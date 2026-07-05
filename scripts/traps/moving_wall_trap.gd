extends Trap
## A wall that slides side to side along its local X on a visible track. Uses an
## AnimatableBody3D driven by position (sync_to_physics), so it shoves the ball
## like a real moving obstacle. The ghost/solidify rule in trap_base disables
## sync while previewing (ancestor transform moves with the mouse), so the wall
## only pushes once it is live. EXPRESS WALL cursed variant runs faster/wider.

@export var travel := 1.1
@export var rate := 1.6

var _t := 0.0

func _init() -> void:
	trap_id = "moving_wall"
	display_name = "MOVING WALL"
	footprint_radius = 1.35

func _physics_process(delta: float) -> void:
	_t += delta * rate * speed_scale
	var x := sin(_t) * travel
	$Slider.position.x = x
