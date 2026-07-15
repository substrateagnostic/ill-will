extends Minigame
## LAST WILL — a funeral procession RACE where DYING IS A POWER.
## A linear 3-segment gauntlet over the dusk void: start chapel, winding
## graveyard path, THE CRYPT. First to the crypt inherits. Three lives each;
## every death FREEZES THE WHOLE WORLD for six seconds while the deceased
## drafts a will — one CURSE, written permanently into a named stretch of the
## course, installed in their color with a name plaque (authorship forever,
## like Par's traps). Out of lives, the dead drift alongside the procession
## on ghost pews and gust the living for royalties. Curse kills pay the
## author royalties and land in kill_events with cause = the curse slug.
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
##   --willrounds=N        override race count (1..5) for quick verification
##   --willtally           headless evidence mode: full bot match, fast-
##                         forwarded with dt pinned to 1/60, prints
##                         WILL_TALLY (wills/curse kills/finish times), quits
##   --willkill=T:P,...    force-eliminate player P at race-time T (race 1
##                         only; deterministic will-theater screenshots)
##   --willview=overview   park the camera high over the whole course
##   --willtest=squish     self-test: a stationary pawn vs an aimed boulder
##   --deadhint            seat 0 human with ONE life, dies at t=1 (ghost
##                         hint bar demo)
##   --shots=N,...         VerifyCapture PNG harness (global autoload)
##
## RULES DECISIONS:
## - Curses PERSIST across races (the course accretes malice, like Par's
##   hole). Nine named stretches; a full slate means new curses displace the
##   oldest resident of the offered stretch.
## - The will always fires while the race runs. If the crypt is reached
##   while a will is still queued, probate closes: no draft (Executor line).
## - Ghost gusts are nudges, ghost kills pay +1; curse kills pay +2.

enum Phase { WAITING, INTRO, RACE, WILL, RACE_END, MATCH_END }
enum WStep { DEATH_BEAT, REVEAL, CARDS, RESOLUTION, CLOSING }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

const LIVES := 3
const HARD_CAP := 135.0
const MAX_SCYTHES := 2       # active scythe curses (a wall of blades ends races)
const MAX_STONES := 3        # active stones ranks
const DRAFT_BUDGET := 6.0
const ROYALTY := 2               # curse kill -> author
const GUST_ROYALTY := 1          # ghost gust kill
const GUST_SPEED := 9.0
const GUST_IMPULSE := 4.4
const GUST_HIT_R := 1.8
const GUST_RANGE := 17.0

const CURSE_DEFS := {
	"scythe": {"title": "SUMMON THE SCYTHE", "desc": "A pendulum blade swings over this stretch until the estate settles.",
		"kill_line": "%s'S SCYTHE REAPS %s"},
	"grease": {"title": "GREASE THE FLAGSTONES", "desc": "This stretch loses all grip. Momentum keeps its own counsel.",
		"kill_line": "%s'S GREASE DELIVERS %s TO THE VOID"},
	"gale": {"title": "A GUST CORRIDOR", "desc": "A crosswind sweeps this stretch toward the void, on a schedule.",
		"kill_line": "%s'S GALE CARRIES %s OFF THE ROAD"},
	"stones": {"title": "RAISE THE DEAD", "desc": "A rank of gravestones blocks this stretch, save one gap.",
		"kill_line": "%s'S STONES DETAIN %s FOREVER"},
}

const EXEC_DRAFT := "The deceased has opinions about the route."
const EXEC_CRYPT := "The first to the crypt inherits. The estate finds this poetic."
const EXEC_GHOST := "Out of lives. Not out of influence."
const EXEC_PROBATE := "Probate closes at the crypt door. The grievance is noted."
const EXEC_DEPART := "The estate extends its condolences in advance."

var game_time := 0.0
var phase := Phase.WAITING
var rng := RandomNumberGenerator.new()
var _fx_rng := RandomNumberGenerator.new()   # camera shake only — NEVER gameplay
var bots: LWBots

var roster: Array = []
var players: Array = []            # {index,name,color,char_path,device,is_bot,total,
                                   #  alive,lives,best_x,checkpoint,finished,finish_time,
                                   #  deaths,deaths_this_race,curse_kills,races_won,deathless_win}
var pawns: Array = []              # index -> LWPawn
var ghosts: Dictionary = {}        # index -> LWGhostSeat
var course: LWCourse
var boulders: Array = []
var pendulums: Array = []          # base scythe gates (endless)
var walls: Array = []
var curses: Array = []             # installed LWCurse nodes
var spinner: LWSpinner
var _gusts: Array = []             # {node, pos, dir, traveled, hit, from}
var _boulder_lanes: Array = []     # {x, period, next_t, side}
var _curse_order := 0

var race_index := 0
var races_total := 3
var race_elapsed := 0.0
var _race_over := false
var _finisher := -1
var _intro_t := 0.0
var _re_t := 0.0                   # RACE_END sequencer time
var _re_events: Array = []         # {t, fn}
var _re_done_t := 0.0

# will theater
var _will: Dictionary = {}
var _will_queue: Array = []
var _nav_prev: Dictionary = {}
var _hand: LWHand
var _ui: LWWillUI
var _rig_home := Vector3.ZERO      # camera rig pos before the resolution pan

# camera
var _cam_zoom := 1.0
var _ghost_rail: Node3D

# THE FINAL STRETCH kit (doc 09 §Q1): the FINAL RACE is last will's stretch —
# every curse written across the night is on the road at once. Tense music
# from the final "RACE N" call + hard-cap ticks + timer pulse. Gated on
# fx_on() (not _tally) so the --willtally receipts never construct it.
var _stretch: FinalStretch = null

# meta
var _currency: Array = []
## Anthology kill ledger (module contract results.kill_events): each entry
## {killer: int, victim: int, cause: String}. killer -1 = environment/self;
## a shove/gust into the dusk credits the attacker; a death within 3s of a
## CURSE TOUCH credits the curse's author with cause = the curse slug.
var _kill_events: Array = []
var _highlights: Array = []

# modes
var _started := false
var _all_bots := false
var _tally := false
var _tally_stats := {"wills": 0, "races": 0, "curse_kills": 0, "gust_kills": 0,
	"deaths": 0, "gusts": 0, "finishes": []}
var _forced_kills: Array = []      # {t, p}
var _cli_players := 4
var _cli_seed := 1
var _races_override := 0
var _view_mode := ""               # "" | "overview"
var _test_mode := ""               # --willtest=squish
var _dead_hint_demo := false       # --deadhint: seat 0 human, 1 life, dies at t=1
var _shove_cue_probe := false      # --shovecue: snap the first shove's readability arc
var _shove_cue_done := false
var _test_fired := false
var _delta_cache := 0.016

# fx
var _shake := 0.0
var _time_token := 0
var _banner_token := 0
var _sub_token := 0
var _exec_token := 0
var _cam_base_fov := 52.0
var _last_hitstop := -99.0       # HIT KIT global one-at-a-time hitstop throttle (0.14s)
var _hitkit_cap := false         # --hitkitcap: stage the HIT KIT / cooldown-ring shots
var _cap_dir := "verify_out/hitkit"

var hud: LWRaceHud

## --- ONLINE (phase 2) --------------------------------------------------------
## House pattern (docs/verify/online-seance-VERIFY.md PATTERN NOTES): host sim
## untouched, _net_state() = one flat dict of PUBLIC facts pumped at 20 Hz,
## _net_apply() diffs + fires ALL juice from deltas, _mirror_tick() interpolates
## at 60 Hz. The couch shows the will draft PUBLICLY (one shared screen, cards
## and cursor visible to the whole room), so the mirror shows the same theater
## — no private channel; last will's only "secret" is who dies next.
## Persistent course state (CURSES with author plaques) rides as the complete
## ACTIVE set every snapshot, so a late-booting mirror rebuilds the whole
## accreted road, plaques included.
const NET_ANIMS := ["Idle", "Running_A", "Hit_A", "Jump_Idle", "Jump_Start",
	"Interact", "Cheer"]
const CURSE_KINDS := ["scythe", "grease", "gale", "stones"]
var _mirror := false
var _mir := {}                    # last applied snapshot (delta source)
var _mir_snaps := {}              # evidence snapshots fired once (probe runs)
var _mir_done := false            # champion beat fired
var _mir_frozen := false          # the mirrored world-freeze fact
var _mir_boulders := {}           # net_id -> LWBoulder replica
var _mir_will_open := false
var _mir_cards_up := false
var _mir_will_res := false
var _mir_clock := 0.0             # local draft-clock drain between snapshots
var _banner_col := "ffffff"       # wire fact: last banner/sub colors
var _sub_col := "ffffff"
var _net_champ := -1              # pre-announced one seq-beat before finished()
var _net_boulder_seq := 0
var _net_ghost_slot := {}         # seat -> pew slot (mirrors seat identically)
var _net_gust_n: Array = []       # per-seat cumulative gust count
var _net_gust_last: Array = []    # flat per-seat last gust [sx, sz, dx, dz]

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var cam_rig: Node3D = $CameraRig
@onready var banner: Label = $UI/Banner
@onready var sub_banner: Label = $UI/SubBanner
@onready var exec_label: Label = $UI/ExecutorLabel
@onready var race_label: Label = $UI/RaceLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var spawn_root: Node3D = $SpawnRoot

func _ready() -> void:
	_parse_args()
	_fx_rng.randomize()
	_build_world()
	banner.visible = false
	sub_banner.visible = false
	exec_label.visible = false
	_ui = LWWillUI.new()
	add_child(_ui)
	_hand = LWHand.new()
	spawn_root.add_child(_hand)
	_hand.visible = false
	hud = LWRaceHud.new()
	$UI.add_child(hud)
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
			_races_override = clampi(int(arg.trim_prefix("--willrounds=")), 1, 5)
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--willkill="):
			for pair in arg.trim_prefix("--willkill=").split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					_forced_kills.append({"t": float(kv[0]), "p": int(kv[1])})
		elif arg.begins_with("--willview="):
			_view_mode = arg.trim_prefix("--willview=")
		elif arg.begins_with("--willtest="):
			_test_mode = arg.trim_prefix("--willtest=")
		elif arg == "--deadhint":
			_dead_hint_demo = true
		elif arg == "--shovecue":
			_shove_cue_probe = true
			_all_bots = true
		elif arg == "--hitkitcap":
			_hitkit_cap = true
			_cli_players = 2
		elif arg.begins_with("--outdir="):
			_cap_dir = arg.trim_prefix("--outdir=")
	if _hitkit_cap:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://%s" % _cap_dir))
	if _dead_hint_demo:
		# seat 0 (KBM human) dies at t=1.0 with ONE life -> straight to the
		# ghost pew, so the dead-state hint bar is on screen
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

# ui_kit intro card (doc 14 nit 7): shown at load, real key fallback, auto-starts
# after 6s so bot soaks flow through.
const GAME_INTRO := {
	"name": "LAST WILL",
	"goal": "A funeral race where DYING IS A POWER. Three lives each — first body to the crypt inherits.",
	"accent": Color(0.72, 0.55, 0.95),
	"controls": [
		{"action": "move", "label": "RUN"},
		{"action": "a", "label": "SHOVE"},
		{"action": "b", "label": "HOP"},
	],
	"tips": [
		"Spend a life as a curse or a boulder to wreck the leaders, then respawn ahead.",
		"HOP the traps: pendulums, spinners, and the gust gates.",
		"First through the crypt door takes the estate.",
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
	if _started:
		return
	_started = true
	_mirror = bool(config.get("net_mirror", false))
	rng.seed = int(config.get("rng_seed", 1))
	races_total = 3
	if config.get("practice", false):
		races_total = 1
	if int(config.get("rounds", 3)) < 3:
		races_total = maxi(1, int(config.get("rounds", 3)))
	if _races_override > 0:
		races_total = _races_override
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
			"lives": LIVES,
			"best_x": 0.0,
			"checkpoint": 0,
			"finished": false,
			"finish_time": -1.0,
			"deaths": 0,
			"deaths_this_race": 0,
			"curse_kills": 0,
			"races_won": 0,
			"deathless_win": false,
		})
		var pawn := LWPawn.new()
		pawn.name = "Pawn%d" % i
		spawn_root.add_child(pawn)
		pawn.setup(i, players[i].color, players[i].name, load(char_path), self)
		pawn.died.connect(_on_pawn_died)
		pawns.append(pawn)
		_net_gust_n.append(0)
		_net_gust_last.append_array([0.0, 0.0, 0.0, 0.0])
	print("LW_BEGIN players=%d seed=%d races=%d bots=%s" % [players.size(),
		rng.seed, races_total, str(players.map(func(p): return p.is_bot))])
	if not _tally:
		_stretch = FinalStretch.attach(self, timer_label)
	hint_label.text = _controls_bar()
	hud.build(players)
	race_index = 0
	if _mirror:
		# RENDER MIRROR (spec §4.3, house pattern): no races, no bots, no rng
		# draws — the host owns every fact. The course, base hazards and HUD
		# were built by _ready from static consts, identical to the host's;
		# curses, boulders, ghosts and the will theater arrive as facts. Pawns
		# freeze into snapshot puppets (anim/rings driven by _mirror_tick).
		phase = Phase.WAITING
		race_label.text = ""
		for i in pawns.size():
			var pw: LWPawn = pawns[i]
			pw.freeze = true
			pw.set_physics_process(false)
			pw.set_process(false)
			pw.global_position = LWCourse.checkpoint_pos(0, i) + Vector3(-1.0, 0.0, 0.0)
		for pen in pendulums:   # blades ride streamed poses; telegraph is over
			pen._strip_mat.albedo_color.a = 0.10
			pen._strip_mat.emission_energy_multiplier = 0.5
		NetSession.set_aim_provider(_net_aim)
		print("LW_MIRROR boot players=%d my_seat=%d" % [players.size(), NetSession.my_seat()])
		return
	# NIT 7: intro card at load; headless tally/test/probe/capture keep sync start.
	if _tally or _test_mode != "" or _shove_cue_probe or _hitkit_cap:
		_start_race()
		if _hitkit_cap:
			_run_hitkit_cap()
	else:
		_intro_then(_start_race)

# ================================================================ world
func _build_world() -> void:
	# THE HOUSE LOOK -- MOONLIT funeral procession (core/env_kit.gd). The gauntlet
	# runs at night: a cool moon key rakes the pier, a warm fill stands in for the
	# lantern-lit cortege, ground fog hangs over the void, and the high-threshold
	# glow blooms the rail lanterns + the gold curse-stretch plaques (the hazards
	# that MUST pop) without touching the UI. Replaces the old FILMIC dusk-sky env
	# + hand-rolled DuskSun/MoonFill.
	var rig := EnvKit.apply(self, EnvKit.MOONLIT, {
		"fill_energy": 0.30,     # warmer pier fill -- the lantern-lit procession
		"fog_density": 0.008,    # thinner than base so hazard plaques read down-course
	})
	var env: Environment = rig["environment"]

	cam.position = Vector3(0, 13.9, 11.8)
	cam.fov = _cam_base_fov
	cam_rig.position = Vector3(2.0, 0.0, 0.0)
	cam.look_at_from_position(cam_rig.position + cam.position,
		cam_rig.position + Vector3(0, 0.2, -0.7), Vector3.UP)

	# (key + warm fill are the EnvKit MOONLIT rig, applied above)

	# the void has a floor of dusk, not pure black: a deep-purple sea far
	# below that silhouettes falling bodies, running the length of the course
	var sea := MeshInstance3D.new()
	var seam := BoxMesh.new()
	seam.size = Vector3(520.0, 0.3, 260.0)
	sea.mesh = seam
	var sea_mat := StandardMaterial3D.new()
	sea_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sea_mat.albedo_color = Color(0.085, 0.05, 0.13)
	sea.material_override = sea_mat
	sea.position = Vector3(99.0, -26.0, 0.0)
	$Arena.add_child(sea)

	course = LWCourse.new()
	course.name = "Course"
	$Arena.add_child(course)
	course.build()

	# base hazard installations (ticked only while the race runs)
	for gx in LWCourse.PENDULUM_GATES:
		var pen := LWPendulum.new()
		spawn_root.add_child(pen)
		pen.setup(Vector3(float(gx), 0.0, LWCourse.z_center(float(gx))), 90.0, -1, self)
		pendulums.append(pen)
	spinner = LWSpinner.new()
	spawn_root.add_child(spinner)
	spinner.setup(Vector3(LWCourse.SPINNER_X, 0.0, LWCourse.z_center(LWCourse.SPINNER_X)), self)
	for wi in LWCourse.WALL_XS.size():
		var wx := float(LWCourse.WALL_XS[wi])
		var wall := LWWall.new()
		spawn_root.add_child(wall)
		wall.setup(Vector3(wx, 0.0, LWCourse.z_center(wx)), LWCourse.half_width(wx), self,
			0.0 if wi % 2 == 0 else PI * 0.7)
		walls.append(wall)

	# drifting embers follow the camera rig so dusk travels with the race
	var p := CPUParticles3D.new()
	p.name = "Embers"
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 6.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(16, 2, 12)
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
	p.position.y = -2.0
	p.emitting = true
	cam_rig.add_child(p)

	_ghost_rail = Node3D.new()
	_ghost_rail.name = "GhostRail"
	spawn_root.add_child(_ghost_rail)

	if _view_mode == "overview":
		# a hero survey: from over the chapel, down the length of the route,
		# the crypt glowing at the vanishing point
		cam_rig.position = Vector3.ZERO
		cam.position = Vector3(-14.0, 26.0, 30.0)
		cam.look_at_from_position(cam.position, Vector3(78.0, -2.0, -6.0), Vector3.UP)
		cam.fov = 58.0
		env.fog_enabled = false   # the survey shot reads the whole route

## Solid-road query used by pawns (anti-tunnel + void grace) and boulders.
func over_ground(pos: Vector3) -> bool:
	return LWCourse.over_ground(pos.x, pos.z)

# ================================================================ races
func _start_race() -> void:
	# NOTE: no wall-clock stamp here — game_time carries a startup offset that
	# varies run to run (scene load frames); race_elapsed stamps are the
	# deterministic ones, and the tally receipt must stay byte-identical.
	print("LW_RACE_START %d/%d curses=%d" % [race_index + 1, races_total, curses.size()])
	phase = Phase.INTRO
	_intro_t = 0.0
	race_elapsed = 0.0
	_race_over = false
	_finisher = -1
	_clear_transients()
	_clear_ghosts()
	_seed_boulder_lanes()
	var n := players.size()
	for i in n:
		players[i].alive = true
		players[i].lives = LIVES
		if _dead_hint_demo and i == 0:
			players[i].lives = 1
		players[i].best_x = 0.0
		players[i].checkpoint = 0
		players[i].finished = false
		players[i].finish_time = -1.0
		players[i].deaths_this_race = 0
		pawns[i].revive(LWCourse.checkpoint_pos(0, i) + Vector3(-1.0, 0.0, 0.0))
		pawns[i].set_world_frozen(true)
	race_label.text = "RACE %d / %d" % [race_index + 1, races_total]
	_refresh_hint()
	# THE FINAL STRETCH (doc 09 §Q1): the last race runs TENSE start to finish —
	# the whole night's curses are on the road. Earlier races re-arm the light bed.
	if _stretch != null:
		if race_index >= races_total - 1 and races_total > 1:
			_stretch.escalate()
		else:
			_stretch.round_reset()
	if not _tally:
		_flash_banner("RACE %d\nFIRST TO THE CRYPT INHERITS" % (race_index + 1), Color(1, 0.85, 0.2), 2.0)
		if race_index == 0:
			_flash_exec(EXEC_DEPART, 3.4)
		elif race_index >= races_total - 1 and races_total > 1:
			_flash_exec("The final race. The estate settles all accounts tonight.", 3.4)
		elif curses.size() > 0:
			_flash_sub("THE COURSE REMEMBERS — %d CURSES ACTIVE" % curses.size(), Color(0.7, 1.0, 0.7), 2.6)

func _seed_boulder_lanes() -> void:
	_boulder_lanes.clear()
	var periods := [5.0, 6.2, 5.6]
	for i in LWCourse.BOULDER_LANES.size():
		_boulder_lanes.append({
			"x": float(LWCourse.BOULDER_LANES[i]),
			"period": float(periods[i % periods.size()]),
			"next_t": 2.0 + rng.randf_range(0.0, 1.4) + 1.3 * float(i),
			"side": 1 if rng.randi_range(0, 1) == 0 else -1,
		})

func _clear_transients() -> void:
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

# ================================================================ tick
func _physics_process(delta: float) -> void:
	if _mirror:
		_mirror_tick(delta)
		return
	game_time += delta
	if _shake > 0.001:
		cam.h_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.3
		cam.v_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.3
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	match phase:
		Phase.INTRO:
			_intro_t += delta
			_update_camera(delta)
			if _intro_t >= (0.2 if _tally else 1.8):
				phase = Phase.RACE
				_set_frozen(false)
				if not _tally:
					_flash_sub("WALK WITH PURPOSE", Color(0.9, 0.95, 1.0), 1.4)
		Phase.RACE:
			_tick_race(delta)
			_update_camera(delta)
		Phase.WILL:
			_tick_will(delta)
		Phase.RACE_END:
			_tick_race_end(delta)
		_:
			pass

func _process(delta: float) -> void:
	if hud != null and not players.is_empty():
		hud.refresh(delta)

func _tick_race(delta: float) -> void:
	race_elapsed += delta
	_update_timer_label()

	# forced kills (screenshot determinism / dead-hint demo)
	if race_index == 0:
		for fk in _forced_kills:
			if not fk.get("done", false) and race_elapsed >= float(fk.t):
				fk["done"] = true
				var p: int = int(fk.p)
				if p >= 0 and p < pawns.size() and pawns[p].alive:
					print("LW_FORCEKILL p=%d t=%.1f" % [p, race_elapsed])
					pawns[p]._die("void")
					return

	# reset terrain mods, then let the curses re-apply them
	for pawn in pawns:
		if pawn.alive:
			pawn.terrain_speed = 1.0
			pawn.terrain_accel = 1.0
	for cu in curses:
		cu.tick(delta)

	# base hazards
	_tick_boulder_lanes(delta)
	for pen in pendulums:
		pen.tick(delta)
	spinner.tick(delta)
	for w in walls:
		w.tick(delta)
	for b in boulders:
		b.tick(delta)
	_prune_boulders()
	_tick_gusts(delta)

	# drive racers + ghosts
	for i in players.size():
		if players[i].alive:
			if _test_mode == "":
				_drive_pawn(i, delta)
		elif ghosts.has(i):
			_drive_ghost(i, delta)

	if _test_mode != "":
		_tick_test(delta)

	if phase != Phase.RACE:
		return  # a death mid-loop flipped us into WILL

	# progress + checkpoints + the crypt
	for i in players.size():
		if not players[i].alive or players[i].finished:
			continue
		var px: float = pawns[i].global_position.x
		if px > float(players[i].best_x):
			players[i].best_x = px
			for ci in range(LWCourse.CHECKPOINTS.size() - 1, -1, -1):
				if px >= float(LWCourse.CHECKPOINTS[ci]):
					if ci > int(players[i].checkpoint):
						players[i].checkpoint = ci
						pawns[i].safe_spawn = LWCourse.checkpoint_pos(ci, i)
						if not _tally:
							_flash_sub("%s CLAIMS THE CHECKPOINT" % players[i].name, players[i].color, 1.3)
							Sfx.play("confirm", -8.0)
						print("LW_CHECKPOINT %s cp=%d t=%.1f" % [players[i].name, ci, race_elapsed])
					break
		if px >= LWCourse.FINISH_X:
			_on_finish(i)
			return

	_update_ghost_rail()

	# tally trace: positions every 20s so stalls are visible in the receipt
	if _tally and int(race_elapsed / 20.0) != int((race_elapsed - delta) / 20.0):
		var bits: Array = []
		for i in players.size():
			bits.append("%s@%.1f%s" % [players[i].name, pawns[i].global_position.x,
				"" if players[i].alive else "(dead)"])
		print("LW_TRACE race=%d t=%.0f %s" % [race_index + 1, race_elapsed, " ".join(bits)])

	if race_elapsed >= HARD_CAP:
		print("LW_TIMEOUT race=%d" % (race_index + 1))
		_end_race()

func _tick_boulder_lanes(delta: float) -> void:
	if _test_mode != "":
		return
	for lane in _boulder_lanes:
		if race_elapsed < float(lane.next_t):
			continue
		lane.next_t = race_elapsed + float(lane.period) + rng.randf_range(0.0, 1.4)
		lane.side = -int(lane.side)
		var lx := float(lane.x)
		var zc := LWCourse.z_center(lx)
		var hw := LWCourse.half_width(lx)
		var side := float(lane.side)
		var start := Vector3(lx, 0.0, zc + side * (hw + 5.5))
		var b := LWBoulder.new()
		spawn_root.add_child(b)
		b.setup(start, Vector2(0.0, -side), (hw + 5.5) * 2.0 + 3.0,
			Vector3(lx, 0.0, zc), hw * 2.0 + 2.0, self)
		# ONLINE wire facts (memory-only): id + spawn params, so mirrors run
		# the same deterministic roll from the same lane fact
		b.net_id = _net_boulder_seq
		_net_boulder_seq += 1
		b.set_meta("net_spawn", [snappedf(start.x, 0.01), snappedf(start.z, 0.01),
			0.0, -side, (hw + 5.5) * 2.0 + 3.0, lx, zc, hw * 2.0 + 2.0])
		boulders.append(b)

func _prune_boulders() -> void:
	for i in range(boulders.size() - 1, -1, -1):
		if boulders[i].is_done():
			boulders[i].queue_free()
			boulders.remove_at(i)

func _drive_pawn(i: int, delta: float) -> void:
	var pawn: LWPawn = pawns[i]
	if players[i].is_bot:
		var d: Dictionary = bots.decide_racer(i, self, pawn, delta)
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
		# (KBM) or right stick (pad). The ghost seat never steers, so the LEFT channel
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

# ================================================================ camera
func _update_camera(delta: float) -> void:
	if _view_mode == "overview" or _hitkit_cap:
		return
	var min_x := 1e9
	var max_x := -1e9
	var racers := 0
	for i in players.size():
		if players[i].alive and not players[i].finished:
			var px: float = pawns[i].global_position.x
			min_x = minf(min_x, px)
			max_x = maxf(max_x, px)
			racers += 1
	if racers == 0:
		return
	var spread := max_x - min_x
	var focus_x := (min_x + max_x) * 0.5
	if spread > 26.0:
		focus_x = max_x - 13.0    # the front of the procession matters most
	var zoom_target := clampf(spread / 20.0, 1.0, 1.45)
	_cam_zoom = lerpf(_cam_zoom, zoom_target, 1.0 - exp(-3.0 * delta))
	var target := Vector3(focus_x + 2.0, 0.0, LWCourse.z_center(focus_x) * 0.6)
	cam_rig.position = cam_rig.position.lerp(target, 1.0 - exp(-4.0 * delta))
	cam.position = Vector3(0.0, 13.9 * _cam_zoom, 11.8 * _cam_zoom)
	cam.look_at_from_position(cam_rig.position + cam.position,
		cam_rig.position + Vector3(0, 0.2, -0.7), Vector3.UP)

func _update_ghost_rail() -> void:
	if _ghost_rail != null:
		_ghost_rail.position = Vector3(cam_rig.position.x,
			0.0, LWCourse.z_center(cam_rig.position.x))

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
	# ONLINE wire fact (memory-only): counter + spawn row for the mirror
	_net_gust_n[i] += 1
	_net_gust_last[i * 4] = snappedf(start.x, 0.01)
	_net_gust_last[i * 4 + 1] = snappedf(start.z, 0.01)
	_net_gust_last[i * 4 + 2] = snappedf(dir3.x, 0.01)
	_net_gust_last[i * 4 + 3] = snappedf(dir3.z, 0.01)
	Sfx.play("bounce", -7.0, 0.2)
	_tally_stats.gusts += 1
	print("LW_GUST from=%s t=%.1f" % [players[i].name, race_elapsed])

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

# ================================================================ self-tests
func _tick_test(_delta: float) -> void:
	_delta_cache = _delta
	match _test_mode:
		"squish":
			# a stationary pawn 0 must be flattened by a boulder aimed down
			# its lane — proves the squish path end to end on the new course
			if not _test_fired and race_elapsed >= 1.0:
				_test_fired = true
				var pp: Vector3 = pawns[0].global_position
				var b := LWBoulder.new()
				spawn_root.add_child(b)
				b.setup(Vector3(pp.x - 10.0, 0.0, pp.z), Vector2(1.0, 0.0), 24.0,
					Vector3(pp.x - 2.0, 0.0, pp.z), 12.0, self)
				boulders.append(b)
				print("WILLTEST squish: boulder launched at pawn0 x=%.2f" % pp.x)
			if _test_fired and boulders.size() > 0 and int(race_elapsed * 2.0) != int((race_elapsed - _delta_cache) * 2.0):
				var rp: Vector3 = boulders[0].rock_pos()
				print("WILLTEST trace rock=(%.2f,%.2f,%.2f) state=%d pawn=(%.2f,%.2f,%.2f) grounded=%s" % [
					rp.x, rp.y, rp.z, boulders[0].state,
					pawns[0].global_position.x, pawns[0].global_position.y, pawns[0].global_position.z,
					str(pawns[0].is_grounded())])
			if race_elapsed > 12.0:
				print("WILLTEST squish RESULT: FAIL (pawn survived)")
				get_tree().quit(1)

func _test_note_death(cause: String) -> void:
	if _test_mode == "squish":
		if cause == "squish":
			print("WILLTEST squish RESULT: PASS (t=%.2f)" % race_elapsed)
			get_tree().quit(0)
		else:
			print("WILLTEST squish RESULT: FAIL (died of %s)" % cause)
			get_tree().quit(1)

# ================================================================ death
func _on_pawn_died(index: int, cause: String) -> void:
	if _test_mode != "":
		_test_note_death(cause)
		return
	if phase == Phase.MATCH_END or phase == Phase.RACE_END:
		return
	players[index].alive = false
	players[index].lives = maxi(0, int(players[index].lives) - 1)
	players[index].deaths += 1
	players[index].deaths_this_race += 1
	_tally_stats.deaths += 1

	# attribution: player action > curse authorship > environment
	var pawn: LWPawn = pawns[index]
	var line := "THE VOID CLAIMS %s" % players[index].name
	var lcolor := Color(0.65, 0.8, 1.0)
	var kev_killer := -1
	var kev_cause := cause      # "void" | "squish"
	var atk: Dictionary = pawn.last_attacker
	var atk_recent: bool = atk.size() > 0 and (game_time - float(atk.get("time", -99.0))) <= 3.0
	var cur: Dictionary = pawn.last_curse
	var cur_recent: bool = cur.size() > 0 and (game_time - float(cur.get("time", -99.0))) <= 3.0
	if cause == "squish":
		line = "THE BOULDER FLATTENS %s" % players[index].name
		lcolor = Color(0.85, 0.75, 0.6)
	else:
		var handled := false
		if atk_recent:
			var ai := int(atk.get("index", -1))
			match str(atk.get("type", "")):
				"shove":
					if ai >= 0 and ai != index:
						line = "%s SHOVES %s INTO THE DUSK" % [players[ai].name, players[index].name]
						lcolor = players[ai].color
						kev_killer = ai
						kev_cause = "shove"
						_highlights.append("%s shoved %s into the dusk" % [players[ai].name, players[index].name])
						handled = true
				"gust":
					if ai >= 0 and ai != index:
						line = "%s'S GUST USHERS %s OFF THE ROAD" % [players[ai].name, players[index].name]
						lcolor = players[ai].color
						kev_killer = ai
						kev_cause = "gust"
						_currency.append({"type": "royalty", "player": ai, "amount": GUST_ROYALTY,
							"reason": "gust kill from beyond"})
						_tally_stats.gust_kills += 1
						_highlights.append("%s, already dead, gusted %s into the void" % [players[ai].name, players[index].name])
						handled = true
				_:
					pass
		if not handled and cur_recent:
			var author := int(cur.get("author", -1))
			var slug := str(cur.get("slug", ""))
			if author >= 0 and CURSE_DEFS.has(slug):
				kev_killer = author
				kev_cause = slug
				line = str(CURSE_DEFS[slug].kill_line) % [players[author].name, players[index].name]
				lcolor = players[author].color
				if author != index:
					players[author].curse_kills += 1
					_currency.append({"type": "royalty", "player": author, "amount": ROYALTY,
						"reason": "curse kill (%s)" % slug})
					_tally_stats.curse_kills += 1
					_highlights.append("%s's %s curse claimed %s" % [players[author].name, slug, players[index].name])
					if not _tally:
						_flash_sub("ROYALTIES TO %s +%d" % [players[author].name, ROYALTY],
							players[author].color, 1.8)
				handled = true
		if not handled and atk_recent:
			match str(atk.get("type", "")):
				"pendulum":
					line = "THE PENDULUM SWATS %s INTO THE DUSK" % players[index].name
					lcolor = Color(1.0, 0.5, 0.4)
					kev_cause = "pendulum"
				"spinner":
					line = "THE SWEEPER ESCORTS %s OFF THE ROAD" % players[index].name
					lcolor = Color(0.9, 0.7, 0.4)
					kev_cause = "spinner"
				_:
					pass
	_kill_events.append({"killer": kev_killer, "victim": index, "cause": kev_cause})
	print("LW_DEATH race=%d t=%.1f %s cause=%s lives_left=%d" % [race_index + 1,
		race_elapsed, line, kev_cause, int(players[index].lives)])

	if not _tally:
		Sfx.play("splat")
		Sfx.play("death")
		_spawn_burst(pawn.global_position + Vector3(0, 0.4, 0), players[index].color, 30)
		_shake = maxf(_shake, 0.5)
		# THE DECIDING MOMENT (doc 09 §10.2/§Q2): a death that leaves <=1 racer
		# with lives gets the deep freeze (the will theater's own -6 fov beat
		# follows it); ordinary deaths demote to 0.5x/0.2s.
		if _racers_with_lives() <= 1 and players.size() >= 2 and not _reduced_motion():
			_time_hit(0.25, 0.9)
		else:
			_time_hit(0.5, 0.2)
	_flash_banner(line, lcolor, 1.6)

	_will_queue.append(index)
	if phase == Phase.RACE:
		phase = Phase.WILL
		_set_frozen(true)
		_begin_will(_will_queue.pop_front())

func _set_frozen(v: bool) -> void:
	for pawn in pawns:
		if pawn.alive:
			pawn.set_world_frozen(v)

## Racers still in contention: lives left and not yet through the crypt door.
## The death that drops this to <=1 is the race-deciding one (doc 09 §10.2).
func _racers_with_lives() -> int:
	var n := 0
	for p in players:
		if int(p.lives) > 0 and not bool(p.finished):
			n += 1
	return n

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
					"kind": c.kind,
					"title": CURSE_DEFS[c.kind].title,
					"desc": CURSE_DEFS[c.kind].desc,
					"zone": "UPON %s" % str(c.slot.name),
					"replaces": str(c.replaces),
				}))
				_will.sel = 0
				_ui.set_card_sel(0)
				_will.step = WStep.CARDS
				_will.t = 0.0
				_will.clock = DRAFT_BUDGET
				_will.bot_goal = bots.draft_card(p, self, _will.cards) if _will.bot else -1
				_will.bot_t = 0.0
				VerifyCapture.snap("draft")
		WStep.CARDS:
			_will.clock -= delta
			_ui.set_timer(_will.clock / DRAFT_BUDGET, _will.clock)
			if _will.clock <= 0.0:
				_will.card = _will.sel
				_resolve_will()
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
				_resolve_will()
		WStep.RESOLUTION:
			if _will.t >= (0.35 if _tally else 2.6):
				_will.step = WStep.CLOSING
				_will.t = 0.0
				_ui.close()
				_hand.visible = false
				if not _tally:
					var tw := create_tween()
					tw.tween_property(cam, "fov", _cam_base_fov, 0.4).set_trans(Tween.TRANS_SINE)
					var tw2 := create_tween()
					tw2.tween_property(cam_rig, "position", _rig_home, 0.5) \
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		WStep.CLOSING:
			if _will.t >= (0.1 if _tally else 0.6):
				_set_base_ui(true)
				_after_will(p)

func _after_will(p: int) -> void:
	if int(players[p].lives) > 0 and not _race_over:
		players[p].alive = true
		pawns[p].revive(LWCourse.checkpoint_pos(int(players[p].checkpoint), p))
		pawns[p].set_world_frozen(true)   # stays held until the race resumes
	elif int(players[p].lives) <= 0:
		_seat_ghost(p)
		if not _tally:
			_flash_exec(EXEC_GHOST, 2.8)
	_will = {}
	if not _will_queue.is_empty():
		_begin_will(_will_queue.pop_front())
		return
	if _race_over:
		_end_race()
		return
	# the procession has run out of living marchers: nothing left to race
	var any_alive := false
	for pl in players:
		if pl.alive:
			any_alive = true
			break
	if not any_alive:
		print("LW_ALL_GHOSTS race=%d t=%.1f" % [race_index + 1, race_elapsed])
		if not _tally:
			_flash_banner("THE PROCESSION IS ENTIRELY DECEASED", Color(0.7, 0.75, 0.9), 2.2)
		_end_race()
		return
	phase = Phase.RACE
	_set_frozen(false)

## Three curse cards: seeded kinds over seeded stretches, free slots first.
## A fully-cursed slate offers displacement of the oldest resident instead.
func _draw_cards() -> Array:
	# kind caps: a course of nothing but blades is unfinishable
	var scythes := 0
	var stones := 0
	for cu0 in curses:
		if cu0.kind == "scythe":
			scythes += 1
		elif cu0.kind == "stones":
			stones += 1
	var kinds: Array = ["grease", "gale"]
	if scythes < MAX_SCYTHES:
		kinds.append("scythe")
	if stones < MAX_STONES:
		kinds.append("stones")
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = kinds[i]; kinds[i] = kinds[j]; kinds[j] = tmp
	var taken := {}
	for cu in curses:
		taken[int(cu.slot.id)] = cu
	var free_slots: Array = []
	var used_slots: Array = []
	for s in LWCourse.SLOTS:
		if taken.has(int(s.id)):
			used_slots.append(s)
		else:
			free_slots.append(s)
	for i in range(free_slots.size() - 1, 0, -1):
		var j2 := rng.randi_range(0, i)
		var tmp2: Dictionary = free_slots[i]; free_slots[i] = free_slots[j2]; free_slots[j2] = tmp2
	# oldest residents first for the displacement offers
	used_slots.sort_custom(func(a, b):
		return int((taken[int(a.id)] as LWCurse).install_order) < int((taken[int(b.id)] as LWCurse).install_order))
	var offer_slots: Array = free_slots.slice(0, 3)
	var k := 0
	while offer_slots.size() < 3 and k < used_slots.size():
		offer_slots.append(used_slots[k])
		k += 1
	var cards: Array = []
	for i in offer_slots.size():
		var slot: Dictionary = offer_slots[i]
		var rep := ""
		if taken.has(int(slot.id)):
			var old: LWCurse = taken[int(slot.id)]
			rep = "%s's %s" % [old.author_name, old.title()]
		cards.append({"kind": kinds[i % kinds.size()], "slot": slot, "replaces": rep})
	return cards

func _resolve_will() -> void:
	var p: int = _will.player
	var card: Dictionary = _will.cards[clampi(int(_will.card), 0, _will.cards.size() - 1)]
	var slot: Dictionary = card.slot
	# displace any resident curse on this stretch
	for ci in range(curses.size() - 1, -1, -1):
		var old: LWCurse = curses[ci]
		if int(old.slot.id) == int(slot.id):
			print("LW_CURSE_DISPLACED %s's %s on %s" % [old.author_name, old.kind, str(slot.name)])
			old.queue_free()
			curses.remove_at(ci)
	var side_seed := rng.randi_range(0, 3)
	var cu := LWCurse.new()
	spawn_root.add_child(cu)
	cu.setup(slot, str(card.kind), p, players[p].name, players[p].color, side_seed, self)
	cu.install_order = _curse_order
	_curse_order += 1
	curses.append(cu)
	_tally_stats.wills += 1
	print("LW_WILL %s condemns %s with %s" % [players[p].name, str(slot.name), str(card.kind)])

	# THE SHOW, part two: the camera visits the condemned stretch while the
	# skeletal hand points it out and the curse rises from the sod.
	var lines: Array = [
		{"text": "%s CONDEMNS" % players[p].name, "color": players[p].color, "delay": 0.0},
		{"text": str(slot.name), "color": LWWillUI.GOLD, "delay": 0.55},
		{"text": "— %s —" % str(CURSE_DEFS[card.kind].title), "color": LWWillUI.GREEN, "delay": 1.1},
	]
	_ui.show_resolution(lines)
	Sfx.play("grudge", -1.0)
	if not _tally:
		cu.play_install()
		_rig_home = cam_rig.position
		var sc := LWCourse.slot_center(slot)
		var tw := create_tween()
		tw.tween_property(cam_rig, "position", Vector3(sc.x + 1.0, 0.0, sc.z * 0.6), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hand.visible = true
		_hand.scale = Vector3(2.6, 2.6, 2.6)   # zone-pointing reads from the pan distance
		_hand.global_position = sc + Vector3(0, 3.1, 1.2)
		_snap_after_pan()
	_will.step = WStep.RESOLUTION
	_will.t = 0.0

func _snap_after_pan() -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	VerifyCapture.snap("curse")

# ================================================================ ghosts
const SEAT_OFFSETS := [Vector3(-10.5, 1.0, -4.2), Vector3(10.5, 1.0, -4.2),
	Vector3(-10.5, 1.0, 5.2), Vector3(10.5, 1.0, 5.2)]

func _seat_ghost(i: int, pew := -1) -> void:
	# pew >= 0: the mirror seats the ghost on the HOST's pew (wire fact);
	# -1 keeps the couch's death-order seating, byte-identical to before.
	if ghosts.has(i):
		return
	var slot_i := pew if pew >= 0 else ghosts.size() % SEAT_OFFSETS.size()
	_net_ghost_slot[i] = slot_i
	var g := LWGhostSeat.new()
	g.name = "Ghost%d" % i
	_ghost_rail.add_child(g)
	g.setup(i, players[i].color, players[i].name, load(players[i].char_path),
		SEAT_OFFSETS[slot_i % SEAT_OFFSETS.size()], self)
	ghosts[i] = g
	_refresh_hint()
	print("LW_GHOST %s takes a pew (race %d)" % [players[i].name, race_index + 1])
	if not _tally:
		Sfx.play("grudge", -10.0, 0.2)

# ================================================================ race end
func _on_finish(i: int) -> void:
	players[i].finished = true
	players[i].finish_time = race_elapsed
	players[i].best_x = LWCourse.FINISH_X
	_race_over = true
	_finisher = i
	pawns[i].celebrate()
	var ft := "%d:%04.1f" % [int(race_elapsed / 60.0), fmod(race_elapsed, 60.0)]
	print("LW_FINISH race=%d winner=%s t=%.1f" % [race_index + 1, players[i].name, race_elapsed])
	_tally_stats.finishes.append("race %d: %s at %.1fs" % [race_index + 1, players[i].name, race_elapsed])
	_flash_banner("%s REACHES THE CRYPT\n%s" % [players[i].name, ft], players[i].color, 2.6)
	if not _tally:
		Sfx.play("match_win", -4.0)
		_flash_exec(EXEC_CRYPT, 4.0)
		_spawn_burst(pawns[i].global_position + Vector3(0, 1.2, 0), players[i].color, 30)
		VerifyCapture.snap("finish")
	# probate closes: pending drafts are dropped with regrets
	if not _will_queue.is_empty():
		_will_queue.clear()
		if not _tally:
			_flash_exec(EXEC_PROBATE, 3.0)
	_end_race()

func _end_race() -> void:
	phase = Phase.RACE_END
	_re_t = 0.0
	_re_events.clear()
	_clear_transients()
	for pawn in pawns:
		if pawn.alive:
			pawn.move_input = Vector2.ZERO
			pawn.want_shove = false
			pawn.want_hop = false
			pawn.set_world_frozen(true)

	# race placements: the finisher, then furthest progress, ties earlier index
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if bool(players[a].finished) != bool(players[b].finished):
			return bool(players[a].finished)
		if absf(float(players[a].best_x) - float(players[b].best_x)) > 0.01:
			return float(players[a].best_x) > float(players[b].best_x)
		return a < b)
	var pts := _points_table()
	for pos in order.size():
		if pos < pts.size():
			players[order[pos]].total += pts[pos]
	var last: int = order[order.size() - 1]
	_currency.append({"type": "grudge", "player": last, "amount": 1,
		"reason": "dead last in the procession"})
	if _finisher >= 0:
		players[_finisher].races_won += 1
		if int(players[_finisher].deaths_this_race) == 0:
			players[_finisher].deathless_win = true
			_highlights.append("%s reached the crypt without dying once" % players[_finisher].name)
	print("LW_RACE_END %d placements=%s totals=%s" % [race_index + 1,
		str(order.map(func(ix): return players[ix].name)),
		str(players.map(func(pl): return pl.total))])
	if not _tally:
		Sfx.play("round_over", -4.0)
		var bits: Array = []
		for ix in order:
			bits.append("%s %d" % [players[ix].name, players[ix].total])
		_re_events.append({"t": 1.8, "fn": Callable(self, "_standings_banner").bind(" · ".join(bits))})
	_re_done_t = 0.6 if _tally else 4.2
	# ONLINE: pre-announce the champion one seq-beat before _finish_match —
	# facts minted the same tick as report_finished() never reach mirrors
	# (masked-ball lesson). Totals are final right here; memory-only on the
	# couch, so tally receipts stay byte-identical.
	if race_index + 1 >= races_total:
		_re_events.append({"t": maxf(_re_done_t - 0.4, 0.0),
			"fn": Callable(self, "_net_mint_champ")})

func _standings_banner(text: String) -> void:
	_flash_sub("STANDINGS — %s" % text, Color(0.92, 0.9, 1.0), 2.4)

## The champion, computed exactly as _finish_match will 0.4 s later. Wire-only.
func _net_mint_champ() -> void:
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if players[a].total != players[b].total:
			return players[a].total > players[b].total
		return a < b)
	_net_champ = int(order[0])

func _tick_race_end(delta: float) -> void:
	_re_t += delta
	for ev in _re_events:
		if not ev.get("done", false) and _re_t >= float(ev.t):
			ev["done"] = true
			(ev.fn as Callable).call()
	if _re_t >= _re_done_t:
		race_index += 1
		if race_index >= races_total:
			_finish_match()
		else:
			_start_race()

func _points_table() -> Array:
	match players.size():
		2: return [3, 0]
		3: return [4, 2, 1]
		_: return [4, 2, 1, 0]

# ================================================================ match end
func _finish_match() -> void:
	phase = Phase.MATCH_END
	if _stretch != null:
		_stretch.match_ended()
	_tally_stats.races = races_total
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
		if int(players[i].curse_kills) >= 3:
			monuments.append({"player": i, "kind": "reaper",
				"label": "%s, Reaper of the Route" % players[i].name})
		if bool(players[i].deathless_win):
			monuments.append({"player": i, "kind": "untouched",
				"label": "%s, the Untouched Procession" % players[i].name})
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
	var problems := Minigame.validate_results(results, players.size())
	print("LW_VALIDATE problems=%d %s" % [problems.size(), str(problems)])
	if _tally:
		_print_tally()
		get_tree().quit()
		return
	_flash_banner("%s WINS LAST WILL" % players[champ].name, players[champ].color, 6.0)
	Sfx.play("match_win")
	_spawn_confetti(pawns[champ].global_position + Vector3(0, 1.2, 0), players[champ].color)
	report_finished(results)

func _print_tally() -> void:
	print("======== LAST WILL TALLY ========")
	print("WILL_TALLY seed=%d races=%d wills=%d curse_kills=%d gust_kills=%d deaths=%d gusts=%d" % [
		rng.seed, races_total, _tally_stats.wills, _tally_stats.curse_kills,
		_tally_stats.gust_kills, _tally_stats.deaths, _tally_stats.gusts])
	for f in _tally_stats.finishes:
		print("FINISH ", f)
	var bits: Array = []
	for i in players.size():
		bits.append("%s=%d" % [players[i].name, players[i].total])
	print("totals: %s" % " ".join(bits))
	print("TALLY_RESULT %s (target: every race reaches the crypt or the cap; wills>=races)" %
		("PASS" if _tally_stats.wills >= races_total else "CHECK"))
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

## The furthest-progressed living racer (ghost target), or -1.
func race_leader_alive() -> int:
	var best := -1
	for i in players.size():
		if not players[i].alive or players[i].finished:
			continue
		if best < 0 or float(players[i].best_x) > float(players[best].best_x):
			best = i
	return best

func race_leader_x() -> float:
	var best := 0.0
	for i in players.size():
		best = maxf(best, float(players[i].best_x))
	return best

## Scythe gates (base + curse) for the bots: world blade positions + travel.
func blade_gates() -> Array:
	var out: Array = []
	for pen in pendulums:
		var info: Dictionary = pen.blade_world_info()
		out.append({"x": pen.origin2.x, "z": pen.origin2.y + float(info.along),
			"y": float(info.y), "vs": float(info.vel_sign)})
	for cu in curses:
		if cu.kind == "scythe" and cu._pendulum != null:
			var info2: Dictionary = cu._pendulum.blade_world_info()
			out.append({"x": cu._pendulum.origin2.x,
				"z": cu._pendulum.origin2.y + float(info2.along), "y": float(info2.y),
				"vs": float(info2.vel_sign)})
	return out

func on_shove_landed(_pos: Vector3) -> void:
	_shake = maxf(_shake, 0.26)
	if _tally:
		return
	# LIVE: THE ILL WILL HIT KIT — layered thud on connect + (unless reduced-motion)
	# ONE throttled micro-hitstop (0.15 time_scale, 45ms).
	Sfx.play("bumper", -3.0)
	if not _reduced_motion() and game_time - _last_hitstop >= 0.14:
		_last_hitstop = game_time
		_time_hit(0.15, 0.045)

## Visual FX gate — OFF in the headless --willtally receipt run, so none of the
## HIT KIT / cooldown-ring code executes there (determinism receipt).
func fx_on() -> bool:
	return not _tally

func _reduced_motion() -> bool:
	return not bool(PartySetup.pref("screen_shake", true))

## HIT KIT §B1 spark burst — a one-shot cone of sparks along the knockback dir at
## the contact point (kept even under reduced-motion; a read, not a shake).
func spark_at(pos: Vector3, dir: Vector3, color: Color, strength := 1.0) -> void:
	if not fx_on():
		return
	var p := CPUParticles3D.new()
	spawn_root.add_child(p)
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
	if _mirror:
		return   # replicas roll for the eyes only; deaths are host facts
	if phase != Phase.RACE:
		return
	if not _tally:
		Sfx.play("crush", -2.0)
	pawn.squish()

func on_pendulum_hit(_i: int) -> void:
	_shake = maxf(_shake, 0.4)
	if not _tally:
		Sfx.play("bumper", -2.0)

func _set_base_ui(v: bool) -> void:
	race_label.visible = v
	timer_label.visible = v
	hint_label.visible = v
	hud.visible = v

const HINT_LIVING := "A = SHOVE   B = HOP   ·   DIE, AND CURSE THE ROAD"

## ---- live-binding hint bar (real keys, not "A"/"B"; docs/verify/realkeys-VERIFY.md) ----
## Self-contained per the template; presentation only. Bindings are fixed per
## match, so the living bar is built when begin()/_refresh_hint set it.

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). The
## living bar personalizes only these; an all-bot demo keeps HINT_LIVING.
func _human_seats() -> Array:
	var out := []
	for i in players.size():
		if not players[i].is_bot and PlayerInput.device_of(i) != -99:
			out.append(i)
	return out

## One button's live legend: "KEY = LABEL" when every human seat shares the key
## (all pads -> "(A) = SHOVE"), else the per-seat "LABEL: KEY/NAME · KEY/NAME" form.
func _btn_hint(action: String, label: String) -> String:
	var seats := _human_seats()
	if seats.is_empty():
		return ""
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

## The living hint bar with real keys, or HINT_LIVING for an all-bot demo (so
## bot-only tally receipts stay byte-identical).
func _controls_bar() -> String:
	if _human_seats().is_empty():
		return HINT_LIVING
	return "%s   ·   %s   ·   DIE, AND CURSE THE ROAD" % [
		_btn_hint("a", "SHOVE"), _btn_hint("b", "HOP")]

## Flip the shared hint bar to a dead-state legend when a HUMAN takes a ghost pew,
## so the dead know how to gust: aim with the RIGHT channel, A fires. Bots never
## trigger this (their seats stay HINT_LIVING), so the tally receipts are
## unchanged.
func _refresh_hint() -> void:
	if hint_label == null:
		return
	var dead_humans: Array = []
	for i in players.size():
		if not players[i].is_bot and ghosts.has(i):
			dead_humans.append(i)
	if dead_humans.is_empty():
		hint_label.text = _controls_bar()
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
	timer_label.text = "%d:%02d" % [int(race_elapsed / 60.0), int(fmod(race_elapsed, 60.0))]
	if _stretch != null and phase == Phase.RACE:
		_stretch.tick(HARD_CAP - race_elapsed)   # ladder into the hard cap
	if race_elapsed < HARD_CAP - 30.0:
		timer_label.add_theme_color_override("font_color", Color(0.85, 0.97, 1))
	else:
		var pulse := 0.6 + 0.4 * sin(race_elapsed * 8.0)
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.3 * pulse + 0.15, 0.2))

func _flash_banner(text: String, color: Color, duration: float) -> void:
	if _tally:
		return
	_banner_col = color.to_html(false)   # wire fact
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
	_sub_col = color.to_html(false)   # wire fact
	sub_banner.text = text
	sub_banner.add_theme_color_override("font_color", color)
	sub_banner.visible = true
	_sub_token += 1
	var my := _sub_token
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(Callable(self, "_hide_sub_if").bind(my))

## The Executor's dry registry line — Saki voice, never an exclamation mark.
func _flash_exec(text: String, duration: float) -> void:
	if _tally:
		return
	exec_label.text = "“%s” — THE EXECUTOR" % text
	exec_label.visible = true
	_exec_token += 1
	var my := _exec_token
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(Callable(self, "_hide_exec_if").bind(my))

func _hide_exec_if(token: int) -> void:
	if token == _exec_token:
		exec_label.visible = false

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

# ================================================================ HIT KIT capture
# --hitkitcap (windowed): stages each feel moment (shove coil+arc, victim impact
# with sparks+pop, cooldown-ring fill, ready-flash) with the race held, films it,
# then quits. Verify-only; no effect on a normal match or the --willtally receipt.
func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func _cap_shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("LW_HITKIT_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/last_will_%s.png" % [_cap_dir, tag]
	img.save_png(path)
	print("LW_HITKIT_CAP ", path)

func _run_hitkit_cap() -> void:
	while phase != Phase.RACE:
		await get_tree().physics_frame
	_clear_transients()
	# BLUE attacker (rings read clearly on the flagstones); RED victim. Staged
	# side-by-side on the start plaza at the same depth.
	var atk: LWPawn = pawns[1]     # BLUE attacker
	var vic: LWPawn = pawns[0]     # RED victim
	atk._cap_freeze = true
	vic._cap_freeze = true
	atk.freeze = true
	vic.freeze = true
	var atk_pos := Vector3(-4.2, 0.25, 1.5)
	var vic_pos := Vector3(-1.6, 0.25, 1.5)
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
	phase = Phase.WAITING     # hold the race sim; the two pawns are frozen
	cam_rig.position = Vector3(-2.5, 0.0, 0.0)
	cam.position = Vector3(0, 13.9, 11.8)
	cam.look_at_from_position(cam_rig.position + cam.position,
		cam_rig.position + Vector3(0, 0.2, -0.7), Vector3.UP)
	banner.visible = false
	sub_banner.visible = false
	_set_base_ui(false)
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
	vic.global_position = Vector3(8.0, 0.25, 0.0)
	atk.global_position = Vector3(-2.5, 0.25, 1.6)
	atk._shove_cd = LWPawn.SHOVE_CD * 0.45
	atk._hop_cd = LWPawn.HOP_CD * 0.45
	await _settle(0.14)
	await _cap_shot("hitkit_ring_fill")
	# 4) READY-FLASH — drive the SHOVE ring to full so it flashes bright
	atk._shove_cd = 0.04
	await _settle(0.06)
	atk._shove_cd = 0.0
	await _settle(0.05)
	await _cap_shot("hitkit_ring_ready")
	await _settle(0.15)
	print("LW_HITKIT_CAP_DONE")
	get_tree().quit()

# ================================================================ ONLINE (phase 2)
# Ask of every key: is this on every couch player's screen right now? Racer
# poses, hearts, checkpoints, curses with authorship, the will theater (public
# on the couch), hazard poses, HUD strings — yes. Nothing else enters.

## HOST, pumped by the estate at 20 Hz.
func _net_state() -> Dictionary:
	var fs: Array = []
	for pawn in pawns:
		fs.append(1 if pawn.alive else 0)
		fs.append(1 if pawn.visible else 0)
		fs.append(snappedf(pawn.global_position.x, 0.01))
		fs.append(snappedf(pawn.global_position.y, 0.01))
		fs.append(snappedf(pawn.global_position.z, 0.01))
		fs.append(snappedf(pawn.model_pivot.rotation.y, 0.01) if pawn.model_pivot else 0.0)
		fs.append(maxi(NET_ANIMS.find(pawn._cur_anim), 0))
		fs.append(snappedf(maxf(pawn._shove_cd, 0.0), 0.02))
		fs.append(snappedf(maxf(pawn._hop_cd, 0.0), 0.02))
		fs.append(pawn.net_hits)
		fs.append(snappedf(pawn.net_hit_dir.x, 0.01))
		fs.append(snappedf(pawn.net_hit_dir.z, 0.01))
		fs.append(pawn.net_shoves)
	var lv: Array = []
	var bx: Array = []
	var cps: Array = []
	var fin: Array = []
	var tot: Array = []
	var dts: Array = []
	for p in players:
		lv.append(int(p.lives))
		bx.append(snappedf(float(p.best_x), 0.1))
		cps.append(int(p.checkpoint))
		fin.append(1 if p.finished else 0)
		tot.append(int(p.total))
		dts.append(int(p.deaths))
	var gh: Array = []
	for i in players.size():
		if ghosts.has(i) and is_instance_valid(ghosts[i]):
			var g: LWGhostSeat = ghosts[i]
			gh.append_array([1, int(_net_ghost_slot.get(i, 0)),
				snappedf(g.aim_dir.x, 0.02), snappedf(g.aim_dir.y, 0.02),
				snappedf(maxf(g.gust_cd, 0.0), 0.05)])
		else:
			gh.append_array([0, 0, 0.0, 0.0, 0.0])
	var hz: Array = []
	for pen in pendulums:
		hz.append(snappedf(pen._blade.rotation.z, 0.005))
		hz.append(snappedf(pen._pivot.position.y, 0.02))
	hz.append(snappedf(spinner._angle, 0.005))
	for w in walls:
		hz.append(snappedf(w._phase, 0.005))
	var bo: Array = []
	for b in boulders:
		if b.net_id < 0 or not b.has_meta("net_spawn"):
			continue
		bo.append_array([b.net_id, int(b.state), snappedf(b._traveled, 0.05)])
		bo.append_array(b.get_meta("net_spawn"))
	var cu: Array = []
	for c in curses:
		var aux1 := 0.0
		var aux2 := 0.0
		if c.kind == "scythe" and c._pendulum != null:
			aux1 = snappedf(c._pendulum._blade.rotation.z, 0.005)
			aux2 = snappedf(c._pendulum._pivot.position.y, 0.02)
		elif c.kind == "gale":
			aux1 = snappedf(fmod(c._t, LWCurse.GALE_PERIOD), 0.05)
		cu.append_array([int(c.install_order), int(c.slot.id),
			maxi(CURSE_KINDS.find(c.kind), 0), int(c.author), int(c.side_seed),
			aux1, aux2])
	var wi: Array
	var wc: Array = []
	if _will.is_empty():
		wi = [0, -1, -1, 0.0, 0, -1]
	else:
		wi = [1, int(_will.player), int(_will.step),
			snappedf(maxf(float(_will.clock), 0.0), 0.05), int(_will.sel), int(_will.card)]
		for c in _will.cards:
			wc.append_array([maxi(CURSE_KINDS.find(str(c.kind)), 0),
				int((c.slot as Dictionary).id), str(c.replaces)])
	var frz := 0
	for pawn in pawns:
		if pawn.alive and pawn.world_frozen:
			frz = 1
			break
	return {
		"ph": phase,
		"ri": race_index,
		"rt": races_total,
		"re": snappedf(race_elapsed, 0.05),
		"rl": race_label.text,
		"frz": frz,
		"ban": [banner.text, _banner_col, banner.visible],
		"sub": [sub_banner.text, _sub_col, sub_banner.visible],
		"exc": [exec_label.text, exec_label.visible],
		"f": fs,
		"lv": lv, "bx": bx, "cp": cps, "fin": fin, "tot": tot, "dth": dts,
		"gh": gh,
		"gn": _net_gust_n.duplicate(),
		"gr": _net_gust_last.duplicate(),
		"hz": hz,
		"bo": bo,
		"cu": cu,
		"wi": wi,
		"wc": wc,
		"champ": _net_champ,
	}


## CLIENT. Latest-state-wins; all juice from deltas and cumulative rows — a
## dropped packet loses nothing but in-between frames.
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()   # FINAL STRETCH: light bed on first snapshot
	phase = (int(state.get("ph", phase))) as Phase   # render/probe fact only
	race_label.text = str(state.get("rl", ""))
	race_elapsed = float(state.get("re", race_elapsed))
	races_total = int(state.get("rt", races_total))
	# --- race rollover: THE FINAL RACE runs tense start to finish (kit fact)
	var ri := int(state.get("ri", 0))
	if ri != int(prev.get("ri", -1)):
		race_index = ri
		if _stretch != null:
			if ri >= races_total - 1 and races_total > 1:
				_stretch.escalate()
			else:
				_stretch.round_reset()
	# --- the world-freeze fact: statues on BOTH screens; the dead own the pause
	var frz := int(state.get("frz", 0)) == 1
	if frz != _mir_frozen:
		_mir_frozen = frz
		for pawn in pawns:
			pawn.world_frozen = frz     # rings/hitstop read it; body stays frozen
			if pawn.alive and pawn.anim:
				pawn.anim.speed_scale = 0.0 if frz else 1.0
	# --- HUD strings
	_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	_apply_mir_sub(state.get("sub", []))
	_apply_mir_exec(state.get("exc", []))
	# --- player facts: hearts, track, totals, checkpoints, finishes, deaths
	_mir_apply_players(state, prev)
	# --- pawn poses + one-shots
	_mir_apply_pawns(state.get("f", []), prev.get("f", []))
	# --- ghost pews + gust cooldowns
	_mir_apply_ghosts(state.get("gh", []))
	# --- gust volleys (counter + spawn row; flight is local + deterministic)
	_mir_apply_gusts(state, prev)
	# --- boulders (spawn facts; the roll is local + deterministic)
	_mir_sync_boulders(state.get("bo", []))
	# --- CURSES: the accreted road, plaques included (late joiners rebuild all)
	_mir_sync_curses(state.get("cu", []))
	# --- THE WILL: public theater, mirrored honestly
	_mir_apply_will(state, prev)
	# --- the champion (pre-announced one seq-beat before finished())
	if not _mir_done:
		var champ := int(state.get("champ", -1))
		if champ >= 0 and champ < players.size():
			_mir_done = true
			if _stretch != null:
				_stretch.match_ended()
			_flash_banner("%s WINS LAST WILL" % players[champ].name, players[champ].color, 6.0)
			Sfx.play("match_win")
			_spawn_confetti(pawns[champ].global_position + Vector3(0, 1.2, 0), players[champ].color)


func _mir_apply_players(state: Dictionary, prev: Dictionary) -> void:
	var lv: Array = state.get("lv", [])
	var bx: Array = state.get("bx", [])
	var cps: Array = state.get("cp", [])
	var pcp: Array = prev.get("cp", [])
	var fin: Array = state.get("fin", [])
	var tot: Array = state.get("tot", [])
	var dts: Array = state.get("dth", [])
	var pdt: Array = prev.get("dth", [])
	for i in mini(players.size(), lv.size()):
		players[i].lives = int(lv[i])
		if i < bx.size():
			players[i].best_x = float(bx[i])
		if i < tot.size():
			players[i].total = int(tot[i])
		if i < cps.size():
			var c := int(cps[i])
			if c > (int(pcp[i]) if i < pcp.size() else c):
				Sfx.play("confirm", -8.0)   # checkpoint claimed (sub rides wire)
			players[i].checkpoint = c
		if i < fin.size():
			var f2 := int(fin[i]) == 1
			if f2 and not bool(players[i].finished):
				# crypt finish: the doorstep tableau, exactly as the couch
				pawns[i].celebrate()
				Sfx.play("match_win", -4.0)
				_spawn_burst(pawns[i].global_position + Vector3(0, 1.2, 0), players[i].color, 30)
				_mir_snap_once("lw_mirror_finish")
			players[i].finished = f2
		if i < dts.size():
			var dd := int(dts[i])
			if dd > (int(pdt[i]) if i < pdt.size() else dd):
				# a death: burst + shake + the deciding-moment freeze (banner
				# text/color — shove, curse line, royalties — rides the wire)
				Sfx.play("splat")
				Sfx.play("death")
				_spawn_burst(pawns[i].global_position + Vector3(0, 0.4, 0), players[i].color, 30)
				_shake = maxf(_shake, 0.5)
				if _racers_with_lives() <= 1 and players.size() >= 2 and not _reduced_motion():
					_time_hit(0.25, 0.9)
				else:
					_time_hit(0.5, 0.2)
			players[i].deaths = dd


func _mir_apply_pawns(fs: Array, pfs: Array) -> void:
	for i in pawns.size():
		var b := i * 13
		if b + 12 >= fs.size():
			break
		var pawn: LWPawn = pawns[i]
		var alive := int(fs[b]) == 1
		if alive != pawn.alive:
			pawn.alive = alive
			players[i].alive = alive
			if alive:   # revived at a checkpoint: appear there, clean slate
				pawn.global_position = Vector3(float(fs[b + 2]), float(fs[b + 3]), float(fs[b + 4]))
				if pawn.model_pivot:
					pawn.model_pivot.scale = Vector3.ONE
				pawn._cur_anim = ""
		pawn.visible = int(fs[b + 1]) == 1
		pawn._set_anim(NET_ANIMS[clampi(int(fs[b + 6]), 0, NET_ANIMS.size() - 1)])
		var scd := float(fs[b + 7])
		if absf(pawn._shove_cd - scd) > 0.1:
			pawn._shove_cd = scd
		var hcd := float(fs[b + 8])
		if absf(pawn._hop_cd - hcd) > 0.1:
			pawn._hop_cd = hcd
		var hits := int(fs[b + 9])
		var phits := int(pfs[b + 9]) if b + 9 < pfs.size() else hits
		if hits > phits and alive:
			# a shove/blade/sweeper connected: victim pop + spark + layered thud
			var d := Vector3(float(fs[b + 10]), 0.0, float(fs[b + 11]))
			pawn.flash_pop()
			spark_at(pawn.global_position + Vector3(0, 0.9, 0) - d * 0.3, d, players[i].color, 1.0)
			Sfx.play("bumper", -3.0)
			_shake = maxf(_shake, 0.26)
			if not _reduced_motion() and game_time - _last_hitstop >= 0.14:
				_last_hitstop = game_time
				_time_hit(0.15, 0.045)
		var sh := int(fs[b + 12])
		var psh := int(pfs[b + 12]) if b + 12 < pfs.size() else sh
		if sh > psh and alive:
			# shove fired: whoosh + windup coil + readability arc along facing
			Sfx.play("bounce", -7.0)
			var yaw := float(fs[b + 5])
			on_shove_fired(pawn.global_position, Vector3(sin(yaw), 0.0, cos(yaw)), players[i].color)
			pawn.windup_coil(false)


func _mir_apply_ghosts(gh: Array) -> void:
	for i in players.size():
		var b := i * 5
		if b + 4 >= gh.size():
			break
		var on := int(gh[b]) == 1
		if on and not ghosts.has(i):
			_seat_ghost(i, int(gh[b + 1]))   # the HOST's pew, not death-order
			_mir_snap_once("lw_mirror_ghost")
		elif not on and ghosts.has(i):
			if is_instance_valid(ghosts[i]):
				ghosts[i].queue_free()
			ghosts.erase(i)
			_refresh_hint()
		if not ghosts.has(i):
			continue
		var g: LWGhostSeat = ghosts[i]
		g.set_aim(Vector2(float(gh[b + 2]), float(gh[b + 3])))
		var cd := float(gh[b + 4])
		if absf(g.gust_cd - cd) > 0.2:
			g.gust_cd = cd


func _mir_apply_gusts(state: Dictionary, prev: Dictionary) -> void:
	var gn: Array = state.get("gn", [])
	var pgn: Array = prev.get("gn", [])
	var gr: Array = state.get("gr", [])
	for i in mini(gn.size(), players.size()):
		if int(gn[i]) <= (int(pgn[i]) if i < pgn.size() else int(gn[i])):
			continue
		var b := i * 4
		if b + 3 >= gr.size():
			continue
		var start := Vector3(float(gr[b]), 0.7, float(gr[b + 1]))
		var dir3 := Vector3(float(gr[b + 2]), 0.0, float(gr[b + 3]))
		var node := _make_gust_node(players[i].color)
		spawn_root.add_child(node)
		node.global_position = start
		node.rotation.y = atan2(-dir3.x, -dir3.z)
		_gusts.append({"node": node, "pos": start, "dir": dir3, "traveled": 0.0,
			"hit": [], "from": i})
		Sfx.play("bounce", -7.0, 0.2)


## Boulder replicas: spawned from host facts, rolled locally (the roll is
## deterministic over static geometry), squish fenced (deaths are host facts).
func _mir_sync_boulders(bo: Array) -> void:
	var seen := {}
	var n := bo.size() / 11
	for r in n:
		var b := r * 11
		var id := int(bo[b])
		seen[id] = true
		var st := int(bo[b + 1])
		var trav := float(bo[b + 2])
		if not _mir_boulders.has(id):
			var node := LWBoulder.new()
			spawn_root.add_child(node)
			node.setup(Vector3(float(bo[b + 3]), 0.0, float(bo[b + 4])),
				Vector2(float(bo[b + 5]), float(bo[b + 6])), float(bo[b + 7]),
				Vector3(float(bo[b + 8]), 0.0, float(bo[b + 9])), float(bo[b + 10]), self)
			node.net_id = id
			_mir_boulders[id] = node
			if st != LWBoulder.BState.TELEGRAPH:
				node._t = LWBoulder.TELEGRAPH_T   # joined mid-roll: fast-forward
				node.tick(0.001)
		var rep: LWBoulder = _mir_boulders[id]
		if rep.state == LWBoulder.BState.ROLLING and absf(rep._traveled - trav) > 0.6:
			var d := trav - rep._traveled          # one-beat spawn lag correction
			rep._traveled = trav
			rep._rock.position += Vector3(rep.dir.x, 0.0, rep.dir.y) * d
	for id in _mir_boulders.keys().duplicate():
		if not seen.has(id):
			(_mir_boulders[id] as LWBoulder).queue_free()
			_mir_boulders.erase(id)


## The accreted road: install rows carry slot + kind + author + side seed, so
## the mirror rebuilds the IDENTICAL curse — author color, plaque, gap side.
func _mir_sync_curses(cu: Array) -> void:
	var n := cu.size() / 7
	var want := {}
	for r in n:
		want[int(cu[r * 7])] = true
	for k in range(curses.size() - 1, -1, -1):
		if not want.has(int(curses[k].install_order)):
			curses[k].queue_free()               # displaced by a newer will
			curses.remove_at(k)
	var have := {}
	for c in curses:
		have[int(c.install_order)] = true
	for r in n:
		var b := r * 7
		var order := int(cu[b])
		if not have.has(order):
			# a curse installs mid-race: same node, author color, NAME PLAQUE
			var slot: Dictionary = LWCourse.SLOTS[clampi(int(cu[b + 1]), 0, LWCourse.SLOTS.size() - 1)]
			var kind: String = CURSE_KINDS[clampi(int(cu[b + 2]), 0, CURSE_KINDS.size() - 1)]
			var author := clampi(int(cu[b + 3]), 0, players.size() - 1)
			var node := LWCurse.new()
			spawn_root.add_child(node)
			node.setup(slot, kind, author, players[author].name, players[author].color,
				int(cu[b + 4]), self)
			node.install_order = order
			curses.append(node)
			node.play_install()
			Sfx.play("grudge", -1.0)
			_mir_curse_snap()
		# gale bursts ride the mirrored phase; scythe poses apply in the tick
		for c in curses:
			if int(c.install_order) != order or c.kind != "gale":
				continue
			var active: bool = float(cu[b + 5]) < LWCurse.GALE_ACTIVE
			for p in c._gale_parts:
				(p as CPUParticles3D).emitting = active
			for m in c._gale_sheets:
				(m as StandardMaterial3D).albedo_color.a = 0.26 if active else 0.05
	curses.sort_custom(func(a, b2): return int(a.install_order) < int(b2.install_order))


## THE WILL, mirrored: the couch shows the draft publicly (one shared screen —
## cards, cursor, timer all in the open), so the mirror performs the same show.
func _mir_apply_will(state: Dictionary, prev: Dictionary) -> void:
	var wi: Array = state.get("wi", [])
	var pwi: Array = prev.get("wi", [])
	if wi.size() < 6:
		return
	var active := int(wi[0]) == 1
	if not active:
		if _mir_will_open:
			# a lost beat skipped CLOSING: fold everything the couch would have
			_mir_will_open = false
			_mir_cards_up = false
			_mir_will_res = false
			_ui.close()
			_hand.visible = false
			cam.fov = _cam_base_fov
		if not race_label.visible:
			_set_base_ui(true)
		return
	var p := int(wi[1])
	var step := int(wi[2])
	var pstep := int(pwi[2]) if pwi.size() >= 6 and int(pwi[0]) == 1 else -1
	if p < 0 or p >= players.size():
		return
	if int(pwi[1] if pwi.size() >= 6 else -1) != p:
		_mir_will_open = false   # queued wills: a new deceased takes the stage
		_mir_cards_up = false
		_mir_will_res = false
	# the memorial overlay opens at the REVEAL beat, as the couch does
	if step >= WStep.REVEAL and step < WStep.CLOSING and not _mir_will_open:
		_mir_will_open = true
		_ui.open(players[p].name, players[p].color, players[p].char_path)
		_set_base_ui(false)
		Sfx.play("grudge", 0.0, 0.03)
		var tw := create_tween()
		tw.tween_property(cam, "fov", _cam_base_fov - 6.0, 0.5).set_trans(Tween.TRANS_SINE)
	# three parchment curse cards (zones + displacement lines ride the wire)
	if step == WStep.CARDS and not _mir_cards_up:
		var wc: Array = state.get("wc", [])
		var cards: Array = []
		var nr := wc.size() / 3
		for r in nr:
			var b := r * 3
			var kind: String = CURSE_KINDS[clampi(int(wc[b]), 0, CURSE_KINDS.size() - 1)]
			var slot: Dictionary = LWCourse.SLOTS[clampi(int(wc[b + 1]), 0, LWCourse.SLOTS.size() - 1)]
			cards.append({
				"kind": kind,
				"title": CURSE_DEFS[kind].title,
				"desc": CURSE_DEFS[kind].desc,
				"zone": "UPON %s" % str(slot.name),
				"replaces": str(wc[b + 2]),
			})
		if not cards.is_empty():
			_mir_cards_up = true
			_ui.show_cards(cards)
			_ui.set_card_sel(int(wi[4]))
			_mir_clock = float(wi[3])
			_mir_snap_once("lw_mirror_draft")
	# the deceased strolls their options — THEIR choice, everyone's screen
	if _mir_cards_up and step == WStep.CARDS:
		_mir_clock = float(wi[3])
		if pwi.size() >= 6 and int(wi[4]) != int(pwi[4]):
			_ui.set_card_sel(int(wi[4]))
			Sfx.play("card", -4.0)
	# the choice lands: lock pop, resolution lines, the pan to the condemned
	# stretch, the skeletal hand — the curse row itself installs the malice
	if step == WStep.RESOLUTION and not _mir_will_res and _mir_will_open:
		_mir_will_res = true
		var card := clampi(int(wi[5]), 0, 2)
		var wc2: Array = state.get("wc", [])
		if wc2.size() >= (card + 1) * 3:
			var kind2: String = CURSE_KINDS[clampi(int(wc2[card * 3]), 0, CURSE_KINDS.size() - 1)]
			var slot2: Dictionary = LWCourse.SLOTS[clampi(int(wc2[card * 3 + 1]), 0, LWCourse.SLOTS.size() - 1)]
			_ui.lock_card(card)
			Sfx.play("confirm", -2.0)
			_ui.show_resolution([
				{"text": "%s CONDEMNS" % players[p].name, "color": players[p].color, "delay": 0.0},
				{"text": str(slot2.name), "color": LWWillUI.GOLD, "delay": 0.55},
				{"text": "— %s —" % str(CURSE_DEFS[kind2].title), "color": LWWillUI.GREEN, "delay": 1.1},
			])
			Sfx.play("grudge", -1.0)
			_rig_home = cam_rig.position
			var sc := LWCourse.slot_center(slot2)
			var tw2 := create_tween()
			tw2.tween_property(cam_rig, "position", Vector3(sc.x + 1.0, 0.0, sc.z * 0.6), 0.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_hand.visible = true
			_hand.scale = Vector3(2.6, 2.6, 2.6)
			_hand.global_position = sc + Vector3(0, 3.1, 1.2)
	# the overlay folds; the camera comes home to the procession
	if step == WStep.CLOSING and pstep != WStep.CLOSING and _mir_will_open:
		_mir_will_open = false
		_mir_cards_up = false
		_mir_will_res = false
		_ui.close()
		_hand.visible = false
		var tw3 := create_tween()
		tw3.tween_property(cam, "fov", _cam_base_fov, 0.4).set_trans(Tween.TRANS_SINE)
		var tw4 := create_tween()
		tw4.tween_property(cam_rig, "position", _rig_home, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## CLIENT, per physics tick: pawn/hazard glide, local boulder+gust flight,
## draft-clock drain, race camera — everything smoother than 20 Hz.
func _mirror_tick(delta: float) -> void:
	if _mir.is_empty():
		return
	game_time += delta
	if _shake > 0.001:
		cam.h_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.3
		cam.v_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.3
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	var racing := phase == Phase.RACE
	if racing:
		race_elapsed += delta       # resynced every apply; drives the hard-cap
		_update_timer_label()       # ladder + timer pulse (FINAL STRETCH kit)
		for rep in _mir_boulders.values():
			(rep as LWBoulder).tick(delta)
		_tick_gusts(delta)          # pushes are inert on frozen puppets
		for i in ghosts:
			(ghosts[i] as LWGhostSeat).tick_cooldown(delta)
	if racing or phase == Phase.INTRO:
		_update_camera(delta)
		_update_ghost_rail()
	var w := 1.0 - exp(-14.0 * delta)
	var fs: Array = _mir.get("f", [])
	for i in pawns.size():
		var b := i * 13
		if b + 12 >= fs.size():
			break
		var pawn: LWPawn = pawns[i]
		if pawn.visible:
			pawn.global_position = pawn.global_position.lerp(
				Vector3(float(fs[b + 2]), float(fs[b + 3]), float(fs[b + 4])), w)
			if pawn.model_pivot:
				pawn.model_pivot.rotation.y = lerp_angle(
					pawn.model_pivot.rotation.y, float(fs[b + 5]), w)
		if racing and not _mir_frozen:
			pawn._shove_cd = maxf(0.0, pawn._shove_cd - delta)
			pawn._hop_cd = maxf(0.0, pawn._hop_cd - delta)
		pawn._drive_rings(delta)
	# hazard poses: exact phases ride the wire; glide between beats
	var hz: Array = _mir.get("hz", [])
	var hi := 0
	for pen in pendulums:
		if hi + 1 < hz.size():
			_mir_drive_pendulum(pen, float(hz[hi]), float(hz[hi + 1]), w)
		hi += 2
	if hi < hz.size():
		spinner._angle = lerp_angle(spinner._angle, float(hz[hi]), w)
		spinner._arms.rotation.y = spinner._angle
	hi += 1
	for wall in walls:
		if hi < hz.size():
			wall._phase = lerpf(wall._phase, float(hz[hi]), w)
			wall._apply_phase()
		hi += 1
	var cu: Array = _mir.get("cu", [])
	for k in curses.size():
		var c := k * 7
		if c + 6 >= cu.size():
			break
		var cur: LWCurse = curses[k]
		if cur.kind == "scythe" and cur._pendulum != null:
			_mir_drive_pendulum(cur._pendulum, float(cu[c + 5]), float(cu[c + 6]), w)
	# the six-second clock drains smoothly between snapshots
	if _mir_cards_up:
		_mir_clock = maxf(_mir_clock - delta, 0.0)
		_ui.set_timer(_mir_clock / DRAFT_BUDGET, _mir_clock)


func _mir_drive_pendulum(pen: LWPendulum, rot: float, py: float, w: float) -> void:
	var prev := pen._blade.rotation.z
	pen._blade.rotation.z = lerp_angle(prev, rot, w)
	pen._pivot.position.y = lerpf(pen._pivot.position.y, py, w)
	# the nadir whoosh, detected locally on the mirrored swing
	if signf(prev) != signf(pen._blade.rotation.z) and absf(pen._blade.rotation.z) < 0.3:
		Sfx.play("bounce", -10.0, 0.15)


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


func _apply_mir_sub(arr: Array) -> void:
	if arr.size() < 3:
		return
	sub_banner.text = str(arr[0])
	sub_banner.add_theme_color_override("font_color", Color(str(arr[1])))
	sub_banner.visible = bool(arr[2])


func _apply_mir_exec(arr: Array) -> void:
	if arr.size() < 2:
		return
	exec_label.text = str(arr[0])
	exec_label.visible = bool(arr[1])


## CLIENT: my aim against my own mirrored render (doc 10 §1.3) — a dead
## player's gust cursor anchors on their ghost pew, exactly as the couch aims.
func _net_aim() -> Dictionary:
	var my := NetSession.my_seat()
	var aim := Vector3.ZERO
	if my >= 0 and my < players.size():
		var anchor: Vector3 = pawns[my].global_position
		if ghosts.has(my) and is_instance_valid(ghosts[my]):
			anchor = (ghosts[my] as LWGhostSeat).global_position
		aim = PlayerInput.get_aim_dir(my, anchor, cam)
	return {"aim": aim, "aim_screen": Vector2.ZERO}


func _mir_snap_once(tag: String) -> void:
	if _mir_snaps.has(tag):
		return
	_mir_snaps[tag] = true
	VerifyCapture.snap(tag)


## The curse-install receipt waits for the resolution pan to land (0.9 s, the
## host's _snap_after_pan cadence) so the plaque is in frame on both screens.
func _mir_curse_snap() -> void:
	if _mir_snaps.has("lw_mirror_curse"):
		return
	_mir_snaps["lw_mirror_curse"] = true
	await get_tree().create_timer(0.9, true, false, true).timeout
	VerifyCapture.snap("lw_mirror_curse")


# ================================================================ verify hooks
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.RACE

func debug_force_kill(p: int) -> void:
	if p >= 0 and p < pawns.size() and pawns[p].alive and phase == Phase.RACE:
		pawns[p]._die("void")
