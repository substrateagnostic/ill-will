class_name LWHand
extends Node3D
## The skeletal hand target cursor (spec: "target selection with a pointing
## skeletal hand cursor"). Bone-white boxes: tattered dark sleeve, palm,
## three curled fingers, a thumb, and a long index finger pointing DOWN at
## the chosen survivor. Bobs and sways above the candidate's head.

var _bob_t := 0.0
var _root: Node3D

func _ready() -> void:
	_root = Node3D.new()
	add_child(_root)

	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.93, 0.9, 0.8)
	bone.emission_enabled = true
	bone.emission = Color(0.9, 0.87, 0.75)
	bone.emission_energy_multiplier = 0.45
	bone.roughness = 0.6

	var sleeve_mat := StandardMaterial3D.new()
	sleeve_mat.albedo_color = Color(0.13, 0.1, 0.2)
	sleeve_mat.roughness = 1.0

	# tattered sleeve cuff above the wrist
	var sleeve := MeshInstance3D.new()
	var svm := CylinderMesh.new()
	svm.top_radius = 0.34
	svm.bottom_radius = 0.22
	svm.height = 0.5
	sleeve.mesh = svm
	sleeve.material_override = sleeve_mat
	sleeve.position = Vector3(0, 0.62, -0.1)
	sleeve.rotation_degrees = Vector3(15, 0, 0)
	_root.add_child(sleeve)
	# ragged sleeve tips (fixed jitter — no global RNG, determinism law)
	var rag_jit := [Vector2(8, -7), Vector2(-6, 10), Vector2(4, 5), Vector2(-9, -4), Vector2(2, 11)]
	for i in 5:
		var rag := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.12, 0.22, 0.06)
		rag.mesh = rm
		rag.material_override = sleeve_mat
		var a := i * TAU / 5.0
		rag.position = Vector3(cos(a) * 0.24, 0.4, -0.1 + sin(a) * 0.24)
		var jit: Vector2 = rag_jit[i]
		rag.rotation_degrees = Vector3(15 + jit.x, 0, jit.y)
		_root.add_child(rag)

	# wrist
	var wrist := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.2, 0.28, 0.2)
	wrist.mesh = wm
	wrist.material_override = bone
	wrist.position = Vector3(0, 0.38, -0.02)
	_root.add_child(wrist)

	# palm, tilted so the index reads as POINTING
	var palm := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.34, 0.3, 0.16)
	palm.mesh = pm
	palm.material_override = bone
	palm.position = Vector3(0, 0.16, 0.02)
	palm.rotation_degrees = Vector3(18, 0, 0)
	_root.add_child(palm)

	# index finger: two bone segments + a slightly darker nail tip
	var seg1 := MeshInstance3D.new()
	var s1m := BoxMesh.new()
	s1m.size = Vector3(0.09, 0.3, 0.09)
	seg1.mesh = s1m
	seg1.material_override = bone
	seg1.position = Vector3(0.08, -0.1, 0.08)
	_root.add_child(seg1)
	var seg2 := MeshInstance3D.new()
	var s2m := BoxMesh.new()
	s2m.size = Vector3(0.08, 0.28, 0.08)
	seg2.mesh = s2m
	seg2.material_override = bone
	seg2.position = Vector3(0.08, -0.36, 0.1)
	_root.add_child(seg2)
	var tip := MeshInstance3D.new()
	var tpm := BoxMesh.new()
	tpm.size = Vector3(0.09, 0.1, 0.09)
	tip.mesh = tpm
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.8, 0.75, 0.6)
	tip.mesh = tpm
	tip.material_override = tip_mat
	tip.position = Vector3(0.08, -0.53, 0.1)
	_root.add_child(tip)

	# three curled fingers (stubby knuckle boxes on the palm's lower edge)
	for i in 3:
		var kn := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.09, 0.14, 0.12)
		kn.mesh = km
		kn.material_override = bone
		kn.position = Vector3(-0.1 + i * 0.09 - 0.045, -0.02, 0.12)
		kn.rotation_degrees = Vector3(35, 0, 0)
		_root.add_child(kn)

	# thumb off the side
	var thumb := MeshInstance3D.new()
	var thm := BoxMesh.new()
	thm.size = Vector3(0.2, 0.09, 0.09)
	thumb.mesh = thm
	thumb.material_override = bone
	thumb.position = Vector3(-0.2, 0.1, 0.06)
	thumb.rotation_degrees = Vector3(0, 0, -25)
	_root.add_child(thumb)

	scale = Vector3(1.35, 1.35, 1.35)

func _process(delta: float) -> void:
	_bob_t += delta
	_root.position.y = sin(_bob_t * 4.4) * 0.13
	_root.rotation.y = sin(_bob_t * 1.7) * 0.22
