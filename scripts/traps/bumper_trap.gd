extends Trap

@export var kick := 4.5
var _cooldowns := {}

func _init() -> void:
	trap_id = "bumper"
	display_name = "BUMPER"
	footprint_radius = 0.55

func _ready() -> void:
	$Sense.body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	for k in _cooldowns.keys():
		_cooldowns[k] -= delta
		if _cooldowns[k] <= 0.0:
			_cooldowns.erase(k)

func _on_body(body: Node3D) -> void:
	if is_ghost or not body is Ball or _cooldowns.has(body):
		return
	_cooldowns[body] = 0.25
	var away := body.global_position - global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	body.linear_velocity += away.normalized() * kick + Vector3(0, 1.2, 0)
	var tw := create_tween()
	tw.tween_property($Body, "scale", Vector3(1.25, 0.85, 1.25), 0.06)
	tw.tween_property($Body, "scale", Vector3.ONE, 0.12)
