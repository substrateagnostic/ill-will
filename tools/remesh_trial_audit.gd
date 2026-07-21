extends Node3D
## THROWAWAY — REMESH TRIAL audit (producer-authorized experiment, 2026-07-20).
## Same bind-vs-animating pair pattern as tools/rig_audit2.gd, narrowed to a
## single lineup: the confirmed-ballooning control (executor_butler_v2_idle_
## c243, action_id 243 on the sparse/irregular-topology auto-rig) beside the
## remesh candidate (executor_butler_v3r_idle_c243 — same clip, same rig
## pipeline, but the source GLB was remeshed to uniform quad-dominant
## topology, target_polycount=30000, BEFORE rigging). Judge the waist/belly
## specifically across 3 animating phases per model.
##
## Disposable — never shipped, never wired into a receipt. Does not modify
## tools/rig_audit.gd or tools/rig_audit2.gd.
##
## Run (windowed):
##   godot --path . tools/remesh_trial_audit.tscn -- --outdir=verify_out/remesh_trial_audit

const GEN := "res://assets/models/meshy/generated/"
const TARGET_H := 1.8   # same uniform target height as rig_audit/rig_audit2 —
						 # deformation is a proportion/rotation defect, invariant
						 # to overall scale, so one target height keeps shots
						 # directly comparable across the control and candidate.
const PAIR_SPACING := 4.0
const HALF_GAP := 1.0

# (tag, glb, native_height_meters) — control first, then remesh candidate.
const RIGGED_CANDIDATES := [
	["01_v2_CONTROL_ballooning", "executor_butler_v2_idle_c243.glb", 1.9],
	["02_v3r_REMESH_candidate", "executor_butler_v3r_idle_c243.glb", 1.9],
]

var out_dir := "verify_out/remesh_trial_audit"
var _pairs: Array = []      # [{tag, x}] rigged pairs

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
	pm.size = Vector2(32, 32)
	ground.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.10, 0.12, 0.16)
	fm.roughness = 0.95
	ground.material_override = fm
	add_child(ground)

	for i in RIGGED_CANDIDATES.size():
		var tag: String = RIGGED_CANDIDATES[i][0]
		var glb: String = RIGGED_CANDIDATES[i][1]
		var native_h: float = RIGGED_CANDIDATES[i][2]
		var x := float(i) * PAIR_SPACING
		var path := GEN + glb
		if not ResourceLoader.exists(path):
			print("REMESH_TRIAL_AUDIT_MISSING ", path)
			continue
		var bind := MeshyProp.instance_rigged(path, native_h, TARGET_H, 0.0, false)
		add_child(bind)
		bind.global_position = Vector3(x - HALF_GAP, 0, 0)
		var anim := MeshyProp.instance_rigged(path, native_h, TARGET_H, 0.0, true)
		add_child(anim)
		anim.global_position = Vector3(x + HALF_GAP, 0, 0)
		_pairs.append({"tag": tag, "x": x})
	_run()

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
	print("REMESH_TRIAL_AUDIT_SNAP ", ProjectSettings.globalize_path(path))

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(30)
	for pr in _pairs:
		var x: float = pr.x
		var tag: String = pr.tag
		# closer/tighter framing than rig_audit2 — this trial is judging the
		# waist/belly silhouette specifically, not the whole figure.
		_cam(Vector3(x, 1.7, 3.6), Vector3(x, 1.15, 0), 40.0)
		for k in 3:
			await _settle(50)
			await _snap("%s_phase_%d" % [tag, k])
	print("REMESH_TRIAL_AUDIT_DONE")
	get_tree().quit()
