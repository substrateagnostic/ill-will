extends Node3D
## THROWAWAY probe — the Executor's S-curve: generation or rig? Three butlers
## in a lineup under the house light: the STATIC generation, the RIGGED mesh
## at rest (bind pose, no animation), and the RIGGED mesh playing its Meshy
## preset Idle. If the static spine stands straight and only the idle bends
## it, the fault is the rig/animation; if all three bend, it was born bent.
## Disposable — never shipped, never wired into a receipt.
##
## Run (windowed):
##   godot --path . tools/executor_lineup.tscn -- --outdir=verify_out/exec_lineup

const STATIC_GLB := "res://assets/models/meshy/executor_butler.glb"
const RIGGED_GLB := "res://assets/models/meshy/executor_butler_idle.glb"
const RIGGED_NATIVE_H := 1.9
const H := 2.55

var out_dir := "verify_out/exec_lineup"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.62,
		"key_energy": 1.25,
	})
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.10, 0.12, 0.16)
	fm.roughness = 0.95
	ground.material_override = fm
	add_child(ground)
	var a := MeshyProp.instance(STATIC_GLB, H)
	add_child(a)
	a.global_position = Vector3(-3.2, 0, 0)
	var b := MeshyProp.instance_rigged(RIGGED_GLB, RIGGED_NATIVE_H, H, 0.0, false)
	add_child(b)
	b.global_position = Vector3.ZERO
	var c := MeshyProp.instance_rigged(RIGGED_GLB, RIGGED_NATIVE_H, H)
	add_child(c)
	c.global_position = Vector3(3.2, 0, 0)
	# Candidate idles from the re-animation wave, if any have landed — each
	# plays its own clip in the row past the original three.
	_cands.clear()
	var dir := DirAccess.open("res://assets/models/meshy")
	if dir != null:
		var names: Array = []
		for f in dir.get_files():
			if f.begins_with("executor_butler_idle_c") and f.ends_with(".glb"):
				names.append(f)
		names.sort()
		for k in names.size():
			var cand := MeshyProp.instance_rigged(
				"res://assets/models/meshy/%s" % names[k], RIGGED_NATIVE_H, H)
			add_child(cand)
			cand.global_position = Vector3(6.4 + 3.2 * k, 0, 0)
			_cands.append({"x": 6.4 + 3.2 * k,
				"tag": String(names[k]).trim_suffix(".glb").trim_prefix("executor_butler_idle_")})
	_run()

var _cands: Array = []

func _cam(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	for n in find_children("*", "Camera3D", true, false):
		(n as Camera3D).queue_free()
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
	print("EXEC_LINEUP_SNAP ", ProjectSettings.globalize_path(path))

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(30)
	# lineup: static | rigged-at-rest | rigged-idling — front, back, side
	_cam(Vector3(0, 2.3, 9.0), Vector3(0, 1.5, 0))
	await _settle(); await _snap("l1_front")
	_cam(Vector3(0, 2.3, -9.0), Vector3(0, 1.5, 0))
	await _settle(); await _snap("l2_back")
	_cam(Vector3(9.0, 2.3, 0), Vector3(0, 1.5, 0))
	await _settle(); await _snap("l3_side")
	# the idling one alone across four idle phases — how much is the anim sway?
	_cam(Vector3(3.2, 2.4, 5.8), Vector3(3.2, 1.5, 0))
	for k in 4:
		await _settle(50)
		await _snap("l4_idle_phase_%d" % k)
	# each candidate solo, three phases apart — the dignity audition.
	for cd in _cands:
		_cam(Vector3(float(cd.x), 2.4, 5.8), Vector3(float(cd.x), 1.5, 0))
		for k in 3:
			await _settle(55)
			await _snap("c_%s_phase_%d" % [String(cd.tag), k])
	print("EXEC_LINEUP_DONE")
	get_tree().quit()
