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
## PAR v4: the embodied hold-release swing (avatar_shot.gd) is the shipped
## default; the v3 drag-back putt stays available behind this toggle (spec OQ2,
## read from PartySetup pref "par_drag_putt" / --v3putt by main). The drag path
## below is byte-identical to v3 when re-enabled.
var drag_enabled := false

var _aiming := false
var _drag_point := Vector3.ZERO

const DOT_COUNT := 14
const DOT_SPACING := 0.55
const PREVIEW_CAP := 9.5

var _dots: Array = []

@onready var arrow: MeshInstance3D = $AimArrow
@onready var arrow_head: MeshInstance3D = $AimArrow/Head

func _ready() -> void:
	arrow.visible = false
	for i in DOT_COUNT:
		var d := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.075
		mesh.height = 0.15
		d.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.8)
		d.material_override = mat
		d.visible = false
		add_child(d)
		_dots.append(d)

func _hide_dots() -> void:
	for d in _dots:
		d.visible = false

func _update_dots(dir: Vector3, speed: float) -> void:
	var total := minf(speed * 2.0, PREVIEW_CAP)
	var space := get_viewport().get_camera_3d().get_world_3d().direct_space_state
	var from: Vector3 = ball.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * total, 1)
	q.exclude = [ball.get_rid()]
	var hit := space.intersect_ray(q)
	var first_leg := total
	var bounce_dir := Vector3.ZERO
	if not hit.is_empty():
		first_leg = from.distance_to(hit.position)
		bounce_dir = dir.bounce(hit.normal)
		bounce_dir.y = 0.0
		bounce_dir = bounce_dir.normalized()
	var t := clampf((speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
	var col := Color(0.3, 0.9, 0.35).lerp(Color(0.95, 0.25, 0.2), t)
	for i in DOT_COUNT:
		var dist := (i + 1) * DOT_SPACING
		var d: MeshInstance3D = _dots[i]
		if dist > total:
			d.visible = false
			continue
		var pos: Vector3
		if dist <= first_leg:
			pos = from + dir * dist
		elif bounce_dir != Vector3.ZERO and dist - first_leg <= 3.0 * DOT_SPACING:
			pos = hit.position + bounce_dir * (dist - first_leg)
		else:
			d.visible = false
			continue
		d.visible = true
		d.global_position = Vector3(pos.x, 0.12, pos.z)
		var fade := 1.0 - float(i) / DOT_COUNT
		d.material_override.albedo_color = Color(col.r, col.g, col.b, 0.4 + 0.5 * fade)

func _unhandled_input(event: InputEvent) -> void:
	if not drag_enabled or not enabled or ball == null or not ball.is_stopped():
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
	_hide_dots()
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
	_hide_dots()

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
		_hide_dots()
		return
	var t: float = clampf(len / MAX_DRAG, 0.0, 1.0)
	_render_arrow(pull.normalized(), t, _power_for_drag(len))

## PAR v4: the embodied aim renders the SAME arrow + first-bounce dots from a
## (dir, speed) pair — presentation only, identical visuals to the drag path.
func show_aim_preview(dir: Vector3, speed: float) -> void:
	if ball == null:
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var t: float = clampf((speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
	_render_arrow(dir.normalized(), t, speed)

func hide_preview() -> void:
	arrow.visible = false
	_hide_dots()

func _render_arrow(dir: Vector3, t: float, speed: float) -> void:
	arrow.visible = true
	var display_len := 0.5 + t * 2.2
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
	_update_dots(dir, speed)

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
