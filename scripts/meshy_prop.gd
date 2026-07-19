class_name MeshyProp
extends RefCounted
## Helper for integrating the custom Meshy GLB props (assets/models/meshy/).
## Meshy normalizes every model to a ~1.9-unit max dimension with an arbitrary
## internal origin, so raw instancing lands the prop at an unpredictable place
## and size. This helper instances a committed GLB, measures the merged AABB of
## all its meshes, then returns a Node3D wrapper whose child model is uniformly
## scaled to a target HEIGHT and re-seated so the prop's base sits at local y=0
## and it is centered on x/z. Purely visual — nothing here touches gameplay.
##
## Usage:
##   var prop := MeshyProp.instance("res://assets/models/meshy/throne.glb", 2.4)
##   prop.rotation.y = PI            # orient as needed per game
##   parent.add_child(prop)
##
## `yaw_deg` rotates the inner model (so the wrapper's own transform is free for
## the caller). Returns an empty Node3D (with a warning) if the path is missing.

## RIGGED GLBs ONLY (Meshy /rigging output, e.g. executor_butler_idle.glb):
## a skinned export's mesh AABB reads ~1/100 scale (the armature applies the
## rest at skinning time), so instance()'s AABB math would explode it. This
## path trusts the model's NATIVE size instead: Meshy rigs to the real-world
## `height_meters` given at rig time (record it in the rig report), so scale
## is just target/native and the feet are assumed to stand at native y=0.
## Also loops the first animation if one ships (pass animate=false to pose).
static func instance_rigged(path: String, native_height: float,
		target_height: float, yaw_deg := 0.0, animate := true) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = "MeshyProp"
	if not ResourceLoader.exists(path):
		push_warning("MeshyProp: missing rigged asset %s" % path)
		return wrap
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("MeshyProp: failed to load %s" % path)
		return wrap
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	if yaw_deg != 0.0:
		model.rotation.y = deg_to_rad(yaw_deg)
	if native_height > 0.0001 and target_height > 0.0:
		var s := target_height / native_height
		model.scale = Vector3(s, s, s)
	wrap.add_child(model)
	_degloss_rigged_materials(model)
	if animate:
		var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		if anim != null and anim.get_animation_list().size() > 0:
			var first: String = anim.get_animation_list()[0]
			anim.get_animation(first).loop_mode = Animation.LOOP_LINEAR
			anim.play(first)
	return wrap

## WIRING FIX (ZA audit, night 8): Meshy's /rigging + /animation re-export
## drops the house-style PBR values the original text-to-3D statics carry
## (metallic 0.0, roughness 0.8 — flat, matte "toy" look) and silently falls
## back to the glTF spec defaults (metallic 1.0, roughness ~0.4) whenever the
## rig pass omits `pbrMetallicRoughness.metallicFactor`. Every rigged/animated
## GLB shipped so far (npc_reaper_walk/_sweep, npc_ferryman_idle,
## npc_gravedigger_idle, npc_groundskeeper_idle, npc_mourner_*_idle/_bow,
## npc_widow_idle, executor_butler_idle) carries this: same albedo texture as
## its static sibling, but metallic=1/roughness=0.41 instead of metallic=0/
## roughness=0.8 — a hard glossy specular sheen on cloth that reads as
## unpainted plastic/rubber next to the matte statics (contact-sheet receipt:
## docs/design/30-asset-finish-audit.md). This is an import-default mismatch,
## not an art/texture change — correct it once, here, for every rigged GLB
## this helper ever instances (present and future).
static func _degloss_rigged_materials(model: Node3D) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if not (mat is BaseMaterial3D):
				continue
			var bm := mat as BaseMaterial3D
			if bm.metallic <= 0.0:
				continue
			var fixed: BaseMaterial3D = bm.duplicate()
			fixed.metallic = 0.0
			fixed.roughness = 0.8
			mi.set_surface_override_material(s, fixed)

static func instance(path: String, target_height: float,
		yaw_deg := 0.0, base_at_zero := true, center_xz := true) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = "MeshyProp"
	if not ResourceLoader.exists(path):
		push_warning("MeshyProp: missing asset %s" % path)
		return wrap
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("MeshyProp: failed to load %s" % path)
		return wrap
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	if yaw_deg != 0.0:
		model.rotation.y = deg_to_rad(yaw_deg)
	wrap.add_child(model)
	var aabb := merged_aabb(model)
	if aabb.size.y > 0.0001 and target_height > 0.0:
		var s := target_height / aabb.size.y
		model.scale = Vector3(s, s, s)
		# offsets are in the parent (wrap) space, i.e. already scaled
		var scaled := merged_aabb_of_scaled(model)
		var off := model.position
		if center_xz:
			off.x -= scaled.position.x + scaled.size.x * 0.5
			off.z -= scaled.position.z + scaled.size.z * 0.5
		if base_at_zero:
			off.y -= scaled.position.y
		model.position = off
	return wrap

## Merged AABB of every MeshInstance3D under `root`, expressed in root-local
## space (root's own transform is NOT applied — the caller owns it).
static func merged_aabb(root: Node) -> AABB:
	var boxes: Array[AABB] = []
	_collect(root, Transform3D.IDENTITY, boxes, true)
	return _union(boxes)

# AABB after `model` already has its scale/rotation applied, in model's PARENT
# space (so root transform IS applied here — used to compute the re-seat offset).
static func merged_aabb_of_scaled(model: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(model, Transform3D.IDENTITY, boxes, false)
	return _union(boxes)

static func _collect(node: Node, xform: Transform3D, boxes: Array[AABB], skip_root_xform: bool) -> void:
	var here := xform
	if node is Node3D and not skip_root_xform:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		boxes.append(here * (node as MeshInstance3D).get_aabb())
	for c in node.get_children():
		_collect(c, here, boxes, false)

static func _union(boxes: Array[AABB]) -> AABB:
	if boxes.is_empty():
		return AABB()
	var out: AABB = boxes[0]
	for i in range(1, boxes.size()):
		out = out.merge(boxes[i])
	return out
