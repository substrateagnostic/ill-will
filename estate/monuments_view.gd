class_name MonumentsView
extends RefCounted

## Champion stones on the lawn. Each stone is the Meshy obelisk GLB (forged
## 2026-07-16, tools/meshy_manifest.json id monument_obelisk_small) normalized
## via MeshyProp and flat-tinted per player — the same full material-override
## walk Cosmetics uses (core/cosmetics.gd _override_meshes), so the color IS
## the identity exactly like the old BoxMesh slabs. If the GLB is missing
## (fresh clone before import), the original flat box stands in.
const MONUMENT_GLB := "res://assets/models/meshy/generated/monument_obelisk_small.glb"
const STONE_HEIGHT := 1.3

static func redraw_monuments(plinths: Node3D) -> void:
	for c in plinths.get_children():
		c.queue_free()
	# Show the 8 newest stones in 3 columns with staggered label heights;
	# older history stays in the save (and the ledger), not on the lawn.
	var all: Array = EstateState.monuments
	var shown: Array = all.slice(maxi(0, all.size() - 8))
	for m_idx in shown.size():
		var m: Dictionary = shown[m_idx]
		var col := Color.from_string(str(m.color), Color.WHITE)
		# ground point of this stone (stone base sits here at y=0)
		var ground := Vector3(-7.7 + (m_idx % 3) * 1.05, 0.0, 0.9 - floorf(m_idx / 3.0) * 1.6)
		plinths.add_child(_make_stone(col, ground))
		var tag := Label3D.new()
		tag.text = str(m.label)
		tag.font_size = 30
		tag.pixel_size = 0.0042
		tag.position = ground + Vector3(0, 1.47 + (m_idx % 3) * 0.3, 0.3)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 8
		plinths.add_child(tag)
	if all.size() > shown.size():
		var older := Label3D.new()
		older.text = "+%d older stones (the ledger keeps them)" % (all.size() - shown.size())
		older.font_size = 26
		older.pixel_size = 0.0042
		older.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		older.modulate = Color(0.8, 0.78, 0.75)
		older.outline_size = 8
		plinths.add_child(older)
		older.position = Vector3(-6.6, 2.4, -3.2)

## One champion stone: obelisk GLB when available, legacy flat box otherwise.
## Either way the whole stone carries the player's flat color (house style).
static func _make_stone(col: Color, ground: Vector3) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	if ResourceLoader.exists(MONUMENT_GLB):
		var stone := MeshyProp.instance(MONUMENT_GLB, STONE_HEIGHT)
		stone.position = ground
		_tint_meshes(stone, mat)
		return stone
	var obelisk := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, STONE_HEIGHT, 0.45)
	obelisk.mesh = mesh
	obelisk.material_override = mat
	obelisk.position = ground + Vector3(0, STONE_HEIGHT * 0.5, 0)
	return obelisk

static func _tint_meshes(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_tint_meshes(c, mat)

static func redraw_graffiti(wall_text: Label3D) -> void:
	var lines: Array = EstateState.graffiti.slice(-10)
	wall_text.text = "\n".join(PackedStringArray(lines))
