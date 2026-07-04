class_name DWProp
extends RigidBody3D
## A chunky physics prop in the attic. Living players shove it; the DEAD
## possess it. When possessed it glows the ghost's color, hovers 5cm, wobbles,
## and trails wisps. Mass tiers decide feel: a lamp is a dart, the wardrobe is
## a slow freight train. Props credit their possessor for any kill they land.

# --- tunables (the ghost's lethality knobs live here) ---
const DRIVE_FORCE := 38.0     # central force applied per physics frame while possessed
const HOVER_LIFT := 0.05      # 5cm hover
const HOVER_SPRING := 42.0
const HOVER_DAMP := 6.0
const KILL_SPEED := 3.0       # min prop speed to count as a lethal slam
const KNOCK_SCALE := 1.0      # momentum -> knockback impulse on the victim
const KNOCK_MAX := 24.0
const HIT_COOLDOWN := 0.28

const TIER_DISPLAY := {"lamp": "THE LAMP", "crate": "THE CRATE", "chair": "THE CHAIR", "wardrobe": "THE WARDROBE"}

var owner_game: Node = null           # back-ref to the controller (for game_time)
var tier := "crate"
var base_color := Color(0.55, 0.4, 0.28)
var home_spawn := Vector3.ZERO
var possessed_by := -1                 # ghost player index, -1 = free
var possess_color := Color.WHITE
var dent := 0.0                        # accumulated darkening across rounds
var alive_in_void := true

var _mat: StandardMaterial3D
var _visual: MeshInstance3D
var _wisps: CPUParticles3D
var _wobble_t := 0.0
var _hit_cd := 0.0
var _emission_energy := 0.0

func setup(p_tier: String, p_base: Color, p_owner: Node) -> void:
	tier = p_tier
	base_color = p_base
	owner_game = p_owner
	mass = _tier_mass()
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	linear_damp = 0.9
	angular_damp = 1.6
	can_sleep = false
	var pm := PhysicsMaterial.new()
	pm.friction = 0.55
	pm.bounce = 0.15
	physics_material_override = pm
	collision_layer = 4          # props
	collision_mask = 1 | 2 | 4   # floor, fighters, props
	add_to_group("dw_props")

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _tier_shape()
	add_child(shape)

	_visual = MeshInstance3D.new()
	_visual.name = "Visual"
	_visual.mesh = _tier_mesh()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = base_color
	_mat.roughness = 0.7
	_mat.emission_enabled = true
	_mat.emission = Color.BLACK
	_visual.material_override = _mat
	add_child(_visual)

	_wisps = CPUParticles3D.new()
	_wisps.name = "Wisps"
	_wisps.emitting = false
	_wisps.amount = 20
	_wisps.lifetime = 0.6
	_wisps.local_coords = false
	_wisps.direction = Vector3.UP
	_wisps.spread = 40.0
	_wisps.gravity = Vector3(0, 1.5, 0)
	_wisps.initial_velocity_min = 0.4
	_wisps.initial_velocity_max = 1.2
	_wisps.scale_amount_min = 0.4
	_wisps.scale_amount_max = 0.9
	var wm := SphereMesh.new()
	wm.radius = 0.09
	wm.height = 0.18
	_wisps.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = Color(1, 1, 1, 0.55)
	_wisps.material_override = wmat
	add_child(_wisps)
	body_entered.connect(_on_body_entered)

func _tier_mass() -> float:
	match tier:
		"lamp": return 0.6
		"crate": return 2.4
		"chair": return 1.6
		"wardrobe": return 8.0
	return 2.0

func _tier_shape() -> Shape3D:
	match tier:
		"lamp":
			var c := CylinderShape3D.new()
			c.radius = 0.16
			c.height = 0.95
			return c
		"wardrobe":
			var b := BoxShape3D.new()
			b.size = Vector3(0.9, 1.7, 0.6)
			return b
		"chair":
			var b2 := BoxShape3D.new()
			b2.size = Vector3(0.5, 0.9, 0.5)
			return b2
	var b3 := BoxShape3D.new()
	b3.size = Vector3(0.62, 0.62, 0.62)
	return b3

func _tier_mesh() -> Mesh:
	match tier:
		"lamp":
			var c := CylinderMesh.new()
			c.top_radius = 0.10
			c.bottom_radius = 0.18
			c.height = 0.95
			return c
		"wardrobe":
			var b := BoxMesh.new()
			b.size = Vector3(0.9, 1.7, 0.6)
			return b
		"chair":
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.5, 0.9, 0.5)
			return b2
	var b3 := BoxMesh.new()
	b3.size = Vector3(0.62, 0.62, 0.62)
	return b3

func rest_height() -> float:
	# half-height so the prop sits on the floor (y=0 top)
	match tier:
		"lamp": return 0.475
		"wardrobe": return 0.85
		"chair": return 0.45
	return 0.31

func display_name() -> String:
	return TIER_DISPLAY.get(tier, "THE THING")

func can_be_possessed() -> bool:
	if possessed_by >= 0:
		return false
	if global_position.y < -1.0:
		return false
	if owner_game != null and owner_game.has_method("prop_locked_by_spawn"):
		return not owner_game.prop_locked_by_spawn(self)
	return true

func possess(ghost_index: int, color: Color) -> void:
	possessed_by = ghost_index
	possess_color = color
	gravity_scale = 0.0
	sleeping = false
	_mat.emission = color
	_wobble_t = 0.0
	var wmat: StandardMaterial3D = _wisps.material_override
	wmat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	_wisps.emitting = true

func release() -> void:
	possessed_by = -1
	gravity_scale = 1.0
	_mat.emission = Color.BLACK
	_emission_energy = 0.0
	_mat.emission_energy_multiplier = 1.0
	_wisps.emitting = false
	_visual.rotation = Vector3.ZERO

func apply_drive(dir: Vector3) -> void:
	if possessed_by < 0:
		return
	dir.y = 0.0
	if dir.length() > 0.05:
		apply_central_force(dir.normalized() * DRIVE_FORCE)

func _physics_process(delta: float) -> void:
	if _hit_cd > 0.0:
		_hit_cd -= delta
	if possessed_by < 0:
		return
	# hover 5cm off the floor with a spring so it floats, not sinks
	var target_y := rest_height() + HOVER_LIFT
	var dy := target_y - global_position.y
	apply_central_force(Vector3.UP * (dy * HOVER_SPRING - linear_velocity.y * HOVER_DAMP) * mass)
	# spooky wobble + pulsing glow on the visual only (never the collider)
	_wobble_t += delta * 7.0
	_visual.rotation.z = sin(_wobble_t) * 0.16
	_visual.rotation.x = cos(_wobble_t * 0.8) * 0.12
	_emission_energy = 1.4 + sin(_wobble_t * 1.5) * 0.5
	_mat.emission_energy_multiplier = _emission_energy

func _on_body_entered(body: Node) -> void:
	if possessed_by < 0 or _hit_cd > 0.0:
		return
	if not (body is DWFighter):
		return
	var f := body as DWFighter
	if not f.alive:
		return
	var speed := linear_velocity.length()
	if speed < KILL_SPEED:
		return
	_hit_cd = HIT_COOLDOWN
	var momentum := speed * mass
	var impulse: float = clampf(momentum * KNOCK_SCALE, 4.0, KNOCK_MAX)
	var dir: Vector3 = (f.global_position - global_position)
	dir.y = 0.0
	f.call_deferred("hit", dir, impulse, "ghost", possessed_by, display_name(), possess_color)
	if owner_game != null and owner_game.has_method("note_ghost_hit"):
		owner_game.call_deferred("note_ghost_hit")

func reset_for_round(darken: float) -> void:
	release()
	dent = darken
	freeze = false
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = home_spawn
	rotation = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_mat.albedo_color = base_color.lerp(Color(0.12, 0.12, 0.14), clampf(dent, 0.0, 0.6))
