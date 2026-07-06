class_name PlayerAvatar
extends CharacterBody3D
## PAR v4 WAVE 1 — the caddy, promoted to the player. A KayKit character that
## walks to its ball, addresses it, and swings. Movement is direct move_toward
## + capsule slide (no NavServer — spec OQ5). Mirrors the proven KayKit rig in
## minigames/echo_chamber/fighter.gd (capsule r 0.35 h 1.4, _pivot yaw,
## identity ring = player color).
##
## PHYSICS ISOLATION (the frozen-sim rule): the capsule lives on layer 2 with
## mask 1, and main adds a collision exception against EVERY ball — so in wave
## 1 avatars slide around walls and trap bodies but neither touch nor are
## touched by any ball. The sim never sees them. Griefer ball-contact is a
## wave-2 rule.

const WALK_SPEED := 3.0
const GRAVITY := 24.0
## KayKit adventurers face +Z; atan2(dir.x, dir.z) needs no flip (fighter.gd).
const MODEL_YAW_OFFSET := 0.0
const TURN_LERP := 14.0
const CHAR_SCALE := 0.7

## Unit horizontal direction the model currently faces (camera + address use it).
var facing := Vector3(0, 0, -1)
var anim: AnimationPlayer

var _pivot: Node3D
var _dead := false
var _yaw := 0.0
var _walking := false
var _walk_target := Vector3.ZERO
var _run := false

func setup(char_scene: PackedScene, color: Color) -> void:
	collision_layer = 2
	collision_mask = 1
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.4
	cap.shape = shape
	cap.position.y = 0.7
	add_child(cap)

	_pivot = Node3D.new()
	add_child(_pivot)
	var inst := char_scene.instantiate()
	inst.scale = Vector3(CHAR_SCALE, CHAR_SCALE, CHAR_SCALE)
	_pivot.add_child(inst)
	anim = inst.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A", "Running_A", "2H_Melee_Idle"]:
		_loop(a)

	# identity ring on the ground (house style: color = player, never color alone)
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.44
	mesh.height = 0.035
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	ring.material_override = mat
	ring.position.y = 0.018
	add_child(ring)
	play_idle()

func _loop(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var hv := Vector3.ZERO
	if _walking:
		var to := _walk_target - global_position
		to.y = 0.0
		if to.length() > 0.05:
			hv = to.normalized() * WALK_SPEED
			_yaw = lerp_angle(_yaw, atan2(hv.x, hv.z), 1.0 - exp(-TURN_LERP * delta))
		play_loop("Running_A" if _run else "Walking_A")
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_pivot.rotation.y = _yaw + MODEL_YAW_OFFSET
	facing = Vector3(sin(_yaw), 0.0, cos(_yaw))

# --- movement API (driven by AvatarShot) ----------------------------------------

func walk_to(target: Vector3, run := false) -> void:
	_walk_target = target
	_run = run
	_walking = true

func stop_walk() -> void:
	_walking = false
	velocity.x = 0.0
	velocity.z = 0.0

func is_walking() -> bool:
	return _walking

func teleport_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO

func face_dir(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_yaw = atan2(dir.x, dir.z)
	if _pivot:
		_pivot.rotation.y = _yaw + MODEL_YAW_OFFSET
	facing = dir.normalized()

## Small kinematic sidestep toward an address point (never through geometry
## checks — the point is always ~0.55m off the ball on open green).
func slide_toward(pos: Vector3, delta: float) -> void:
	var target := Vector3(pos.x, global_position.y, pos.z)
	global_position = global_position.move_toward(target, 3.0 * delta)

# --- animation API ---------------------------------------------------------------

func play_loop(anim_name: String) -> void:
	if _dead or anim == null or not anim.has_animation(anim_name):
		return
	if anim.current_animation != anim_name:
		anim.play(anim_name)

func play_once(anim_name: String) -> void:
	if _dead or anim == null or not anim.has_animation(anim_name):
		return
	anim.play(anim_name)

func play_idle() -> void:
	play_loop("Idle")

# --- caddy-compatible reaction API (main.gd calls these) --------------------------

func react(anim_name: String) -> void:
	if _dead or _walking or anim == null or not anim.has_animation(anim_name):
		return
	anim.play(anim_name)
	if not anim.animation_finished.is_connected(_back_to_idle):
		anim.animation_finished.connect(_back_to_idle, CONNECT_ONE_SHOT)

func _back_to_idle(_name: StringName) -> void:
	play_idle()

func react_death() -> void:
	if anim == null:
		return
	_dead = true
	_walking = false
	if anim.animation_finished.is_connected(_back_to_idle):
		anim.animation_finished.disconnect(_back_to_idle)
	anim.play("Death_A")

func revive() -> void:
	_dead = false
	play_idle()
