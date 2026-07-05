extends Trap
## A flat four-armed cross lying at ground level, spinning about Y. Rolling balls
## that clip an arm get batted off at an angle — a redirector, not a killer. The
## arms are an AnimatableBody3D (sync_to_physics) so they actually swat the ball.
## BUZZSAW SPINNER cursed variant spins much faster.

@export var spin := 2.2

func _init() -> void:
	trap_id = "spinner"
	display_name = "SPINNER"
	footprint_radius = 1.15

func _physics_process(delta: float) -> void:
	# Arm meshes are children of the AnimatableBody, so they follow the rotation.
	$Arms.rotate_y(spin * delta * speed_scale)
