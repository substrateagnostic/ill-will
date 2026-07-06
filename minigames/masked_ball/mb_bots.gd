class_name MBBots
extends RefCounted
## Seeded self-play brains for MASKED BALL. Deterministic per rng_seed: every
## roll comes from ONE RNG consumed in tick order at a pinned dt (tally mode).
##
## BLEND: a bot knows which body is its own (fair — a human learns theirs in
## seconds through the feather-glint) and drives it exactly like the crowd:
## same swirl waypoints, same speed, pauses kept SHORTER than the NPC maximum
## so the stillness tell never fires on a bot. Three seeded curtsy windows
## send it to the throne for its pips; a seeded bluff timer makes it curtsy
## in the open now and then, because only the guilty never bow.
##
## HUNT: bots read only PUBLIC evidence, through seeded noise:
##   1. pip coincidence — when the Executor announces an (unnamed) scored
##      curtsy, every dancer mid-curtsy near the throne shares the suspicion,
##      split by how many were bowing (deniability by parallelism).
##   2. the waste-flash — a flashed body is a KNOWN human; certainty decays
##      as the crowd churns (humans lose track of a body; so do bots).
##   3. stillness — no NPC ever freezes longer than ~2.6s. A body statuing
##      past 4s is breathing too deliberately.
## A bot spends its ONE mark when suspicion clears its personal threshold
## (lower in the closing bars — desperation is seeded too), steering to the
## target at a 7% hunt stride. Wastes happen: an unlucky NPC that bowed at
## the wrong moments can clear a desperate threshold. That is the game.

var rng := RandomNumberGenerator.new()
var n_seats := 0
var n_bodies := 0
var waltz_len := 150.0

# per-seat personality
var _threshold: Array = []      # suspicion needed to spend the mark
var _desperation: Array = []    # late-game threshold (from t > 78% waltz)
var _pause_lo: Array = []
var _pause_hi: Array = []

# per-seat state
var _wp: Array = []             # waypoint Vector3
var _pause_t: Array = []
var _mode: Array = []           # 0 = blend, 1 = hunt, 2 = objective run
var _hunt_body: Array = []
var _curtsy_at: Array = []      # 3 seeded window times each
var _next_window: Array = []
var _obj_point: Array = []      # seeded spot inside the throne zone
var _bluff_t: Array = []
var _eval_t: Array = []
var _sus: Array = []            # per seat: Array[float] per body
# ghost state
var _gwp: Array = []
var _gust_t: Array = []

func setup(seed_value: int, seats: int, bodies: int, p_waltz_len: float) -> void:
	rng.seed = seed_value
	n_seats = seats
	n_bodies = bodies
	waltz_len = p_waltz_len
	for arr in [_threshold, _desperation, _pause_lo, _pause_hi, _wp, _pause_t,
			_mode, _hunt_body, _curtsy_at, _next_window, _obj_point, _bluff_t,
			_eval_t, _sus, _gwp, _gust_t]:
		(arr as Array).clear()
	for i in seats:
		_threshold.append(rng.randf_range(3.9, 5.7))
		_desperation.append(rng.randf_range(1.8, 2.7))
		_pause_lo.append(rng.randf_range(0.4, 0.8))
		_pause_hi.append(rng.randf_range(1.6, 2.3))
		_wp.append(Vector3.ZERO)
		_pause_t.append(rng.randf_range(0.3, 1.2))
		_mode.append(0)
		_hunt_body.append(-1)
		var wins: Array = []
		for _k in 3:
			wins.append(rng.randf_range(0.12, 0.78) * waltz_len)
		wins.sort()
		_curtsy_at.append(wins)
		_next_window.append(0)
		_obj_point.append(Vector3.ZERO)
		_bluff_t.append(rng.randf_range(14.0, 34.0))
		_eval_t.append(rng.randf_range(0.0, 0.5))   # desync eval beats
		var s: Array = []
		for _b in bodies:
			s.append(0.0)
		_sus.append(s)
		_gwp.append(Vector3.ZERO)
		_gust_t.append(rng.randf_range(3.0, 7.0))

# ---------------------------------------------------------------- events
## Executor announced an unnamed scored curtsy. `curtsiers` = bodies bowing
## near the throne at that instant; `scorer_seat` knows the event was theirs.
func on_pip_event(curtsiers: Array, scorer_seat: int, g) -> void:
	var share := 2.3 / float(maxi(1, curtsiers.size()))
	for i in n_seats:
		var own: int = g.body_of(i)
		for b in curtsiers:
			var bi := int(b)
			# every seat consumes the same rolls -> stream stays aligned
			var noise := rng.randf_range(-0.75, 0.75)
			if i == scorer_seat or bi == own:
				continue
			_sus[i][bi] = float(_sus[i][bi]) + share + noise
	print("MBBOTS_PIP_EVIDENCE set=%s share=%.2f" % [str(curtsiers), share])

## A waste-flash marked `flashed_body` as certainly human.
func on_flash(flashed_body: int, g) -> void:
	for i in n_seats:
		var gasp := rng.randf_range(1.0, 2.5)
		if g.body_of(i) == flashed_body:
			continue
		_sus[i][flashed_body] = maxf(float(_sus[i][flashed_body]), 9.0)
		_eval_t[i] = maxf(float(_eval_t[i]), gasp)

## An unmask-lunge is public — the tearing body becomes a LEAD, not a
## conviction (the lunge is over in a blink and the crowd churns), and the
## witnesses need a beat to collect themselves before acting on anything.
func on_kill_seen(killer_body: int, g) -> void:
	for i in n_seats:
		var lead := 3.3 + rng.randf_range(-0.7, 0.7)
		var shock := rng.randf_range(2.0, 5.0)
		if g.body_of(i) == killer_body:
			continue
		_sus[i][killer_body] = maxf(float(_sus[i][killer_body]), lead)
		_eval_t[i] = maxf(float(_eval_t[i]), shock)

## A body was revealed (unmasked human) — never a target again.
func on_reveal(revealed_body: int) -> void:
	for i in n_seats:
		_sus[i][revealed_body] = -999.0

# ---------------------------------------------------------------- alive tick
## Returns {mv: Vector2, curtsy: bool, mark: bool}. g = masked_ball.gd root.
func decide_alive(i: int, g, delta: float) -> Dictionary:
	var mv := Vector2.ZERO
	var curtsy := false
	var mark := false
	var own: int = g.body_of(i)
	var here: Vector3 = g.pos_of(own)
	_pause_t[i] = float(_pause_t[i]) - delta

	# ---- periodic evidence read
	_eval_t[i] = float(_eval_t[i]) - delta
	if _eval_t[i] <= 0.0:
		_eval_t[i] = 0.5
		_evaluate(i, g)

	# ---- objective windows (pips first, hunting second, drifting last)
	if int(_mode[i]) != 1:
		var k := int(_next_window[i])
		var wins: Array = _curtsy_at[i]
		if k < wins.size() and g.waltz_t() >= float(wins[k]) and g.pips_of(i) < g.PIP_MAX:
			if int(_mode[i]) != 2:
				_mode[i] = 2
				_obj_point[i] = g.zone_point(rng.randf_range(0.0, TAU), rng.randf_range(0.2, 0.85))

	match int(_mode[i]):
		2:  # objective run: walk to the throne, bow, leave
			var to: Vector3 = _obj_point[i] - here
			to.y = 0.0
			if to.length() > 0.35:
				mv = Vector2(to.x, to.z).normalized()
			elif g.can_score_curtsy(i):
				curtsy = true
				_next_window[i] = int(_next_window[i]) + 1
				_mode[i] = 0
				_pause_t[i] = rng.randf_range(_pause_lo[i], _pause_hi[i])
			elif _pause_t[i] <= 0.0:
				# scoring gap not open yet — mill about the zone, never statue
				_obj_point[i] = g.zone_point(rng.randf_range(0.0, TAU), rng.randf_range(0.2, 0.85))
				_pause_t[i] = rng.randf_range(0.6, 1.4)
		1:  # hunt
			var hb := int(_hunt_body[i])
			if hb < 0 or not g.alive_body(hb) or not g.has_mark(i):
				_mode[i] = 0
				_hunt_body[i] = -1
			else:
				var tp: Vector3 = g.pos_of(hb) - here
				tp.y = 0.0
				if tp.length() <= g.MARK_REACH * 0.82 and g.nearest_markable(own, here) == hb:
					# fire only when the grab would land on the TARGET —
					# never through a bystander
					mark = true
					_mode[i] = 0
					_hunt_body[i] = -1
				else:
					mv = Vector2(tp.x, tp.z).normalized() * 1.07   # hunt stride
		_:  # blend: swirl like the crowd
			var to_wp: Vector3 = _wp[i] - here
			to_wp.y = 0.0
			if _wp[i] == Vector3.ZERO or to_wp.length() < 0.22:
				if _pause_t[i] <= 0.0:
					_wp[i] = g.swirl_waypoint(here, rng)
					_pause_t[i] = rng.randf_range(_pause_lo[i], _pause_hi[i])
			elif _pause_t[i] <= 0.0:
				mv = Vector2(to_wp.x, to_wp.z).normalized()
			# bluff curtsy: only the guilty never bow
			_bluff_t[i] = float(_bluff_t[i]) - delta
			if _bluff_t[i] <= 0.0:
				_bluff_t[i] = rng.randf_range(14.0, 34.0)
				curtsy = true

	return {"mv": mv, "curtsy": curtsy, "mark": mark}

func _evaluate(i: int, g) -> void:
	var own: int = g.body_of(i)
	# decay + stillness read, fixed body order
	for b in n_bodies:
		var s := float(_sus[i][b])
		if s <= -100.0:
			continue
		s *= exp(-0.03 * 0.5)   # evidence fades as the crowd churns
		if b != own and g.alive_body(b) and g.still_of(b) > 4.0:
			s += 1.2 + rng.randf_range(0.0, 0.5)
		_sus[i][b] = s
	if not g.has_mark(i) or int(_mode[i]) == 1:
		return
	# spend the mark?
	var best := -1
	var best_s := 0.0
	var second := -1
	var second_s := 0.0
	for b in n_bodies:
		if b == own or not g.alive_body(b):
			continue
		var s2 := float(_sus[i][b])
		if s2 > best_s:
			second = best
			second_s = best_s
			best_s = s2
			best = b
		elif s2 > second_s:
			second_s = s2
			second = b
	var th := float(_threshold[i])
	if g.waltz_t() > g.waltz_len() * 0.8:
		th = float(_desperation[i])
	if best >= 0 and best_s >= th:
		# couch players misremember which body did what — sometimes the
		# runner-up suspect eats the mark instead (this is where bot wastes
		# come from; the flash then feeds the next act of the drama)
		var pick := best
		if second >= 0 and second_s > 0.2 and rng.randf() < 0.18:
			pick = second
		_mode[i] = 1
		_hunt_body[i] = pick
		print("MBBOTS_HUNT seat=%d body=%d sus=%.2f th=%.2f t=%.1f%s" % [i, pick,
			best_s, th, g.waltz_t(), " (runner-up)" if pick != best else ""])

# ---------------------------------------------------------------- ghost tick
## Returns {mv: Vector2, gust: bool}. Ghosts drift and heckle; pure mischief.
func decide_ghost(i: int, g, delta: float) -> Dictionary:
	var mv := Vector2.ZERO
	var gust := false
	var here: Vector3 = g.ghost_pos_of(i)
	var to: Vector3 = _gwp[i] - here
	to.y = 0.0
	if _gwp[i] == Vector3.ZERO or to.length() < 0.4:
		_gwp[i] = g.swirl_waypoint(here, rng)
	else:
		mv = Vector2(to.x, to.z).normalized()
	_gust_t[i] = float(_gust_t[i]) - delta
	if _gust_t[i] <= 0.0:
		_gust_t[i] = rng.randf_range(4.0, 9.0)
		gust = true
	return {"mv": mv, "gust": gust}
