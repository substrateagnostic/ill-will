class_name EstateWalker
extends CharacterBody3D
## A player's character on the estate grounds. Gamepad stick moves it
## directly; the shared mouse selects it and sends it walking to a point.

const SPEED := 3.4

var player_idx := 0
var anim: AnimationPlayer
var walk_target := Vector3.INF
var selected := false
var _anim_lock := 0.0

var _ring_mat: StandardMaterial3D
var _base_color := Color.WHITE

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
	inst.scale = Vector3(0.78, 0.78, 0.78)
	add_child(inst)
	anim = inst.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A"]:
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
	velocity.y = velocity.y - 20.0 * delta if not is_on_floor() else 0.0
	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if body is RigidBody3D:
			body.apply_central_impulse(-col.get_normal() * 1.4)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	if anim and _anim_lock <= 0.0:
		var moving := Vector2(velocity.x, velocity.z).length() > 0.5
		var want := "Walking_A" if moving else "Idle"
		if anim.current_animation != want and anim.has_animation(want):
			anim.play(want)
	if Vector2(velocity.x, velocity.z).length() > 0.5:
		var face := atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-10.0 * delta))
