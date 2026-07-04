extends Minigame
## SWAP MEET - anthology minigame (module contract: core/minigame.gd).
## A bumper-kart race where NOTHING does damage - every orb hit SWAPS
## your position with the victim's (position + velocity + progress,
## atomically). First place is a bullseye you wear: the leader gets a
## crown, and the golden orb pickup swaps its holder with the CURRENT
## LEADER from anywhere.
##
## Controls (PlayerInput): move.x steer, auto-throttle forward, move.y
## (pull back) brake/reverse. A = throw swap orb (3s cd). B = hold to
## drift, release for a boost proportional to drift time (2s cd).
##
## Standalone: if the shell hasn't called begin() within 0.5s, the game
## begins itself with a default roster from GameState consts, KayKit
## chars seated on karts, seed from --seed or 1.
##
## CLI user args (after --):
##   --seed=N        rng seed for the default config (default 1)
##   --players=N     default roster size 2..4 (default 4)
##   --swapbots      seeded self-play bots on every seat
##   --fast=K        Engine.time_scale multiplier (mutes audio; dt stays
##                   exactly 1/60 - see orbital's determinism notes)
##   --autoquit      quit after the results report / test verdict
##   --laps=N        override 3 laps
##   --timecap=N     override the 170s race cap
##   --swaptest=immunity   scripted orb drops prove 1s swap immunity
##   --swaptest=moment     two parked karts + one throw: the swap money shot
##   --shotsec=a,b,..      capture PNGs at these WALL-clock seconds
##   --shots=N,...         (VerifyCapture autoload) PNGs at frame indices
## All gameplay randomness comes from config.rng_seed. No physics bodies:
## karts, orbs, walls and hazards are hand-integrated each tick.

enum Phase { WAIT, INTRO, PLAY, END }

const KAYKIT_CHARS := ["Barbarian", "Knight", "Mage", "Rogue"]
const LAPS_DEFAULT := 3
const RACE_CAP := 170.0
const FINISH_PTS := [5, 3, 2, 1]
const ORB_CD := 3.0
const SWAP_IMMUNITY := 1.0
const FREEZE_TICKS := 5          # 0.083s hit-stop on every swap
const GOLD_EVERY := 40.0
const GOLD_SPOT_FRACS := [0.16, 0.38, 0.60, 0.84]
const BOOM_LEN := 4.9
const BOOM_SPEED := 0.75
const BOOM_PIVOT_Z := 3.9        # pinch center pulled toward the infield
const KNOCK_POWER := 7.0
const KART_R := 0.55
const CAM_POS := Vector3(0, 28.5, 22.0)
const CAM_LOOK := Vector3(0, 0, 0.9)
const CAM_FOV := 45.0

var config := {}
var rng := RandomNumberGenerator.new()
var phase := Phase.WAIT
var now := 0.0                   # sim clock (stops during hit-stop)
var race_t := 0.0                # race clock (starts at GO)
var laps_total := LAPS_DEFAULT
var time_cap := RACE_CAP

var track: SwapTrack
var karts: Array = []            # SwapKart, array pos == player index
var bots: Array = []
var orbs: Array = []
var bots_enabled := false

var _points := {}
var _currency: Array = []
var _names: Array = []
var _colors: Array = []
var _finish_count := 0
var _swaps_total := 0
var _swaps_blocked := 0
var _golden_swaps := 0
var _gaining_swaps := {}         # player -> count (thrower gained >=1)
var _gold_victims := {}          # player -> times golden-orbed
var _cruel_delta := 0
var _cruel_txt := ""
var _bounces := 0
var _reported := false

var _intro_t := 0.0
var _intro_stage := -1
var _freeze_ticks := 0
var _gold_t := 0.0
var _gold_pickup: Node3D = null
var _gold_spot := Vector3.ZERO
var _booms: Array = []           # {pivot: Node3D, pos, angle, speed, glb_blades}
var _crown: Node3D = null
var _crown_on := -1
var _final_lap_called := false
var _end_t := -1.0

var _begun := false
var _cli_seed := 1
var _cli_players := 4
var _fast := 1.0
var _autoquit := false
var _test_mode := ""
var _test_stage := 0
var _shotsec: Array = []
var _vis_t := 0.0
var _shot_i := 0
var _shake := 0.0

var _cam: Camera3D
var _fx_root: Node3D
var _banner: RichTextLabel
var _event_label: Label
var _timer_label: Label
var _lap_label: Label
var _hint_label: Label
var _score_rows: VBoxContainer
var _row_labels: Array = []
var _event_until := 0.0
var _banner_gen := 0

func _ready() -> void:
	_parse_args()
	_build_static()
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if not _begun:
			begin(_default_config()))

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--swapbots":
			bots_enabled = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--fast="):
			_fast = clampf(float(arg.trim_prefix("--fast=")), 1.0, 30.0)
		elif arg == "--autoquit":
			_autoquit = true
		elif arg.begins_with("--laps="):
			laps_total = clampi(int(arg.trim_prefix("--laps=")), 1, 9)
		elif arg.begins_with("--timecap="):
			time_cap = float(arg.trim_prefix("--timecap="))
		elif arg.begins_with("--swaptest="):
			_test_mode = arg.trim_prefix("--swaptest=")
		elif arg.begins_with("--shotsec="):
			for s in arg.trim_prefix("--shotsec=").split(","):
				_shotsec.append(float(s))
	if _fast > 1.01:
		# Faster-than-realtime with dt pinned to exactly 1/60 (the sim is
		# tick-identical to live play): scale BOTH time_scale and tick rate.
		Engine.time_scale = _fast
		Engine.physics_ticks_per_second = int(60.0 * _fast)
		Engine.max_physics_steps_per_frame = maxi(8, int(60.0 * _fast))
		AudioServer.set_bus_mute(0, true)

func _default_config() -> Dictionary:
	PlayerInput.auto_assign(_cli_players)
	var roster: Array = []
	for i in _cli_players:
		roster.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": "res://assets/models/kaykit/%s.glb" % KAYKIT_CHARS[i],
			"device": PlayerInput.device_of(i),
		})
	return {"roster": roster, "rounds": 1, "rng_seed": _cli_seed, "practice": false}

func begin(cfg: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	config = cfg
	rng.seed = int(cfg.rng_seed)
	if cfg.get("practice", false):
		laps_total = mini(laps_total, 2)
	var roster: Array = cfg.roster
	for pl in roster:
		var idx: int = pl.index
		_names.resize(maxi(_names.size(), idx + 1))
		_colors.resize(maxi(_colors.size(), idx + 1))
		_names[idx] = pl.name
		_colors[idx] = pl.color
		_points[idx] = 0
		_gaining_swaps[idx] = 0
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var kart := SwapKart.new()
		kart.world = self
		kart.track = track
		kart.index = pl.index
		add_child(kart)
		kart.setup(load(String(pl.char_scene)), pl.color, pl.name)
		# staggered grid just before the finish line
		var row := i / 2
		var col := i % 2
		kart.place_at(track.total_len - 2.2 - row * 1.9, -1.05 + 2.1 * col)
		karts.append(kart)
	if bots_enabled:
		for i in roster.size():
			var bot := SwapBot.new()
			bot.setup(self, i, int(cfg.rng_seed) * 977 + i * 131)
			bots.append(bot)
	_build_crown()
	if _test_mode != "":
		_setup_test()
		return
	phase = Phase.INTRO
	_intro_t = 0.0
	_intro_stage = -1
	_update_score_rows()

## --- static world -------------------------------------------------------------

func _build_static() -> void:
	_cam = Camera3D.new()
	_cam.position = CAM_POS
	_cam.fov = CAM_FOV
	add_child(_cam)
	_cam.look_at(CAM_LOOK)
	_cam.current = true
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-54, 34, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	var wenv := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.11, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.64, 0.62)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	wenv.environment = env
	add_child(wenv)
	track = SwapTrack.new()
	add_child(track)
	track.build()
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_build_booms()
	_build_ui()

## Windmill boom hazards at the two pinch points: a candy-striped arm
## sweeps across the track; getting clipped knocks you sideways
## (non-lethal). The Par windmill model stands at each pivot for flavor.
func _build_booms() -> void:
	var pinches := [Vector3(0, 0, -BOOM_PIVOT_Z), Vector3(0, 0, BOOM_PIVOT_Z)]
	var phases := [0.0, PI]
	var wm_scene: PackedScene = load("res://assets/models/minigolf/windmill.glb")
	for i in 2:
		var pivot := Node3D.new()
		pivot.position = pinches[i] + Vector3(0, 0.35, 0)
		add_child(pivot)
		var base := MeshInstance3D.new()
		var basem := CylinderMesh.new()
		basem.top_radius = 0.42
		basem.bottom_radius = 0.55
		basem.height = 0.4
		base.mesh = basem
		var bmat2 := StandardMaterial3D.new()
		bmat2.albedo_color = Color(0.35, 0.33, 0.38)
		base.material_override = bmat2
		base.position = pinches[i] + Vector3(0, 0.1, 0)
		add_child(base)
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.30
		hm.bottom_radius = 0.36
		hm.height = 0.5
		hub.mesh = hm
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.25, 0.24, 0.28)
		hub.material_override = hmat
		pivot.add_child(hub)
		for seg in 4:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(BOOM_LEN / 4.0, 0.24, 0.30)
			bar.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = SwapTrack.COL_RAILRED if seg % 2 == 0 else Color(0.96, 0.93, 0.88)
			bar.material_override = mat
			bar.position = Vector3(BOOM_LEN / 4.0 * (0.5 + seg), 0.0, 0.0)
			pivot.add_child(bar)
		var tip := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.2
		tm.height = 0.4
		tip.mesh = tm
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(1.0, 0.8, 0.2)
		tmat.emission_enabled = true
		tmat.emission = Color(0.9, 0.65, 0.1)
		tip.material_override = tmat
		tip.position = Vector3(BOOM_LEN, 0.0, 0.0)
		pivot.add_child(tip)
		var blades: Node3D = null
		if wm_scene != null:
			var wm: Node3D = wm_scene.instantiate()
			# tucked into the infield beside its pinch, clear of the sweep
			wm.position = Vector3(5.8 * (1.0 if i == 1 else -1.0), 0.0, pinches[i].z * 0.62)
			wm.scale = Vector3.ONE * 2.6
			wm.rotation.y = 0.0 if i == 0 else PI
			add_child(wm)
			blades = wm.find_child("blades", true, false)
		_booms.append({"pivot": pivot, "pos": pinches[i], "angle": phases[i],
			"speed": BOOM_SPEED * (1.0 if i == 0 else -1.0), "blades": blades})

func _build_crown() -> void:
	_crown = Node3D.new()
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.26
	bm.bottom_radius = 0.30
	bm.height = 0.16
	band.mesh = bm
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.2)
	gold.metallic = 0.8
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.7, 0.1)
	gold.emission_energy_multiplier = 0.5
	band.material_override = gold
	_crown.add_child(band)
	for i in 4:
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.07
		sm.height = 0.22
		spike.mesh = sm
		spike.material_override = gold
		var a := TAU * i / 4.0
		spike.position = Vector3(cos(a) * 0.26, 0.17, sin(a) * 0.26)
		_crown.add_child(spike)
	var sparkle := CPUParticles3D.new()
	sparkle.amount = 14
	sparkle.lifetime = 0.7
	sparkle.initial_velocity_min = 0.4
	sparkle.initial_velocity_max = 1.2
	sparkle.direction = Vector3.UP
	sparkle.spread = 70.0
	sparkle.gravity = Vector3(0, -1.5, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	sparkle.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	sparkle.material_override = mat
	sparkle.emitting = true
	_crown.add_child(sparkle)
	_crown.scale = Vector3.ONE * 2.1
	_crown.visible = false
	add_child(_crown)

## --- simulation loop -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if phase == Phase.WAIT:
		return
	var sdt := delta
	if _freeze_ticks > 0:
		# the swap hit-stop: tick-counted, never touches Engine.time_scale
		_freeze_ticks -= 1
		sdt = 0.0
	now += sdt
	if phase == Phase.INTRO:
		_intro_tick(sdt)
	if phase == Phase.PLAY:
		race_t += sdt
	if sdt > 0.0 and bots_enabled:
		for bot in bots:
			bot.think(sdt)
	# karts
	for k in karts:
		var kart: SwapKart = k
		var inp := _input_for(kart.index)
		if sdt > 0.0:
			kart.step(sdt, inp.move, inp.b)
			_constrain(kart, sdt)
			if phase == Phase.PLAY and inp.a:
				_throw_orb(kart)
	if sdt > 0.0:
		_kart_bumps()
		_step_booms(sdt)
	# orbs (after karts so hits use final positions)
	if sdt > 0.0:
		var hits: Array = []
		for o in orbs:
			var orb: SwapOrb = o
			var victim: SwapKart = orb.step(sdt)
			if victim != null:
				hits.append({"orb": orb, "victim": victim})
		for h in hits:
			_resolve_hit(h.orb, h.victim)
		var alive: Array = []
		for o in orbs:
			if not (o as SwapOrb).dead:
				alive.append(o)
		orbs = alive
	if phase == Phase.PLAY and sdt > 0.0:
		_progress_all()
		_golden_tick(sdt)
		_update_crown()
		if _test_mode == "":
			if race_t > time_cap:
				_end_race()
			elif _finish_count >= karts.size():
				_end_race()
	if _test_mode != "" and sdt > 0.0:
		_test_tick()

func _intro_tick(sdt: float) -> void:
	_intro_t += sdt
	var stage := -1
	if _intro_t < 1.1:
		stage = 0
	elif _intro_t < 1.7:
		stage = 1
	elif _intro_t < 2.3:
		stage = 2
	elif _intro_t < 2.9:
		stage = 3
	else:
		stage = 4
	if stage == _intro_stage:
		return
	_intro_stage = stage
	match stage:
		0:
			_flash_banner("[color=#ffd84d]SWAP MEET[/color]\n[font_size=26]EVERY HIT TRADES PLACES. SHOOT FIRST PLACE.[/font_size]", 1.05)
		1:
			_flash_banner("[color=#ff6b5e]3[/color]", 0.55)
			Sfx.play("card")
		2:
			_flash_banner("[color=#ffd84d]2[/color]", 0.55)
			Sfx.play("card")
		3:
			_flash_banner("[color=#7fe08a]1[/color]", 0.55)
			Sfx.play("card")
		4:
			_flash_banner("[color=#ffffff]GO!!![/color]", 0.8)
			Sfx.play("confirm")
			phase = Phase.PLAY
			for k in karts:
				(k as SwapKart).locked = false
				(k as SwapKart).orb_cd = 1.5  # first seconds are pure racing

func _input_for(p: int) -> Dictionary:
	if phase != Phase.PLAY and phase != Phase.END:
		return {"move": Vector2.ZERO, "a": false, "b": false}
	if bots_enabled:
		var bot: SwapBot = bots[p]
		return {"move": bot.move, "a": bot.a, "b": bot.b}
	if _test_mode != "":
		return {"move": Vector2.ZERO, "a": false, "b": false}
	return {
		"move": PlayerInput.get_move(p),
		"a": PlayerInput.just_pressed(p, "a"),
		"b": PlayerInput.is_down(p, "b"),
	}

## Corridor walls + floor + shortcut transitions + progress s for one kart.
func _constrain(kart: SwapKart, dt: float) -> void:
	var s_eff := 0.0
	if kart.on_shortcut:
		var q: Dictionary = track.nearest_sc(kart.global_position, kart.sc_hint)
		kart.sc_hint = int(q.idx)
		var s_sc := float(q.s)
		if s_sc > track.sc_len - 0.9:
			kart.on_shortcut = false
			print("SC_EXIT t=%.1f p=%d" % [race_t, kart.index])
			var qm: Dictionary = track.nearest_main(kart.global_position, -1)
			kart.hint = int(qm.idx)
			s_eff = float(qm.s)
			_apply_walls(kart, qm, 0.0, dt)
		else:
			_apply_walls(kart, q, track.sc_floor(s_sc), dt)
			s_eff = track.sc_entry_s + (s_sc / track.sc_len) * fposmod(track.sc_exit_s - track.sc_entry_s, track.total_len)
	else:
		var q2: Dictionary = track.nearest_main(kart.global_position, kart.hint)
		kart.hint = int(q2.idx)
		s_eff = float(q2.s)
		# shortcut entrance: near the mouth, HUGGING THE INFIELD SIDE
		# (where the arrow is; negative lat here), and moving into the
		# branch. Racing-line traffic keeps lat ~0 and is not captured.
		if not kart.finished and not kart.airborne \
				and float(q2.lat) < -1.1 \
				and kart.global_position.distance_to(track.sc_entry_pos) < 2.4:
			var into := Vector3(track.sc_sample_at(2.5).pos) - kart.global_position
			into.y = 0.0
			if into.length() > 0.3 and kart.heading.dot(into.normalized()) > 0.3:
				kart.on_shortcut = true
				kart.sc_hint = 0
				print("SC_ENTER t=%.1f p=%d" % [race_t, kart.index])
		_apply_walls(kart, q2, 0.0, dt)
	# progress (wrap-aware delta on the effective main-loop arclength)
	var l := track.total_len
	var ds := s_eff - kart.last_s_eff
	if ds < -l * 0.5:
		ds += l
	elif ds > l * 0.5:
		ds -= l
	kart.progress += ds
	kart.last_s_eff = s_eff
	if phase == Phase.PLAY:
		_check_gates(kart)
		_check_laps(kart)

func _apply_walls(kart: SwapKart, q: Dictionary, floor_y: float, dt: float) -> void:
	var hw := float(q.hw) - KART_R
	var lat := float(q.lat)
	var right := Vector3(q.tangent).cross(Vector3.UP)
	if absf(lat) > hw:
		var side := signf(lat)
		var proj := Vector3(q.proj)
		kart.global_position = Vector3(proj.x, kart.global_position.y, proj.z) + right * hw * side
		var impact := kart.bounce(-right * side)
		if impact > 1.5:
			_bounces += 1
			Sfx.play("bounce", clampf(-12.0 + impact * 1.1, -12.0, -2.0))
			if impact > 5.0:
				_shake = maxf(_shake, 0.12)
	# floor / airborne
	if kart.airborne:
		if kart.air_step(dt, floor_y):
			_burst(kart.global_position, Color(0.8, 0.72, 0.6), 8)
			Sfx.play("place", -6.0)
	else:
		if floor_y < kart.y - 0.5:
			kart.launch_air(maxf(kart.speed, 0.0) * SwapKart.RAMP_LAUNCH)
			Sfx.play("putt", -4.0)
			print("JUMP t=%.1f p=%d v=%.1f" % [race_t, kart.index, kart.speed])
		else:
			kart.y = floor_y
	kart.global_position.y = kart.y

func _check_gates(kart: SwapKart) -> void:
	var g := _gates_below(kart.progress)
	if g > kart.gates_credited:
		var earned := g - kart.gates_credited
		kart.gates_credited = g
		if not kart.finished:
			_points[kart.index] += earned
			var gi := (g - 1) % track.gate_s.size()
			track.pulse_gate(gi, kart.color)
			Sfx.play("card", -5.0)
			_update_score_rows()

func _gates_below(prog: float) -> int:
	if prog <= 0.0:
		return 0
	var per := track.gate_s.size()
	var full := int(prog / track.total_len)
	var rem := prog - full * track.total_len
	var c := full * per
	for gs in track.gate_s:
		if rem >= gs:
			c += 1
	return c

func _check_laps(kart: SwapKart) -> void:
	var laps_done := int(floorf(kart.progress / track.total_len))
	if laps_done <= kart.laps_hw:
		return
	kart.laps_hw = laps_done
	var lt := race_t - kart.last_cross_time
	kart.last_cross_time = race_t
	if kart.laps_hw > 0:
		kart.lap_times.append(lt)
		print("LAP t=%.1f p=%d lap=%d time=%.1fs" % [race_t, kart.index, kart.laps_hw, lt])
	if kart.laps_hw >= laps_total and not kart.finished:
		_finish_kart(kart)
	elif kart.laps_hw == laps_total - 1 and not _final_lap_called and _leader_all() == kart.index:
		_final_lap_called = true
		_flash_banner("[color=#ffd84d]FINAL LAP![/color]", 1.4)
		Sfx.play("round_over", -4.0)

func _finish_kart(kart: SwapKart) -> void:
	kart.finished = true
	kart.has_golden = false
	_finish_count += 1
	kart.finish_place = _finish_count
	_points[kart.index] += FINISH_PTS[kart.finish_place - 1]
	kart.cheer_forever()
	Sfx.play("round_over")
	_confetti(kart.center(), kart.color)
	_flash_banner("[color=%s]%s[/color] FINISHES P%d!" % [kart.color.to_html(false), kart.pname, kart.finish_place], 1.6)
	print("FINISH t=%.1f p=%d place=%d laps=%s" % [race_t, kart.index, kart.finish_place, str(kart.lap_times)])
	_update_score_rows()

## --- kart-kart bumps ------------------------------------------------------------

func _kart_bumps() -> void:
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			var a: SwapKart = karts[i]
			var b: SwapKart = karts[j]
			if absf(a.y - b.y) > 0.8:
				continue
			var d := b.global_position - a.global_position
			d.y = 0.0
			var dist := d.length()
			if dist > KART_R * 2.0 + 0.14 or dist < 0.001:
				continue
			var n := d / dist
			var overlap := KART_R * 2.0 + 0.14 - dist
			a.global_position -= n * overlap * 0.5
			b.global_position += n * overlap * 0.5
			var va := a.vel_dir * a.speed + a.knock_vel
			var vb := b.vel_dir * b.speed + b.knock_vel
			var closing := (va - vb).dot(n)
			if closing > 0.0:
				a.knock_vel -= n * closing * 0.55
				b.knock_vel += n * closing * 0.55
				if closing > 3.0:
					Sfx.play("bounce", -8.0)

## --- windmill booms ----------------------------------------------------------------

func _step_booms(dt: float) -> void:
	for boom in _booms:
		boom.angle = fposmod(float(boom.angle) + float(boom.speed) * dt, TAU)
		var pivot: Node3D = boom.pivot
		pivot.rotation.y = -float(boom.angle)
		if boom.blades != null:
			(boom.blades as Node3D).rotate_object_local(Vector3(0, 0, 1), dt * 1.4)
		if phase != Phase.PLAY:
			continue
		var origin := Vector3(boom.pos)
		var dir := Vector3(cos(float(boom.angle)), 0, sin(float(boom.angle)))
		for k in karts:
			var kart: SwapKart = k
			if kart.finished or kart.knock_immune > 0.0 or kart.y > 0.6:
				continue
			var rel := kart.global_position - origin
			rel.y = 0.0
			var along := clampf(rel.dot(dir), 0.0, BOOM_LEN)
			var closest := origin + dir * along
			if kart.global_position.distance_to(Vector3(closest.x, kart.global_position.y, closest.z)) < 0.78:
				var swing := Vector3.UP.cross(dir).normalized() * signf(float(boom.speed))
				kart.knock(swing, KNOCK_POWER)
				kart.play_anim("Hit_A", 0.5)
				Sfx.play("crush")
				_shake = maxf(_shake, 0.22)
				_burst(kart.center(), Color(1.0, 0.9, 0.6), 14)
				print("KNOCK t=%.1f p=%d boom" % [race_t, kart.index])

## --- orbs & swapping -----------------------------------------------------------------

func _throw_orb(kart: SwapKart) -> void:
	if kart.locked:
		return
	if kart.finished:
		# finished players still get a toy: confetti honk
		_burst(kart.center() + Vector3(0, 1.0, 0), kart.color, 10)
		Sfx.play("card", -6.0)
		return
	if kart.orb_cd > 0.0:
		return
	kart.orb_cd = ORB_CD
	var was_golden := kart.has_golden
	var golden := was_golden
	var target := -1
	if golden:
		kart.has_golden = false
		target = leader_unfinished()
		if target == kart.index or target < 0:
			golden = false  # leader threw the golden: it flies as a normal orb
	var orb := SwapOrb.new()
	orb.setup(self, kart.index, kart.color, was_golden)
	_fx_root.add_child(orb)
	orb.golden = golden
	orb.target_idx = target
	orb.global_position = kart.center() + kart.heading * 0.85 + Vector3(0, 0.35, 0)
	if golden:
		orb.vel = kart.heading * 8.0 + Vector3(0, 3.5, 0)
		Sfx.play("grudge")
		_flash_event("%s FIRES THE GOLDEN ORB AT %s!" % [kart.pname, _names[target]], Color(1.0, 0.85, 0.25))
	else:
		orb.vel = kart.heading * (8.5 + maxf(kart.speed, 0.0) * 0.6) + Vector3(0, 4.6, 0)
		Sfx.play("putt")
	orbs.append(orb)
	kart.play_anim("Throw", 0.7)
	print("THROW t=%.1f p=%d golden=%s" % [race_t, kart.index, str(golden)])

func _resolve_hit(orb: SwapOrb, victim: SwapKart) -> void:
	if orb.dead:
		return
	var thrower: SwapKart = karts[orb.owner_idx]
	if victim.finished or victim == thrower:
		orb.fizzle()
		return
	if not orb.golden and victim.swap_immune > 0.0:
		orb.fizzle()
		return
	orb.dead = true
	orb.queue_free()
	_do_swap(thrower, victim, orb.golden)

func on_swap_blocked(_orb: SwapOrb, victim: SwapKart) -> void:
	_swaps_blocked += 1
	_flash_event("%s IS SWAP-PROOF (immunity)" % victim.pname, Color(0.8, 0.85, 1.0))
	print("SWAP_BLOCKED t=%.1f victim=%d" % [race_t, victim.index])

## THE verb. Atomic exchange of two karts' kinematic souls, with the
## full ritual: 0.08s hit-stop, dual teleport beams in both colors,
## camera shake, name-tag flashes, SWAPPED! banner.
func _do_swap(a: SwapKart, b: SwapKart, golden: bool) -> void:
	var pre := _positions_list()
	var pre_pos_a := pre.find(a.index) + 1
	var pre_pos_b := pre.find(b.index) + 1
	var pos_a := a.center()
	var pos_b := b.center()
	# the atomic trade
	var soul_a: Dictionary = a.soul()
	a.apply_soul(b.soul())
	b.apply_soul(soul_a)
	a.gates_credited = maxi(a.gates_credited, _gates_below(a.progress))
	b.gates_credited = maxi(b.gates_credited, _gates_below(b.progress))
	a.swap_immune = SWAP_IMMUNITY
	b.swap_immune = SWAP_IMMUNITY
	a.play_anim("Hit_A", 0.4)
	b.play_anim("Hit_A", 0.4)
	a.flash_tag()
	b.flash_tag()
	# the ritual
	_freeze_ticks = FREEZE_TICKS
	_swap_fx(pos_a, a.color, b.color)
	_swap_fx(pos_b, b.color, a.color)
	_shake = maxf(_shake, 0.55 if golden else 0.4)
	Sfx.play("sink")
	Sfx.play("bumper", -4.0)
	# accounting
	_swaps_total += 1
	var post := _positions_list()
	var post_pos_a := post.find(a.index) + 1
	var post_pos_b := post.find(b.index) + 1
	var gain_a := pre_pos_a - post_pos_a
	var gain_b := pre_pos_b - post_pos_b
	var ca := a.color.to_html(false)
	var cb := b.color.to_html(false)
	if golden:
		_golden_swaps += 1
		_gold_victims[b.index] = int(_gold_victims.get(b.index, 0)) + 1
		_flash_banner("[color=#ffd84d]GOLDEN SWAP![/color]\n[color=#%s]%s[/color] ROBS [color=#%s]%s[/color]" % [ca, a.pname, cb, b.pname], 2.0)
	else:
		_flash_banner("[color=#ffffff]SWAPPED![/color]\n[color=#%s]%s[/color] [color=#ffffff]<->[/color] [color=#%s]%s[/color]" % [ca, a.pname, cb, b.pname], 1.6)
	for pair in [[a, gain_a, b], [b, gain_b, a]]:
		var who: SwapKart = pair[0]
		var gain: int = pair[1]
		var other: SwapKart = pair[2]
		if gain >= 1:
			_currency.append({"type": "royalty", "player": who.index, "amount": 1,
				"reason": "swap heist (+%d places)" % gain})
			if who == a:  # the thrower stole it: pickpocket credit
				_gaining_swaps[who.index] = int(_gaining_swaps[who.index]) + 1
			if gain > _cruel_delta:
				_cruel_delta = gain
				_cruel_txt = "%s pickpocketed %d place%s from %s" % [who.pname, gain, "s" if gain > 1 else "", other.pname]
		if pre.find(who.index) == 0 and post.find(who.index) != 0:
			_currency.append({"type": "grudge", "player": who.index, "amount": 1,
				"reason": "swapped out of 1st"})
			_flash_event("%s LOSES THE LEAD!" % who.pname, who.color)
	_update_score_rows()
	print("SWAP t=%.1f thrower=%d victim=%d golden=%s gain=%d" % [race_t, a.index, b.index, str(golden), gain_a])

func on_orb_fizzle(orb: SwapOrb) -> void:
	_burst(orb.global_position, Color(0.7, 0.8, 0.95, 0.7), 6)
	orb.queue_free()

func on_boost(kart: SwapKart, tier: int) -> void:
	Sfx.play("bumper", -6.0 if tier == 1 else -1.0)
	if tier == 2:
		_burst(kart.global_position + Vector3(0, 0.3, 0), Color(0.8, 0.5, 1.0), 10)
	print("BOOST t=%.1f p=%d tier=%d" % [race_t, kart.index, tier])

## --- golden orb pickup ---------------------------------------------------------------

func _golden_tick(dt: float) -> void:
	if _gold_pickup != null:
		_gold_pickup.rotate_y(dt * 2.0)
		var bob: Node3D = _gold_pickup.get_node("Bob")
		bob.position.y = 1.0 + 0.18 * sin(now * 3.0)
		var lead := leader_unfinished()
		for k in karts:
			var kart: SwapKart = k
			# the leader can't claim it - the golden orb IS the bullseye
			# pointed at them; they drive right through
			if kart.finished or kart.airborne or kart.index == lead:
				continue
			if kart.global_position.distance_to(_gold_spot) < 1.25:
				_claim_golden(kart)
				break
		return
	var holder := false
	for k in karts:
		if (k as SwapKart).has_golden:
			holder = true
	for o in orbs:
		if (o as SwapOrb).golden:
			holder = true
	if holder:
		return
	_gold_t += dt
	if _gold_t >= GOLD_EVERY:
		_gold_t = 0.0
		_spawn_golden()

func _spawn_golden() -> void:
	# The comeback verb: spawn AHEAD of the trailing kart so the player
	# who needs it most reaches it first. Seeded pick among qualifying
	# spots; falls back to the nearest spot ahead of the trailer.
	var order := _positions_list()
	var trailer: SwapKart = null
	for i in range(order.size() - 1, -1, -1):
		if not (karts[order[i]] as SwapKart).finished:
			trailer = karts[order[i]]
			break
	if trailer == null:
		return
	var t_s := fposmod(trailer.progress, track.total_len)
	var candidates: Array = []
	var best_frac := -1.0
	var best_ahead := 1e9
	for f in GOLD_SPOT_FRACS:
		var ahead := fposmod(float(f) * track.total_len - t_s, track.total_len)
		if ahead > 6.0 and ahead < 45.0:
			candidates.append(f)
		if ahead > 6.0 and ahead < best_ahead:
			best_ahead = ahead
			best_frac = float(f)
	var frac := best_frac if best_frac > 0.0 else float(GOLD_SPOT_FRACS[0])
	if candidates.size() > 0:
		frac = float(candidates[rng.randi_range(0, candidates.size() - 1)])
	var sm: Dictionary = track.sample_at(frac * track.total_len)
	_gold_spot = Vector3(sm.pos)
	_gold_pickup = Node3D.new()
	_gold_pickup.position = _gold_spot
	var bob := Node3D.new()
	bob.name = "Bob"
	bob.position.y = 1.0
	_gold_pickup.add_child(bob)
	var orb := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.42
	om.height = 0.84
	orb.mesh = om
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.2)
	mat.metallic = 0.7
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	mat.emission_energy_multiplier = 1.4
	orb.material_override = mat
	bob.add_child(orb)
	var pillar := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.5
	pm.bottom_radius = 0.7
	pm.height = 9.0
	pillar.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.albedo_color = Color(1.0, 0.8, 0.2, 0.16)
	pillar.material_override = pmat
	pillar.position.y = 4.5
	_gold_pickup.add_child(pillar)
	add_child(_gold_pickup)
	Sfx.play("confirm", -2.0)
	_flash_event("GOLDEN ORB ON THE TRACK - SWAPS YOU WITH THE LEADER (leaders can't grab it)", Color(1.0, 0.85, 0.25))
	print("GOLD_SPAWN t=%.1f s=%.1f" % [race_t, frac * track.total_len])

func _claim_golden(kart: SwapKart) -> void:
	_gold_pickup.queue_free()
	_gold_pickup = null
	kart.has_golden = true
	Sfx.play("sink", -3.0)
	_burst(kart.center(), Color(1.0, 0.85, 0.25), 20)
	_flash_banner("[color=#%s]%s[/color] [color=#ffd84d]HAS THE GOLDEN ORB[/color]" % [kart.color.to_html(false), kart.pname], 1.5)
	print("GOLD_CLAIM t=%.1f p=%d" % [race_t, kart.index])

## --- standings ----------------------------------------------------------------------

func _progress_all() -> void:
	# HUD refresh cadence
	if Engine.get_physics_frames() % 15 == 0:
		_update_score_rows()
		_update_timer_label()

func _positions_list() -> Array:
	var order: Array = []
	for k in karts:
		order.append((k as SwapKart).index)
	order.sort_custom(func(x, y) -> bool:
		var a: SwapKart = karts[x]
		var b: SwapKart = karts[y]
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_place < b.finish_place
		if absf(a.progress - b.progress) > 0.001:
			return a.progress > b.progress
		return a.index < b.index)
	return order

func position_of(idx: int) -> int:
	return _positions_list().find(idx) + 1

func _leader_all() -> int:
	return _positions_list()[0]

func leader_unfinished() -> int:
	for i in _positions_list():
		if not (karts[i] as SwapKart).finished:
			return i
	return -1

func _update_crown() -> void:
	var lead := leader_unfinished()
	if lead != _crown_on:
		_crown_on = lead
		if lead >= 0 and phase == Phase.PLAY:
			_flash_event("%s LEADS - AIM AT THE CROWN" % _names[lead], _colors[lead])
	if lead < 0:
		_crown.visible = false
		return
	var kart: SwapKart = karts[lead]
	_crown.visible = phase != Phase.WAIT
	_crown.global_position = kart.global_position + Vector3(0, 1.42 + 0.08 * sin(now * 4.0), 0)
	_crown.rotation.y += get_physics_process_delta_time() * 1.5

## --- race end -------------------------------------------------------------------------

func _end_race() -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	var order := _positions_list()
	# DNF karts still collect their placement points (transparent, kind)
	for pi in order.size():
		var kart: SwapKart = karts[order[pi]]
		if not kart.finished and pi < FINISH_PTS.size():
			_points[kart.index] += FINISH_PTS[pi]
	var winner: int = order[0]
	karts[winner].cheer_forever()
	Sfx.play("match_win")
	_confetti(karts[winner].center(), _colors[winner])
	_confetti(karts[winner].center() + Vector3(1.5, 1, 0), Color(1, 0.9, 0.4))
	_flash_banner("[color=#%s]%s WINS THE SWAP MEET![/color]" % [_colors[winner].to_html(false), _names[winner]], 9999.0)
	for k in karts:
		(k as SwapKart).locked = false  # keep cruising behind the banner
	var highlights: Array = []
	if _cruel_txt != "":
		highlights.append(_cruel_txt)
	var worst_gold := 0
	var worst_gold_i := -1
	for i in _gold_victims:
		if int(_gold_victims[i]) > worst_gold:
			worst_gold = int(_gold_victims[i])
			worst_gold_i = int(i)
	if worst_gold_i >= 0:
		var times_txt := "at the worst moment"
		if worst_gold >= 2:
			times_txt = "%d times" % worst_gold
		highlights.append("%s ate the golden orb %s" % [_names[worst_gold_i], times_txt])
	var fast_t := 1e9
	var fast_i := -1
	for k in karts:
		var kart: SwapKart = k
		for lt in kart.lap_times:
			if float(lt) < fast_t:
				fast_t = float(lt)
				fast_i = kart.index
	if fast_i >= 0:
		highlights.append("Fastest lap: %s (%.1fs)" % [_names[fast_i], fast_t])
	var monuments: Array = []
	for i in _gaining_swaps:
		if int(_gaining_swaps[i]) >= 5:
			monuments.append({"player": int(i), "kind": "pickpocket",
				"label": "%s, The Pickpocket (%d liftings)" % [_names[int(i)], int(_gaining_swaps[i])]})
	var results := {
		"placements": order,
		"points": _points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": highlights.slice(0, 3),
		"monuments": monuments,
	}
	get_tree().create_timer(1.8, true, false, true).timeout.connect(func() -> void:
		if _reported:
			return
		_reported = true
		report_finished(results)
		print("SWAPMEET_RESULTS ", JSON.stringify(results))
		_print_sim_summary()
		if _autoquit:
			get_tree().create_timer(1.5, true, false, true).timeout.connect(func() -> void: get_tree().quit()))

func _print_sim_summary() -> void:
	var all_finished := true
	var laps_txt := ""
	for k in karts:
		var kart: SwapKart = k
		if not kart.finished:
			all_finished = false
		var times: Array = []
		for lt in kart.lap_times:
			times.append("%.1f" % float(lt))
		laps_txt += " p%d=[%s]" % [kart.index, ",".join(times)]
	print("SWAPMEET_SIM race_t=%.1fs swaps=%d blocked=%d golden=%d bounces=%d gaining=%s" %
		[race_t, _swaps_total, _swaps_blocked, _golden_swaps, _bounces, str(_gaining_swaps)])
	print("SWAPMEET_LAPS%s" % laps_txt)
	if bots_enabled:
		var ok := all_finished and race_t < 180.0 and _swaps_total >= 3
		print("SWAPMEET_ASSERT all_finished=%s race_t=%.1fs(<180) swaps=%d(>=3): %s" %
			[str(all_finished), race_t, _swaps_total, "PASS" if ok else "FAIL"])

## --- scripted tests ----------------------------------------------------------------------

func _setup_test() -> void:
	phase = Phase.PLAY
	for k in karts:
		var kart: SwapKart = k
		kart.locked = false
		kart.parked = true
	var l := track.total_len
	if _test_mode == "immunity" or _test_mode == "moment":
		karts[0].place_at(l * 0.26, -0.5)
		karts[1].place_at(l * 0.34, -0.5)
		if karts.size() > 2:
			karts[2].place_at(l * 0.18, 0.9)
		if karts.size() > 3:
			karts[3].place_at(l * 0.14, -0.9)
		# kart1 sits EXACTLY on kart0's throw line (deterministic hit)
		var k0: SwapKart = karts[0]
		var k1: SwapKart = karts[1]
		k1.global_position = k0.global_position + k0.heading * 7.5
		k1.heading = k0.heading
		k1.vel_dir = k0.heading
		var q: Dictionary = track.nearest_main(k1.global_position, -1)
		k1.hint = int(q.idx)
		k1.last_s_eff = float(q.s)
		k1.progress = float(q.s)
		k1._orient(1000.0)
	_update_score_rows()
	print("SWAPTEST %s armed" % _test_mode)

func _drop_orb_on(owner_i: int, target_i: int) -> void:
	var orb := SwapOrb.new()
	orb.setup(self, owner_i, _colors[owner_i], false)
	_fx_root.add_child(orb)
	orb.global_position = karts[target_i].center() + Vector3(0, 3.0, 0)
	orb.vel = Vector3(0, -6.0, 0)
	orbs.append(orb)

func _test_tick() -> void:
	if _test_mode == "immunity":
		# stage machine on sim time; orb drops take ~0.4s to land
		if _test_stage == 0 and now >= 1.0:
			_test_stage = 1
			_drop_orb_on(0, 1)  # -> swap 1
		elif _test_stage == 1 and now >= 1.8:
			_test_stage = 2
			_drop_orb_on(2, 1)  # within immunity -> must be blocked
		elif _test_stage == 2 and now >= 3.5:
			_test_stage = 3
			_drop_orb_on(2, 1)  # immunity expired -> swap 2
		elif _test_stage == 3 and now >= 4.6:
			_test_stage = 4
			var ok := _swaps_total == 2 and _swaps_blocked >= 1
			print("SWAPMEET_TEST immunity swaps=%d blocked=%d: %s" %
				[_swaps_total, _swaps_blocked, "PASS" if ok else "FAIL"])
			if _autoquit:
				get_tree().quit()
	elif _test_mode == "moment":
		if _test_stage == 0 and now >= 1.0:
			_test_stage = 1
			karts[0].orb_cd = 0.0
			_throw_orb(karts[0])

## --- FX -------------------------------------------------------------------------------------

func _swap_fx(pos: Vector3, col_arriving: Color, col_departing: Color) -> void:
	for cfg in [[col_departing, 0.85, 0.55], [col_arriving, 0.45, 0.95]]:
		var col: Color = cfg[0]
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(cfg[1])
		cm.bottom_radius = float(cfg[1])
		cm.height = 7.0
		beam.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(col.r, col.g, col.b, float(cfg[2]))
		beam.material_override = mat
		_fx_root.add_child(beam)
		beam.global_position = Vector3(pos.x, 3.2, pos.z)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(beam, "scale", Vector3(0.15, 1.15, 0.15), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
		tw.chain().tween_callback(beam.queue_free)
	_burst(pos, col_arriving, 18)
	_burst(pos + Vector3(0, 0.5, 0), col_departing, 12)
	# ground shock ring
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(col_arriving.r, col_arriving.g, col_arriving.b, 0.8)
	ring.material_override = rmat
	_fx_root.add_child(ring)
	ring.global_position = Vector3(pos.x, 0.1, pos.z)
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(rmat, "albedo_color:a", 0.0, 0.45)
	tw2.chain().tween_callback(ring.queue_free)

func _burst(pos: Vector3, color: Color, amount: int) -> void:
	var part := CPUParticles3D.new()
	_fx_root.add_child(part)
	part.global_position = pos
	part.one_shot = true
	part.amount = amount
	part.lifetime = 0.7
	part.explosiveness = 1.0
	part.direction = Vector3.UP
	part.spread = 180.0
	part.initial_velocity_min = 2.0
	part.initial_velocity_max = 5.0
	part.gravity = Vector3(0, -4, 0)
	part.damping_min = 1.0
	part.damping_max = 2.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	part.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	part.material_override = mat
	part.emitting = true
	get_tree().create_timer(1.4, true, false, true).timeout.connect(part.queue_free)

func _confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		_fx_root.add_child(p)
		p.global_position = pos + Vector3(0, 0.5, 0)
		p.one_shot = true
		p.amount = 18
		p.lifetime = 1.2
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 7.5
		p.gravity = Vector3(0, -9, 0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 0.02, 0.09)
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.2, true, false, true).timeout.connect(p.queue_free)

## --- presentation ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_vis_t += delta
	if phase == Phase.WAIT:
		return
	if _event_label.visible and now > _event_until:
		_event_label.visible = false
	if _hint_label.visible and now > 9.0:
		_hint_label.visible = false
	if _shake > 0.002:
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-5.0 * delta))
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	# shortcut arrow bob
	var arrow := track.get_node_or_null("ScArrow")
	if arrow != null:
		(arrow as Node3D).position.y = 1.7 + 0.22 * sin(_vis_t * 3.2)
	_shotsec_tick()

func _shotsec_tick() -> void:
	if _shotsec.is_empty():
		return
	if _vis_t < float(_shotsec[0]):
		return
	_shotsec.pop_front()
	_shot_i += 1
	var idx := _shot_i
	_capture_shot(idx)

func _capture_shot(idx: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	var path := "res://verify_out/shotsec_%02d.png" % idx
	img.save_png(path)
	print("SHOTSEC ", path)
	if _shotsec.is_empty() and _autoquit:
		get_tree().quit()

## --- UI -----------------------------------------------------------------------------------------

func _build_ui() -> void:
	var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	var baloo: Font = load("res://assets/fonts/Baloo2.ttf")
	var ui := CanvasLayer.new()
	add_child(ui)
	_timer_label = _mk_label(lg, 38, 9)
	_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_timer_label.offset_top = 6
	ui.add_child(_timer_label)
	_lap_label = _mk_label(lg, 26, 7)
	_lap_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lap_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_lap_label.offset_top = 52
	ui.add_child(_lap_label)
	_event_label = _mk_label(baloo, 23, 6)
	_event_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_event_label.offset_top = 88
	_event_label.visible = false
	ui.add_child(_event_label)
	_banner = RichTextLabel.new()
	_banner.bbcode_enabled = true
	_banner.fit_content = true
	_banner.scroll_active = false
	_banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.offset_top = 250.0
	_banner.add_theme_font_override("normal_font", lg)
	_banner.add_theme_font_size_override("normal_font_size", 52)
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.09))
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.visible = false
	ui.add_child(_banner)
	_score_rows = VBoxContainer.new()
	_score_rows.position = Vector2(16, 10)
	ui.add_child(_score_rows)
	_hint_label = _mk_label(baloo, 19, 6)
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.offset_bottom = -8
	_hint_label.text = "STEER move · A = THROW SWAP ORB (trades places!) · hold B = DRIFT, release = BOOST"
	_hint_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	ui.add_child(_hint_label)

func _mk_label(font: Font, size: int, outline: int) -> Label:
	var l := Label.new()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.09))
	l.add_theme_constant_override("outline_size", outline)
	return l

func _update_score_rows() -> void:
	if _row_labels.is_empty():
		var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
		for i in karts.size():
			var l := _mk_label(lg, 24, 7)
			_score_rows.add_child(l)
			_row_labels.append(l)
	var order := _positions_list()
	for pi in order.size():
		var kart: SwapKart = karts[order[pi]]
		var l: Label = _row_labels[pi]
		var extra := ""
		if kart.finished:
			extra = "  FIN"
		elif kart.has_golden:
			extra = "  [GOLD ORB]"
		l.text = "P%d %s · %d%s" % [pi + 1, kart.pname, int(_points[kart.index]), extra]
		l.add_theme_color_override("font_color", kart.color)

func _update_timer_label() -> void:
	var t := int(race_t)
	_timer_label.text = "%d:%02d" % [t / 60, t % 60]
	_timer_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.35) if time_cap - race_t < 20.0 and phase == Phase.PLAY else Color.WHITE)
	var lead := _leader_all()
	var lead_lap: int = clampi((karts[lead] as SwapKart).laps_hw + 1, 1, laps_total)
	if phase == Phase.END:
		_lap_label.text = "RACE OVER"
	else:
		_lap_label.text = "LAP %d/%d" % [lead_lap, laps_total]

func _flash_banner(bb: String, duration: float) -> void:
	_banner_gen += 1
	var gen := _banner_gen
	_banner.text = "[center]%s[/center]" % bb
	_banner.visible = true
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.5, 0.5)
	var pop := create_tween()
	pop.tween_property(_banner, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func() -> void:
			if _banner_gen == gen:
				_banner.visible = false)

func _flash_event(text: String, color: Color) -> void:
	_event_label.text = text
	_event_label.add_theme_color_override("font_color", color)
	_event_label.visible = true
	_event_until = now + 2.4

## --- debug/verify surface -------------------------------------------------------------------------

func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_playing() -> bool:
	return phase == Phase.PLAY
