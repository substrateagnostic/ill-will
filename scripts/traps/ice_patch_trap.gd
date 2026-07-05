extends Trap
## Near-frictionless disc. While a ball is on the ice its linear damping drops to
## almost nothing, so it glides forever and overshoots. Restores on exit. Same
## runtime-damp technique the sand pit uses (inverted), so no frozen putt
## constants are touched.

const ICE_DAMP := 0.02
const NORMAL_DAMP := 0.5

func _init() -> void:
	trap_id = "ice_patch"
	display_name = "ICE PATCH"
	footprint_radius = 1.05

func _ready() -> void:
	$Zone.body_entered.connect(_on_enter)
	$Zone.body_exited.connect(_on_exit)

func _on_enter(body: Node3D) -> void:
	if body is Ball and not is_ghost:
		body.linear_damp = ICE_DAMP

func _on_exit(body: Node3D) -> void:
	if body is Ball:
		body.linear_damp = NORMAL_DAMP
