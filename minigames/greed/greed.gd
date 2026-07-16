extends Minigame
## GREED INC. — a gilded pot in the middle of a vault fills with coins forever.
## Anyone can grab it and run for their own corner chute to BANK the value as
## points — but carrying it makes you SLOW, GLOWING, coin-LEAKING, and the most
## hunted person in the room (every rival's arrow points at you). Tackle the
## carrier to drop the pot (20% scatters as floor coins, you pocket a royalty).
## Dash to escape — but a carrier's dash bleeds 2 coins. 3 rounds x 90s.
##
## Anthology module contract: root of minigames/greed/greed.tscn, extends
## Minigame. Runs standalone too — if begin() isn't called 0.5s after _ready it
## self-starts a 4-player config (GameState colors/names, KayKit chars, seed
## from --seed= or 1) with bots driving the empty seats.
##
## CLI user args (after --):
##   --greedbots          all players are seeded self-play bots
##   --seed=N             rng seed for standalone start (default 1)
##   --players=N          standalone roster size 2..4
##   --rounds=N           override round count (1..3) for quick verification
##   --roundtime=S        override 90s round length
##   --greedcap           state/event-based screenshots -> verify_out, then quit
##   --outdir=DIR         output dir for --greedcap (default verify_out)
##   --greedtest=intercept  run the pursuit-tuning test, print tally, quit
##   --greedbellcap       stage + film the CLOSING BELL beats (windowed), quit
##   --shots=N,...        handled by the house VerifyCapture autoload (PNGs)

enum Phase { WAITING, INTRO, PLAY, ROUND_END, MATCH_END }
enum PotState { ON_PEDESTAL, CARRIED, LOOSE }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

const ARENA_HALF := 7.0
const CORNER := 5.6                 # chute-centre distance from origin (equidistant)
const BANK_RADIUS := 1.75
const GRAB_RANGE := 1.95
const GRAB_TIME := 0.6
const TACKLE_RANGE := 1.95
const POT_START := 5
const GROW_INTERVAL := 1.2
const GROW_AMOUNT := 1
const BURST_INTERVAL := 15.0
const BURST_AMOUNT := 5
const SCATTER_FRAC := 0.2
const DASH_COIN_COST := 2
const ROUND_TIME := 90.0
const ROUNDS := 3
const INTRO_TIME := 1.6
const ROUND_END_TIME := 3.2
const MATCH_END_HOLD := 8.0

# corner sign pattern -> chute per player index
const CORNER_SIGNS := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]

var roster: Array = []
var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()
var practice := false
var rounds_total := ROUNDS
var round_time := ROUND_TIME

var players: Array = []             # GreedPlayer per roster slot
var pot: GreedPot
var pot_value := POT_START
var pot_state: PotState = PotState.ON_PEDESTAL
var carrier_index := -1
var pot_loose_pos := Vector3.ZERO
var floor_coins: Array = []         # [{node: Node3D, pos: Vector2}]
var chute_lights: Array = []        # MeshInstance3D per corner (bank pad glow)

var phase: Phase = Phase.WAITING
var phase_t := 0.0
var round_t := 0.0
var game_t := 0.0
var round_num := 1
var grow_t := 0.0
var burst_t := 0.0
var banks_this_round := 0
var _carry_step_t := 0.0

var points := {}
var round_bank_count := {}
var biggest_bank := {}
var drops_caused := {}
var royalties := {}
var _currency: Array = []
var _kill_events: Array = []   # {killer:int, victim:int, cause:String} per contract
var _highlights: Array = []
var _results := {}

var bots: GreedBots
var bot_enabled: Array = []
var _begun := false
var _reported := false
var _standalone := false

# CLI
var _cli_seed := 1
var _cli_players := 4
var _cli_rounds := -1
var _cli_roundtime := -1.0
var _bots_all := false
var _test_mode := ""
var _cap_on := false
var _cap_dir := "verify_out"
var _cap_done := {}
var _aim_probe_on := false
var _aim_probe_deg := 0.0
var _hitkit_cap := false        # verify: stage the HIT KIT / cooldown-ring shots
var _bell_cap := false          # verify: stage + film the CLOSING BELL beats
var _freeze := false            # verify: pause gameplay so a moment can be filmed

# juice
var _shake := 0.0
var _cam_base: Transform3D
var _slowmo := false
var _vc: Node = null
var _last_status := 0.0
var _banner_col := "ffffff"        # last banner color (mirrored as html)

# THE CLOSING BELL (doc 09 §6.1-3, owner-signed Q5) — presentation-only endgame
# urgency: T-20 no-banks warning, T-15 "LAST BANKS!", T-10 rising ticks, and the
# chute-approach strobe/tick while a fat pot closes on its own chute. None of it
# touches rng or sim state; --greedtest receipts are untouched by construction.
const BELL_WARN_AT := 20.0         # §6.3: nobody-banked straight line
const BELL_LAST_AT := 15.0         # §6.1: the closing bell itself
const BELL_TICKS_AT := 10.0        # final-stretch ticks (Q1 kit cadence, local)
const BELL_APP_RANGE := 3.0        # §6.2: carrier-to-chute approach radius
const BELL_APP_POT := 15           # §6.2: pot worth the drama
const BELL_APP_TICK := 0.4         # §6.2: rising tick interval
var _bell_last := false            # T-15 fired this round
var _bell_warned := false          # T-20 fired this round
var _bell_tick_s := -1             # last final-stretch second ticked
var _bell_app := false             # chute-approach drama live
var _bell_app_ticks := 0           # rising ticks played (drives pitch +0.06)
var _bell_app_t := 0.0
var _strobe_base := 0.9            # chute pad emission at rest
var _tick_players: Array = []      # local pitched pool (bell ticks; séance style)
var _tick_next := 0
var _tick_stream: AudioStream = null
# THE FINAL STRETCH kit (doc 09 §Q1): the CLOSING BELL *is* greed's final
# stretch — the bell keeps its ticks/banners (ticks:false, no double-trigger,
# doc 09's reconciliation rule); the kit adds the missing music escalation
# (light -> tense at LAST BANKS), the lighting nudge, and the timer pulse.
# By construction: no rng, no sim writes — --greedtest receipts untouched.
var _stretch: FinalStretch = null

# ONLINE PHASE 2 (docs/design/10 §4.3) — the render mirror, house pattern per
# docs/verify/online-seance-VERIFY.md. Host runs the WHOLE sim as couch; the
# estate pumps _net_state() (PUBLIC facts) at 20 Hz; the client boots this same
# scene with config.net_mirror = true and _net_apply() drives the visuals, all
# juice fired locally from state DELTAS. Greed has no hidden info — no private
# channel needed. Reduced-motion (shake/hitstop) honors the CLIENT's own pref.
var _mirror := false
var _mir := {}                     # last applied snapshot (delta source)
var _mir_gh: Array = []            # smooth local grab-hold per seat (the tension)
var _mir_champ_done := false
var _mir_snaps := {}               # evidence snapshots fired (probe runs only)
# host-side event counters (juice rides deltas, never events)
var _ev_grabs := 0
var _ev_drops := 0
var _ev_banks := 0
var _ev_geysers := 0
var _ev_punished := 0
var _ev_leaks := 0
var _ev_swings: Array = []         # per-seat tackle swings (whiffs included)
var _ev_last_drop: Array = [-1, -1]
var _ev_last_bank: Array = [-1, 0]
var _net_champ := -1

@onready var cam: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var ui: CanvasLayer = $UI
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var banner: Label = $UI/Banner
@onready var pot_flash: Label = $UI/PotFlash
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows
var arrows: GreedEdgeArrows


# ===========================================================================
# Lifecycle
# ===========================================================================
func _ready() -> void:
	_parse_args()
	_vc = get_node_or_null("/root/VerifyCapture")
	_build_world()
	_build_arrows()
	banner.visible = false
	pot_flash.visible = false
	timer_label.text = ""
	round_label.text = ""
	if _test_mode == "intercept":
		_run_intercept_test()
		return
	await get_tree().create_timer(0.5).timeout
	if not _begun:
		_standalone = true
		begin(_default_config())


# ui_kit intro card (doc 14 nit 7): shown at load, feature-detects glyphs, real
# key fallback via describe_binding. Auto-starts after 6s so bot soaks flow through.
const GAME_INTRO := {
	"name": "GREED INC.",
	"goal": "The pot fills forever. Bank it at your chute — but carrying makes you a slow, glowing target.",
	"accent": Color(1, 0.82, 0.2),
	"controls": [
		{"action": "move", "label": "MOVE"},
		{"action": "a", "label": "GRAB / BANK"},
		{"action": "b", "label": "DASH / TACKLE"},
	],
	"tips": [
		"Carry the pot to YOUR chute and hold to bank the coins as points.",
		"The longer you hold it, the more it leaks — and the bigger a target you are.",
		"Tackle a carrier to knock the pot loose, then scoop the spill.",
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
	if _begun:
		return
	_begun = true
	_mirror = bool(config.get("net_mirror", false))
	roster = config.roster
	rng.seed = int(config.rng_seed)
	fx_rng.seed = int(config.rng_seed) + 9173
	practice = bool(config.get("practice", false))
	rounds_total = clampi(int(config.get("rounds", ROUNDS)), 1, ROUNDS)
	if practice:
		rounds_total = 1
	if _cli_rounds > 0:
		rounds_total = clampi(_cli_rounds, 1, ROUNDS)
	if _cli_roundtime > 0.0:
		round_time = clampf(_cli_roundtime, 8.0, 180.0)
	_stretch = FinalStretch.attach(self, timer_label, {"ticks": false})
	# Per-player: a seat is bot-driven if the roster says so (shell sets this
	# from estate._is_bot; standalone fills it from PlayerInput) OR the legacy
	# --greedbots flag forces ALL bots. Decided at begin() from roster data.
	bot_enabled.clear()
	for i in roster.size():
		bot_enabled.append(_bots_all or bool(roster[i].get("bot", false)))
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var player := GreedPlayer.new()
		player.name = "Player%d" % i
		add_child(player)
		player.setup(i, pl.color, str(pl.char_scene))
		player.is_bot = bot_enabled[i]   # gates the EXPRESSIVE HOP personality timers (doc 16)
		players.append(player)
		points[i] = 0
		round_bank_count[i] = 0
		biggest_bank[i] = 0
		drops_caused[i] = 0
		royalties[i] = 0
		_ev_swings.append(0)
		_mir_gh.append(0.0)
		_tint_chute(i, pl.color)
	hint_label.text = _controls_bar()   # live per-seat keys (realkeys-VERIFY)
	if _mirror:
		# RENDER MIRROR (spec §4.3): no bots, no round start, no economy — the
		# host owns every fact. Pawns stand ready for the first _net_apply; the
		# hint bar above already reads THIS machine's keys for THIS seat.
		phase = Phase.WAITING
		for i in roster.size():
			(players[i] as GreedPlayer).global_position = _spawn_pos(i)
		NetSession.set_aim_provider(_net_aim)
		print("GREED_MIRROR boot players=%d my_seat=%d" % [roster.size(), NetSession.my_seat()])
		return
	bots = GreedBots.new()
	bots.setup(int(config.rng_seed) ^ 0x6EED, roster.size())
	_log("begin players=%d seed=%d rounds=%d bots=%s" % [
		roster.size(), int(config.rng_seed), rounds_total, str(bot_enabled)])
	# NIT 7: intro card at load. Headless probe/capture modes keep the synchronous
	# start so their frame-indexed receipts stay byte-identical.
	if _test_mode != "" or _cap_on or _aim_probe_on or _hitkit_cap or _bell_cap:
		_start_round()
		if _aim_probe_on:
			_run_greed_probe()
		if _hitkit_cap:
			_run_hitkit_cap()
		if _bell_cap:
			_run_bell_cap()
	else:
		_intro_then(_start_round)


# ===========================================================================
# Round / match flow
# ===========================================================================
func _start_round() -> void:
	phase = Phase.INTRO
	phase_t = 0.0
	round_t = 0.0
	_last_status = 0.0
	banks_this_round = 0
	grow_t = GROW_INTERVAL
	burst_t = BURST_INTERVAL
	carrier_index = -1
	pot_state = PotState.ON_PEDESTAL
	_bell_last = false
	_bell_warned = false
	_bell_tick_s = -1
	_set_bell_approach(false)
	if round_num == 1:
		pot_value = POT_START
	_clear_floor_coins()
	for i in roster.size():
		round_bank_count[i] = 0
		var pos := _spawn_pos(i)
		var face := atan2(-pos.x, -pos.z)   # face the vault centre
		(players[i] as GreedPlayer).reset_for_round(pos, face)
	round_label.text = "ROUND %d / %d" % [round_num, rounds_total]
	if _stretch != null:
		_stretch.round_reset()   # FINAL STRETCH: light bed back on between rounds
	_flash_banner("ROUND %d" % round_num, Color(1, 0.85, 0.2), 1.2)
	hint_label.visible = round_num == 1
	if round_num == 1:
		var tw := create_tween()
		tw.tween_interval(8.0)
		tw.tween_callback(func() -> void: hint_label.visible = false)
	_rebuild_scoreboard()
	_log("round_start %d pot=%d" % [round_num, pot_value])


func _end_round(kind: String) -> void:
	phase = Phase.ROUND_END
	phase_t = 0.0
	# whistle: freeze the world, pot goes home. A carrier at the bell loses it.
	if carrier_index >= 0:
		(players[carrier_index] as GreedPlayer).set_carrier(false)
		carrier_index = -1
	_set_bell_approach(false)
	var greed_punished := banks_this_round == 0
	if greed_punished:
		_scatter_entire_pot()
		_ev_punished += 1
		_flash_banner("GREED PUNISHED!\nTHE POT SCATTERS", Color(1.0, 0.35, 0.25), 2.8)
		Sfx.play("grudge")
		pot_value = POT_START
	else:
		_flash_banner("ROUND %d OVER" % round_num, Color(1, 0.85, 0.2), 2.6)
		Sfx.play("round_over")
	pot_state = PotState.ON_PEDESTAL
	# grudge: banked nothing this round
	for i in roster.size():
		if int(round_bank_count[i]) == 0:
			_currency.append({"type": "grudge", "player": i, "amount": 1,
				"reason": "banked nothing in round %d" % round_num})
	_rebuild_scoreboard()
	var bits: Array = []
	for i in roster.size():
		bits.append("%s=%d" % [roster[i].name, int(points[i])])
	_log("round_end %d kind=%s punished=%s scores[%s]" % [
		round_num, kind, str(greed_punished), ", ".join(bits)])


func _finish_match() -> void:
	phase = Phase.MATCH_END
	phase_t = 0.0
	var order: Array = range(roster.size())
	order.sort_custom(func(a, b):
		if int(points[a]) != int(points[b]):
			return int(points[a]) > int(points[b])
		return a < b)
	var champ: int = order[0]
	_net_champ = champ
	var champ_pl: Dictionary = roster[champ]
	if _stretch != null:
		_stretch.match_ended()
	_flash_banner("%s WINS GREED INC.!" % champ_pl.name, champ_pl.color, 9999.0)
	Sfx.play("match_win")
	(players[champ] as GreedPlayer).cheer()
	_confetti((players[champ] as GreedPlayer).global_position + Vector3(0, 1.8, 0), champ_pl.color)
	_shake = maxf(_shake, 0.5)
	# highlights
	_highlights.clear()
	var bb := _dict_max(biggest_bank)
	if int(biggest_bank[bb]) > 0:
		_highlights.append("%s's biggest heist: %d coins" % [roster[bb].name, int(biggest_bank[bb])])
	var dc := _dict_max(drops_caused)
	if int(drops_caused[dc]) >= 1:
		_highlights.append("%s forced %d drop%s" % [roster[dc].name, int(drops_caused[dc]),
			"" if int(drops_caused[dc]) == 1 else "s"])
	# monuments: The Banker for a 30+ single bank
	var monuments: Array = []
	for i in roster.size():
		if int(biggest_bank[i]) >= 30:
			monuments.append({"player": i, "kind": "banker",
				"label": "%s, The Banker" % roster[i].name})
			break
	_results = {
		"placements": order,
		"points": points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": _highlights.slice(0, 3),
		"monuments": monuments,
		"kill_events": _kill_events.duplicate(),
	}
	_log("match_end " + JSON.stringify(_results))
	print("KILL_EVENTS n=", _kill_events.size(), " ", JSON.stringify(_kill_events))


# ===========================================================================
# Main loop
# ===========================================================================
func _physics_process(delta: float) -> void:
	# THE HOUSE GUARD (spec §4.3): a mirror never simulates. Interp + juice only.
	if _mirror:
		game_t += delta
		_mirror_tick(delta)
		return
	if phase == Phase.WAITING:
		return
	if _freeze:                     # verify capture: gameplay held, visuals keep ticking
		return
	game_t += delta
	phase_t += delta
	match phase:
		Phase.INTRO:
			for p in players:
				(p as GreedPlayer).set_move_intent(Vector2.ZERO)
				(p as GreedPlayer).tick_movement(delta)
			if phase_t >= INTRO_TIME:
				phase = Phase.PLAY
				round_t = 0.0
				_flash_banner("GRAB IT!", Color(1, 0.85, 0.2), 0.8)
				Sfx.play("confirm")
		Phase.PLAY:
			round_t += delta
			_tick_play(delta)
		Phase.ROUND_END:
			for p in players:
				(p as GreedPlayer).set_move_intent(Vector2.ZERO)
				(p as GreedPlayer).tick_movement(delta)
			if phase_t >= ROUND_END_TIME:
				round_num += 1
				if round_num > rounds_total:
					_finish_match()
				else:
					_start_round()
		Phase.MATCH_END:
			for p in players:
				(p as GreedPlayer).tick_movement(delta)
			if phase_t >= MATCH_END_HOLD and not _reported:
				_reported = true
				report_finished(_results)


func _tick_play(delta: float) -> void:
	# 1. pot growth (only while it sits on the pedestal)
	if pot_state == PotState.ON_PEDESTAL:
		grow_t -= delta
		if grow_t <= 0.0:
			grow_t = GROW_INTERVAL
			pot_value += GROW_AMOUNT
			Sfx.play("card", -14.0)
		burst_t -= delta
		if burst_t <= 0.0:
			burst_t = BURST_INTERVAL
			pot_value += BURST_AMOUNT
			_ev_geysers += 1
			pot.geyser()
			Sfx.play("bumper", -3.0)
			_flash_pot("+%d!" % BURST_AMOUNT, Color(1.0, 0.9, 0.35))

	# 2. drive every player in index order (deterministic)
	for p in roster.size():
		var me: GreedPlayer = players[p]
		var inp := _input_for(p, delta)
		me.set_move_intent(inp.move)
		# dash (B)
		if inp.dash and me.can_act():
			if me.is_carrier:
				if pot_value > POT_START and me.try_dash():
					pot_value -= DASH_COIN_COST
					pot_value = maxi(pot_value, 1)
					_ev_leaks += 1
					_leak_burst(me.global_position)
					_flash_pot("-%d" % DASH_COIN_COST, Color(1.0, 0.5, 0.3))
				elif me.dash_cd <= 0.0:
					me.try_dash()   # too poor to bleed coins: free hop
			else:
				me.try_dash()
		# A: tackle the carrier, else grab the pot
		_handle_action(p, me, inp, delta)
		me.tick_movement(delta)

	# 3. keep everyone inside the vault (belt-and-braces vs. wall tunnelling)
	for p in players:
		var gp: GreedPlayer = p
		gp.global_position.x = clampf(gp.global_position.x, -ARENA_HALF + 0.4, ARENA_HALF - 0.4)
		gp.global_position.z = clampf(gp.global_position.z, -ARENA_HALF + 0.4, ARENA_HALF - 0.4)

	# 4. resolve pot follow, floor-coin pickups, banking
	_update_pot_transform()
	_tick_floor_coins()
	if carrier_index >= 0:
		_check_bank(carrier_index)
		_tick_carry_footsteps(delta)

	# 5. HUD / arrows
	_update_hud()

	# 5b. THE CLOSING BELL (doc 09 §6.1-3) — presentation only, no sim writes
	_tick_closing_bell(delta)

	if _cap_on:
		_capture_beats()

	# 6. timeout
	if round_t >= round_time:
		_end_round("timeout")

	# periodic status for verification logs
	if round_t - _last_status >= 10.0:
		_last_status = round_t
		_log("status t=%.0f pot=%d state=%s carrier=%d coins=%d" % [
			round_t, pot_value, PotState.keys()[pot_state], carrier_index, floor_coins.size()])


func _process(delta: float) -> void:
	if phase == Phase.WAITING:
		return
	# camera shake
	cam.global_transform = _cam_base
	if _shake > 0.002:
		_shake = maxf(0.0, _shake - delta * 1.4)
		cam.position += Vector3(fx_rng.randf_range(-1, 1), fx_rng.randf_range(-1, 1),
			fx_rng.randf_range(-1, 1)) * _shake * 0.4
	if pot:
		pot.tick(delta)
	for p in players:
		(p as GreedPlayer).tick_visual(delta, game_t)
	# HUD timer colour (mirror: text + colour ride the snapshot instead)
	if not _mirror:
		if phase == Phase.PLAY or phase == Phase.INTRO:
			var remain := int(ceil(maxf(0.0, round_time - round_t)))
			timer_label.text = str(remain)
			var hot := remain <= 10
			timer_label.add_theme_color_override("font_color",
				Color(1, 0.3, 0.2) if hot else Color(1, 0.92, 0.6))
			# FINAL STRETCH: timer pulse only — the CLOSING BELL owns the ticks
			if _stretch != null and phase == Phase.PLAY:
				_stretch.tick(round_time - round_t)
		else:
			timer_label.text = ""
	# CLOSING BELL §6.2: the carrier's chute pad strobes at 3 Hz while the
	# approach drama is live (host: real state; mirror: the mirrored bell fact)
	if _bell_app and carrier_index >= 0:
		_drive_strobe(carrier_index, game_t)
	# floor coin bob
	for c in floor_coins:
		(c.node as Node3D).rotation.y += delta * 3.0


# ===========================================================================
# Action handling: grab (hold) & tackle (tap)
# ===========================================================================
func _handle_action(p: int, me: GreedPlayer, inp: Dictionary, delta: float) -> void:
	if me.is_carrier:
		me.show_grab_progress(0.0)
		return
	# tackle takes priority when a carrier is in reach
	if carrier_index >= 0 and carrier_index != p:
		var cp: GreedPlayer = players[carrier_index]
		var d: float = _flat_dist(me.global_position, cp.global_position)
		if d < TACKLE_RANGE:
			me.show_grab_progress(0.0)
			if inp.tackle and me.can_act() and me.tackle_lock <= 0.0:
				_attempt_tackle(p)
			return
	# grab: hold A near a grabbable pot
	if pot_state == PotState.ON_PEDESTAL or pot_state == PotState.LOOSE:
		var pot2 := pot_world_2d()
		var d2: float = Vector2(me.global_position.x, me.global_position.z).distance_to(pot2)
		if d2 < GRAB_RANGE and me.can_act():
			if inp.grab:
				me.grab_hold += delta
				me.show_grab_progress(me.grab_hold / GRAB_TIME)
				if me.grab_hold >= GRAB_TIME:
					_do_grab(_grab_winner_over(p, delta))
				return
	me.grab_hold = 0.0
	me.show_grab_progress(0.0)


## Tie-break for the 0.6s grab hold. `p` (processed in index order, so no lower
## index has grabbed yet this tick) just reached GRAB_TIME. If `p` is a bot and a
## HUMAN is tied on progress — equal hold, still holding A within range, and thus
## crossing the same tick — the HUMAN gets the pot instead. Humans win grab ties.
## No humans in the contest -> returns `p` unchanged, so bot-only sims are byte-
## identical (bots still obey the same hold; only the human tie-break is new).
func _grab_winner_over(p: int, delta: float) -> int:
	if not bot_enabled[p]:
		return p
	var me: GreedPlayer = players[p]
	var pot2: Vector2 = pot_world_2d()
	for q in roster.size():
		if q == p or bot_enabled[q]:
			continue
		var hq: GreedPlayer = players[q]
		if hq.is_carrier or not hq.can_act() or not PlayerInput.is_down(q, "a"):
			continue
		var dq: float = Vector2(hq.global_position.x, hq.global_position.z).distance_to(pot2)
		if dq >= GRAB_RANGE:
			continue
		# hq.grab_hold is a tick behind (q not ticked yet); +delta is its effective
		# progress this frame. Equal-or-better than the bot -> the human takes it.
		if hq.grab_hold + delta >= me.grab_hold - 0.0001:
			return q
	return p


func _do_grab(p: int) -> void:
	var me: GreedPlayer = players[p]
	me.grab_hold = 0.0
	me.show_grab_progress(0.0)
	me.set_carrier(true)
	me.immune_t = maxf(me.immune_t, 0.5)   # grace to break away — no instant re-mug
	carrier_index = p
	pot_state = PotState.CARRIED
	pot.set_carried(true)
	# stop everyone else mid-grab (the pot just moved)
	for q in roster.size():
		if q != p:
			(players[q] as GreedPlayer).grab_hold = 0.0
			(players[q] as GreedPlayer).show_grab_progress(0.0)
	Sfx.play("confirm", -2.0)
	_flash_pot("GRABBED!", roster[p].color)
	_ev_grabs += 1
	if NetSession.has_guests() and not _mir_snaps.has("host_carry"):
		_mir_snaps["host_carry"] = true
		VerifyCapture.snap("greed_host_carry")
	_cap_event("grab")
	_log("grab p%d pot=%d at=(%.1f,%.1f) chute=(%.1f,%.1f)" % [p, pot_value,
		me.global_position.x, me.global_position.z, chute_pos(p).x, chute_pos(p).y])


func _attempt_tackle(p: int) -> void:
	var me: GreedPlayer = players[p]
	var cp: GreedPlayer = players[carrier_index]
	_ev_swings[p] += 1
	me.do_tackle_swing()
	# KBM humans lunge toward the cursor (grab unchanged, dash stays move-directed).
	# Non-KBM / bots get ZERO aim -> no lunge -> identical to before.
	if not bot_enabled[p]:
		var aim := PlayerInput.get_aim_dir(p, me.global_position, cam)
		if aim != Vector3.ZERO:
			me.lunge_toward(aim)
	if not cp.can_be_tackled():
		# whiffed into i-frames / immunity — escape was priced but it paid off
		Sfx.play("invalid", -8.0)
		_log("tackle_whiff p%d -> p%d (iframe)" % [p, carrier_index])
		return
	var victim := carrier_index
	_drop_carrier(victim, p)


func _drop_carrier(victim: int, tackler: int) -> void:
	var cp: GreedPlayer = players[victim]
	var drop_pos := cp.global_position
	# 20% of the pot scatters as floor coins (each worth +1)
	var scatter := int(round(float(pot_value) * SCATTER_FRAC))
	scatter = clampi(scatter, 0, pot_value - 1)
	pot_value -= scatter
	_spawn_floor_coins(drop_pos, scatter)
	# pot lands where it fell
	pot_state = PotState.LOOSE
	pot_loose_pos = Vector3(
		clampf(drop_pos.x, -ARENA_HALF + 1.0, ARENA_HALF - 1.0),
		0.0,
		clampf(drop_pos.z, -ARENA_HALF + 1.0, ARENA_HALF - 1.0))
	cp.set_carrier(false)
	cp.get_stunned()
	carrier_index = -1
	pot.set_carried(false)
	# tackler profits: +1 royalty ("mugging pays")
	points[tackler] = int(points[tackler]) + 1
	royalties[tackler] = int(royalties[tackler]) + 1
	drops_caused[tackler] = int(drops_caused[tackler]) + 1
	_currency.append({"type": "royalty", "player": tackler, "amount": 1,
		"reason": "mugged %s off the pot" % roster[victim].name})
	_currency.append({"type": "grudge", "player": victim, "amount": 1,
		"reason": "got mugged off the pot"})
	# structured kill attribution (module contract): the tackle stuns the carrier
	# (get_stunned, STUN_TIME) — a genuine down, at the exact royalty-crediting path.
	_kill_events.append({"killer": tackler, "victim": victim, "cause": "mugged"})
	# HIT KIT: softened hitstop + victim squash-pop + spark along the knockback,
	# then coin burst. Shake + hitstop drop under reduced-motion; pop/spark stay.
	_hit_pause()
	var tk: GreedPlayer = players[tackler]
	var kdir := drop_pos - tk.global_position
	cp.flash_pop()
	_spark_burst(drop_pos + Vector3(0, 1.0, 0), kdir, roster[tackler].color, 1.0)
	if not _reduced_motion():
		_shake = maxf(_shake, 0.45)
	_coin_burst(drop_pos + Vector3(0, 1.0, 0), 22)
	Sfx.play("splat", -1.0)
	Sfx.play("death", -6.0)
	_flash_banner("%s MUGGED %s!" % [roster[tackler].name, roster[victim].name],
		roster[tackler].color, 1.8)
	_ev_drops += 1
	_ev_last_drop = [victim, tackler]
	if NetSession.has_guests() and not _mir_snaps.has("host_drop"):
		_mir_snaps["host_drop"] = true
		VerifyCapture.snap("greed_host_drop")
	_cap_event("drop")
	_rebuild_scoreboard()
	_log("drop victim=%d tackler=%d scatter=%d pot=%d" % [victim, tackler, scatter, pot_value])


## Heavy, distinct footfall while the carrier lugs the pot — the audible half of
## "the carrier must FEEL hunted" (spec Feel targets).
func _tick_carry_footsteps(delta: float) -> void:
	var c: GreedPlayer = players[carrier_index]
	if not c.can_act() or Vector2(c.velocity.x, c.velocity.z).length() < 1.0:
		_carry_step_t = 0.0
		return
	_carry_step_t -= delta
	if _carry_step_t <= 0.0:
		_carry_step_t = 0.34
		Sfx.play("place", -7.0, 0.12)


func _check_bank(p: int) -> void:
	var me: GreedPlayer = players[p]
	var here := Vector2(me.global_position.x, me.global_position.z)
	if here.distance_to(chute_pos(p)) <= BANK_RADIUS:
		_do_bank(p)


func _do_bank(p: int) -> void:
	var amount := pot_value
	points[p] = int(points[p]) + amount
	round_bank_count[p] = int(round_bank_count[p]) + 1
	banks_this_round += 1
	biggest_bank[p] = maxi(int(biggest_bank[p]), amount)
	var me: GreedPlayer = players[p]
	me.set_carrier(false)
	me.cheer()
	carrier_index = -1
	# ceremony
	_bank_ceremony(p, amount)
	_ev_banks += 1
	_ev_last_bank = [p, amount]
	_set_bell_approach(false)
	if NetSession.has_guests() and not _mir_snaps.has("host_bank"):
		_mir_snaps["host_bank"] = true
		VerifyCapture.snap("greed_host_bank")
	# pot resets and returns to the pedestal
	pot_value = POT_START
	pot_state = PotState.ON_PEDESTAL
	pot.set_carried(false)
	grow_t = GROW_INTERVAL
	burst_t = BURST_INTERVAL
	_cap_event("bank")
	_rebuild_scoreboard()
	_log("bank p%d amount=%d total=%d at=(%.1f,%.1f)" % [p, amount, int(points[p]),
		me.global_position.x, me.global_position.z])


func _bank_ceremony(p: int, amount: int) -> void:
	var pl: Dictionary = roster[p]
	var at := chute_pos(p)
	var world := Vector3(at.x, 0.2, at.y)
	Sfx.play("match_win")
	_shake = maxf(_shake, 0.5)
	_flash_banner("%s BANKS %d!" % [pl.name, amount], pl.color, 2.4)
	_coin_rain(world, mini(amount, 40), pl.color)
	_confetti(world + Vector3(0, 1.4, 0), pl.color)
	# light the chute pad up
	var idx := p
	if idx < chute_lights.size():
		var mat := (chute_lights[idx] as MeshInstance3D).material_override as StandardMaterial3D
		if mat:
			var tw := create_tween()
			mat.emission_energy_multiplier = 3.5
			tw.tween_property(mat, "emission_energy_multiplier", 0.9, 1.2)


# ===========================================================================
# Floor coins
# ===========================================================================
func _spawn_floor_coins(around: Vector3, n: int) -> void:
	for i in n:
		var ang := fx_rng.randf_range(0.0, TAU)
		var r := fx_rng.randf_range(0.6, 2.1)
		var pos := Vector2(around.x + cos(ang) * r, around.z + sin(ang) * r)
		pos.x = clampf(pos.x, -ARENA_HALF + 0.6, ARENA_HALF - 0.6)
		pos.y = clampf(pos.y, -ARENA_HALF + 0.6, ARENA_HALF - 0.6)
		_make_coin(pos)


## One floor-coin node (shared by the host spawner above and the mirror's
## coin-list sync — render-only, no rng).
func _make_coin(pos: Vector2) -> void:
	var node := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.26
	m.bottom_radius = 0.26
	m.height = 0.09
	node.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.83, 0.16)
	mat.metallic = 0.85
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.08)
	mat.emission_energy_multiplier = 0.8
	node.material_override = mat
	node.rotation.x = 0.22
	add_child(node)
	node.global_position = Vector3(pos.x, 0.35, pos.y)
	floor_coins.append({"node": node, "pos": pos})


func _tick_floor_coins() -> void:
	for p in roster.size():
		var me: GreedPlayer = players[p]
		if not me.can_act():
			continue
		var mp := Vector2(me.global_position.x, me.global_position.z)
		for i in range(floor_coins.size() - 1, -1, -1):
			var c: Dictionary = floor_coins[i]
			if (c.pos as Vector2).distance_to(mp) < 0.85:
				(c.node as Node3D).queue_free()
				floor_coins.remove_at(i)
				points[p] = int(points[p]) + 1
				Sfx.play("card", -10.0)
				_rebuild_scoreboard()


func _scatter_entire_pot() -> void:
	# the whole hoard bursts across the vault (visual only — nobody scores it)
	_coin_burst(pot.global_position + Vector3(0, 1.0, 0), mini(pot_value * 2, 90))
	_shake = maxf(_shake, 0.7)


func _clear_floor_coins() -> void:
	for c in floor_coins:
		(c.node as Node3D).queue_free()
	floor_coins.clear()


# ===========================================================================
# Pot transform
# ===========================================================================
func _update_pot_transform() -> void:
	match pot_state:
		PotState.ON_PEDESTAL:
			pot.global_position = Vector3(0, 0.55, 0)
		PotState.CARRIED:
			if carrier_index >= 0:
				var c: GreedPlayer = players[carrier_index]
				var fwd := Vector3(sin(c.yaw), 0, cos(c.yaw))
				pot.global_position = c.global_position + Vector3(0, 1.35, 0) + fwd * 0.15
			pot.update_value(pot_value)
			return
		PotState.LOOSE:
			pot.global_position = pot_loose_pos + Vector3(0, 0.55, 0)
	pot.update_value(pot_value)


func pot_world_2d() -> Vector2:
	if pot_state == PotState.LOOSE:
		return Vector2(pot_loose_pos.x, pot_loose_pos.z)
	return Vector2.ZERO   # pedestal is at origin


# ===========================================================================
# Input / bots
# ===========================================================================
func _input_for(p: int, delta: float) -> Dictionary:
	if bot_enabled[p]:
		var d: Dictionary = bots.decide(p, self, delta)
		return {"move": d.move, "grab": d.grab, "tackle": d.tackle, "dash": d.dash}
	return {
		"move": PlayerInput.get_move(p),
		"grab": PlayerInput.is_down(p, "a"),
		"tackle": PlayerInput.just_pressed(p, "a"),
		"dash": PlayerInput.just_pressed(p, "b"),
	}


# ===========================================================================
# Geometry helpers
# ===========================================================================
func chute_pos(i: int) -> Vector2:
	var s: Vector2 = CORNER_SIGNS[i % 4]
	return s * CORNER


func _spawn_pos(i: int) -> Vector3:
	var c := chute_pos(i)
	# just inside the chute, facing centre
	var inward := (-c).normalized() * 1.2
	return Vector3(c.x + inward.x, 0.1, c.y + inward.y)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


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
	# edge arrows all point at the carrier
	if carrier_index >= 0 and arrows and not cam.is_position_behind(
			(players[carrier_index] as GreedPlayer).global_position + Vector3(0, 1.6, 0)):
		var c: GreedPlayer = players[carrier_index]
		var head := c.global_position + Vector3(0, 1.6, 0)
		var screen: Vector2 = cam.unproject_position(head)
		var list: Array = []
		for q in roster.size():
			if q != carrier_index:
				list.append({"color": roster[q].color})
		arrows.update_arrows(true, screen, list, game_t)
	elif arrows:
		arrows.update_arrows(false, Vector2.ZERO, [], game_t)


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
		if i == carrier_index:
			tag = "  CARRYING"
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


func _flash_pot(text: String, color: Color) -> void:
	pot_flash.text = text
	pot_flash.add_theme_color_override("font_color", color)
	pot_flash.visible = true
	pot_flash.pivot_offset = pot_flash.size / 2.0
	pot_flash.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(pot_flash, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void: pot_flash.visible = false)


# ===========================================================================
# THE CLOSING BELL (doc 09 §6.1-3, AAA queue Q5 — owner-signed)
# Presentation only: banners, sfx, pad strobe, pot tremble/pulse. No rng, no
# sim writes — --greedtest / --greedcap receipts are untouched by construction.
# Every fact here also rides _net_state() so the mirror hears the same bell.
# ===========================================================================
var _strobe_pad := -1
var _bell_warn_fired := false

func _tick_closing_bell(delta: float) -> void:
	var remain := round_time - round_t
	# §6.3 the straight line before the GREED PUNISHED punchline
	if not _bell_warned and remain <= BELL_WARN_AT:
		_bell_warned = true
		if banks_this_round == 0:
			_bell_warn_fired = true
			_flash_banner("NOBODY HAS BANKED —\nTHE POT GROWS RESTLESS", Color(1.0, 0.62, 0.25), 2.2)
			pot.restless(1.6)
			Sfx.play("grudge", -10.0)
			_log("bell_warn t=%.1f pot=%d" % [round_t, pot_value])
	# §6.1 the bell itself
	if not _bell_last and remain <= BELL_LAST_AT:
		_bell_last = true
		if _stretch != null:
			_stretch.escalate()   # FINAL STRETCH: the bell brings the tense track
		_flash_banner("LAST BANKS!", Color(1.0, 0.85, 0.2), 1.5)
		Sfx.play("grudge", -6.0)
		pot.bell_pulse()
		_log("bell_lastbanks t=%.1f pot=%d" % [round_t, pot_value])
		if NetSession.has_guests() and not _mir_snaps.has("host_bell"):
			_mir_snaps["host_bell"] = true
			VerifyCapture.snap("greed_host_bell")
	# final-stretch ticks, one per second T-10 .. T-1, rising pitch (Q1 cadence)
	if remain <= BELL_TICKS_AT:
		var s := int(ceil(maxf(remain, 0.0)))
		if s != _bell_tick_s and s >= 1:
			_bell_tick_s = s
			_bell_tick(lerpf(1.0, 1.55, (10 - s) / 9.0), -9.0)
	# §6.2 the approach: a fat pot closing on its own chute turns the room's head
	var want := false
	if carrier_index >= 0 and pot_value >= BELL_APP_POT:
		var c: GreedPlayer = players[carrier_index]
		if Vector2(c.global_position.x, c.global_position.z) \
				.distance_to(chute_pos(carrier_index)) <= BELL_APP_RANGE:
			want = true
	if want and not _bell_app:
		_log("bell_approach on p%d pot=%d" % [carrier_index, pot_value])
	if not want:
		if _bell_app:
			_set_bell_approach(false)
		return
	_bell_app = true
	_bell_app_t -= delta
	if _bell_app_t <= 0.0:
		_bell_app_t = BELL_APP_TICK
		_bell_tick(1.0 + 0.06 * float(_bell_app_ticks), -10.0)
		_bell_app_ticks += 1


func _set_bell_approach(on: bool) -> void:
	if not on and _strobe_pad >= 0 and _strobe_pad < chute_lights.size():
		var mat := (chute_lights[_strobe_pad] as MeshInstance3D).material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = _strobe_base
	_bell_app = on
	if not on:
		_bell_app_ticks = 0
		_bell_app_t = 0.0
		_strobe_pad = -1


## 3 Hz pad strobe on the carrier's own chute while the approach drama is live.
func _drive_strobe(ci: int, t: float) -> void:
	if ci < 0 or ci >= chute_lights.size():
		return
	_strobe_pad = ci
	var mat := (chute_lights[ci] as MeshInstance3D).material_override as StandardMaterial3D
	if mat:
		mat.emission_energy_multiplier = _strobe_base + (0.5 + 0.5 * sin(t * TAU * 3.0)) * 2.4


## Exact-pitch tick (the Sfx pool randomizes pitch; the bell needs a LADDER).
## Same lazy local-pool trick as the séance's _play_pitched.
func _bell_tick(pitch: float, db: float) -> void:
	if _tick_players.is_empty():
		for i in 3:
			var p := AudioStreamPlayer.new()
			p.bus = "SFX"
			add_child(p)
			_tick_players.append(p)
	if _tick_stream == null:
		var bank: Dictionary = Sfx.BANK
		if bank.has("card") and not (bank["card"] as Array).is_empty():
			_tick_stream = load("res://assets/audio/%s.ogg" % str(bank["card"][0]))
	if _tick_stream == null:
		return
	var p: AudioStreamPlayer = _tick_players[_tick_next]
	_tick_next = (_tick_next + 1) % _tick_players.size()
	p.stream = _tick_stream
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


# ===========================================================================
# Live-binding hint bar (real keys, not "A"/"B" — docs/verify/realkeys-VERIFY.md)
# ===========================================================================

## Seats driven by a HUMAN with a real local device (not a bot, not unassigned,
## not a remote guest — their keys live on THEIR screen, mirrored there).
func _human_seats() -> Array:
	var out := []
	for i in roster.size():
		var idx := int(roster[i].get("index", i))
		if not bot_enabled[i] and PlayerInput.device_of(idx) != -99:
			out.append(idx)
	return out


## Seats whose bindings the hint bar prints: the live humans, or seat 0 as a
## representative when a bot-only demo has no humans — so the bar always shows
## a REAL key, never an abstract "A =" verb (doc 14 nit 3, notation consistency).
func _hint_seats() -> Array:
	var seats := _human_seats()
	return seats if not seats.is_empty() else [0]


## One button's live legend: "KEY = LABEL" when every hint seat shares the key,
## else the per-seat "LABEL: KEY/NAME · KEY/NAME" form (mixed devices).
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
	return "MOVE   ·   %s   ·   %s   ·   %s   |   CARRY THE POT TO YOUR CHUTE TO BANK IT" % [
		_btn_hint("a", "GRAB (hold) / TACKLE"), _btn_hint("b", "DASH"), _btn_hint("jump", "HOP")]


# ===========================================================================
# ONLINE PHASE 2 — the render mirror (docs/design/10 §4.3; house pattern per
# docs/verify/online-seance-VERIFY.md). Host: _net_state() -> PUBLIC facts at
# 20 Hz. Client: _net_apply() stores + diffs; ALL juice fires from deltas;
# _mirror_tick() interpolates at 60 Hz. Greed has no hidden info — no private
# channel. The vault itself is static and built identically by both ends.
# ===========================================================================

## HOST, pumped by the estate at 20 Hz. Everything here is on every couch
## player's screen right now; nothing else enters the dict.
func _net_state() -> Dictionary:
	var pp: Array = []
	for i in roster.size():
		var pl: GreedPlayer = players[i]
		pp.append(snappedf(pl.global_position.x, 0.01))
		pp.append(snappedf(pl.global_position.z, 0.01))
		pp.append(snappedf(pl.yaw, 0.01))
		pp.append(1 if Vector2(pl.velocity.x, pl.velocity.z).length() > 0.6 else 0)
		pp.append(1 if pl.stun_t > 0.0 else 0)
		pp.append(snappedf(pl.dash_cd, 0.02))
		pp.append(snappedf(pl.grab_hold, 0.02))
	var pts: Array = []
	for i in roster.size():
		pts.append(int(points[i]))
	var coins: Array = []
	for c in floor_coins:
		coins.append(snappedf((c.pos as Vector2).x, 0.01))
		coins.append(snappedf((c.pos as Vector2).y, 0.01))
	return {
		"ph": phase,
		"rl": round_label.text,
		"tmr": timer_label.text,
		"hv": hint_label.visible,
		"ban": [banner.text, _banner_col, banner.visible],
		"pv": pot_value,
		"ps": pot_state,
		"ci": carrier_index,
		"lp": [snappedf(pot_loose_pos.x, 0.01), snappedf(pot_loose_pos.z, 0.01)],
		"p": pp,
		"pts": pts,
		"sw": _ev_swings.duplicate(),
		"coins": coins,
		"ev": [_ev_grabs, _ev_drops, _ev_banks, _ev_geysers, _ev_punished, _ev_leaks],
		"ld": _ev_last_drop,
		"lb": _ev_last_bank,
		"bell": [1 if _bell_last else 0, 1 if _bell_warn_fired else 0,
			1 if _bell_app else 0, _bell_app_ticks],
		"champ": _net_champ,
	}


## CLIENT. Latest-state-wins; every sfx/flash/shake fires from a DELTA against
## the previous snapshot, so a dropped packet loses nothing but frames.
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()   # FINAL STRETCH: light bed on first snapshot
	phase = (int(state.get("ph", phase))) as Phase   # render/probe fact only
	round_label.text = str(state.get("rl", ""))
	hint_label.visible = bool(state.get("hv", hint_label.visible))
	_apply_mir_timer(str(state.get("tmr", "")), str(prev.get("tmr", "")))
	_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	# --- pot + carrier facts
	var pci := int(prev.get("ci", -1))
	var ci := int(state.get("ci", -1))
	if ci != pci:
		if pci >= 0 and pci < players.size():
			(players[pci] as GreedPlayer).set_carrier(false)
		if ci >= 0 and ci < players.size():
			(players[ci] as GreedPlayer).set_carrier(true)
	carrier_index = ci
	pot_value = int(state.get("pv", pot_value))
	var nps := int(state.get("ps", pot_state))
	if nps != int(pot_state):
		pot_state = nps as PotState
		pot.set_carried(pot_state == PotState.CARRIED)
	var lp: Array = state.get("lp", [])
	if lp.size() >= 2:
		pot_loose_pos = Vector3(float(lp[0]), 0.0, float(lp[1]))
	# --- per-seat resyncs + one-shot deltas (dash, tackle swing, grab hold)
	var pp: Array = state.get("p", [])
	var ppp: Array = prev.get("p", [])
	var sw: Array = state.get("sw", [])
	var psw: Array = prev.get("sw", [])
	for i in players.size():
		var b := i * 7
		if b + 6 >= pp.size():
			break
		var pl: GreedPlayer = players[i]
		var dcd := float(pp[b + 5])
		var pdcd := float(ppp[b + 5]) if b + 5 < ppp.size() else 0.0
		if dcd - pdcd > 0.8:              # dash fired host-side this window
			pl._one_shot("Dodge_Forward", GreedPlayer.DASH_TIME + 0.05)
			Sfx.play("bounce", -6.0)
		if absf(pl.dash_cd - dcd) > 0.1:  # ring resync (net_pose decays locally)
			pl.dash_cd = dcd
		var tgh := float(pp[b + 6])
		if tgh <= 0.0:
			_mir_gh[i] = 0.0
		elif absf(_mir_gh[i] - tgh) > 0.08:
			_mir_gh[i] = tgh
		if i < sw.size() and int(sw[i]) > (int(psw[i]) if i < psw.size() else 0):
			pl.do_tackle_swing()          # anim + coil + whoosh, exactly as couch
	# --- scoreboard facts
	if state.get("pts", []) != prev.get("pts", []) or ci != pci:
		var pts: Array = state.get("pts", [])
		for i in mini(pts.size(), players.size()):
			points[i] = int(pts[i])
		_rebuild_scoreboard()
	# --- floor coins (list sync; pickup tick on shrink)
	var coins: Array = state.get("coins", [])
	if coins != prev.get("coins", []):
		if coins.size() < Array(prev.get("coins", [])).size():
			Sfx.play("card", -10.0)
		_mir_sync_coins(coins)
	# --- event-counter juice (grabs/drops/banks/geysers/punished/leaks)
	_mir_event_juice(state, prev)
	# --- the closing bell, mirrored
	_mir_bell(state.get("bell", []), prev.get("bell", []))
	# --- the champion moment
	if phase == Phase.MATCH_END and not _mir_champ_done:
		var champ := int(state.get("champ", -1))
		if champ >= 0 and champ < players.size():
			_mir_champ_done = true
			if _stretch != null:
				_stretch.match_ended()
			(players[champ] as GreedPlayer).cheer()
			_confetti((players[champ] as GreedPlayer).global_position + Vector3(0, 1.8, 0),
				roster[champ].color)
			if not _reduced_motion():
				_shake = maxf(_shake, 0.5)


func _apply_mir_timer(tmr: String, ptmr: String) -> void:
	if tmr == timer_label.text:
		return
	timer_label.text = tmr
	if not tmr.is_valid_int():
		return
	var remain := int(tmr)
	timer_label.add_theme_color_override("font_color",
		Color(1, 0.3, 0.2) if remain <= 10 else Color(1, 0.92, 0.6))
	# final-stretch tick ladder plays LOCALLY off the mirrored countdown
	if remain <= 10 and remain >= 1 and ptmr.is_valid_int() and int(ptmr) == remain + 1:
		_bell_tick(lerpf(1.0, 1.55, (10 - remain) / 9.0), -9.0)
	# FINAL STRETCH timer pulse (kit ticks stay off — the bell owns the audio)
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


func _mir_sync_coins(list: Array) -> void:
	var want := list.size() / 2
	while floor_coins.size() > want:
		var c: Dictionary = floor_coins.pop_back()
		(c.node as Node3D).queue_free()
	while floor_coins.size() < want:
		var k := floor_coins.size()
		_make_coin(Vector2(float(list[k * 2]), float(list[k * 2 + 1])))
	for k in want:
		var pos := Vector2(float(list[k * 2]), float(list[k * 2 + 1]))
		var c: Dictionary = floor_coins[k]
		if (c.pos as Vector2) != pos:
			c.pos = pos
			(c.node as Node3D).global_position = Vector3(pos.x, 0.35, pos.y)


func _mir_event_juice(state: Dictionary, prev: Dictionary) -> void:
	var ev: Array = state.get("ev", [])
	var pev: Array = prev.get("ev", [0, 0, 0, 0, 0, 0])
	if ev.size() < 6:
		return
	while pev.size() < 6:
		pev.append(0)
	# GRAB — the pot changed hands
	if int(ev[0]) > int(pev[0]):
		Sfx.play("confirm", -2.0)
		if carrier_index >= 0:
			_flash_pot("GRABBED!", roster[carrier_index].color)
		_mir_snap_once("greed_mirror_carry")
	# DROP — a mug landed: full couch impact, banner rides the state
	if int(ev[1]) > int(pev[1]):
		var ld: Array = state.get("ld", [-1, -1])
		var v := int(ld[0])
		var t := int(ld[1])
		if v >= 0 and v < players.size():
			var vp: GreedPlayer = players[v]
			vp.flash_pop()
			var kdir := Vector3.FORWARD
			if t >= 0 and t < players.size():
				kdir = vp.global_position - (players[t] as GreedPlayer).global_position
			_spark_burst(vp.global_position + Vector3(0, 1.0, 0), kdir,
				roster[maxi(t, 0)].color, 1.0)
			_coin_burst(vp.global_position + Vector3(0, 1.0, 0), 22)
		Sfx.play("splat", -1.0)
		Sfx.play("death", -6.0)
		if not _reduced_motion():
			_shake = maxf(_shake, 0.45)
		_hit_pause()
		_mir_snap_once("greed_mirror_drop")
	# BANK — the ceremony (banner text rides the state; the rest is local)
	if int(ev[2]) > int(pev[2]):
		var lb: Array = state.get("lb", [-1, 0])
		var p := int(lb[0])
		if p >= 0 and p < players.size():
			var at := chute_pos(p)
			var world := Vector3(at.x, 0.2, at.y)
			Sfx.play("match_win")
			if not _reduced_motion():
				_shake = maxf(_shake, 0.5)
			_coin_rain(world, mini(int(lb[1]), 40), roster[p].color)
			_confetti(world + Vector3(0, 1.4, 0), roster[p].color)
			(players[p] as GreedPlayer).cheer()
			if p < chute_lights.size():
				var mat := (chute_lights[p] as MeshInstance3D).material_override as StandardMaterial3D
				if mat:
					var tw := create_tween()
					mat.emission_energy_multiplier = 3.5
					tw.tween_property(mat, "emission_energy_multiplier", _strobe_base, 1.2)
		_mir_snap_once("greed_mirror_bank")
	# GEYSER — the +5 burst
	if int(ev[3]) > int(pev[3]):
		pot.geyser()
		Sfx.play("bumper", -3.0)
		_flash_pot("+%d!" % BURST_AMOUNT, Color(1.0, 0.9, 0.35))
	# GREED PUNISHED — the scatter (banner rides the state)
	if int(ev[4]) > int(pev[4]):
		_coin_burst(pot.global_position + Vector3(0, 1.0, 0),
			mini(int(prev.get("pv", 30)) * 2, 90))
		Sfx.play("grudge")
		if not _reduced_motion():
			_shake = maxf(_shake, 0.7)
	# DASH LEAK — the carrier bled coins to escape
	if int(ev[5]) > int(pev[5]) and carrier_index >= 0:
		_leak_burst((players[carrier_index] as GreedPlayer).global_position)
		_flash_pot("-%d" % DASH_COIN_COST, Color(1.0, 0.5, 0.3))


func _mir_bell(bell: Array, pbell: Array) -> void:
	if bell.size() < 4:
		return
	while pbell.size() < 4:
		pbell.append(0)
	if int(bell[0]) > int(pbell[0]):      # LAST BANKS! (banner rides the state)
		Sfx.play("grudge", -6.0)
		pot.bell_pulse()
		if _stretch != null:
			_stretch.escalate()   # FINAL STRETCH fires client-side off the bell fact
		_mir_snap_once("greed_mirror_bell")
	elif int(bell[0]) < int(pbell[0]) and _stretch != null:
		_stretch.round_reset()    # bell fact cleared = a fresh round began
	if int(bell[1]) > int(pbell[1]):      # the pot grows restless
		pot.restless(1.6)
		Sfx.play("grudge", -10.0)
	var app := int(bell[2]) == 1
	if not app and _bell_app:
		_set_bell_approach(false)
	_bell_app = app                       # _process strobes the mirrored pad
	var n := int(bell[3])
	if n > int(pbell[3]) and n > 0:       # rising approach ticks, same ladder
		_bell_tick(1.0 + 0.06 * float(n - 1), -10.0)


## CLIENT, per physics tick: pawn glide + grab-hold fill + pot follow + arrows —
## everything that must be smoother than the 20 Hz snapshots.
func _mirror_tick(delta: float) -> void:
	if _mir.is_empty():
		return
	var pp: Array = _mir.get("p", [])
	for i in players.size():
		var b := i * 7
		if b + 6 >= pp.size():
			break
		var pl: GreedPlayer = players[i]
		pl.net_pose(delta, Vector3(float(pp[b]), 0.1, float(pp[b + 1])),
			float(pp[b + 2]), int(pp[b + 3]) == 1, int(pp[b + 4]) == 1)
		# THE TENSION: the grab-hold ring fills at the host's real rate between
		# snapshots (host adds delta per tick too), resynced on every apply.
		if float(pp[b + 6]) > 0.0:
			_mir_gh[i] = minf(_mir_gh[i] + delta, GRAB_TIME)
		pl.show_grab_progress(_mir_gh[i] / GRAB_TIME)
	_update_pot_transform()
	_update_hud()


## CLIENT: my aim, computed against my own mirrored render (doc 10 §1.3) and
## relayed as a unit vector inside the 30 Hz input packet.
func _net_aim() -> Dictionary:
	var my := NetSession.my_seat()
	var aim := Vector3.ZERO
	if my >= 0 and my < players.size():
		aim = PlayerInput.get_aim_dir(my, (players[my] as GreedPlayer).global_position, cam)
	return {"aim": aim, "aim_screen": Vector2.ZERO}


func _mir_snap_once(tag: String) -> void:
	if _mir_snaps.has(tag):
		return
	_mir_snaps[tag] = true
	VerifyCapture.snap(tag)


# ===========================================================================
# FX
# ===========================================================================
## HIT KIT §B1 Phase 2 hitstop. Softened from 0.05 -> 0.15 time_scale: a 0.05
## freeze on every tackle read as a lurch, not impact (research fix #2). Micro-
## hitstop 0.15 for 45ms; one at a time (the _slowmo guard); reserved slow-mo
## (deep 0.05) stays for round-deciding KOs elsewhere. Skipped in reduced-motion.
func _hit_pause() -> void:
	if _slowmo or _reduced_motion():
		return
	_slowmo = true
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo = false


func _reduced_motion() -> bool:
	return not bool(PartySetup.pref("screen_shake", true))


## HIT KIT §B1 spark burst — a one-shot cone of sparks along the knockback dir at
## the contact point. Kept even in reduced-motion (it's a read, not a shake).
## amount = round(8*strength) capped at 14, white->attacker color, auto-freed.
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


func _coin_burst(pos: Vector3, amount: int) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.amount = maxi(amount, 1)
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -11.0, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.1
	mesh.height = 0.03
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.metallic = 0.8
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _coin_rain(pos: Vector3, amount: int, _color: Color) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos + Vector3(0, 4.5, 0)
	p.one_shot = true
	p.amount = maxi(amount, 6)
	p.lifetime = 1.3
	p.explosiveness = 0.5
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -14.0, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.12
	mesh.height = 0.035
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.2)
	mat.metallic = 0.8
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.12)
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _leak_burst(pos: Vector3) -> void:
	_coin_burst(pos + Vector3(0, 0.9, 0), 8)
	Sfx.play("card", -6.0)


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


# ===========================================================================
# World build
# ===========================================================================
func _build_world() -> void:
	# THE HOUSE LOOK -- CANDLELIT vault (core/env_kit.gd). Greed is a warm heist
	# interior: an amber key rakes the felt table for deep shadow falloff, strong
	# SSAO grounds the crates + pot, and the high-threshold glow blooms the gilded
	# pot and the four carrier-chute pads (the heroes) without touching the UI.
	# Replaces the old flat FILMIC sky-env + hand-rolled sun/fill.
	EnvKit.apply(self, EnvKit.CANDLELIT, {
		"key_angle": Vector3(-55.0, 32.0, 0.0),   # keep the old vault-sun rake
		"key_energy": 1.1,
		"ambient_energy": 0.5,       # a hair over base so all four pawns read on the felt
		"glow_intensity": 0.78,      # let the gilded pot + chute glows bloom prouder
	})
	# the scene's static $Sun is superseded by EnvKit's key rig
	sun.visible = false
	sun.light_energy = 0.0

	# vault floor (warm wood)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fshape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(ARENA_HALF * 2.0, 0.4, ARENA_HALF * 2.0)
	fshape.shape = fbox
	fshape.position.y = -0.2
	floor_body.add_child(fshape)
	var fmesh := MeshInstance3D.new()
	var fbm := BoxMesh.new()
	fbm.size = Vector3(ARENA_HALF * 2.0, 0.4, ARENA_HALF * 2.0)
	fmesh.mesh = fbm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.34, 0.22, 0.13)
	fmat.roughness = 0.85
	fmesh.material_override = fmat
	fmesh.position.y = -0.2
	floor_body.add_child(fmesh)
	add_child(floor_body)

	# a felt "money-pit" inlay circle under the pedestal
	var inlay := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = 3.2
	im.bottom_radius = 3.2
	im.height = 0.02
	inlay.mesh = im
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color(0.16, 0.28, 0.20)
	imat.roughness = 0.9
	inlay.material_override = imat
	inlay.position.y = 0.012
	add_child(inlay)

	_build_walls()
	_build_pedestal()
	_build_chutes()
	_build_crates()

	# pot
	pot = GreedPot.new()
	pot.name = "Pot"
	add_child(pot)
	pot.build()
	pot.global_position = Vector3(0, 0.55, 0)
	pot.update_value(pot_value)

	# camera: fixed 3/4, whole vault in frame
	cam.position = Vector3(0, 15.5, 12.8)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.fov = 56.0
	_cam_base = cam.global_transform


func _build_walls() -> void:
	var t := 0.4
	var h := 1.4
	var specs := [
		[Vector3(0, h * 0.5, -ARENA_HALF), Vector3(ARENA_HALF * 2.0, h, t)],
		[Vector3(0, h * 0.5, ARENA_HALF), Vector3(ARENA_HALF * 2.0, h, t)],
		[Vector3(-ARENA_HALF, h * 0.5, 0), Vector3(t, h, ARENA_HALF * 2.0)],
		[Vector3(ARENA_HALF, h * 0.5, 0), Vector3(t, h, ARENA_HALF * 2.0)],
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
		mat.albedo_color = Color(0.28, 0.18, 0.11)
		mat.roughness = 0.8
		mi.material_override = mat
		body.add_child(mi)
		# gold trim cap along the top
		var trim := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(sz.x + 0.05, 0.12, sz.z + 0.05)
		trim.mesh = tm
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.85, 0.68, 0.2)
		tmat.metallic = 0.8
		tmat.roughness = 0.3
		tmat.emission_enabled = true
		tmat.emission = Color(0.6, 0.45, 0.1)
		tmat.emission_energy_multiplier = 0.3
		trim.material_override = tmat
		trim.position.y = h * 0.5 + 0.02
		body.add_child(trim)
		add_child(body)


func _build_pedestal() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.85
	cyl.height = 0.5
	cs.shape = cyl
	cs.position.y = 0.25
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.85
	cm.bottom_radius = 1.0
	cm.height = 0.5
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.32, 0.18)
	mat.roughness = 0.6
	mat.metallic = 0.2
	mi.material_override = mat
	mi.position.y = 0.25
	body.add_child(mi)
	add_child(body)


func _build_chutes() -> void:
	chute_lights.clear()
	for i in 4:
		var c := chute_pos(i)
		# glowing bank pad (tinted to the owner in _tint_chute)
		var pad := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = BANK_RADIUS
		pm.bottom_radius = BANK_RADIUS
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
		chute_lights.append(pad)
		# a back funnel wall behind the pad (the "chute")
		var funnel := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 1.4
		tm.bottom_radius = 0.5
		tm.height = 1.3
		funnel.mesh = tm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.22, 0.16, 0.12)
		fmat.roughness = 0.8
		funnel.material_override = fmat
		var back := c + (-c).normalized() * -0.9   # pushed outward toward corner
		funnel.position = Vector3(back.x, 0.65, back.y)
		add_child(funnel)


func _tint_chute(i: int, color: Color) -> void:
	if i >= chute_lights.size():
		return
	var mat := (chute_lights[i] as MeshInstance3D).material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = color
		mat.emission = color
		mat.emission_energy_multiplier = 0.9


func _build_crates() -> void:
	var spots := [Vector2(3.1, 0.2), Vector2(-3.1, -0.2), Vector2(0.2, 3.1), Vector2(-0.2, -3.1)]
	for sp in spots:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.95, 0.95, 0.95)
		cs.shape = box
		cs.position.y = 0.48
		body.add_child(cs)
		# Visual: Meshy crate filling the same 0.95 footprint the collider
		# implies, fixed varied yaws so the four vaults don't read as clones.
		# Primitive-box fallback if the asset is missing. Visual only.
		var crate_glb := "res://assets/models/meshy/crate.glb"
		if ResourceLoader.exists(crate_glb):
			var yaws := [0.0, 90.0, 180.0, 270.0]
			var vis := MeshyProp.instance(crate_glb, 0.95, yaws[spots.find(sp)])
			# clamp the visual to the 0.95 box collider (model is elongated)
			var caabb := MeshyProp.merged_aabb_of_scaled(vis.get_node("Model"))
			if caabb.size.x > 0.98:
				vis.scale.x = 0.98 / caabb.size.x
			if caabb.size.z > 0.98:
				vis.scale.z = 0.98 / caabb.size.z
			body.add_child(vis)
		else:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.95, 0.95, 0.95)
			mi.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.36, 0.2)
			mat.roughness = 0.85
			mi.material_override = mat
			mi.position.y = 0.48
			body.add_child(mi)
		body.position = Vector3(sp.x, 0, sp.y)
		add_child(body)


func _build_arrows() -> void:
	arrows = GreedEdgeArrows.new()
	arrows.name = "EdgeArrows"
	ui.add_child(arrows)


# ===========================================================================
# Config / args
# ===========================================================================
func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--greedbots":
			_bots_all = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--rounds="):
			_cli_rounds = int(arg.trim_prefix("--rounds="))
		elif arg.begins_with("--roundtime="):
			_cli_roundtime = float(arg.trim_prefix("--roundtime="))
		elif arg == "--greedcap":
			_cap_on = true
		elif arg.begins_with("--outdir="):
			_cap_dir = arg.trim_prefix("--outdir=")
		elif arg.begins_with("--greedtest="):
			_test_mode = arg.trim_prefix("--greedtest=")
		elif arg.begins_with("--aimprobe="):
			_aim_probe_on = true
			_aim_probe_deg = float(arg.trim_prefix("--aimprobe="))
		elif arg == "--hitkitcap":
			_hitkit_cap = true
		elif arg == "--greedbellcap":
			_bell_cap = true
	if _cap_on or _aim_probe_on or _hitkit_cap or _bell_cap:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _cap_dir))


func _default_config() -> Dictionary:
	var n := _cli_players
	if _aim_probe_on:
		n = 2   # p0 = KBM human under the cursor, p1 = an inert stand-in carrier
	PlayerInput.auto_assign(n)
	if _aim_probe_on:
		PlayerInput.assign(0, -4)     # KBM human
		PlayerInput.assign(1, -99)    # inert: no input, stands still as the carrier
		var av := deg_to_rad(_aim_probe_deg)
		PlayerInput.set_debug_aim(0, Vector3(sin(av), 0.0, cos(av)))
	var r: Array = []
	for i in n:
		r.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": CHAR_FALLBACKS[i],
			"device": PlayerInput.device_of(i),
			"bot": false if (_aim_probe_on or _bell_cap) else PlayerInput.standalone_bot_default(i),
		})
	return {"roster": r, "rounds": ROUNDS, "rng_seed": _cli_seed, "practice": false}


# ===========================================================================
# Screenshot capture (event/state based — reliable regardless of framerate)
# ===========================================================================
func _cap_event(tag: String) -> void:
	if not _cap_on:
		return
	if _cap_done.has(tag):
		return
	# hold the shot a beat so the carrier glow / arrows / scatter are on screen
	get_tree().create_timer(0.35, true, false, true).timeout.connect(
		func() -> void: _grab_shot(tag, false))
	_cap_done[tag] = true


func _capture_beats() -> void:
	# a clean "vault + growing pot" baseline early in round 1
	if round_num == 1 and round_t >= 3.0 and not _cap_done.has("arena"):
		_cap_done["arena"] = true
		_grab_shot("arena", false)
	# quit once the whole arc (grab -> hunt -> drop -> bank) is on film, or on a
	# safety timeout so a quiet run still terminates
	var have_all: bool = _cap_done.has("arena") and _cap_done.has("grab") \
		and _cap_done.has("drop") and _cap_done.has("bank")
	if (have_all or round_t > 60.0) and not _cap_done.has("_quit"):
		_cap_done["_quit"] = true
		get_tree().create_timer(1.2, true, false, true).timeout.connect(
			func() -> void:
				print("GREED_CAP_DONE")
				get_tree().quit())


func _grab_shot(tag: String, quit_after: bool) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/greed_%s.png" % [_cap_dir, tag]
		img.save_png(path)
		print("GREED_CAP ", path)
	else:
		print("GREED_CAP_SKIP_HEADLESS ", tag)
	if quit_after:
		get_tree().quit()


# ===========================================================================
# Pursuit-tuning test (spec Risk: "turtle camping / interception possible")
# ===========================================================================
## Kinematic model of the make-or-break chase, using the REAL movement
## constants (carry speed, dash speed/time/cd/i-frames, tackle range, chute
## geometry). A carrier grabs at centre and runs to its OWN (farthest) chute; a
## dashing chaser starts at an ADJACENT chute and pursues. Both may dash. We
## count how often the chaser lands a tackle before the carrier banks. Spec bar:
## catchable in >=60% of runs.
func _run_intercept_test() -> void:
	var trials := 80
	var catches := 0
	var trng := RandomNumberGenerator.new()
	trng.seed = _cli_seed
	var carry_speed := GreedPlayer.MOVE_SPEED * GreedPlayer.CARRY_SPEED_MULT
	var base_speed := GreedPlayer.MOVE_SPEED
	var dt := 1.0 / 60.0
	for tr in trials:
		var c_idx := trng.randi_range(0, 3)
		var goal := chute_pos(c_idx)
		var adj := _adjacent_corner_indices(c_idx)
		var chaser_corner: int = adj[trng.randi_range(0, adj.size() - 1)]
		var carrier := Vector2(trng.randf_range(-0.7, 0.7), trng.randf_range(-0.7, 0.7))
		var chaser := chute_pos(chaser_corner)
		var carrier_dash_cd := trng.randf_range(0.0, GreedPlayer.DASH_CD)
		var chaser_dash_cd := trng.randf_range(0.0, 0.4)
		var carrier_dash_t := -1.0
		var chaser_dash_t := -1.0
		var carrier_iframe := 0.0
		var carrier_vel := Vector2.ZERO
		var caught := false
		var t := 0.0
		while t < 6.0:
			t += dt
			carrier_dash_cd = maxf(0.0, carrier_dash_cd - dt)
			chaser_dash_cd = maxf(0.0, chaser_dash_cd - dt)
			carrier_iframe = maxf(0.0, carrier_iframe - dt)
			var gap := chaser.distance_to(carrier)
			# --- carrier: run to goal; dash to flee if hunter is closing ---
			var cdir := (goal - carrier)
			cdir = cdir.normalized() if cdir.length() > 0.001 else Vector2.ZERO
			var cspeed := carry_speed
			if carrier_dash_t >= 0.0:
				carrier_dash_t += dt
				cspeed = GreedPlayer.DASH_SPEED * GreedPlayer.CARRY_DASH_MULT
				if carrier_dash_t >= GreedPlayer.DASH_TIME:
					carrier_dash_t = -1.0
			elif gap < 2.6 and carrier_dash_cd <= 0.0:
				carrier_dash_t = 0.0
				carrier_dash_cd = GreedPlayer.DASH_CD
				carrier_iframe = GreedPlayer.DASH_IFRAME
				cspeed = GreedPlayer.DASH_SPEED * GreedPlayer.CARRY_DASH_MULT
			carrier_vel = cdir * cspeed
			carrier += carrier_vel * dt
			# --- chaser: LEAD pursuit (aim where the carrier will be), dash ---
			var chspeed := base_speed
			if chaser_dash_t >= 0.0:
				chaser_dash_t += dt
				chspeed = GreedPlayer.DASH_SPEED
				if chaser_dash_t >= GreedPlayer.DASH_TIME:
					chaser_dash_t = -1.0
			elif chaser_dash_cd <= 0.0:
				chaser_dash_t = 0.0
				chaser_dash_cd = GreedPlayer.DASH_CD
				chspeed = GreedPlayer.DASH_SPEED
			var lead_t: float = clampf(gap / 6.6, 0.0, 0.9)   # ~avg chaser speed w/ dashes
			var aim := carrier + carrier_vel * lead_t
			var chdir := (aim - chaser)
			chdir = chdir.normalized() if chdir.length() > 0.001 else Vector2.ZERO
			chaser += chdir * chspeed * dt
			# --- resolve ---
			if chaser.distance_to(carrier) <= TACKLE_RANGE and carrier_iframe <= 0.0:
				caught = true
				break
			if carrier.distance_to(goal) <= BANK_RADIUS:
				break
		if caught:
			catches += 1
	var rate := float(catches) / float(trials)
	var verdict := "PASS" if rate >= 0.6 else "FAIL"
	print("GREED_INTERCEPT trials=%d catches=%d rate=%.2f (bar>=0.60) %s" % [
		trials, catches, rate, verdict])
	get_tree().quit(0 if rate >= 0.6 else 1)


func _adjacent_corner_indices(i: int) -> Array:
	var c: Vector2 = CORNER_SIGNS[i]
	var out: Array = []
	for j in 4:
		if j == i:
			continue
		var o: Vector2 = CORNER_SIGNS[j]
		# adjacent = shares exactly one axis sign (edge neighbour, not diagonal)
		if (is_equal_approx(o.x, c.x)) != (is_equal_approx(o.y, c.y)):
			out.append(j)
	return out


# ===========================================================================
func _log(msg: String) -> void:
	var f := -1
	if _vc != null:
		f = int(_vc.frame)
	print("GREED_EVT t=%.2f frame=%d | %s" % [game_t, f, msg])


func _unhandled_input(event: InputEvent) -> void:
	if _standalone and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# ===========================================================================
# Mouse-aim verification (--aimprobe=<deg>): p0 (a KBM human) stands next to an
# inert carrier facing 90 deg off a synthetic cursor. Shot 1 is the baseline;
# then a REAL tackle (_attempt_tackle) fires -> p0 faces + pounces toward the
# cyan aim ray. Shot 2 shows the lunge going to the cursor, not the white face.
# ===========================================================================
func _run_greed_probe() -> void:
	while phase != Phase.PLAY:
		await get_tree().physics_frame
	var me: GreedPlayer = players[0]
	var cp: GreedPlayer = players[1]
	var aim_yaw := deg_to_rad(_aim_probe_deg)
	var face_yaw := aim_yaw + PI * 0.5
	me.global_position = Vector3(0, 0.1, 0)
	me.yaw = face_yaw
	me.velocity = Vector3.ZERO
	cp.global_position = Vector3(1.1, 0.1, 0.5)      # within TACKLE_RANGE of p0
	cp.immune_t = 0.0
	carrier_index = 1
	cp.set_carrier(true)
	pot_state = PotState.CARRIED
	pot.set_carried(true)
	pot_value = 20
	var origin := Vector3(0, 0.1, 0)
	_probe_arrow(origin, face_yaw, Color(1, 1, 1), 3.0)                 # facing (white)
	_probe_arrow(origin, aim_yaw, Color(0.2, 0.95, 1.0), 3.0)          # cursor aim (cyan)
	await get_tree().create_timer(0.5).timeout
	await _probe_grab("facing")
	var p0_before := me.global_position
	print("GREED_AIMPROBE face=%.0fdeg aim=%.0fdeg body_before=%.0fdeg pos=(%.2f,%.2f)" % [
		rad_to_deg(face_yaw), _aim_probe_deg, rad_to_deg(me.yaw), p0_before.x, p0_before.z])
	_attempt_tackle(0)
	await get_tree().create_timer(0.16).timeout                        # mid-lunge
	await _probe_grab("acting")
	var moved := me.global_position - p0_before
	var move_yaw := atan2(moved.x, moved.z)
	print("GREED_AIMPROBE body_after=%.0fdeg lunge_dir=%.0fdeg matches_aim=%s (moved %.2fm)" % [
		rad_to_deg(me.yaw), rad_to_deg(move_yaw), str(absf(rad_to_deg(move_yaw) - _aim_probe_deg) < 20.0), moved.length()])
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


# ===========================================================================
# HIT KIT / COOLDOWN RING capture (--hitkitcap, windowed): stages each feel
# moment deterministically and films it, then quits. Gameplay is frozen so the
# tween/particle frame we want is guaranteed on screen (frame-indexed --shots
# cannot land a 0.05s coil reliably). Verify-only; no effect on a normal match.
# ===========================================================================
func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _run_hitkit_cap() -> void:
	while phase != Phase.PLAY:
		await get_tree().physics_frame
	_freeze = true
	banner.visible = false               # declutter the staged shots
	var a: GreedPlayer = players[0]      # attacker (on the far side)
	var b: GreedPlayer = players[1]      # victim (nearer the camera)
	# clean patch right-of-centre, clear of the pedestal + crates; knockback runs
	# toward the camera (+z) so the spark cone is face-on and legible.
	a.global_position = Vector3(2.2, 0.1, 0.4)
	a.yaw = 0.0                          # face +z (toward the victim / camera)
	b.global_position = Vector3(2.2, 0.1, 2.1)
	b.yaw = PI
	a.set_move_intent(Vector2.ZERO)
	b.set_move_intent(Vector2.ZERO)
	for i in range(2, players.size()):
		(players[i] as GreedPlayer).global_position = Vector3(6.2, 0.1, 6.2)
	await _settle(0.25)
	# 1) WINDUP COIL — fire the swing, catch the crouch mid-tween (~0.05s in)
	a.do_tackle_swing()
	await _settle(0.05)
	await _grab_shot("hitkit_coil", false)
	await _settle(0.3)
	# 2) IMPACT — victim squash-pop + spark cone along the knockback (+z, face-on)
	b.flash_pop()
	_spark_burst(b.global_position + Vector3(0, 1.0, 0), Vector3(0, 0, 1), roster[0].color, 1.3)
	await _settle(0.09)
	await _grab_shot("hitkit_impact", false)
	await _settle(0.35)
	# 3) DASH COOLDOWN RING — held at half fill
	a.dash_cd = GreedPlayer.DASH_CD * 0.5
	await _settle(0.14)
	await _grab_shot("hitkit_ring_fill", false)
	# 4) READY-FLASH — drive the ring to full so it flashes, film inside the window
	a.dash_cd = GreedPlayer.DASH_CD * 0.5
	await _settle(0.06)
	a.dash_cd = 0.0
	await _settle(0.04)
	await _grab_shot("hitkit_ring_ready", false)
	await _settle(0.15)
	print("GREED_HITKIT_CAP_DONE")
	get_tree().quit()


# ===========================================================================
# CLOSING BELL capture (--greedbellcap, windowed): stages each §6.1-3 beat on
# a LIVE round clock (the bell code runs untouched — we only move round_t and
# park a staged carrier) and films it. Verify-only; no effect on normal play.
# ===========================================================================
func _run_bell_cap() -> void:
	while phase != Phase.PLAY:
		await get_tree().physics_frame
	banner.visible = false
	hint_label.visible = false
	# 1) §6.2 approach drama: a 22-coin pot parked 2.4 m from its OWN chute
	#    (inside the 3.0 m drama ring, outside the 1.75 m bank ring)
	round_t = round_time - 26.0          # remain 26: no other bell beat yet
	_do_grab(0)
	pot_value = 22
	var c := chute_pos(0)
	var inward := (-c).normalized() * 2.4
	(players[0] as GreedPlayer).global_position = Vector3(c.x + inward.x, 0.1, c.y + inward.y)
	await _settle(0.9)
	await _grab_shot("bell_approach", false)
	# 2) §6.3 the T-20 straight line (nobody has banked)
	round_t = round_time - 20.2
	await _settle(0.7)
	await _grab_shot("bell_warn", false)
	# 3) §6.1 the bell: LAST BANKS! + pot Label3D pulse
	round_t = round_time - 15.2
	await _settle(0.45)
	await _grab_shot("bell_lastbanks", false)
	# 4) the final stretch: red timer + rising tick ladder
	round_t = round_time - 9.6
	await _settle(0.8)
	await _grab_shot("bell_ticks", false)
	print("GREED_BELLCAP_DONE")
	get_tree().quit()


func _probe_arrow(origin: Vector3, yaw_a: float, col: Color, length: float) -> void:
	var dir := Vector3(sin(yaw_a), 0.0, cos(yaw_a))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, length)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = origin + dir * (length * 0.5) + Vector3(0, 1.1, 0)
	mi.rotation.y = yaw_a
	add_child(mi)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.42, 0.42, 0.42)
	tip.mesh = tm
	tip.material_override = mat
	tip.position = origin + dir * length + Vector3(0, 1.1, 0)
	add_child(tip)


func _probe_grab(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("GREED_AIMPROBE_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/greed_aim_%s.png" % [_cap_dir, tag]
	img.save_png(path)
	print("GREED_AIMPROBE_CAP ", path)
