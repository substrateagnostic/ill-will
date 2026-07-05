extends Trap
## Directional speed strip. Any ball over the pad is shoved along the pad's
## forward (-Z) direction — the painted chevrons show which way. Scales with
## chaos speed. Great for banking balls somewhere they didn't intend to go.

@export var boost := 11.0

func _init() -> void:
	trap_id = "boost_pad"
	display_name = "BOOST PAD"
	footprint_radius = 0.95

func _physics_process(delta: float) -> void:
	var chev := $Chevrons
	if chev:
		# scroll the chevrons forward as a "conveyor" tell
		chev.position.z = wrapf(chev.position.z - delta * 1.5, -0.6, 0.0)
	if is_ghost:
		return
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	for body in $Zone.get_overlapping_bodies():
		if body is Ball and not body.is_sunk and not body.is_dead:
			body.apply_central_force(fwd.normalized() * boost * speed_scale)
