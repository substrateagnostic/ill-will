class_name SwapTrack
extends Node3D
## Purpose-built estate circuit for SWAP MEET. The route quotes the estate in
## one readable lap order: finish straight, hedge chicane, forest S-curves,
## bog/plank split, windmill crossing, graveyard overpass, then home.
##
## Everything is hand-integrated against sampled centre lines. The late-lap
## bridge is genuine topology: its samples rise above the start straight and
## nearest-point queries include height so the two branches never collapse.

const SEG_SAMPLES: int = 16
const SC_HW: float = 1.75
const SC_RAMP_START: float = 2.2
const SC_RAMP_LIP: float = 6.2
const SC_LAND: float = 11.0
const RAMP_H: float = 1.55

const COL_ASPHALT: Color = Color(0.19, 0.20, 0.29)
const COL_CREAM: Color = Color(0.94, 0.86, 0.69)
const COL_RAILRED: Color = Color(0.94, 0.18, 0.25)
const COL_WOOD: Color = Color(0.34, 0.19, 0.12)
const COL_PLANK: Color = Color(0.68, 0.42, 0.18)
const COL_WATER: Color = Color(0.08, 0.48, 0.58, 0.72)
const EDGE_COLORS: Array[Color] = [
	Color(0.1, 0.95, 1.0), Color(1.0, 0.18, 0.72), Color(0.65, 1.0, 0.18),
]

## x, z, half-width, height. Travel order is binding design order. Index 0 is
## the finish line. Indices 15-17 make the high bridge across the index 0-1
## straight; 18-19 descend behind it before closing the loop.
const CTRL: Array = [
	[-38.0, 24.0, 3.25, 0.0], # 0 start/finish straight
	[-18.0, 24.0, 3.25, 0.0], # 1 straight end
	[-10.0, 15.5, 2.65, 0.0], # 2 hedge chicane L
	[-1.5, 28.0, 2.55, 0.0],  # 3 hedge chicane R
	[7.5, 15.0, 2.65, 0.0],   # 4 hedge chicane L
	[18.0, 22.0, 3.1, 0.0],   # 5 forest entry
	[32.0, 13.0, 3.0, 0.0],   # 6 tree apex
	[20.0, 4.0, 2.9, 0.0],    # 7 tree apex
	[34.0, -6.0, 3.1, 0.0],   # 8 forest exit
	[25.0, -19.0, 3.45, 0.0], # 9 bog entry
	[7.0, -24.0, 3.6, 0.0],   # 10 bog pool
	[-10.0, -16.5, 3.5, 0.0], # 11 bog exit
	[-27.0, -21.0, 3.15, 0.0],# 12 windmill approach
	[-39.0, -11.0, 3.0, 0.0], # 13 blade crossing
	[-29.0, -2.0, 3.0, 0.0],  # 14 graveyard climb
	[-28.0, 9.0, 2.85, 1.4],  # 15 bridge ramp
	[-28.0, 24.0, 2.8, 5.6],  # 16 OVER start straight
	[-28.0, 34.0, 2.8, 5.6],  # 17 bridge deck
	[-42.0, 36.0, 3.0, 1.5],  # 18 descent
	[-49.0, 30.0, 3.2, 0.0],  # 19 home bend
]

## Risk/reward launch cutting the middle forest S. It is shorter but narrow,
## airborne, and aimed between tree apexes.
const SC_CTRL: Array = [
	[17.0, 21.4], [21.5, 15.0], [24.0, 8.0], [27.0, 1.0], [33.0, -5.2],
]

const GATE_FRAC: Array[float] = [0.20, 0.43, 0.64, 0.84]

var pts: PackedVector3Array = PackedVector3Array()
var tans: PackedVector3Array = PackedVector3Array()
var hws: PackedFloat32Array = PackedFloat32Array()
var cum: PackedFloat32Array = PackedFloat32Array()
var total_len: float = 0.0

var sc_pts: PackedVector3Array = PackedVector3Array()
var sc_tans: PackedVector3Array = PackedVector3Array()
var sc_cum: PackedFloat32Array = PackedFloat32Array()
var sc_len: float = 0.0
var sc_entry_s: float = 0.0
var sc_exit_s: float = 0.0
var sc_entry_pos: Vector3 = Vector3.ZERO
var sc_exit_pos: Vector3 = Vector3.ZERO

var gate_s: PackedFloat32Array = PackedFloat32Array()
var gate_pos: Array[Vector3] = []
var windmill_s: float = 0.0
var bog_start_s: float = 0.0
var bog_end_s: float = 0.0
var bridge_start_s: float = 0.0
var bridge_end_s: float = 0.0

var _gate_bars: Array[MeshInstance3D] = []
var _vc_mat: StandardMaterial3D = null

func build() -> void:
	_vc_mat = StandardMaterial3D.new()
	_vc_mat.vertex_color_use_as_albedo = true
	_vc_mat.roughness = 0.82
	_vc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sample_main()
	_sample_shortcut()
	bog_start_s = _control_s(9)
	bog_end_s = _control_s(12)
	windmill_s = _control_s(13)
	bridge_start_s = _control_s(14)
	bridge_end_s = _control_s(18)
	for frac: float in GATE_FRAC:
		var s: float = frac * total_len
		var sample: Dictionary = sample_at(s)
		gate_s.append(s)
		gate_pos.append(Vector3(sample.get("pos", Vector3.ZERO)))
	_build_ground()
	_build_ribbon()
	_build_rails_and_markers()
	_build_dashes()
	_build_finish()
	_build_gates()
	_build_shortcut_visual()
	_build_bog()
	_build_biomes()
	_build_bridge_supports()

static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _ctrl_vec(index: int) -> Vector3:
	var c: Array = CTRL[index]
	return Vector3(float(c[0]), float(c[3]), float(c[1]))

func _control_s(index: int) -> float:
	return float(cum[clampi(index * SEG_SAMPLES, 0, cum.size() - 1)])

func _sample_main() -> void:
	var n: int = CTRL.size()
	for i: int in n:
		var p0: Vector3 = _ctrl_vec((i - 1 + n) % n)
		var p1: Vector3 = _ctrl_vec(i)
		var p2: Vector3 = _ctrl_vec((i + 1) % n)
		var p3: Vector3 = _ctrl_vec((i + 2) % n)
		var c1: Array = CTRL[i]
		var c2: Array = CTRL[(i + 1) % n]
		for k: int in SEG_SAMPLES:
			var t: float = float(k) / float(SEG_SAMPLES)
			var smooth: float = t * t * (3.0 - 2.0 * t)
			pts.append(_cr(p0, p1, p2, p3, t))
			hws.append(lerpf(float(c1[2]), float(c2[2]), smooth))
	var m: int = pts.size()
	cum.resize(m)
	var acc: float = 0.0
	for i: int in m:
		cum[i] = acc
		acc += pts[i].distance_to(pts[(i + 1) % m])
	total_len = acc
	tans.resize(m)
	for i: int in m:
		tans[i] = (pts[(i + 1) % m] - pts[i]).normalized()

func _sample_shortcut() -> void:
	var cp: Array[Vector3] = []
	for raw: Array in SC_CTRL:
		cp.append(Vector3(float(raw[0]), 0.0, float(raw[1])))
	var n: int = cp.size()
	for i: int in n - 1:
		var p0: Vector3 = cp[maxi(i - 1, 0)]
		var p1: Vector3 = cp[i]
		var p2: Vector3 = cp[i + 1]
		var p3: Vector3 = cp[mini(i + 2, n - 1)]
		for k: int in SEG_SAMPLES:
			var t: float = float(k) / float(SEG_SAMPLES)
			sc_pts.append(_cr(p0, p1, p2, p3, t))
	sc_pts.append(cp[n - 1])
	var m: int = sc_pts.size()
	sc_cum.resize(m)
	var acc: float = 0.0
	for i: int in m:
		sc_cum[i] = acc
		if i < m - 1:
			acc += sc_pts[i].distance_to(sc_pts[i + 1])
	sc_len = acc
	sc_tans.resize(m)
	for i: int in m:
		var j: int = mini(i, m - 2)
		sc_tans[i] = (sc_pts[j + 1] - sc_pts[j]).normalized()
	sc_entry_pos = sc_pts[0]
	sc_exit_pos = sc_pts[m - 1]
	var entry: Dictionary = nearest_main(sc_entry_pos, -1)
	var exit: Dictionary = nearest_main(sc_exit_pos, -1)
	sc_entry_s = float(entry.get("s", 0.0))
	sc_exit_s = float(exit.get("s", 0.0))

func nearest_main(pos: Vector3, hint: int) -> Dictionary:
	return _nearest(pos, hint, pts, tans, cum, hws, true)

func nearest_sc(pos: Vector3, hint: int) -> Dictionary:
	return _nearest(pos, hint, sc_pts, sc_tans, sc_cum, PackedFloat32Array(), false)

func _nearest(pos: Vector3, hint: int, path: PackedVector3Array,
		path_tans: PackedVector3Array, path_cum: PackedFloat32Array,
		path_hw: PackedFloat32Array, closed: bool) -> Dictionary:
	var m: int = path.size()
	var last: int = m if closed else m - 1
	var lo: int = 0
	var hi: int = last
	if hint >= 0:
		lo = hint - 12
		hi = hint + 13
	var best_d2: float = INF
	var best_i: int = 0
	var best_t: float = 0.0
	var best_proj: Vector3 = Vector3.ZERO
	for raw_i: int in range(lo, hi):
		var i: int = posmod(raw_i, last)
		var a: Vector3 = path[i]
		var b: Vector3 = path[(i + 1) % m]
		var ab: Vector3 = b - a
		var len2: float = ab.length_squared()
		if len2 < 0.000001:
			continue
		var t: float = clampf((pos - a).dot(ab) / len2, 0.0, 1.0)
		var proj: Vector3 = a + ab * t
		var d2: float = pos.distance_squared_to(proj)
		if d2 < best_d2:
			best_d2 = d2
			best_i = i
			best_t = t
			best_proj = proj
	var tangent: Vector3 = path_tans[best_i]
	var right: Vector3 = tangent.cross(Vector3.UP).normalized()
	var seg_len: float = 0.0
	if best_i + 1 < m:
		seg_len = float(path_cum[best_i + 1] - path_cum[best_i])
	elif closed:
		seg_len = total_len - float(path_cum[best_i])
	var s: float = float(path_cum[best_i]) + best_t * maxf(seg_len, 0.0001)
	var width: float = float(path_hw[best_i]) if not path_hw.is_empty() else SC_HW
	return {"idx": best_i, "s": s, "lat": (pos - best_proj).dot(right),
		"tangent": tangent, "proj": best_proj, "hw": width, "floor": best_proj.y}

func sample_at(s: float) -> Dictionary:
	var wrapped: float = fposmod(s, total_len)
	var i: int = clampi(cum.bsearch(wrapped) - 1, 0, pts.size() - 1)
	var next_i: int = (i + 1) % pts.size()
	var seg: float = (float(cum[next_i]) if next_i > 0 else total_len) - float(cum[i])
	var t: float = clampf((wrapped - float(cum[i])) / maxf(seg, 0.0001), 0.0, 1.0)
	return {"pos": pts[i].lerp(pts[next_i], t), "tangent": tans[i], "hw": hws[i]}

func sc_sample_at(s: float) -> Dictionary:
	var clamped: float = clampf(s, 0.0, sc_len)
	var i: int = clampi(sc_cum.bsearch(clamped) - 1, 0, sc_pts.size() - 2)
	var seg: float = float(sc_cum[i + 1] - sc_cum[i])
	var t: float = clampf((clamped - float(sc_cum[i])) / maxf(seg, 0.0001), 0.0, 1.0)
	return {"pos": sc_pts[i].lerp(sc_pts[i + 1], t), "tangent": sc_tans[i], "hw": SC_HW}

func sc_floor(s: float) -> float:
	if s < SC_RAMP_START or s >= SC_RAMP_LIP:
		return 0.0
	return RAMP_H * (s - SC_RAMP_START) / (SC_RAMP_LIP - SC_RAMP_START)

## Water is deliberately off the fast centre plank. The returned multiplier is
## consumed by SwapKart on the next deterministic tick.
func bog_speed_scale(s: float, lateral: float) -> float:
	if s >= bog_start_s and s <= bog_end_s and absf(lateral) > 0.72:
		return 0.60
	return 1.0

func windmill_gate() -> Dictionary:
	return sample_at(windmill_s)

static func _seg_xform(a: Vector3, b: Vector3, scale_v: Vector3) -> Transform3D:
	var fwd: Vector3 = (b - a).normalized()
	var basis: Basis = Basis.looking_at(-fwd, Vector3.UP) * Basis.from_scale(scale_v)
	return Transform3D(basis, (a + b) * 0.5)

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color],
		material: Material) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)

func _build_ground() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(118.0, 92.0)
	ground.mesh = plane
	ground.material_override = _material(Color(0.035, 0.075, 0.075))
	ground.position.y = -0.12
	add_child(ground)

func _build_ribbon() -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m: int = pts.size()
	for i: int in m:
		var j: int = (i + 1) % m
		var r0: Vector3 = tans[i].cross(Vector3.UP).normalized()
		var r1: Vector3 = tans[j].cross(Vector3.UP).normalized()
		var lift: Vector3 = Vector3(0.0, 0.025, 0.0)
		var a0: Vector3 = pts[i] - r0 * hws[i] + lift
		var b0: Vector3 = pts[i] + r0 * hws[i] + lift
		var a1: Vector3 = pts[j] - r1 * hws[j] + lift
		var b1: Vector3 = pts[j] + r1 * hws[j] + lift
		var shade: float = 0.94 + 0.05 * sin(float(i) * 2.71)
		var color: Color = Color(COL_ASPHALT.r * shade, COL_ASPHALT.g * shade, COL_ASPHALT.b * shade)
		for vertex: Vector3 in [a0, b0, a1, b0, b1, a1]:
			tool.set_color(color)
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)
	var ribbon: MeshInstance3D = MeshInstance3D.new()
	ribbon.mesh = tool.commit()
	ribbon.material_override = _vc_mat
	add_child(ribbon)

func _build_rails_and_markers() -> void:
	var rail_mat: StandardMaterial3D = StandardMaterial3D.new()
	rail_mat.vertex_color_use_as_albedo = true
	rail_mat.roughness = 0.85
	var rail_mesh: BoxMesh = BoxMesh.new()
	rail_mesh.size = Vector3(0.24, 0.38, 1.0)
	var rail_transforms: Array[Transform3D] = []
	var rail_colors: Array[Color] = []
	var m: int = pts.size()
	for side: float in [-1.0, 1.0]:
		for i: int in range(0, m, 2):
			var j: int = (i + 2) % m
			var r0: Vector3 = tans[i].cross(Vector3.UP).normalized()
			var r1: Vector3 = tans[j].cross(Vector3.UP).normalized()
			var a: Vector3 = pts[i] + r0 * (hws[i] + 0.16) * side + Vector3(0, 0.23, 0)
			var b: Vector3 = pts[j] + r1 * (hws[j] + 0.16) * side + Vector3(0, 0.23, 0)
			rail_transforms.append(_seg_xform(a, b, Vector3(1, 1, a.distance_to(b) * 1.05)))
			rail_colors.append(Color(0.18, 0.16, 0.24))
	_add_multimesh(rail_mesh, rail_transforms, rail_colors, rail_mat)
	var marker_mesh: CylinderMesh = CylinderMesh.new()
	marker_mesh.top_radius = 0.10
	marker_mesh.bottom_radius = 0.16
	marker_mesh.height = 0.72
	for wanted_color: int in EDGE_COLORS.size():
		var marker_mat: StandardMaterial3D = _material(EDGE_COLORS[wanted_color], 2.2)
		marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var marker_transforms: Array[Transform3D] = []
		var marker_colors: Array[Color] = []
		for s: float in rangef(0.0, total_len, 4.5):
			var color_index: int = posmod(int(s / 4.5), EDGE_COLORS.size())
			if color_index != wanted_color:
				continue
			var sample: Dictionary = sample_at(s)
			var pos: Vector3 = Vector3(sample.get("pos", Vector3.ZERO))
			var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
			var right: Vector3 = tangent.cross(Vector3.UP).normalized()
			var width: float = float(sample.get("hw", 3.0))
			for side: float in [-1.0, 1.0]:
				var marker_pos: Vector3 = pos + right * (width + 0.42) * side + Vector3(0, 0.36, 0)
				marker_transforms.append(Transform3D(Basis.IDENTITY, marker_pos))
				marker_colors.append(Color.WHITE)
		_add_multimesh(marker_mesh, marker_transforms, marker_colors, marker_mat)

func _build_dashes() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.15, 0.035, 1.35)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for s: float in rangef(1.5, total_len, 5.0):
		var sample: Dictionary = sample_at(s)
		var pos: Vector3 = Vector3(sample.get("pos", Vector3.ZERO)) + Vector3(0, 0.055, 0)
		var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
		transforms.append(Transform3D(Basis.looking_at(-tangent, Vector3.UP), pos))
		colors.append(Color(0.82, 0.83, 0.9))
	_add_multimesh(mesh, transforms, colors, mat)

func _build_finish() -> void:
	var sample: Dictionary = sample_at(0.0)
	var center: Vector3 = Vector3(sample.get("pos", Vector3.ZERO))
	var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.RIGHT))
	var right: Vector3 = tangent.cross(Vector3.UP).normalized()
	var width: float = float(sample.get("hw", 3.0))
	var cell: float = 0.5
	var columns: int = int(width * 2.0 / cell)
	for row: int in 2:
		for i: int in columns:
			var tile: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(cell, 0.04, cell)
			tile.mesh = mesh
			tile.material_override = _material(Color(0.96, 0.96, 1.0) if (i + row) % 2 else Color(0.05, 0.05, 0.09))
			tile.position = center + right * (-width + cell * (0.5 + i)) + tangent * cell * (float(row) - 0.5) + Vector3(0, 0.06, 0)
			add_child(tile)
	for side: float in [-1.0, 1.0]:
		var post: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.14
		mesh.bottom_radius = 0.2
		mesh.height = 3.2
		post.mesh = mesh
		post.material_override = _material(COL_RAILRED, 0.35)
		post.position = center + right * (width + 0.65) * side + Vector3(0, 1.6, 0)
		add_child(post)
	var label: Label3D = Label3D.new()
	label.text = "SWAP MEET"
	label.font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	label.font_size = 118
	label.pixel_size = 0.009
	label.modulate = Color(1.0, 0.83, 0.2)
	label.outline_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = center + Vector3(0, 3.45, 0)
	add_child(label)

func _build_gates() -> void:
	for gate_index: int in gate_s.size():
		var sample: Dictionary = sample_at(gate_s[gate_index])
		var center: Vector3 = Vector3(sample.get("pos", Vector3.ZERO))
		var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var width: float = float(sample.get("hw", 3.0))
		var bar: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(width * 2.0 + 1.2, 0.14, 0.14)
		bar.mesh = mesh
		bar.material_override = _material(Color(0.14, 0.8, 1.0), 1.4)
		add_child(bar)
		bar.global_transform = Transform3D(Basis(right, Vector3.UP, tangent), center + Vector3(0, 2.05, 0))
		_gate_bars.append(bar)

func pulse_gate(index: int, color: Color) -> void:
	if index < 0 or index >= _gate_bars.size():
		return
	var bar: MeshInstance3D = _gate_bars[index]
	var mat: StandardMaterial3D = bar.material_override as StandardMaterial3D
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	var tween: Tween = create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 1.4, 0.6)

func _build_shortcut_visual() -> void:
	var deck_mat: StandardMaterial3D = _material(COL_PLANK)
	var s: float = 0.0
	while s < sc_len:
		var next_s: float = minf(s + 0.65, sc_len)
		if s < SC_RAMP_LIP or s >= SC_LAND:
			var a_sample: Dictionary = sc_sample_at(s)
			var b_sample: Dictionary = sc_sample_at(next_s)
			var a: Vector3 = Vector3(a_sample.get("pos", Vector3.ZERO))
			var b: Vector3 = Vector3(b_sample.get("pos", Vector3.ZERO))
			var floor_a: float = sc_floor(s)
			var floor_b: float = sc_floor(next_s)
			a.y = floor_a + 0.03
			b.y = floor_b + 0.03
			var plank: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(SC_HW * 2.0, 0.14, 1.0)
			plank.mesh = mesh
			plank.material_override = deck_mat
			add_child(plank)
			plank.global_transform = _seg_xform(a, b, Vector3(1, 1, a.distance_to(b) * 1.08))
		s = next_s
	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.name = "ScArrow"
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(1.0, 1.0, 0.3)
	arrow.mesh = prism
	arrow.material_override = _material(Color(1.0, 0.75, 0.05), 2.2)
	arrow.position = sc_entry_pos + Vector3(0, 1.8, 0)
	add_child(arrow)

func _build_bog() -> void:
	var water_mat: StandardMaterial3D = _material(COL_WATER, 0.55)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var plank_mat: StandardMaterial3D = _material(Color(0.9, 0.55, 0.16), 0.2)
	var s: float = bog_start_s
	while s < bog_end_s:
		var next_s: float = minf(s + 1.4, bog_end_s)
		var a_sample: Dictionary = sample_at(s)
		var b_sample: Dictionary = sample_at(next_s)
		var a: Vector3 = Vector3(a_sample.get("pos", Vector3.ZERO))
		var b: Vector3 = Vector3(b_sample.get("pos", Vector3.ZERO))
		var width: float = maxf(float(a_sample.get("hw", 3.4)) * 2.0 - 0.25, 1.0)
		var water: MeshInstance3D = MeshInstance3D.new()
		var water_mesh: BoxMesh = BoxMesh.new()
		water_mesh.size = Vector3(width, 0.08, 1.0)
		water.mesh = water_mesh
		water.material_override = water_mat
		add_child(water)
		water.global_transform = _seg_xform(a + Vector3(0, 0.08, 0), b + Vector3(0, 0.08, 0), Vector3(1, 1, a.distance_to(b) * 1.08))
		var plank: MeshInstance3D = MeshInstance3D.new()
		var plank_mesh: BoxMesh = BoxMesh.new()
		plank_mesh.size = Vector3(1.45, 0.12, 1.0)
		plank.mesh = plank_mesh
		plank.material_override = plank_mat
		add_child(plank)
		plank.global_transform = _seg_xform(a + Vector3(0, 0.17, 0), b + Vector3(0, 0.17, 0), Vector3(1, 1, a.distance_to(b) * 0.98))
		s = next_s

func _build_biomes() -> void:
	# Hedge-maze chicane: continuous clipped walls just outside the corridor,
	# plus estate topiary heroes at the three directional beats.
	var hedge_mat: StandardMaterial3D = _material(Color(0.08, 0.38, 0.19), 0.12)
	for s: float in rangef(_control_s(1) + 3.0, _control_s(5) - 2.0, 3.0):
		var sample: Dictionary = sample_at(s)
		var center: Vector3 = Vector3(sample.get("pos", Vector3.ZERO))
		var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var width: float = float(sample.get("hw", 2.6))
		for side: float in [-1.0, 1.0]:
			var wall: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(0.72, 2.35, 3.35)
			wall.mesh = mesh
			wall.material_override = hedge_mat
			wall.position = center + right * (width + 0.58) * side + Vector3.UP * 1.17
			wall.rotation.y = atan2(tangent.x, tangent.z)
			add_child(wall)
	for index: int in [2, 3, 4]:
		var center: Vector3 = _ctrl_vec(index)
		var sample: Dictionary = sample_at(_control_s(index))
		var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var width: float = float(sample.get("hw", 2.6))
		for side: float in [-1.0, 1.0]:
			ArenaDressing.prop(self, "estate_hedge_topiary", 2.5, center + right * (width + 1.15) * side, float(index * 37))
	# Forest S: trees are visible apex calls, not hidden collision.
	for index: int in [5, 6, 7, 8]:
		var center: Vector3 = _ctrl_vec(index)
		var sample: Dictionary = sample_at(_control_s(index))
		var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var side: float = -1.0 if index % 2 == 0 else 1.0
		ArenaDressing.prop(self, "estate_dead_tree", 5.2, center + right * (float(sample.get("hw", 3.0)) + 1.6) * side, float(index * 53))
	# Graveyard bridge approach and deck.
	for raw: Array in [[-36.0, 0.0, 3.5], [-21.0, 8.0, 2.0], [-37.0, 31.0, 1.5], [-19.0, 31.5, 1.5]]:
		ArenaDressing.prop(self, "grave_headstone_cracked", 1.45, Vector3(float(raw[0]), float(raw[2]), float(raw[1])), float(raw[0]) * 3.0)
	ArenaDressing.prop(self, "grave_mausoleum_front", 4.5, Vector3(-18.0, 0.0, 19.0), -90.0)
	# Moonlit estate rim: sparse saturated lamp pools keep the course festive.
	var lamp: Dictionary = {"color": Color(1.0, 0.45, 0.18), "energy": 1.7, "range": 9.0}
	for pos: Vector3 in [Vector3(-48, 0, 17), Vector3(4, 0, 35), Vector3(40, 0, -12), Vector3(-4, 0, -34)]:
		ArenaDressing.prop(self, "estate_lamppost", 3.4, pos, 0.0, lamp)

func _build_bridge_supports() -> void:
	var stone: StandardMaterial3D = _material(Color(0.27, 0.29, 0.38))
	var deck: MeshInstance3D = MeshInstance3D.new()
	var deck_mesh: BoxMesh = BoxMesh.new()
	deck_mesh.size = Vector3(6.5, 0.62, 14.0)
	deck.mesh = deck_mesh
	deck.material_override = stone
	deck.position = Vector3(-28.0, 5.23, 24.0)
	add_child(deck)
	# Four abutment columns sit outside the ground-level straight's 3.25u
	# half-width, leaving the underpass visibly and mechanically clear.
	for z: float in [19.6, 28.4]:
		for x: float in [-31.0, -25.0]:
			var pillar: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(0.9, 5.2, 0.9)
			pillar.mesh = mesh
			pillar.material_override = stone
			pillar.position = Vector3(x, 2.45, z)
			add_child(pillar)
	var arch_label: Label3D = Label3D.new()
	arch_label.text = "GRAVEYARD OVERPASS"
	arch_label.font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	arch_label.font_size = 72
	arch_label.pixel_size = 0.008
	arch_label.modulate = Color(0.7, 0.65, 1.0)
	arch_label.outline_size = 18
	arch_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arch_label.position = Vector3(-28.0, 7.4, 27.0)
	add_child(arch_label)

## GDScript has no floating-point range helper.
func rangef(from: float, to: float, step: float) -> Array[float]:
	var values: Array[float] = []
	var value: float = from
	while value < to:
		values.append(value)
		value += step
	return values
