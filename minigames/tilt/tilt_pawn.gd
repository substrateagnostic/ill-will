class_name TiltPawn
extends Node3D
## A player standing on the platter. All movement is manual, integrated in
## platter-LOCAL space (Vector2 lpos); the world transform is composed from
## the disc's global transform every tick so the pawn visually tilts with
## the platter. No physics bodies: per the spec's risk notes we never rely
## on floor friction — downhill slide is integrated by hand:
##   slide += g*sin(tilt)*downhill*dt, decayed exponentially (footing),
## with a static-friction threshold that shrinks as you carry coins.

enum PState { STANDING, FALLING, GONE }

const BASE_SPEED := 4.5
const COIN_MASS := 0.08          # +8% mass per coin
const SLIDE_ACCEL := 1.0         # multiplier on g*sin(tilt)
const SLIDE_DECAY := 0.9         # footing (exp decay rate), shrinks w/ coins
const STATIC_DEG := 7.0          # below this tilt you keep your feet planted
const SLOPE_SPEED := 0.55        # move speed +- with slope
const BRACE_TIME := 2.0
const BRACE_CD := 3.0
const SHOVE_CD := 0.8
const SHOVE_WINDUP := 0.12       # readable tell; total time-to-hit stays < 0.2s
const CLASH_STAGGER := 0.3       # after a clash: no immediate re-shove
const FALL_GRAV := 12.0

var player_index := 0
var pname := ""
var pcolor := Color.WHITE
var state: PState = PState.STANDING
var lpos := Vector2.ZERO         # platter-local XZ
var facing := Vector2(0.0, 1.0)  # unit, local XZ
var slide := Vector2.ZERO        # slide velocity, local XZ
var move_vel := Vector2.ZERO
var coins := 0
var braced := false
var brace_t := 0.0
var brace_cd := 0.0
var shove_cd := 0.0
var windup_t := 0.0              # > 0: shove wound up, lands when it hits 0
var shove_press_t := -999.0      # game time the current/last shove started
var in_slip := false
var stagger_t := 0.0             # shoved: briefly no control (knock carries)
var fall_vel := Vector3.ZERO
var last_shover := -1
var last_shove_t := -999.0
var cheering := false

var _disc: Node3D
var _anim: AnimationPlayer
var _avatar: Node3D
var _stack: Node3D
var _brace_ring: MeshInstance3D
var _cur_anim := ""
var _anim_hold := 0.0            # seconds a one-shot anim owns the body
var _shove_release := false      # set the tick the windup completes

func setup(index: int, display_name: String, color: Color, char_scene_path: String, disc: Node3D) -> void:
	player_index = index
	pname = display_name
	pcolor = color
	_disc = disc
	var ps: PackedScene = load(char_scene_path)
	if ps != null:
		_avatar = ps.instantiate()
		add_child(_avatar)
		_anim = _avatar.find_child("AnimationPlayer", true, false)
		for lp_name in ["Idle", "Running_A", "Blocking", "Jump_Idle", "Cheer"]:
			if _anim and _anim.has_animation(lp_name):
				_anim.get_animation(lp_name).loop_mode = Animation.LOOP_LINEAR
	# identity ring under the feet
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.4
	rm.outer_radius = 0.62
	ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = 1.4
	ring.material_override = rmat
	ring.position.y = 0.04
	ring.scale.y = 0.35
	add_child(ring)
	# brace ring (visible only while braced)
	_brace_ring = MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.55
	bm.outer_radius = 0.72
	_brace_ring.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1, 1, 1, 0.9)
	bmat.emission_enabled = true
	bmat.emission = color * 1.2
	bmat.emission_energy_multiplier = 1.8
	_brace_ring.material_override = bmat
	_brace_ring.position.y = 0.12
	_brace_ring.scale.y = 0.4
	_brace_ring.visible = false
	add_child(_brace_ring)
	# coin backpack stack
	_stack = Node3D.new()
	_stack.name = "CoinStack"
	add_child(_stack)
	_play("Idle")

func mass() -> float:
	return 1.0 + COIN_MASS * coins

## Main per-tick update while STANDING. move is the (already bot-or-human)
## input vector, tilt the platter's tilt vector (radians, local XZ).
func tick(delta: float, move: Vector2, tilt: Vector2) -> void:
	shove_cd = maxf(0.0, shove_cd - delta)
	stagger_t = maxf(0.0, stagger_t - delta)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	if windup_t > 0.0:
		windup_t -= delta
		if windup_t <= 0.0:
			windup_t = 0.0
			_shove_release = true
			if _avatar:
				_avatar.scale = Vector3.ONE
	if braced:
		brace_t -= delta
		if brace_t <= 0.0:
			braced = false
			brace_cd = BRACE_CD
			_brace_ring.visible = false
	else:
		brace_cd = maxf(0.0, brace_cd - delta)
	var tmag := tilt.length()
	var sin_t := sin(tmag)
	var dh := tilt.normalized() if tmag > 0.0001 else Vector2.ZERO
	# -- input movement (locked while braced)
	move_vel = Vector2.ZERO
	if not braced and stagger_t <= 0.0 and move.length() > 0.05:
		var dir := move.normalized() if move.length() > 1.0 else move
		var aim := dir.normalized()
		var speed_scale := 1.0 + SLOPE_SPEED * sin_t * aim.dot(dh)
		move_vel = dir * BASE_SPEED * speed_scale
		facing = facing.slerp(aim, minf(1.0, 12.0 * delta)).normalized()
	# -- downhill slide (the heart of the game)
	if braced and not in_slip:
		slide = Vector2.ZERO
	else:
		var static_deg := maxf(2.5, STATIC_DEG - 0.5 * coins)
		var accel := 9.8 * sin_t * SLIDE_ACCEL * (1.0 + 0.06 * coins)
		var k := SLIDE_DECAY / (1.0 + 0.18 * coins)
		if in_slip:
			static_deg = 0.3
			accel *= 1.4
			k = 0.15
		if rad_to_deg(tmag) > static_deg or slide.length() > 0.3:
			slide += dh * accel * delta
		slide *= exp(-k * delta)
		if rad_to_deg(tmag) < static_deg and slide.length() < 0.35 and not in_slip:
			slide = Vector2.ZERO
	lpos += (move_vel + slide) * delta
	_update_anim()
	_apply_platter_transform()

func tick_falling(delta: float) -> void:
	fall_vel.y -= FALL_GRAV * delta
	global_position += fall_vel * delta
	rotation.x += 2.4 * delta  # tumble
	if _anim_hold <= 0.0:
		_play("Jump_Idle")

func begin_fall() -> void:
	state = PState.FALLING
	var v3 := Vector3(move_vel.x + slide.x, 0.0, move_vel.y + slide.y)
	fall_vel = _disc.global_transform.basis * v3
	fall_vel.y = minf(fall_vel.y, 0.5)
	braced = false
	_brace_ring.visible = false
	_anim_hold = 0.0
	cancel_windup()

func try_brace() -> bool:
	if braced or brace_cd > 0.0 or windup_t > 0.0 or state != PState.STANDING:
		return false
	braced = true
	brace_t = BRACE_TIME
	slide = Vector2.ZERO
	_brace_ring.visible = true
	return true

## Begins the shove WINDUP (the readable tell). The hit itself lands
## SHOVE_WINDUP seconds later — tilt.gd polls consume_shove_release() and
## resolves cone hits / clashes there. Cooldown counts from the press.
func try_shove(now: float) -> bool:
	if shove_cd > 0.0 or windup_t > 0.0 or braced or stagger_t > 0.0 \
			or state != PState.STANDING:
		return false
	shove_cd = SHOVE_CD
	windup_t = SHOVE_WINDUP
	shove_press_t = now
	if _avatar:
		_avatar.scale = Vector3.ONE * 1.06  # windup pulse (snap back on release)
	_one_shot("Unarmed_Melee_Attack_Punch_A", SHOVE_WINDUP + 0.5)
	return true

## True exactly once, on the tick the windup completed.
func consume_shove_release() -> bool:
	if _shove_release:
		_shove_release = false
		return true
	return false

## The forward lunge that used to fire at press time — now at release.
func release_lunge() -> void:
	slide += facing * 1.2

## Windup interrupted (hit mid-swing, clash consumed it, fell, round reset).
func cancel_windup() -> void:
	windup_t = 0.0
	_shove_release = false
	shove_press_t = -999.0
	if _avatar:
		_avatar.scale = Vector3.ONE

func apply_knock(dir: Vector2, power: float, shover: int, now: float) -> void:
	var factor := 0.35 if braced else 1.0
	slide += dir * power * factor
	if not braced:
		stagger_t = 0.5
		cancel_windup()  # a landed hit interrupts whatever you were winding up
	last_shover = shover
	last_shove_t = now
	_one_shot("Hit_A", 0.4)

## Mutual shove clash: soft push-apart, brief stagger, NO royalty credit
## (last_shover deliberately untouched).
func apply_clash(dir: Vector2, power: float) -> void:
	slide += dir * power
	stagger_t = CLASH_STAGGER
	cancel_windup()
	_one_shot("Hit_A", 0.35)

func add_coin() -> void:
	coins += 1
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = 0.09
	c.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.15)
	mat.metallic = 0.8
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.65, 0.05)
	mat.emission_energy_multiplier = 0.6
	c.material_override = mat
	c.position = Vector3(0.0, 0.88 + (coins - 1) * 0.1, 0.32)
	c.rotation.z = 0.12 * ((coins % 3) - 1)
	_stack.add_child(c)

func cheer() -> void:
	cheering = true
	_play("Cheer")

## ---- ONLINE mirror poses (doc 10 §4.3) --------------------------------------
## Render-only: a mirror pawn is POSED from host snapshots, never simulated.
## All of these reuse the exact anim/visual paths the couch uses.

## Standing pawn, per mirror tick: lpos/facing already interpolated by tilt.gd.
func mirror_pose_standing(lp: Vector2, face_ang: float, moving: bool, braced_now: bool, delta: float) -> void:
	lpos = lp
	facing = Vector2(sin(face_ang), cos(face_ang))
	braced = braced_now
	_brace_ring.visible = braced_now
	_anim_hold = maxf(0.0, _anim_hold - delta)
	if not cheering and _anim_hold <= 0.0:
		if braced_now:
			_play("Blocking")
		else:
			_play("Running_A" if moving else "Idle")
	_apply_platter_transform()

## Falling pawn: chase the authoritative world position, tumble locally.
func mirror_fall_pose(target: Vector3, delta: float) -> void:
	global_position = global_position.lerp(target, 1.0 - exp(-10.0 * delta))
	rotation.x += 2.4 * delta
	if _anim_hold <= 0.0:
		_play("Jump_Idle")

## Shove-counter delta: the windup tell (scale pulse + early punch anim). The
## snap-back the host does at release time runs on a local timer here.
func mirror_windup() -> void:
	if _avatar:
		_avatar.scale = Vector3.ONE * 1.06
	_one_shot("Unarmed_Melee_Attack_Punch_A", SHOVE_WINDUP + 0.5)
	var tw := create_tween()
	tw.tween_interval(SHOVE_WINDUP)
	tw.tween_callback(func() -> void:
		if _avatar:
			_avatar.scale = Vector3.ONE)

## Knock-counter delta: the hit reaction.
func mirror_knock() -> void:
	if _avatar:
		_avatar.scale = Vector3.ONE
	_one_shot("Hit_A", 0.4)

## State delta STANDING -> FALLING: flip the visuals; position rides the wire.
func mirror_begin_fall() -> void:
	state = PState.FALLING
	braced = false
	_brace_ring.visible = false
	_anim_hold = 0.0
	cheering = false
	if _avatar:
		_avatar.scale = Vector3.ONE

func reset_for_round(spawn: Vector2) -> void:
	state = PState.STANDING
	lpos = spawn
	facing = (-spawn).normalized() if spawn.length() > 0.01 else Vector2(0, 1)
	slide = Vector2.ZERO
	move_vel = Vector2.ZERO
	coins = 0
	for c in _stack.get_children():
		c.queue_free()
	braced = false
	brace_t = 0.0
	brace_cd = 0.0
	shove_cd = 0.0
	cancel_windup()
	in_slip = false
	fall_vel = Vector3.ZERO
	last_shover = -1
	last_shove_t = -999.0
	cheering = false
	_anim_hold = 0.0
	_brace_ring.visible = false
	visible = true
	_cur_anim = ""
	_play("Idle")
	_apply_platter_transform()

func vanish() -> void:
	state = PState.GONE
	visible = false

## Compose world transform from the disc: pawn stands ON the tilted disc,
## leaning with it, rotated around the local up axis to face `facing`.
func _apply_platter_transform() -> void:
	var yaw := atan2(facing.x, facing.y)
	var xf := _disc.global_transform
	global_transform = Transform3D(
		xf.basis * Basis(Vector3.UP, yaw),
		xf * Vector3(lpos.x, TiltPlatter.PAWN_Y, lpos.y))

func _update_anim() -> void:
	if cheering:
		return
	if _anim_hold > 0.0:
		return
	if braced:
		_play("Blocking")
		return
	var speed := (move_vel + slide).length()
	_play("Running_A" if speed > 0.8 else "Idle")

func _one_shot(anim_name: String, hold: float) -> void:
	if _anim and _anim.has_animation(anim_name):
		_cur_anim = anim_name
		_anim.play(anim_name, 0.1)
		_anim_hold = hold

func _play(anim_name: String) -> void:
	if _anim == null or _cur_anim == anim_name:
		return
	if not _anim.has_animation(anim_name):
		anim_name = "Idle"
		if _cur_anim == anim_name or not _anim.has_animation(anim_name):
			return
	_cur_anim = anim_name
	_anim.play(anim_name, 0.2)
