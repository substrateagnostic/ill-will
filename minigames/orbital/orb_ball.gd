class_name OrbBall
extends Node3D
## One never-despawning dodgeball (ORBITAL DODGEBALL).
## Fully hand-integrated: sum of the three planets' inverse-square pulls,
## 3%/s "space drag" (ramping after DECAY_AGE so every orbit is guaranteed
## to die inside ~75s), speed cap, restitution bounces off planets, then a
## rest state where it can be picked up and thrown again - forever.
## Kill credit sticks to owner_idx = the LAST THROWER, no matter how old
## the orbit is when it finally clips someone.

enum S { REST, HELD, FLYING }

const RADIUS := 0.32
const RESTITUTION := 0.75
const TANGENT_KEEP := 0.96
const SPEED_CAP := 13.0
const DEADLY_SPEED := 4.0
const REST_SPEED := 1.7
const DRAG_BASE := 0.03       # 3% of speed lost per second (spec)
const DRAG_OLD_RAMP := 0.004  # extra drag/s per second past DECAY_AGE
const DECAY_AGE := 40.0
const GHOST_AGE := 10.0
const NEUTRAL := Color(0.88, 0.88, 0.92)

var world = null          # Orbital root (untyped: cyclic reference)
var state := S.REST
var vel := Vector3.ZERO
var owner_idx := -1       # last thrower, forever (kill credit)
var holder_idx := -1
var throw_time := -999.0
var rest_planet := 0
var trail: OrbTrail = null

var _mat: StandardMaterial3D

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = NEUTRAL
	_mat.roughness = 0.4
	_mat.emission_enabled = true
	_mat.emission = NEUTRAL * 0.2
	mi.material_override = _mat
	add_child(mi)

func display_color() -> Color:
	if holder_idx >= 0:
		return world.pawn_color(holder_idx)
	if owner_idx >= 0:
		return world.pawn_color(owner_idx)
	return NEUTRAL

func refresh_color() -> void:
	var c := display_color()
	_mat.albedo_color = c.lightened(0.2)
	if trail != null:
		trail.color = c

func age(now: float) -> float:
	return now - throw_time

func deadly() -> bool:
	return state == S.FLYING and vel.length() >= DEADLY_SPEED

func launch(from: Vector3, v: Vector3, thrower: int, now: float) -> void:
	global_position = from
	vel = v
	owner_idx = thrower
	holder_idx = -1
	throw_time = now
	state = S.FLYING
	refresh_color()

## Killed while holding: the ball pops loose (slow, harmless).
func drop_loose(v: Vector3, now: float) -> void:
	holder_idx = -1
	throw_time = now
	vel = v
	state = S.FLYING
	refresh_color()

func pick_up(p: int) -> void:
	holder_idx = p
	state = S.HELD
	vel = Vector3.ZERO
	if trail != null:
		trail.clear_points()
	refresh_color()

func step(dt: float, now: float) -> void:
	if state != S.FLYING:
		return
	var drag := DRAG_BASE
	var a := age(now)
	if a > DECAY_AGE:
		drag += (a - DECAY_AGE) * DRAG_OLD_RAMP
	vel += world.gravity_at(global_position) * dt
	vel *= maxf(0.0, 1.0 - drag * dt)
	if vel.length() > SPEED_CAP:
		vel = vel.normalized() * SPEED_CAP
	global_position += vel * dt
	for i in world.planets.size():
		var pl: Dictionary = world.planets[i]
		var c: Vector3 = pl.center
		var r: float = pl.radius
		var d := global_position - c
		var dist := d.length()
		if dist < r + RADIUS:
			var n := d / maxf(dist, 0.001)
			global_position = c + n * (r + RADIUS)
			var vn := vel.dot(n)
			if vn < 0.0:
				var vt := vel - n * vn
				vel = vt * TANGENT_KEEP - n * vn * RESTITUTION
				if -vn > 1.5:
					world.on_ball_bounce(self, -vn)
				if vel.length() < REST_SPEED:
					_come_to_rest(i, n)
			break
	if state == S.FLYING and trail != null:
		trail.add_point(global_position, now)

func _come_to_rest(planet_i: int, n: Vector3) -> void:
	state = S.REST
	rest_planet = planet_i
	vel = Vector3.ZERO
	var pl: Dictionary = world.planets[planet_i]
	global_position = pl.center + n * (float(pl.radius) + RADIUS)
	world.on_ball_rest(self)

## Visual heartbeat: deadly balls glow hard, ghost orbits (>10s) pulse.
func _process(_dt: float) -> void:
	if world == null:
		return
	var c := display_color()
	var glow := 0.25
	if state == S.FLYING:
		if deadly():
			glow = 1.1
		var a := age(world.now)
		if a > GHOST_AGE:
			glow += 0.4 + 0.35 * sin(world.now * 7.0)
	elif state == S.HELD:
		glow = 0.5
	_mat.emission = c * glow
