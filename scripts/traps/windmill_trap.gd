extends Trap

@export var spin_speed := 1.4

func _init() -> void:
	trap_id = "windmill"
	display_name = "WINDMILL"
	footprint_radius = 1.2

func _physics_process(delta: float) -> void:
	$Blades.rotate_y(spin_speed * delta)
