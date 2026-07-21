extends Node3D
## THROWAWAY — RIGGING BATCH audit (producer-approved wave, 2026-07-20).
## Same bind-vs-animating pair pattern as tools/rig_audit.gd, extended to the
## new candidate set from this batch: calmer preset idles for ferryman /
## mourner_hooded / widow (replacing the action_id=0 hip-swagger clip found by
## the executor audition), plus the tray-less butler regen, cane-less elderly
## mourner regen, and the new mourner-for-hire. A second row shows the
## static-only new assets (magpie, cane prop, tray prop, and the three new
## character statics before rigging) with a single still each.
##
## Disposable — never shipped, never wired into a receipt. Does not modify
## tools/rig_audit.gd.
##
## Run (windowed):
##   godot --path . tools/rig_audit2.tscn -- --outdir=verify_out/rig_audit2

const GEN := "res://assets/models/meshy/generated/"
const TARGET_H := 1.8   # uniform across all rigged pairs — see tools/rig_audit.gd
const PAIR_SPACING := 4.0
const HALF_GAP := 1.0

# (tag, glb, native_height_meters) — rigged candidates from this batch.
const RIGGED_CANDIDATES := [
	["01_ferryman_idle_c243", "npc_ferryman_idle_c243.glb", 1.85],
	["02_ferryman_idle_c47", "npc_ferryman_idle_c47.glb", 1.85],
	["03_hooded_idle_c243", "npc_mourner_hooded_idle_c243.glb", 1.75],
	["04_hooded_idle_c245", "npc_mourner_hooded_idle_c245.glb", 1.75],
	["05_hooded_bow_c42", "npc_mourner_hooded_bow_c42.glb", 1.75],
	["06_widow_idle_c243", "npc_widow_idle_c243.glb", 1.6],
	["07_butler_v2_idle_c243", "executor_butler_v2_idle_c243.glb", 1.9],
	["08_butler_v2_idle_c47", "executor_butler_v2_idle_c47.glb", 1.9],
	["09_elderly_v2_idle_c243", "npc_mourner_elderly_v2_idle_c243.glb", 1.65],
	["10_forhire_idle_c243", "npc_mourner_forhire_idle_c243.glb", 1.7],
]

# (tag, glb, target_height) — static-only new assets, single still each.
const STATIC_ONLY := [
	["s1_butler_v2_static", "executor_butler_v2.glb", 1.9],
	["s2_elderly_v2_static", "npc_mourner_elderly_v2.glb", 1.65],
	["s3_forhire_static", "npc_mourner_forhire.glb", 1.7],
	["s4_magpie", "npc_magpie.glb", 0.28],
	["s5_cane_prop", "prop_cane_wooden.glb", 0.9],
	["s6_tray_prop", "prop_serving_tray_silver.glb", 0.35],
	["s7_elderly_v3_static_RETRY", "npc_mourner_elderly_v3.glb", 1.65],
]

var out_dir := "verify_out/rig_audit2"
var _pairs: Array = []      # [{tag, x}] rigged pairs
var _statics: Array = []    # [{tag, x}] static-only singles

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
	pm.size = Vector2(64, 64)
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
			print("RIG_AUDIT2_MISSING ", path)
			continue
		var bind := MeshyProp.instance_rigged(path, native_h, TARGET_H, 0.0, false)
		add_child(bind)
		bind.global_position = Vector3(x - HALF_GAP, 0, 0)
		var anim := MeshyProp.instance_rigged(path, native_h, TARGET_H, 0.0, true)
		add_child(anim)
		anim.global_position = Vector3(x + HALF_GAP, 0, 0)
		_pairs.append({"tag": tag, "x": x})

	var static_row_z := -8.0
	var static_x0 := 0.0
	for i in STATIC_ONLY.size():
		var tag: String = STATIC_ONLY[i][0]
		var glb: String = STATIC_ONLY[i][1]
		var h: float = STATIC_ONLY[i][2]
		var path := GEN + glb
		if not ResourceLoader.exists(path):
			print("RIG_AUDIT2_MISSING ", path)
			continue
		var x := static_x0 + float(i) * 3.0
		var inst := MeshyProp.instance(path, h)
		add_child(inst)
		inst.global_position = Vector3(x, 0, static_row_z)
		_statics.append({"tag": tag, "x": x, "z": static_row_z})
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
	print("RIG_AUDIT2_SNAP ", ProjectSettings.globalize_path(path))

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(30)
	for pr in _pairs:
		var x: float = pr.x
		var tag: String = pr.tag
		_cam(Vector3(x, 2.2, 5.5), Vector3(x, 1.5, 0))
		for k in 3:
			await _settle(50)
			await _snap("%s_phase_%d" % [tag, k])
	for st in _statics:
		var x: float = st.x
		var z: float = st.z
		var tag: String = st.tag
		_cam(Vector3(x, 1.8, z + 3.2), Vector3(x, 1.0, z))
		await _settle(20)
		await _snap(tag)
	print("RIG_AUDIT2_DONE")
	get_tree().quit()
