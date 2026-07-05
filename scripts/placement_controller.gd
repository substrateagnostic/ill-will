extends Node3D
## Ghost-preview trap placement. Mouse moves the ghost on the green,
## wheel / R rotates in 15-degree steps, click places when valid. All course
## geometry (playable region, no-build zones) is queried from the active
## Course, so this controller works for any course shape.

signal trap_placed(trap: Trap)

var active := false
var ghost: Trap = null
var trap_container: Node3D = null
var course: Course = null

var _rot := 0.0
var _valid := false

@onready var disc: MeshInstance3D = $ValidityDisc
@onready var disc_mat: StandardMaterial3D = disc.get_surface_override_material(0)

func begin(scene: PackedScene, author_idx: int, author_color: Color, params := {}) -> void:
	cancel()
	ghost = scene.instantiate()
	for k in params:
		ghost.set(k, params[k])
	trap_container.add_child(ghost)
	ghost.set_author(author_idx, author_color)
	ghost.ghostify()
	var c := course.course_center
	ghost.global_position = Vector3(c.x, 0, c.z)
	_rot = 0.0
	active = true
	disc.visible = true
	_refresh()

func cancel() -> void:
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	active = false
	disc.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not active or ghost == null:
		return
	if event is InputEventMouseMotion:
		var p := _mouse_on_ground(event.position)
		if p != Vector3.INF:
			ghost.move_placement(p)
			_refresh()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rotate_step(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rotate_step(-1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _valid:
				# Multi-endpoint traps (portal) keep the ghost live between clicks.
				if ghost.advance_placement():
					_confirm()
				else:
					Sfx.play("place")
					_refresh()
			else:
				Sfx.play("invalid")
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		_rotate_step(1)

func _rotate_step(dir: int) -> void:
	_rot = wrapf(_rot + dir * 15.0, 0.0, 360.0)
	if ghost:
		ghost.rotation_degrees.y = _rot
		_refresh()

func _confirm() -> void:
	Sfx.play("place")
	ghost.solidify()
	var placed := ghost
	ghost = null
	active = false
	disc.visible = false
	trap_placed.emit(placed)

func _refresh() -> void:
	_valid = _check_valid()
	var ap: Vector3 = ghost.active_placement_pos()
	disc.global_position = Vector3(ap.x, 0.015, ap.z)
	var r: float = ghost.active_footprint_radius()
	disc.scale = Vector3(r, 1, r)
	disc_mat.albedo_color = Color(0.3, 0.95, 0.4, 0.35) if _valid else Color(0.95, 0.25, 0.2, 0.4)

func _check_valid() -> bool:
	if ghost == null or course == null:
		return false
	var p: Vector3 = ghost.active_placement_pos()
	var r: float = ghost.active_footprint_radius()
	# Footprint must stay on the green: check center + 4 cardinal edge points so
	# a trap can't poke over a wall or off a leg of the dogleg.
	if not course.is_point_on_green(p):
		return false
	var m := r * 0.6
	for off in [Vector3(m, 0, 0), Vector3(-m, 0, 0), Vector3(0, 0, m), Vector3(0, 0, -m)]:
		if not course.is_point_on_green(p + off):
			return false
	for zone in course.no_build_zones():
		var zp: Vector3 = zone["pos"]
		var zr: float = zone["radius"]
		if Vector2(p.x - zp.x, p.z - zp.z).length() < zr + r * 0.5:
			return false
	# Endpoints already locked this placement (portal's first ring).
	for fp in ghost.locked_footprint_points():
		var lp: Vector3 = fp["pos"]
		var lr: float = fp["radius"]
		if Vector2(p.x - lp.x, p.z - lp.z).length() < (r + lr) * 0.75:
			return false
	for t in trap_container.get_children():
		if t == ghost or not t is Trap:
			continue
		for tf in t.footprint_points():
			var tp: Vector3 = tf["pos"]
			var tr: float = tf["radius"]
			var d := Vector2(p.x - tp.x, p.z - tp.z).length()
			if d < (r + tr) * 0.75:
				return false
	return true

## True if there is at least one legal spot for the current ghost anywhere on
## the course (used to auto-skip a placement when the course is saturated).
func has_valid_placement() -> bool:
	if ghost == null or course == null:
		return false
	var saved: Vector3 = ghost.active_placement_pos()
	var ok := false
	var steps := 9
	for r in course.play_rects:
		for ix in steps:
			for iz in steps:
				var x: float = r.position.x + r.size.x * (ix + 0.5) / steps
				var z: float = r.position.y + r.size.y * (iz + 0.5) / steps
				ghost.move_placement(Vector3(x, 0, z))
				if _check_valid():
					ok = true
					break
			if ok:
				break
		if ok:
			break
	ghost.move_placement(saved)
	_refresh()
	return ok

## Deterministic auto-placement for headless self-play: scan random points in
## the course rects at a fixed rotation, confirm the first legal one. Handles
## multi-endpoint traps (portal) by scanning + locking each endpoint in turn.
func debug_place_scan(rot_deg: float, rng: RandomNumberGenerator) -> bool:
	if not active or ghost == null or course == null:
		return false
	_rot = rot_deg
	ghost.rotation_degrees.y = rot_deg
	for _click in ghost.endpoint_count:
		var found := false
		for attempt in 120:
			var r: Rect2 = course.play_rects[rng.randi_range(0, course.play_rects.size() - 1)]
			var x := rng.randf_range(r.position.x, r.position.x + r.size.x)
			var z := rng.randf_range(r.position.y, r.position.y + r.size.y)
			ghost.move_placement(Vector3(x, 0, z))
			_refresh()
			if _valid:
				found = true
				break
		if not found:
			return false
		if ghost.advance_placement():
			_confirm()
			return true
		Sfx.play("place")
	return false

func _mouse_on_ground(screen_pos: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	return hit if hit != null else Vector3.INF
