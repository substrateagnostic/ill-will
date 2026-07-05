extends SceneTree
## Dev tool: godot --headless --script res://scripts/dev/probe_rig.gd
## Dumps KayKit character rigs: full node tree + BoneAttachment3D rest transforms,
## plus head-bone world position, to inform cosmetic fitting.

func _init() -> void:
	for path in [
		"res://assets/models/kaykit/Barbarian.glb",
		"res://assets/models/kaykit/Knight.glb",
		"res://assets/models/kaykit/Mage.glb",
		"res://assets/models/kaykit/Rogue.glb",
	]:
		print("=== ", path)
		var scene: PackedScene = load(path)
		if scene == null:
			print("  LOAD FAILED")
			continue
		var inst := scene.instantiate()
		var root := Node3D.new()
		get_root().add_child.call_deferred(root)
		_dump(inst, 1)
		# find skeleton + attachments
		var skel: Skeleton3D = _find_class(inst, "Skeleton3D")
		if skel:
			for i in skel.get_bone_count():
				var n := skel.get_bone_name(i)
				if n.to_lower().contains("head") or n.to_lower().contains("hand") or n.to_lower().contains("chest") or n.to_lower().contains("neck"):
					var g := skel.get_bone_global_rest(i)
					print("  BONE %-20s rest_origin=%s" % [n, str(g.origin)])
		for att in _find_all_class(inst, "BoneAttachment3D"):
			print("  ATTACH %-16s bone=%s xform_origin=%s" % [att.name, att.bone_name, str(att.transform.origin)])
			for c in att.get_children():
				print("      child: ", c.name, " (", c.get_class(), ")")
		# head mesh AABB per character for hat sizing
		inst.free()
	quit()

func _dump(node: Node, depth: int) -> void:
	if depth > 5:
		return
	var extra := ""
	if node is MeshInstance3D:
		var aabb: AABB = node.get_aabb()
		extra = " aabb_size=" + str(aabb.size) + " aabb_pos=" + str(aabb.position)
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")", extra)
	for c in node.get_children():
		_dump(c, depth + 1)

func _find_class(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var r := _find_class(c, cls)
		if r:
			return r
	return null

func _find_all_class(node: Node, cls: String) -> Array:
	var out: Array = []
	if node.get_class() == cls:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_all_class(c, cls))
	return out
