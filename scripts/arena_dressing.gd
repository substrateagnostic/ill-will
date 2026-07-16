class_name ArenaDressing
extends RefCounted
## B8 — ARENA DRESSING. Shared placement helpers for horizon silhouettes and
## estate props (assets/models/meshy/generated/ — headstones, dead trees, iron
## gates, lampposts, mausoleum fronts, hedge topiary) so the anthology's
## plainest arenas read as part of the same estate grounds instead of a
## graybox floating in a void.
##
## PURELY DECORATIVE: everything built here is a static MeshInstance3D (or a
## MeshyProp-wrapped GLB) with no collision, no physics, no per-frame
## processing. Callers place dressing OUTSIDE their play bounds; this helper
## does not know or care where those bounds are.
##
## Usage:
##   ArenaDressing.prop(self, "estate_dead_tree", 3.0, Vector3(20, 0, -14))
##   ArenaDressing.mound(self, Vector3(30, -2, 10), 3.0, 4.0, 3.0, Color(0.05, 0.06, 0.09))

const GEN_DIR := "res://assets/models/meshy/generated/"   # meshy forge wave 2 (~42 props)
const ROOT_DIR := "res://assets/models/meshy/"             # meshy wave 1 (throne, columns, lanterns...)

## One forged prop by manifest id (tools/meshy_manifest.json for GEN_DIR ids;
## earlier wave-1 ids like "broken_column"/"stone_lantern" live in ROOT_DIR),
## scaled to `height` and seated at `pos`. Deterministic yaw (no randomize()/
## RNG — callers pass whatever fixed angle reads best). No-op with a warning
## if the id is missing anywhere (never a hard failure — presentation-only).
static func prop(parent: Node3D, id: String, height: float, pos: Vector3,
		yaw_deg := 0.0, light: Dictionary = {}) -> Node3D:
	var glb := GEN_DIR + id + ".glb"
	if not ResourceLoader.exists(glb):
		glb = ROOT_DIR + id + ".glb"
	if not ResourceLoader.exists(glb):
		push_warning("ArenaDressing: missing prop %s" % id)
		return null
	var node := MeshyProp.instance(glb, height, yaw_deg)
	node.position = pos
	parent.add_child(node)
	if not light.is_empty():
		var l := OmniLight3D.new()
		l.light_color = light.get("color", Color(1.0, 0.8, 0.5))
		l.light_energy = float(light.get("energy", 1.0))
		l.omni_range = float(light.get("range", 5.0))
		l.position = pos + Vector3(0, float(light.get("height", height * 0.9)), 0)
		parent.add_child(l)
	return node

## A low, dark, unshaded mound/skerry to ground dressing that floats above a
## void or ocean (tilt's sea, greed's black vault) — a cheap silhouette shape,
## not meant to be looked at directly. Top sits at `pos.y + height * 0.5`.
static func mound(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float,
		height: float, color := Color(0.05, 0.06, 0.09)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
