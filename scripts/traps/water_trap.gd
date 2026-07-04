extends Trap

func _init() -> void:
	trap_id = "water"
	display_name = "WATER HAZARD"
	footprint_radius = 1.1

func _ready() -> void:
	$Zone.body_entered.connect(_on_body)

func _on_body(body: Node3D) -> void:
	if not is_ghost and body is Ball:
		kill_ball(body)
