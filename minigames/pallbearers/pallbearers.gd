extends Minigame
## PALLBEARERS — the anthology's first TEAM game. A 2v2 coffin race down a
## graveyard lane to the crypt: everyone is late for the funeral.
##
## CARRY: a pair carries one coffin. Its movement is the BLEND of BOTH carriers'
## sticks — pull apart and the coffin crawls and lists; sync and it sprints.
## DROP: diverge too hard for too long, or clip a hazard, and the coffin drops
## and THE DECEASED SPILLS OUT (complaining in the voice-bible register while
## both carriers MASH to stuff them back in). HAZARDS: mud (slow + slip), a
## swinging cemetery gate on a timer, a mourner procession crossing the lane, and
## a downhill stretch where a dropped coffin RUNS AWAY (chase it). First coffin
## into the crypt wins; if time expires, the closest wins.
##
## THE TWIST (house style): each carrier can HOP (the jump button). A SOLO hop
## jostles your own coffin — a lopsided lurch that can nudge you over a mud lip
## but spikes divergence. A SYNCED hop (both, same beat) is a HEAVE: it clears
## mud, bursts forward, and re-settles the carry. And a hop clatters loud enough
## to tempt the other team into looking over at the wrong moment.
##
## Anthology module contract: root of minigames/pallbearers/pallbearers.tscn,
## extends Minigame. Self-starts a 4-player all-bot demo 0.5s after _ready if
## begin() is not called first. Host-authoritative online mirror via
## _net_state()/_net_apply() (docs/design/10, greed/widows precedent).
##
## CLI user args (after --):
##   --pallbearerbots     all seats are seeded self-play bots
##   --pallbearertest     headless deterministic bot soak -> PB_TALLY + quit
##   --seed=N             rng seed (default 1); receipt is byte-identical per seed
##   --players=N          standalone roster size 2..4
##   --roundtime=S        override the round clock (verification)
##   --pallbearercap      event/state screenshots -> verify_out, then quit
##   --outdir=DIR         output dir for --pallbearercap (default verify_out)

const PBCarrierS := preload("res://minigames/pallbearers/pb_carrier.gd")
const PBCoffinS := preload("res://minigames/pallbearers/pb_coffin.gd")
const PBBotsS := preload("res://minigames/pallbearers/pb_bots.gd")

enum Phase { WAITING, INTRO, PLAY, MATCH_END }
enum TeamPhase { CARRY, DROPPED, RUNAWAY, RESTUFF, DONE }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

# ---- the lane (coffins travel from the funeral start at +Z to the crypt at -Z) ----
const START_Z := 14.5
const CRYPT_Z := -16.0
const TEAM_X := [-4.5, 4.5]          # lane centres
const LANE_HALF := 2.4               # coffin x stays within centre ± this
const TEAM_ACCENT := [Color(0.9, 0.74, 0.34), Color(0.66, 0.78, 0.95)]  # brass / silver
const CARRY_Y := 0.95                # shoulder-height while carried
const DROP_Y := 0.24                 # on the gravel when dropped

# ---- carry tuning (all speeds m/s, times s) ----
const MAX_SPEED := 3.6
const ACCEL := 14.0
const FRICTION := 12.0
const DIV_GAIN := 0.9                # divergence gained per second at full opposition
const DIV_RECOVER := 0.7             # divergence bled per second when carrying smooth
const MUD_SLIP := 0.28               # divergence gained per second in mud
const DROP_DIV := 1.0                # divergence at which the coffin drops
const HOP_CD := 0.9
const HOP_SYNC := 0.16               # both hops within this window = a HEAVE
const HOP_BURST := 2.4               # forward impulse from a heave
const SOLO_JOLT := 0.22              # divergence spike from a lopsided solo hop
const HEAVE_CLEAR := 0.4             # divergence cleared by a synced heave
const RESTUFF_NEED := 14.0           # combined mashes to reseat the deceased (a
                                    # drop is a real setback; the dead stay out ~1.4s)
const MASH_CD := 0.12
const NEAR_COFFIN := 1.35            # carrier within this of its coffin end = restuffing

# ---- hazards ----
const MUD_ZONES := [8.6, 2.4]        # z centres (both lanes), half-length below
const MUD_HALF := 1.7
const GATE_Z := -1.5
const GATE_PERIOD := 4.2
const GATE_CLOSED := 0.55            # closed_frac above this = the bar is across the lane
const GATE_BAND := 1.1
const MOURNER_Z := -6.2
const MOURNER_PERIOD := 8.5
const MOURNER_CROSS := 0.55          # fraction of the period spent traversing
const MOURNER_W := 1.7               # half-width the procession occupies at any moment
const MOURNER_SAFE := 1.6            # coffin speed below this = a soft block, above = a drop
const DOWN_Z0 := -9.5                # downhill band (drop here and the coffin runs)
const DOWN_Z1 := -14.5
const RUNAWAY_SPEED := 5.5
const RUNAWAY_DECAY := 3.2

# ---- round ----
const ROUND_TIME := 110.0
const INTRO_TIME := 1.6
const MATCH_END_HOLD := 8.0
const CAM_FOV := 56.0

const GAME_INTRO := {
	"name": "PALLBEARERS",
	"goal": "Carry the pall to the crypt first. You share one coffin — steer together or drop the dead.",
	"accent": Color(0.9, 0.74, 0.34),
	"controls": [
		{"action": "move", "label": "CARRY (both steer)"},
		{"action": "jump", "label": "HOP / HEAVE"},
		{"action": "a", "label": "RESTUFF (mash)"},
	],
	"tips": [
		"The coffin moves on the BLEND of both sticks. Pull the same way to sprint.",
		"Both hop on the same beat to HEAVE over mud. Hop alone and you jostle the dead.",
		"Drop on the downhill and the coffin bolts for the crypt without you. Chase it.",
	],
}

# THE DECEASED — pooled complaints, voice-bible register (administrative; death is
# paperwork; the institution never exclaims).
const COMPLAINTS := [
	"In my day, the dead were carried by professionals.",
	"I have been to livelier funerals. All of them, in fact.",
	"You have dropped me before the mourners. Note it for the record.",
	"I did not survive three wars to be spilled on the gravel.",
	"One does not rush a man to his own eternity.",
	"The crypt is thataway. It has not moved. Unlike me.",
	"Handle with care. I am, technically, still management.",
	"The paperwork on a second death is considerable. Do try to avoid it.",
	"Feet first is traditional. Face first is a choice.",
	"If I wanted to be jostled, I would have taken the bus.",
	"I was promised a dignified exit. This is neither.",
	"Mind the upholstery. It is the only thing here with dignity.",
]
const GRUMBLES := ["Was that necessary.", "I felt that.", "Please refrain.", "Noted.", "Mind the corners."]
const RESEAT_LINES := ["Continue.", "As you were.", "Carry on, then.", "Adequate."]

# ---- roster / config ----
var roster: Array = []
var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()
var practice := false
var round_time := ROUND_TIME

# ---- sim state ----
var carriers: Array = []             # 4 slot dicts (see _build_teams)
var teams: Array = []                # 2 team dicts
var phase: Phase = Phase.WAITING
var phase_t := 0.0
var round_t := 0.0
var game_t := 0.0
var winner_team := -1
var _finish_order: Array = []        # team ids in finish order (first = winner)

var points := {}
var _currency: Array = []
var _highlights: Array = []
var _results := {}

var bots
var bot_enabled: Array = []          # per slot
var _begun := false
var _reported := false
var _standalone := false
var _no_juice := false               # true in tally: no Engine.time_scale so the sim is byte-stable

# ui_kit
var _intro_card: IntroCard = null
var _results_board: ResultsBoard = null
var _board_running := false
var _stretch: FinalStretch = null

# CLI
var _cli_seed := 1
var _cli_players := 4
var _cli_roundtime := -1.0
var _bots_all := false
var _tally_mode := false
var _cap_on := false
var _cap_dir := "verify_out"
var _cap_done := {}

# juice
var _shake := 0.0
var _cam_base: Transform3D
var _slowmo := false
var _vc: Node = null
var _banner_col := "ffffff"
var _env_rig := {}

# gate / mourner visuals
var _gate_nodes: Array = []          # per lane: the swinging bar Node3D
var _mourner_node: Node3D = null
var _mourner_left: Node3D = null
var _mourner_right: Node3D = null

# tally
var _ev_drops := [0, 0]
var _ev_gate := [0, 0]
var _ev_mourner := [0, 0]
var _ev_heaves := [0, 0]
var _last_status := 0.0

# ---- ONLINE mirror (host pumps _net_state @20Hz; client feeds _net_apply) ----
var _mirror := false
var _mir := {}
var _net_winner := -1
var _mir_champ_done := false

# HUD
var _prog_bars: Array = []           # per team: {bg, fill, label}

@onready var cam: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var ui: CanvasLayer = $UI
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var banner: Label = $UI/Banner
@onready var hint_label: Label = $UI/HintLabel


# ===========================================================================
# Lifecycle
# ===========================================================================
func _ready() -> void:
	_parse_args()
	_vc = get_node_or_null("/root/VerifyCapture")
	_build_world()
	banner.visible = false
	timer_label.text = ""
	round_label.text = "PALLBEARERS"
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
	fx_rng.seed = int(config.rng_seed) + 8231
	practice = bool(config.get("practice", false))
	_no_juice = _tally_mode
	if _cli_roundtime > 0.0:
		round_time = clampf(_cli_roundtime, 15.0, 240.0)
	_stretch = FinalStretch.attach(self, timer_label)
	_build_teams(config)
	_build_hud()
	hint_label.text = _controls_bar()
	if _mirror:
		phase = Phase.WAITING
		print("PB_MIRROR boot teams=2 carriers=%d my_seat=%d" % [carriers.size(), NetSession.my_seat()])
		return
	bots = PBBotsS.new()
	bots.setup(int(config.rng_seed) ^ 0x5AC0, carriers.size())
	if _cap_on:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _cap_dir))
	_log("begin roster=%d seed=%d tally=%s" % [roster.size(), int(config.rng_seed), str(_tally_mode)])
	if _tally_mode:
		_start_round()
	else:
		_present_intro_card()


func _present_intro_card() -> void:
	_intro_card = IntroCard.new()
	add_child(_intro_card)
	_intro_card.started.connect(_start_round)
	var spec: Dictionary = GAME_INTRO.duplicate(true)
	spec["seats"] = _human_seats()
	if _cap_on:
		spec["auto_secs"] = 2.4               # cap runs are all-bot; don't dwell
	_intro_card.present(spec)
	if _cap_on:
		get_tree().create_timer(1.2, true, false, true).timeout.connect(
			func() -> void: _grab_shot("intro"))
	elif _vc != null:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _vc.snap("pb_intro"))


func _start_round() -> void:
	phase = Phase.INTRO
	phase_t = 0.0
	round_t = 0.0
	_last_status = 0.0
	_reset_all_teams()
	_flash_banner("LATE FOR THE FUNERAL", Color(0.9, 0.86, 0.7), 1.4)
	hint_label.visible = true
	var tw := create_tween()
	tw.tween_interval(8.0)
	tw.tween_callback(func() -> void: hint_label.visible = false)
	_log("round_start time=%.0f" % round_time)


# ===========================================================================
# Main loop
# ===========================================================================
## The sim runs on a FIXED timestep, fully decoupled from wall-clock: sim state
## is a pure function of the seed and the number of steps taken, so the receipt
## is byte-identical run to run regardless of frame rate or time_scale. The
## headless tally soaks by running SOAK_STEPS fixed sub-steps per physics tick
## (12x faster real-time, identical math). Windowed play runs one step per tick.
const FIXED_DT := 1.0 / 60.0
const SOAK_STEPS := 12

func _physics_process(delta: float) -> void:
	if _mirror:
		game_t += delta
		_mirror_tick(delta)
		return
	if phase == Phase.WAITING:
		return
	var steps := SOAK_STEPS if _tally_mode else 1
	for _i in steps:
		if phase == Phase.WAITING:
			break
		game_t += FIXED_DT
		phase_t += FIXED_DT
		_sim_frame(FIXED_DT)


func _sim_frame(delta: float) -> void:
	match phase:
		Phase.INTRO:
			_pin_all_idle(delta)
			if phase_t >= INTRO_TIME:
				phase = Phase.PLAY
				round_t = 0.0
				_flash_banner("CARRY THE PALL", TEAM_ACCENT[0].lerp(TEAM_ACCENT[1], 0.5), 1.0)
				Sfx.play("bell_toll", -4.0)
				if _stretch != null:
					_stretch.play_started()
		Phase.PLAY:
			round_t += delta
			_tick_play(delta)
		Phase.MATCH_END:
			_pin_all_idle(delta)
			if _cap_on:
				_capture_beats()
			if not _board_running and phase_t >= MATCH_END_HOLD and not _reported:
				_reported = true
				report_finished(_results)
				if _tally_mode:
					_print_tally()
					get_tree().quit()


func _tick_play(delta: float) -> void:
	# hazards advance first (deterministic, game_t driven)
	_tick_gate(delta)
	_tick_mourners(delta)
	# each team in index order
	for t in teams.size():
		var team: Dictionary = teams[t]
		if int(team.phase) == TeamPhase.DONE:
			continue
		if int(team.phase) == TeamPhase.CARRY:
			_carry_step(t, delta)
		else:
			_dropped_step(t, delta)
	_update_hud()
	if _cap_on:
		_capture_beats()
	# round end: someone reached the crypt, or the clock ran out
	if winner_team >= 0:
		_finish_match(winner_team)
	elif round_t >= round_time:
		_finish_match(_closest_team())


func _process(delta: float) -> void:
	if phase == Phase.WAITING and not _mirror:
		return
	cam.global_transform = _cam_base
	if _shake > 0.002:
		_shake = maxf(0.0, _shake - delta * 1.4)
		cam.position += Vector3(fx_rng.randf_range(-1, 1), fx_rng.randf_range(-1, 1),
			fx_rng.randf_range(-1, 1)) * _shake * 0.35
	# HUD timer (host); the mirror rides the snapshot
	if not _mirror:
		if phase == Phase.PLAY:
			var remain := int(ceil(maxf(0.0, round_time - round_t)))
			timer_label.text = str(remain)
			timer_label.add_theme_color_override("font_color",
				Color(1, 0.3, 0.2) if remain <= 10 else Color(1, 0.92, 0.6))
			if _stretch != null:
				_stretch.tick(round_time - round_t)
		elif phase == Phase.INTRO:
			timer_label.text = str(int(round_time))
		elif phase != Phase.MATCH_END:
			timer_label.text = ""


# ===========================================================================
# THE CARRY — the blended, coordinated step (the heart of the game)
# ===========================================================================
func _carry_step(t: int, delta: float) -> void:
	var team: Dictionary = teams[t]
	team.grace = maxf(0.0, float(team.grace) - delta)
	var invuln := float(team.grace) > 0.0
	var fs: int = team.slots[0]
	var bs: int = team.slots[1]
	var inp_f: Dictionary = _carrier_input(fs, team, delta)
	var inp_b: Dictionary = _carrier_input(bs, team, delta)
	var s0: Vector2 = inp_f.move
	var s1: Vector2 = inp_b.move

	# the BLEND + how much the carriers agree
	var pair := (s0 + s1) * 0.5
	var a0 := s0.length() > 0.15
	var a1 := s1.length() > 0.15
	var agree := 1.0
	if a0 and a1:
		agree = s0.normalized().dot(s1.normalized())
	elif a0 or a1:
		agree = 0.2                              # one pulling, one slack: sluggish
	var sync := clampf((agree + 1.0) * 0.5, 0.0, 1.0)
	var speed_factor := clampf(0.15 + sync * 0.85, 0.15, 1.0)

	# mud
	var in_mud := _z_in_mud(float(team.pos2.y))
	var mud_factor := 0.5 if in_mud else 1.0
	if in_mud:
		team.mud_time = float(team.mud_time) + delta

	# HOPS — the twist. Fire per carrier, detect a synced heave.
	var heaved := _resolve_hops(t, fs, bs, bool(inp_f.hop), bool(inp_b.hop))

	# target velocity (stick.y = -1 is forward toward the crypt / -Z)
	var target := pair * MAX_SPEED * speed_factor * mud_factor
	team.vel2 = (team.vel2 as Vector2).move_toward(target,
		(ACCEL if target.length() > 0.05 else FRICTION) * delta)
	if heaved:
		var fwd := (team.vel2 as Vector2)
		if fwd.length() < 0.1:
			fwd = Vector2(0, -1)
		team.vel2 = (team.vel2 as Vector2) + fwd.normalized() * HOP_BURST

	# advance + clamp to the lane
	var pos: Vector2 = team.pos2
	pos += (team.vel2 as Vector2) * delta
	var cx: float = TEAM_X[t]
	pos.x = clampf(pos.x, cx - LANE_HALF, cx + LANE_HALF)
	pos.y = clampf(pos.y, CRYPT_Z - 0.2, START_Z + 0.5)
	team.pos2 = pos
	if (team.vel2 as Vector2).length() > 0.3:
		var dir2: Vector2 = (team.vel2 as Vector2).normalized()
		team.heading = lerp_angle(float(team.heading), atan2(dir2.x, dir2.y),
			1.0 - exp(-9.0 * delta))

	# DIVERGENCE — the drop clock
	var div_rate := 0.0
	if a0 and a1:
		div_rate += (1.0 - sync) * DIV_GAIN
	if in_mud:
		div_rate += MUD_SLIP
	if sync > 0.72 and (team.vel2 as Vector2).length() > 0.5:
		div_rate -= DIV_RECOVER
	if invuln:
		div_rate = minf(div_rate, -2.5)          # fresh grip bleeds instability fast
	team.div = clampf(float(team.div) + div_rate * delta, 0.0, 1.0)

	# smoothness bookkeeping (the individual flourish)
	_accum_smooth(fs, sync)
	_accum_smooth(bs, sync)

	# lift the coffin to shoulder height
	team.coffin_y = lerpf(float(team.coffin_y), CARRY_Y, 1.0 - exp(-10.0 * delta))
	_place_team_carry(t, delta, sync)

	# HAZARD drops (order: hard collisions, then the divergence clock). A fresh
	# grip (grace) is briefly drop-immune so a coffin can escape the mud it fell in.
	if not invuln and _gate_hits(t):
		_ev_gate[t] += 1
		_drop_team(t, "gate")
	elif not invuln and _mourner_hits(t):
		_ev_mourner[t] += 1
		_drop_team(t, "mourner")
	elif not invuln and float(team.div) >= DROP_DIV:
		_drop_team(t, "diverge")
	elif float(team.pos2.y) <= CRYPT_Z:
		_team_finish(t)


## Fire hops with per-carrier cooldowns; both within HOP_SYNC = a HEAVE.
func _resolve_hops(t: int, fs: int, bs: int, hop_f: bool, hop_b: bool) -> bool:
	var team: Dictionary = teams[t]
	var heaved := false
	for slot in [fs, bs]:
		var c: Dictionary = carriers[slot]
		var want := hop_f if slot == fs else hop_b
		if not want or float(c.hop_cd) > 0.0:
			continue
		c.hop_cd = HOP_CD
		c.hop_time = game_t
		(c.node as PBCarrier).hop()
		Sfx.play("impact_wood", -6.0, 0.12)
		var other: int = bs if slot == fs else fs
		var od: Dictionary = carriers[other]
		if game_t - float(od.hop_time) <= HOP_SYNC:
			# SYNCED HEAVE — clears divergence, forward burst
			team.div = maxf(0.0, float(team.div) - HEAVE_CLEAR)
			heaved = true
			_ev_heaves[t] += 1
			Sfx.play("whoosh_big", -7.0)
		else:
			# SOLO JOLT — lopsided lurch; +divergence, small lateral kick
			team.div = clampf(float(team.div) + SOLO_JOLT, 0.0, 1.0)
			var kick := 1.0 if fx_rng.randf() < 0.5 else -1.0
			team.vel2 = (team.vel2 as Vector2) + Vector2(kick * 0.9, 0.0)
			if fx_rng.randf() < 0.5:
				(team.coffin as PBCoffin).say(GRUMBLES[rng.randi_range(0, GRUMBLES.size() - 1)], 1.4)
	return heaved


# ===========================================================================
# THE DROP / RESTUFF / RUNAWAY
# ===========================================================================
func _drop_team(t: int, cause: String) -> void:
	var team: Dictionary = teams[t]
	_ev_drops[t] = int(_ev_drops[t]) + 1
	team.drops = int(team.drops) + 1
	team.vel2 = Vector2.ZERO
	team.div = 0.0
	team.restuff = 0.0
	(team.coffin as PBCoffin).spill()
	(team.coffin as PBCoffin).say(COMPLAINTS[rng.randi_range(0, COMPLAINTS.size() - 1)], 2.8)
	# carriers stumble back a step
	for slot in team.slots:
		(carriers[slot].node as PBCarrier).stumble()
	Sfx.play("thud_coffin", -2.0)
	Sfx.play("crush", -8.0)
	if not _reduced_motion() and not _no_juice:
		_shake = maxf(_shake, 0.4)
		_time_hit(0.4, 0.22)
	# a drop on the downhill = a RUNAWAY
	if float(team.pos2.y) <= DOWN_Z0 and float(team.pos2.y) >= DOWN_Z1 + -2.0:
		team.phase = TeamPhase.RUNAWAY
		team.runaway = RUNAWAY_SPEED
		Sfx.play("chain", -4.0)
	else:
		team.phase = TeamPhase.DROPPED
	_cap_event("drop")
	_log("drop team=%d cause=%s z=%.1f runaway=%s" % [t, cause, float(team.pos2.y),
		str(int(team.phase) == TeamPhase.RUNAWAY)])


func _dropped_step(t: int, delta: float) -> void:
	var team: Dictionary = teams[t]
	team.coffin_y = lerpf(float(team.coffin_y), DROP_Y, 1.0 - exp(-9.0 * delta))
	# runaway slide (downhill, toward the crypt), decaying
	if int(team.phase) == TeamPhase.RUNAWAY:
		var pos: Vector2 = team.pos2
		pos.y -= float(team.runaway) * delta                 # toward crypt (-Z)
		pos.x += sin(game_t * 3.0 + t) * 0.4 * delta * float(team.runaway)  # veers
		pos.y = maxf(pos.y, CRYPT_Z + 0.6)                   # a spilled coffin can't enter the crypt
		team.pos2 = pos
		team.runaway = maxf(0.0, float(team.runaway) - RUNAWAY_DECAY * delta)
		if float(team.runaway) < 0.6:
			team.phase = TeamPhase.DROPPED
	_place_team_dropped(t, delta)

	# both carriers must be at the coffin to stuff the deceased home
	var both_near := _carriers_near_coffin(t)
	if both_near and int(team.phase) == TeamPhase.DROPPED:
		team.phase = TeamPhase.RESTUFF
	# process carrier inputs (bot decisions + fold mashes into the restuff meter)
	for slot in team.slots:
		_carrier_input(int(slot), team, delta)
	if int(team.phase) == TeamPhase.RESTUFF:
		(team.coffin as PBCoffin).set_restuff(float(team.restuff) / RESTUFF_NEED)
		if float(team.restuff) >= RESTUFF_NEED:
			_reseat_team(t)


func _reseat_team(t: int) -> void:
	var team: Dictionary = teams[t]
	team.phase = TeamPhase.CARRY
	team.restuff = 0.0
	team.div = 0.0
	team.grace = 1.4                     # a fresh grip: brief drop-immunity so a
	team.restuffs = int(team.restuffs) + 1   # coffin can escape the mud it fell in
	(team.coffin as PBCoffin).reseat()
	(team.coffin as PBCoffin).say(RESEAT_LINES[rng.randi_range(0, RESEAT_LINES.size() - 1)], 1.6)
	Sfx.play("confirm", -3.0)
	_log("reseat team=%d z=%.1f" % [t, float(team.pos2.y)])


func _team_finish(t: int) -> void:
	var team: Dictionary = teams[t]
	team.phase = TeamPhase.DONE
	team.pos2 = Vector2(float(TEAM_X[t]), CRYPT_Z)
	team.finish_tick = game_t
	_finish_order.append(t)
	if winner_team < 0:
		winner_team = t
	Sfx.play("bell_toll", -1.0)
	_cap_event("finish")
	_log("finish team=%d t=%.2f" % [t, game_t])


# ===========================================================================
# Carrier input (human or bot) + mash folding
# ===========================================================================
func _carrier_input(slot: int, team: Dictionary, delta: float) -> Dictionary:
	var c: Dictionary = carriers[slot]
	c.hop_cd = maxf(0.0, float(c.hop_cd) - delta)
	c.mash_cd = maxf(0.0, float(c.mash_cd) - delta)
	var out: Dictionary
	if bool(bot_enabled[slot]):
		var partner: int = int(team.slots[0]) if slot == int(team.slots[1]) else int(team.slots[1])
		var ps: Vector2 = _last_stick.get(partner, Vector2.ZERO)
		var ph: bool = not bool(bot_enabled[partner]) and int(carriers[partner].roster_index) >= 0
		out = bots.decide(slot, self, delta, ps, ph)
	else:
		var idx: int = int(c.roster_index)
		out = {
			"move": PlayerInput.get_move(idx),
			"hop": PlayerInput.just_pressed(idx, "jump"),
			"mash": PlayerInput.just_pressed(idx, "a"),
		}
	_last_stick[slot] = out.move
	# fold a mash into the team's restuff meter (rate-limited so it reads frantic)
	if bool(out.get("mash", false)) and float(c.mash_cd) <= 0.0 \
			and int(team.phase) == TeamPhase.RESTUFF and _carrier_near_coffin(slot):
		c.mash_cd = MASH_CD
		team.restuff = minf(RESTUFF_NEED, float(team.restuff) + 1.0)
		(c.node as PBCarrier).mash_pump()
		Sfx.play("impact_light", -10.0, 0.15)
		if fx_rng.randf() < 0.22:
			(team.coffin as PBCoffin).say(GRUMBLES[rng.randi_range(0, GRUMBLES.size() - 1)], 1.2)
	return out

var _last_stick: Dictionary = {}


# ===========================================================================
# Placement of coffins + carriers (visual, derived from sim state)
# ===========================================================================
func _place_team_carry(t: int, delta: float, sync: float) -> void:
	var team: Dictionary = teams[t]
	var pos: Vector2 = team.pos2
	var yaw: float = team.heading
	var coffin: PBCoffin = team.coffin
	coffin.global_position = Vector3(pos.x, float(team.coffin_y), pos.y)
	coffin.rotation.y = yaw
	# sway telegraphs instability: divergence + a little from raw speed
	coffin.drive(delta, float(team.div), game_t)
	var dir2 := Vector2(sin(yaw), cos(yaw))          # travel direction in (x,z)
	var half := PBCoffin.LEN * 0.5 + 0.35
	var moving := (team.vel2 as Vector2).length() > 0.4
	_drive_carrier(int(team.slots[0]), delta, pos + dir2 * half, yaw, moving, 1.0)     # front bearer
	_drive_carrier(int(team.slots[1]), delta, pos - dir2 * half, yaw, moving, 1.0)     # back bearer


func _place_team_dropped(t: int, delta: float) -> void:
	var team: Dictionary = teams[t]
	var pos: Vector2 = team.pos2
	var coffin: PBCoffin = team.coffin
	coffin.global_position = Vector3(pos.x, float(team.coffin_y), pos.y)
	coffin.drive(delta, 0.15, game_t)
	var yaw: float = team.heading
	var dir2 := Vector2(sin(yaw), cos(yaw))
	var half := PBCoffin.LEN * 0.5 + 0.35
	# carriers walk toward their coffin ends (chase a runaway)
	for i in 2:
		var slot: int = int(team.slots[i])
		var end := pos + dir2 * (half if i == 0 else -half)
		var c: Dictionary = carriers[slot]
		var cur: Vector2 = c.pos2
		var to := end - cur
		var step := 4.2 * delta
		var np := cur + to.normalized() * minf(step, to.length()) if to.length() > 0.05 else end
		c.pos2 = np
		var moving := to.length() > 0.15
		var fy := atan2(to.x, to.y) if moving else yaw
		(c.node as PBCarrier).drive(delta, Vector3(np.x, 0.1, np.y), fy, moving, 0.0)


func _drive_carrier(slot: int, delta: float, at: Vector2, yaw: float, moving: bool, grip: float) -> void:
	var c: Dictionary = carriers[slot]
	c.pos2 = at
	(c.node as PBCarrier).drive(delta, Vector3(at.x, 0.1, at.y), yaw, moving, grip)


func _pin_all_idle(delta: float) -> void:
	for t in teams.size():
		var team: Dictionary = teams[t]
		if int(team.phase) == TeamPhase.CARRY or int(team.phase) == TeamPhase.DONE:
			_place_team_carry(t, delta, 1.0)
		else:
			_place_team_dropped(t, delta)


# ===========================================================================
# Hazards
# ===========================================================================
func _tick_gate(_delta: float) -> void:
	var frac := _gate_closed_frac()
	for lane in _gate_nodes.size():
		var bar: Node3D = _gate_nodes[lane]
		# swing the bar across the lane (0 open = along the fence, 1 closed = across)
		bar.rotation.y = lerpf(-1.35, 0.02, frac)
	# a warn creak as it starts to close
	if frac > 0.45 and frac < 0.5:
		Sfx.play("creak", -10.0)


func _gate_closed_frac() -> float:
	var p := fmod(game_t, GATE_PERIOD) / GATE_PERIOD
	return (sin(p * TAU - PI * 0.5) + 1.0) * 0.5      # smooth open->closed->open


func _gate_hits(t: int) -> bool:
	var z: float = float(teams[t].pos2.y)
	return absf(z - GATE_Z) < GATE_BAND and _gate_closed_frac() > GATE_CLOSED


## For bots: is a closing gate just ahead of this coffin? Bots cut it close
## (greedy) — they only hold when the bar is nearly across and they are right on
## it, so a fraction of approaches get clipped as it swings shut.
func gate_blocks_ahead(t: int) -> bool:
	var z: float = float(teams[t].pos2.y)
	if z <= GATE_Z + 0.2:
		return false                                 # already past
	return z - GATE_Z < 1.7 and _gate_closed_frac() > 0.52


func _tick_mourners(_delta: float) -> void:
	if _mourner_node == null:
		return
	var q := _mourner_phase()
	_mourner_node.visible = q >= 0.0
	if q >= 0.0 and _mourner_left != null:
		# two lines converge from both verges toward the centre — SYMMETRIC, so
		# neither lane is favoured (a single sweep always reaches one lane first)
		_mourner_left.position = Vector3(lerpf(-9.0, 0.0, q), 0.0, MOURNER_Z)
		_mourner_right.position = Vector3(lerpf(9.0, 0.0, q), 0.0, MOURNER_Z)


## Crossing progress q in [0,1), or -1 when the transept is clear.
func _mourner_phase() -> float:
	var p := fmod(game_t, MOURNER_PERIOD) / MOURNER_PERIOD
	if p > MOURNER_CROSS:
		return -1.0
	return p / MOURNER_CROSS


## The procession front on lane t's side (symmetric), or a far sentinel when clear.
func _mourner_front(t: int) -> float:
	var q := _mourner_phase()
	if q < 0.0:
		return -999.0
	return lerpf(-9.0, 0.0, q) if float(TEAM_X[t]) < 0.0 else lerpf(9.0, 0.0, q)


func _mourner_hits(t: int) -> bool:
	var fx := _mourner_front(t)
	if fx < -900.0:
		return false
	var pos: Vector2 = teams[t].pos2
	if absf(pos.y - MOURNER_Z) > 1.2:
		return false
	if absf(pos.x - fx) > MOURNER_W:
		return false
	# fast into the grievers = a drop; slow = a soft block (handled in mourner_block)
	return (teams[t].vel2 as Vector2).length() > MOURNER_SAFE


## For bots: 0 clear .. 1 must stop, for a procession about to sweep the coffin.
func mourner_block(t: int) -> float:
	var fx := _mourner_front(t)
	if fx < -900.0:
		return 0.0
	var pos: Vector2 = teams[t].pos2
	if pos.y < MOURNER_Z - 0.5 or absf(pos.y - MOURNER_Z) > 4.0:
		return 0.0
	var dx: float = absf(pos.x - fx)
	return clampf(1.0 - dx / (MOURNER_W + 1.6), 0.0, 1.0)


func _z_in_mud(z: float) -> bool:
	for mz in MUD_ZONES:
		if absf(z - float(mz)) < MUD_HALF:
			return true
	return false


# ===========================================================================
# Bot world API (read-only accessors)
# ===========================================================================
func slot_team(slot: int) -> int:
	return int(carriers[slot].team)

func team_phase(t: int) -> int:
	return int(teams[t].phase)

func coffin_pos2(t: int) -> Vector2:
	return teams[t].pos2

func carrier_pos2(slot: int) -> Vector2:
	return carriers[slot].pos2

func lane_center_x(t: int) -> float:
	return float(TEAM_X[t])

func team_in_mud(t: int) -> bool:
	return _z_in_mud(float(teams[t].pos2.y))

func hop_window(t: int) -> bool:
	# a short, shared, deterministic beat while in mud so both bots heave together
	if not _z_in_mud(float(teams[t].pos2.y)):
		return false
	return int(game_t * 60.0) % 42 < 2


# ===========================================================================
# Round / match end
# ===========================================================================
func _closest_team() -> int:
	# smallest coffin z (nearest the crypt) wins on a timeout
	return 0 if float(teams[0].pos2.y) <= float(teams[1].pos2.y) else 1


func _finish_match(champ_team: int) -> void:
	phase = Phase.MATCH_END
	phase_t = 0.0
	winner_team = champ_team
	_net_winner = champ_team
	if _stretch != null:
		_stretch.match_ended()
	banner.visible = false
	# losers set the pall down
	for slot in carriers.size():
		if int(carriers[slot].team) != champ_team:
			(carriers[slot].node as PBCarrier).slump()
	_build_results(champ_team)
	_log("match_end winner_team=%d " % champ_team + JSON.stringify(_results))
	if not _tally_mode:
		_present_results_board()


func _build_results(champ_team: int) -> void:
	# roster players, ordered: winning team first, then by carry smoothness desc
	var order: Array = []
	for slot in carriers.size():
		if int(carriers[slot].roster_index) >= 0:
			order.append(slot)
	order.sort_custom(func(a, b):
		var ta := int(carriers[a].team) == champ_team
		var tb := int(carriers[b].team) == champ_team
		if ta != tb:
			return ta
		if absf(_smooth(a) - _smooth(b)) > 0.0001:
			return _smooth(a) > _smooth(b)
		return int(carriers[a].roster_index) < int(carriers[b].roster_index))
	var placements: Array = []
	for slot in order:
		placements.append(int(carriers[slot].roster_index))
	# DISPLAY points: a fair pair mapping (winners 4, losers 1). NOTE: the shell
	# (estate_state.apply_results) awards party currency strictly by PLACEMENT
	# RANK [5,3,2,1] and ignores this dict — so the fair team outcome is expressed
	# by placing BOTH winners ahead of BOTH losers; the smoothest-carrier tiebreak
	# only decides the 5-vs-3 / 2-vs-1 split within a pair. (LOGGED per brief.)
	points.clear()
	for slot in carriers.size():
		var ri := int(carriers[slot].roster_index)
		if ri >= 0:
			points[ri] = 4 if int(carriers[slot].team) == champ_team else 1
	# spite economy: grudge for fumblers, royalty + monument for the steadiest hands
	_currency.clear()
	for t in teams.size():
		var d := int(teams[t].drops)
		if d <= 0:
			continue
		for slot in teams[t].slots:
			var ri := int(carriers[slot].roster_index)
			if ri >= 0:
				_currency.append({"type": "grudge", "player": ri, "amount": mini(d, 3),
					"reason": "spilled the deceased %d time%s" % [d, "" if d == 1 else "s"]})
	var steady := _steadiest_roster()
	var monuments: Array = []
	if steady >= 0:
		_currency.append({"type": "royalty", "player": steady, "amount": 1,
			"reason": "the steadiest hands at the wake"})
		monuments.append({"player": steady, "kind": "steady_hand",
			"label": "%s, The Steady Hand" % _name_of(steady)})
	# highlights
	_highlights.clear()
	if not placements.is_empty():
		_highlights.append("%s carried the pall home first" % _team_name(champ_team))
	var worst := _most_drops_roster()
	if worst >= 0 and int(_drops_of_roster(worst)) >= 2:
		_highlights.append("%s fumbled the coffin %d times" % [_name_of(worst), _drops_of_roster(worst)])
	if steady >= 0 and _smooth(_slot_of_roster(steady)) > 0.9:
		_highlights.append("%s never lost their grip" % _name_of(steady))

	_results = {
		"placements": placements,
		"points": points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": _highlights.slice(0, 3),
		"monuments": monuments,
		"kill_events": [],
	}


func _present_results_board() -> void:
	for pb in _prog_bars:
		(pb.bg as Control).visible = false
	var rows: Array = []
	for ri in _results.placements:
		var slot := _slot_of_roster(int(ri))
		rows.append({
			"player": int(ri),
			"score": int(points.get(int(ri), 0)),
			"color": carriers[slot].color,
			"name": str(carriers[slot].name),
			"callout": "STEADY" if _steadiest_roster() == int(ri) else "",
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
		"title": "THE PALL IS SET DOWN",
		"subtitle": "FIRST TO THE CRYPT INHERITS THE PLOT",
		"score_type": ResultsBoard.ScoreType.POINTS,
		"win_title": "{name} SETS DOWN THE PALL FIRST",
		"accent": TEAM_ACCENT[winner_team if winner_team >= 0 else 0],
	})


func _on_results_winner(champ: int) -> void:
	if champ < 0:
		return
	Sfx.play("match_win")
	var slot := _slot_of_roster(champ)
	if slot >= 0:
		var team := int(carriers[slot].team)
		for s in carriers.size():
			if int(carriers[s].team) == team:
				(carriers[s].node as PBCarrier).cheer()
		_confetti((carriers[slot].node as PBCarrier).global_position + Vector3(0, 1.8, 0),
			carriers[slot].color)
	if not _reduced_motion():
		_shake = maxf(_shake, 0.5)
	if _cap_on:
		get_tree().create_timer(0.6, true, false, true).timeout.connect(
			func() -> void: _cap_done.erase("results"); _grab_shot("results"); _cap_done["results"] = true)
	elif _vc != null:
		get_tree().create_timer(0.35, true, false, true).timeout.connect(
			func() -> void: _vc.snap("pb_results"))


func _print_tally() -> void:
	var sm: Array = []
	for slot in carriers.size():
		if int(carriers[slot].roster_index) >= 0:
			sm.append("%s=%.2f" % [str(carriers[slot].name), _smooth(slot)])
	print("PB_TALLY seed=%d winner_team=%d finish_t=%.2f drops=%s gate=%s mourner=%s heaves=%s smooth=[%s] points=%s placements=%s" % [
		_cli_seed, winner_team,
		(float(teams[winner_team].finish_tick) if winner_team >= 0 and float(teams[winner_team].finish_tick) > 0.0 else round_t),
		str(_ev_drops), str(_ev_gate), str(_ev_mourner), str(_ev_heaves),
		", ".join(sm), JSON.stringify(points), str(_results.get("placements", []))])


# ===========================================================================
# Smoothness / roster helpers
# ===========================================================================
func _accum_smooth(slot: int, sync: float) -> void:
	var c: Dictionary = carriers[slot]
	c.smooth_sum = float(c.smooth_sum) + sync
	c.smooth_n = int(c.smooth_n) + 1

func _smooth(slot: int) -> float:
	var c: Dictionary = carriers[slot]
	return float(c.smooth_sum) / maxf(1.0, float(c.smooth_n))

func _steadiest_roster() -> int:
	var best := -1
	var best_s := -1.0
	for slot in carriers.size():
		if int(carriers[slot].roster_index) < 0:
			continue
		var s := _smooth(slot)
		if s > best_s:
			best_s = s
			best = int(carriers[slot].roster_index)
	return best

func _most_drops_roster() -> int:
	var best := -1
	var best_d := -1
	for slot in carriers.size():
		var ri := int(carriers[slot].roster_index)
		if ri < 0:
			continue
		var d := _drops_of_roster(ri)
		if d > best_d:
			best_d = d
			best = ri
	return best

func _drops_of_roster(ri: int) -> int:
	var slot := _slot_of_roster(ri)
	if slot < 0:
		return 0
	return int(teams[int(carriers[slot].team)].drops)

func _slot_of_roster(ri: int) -> int:
	for slot in carriers.size():
		if int(carriers[slot].roster_index) == ri:
			return slot
	return -1

func _name_of(ri: int) -> String:
	var slot := _slot_of_roster(ri)
	return str(carriers[slot].name) if slot >= 0 else "P%d" % (ri + 1)

func _team_name(t: int) -> String:
	var names: Array = []
	for slot in carriers.size():
		if int(carriers[slot].team) == t and int(carriers[slot].roster_index) >= 0:
			names.append(str(carriers[slot].name))
	if names.is_empty():
		return "THE %s PALL" % ("BRASS" if t == 0 else "SILVER")
	return " & ".join(names)


func _carrier_near_coffin(slot: int) -> bool:
	var c: Dictionary = carriers[slot]
	var t := int(c.team)
	return (c.pos2 as Vector2).distance_to(teams[t].pos2) < NEAR_COFFIN + PBCoffin.LEN * 0.5

func _carriers_near_coffin(t: int) -> bool:
	for slot in teams[t].slots:
		if not _carrier_near_coffin(int(slot)):
			return false
	return true


# ===========================================================================
# Build: teams, HUD, world
# ===========================================================================
func _build_teams(config: Dictionary) -> void:
	carriers.clear()
	teams.clear()
	bot_enabled.clear()
	# 4 carrier slots: 0,1 = team0 front/back; 2,3 = team1 front/back
	for slot in 4:
		var tm := slot / 2
		carriers.append({
			"slot": slot, "roster_index": -1, "team": tm, "is_front": slot % 2 == 0,
			"color": Color(0.62, 0.62, 0.66), "name": "BEARER", "bot": true,
			"node": null, "pos2": Vector2.ZERO, "yaw": PI,
			"mash_cd": 0.0, "hop_cd": 0.0, "hop_time": -10.0,
			"smooth_sum": 0.0, "smooth_n": 0,
		})
	# round-robin parity assignment: roster players spread across the two teams
	var team_next := [0, 0]
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var tm := i % 2
		if team_next[tm] > 1:
			tm = 1 - tm
		if team_next[tm] > 1:
			continue
		var slot := tm * 2 + int(team_next[tm])
		team_next[tm] = int(team_next[tm]) + 1
		var c: Dictionary = carriers[slot]
		c.roster_index = int(pl.get("index", i))
		c.color = pl.get("color", Color.WHITE)
		c.name = str(pl.get("name", "P%d" % (i + 1)))
		c.bot = _bots_all or bool(pl.get("bot", false))
	# instantiate carrier bodies + team coffins
	for slot in 4:
		var c: Dictionary = carriers[slot]
		bot_enabled.append(bool(c.bot) or _bots_all)
		var char_scene := str(roster[0].get("char_scene", CHAR_FALLBACKS[0])) if int(c.roster_index) < 0 else _char_of(int(c.roster_index))
		if int(c.roster_index) < 0:
			char_scene = CHAR_FALLBACKS[slot]
		var node := PBCarrierS.new()
		node.name = "Carrier%d" % slot
		add_child(node)
		node.setup(int(c.roster_index), c.color, char_scene, bool(c.is_front), int(c.team))
		c.node = node
	for t in 2:
		var coffin := PBCoffinS.new()
		coffin.name = "Coffin%d" % t
		add_child(coffin)
		coffin.build(t, TEAM_ACCENT[t])
		teams.append({
			"team": t, "coffin": coffin, "slots": [t * 2, t * 2 + 1],
			"pos2": Vector2(float(TEAM_X[t]), START_Z), "vel2": Vector2.ZERO,
			"heading": PI, "coffin_y": CARRY_Y, "div": 0.0,
			"phase": TeamPhase.CARRY, "restuff": 0.0, "runaway": 0.0, "grace": 1.0,
			"finish_tick": 0.0, "drops": 0, "restuffs": 0, "mud_time": 0.0,
		})
	# mirror: no bots
	if _mirror:
		for i in bot_enabled.size():
			bot_enabled[i] = false


func _char_of(ri: int) -> String:
	for pl in roster:
		if int(pl.get("index", -1)) == ri:
			return str(pl.get("char_scene", CHAR_FALLBACKS[ri % 4]))
	return CHAR_FALLBACKS[ri % 4]


func _reset_all_teams() -> void:
	for t in teams.size():
		var team: Dictionary = teams[t]
		team.pos2 = Vector2(float(TEAM_X[t]), START_Z)
		team.vel2 = Vector2.ZERO
		team.heading = PI
		team.coffin_y = CARRY_Y
		team.div = 0.0
		team.phase = TeamPhase.CARRY
		team.restuff = 0.0
		team.runaway = 0.0
		team.grace = 1.2
		(team.coffin as PBCoffin).reseat()
		_place_team_carry(t, 0.016, 1.0)


func _build_hud() -> void:
	_prog_bars.clear()
	for t in 2:
		var bg := ColorRect.new()
		bg.color = Color(0.06, 0.05, 0.08, 0.6)
		bg.size = Vector2(360, 26)
		bg.position = Vector2(24 if t == 0 else 1280 - 384, 64)
		ui.add_child(bg)
		var fill := ColorRect.new()
		fill.color = TEAM_ACCENT[t]
		fill.size = Vector2(4, 20)
		fill.position = Vector2((24 if t == 0 else 1280 - 384) + 3, 67)
		ui.add_child(fill)
		var lbl := Label.new()
		lbl.add_theme_font_override("font", load("res://assets/fonts/Baloo2.ttf"))
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", TEAM_ACCENT[t])
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.08))
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.position = Vector2(24 if t == 0 else 1280 - 384, 40)
		lbl.text = _team_name(t)
		ui.add_child(lbl)
		_prog_bars.append({"bg": bg, "fill": fill, "label": lbl})


func _update_hud() -> void:
	for t in _prog_bars.size():
		var frac := clampf((START_Z - float(teams[t].pos2.y)) / (START_Z - CRYPT_Z), 0.0, 1.0)
		var pb: Dictionary = _prog_bars[t]
		(pb.fill as ColorRect).size.x = maxf(4.0, 354.0 * frac)
		var tag := ""
		match int(teams[t].phase):
			TeamPhase.DROPPED, TeamPhase.RESTUFF:
				tag = "  DROPPED"
			TeamPhase.RUNAWAY:
				tag = "  RUNAWAY"
			TeamPhase.DONE:
				tag = "  AT THE CRYPT"
		(pb.label as Label).text = _team_name(t) + tag


# ===========================================================================
# World build — THE GRAVEYARD LANE
# ===========================================================================
func _build_world() -> void:
	_env_rig = EnvKit.apply(self, EnvKit.MOONLIT, {
		"key_energy": 1.45,
		"fill_energy": 0.5,
		"fog_density": 0.007,
		"ambient_energy": 0.78,
		"ambient_color": Color(0.42, 0.5, 0.7),
	})
	sun.visible = false                              # EnvKit owns the key light
	# a soft overhead fill so the coffins + carriers read against the night ground
	var top := DirectionalLight3D.new()
	top.rotation_degrees = Vector3(-80, 10, 0)
	top.light_energy = 0.55
	top.light_color = Color(0.85, 0.88, 1.0)
	add_child(top)
	_build_ground()
	_build_lanes()
	_build_crypt()
	_build_gates()
	_build_mourners()
	_scatter_graves()
	# camera: both lanes in frame, coffins recede toward the crypt upstage
	cam.position = Vector3(0, 13.5, 21.0)
	cam.look_at(Vector3(0, 0.7, -4.0))
	cam.fov = 60.0
	_cam_base = cam.global_transform


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 44)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.10, 0.12, 0.10)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, 0, -1.0)
	add_child(ground)


func _build_lanes() -> void:
	for t in 2:
		var cx: float = float(TEAM_X[t])
		# the lane path (raked gravel, tinted team accent at the edges)
		var lane := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(LANE_HALF * 2.0 + 0.5, 0.06, START_Z - CRYPT_Z + 2.0)
		lane.mesh = lm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.20, 0.19, 0.17)
		mat.roughness = 1.0
		lane.material_override = mat
		lane.position = Vector3(cx, 0.03, (START_Z + CRYPT_Z) * 0.5)
		add_child(lane)
		# mud patches
		for mz in MUD_ZONES:
			var mud := MeshInstance3D.new()
			var mm := BoxMesh.new()
			mm.size = Vector3(LANE_HALF * 2.0 + 0.3, 0.05, MUD_HALF * 2.0)
			mud.mesh = mm
			var mmat := StandardMaterial3D.new()
			mmat.albedo_color = Color(0.13, 0.10, 0.07)
			mmat.roughness = 1.0
			mmat.metallic = 0.2
			mud.material_override = mmat
			mud.position = Vector3(cx, 0.06, float(mz))
			add_child(mud)
		# downhill band (a darker, sunken strip near the crypt)
		var down := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(LANE_HALF * 2.0 + 0.4, 0.05, DOWN_Z0 - DOWN_Z1)
		down.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.16, 0.15, 0.18)
		dmat.roughness = 1.0
		down.material_override = dmat
		down.position = Vector3(cx, 0.05, (DOWN_Z0 + DOWN_Z1) * 0.5)
		add_child(down)


func _build_crypt() -> void:
	var glb := "res://assets/models/meshy/generated/board_crypt_door.glb"
	for t in 2:
		var cx: float = float(TEAM_X[t])
		if ResourceLoader.exists(glb):
			var prop := MeshyProp.instance(glb, 3.6, 180.0)
			prop.position = Vector3(cx, 0, CRYPT_Z - 1.2)
			add_child(prop)
		else:
			var arch := MeshInstance3D.new()
			var ab := BoxMesh.new()
			ab.size = Vector3(3.4, 3.2, 0.6)
			arch.mesh = ab
			var am := StandardMaterial3D.new()
			am.albedo_color = Color(0.2, 0.2, 0.22)
			arch.material_override = am
			arch.position = Vector3(cx, 1.6, CRYPT_Z - 1.2)
			add_child(arch)
		# a warm glow spilling from the crypt mouth (the finish read)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.72, 0.4)
		glow.light_energy = 2.2
		glow.omni_range = 6.0
		glow.position = Vector3(cx, 1.2, CRYPT_Z)
		add_child(glow)


func _build_gates() -> void:
	_gate_nodes.clear()
	for t in 2:
		var cx: float = float(TEAM_X[t])
		# a post the gate swings from
		var post := MeshInstance3D.new()
		var pmesh := CylinderMesh.new()
		pmesh.top_radius = 0.12
		pmesh.bottom_radius = 0.14
		pmesh.height = 2.2
		post.mesh = pmesh
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.1, 0.1, 0.12)
		pmat.metallic = 0.7
		pmat.roughness = 0.4
		post.material_override = pmat
		post.position = Vector3(cx - LANE_HALF - 0.2, 1.1, GATE_Z)
		add_child(post)
		# the swinging bar (hinge Node3D at the post, bar offset along +x)
		var hinge := Node3D.new()
		hinge.position = Vector3(cx - LANE_HALF - 0.2, 1.0, GATE_Z)
		add_child(hinge)
		var bar := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(LANE_HALF * 2.0 + 0.4, 1.4, 0.12)
		bar.mesh = bmesh
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.14, 0.14, 0.16)
		bmat.metallic = 0.75
		bmat.roughness = 0.35
		bmat.emission_enabled = true
		bmat.emission = Color(0.3, 0.32, 0.4)
		bmat.emission_energy_multiplier = 0.15
		bar.material_override = bmat
		bar.position = Vector3((LANE_HALF * 2.0 + 0.4) * 0.5, 0, 0)
		hinge.add_child(bar)
		_gate_nodes.append(hinge)


func _build_mourners() -> void:
	_mourner_node = Node3D.new()
	_mourner_node.visible = false
	add_child(_mourner_node)
	# two short lines of hooded mourners that converge from both verges
	_mourner_left = _build_mourner_line()
	_mourner_right = _build_mourner_line()
	_mourner_node.add_child(_mourner_left)
	_mourner_node.add_child(_mourner_right)


func _build_mourner_line() -> Node3D:
	var line := Node3D.new()
	for i in 3:
		var m := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.24
		cap.height = 1.5
		m.mesh = cap
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.07, 0.1)
		mat.roughness = 0.95
		m.material_override = mat
		m.position = Vector3(0, 0.75, (i - 1) * 0.55)
		line.add_child(m)
		# a pale candle each, so the procession reads at night
		var c := OmniLight3D.new()
		c.light_color = Color(1.0, 0.72, 0.4)
		c.light_energy = 0.5
		c.omni_range = 1.6
		c.position = Vector3(0, 1.3, (i - 1) * 0.55)
		line.add_child(c)
	return line


func _scatter_graves() -> void:
	var graves := [
		"grave_headstone_plain", "grave_headstone_cracked", "grave_celtic_cross",
		"grave_tilted_slab", "grave_small_obelisk", "grave_cherub_stone",
	]
	# rows of headstones down the median and outer edges (deterministic layout)
	var zs := [12.0, 6.5, 0.0, -5.0, -11.0]
	var xs := [0.0, -8.4, 8.4]
	var gi := 0
	for z in zs:
		for x in xs:
			var gname: String = graves[gi % graves.size()]
			gi += 1
			var glb := "res://assets/models/meshy/generated/%s.glb" % gname
			var yaw := float((gi * 47) % 360)
			if ResourceLoader.exists(glb):
				var prop := MeshyProp.instance(glb, 1.2, yaw)
				prop.position = Vector3(float(x), 0, float(z))
				add_child(prop)
			else:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.5, 1.0, 0.2)
				mi.mesh = bm
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.3, 0.3, 0.32)
				mi.material_override = mat
				mi.position = Vector3(float(x), 0.5, float(z))
				add_child(mi)
	# a couple of dead trees + lampposts for atmosphere
	for spec in [["estate_dead_tree", -9.5, 3.0, 3.4], ["estate_dead_tree", 9.5, -8.0, 3.2],
			["estate_lamppost", -7.6, -3.0, 2.6], ["estate_lamppost", 7.6, 8.0, 2.6]]:
		var glb := "res://assets/models/meshy/generated/%s.glb" % str(spec[0])
		if ResourceLoader.exists(glb):
			var prop := MeshyProp.instance(glb, float(spec[3]))
			prop.position = Vector3(float(spec[1]), 0, float(spec[2]))
			add_child(prop)
			if str(spec[0]) == "estate_lamppost":
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.8, 0.5)
				l.light_energy = 1.2
				l.omni_range = 6.0
				l.position = Vector3(float(spec[1]), 3.0, float(spec[2]))
				add_child(l)


# ===========================================================================
# FX
# ===========================================================================
func _time_hit(scale: float, dur: float) -> void:
	if _slowmo or _reduced_motion() or _no_juice:
		return
	_slowmo = true
	Engine.time_scale = scale
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo = false


func _reduced_motion() -> bool:
	return not bool(PartySetup.pref("screen_shake", true))


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


# ===========================================================================
# Hint bar / intro seats (house pattern)
# ===========================================================================
func _human_seats() -> Array:
	var out: Array = []
	for slot in carriers.size():
		var ri := int(carriers[slot].roster_index)
		if ri >= 0 and not bool(bot_enabled[slot]) and PlayerInput.device_of(ri) != -99:
			out.append(ri)
	return out


func _hint_seats() -> Array:
	var seats := _human_seats()
	return seats if not seats.is_empty() else [0]


func _btn_hint(action: String, label: String) -> String:
	var seats := _hint_seats()
	var keys: Array = []
	var same := true
	for i in seats:
		var k := PlayerInput.describe_binding(int(i), action)
		if not keys.is_empty() and k != keys[0]:
			same = false
		keys.append(k)
	if same:
		return "%s = %s" % [keys[0], label]
	var parts: Array = []
	for j in seats.size():
		parts.append("%s/%s" % [keys[j], GameState.PLAYER_NAMES[int(seats[j])]])
	return "%s: %s" % [label, " · ".join(parts)]


func _controls_bar() -> String:
	return "MOVE = CARRY (both)   ·   %s   ·   %s   |   STEER TOGETHER" % [
		_btn_hint("jump", "HOP / HEAVE"), _btn_hint("a", "RESTUFF")]


# ===========================================================================
# Screenshot capture (--pallbearercap)
# ===========================================================================
func _cap_event(tag: String) -> void:
	if not _cap_on or _cap_done.has(tag):
		return
	_cap_done[tag] = true
	var delay := 0.6 if tag == "results" else (0.3 if tag == "drop" else 0.15)
	get_tree().create_timer(delay, true, false, true).timeout.connect(
		func() -> void: _grab_shot(tag))


func _capture_beats() -> void:
	# carry mid-race once coffins are downfield
	if not _cap_done.has("carry") and phase == Phase.PLAY and round_t > 3.0:
		if float(teams[0].pos2.y) < START_Z - 4.0 or float(teams[1].pos2.y) < START_Z - 4.0:
			_cap_done["carry"] = true
			_grab_shot("carry")
	# a gate-hazard beat: the bar closing while a coffin is near it
	if not _cap_done.has("gate") and phase == Phase.PLAY and _gate_closed_frac() > 0.5:
		for t in 2:
			if absf(float(teams[t].pos2.y) - GATE_Z) < 3.0:
				_cap_done["gate"] = true
				_grab_shot("gate")
				break
	var have_all: bool = _cap_done.has("carry") and _cap_done.has("drop") \
		and _cap_done.has("gate") and _cap_done.has("finish") and _cap_done.has("results")
	if (have_all or game_t > 130.0) and not _cap_done.has("_quit"):
		_cap_done["_quit"] = true
		get_tree().create_timer(1.4, true, false, true).timeout.connect(
			func() -> void:
				print("PB_CAP_DONE have=%s" % str(_cap_done.keys()))
				get_tree().quit())


func _grab_shot(tag: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/pallbearers_%s.png" % [_cap_dir, tag]
		img.save_png(path)
		print("PB_CAP ", path)
	else:
		print("PB_CAP_SKIP_HEADLESS ", tag)


# ===========================================================================
# ONLINE mirror (host pumps _net_state @20Hz; client feeds _net_apply)
# ===========================================================================
func _net_state() -> Dictionary:
	var tm: Array = []
	for t in teams.size():
		var team: Dictionary = teams[t]
		tm.append(snappedf(float(team.pos2.x), 0.01))
		tm.append(snappedf(float(team.pos2.y), 0.01))
		tm.append(snappedf(float(team.heading), 0.01))
		tm.append(snappedf(float(team.coffin_y), 0.01))
		tm.append(snappedf(float(team.div), 0.02))
		tm.append(int(team.phase))
		tm.append(snappedf(float(team.restuff) / RESTUFF_NEED, 0.02))
	var cp: Array = []
	for slot in carriers.size():
		var c: Dictionary = carriers[slot]
		cp.append(snappedf(float(c.pos2.x), 0.01))
		cp.append(snappedf(float(c.pos2.y), 0.01))
		cp.append(snappedf(float(c.node.yaw), 0.01))
	return {
		"ph": phase,
		"tmr": timer_label.text,
		"hv": hint_label.visible,
		"ban": [banner.text, _banner_col, banner.visible],
		"tm": tm,
		"cp": cp,
		"drops": _ev_drops.duplicate(),
		"heaves": _ev_heaves.duplicate(),
		"gate": snappedf(_gate_closed_frac(), 0.02),
		"mq": snappedf(_mourner_phase(), 0.02),
		"win": _net_winner,
	}


func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()
	phase = int(state.get("ph", phase)) as Phase
	# timer + banner
	var tmr := str(state.get("tmr", ""))
	if tmr != timer_label.text:
		timer_label.text = tmr
	hint_label.visible = bool(state.get("hv", hint_label.visible))
	var ban: Array = state.get("ban", [])
	if ban.size() >= 3:
		banner.text = str(ban[0])
		banner.add_theme_color_override("font_color", Color(str(ban[1])))
		banner.visible = bool(ban[2])
	# teams
	var tmd: Array = state.get("tm", [])
	for t in teams.size():
		var b := t * 7
		if b + 6 >= tmd.size():
			break
		var team: Dictionary = teams[t]
		team.pos2 = Vector2(float(tmd[b]), float(tmd[b + 1]))
		team.heading = float(tmd[b + 2])
		team.coffin_y = float(tmd[b + 3])
		team.div = float(tmd[b + 4])
		var pph := int(team.phase)
		team.phase = int(tmd[b + 5])
		team.restuff = float(tmd[b + 6]) * RESTUFF_NEED
		var coffin: PBCoffin = team.coffin
		coffin.global_position = Vector3(float(team.pos2.x), float(team.coffin_y), float(team.pos2.y))
		coffin.rotation.y = float(team.heading)
		coffin.drive(get_physics_process_delta_time(), float(team.div), game_t)
		# spill/reseat from phase deltas
		var now_spilled := int(team.phase) == TeamPhase.DROPPED or int(team.phase) == TeamPhase.RUNAWAY or int(team.phase) == TeamPhase.RESTUFF
		if now_spilled and not coffin.is_spilled():
			coffin.spill()
		elif not now_spilled and coffin.is_spilled():
			coffin.reseat()
		if coffin.is_spilled():
			coffin.set_restuff(float(team.restuff) / RESTUFF_NEED)
	# carriers
	var cpd: Array = state.get("cp", [])
	for slot in carriers.size():
		var b := slot * 3
		if b + 2 >= cpd.size():
			break
		var c: Dictionary = carriers[slot]
		var np := Vector2(float(cpd[b]), float(cpd[b + 1]))
		var moving := (c.pos2 as Vector2).distance_to(np) > 0.02
		c.pos2 = np
		(c.node as PBCarrier).drive(get_physics_process_delta_time(),
			Vector3(np.x, 0.1, np.y), float(cpd[b + 2]), moving, 1.0)
	# drop clatter juice from counter deltas
	var dr: Array = state.get("drops", [0, 0])
	var pdr: Array = prev.get("drops", [0, 0])
	for t in mini(dr.size(), pdr.size()):
		if int(dr[t]) > int(pdr[t]):
			Sfx.play("thud_coffin", -2.0)
			if not _reduced_motion():
				_shake = maxf(_shake, 0.35)
	# gate visual
	var gf := float(state.get("gate", 0.0))
	for lane in _gate_nodes.size():
		(_gate_nodes[lane] as Node3D).rotation.y = lerpf(-1.35, 0.02, gf)
	# mourners (two converging lines)
	var mq := float(state.get("mq", -1.0))
	if _mourner_node != null:
		_mourner_node.visible = mq >= 0.0
		if mq >= 0.0 and _mourner_left != null:
			_mourner_left.position = Vector3(lerpf(-9.0, 0.0, mq), 0.0, MOURNER_Z)
			_mourner_right.position = Vector3(lerpf(9.0, 0.0, mq), 0.0, MOURNER_Z)
	# champion moment
	if phase == Phase.MATCH_END and not _mir_champ_done:
		var w := int(state.get("win", -1))
		if w >= 0:
			_mir_champ_done = true
			winner_team = w
			if _stretch != null:
				_stretch.match_ended()
			for slot in carriers.size():
				if int(carriers[slot].team) == w:
					(carriers[slot].node as PBCarrier).cheer()
			_confetti(Vector3(float(TEAM_X[w]), 1.6, CRYPT_Z + 2.0), TEAM_ACCENT[w])


func _mirror_tick(_delta: float) -> void:
	pass    # all mirror updates ride _net_apply snapshots


# ===========================================================================
# Config / args
# ===========================================================================
func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--pallbearerbots":
			_bots_all = true
		elif arg == "--pallbearertest":
			_tally_mode = true
			_bots_all = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--roundtime="):
			_cli_roundtime = float(arg.trim_prefix("--roundtime="))
		elif arg == "--pallbearercap":
			_cap_on = true
			_bots_all = true
		elif arg.begins_with("--outdir="):
			_cap_dir = arg.trim_prefix("--outdir=")


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
func _log(msg: String) -> void:
	var f := -1
	if _vc != null:
		f = int(_vc.frame)
	print("PB_EVT t=%.2f frame=%d | %s" % [game_t, f, msg])


func _unhandled_input(event: InputEvent) -> void:
	if _standalone and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
