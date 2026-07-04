class_name GreedPot
extends Node3D
## The gilded pot — a golden bowl heaped with coins under a huge floating value
## number. Purely visual: the controller owns pot value/state and tells this
## node where to sit (on the pedestal, on the carrier, or loose on the floor)
## and how big the number is. Also fires the +5 burst "coin geyser".

var _bowl: MeshInstance3D
var _pile: MeshInstance3D
var _pile_mat: StandardMaterial3D
var _label: Label3D
var _glow: OmniLight3D
var _geyser: CPUParticles3D
var _spin := 0.0


func build() -> void:
	# golden bowl
	_bowl = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.62
	bm.bottom_radius = 0.42
	bm.height = 0.5
	_bowl.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.95, 0.75, 0.18)
	bmat.metallic = 0.9
	bmat.roughness = 0.25
	bmat.emission_enabled = true
	bmat.emission = Color(0.8, 0.55, 0.05)
	bmat.emission_energy_multiplier = 0.35
	_bowl.material_override = bmat
	_bowl.position.y = 0.35
	add_child(_bowl)

	# heaped coins (grows subtly with value)
	_pile = MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.5
	pm.height = 0.5
	_pile.mesh = pm
	_pile_mat = StandardMaterial3D.new()
	_pile_mat.albedo_color = Color(1.0, 0.85, 0.22)
	_pile_mat.metallic = 0.85
	_pile_mat.roughness = 0.22
	_pile_mat.emission_enabled = true
	_pile_mat.emission = Color(1.0, 0.72, 0.1)
	_pile_mat.emission_energy_multiplier = 0.6
	_pile.material_override = _pile_mat
	_pile.position.y = 0.62
	add_child(_pile)

	# glow so the pot reads as the object of desire
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.82, 0.3)
	_glow.light_energy = 1.6
	_glow.omni_range = 6.0
	_glow.position.y = 1.0
	add_child(_glow)

	# huge floating value number
	_label = Label3D.new()
	_label.text = "5"
	_label.font_size = 200
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.outline_size = 40
	_label.outline_modulate = Color(0.15, 0.08, 0.0)
	_label.modulate = Color(1.0, 0.92, 0.4)
	_label.position.y = 2.5
	_label.fixed_size = false
	var lf: FontFile = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	if lf:
		_label.font = lf
	add_child(_label)

	# burst geyser (fired on the +5 fanfare)
	_geyser = CPUParticles3D.new()
	_geyser.emitting = false
	_geyser.one_shot = true
	_geyser.amount = 40
	_geyser.lifetime = 1.1
	_geyser.explosiveness = 0.85
	_geyser.direction = Vector3(0, 1, 0)
	_geyser.spread = 28.0
	_geyser.gravity = Vector3(0, -11.0, 0)
	_geyser.initial_velocity_min = 5.0
	_geyser.initial_velocity_max = 8.5
	_geyser.position.y = 0.6
	var gmesh := CylinderMesh.new()
	gmesh.top_radius = 0.11
	gmesh.bottom_radius = 0.11
	gmesh.height = 0.035
	_geyser.mesh = gmesh
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.86, 0.2)
	gmat.metallic = 0.8
	gmat.roughness = 0.25
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.7, 0.1)
	gmat.emission_energy_multiplier = 0.8
	_geyser.mesh.surface_set_material(0, gmat)
	add_child(_geyser)


func update_value(value: int) -> void:
	_label.text = str(value)
	# pile swells with the hoard (clamped so it never dwarfs the bowl)
	var s := clampf(0.6 + float(value) * 0.012, 0.6, 1.7)
	_pile.scale = Vector3(s, minf(s, 1.25), s)
	# the fatter the pot, the hotter it glows
	_glow.light_energy = clampf(1.2 + float(value) * 0.03, 1.2, 3.4)


func set_carried(carried: bool) -> void:
	# on the carrier the number floats higher and the pedestal light dims
	_label.position.y = 3.0 if carried else 2.5
	_glow.light_energy = _glow.light_energy if not carried else 2.6


func geyser() -> void:
	_geyser.restart()
	_geyser.emitting = true


func tick(delta: float) -> void:
	_spin += delta
	_bowl.rotation.y = _spin * 0.8
	_pile.rotation.y = -_spin * 0.6
	_label.position.y += sin(_spin * 3.0) * delta * 0.15
