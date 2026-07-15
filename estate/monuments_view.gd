class_name MonumentsView
extends RefCounted

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
		var obelisk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.45, 1.3, 0.45)
		obelisk.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		obelisk.material_override = mat
		obelisk.position = Vector3(-7.7 + (m_idx % 3) * 1.05, 0.65, 0.9 - floorf(m_idx / 3.0) * 1.6)
		plinths.add_child(obelisk)
		var tag := Label3D.new()
		tag.text = str(m.label)
		tag.font_size = 30
		tag.pixel_size = 0.0042
		tag.position = obelisk.position + Vector3(0, 0.82 + (m_idx % 3) * 0.3, 0.3)
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

static func redraw_graffiti(wall_text: Label3D) -> void:
	var lines: Array = EstateState.graffiti.slice(-10)
	wall_text.text = "\n".join(PackedStringArray(lines))
