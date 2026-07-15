class_name EstateWalker
extends CharacterBody3D
## A player's character on the estate grounds. Gamepad stick moves it
## directly; the shared mouse selects it and sends it walking to a point.
##
## REAL JUMP (director's ruling, docs/design/16-jump-and-visibility.md §E3):
## the GROUNDS hub is the one place in the anthology with no move+A+B verb
## budget to protect and no combat to keep fair, so it gets an actual
## traversal jump on the new PlayerInput "jump" action — coyote time, input
## buffer, and jump-cut for variable height, tuned to the house feel (the
## same GRAVITY the combat games use).

const SPEED := 3.4
const GRAVITY := 24.0            # house standard (matches player_avatar.gd / echo_chamber.gd)
const CHAR_SCALE := 0.78
const JUMP_HEIGHT := 1.1         # target apex, held the whole ascent
const JUMP_VY := 7.27            # sqrt(2 * GRAVITY * JUMP_HEIGHT)
const JUMP_CUT_MULT := 2.4       # extra gravity applied when rising w/o holding jump (short hop)
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.15
const LAND_SQUASH_T := 0.1

var player_idx := 0
var anim: AnimationPlayer
var walk_target := Vector3.INF
var selected := false
var _anim_lock := 0.0

var _ring_mat: StandardMaterial3D
var _base_color := Color.WHITE

var _model: Node3D              # the KayKit instance (squash target)
var _coyote_t := 0.0
var _jump_buffer_t := 0.0
var _airborne := false          # true from launch until landing (for the squash trigger)
var _squash_tw: Tween

func setup(char_scene: PackedScene, color: Color, idx: int) -> void:
	player_idx = idx
	_base_color = color
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.65
	add_child(shape)
	var inst := char_scene.instantiate()
	inst.scale = Vector3(CHAR_SCALE, CHAR_SCALE, CHAR_SCALE)
	add_child(inst)
	_model = inst
	anim = inst.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A", "Jump_Idle"]:
		if anim and anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.36
	mesh.outer_radius = 0.5
	ring.mesh = mesh
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = color
	_ring_mat.emission_enabled = true
	_ring_mat.emission = color * 0.3
	ring.material_override = _ring_mat
	ring.position.y = 0.03
	ring.scale.y = 0.25
	add_child(ring)
	if anim:
		anim.play("Idle")

func trip(from: Vector3) -> void:
	var away := global_position - from
	away.y = 0.0
	velocity = away.normalized() * 4.0 + Vector3(0, 5.5, 0)
	walk_target = Vector3.INF
	_anim_lock = 0.8
	if anim and anim.has_animation("Hit_A"):
		anim.play("Hit_A")
	Sfx.play("splat", -4.0)

func set_selected(v: bool) -> void:
	selected = v
	if _ring_mat:
		_ring_mat.emission = _base_color * (1.2 if v else 0.3)

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var mv := PlayerInput.get_move(player_idx)
	var v := Vector3(mv.x, 0, mv.y) * SPEED
	if v.length() < 0.2 and walk_target != Vector3.INF:
		var flat := walk_target - global_position
		flat.y = 0.0
		if flat.length() > 0.3:
			v = flat.normalized() * SPEED
		else:
			walk_target = Vector3.INF
	elif v.length() >= 0.2:
		walk_target = Vector3.INF
	velocity.x = v.x
	velocity.z = v.z

	# ---- REAL JUMP: coyote time + input buffer + jump-cut variable height ----
	_coyote_t = COYOTE_TIME if grounded else maxf(0.0, _coyote_t - delta)
	if PlayerInput.just_pressed(player_idx, "jump"):
		_jump_buffer_t = JUMP_BUFFER
	else:
		_jump_buffer_t = maxf(0.0, _jump_buffer_t - delta)
	var did_jump := false
	if _jump_buffer_t > 0.0 and _coyote_t > 0.0:
		velocity.y = JUMP_VY
		_jump_buffer_t = 0.0
		_coyote_t = 0.0
		did_jump = true
	elif grounded:
		velocity.y = 0.0
	else:
		var g := GRAVITY
		if velocity.y > 0.0 and not PlayerInput.is_down(player_idx, "jump"):
			g *= JUMP_CUT_MULT   # released early -> short hop (variable height)
		velocity.y -= g * delta

	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if body is RigidBody3D:
			body.apply_central_impulse(-col.get_normal() * 1.4)

	if did_jump:
		_airborne = true
		Sfx.play("putt", -6.0)
		if anim and anim.has_animation("Jump_Start"):
			anim.play("Jump_Start")
			_anim_lock = 0.18
	elif _airborne and is_on_floor():
		_airborne = false
		_land_squash()
		if anim and anim.has_animation("Jump_Land"):
			anim.play("Jump_Land")
			_anim_lock = 0.15

	_anim_lock = maxf(0.0, _anim_lock - delta)
	if anim and _anim_lock <= 0.0:
		if not is_on_floor():
			if anim.current_animation != "Jump_Idle" and anim.has_animation("Jump_Idle"):
				anim.play("Jump_Idle")
		else:
			var moving := Vector2(velocity.x, velocity.z).length() > 0.5
			var want := "Walking_A" if moving else "Idle"
			if anim.current_animation != want and anim.has_animation(want):
				anim.play(want)
	if Vector2(velocity.x, velocity.z).length() > 0.5:
		var face := atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-10.0 * delta))

## Landing squash — the house convention (1.08 wide / 0.92 tall, ~0.1s).
func _land_squash() -> void:
	if _model == null:
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_squash_tw = create_tween()
	_model.scale = Vector3(CHAR_SCALE * 1.08, CHAR_SCALE * 0.92, CHAR_SCALE * 1.08)
	_squash_tw.tween_property(_model, "scale", Vector3(CHAR_SCALE, CHAR_SCALE, CHAR_SCALE), LAND_SQUASH_T) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
