extends Trap

const KILL_RADIUS := 0.4
const PULL := 9.0

func _init() -> void:
	trap_id = "black_hole"
	display_name = "BLACK HOLE"
	footprint_radius = 0.9

func _physics_process(delta: float) -> void:
	$Ring.rotate_y(2.0 * delta)
	if is_ghost:
		return
	for body in $Pull.get_overlapping_bodies():
		if not body is Ball or body.is_sunk:
			continue
		var to_core: Vector3 = global_position - body.global_position
		to_core.y = 0.0
		var d: float = to_core.length()
		if d < KILL_RADIUS:
			kill_ball(body)
		elif d > 0.01:
			body.apply_central_force(to_core.normalized() * (PULL / maxf(d * 0.6, 0.5)))
