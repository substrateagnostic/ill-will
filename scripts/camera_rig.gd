extends Node3D
## Diorama camera: frames the whole course from a 3/4 angle, with a gentle
## lean toward the ball so motion feels tracked without losing the overview.

@export var course_center := Vector3(0, 0, -6.5)
@export var lean_strength := 0.22

var ball: Ball

@onready var cam: Camera3D = $Camera3D

func _process(delta: float) -> void:
	var focus := course_center
	if ball != null and not ball.is_sunk:
		focus = course_center.lerp(ball.global_position, lean_strength)
	var target := Transform3D(Basis.looking_at(focus - cam.global_position, Vector3.UP), cam.global_position)
	cam.global_transform = cam.global_transform.interpolate_with(target, 1.0 - exp(-6.0 * delta))
