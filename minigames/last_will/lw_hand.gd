class_name LWHand
extends Node3D
## The skeletal hand target cursor (spec: "target selection with a pointing
## skeletal hand cursor"). Unshaded bone-white boxes — palm, knuckles, a
## thumb, and a long index finger pointing DOWN at the chosen survivor —
## pitched hard toward the 3/4 couch camera so the FINGER is what reads
## from above, not a shroud (v1 had a dark sleeve that ate the silhouette).

var _bob_t := 0.0
var _root: Node3D

func _ready() -> void:
	_root = Node3D.new()
	add_child(_root)

	var bone := StandardMaterial3D.new()
	bone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bone.albedo_color = Color(0.97, 0.94, 0.84)
	bone.emission_enabled = true
	bone.emission = Color(0.9, 0.86, 0.7)
	bone.emission_energy_multiplier = 0.35

	var shadow_bone := StandardMaterial3D.new()
	shadow_bone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_bone.albedo_color = Color(0.62, 0.58, 0.5)

	# small dark cuff where the arm "ends" — just enough wrist, no shroud
	var cuff := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.1
	cm.height = 0.1
	cuff.mesh = cm
	var cuff_mat := StandardMaterial3D.new()
	cuff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cuff_mat.albedo_color = Color(0.45, 0.38, 0.62)
	cuff.material_override = cuff_mat
	cuff.position = Vector3(0, 0.4, -0.05)
	_root.add_child(cuff)

	# wrist bones: two thin parallel rods (radius/ulna silhouette)
	for wx in [-0.05, 0.05]:
		var rod := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.06, 0.24, 0.07)
		rod.mesh = rm
		rod.material_override = shadow_bone
		rod.position = Vector3(wx, 0.3, -0.03)
		_root.add_child(rod)

	# palm: broad bone plate
	var palm := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.4, 0.3, 0.15)
	palm.mesh = pm
	palm.material_override = bone
	palm.position = Vector3(0, 0.12, 0.02)
	palm.rotation_degrees = Vector3(14, 0, 0)
	_root.add_child(palm)

	# index finger: two long segments + a darker tip, pointing DOWN
	var seg1 := MeshInstance3D.new()
	var s1m := BoxMesh.new()
	s1m.size = Vector3(0.11, 0.34, 0.11)
	seg1.mesh = s1m
	seg1.material_override = bone
	seg1.position = Vector3(0.1, -0.15, 0.09)
	_root.add_child(seg1)
	var seg2 := MeshInstance3D.new()
	var s2m := BoxMesh.new()
	s2m.size = Vector3(0.1, 0.32, 0.1)
	seg2.mesh = s2m
	seg2.material_override = bone
	seg2.position = Vector3(0.1, -0.46, 0.12)
	_root.add_child(seg2)
	var tip := MeshInstance3D.new()
	var tpm := BoxMesh.new()
	tpm.size = Vector3(0.11, 0.12, 0.11)
	tip.mesh = tpm
	tip.material_override = shadow_bone
	tip.position = Vector3(0.1, -0.66, 0.13)
	_root.add_child(tip)

	# three curled knuckle stubs
	for i in 3:
		var kn := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.1, 0.16, 0.13)
		kn.mesh = km
		kn.material_override = bone
		kn.position = Vector3(-0.13 + i * 0.1, -0.06, 0.11)
		kn.rotation_degrees = Vector3(38, 0, 0)
		_root.add_child(kn)

	# thumb off the side
	var thumb := MeshInstance3D.new()
	var thm := BoxMesh.new()
	thm.size = Vector3(0.22, 0.1, 0.1)
	thumb.mesh = thm
	thumb.material_override = bone
	thumb.position = Vector3(-0.24, 0.06, 0.05)
	thumb.rotation_degrees = Vector3(0, 0, -28)
	_root.add_child(thumb)

	scale = Vector3(1.7, 1.7, 1.7)
	# pitch hard toward the camera: the couch must see FINGER, not wrist
	_root.rotation_degrees.x = 52.0
	_root.position.z = 0.45

func _process(delta: float) -> void:
	_bob_t += delta
	_root.position.y = sin(_bob_t * 4.4) * 0.13
	_root.rotation.y = sin(_bob_t * 1.7) * 0.22
