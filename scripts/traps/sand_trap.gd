extends Trap

const SAND_DAMP := 3.2
const NORMAL_DAMP := 0.5

func _init() -> void:
	trap_id = "sand"
	display_name = "SAND PIT"
	footprint_radius = 1.05

func _ready() -> void:
	$Zone.body_entered.connect(_on_enter)
	$Zone.body_exited.connect(_on_exit)

func _on_enter(body: Node3D) -> void:
	if body is Ball and not is_ghost:
		body.linear_damp = SAND_DAMP

func _on_exit(body: Node3D) -> void:
	if body is Ball:
		body.linear_damp = NORMAL_DAMP
