extends Node3D
## Diorama camera: frames the whole course from a 3/4 angle, with a gentle
## lean toward the ball so motion feels tracked without losing the overview.

@export var course_center := Vector3(0, 0, -6.5)
@export var lean_strength := 0.22

var ball: Ball
var _shake := 0.0
var cinematic := false
var _focus_override := Vector3.INF
var _focus_timer := 0.0

@onready var cam: Camera3D = $Camera3D

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func focus_on(pos: Vector3, duration: float) -> void:
	_focus_override = pos
	_focus_timer = duration

func start_flyover(duration: float) -> Tween:
	cinematic = true
	var start_pos := Vector3(2.2, 1.6, 2.5)
	var end_pos := Vector3(-2.2, 1.8, -15.5)
	cam.global_position = start_pos
	var tw := create_tween()
	tw.tween_method(_flyover_step.bind(start_pos, end_pos), 0.0, 1.0, duration)
	tw.tween_callback(func():
		cinematic = false
		cam.position = Vector3(0, 12.5, 4.5))
	return tw

func _flyover_step(t: float, start_pos: Vector3, end_pos: Vector3) -> void:
	var eased := ease(t, -1.8)
	cam.global_position = start_pos.lerp(end_pos, eased)
	var look_target := Vector3(0, 0.3, lerpf(-2.0, -13.0, eased))
	cam.look_at(look_target, Vector3.UP)

func _process(delta: float) -> void:
	if cinematic:
		return
	var focus := course_center
	if _focus_timer > 0.0:
		_focus_timer -= delta
		focus = _focus_override
	elif ball != null and not ball.is_sunk:
		focus = course_center.lerp(ball.global_position, lean_strength)
	var target := Transform3D(Basis.looking_at(focus - cam.global_position, Vector3.UP), cam.global_position)
	cam.global_transform = cam.global_transform.interpolate_with(target, 1.0 - exp(-6.0 * delta))
	if _shake > 0.002:
		cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-5.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
