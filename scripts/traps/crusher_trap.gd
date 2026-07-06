extends Trap

const UP_Y := 1.5
const DOWN_Y := 0.28

var _t := 0.0

func _init() -> void:
	trap_id = "crusher"
	display_name = "THE CRUSHER"
	footprint_radius = 0.85

func _ready() -> void:
	# VISUAL-ONLY swap: Meshy press head stretched to exactly fill the
	# 0.85 x 0.55 x 0.85 hammer collider. Pad, pillar, author AccentBand,
	# collision and kill logic untouched. Primitive fallback if missing.
	var glb := "res://assets/models/meshy/crusher_head.glb"
	if not ResourceLoader.exists(glb):
		return
	var wrap := MeshyProp.instance(glb, 0.55)
	var model: Node3D = wrap.get_node("Model")
	var aabb := MeshyProp.merged_aabb_of_scaled(model)
	if aabb.size.x > 0.001 and aabb.size.z > 0.001:
		wrap.scale = Vector3(0.85 / aabb.size.x, 1.0, 0.85 / aabb.size.z)
	wrap.position.y = -0.275   # collider box is centered on the Hammer origin
	$Hammer/HammerMesh.visible = false
	$Hammer.add_child(wrap)

func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta * speed_scale, 2.6)
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
