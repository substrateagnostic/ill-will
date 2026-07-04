class_name Caddy
extends Node3D
## A player's toy-figure avatar standing behind the tee. Reacts to the
## match: cheers sinks (including kills by their traps), dies with the ball.

var anim: AnimationPlayer
var _dead := false

func setup(char_scene: PackedScene, color: Color) -> void:
	var inst := char_scene.instantiate()
	inst.scale = Vector3(0.7, 0.7, 0.7)
	add_child(inst)
	anim = inst.find_child("AnimationPlayer", true, false)
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
	_loop("Idle")
	play_idle()

func _loop(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func play_idle() -> void:
	if _dead or anim == null:
		return
	anim.play("Idle")

func react(anim_name: String) -> void:
	if _dead or anim == null or not anim.has_animation(anim_name):
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
	if anim.animation_finished.is_connected(_back_to_idle):
		anim.animation_finished.disconnect(_back_to_idle)
	anim.play("Death_A")

func revive() -> void:
	_dead = false
	play_idle()
