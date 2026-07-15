class_name GreedPlayer
extends CharacterBody3D
## One player in GREED INC. — a KayKit body that runs, grabs the pot, carries
## it (slow + glowing + leaking coins), tackles the carrier, and dashes.
##
## Driven MANUALLY by the controller (greed.gd) via tick_movement(delta) — NOT
## its own _physics_process — so the whole vault updates in one deterministic
## order each physics step (ticked in index order). All game decisions (grab /
## tackle / bank) live in the controller; this node owns only body state,
## movement, timers, and the carrier's glow + coin-leak visuals.

const MOVE_SPEED := 5.2
const CARRY_SPEED_MULT := 0.8          # -20% while carrying (spec)
const DASH_SPEED := 12.0
const DASH_TIME := 0.22
const DASH_CD := 1.4
const DASH_IFRAME := 0.2               # i-frames 0.2s (spec)
const CARRY_DASH_MULT := 0.6           # a burdened dash is a clumsy lurch (priced escape)
const GRAVITY := 24.0
const TURN_LERP := 16.0
const TACKLE_LOCK := 0.28              # rooted while a tackle swing animates
const STUN_TIME := 1.0                 # stunned 1s after being dropped (spec)
const KNOCK_DECAY := 26.0
const MODEL_YAW_OFFSET := 0.0          # KayKit adventurers face +Z; atan2(x,z) needs no flip

# ---- EXPRESSIVE HOP (director's ruling, docs/design/16-jump-and-visibility.md) ----
# Cosmetic-only bunny-hop, self-contained (reads PlayerInput "jump" directly,
# like this file already reads nothing else — all its other input rides
# greed.gd's _input_for() dict; jump is the one exception, kept local since it
# doesn't touch any shared gameplay state). Refused while is_carrier (THIS is
# the anthology's "while-carrying" game the ruling calls out by name), mid-
# tackle-swing, mid-dash, mid-stun, or mid one-shot anim (cheer/etc). The
# tackle range check is Y-ignorant by construction (_flat_dist, greed.gd:882-
# 883, only ever reads x/z) so a hop can neither dodge nor land a tackle any
# differently than being grounded — this refusal is about animation
# cleanliness, not balance.
const HOP_VY := 3.0
const HOP_GRAVITY := 15.0              # softer than combat GRAVITY (24.0): a floaty arc
const HOP_CD := 0.5
const HOP_START_ANIM_T := 0.12
const HOP_LAND_HOLD_T := 0.15
const HOP_SQUASH_T := 0.1

var player_index := 0
var color := Color.WHITE
var char_path := ""
var is_bot := false

var is_carrier := false
var yaw := 0.0
var stun_t := 0.0
var immune_t := 0.0                    # tackle immunity window (post-drop / spawn)
var iframe_t := 0.0                    # dash i-frames
var dash_t := -1.0
var dash_cd := 0.0
var _dash_dir := Vector3.FORWARD
var tackle_lock := 0.0
var grab_hold := 0.0                   # progress toward a 0.6s grab
var _move_intent := Vector2.ZERO
var _knock := Vector3.ZERO

# EXPRESSIVE HOP state (cosmetic only — never read by tackle/grab resolution)
var _hopping := false
var _hop_cd := 0.0
var _hop_anim_t := 0.0
var _hop_land_hold := 0.0
var _hop_intro_t := -1000.0            # bots: one hop shortly after round start
var _hop_after_win_t := -1000.0        # bots: one hop shortly after a bank (cheer())
var _hop_rng := RandomNumberGenerator.new()

var _pivot: Node3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _aura: MeshInstance3D
var _aura_mat: StandardMaterial3D
var _glow_light: OmniLight3D
var _leak: CPUParticles3D
var _grab_ring: MeshInstance3D
var _grab_mat: StandardMaterial3D
var _stun_stars: CPUParticles3D
var _dash_ring: CooldownRing          # THE COOLDOWN RING for the dash (feet-anchored)
var _squash_tw: Tween                 # owns the HIT KIT windup/pop scale (one at a time)
var _cur_anim := ""
var _anim_hold := 0.0                  # seconds a one-shot anim owns the body
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
		for a in ["Idle", "Running_A", "Jump_Idle"]:
			if _anim and _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	# identity ring on the ground (house style: color = player)
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

	# carrier aura (golden translucent halo, hidden until carrying)
	_aura = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.95
	sm.height = 1.9
	_aura.mesh = sm
	_aura_mat = StandardMaterial3D.new()
	_aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_mat.albedo_color = Color(1.0, 0.82, 0.2, 0.20)
	_aura.material_override = _aura_mat
	_aura.position.y = 1.0
	_aura.visible = false
	add_child(_aura)

	# carrier glow light
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(1.0, 0.78, 0.25)
	_glow_light.light_energy = 0.0
	_glow_light.omni_range = 5.5
	_glow_light.position.y = 1.2
	add_child(_glow_light)

	# coin-leak trail (emits while carrying)
	_leak = CPUParticles3D.new()
	_leak.emitting = false
	_leak.amount = 26
	_leak.lifetime = 0.9
	_leak.local_coords = false
	_leak.direction = Vector3(0, 1, 0)
	_leak.spread = 35.0
	_leak.gravity = Vector3(0, -9.0, 0)
	_leak.initial_velocity_min = 1.2
	_leak.initial_velocity_max = 2.6
	_leak.position.y = 1.0
	var lmesh := CylinderMesh.new()
	lmesh.top_radius = 0.09
	lmesh.bottom_radius = 0.09
	lmesh.height = 0.03
	_leak.mesh = lmesh
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.85, 0.2)
	lmat.metallic = 0.7
	lmat.roughness = 0.3
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.7, 0.1)
	lmat.emission_energy_multiplier = 0.7
	_leak.mesh.surface_set_material(0, lmat)
	add_child(_leak)

	# grab-progress ring (fills while holding A near the pot)
	_grab_ring = MeshInstance3D.new()
	var gm := TorusMesh.new()
	gm.inner_radius = 0.62
	gm.outer_radius = 0.78
	_grab_ring.mesh = gm
	_grab_mat = StandardMaterial3D.new()
	_grab_mat.albedo_color = Color(1, 1, 1, 0.95)
	_grab_mat.emission_enabled = true
	_grab_mat.emission = Color(1.0, 0.9, 0.4)
	_grab_mat.emission_energy_multiplier = 2.0
	_grab_ring.material_override = _grab_mat
	_grab_ring.position.y = 1.5
	_grab_ring.visible = false
	add_child(_grab_ring)

	# stun stars (spins while stunned)
	_stun_stars = CPUParticles3D.new()
	_stun_stars.emitting = false
	_stun_stars.amount = 10
	_stun_stars.lifetime = 0.7
	_stun_stars.local_coords = true
	_stun_stars.direction = Vector3(0, 0, 0)
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
	stmat.albedo_color = Color(1.0, 1.0, 0.5)
	stmat.emission_enabled = true
	stmat.emission = Color(1.0, 0.9, 0.3)
	_stun_stars.mesh.surface_set_material(0, stmat)
	add_child(_stun_stars)

	# dash cooldown ring — flat, player-colored, concentric just outside the
	# identity ring (identity outer 0.58); geometric fill = colorblind-safe.
	_dash_ring = CooldownRing.new()
	add_child(_dash_ring)
	_dash_ring.setup(color, 0.70, 0.60, 0.05, 0.9)

	_hop_rng.seed = player_index * 977 + 269
	_play("Idle")


func reset_for_round(pos: Vector3, face_yaw: float) -> void:
	global_position = pos
	yaw = face_yaw
	is_carrier = false
	stun_t = 0.0
	immune_t = 0.6
	iframe_t = 0.0
	dash_t = -1.0
	dash_cd = 0.0
	tackle_lock = 0.0
	grab_hold = 0.0
	_move_intent = Vector2.ZERO
	_knock = Vector3.ZERO
	velocity = Vector3.ZERO
	_anim_hold = 0.0
	_hopping = false
	_hop_cd = 0.0
	_hop_anim_t = 0.0
	_hop_land_hold = 0.0
	_hop_after_win_t = -1000.0
	_hop_intro_t = _hop_rng.randf_range(2.0, 6.0) if is_bot else -1000.0
	set_carrier(false)
	_grab_ring.visible = false
	_stun_stars.emitting = false
	_pivot.rotation = Vector3.ZERO
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_pivot.scale = Vector3.ONE
	if _dash_ring:
		_dash_ring.tick(0.0, 1.0, false, false)   # force-hide the cooldown ring
	_cur_anim = ""
	_play("Idle")


func can_act() -> bool:
	return stun_t <= 0.0


func can_be_tackled() -> bool:
	return iframe_t <= 0.0 and immune_t <= 0.0 and stun_t <= 0.0


func set_move_intent(m: Vector2) -> void:
	_move_intent = m


func try_dash() -> bool:
	if dash_cd > 0.0 or dash_t >= 0.0 or stun_t > 0.0 or tackle_lock > 0.0:
		return false
	var dir := Vector3(_move_intent.x, 0.0, _move_intent.y)
	if dir.length() < 0.1:
		dir = _forward()
	_dash_dir = dir.normalized()
	dash_t = 0.0
	dash_cd = DASH_CD
	iframe_t = maxf(iframe_t, DASH_IFRAME)
	yaw = atan2(_dash_dir.x, _dash_dir.z)
	_one_shot("Dodge_Forward", DASH_TIME + 0.05)
	Sfx.play("bounce", -6.0)
	return true


## Fires a tackle swing; returns true if the animation started (controller has
## already decided the hit lands). Rooted briefly.
func do_tackle_swing() -> void:
	tackle_lock = TACKLE_LOCK
	_one_shot("Unarmed_Melee_Attack_Punch_A", TACKLE_LOCK)
	windup_coil()                       # HIT KIT windup: coil before the strike lands
	Sfx.play("putt", -3.0)


## HIT KIT §B1 Phase 1 — WINDUP. The body coils (chunky crouch) then springs
## back over ~0.16s. Visual only; the tackle hitbox is decided by the controller.
func windup_coil() -> void:
	if _pivot == null:
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_squash_tw = create_tween()
	_squash_tw.tween_property(_pivot, "scale", Vector3(1.08, 0.90, 1.08), 0.06)
	_squash_tw.tween_property(_pivot, "scale", Vector3.ONE, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## HIT KIT §B1 Phase 2 — victim impact pop (copy of echo_chamber _flash_pop):
## flatten wide on impact, snap back over 0.16s. Reads as "hit hard".
func flash_pop() -> void:
	if _pivot == null:
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_pivot.scale = Vector3(1.22, 0.85, 1.22)
	_squash_tw = create_tween()
	_squash_tw.tween_property(_pivot, "scale", Vector3.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Mouse aim (KBM humans only): a tackle pounces toward the cursor. We face the
## aim and ride an existing knock impulse — the fighter is rooted by tackle_lock
## so the decaying _knock is the whole lunge, sliding the body toward the cursor
## for the ~0.28s the swing animates. Bots / non-KBM never call this, so their
## tackle (and the balance model) is byte-identical.
const TACKLE_LUNGE := 7.0
func lunge_toward(dir: Vector3) -> void:
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	yaw = atan2(d.x, d.z)
	apply_knock(d, TACKLE_LUNGE)


func get_stunned() -> void:
	stun_t = STUN_TIME
	immune_t = maxf(immune_t, STUN_TIME)   # 1s tackle immunity after drop (spec)
	dash_t = -1.0
	tackle_lock = 0.0
	grab_hold = 0.0
	_stun_stars.emitting = true
	_one_shot("Hit_A", 0.4)


func set_carrier(on: bool) -> void:
	is_carrier = on
	_aura.visible = on
	_leak.emitting = on
	_glow_light.light_energy = 2.2 if on else 0.0
	if on:
		_ring_mat.emission = Color(1.0, 0.8, 0.25)
		_ring_mat.emission_energy_multiplier = 2.4
		_ring_mat.albedo_color = Color(1.0, 0.82, 0.3)
	else:
		_ring_mat.emission = _base_ring_color
		_ring_mat.emission_energy_multiplier = 0.5
		_ring_mat.albedo_color = _base_ring_color


func show_grab_progress(frac: float) -> void:
	if frac <= 0.0:
		_grab_ring.visible = false
		return
	_grab_ring.visible = true
	var f := clampf(frac, 0.05, 1.0)
	_grab_ring.scale = Vector3(f, 1.0, f)
	_grab_mat.emission_energy_multiplier = 1.2 + 2.4 * f


func cheer() -> void:
	_one_shot("Cheer", 3.0)
	if is_bot:
		_hop_after_win_t = _hop_rng.randf_range(3.2, 3.6)   # queued to fire after the Cheer hold clears


## Main per-physics-tick movement. Controller sets intents/actions first.
func tick_movement(delta: float) -> void:
	stun_t = maxf(0.0, stun_t - delta)
	immune_t = maxf(0.0, immune_t - delta)
	iframe_t = maxf(0.0, iframe_t - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	tackle_lock = maxf(0.0, tackle_lock - delta)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_hop_cd = maxf(0.0, _hop_cd - delta)
	_hop_land_hold = maxf(0.0, _hop_land_hold - delta)

	# ---- EXPRESSIVE HOP trigger (see the const-block comment for the refusal
	# rationale). Bots get a round-start hop and one shortly after cheer(); the
	# intent latches (doesn't consume) once a timer crosses zero, so a bot that
	# happens to be refused right then (e.g. mid-tackle-lock) still hops the
	# moment it's free instead of silently losing the beat. -1000.0 is the
	# "inactive/consumed" sentinel — only values above -900.0 are live timers.
	var want_hop := false
	if is_bot:
		if _hop_intro_t > -900.0:
			_hop_intro_t -= delta
			if _hop_intro_t <= 0.0:
				want_hop = true
		if _hop_after_win_t > -900.0:
			_hop_after_win_t -= delta
			if _hop_after_win_t <= 0.0:
				want_hop = true
	else:
		want_hop = PlayerInput.just_pressed(player_index, "jump")
	if want_hop and not _hopping and _hop_cd <= 0.0 and not is_carrier \
			and stun_t <= 0.0 and tackle_lock <= 0.0 and dash_t < 0.0 and _anim_hold <= 0.0:
		_hopping = true
		_hop_anim_t = HOP_START_ANIM_T
		_hop_cd = HOP_CD
		velocity.y = HOP_VY
		Sfx.play("putt", -8.0)
		if _hop_intro_t <= 0.0:
			_hop_intro_t = -1000.0
		if _hop_after_win_t <= 0.0:
			_hop_after_win_t = -1000.0
		print("GREED_HOP p=%d bot=%s frame=%d" % [player_index, str(is_bot), Engine.get_physics_frames()])

	var horiz := Vector3.ZERO
	var moving := false
	if dash_t >= 0.0:
		dash_t += delta
		horiz = _dash_dir * DASH_SPEED * (CARRY_DASH_MULT if is_carrier else 1.0)
		moving = true
		if dash_t >= DASH_TIME:
			dash_t = -1.0
	elif stun_t > 0.0 or tackle_lock > 0.0:
		horiz = Vector3.ZERO
	else:
		var dir := Vector3(_move_intent.x, 0.0, _move_intent.y)
		if dir.length() > 1.0:
			dir = dir.normalized()
		var spd := MOVE_SPEED * (CARRY_SPEED_MULT if is_carrier else 1.0)
		horiz = dir * spd
		if dir.length() > 0.06:
			moving = true
			yaw = lerp_angle(yaw, atan2(dir.x, dir.z), 1.0 - exp(-TURN_LERP * delta))

	horiz += _knock
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)

	velocity.x = horiz.x
	velocity.z = horiz.z
	if _hopping:
		velocity.y -= HOP_GRAVITY * delta        # floaty bunny-hop arc, not combat GRAVITY
	elif is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if _hopping and is_on_floor() and velocity.y <= 0.0:
		_hopping = false
		_hop_land_hold = HOP_LAND_HOLD_T
		_hop_land_fx()

	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
	if _hopping:
		if _hop_anim_t > 0.0:
			_hop_anim_t -= delta
			_play("Jump_Start")
		else:
			_play("Jump_Idle")
	elif _hop_land_hold > 0.0:
		_play("Jump_Land")
	else:
		_update_locomotion_anim(moving)


## EXPRESSIVE HOP landing beat: squash-stretch (1.08 wide / 0.92 tall, 0.1s —
## smaller than the HIT KIT's flash_pop above) + a tiny dust puff.
func _hop_land_fx() -> void:
	if _pivot == null:
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_pivot.scale = Vector3(_base_scale * 1.08, _base_scale * 0.92, _base_scale * 1.08)
	_squash_tw = create_tween()
	_squash_tw.tween_property(_pivot, "scale", Vector3(_base_scale, _base_scale, _base_scale), HOP_SQUASH_T) \
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


func apply_knock(dir: Vector3, power: float) -> void:
	_knock = dir.normalized() * power


## ONLINE mirror pose (render-only; docs/design/10 §4.3). The client's greed.gd
## drives every pawn from 20 Hz snapshots: glide to the authoritative spot, face
## the authoritative yaw, and run the SAME locomotion-anim logic the host uses
## (stun_t doubles as the mirrored stun flag; _anim_hold still honors one-shots
## like the dash/tackle/cheer fired from event deltas). Never runs on a host.
func net_pose(delta: float, tp: Vector3, tyaw: float, moving: bool, stunned: bool) -> void:
	global_position = global_position.lerp(tp, 1.0 - exp(-14.0 * delta))
	yaw = lerp_angle(yaw, tyaw, 1.0 - exp(-14.0 * delta))
	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
	_anim_hold = maxf(0.0, _anim_hold - delta)
	dash_cd = maxf(0.0, dash_cd - delta)      # local decay; resynced per snapshot
	stun_t = 1.0 if stunned else 0.0
	if _stun_stars.emitting != stunned:
		_stun_stars.emitting = stunned
	_update_locomotion_anim(moving)


func _update_locomotion_anim(moving: bool) -> void:
	if _anim_hold > 0.0:
		return
	if stun_t > 0.0:
		_play("Hit_A")
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
	# pulse the aura + spin the grab ring for readability
	if is_carrier:
		var pulse := 0.18 + 0.10 * sin(t * 6.0)
		_aura_mat.albedo_color = Color(1.0, 0.82, 0.2, pulse)
		_aura.scale = Vector3.ONE * (1.0 + 0.06 * sin(t * 6.0))
		_glow_light.light_energy = 2.0 + 0.6 * sin(t * 6.0)
	if _grab_ring.visible:
		_grab_ring.rotation.y += delta * 5.0
	# dash cooldown ring: empty at fire (dash_cd = DASH_CD) -> full = READY.
	if _dash_ring:
		var frac := clampf(1.0 - dash_cd / DASH_CD, 0.0, 1.0)
		var reduced := not bool(PartySetup.pref("screen_shake", true))
		_dash_ring.tick(delta, frac, true, reduced)
