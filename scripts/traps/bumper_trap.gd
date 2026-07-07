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

## WAVE 2 grief-trigger: kick anything already touching the sensor NOW (the
## normal _on_body path, cooldowns included) + a visible pulse so a whiff reads.
func grief_trigger() -> bool:
	for body in $Sense.get_overlapping_bodies():
		_on_body(body)
	var tw := create_tween()
	tw.tween_property($Body, "scale", Vector3(1.25, 0.85, 1.25), 0.06)
	tw.tween_property($Body, "scale", Vector3.ONE, 0.12)
	return true

func _on_body(body: Node3D) -> void:
	if is_ghost or not body is Ball or _cooldowns.has(body):
		return
	_cooldowns[body] = 0.25
	Sfx.play("bumper", -4.0)
	var away := body.global_position - global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	body.linear_velocity += away.normalized() * kick + Vector3(0, 1.2, 0)
	var tw := create_tween()
	tw.tween_property($Body, "scale", Vector3(1.25, 0.85, 1.25), 0.06)
	tw.tween_property($Body, "scale", Vector3.ONE, 0.12)
