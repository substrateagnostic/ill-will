extends SceneTree
## Dev utility: list animation names in a KayKit GLB so TILT can pick
## the right clips (Idle/Running_A/Cheer/Death_A/Block/...).
## Run: godot --headless --path . -s minigames/tilt/dev_dump_anims.gd

func _init() -> void:
	var ps: PackedScene = load("res://assets/models/kaykit/Knight.glb")
	if ps == null:
		print("ANIMDUMP: could not load Knight.glb")
		quit(1)
		return
	var inst := ps.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if ap == null:
		print("ANIMDUMP: no AnimationPlayer")
	else:
		for a in ap.get_animation_list():
			print("ANIM ", a)
	inst.free()
	quit(0)
