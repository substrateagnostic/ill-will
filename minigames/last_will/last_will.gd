extends Minigame
## LAST WILL — survival gauntlet over the dusk void where DYING IS A POWER.
## A shrinking chapel-yard platform, a windmill-blade pendulum, rolling
## boulders. When you're eliminated the whole world FREEZES for six seconds
## while you draft your will: bless one survivor, curse another. Then you
## linger at the platform edge as a spectral onlooker, gusting the living
## every 10s. Best-of-3; puppetmaster +2 if your blessed champion wins the
## round. The dead decide who wins; the living audition for their favor.
##
## Anthology module: root of minigames/last_will/last_will.tscn, extends
## Minigame. Self-starts standalone 0.5s after _ready if begin() wasn't
## called (GameState colors/names, KayKit chars, seed from --seed= or 1).
##
## PER-PLAYER BOTS (fleet convention): the bot driver skips roster entries
## with "bot": false. Entries without the key fall back to
## PlayerInput.is_bot(). --willbots forces everyone.
##
## CLI user args (after `--`):
##   --willbots            all players are seeded self-play bots
##   --seed=N              rng seed for standalone start (default 1)
##   --players=N           standalone roster size 2..4
##   --willrounds=N        override 3 rounds (1..5) for quick verification
##   --willtally           headless evidence mode: full bot match, fast-
##                         forwarded with dt pinned to 1/60, prints
##                         WILL_TALLY (wills per round) and quits
##   --willkill=T:P,...    force-eliminate player P at round-time T (round 1
##                         only; deterministic will-theater screenshots)
##   --shots=N,...         VerifyCapture PNG harness (global autoload)
##
## RULES DECISIONS (documented per spec "Risks & tests"):
## - The will ALWAYS fires, including the round-ending death. If the round
##   is already decided, timed effects CARRY OVER into the next round's
##   opening seconds (the spec's 2P carry-over rule, generalized). Coin is
##   always instant. Carry-over blesses claim the NEXT round's puppetmaster.
## - Caps: 1 active blessing + 1 active curse per player; newest replaces.
##   Puppetmaster claims survive replacement (the cap governs effects, not
##   gratitude) — one claim per will, resolved at that round's end.
## - Gusts are nudges: they bypass shields (a shield eats one HIT — shove,
##   pendulum, or boulder squish).

enum Phase { WAITING, INTRO, ROUND, WILL, ROUND_END, MATCH_END }
enum WStep { DEATH_BEAT, REVEAL, CARDS, BLESS_T, CURSE_T, MODE, RESOLUTION, CLOSING }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

const R_FULL := 7.0
const R_MID := 5.1
const R_CORE := 3.2
const R_LAST := 1.8      # sudden death: the yard becomes a lonely pillar
const ROUND_TIME := 60.0
const HARD_CAP := 78.0
const DRAFT_BUDGET := 6.0
const ROYALTY := 2
const GUST_SPEED := 9.0
const GUST_IMPULSE := 4.4
const GUST_HIT_R := 1.8
const GUST_RANGE := 17.0

const BLESS_DEFS := {
	"shield": {"title": "AEGIS", "banner": "SHIELD", "desc": "A shield that eats one hit — shove, blade, or boulder.", "dur": 0.0},
	"swift": {"title": "DEAD MAN'S HASTE", "banner": "SWIFTNESS", "desc": "+20% speed for 10 seconds.", "dur": 10.0},
	"coin": {"title": "INHERITANCE", "banner": "A COIN", "desc": "+1 point, paid instantly.", "dur": 0.0},
}
const CURSE_DEFS := {
	"sluggish": {"title": "LEADEN LEGS", "banner": "SLUGGISH", "desc": "-20% speed for 8 seconds.", "dur": 8.0},
	"butterfingers": {"title": "BUTTERFINGERS", "banner": "BUTTERFINGERS", "desc": "Cannot shove for 6 seconds.", "dur": 6.0},
	"haunted": {"title": "HAUNTED", "banner": "HAUNTED", "desc": "A hungry wisp hunts them for 8 seconds.", "dur": 8.0},
}

var game_time := 0.0
var phase := Phase.WAITING
var rng := RandomNumberGenerator.new()
var bots: LWBots

var roster: Array = []
var players: Array = []            # {index,name,color,char_path,device,is_bot,total,alive,deaths,puppet}
var pawns: Array = []              # index -> LWPawn
var ghosts: Dictionary = {}        # index -> LWGhostSeat
var pendulums: Array = []
var boulders: Array = []
var wisps: Dictionary = {}         # target index -> LWWisp
var _gusts: Array = []             # {node, pos, dir, traveled, hit, from}

var platform_radius := R_FULL
var _next_radius := R_FULL
var _shrink_pending := false
var _floor_shape: CylinderShape3D
var _ring_segs: Array = []         # per ring: Array[MeshInstance3D]
var _ring_mats: Array = []
var _ring_roots: Array = []
var _shrink_stage := 0             # 0 full, 1 outer gone, 2 mid gone, 3 pillar
var _tele_ring := -1
var _pillar_disc: MeshInstance3D

var round_index := 0
var rounds_total := 3
var round_elapsed := 0.0
var _elim_order: Array = []
var _schedule: Array = []
var _sched_i := 0
var _boulder_side := 1
var _intro_t := 0.0
var _re_t := 0.0                   # ROUND_END sequencer time
var _re_events: Array = []         # {t, fn}
var _re_done_t := 0.0

# will theater
var _will: Dictionary = {}
var _will_queue: Array = []
var _nav_prev: Dictionary = {}
var _hand: LWHand
var _target_ring: MeshInstance3D
var _ui: LWWillUI

# meta
var _claims: Array = []            # {from, target, round}
var _carry: Array = []             # {kind, effect, from, target}
var _currency: Array = []
## Anthology kill ledger (module contract results.kill_events): each entry
## {killer: int, victim: int, cause: String}. killer -1 = environment/self (void
## fall with no shover, boulder squish, pendulum); a shove/gust into the dusk
## credits the attacker. Reporting only — mirrors the banner attribution.
var _kill_events: Array = []
var _highlights: Array = []
var _monument_counts: Dictionary = {}
var _last_kill_line := ""
var _last_kill_color := Color.WHITE

# modes
var _started := false
var _all_bots := false
var _tally := false
var _tally_stats := {"wills": 0, "rounds": 0, "void": 0, "squish": 0, "gusts": 0, "puppets": 0, "carries": 0}
var _forced_kills: Array = []      # {t, p}
var _cli_players := 4
var _cli_seed := 1
var _rounds_override := 0
var _test_mode := ""               # --willtest=squish|gust
var _dead_hint_demo := false       # --deadhint: seat 0 human, dies at t=1
var _shove_cue_probe := false      # --shovecue: snap the first shove's readability arc
var _shove_cue_done := false
var _test_fired := false
var _delta_cache := 0.016
var _skip_to := 0.0                # --willskip=T: screenshot aid, round 1 only

# fx
var _shake := 0.0
var _time_token := 0
var _banner_token := 0
var _sub_token := 0
var _cam_base_fov := 52.0

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var banner: Label = $UI/Banner
@onready var sub_banner: Label = $UI/SubBanner
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows
@onready var spawn_root: Node3D = $SpawnRoot

func _ready() -> void:
	_parse_args()
	_build_world()
	banner.visible = false
	sub_banner.visible = false
	_ui = LWWillUI.new()
	add_child(_ui)
	_hand = LWHand.new()
	spawn_root.add_child(_hand)
	_hand.visible = false
	_build_target_ring()
	await get_tree().create_timer(0.5).timeout
	if not _started:
		begin(_default_config())

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--willbots":
			_all_bots = true
		elif arg == "--willtally":
			_tally = true
			_all_bots = true
		elif arg.begins_with("--willrounds="):
			_rounds_override = clampi(int(arg.trim_prefix("--willrounds=")), 1, 5)
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--willkill="):
			for pair in arg.trim_prefix("--willkill=").split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					_forced_kills.append({"t": float(kv[0]), "p": int(kv[1])})
		elif arg.begins_with("--willtest="):
			_test_mode = arg.trim_prefix("--willtest=")
		elif arg.begins_with("--willskip="):
			_skip_to = maxf(0.0, float(arg.trim_prefix("--willskip=")))
		elif arg == "--deadhint":
			_dead_hint_demo = true
		elif arg == "--shovecue":
			_shove_cue_probe = true
			_all_bots = true
	if _dead_hint_demo:
		# seat 0 (KBM human) dies at t=1.0 so the dead-state hint bar is on screen
		_forced_kills.append({"t": 1.0, "p": 0})
	if _tally:
		# faster-than-realtime with dt pinned to exactly 1/60 (Swap Meet trick)
		var fast := 8.0
		Engine.time_scale = fast
		Engine.physics_ticks_per_second = int(60.0 * fast)
		Engine.max_physics_steps_per_frame = maxi(8, int(60.0 * fast))
		AudioServer.set_bus_mute(0, true)

func _default_config() -> Dictionary:
	PlayerInput.auto_assign(_cli_players)
	if _dead_hint_demo:
		PlayerInput.assign(0, -4)   # seat 0 = KBM human so its ghost hint reads MOUSE
	var r: Array = []
	for i in _cli_players:
		var dev := PlayerInput.device_of(i)
		var seat_bot := _all_bots or dev == -3 or dev == -99
		if _dead_hint_demo:
			seat_bot = (i != 0)   # seat 0 human (dies at t=1), the rest bots
		r.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": CHAR_FALLBACKS[i % CHAR_FALLBACKS.size()],
			"device": dev,
			"bot": seat_bot,
		})
	return {"roster": r, "rounds": 3, "rng_seed": _cli_seed, "practice": false}

func begin(config: Dictionary) -> void:
	if _started:
		return
	_started = true
	rng.seed = int(config.get("rng_seed", 1))
	rounds_total = 3
	if config.get("practice", false):
		rounds_total = 1
	if int(config.get("rounds", 3)) < 3:
		rounds_total = maxi(1, int(config.get("rounds", 3)))
	if _rounds_override > 0:
		rounds_total = _rounds_override
	roster = config.get("roster", [])
	bots = LWBots.new()
	bots.setup(int(config.get("rng_seed", 1)) ^ 0x717A57, roster.size())
	players.clear()
	pawns.clear()
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var char_path := str(pl.get("char_scene", ""))
		if char_path == "" or not ResourceLoader.exists(char_path):
			char_path = CHAR_FALLBACKS[i % CHAR_FALLBACKS.size()]
		var is_bot: bool = _all_bots or bool(pl.get("bot", PlayerInput.is_bot(int(pl.get("index", i)))))
		players.append({
			"index": int(pl.get("index", i)),
			"name": str(pl.get("name", "P%d" % i)),
			"color": pl.get("color", Color.WHITE),
			"char_path": char_path,
			"device": int(pl.get("device", -99)),
			"is_bot": is_bot,
			"total": 0,
			"alive": true,
			"deaths": 0,
			"puppet": 0,
		})
		var pawn := LWPawn.new()
		pawn.name = "Pawn%d" % i
		spawn_root.add_child(pawn)
		pawn.setup(i, players[i].color, players[i].name, load(char_path), self)
		pawn.died.connect(_on_pawn_died)
		pawns.append(pawn)
	print("LW_BEGIN players=%d seed=%d rounds=%d bots=%s" % [players.size(),
		rng.seed, rounds_total, str(players.map(func(p): return p.is_bot))])
	hint_label.text = HINT_LIVING
	round_index = 0
	_start_round()

# ================================================================ world
func _build_world() -> void:
	var we: WorldEnvironment = $WorldEnvironment
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.13, 0.08, 0.24)
	sky_mat.sky_horizon_color = Color(0.72, 0.34, 0.22)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color(0.04, 0.03, 0.09)
	sky_mat.ground_horizon_color = Color(0.45, 0.2, 0.2)
	sky_mat.sun_angle_max = 40.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.1, 0.2)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.0
	we.environment = env

	cam.global_position = Vector3(0, 13.9, 11.8)
	cam.look_at(Vector3(0, 0.2, -0.7), Vector3.UP)
	cam.fov = _cam_base_fov

	var sun := DirectionalLight3D.new()
	sun.name = "DuskSun"
	add_child(sun)
	sun.rotation_degrees = Vector3(-19.0, 118.0, 0.0)
	sun.light_energy = 0.7
	sun.light_color = Color(1.0, 0.58, 0.33)
	sun.shadow_enabled = true

	var moon := DirectionalLight3D.new()
	moon.name = "MoonFill"
	add_child(moon)
	moon.rotation_degrees = Vector3(-48.0, -50.0, 0.0)
	moon.light_energy = 0.28
	moon.light_color = Color(0.5, 0.58, 0.95)

	# the void has a floor of dusk, not pure black: a deep-purple sea far
	# below + a faint warm under-glow that silhouettes falling bodies
	var sea := MeshInstance3D.new()
	var seam := CylinderMesh.new()
	seam.top_radius = 90.0
	seam.bottom_radius = 90.0
	seam.height = 0.3
	sea.mesh = seam
	var sea_mat := StandardMaterial3D.new()
	sea_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sea_mat.albedo_color = Color(0.085, 0.05, 0.13)
	sea.material_override = sea_mat
	sea.position.y = -26.0
	$Arena.add_child(sea)
	var under_glow := MeshInstance3D.new()
	var ugm := CylinderMesh.new()
	ugm.top_radius = 13.0
	ugm.bottom_radius = 13.0
	ugm.height = 0.1
	under_glow.mesh = ugm
	var ug_mat := StandardMaterial3D.new()
	ug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ug_mat.albedo_color = Color(0.55, 0.2, 0.28, 0.16)
	under_glow.material_override = ug_mat
	under_glow.position.y = -9.5
	$Arena.add_child(under_glow)

	# floor collider: one fat cylinder slab, radius shrinks with the yard
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	$Arena.add_child(floor_body)
	var cs := CollisionShape3D.new()
	_floor_shape = CylinderShape3D.new()
	_floor_shape.radius = R_FULL
	_floor_shape.height = 3.0
	cs.shape = _floor_shape
	cs.position.y = -1.5
	floor_body.add_child(cs)

	_build_decor_islands()
	_build_ember_field()

func _build_decor_islands() -> void:
	# a broken chapel arch drifting behind the yard + stray rock shards
	var arch := Node3D.new()
	arch.name = "ArchIsland"
	$Arena.add_child(arch)
	arch.position = Vector3(-9.5, -1.4, -7.5)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.3, 0.27, 0.33)
	rock_mat.roughness = 1.0
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 2.4
	bm.bottom_radius = 0.9
	bm.height = 2.2
	base.mesh = bm
	base.material_override = rock_mat
	base.position.y = -1.1
	arch.add_child(base)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.47, 0.52)
	stone_mat.roughness = 0.92
	for px in [-1.1, 1.1]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.7, 3.4, 0.7)
		pillar.mesh = pm
		pillar.material_override = stone_mat
		pillar.position = Vector3(px, 1.7, 0)
		arch.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(2.0, 0.55, 0.8)
	lintel.mesh = lm
	lintel.material_override = stone_mat
	lintel.position = Vector3(-0.55, 3.55, 0)
	lintel.rotation_degrees = Vector3(0, 0, 9)
	arch.add_child(lintel)
	var arch_lantern := _make_lantern(true)
	arch_lantern.position = Vector3(1.1, 3.6, 0)
	arch.add_child(arch_lantern)

	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.24, 0.22, 0.3)
	shard_mat.roughness = 1.0
	for sp in [Vector3(10.5, -2.6, -5.0), Vector3(8.5, -3.4, 6.5), Vector3(-10.0, -3.0, 5.0)]:
		var shard := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 1.3
		sm.bottom_radius = 0.3
		sm.height = 1.8
		shard.mesh = sm
		shard.material_override = shard_mat
		shard.position = sp
		shard.rotation_degrees = Vector3(8, 40, -6)
		$Arena.add_child(shard)

func _build_ember_field() -> void:
	var p := CPUParticles3D.new()
	p.name = "Embers"
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 2, 12)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.6, 0.3, 0.35)
	p.material_override = mat
	p.position.y = -3.0
	p.emitting = true
	$Arena.add_child(p)

func _make_lantern(with_light: bool) -> Node3D:
	var root := Node3D.new()
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.09, 1.15, 0.09)
	post.mesh = pm
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.16, 0.13, 0.12)
	post.material_override = post_mat
	post.position.y = 0.57
	root.add_child(post)
	# glowing amber housing (translucent, so the lamp reads from every angle)
	var cage := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.28, 0.32, 0.28)
	cage.mesh = cm
	var cage_mat := StandardMaterial3D.new()
	cage_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cage_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cage_mat.albedo_color = Color(1.0, 0.76, 0.38, 0.55)
	cage_mat.emission_enabled = true
	cage_mat.emission = Color(1.0, 0.7, 0.3)
	cage_mat.emission_energy_multiplier = 1.9
	cage.material_override = cage_mat
	cage.position.y = 1.3
	root.add_child(cage)
	# tiny finial knob — the amber housing must stay visible from the high
	# couch camera (an earlier full-width cap blacked every lantern out)
	var cap := MeshInstance3D.new()
	var capm := SphereMesh.new()
	capm.radius = 0.06
	capm.height = 0.12
	cap.mesh = capm
	cap.material_override = post_mat
	cap.position.y = 1.5
	root.add_child(cap)
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.34)
		l.light_energy = 2.1
		l.omni_range = 4.2
		l.position.y = 1.35
		root.add_child(l)
	return root

func _build_platform() -> void:
	for r in _ring_roots:
		if is_instance_valid(r):
			r.queue_free()
	_ring_roots.clear()
	if _pillar_disc != null and is_instance_valid(_pillar_disc):
		_pillar_disc.queue_free()
		_pillar_disc = null
	_ring_segs = [[], [], []]
	_ring_mats = [[], [], []]
	_shrink_stage = 0
	_tele_ring = -1
	platform_radius = R_FULL
	_next_radius = R_FULL
	_shrink_pending = false
	_floor_shape.radius = R_FULL

	# ring definitions: [inner_r, outer_r, seg_count, ring_id]
	# ring_id 2 = outer (falls at 20s), 1 = mid (40s), 0 = core ring (falls
	# at SUDDEN DEATH — only the r=1.8 pillar disc endures)
	var defs := [[R_MID, R_FULL, 30, 2], [R_CORE, R_MID, 22, 1], [R_LAST, R_CORE, 12, 0]]
	for d in defs:
		var inner: float = d[0]
		var outer: float = d[1]
		var n: int = d[2]
		var ring_id: int = d[3]
		var root := Node3D.new()
		root.name = "Ring%d" % ring_id
		$Arena.add_child(root)
		_ring_roots.append(root)
		if ring_id == 0:
			# the last pillar: a disc that never falls, parented to Arena
			# (NOT this ring root) so the sudden-death crumble spares it
			var disc := MeshInstance3D.new()
			var dm := CylinderMesh.new()
			dm.top_radius = R_LAST + 0.06
			dm.bottom_radius = R_LAST * 0.62
			dm.height = 2.6
			disc.mesh = dm
			var dmat := StandardMaterial3D.new()
			dmat.albedo_color = Color(0.5, 0.47, 0.53)
			dmat.roughness = 0.95
			disc.material_override = dmat
			disc.position.y = -1.31
			$Arena.add_child(disc)
			_pillar_disc = disc
			# the last flame: candle stubs + one warm light that NEVER falls,
			# so the sudden-death brawl isn't fought in the dark
			var candle_mat := StandardMaterial3D.new()
			candle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			candle_mat.albedo_color = Color(1.0, 0.82, 0.5)
			candle_mat.emission_enabled = true
			candle_mat.emission = Color(1.0, 0.7, 0.3)
			candle_mat.emission_energy_multiplier = 1.6
			for ci in 5:
				var ca := TAU * ci / 5.0 + 0.4
				var candle := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.055
				cyl.bottom_radius = 0.07
				cyl.height = 0.16 + 0.07 * ((ci * 3) % 3)
				candle.mesh = cyl
				candle.material_override = candle_mat
				candle.position = Vector3(cos(ca) * (R_LAST - 0.28), 0.09, sin(ca) * (R_LAST - 0.28))
				disc.add_child(candle)
				candle.position.y += 1.31   # counter the disc's own offset
			var pl := OmniLight3D.new()
			pl.light_color = Color(1.0, 0.72, 0.38)
			pl.light_energy = 1.7
			pl.omni_range = 5.0
			pl.position.y = 1.31 + 1.6
			disc.add_child(pl)
		var rm := (inner + outer) / 2.0
		for i in n:
			var a := TAU * i / n + (0.11 * ring_id)
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var tangential := rm * TAU / n * 0.97
			bm.size = Vector3(outer - inner - 0.04, 1.5, tangential)
			seg.mesh = bm
			var mat := StandardMaterial3D.new()
			var shade := 0.28 + 0.11 * ((i * 7 + ring_id * 3) % 5) / 4.0
			mat.albedo_color = Color(shade * 0.96, shade * 0.94, shade * 1.14)
			mat.roughness = 0.95
			seg.material_override = mat
			seg.position = Vector3(cos(a) * rm, -0.76 - 0.012 * ((i * 5) % 3), sin(a) * rm)
			seg.rotation.y = -a
			root.add_child(seg)
			_ring_segs[ring_id].append(seg)
			_ring_mats[ring_id].append(mat)
		# lanterns per ring — every lantern is LIT; at dusk they carry the scene
		var lant_counts := {2: 6, 1: 4, 0: 3}
		var ln: int = lant_counts[ring_id]
		for i in ln:
			var a := TAU * i / ln + 0.35 + ring_id * 0.5
			var lr := outer - 0.45
			if ring_id == 0:
				lr = R_CORE - 0.5
			var lant := _make_lantern(true)
			lant.position = Vector3(cos(a) * lr, 0, sin(a) * lr)
			root.add_child(lant)
	# gravestones + cracked slab flavor on core and mid
	var grave_mat := StandardMaterial3D.new()
	grave_mat.albedo_color = Color(0.33, 0.32, 0.38)
	grave_mat.roughness = 1.0
	for g in [[1.6, 0.9, -12.0], [-1.9, 2.2, 8.0], [3.9, -2.4, 20.0]]:
		var stone := Node3D.new()
		var body := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.5, 0.7, 0.14)
		body.mesh = bm2
		body.material_override = grave_mat
		body.position.y = 0.35
		stone.add_child(body)
		var top := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.25
		tm.bottom_radius = 0.25
		tm.height = 0.14
		top.mesh = tm
		top.material_override = grave_mat
		top.rotation_degrees = Vector3(90, 0, 0)
		top.position.y = 0.7
		stone.add_child(top)
		stone.position = Vector3(g[0], 0, g[1])
		stone.rotation_degrees = Vector3(0, g[2], 4)
		# gravestones ride their ring's root so they crumble with the yard
		var ring_id := 0 if Vector2(g[0], g[1]).length() < R_CORE else 1
		_ring_roots[ring_root_index(ring_id)].add_child(stone)

func _build_target_ring() -> void:
	_target_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.95
	_target_ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 1.8
	_target_ring.material_override = mat
	_target_ring.visible = false
	spawn_root.add_child(_target_ring)

# ================================================================ rounds
func _start_round() -> void:
	print("LW_ROUND_START %d/%d t=%.1f" % [round_index + 1, rounds_total, game_time])
	phase = Phase.INTRO
	_intro_t = 0.0
	round_elapsed = 0.0
	_elim_order.clear()
	_clear_hazards()
	_clear_ghosts()
	_clear_wisps()
	_build_platform()
	_build_schedule()
	var n := players.size()
	for i in n:
		players[i].alive = true
		var a := TAU * i / n + 0.6
		pawns[i].revive(Vector3(cos(a) * 4.1, 0.25, sin(a) * 4.1))
		pawns[i].set_world_frozen(true)
	# carry-over wills from the previous round's dying breath
	var carry_lines: Array = []
	for c in _carry:
		var tgt: int = c.target
		if c.kind == "bless":
			_apply_bless_effect(str(c.effect), int(c.from), tgt)
			_register_claim(int(c.from), tgt, round_index)
			carry_lines.append("%s'S BLESSING ENDURES: %s — %s" % [player_name(c.from),
				player_name(tgt), str(BLESS_DEFS[c.effect].banner)])
		else:
			_apply_curse_effect(str(c.effect), int(c.from), tgt)
			carry_lines.append("%s'S CURSE ENDURES: %s — %s" % [player_name(c.from),
				player_name(tgt), str(CURSE_DEFS[c.effect].banner)])
		_tally_stats.carries += 1
		print("LW_CARRYOVER %s %s %s->%s" % [c.kind, c.effect, player_name(c.from), player_name(tgt)])
	_carry.clear()
	if _skip_to > 0.0 and round_index == 0:
		round_elapsed = _skip_to
	round_label.text = "ROUND %d / %d" % [round_index + 1, rounds_total]
	_rebuild_scoreboard()
	_refresh_hint()   # everyone revived -> back to the living legend
	if not _tally:
		_flash_banner("ROUND %d\nSURVIVE — OR RULE FROM BEYOND" % (round_index + 1), Color(1, 0.85, 0.2), 1.9)
		if carry_lines.size() > 0:
			_flash_sub(String("\n".join(carry_lines)), Color(0.8, 1.0, 0.75), 3.2)

func _build_schedule() -> void:
	_schedule.clear()
	_sched_i = 0
	if _test_mode != "":
		return   # self-tests drive their own hazards
	var pend_a := rng.randf_range(0.0, 180.0)
	_schedule = [
		{"t": 5.0, "k": "boulder"},
		{"t": 11.0, "k": "pendulum", "a": pend_a, "swings": 3},
		{"t": 18.0, "k": "shrink_tele", "ring": 2},
		{"t": 20.0, "k": "shrink", "ring": 2},
		{"t": 23.5, "k": "boulder"},
		{"t": 24.3, "k": "boulder"},
		{"t": 30.0, "k": "pendulum", "a": pend_a + rng.randf_range(50.0, 130.0), "swings": 3},
		{"t": 38.0, "k": "shrink_tele", "ring": 1},
		{"t": 40.0, "k": "shrink", "ring": 1},
		{"t": 43.0, "k": "boulder"},
		{"t": 43.8, "k": "boulder"},
		{"t": 49.0, "k": "pendulum", "a": rng.randf_range(0.0, 180.0), "swings": 4},
		{"t": 55.0, "k": "boulder"},
		{"t": 55.8, "k": "boulder"},
		{"t": 58.0, "k": "shrink_tele", "ring": 0},
		{"t": 60.0, "k": "sudden"},
		{"t": 60.05, "k": "shrink", "ring": 0},
		{"t": 63.0, "k": "boulder"},
		{"t": 66.5, "k": "boulder"},
		{"t": 68.8, "k": "boulder"},
		{"t": 71.0, "k": "pendulum", "a": rng.randf_range(0.0, 180.0), "swings": 4},
		{"t": 72.4, "k": "boulder"},
		{"t": 74.6, "k": "boulder"},
		{"t": 76.4, "k": "boulder"},
	]

func _process_schedule() -> void:
	while _sched_i < _schedule.size() and round_elapsed >= float(_schedule[_sched_i].t):
		var ev: Dictionary = _schedule[_sched_i]
		_sched_i += 1
		# --willskip fast-forward: stale moving hazards are skipped, but the
		# shrink chain always replays so the platform state stays honest
		if round_elapsed - float(ev.t) > 1.5 and str(ev.k) in ["boulder", "pendulum"]:
			continue
		match str(ev.k):
			"boulder":
				_spawn_boulder()
			"pendulum":
				var pen := LWPendulum.new()
				spawn_root.add_child(pen)
				pen.setup(float(ev.a), int(ev.swings), self)
				pendulums.append(pen)
				if not _tally:
					_flash_sub("THE PENDULUM STIRS", Color(1.0, 0.5, 0.4), 1.4)
			"shrink_tele":
				_tele_ring = int(ev.ring)
				_shrink_pending = true
				_next_radius = R_MID if int(ev.ring) == 2 else (R_CORE if int(ev.ring) == 1 else R_LAST)
				Sfx.play("grudge", -6.0)
				if not _tally:
					_flash_sub("THE YARD IS CRUMBLING!", Color(1.0, 0.45, 0.3), 1.8)
			"shrink":
				_do_shrink(int(ev.ring))
			"sudden":
				if not _tally:
					_flash_banner("SUDDEN DEATH\nONLY THE PILLAR REMAINS", Color(1.0, 0.35, 0.25), 2.0)
					Sfx.play("grudge", -2.0)

func _spawn_boulder() -> void:
	_boulder_side = -_boulder_side
	var a := rng.randf_range(0.0, 360.0)
	if _boulder_side < 0:
		a += 180.0
	var off := rng.randf_range(-0.55, 0.55) * platform_radius
	var b := LWBoulder.new()
	spawn_root.add_child(b)
	b.setup(a, off, self)
	boulders.append(b)

func _do_shrink(ring: int) -> void:
	_tele_ring = -1
	_shrink_pending = false
	_shrink_stage = 3 - ring
	platform_radius = R_MID if ring == 2 else (R_CORE if ring == 1 else R_LAST)
	_floor_shape.radius = platform_radius
	Sfx.play("crush", -2.0)
	_shake = maxf(_shake, 0.5)
	print("LW_SHRINK ring=%d radius=%.1f t=%.1f" % [ring, platform_radius, round_elapsed])
	# fall ALL the way past the void sea and free — resting at a shallow
	# depth left a ghost-ring visible from the top-down camera
	var segs: Array = _ring_segs[ring]
	for i in segs.size():
		var seg: MeshInstance3D = segs[i]
		if not is_instance_valid(seg):
			continue
		var tw := create_tween()
		var d := 0.03 * (i % 7)
		tw.tween_interval(d)
		tw.tween_property(seg, "position:y", seg.position.y - 34.0, 2.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(seg, "rotation:x", rng.randf_range(-2.6, 2.6), 2.1)
		tw.parallel().tween_property(seg, "rotation:z", rng.randf_range(-2.6, 2.6), 2.1)
		tw.tween_callback(seg.queue_free)
	# lanterns and gravestones on that ring fall with their parent segs' root
	var root: Node3D = _ring_roots[ring_root_index(ring)]
	for child in root.get_children():
		if child is MeshInstance3D:
			continue  # segs handled above
		var tw2 := create_tween()
		tw2.tween_property(child, "position:y", child.position.y - 34.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(child, "rotation:x", 0.9, 2.0)
		tw2.tween_callback(child.queue_free)

func ring_root_index(ring: int) -> int:
	# _ring_roots built in order [outer(2), mid(1), core(0)]
	return 2 - ring

func bot_safe_radius() -> float:
	return (_next_radius if _shrink_pending else platform_radius) - 0.7

func _clear_hazards() -> void:
	for p in pendulums:
		if is_instance_valid(p):
			p.queue_free()
	pendulums.clear()
	for b in boulders:
		if is_instance_valid(b):
			b.queue_free()
	boulders.clear()
	for g in _gusts:
		if is_instance_valid(g.node):
			g.node.queue_free()
	_gusts.clear()

func _clear_ghosts() -> void:
	for k in ghosts:
		if is_instance_valid(ghosts[k]):
			ghosts[k].queue_free()
	ghosts.clear()

func _clear_wisps() -> void:
	for k in wisps:
		if is_instance_valid(wisps[k]):
			wisps[k].queue_free()
	wisps.clear()

# ================================================================ tick
func _physics_process(delta: float) -> void:
	game_time += delta
	if _shake > 0.001:
		cam.h_offset = rng.randf_range(-1, 1) * _shake * 0.3
		cam.v_offset = rng.randf_range(-1, 1) * _shake * 0.3
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	if _target_ring != null and _target_ring.visible:
		var s := 1.0 + 0.1 * sin(game_time * 7.0)
		_target_ring.scale = Vector3(s, 1.0, s)

	match phase:
		Phase.INTRO:
			_intro_t += delta
			if _intro_t >= (0.2 if _tally else 1.6):
				phase = Phase.ROUND
				_set_frozen(false)
		Phase.ROUND:
			_tick_round(delta)
		Phase.WILL:
			_tick_will(delta)
		Phase.ROUND_END:
			_tick_round_end(delta)
		_:
			pass

func _tick_round(delta: float) -> void:
	round_elapsed += delta
	_update_timer_label()
	_process_schedule()
	_pulse_telegraph()

	# forced kills (screenshot determinism)
	if round_index == 0:
		for fk in _forced_kills:
			if not fk.get("done", false) and round_elapsed >= float(fk.t):
				fk["done"] = true
				var p: int = int(fk.p)
				if p >= 0 and p < pawns.size() and pawns[p].alive:
					print("LW_FORCEKILL p=%d t=%.1f" % [p, round_elapsed])
					pawns[p]._die("void")
					return

	for pen in pendulums:
		pen.tick(delta)
	for b in boulders:
		b.tick(delta)
	_prune_hazards()
	_tick_gusts(delta)
	_tick_wisps(delta)

	for i in players.size():
		if players[i].alive:
			pawns[i].tick_effects(delta)
			if _test_mode == "":
				_drive_pawn(i, delta)
		elif ghosts.has(i):
			_drive_ghost(i, delta)

	if _test_mode != "":
		_tick_test(delta)

	if phase != Phase.ROUND:
		return  # a death mid-loop flipped us into WILL
	if round_elapsed >= HARD_CAP:
		_end_round()

func _prune_hazards() -> void:
	for i in range(pendulums.size() - 1, -1, -1):
		if pendulums[i].is_done():
			pendulums[i].queue_free()
			pendulums.remove_at(i)
	for i in range(boulders.size() - 1, -1, -1):
		if boulders[i].is_done():
			boulders[i].queue_free()
			boulders.remove_at(i)

func _pulse_telegraph() -> void:
	if _tele_ring < 0:
		return
	var pulse := 0.5 + 0.5 * sin(round_elapsed * 10.0)
	for mat in _ring_mats[_tele_ring]:
		var m: StandardMaterial3D = mat
		m.emission_enabled = true
		m.emission = Color(1.0, 0.2, 0.12)
		m.emission_energy_multiplier = 0.9 * pulse

func _drive_pawn(i: int, delta: float) -> void:
	var pawn: LWPawn = pawns[i]
	if players[i].is_bot:
		var d: Dictionary = bots.decide_living(i, self, pawn, delta)
		pawn.move_input = d.move
		if d.a:
			pawn.want_shove = true
		if d.b:
			pawn.want_hop = true
	else:
		pawn.move_input = PlayerInput.get_move(i)
		if PlayerInput.just_pressed(i, "a"):
			pawn.want_shove = true
		if PlayerInput.just_pressed(i, "b"):
			pawn.want_hop = true

func _drive_ghost(i: int, delta: float) -> void:
	var g: LWGhostSeat = ghosts[i]
	g.tick_cooldown(delta)
	if players[i].is_bot:
		var d: Dictionary = bots.decide_ghost(i, self, g, delta)
		g.set_aim(d.aim)
		if d.fire and g.gust_ready():
			_fire_gust(i)
	else:
		# TWIN-STICK CONVENTION: aim the gust with the RIGHT channel — mouse cursor
		# (KBM) or right stick (pad). The ghost seat never moves, so the LEFT channel
		# is only the fallback when there is no aim device (keyboard halves) or the
		# right stick is idle.
		var aim3 := PlayerInput.get_aim_dir(i, g.global_position, cam)   # KBM cursor (world)
		var aim2 := Vector2(aim3.x, aim3.z)
		if aim2 == Vector2.ZERO:
			aim2 = PlayerInput.get_aim_stick(i)                         # pad right stick
		if aim2 == Vector2.ZERO:
			aim2 = PlayerInput.get_move(i)                              # fallback: LEFT channel
		g.set_aim(aim2)
		if PlayerInput.just_pressed(i, "a") and g.gust_ready():
			_fire_gust(i)

# ================================================================ gusts
func _fire_gust(i: int) -> void:
	var g: LWGhostSeat = ghosts[i]
	g.consume_gust()
	var dir3 := Vector3(g.aim_dir.x, 0, g.aim_dir.y)
	var start := g.global_position + dir3 * 0.8
	start.y = 0.7
	var node := _make_gust_node(players[i].color)
	spawn_root.add_child(node)
	node.global_position = start
	node.rotation.y = atan2(-dir3.x, -dir3.z)
	_gusts.append({"node": node, "pos": start, "dir": dir3, "traveled": 0.0,
		"hit": [], "from": i})
	Sfx.play("bounce", -7.0, 0.2)
	_tally_stats.gusts += 1
	print("LW_GUST from=%s t=%.1f" % [players[i].name, round_elapsed])

func _make_gust_node(c: Color) -> Node3D:
	var root := Node3D.new()
	var wave := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 0.8
	wave.mesh = sm
	wave.scale = Vector3(1.8, 0.5, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gc := c.lerp(Color(0.8, 0.95, 1.0), 0.6)
	mat.albedo_color = Color(gc.r, gc.g, gc.b, 0.34)
	mat.emission_enabled = true
	mat.emission = gc
	mat.emission_energy_multiplier = 0.9
	wave.material_override = mat
	root.add_child(wave)
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 0.5
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 40.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.4
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	var pm := SphereMesh.new()
	pm.radius = 0.06
	pm.height = 0.12
	p.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = Color(gc.r, gc.g, gc.b, 0.5)
	p.material_override = pmat
	p.emitting = true
	root.add_child(p)
	return root

func _tick_gusts(delta: float) -> void:
	for gi in range(_gusts.size() - 1, -1, -1):
		var g: Dictionary = _gusts[gi]
		var step: Vector3 = g.dir * GUST_SPEED * delta
		g.pos += step
		g.traveled += step.length()
		var node: Node3D = g.node
		node.global_position = g.pos
		var fade: float = 1.0 - float(g.traveled) / GUST_RANGE
		for c in node.get_children():
			if c is MeshInstance3D:
				var m: StandardMaterial3D = c.material_override
				m.albedo_color.a = 0.34 * fade
		for pawn in living_pawns():
			if g.hit.has(pawn.index):
				continue
			var d := Vector2(pawn.global_position.x - g.pos.x, pawn.global_position.z - g.pos.z).length()
			if d < GUST_HIT_R:
				g.hit.append(pawn.index)
				pawn.gust_push(g.dir, GUST_IMPULSE, int(g.from),
					players[g.from].name, players[g.from].color)
		if g.traveled >= GUST_RANGE:
			node.queue_free()
			_gusts.remove_at(gi)

func _tick_wisps(delta: float) -> void:
	for k in wisps.keys():
		var w: LWWisp = wisps[k]
		if not w.tick(delta):
			w.queue_free()
			wisps.erase(k)
			if k < pawns.size() and pawns[k].curse_kind == "haunted":
				pawns[k].clear_curse()

# ================================================================ self-tests
func _tick_test(_delta: float) -> void:
	_delta_cache = _delta
	match _test_mode:
		"squish":
			# a stationary pawn 0 must be flattened by a boulder aimed down
			# its row — proves the squish path end to end
			if not _test_fired and round_elapsed >= 1.0:
				_test_fired = true
				var b := LWBoulder.new()
				spawn_root.add_child(b)
				b.setup(0.0, pawns[0].global_position.z, self)
				boulders.append(b)
				print("WILLTEST squish: boulder launched at pawn0 z=%.2f" % pawns[0].global_position.z)
			if _test_fired and boulders.size() > 0 and int(round_elapsed * 2.0) != int((round_elapsed - _delta_cache) * 2.0):
				var rp: Vector3 = boulders[0].rock_pos()
				print("WILLTEST trace rock=(%.2f,%.2f,%.2f) state=%d pawn=(%.2f,%.2f,%.2f) grounded=%s" % [
					rp.x, rp.y, rp.z, boulders[0].state,
					pawns[0].global_position.x, pawns[0].global_position.y, pawns[0].global_position.z,
					str(pawns[0].is_grounded())])
			if round_elapsed > 12.0:
				print("WILLTEST squish RESULT: FAIL (pawn survived)")
				get_tree().quit(1)

func _test_note_death(cause: String) -> void:
	if _test_mode == "squish":
		if cause == "squish":
			print("WILLTEST squish RESULT: PASS (t=%.2f)" % round_elapsed)
			get_tree().quit(0)
		else:
			print("WILLTEST squish RESULT: FAIL (died of %s)" % cause)
			get_tree().quit(1)

# ================================================================ death
func _on_pawn_died(index: int, cause: String) -> void:
	if _test_mode != "":
		_test_note_death(cause)
		return
	if phase == Phase.MATCH_END or phase == Phase.ROUND_END:
		return
	players[index].alive = false
	players[index].deaths += 1
	_elim_order.append(index)
	_currency.append({"type": "grudge", "player": index, "amount": 1,
		"reason": "eliminated (%s)" % cause})
	if cause == "void":
		_tally_stats["void"] += 1
	else:
		_tally_stats["squish"] += 1

	# attribution for the banner + highlights
	var pawn: LWPawn = pawns[index]
	var line := "THE VOID CLAIMS %s" % players[index].name
	var lcolor := Color(0.65, 0.8, 1.0)
	var atk: Dictionary = pawn.last_attacker
	if cause == "squish":
		line = "THE BOULDER FLATTENS %s" % players[index].name
		lcolor = Color(0.85, 0.75, 0.6)
	elif atk.size() > 0 and (game_time - float(atk.get("time", -99.0))) <= 3.0:
		var ai := int(atk.get("index", -1))
		match str(atk.get("type", "")):
			"shove":
				if ai >= 0 and ai != index:
					line = "%s SHOVES %s INTO THE DUSK" % [players[ai].name, players[index].name]
					lcolor = players[ai].color
					_highlights.append("%s shoved %s into the dusk" % [players[ai].name, players[index].name])
			"gust":
				if ai >= 0 and ai != index:
					line = "%s'S GUST USHERS %s OFF THE EDGE" % [players[ai].name, players[index].name]
					lcolor = players[ai].color
					_highlights.append("%s, already dead, gusted %s into the void" % [players[ai].name, players[index].name])
			"pendulum":
				line = "THE PENDULUM SWATS %s AWAY" % players[index].name
				lcolor = Color(1.0, 0.5, 0.4)
	if pawn.curse_kind != "" and pawn.curse_from >= 0 and pawn.curse_from != index:
		_highlights.append("%s's curse dragged %s to the grave" % [players[pawn.curse_from].name, players[index].name])
	# Anthology kill ledger (reporting only; mirrors the banner attribution
	# above without altering it). killer -1 = environment/self.
	var kev_killer := -1
	var kev_cause := cause      # "void" | "squish"
	if cause != "squish" and atk.size() > 0 and (game_time - float(atk.get("time", -99.0))) <= 3.0:
		var kai := int(atk.get("index", -1))
		match str(atk.get("type", "")):
			"shove":
				if kai >= 0 and kai != index:
					kev_killer = kai
			"gust":
				if kai >= 0 and kai != index:
					kev_killer = kai
					kev_cause = "gust"
			"pendulum":
				kev_cause = "pendulum"
	_kill_events.append({"killer": kev_killer, "victim": index, "cause": kev_cause})
	print("LW_DEATH round=%d t=%.1f %s cause=%s" % [round_index + 1, round_elapsed, line, cause])

	# clear their outgoing wisp target state / incoming wisp
	if wisps.has(index):
		wisps[index].queue_free()
		wisps.erase(index)

	if not _tally:
		Sfx.play("splat")
		Sfx.play("death")
		_spawn_burst(pawn.global_position + Vector3(0, 0.4, 0), players[index].color, 30)
		_shake = maxf(_shake, 0.5)
		_time_hit(0.3, 0.38)
	_flash_banner(line, lcolor, 1.6)

	_will_queue.append(index)
	if phase == Phase.ROUND:
		phase = Phase.WILL
		_set_frozen(true)
		_begin_will(_will_queue.pop_front())

func _set_frozen(v: bool) -> void:
	for pawn in pawns:
		if pawn.alive:
			pawn.set_world_frozen(v)

# ================================================================ the will (THE SHOW)
func _begin_will(deceased: int) -> void:
	_will = {
		"player": deceased,
		"step": WStep.DEATH_BEAT,
		"t": 0.0,
		"clock": DRAFT_BUDGET,
		"cards": [],
		"sel": 0,
		"card": -1,
		"bless_target": -1,
		"curse_target": -1,
		"targets": [],
		"mode_sel": 0,
		"bot": players[deceased].is_bot,
		"bot_goal": -1,
		"bot_t": 0.0,
	}
	_nav_prev[deceased] = 0

func _will_step_time() -> float:
	return 0.14 if _tally else 0.55

func _tick_will(delta: float) -> void:
	if _will.is_empty():
		return
	_will.t += delta
	var p: int = _will.player
	var step: int = _will.step
	match step:
		WStep.DEATH_BEAT:
			if _will.t >= (0.25 if _tally else 1.35):
				var survivors := _alive_indices()
				if survivors.is_empty():
					print("LW_WILL %s: no heirs remain" % players[p].name)
					_flash_banner("NO HEIRS REMAIN", Color(0.7, 0.7, 0.8), 1.4)
					_will.step = WStep.CLOSING
					_will.t = 0.0
					return
				_ui.open(players[p].name, players[p].color, players[p].char_path)
				_set_base_ui(false)
				Sfx.play("grudge", 0.0, 0.03)
				if not _tally:
					var tw := create_tween()
					tw.tween_property(cam, "fov", _cam_base_fov - 6.0, 0.5).set_trans(Tween.TRANS_SINE)
				_will.step = WStep.REVEAL
				_will.t = 0.0
		WStep.REVEAL:
			if _will.t >= (0.2 if _tally else 1.0):
				_will.cards = _draw_cards()
				_ui.show_cards(_will.cards.map(func(c): return {
					"bless": {"kind": c.bless, "title": BLESS_DEFS[c.bless].title, "desc": BLESS_DEFS[c.bless].desc},
					"curse": {"kind": c.curse, "title": CURSE_DEFS[c.curse].title, "desc": CURSE_DEFS[c.curse].desc},
				}))
				_will.sel = 0
				_ui.set_card_sel(0)
				_will.step = WStep.CARDS
				_will.t = 0.0
				_will.clock = DRAFT_BUDGET
				_will.bot_goal = bots.draft_card(p, self, _will.cards) if _will.bot else -1
				_will.bot_t = 0.0
		WStep.CARDS:
			_will.clock -= delta
			_ui.set_timer(_will.clock / DRAFT_BUDGET, _will.clock)
			if _will.clock <= 0.0:
				_auto_resolve()
				return
			var nav := 0
			var confirm := false
			if _will.bot:
				_will.bot_t += delta
				if _will.bot_t >= _will_step_time():
					_will.bot_t = 0.0
					if _will.sel != _will.bot_goal:
						nav = 1 if _will.bot_goal > _will.sel else -1
					else:
						confirm = true
			else:
				nav = _nav_dir(p)
				confirm = PlayerInput.just_pressed(p, "a")
			if nav != 0:
				_will.sel = wrapi(_will.sel + nav, 0, _will.cards.size())
				_ui.set_card_sel(_will.sel)
				Sfx.play("card", -4.0)
			if confirm:
				_will.card = _will.sel
				_ui.lock_card(_will.sel)
				Sfx.play("confirm", -2.0)
				var survivors := _alive_indices()
				if survivors.size() == 1:
					var c: Dictionary = _will.cards[_will.card]
					_ui.show_mode_choice(str(BLESS_DEFS[c.bless].banner), str(CURSE_DEFS[c.curse].banner),
						players[survivors[0]].name, players[survivors[0]].color)
					_will.mode_sel = 0
					_ui.set_mode_sel(0)
					_will.step = WStep.MODE
					_will.bot_goal = (0 if bots.draft_mode(p, self, survivors[0]) == "bless" else 1) if _will.bot else -1
					_point_hand_at(survivors[0])
				else:
					_enter_target_step(WStep.BLESS_T, survivors)
				_will.t = 0.0
				_will.bot_t = 0.0
		WStep.BLESS_T, WStep.CURSE_T:
			_will.clock -= delta
			_ui.set_timer(_will.clock / DRAFT_BUDGET, _will.clock)
			if _will.clock <= 0.0:
				_auto_resolve()
				return
			var nav2 := 0
			var confirm2 := false
			if _will.bot:
				_will.bot_t += delta
				if _will.bot_t >= _will_step_time():
					_will.bot_t = 0.0
					if _will.sel != _will.bot_goal:
						nav2 = 1
					else:
						confirm2 = true
			else:
				nav2 = _nav_dir(p)
				confirm2 = PlayerInput.just_pressed(p, "a")
			var targets: Array = _will.targets
			if nav2 != 0:
				_will.sel = wrapi(_will.sel + nav2, 0, targets.size())
				_show_target(targets[_will.sel])
				Sfx.play("card", -4.0)
			if confirm2:
				var chosen: int = targets[_will.sel]
				Sfx.play("confirm", -2.0)
				if step == WStep.BLESS_T:
					_will.bless_target = chosen
					var survivors2: Array = _alive_indices().filter(func(s): return s != chosen)
					if survivors2.is_empty():
						_go_resolution()
					else:
						_enter_target_step(WStep.CURSE_T, survivors2)
				else:
					_will.curse_target = chosen
					_go_resolution()
		WStep.MODE:
			_will.clock -= delta
			_ui.set_timer(_will.clock / DRAFT_BUDGET, _will.clock)
			if _will.clock <= 0.0:
				_auto_resolve()
				return
			var nav3 := 0
			var confirm3 := false
			if _will.bot:
				_will.bot_t += delta
				if _will.bot_t >= _will_step_time():
					_will.bot_t = 0.0
					if _will.mode_sel != _will.bot_goal:
						nav3 = 1
					else:
						confirm3 = true
			else:
				nav3 = _nav_dir(p)
				confirm3 = PlayerInput.just_pressed(p, "a")
			if nav3 != 0:
				_will.mode_sel = wrapi(_will.mode_sel + nav3, 0, 2)
				_ui.set_mode_sel(_will.mode_sel)
				Sfx.play("card", -4.0)
			if confirm3:
				var survivor: int = _alive_indices()[0]
				if _will.mode_sel == 0:
					_will.bless_target = survivor
				else:
					_will.curse_target = survivor
				Sfx.play("confirm", -2.0)
				_go_resolution()
		WStep.RESOLUTION:
			if _will.t >= (0.3 if _tally else 2.3):
				_will.step = WStep.CLOSING
				_will.t = 0.0
				_ui.close()
				_hand.visible = false
				_target_ring.visible = false
				if not _tally:
					var tw := create_tween()
					tw.tween_property(cam, "fov", _cam_base_fov, 0.4).set_trans(Tween.TRANS_SINE)
		WStep.CLOSING:
			if _will.t >= (0.1 if _tally else 0.5):
				_set_base_ui(true)
				_seat_ghost(p)
				_will = {}
				if not _will_queue.is_empty():
					_begin_will(_will_queue.pop_front())
					return
				if _alive_indices().size() <= 1:
					_end_round()
				else:
					phase = Phase.ROUND
					_set_frozen(false)

func _enter_target_step(step: int, targets: Array) -> void:
	_will.step = step
	_will.targets = targets
	_will.sel = 0
	_will.t = 0.0
	_will.bot_t = 0.0
	if _will.bot:
		var want: int = bots.draft_bless_target(_will.player, self, targets) if step == WStep.BLESS_T \
			else bots.draft_curse_target(_will.player, self, targets)
		_will.bot_goal = targets.find(want)
		if _will.bot_goal < 0:
			_will.bot_goal = 0
	_ui.show_target_prompt("bless" if step == WStep.BLESS_T else "curse")
	_show_target(targets[0])

func _show_target(idx: int) -> void:
	_ui.set_target_display(players[idx].name, players[idx].color)
	_point_hand_at(idx)

func _point_hand_at(idx: int) -> void:
	var pawn: LWPawn = pawns[idx]
	_hand.visible = true
	# hover just over the head, biased toward the camera so the finger
	# reads instead of hiding behind the target-name label
	_hand.global_position = pawn.global_position + Vector3(0, 2.25, 0.55)
	_target_ring.visible = true
	_target_ring.global_position = Vector3(pawn.global_position.x, 0.1, pawn.global_position.z)
	var mat: StandardMaterial3D = _target_ring.material_override
	var dc: Color = players[_will.player].color
	mat.albedo_color = Color(dc.r, dc.g, dc.b, 0.85)
	mat.emission = dc

func _draw_cards() -> Array:
	var blesses := ["shield", "swift", "coin"]
	var curses := ["sluggish", "butterfingers", "haunted"]
	# seeded shuffles; pairing varies, but every draft shows all six effects
	for i in range(blesses.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = blesses[i]; blesses[i] = blesses[j]; blesses[j] = tmp
	for i in range(curses.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp2: String = curses[i]; curses[i] = curses[j]; curses[j] = tmp2
	var cards: Array = []
	for i in 3:
		cards.append({"bless": blesses[i], "curse": curses[i]})
	return cards

func _auto_resolve() -> void:
	## 6 seconds are up: whatever the hand hovers, the will takes.
	var survivors := _alive_indices()
	if _will.card < 0:
		_will.card = _will.sel if _will.step == WStep.CARDS else 0
	if survivors.size() == 1:
		if _will.bless_target < 0 and _will.curse_target < 0:
			if _will.step == WStep.MODE and _will.mode_sel == 1:
				_will.curse_target = survivors[0]
			else:
				_will.bless_target = survivors[0]
	else:
		if _will.bless_target < 0:
			var t: Array = _will.targets if _will.step == WStep.BLESS_T else survivors
			_will.bless_target = t[_will.sel] if _will.step == WStep.BLESS_T else t[0]
		if _will.curse_target < 0:
			var rest: Array = survivors.filter(func(s): return s != _will.bless_target)
			if not rest.is_empty():
				if _will.step == WStep.CURSE_T:
					_will.curse_target = _will.targets[_will.sel]
				else:
					_will.curse_target = rest[0]
	_go_resolution()

func _go_resolution() -> void:
	var p: int = _will.player
	var card: Dictionary = _will.cards[_will.card] if _will.card >= 0 and _will.card < _will.cards.size() \
		else {"bless": "coin", "curse": "sluggish"}
	var round_over := _alive_indices().size() <= 1
	var lines: Array = []
	var delay := 0.0

	if _will.bless_target >= 0:
		var bt: int = _will.bless_target
		var b := str(card.bless)
		lines.append({"text": "%s BLESSES %s — %s" % [players[p].name, players[bt].name,
			BLESS_DEFS[b].banner], "color": LWWillUI.GOLD, "delay": delay})
		delay += 0.7
		if b == "coin":
			players[bt].total += 1
			if not round_over:
				_register_claim(p, bt, round_index)
			elif round_index + 1 < rounds_total:
				_register_claim(p, bt, round_index + 1)
			# (final round + round over: coin pays, but no puppetmaster claim —
			# blessing a champion who has already won is not kingmaking)
			_spawn_coin_pop(bt)
		elif round_over:
			if round_index + 1 < rounds_total:
				_carry.append({"kind": "bless", "effect": b, "from": p, "target": bt})
			# else: the match ends here; the timed blessing fades unspent
		else:
			_apply_bless_effect(b, p, bt)
			_register_claim(p, bt, round_index)
		var b_stored := round_over and b != "coin" and round_index + 1 < rounds_total
		print("LW_WILL %s blesses %s with %s%s" % [players[p].name, players[bt].name, b,
			" (carry)" if b_stored else (" (fades: match over)" if round_over and b != "coin" else "")])

	if _will.curse_target >= 0:
		var ct: int = _will.curse_target
		var c := str(card.curse)
		lines.append({"text": "...AND CURSES %s — %s" % [players[ct].name,
			CURSE_DEFS[c].banner], "color": LWWillUI.GREEN, "delay": delay})
		if round_over:
			if round_index + 1 < rounds_total:
				_carry.append({"kind": "curse", "effect": c, "from": p, "target": ct})
		else:
			_apply_curse_effect(c, p, ct)
		var c_stored := round_over and round_index + 1 < rounds_total
		print("LW_WILL %s curses %s with %s%s" % [players[p].name, players[ct].name, c,
			" (carry)" if c_stored else (" (fades: match over)" if round_over else "")])

	_tally_stats.wills += 1
	_ui.show_resolution(lines)
	Sfx.play("grudge", -1.0)
	_hand.visible = false
	_target_ring.visible = false
	_rebuild_scoreboard()
	_will.step = WStep.RESOLUTION
	_will.t = 0.0

func _apply_bless_effect(kind: String, from: int, target: int) -> void:
	var pawn: LWPawn = pawns[target]
	# cap: one active blessing — apply_bless overwrites (newest replaces)
	pawn.apply_bless(kind, from, float(BLESS_DEFS[kind].dur))
	if not _tally:
		Sfx.play("sink", -4.0)

func _apply_curse_effect(kind: String, from: int, target: int) -> void:
	var pawn: LWPawn = pawns[target]
	# cap: one active curse — clear any live wisp before the newest replaces
	if pawn.curse_kind == "haunted" and wisps.has(target):
		wisps[target].queue_free()
		wisps.erase(target)
	pawn.apply_curse(kind, from, float(CURSE_DEFS[kind].dur))
	if kind == "haunted":
		var w := LWWisp.new()
		spawn_root.add_child(w)
		var edge := pawn.global_position + Vector3(2.5, 0, 2.5)
		w.setup(target, float(CURSE_DEFS[kind].dur), edge, self)
		wisps[target] = w
	if not _tally:
		Sfx.play("grudge", -6.0)

func _register_claim(from: int, target: int, for_round: int) -> void:
	_claims.append({"from": from, "target": target, "round": for_round})

func _spawn_coin_pop(target: int) -> void:
	if _tally:
		return
	var pawn: LWPawn = pawns[target]
	_spawn_burst(pawn.global_position + Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.3), 20)
	Sfx.play("sink", -2.0)

const SEAT_ANGLES := [0.15, PI - 0.15, 4.25, 5.25]  # east, west, NW, NE —
	# all inside the camera frame (the south wedge is clipped at 720p)

func _seat_ghost(i: int) -> void:
	if ghosts.has(i):
		return
	var g := LWGhostSeat.new()
	g.name = "Ghost%d" % i
	spawn_root.add_child(g)
	var seat_angle: float = SEAT_ANGLES[i % SEAT_ANGLES.size()]
	g.setup(i, players[i].color, players[i].name, load(players[i].char_path), seat_angle, self)
	ghosts[i] = g
	_refresh_hint()
	if not _tally:
		Sfx.play("grudge", -10.0, 0.2)

# ================================================================ round end
func _end_round() -> void:
	phase = Phase.ROUND_END
	_re_t = 0.0
	_re_events.clear()
	_clear_hazards()   # the yard goes quiet for the ceremony
	for pawn in pawns:
		if pawn.alive:
			pawn.move_input = Vector2.ZERO
			pawn.want_shove = false
			pawn.want_hop = false
			pawn.set_world_frozen(true)

	var survivors: Array = _alive_indices()
	# multi-survivor timeout: closest to the pillar's heart wins (earned
	# position, not player index)
	survivors.sort_custom(func(a, b):
		var da := Vector2(pawns[a].global_position.x, pawns[a].global_position.z).length()
		var db := Vector2(pawns[b].global_position.x, pawns[b].global_position.z).length()
		if absf(da - db) > 0.01:
			return da < db
		return a < b)
	var finishing: Array = survivors.duplicate()
	var dead_desc := _elim_order.duplicate()
	dead_desc.reverse()
	finishing.append_array(dead_desc)
	var pts := _points_table()
	for pos in finishing.size():
		if pos < pts.size():
			players[finishing[pos]].total += pts[pos]
	var winner: int = finishing[0] if finishing.size() > 0 else 0

	var champ_name: String = players[winner].name
	var champ_color: Color = players[winner].color
	if survivors.is_empty():
		champ_name = "NOBODY"
		champ_color = Color(0.7, 0.7, 0.8)
	print("LW_ROUND_END %d winner=%s survivors=%d elims=%d" % [round_index + 1,
		champ_name, survivors.size(), _elim_order.size()])
	if not _tally:
		Sfx.play("round_over")
	_flash_banner("%s SURVIVES ROUND %d" % [champ_name, round_index + 1], champ_color, 2.4)

	# puppetmaster: claims on THIS round whose champion delivered
	var delay := 1.6
	for cl in _claims:
		if int(cl.round) != round_index:
			continue
		if int(cl.target) != winner or int(cl.from) == winner or survivors.is_empty():
			continue
		var from: int = int(cl.from)
		players[from].total += ROYALTY
		players[from].puppet += 1
		_tally_stats.puppets += 1
		_currency.append({"type": "royalty", "player": from, "amount": ROYALTY,
			"reason": "the dead hand moves the world"})
		_highlights.append("%s backed %s from beyond the grave — %s delivered" %
			[players[from].name, players[winner].name, players[winner].name])
		print("LW_PUPPETMASTER %s +2 (blessed %s)" % [players[from].name, players[winner].name])
		var fname: String = players[from].name
		var fcolor: Color = players[from].color
		_re_events.append({"t": delay, "fn": Callable(self, "_puppet_banner").bind(fname, fcolor)})
		delay += 1.7
	_re_done_t = delay + (0.4 if _tally else 1.2)
	_rebuild_scoreboard()

func _puppet_banner(fname: String, fcolor: Color) -> void:
	_flash_banner("THE DEAD HAND MOVES THE WORLD\n%s +2" % fname, fcolor, 1.8)
	if not _tally:
		Sfx.play("match_win", -6.0)

func _tick_round_end(delta: float) -> void:
	_re_t += delta
	for ev in _re_events:
		if not ev.get("done", false) and _re_t >= float(ev.t):
			ev["done"] = true
			(ev.fn as Callable).call()
	if _re_t >= _re_done_t:
		round_index += 1
		if round_index >= rounds_total:
			_finish_match()
		else:
			_start_round()

func _points_table() -> Array:
	match players.size():
		2: return [3, 0]
		3: return [4, 2, 1]
		_: return [4, 2, 1, 0]

# ================================================================ match end
func _finish_match() -> void:
	phase = Phase.MATCH_END
	_tally_stats.rounds = rounds_total
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if players[a].total != players[b].total:
			return players[a].total > players[b].total
		return a < b)
	var champ: int = order[0]
	var points := {}
	for i in players.size():
		points[i] = players[i].total
	var monuments: Array = []
	for i in players.size():
		if players[i].puppet >= 2:
			monuments.append({"player": i, "kind": "kingmaker",
				"label": "%s, Kingmaker from the Grave" % players[i].name})
	var results := {
		"placements": order,
		"points": points,
		"currency_events": _currency.duplicate(),
		"kill_events": _kill_events.duplicate(),
		"highlights": _dedup(_highlights).slice(0, 3),
		"monuments": monuments,
	}
	print("KILL_EVENTS n=", _kill_events.size(), " ", _kill_events)
	print("LW_MATCH_OVER champ=%s pts=%d" % [players[champ].name, players[champ].total])
	print("LW_RESULTS ", JSON.stringify(results))
	if _tally:
		_print_tally()
		get_tree().quit()
		return
	_flash_banner("%s WINS LAST WILL" % players[champ].name, players[champ].color, 6.0)
	Sfx.play("match_win")
	_spawn_confetti(pawns[champ].global_position + Vector3(0, 1.2, 0), players[champ].color)
	report_finished(results)

func _print_tally() -> void:
	var wpr := float(_tally_stats.wills) / float(maxi(1, rounds_total))
	print("======== LAST WILL TALLY ========")
	print("WILL_TALLY seed=%d rounds=%d wills=%d wills_per_round=%.2f" % [
		rng.seed, rounds_total, _tally_stats.wills, wpr])
	print("deaths: void=%d squish=%d | gusts=%d puppet_bonuses=%d carryovers=%d" % [
		_tally_stats["void"], _tally_stats["squish"], _tally_stats["gusts"],
		_tally_stats["puppets"], _tally_stats["carries"]])
	var bits: Array = []
	for i in players.size():
		bits.append("%s=%d" % [players[i].name, players[i].total])
	print("totals: %s" % " ".join(bits))
	print("TALLY_RESULT %s (target >=2 wills/round avg across seeds)" % ("PASS" if wpr >= 2.0 else "CHECK"))
	print("=================================")

func _dedup(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		if not out.has(x):
			out.append(x)
	return out

# ================================================================ queries (bots/hazards)
func living_pawns() -> Array:
	var out: Array = []
	for pawn in pawns:
		if pawn.alive:
			out.append(pawn)
	return out

func pawn_of(i: int):
	if i >= 0 and i < pawns.size() and pawns[i].alive:
		return pawns[i]
	return null

func player_name(i: int) -> String:
	return players[i].name if i >= 0 and i < players.size() else "???"

func _alive_indices() -> Array:
	var out: Array = []
	for i in players.size():
		if players[i].alive:
			out.append(i)
	return out

func round_leader_alive() -> int:
	var best := -1
	for i in players.size():
		if not players[i].alive:
			continue
		if best < 0 or players[i].total > players[best].total:
			best = i
	return best

func wisp_pos_for(i: int):
	if wisps.has(i):
		return wisps[i].global_position
	return null

func on_shove_landed(_pos: Vector3) -> void:
	_shake = maxf(_shake, 0.26)
	if not _tally:
		_time_hit(0.001, 0.05)

## Readability cue fired the instant a shove releases (hit OR whiff): a bright
## windup ring + a directional arc filling the shove's front-hemisphere reach, in
## the shover's color. Presentation only — spawns nothing physical, samples no RNG,
## and is skipped entirely in the headless tally, so determinism is untouched.
func on_shove_fired(pos: Vector3, dir: Vector3, col: Color) -> void:
	if _tally:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3(0, 0, 1)
	flat = flat.normalized()
	var root := Node3D.new()
	spawn_root.add_child(root)
	root.global_position = pos + Vector3(0, 0.12, 0)
	root.rotation.y = atan2(flat.x, flat.z)   # local +Z -> shove direction
	var gc := col.lerp(Color(1, 1, 1), 0.35)
	# directional arc — WHERE the shove reaches (front hemisphere to SHOVE_RANGE)
	var arc := MeshInstance3D.new()
	arc.mesh = _shove_arc_mesh(LWPawn.SHOVE_RANGE)
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.albedo_color = Color(gc.r, gc.g, gc.b, 0.5)
	am.emission_enabled = true
	am.emission = gc
	am.emission_energy_multiplier = 2.0
	arc.material_override = am
	arc.scale = Vector3(0.55, 1.0, 0.55)
	root.add_child(arc)
	# windup/impact ring — WHEN it fires (a bright pop at the shover's feet)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.5
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.9)
	rm.emission_enabled = true
	rm.emission = gc
	rm.emission_energy_multiplier = 3.0
	ring.material_override = rm
	ring.rotation.x = PI / 2.0
	root.add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "scale", Vector3(1.05, 1.0, 1.05), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(am, "albedo_color:a", 0.0, 0.28)
	tw.tween_property(ring, "scale", Vector3(2.2, 2.2, 2.2), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(root.queue_free)
	# verification: snap the very first shove's arc mid-expansion, then quit
	if _shove_cue_probe and not _shove_cue_done:
		_shove_cue_done = true
		_snap_shove_cue()

func _snap_shove_cue() -> void:
	await get_tree().create_timer(0.07).timeout   # let the arc bloom
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://verify_out/lw_shove_cue.png")
	print("LW_SHOVE_CUE_SNAP res://verify_out/lw_shove_cue.png")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## Filled front-arc (annular sector, ~160°) opening along local +Z, radius r.
func _shove_arc_mesh(r: float) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(80.0)
	var steps := 16
	var inner := 0.26
	for s in steps:
		var a0 := lerpf(-half, half, s / float(steps))
		var a1 := lerpf(-half, half, (s + 1) / float(steps))
		var i0 := Vector3(sin(a0) * inner, 0.0, cos(a0) * inner)
		var i1 := Vector3(sin(a1) * inner, 0.0, cos(a1) * inner)
		var o0 := Vector3(sin(a0) * r, 0.0, cos(a0) * r)
		var o1 := Vector3(sin(a1) * r, 0.0, cos(a1) * r)
		im.surface_add_vertex(i0)
		im.surface_add_vertex(o0)
		im.surface_add_vertex(o1)
		im.surface_add_vertex(i0)
		im.surface_add_vertex(o1)
		im.surface_add_vertex(i1)
	im.surface_end()
	return im

func on_boulder_contact(pawn: LWPawn) -> void:
	if phase != Phase.ROUND:
		return
	if not _tally:
		Sfx.play("crush", -2.0)
	pawn.squish()

func on_pendulum_hit(_i: int) -> void:
	_shake = maxf(_shake, 0.4)
	if not _tally:
		Sfx.play("bumper", -2.0)

func on_shield_break(i: int) -> void:
	_flash_sub("%s'S SHIELD SHATTERS!" % players[i].name, Color(1.0, 0.85, 0.4), 1.4)
	print("LW_SHIELD_BREAK %s" % players[i].name)

func on_wisp_contact(i: int) -> void:
	if not _tally:
		_flash_sub("THE WISP CATCHES %s" % players[i].name, Color(0.6, 1.0, 0.6), 1.2)

func _set_base_ui(v: bool) -> void:
	round_label.visible = v
	timer_label.visible = v
	hint_label.visible = v
	$UI/ScorePanel.visible = v

const HINT_LIVING := "A = SHOVE   B = HOP   ·   DIE, AND DRAFT YOUR WILL"

## Flip the shared hint bar to a dead-state legend when a HUMAN takes a ghost pew,
## so the dead know how to gust: aim with the RIGHT channel, A fires. Bots never
## trigger this (their seats stay HINT_LIVING), so the tally screenshots are
## unchanged.
func _refresh_hint() -> void:
	if hint_label == null:
		return
	var dead_humans: Array = []
	for i in players.size():
		if not players[i].is_bot and ghosts.has(i):
			dead_humans.append(i)
	if dead_humans.is_empty():
		hint_label.text = HINT_LIVING
	elif dead_humans.size() == 1:
		hint_label.text = _ghost_hint_line(int(dead_humans[0]))
	else:
		hint_label.text = "YOU'RE DEAD — AIM the gust (RIGHT) · A = GUST the living (every %ds)" % int(LWGhostSeat.GUST_COOLDOWN)

func _ghost_hint_line(i: int) -> String:
	var d: int = PlayerInput.device_of(i)
	var fire: String = PlayerInput.describe_binding(i, "a")
	var aim := "MOUSE"
	if d >= 0:
		aim = "RIGHT STICK"
	elif d != -4:
		aim = PlayerInput.describe_binding(i, "move")   # keyboard halves aim with their move keys
	return "%s IS DEAD — %s aim the gust · %s = GUST (every %ds)" % [players[i].name, aim, fire, int(LWGhostSeat.GUST_COOLDOWN)]

# ================================================================ input helpers
func _nav_dir(p: int) -> int:
	var x := PlayerInput.get_move(p).x
	var s := 0
	if x > 0.5:
		s = 1
	elif x < -0.5:
		s = -1
	var prev: int = _nav_prev.get(p, 0)
	_nav_prev[p] = s
	if s != 0 and s != prev:
		return s
	return 0

# ================================================================ fx / ui
func _time_hit(scale: float, real_duration: float) -> void:
	_time_token += 1
	var my := _time_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_duration, true, false, true).timeout
	if my == _time_token:
		Engine.time_scale = 1.0

func _update_timer_label() -> void:
	var remaining := ROUND_TIME - round_elapsed
	if remaining >= 0.0:
		timer_label.text = "%02d" % int(ceil(remaining))
		timer_label.add_theme_color_override("font_color", Color(0.85, 0.97, 1))
	else:
		timer_label.text = "SUDDEN DEATH"
		var pulse := 0.6 + 0.4 * sin(round_elapsed * 8.0)
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.3 * pulse + 0.15, 0.2))

func _flash_banner(text: String, color: Color, duration: float) -> void:
	if _tally:
		return
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_token += 1
	var my := _banner_token
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		# a newer banner owns the label now — never hide someone else's line
		tw.tween_callback(Callable(self, "_hide_banner_if").bind(my))

func _hide_banner_if(token: int) -> void:
	if token == _banner_token:
		banner.visible = false

func _hide_sub_if(token: int) -> void:
	if token == _sub_token:
		sub_banner.visible = false

func _flash_sub(text: String, color: Color, duration: float) -> void:
	if _tally:
		return
	sub_banner.text = text
	sub_banner.add_theme_color_override("font_color", color)
	sub_banner.visible = true
	_sub_token += 1
	var my := _sub_token
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(Callable(self, "_hide_sub_if").bind(my))

func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if players[a].total != players[b].total:
			return players[a].total > players[b].total
		return a < b)
	for i in order:
		var p: Dictionary = players[i]
		var tags := ""
		if not p.alive:
			tags += "  †"
		if i < pawns.size() and pawns[i].alive:
			if pawns[i].bless_kind != "":
				tags += "  +"
			if pawns[i].curse_kind != "":
				tags += "  −"
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(i, 24)
		badge.color = p.color
		if not p.alive:
			badge.dim = 0.45
		hb.add_child(badge)
		var row := Label.new()
		row.text = "%s  %d%s" % [p.name, p.total, tags]
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", p.color)
		row.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.1))
		row.add_theme_constant_override("outline_size", 5)
		hb.add_child(row)
		score_rows.add_child(hb)

func _spawn_burst(pos: Vector3, color: Color, amount: int) -> void:
	if _tally:
		return
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _spawn_confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 18
		p.lifetime = 1.2
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.5
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
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)

# ================================================================ verify hooks
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.ROUND

func debug_force_kill(p: int) -> void:
	if p >= 0 and p < pawns.size() and pawns[p].alive and phase == Phase.ROUND:
		pawns[p]._die("void")
