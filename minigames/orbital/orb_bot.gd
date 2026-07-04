class_name OrbBot
extends RefCounted
## Deterministic self-play brain (ORBITAL DODGEBALL, --orbbots).
## Emits a VIRTUAL THUMBSTICK in screen space - exactly what a human would
## push while looking at the fixed camera - plus A/B holds. It never touches
## pawn internals to move; everything goes through the same screen-relative
## control path a player uses. All randomness comes from a per-bot RNG
## seeded from config.rng_seed.

var index := 0
var world = null
var rng := RandomNumberGenerator.new()

var move := Vector2.ZERO
var a := false
var b := false

var _target_enemy := -1
var _retarget_t := 0.0
var _charge_goal := 1.0
var _wander_phase := 0.0

func setup(w, i: int, seed_v: int) -> void:
	world = w
	index = i
	rng.seed = seed_v
	_wander_phase = rng.randf_range(0.0, TAU)

func think(dt: float, now: float) -> void:
	b = false
	var pawn: OrbPawn = world.pawns[index]
	if not pawn.alive:
		move = Vector2.ZERO
		a = false
		return
	if pawn.airborne:
		a = false
		return
	_retarget_t -= dt
	if pawn.held != null:
		_think_throw(pawn, now)
	else:
		_think_fetch(pawn, now)
		_think_catch(pawn, now)
	if rng.randf() < dt * 0.05:
		b = true  # occasional playful hop (spec: bots occasionally jump)

## Convert a desired world-space direction into the stick a human would push.
func _stick_toward(pawn: OrbPawn, world_dir: Vector3) -> Vector2:
	var n := pawn.srf_n
	var t := world_dir - n * world_dir.dot(n)
	if t.length() < 0.03:
		return Vector2.ZERO
	t = t.normalized()
	var up_t := n.cross(pawn.frame_r)
	return Vector2(t.dot(pawn.frame_r), -t.dot(up_t))

func _think_throw(pawn: OrbPawn, _now: float) -> void:
	if _target_enemy < 0 or _retarget_t <= 0.0 or not world.pawns[_target_enemy].alive:
		_target_enemy = _nearest_enemy(pawn)
		_retarget_t = 0.7
	if _target_enemy < 0:
		a = false
		return
	var enemy: OrbPawn = world.pawns[_target_enemy]
	var to: Vector3 = enemy.body_center() - pawn.body_center()
	var dist := to.length()
	# small lead on a moving target
	if enemy.walking:
		to += enemy.heading * minf(dist * 0.18, 1.4)
	move = _stick_toward(pawn, to.normalized())
	if not a:
		_charge_goal = clampf(dist / 11.0 + rng.randf_range(-0.05, 0.18), 0.35, 1.0)
		a = true
		return
	var tang := to - pawn.srf_n * to.dot(pawn.srf_n)
	var facing := 0.0
	if tang.length() > 0.05:
		facing = pawn.heading.dot(tang.normalized())
	if pawn.charge >= _charge_goal and (facing > 0.9 or pawn.charge >= 1.0):
		a = false  # release -> throw

func _think_fetch(pawn: OrbPawn, now: float) -> void:
	a = false
	var best: OrbBall = null
	var best_d := 1e9
	for ball in world.balls:
		var bb: OrbBall = ball
		if bb.state != OrbBall.S.REST:
			continue
		var d: float = bb.global_position.distance_to(pawn.global_position)
		# prefer balls on my own planet
		if bb.rest_planet != pawn.planet:
			d += 6.0
		if d < best_d:
			best_d = d
			best = bb
	if best == null:
		# nothing to grab: drift-patrol so the sky stays lively
		var wander := Vector2(cos(now * 0.35 + _wander_phase), sin(now * 0.35 + _wander_phase))
		move = wander * 0.7
		return
	if best.rest_planet == pawn.planet:
		move = _stick_toward(pawn, (best.global_position - pawn.global_position).normalized())
	else:
		# walk to the near point facing the target planet, then hop the gap
		var my_c: Vector3 = world.planets[pawn.planet].center
		var other_c: Vector3 = world.planets[best.rest_planet].center
		var gap_dir := (other_c - my_c).normalized()
		move = _stick_toward(pawn, (other_c - pawn.global_position).normalized())
		if pawn.srf_n.dot(gap_dir) > 0.93:
			b = true

func _think_catch(pawn: OrbPawn, _now: float) -> void:
	if pawn.held != null or pawn.catch_cd > 0.0:
		return
	for ball in world.balls:
		var bb: OrbBall = ball
		if not bb.deadly():
			continue
		if bb.owner_idx == index and bb.age(world.now) < 0.8:
			continue
		var to_me: Vector3 = pawn.body_center() - bb.global_position
		var d := to_me.length()
		if d > 2.4:
			continue
		var closing: float = bb.vel.dot(to_me.normalized())
		if closing > 3.0 and d / maxf(closing, 0.1) < 0.16:
			a = true
			return

func _nearest_enemy(pawn: OrbPawn) -> int:
	var best := -1
	var best_d := 1e9
	for p in world.pawns:
		var op: OrbPawn = p
		if op.index == index or not op.alive:
			continue
		var d: float = op.global_position.distance_to(pawn.global_position)
		if d < best_d:
			best_d = d
			best = op.index
	return best
