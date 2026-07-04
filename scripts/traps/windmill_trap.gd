extends Trap

@export var spin_speed := 1.4

var _blades_visual: Node3D

func _init() -> void:
	trap_id = "windmill"
	display_name = "WINDMILL"
	footprint_radius = 1.25

func _ready() -> void:
	_blades_visual = find_child("blades", true, false)
	if _blades_visual:
		_blades_visual.scale = Vector3(1.6, 1.6, 1.0)

func _physics_process(delta: float) -> void:
	var step := spin_speed * delta * speed_scale
	$BladesBody.rotate_object_local(Vector3(0, 0, 1), step)
	if _blades_visual:
		_blades_visual.rotate_object_local(Vector3(0, 0, 1), step)
