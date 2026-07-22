class_name SwapOrb
extends Node3D
## SWAP projectiles (SWAP MEET). Three flavors:
##  - normal: lobbed forward-arc projectile, ~1.2s flight, generous hit
##    radius; whoever it tags trades places with the thrower.
##  - golden: homing missile locked onto the race leader (the comeback
##    verb). Ignores swap immunity; cannot miss.
##  - swap-shell: item-box draw that homes on the kart immediately ahead;
##    its hit uses the same atomic position exchange + immunity ritual.
## Stepped by the world (no physics bodies). A ground shadow blob keeps
## the lob readable from the fixed overhead camera.

const G := 11.0
const HIT_R := 0.9
const LIFE := 1.45
const GOLD_SPEED := 14.0
const GOLD_HIT_R := 1.1
const GOLD_LIFE := 4.0
const SHELL_SPEED := 12.5
const SHELL_HIT_R := 0.95
const SHELL_LIFE := 5.0

var world: Variant = null
var owner_idx: int = -1
var oid: int = 0             # ONLINE: host-assigned wire id (render mirror keying)
var golden: bool = false
var shell: bool = false
var target_idx: int = -1     # golden/shell: locked at throw time
var vel: Vector3 = Vector3.ZERO
var age: float = 0.0
var dead: bool = false

var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _trail: CPUParticles3D
var _blocked_notified: bool = false

func setup(w, owner_i: int, col: Color, is_golden: bool, is_shell: bool = false) -> void:
	world = w
	owner_idx = owner_i
	golden = is_golden
	shell = is_shell
	var c: Color = Color(1.0, 0.82, 0.2) if golden else (Color(0.22, 1.0, 0.72) if shell else col)
	_mesh = MeshInstance3D.new()
	if shell:
		var shell_mesh: PrismMesh = PrismMesh.new()
		shell_mesh.size = Vector3(0.62, 0.32, 0.72)
		_mesh.mesh = shell_mesh
	else:
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.30 if golden else 0.22
		sm.height = sm.radius * 2.0
		_mesh.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 1.8 if golden else 1.1
	_mesh.material_override = mat
	add_child(_mesh)
	_shadow = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.26
	cm.height = 0.01
	_shadow.mesh = cm
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(c.r, c.g, c.b, 0.4)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow.material_override = smat
	_shadow.top_level = true
	add_child(_shadow)
	_trail = CPUParticles3D.new()
	_trail.amount = 22
	_trail.lifetime = 0.4
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.3
	_trail.gravity = Vector3.ZERO
	_trail.scale_amount_min = 0.4
	_trail.scale_amount_max = 1.0
	var tm: SphereMesh = SphereMesh.new()
	tm.radius = 0.09 if golden else 0.06
	tm.height = tm.radius * 2.0
	_trail.mesh = tm
	var tmat: StandardMaterial3D = StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = Color(c.r, c.g, c.b, 0.7)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail.material_override = tmat
	_trail.emitting = true
	add_child(_trail)

## Returns the kart hit this tick, or null.
func step(dt: float) -> SwapKart:
	if dead:
		return null
	age += dt
	if golden:
		return _step_golden(dt)
	if shell:
		return _step_shell(dt)
	vel.y -= G * dt
	global_position += vel * dt
	if age > LIFE or (global_position.y < 0.18 and vel.y < 0.0):
		fizzle()
		return null
	for k in world.karts:
		var kart: SwapKart = k
		if kart.index == owner_idx or kart.finished:
			continue
		if global_position.distance_to(kart.center()) < HIT_R:
			if kart.swap_immune > 0.0:
				# 1s post-swap immunity: the orb sails right through
				if not _blocked_notified:
					_blocked_notified = true
					world.on_swap_blocked(self, kart)
				continue
			return kart
	return null

func _step_golden(dt: float) -> SwapKart:
	if target_idx >= 0 and world.karts[target_idx].finished:
		target_idx = world.leader_unfinished()
	if target_idx < 0:
		fizzle()
		return null
	var target: SwapKart = world.karts[target_idx]
	var want: Vector3 = (target.center() + Vector3(0, 0.3, 0) - global_position)
	var d: float = want.length()
	want = want.normalized() * GOLD_SPEED
	vel = vel.lerp(want, 1.0 - exp(-6.0 * dt))
	global_position += vel * dt
	if d < GOLD_HIT_R or age > GOLD_LIFE:
		return target  # cannot miss (ignores swap immunity by design)
	return null

func _step_shell(dt: float) -> SwapKart:
	if target_idx < 0 or target_idx >= world.karts.size() \
			or (world.karts[target_idx] as SwapKart).finished:
		target_idx = world.kart_ahead_of(owner_idx)
	if target_idx < 0:
		fizzle()
		return null
	var target: SwapKart = world.karts[target_idx]
	var delta_pos: Vector3 = target.center() - global_position
	var distance: float = delta_pos.length()
	var desired: Vector3 = delta_pos.normalized() * SHELL_SPEED
	vel = vel.lerp(desired, 1.0 - exp(-8.5 * dt))
	global_position += vel * dt
	if distance < SHELL_HIT_R:
		if target.swap_immune > 0.0:
			world.on_swap_blocked(self, target)
			fizzle()
			return null
		return target
	if age > SHELL_LIFE:
		fizzle()
	return null

func fizzle() -> void:
	if dead:
		return
	dead = true
	world.on_orb_fizzle(self)

func _process(_delta: float) -> void:
	if _shadow != null:
		_shadow.global_position = Vector3(global_position.x, 0.045, global_position.z)
		var h: float = clampf(global_position.y / 3.0, 0.0, 1.0)
		_shadow.scale = Vector3.ONE * (1.2 - 0.5 * h)
	if _mesh != null:
		_mesh.rotate_y(6.0 * _delta)
