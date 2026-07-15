class_name Royal
extends RigidBody3D
## One tyrant-in-waiting wearing a KayKit body. Two lives in one node:
##  - CHALLENGER: snappy 5 m/s control, A = shove (Par-family knockback that
##    scales with your speed, 0.7s cd), B = dash (burst of speed to close on
##    the throne or escape a decree).
##  - KING: frozen on the seat (cannot move), scores while seated, and the
##    controller drives its court powers. A landed challenger shove drains the
##    king's GRIP instead of knocking it — at 0 grip the controller LAUNCHES
##    this body off the dais in a ragdoll tumble.
##
## Owns: challenger movement + shove + dash + the launch tumble. The controller
## (throne.gd) owns seating, grip, scoring, decree and guard powers.

const MOVE_SPEED := 5.0
const ACCEL := 42.0
const SHOVE_RANGE := 1.9
const SHOVE_ARC := -0.15         # dot() threshold: slightly forgiving front arc
const SHOVE_BASE := 8.0
const SHOVE_SPEED_SCALE := 1.5
const SHOVE_CD := 0.7
const DASH_IMPULSE := 7.5
const DASH_CD := 1.4
const STUN_TIME := 0.30

# ---- EXPRESSIVE HOP (director's ruling, docs/design/16-jump-and-visibility.md) ----
# Cosmetic-only bunny-hop, self-contained (this file reads PlayerInput directly
# for "jump" — the existing move/shove/dash fields stay externally driven by
# throne.gd, untouched). Refused while seated (is_king — frozen/can't move,
# the throne's "carrying"-equivalent commitment), mid-tumble (post-dethrone
# ragdoll) or mid-stun. _do_shove()'s range check flattens Y unconditionally
# (royal.gd:350, `to.y = 0.0` before SHOVE_RANGE/SHOVE_ARC) regardless of
# either party's height, so a hop cannot grant or deny a shove either way —
# this refusal is about animation cleanliness, not balance.
const HOP_VY := 3.0
const HOP_GRAVITY := 15.0        # softer than the RigidBody's own gravity: a floaty arc
const HOP_AIRTIME := 0.4         # 2*HOP_VY/HOP_GRAVITY — exact analytic hang time
const HOP_CD := 0.5
const HOP_START_ANIM_T := 0.12
const HOP_LAND_HOLD_T := 0.15
const HOP_SQUASH_T := 0.1

signal king_shoved(attacker: int, dir: Vector3)   # a shove connected with the seated king

var index := 0
var color := Color.WHITE
var owner_game: Node = null
var is_bot := false

var is_king := false
var seat_pos := Vector3.ZERO
var re_sit_cd := 0.0              # after being launched, cannot re-sit for a bit

var move_input := Vector2.ZERO
var want_shove := false
var want_dash := false

var _stun := 0.0
var _shove_cd := 0.0
var _dash_cd := 0.0
var _face := Vector3(0, 0, 1)     # face the camera by default (camera is at +Z)
var _grounded := false
var _tumble_t := 0.0             # >0 while ragdoll-tumbling after a launch

# EXPRESSIVE HOP state (cosmetic only — never read by combat resolution)
var _hop_t := -1.0                # >=0 while airborne from a hop, counts up to HOP_AIRTIME
var _hop_cd := 0.0
var _hop_anim_t := 0.0
var _hop_land_hold := 0.0
var _hop_intro_t := -1.0          # bots: one hop shortly after match start
var _hop_after_recover_t := -1.0  # bots: one hop shortly after recovering from a dethrone tumble
var _hop_rng := RandomNumberGenerator.new()

var model_pivot: Node3D
var anim: AnimationPlayer
var ring: MeshInstance3D
var crown_anchor: Node3D
var _cur_anim := ""
var _anim_lock := 0.0
var _squash_tw: Tween             # owns the HIT KIT windup/pop model scale
var net_mirror := false           # ONLINE: this body renders host state, never simulates

func setup(p_index: int, p_color: Color, char_scene: PackedScene, p_owner: Node) -> void:
	index = p_index
	color = p_color
	owner_game = p_owner
	mass = 1.5
	gravity_scale = 1.0
	continuous_cd = true
	can_sleep = false
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_lock_upright()
	linear_damp = 0.2
	collision_layer = 2                 # royals
	collision_mask = 1 | 2 | 4          # environment, other royals, guards
	add_to_group("throne_royals")

	var pm := PhysicsMaterial.new()
	pm.friction = 0.5
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
	rmat.emission_energy_multiplier = 0.7
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
		_loop("Jump_Idle")
		_set_anim("Idle")

	_hop_rng.seed = p_index * 977 + 401
	_hop_intro_t = _hop_rng.randf_range(2.0, 6.0)

	# a socket above the head where the crown rides while this royal reigns
	crown_anchor = Node3D.new()
	crown_anchor.name = "CrownAnchor"
	crown_anchor.position = Vector3(0, 1.55, 0)
	model_pivot.add_child(crown_anchor)

func _lock_upright() -> void:
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	angular_velocity = Vector3.ZERO

func _unlock_angular() -> void:
	axis_lock_angular_x = false
	axis_lock_angular_y = false
	axis_lock_angular_z = false

func _tint_model(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = _rim_material()
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

func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()

# ----------------------------------------------------------------- king mode
func become_king(p_seat: Vector3) -> void:
	is_king = true
	seat_pos = p_seat
	move_input = Vector2.ZERO
	want_shove = false
	want_dash = false
	_stun = 0.0
	_tumble_t = 0.0
	_hop_t = -1.0            # a coronation mid-hop lands instantly, not on delay
	_hop_land_hold = 0.0
	_lock_upright()
	linear_velocity = Vector3.ZERO
	global_position = seat_pos
	# face the camera (at +Z) so the crown and cushion read; KayKit faces -Z,
	# so rotate the model 180 deg to look toward the viewer
	_face = Vector3(0, 0, 1)
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	if model_pivot:
		model_pivot.rotation.y = PI
		model_pivot.scale = Vector3.ONE
	freeze = true
	_set_anim("Idle")

func stop_being_king() -> void:
	is_king = false
	freeze = false

## The controller calls this when grip hits 0: a big ragdoll fling off the seat.
func launch(dir: Vector3, force: float) -> void:
	stop_being_king()
	dir.y = 0.0
	var d := dir.normalized() if dir.length() > 0.05 else Vector3(0, 0, 1)
	_unlock_angular()
	_stun = STUN_TIME * 2.0
	_tumble_t = 1.4
	re_sit_cd = 2.0
	apply_central_impulse(d * force + Vector3.UP * force * 0.55)
	apply_torque_impulse(Vector3(d.z, 1.0, -d.x) * force * 0.4)
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	if model_pivot:
		model_pivot.scale = Vector3.ONE
	if anim and anim.has_animation("Hit_A"):
		_cur_anim = "Hit_A"
		anim.play("Hit_A")
	_anim_lock = 0.6

# ----------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	if net_mirror:
		return   # ONLINE mirror: the host owns physics; net_render drives this body
	if _shove_cd > 0.0: _shove_cd -= delta
	if _dash_cd > 0.0: _dash_cd -= delta
	if re_sit_cd > 0.0: re_sit_cd -= delta
	if _hop_cd > 0.0: _hop_cd -= delta
	if _hop_land_hold > 0.0: _hop_land_hold -= delta

	if is_king:
		# hard-pin to the seat every tick (frozen static, but be defensive)
		global_position = seat_pos
		linear_velocity = Vector3.ZERO
		return

	if _tumble_t > 0.0:
		_tumble_t -= delta
		if _tumble_t <= 0.0:
			_lock_upright()
			rotation = Vector3.ZERO
			if is_bot:
				_hop_after_recover_t = _hop_rng.randf_range(0.3, 0.9)

	_grounded = linear_velocity.y > -2.5 and linear_velocity.y < 2.0

	if _stun > 0.0:
		_stun -= delta
	elif _tumble_t <= 0.0:
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
	if want_dash:
		want_dash = false
		_do_dash()

	# ---- EXPRESSIVE HOP: fixed-arc vertical pop, driven by a timer (not
	# is_on_floor(), which RigidBody3D doesn't offer) — analytically returns to
	# ground exactly at HOP_AIRTIME given HOP_VY/HOP_GRAVITY, so it self-lands
	# without fighting the body's own gravity_scale integration.
	if _hop_t >= 0.0:
		_hop_t += delta
		_hop_anim_t = maxf(0.0, _hop_anim_t - delta)
		var lv := linear_velocity
		lv.y = HOP_VY - HOP_GRAVITY * _hop_t
		linear_velocity = lv
		if _hop_t >= HOP_AIRTIME:
			_hop_t = -1.0
			_hop_land_hold = HOP_LAND_HOLD_T
			_hop_land_fx()
	elif _tumble_t <= 0.0 and _stun <= 0.0 and _hop_cd <= 0.0:
		var want_hop := false
		if is_bot:
			_hop_intro_t -= delta
			if _hop_intro_t <= 0.0 and _hop_intro_t > -900.0:
				want_hop = true
				_hop_intro_t = -1000.0   # consumed; never re-fires from the intro timer
			if _hop_after_recover_t > 0.0:
				_hop_after_recover_t -= delta
				if _hop_after_recover_t <= 0.0:
					want_hop = true
		else:
			want_hop = PlayerInput.just_pressed(index, "jump")
		if want_hop:
			_hop_t = 0.0
			_hop_anim_t = HOP_START_ANIM_T
			_hop_cd = HOP_CD
			Sfx.play("putt", -8.0)
			print("THRONE_HOP idx=%d bot=%s frame=%d" % [index, str(is_bot), Engine.get_physics_frames()])

	# safety net: a hard dethrone launch must never lose a body over the wall
	# or under the floor. Catch any escapee and set it back inside the arena.
	if global_position.y < -2.0 or absf(global_position.x) > 7.0 or absf(global_position.z) > 7.0:
		print("THRONE_RESCUE royal=%d from=(%.1f,%.1f,%.1f)" % [index, global_position.x, global_position.y, global_position.z])
		global_position = Vector3(clampf(global_position.x, -5.0, 5.0), 0.5, clampf(global_position.z, -5.0, 5.0))
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		_tumble_t = 0.0
		_stun = 0.0
		_lock_upright()
		rotation = Vector3.ZERO

func _process(delta: float) -> void:
	if net_mirror:
		return   # ONLINE mirror: net_render sets the anim tag from the host
	_update_anim(delta)

# --- ONLINE mirror (docs/design/10 §4.3) ------------------------------------
## The model's facing yaw (host packs this; the mirror lerps toward it).
func model_yaw() -> float:
	return model_pivot.rotation.y if model_pivot else 0.0

## Current anim tag for the wire (Idle / Running_A / Hit_A / Interact).
func anim_tag() -> String:
	return _cur_anim

## Apply a host snapshot on the mirror: place the (frozen) body, face the model,
## and re-play the anim when the tag changes. No physics, no input.
func net_render(pos: Vector3, yaw: float, tag: String, king_now: bool) -> void:
	global_position = pos
	is_king = king_now
	if model_pivot:
		model_pivot.rotation.y = yaw
	if tag != _cur_anim and anim != null and anim.has_animation(tag):
		_cur_anim = tag
		anim.play(tag)

func _update_anim(delta: float) -> void:
	if anim == null:
		return
	# EXPRESSIVE HOP anim triptych takes priority over everything but the
	# seated pose — hop is refused while is_king (see royal.gd's hop trigger),
	# so this never actually races the seat. _hop_t/_hop_anim_t/_hop_land_hold
	# are decremented in _physics_process; read-only here (see the _stun/
	# _tumble_t pattern just below for the same read/decrement split).
	if _hop_t >= 0.0:
		_set_anim("Jump_Start" if _hop_anim_t > 0.0 else "Jump_Idle")
		return
	if _hop_land_hold > 0.0:
		_set_anim("Jump_Land")
		return
	if _anim_lock > 0.0:
		_anim_lock -= delta
		return
	if is_king:
		_set_anim("Idle")
	elif _tumble_t > 0.0 or _stun > 0.0:
		_set_anim("Hit_A")
	elif speed() > 0.8:
		_set_anim("Running_A")
	else:
		_set_anim("Idle")

## Visual FX gate — off in the reproducible no-FX balance sim (--thronebalancefast).
func _visuals_on() -> bool:
	return owner_game != null and owner_game.has_method("fx_on") and owner_game.fx_on()


## HIT KIT §B1 Phase 1 — WINDUP coil (chunky crouch) then spring back. Visual
## only; the shove hitbox still resolves this same frame, so time-to-hit is
## unchanged (< 0.18s). This is the "standard shove windup" (research fix #3).
func windup_coil() -> void:
	if model_pivot == null or not _visuals_on():
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_squash_tw = create_tween()
	_squash_tw.tween_property(model_pivot, "scale", Vector3(1.08, 0.90, 1.08), 0.06)
	_squash_tw.tween_property(model_pivot, "scale", Vector3.ONE, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## HIT KIT §B1 Phase 2 — victim impact pop (flatten wide, snap back over 0.16s).
func flash_pop() -> void:
	if model_pivot == null or not _visuals_on():
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	model_pivot.scale = Vector3(1.22, 0.85, 1.22)
	_squash_tw = create_tween()
	_squash_tw.tween_property(model_pivot, "scale", Vector3.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## EXPRESSIVE HOP landing beat: squash-stretch (1.08 wide / 0.92 tall, 0.1s —
## smaller than the HIT KIT's flash_pop above) + a tiny dust puff. Gated behind
## _visuals_on() like the rest of the HIT KIT so --thronebalancefast stays a
## reproducible no-FX sim.
func _hop_land_fx() -> void:
	if model_pivot == null or not _visuals_on():
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_squash_tw = create_tween()
	model_pivot.scale = Vector3(1.08, 0.92, 1.08)
	_squash_tw.tween_property(model_pivot, "scale", Vector3.ONE, HOP_SQUASH_T) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_hop_dust()


func _spawn_hop_dust() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 8
	p.lifetime = 0.35
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 50.0
	p.gravity = Vector3(0, -4.0, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.12
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.68, 0.55, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.mesh.surface_set_material(0, mat)
	add_child(p)
	p.top_level = true         # decouple from the (possibly still-moving) body
	p.global_position = global_position + Vector3(0, 0.05, 0)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


func _do_shove() -> void:
	if _shove_cd > 0.0 or owner_game == null:
		return
	_shove_cd = SHOVE_CD
	windup_coil()                       # HIT KIT windup on the shove action
	Sfx.play("bumper", -4.0)
	if anim and anim.has_animation("Interact"):
		_cur_anim = "Interact"
		anim.play("Interact")
		_anim_lock = 0.32
	var power := SHOVE_BASE + speed() * SHOVE_SPEED_SCALE
	for other in owner_game.royals():
		if other == self:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		if to.length() > SHOVE_RANGE or to.length() < 0.001:
			continue
		if _face.dot(to.normalized()) < SHOVE_ARC:
			continue
		if other.is_king:
			# a shove on the throne drains grip instead of moving the king
			king_shoved.emit(index, to)
			owner_game.on_king_shoved(index, to)
		else:
			other.call_deferred("take_shove", to, power, index)
	if owner_game.has_method("on_shove_landed"):
		owner_game.on_shove_landed(global_position)

func _do_dash() -> void:
	if _dash_cd > 0.0:
		return
	_dash_cd = DASH_CD
	Sfx.play("putt", -6.0)
	var dir := Vector3(move_input.x, 0, move_input.y)
	if dir.length() < 0.1:
		dir = _face
	dir.y = 0.0
	apply_central_impulse(dir.normalized() * DASH_IMPULSE)

func take_shove(dir: Vector3, impulse: float, attacker: int) -> void:
	if is_king:
		return
	dir.y = 0.0
	apply_central_impulse(dir.normalized() * impulse + Vector3.UP * impulse * 0.12)
	_stun = STUN_TIME
	# HIT KIT: victim squash-pop + spark along the knockback at the strike point.
	flash_pop()
	if _visuals_on() and owner_game.has_method("spark_at"):
		var col: Color = color
		if attacker >= 0 and attacker < owner_game.players.size():
			col = owner_game.players[attacker].color
		owner_game.spark_at(global_position + Vector3(0, 0.9, 0), dir, col, _shove_strength(impulse))

## The controller's decree blast pushes challengers away from the dais.
func apply_blast(dir: Vector3, impulse: float) -> void:
	if is_king:
		return
	dir.y = 0.0
	apply_central_impulse(dir.normalized() * impulse + Vector3.UP * impulse * 0.35)
	_stun = STUN_TIME
	# HIT KIT victim pop (the decree already carries its own shockwave for the spark read).
	flash_pop()

## Normalized impact strength for HIT KIT scaling (spark count / shake).
func _shove_strength(impulse: float) -> float:
	return clampf(impulse / (SHOVE_BASE + 5.0 * SHOVE_SPEED_SCALE), 0.5, 1.5)
