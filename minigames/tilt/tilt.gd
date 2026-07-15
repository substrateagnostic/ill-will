extends Minigame
## TILT — everyone stands on ONE giant platter balanced on a pin. Every
## player's weight tilts the shared world; coins make you heavier (more
## influence, worse footing); last one aboard wins; the fallen become
## seagulls who bomb the survivors. Best-of-5 rounds.
##
## v1.1 — SHOVE CLASH: shoves have a 0.12s windup (readable tell). If two
## pawns shove EACH OTHER within 0.25s (each inside the other's cone at the
## moment of landing), the shoves CLASH: both take 40% knockback pushed
## apart, both staggered 0.3s, NO royalty for either, sparks + shock ring +
## "CLASH!" floaty + bumper clang. Answering a shove with a shove saves you
## — rim defense is a timing mind-game. Blindside shoves stay uncounterable
## (the victim's cone can't contain an attacker behind them).
##
## v1.2 — BALANCE (doc 09 §3.3-3.4, Alex-signed):
## * OVERTIME INSTEAD OF SPLIT: a timeout with >1 survivor no longer splits
##   the pot. THE ESTATE SPLITS NOTHING — 20s of overtime on a sudden-death
##   platter tilting 1.5x harder. Only if the sea still refuses a verdict at
##   +20s do the survivors split (the old path, now the exception).
## * GULL ASSIST ROYALTY: when a seagull's guano KOs someone (fall within 2s
##   of a slip), the player who most recently shoved that victim (within 3s)
##   collects the +1 royalty — kill_events cause "gull_assist", killer=shover.
##
## Anthology module: root of minigames/tilt/tilt.tscn, extends Minigame.
## Runs standalone too — if begin() hasn't been called 0.5s after _ready,
## self-starts with a 4-player config (GameState colors/names, KayKit
## chars, seed from `--seed=` user arg or 1).
##
## CLI user args (after `--`):
##   --tiltbots           all players seeded self-play bots
##   --seed=N             rng seed for standalone start (default 1)
##   --players=N          standalone roster size 2..4
##   --rounds=N           override rounds (1..5) for quick verification
##   --roundtime=S        override 60s round length (sudden death at 75%)
##   --tilttest=idle      4 pawns idle 30s; |tilt| must stay < 3 deg
##                        (impulse injected at t=5s must settle by t=9s)
##   --tilttest=edge      pawn at rim, platter forced to 20 deg: must slide
##                        off within 8s (proves manual slide model)
##   --tilttest=gull      v1.2 credit chain: recent shove + guano slip + fall
##                        must yield cause "gull_assist", killer = shover,
##                        +1 royalty to the shover
##   --shots=N,...        handled by the VerifyCapture autoload (PNGs)

enum Phase { WAITING, INTRO, PLAY, ROUND_END, MATCH_END }

const CHAR_FALLBACKS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const SPAWN_R := 3.5
const COIN_INTERVAL := 3.0
const COIN_LOOSE_MASS := 0.08
const SHOVE_RANGE := 2.05        # v1.1: +0.35 reach pays for the 0.12s windup
                                 # (a fleeing target covers ~0.54m during it)
const SHOVE_HALF_ANGLE := 55.0   # degrees
const SHOVE_POWER := 7.5
const CLASH_WINDOW := 0.25       # both shoves pressed within this -> CLASH
const CLASH_KB := 0.4            # clash knockback factor (vs full shove)
const ROYALTY_WINDOW := 1.5      # s between shove contact and the fall
const OVERTIME_TIME := 20.0      # tie at the horn: sudden-death overtime length
const GULL_KO_WINDOW := 2.0      # fall this soon after a guano slip = gull KO
const GULL_ASSIST_WINDOW := 3.0  # shove this recent still pays on a gull KO
const BANNER_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const GUANO_GRAV := 14.0
const SLIP_RADIUS := 1.25
const SLIP_TIME := 4.0
const OCEAN_Y := -6.0
const ROUND_POINTS := [4, 2, 1, 0]  # win / survival-order 2/1/0

var roster: Array = []
var rounds_total := 5
var round_num := 1
var round_time := 60.0
var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()
var practice := false

var platter: TiltPlatter
var pawns: Array = []          # TiltPawn per roster slot
var gulls: Dictionary = {}     # player index -> TiltSeagull
var loose_coins: Array = []    # {node: Node3D, l: Vector2}
var splats: Array = []         # {node, mat, l: Vector2, until: float}
var guanos: Array = []         # {node, vel: Vector3, owner: int}

var phase := Phase.WAITING
var phase_t := 0.0
var round_t := 0.0
var game_t := 0.0
var sudden_death := false
var overtime := false
var coin_timer := 0.0
var klaxon_t := 0.0
var _slip_gull := {}           # player -> gull owner of the last guano slip
var _slip_t := {}              # player -> game_t of that slip

var points := {}
var coins_banked := {}
var max_carried := {}
var shove_falls := {}
var gull_hits := {}
var round_wins := {}
var elim_order: Array = []     # current round, in fall order
var _currency: Array = []
var _kill_events: Array = []   # optional contract: {killer,victim,cause} per fall
var _highlights: Array = []
var _results := {}
var _begun := false
var _reported := false
var _standalone := false

var bots: TiltBots
var bot_enabled: Array = []
var _bots_all := false
var _test_mode := ""
var _test_t := 0.0
var _test_next_sample := 0.0
var _test_fail := false
var _test_injected := false
var _cli_seed := 1
var _cli_players := 4
var _cli_rounds := -1
var _cli_roundtime := -1.0
var _dead_hint_demo := false     # --deadhint: seat 0 human, becomes a seagull
var _deadhint_fired := false

var _shake := 0.0
var _last_status := 0.0
var _cam_base: Transform3D
var _slowmo := false
var _vc: Node = null
# THE FINAL STRETCH kit (doc 09 §Q1): sudden death IS tilt's stretch — the kit
# unifies music (light->tense) + last-10s ticks + timer pulse around the
# bespoke "SUDDEN DEATH / THE PIN RISES" drama. Never attached in --tilttest,
# so the idle/edge/gull receipts stay byte-identical.
var _stretch: FinalStretch = null

# ui_kit adoption (doc 14): intro card at load, HudStrip player-order strip for
# live standings, ResultsBoard staged match-end reveal.
var _intro_card: IntroCard = null
var _results_board: ResultsBoard = null
var _hud: HudStrip = null
var _board_running := false
var _snap_hud_done := false      # windowed-verify latch: one HudStrip play snap

# --- ONLINE PHASE 2: the render mirror (docs/design/10 §4.3; house pattern
# copied from minigames/seance/seance.gd). Host runs the WHOLE sim exactly as
# couch; the estate pumps _net_state() (compact public facts) to guests at
# 20 Hz. A client boots THIS scene with config.net_mirror = true: sim, bots
# and input sampling never run — _net_apply() stores facts + fires all juice
# from state DELTAS, _mirror_tick() interpolates at 60 fps. The platter tilt
# is the one transform that moves everything; it gets the smoothest chase.
var _mirror := false
var _mir := {}                    # last applied snapshot (delta source)
var _mir_tilt := Vector2.ZERO     # authoritative tilt target (radians)
var _mir_pawn := []               # per-seat interp targets [st, Vector3/Vector2 data]
var _mir_gull := {}               # seat -> Vector2 XZ target
var _mir_guanos: Array = []       # cosmetic falling bombs: {node, vel}
var _snap_net_tilt := false       # evidence snap latch (host + mirror pair)
var _snap_mir_tilt := false
# host-side wire bookkeeping (counters the mirror turns back into juice):
var _banner_col := "ffffff"
var _shove_n: Array = []          # per seat: windups started
var _knock_n: Array = []          # per seat: hits taken
var _guano_n := {}                # per seat: bombs dropped (as a gull)
var _clash_n := 0
var _clash_pos := Vector3.ZERO
var _win_n := 0                   # round wins banked (confetti trigger)
var _last_win := -1
var _match_winner := -1

@onready var cam: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var banner: Label = $UI/Banner
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows

func _ready() -> void:
	_parse_args()
	_vc = get_node_or_null("/root/VerifyCapture")
	_build_world()
	banner.visible = false
	hint_label.visible = false
	timer_label.text = ""
	round_label.text = ""
	await get_tree().create_timer(0.5).timeout
	if not _begun:
		_standalone = true
		begin(_default_config())

func begin(config: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	roster = config.roster
	_mirror = bool(config.get("net_mirror", false))
	rng.seed = int(config.rng_seed)
	fx_rng.seed = int(config.rng_seed) + 7777
	practice = bool(config.get("practice", false))
	rounds_total = clampi(int(config.get("rounds", 5)), 1, 5)
	if practice:
		rounds_total = 1
	if _cli_rounds > 0:
		rounds_total = clampi(_cli_rounds, 1, 5)
	if _cli_roundtime > 0.0:
		round_time = clampf(_cli_roundtime, 8.0, 120.0)
	if _test_mode == "":
		_stretch = FinalStretch.attach(self, timer_label)
	if not _mirror:
		# fenced from the mirror: bot construction (spec §4.3 begin() split)
		bots = TiltBots.new()
		bots.setup(int(config.rng_seed) ^ 0x5EA9, roster.size())
	# Per-player: a seat is bot-driven if the roster says so (shell sets this
	# from estate._is_bot; standalone fills it from PlayerInput) OR the legacy
	# --tiltbots flag forces ALL bots. Test modes force all seats to bots (their
	# input is overridden to zero anyway). Decided here at begin() from roster
	# data only - never from runtime Input reads - so the sim stays reproducible.
	bot_enabled.clear()
	for i in roster.size():
		bot_enabled.append(not _mirror and (_bots_all or _test_mode != "" or bool(roster[i].get("bot", false))))
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var pawn := TiltPawn.new()
		pawn.name = "Pawn%d" % i
		add_child(pawn)
		pawn.setup(i, str(pl.name), pl.color, str(pl.char_scene), platter.disc)
		pawns.append(pawn)
		platter.add_quadrant_marker(_spawn_angle(i), pl.color)
		points[i] = 0
		coins_banked[i] = 0
		max_carried[i] = 0
		shove_falls[i] = 0
		gull_hits[i] = 0
		round_wins[i] = 0
		_shove_n.append(0)
		_knock_n.append(0)
	_build_hud()
	if _mirror:
		# RENDER MIRROR: world + pawns stand ready; the first _net_apply drives
		# everything. No bots, no round kick, no self-tests. Hint bar is built
		# from THIS machine's bindings (my seat samples locally) — better than
		# mirroring the host's keys.
		phase = Phase.WAITING
		hint_label.text = _controls_bar()
		hint_label.visible = true
		var htw := create_tween()
		htw.tween_interval(7.0)
		htw.tween_callback(func() -> void: _refresh_hint())
		_rebuild_scoreboard()
		print("TILT_MIRROR boot players=%d my_seat=%d" % [roster.size(), NetSession.my_seat()])
		return
	_log("begin players=%d seed=%d rounds=%d bots=%s test=%s" % [
		roster.size(), int(config.rng_seed), rounds_total, str(bot_enabled), _test_mode])
	if _test_mode != "":
		_setup_test()
	else:
		_kickoff()

## ui_kit HudStrip: the shared-camera player-order strip (doc 14 item 9). Built
## for host AND mirror; replaces the bespoke top-right ScorePanel rows. Anchored
## just under the top-center timer so the two never collide.
func _build_hud() -> void:
	var entries: Array = []
	for i in roster.size():
		entries.append({"player": i, "name": str((roster[i] as Dictionary).name),
			"color": (roster[i] as Dictionary).color})
	_hud = HudStrip.make(entries, {"anchor": "top", "y": 72.0,
		"score_type": HudStrip.ScoreType.POINTS, "font_size": 26})
	$UI.add_child(_hud)
	var panel := get_node_or_null("UI/ScorePanel")
	if panel:
		panel.visible = false

## Intro card (ui_kit) at load, then the first round. Test modes never reach
## here (they _setup_test); the card auto-starts after 6s so bot runs flow through.
func _kickoff() -> void:
	_intro_card = IntroCard.new()
	add_child(_intro_card)
	_intro_card.started.connect(_start_round)
	_intro_card.present({
		"name": "TILT",
		"goal": "One platter, one pin. Last one aboard wins the round.",
		"accent": Color(1, 0.82, 0.3),
		"seats": _human_seats(),
		"controls": [
			{"action": "move", "label": "LEAN"},
			{"action": "a", "label": "SHOVE"},
			{"action": "b", "label": "BRACE"},
		],
		"tips": [
			"Answer a shove with a shove to CLASH — no one falls.",
			"Coins make you heavier: more sway, worse footing.",
			"Fall in and you return as a guano-bombing seagull.",
		],
	})
	if _vc != null:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _vc.snap("tilt_intro"))

# -- per-tick orchestration --------------------------------------------------

func _physics_process(delta: float) -> void:
	# THE HOUSE GUARD (spec §4.3): a mirror never simulates. Interp + juice only.
	if _mirror:
		_mirror_tick(delta)
		return
	if phase == Phase.WAITING:
		return
	game_t += delta
	phase_t += delta
	match phase:
		Phase.INTRO:
			_tick_pawns_idle(delta)
			platter.update_tilt(delta, _mass_points())
			if phase_t >= 1.4:
				phase = Phase.PLAY
				round_t = 0.0
				_flash_banner("TILT!", Color(1, 0.85, 0.2), 0.8)
				Sfx.play("confirm")
		Phase.PLAY:
			round_t += delta
			_tick_play(delta)
			if _dead_hint_demo and not _deadhint_fired and round_num == 1 and round_t > 0.8:
				_deadhint_fired = true
				if (pawns[0] as TiltPawn).state == TiltPawn.PState.STANDING:
					_on_water_death(0)   # seat 0 splashes -> returns as a seagull
		Phase.ROUND_END:
			_tick_pawns_idle(delta)
			platter.update_tilt(delta, _mass_points())
			_tick_falling(delta)
			_tick_guano(delta)
			if phase_t >= 3.2:
				round_num += 1
				if round_num > rounds_total:
					_finish_match()
				else:
					_start_round()
		Phase.MATCH_END:
			_tick_pawns_idle(delta)
			platter.update_tilt(delta, _mass_points())
			_tick_falling(delta)
			# The ResultsBoard owns the finish when present; it reports on `done`.
			# The 2.5s gate is the fallback for the no-ceremony path only.
			if not _board_running and phase_t >= 2.5 and not _reported:
				_reported = true
				report_finished(_results)
	if _test_mode != "":
		_tick_test(delta)

func _tick_play(delta: float) -> void:
	# inputs -> standing pawns and gulls
	for p in roster.size():
		var pawn: TiltPawn = pawns[p]
		if pawn.state == TiltPawn.PState.STANDING:
			var inp := _input_for(p, delta)
			if inp.b and pawn.try_brace():
				Sfx.play("confirm", -4.0)
			if inp.a:
				_try_shove(p)
			var slip_owner := _slip_owner(pawn.lpos)
			pawn.in_slip = slip_owner >= 0
			if slip_owner >= 0:
				_slip_gull[p] = slip_owner
				_slip_t[p] = game_t
			pawn.tick(delta, inp.move, platter.tilt)
		elif gulls.has(p):
			var inp := _input_for(p, delta)
			var gull: TiltSeagull = gulls[p]
			gull.tick(delta, inp.move)
			if inp.a and gull.can_bomb():
				gull.drop()
				_spawn_guano(gull.global_position, p)
	# shoves whose windup just completed land NOW (clash check inside)
	for p in roster.size():
		var pawn: TiltPawn = pawns[p]
		if pawn.consume_shove_release() and pawn.state == TiltPawn.PState.STANDING:
			_resolve_shove(p)
	_separate_pawns()
	# edge falls
	for p in roster.size():
		if phase != Phase.PLAY:
			break
		var pawn: TiltPawn = pawns[p]
		if pawn.state == TiltPawn.PState.STANDING and pawn.lpos.length() > TiltPlatter.FALL_R:
			_on_edge_fall(p)
	platter.update_tilt(delta, _mass_points())
	_tick_falling(delta)
	_tick_guano(delta)
	_tick_coins(delta)
	_tick_splats()
	# low-side klaxon
	if platter.tilt_deg() > TiltPlatter.WARN_DEG:
		klaxon_t -= delta
		if klaxon_t <= 0.0:
			Sfx.play("invalid", -6.0)
			klaxon_t = 0.9
	else:
		klaxon_t = 0.0
	# sudden death
	if phase == Phase.PLAY and not sudden_death and _test_mode == "" \
			and round_t >= round_time * 0.75 and _standing_count() > 1:
		_start_sudden_death()
	# timeout — a tie at the horn triggers overtime instead of a split (v1.2)
	if phase == Phase.PLAY and round_t >= round_time:
		if not overtime:
			if _standing_count() > 1 and _test_mode == "":
				_start_overtime()
			else:
				_end_round("timeout")
		elif round_t >= round_time + OVERTIME_TIME:
			_end_round("overtime_split")
	# evidence snap (online nights only): the platter mid-tilt, paired with the
	# mirror's own "mirror_tilting" snap fired from the same mirrored condition.
	if not _snap_net_tilt and NetSession.has_guests() and platter.tilt_deg() >= 8.0:
		_snap_net_tilt = true
		VerifyCapture.snap("net_tilting")
	# windowed-verify: one snap mid-round-1 showing the live HudStrip
	if _vc != null and not _snap_hud_done and round_num == 1 and round_t >= 4.0:
		_snap_hud_done = true
		_vc.snap("tilt_hud")
	# periodic status for verification logs
	if round_t - _last_status >= 5.0:
		_last_status = round_t
		var rr: Array = []
		for pw in pawns:
			var tp2: TiltPawn = pw
			if tp2.state == TiltPawn.PState.STANDING:
				rr.append("%.1f" % tp2.lpos.length())
		_log("status tilt=%.1f standing=%d radii=[%s]" % [
			platter.tilt_deg(), _standing_count(), ", ".join(rr)])

## Non-PLAY phases: pawns hold their footing (no fresh slide — the drama is
## paused) and can never drift past the rim while a banner is up.
func _tick_pawns_idle(delta: float) -> void:
	for p in roster.size():
		var pawn: TiltPawn = pawns[p]
		if pawn.state == TiltPawn.PState.STANDING:
			pawn.in_slip = false
			pawn.tick(delta, Vector2.ZERO, Vector2.ZERO)
			if pawn.lpos.length() > 6.4:
				pawn.lpos = pawn.lpos.normalized() * 6.4
				pawn.slide = Vector2.ZERO
		elif gulls.has(p):
			gulls[p].tick(delta, Vector2.ZERO)

func _tick_falling(delta: float) -> void:
	for p in roster.size():
		var pawn: TiltPawn = pawns[p]
		if pawn.state == TiltPawn.PState.FALLING:
			pawn.tick_falling(delta)
			if pawn.global_position.y < OCEAN_Y + 0.6:
				_on_water_death(p)

func _tick_coins(delta: float) -> void:
	if _test_mode != "":
		return
	if not sudden_death:
		coin_timer -= delta
		if coin_timer <= 0.0:
			coin_timer = COIN_INTERVAL
			_spawn_coin()
	# pickups
	for p in roster.size():
		var pawn: TiltPawn = pawns[p]
		if pawn.state != TiltPawn.PState.STANDING:
			continue
		for i in range(loose_coins.size() - 1, -1, -1):
			var c: Dictionary = loose_coins[i]
			if (c.l as Vector2).distance_to(pawn.lpos) < 0.8:
				(c.node as Node3D).queue_free()
				loose_coins.remove_at(i)
				pawn.add_coin()
				points[p] = int(points[p]) + 1
				coins_banked[p] = int(coins_banked[p]) + 1
				max_carried[p] = maxi(int(max_carried[p]), pawn.coins)
				Sfx.play("bumper", -8.0)
				_log("coin p%d carried=%d" % [p, pawn.coins])
				_rebuild_scoreboard()

func _tick_guano(delta: float) -> void:
	var inv := platter.disc.global_transform.affine_inverse()
	for i in range(guanos.size() - 1, -1, -1):
		var g: Dictionary = guanos[i]
		var node: Node3D = g.node
		var vel: Vector3 = g.vel
		vel.y -= GUANO_GRAV * delta
		g.vel = vel
		node.global_position += vel * delta
		var lp: Vector3 = inv * node.global_position
		var flat := Vector2(lp.x, lp.z)
		if lp.y <= TiltPlatter.PAWN_Y + 0.05 and flat.length() <= TiltPlatter.RADIUS:
			_make_splat(flat, int(g.owner))
			node.queue_free()
			guanos.remove_at(i)
		elif node.global_position.y < OCEAN_Y + 0.3:
			_splash_fx(node.global_position, 0.4)
			node.queue_free()
			guanos.remove_at(i)

func _tick_splats() -> void:
	for i in range(splats.size() - 1, -1, -1):
		var s: Dictionary = splats[i]
		if game_t > float(s.until):
			(s.node as Node3D).queue_free()
			splats.remove_at(i)

func _process(delta: float) -> void:
	if phase == Phase.WAITING:
		return
	# camera: subtle roll WITH the platter (<= 3 deg) + shake
	var roll := clampf(platter.tilt.x * 0.14, -deg_to_rad(3.0), deg_to_rad(3.0))
	cam.global_transform = _cam_base
	cam.rotate_object_local(Vector3(0, 0, 1), roll)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.1)
		cam.position += Vector3(
			fx_rng.randf_range(-1, 1), fx_rng.randf_range(-1, 1),
			fx_rng.randf_range(-1, 1)) * _shake * 0.35
	# coin twirl + splat fade
	for c in loose_coins:
		(c.node as Node3D).rotation.y += 2.5 * delta
	for s in splats:
		var left := float(s.until) - game_t
		if left < 1.0:
			(s.mat as StandardMaterial3D).albedo_color.a = maxf(0.0, left) * 0.8
	# HUD timer (overtime counts down its own 20s window, always hot)
	if phase == Phase.PLAY or phase == Phase.INTRO:
		var deadline := round_time + (OVERTIME_TIME if overtime else 0.0)
		var remain := int(ceil(maxf(0.0, deadline - round_t)))
		timer_label.text = ("OT %d" % remain) if overtime else str(remain)
		var hot := sudden_death or remain <= 10
		timer_label.add_theme_color_override("font_color",
			Color(1, 0.3, 0.2) if hot else Color(1, 0.92, 0.6))
		# FINAL STRETCH ticks + timer pulse over the last 10s (host AND mirror:
		# both run this HUD block off the same authoritative round clock)
		if _stretch != null and phase == Phase.PLAY:
			_stretch.tick(deadline - round_t)
	else:
		timer_label.text = ""

# -- input / bots -------------------------------------------------------------

func _input_for(p: int, delta: float) -> Dictionary:
	if _test_mode != "":
		return {"move": Vector2.ZERO, "a": false, "b": false}
	if bot_enabled[p]:
		return bots.decide(p, self, delta)
	return {
		"move": PlayerInput.get_move(p),
		"a": PlayerInput.just_pressed(p, "a"),
		"b": PlayerInput.just_pressed(p, "b"),
	}

# -- mechanics ----------------------------------------------------------------

func _mass_points() -> Array:
	var pts: Array = []
	for pawn in pawns:
		var tp: TiltPawn = pawn
		if tp.state == TiltPawn.PState.STANDING:
			pts.append({"pos": tp.lpos, "m": tp.mass()})
	for c in loose_coins:
		pts.append({"pos": c.l, "m": COIN_LOOSE_MASS})
	return pts

## A pressed: start the windup (the readable tell). The hit lands
## SHOVE_WINDUP (0.12s) later in _resolve_shove.
func _try_shove(p: int) -> void:
	var pawn: TiltPawn = pawns[p]
	if not pawn.try_shove(game_t):
		return
	_shove_n[p] = int(_shove_n[p]) + 1   # wire counter; the mirror plays the tell
	Sfx.play("card", -10.0)  # quiet tell
	_log("shove_windup p%d" % p)

## Windup completed. If a victim in our cone ALSO has a live shove (pressed
## within CLASH_WINDOW) and we are inside THEIR cone -> the shoves CLASH:
## soft mutual push-apart, no royalty, sparks + CLASH! floaty. Otherwise the
## normal cone knockback.
func _resolve_shove(p: int) -> void:
	var pawn: TiltPawn = pawns[p]
	Sfx.play("putt", -6.0)
	# aim tracking: the windup telegraphs WHEN, it shouldn't make you whiff.
	# At release, swing facing up to 25 deg toward the nearest opponent who
	# is in range and near the cone edge (fighting-game startup tracking).
	var track := -1
	var track_d := 999.0
	for q in roster.size():
		if q == p:
			continue
		var other: TiltPawn = pawns[q]
		if other.state != TiltPawn.PState.STANDING:
			continue
		var to_other := other.lpos - pawn.lpos
		if to_other.length() < SHOVE_RANGE and to_other.length() < track_d \
				and absf(rad_to_deg(pawn.facing.angle_to(to_other))) < SHOVE_HALF_ANGLE + 25.0:
			track_d = to_other.length()
			track = q
	if track >= 0:
		var want := ((pawns[track] as TiltPawn).lpos - pawn.lpos).normalized()
		var off := pawn.facing.angle_to(want)
		pawn.facing = pawn.facing.rotated(clampf(off, -deg_to_rad(25.0), deg_to_rad(25.0)))
	_shove_fx(pawn)
	# clash check first: nearest mutual shover wins the drama
	var clash_q := -1
	var clash_d := 999.0
	for q in roster.size():
		if q == p:
			continue
		var other: TiltPawn = pawns[q]
		if other.state != TiltPawn.PState.STANDING or other.braced:
			continue
		if game_t - other.shove_press_t > CLASH_WINDOW:
			continue
		var to_other := other.lpos - pawn.lpos
		var d := to_other.length()
		if d < SHOVE_RANGE \
				and absf(rad_to_deg(pawn.facing.angle_to(to_other))) < SHOVE_HALF_ANGLE \
				and absf(rad_to_deg(other.facing.angle_to(-to_other))) < SHOVE_HALF_ANGLE \
				and d < clash_d:
			clash_d = d
			clash_q = q
	if clash_q >= 0:
		_do_clash(p, clash_q)
		return
	pawn.release_lunge()
	var hit := false
	for q in roster.size():
		if q == p:
			continue
		var other: TiltPawn = pawns[q]
		if other.state != TiltPawn.PState.STANDING:
			continue
		var to_other := other.lpos - pawn.lpos
		if to_other.length() < SHOVE_RANGE \
				and absf(rad_to_deg(pawn.facing.angle_to(to_other))) < SHOVE_HALF_ANGLE:
			other.apply_knock(pawn.facing, SHOVE_POWER, p, game_t)
			_knock_n[q] = int(_knock_n[q]) + 1
			hit = true
			_log("shove p%d -> p%d r=%.1f out=%.2f" % [p, q, other.lpos.length(),
				pawn.facing.dot(other.lpos.normalized()) if other.lpos.length() > 0.1 else 0.0])
	if hit:
		Sfx.play("splat", -3.0)
		_shake = maxf(_shake, 0.12)

func _do_clash(p: int, q: int) -> void:
	var pa: TiltPawn = pawns[p]
	var pb: TiltPawn = pawns[q]
	var axis := (pb.lpos - pa.lpos)
	axis = axis.normalized() if axis.length() > 0.001 else Vector2(1, 0)
	pa.apply_clash(-axis, SHOVE_POWER * CLASH_KB)
	pb.apply_clash(axis, SHOVE_POWER * CLASH_KB)
	var mid := (pa.lpos + pb.lpos) * 0.5
	var world: Vector3 = platter.disc.global_transform \
			* Vector3(mid.x, TiltPlatter.PAWN_Y + 1.0, mid.y)
	_clash_n += 1
	_clash_pos = world
	_clash_fx(world)
	_floaty(world + Vector3(0, 1.1, 0), "CLASH!", Color(1.0, 0.9, 0.25))
	Sfx.play("bumper", -2.0)
	_shake = maxf(_shake, 0.16)
	_log("clash p%d<->p%d kb=%.1f r=[%.1f,%.1f]" % [
		p, q, CLASH_KB, pa.lpos.length(), pb.lpos.length()])

## Which gull owns the splat underfoot (-1 = dry footing). The owner feeds the
## GULL ASSIST credit chain: slip -> fall within GULL_KO_WINDOW = a gull KO.
func _slip_owner(lp: Vector2) -> int:
	for s in splats:
		if (s.l as Vector2).distance_to(lp) < SLIP_RADIUS:
			return int(s.owner)
	return -1

func _separate_pawns() -> void:
	for a in roster.size():
		var pa: TiltPawn = pawns[a]
		if pa.state != TiltPawn.PState.STANDING:
			continue
		for b in range(a + 1, roster.size()):
			var pb: TiltPawn = pawns[b]
			if pb.state != TiltPawn.PState.STANDING:
				continue
			var d := pb.lpos - pa.lpos
			var dist := d.length()
			if dist < 0.9 and dist > 0.001:
				var push := d.normalized() * (0.9 - dist) * 0.5
				pa.lpos -= push
				pb.lpos += push

func _on_edge_fall(p: int) -> void:
	var pawn: TiltPawn = pawns[p]
	pawn.begin_fall()
	elim_order.append(p)
	var pl: Dictionary = roster[p]
	_currency.append({"type": "grudge", "player": p, "amount": 1, "reason": "fell off the platter"})
	var shover := -1
	if pawn.last_shover >= 0 and pawn.last_shover != p \
			and game_t - pawn.last_shove_t <= ROYALTY_WINDOW:
		shover = pawn.last_shover
	# GULL ASSIST (v1.2): a fall within GULL_KO_WINDOW of a guano slip is the
	# seagull's KO. The most recent shover (inside the wider assist window)
	# collects the royalty — the shove softened them up, the bomb finished it.
	var gull_ko: bool = _slip_t.has(p) and game_t - float(_slip_t[p]) <= GULL_KO_WINDOW
	var assist := -1
	if gull_ko and pawn.last_shover >= 0 and pawn.last_shover != p \
			and game_t - pawn.last_shove_t <= GULL_ASSIST_WINDOW:
		assist = pawn.last_shover
	# Optional contract reporting: one kill_event per overboard fall. killer is
	# the crediting shover (gull_assist on a gull KO, ring_out otherwise) or -1
	# for a solo fall. Pure bookkeeping — the sim is untouched by this line.
	if assist >= 0:
		_kill_events.append({"killer": assist, "victim": p, "cause": "gull_assist"})
	else:
		_kill_events.append({"killer": shover, "victim": p, "cause": "ring_out"})
	Sfx.play("death")
	_shake = maxf(_shake, 0.3)
	# THE DECIDING MOMENT (doc 09 §Q2): the fall that ENDS the round gets the
	# deep freeze + fov punch; every other fall gets the demoted 0.5x/0.2s
	# beat (doc 08's anti-goal — deep slow-mo is reserved, not routine).
	var deciding := _standing_count() <= 1 and roster.size() >= 2 and _test_mode == ""
	if deciding and not _reduced_motion():
		_slow_mo(0.25, 0.8)
		FinalStretch.fov_punch(cam, 50.0, 6.0, 0.8)
	else:
		_slow_mo()
	if assist >= 0:
		shove_falls[assist] = int(shove_falls[assist]) + 1
		var an: Dictionary = roster[assist]
		var gn: Dictionary = roster[int(_slip_gull.get(p, assist))]
		_currency.append({"type": "royalty", "player": assist, "amount": 1,
			"reason": "softened %s for %s's gull" % [pl.name, gn.name]})
		_flash_banner("AIR RAID!  %s'S GULL SINKS %s — %s COLLECTS" % [gn.name, pl.name, an.name],
			an.color, 2.0)
	elif shover >= 0:
		shove_falls[shover] = int(shove_falls[shover]) + 1
		var sn: Dictionary = roster[shover]
		_currency.append({"type": "royalty", "player": shover, "amount": 1,
			"reason": "shoved %s overboard" % pl.name})
		_flash_banner("%s SHOVED %s OVERBOARD!" % [sn.name, pl.name], sn.color, 1.8)
	else:
		_flash_banner("%s OVERBOARD!" % pl.name, pl.color, 1.6)
	_log("fall p%d shover=%d gull_ko=%s assist=%d tilt=%.1f" % [
		p, shover, str(gull_ko), assist, platter.tilt_deg()])
	_rebuild_scoreboard()
	if _standing_count() <= 1 and _test_mode == "":
		_end_round("last_stand")

func _on_water_death(p: int) -> void:
	var pawn: TiltPawn = pawns[p]
	_splash_fx(pawn.global_position, 1.0)
	Sfx.play("splat", -2.0)
	pawn.vanish()
	if phase == Phase.PLAY or phase == Phase.ROUND_END:
		if _test_mode == "" and phase == Phase.PLAY:
			_spawn_gull(p, pawn.global_position)
	_log("splash p%d" % p)

func _spawn_gull(p: int, at: Vector3) -> void:
	var gull := TiltSeagull.new()
	gull.name = "Gull%d" % p
	add_child(gull)
	gull.setup(p, (roster[p] as Dictionary).color)
	gull.position = Vector3(at.x, 1.0, at.z)
	gulls[p] = gull
	_rebuild_scoreboard()
	_refresh_hint()

const TILT_HINT_BASE := "MOVE  -  A = SHOVE (ANSWER A SHOVE TO CLASH!)  -  B = BRACE   |   FALL AND YOU RETURN AS A SEAGULL (A = BOMB)"

## The hint bar's seagull legend: shown whenever a HUMAN is a seagull so the dead
## get their controls (fly + bomb). Bots never trigger it. Owns hint visibility
## once the round-1 intro window closes.
func _refresh_hint() -> void:
	if hint_label == null:
		return
	var human_gull := -1
	var n := 0
	for p in roster.size():
		# mirror: only MY seat's controls belong on MY hint bar (other seats'
		# humans live on other machines; host-side bots aren't humans at all)
		var eligible: bool = (p == NetSession.my_seat()) if _mirror \
				else (p < bot_enabled.size() and not bot_enabled[p])
		if eligible and gulls.has(p):
			n += 1
			if human_gull < 0:
				human_gull = p
	if n > 0:
		hint_label.text = _gull_hint_line(human_gull) if n == 1 else "SPLASH! YOU'RE A SEAGULL — MOVE to fly · A = drop a BOMB"
		hint_label.visible = true
	else:
		hint_label.visible = false

func _gull_hint_line(p: int) -> String:
	var nm: String = (roster[p] as Dictionary).name
	var mv: String = PlayerInput.describe_binding(p, "move")
	var bomb: String = PlayerInput.describe_binding(p, "a")
	return "%s IS A SEAGULL — %s fly · %s = drop a BOMB" % [nm, mv, bomb]

## ---- live-binding hint bar (real keys, not "A"/"B"; see docs/verify/realkeys-VERIFY.md) ----

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). The
## main bar personalizes only these; an all-bot demo gets an empty list and keeps
## the generic TILT_HINT_BASE text.
func _human_seats() -> Array:
	var out := []
	for i in roster.size():
		# mirror: only MY seat is a human on THIS machine (the client estate
		# maps local devices to every seat, but those hands live elsewhere)
		if _mirror and i != NetSession.my_seat():
			continue
		if i < bot_enabled.size() and not bot_enabled[i] and PlayerInput.device_of(i) != -99:
			out.append(i)
	return out

## One button's live legend: "KEY = LABEL" when every human seat shares the key
## (all pads -> "(A) = SHOVE"), else the per-seat "LABEL: KEY/NAME · KEY/NAME"
## form (mixed keyboard + pad). Bindings are fixed per match, so this is built
## once when the round starts - no live polling.
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

## The main living bar with real keys, or TILT_HINT_BASE for an all-bot demo.
func _controls_bar() -> String:
	if _human_seats().is_empty():
		return TILT_HINT_BASE
	return "MOVE   ·   %s   ·   %s   |   FALL AND YOU RETURN AS A SEAGULL" % [
		_btn_hint("a", "SHOVE"), _btn_hint("b", "BRACE")]

func _spawn_guano(from: Vector3, owner_p: int) -> void:
	guanos.append({"node": _guano_visual(from), "vel": Vector3(0, -1.0, 0), "owner": owner_p})
	_guano_n[owner_p] = int(_guano_n.get(owner_p, 0)) + 1
	Sfx.play("card", -4.0)
	_log("guano p%d" % owner_p)

## Guano VISUAL only — shared by the host spawn and the mirror's bomb-counter
## deltas (the mirror integrates its copy cosmetically; splats ride the wire).
func _guano_visual(from: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.13
	m.height = 0.26
	node.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.98, 0.92)
	node.material_override = mat
	add_child(node)
	node.global_position = from + Vector3(0, -0.25, 0)
	return node

## Splat VISUAL only (node + list entry + sfx) — shared verbatim by the host
## sim (_make_splat) and the mirror (splat-list deltas). Render, no sim.
func _splat_visual(l: Vector2, owner_p: int, until_t: float) -> void:
	var node := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = SLIP_RADIUS
	m.bottom_radius = SLIP_RADIUS
	m.height = 0.015
	node.mesh = m
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.97, 0.97, 0.9, 0.8)
	node.material_override = mat
	platter.disc.add_child(node)
	node.position = Vector3(l.x, TiltPlatter.TOP_Y + 0.085, l.y)
	splats.append({"node": node, "mat": mat, "l": l, "until": until_t, "owner": owner_p})
	Sfx.play("splat", -6.0)

func _make_splat(l: Vector2, owner_p: int) -> void:
	_splat_visual(l, owner_p, game_t + SLIP_TIME)
	# direct hit: staggers anyone underneath (and counts as a fresh slip for the
	# gull-KO window — the bomb IS the slip)
	for q in roster.size():
		var pawn: TiltPawn = pawns[q]
		if pawn.state == TiltPawn.PState.STANDING and pawn.lpos.distance_to(l) < 1.0:
			pawn.slide += platter.downhill() * 2.2 + (pawn.lpos - l).normalized() * 1.2
			gull_hits[owner_p] = int(gull_hits[owner_p]) + 1
			_slip_gull[q] = owner_p
			_slip_t[q] = game_t
			_log("guano_hit p%d by gull p%d" % [q, owner_p])

func _spawn_coin() -> void:
	var r := clampf(absf(rng.randfn(0.0, 2.2)), 0.0, 5.7)
	var ang := rng.randf_range(0.0, TAU)
	_coin_visual(Vector2(cos(ang), sin(ang)) * r)

## Coin VISUAL only — shared by the host spawn (seeded position) and the
## mirror (coin-list reconcile).
func _coin_visual(l: Vector2) -> void:
	var node := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.34
	m.bottom_radius = 0.34
	m.height = 0.12
	node.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.15)
	mat.metallic = 0.8
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.7, 0.05)
	mat.emission_energy_multiplier = 0.9
	node.material_override = mat
	node.rotation.x = 0.25  # cocked so the face catches the eye while it spins
	platter.disc.add_child(node)
	node.position = Vector3(l.x, TiltPlatter.TOP_Y + 0.45, l.y)
	loose_coins.append({"node": node, "l": l})

func _standing_count() -> int:
	var n := 0
	for pawn in pawns:
		if (pawn as TiltPawn).state == TiltPawn.PState.STANDING:
			n += 1
	return n

func _start_sudden_death() -> void:
	sudden_death = true
	platter.set_sudden_death(true)
	if _stretch != null:
		_stretch.escalate()   # FINAL STRETCH: game_light -> game_tense + nudge
	_flash_banner("SUDDEN DEATH\nTHE PIN RISES", Color(1, 0.3, 0.2), 2.2)
	Sfx.play("grudge")
	_shake = maxf(_shake, 0.2)
	_log("sudden_death")

## OVERTIME (v1.2): >1 survivor at the horn. The estate splits nothing — 20
## more seconds on a sudden-death platter tilting 1.5x harder. Only if the sea
## still refuses a verdict at +20s does the old split fire (the exception now).
func _start_overtime() -> void:
	overtime = true
	if not sudden_death:
		_start_sudden_death()
	platter.set_overtime(true)
	_flash_banner("THE ESTATE SPLITS NOTHING\nOVERTIME", Color(1, 0.3, 0.2), 2.6)
	Sfx.play("grudge")
	Sfx.play("round_over", -6.0)
	_shake = maxf(_shake, 0.25)
	_log("overtime start standing=%d gain=%.2fx window=%.0fs" % [
		_standing_count(), platter.gain_scale * platter.overtime_scale, OVERTIME_TIME])

# -- round / match flow -------------------------------------------------------

func _start_round() -> void:
	phase = Phase.INTRO
	phase_t = 0.0
	round_t = 0.0
	_last_status = 0.0
	sudden_death = false
	overtime = false
	coin_timer = COIN_INTERVAL
	elim_order.clear()
	_slip_gull.clear()
	_slip_t.clear()
	platter.reset()
	for arr in [loose_coins, splats, guanos]:
		for e in arr:
			(e.node as Node3D).queue_free()
		arr.clear()
	for p in gulls:
		(gulls[p] as TiltSeagull).queue_free()
	gulls.clear()
	for i in roster.size():
		var pawn: TiltPawn = pawns[i]
		pawn.reset_for_round(_spawn_pos(i))
	round_label.text = "ROUND %d / %d" % [round_num, rounds_total]
	if _stretch != null:
		_stretch.round_reset()   # light bed back on; tick ladder re-arms
	_flash_banner("ROUND %d" % round_num, Color(1, 0.85, 0.2), 1.2)
	if round_num == 1:
		hint_label.text = _controls_bar()
		hint_label.visible = true
		var tw := create_tween()
		tw.tween_interval(7.0)
		# hand visibility to _refresh_hint: it keeps the bar up iff a human is a gull
		tw.tween_callback(func() -> void: _refresh_hint())
	else:
		# gulls were cleared for the new round -> hide unless a human is a gull
		_refresh_hint()
	_rebuild_scoreboard()
	_log("round_start %d" % round_num)

func _end_round(kind: String) -> void:
	phase = Phase.ROUND_END
	phase_t = 0.0
	var survivors: Array = []
	for i in roster.size():
		if (pawns[i] as TiltPawn).state == TiltPawn.PState.STANDING:
			survivors.append(i)
	if survivors.size() == 1:
		var w: int = survivors[0]
		_win_n += 1
		_last_win = w
		points[w] = int(points[w]) + ROUND_POINTS[0]
		round_wins[w] = int(round_wins[w]) + 1
		var pl: Dictionary = roster[w]
		_flash_banner("%s HOLDS THE PLATTER  +%d" % [pl.name, ROUND_POINTS[0]], pl.color, 2.8)
		(pawns[w] as TiltPawn).cheer()
		_confetti((pawns[w] as TiltPawn).global_position + Vector3(0, 1.6, 0), pl.color)
		var rank := 1
		for i in range(elim_order.size() - 1, -1, -1):
			if rank < ROUND_POINTS.size():
				points[elim_order[i]] = int(points[elim_order[i]]) + ROUND_POINTS[rank]
			rank += 1
	elif survivors.size() > 1:
		var pool := 0
		for k in survivors.size():
			pool += ROUND_POINTS[k] if k < ROUND_POINTS.size() else 0
		var share := maxi(1, int(float(pool) / survivors.size()))
		for w in survivors:
			points[w] = int(points[w]) + share
			(pawns[w] as TiltPawn).cheer()
		var split_msg := "TIME!  %d SURVIVORS SPLIT THE WIN  +%d" % [survivors.size(), share]
		if kind == "overtime_split":
			split_msg = "THE SEA REFUSES A VERDICT\n%d SURVIVORS SPLIT  +%d" % [survivors.size(), share]
		_flash_banner(split_msg, Color(1, 0.85, 0.2), 2.8)
		var rank2 := survivors.size()
		for i in range(elim_order.size() - 1, -1, -1):
			if rank2 < ROUND_POINTS.size():
				points[elim_order[i]] = int(points[elim_order[i]]) + ROUND_POINTS[rank2]
			rank2 += 1
	else:
		_flash_banner("NOBODY SURVIVES", Color(0.85, 0.85, 0.85), 2.6)
	Sfx.play("round_over")
	_rebuild_scoreboard()
	var score_bits: Array = []
	for i in roster.size():
		score_bits.append("%s=%d" % [(roster[i] as Dictionary).name, int(points[i])])
	_log("round_end %d kind=%s scores[%s]" % [round_num, kind, ", ".join(score_bits)])

func _finish_match() -> void:
	phase = Phase.MATCH_END
	phase_t = 0.0
	var order: Array = range(roster.size())
	order.sort_custom(func(a, b):
		if int(points[a]) != int(points[b]):
			return int(points[a]) > int(points[b])
		return a < b)
	var champ: int = order[0]
	var champ_pl: Dictionary = roster[champ]
	_match_winner = champ
	if _stretch != null:
		_stretch.match_ended()
	# The winner banner + match_win sting + 3D cheer/confetti are now the
	# ResultsBoard's winner beat (see the tail of this function). Keep only the
	# online evidence snap here, on the authoritative match-end frame.
	if NetSession.has_guests():
		VerifyCapture.snap("net_matchend")
	_highlights.clear()
	var hv := _dict_max(max_carried)
	if int(max_carried[hv]) >= 3:
		_highlights.append("%s lugged %d coins at once" % [(roster[hv] as Dictionary).name, int(max_carried[hv])])
	var sv := _dict_max(shove_falls)
	if int(shove_falls[sv]) >= 1:
		_highlights.append("%s shoved %d rival%s overboard" % [(roster[sv] as Dictionary).name,
			int(shove_falls[sv]), "" if int(shove_falls[sv]) == 1 else "s"])
	var gv := _dict_max(gull_hits)
	if int(gull_hits[gv]) >= 2:
		_highlights.append("%s's seagull scored %d direct hits" % [(roster[gv] as Dictionary).name, int(gull_hits[gv])])
	if int(round_wins[champ]) == rounds_total and rounds_total > 1:
		_highlights.append("%s never lost the platter" % champ_pl.name)
	var monuments: Array = []
	if int(shove_falls[sv]) >= 4:
		monuments.append({"player": sv, "kind": "tyrant",
			"label": "%s, Tipper of Worlds" % (roster[sv] as Dictionary).name})
	_results = {
		"placements": order,
		"points": points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": _highlights.slice(0, 3),
		"monuments": monuments,
		"kill_events": _kill_events.duplicate(),
	}
	print("KILL_EVENTS n=", _kill_events.size(), " ", _kill_events)
	_log("match_end " + JSON.stringify(_results))
	_present_results_board()

## The staged match-end reveal (doc 14 §3), via the shared ui_kit ResultsBoard:
## the old banner + static hold becomes freeze -> per-player count-up (points,
## with round wins as the per-row callout) -> protected winner hero beat. tilt
## keeps the champion's 3D cheer + confetti and hangs them off the winner beat.
func _present_results_board() -> void:
	banner.visible = false
	if _hud != null:
		_hud.visible = false      # the board IS the standings now — no double board
	var rows: Array = []
	for p in _results.placements:
		var pidx := int(p)
		var rw := int(round_wins.get(pidx, 0))
		var callout := ""
		if rw > 0:
			callout = "%d round win%s" % [rw, "" if rw == 1 else "s"]
		rows.append({
			"player": pidx,
			"score": int(points.get(pidx, 0)),
			"color": (roster[pidx] as Dictionary).color,
			"name": str((roster[pidx] as Dictionary).name),
			"callout": callout,
		})
	var board := ResultsBoard.new()
	add_child(board)
	_results_board = board
	_board_running = true
	board.winner_beat.connect(_on_match_winner)
	board.done.connect(func() -> void:
		if not _reported:
			_reported = true
			report_finished(_results))
	if _vc != null:
		get_tree().create_timer(2.4).timeout.connect(func() -> void: _vc.snap("tilt_results"))
	board.present(rows, {
		"title": "FINAL STANDINGS",
		"subtitle": "BEST OF %d" % rounds_total,
		"score_type": ResultsBoard.ScoreType.POINTS,
		"win_title": "{name} WINS TILT!",
		"accent": Color(1, 0.82, 0.3),
	})

func _on_match_winner(champ: int) -> void:
	var champ_pl: Dictionary = roster[champ]
	var champ_pawn: TiltPawn = pawns[champ]
	if champ_pawn.state == TiltPawn.PState.STANDING:
		champ_pawn.cheer()
		_confetti(champ_pawn.global_position + Vector3(0, 1.6, 0), champ_pl.color)
	else:
		_confetti(Vector3(0, 3, 0), champ_pl.color)
	_shake = maxf(_shake, 0.3)

func _dict_max(d: Dictionary) -> int:
	var best := 0
	for k in d:
		if int(d[k]) > int(d[best]):
			best = int(k)
	return best

func _spawn_angle(i: int) -> float:
	return TAU * float(i) / float(maxi(roster.size(), 1)) + TAU / 8.0

func _spawn_pos(i: int) -> Vector2:
	var a := _spawn_angle(i)
	return Vector2(cos(a), sin(a)) * SPAWN_R

# -- config / args ------------------------------------------------------------

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--tiltbots":
			_bots_all = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--rounds="):
			_cli_rounds = int(arg.trim_prefix("--rounds="))
		elif arg.begins_with("--roundtime="):
			_cli_roundtime = float(arg.trim_prefix("--roundtime="))
		elif arg.begins_with("--tilttest="):
			_test_mode = arg.trim_prefix("--tilttest=")
		elif arg == "--deadhint":
			_dead_hint_demo = true

func _default_config() -> Dictionary:
	PlayerInput.auto_assign(_cli_players)
	if _dead_hint_demo:
		PlayerInput.assign(0, -4)   # seat 0 = KBM human so its seagull hint reads MOUSE/LMB
	var r: Array = []
	for i in _cli_players:
		var seat_bot: bool = PlayerInput.standalone_bot_default(i)
		if _dead_hint_demo:
			seat_bot = (i != 0)   # seat 0 human (forced into a gull), the rest bots
		r.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": CHAR_FALLBACKS[i],
			"device": PlayerInput.device_of(i),
			"bot": seat_bot,
		})
	return {"roster": r, "rounds": 5, "rng_seed": _cli_seed, "practice": false}

# -- self-tests (spec "Risks & tests") -----------------------------------------

func _setup_test() -> void:
	phase = Phase.PLAY
	round_time = 99999.0
	hint_label.visible = false
	banner.visible = false
	for i in roster.size():
		(pawns[i] as TiltPawn).reset_for_round(_spawn_pos(i))
	if _test_mode == "edge":
		(pawns[0] as TiltPawn).reset_for_round(Vector2(6.55, 0.0))
		platter.debug_force_tilt(Vector2(1, 0), 20.0)
		_log("tilttest edge: pawn0 at r=6.55, forced 20deg toward +X")
	elif _test_mode == "gull":
		(pawns[0] as TiltPawn).reset_for_round(Vector2(5.9, 0.0))
		platter.debug_force_tilt(Vector2(1, 0), 20.0)
		_log("tilttest gull: pawn0 at r=5.9, forced 20deg; shove+splat inject at t=0.5")
	else:
		_log("tilttest idle: 4 pawns symmetric, impulse at t=5s")

func _tick_test(delta: float) -> void:
	_test_t += delta
	if _test_mode == "idle":
		if not _test_injected and _test_t >= 5.0:
			_test_injected = true
			platter.tilt_vel += Vector2(0.35, 0.22)
			print("TILTTEST idle: impulse injected at t=%.1f" % _test_t)
		if _test_t >= _test_next_sample:
			_test_next_sample += 1.0
			var deg := platter.tilt_deg()
			var grace := _test_t > 4.9 and _test_t < 9.0
			print("TILTTEST idle t=%2.0f tilt=%.3f deg%s" % [_test_t, deg, "  (grace)" if grace else ""])
			if not grace and deg > 3.0:
				_test_fail = true
		if _test_t >= 30.0:
			print("TILTTEST idle RESULT: %s" % ("FAIL" if _test_fail else "PASS"))
			get_tree().quit(1 if _test_fail else 0)
	elif _test_mode == "edge":
		var pawn: TiltPawn = pawns[0]
		if _test_t >= _test_next_sample:
			_test_next_sample += 0.5
			print("TILTTEST edge t=%.1f r=%.2f slide=%.2f tilt=%.1f" % [
				_test_t, pawn.lpos.length(), pawn.slide.length(), platter.tilt_deg()])
		if pawn.state != TiltPawn.PState.STANDING:
			print("TILTTEST edge RESULT: PASS (slid off at t=%.2f)" % _test_t)
			get_tree().quit(0)
		elif _test_t > 8.0:
			print("TILTTEST edge RESULT: FAIL (still aboard after 8s)")
			get_tree().quit(1)
	elif _test_mode == "gull":
		# v1.2 GULL ASSIST chain, deterministically: p1's shove connects (the
		# real apply_knock path), p2's gull splats the same spot, the knockback
		# carries p0 over the rim inside both windows -> the fall must credit
		# cause "gull_assist", killer=1, +1 royalty to p1.
		var pawn: TiltPawn = pawns[0]
		if not _test_injected and _test_t >= 0.5:
			_test_injected = true
			pawn.apply_knock(Vector2(1, 0), SHOVE_POWER, 1, game_t)
			_make_splat(pawn.lpos, 2)
			print("TILTTEST gull: shove(p1) + splat(gull p2) injected at t=%.2f r=%.2f" % [
				_test_t, pawn.lpos.length()])
		if pawn.state != TiltPawn.PState.STANDING and not _kill_events.is_empty():
			var ev: Dictionary = _kill_events[-1]
			var royal := false
			for c in _currency:
				if str(c.type) == "royalty" and int(c.player) == 1:
					royal = true
			var ok: bool = str(ev.cause) == "gull_assist" and int(ev.killer) == 1 \
					and int(ev.victim) == 0 and royal
			print("TILTTEST gull RESULT: %s (cause=%s killer=%d victim=%d royalty_p1=%s t=%.2f)" % [
				"PASS" if ok else "FAIL", str(ev.cause), int(ev.killer), int(ev.victim), str(royal), _test_t])
			get_tree().quit(0 if ok else 1)
		elif _test_t > 8.0:
			print("TILTTEST gull RESULT: FAIL (no fall after 8s)")
			get_tree().quit(1)

# -- world & juice -------------------------------------------------------------

func _build_world() -> void:
	# sky + ambient — warm golden-hour diorama (greed/mower family): warm sun
	# with shadows, warm peach sky + soft ambient, filmic, gentle glow so the
	# platter's bright target rings and gold coins bloom. The ocean stays the
	# sea it always was, just warmed by the low sun.
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.30, 0.38)
	sky_mat.sky_horizon_color = Color(0.98, 0.74, 0.48)
	sky_mat.ground_bottom_color = Color(0.15, 0.17, 0.18)
	sky_mat.ground_horizon_color = Color(0.66, 0.48, 0.34)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# sun (casts the platter's tilt shadow on the ocean) — warm, low, golden
	sun.rotation_degrees = Vector3(-40, 40, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.84, 0.60)
	# a soft cool bounce from the sea keeps warm shadows from going flat
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, -132, 0)
	fill.light_energy = 0.26
	fill.light_color = Color(0.64, 0.72, 0.80)
	add_child(fill)
	# ocean — deepened a touch so it reads as evening sea under the warm sun
	var ocean := MeshInstance3D.new()
	var om := CylinderMesh.new()
	om.top_radius = 70.0
	om.bottom_radius = 70.0
	om.height = 0.3
	ocean.mesh = om
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.11, 0.24, 0.25)   # warm evening sea-green
	omat.roughness = 0.07                          # mirror-calm: catches the golden sky
	omat.metallic = 0.35
	ocean.material_override = omat
	ocean.position.y = OCEAN_Y - 0.15
	add_child(ocean)
	# the platter itself
	platter = TiltPlatter.new()
	platter.name = "Platter"
	add_child(platter)
	# camera: fixed 3/4, whole platter in frame
	cam.position = Vector3(0, 15.5, 14.5)
	cam.look_at(Vector3(0, 0.4, 0))
	cam.fov = 50.0
	_cam_base = cam.global_transform

## Deciding-moment standard (doc 09 §Q2): ordinary falls demoted to 0.5x/0.2s
## (was a flat 0.35x/0.32s on EVERY fall); the round-ending fall promotes to
## 0.25x/0.8s via the explicit args. Restore timer is real-time, as before.
func _slow_mo(scale := 0.5, dur := 0.2) -> void:
	if _slowmo:
		return
	_slowmo = true
	Engine.time_scale = scale
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo = false

func _reduced_motion() -> bool:
	return not bool(PartySetup.pref("screen_shake", true))

func _shove_fx(pawn: TiltPawn) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	var fwd := platter.disc.global_transform.basis * Vector3(pawn.facing.x, 0, pawn.facing.y)
	p.global_position = pawn.global_position + Vector3(0, 0.9, 0) + fwd * 0.5
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.direction = fwd
	p.spread = 20.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.9)
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

## Spark burst at a clash midpoint: hot yellow-white omnidirectional flecks.
func _clash_fx(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.amount = 32
	p.lifetime = 0.42
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -6.0, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.07, 0.07)
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.06)
	mat.emission_energy_multiplier = 1.6
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	# expanding white shock ring: the unmistakable "shoves cancelled" read
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.34
	rm.outer_radius = 0.46
	ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(1, 1, 1, 0.95)
	rmat.emission_enabled = true
	rmat.emission = Color(1, 0.95, 0.7)
	rmat.emission_energy_multiplier = 2.0
	ring.material_override = rmat
	add_child(ring)
	ring.global_transform = Transform3D(platter.disc.global_transform.basis, pos)
	ring.scale = Vector3(0.5, 0.4, 0.5)
	var rtw := create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector3(3.2, 0.25, 3.2), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(rmat, "albedo_color:a", 0.0, 0.3)
	rtw.chain().tween_callback(ring.queue_free)

## World-space floating text (Label3D billboard) that rises and fades.
func _floaty(pos: Vector3, text: String, color: Color) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font = BANNER_FONT
	lb.font_size = 150
	lb.pixel_size = 0.004
	lb.modulate = color
	lb.outline_size = 26
	lb.outline_modulate = Color(0.2, 0.08, 0.0)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	add_child(lb)
	lb.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "position:y", lb.position.y + 1.1, 0.95) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.45).set_delay(0.5)
	tw.chain().tween_callback(lb.queue_free)

func _splash_fx(pos: Vector3, scale_f: float) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = Vector3(pos.x, OCEAN_Y + 0.2, pos.z)
	p.one_shot = true
	p.amount = 24
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 3.0 * scale_f
	p.initial_velocity_max = 6.5 * scale_f
	p.gravity = Vector3(0, -9.8, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.08 * scale_f
	mesh.height = 0.16 * scale_f
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.9, 0.95)
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)

func _confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 16
		p.lifetime = 1.1
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
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

func _flash_banner(text: String, color: Color, duration: float) -> void:
	_banner_col = color.to_html(false)
	banner.text = text
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

## Live standings now ride the ui_kit HudStrip (doc 14 item 9): points as the
## chip score, carried coins / GULL as the status tag, dead seats dimmed, and a
## leader marker + pulse on lead changes.
func _rebuild_scoreboard() -> void:
	if _hud == null:
		return
	var leader := -1
	var best := -2147483648
	for i in roster.size():
		var pawn: TiltPawn = pawns[i]
		var standing: bool = pawn.state == TiltPawn.PState.STANDING
		var status := ""
		if standing:
			if pawn.coins > 0:
				status = "x%d" % pawn.coins
		else:
			status = "GULL"
		_hud.set_score(i, int(points.get(i, 0)), status, not standing)
		if int(points.get(i, 0)) > best:
			best = int(points.get(i, 0))
			leader = i
	if leader >= 0:
		_hud.set_lead(leader)

func _log(msg: String) -> void:
	var f := -1
	if _vc != null:
		f = int(_vc.frame)
	print("TILT_EVT t=%.2f frame=%d | %s" % [game_t, f, msg])

# ================================================================ ONLINE (phase 2)
# House pattern from minigames/seance/seance.gd (docs/design/10 §4.3): the
# _mirror guard in _physics_process, the begin() mirror branch, and
# _net_state()/_net_apply() with juice-from-deltas. TILT-specific content:
# the platter tilt vector (the ONE transform that moves everything, chased at
# 60 fps), pawn poses/anim flags, gull + bomb + splat + coin mirrors, and the
# v1.2 overtime/gull-assist banners riding the ban fact. No hidden info —
# everything on this wire is on every couch player's screen already.

## HOST, pumped by the estate at 20 Hz (unreliable_ordered ch 4, latest wins).
func _net_state() -> Dictionary:
	var pw: Array = []
	for i in roster.size():
		var p: TiltPawn = pawns[i]
		var flags := 0
		if (p.move_vel + p.slide).length() > 0.8:
			flags |= 1                     # moving (Running_A vs Idle)
		if p.braced:
			flags |= 2
		if p.cheering:
			flags |= 4
		if p.state == TiltPawn.PState.STANDING:
			pw.append([0, snappedf(p.lpos.x, 0.01), snappedf(p.lpos.y, 0.01), 0.0,
				snappedf(atan2(p.facing.x, p.facing.y), 0.01), p.coins, flags,
				int(_shove_n[i]), int(_knock_n[i])])
		else:
			var gp := p.global_position
			pw.append([int(p.state), snappedf(gp.x, 0.01), snappedf(gp.z, 0.01),
				snappedf(gp.y, 0.01), 0.0, p.coins, flags,
				int(_shove_n[i]), int(_knock_n[i])])
	var gl := {}
	for p in gulls:
		var g: TiltSeagull = gulls[p]
		gl[int(p)] = [snappedf(g.position.x, 0.01), snappedf(g.position.z, 0.01),
			int(_guano_n.get(p, 0))]
	var cn: Array = []
	for c in loose_coins:
		cn.append([snappedf((c.l as Vector2).x, 0.01), snappedf((c.l as Vector2).y, 0.01)])
	var sp: Array = []
	for s in splats:
		sp.append([snappedf((s.l as Vector2).x, 0.01), snappedf((s.l as Vector2).y, 0.01),
			int(s.owner), snappedf(maxf(float(s.until) - game_t, 0.0), 0.1)])
	var pts: Array = []
	for i in roster.size():
		pts.append(int(points[i]))
	return {
		"ph": phase, "rn": round_num, "rts": rounds_total,
		"gt": snappedf(game_t, 0.01), "rt": snappedf(round_t, 0.01),
		"rtl": round_time, "sd": sudden_death, "ot": overtime,
		"tilt": [snappedf(platter.tilt.x, 0.0001), snappedf(platter.tilt.y, 0.0001)],
		"pw": pw, "gl": gl, "cn": cn, "sp": sp,
		"cl": _clash_n,
		"clp": [snappedf(_clash_pos.x, 0.01), snappedf(_clash_pos.y, 0.01), snappedf(_clash_pos.z, 0.01)],
		"pts": pts,
		"ban": [banner.text, _banner_col, banner.visible],
		"rw": _win_n, "rww": _last_win, "mw": _match_winner,
	}

## CLIENT. Latest-state-wins; every sfx/anim/confetti below fires from a DELTA
## against the previous snapshot (counters, not events — a dropped packet loses
## nothing but intermediate frames). Continuous motion only sets targets; the
## 60 fps chase lives in _mirror_tick.
func _net_apply(state: Dictionary) -> void:
	if not _mirror:
		return
	var prev := _mir
	_mir = state
	var first := prev.is_empty()
	# --- clocks + round facts: feed the UNTOUCHED couch _process (timer text,
	# splat fade, coin twirl, camera roll) exactly what it reads on the host
	rounds_total = int(state.get("rts", rounds_total))
	round_time = float(state.get("rtl", round_time))
	var ph := int(state.get("ph", Phase.WAITING))
	var prev_ph: int = int(prev.get("ph", -1))
	var rn := int(state.get("rn", round_num))
	# a fresh ROUND resets the board; the rn bump INTO match end does not (the
	# host bumps round_num past rounds_total right before _finish_match, and
	# the final tableau — gulls, splats, survivors — must stay on stage)
	if first or (rn != round_num and ph != Phase.MATCH_END):
		_mirror_round_reset(rn, first)
	round_num = rn
	game_t = float(state.get("gt", game_t))
	round_t = float(state.get("rt", round_t))
	phase = ph
	# --- sudden death / overtime platter dressing (banners ride the ban fact)
	var sd: bool = bool(state.get("sd", false))
	if sd and not sudden_death:
		platter.set_sudden_death(true)
		Sfx.play("grudge")
		_shake = maxf(_shake, 0.2)
		if _stretch != null:
			_stretch.escalate()   # FINAL STRETCH fires client-side off the sd fact
	sudden_death = sd
	var ot: bool = bool(state.get("ot", false))
	if ot and not overtime:
		platter.set_overtime(true)
		Sfx.play("round_over", -6.0)
		_shake = maxf(_shake, 0.25)
	overtime = ot
	# --- the one transform that moves everything
	var tl: Array = state.get("tilt", [])
	if tl.size() >= 2:
		_mir_tilt = Vector2(float(tl[0]), float(tl[1]))
	if first:
		platter.mirror_set_tilt(_mir_tilt, 0.0)   # appear, don't swoop
	_apply_mir_banner(state.get("ban", []), prev.get("ban", []))
	# --- pawns: poses are targets; counters/flags are juice
	var board_dirty := first
	var pw: Array = state.get("pw", [])
	var ppw: Array = prev.get("pw", [])
	_mir_pawn = pw
	for i in mini(pw.size(), pawns.size()):
		var d: Array = pw[i]
		var pd: Array = ppw[i] if i < ppw.size() else []
		var pawn: TiltPawn = pawns[i]
		var st := int(d[0])
		# state edges compare against the PAWN's actual state (not the previous
		# snapshot) so the mirror self-heals if a reset and a snapshot ever race
		var pst: int = int(pawn.state)
		var flags := int(d[6])
		var pflags: int = int(pd[6]) if pd.size() > 6 else 0
		if int(d[7]) > (int(pd[7]) if pd.size() > 7 else 0):
			pawn.mirror_windup()
			Sfx.play("card", -10.0)   # the quiet tell
		if int(d[8]) > (int(pd[8]) if pd.size() > 8 else 0):
			pawn.mirror_knock()
			Sfx.play("splat", -3.0)
			_shake = maxf(_shake, 0.12)
		if (flags & 2) != 0 and (pflags & 2) == 0:
			Sfx.play("confirm", -4.0)  # brace planted
		if (flags & 4) != 0 and (pflags & 4) == 0:
			pawn.cheer()
		var coins_now := int(d[5])
		var pcoins: int = int(pd[5]) if pd.size() > 5 else 0
		if coins_now > pcoins:
			for _k in coins_now - pcoins:
				pawn.add_coin()
			Sfx.play("bumper", -8.0)
			board_dirty = true
		if st != pst:
			board_dirty = true
			if st == TiltPawn.PState.FALLING and pst == TiltPawn.PState.STANDING:
				pawn.mirror_begin_fall()
				Sfx.play("death")
				_shake = maxf(_shake, 0.3)
				# DECIDING MOMENT on the mirror: the host's deep freeze already
				# slows the snapshot stream; add only the local fov punch when
				# this fall leaves <=1 standing in the new snapshot.
				var standing_now := 0
				for e in pw:
					if int((e as Array)[0]) == int(TiltPawn.PState.STANDING):
						standing_now += 1
				if standing_now <= 1 and roster.size() >= 2:
					FinalStretch.fov_punch(cam, 50.0, 6.0, 0.8)
			elif st == TiltPawn.PState.GONE and pst != TiltPawn.PState.GONE:
				_splash_fx(pawn.global_position, 1.0)
				Sfx.play("splat", -2.0)
				pawn.vanish()
		if first and st == TiltPawn.PState.STANDING:
			pawn.mirror_pose_standing(Vector2(float(d[1]), float(d[2])), float(d[4]),
				false, (flags & 2) != 0, 0.0)
	# --- scores
	var pts: Array = state.get("pts", [])
	for i in mini(pts.size(), roster.size()):
		if int(points.get(i, 0)) != int(pts[i]):
			points[i] = int(pts[i])
			board_dirty = true
	# --- gulls: spawn on arrival, bombs from counters
	var gl: Dictionary = state.get("gl", {})
	var pgl: Dictionary = prev.get("gl", {})
	for k in gl:
		var seat := int(k)
		var arr: Array = gl[k]
		var at := Vector2(float(arr[0]), float(arr[1]))
		if not gulls.has(seat):
			_mirror_spawn_gull(seat, at)
			board_dirty = true
		_mir_gull[seat] = at
		var pb: int = int((pgl[k] as Array)[2]) if pgl.has(k) else 0
		if int(arr[2]) > pb and gulls.has(seat):
			_mir_guanos.append({"node": _guano_visual((gulls[seat] as TiltSeagull).global_position),
				"vel": Vector3(0, -1.0, 0)})
			Sfx.play("card", -4.0)
	# --- coins + splats: reconcile lists (positions are immutable once spawned)
	_mirror_reconcile_coins(state.get("cn", []))
	_mirror_reconcile_splats(state.get("sp", []))
	# --- clash + round/match flourishes
	if int(state.get("cl", 0)) > int(prev.get("cl", 0)):
		var cp: Array = state.get("clp", [])
		if cp.size() >= 3:
			var world := Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
			_clash_fx(world)
			_floaty(world + Vector3(0, 1.1, 0), "CLASH!", Color(1.0, 0.9, 0.25))
		Sfx.play("bumper", -2.0)
		_shake = maxf(_shake, 0.16)
	if int(state.get("rw", 0)) > int(prev.get("rw", 0)):
		var w := int(state.get("rww", -1))
		if w >= 0 and w < pawns.size():
			_confetti((pawns[w] as TiltPawn).global_position + Vector3(0, 1.6, 0),
				(roster[w] as Dictionary).color)
	var mwv := int(state.get("mw", -1))
	if mwv >= 0 and int(prev.get("mw", -1)) < 0:
		if _stretch != null:
			_stretch.match_ended()
		Sfx.play("match_win")
		var champ_pawn: TiltPawn = pawns[mwv]
		var cpos: Vector3 = champ_pawn.global_position + Vector3(0, 1.6, 0) \
				if champ_pawn.state == TiltPawn.PState.STANDING else Vector3(0, 3, 0)
		_confetti(cpos, (roster[mwv] as Dictionary).color)
		print("TILT_MIRROR match winner=%d" % mwv)
		VerifyCapture.snap("mirror_matchend")
	# --- phase-entry juice
	if ph != prev_ph:
		print("TILT_MIRROR phase -> %s rn=%d t=%.1f" % [Phase.keys()[ph], rn, game_t])
		match ph:
			Phase.PLAY:
				if prev_ph == Phase.INTRO:
					Sfx.play("confirm")
			Phase.ROUND_END:
				Sfx.play("round_over")
	if board_dirty:
		_rebuild_scoreboard()

## CLIENT, per physics tick: everything that must be smoother than 20 Hz —
## the platter chase (the game IS this transform), pawn/gull glides, cosmetic
## bomb ballistics, and the low-side klaxon off the mirrored tilt.
func _mirror_tick(delta: float) -> void:
	if _mir.is_empty():
		return
	game_t += delta   # local clock between snapshots (fades/twirls); resynced per apply
	platter.mirror_set_tilt(platter.tilt.lerp(_mir_tilt, 1.0 - exp(-12.0 * delta)), delta)
	if phase == Phase.PLAY and platter.tilt_deg() > TiltPlatter.WARN_DEG:
		klaxon_t -= delta
		if klaxon_t <= 0.0:
			Sfx.play("invalid", -6.0)
			klaxon_t = 0.9
	else:
		klaxon_t = 0.0
	for i in mini(_mir_pawn.size(), pawns.size()):
		var d: Array = _mir_pawn[i]
		var pawn: TiltPawn = pawns[i]
		var st := int(d[0])
		if st == TiltPawn.PState.STANDING and pawn.state == TiltPawn.PState.STANDING:
			var lp := pawn.lpos.lerp(Vector2(float(d[1]), float(d[2])), 1.0 - exp(-14.0 * delta))
			var fa := lerp_angle(atan2(pawn.facing.x, pawn.facing.y), float(d[4]),
				1.0 - exp(-14.0 * delta))
			pawn.mirror_pose_standing(lp, fa, (int(d[6]) & 1) != 0, (int(d[6]) & 2) != 0, delta)
		elif st == TiltPawn.PState.FALLING and pawn.state == TiltPawn.PState.FALLING:
			pawn.mirror_fall_pose(Vector3(float(d[1]), float(d[3]), float(d[2])), delta)
	for seat in _mir_gull:
		if gulls.has(seat):
			var g: TiltSeagull = gulls[seat]
			var before := Vector2(g.position.x, g.position.z)
			var after := before.lerp(_mir_gull[seat], 1.0 - exp(-10.0 * delta))
			g.position.x = after.x
			g.position.z = after.y
			g.mirror_tick(delta, (after - before) / maxf(delta, 0.0001))
	for i in range(_mir_guanos.size() - 1, -1, -1):
		var gg: Dictionary = _mir_guanos[i]
		var vel: Vector3 = gg.vel
		vel.y -= GUANO_GRAV * delta
		gg.vel = vel
		var node: Node3D = gg.node
		node.global_position += vel * delta
		var lp3: Vector3 = platter.disc.global_transform.affine_inverse() * node.global_position
		var landed: bool = lp3.y <= TiltPlatter.PAWN_Y + 0.05 \
				and Vector2(lp3.x, lp3.z).length() <= TiltPlatter.RADIUS
		if landed or node.global_position.y < OCEAN_Y + 0.3:
			if not landed:
				_splash_fx(node.global_position, 0.4)
			node.queue_free()
			_mir_guanos.remove_at(i)
	# paired evidence snap: the RENDERED platter crossing 8 deg on this screen
	# (the host fires its "net_tilting" twin from the same condition)
	if not _snap_mir_tilt and phase == Phase.PLAY and platter.tilt_deg() >= 8.0:
		_snap_mir_tilt = true
		VerifyCapture.snap("mirror_tilting")

## Mirror round boundary: same board scrub _start_round does, no sim kick.
func _mirror_round_reset(rn: int, first: bool) -> void:
	round_num = rn
	sudden_death = false
	overtime = false
	if _stretch != null:
		_stretch.round_reset()   # light bed + re-armed ladder, same as the host
	klaxon_t = 0.0
	platter.reset()
	_mir_tilt = Vector2.ZERO
	for arr in [loose_coins, splats]:
		for e in arr:
			(e.node as Node3D).queue_free()
		arr.clear()
	for g in _mir_guanos:
		(g.node as Node3D).queue_free()
	_mir_guanos.clear()
	for p in gulls:
		(gulls[p] as TiltSeagull).queue_free()
	gulls.clear()
	_mir_gull.clear()
	for i in roster.size():
		(pawns[i] as TiltPawn).reset_for_round(_spawn_pos(i))
	round_label.text = "ROUND %d / %d" % [rn, rounds_total]
	if not first:
		_refresh_hint()
	_rebuild_scoreboard()

func _mirror_spawn_gull(p: int, at: Vector2) -> void:
	var gull := TiltSeagull.new()
	gull.name = "Gull%d" % p
	add_child(gull)
	gull.setup(p, (roster[p] as Dictionary).color)
	gull.position = Vector3(at.x, 1.0, at.y)
	gulls[p] = gull
	_refresh_hint()

func _mirror_reconcile_coins(cn: Array) -> void:
	var want := {}
	for c in cn:
		want["%.2f|%.2f" % [float(c[0]), float(c[1])]] = c
	for i in range(loose_coins.size() - 1, -1, -1):
		var lc: Dictionary = loose_coins[i]
		var key := "%.2f|%.2f" % [(lc.l as Vector2).x, (lc.l as Vector2).y]
		if want.has(key):
			want.erase(key)
		else:
			(lc.node as Node3D).queue_free()
			loose_coins.remove_at(i)
	for key in want:
		var c: Array = want[key]
		_coin_visual(Vector2(float(c[0]), float(c[1])))

func _mirror_reconcile_splats(sp: Array) -> void:
	var want := {}
	for s in sp:
		want["%.2f|%.2f|%d" % [float(s[0]), float(s[1]), int(s[2])]] = s
	for i in range(splats.size() - 1, -1, -1):
		var e: Dictionary = splats[i]
		var key := "%.2f|%.2f|%d" % [(e.l as Vector2).x, (e.l as Vector2).y, int(e.owner)]
		if want.has(key):
			want.erase(key)
		else:
			(e.node as Node3D).queue_free()
			splats.remove_at(i)
	for key in want:
		var s: Array = want[key]
		_splat_visual(Vector2(float(s[0]), float(s[1])), int(s[2]), game_t + float(s[3]))

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
