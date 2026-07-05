extends Trap
## A non-lethal attractor pole. Balls inside the (visible) pull radius are drawn
## toward the post — it won't kill them, it just drags their line and can pin a
## slow ball against the base. The MEGA MAGNET cursed variant cranks both.

@export var pull := 7.0
@export var radius := 2.0

func _init() -> void:
	trap_id = "magnet_post"
	display_name = "MAGNET POST"
	footprint_radius = 0.55

func _ready() -> void:
	# Size the pull area + the ground ring to the configured radius. Duplicate the
	# shape so a MEGA MAGNET doesn't resize every other post sharing the resource.
	var shape: CylinderShape3D = $Pull/PullShape.shape.duplicate()
	shape.radius = radius
	$Pull/PullShape.shape = shape
	$PullRing.scale = Vector3(radius, 1.0, radius)

func _physics_process(_delta: float) -> void:
	if is_ghost:
		return
	for body in $Pull.get_overlapping_bodies():
		if not body is Ball or body.is_sunk or body.is_dead:
			continue
		var to_core: Vector3 = global_position - body.global_position
		to_core.y = 0.0
		var d: float = to_core.length()
		if d > 0.12:
			body.apply_central_force(to_core.normalized() * pull * speed_scale)
