extends Minigame
## MOWER MAYHEM — riding mowers on the estate's back lawn. Mow stripes in your
## color, ram rivals to steal their turf. Coverage IS score (Splatoon meets
## bumper cars). Grid-based coverage (64x48) drives ONE plane + ONE shader via
## ONE data texture — no per-cell nodes (see mower_lawn.gd).
##
## Anthology module: root of minigames/mower/mower.tscn, extends Minigame.
## Runs standalone too — if begin() hasn't been called 0.5s after _ready, it
## self-starts with a 4-player config (GameState colors/names, KayKit chars,
## seed from `--seed=` or 1).
##
## CLI user args (after `--`):
##   --mowbots            all players are seeded self-play bots
##   --seed=N             rng seed for standalone start (default 1)
##   --players=N          standalone roster size 2..4
##   --roundtime=S        override the 120s round (min 12)
##   --covtest            headless: run a fast round, assert coverage sum,
##                        print PASS/FAIL, quit (spec "coverage math" test)
##   --shots=N,...        handled by the VerifyCapture autoload (PNGs)

enum Phase { WAITING, INTRO, PLAY, RESULTS }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const GRAVE_SCENE := "res://scenes/gravestone.tscn"
const ROUND_TIME := 120.0
const OVERTIME_LEN := 20.0
const RAM_HALF_ANGLE := 0.15     # dot threshold facing vs victim
const STEAL_BURST := 6

var roster: Array = []
var round_time := ROUND_TIME
var rng := RandomNumberGenerator.new()
var practice := false

var lawn: MowerLawn
var mowers: Array = []            # MowerUnit per roster slot
var bots: MowerBots
var bot_enabled: Array = []

var phase := Phase.WAITING
var phase_t := 0.0
var round_t := 0.0
var overtime := false
var _ot_start := 100.0
var _ot_pulse := 0.0
var _score_t := 0.0

var _currency: Array = []
var _results := {}
var _begun := false
var _reported := false
var _standalone := false

var _bots_all := false
var _covtest := false
var _cli_seed := 1
var _cli_players := 4
var _cli_roundtime := -1.0

var _shake := 0.0
var _slowmo := false
var _engine_i := 0
var _engine_t := 0.0
var _last_status := 0.0
var _worst_step_ms := 0.0
var _over12 := 0
var _paint_worst_ms := 0.0
var _commit_worst_ms := 0.0
var _ram_count := 0
var _frame_prev_us := 0
var _worst_frame_ms := 0.0
var _frames_over_12 := 0
var _frame_count := 0
var _vc: Node = null

# UI built in code
var _meter_bar: HBoxContainer
var _meter_segs: Array = []       # {rect: ColorRect, label: Label} per player
var _uncut_seg: ColorRect

@onready var cam: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var timer_label: Label = $UI/TimerLabel
@onready var banner: Label = $UI/Banner
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows
@onready var meter_holder: Control = $UI/MeterHolder

func _ready() -> void:
	_parse_args()
	_vc = get_node_or_null("/root/VerifyCapture")
	_build_environment()
	banner.visible = false
	timer_label.text = ""
	await get_tree().create_timer(0.5).timeout
	if not _begun:
		_standalone = true
		begin(_default_config())

func begin(config: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	roster = config.roster
	rng.seed = int(config.rng_seed)
	practice = bool(config.get("practice", false))
	if _cli_roundtime > 0.0:
		round_time = maxf(12.0, _cli_roundtime)
	elif practice:
		round_time = 45.0
	if _covtest:
		round_time = 18.0
	# overtime = final 20s of a full round; on short test rounds fall back to
	# the last 40% so a truncated round still exercises the OT path once.
	_ot_start = maxf(round_time - OVERTIME_LEN, round_time * 0.6)
	# lawn + obstacles
	lawn = MowerLawn.new()
	lawn.name = "Lawn"
	add_child(lawn)
	var colors: Array = []
	for pl in roster:
		colors.append(pl.color)
	while colors.size() < 4:
		colors.append(Color.WHITE)
	lawn.build(colors)
	_build_obstacles()
	# bots
	bots = MowerBots.new()
	bots.setup(int(config.rng_seed) ^ 0x30FA, roster.size())
	# Per-player: a seat is bot-driven if the roster says so (shell sets this
	# from estate._is_bot; standalone fills it from PlayerInput) OR the legacy
	# --mowbots / --covtest flags force ALL bots. Decided here at begin() from
	# roster data only - never runtime Input - so the tick sim stays reproducible.
	bot_enabled.clear()
	for i in roster.size():
		bot_enabled.append(_bots_all or _covtest or bool(roster[i].get("bot", false)))
	# mowers
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var mu := MowerUnit.new()
		mu.name = "Mower%d" % i
		add_child(mu)
		mu.setup(i, str(pl.name), pl.color, str(pl.char_scene))
		var sp := _spawn_pos(i)
		mu.reset(sp, (-sp).normalized())
		mowers.append(mu)
	_build_meter()
	_rebuild_scoreboard()
	_log("begin players=%d seed=%d roundtime=%.0f bots=%s covtest=%s" % [
		roster.size(), int(config.rng_seed), round_time, str(bot_enabled), _covtest])
	_start_round()

# -- world --------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.86, 0.90, 0.82)
	sky_mat.ground_bottom_color = Color(0.20, 0.30, 0.16)
	sky_mat.ground_horizon_color = Color(0.55, 0.66, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun.rotation_degrees = Vector3(-58, 40, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	# camera: high 3/4, whole 16x12 lawn filling the frame
	cam.position = Vector3(0, 15.0, 10.2)
	cam.look_at(Vector3(0, 0, -0.2))
	cam.fov = 52.0

## Low hedge walls around the lawn so the arena reads as enclosed grounds.
func _build_hedges() -> void:
	var specs := [
		{"p": Vector3(0, 0.35, -MowerLawn.HZ - 0.2), "s": Vector3(2 * MowerLawn.HX + 1.0, 0.7, 0.4)},
		{"p": Vector3(0, 0.35, MowerLawn.HZ + 0.2), "s": Vector3(2 * MowerLawn.HX + 1.0, 0.7, 0.4)},
		{"p": Vector3(-MowerLawn.HX - 0.2, 0.35, 0), "s": Vector3(0.4, 0.7, 2 * MowerLawn.HZ + 1.0)},
		{"p": Vector3(MowerLawn.HX + 0.2, 0.35, 0), "s": Vector3(0.4, 0.7, 2 * MowerLawn.HZ + 1.0)},
	]
	for sp in specs:
		var h := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sp.s
		h.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.14, 0.30, 0.13)
		m.roughness = 1.0
		h.material_override = m
		h.position = sp.p
		add_child(h)

func _build_obstacles() -> void:
	_build_hedges()
	# birdbath — central circular no-mow zone
	_spawn_birdbath(Vector2(0.0, -0.4), 0.85)
	# flowerbeds — rectangular no-mow zones
	_spawn_flowerbed(Vector2(-4.6, 3.1), Vector2(1.1, 0.7))
	_spawn_flowerbed(Vector2(4.6, -3.1), Vector2(1.1, 0.7))
	# gravestone bumpers (reuse the estate prop; on-brand) — solid, not no-mow
	for gp in [Vector2(3.6, 3.0), Vector2(-3.6, -3.0), Vector2(-5.8, 1.2), Vector2(5.8, -1.2)]:
		_spawn_gravestone(gp)

func _spawn_birdbath(c: Vector2, r: float) -> void:
	lawn.add_bed_circle(c, r)
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.18
	bm.bottom_radius = 0.28
	bm.height = 0.6
	base.mesh = bm
	base.material_override = _stone()
	base.position = Vector3(c.x, 0.3, c.y)
	add_child(base)
	var bowl := MeshInstance3D.new()
	var bwm := CylinderMesh.new()
	bwm.top_radius = 0.52
	bwm.bottom_radius = 0.28
	bwm.height = 0.18
	bowl.mesh = bwm
	bowl.material_override = _stone()
	bowl.position = Vector3(c.x, 0.66, c.y)
	add_child(bowl)
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.46
	wm.bottom_radius = 0.46
	wm.height = 0.04
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.35, 0.6, 0.75)
	wmat.roughness = 0.1
	wmat.metallic = 0.3
	water.material_override = wmat
	water.position = Vector3(c.x, 0.73, c.y)
	add_child(water)

func _spawn_flowerbed(c: Vector2, half: Vector2) -> void:
	lawn.add_bed_rect(c, half)
	# soil box
	var soil := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(half.x * 2.0, 0.16, half.y * 2.0)
	soil.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.28, 0.18, 0.11)
	smat.roughness = 1.0
	soil.material_override = smat
	soil.position = Vector3(c.x, 0.08, c.y)
	add_child(soil)
	# flowers (small colored spheres) — deterministic scatter
	var petals := [Color(0.9, 0.3, 0.4), Color(0.95, 0.8, 0.25), Color(0.7, 0.4, 0.85), Color(0.95, 0.95, 0.95)]
	var n := 0
	for fx in range(-1, 2):
		for fz in range(-1, 2):
			var f := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.11
			fm.height = 0.22
			f.mesh = fm
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = petals[n % petals.size()]
			f.material_override = fmat
			f.position = Vector3(c.x + fx * half.x * 0.55, 0.24, c.y + fz * half.y * 0.55)
			add_child(f)
			n += 1

func _spawn_gravestone(c: Vector2) -> void:
	var ps := load(GRAVE_SCENE) as PackedScene
	if ps == null:
		return
	var g := ps.instantiate()
	add_child(g)
	g.position = Vector3(c.x, 0.0, c.y)
	g.rotation.y = rng.randf_range(-0.3, 0.3)
	# solid bumper circle (mowers bounce; grass under it stays mowable)
	lawn.solid_circles.append({"c": c, "r": 0.34})

func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.61, 0.64)
	m.roughness = 0.85
	return m

# -- round flow ---------------------------------------------------------------

func _start_round() -> void:
	phase = Phase.INTRO
	phase_t = 0.0
	round_t = 0.0
	overtime = false
	_last_status = 0.0
	_worst_step_ms = 0.0
	_over12 = 0
	_flash_banner("MOW!", Color(1, 0.9, 0.3), 1.0)
	hint_label.visible = true
	Sfx.play("confirm")

func _physics_process(delta: float) -> void:
	if phase == Phase.WAITING:
		return
	phase_t += delta
	match phase:
		Phase.INTRO:
			if phase_t >= 1.2:
				phase = Phase.PLAY
				round_t = 0.0
		Phase.PLAY:
			var t0 := Time.get_ticks_usec()
			_tick_play(delta)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0
			if ms > _worst_step_ms:
				_worst_step_ms = ms
			if ms > 12.0:
				_over12 += 1
				print("MOWER_PERF frame step=%.2fms (>12) t=%.1f" % [ms, round_t])
		Phase.RESULTS:
			if phase_t >= 3.0 and not _reported:
				_reported = true
				report_finished(_results)
				# automated all-bot soak/demo self-terminates (no shell attached)
				if _bots_all and _standalone:
					get_tree().quit(0)

func _tick_play(delta: float) -> void:
	round_t += delta
	# overtime trigger
	if not overtime and round_t >= _ot_start:
		_enter_overtime()
	# drive each mower
	for p in roster.size():
		mowers[p].drive(delta, _input_for(p, delta))
	# collisions: mower-mower (incl. ram), mower-solid, walls
	_resolve_mowers()
	_resolve_solids()
	# cut: paint the deck under each mower. This loop + commit() (in _process)
	# ARE the "engineering heart" the perf spec cares about; time it in isolation.
	var pt0 := Time.get_ticks_usec()
	for p in roster.size():
		var mu: MowerUnit = mowers[p]
		if mu.spin_t > 0.0:
			continue
		var moved := mu.vel.length() * delta
		var res := lawn.paint_deck(mu.deck_center(), mu.facing, mu.deck_half_w(overtime), MowerUnit.DECK_LEN * 0.5, mu.owner_code)
		mu.note_cut(moved, res)
	var pms := float(Time.get_ticks_usec() - pt0) / 1000.0
	if pms > _paint_worst_ms:
		_paint_worst_ms = pms
	# timeout
	if round_t >= round_time:
		_end_round()
		return
	# periodic status + soak log
	if round_t - _last_status >= 5.0:
		_last_status = round_t
		var bits: Array = []
		for p in roster.size():
			bits.append("%s=%.1f%%" % [roster[p].name, lawn.coverage_pct(p)])
		_log("status t=%.0f cov[%s] uncut=%.1f%% rams=%d paint_worst=%.3fms commit_worst=%.3fms" % [
			round_t, ", ".join(bits), lawn.uncut_pct(), _ram_count, _paint_worst_ms, _commit_worst_ms])

func _resolve_mowers() -> void:
	for a in roster.size():
		var ma: MowerUnit = mowers[a]
		for b in range(a + 1, roster.size()):
			var mb: MowerUnit = mowers[b]
			var d := mb.pos - ma.pos
			var dist := d.length()
			var min_d := MowerUnit.RADIUS * 2.0
			if dist < min_d and dist > 0.001:
				var n := d / dist
				# ram check BEFORE separation so impact point is the contact
				var impact := (ma.pos + mb.pos) * 0.5
				if ma.is_ramming() and mb.spin_t <= 0.0 and ma.facing.dot(n) > RAM_HALF_ANGLE:
					_do_ram(a, b, impact, n)
				elif mb.is_ramming() and ma.spin_t <= 0.0 and mb.facing.dot(-n) > RAM_HALF_ANGLE:
					_do_ram(b, a, impact, -n)
				var push := n * (min_d - dist) * 0.5
				ma.pos -= push
				mb.pos += push

func _do_ram(attacker: int, victim: int, impact: Vector2, n: Vector2) -> void:
	var ma: MowerUnit = mowers[attacker]
	var mv: MowerUnit = mowers[victim]
	ma.ram_t = 0.0   # spend the lunge
	# spin direction from cross product of attack dir and contact normal
	var dir := 1.0 if (ma.facing.x * n.y - ma.facing.y * n.x) >= 0.0 else -1.0
	mv.spin_out(dir)
	var stolen := lawn.steal_burst(impact, ma.owner_code, STEAL_BURST)
	ma.cells_stolen += stolen
	ma.ram_cells += stolen
	ma.ram_spinouts += 1
	_currency.append({"type": "royalty", "player": attacker, "amount": 1,
		"reason": "rammed %s and stole their turf" % mv.pname})
	# juice (banner/particles/tween/node-creation) is deferred so it lands in
	# idle time, keeping the physics step itself cheap (perf: <12ms/frame).
	call_deferred("_ram_juice", ma.pname, mv.pname, ma.pcolor, impact)
	_ram_count += 1  # counted here, printed at the 5s status (no per-ram I/O)

func _ram_juice(aname: String, vname: String, color: Color, impact: Vector2) -> void:
	_flash_banner("%s RAMMED %s!" % [aname, vname], color, 1.4)
	Sfx.play("bumper", -2.0)
	Sfx.play("splat", -4.0)
	_shake = maxf(_shake, 0.35)
	_slow_mo()
	_burst_fx(Vector3(impact.x, 0.4, impact.y), color)

func _resolve_solids() -> void:
	for p in roster.size():
		var mu: MowerUnit = mowers[p]
		for s in lawn.solid_circles:
			var c: Vector2 = s.c
			var r: float = float(s.r) + MowerUnit.RADIUS
			var d := mu.pos - c
			var dist := d.length()
			if dist < r and dist > 0.001:
				var n := d / dist
				mu.pos = c + n * r
				# bounce heading away from the obstacle
				if mu.facing.dot(n) < 0.0:
					mu.facing = mu.facing.bounce(n).normalized()
		# arena walls
		var lim_x := MowerLawn.HX - MowerUnit.RADIUS
		var lim_z := MowerLawn.HZ - MowerUnit.RADIUS
		if mu.pos.x < -lim_x:
			mu.pos.x = -lim_x
			mu.facing = mu.facing.bounce(Vector2(1, 0)).normalized() if mu.facing.x < 0 else mu.facing
		elif mu.pos.x > lim_x:
			mu.pos.x = lim_x
			mu.facing = mu.facing.bounce(Vector2(-1, 0)).normalized() if mu.facing.x > 0 else mu.facing
		if mu.pos.y < -lim_z:
			mu.pos.y = -lim_z
			mu.facing = mu.facing.bounce(Vector2(0, 1)).normalized() if mu.facing.y < 0 else mu.facing
		elif mu.pos.y > lim_z:
			mu.pos.y = lim_z
			mu.facing = mu.facing.bounce(Vector2(0, -1)).normalized() if mu.facing.y > 0 else mu.facing
		mu._apply_transform()

func _enter_overtime() -> void:
	overtime = true
	lawn.set_overtime(1.0)
	_flash_banner("OVERTIME!\nDOUBLE-WIDE CUTS", Color(1, 0.35, 0.25), 2.4)
	Sfx.play("grudge")
	Sfx.play("round_over", -4.0)
	_shake = maxf(_shake, 0.25)
	_log("overtime t=%.1f" % round_t)

func _end_round() -> void:
	phase = Phase.RESULTS
	phase_t = 0.0
	lawn.commit()
	# coverage math assert (spec "Risks & tests")
	var sum := lawn.uncut_pct()
	for p in roster.size():
		sum += lawn.coverage_pct(p)
	# beds are excluded from the mowable denominator, so player% + uncut% == 100
	var ok: bool = absf(sum - 100.0) <= 0.5
	print("MOWER_COVERAGE_ASSERT sum=%.4f%% (players+uncut) -> %s" % [sum, "PASS" if ok else "FAIL"])
	for p in roster.size():
		print("  %s: %.2f%%  stolen=%d bestStripe=%.1fm rams=%d" % [
			roster[p].name, lawn.coverage_pct(p), mowers[p].cells_stolen,
			mowers[p].best_stripe, mowers[p].ram_spinouts])
	print("MOWER_PERF grid_path: paint_worst=%.3fms commit_worst=%.3fms (the batched texture path) | sim_step worst=%.2fms over12=%d | full_frame worst=%.2fms over12=%d of %d frames | total_rams=%d" % [
		_paint_worst_ms, _commit_worst_ms, _worst_step_ms, _over12, _worst_frame_ms, _frames_over_12, _frame_count, _ram_count])
	_build_results()
	# celebrate the winner
	var winner: int = _results.placements[0]
	mowers[winner].cheer()
	_confetti(Vector3(mowers[winner].pos.x, 1.4, mowers[winner].pos.y), roster[winner].color)
	var wpl: Dictionary = roster[winner]
	_flash_banner("%s TAKES THE LAWN!\n%.0f%%" % [wpl.name, lawn.coverage_pct(winner)], wpl.color, 9999.0)
	Sfx.play("match_win")
	timer_label.text = ""
	hint_label.visible = false
	if _covtest:
		_log("covtest done")
		get_tree().quit(0 if ok else 1)

func _build_results() -> void:
	var order: Array = range(roster.size())
	order.sort_custom(func(a, b):
		var ca := lawn.coverage_pct(a)
		var cb := lawn.coverage_pct(b)
		if not is_equal_approx(ca, cb):
			return ca > cb
		return a < b)
	var points := {}
	for p in roster.size():
		points[p] = int(round(lawn.coverage_pct(p) / 5.0))
	# grudge: last place in coverage
	var last: int = order[order.size() - 1]
	_currency.append({"type": "grudge", "player": last, "amount": 1,
		"reason": "mowed the least of anyone"})
	# highlights
	var highlights: Array = []
	var thief := _stat_leader("ram_spinouts")
	if thief >= 0 and mowers[thief].ram_spinouts > 0:
		highlights.append("%s hijacked rivals' turf %d times" % [roster[thief].name, mowers[thief].ram_spinouts])
	var striper := _stat_leader("best_stripe")
	if striper >= 0 and mowers[striper].best_stripe >= 3.0:
		highlights.append("%s laid a %.1fm unbroken stripe" % [roster[striper].name, mowers[striper].best_stripe])
	var champ: int = order[0]
	highlights.append("%s covered %.0f%% of the lawn" % [roster[champ].name, lawn.coverage_pct(champ)])
	# monuments: Groundskeeper for >40% coverage
	var monuments: Array = []
	for p in roster.size():
		if lawn.coverage_pct(p) > 40.0:
			monuments.append({"player": p, "kind": "groundskeeper",
				"label": "%s, Groundskeeper of the Estate" % roster[p].name})
	_results = {
		"placements": order,
		"points": points,
		"currency_events": _currency.duplicate(),
		"highlights": highlights.slice(0, 3),
		"monuments": monuments,
	}
	_log("results " + JSON.stringify(_results))

func _stat_leader(field: String) -> int:
	var best := -1
	var best_v := -1.0
	for p in roster.size():
		var v: float = float(mowers[p].get(field))
		if v > best_v:
			best_v = v
			best = p
	return best

# -- input / bots -------------------------------------------------------------

func _input_for(p: int, _delta: float) -> Dictionary:
	if bot_enabled[p]:
		return bots.decide(p, self, _delta)
	# get_move: y = forward(-1)/back(+1). Camera looks down the -Z axis, so
	# stick-up (y=-1) is world -Z = "up the screen" = forward. Feed the stick
	# vector straight through as an XZ world heading; no flip needed.
	return {
		"move": PlayerInput.get_move(p),
		"a": PlayerInput.just_pressed(p, "a"),
		"b": PlayerInput.is_down(p, "b"),
	}

# -- juice / hud --------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.WAITING:
		return
	# real per-frame wall time (full cost: sim + grid commit + UI + fx)
	var now := Time.get_ticks_usec()
	if _frame_prev_us > 0 and phase == Phase.PLAY:
		var fms := float(now - _frame_prev_us) / 1000.0
		_frame_count += 1
		if fms > _worst_frame_ms:
			_worst_frame_ms = fms
		if fms > 12.0:
			_frames_over_12 += 1
	_frame_prev_us = now
	# push the batched coverage image to the GPU ONCE per frame
	if lawn:
		var ct0 := Time.get_ticks_usec()
		lawn.commit()
		var cms := float(Time.get_ticks_usec() - ct0) / 1000.0
		if phase == Phase.PLAY and cms > _commit_worst_ms:
			_commit_worst_ms = cms
	# camera shake
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.4)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	# engine put-put: stagger ticks across mowers so it reads as chugging
	_engine_t -= delta
	if _engine_t <= 0.0 and phase == Phase.PLAY and not mowers.is_empty():
		_engine_t = 0.11
		_engine_i = (_engine_i + 1) % mowers.size()
		mowers[_engine_i].engine_tick()
	# overtime meter pulse
	if overtime:
		_ot_pulse += delta * 6.0
	# HUD
	if phase == Phase.PLAY or phase == Phase.INTRO:
		var remain := int(ceil(maxf(0.0, round_time - round_t)))
		timer_label.text = str(remain)
		var hot := overtime or remain <= 10
		timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.25) if hot else Color(0.15, 0.35, 0.1))
	_update_meter()
	_score_t -= delta
	if _score_t <= 0.0:
		_score_t = 0.2
		_rebuild_scoreboard()

func _slow_mo() -> void:
	if _slowmo or _covtest:
		return
	_slowmo = true
	Engine.time_scale = 0.4
	await get_tree().create_timer(0.22, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo = false

func _burst_fx(pos: Vector3, color: Color) -> void:
	var pt := CPUParticles3D.new()
	add_child(pt)
	pt.global_position = pos
	pt.one_shot = true
	pt.amount = 22
	pt.lifetime = 0.5
	pt.explosiveness = 1.0
	pt.direction = Vector3.UP
	pt.spread = 65.0
	pt.initial_velocity_min = 3.0
	pt.initial_velocity_max = 6.5
	pt.gravity = Vector3(0, -10, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.03, 0.12)
	pt.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	pt.material_override = mat
	pt.emitting = true
	get_tree().create_timer(1.2).timeout.connect(pt.queue_free)

func _confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var pt := CPUParticles3D.new()
		add_child(pt)
		pt.global_position = pos
		pt.one_shot = true
		pt.amount = 20
		pt.lifetime = 1.4
		pt.explosiveness = 1.0
		pt.direction = Vector3.UP
		pt.spread = 55.0
		pt.initial_velocity_min = 4.0
		pt.initial_velocity_max = 7.5
		pt.gravity = Vector3(0, -7.0, 0)
		pt.angular_velocity_min = -360.0
		pt.angular_velocity_max = 360.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 0.03, 0.09)
		pt.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		pt.material_override = mat
		pt.emitting = true
		get_tree().create_timer(2.4).timeout.connect(pt.queue_free)

func _flash_banner(text: String, color: Color, duration: float) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func() -> void: banner.visible = false)

# -- meter (Splatoon-style top bar) -------------------------------------------

func _build_meter() -> void:
	_meter_bar = HBoxContainer.new()
	_meter_bar.add_theme_constant_override("separation", 3)
	_meter_bar.anchor_right = 1.0
	_meter_bar.offset_left = 16
	_meter_bar.offset_right = -16
	_meter_bar.offset_top = 10
	_meter_bar.offset_bottom = 52
	meter_holder.add_child(_meter_bar)
	_meter_segs.clear()
	for p in roster.size():
		var rect := ColorRect.new()
		rect.color = Color(roster[p].color, 0.82)
		rect.size_flags_horizontal = Control.SIZE_FILL
		rect.size_flags_stretch_ratio = 1.0
		rect.custom_minimum_size = Vector2(4, 42)
		var lbl := Label.new()
		lbl.add_theme_font_override("font", load("res://assets/fonts/LuckiestGuy-Regular.ttf"))
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		rect.add_child(lbl)
		_meter_bar.add_child(rect)
		_meter_segs.append({"rect": rect, "label": lbl})
	_uncut_seg = ColorRect.new()
	_uncut_seg.color = Color(0.12, 0.24, 0.09, 0.7)
	_uncut_seg.size_flags_horizontal = Control.SIZE_FILL
	_uncut_seg.custom_minimum_size = Vector2(2, 42)
	_meter_bar.add_child(_uncut_seg)

func _update_meter() -> void:
	if _meter_bar == null or lawn == null:
		return
	var pulse := 1.0 + (0.15 * sin(_ot_pulse) if overtime else 0.0)
	for p in roster.size():
		var seg: Dictionary = _meter_segs[p]
		var cov := lawn.coverage_pct(p)
		var rect: ColorRect = seg.rect
		rect.size_flags_stretch_ratio = maxf(0.02, cov)
		rect.color = Color(roster[p].color, 0.82)
		var lbl: Label = seg.label
		lbl.text = "%d%%" % int(round(cov))
		lbl.add_theme_color_override("font_color", Color.WHITE if cov > 6 else Color(1, 1, 1, 0))
	_uncut_seg.size_flags_stretch_ratio = maxf(0.02, lawn.uncut_pct())
	if overtime:
		_meter_bar.scale = Vector2(1, pulse)
		_meter_bar.pivot_offset = Vector2(_meter_bar.size.x * 0.5, 0)

func _rebuild_scoreboard() -> void:
	if score_rows == null or lawn == null:
		return
	for c in score_rows.get_children():
		c.queue_free()
	# standings by live coverage
	var order: Array = range(roster.size())
	order.sort_custom(func(a, b): return lawn.coverage_pct(a) > lawn.coverage_pct(b))
	for i in order.size():
		var p: int = order[i]
		var mu: MowerUnit = mowers[p] if p < mowers.size() else null
		var fuel := int(round((mu.fuel if mu else 0.0) * 100.0))
		var row := Label.new()
		var tag := ""
		if mu and mu.spin_t > 0.0:
			tag = "  SPUN!"
		elif mu and mu.boosting:
			tag = "  BOOST"
		row.text = "%s  %.0f%%   fuel %d%%%s" % [roster[p].name, lawn.coverage_pct(p), fuel, tag]
		row.add_theme_font_size_override("font_size", 22)
		row.add_theme_color_override("font_color", roster[p].color)
		row.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
		row.add_theme_constant_override("outline_size", 5)
		score_rows.add_child(row)

# -- config / args ------------------------------------------------------------

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--mowbots":
			_bots_all = true
		elif arg == "--covtest":
			_covtest = true
			_bots_all = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--roundtime="):
			_cli_roundtime = float(arg.trim_prefix("--roundtime="))

func _default_config() -> Dictionary:
	PlayerInput.auto_assign(_cli_players)
	var r: Array = []
	for i in _cli_players:
		r.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": CHAR_FALLBACKS[i],
			"device": PlayerInput.device_of(i),
			"bot": PlayerInput.standalone_bot_default(i),
		})
	return {"roster": r, "rounds": 1, "rng_seed": _cli_seed, "practice": false}

func _spawn_pos(i: int) -> Vector2:
	var spots := [Vector2(-6.2, -4.2), Vector2(6.2, 4.2), Vector2(6.2, -4.2), Vector2(-6.2, 4.2)]
	return spots[i % spots.size()]

func _log(msg: String) -> void:
	var f := -1
	if _vc != null:
		f = int(_vc.frame)
	print("MOWER_EVT t=%.2f frame=%d | %s" % [round_t, f, msg])
