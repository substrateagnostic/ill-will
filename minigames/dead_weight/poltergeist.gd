class_name DWGhost
extends Node3D
## The dead are the most dangerous people in the room. A free-flying wisp in the
## owner's color that hovers over the furniture, possesses a prop (hold A), and
## hurls it at the living. B releases (4s cooldown). Kills credit this ghost.

const FLY_SPEED := 7.5
const FLY_ACCEL := 30.0
const HOVER_Y := 1.7
const POSSESS_RANGE := 2.2     # how close the wisp must be to grab a prop
const HIGHLIGHT_RANGE := 2.6
const POSSESS_CD := 4.0
const FLING_CD := 0.55         # min gap between poltergeist flings
const ARENA_LIMIT := 7.5       # ghosts may drift a little past the floor edge

var index := 0
var color := Color.WHITE
var owner_game: Node = null

var move_input := Vector2.ZERO
var want_possess := false      # A held (free-fly: grab the nearest prop)
var want_release := false      # B pressed (let go without flinging)
var want_fling := false        # A pressed while possessing (hurl the prop)
var aim_fling := Vector3.ZERO  # RIGHT channel (mouse cursor / right stick) fling dir;
                               # ZERO => fling along the LEFT-channel drift direction

var possessing: DWProp = null
var hover_target: DWProp = null
var _possess_cd := 0.0
var _fling_cd := 0.0
var _vel := Vector3.ZERO

var _orb: MeshInstance3D
var _light: OmniLight3D
var _wisps: CPUParticles3D

func setup(p_index: int, p_color: Color, p_owner: Node) -> void:
	index = p_index
	color = p_color
	owner_game = p_owner
	add_to_group("dw_ghosts")

	_orb = MeshInstance3D.new()
	_orb.name = "Orb"
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	_orb.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.7)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.5
	_orb.material_override = m
	add_child(_orb)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 2.2
	_light.omni_range = 4.5
	add_child(_light)

	_wisps = CPUParticles3D.new()
	_wisps.amount = 24
	_wisps.lifetime = 0.7
	_wisps.local_coords = false
	_wisps.direction = Vector3.UP
	_wisps.spread = 30.0
	_wisps.gravity = Vector3(0, 0.8, 0)
	_wisps.initial_velocity_min = 0.3
	_wisps.initial_velocity_max = 0.8
	_wisps.scale_amount_min = 0.3
	_wisps.scale_amount_max = 0.7
	var wm := SphereMesh.new()
	wm.radius = 0.07
	wm.height = 0.14
	_wisps.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	_wisps.material_override = wmat
	_wisps.emitting = true
	add_child(_wisps)

func spawn_at(pos: Vector3) -> void:
	global_position = Vector3(pos.x, HOVER_Y, pos.z)
	_vel = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if _possess_cd > 0.0:
		_possess_cd -= delta
	if _fling_cd > 0.0:
		_fling_cd -= delta

	if possessing != null:
		_drive_possession(delta)
	else:
		_free_fly(delta)

	if want_release and possessing != null:
		release()
	want_release = false

	# pulse the orb so ghosts read as alive-in-death
	if _orb:
		var s := 1.0 + sin(owner_game_time() * 6.0) * 0.12
		_orb.scale = Vector3(s, s, s)

func owner_game_time() -> float:
	if owner_game != null:
		return owner_game.game_time
	return 0.0

func _free_fly(delta: float) -> void:
	var dir := Vector3(move_input.x, 0.0, move_input.y)
	var desired := dir * FLY_SPEED
	_vel.x = move_toward(_vel.x, desired.x, FLY_ACCEL * delta)
	_vel.z = move_toward(_vel.z, desired.z, FLY_ACCEL * delta)
	global_position += _vel * delta
	global_position.x = clampf(global_position.x, -ARENA_LIMIT, ARENA_LIMIT)
	global_position.z = clampf(global_position.z, -ARENA_LIMIT, ARENA_LIMIT)
	global_position.y = lerpf(global_position.y, HOVER_Y, 1.0 - exp(-6.0 * delta))

	# find the nearest possessable prop to highlight
	hover_target = _nearest_prop(HIGHLIGHT_RANGE)
	if want_possess and hover_target != null and _possess_cd <= 0.0:
		if hover_target.can_be_possessed() and _flat_dist(hover_target) <= POSSESS_RANGE:
			_begin_possession(hover_target)

func _drive_possession(delta: float) -> void:
	if not is_instance_valid(possessing) or possessing.possessed_by != index:
		possessing = null
		return
	if possessing.global_position.y < -1.5:
		# the prop fell into the void; let go
		release()
		return
	# TWIN-STICK CONVENTION: LEFT (WASD / left stick) DRIFTS the furniture; RIGHT
	# (mouse cursor / right stick) AIMS a discrete FLING (LMB / A). Bots and non-KBM
	# humans leave aim_fling ZERO and never set want_fling, so their whole drive is
	# this same move_input apply_drive -- byte-identical to the old behavior.
	possessing.apply_drive(Vector3(move_input.x, 0.0, move_input.y))
	if want_fling and _fling_cd <= 0.0:
		var fdir := aim_fling
		if fdir == Vector3.ZERO:
			fdir = Vector3(move_input.x, 0.0, move_input.y)   # fallback: fling along drift
		possessing.fling(fdir)
		_fling_cd = FLING_CD
		Sfx.play("bumper", -3.0)
	want_fling = false
	# the wisp rides the prop
	global_position = global_position.lerp(possessing.global_position + Vector3(0, 0.4, 0), 1.0 - exp(-12.0 * delta))

func _begin_possession(prop: DWProp) -> void:
	possessing = prop
	prop.possess(index, color)
	Sfx.play("grudge", -2.0)
	if owner_game != null and owner_game.has_method("on_possess"):
		owner_game.on_possess(self, prop)

func release() -> void:
	if possessing != null and is_instance_valid(possessing) and possessing.possessed_by == index:
		possessing.release()
	possessing = null
	_possess_cd = POSSESS_CD
	Sfx.play("card", -6.0)

func force_release() -> void:
	# called at round reset
	if possessing != null and is_instance_valid(possessing) and possessing.possessed_by == index:
		possessing.release()
	possessing = null
	_possess_cd = 0.0

func _nearest_prop(within: float) -> DWProp:
	if owner_game == null:
		return null
	var best: DWProp = null
	var best_d := within
	for prop in owner_game.props():
		if prop.possessed_by >= 0:
			continue
		var d := _flat_dist(prop)
		if d < best_d:
			best_d = d
			best = prop
	return best

func _flat_dist(node: Node3D) -> float:
	var a := global_position
	var b := node.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()
