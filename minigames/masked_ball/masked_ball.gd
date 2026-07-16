extends Minigame
## MASKED BALL — the Theater's third social-deduction act. The stage floods
## with a crowd of IDENTICAL masked dancers; four of them are the players,
## and nobody is told which. You discover yourself by moving (your dancer
## answers your stick; feather it and your mask glints privately), blend by
## dancing like the crowd, curtsy to the throne for points, and spend your
## ONE mark to tear the mask off a body you believe is human. Hidden in
## Plain Sight, staged — docs/design/06-social-deduction-research.md pitch
## #3, the cheapest secret model of all: ZERO on-screen secret delivery.
## Your identity IS your controlled body; nothing hidden ever touches the
## shared screen.
##
## ROUND FLOW (per the doc: one waltz, ~3:00 total):
##   INTRO (~3s)    the ball is already underway; every body — including
##                  the four player bodies — dances on the crowd's brain,
##                  so nobody can pre-track a spawn.
##   WALTZ (150s)   everything at once, fully simultaneous (doc: "a single
##                  2:30 waltz", no turn windows):
##                    stick   = drift at CROWD SPEED (never faster — pace
##                              can't be the tell; intention is)
##                    feather = below the move threshold, your mask glints;
##                              NPC masks glint on their own, so only YOU
##                              can read the correlation (the private pulse)
##                    A       = CURTSY. In the throne circle it scores a pip
##                              (3 max, +2 each, 6s apart); anywhere else it
##                              is a free bluff. NPCs curtsy too. Scored
##                              curtsies are announced UNNAMED — the room
##                              only learns "somebody bowed for money".
##                    B       = UNMASK the nearest dancer in reach — one
##                              mark, all waltz (HiPS's single bullet).
##                              Human: +6, they die to spectator-ghost, the
##                              accuser collects royalty. Furniture: −3,
##                              grudge, and YOUR body flashes — the position
##                              leak (a self-inflicted reveal moment).
##   REVEAL (~15s)  the orchestra stops, the hired bodies dim, survivors
##                  are unmasked one by one, the ledger settles.
##
## ECONOMY (doc: "marking a human correctly = royalty; being marked =
## grudge; completing your secret objective = points"): royalty 2 to a
## correct accuser; grudge 1 to the victim; grudge 1 for a wasted mark;
## pips and survival are points only. kill_events: killer = accuser,
## cause "unmasked", exactly one per elimination.
##
## PLAYERBADGE EXCEPTION (deliberate, documented in
## docs/verify/maskedball-VERIFY.md): identity hiding IS the game, so NO
## badge/color/tag rides a dancer mid-round — the anthology's one exception
## to always-on identity. Badges and seat-pitch audio (RED .90 / BLUE 1.00 /
## GOLD 1.12 / MINT 1.26) appear exactly at REVEAL moments: an unmasking, a
## waste-flash (self-reveal), the ghost, the last dance, the ledger. The
## mitigation for self-identification is the feather-glint private pulse.
##
## Anthology module: id "maskedball", scene minigames/masked_ball/
## masked_ball.tscn, root extends Minigame. Self-starts standalone 0.5s
## after _ready if begin() was not called. Per-seat bots (roster[i].bot,
## else PlayerInput.standalone_bot_default). Deterministic per rng_seed:
## kinematic crowd (no physics bodies), logic rolls from seeded streams in
## fixed tick order, visual-only randomness on a separate rng.
##
## CLI user args (after `--`):
##   --mbbots         all seats are seeded self-play bots
##   --seed=N         rng seed for standalone start (default 1)
##   --players=N      standalone roster size 2..4
##   --mbtally        headless evidence mode: full bot match fast-forwarded
##                    (dt pinned 1/60), prints MB_TALLY + results JSON, quits
##   --mbsnaps        windowed bot match, waltz shortened to 90s, with two
##                    SCRIPTED beats (a forced waste at ~26s, a forced human
##                    unmask at ~48s) so every reveal state is photographed;
##                    saves docs/verify/shots/maskedball_*.png and quits
##   --mbnetdemo      two-instance NETPROBE rig (docs/verify/
##                    online-maskedball-VERIFY.md): host side shortens the
##                    waltz to 90s, calms the bots (photo_mode) and scripts
##                    ONE reveal beat at ~40s; client side drives its remote
##                    seat through the REAL input pipe (stroll, feather-glint,
##                    the one mark, a bluff curtsy) via the _dbg_aim-style
##                    injection seam, and photographs the reveal moments
##   --shots=N,... / --quitafter=N   global VerifyCapture harness
##
## ONLINE (phase 2, docs/design/10-online-first-architecture.md §4.3): the
## host runs this ENTIRE sim exactly as couch; the estate pumps _net_state()
## to guests at 20 Hz and clients boot this same scene with
## config.net_mirror = true, where _net_apply()/_mirror_tick() puppet the
## twenty dancers from public facts. THE PRIVACY CORE SURVIVES THE WIRE FOR
## FREE: the snapshot is BODY-indexed and carries no seat->dancer mapping —
## every glint (decoy or feather) rides one untagged per-body counter, and
## seat<->body pairs enter the dict only inside reveal rows minted at the
## exact frame the couch prints the same badge on screen. The client is
## booted with rng_seed=0 (the estate's mirror contract), so the seeded deal
## can never be recomputed remotely. Masked ball has ZERO private sends:
## the couch's only "secret" is the correlation between your hidden stick
## and your own mask's glints, which no packet can name.

enum Phase { WAITING, INTRO, WALTZ, REVEAL, DONE }

const DANCER_CHAR := "res://assets/models/kaykit/Rogue.glb"

const CROWD_TOTAL := 20            # dancers on the floor, players included
const DANCE_SPEED := 1.35          # EVERYBODY moves at crowd pace
const MOVE_TH := 0.5               # stick past this = glide
const FEATHER_LO := 0.15           # feather band lower edge (private pulse)
const GLINT_CD := 1.4
const WALTZ_TIME := 150.0
const SNAP_WALTZ_TIME := 90.0
const INTRO_TIME := 3.2
const CURTSY_TIME := 1.15
const CURTSY_GAP := 6.0            # seconds between SCORED curtsies
const PIP_MAX := 3
const PIP_PTS := 2
const UNMASK_PTS := 6
const WASTE_PTS := -3
const SURVIVE_PTS := 4
const MARK_REACH := 1.7
const FLASH_TIME := 1.8
const ROYALTY_UNMASK := 2
const GRUDGE_MARKED := 1
const GRUDGE_WASTE := 1
const SEP_R := 0.55
const AX := 7.6                    # ballroom ellipse half extents
const AZ := 5.0
const ZONE_C := Vector3(0, 0, -3.55)
const ZONE_R := 2.1
const GHOST_SPEED := 1.9
const GUST_CD := 3.5
const GUST_R := 2.2

# the house seat-pitch language (RED .90 / BLUE 1.00 / GOLD 1.12 / MINT 1.26)
const SEAT_TAP_PITCH := [0.9, 1.0, 1.12, 1.26]
const REVEAL_TICK_DB := -6.0
# waltz metronome (presentation only): oom-pah-pah at 0.62s a beat
const WALTZ_BEAT := 0.62

var phase: int = Phase.WAITING
var game_time := 0.0
var rng := RandomNumberGenerator.new()        # match setup draws
var crowd_rng := RandomNumberGenerator.new()  # NPC brains, fixed tick order
var _fx_rng := RandomNumberGenerator.new()    # visual/flavor only, never logic
var bots: MBBots

var roster: Array = []
var players: Array = []     # {index,name,color,device,is_bot,points,pips,
                            #  mark_left,eliminated,last_pip,ghost_pos,gust_cd,
                            #  glint_cd,ghost_node}
var dancers: Array = []     # body id -> MBDancer
var body_to_seat: Array = []
var _waltz_e := 0.0
var _waltz_len := WALTZ_TIME
var _intro_t := 0.0
var _corpse_fade: Dictionary = {}   # body -> waltz time to fade

# meta / results
var _currency: Array = []
var _kill_events: Array = []
var _highlights: Array = []
var _unmask_count := 0
var _waste_count := 0
var _first_kill_txt := ""
var _practice := false
var _reported := false

# sequencer (REVEAL theatrics)
var _seq: Array = []
var _seq_t := 0.0

# modes
var _started := false
var _all_bots := false
var _tally := false
var _snaps := false
var _cli_players := 4
var _cli_seed := 1
var _snapped: Dictionary = {}
var _pending_snaps: Array = []      # {tag, at} in game_time
var _forced_waste_done := false
var _forced_kill_done := false

# ---- ONLINE PHASE 2 (mirror) ----
var _mirror := false                # this instance is a client render mirror
var _netdemo := false               # --mbnetdemo probe rig (host beats / client script)
var _mir: Dictionary = {}           # client: latest applied snapshot
var _mir_rev_n := 0                 # client: processed reveal rows
var _mir_wst_n := 0                 # client: processed waste rows
var _mir_led_n := 0                 # client: processed ledger rows
var _mir_champ := -1                # client: confetti latch
var _mir_snaps: Dictionary = {}     # client: VerifyCapture latches
# host-side public event ledgers (cumulative — latest-wins snapshots may drop;
# counters and append-only rows lose nothing but intermediate frames)
var _net_crt := 0                   # scored curtsies, UNNAMED count only
var _net_rev: Array = []            # [kind(0 unmask/1 survivor), seat, body, killer]
var _net_wst: Array = []            # [accuser_seat, accuser_body]
var _net_led: Array = []            # [text, color_html] as rows are read out
var _net_gust: Array = [0, 0, 0, 0] # per-seat ghost-gust counters (dead = revealed)
var _net_champ: Array = [-1, -1]    # [seat, body] once the ball is taken
var _ban_col := "ffffff"            # last banner/sub colors (ride the wire)
var _sub_col := "ffffff"
# --mbnetdemo host beat + client injector state
var _nd_done := false
var _demo_feather := false
var _demo_glint_seen := false
var _inj_seq := 0
var _inj_pa := 0
var _inj_pb := 0
var _inj_a_prev := false
var _inj_b_prev := false

# fx
var _shake := 0.0
var _time_token := 0
var _banner_token := 0
var _sub_token := 0
var _music_t := 0.0
var _music_beat := 0
var _pitched_players: Array = []
var _pitched_next := 0
var _pitched_streams: Dictionary = {}
var _reveal_spot: SpotLight3D
var _zone_ring_mat: StandardMaterial3D

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var banner: Label = $UI/Banner
@onready var sub_banner: Label = $UI/SubBanner
@onready var phase_label: Label = $UI/PhaseLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var executor_label: Label = $UI/ExecutorLabel
@onready var ledger_box: VBoxContainer = $UI/Ledger
@onready var spawn_root: Node3D = $SpawnRoot

func _ready() -> void:
	_parse_args()
	_fx_rng.seed = 0xBA11 + _cli_seed
	_build_world()
	banner.visible = false
	sub_banner.visible = false
	executor_label.text = ""
	info_label.text = ""
	hint_label.text = ""
	if not _tally:
		_build_pitched_pool()
	await get_tree().create_timer(0.5).timeout
	if not _started:
		begin(_default_config())

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--mbbots":
			_all_bots = true
		elif arg == "--mbtally":
			_tally = true
			_all_bots = true
		elif arg == "--mbsnaps":
			_snaps = true
			_all_bots = true
		elif arg == "--mbnetdemo":
			_netdemo = true
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
	if _tally:
		# faster-than-realtime with dt pinned to exactly 1/60 (house trick)
		var fast := 8.0
		Engine.time_scale = fast
		Engine.physics_ticks_per_second = int(60.0 * fast)
		Engine.max_physics_steps_per_frame = maxi(8, int(60.0 * fast))
		AudioServer.set_bus_mute(0, true)

func _default_config() -> Dictionary:
	PlayerInput.auto_assign(_cli_players)
	var r: Array = []
	for i in _cli_players:
		var dev := PlayerInput.device_of(i)
		r.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": DANCER_CHAR,
			"device": dev,
			"bot": _all_bots or PlayerInput.standalone_bot_default(i) or dev == -3 or dev == -99,
		})
	return {"roster": r, "rounds": 1, "rng_seed": _cli_seed, "practice": false}

func begin(config: Dictionary) -> void:
	if _started:
		return
	_started = true
	_mirror = bool(config.get("net_mirror", false))
	rng.seed = int(config.get("rng_seed", 1))
	crowd_rng.seed = int(config.get("rng_seed", 1)) ^ 0xC0DA
	_practice = bool(config.get("practice", false))
	_waltz_len = SNAP_WALTZ_TIME if (_snaps or _netdemo) else WALTZ_TIME
	roster = config.get("roster", [])
	players.clear()
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var idx := int(pl.get("index", i))
		var is_bot: bool = _all_bots or bool(pl.get("bot", PlayerInput.is_bot(idx)))
		players.append({
			"index": idx,
			"name": str(pl.get("name", "P%d" % i)),
			"color": pl.get("color", Color.WHITE),
			"device": int(pl.get("device", -99)),
			"is_bot": is_bot,
			"points": 0,
			"pips": 0,
			"mark_left": true,
			"eliminated": false,
			"last_pip": -999.0,
			"ghost_pos": Vector3.ZERO,
			"gust_cd": 0.0,
			"glint_cd": 0.0,
			"ghost_node": null,
		})
	if _mirror:
		# RENDER MIRROR (spec §4.3): no deal, no bots, no sim. The client's
		# rng_seed is 0 by the estate's mirror contract, and we never touch it:
		# _body_of stays EMPTY on this machine — the mirror cannot know (or
		# leak, or even guess at) which dancer answers which seat until a
		# reveal row says so. Twenty pawns spawn on a plain ring and the first
		# snapshot teleports them onto the host's truth.
		_spawn_crowd_mirror()
		phase = Phase.INTRO
		phase_label.text = "MASKED BALL"
		info_label.text = ""
		print("MB_MIRROR boot players=%d my_seat=%d" % [players.size(), NetSession.my_seat()])
		return
	_spawn_crowd()
	bots = MBBots.new()
	bots.setup(int(config.get("rng_seed", 1)) ^ 0x3A5CED, players.size(),
		CROWD_TOTAL, _waltz_len)
	bots.photo_mode = _snaps or _netdemo
	print("MB_BEGIN players=%d seed=%d practice=%s bots=%s waltz=%.0f" % [
		players.size(), rng.seed, str(_practice),
		str(players.map(func(p): return p.is_bot)), _waltz_len])
	for i in players.size():
		print("MB_SELF seat=%d %s body=%d" % [i, players[i].name, _body_of[i]])
	phase = Phase.INTRO
	_intro_t = 0.0
	phase_label.text = "MASKED BALL"
	info_label.text = _info_line()
	_flash_banner("MASKED BALL", Color(0.92, 0.82, 1.0), 2.6)
	_flash_sub("the Theater presents", Color(0.72, 0.62, 0.8), 2.6)
	_say("The orchestra plays. Somebody here is breathing too deliberately.")

var _body_of: Array = []    # seat -> body id

func _spawn_crowd() -> void:
	var char_scene: PackedScene = load(DANCER_CHAR)
	body_to_seat.clear()
	dancers.clear()
	_body_of.clear()
	for b in CROWD_TOTAL:
		body_to_seat.append(-1)
	# seeded shuffle picks the player bodies — the only "deal", and it never
	# touches the screen
	var ids: Array = range(CROWD_TOTAL)
	for k in range(CROWD_TOTAL - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = ids[k]
		ids[k] = ids[j]
		ids[j] = tmp
	for i in players.size():
		_body_of.append(int(ids[i]))
		body_to_seat[int(ids[i])] = i
	for b in CROWD_TOTAL:
		var d := MBDancer.new()
		d.name = "Dancer%d" % b
		spawn_root.add_child(d)
		d.setup(b, char_scene, not _tally)
		var a := rng.randf_range(0.0, TAU)
		var k2 := sqrt(rng.randf()) * 0.85
		d.position = Vector3(cos(a) * AX * k2, 0, sin(a) * AZ * k2)
		d.facing = rng.randf_range(0.0, TAU)
		d.rotation.y = d.facing
		d.npc_t = rng.randf_range(0.2, 1.6)
		d.glint_next = rng.randf_range(1.0, 5.0)
		dancers.append(d)

## ONLINE mirror crowd: the same twenty pawns with NO deal and NO rng — a
## plain ring the first snapshot immediately overwrites. body_to_seat stays
## all -1 until reveal rows arrive (the client holds no seat->dancer map).
func _spawn_crowd_mirror() -> void:
	var char_scene: PackedScene = load(DANCER_CHAR)
	body_to_seat.clear()
	dancers.clear()
	_body_of.clear()
	for b in CROWD_TOTAL:
		body_to_seat.append(-1)
	for b in CROWD_TOTAL:
		var d := MBDancer.new()
		d.name = "Dancer%d" % b
		spawn_root.add_child(d)
		d.setup(b, char_scene, true)
		var a := TAU * float(b) / float(CROWD_TOTAL)
		d.position = Vector3(cos(a) * AX * 0.6, 0, sin(a) * AZ * 0.6)
		d.facing = a
		d.rotation.y = a
		dancers.append(d)

# ================================================================ world
func _build_world() -> void:
	# THE HOUSE LOOK -- STAGELIT ballroom (core/env_kit.gd). The game IS finding a
	# body in a crowd, so ALL 20 dancers must read: we keep the bespoke warm rig
	# (the BallSpot candle pool, the MoonFill, the chandeliers, the reveal spot)
	# and use EnvKit to own the ENVIRONMENT with the house AGX tonemap + an ADDITIVE
	# high-threshold glow (the mask glints bloom), RAISE ambient so edge dancers
	# outside the centre pool still read, and add a cool STAGELIT rim that peels the
	# brown-hooded crowd off the checkered floor. EnvKit's key/fill are zeroed --
	# the bespoke BallSpot stays the key. Replaces the old flat FILMIC env.
	EnvKit.apply(self, EnvKit.STAGELIT, {
		"key_energy": 0.0, "key_shadow": false,          # keep the bespoke BallSpot candle pool
		"fill_energy": 0.0,                              # keep the bespoke MoonFill
		"rim_energy": 0.85,                              # cool rim -- separate the 20 dancers
		"rim_color": Color(0.55, 0.62, 0.98),
		"bg_color": Color(0.014, 0.009, 0.02),
		"ambient_color": Color(0.52, 0.42, 0.40),        # warm-neutral crowd fill
		"ambient_energy": 0.60,                          # UP from 0.5 so all 20 dancers read
		"fog": true, "fog_color": Color(0.1, 0.07, 0.12), "fog_density": 0.01,
		"glow_intensity": 0.75, "glow_bloom": 0.1, "glow_threshold": 0.95,
		"glow_blend": Environment.GLOW_BLEND_MODE_ADDITIVE,
	})

	cam.global_position = Vector3(0, 11.6, 12.2)
	cam.look_at(Vector3(0, 0.3, -1.5), Vector3.UP)
	cam.fov = 45.0

	# candle pool over the floor
	var spot := SpotLight3D.new()
	spot.name = "BallSpot"
	spot.light_color = Color(1.0, 0.82, 0.58)
	spot.light_energy = 1.15
	spot.spot_range = 16.0
	spot.spot_angle = 52.0
	spot.position = Vector3(0, 10.0, 0.5)
	spot.rotation_degrees = Vector3(-88, 0, 0)
	spot.shadow_enabled = true
	add_child(spot)
	var moon := DirectionalLight3D.new()
	moon.name = "MoonFill"
	moon.rotation_degrees = Vector3(-44, -152, 0)
	moon.light_energy = 0.14
	moon.light_color = Color(0.45, 0.5, 0.85)
	add_child(moon)
	_reveal_spot = SpotLight3D.new()
	_reveal_spot.light_color = Color(1.0, 0.95, 0.85)
	_reveal_spot.light_energy = 0.0
	_reveal_spot.spot_range = 18.0
	_reveal_spot.spot_angle = 14.0
	_reveal_spot.position = Vector3(0, 9.5, 5.0)
	add_child(_reveal_spot)

	_build_ballroom()
	_build_throne()
	_build_chandeliers()

func _build_ballroom() -> void:
	var floor_m := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(21, 0.3, 15)
	floor_m.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.24, 0.16, 0.11)
	fmat.roughness = 0.62
	floor_m.material_override = fmat
	floor_m.position.y = -0.15
	$Arena.add_child(floor_m)
	# parquet diamonds: alternating darker tiles
	var tile_mat := StandardMaterial3D.new()
	tile_mat.albedo_color = Color(0.185, 0.12, 0.085)
	tile_mat.roughness = 0.68
	for ix in 10:
		for iz in 7:
			if (ix + iz) % 2 == 0:
				continue
			var tile := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(2.0, 0.012, 2.0)
			tile.mesh = tm
			tile.material_override = tile_mat
			tile.position = Vector3(-9.0 + ix * 2.0, 0.007, -6.0 + iz * 2.0)
			$Arena.add_child(tile)
	# red velvet curtain folds, back wall + angled sides
	var curt_mat := StandardMaterial3D.new()
	curt_mat.albedo_color = Color(0.3, 0.07, 0.1)
	curt_mat.roughness = 1.0
	for i in 16:
		var fold := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.62
		cm.height = 8.5
		fold.mesh = cm
		fold.material_override = curt_mat
		fold.position = Vector3(-9.0 + i * 1.2, 4.25, -8.2 + 0.18 * (i % 2))
		$Arena.add_child(fold)
	for side in [-1.0, 1.0]:
		for i in 5:
			var fold2 := MeshInstance3D.new()
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.5
			cm2.bottom_radius = 0.58
			cm2.height = 8.5
			fold2.mesh = cm2
			fold2.material_override = curt_mat
			fold2.position = Vector3(side * (8.9 + i * 0.3), 4.25, -6.4 + i * 1.5)
			$Arena.add_child(fold2)
	# gilt proscenium lip
	var lip := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(21, 0.5, 0.5)
	lip.mesh = lm
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.65, 0.5, 0.22)
	gold_mat.metallic = 0.7
	gold_mat.roughness = 0.4
	lip.material_override = gold_mat
	lip.position = Vector3(0, 8.4, -7.9)
	$Arena.add_child(lip)

func _build_throne() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.68, 0.52, 0.22)
	gold.metallic = 0.72
	gold.roughness = 0.35
	var velvet := StandardMaterial3D.new()
	velvet.albedo_color = Color(0.38, 0.08, 0.12)
	velvet.roughness = 0.9
	# dais steps
	for s in 2:
		var step := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(5.6 - s * 1.4, 0.26, 2.6 - s * 0.7)
		step.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.3, 0.2, 0.13)
		smat.roughness = 0.6
		step.material_override = smat
		step.position = Vector3(0, 0.13 + s * 0.26, -6.1)
		$Arena.add_child(step)
	# the throne
	var seat := MeshInstance3D.new()
	var seat_m := BoxMesh.new()
	seat_m.size = Vector3(1.1, 0.5, 0.9)
	seat.mesh = seat_m
	seat.material_override = velvet
	seat.position = Vector3(0, 0.9, -6.35)
	$Arena.add_child(seat)
	var back := MeshInstance3D.new()
	var back_m := BoxMesh.new()
	back_m.size = Vector3(1.2, 2.0, 0.18)
	back.mesh = back_m
	back.material_override = velvet
	back.position = Vector3(0, 1.9, -6.75)
	$Arena.add_child(back)
	for px in [-0.62, 0.62]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.07
		pm.bottom_radius = 0.09
		pm.height = 2.6
		post.mesh = pm
		post.material_override = gold
		post.position = Vector3(px, 1.7, -6.72)
		$Arena.add_child(post)
		var orb := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.13
		om.height = 0.26
		orb.mesh = om
		orb.material_override = gold
		orb.position = Vector3(px, 3.05, -6.72)
		$Arena.add_child(orb)
	# red carpet down the floor
	var carpet := MeshInstance3D.new()
	var car_m := BoxMesh.new()
	car_m.size = Vector3(2.3, 0.015, 10.6)
	carpet.mesh = car_m
	carpet.material_override = velvet
	carpet.position = Vector3(0, 0.009, -0.4)
	$Arena.add_child(carpet)
	# the respects circle — the throne-zone marker (the objective is public;
	# WHO is working it is the secret)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.965
	rm.outer_radius = 1.0
	ring.mesh = rm
	ring.scale = Vector3(ZONE_R, 1.0, ZONE_R)
	_zone_ring_mat = StandardMaterial3D.new()
	_zone_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_zone_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_zone_ring_mat.albedo_color = Color(0.85, 0.7, 0.32, 0.5)
	_zone_ring_mat.emission_enabled = true
	_zone_ring_mat.emission = Color(0.85, 0.68, 0.3)
	_zone_ring_mat.emission_energy_multiplier = 0.5
	ring.material_override = _zone_ring_mat
	ring.position = ZONE_C + Vector3(0, 0.02, 0)
	$Arena.add_child(ring)

func _build_chandeliers() -> void:
	for cx in [-4.2, 4.2]:
		var ch := Node3D.new()
		ch.position = Vector3(cx, 6.2, -1.0)
		$Arena.add_child(ch)
		var hoop := MeshInstance3D.new()
		var hm := TorusMesh.new()
		hm.inner_radius = 0.78
		hm.outer_radius = 0.9
		hoop.mesh = hm
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.6, 0.47, 0.2)
		gold.metallic = 0.75
		gold.roughness = 0.4
		hoop.material_override = gold
		ch.add_child(hoop)
		for k in 6:
			var a := TAU * k / 6.0
			var flame := MeshInstance3D.new()
			var flm := SphereMesh.new()
			flm.radius = 0.05
			flm.height = 0.14
			flame.mesh = flm
			var fmat := StandardMaterial3D.new()
			fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fmat.albedo_color = Color(1.0, 0.8, 0.42)
			fmat.emission_enabled = true
			fmat.emission = Color(1.0, 0.66, 0.28)
			fmat.emission_energy_multiplier = 1.6
			flame.material_override = fmat
			flame.position = Vector3(cos(a) * 0.84, 0.14, sin(a) * 0.84)
			ch.add_child(flame)
		var lit := OmniLight3D.new()
		lit.light_color = Color(1.0, 0.74, 0.4)
		lit.light_energy = 1.1
		lit.omni_range = 9.0
		ch.add_child(lit)

# ================================================================ tick
func _physics_process(delta: float) -> void:
	if _mirror:
		_mirror_tick(delta)
		return
	game_time += delta
	_tick_shake(delta)
	match phase:
		Phase.INTRO:
			_intro_t += delta
			_tick_crowd(delta, true)
			_post_move(delta)
			_tick_music(delta)
			if _intro_t >= INTRO_TIME:
				_begin_waltz()
		Phase.WALTZ:
			_tick_waltz(delta)
			_tick_music(delta)
		Phase.REVEAL:
			_seq_run(delta)
			_run_pending_snaps()
		_:
			pass

## Camera shake decay — shared verbatim by the couch tick and the mirror tick
## (pure visual; _fx_rng never feeds logic).
func _tick_shake(delta: float) -> void:
	if _shake > 0.001:
		cam.h_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.25
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func _begin_waltz() -> void:
	phase = Phase.WALTZ
	_waltz_e = 0.0
	phase_label.text = "MASKED BALL — THE WALTZ"
	hint_label.text = _controls_bar()
	_flash_banner("THE WALTZ BEGINS", Color(1.0, 0.85, 0.4), 2.0)
	_say("Dance. Preferably like nobody in particular.")
	# player bodies leave the crowd's brain; any half-finished bow is abandoned
	for i in players.size():
		var d: MBDancer = dancers[_body_of[i]]
		d.end_act()
		d.act_t = 0.0
	# NOTE: no game_time here — the standalone-start timer adds wall-clock
	# wobble before begin(); every deterministic print keys off _waltz_e
	print("MB_WALTZ_START bodies=%s" % str(_body_of))

## ---- live-binding hint bar (real keys, not "A"/"B"; docs/verify/realkeys-VERIFY.md) ----
## Self-contained per the template; presentation only. Bindings are fixed per
## match, so the bar is built once when the waltz begins.

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). The
## bar personalizes only these.
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
## (all pads -> "(A) = CURTSY"), else the per-seat "LABEL: KEY/NAME · KEY/NAME" form.
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

## The main waltz bar, always real keys via describe_binding (matches the card).
func _controls_bar() -> String:
	return "STICK = DRIFT · FEATHER IT = your mask glints · %s · %s" % [
		_btn_hint("a", "CURTSY"), _btn_hint("b", "UNMASK (one mark)")]

# ---------------------------------------------------------------- crowd
## NPC brain pass. During INTRO every body is crowd-driven (nobody can
## pre-track a player spawn); during the WALTZ, player bodies are skipped.
func _tick_crowd(delta: float, include_players: bool) -> void:
	for b in CROWD_TOTAL:
		if not include_players and body_to_seat[b] >= 0:
			continue
		var d: MBDancer = dancers[b]
		if d.revealed or d.gone:
			continue
		var moved := false
		match d.act:
			MBDancer.Act.CURTSY, MBDancer.Act.TWIRL:
				d.act_t -= delta
				if d.act_t <= 0.0:
					if d.curtsying():
						d.last_curtsy_end = _waltz_e
					d.end_act()
					d.npc_t = crowd_rng.randf_range(0.5, 2.4)
			MBDancer.Act.PAUSE:
				d.npc_t -= delta
				if d.npc_t <= 0.0:
					var roll := crowd_rng.randf()
					var curtsy_p := 0.45 if in_zone(d.position) else 0.10
					if roll < 0.10:
						d.begin_twirl(1.1)
					elif roll < 0.10 + curtsy_p:
						d.begin_curtsy(CURTSY_TIME)
					else:
						d.waypoint = swirl_waypoint(d.position, crowd_rng)
						d.act = MBDancer.Act.DRIFT
			MBDancer.Act.DRIFT:
				var to := d.waypoint - d.position
				to.y = 0.0
				if to.length() < 0.2:
					d.act = MBDancer.Act.PAUSE
					d.npc_t = crowd_rng.randf_range(0.5, 2.4)
				else:
					var dir := to.normalized()
					d.position += dir * DANCE_SPEED * delta
					d.face_toward(dir)
					moved = true
		d.set_walking(moved)
		# ambient mask glints — the noise floor the private pulse hides in
		d.glint_next -= delta
		if d.glint_next <= 0.0:
			d.glint_next = crowd_rng.randf_range(2.0, 6.0)
			d.glint()

# ---------------------------------------------------------------- waltz
func _tick_waltz(delta: float) -> void:
	_waltz_e += delta
	timer_label.text = "%02d" % int(ceil(maxf(0.0, _waltz_len - _waltz_e)))
	# 1) crowd (players excluded)
	_tick_crowd(delta, false)
	# 2) seats, fixed order
	for i in players.size():
		if players[i].eliminated:
			_tick_ghost(i, delta)
		else:
			_tick_seat(i, delta)
	_post_move(delta)
	# 3) corpse fades
	for b in _corpse_fade.keys():
		if _waltz_e >= float(_corpse_fade[b]) and not dancers[b].gone:
			dancers[b].fade_out()
	# 4) scheduled snaps
	_run_pending_snaps()
	if _snaps and not _snapped.has("crowd") and _waltz_e >= 14.0:
		_snapped["crowd"] = true
		_do_snap("crowd")
		VerifyCapture.snap("crowd")
	if _netdemo and not _snapped.has("mb_net_waltz") and _waltz_e >= 20.0:
		_snapped["mb_net_waltz"] = true
		VerifyCapture.snap("mb_net_waltz")
	# 5) end checks
	if _waltz_e >= _waltz_len:
		_end_waltz("buzzer")
	elif _waltz_e > 10.0 and _alive_count() == 1:
		_end_waltz("floor_emptied")
	elif _waltz_e > 10.0 and _nothing_left():
		_end_waltz("nothing_left")

func _tick_seat(i: int, delta: float) -> void:
	var p: Dictionary = players[i]
	var d: MBDancer = dancers[_body_of[i]]
	if p.glint_cd > 0.0:
		p.glint_cd = maxf(0.0, float(p.glint_cd) - delta)
	# actions
	var mv := Vector2.ZERO
	var want_curtsy := false
	var want_mark := false
	if p.is_bot:
		var dec: Dictionary = bots.decide_alive(i, self, delta)
		mv = dec.mv
		want_curtsy = dec.curtsy
		want_mark = dec.mark
		var forced: Dictionary = _forced_override(i, d)
		if not forced.is_empty():
			mv = forced.mv
			want_curtsy = false
			want_mark = forced.mark
	else:
		mv = PlayerInput.get_move(i)
		want_curtsy = PlayerInput.just_pressed(i, "a")
		want_mark = PlayerInput.just_pressed(i, "b")
	# a bow in progress locks the body
	if d.busy():
		d.act_t -= delta
		if d.act_t <= 0.0:
			var was_curtsy := d.curtsying()
			if was_curtsy:
				d.last_curtsy_end = _waltz_e
			d.end_act()
			if was_curtsy:
				_finish_player_curtsy(i, d)
		d.set_walking(false)
		return
	var mag := mv.length()
	if mag >= MOVE_TH:
		var dir3 := Vector3(mv.x, 0, mv.y).normalized()
		var speed := DANCE_SPEED * clampf(mag, 1.0, 1.12)   # bots' hunt stride
		d.position += dir3 * speed * delta
		d.face_toward(dir3)
		d.set_walking(true)
	else:
		d.set_walking(false)
		if mag >= FEATHER_LO and p.glint_cd <= 0.0:
			# THE PRIVATE PULSE: the mask answers the feathered stick
			p.glint_cd = GLINT_CD
			d.glint()
			print("MB_GLINT seat=%d body=%d t=%.1f" % [i, d.body, _waltz_e])
	if want_curtsy:
		d.begin_curtsy(CURTSY_TIME)
	if want_mark and p.mark_left:
		_try_mark(i, d)

## --mbsnaps only: two scripted beats so every reveal state gets a photo.
func _forced_override(i: int, d: MBDancer) -> Dictionary:
	if _netdemo:
		return _netdemo_override(i, d)
	if not _snaps:
		return {}
	if i == 1 and not _forced_waste_done and _waltz_e >= 26.0 and players[1].mark_left:
		var b := _nearest_npc_body(d.position, d.body)
		if b >= 0:
			var to: Vector3 = dancers[b].position - d.position
			to.y = 0.0
			if to.length() <= MARK_REACH * 0.8 and nearest_markable(d.body, d.position) == b:
				return {"mv": Vector2.ZERO, "mark": true}
			return {"mv": Vector2(to.x, to.z).normalized(), "mark": false}
	if i == 0 and not _forced_kill_done and _waltz_e >= 48.0 and players[0].mark_left \
			and players.size() > 2 and not players[2].eliminated:
		var tb: int = _body_of[2]
		var to2: Vector3 = dancers[tb].position - d.position
		to2.y = 0.0
		if to2.length() <= MARK_REACH * 0.8 and nearest_markable(d.body, d.position) == tb:
			return {"mv": Vector2.ZERO, "mark": true}
		return {"mv": Vector2(to2.x, to2.z).normalized() * 1.12, "mark": false}
	return {}

## --mbnetdemo HOST beat: at waltz ~40s the first living bot seat holding a
## mark guarantees whichever reveal path the remote seat's own mark did NOT
## already provide — an unmask-HUMAN if none has landed, otherwise a waste.
## Both two-screen reveal moments get photographed either way.
func _netdemo_override(i: int, d: MBDancer) -> Dictionary:
	if _nd_done or _waltz_e < 40.0 or i != _nd_actor():
		return {}
	var target := -1
	if _unmask_count == 0:
		target = _nearest_human_body(d.position, d.body)
	else:
		target = _nearest_npc_body(d.position, d.body)
	if target < 0:
		_nd_done = true
		return {}
	var to: Vector3 = dancers[target].position - d.position
	to.y = 0.0
	if to.length() <= MARK_REACH * 0.8 and nearest_markable(d.body, d.position) == target:
		_nd_done = true
		return {"mv": Vector2.ZERO, "mark": true}
	return {"mv": Vector2(to.x, to.z).normalized() * 1.12, "mark": false}

## First living bot seat that still holds its mark (-1: beat impossible).
func _nd_actor() -> int:
	for i in players.size():
		var p: Dictionary = players[i]
		if bool(p.is_bot) and not bool(p.eliminated) and bool(p.mark_left):
			return i
	return -1

func _nearest_human_body(from: Vector3, exclude: int) -> int:
	var best := -1
	var best_d := 1e9
	for i in players.size():
		if players[i].eliminated:
			continue
		var b: int = _body_of[i]
		if b == exclude:
			continue
		var d2: MBDancer = dancers[b]
		if d2.revealed or d2.gone:
			continue
		var dist := (d2.position - from).length()
		if dist < best_d:
			best_d = dist
			best = b
	return best

func _nearest_npc_body(from: Vector3, exclude: int) -> int:
	var best := -1
	var best_d := 1e9
	for b in CROWD_TOTAL:
		if b == exclude or body_to_seat[b] >= 0:
			continue
		var d2: MBDancer = dancers[b]
		if d2.revealed or d2.gone:
			continue
		var dist := (d2.position - from).length()
		if dist < best_d:
			best_d = dist
			best = b
	return best

func _finish_player_curtsy(i: int, d: MBDancer) -> void:
	var p: Dictionary = players[i]
	if not in_zone(d.position):
		return   # a bluff, or a bow in the open — free theater
	if int(p.pips) >= PIP_MAX or _waltz_e - float(p.last_pip) < CURTSY_GAP:
		return
	p.pips = int(p.pips) + 1
	p.last_pip = _waltz_e
	p.points = int(p.points) + PIP_PTS
	_net_crt += 1   # wire fact: "somebody bowed for money" — a COUNT, no name
	info_label.text = _info_line()
	# the announcement is UNNAMED — the leak is "somebody bowed for money,
	# just now"; the couch (and the bots) must catch WHO was mid-bow
	# nobody can freeze-frame twenty dancers: anyone mid-bow OR fresh out of
	# one near the throne shares the suspicion
	var curtsiers: Array = []
	for b in CROWD_TOTAL:
		var dd: MBDancer = dancers[b]
		if dd.revealed or dd.gone:
			continue
		var bowed_recently: bool = _waltz_e - dd.last_curtsy_end < 1.2
		if (dd.curtsying() or bowed_recently or b == d.body) and in_zone_wide(dd.position):
			curtsiers.append(b)
	if not curtsiers.has(d.body):
		curtsiers.append(d.body)
	print("MB_CURTSY seat=%d %s pip=%d/%d t=%.1f set=%s" % [i, p.name,
		int(p.pips), PIP_MAX, _waltz_e, str(curtsiers)])
	bots.on_pip_event(curtsiers, i, self)
	_say(_pick_line([
		"Somebody has paid respects to the throne. How dutiful.",
		"Another bow at the dais. The throne remains unimpressed.",
		"A curtsy, for money. The orchestra pretends not to notice.",
	]))
	if not _tally:
		Sfx.play("sink", -10.0)
		_pulse_zone_ring()

## The body an unmask attempt from `pos` would actually grab: the nearest
## unrevealed dancer (never your own) within MARK_REACH, or -1. Shared with
## the bots so they never fire through a bystander.
func nearest_markable(own_body: int, pos: Vector3) -> int:
	var best := -1
	var best_d := MARK_REACH
	for b in CROWD_TOTAL:
		if b == own_body:
			continue
		var dd: MBDancer = dancers[b]
		if dd.revealed or dd.gone:
			continue
		var dist := (dd.position - pos).length()
		if dist < best_d:
			best_d = dist
			best = b
	return best

func _try_mark(i: int, d: MBDancer) -> void:
	var own: int = _body_of[i]
	var best := nearest_markable(own, d.position)
	if best < 0:
		if not _tally:
			Sfx.play("invalid", -10.0)
		return   # nobody in reach — the mark is NOT spent on empty air
	players[i].mark_left = false
	info_label.text = _info_line()
	var victim_seat: int = body_to_seat[best]
	if victim_seat >= 0:
		_unmask_human(i, victim_seat, best, d)
	else:
		_waste_mark(i, best, d)

func _unmask_human(killer: int, victim: int, victim_body: int, killer_d: MBDancer) -> void:
	var vp: Dictionary = players[victim]
	var vd: MBDancer = dancers[victim_body]
	vd.end_act()
	vp.eliminated = true
	vp.ghost_pos = vd.position + Vector3(0, 2.3, 0)
	vp.gust_cd = 2.0
	players[killer].points = int(players[killer].points) + UNMASK_PTS
	_unmask_count += 1
	_kill_events.append({"killer": killer, "victim": victim, "cause": "unmasked"})
	if not _practice:
		_currency.append({"type": "royalty", "player": killer, "amount": ROYALTY_UNMASK,
			"reason": "tore the mask off %s for the room's amusement" % vp.name})
		_currency.append({"type": "grudge", "player": victim, "amount": GRUDGE_MARKED,
			"reason": "unmasked mid-waltz"})
	bots.on_reveal(victim_body)
	# the lunge is public: anyone watching (bots included) now suspects the
	# body that did the tearing — fair-play parity with the couch
	bots.on_kill_seen(killer_d.body, self)
	# wire fact: the FIRST time this seat<->body pair exists anywhere the
	# clients can read, minted at the same frame the couch prints the badge
	_net_rev.append([0, victim, victim_body, killer])
	# REVEAL moment: the victim's badge finally exists
	vd.reveal(vp.color, PlayerBadge.glyph(victim) + " " + vp.name, true)
	_corpse_fade[victim_body] = _waltz_e + 2.6
	killer_d.face_toward(vd.position - killer_d.position)
	killer_d.glint()
	if _first_kill_txt == "":
		_first_kill_txt = "%s tore the mask off %s mid-waltz" % [players[killer].name, vp.name]
	print("MB_MARK killer=%d %s victim=%d %s body=%d t=%.1f" % [killer,
		players[killer].name, victim, vp.name, victim_body, _waltz_e])
	_flash_banner("%s WAS HUMAN" % vp.name, vp.color, 2.6)
	_flash_sub("%s collects the unmasking" % players[killer].name, players[killer].color, 2.6)
	_say(_pick_line([
		"One mask off. %s, everyone. They bowed beautifully, considering." % vp.name,
		"%s, unmasked. The orchestra plays on. It is paid to." % vp.name,
	]))
	_play_seat_tick(victim)
	_shake = maxf(_shake, 0.4)
	if not _tally:
		Sfx.play("grudge", -2.0)
		_time_hit(0.3, 0.4)
		_spawn_ghost_node(victim)
		_spawn_floor_mask(vd.position)
	if _snaps and not _snapped.has("unmask_human"):
		_snapped["unmask_human"] = true
		_pending_snaps.append({"tag": "unmask_human", "at": game_time + 0.9})
		VerifyCapture.snap("unmask_human")
	if _snaps:
		_forced_kill_done = true
	if _netdemo and not _snapped.has("mb_net_unmask"):
		_snapped["mb_net_unmask"] = true
		VerifyCapture.snap("mb_net_unmask")

func _waste_mark(accuser: int, npc_body: int, accuser_d: MBDancer) -> void:
	var p: Dictionary = players[accuser]
	p.points = int(p.points) + WASTE_PTS
	_waste_count += 1
	if not _practice:
		_currency.append({"type": "grudge", "player": accuser, "amount": GRUDGE_WASTE,
			"reason": "accused the furniture"})
	# the position leak — a self-inflicted reveal moment, so the badge shows
	_net_wst.append([accuser, accuser_d.body])   # wire fact, minted with the flash
	accuser_d.do_flash(FLASH_TIME, p.color, PlayerBadge.glyph(accuser) + " " + p.name)
	bots.on_flash(accuser_d.body, self)
	dancers[npc_body].begin_twirl(1.1)   # the furniture, offended
	print("MB_FLASH seat=%d %s body=%d npc=%d t=%.1f" % [accuser, p.name,
		accuser_d.body, npc_body, _waltz_e])
	_flash_banner("%s MARKS THE FURNITURE" % p.name, p.color, 2.2)
	_flash_sub("%+d · their dancer flashes" % WASTE_PTS, Color(1.0, 0.55, 0.4), 2.2)
	_say(_pick_line([
		"That one was furniture, %s. The furniture accepts your apology." % p.name,
		"%s accuses an employee. The employee will dine on this for years." % p.name,
	]))
	_play_seat_tick(accuser)
	_shake = maxf(_shake, 0.22)
	if not _tally:
		Sfx.play("grudge", -6.0)
	if _snaps and not _snapped.has("unmask_npc"):
		_snapped["unmask_npc"] = true
		_pending_snaps.append({"tag": "unmask_npc", "at": game_time + 0.5})
		VerifyCapture.snap("unmask_npc")
	if _snaps:
		_forced_waste_done = true
	if _netdemo and not _snapped.has("mb_net_waste"):
		_snapped["mb_net_waste"] = true
		VerifyCapture.snap("mb_net_waste")

# ---------------------------------------------------------------- ghosts
func _tick_ghost(i: int, delta: float) -> void:
	var p: Dictionary = players[i]
	if p.gust_cd > 0.0:
		p.gust_cd = maxf(0.0, float(p.gust_cd) - delta)
	var mv := Vector2.ZERO
	var gust := false
	if p.is_bot:
		var dec: Dictionary = bots.decide_ghost(i, self, delta)
		mv = dec.mv
		gust = dec.gust
	else:
		mv = PlayerInput.get_move(i)
		gust = PlayerInput.just_pressed(i, "a")
	if mv.length() > 1.0:
		mv = mv.normalized()
	var gp: Vector3 = p.ghost_pos + Vector3(mv.x, 0, mv.y) * GHOST_SPEED * delta
	var k := Vector2(gp.x / (AX * 1.12), gp.z / (AZ * 1.12)).length()
	if k > 1.0:
		gp.x /= k
		gp.z /= k
	gp.y = 2.3
	p.ghost_pos = gp
	if gust and p.gust_cd <= 0.0:
		p.gust_cd = GUST_CD
		if i < _net_gust.size():
			_net_gust[i] = int(_net_gust[i]) + 1   # wire fact: dead = already revealed
		print("MB_GUST seat=%d t=%.1f" % [i, _waltz_e])
		for b in CROWD_TOTAL:
			var d: MBDancer = dancers[b]
			if d.gone or d.revealed:
				continue
			var flat := d.position - Vector3(gp.x, 0, gp.z)
			flat.y = 0.0
			if flat.length() <= GUST_R:
				d.wobble()   # visual shiver only — never logic
		if not _tally:
			Sfx.play("bounce", -14.0, 0.2)
			if p.ghost_node != null:
				(p.ghost_node as MBGhost).gust_fx()
	if p.ghost_node != null:
		(p.ghost_node as Node3D).position = gp

func _spawn_ghost_node(i: int) -> void:
	var g := MBGhost.new()
	g.name = "Ghost%d" % i
	spawn_root.add_child(g)
	g.setup(players[i].color, PlayerBadge.glyph(i) + " " + str(players[i].name))
	g.position = players[i].ghost_pos
	players[i].ghost_node = g
	var nm: String = str(players[i].name)
	get_tree().create_timer(2.6).timeout.connect(func():
		if phase == Phase.WALTZ:
			_say("%s will be haunting the chandeliers for the rest of the evening." % nm))

func _spawn_floor_mask(pos: Vector3) -> void:
	# the fallen mask stays where the body fell — a little monument
	var m := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.115
	mm.height = 0.21
	m.mesh = mm
	m.scale = Vector3(1.0, 0.78, 0.5)
	m.rotation_degrees = Vector3(-88, 0, 24)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.89, 0.8)
	mat.roughness = 0.35
	m.material_override = mat
	m.position = Vector3(pos.x + 0.3, 0.05, pos.z + 0.2)
	spawn_root.add_child(m)

# ---------------------------------------------------------------- post-move
## Shared per-tick cleanup: separation, ellipse clamp, stillness metric,
## flash decay. Runs once per tick, fixed order — deterministic.
var _pos_before: Dictionary = {}

func _post_move(delta: float) -> void:
	# soft separation, fixed pair order
	for a in CROWD_TOTAL:
		var da: MBDancer = dancers[a]
		if da.gone:
			continue
		for b in range(a + 1, CROWD_TOTAL):
			var db: MBDancer = dancers[b]
			if db.gone:
				continue
			var flat := db.position - da.position
			flat.y = 0.0
			var dist := flat.length()
			if dist < SEP_R and dist > 0.0001:
				var push := flat.normalized() * (SEP_R - dist) * 0.5
				da.position -= push
				db.position += push
	for b2 in CROWD_TOTAL:
		var d: MBDancer = dancers[b2]
		if d.gone:
			continue
		# ellipse clamp
		var k := Vector2(d.position.x / (AX * 0.97), d.position.z / (AZ * 0.97)).length()
		if k > 1.0:
			d.position.x /= k
			d.position.z /= k
		d.position.y = 0.0
		# stillness metric (the tell): bows/twirls count as animate
		var before: Vector3 = _pos_before.get(b2, d.position)
		var moved := (d.position - before).length()
		if d.busy() or d.revealed:
			d.still_t = 0.0
		elif moved < 0.45 * DANCE_SPEED * delta:
			d.still_t += delta
		else:
			d.still_t = 0.0
		_pos_before[b2] = d.position
		# waste-flash decay
		if d.flash_t > 0.0:
			d.flash_t = maxf(0.0, d.flash_t - delta)

# ---------------------------------------------------------------- end checks
func _alive_count() -> int:
	var n := 0
	for p in players:
		if not p.eliminated:
			n += 1
	return n

func _nothing_left() -> bool:
	# nothing left to earn or to hunt with: every living seat has all pips
	# and no living seat holds a mark
	for p in players:
		if p.eliminated:
			continue
		if int(p.pips) < PIP_MAX or bool(p.mark_left):
			return false
	return true

func _end_waltz(cause: String) -> void:
	if phase != Phase.WALTZ:
		return
	print("MB_WALTZ_END cause=%s t=%.1f unmasks=%d wastes=%d" % [cause, _waltz_e,
		_unmask_count, _waste_count])
	_begin_reveal()

# ================================================================ REVEAL
func _begin_reveal() -> void:
	phase = Phase.REVEAL
	phase_label.text = "MASKED BALL — THE LAST DANCE"
	hint_label.text = ""
	timer_label.text = ""
	# survival pays at the buzzer
	var survivors: Array = []
	for i in players.size():
		if not players[i].eliminated:
			players[i].points = int(players[i].points) + SURVIVE_PTS
			survivors.append(i)
	print("MB_REVEAL survivors=%s" % str(survivors))
	_seq.clear()
	_seq_t = 0.0
	_seq_add(0.0, func():
		_flash_banner("THE LAST DANCE", Color(0.92, 0.85, 1.0), 2.6)
		_say("The orchestra stops. The masks were always coming off.")
		if not _tally:
			Sfx.play("round_over"))
	_seq_add(1.6, func():
		for b in CROWD_TOTAL:
			if body_to_seat[b] < 0:
				dancers[b].dim_npc()
		_say("The hired bodies may stop pretending."))
	var t := 3.0
	for si in survivors.size():
		var seat := int(survivors[si])
		_seq_add(t, func(): _reveal_survivor(seat))
		t += 1.8
	_seq_add(t + 0.2, func():
		if _snaps and not _snapped.has("reveal"):
			_snapped["reveal"] = true
			_do_snap("reveal")
		VerifyCapture.snap("reveal"))
	# the ledger
	var rows: Array = _ledger_rows()
	_seq_add(t + 0.5, func(): banner.visible = false)
	for ri in rows.size():
		var row: Dictionary = rows[ri]
		_seq_add(t + 0.7 + 0.55 * ri, func(): _add_ledger_row(str(row.text), row.color))
	var t_end := t + 0.7 + 0.55 * rows.size() + 1.2
	_seq_add(t_end, func():
		if _snaps and not _snapped.has("verdict"):
			_snapped["verdict"] = true
			_do_snap("verdict")
		VerifyCapture.snap("settle"))
	# ONLINE: pre-announce the champion one beat before finished() — points are
	# final since survival paid at reveal. report_finished() stops the estate's
	# 20 Hz pump the same tick it runs, so a champ fact set inside
	# _finish_match would never reach the mirror (found by the first probe
	# night: the client missed the confetti). Memory-only on the couch.
	_seq_add(t_end + 0.4, func():
		var champ_order := _placement_order()
		var cw := int(champ_order[0])
		_net_champ = [cw, int(_body_of[cw])])
	_seq_add(t_end + 0.8, func(): _finish_match())

func _reveal_survivor(seat: int) -> void:
	var d: MBDancer = dancers[_body_of[seat]]
	var p: Dictionary = players[seat]
	_net_rev.append([1, seat, int(_body_of[seat]), -1])   # public at this beat
	d.reveal(p.color, PlayerBadge.glyph(seat) + " " + str(p.name), false)
	_reveal_spot.light_energy = 6.5
	_reveal_spot.look_at_from_position(Vector3(d.position.x * 0.5, 9.5, d.position.z * 0.5 + 4.0),
		d.position + Vector3(0, 1.2, 0), Vector3.UP)
	_play_seat_tick(seat)
	_say("%s, all along." % p.name)
	if not _tally:
		Sfx.play("card", -4.0)

func _ledger_rows() -> Array:
	var rows: Array = []
	var order := _placement_order()
	for idx in order:
		var i := int(idx)
		var p: Dictionary = players[i]
		var bits: Array = []
		bits.append("1 curtsy" if int(p.pips) == 1 else "%d curtsies" % int(p.pips))
		var killed := ""
		for ke in _kill_events:
			if int(ke.killer) == i:
				killed = str(players[int(ke.victim)].name)
		if killed != "":
			bits.append("unmasked %s" % killed)
		elif not bool(p.mark_left) and killed == "":
			bits.append("marked the furniture")
		if p.eliminated:
			bits.append("unmasked")
		else:
			bits.append("survived")
		rows.append({"text": "%s %s — %s — %d pts" % [PlayerBadge.glyph(i), p.name,
			" · ".join(bits), int(p.points)], "color": p.color})
	return rows

func _add_ledger_row(text: String, color: Color) -> void:
	if not _mirror:
		_net_led.append([text, color.to_html(false)])   # settle rows, as read out
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_font_size_override("font_size", 24)
	ledger_box.add_child(l)
	if not _tally:
		Sfx.play("card", -8.0)

func _placement_order() -> Array:
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		var pa := int(players[a].points)
		var pb := int(players[b].points)
		if pa != pb:
			return pa > pb
		return a < b)
	return order

func _finish_match() -> void:
	if _reported:
		return
	_reported = true
	phase = Phase.DONE
	var points := {}
	for i in players.size():
		points[i] = int(players[i].points)
	var order := _placement_order()
	# highlights
	if _first_kill_txt != "":
		_highlights.append(_first_kill_txt)
	for i in players.size():
		var p: Dictionary = players[i]
		if not bool(p.mark_left) and not _killed_by(i):
			_highlights.append("%s accused the furniture" % p.name)
			break
	for i in players.size():
		var p2: Dictionary = players[i]
		if not p2.eliminated and int(p2.pips) >= PIP_MAX:
			_highlights.append("%s curtsied thrice and was never suspected" % p2.name)
			break
	if _unmask_count == 0 and _waste_count == 0:
		_highlights.append("four marks unspent — a polite bloodbath of nerves")
	# monuments
	var monuments: Array = []
	if not _practice:
		for i in players.size():
			var p3: Dictionary = players[i]
			if not p3.eliminated and int(p3.pips) >= PIP_MAX and _killed_by(i):
				monuments.append({"player": i, "kind": "belle",
					"label": "%s, Belle of the Ball" % p3.name})
	var results := {
		"placements": order,
		"points": points,
		"currency_events": _currency.duplicate(),
		"kill_events": _kill_events.duplicate(),
		"highlights": _dedup(_highlights).slice(0, 3),
		"monuments": monuments,
	}
	print("KILL_EVENTS n=", _kill_events.size(), " ", JSON.stringify(_kill_events))
	print("MB_RESULTS ", JSON.stringify(results))
	if _tally:
		_print_tally(points)
		report_finished(results)
		get_tree().quit()
		return
	var w := int(order[0])
	_net_champ = [w, int(_body_of[w])]   # by now every body is a public fact
	_flash_banner("%s TAKES THE BALL" % players[w].name, players[w].color, 6.0)
	_say("%s takes the ball. Do try to look surprised." % players[w].name)
	if not _tally:
		Sfx.play("match_win")
		_spawn_confetti(dancers[_body_of[w]].position + Vector3(0, 2.0, 0), players[w].color)
	report_finished(results)
	if _snaps:
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()

func _killed_by(i: int) -> bool:
	for ke in _kill_events:
		if int(ke.killer) == i:
			return true
	return false

func _print_tally(points: Dictionary) -> void:
	print("======== MASKED BALL TALLY ========")
	var alive: Array = []
	for i in players.size():
		if not players[i].eliminated:
			alive.append(players[i].name)
	print("MB_TALLY seed=%d unmasks=%d wastes=%d survivors=%s waltz_end=%.1f" % [
		rng.seed, _unmask_count, _waste_count, str(alive), _waltz_e])
	var bits: Array = []
	for i in players.size():
		bits.append("%s=%d%s" % [players[i].name, int(points[i]),
			"+" if not players[i].eliminated else "x"])
	print("points: %s (+ survived, x unmasked)" % " ".join(bits))
	var pips: Array = []
	for i in players.size():
		pips.append("%s=%d/3" % [players[i].name, int(players[i].pips)])
	print("curtsies: %s" % " ".join(pips))
	print("===================================")

# ================================================================ queries (bots)
func body_of(seat: int) -> int:
	return int(_body_of[seat])

func pos_of(b: int) -> Vector3:
	return dancers[b].position

func still_of(b: int) -> float:
	return dancers[b].still_t

func alive_body(b: int) -> bool:
	var d: MBDancer = dancers[b]
	return not d.revealed and not d.gone

func has_mark(seat: int) -> bool:
	return bool(players[seat].mark_left) and not bool(players[seat].eliminated)

func pips_of(seat: int) -> int:
	return int(players[seat].pips)

func waltz_t() -> float:
	return _waltz_e

func waltz_len() -> float:
	return _waltz_len

func ghost_pos_of(seat: int) -> Vector3:
	return players[seat].ghost_pos

func in_zone(pos: Vector3) -> bool:
	var flat := pos - ZONE_C
	flat.y = 0.0
	return flat.length() <= ZONE_R

func in_zone_wide(pos: Vector3) -> bool:
	var flat := pos - ZONE_C
	flat.y = 0.0
	return flat.length() <= ZONE_R * 1.4

func can_score_curtsy(seat: int) -> bool:
	var p: Dictionary = players[seat]
	return int(p.pips) < PIP_MAX and _waltz_e - float(p.last_pip) >= CURTSY_GAP \
		and in_zone(dancers[_body_of[seat]].position)

func zone_point(angle: float, k: float) -> Vector3:
	return ZONE_C + Vector3(cos(angle) * ZONE_R * k, 0, sin(angle) * ZONE_R * k)

## Shared crowd-swirl waypoint: advance counterclockwise around the floor,
## vary the radius — the whole ballroom slowly rotates, which reads as a
## waltz. Callers pass their OWN rng (crowd vs bot streams stay separate).
func swirl_waypoint(from: Vector3, r: RandomNumberGenerator) -> Vector3:
	var th := atan2(from.z / AZ, from.x / AX)
	th += r.randf_range(0.35, 1.0)
	var k := r.randf_range(0.22, 0.88)
	return Vector3(cos(th) * AX * k, 0, sin(th) * AZ * k)

func player_name(i: int) -> String:
	return players[i].name if i >= 0 and i < players.size() else "???"

func _info_line() -> String:
	var marks := 0
	for p in players:
		if bool(p.mark_left) and not bool(p.eliminated):
			marks += 1
	return "DANCERS %d · HUMANS AMONG THEM %d · MARKS UNSPENT %d" % [
		CROWD_TOTAL, _alive_count(), marks]

# ================================================================ music/audio
func _tick_music(delta: float) -> void:
	if _tally:
		return
	_music_t += delta
	while _music_t >= WALTZ_BEAT:
		_music_t -= WALTZ_BEAT
		_music_beat = (_music_beat + 1) % 3
		if _music_beat == 0:
			_play_pitched("place", 0.74, -15.0)
		else:
			_play_pitched("place", 1.1, -21.0)

func _build_pitched_pool() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pitched_players.append(p)

func _bank_stream(key: String) -> AudioStream:
	var bank: Dictionary = Sfx.BANK
	if not bank.has(key) or (bank[key] as Array).is_empty():
		return null
	return load("res://assets/audio/%s.ogg" % str(bank[key][0]))

func _play_pitched(key: String, pitch: float, volume_db: float) -> void:
	if _tally or _pitched_players.is_empty():
		return
	if not _pitched_streams.has(key):
		_pitched_streams[key] = _bank_stream(key)
	var strm: AudioStream = _pitched_streams[key]
	if strm == null:
		return
	var p: AudioStreamPlayer = _pitched_players[_pitched_next]
	_pitched_next = (_pitched_next + 1) % _pitched_players.size()
	p.stream = strm
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

## Seat-pitch identity tick (house language) — REVEAL moments only.
func _play_seat_tick(seat: int) -> void:
	if _tally:
		return
	var pitch: float = SEAT_TAP_PITCH[seat % SEAT_TAP_PITCH.size()]
	_play_pitched("place", pitch, REVEAL_TICK_DB)
	print("MB_SEAT_TICK p=%d %s pitch=%.2f" % [seat, players[seat].name, pitch])

# ================================================================ sequencer
func _seq_add(t: float, fn: Callable) -> void:
	_seq.append({"t": t, "fn": fn})

func _seq_run(delta: float) -> void:
	_seq_t += delta
	while _seq.size() > 0 and _seq_t >= float(_seq[0].t):
		var ev: Dictionary = _seq.pop_front()
		var fn: Callable = ev.fn
		fn.call()

# ================================================================ fx / ui
func _pulse_zone_ring() -> void:
	if _zone_ring_mat == null:
		return
	_zone_ring_mat.emission_energy_multiplier = 2.2
	var tw := create_tween()
	tw.tween_property(_zone_ring_mat, "emission_energy_multiplier", 0.5, 0.8)

func _say(text: String) -> void:
	executor_label.text = "“" + text + "”  — THE EXECUTOR"

func _pick_line(lines: Array) -> String:
	return str(lines[_fx_rng.randi_range(0, lines.size() - 1)])

func _time_hit(scale: float, real_duration: float) -> void:
	if _tally:
		return
	_time_token += 1
	var my := _time_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_duration, true, false, true).timeout
	if my == _time_token:
		Engine.time_scale = 1.0

func _flash_banner(text: String, color: Color, duration: float) -> void:
	if _tally:
		return
	_ban_col = color.to_html(false)
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
		tw.tween_callback(Callable(self, "_hide_banner_if").bind(my))

func _hide_banner_if(token: int) -> void:
	if token == _banner_token:
		banner.visible = false

func _flash_sub(text: String, color: Color, duration: float) -> void:
	if _tally:
		return
	_sub_col = color.to_html(false)
	sub_banner.text = text
	sub_banner.add_theme_color_override("font_color", color)
	sub_banner.visible = true
	_sub_token += 1
	var my := _sub_token
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(Callable(self, "_hide_sub_if").bind(my))

func _hide_sub_if(token: int) -> void:
	if token == _sub_token:
		sub_banner.visible = false

func _spawn_confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 16
		p.lifetime = 1.2
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 2.5
		p.initial_velocity_max = 5.5
		p.gravity = Vector3(0, -7.0, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.02, 0.07)
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _dedup(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		if not out.has(x):
			out.append(x)
	return out

# ================================================================ snapshots
func _run_pending_snaps() -> void:
	var keep: Array = []
	for s in _pending_snaps:
		if game_time >= float(s.at):
			_do_snap(str(s.tag))
		else:
			keep.append(s)
	_pending_snaps = keep

func _do_snap(tag: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://docs/verify/shots/maskedball_%s.png" % tag
	img.save_png(path)
	print("MB_SNAP ", path)

# ================================================================ ONLINE (phase 2)
# House pattern (docs/verify/online-seance-VERIFY.md PATTERN NOTES): host sim
# untouched, _net_state() = one flat dict of PUBLIC facts, _net_apply() diffs
# and fires ALL juice from deltas, _mirror_tick() interpolates at 60 Hz.
#
# THE PRIVACY CORE: the snapshot is BODY-indexed. Twenty dancers stream the
# same seven quantized fields whether a hand or the crowd's brain drives them;
# glints ride one untagged per-body counter (feather pulses, NPC decoys and
# kill lunges are indistinguishable on the wire, exactly as on the couch).
# seat<->body pairs exist ONLY in the cumulative reveal/waste rows, each
# minted at the frame the couch prints the same badge. No rng_seed, no
# _body_of, no per-seat pips/marks/points ever enter this dict. Masked ball
# sends NOTHING on the private channel — the couch has no private beat: the
# self-ID "secret" is a correlation with your own hidden stick, which the
# transport cannot name and therefore cannot leak.

const MIR_D_STRIDE := 7   # per-body ints: x, z, yaw, act, act_t, flags, glints
const MIR_G_STRIDE := 3   # per-seat ghost ints: on, x, z

## HOST, pumped by the estate at 20 Hz. Ask of every key: is this on every
## couch player's screen right now? Bodies, ghosts, HUD text, reveal rows —
## yes. Who owns an unrevealed body — never.
func _net_state() -> Dictionary:
	if dancers.size() < CROWD_TOTAL:
		return {"ph": phase}   # pump beat before begin() — nothing staged yet
	var dd := PackedInt32Array()
	for b in CROWD_TOTAL:
		var d: MBDancer = dancers[b]
		dd.append(int(roundf(d.position.x * 100.0)))
		dd.append(int(roundf(d.position.z * 100.0)))
		dd.append(int(roundf(wrapf(d.facing, 0.0, TAU) * 1000.0)))
		dd.append(d.act)
		dd.append(int(roundf(maxf(d.act_t, 0.0) * 100.0)))
		var fl := 0
		if d.walking():
			fl |= 1
		if d.revealed:
			fl |= 2
		if d.gone:
			fl |= 4
		if d.dimmed():
			fl |= 8
		dd.append(fl)
		dd.append(d.glints)
	var gh := PackedInt32Array()
	for i in players.size():
		var p: Dictionary = players[i]
		gh.append(1 if bool(p.eliminated) else 0)
		gh.append(int(roundf(float(p.ghost_pos.x) * 100.0)))
		gh.append(int(roundf(float(p.ghost_pos.z) * 100.0)))
	return {
		"ph": phase,
		"wt": snappedf(_waltz_e, 0.1),
		"wl": snappedf(_waltz_len, 0.1),
		"d": dd,
		"gh": gh,
		"gu": _net_gust.duplicate(),
		"crt": _net_crt,
		"rev": _net_rev.duplicate(),
		"wst": _net_wst.duplicate(),
		"led": _net_led.duplicate(),
		"champ": _net_champ.duplicate(),
		"ban": [banner.text, _ban_col, banner.visible],
		"sub": [sub_banner.text, _sub_col, sub_banner.visible],
		"exec": executor_label.text,
		"pl": phase_label.text,
		"info": info_label.text,
		"tmr": timer_label.text,
	}

## CLIENT. Latest-state-wins; all juice from deltas (counters + cumulative
## rows, never events — a dropped packet loses nothing but in-between frames).
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	var first: bool = (prev.get("d", PackedInt32Array()) as PackedInt32Array).is_empty()
	var new_ph := int(state.get("ph", phase))
	if new_ph != phase:
		phase = new_ph as Phase
		print("MB_MIRROR phase -> %s" % Phase.keys()[phase])
		if phase == Phase.WALTZ:
			# the mirror builds the bar from THIS machine's bindings (my local
			# seat samples locally — the tilt/dead_weight mirror precedent)
			hint_label.text = _controls_bar()
		elif phase == Phase.REVEAL:
			hint_label.text = ""
			if not _tally:
				Sfx.play("round_over")
	phase_label.text = str(state.get("pl", ""))
	timer_label.text = str(state.get("tmr", ""))
	info_label.text = str(state.get("info", ""))
	executor_label.text = str(state.get("exec", ""))
	_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	_apply_mir_sub(state.get("sub", []), prev.get("sub", []))
	# --- the twenty bodies: pose facts + glint/fade/dim deltas
	var dd: PackedInt32Array = state.get("d", PackedInt32Array())
	var pd: PackedInt32Array = prev.get("d", PackedInt32Array())
	var n := mini(CROWD_TOTAL, dd.size() / MIR_D_STRIDE)
	for b in n:
		var k := b * MIR_D_STRIDE
		var d: MBDancer = dancers[b]
		if first:
			d.position = Vector3(dd[k] / 100.0, 0, dd[k + 1] / 100.0)
			d.facing = dd[k + 2] / 1000.0
			d.rotation.y = d.facing
		d.mirror_act(dd[k + 3], dd[k + 4] / 100.0)
		var fl := dd[k + 5]
		var pfl := pd[k + 5] if pd.size() > k + 5 else 0
		d.set_walking((fl & 1) == 1)
		if (fl & 4) == 4 and (pfl & 4) == 0 and not d.gone:
			d.fade_out()
		if (fl & 8) == 8 and (pfl & 8) == 0:
			d.dim_npc()   # the hired bodies stop pretending — reveal-beat fact
		var gl := dd[k + 6]
		var pgl := gl if pd.size() <= k + 6 else pd[k + 6]
		if gl > pgl and not first:
			d.glint()
			if _demo_feather:
				# probe receipt: pair these against the host's MB_GLINT lines
				print("MB_MIRROR_GLINT body=%d wt=%.1f" % [b, float(state.get("wt", 0.0))])
				_demo_glint_seen = true
	# --- reveal rows: the ONLY seat<->body pairs on the wire, and each one is
	# applied here at the same beat the couch stamps the badge
	var rev: Array = state.get("rev", [])
	while _mir_rev_n < rev.size():
		_apply_rev_row(rev[_mir_rev_n])
		_mir_rev_n += 1
	var wst: Array = state.get("wst", [])
	while _mir_wst_n < wst.size():
		_apply_wst_row(wst[_mir_wst_n])
		_mir_wst_n += 1
	# --- unnamed scored-curtsy count: ring pulse + coin clink, no name
	if int(state.get("crt", 0)) > int(prev.get("crt", 0)) and not first:
		Sfx.play("sink", -10.0)
		_pulse_zone_ring()
	# --- ghost pews: wisps for the unmasked (dead = already revealed)
	_apply_mir_ghosts(state.get("gh", PackedInt32Array()), state.get("gu", []),
		prev.get("gu", []), first)
	# --- the settle ledger, row by row as the host reads it out
	var led: Array = state.get("led", [])
	while _mir_led_n < led.size():
		var row: Array = led[_mir_led_n]
		_add_ledger_row(str(row[0]), Color.html(str(row[1])))
		_mir_led_n += 1
	# --- the ball is taken
	var champ: Array = state.get("champ", [-1, -1])
	if champ.size() >= 2 and int(champ[0]) >= 0 and _mir_champ < 0:
		_mir_champ = int(champ[0])
		print("MB_MIRROR champ seat=%d body=%d" % [int(champ[0]), int(champ[1])])
		if not _tally:
			Sfx.play("match_win")
			var cb := int(champ[1])
			if cb >= 0 and cb < dancers.size():
				_spawn_confetti(dancers[cb].position + Vector3(0, 2.0, 0),
					players[_mir_champ].color)
		_mir_snap_later("mb_client_verdict", 0.15)   # the fold follows within ~0.6 s
	# --- probe photographs (client side). The glint shot waits for wt >= 15.9:
	# my injected feather glints land at ~13.1 / 14.5 / 15.9 / 17.3 (GLINT_CD
	# cadence), so the first delta past 15.9 catches my own pulse still bright.
	if _netdemo and float(state.get("wt", 0.0)) >= 20.0 and phase == Phase.WALTZ:
		_mir_snap_later("mb_client_waltz", 0.0)
	if _netdemo and _demo_glint_seen and _demo_feather \
			and float(state.get("wt", 0.0)) >= 15.9:
		_mir_snap_later("mb_client_glint", 0.0)

## One reveal row: [kind(0 unmask/1 survivor), seat, body, killer_seat|-1].
func _apply_rev_row(row: Array) -> void:
	if row.size() < 4:
		return
	var kind := int(row[0])
	var seat := int(row[1])
	var body := int(row[2])
	if seat < 0 or seat >= players.size() or body < 0 or body >= dancers.size():
		return
	var p: Dictionary = players[seat]
	var d: MBDancer = dancers[body]
	body_to_seat[body] = seat   # public from this frame on, couch and mirror alike
	d.end_act()
	if kind == 0:
		var killer := int(row[3])
		print("MB_MIRROR unmask victim=%d body=%d killer=%d" % [seat, body, killer])
		p.eliminated = true
		p.ghost_pos = d.position + Vector3(0, 2.3, 0)
		d.reveal(p.color, PlayerBadge.glyph(seat) + " " + str(p.name), true)
		_play_seat_tick(seat)
		_shake = maxf(_shake, 0.4)
		if not _tally:
			Sfx.play("grudge", -2.0)
			_time_hit(0.3, 0.4)
			_spawn_floor_mask(d.position)
		if _netdemo:
			_mir_snap_later("mb_client_unmask", 0.9)
	else:
		print("MB_MIRROR survivor seat=%d body=%d" % [seat, body])
		d.reveal(p.color, PlayerBadge.glyph(seat) + " " + str(p.name), false)
		_reveal_spot.light_energy = 6.5
		_reveal_spot.look_at_from_position(
			Vector3(d.position.x * 0.5, 9.5, d.position.z * 0.5 + 4.0),
			d.position + Vector3(0, 1.2, 0), Vector3.UP)
		_play_seat_tick(seat)
		if not _tally:
			Sfx.play("card", -4.0)
		if _netdemo:
			_mir_snap_later("mb_client_lastdance", 0.8)

## One waste row: [accuser_seat, accuser_body] — the self-inflicted flash.
func _apply_wst_row(row: Array) -> void:
	if row.size() < 2:
		return
	var seat := int(row[0])
	var body := int(row[1])
	if seat < 0 or seat >= players.size() or body < 0 or body >= dancers.size():
		return
	var p: Dictionary = players[seat]
	print("MB_MIRROR waste seat=%d body=%d" % [seat, body])
	dancers[body].do_flash(FLASH_TIME, p.color, PlayerBadge.glyph(seat) + " " + str(p.name))
	_play_seat_tick(seat)
	_shake = maxf(_shake, 0.22)
	if not _tally:
		Sfx.play("grudge", -6.0)
	if _netdemo:
		var tag := "mb_client_ownflash" if seat == NetSession.my_seat() else "mb_client_waste"
		_mir_snap_later(tag, 0.5)

## Ghost lifecycle + gust one-shots from the per-seat rows.
func _apply_mir_ghosts(gh: PackedInt32Array, gu: Array, pgu: Array, first: bool) -> void:
	for i in players.size():
		var k := i * MIR_G_STRIDE
		if k + 2 >= gh.size():
			break
		var p: Dictionary = players[i]
		var pos := Vector3(gh[k + 1] / 100.0, 2.3, gh[k + 2] / 100.0)
		if gh[k] == 1 and p.ghost_node == null:
			var g := MBGhost.new()
			g.name = "Ghost%d" % i
			spawn_root.add_child(g)
			g.setup(p.color, PlayerBadge.glyph(i) + " " + str(p.name))
			g.position = pos
			p.ghost_node = g
		if p.ghost_node != null:
			p.ghost_pos = pos   # target; _mirror_tick glides the wisp
		if i < gu.size() and not first:
			var pg := int(pgu[i]) if i < pgu.size() else int(gu[i])
			if int(gu[i]) > pg and p.ghost_node != null:
				(p.ghost_node as MBGhost).gust_fx()
				if not _tally:
					Sfx.play("bounce", -14.0, 0.2)
				var gp: Vector3 = p.ghost_pos
				for b in CROWD_TOTAL:
					var d: MBDancer = dancers[b]
					if d.gone or d.revealed:
						continue
					var flat := d.position - Vector3(gp.x, 0, gp.z)
					flat.y = 0.0
					if flat.length() <= GUST_R:
						d.wobble()

## CLIENT, per physics tick: glide every puppet toward its authoritative spot;
## everything that must be smoother than 20 Hz lives here.
func _mirror_tick(delta: float) -> void:
	game_time += delta
	_tick_shake(delta)
	if _mir.is_empty():
		return
	var ph := int(_mir.get("ph", Phase.WAITING))
	if ph == Phase.INTRO or ph == Phase.WALTZ:
		_tick_music(delta)
	var w := 1.0 - exp(-14.0 * delta)
	var dd: PackedInt32Array = _mir.get("d", PackedInt32Array())
	var n := mini(CROWD_TOTAL, dd.size() / MIR_D_STRIDE)
	for b in n:
		var k := b * MIR_D_STRIDE
		var d: MBDancer = dancers[b]
		if d.gone:
			continue
		d.position = d.position.lerp(Vector3(dd[k] / 100.0, 0, dd[k + 1] / 100.0), w)
		d.facing = lerp_angle(d.facing, dd[k + 2] / 1000.0, w)
		d.rotation.y = d.facing
		if d.act_t > 0.0:
			d.act_t = maxf(0.0, d.act_t - delta)   # smooth bow/twirl between snaps
		if d.flash_t > 0.0:
			d.flash_t = maxf(0.0, d.flash_t - delta)
	for i in players.size():
		var p: Dictionary = players[i]
		if p.ghost_node != null:
			var g: Node3D = p.ghost_node
			g.position = g.position.lerp(p.ghost_pos, w)
	if _netdemo and NetSession.is_client():
		_demo_tick()

func _apply_mir_banner(arr: Array, parr: Array) -> void:
	if arr.size() < 3:
		return
	banner.text = str(arr[0])
	banner.add_theme_color_override("font_color", Color.html(str(arr[1])))
	var was: bool = parr.size() >= 3 and bool(parr[2]) and str(parr[0]) == str(arr[0])
	banner.visible = bool(arr[2])
	if banner.visible and not was:
		banner.pivot_offset = banner.size / 2.0
		banner.scale = Vector2(0.6, 0.6)
		var pop := create_tween()
		pop.tween_property(banner, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _apply_mir_sub(arr: Array, _parr: Array) -> void:
	if arr.size() < 3:
		return
	sub_banner.text = str(arr[0])
	sub_banner.add_theme_color_override("font_color", Color.html(str(arr[1])))
	sub_banner.visible = bool(arr[2])

func _mir_snap_later(tag: String, wait: float) -> void:
	if _mir_snaps.has(tag):
		return
	_mir_snaps[tag] = true
	if wait <= 0.0:
		VerifyCapture.snap(tag)
	else:
		get_tree().create_timer(wait).timeout.connect(func(): VerifyCapture.snap(tag))

# ---------------- --mbnetdemo client script: a remote hand on the REAL pipe.
# The probe join runs WITHOUT --nettape; this drives MY seat through
# PlayerInput's injection seam (the _dbg_aim pattern, networked — the same
# seam NetSession itself uses for remote seats), so NetSession's 30 Hz
# sampler reads it and streams genuine input packets to the host: stroll,
# FEATHER (the private pulse, sub-threshold at 0.30), the one B mark, a bluff
# curtsy. Only the hand is synthetic; sampler, wire, host sim are the real
# thing end to end.
func _demo_tick() -> void:
	var my := NetSession.my_seat()
	if my < 0:
		return
	var mv := Vector2.ZERO
	var a := false
	var b := false
	if int(_mir.get("ph", 0)) == Phase.WALTZ:
		var wt := float(_mir.get("wt", 0.0))
		_demo_feather = wt >= 13.0 and wt < 21.0
		if wt < 4.0:
			pass                                        # arrive; blend in place
		elif wt < 12.0:
			mv = Vector2.from_angle(wt * 0.5)           # stroll at crowd pace
		elif wt < 13.0:
			pass
		elif wt < 21.0:
			mv = Vector2(0.30, 0.0)                     # FEATHER: my mask answers
		elif wt < 23.0:
			pass
		elif wt < 26.0:
			b = wt - floorf(wt) < 0.4 and int(wt) % 4 == 3   # spend the mark
		elif wt < 28.0:
			mv = Vector2.from_angle(wt * 0.5 + 1.0)
		elif wt < 28.4:
			a = true                                    # a bluff curtsy
		elif wt < 36.0:
			mv = Vector2.from_angle(wt * 0.45)
			b = wt - floorf(wt) < 0.4 and int(wt) % 4 == 3   # retry if unspent
		else:
			mv = Vector2.from_angle(wt * 0.35 + 2.0)    # keep dancing…
			# …and if the scripted beat unmasked ME, these A presses gust
			# the crowd from the pews instead (alive: harmless bluff bows)
			a = wt - floorf(wt) < 0.4 and int(wt) % 6 == 2
	else:
		_demo_feather = false
	_inject(my, mv, a, b)

func _inject(seat: int, mv: Vector2, a: bool, b: bool) -> void:
	if a and not _inj_a_prev:
		_inj_pa += 1
	if b and not _inj_b_prev:
		_inj_pb += 1
	_inj_a_prev = a
	_inj_b_prev = b
	_inj_seq = (_inj_seq + 1) & 0xFFFF
	PlayerInput.set_remote_state(seat, {"seq": _inj_seq, "seat": seat, "move": mv,
		"a": a, "b": b, "presses_a": _inj_pa, "presses_b": _inj_pb,
		"aim": Vector3.ZERO, "aim_screen": Vector2.ZERO, "stick": Vector2.ZERO})

# ================================================================ verify hooks
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.WALTZ
