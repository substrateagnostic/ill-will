extends Trap

@export var push := 6.5

func _init() -> void:
	trap_id = "fan"
	display_name = "BIG FAN"
	footprint_radius = 1.0

func _ready() -> void:
	# VISUAL-ONLY swap: Meshy pedestal fan standing where the pole is, cage
	# facing -Z (the wind direction). The bare pole/disc primitives hide; the
	# translucent wind zone, collision and push logic are untouched.
	var glb := "res://assets/models/meshy/pedestal_fan.glb"
	if not ResourceLoader.exists(glb):
		return
	var wrap := MeshyProp.instance(glb, 1.25, 180.0)
	wrap.position = Vector3(0, 0, 1.55)
	$PoleBody/PoleMesh.visible = false
	$Disc.visible = false
	add_child(wrap)

## WAVE 2 grief-trigger: one gust — a single capped impulse (dv = 0.8/0.8 mass
## = 1.0 m/s) on balls already inside the wind zone. Perturbs the sim's INPUTS
## through the trap, exactly like the continuous push; no ball constant touched.
func grief_trigger() -> bool:
	var wind := -global_transform.basis.z
	wind.y = 0.0
	for body in $Zone.get_overlapping_bodies():
		if body is Ball and not body.is_sunk and not body.is_dead:
			body.apply_central_impulse(wind.normalized() * 0.8)
	return true

func _physics_process(_delta: float) -> void:
	if is_ghost:
		$Disc.rotate_object_local(Vector3.UP, 0.3)
		return
	$Disc.rotate_object_local(Vector3.UP, 0.3)
	var wind := -global_transform.basis.z
	wind.y = 0.0
	for body in $Zone.get_overlapping_bodies():
		if body is Ball and not body.is_sunk:
			body.apply_central_force(wind.normalized() * push * speed_scale)
