extends Trap

func _init() -> void:
	trap_id = "spikes"
	display_name = "SPIKE STRIP"
	footprint_radius = 0.95

func _ready() -> void:
	$Zone.body_entered.connect(_on_body)

func _on_body(body: Node3D) -> void:
	if not is_ghost and body is Ball:
		kill_ball(body)
