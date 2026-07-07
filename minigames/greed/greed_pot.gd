class_name GreedPot
extends Node3D
## The gilded pot — a golden bowl heaped with coins under a huge floating value
## number. Purely visual: the controller owns pot value/state and tells this
## node where to sit (on the pedestal, on the carrier, or loose on the floor)
## and how big the number is. Also fires the +5 burst "coin geyser".

const POT_GLB := "res://assets/models/meshy/gilded_pot.glb"
const POT_HEIGHT := 1.25       # ornate cauldron height on the pedestal

var _model: Node3D             # the gilded_pot GLB (replaces bowl + coin pile)
var _model_base_scale := Vector3.ONE
var _label: Label3D
var _glow: OmniLight3D
var _geyser: CPUParticles3D
var _spin := 0.0
var _restless_t := 0.0         # CLOSING BELL: "the pot grows restless" tremble
var _label_base_px := 0.010


func build() -> void:
	# Custom Meshy gilded cauldron (dark pot, gold trim, coins heaped on top with
	# spill around the base) replacing the procedural bowl + coin sphere. Purely
	# visual — the controller still owns the pot value/state and its position.
	# Normalized so the base is seated at this node's origin (on the pedestal).
	_model = MeshyProp.instance(POT_GLB, POT_HEIGHT)
	_model.name = "PotModel"
	add_child(_model)
	_model_base_scale = _model.scale   # swell (update_value) multiplies this

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
	_label.font_size = 260
	_label.pixel_size = 0.010
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.outline_size = 52
	_label.outline_modulate = Color(0.15, 0.08, 0.0)
	_label.modulate = Color(1.0, 0.92, 0.4)
	_label.position.y = 2.7
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
	_geyser.position.y = 0.95        # erupt from the coin heap on the cauldron mouth
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
	# the whole hoard swells subtly with value (base stays planted on the pedestal)
	var swell := clampf(1.0 + float(value) * 0.004, 1.0, 1.35)
	_model.scale = _model_base_scale * swell
	# the fatter the pot, the hotter it glows
	_glow.light_energy = clampf(1.2 + float(value) * 0.03, 1.2, 3.4)


func set_carried(carried: bool) -> void:
	# on the carrier the number floats higher and the pedestal light dims
	_label.position.y = 3.0 if carried else 2.5
	_glow.light_energy = _glow.light_energy if not carried else 2.6


func geyser() -> void:
	_geyser.restart()
	_geyser.emitting = true


## CLOSING BELL (doc 09 §6.1): the value number PULSES at the T-15 last-banks
## call — a triple swell of the Label3D so the whole room's eyes go to the pot.
func bell_pulse() -> void:
	_label.pixel_size = _label_base_px
	var tw := create_tween()
	for i in 3:
		tw.tween_property(_label, "pixel_size", _label_base_px * 1.55, 0.16) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_label, "pixel_size", _label_base_px, 0.22) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _label.pixel_size = _label_base_px)


## CLOSING BELL (doc 09 §6.3): "THE POT GROWS RESTLESS" — the hoard trembles for
## `t` seconds. Visual only (the model shivers; the collider-less pot is a prop).
func restless(t := 1.4) -> void:
	_restless_t = maxf(_restless_t, t)


func tick(delta: float) -> void:
	_spin += delta
	# slow turntable spin so the hoard reads as the object of desire
	_model.rotation.y = _spin * 0.5
	_label.position.y += sin(_spin * 3.0) * delta * 0.15
	if _restless_t > 0.0:
		_restless_t = maxf(0.0, _restless_t - delta)
		var amp := 0.045 * minf(_restless_t / 0.4, 1.0)   # eases out at the tail
		_model.rotation.z = sin(_spin * 43.0) * amp
		_model.rotation.x = cos(_spin * 37.0) * amp * 0.7
		if _restless_t <= 0.0:
			_model.rotation.z = 0.0
			_model.rotation.x = 0.0
