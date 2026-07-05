class_name ThroneBots
extends RefCounted
## Seeded self-play bots (spec MUST: "challengers gang the seat, then scramble").
## One brain per player, personality drawn from the seeded RNG so runs are
## reproducible per seed. decide() runs once per physics tick per player in
## player order, so the RNG stream stays deterministic.
##
## Behaviour:
##  - I am KING  -> blast challengers who crowd the dais (A), and drop a guard
##    on the most-threatened open approach when one closes in (B).
##  - throne EMPTY -> SCRAMBLE: sprint (and dash) for the seat.
##  - someone else REIGNS -> GANG UP: converge on the throne and shove to drain
##    the king's grip, dodging any guard wall in the way.

var rng := RandomNumberGenerator.new()
var aggression: Array = []      # per player 0..1: how hard they chase the king
var ambition: Array = []        # per player 0..1: how fast they commit to the seat
var wander_ang: Array = []
var wander_t: Array = []
var _blast_react: Array = []    # king: small delay so blasts aren't frame-perfect

func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	aggression.clear(); ambition.clear(); wander_ang.clear(); wander_t.clear(); _blast_react.clear()
	for i in n:
		aggression.append(rng.randf_range(0.55, 0.95))
		ambition.append(rng.randf_range(0.45, 0.95))
		wander_ang.append(rng.randf_range(0.0, TAU))
		wander_t.append(0.0)
		_blast_react.append(0.0)

## g is the throne.gd root. Returns {move: Vector2, a: bool, b: bool}.
## The controller maps a/b to the right verb for the royal's current mode and
## validates every cooldown, so the bot only expresses intent.
func decide(p: int, g, delta: float) -> Dictionary:
	var out := {"move": Vector2.ZERO, "a": false, "b": false}
	var me: Royal = g.royals_by_index(p)
	if me == null:
		return out
	var my_pos := Vector2(me.global_position.x, me.global_position.z)
	var seat := Vector2(g.SEAT_POS.x, g.SEAT_POS.z)

	# ------------------------------------------------------- I am the king
	if g.king == p:
		var threat := _nearest_challenger_dist(p, g, seat)
		# blast when a challenger crowds the dais and it's worth the fatigue
		_blast_react[p] = maxf(0.0, _blast_react[p] - delta)
		if threat.dist < g.DECREE_TRIGGER and g.decree_cd <= 0.0:
			if _blast_react[p] <= 0.0:
				out["a"] = true
				_blast_react[p] = rng.randf_range(0.15, 0.4)
		# drop a guard toward a challenger closing from open ground
		if threat.dist < g.GUARD_TRIGGER and g.guard_cd <= 0.0 and g.active_guard == null:
			out["b"] = true
		return out

	# ------------------------------------------------------- throne is empty
	if g.king < 0:
		if me.re_sit_cd > 0.0:
			# just got launched: circle back toward the dais, ready to re-enter
			out["move"] = _approach_seat(my_pos, seat, p, g, delta, 0.6)
			return out
		# Only the challenger nearest the empty seat commits to dead-centre;
		# the rest hold a standoff ring, poised to gang the instant someone
		# sits. This keeps the scramble lively AND stops four bodies from
		# jamming the dead-centre so hard that nobody can actually sit.
		var my_d := my_pos.distance_to(seat)
		var am_closest := true
		for r in g.royals():
			if r.index == p or r.is_king or r.re_sit_cd > 0.0:
				continue
			if Vector2(r.global_position.x, r.global_position.z).distance_to(seat) < my_d - 0.1:
				am_closest = false
				break
		if am_closest:
			var to_seat := seat - my_pos
			out["move"] = to_seat.normalized() if to_seat.length() > 0.12 else Vector2.ZERO
			if to_seat.length() > 2.6 and me._dash_cd <= 0.0:
				out["b"] = true
		else:
			var away := my_pos - seat
			if away.length() < 0.1:
				away = Vector2(cos(wander_ang[p]), sin(wander_ang[p]))
			var hold := seat + away.normalized() * 2.15
			var to_hold := hold - my_pos
			out["move"] = to_hold.normalized() if to_hold.length() > 0.35 else Vector2.ZERO
		return out

	# ------------------------------------------------------- someone reigns: gang up
	var king_royal: Royal = g.royals_by_index(g.king)
	var kpos := seat
	if king_royal != null:
		kpos = Vector2(king_royal.global_position.x, king_royal.global_position.z)
	var to_king := kpos - my_pos
	var d := to_king.length()
	out["move"] = _approach_seat(my_pos, kpos, p, g, delta, 1.0)
	# shove the instant we're in range (controller enforces the 0.7s cd)
	if d < Royal.SHOVE_RANGE * 0.95:
		# face the king before shoving: point move straight at them
		out["move"] = to_king.normalized() if d > 0.05 else Vector2.ZERO
		out["a"] = true
	elif d > 3.0 and me._dash_cd <= 0.0 and aggression[p] > 0.6:
		out["b"] = true    # dash to close the gap and join the mob
	return out

## Steer toward a target on the dais, curving around any active guard wall and
## adding a little seeded spread so the mob doesn't collapse to one point.
func _approach_seat(my_pos: Vector2, target: Vector2, p: int, g, delta: float, urgency: float) -> Vector2:
	var to_t := target - my_pos
	var mv := to_t.normalized() if to_t.length() > 0.1 else Vector2.ZERO
	# guard avoidance: if a wall sits between me and the dais, slide sideways
	if g.active_guard != null and is_instance_valid(g.active_guard):
		var gp: Vector2 = Vector2(g.active_guard.global_position.x, g.active_guard.global_position.z)
		var gd := my_pos.distance_to(gp)
		if gd < 2.0 and to_t.dot(gp - my_pos) > 0.0:
			var perp := Vector2(-mv.y, mv.x)
			if perp.dot(my_pos - gp) < 0.0:
				perp = -perp
			mv = (mv + perp * 1.4).normalized()
	# seeded spread so four bots attack from a spread of angles, not a stack
	wander_t[p] -= delta
	if wander_t[p] <= 0.0:
		wander_t[p] = rng.randf_range(0.7, 1.6)
		wander_ang[p] += rng.randf_range(-1.1, 1.1)
	var spread := Vector2(cos(wander_ang[p]), sin(wander_ang[p])) * (0.35 * (1.0 - urgency * 0.5))
	mv = (mv + spread)
	return mv.normalized() if mv.length() > 0.05 else Vector2.ZERO

func _nearest_challenger_dist(king_p: int, g, seat: Vector2) -> Dictionary:
	var best := 1e9
	var bi := -1
	for r in g.royals():
		if r.index == king_p or r.is_king:
			continue
		var d: float = Vector2(r.global_position.x, r.global_position.z).distance_to(seat)
		if d < best:
			best = d
			bi = r.index
	return {"dist": best, "index": bi}
