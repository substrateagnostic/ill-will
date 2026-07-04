class_name SwapTrack
extends Node3D
## SWAP MEET track: toy-scale tabletop circuit. Pure geometry + meshes -
## no physics bodies. The world queries nearest-point on the center
## polyline (main loop or shortcut branch) and clamps karts to the
## corridor; walls are math, not colliders.
##
## Geometry: control points -> closed Catmull-Rom loop, densely sampled
## with per-point half-widths (the two pinches are narrow points where
## the windmill booms sweep). One shortcut branch cuts the left end cap
## with a plank ramp + jump gap.

## Uniform blow-up of the circuit (world units); lap length ~90u.
const TRACK_SCALE := 1.18

## (x, z, halfwidth). Travel order = array order (counter-clockwise on
## screen); index 0 is the START/FINISH line on the bottom straight.
const CTRL := [
	[10.5, 6.9, 2.3],    # 0 finish line, heading +x
	[13.6, 5.1, 2.3],    # bottom-right sweeper
	[15.8, 0.0, 2.5],    # right apex
	[13.6, -5.1, 2.3],   # top-right
	[7.0, -7.6, 2.3],    # top straight (right)
	[0.0, -5.7, 1.55],   # TOP PINCH (windmill A)
	[-7.0, -7.6, 2.3],   # top straight (left)
	[-13.6, -5.1, 2.3],  # top-left
	[-15.8, 0.0, 2.5],   # left apex
	[-13.6, 5.1, 2.3],   # bottom-left
	[-7.0, 7.6, 2.3],    # bottom straight (left)
	[0.0, 5.7, 1.55],    # BOTTOM PINCH (windmill B)
]
const SEG_SAMPLES := 14

## Shortcut: branch across the left cap. Open Catmull chain.
const SC_CTRL := [
	[-7.6, -6.9],
	[-8.7, -4.0],
	[-9.1, 0.0],
	[-8.7, 4.0],
	[-7.6, 6.9],
]
const SC_HW := 1.6
const SC_RAMP_START := 2.0    # s_sc where the plank ramp starts rising
const SC_RAMP_LIP := 4.6      # s_sc of the launch lip (height RAMP_H)
const SC_LAND := 9.2          # s_sc where landing planks resume
const RAMP_H := 1.35

## Scoring gates as loop fractions (finish line itself is not a gate).
## Chosen so neither route bypasses one (shortcut spans ~0.47..0.72 L).
const GATE_FRAC := [0.14, 0.30, 0.44, 0.79]

const COL_ASPHALT := Color(0.32, 0.31, 0.36)
const COL_CREAM := Color(0.93, 0.88, 0.78)
const COL_RAILRED := Color(0.86, 0.30, 0.26)
const COL_WOOD := Color(0.42, 0.27, 0.16)
const COL_PLANK := Color(0.52, 0.36, 0.20)

var pts := PackedVector3Array()      # dense main loop samples (y = 0)
var tans := PackedVector3Array()     # unit tangents per sample
var hws := PackedFloat32Array()      # half-width per sample
var cum := PackedFloat32Array()      # arclength at sample i
var total_len := 0.0

var sc_pts := PackedVector3Array()   # shortcut samples (y = 0, floor separate)
var sc_tans := PackedVector3Array()
var sc_cum := PackedFloat32Array()
var sc_len := 0.0
var sc_entry_s := 0.0                # s on MAIN of the branch point
var sc_exit_s := 0.0
var sc_entry_pos := Vector3.ZERO
var sc_exit_pos := Vector3.ZERO

var gate_s := PackedFloat32Array()   # sorted s of the scoring gates
var gate_pos: Array = []             # Vector3 per gate
var _gate_bars: Array = []           # MeshInstance3D glow bar per gate
var _vc_mat: StandardMaterial3D     # shared vertex-color material

func build() -> void:
	_vc_mat = StandardMaterial3D.new()
	_vc_mat.vertex_color_use_as_albedo = true
	_vc_mat.roughness = 0.85
	_vc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sample_main()
	_sample_shortcut()
	for f in GATE_FRAC:
		var s := float(f) * total_len
		gate_s.append(s)
		gate_pos.append(sample_at(s).pos)
	_build_table()
	_build_ribbon()
	_build_rails()
	_build_dashes()
	_build_finish()
	_build_gates()
	_build_shortcut_visual()
	_build_decor()

## --- geometry ---------------------------------------------------------------

static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _sample_main() -> void:
	var n := CTRL.size()
	var cp: Array = []
	var chw: Array = []
	for c in CTRL:
		cp.append(Vector3(float(c[0]) * TRACK_SCALE, 0.0, float(c[1]) * TRACK_SCALE))
		chw.append(float(c[2]) * TRACK_SCALE)
	for i in n:
		var p0: Vector3 = cp[(i - 1 + n) % n]
		var p1: Vector3 = cp[i]
		var p2: Vector3 = cp[(i + 1) % n]
		var p3: Vector3 = cp[(i + 2) % n]
		for k in SEG_SAMPLES:
			var t := float(k) / SEG_SAMPLES
			pts.append(_cr(p0, p1, p2, p3, t))
			var st := t * t * (3.0 - 2.0 * t)
			hws.append(lerpf(float(chw[i]), float(chw[(i + 1) % n]), st))
	var m := pts.size()
	cum.resize(m)
	var acc := 0.0
	for i in m:
		cum[i] = acc
		acc += pts[i].distance_to(pts[(i + 1) % m])
	total_len = acc
	tans.resize(m)
	for i in m:
		tans[i] = (pts[(i + 1) % m] - pts[i]).normalized()

func _sample_shortcut() -> void:
	var n := SC_CTRL.size()
	var cp: Array = []
	for c in SC_CTRL:
		cp.append(Vector3(float(c[0]) * TRACK_SCALE, 0.0, float(c[1]) * TRACK_SCALE))
	for i in n - 1:
		var p0: Vector3 = cp[maxi(i - 1, 0)]
		var p1: Vector3 = cp[i]
		var p2: Vector3 = cp[i + 1]
		var p3: Vector3 = cp[mini(i + 2, n - 1)]
		for k in SEG_SAMPLES:
			var t := float(k) / SEG_SAMPLES
			sc_pts.append(_cr(p0, p1, p2, p3, t))
	sc_pts.append(cp[n - 1])
	var m := sc_pts.size()
	sc_cum.resize(m)
	var acc := 0.0
	for i in m:
		sc_cum[i] = acc
		if i < m - 1:
			acc += sc_pts[i].distance_to(sc_pts[i + 1])
	sc_len = acc
	sc_tans.resize(m)
	for i in m:
		var j := mini(i, m - 2)
		sc_tans[i] = (sc_pts[j + 1] - sc_pts[j]).normalized()
	sc_entry_pos = sc_pts[0]
	sc_exit_pos = sc_pts[m - 1]
	sc_entry_s = nearest_main(sc_entry_pos, -1).s
	sc_exit_s = nearest_main(sc_exit_pos, -1).s

## Nearest point on the MAIN loop. hint = last segment index (or -1).
func nearest_main(pos: Vector3, hint: int) -> Dictionary:
	return _nearest(pos, hint, pts, tans, cum, hws, true)

func nearest_sc(pos: Vector3, hint: int) -> Dictionary:
	return _nearest(pos, hint, sc_pts, sc_tans, sc_cum, PackedFloat32Array(), false)

func _nearest(pos: Vector3, hint: int, p: PackedVector3Array, tn: PackedVector3Array,
		cm: PackedFloat32Array, hw: PackedFloat32Array, closed: bool) -> Dictionary:
	var m := p.size()
	var last := m if closed else m - 1
	var lo := 0
	var hi := last
	if hint >= 0:
		lo = hint - 8
		hi = hint + 9
	var best_d2 := 1e18
	var bi := 0
	var bt := 0.0
	var bproj := Vector3.ZERO
	var flat := Vector3(pos.x, 0.0, pos.z)
	for ii in range(lo, hi):
		var i := ((ii % last) + last) % last
		var a := p[i]
		var b := p[(i + 1) % m]
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 < 0.000001:
			continue
		var t := clampf((flat - a).dot(ab) / len2, 0.0, 1.0)
		var proj := a + ab * t
		var d2 := flat.distance_squared_to(proj)
		if d2 < best_d2:
			best_d2 = d2
			bi = i
			bt = t
			bproj = proj
	var tangent := tn[bi]
	var right := tangent.cross(Vector3.UP)
	var seg_len: float = (cm[(bi + 1) % m] if bi + 1 < m else total_len) - cm[bi]
	if bi + 1 >= m and closed:
		seg_len = total_len - cm[bi]
	var s: float = cm[bi] + bt * maxf(seg_len, 0.0001)
	var w: float = hws[bi] if hw.size() > 0 else SC_HW
	return {"idx": bi, "s": s, "lat": (flat - bproj).dot(right),
		"tangent": tangent, "proj": bproj, "hw": w}

## Sample the MAIN loop at arclength s -> {pos, tangent, hw}.
func sample_at(s: float) -> Dictionary:
	s = fposmod(s, total_len)
	var i := cum.bsearch(s) - 1
	i = clampi(i, 0, pts.size() - 1)
	var nxt := (i + 1) % pts.size()
	var seg: float = (cum[nxt] if nxt > 0 else total_len) - cum[i]
	var t: float = clampf((s - cum[i]) / maxf(seg, 0.0001), 0.0, 1.0)
	return {"pos": pts[i].lerp(pts[nxt], t), "tangent": tans[i], "hw": hws[i]}

func sc_sample_at(s: float) -> Dictionary:
	s = clampf(s, 0.0, sc_len)
	var i := sc_cum.bsearch(s) - 1
	i = clampi(i, 0, sc_pts.size() - 2)
	var seg: float = sc_cum[i + 1] - sc_cum[i]
	var t: float = clampf((s - sc_cum[i]) / maxf(seg, 0.0001), 0.0, 1.0)
	return {"pos": sc_pts[i].lerp(sc_pts[i + 1], t), "tangent": sc_tans[i], "hw": SC_HW}

## Floor height along the shortcut (plank ramp -> gap -> landing).
func sc_floor(s: float) -> float:
	if s < SC_RAMP_START or s >= SC_RAMP_LIP:
		return 0.0
	var t := (s - SC_RAMP_START) / (SC_RAMP_LIP - SC_RAMP_START)
	return RAMP_H * t * t * (3.0 - 2.0 * t)

## --- meshes -------------------------------------------------------------------

func _mmi(mm: MultiMesh) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _vc_mat
	add_child(inst)
	return inst

static func _seg_xform(a: Vector3, b: Vector3, size_scale: Vector3) -> Transform3D:
	var fwd := (b - a).normalized()
	var basis := Basis.looking_at(-fwd, Vector3.UP) * Basis.from_scale(size_scale)
	return Transform3D(basis, (a + b) * 0.5)

func _build_ribbon() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := pts.size()
	for i in m:
		var j := (i + 1) % m
		var r0 := tans[i].cross(Vector3.UP)
		var r1 := tans[j].cross(Vector3.UP)
		var y := Vector3(0, 0.02, 0)
		var a0 := pts[i] - r0 * hws[i] + y
		var b0 := pts[i] + r0 * hws[i] + y
		var a1 := pts[j] - r1 * hws[j] + y
		var b1 := pts[j] + r1 * hws[j] + y
		var shade := 1.0 + 0.045 * sin(float(i) * 12.9898)
		var c := Color(COL_ASPHALT.r * shade, COL_ASPHALT.g * shade, COL_ASPHALT.b * shade)
		for v in [a0, b0, a1, b0, b1, a1]:
			st.set_color(c)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vc_mat
	add_child(mi)

func _build_rails() -> void:
	var m := pts.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.34, 1.0)
	mm.mesh = box
	var xforms: Array = []
	var cols: Array = []
	for side: float in [-1.0, 1.0]:
		for i in m:
			var j := (i + 1) % m
			var r0 := tans[i].cross(Vector3.UP)
			var r1 := tans[j].cross(Vector3.UP)
			var a: Vector3 = pts[i] + r0 * (hws[i] + 0.13) * side + Vector3(0, 0.19, 0)
			var b: Vector3 = pts[j] + r1 * (hws[j] + 0.13) * side + Vector3(0, 0.19, 0)
			var seg_len: float = a.distance_to(b)
			xforms.append(_seg_xform(a, b, Vector3(1, 1, seg_len * 1.12)))
			cols.append(COL_RAILRED if int(cum[i] / 2.6) % 4 == 0 else COL_CREAM)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	_mmi(mm)

func _build_dashes() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(0.13, 0.012, 1.15)
	mm.mesh = box
	var n := int(total_len / 2.8)
	mm.instance_count = n
	for i in n:
		var sm := sample_at(float(i) * 2.8)
		var basis := Basis.looking_at(-Vector3(sm.tangent), Vector3.UP)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(sm.pos) + Vector3(0, 0.033, 0)))
		mm.set_instance_color(i, Color(0.92, 0.92, 0.88, 1.0))
	_mmi(mm)

func _build_finish() -> void:
	var sm := sample_at(0.0)
	var tangent := Vector3(sm.tangent)
	var right := tangent.cross(Vector3.UP)
	var c := Vector3(sm.pos)
	var hw := float(sm.hw)
	# checker strip: 2 rows across the track
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	var cell := 0.46
	box.size = Vector3(cell, 0.013, cell)
	mm.mesh = box
	var cols_n := int(hw * 2.0 / cell)
	mm.instance_count = cols_n * 2
	var k := 0
	for row in 2:
		for i in cols_n:
			var p := c + right * (-hw + cell * (0.5 + i)) + tangent * (cell * (row - 0.5)) + Vector3(0, 0.035, 0)
			var basis := Basis.looking_at(-tangent, Vector3.UP)
			mm.set_instance_transform(k, Transform3D(basis, p))
			mm.set_instance_color(k, Color(0.1, 0.1, 0.12) if (i + row) % 2 == 0 else Color(0.95, 0.95, 0.95))
			k += 1
	_mmi(mm)
	# striped posts either side + overhead banner bar
	for side in [-1.0, 1.0]:
		_candy_pole(c + right * (hw + 0.55) * side, 2.6)
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(hw * 2.0 + 1.5, 0.22, 0.3)
	bar.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = COL_RAILRED
	bar.material_override = bmat
	# bar length axis = local x; align x across the track
	add_child(bar)
	bar.global_transform = Transform3D(Basis(right, Vector3.UP, tangent), c + Vector3(0, 2.6, 0))
	var lbl := Label3D.new()
	lbl.text = "FINISH"
	lbl.font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	lbl.font_size = 120
	lbl.pixel_size = 0.008
	lbl.modulate = Color(0.98, 0.95, 0.86)
	lbl.outline_size = 26
	lbl.outline_modulate = Color(0.1, 0.08, 0.1)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = c + Vector3(0, 3.35, 0)
	add_child(lbl)
	var flag: PackedScene = load("res://assets/models/minigolf/flag-red.glb")
	if flag != null:
		var f: Node3D = flag.instantiate()
		f.position = c + right * (hw + 1.5)
		add_child(f)

func _candy_pole(pos: Vector3, h: float) -> void:
	var segs := 6
	for i in segs:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.11
		cm.bottom_radius = 0.11
		cm.height = h / segs
		mi.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COL_RAILRED if i % 2 == 0 else Color(0.96, 0.94, 0.9)
		mi.material_override = mat
		mi.position = pos + Vector3(0, h / segs * (0.5 + i), 0)
		add_child(mi)

func _build_gates() -> void:
	for gi in gate_s.size():
		var sm := sample_at(gate_s[gi])
		var tangent := Vector3(sm.tangent)
		var right := tangent.cross(Vector3.UP)
		var c := Vector3(sm.pos)
		var hw := float(sm.hw)
		for side in [-1.0, 1.0]:
			_gate_pole(c + right * (hw + 0.45) * side, 1.9)
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(hw * 2.0 + 1.2, 0.14, 0.14)
		bar.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.75, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.5, 0.8)
		mat.emission_energy_multiplier = 0.6
		bar.material_override = mat
		add_child(bar)
		bar.global_transform = Transform3D(Basis(right, Vector3.UP, tangent), c + Vector3(0, 1.9, 0))
		_gate_bars.append(bar)

func _gate_pole(pos: Vector3, h: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.13
	cm.height = h
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.75, 0.95)
	mi.material_override = mat
	mi.position = pos + Vector3(0, h * 0.5, 0)
	add_child(mi)

## Gate credit flash (called by the world).
func pulse_gate(gi: int, col: Color) -> void:
	if gi < 0 or gi >= _gate_bars.size():
		return
	var bar: MeshInstance3D = _gate_bars[gi]
	var mat: StandardMaterial3D = bar.material_override
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	var tw := create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 0.6, 0.6)

func _build_shortcut_visual() -> void:
	# plank bridge along the ramp + landing sections (gap left open)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(SC_HW * 2.0, 0.16, 1.0)
	mm.mesh = box
	var xforms: Array = []
	var cols: Array = []
	var step := 0.55
	var s := 0.0
	while s < sc_len:
		if s < SC_RAMP_LIP or s > SC_LAND - 0.6:
			var a := sc_sample_at(s)
			var b := sc_sample_at(minf(s + step, sc_len))
			var pa := Vector3(a.pos) + Vector3(0, sc_floor(s) - 0.06, 0)
			var pb := Vector3(b.pos) + Vector3(0, sc_floor(minf(s + step, sc_len)) - 0.06, 0)
			var shade := 1.0 + (0.10 if int(s / step) % 2 == 0 else -0.06)
			xforms.append(_seg_xform(pa, pb, Vector3(1, 1, pa.distance_to(pb) * 1.06)))
			cols.append(Color(COL_PLANK.r * shade, COL_PLANK.g * shade, COL_PLANK.b * shade))
		s += step
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	_mmi(mm)
	# mini rails on the ramp
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.use_colors = true
	var rb := BoxMesh.new()
	rb.size = Vector3(0.18, 0.24, 1.0)
	mm2.mesh = rb
	var x2: Array = []
	var c2: Array = []
	s = 0.0
	while s < SC_RAMP_LIP:
		for side: float in [-1.0, 1.0]:
			var a := sc_sample_at(s)
			var b := sc_sample_at(s + step)
			var ra := Vector3(a.tangent).cross(Vector3.UP)
			var rbv := Vector3(b.tangent).cross(Vector3.UP)
			var pa: Vector3 = Vector3(a.pos) + ra * (SC_HW + 0.1) * side + Vector3(0, sc_floor(s) + 0.1, 0)
			var pb: Vector3 = Vector3(b.pos) + rbv * (SC_HW + 0.1) * side + Vector3(0, sc_floor(s + step) + 0.1, 0)
			x2.append(_seg_xform(pa, pb, Vector3(1, 1, pa.distance_to(pb) * 1.1)))
			c2.append(COL_CREAM)
		s += step
	mm2.instance_count = x2.size()
	for i in x2.size():
		mm2.set_instance_transform(i, x2[i])
		mm2.set_instance_color(i, c2[i])
	_mmi(mm2)
	# bouncing arrow sign at the entrance
	var arrow := MeshInstance3D.new()
	arrow.name = "ScArrow"
	var pm := PrismMesh.new()
	pm.size = Vector3(0.9, 0.9, 0.25)
	arrow.mesh = pm
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(1.0, 0.85, 0.2)
	amat.emission_enabled = true
	amat.emission = Color(0.9, 0.7, 0.1)
	amat.emission_energy_multiplier = 0.8
	arrow.material_override = amat
	var dir := Vector3(sc_tans[0])
	arrow.position = sc_entry_pos + Vector3(0, 1.7, 0)
	arrow.rotation.z = -PI / 2.0 if dir.z > 0.0 else PI / 2.0
	arrow.rotation.y = atan2(dir.x, dir.z)
	add_child(arrow)

func _build_table() -> void:
	# wooden table + striped felt top (the diorama surface)
	var wood := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 25.0
	wm.bottom_radius = 24.2
	wm.height = 1.6
	wood.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = COL_WOOD
	wmat.roughness = 0.6
	wood.material_override = wmat
	wood.position.y = -0.82
	add_child(wood)
	var felt := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 24.2
	fm.bottom_radius = 24.2
	fm.height = 0.1
	felt.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = load("res://assets/textures/grass_stripes.png")
	fmat.uv1_triplanar = true
	fmat.uv1_scale = Vector3(0.1, 0.1, 0.1)
	fmat.roughness = 1.0
	felt.material_override = fmat
	felt.position.y = -0.05
	add_child(felt)
	# room floor far below (catches the table shadow)
	var floor_mi := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(240, 240)
	floor_mi.mesh = pl
	var flm := StandardMaterial3D.new()
	flm.albedo_color = Color(0.23, 0.17, 0.16)
	flm.roughness = 1.0
	floor_mi.material_override = flm
	floor_mi.position.y = -7.5
	add_child(floor_mi)

func _build_decor() -> void:
	var castle: PackedScene = load("res://assets/models/minigolf/castle.glb")
	if castle != null:
		var c := castle.instantiate()
		c.position = Vector3(11.8, 0.0, 0.4)
		c.scale = Vector3.ONE * 3.0
		add_child(c)
	var block: PackedScene = load("res://assets/models/minigolf/obstacle-block.glb")
	var diamond: PackedScene = load("res://assets/models/minigolf/obstacle-diamond.glb")
	var spots := [Vector3(-20.5, 0, 6.5), Vector3(20.0, 0, -7.0), Vector3(-19.0, 0, -8.0), Vector3(3.0, 0, -11.5)]
	for i in spots.size():
		var ps: PackedScene = block if i % 2 == 0 else diamond
		if ps == null:
			continue
		var d := ps.instantiate()
		d.position = spots[i]
		d.rotation.y = float(i) * 1.3
		d.scale = Vector3.ONE * 1.4
		add_child(d)
