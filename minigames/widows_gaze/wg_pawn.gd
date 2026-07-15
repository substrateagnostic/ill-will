class_name WGPawn
extends CharacterBody3D
## One mourner in THE WIDOW'S GAZE — a KayKit body that creeps down the parlor,
## grabs a relic off the wake, hauls it back to its memorial chest, and SHOVES
## rivals into the Widow's line of sight.
##
## Driven MANUALLY by the controller (widows_gaze.gd) via tick_movement(delta) —
## NOT its own _physics_process — so the whole parlor updates in one deterministic
## order each physics step (ticked in index order). All game decisions (grab /
## shove / catch) live in the controller; this node owns only body state,
## acceleration-based movement (the STOP is the skill), timers, and juice.
##
## THE STOP-WINDOW: movement uses real accel/friction, so releasing the stick
## costs a fraction of a second to bleed off. horizontal_speed() is what the
## controller reads to decide a catch — a controlled, anticipated stop lands the
## body under STOP_EPSILON before the whip-turn completes; a greedy over-run does
## not. That gap IS the game.

const MOVE_SPEED := 5.0
const ACCEL := 42.0                    # brisk to full speed (responsive)
const FRICTION := 20.0                 # coast-down when the stick is released
const STOP_EPSILON := 0.7              # horiz speed under this = still (safe under the gaze)
const STUMBLE_TIME := 0.4              # involuntary movement after a shove (spec)
const SHOVE_KNOCK := 8.5
const SHOVE_LOCK := 0.26               # rooted while a shove swing animates
const SHOVE_CD := 2.5                  # cooldown ring (spec ~2.5s)
const CAUGHT_TIME := 1.2               # dead-time-free respawn at the rope (spec)
const YEET_TIME := 0.5                 # the fling arc back to the rope
const GRAVITY := 24.0
const TURN_LERP := 16.0
const KNOCK_DECAY := 22.0
const MODEL_YAW_OFFSET := 0.0          # KayKit adventurers face +Z; atan2(x,z) needs no flip

var player_index := 0
var color := Color.WHITE
var char_path := ""

var yaw := 0.0
var caught_t := 0.0                    # >0 = flung/respawning (uncontrollable)
var stumble_t := 0.0                   # >0 = shoved, moving against my will
var shove_lock := 0.0                  # rooted mid-swing
var shove_cd := 0.0                    # shove cooldown (ring)
var immune_t := 0.0                    # spawn/respawn grace (not catchable)
var shove_by := -1                     # who shoved me last (murder attribution)
var carry_mult := 1.0                  # set by controller from the held relic tier
var carrying := false
var grab_hold := 0.0                   # controller-managed grab channel progress
var grab_target := -1                  # relic index being channeled
var _move_intent := Vector2.ZERO
var _knock := Vector3.ZERO
var _yeet_from := Vector3.ZERO
var _yeet_to := Vector3.ZERO
var _yeet_t := 0.0

var _pivot: Node3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _carry_glow: OmniLight3D
var _grab_ring: MeshInstance3D
var _grab_mat: StandardMaterial3D
var _stun_stars: CPUParticles3D
var _shove_ring: CooldownRing          # THE COOLDOWN RING for the shove
var _squash_tw: Tween                  # owns the HIT KIT windup/pop scale (one at a time)
var _cur_anim := ""
var _anim_hold := 0.0
var _pose_hold := 0.0                  # a bot's funny freeze pose owns the body this long
var _base_scale := 0.92
var _base_ring_color := Color.WHITE


func setup(index: int, col: Color, char_scene: String) -> void:
	player_index = index
	color = col
	char_path = char_scene
	_base_ring_color = col
	collision_layer = 2
	collision_mask = 1 | 2
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.4
	cap.shape = shape
	cap.position.y = 0.7
	add_child(cap)

	_pivot = Node3D.new()
	add_child(_pivot)
	var ps: PackedScene = load(char_path)
	if ps != null:
		var inst := ps.instantiate()
		inst.scale = Vector3(_base_scale, _base_scale, _base_scale)
		_pivot.add_child(inst)
		_anim = inst.find_child("AnimationPlayer", true, false)
		for a in ["Idle", "Running_A"]:
			if _anim and _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	# identity feet ring (house style: color = player)
	_ring = MeshInstance3D.new()
	var rmesh := CylinderMesh.new()
	rmesh.top_radius = 0.52
	rmesh.bottom_radius = 0.58
	rmesh.height = 0.05
	_ring.mesh = rmesh
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = col
	_ring_mat.emission_enabled = true
	_ring_mat.emission = col
	_ring_mat.emission_energy_multiplier = 0.5
	_ring_mat.roughness = 0.5
	_ring.material_override = _ring_mat
	_ring.position.y = 0.04
	add_child(_ring)

	# soft carry glow (lit only while hauling a relic)
	_carry_glow = OmniLight3D.new()
	_carry_glow.light_color = Color(1.0, 0.85, 0.55)
	_carry_glow.light_energy = 0.0
	_carry_glow.omni_range = 4.5
	_carry_glow.position.y = 1.4
	add_child(_carry_glow)

	# grab-progress ring (fills while channeling a relic pickup)
	_grab_ring = MeshInstance3D.new()
	var gm := TorusMesh.new()
	gm.inner_radius = 0.62
	gm.outer_radius = 0.78
	_grab_ring.mesh = gm
	_grab_mat = StandardMaterial3D.new()
	_grab_mat.albedo_color = Color(1, 1, 1, 0.95)
	_grab_mat.emission_enabled = true
	_grab_mat.emission = Color(0.95, 0.9, 0.75)
	_grab_mat.emission_energy_multiplier = 2.0
	_grab_ring.material_override = _grab_mat
	_grab_ring.position.y = 1.5
	_grab_ring.visible = false
	add_child(_grab_ring)

	# stun stars (spin while flung / caught)
	_stun_stars = CPUParticles3D.new()
	_stun_stars.emitting = false
	_stun_stars.amount = 10
	_stun_stars.lifetime = 0.7
	_stun_stars.local_coords = true
	_stun_stars.spread = 180.0
	_stun_stars.gravity = Vector3.ZERO
	_stun_stars.initial_velocity_min = 0.8
	_stun_stars.initial_velocity_max = 1.2
	_stun_stars.position.y = 1.9
	var stm := SphereMesh.new()
	stm.radius = 0.06
	stm.height = 0.12
	_stun_stars.mesh = stm
	var stmat := StandardMaterial3D.new()
	stmat.albedo_color = Color(0.75, 0.85, 1.0)
	stmat.emission_enabled = true
	stmat.emission = Color(0.6, 0.8, 1.0)
	_stun_stars.mesh.surface_set_material(0, stmat)
	add_child(_stun_stars)

	# shove cooldown ring — flat, player-colored, concentric just outside identity
	_shove_ring = CooldownRing.new()
	add_child(_shove_ring)
	_shove_ring.setup(color, 0.70, 0.60, 0.05, 0.9)

	_play("Idle")


func reset_for_round(pos: Vector3, face_yaw: float) -> void:
	global_position = pos
	yaw = face_yaw
	caught_t = 0.0
	stumble_t = 0.0
	shove_lock = 0.0
	shove_cd = 0.0
	immune_t = 0.6
	shove_by = -1
	carry_mult = 1.0
	carrying = false
	grab_hold = 0.0
	grab_target = -1
	_move_intent = Vector2.ZERO
	_knock = Vector3.ZERO
	_yeet_t = 0.0
	velocity = Vector3.ZERO
	_anim_hold = 0.0
	_pose_hold = 0.0
	set_carry_visual(false)
	_grab_ring.visible = false
	_stun_stars.emitting = false
	_pivot.rotation = Vector3.ZERO
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_pivot.scale = Vector3.ONE
	if _shove_ring:
		_shove_ring.tick(0.0, 1.0, false, false)
	_cur_anim = ""
	_play("Idle")


## Free to steer? Not while flung, stumbling, or mid-swing.
func can_control() -> bool:
	return caught_t <= 0.0 and stumble_t <= 0.0 and shove_lock <= 0.0


## Can the gaze take me? A flung/respawning body or a grace-immune one is safe.
func can_be_caught() -> bool:
	return caught_t <= 0.0 and immune_t <= 0.0


func is_caught() -> bool:
	return caught_t > 0.0


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func set_move_intent(m: Vector2) -> void:
	_move_intent = m


func set_carry_visual(on: bool, bulky := false) -> void:
	carrying = on
	_carry_glow.light_energy = (1.7 if on else 0.0)
	if on:
		_ring_mat.emission_energy_multiplier = 1.6
		_carry_glow.light_color = Color(0.95, 0.55, 0.75) if bulky else Color(1.0, 0.85, 0.55)
	else:
		_ring_mat.emission_energy_multiplier = 0.5


func show_grab_progress(frac: float) -> void:
	if frac <= 0.0:
		_grab_ring.visible = false
		return
	_grab_ring.visible = true
	var f := clampf(frac, 0.06, 1.0)
	_grab_ring.scale = Vector3(f, 1.0, f)
	_grab_mat.emission_energy_multiplier = 1.2 + 2.4 * f


## Fires a shove swing. Rooted briefly; HIT KIT windup coils before the strike.
func do_shove_swing() -> void:
	shove_lock = SHOVE_LOCK
	shove_cd = SHOVE_CD
	grab_hold = 0.0
	grab_target = -1
	_one_shot("Unarmed_Melee_Attack_Punch_A", SHOVE_LOCK)
	windup_coil()
	Sfx.play("putt", -3.0)


## HIT KIT §B1 Phase 1 — WINDUP. The body coils then springs over ~0.16s.
func windup_coil() -> void:
	if _pivot == null:
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_squash_tw = create_tween()
	_squash_tw.tween_property(_pivot, "scale", Vector3(1.08, 0.90, 1.08), 0.06)
	_squash_tw.tween_property(_pivot, "scale", Vector3.ONE, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## HIT KIT §B1 Phase 2 — victim impact pop: flatten wide, snap back over 0.16s.
func flash_pop() -> void:
	if _pivot == null:
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_pivot.scale = Vector3(1.22, 0.85, 1.22)
	_squash_tw = create_tween()
	_squash_tw.tween_property(_pivot, "scale", Vector3.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## I've been shoved: knocked in `dir`, then STUMBLE_TIME of involuntary drift.
func get_shoved(dir: Vector3, by: int) -> void:
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		d = _forward()
	d = d.normalized()
	_knock = d * SHOVE_KNOCK
	stumble_t = STUMBLE_TIME
	shove_by = by
	yaw = atan2(d.x, d.z)
	grab_hold = 0.0
	grab_target = -1
	flash_pop()
	_one_shot("Hit_A", STUMBLE_TIME)


## THE WIDOW TOOK ME. Flung back to the rope; uncontrollable for CAUGHT_TIME.
func get_caught(rope_pos: Vector3) -> void:
	caught_t = CAUGHT_TIME
	stumble_t = 0.0
	shove_lock = 0.0
	grab_hold = 0.0
	grab_target = -1
	_knock = Vector3.ZERO
	_move_intent = Vector2.ZERO
	set_carry_visual(false)
	_yeet_from = global_position
	_yeet_to = rope_pos
	_yeet_t = 0.0
	_stun_stars.emitting = true
	if _anim and _anim.has_animation("Death_A"):
		_one_shot("Death_A", YEET_TIME)
	else:
		_one_shot("Hit_A", YEET_TIME)


func cheer() -> void:
	_one_shot("Cheer", 3.0)


## A bot freezing mid-stride in a funny pose (spec flavor). Holds a random clip.
func funny_pose(clip: String, hold: float) -> void:
	_pose_hold = hold
	_one_shot(clip, hold)


func is_posing() -> bool:
	return _pose_hold > 0.0


## Main per-physics-tick movement. Controller sets intents/actions first.
func tick_movement(delta: float) -> void:
	immune_t = maxf(0.0, immune_t - delta)
	shove_lock = maxf(0.0, shove_lock - delta)
	shove_cd = maxf(0.0, shove_cd - delta)
	stumble_t = maxf(0.0, stumble_t - delta)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_pose_hold = maxf(0.0, _pose_hold - delta)
	if stumble_t <= 0.0 and caught_t <= 0.0:
		# the murder-credit clears once the stumble that carried me ends
		if shove_by >= 0 and _knock.length() < 0.05:
			shove_by = -1

	# --- caught: the fling arc back to the rope, then a beat of stun ---
	if caught_t > 0.0:
		caught_t = maxf(0.0, caught_t - delta)
		if _yeet_t < YEET_TIME:
			_yeet_t = minf(YEET_TIME, _yeet_t + delta)
			var k := _yeet_t / YEET_TIME
			var flat := _yeet_from.lerp(_yeet_to, k)
			flat.y = _yeet_from.y + sin(k * PI) * 2.2   # arc up and over
			global_position = flat
		velocity = Vector3.ZERO
		if caught_t <= 0.0:
			immune_t = 0.5
			_stun_stars.emitting = false
			_pivot.rotation = Vector3.ZERO
			if _squash_tw and _squash_tw.is_valid():
				_squash_tw.kill()
			_pivot.scale = Vector3.ONE
		_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
		return

	var moving := false
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if stumble_t > 0.0 or shove_lock > 0.0 or _pose_hold > 0.0:
		# involuntary / rooted: bleed toward zero (the shove-knock does the moving)
		horiz = horiz.move_toward(Vector3.ZERO, FRICTION * delta)
	else:
		var target := Vector3(_move_intent.x, 0.0, _move_intent.y)
		if target.length() > 1.0:
			target = target.normalized()
		target *= MOVE_SPEED * carry_mult
		var rate := ACCEL if target.length() > 0.05 else FRICTION
		horiz = horiz.move_toward(target, rate * delta)
		if target.length() > 0.05:
			yaw = lerp_angle(yaw, atan2(target.x, target.z), 1.0 - exp(-TURN_LERP * delta))

	horiz += _knock
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)

	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if horizontal_speed() > STOP_EPSILON * 0.5:
		moving = true
	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
	_update_locomotion_anim(moving)


## ONLINE mirror pose (render-only). Client drives every pawn from 20 Hz facts.
func net_pose(delta: float, tp: Vector3, tyaw: float, moving: bool, caught: bool, held: bool) -> void:
	global_position = global_position.lerp(tp, 1.0 - exp(-14.0 * delta))
	yaw = lerp_angle(yaw, tyaw, 1.0 - exp(-14.0 * delta))
	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
	_anim_hold = maxf(0.0, _anim_hold - delta)
	shove_cd = maxf(0.0, shove_cd - delta)
	caught_t = 0.05 if caught else 0.0
	if _stun_stars.emitting != caught:
		_stun_stars.emitting = caught
	if carrying != held:
		set_carry_visual(held)
	_update_locomotion_anim(moving and not caught)


func _update_locomotion_anim(moving: bool) -> void:
	if _anim_hold > 0.0:
		return
	if caught_t > 0.0:
		return
	_play("Running_A" if moving else "Idle")


func _one_shot(anim_name: String, hold: float) -> void:
	if _anim and _anim.has_animation(anim_name):
		_cur_anim = anim_name
		_anim.play(anim_name, 0.08)
		_anim_hold = hold


func _play(anim_name: String) -> void:
	if _anim == null or _cur_anim == anim_name:
		return
	if not _anim.has_animation(anim_name):
		anim_name = "Idle"
		if _cur_anim == anim_name or not _anim.has_animation(anim_name):
			return
	_cur_anim = anim_name
	_anim.play(anim_name, 0.15)


func _forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func tick_visual(delta: float, t: float) -> void:
	if _grab_ring.visible:
		_grab_ring.rotation.y += delta * 5.0
	if carrying:
		_carry_glow.light_energy = 1.5 + 0.4 * sin(t * 6.0)
	# shove cooldown ring: empty at fire (shove_cd = SHOVE_CD) -> full = READY
	if _shove_ring:
		var frac := clampf(1.0 - shove_cd / SHOVE_CD, 0.0, 1.0)
		var reduced := not bool(PartySetup.pref("screen_shake", true))
		_shove_ring.tick(delta, frac, true, reduced)
