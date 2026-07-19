extends Node
## ZA finish audit: objective material/texture wiring diagnostic for every GLB
## in a directory (default assets/models/meshy/generated/). Headless, no
## screenshots — this is the *technical* half of the audit (asset_probe.tscn
## contact sheets are the *visual* half). For each GLB:
##   - walks every MeshInstance3D / surface, reads the active material
##   - records whether it has an albedo_texture wired
##   - finds the sibling extracted texture file Godot's import left beside the
##     glb (<name>_0.jpg for statics, <name>_texture_0.png for rigged output)
##   - loads that sibling texture and computes downsampled luminance mean +
##     stddev, to separate "genuinely flat/low-detail bake" from "detailed
##     texture exists on disk but isn't reaching the material" (a real wiring
##     bug) from "no sibling texture at all".
## Prints one AUDIT_ROW line per asset (tab-separated) then quits.
## Run: godot --headless --path . tools/finish_audit.tscn -- --dir=res://assets/models/meshy/generated/

var _dir := "res://assets/models/meshy/generated/"
var _via_meshyprop := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.trim_prefix("--dir=")
		elif arg == "--via-meshyprop":
			_via_meshyprop = true
	var names := _glb_names(_dir)
	if _via_meshyprop:
		# Fix-verification mode: route every rigged (skinned) GLB through the
		# SAME integrator the game actually uses (MeshyProp.instance_rigged),
		# instead of a raw load(), and report the material it produces. Proves
		# the de-gloss fix in scripts/meshy_prop.gd actually reaches the path
		# every rigged NPC in the game takes (board_graph, ambient_life,
		# executor_body, pallbearers) — not just this probe's own loader.
		print("FIX_HEADER name\tmetallic\troughness")
		for n in names:
			_check_fix(_dir + n, n)
		print("FIX_DONE")
		get_tree().quit()
		return
	print("AUDIT_HEADER name\tmesh_instances\tsurfaces\thas_material\thas_albedo_tex\talbedo_tex_path\tsibling_tex\tsibling_kind\ttex_mean\ttex_stddev\talbedo_color\tmetallic\troughness\thas_skeleton\thas_anim")
	for n in names:
		_audit_one(_dir + n, n)
	print("AUDIT_DONE")
	get_tree().quit()

## --via-meshyprop: only meaningful for skinned/rigged GLBs (statics have no
## skeleton and were never affected). Skips anything without a Skeleton3D.
func _check_fix(path: String, fname: String) -> void:
	var base := fname.replace(".glb", "")
	if not ResourceLoader.exists(path):
		return
	var probe: PackedScene = load(path)
	if probe == null or _find_first(probe.instantiate(), "Skeleton3D") == null:
		return
	var wrap := MeshyProp.instance_rigged(path, 1.0, 1.0, 0.0, false)
	var metallic := -1.0
	var roughness := -1.0
	for mi in _find_mesh_instances(wrap):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat: Material = m.get_active_material(s)
			if mat is BaseMaterial3D:
				metallic = (mat as BaseMaterial3D).metallic
				roughness = (mat as BaseMaterial3D).roughness
	print("FIX_ROW %s\t%.2f\t%.2f" % [base, metallic, roughness])
	wrap.free()

func _glb_names(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		print("AUDIT_ERR cannot open dir ", dir)
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

func _audit_one(path: String, fname: String) -> void:
	var base := fname.replace(".glb", "")
	if not ResourceLoader.exists(path):
		print("AUDIT_ROW %s\tLOAD_FAIL" % base)
		return
	var scene: PackedScene = load(path)
	if scene == null:
		print("AUDIT_ROW %s\tLOAD_FAIL" % base)
		return
	var inst: Node = scene.instantiate()
	var meshes := _find_mesh_instances(inst)
	var has_skeleton := _find_first(inst, "Skeleton3D") != null
	var has_anim := _find_first(inst, "AnimationPlayer") != null

	var surf_count := 0
	var has_material := false
	var has_albedo_tex := false
	var albedo_tex_path := ""
	var albedo_color := Color(1, 1, 1, 1)
	var metallic := 0.0
	var roughness := 1.0
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			surf_count += 1
			var mat: Material = m.get_active_material(s)
			if mat == null:
				continue
			has_material = true
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				albedo_color = bm.albedo_color
				metallic = bm.metallic
				roughness = bm.roughness
				var tex := bm.albedo_texture
				if tex != null:
					has_albedo_tex = true
					albedo_tex_path = tex.resource_path

	# sibling extracted texture: try the two naming conventions this repo uses.
	var sibling_path := ""
	var sibling_kind := "none"
	var jpg_path := _dir + base + "_0.jpg"
	var png_path := _dir + base + "_texture_0.png"
	if ResourceLoader.exists(jpg_path):
		sibling_path = jpg_path
		sibling_kind = "jpg"
	elif ResourceLoader.exists(png_path):
		sibling_path = png_path
		sibling_kind = "png"

	var tex_mean := -1.0
	var tex_stddev := -1.0
	if sibling_path != "":
		var stats := _texture_stats(sibling_path)
		tex_mean = stats[0]
		tex_stddev = stats[1]

	print("AUDIT_ROW %s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%.2f\t%.2f\t(%.2f,%.2f,%.2f,%.2f)\t%.2f\t%.2f\t%s\t%s" % [
		base, meshes.size(), surf_count, str(has_material), str(has_albedo_tex), albedo_tex_path,
		sibling_path, sibling_kind, tex_mean, tex_stddev,
		albedo_color.r, albedo_color.g, albedo_color.b, albedo_color.a, metallic, roughness,
		str(has_skeleton), str(has_anim)])
	inst.free()

## Load a texture resource and compute a downsampled luminance mean+stddev
## (0..255 scale). Cheap: resized to 24x24 before sampling.
func _texture_stats(res_path: String) -> Array:
	var tex: Texture2D = load(res_path)
	if tex == null:
		return [-1.0, -1.0]
	var img := tex.get_image()
	if img == null:
		return [-1.0, -1.0]
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.resize(24, 24, Image.INTERPOLATE_LANCZOS)
	var vals: Array[float] = []
	var sum := 0.0
	for y in 24:
		for x in 24:
			var c := img.get_pixel(x, y)
			var lum := (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * 255.0
			vals.append(lum)
			sum += lum
	var mean := sum / vals.size()
	var var_sum := 0.0
	for v in vals:
		var_sum += (v - mean) * (v - mean)
	var stddev := sqrt(var_sum / vals.size())
	return [mean, stddev]

func _find_mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_mesh_instances(c))
	return out

func _find_first(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for c in node.get_children():
		var r := _find_first(c, cls)
		if r != null:
			return r
	return null
