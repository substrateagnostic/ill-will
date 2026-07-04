extends SceneTree
## Dev tool: godot --headless --script res://scripts/dev/probe_assets.gd

func _init() -> void:
	for path in [
		"res://assets/models/kaykit/Knight.glb",
		"res://assets/models/minigolf/windmill.glb",
		"res://assets/models/minigolf/flag-red.glb",
	]:
		print("=== ", path)
		var scene: PackedScene = load(path)
		if scene == null:
			print("  LOAD FAILED")
			continue
		var inst := scene.instantiate()
		_dump(inst, 1)
		inst.free()
	quit()

func _dump(node: Node, depth: int) -> void:
	if depth > 4:
		return
	var extra := ""
	if node is AnimationPlayer:
		extra = " anims=" + str(node.get_animation_list())
	elif node is MeshInstance3D:
		var aabb: AABB = node.get_aabb()
		extra = " aabb=" + str(aabb.size) + " origin=" + str(node.transform.origin) + " aabb_pos=" + str(aabb.position)
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")", extra)
	for c in node.get_children():
		_dump(c, depth + 1)
