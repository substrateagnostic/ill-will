class_name Podium
extends Node3D
## Reusable end-of-session podium ceremony. Instantiate, add to tree, call
## present(entries) — entries: [{name, color, char_scene: PackedScene, rank}]
## rank 0 = champion. Emits `done` after the ceremony.

signal done

const BLOCK_HEIGHTS := [1.5, 1.0, 0.6]
const BLOCK_X := [0.0, -1.7, 1.7]
const CEREMONY_TIME := 6.5

@onready var cam := Camera3D.new()

func _ready() -> void:
	global_position = Vector3(0, -60, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.1, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.6)
	e.ambient_light_energy = 1.2
	e.glow_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.3
	light.light_color = Color(1, 0.95, 0.85)
	light.shadow_enabled = true
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 6.0
	fm.bottom_radius = 6.0
	fm.height = 0.2
	floor_mesh.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.25, 0.22, 0.3)
	floor_mesh.material_override = fmat
	floor_mesh.position.y = -0.1
	add_child(floor_mesh)
	cam.position = Vector3(0, 3.1, 7.2)
	cam.rotation_degrees = Vector3(-13, 0, 0)
	cam.fov = 42.0
	add_child(cam)

func present(entries: Array, ceremony_time := CEREMONY_TIME) -> void:
	cam.current = true
	for entry in entries:
		var rank: int = entry.rank
		var color: Color = entry.color
		var pos := Vector3.ZERO
		if rank < 3:
			var block := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.4, BLOCK_HEIGHTS[rank], 1.4)
			block.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color.lerp(Color(0.9, 0.9, 0.95), 0.55)
			block.material_override = mat
			block.position = Vector3(BLOCK_X[rank], BLOCK_HEIGHTS[rank] / 2.0, 0)
			add_child(block)
			var num := Label3D.new()
			num.text = str(rank + 1)
			num.font_size = 140
			num.pixel_size = 0.004
			num.modulate = Color(0.15, 0.13, 0.2)
			num.position = Vector3(BLOCK_X[rank], BLOCK_HEIGHTS[rank] / 2.0, 0.72)
			add_child(num)
			pos = Vector3(BLOCK_X[rank], BLOCK_HEIGHTS[rank], 0)
		else:
			pos = Vector3(3.4, 0, 0.8)
		var scene: PackedScene = entry.char_scene
		var inst := scene.instantiate()
		inst.scale = Vector3(0.9, 0.9, 0.9)
		add_child(inst)
		inst.global_position = global_position + pos
		if entry.has("player"):
			Cosmetics.apply_to_character(inst, entry.player)
		if rank >= 3:
			inst.rotation_degrees.y = 200.0
		var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if anim:
			var wanted: String = ["Cheer", "Idle", "Sit_Floor_Idle", "Lie_Idle"][mini(rank, 3)]
			if anim.has_animation(wanted):
				anim.get_animation(wanted).loop_mode = Animation.LOOP_LINEAR
				anim.play(wanted)
		var tag := Label3D.new()
		tag.text = entry.name
		tag.font_size = 64
		tag.pixel_size = 0.005
		tag.modulate = color
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = pos + Vector3(0, 2.0, 0)
		add_child(tag)
	_confetti()
	Sfx.play("match_win")
	await get_tree().create_timer(ceremony_time).timeout
	done.emit()

func _confetti() -> void:
	for x in [-2.0, 0.0, 2.0]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.position = Vector3(x, 5.5, 0.5)
		p.amount = 40
		p.lifetime = 3.5
		p.preprocess = 0.5
		p.direction = Vector3.DOWN
		p.spread = 25.0
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.2
		p.gravity = Vector3(0, -1.6, 0)
		p.angular_velocity_min = -300.0
		p.angular_velocity_max = 300.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 0.02, 0.09)
		p.mesh = mesh
		p.emitting = true
