class_name MBBots
extends RefCounted
## Seeded self-play brains for THE CORONER. Guests know only their own current
## icon errand and body. The public Coroner reads only visible floor evidence:
## clock bows, punch-bowl loitering, and sustained west-hall waltzing. NPC fakes
## feed the exact same evidence function, so a tell is evidence, never proof.

var rng := RandomNumberGenerator.new()
var n_seats := 0
var n_bodies := 0
var round_len := 75.0
var photo_mode := false

var _wp: Array = []
var _pause_t: Array = []
var _eval_t: Array = []
var _sus: Array = []
var _hunt_body: Array = []
var _commit_at: Array = []
var _threshold: Array = []
var _alternate_pick: Array = []
var _last_kind: Array = []
var _round := 0
var _coroner := -1

func setup(seed_value: int, seats: int, bodies: int, p_round_len: float) -> void:
	rng.seed = seed_value
	n_seats = seats
	n_bodies = bodies
	round_len = p_round_len
	for arr in [_wp, _pause_t, _eval_t, _sus, _hunt_body, _commit_at,
			_threshold, _alternate_pick, _last_kind]:
		(arr as Array).clear()
	for _i in seats:
		_wp.append(Vector3.ZERO)
		_pause_t.append(0.0)
		_eval_t.append(0.0)
		var row: Array = []
		for _b in bodies:
			row.append(0.0)
		_sus.append(row)
		_hunt_body.append(-1)
		# Coroners deliberate until the last fifth. This keeps bot rounds inside
		# the requested 60-120 second target while humans may still accuse at once.
		_commit_at.append(rng.randf_range(60.0, 62.0))
		_threshold.append(rng.randf_range(4.1, 5.5))
		_alternate_pick.append(rng.randf() < 0.38)
		_last_kind.append(-1)

func begin_round(round_index: int, coroner_seat: int) -> void:
	_round = round_index
	_coroner = coroner_seat
	for i in n_seats:
		_wp[i] = Vector3.ZERO
		_pause_t[i] = rng.randf_range(0.2, 1.0)
		_eval_t[i] = rng.randf_range(0.0, 0.35)
		_hunt_body[i] = -1
		_commit_at[i] = rng.randf_range(60.0, 62.0)
		_threshold[i] = rng.randf_range(4.1, 5.5)
		_alternate_pick[i] = rng.randf() < 0.38
		_last_kind[i] = -1
		for b in n_bodies:
			_sus[i][b] = 0.0
	print("MBC_BOTS_ROUND round=%d coroner=%d commit=%.1f alternate=%s" % [
		round_index + 1, coroner_seat, float(_commit_at[coroner_seat]),
		str(bool(_alternate_pick[coroner_seat]))])

func on_errand_complete(seat: int) -> void:
	if seat < 0 or seat >= n_seats:
		return
	_pause_t[seat] = rng.randf_range(0.7, 1.8)
	_wp[seat] = Vector3.ZERO

## Returns {mv, action}. For a guest, action is the clock bow. For the public
## Coroner it is the one close-range accusation.
func decide_alive(i: int, g, delta: float) -> Dictionary:
	if i == _coroner:
		return _decide_coroner(i, g, delta)
	return _decide_guest(i, g, delta)

func _decide_guest(i: int, g, delta: float) -> Dictionary:
	var own: int = g.body_of(i)
	var here: Vector3 = g.pos_of(own)
	_pause_t[i] = maxf(0.0, float(_pause_t[i]) - delta)
	if float(_pause_t[i]) > 0.0:
		return {"mv": _blend_move(i, here, g), "action": false}
	var kind: int = int(g.errand_kind(i))
	if int(_last_kind[i]) != kind:
		_last_kind[i] = kind
		_wp[i] = Vector3.ZERO
	var center: Vector3 = g.errand_center(kind)
	var radius: float = g.errand_radius(kind)
	var flat := center - here
	flat.y = 0.0
	match kind:
		0: # CLOCK
			if flat.length() > radius * 0.52:
				return {"mv": Vector2(flat.x, flat.z).normalized(), "action": false}
			return {"mv": Vector2.ZERO, "action": true}
		1: # PUNCH
			if flat.length() > radius * 0.45:
				return {"mv": Vector2(flat.x, flat.z).normalized(), "action": false}
			return {"mv": Vector2.ZERO, "action": false}
		_:
			# Waltz continuously inside the west hall; waypoint changes look like
			# the hired dancers' fake circuit rather than a statue in a trigger.
			if flat.length() > radius * 0.75:
				return {"mv": Vector2(flat.x, flat.z).normalized(), "action": false}
			var to_wp: Vector3 = _wp[i] - here
			to_wp.y = 0.0
			if _wp[i] == Vector3.ZERO or to_wp.length() < 0.3:
				_wp[i] = g.errand_point(kind, rng.randf_range(0.0, TAU),
					rng.randf_range(0.25, 0.72))
				to_wp = _wp[i] - here
			return {"mv": Vector2(to_wp.x, to_wp.z).normalized(), "action": false}

func _blend_move(i: int, here: Vector3, g) -> Vector2:
	var to_wp: Vector3 = _wp[i] - here
	to_wp.y = 0.0
	if _wp[i] == Vector3.ZERO or to_wp.length() < 0.24:
		_wp[i] = g.swirl_waypoint(here, rng)
		to_wp = _wp[i] - here
	return Vector2(to_wp.x, to_wp.z).normalized()

func _decide_coroner(i: int, g, delta: float) -> Dictionary:
	var own: int = g.body_of(i)
	var here: Vector3 = g.pos_of(own)
	_eval_t[i] -= delta
	if _eval_t[i] <= 0.0:
		_eval_t[i] = 0.35
		_read_floor(i, own, g)
	var target := int(_hunt_body[i])
	if target < 0 and not photo_mode and g.has_mark(i) \
			and g.waltz_t() >= float(_commit_at[i]):
		target = _choose_accusation(i, own, g)
		_hunt_body[i] = target
		if target >= 0:
			print("MBC_BOT_ACCUSE_PLAN round=%d seat=%d body=%d suspicion=%.2f t=%.1f" % [
				_round + 1, i, target, float(_sus[i][target]), g.waltz_t()])
	if target >= 0 and g.has_mark(i) and g.alive_body(target):
		var to: Vector3 = g.pos_of(target) - here
		to.y = 0.0
		if to.length() <= g.MARK_REACH * 0.82 \
				and g.nearest_markable(own, here) == target:
			return {"mv": Vector2.ZERO, "action": true}
		return {"mv": Vector2(to.x, to.z).normalized() * 1.08, "action": false}
	return {"mv": _blend_move(i, here, g), "action": false}

func _read_floor(i: int, own: int, g) -> void:
	for b in n_bodies:
		if b == own or not g.alive_body(b):
			continue
		var s := float(_sus[i][b]) * 0.975
		var visible: float = float(g.public_errand_evidence(b))
		if visible > 0.0:
			s += visible * rng.randf_range(0.72, 1.18)
		_sus[i][b] = s

func _choose_accusation(i: int, own: int, g) -> int:
	var ranked: Array = []
	for b in n_bodies:
		if b != own and g.alive_body(b):
			ranked.append(b)
	ranked.sort_custom(func(a, b): return float(_sus[i][a]) > float(_sus[i][b]))
	if ranked.is_empty():
		return -1
	var best := int(ranked[0])
	var threshold := float(_threshold[i])
	# At the deadline the knife demands use. A hesitant Coroner picks the best
	# public lead even below threshold; seeded memory noise sometimes chooses
	# the runner-up or third lead, producing honest wrong accusations.
	if float(_sus[i][best]) < threshold and g.waltz_t() < round_len - 15.0:
		return -1
	if bool(_alternate_pick[i]) and ranked.size() > 1:
		var top_n := mini(3, ranked.size())
		return int(ranked[rng.randi_range(1, top_n - 1)])
	return best

## Kept for the existing mirror/legacy ghost hook. THE CORONER settles a
## correct accusation immediately, so this path is not entered by new rounds.
func decide_ghost(_i: int, _g, _delta: float) -> Dictionary:
	return {"mv": Vector2.ZERO, "gust": false}
