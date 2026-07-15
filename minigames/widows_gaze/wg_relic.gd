class_name WGRelic
extends Node3D
## A relic on the wake — the object of desire. Three tiers, built from primitives
## (a locket, an urn, a framed portrait) with a faint funereal glow so they read
## as loot from the 45-degree diorama camera. Purely visual: the controller owns
## which tier, its point value, who holds it, and where it sits.
##
## Tier index: 0 = locket (1pt, quick grab), 1 = urn (2pt), 2 = portrait
## (3pt, bulky — slow to grab, heavy to haul). Highest tiers spawn nearest the
## Widow, so the fattest points sit deepest in the danger zone.

const TIER_NAMES := ["locket", "urn", "portrait"]
const TIER_VALUE := [1, 2, 3]
const TIER_GRAB := [0.2, 0.5, 0.85]       # channel seconds to lift it (deep dwell = exposure)
const TIER_CARRY := [0.86, 0.78, 0.66]    # movement multiplier while carrying it
const TIER_COLOR := [
	Color(0.86, 0.72, 0.30),              # locket — tarnished gold
	Color(0.72, 0.74, 0.80),              # urn — pewter
	Color(0.55, 0.40, 0.72),              # portrait — dusk violet
]

var tier := 0
var _glow: OmniLight3D
var _spin := 0.0


func build(t: int) -> void:
	tier = clampi(t, 0, 2)
	var col: Color = TIER_COLOR[tier]
	match tier:
		0: _build_locket(col)
		1: _build_urn(col)
		_: _build_portrait(col)
	_glow = OmniLight3D.new()
	_glow.light_color = col.lerp(Color(1, 1, 1), 0.3)
	_glow.light_energy = 0.8 + 0.4 * float(tier)
	_glow.omni_range = 2.6 + 0.6 * float(tier)
	_glow.position.y = 0.6
	add_child(_glow)


func value() -> int:
	return TIER_VALUE[tier]


func grab_time() -> float:
	return TIER_GRAB[tier]


func carry_mult() -> float:
	return TIER_CARRY[tier]


func tier_name() -> String:
	return TIER_NAMES[tier]


func tint() -> Color:
	return TIER_COLOR[tier]


func set_held(held: bool) -> void:
	_glow.light_energy = (1.4 + 0.5 * float(tier)) if held else (0.8 + 0.4 * float(tier))


func _mat(col: Color, metal := 0.6, rough := 0.4, emit := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = emit
	return m


func _build_locket(col: Color) -> void:
	# small oval pendant on a chain loop
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.34
	body.mesh = sm
	body.scale = Vector3(1.0, 1.0, 0.35)
	body.material_override = _mat(col, 0.85, 0.25, 0.7)
	body.position.y = 0.45
	add_child(body)
	var loop := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.04
	tm.outer_radius = 0.09
	loop.mesh = tm
	loop.material_override = _mat(col, 0.9, 0.2, 0.6)
	loop.position.y = 0.66
	loop.rotation.x = PI * 0.5
	add_child(loop)


func _build_urn(col: Color) -> void:
	# a lidded funerary urn: belly + neck + lid knob
	var belly := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.20
	cm.bottom_radius = 0.15
	cm.height = 0.44
	belly.mesh = cm
	belly.material_override = _mat(col, 0.55, 0.4, 0.35)
	belly.position.y = 0.32
	add_child(belly)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.15
	nm.bottom_radius = 0.20
	nm.height = 0.14
	neck.mesh = nm
	neck.material_override = _mat(col, 0.55, 0.4, 0.35)
	neck.position.y = 0.60
	add_child(neck)
	var lid := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.08
	lm.height = 0.16
	lid.mesh = lm
	lid.material_override = _mat(col.lerp(Color(1, 1, 1), 0.2), 0.8, 0.25, 0.6)
	lid.position.y = 0.72
	add_child(lid)


func _build_portrait(col: Color) -> void:
	# a heavy framed oval portrait — the bulky prize
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.52, 0.68, 0.06)
	frame.mesh = fb
	frame.material_override = _mat(col, 0.7, 0.3, 0.55)
	frame.position.y = 0.55
	add_child(frame)
	var canvas := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.38, 0.52, 0.08)
	canvas.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.14, 0.12, 0.16)
	cm.roughness = 0.9
	cm.emission_enabled = true
	cm.emission = Color(0.30, 0.22, 0.40)
	cm.emission_energy_multiplier = 0.35
	canvas.material_override = cm
	canvas.position.y = 0.55
	canvas.position.z = 0.02
	add_child(canvas)


## Turntable spin so the relic reads as loot. The controller owns X/Y/Z placement
## (floor rest height or floating in a carrier's hands); this only spins it.
func tick(delta: float) -> void:
	_spin += delta
	rotation.y = _spin * 0.9
