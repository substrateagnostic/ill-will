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

func _ready() -> void:
	# VISUAL-ONLY swap: Meshy sweeper cross scaled so its span fills the same
	# 2.0-unit footprint the two crossed arm colliders imply, flattened if the
	# model is tall. Colliders, spin and author AccentHub untouched.
	var glb := "res://assets/models/meshy/spinner_arms.glb"
	if not ResourceLoader.exists(glb):
		return
	var wrap := MeshyProp.instance(glb, 1.0)
	var model: Node3D = wrap.get_node("Model")
	var aabb := MeshyProp.merged_aabb_of_scaled(model)
	var span := maxf(aabb.size.x, aabb.size.z)
	if span > 0.001:
		var s := 2.0 / span
		wrap.scale = Vector3(s, s, s)
		var h := aabb.size.y * s
		if h > 0.42:   # keep the cross low like the box arms were
			wrap.scale.y = s * (0.42 / h)
	wrap.position.y = 0.04   # arm colliders: 0.16 thick, centered at y=0.12
	$Arms/MeshA.visible = false
	$Arms/MeshB.visible = false
	$Arms.add_child(wrap)

func _physics_process(delta: float) -> void:
	# Arm meshes are children of the AnimatableBody, so they follow the rotation.
	$Arms.rotate_y(spin * delta * speed_scale)
