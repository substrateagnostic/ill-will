class_name LWWisp
extends Node3D
## The HAUNTED curse made flesh (well — vapor). A sickly green wisp that
## chases its victim for the curse duration; contact = stumble, then it
## re-arms after a moment and keeps hunting. Slightly slower than a pawn at
## full sprint, so the haunted can kite it — while dodging everything else.
## Code-driven; ticked by the controller only while the round runs.

const CHASE_SPEED := 4.4
const HOVER_Y := 1.1
const CONTACT_R := 0.55
const REARM_T := 1.6

var owner_game: Node = null
var target_index := -1
var life := 8.0
var _rearm := 0.0
var _vel := Vector3.ZERO
var _t := 0.0

var _orb: MeshInstance3D

func setup(p_target: int, duration: float, spawn_pos: Vector3, p_owner: Node) -> void:
	owner_game = p_owner
	target_index = p_target
	life = duration
	global_position = spawn_pos + Vector3(0, HOVER_Y, 0)

	var gc := Color(0.5, 1.0, 0.55)
	_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.26
	sm.height = 0.52
	_orb.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(gc.r, gc.g, gc.b, 0.75)
	m.emission_enabled = true
	m.emission = gc
	m.emission_energy_multiplier = 2.2
	_orb.material_override = m
	add_child(_orb)

	# two little "eyes" so it reads as a hungry spirit, not a particle
	for ex in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.045
		em.height = 0.09
		eye.mesh = em
		var emat := StandardMaterial3D.new()
		emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emat.albedo_color = Color(0.05, 0.12, 0.05)
		eye.material_override = emat
		eye.position = Vector3(ex, 0.06, 0.2)
		add_child(eye)

	var light := OmniLight3D.new()
	light.light_color = gc
	light.light_energy = 1.4
	light.omni_range = 3.0
	add_child(light)

	var trail := CPUParticles3D.new()
	trail.amount = 22
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.direction = Vector3.UP
	trail.spread = 25.0
	trail.gravity = Vector3(0, 0.5, 0)
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 0.7
	var tm := SphereMesh.new()
	tm.radius = 0.07
	tm.height = 0.14
	trail.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.albedo_color = Color(gc.r, gc.g, gc.b, 0.45)
	trail.material_override = tmat
	trail.emitting = true
	add_child(trail)

## Returns false when the wisp is spent (controller frees it + clears curse).
func tick(delta: float) -> bool:
	life -= delta
	if life <= 0.0:
		return false
	if _rearm > 0.0:
		_rearm -= delta
	_t += delta
	_orb.scale = Vector3.ONE * (1.0 + sin(_t * 9.0) * 0.15)

	if owner_game == null:
		return true
	var victim = owner_game.pawn_of(target_index)
	if victim == null or not victim.alive:
		return false
	var to: Vector3 = victim.global_position + Vector3(0, HOVER_Y, 0) - global_position
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > 0.05:
		var desired := flat.normalized() * CHASE_SPEED
		_vel.x = move_toward(_vel.x, desired.x, 12.0 * delta)
		_vel.z = move_toward(_vel.z, desired.z, 12.0 * delta)
	global_position += _vel * delta
	global_position.y = lerpf(global_position.y, victim.global_position.y + HOVER_Y, 1.0 - exp(-5.0 * delta))
	# face the prey
	if flat.length() > 0.1:
		rotation.y = atan2(flat.x, flat.z)

	if _rearm <= 0.0 and flat.length() < CONTACT_R:
		victim.stumble()
		_rearm = REARM_T
		if owner_game.has_method("on_wisp_contact"):
			owner_game.on_wisp_contact(target_index)
	return true
