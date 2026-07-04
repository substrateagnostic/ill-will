class_name TiltBots
extends RefCounted
## Seeded self-play bots (spec MUST). One brain per player, personalities
## drawn from the seeded RNG so runs are deterministic per seed. decide()
## is called once per physics tick per living player, in player order, so
## the RNG stream is reproducible.
##
## Standing brain: stay safe (uphill/centered) when the platter is angry,
## chase coins when it is calm, shove neighbours when they are in reach —
## preferably when they are downhill of us. Brace when sliding outward fast.
## Seagull brain: pick a survivor, lead their position, bomb from above.

var rng := RandomNumberGenerator.new()
var aggr: Array = []          # per player 0..1, shove eagerness
var greed: Array = []         # coin pull vs safety
var caution_deg: Array = []   # tilt at which the bot starts fleeing uphill
var wander: Array = []        # per player wander angle
var gull_target: Array = []   # per player current victim index
var gull_retarget: Array = [] # countdown to next retarget

func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	aggr.clear()
	greed.clear()
	caution_deg.clear()
	wander.clear()
	gull_target.clear()
	gull_retarget.clear()
	for i in n:
		aggr.append(rng.randf_range(0.45, 0.95))
		greed.append(rng.randf_range(0.55, 1.0))
		caution_deg.append(rng.randf_range(8.0, 12.5))
		wander.append(rng.randf_range(0.0, TAU))
		gull_target.append(-1)
		gull_retarget.append(0.0)

## g is the tilt.gd root; bots read pawns/coins/platter state directly.
func decide(p: int, g, delta: float) -> Dictionary:
	var pawn: TiltPawn = g.pawns[p]
	if pawn.state == TiltPawn.PState.STANDING:
		return _decide_standing(p, g, pawn, delta)
	if g.gulls.has(p):
		return _decide_gull(p, g, delta)
	return {"move": Vector2.ZERO, "a": false, "b": false}

func _decide_standing(p: int, g, pawn: TiltPawn, delta: float) -> Dictionary:
	var tilt_deg: float = g.platter.tilt_deg()
	var dh: Vector2 = g.platter.downhill()
	var move := Vector2.ZERO
	var press_a := false
	var press_b := false
	# counter-shove reflex: someone close is WINDING UP a shove aimed at us
	# AND we can see it (roughly in front of us — a clash needs mutual cones,
	# so blindside shoves stay uncounterable, same as for humans). Answer it
	# (square up + press A) and the shoves clash — rim defense as a timing
	# game. Rolled per tick over the ~7-tick windup, scaled by aggression.
	for q in g.pawns.size():
		if q == p:
			continue
		var threat: TiltPawn = g.pawns[q]
		if threat == null or threat.state != TiltPawn.PState.STANDING:
			continue
		if threat.windup_t <= 0.0:
			continue
		var to_me: Vector2 = pawn.lpos - threat.lpos
		if to_me.length() > 1.9:
			continue
		if absf(rad_to_deg(threat.facing.angle_to(to_me))) > 62.0:
			continue
		if absf(rad_to_deg(pawn.facing.angle_to(-to_me))) > 105.0:
			continue  # didn't see it coming — eat it like it's v1
		var face_them: Vector2 = (-to_me).normalized()
		if pawn.windup_t > 0.0:
			# our answer is already swinging — stay squared up for the clash
			return {"move": face_them, "a": false, "b": false}
		var can_answer: bool = pawn.shove_cd <= 0.0 and not pawn.braced \
				and pawn.stagger_t <= 0.0
		if can_answer:
			# "occasionally": ~25-35% of seen windups get answered over the
			# ~7-tick windup (rolled per tick), ~50% when cornered at the rim
			var desperation: float = 0.04 if pawn.lpos.length() > 4.6 else 0.0
			var answer: bool = rng.randf() < 0.02 + aggr[p] * 0.04 + desperation
			if not answer and pawn.lpos.length() <= 4.6:
				break  # not committing to the duel — v1 behavior instead
			return {"move": face_them, "a": answer, "b": false}
		if pawn.lpos.length() > 5.2 and not pawn.braced and pawn.brace_cd <= 0.0 \
				and pawn.stagger_t <= 0.0 and rng.randf() < 0.05:
			return {"move": Vector2.ZERO, "a": false, "b": true}  # last-ditch brace
		break  # aware but helpless: keep doing whatever v1 would do (flee)
	var my_r := pawn.lpos.length()
	var on_low_side := pawn.lpos.dot(dh) > 0.5
	var in_danger: bool = (tilt_deg > caution_deg[p] and on_low_side) or my_r > 5.6
	if in_danger:
		# run uphill and inward
		move = (-dh * 3.0 - pawn.lpos * 0.45)
		if move.length() > 0.01:
			move = move.normalized()
		# brace if we are sliding outward fast and near the rim
		if pawn.slide.length() > 2.0 and my_r > 4.6 \
				and pawn.slide.dot(pawn.lpos) > 0.0 and pawn.brace_cd <= 0.0 and not pawn.braced:
			press_b = true
	else:
		var target := _best_coin(p, g, pawn, dh, tilt_deg)
		if target.x < 900.0:
			move = (target - pawn.lpos)
			if move.length() > 0.01:
				move = move.normalized()
		else:
			# wander a gentle orbit near mid-radius
			wander[p] += rng.randf_range(-0.9, 0.9) * delta
			var home := Vector2(cos(wander[p]), sin(wander[p])) * 3.4
			var to_home := home - pawn.lpos
			move = to_home.normalized() if to_home.length() > 0.4 else Vector2.ZERO
	# shove opportunism: nearest living neighbour in reach
	var best_d := 999.0
	var victim := -1
	for q in g.pawns.size():
		if q == p:
			continue
		var other: TiltPawn = g.pawns[q]
		if other == null or other.state != TiltPawn.PState.STANDING:
			continue
		var d: float = (other.lpos - pawn.lpos).length()
		if d < best_d:
			best_d = d
			victim = q
	if victim >= 0 and best_d < 1.9:
		var vpawn: TiltPawn = g.pawns[victim]
		var to_v := (vpawn.lpos - pawn.lpos).normalized()
		if not in_danger:
			move = (move * 0.5 + to_v * 0.5).normalized()  # face them, keep purpose
		if best_d < 1.55 and pawn.shove_cd <= 0.0 and not pawn.braced:
			# v1.1: with clashes defusing center scuffles, bots value POSITION:
			# less idle spam in the safe middle (fewer accidental clashes),
			# more pressure the closer the victim is to the edge.
			var kill_bonus := 0.0
			if to_v.dot(dh) > 0.3:
				kill_bonus += 0.25       # they're downhill of me
			if vpawn.lpos.length() > 3.6:
				kill_bonus += 0.18       # they're past mid-radius
			if vpawn.lpos.length() > 4.8:
				kill_bonus += 0.35       # they're near the rim
			if g.sudden_death:
				kill_bonus += 0.15       # no time for pleasantries
			if rng.randf() < (aggr[p] * 0.12 + kill_bonus):
				press_a = true
	return {"move": move, "a": press_a, "b": press_b}

func _best_coin(p: int, g, pawn: TiltPawn, dh: Vector2, tilt_deg: float) -> Vector2:
	var best := Vector2(999.0, 999.0)
	var best_score := 999.0
	for c in g.loose_coins:
		var cl: Vector2 = c.l
		var score: float = (cl - pawn.lpos).length()
		if tilt_deg > 9.0:
			score += 4.0 * maxf(0.0, cl.normalized().dot(dh)) / greed[p]
		if score < best_score:
			best_score = score
			best = cl
	return best

func _decide_gull(p: int, g, delta: float) -> Dictionary:
	gull_retarget[p] -= delta
	var standing: Array = []
	for q in g.pawns.size():
		var other: TiltPawn = g.pawns[q]
		if other != null and other.state == TiltPawn.PState.STANDING:
			standing.append(q)
	if standing.is_empty():
		return {"move": Vector2.ZERO, "a": false, "b": false}
	if gull_retarget[p] <= 0.0 or not standing.has(gull_target[p]):
		gull_target[p] = standing[rng.randi_range(0, standing.size() - 1)]
		gull_retarget[p] = rng.randf_range(2.5, 4.5)
	var victim: TiltPawn = g.pawns[gull_target[p]]
	var gull: TiltSeagull = g.gulls[p]
	# lead the victim slightly
	var vworld: Vector3 = victim.global_position
	var vel := (victim.move_vel + victim.slide)
	var aim := Vector2(vworld.x, vworld.z) + vel * 0.45
	var here := Vector2(gull.position.x, gull.position.z)
	var to_aim := aim - here
	var move := to_aim.normalized() if to_aim.length() > 0.5 else Vector2.ZERO
	var press_a := to_aim.length() < 1.15 and gull.can_bomb()
	return {"move": move, "a": press_a, "b": false}
