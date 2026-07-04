extends Node3D

signal ball_entered_cup(body: Node3D)

const MAGNET_RADIUS := 0.36
const MAGNET_MAX_SPEED := 5.0
const MAGNET_FORCE := 26.0

var balls: Array = []

@onready var cup_area: Area3D = $CupArea

func _ready() -> void:
	cup_area.body_entered.connect(func(body): ball_entered_cup.emit(body))

func _physics_process(_delta: float) -> void:
	var cup := cup_area.global_position
	for b in balls:
		if b == null or b.is_sunk:
			continue
		var flat := Vector2(b.global_position.x - cup.x, b.global_position.z - cup.z)
		if flat.length() < MAGNET_RADIUS and b.linear_velocity.length() < MAGNET_MAX_SPEED and b.global_position.y > -0.2:
			var target := Vector3(cup.x, b.global_position.y - 0.5, cup.z)
			b.apply_central_force((target - b.global_position).normalized() * MAGNET_FORCE)
