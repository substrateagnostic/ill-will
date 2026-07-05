extends Node3D
## Asset probe: displays every GLB in res://assets/models/meshy/ on a pedestal
## in a row, under the anthology's warm house lighting, beside a 1.8m reference
## capsule. Prints each model's bounding-box size to stdout for scale judgement.
## Run: godot --path . tools/asset_probe.tscn -- --shots=90 --outdir=verify_out
## (VerifyCapture autoload handles the screenshot + quit.)

const MESHY_DIR := "res://assets/models/meshy/"
const PED_TOP := 0.5
const SPACING := 2.8

func _ready() -> void:
	_build_env()
	var cam := Camera3D.new()
	add_child(cam)

	# reference capsule: 1.8 m tall (radius 0.35 -> capsule total height 1.8)
	_ref_capsule(Vector3(0, 0, 0))

	var names := _glb_names()
	print("PROBE: found %d GLBs: %s" % [names.size(), str(names)])

	var x := SPACING
	for n in names:
		_pedestal(x)
		var path := MESHY_DIR + n
		var res := load(path)
		if res == null:
			print("PROBE_LOAD_FAIL ", n)
			_name_tag(x, n + " (LOAD FAIL)", Color(1, 0.4, 0.4))
			x += SPACING
			continue
		var inst: Node3D = res.instantiate()
		add_child(inst)
		var aabb := _merged_aabb(inst)
		# rest the model's base on the pedestal top, centred over the pedestal
		var c := aabb.get_center()
		inst.global_position = Vector3(x - c.x, PED_TOP - aabb.position.y, -c.z)
		var s := aabb.size
		print("PROBE_AABB %-16s size=(%.2f, %.2f, %.2f)" % [n, s.x, s.y, s.z])
		_name_tag(x, "%s\n%.2f x %.2f x %.2f" % [n.replace(".glb", ""), s.x, s.y, s.z], Color(0.95, 0.95, 1.0))
		x += SPACING

	# frame the whole row
	_row_end = x - SPACING
	var center_x := _row_end / 2.0
	var span := maxf(_row_end, 4.0)
	cam.global_position = Vector3(center_x, 2.4, span * 0.55 + 4.0)
	cam.look_at(Vector3(center_x, 1.1, 0), Vector3.UP)
	cam.fov = 50.0
	cam.current = true
	_cam = cam

var _cam: Camera3D
var _row_end := 0.0
var _frame := 0

func _process(_dt: float) -> void:
	if _cam == null:
		return
	_frame += 1
	# camera passes for close-up shots
	if _frame == 70:
		_frame_group(0.25)
	elif _frame == 130:
		_frame_group(0.75)
	elif _frame == 190:
		_frame_group(0.5)
	elif _frame == 250:
		_frame_group(1.0)

func _frame_group(t: float) -> void:
	var cx := _row_end * t
	_cam.global_position = Vector3(cx, 1.8, 8.0)
	_cam.look_at(Vector3(cx, 1.1, 0), Vector3.UP)

func _glb_names() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(MESHY_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.to_lower().ends_with(".glb"):
			out.append(f)
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func _merged_aabb(node: Node) -> AABB:
	var acc := AABB()
	var has := false
	for m in _all_mesh_instances(node):
		var mi: MeshInstance3D = m
		var a: AABB = mi.get_aabb()
		# transform local AABB into the probe/root space
		var xf: Transform3D = mi.global_transform
		var box := _xform_aabb(xf, a)
		if not has:
			acc = box
			has = true
		else:
			acc = acc.merge(box)
	if not has:
		return AABB(Vector3.ZERO, Vector3.ONE)
	return acc

func _all_mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_mesh_instances(c))
	return out

func _xform_aabb(xf: Transform3D, a: AABB) -> AABB:
	var pts: Array[Vector3] = [
		a.position,
		a.position + Vector3(a.size.x, 0, 0),
		a.position + Vector3(0, a.size.y, 0),
		a.position + Vector3(0, 0, a.size.z),
		a.position + Vector3(a.size.x, a.size.y, 0),
		a.position + Vector3(a.size.x, 0, a.size.z),
		a.position + Vector3(0, a.size.y, a.size.z),
		a.position + a.size,
	]
	var mn := xf * pts[0]
	var mx := mn
	for i in range(1, pts.size()):
		var p: Vector3 = xf * pts[i]
		mn = mn.min(p)
		mx = mx.max(p)
	return AABB(mn, mx - mn)

func _pedestal(x: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, PED_TOP, 1.1)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.26, 0.33)
	mi.material_override = mat
	mi.position = Vector3(x, PED_TOP / 2.0, 0)
	add_child(mi)

func _ref_capsule(base: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.8
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 0.55)
	mi.material_override = mat
	mi.position = base + Vector3(0, 0.9, 0)
	add_child(mi)
	_name_tag(base.x, "1.8 m REF", Color(0.4, 0.95, 0.6))

func _name_tag(x: float, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(x, 2.4, 0)
	add_child(l)

func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.15, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.52, 0.5, 0.62)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	we.environment = e
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -34, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 140, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.55, 0.68, 1.0)
	add_child(fill)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	floor_mi.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.22, 0.2, 0.26)
	floor_mi.material_override = fmat
	add_child(floor_mi)
