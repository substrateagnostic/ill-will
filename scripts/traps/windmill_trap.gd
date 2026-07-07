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

## WAVE 2 grief-trigger: lurch a quarter-turn NOW (phase snap, timing only).
func grief_trigger() -> bool:
	$BladesBody.rotate_object_local(Vector3(0, 0, 1), PI / 2.0)
	if _blades_visual:
		_blades_visual.rotate_object_local(Vector3(0, 0, 1), PI / 2.0)
	return true

func _physics_process(delta: float) -> void:
	var step := spin_speed * delta * speed_scale
	$BladesBody.rotate_object_local(Vector3(0, 0, 1), step)
	if _blades_visual:
		_blades_visual.rotate_object_local(Vector3(0, 0, 1), step)
