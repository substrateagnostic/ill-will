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
const ROUND_TIME := 45.0   # playtest (Andrew): 120s way too long — Mario Party pace
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
var _kill_events: Array = []   # {killer:int, victim:int, cause:String} per contract
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
# THE FINAL STRETCH kit (doc 09 §Q1): OVERTIME is mower's stretch — the kit
# adds the music escalation the VERIFY doc always claimed (light->tense at OT)
# + last-10s ticks + timer pulse around the bespoke "OVERTIME! DOUBLE-WIDE
# CUTS" banner. Never attached under --covtest (receipts untouched).
var _stretch: FinalStretch = null
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

# --- ONLINE PHASE 2: the render mirror (docs/design/10 §4.3; house pattern
# from minigames/seance/seance.gd). Host runs the WHOLE sim as couch; the
# estate pumps _net_state() to guests at 20 Hz. The 64x48 coverage grid — the
# game's engineering heart — rides the snapshot as ONE deflate-compressed
# PackedByteArray on every 2nd pump (10 Hz): full-grid latest-wins is
# self-healing (a drop costs 100 ms of lawn, never a cell) and every grid
# arrives internally consistent with the mower transforms beside it. The
# mirror re-derives coverage tallies from the applied grid, so the meter,
# scoreboard and the Splatoon tally ceremony all run their couch code paths.
var _mirror := false
var _mir := {}                    # last applied snapshot (delta source)
var _mir_mow := []                # per-mower interp targets
var _mir_tally_up := false        # local tally ceremony started (RESULTS)
var _snap_net_lawn := false       # paired lawn evidence snaps (host + mirror)
var _snap_mir_lawn := false
# host-side wire bookkeeping:
var _banner_col := "ffffff"
var _ram_last_a := -1             # last ram: attacker + impact (fx on rc delta)
var _ram_last_p := Vector2.ZERO
var _net_pump_n := 0

# UI built in code
var _meter_bar: HBoxContainer
var _meter_segs: Array = []       # {rect: ColorRect, label: Label} per player
var _uncut_seg: ColorRect

# tally ceremony (Splatoon-style turf reveal at time-up) — the count-up rows +
# winner beat now live in the shared ui_kit ResultsBoard; mower keeps the turf
# saturation + camera pull + 3D cheer and drives them off the board's signals.
var _tally_done := false
var _results_board: ResultsBoard = null
var _intro_card: IntroCard = null
var _tally_reveal_n := 0
var _tally_mid_snapped := false
var _tally_mid2_snapped := false

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
	_mirror = bool(config.get("net_mirror", false))
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
	if not _covtest:
		_stretch = FinalStretch.attach(self, timer_label)
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
	if not _mirror:
		# fenced from the mirror: bot construction (spec §4.3 begin() split)
		bots = MowerBots.new()
		bots.setup(int(config.rng_seed) ^ 0x30FA, roster.size())
	# Per-player: a seat is bot-driven if the roster says so (shell sets this
	# from estate._is_bot; standalone fills it from PlayerInput) OR the legacy
	# --mowbots / --covtest flags force ALL bots. Decided here at begin() from
	# roster data only - never runtime Input - so the tick sim stays reproducible.
	bot_enabled.clear()
	for i in roster.size():
		bot_enabled.append(not _mirror and (_bots_all or _covtest or bool(roster[i].get("bot", false))))
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
	if _mirror:
		# RENDER MIRROR: lawn, obstacles, mowers, meter and tally UI all stand
		# ready (identical deterministic build); the first _net_apply drives
		# everything. Hint bar is built from THIS machine's bindings.
		phase = Phase.WAITING
		var bar := _controls_bar()
		if bar != "":
			hint_label.text = bar
		hint_label.visible = true
		print("MOWER_MIRROR boot players=%d my_seat=%d" % [roster.size(), NetSession.my_seat()])
		return
	_log("begin players=%d seed=%d roundtime=%.0f bots=%s covtest=%s" % [
		roster.size(), int(config.rng_seed), round_time, str(bot_enabled), _covtest])
	# NIT 3: set the real-key hint bar NOW (not just at _start_round) so the bar
	# shown behind the intro card never reads the scene-authored abstract "A =".
	hint_label.text = _controls_bar()
	hint_label.visible = true
	_kickoff()

## Intro card (ui_kit) at load, then the round. --covtest skips the ceremony
## entirely (headless math assert stays byte-identical). Card auto-starts after
## 6s if no human presses A, so bot-only runs flow through untouched.
func _kickoff() -> void:
	if _covtest:
		_start_round()
		return
	_present_intro_card()

func _present_intro_card() -> void:
	_intro_card = IntroCard.new()
	add_child(_intro_card)
	_intro_card.started.connect(_start_round)
	_intro_card.present({
		"name": "MOWER MAYHEM",
		"goal": "Mow stripes in your color — coverage IS score.",
		"accent": Color(0.42, 0.82, 0.34),
		"seats": _human_seats(),
		"controls": [
			{"action": "move", "label": "STEER"},
			{"action": "a", "label": "RAM HORN"},
			{"action": "b", "label": "BOOST"},
		],
		"tips": [
			"Ram a rival head-on to steal a burst of their turf.",
			"OVERTIME widens every deck — double-wide cuts.",
			"Beds and the birdbath can't be mowed — steer around them.",
		],
	})
	if _vc != null:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _vc.snap("mower_intro"))

# -- world --------------------------------------------------------------------

func _build_environment() -> void:
	# THE HOUSE LOOK -- MOONLIT night lawn (core/env_kit.gd). Mowing happens under
	# the moon: a cool moon key rakes the grass, a warm fill keeps it from going
	# blue-dead, and the high-threshold glow blooms the bright cut stripes (the
	# live Splatoon coverage meter -- the score) HARDEST against the dark uncut
	# lawn. The UI-kit intro/results ride a CanvasLayer, untouched by the glow.
	# Replaces the old flat FILMIC day-sky env. ($Sun angle already matched MOONLIT.)
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"key_energy": 1.15,
		"ambient_energy": 0.5,   # lawn reads moonlit; the cut stripes still pop hardest
	})
	# the scene's static $Sun is superseded by EnvKit's key rig
	sun.visible = false
	sun.light_energy = 0.0
	# camera: high 3/4, whole 16x12 lawn filling the frame
	cam.position = Vector3(0, 15.0, 10.2)
	cam.look_at(Vector3(0, 0, -0.2))
	cam.fov = 52.0
	_build_b8_horizon()  # B8-HOOK: graveyard glimpsed past the hedges (arena_dressing.gd)

## B8 ARENA DRESSING — headstones, dead trees and a lamppost pair just past
## the hedge line (hedges sit at HX/HZ+0.2, so everything here starts at
## +0.8 to +2.6 beyond that), on-brand with the gravestone bumpers already
## reused inside the mowable lawn. Static, outside the 16x12 play rect, no
## collision. The two props on the near (+z, camera) side sit closer to the
## hedge than the rest — verified against the fixed camera (pos 0,15.0,10.2
## -> look_at 0,0,-0.2, fov 52): past ~z=+7.5 out here they'd drop below the
## bottom of frame at this pitch.
func _build_b8_horizon() -> void:
	var ring := [
		["estate_dead_tree", 3.0, Vector3(-MowerLawn.HX - 2.6, 0, -MowerLawn.HZ - 2.2), 40.0],
		["grave_headstone_plain", 1.1, Vector3(-MowerLawn.HX - 2.2, 0, 0), 15.0],
		["estate_dead_tree", 2.7, Vector3(-MowerLawn.HX - 2.6, 0, MowerLawn.HZ + 1.0), -30.0],
		["estate_lamppost", 2.6, Vector3(0, 0, -MowerLawn.HZ - 2.6), 0.0],
		["grave_headstone_cracked", 1.0, Vector3(MowerLawn.HX + 2.2, 0, -MowerLawn.HZ * 0.5), 200.0],
		["estate_lamppost", 2.6, Vector3(MowerLawn.HX + 2.6, 0, MowerLawn.HZ * 0.5), 0.0],
		["grave_small_obelisk", 1.5, Vector3(0, 0, MowerLawn.HZ + 1.0), 60.0],
	]
	for r in ring:
		var light := {} if str(r[0]) != "estate_lamppost" else \
			{"color": Color(1.0, 0.8, 0.5), "energy": 1.0, "range": 5.5}
		ArenaDressing.prop(self, str(r[0]), float(r[1]), r[2], float(r[3]), light)

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

# -- live-binding hint bar (real keys, not "A"/"B"; see docs/verify/realkeys-VERIFY.md) --

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). The
## main bar personalizes only these; an all-bot demo gets an empty list and keeps
## the generic scene-authored "A = ..." text.
func _human_seats() -> Array:
	var out := []
	for i in roster.size():
		# mirror: only MY seat is a human on THIS machine (the client estate
		# maps local devices to every seat, but those hands live elsewhere)
		if _mirror and i != NetSession.my_seat():
			continue
		if i < bot_enabled.size() and not bot_enabled[i] and PlayerInput.device_of(i) != -99:
			out.append(i)
	return out

## Seats whose bindings the hint bar prints: the live humans, or seat 0 as a
## representative when a bot-only demo has no humans — so the bar shows the SAME
## real key the intro card prints for glyph_seat 0, never an abstract "A =" verb
## (doc 14 item 13 / notation-consistency nit).
func _hint_seats() -> Array:
	var seats := _human_seats()
	return seats if not seats.is_empty() else [0]

## One button's live legend: "KEY = LABEL" when every hint seat shares the key
## (all pads -> "(A) = RAM HORN"), else the per-seat "LABEL: KEY/NAME · KEY/NAME"
## form (mixed keyboard + pad). Bindings are fixed per match, so this is built
## once when the round starts - no live polling.
func _btn_hint(action: String, label: String) -> String:
	var seats := _hint_seats()
	var keys := []
	var same := true
	for i in seats:
		var k := PlayerInput.describe_binding(int(i), action)
		if not keys.is_empty() and k != keys[0]:
			same = false
		keys.append(k)
	if same:
		return "%s = %s" % [keys[0], label]
	var parts := []
	for j in seats.size():
		parts.append("%s/%s" % [keys[j], GameState.PLAYER_NAMES[int(seats[j])]])
	return "%s: %s" % [label, " · ".join(parts)]

## The main bar, always real keys via describe_binding (matches the intro card).
func _controls_bar() -> String:
	return "MOVE = STEER   ·   %s   ·   %s   |   COVERAGE IS SCORE" % [
		_btn_hint("a", "RAM HORN"), _btn_hint("b", "BOOST")]

# -- round flow ---------------------------------------------------------------

func _start_round() -> void:
	phase = Phase.INTRO
	phase_t = 0.0
	round_t = 0.0
	overtime = false
	_last_status = 0.0
	_worst_step_ms = 0.0
	_over12 = 0
	if _stretch != null:
		_stretch.play_started()   # FINAL STRETCH: light bed under the mowing
	_flash_banner("THE GROUNDS NEED CUTTING", Color(1, 0.9, 0.3), 1.0)
	hint_label.visible = true
	var bar := _controls_bar()
	if bar != "":
		hint_label.text = bar
	Sfx.play("confirm")

func _physics_process(delta: float) -> void:
	# THE HOUSE GUARD (spec §4.3): a mirror never simulates. Interp + juice only.
	if _mirror:
		_mirror_tick(delta)
		return
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
			# hold until the tally ceremony finishes (~4.5s); the phase_t fallback
			# guarantees the round still reports if a reveal tween ever stalls.
			if (_tally_done or phase_t >= 6.0) and not _reported:
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
	# evidence snap (online nights only): the half-mowed lawn, paired with the
	# mirror's "mirror_lawn" snap fired from the same authoritative round clock.
	if not _snap_net_lawn and NetSession.has_guests() and round_t >= 20.0:
		_snap_net_lawn = true
		VerifyCapture.snap("net_lawn")
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
	_ram_last_a = attacker      # wire facts: the mirror's burst fx + shake
	_ram_last_p = impact
	_currency.append({"type": "royalty", "player": attacker, "amount": 1,
		"reason": "rammed %s and stole their turf" % mv.pname})
	# structured kill attribution (module contract): the ram spins the victim out
	# (SPINOUT_TIME loss of control) — a down at the exact royalty-crediting path.
	_kill_events.append({"killer": attacker, "victim": victim, "cause": "mowed"})
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
	if _stretch != null:
		_stretch.escalate()   # FINAL STRETCH: the OT sting mower always claimed
	_flash_banner("OVERTIME!\nDOUBLE-WIDE CUTS", Color(1, 0.35, 0.25), 2.4)
	Sfx.play("grudge")
	Sfx.play("round_over", -4.0)
	_shake = maxf(_shake, 0.25)
	# THE DECIDING MOMENT (doc 09 §Q2): OVERTIME is mower's sudden-death stakes-spike
	# — punch the camera in (the tally's own pull-BACK survey comes later on the
	# freeze beat). Self-gates on reduced-motion inside the kit.
	FinalStretch.fov_punch(cam, 52.0, 6.0, 0.8, "OVERTIME")
	_log("overtime t=%.1f" % round_t)

func _end_round() -> void:
	phase = Phase.RESULTS
	phase_t = 0.0
	if _stretch != null:
		_stretch.match_ended()   # nudge fades under the tally ceremony
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
	print("KILL_EVENTS n=", _kill_events.size(), " ", JSON.stringify(_kill_events))
	_build_results()
	timer_label.text = ""
	hint_label.visible = false
	# covtest is a headless math assert — skip the ceremony, quit immediately.
	if _covtest:
		_log("covtest done")
		get_tree().quit(0 if ok else 1)
		return
	# THE TALLY: withhold the winner and stage the Splatoon-style turf reveal.
	# Presentation only — _results is already built and never changes here.
	_run_tally()

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
		"kill_events": _kill_events.duplicate(),
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
		var jx := randf_range(-1, 1)
		cam.h_offset = jx * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
		ShakeKit.roll(cam, _shake, jx)   # rotational force, reusing the jitter above
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		ShakeKit.clear(cam)
	# engine put-put: stagger ticks across mowers so it reads as chugging
	_engine_t -= delta
	if _engine_t <= 0.0 and phase == Phase.PLAY and not mowers.is_empty():
		_engine_t = 0.11
		_engine_i = (_engine_i + 1) % mowers.size()
		mowers[_engine_i].engine_tick()
	# overtime meter pulse
	if overtime:
		_ot_pulse += delta * 6.0
	# HUD — frozen once the round ends so the tally ceremony withholds standings.
	if phase == Phase.PLAY or phase == Phase.INTRO:
		var remain := int(ceil(maxf(0.0, round_time - round_t)))
		timer_label.text = str(remain)
		var hot := overtime or remain <= 10
		timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.25) if hot else Color(0.15, 0.35, 0.1))
		# FINAL STRETCH ticks + timer pulse (host and mirror share this block —
		# the mirror's round_t is the authoritative host clock off the wire)
		if _stretch != null and phase == Phase.PLAY:
			_stretch.tick(round_time - round_t)
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
	_banner_col = color.to_html(false)
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

# -- tally ceremony (Splatoon turf reveal) ------------------------------------
# At time-up we WITHHOLD the winner: the live meter/scoreboard freeze and hide,
# the camera pulls to the whole lawn, and each player's turf saturates in turn
# (worst -> best) while a big 72pt count-up ticks their coverage 0 -> final.
# The winner is stamped last with a flourish. Presentation only: _results is
# already committed in _end_round and nothing here touches coverage/scoring.

## THE TALLY, expressed through the shared ui_kit ResultsBoard. mower keeps what
## is uniquely its own — the Splatoon turf saturation, the overhead camera pull,
## the winning mower's 3D cheer/confetti — and drives them off the board's beat
## signals. The count-up rows + winner hero beat are the kit's. Both the host
## (_end_round) and the net mirror (_net_apply) call this, so couch and client
## run the identical ceremony from the same placements + (mirrored) grid.
func _run_tally() -> void:
	# withhold the live standings — Splatoon hides the result and "calculates"
	if _meter_bar:
		_meter_bar.visible = false
	var panel := get_node_or_null("UI/ScorePanel")
	if panel:
		panel.visible = false
	lawn.set_tally(0, 0.0)
	banner.visible = false   # the board owns the title/winner banner now
	_tally_reveal_n = 0
	_tally_mid_snapped = false
	_tally_mid2_snapped = false
	var rows: Array = []
	for p in _results.placements:
		rows.append({
			"player": int(p),
			"score": lawn.coverage_pct(int(p)),
			"color": roster[int(p)].color,
			"name": str(roster[int(p)].name),
		})
	var board := ResultsBoard.new()
	add_child(board)
	_results_board = board
	board.freeze_beat.connect(_tally_camera_pull)
	board.row_started.connect(_on_tally_row_started)
	board.row_tick.connect(_on_tally_row_tick)
	board.winner_beat.connect(_on_tally_winner)
	board.done.connect(func() -> void: _tally_done = true)
	board.present(rows, {
		"title": "TALLYING...",
		"subtitle": "COVERAGE IS SCORE",
		"score_type": ResultsBoard.ScoreType.PERCENT,
		"win_title": "{name} TAKES THE LAWN",
		"accent": Color(1, 0.95, 0.55),
	})

## Each row reveal makes THAT player the spotlit owner (turf saturates, the rest
## recede); the mid-count evidence snap fires on the 2nd reveal.
func _on_tally_row_started(p: int) -> void:
	lawn.set_tally(p + 1, 0.0)
	_tally_reveal_n += 1

func _on_tally_row_tick(p: int, _shown: float, t: float) -> void:
	lawn.set_tally(p + 1, t)
	# two snaps a few frames apart on the SAME reveal, so the count-up is provably
	# animating (the digits differ between the pair).
	if _tally_reveal_n == 2 and _vc != null:
		if t >= 0.35 and not _tally_mid_snapped:
			_tally_mid_snapped = true
			_vc.snap("mower_midcount_a")
		elif t >= 0.78 and not _tally_mid2_snapped:
			_tally_mid2_snapped = true
			_vc.snap("mower_midcount_b")

## The protected winner beat: keep their turf lit + the 3D flourish mower always
## did (the banner + stamp pop are the board's).
func _on_tally_winner(winner: int) -> void:
	lawn.set_tally(winner + 1, 1.0)
	_shake = maxf(_shake, 0.4)
	mowers[winner].cheer()
	_confetti(Vector3(mowers[winner].pos.x, 1.4, mowers[winner].pos.y), roster[winner].color)
	if _vc != null:
		_vc.snap("mower_winner")

func _set_cam_pos(pos: Vector3) -> void:
	cam.position = pos
	cam.look_at(Vector3.ZERO)

func _tally_camera_pull() -> void:
	# lift to a fuller, more overhead framing so the whole lawn reads as a map
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_set_cam_pos, cam.position, Vector3(0.0, 20.0, 6.5), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "fov", 54.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(p, 22)
		badge.color = roster[p].color
		hb.add_child(badge)
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
		hb.add_child(row)
		score_rows.add_child(hb)

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

# ================================================================ ONLINE (phase 2)
# House pattern from minigames/seance/seance.gd (docs/design/10 §4.3): the
# _mirror guard, the begin() mirror branch, _net_state()/_net_apply() with
# juice-from-deltas. MOWER-specific: the coverage GRID rides the snapshot as
# one deflate-compressed byte array at 10 Hz (see mower_lawn.gd notes — the
# bandwidth math + rejected diff/event schemes live in the VERIFY doc), and
# the RESULTS phase hands the mirror its own LOCAL Splatoon tally ceremony,
# fed by the mirrored grid + the host's placements.

## HOST, pumped by the estate at 20 Hz (unreliable_ordered ch 4, latest wins).
func _net_state() -> Dictionary:
	_net_pump_n += 1
	var mws: Array = []
	for i in roster.size():
		var m: MowerUnit = mowers[i]
		var flags := 0
		if m.boosting:
			flags |= 1
		if m.spin_t > 0.0:
			flags |= 2
		if m.is_ramming():
			flags |= 4
		if m.spin_spd >= 0.0:
			flags |= 8
		mws.append([snappedf(m.pos.x, 0.01), snappedf(m.pos.y, 0.01),
			snappedf(atan2(m.facing.x, m.facing.y), 0.01), flags,
			snappedf(m.fuel, 0.02)])
	var st := {
		"ph": phase, "rt": snappedf(round_t, 0.01), "rtime": round_time,
		"ot": overtime, "mw": mws,
		"rc": _ram_count, "ra": _ram_last_a,
		"rp": [snappedf(_ram_last_p.x, 0.01), snappedf(_ram_last_p.y, 0.01)],
		"ban": [banner.text, _banner_col, banner.visible],
	}
	# the lawn itself: every 2nd pump (10 Hz), and EVERY pump once the round is
	# over so the tally ceremony is guaranteed the final grid.
	if _net_pump_n % 2 == 1 or phase == Phase.RESULTS:
		var packet := lawn.grid_packet()
		st["grid"] = packet
		if _net_pump_n % 40 == 1:
			print("MOWGRID side=host seq=%d h=%s raw=%d zbytes=%d" % [
				_net_pump_n, lawn.grid_hash(), MowerLawn.GW * MowerLawn.GH, packet.size()])
	if phase == Phase.RESULTS:
		st["plc"] = _results.get("placements", [])
	return st

## CLIENT. Latest-state-wins; juice fires from DELTAS. The grid is adopted
## wholesale (self-healing), then the couch _process — meter, scoreboard,
## timer, engine put-put, lawn.commit — renders it through untouched paths.
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	var first := prev.is_empty()
	round_time = float(state.get("rtime", round_time))
	round_t = float(state.get("rt", round_t))
	var ot: bool = bool(state.get("ot", false))
	if ot and not overtime:
		lawn.set_overtime(1.0)
		Sfx.play("grudge")
		Sfx.play("round_over", -4.0)
		_shake = maxf(_shake, 0.25)
		if _stretch != null:
			_stretch.escalate()   # FINAL STRETCH fires client-side off the ot fact
	overtime = ot
	# --- the authoritative lawn
	if state.has("grid"):
		lawn.mirror_apply_grid(state["grid"])
		if int(state.get("seq", 0)) % 40 == 1:
			print("MOWGRID side=client seq=%d h=%s" % [int(state.get("seq", 0)), lawn.grid_hash()])
	var ph := int(state.get("ph", Phase.WAITING))
	var prev_ph: int = int(prev.get("ph", -1))
	# banner mirrors until RESULTS — from there the LOCAL tally ceremony owns it
	if ph != Phase.RESULTS:
		_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	# --- mowers: poses are targets; the spin flag's rising edge is the hit
	var mws: Array = state.get("mw", [])
	var pmw: Array = prev.get("mw", [])
	_mir_mow = mws
	for i in mini(mws.size(), mowers.size()):
		var d: Array = mws[i]
		var flags := int(d[3])
		var pflags: int = int((pmw[i] as Array)[3]) if i < pmw.size() else 0
		if (flags & 2) != 0 and (pflags & 2) == 0:
			(mowers[i] as MowerUnit).mirror_spun()
		if first:
			(mowers[i] as MowerUnit).mirror_pose(Vector2(float(d[0]), float(d[1])),
				float(d[2]), false, (flags & 2) != 0, false, (flags & 1) != 0,
				1.0 if (flags & 8) != 0 else -1.0, float(d[4]))
	# --- ram flourish from the counter (banner rides ban; the host's slow-mo
	# already slows the snapshot stream, so the mirror never touches time_scale)
	if int(state.get("rc", 0)) > int(prev.get("rc", 0)):
		var ra := int(state.get("ra", -1))
		var rp: Array = state.get("rp", [])
		Sfx.play("bumper", -2.0)
		Sfx.play("splat", -4.0)
		_shake = maxf(_shake, 0.35)
		if ra >= 0 and ra < roster.size() and rp.size() >= 2:
			_burst_fx(Vector3(float(rp[0]), 0.4, float(rp[1])), (roster[ra] as Dictionary).color)
	# --- phase handoffs
	phase = ph
	if ph != prev_ph:
		print("MOWER_MIRROR phase -> %s rt=%.1f" % [Phase.keys()[ph], round_t])
		if ph == Phase.INTRO or (first and ph == Phase.PLAY):
			Sfx.play("confirm")
			if _stretch != null:
				_stretch.play_started()
	if ph == Phase.RESULTS and not _mir_tally_up:
		_mir_tally_up = true
		if _stretch != null:
			_stretch.match_ended()
		# the host's verdict + the mirrored final grid = the same ceremony,
		# staged locally: camera pull, per-player turf reveal, count-up, stamp.
		_results = {"placements": state.get("plc", range(roster.size()))}
		timer_label.text = ""
		hint_label.visible = false
		print("MOWER_MIRROR tally begins placements=%s" % [str(_results.placements)])
		_run_tally()
	# --- paired lawn evidence snap on the authoritative round clock
	if not _snap_mir_lawn and ph == Phase.PLAY and round_t >= 20.0:
		_snap_mir_lawn = true
		VerifyCapture.snap("mirror_lawn")

## CLIENT, per physics tick: 60 fps glide between 20 Hz snapshots.
func _mirror_tick(delta: float) -> void:
	if _mir.is_empty():
		return
	for i in mini(_mir_mow.size(), mowers.size()):
		var d: Array = _mir_mow[i]
		var mu: MowerUnit = mowers[i]
		var target := Vector2(float(d[0]), float(d[1]))
		var moving := (target - mu.pos).length() > 0.05
		var np := mu.pos.lerp(target, 1.0 - exp(-14.0 * delta))
		var fa := lerp_angle(atan2(mu.facing.x, mu.facing.y), float(d[2]),
			1.0 - exp(-14.0 * delta))
		var flags := int(d[3])
		mu.mirror_pose(np, fa, moving, (flags & 2) != 0, (flags & 4) != 0,
			(flags & 1) != 0, 1.0 if (flags & 8) != 0 else -1.0, float(d[4]))

func _apply_mir_banner(arr: Array, parr: Array) -> void:
	if arr.size() < 3:
		return
	banner.text = str(arr[0])
	banner.add_theme_color_override("font_color", Color(str(arr[1])))
	var was: bool = parr.size() >= 3 and bool(parr[2]) and str(parr[0]) == str(arr[0])
	banner.visible = bool(arr[2])
	if banner.visible and not was:
		banner.pivot_offset = banner.size / 2.0
		banner.scale = Vector2(0.6, 0.6)
		var pop := create_tween()
		pop.tween_property(banner, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
