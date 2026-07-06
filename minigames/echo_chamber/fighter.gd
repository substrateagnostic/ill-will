class_name EchoFighter
extends CharacterBody3D
## A live brawler (player- or bot-controlled). Driven MANUALLY by the main
## controller via tick(delta) — NOT its own _physics_process — so the whole
## arena updates in one deterministic order each physics step:
##   1. controller ticks every fighter (they read input + move_and_slide)
##   2. controller samples the recorder from post-move state
##   3. controller replays ghosts against those fresh positions
## This ordering is what makes recording -> replay drift-free.
##
## v1.1 combat triangle inside the 2-button PlayerInput budget:
##   A tap            -> LIGHT (Chop, 1 dmg, fast)
##   A hold >=0.35s   -> charge, release -> HEAVY (2H Slice, 2 dmg, wide+reach)
##   B tap            -> DASH (i-frames, unchanged)
##   B hold >0.15s    -> PARRY (Blocking; negates a hit, staggers live
##                       attacker, opens a riposte window)
## heavy beats no-parry; parry beats heavy (riposte); fast light beats parry
## spam (parry has a 1.0s cooldown and a 1.2s max hold).

# ---- shared animation-state ids (ghost.gd mirrors these) ----
const ST_IDLE := 0
const ST_RUN := 1
const ST_SWING := 2       # LIGHT (Chop)
const ST_DASH := 3
const ST_HIT := 4
const ST_DEAD := 5
const ST_HEAVY := 6       # HEAVY (2H Slice)
const ST_PARRY := 7       # Blocking
const ST_CHARGE := 8      # heavy windup (readable: scale + red tint)

# ---- feel constants (see spec "Feel targets") ----
const MOVE_SPEED := 5.0
const DASH_SPEED := 11.0
const DASH_TIME := 0.25
const DASH_CD := 1.2
const SWING_CD := 0.5
const SWING_STRIKE_T := 0.04         # hitbox goes live <50ms after release
const SWING_LOCK_T := 0.34           # rooted while the light animates
const SWING_RANGE := 1.9
const SWING_HALF_ARC := deg_to_rad(60.0)   # 120deg total cone
const KNOCKBACK := 7.5
const HP_MAX := 3
const GRAVITY := 24.0
const SPAWN_PROTECT := 1.0
const STAGGER_T := 0.18
const TURN_LERP := 18.0
const MODEL_YAW_OFFSET := 0.0         # KayKit adventurers face +Z; atan2(x,z) needs no flip (they moonwalked with PI)

# ---- v1.1 heavy / parry / riposte ----
const HEAVY_CHARGE_T := 0.35          # hold A this long to arm a heavy
const HEAVY_STRIKE_T := 0.18          # heavy hitbox lands later (it's slow)
const HEAVY_LOCK_T := 0.5             # rooted while the heavy animates
const HEAVY_CD := 0.9
const HEAVY_DMG := 2
const HEAVY_KNOCKBACK := 14.0
const HEAVY_RANGE := SWING_RANGE + 0.4
const HEAVY_HALF_ARC := deg_to_rad(75.0)   # 150deg total cone

const PARRY_THRESHOLD := 0.15         # hold B past this to parry (else dash)
const PARRY_MAX := 1.2                # anti-turtle: forced release
const PARRY_CD := 1.0                 # anti-turtle: cooldown after release
const RIPOSTE_WINDOW := 0.8           # after a parry, your next light bonuses
const CHARGE_SCALE := 1.06

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
var _fire_val := 0                    # 0 none / 1 light / 2 heavy; recorder eats it
var _heavy_cd := 0.0
var _heavy_t := -1.0
var _heavy_did_strike := false
var _charging := false                # holding A past the charge threshold
var _dash_cd := 0.0
var _dash_t := -1.0
var _dash_dir := Vector3.FORWARD
var _iframe := 0.0
var _stagger := 0.0
var _parrying := false
var _parry_hold := 0.0
var _parry_cd := 0.0
var _riposte_t := 0.0                 # >0 => next light is a riposte
var _riposte_swing := false           # this light is a riposte (bonus dmg+pt)

# per-tick intents (players derive from buttons; bots set directly)
var _ev_light := false
var _ev_heavy := false
var _ev_dash := false
var _want_parry := false

# player button hold tracking
var _a_prev := false
var _a_active := false
var _a_hold := 0.0
var _b_prev := false
var _b_active := false
var _b_hold := 0.0

var _pivot: Node3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _cur_anim := ""
var _base_scale := 1.0
var _mesh_instances: Array = []
var _charge_overlay: StandardMaterial3D
var _charge_visual := false

# ---- bot state (all seeded, no wall-clock) ----
var _bot_rng := RandomNumberGenerator.new()
var _bot_target := Vector3.ZERO
var _bot_wander_t := 0.0
var _bot_swing_t := 0.0
var _bot_heavy_t := 0.0
var _bot_dash_t := 0.0
var _bot_parry_t := 0.0
var _bot_parry_hold := 0.0
var _bot_charge_hold := 0.0
var _bot_riposte_pending := false
var _bot_move := Vector2.ZERO


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
	for a in ["Idle", "Running_A", "Blocking"]:
		if _anim and _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_collect_meshes(inst)

	# red charge overlay (readable heavy windup, per v1.1 note)
	_charge_overlay = StandardMaterial3D.new()
	_charge_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_charge_overlay.albedo_color = Color(1.0, 0.28, 0.16, 0.42)
	_charge_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_charge_overlay.emission_enabled = true
	_charge_overlay.emission = Color(1.0, 0.22, 0.1)
	_charge_overlay.emission_energy_multiplier = 0.6

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


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_instances.append(node)
	for c in node.get_children():
		_collect_meshes(c)


func tick(delta: float) -> void:
	if not alive:
		return
	_swing_cd = maxf(0.0, _swing_cd - delta)
	_heavy_cd = maxf(0.0, _heavy_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_parry_cd = maxf(0.0, _parry_cd - delta)
	_iframe = maxf(0.0, _iframe - delta)
	_riposte_t = maxf(0.0, _riposte_t - delta)
	if _stagger > 0.0:
		_stagger -= delta

	# 1. gather intents
	_ev_light = false
	_ev_heavy = false
	_ev_dash = false
	_want_parry = false
	var mv := Vector2.ZERO
	if is_bot:
		_bot_tick(delta)
		mv = _bot_move
	else:
		mv = PlayerInput.get_move(player_index)
		_resolve_player_buttons(delta)

	# 2. parry stance start/stop
	if _parrying:
		_parry_hold += delta
		if not _want_parry or _parry_hold >= PARRY_MAX:
			_end_parry()
	elif _want_parry and _parry_cd <= 0.0 and not _busy():
		_start_parry()

	# 3. action initiation (never while parrying)
	if not _parrying:
		if _ev_dash and _dash_cd <= 0.0 and not _busy():
			_start_dash(mv)
		elif _ev_heavy and _heavy_cd <= 0.0 and not _busy():
			_start_heavy()
		elif _ev_light and _swing_cd <= 0.0 and not _busy():
			_start_light()

	# 4. advance an active LIGHT; fire its arc once, early
	if _swing_t >= 0.0:
		_swing_t += delta
		if not _swing_did_strike and _swing_t >= SWING_STRIKE_T:
			_swing_did_strike = true
			_fire_val = 1
			Sfx.play("putt", -5.0)
			if main:
				main.resolve_swing(global_position, yaw, player_index, false, self, 0, false, _riposte_swing)
			_riposte_swing = false
		if _swing_t >= SWING_LOCK_T:
			_swing_t = -1.0

	# 5. advance an active HEAVY; fires later, hits harder, wider
	if _heavy_t >= 0.0:
		_heavy_t += delta
		if not _heavy_did_strike and _heavy_t >= HEAVY_STRIKE_T:
			_heavy_did_strike = true
			_fire_val = 2
			Sfx.play("bumper", -2.0)
			if main:
				main.resolve_swing(global_position, yaw, player_index, false, self, 0, true, false)
		if _heavy_t >= HEAVY_LOCK_T:
			_heavy_t = -1.0

	# 6. horizontal movement (rooted while committed to an action)
	var horiz := Vector3.ZERO
	if _dash_t >= 0.0:
		_dash_t += delta
		horiz = _dash_dir * DASH_SPEED
		if _dash_t >= DASH_TIME:
			_dash_t = -1.0
			state = ST_IDLE
	elif _busy():
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
	_set_charge_visual(_charging)
	_apply_locomotion_anim()

	if global_position.y < -3.0 and alive and main:
		main.on_fall_death(player_index)


## True while committed to something that should root the fighter and block
## new action starts.
func _busy() -> bool:
	return _swing_t >= 0.0 or _heavy_t >= 0.0 or _dash_t >= 0.0 \
		or _charging or _parrying or _stagger > 0.0


func _apply_locomotion_anim() -> void:
	# one-shots (light/heavy/dash/hit) are launched by their starters; charge
	# and parry hold their own anim. Only resume idle/run locomotion here so we
	# don't stomp an in-progress action.
	if state == ST_RUN:
		_play("Running_A")
	elif state == ST_IDLE:
		_play("Idle")


# ---------------------------------------------------------------------------
# Player button -> intent translation (tap vs hold on a 2-button budget).
# A: tap=light, hold>=0.35s then release=heavy (charge is readable).
# B: tap=dash, hold>0.15s=parry (release decides; dash fires on a short tap).
# ---------------------------------------------------------------------------
func _resolve_player_buttons(delta: float) -> void:
	var a_down := PlayerInput.is_down(player_index, "a")
	if a_down and not _a_prev:
		_a_active = true
		_a_hold = 0.0
	if _a_active and a_down:
		_a_hold += delta
		if _a_hold >= HEAVY_CHARGE_T and _heavy_cd <= 0.0 and not _charging and not _busy():
			_charging = true
			state = ST_CHARGE
	if _a_active and not a_down:
		_a_active = false
		if _charging:
			_charging = false
			_ev_heavy = true
		else:
			_ev_light = true   # short tap, or long hold that couldn't charge
	_a_prev = a_down

	var b_down := PlayerInput.is_down(player_index, "b")
	if b_down and not _b_prev:
		_b_active = true
		_b_hold = 0.0
	if _b_active and b_down:
		_b_hold += delta
		if _b_hold >= PARRY_THRESHOLD:
			_want_parry = true
	if _b_active and not b_down:
		_b_active = false
		if not _parrying and _b_hold < PARRY_THRESHOLD:
			_ev_dash = true
	_b_prev = b_down


## Mouse aim (KBM humans only): a light/heavy swing faces + fires toward the
## cursor instead of the walk-derived facing. We overwrite `yaw` at swing start —
## the fighter is _busy() for the whole swing so movement never touches yaw
## again, the arc (resolve_swing reads yaw), the model rotation, AND the 30Hz
## recorder (samples yaw) all consume this one honest value, so ghost replays
## stay drift-free. Bots / non-KBM / no-cursor keep their current yaw.
func _aim_yaw(fallback: float) -> float:
	if is_bot or main == null:
		return fallback
	var aim: Vector3 = PlayerInput.get_aim_dir(player_index, global_position, main.camera)
	if aim.length() > 0.05:
		return atan2(aim.x, aim.z)
	return fallback


func _start_light() -> void:
	yaw = _aim_yaw(yaw)
	_swing_t = 0.0
	_swing_cd = SWING_CD
	_swing_did_strike = false
	_riposte_swing = _riposte_t > 0.0
	if _riposte_swing:
		_riposte_t = 0.0
	state = ST_SWING
	_play("1H_Melee_Attack_Chop", false)


func _start_heavy() -> void:
	yaw = _aim_yaw(yaw)
	_heavy_t = 0.0
	_heavy_cd = HEAVY_CD
	_heavy_did_strike = false
	_charging = false
	_set_charge_visual(false)
	state = ST_HEAVY
	_play("2H_Melee_Attack_Slice", false)


func _start_parry() -> void:
	_parrying = true
	_parry_hold = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_knockback = Vector3.ZERO
	state = ST_PARRY
	_play("Blocking")
	Sfx.play("bounce", -12.0)


func _end_parry() -> void:
	_parrying = false
	_parry_cd = PARRY_CD
	state = ST_IDLE


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


## Returns "" (missed/immune), "hit", "kill", or "parry".
func take_hit(dmg: int, from_pos: Vector3, _attacker: int, is_heavy := false) -> String:
	if not alive or _iframe > 0.0:
		return ""
	# PARRY: negate the hit, open a riposte window. Attacker stagger + logging
	# is the controller's job (it knows if the attacker is live or a ghost).
	if _parrying:
		_riposte_t = RIPOSTE_WINDOW
		if is_bot:
			_bot_riposte_pending = true
			_bot_parry_hold = 0.0
		_flash_pop()
		Sfx.play("confirm", -1.0)
		return "parry"
	hp -= dmg
	var kdir := global_position - from_pos
	kdir.y = 0.0
	if kdir.length() < 0.01:
		kdir = -_forward()
	_knockback = kdir.normalized() * (HEAVY_KNOCKBACK if is_heavy else KNOCKBACK)
	# getting hit interrupts your own windup/attack (fast light beats a charge)
	_charging = false
	_swing_t = -1.0
	_heavy_t = -1.0
	_set_charge_visual(false)
	if hp <= 0:
		kill()
		return "kill"
	_stagger = STAGGER_T
	state = ST_HIT
	_play("Hit_A", false)
	Sfx.play("splat", -3.0)
	_flash_pop()
	return "hit"


## Punished for swinging into a parry: rooted, animation-locked (attacker only).
func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)
	_charging = false
	_swing_t = -1.0
	_heavy_t = -1.0
	_knockback = Vector3.ZERO
	_set_charge_visual(false)
	state = ST_HIT
	_play("Hit_A", false)


func kill() -> void:
	if not alive:
		return
	alive = false
	hp = 0
	state = ST_DEAD
	_knockback = Vector3.ZERO
	velocity = Vector3.ZERO
	_swing_t = -1.0
	_heavy_t = -1.0
	_dash_t = -1.0
	_charging = false
	_parrying = false
	_set_charge_visual(false)
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
	_heavy_t = -1.0
	_dash_t = -1.0
	_swing_cd = 0.0
	_heavy_cd = 0.0
	_dash_cd = 0.0
	_parrying = false
	_parry_cd = 0.0
	_charging = false
	_riposte_t = 0.0
	_riposte_swing = false
	_bot_riposte_pending = false
	_bot_parry_hold = 0.0
	_bot_charge_hold = 0.0
	_set_charge_visual(false)
	state = ST_IDLE
	_play("Idle")


func consume_fire() -> int:
	var f := _fire_val
	_fire_val = 0
	return f


## Verification hook (--aimprobe): fire a light swing straight through the real
## aim path (_start_light -> _aim_yaw), so the probe proves the cursor overrides
## the walk-facing without reaching into internals.
func debug_probe_light() -> void:
	_start_light()


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


func _set_charge_visual(active: bool) -> void:
	if _charge_visual == active:
		return
	_charge_visual = active
	if _pivot:
		var s := _base_scale * (CHARGE_SCALE if active else 1.0)
		_pivot.scale = Vector3(s, s, s)
	for mi in _mesh_instances:
		(mi as MeshInstance3D).material_overlay = _charge_overlay if active else null
	if active and main and main.has_method("notify_charge"):
		main.notify_charge()


func _flash_pop() -> void:
	if _pivot == null:
		return
	var tw := create_tween()
	_pivot.scale = Vector3(_base_scale * 1.22, _base_scale * 0.85, _base_scale * 1.22)
	tw.tween_property(_pivot, "scale", Vector3(_base_scale, _base_scale, _base_scale), 0.16)


# ---------------------------------------------------------------------------
# Bot AI — deterministic, seeded. Wanders inside the platform, and exercises
# EVERY verb so the evidence (and the ghosts of past rounds) show them:
# charges heavies, holds parries when threatened, ripostes after a parry,
# throws lights on a cadence, dashes occasionally.
# ---------------------------------------------------------------------------
func _bot_tick(delta: float) -> void:
	var platform_r_v: float = main.platform_r() if main else 6.0

	# charge-a-heavy in progress: root, show windup, release when timer expires
	if _bot_charge_hold > 0.0:
		_bot_charge_hold -= delta
		_bot_move = Vector2.ZERO
		if _stagger > 0.0:
			_bot_charge_hold = 0.0
			_charging = false
			return
		if _heavy_cd <= 0.0 and _swing_t < 0.0 and _heavy_t < 0.0 and _dash_t < 0.0 and not _parrying:
			_charging = true
			state = ST_CHARGE
		if _bot_charge_hold <= 0.0:
			_charging = false
			_ev_heavy = true
		return

	# hold a parry stance
	if _bot_parry_hold > 0.0:
		_bot_parry_hold -= delta
		_bot_move = Vector2.ZERO
		_want_parry = true
		return

	# riposte immediately after a successful parry
	if _bot_riposte_pending:
		_bot_riposte_pending = false
		_bot_move = Vector2.ZERO
		if _swing_cd <= 0.0:
			_ev_light = true
		return

	# wander toward a roaming target (ring, not center, for ghost readability)
	_bot_wander_t -= delta
	if _bot_wander_t <= 0.0 or global_position.distance_to(_bot_target) < 0.8:
		_bot_wander_t = _bot_rng.randf_range(0.9, 2.1)
		var ang := _bot_rng.randf_range(0.0, TAU)
		var rad := platform_r_v * _bot_rng.randf_range(0.35, 0.9)
		_bot_target = Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
	var to := _bot_target - global_position
	to.y = 0.0
	_bot_move = Vector2(to.x, to.z)
	if _bot_move.length() > 1.0:
		_bot_move = _bot_move.normalized()

	var enemy_near := _bot_enemy_ahead()
	var threat := _bot_enemy_threat()

	# defensive parry: when a live attacker is winding up on us, or a gamble
	# near an enemy (also catches ghost swings). Sets up the riposte.
	_bot_parry_t -= delta
	if _parry_cd <= 0.0 and _bot_parry_t <= 0.0 and (threat or (enemy_near and _bot_rng.randf() < 0.3)):
		_bot_parry_hold = _bot_rng.randf_range(0.4, 0.7)
		_bot_parry_t = _bot_rng.randf_range(0.8, 2.0)
		_want_parry = true
		_bot_move = Vector2.ZERO
		return

	# heavy: charge then release, when an enemy is roughly ahead
	_bot_heavy_t -= delta
	if _heavy_cd <= 0.0 and _bot_heavy_t <= 0.0 and enemy_near and _bot_rng.randf() < 0.5:
		_bot_charge_hold = HEAVY_CHARGE_T + _bot_rng.randf_range(0.15, 0.5)
		_bot_heavy_t = _bot_rng.randf_range(1.6, 3.2)
		return

	# light on cadence, or when a live enemy is close & ahead
	_bot_swing_t -= delta
	if (_bot_swing_t <= 0.0 or enemy_near) and _swing_cd <= 0.0:
		_ev_light = true
		_bot_swing_t = _bot_rng.randf_range(0.6, 1.4)

	# dash occasionally
	_bot_dash_t -= delta
	if _bot_dash_t <= 0.0 and _dash_cd <= 0.0:
		_ev_dash = true
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


## A live enemy who is mid-swing/heavy/charge, close, and facing us — the
## thing a parry is FOR.
func _bot_enemy_threat() -> bool:
	if main == null:
		return false
	for other in main.fighters:
		if other == self or not other.alive:
			continue
		var st: int = other.state
		if st != ST_SWING and st != ST_HEAVY and st != ST_CHARGE:
			continue
		var d: Vector3 = other.global_position - global_position
		d.y = 0.0
		if d.length() > SWING_RANGE + 0.7:
			continue
		var ofwd := Vector3(sin(other.yaw), 0.0, cos(other.yaw))
		if ofwd.angle_to(-d) <= deg_to_rad(80.0):
			return true
	return false
