extends Minigame
## ORBITAL DODGEBALL - anthology minigame (module contract: core/minigame.gd).
## Dodgeball on 3 tiny planets with real radial gravity. Thrown balls NEVER
## despawn - they orbit the cluster, decaying over ~40s of space drag, and a
## kill credits the LAST THROWER forever ("GOLD'S GHOST ORBIT STRIKES" on a
## 30-second-old throw).
##
## Controls (PlayerInput): move = surface walk (screen-relative),
##   A tap (empty hands) = catch window, walk over a ball = pick up,
##   A hold (holding)    = aim + power ramp, release = throw,
##   B = jump (hop; at the near points you can hop to a neighboring planet).
##
## Standalone: runs self-contained - if the shell has not called begin()
## within 0.5s the game begins itself with a default 4-player roster built
## from GameState consts. CLI user args (after --):
##   --seed=N       rng seed for the default config (default 1)
##   --players=N    default-roster size 2..4 (default 4)
##   --orbbots      seeded self-play bots on every seat
##   --fast=K       Engine.time_scale multiplier for long sims (mutes audio)
##   --matchsec=N   override match length (default 180)
##   --autoquit     quit after the match report / test completion
##   --orbtest=circ bot circumnavigates each planet on constant stick input,
##                  logs heading continuity (control-flip evidence), quits
##   --orbtest=aim  player 0 holds a full-power aim forever (preview shots)
##   --orbtest=xray occluded-visibility tableau: 2 pawns planted far-side of a
##                  planet (occluded) + 2 near-side (visible) + 1 ball parked
##                  far-side; logs point_occluded() facts, quits
##   --shots=N,...  (VerifyCapture autoload) capture PNGs at those frames
## All gameplay randomness comes from config.rng_seed. No physics bodies are
## used at all - balls, pawns and collisions are hand-integrated in
## _physics_process, so there are no deferred-physics-state gotchas.

enum Phase { WAIT, PLAY, END }

const PLANET_DEFS := [
	{"radius": 3.0, "center": Vector3(-3.8, -2.1, 0), "gsurf": 13.0, "col": Color(0.28, 0.42, 0.52)},
	{"radius": 2.2, "center": Vector3(3.5, -2.5, 0), "gsurf": 12.0, "col": Color(0.55, 0.33, 0.24)},
	{"radius": 1.8, "center": Vector3(0.8, 3.3, 0), "gsurf": 11.0, "col": Color(0.42, 0.32, 0.58)},
]
const START_BALLS := [
	{"planet": 0, "n": Vector3(-0.25, 0.55, 0.80)},
	{"planet": 0, "n": Vector3(0.55, -0.45, 0.70)},
	{"planet": 1, "n": Vector3(0.30, 0.35, 0.89)},
	{"planet": 2, "n": Vector3(-0.40, 0.30, 0.87)},
]
const START_SPOTS := [
	{"planet": 0, "n": Vector3(0.65, 0.35, 0.68)},
	{"planet": 1, "n": Vector3(-0.45, 0.25, 0.86)},
	{"planet": 2, "n": Vector3(0.30, -0.20, 0.93)},
	{"planet": 0, "n": Vector3(-0.70, -0.30, 0.65)},
]
const KAYKIT_CHARS := ["Barbarian", "Knight", "Mage", "Rogue"]
const MATCH_LEN := 180.0
const BALL_SPAWN_EVERY := 45.0
const MAX_BALLS := 8
const KILL_POINTS := 2
const CATCH_POINTS := 1
const GHOST_AGE := 10.0
const MONUMENT_AGE := 25.0
const RESPAWN_DELAY := 3.0
const MAX_FLIGHT_AGE_ASSERT := 75.0
const BOUNDARY_R := 13.0
const CAM_POS := Vector3(-0.2, 0.2, 17.6)
const CAM_FOV := 46.0

const GAME_INTRO := {
	"name": "ORBITAL DODGEBALL",
	"goal": "Dodgeball on three tiny planets. Every throw orbits forever and can still kill you.",
	"accent": Color(1.0, 0.85, 0.25),
	"controls": [
		{"action": "move", "label": "WALK the surface"},
		{"action": "a", "label": "HOLD: AIM+THROW · TAP: CATCH"},
		{"action": "b", "label": "JUMP the gap"},
	],
	"tips": [
		"A throw never truly leaves — it just keeps orbiting the cluster until physics or a body stops it.",
		"Hop near the gap between two planets to jump to the next one.",
	],
}

var config := {}
var rng := RandomNumberGenerator.new()
var phase := Phase.WAIT
var now := 0.0
var _intro_card: IntroCard = null
var match_len := MATCH_LEN
var time_left := MATCH_LEN

var planets: Array = []   # [{center, radius, mu, col}]
var pawns: Array = []     # [OrbPawn]
var balls: Array = []     # [OrbBall]
var bots: Array = []      # per player index: OrbBot or null (human seat)
var bot_enabled: Array = []  # per player index: bool, decided at begin()
var bots_enabled := false    # legacy --orbbots flag: force ALL seats to bots

var kills := {}
var catches := {}
var deaths := {}
var _points := {}
var _currency: Array = []
var _kill_events: Array = []   # {killer:int, victim:int, cause:String} per contract
var _respawn_queue: Array = []
var _oldest_kill_age := 0.0
var _oldest_kill_txt := ""
var _ghost_monument := {}   # player -> best ghost age > MONUMENT_AGE
var _best_catch_age := 0.0
var _best_catch_txt := ""
var _throws := 0
var _hops := 0
var _max_flight_age := 0.0
var _age_fail := false
var _next_spawn := BALL_SPAWN_EVERY
var _names: Array = []
var _colors: Array = []

var _begun := false
var _cli_seed := 1
var _cli_players := 4
var _fast := 1.0
var _autoquit := false
var _match_override := -1.0
var _test_mode := ""
var _aim_probe_deg := 0.0
var _orb_probe_release := false
var _orb_probe_armed := false
var _orb_probe_line: Line2D = null
var _shake := 0.0
var _slowmo_left := 0.0  # game-seconds of slow-mo remaining (tick-driven)
var _circ := {}

var _cam: Camera3D
var _ball_root: Node3D
var _trail_root: Node3D
var _pawn_root: Node3D
var _fx_root: Node3D
var _aim_mesh: MeshInstance3D
var _aim_im: ImmediateMesh
var _banner: Label
var _event_label: Label
var _timer_label: Label
var _hint_label: Label
var _score_rows: VBoxContainer
var _meddle: GhostMeddle       # GHOST MEDDLING (doc 24 §6 / B6): dead humans get one verb
var _meddle_shot := false      # dev: force a seat-0 wisp for a windowed shot
var _meddle_shot_done := false
var _row_labels: Array = []
var _event_until := 0.0
var _banner_gen := 0

## --- THREAT LADDER (presentation only) --------------------------------------
## Speed-tier danger feedback: escalating ball heat, a proximity danger
## vignette, threat-tone audio, and a speed-scaled kill impact. NONE of this
## feeds the deterministic sim (all driven from _process / _do_kill's
## presentation tail, no rng, no sim-state writes) so same-seed KILL_EVENTS
## stay byte-identical. Motion-heavy pieces respect PartySetup's screen_shake
## (reduced-motion) preference, the HIT KIT pattern.
var _impact_amp := 0.0        # 0..1 kill punch, decays each frame
var _impact_decay := 10.0     # faster ball -> quicker decay (deeper, shorter)
var _decide_fov_ms := 0       # FINAL ORBIT: real-time deadline while the shared fov_punch owns the lens

# NOTE (JUICE W5): orbital is the one game DELIBERATELY exempted from the house
# rotational-shake roll. Its sim reads _cam.global_basis as the screen-relative
# control frame (screen_right/up, get_aim_screen), so rolling the camera would
# rotate that frame and perturb bot movement -- a determinism break (proven: it
# desynced the --fast receipt run-to-run). Translation shake (h/v_offset) is safe
# because it never touches the basis. The fov punch below is safe for the same
# reason the existing _impact_amp fov beat is: fov never enters the control frame.
var _vig_strength := 0.0      # smoothed danger-vignette strength
var _vignette: ColorRect
var _vig_mat: ShaderMaterial
var _threat_pool: Array = []  # AudioStreamPlayer pool for pitched threat tones
var _threat_next := 0
# THE FINAL STRETCH kit (doc 09 §Q1/§4.3): T-30 "FINAL ORBIT" — tense music,
# last-10s ticks, timer pulse. The lighting nudge here is the doc's starfield
# tint 20% toward red (kit vignette OFF — the threat ladder owns the red
# screen edges). Never attached under --orbtest, so probe receipts hold.
var _stretch: FinalStretch = null
var _star_mat: StandardMaterial3D = null   # starfield tint target (FINAL ORBIT)

## --- ONLINE (phase 2) --------------------------------------------------------
## House pattern (docs/verify/online-seance-VERIFY.md PATTERN NOTES): host sim
## untouched, _net_state() = one flat dict of PUBLIC facts pumped at 20 Hz by
## the estate, _net_apply() diffs + fires ALL juice from deltas, _mirror_tick()
## interpolates at 60 Hz. Orbital has no hidden info — no private channel. The
## soul of this mirror is the BALLS: state + velocity stream, so the client's
## own heat/threat/trail presentation (all velocity-derived) renders the same
## menace the couch sees, and a 30-second-old ghost orbit pulses identically.
const NET_ANIMS := ["Idle", "Running_A", "Jump_Idle", "1H_Ranged_Aiming",
	"Throw", "PickUp", "Jump_Land", "Death_A", "Cheer"]
var _mirror := false
var _mir := {}                  # last applied snapshot (delta source for juice)
var _mir_ball_t := 0.0          # seconds since last snapshot (ball dead-reckoning)
var _mir_snaps := {}            # evidence snapshots fired once (probe runs)
var _mir_done := false          # champion confetti fired
var _banner_col := "ffffff"     # last banner color (wire fact)
var _event_col := "ffffff"      # last event-line color (wire fact)
var _event_gen := 0             # bumps per flash so repeats still fire
var _net_fo := 0                # FINAL ORBIT flag (0/1) — the kit trigger fact
var _net_bounce := 0            # ball-bounce counter + last impact (sfx fact)
var _net_bounce_imp := 0.0
var _net_kill: Array = [0, -1, -1, 0.0]   # [gen, victim, killer, ball speed]
var _net_champ := -1            # pre-announced winner (end facts beat the fold)

func _ready() -> void:
	_parse_args()
	_build_static()
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if not _begun:
			begin(_default_config()))

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--orbbots":
			bots_enabled = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--fast="):
			_fast = clampf(float(arg.trim_prefix("--fast=")), 1.0, 30.0)
		elif arg == "--autoquit":
			_autoquit = true
		elif arg == "--orbmeddleshot":
			_meddle_shot = true    # dev-only: photograph a live ghost-meddle wisp (windowed)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
		elif arg.begins_with("--matchsec="):
			_match_override = float(arg.trim_prefix("--matchsec="))
		elif arg.begins_with("--orbtest="):
			_test_mode = arg.trim_prefix("--orbtest=")
		elif arg.begins_with("--aimprobe="):
			_test_mode = "aimprobe"
			_aim_probe_deg = float(arg.trim_prefix("--aimprobe="))
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	if _fast > 1.01:
		# Faster-than-realtime WITHOUT changing the integration step:
		# Godot passes delta = time_scale / physics_ticks_per_second to
		# _physics_process, so scale BOTH by K -> dt stays exactly 1/60 and
		# the sim runs K ticks per real tick, bit-identical to a live match.
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
			"bot": PlayerInput.standalone_bot_default(i),
		})
	return {"roster": roster, "rounds": 1, "rng_seed": _cli_seed, "practice": false}

func begin(cfg: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	config = cfg
	_mirror = bool(cfg.get("net_mirror", false))
	rng.seed = int(cfg.rng_seed)
	match_len = _match_override if _match_override > 0.0 else (MATCH_LEN if not cfg.get("practice", false) else 90.0)
	time_left = match_len
	var roster: Array = cfg.roster
	for pl in roster:
		var idx: int = pl.index
		_names.resize(maxi(_names.size(), idx + 1))
		_colors.resize(maxi(_colors.size(), idx + 1))
		_names[idx] = pl.name
		_colors[idx] = pl.color
		kills[idx] = 0
		catches[idx] = 0
		deaths[idx] = 0
		_points[idx] = 0
	if _test_mode != "circ":
		for sb in START_BALLS:
			_spawn_ball_at(sb.planet, Vector3(sb.n).normalized(), true)
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var pawn := OrbPawn.new()
		pawn.world = self
		pawn.index = pl.index
		_pawn_root.add_child(pawn)
		pawn.setup(load(String(pl.char_scene)), pl.color)
		var spot: Dictionary = START_SPOTS[i % START_SPOTS.size()]
		pawn.place_on(spot.planet, Vector3(spot.n).normalized())
		pawns.append(pawn)
	# Per-player bots: a seat is bot-driven if the roster marks it a bot (shell
	# sets it from estate._is_bot; standalone from PlayerInput) OR the legacy
	# --orbbots flag forces ALL bots. Human seats get a null slot and read
	# PlayerInput. Seeds are per index, so the all-bots path is bit-identical to
	# before. Scripted --orbtest modes drive pawn 0 directly - no bot brains.
	bot_enabled.resize(roster.size())
	bots.resize(roster.size())
	for i in roster.size():
		bot_enabled[i] = bots_enabled or bool(roster[i].get("bot", false))
		if bot_enabled[i] and _test_mode == "" and not _mirror:
			var bot := OrbBot.new()
			bot.setup(self, i, int(cfg.rng_seed) * 977 + i * 131)
			bots[i] = bot
	var _cbar := _controls_bar()
	if _cbar != "":
		_hint_label.text = _cbar
	if _mirror:
		# RENDER MIRROR (spec §4.3, house pattern): no bots, no sim, no rng
		# draws — the host owns every fact. The world, pawns, start balls and
		# pedestals above are deterministic consts, so the first snapshot lands
		# on identical furniture. phase stays WAIT until _net_apply flips it.
		_stretch = FinalStretch.attach(self, _timer_label, {"vignette": false})
		_update_score_rows()
		NetSession.set_aim_provider(_net_aim)
		print("ORB_MIRROR boot players=%d my_seat=%d" % [pawns.size(), NetSession.my_seat()])
		return
	# NIT 7 idiom: intro card at load; headless evidence/test/probe keep sync start.
	if _test_mode != "" or _autoquit:
		_start_match()
	else:
		_hint_label.visible = false   # revealed once the intro card clears (no double-gate)
		_present_intro_card()


func _present_intro_card() -> void:
	_intro_card = IntroCard.new()
	add_child(_intro_card)
	_intro_card.started.connect(_start_match)
	var spec: Dictionary = GAME_INTRO.duplicate(true)
	spec["seats"] = _human_seats()
	_intro_card.present(spec)


func _start_match() -> void:
	phase = Phase.PLAY
	_hint_label.visible = true
	if _test_mode == "":
		_stretch = FinalStretch.attach(self, _timer_label, {"vignette": false})
		_stretch.play_started()   # FINAL STRETCH: light bed over the void
	_update_score_rows()
	if _test_mode == "circ":
		_circ_start()
	elif _test_mode == "aim":
		if balls.size() > 0:
			var b: OrbBall = balls[0]
			b.pick_up(0)
			pawns[0].held = b
	elif _test_mode == "aimprobe":
		_run_orb_probe()
	elif _test_mode == "threat":
		_run_threat_demo()
	elif _test_mode == "xray":
		_run_xray_demo()
	else:
		_flash_banner("ORBITAL DODGEBALL", Color(1.0, 0.85, 0.25), 2.2)
		_flash_event("BALLS NEVER DESPAWN. OLD ORBITS STILL KILL.", Color(0.85, 0.88, 1.0))

## ---- live-binding hint bar (real keys, not "A"/"B"; see docs/verify/realkeys-VERIFY.md) ----

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). The
## main bar personalizes only these.
func _human_seats() -> Array:
	var out := []
	for i in bot_enabled.size():
		if not bot_enabled[i] and PlayerInput.device_of(i) != -99:
			out.append(i)
	return out

## Seats whose bindings the hint bar prints: the live humans, or seat 0 as a
## representative when a bot-only demo has no humans — so the bar always shows
## a REAL key, never an abstract "A =" verb (doc 14 nit 3, notation consistency).
func _hint_seats() -> Array:
	var seats := _human_seats()
	return seats if not seats.is_empty() else [0]

## One button's live legend: "KEY = LABEL" when every hint seat shares the key
## (all pads -> "(A) = ..."), else the per-seat "LABEL: KEY/NAME · KEY/NAME" form
## (mixed keyboard + pad). Bindings are fixed per match, so this is built once when
## the match starts - no live polling.
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
	return "MOVE walk   ·   %s   ·   %s" % [
		_btn_hint("a", "THROW (hold) / CATCH (tap)"), _btn_hint("b", "JUMP the gap")]


## GHOST MEDDLING: while any wisp exists, append each locally-controlled dead
## seat's meddle legend (real keys via describe_binding) under the controls bar
## and re-reveal it; restore the plain bar when the last wisp respawns.
func _refresh_meddle_hints() -> void:
	if _hint_label == null:
		return
	if _meddle == null or _meddle.ghost_count() == 0:
		_hint_label.text = _controls_bar()
		return
	var lines := [_controls_bar()]
	for i in _human_seats():
		if _meddle.has_ghost(int(i)):
			lines.append(_meddle.hint_line(int(i), "RATTLE"))
	_hint_label.text = "\n".join(lines)
	_hint_label.visible = true


## GHOST MEDDLING (doc 24 §6): a dead human's ONE verb. A cold spectral pulse —
## RATTLE THE VOID. PRESENTATION-ONLY: it spawns a cosmetic burst and a soft rush
## and touches NO sim state and NO sim rng (_spawn_burst uses engine particle
## randomness, not the seeded sim rng), so in this all-balls-are-lethal arena it
## can never move a ball, credit a kill, or desync a mirror. Mischief, filed.
func _on_ghost_meddle(index: int, origin: Vector3, _aim: Vector3) -> void:
	_spawn_burst(origin, pawn_color(index), 16)
	Sfx.play("whoosh_small", -9.0)
	_meddle.attribute(index, "RATTLED THE VOID")
	print("ORB_MEDDLE seat=%d (spectral pulse; presentation-only, sim untouched)" % index)


## DEV/VERIFY ONLY (--orbmeddleshot, windowed): hide seat 0's body and force-raise
## its ghost-meddle wisp so the fixed-hover actor can be photographed. BYPASSES the
## human gate on purpose — never enabled in a receipt run, so all-bot receipts are
## untouched. Mirrors orbital's own --orbtest / probe capture precedent.
func _meddle_shot_tick() -> void:
	if _meddle_shot_done or now < 3.2:   # let the "ORBITAL DODGEBALL" intro banner clear
		return
	_meddle_shot_done = true
	var pw: OrbPawn = pawns[0]
	if pw._visual != null:
		pw._visual.visible = false
	_flash_banner("", Color.WHITE, 0.0)   # clear any lingering banner for a clean plate
	# a clear foreground spot (toward the camera, off the planet cluster) so the
	# fixed-hover wisp photographs large against the stars, not lost on a planet
	_meddle.add_ghost(0, str(pawn_name(0)), pawn_color(0), Vector3(-5.5, 3.4, 7.0), 1.4, false)
	_refresh_meddle_hints()
	print("ORB_MEDDLE_SHOT wisp raised for seat 0 (dev capture; not a receipt path)")
	_grab_meddle()


func _grab_meddle() -> void:
	await get_tree().create_timer(0.8).timeout   # let the wisp fade in + ring draw
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://verify_out/orbital_meddle_wisp.png"
		img.save_png(path)
		print("ORB_MEDDLE_CAP ", path)
	else:
		print("ORB_MEDDLE_SHOT_SKIP_HEADLESS")
	await get_tree().create_timer(0.3).timeout
	print("ORB_MEDDLE_SHOT_DONE")
	get_tree().quit()

## --- static world (camera, light, stars, planets, ui) ----------------------

func _build_static() -> void:
	_cam = Camera3D.new()
	_cam.position = CAM_POS
	_cam.fov = CAM_FOV
	_cam.current = true
	add_child(_cam)

	# GHOST MEDDLING (doc 24 §6 / B6): a dead HUMAN seat hovers fixed at its death
	# spot (drift=false — a floor-clamped drift would fight the screen-relative
	# planet controls) for its respawn window and may RATTLE THE VOID: a cold
	# spectral pulse. PRESENTATION-only (presentation_only=true) — in a game where
	# every ball is lethal, a meddle must never perturb the sim, so it touches no
	# ball, credits no kill, and each screen renders its own. Bots never raise one.
	_meddle = GhostMeddle.new()
	add_child(_meddle)
	_meddle.setup(self, _cam, GhostMeddle.DEFAULT_CD, true)
	_meddle.meddled.connect(_on_ghost_meddle)
	var light := DirectionalLight3D.new()
	add_child(light)
	light.look_at_from_position(Vector3(6, 8, 14), Vector3.ZERO, Vector3.UP)
	light.light_energy = 1.25
	light.shadow_enabled = true
	var wenv := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.50)
	env.ambient_light_energy = 0.55
	# THE HOUSE LOOK -- light touch (core/env_kit.gd rationale): orbital keeps its
	# bespoke starfield + planet-atmosphere space env, but adopts the house AGX
	# tonemap so bright ball trails, ghost orbits and atmosphere shells roll off to
	# COLOURED glow instead of clipping to a white smear (FILMIC's harsher
	# shoulder). A hair of exposure compensates AGX's gentler curve; glow nudged up
	# so the trails bloom a touch prouder. No preset swap -- the x-ray silhouettes
	# and threat-ladder reads must stay exactly as approved.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.06
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	wenv.environment = env
	add_child(wenv)
	_build_stars()
	for def in PLANET_DEFS:
		var d: Dictionary = def
		var r: float = d.radius
		planets.append({"center": d.center, "radius": r, "mu": float(d.gsurf) * r * r, "col": d.col})
		_build_planet_visual(d.center, r, d.col)
	_trail_root = Node3D.new()
	add_child(_trail_root)
	_ball_root = Node3D.new()
	add_child(_ball_root)
	_pawn_root = Node3D.new()
	add_child(_pawn_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_aim_im = ImmediateMesh.new()
	_aim_mesh = MeshInstance3D.new()
	_aim_mesh.mesh = _aim_im
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	am.vertex_color_use_as_albedo = true
	am.no_depth_test = true
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	_aim_mesh.material_override = am
	add_child(_aim_mesh)
	_build_ui()
	_build_threat_fx()

func _build_stars() -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = 314159  # decor only; constant across every match like an asset
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var orb := SphereMesh.new()  # unshaded sphere = crisp round star disc
	orb.radius = 0.16
	orb.height = 0.32
	orb.radial_segments = 10
	orb.rings = 5
	mm.mesh = orb
	mm.instance_count = 700
	for i in mm.instance_count:
		var dir := Vector3(srng.randf_range(-1, 1), srng.randf_range(-1, 1), srng.randf_range(-1, 1))
		if dir.length_squared() < 0.01:
			dir = Vector3.FORWARD
		var pos := dir.normalized() * srng.randf_range(48.0, 70.0)
		var s := srng.randf_range(0.4, 1.4)
		if srng.randf() < 0.05:
			s *= 2.4
		var xf := Transform3D(Basis().scaled(Vector3.ONE * s), pos)
		mm.set_instance_transform(i, xf)
		var warm := srng.randf()
		var c := Color(0.75 + 0.25 * warm, 0.78 + 0.16 * warm, 1.0 - 0.25 * warm)
		mm.set_instance_color(i, Color(c.r, c.g, c.b, srng.randf_range(0.2, 0.9)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	_star_mat = mat   # FINAL ORBIT tints the whole field via this multiplier
	add_child(mmi)

func _build_planet_visual(center: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 48
	sm.rings = 24
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = center
	add_child(mi)
	# fresnel atmosphere shell
	var shell := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = r * 1.055
	sm2.height = r * 2.11
	sm2.radial_segments = 48
	sm2.rings = 24
	shell.mesh = sm2
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec3 tint = vec3(0.5, 0.7, 1.0);
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint * f;
	ALPHA = clamp(f, 0.0, 1.0) * 0.8;
}
"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	var glowc := col.lightened(0.45)
	smat.set_shader_parameter("tint", Vector3(glowc.r, glowc.g, glowc.b))
	shell.material_override = smat
	shell.position = center
	add_child(shell)

func _basis_up(n: Vector3) -> Basis:
	var axis := Vector3.UP.cross(n)
	if axis.length() < 0.001:
		return Basis() if n.y > 0.0 else Basis(Vector3(1, 0, 0), PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(n))

func _add_pedestal(planet_i: int, n: Vector3) -> void:
	var pl: Dictionary = planets[planet_i]
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.24
	cm.bottom_radius = 0.32
	cm.height = 0.22
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.72, 0.78)
	mat.roughness = 0.5
	mi.material_override = mat
	add_child(mi)
	mi.global_transform = Transform3D(_basis_up(n), Vector3(pl.center) + n * (float(pl.radius) + 0.11))

## --- gravity field ----------------------------------------------------------

func gravity_at(pos: Vector3) -> Vector3:
	var g := Vector3.ZERO
	for pl in planets:
		var d: Vector3 = Vector3(pl.center) - pos
		var dist := maxf(d.length(), 0.4)
		g += d / dist * (float(pl.mu) / (dist * dist))
	var rlen := pos.length()
	if rlen > BOUNDARY_R:
		g += -pos / rlen * ((rlen - BOUNDARY_R) * 1.6)
	return g

func nearest_planet(pos: Vector3) -> int:
	var best := 0
	var best_d := 1e9
	for i in planets.size():
		var d: float = pos.distance_to(Vector3(planets[i].center)) - float(planets[i].radius)
		if d < best_d:
			best_d = d
			best = i
	return best

func cam_right() -> Vector3:
	return _cam.global_basis.x

func cam_up() -> Vector3:
	return _cam.global_basis.y

func cam_axis() -> Vector3:
	return _cam.global_basis.z

func cam_pos() -> Vector3:
	return _cam.global_position

## PROBLEM 2 (docs/design/16-jump-and-visibility.md): analytic ray-vs-sphere
## occlusion test from the fixed camera to a world point, used to gate the
## pawn/ball x-ray silhouettes. This game has no physics bodies at all
## ("Fully kinematic" - orb_pawn.gd header), so there is no collision layer
## to raycast against; this reuses the same hand-integrated-sphere approach
## gravity_at()/nearest_planet() already use. True if the camera->p segment
## crosses a planet's sphere strictly before reaching p (the margin excludes
## self-grazing where p sits right on the near hemisphere of its own planet).
func point_occluded(p: Vector3) -> bool:
	var cp := cam_pos()
	var to_p := p - cp
	var dist := to_p.length()
	if dist < 0.001:
		return false
	var dir := to_p / dist
	for pl in planets:
		var c: Vector3 = pl.center
		var r: float = pl.radius
		var oc := cp - c
		var b := oc.dot(dir)
		var cterm := oc.dot(oc) - r * r
		var disc := b * b - cterm
		if disc <= 0.0:
			continue
		var t := -b - sqrt(disc)
		if t > 0.2 and t < dist - 0.2:
			return true
	return false

func pawn_color(i: int) -> Color:
	return _colors[i]

func pawn_name(i: int) -> String:
	return _names[i]

## --- simulation loop --------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _mirror:
		_mirror_tick(delta)
		return
	if phase == Phase.WAIT:
		return
	# Slow-mo NEVER touches Engine.time_scale (the engine applies that at
	# frame granularity, which would make ticks machine-dependent). Instead
	# the sim's own step shrinks for a tick-counted budget: deterministic
	# in live play, headed captures and --fast sims alike.
	var sdt := delta
	if _slowmo_left > 0.0:
		_slowmo_left -= delta
		sdt = delta * 0.3
	now += sdt
	if phase == Phase.PLAY:
		for bot in bots:
			if bot != null:
				bot.think(sdt, now)
	var neutral := {"move": Vector2.ZERO, "a": false, "b": false}
	for p in pawns:
		var pw: OrbPawn = p
		var inp: Dictionary = _input_for(pw.index) if phase == Phase.PLAY else neutral
		pw.step(sdt, now, inp.move, inp.a, inp.b, inp.get("aim", Vector2.ZERO))
		if pw.held != null:
			pw.held.global_position = pw.body_center() + pw.up_dir() * 0.5 + pw.heading * 0.25
	for b in balls:
		var bb: OrbBall = b
		bb.step(sdt, now)
		if bb.state == OrbBall.S.FLYING and bb.owner_idx >= 0:
			var a := bb.age(now)
			if a > _max_flight_age:
				_max_flight_age = a
			if a > MAX_FLIGHT_AGE_ASSERT and not _age_fail:
				_age_fail = true
				print("ORBITAL_ASSERT FAIL flight age %.1fs > %.0fs" % [a, MAX_FLIGHT_AGE_ASSERT])
	if phase == Phase.PLAY:
		_resolve_pickups()
		_resolve_hits()
		_process_respawns()
		# GHOST MEDDLING: drive dead-human wisps (real delta — the dead are not slowed
		# by the living's hit slow-mo). Presentation-only, so it never touches the sim.
		_meddle.tick(delta)
		if _meddle_shot:
			_meddle_shot_tick()
		if _test_mode == "":
			if now >= _next_spawn and balls.size() < MAX_BALLS:
				_next_spawn += BALL_SPAWN_EVERY
				var pi := rng.randi_range(0, planets.size() - 1)
				_spawn_ball_at(pi, _random_visible_n(), false)
				Sfx.play("confirm")
				_flash_event("A NEW BALL DRIFTS IN", Color(0.85, 0.88, 1.0))
			if _stretch != null and not _stretch.escalated and time_left <= 30.0:
				_final_orbit()   # FINAL STRETCH (§4.3): T-30 crescendo
			time_left -= sdt
			if time_left <= 0.0:
				_end_match()
		elif _test_mode == "circ":
			_circ_track()

func _input_for(p: int) -> Dictionary:
	if _test_mode == "circ":
		return {"move": Vector2(1, 0) if p == 0 else Vector2.ZERO, "a": false, "b": false}
	if _test_mode == "aim":
		return {"move": Vector2.ZERO, "a": p == 0, "b": false}
	if _test_mode == "aimprobe":
		# hold A on pawn 0 (charge + aim); the synthetic cursor is fed once the
		# probe driver arms it (device -4 + set_debug_aim_screen), so the first
		# capture shows the fixed heading and the second shows the aimed one.
		return {"move": Vector2.ZERO, "a": p == 0 and not _orb_probe_release, "b": false,
			"aim": PlayerInput.get_aim_screen(p, pawns[p].body_center(), _cam) if (p == 0 and _orb_probe_armed) else Vector2.ZERO}
	if p < bots.size() and bots[p] != null:
		var bot: OrbBot = bots[p]
		return {"move": bot.move, "a": bot.a, "b": bot.b}
	return {
		"move": PlayerInput.get_move(p),
		"a": PlayerInput.is_down(p, "a"),
		"b": PlayerInput.is_down(p, "b"),
		"aim": PlayerInput.get_aim_screen(p, pawns[p].body_center(), _cam),
	}

func _resolve_pickups() -> void:
	for b in balls:
		var bb: OrbBall = b
		if bb.state != OrbBall.S.REST:
			continue
		for p in pawns:
			var pw: OrbPawn = p
			if pw.alive and not pw.airborne and pw.held == null \
					and bb.global_position.distance_to(pw.global_position) < 0.8:
				bb.pick_up(pw.index)
				pw.held = bb
				pw._play_once("PickUp")
				Sfx.play("card", -6.0)
				break

func _resolve_hits() -> void:
	for b in balls:
		var bb: OrbBall = b
		if not bb.deadly():
			continue
		for p in pawns:
			var pw: OrbPawn = p
			if not pw.alive or pw.invuln > 0.0:
				continue
			if bb.owner_idx == pw.index and bb.age(now) < 0.8:
				continue  # grace: your throw cannot clip you point-blank
			var d := bb.global_position.distance_to(pw.body_center())
			if d < OrbPawn.CATCH_RADIUS and pw.catch_timer > 0.0 and pw.held == null:
				_do_catch(pw, bb)
				break
			elif d < OrbBall.RADIUS + OrbPawn.BODY_R:
				_do_kill(pw, bb)
				break

func _do_catch(pw: OrbPawn, bb: OrbBall) -> void:
	var stolen := bb.owner_idx >= 0 and bb.owner_idx != pw.index
	var b_age := bb.age(now)
	bb.pick_up(pw.index)
	pw.held = bb
	pw.invuln = maxf(pw.invuln, 0.5)
	pw.catch_timer = 0.0
	pw._play_once("PickUp")
	catches[pw.index] += 1
	if stolen:
		_points[pw.index] += CATCH_POINTS
		_update_score_rows()
	Sfx.play("bumper")
	_shake = maxf(_shake, 0.18)
	_spawn_burst(pw.body_center(), Color(1, 1, 1), 16)
	var extra := " — A %d-SECOND ORBIT!" % int(b_age) if b_age > GHOST_AGE else ""
	_flash_event("NICE CATCH — %s%s" % [pawn_name(pw.index), extra], pawn_color(pw.index))
	if b_age > _best_catch_age:
		_best_catch_age = b_age
		_best_catch_txt = "%s plucked a %d-second orbit out of the sky" % [pawn_name(pw.index), int(b_age)]
	if NetSession.has_guests() and not _mir_snaps.has("orb_host_catch"):
		_mir_snaps["orb_host_catch"] = true
		VerifyCapture.snap("orb_host_catch")
	print("CATCH t=%.1f p=%d ball_age=%.1f stolen=%s" % [now, pw.index, b_age, stolen])

func _do_kill(pw: OrbPawn, bb: OrbBall) -> void:
	var victim := pw.index
	var killer := bb.owner_idx
	var ball_age := bb.age(now)
	# structured kill attribution (module contract): killer = last thrower
	# (-1 = environment/never-thrown ball; == victim = self-orbit), victim = pawn.
	_kill_events.append({"killer": killer, "victim": victim, "cause": "orbit_hit"})
	# wire fact (memory-only): the mirror fires burst/impact/sfx off this row
	_net_kill = [int(_net_kill[0]) + 1, victim, killer, snappedf(bb.vel.length(), 0.1)]
	deaths[victim] += 1
	_currency.append({"type": "grudge", "player": victim, "amount": 1, "reason": "orbital dodgeball to the face"})
	if pw.held != null:
		var loose := pw.held
		pw.held = null
		loose.drop_loose(pw.srf_n * 2.0 + bb.vel.normalized(), now)
	var spin := bb.vel.cross(pw.srf_n)
	pw.die(bb.vel, spin)
	_respawn_queue.append({"t": now + RESPAWN_DELAY, "player": victim})
	# GHOST MEDDLING: raise a fixed-hover wisp for a dead HUMAN seat at the death
	# spot (never a bot — that keeps every all-bot receipt byte-identical).
	if not bool(bot_enabled[victim]):
		_meddle.add_ghost(victim, str(pawn_name(victim)), pawn_color(victim), pw.body_center(), 1.4, false)
		_refresh_meddle_hints()
	Sfx.play("splat")
	Sfx.play("death")
	_kill_impact(bb.vel.length())  # speed-scaled VISUAL punch; sim slow-mo unchanged
	PlayerInput.rumble_hit(victim, 0.7)   # RUMBLE: the orbited pawn (haptic only; camera basis untouched)
	_spawn_burst(pw.body_center(), pawn_color(victim), 30)
	if killer == victim:
		_flash_banner("%s ORBITED THEMSELF" % pawn_name(victim), pawn_color(victim), 2.2)
	elif killer >= 0:
		kills[killer] += 1
		_points[killer] += KILL_POINTS
		PlayerInput.rumble_hit(killer, 0.35)   # RUMBLE: the thrower feels the hit connect

		if ball_age > GHOST_AGE:
			_currency.append({"type": "royalty", "player": killer, "amount": 1,
				"reason": "ghost orbit kill (%ds old)" % int(ball_age)})
			_flash_banner("%s'S GHOST ORBIT STRIKES!\n%d-SECOND-OLD THROW TAKES OUT %s"
				% [pawn_name(killer), int(ball_age), pawn_name(victim)], pawn_color(killer), 2.8)
			if ball_age > float(_ghost_monument.get(killer, 0.0)):
				_ghost_monument[killer] = ball_age
		else:
			_flash_banner("%s SMACKS %s!" % [pawn_name(killer), pawn_name(victim)], pawn_color(killer), 2.0)
		if ball_age > _oldest_kill_age:
			_oldest_kill_age = ball_age
			_oldest_kill_txt = "%s's %d-second orbit found %s" % [pawn_name(killer), int(ball_age), pawn_name(victim)]
		_update_score_rows()
	print("KILL t=%.1f killer=%d victim=%d ball_age=%.1f" % [now, killer, victim, ball_age])
	_slow_mo()

func _process_respawns() -> void:
	var keep: Array = []
	for item in _respawn_queue:
		if now >= float(item.t):
			var pi := _least_crowded_planet()
			var n := _respawn_spot(pi)
			pawns[int(item.player)].respawn(pi, n)
			# GHOST MEDDLING: the seat lives again — retire its wisp.
			_meddle.remove_ghost(int(item.player))
			_refresh_meddle_hints()
			Sfx.play("confirm", -4.0)
			_spawn_burst(pawns[int(item.player)].body_center(), pawn_color(int(item.player)), 12)
		else:
			keep.append(item)
	_respawn_queue = keep

func _least_crowded_planet() -> int:
	var counts := [0, 0, 0]
	for p in pawns:
		var pw: OrbPawn = p
		if pw.alive and not pw.airborne:
			counts[pw.planet] += 1
	var best := 0
	for i in range(1, planets.size()):
		if counts[i] < counts[best]:
			best = i
	return best

func _respawn_spot(planet_i: int) -> Vector3:
	var best_n := _random_visible_n()
	var best_d := -1.0
	for _try in 5:
		var n := _random_visible_n()
		var pos: Vector3 = Vector3(planets[planet_i].center) + n * float(planets[planet_i].radius)
		var nearest := 99.0
		for b in balls:
			var bb: OrbBall = b
			if bb.deadly():
				nearest = minf(nearest, bb.global_position.distance_to(pos))
		if nearest > best_d:
			best_d = nearest
			best_n = n
	return best_n

func _random_visible_n() -> Vector3:
	var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(0.25, 1.0))
	return v.normalized()

func _spawn_ball_at(planet_i: int, n: Vector3, with_pedestal: bool) -> OrbBall:
	var b := OrbBall.new()
	b.world = self
	_ball_root.add_child(b)
	var pl: Dictionary = planets[planet_i]
	var lift := 0.22 if with_pedestal else 0.0
	b.global_position = Vector3(pl.center) + n * (float(pl.radius) + lift + OrbBall.RADIUS)
	b.state = OrbBall.S.REST
	b.rest_planet = planet_i
	var t := OrbTrail.new()
	_trail_root.add_child(t)
	b.trail = t
	b.refresh_color()
	balls.append(b)
	if with_pedestal:
		_add_pedestal(planet_i, n)
	return b

## --- event hooks from balls / pawns ----------------------------------------

func on_throw(pw: OrbPawn, bb: OrbBall) -> void:
	_throws += 1
	Sfx.play("putt")
	print("THROW t=%.1f p=%d speed=%.1f" % [now, pw.index, bb.vel.length()])

func on_jump(_pw: OrbPawn) -> void:
	Sfx.play("place", -6.0)

func on_land(pw: OrbPawn, prev_planet: int) -> void:
	if prev_planet != pw.planet:
		_hops += 1
		print("HOP t=%.1f p=%d %d->%d" % [now, pw.index, prev_planet, pw.planet])

func on_ball_bounce(_bb: OrbBall, impact: float) -> void:
	_net_bounce += 1   # wire fact; pure counter, sim never reads it
	_net_bounce_imp = snappedf(impact, 0.1)
	Sfx.play("bounce", clampf(-14.0 + impact * 1.4, -14.0, -3.0))

func on_ball_rest(bb: OrbBall) -> void:
	print("BALL_REST t=%.1f owner=%d flight=%.1fs" % [now, bb.owner_idx, bb.age(now)])

## --- match end ---------------------------------------------------------------

## FINAL ORBIT (doc 09 §4.3, via the §Q1 kit): T-30 banner + Executor line +
## tense track + the starfield leaning 20% toward red. Presentation only.
func _final_orbit() -> void:
	_net_fo = 1   # wire fact: the mirror's kit escalates + tints off this flip
	_stretch.escalate()
	# THE DECIDING MOMENT (doc 09 §Q2): FINAL ORBIT is orbital's sudden-death spike.
	# The shared fov punch owns the lens for its window; the per-frame _impact_amp fov
	# driver stands aside via _decide_fov_ms so the punch actually reads. fov never
	# enters the sim's control frame, so this stays byte-identical (unlike a roll).
	if _motion_ok():
		_decide_fov_ms = Time.get_ticks_msec() + 900
	FinalStretch.fov_punch(_cam, CAM_FOV, 6.0, 0.9, "FINAL ORBIT")
	_flash_banner("FINAL ORBIT", Color(1.0, 0.45, 0.3), 2.4)
	_flash_event("THE ESTATE CALLS TIME. OLD ORBITS STILL KILL.", Color(1.0, 0.75, 0.65))
	if _star_mat != null:
		var tw := create_tween()
		tw.tween_property(_star_mat, "albedo_color",
			Color.WHITE.lerp(Color(1.0, 0.25, 0.18), 0.2), 2.0)
	if NetSession.has_guests() and not _mir_snaps.has("orb_host_finalorbit"):
		_mir_snaps["orb_host_finalorbit"] = true
		VerifyCapture.snap("orb_host_finalorbit")

func _end_match() -> void:
	phase = Phase.END
	if _stretch != null:
		_stretch.match_ended()
	# GHOST MEDDLING: the match is over — retire any lingering wisps.
	if _meddle != null:
		_meddle.clear()
		_refresh_meddle_hints()
	var order: Array = _points.keys()
	order.sort_custom(func(a, b):
		if _points[a] != _points[b]:
			return int(_points[a]) > int(_points[b])
		return int(a) < int(b))
	var winner: int = order[0]
	_net_champ = winner   # wire fact: mirror confetti keys off this + phase END
	if not pawns[winner].alive:
		pawns[winner].respawn(_least_crowded_planet(), _random_visible_n())
	pawns[winner]._play_once("Cheer")
	Sfx.play("match_win")
	_spawn_burst(pawns[winner].body_center(), pawn_color(winner), 40)
	_flash_banner("%s HOLDS THE VOID" % pawn_name(winner), pawn_color(winner), 9999.0)
	var highlights: Array = []
	if _oldest_kill_txt != "":
		highlights.append(_oldest_kill_txt)
	if _best_catch_age > GHOST_AGE:
		highlights.append(_best_catch_txt)
	var most_deaths := -1
	var eater := -1
	for i in deaths:
		if int(deaths[i]) > most_deaths:
			most_deaths = int(deaths[i])
			eater = int(i)
	if eater >= 0 and most_deaths >= 2:
		highlights.append("%s ate %d dodgeballs" % [pawn_name(eater), most_deaths])
	var monuments: Array = []
	for i in _ghost_monument:
		monuments.append({"player": int(i), "kind": "ghost_orbit",
			"label": "%s, Keeper of the %d-Second Orbit" % [pawn_name(int(i)), int(float(_ghost_monument[i]))]})
	var results := {
		"placements": order,
		"points": _points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": highlights.slice(0, 3),
		"monuments": monuments,
		"kill_events": _kill_events.duplicate(),
	}
	# ONLINE: the estate's 20 Hz pump stops the same tick finished() fires, so
	# facts minted here would never reach mirrors (masked-ball lesson). Hold the
	# report one real beat — END phase, winner banner and champ fact hit the
	# wire first. Prints below stay inline; results are already duplicated, so
	# the receipt blocks are byte-identical either way.
	get_tree().create_timer(0.45).timeout.connect(report_finished.bind(results))
	print("ORBITAL_RESULTS ", JSON.stringify(results))
	print("KILL_EVENTS n=", _kill_events.size(), " ", JSON.stringify(_kill_events))
	var verdict := "PASS" if (not _age_fail and _max_flight_age < MAX_FLIGHT_AGE_ASSERT) else "FAIL"
	print("ORBITAL_SIM throws=%d hops=%d kills=%s catches=%s deaths=%s" % [_throws, _hops, str(kills), str(catches), str(deaths)])
	print("ORBITAL_ASSERT max_flight_age=%.1fs (<%.0fs): %s" % [_max_flight_age, MAX_FLIGHT_AGE_ASSERT, verdict])
	if _autoquit:
		get_tree().create_timer(2.0, true, false, true).timeout.connect(func() -> void: get_tree().quit())

func _slow_mo() -> void:
	if _test_mode != "":
		return
	_slowmo_left = 0.4  # 24 ticks at 0.3x step = a 0.4s real-time beat

## --- circumnavigation evidence mode (--orbtest=circ) ------------------------

func _circ_start() -> void:
	_circ = {"planet": 0, "prev_h": Vector3.ZERO, "prev_n": Vector3.ZERO,
		"angle": 0.0, "min_dot": 1.0, "flips": 0, "tick": 0}
	pawns[0].place_on(0, Vector3(0, 0, 1))
	print("CIRC_START constant screen-input (1,0); heading continuity logged")

func _circ_track() -> void:
	var pw: OrbPawn = pawns[0]
	if _circ.prev_h != Vector3.ZERO and pw.walking:
		var d: float = Vector3(_circ.prev_h).dot(pw.heading)
		_circ.min_dot = minf(float(_circ.min_dot), d)
		if d < 0.5:
			_circ.flips = int(_circ.flips) + 1
	_circ.prev_h = pw.heading
	if _circ.prev_n != Vector3.ZERO:
		_circ.angle = float(_circ.angle) + Vector3(_circ.prev_n).angle_to(pw.srf_n)
	_circ.prev_n = pw.srf_n
	_circ.tick = int(_circ.tick) + 1
	if int(_circ.tick) % 120 == 0:
		print("CIRC planet=%d deg=%.0f min_heading_dot=%.4f" % [int(_circ.planet), rad_to_deg(float(_circ.angle)), float(_circ.min_dot)])
	if float(_circ.angle) >= TAU:
		print("CIRC_OK planet=%d full_circle min_heading_dot=%.4f flips=%d" % [int(_circ.planet), float(_circ.min_dot), int(_circ.flips)])
		_circ.planet = int(_circ.planet) + 1
		if int(_circ.planet) >= planets.size():
			print("CIRC_DONE all 3 planets circumnavigated, zero control flips" if int(_circ.flips) == 0 else "CIRC_DONE with flips=%d" % int(_circ.flips))
			_test_mode = ""
			if _autoquit:
				get_tree().quit()
			return
		pawns[0].place_on(int(_circ.planet), Vector3(0, 0, 1))
		_circ.prev_h = Vector3.ZERO
		_circ.prev_n = Vector3.ZERO
		_circ.angle = 0.0
		_circ.min_dot = 1.0

## --- presentation (visual frame) ---------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.WAIT:
		return
	for b in balls:
		var bb: OrbBall = b
		if bb.trail != null:
			bb.trail.render(now, _cam.global_position)
	_draw_aim_previews()
	if _orb_probe_line != null:
		_update_probe_line()
	_update_timer_label()
	if _stretch != null and phase == Phase.PLAY:
		_stretch.tick(time_left)   # FINAL STRETCH last-10s ladder + timer pulse
	if _hint_label.visible and now > 7.0:
		_hint_label.visible = false
	if _event_label.visible and now > _event_until:
		_event_label.visible = false
	var motion_ok := _motion_ok()
	# Camera shake now respects the reduced-motion pref (was unconditional).
	if _shake > 0.002:
		if motion_ok:
			_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
			_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		else:
			_cam.h_offset = 0.0
			_cam.v_offset = 0.0
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-5.0 * delta))
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	# Speed-scaled kill freeze (visual): a brief FOV punch-in that decays at a
	# heat-scaled rate. Motion-gated; the sim's slow-mo beat is untouched.
	if _impact_amp > 0.001:
		_impact_amp = lerpf(_impact_amp, 0.0, 1.0 - exp(-_impact_decay * delta))
		if Time.get_ticks_msec() >= _decide_fov_ms:   # yield to a FINAL ORBIT punch
			_cam.fov = CAM_FOV - (_impact_amp * 3.5 if motion_ok else 0.0)
	else:
		_impact_amp = 0.0
		if Time.get_ticks_msec() >= _decide_fov_ms:   # yield to a FINAL ORBIT punch
			_cam.fov = CAM_FOV
	_update_threat_audio(delta)
	_update_vignette(delta)
	# probe-night evidence latch (has_guests only, once): a top-heat ball
	# screaming near a living body — the pair for the mirror's identical frame
	if not _mirror and NetSession.has_guests() and not _mir_snaps.has("orb_host_heat"):
		if _heat_moment():
			_mir_snaps["orb_host_heat"] = true
			VerifyCapture.snap("orb_host_heat")

func _draw_aim_previews() -> void:
	_aim_im.clear_surfaces()
	for p in pawns:
		var pw: OrbPawn = p
		if not pw.alive or pw.held == null or pw.charge < 0.0:
			continue
		var tv: Dictionary = pw.throw_vector()
		var pos: Vector3 = tv.origin
		var vel: Vector3 = tv.vel
		var col := pawn_color(pw.index)
		_aim_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var dt := 0.06
		var hit := false
		for i in 25:  # first 1.5s of the predicted path only (spec)
			vel += gravity_at(pos) * dt
			vel *= (1.0 - OrbBall.DRAG_BASE * dt)
			if vel.length() > OrbBall.SPEED_CAP:
				vel = vel.normalized() * OrbBall.SPEED_CAP
			pos += vel * dt
			for pl in planets:
				if pos.distance_to(Vector3(pl.center)) < float(pl.radius) + OrbBall.RADIUS:
					hit = true
			var fade := 1.0 - float(i) / 25.0
			var s := 0.06 + 0.05 * pw.charge
			if hit:
				s *= 2.0  # impact blip, then stop
			_aim_dot(pos, s, Color(col.r, col.g, col.b, 0.5 + 0.45 * fade))
			if hit:
				break
		_aim_im.surface_end()

func _aim_dot(p: Vector3, s: float, c: Color) -> void:
	# camera-facing diamond (reads as a deliberate dotted line, not a pixel)
	var r := cam_right() * s
	var u := cam_up() * s
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p - r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p + u)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p + r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p - r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p + r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p - u)

func _spawn_burst(pos: Vector3, color: Color, amount: int) -> void:
	var part := CPUParticles3D.new()
	_fx_root.add_child(part)
	part.global_position = pos
	part.one_shot = true
	part.amount = amount
	part.lifetime = 0.8
	part.explosiveness = 1.0
	part.direction = Vector3.UP
	part.spread = 180.0
	part.initial_velocity_min = 2.0
	part.initial_velocity_max = 5.0
	part.gravity = Vector3.ZERO
	part.damping_min = 1.5
	part.damping_max = 3.0
	part.scale_amount_min = 0.5
	part.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	part.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.8
	part.material_override = mat
	part.emitting = true
	get_tree().create_timer(1.6).timeout.connect(part.queue_free)

## --- THREAT LADDER presentation ---------------------------------------------

## Reduced-motion gate (the HIT KIT pattern): games read PartySetup's
## screen_shake toggle. When off, camera shake / kill punch / vignette pulse
## are suppressed or heavily softened. Audio + ball heat are not motion, so
## they stay on. Reads live so an ESC-menu toggle takes effect immediately.
func _motion_ok() -> bool:
	var ps := get_node_or_null(^"/root/PartySetup")
	if ps == null:
		return true
	return bool(ps.pref("screen_shake", true))

func _build_threat_fx() -> void:
	# Danger vignette: a full-screen radial edge tint that ramps up as a
	# top-tier ball screams past a living player. Own CanvasLayer under the HUD
	# text so scores/banners stay crisp on top.
	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 0
	add_child(vig_layer)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsh := Shader.new()
	vsh.code = """
shader_type canvas_item;
render_mode blend_mix;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.95, 0.12, 0.12, 1.0);
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 1.42;                 // 0 centre -> ~1 corner
	float v = smoothstep(0.34, 0.98, d);         // soft edge mask
	COLOR = vec4(tint.rgb, v * strength);
}
"""
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = vsh
	_vig_mat.set_shader_parameter("strength", 0.0)
	_vignette.material = _vig_mat
	vig_layer.add_child(_vignette)
	# Threat-tone voices: reuse a soft bank asset (the plate tap the Sfx bank
	# already ships) and PITCH-SCALE it per speed tier — a spaced low hum that
	# tightens into a high whistle as the ball climbs the ladder.
	var tone: AudioStream = load("res://assets/audio/impactPlate_light_000.ogg")
	for i in 6:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		pl.stream = tone
		add_child(pl)
		_threat_pool.append(pl)

## Speed-scaled kill freeze (presentation): the sim's own slow-mo beat is left
## byte-identical; this layers the VISUAL punch on top. Faster ball => DEEPER
## (bigger amplitude) and SHORTER (quicker decay) — a snappier, more violent
## hit — while a slow lob gives a softer, longer-lingering thud. Motion-gated.
func _kill_impact(speed: float) -> void:
	var t := clampf((speed - OrbBall.DEADLY_SPEED) / (OrbBall.SPEED_CAP - OrbBall.DEADLY_SPEED - 1.0), 0.0, 1.0)
	_impact_amp = lerpf(0.4, 1.0, t)      # deeper for faster
	_impact_decay = lerpf(6.0, 15.0, t)   # shorter (faster decay) for faster
	_shake = maxf(_shake, lerpf(0.34, 0.82, t))

## Per-frame threat audio: for every deadly ball near a living player, advance
## a cadence accumulator and fire a pitched tone when it rolls over. Cadence
## and pitch both scale with heat (hum -> whistle); volume with heat AND
## proximity. Presentation only: runs in _process, no sim rng, no sim writes.
func _update_threat_audio(delta: float) -> void:
	if _threat_pool.is_empty():
		return
	for b in balls:
		var bb: OrbBall = b
		if not bb.deadly():
			bb._threat_phase = 0.0
			continue
		var hf := bb.heat_factor()
		var nd := 1.0e9
		for p in pawns:
			var pw: OrbPawn = p
			if pw.alive:
				nd = minf(nd, bb.global_position.distance_to(pw.body_center()))
		var prox := clampf(inverse_lerp(9.0, 2.0, nd), 0.0, 1.0)
		var loud := prox * lerpf(0.15, 1.0, hf)
		if bb.vel.length() < 5.0 or loud < 0.06:
			bb._threat_phase = 0.0
			continue
		var period := lerpf(0.26, 0.07, hf)  # low hum spacing -> whistle flutter
		bb._threat_phase += delta
		if bb._threat_phase >= period:
			bb._threat_phase -= period
			_emit_threat(hf, loud)

func _emit_threat(hf: float, loud: float) -> void:
	var pl: AudioStreamPlayer = _threat_pool[_threat_next]
	_threat_next = (_threat_next + 1) % _threat_pool.size()
	pl.pitch_scale = lerpf(0.85, 2.15, hf) * (1.0 + randf_range(-0.03, 0.03))
	pl.volume_db = linear_to_db(clampf(loud, 0.02, 1.0)) - 7.0  # subtle bed
	pl.play()

## Danger vignette + kill flash: strength = the strongest (proximity x heat)
## of any top-tier deadly ball hovering near a living player, plus the decaying
## kill punch. Smoothed, capped subtle, and softened under reduced motion.
func _update_vignette(delta: float) -> void:
	if _vig_mat == null:
		return
	var vig := 0.0
	for b in balls:
		var bb: OrbBall = b
		if not bb.deadly():
			continue
		var hf := bb.heat_factor()
		if hf < 0.45:  # only the upper tiers raise the alarm
			continue
		for p in pawns:
			var pw: OrbPawn = p
			if not pw.alive:
				continue
			var d := bb.global_position.distance_to(pw.body_center())
			var prox := clampf(inverse_lerp(4.0, 1.0, d), 0.0, 1.0)
			vig = maxf(vig, prox * hf)
	vig = maxf(vig, _impact_amp * 0.6)
	_vig_strength = lerpf(_vig_strength, vig, 1.0 - exp(-10.0 * delta))
	var motion := 1.0 if _motion_ok() else 0.45
	_vig_mat.set_shader_parameter("strength", clampf(_vig_strength * 0.5 * motion, 0.0, 0.5))

## --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	var baloo: Font = load("res://assets/fonts/Baloo2.ttf")
	var ui := CanvasLayer.new()
	add_child(ui)
	_timer_label = _mk_label(lg, 40, 10)
	_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_timer_label.offset_top = 8
	ui.add_child(_timer_label)
	_event_label = _mk_label(baloo, 24, 7)
	_event_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_event_label.offset_top = 62
	_event_label.visible = false
	ui.add_child(_event_label)
	_banner = _mk_label(lg, 46, 12)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.visible = false
	ui.add_child(_banner)
	_score_rows = VBoxContainer.new()
	_score_rows.position = Vector2(16, 12)
	ui.add_child(_score_rows)
	_hint_label = _mk_label(baloo, 19, 6)
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.offset_bottom = -10
	_hint_label.text = "MOVE walk the planet   ·   A hold = aim, release = THROW   ·   A tap = CATCH   ·   B = JUMP the gap"
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	ui.add_child(_hint_label)

func _mk_label(font: Font, size: int, outline: int) -> Label:
	var l := Label.new()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.09))
	l.add_theme_constant_override("outline_size", outline)
	return l

func _update_score_rows() -> void:
	if _row_labels.is_empty():
		var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
		for i in _points:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			var badge := PlayerBadge.make(int(i), 26)
			badge.color = pawn_color(int(i))
			hb.add_child(badge)
			var l := _mk_label(lg, 26, 7)
			hb.add_child(l)
			_score_rows.add_child(hb)
			_row_labels.append({"label": l, "player": int(i)})
	for row in _row_labels:
		var i: int = row.player
		var l: Label = row.label
		l.text = "%s  %d" % [pawn_name(i), int(_points[i])]
		l.add_theme_color_override("font_color", pawn_color(i))

func _update_timer_label() -> void:
	if phase == Phase.END:
		_timer_label.text = "0:00"
		return
	var t := maxi(0, int(ceilf(time_left)))
	_timer_label.text = "%d:%02d" % [t / 60, t % 60]
	_timer_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.35) if time_left < 15.0 else Color.WHITE)

func _flash_banner(text: String, color: Color, duration: float) -> void:
	_banner_gen += 1
	var gen := _banner_gen
	_banner_col = color.to_html(false)
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.55, 0.55)
	var pop := create_tween()
	pop.tween_property(_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		# only hide if no newer banner replaced this one (e.g. the winner
		# banner must survive a kill banner's stale hide timer)
		tw.tween_callback(func() -> void:
			if _banner_gen == gen:
				_banner.visible = false)

func _flash_event(text: String, color: Color) -> void:
	if not _mirror:   # mirror replays flashes from the wire; gens are host facts
		_event_col = color.to_html(false)
		_event_gen += 1
	_event_label.text = text
	_event_label.add_theme_color_override("font_color", color)
	_event_label.visible = true
	_event_until = now + 2.2

## --- mouse-aim verification (--aimprobe=<deg>) -------------------------------
## Pawn 0 (a KBM human) holds a ball with a FIXED screen-right heading. Shot 1
## captures that baseline. Then a synthetic cursor at <deg> (screen space,
## 0=right, 90=up) is armed; the throw heading — and the dotted preview that
## reads off it — chase the cursor into this planet's screen-relative frame.
## Shot 2 captures the aimed preview. A cyan on-screen ray marks the cursor.
func _run_orb_probe() -> void:
	var pw: OrbPawn = pawns[0]
	pw.place_on(0, Vector3(0, 0, 1))          # near point, facing camera
	pw.frame_r = _cam.global_basis.x          # screen right
	pw.heading = pw.frame_r
	if balls.size() > 0:
		var b: OrbBall = balls[0]
		b.pick_up(0)
		pw.held = b
	var ov := CanvasLayer.new()
	add_child(ov)
	_orb_probe_line = Line2D.new()
	_orb_probe_line.width = 5.0
	_orb_probe_line.default_color = Color(0.2, 0.95, 1.0)
	ov.add_child(_orb_probe_line)
	await get_tree().create_timer(0.7).timeout
	await _orb_probe_grab("facing")
	print("ORB_AIMPROBE heading_before=(%.2f,%.2f,%.2f)" % [pw.heading.x, pw.heading.y, pw.heading.z])
	var rad := deg_to_rad(_aim_probe_deg)
	PlayerInput.assign(0, -4)
	PlayerInput.set_debug_aim_screen(0, Vector2(cos(rad), sin(rad)))
	_orb_probe_armed = true
	print("ORB_AIMPROBE armed cursor deg=%.0f (screen x=right y=up)" % _aim_probe_deg)
	await get_tree().create_timer(1.0).timeout
	await _orb_probe_grab("acting")
	print("ORB_AIMPROBE heading_after=(%.2f,%.2f,%.2f)" % [pw.heading.x, pw.heading.y, pw.heading.z])
	_orb_probe_release = true                  # release A -> throw toward cursor
	await get_tree().create_timer(0.5).timeout
	print("ORB_AIMPROBE_DONE thrown; ball vel=%s" % (str(balls[0].vel) if balls.size() > 0 else "n/a"))
	get_tree().quit()


func _update_probe_line() -> void:
	var pw: OrbPawn = pawns[0]
	var anchor := _cam.unproject_position(pw.body_center())
	var rad := deg_to_rad(_aim_probe_deg)
	var scr := Vector2(cos(rad), -sin(rad))    # screen y is down, so up = -sin
	_orb_probe_line.points = PackedVector2Array([anchor, anchor + scr * 240.0])


func _orb_probe_grab(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("ORB_AIMPROBE_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://verify_out/orbital_aim_%s.png" % tag
	img.save_png(path)
	print("ORB_AIMPROBE_CAP ", path)


## --- threat-ladder verification (--orbtest=threat) --------------------------
## Stages a deterministic top-tier moment: pawn 0 stands still on the small
## planet, a ~12 m/s (top speed tier) ball is launched screaming across the
## front of it at a ~1-unit near miss. Captures a bracket of PNGs around
## closest approach so a human can read the heated ball + danger vignette.
## Isolated test path — never runs during a real match, so KILL_EVENTS unaffected.
func _run_threat_demo() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	_hint_label.visible = false
	var pw: OrbPawn = pawns[0]
	pw.place_on(2, Vector3(0.0, 0.0, 1.0))     # near point of the small planet
	pw.invuln = 0.0
	var start := Vector3(-4.2, 3.3, 3.9)
	var vel := Vector3(12.0, 0.0, -0.6)         # top speed tier, slight in-arc
	var b: OrbBall = balls[0] if balls.size() > 0 else _spawn_ball_at(2, Vector3(0, 0, 1), false)
	b.launch(start, vel, 1, now)                # owner = P1 (identity hue under the heat)
	print("THREAT_DEMO launched speed=%.1f hf~=%.2f" % [vel.length(), b.heat_factor()])
	for grab in [{"t": 0.34, "tag": "a"}, {"t": 0.05, "tag": "b"}, {"t": 0.05, "tag": "c"}, {"t": 0.05, "tag": "d"}]:
		await get_tree().create_timer(float(grab.t)).timeout
		var nd := 1.0e9
		for p in pawns:
			var pp: OrbPawn = p
			if pp.alive:
				nd = minf(nd, b.global_position.distance_to(pp.body_center()))
		print("THREAT_STATE tag=%s speed=%.2f hf=%.2f nearest_pawn=%.2f vig=%.2f alive0=%s"
			% [grab.tag, b.vel.length(), b.heat_factor(), nd, _vig_strength, str(pawns[0].alive)])
		await _threat_grab(String(grab.tag))
	print("THREAT_DEMO_DONE")
	if _autoquit:
		get_tree().quit()

func _threat_grab(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("THREAT_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://verify_out/orbital_threat_%s.png" % tag
	img.save_png(path)
	print("THREAT_CAP ", path)


## --- occluded-player/ball visibility verification (--orbtest=xray) ----------
## Stages a deterministic tableau for PROBLEM 2 (docs/design/
## 16-jump-and-visibility.md). Dead-center near/far points along the SAME
## camera axis project to the SAME screen position (one just closer than the
## other) - so occluded and visible pawns on one planet are staged at
## DIFFERENT clock positions (rotated off the camera axis around a tangent),
## not diametrically opposite, or they'd stack on screen and the screenshot
## couldn't tell them apart:
##   planet 0: pawn 0 dead-center far side (OCCLUDED, silhouette read) +
##             pawn 1 near side offset 65 deg off-front (VISIBLE, offset so
##             it doesn't stack on pawn 0 - checks no-double-draw-tint AND
##             that an occluded/visible pair reads correctly side by side)
##   planet 1: pawn 2 dead-center far side (OCCLUDED, second color) + a ball
##             offset 25 deg off pawn 2's line (also OCCLUDED - ball x-ray dot)
##   planet 2: pawn 3 dead-center near side, alone on its planet (VISIBLE,
##             isolated no-double-draw check)
## Isolated test path - never runs during a real match.
func _run_xray_demo() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out/orbital_sil"))
	_hint_label.visible = false
	for p in pawns:
		(p as OrbPawn).invuln = 0.0
	var u0 := (Vector3(planets[0].center) - cam_pos()).normalized()
	var u1 := (Vector3(planets[1].center) - cam_pos()).normalized()
	var u2 := (Vector3(planets[2].center) - cam_pos()).normalized()
	var axis0 := _tangent_axis(u0)
	var axis1 := _tangent_axis(u1)
	(pawns[0] as OrbPawn).place_on(0, u0)                              # far side: OCCLUDED
	(pawns[1] as OrbPawn).place_on(0, (-u0).rotated(axis0, deg_to_rad(65.0)))  # near side, offset: VISIBLE
	if pawns.size() > 2:
		(pawns[2] as OrbPawn).place_on(1, u1)                            # far side: OCCLUDED
	if pawns.size() > 3:
		(pawns[3] as OrbPawn).place_on(2, -u2)                           # near side, alone: VISIBLE
	var ball_dir := u1.rotated(axis1, deg_to_rad(25.0))
	var b: OrbBall = balls[0] if balls.size() > 0 else _spawn_ball_at(1, ball_dir, false)
	b.global_position = Vector3(planets[1].center) + ball_dir * (float(planets[1].radius) + OrbBall.RADIUS)
	b.vel = Vector3.ZERO
	b.state = OrbBall.S.REST
	b.rest_planet = 1
	b.refresh_color()
	print("XRAY_DEMO staged occluded_pawns=[0,2] visible_pawns=[1,3] ball_at=%s" % [str(b.global_position)])
	await get_tree().create_timer(0.4).timeout
	print("XRAY_STATE p0_occluded=%s p1_occluded=%s ball_occluded=%s"
		% [str(point_occluded((pawns[0] as OrbPawn).body_center())),
			str(point_occluded((pawns[1] as OrbPawn).body_center())),
			str(point_occluded(b.global_position))])
	await _xray_grab("wide")
	print("XRAY_DEMO_DONE")
	if _autoquit:
		get_tree().quit()

## A unit axis perpendicular to u, used to rotate a near/far-side direction
## off the dead-center camera line onto a different clock position.
func _tangent_axis(u: Vector3) -> Vector3:
	var t := u.cross(Vector3.UP)
	if t.length() < 0.1:
		t = u.cross(Vector3.RIGHT)
	return t.normalized()

func _xray_grab(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("XRAY_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://verify_out/orbital_sil/xray_%s.png" % tag
	img.save_png(path)
	print("XRAY_CAP ", path)


## --- ONLINE (phase 2): the mirror ---------------------------------------------
## Host sim untouched. Ask of every key: is this on every couch screen right
## now? Pawn poses, ball state+velocity (the whole threat ladder is derived
## from velocity client-side), HUD strings, counters — yes. Nothing else.

## HOST, pumped by the estate at 20 Hz.
func _net_state() -> Dictionary:
	var fs: Array = []
	for p in pawns:
		var pw: OrbPawn = p
		fs.append(1 if pw.alive else 0)
		fs.append(1 if pw.visible else 0)
		fs.append(snappedf(pw.global_position.x, 0.01))
		fs.append(snappedf(pw.global_position.y, 0.01))
		fs.append(snappedf(pw.global_position.z, 0.01))
		var q := pw.global_transform.basis.get_rotation_quaternion()
		fs.append(snappedf(q.x, 0.001))
		fs.append(snappedf(q.y, 0.001))
		fs.append(snappedf(q.z, 0.001))
		fs.append(snappedf(q.w, 0.001))
		fs.append(maxi(NET_ANIMS.find(pw._cur_anim), 0))
		fs.append(snappedf(pw.charge, 0.02))
		fs.append(snappedf(maxf(pw.invuln, 0.0), 0.05))
	var bs: Array = []
	for b in balls:
		var bb: OrbBall = b
		bs.append(int(bb.state))
		bs.append(snappedf(bb.global_position.x, 0.01))
		bs.append(snappedf(bb.global_position.y, 0.01))
		bs.append(snappedf(bb.global_position.z, 0.01))
		bs.append(snappedf(bb.vel.x, 0.01))
		bs.append(snappedf(bb.vel.y, 0.01))
		bs.append(snappedf(bb.vel.z, 0.01))
		bs.append(bb.owner_idx)
		bs.append(bb.holder_idx)
		bs.append(snappedf(bb.age(now), 0.1) if bb.state == OrbBall.S.FLYING else 0.0)
	var sc: Array = []
	var ct: Array = []
	var dth: Array = []
	for p in pawns:
		var idx: int = (p as OrbPawn).index
		sc.append(int(_points.get(idx, 0)))
		ct.append(int(catches.get(idx, 0)))
		dth.append(int(deaths.get(idx, 0)))
	return {
		"ph": phase,
		"tl": snappedf(time_left, 0.05),
		"ban": [_banner.text, _banner_col, _banner.visible],
		"ev": [_event_label.text, _event_col, _event_gen],
		"fo": _net_fo,
		"bn": [_net_bounce, _net_bounce_imp],
		"lk": _net_kill.duplicate(),
		"f": fs,
		"b": bs,
		"sc": sc,
		"ct": ct,
		"dth": dth,
		"champ": _net_champ,
	}


## CLIENT. Latest-state-wins; all juice fires from DELTAS (counters, never
## events — a dropped packet loses nothing but in-between frames).
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	_mir_ball_t = 0.0
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()   # FINAL STRETCH: light bed on first snapshot
	phase = (int(state.get("ph", phase))) as Phase   # render/probe fact only
	time_left = float(state.get("tl", time_left))
	_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	# --- event line: gen bump replays the flash (same text twice still fires)
	var ev: Array = state.get("ev", [])
	var pev: Array = prev.get("ev", [])
	if ev.size() >= 3 and int(ev[2]) != (int(pev[2]) if pev.size() >= 3 else 0):
		_flash_event(str(ev[0]), Color(str(ev[1])))
	# --- FINAL ORBIT: kit escalation + starfield shift, locally, off the flip
	if int(state.get("fo", 0)) == 1 and int(prev.get("fo", 0)) == 0:
		if _stretch != null:
			_stretch.escalate()
		if _star_mat != null:
			var tw := create_tween()
			tw.tween_property(_star_mat, "albedo_color",
				Color.WHITE.lerp(Color(1.0, 0.25, 0.18), 0.2), 2.0)
		_mir_snap_once("orb_mirror_finalorbit")
	# --- pawn facts: alive edges, anim, charge/invuln resync, catch flashes
	var fs: Array = state.get("f", [])
	var pfs: Array = prev.get("f", [])
	var ct: Array = state.get("ct", [])
	var pct: Array = prev.get("ct", [])
	for i in pawns.size():
		var b := i * 12
		if b + 11 >= fs.size():
			break
		var pw: OrbPawn = pawns[i]
		var alive := int(fs[b]) == 1
		if alive != pw.alive:
			pw.alive = alive
			if alive:   # respawned: pop back exactly as the couch hears it
				pw.global_position = Vector3(float(fs[b + 2]), float(fs[b + 3]), float(fs[b + 4]))
				if pw._visual != null:
					pw._visual.visible = true
				Sfx.play("confirm", -4.0)
				_spawn_burst(pw.body_center(), pawn_color(pw.index), 12)
				# GHOST MEDDLING (mirror): the seat returns — retire its wisp.
				_meddle.remove_ghost(i)
				_refresh_meddle_hints()
			elif not bool(bot_enabled[i]):
				# GHOST MEDDLING (mirror): the alive edge is our death signal here (no
				# sim runs). Raise this dead HUMAN seat's wisp locally at the death spot.
				_meddle.add_ghost(i, str(pawn_name(i)), pawn_color(i), pw.body_center(), 1.4, false)
				_refresh_meddle_hints()
		pw.visible = int(fs[b + 1]) == 1
		pw._play(NET_ANIMS[clampi(int(fs[b + 9]), 0, NET_ANIMS.size() - 1)])
		var chg := float(fs[b + 10])
		if chg < 0.0 or pw.charge < 0.0 or absf(pw.charge - chg) > 0.08:
			pw.charge = chg   # THE TENSION: hold-fill resync (advances locally)
		var inv := float(fs[b + 11])
		if absf(pw.invuln - inv) > 0.12:
			pw.invuln = inv
		if i < ct.size() and int(ct[i]) > (int(pct[i]) if i < pct.size() else int(ct[i])):
			# a catch connected: the couch's bumper + white burst + shake
			Sfx.play("bumper")
			_shake = maxf(_shake, 0.18)
			_spawn_burst(pw.body_center(), Color(1, 1, 1), 16)
			_mir_snap_once("orb_mirror_catch")
	# --- balls: spawn-to-count, state transitions, colors, velocity, age
	_mir_sync_balls(state.get("b", []), prev.get("b", []))
	# --- held glue: pawns hold the mirrored balls (aim preview reads .held)
	for p in pawns:
		(p as OrbPawn).held = null
	for b in balls:
		var bb: OrbBall = b
		if bb.state == OrbBall.S.HELD and bb.holder_idx >= 0 and bb.holder_idx < pawns.size():
			(pawns[bb.holder_idx] as OrbPawn).held = bb
	# --- bounce sfx from the counter (one voice per window is plenty)
	var bn: Array = state.get("bn", [])
	var pbn: Array = prev.get("bn", [])
	if bn.size() >= 2 and int(bn[0]) > (int(pbn[0]) if pbn.size() >= 2 else int(bn[0])):
		Sfx.play("bounce", clampf(-14.0 + float(bn[1]) * 1.4, -14.0, -3.0))
	# --- the kill row: burst + speed-scaled impact + sfx, exactly as couch
	var lk: Array = state.get("lk", [])
	var plk: Array = prev.get("lk", [0])
	if lk.size() >= 4 and int(lk[0]) > int(plk[0] if plk.size() >= 1 else 0):
		var victim := int(lk[1])
		Sfx.play("splat")
		Sfx.play("death")
		_kill_impact(float(lk[3]))
		if victim >= 0 and victim < pawns.size():
			_spawn_burst((pawns[victim] as OrbPawn).body_center(), pawn_color(victim), 30)
	# --- scoreboard facts
	if state.get("sc", []) != prev.get("sc", []):
		var sc: Array = state.get("sc", [])
		for i in mini(sc.size(), pawns.size()):
			_points[(pawns[i] as OrbPawn).index] = int(sc[i])
		_update_score_rows()
	# --- the champion moment (champ fact beats the fold by one real beat)
	if phase == Phase.END and not _mir_done:
		var champ := int(state.get("champ", -1))
		if champ >= 0 and champ < pawns.size():
			_mir_done = true
			if _stretch != null:
				_stretch.match_ended()
			Sfx.play("match_win")
			_spawn_burst((pawns[champ] as OrbPawn).body_center(), pawn_color(champ), 40)


## CLIENT, per physics tick: glide pawns, dead-reckon balls between snapshots,
## grow hold-fills and trails — everything smoother than 20 Hz.
func _mirror_tick(delta: float) -> void:
	if _mir.is_empty():
		return
	now += delta
	_mir_ball_t += delta
	if phase == Phase.PLAY:
		time_left = maxf(time_left - delta, 0.0)
	var w := 1.0 - exp(-14.0 * delta)
	var fs: Array = _mir.get("f", [])
	for i in pawns.size():
		var b := i * 12
		if b + 11 >= fs.size():
			break
		var pw: OrbPawn = pawns[i]
		pw.global_position = pw.global_position.lerp(
			Vector3(float(fs[b + 2]), float(fs[b + 3]), float(fs[b + 4])), w)
		var tq := Quaternion(float(fs[b + 5]), float(fs[b + 6]), float(fs[b + 7]), float(fs[b + 8]))
		if tq.length_squared() > 0.5:
			var cq := pw.global_transform.basis.get_rotation_quaternion()
			pw.global_transform.basis = Basis(cq.slerp(tq.normalized(), w))
		# derive the tangent frame from the mirrored basis (_orient invariants:
		# +Y = surface up, +Z = heading) so the dotted aim preview just works
		pw.srf_n = pw.global_transform.basis.y.normalized()
		pw.heading = pw.global_transform.basis.z.normalized()
		if pw.charge >= 0.0 and pw.held != null:
			pw.charge = minf(pw.charge + delta / OrbPawn.AIM_TIME, 1.0)
		pw.invuln = maxf(pw.invuln - delta, 0.0)
	var bs: Array = _mir.get("b", [])
	for k in balls.size():
		var b := k * 10
		if b + 9 >= bs.size():
			break
		var bb: OrbBall = balls[k]
		if bb.state == OrbBall.S.HELD:
			if bb.holder_idx >= 0 and bb.holder_idx < pawns.size():
				var hp: OrbPawn = pawns[bb.holder_idx]
				bb.global_position = hp.body_center() + hp.up_dir() * 0.5 + hp.heading * 0.25
			continue
		var snap_pos := Vector3(float(bs[b + 1]), float(bs[b + 2]), float(bs[b + 3]))
		if bb.state == OrbBall.S.FLYING:
			# dead-reckon: advance the snapshot by its own velocity, then glide
			bb.global_position = bb.global_position.lerp(
				snap_pos + bb.vel * _mir_ball_t, 1.0 - exp(-20.0 * delta))
			if bb.trail != null:
				bb.trail.add_point(bb.global_position, now)
			# top-heat evidence latch: same condition as the host's pair
			if not _mir_snaps.has("orb_mirror_heat") and bb.heat_factor() >= 0.75:
				for p in pawns:
					var pw2: OrbPawn = p
					if pw2.alive and bb.global_position.distance_to(pw2.body_center()) < 6.0:
						_mir_snap_once("orb_mirror_heat")
						break
		else:
			bb.global_position = bb.global_position.lerp(snap_pos, w)

	# GHOST MEDDLING (mirror): drive the LOCAL seat's wisp (cooldown + its own
	# presentation pulse fires here — orbital's meddle is presentation-only, so
	# each screen renders its own; no sim, no network). Others idle-hover.
	_meddle.tick_cosmetic(delta, NetSession.my_seat())


## Host-side pair of the mirror's top-heat latch (probe nights only).
func _heat_moment() -> bool:
	for b in balls:
		var bb: OrbBall = b
		if bb.heat_factor() < 0.75:
			continue
		for p in pawns:
			var pw: OrbPawn = p
			if pw.alive and bb.global_position.distance_to(pw.body_center()) < 6.0:
				return true
	return false


func _mir_sync_balls(bs: Array, pbs: Array) -> void:
	var want := bs.size() / 10
	var fresh_from := balls.size()
	while balls.size() < want:
		_mir_spawn_ball()
	for k in balls.size():
		var b := k * 10
		if b + 9 >= bs.size():
			break
		var bb: OrbBall = balls[k]
		if k >= fresh_from:   # just drifted in: land on its spot, no glide-in
			bb.global_position = Vector3(float(bs[b + 1]), float(bs[b + 2]), float(bs[b + 3]))
		var st := int(bs[b])
		var pst := int(pbs[b]) if b < pbs.size() else st
		var own := int(bs[b + 7])
		var hol := int(bs[b + 8])
		if st != int(bb.state):
			if st == OrbBall.S.HELD:
				bb.pick_up(hol)          # clears the trail, tints to the holder
				Sfx.play("card", -6.0)
			elif st == OrbBall.S.FLYING and pst == OrbBall.S.HELD:
				Sfx.play("putt")         # a throw left somebody's hand
			bb.state = st as OrbBall.S
		if own != bb.owner_idx or hol != bb.holder_idx:
			bb.owner_idx = own
			bb.holder_idx = hol
			bb.refresh_color()
		bb.vel = Vector3(float(bs[b + 4]), float(bs[b + 5]), float(bs[b + 6]))
		bb.throw_time = now - float(bs[b + 9])   # age() true: ghost pulse + labels


## A drifted-in ball on the mirror: same node kit, position rides the wire.
func _mir_spawn_ball() -> OrbBall:
	var b := OrbBall.new()
	b.world = self
	_ball_root.add_child(b)
	b.state = OrbBall.S.REST
	var t := OrbTrail.new()
	_trail_root.add_child(t)
	b.trail = t
	b.refresh_color()
	balls.append(b)
	return b


func _apply_mir_banner(arr: Array, parr: Array) -> void:
	if arr.size() < 3:
		return
	_banner.text = str(arr[0])
	_banner.add_theme_color_override("font_color", Color(str(arr[1])))
	var was: bool = parr.size() >= 3 and bool(parr[2]) and str(parr[0]) == str(arr[0])
	_banner.visible = bool(arr[2])
	if _banner.visible and not was:
		_banner.pivot_offset = _banner.size / 2.0
		_banner.scale = Vector2(0.55, 0.55)
		var pop := create_tween()
		pop.tween_property(_banner, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## CLIENT: my aim against my own mirrored render (doc 10 §1.3). Orbital aims in
## SCREEN space (the sphere game), so the relay carries aim_screen, which the
## host's get_aim_screen returns verbatim for a remote seat.
func _net_aim() -> Dictionary:
	var my := NetSession.my_seat()
	var scr := Vector2.ZERO
	if my >= 0 and my < pawns.size():
		scr = PlayerInput.get_aim_screen(my, (pawns[my] as OrbPawn).body_center(), _cam)
	return {"aim": Vector3.ZERO, "aim_screen": scr}


func _mir_snap_once(tag: String) -> void:
	if _mir_snaps.has(tag):
		return
	_mir_snaps[tag] = true
	VerifyCapture.snap(tag)


## --- debug/verify surface ------------------------------------------------------

func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_playing() -> bool:
	return phase == Phase.PLAY
