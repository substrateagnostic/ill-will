extends Minigame
## THE WIDOW'S GAZE — red light / green light at a wake, with sabotage.
## A long parlor: mourners behind a velvet rope at one end, the coffin, the
## relic table and THE WIDOW at the other. While she weeps (GREEN) you creep
## forward, lift relics off the wake and haul them home to your memorial chest.
## A rising sting (~0.5s) warns — then she WHIPS around (RED) and any body still
## moving under her gaze is taken by spectral lightning and flung back to the
## rope, dropping its relic mid-field. The ILL WILL twist: B is SHOVE — shove a
## rival as the sting plays and the Widow does your murder for you.
##
## 75s single round, all four play, no dead time (caught players respawn in
## 1.2s). Most banked value wins; ties go to a sudden-death grab. T-25 she grows
## suspicious: cycles shorten and she adds FAKE-OUTS (the falling third note is
## the learnable tell; the second sting in a fake-out chain is always real).
##
## Anthology module contract: root of minigames/widows_gaze/widows_gaze.tscn,
## extends Minigame. Runs standalone — if begin() isn't called 0.5s after _ready
## it self-starts a 4-player config with bots driving the empty seats.
##
## CLI user args (after --):
##   --wgbots            all players are seeded self-play bots
##   --seed=N            rng seed for standalone start (default 1)
##   --players=N         standalone roster size 2..4
##   --roundtime=S       override the 75s round (verification)
##   --wgtally           print WG_TALLY at match end, then quit (headless ok)
##   --wgfast=K          Engine.time_scale=K for soak runs (sim identical)
##   --wgcap             event/state-based screenshots -> verify_out, then quit
##   --outdir=DIR        output dir for --wgcap (default verify_out)
##   --shots=N,...       handled by the house VerifyCapture autoload (PNGs)

enum Phase { WAITING, INTRO, PLAY, TIEBREAK, MATCH_END }
enum Gaze { WEEPING, STING, WATCHING }
enum RelicState { FIELD, HELD, BANKED }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

# ---- the parlor (long room; players walk -Z toward the Widow) ----
const ROOM_HALF_X := 6.2
const ROOM_MIN_Z := -11.5           # the wake end (Widow / coffin)
const ROOM_MAX_Z := 11.5            # the rope end (chests / spawns)
const ROPE_Z := 8.8                 # the velvet rope line
const WIDOW_POS := Vector3(0, 0, -10.8)
const COFFIN_POS := Vector3(0, 0, -9.5)
const CHEST_XS := [-4.5, -1.5, 1.5, 4.5]
const CHEST_Z := 10.2
const SPAWN_Z := 9.7

# ---- fixed relic layout (deterministic: the mirror builds the same wake) ----
# [tier, x, z] — highest tiers nearest the Widow (risk/reward, spec)
const RELIC_LAYOUT := [
	[2, -2.2, -8.4], [2, 2.2, -8.4], [2, 0.0, -9.0],       # portraits, 3pt
	[1, -3.4, -7.2], [1, 0.0, -7.0], [1, 3.4, -7.2],       # urns, 2pt
	[0, -4.6, -5.6], [0, -1.6, -5.9], [0, 1.6, -5.9], [0, 4.6, -5.6],  # lockets, 1pt
]

# ---- verbs ----
const GRAB_RANGE := 1.4
const BANK_RANGE := 1.7
const SHOVE_RANGE := 1.7

# ---- the gaze (all times seconds) ----
const STING_TIME := 0.5             # the warning IS the skill window (spec)
const GREEN_EARLY := Vector2(2.6, 4.4)     # tuned: ~12 stings/round keeps hauls contested
const GREEN_LATE := Vector2(1.8, 3.0)      # after escalation
const WATCH_EARLY := Vector2(1.8, 2.6)
const WATCH_LATE := Vector2(2.0, 2.8)
const FAKE_CHANCE := 0.45           # escalated: odds a scheduled turn is a fake
const FAKE_REARM := Vector2(0.35, 0.8)     # weep gap between fake and the REAL sting
const SOB_PERIOD := 1.4

# ---- round ----
const ROUND_TIME := 75.0
const ESCALATE_AT := 25.0           # T-25 FINAL STRETCH (spec)
const INTRO_TIME := 1.6
const MATCH_END_HOLD := 8.0
const TIEBREAK_SAFETY := 45.0
const CAM_FOV := 55.0

# VOICE B floor pools (doc 26 §2) — drawn via Voice.pick, presentation-only.
# The go-signal fires every round; the kill line fires many times a round. Both
# want variants. Neither touches sim rng or a receipt path.
const VP_STEAL_WINDOW: PackedStringArray = [
	"SHE WEEPS — CREEP",
	"THE PARLOR IS OPEN",
	"HER BACK IS TURNED",
	"GO, QUIETLY",
	"THE WAKE IS UNWATCHED",
]
const VP_FED_WIDOW: PackedStringArray = [
	"%s FED %s TO THE WIDOW",
	"%s GAVE %s TO HER GAZE",
	"%s LET THE WIDOW SEE %s",
	"%s OFFERED UP %s",
	"%s SAT %s IN HER SIGHT",
	"%s LEFT %s FOR THE WIDOW",
]

# ui_kit adoption (doc 14 nit 5): the Mario-Party intro card at load. Accent is
# the widow's spectral violet. Feature-detected glyphs, real key fallback.
const GAME_INTRO := {
	"name": "THE WIDOW'S GAZE",
	"goal": "Rob the wake while she weeps. FREEZE when she turns — or be taken.",
	"accent": Color(0.68, 0.5, 0.95),
	"controls": [
		{"action": "move", "label": "CREEP"},
		{"action": "a", "label": "GRAB / BANK"},
		{"action": "b", "label": "SHOVE"},
	],
	"tips": [
		"Hold A by a relic to lift it, carry it home, press A at your chest to bank.",
		"SHOVE a rival as the sting rises and the Widow does your murder for you.",
		"Once she grows suspicious, a FALLING third note is a fake-out — hold.",
	],
}
const WIDOW_VIOLET := Color(0.68, 0.5, 0.95)

var roster: Array = []
var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()
var practice := false
var round_time := ROUND_TIME

var players: Array = []             # WGPawn per roster slot
var widow: WGWidow
var relics: Array = []              # [{node:WGRelic, tier:int, value:int, state:RelicState, pos:Vector2, holder:int}]
var chest_pads: Array = []          # MeshInstance3D glow pad per chest
var carried: Array = []             # per player: relic index or -1

var phase: Phase = Phase.WAITING
var phase_t := 0.0
var round_t := 0.0
var game_t := 0.0

var gaze: Gaze = Gaze.WEEPING
var gaze_t := 0.0
var green_dur := 4.5
var watch_dur := 2.0
var sting_fake := false
var force_real := false             # the sting after a fake is always real
var sting_seq := 0                  # increments per sting (bots reroll reaction)
var escalated := false
var _sob_t := 0.0
var _sting_notes_played := 0

var points := {}                    # banked value per player
var caught_count := {}
var murders := {}
var _currency: Array = []
var _kill_events: Array = []        # {killer, victim, cause:"gazed"} per contract
var _highlights: Array = []
var _results := {}

# tie ceremony
var tie_players: Array = []
var tie_relic := -1

var bots: WGBots
var bot_enabled: Array = []
var _begun := false
var _reported := false
var _standalone := false

# ui_kit adoption (doc 14 nit 5): intro card at load + staged final standings.
var _intro_card: IntroCard = null
var _results_board: ResultsBoard = null
var _board_running := false

# CLI
var _cli_seed := 1
var _cli_players := 4
var _cli_roundtime := -1.0
var _bots_all := false
var _tally_mode := false
var _cap_on := false
var _cap_dir := "verify_out"
var _cap_done := {}
var _fast := 1.0

# juice
var _shake := 0.0
var _cam_base: Transform3D
var _slowmo := false
var _vc: Node = null
var _banner_col := "ffffff"
var _stretch: FinalStretch = null
var _tick_players: Array = []       # exact-pitch pool for the sting ladder + sobs
var _tick_next := 0
var _tick_stream: AudioStream = null
var _sob_stream: AudioStream = null
var _last_status := 0.0

# lighting rig (the lights drop when she watches)
var _sun_warm := 1.35
var _amb_warm := 0.6
var _env: Environment = null
var _warm_lights: Array = []        # candles + lamps: THE room light; dies on RED
var _warm_energies: Array = []

# tally
var _ev_catches := 0
var _ev_murders := 0
var _ev_shoves := 0                 # swings
var _ev_shove_hits := 0
var _ev_banks := 0
var _ev_stings := 0
var _ev_fakeouts := 0
var _ev_last_catch: Array = [-1, -1]   # victim, killer
var _ev_last_bank: Array = [-1, 0]     # player, value
var _net_champ := -1

# ONLINE PHASE 2 — the render mirror (house pattern per greed.gd). Host runs the
# whole sim; the estate pumps _net_state() (PUBLIC facts) at 20 Hz; the client
# boots this same scene with config.net_mirror = true and _net_apply() drives
# the visuals, all juice fired locally from state DELTAS. No hidden info.
var _mirror := false
var _mir := {}
var _mir_gh: Array = []             # smooth local grab-hold per seat
var _mir_champ_done := false

@onready var cam: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var ui: CanvasLayer = $UI
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var banner: Label = $UI/Banner
@onready var gaze_label: Label = $UI/GazeLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows


# ===========================================================================
# Lifecycle
# ===========================================================================
func _ready() -> void:
	_parse_args()
	_vc = get_node_or_null("/root/VerifyCapture")
	_build_world()
	banner.visible = false
	gaze_label.visible = false
	timer_label.text = ""
	round_label.text = "THE WIDOW'S GAZE"
	if _fast > 1.0:
		Engine.time_scale = _fast
	await get_tree().create_timer(0.5).timeout
	if not _begun:
		_standalone = true
		begin(_default_config())


func begin(config: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	_mirror = bool(config.get("net_mirror", false))
	roster = config.roster
	rng.seed = int(config.rng_seed)
	fx_rng.seed = int(config.rng_seed) + 4177
	practice = bool(config.get("practice", false))
	if _cli_roundtime > 0.0:
		round_time = clampf(_cli_roundtime, 10.0, 180.0)
	_stretch = FinalStretch.attach(self, timer_label)
	bot_enabled.clear()
	for i in roster.size():
		bot_enabled.append(_bots_all or bool(roster[i].get("bot", false)))
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var pawn := WGPawn.new()
		pawn.name = "Pawn%d" % i
		add_child(pawn)
		pawn.setup(i, pl.color, str(pl.char_scene))
		players.append(pawn)
		points[i] = 0
		caught_count[i] = 0
		murders[i] = 0
		carried.append(-1)
		_mir_gh.append(0.0)
		_tint_chest(i, pl.color)
	hint_label.text = _controls_bar()
	if _mirror:
		# RENDER MIRROR: no bots, no gaze machine, no economy — the host owns
		# every fact. Pawns stand ready for the first _net_apply.
		phase = Phase.WAITING
		for i in roster.size():
			(players[i] as WGPawn).global_position = _spawn_pos(i)
		print("WG_MIRROR boot players=%d my_seat=%d" % [roster.size(), NetSession.my_seat()])
		return
	bots = WGBots.new()
	bots.setup(int(config.rng_seed) ^ 0x71D0, roster.size())
	if _cap_on:
		# verify-only capture rig: hungrier shovers so the murder beat lands on
		# film inside one round. Never active in normal play or --wgtally runs.
		for i in bots.malice.size():
			bots.malice[i] = maxf(float(bots.malice[i]), 0.7)
	_log("begin players=%d seed=%d bots=%s" % [
		roster.size(), int(config.rng_seed), str(bot_enabled)])
	# ui_kit intro card at load, then the round. Headless assert modes skip the
	# ceremony (byte-identical receipts); the card auto-starts after 6s so an
	# all-bot windowed demo flows through untouched.
	if _tally_mode or _cap_on:
		_start_round()
	else:
		_present_intro_card()


func _present_intro_card() -> void:
	_intro_card = IntroCard.new()
	add_child(_intro_card)
	_intro_card.started.connect(_start_round)
	var spec: Dictionary = GAME_INTRO.duplicate(true)
	spec["seats"] = _human_seats()
	_intro_card.present(spec)
	if _vc != null:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _vc.snap("wg_intro"))


func _start_round() -> void:
	phase = Phase.INTRO
	phase_t = 0.0
	round_t = 0.0
	_last_status = 0.0
	escalated = false
	gaze = Gaze.WEEPING
	gaze_t = 0.0
	green_dur = _roll(GREEN_EARLY)
	force_real = false
	sting_fake = false
	for i in roster.size():
		(players[i] as WGPawn).reset_for_round(_spawn_pos(i), PI)   # face the wake (-Z)
	widow.weep(true)
	_set_lights(false, true)
	_flash_banner("THE WIDOW WEEPS", Color(0.8, 0.88, 1.0), 1.4)
	hint_label.visible = true
	var tw := create_tween()
	tw.tween_interval(8.0)
	tw.tween_callback(func() -> void: hint_label.visible = false)
	_rebuild_scoreboard()
	_log("round_start time=%.0f relics=%d" % [round_time, relics.size()])


# ===========================================================================
# Main loop
# ===========================================================================
func _physics_process(delta: float) -> void:
	if _mirror:
		game_t += delta
		_mirror_tick(delta)
		return
	if phase == Phase.WAITING:
		return
	game_t += delta
	phase_t += delta
	# keep every body inside the parlor, whatever the phase (belt-and-braces:
	# a yeet arc, a stale intent, or a wall seam can never strand a pawn out)
	for p in players:
		var gp: WGPawn = p
		gp.global_position.x = clampf(gp.global_position.x, -ROOM_HALF_X + 0.4, ROOM_HALF_X - 0.4)
		gp.global_position.z = clampf(gp.global_position.z, ROOM_MIN_Z + 0.6, ROOM_MAX_Z - 0.4)
	match phase:
		Phase.INTRO:
			for p in players:
				(p as WGPawn).set_move_intent(Vector2.ZERO)
				(p as WGPawn).tick_movement(delta)
			if phase_t >= INTRO_TIME:
				phase = Phase.PLAY
				round_t = 0.0
				_flash_banner(Voice.pick(VP_STEAL_WINDOW), Color(1, 0.85, 0.2), 1.0)
				Sfx.play("confirm")
				if _stretch != null:
					_stretch.play_started()
		Phase.PLAY:
			round_t += delta
			_tick_play(delta)
		Phase.TIEBREAK:
			round_t += delta
			_tick_play(delta, true)
		Phase.MATCH_END:
			for p in players:
				(p as WGPawn).set_move_intent(Vector2.ZERO)   # kill stale bot intents
				(p as WGPawn).tick_movement(delta)
			if _cap_on:
				_capture_beats()
			# the ResultsBoard reports on its `done` beat when present (host,
			# non-headless); the MATCH_END_HOLD gate is the no-board fallback.
			if not _board_running and phase_t >= MATCH_END_HOLD and not _reported:
				_reported = true
				report_finished(_results)
				if _tally_mode:
					_print_tally()
					get_tree().quit()


func _tick_play(delta: float, tiebreak := false) -> void:
	# 1. the gaze machine
	_tick_gaze(delta)

	# 2. drive every player in index order (deterministic)
	for p in roster.size():
		var me: WGPawn = players[p]
		var inp := _input_for(p, delta)
		if tiebreak and not tie_players.has(p):
			inp = {"move": Vector2.ZERO, "grab": false, "shove": false, "pose": false}
		me.set_move_intent(inp.move)
		if bool(inp.get("pose", false)) and me.can_control() and not me.carrying:
			var clips := ["Blocking", "Interact", "Cheer"]
			me.funny_pose(clips[rng.randi_range(0, clips.size() - 1)], rng.randf_range(0.8, 1.5))
			_log("pose p%d" % p)
		if inp.shove and me.can_control() and me.shove_cd <= 0.0:
			_attempt_shove(p)
		_handle_grab(p, me, inp, delta)
		me.tick_movement(delta)

	# 4. THE GAZE TAKES: any moving body under the lamped eyes
	if gaze == Gaze.WATCHING:
		for p in roster.size():
			var me: WGPawn = players[p]
			if me.can_be_caught() and me.horizontal_speed() > WGPawn.STOP_EPSILON:
				_catch(p)

	# 5. banking + relic transforms
	_update_relic_transforms()

	# 6. HUD
	_update_hud()

	if _cap_on:
		_capture_beats()

	# 7. escalation + timeout (regulation only)
	if not tiebreak:
		if not escalated and round_time - round_t <= ESCALATE_AT:
			_escalate()
		if round_t >= round_time:
			_end_round("timeout")
		elif _all_relics_banked():
			_end_round("clean")
	else:
		if round_t >= TIEBREAK_SAFETY:
			_flash_banner("THE WIDOW LOSES PATIENCE", Color(1, 0.4, 0.3), 2.0)
			_finish_match(tie_players[0])


func _process(delta: float) -> void:
	if phase == Phase.WAITING and not _mirror:
		return
	# camera shake
	cam.global_transform = _cam_base
	if _shake > 0.002:
		_shake = maxf(0.0, _shake - delta * 1.4)
		var j := Vector3(fx_rng.randf_range(-1, 1), fx_rng.randf_range(-1, 1),
			fx_rng.randf_range(-1, 1))
		cam.position += j * _shake * 0.4
		ShakeKit.roll(cam, _shake, j.x)   # rotational force, reusing the jitter above
	if widow:
		widow.tick(delta, game_t)
	for p in players:
		(p as WGPawn).tick_visual(delta, game_t)
	for r in relics:
		if r.state != RelicState.BANKED:
			(r.node as WGRelic).tick(delta)
	# HUD timer (mirror: text rides the snapshot)
	if not _mirror:
		if phase == Phase.PLAY:
			var remain := int(ceil(maxf(0.0, round_time - round_t)))
			timer_label.text = str(remain)
			timer_label.add_theme_color_override("font_color",
				Color(1, 0.3, 0.2) if remain <= 10 else Color(1, 0.92, 0.6))
			if _stretch != null:
				_stretch.tick(round_time - round_t)
		elif phase == Phase.TIEBREAK:
			timer_label.text = "SUDDEN DEATH"
			timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		elif phase == Phase.INTRO:
			timer_label.text = str(int(round_time))
		else:
			timer_label.text = ""


# ===========================================================================
# THE GAZE — weep / sting / watch, with fake-outs after escalation
# ===========================================================================
func _tick_gaze(delta: float) -> void:
	gaze_t += delta
	match gaze:
		Gaze.WEEPING:
			_sob_t -= delta
			if _sob_t <= 0.0:
				_sob_t = SOB_PERIOD + rng.randf_range(-0.2, 0.3)
				_play_pitched(0.5 + rng.randf_range(-0.06, 0.06), -20.0, true)
			if gaze_t >= green_dur:
				_begin_sting()
		Gaze.STING:
			# the rising ladder: 3 notes across the 0.5s window. The fake's third
			# note FALLS — the learnable tell (spec: audibly distinct on repeats).
			var marks := [0.0, 0.18, 0.36]
			while _sting_notes_played < 3 and gaze_t >= marks[_sting_notes_played]:
				var pitches := [0.9, 1.15, (0.72 if sting_fake else 1.45)]
				_play_pitched(pitches[_sting_notes_played], -4.0)
				_sting_notes_played += 1
			if gaze_t >= STING_TIME:
				if sting_fake:
					_resume_weeping(true)
				else:
					_begin_watching()
		Gaze.WATCHING:
			if gaze_t >= watch_dur:
				_resume_weeping(false)


func _begin_sting() -> void:
	gaze = Gaze.STING
	gaze_t = 0.0
	sting_seq += 1
	_sting_notes_played = 0
	_ev_stings += 1
	# fake-outs exist only after escalation; a fake is ALWAYS followed by a real
	sting_fake = escalated and not force_real and rng.randf() < FAKE_CHANCE
	if sting_fake:
		_ev_fakeouts += 1
		widow.fakeout_turn(STING_TIME)
	else:
		widow.whip_turn(STING_TIME)
	force_real = false
	_log("sting seq=%d fake=%s" % [sting_seq, str(sting_fake)])


func _begin_watching() -> void:
	gaze = Gaze.WATCHING
	gaze_t = 0.0
	watch_dur = _roll(WATCH_LATE if escalated else WATCH_EARLY)
	widow.set_gaze(true)
	_set_lights(true)
	Sfx.play("bumper", -4.0)
	gaze_label.text = "SHE  WATCHES"
	gaze_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	gaze_label.visible = true
	_log("watching dur=%.2f" % watch_dur)


func _resume_weeping(was_fake: bool) -> void:
	gaze = Gaze.WEEPING
	gaze_t = 0.0
	if was_fake:
		# the chained REAL sting comes fast — this gap is the trap
		green_dur = _roll(FAKE_REARM)
		force_real = true
		_log("fakeout resolved -> real sting in %.2f" % green_dur)
	else:
		green_dur = _roll(GREEN_LATE if escalated else GREEN_EARLY)
		widow.weep()
		widow.set_gaze(false)
		_set_lights(false)
		gaze_label.visible = false
		_sob_t = 0.4
		_log("weeping dur=%.2f" % green_dur)


func _escalate() -> void:
	escalated = true
	if _stretch != null:
		_stretch.escalate()
	_flash_banner("SHE GROWS SUSPICIOUS", Color(1.0, 0.55, 0.75), 2.0)
	Sfx.play("grudge", -8.0)
	_log("escalate t=%.1f" % round_t)


# ===========================================================================
# THE CATCH — spectral lightning, yeet to the rope, relic drops mid-field
# ===========================================================================
func _catch(victim: int) -> void:
	var me: WGPawn = players[victim]
	var at := me.global_position
	# murder attribution: still stumbling from a shove = the shover did this
	var killer := me.shove_by if me.stumble_t > 0.0 else -1
	# the carried relic drops where they stood — a tempting mid-field pickup
	var dropped := -1
	if carried[victim] >= 0:
		dropped = carried[victim]
		_drop_relic(victim, at)
	caught_count[victim] = int(caught_count[victim]) + 1
	_ev_catches += 1
	_ev_last_catch = [victim, killer]
	me.get_caught(_spawn_pos(victim))
	# ---- the juice: lightning + squash-pop + hitstop + shake ----
	_lightning_to(at + Vector3(0, 1.0, 0))
	me.flash_pop()
	if not _reduced_motion():
		_shake = maxf(_shake, 0.5)
	Sfx.play("crush", -2.0)
	Sfx.play("death", -6.0)
	var deciding := _is_deciding_catch(victim, dropped)
	if deciding and not _reduced_motion():
		_time_hit(0.25, 0.8)
		FinalStretch.fov_punch(cam, CAM_FOV, 6.0, 0.8)
	else:
		_time_hit(0.5, 0.2)
	if killer >= 0:
		murders[killer] = int(murders[killer]) + 1
		_ev_murders += 1
		points[killer] = int(points[killer]) + 1
		_currency.append({"type": "royalty", "player": killer, "amount": 1,
			"reason": "fed %s to the Widow" % roster[victim].name})
		_flash_banner(Voice.pick_fmt(VP_FED_WIDOW, [roster[killer].name, roster[victim].name]),
			roster[killer].color, 2.0)
		_rebuild_scoreboard()
	else:
		_flash_banner("THE WIDOW TAKES %s" % roster[victim].name,
			Color(0.8, 0.88, 1.0), 1.6)
	_currency.append({"type": "grudge", "player": victim, "amount": 1,
		"reason": "taken by the Widow's gaze"})
	_kill_events.append({"killer": killer, "victim": victim, "cause": "gazed"})
	_cap_event("catch")
	if killer >= 0:
		_cap_event("murder")
	_log("catch victim=%d killer=%d dropped=%d at=(%.1f,%.1f) deciding=%s" % [
		victim, killer, dropped, at.x, at.z, str(deciding)])


## Round-deciding catch (doc 09 §B): sudden-death catches always; in regulation
## the last-10s catch of a carrier whose banked+carried would take/keep the lead.
func _is_deciding_catch(victim: int, dropped_relic: int) -> bool:
	if phase == Phase.TIEBREAK:
		return true
	if round_time - round_t > 10.0 or dropped_relic < 0:
		return false
	var would := int(points[victim]) + int(relics[dropped_relic].value)
	for q in roster.size():
		if q != victim and int(points[q]) > would:
			return false
	return true


# ===========================================================================
# SHOVE — the sabotage verb (HIT KIT to spec §B1)
# ===========================================================================
func _attempt_shove(p: int) -> void:
	var me: WGPawn = players[p]
	_ev_shoves += 1
	me.do_shove_swing()
	# nearest shovable body in range
	var best := -1
	var best_d := SHOVE_RANGE
	for q in roster.size():
		if q == p:
			continue
		var o: WGPawn = players[q]
		if o.is_caught():
			continue
		var d := _flat_dist(me.global_position, o.global_position)
		if d < best_d:
			best_d = d
			best = q
	if best < 0:
		_log("shove_whiff p%d" % p)
		return
	var victim: WGPawn = players[best]
	var dir := victim.global_position - me.global_position
	victim.get_shoved(dir, p)
	_ev_shove_hits += 1
	# forced drop (legal on GREEN too — drop-forcing, spec)
	if carried[best] >= 0:
		_drop_relic(best, victim.global_position)
		_currency.append({"type": "royalty", "player": p, "amount": 1,
			"reason": "shoved a relic out of %s's hands" % roster[best].name})
		_currency.append({"type": "grudge", "player": best, "amount": 1,
			"reason": "shoved, dropped the goods"})
		Sfx.play("place", -4.0)
	# HIT KIT: hitstop + spark along the knockback (windup coil already fired)
	_hit_pause()
	_spark_burst(victim.global_position + Vector3(0, 1.0, 0), dir, roster[p].color, 1.0)
	if not _reduced_motion():
		_shake = maxf(_shake, 0.35)
	Sfx.play("splat", -3.0)
	_cap_event("shove")
	_log("shove p%d -> p%d gaze=%s gaze_t=%.2f" % [p, best, Gaze.keys()[gaze], gaze_t])


# ===========================================================================
# GRAB / BANK (A): channel a relic off the wake; deposit at your chest
# ===========================================================================
func _handle_grab(p: int, me: WGPawn, inp: Dictionary, delta: float) -> void:
	if not me.can_control():
		me.show_grab_progress(0.0)
		return
	var my2 := Vector2(me.global_position.x, me.global_position.z)
	# carrying: A near my chest banks it
	if carried[p] >= 0:
		me.show_grab_progress(0.0)
		if inp.grab and my2.distance_to(chest_pos(p)) <= BANK_RANGE:
			_do_bank(p)
		return
	# empty-handed: hold A near a relic to channel the lift
	if not inp.grab:
		me.grab_hold = 0.0
		me.grab_target = -1
		me.show_grab_progress(0.0)
		return
	var idx := _nearest_relic(my2, GRAB_RANGE)
	if idx < 0:
		me.grab_hold = 0.0
		me.grab_target = -1
		me.show_grab_progress(0.0)
		return
	if me.grab_target != idx:
		me.grab_target = idx
		me.grab_hold = 0.0
	me.grab_hold += delta
	var need: float = (relics[idx].node as WGRelic).grab_time()
	me.show_grab_progress(me.grab_hold / need)
	if me.grab_hold >= need:
		_do_grab(p, idx)


func _do_grab(p: int, idx: int) -> void:
	var me: WGPawn = players[p]
	me.grab_hold = 0.0
	me.grab_target = -1
	me.show_grab_progress(0.0)
	var r: Dictionary = relics[idx]
	r.state = RelicState.HELD
	r.holder = p
	carried[p] = idx
	var node := r.node as WGRelic
	node.set_held(true)
	me.carry_mult = node.carry_mult()
	me.set_carry_visual(true, node.tier == 2)
	Sfx.play("confirm", -4.0)
	_flash_ground_label(me.global_position, node.tier_name().to_upper(), node.tint())
	_cap_event("grab")
	_log("grab p%d relic=%d tier=%d value=%d" % [p, idx, node.tier, r.value])


func _drop_relic(p: int, at: Vector3) -> void:
	var idx: int = carried[p]
	if idx < 0:
		return
	var r: Dictionary = relics[idx]
	r.state = RelicState.FIELD
	r.holder = -1
	r.pos = Vector2(
		clampf(at.x, -ROOM_HALF_X + 0.8, ROOM_HALF_X - 0.8),
		clampf(at.z, ROOM_MIN_Z + 1.2, ROOM_MAX_Z - 2.0))
	carried[p] = -1
	var me: WGPawn = players[p]
	me.carry_mult = 1.0
	me.set_carry_visual(false)
	(r.node as WGRelic).set_held(false)
	_log("drop p%d relic=%d at=(%.1f,%.1f)" % [p, idx, r.pos.x, r.pos.y])


func _do_bank(p: int) -> void:
	var idx: int = carried[p]
	var r: Dictionary = relics[idx]
	var amount: int = r.value
	r.state = RelicState.BANKED
	r.holder = -1
	carried[p] = -1
	points[p] = int(points[p]) + amount
	_ev_banks += 1
	_ev_last_bank = [p, amount]
	var me: WGPawn = players[p]
	me.carry_mult = 1.0
	me.set_carry_visual(false)
	(r.node as WGRelic).visible = false
	# ceremony: chest glow + confetti + value pop
	var cp := chest_pos(p)
	var world := Vector3(cp.x, 0.4, cp.y)
	Sfx.play("sink", -4.0)
	_flash_ground_label(world + Vector3(0, 0.8, 0), "+%d" % amount, roster[p].color)
	_confetti(world + Vector3(0, 1.0, 0), roster[p].color)
	if p < chest_pads.size():
		var mat := (chest_pads[p] as MeshInstance3D).material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 3.2
			var tw := create_tween()
			tw.tween_property(mat, "emission_energy_multiplier", 0.9, 1.0)
	_rebuild_scoreboard()
	_cap_event("bank")
	_log("bank p%d relic=%d amount=%d total=%d" % [p, idx, amount, int(points[p])])
	# tie ceremony: first bank decides
	if phase == Phase.TIEBREAK and tie_players.has(p):
		if not _reduced_motion():
			_time_hit(0.25, 0.8)
			FinalStretch.fov_punch(cam, CAM_FOV, 6.0, 0.8)
		_finish_match(p)


# ===========================================================================
# Round / match end + THE TIE CEREMONY
# ===========================================================================
func _end_round(kind: String) -> void:
	# who leads?
	var best := -1
	for i in roster.size():
		if best < 0 or int(points[i]) > int(points[best]):
			best = i
	var tied: Array = []
	for i in roster.size():
		if int(points[i]) == int(points[best]):
			tied.append(i)
	_log("round_end kind=%s scores=%s tied=%d" % [kind, str(points), tied.size()])
	if tied.size() > 1:
		_begin_tiebreak(tied)
	else:
		_finish_match(best)


## THE TIE CEREMONY (doc 09 §C): tied players line the rope for ONE sudden-death
## grab — nearest relic, first to bank. The Widow cycles fast. Everyone else
## stands aside as mourners.
func _begin_tiebreak(tied: Array) -> void:
	phase = Phase.TIEBREAK
	phase_t = 0.0
	round_t = 0.0
	tie_players = tied
	escalated = true          # fast cycles + fake-outs stay armed
	gaze = Gaze.WEEPING
	gaze_t = 0.0
	green_dur = 1.6
	force_real = true         # first sudden-death sting is honest
	widow.weep(true)
	widow.set_gaze(false)
	_set_lights(false)
	gaze_label.visible = false
	# park everyone; tied players at the rope, the rest along the walls
	var lane := 0
	for i in roster.size():
		var me: WGPawn = players[i]
		if carried[i] >= 0:
			_drop_relic(i, me.global_position)
		if tied.has(i):
			var x: float = lerpf(-2.0, 2.0, float(lane) / maxf(1.0, tied.size() - 1.0)) if tied.size() > 1 else 0.0
			me.reset_for_round(Vector3(x, 0.1, SPAWN_Z), PI)
			lane += 1
		else:
			var side := -1.0 if i % 2 == 0 else 1.0
			me.reset_for_round(Vector3((ROOM_HALF_X - 0.9) * side, 0.1, 4.0), PI)
	# the prize: nearest remaining relic to mid-field; conjure a locket if bare
	tie_relic = _nearest_field_relic_to(Vector2(0, 0))
	if tie_relic < 0:
		tie_relic = _spawn_extra_relic(0, Vector2(0, 0.0))
	else:
		var r: Dictionary = relics[tie_relic]
		r.pos = Vector2(r.pos.x * 0.5, minf(r.pos.y * 0.5, -1.0))   # drag it toward centre stage
	var names: Array = []
	for i in tied:
		names.append(str(roster[i].name))
	_flash_banner("TIED — ONE LAST RELIC\n%s" % " vs ".join(names), Color(1, 0.85, 0.2), 3.0)
	Sfx.play("grudge", -2.0)
	_rebuild_scoreboard()
	_log("tiebreak players=%s relic=%d" % [str(tied), tie_relic])


func _finish_match(champ: int) -> void:
	phase = Phase.MATCH_END
	phase_t = 0.0
	_net_champ = champ
	var order: Array = range(roster.size())
	order.sort_custom(func(a, b):
		if int(points[a]) != int(points[b]):
			return int(points[a]) > int(points[b])
		if a == champ:
			return true
		if b == champ:
			return false
		return a < b)
	# the tiebreak winner must place first even if scores still read tied
	if order[0] != champ:
		order.erase(champ)
		order.push_front(champ)
	var champ_pl: Dictionary = roster[champ]
	if _stretch != null:
		_stretch.match_ended()
	# The bespoke persistent "INHERITS THE WAKE" banner + champ cheer are now the
	# ResultsBoard's protected winner beat (see the tail of this function). The
	# wake settles back to weeping either way.
	banner.visible = false
	widow.weep()
	widow.set_gaze(false)
	_set_lights(false)
	gaze_label.visible = false
	# highlights
	_highlights.clear()
	var mm := _dict_max(murders)
	if int(murders[mm]) >= 1:
		_highlights.append("%s fed %d mourner%s to the Widow" % [roster[mm].name,
			int(murders[mm]), "" if int(murders[mm]) == 1 else "s"])
	var cc := _dict_max(caught_count)
	if int(caught_count[cc]) >= 2:
		_highlights.append("The Widow took %s %d times" % [roster[cc].name, int(caught_count[cc])])
	if int(caught_count[champ]) == 0:
		_highlights.append("%s was never caught moving" % champ_pl.name)
	# monuments: The Widowmaker for 2+ shove-murders
	var monuments: Array = []
	for i in roster.size():
		if int(murders[i]) >= 2:
			monuments.append({"player": i, "kind": "widowmaker",
				"label": "%s, The Widowmaker" % roster[i].name})
			break
	# grudge: banked nothing all night
	for i in roster.size():
		if int(points[i]) == 0:
			_currency.append({"type": "grudge", "player": i, "amount": 1,
				"reason": "left the wake empty-handed"})
	_results = {
		"placements": order,
		"points": points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": _highlights.slice(0, 3),
		"monuments": monuments,
		"kill_events": _kill_events.duplicate(),
	}
	_cap_event("results")
	_log("match_end " + JSON.stringify(_results))
	print("KILL_EVENTS n=", _kill_events.size(), " ", JSON.stringify(_kill_events))
	# Headless assert (--wgtally) keeps the MATCH_END_HOLD path; everyone else gets
	# the staged final standings. _finish_match is host/standalone only (the mirror
	# stages its own champ moment from the `champ` fact), so no mirror guard needed.
	if not _tally_mode:
		_present_results_board(champ)


## Final standings via the shared ui_kit ResultsBoard (doc 14 §3, nit 5): freeze
## -> per-player banks count-up -> protected winner hero beat. The tie ceremony
## stays game-side (the TIEBREAK phase resolved before we got here); the winner's
## 3D cheer + confetti hang off the board's winner_beat seam.
func _present_results_board(champ: int) -> void:
	var panel := get_node_or_null("UI/ScorePanel")
	if panel:
		panel.visible = false   # the board is the standings now — no double list
	var rows: Array = []
	for p in _results.placements:
		var pidx := int(p)
		rows.append({
			"player": pidx,
			"score": int(points.get(pidx, 0)),
			"color": roster[pidx].color,
			"name": str(roster[pidx].name),
		})
	var board := ResultsBoard.new()
	add_child(board)
	_results_board = board
	_board_running = true
	board.winner_beat.connect(_on_results_winner)
	board.done.connect(func() -> void:
		if not _reported:
			_reported = true
			report_finished(_results))
	board.present(rows, {
		"title": "THE WILL IS READ",
		"subtitle": "MOST BANKED INHERITS THE WAKE",
		"score_type": ResultsBoard.ScoreType.POINTS,
		"win_title": "{name} INHERITS THE WAKE!",
		"accent": WIDOW_VIOLET,
	})


## The protected winner beat: the champion cheers, confetti falls (kept game-side
## via the board's signal seam). champ == placements[0] here (forced by _finish).
func _on_results_winner(champ: int) -> void:
	if champ < 0 or champ >= players.size():
		return
	Sfx.play("match_win")
	(players[champ] as WGPawn).cheer()
	_confetti((players[champ] as WGPawn).global_position + Vector3(0, 1.8, 0), roster[champ].color)
	if not _reduced_motion():
		_shake = maxf(_shake, 0.5)
	if _vc != null:
		get_tree().create_timer(0.35, true, false, true).timeout.connect(
			func() -> void: _vc.snap("wg_results"))


func _print_tally() -> void:
	print("WG_TALLY seed=%d banks=%d catches=%d murders=%d shoves=%d hits=%d stings=%d fakeouts=%d points=%s placements=%s" % [
		_cli_seed, _ev_banks, _ev_catches, _ev_murders, _ev_shoves, _ev_shove_hits,
		_ev_stings, _ev_fakeouts, JSON.stringify(points), str(_results.get("placements", []))])


# ===========================================================================
# Input / bots
# ===========================================================================
func _input_for(p: int, delta: float) -> Dictionary:
	if bot_enabled[p]:
		var d: Dictionary = bots.decide(p, self, delta)
		# bots stride at 87%: humans out-hustle them (spec: beatable), and
		# bot-only rounds stretch into the T-25 fake-out act instead of
		# stripping the wake clean at half time.
		d.move = (d.move as Vector2) * 0.87
		return d
	return {
		"move": PlayerInput.get_move(p),
		"grab": PlayerInput.is_down(p, "a"),
		"shove": PlayerInput.just_pressed(p, "b"),
		"pose": false,
	}


# ===========================================================================
# Relic helpers (also the bots' world API)
# ===========================================================================
func relic_available(i: int) -> bool:
	return relics[i].state == RelicState.FIELD and \
		(phase != Phase.TIEBREAK or i == tie_relic)


func relic_world_2d(i: int) -> Vector2:
	return relics[i].pos


func _nearest_relic(from: Vector2, within: float) -> int:
	var best := -1
	var best_d := within
	for i in relics.size():
		if not relic_available(i):
			continue
		var d: float = (relics[i].pos as Vector2).distance_to(from)
		if d < best_d:
			best_d = d
			best = i
	return best


func _nearest_field_relic_to(from: Vector2) -> int:
	var best := -1
	var best_d := 1e9
	for i in relics.size():
		if relics[i].state != RelicState.FIELD:
			continue
		var d: float = (relics[i].pos as Vector2).distance_to(from)
		if d < best_d:
			best_d = d
			best = i
	return best


func _all_relics_banked() -> bool:
	for r in relics:
		if r.state != RelicState.BANKED:
			return false
	return true


func _spawn_extra_relic(tier: int, at: Vector2) -> int:
	var node := WGRelic.new()
	add_child(node)
	node.build(tier)
	node.position = Vector3(at.x, 0.55, at.y)
	relics.append({"node": node, "tier": tier, "value": node.value(),
		"state": RelicState.FIELD, "pos": at, "holder": -1})
	return relics.size() - 1


func _update_relic_transforms() -> void:
	for r in relics:
		var node := r.node as WGRelic
		match int(r.state):
			RelicState.FIELD:
				node.visible = true
				var p2: Vector2 = r.pos
				node.position = Vector3(p2.x, 0.55, p2.y)
			RelicState.HELD:
				node.visible = true
				var holder: WGPawn = players[r.holder]
				var fwd := Vector3(sin(holder.yaw), 0, cos(holder.yaw))
				node.position = holder.global_position + Vector3(0, 1.35, 0) + fwd * 0.3
			RelicState.BANKED:
				node.visible = false


# ===========================================================================
# Geometry
# ===========================================================================
func chest_pos(i: int) -> Vector2:
	return Vector2(float(CHEST_XS[i % 4]), CHEST_Z)


func _spawn_pos(i: int) -> Vector3:
	return Vector3(float(CHEST_XS[i % 4]), 0.1, SPAWN_Z)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _roll(range_v: Vector2) -> float:
	return rng.randf_range(range_v.x, range_v.y)


func _dict_max(d: Dictionary) -> int:
	var best := 0
	for k in d:
		if int(d[k]) > int(d[best]):
			best = int(k)
	return best


# ===========================================================================
# HUD
# ===========================================================================
func _update_hud() -> void:
	pass   # scoreboard rebuilds on events; gaze label rides the state machine


func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	var order: Array = range(roster.size())
	order.sort_custom(func(a, b):
		if int(points[a]) != int(points[b]):
			return int(points[a]) > int(points[b])
		return a < b)
	for i in order:
		var pl: Dictionary = roster[i]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(i, 24)
		badge.color = pl.color
		hb.add_child(badge)
		var row := Label.new()
		var tag := ""
		if carried[i] >= 0:
			tag = "  +%d IN HAND" % int(relics[carried[i]].value)
		row.text = "%s  %d%s" % [pl.name, int(points[i]), tag]
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", pl.color)
		row.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
		row.add_theme_constant_override("outline_size", 5)
		hb.add_child(row)
		score_rows.add_child(hb)


func _flash_banner(text: String, color: Color, duration: float) -> void:
	banner.text = text
	_banner_col = color.to_html(false)
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.55, 0.55)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func() -> void: banner.visible = false)


## A small world-anchored Label3D pop (relic names, +N banks). Auto-frees.
func _flash_ground_label(at: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 24
	l.outline_modulate = Color(0.1, 0.08, 0.1)
	var lf: FontFile = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	if lf:
		l.font = lf
	add_child(l)
	l.global_position = at + Vector3(0, 1.8, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 0.9, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


# ===========================================================================
# Live-binding hint bar (real keys, house pattern)
# ===========================================================================
func _human_seats() -> Array:
	var out := []
	for i in roster.size():
		var idx := int(roster[i].get("index", i))
		if not bot_enabled[i] and PlayerInput.device_of(idx) != -99:
			out.append(idx)
	return out


## Seats whose bindings the hint bar prints: the live humans, or seat 0 as a
## representative when a bot-only demo has no humans — so the bar shows the SAME
## real key the intro card prints, never an abstract "A =" verb (notation nit).
func _hint_seats() -> Array:
	var seats := _human_seats()
	return seats if not seats.is_empty() else [0]


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


func _controls_bar() -> String:
	return "MOVE   ·   %s   ·   %s   |   FREEZE WHEN SHE TURNS" % [
		_btn_hint("a", "GRAB / BANK (hold)"), _btn_hint("b", "SHOVE")]


# ===========================================================================
# FX
# ===========================================================================
## HIT KIT §B1 Phase 2 hitstop: micro 0.15x for 45ms, one at a time. Reserved
## deep slow-mo lives in _time_hit for catches. Skipped in reduced-motion.
func _hit_pause() -> void:
	if _slowmo or _reduced_motion():
		return
	_slowmo = true
	var base := _fast if _fast > 1.0 else 1.0
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = base
	_slowmo = false


## Catch slow-mo: ordinary 0.5x/0.2s, deciding 0.25x/0.8s (doc 09 §B).
func _time_hit(scale: float, dur: float) -> void:
	if _slowmo or _reduced_motion():
		return
	_slowmo = true
	var base := _fast if _fast > 1.0 else 1.0
	Engine.time_scale = scale
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = base
	_slowmo = false


func _reduced_motion() -> bool:
	return not bool(PartySetup.pref("screen_shake", true))


## SPECTRAL LIGHTNING — a jagged emissive bolt from the Widow's eyes to the
## victim, plus a spark nova at the impact. Segments freed after a beat.
func _lightning_to(target: Vector3) -> void:
	var from: Vector3 = widow.global_position + Vector3(0, 1.85, 0.2)
	var segs := 6
	var holder := Node3D.new()
	add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.65, 0.85, 1.0)
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var prev := from
	for i in range(1, segs + 1):
		var k := float(i) / float(segs)
		var pt := from.lerp(target, k)
		if i < segs:
			pt += Vector3(fx_rng.randf_range(-0.5, 0.5), fx_rng.randf_range(-0.35, 0.35),
				fx_rng.randf_range(-0.5, 0.5))
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.09, prev.distance_to(pt))
		seg.mesh = bm
		seg.material_override = mat
		holder.add_child(seg)
		seg.global_position = (prev + pt) * 0.5
		if prev.distance_to(pt) > 0.01:
			seg.look_at(pt, Vector3.UP)
		prev = pt
	# impact nova
	var p := CPUParticles3D.new()
	holder.add_child(p)
	p.global_position = target
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3.ZERO
	var pm := BoxMesh.new()
	pm.size = Vector3(0.1, 0.1, 0.1)
	p.mesh = pm
	p.material_override = mat
	get_tree().create_timer(0.16, true, false, true).timeout.connect(
		func() -> void:
			for c in holder.get_children():
				if c is MeshInstance3D:
					(c as MeshInstance3D).visible = false)
	get_tree().create_timer(0.7).timeout.connect(holder.queue_free)


## HIT KIT §B1 spark burst — cone of sparks along the knockback direction.
func _spark_burst(pos: Vector3, dir: Vector3, color: Color, strength := 1.0) -> void:
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


func _confetti(pos: Vector3, color: Color) -> void:
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
		p.initial_velocity_min = 3.5
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
		get_tree().create_timer(2.2).timeout.connect(p.queue_free)


## Exact-pitch voice pool (Sfx wobbles pitch; ladders + sobs need exact steps).
func _play_pitched(pitch: float, db: float, sob := false) -> void:
	if _tick_players.is_empty():
		for i in 4:
			var p := AudioStreamPlayer.new()
			p.bus = "SFX"
			add_child(p)
			_tick_players.append(p)
	if _tick_stream == null:
		var bank: Dictionary = Sfx.BANK
		if bank.has("card") and not (bank["card"] as Array).is_empty():
			_tick_stream = Sfx._load_sample(str(bank["card"][0]))
	if _sob_stream == null:
		var bank2: Dictionary = Sfx.BANK
		if bank2.has("grudge") and not (bank2["grudge"] as Array).is_empty():
			_sob_stream = Sfx._load_sample(str(bank2["grudge"][0]))
	var stream := _sob_stream if sob else _tick_stream
	if stream == null:
		return
	var p: AudioStreamPlayer = _tick_players[_tick_next]
	_tick_next = (_tick_next + 1) % _tick_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


# ===========================================================================
# Lighting — the lights DROP when she watches (the room-read for RED)
# ===========================================================================
func _set_lights(watching: bool, instant := false) -> void:
	var dur := 0.01 if instant else (0.14 if watching else 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sun, "light_energy", 0.22 if watching else _sun_warm, dur)
	if _env:
		tw.tween_property(_env, "ambient_light_energy", 0.12 if watching else _amb_warm, dur)
		tw.tween_property(_env, "ambient_light_color",
			Color(0.55, 0.22, 0.28) if watching else Color(1.0, 0.88, 0.72), dur)
	# the candles and lamps ARE the parlor's light — they gutter when she turns
	for i in _warm_lights.size():
		tw.tween_property(_warm_lights[i], "light_energy",
			float(_warm_energies[i]) * (0.22 if watching else 1.0), dur)


# ===========================================================================
# World build — THE PARLOR
# ===========================================================================
func _build_world() -> void:
	# environment: candlelit mourning parlor, glow so the relics bloom
	_env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.05, 0.045, 0.08)
	sky_mat.sky_horizon_color = Color(0.14, 0.10, 0.12)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.05)
	sky_mat.ground_horizon_color = Color(0.10, 0.08, 0.10)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1.0, 0.88, 0.72)
	_env.ambient_light_energy = _amb_warm
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.15
	_env.glow_hdr_threshold = 0.92
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	sun.rotation_degrees = Vector3(-52, 24, 0)
	sun.light_energy = _sun_warm
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.shadow_enabled = true

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, -140, 0)
	fill.light_energy = 0.25
	fill.light_color = Color(0.7, 0.65, 0.9)
	add_child(fill)

	_build_floor()
	_build_walls()
	_build_wake_end()      # coffin + bier + relic pedestals + candles
	_build_rope_end()      # velvet rope + memorial chests
	_build_furniture()     # psychological cover, floor stays readable
	_build_relics()

	# the Widow herself — ONE node; a Meshy model swap is one line in wg_widow.gd
	widow = WGWidow.new()
	widow.name = "Widow"
	add_child(widow)
	widow.build()
	widow.global_position = WIDOW_POS

	# camera: whole parlor in frame from the rope end, Widow deep upstage
	cam.position = Vector3(0, 16.5, 18.5)
	cam.look_at(Vector3(0, 0.4, -1.6))
	cam.fov = CAM_FOV
	_cam_base = cam.global_transform


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fshape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(ROOM_HALF_X * 2.0, 0.4, ROOM_MAX_Z - ROOM_MIN_Z)
	fshape.shape = fbox
	fshape.position = Vector3(0, -0.2, (ROOM_MAX_Z + ROOM_MIN_Z) * 0.5)
	floor_body.add_child(fshape)
	var fmesh := MeshInstance3D.new()
	var fbm := BoxMesh.new()
	fbm.size = fbox.size
	fmesh.mesh = fbm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.20, 0.14, 0.11)   # dark parquet
	fmat.roughness = 0.8
	fmesh.material_override = fmat
	fmesh.position = fshape.position
	floor_body.add_child(fmesh)
	add_child(floor_body)
	# the mourning runner — a long dark-red carpet lane down the middle
	var runner := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(4.2, 0.02, ROOM_MAX_Z - ROOM_MIN_Z - 3.0)
	runner.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.30, 0.08, 0.10)
	rmat.roughness = 0.95
	runner.material_override = rmat
	runner.position = Vector3(0, 0.012, (ROOM_MAX_Z + ROOM_MIN_Z) * 0.5)
	add_child(runner)


func _build_walls() -> void:
	var t := 0.4
	var h := 3.2
	var length := ROOM_MAX_Z - ROOM_MIN_Z
	var midz := (ROOM_MAX_Z + ROOM_MIN_Z) * 0.5
	var specs := [
		[Vector3(0, h * 0.5, ROOM_MIN_Z), Vector3(ROOM_HALF_X * 2.0, h, t)],
		[Vector3(0, h * 0.5, ROOM_MAX_Z), Vector3(ROOM_HALF_X * 2.0, h, t)],
		[Vector3(-ROOM_HALF_X, h * 0.5, midz), Vector3(t, h, length)],
		[Vector3(ROOM_HALF_X, h * 0.5, midz), Vector3(t, h, length)],
	]
	for s in specs:
		var pos: Vector3 = s[0]
		var sz: Vector3 = s[1]
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.position = pos
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sz
		cs.shape = box
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.12, 0.15)   # funeral wallpaper
		mat.roughness = 0.85
		mi.material_override = mat
		body.add_child(mi)
		# wainscoting trim
		var trim := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(sz.x + 0.05, 0.14, sz.z + 0.05)
		trim.mesh = tm
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.32, 0.24, 0.16)
		tmat.roughness = 0.6
		trim.material_override = tmat
		trim.position.y = -h * 0.5 + 0.9
		body.add_child(trim)
		add_child(body)


func _build_wake_end() -> void:
	# bier + coffin (dark box, gold trim, slightly raised) — collides
	var bier := StaticBody3D.new()
	bier.collision_layer = 1
	bier.position = COFFIN_POS
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 1.1, 1.5)
	cs.shape = box
	cs.position.y = 0.55
	bier.add_child(cs)
	var base := MeshInstance3D.new()
	var basem := BoxMesh.new()
	basem.size = Vector3(3.0, 0.5, 1.2)
	base.mesh = basem
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.12, 0.10, 0.13)
	bmat.roughness = 0.7
	base.material_override = bmat
	base.position.y = 0.25
	bier.add_child(base)
	var coffin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(3.2, 0.55, 1.3)
	coffin.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.22, 0.12, 0.10)
	cmat.roughness = 0.4
	cmat.metallic = 0.1
	coffin.material_override = cmat
	coffin.position.y = 0.78
	bier.add_child(coffin)
	var lid_trim := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(3.26, 0.07, 1.36)
	lid_trim.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.85, 0.68, 0.2)
	lmat.metallic = 0.85
	lmat.roughness = 0.3
	lmat.emission_enabled = true
	lmat.emission = Color(0.6, 0.45, 0.1)
	lmat.emission_energy_multiplier = 0.3
	lid_trim.material_override = lmat
	lid_trim.position.y = 1.06
	bier.add_child(lid_trim)
	add_child(bier)

	# candelabra light pools flanking the coffin
	for sx in [-2.6, 2.6]:
		var candle := OmniLight3D.new()
		candle.light_color = Color(1.0, 0.75, 0.4)
		candle.light_energy = 1.6
		candle.omni_range = 5.0
		candle.position = Vector3(sx, 1.8, COFFIN_POS.z + 0.4)
		add_child(candle)
		_warm_lights.append(candle)
		_warm_energies.append(candle.light_energy)
		var stick := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.05
		sm.bottom_radius = 0.12
		sm.height = 1.5
		stick.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.75, 0.62, 0.25)
		smat.metallic = 0.8
		smat.roughness = 0.35
		stick.material_override = smat
		stick.position = Vector3(sx, 0.75, COFFIN_POS.z + 0.4)
		add_child(stick)
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.07
		fm.height = 0.18
		flame.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(1.0, 0.8, 0.3)
		fmat.emission_enabled = true
		fmat.emission = Color(1.0, 0.7, 0.2)
		fmat.emission_energy_multiplier = 3.0
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.material_override = fmat
		flame.position = Vector3(sx, 1.62, COFFIN_POS.z + 0.4)
		add_child(flame)

	# low relic pedestals under each relic spot (visual, no collider)
	for spec in RELIC_LAYOUT:
		var ped := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.42
		pm.bottom_radius = 0.5
		pm.height = 0.22
		ped.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.16, 0.13, 0.17)
		pmat.roughness = 0.7
		ped.material_override = pmat
		ped.position = Vector3(float(spec[1]), 0.11, float(spec[2]))
		add_child(ped)


func _build_rope_end() -> void:
	# the velvet rope: posts + sagging red cord across the room (visual only)
	var posts := 5
	for i in posts:
		var x := lerpf(-ROOM_HALF_X + 0.8, ROOM_HALF_X - 0.8, float(i) / float(posts - 1))
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.06
		pm.bottom_radius = 0.09
		pm.height = 1.0
		post.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.8, 0.66, 0.25)
		pmat.metallic = 0.85
		pmat.roughness = 0.3
		post.material_override = pmat
		post.position = Vector3(x, 0.5, ROPE_Z)
		add_child(post)
		if i > 0:
			var px := lerpf(-ROOM_HALF_X + 0.8, ROOM_HALF_X - 0.8, float(i - 1) / float(posts - 1))
			var cord := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.035
			cyl.bottom_radius = 0.035
			cyl.height = absf(x - px)
			cord.mesh = cyl
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.55, 0.12, 0.15)
			cmat.roughness = 0.9
			cord.material_override = cmat
			cord.rotation.z = PI * 0.5
			cord.position = Vector3((x + px) * 0.5, 0.82, ROPE_Z)
			add_child(cord)

	# memorial chests (player-colored; pads tinted in _tint_chest)
	chest_pads.clear()
	for i in 4:
		var c := chest_pos(i)
		var pad := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = BANK_RANGE * 0.8
		pm.bottom_radius = BANK_RANGE * 0.8
		pm.height = 0.04
		pad.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.6, 0.6)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.5, 0.5)
		mat.emission_energy_multiplier = 0.9
		pad.material_override = mat
		pad.position = Vector3(c.x, 0.03, c.y)
		add_child(pad)
		chest_pads.append(pad)
		# the chest box itself against the back wall
		var chest := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.1, 0.7, 0.7)
		chest.mesh = bm
		var chm := StandardMaterial3D.new()
		chm.albedo_color = Color(0.24, 0.17, 0.12)
		chm.roughness = 0.6
		chest.material_override = chm
		chest.position = Vector3(c.x, 0.35, ROOM_MAX_Z - 0.75)
		add_child(chest)
		var lid := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(1.14, 0.16, 0.74)
		lid.mesh = lm
		lid.material_override = chm
		lid.position = Vector3(c.x, 0.78, ROOM_MAX_Z - 0.75)
		lid.rotation.x = -0.25
		add_child(lid)


func _tint_chest(i: int, color: Color) -> void:
	if i >= chest_pads.size():
		return
	var mat := (chest_pads[i] as MeshInstance3D).material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = color
		mat.emission = color
		mat.emission_energy_multiplier = 0.9


func _build_furniture() -> void:
	# scattered mourning furniture — PSYCHOLOGICAL cover (no colliders, spec):
	# armchairs + lamps off the main lanes so the floor stays readable
	var chair_glb := "res://assets/models/meshy/armchair.glb"
	var lamp_glb := "res://assets/models/meshy/table_lamp.glb"
	var chairs := [
		[Vector3(-4.6, 0, 1.6), 115.0], [Vector3(4.6, 0, 0.2), -110.0],
		[Vector3(-4.4, 0, -3.4), 80.0], [Vector3(4.5, 0, -3.0), -75.0],
		[Vector3(-3.0, 0, 4.6), 145.0], [Vector3(3.2, 0, 4.2), -140.0],
	]
	for spec in chairs:
		if ResourceLoader.exists(chair_glb):
			var vis := MeshyProp.instance(chair_glb, 1.15, float(spec[1]))
			vis.position = spec[0]
			add_child(vis)
		else:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.9, 1.0, 0.9)
			mi.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.25, 0.14, 0.16)
			mat.roughness = 0.9
			mi.material_override = mat
			mi.position = (spec[0] as Vector3) + Vector3(0, 0.5, 0)
			add_child(mi)
	var lamps := [Vector3(-5.2, 0, -0.9), Vector3(5.2, 0, 2.2)]
	for lp in lamps:
		if ResourceLoader.exists(lamp_glb):
			var vis := MeshyProp.instance(lamp_glb, 1.4)
			vis.position = lp
			add_child(vis)
		var gl := OmniLight3D.new()
		gl.light_color = Color(1.0, 0.8, 0.5)
		gl.light_energy = 0.9
		gl.omni_range = 3.5
		gl.position = lp + Vector3(0, 1.5, 0)
		add_child(gl)
		_warm_lights.append(gl)
		_warm_energies.append(gl.light_energy)


func _build_relics() -> void:
	relics.clear()
	for spec in RELIC_LAYOUT:
		var tier := int(spec[0])
		var node := WGRelic.new()
		add_child(node)
		node.build(tier)
		var pos := Vector2(float(spec[1]), float(spec[2]))
		node.position = Vector3(pos.x, 0.55, pos.y)
		relics.append({"node": node, "tier": tier, "value": node.value(),
			"state": RelicState.FIELD, "pos": pos, "holder": -1})


# ===========================================================================
# Config / args
# ===========================================================================
func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--wgbots":
			_bots_all = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--roundtime="):
			_cli_roundtime = float(arg.trim_prefix("--roundtime="))
		elif arg == "--wgtally":
			_tally_mode = true
		elif arg.begins_with("--wgfast="):
			_fast = clampf(float(arg.trim_prefix("--wgfast=")), 1.0, 10.0)
		elif arg == "--wgcap":
			_cap_on = true
		elif arg.begins_with("--outdir="):
			_cap_dir = arg.trim_prefix("--outdir=")
	if _cap_on:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _cap_dir))


func _default_config() -> Dictionary:
	var n := _cli_players
	PlayerInput.auto_assign(n)
	var r: Array = []
	for i in n:
		r.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": CHAR_FALLBACKS[i],
			"device": PlayerInput.device_of(i),
			"bot": PlayerInput.standalone_bot_default(i),
		})
	return {"roster": r, "rounds": 1, "rng_seed": _cli_seed, "practice": false}


# ===========================================================================
# Screenshot capture (--wgcap, event/state based; windowed)
# ===========================================================================
func _cap_event(tag: String) -> void:
	if not _cap_on or _cap_done.has(tag):
		return
	_cap_done[tag] = true
	# hold the shot a beat so lightning/sparks/banners are on screen
	# (results waits for the banner pop to finish its back-ease)
	var delay := 0.6 if tag == "results" else 0.12
	get_tree().create_timer(delay, true, false, true).timeout.connect(
		func() -> void: _grab_shot(tag))


func _capture_beats() -> void:
	# green-phase mid-heist baseline once bodies are downfield
	if not _cap_done.has("green") and gaze == Gaze.WEEPING and round_t > 6.0:
		var downfield := 0
		for p in players:
			if (p as WGPawn).global_position.z < 4.0:
				downfield += 1
		if downfield >= 2:
			_cap_done["green"] = true
			_grab_shot("green")
	# the whip-turn itself (red, eyes on, room dimmed)
	if not _cap_done.has("red") and gaze == Gaze.WATCHING and gaze_t > 0.15:
		_cap_done["red"] = true
		_grab_shot("red")
	# quit once the arc is on film, or safety timeout
	var have_all: bool = _cap_done.has("green") and _cap_done.has("red") \
		and _cap_done.has("catch") and _cap_done.has("murder") and _cap_done.has("results")
	if (have_all or game_t > 110.0) and not _cap_done.has("_quit"):
		_cap_done["_quit"] = true
		get_tree().create_timer(1.4, true, false, true).timeout.connect(
			func() -> void:
				print("WG_CAP_DONE have=%s" % str(_cap_done.keys()))
				get_tree().quit())


func _grab_shot(tag: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/widows_gaze_%s.png" % [_cap_dir, tag]
		img.save_png(path)
		print("WG_CAP ", path)
	else:
		print("WG_CAP_SKIP_HEADLESS ", tag)


# ===========================================================================
# ONLINE PHASE 2 — the render mirror (house pattern per greed.gd §4.3)
# ===========================================================================

## HOST, pumped by the estate at 20 Hz. PUBLIC facts only.
func _net_state() -> Dictionary:
	var pp: Array = []
	for i in roster.size():
		var pl: WGPawn = players[i]
		pp.append(snappedf(pl.global_position.x, 0.01))
		pp.append(snappedf(pl.global_position.z, 0.01))
		pp.append(snappedf(pl.yaw, 0.01))
		pp.append(1 if pl.horizontal_speed() > 0.6 else 0)
		pp.append(1 if pl.is_caught() else 0)
		pp.append(snappedf(pl.shove_cd, 0.02))
		pp.append(snappedf(pl.grab_hold, 0.02))
		pp.append(carried[i])
	var pts: Array = []
	for i in roster.size():
		pts.append(int(points[i]))
	var rel: Array = []
	for r in relics:
		rel.append(int(r.state))
		rel.append(snappedf((r.pos as Vector2).x, 0.01))
		rel.append(snappedf((r.pos as Vector2).y, 0.01))
	return {
		"ph": phase,
		"tmr": timer_label.text,
		"hv": hint_label.visible,
		"ban": [banner.text, _banner_col, banner.visible],
		"gz": gaze,
		"fake": 1 if sting_fake else 0,
		"seq": sting_seq,
		"esc": 1 if escalated else 0,
		"p": pp,
		"pts": pts,
		"rel": rel,
		"ev": [_ev_catches, _ev_murders, _ev_shove_hits, _ev_banks],
		"lc": _ev_last_catch,
		"lb": _ev_last_bank,
		"champ": _net_champ,
	}


## CLIENT. Latest-state-wins; all juice fires from DELTAS vs the previous
## snapshot, so a dropped packet loses nothing but frames.
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()
	phase = (int(state.get("ph", phase))) as Phase
	_apply_mir_timer(str(state.get("tmr", "")), str(prev.get("tmr", "")))
	hint_label.visible = bool(state.get("hv", hint_label.visible))
	_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	# --- the gaze, mirrored: sting ladder + whip + lights from state deltas
	var pgz := int(prev.get("gz", Gaze.WEEPING))
	var gz := int(state.get("gz", Gaze.WEEPING))
	var fake := int(state.get("fake", 0)) == 1
	if gz != pgz:
		gaze = gz as Gaze
		match gz:
			Gaze.STING:
				sting_fake = fake
				_sting_notes_played = 0
				gaze_t = 0.0
				if fake:
					widow.fakeout_turn(STING_TIME)
				else:
					widow.whip_turn(STING_TIME)
				# the remote seat NEEDS the warning: play the same 3-note ladder
				# locally (fake's falling third note included — same tell)
				var lt := create_tween()
				lt.tween_callback(_play_pitched.bind(0.9, -4.0))
				lt.tween_interval(0.18)
				lt.tween_callback(_play_pitched.bind(1.15, -4.0))
				lt.tween_interval(0.18)
				lt.tween_callback(_play_pitched.bind(0.72 if fake else 1.45, -4.0))
			Gaze.WATCHING:
				widow.set_gaze(true)
				_set_lights(true)
				Sfx.play("bumper", -4.0)
				gaze_label.text = "SHE  WATCHES"
				gaze_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
				gaze_label.visible = true
			Gaze.WEEPING:
				widow.weep()
				widow.set_gaze(false)
				_set_lights(false)
				gaze_label.visible = false
	if int(state.get("esc", 0)) == 1 and int(prev.get("esc", 0)) == 0 and _stretch != null:
		_stretch.escalate()
	# --- per-seat resyncs + one-shot deltas
	var pp: Array = state.get("p", [])
	var ppp: Array = prev.get("p", [])
	for i in players.size():
		var b := i * 8
		if b + 7 >= pp.size():
			break
		var pl: WGPawn = players[i]
		var scd := float(pp[b + 5])
		var pscd := float(ppp[b + 5]) if b + 5 < ppp.size() else 0.0
		if scd - pscd > 1.5:               # shove fired host-side this window
			pl.do_shove_swing()
		if absf(pl.shove_cd - scd) > 0.1:
			pl.shove_cd = scd
		var tgh := float(pp[b + 6])
		if tgh <= 0.0:
			_mir_gh[i] = 0.0
		elif absf(_mir_gh[i] - tgh) > 0.08:
			_mir_gh[i] = tgh
		carried[i] = int(pp[b + 7])
	# --- scoreboard facts
	if state.get("pts", []) != prev.get("pts", []):
		var pts: Array = state.get("pts", [])
		for i in mini(pts.size(), players.size()):
			points[i] = int(pts[i])
		_rebuild_scoreboard()
	# --- relic sync (state + pos; held relics ride the pawn transform)
	var rel: Array = state.get("rel", [])
	for k in relics.size():
		var b2 := k * 3
		if b2 + 2 >= rel.size():
			break
		var r: Dictionary = relics[k]
		r.state = int(rel[b2]) as RelicState
		r.pos = Vector2(float(rel[b2 + 1]), float(rel[b2 + 2]))
		r.holder = -1
		for i in players.size():
			if carried[i] == k:
				r.holder = i
	_update_relic_transforms()
	# --- event-counter juice (catch / murder / shove-hit / bank)
	_mir_event_juice(state, prev)
	# --- the champion moment
	if phase == Phase.MATCH_END and not _mir_champ_done:
		var champ := int(state.get("champ", -1))
		if champ >= 0 and champ < players.size():
			_mir_champ_done = true
			if _stretch != null:
				_stretch.match_ended()
			(players[champ] as WGPawn).cheer()
			_confetti((players[champ] as WGPawn).global_position + Vector3(0, 1.8, 0),
				roster[champ].color)
			if not _reduced_motion():
				_shake = maxf(_shake, 0.5)


func _apply_mir_timer(tmr: String, _ptmr: String) -> void:
	if tmr == timer_label.text:
		return
	timer_label.text = tmr
	if not tmr.is_valid_int():
		return
	var remain := int(tmr)
	timer_label.add_theme_color_override("font_color",
		Color(1, 0.3, 0.2) if remain <= 10 else Color(1, 0.92, 0.6))
	if _stretch != null:
		_stretch.tick(float(remain))


func _apply_mir_banner(arr: Array, parr: Array) -> void:
	if arr.size() < 3:
		return
	banner.text = str(arr[0])
	banner.add_theme_color_override("font_color", Color(str(arr[1])))
	var was: bool = parr.size() >= 3 and bool(parr[2]) and str(parr[0]) == str(arr[0])
	banner.visible = bool(arr[2])
	if banner.visible and not was:
		banner.pivot_offset = banner.size / 2.0
		banner.scale = Vector2(0.55, 0.55)
		var pop := create_tween()
		pop.tween_property(banner, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mir_event_juice(state: Dictionary, prev: Dictionary) -> void:
	var ev: Array = state.get("ev", [])
	var pev: Array = prev.get("ev", [0, 0, 0, 0])
	if ev.size() < 4:
		return
	while pev.size() < 4:
		pev.append(0)
	# CATCH — lightning at the victim (banner rides the state)
	if int(ev[0]) > int(pev[0]):
		var lc: Array = state.get("lc", [-1, -1])
		var v := int(lc[0])
		if v >= 0 and v < players.size():
			var vp: WGPawn = players[v]
			_lightning_to(vp.global_position + Vector3(0, 1.0, 0))
			vp.flash_pop()
			vp.get_caught(_spawn_pos(v))
		Sfx.play("crush", -2.0)
		Sfx.play("death", -6.0)
		if not _reduced_motion():
			_shake = maxf(_shake, 0.5)
		_time_hit(0.5, 0.2)
	# SHOVE HIT — spark + pop on the wire
	if int(ev[2]) > int(pev[2]):
		Sfx.play("splat", -3.0)
		_hit_pause()
	# BANK — the little ceremony
	if int(ev[3]) > int(pev[3]):
		var lb: Array = state.get("lb", [-1, 0])
		var p := int(lb[0])
		if p >= 0 and p < players.size():
			var cpos := chest_pos(p)
			var world := Vector3(cpos.x, 0.4, cpos.y)
			Sfx.play("sink", -4.0)
			_flash_ground_label(world + Vector3(0, 0.8, 0), "+%d" % int(lb[1]), roster[p].color)
			_confetti(world + Vector3(0, 1.0, 0), roster[p].color)


## CLIENT, per physics tick: pawn glide + grab-ring fill + relic transforms.
## The weeping sobs play locally off the mirrored gaze fact (GREEN is heard).
func _mirror_tick(delta: float) -> void:
	if _mir.is_empty():
		return
	if gaze == Gaze.WEEPING and phase == Phase.PLAY:
		_sob_t -= delta
		if _sob_t <= 0.0:
			_sob_t = SOB_PERIOD
			_play_pitched(0.5, -20.0, true)
	var pp: Array = _mir.get("p", [])
	for i in players.size():
		var b := i * 8
		if b + 7 >= pp.size():
			break
		var pl: WGPawn = players[i]
		pl.net_pose(delta, Vector3(float(pp[b]), 0.1, float(pp[b + 1])),
			float(pp[b + 2]), int(pp[b + 3]) == 1, int(pp[b + 4]) == 1,
			int(pp[b + 7]) >= 0)
		if float(pp[b + 6]) > 0.0:
			_mir_gh[i] = minf(_mir_gh[i] + delta, 1.0)
			pl.show_grab_progress(_mir_gh[i] / 0.85)
		else:
			pl.show_grab_progress(0.0)
	_update_relic_transforms()


# ===========================================================================
func _log(msg: String) -> void:
	var f := -1
	if _vc != null:
		f = int(_vc.frame)
	print("WG_EVT t=%.2f frame=%d | %s" % [game_t, f, msg])


func _unhandled_input(event: InputEvent) -> void:
	if _standalone and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
