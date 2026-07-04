extends Node3D
## Ghost-preview trap placement. Mouse moves the ghost on the green,
## wheel / R rotates in 15-degree steps, click places when valid.

signal trap_placed(trap: Trap)

const COURSE_X := 2.85
const COURSE_Z_MIN := -14.85
const COURSE_Z_MAX := 1.85
const TEE_ZONE := {"pos": Vector3(0, 0, 0), "radius": 1.5}
const CUP_ZONE := {"pos": Vector3(0, 0, -13), "radius": 1.3}

var active := false
var ghost: Trap = null
var trap_container: Node3D = null

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
	ghost.global_position = Vector3(0, 0, -6.5)
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
			ghost.global_position = Vector3(p.x, 0, p.z)
			_refresh()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rotate_step(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rotate_step(-1)
		elif event.button_index == MOUSE_BUTTON_LEFT and _valid:
			_confirm()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		_rotate_step(1)

func _rotate_step(dir: int) -> void:
	_rot = wrapf(_rot + dir * 15.0, 0.0, 360.0)
	if ghost:
		ghost.rotation_degrees.y = _rot
		_refresh()

func _confirm() -> void:
	ghost.solidify()
	var placed := ghost
	ghost = null
	active = false
	disc.visible = false
	trap_placed.emit(placed)

func _refresh() -> void:
	_valid = _check_valid()
	disc.global_position = ghost.global_position + Vector3(0, 0.015, 0)
	var r: float = ghost.footprint_radius
	disc.scale = Vector3(r, 1, r)
	disc_mat.albedo_color = Color(0.3, 0.95, 0.4, 0.35) if _valid else Color(0.95, 0.25, 0.2, 0.4)

func _check_valid() -> bool:
	if ghost == null:
		return false
	var p := ghost.global_position
	var r: float = ghost.footprint_radius
	if absf(p.x) > COURSE_X - r * 0.6 or p.z < COURSE_Z_MIN + r * 0.6 or p.z > COURSE_Z_MAX - r * 0.6:
		return false
	for zone in [TEE_ZONE, CUP_ZONE]:
		var zp: Vector3 = zone.pos
		if Vector2(p.x - zp.x, p.z - zp.z).length() < zone.radius + r * 0.5:
			return false
	for t in trap_container.get_children():
		if t == ghost or not t is Trap:
			continue
		var d := Vector2(p.x - t.global_position.x, p.z - t.global_position.z).length()
		if d < (r + t.footprint_radius) * 0.75:
			return false
	return true

func _mouse_on_ground(screen_pos: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	return hit if hit != null else Vector3.INF

func debug_place(pos: Vector3, rot_deg: float) -> bool:
	if not active or ghost == null:
		return false
	_rot = rot_deg
	ghost.rotation_degrees.y = rot_deg
	for attempt in 10:
		var offset := Vector3((attempt % 5) * 0.45 * (1 if attempt % 2 == 0 else -1), 0, floorf(attempt / 5.0) * 0.6)
		ghost.global_position = pos + offset
		_refresh()
		if _valid:
			_confirm()
			return true
	return false
