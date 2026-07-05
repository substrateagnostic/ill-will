extends Trap
## Springy pad. A ball touching it is flung up and forward (along the pad's -Z),
## turning a ground roll into an arcing hop. Short per-ball cooldown so it fires
## once per bounce instead of every physics frame while the ball sits on it.

@export var launch_up := 5.5
@export var launch_fwd := 3.0

var _cooldowns := {}

func _init() -> void:
	trap_id = "trampoline"
	display_name = "TRAMPOLINE"
	footprint_radius = 0.85

func _ready() -> void:
	$Sense.body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	for k in _cooldowns.keys():
		_cooldowns[k] -= delta
		if _cooldowns[k] <= 0.0:
			_cooldowns.erase(k)

func _on_body(body: Node3D) -> void:
	if is_ghost or not body is Ball or body.is_sunk or body.is_dead or _cooldowns.has(body):
		return
	_cooldowns[body] = 0.4
	Sfx.play("bounce", -2.0)
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var v: Vector3 = body.linear_velocity
	body.linear_velocity = Vector3(v.x, 0, v.z) + fwd.normalized() * launch_fwd + Vector3(0, launch_up, 0)
	var tw := create_tween()
	tw.tween_property($Pad, "scale", Vector3(1.0, 0.5, 1.0), 0.05)
	tw.tween_property($Pad, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
