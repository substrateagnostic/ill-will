class_name WGBots
extends RefCounted
## Seeded self-play mourners for THE WIDOW'S GAZE. Each bot has:
##   react   — how long after the STING starts before it slams on the brakes.
##             Small = safe (stops with decel time to spare); large = greedy
##             and gets CAUGHT (it over-runs the whip). One bot is seeded
##             deliberately greedy so the room has a reliable victim/pace-setter.
##   greed   — prefers fatter, deeper relics (nearer the Widow) over near ones.
##   malice  — chance to SHOVE a rival into the gaze (a murder) near the red.
##   poise   — chance to freeze mid-stride in a funny mourning pose on green.
##
## decide() runs once per physics tick per player, in player order, off a seeded
## RNG so bot-only runs are reproducible per seed. The controller still validates
## every range / cooldown / catch, exactly as it does for humans.

var rng := RandomNumberGenerator.new()
var react: Array = []
var greed: Array = []
var malice: Array = []
var poise: Array = []
var _target: Array = []       # per-bot chosen relic index (-1 = none / re-pick)
var _wander_t: Array = []
var _react_now: Array = []    # per-sting effective reaction (jittered per sting)
var _seq_seen: Array = []     # last sting_seq this bot rerolled for
var _rest_t: Array = []       # post-bank mourning pause (paces the wake-stripping)
var _banked_seen: Array = []  # per-bot bank count last tick (detects a fresh bank)


func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	react.clear(); greed.clear(); malice.clear(); poise.clear()
	_target.clear(); _wander_t.clear(); _react_now.clear(); _seq_seen.clear()
	for i in n:
		react.append(rng.randf_range(0.15, 0.29))     # careful default: stops in time
		greed.append(rng.randf_range(0.2, 0.7))
		malice.append(rng.randf_range(0.15, 0.55))
		poise.append(rng.randf_range(0.0, 0.5))
		_target.append(-1)
		_wander_t.append(0.0)
		_react_now.append(react[i])
		_seq_seen.append(-1)
		_rest_t.append(rng.randf_range(0.0, 1.2))
		_banked_seen.append(0)
	# one seeded GREEDY mourner: over-runs the greens, hunts the deep relics.
	# It is the pace-setter and the reliable casualty (spec: beatable + killable).
	if n >= 1:
		react[0] = rng.randf_range(0.40, 0.62)
		greed[0] = 0.95
		malice[0] = 0.5
		_react_now[0] = react[0]


## Returns {move: Vector2, grab: bool, shove: bool, pose: bool}. The controller
## validates ranges/cooldowns and resolves the actual grab/shove/catch.
func decide(p: int, g, delta: float) -> Dictionary:
	var me: WGPawn = g.players[p]
	var out := {"move": Vector2.ZERO, "grab": false, "shove": false, "pose": false}
	if me.is_caught() or not me.can_control():
		_target[p] = -1
		return out
	var my_pos := Vector2(me.global_position.x, me.global_position.z)
	# post-bank mourning rest: paces the wake-stripping so the round's endgame
	# (T-25 fake-outs guarding the last relics) actually happens, and leaves a
	# hustling human a real edge over the bots. Points delta covers banks AND
	# murders (a menacing pause after feeding someone to the Widow reads right).
	_rest_t[p] = maxf(0.0, _rest_t[p] - delta)
	if int(g.points[p]) > int(_banked_seen[p]):
		_banked_seen[p] = int(g.points[p])
		if g.phase != g.Phase.TIEBREAK:
			_rest_t[p] = rng.randf_range(1.0, 2.2) if p == 0 else rng.randf_range(2.6, 5.6)

	# Should I be frozen right now? (the whip is coming / gaze is on)
	var must_stop := _should_stop(p, g)

	# --- funny freeze pose, but only when it's safe (green, nowhere to be) ---
	if not must_stop and g.gaze == g.Gaze.WEEPING and not me.carrying:
		_wander_t[p] -= delta
		if _wander_t[p] <= 0.0:
			_wander_t[p] = rng.randf_range(2.5, 5.0)
			if rng.randf() < poise[p] * 0.4:
				out["pose"] = true
				return out

	# --- malice: shove a rival into the gaze near the red (a murder) ---
	if me.shove_cd <= 0.0 and (g.gaze == g.Gaze.WATCHING or
			(g.gaze == g.Gaze.STING and g.gaze_t > react[p] * 0.6)):
		var tgt := _shove_target(p, g, my_pos)
		if tgt >= 0 and rng.randf() < malice[p] * 0.10:
			out["shove"] = true
			var tp: WGPawn = g.players[tgt]
			out["move"] = (Vector2(tp.global_position.x, tp.global_position.z) - my_pos).normalized()
			return out

	if must_stop:
		# FREEZE. The greedy bot's react is long enough that "stopping now" can
		# still leave it caught — that's the whole point.
		out["move"] = Vector2.ZERO
		return out

	# --- carrying: haul to my chest and bank ---
	if me.carrying:
		var chest: Vector2 = g.chest_pos(p)
		var to_chest := chest - my_pos
		if to_chest.length() <= g.BANK_RANGE * 0.8:
			out["grab"] = true          # controller reads A-as-bank at the chest
			out["move"] = Vector2.ZERO
		else:
			out["move"] = to_chest.normalized()
		return out

	# --- empty-handed: mourn a beat after scoring, else pick a relic ---
	if _rest_t[p] > 0.0 and g.phase != g.Phase.TIEBREAK:
		var home := Vector2(g.chest_pos(p).x * 0.7, 4.5)
		var to_h := home - my_pos
		out["move"] = to_h.normalized() if to_h.length() > 0.8 else Vector2.ZERO
		return out
	var idx := _pick_relic(p, g, my_pos)
	if idx < 0:
		# nothing to grab: loiter mid-parlor, poised
		out["move"] = (Vector2(0, 3.0) - my_pos)
		out["move"] = out["move"].normalized() if out["move"].length() > 0.6 else Vector2.ZERO
		return out
	var rpos: Vector2 = g.relic_world_2d(idx)
	var to_r := rpos - my_pos
	if to_r.length() <= g.GRAB_RANGE * 0.75:
		out["grab"] = true
		out["move"] = Vector2.ZERO
	else:
		out["move"] = to_r.normalized()
	return out


## True when the bot ought to be at a dead stop for the gaze. Careful bots reach
## this early in the STING (with decel time to spare); the greedy bot reaches it
## late — sometimes only after the gaze is already ON, so it gets taken.
## Reaction is JITTERED per sting (rerolled on sting_seq change) so the same bot
## sometimes squeaks through and sometimes over-runs — catches feel earned, not
## scripted. Friction needs ~0.21s to bleed under the stop epsilon; a stop that
## starts after ~0.29s into the 0.5s sting is already doomed.
func _should_stop(p: int, g) -> bool:
	if int(g.sting_seq) != int(_seq_seen[p]):
		_seq_seen[p] = int(g.sting_seq)
		_react_now[p] = react[p] * rng.randf_range(0.5, 1.15)
	if g.gaze == g.Gaze.STING:
		return g.gaze_t >= _react_now[p]
	if g.gaze == g.Gaze.WATCHING:
		return g.gaze_t >= maxf(0.0, _react_now[p] - g.STING_TIME)
	return false


func _pick_relic(p: int, g, my_pos: Vector2) -> int:
	# keep the current target if it's still available
	if _target[p] >= 0 and g.relic_available(_target[p]):
		return _target[p]
	var best := -1
	var best_score := -1e9
	for i in g.relics.size():
		if not g.relic_available(i):
			continue
		var rpos: Vector2 = g.relic_world_2d(i)
		var dist := my_pos.distance_to(rpos)
		var val: float = float(g.relics[i].value)
		# greedy bots weight value (the deep, fat relics); careful bots weight
		# proximity (grab the near one, get out).
		var score: float = val * (0.4 + float(greed[p]) * 1.6) - dist * (0.35 - float(greed[p]) * 0.18)
		if score > best_score:
			best_score = score
			best = i
	_target[p] = best
	return best


func _shove_target(p: int, g, my_pos: Vector2) -> int:
	var best := -1
	var best_d: float = g.SHOVE_RANGE
	for q in g.players.size():
		if q == p:
			continue
		var o: WGPawn = g.players[q]
		if o.is_caught() or not o.can_be_caught():
			continue
		var d: float = Vector2(o.global_position.x, o.global_position.z).distance_to(my_pos)
		if d < best_d:
			best_d = d
			best = q
	return best
