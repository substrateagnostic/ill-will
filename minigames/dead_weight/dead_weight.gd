extends Minigame
## DEAD WEIGHT — a sumo brawl in a cozy attic where the knocked-out become
## POLTERGEISTS who possess the furniture and hurl it at the living.
## Extends the anthology Minigame contract: begin(config) -> finished(results).
## Also self-starts standalone (0.5s after _ready) with a default 4-player
## config so the scene runs on its own for testing.

enum Phase { PRE, ROUND, BETWEEN, DONE }

const CHAR_SCENES := [
	preload("res://assets/models/kaykit/Barbarian.glb"),
	preload("res://assets/models/kaykit/Knight.glb"),
	preload("res://assets/models/kaykit/Mage.glb"),
	preload("res://assets/models/kaykit/Rogue.glb"),
]

const ROUND_TIME := 75.0
const HOUSE_AWAKENS_WINDOW := 30.0   # final stretch (doc 09 §8.3, Alex-signed):
                                     # ghost possess-cooldowns halve + the room
                                     # dims to candlelight — the dead get lively
                                     # exactly when the living are winning
const KILL_CREDIT_WINDOW := 4.0      # safety cap; recovery-clear is the real gate
const SPAWN_LOCK_TIME := 3.0         # props near spawns unpossessable this long
const SPAWN_LOCK_RADIUS := 2.0
const POINTS_TABLE := [4, 2, 1, 0]
const ROYALTY := 2
const FLOOR_HALF := 6.0

# prop layout: tier + grid-ish scatter (deterministic, jittered by rng)
const PROP_TIERS := ["wardrobe", "crate", "lamp", "chair", "crate", "lamp",
	"wardrobe", "chair", "crate", "lamp", "chair", "crate"]

var game_time := 0.0
var phase := Phase.PRE
var rng := RandomNumberGenerator.new()

var players: Array = []               # per-player match state dicts
var _fighters: Array = []             # index -> DWFighter or null (ghost-start)
var _ghosts: Dictionary = {}          # index -> DWGhost (dead this round)
var _props: Array = []                # Array[DWProp]
var _spawns: Array = []               # Array[Vector3] revival points
var _elim_order: Array = []           # indices in death order this round
var _currency_log: Array = []
var _kill_events: Array = []          # {killer:int, victim:int, cause:String}; killer -1 = void
var _highlights: Array = []
var _last_kill_line := ""             # the kill that ended the round, if any
var _last_kill_color := Color.WHITE

var round_index := 0                  # 0-based
var rounds_total := 3
var round_elapsed := 0.0
var _between_timer := 0.0             # counts down to the next round start
var _round_resolving := false
var _decider := "none"                # what ended the round (balance metric)
var _house_awake := false             # final-stretch ghost buff live this round
# THE FINAL STRETCH kit (doc 09 §Q1): THE HOUSE AWAKENS is dead weight's
# stretch — the kit adds music (light->tense at the awakening) + last-10s
# ticks + timer pulse around the bespoke banner/candlelight dim. Gated on
# fx_on() so --dwbalance receipts never construct it.
var _stretch: FinalStretch = null
var _awaken_override := -1.0          # --dwawaken=S (verify): film the moment early
var _evict_pin := -1                  # --dwevict=N (evidence pin, --seancechar
                                      # precedent): fell seat N through the REAL
                                      # _fall() path 1 s into round 1 so a probe
                                      # night is GUARANTEED a poltergeist + a
                                      # furniture assault on film. Logged loud;
                                      # never set in real play.
var _env: Environment = null          # stage refs for the candlelight dim (fx)
var _sun: DirectionalLight3D = null
var _base_ambient := 0.44             # EnvKit CANDLELIT base — THE HOUSE AWAKENS
var _base_sun := 1.05                 # dims RELATIVE to these, restores TO them
var _dim_tw: Tween = null
var _candle_root: Node3D = null
var _candle_lights: Array = []

# modes
var _started := false
var _all_bots := false
var _aim_probe_on := false
var _dead_hint_demo := false     # --deadhint: seat 0 = KBM human, starts as a ghost
var _aim_probe_deg := 0.0
var _probe_shove := false        # false => poltergeist fling probe, true => living shove
var _dw_probe_manual := false    # skip driving p0 (fling probe steers it directly)
var _balance_rounds := 0
var _balance_tally := {"living": 0, "ghost": 0, "void": 0}
var _dbg := {"possess": 0, "ghost_hits": 0, "round_len": 0.0}
var _ghost_hold: Dictionary = {}      # ghost bot possession dwell timers

# fx
var _shake := 0.0
var _time_token := 0
var _last_hitstop := -99.0       # HIT KIT global one-at-a-time hitstop throttle (0.14s)
var _hitkit_cap := false         # --hitkitcap: stage the HIT KIT / cooldown-ring shots
var _cap_dir := "verify_out/hitkit"
var _banner_col := "ffffff"      # last banner color (mirrored as html)

# ONLINE PHASE 2 (docs/design/10 §4.3) — the render mirror, house pattern per
# docs/verify/online-seance-VERIFY.md. Host runs the WHOLE sim (Jolt included)
# exactly as couch; the estate pumps _net_state() at 20 Hz; the client boots
# this same scene with config.net_mirror = true, freezes every body, and
# _net_apply()/_mirror_tick() puppet the fighters, wisps and FURNITURE from
# snapshots — the armchair lunge is a streamed transform, the possession glow,
# wobble and all impact juice fire locally from state deltas. Reduced-motion
# (shake/hitstop) honors the CLIENT's own pref on every mirrored beat.
const NET_ANIMS := ["Idle", "Running_A", "Hit_A", "Jump_Idle", "Interact", "Jump_Start"]
var _mirror := false
var _mir := {}                   # last applied snapshot (delta source for juice)
var _mir_snaps := {}             # evidence snapshots fired once (probe runs)
var _mir_done := false           # champion confetti fired
var _net_ghost_hits := 0         # possessed-prop slams (host counter -> mirror juice)
var _net_champ := -1

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var banner: Label = $UI/Banner
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows
@onready var spawn_root: Node3D = $SpawnRoot

func _ready() -> void:
	_parse_args()
	_build_stage()
	banner.visible = false
	await get_tree().create_timer(0.5).timeout
	if not _started:
		_begin(_default_config())

# ---------------------------------------------------------------- stage
func _build_stage() -> void:
	# THE HOUSE LOOK — CANDLELIT attic (core/env_kit.gd). A warm amber key rakes
	# the diorama for deep shadow falloff, strong SSAO grounds the furniture, and
	# dust motes drift in the still air. The base state is already candlelit; THE
	# HOUSE AWAKENS (_dim_to_candlelight) drops it FURTHER and guts four corner
	# candles to life. Keep refs to the env + key so that dim can tween them.
	var rig := EnvKit.apply(self, EnvKit.CANDLELIT, {
		"key_angle": Vector3(-56.0, -34.0, 0.0),   # keep the old sun's shadow direction
		"key_energy": 1.05,
		"ambient_energy": 0.44,
	})
	_env = rig["environment"]
	_sun = rig["key"]
	_base_ambient = _env.ambient_light_energy
	_base_sun = _sun.light_energy
	# slow dust motes over the play slab (fx-cheap; ~46 additive particles)
	EnvKit.add_dust_motes(self, Vector3(12, 5, 12), Vector3(0, 4.4, 0))

	cam.global_position = Vector3(0, 13.5, 11.5)
	cam.look_at(Vector3(0, 0.3, -0.4), Vector3.UP)
	cam.fov = 52.0

	# floor: 12x12 platform with nothing beyond the lip — walk off, you fall
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	$Arena.add_child(floor_body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# a thick slab (top at y=0) so nothing can be shoved down through it —
	# only walking off the ±6 edge drops you into the void
	bs.size = Vector3(12.0, 3.0, 12.0)
	cs.shape = bs
	cs.position = Vector3(0, -1.5, 0)
	floor_body.add_child(cs)
	var fm := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(12.0, 3.0, 12.0)
	fm.mesh = fmesh
	fm.position = Vector3(0, -1.5, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.36, 0.26, 0.19)
	fmat.roughness = 0.85
	fm.material_override = fmat
	floor_body.add_child(fm)

	# a warm rug so the middle reads "cozy attic", not "arena"
	var rug := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(6.5, 0.02, 6.5)
	rug.mesh = rmesh
	rug.position = Vector3(0, 0.011, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.5, 0.22, 0.24)
	rmat.roughness = 0.9
	rug.material_override = rmat
	$Arena.add_child(rug)

	_build_surround()
	_build_void_ring()

func _build_surround() -> void:
	# The diorama sits on a warm table in a warm room instead of floating in a
	# void. Purely decorative (no collision), placed BELOW / INSIDE the ±6 lip so
	# gameplay dimensions are untouched — a shoved fighter still falls clear of it
	# into the drop. This is what lets dead_weight read at the same party as mower.
	var room := MeshInstance3D.new()
	room.name = "RoomFloor"
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(64.0, 0.5, 64.0)
	room.mesh = rmesh
	room.position = Vector3(0, -6.75, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.15, 0.10, 0.075)  # dark warm room floorboards (recedes)
	rmat.roughness = 0.95
	room.material_override = rmat
	$Arena.add_child(room)

	# a chunky warm table the arena rests on (footprint inside the lip so it never
	# catches a falling fighter); top tucks just under the play slab
	var table := MeshInstance3D.new()
	table.name = "Table"
	var tmesh := BoxMesh.new()
	tmesh.size = Vector3(9.6, 3.6, 9.6)
	table.mesh = tmesh
	table.position = Vector3(0, -4.65, 0)         # top ~-2.85, base rests on room floor
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.24, 0.16, 0.10)   # warm table wood, catches a little sun
	tmat.roughness = 0.72
	table.material_override = tmat
	$Arena.add_child(table)

func _build_void_ring() -> void:
	# a glowing gutter at the very lip of the floor: fall past it and you die.
	# warm hazard amber (was neon cyan) so the lethal edge still reads loudly
	# while belonging to the warm house palette.
	var glow := Color(1.0, 0.55, 0.16)
	var bars := [
		{"size": Vector3(12.4, 0.08, 0.3), "pos": Vector3(0, 0.04, 5.95)},
		{"size": Vector3(12.4, 0.08, 0.3), "pos": Vector3(0, 0.04, -5.95)},
		{"size": Vector3(0.3, 0.08, 12.4), "pos": Vector3(5.95, 0.04, 0)},
		{"size": Vector3(0.3, 0.08, 12.4), "pos": Vector3(-5.95, 0.04, 0)},
	]
	for b in bars:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = b["size"]
		mi.mesh = mesh
		mi.position = b["pos"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = glow
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 4.0
		mi.material_override = mat
		$Arena.add_child(mi)

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--dwbots":
			_all_bots = true
		elif arg == "--deadhint":
			_dead_hint_demo = true
		elif arg.begins_with("--dwbalance="):
			_balance_rounds = maxi(1, int(arg.trim_prefix("--dwbalance=")))
			_all_bots = true
		elif arg.begins_with("--dwrounds="):
			rounds_total = clampi(int(arg.trim_prefix("--dwrounds=")), 1, 9)
		elif arg.begins_with("--aimprobe="):
			_aim_probe_on = true
			_probe_shove = false
			_aim_probe_deg = float(arg.trim_prefix("--aimprobe="))
		elif arg.begins_with("--aimshove="):
			_aim_probe_on = true
			_probe_shove = true
			_aim_probe_deg = float(arg.trim_prefix("--aimshove="))
		elif arg.begins_with("--dwawaken="):
			# verify-only: force THE HOUSE AWAKENS this many seconds into each
			# round so the candlelight moment can be filmed without waiting out
			# 45s of brawl. Ignored by the --dwbalance sim (receipts unchanged).
			_awaken_override = maxf(0.5, float(arg.trim_prefix("--dwawaken=")))
		elif arg == "--hitkitcap":
			_hitkit_cap = true
		elif arg.begins_with("--dwevict="):
			_evict_pin = int(arg.trim_prefix("--dwevict="))
		elif arg.begins_with("--outdir="):
			_cap_dir = arg.trim_prefix("--outdir=")
	if _aim_probe_on:
		_dw_probe_manual = not _probe_shove
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	if _hitkit_cap:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://%s" % _cap_dir))

func _seed_from_args() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return 1

func _default_config() -> Dictionary:
	var count := 4
	var roles: Array = []
	var dwghosts := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			count = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--dwghosts="):
			dwghosts = int(arg.trim_prefix("--dwghosts="))
	if _balance_rounds > 0:
		count = 3
	if _aim_probe_on:
		count = 2   # p0 = KBM human, p1 = inert stand-in (victim / bystander)
	if _hitkit_cap:
		count = 2   # p0 = RED attacker, p1 = BLUE victim (staged, frozen)
	var roster: Array = []
	PlayerInput.auto_assign(count)
	if _aim_probe_on:
		PlayerInput.assign(0, -4)
		PlayerInput.assign(1, -99)
		var av := deg_to_rad(_aim_probe_deg)
		PlayerInput.set_debug_aim(0, Vector3(sin(av), 0.0, cos(av)))
	if _dead_hint_demo:
		PlayerInput.assign(0, -4)   # seat 0 is a KBM human so its ghost hint reads MOUSE/LMB
	for i in count:
		var seat_bot: bool = PlayerInput.standalone_bot_default(i)
		if _aim_probe_on:
			seat_bot = false
		elif _dead_hint_demo:
			seat_bot = (i != 0)   # seat 0 human (dead), the rest bots so the round plays
		roster.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": "",
			"device": PlayerInput.device_of(i),
			"bot": seat_bot,
		})
	# roles: default all living; balance = last player is a permanent ghost;
	# --dwghosts=N starts the last N players as ghosts.
	for i in count:
		roles.append("living")
	if _balance_rounds > 0:
		roles[count - 1] = "ghost"
	for i in range(count - dwghosts, count):
		if i >= 0:
			roles[i] = "ghost"
	if _aim_probe_on and not _probe_shove:
		roles[0] = "ghost"   # p0 rises as a poltergeist to fling furniture
	if _dead_hint_demo:
		roles[0] = "ghost"   # p0 (KBM human) starts dead so the ghost hint shows
	return {"roster": roster, "rounds": rounds_total, "rng_seed": _seed_from_args(),
		"practice": false, "roles": roles}

# ui_kit intro card (doc 14 nit 7): shown at load, real key fallback, auto-starts
# after 6s so bot soaks flow through.
const GAME_INTRO := {
	"name": "DEAD WEIGHT",
	"goal": "Sumo brawl in the attic. Shove rivals off — the fallen return as furniture-hurling ghosts.",
	"accent": Color(0.62, 0.78, 0.95),
	"controls": [
		{"action": "move", "label": "MOVE"},
		{"action": "a", "label": "SHOVE"},
		{"action": "b", "label": "HOP"},
	],
	"tips": [
		"Shove rivals over the edge; a HOP dodges a shove and repositions.",
		"Fall off and you possess the furniture — hurl it at the living.",
		"Last body standing takes the round.",
	],
}

## ui_kit intro card, then the callback. Feature-detected; ≤5-line hook (nit 7).
func _intro_then(cb: Callable) -> void:
	var card := IntroCard.new()
	add_child(card)
	card.started.connect(cb)
	var spec: Dictionary = GAME_INTRO.duplicate(true)
	spec["seats"] = _human_seats()
	card.present(spec)

func begin(config: Dictionary) -> void:
	_begin(config)

func _begin(config: Dictionary) -> void:
	_started = true
	_mirror = bool(config.get("net_mirror", false))
	rng.seed = int(config.get("rng_seed", 1))
	if _balance_rounds == 0:
		_stretch = FinalStretch.attach(self, timer_label)
	rounds_total = clampi(int(config.get("rounds", 3)), 1, 9)
	if _balance_rounds > 0:
		rounds_total = _balance_rounds
		Engine.time_scale = 6.0   # sim fast-forward; bot logic runs per physics tick
	var roster: Array = config.get("roster", [])
	var roles: Array = config.get("roles", [])
	players.clear()
	_fighters.clear()
	for i in roster.size():
		var r: Dictionary = roster[i]
		var role := "living"
		if i < roles.size():
			role = str(roles[i])
		players.append({
			"index": int(r.get("index", i)),
			"name": str(r.get("name", "P%d" % i)),
			"color": r.get("color", Color.WHITE),
			"device": int(r.get("device", -99)),
			# Per-player: bot-driven if the roster marks this seat a bot (shell
			# sets it from estate._is_bot; standalone from PlayerInput) OR the
			# legacy --dwbots / --dwbalance flags force ALL bots.
			"is_bot": _all_bots or bool(r.get("bot", false)),
			"role": role,
			"total": 0,
			"ghost_kills": 0,
			"deaths": 0,
			"streak": 0,
			"best_streak": 0,
		})
		var char_path := str(r.get("char_scene", ""))
		var char_scene: PackedScene = null
		if char_path != "" and ResourceLoader.exists(char_path):
			char_scene = load(char_path)
		else:
			char_scene = CHAR_SCENES[i % CHAR_SCENES.size()]
		if role == "living":
			var f := DWFighter.new()
			f.name = "Fighter%d" % i
			spawn_root.add_child(f)
			f.setup(i, players[i].color, char_scene, self)
			f.fell.connect(_on_fighter_fell)
			_fighters.append(f)
		else:
			_fighters.append(null)
	_layout_spawns(players.size())
	_build_props()
	_rebuild_scoreboard()
	hint_label.text = _controls_bar()   # on a client this reads THIS seat's keys
	round_index = 0
	if _mirror:
		# RENDER MIRROR (spec §4.3): no round start, no bots, no Jolt sim — every
		# body freezes and becomes a snapshot puppet. The host owns every fact.
		phase = Phase.PRE
		for i in players.size():
			var f: DWFighter = _fighters[i]
			if f == null:
				continue
			f.freeze = true
			f.set_physics_process(false)
			f.set_process(false)             # anim/rings are driven by _mirror_tick
			f.global_position = _spawns[i % _spawns.size()]
		for prop in _props:
			(prop as DWProp).freeze = true   # transforms stream; wobble stays local
		NetSession.set_aim_provider(_net_aim)
		print("DW_MIRROR boot players=%d my_seat=%d" % [players.size(), NetSession.my_seat()])
		return
	# NIT 7: intro card at load; headless balance/probe/capture keep the sync start.
	if _balance_rounds > 0 or _aim_probe_on or _hitkit_cap:
		_start_round()
		if _aim_probe_on:
			_run_dw_probe()
	else:
		_intro_then(_start_round)
	if _hitkit_cap:
		_run_hitkit_cap()

func _layout_spawns(count: int) -> void:
	_spawns.clear()
	var corners := [Vector3(-3.2, 0, -3.2), Vector3(3.2, 0, 3.2),
		Vector3(3.2, 0, -3.2), Vector3(-3.2, 0, 3.2)]
	for i in count:
		_spawns.append(corners[i % corners.size()])

func _build_props() -> void:
	# scatter props on a jittered ring/grid, avoiding the spawn corners
	var slots: Array = []
	var cols := 4
	for gx in cols:
		for gz in 3:
			var px := lerpf(-4.0, 4.0, gx / float(cols - 1))
			var pz := lerpf(-3.6, 3.6, gz / 2.0)
			slots.append(Vector3(px, 0, pz))
	for i in PROP_TIERS.size():
		var tier: String = PROP_TIERS[i]
		var prop := DWProp.new()
		prop.name = "Prop%d_%s" % [i, tier]
		spawn_root.add_child(prop)
		var base := Color(0.6, 0.45, 0.32).lerp(Color(0.5, 0.36, 0.5), rng.randf() * 0.5)
		if tier == "wardrobe":
			base = Color(0.45, 0.32, 0.24)
		elif tier == "lamp":
			base = Color(0.85, 0.78, 0.5)
		prop.setup(tier, base, self)
		var slot: Vector3 = slots[i % slots.size()]
		slot += Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		slot = _nudge_off_spawns(slot)
		slot.y = prop.rest_height()
		prop.home_spawn = slot
		_props.append(prop)

func _nudge_off_spawns(slot: Vector3) -> Vector3:
	# never seat a prop on a fighter spawn corner — the physics overlap would
	# fling the fighter off the floor at round start
	var corners := [Vector3(-3.2, 0, -3.2), Vector3(3.2, 0, 3.2),
		Vector3(3.2, 0, -3.2), Vector3(-3.2, 0, 3.2)]
	for _iter in 6:
		var worst := 0.0
		var push := Vector3.ZERO
		for c in corners:
			var d := Vector2(slot.x - c.x, slot.z - c.z).length()
			if d < 2.6 and (2.6 - d) > worst:
				worst = 2.6 - d
				var away := Vector2(slot.x - c.x, slot.z - c.z)
				if away.length() < 0.01:
					away = Vector2(0.5, 0.5)
				away = away.normalized() * 2.7
				push = Vector3(c.x + away.x, 0, c.z + away.y) - slot
		if worst <= 0.0:
			break
		slot += push
		slot.x = clampf(slot.x, -4.8, 4.8)
		slot.z = clampf(slot.z, -4.8, 4.8)
	return slot

# ---------------------------------------------------------------- round flow
func _start_round() -> void:
	print("DW_ROUND_START %d/%d t=%.1f ts=%.3f" % [round_index + 1, rounds_total, game_time, Engine.time_scale])
	phase = Phase.ROUND
	round_elapsed = 0.0
	_round_resolving = false
	_decider = "none"
	_elim_order.clear()
	_clear_ghosts()
	_house_asleep()
	var darken := round_index * 0.22
	for prop in _props:
		prop.reset_for_round(darken)
	for i in players.size():
		if players[i].role == "ghost":
			_spawn_ghost(i, Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)))
		else:
			var f: DWFighter = _fighters[i]
			var jitter := Vector3(rng.randf_range(-0.7, 0.7), 0.2, rng.randf_range(-0.7, 0.7))
			f.revive(_spawns[i] + jitter)
	round_label.text = "ROUND %d / %d" % [round_index + 1, rounds_total]
	_rebuild_scoreboard()
	_refresh_hint()
	if _stretch != null:
		_stretch.round_reset()   # FINAL STRETCH: light bed until the house wakes
	if _balance_rounds == 0:
		_flash_banner("ROUND %d\nFIGHT!" % (round_index + 1), Color(1, 0.85, 0.2), 1.6)
	# --dwevict evidence pin (probe nights only; --seancechar precedent): fell
	# the pinned seat through the REAL _fall() path 1 s into round 1, so the
	# poltergeist-and-furniture arc is guaranteed on film. Loud, never real play.
	if _evict_pin >= 0 and round_index == 0 and _balance_rounds == 0 and not _mirror:
		var pin := _evict_pin
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if phase == Phase.ROUND and pin < _fighters.size() \
					and _fighters[pin] != null and _fighters[pin].alive:
				print("DW_FORCEEVICT seat=%d (evidence pin — never real play)" % pin)
				_fighters[pin]._fall())

func _living_count() -> int:
	var n := 0
	for f in _fighters:
		if f != null and f.alive:
			n += 1
	return n

func _living_participants() -> int:
	var n := 0
	for p in players:
		if p.role == "living":
			n += 1
	return n

func _on_fighter_fell(index: int) -> void:
	if phase != Phase.ROUND:
		return
	_elim_order.append(index)
	players[index].deaths += 1
	players[index].streak = 0
	_currency_log.append({"type": "grudge", "player": index, "amount": 1, "reason": "shoved into the void"})

	var f: DWFighter = _fighters[index]
	var death_pos := f.global_position
	var atk: Dictionary = f.last_attacker
	var credit_type := "void"
	var credit_line := "THE VOID CLAIMS %s" % players[index].name
	var credit_color := Color(0.6, 0.85, 1.0)
	# kill attribution (reporting only): killer -1 = the void / an accident.
	var kill_killer := -1
	var kill_cause := "void"
	if atk.size() > 0 and (game_time - float(atk.get("time", -99.0))) <= KILL_CREDIT_WINDOW:
		var ai: int = int(atk.get("index", -1))
		if atk.get("type", "") == "ghost" and ai >= 0 and ai != index:
			credit_type = "ghost"
			credit_color = atk.get("color", Color.WHITE)
			credit_line = "%s (%s) CLAIMS %s" % [atk.get("name", "THE THING"), players[ai].name, players[index].name]
			players[ai].total += ROYALTY
			players[ai].ghost_kills += 1
			_currency_log.append({"type": "royalty", "player": ai, "amount": ROYALTY,
				"reason": "poltergeist kill on %s" % players[index].name})
			_highlights.append(credit_line)
			kill_killer = ai
			kill_cause = "furniture"
		elif atk.get("type", "") == "player" and ai >= 0 and ai != index:
			credit_type = "player"
			credit_color = atk.get("color", Color.WHITE)
			credit_line = "%s BOOTS %s INTO THE VOID" % [players[ai].name, players[index].name]
			_highlights.append(credit_line)
			kill_killer = ai
			kill_cause = "shove"
	_kill_events.append({"killer": kill_killer, "victim": index, "cause": kill_cause})

	print("DW_DEATH round=%d t=%.1fs %s (%s)" % [round_index + 1, round_elapsed, credit_line, credit_type])
	if _balance_rounds == 0:
		Sfx.play("splat")
		Sfx.play("death")
		_spawn_death_fx(death_pos, players[index].color)
		_flash_banner(credit_line, credit_color, 2.0)
		_shake = maxf(_shake, 0.5)
		# THE DECIDING MOMENT (doc 09 §8.2/§Q2): the fall that leaves one body
		# standing gets the deep freeze + fov punch ("LAST ONE STANDING" rides
		# the round banner below); ordinary falls demote to 0.5x/0.2s.
		var deciding := _living_count() <= 1 and _living_participants() >= 2
		if deciding and not _reduced_motion():
			_time_hit(0.25, 0.8)
			FinalStretch.fov_punch(cam, 52.0, 6.0, 0.8)
		else:
			_time_hit(0.5, 0.2)

	# record what ended the round for the balance metric + banner spotlight
	if _living_count() <= 1 and _decider == "none":
		_decider = credit_type
		_last_kill_line = credit_line
		_last_kill_color = credit_color

	# rise as a poltergeist for the rest of the round
	_spawn_ghost(index, death_pos)
	_rebuild_scoreboard()
	_refresh_hint()
	call_deferred("_check_round_end")

func _check_round_end() -> void:
	if phase != Phase.ROUND or _round_resolving:
		return
	var alive := _living_count()
	var participants := _living_participants()
	if participants >= 2 and alive <= 1:
		_resolve_round()
	elif participants == 1 and alive == 0:
		_resolve_round()

func _resolve_round() -> void:
	_round_resolving = true
	phase = Phase.BETWEEN
	# stop survivors in their tracks: bot/player input is no longer applied in
	# BETWEEN, and stale velocity must not carry anyone off the lip
	for f in _fighters:
		if f != null and f.alive:
			f.move_input = Vector2.ZERO
			f.want_shove = false
			f.want_hop = false
			f.linear_velocity = Vector3(0, f.linear_velocity.y, 0)
	# finishing order: survivors first, then reverse of death order
	var survivors: Array = []
	for i in players.size():
		if players[i].role == "living" and _fighters[i] != null and _fighters[i].alive:
			survivors.append(i)
	var finishing: Array = survivors.duplicate()
	var dead_desc: Array = _elim_order.duplicate()
	dead_desc.reverse()
	for i in dead_desc:
		finishing.append(i)
	for pos in finishing.size():
		var pi: int = finishing[pos]
		if pos < POINTS_TABLE.size():
			players[pi].total += POINTS_TABLE[pos]
	# survivors extend their streak
	for i in survivors:
		players[i].streak += 1
		players[i].best_streak = maxi(players[i].best_streak, players[i].streak)

	if _balance_rounds > 0:
		var key := "void"
		if _decider == "player":
			key = "living"
		elif _decider == "ghost":
			key = "ghost"
		_balance_tally[key] += 1
		_dbg.round_len += round_elapsed
		_next_round_or_finish(0.05)
		return

	var champ := "THE VOID"
	var champ_color := Color(0.7, 0.85, 1.0)
	if survivors.size() > 0:
		champ = players[survivors[0]].name
		champ_color = players[survivors[0]].color
	Sfx.play("round_over")
	# if a kill ended the round, the kill line keeps the spotlight
	var text := "%s SURVIVES\nROUND %d" % [champ, round_index + 1]
	var text_color := champ_color
	if _last_kill_line != "":
		# the deciding KO's name banner (doc 09 §8.2): the kill that ended it
		# keeps the spotlight, stamped LAST ONE STANDING
		text = "LAST ONE STANDING\n%s\n%s SURVIVES ROUND %d" % [_last_kill_line, champ, round_index + 1]
		text_color = _last_kill_color
		_last_kill_line = ""
	_flash_banner(text, text_color, 2.8)
	_rebuild_scoreboard()
	_next_round_or_finish(3.2)

func _next_round_or_finish(delay: float) -> void:
	round_index += 1
	if round_index >= rounds_total:
		call_deferred("_finish_match")
		return
	if delay <= 0.1:
		_start_round()
	else:
		# tick-driven (not awaited): survives any time_scale weirdness
		_between_timer = delay

func _finish_match() -> void:
	phase = Phase.DONE
	print("KILL_EVENTS n=%d %s" % [_kill_events.size(), JSON.stringify(_kill_events)])
	if _balance_rounds > 0:
		_print_balance()
		get_tree().quit()
		return
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if players[a].total != players[b].total:
			return players[a].total > players[b].total
		return a < b)
	var champ: int = order[0]
	_net_champ = champ
	print("DW_MATCH_OVER champ=%s pts=%d" % [players[champ].name, players[champ].total])
	if _stretch != null:
		_stretch.match_ended()
	_flash_banner("%s WINS DEAD WEIGHT" % players[champ].name, players[champ].color, 6.0)
	Sfx.play("match_win")
	_spawn_confetti(_spawns[champ] + Vector3(0, 1.2, 0), players[champ].color)

	var points: Dictionary = {}
	for i in players.size():
		points[i] = players[i].total
	# best streak highlight
	var best_streak_player := -1
	var best_streak := 0
	for i in players.size():
		if players[i].best_streak > best_streak:
			best_streak = players[i].best_streak
			best_streak_player = i
	if best_streak_player >= 0 and best_streak >= 2:
		_highlights.insert(0, "%s survived %d rounds straight" % [players[best_streak_player].name, best_streak])
	var monuments: Array = []
	for i in players.size():
		if players[i].ghost_kills >= 3:
			monuments.append({"player": i, "kind": "poltergeist",
				"label": "%s, Dead and Still Winning" % players[i].name})
	var results := {
		"placements": order,
		"points": points,
		"currency_events": _currency_log.duplicate(),
		"kill_events": _kill_events.duplicate(),
		"highlights": _dedup(_highlights).slice(0, 3),
		"monuments": monuments,
	}
	if has_method("report_finished"):
		report_finished(results)
	else:
		finished.emit(results)

func _print_balance() -> void:
	var total: int = _balance_tally.living + _balance_tally.ghost + _balance_tally.void
	# "living wins" = the ghost did NOT land the decisive kill (living shove or accident)
	var living_side: int = _balance_tally.living + _balance_tally.void
	var living_pct := 0.0
	if total > 0:
		living_pct = 100.0 * living_side / float(total)
	print("======== DEAD WEIGHT BALANCE ========")
	print("seed=%d rounds=%d" % [rng.seed, total])
	print("living-shove=%d ghost-kill=%d void/accident=%d" % [_balance_tally.living, _balance_tally.ghost, _balance_tally.void])
	print("LIVING WIN %% = %.1f%%   ghost-decided %% = %.1f%%   [target living 55-75%%]" % [living_pct, 100.0 - living_pct])
	print("telemetry: possessions=%d ghost_hits=%d avg_round=%.1fs" % [_dbg.possess, _dbg.ghost_hits, _dbg.round_len / float(maxi(total, 1))])
	print("DRIVE_FORCE=%.1f KNOCK_SCALE=%.2f KNOCK_MAX=%.1f" % [DWProp.DRIVE_FORCE, DWProp.KNOCK_SCALE, DWProp.KNOCK_MAX])
	print("HOUSE_AWAKENS at=%.1fs of %.1fs cap (live: %.0fs of %.0fs) POSSESS_CD %.1f->%.1f" % [
		_house_awakens_at(), _round_cap(), ROUND_TIME - HOUSE_AWAKENS_WINDOW, ROUND_TIME,
		DWGhost.POSSESS_CD, DWGhost.POSSESS_CD * 0.5])
	print("=====================================")

func _dedup(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		if not out.has(x):
			out.append(x)
	return out

# ---------------------------------------------------------------- ghosts
func _spawn_ghost(index: int, pos: Vector3) -> void:
	if _ghosts.has(index):
		return
	var g := DWGhost.new()
	g.name = "Ghost%d" % index
	spawn_root.add_child(g)
	g.setup(index, players[index].color, self)
	g.spawn_at(pos + Vector3(0, 1.0, 0))
	_ghosts[index] = g
	_ghost_hold[index] = 0.0

func _clear_ghosts() -> void:
	for k in _ghosts.keys():
		var g: DWGhost = _ghosts[k]
		g.force_release()
		g.queue_free()
	_ghosts.clear()

## ---- live-binding hint bar (real keys, not "A"/"B"; see docs/verify/realkeys-VERIFY.md) ----

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). The
## main bar personalizes only these.
func _human_seats() -> Array:
	var out := []
	for i in players.size():
		if not players[i].is_bot and PlayerInput.device_of(i) != -99:
			out.append(i)
	return out

## Seats whose bindings the hint bar prints: the live humans, or seat 0 as a
## representative when a bot-only demo has no humans — so the bar always shows
## a REAL key, never an abstract "A =" verb (doc 14 nit 3, notation consistency).
func _hint_seats() -> Array:
	var seats := _human_seats()
	return seats if not seats.is_empty() else [0]

## One button's live legend: "KEY = LABEL" when every hint seat shares the key
## (all pads -> "(A) = SHOVE"), else the per-seat "LABEL: KEY/NAME · KEY/NAME"
## form (mixed keyboard + pad). Consistent with the poltergeist _ghost_hint_line
## below. Bindings are fixed per match, so this is built once - no live polling.
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

## The living bar, always real keys via describe_binding (matches the card).
func _controls_bar() -> String:
	return "MOVE   ·   %s   ·   %s   ·   THE DEAD POSSESS THE FURNITURE" % [
		_btn_hint("a", "SHOVE"), _btn_hint("b", "HOP")]

## Swap the shared hint bar to a dead-state legend the moment a HUMAN becomes a
## poltergeist — the dead need the twin-stick controls spelled out (LEFT drifts,
## RIGHT aims, A flings). Bots never trigger this, so bot demos keep the living bar.
func _refresh_hint() -> void:
	if hint_label == null:
		return
	if _mirror:
		# On a mirror only MY seat's death swaps the bar (other seats' hints
		# live on their own screens; roster bot-flags are meaningless here).
		var my := NetSession.my_seat()
		if my >= 0 and _ghosts.has(my):
			hint_label.text = _ghost_hint_line(my)
		else:
			hint_label.text = _controls_bar()
		return
	var dead_humans: Array = []
	for i in players.size():
		if i < players.size() and not players[i].is_bot and _ghosts.has(i):
			dead_humans.append(i)
	if dead_humans.is_empty():
		hint_label.text = _controls_bar()
	elif dead_humans.size() == 1:
		hint_label.text = _ghost_hint_line(int(dead_humans[0]))
	else:
		hint_label.text = "YOU'RE DEAD — MOVE drift the furniture · AIM · A = FLING · B = release"

## Per-player poltergeist control line with LIVE bindings (device-accurate).
func _ghost_hint_line(i: int) -> String:
	var d: int = PlayerInput.device_of(i)
	var mv: String = PlayerInput.describe_binding(i, "move")
	var fling: String = PlayerInput.describe_binding(i, "a")
	var rel: String = PlayerInput.describe_binding(i, "b")
	var aim := "MOUSE"
	if d >= 0:
		aim = "RIGHT STICK"
	elif d != -4:
		aim = mv   # keyboard halves: no aim channel, fling follows the drift
	return "%s IS DEAD — %s drift · %s aim · %s FLING · %s release" % [players[i].name, mv, aim, fling, rel]

# ---------------------------------------------------------------- input/AI
func _physics_process(delta: float) -> void:
	game_time += delta
	if _shake > 0.001:
		cam.h_offset = rng.randf_range(-1, 1) * _shake * 0.3
		cam.v_offset = rng.randf_range(-1, 1) * _shake * 0.3
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	# THE HOUSE GUARD (spec §4.3): a mirror never simulates. Interp + juice only.
	if _mirror:
		_mirror_tick(delta)
		return

	if phase == Phase.BETWEEN and _between_timer > 0.0:
		_between_timer -= delta
		if _between_timer <= 0.0:
			_start_round()
		return
	if phase != Phase.ROUND:
		return
	round_elapsed += delta
	_update_timer_label()
	if not _house_awake and round_elapsed >= _house_awakens_at():
		_awaken_house()

	for i in players.size():
		if _dw_probe_manual and i == 0:
			continue   # the fling probe steers p0's ghost directly
		if _ghosts.has(i):
			_drive_ghost(i)
		elif _fighters[i] != null and _fighters[i].alive:
			_drive_fighter(i)

	if round_elapsed >= _round_cap():
		_resolve_round()

func _round_cap() -> float:
	return 22.0 if _balance_rounds > 0 else ROUND_TIME

# ---------------------------------------------------------------- house awakens
## When the dead rise: the final HOUSE_AWAKENS_WINDOW (30s) of the live 75s
## round. The shortened balance-sim rounds (22s cap) use the same fraction of
## the cap (45/75 = 60%) so --dwbalance measures the same regime, reproducibly.
func _house_awakens_at() -> float:
	if _awaken_override > 0.0 and _balance_rounds == 0:
		return _awaken_override
	return maxf(_round_cap() - HOUSE_AWAKENS_WINDOW, _round_cap() * 0.6)

## THE HOUSE AWAKENS (doc 09 §8.3, Alex-signed): ghost possess-cooldowns halve
## (running cooldowns halved on the spot) — the teeth. The candlelight dim is
## presentation only, gated behind fx_on() so --dwbalance stays reproducible.
func _awaken_house() -> void:
	_house_awake = true
	for k in _ghosts:
		(_ghosts[k] as DWGhost).house_awakens()
	print("DW_HOUSE_AWAKENS round=%d t=%.1fs at=%.1fs cd_scale=0.5 ghosts=%d" % [
		round_index + 1, round_elapsed, _house_awakens_at(), _ghosts.size()])
	if fx_on():
		if _stretch != null:
			_stretch.escalate()   # FINAL STRETCH: the awakening brings the tense track
		Sfx.play("grudge")
		_flash_banner("THE HOUSE AWAKENS", Color(0.72, 0.55, 0.95), 2.2)
		_dim_to_candlelight()
		if NetSession.has_guests() and not _mir_snaps.has("dw_host_awakens"):
			_mir_snaps["dw_host_awakens"] = true
			VerifyCapture.snap("dw_host_awakens")

## Ghost possess-cooldown scale — poltergeist.gd reads this on every release().
func ghost_possess_cd_scale() -> float:
	return 0.5 if _house_awake else 1.0

## The room drops to candlelight: ambient + sun ease down, four candles gutter
## to life around the attic. Pure fx (never runs in --dwbalance).
func _dim_to_candlelight() -> void:
	if _env != null:
		if _dim_tw != null and _dim_tw.is_valid():
			_dim_tw.kill()
		_dim_tw = create_tween()
		_dim_tw.set_parallel(true)
		# drop RELATIVE to the EnvKit base so the mood deepens regardless of preset tuning
		_dim_tw.tween_property(_env, "ambient_light_energy", _base_ambient * 0.65, 1.4)
		if _sun != null:
			_dim_tw.tween_property(_sun, "light_energy", _base_sun * 0.68, 1.4)
	_candle_root = Node3D.new()
	_candle_root.name = "Candles"
	add_child(_candle_root)
	_candle_lights.clear()
	for corner in [Vector3(4.9, 0, 4.9), Vector3(-4.9, 0, 4.9), Vector3(4.9, 0, -4.9), Vector3(-4.9, 0, -4.9)]:
		var wax := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.09
		wm.bottom_radius = 0.11
		wm.height = 0.42
		wax.mesh = wm
		wax.position = corner + Vector3(0, 0.21, 0)
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.92, 0.86, 0.72)
		wmat.roughness = 0.6
		wax.material_override = wmat
		_candle_root.add_child(wax)
		var flame := MeshInstance3D.new()
		var fm2 := SphereMesh.new()
		fm2.radius = 0.06
		fm2.height = 0.16
		flame.mesh = fm2
		flame.position = corner + Vector3(0, 0.52, 0)
		var fmat2 := StandardMaterial3D.new()
		fmat2.albedo_color = Color(1.0, 0.72, 0.3)
		fmat2.emission_enabled = true
		fmat2.emission = Color(1.0, 0.6, 0.18)
		fmat2.emission_energy_multiplier = 3.6
		flame.material_override = fmat2
		_candle_root.add_child(flame)
		var lt := OmniLight3D.new()
		lt.position = corner + Vector3(0, 0.7, 0)
		lt.light_color = Color(1.0, 0.62, 0.28)
		lt.light_energy = 1.4
		lt.omni_range = 5.5
		lt.set_meta("base_energy", 1.4)
		_candle_root.add_child(lt)
		_candle_lights.append(lt)

## Reset the awakening between rounds: buff off, candles out, lighting restored.
func _house_asleep() -> void:
	_house_awake = false
	if _dim_tw != null and _dim_tw.is_valid():
		_dim_tw.kill()
	_dim_tw = null
	if _candle_root != null and is_instance_valid(_candle_root):
		_candle_root.queue_free()
	_candle_root = null
	_candle_lights.clear()
	if fx_on() and _env != null:
		_env.ambient_light_energy = _base_ambient
		if _sun != null:
			_sun.light_energy = _base_sun

## Candle gutter — visual only, fx-gated, global randf (never the seeded rng).
func _process(_delta: float) -> void:
	if not fx_on() or _candle_lights.is_empty():
		return
	for c in _candle_lights:
		if not is_instance_valid(c):
			continue
		var base: float = float(c.get_meta("base_energy", 1.4))
		(c as OmniLight3D).light_energy = base \
			+ sin(game_time * 13.0 + c.position.x * 7.0) * 0.35 + randf_range(-0.12, 0.12)

func _drive_fighter(i: int) -> void:
	var f: DWFighter = _fighters[i]
	if players[i].is_bot:
		_bot_living(f)
	else:
		f.move_input = PlayerInput.get_move(i)
		f.aim_face = PlayerInput.get_aim_dir(i, f.global_position, cam)   # ZERO for non-KBM
		if PlayerInput.just_pressed(i, "a"):
			f.want_shove = true
		if PlayerInput.just_pressed(i, "b"):
			f.want_hop = true

func _drive_ghost(i: int) -> void:
	var g: DWGhost = _ghosts[i]
	if players[i].is_bot:
		_bot_ghost(g)
	else:
		# LEFT channel = MOVE: WASD / left stick both free-fly the wisp AND drift a
		# possessed prop (the owner's convention fix — the dead now steer with the
		# left hand, not the cursor).
		g.move_input = PlayerInput.get_move(i)
		# RIGHT channel = AIM the fling: mouse cursor (KBM) or right stick (pad),
		# anchored on the prop. ZERO for keyboard halves / bots => fling falls back
		# to the drift direction. Only sampled while possessing.
		if g.possessing != null:
			var aim3 := PlayerInput.get_aim_dir(i, g.possessing.global_position, cam)  # KBM cursor
			if aim3 == Vector3.ZERO:
				var st := PlayerInput.get_aim_stick(i)                                 # pad right stick
				if st != Vector2.ZERO:
					aim3 = Vector3(st.x, 0.0, st.y)
			g.aim_fling = aim3
			g.want_fling = PlayerInput.just_pressed(i, "a")                            # LMB / A hurls it
		else:
			g.aim_fling = Vector3.ZERO
			g.want_fling = false
		g.want_possess = PlayerInput.is_down(i, "a")   # free-fly: hold to grab
		g.want_release = PlayerInput.just_pressed(i, "b")

func _bot_living(f: DWFighter) -> void:
	var here := Vector2(f.global_position.x, f.global_position.z)
	var target := _nearest_living_other(f)
	var mv := Vector2.ZERO
	if target != null:
		var tp := Vector2(target.global_position.x, target.global_position.z)
		var dist := here.distance_to(tp)
		# approach the target from the CENTER side, so our shove sends them outward
		var outward := tp
		if outward.length() < 0.4:
			outward = Vector2(0, 1)
		outward = outward.normalized()
		var approach := tp - outward * 1.15
		if dist < 1.9:
			mv = (tp - here)          # close for the kill
		else:
			mv = approach - here
		if mv.length() > 0.01:
			mv = mv.normalized()
		if dist < DWFighter.SHOVE_RANGE + 0.1:
			f.want_shove = true
	# a little seeded wander so mirror-image bots don't play identical rounds
	mv += Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
	# edge avoidance: steer hard back toward center near the lip
	if absf(here.x) > 3.6:
		mv.x += -signf(here.x) * 3.0
	if absf(here.y) > 3.6:
		mv.y += -signf(here.y) * 3.0
	# dodge a fast possessed prop bearing down
	var threat := _incoming_prop(f)
	if threat != null:
		var away := here - Vector2(threat.global_position.x, threat.global_position.z)
		if away.length() > 0.01:
			var perp := Vector2(-away.y, away.x).normalized()
			mv += perp * 1.3
	if mv.length() > 0.01:
		mv = mv.normalized()
	f.move_input = mv

func _bot_ghost(g: DWGhost) -> void:
	var target := _nearest_living_any(g.global_position)
	if g.possessing != null:
		if target == null:
			g.want_release = true
			return
		# ram the victim TOWARD the nearest void edge: approach from the center
		# side so the prop's momentum shoves them outward, not inward
		var prop_xz := Vector2(g.possessing.global_position.x, g.possessing.global_position.z)
		var tgt_xz := Vector2(target.global_position.x, target.global_position.z)
		var outward := tgt_xz
		if outward.length() < 0.4:
			outward = Vector2(0, 1)
		outward = outward.normalized()
		var to_tgt := (tgt_xz - prop_xz)
		if to_tgt.length() > 0.05 and to_tgt.normalized().dot(outward) > 0.15:
			# prop is center-ward of the victim: charge straight through them
			g.move_input = to_tgt.normalized()
		else:
			# prop is on the wrong side: swing around to the center side first
			var flank := tgt_xz - outward * 2.3
			var to_flank := flank - prop_xz
			g.move_input = to_flank.normalized() if to_flank.length() > 0.05 else to_tgt.normalized()
		_ghost_hold[g.index] = _ghost_hold.get(g.index, 0.0) + get_physics_process_delta_time()
		if _ghost_hold[g.index] > 8.0:
			g.want_release = true
			_ghost_hold[g.index] = 0.0
		return
	# hunt a prop near the target (fall back to nearest prop to the ghost)
	var prop := _possessable_prop_near(target.global_position if target != null else g.global_position)
	if prop == null:
		g.move_input = Vector2(-g.global_position.x, -g.global_position.z).normalized()
		g.want_possess = false
		return
	var pd := Vector2(prop.global_position.x - g.global_position.x,
		prop.global_position.z - g.global_position.z)
	g.move_input = pd.normalized() if pd.length() > 0.01 else Vector2.ZERO
	g.want_possess = pd.length() <= DWGhost.POSSESS_RANGE

func _nearest_living_other(f: DWFighter) -> DWFighter:
	var best: DWFighter = null
	var bd := 1e9
	for other in _fighters:
		if other == null or other == f or not other.alive:
			continue
		var d: float = f.global_position.distance_to(other.global_position)
		if d < bd:
			bd = d
			best = other
	return best

func _nearest_living_any(from: Vector3) -> DWFighter:
	var best: DWFighter = null
	var bd := 1e9
	for f in _fighters:
		if f == null or not f.alive:
			continue
		var d: float = from.distance_to(f.global_position)
		if d < bd:
			bd = d
			best = f
	return best

func _incoming_prop(f: DWFighter) -> DWProp:
	for prop in _props:
		if prop.possessed_by < 0:
			continue
		var to: Vector3 = f.global_position - prop.global_position
		to.y = 0
		if to.length() < 2.5 and prop.linear_velocity.length() > 2.5:
			if prop.linear_velocity.normalized().dot(to.normalized()) > 0.4:
				return prop
	return null

func _possessable_prop_near(pos: Vector3) -> DWProp:
	var best: DWProp = null
	var bd := 1e9
	for prop in _props:
		if not prop.can_be_possessed():
			continue
		var d: float = pos.distance_to(prop.global_position)
		if d < bd:
			bd = d
			best = prop
	return best

# ---------------------------------------------------------------- callbacks used by children
func living_fighters() -> Array:
	var out: Array = []
	for f in _fighters:
		if f != null and f.alive:
			out.append(f)
	return out

func props() -> Array:
	return _props

func prop_locked_by_spawn(prop: DWProp) -> bool:
	if round_elapsed >= SPAWN_LOCK_TIME:
		return false
	for s in _spawns:
		var d := Vector2(prop.global_position.x - s.x, prop.global_position.z - s.z).length()
		if d < SPAWN_LOCK_RADIUS:
			return true
	return false

func on_shove_landed(_pos: Vector3) -> void:
	# Balance mode DISABLES FX so the sim is reproducible — the documented
	# by-construction argument (dead_weight/VERIFY.md "Known issues": the wall-clock
	# hit-pause must not run headless or physics alignment drifts run-to-run). This
	# mirrors the death-FX gating in _on_fighter_fell (both keyed on fx_on()); with
	# no FX, _shake never fires in --dwbalance, so its rng stream stays deterministic.
	if not fx_on():
		return
	# LIVE: THE ILL WILL HIT KIT — layered thud on connect + (unless reduced-motion)
	# a capped shake and ONE throttled micro-hitstop (0.15 time_scale, 45ms).
	Sfx.play("bumper", -3.0)
	if not _reduced_motion():
		_shake = maxf(_shake, 0.28)
		if game_time - _last_hitstop >= 0.14:
			_last_hitstop = game_time
			_time_hit(0.15, 0.045)

## Visual FX gate — OFF in the reproducible all-bot balance sim (--dwbalance),
## so none of the HIT KIT / cooldown-ring code runs there (determinism receipt).
func fx_on() -> bool:
	return _balance_rounds == 0

func _reduced_motion() -> bool:
	return not bool(PartySetup.pref("screen_shake", true))

## HIT KIT §B1 spark burst — a one-shot cone of sparks along the knockback dir at
## the contact point (kept even under reduced-motion; a read, not a shake).
func spark_at(pos: Vector3, dir: Vector3, color: Color, strength := 1.0) -> void:
	if not fx_on():
		return
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = clampi(int(round(8.0 * strength)), 3, 14)
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.spread = 55.0
	var d := dir
	d.y = 0.0
	p.direction = (d.normalized() if d.length() > 0.05 else Vector3.UP)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -6.0, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.09)
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = color.lerp(Color.WHITE, 0.5)
	mat.emission_energy_multiplier = 2.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

## HIT KIT §A6/§B1 readability arc — fired the instant a shove releases (hit OR
## whiff): a bright windup ring (WHEN) + a directional arc to SHOVE_RANGE (WHERE),
## in the shover's color. Presentation only; skipped in the balance sim.
func on_shove_fired(pos: Vector3, dir: Vector3, col: Color) -> void:
	if not fx_on():
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3(0, 0, 1)
	flat = flat.normalized()
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos + Vector3(0, 0.12, 0)
	root.rotation.y = atan2(flat.x, flat.z)
	var gc := col.lerp(Color(1, 1, 1), 0.35)
	var arc := MeshInstance3D.new()
	arc.mesh = _shove_arc_mesh(DWFighter.SHOVE_RANGE)
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
	var ring2 := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.5
	ring2.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.9)
	rm.emission_enabled = true
	rm.emission = gc
	rm.emission_energy_multiplier = 3.0
	ring2.material_override = rm
	ring2.rotation.x = PI / 2.0
	root.add_child(ring2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "scale", Vector3(1.05, 1.0, 1.05), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(am, "albedo_color:a", 0.0, 0.28)
	tw.tween_property(ring2, "scale", Vector3(2.2, 2.2, 2.2), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(root.queue_free)

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

func on_possess(_g: DWGhost, _p: DWProp) -> void:
	if _balance_rounds > 0:
		_dbg.possess += 1

func note_ghost_hit() -> void:
	_net_ghost_hits += 1   # mirrored fact; pure counter, sim never reads it
	if _balance_rounds > 0:
		_dbg.ghost_hits += 1
	elif NetSession.has_guests() and not _mir_snaps.has("dw_host_ghosthit"):
		_mir_snaps["dw_host_ghosthit"] = true
		VerifyCapture.snap("dw_host_ghosthit")

# ---------------------------------------------------------------- fx / ui
func _time_hit(scale: float, real_duration: float) -> void:
	_time_token += 1
	var my := _time_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_duration, true, false, true).timeout
	if my == _time_token:
		Engine.time_scale = 1.0

func _update_timer_label() -> void:
	var remaining: int = int(ceil(maxf(0.0, _round_cap() - round_elapsed)))
	timer_label.text = "%02d" % remaining
	if _stretch != null:
		_stretch.tick(_round_cap() - round_elapsed)   # FINAL STRETCH ladder + pulse

func _flash_banner(text: String, color: Color, duration: float) -> void:
	banner.text = text
	_banner_col = color.to_html(false)
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func(): banner.visible = false)

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
		var dead: bool = (p.role == "ghost" or _ghosts.has(i)) or (_fighters[i] != null and not _fighters[i].alive)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(i, 24)
		badge.color = p.color
		if dead:
			badge.dim = 0.45
		hb.add_child(badge)
		var row := Label.new()
		var tag := ""
		if p.role == "ghost" or _ghosts.has(i):
			tag = "  ☠"
		elif _fighters[i] != null and not _fighters[i].alive:
			tag = "  ☠"
		var extras := ""
		if p.ghost_kills > 0:
			extras += "  †%d" % p.ghost_kills
		row.text = "%s  %d%s%s" % [p.name, p.total, extras, tag]
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", p.color)
		row.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
		row.add_theme_constant_override("outline_size", 5)
		hb.add_child(row)
		score_rows.add_child(hb)

func _spawn_death_fx(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos + Vector3(0, 0.3, 0)
	p.one_shot = true
	p.amount = 30
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

# ---------------------------------------------------------------- mouse-aim probe
# --aimprobe=<deg>: poltergeist flings a possessed crate toward the cursor.
# --aimshove=<deg>: a living fighter's shove cone points at the cursor.
# Each writes two shots to verify_out/ proving the action follows the CYAN aim
# ray, not the WHITE baseline (WASD-drive dir / walk-facing).
func _run_dw_probe() -> void:
	while phase != Phase.ROUND:
		await get_tree().physics_frame
	if _probe_shove:
		await _dw_probe_shove()
	else:
		await _dw_probe_fling()
	await get_tree().create_timer(0.2).timeout
	print("DW_AIMPROBE_DONE")
	get_tree().quit()


func _dw_probe_fling() -> void:
	var g: DWGhost = _ghosts[0]
	var prop: DWProp = _props[2]   # a lamp: light enough to hurl fast and read as thrown
	var aim_yaw := deg_to_rad(_aim_probe_deg)
	var wasd_dir := Vector3(1, 0, 0)                    # baseline: "WASD" drives it +X
	prop.global_position = Vector3(0, prop.rest_height() + 0.1, 0)
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	g.global_position = Vector3(0, DWGhost.HOVER_Y, 0)
	g._begin_possession(prop)
	g.aim_fling = Vector3.ZERO
	g.want_fling = false
	g.move_input = Vector2(wasd_dir.x, wasd_dir.z)
	_dw_probe_arrow(Vector3.ZERO, atan2(wasd_dir.x, wasd_dir.z), Color(1, 1, 1), 3.0)     # WASD drift (white)
	_dw_probe_arrow(Vector3.ZERO, aim_yaw, Color(0.2, 0.95, 1.0), 3.0)                    # cursor (cyan)
	await get_tree().create_timer(0.45).timeout
	await _dw_grab("fling_facing")
	print("DW_AIMPROBE fling baseline prop_vel=%s (WASD +X drift)" % str(prop.linear_velocity))
	prop.global_position = Vector3(0, prop.rest_height() + 0.1, 0)
	prop.linear_velocity = Vector3.ZERO
	g.global_position = Vector3(0, DWGhost.HOVER_Y, 0)
	g.move_input = Vector2.ZERO
	# aim the FLING at the cursor and pull the trigger (LMB / A) once. The fling is
	# a one-shot velocity burst, so measure it while it is still in flight (before
	# linear_damp bleeds it off or it rams a scattered prop 3.6m out).
	g.aim_fling = Vector3(sin(aim_yaw), 0.0, cos(aim_yaw))
	g.want_fling = true
	await get_tree().create_timer(0.22).timeout
	await _dw_grab("fling_acting")
	var vdir := rad_to_deg(atan2(prop.linear_velocity.x, prop.linear_velocity.z))
	print("DW_AIMPROBE fling prop_vel=%s dir=%.0fdeg aim=%.0fdeg matches=%s" % [
		str(prop.linear_velocity), vdir, _aim_probe_deg, str(absf(vdir - _aim_probe_deg) < 25.0)])


func _dw_probe_shove() -> void:
	var f: DWFighter = _fighters[0]
	var victim: DWFighter = _fighters[1]
	var aim_yaw := deg_to_rad(_aim_probe_deg)
	var face_yaw := aim_yaw + PI * 0.5
	var aim_dir := Vector3(sin(aim_yaw), 0.0, cos(aim_yaw))
	f.global_position = Vector3(0, 0.1, 0)
	f.linear_velocity = Vector3.ZERO
	f._face = Vector3(sin(face_yaw), 0.0, cos(face_yaw))
	if f.model_pivot:
		f.model_pivot.rotation.y = face_yaw
	victim.global_position = Vector3(0, 0.1, 0) + aim_dir * (DWFighter.SHOVE_RANGE - 0.4)
	victim.linear_velocity = Vector3.ZERO
	_dw_probe_arrow(Vector3.ZERO, face_yaw, Color(1, 1, 1), 3.0)                          # facing (white)
	_dw_probe_arrow(Vector3.ZERO, aim_yaw, Color(0.2, 0.95, 1.0), 3.0)                    # cursor (cyan)
	await get_tree().create_timer(0.5).timeout
	await _dw_grab("shove_facing")
	var v_before := victim.global_position
	print("DW_AIMSHOVE face=%.0fdeg aim=%.0fdeg victim_before=(%.2f,%.2f)" % [
		rad_to_deg(face_yaw), _aim_probe_deg, v_before.x, v_before.z])
	f.want_shove = true
	await get_tree().create_timer(0.25).timeout
	await _dw_grab("shove_acting")
	var knocked := victim.global_position - v_before
	var kdir := rad_to_deg(atan2(knocked.x, knocked.z))
	print("DW_AIMSHOVE victim moved %.2fm dir=%.0fdeg aim=%.0fdeg matches=%s" % [
		knocked.length(), kdir, _aim_probe_deg,
		str(knocked.length() > 0.2 and absf(kdir - _aim_probe_deg) < 35.0)])


func _dw_probe_arrow(origin: Vector3, yaw_a: float, col: Color, length: float) -> void:
	var dir := Vector3(sin(yaw_a), 0.0, cos(yaw_a))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.8
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, length)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = origin + dir * (length * 0.5) + Vector3(0, 0.9, 0)
	mi.rotation.y = yaw_a
	add_child(mi)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.42, 0.42, 0.42)
	tip.mesh = tm
	tip.material_override = mat
	tip.position = origin + dir * length + Vector3(0, 0.9, 0)
	add_child(tip)


func _dw_grab(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("DW_AIMPROBE_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://verify_out/dead_weight_aim_%s.png" % tag
	img.save_png(path)
	print("DW_AIMPROBE_CAP ", path)


# ---------------------------------------------------------------- HIT KIT capture
# --hitkitcap (windowed): stages each feel moment (shove coil+arc, victim impact
# with sparks+pop, cooldown-ring fill, ready-flash) with gameplay frozen, films
# it, then quits. Verify-only; no effect on a normal match.
func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func _cap_shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("DW_HITKIT_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/dead_weight_%s.png" % [_cap_dir, tag]
	img.save_png(path)
	print("DW_HITKIT_CAP ", path)

func _run_hitkit_cap() -> void:
	while phase != Phase.ROUND:
		await get_tree().physics_frame
	# BLUE attacker (its player-colored rings read clearly on the warm red rug);
	# RED victim. Staged side-by-side at the same depth so neither body occludes
	# the other's feet rings.
	var atk: DWFighter = _fighters[1]     # BLUE attacker
	var vic: DWFighter = _fighters[0]     # RED victim
	if atk == null or vic == null:
		print("DW_HITKIT_CAP_ABORT no fighters")
		get_tree().quit()
		return
	atk._cap_freeze = true
	vic._cap_freeze = true
	atk.freeze = true
	vic.freeze = true
	var atk_pos := Vector3(-1.55, 0.1, 1.9)
	var vic_pos := Vector3(1.15, 0.1, 1.9)
	atk.global_position = atk_pos
	vic.global_position = vic_pos
	var face := (vic_pos - atk_pos)
	face.y = 0.0
	face = face.normalized()
	atk._face = face
	if atk.model_pivot:
		atk.model_pivot.rotation.y = atan2(face.x, face.z)
	if vic.model_pivot:
		vic.model_pivot.rotation.y = atan2(-face.x, -face.z)   # victim faces the shover
	banner.visible = false
	await _settle(0.35)
	# 1) WINDUP COIL + readability arc (BLUE attacker mid crouch-and-lunge at RED)
	atk.windup_coil(true)
	on_shove_fired(atk_pos, face, players[1].color)
	await _settle(0.05)
	await _cap_shot("hitkit_coil")
	await _settle(0.3)
	# 2) IMPACT — RED victim squash-popped + spark cone along the knockback
	vic.flash_pop()
	spark_at(vic_pos + Vector3(0, 0.9, 0) - face * 0.3, face, players[1].color, 1.35)
	await _settle(0.06)
	await _cap_shot("hitkit_impact")
	await _settle(0.35)
	# 3) COOLDOWN RINGS mid-fill — park the victim, center the BLUE attacker so its
	#    SHOVE (outer) + HOP (thin inner) rings are fully visible and unoccluded.
	vic.global_position = Vector3(5.6, 0.1, 5.6)
	atk.global_position = Vector3(0.0, 0.1, 2.0)
	atk._shove_cd = DWFighter.SHOVE_CD * 0.45
	atk._hop_cd = DWFighter.HOP_CD * 0.45
	await _settle(0.14)
	await _cap_shot("hitkit_ring_fill")
	# 4) READY-FLASH — drive the SHOVE ring to full so it flashes bright
	atk._shove_cd = 0.04
	await _settle(0.06)
	atk._shove_cd = 0.0
	await _settle(0.05)
	await _cap_shot("hitkit_ring_ready")
	await _settle(0.15)
	print("DW_HITKIT_CAP_DONE")
	get_tree().quit()

# ---------------------------------------------------------------- ONLINE (phase 2)
# House pattern (docs/verify/online-seance-VERIFY.md PATTERN NOTES): host sim
# untouched, _net_state() = one flat dict of PUBLIC facts, _net_apply() diffs
# and fires ALL juice from deltas, _mirror_tick() interpolates at 60 Hz. Dead
# weight has no hidden info — no private channel. The soul of this mirror is
# the FURNITURE: possessed-prop transforms stream, so the client watches the
# armchair lunge exactly as the couch does.

## HOST, pumped by the estate at 20 Hz. Ask of every key: is this on every
## couch screen right now? Fighters, wisps, furniture, HUD — yes. Nothing else.
func _net_state() -> Dictionary:
	var fs: Array = []
	for i in players.size():
		var f: DWFighter = _fighters[i]
		if f == null:
			fs.append_array([0, 0.0, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0, 0.0, 0.0, 0])
			continue
		fs.append(1 if f.alive else 0)
		fs.append(snappedf(f.global_position.x, 0.01))
		fs.append(snappedf(f.global_position.y, 0.01))
		fs.append(snappedf(f.global_position.z, 0.01))
		fs.append(snappedf(f.model_pivot.rotation.y, 0.01) if f.model_pivot else 0.0)
		fs.append(maxi(NET_ANIMS.find(f._cur_anim), 0))
		fs.append(snappedf(maxf(f._shove_cd, 0.0), 0.02))
		fs.append(snappedf(maxf(f._hop_cd, 0.0), 0.02))
		fs.append(f.net_hits)
		fs.append(snappedf(f.net_hit_dir.x, 0.01))
		fs.append(snappedf(f.net_hit_dir.z, 0.01))
		fs.append(f.net_shoves)
	var gs: Array = []
	for i in players.size():
		if _ghosts.has(i):
			var g: DWGhost = _ghosts[i]
			var pidx := -1
			if g.possessing != null and is_instance_valid(g.possessing):
				pidx = _props.find(g.possessing)
			gs.append_array([1, snappedf(g.global_position.x, 0.01),
				snappedf(g.global_position.y, 0.01), snappedf(g.global_position.z, 0.01), pidx])
		else:
			gs.append_array([0, 0.0, 0.0, 0.0, -1])
	var ps: Array = []
	for prop in _props:
		var pr := prop as DWProp
		ps.append(snappedf(pr.global_position.x, 0.01))
		ps.append(snappedf(pr.global_position.y, 0.01))
		ps.append(snappedf(pr.global_position.z, 0.01))
		var q := pr.global_transform.basis.get_rotation_quaternion()
		ps.append(snappedf(q.x, 0.001))
		ps.append(snappedf(q.y, 0.001))
		ps.append(snappedf(q.z, 0.001))
		ps.append(snappedf(q.w, 0.001))
		ps.append(pr.possessed_by)
	var sc: Array = []
	var gk: Array = []
	var dth: Array = []
	for p in players:
		sc.append(int(p.total))
		gk.append(int(p.ghost_kills))
		dth.append(int(p.deaths))
	return {
		"ph": phase,
		"ri": round_index,
		"rl": round_label.text,
		"tmr": timer_label.text,
		"ban": [banner.text, _banner_col, banner.visible],
		"aw": 1 if _house_awake else 0,
		"f": fs,
		"g": gs,
		"pr": ps,
		"sc": sc,
		"gk": gk,
		"dth": dth,
		"gh": _net_ghost_hits,
		"champ": _net_champ,
	}


## CLIENT. Latest-state-wins; all juice from deltas (counters, never events).
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()   # FINAL STRETCH: light bed on first snapshot
	phase = (int(state.get("ph", phase))) as Phase   # render/probe fact only
	round_label.text = str(state.get("rl", ""))
	timer_label.text = str(state.get("tmr", ""))
	# FINAL STRETCH ladder/pulse off the mirrored countdown text ("%02d")
	if _stretch != null:
		if str(state.get("tmr", "")).is_valid_int() and phase == Phase.ROUND:
			_stretch.tick(float(int(str(state.get("tmr", "99")))))
		elif phase == Phase.DONE:
			_stretch.match_ended()
	_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	# --- round rollover: candles out, ghosts folded, furniture dent applied
	var ri := int(state.get("ri", 0))
	if ri != int(prev.get("ri", ri)):
		_mir_round_reset(ri)
		if _stretch != null:
			_stretch.round_reset()
	# --- THE HOUSE AWAKENS: the mood shift, fired locally from the fact
	if int(state.get("aw", 0)) == 1 and int(prev.get("aw", 0)) == 0:
		Sfx.play("grudge")
		if _stretch != null:
			_stretch.escalate()   # FINAL STRETCH fires client-side off the aw fact
		_dim_to_candlelight()
		_mir_snap_once("dw_mirror_awakens")
	elif int(state.get("aw", 1)) == 0 and int(prev.get("aw", 0)) == 1:
		_house_asleep()
	# --- fighters: alive flags, cooldown resync, hit/shove one-shots
	var fs: Array = state.get("f", [])
	var pfs: Array = prev.get("f", [])
	for i in players.size():
		var b := i * 12
		if b + 11 >= fs.size():
			break
		var f: DWFighter = _fighters[i]
		if f == null:
			continue
		var alive := int(fs[b]) == 1
		if alive != f.alive:
			f.alive = alive
			f.visible = alive
			if alive and f.model_pivot:      # revived for the next round
				f.model_pivot.scale = Vector3.ONE
		var scd := float(fs[b + 6])
		if absf(f._shove_cd - scd) > 0.1:
			f._shove_cd = scd
		var hcd := float(fs[b + 7])
		if absf(f._hop_cd - hcd) > 0.1:
			f._hop_cd = hcd
		var hits := int(fs[b + 8])
		var phits := int(pfs[b + 8]) if b + 8 < pfs.size() else hits
		if hits > phits and alive:
			# a shove or a hurled prop connected: squash-pop + spark, as couch
			var d := Vector3(float(fs[b + 9]), 0.0, float(fs[b + 10]))
			f.flash_pop()
			spark_at(f.global_position + Vector3(0, 0.9, 0) - d * 0.3, d, players[i].color, 1.0)
			Sfx.play("bumper", -3.0)
			if not _reduced_motion():
				_shake = maxf(_shake, 0.28)
		var sh := int(fs[b + 11])
		var psh := int(pfs[b + 11]) if b + 11 < pfs.size() else sh
		if sh > psh and alive:
			# shove fired: whoosh + windup ring/arc along the mirrored facing
			Sfx.play("bounce", -7.0)
			var yaw := float(fs[b + 4])
			on_shove_fired(f.global_position, Vector3(sin(yaw), 0.0, cos(yaw)), players[i].color)
			f.windup_coil(false)
	# --- deaths: fx + shake + hitstop (client's reduced-motion pref rules)
	var dth: Array = state.get("dth", [])
	var pdth: Array = prev.get("dth", [])
	for i in mini(dth.size(), players.size()):
		var pd := int(pdth[i]) if i < pdth.size() else int(dth[i])
		if int(dth[i]) > pd:
			var at := Vector3.ZERO
			if _fighters[i] != null:
				at = _fighters[i].global_position
			Sfx.play("splat")
			Sfx.play("death")
			_spawn_death_fx(at, players[i].color)
			if not _reduced_motion():
				_shake = maxf(_shake, 0.5)
				# DECIDING MOMENT on the mirror (§8.2): alive flags in this same
				# snapshot say whether that fall left one body standing
				if _living_count() <= 1 and players.size() >= 2:
					_time_hit(0.25, 0.8)
					FinalStretch.fov_punch(cam, 52.0, 6.0, 0.8)
				else:
					_time_hit(0.5, 0.2)
	# --- ghosts + THE FURNITURE possession glow
	_mir_apply_ghosts(state.get("g", []), prev.get("g", []))
	# --- scoreboard facts
	if state.get("sc", []) != prev.get("sc", []) or state.get("gk", []) != prev.get("gk", []) \
			or state.get("g", []) != prev.get("g", []) or state.get("f", []).size() != pfs.size():
		var sc: Array = state.get("sc", [])
		var gk: Array = state.get("gk", [])
		for i in mini(sc.size(), players.size()):
			players[i].total = int(sc[i])
			if i < gk.size():
				players[i].ghost_kills = int(gk[i])
		_rebuild_scoreboard()
	# --- the money shot receipt: a possessed prop just slammed a living body
	if int(state.get("gh", 0)) > int(prev.get("gh", 0)):
		_mir_snap_once("dw_mirror_ghosthit")
	# --- champion confetti (the banner itself rides the state)
	if phase == Phase.DONE and not _mir_done:
		var champ := int(state.get("champ", -1))
		if champ >= 0 and champ < players.size():
			_mir_done = true
			Sfx.play("match_win")
			_spawn_confetti(_spawns[champ % _spawns.size()] + Vector3(0, 1.2, 0), players[champ].color)


func _mir_round_reset(ri: int) -> void:
	round_index = ri
	_house_asleep()
	_clear_ghosts()
	var darken := ri * 0.22
	for prop in _props:
		(prop as DWProp).net_round_reset(darken)
	_refresh_hint()


## Ghost lifecycle + possession glow, from the mirrored per-seat ghost rows.
func _mir_apply_ghosts(gs: Array, pgs: Array) -> void:
	for i in players.size():
		var b := i * 5
		if b + 4 >= gs.size():
			break
		var on := int(gs[b]) == 1
		var pos := Vector3(float(gs[b + 1]), float(gs[b + 2]), float(gs[b + 3]))
		if on and not _ghosts.has(i):
			_spawn_ghost(i, pos)
			var ng: DWGhost = _ghosts[i]
			ng.set_physics_process(false)   # a wisp puppet — never free-flies
			ng.global_position = pos
			_refresh_hint()
		elif not on and _ghosts.has(i):
			var og: DWGhost = _ghosts[i]
			og.force_release()
			og.queue_free()
			_ghosts.erase(i)
			_refresh_hint()
		if not on or not _ghosts.has(i):
			continue
		var g: DWGhost = _ghosts[i]
		var pidx := int(gs[b + 4])
		var ppidx := int(pgs[b + 4]) if b + 4 < pgs.size() else -1
		if pidx != ppidx:
			if ppidx >= 0 and ppidx < _props.size() and (_props[ppidx] as DWProp).possessed_by == i:
				(_props[ppidx] as DWProp).release()
				Sfx.play("card", -6.0)
			if pidx >= 0 and pidx < _props.size():
				(_props[pidx] as DWProp).possess(i, players[i].color)
				g.possessing = _props[pidx]
				Sfx.play("grudge", -2.0)
				_mir_snap_once("dw_mirror_possess")
			else:
				g.possessing = null


## CLIENT, per physics tick: glide every puppet toward its authoritative spot.
## Fighters (pos + pivot yaw + anim + rings), wisps (pos + pulse), FURNITURE
## (pos + slerped rotation — the lunge, the tumble). Wobble/glow on a possessed
## prop keeps running in prop.gd's own _physics_process (frozen body, live fx).
func _mirror_tick(delta: float) -> void:
	if _mir.is_empty():
		return
	var w := 1.0 - exp(-14.0 * delta)
	var fs: Array = _mir.get("f", [])
	for i in players.size():
		var b := i * 12
		if b + 11 >= fs.size():
			break
		var f: DWFighter = _fighters[i]
		if f == null or not f.alive:
			continue
		f.global_position = f.global_position.lerp(
			Vector3(float(fs[b + 1]), float(fs[b + 2]), float(fs[b + 3])), w)
		if f.model_pivot:
			f.model_pivot.rotation.y = lerp_angle(f.model_pivot.rotation.y, float(fs[b + 4]), w)
		f._set_anim(NET_ANIMS[clampi(int(fs[b + 5]), 0, NET_ANIMS.size() - 1)])
		f._shove_cd = maxf(0.0, f._shove_cd - delta)   # smooth ring fill between snaps
		f._hop_cd = maxf(0.0, f._hop_cd - delta)
		f._drive_rings(delta)
	var gs: Array = _mir.get("g", [])
	for i in players.size():
		var b := i * 5
		if b + 4 >= gs.size():
			break
		if not _ghosts.has(i):
			continue
		var g: DWGhost = _ghosts[i]
		g.global_position = g.global_position.lerp(
			Vector3(float(gs[b + 1]), float(gs[b + 2]), float(gs[b + 3])), w)
		if g._orb:
			var s := 1.0 + sin(game_time * 6.0) * 0.12
			g._orb.scale = Vector3(s, s, s)
	var ps: Array = _mir.get("pr", [])
	for k in _props.size():
		var b := k * 8
		if b + 7 >= ps.size():
			break
		var pr := _props[k] as DWProp
		pr.global_position = pr.global_position.lerp(
			Vector3(float(ps[b]), float(ps[b + 1]), float(ps[b + 2])), w)
		var tq := Quaternion(float(ps[b + 3]), float(ps[b + 4]), float(ps[b + 5]), float(ps[b + 6]))
		if tq.length_squared() > 0.5:
			var cq := pr.global_transform.basis.get_rotation_quaternion()
			pr.global_transform.basis = Basis(cq.slerp(tq.normalized(), w))


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
		pop.tween_property(banner, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## CLIENT: my aim against my own mirrored render (doc 10 §1.3) — the fling
## cursor anchors on my possessed prop, the shove cursor on my fighter.
func _net_aim() -> Dictionary:
	var my := NetSession.my_seat()
	var aim := Vector3.ZERO
	if my >= 0 and my < players.size():
		if _ghosts.has(my):
			var g: DWGhost = _ghosts[my]
			var anchor := g.global_position
			if g.possessing != null and is_instance_valid(g.possessing):
				anchor = g.possessing.global_position
			aim = PlayerInput.get_aim_dir(my, anchor, cam)
		elif _fighters[my] != null:
			aim = PlayerInput.get_aim_dir(my, _fighters[my].global_position, cam)
	return {"aim": aim, "aim_screen": Vector2.ZERO}


func _mir_snap_once(tag: String) -> void:
	if _mir_snaps.has(tag):
		return
	_mir_snaps[tag] = true
	VerifyCapture.snap(tag)


# ---------------------------------------------------------------- verify hooks
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.ROUND
