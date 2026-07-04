extends Trap

const UP_Y := 1.5
const DOWN_Y := 0.28

var _t := 0.0

func _init() -> void:
	trap_id = "crusher"
	display_name = "THE CRUSHER"
	footprint_radius = 0.85

func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, 2.6)
	var y := UP_Y
	if _t < 1.5:
		y = UP_Y
	elif _t < 1.62:
		y = lerpf(UP_Y, DOWN_Y, (_t - 1.5) / 0.12)
	elif _t < 2.15:
		y = DOWN_Y
	else:
		y = lerpf(DOWN_Y, UP_Y, (_t - 2.15) / 0.45)
	$Hammer.position.y = y
	if not is_ghost and y < 0.75:
		for body in $Zone.get_overlapping_bodies():
			if body is Ball:
				kill_ball(body)
