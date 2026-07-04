class_name DWFighter
extends RigidBody3D
## A living sumo brawler wearing a KayKit body. Snappy 5 m/s control, A = shove
## (knockback scales with your speed), B = hop. No HP: you die by leaving the
## floor and falling into the void gutter. On death the controller turns you
## into a poltergeist.

const MOVE_SPEED := 5.0
const ACCEL := 42.0
const SHOVE_RANGE := 1.9
const SHOVE_ARC := 0.0         # dot() threshold: target must be in the front hemisphere
const SHOVE_BASE := 8.0
const SHOVE_SPEED_SCALE := 1.5
const SHOVE_CD := 0.7
const HOP_IMPULSE := 5.0
const HOP_CD := 1.5
const STUN_TIME := 0.32
const VOID_Y := -5.0        # below the floor slab (bottom at y=-3); only edge falls reach here

signal fell(index: int)

var index := 0
var color := Color.WHITE
var alive := true
var owner_game: Node = null
var last_attacker := {}        # {type, index, name, color, time}

var move_input := Vector2.ZERO
var want_shove := false
var want_hop := false

var _stun := 0.0
var _shove_cd := 0.0
var _hop_cd := 0.0
var _face := Vector3.FORWARD
var _grounded := false
var safe_spawn := Vector3.ZERO
var grace_until := 0.0

var model_pivot: Node3D
var anim: AnimationPlayer
var ring: MeshInstance3D
var _cur_anim := ""
var _anim_lock := 0.0

func setup(p_index: int, p_color: Color, char_scene: PackedScene, p_owner: Node) -> void:
	index = p_index
	color = p_color
	owner_game = p_owner
	mass = 1.5
	gravity_scale = 1.0
	continuous_cd = true
	can_sleep = false
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	linear_damp = 0.0
	collision_layer = 2                 # fighters
	collision_mask = 1 | 2 | 4          # floor, fighters, props
	add_to_group("dw_fighters")

	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.05
	physics_material_override = pm

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var caps := CapsuleShape3D.new()
	caps.radius = 0.32
	caps.height = 1.1
	shape.shape = caps
	shape.position.y = 0.55
	add_child(shape)

	# identity ring at the feet
	ring = MeshInstance3D.new()
	ring.name = "Ring"
	var rmesh := CylinderMesh.new()
	rmesh.top_radius = 0.42
	rmesh.bottom_radius = 0.46
	rmesh.height = 0.04
	ring.mesh = rmesh
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = 0.6
	ring.material_override = rmat
	ring.position.y = 0.03
	add_child(ring)

	model_pivot = Node3D.new()
	model_pivot.name = "ModelPivot"
	add_child(model_pivot)
	if char_scene != null:
		var body := char_scene.instantiate()
		body.scale = Vector3(0.95, 0.95, 0.95)
		model_pivot.add_child(body)
		anim = body.find_child("AnimationPlayer", true, false)
		_tint_model(body)
		_loop("Idle")
		_loop("Running_A")
		_set_anim("Idle")

func _tint_model(node: Node) -> void:
	# add a rim of identity color so team read is instant even at distance
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.rim_enabled = true
		m.rim = 0.6
		m.rim_tint = 0.9
		# leave the KayKit texture but push a colored rim via emission-ish tint
		mi.material_overlay = _rim_material()
	for c in node.get_children():
		_tint_model(c)

func _rim_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.28)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	m.rim = 0.8
	return m

func _loop(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func _set_anim(n: String) -> void:
	if anim == null or _cur_anim == n or not anim.has_animation(n):
		return
	_cur_anim = n
	anim.play(n)

func _update_anim(delta: float) -> void:
	if anim == null:
		return
	if _anim_lock > 0.0:
		_anim_lock -= delta
		return
	if _stun > 0.0:
		_set_anim("Hit_A")
	elif not _grounded:
		_set_anim("Jump_Idle")
	elif speed() > 0.7:
		_set_anim("Running_A")
	else:
		_set_anim("Idle")

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _shove_cd > 0.0: _shove_cd -= delta
	if _hop_cd > 0.0: _hop_cd -= delta

	if _stun > 0.0:
		_stun -= delta
	else:
		var desired := Vector3(move_input.x, 0.0, move_input.y) * MOVE_SPEED
		var v := linear_velocity
		v.x = move_toward(v.x, desired.x, ACCEL * delta)
		v.z = move_toward(v.z, desired.z, ACCEL * delta)
		linear_velocity = Vector3(v.x, linear_velocity.y, v.z)
		if desired.length() > 0.2:
			_face = desired.normalized()
			if model_pivot:
				var target_yaw := atan2(_face.x, _face.z)
				model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))

	if want_shove:
		want_shove = false
		_do_shove()
	if want_hop:
		want_hop = false
		_do_hop()

	# hard safety net: a fighter standing over the floor footprint can NEVER be
	# below its surface (Jolt can shove bodies down through the slab when two
	# capsules ram or a heavy prop slams them). Only past the ±6 lip may you sink.
	if global_position.y < -0.6 and absf(global_position.x) < 5.9 and absf(global_position.z) < 5.9:
		global_position.y = 0.05
		linear_velocity.y = maxf(linear_velocity.y, 0.0)

	if global_position.y < VOID_Y:
		# grace at round start: spawn jank rescues instead of killing
		if owner_game != null and owner_game.game_time < grace_until:
			global_position = safe_spawn
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_stun = 0.0
		else:
			_fall()

func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()

func _do_shove() -> void:
	if _shove_cd > 0.0 or owner_game == null:
		return
	_shove_cd = SHOVE_CD
	Sfx.play("bumper", -4.0)
	_cur_anim = "Interact"
	if anim and anim.has_animation("Interact"):
		anim.play("Interact")
	_anim_lock = 0.35
	var my_speed := speed()
	var power := SHOVE_BASE + my_speed * SHOVE_SPEED_SCALE
	var hit_any := false
	for other in owner_game.living_fighters():
		if other == self or not other.alive:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		if to.length() > SHOVE_RANGE:
			continue
		if _face.dot(to.normalized()) < SHOVE_ARC:
			continue
		other.call_deferred("hit", to, power, "player", index, "%s" % name, color)
		hit_any = true
	# also shove nearby free props so the arena stays kinetic
	for prop in owner_game.props():
		if prop.possessed_by >= 0:
			continue
		var pto: Vector3 = prop.global_position - global_position
		pto.y = 0.0
		if pto.length() <= SHOVE_RANGE and _face.dot(pto.normalized()) >= SHOVE_ARC:
			prop.apply_central_impulse(pto.normalized() * power * 0.5 + Vector3.UP * 0.5)
	if hit_any and owner_game.has_method("on_shove_landed"):
		owner_game.on_shove_landed(global_position)

func _do_hop() -> void:
	if _hop_cd > 0.0 or not _grounded:
		return
	_hop_cd = HOP_CD
	Sfx.play("putt", -6.0)
	_cur_anim = "Jump_Start"
	if anim and anim.has_animation("Jump_Start"):
		anim.play("Jump_Start")
	_anim_lock = 0.3
	apply_central_impulse(Vector3.UP * HOP_IMPULSE)

func hit(dir: Vector3, impulse: float, atk_type: String, atk_index: int, src_name: String, atk_color: Color) -> void:
	if not alive:
		return
	dir.y = 0.0
	var d := dir.normalized()
	apply_central_impulse(d * impulse + Vector3.UP * impulse * 0.14)
	_stun = STUN_TIME
	var t := 0.0
	if owner_game != null:
		t = owner_game.game_time
	last_attacker = {"type": atk_type, "index": atk_index, "name": src_name, "color": atk_color, "time": t}

func _process(delta: float) -> void:
	# cheap ground check for hop gating
	_grounded = alive and global_position.y < 0.15 and absf(linear_velocity.y) < 1.5
	# whoever last hit you stays on the hook until you're genuinely safe again:
	# grounded, unstunned, AND no longer sliding. A blow that skids you off the
	# lip still counts even though your feet never left the floor.
	if alive and _stun <= 0.0 and _grounded and speed() < 2.0 and not last_attacker.is_empty():
		last_attacker = {}
	if alive:
		_update_anim(delta)

func _fall() -> void:
	if not alive:
		return
	alive = false
	fell.emit(index)
	call_deferred("_disable_body")

func _disable_body() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	visible = false

func revive(pos: Vector3) -> void:
	alive = true
	freeze = true
	visible = true
	global_position = pos
	safe_spawn = pos + Vector3(0, 0.1, 0)
	if owner_game != null:
		grace_until = owner_game.game_time + 1.5
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_stun = 0.0
	_shove_cd = 0.0
	_hop_cd = 0.0
	last_attacker = {}
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	_anim_lock = 0.0
	_cur_anim = ""
	_set_anim("Idle")
	call_deferred("set", "freeze", false)
