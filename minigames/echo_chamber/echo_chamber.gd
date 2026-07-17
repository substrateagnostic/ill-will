extends Minigame
## ECHO CHAMBER — top-down arena brawl where every previous round replays as
## translucent ghosts. By round 5 the arena teems with everyone's recorded
## past selves, still fighting — and YOUR echoes earn YOU points when they
## land hits in the present ("PAST BLUE STRIKES AGAIN").
##
## Determinism spine: the controller owns one physics-step update order —
## tick live fighters, sample the 30Hz recorder from their post-move state,
## then replay ghosts by DIRECT transform application against those fresh
## positions. Ghost replay never touches physics, so recording->replay is
## drift-free (asserted each round: ghost end pos == recorded final +-0.01).
##
## Self-contained scene; obeys the anthology module contract (core/minigame.gd).

const ROUNDS := 5
const ROUND_LEN_DEFAULT := 45.0
const REC_HZ := 30.0
const MAX_FRAMES := 3200
const MAX_GHOSTS := 12
const HP_MAX := 3
const ARENA_R := 8.0
const SHRINK := 0.7
const RING_R := ARENA_R * SHRINK   # 5.6 — the yellow boundary ring & enforced edge
const RING_WARN_T := 1.5           # grace after leaving the ring before a ring-out KO
const RESPAWN_TIME := 2.0
const TRANSITION_TIME := 2.4
const INTRO_TIME := 1.6
const LIVE_HIT_PTS := 2
const GHOST_HIT_PTS := 1
const SURVIVE_BONUS := 3
const RESULT_HOLD := 8.5

const SWING_RANGE := 1.9
const SWING_HALF_ARC := deg_to_rad(60.0)
const HEAVY_RANGE := SWING_RANGE + 0.4
const HEAVY_HALF_ARC := deg_to_rad(75.0)   # 150deg total cone
const HEAVY_HIT_PTS := 2
const RIPOSTE_BONUS_PTS := 1
const PARRY_STAGGER_T := 0.6

# GHOST MEDDLING (doc 24 §6): the dead's ONE verb — a cold draft that STAGGERS the
# living within reach. Stagger adds no velocity, so it can never ring anyone out; a
# fighter already over the ring is skipped, so a death-in-progress is never decided.
const MEDDLE_GUST_R := 3.2
const MEDDLE_GUST_STAGGER := 0.22

const DEFAULT_CHARS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

enum St { INTRO, PLAY, TRANSITION, DONE }

# ---- config / roster ----
var _begun := false
var _selfstarted := false
var roster: Array = []
var rng := RandomNumberGenerator.new()
var _seed := 1
var _bots := false
var _rounds := ROUNDS             # honored from config.rounds (shell contract)
var round_len := ROUND_LEN_DEFAULT
var _cap_on := false
var _cap_dir := "verify_out"
var _cap_done: Dictionary = {}
var _aim_probe_on := false
var _aim_probe_deg := 0.0
var _ring_test := false            # dev: park fighter 0 outside the ring to film warning+KO
var _ringtest_state := 0
var _meddle_shot := false          # dev: force a seat-0 ghost-meddle wisp for a windowed shot
var _meddle_shot_done := false
var _names: Dictionary = {}
var _colors: Dictionary = {}

# ---- match state ----
var state := St.INTRO
var round_no := 0
var _round_time := 0.0
var _rec_count := 0
var _phase_timer := 0.0
var _shrink_at := 999.0
var _shrunk := false

var fighters: Array = []
var ghosts: Array = []
var _takes: Array = []            # every stored round-recording (all rounds)
var _samples: Array = []          # this round's in-progress recorders
var _respawns: Array = []
var _ring_warn: Dictionary = {}   # player_index -> seconds spent outside the ring
var _deaths_round: Dictionary = {}
var points: Dictionary = {}
var _currency: Array = []
var _ghost_kill_notes: Array = []
var _kill_events: Array = []      # optional contract: {killer,victim,cause} per KO
var _bounty_counts: Dictionary = {}
# IRONY PACK (doc 09 §2.1): times each player was killed by their OWN recorded
# echo. Surfaced to the estate's Will reading via highlights + kill_events cause.
var _self_haunts: Dictionary = {}

# ---- juice / perf ----
var _shake := 0.0
var _cam_base := Vector3.ZERO
var _last_hitpause := -1.0
# THE FINAL STRETCH kit (doc 09 §Q1): round 5 — the whole arena of echoes —
# is echo's stretch. Tense music for the final round, last-10s ticks + timer
# pulse every round (the anthology's silent-countdown gap A). Not attached
# under --ringtest / --aimprobe so the scripted evidence paths stay clean.
var _stretch: FinalStretch = null
var _perf_accum := 0.0
var _perf_frames := 0
var _perf_degraded := false

# ---- determinism accounting (ghosts report their endpoint drift) ----
var _det_max_err := 0.0
var _det_ghost_total := 0
var _logged_ghost_heavy := false   # log the first replayed heavy each round

# ---- ONLINE PHASE 2 (docs/design/10 §4.3): the render mirror ----
# House pattern (online-seance-VERIFY.md PATTERN NOTES): the host runs this
# ENTIRE sim exactly as couch; the estate pumps _net_state() (compact PUBLIC
# facts) to guests at 20 Hz. The client boots this same scene with
# config.net_mirror = true — no sim, no bots, no rng; fighters AND GHOSTS ride
# one body-indexed block of quantized ints (ghost transforms are STREAMED, not
# re-simulated: drift risk zero by construction). All juice fires from state
# deltas; _mirror_tick interpolates at the render rate. Arena has no hidden
# info, so nothing rides the private channel.
var _mirror := false
var _mir := {}                     # last applied snapshot (delta source)
var _ban_col := "ffd933"           # host: banner color as a wire fact
var _cb_col := "ffffff"            # host: credit-banner color as a wire fact
var _net_ghost_gid := 0            # host: next ghost wire id
var _net_parry_n := 0              # host: parry clash count (mirror juice)
var _net_parry_seat := 0           # host: last parrier (mirror fx anchor)
var _net_bounty_n := 0             # host: ghost-bounty hits (mirror sting)
var _net_haunt_n := 0              # host: KILLED BY THEIR OWN ECHO count
var _net_decide_n := 0             # host: deciding-moment beats (mirror punch)
var _net_champ := -1               # pre-announced one beat before finished()
var _net_snapped: Dictionary = {}  # host-side probe evidence latches
# client mirror scratch
var _mir_f: Array = []             # per-fighter interp targets [pos, yaw, st]
var _mir_ghosts: Dictionary = {}   # gid -> {"node", "pos", "yaw", "st", "col"}
var _mir_warn: Dictionary = {}     # fighter idx -> outside-ring (local blink)
var _mir_clock := 0.0              # local clock for the warn blink
var _mir_rem0 := 0.0               # rem at round entry (evidence-latch timing)
var _mir_snapped: Dictionary = {}  # mirror-side probe evidence latches

# ---- event-driven verify captures (heavy windup / parry / fragment) ----
var _ev_captured: Dictionary = {}

# ---- nodes ----
var arena_floor: StaticBody3D
var arena_shape: CollisionShape3D
var _outer_disc: MeshInstance3D
var _inner_ring: MeshInstance3D
var camera: Camera3D
var ui: CanvasLayer
var round_label: Label
var timer_label: Label
var ghost_label: Label
var controls_label: Label     # persistent real-keys hint bar (realkeys-VERIFY.md)
var _meddle: GhostMeddle       # GHOST MEDDLING (doc 24 §6 / B6): dead humans get one verb
var banner: Label
var credit_banner: Label
var score_rows: VBoxContainer
var _font_luckiest: FontFile
var _font_baloo: FontFile


# ===========================================================================
# Lifecycle
# ===========================================================================
func _ready() -> void:
	# Self-start standalone if the party shell doesn't call begin() promptly.
	get_tree().create_timer(0.5).timeout.connect(_maybe_selfstart)


func _maybe_selfstart() -> void:
	if _begun:
		return
	_selfstarted = true
	begin(_default_config())


func _default_config() -> Dictionary:
	var n := 4
	var seed := 1
	var probe := false
	var probe_deg := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			n = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--aimprobe="):
			probe = true
			probe_deg = float(arg.trim_prefix("--aimprobe="))
	if probe:
		n = 2   # p0 = KBM human under the cursor, p1 = a bot parked off to the side
	PlayerInput.auto_assign(n)
	if probe:
		PlayerInput.assign(0, -4)
		var av := deg_to_rad(probe_deg)
		PlayerInput.set_debug_aim(0, Vector3(sin(av), 0.0, cos(av)))
	var r: Array = []
	for i in n:
		r.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": DEFAULT_CHARS[i],
			"device": PlayerInput.device_of(i),
			"bot": false if (probe and i == 0) else PlayerInput.standalone_bot_default(i),
		})
	return {"roster": r, "rounds": ROUNDS, "rng_seed": seed, "practice": false}


func begin(config: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	_mirror = bool(config.get("net_mirror", false))
	roster = config.get("roster", [])
	if roster.is_empty():
		roster = _default_config()["roster"]
	_seed = int(config.get("rng_seed", 1))
	rng.seed = _seed
	# Honor the shell's requested match length (contract: config.rounds). The
	# standalone default stays ROUNDS (5) via _default_config(); clamp to [1,ROUNDS].
	_rounds = clampi(int(config.get("rounds", ROUNDS)), 1, ROUNDS)
	_parse_args()

	for pl in roster:
		var idx: int = pl["index"]
		_names[idx] = pl["name"]
		_colors[idx] = pl["color"]
		points[idx] = 0
		_bounty_counts[idx] = 0

	_build_world()
	_build_ui()
	_spawn_fighters()
	if _mirror:
		# RENDER MIRROR: world, UI and fighters exist; no rng draws beyond the
		# harmless seed above, no bots, no recorders, no intro kick — the first
		# _net_apply drives every fact. Park fighters on their start rings so
		# the opening interpolation has an honest origin.
		state = St.INTRO
		for i in fighters.size():
			fighters[i].global_position = _start_pos(i)
			_mir_f.append([_start_pos(i), 0.0, 0])
		_stretch = FinalStretch.attach(self, timer_label)
		if controls_label != null:
			controls_label.text = _controls_bar()
			get_tree().create_timer(8.5, true, false, true).timeout.connect(func() -> void:
				if is_instance_valid(controls_label):
					controls_label.visible = false)
		print("ECHO_MIRROR boot players=%d my_seat=%d" % [roster.size(), NetSession.my_seat()])
		return
	# Personalize the persistent hint bar with each human seat's REAL keys, once
	# per match now that the roster/bot map is known (docs/verify/realkeys-VERIFY.md).
	if controls_label != null:
		controls_label.text = _controls_bar()
		# show it for the opening seconds, then declutter (real-time timer so the
		# hit-pause slow-mos never stretch the reveal)
		get_tree().create_timer(8.5, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(controls_label):
				controls_label.visible = false)
	print("ECHO_BEGIN players=%d seed=%d bots=%s round_len=%.1f" % [roster.size(), _seed, str(_bots), round_len])
	if not _ring_test and not _aim_probe_on:
		_stretch = FinalStretch.attach(self, timer_label)
	_enter_intro(1)
	if _aim_probe_on:
		_run_aim_probe()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--echobots":
			_bots = true
		elif arg.begins_with("--echofast="):
			round_len = maxf(2.0, float(arg.trim_prefix("--echofast=")))
		elif arg.begins_with("--echorounds="):
			# standalone override of the match length (mirrors the shell's
			# config.rounds contract, honored via _rounds); clamp to [1, ROUNDS].
			_rounds = clampi(int(arg.trim_prefix("--echorounds=")), 1, ROUNDS)
		elif arg == "--echocap":
			_cap_on = true
		elif arg == "--ringtest":
			_ring_test = true
		elif arg == "--echomeddleshot":
			_meddle_shot = true    # dev-only: photograph a live ghost-meddle wisp (windowed)
		elif arg.begins_with("--aimprobe="):
			_aim_probe_on = true
			_aim_probe_deg = float(arg.trim_prefix("--aimprobe="))
		elif arg.begins_with("--outdir="):
			_cap_dir = arg.trim_prefix("--outdir=")
	if _cap_on or _aim_probe_on or _ring_test or _meddle_shot:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _cap_dir))


# ===========================================================================
# World / UI construction
# ===========================================================================
func _build_world() -> void:
	# THE HOUSE LOOK — STAGELIT (core/env_kit.gd). Echo Chamber is an arena where
	# the ghosts of past rounds perform for the couch: a hard overhead key spot
	# pools light on the shrinking ring, a cool rim peels the four fighters off a
	# near-black surround, and the high-threshold glow makes the neon ghost trails,
	# gold boundary ring and parry flashes bloom hardest. The black beyond the pool
	# also sells the round-5 ring-out — light is safe, the void is death.
	# Hard directional key over a near-black surround (readability first: all four
	# KayKit bodies must always read on the couch, so ambient never bottoms out).
	EnvKit.apply(self, EnvKit.STAGELIT, {
		"key_energy": 1.7,
		"key_angle": Vector3(-64.0, 22.0, 0.0),
		"ambient_energy": 0.5,
		"fill_energy": 0.24,
		"rim_energy": 1.0,
	})

	_build_surround()

	# arena floor collision (radius shrinks at round 5)
	arena_floor = StaticBody3D.new()
	arena_floor.collision_layer = 1
	arena_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ARENA_R
	cyl.height = 1.0
	arena_shape.shape = cyl
	arena_shape.position.y = -0.5
	arena_floor.add_child(arena_shape)
	add_child(arena_floor)

	# outer disc (the ring that falls away in round 5)
	_outer_disc = MeshInstance3D.new()
	var omesh := CylinderMesh.new()
	omesh.top_radius = ARENA_R
	omesh.bottom_radius = ARENA_R - 0.3
	omesh.height = 0.5
	_outer_disc.mesh = omesh
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.30, 0.21, 0.14)   # warm brown table apron
	omat.roughness = 0.85
	_outer_disc.material_override = omat
	_outer_disc.position.y = -0.25
	add_child(_outer_disc)

	# inner disc + bright ring marks the safe zone
	var inner := MeshInstance3D.new()
	var imesh := CylinderMesh.new()
	imesh.top_radius = ARENA_R * SHRINK
	imesh.bottom_radius = ARENA_R * SHRINK
	imesh.height = 0.52
	inner.mesh = imesh
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color(0.44, 0.33, 0.22)   # warm tabletop the fight sits on
	imat.roughness = 0.8
	inner.material_override = imat
	inner.position.y = -0.24
	add_child(inner)

	_inner_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = ARENA_R * SHRINK - 0.12
	ring.outer_radius = ARENA_R * SHRINK + 0.05
	_inner_ring.mesh = ring
	var ringmat := StandardMaterial3D.new()
	ringmat.albedo_color = Color(1.0, 0.80, 0.24)
	ringmat.emission_enabled = true
	# THE RING DEMANDS. The ring-out boundary must be the HOTTEST thing on screen.
	# AGX crushes saturated yellows toward pale cream, so we compensate two ways:
	# an orange-shifted gold emission (survives AGX far better than pure yellow) and
	# an energy well ABOVE the STAGELIT glow HDR threshold (1.0) so the whole ring
	# crosses into bloom and out-glows the ghost trails / parry flashes. (Pre-lookdev
	# this sat at 0.6 — under the threshold — which is why it read as cold cream.)
	ringmat.emission = Color(1.0, 0.56, 0.10)
	ringmat.emission_energy_multiplier = 4.5
	_inner_ring.material_override = ringmat
	_inner_ring.position.y = 0.02
	add_child(_inner_ring)

	_spawn_pillars()

	camera = Camera3D.new()
	camera.fov = 52.0
	_cam_base = Vector3(0.0, 16.5, 12.5)
	camera.position = _cam_base
	camera.look_at_from_position(_cam_base, Vector3(0, 0.5, 0), Vector3.UP)
	add_child(camera)

	# GHOST MEDDLING (doc 24 §6 / B6): a dead HUMAN seat rises as a wisp for its
	# respawn window and may STIR A COLD DRAFT (a brief stagger of the nearby
	# living). SIM meddle — the stagger rides the fighter snapshot to mirrors, so
	# presentation_only stays false. Bots never raise a wisp (receipt-safe).
	_meddle = GhostMeddle.new()
	add_child(_meddle)
	_meddle.setup(self, camera, GhostMeddle.DEFAULT_CD, false)
	_meddle.set_bounds(Vector2.ZERO, Vector2(RING_R, RING_R))
	_meddle.meddled.connect(_on_ghost_meddle)


func _spawn_pillars() -> void:
	var spots := [Vector3(3.2, 0, 0.6), Vector3(-2.6, 0, 2.9), Vector3(-0.4, 0, -3.4)]
	for sp in spots:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.position = sp
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.45
		shape.height = 3.0
		cs.shape = shape
		cs.position.y = 1.5
		body.add_child(cs)
		# Visual: Meshy broken column (base at y=0, same footprint the 0.45
		# cylinder collider implies), varied fixed yaws. Primitive fallback.
		var column_glb := "res://assets/models/meshy/broken_column.glb"
		if ResourceLoader.exists(column_glb):
			var yaws := [0.0, 140.0, 260.0]
			var vis := MeshyProp.instance(column_glb, 3.0, yaws[spots.find(sp)])
			# the stub model is wide; squeeze x/z so the visual matches the
			# 0.45-radius collider instead of swallowing players
			var model: Node3D = vis.get_node("Model")
			var caabb := MeshyProp.merged_aabb_of_scaled(model)
			var w := maxf(caabb.size.x, caabb.size.z)
			if w > 1.05:
				vis.scale = Vector3(1.0 / w, 1.0, 1.0 / w)
			body.add_child(vis)
		else:
			var mi := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.42
			mesh.bottom_radius = 0.5
			mesh.height = 3.0
			mi.mesh = mesh
			mi.position.y = 1.5
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.52, 0.42, 0.30)   # warm carved-wood pillars
			mat.roughness = 0.9
			mi.material_override = mat
			body.add_child(mi)
		add_child(body)


## Warm surround so the arena reads as a lit diorama on a table (greed/mower
## family) instead of a cold disc in a void. PURELY DECORATIVE — no collision,
## and the tabletop sits below the round-5 death line (fighters die at y<-3,
## the floor fades out as it drops to y=-9), so gameplay/physics are untouched.
func _build_surround() -> void:
	# the warm room floor / tabletop the whole diorama rests above
	var table := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 30.0
	tm.bottom_radius = 30.0
	tm.height = 1.0
	table.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.26, 0.17, 0.11)
	tmat.roughness = 0.95
	table.material_override = tmat
	table.position.y = -9.8
	add_child(table)
	# a warm brown well-wall ringing the arena edge (like greed's vault walls),
	# hung a touch outside the play radius so nothing ever collides with it.
	var wall := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = ARENA_R + 1.3
	wm.bottom_radius = ARENA_R + 1.3
	wm.height = 8.6
	wm.rings = 1
	wall.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.23, 0.16, 0.11)
	wmat.roughness = 0.95
	wmat.cull_mode = BaseMaterial3D.CULL_FRONT   # see the inner face of the well
	wall.material_override = wmat
	wall.position.y = -5.0
	add_child(wall)
	_build_pit_bottom()


## W3 — THE WELL GETS A BOTTOM. The round-5 ring-out drops losers into flat black;
## this heaps reused grave GLBs on the pit floor (the table top, ~y=-9.3), tilted
## and jumbled like a bone pile, and washes them in ONE faint sickly-green glow so
## the elimination REVEALS where the losers go instead of swallowing them. It all
## sits far below the play surface and inside the well wall (r<=9.3) — no collision,
## no per-frame cost, one shadowless omni whose spill stays under the discs.
func _build_pit_bottom() -> void:
	var floor_y := -9.25
	# Director note: the warm tabletop material under the well read as a SHALLOW
	# brown floor — the pit needs its own darkness before anything can read as
	# depth. A near-black disc caps the table inside the well wall; everything
	# below the rim now falls toward black, and only the green pool interrupts it.
	var dark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 9.25
	disc.bottom_radius = 9.25
	disc.height = 0.05
	dark.mesh = disc
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.015, 0.02, 0.02)
	dmat.roughness = 1.0
	dark.material_override = dmat
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dark.position = Vector3(0, floor_y - 0.04, 0)
	add_child(dark)
	# id, x, z, height, tilt_deg, tilt_axis_deg, yaw — a tighter, SMALLER heap
	# (scaled ~0.6, pulled inward) so from 12+ units above it reads as a distant
	# pile at the bottom of a shaft, not furniture on a floor.
	var bones := [
		["grave_mausoleum_front",   0.4,  4.6, 1.3, 58.0,  20.0, 190.0],
		["grave_tilted_slab",      -2.4,  3.7, 1.1, 72.0, -30.0, 200.0],
		["grave_headstone_cracked", 2.5,  3.3, 0.9, 80.0,  60.0, 150.0],
		["grave_tilted_slab",      -4.3,  1.6, 1.1, 64.0,  10.0, 240.0],
		["grave_small_obelisk",     4.2,  1.0, 1.0, 84.0, 110.0, 300.0],
		["grave_tilted_slab",       0.1,  0.0, 1.1, 40.0, -50.0, 175.0],
		["grave_headstone_cracked",-1.8, -2.7, 0.9, 78.0, 130.0,  90.0],
		["grave_tilted_slab",       3.1, -2.1, 1.1, 66.0,  40.0, 120.0],
		["grave_headstone_cracked", 5.5,  4.2, 0.8, 82.0, -20.0, 210.0],
		["grave_tilted_slab",      -5.4,  3.4, 1.1, 70.0,  70.0, 260.0],
	]
	for b in bones:
		var glb := "res://assets/models/meshy/generated/%s.glb" % str(b[0])
		if not ResourceLoader.exists(glb):
			continue
		var w := MeshyProp.instance(glb, float(b[3]), float(b[6]))
		w.position = Vector3(float(b[1]), floor_y, float(b[2]))
		var ax := deg_to_rad(float(b[5]))
		w.rotate(Vector3(cos(ax), 0.0, sin(ax)), deg_to_rad(float(b[4])))
		add_child(w)
	# the sickly glow that makes the heap read from far above (shadowless, cheap):
	# tighter and hotter than v1 — over the black floor it pools as a green well-
	# bottom light instead of vanishing into the warm table material.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.34, 0.95, 0.42)
	glow.light_energy = 3.6
	glow.omni_range = 11.0
	glow.shadow_enabled = false
	glow.position = Vector3(0.3, -8.1, 1.8)
	add_child(glow)


func _build_ui() -> void:
	_font_luckiest = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	_font_baloo = load("res://assets/fonts/Baloo2.ttf")
	ui = CanvasLayer.new()
	add_child(ui)

	round_label = _mk_label(_font_baloo, 26, HORIZONTAL_ALIGNMENT_LEFT)
	round_label.offset_left = 22
	round_label.offset_top = 14
	round_label.offset_right = 360
	round_label.offset_bottom = 52
	ui.add_child(round_label)

	timer_label = _mk_label(_font_luckiest, 34, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.anchor_right = 1.0
	timer_label.offset_top = 12
	timer_label.offset_bottom = 58
	ui.add_child(timer_label)

	ghost_label = _mk_label(_font_baloo, 20, HORIZONTAL_ALIGNMENT_LEFT)
	ghost_label.anchor_top = 1.0
	ghost_label.anchor_bottom = 1.0
	ghost_label.offset_left = 22
	ghost_label.offset_top = -44
	ghost_label.offset_bottom = -14
	ghost_label.offset_right = 400
	ui.add_child(ghost_label)

	# Persistent real-keys hint bar, bottom-center (clear of the bottom-left
	# GHOSTS count). Text is filled once at match start from _controls_bar().
	controls_label = _mk_label(_font_baloo, 19, HORIZONTAL_ALIGNMENT_CENTER)
	controls_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	controls_label.offset_bottom = -10
	controls_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	ui.add_child(controls_label)

	credit_banner = _mk_label(_font_luckiest, 40, HORIZONTAL_ALIGNMENT_CENTER)
	credit_banner.anchor_right = 1.0
	credit_banner.anchor_top = 0.14
	credit_banner.anchor_bottom = 0.14
	credit_banner.offset_bottom = 70
	credit_banner.visible = false
	ui.add_child(credit_banner)

	banner = _mk_label(_font_luckiest, 66, HORIZONTAL_ALIGNMENT_CENTER)
	banner.anchor_right = 1.0
	banner.anchor_top = 0.34
	banner.anchor_bottom = 0.5
	banner.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	banner.visible = false
	ui.add_child(banner)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -250
	panel.offset_top = 12
	panel.offset_right = -14
	ui.add_child(panel)
	score_rows = VBoxContainer.new()
	panel.add_child(score_rows)


func _mk_label(font: FontFile, size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = align
	return l


## ---- live-binding hint bar (real keys, not "A"/"B"; docs/verify/realkeys-VERIFY.md) ----
## Self-contained per the template; presentation only. Bindings are fixed per
## match, so the bar is built once at match start (from begin()).

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). A seat
## is bot-driven under the same rule _spawn_fighters uses (--echobots OR the
## roster marks it a bot). The bar personalizes only human seats.
func _human_seats() -> Array:
	var out := []
	for i in roster.size():
		var seat_bot: bool = _bots or bool(roster[i].get("bot", false))
		if not seat_bot and PlayerInput.device_of(i) != -99:
			out.append(i)
	return out

## Seats whose bindings the hint bar prints: the live humans, or seat 0 as a
## representative when a bot-only demo has no humans — so the bar always shows
## a REAL key, never an abstract "A =" verb (doc 14 nit 3, notation consistency).
func _hint_seats() -> Array:
	var seats := _human_seats()
	return seats if not seats.is_empty() else [0]

## One button's live legend: "KEY = LABEL" when every hint seat shares the key
## (all pads -> "(A) = STRIKE"), else the per-seat "LABEL: KEY/NAME · KEY/NAME"
## form (mixed keyboard + pad).
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

## The main hint bar, always real keys via describe_binding (matches the card).
func _controls_bar() -> String:
	return "MOVE   ·   %s   ·   %s   ·   %s   |   DUEL YOUR OWN ECHO" % [
		_btn_hint("a", "STRIKE"), _btn_hint("b", "DASH / hold PARRY"), _btn_hint("jump", "HOP")]


## GHOST MEDDLING: while any wisp exists, append each locally-controlled dead
## seat's meddle legend (the _hint_seats pattern, real keys via describe_binding)
## under the live-controls bar and re-reveal it; restore the plain bar when the
## last wisp respawns. Only _human_seats() are listed (a mirror shows just its own).
func _refresh_meddle_hints() -> void:
	if controls_label == null:
		return
	if _meddle == null or _meddle.ghost_count() == 0:
		controls_label.text = _controls_bar()
		return
	var lines := [_controls_bar()]
	for i in _human_seats():
		if _meddle.has_ghost(int(i)):
			lines.append(_meddle.hint_line(int(i), "GUST"))
	controls_label.text = "\n".join(lines)
	controls_label.visible = true


## GHOST MEDDLING (doc 24 §6): a dead human's ONE verb. A cold spectral draft
## STAGGERS the LIVING within reach — a stumble, never a shove: it adds no
## velocity, so it can neither ring anyone out nor decide the round, and it skips
## a fighter already over the ring (a death in progress is never the draft's doing).
## Mischief, filed. SIM meddle: the stagger rides the fighter snapshot to mirrors.
func _on_ghost_meddle(index: int, origin: Vector3, _aim: Vector3) -> void:
	var touched := 0
	for f in fighters:
		if not f.alive or f.player_index == index:
			continue
		var d := Vector2(f.global_position.x - origin.x, f.global_position.z - origin.z).length()
		if d > MEDDLE_GUST_R:
			continue
		if Vector2(f.global_position.x, f.global_position.z).length() > RING_R:
			continue   # already over the edge — the draft does not decide that
		f.stagger(MEDDLE_GUST_STAGGER)
		touched += 1
	Sfx.play("gust", -8.0)
	_meddle.attribute(index, "STIRRED A COLD DRAFT")
	print("ECHO_MEDDLE seat=%d touched=%d (cold draft; stagger-only, no ring-out)" % [index, touched])


func _spawn_fighters() -> void:
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var f := EchoFighter.new()
		f.player_index = pl["index"]
		f.color = pl["color"]
		f.char_path = pl.get("char_scene", DEFAULT_CHARS[i % DEFAULT_CHARS.size()])
		# Per-player: bot-driven if the roster marks this seat a bot (shell sets
		# it from estate._is_bot; standalone from PlayerInput) OR the legacy
		# --echobots flag forces ALL bots. A human seat reads PlayerInput as
		# normal; the ghost-replay determinism assertion is unaffected.
		f.is_bot = _bots or bool(pl.get("bot", false))
		f.main = self
		add_child(f)
		f.setup(_seed)
		fighters.append(f)


# ===========================================================================
# Round flow
# ===========================================================================
func _enter_intro(n: int) -> void:
	round_no = n
	state = St.INTRO
	_phase_timer = INTRO_TIME
	round_label.text = "ROUND %d / %d" % [n, _rounds]
	round_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	_spawn_ghosts_for_round()
	_det_ghost_total = ghosts.size()
	_det_max_err = 0.0
	_logged_ghost_heavy = false
	_reset_arena(n == _rounds)
	_ring_warn.clear()
	for f in fighters:
		f.set_ring_warning(false)
	_deaths_round.clear()
	for pl in roster:
		_deaths_round[int(pl["index"])] = 0
	_respawns.clear()
	# GHOST MEDDLING: a new round reseats everyone alive — clear any lingering wisps.
	if _meddle != null:
		_meddle.clear()
		_refresh_meddle_hints()
	# reset fighters to their start rings, full HP
	for i in fighters.size():
		fighters[i].respawn(_start_pos(i), HP_MAX)
	# fresh recorders for this round
	_samples.clear()
	for i in fighters.size():
		_samples.append(_new_recorder(fighters[i]))
	_round_time = 0.0
	_rec_count = 0
	_shrunk = false
	_shrink_at = round_len * 0.45 if n == _rounds else 999.0
	var sub := "%d GHOSTS HAUNT THE ARENA" % ghosts.size() if ghosts.size() > 0 else "NO GHOSTS YET — MAKE SOME"
	_flash_banner("ROUND %d\n%s" % [n, sub], Color(1, 0.85, 0.2), 0.0)
	# THE FINAL STRETCH (doc 09 §Q1): the last round plays TENSE from its first
	# second — every recorded self is on the floor. Earlier rounds re-arm light.
	if _stretch != null:
		if n >= _rounds and _rounds > 1:
			_stretch.escalate()
			_flash_credit("THE ESTATE COLLECTS ITS ECHOES", Color(1.0, 0.8, 0.35))
		else:
			_stretch.round_reset()
	Sfx.play("round_over")
	print("ECHO_ROUND_START round=%d ghosts=%d frame=%d" % [n, ghosts.size(), Engine.get_process_frames()])
	_rebuild_scoreboard()


func _new_recorder(f: EchoFighter) -> Dictionary:
	return {
		"owner": f.player_index,
		"round": round_no,
		"color": f.color,
		"char": f.char_path,
		"pos": PackedVector3Array(),
		"yaw": PackedFloat32Array(),
		"state": PackedByteArray(),
		"fire": PackedByteArray(),
		"count": 0,
	}


func _spawn_ghosts_for_round() -> void:
	for g in ghosts:
		g.queue_free()
	ghosts.clear()
	if _takes.is_empty():
		return
	# newest rounds first; cap at MAX_GHOSTS by dropping OLDEST rounds
	var pool: Array = _takes.duplicate()
	pool.sort_custom(func(a, b):
		var ra: int = a["round"]
		var rb: int = b["round"]
		if ra != rb:
			return ra > rb
		return int(a["owner"]) < int(b["owner"]))
	var chosen: Array = pool.slice(0, MAX_GHOSTS)
	# find oldest kept round for readability thinning
	var oldest := 9999
	var distinct := {}
	for tk in chosen:
		var rr: int = tk["round"]
		oldest = mini(oldest, rr)
		distinct[rr] = true
	for tk in chosen:
		var g := EchoGhost.new()
		_net_ghost_gid += 1
		g.gid = _net_ghost_gid
		g.take = tk
		g.owner_index = tk["owner"]
		g.owner_color = tk["color"]
		g.round_no = tk["round"]
		g.main = self
		# thin oldest kept round for readability when the arena is crowded
		if int(tk["round"]) == oldest and distinct.size() > 1:
			g.opacity = 0.4
		add_child(g)
		g.setup()
		g.reset_replay()
		ghosts.append(g)


func _reset_arena(_is_round5: bool) -> void:
	# arena always starts full; shrink is triggered mid-round-5
	_outer_disc.visible = true
	_outer_disc.position.y = -0.25
	_outer_disc.transparency = 0.0
	(arena_shape.shape as CylinderShape3D).radius = ARENA_R


func _do_shrink() -> void:
	_shrunk = true
	(arena_shape.shape as CylinderShape3D).radius = ARENA_R * SHRINK
	_shrink_fx()
	_flash_banner("THE FLOOR FALLS AWAY!", Color(1.0, 0.4, 0.3), 2.0)
	print("ECHO_SHRINK round=%d t=%.2f" % [round_no, _round_time])
	_net_snap("net_shrink")


## The collapse's render half (tween + crush + shake), shared with the mirror
## (which fires it off the shrunk-flag edge; its banner rides the ban fact).
func _shrink_fx() -> void:
	var tw := create_tween()
	tw.tween_property(_outer_disc, "position:y", -9.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_outer_disc, "transparency", 1.0, 1.1)
	Sfx.play("crush")
	_shake = maxf(_shake, 0.9)


func _end_round() -> void:
	state = St.TRANSITION
	_phase_timer = TRANSITION_TIME
	# survival bonus + grudge bookkeeping
	for pl in roster:
		var idx: int = pl["index"]
		var d: int = _deaths_round.get(idx, 0)
		if d == 0:
			points[idx] += SURVIVE_BONUS
		if d >= 2:
			_currency.append({"type": "grudge", "player": idx, "amount": 1,
				"reason": "died %d times in round %d" % [d, round_no]})
	# store this round's recordings as ghost-takes for future rounds
	for i in fighters.size():
		_takes.append(_samples[i])
	_verify_determinism()
	_rebuild_scoreboard()
	print("ECHO_ROUND_END round=%d points=%s" % [round_no, str(points)])
	if round_no >= _rounds:
		_finish_match()
	else:
		Sfx.play("round_over")
		_flash_banner("ROUND %d OVER" % round_no, Color(1, 0.85, 0.2), TRANSITION_TIME - 0.4)


## Spec risk "Replay drift": each ghost, the instant it reaches its recorded
## endpoint (death or end), reports the drift between its transform and the
## recorded sample it snapped to. Ghosts are driven by DIRECT transform
## application, so this holds exactly (0.000000). assert() halts on drift.
## By round end every ghost this round has reported (recording length == round
## length), so the accumulated max is the round's verdict.
func _report_determinism(err: float, owner: int, rnd: int) -> void:
	_det_max_err = maxf(_det_max_err, err)
	assert(err < 0.01, "GHOST DRIFT owner=%d round=%d err=%f" % [owner, rnd, err])


func _verify_determinism() -> void:
	print("ECHO_DETERMINISM round=%d ghosts=%d max_err=%.6f OK" % [round_no, _det_ghost_total, _det_max_err])


func _finish_match() -> void:
	state = St.DONE
	_phase_timer = RESULT_HOLD
	if _stretch != null:
		_stretch.match_ended()
	var order := _placements()
	var champ: int = order[0]
	timer_label.text = ""
	round_label.text = "FINAL"
	_flash_banner("%s SILENCES THE CHAMBER" % _names[champ], _colors[champ], 0.0)
	Sfx.play("match_win")
	_spawn_confetti(Vector3(0, 2.5, 0), _colors[champ])
	_shake = maxf(_shake, 0.6)

	var monuments: Array = []
	var top_bounty := -1
	var top_bounty_n := 0
	for idx in _bounty_counts:
		if int(_bounty_counts[idx]) > top_bounty_n:
			top_bounty_n = int(_bounty_counts[idx])
			top_bounty = int(idx)
	if top_bounty >= 0 and top_bounty_n >= 3:
		monuments.append({"player": top_bounty, "kind": "revenant",
			"label": "%s, Haunted by Their Own Echo" % _names[top_bounty]})

	var results := {
		"placements": order,
		"points": points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": _best_highlights(),
		"monuments": monuments,
		"kill_events": _kill_events.duplicate(),
	}
	print("ECHO_MATCH_OVER champ=%s placements=%s" % [_names[champ], str(order)])
	print("KILL_EVENTS n=", _kill_events.size(), " ", _kill_events)
	# ONLINE (hard-won lesson, see masked_ball.gd): report_finished() stops the
	# estate's 20 Hz pump the same tick it runs, so any fact minted here would
	# never reach a mirror. Pre-announce the champ NOW (points are final) and
	# let the tableau breathe half a second before the report. Prints above stay
	# on this tick, so couch/bot receipts are byte-identical; the real-time
	# timer ignores the deciding-moment slow-mo.
	_net_champ = champ
	_net_snap("net_champ")
	get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
		report_finished(results))


func _placements() -> Array:
	var idx: Array = []
	for pl in roster:
		idx.append(int(pl["index"]))
	idx.sort_custom(func(a, b):
		if int(points[a]) != int(points[b]):
			return int(points[a]) > int(points[b])
		return a < b)
	return idx


func _best_highlights() -> Array:
	var out: Array = []
	# IRONY PACK (doc 09 §2.1): the self-echo deaths lead the recap. The estate
	# carves each highlight as graffiti and reads it at the will, so the "killed
	# by your own echo" moment surfaces in the Reading of the Will. Insertion
	# order of _self_haunts is deterministic (seed-driven death order).
	for v in _self_haunts:
		if out.size() >= 3:
			break
		var n: int = int(_self_haunts[v])
		if n > 0:
			out.append("%s WAS SLAIN BY THEIR OWN ECHO%s" % [_names[v], (" (x%d)" % n) if n > 1 else ""])
	var seen := {}
	for note in _ghost_kill_notes:
		if out.size() >= 3:
			break
		if not seen.has(note):
			seen[note] = true
			out.append(note)
	return out


# ===========================================================================
# Main loop
# ===========================================================================
func _physics_process(delta: float) -> void:
	if not _begun:
		return
	# THE HOUSE GUARD (spec §4.3): a mirror never simulates. Interp + juice only.
	if _mirror:
		_mirror_tick(delta)
		return
	match state:
		St.INTRO:
			_phase_timer -= delta
			for f in fighters:
				f.tick(delta)   # let them settle onto the floor
			if _phase_timer <= 0.0:
				state = St.PLAY
				banner.visible = false
		St.PLAY:
			_tick_play(delta)
		St.TRANSITION:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_enter_intro(round_no + 1)
		St.DONE:
			_phase_timer -= delta


func _tick_play(delta: float) -> void:
	_round_time += delta

	# final-round collapse telegraph
	if not _shrunk and round_no == _rounds and _round_time >= _shrink_at:
		_do_shrink()

	# 1. tick live fighters in index order
	for f in fighters:
		f.tick(delta)

	# dev: hold fighter 0 outside the ring (after its own tick, before enforcement)
	if _ring_test and fighters[0].alive and _ringtest_state < 2:
		fighters[0].global_position = Vector3(7.0, 0.1, 0.0)
		fighters[0].velocity = Vector3.ZERO

	# 1b. enforce the ring boundary on LIVE fighters only (ghosts never checked)
	_enforce_ring(delta)

	if _ring_test:
		_ringtest_capture()

	# 2. sample the recorder from post-move state, keyed to the round clock
	var target := int(_round_time * REC_HZ)
	while _rec_count <= target and _rec_count < MAX_FRAMES:
		for i in fighters.size():
			var f: EchoFighter = fighters[i]
			var rec: Dictionary = _samples[i]
			rec["pos"].append(f.global_position)
			rec["yaw"].append(f.yaw)
			rec["state"].append(f.state)
			rec["fire"].append(f.consume_fire())   # 0 none / 1 light / 2 heavy
			rec["count"] = int(rec["count"]) + 1
		_rec_count += 1

	# 3. replay ghosts by direct transform application (may strike live players).
	#    A ghost that reaches its recorded death/end fragments and marks itself
	#    done; sweep those out so we stop touching freed instances.
	var any_done := false
	for g in ghosts:
		g.replay(_round_time)
		if g.done:
			any_done = true
	if any_done:
		var live: Array = []
		for g in ghosts:
			if not g.done:
				live.append(g)
		ghosts = live

	# 4. respawns + round end
	_process_respawns(delta)

	# 4b. GHOST MEDDLING: drive dead-human wisps off the AUTHORITATIVE tick (reads
	# each dead seat's drift + A; fires _on_ghost_meddle when the verb is ready).
	_meddle.tick(delta)
	if _meddle_shot:
		_meddle_shot_tick()

	# HUD
	var remain := maxf(0.0, round_len - _round_time)
	timer_label.text = "%0.1f" % remain
	timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if remain < 6.0 else Color(1, 1, 1))
	if _stretch != null:
		_stretch.tick(remain)   # FINAL STRETCH last-10s ladder + timer pulse
	ghost_label.text = "GHOSTS: %d" % ghosts.size()
	_rebuild_scoreboard()

	# host-side probe evidence (latched; inert offline/headless)
	if _round_time >= 5.0 and round_no >= 2:
		_net_snap("net_ghosts")
		if round_no >= _rounds and _rounds > 1:
			_net_snap("net_r5")

	if _cap_on:
		_try_capture()

	if _round_time >= round_len:
		_end_round()


## State-based screenshot beats (reliable regardless of framerate). Fires the
## make-or-break round-5 density shots that frame-indexed --shots can't target.
func _try_capture() -> void:
	var beats := [
		[1, 2.5, "r1_play"],
		[2, 2.5, "r2_ghosts"],
		[3, 2.5, "r3"],
		[4, 2.5, "r4_full12"],
		[5, _shrink_at - 0.25, "r5_dense_preshrink"],
		[5, minf(_shrink_at + 1.9, round_len - 0.2), "r5_postshrink"],
	]
	for b in beats:
		var rn: int = b[0]
		var tt: float = b[1]
		var tag: String = b[2]
		if round_no == rn and _round_time >= tt and not _cap_done.has(tag):
			_cap_done[tag] = true
			_grab(tag, tag == "r5_postshrink")


func _grab(tag: String, quit_after: bool) -> void:
	# frame_post_draw never fires under --headless (no drawing), so only wait
	# for it when there's a real display; otherwise capture would hang.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/echo_%s.png" % [_cap_dir, tag]
		img.save_png(path)
		print("ECHO_CAP ", path)
	else:
		print("ECHO_CAP_SKIP_HEADLESS ", tag)
	if quit_after:
		await get_tree().create_timer(0.3).timeout
		print("ECHO_CAP_DONE")
		get_tree().quit()


## DEV/VERIFY ONLY (--echomeddleshot, windowed): once the arena has settled, kill
## seat 0's body and force-raise its ghost-meddle wisp so the actor (orb, name,
## cooldown ring, MEDDLE READY tag) can be photographed. This BYPASSES the human
## gate on purpose — it is never enabled in a receipt run, so all-bot receipts are
## untouched. Mirrors the game's own _ring_test / --echocap capture precedent.
func _meddle_shot_tick() -> void:
	if _meddle_shot_done or round_no != 1 or _round_time < 1.6:
		return
	_meddle_shot_done = true
	var f0: EchoFighter = fighters[0]
	if f0.alive:
		f0.kill()
	# spawn the wisp at a deliberately CLEAR spot (front-left of the ring) so the
	# actor photographs unobstructed by the center fighter cluster
	_meddle.add_ghost(0, str(_names[0]), _colors[0], Vector3(-3.0, 0.05, 2.8))
	_refresh_meddle_hints()
	print("ECHO_MEDDLE_SHOT wisp raised for seat 0 (dev capture; not a receipt path)")
	_grab_meddle()


func _grab_meddle() -> void:
	await get_tree().create_timer(0.8).timeout   # let the wisp fade in + ring draw
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/echo_meddle_wisp.png" % _cap_dir
		img.save_png(path)
		print("ECHO_CAP ", path)
	else:
		print("ECHO_CAP_SKIP_HEADLESS meddle_wisp")
	await get_tree().create_timer(0.3).timeout
	print("ECHO_MEDDLE_SHOT_DONE")
	get_tree().quit()


func _process_respawns(delta: float) -> void:
	var still: Array = []
	for r in _respawns:
		var rr: Dictionary = r
		rr["t"] = float(rr["t"]) - delta
		if float(rr["t"]) <= 0.0:
			var f: EchoFighter = rr["f"]
			var pos: Vector3 = _center_spawn() if rr["mode"] == "center" else _edge_spawn()
			f.respawn(pos, int(rr["hp"]))
			# GHOST MEDDLING: the seat lives again — retire its wisp.
			_meddle.remove_ghost(int(f.player_index))
			_refresh_meddle_hints()
			Sfx.play("confirm", -4.0)
		else:
			still.append(rr)
	_respawns = still


func _process(delta: float) -> void:
	# camera shake (static rig + additive offset)
	if camera:
		if _shake > 0.002:
			var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.35
			camera.position = _cam_base + off
			_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
		else:
			camera.position = _cam_base
	# perf watchdog (spec: >8ms -> thin oldest ghosts / drop shadows)
	_perf_accum += Performance.get_monitor(Performance.TIME_PROCESS)
	_perf_frames += 1
	if _perf_frames >= 45:
		var avg_ms := (_perf_accum / _perf_frames) * 1000.0
		_perf_accum = 0.0
		_perf_frames = 0
		if avg_ms > 8.0 and not _perf_degraded:
			_perf_degraded = true
			_apply_perf_degrade(avg_ms)


func _apply_perf_degrade(ms: float) -> void:
	for g in ghosts:
		g.set_shadows(false)
		g.set_opacity(minf(g.opacity, 0.4))
	print("ECHO_PERF degraded=true avg_ms=%.2f ghosts thinned" % ms)


# ===========================================================================
# Combat resolution (called by both live swings and ghost replays)
# ===========================================================================
func resolve_swing(origin: Vector3, yaw_a: float, owner: int, is_ghost: bool, exclude, src_round: int, is_heavy := false, is_riposte := false) -> void:
	if is_ghost and is_heavy and not _logged_ghost_heavy:
		_logged_ghost_heavy = true
		print("ECHO_GHOST_HEAVY owner=%s src_round=%d (past heavy replays with 2H arc)" % [_names[owner], src_round])
	var fwd := Vector3(sin(yaw_a), 0.0, cos(yaw_a))
	var reach := HEAVY_RANGE if is_heavy else SWING_RANGE
	var arc := HEAVY_HALF_ARC if is_heavy else SWING_HALF_ARC
	var dmg := HEAVY_HIT_PTS if is_heavy else 1
	if is_riposte:
		dmg += 1     # riposte light: +1 bonus damage
	for f in fighters:
		if f == exclude or not f.alive:
			continue
		var fpos: Vector3 = f.global_position
		var to: Vector3 = fpos - origin
		to.y = 0.0
		var d: float = to.length()
		if d > reach or d < 0.001:
			continue
		if fwd.angle_to(to) > arc:
			continue
		var res: String = f.take_hit(dmg, origin, owner, is_heavy)
		if res == "":
			continue
		if res == "parry":
			_on_parry(f, owner, is_ghost, exclude, src_round)
			continue
		if is_ghost:
			_award_ghost_hit(owner, f.player_index, res, src_round)
		else:
			if owner != f.player_index:
				points[owner] += HEAVY_HIT_PTS if is_heavy else LIVE_HIT_PTS
				if is_riposte:
					points[owner] += RIPOSTE_BONUS_PTS
					print("ECHO_RIPOSTE by=%s victim=%s +%d (parry payoff)" % [_names[owner], _names[f.player_index], RIPOSTE_BONUS_PTS])
		_hit_feedback(f.global_position, f.color, is_heavy)
		if res == "kill":
			# killer = attacking OWNER (a player index for BOTH live and ghost
			# swings — ghosts credit their owner, matching the royalty above).
			# IRONY PACK (doc 09 §2.1): a ghost that kills its OWN owner is the
			# "killed by your own echo" moment. Tag the cause slug so _on_death
			# fires the distinct celebration and carries it to the Will reading.
			var self_echo: bool = is_ghost and owner == int(f.player_index)
			var kcause: String = "self_echo" if self_echo else ("crush" if is_heavy else "shatter")
			_on_death(f.player_index, false, owner, kcause)


## A parry landed: the incoming hit is negated. A LIVE attacker staggers
## (0.6s, opening the riposte); ghosts never stagger (they already happened),
## but their swing is still parried and the parrier still gets the riposte.
func _on_parry(parrier, attacker_owner: int, is_ghost: bool, attacker_fighter, src_round: int) -> void:
	Sfx.play("confirm", 0.5)
	_spawn_death_fx(parrier.global_position + Vector3(0, 1.1, 0), Color(1, 1, 0.75), 14, 0.4)
	_shake = maxf(_shake, 0.22)
	if not is_ghost and attacker_fighter != null:
		attacker_fighter.stagger(PARRY_STAGGER_T)
	_flash_credit("%s PARRIES!" % _names[parrier.player_index], _colors[parrier.player_index])
	_net_parry_n += 1
	_net_parry_seat = parrier.player_index
	_net_snap("net_parry")
	print("ECHO_PARRY parrier=%s attacker=%s ghost=%s round=%d t=%.2f" % [_names[parrier.player_index], _names[attacker_owner], str(is_ghost), src_round, _round_time])
	_event_capture("parry_moment")


## One-shot shard burst in a ghost's tint (declutter: the ghost is despawning).
func _spawn_fragments(pos: Vector3, color: Color) -> void:
	_spawn_death_fx(pos, color, 20, 0.5)
	_event_capture("ghost_fragment")


func _award_ghost_hit(owner: int, victim: int, res: String, src_round: int) -> void:
	points[owner] += GHOST_HIT_PTS
	_bounty_counts[owner] = int(_bounty_counts[owner]) + 1
	_currency.append({"type": "royalty", "player": owner, "amount": 1,
		"reason": "past self struck %s" % _names[victim]})
	Sfx.play("grudge", -2.0)
	_net_bounty_n += 1
	_flash_credit("PAST %s STRIKES AGAIN" % _names[owner], _colors[owner])
	if res == "kill":
		var note := "ROUND-%d %s KILLED PRESENT %s" % [src_round, _names[owner], _names[victim]]
		_ghost_kill_notes.append(note)
		print("ECHO_BOUNTY_KILL ", note)


func on_fall_death(idx: int) -> void:
	var f: EchoFighter = fighters[idx]
	if not f.alive:
		return
	f.kill()
	# fell off the platform — no attacker is credited, so killer = -1.
	_on_death(idx, true, -1, "ring_out")


## Dev harness (--ringtest): film the two required beats — the flashing warning
## while fighter 0 is held outside the ring, then the ring-out KO ~1.5s later.
func _ringtest_capture() -> void:
	var f: EchoFighter = fighters[0]
	if _ringtest_state == 0 and float(_ring_warn.get(0, 0.0)) >= 0.7:
		_ringtest_state = 1
		f.set_ring_warning(true, true)   # force the flash ON for the frame we grab
		_grab("ringwarn", false)
	elif _ringtest_state == 1 and not f.alive:
		_ringtest_state = 2
		print("ECHO_RINGTEST ko fighter=0 at r=%.1f" % Vector2(f.global_position.x, f.global_position.z).length())
		_grab("ringko", true)


## THE RING DEMANDS. A LIVE fighter standing beyond the yellow boundary ring
## (RING_R) gets a flashing 1.5s warning, then a ring-out KO down the existing
## fall-death path (killer -1). Called every PLAY tick with live fighters only —
## ghosts are separate nodes and are NEVER checked, so replayed past selves that
## wandered outside the ring trigger nothing.
func _enforce_ring(delta: float) -> void:
	for f in fighters:
		var idx: int = f.player_index
		if not f.alive:
			if _ring_warn.has(idx):
				_ring_warn.erase(idx)
				f.set_ring_warning(false)
			continue
		var r := Vector2(f.global_position.x, f.global_position.z).length()
		if r > RING_R:
			var t: float = float(_ring_warn.get(idx, 0.0)) + delta
			_ring_warn[idx] = t
			# flash the warning ~4Hz so it reads as an alarm, not a static label
			f.set_ring_warning(true, fmod(t, 0.26) < 0.13)
			if t >= RING_WARN_T:
				_ring_warn.erase(idx)
				f.set_ring_warning(false)
				_flash_credit("%s — THE RING DEMANDS" % _names[idx], _colors[idx])
				on_fall_death(idx)
		elif _ring_warn.has(idx):
			_ring_warn.erase(idx)
			f.set_ring_warning(false)


func _on_death(victim: int, is_fall: bool, killer: int = -1, cause: String = "shatter") -> void:
	# Optional contract reporting: one kill_event per KO. Every death funnels
	# through here (swing kills + fall deaths), so this is the single sink.
	# Pure bookkeeping — nothing below the sim depends on it.
	_kill_events.append({"killer": killer, "victim": victim, "cause": cause})
	_deaths_round[victim] = int(_deaths_round.get(victim, 0)) + 1
	Sfx.play("death")
	# IRONY PACK (doc 09 §2.1): killed by your OWN recorded echo — the funniest
	# outcome the ghost engine can produce. Distinct celebration vs a normal kill:
	# the big center banner (normal kills use the small credit banner), a grudge
	# sting at 0dB, deeper slow-mo, and a tracked self_haunt stat for the estate's
	# Will reading (surfaced through highlights + the kill_events cause slug).
	var self_echo := cause == "self_echo"
	if self_echo:
		_self_haunts[victim] = int(_self_haunts.get(victim, 0)) + 1
		_net_haunt_n += 1
		_flash_banner("KILLED BY THEIR OWN ECHO", _colors[victim], 2.2)
		Sfx.play("grudge", 0.0)
		_net_snap("net_irony")
		print("ECHO_SELF_HAUNT victim=%s round=%d (slain by their own recorded ghost)" % [_names[victim], round_no])
	var mode := "edge"
	var hp_amt := HP_MAX
	if round_no == _rounds and is_fall:
		mode = "center"
		hp_amt = 2   # respawn center at half HP
	_respawns.append({"f": fighters[victim], "t": RESPAWN_TIME, "hp": hp_amt, "mode": mode})
	# GHOST MEDDLING: raise a wisp for a dead HUMAN seat (never a bot — that is what
	# keeps every all-bot receipt byte-identical). Removed again on respawn.
	if not fighters[victim].is_bot:
		_meddle.add_ghost(victim, str(_names[victim]), _colors[victim], fighters[victim].global_position)
		_refresh_meddle_hints()
	_shake = maxf(_shake, 0.7 if self_echo else 0.55)
	_spawn_death_fx(fighters[victim].global_position, _colors[victim])
	# THE DECIDING MOMENT (doc 09 §Q2): a KO inside the final round's dying 10
	# seconds decides the match — there is no time to answer it. Deep freeze +
	# fov punch + a named beat. Ordinary KOs keep the 45ms hitpause (echo was
	# already demote-compliant); the self-echo irony beat keeps its §2.1 depth.
	var deciding: bool = round_no >= _rounds and _rounds > 1 and state == St.PLAY \
			and _round_time >= round_len - 10.0
	if deciding and FinalStretch.motion_ok():
		_net_decide_n += 1
		_slowmo(0.25, 0.85)
		FinalStretch.fov_punch(camera, 52.0, 6.0, 0.85)
		if not self_echo:
			_flash_banner("THE DYING SECONDS CLAIM %s" % _names[victim], _colors[victim], 1.8)
	elif self_echo:
		_slowmo(0.3, 0.5)
	else:
		_hitpause()


# ===========================================================================
# Spawns
# ===========================================================================
func platform_r() -> float:
	return ARENA_R * SHRINK if _shrunk else ARENA_R


## The enforced play boundary (the yellow ring). Constant across rounds — the
## round-final floor collapse just makes stepping past it physical too. Spawns
## and bot wander targets stay inside this so nobody spawns into a ring-out.
func ring_r() -> float:
	return RING_R


func _start_pos(i: int) -> Vector3:
	var n := fighters.size()
	var ang := TAU * float(i) / float(maxi(1, n))
	var rad := 3.6
	return Vector3(cos(ang) * rad, 0.05, sin(ang) * rad)


func _edge_spawn() -> Vector3:
	# spawn just inside the ring (never on the apron) so a respawn can't drop the
	# fighter straight into a ring-out warning.
	var ang := rng.randf_range(0.0, TAU)
	var rad := RING_R * 0.82
	return Vector3(cos(ang) * rad, 0.1, sin(ang) * rad)


func _center_spawn() -> Vector3:
	var ang := rng.randf_range(0.0, TAU)
	var rad := rng.randf_range(0.4, 1.6)
	return Vector3(cos(ang) * rad, 0.1, sin(ang) * rad)


# ===========================================================================
# UI / juice
# ===========================================================================
func _rebuild_scoreboard() -> void:
	var order := _placements()
	var existing := score_rows.get_child_count()
	# rebuild only when count changes; otherwise update in place (cheap)
	if existing != order.size():
		for c in score_rows.get_children():
			c.queue_free()
		for _i in order.size():
			# Row is an HBox: [PlayerBadge, Label] so shape+color+name travel
			# together. Slots reorder by placement, so the badge's player is
			# reassigned in the update pass below.
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			hb.add_child(PlayerBadge.make(0, 22))
			var row := Label.new()
			row.add_theme_font_override("font", _font_baloo)
			row.add_theme_font_size_override("font_size", 22)
			row.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
			row.add_theme_constant_override("outline_size", 5)
			hb.add_child(row)
			score_rows.add_child(hb)
	var rows := score_rows.get_children()
	for i in order.size():
		var idx: int = order[i]
		var hb := rows[i] as HBoxContainer
		var badge := hb.get_child(0) as PlayerBadge
		var row := hb.get_child(1) as Label
		var found := false
		var alive := true
		var hp_txt := ""
		for f in fighters:
			if f.player_index == idx:
				found = true
				alive = f.alive
				var pips := int(f.hp) if f.alive else 0
				for _h in pips:
					hp_txt += "♥"
				for _h in (HP_MAX - pips):
					hp_txt += "·"
				break
		badge.player_index = idx
		badge.color = _colors[idx]
		badge.dim = 1.0 if (not found or alive) else 0.45
		row.text = "%s  %d  %s" % [_names[idx], int(points[idx]), hp_txt]
		row.add_theme_color_override("font_color", _colors[idx])


func _flash_banner(text: String, color: Color, auto_hide: float) -> void:
	_ban_col = color.to_html(false)
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.5, 0.5)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if auto_hide > 0.0:
		var tw := create_tween()
		tw.tween_interval(auto_hide)
		tw.tween_callback(func(): banner.visible = false)


func _flash_credit(text: String, color: Color) -> void:
	_cb_col = color.to_html(false)
	credit_banner.text = text
	credit_banner.add_theme_color_override("font_color", color)
	credit_banner.visible = true
	credit_banner.pivot_offset = credit_banner.size / 2.0
	credit_banner.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(credit_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hide := create_tween()
	hide.tween_interval(1.1)
	hide.tween_callback(func(): credit_banner.visible = false)


func _hit_feedback(pos: Vector3, color: Color, is_heavy := false) -> void:
	Sfx.play("bumper", -4.0 if is_heavy else -6.0)
	_shake = maxf(_shake, 0.5 if is_heavy else 0.28)
	_spawn_death_fx(pos + Vector3(0, 0.9, 0), color, 20 if is_heavy else 12, 0.55 if is_heavy else 0.5)


## A fighter began charging a heavy — grab the readable windup once (verify).
func notify_charge() -> void:
	_event_capture("heavy_windup")


## One-shot state-driven screenshot of a transient combat beat (windup / parry
## / ghost fragment). Fires the first time each beat happens after warmup, so
## the required v1.1 evidence lands without frame-index guessing. Windowed only.
func _event_capture(tag: String) -> void:
	if not _cap_on or _ev_captured.has(tag):
		return
	if state != St.PLAY or _round_time < 1.0:
		return
	if DisplayServer.get_name() == "headless":
		return
	_ev_captured[tag] = true
	_grab(tag, false)


func _hitpause() -> void:
	# SHOULD: brief freeze on impact; throttled so a swarm of ghosts can't
	# lock the game into permanent slow-mo.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hitpause < 0.16:
		return
	_last_hitpause = now
	Engine.time_scale = 0.2
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## IRONY PACK: a deeper, deliberate slow-mo for the self-echo kill (doc 09 §2.1
## asks 0.3x/0.5s). Same time_scale-independent restore timer as _hitpause, and
## it seeds _last_hitpause so an ordinary hit-pause in the same instant can't cut
## the beat short inside the throttle window.
func _slowmo(scale: float, dur: float) -> void:
	_last_hitpause = Time.get_ticks_msec() / 1000.0
	Engine.time_scale = scale
	get_tree().create_timer(dur, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _spawn_death_fx(pos: Vector3, color: Color, amount := 24, life := 0.8) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos + Vector3(0, 0.15, 0)
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _spawn_confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 22
		p.lifetime = 1.4
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 3.5
		p.initial_velocity_max = 7.0
		p.gravity = Vector3(0, -7.0, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.02, 0.08)
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.5).timeout.connect(p.queue_free)


# ===========================================================================
# ONLINE (phase 2) — the render mirror (docs/design/10 §4.3, house pattern)
# ===========================================================================
# Physics stays HOST-SIDE; the client renders. Fighters AND ghosts ride one
# body-indexed PackedInt32Array (stride 8, cm/mrad quantized): ghosts are
# deterministic replays on the host, but the mirror receives their POSES on
# the wire instead of re-simulating the takes — zero drift risk for the cost
# of ~32 bytes per ghost per snapshot. All juice fires from deltas (hp drops,
# alive edges, counters, banner changes); _mirror_tick interpolates at 60 Hz.
# No hidden info in the arena — nothing rides the private channel.

## HOST, pumped by the estate at 20 Hz. Compact PUBLIC facts only.
func _net_state() -> Dictionary:
	var nf := fighters.size()
	var bd := PackedInt32Array()
	for f in fighters:
		var fl := 0
		if f.alive:
			fl |= 1
		if _ring_warn.has(f.player_index):
			fl |= 2
		bd.append_array(PackedInt32Array([
			int(roundf(f.global_position.x * 100.0)),
			int(roundf(f.global_position.y * 100.0)),
			int(roundf(f.global_position.z * 100.0)),
			int(roundf(f.yaw * 1000.0)),
			f.state, f.hp, fl, 0]))
	for g in ghosts:
		if g.done or not is_instance_valid(g):
			continue
		bd.append_array(PackedInt32Array([
			int(roundf(g.global_position.x * 100.0)),
			int(roundf(g.global_position.y * 100.0)),
			int(roundf(g.global_position.z * 100.0)),
			int(roundf(g.yaw * 1000.0)),
			maxi(g.cur_state, 0), g.owner_index, g.gid,
			int(roundf(g.opacity * 100.0))]))
	var pts := PackedInt32Array()
	for f in fighters:
		pts.append(int(points[f.player_index]))
	return {
		"ph": state, "rn": round_no, "rmax": _rounds,
		"rem": snappedf(maxf(0.0, round_len - _round_time), 0.05),
		"shr": _shrunk, "nf": nf, "bd": bd, "pts": pts,
		"ban": [banner.text, _ban_col, banner.visible],
		"cb": [credit_banner.text, _cb_col, credit_banner.visible],
		"pn": _net_parry_n, "pw": _net_parry_seat,
		"bn": _net_bounty_n, "hn": _net_haunt_n, "dn": _net_decide_n,
		"champ": _net_champ,
	}


## CLIENT. Latest-state-wins; all juice fires from DELTAS. Continuous motion
## only sets targets; _mirror_tick interpolates at the render rate.
func _net_apply(st: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = st
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()   # FINAL STRETCH: light bed on first snapshot
	var ph := int(st.get("ph", St.INTRO))
	var rn := int(st.get("rn", 0))
	var rmax := int(st.get("rmax", ROUNDS))
	state = ph
	# --- round flips: label, arena reset, FINAL STRETCH re-arm/escalate.
	# rmax comes off the WIRE (the client estate boots mirrors with a stock
	# rounds count) — the final-round flip must never read local _rounds.
	if rn != int(prev.get("rn", -1)):
		round_no = rn
		round_label.text = "ROUND %d / %d" % [rn, rmax]
		_mir_rem0 = float(st.get("rem", 0.0))
		_reset_arena(false)
		if not prev.is_empty():
			Sfx.play("round_over")
		if _stretch != null:
			if rn >= rmax and rmax > 1:
				_stretch.escalate()
			else:
				_stretch.round_reset()
		print("ECHO_MIRROR round=%d/%d" % [rn, rmax])
	# --- timer + FINAL STRETCH ladder off the authoritative clock
	var rem := float(st.get("rem", 0.0))
	if ph == St.PLAY:
		timer_label.text = "%0.1f" % rem
		timer_label.add_theme_color_override("font_color",
			Color(1, 0.35, 0.3) if rem < 6.0 else Color(1, 1, 1))
	if _stretch != null:
		if ph == St.PLAY:
			_stretch.tick(rem)
		elif ph == St.DONE:
			_stretch.match_ended()
	if ph == St.DONE and int(prev.get("ph", -1)) != St.DONE:
		round_label.text = "FINAL"
		timer_label.text = ""
	# --- the round-final collapse (its banner rides the ban fact)
	if bool(st.get("shr", false)) and not bool(prev.get("shr", false)):
		_shrink_fx()
		if not _mir_snapped.has("mirror_shrink"):
			_mir_snapped["mirror_shrink"] = true
			VerifyCapture.snap("mirror_shrink")
	# --- fighters: interp targets + instant facts (hp/alive edges ARE the juice)
	var nf := int(st.get("nf", fighters.size()))
	var bd: PackedInt32Array = st.get("bd", PackedInt32Array())
	for i in mini(nf, fighters.size()):
		var o := i * 8
		if o + 8 > bd.size():
			break
		var f: EchoFighter = fighters[i]
		_mir_f[i][0] = Vector3(bd[o] / 100.0, bd[o + 1] / 100.0, bd[o + 2] / 100.0)
		_mir_f[i][1] = bd[o + 3] / 1000.0
		_mir_f[i][2] = bd[o + 4]
		var hp := bd[o + 5]
		var fl := bd[o + 6]
		var now_alive := (fl & 1) != 0
		if now_alive and not f.alive:
			Sfx.play("confirm", -4.0)          # respawn chime (couch parity)
			f.global_position = _mir_f[i][0]   # spawn teleports snap, not glide
			# GHOST MEDDLING (mirror): the alive edge is our death/respawn signal
			# here (no sim runs). Retire this seat's wisp as it returns.
			_meddle.remove_ghost(int(f.player_index))
			_refresh_meddle_hints()
		elif not now_alive and f.alive:
			Sfx.play("death")
			_shake = maxf(_shake, 0.55)
			_spawn_death_fx(f.global_position, _colors[f.player_index])
			# GHOST MEDDLING (mirror): raise this dead HUMAN seat's wisp locally so
			# the guest still feels present as a ghost (bots never do).
			if not f.is_bot:
				_meddle.add_ghost(int(f.player_index), str(_names[f.player_index]), _colors[f.player_index], f.global_position)
				_refresh_meddle_hints()
		elif now_alive and hp < f.hp:
			_hit_feedback(f.global_position, f.color, f.hp - hp >= 2)
		f.hp = hp
		f.alive = now_alive
		_mir_warn[i] = (fl & 2) != 0
		if not bool(_mir_warn[i]):
			f.set_ring_warning(false)
	# --- ghosts: streamed poses in the same block (never re-simulated)
	var seen := {}
	var gi := nf * 8
	while gi + 8 <= bd.size():
		var gpos := Vector3(bd[gi] / 100.0, bd[gi + 1] / 100.0, bd[gi + 2] / 100.0)
		var ggid := bd[gi + 6]
		var gopa := bd[gi + 7] / 100.0
		seen[ggid] = true
		if not _mir_ghosts.has(ggid):
			_mir_ghosts[ggid] = {"node": _mir_spawn_ghost(bd[gi + 5], gopa, gpos),
				"pos": gpos, "yaw": bd[gi + 3] / 1000.0, "st": bd[gi + 4], "opa": gopa}
		else:
			var rec: Dictionary = _mir_ghosts[ggid]
			rec["pos"] = gpos
			rec["yaw"] = bd[gi + 3] / 1000.0
			rec["st"] = bd[gi + 4]
			if absf(float(rec["opa"]) - gopa) > 0.01:
				rec["opa"] = gopa
				(rec["node"] as EchoGhost).set_opacity(gopa)
		gi += 8
	for ggid in _mir_ghosts.keys():
		if not seen.has(ggid):
			var gone: EchoGhost = _mir_ghosts[ggid]["node"]
			if is_instance_valid(gone):
				# a PLAY despawn is the fragment beat; round swaps clear silently
				if ph == St.PLAY:
					_spawn_fragments(gone.global_position + Vector3(0, 0.9, 0), gone.owner_color)
				gone.queue_free()
			_mir_ghosts.erase(ggid)
	ghost_label.text = "GHOSTS: %d" % _mir_ghosts.size()
	# --- HUD banners (pop once per text change, same tween as the couch)
	_apply_mir_banner(banner, st.get("ban", []), prev.get("ban", []))
	_apply_mir_banner(credit_banner, st.get("cb", []), prev.get("cb", []))
	# --- juice counters (counters, not events: drops lose nothing but frames)
	if int(st.get("pn", 0)) > int(prev.get("pn", 0)):
		var pw := int(st.get("pw", 0))
		Sfx.play("confirm", 0.5)
		if pw >= 0 and pw < fighters.size():
			_spawn_death_fx(fighters[pw].global_position + Vector3(0, 1.1, 0), Color(1, 1, 0.75), 14, 0.4)
		_shake = maxf(_shake, 0.22)
		if not _mir_snapped.has("mirror_parry"):
			_mir_snapped["mirror_parry"] = true
			VerifyCapture.snap("mirror_parry")
	if int(st.get("bn", 0)) > int(prev.get("bn", 0)):
		Sfx.play("grudge", -2.0)   # PAST X STRIKES AGAIN (text rides cb)
	if int(st.get("hn", 0)) > int(prev.get("hn", 0)):
		Sfx.play("grudge", 0.0)    # KILLED BY THEIR OWN ECHO (banner rides ban)
		_shake = maxf(_shake, 0.7)
		if not _mir_snapped.has("mirror_irony"):
			_mir_snapped["mirror_irony"] = true
			VerifyCapture.snap("mirror_irony")
	if int(st.get("dn", 0)) > int(prev.get("dn", 0)) and FinalStretch.motion_ok():
		FinalStretch.fov_punch(camera, 52.0, 6.0, 0.85)   # THE DECIDING MOMENT
		_shake = maxf(_shake, 0.5)
	# --- champion (pre-announced one beat before finished(); banner rides ban)
	var champ := int(st.get("champ", -1))
	if champ >= 0 and int(prev.get("champ", -1)) < 0:
		Sfx.play("match_win")
		_spawn_confetti(Vector3(0, 2.5, 0), _colors[champ] if _colors.has(champ) else Color.WHITE)
		_shake = maxf(_shake, 0.6)
		print("ECHO_MIRROR champ=%d" % champ)
		if not _mir_snapped.has("mirror_champ"):
			_mir_snapped["mirror_champ"] = true
			VerifyCapture.snap("mirror_champ")
	# --- scoreboard from pts + the hp facts applied above
	var pts: PackedInt32Array = st.get("pts", PackedInt32Array())
	for i in mini(pts.size(), fighters.size()):
		points[fighters[i].player_index] = pts[i]
	_rebuild_scoreboard()
	# --- evidence latch: the haunted-arena read (live + ghost bodies together;
	# ~5 s into the round so echoes have fanned out from the spawn rings)
	var round_ran := _mir_rem0 - rem >= 5.0
	if ph == St.PLAY and rn >= 2 and round_ran and _mir_ghosts.size() >= 3 and not _mir_snapped.has("mirror_ghosts"):
		_mir_snapped["mirror_ghosts"] = true
		VerifyCapture.snap("mirror_ghosts")
	if ph == St.PLAY and rn >= rmax and rmax > 1 and round_ran and _mir_ghosts.size() >= 6 and not _mir_snapped.has("mirror_r5"):
		_mir_snapped["mirror_r5"] = true
		VerifyCapture.snap("mirror_r5")


## CLIENT, per physics tick: glide every body toward its authoritative pose.
## Teleports (respawns, recorded respawn snaps) never glide — distance > 4
## snaps, mirroring the ghost replayer's own rule.
func _mirror_tick(delta: float) -> void:
	_mir_clock += delta
	if _mir.is_empty():
		return
	var k := 1.0 - exp(-14.0 * delta)
	for i in mini(_mir_f.size(), fighters.size()):
		var f: EchoFighter = fighters[i]
		var tgt: Vector3 = _mir_f[i][0]
		var np := tgt if f.global_position.distance_to(tgt) > 4.0 else f.global_position.lerp(tgt, k)
		f.net_pose(np, lerp_angle(f.yaw, float(_mir_f[i][1]), k), int(_mir_f[i][2]))
		if bool(_mir_warn.get(i, false)) and f.alive:
			f.set_ring_warning(true, fmod(_mir_clock, 0.26) < 0.13)
	for ggid in _mir_ghosts:
		var rec: Dictionary = _mir_ghosts[ggid]
		var g: EchoGhost = rec["node"]
		if not is_instance_valid(g):
			continue
		var tp: Vector3 = rec["pos"]
		var np2 := tp if g.global_position.distance_to(tp) > 4.0 else g.global_position.lerp(tp, k)
		g.net_pose(np2, lerp_angle(g.yaw, float(rec["yaw"]), k), int(rec["st"]))

	# GHOST MEDDLING (mirror): drive the LOCAL seat's wisp from its own input; the
	# others idle-drift. This is a SIM meddle, so a wisp's A does NOT fire here —
	# the guest's A relays to the host, whose stagger arrives via the pose snapshot.
	_meddle.tick_cosmetic(delta, NetSession.my_seat())


## Mirror banner applier (throne pattern): text + color as facts, pop locally
## once per text change.
func _apply_mir_banner(l: Label, arr: Array, parr: Array) -> void:
	if arr.size() < 3:
		return
	l.text = str(arr[0])
	l.add_theme_color_override("font_color", Color(str(arr[1])))
	var was: bool = parr.size() >= 3 and bool(parr[2]) and str(parr[0]) == str(arr[0])
	l.visible = bool(arr[2])
	if l.visible and not was:
		l.pivot_offset = l.size / 2.0
		l.scale = Vector2(0.6, 0.6)
		var tw := create_tween()
		tw.tween_property(l, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not l.visible:
		l.scale = Vector2.ONE


## A mirror ghost: same EchoGhost body/tint, EMPTY take — replay() never runs;
## net_pose() streams its life instead.
func _mir_spawn_ghost(owner: int, opa: float, pos: Vector3) -> EchoGhost:
	var g := EchoGhost.new()
	g.take = {"char": _char_of(owner), "count": 0,
		"pos": PackedVector3Array(), "yaw": PackedFloat32Array(),
		"state": PackedByteArray(), "fire": PackedByteArray()}
	g.owner_index = owner
	g.owner_color = _colors[owner] if _colors.has(owner) else Color.WHITE
	g.opacity = opa
	g.main = null   # a mirror ghost never replays, reports or fragments itself
	add_child(g)
	g.setup()
	g.global_position = pos
	return g


func _char_of(owner: int) -> String:
	for pl in roster:
		if int(pl["index"]) == owner:
			return str(pl.get("char_scene", DEFAULT_CHARS[owner % DEFAULT_CHARS.size()]))
	return DEFAULT_CHARS[owner % DEFAULT_CHARS.size()]


## Host-side probe evidence: latched windowed snaps at the beats the mirror
## also latches. Inert offline and in every headless receipt (VerifyCapture
## is only active under probe flags).
func _net_snap(tag: String) -> void:
	if _mirror or _net_snapped.has(tag) or not NetSession.is_online() or not NetSession.is_host():
		return
	_net_snapped[tag] = true
	VerifyCapture.snap(tag)


# ===========================================================================
# Standalone restart
# ===========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _selfstarted and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# ===========================================================================
# Mouse-aim verification (--aimprobe=<deg>): pin player 0 (a KBM human) at
# centre facing 90° off a synthetic cursor, screenshot it, fire a real light
# swing, screenshot again. The body + arc snap to the CYAN aim ray, not the
# WHITE facing ray. Two shots: verify_out/echo_aim_{facing,acting}.png.
# ===========================================================================
func _run_aim_probe() -> void:
	while state != St.PLAY:
		await get_tree().physics_frame
	var f: EchoFighter = fighters[0]
	var aim_yaw := deg_to_rad(_aim_probe_deg)
	var face_yaw := aim_yaw + PI * 0.5           # deliberately perpendicular
	# park the bot far off so it can't interfere with the framed shot
	if fighters.size() > 1:
		fighters[1].global_position = Vector3(40, 0.05, 40)
	f.global_position = Vector3(0, 0.05, 0)
	f.yaw = face_yaw
	var origin := Vector3(0, 0.05, 0)
	_probe_arrow(origin, face_yaw, Color(1, 1, 1), 3.2)                 # facing (white)
	_probe_arrow(origin, aim_yaw, Color(0.2, 0.95, 1.0), 3.2)          # cursor aim (cyan)
	await get_tree().create_timer(0.45).timeout
	await _probe_grab("facing")
	print("ECHO_AIMPROBE face=%.0fdeg aim=%.0fdeg body_before=%.0fdeg" % [
		rad_to_deg(face_yaw), _aim_probe_deg, rad_to_deg(f.yaw)])
	f.debug_probe_light()
	await get_tree().create_timer(0.12).timeout                        # mid-swing
	await _probe_grab("acting")
	print("ECHO_AIMPROBE body_after=%.0fdeg matches_aim=%s" % [
		rad_to_deg(f.yaw), str(absf(rad_to_deg(f.yaw) - _aim_probe_deg) < 5.0)])
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()


func _probe_arrow(origin: Vector3, yaw_a: float, col: Color, length: float) -> void:
	var dir := Vector3(sin(yaw_a), 0.0, cos(yaw_a))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, length)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.4
	mi.material_override = m
	mi.position = origin + dir * (length * 0.5) + Vector3(0, 1.1, 0)
	mi.rotation.y = yaw_a
	add_child(mi)
	# a fat tip so the arrow reads directionally, not as a bar
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.42, 0.42, 0.42)
	tip.mesh = tm
	tip.material_override = m
	tip.position = origin + dir * length + Vector3(0, 1.1, 0)
	add_child(tip)


func _probe_grab(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("ECHO_AIMPROBE_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/echo_aim_%s.png" % [_cap_dir, tag]
	img.save_png(path)
	print("ECHO_AIMPROBE_CAP ", path)
