extends Node3D
## Drag-back-and-release putting. Click near the ball, drag away; the ball
## fires opposite the drag (slingshot). Power = drag distance.

signal stroke_taken

const MIN_SPEED := 1.2
const MAX_SPEED := 13.0
const MAX_DRAG := 3.2
const GRAB_RADIUS := 1.2

var ball: Ball
var enabled := true

var _aiming := false
var _drag_point := Vector3.ZERO

@onready var arrow: MeshInstance3D = $AimArrow
@onready var arrow_head: MeshInstance3D = $AimArrow/Head

func _ready() -> void:
	arrow.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or ball == null or not ball.is_stopped():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p := _mouse_on_plane(event.position)
			if p != Vector3.INF and p.distance_to(_ball_flat()) < GRAB_RADIUS:
				_aiming = true
				_drag_point = p
		elif _aiming:
			_fire()
	elif event is InputEventMouseMotion and _aiming:
		var p := _mouse_on_plane(event.position)
		if p != Vector3.INF:
			_drag_point = p
			_update_arrow()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and _aiming:
		_cancel()

func _fire() -> void:
	_aiming = false
	arrow.visible = false
	var pull := _ball_flat() - _drag_point
	pull.y = 0.0
	if pull.length() < 0.25:
		return
	var speed := _power_for_drag(pull.length())
	Sfx.play("putt", -8.0 + 9.0 * (speed / MAX_SPEED))
	ball.putt(pull.normalized(), speed)
	stroke_taken.emit()

func _cancel() -> void:
	_aiming = false
	arrow.visible = false

func _power_for_drag(drag: float) -> float:
	var t: float = clampf(drag / MAX_DRAG, 0.0, 1.0)
	return lerpf(MIN_SPEED, MAX_SPEED, t)

func power_ratio() -> float:
	if not _aiming:
		return 0.0
	var pull := _ball_flat() - _drag_point
	return clampf(pull.length() / MAX_DRAG, 0.0, 1.0)

func _update_arrow() -> void:
	var pull := _ball_flat() - _drag_point
	pull.y = 0.0
	var len := pull.length()
	if len < 0.25:
		arrow.visible = false
		return
	arrow.visible = true
	var t: float = clampf(len / MAX_DRAG, 0.0, 1.0)
	var display_len := 0.5 + t * 2.2
	var dir := pull.normalized()
	arrow.global_position = ball.global_position + Vector3(0, 0.02, 0)
	arrow.global_position += dir * (display_len * 0.5)
	arrow.look_at(arrow.global_position + dir, Vector3.UP)
	arrow.scale = Vector3(0.5 + t * 0.7, 1.0, display_len / 2.0)
	arrow_head.position = Vector3(0, 0, -1.15)
	var col := Color(0.3, 0.9, 0.35).lerp(Color(0.95, 0.25, 0.2), t)
	var mat: StandardMaterial3D = arrow.get_surface_override_material(0)
	if mat:
		mat.albedo_color = col
	var hmat: StandardMaterial3D = arrow_head.get_surface_override_material(0)
	if hmat:
		hmat.albedo_color = col

func _ball_flat() -> Vector3:
	return ball.global_position

func _mouse_on_plane(screen_pos: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, ball.global_position.y)
	var hit = plane.intersects_ray(origin, dir)
	return hit if hit != null else Vector3.INF

func debug_show_aim(drag: float, angle_deg: float) -> void:
	if ball == null:
		return
	var dir := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(angle_deg))
	_drag_point = ball.global_position - dir * drag
	_aiming = true
	_update_arrow()

func debug_putt(power: float, angle_deg: float) -> void:
	if ball == null:
		return
	var dir := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(angle_deg))
	Sfx.play("putt", -8.0 + 9.0 * (power / MAX_SPEED))
	ball.putt(dir, power)
	stroke_taken.emit()
