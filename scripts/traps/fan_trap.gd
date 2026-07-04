extends Trap

const PUSH := 6.5

func _init() -> void:
	trap_id = "fan"
	display_name = "BIG FAN"
	footprint_radius = 1.0

func _physics_process(_delta: float) -> void:
	if is_ghost:
		$Disc.rotate_object_local(Vector3.UP, 0.3)
		return
	$Disc.rotate_object_local(Vector3.UP, 0.3)
	var wind := -global_transform.basis.z
	wind.y = 0.0
	for body in $Zone.get_overlapping_bodies():
		if body is Ball and not body.is_sunk:
			body.apply_central_force(wind.normalized() * PUSH)
