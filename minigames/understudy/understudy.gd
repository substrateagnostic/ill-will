extends Minigame
## THE UNDERSTUDY — a couch-native, two-button re-engineering of the Spyfall
## odd-one-out for EXACTLY four seats. Three players are the CAST and privately
## learn tonight's PLAY. The fourth is the UNDERSTUDY, who never got the script
## and must deduce the play from the rehearsal and blend. The house then names
## the pretender. THE EXECUTOR runs the theater.
##
## WHY IT DOES NOT STALEMATE (the four-player problem): a single majority
## accusation vote deadlocks at 2-2. Here scoring is DISTRIBUTED across every
## actor's individual choices — each cast member scores for a correct unmasking
## on their own, the understudy scores per dodged accusation plus survival, and
## the rehearsal pays out independently. A perfect 2-2 split still yields a
## fully-ranked scoreboard. See docs/verify/understudy-VERIFY.md.
##
## Anthology module: root of minigames/understudy/understudy.tscn, extends
## Minigame. Self-starts standalone ~0.5s after _ready if begin() was not
## called (GameState colors/names, KayKit chars, seed from --seed= or 1).
##
## PER-SEAT BOTS: bot per roster[i].bot, else PlayerInput.standalone_bot_default.
## --usbots forces everyone. Bots play LEGIBLY and deterministically (us_bots.gd).
##
## CLI user args (after `--`):
##   --usbots            all seats are seeded self-play bots
##   --seed=N            rng seed for standalone start (default 1)
##   --players=N         standalone roster size 2..4 (designed for 4)
##   --usrounds=N        override round count (1..8; default = one per player)
##   --ustally           headless evidence mode: full bot match fast-forwarded,
##                       prints US_TALLY + US_RESULTS and quits
##   --ussnaps           windowed bot match that saves the four key moments to
##                       docs/verify/shots/understudy_*.png
##   --shots=N,...       VerifyCapture PNG harness (global autoload)

enum Phase { WAITING, INTRO, CASTING, REHEARSAL, VOTE, RESOLVE, ROUND_END, MATCH_END }
enum Cast { ROLLCALL, CALL, PEEK, GAP }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

## Tonight's repertory. Each play: a title and six on-script cue words. Words
## may belong to more than one play (OATH) — pleasant ambiguity for the mole.
const PLAYS := {
	"shipwreck": {"title": "THE SHIPWRECK", "words": ["LIFEBOAT", "ROPE", "STORM", "CAPTAIN", "DROWN", "LANTERN"]},
	"coronation": {"title": "THE CORONATION", "words": ["CROWN", "THRONE", "VELVET", "OATH", "HERALD", "SCEPTER"]},
	"heist": {"title": "THE HEIST", "words": ["VAULT", "MASK", "ALARM", "GETAWAY", "BLUEPRINT", "LOOT"]},
	"haunting": {"title": "THE HAUNTING", "words": ["CANDLE", "WHISPER", "PORTRAIT", "CELLAR", "CHAIN", "SHROUD"]},
	"wedding": {"title": "THE WEDDING", "words": ["VOWS", "RING", "TOAST", "VEIL", "BOUQUET", "ALTAR"]},
	"trial": {"title": "THE TRIAL", "words": ["GAVEL", "VERDICT", "WITNESS", "ALIBI", "JURY", "OATH"]},
}

const PASSES := 2                 # cues delivered per player during a rehearsal
const UNMASK_PTS := 2   # each cast voter who correctly names the understudy
const SURVIVAL_PTS := 3 # understudy who escapes a working conviction (<2 correct)
const FRAME_PTS := 2    # understudy whose framed target drew the real pile-on
const BLEND_PTS := 1    # understudy, per on-script cue slipped past the house

const MARK_X := [-3.7, -1.25, 1.25, 3.7]

# --- eyes-closed VOICE SUMMONS (playtest fix) -------------------------------
# First tester on the eyes-closed casting: "how da hell if everyone eyes are
# closed are people supposed to know who should look first." A visual "LOOK NOW"
# is useless to a blind table. So when a seat is called, the room speaks its
# COLOUR — three ticks at a seat-distinct pitch before the card, a fourth as it
# flips. Same pitch mapping as THE SÉANCE's chant tick (RED .90 / BLUE 1.00 /
# GOLD 1.12 / MINT 1.26) so the two theater games share one house language. A
# roll-call teaches every colour its sound, eyes OPEN, before the lights fall.
# Presentation only: a local pitched-tick pool over the existing Sfx bank, inert
# in tally (no new audio files, no RNG, no bot logic touched).
const SEAT_TAP_PITCH := [0.9, 1.0, 1.12, 1.26]
const SUMMONS_TICK_DB := -4.0
const SUMMONS_GAP := 0.35          # seconds between the three summons ticks
const CAST_GAP := 2.2              # silence between one seat's eyes-down and the next summons
const ROLLCALL_INTRO := 2.0        # eyes-open teaching intro hold
const ROLLCALL_SEAT := 1.75        # per-colour teaching slot

# --- state ------------------------------------------------------------------
var phase := Phase.WAITING
var rng := RandomNumberGenerator.new()
var bots: USBots

var roster: Array = []
var players: Array = []            # {index,name,color,char_path,device,is_bot,total,und_rounds,und_caught}
var actors: Array = []             # index -> USActor

var rounds_total := 4
var round_index := 0
var _und_perm: Array = []          # seeded understudy rotation
var round_understudy := -1
var tonight_play := ""

# rehearsal (public: bots read these)
var cur_grid: Array = []           # current beat's words
var cue_history: Array = []        # [{player,word,on_script}] this round
var offscript_count: Dictionary = {}
var onscript_count: Dictionary = {}

# vote
var votes: Dictionary = {}         # voter index -> target index
var _vote_locked: Dictionary = {}  # voter -> bool
var _vote_cursor: Dictionary = {}  # voter -> target column (player index)
var _vote_bot_t: Dictionary = {}   # voter -> elapsed
var _vote_bot_delay: Dictionary = {}
var _vote_target: Dictionary = {}  # voter index -> target SEAT (bots, precomputed once/round)
var _vote_settled := false         # all votes in; hold the full board a beat
var _vote_settle_t := 0.0

# results accumulation
var _currency: Array = []
var _highlights: Array = []

# phase sequencing
var _t := 0.0                      # generic phase timer
var _cast_seat := 0
var _cast_step := Cast.CALL
var _cast_bot_t := 0.0
var _call_tick_i := 0              # how many of the seat's 3 summons ticks have fired
var _rc_seat := -1                 # roll-call: colour being taught (-1 = intro)
var _rc_seat_t := 0.0
var _rc_tick_i := 0
# pitched-tick pool (presentation only; mirrors the seance audio pass)
var _pitched_players: Array = []
var _pitched_next := 0
var _pitched_streams: Dictionary = {}
var _beat := 0                     # rehearsal beat index
var _beat_order: Array = []        # seat order across passes
var _reh_step := 0                 # 0 pick, 1 result
var _reh_cursor := 0
var _reh_bot_t := 0.0
var _reh_bot_goal := 0             # bot's chosen cue index (precomputed once/beat)
var _reh_locked_word := -1
var _nav_prev: Dictionary = {}
var _round_pts: Dictionary = {}
var _re_events: Array = []
var _re_t := 0.0
var _re_done := 0.0

# modes
var _started := false
var _all_bots := false
var _tally := false
var _snaps := false
var _snapped: Dictionary = {}
var _cli_players := 4
var _cli_seed := 1
var _rounds_override := 0

# fx tokens
var _banner_token := 0
var _sub_token := 0

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var stage_root: Node3D = $StageRoot
@onready var executor_line: Label = $UI/ExecutorLine
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var banner: Label = $UI/Banner
@onready var sub_banner: Label = $UI/SubBanner
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows

var reveal_ui: USReveal
var board: USBoard

# ============================================================== lifecycle
func _ready() -> void:
	_parse_args()
	_build_world()
	banner.visible = false
	sub_banner.visible = false
	reveal_ui = USReveal.new()
	add_child(reveal_ui)
	board = USBoard.new()
	add_child(board)
	if not _tally:
		_build_pitched_pool()
	await get_tree().create_timer(0.5).timeout
	if not _started:
		begin(_default_config())

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--usbots":
			_all_bots = true
		elif arg == "--ustally":
			_tally = true
			_all_bots = true
		elif arg == "--ussnaps":
			_snaps = true
			_all_bots = true
		elif arg.begins_with("--usrounds="):
			_rounds_override = clampi(int(arg.trim_prefix("--usrounds=")), 1, 8)
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
	if _tally:
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
			"char_scene": CHAR_FALLBACKS[i % CHAR_FALLBACKS.size()],
			"device": dev,
			"bot": _all_bots or dev == -3 or dev == -99 or PlayerInput.standalone_bot_default(i),
		})
	return {"roster": r, "rounds": 0, "rng_seed": _cli_seed, "practice": false}

func begin(config: Dictionary) -> void:
	if _started:
		return
	_started = true
	rng.seed = int(config.get("rng_seed", 1))
	roster = config.get("roster", [])
	var n: int = roster.size()
	bots = USBots.new()
	bots.setup(int(config.get("rng_seed", 1)) ^ 0x5D511D, n)

	players.clear()
	actors.clear()
	for i in n:
		var pl: Dictionary = roster[i]
		var char_path := str(pl.get("char_scene", ""))
		if char_path == "" or not ResourceLoader.exists(char_path):
			char_path = CHAR_FALLBACKS[i % CHAR_FALLBACKS.size()]
		var idx: int = int(pl.get("index", i))
		var is_bot: bool = _all_bots or bool(pl.get("bot", PlayerInput.standalone_bot_default(idx)))
		players.append({
			"index": idx,
			"name": str(pl.get("name", "P%d" % i)),
			"color": pl.get("color", Color.WHITE),
			"char_path": char_path,
			"device": int(pl.get("device", -99)),
			"is_bot": is_bot,
			"total": 0,
			"und_rounds": 0,
			"und_caught": 0,
			"unmask_hits": 0,
			"cast_rounds": 0,
		})
		var a := USActor.new()
		a.name = "Actor%d" % i
		stage_root.add_child(a)
		a.position = Vector3(MARK_X[i % MARK_X.size()], 0.0, 0.0)
		a.setup(idx, players[i].color, players[i].name, load(char_path), 0.0)
		actors.append(a)

	# rounds: default one turn as understudy per player; honor overrides
	rounds_total = n
	if config.get("practice", false):
		rounds_total = 1
	var req: int = int(config.get("rounds", 0))
	if req > 0:
		rounds_total = clampi(req, 1, 8)
	if _rounds_override > 0:
		rounds_total = _rounds_override

	# seeded understudy rotation (a shuffled seat order, cycled if needed)
	_und_perm = []
	for i in n:
		_und_perm.append(i)
	_shuffle(_und_perm)

	print("US_BEGIN players=%d seed=%d rounds=%d bots=%s" % [n, rng.seed, rounds_total,
		str(players.map(func(p): return p.is_bot))])
	hint_label.text = "STICK = CHOOSE     A = COMMIT"
	round_index = 0
	_start_round()

# ============================================================== world
func _build_world() -> void:
	var we: WorldEnvironment = $WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.42)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.06, 0.08)
	env.fog_density = 0.012
	we.environment = env

	cam.global_position = Vector3(0, 3.55, 8.7)
	cam.look_at(Vector3(0, 1.35, 0), Vector3.UP)
	cam.fov = 52.0

	# key wash from the front-top so faces read; warm
	var key := DirectionalLight3D.new()
	key.name = "KeyWash"
	add_child(key)
	key.rotation_degrees = Vector3(-42.0, 8.0, 0.0)
	key.light_energy = 0.35
	key.light_color = Color(1.0, 0.88, 0.72)

	_build_stage()
	_build_curtains()
	_build_footlights()
	_build_house_seats()

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _build_stage() -> void:
	# wooden boards
	var floor := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(13.0, 0.4, 7.0)
	floor.mesh = fm
	floor.material_override = _mat(Color(0.28, 0.18, 0.11), 0.85)
	floor.position = Vector3(0, -0.2, -0.6)
	$Arena.add_child(floor)
	# plank seams
	for i in range(-6, 7):
		var seam := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.03, 0.42, 7.0)
		seam.mesh = sm
		seam.material_override = _mat(Color(0.18, 0.11, 0.07), 1.0)
		seam.position = Vector3(float(i), -0.19, -0.6)
		$Arena.add_child(seam)
	# back wall
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(13.0, 7.0, 0.4)
	wall.mesh = wm
	wall.material_override = _mat(Color(0.12, 0.07, 0.10), 0.95)
	wall.position = Vector3(0, 3.2, -3.9)
	$Arena.add_child(wall)
	# painted backdrop panel (deep theatre indigo with a warm moon)
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9.5, 4.6, 0.1)
	back.mesh = bm
	var backmat := StandardMaterial3D.new()
	backmat.albedo_color = Color(0.10, 0.09, 0.20)
	backmat.emission_enabled = true
	backmat.emission = Color(0.10, 0.09, 0.22)
	backmat.emission_energy_multiplier = 0.25
	back.material_override = backmat
	back.position = Vector3(0, 3.0, -3.68)
	$Arena.add_child(back)
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.7
	mm.height = 1.4
	moon.mesh = mm
	var moonmat := StandardMaterial3D.new()
	moonmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moonmat.albedo_color = Color(0.98, 0.9, 0.7)
	moonmat.emission_enabled = true
	moonmat.emission = Color(1.0, 0.9, 0.65)
	moonmat.emission_energy_multiplier = 1.4
	moon.mesh = mm
	moon.material_override = moonmat
	moon.position = Vector3(-2.9, 4.1, -3.6)
	$Arena.add_child(moon)

func _build_curtains() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.5, 0.05, 0.08)
	red.roughness = 0.75
	red.emission_enabled = true
	red.emission = Color(0.32, 0.02, 0.05)
	red.emission_energy_multiplier = 0.35
	# top valance swag
	var val := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(13.2, 1.5, 0.5)
	val.mesh = vm
	val.material_override = red
	val.position = Vector3(0, 6.1, 2.0)
	$Arena.add_child(val)
	# side drapes as folded pillars
	for sx in [-6.0, 6.0]:
		for f in 4:
			var drape := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(0.55, 6.6, 0.5)
			drape.mesh = dm
			drape.material_override = red
			var fold := 1.0 - 0.12 * (f % 2)
			drape.scale.x = fold
			drape.position = Vector3(sx + (0.5 * f if sx < 0 else -0.5 * f), 3.3, 2.0)
			$Arena.add_child(drape)
	# gold trim tie
	for sx2 in [-5.2, 5.2]:
		var tie := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(1.3, 0.28, 0.6)
		tie.mesh = tm
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.85, 0.66, 0.24)
		gold.metallic = 0.6
		gold.roughness = 0.4
		gold.emission_enabled = true
		gold.emission = Color(0.7, 0.5, 0.15)
		gold.emission_energy_multiplier = 0.4
		tie.material_override = gold
		tie.position = Vector3(sx2, 2.6, 2.2)
		$Arena.add_child(tie)

func _build_footlights() -> void:
	var lip := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(12.6, 0.3, 0.35)
	lip.mesh = lm
	lip.material_override = _mat(Color(0.14, 0.09, 0.06), 0.9)
	lip.position = Vector3(0, 0.06, 2.7)
	$Arena.add_child(lip)
	for i in 13:
		var x := -6.0 + i * 1.0
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.28
		dome.mesh = sm
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_color = Color(1.0, 0.82, 0.5)
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.72, 0.34)
		gm.emission_energy_multiplier = 2.1
		dome.material_override = gm
		dome.position = Vector3(x, 0.22, 2.68)
		$Arena.add_child(dome)
		if i % 3 == 1:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.36)
			l.light_energy = 1.5
			l.omni_range = 4.0
			l.position = Vector3(x, 0.5, 2.4)
			$Arena.add_child(l)

func _build_house_seats() -> void:
	# a hint of a dark audience below the apron so the stage reads as a stage
	var floor := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(16.0, 0.2, 6.0)
	floor.mesh = fm
	floor.material_override = _mat(Color(0.05, 0.03, 0.05), 1.0)
	floor.position = Vector3(0, -0.6, 6.5)
	$Arena.add_child(floor)

# ============================================================== rounds
func _start_round() -> void:
	phase = Phase.INTRO
	_t = 0.0
	votes.clear()
	_vote_locked.clear()
	_vote_cursor.clear()
	_vote_bot_t.clear()
	cue_history.clear()
	offscript_count.clear()
	onscript_count.clear()
	_round_pts.clear()
	for i in players.size():
		offscript_count[players[i].index] = 0
		onscript_count[players[i].index] = 0
		_round_pts[players[i].index] = 0

	round_understudy = int(_und_perm[round_index % _und_perm.size()])
	players[_seat_of(round_understudy)].und_rounds += 1
	for i in players.size():
		if players[i].index != round_understudy:
			players[i].cast_rounds += 1
	# tonight's play (seeded); understudy candidate list is all plays
	var keys: Array = PLAYS.keys()
	tonight_play = str(keys[rng.randi_range(0, keys.size() - 1)])

	# reset actors to lit idle facing front
	for a in actors:
		a.set_lit(USActor.SPOT_BASE)
		a.face_front()
		a.play_idle()
		a.hide_status()

	round_label.text = "ACT %d / %d" % [round_index + 1, rounds_total]
	_rebuild_scoreboard()
	board.hide_all()
	print("US_ROUND %d/%d play=%s understudy=%s" % [round_index + 1, rounds_total,
		tonight_play, player_name(round_understudy)])
	_say("Act the %s. Tonight's play is chosen. Three of you have read it. One has not." % _ordinal(round_index + 1))
	if not _tally:
		_flash_banner("ACT %d" % (round_index + 1), Color(1.0, 0.83, 0.36), 1.6)
		_flash_sub("EYES TO THE FLOOR — I WILL CALL YOU EACH IN TURN", Color(0.85, 0.7, 0.6), 2.4)

func _seat_of(pindex: int) -> int:
	for i in players.size():
		if players[i].index == pindex:
			return i
	return 0

# ============================================================== tick
func _physics_process(delta: float) -> void:
	for a in actors:
		a.tick(delta)
	match phase:
		Phase.INTRO:
			_t += delta
			if _t >= (0.2 if _tally else 2.6):
				_enter_casting()
		Phase.CASTING:
			_tick_casting(delta)
		Phase.REHEARSAL:
			_tick_rehearsal(delta)
		Phase.VOTE:
			_tick_vote(delta)
		Phase.RESOLVE:
			_tick_resolve(delta)
		Phase.ROUND_END:
			_tick_round_end(delta)
		_:
			pass

# ============================================================== casting
func _enter_casting() -> void:
	phase = Phase.CASTING
	_cast_seat = 0
	_cast_bot_t = 0.0
	reveal_ui.open()
	_set_base_ui(false)
	if _tally:
		# no teaching roll-call in the headless evidence run — sim path unchanged
		_cast_step = Cast.CALL
		_say("The casting. When your colour is called, and only then, look up.")
		_present_call()
	else:
		# VOICE ROLL-CALL: teach every colour its summons, eyes OPEN, before the
		# lights fall — so a blind player can recognise the call later.
		_cast_step = Cast.ROLLCALL
		_rc_seat = -1
		_rc_seat_t = 0.0
		_rc_tick_i = 0
		_say("Your colour has a voice. Learn it now — eyes open — before the lights fall.")
		reveal_ui.show_rollcall_intro()

func _present_call() -> void:
	var pl: Dictionary = players[_cast_seat]
	_call_tick_i = 0        # arm this seat's three summons ticks
	# dim everyone; the caller's mark glows
	for i in actors.size():
		actors[i].set_lit(0.6 if i != _cast_seat else USActor.SPOT_FOCUS)
	reveal_ui.show_call(pl.name, pl.color, PlayerBadge.glyph(pl.index))

## Roll-call teaching slot: light the taught colour, name it huge.
func _present_teach(seat: int) -> void:
	var pl: Dictionary = players[seat]
	for i in actors.size():
		actors[i].set_lit(0.6 if i != seat else USActor.SPOT_FOCUS)
	reveal_ui.show_teach(pl.name, pl.color, PlayerBadge.glyph(pl.index))

func _tick_casting(delta: float) -> void:
	if _cast_step == Cast.ROLLCALL:
		_tick_rollcall(delta)
		return
	if _cast_step == Cast.GAP:
		# ≥2s of silence between one seat's eyes-down and the next summons
		_cast_bot_t += delta
		if _cast_bot_t >= CAST_GAP:
			_cast_step = Cast.CALL
			_cast_bot_t = 0.0
			_present_call()
		return
	var pl: Dictionary = players[_cast_seat]
	var seat_bot: bool = pl.is_bot
	if _cast_step == Cast.CALL:
		_cast_bot_t += delta
		# AUDIO SUMMONS: three ticks in this seat's tone as the call lands, BEFORE
		# the card can be read — the only cue a player with eyes closed gets.
		if not _tally:
			var marks := [0.15, 0.15 + SUMMONS_GAP, 0.15 + 2.0 * SUMMONS_GAP]
			while _call_tick_i < marks.size() and _cast_bot_t >= marks[_call_tick_i]:
				_play_summons_tick(_cast_seat)
				_call_tick_i += 1
		var peek := false
		if seat_bot:
			if _cast_bot_t >= bots.read_beat(_cast_seat):
				peek = true
		else:
			peek = PlayerInput.just_pressed(pl.index, "a")
		if _cast_bot_t > 8.0:
			peek = true
		if peek:
			_play_summons_tick(_cast_seat)   # fourth confirmation tick as the card turns
			if pl.index == round_understudy:
				var cands: Array = []
				for k in PLAYS:
					cands.append(PLAYS[k].title)
				reveal_ui.flip_to_understudy(cands)
			else:
				reveal_ui.flip_to_cast(str(PLAYS[tonight_play].title))
			_cast_step = Cast.PEEK
			_cast_bot_t = 0.0
	else:
		_cast_bot_t += delta
		if _cast_bot_t >= (0.5 if _tally else 0.75):
			_maybe_snap("reveal")   # card fully flipped face-up
		var commit := false
		if seat_bot:
			if _cast_bot_t >= (0.3 if _tally else 1.65):   # +50% reveal hold for humans
				commit = true
		else:
			commit = PlayerInput.just_pressed(pl.index, "a")
		if _cast_bot_t > 7.0:
			commit = true
		if commit:
			_cast_seat += 1
			_cast_bot_t = 0.0
			if _cast_seat >= players.size():
				_cast_step = Cast.CALL
				reveal_ui.close()
				_enter_rehearsal()
			elif _tally:
				# original path: straight to the next call, no interstitial gap
				_cast_step = Cast.CALL
				_present_call()
			else:
				# eyes down, hold the silence, then summon the next colour
				_cast_step = Cast.GAP
				reveal_ui.show_gap()

func _tick_rollcall(delta: float) -> void:
	if _rc_seat < 0:
		_cast_bot_t += delta
		if _cast_bot_t >= ROLLCALL_INTRO:
			_rc_seat = 0
			_rc_seat_t = 0.0
			_rc_tick_i = 0
			_present_teach(_rc_seat)
		return
	_rc_seat_t += delta
	var marks := [0.15, 0.15 + SUMMONS_GAP, 0.15 + 2.0 * SUMMONS_GAP]
	while _rc_tick_i < marks.size() and _rc_seat_t >= marks[_rc_tick_i]:
		_play_summons_tick(_rc_seat)
		_rc_tick_i += 1
	if _rc_seat_t >= ROLLCALL_SEAT:
		_rc_seat += 1
		if _rc_seat >= players.size():
			# every colour taught — now fall the lights and call the first seat
			_cast_step = Cast.CALL
			_cast_bot_t = 0.0
			_say("The casting. When your colour is called — and only then — look up.")
			_present_call()
		else:
			_rc_seat_t = 0.0
			_rc_tick_i = 0
			_present_teach(_rc_seat)

# ---------------------------------------------- pitched audio (presentation)
## Local AudioStreamPlayer pool so a bank sound can play at a fixed pitch_scale
## (Sfx.play only offers a symmetric wobble around 1.0). Built once, never in
## tally, routed through the same "SFX" bus the settings sliders drive. Reuses
## the existing Sfx bank streams — no new audio files. Mirrors the seance pass.
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

## The turn summons — a seat's OWN pitch (same mapping as the seance chant tick),
## loud enough to carry with eyes shut. Reads only the seat index. Inert in tally.
func _play_summons_tick(seat: int) -> void:
	if _tally:
		return
	var pitch: float = SEAT_TAP_PITCH[seat % SEAT_TAP_PITCH.size()]
	_play_pitched("card", pitch, SUMMONS_TICK_DB)
	print("US_SUMMONS seat=%d %s pitch=%.2f" % [seat, players[seat].name, pitch])

# ============================================================== rehearsal
func _enter_rehearsal() -> void:
	phase = Phase.REHEARSAL
	_set_base_ui(true)
	board.show_rehearsal(true)
	# shuffle each pass independently (seeded) so exposure is not welded to seat
	# order — otherwise seat 0 would always deliver the first, blindest cue
	_beat_order = []
	for _p in PASSES:
		var pass_order: Array = []
		for i in players.size():
			pass_order.append(i)
		_shuffle(pass_order)
		_beat_order.append_array(pass_order)
	_beat = 0
	_say("The rehearsal begins. Deliver your lines, and mind that I am watching.")
	if not _tally:
		_flash_banner("THE REHEARSAL", Color(1.0, 0.83, 0.36), 1.4)
	_present_beat()

func _present_beat() -> void:
	for a in actors:
		a.set_focus(false)
		a.set_lit(0.9)
	var seat: int = _beat_order[_beat]
	var pl: Dictionary = players[seat]
	actors[seat].set_focus(true)
	cur_grid = _build_beat_grid()
	board.show_grid(cur_grid)
	board.set_active(pl.name, pl.color, PlayerBadge.glyph(pl.index))
	_reh_step = 0
	_reh_bot_t = 0.0
	_reh_locked_word = -1
	_reh_cursor = 0
	# compute the bot's cue ONCE per beat (pick_cue consumes RNG)
	_reh_bot_goal = bots.pick_cue(seat, self) if pl.is_bot else 0
	board.set_word_cursor(0, pl.color)
	timer_label.text = ""

func _tick_rehearsal(delta: float) -> void:
	var seat: int = _beat_order[_beat]
	var pl: Dictionary = players[seat]
	if _reh_step == 0:
		_reh_bot_t += delta
		var nav := 0
		var confirm := false
		if pl.is_bot:
			if _reh_bot_t >= (0.25 if _tally else 0.9):
				if _reh_cursor != _reh_bot_goal:
					nav = 1 if _reh_bot_goal > _reh_cursor else -1
				else:
					confirm = true
				_reh_bot_t = 0.0
		else:
			nav = _nav_dir(pl.index)
			confirm = PlayerInput.just_pressed(pl.index, "a")
			if _reh_bot_t > 6.0:
				confirm = true
		if nav != 0:
			_reh_cursor = wrapi(_reh_cursor + nav, 0, cur_grid.size())
			board.set_word_cursor(_reh_cursor, pl.color)
			if not _tally:
				Sfx.play("card", -6.0)
		if confirm:
			_deliver_cue(seat, _reh_cursor)
	else:
		_reh_bot_t += delta
		if _reh_bot_t >= (0.3 if _tally else 1.15):
			_beat += 1
			if _beat >= _beat_order.size():
				actors[seat].set_focus(false)
				_enter_vote()
			else:
				_present_beat()

func _deliver_cue(seat: int, idx: int) -> void:
	var pl: Dictionary = players[seat]
	var word := str(cur_grid[idx])
	var on_script: bool = word_in_play(word, tonight_play)
	cue_history.append({"player": pl.index, "word": word, "on_script": on_script})
	if on_script:
		onscript_count[pl.index] = int(onscript_count[pl.index]) + 1
		# blend points reward the UNDERSTUDY for passing without the script; the
		# cast trivially know the play, so on-script cues are not skill for them
		if pl.index == round_understudy:
			_round_pts[pl.index] = int(_round_pts[pl.index]) + BLEND_PTS
	else:
		offscript_count[pl.index] = int(offscript_count[pl.index]) + 1
	board.lock_word(idx, on_script, pl.color)
	_reh_locked_word = idx
	_reh_step = 1
	_reh_bot_t = 0.0
	if on_script:
		actors[seat].show_status("“%s”" % word, Color(0.95, 0.88, 0.72))
		actors[seat].play_cheer()
		if not _tally:
			Sfx.play("confirm", -3.0)
	else:
		actors[seat].show_status("“%s”?" % word, Color(1.0, 0.5, 0.45))
		actors[seat].play_flinch()
		if not _tally:
			Sfx.play("invalid", -6.0)
			_flash_sub("AN OFF-SCRIPT LINE. HOW ILLUMINATING.", Color(1.0, 0.55, 0.4), 1.3)
	print("US_CUE act=%d %s says \"%s\" %s" % [round_index + 1, pl.name, word,
		"(on-script)" if on_script else "(OFF-SCRIPT)"])
	_maybe_snap("rehearsal")

func _build_beat_grid() -> Array:
	var tw: Array = (PLAYS[tonight_play].words as Array).duplicate()
	_shuffle(tw)
	var trues: Array = tw.slice(0, 3)
	var pool: Array = []
	for key in PLAYS:
		if key == tonight_play:
			continue
		for w in PLAYS[key].words:
			if not (w in PLAYS[tonight_play].words) and not (w in pool):
				pool.append(w)
	_shuffle(pool)
	var foils: Array = pool.slice(0, 3)
	var grid: Array = []
	grid.append_array(trues)
	grid.append_array(foils)
	_shuffle(grid)
	return grid

# ============================================================== vote
func _enter_vote() -> void:
	phase = Phase.VOTE
	_t = 0.0
	board.show_rehearsal(false)
	for a in actors:
		a.set_focus(false)
		a.set_lit(1.4)
		a.hide_status()
	var entries: Array = []
	for i in players.size():
		entries.append({"index": players[i].index, "name": players[i].name, "color": players[i].color})
	board.show_vote(entries)
	board.show_vote_panel(true)
	votes.clear()
	_vote_locked.clear()
	_vote_target.clear()
	_vote_settled = false
	_vote_settle_t = 0.0
	for i in players.size():
		var vi: int = players[i].index
		_vote_locked[vi] = false
		_vote_cursor[vi] = _first_target_seat(i)
		_vote_bot_t[vi] = 0.0
		_vote_bot_delay[vi] = (0.2 + 0.12 * i) if _tally else (0.9 + 0.5 * i + bots.read_beat(i))
		# each bot decides ONCE per round (decide_vote consumes RNG)
		if players[i].is_bot:
			_vote_target[vi] = _seat_of(bots.decide_vote(i, self))
		board.set_vote_cursor(vi, _vote_cursor[vi])
	_say("Name the pretender. Do try to be right.")
	if not _tally:
		_flash_banner("NAME THE PRETENDER", Color(0.88, 0.26, 0.28), 1.4)

func _first_target_seat(voter_seat: int) -> int:
	for i in players.size():
		if i != voter_seat:
			return i
	return 0

func _tick_vote(delta: float) -> void:
	_t += delta
	var remaining := (2.0 if _tally else 10.0) - _t
	timer_label.text = "%02d" % maxi(0, int(ceil(remaining)))
	for i in players.size():
		var pl: Dictionary = players[i]
		var vi: int = pl.index
		if _vote_locked.get(vi, false):
			continue
		if pl.is_bot:
			_vote_bot_t[vi] = float(_vote_bot_t[vi]) + delta
			# ease the cursor toward the round's precomputed target, then lock
			var goal_seat: int = int(_vote_target.get(vi, _first_target_seat(i)))
			if _vote_cursor[vi] != goal_seat:
				_step_vote_cursor(i, goal_seat)
			elif float(_vote_bot_t[vi]) >= float(_vote_bot_delay[vi]):
				_lock_vote(i, goal_seat)
		else:
			var nav := _nav_dir(vi)
			if nav != 0:
				_step_vote_cursor(i, _next_target_seat(i, int(_vote_cursor[vi]), nav))
			if PlayerInput.just_pressed(vi, "a"):
				_lock_vote(i, int(_vote_cursor[vi]))
	if remaining <= 0.0:
		# time called: auto-lock the undecided on their precomputed / first read
		for i in players.size():
			var vi2: int = players[i].index
			if not _vote_locked.get(vi2, false):
				_lock_vote(i, int(_vote_target.get(vi2, _first_target_seat(i))))
	if _all_locked():
		if not _vote_settled:
			_vote_settled = true
			_vote_settle_t = 0.0
			timer_label.text = ""
			_maybe_snap("vote")   # every accusation is in; the board is complete
			_say("The house has spoken. Let us see who was lying.")
		else:
			_vote_settle_t += delta
			if _vote_settle_t >= (0.2 if _tally else 1.0):
				_enter_resolve()

func _step_vote_cursor(voter_seat: int, target_seat: int) -> void:
	var vi: int = players[voter_seat].index
	_vote_cursor[vi] = target_seat
	board.set_vote_cursor(vi, target_seat)

func _next_target_seat(voter_seat: int, cur: int, dir: int) -> int:
	var n := players.size()
	var t := cur
	for _k in n:
		t = wrapi(t + dir, 0, n)
		if t != voter_seat:
			return t
	return cur

func _lock_vote(voter_seat: int, target_seat: int) -> void:
	var pl: Dictionary = players[voter_seat]
	var vi: int = pl.index
	if _vote_locked.get(vi, false):
		return
	if target_seat == voter_seat:
		target_seat = _first_target_seat(voter_seat)
	_vote_locked[vi] = true
	votes[vi] = players[target_seat].index
	board.lock_vote(vi, pl.name, pl.color, target_seat)
	print("US_ACCUSE %s -> %s" % [pl.name, players[target_seat].name])

func _all_locked() -> bool:
	for i in players.size():
		if not _vote_locked.get(players[i].index, false):
			return false
	return true

# ============================================================== resolve
func _enter_resolve() -> void:
	phase = Phase.RESOLVE
	_t = 0.0
	board.show_vote_panel(false)
	timer_label.text = ""
	var u: int = round_understudy
	var u_seat: int = _seat_of(u)

	# tally accusations
	var accus: Dictionary = {}
	for i in players.size():
		accus[players[i].index] = 0
	for voter in votes:
		var tgt: int = int(votes[voter])
		accus[tgt] = int(accus[tgt]) + 1

	# cast correctness
	var correct_cast: Array = []
	var misfire_cast: Array = []
	for i in players.size():
		var ci: int = players[i].index
		if ci == u:
			continue
		if int(votes.get(ci, -1)) == u:
			correct_cast.append(ci)
		else:
			misfire_cast.append(ci)

	# --- DISTRIBUTED SCORING (rehearsal blend already added per-cue) ---
	for ci in correct_cast:
		_round_pts[ci] = int(_round_pts[ci]) + UNMASK_PTS
		players[_seat_of(ci)].unmask_hits += 1
		_currency.append({"type": "royalty", "player": ci, "amount": 1,
			"reason": "saw through the understudy"})

	var caught: bool = correct_cast.size() >= 2
	var frame_target: int = int(votes.get(u, -1))
	var top_count: int = 0
	for k in accus:
		top_count = maxi(top_count, int(accus[k]))
	if caught:
		players[u_seat].und_caught += 1
		_currency.append({"type": "grudge", "player": u, "amount": 1,
			"reason": "unmasked before the house"})
		_highlights.append("%s was unmasked — the cast saw through the act" % player_name(u))
	else:
		_round_pts[u] = int(_round_pts[u]) + SURVIVAL_PTS
		_currency.append({"type": "royalty", "player": u, "amount": 2,
			"reason": "walked off the stage unmasked"})
		_highlights.append("%s fooled the theater and walked free" % player_name(u))
		# frame bonus: the mob actually leaned (>=2) on the actor the understudy
		# pointed at — a scattered split is escaping, not framing
		if frame_target >= 0 and frame_target != u and top_count >= 2 \
				and int(accus.get(frame_target, 0)) == top_count:
			_round_pts[u] = int(_round_pts[u]) + FRAME_PTS
			_highlights.append("%s took the fall for %s" % [player_name(frame_target), player_name(u)])
		if frame_target >= 0 and frame_target != u and int(accus.get(frame_target, 0)) >= 2:
			_currency.append({"type": "grudge", "player": frame_target, "amount": 1,
				"reason": "took the fall for the understudy"})

	# --- old majority verdict, for the record (NOT used for scoring) ---
	var top_players: Array = []
	for k in accus:
		if int(accus[k]) == top_count and top_count > 0:
			top_players.append(k)
	var majority_needed: int = players.size() / 2 + 1
	var majority: bool = top_count >= majority_needed and top_players.size() == 1
	var maj_str := "STALEMATE"
	var maj_target := -1
	if majority:
		maj_target = int(top_players[0])
		maj_str = "CONVICT %s" % player_name(maj_target)

	# round winner (distributed)
	var winner: int = _round_winner()
	print("US_VOTE act=%d understudy=%s votes=%s accus=%s" % [round_index + 1,
		player_name(u), _votes_str(), _accus_str(accus)])
	print("US_MAJORITY act=%d verdict=%s (top=%d needed=%d)" % [round_index + 1,
		maj_str, top_count, majority_needed])
	print("US_DISTRIBUTED act=%d pts=%s winner=%s caught=%s" % [round_index + 1,
		_pts_str(), player_name(winner), str(caught)])

	# apply round points to totals
	for i in players.size():
		players[i].total += int(_round_pts[players[i].index])

	# --- theatre of the reveal ---
	for i in players.size():
		if players[i].index == u:
			actors[i].set_focus(true)
			actors[i].face_front()
			actors[i].play_flinch() if caught else actors[i].play_cheer()
			actors[i].show_status("THE UNDERSTUDY", Color(0.95, 0.3, 0.3))
		else:
			actors[i].dim_out()
	if not _tally:
		Sfx.play("grudge", -1.0)
	_reveal_lines(u, caught, majority, maj_target, correct_cast, misfire_cast)
	_rebuild_scoreboard()

	# executor judgment (Saki register)
	if caught:
		_say("The understudy was %s. The cast, on the whole, was not fooled." % player_name(u))
	else:
		_say("The understudy was %s. The house suspected the wrong throat, and %s will profit." % [player_name(u), player_name(u)])

	_re_events.clear()
	_re_t = 0.0
	_re_done = (0.6 if _tally else 4.8)

func _reveal_lines(u: int, caught: bool, majority: bool, maj_target: int, correct_cast: Array, _misfire: Array) -> void:
	var lines: Array = []
	if caught:
		board.show_verdict("UNMASKED — %s WAS THE UNDERSTUDY" % player_name(u), Color(1.0, 0.4, 0.35))
	else:
		board.show_verdict("THEY WALK — %s WAS THE UNDERSTUDY" % player_name(u), players[_seat_of(u)].color)
	var d := 0.4
	if not majority:
		lines.append({"text": "A SPLIT HOUSE — NO MAJORITY TO CONVICT", "color": Color(0.9, 0.55, 0.4), "delay": d})
		d += 0.7
		lines.append({"text": "THE LEDGER SETTLES IT ANYWAY", "color": Color(1.0, 0.83, 0.36), "delay": d})
		d += 0.7
	else:
		lines.append({"text": "THE HOUSE CONVICTS %s" % player_name(maj_target), "color": Color(0.9, 0.55, 0.4), "delay": d})
		d += 0.7
	for ci in correct_cast:
		lines.append({"text": "%s +%d  UNMASKING" % [player_name(ci), UNMASK_PTS], "color": players[_seat_of(ci)].color, "delay": d})
		d += 0.5
	var uc: Color = players[_seat_of(u)].color
	if not caught:
		lines.append({"text": "%s +%d  SURVIVED THE STAGE" % [player_name(u), int(_round_pts[u])], "color": uc, "delay": d})
	board.show_res_lines(lines)

func _round_winner() -> int:
	var best := 0
	var best_p := -1
	for i in players.size():
		var pts: int = int(_round_pts[players[i].index])
		if pts > best_p:
			best_p = pts
			best = players[i].index
	return best

func _tick_resolve(delta: float) -> void:
	_re_t += delta
	if _snaps and _re_t >= 1.7:
		_maybe_snap("judgment")   # verdict + resolution lines have appeared
		if _snapped.has("judgment") and _re_t >= 3.2:
			get_tree().quit()
	if _re_t >= _re_done:
		round_index += 1
		if round_index >= rounds_total:
			_finish_match()
		else:
			board.hide_resolution()
			_start_round()

# ============================================================== round end / match
func _tick_round_end(_delta: float) -> void:
	pass

func _finish_match() -> void:
	phase = Phase.MATCH_END
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if players[a].total != players[b].total:
			return players[a].total > players[b].total
		return a < b)
	var placements: Array = []
	for s in order:
		placements.append(players[s].index)
	var points: Dictionary = {}
	for i in players.size():
		points[players[i].index] = players[i].total

	var monuments: Array = []
	for i in players.size():
		if players[i].und_rounds > 0 and players[i].und_caught == 0:
			monuments.append({"player": players[i].index, "kind": "phantom",
				"label": "%s, Never Unmasked" % players[i].name})
		if players[i].cast_rounds > 0 and players[i].unmask_hits >= players[i].cast_rounds:
			monuments.append({"player": players[i].index, "kind": "inquisitor",
				"label": "%s, the Unerring Eye" % players[i].name})

	var champ: int = players[order[0]].index
	var results: Dictionary = {
		"placements": placements,
		"points": points,
		"currency_events": _currency.duplicate(),
		"highlights": _dedup(_highlights).slice(0, 3),
		"monuments": monuments,
	}
	print("US_MATCH_OVER champ=%s pts=%d" % [player_name(champ), players[order[0]].total])
	print("US_RESULTS ", JSON.stringify(results))
	if _tally:
		_print_tally(champ)
		get_tree().quit()
		return
	board.hide_all()
	_set_base_ui(true)
	for i in players.size():
		if players[i].index == champ:
			actors[i].set_focus(true)
			actors[i].set_lit(USActor.SPOT_FOCUS)
			actors[i].play_cheer()
			actors[i].show_status("★ TOP BILLING", Color(1.0, 0.85, 0.4))
			_spawn_confetti(actors[i].global_position + Vector3(0, 2.0, 0), players[i].color)
		else:
			actors[i].dim_out()
	_flash_banner("%s TAKES TOP BILLING" % player_name(champ), players[_seat_of(champ)].color, 6.0)
	_say("The bills are printed. %s has the marquee. The rest of you may see yourselves out." % player_name(champ))
	Sfx.play("match_win")
	report_finished(results)

func _print_tally(champ: int) -> void:
	print("======== THE UNDERSTUDY TALLY ========")
	var bits: Array = []
	for i in players.size():
		bits.append("%s=%d" % [players[i].name, players[i].total])
	print("US_TALLY seed=%d rounds=%d totals: %s champ=%s" % [rng.seed, rounds_total,
		" ".join(bits), player_name(champ)])
	print("======================================")

# ============================================================== content queries (bots)
func word_in_play(word: String, key: String) -> bool:
	return PLAYS.has(key) and word in PLAYS[key].words

func word_play_count(word: String) -> int:
	var c := 0
	for key in PLAYS:
		if word in PLAYS[key].words:
			c += 1
	return c

func play_keys() -> Array:
	return PLAYS.keys()

func is_cast(pindex: int) -> bool:
	return pindex != round_understudy

func player_name(pindex: int) -> String:
	for i in players.size():
		if players[i].index == pindex:
			return players[i].name
	return "???"

# ============================================================== helpers
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _ordinal(n: int) -> String:
	match n:
		1: return "First"
		2: return "Second"
		3: return "Third"
		4: return "Fourth"
		5: return "Fifth"
		_: return "%dth" % n

func _nav_dir(pindex: int) -> int:
	var x := PlayerInput.get_move(pindex).x
	var s := 0
	if x > 0.5:
		s = 1
	elif x < -0.5:
		s = -1
	var prev: int = _nav_prev.get(pindex, 0)
	_nav_prev[pindex] = s
	if s != 0 and s != prev:
		return s
	return 0

func _votes_str() -> String:
	var parts: Array = []
	for voter in votes:
		parts.append("%s->%s" % [player_name(voter), player_name(int(votes[voter]))])
	return "{" + ", ".join(parts) + "}"

func _accus_str(accus: Dictionary) -> String:
	var parts: Array = []
	for k in accus:
		parts.append("%s:%d" % [player_name(k), int(accus[k])])
	return "{" + ", ".join(parts) + "}"

func _pts_str() -> String:
	var parts: Array = []
	for i in players.size():
		parts.append("%s=%d" % [players[i].name, int(_round_pts[players[i].index])])
	return "{" + ", ".join(parts) + "}"

func _dedup(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		if not out.has(x):
			out.append(x)
	return out

func _say(text: String) -> void:
	executor_line.text = "THE EXECUTOR:  " + text
	executor_line.visible = true

func _set_base_ui(v: bool) -> void:
	round_label.visible = v
	timer_label.visible = v
	hint_label.visible = v
	executor_line.visible = v
	$UI/ScorePanel.visible = v

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
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(p.index, 24)
		badge.color = p.color
		if p.index == round_understudy and phase >= Phase.RESOLVE:
			badge.dim = 0.6
		hb.add_child(badge)
		var row := Label.new()
		var tag := ""
		if p.index == round_understudy and phase >= Phase.RESOLVE:
			tag = "  (u/s)"
		row.text = "%s  %d%s" % [p.name, p.total, tag]
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", p.color)
		row.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.1))
		row.add_theme_constant_override("outline_size", 5)
		hb.add_child(row)
		score_rows.add_child(hb)

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
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func():
		if my == _banner_token:
			banner.visible = false)

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
	tw.tween_callback(func():
		if my == _sub_token:
			sub_banner.visible = false)

func _spawn_confetti(pos: Vector3, color: Color) -> void:
	if _tally:
		return
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 20
		p.lifetime = 1.4
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

# ============================================================== snapshots (verify)
func _maybe_snap(tag: String) -> void:
	if not _snaps or _snapped.has(tag):
		return
	_snapped[tag] = true
	_do_snap(tag)

func _do_snap(tag: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://docs/verify/shots/understudy_%s.png" % tag
	img.save_png(path)
	print("US_SNAP ", path)

# ============================================================== verify hooks
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.REHEARSAL or phase == Phase.VOTE
