class_name LWBots
extends RefCounted
## Seeded self-play brains (spec MUST). One personality per player drawn
## from the seeded RNG so runs reproduce per seed. decide_racer() runs once
## per physics tick per living bot, in player order — the RNG stream is
## deterministic.
##
## Racer brain priority: don't be under the boulder > don't be in a scythe's
## strip when the blade is low > hop the ossuary gaps (imperfectly — the race
## REQUIRES bodies) > thread the stones/wall openings > hold the walkway >
## run for the crypt. Shove opportunism near edges and gap lips.
##
## Will-draft brain: seeded-spiteful — prefer the curse card whose stretch
## lies just AHEAD of the race leader. Ghost brain: aim the gust at the
## leader, release when the push has a void-ward or backward component.

var rng := RandomNumberGenerator.new()
var aggr: Array = []          # shove eagerness 0..1
var hop_skill: Array = []     # hop-timing skill 0..1 (gaps + boulders)
var caution: Array = []       # edge margin personality
var lane_bias: Array = []     # preferred lateral lane -1..1
var wander_a: Array = []      # wander angle
var _gust_hold: Array = []    # how long a ghost has been sitting on a ready gust
var _stall_t: Array = []      # seconds without forward progress (desperation)
var _last_px: Array = []
var _gap_roll: Array = []     # per-bot {gap_index: bool} — ONE hop roll per approach

func setup(seed_value: int, n: int) -> void:
	rng.seed = seed_value
	aggr.clear()
	hop_skill.clear()
	caution.clear()
	lane_bias.clear()
	wander_a.clear()
	_gust_hold.clear()
	_stall_t.clear()
	_last_px.clear()
	for i in n:
		aggr.append(rng.randf_range(0.35, 0.95))
		hop_skill.append(rng.randf_range(0.45, 0.9))
		caution.append(rng.randf_range(0.8, 1.6))
		lane_bias.append(rng.randf_range(-0.8, 0.8))
		wander_a.append(rng.randf_range(0.0, TAU))
		_gust_hold.append(0.0)
		_stall_t.append(0.0)
		_last_px.append(-999.0)
		_gap_roll.append({})

## g = last_will.gd root. Returns {move: Vector2 (x=course dir, y=z), a, b}.
func decide_racer(p: int, g, pawn: LWPawn, delta: float) -> Dictionary:
	var px: float = pawn.global_position.x
	var pz: float = pawn.global_position.z
	var move := Vector2.ZERO
	var press_a := false
	var press_b := false
	var danger := false

	# desperation clock: a bot that has made no forward progress for 5s stops
	# respecting red lights (better a body than a statue — the race must end)
	if px > float(_last_px[p]) + 0.4:
		_last_px[p] = px
		_stall_t[p] = 0.0
	else:
		_stall_t[p] = float(_stall_t[p]) + delta
	var desperate: bool = float(_stall_t[p]) > 5.0
	if float(_stall_t[p]) > 8.0 and pawn.is_grounded():
		if rng.randf() < 0.06:
			press_b = true   # hop at whatever is pinning us

	# -- 1) boulders crossing the road: hop late, sidestep early
	for b in g.boulders:
		if b.state != LWBoulder.BState.ROLLING and b.state != LWBoulder.BState.TELEGRAPH:
			continue
		var lane_x: float = b.rock_pos().x
		var off_lane := px - lane_x
		if absf(off_lane) > LWBoulder.RADIUS + 1.15:
			continue
		if b.state == LWBoulder.BState.TELEGRAPH:
			# lane is only warned: keep moving through or hold before it
			move.x += signf(off_lane if absf(off_lane) > 0.05 else 1.0) * 1.2
			danger = true
			continue
		var rp: Vector3 = b.rock_pos()
		var to_me := Vector2(px - rp.x, pz - rp.z)
		var closing: float = to_me.dot(b.dir)   # >0 = the rock is behind, rolling at us
		var dist := to_me.length()
		if closing > -0.5 and dist < 4.6:
			danger = true
			if dist < 2.35:
				# hop window — imperfect on purpose
				if rng.randf() < hop_skill[p] * 0.5:
					press_b = true
			else:
				move.x += signf(off_lane if absf(off_lane) > 0.05 else 1.0) * 2.0

	# -- 2) scythe gates as traffic lights: cross only when the blade has
	#       passed our lane and is receding; otherwise PARK just short of the
	#       strip (a desperate bot jaywalks — the race must end)
	for gate in g.blade_gates():
		var gx := float(gate.x)
		var dx := gx - px
		if dx < -1.4 or dx > 4.2:
			continue
		var strip := LWPendulum.HIT_PERP + 0.45
		var rel_z := float(gate.z) - pz
		var vs := float(gate.vs)
		var moving_away: bool = (vs > 0.0 and rel_z > 0.05) or (vs < 0.0 and rel_z < -0.05)
		var safe: bool = (absf(rel_z) > 1.9 and moving_away) or absf(rel_z) > 5.2
		if absf(dx) <= strip:
			move.x += 3.0   # inside the strip: clear it, hard
			danger = true
		elif dx > strip:
			if safe or desperate:
				move.x += 1.4
			else:
				# red light: park just outside the strip
				var hold_pt := gx - (strip + 0.8)
				move.x += clampf((hold_pt - px) * 1.4, -2.8, 0.5)
				danger = true

	# -- 3) the ossuary gaps: ONE timing roll per approach — a failed roll is
	#       a body in the dusk (the race REQUIRES bodies)
	for gi in LWCourse.GAPS.size():
		var g0 := float(LWCourse.GAPS[gi][0])
		var lead := g0 - px
		var rolls: Dictionary = _gap_roll[p]
		if lead > 6.0 or lead < -3.0:
			rolls.erase(gi)
			continue
		if lead > 0.5 and lead <= 2.1 and pawn.is_grounded() and pawn.linear_velocity.x > 1.2:
			if not rolls.has(gi):
				rolls[gi] = rng.randf() < (0.5 + hop_skill[p] * 0.48)
			if bool(rolls[gi]) and lead < 1.7:
				press_b = true
			danger = true

	# -- 4) stones ranks + wall pushers: thread the opening. The thread target
	#       OVERRIDES lane-keeping (v1 bug: the lane spring out-pulled the
	#       gap steer and parked three bots against the stones forever)
	var has_thread := false
	var thread_z := 0.0
	for cu in g.curses:
		if cu.kind == "stones":
			var dxs: float = cu.center_x() - px
			if dxs > -0.5 and dxs < 5.0:
				has_thread = true
				thread_z = cu.stones_gap_z()
				danger = true
	for w in g.walls:
		var dxw: float = w.wall_x() - px
		if dxw > 0.2 and dxw < 3.5:
			has_thread = true
			thread_z = w.gap_z()
			danger = true

	# -- 5) hold the walkway: thread target if any, else center + personal lane
	var zc := LWCourse.z_center(px + 1.2)
	var hw := LWCourse.half_width(px + 1.2)
	if has_thread:
		move.y += clampf(thread_z - pz, -2.2, 2.2) * 1.6
	else:
		var want_z: float = zc + float(lane_bias[p]) * maxf(hw - 1.2, 0.0)
		var zerr: float = pz - want_z
		move.y += -zerr * 0.55
	if absf(pz - zc) > hw - 0.45 - caution[p] * 0.15:
		move.y += -signf(pz - zc) * (1.2 if has_thread else 2.4)
		danger = true

	# -- 6) the crypt calls
	move.x += 1.7

	# -- 7) shove opportunism: rivals near the edge or a gap lip are invitations
	var target: LWPawn = null
	var best_d := 1e9
	for other in g.living_pawns():
		if other == pawn or not other.alive:
			continue
		var d: float = pawn.global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			target = other
	if target != null and best_d < LWPawn.SHOVE_RANGE + 0.05:
		var tz: float = target.global_position.z
		var tzc := LWCourse.z_center(target.global_position.x)
		var thw := LWCourse.half_width(target.global_position.x)
		var kill_bonus := 0.0
		if absf(tz - tzc) > thw - 1.0:
			kill_bonus += 0.3
		for gap in LWCourse.GAPS:
			if float(gap[0]) - target.global_position.x < 2.0 and float(gap[0]) > target.global_position.x - 0.5:
				kill_bonus += 0.35
		if rng.randf() < aggr[p] * 0.1 + kill_bonus * 0.5:
			press_a = true

	# -- 8) seeded wander so mirror bots diverge
	wander_a[p] += rng.randf_range(-0.8, 0.8) * delta
	move += Vector2(cos(wander_a[p]), sin(wander_a[p])) * 0.2

	if move.length() > 0.01:
		move = move.normalized()
	if danger and press_a:
		press_a = false   # no showboating mid-dodge
	return {"move": move, "a": press_a, "b": press_b}

## Ghost brain: {aim: Vector2, fire: bool}. Harass the race leader.
func decide_ghost(p: int, g, ghost: LWGhostSeat, delta: float) -> Dictionary:
	var leader: int = g.race_leader_alive()
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
		aim = Vector2(1, 0)
	aim = aim.normalized()
	var fire := false
	if ghost.gust_ready():
		_gust_hold[p] += delta
		# release when the push carries the leader VOID-WARD (off the walkway
		# center line) or BACKWARD — or we've sat on it for 4 seconds
		var zc := LWCourse.z_center(tp.x)
		var edge_gain: float = aim.y * signf(tp.y - zc) if absf(tp.y - zc) > 0.2 else 0.0
		var back_gain: float = -aim.x
		if edge_gain > 0.2 or back_gain > 0.55 or _gust_hold[p] > 4.0:
			fire = true
			_gust_hold[p] = 0.0
	return {"aim": aim, "fire": fire}

## --- will draft (seeded, spiteful) --------------------------------------
## Prefer the card whose condemned stretch lies just AHEAD of the race
## leader; a seeded quarter of the time, pure caprice.
func draft_card(_p: int, g, cards: Array) -> int:
	var pick := rng.randi_range(0, cards.size() - 1)
	if rng.randf() < 0.25:
		return pick
	var leader_x: float = g.race_leader_x()
	var best := -1
	var best_lead := 1e9
	for i in cards.size():
		var cx := float(cards[i].slot.x)
		var lead := cx - leader_x
		if lead > -2.0 and lead < best_lead:
			best_lead = lead
			best = i
	return best if best >= 0 else pick
