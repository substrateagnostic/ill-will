class_name SeancePlanchette
extends Node3D
## The shared planchette. Pure kinematic motion (no physics body) so bot
## matches are deterministic per seed at a pinned dt. All four players'
## sticks sum into one force — like a real Ouija board, observers see ONE
## motion and cannot decompose whose hand pulled where. Surges (B) render
## as an ANONYMOUS ripple: everyone sees that someone yanked, nobody sees
## who. Deniability is the design, not an accident (research doc pitch #1).

const DAMP := 5.2
const MAX_SPEED := 1.4

var vel := Vector3.ZERO
## Board footprint (ellipse semi-axes in local XZ around board_center).
var board_center := Vector3.ZERO
var half_x := 1.62
var half_z := 1.06

var _ripple: MeshInstance3D
var _ripple_mat: StandardMaterial3D
var _ripple_t := 0.0
var _glow_mat: StandardMaterial3D

func build() -> void:
	# wooden teardrop body
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.19
	bm.height = 0.38
	body.mesh = bm
	body.scale = Vector3(1.0, 0.28, 1.35)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.48, 0.32, 0.2)
	wood.roughness = 0.5
	wood.emission_enabled = true
	wood.emission = Color(0.65, 0.45, 0.3)
	wood.emission_energy_multiplier = 0.14
	body.material_override = wood
	body.position.y = 0.035
	add_child(body)
	# spirit presence: a faint warm glow rides the planchette so all four
	# hands can track it in the candle-dark
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.72, 0.83, 1.0)
	lamp.light_energy = 1.0
	lamp.omni_range = 1.6
	lamp.position.y = 0.35
	add_child(lamp)
	# pointer tip toward -Z (north/up-board)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.075
	tm.height = 0.2
	tip.mesh = tm
	tip.material_override = wood
	tip.rotation_degrees = Vector3(-90, 0, 0)
	tip.position = Vector3(0, 0.03, -0.29)
	add_child(tip)
	# glass lens ring — the spirit's eye; glows while channeling a letter
	var ringm := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.055
	torus.outer_radius = 0.095
	ringm.mesh = torus
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.58, 0.28)
	brass.metallic = 0.8
	brass.roughness = 0.35
	ringm.material_override = brass
	ringm.position.y = 0.075
	add_child(ringm)
	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.06
	lm.bottom_radius = 0.06
	lm.height = 0.012
	lens.mesh = lm
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(0.75, 0.9, 1.0, 0.55)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(0.6, 0.85, 1.0)
	_glow_mat.emission_energy_multiplier = 0.9
	lens.material_override = _glow_mat
	lens.position.y = 0.075
	add_child(lens)
	# anonymous surge ripple (hidden until someone surges)
	_ripple = MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 0.16
	rt.outer_radius = 0.2
	_ripple.mesh = rt
	_ripple_mat = StandardMaterial3D.new()
	_ripple_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ripple_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ripple_mat.albedo_color = Color(0.8, 0.92, 1.0, 0.0)
	_ripple.material_override = _ripple_mat
	_ripple.position.y = 0.05
	add_child(_ripple)

## Channel intensity 0..1 — lens glow ramps while a letter is being held.
func set_channel(k: float) -> void:
	_glow_mat.emission_energy_multiplier = 0.9 + 3.2 * clampf(k, 0.0, 1.0)
	_glow_mat.albedo_color.a = 0.55 + 0.35 * clampf(k, 0.0, 1.0)

## Anonymous: same ripple whoever surged.
func show_surge_ripple() -> void:
	_ripple_t = 0.4

func apply_force(dir: Vector3, accel: float, delta: float) -> void:
	vel += dir * accel * delta

func apply_impulse(dir: Vector3, strength: float) -> void:
	vel += dir * strength

func tick(delta: float) -> void:
	vel -= vel * minf(DAMP * delta, 0.9)
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED
	position += vel * delta
	# clamp inside the board ellipse (slide along the rim, don't stick)
	var lx := (position.x - board_center.x) / half_x
	var lz := (position.z - board_center.z) / half_z
	var r2 := lx * lx + lz * lz
	if r2 > 1.0:
		var r := sqrt(r2)
		position.x = board_center.x + lx / r * half_x
		position.z = board_center.z + lz / r * half_z
		var n := Vector3(lx / half_x, 0, lz / half_z).normalized()
		var out := n.dot(vel)
		if out > 0.0:
			vel -= n * out
	position.y = board_center.y
	# ripple anim
	if _ripple_t > 0.0:
		_ripple_t = maxf(0.0, _ripple_t - delta)
		var k := 1.0 - _ripple_t / 0.4
		var s := 1.0 + k * 2.6
		_ripple.scale = Vector3(s, 1.0, s)
		_ripple_mat.albedo_color.a = 0.7 * (1.0 - k)
	else:
		_ripple_mat.albedo_color.a = 0.0
