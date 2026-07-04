class_name OrbPawn
extends Node3D
## A player stuck to tiny planets (ORBITAL DODGEBALL). Fully kinematic -
## no physics bodies. Local up = radial. Controls are SCREEN-RELATIVE via a
## parallel-transported control frame:
##   * frame_r is a tangent vector meaning "stick right".
##   * Each tick it is re-projected onto the new tangent plane (parallel
##     transport) so holding one direction carries you smoothly all the way
##     around the planet - no control flips, ever.
##   * On the camera-facing hemisphere the frame continuously relaxes toward
##     the true screen frame (camera right projected onto the tangent plane),
##     so on the visible side right IS screen-right. On the far side the
##     transported frame takes over (the projection is ill-conditioned
##     there anyway) - you wrap around like Pac-Man and re-emerge.
## Jumps are ballistic through the blended 3-planet gravity field, which is
## what makes planet-hopping at the near points possible.

const WALK_SPEED := 4.0
const JUMP_SPEED := 7.6
const AIM_TIME := 0.8          # hold A: power 0 -> 1 over this
const THROW_MIN := 5.5
const THROW_MAX := 13.0
const THROW_LOFT_DEG := 26.0
const BODY_R := 0.42
const CENTER_H := 0.55
const CATCH_WINDOW := 0.2
const CATCH_LOCKOUT := 0.5
const CATCH_RADIUS := 1.15
const CHAR_SCALE := 0.55

var world = null              # Orbital root (untyped: cyclic reference)
var index := 0
var color := Color.WHITE

var planet := 0
var srf_n := Vector3(0, 0, 1)     # unit surface normal = local up
var frame_r := Vector3(1, 0, 0)   # transported "stick right" tangent
var heading := Vector3(1, 0, 0)   # facing / travel direction (tangent)
var walking := false
var airborne := false
var air_vel := Vector3.ZERO
var alive := true
var held: OrbBall = null
var charge := -1.0                # <0 = not aiming
var catch_timer := 0.0
var catch_cd := 0.0
var invuln := 0.0

var _prev_a := false
var _prev_b := false
var _throw_lock := 0.0
var _air_t := 0.0
var _corpse_vel := Vector3.ZERO
var _corpse_axis := Vector3.UP
var _dead_t := 0.0
var _anim: AnimationPlayer = null
var _visual: Node3D = null
var _marker: MeshInstance3D = null
var _cur_anim := ""

const LOOPED_ANIMS := ["Idle", "Running_A", "Jump_Idle", "1H_Ranged_Aiming"]

func setup(char_scene: PackedScene, col: Color) -> void:
	color = col
	_visual = Node3D.new()
	add_child(_visual)
	var inst := char_scene.instantiate()
	inst.scale = Vector3.ONE * CHAR_SCALE
	_visual.add_child(inst)
	_anim = inst.find_child("AnimationPlayer", true, false)
	for a in LOOPED_ANIMS:
		if _anim != null and _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	# space helmet: identity-colored bubble over the head
	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.26
	hm.height = 0.52
	helmet.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.albedo_color = Color(col.r, col.g, col.b, 0.22)
	hmat.cull_mode = BaseMaterial3D.CULL_BACK
	helmet.material_override = hmat
	helmet.position = Vector3(0, 0.78, 0)
	_visual.add_child(helmet)
	# always-visible marker orb (no depth test - readable behind planets)
	_marker = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.12
	mm.height = 0.24
	_marker.mesh = mm
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.albedo_color = Color(col.r, col.g, col.b, 0.92)
	mmat.no_depth_test = true
	mmat.render_priority = 10
	_marker.material_override = mmat
	_marker.position = Vector3(0, 1.18, 0)
	_visual.add_child(_marker)
	_play("Idle")

func body_center() -> Vector3:
	return global_position + up_dir() * CENTER_H

func up_dir() -> Vector3:
	return srf_n

func place_on(planet_i: int, n: Vector3) -> void:
	planet = planet_i
	srf_n = n.normalized()
	airborne = false
	air_vel = Vector3.ZERO
	_air_t = 0.0
	var pl: Dictionary = world.planets[planet]
	global_position = Vector3(pl.center) + srf_n * float(pl.radius)
	frame_r = _project_cam_right(srf_n)
	heading = frame_r
	_orient(1000.0)

func _project_cam_right(n: Vector3) -> Vector3:
	var cr: Vector3 = world.cam_right()
	var t := cr - n * cr.dot(n)
	if t.length_squared() < 0.001:
		t = world.cam_up().cross(n)
	return t.normalized()

## --- per-tick simulation (driven by the world; no _physics_process) ------

func step(dt: float, now: float, mv: Vector2, a_down: bool, b_down: bool) -> void:
	var a_pressed := a_down and not _prev_a
	var a_released := (not a_down) and _prev_a
	var b_pressed := b_down and not _prev_b
	_prev_a = a_down
	_prev_b = b_down
	catch_cd = maxf(0.0, catch_cd - dt)
	catch_timer = maxf(0.0, catch_timer - dt)
	invuln = maxf(0.0, invuln - dt)
	_throw_lock = maxf(0.0, _throw_lock - dt)
	if not alive:
		_corpse_step(dt)
		return
	if airborne:
		_air_step(dt)
	else:
		_update_frame(dt)
		if held != null and charge >= 0.0 and a_down:
			charge = minf(1.0, charge + dt / AIM_TIME)
			_aim_turn(dt, mv)
		else:
			_walk(dt, mv)
		if held != null and a_pressed and _throw_lock <= 0.0:
			charge = 0.0
		elif held != null and charge >= 0.0 and a_released:
			_do_throw(now)
		elif held == null and a_pressed and catch_cd <= 0.0:
			catch_timer = CATCH_WINDOW
			catch_cd = CATCH_WINDOW + CATCH_LOCKOUT
		if b_pressed:
			_jump(mv)
	_orient(dt)
	_update_anim()

func _update_frame(dt: float) -> void:
	var n := srf_n
	frame_r = frame_r - n * frame_r.dot(n)
	if frame_r.length_squared() < 0.0001:
		frame_r = _project_cam_right(n)
	frame_r = frame_r.normalized()
	# relax toward true screen frame on the visible hemisphere
	var w := clampf(n.dot(world.cam_axis()), 0.0, 1.0)
	if w > 0.001:
		var cr: Vector3 = world.cam_right()
		var tr := cr - n * cr.dot(n)
		if tr.length() > 0.25:
			var ang := frame_r.signed_angle_to(tr.normalized(), n)
			frame_r = frame_r.rotated(n, ang * (1.0 - exp(-8.0 * w * dt))).normalized()

func _stick_dir(mv: Vector2) -> Vector3:
	# mv.y = forward(-1)/back(+1) per PlayerInput; screen up = -mv.y
	var n := srf_n
	var up_t := n.cross(frame_r)
	var dir := frame_r * mv.x - up_t * mv.y
	dir = dir - n * dir.dot(n)
	if dir.length_squared() < 0.0005:
		return Vector3.ZERO
	return dir.normalized()

func _walk(dt: float, mv: Vector2) -> void:
	walking = false
	if mv.length() < 0.12:
		return
	var dir := _stick_dir(mv)
	if dir == Vector3.ZERO:
		return
	heading = dir
	var pl: Dictionary = world.planets[planet]
	var r: float = pl.radius
	var arc := WALK_SPEED * minf(mv.length(), 1.0) * dt / r
	var axis := srf_n.cross(heading)
	if axis.length_squared() < 0.000001:
		return
	axis = axis.normalized()
	srf_n = srf_n.rotated(axis, arc).normalized()
	frame_r = frame_r.rotated(axis, arc)
	heading = heading.rotated(axis, arc)
	global_position = Vector3(pl.center) + srf_n * r
	walking = true

func _aim_turn(dt: float, mv: Vector2) -> void:
	walking = false
	if mv.length() < 0.15:
		return
	var dir := _stick_dir(mv)
	if dir == Vector3.ZERO:
		return
	var ang := heading.signed_angle_to(dir, srf_n)
	heading = heading.rotated(srf_n, clampf(ang, -7.0 * dt, 7.0 * dt)).normalized()

func throw_vector() -> Dictionary:
	var v := lerpf(THROW_MIN, THROW_MAX, maxf(charge, 0.0))
	var loft := deg_to_rad(THROW_LOFT_DEG)
	var dir := (heading * cos(loft) + srf_n * sin(loft)).normalized()
	return {"origin": body_center() + dir * 0.55, "vel": dir * v}

func _do_throw(now: float) -> void:
	if held == null:
		return
	var tv := throw_vector()
	var ball := held
	held = null
	ball.launch(tv.origin, tv.vel, index, now)
	charge = -1.0
	_throw_lock = 0.35
	_play_once("Throw")
	world.on_throw(self, ball)

func _jump(mv: Vector2) -> void:
	charge = -1.0
	var launch_dir := _stick_dir(mv)
	if launch_dir != Vector3.ZERO:
		heading = launch_dir
	var run := heading * WALK_SPEED * clampf(mv.length(), 0.0, 1.0)
	air_vel = run + srf_n * JUMP_SPEED
	airborne = true
	_air_t = 0.0
	world.on_jump(self)

func _air_step(dt: float) -> void:
	var g: Vector3 = world.gravity_at(global_position)
	air_vel += g * dt
	global_position += air_vel * dt
	_air_t += dt
	if g.length() > 0.4:
		srf_n = srf_n.slerp(-g.normalized(), 1.0 - exp(-4.0 * dt)).normalized()
	if _air_t > 4.0:
		# failsafe: drifting too long, pull hard toward the nearest planet
		var ni: int = world.nearest_planet(global_position)
		var c: Vector3 = world.planets[ni].center
		air_vel += (c - global_position).normalized() * 8.0 * dt
	for i in world.planets.size():
		var pl: Dictionary = world.planets[i]
		var d := global_position - Vector3(pl.center)
		var dist := d.length()
		if dist <= float(pl.radius) + 0.05:
			var n := d / maxf(dist, 0.001)
			if air_vel.dot(n) <= 0.1:
				_land(i, n)
				return

func _land(planet_i: int, n: Vector3) -> void:
	var prev := planet
	planet = planet_i
	srf_n = n.normalized()
	airborne = false
	_air_t = 0.0
	var pl: Dictionary = world.planets[planet]
	global_position = Vector3(pl.center) + srf_n * float(pl.radius)
	frame_r = frame_r - srf_n * frame_r.dot(srf_n)
	if frame_r.length_squared() < 0.0001:
		frame_r = _project_cam_right(srf_n)
	frame_r = frame_r.normalized()
	var tang := air_vel - srf_n * air_vel.dot(srf_n)
	if tang.length() > 0.8:
		heading = tang.normalized()
	else:
		heading = heading - srf_n * heading.dot(srf_n)
		heading = heading.normalized() if heading.length_squared() > 0.001 else frame_r
	air_vel = Vector3.ZERO
	_play_once("Jump_Land")
	world.on_land(self, prev)

## --- death / respawn ------------------------------------------------------

func die(kill_vel: Vector3, spin_axis: Vector3) -> void:
	alive = false
	airborne = false
	charge = -1.0
	catch_timer = 0.0
	_dead_t = 0.0
	_corpse_vel = kill_vel.normalized() * 8.0 + up_dir() * 2.5
	_corpse_axis = spin_axis.normalized() if spin_axis.length() > 0.01 else Vector3.UP
	_play_once("Death_A")

func _corpse_step(dt: float) -> void:
	_dead_t += dt
	if _dead_t > 2.0:
		visible = false
		return
	global_position += _corpse_vel * dt
	_corpse_vel += world.gravity_at(global_position) * 0.4 * dt
	rotate(_corpse_axis, 6.5 * dt)

func respawn(planet_i: int, n: Vector3) -> void:
	alive = true
	visible = true
	held = null
	place_on(planet_i, n)
	invuln = 1.0
	_cur_anim = ""
	_play("Idle")

## --- presentation ----------------------------------------------------------

func _orient(dt: float) -> void:
	if not alive:
		return
	var up := up_dir()
	var fwd := heading - up * heading.dot(up)
	if fwd.length_squared() < 0.001:
		return
	fwd = fwd.normalized()
	# KayKit GLBs face +Z, so aim -Z of the basis AWAY from the heading
	var target := Basis.looking_at(-fwd, up)
	var k := clampf(1.0 - exp(-14.0 * dt), 0.0, 1.0)
	global_transform.basis = global_transform.basis.orthonormalized().slerp(target, k)

func _update_anim() -> void:
	if not alive:
		return
	if _throw_lock > 0.0:
		return
	var want := "Idle"
	if airborne:
		want = "Jump_Idle"
	elif charge >= 0.0 and held != null:
		want = "1H_Ranged_Aiming"
	elif walking:
		want = "Running_A"
	_play(want)

func _play(anim_name: String) -> void:
	if _anim == null or _cur_anim == anim_name:
		return
	if _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.15)
		_cur_anim = anim_name

func _play_once(anim_name: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.1)
		_cur_anim = anim_name

func _process(_dt: float) -> void:
	if world == null or _visual == null:
		return
	# invulnerability shimmer
	if invuln > 0.0 and alive:
		_visual.visible = fmod(world.now * 9.0, 1.0) < 0.72
	elif alive:
		_visual.visible = true
	# marker bob
	if _marker != null:
		_marker.position.y = 1.18 + 0.06 * sin(world.now * 3.0 + float(index))
