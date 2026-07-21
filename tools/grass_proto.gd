extends Node3D
## THROWAWAY — LIVING LAWN prototype capture lane (TASTE). Proves a shader-grass
## ground fill to replace the plasticky Meshy clump scatter in
## grounds.gd._dress_meadows. Builds two test stretches on the REAL land
## (grounds.height() so they roll): a MEADOW patch and a sparser, wetter
## BOG-EDGE strip. Poses wide / mid / close-glancing framings + a 3-frame
## TRAMPLE sequence as a fake bender crosses. Never shipped, never wired.
##
## Run (windowed, project-relative outdir):
##   godot --path . tools/grass_proto.tscn -- --outdir=verify_out/grass_proto

const G := preload("res://estate/procession/grounds.gd")
const GRASS_SHADER := "res://estate/procession/grass_blades.gdshader"
const GROUND_SHADER := "res://estate/procession/grass_ground.gdshader"

var out_dir := "verify_out/grass_proto"

# patch anchors (real world coords so height() gives real roll)
const MEADOW_C := Vector2(41.0, 6.0)
const BOG_C := Vector2(-24.0, 3.0)
const BOG_BASE_Y := -0.30      # the bog edge sits low; deltas flattened
const BOG_FLATTEN := 0.45

var _grass_mats: Array[ShaderMaterial] = []
var _benders: Array[Node3D] = []
var _meadow_gy := 0.0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.52,
		"key_energy": 1.15,
		"rim_energy": 0.32,
		"rim_color": Color(0.55, 0.68, 1.0),
		"fog_density": 0.010,
		"glow_intensity": 0.85,
	})
	_meadow_gy = G.height(MEADOW_C.x, MEADOW_C.y)

	# ---- MEADOW: rolling ground + dense living grass
	_build_ground(MEADOW_C, Vector2(26, 26), _meadow_gy, 1.0, 0.0,
		Color(0.100, 0.130, 0.075))
	_grass_mats.append(_build_grass(MEADOW_C, Vector2(24, 24), _meadow_gy, 1.0,
		0.42, 0.0, 0.46, 8))
	# ---- BOG EDGE: low, flattened, wetter ground + sparse short tussocks
	_build_ground(BOG_C, Vector2(28, 12), BOG_BASE_Y, BOG_FLATTEN, 0.85,
		Color(0.088, 0.080, 0.058))
	_grass_mats.append(_build_grass(BOG_C, Vector2(26, 10), BOG_BASE_Y, BOG_FLATTEN,
		0.40, 0.85, 0.70, 6))

	# ---- fake tramplers (fed to the shader every frame in _process)
	for i in 2:
		var b := Node3D.new()
		b.set_meta("radius", 1.7)
		add_child(b)
		_benders.append(b)
	_benders[0].global_position = Vector3(MEADOW_C.x - 8.0, _meadow_gy, MEADOW_C.y)
	_benders[1].global_position = Vector3(MEADOW_C.x + 30.0, _meadow_gy, MEADOW_C.y) # parked off-patch
	_run()

# --------------------------------------------------------------------------
func _patch_y(center: Vector2, base_y: float, flatten: float, x: float, z: float) -> float:
	return base_y + (G.height(x, z) - G.height(center.x, center.y)) * flatten

## Rolling, vertex-coloured ground patch under the grass.
func _build_ground(center: Vector2, size: Vector2, base_y: float, flatten: float,
		wetness: float, base_col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.1
	var nx := int(size.x / step)
	var nz := int(size.y / step)
	var x0 := center.x - size.x * 0.5
	var z0 := center.y - size.y * 0.5
	for iz in range(nz + 1):
		for ix in range(nx + 1):
			var x := x0 + float(ix) * step
			var z := z0 + float(iz) * step
			# a faint per-vertex mottle so even the base tint is never one colour
			var m := G._vnoise(x * 1.6 + 20.0, z * 1.6 - 20.0, 61)
			var c := base_col.lightened(m * 0.10) if m > 0.0 else base_col.darkened(-m * 0.12)
			st.set_color(c)
			st.set_uv(Vector2(float(ix) / float(nx), float(iz) / float(nz)))
			st.add_vertex(Vector3(x, _patch_y(center, base_y, flatten, x, z), z))
	for iz in range(nz):
		for ix in range(nx):
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + (nx + 1)
			var d := c + 1
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load(GROUND_SHADER)
	mat.set_shader_parameter("wetness", wetness)
	mi.material_override = mat
	add_child(mi)

## Dense MultiMesh of fanned blade-tufts over a patch. Grass grows in DRIFTS
## (broad noise carves bare soil between) — never a wall-to-wall carpet.
func _build_grass(center: Vector2, size: Vector2, base_y: float, flatten: float,
		blade_h: float, wetness: float, spacing: float, n_blades: int) -> ShaderMaterial:
	var tuft := _make_tuft_mesh(n_blades, blade_h, wetness)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tuft
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + int(wetness * 1000.0)
	var x0 := center.x - size.x * 0.5
	var z0 := center.y - size.y * 0.5
	var z := z0
	while z < z0 + size.y:
		var x := x0
		while x < x0 + size.x:
			var jx := x + spacing * 0.6 * (rng.randf() - 0.5)
			var jz := z + spacing * 0.6 * (rng.randf() - 0.5)
			# DRIFT mask: broad value-noise carves bare dark soil between clumps
			var drift := G._vnoise(jx * 0.055 + 40.0, jz * 0.055, 83)
			var thin := -0.05 if wetness > 0.5 else -0.18   # bog is patchier
			if drift > thin and rng.randf() < (0.62 if wetness > 0.5 else 0.94):
				var y := _patch_y(center, base_y, flatten, jx, jz)
				var sc := (0.80 + 0.45 * rng.randf()) * (0.8 if wetness > 0.5 else 1.0)
				var yaw := rng.randf() * TAU
				var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sc, sc, sc))
				xforms.append(Transform3D(basis, Vector3(jx, y, jz)))
			x += spacing
		z += spacing
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass_w%d" % int(wetness * 100.0)
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load(GRASS_SHADER)
	if wetness > 0.5:
		# bog blades: shorter, wetter, olive-drab, less strawy
		mat.set_shader_parameter("root_color", Color(0.045, 0.058, 0.036))
		mat.set_shader_parameter("tip_color", Color(0.110, 0.190, 0.090))
		mat.set_shader_parameter("dry_tip", Color(0.150, 0.180, 0.080))
		mat.set_shader_parameter("wind_strength", 0.07)
	mmi.material_override = mat
	add_child(mmi)
	var tris_per_tuft := n_blades * 4 * 2   # segs(4) * 2 tris
	print("GRASS_MM w=%.0f tufts=%d blades/tuft=%d tris_per_tuft=%d total_tris=%d" %
		[wetness * 100.0, xforms.size(), n_blades, tris_per_tuft, xforms.size() * tris_per_tuft])
	return mat

## One fanned tuft: n blades at varied yaw / lean / height, each a 3-segment
## strip tapering to a point (pure geometry — no alpha). UV.y = height frac;
## COLOR.r = per-blade phase random; COLOR.g = per-blade hue jitter.
func _make_tuft_mesh(n: int, base_h: float, wetness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + int(wetness * 100.0) + n * 7
	var segs := 4
	for bi in range(n):
		var yaw := rng.randf() * TAU
		var side := Vector2(-sin(yaw), cos(yaw))      # width axis (horizontal)
		var lean_ang := yaw + rng.randf_range(-0.8, 0.8)
		var lean := Vector2(cos(lean_ang), sin(lean_ang))
		var tall := 1.22 if bi == 0 else 1.0          # one hero blade per tuft
		var h := base_h * rng.randf_range(0.78, 1.10) * tall
		var w := rng.randf_range(0.020, 0.032) * (0.85 if wetness > 0.5 else 1.0)
		var lean_amt := (rng.randf_range(0.10, 0.24) + wetness * 0.10) * h
		var root := Vector2(rng.randf_range(-0.19, 0.19), rng.randf_range(-0.19, 0.19))
		var r0 := rng.randf()
		var hue := rng.randf()
		var col := Color(r0, hue, 0.0)
		var fnrm := Vector3(cos(yaw), 0.35, sin(yaw)).normalized()   # face out + up
		# build a SLENDER, ARCING blade: width holds near-full then tapers to a
		# point past mid-height (not a triangle/sail), the tip bows over.
		for j in range(segs):
			var rows := [j, j + 1]
			var p: Array[Vector3] = []
			var u: Array[Vector2] = []
			for side_i in [-1.0, 1.0]:
				for rj in rows:
					var hf := float(rj) / float(segs)
					var wprof := 1.0 if hf < 0.55 else (1.0 - (hf - 0.55) / 0.45)
					var wj := w * clampf(wprof, 0.0, 1.0)
					var bow := pow(hf, 1.4)               # arc grows toward the tip
					var cx := root.x + lean.x * lean_amt * bow
					var cz := root.y + lean.y * lean_amt * bow
					var yy := h * (hf - 0.10 * bow)       # slight gravity tip-droop
					p.append(Vector3(cx + side.x * wj * side_i, yy, cz + side.y * wj * side_i))
					u.append(Vector2(0.5 + 0.5 * side_i, hf))
			# p order: [L_j, L_j1, R_j, R_j1]; two tris L_j,R_j,L_j1 / L_j1,R_j,R_j1
			_tri(st, col, fnrm, p[0], u[0], p[2], u[2], p[1], u[1])
			_tri(st, col, fnrm, p[1], u[1], p[2], u[2], p[3], u[3])
	return st.commit()

func _tri(st: SurfaceTool, col: Color, nrm: Vector3,
		a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
	st.set_normal(nrm); st.set_color(col); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(nrm); st.set_color(col); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(nrm); st.set_color(col); st.set_uv(uc); st.add_vertex(c)

# --------------------------------------------------------------------------
func _process(_dt: float) -> void:
	# feed the trample benders into every grass material each frame
	var arr := PackedVector4Array()
	arr.resize(8)
	var count := mini(_benders.size(), 8)
	for i in range(8):
		if i < count:
			var p := _benders[i].global_position
			arr[i] = Vector4(p.x, p.y, p.z, float(_benders[i].get_meta("radius")))
		else:
			arr[i] = Vector4(0, 0, 0, 0)
	for m in _grass_mats:
		m.set_shader_parameter("benders", arr)
		m.set_shader_parameter("bender_count", count)

# --------------------------------------------------------------------------
func _cam(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	for c in find_children("*", "Camera3D", true, false):
		(c as Camera3D).queue_free()
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = fov
	cam.current = true

func _snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/%s.png" % [out_dir, tag]
	img.save_png(path)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("PROTO_SNAP %s draw_calls=%d prims=%dk" %
		[ProjectSettings.globalize_path(path), dc, prims / 1000])

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(20)
	var mgy := _meadow_gy
	# ---- MEADOW ----
	_cam(Vector3(MEADOW_C.x, mgy + 6.0, MEADOW_C.y + 16.0),
		Vector3(MEADOW_C.x, mgy + 0.4, MEADOW_C.y), 50.0)
	await _settle(); await _snap("m1_wide")
	_cam(Vector3(MEADOW_C.x, mgy + 2.8, MEADOW_C.y + 9.0),
		Vector3(MEADOW_C.x, mgy + 0.35, MEADOW_C.y), 52.0)
	await _settle(); await _snap("m2_mid")
	# close, glancing angle skimming the blade tops (the shard-artifact case)
	_cam(Vector3(MEADOW_C.x - 1.0, mgy + 0.85, MEADOW_C.y + 3.4),
		Vector3(MEADOW_C.x + 3.0, mgy + 0.30, MEADOW_C.y - 2.0), 55.0)
	await _settle(); await _snap("m3_close_glancing")
	# ---- TRAMPLE sequence: bender crosses the meadow along +x ----
	_cam(Vector3(MEADOW_C.x, mgy + 3.4, MEADOW_C.y + 10.5),
		Vector3(MEADOW_C.x, mgy + 0.3, MEADOW_C.y), 52.0)
	for step_i in 3:
		var bx := MEADOW_C.x - 5.0 + float(step_i) * 5.0
		_benders[0].global_position = Vector3(bx, mgy, MEADOW_C.y - 0.5)
		await _settle(4)
		await _snap("t%d_trample" % (step_i + 1))
	# park the bender off-patch again for the clean bog framings
	_benders[0].global_position = Vector3(MEADOW_C.x, mgy, MEADOW_C.y + 40.0)
	# ---- BOG EDGE ----
	var bgy := BOG_BASE_Y
	_cam(Vector3(BOG_C.x, bgy + 5.0, BOG_C.y + 14.0),
		Vector3(BOG_C.x, bgy + 0.3, BOG_C.y), 52.0)
	await _settle(); await _snap("b1_wide")
	_cam(Vector3(BOG_C.x - 2.0, bgy + 2.2, BOG_C.y + 7.0),
		Vector3(BOG_C.x + 2.0, bgy + 0.25, BOG_C.y), 54.0)
	await _settle(); await _snap("b2_mid")
	print("PROTO_SHOTS_DONE")
	get_tree().quit()
