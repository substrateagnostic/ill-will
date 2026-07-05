extends Minigame
## THE SÉANCE — the anthology's first social-deduction game, staged at the
## estate's Theater. Four sitters share ONE planchette and try to make the
## spirit spell a secret word before the table's focus dies. One of them was
## paid, in grudge, to make the séance fail — and not get caught. Insider's
## co-op-task-with-a-hidden-steerer structure, inverted to sabotage, per
## docs/design/06-social-deduction-research.md pitch #1.
##
## ROUND FLOW (~4:00, per the research doc):
##   CAST (~22s)   eyes-closed casting, Executor liturgy. Each seat gets an
##                 identical-length private flash: three read FAITHFUL, one
##                 reads the word and the contract. Equal beats = timing
##                 leaks nothing (doc method #2 dressed over method #4 —
##                 with no dealt cards and no guaranteed rumble, identity
##                 must touch the screen once per seat; see VERIFY doc).
##   SÉANCE (90s)  the co-op task. Stick = shared pull on the planchette
##                 (forces sum; individual hands are NOT visualized — Ouija
##                 deniability). A = chant on the candle pulse (on-beat
##                 feeds the focus meter, off-beat drains it; every tap
##                 flares YOUR candle, so rhythm is watchable per suspect
##                 but not for all four at once). B = anonymous surge.
##                 Letters commit by dwell. Wrong letters wound the focus.
##                 Word spelled = table wins; focus dead / clock out =
##                 spirits win (Charlatan wins).
##   TALK (30s)    open accusations, out loud. Couch does the work.
##   VOTE (15s)    stick = swing your chip across portraits, A = lock.
##                 Distributed scoring — every correct finger pays royalty
##                 individually; no majority is ever required to score.
##   REVEAL (~9s)  the Executor unmasks the Charlatan REGARDLESS of votes
##                 (pillar 1: the Theater allows hidden info because it is
##                 always unmasked publicly and settled on the ladder).
##
## ECONOMY (grudge in, royalty out, per the doc):
##   fee: Charlatan is paid 2 grudge up front at the cast.
##   séance succeeds: each honest sitter earns royalty (they profited
##     from resisting).
##   séance fails + Charlatan uncaught (<2 correct fingers): Charlatan
##     converts the fee into a fat royalty payout.
##   caught (2+ correct fingers): Charlatan eats grudge; and every correct
##     finger earns royalty (paid even when the catch threshold fails —
##     distributed scoring, doc section d preamble).
##   kill_events: a successful unmasking reports ONE kill — the first
##     correct accuser to lock is credited with the Charlatan's unmasking
##     (cause "seance"). No unmasking, no kill; nothing is fabricated.
##
## Anthology module: root of minigames/seance/seance.tscn, extends Minigame.
## Self-starts standalone 0.5s after _ready if begin() wasn't called.
## Per-seat bots (fleet convention): roster[i].bot, else
## PlayerInput.standalone_bot_default(i) on self-start. Deterministic per
## rng_seed: planchette is kinematic (no physics bodies), all logic rolls
## come from seeded streams, visual-only randomness uses a separate rng.
##
## CLI user args (after `--`):
##   --seancebots        all players are seeded self-play bots
##   --seed=N            rng seed for standalone start (default 1)
##   --players=N         standalone roster size 2..4
##   --seancetally       headless evidence mode: full bot match fast-
##                       forwarded (dt pinned 1/60), prints SEANCE_TALLY +
##                       results JSON and quits
##   --seancesabo=off    tuning control: the charlatan seat exists but its
##                       bot plays honest (baseline win-rate evidence)
##   --shots=N,... / --quitafter=N   VerifyCapture harness (global); the
##                       game also fires event snaps: cast/board/accuse/
##                       reveal/settle

enum Phase { WAITING, INTRO, CAST, SEANCE, TALK, VOTE, REVEAL, DONE }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

# --- the sitting (co-op task) tuning -----------------------------------
const BEAT_PERIOD := 0.85          # the candle pulse (spirit's heartbeat)
const TAP_WINDOW := 0.16           # |offset from beat| that counts on-beat
const ON_TAP := 0.45               # focus per on-beat chant
const OFF_TAP := 1.1               # focus lost per off-beat chant
const PASSIVE_DECAY := 1.5         # focus per second, always
const WRONG_HIT := 13.0            # focus lost when the spirit recoils
const CORRECT_BONUS := 5.0         # focus gained on a true letter
const DWELL_TIME := 1.15           # seconds resting on a letter to commit
const LETTER_R := 0.24             # capture radius around a letter
const SEANCE_TIME := 90.0
const TALK_TIME := 30.0            # 8s when the whole table is bots
const VOTE_TIME := 15.0
const ACCEL_PER := 5.2             # per-player planchette pull
const SURGE_IMPULSE := 1.9
const SURGE_CD := 2.5
const SAB_ALIBI_WINDOW := 6.0      # saboteur bot plays honest this long
const FEE_GRUDGE := 2
const CATCH_ROYALTY := 1
const HOLD_ROYALTY := 1
const ESCAPE_ROYALTY := 2
const CAUGHT_GRUDGE := 2

var phase: int = Phase.WAITING
var game_time := 0.0
var rng := RandomNumberGenerator.new()
var _fx_rng := RandomNumberGenerator.new()   # visual-only, never gates logic
var bots: SeanceBots

var roster: Array = []
var players: Array = []        # {index,name,color,char_path,device,is_bot}
var figures: Array = []        # index -> SeanceFigure
var charlatan := -1
var word := ""
var clue := ""
var word_letters: Dictionary = {}    # letter -> true (unique letters of word)

# board
var planchette: SeancePlanchette
var _letters: Dictionary = {}        # "A" -> {pos, label, mat_state:int 0/1/2}
var _letter_order: Array = []
var _dwell_ring: MeshInstance3D
var _spirit_flame_mat: StandardMaterial3D
var _spirit_light: OmniLight3D
var _table_flames: Array = []        # MeshInstance3D tealight flames
var _reveal_spot: SpotLight3D

# the sitting state
var seance_elapsed := 0.0
var focus := 90.0                    # room to climb, room to bleed
var dwell_letter := ""
var dwell_t := 0.0
var _dwell_cd := 0.0
var _last_beat := -1
var _recent_travel := Vector3.ZERO
var _contrib: Array = []             # per player Vector3, exp-decayed pull
var _surge_cd_p: Array = []
var _last_surge_t: Array = []
var _last_tap_beat: Array = []
var _taps_on: Array = []
var _taps_off: Array = []
var _commits_right := 0
var _commits_wrong := 0
var _seance_success := false
var _seance_over_cause := ""
var _low_focus_warned := false

# deduction state
var suspicion: Dictionary = {}       # index -> float (bots' evidence read)
var _talk_len := TALK_TIME
var vote_t := 0.0
var _vote_cursor: Array = []
var _vote_locked: Array = []
var vote_target: Array = []
var _lock_order: Array = []
var _nav_prev: Dictionary = {}
var _caught := false
var _correct_votes := 0

# meta / results
var _currency: Array = []
var _kill_events: Array = []
var _highlights: Array = []
var _practice := false
var _reported := false

# sequencer (CAST + REVEAL theatrics)
var _seq: Array = []
var _seq_t := 0.0
var _intro_t := 0.0

# modes
var _started := false
var _all_bots := false
var _tally := false
var _no_sabo := false
var _cli_players := 4
var _cli_seed := 1
var _snap_board_done := false
var _snap_accuse_done := false

# fx
var _shake := 0.0
var _time_token := 0
var _banner_token := 0
var _sub_token := 0
var _ui: SeanceUI

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var banner: Label = $UI/Banner
@onready var sub_banner: Label = $UI/SubBanner
@onready var phase_label: Label = $UI/PhaseLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var blanks_label: Label = $UI/BlanksLabel
@onready var clue_label: Label = $UI/ClueLabel
@onready var executor_label: Label = $UI/ExecutorLabel
@onready var focus_fill: ColorRect = $UI/FocusBG/FocusFill
@onready var spawn_root: Node3D = $SpawnRoot

func _ready() -> void:
	_parse_args()
	_fx_rng.seed = 0xF7A57 + _cli_seed
	_build_world()
	banner.visible = false
	sub_banner.visible = false
	blanks_label.visible = false
	clue_label.visible = false
	executor_label.text = ""
	_set_focus_ui(1.0)
	_ui = SeanceUI.new()
	add_child(_ui)
	await get_tree().create_timer(0.5).timeout
	if not _started:
		begin(_default_config())

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--seancebots":
			_all_bots = true
		elif arg == "--seancetally":
			_tally = true
			_all_bots = true
		elif arg == "--seancesabo=off":
			_no_sabo = true
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
			"char_scene": CHAR_FALLBACKS[i % CHAR_FALLBACKS.size()],
			"device": dev,
			"bot": _all_bots or PlayerInput.standalone_bot_default(i) or dev == -3 or dev == -99,
		})
	return {"roster": r, "rounds": 1, "rng_seed": _cli_seed, "practice": false}

func begin(config: Dictionary) -> void:
	if _started:
		return
	_started = true
	rng.seed = int(config.get("rng_seed", 1))
	_practice = bool(config.get("practice", false))
	roster = config.get("roster", [])
	players.clear()
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var char_path := str(pl.get("char_scene", ""))
		if char_path == "" or not ResourceLoader.exists(char_path):
			char_path = CHAR_FALLBACKS[i % CHAR_FALLBACKS.size()]
		var idx := int(pl.get("index", i))
		var is_bot: bool = _all_bots or bool(pl.get("bot", PlayerInput.is_bot(idx)))
		players.append({
			"index": idx,
			"name": str(pl.get("name", "P%d" % i)),
			"color": pl.get("color", Color.WHITE),
			"char_path": char_path,
			"device": int(pl.get("device", -99)),
			"is_bot": is_bot,
		})
	# one seeded draw each, fixed order: word, then the paid seat
	var pickd: Dictionary = SeanceWords.pick(rng)
	word = str(pickd.word)
	clue = str(pickd.clue)
	for ch in word:
		word_letters[ch] = true
	charlatan = rng.randi_range(0, players.size() - 1)
	bots = SeanceBots.new()
	bots.setup(int(config.get("rng_seed", 1)) ^ 0x5EA0CE,
		players.size(), -1 if _no_sabo else charlatan)
	for i in players.size():
		suspicion[i] = 0.0
		_contrib.append(Vector3.ZERO)
		_surge_cd_p.append(0.0)
		_last_surge_t.append(-99.0)
		_last_tap_beat.append(-1)
		_taps_on.append(0)
		_taps_off.append(0)
		_vote_cursor.append(-1)
		_vote_locked.append(false)
		vote_target.append(-1)
	_spawn_figures()
	_ui.build_vote_panel(players)
	_talk_len = TALK_TIME
	if _all_bots or players.all(func(p): return p.is_bot):
		_talk_len = 8.0
	print("SEANCE_BEGIN players=%d seed=%d practice=%s bots=%s" % [players.size(),
		rng.seed, str(_practice), str(players.map(func(p): return p.is_bot))])
	print("SEANCE_WORD word=%s clue=\"%s\"" % [word, clue])
	print("SEANCE_CAST charlatan=%s idx=%d fee=%d grudge" % [players[charlatan].name, charlatan, FEE_GRUDGE])
	if not _practice:
		_currency.append({"type": "grudge", "player": charlatan, "amount": FEE_GRUDGE,
			"reason": "took the spirits' coin to bury the seance"})
	phase = Phase.INTRO
	_intro_t = 0.0
	phase_label.text = "THE SEANCE"
	_flash_banner("THE SEANCE", Color(0.8, 0.75, 1.0), 2.4)
	_flash_sub("the Theater presents", Color(0.7, 0.62, 0.78), 2.4)
	_say("Take your seats. The dead dislike waiting.")

# ================================================================ world
func _build_world() -> void:
	var we: WorldEnvironment = $WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.008, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.38, 0.32)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.07, 0.12)
	env.fog_density = 0.012
	we.environment = env

	cam.global_position = Vector3(0, 7.35, 8.9)
	cam.look_at(Vector3(0, 0.72, -0.4), Vector3.UP)
	cam.fov = 42.0

	# warm house key: a soft spot over the table (the candle pool)
	var spot := SpotLight3D.new()
	spot.name = "TableSpot"
	spot.light_color = Color(1.0, 0.82, 0.6)
	spot.light_energy = 1.25
	spot.spot_range = 11.0
	spot.spot_angle = 36.0
	spot.position = Vector3(0, 7.5, 1.5)
	spot.rotation_degrees = Vector3(-78, 0, 0)
	spot.shadow_enabled = true
	add_child(spot)
	# faint cool fill so the dark isn't mud
	var moon := DirectionalLight3D.new()
	moon.name = "MoonFill"
	moon.rotation_degrees = Vector3(-42, -155, 0)
	moon.light_energy = 0.16
	moon.light_color = Color(0.45, 0.52, 0.85)
	add_child(moon)
	# reveal spotlight, parked dark until the verdict
	_reveal_spot = SpotLight3D.new()
	_reveal_spot.light_color = Color(1.0, 0.95, 0.85)
	_reveal_spot.light_energy = 0.0
	_reveal_spot.spot_range = 16.0
	_reveal_spot.spot_angle = 16.0
	_reveal_spot.position = Vector3(0, 8.5, 4.0)
	add_child(_reveal_spot)

	_build_stage()
	_build_table()
	_build_board()

func _build_stage() -> void:
	var floor_m := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(22, 0.3, 20)
	floor_m.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.21, 0.14, 0.1)
	fmat.roughness = 0.85
	floor_m.material_override = fmat
	floor_m.position.y = -0.15
	$Arena.add_child(floor_m)
	# planks read: thin darker strips
	var strip_mat := StandardMaterial3D.new()
	strip_mat.albedo_color = Color(0.16, 0.1, 0.075)
	strip_mat.roughness = 0.9
	for i in 9:
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.06, 0.02, 20)
		strip.mesh = sm
		strip.material_override = strip_mat
		strip.position = Vector3(-8.8 + i * 2.2, 0.008, 0)
		$Arena.add_child(strip)
	# back curtain — red velvet wall with sculpted folds
	var curt_mat := StandardMaterial3D.new()
	curt_mat.albedo_color = Color(0.3, 0.07, 0.1)
	curt_mat.roughness = 1.0
	for i in 15:
		var fold := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.62
		cm.height = 7.5
		fold.mesh = cm
		fold.material_override = curt_mat
		fold.position = Vector3(-8.4 + i * 1.2, 3.75, -7.6 + 0.18 * (i % 2))
		$Arena.add_child(fold)
	# side curtains, angled in
	for side in [-1.0, 1.0]:
		for i in 4:
			var fold2 := MeshInstance3D.new()
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.5
			cm2.bottom_radius = 0.58
			cm2.height = 7.5
			fold2.mesh = cm2
			fold2.material_override = curt_mat
			fold2.position = Vector3(side * (7.4 + i * 0.35), 3.75, -6.0 + i * 1.35)
			$Arena.add_child(fold2)
	# gilt proscenium lip across the top of the backdrop
	var lip := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(19, 0.5, 0.5)
	lip.mesh = lm
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.65, 0.5, 0.22)
	gold_mat.metallic = 0.7
	gold_mat.roughness = 0.4
	lip.material_override = gold_mat
	lip.position = Vector3(0, 7.4, -7.3)
	$Arena.add_child(lip)

func _build_table() -> void:
	# round table draped to the floor in dark cloth
	var skirt := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 2.5
	km.bottom_radius = 2.62
	km.height = 0.86
	skirt.mesh = km
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.15, 0.09, 0.16)
	cloth.roughness = 0.95
	skirt.material_override = cloth
	skirt.position.y = 0.43
	$Arena.add_child(skirt)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 2.56
	tm.bottom_radius = 2.56
	tm.height = 0.05
	top.mesh = tm
	var topmat := StandardMaterial3D.new()
	topmat.albedo_color = Color(0.2, 0.12, 0.2)
	topmat.roughness = 0.8
	top.material_override = topmat
	top.position.y = 0.885
	$Arena.add_child(top)
	# tealights ringing the board — the focus meter, diegetic: they snuff
	# as the table's focus dies
	var wax_mat := StandardMaterial3D.new()
	wax_mat.albedo_color = Color(0.9, 0.86, 0.75)
	wax_mat.roughness = 0.7
	for i in 10:
		var a := TAU * i / 10.0 + 0.31
		var pos := Vector3(cos(a) * 2.18, 0.91, sin(a) * 1.46)
		var cup := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.06
		cm.height = 0.07
		cup.mesh = cm
		cup.material_override = wax_mat
		cup.position = pos
		$Arena.add_child(cup)
		var flame := MeshInstance3D.new()
		var flm := SphereMesh.new()
		flm.radius = 0.035
		flm.height = 0.1
		flame.mesh = flm
		var flmat := StandardMaterial3D.new()
		flmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flmat.albedo_color = Color(1.0, 0.8, 0.42, 0.92)
		flmat.emission_enabled = true
		flmat.emission = Color(1.0, 0.66, 0.28)
		flmat.emission_energy_multiplier = 1.5
		flame.material_override = flmat
		flame.position = pos + Vector3(0, 0.08, 0)
		$Arena.add_child(flame)
		_table_flames.append(flame)
	# the spirit flame: a tall candle at the head of the table whose pulse
	# is the chant metronome
	var pillar := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.11
	pm.height = 0.55
	pillar.mesh = pm
	var wax2 := StandardMaterial3D.new()
	wax2.albedo_color = Color(0.85, 0.78, 0.62)
	wax2.roughness = 0.6
	pillar.material_override = wax2
	pillar.position = Vector3(0, 1.16, -1.95)
	$Arena.add_child(pillar)
	var sflame := MeshInstance3D.new()
	var sfm := SphereMesh.new()
	sfm.radius = 0.075
	sfm.height = 0.2
	sflame.mesh = sfm
	_spirit_flame_mat = StandardMaterial3D.new()
	_spirit_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spirit_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spirit_flame_mat.albedo_color = Color(1.0, 0.85, 0.5, 0.95)
	_spirit_flame_mat.emission_enabled = true
	_spirit_flame_mat.emission = Color(1.0, 0.72, 0.32)
	_spirit_flame_mat.emission_energy_multiplier = 2.0
	sflame.material_override = _spirit_flame_mat
	sflame.position = Vector3(0, 1.52, -1.95)
	$Arena.add_child(sflame)
	_spirit_light = OmniLight3D.new()
	_spirit_light.light_color = Color(1.0, 0.72, 0.36)
	_spirit_light.light_energy = 1.6
	_spirit_light.omni_range = 7.5
	_spirit_light.position = Vector3(0, 1.9, -1.7)
	add_child(_spirit_light)

func _build_board() -> void:
	var board := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 1.0
	bm.bottom_radius = 1.0
	bm.height = 0.05
	board.mesh = bm
	board.scale = Vector3(1.88, 1.0, 1.28)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.4, 0.28, 0.16)
	bmat.roughness = 0.55
	board.material_override = bmat
	board.position = Vector3(0, 0.935, 0)
	$Arena.add_child(board)
	# border ring paint
	var border := MeshInstance3D.new()
	var brm := TorusMesh.new()
	brm.inner_radius = 0.955
	brm.outer_radius = 1.0
	border.mesh = brm
	border.scale = Vector3(1.88, 1.0, 1.28)
	var brmat := StandardMaterial3D.new()
	brmat.albedo_color = Color(0.62, 0.47, 0.2)
	brmat.metallic = 0.4
	brmat.roughness = 0.5
	border.material_override = brmat
	border.position = Vector3(0, 0.965, 0)
	$Arena.add_child(border)
	# YES / NO corner decor (the spirit's vocabulary is fuller tonight)
	for d in [["YES", -1.35], ["NO", 1.35]]:
		var lab := Label3D.new()
		lab.text = str(d[0])
		lab.font_size = 40
		lab.pixel_size = 0.004
		lab.modulate = Color(0.28, 0.18, 0.1)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.position = Vector3(float(d[1]), 0.966, -0.98)
		lab.no_depth_test = false
		$Arena.add_child(lab)
	# letters: three bowed rows, A-I / J-R / S-Z
	var board_y := 0.966
	var rows: Array = [
		{"letters": "ABCDEFGHI", "z": -0.52},
		{"letters": "JKLMNOPQR", "z": 0.0},
		{"letters": "STUVWXYZ", "z": 0.52},
	]
	for row in rows:
		var s: String = row.letters
		var n := s.length()
		for i in n:
			var l := s[i]
			var x := (float(i) - float(n - 1) * 0.5) * 0.36
			var z: float = row.z + 0.06 * cos(x * 1.1) - 0.03
			var lab := Label3D.new()
			lab.text = l
			lab.font_size = 62
			lab.pixel_size = 0.0046
			lab.modulate = Color(0.92, 0.84, 0.64)
			lab.outline_size = 6
			lab.outline_modulate = Color(0.16, 0.1, 0.05)
			lab.rotation_degrees = Vector3(-90, 0, 0)
			lab.position = Vector3(x, board_y, z)
			$Arena.add_child(lab)
			_letters[l] = {"pos": Vector3(x, board_y, z), "label": lab, "state": 0}
			_letter_order.append(l)
	# dwell ring (channel telegraph on the hovered letter)
	_dwell_ring = MeshInstance3D.new()
	var drm := TorusMesh.new()
	drm.inner_radius = 0.14
	drm.outer_radius = 0.18
	_dwell_ring.mesh = drm
	var drmat := StandardMaterial3D.new()
	drmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drmat.albedo_color = Color(0.65, 0.85, 1.0, 0.0)
	drmat.emission_enabled = true
	drmat.emission = Color(0.6, 0.85, 1.0)
	drmat.emission_energy_multiplier = 1.2
	_dwell_ring.material_override = drmat
	_dwell_ring.visible = false
	$Arena.add_child(_dwell_ring)
	# the planchette
	planchette = SeancePlanchette.new()
	planchette.build()
	planchette.board_center = Vector3(0, 0.985, 0)
	planchette.half_x = 1.75
	planchette.half_z = 1.16
	planchette.position = Vector3(0, 0.985, 0.8)
	spawn_root.add_child(planchette)

func _spawn_figures() -> void:
	var seat_az: Array = [0.0, 78.0, -78.0, 152.0]   # degrees; 0 = north (far)
	var r := 3.35
	for i in players.size():
		var az: float = deg_to_rad(float(seat_az[i % seat_az.size()]))
		var pos := Vector3(sin(az) * r, 0, -cos(az) * r)
		var fig := SeanceFigure.new()
		fig.name = "Figure%d" % i
		spawn_root.add_child(fig)
		var scene: PackedScene = load(players[i].char_path)
		fig.setup(i, players[i].color, players[i].name, scene)
		fig.position = pos
		var dir := -pos.normalized()
		fig.rotation.y = atan2(dir.x, dir.z)
		figures.append(fig)

# ================================================================ tick
func _physics_process(delta: float) -> void:
	game_time += delta
	if _shake > 0.001:
		cam.h_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = _fx_rng.randf_range(-1, 1) * _shake * 0.25
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	match phase:
		Phase.INTRO:
			_intro_t += delta
			if _intro_t >= 2.8:
				_begin_cast()
		Phase.CAST:
			_seq_run(delta)
		Phase.SEANCE:
			_tick_seance(delta)
		Phase.TALK:
			_tick_talk(delta)
		Phase.VOTE:
			_tick_vote(delta)
		Phase.REVEAL:
			_seq_run(delta)
		_:
			pass

# ================================================================ CAST
func _begin_cast() -> void:
	phase = Phase.CAST
	phase_label.text = "THE SEANCE — THE CASTING"
	_seq.clear()
	_seq_t = 0.0
	var dim := Color(0.62, 0.58, 0.68)
	_seq_add(0.0, func():
		_ui.cast_show("EYES CLOSED", dim, "all of them", "", Color.WHITE)
		_say("Close your eyes. All of them. I will know."))
	var t := 2.2
	for i in players.size():
		var idx := i
		var nm: String = str(players[i].name)
		var col: Color = players[i].color
		var glyph := PlayerBadge.glyph(i)
		_seq_add(t, func():
			_ui.cast_show(glyph + " " + nm, col, "eyes open — this is for you alone", "", Color.WHITE)
			if not _tally:
				Sfx.play("card", -8.0))
		_seq_add(t + 1.1, func():
			if idx == charlatan:
				_ui.cast_show(glyph + " " + nm, col, "the spirits took the liberty of paying you",
					"YOU WERE PAID — %d GRUDGE, UP FRONT\nTHE WORD IS \"%s\"\nBury it. Do not get caught." % [FEE_GRUDGE, word],
					Color(1.0, 0.78, 0.35))
				VerifyCapture.snap("cast")
			else:
				_ui.cast_show(glyph + " " + nm, col, "you are",
					"FAITHFUL\nGuide the spirit true.", Color(0.75, 0.95, 0.8)))
		_seq_add(t + 3.7, func():
			_ui.cast_show("EYES CLOSED", dim, "", "", Color.WHITE))
		t += 4.4
	_seq_add(t, func():
		_ui.cast_hide()
		_say("The spirits are willing. One of you, less so.")
		_flash_banner("ALL EYES OPEN", Color(0.85, 0.8, 1.0), 1.8))
	_seq_add(t + 2.0, func(): _begin_seance())

func _begin_seance() -> void:
	phase = Phase.SEANCE
	phase_label.text = "THE SEANCE — THE SITTING"
	seance_elapsed = 0.0
	_last_beat = -1
	blanks_label.visible = true
	clue_label.visible = true
	clue_label.text = clue
	_refresh_blanks()
	hint_label.text = "STICK = GUIDE THE PLANCHETTE    A = CHANT ON THE PULSE    B = SURGE"
	_say("Guide the spirit. Chant on the pulse. And keep your hands where the dead can see them.")
	_flash_banner("THE SITTING BEGINS", Color(1.0, 0.85, 0.4), 1.8)
	print("SEANCE_SITTING_START t=%.1f" % game_time)

func _tick_seance(delta: float) -> void:
	seance_elapsed += delta
	timer_label.text = "%02d" % int(ceil(maxf(0.0, SEANCE_TIME - seance_elapsed)))
	# the pulse
	var beat := beat_index()
	if beat != _last_beat:
		_last_beat = beat
		if not _tally:
			Sfx.play("card", -18.0, 0.02)
	var bt := beat_time()
	var pulse := maxf(0.0, 1.0 - bt * 5.0)
	_spirit_flame_mat.emission_energy_multiplier = 2.0 + 3.0 * pulse
	_spirit_light.light_energy = 1.6 + 1.1 * pulse
	if _dwell_cd > 0.0:
		_dwell_cd -= delta

	# players drive the planchette
	for i in players.size():
		if _surge_cd_p[i] > 0.0:
			_surge_cd_p[i] = maxf(0.0, float(_surge_cd_p[i]) - delta)
		var mv := Vector2.ZERO
		var tap := false
		var surge := false
		if players[i].is_bot:
			var d: Dictionary = bots.decide_seance(i, self, delta)
			mv = d.move
			tap = d.tap
			surge = d.surge
		else:
			mv = PlayerInput.get_move(i)
			tap = PlayerInput.just_pressed(i, "a")
			surge = PlayerInput.just_pressed(i, "b")
		if mv.length() > 1.0:
			mv = mv.normalized()
		var force := Vector3(mv.x, 0, mv.y)
		if force.length() > 0.05:
			planchette.apply_force(force, ACCEL_PER, delta)
		_contrib[i] = _contrib[i] * exp(-delta / 0.8) + force * delta
		if tap:
			_do_tap(i)
		if surge and can_surge(i) and force.length() > 0.05:
			_do_surge(i, force.normalized())

	planchette.tick(delta)
	_recent_travel = _recent_travel * exp(-delta / 0.6) + planchette.vel * delta
	_tick_dwell(delta)

	# focus
	focus = clampf(focus - PASSIVE_DECAY * delta, 0.0, 100.0)
	_set_focus_ui(focus / 100.0)
	_update_table_candles()
	if focus <= 35.0 and not _low_focus_warned:
		_low_focus_warned = true
		_say("The candles are voting to leave.")
	if not _snap_board_done and seance_elapsed >= 30.0:
		_snap_board_done = true
		VerifyCapture.snap("board")
	if focus <= 0.0:
		_end_seance(false, "focus")
	elif seance_elapsed >= SEANCE_TIME:
		_end_seance(false, "time")

func _do_tap(p: int) -> void:
	figures[p].flare()
	var bt := beat_time()
	var dist := minf(bt, BEAT_PERIOD - bt)
	var nearest := beat_index() if bt <= BEAT_PERIOD * 0.5 else beat_index() + 1
	var spam: bool = (int(_last_tap_beat[p]) == nearest)
	_last_tap_beat[p] = nearest
	if not spam and dist <= TAP_WINDOW:
		focus = clampf(focus + ON_TAP, 0.0, 100.0)
		_taps_on[p] = int(_taps_on[p]) + 1
	else:
		focus = clampf(focus - OFF_TAP, 0.0, 100.0)
		_taps_off[p] = int(_taps_off[p]) + 1

func _do_surge(p: int, dir: Vector3) -> void:
	_surge_cd_p[p] = SURGE_CD
	_last_surge_t[p] = seance_elapsed
	planchette.apply_impulse(dir, SURGE_IMPULSE)
	planchette.show_surge_ripple()
	if not _tally:
		Sfx.play("bounce", -12.0, 0.15)

func _tick_dwell(delta: float) -> void:
	var found := ""
	var best_d := LETTER_R
	if _dwell_cd <= 0.0:
		for l in _letter_order:
			var ld: Dictionary = _letters[l]
			if int(ld.state) != 0:
				continue
			var lp: Vector3 = ld.pos
			var d := Vector2(planchette.position.x - lp.x, planchette.position.z - lp.z).length()
			if d < best_d:
				best_d = d
				found = l
	if found != dwell_letter:
		dwell_letter = found
		dwell_t = 0.0
	elif found != "":
		dwell_t += delta
	planchette.set_channel(0.0 if dwell_letter == "" else dwell_t / DWELL_TIME)
	if dwell_letter == "":
		_dwell_ring.visible = false
	else:
		var ld2: Dictionary = _letters[dwell_letter]
		var lp2: Vector3 = ld2.pos
		_dwell_ring.visible = true
		_dwell_ring.position = lp2 + Vector3(0, 0.012, 0)
		var k := clampf(dwell_t / DWELL_TIME, 0.0, 1.0)
		var s := 1.6 - 0.6 * k
		_dwell_ring.scale = Vector3(s, 1.0, s)
		var m: StandardMaterial3D = _dwell_ring.material_override
		m.albedo_color.a = 0.25 + 0.6 * k
		if dwell_t >= DWELL_TIME:
			_commit_letter(dwell_letter)

func _commit_letter(l: String) -> void:
	_dwell_cd = 0.7
	dwell_letter = ""
	dwell_t = 0.0
	_dwell_ring.visible = false
	# knock the planchette back toward center — the spirit inhales
	var back := (planchette.board_center - planchette.position)
	back.y = 0.0
	if back.length() > 0.05:
		planchette.apply_impulse(back.normalized(), 0.8)
	var ld: Dictionary = _letters[l]
	var lab: Label3D = ld.label
	var correct := is_letter_in_word(l)
	# public-evidence attribution: whose recent pull pointed the way the
	# planchette actually travelled into this letter
	var approach := _recent_travel
	approach.y = 0.0
	var shares: Dictionary = {}
	var total_w := 0.0
	if approach.length() > 0.001:
		var an := approach.normalized()
		for i in players.size():
			var w := maxf(0.0, _contrib[i].dot(an))
			shares[i] = w
			total_w += w
	if correct:
		ld.state = 1
		lab.modulate = Color(1.0, 0.86, 0.4)
		lab.outline_modulate = Color(0.35, 0.2, 0.02)
		focus = clampf(focus + CORRECT_BONUS, 0.0, 100.0)
		_commits_right += 1
		if not _tally:
			Sfx.play("sink", -4.0)
			var tw := create_tween()
			tw.tween_property(lab, "scale", Vector3(1.45, 1.45, 1.45), 0.16)
			tw.tween_property(lab, "scale", Vector3.ONE, 0.22)
		_refresh_blanks()
		_say(_pick_line(["The spirit concedes a letter.",
			"It moves. It remembers.",
			"A letter, freely given. Savor the novelty."]))
		# alibi credit for whoever pulled truest
		if total_w > 0.0:
			for i in players.size():
				suspicion[i] = maxf(0.0, float(suspicion[i]) - float(shares[i]) / total_w * 0.35)
	else:
		ld.state = 2
		lab.modulate = Color(0.5, 0.16, 0.13)
		lab.outline_modulate = Color(0.1, 0.03, 0.03)
		focus = clampf(focus - WRONG_HIT, 0.0, 100.0)
		_commits_wrong += 1
		_shake = maxf(_shake, 0.22)
		if not _tally:
			Sfx.play("grudge", -6.0)
		_say(_pick_line(["The spirit recoils. Curious.",
			"Someone's hand is heavy tonight.",
			"The dead do not misspell. The living do."]))
		if total_w > 0.0:
			for i in players.size():
				suspicion[i] = float(suspicion[i]) + float(shares[i]) / total_w
		for i in players.size():
			if seance_elapsed - float(_last_surge_t[i]) < 1.0:
				suspicion[i] = float(suspicion[i]) + 0.4
	print("SEANCE_COMMIT letter=%s correct=%s focus=%.0f t=%.1f" % [l, str(correct), focus, seance_elapsed])
	if correct and _word_complete():
		_end_seance(true, "spelled")

func _word_complete() -> bool:
	for l in word_letters:
		if int(_letters[l].state) != 1:
			return false
	return true

func _refresh_blanks() -> void:
	var bits: Array = []
	for ch in word:
		if _letters.has(ch) and int(_letters[ch].state) == 1:
			bits.append(ch)
		else:
			bits.append("_")
	blanks_label.text = " ".join(bits)

func _end_seance(success: bool, cause: String) -> void:
	if phase != Phase.SEANCE:
		return
	_seance_success = success
	_seance_over_cause = cause
	# chant scoring becomes public evidence weight for the bots
	for i in players.size():
		var on := int(_taps_on[i])
		var off := int(_taps_off[i])
		suspicion[i] = float(suspicion[i]) + float(off) / float(maxi(1, on + off)) * 2.2
		print("SEANCE_TAPS p=%d %s on=%d off=%d suspicion=%.2f" % [i, players[i].name, on, off, float(suspicion[i])])
	print("SEANCE_TASK success=%s cause=%s focus=%.0f t=%.1f right=%d wrong=%d" % [
		str(success), cause, focus, seance_elapsed, _commits_right, _commits_wrong])
	planchette.set_channel(0.0)
	_dwell_ring.visible = false
	clue_label.visible = false   # the sitting is over; portraits take the stage
	if success:
		_flash_banner("THE WORD IS SPOKEN", Color(1.0, 0.85, 0.35), 2.4)
		_say("The word is spoken. The circle held.")
		var bits: Array = []
		for ch in word:
			bits.append(ch)
		blanks_label.text = " ".join(bits)
		if not _tally:
			Sfx.play("round_over")
			for f in figures:
				f.play_reaction("Cheer", 2.2)
	else:
		for f in _table_flames:
			f.visible = false
		if cause == "focus":
			_flash_banner("THE SEANCE IS DEAD", Color(1.0, 0.35, 0.28), 2.4)
			_say("The seance is dead. It had help.")
		else:
			_flash_banner("THE SPIRITS DEPART", Color(0.8, 0.5, 0.9), 2.4)
			_say("Time of death: now. The spirits send their regrets.")
		if not _tally:
			Sfx.play("death")
			_time_hit(0.35, 0.3)
	# short beat, then the talk
	phase = Phase.TALK
	vote_t = -2.4    # grace so the banner lands before the clock runs
	phase_label.text = "THE SEANCE — THE ACCUSATIONS"
	hint_label.text = "SPEAK. THE VOTE COMES."
	timer_label.text = ""

func _tick_talk(delta: float) -> void:
	vote_t += delta
	if vote_t < 0.0:
		return
	if vote_t - delta < 0.0:
		# talk actually opens now
		_ui.show_vote_panel(true)
		_say("Accuse each other with your outside voices. The spirits enjoy names."
			if _talk_len >= TALK_TIME else "Accuse. Briskly.")
	timer_label.text = "%02d" % int(ceil(maxf(0.0, _talk_len - vote_t)))
	if vote_t >= _talk_len:
		_begin_vote()

func _begin_vote() -> void:
	phase = Phase.VOTE
	phase_label.text = "THE SEANCE — THE ACCUSATIONS"
	vote_t = 0.0
	hint_label.text = "STICK = POINT THE SPOTLIGHT    A = LOCK YOUR ACCUSATION"
	_say("Point. The dead enjoy theater.")
	for i in players.size():
		var others := _others_of(i)
		_vote_cursor[i] = int(others[0])
		_ui.set_vote_chip(i, int(_vote_cursor[i]), false)
	print("SEANCE_VOTE_OPEN t=%.1f" % game_time)

func _others_of(p: int) -> Array:
	var out: Array = []
	for i in players.size():
		if i != p:
			out.append(i)
	return out

func _tick_vote(delta: float) -> void:
	vote_t += delta
	timer_label.text = "%02d" % int(ceil(maxf(0.0, VOTE_TIME - vote_t)))
	var all_locked := true
	for i in players.size():
		if _vote_locked[i]:
			continue
		all_locked = false
		var others := _others_of(i)
		if players[i].is_bot:
			var choice := bots.decide_vote(i, self, others, vote_t)
			if choice >= 0:
				_vote_cursor[i] = choice
				_lock_vote(i)
			else:
				var hov := bots.hover_vote(i, self, others, delta, int(_vote_cursor[i]))
				if hov != int(_vote_cursor[i]):
					_vote_cursor[i] = hov
					_ui.set_vote_chip(i, hov, false)
		else:
			var nav := _nav_dir(i)
			if nav != 0:
				var at := others.find(int(_vote_cursor[i]))
				at = wrapi(at + nav, 0, others.size())
				_vote_cursor[i] = int(others[at])
				_ui.set_vote_chip(i, int(_vote_cursor[i]), false)
				if not _tally:
					Sfx.play("card", -6.0)
			if PlayerInput.just_pressed(i, "a"):
				_lock_vote(i)
				all_locked = false   # recount next frame
	if all_locked or vote_t >= VOTE_TIME:
		_begin_reveal()

func _lock_vote(p: int) -> void:
	if _vote_locked[p]:
		return
	_vote_locked[p] = true
	vote_target[p] = int(_vote_cursor[p])
	_lock_order.append(p)
	_ui.set_vote_chip(p, int(vote_target[p]), true)
	if not _tally:
		Sfx.play("confirm", -3.0)
	print("SEANCE_VOTE p=%d %s -> %s t=%.1f" % [p, players[p].name,
		players[vote_target[p]].name, vote_t])
	if not _snap_accuse_done:
		_snap_accuse_done = true
		VerifyCapture.snap("accuse")

# ================================================================ REVEAL
func _begin_reveal() -> void:
	if phase == Phase.REVEAL:
		return
	phase = Phase.REVEAL
	phase_label.text = "THE SEANCE — THE VERDICT"
	hint_label.text = ""
	timer_label.text = ""
	_correct_votes = 0
	for i in players.size():
		if i != charlatan and int(vote_target[i]) == charlatan:
			_correct_votes += 1
	var honest := players.size() - 1
	_caught = _correct_votes >= mini(2, honest)
	print("SEANCE_VERDICT caught=%s correct_votes=%d charlatan=%d success=%s" % [
		str(_caught), _correct_votes, charlatan, str(_seance_success)])
	_seq.clear()
	_seq_t = 0.0
	_seq_add(0.0, func():
		_say("The votes are cast. Let us see whom you have chosen to ruin."))
	_seq_add(1.6, func():
		_flash_banner("THE CHARLATAN WAS...", Color(0.9, 0.85, 1.0), 999.0))
	_seq_add(3.2, func(): _unmask_moment())
	_seq_add(4.9, func(): _verdict_moment())
	_seq_add(6.1, func(): _settle_moment())
	_seq_add(9.6, func(): _finish_match())

func _unmask_moment() -> void:
	var nm: String = str(players[charlatan].name)
	var col: Color = players[charlatan].color
	_flash_banner(PlayerBadge.glyph(charlatan) + " " + nm, col, 999.0)
	_ui.spotlight_portrait(charlatan)
	# stage spotlight snaps to the guilty chair
	var fig: SeanceFigure = figures[charlatan]
	_reveal_spot.light_energy = 4.0
	_reveal_spot.look_at_from_position(Vector3(fig.position.x * 0.5, 8.5, fig.position.z * 0.5 + 3.0),
		fig.position + Vector3(0, 1.0, 0), Vector3.UP)
	_shake = maxf(_shake, 0.4)
	if not _tally:
		Sfx.play("grudge", 0.0)
		_time_hit(0.25, 0.4)
	if _caught:
		fig.react_unmasked_caught()
		for i in players.size():
			if i != charlatan and int(vote_target[i]) == charlatan:
				figures[i].react_cheer()
	else:
		fig.react_cheer()
	if not _seance_success:
		_say("The word, for the record, was %s." % word)
	VerifyCapture.snap("reveal")

func _verdict_moment() -> void:
	if _caught:
		_flash_sub("THE CIRCLE HOLDS THE TRAITOR", Color(0.75, 1.0, 0.7), 4.5)
		_say("The Charlatan: %s. The spirits knew before you did." % players[charlatan].name)
		if not _tally:
			Sfx.play("match_win")
			for i in players.size():
				if i != charlatan and int(vote_target[i]) == charlatan:
					_spawn_confetti(figures[i].position + Vector3(0, 1.6, 0), players[i].color)
	else:
		_flash_sub("THE CHARLATAN WALKS", Color(1.0, 0.55, 0.4), 4.5)
		_say("The Charlatan walks: %s. Applaud; it cost you enough." % players[charlatan].name)
		if not _tally:
			Sfx.play("match_win", -4.0)
			_spawn_confetti(figures[charlatan].position + Vector3(0, 1.6, 0), players[charlatan].color)

func _settle_moment() -> void:
	# ---- economy per the research doc (see class docs)
	if not _practice:
		if _seance_success:
			for i in players.size():
				if i != charlatan:
					_currency.append({"type": "royalty", "player": i, "amount": HOLD_ROYALTY,
						"reason": "held the circle against a paid hand"})
		elif not _caught:
			_currency.append({"type": "royalty", "player": charlatan, "amount": ESCAPE_ROYALTY,
				"reason": "the seance died on schedule and nobody hanged for it"})
		if _caught:
			_currency.append({"type": "grudge", "player": charlatan, "amount": CAUGHT_GRUDGE,
				"reason": "dragged into the light"})
		for i in players.size():
			if i != charlatan and int(vote_target[i]) == charlatan:
				_currency.append({"type": "royalty", "player": i, "amount": CATCH_ROYALTY,
					"reason": "fingered the charlatan"})
		if _caught:
			var first_correct := -1
			for p in _lock_order:
				if int(p) != charlatan and int(vote_target[p]) == charlatan:
					first_correct = int(p)
					break
			if first_correct >= 0:
				_kill_events.append({"killer": first_correct, "victim": charlatan, "cause": "seance"})
	# ---- settle rows on screen
	_ui.clear_settle_rows()
	if _practice:
		_ui.add_settle_row("practice sitting — nothing at stake", Color(0.7, 0.68, 0.75))
	if _seance_success:
		_ui.add_settle_row("the seance HELD — the faithful collect royalties", Color(1.0, 0.85, 0.4))
	else:
		_ui.add_settle_row("the seance DIED — the word was %s" % word, Color(1.0, 0.5, 0.42))
	if _caught:
		_ui.add_settle_row("%s eats %d grudge, dragged into the light" % [players[charlatan].name, CAUGHT_GRUDGE],
			players[charlatan].color)
	elif not _seance_success:
		_ui.add_settle_row("%s converts the fee — +%d royalty, clean hands" % [players[charlatan].name, ESCAPE_ROYALTY],
			players[charlatan].color)
	for i in players.size():
		if i != charlatan and int(vote_target[i]) == charlatan:
			_ui.add_settle_row("%s fingered the charlatan — +%d royalty" % [players[i].name, CATCH_ROYALTY],
				players[i].color)
	VerifyCapture.snap("settle")

func _finish_match() -> void:
	if _reported:
		return
	_reported = true
	phase = Phase.DONE
	# ---- points -> placements (distributed; no majority ever required)
	var points := {}
	for i in players.size():
		var pts := 0
		if i == charlatan:
			# the contract was "make it fail WITHOUT getting caught" —
			# caught voids everything; a clean escape pays, a clean KILL pays big
			if not _caught:
				pts += 1
				if not _seance_success:
					pts += 4
		else:
			if _seance_success:
				pts += 2
			if int(vote_target[i]) == charlatan:
				pts += 1
		points[i] = pts
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if points[a] != points[b]:
			return points[a] > points[b]
		return a < b)
	# ---- highlights
	if _caught:
		var first_c := -1
		for p in _lock_order:
			if int(p) != charlatan and int(vote_target[p]) == charlatan:
				first_c = int(p)
				break
		if first_c >= 0:
			_highlights.append("%s fingered the charlatan first" % players[first_c].name)
		_highlights.append("%s sold the seance for %d grudge and got dragged into the light" % [
			players[charlatan].name, FEE_GRUDGE])
	elif not _seance_success:
		_highlights.append("%s buried the word %s and walked away clean" % [players[charlatan].name, word])
	if _seance_success:
		_highlights.append("the circle spelled %s through a paid hand" % word)
	if _commits_wrong >= 4:
		_highlights.append("the spirit recoiled %d times in one sitting" % _commits_wrong)
	# ---- monuments
	var monuments: Array = []
	if not _practice and not _seance_success and _correct_votes == 0:
		monuments.append({"player": charlatan, "kind": "charlatan",
			"label": "%s, the Perfect Con" % players[charlatan].name})
	var results := {
		"placements": order,
		"points": points,
		"currency_events": _currency.duplicate(),
		"kill_events": _kill_events.duplicate(),
		"highlights": _dedup(_highlights).slice(0, 3),
		"monuments": monuments,
	}
	print("KILL_EVENTS n=", _kill_events.size(), " ", JSON.stringify(_kill_events))
	print("SEANCE_RESULTS ", JSON.stringify(results))
	if _tally:
		_print_tally(points)
		report_finished(results)
		get_tree().quit()
		return
	_flash_banner("%s TAKES THE SITTING" % players[order[0]].name, players[order[0]].color, 6.0)
	report_finished(results)

func _print_tally(points: Dictionary) -> void:
	print("======== SEANCE TALLY ========")
	print("SEANCE_TALLY seed=%d word=%s charlatan=%s success=%s caught=%s correct_votes=%d" % [
		rng.seed, word, players[charlatan].name, str(_seance_success), str(_caught), _correct_votes])
	print("focus_end=%.0f commits right=%d wrong=%d cause=%s%s" % [focus, _commits_right,
		_commits_wrong, _seance_over_cause, " (SABO OFF)" if _no_sabo else ""])
	var bits: Array = []
	for i in players.size():
		bits.append("%s=%d%s" % [players[i].name, int(points[i]), "*" if i == charlatan else ""])
	print("points: %s (* = charlatan)" % " ".join(bits))
	var sus: Array = []
	for i in players.size():
		sus.append("%s=%.2f" % [players[i].name, float(suspicion[i])])
	print("suspicion: %s" % " ".join(sus))
	print("==============================")

# ================================================================ queries (bots)
func beat_index() -> int:
	return int(seance_elapsed / BEAT_PERIOD)

func beat_time() -> float:
	return fmod(seance_elapsed, BEAT_PERIOD)

func letter_pos(l: String) -> Vector3:
	if _letters.has(l):
		return _letters[l].pos
	return Vector3.ZERO

func all_letters() -> Array:
	return _letter_order

func is_letter_settled(l: String) -> bool:
	return _letters.has(l) and int(_letters[l].state) != 0

func is_letter_in_word(l: String) -> bool:
	return word_letters.has(l)

## First letter of the word (reading order) not yet revealed — bots try to
## spell in order, which reads as intent on the couch.
func next_needed_letter() -> String:
	for ch in word:
		if int(_letters[ch].state) == 0:
			return ch
	return ""

func can_surge(p: int) -> bool:
	return float(_surge_cd_p[p]) <= 0.0

func player_name(i: int) -> String:
	return players[i].name if i >= 0 and i < players.size() else "???"

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
func _set_focus_ui(k: float) -> void:
	focus_fill.size.x = 236.0 * clampf(k, 0.0, 1.0)
	focus_fill.color = Color(0.45, 0.9, 0.55).lerp(Color(0.95, 0.3, 0.2), 1.0 - k)

func _update_table_candles() -> void:
	var lit := int(ceil(focus / 10.0))
	for i in _table_flames.size():
		_table_flames[i].visible = i < lit

func _say(text: String) -> void:
	executor_label.text = "“" + text + "”  — THE EXECUTOR"

func _pick_line(lines: Array) -> String:
	return str(lines[rng.randi_range(0, lines.size() - 1)])

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

# ================================================================ verify hooks
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.SEANCE
