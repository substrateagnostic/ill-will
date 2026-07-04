class_name EchoFighter
extends CharacterBody3D
## A live brawler (player- or bot-controlled). Driven MANUALLY by the main
## controller via tick(delta) — NOT its own _physics_process — so the whole
## arena updates in one deterministic order each physics step:
##   1. controller ticks every fighter (they read input + move_and_slide)
##   2. controller samples the recorder from post-move state
##   3. controller replays ghosts against those fresh positions
## This ordering is what makes recording -> replay drift-free.

# ---- shared animation-state ids (ghost.gd mirrors these) ----
const ST_IDLE := 0
const ST_RUN := 1
const ST_SWING := 2
const ST_DASH := 3
const ST_HIT := 4
const ST_DEAD := 5

# ---- feel constants (see spec "Feel targets") ----
const MOVE_SPEED := 5.0
const DASH_SPEED := 11.0
const DASH_TIME := 0.25
const DASH_CD := 1.2
const SWING_CD := 0.5
const SWING_STRIKE_T := 0.04         # hitbox goes live <50ms after press
const SWING_LOCK_T := 0.34           # rooted while the swing animates
const SWING_RANGE := 1.9
const SWING_HALF_ARC := deg_to_rad(60.0)   # 120deg total cone
const KNOCKBACK := 7.5
const HP_MAX := 3
const GRAVITY := 24.0
const SPAWN_PROTECT := 1.0
const STAGGER_T := 0.18
const TURN_LERP := 18.0
const MODEL_YAW_OFFSET := PI          # KayKit adventurers face +Z natively

var player_index := 0
var color := Color.WHITE
var char_path := ""
var is_bot := false
var main: Node = null                 # EchoChamber (untyped: avoid cyclic type)

var hp := HP_MAX
var alive := true
var yaw := 0.0
var state := ST_IDLE

var _knockback := Vector3.ZERO
var _swing_cd := 0.0
var _swing_t := -1.0
var _swing_did_strike := false
var _fire_latch := false              # a strike happened; recorder consumes it
var _dash_cd := 0.0
var _dash_t := -1.0
var _dash_dir := Vector3.FORWARD
var _iframe := 0.0
var _stagger := 0.0

var _pivot: Node3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _cur_anim := ""
var _base_scale := 1.0

# ---- bot state (all seeded, no wall-clock) ----
var _bot_rng := RandomNumberGenerator.new()
var _bot_target := Vector3.ZERO
var _bot_wander_t := 0.0
var _bot_swing_t := 0.0
var _bot_dash_t := 0.0
var _bot_move := Vector2.ZERO
var _bot_swing_edge := false
var _bot_dash_edge := false


func setup(seed_base: int) -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.4
	cap.shape = shape
	cap.position.y = 0.7
	add_child(cap)

	_pivot = Node3D.new()
	add_child(_pivot)
	var scene: PackedScene = load(char_path)
	var inst := scene.instantiate()
	_base_scale = 0.9
	inst.scale = Vector3(_base_scale, _base_scale, _base_scale)
	_pivot.add_child(inst)
	_anim = inst.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A"]:
		if _anim and _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	# identity ring on the ground (house style: color = player)
	_ring = MeshInstance3D.new()
	var rmesh := CylinderMesh.new()
	rmesh.top_radius = 0.5
	rmesh.bottom_radius = 0.55
	rmesh.height = 0.04
	_ring.mesh = rmesh
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = 0.35
	rmat.roughness = 0.5
	_ring.material_override = rmat
	_ring.position.y = 0.03
	add_child(_ring)

	_bot_rng.seed = seed_base * 131 + player_index * 977 + 7
	_play("Idle")


func tick(delta: float) -> void:
	if not alive:
		return
	_swing_cd = maxf(0.0, _swing_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_iframe = maxf(0.0, _iframe - delta)
	if _stagger > 0.0:
		_stagger -= delta

	var mv := Vector2.ZERO
	var want_swing := false
	var want_dash := false
	if is_bot:
		_bot_tick(delta)
		mv = _bot_move
		want_swing = _bot_swing_edge
		want_dash = _bot_dash_edge
	else:
		mv = PlayerInput.get_move(player_index)
		want_swing = PlayerInput.just_pressed(player_index, "a")
		want_dash = PlayerInput.just_pressed(player_index, "b")

	var locked := (_swing_t >= 0.0 and _swing_t < SWING_LOCK_T) or _stagger > 0.0
	if want_dash and _dash_cd <= 0.0 and _dash_t < 0.0 and _stagger <= 0.0:
		_start_dash(mv)
	elif want_swing and _swing_cd <= 0.0 and _dash_t < 0.0 and not locked:
		_start_swing()

	# advance an active swing; fire the arc once, early (<50ms)
	if _swing_t >= 0.0:
		_swing_t += delta
		if not _swing_did_strike and _swing_t >= SWING_STRIKE_T:
			_swing_did_strike = true
			_fire_latch = true
			Sfx.play("putt", -5.0)
			if main:
				main.resolve_swing(global_position, yaw, player_index, false, self, 0)
		if _swing_t >= SWING_LOCK_T:
			_swing_t = -1.0

	# horizontal movement
	var horiz := Vector3.ZERO
	if _dash_t >= 0.0:
		_dash_t += delta
		horiz = _dash_dir * DASH_SPEED
		if _dash_t >= DASH_TIME:
			_dash_t = -1.0
			state = ST_IDLE
	elif locked:
		horiz = Vector3.ZERO
	else:
		var dir := Vector3(mv.x, 0.0, mv.y)
		if dir.length() > 1.0:
			dir = dir.normalized()
		horiz = dir * MOVE_SPEED
		if dir.length() > 0.06:
			yaw = lerp_angle(yaw, atan2(dir.x, dir.z), 1.0 - exp(-TURN_LERP * delta))
			state = ST_RUN
		else:
			state = ST_IDLE

	horiz += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 32.0 * delta)

	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
	_apply_locomotion_anim()

	if global_position.y < -3.0 and alive and main:
		main.on_fall_death(player_index)


func _apply_locomotion_anim() -> void:
	# one-shots (swing/dash/hit) are launched by their starters; only resume
	# idle/run locomotion here so we don't stomp an in-progress attack.
	if state == ST_RUN:
		_play("Running_A")
	elif state == ST_IDLE:
		_play("Idle")


func _start_swing() -> void:
	_swing_t = 0.0
	_swing_cd = SWING_CD
	_swing_did_strike = false
	state = ST_SWING
	_play("1H_Melee_Attack_Slice_Horizontal", false)


func _start_dash(mv: Vector2) -> void:
	var dir := Vector3(mv.x, 0.0, mv.y)
	if dir.length() < 0.1:
		dir = _forward()
	_dash_dir = dir.normalized()
	_dash_t = 0.0
	_dash_cd = DASH_CD
	_iframe = maxf(_iframe, DASH_TIME + 0.02)   # i-frames span the whole dash
	state = ST_DASH
	yaw = atan2(_dash_dir.x, _dash_dir.z)
	Sfx.play("bounce", -6.0)
	_play("Dodge_Forward", false)


## Returns "" (missed/immune), "hit", or "kill".
func take_hit(dmg: int, from_pos: Vector3, _attacker: int) -> String:
	if not alive or _iframe > 0.0:
		return ""
	hp -= dmg
	var kdir := global_position - from_pos
	kdir.y = 0.0
	if kdir.length() < 0.01:
		kdir = -_forward()
	_knockback = kdir.normalized() * KNOCKBACK
	if hp <= 0:
		kill()
		return "kill"
	_stagger = STAGGER_T
	state = ST_HIT
	_play("Hit_A", false)
	Sfx.play("splat", -3.0)
	_flash_pop()
	return "hit"


func kill() -> void:
	if not alive:
		return
	alive = false
	hp = 0
	state = ST_DEAD
	_knockback = Vector3.ZERO
	velocity = Vector3.ZERO
	_swing_t = -1.0
	_dash_t = -1.0
	_play("Death_A", false)


func respawn(pos: Vector3, hp_amount: int) -> void:
	alive = true
	hp = hp_amount
	global_position = pos
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_iframe = SPAWN_PROTECT
	_stagger = 0.0
	_swing_t = -1.0
	_dash_t = -1.0
	_swing_cd = 0.0
	_dash_cd = 0.0
	state = ST_IDLE
	_play("Idle")


func consume_fire() -> bool:
	var f := _fire_latch
	_fire_latch = false
	return f


func _forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func _play(anim_name: String, loop := true) -> void:
	if _anim == null or _cur_anim == anim_name:
		return
	if not _anim.has_animation(anim_name):
		return
	if loop:
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name)
	_cur_anim = anim_name


func _flash_pop() -> void:
	if _pivot == null:
		return
	var tw := create_tween()
	_pivot.scale = Vector3(_base_scale * 1.22, _base_scale * 0.85, _base_scale * 1.22)
	tw.tween_property(_pivot, "scale", Vector3(_base_scale, _base_scale, _base_scale), 0.16)


# ---------------------------------------------------------------------------
# Bot AI — deterministic, seeded. Wanders inside the platform, swings on a
# cadence (and when an enemy is in front), dashes occasionally.
# ---------------------------------------------------------------------------
func _bot_tick(delta: float) -> void:
	_bot_swing_edge = false
	_bot_dash_edge = false
	var platform_r: float = main.platform_r() if main else 6.0

	_bot_wander_t -= delta
	if _bot_wander_t <= 0.0 or global_position.distance_to(_bot_target) < 0.8:
		_bot_wander_t = _bot_rng.randf_range(0.9, 2.1)
		var ang := _bot_rng.randf_range(0.0, TAU)
		var rad := _bot_rng.randf_range(0.0, platform_r * 0.8)
		_bot_target = Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)

	var to := _bot_target - global_position
	to.y = 0.0
	_bot_move = Vector2(to.x, to.z)
	if _bot_move.length() > 1.0:
		_bot_move = _bot_move.normalized()

	# swing on cadence, or when a live enemy is close & roughly ahead
	_bot_swing_t -= delta
	var enemy_near := _bot_enemy_ahead()
	if (_bot_swing_t <= 0.0 or enemy_near) and _swing_cd <= 0.0:
		_bot_swing_edge = true
		_bot_swing_t = _bot_rng.randf_range(0.6, 1.4)

	_bot_dash_t -= delta
	if _bot_dash_t <= 0.0 and _dash_cd <= 0.0:
		_bot_dash_edge = true
		_bot_dash_t = _bot_rng.randf_range(1.8, 3.6)


func _bot_enemy_ahead() -> bool:
	if main == null:
		return false
	var fwd := Vector3(_bot_move.x, 0.0, _bot_move.y)
	if fwd.length() < 0.1:
		fwd = _forward()
	fwd = fwd.normalized()
	for other in main.fighters:
		if other == self or not other.alive:
			continue
		var opos: Vector3 = other.global_position
		var d: Vector3 = opos - global_position
		d.y = 0.0
		if d.length() <= SWING_RANGE + 0.3 and fwd.angle_to(d) <= SWING_HALF_ARC:
			return true
	return false
