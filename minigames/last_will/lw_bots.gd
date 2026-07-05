class_name LWBots
extends RefCounted
## Seeded self-play brains (spec MUST). One personality per player drawn
## from the seeded RNG so runs reproduce per seed. decide_living() runs once
## per physics tick per living bot, in player order — the RNG stream is
## deterministic.
##
## Living brain priority: don't be under the boulder > don't be in the
## pendulum's line > don't be outside the next platform ring > shove someone
## who is > wander toward the action. Hop skill is deliberately imperfect —
## the spec REQUIRES bodies (>=2 wills per round avg across 5 seeds).
##
## Will-draft brain is spiteful by fleet decree: CURSE the current round
## leader, BLESS the second-worst survivor. Card pick is seeded-random.
## Ghost brain: aim the gust at the leader, release when the push has an
## outward component (shoving them toward the void, not to safety).

var rng := RandomNumberGenerator.new()
var aggr: Array = []          # shove eagerness 0..1
var hop_skill: Array = []     # chance per tick window to hop the boulder
var caution: Array = []       # edge margin
var wander_a: Array = []      # wander angle
var _gust_hold: Array = []    # how long a ghost has been sitting on a ready gust

func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	aggr.clear()
	hop_skill.clear()
	caution.clear()
	wander_a.clear()
	_gust_hold.clear()
	for i in n:
		aggr.append(rng.randf_range(0.4, 0.95))
		hop_skill.append(rng.randf_range(0.5, 0.9))
		caution.append(rng.randf_range(0.9, 1.7))
		wander_a.append(rng.randf_range(0.0, TAU))
		_gust_hold.append(0.0)

## g = last_will.gd root. Returns {move: Vector2, a: bool, b: bool}.
func decide_living(p: int, g, pawn: LWPawn, delta: float) -> Dictionary:
	var here := Vector2(pawn.global_position.x, pawn.global_position.z)
	var move := Vector2.ZERO
	var press_a := false
	var press_b := false
	var danger := false

	# -- 1) boulders: hop when one is about to run us over, sidestep early
	for b in g.boulders:
		if b.state != LWBoulder.BState.ROLLING and b.state != LWBoulder.BState.TELEGRAPH:
			continue
		var lane_perp := Vector2(-b.dir.y, b.dir.x)
		var perp_d: float = (here - lane_perp * b.lane_offset).dot(lane_perp)
		if absf(perp_d) > LWBoulder.RADIUS + 1.15:
			continue
		if b.state == LWBoulder.BState.TELEGRAPH:
			# lane is only warned: walk out of it, no panic
			move += lane_perp * signf(perp_d if absf(perp_d) > 0.05 else 1.0) * 1.4
			danger = true
			continue
		var rp: Vector3 = b.rock_pos()
		var to_me := here - Vector2(rp.x, rp.z)
		var closing: float = to_me.dot(b.dir)   # >0 means the rock is behind, rolling at us
		var dist := to_me.length()
		if closing > -0.5 and dist < 4.6:
			danger = true
			if dist < 2.35:
				# hop window — imperfect on purpose
				if rng.randf() < hop_skill[p] * 0.5:
					press_b = true
			else:
				move += lane_perp * signf(perp_d if absf(perp_d) > 0.05 else 1.0) * 2.0

	# -- 2) pendulum line
	for pen in g.pendulums:
		if pen.state == LWPendulum.PState.DONE or pen.state == LWPendulum.PState.RETRACT:
			continue
		var perp: float = here.dot(Vector2(-pen.sweep_dir.y, pen.sweep_dir.x))
		if absf(perp) < LWPendulum.HIT_PERP + 0.9:
			danger = true
			move += Vector2(-pen.sweep_dir.y, pen.sweep_dir.x) * signf(perp if absf(perp) > 0.05 else 1.0) * 2.2

	# -- 3) platform edge / shrink urgency
	var safe_r: float = g.bot_safe_radius() - caution[p] * 0.45
	if here.length() > safe_r:
		move += -here.normalized() * (2.5 if here.length() > safe_r + 0.8 else 1.4)
		danger = true

	# -- 3.5) flee the wisp if we are the haunted one
	if pawn.curse_kind == "haunted":
		var w = g.wisp_pos_for(p)
		if w != null:
			var away := here - Vector2(w.x, w.z)
			if away.length() < 3.0 and away.length() > 0.01:
				move += away.normalized() * 1.6

	# -- 4) hunt: approach nearest rival from the center side, shove outward
	var target: LWPawn = null
	var best_d := 1e9
	for other in g.living_pawns():
		if other == pawn or not other.alive:
			continue
		var d: float = pawn.global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			target = other
	if target != null and not danger:
		var tp := Vector2(target.global_position.x, target.global_position.z)
		var outward := tp
		if outward.length() < 0.4:
			outward = Vector2(0, 1)
		outward = outward.normalized()
		var approach := tp - outward * 1.1
		if best_d < 1.8:
			move += (tp - here)
		else:
			move += (approach - here).limit_length(1.0)
	# shove opportunism runs even while fleeing — on the last pillar there
	# is no "safe", only whoever swings first
	if target != null and best_d < LWPawn.SHOVE_RANGE + 0.05 and pawn.curse_kind != "butterfingers":
		var tp2 := Vector2(target.global_position.x, target.global_position.z)
		var kill_bonus := 0.0
		if tp2.length() > g.platform_radius - 1.6:
			kill_bonus += 0.3
		if g.platform_radius < 2.5:
			kill_bonus += 0.4   # pillar brawl: swing constantly
		if rng.randf() < aggr[p] * 0.14 + kill_bonus:
			press_a = true

	# -- 5) seeded wander so mirror bots diverge
	wander_a[p] += rng.randf_range(-0.8, 0.8) * delta
	move += Vector2(cos(wander_a[p]), sin(wander_a[p])) * 0.25

	if move.length() > 0.01:
		move = move.normalized()
	return {"move": move, "a": press_a, "b": press_b}

## Ghost brain: {aim: Vector2, fire: bool}
func decide_ghost(p: int, g, ghost: LWGhostSeat, delta: float) -> Dictionary:
	var leader: int = g.round_leader_alive()
	if leader < 0:
		return {"aim": ghost.aim_dir, "fire": false}
	var pawn = g.pawn_of(leader)
	if pawn == null:
		return {"aim": ghost.aim_dir, "fire": false}
	var seat := Vector2(ghost.global_position.x, ghost.global_position.z)
	var tp := Vector2(pawn.global_position.x, pawn.global_position.z)
	var lead := Vector2(pawn.linear_velocity.x, pawn.linear_velocity.z) * 0.3
	var aim := (tp + lead - seat)
	if aim.length() < 0.05:
		aim = -seat
	aim = aim.normalized()
	var fire := false
	if ghost.gust_ready():
		_gust_hold[p] += delta
		# only shove when the push sends the leader OUTWARD (or we've waited 4s)
		var outward_gain: float = aim.dot(tp.normalized() if tp.length() > 0.3 else aim)
		if outward_gain > 0.15 or _gust_hold[p] > 4.0:
			fire = true
			_gust_hold[p] = 0.0
	return {"aim": aim, "fire": fire}

## --- will draft (random-but-SPITEFUL) ---------------------------------
func draft_card(_p: int, _g, cards: Array) -> int:
	return rng.randi_range(0, cards.size() - 1)

## curse the round leader among candidates
func draft_curse_target(_p: int, g, candidates: Array) -> int:
	var best: int = candidates[0]
	for c in candidates:
		if g.players[c].total > g.players[best].total:
			best = c
	return best

## bless the second-worst (lowest total among survivors; the worst is us, dead)
func draft_bless_target(_p: int, g, candidates: Array) -> int:
	var best: int = candidates[0]
	for c in candidates:
		if g.players[c].total < g.players[best].total:
			best = c
	return best

## single-survivor mode (2P rule): curse them if they lead us, else bless
func draft_mode(p: int, g, survivor: int) -> String:
	if g.players[survivor].total >= g.players[p].total:
		return "curse"
	return "bless"
