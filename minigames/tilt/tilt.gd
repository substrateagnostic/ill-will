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
var coin_timer := 0.0
var klaxon_t := 0.0

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
	bots = TiltBots.new()
	bots.setup(int(config.rng_seed) ^ 0x5EA9, roster.size())
	# Per-player: a seat is bot-driven if the roster says so (shell sets this
	# from estate._is_bot; standalone fills it from PlayerInput) OR the legacy
	# --tiltbots flag forces ALL bots. Test modes force all seats to bots (their
	# input is overridden to zero anyway). Decided here at begin() from roster
	# data only - never from runtime Input reads - so the sim stays reproducible.
	bot_enabled.clear()
	for i in roster.size():
		bot_enabled.append(_bots_all or _test_mode != "" or bool(roster[i].get("bot", false)))
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
	_log("begin players=%d seed=%d rounds=%d bots=%s test=%s" % [
		roster.size(), int(config.rng_seed), rounds_total, str(bot_enabled), _test_mode])
	if _test_mode != "":
		_setup_test()
	else:
		_start_round()

# -- per-tick orchestration --------------------------------------------------

func _physics_process(delta: float) -> void:
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
			if phase_t >= 2.5 and not _reported:
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
			pawn.in_slip = _in_slip(pawn.lpos)
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
	# timeout
	if phase == Phase.PLAY and round_t >= round_time:
		_end_round("timeout")
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
	# HUD timer
	if phase == Phase.PLAY or phase == Phase.INTRO:
		var remain := int(ceil(maxf(0.0, round_time - round_t)))
		timer_label.text = str(remain)
		var hot := sudden_death or remain <= 10
		timer_label.add_theme_color_override("font_color",
			Color(1, 0.3, 0.2) if hot else Color(1, 0.92, 0.6))
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
	_clash_fx(world)
	_floaty(world + Vector3(0, 1.1, 0), "CLASH!", Color(1.0, 0.9, 0.25))
	Sfx.play("bumper", -2.0)
	_shake = maxf(_shake, 0.16)
	_log("clash p%d<->p%d kb=%.1f r=[%.1f,%.1f]" % [
		p, q, CLASH_KB, pa.lpos.length(), pb.lpos.length()])

func _in_slip(lp: Vector2) -> bool:
	for s in splats:
		if (s.l as Vector2).distance_to(lp) < SLIP_RADIUS:
			return true
	return false

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
	# Optional contract reporting: one kill_event per overboard fall. killer is
	# the crediting shover (same test as the royalty below) or -1 for a solo
	# fall. Pure bookkeeping — the sim is untouched by this line.
	_kill_events.append({"killer": shover, "victim": p, "cause": "ring_out"})
	Sfx.play("death")
	_shake = maxf(_shake, 0.3)
	_slow_mo()
	if shover >= 0:
		shove_falls[shover] = int(shove_falls[shover]) + 1
		var sn: Dictionary = roster[shover]
		_currency.append({"type": "royalty", "player": shover, "amount": 1,
			"reason": "shoved %s overboard" % pl.name})
		_flash_banner("%s SHOVED %s OVERBOARD!" % [sn.name, pl.name], sn.color, 1.8)
	else:
		_flash_banner("%s OVERBOARD!" % pl.name, pl.color, 1.6)
	_log("fall p%d shover=%d tilt=%.1f" % [p, shover, platter.tilt_deg()])
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
		if p < bot_enabled.size() and not bot_enabled[p] and gulls.has(p):
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

func _spawn_guano(from: Vector3, owner_p: int) -> void:
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
	guanos.append({"node": node, "vel": Vector3(0, -1.0, 0), "owner": owner_p})
	Sfx.play("card", -4.0)
	_log("guano p%d" % owner_p)

func _make_splat(l: Vector2, owner_p: int) -> void:
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
	splats.append({"node": node, "mat": mat, "l": l, "until": game_t + SLIP_TIME})
	Sfx.play("splat", -6.0)
	# direct hit: staggers anyone underneath
	for q in roster.size():
		var pawn: TiltPawn = pawns[q]
		if pawn.state == TiltPawn.PState.STANDING and pawn.lpos.distance_to(l) < 1.0:
			pawn.slide += platter.downhill() * 2.2 + (pawn.lpos - l).normalized() * 1.2
			gull_hits[owner_p] = int(gull_hits[owner_p]) + 1
			_log("guano_hit p%d by gull p%d" % [q, owner_p])

func _spawn_coin() -> void:
	var r := clampf(absf(rng.randfn(0.0, 2.2)), 0.0, 5.7)
	var ang := rng.randf_range(0.0, TAU)
	var l := Vector2(cos(ang), sin(ang)) * r
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
	_flash_banner("SUDDEN DEATH\nTHE PIN RISES", Color(1, 0.3, 0.2), 2.2)
	Sfx.play("grudge")
	_shake = maxf(_shake, 0.2)
	_log("sudden_death")

# -- round / match flow -------------------------------------------------------

func _start_round() -> void:
	phase = Phase.INTRO
	phase_t = 0.0
	round_t = 0.0
	_last_status = 0.0
	sudden_death = false
	coin_timer = COIN_INTERVAL
	elim_order.clear()
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
	_flash_banner("ROUND %d" % round_num, Color(1, 0.85, 0.2), 1.2)
	if round_num == 1:
		hint_label.text = TILT_HINT_BASE
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
		_flash_banner("TIME!  %d SURVIVORS SPLIT THE WIN  +%d" % [survivors.size(), share],
			Color(1, 0.85, 0.2), 2.8)
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
	_flash_banner("%s WINS TILT!" % champ_pl.name, champ_pl.color, 9999.0)
	Sfx.play("match_win")
	var champ_pawn: TiltPawn = pawns[champ]
	if champ_pawn.state == TiltPawn.PState.STANDING:
		champ_pawn.cheer()
		_confetti(champ_pawn.global_position + Vector3(0, 1.6, 0), champ_pl.color)
	else:
		_confetti(Vector3(0, 3, 0), champ_pl.color)
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

func _slow_mo() -> void:
	if _slowmo:
		return
	_slowmo = true
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.32, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo = false

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

func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var pawn: TiltPawn = pawns[i]
		var standing: bool = pawn.state == TiltPawn.PState.STANDING
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(i, 24)
		badge.color = pl.color
		if not standing:
			badge.dim = 0.45
		hb.add_child(badge)
		var row := Label.new()
		var extras := ""
		if standing:
			if pawn.coins > 0:
				extras = "  x%d coins" % pawn.coins
		else:
			extras = "  GULL"
		row.text = "%s  %d%s" % [pl.name, int(points.get(i, 0)), extras]
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", pl.color)
		row.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
		row.add_theme_constant_override("outline_size", 5)
		hb.add_child(row)
		score_rows.add_child(hb)

func _log(msg: String) -> void:
	var f := -1
	if _vc != null:
		f = int(_vc.frame)
	print("TILT_EVT t=%.2f frame=%d | %s" % [game_t, f, msg])
