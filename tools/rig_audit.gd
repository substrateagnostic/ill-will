extends Node3D
## THROWAWAY — RIG DISEASE SURVEY. Same diagnostic pattern as
## tools/executor_lineup.gd (which caught the Executor's S-curve spine +
## in-hand tray driven through his face), run across every OTHER
## rigged/animated Meshy GLB in the game, to build the shopping list for a
## future batched re-rig. executor_butler_idle.glb is EXCLUDED (already
## diagnosed separately).
##
## For each model: a BIND POSE instance (animate=false) and an ANIMATING
## instance (animate=true) side by side, 4 units apart from the next pair.
## One camera framing per pair, 3 snaps ~50 frames apart so the animating
## twin is caught moving through several phases while the bind twin holds
## still for comparison.
##
## Disposable — never shipped, never wired into a receipt.
##
## Run (windowed):
##   godot --path . tools/rig_audit.tscn -- --outdir=verify_out/rig_audit

const GEN := "res://assets/models/meshy/generated/"
const TARGET_H := 1.8   # uniform across all — deformation is a proportion/
						 # rotation defect, invariant to overall scale, so one
						 # target height keeps every shot directly comparable.
const PAIR_SPACING := 4.0
const HALF_GAP := 1.0    # bind at pair_x - HALF_GAP, animating at pair_x + HALF_GAP

# (tag, glb, native_height_meters) — order matches the two rig-wave reports.
const MODELS := [
	["01_groundskeeper_idle", "npc_groundskeeper_idle.glb", 1.8],
	["02_mourner_elderly_idle", "npc_mourner_elderly_idle.glb", 1.65],
	["03_mourner_hooded_idle", "npc_mourner_hooded_idle.glb", 1.75],
	["04_mourner_hooded_bow", "npc_mourner_hooded_bow.glb", 1.75],
	["05_reaper_walk", "npc_reaper_walk.glb", 3.5],
	["06_reaper_sweep", "npc_reaper_sweep.glb", 3.5],
	["07_ferryman_idle", "npc_ferryman_idle.glb", 1.85],
	["08_gravedigger_idle", "npc_gravedigger_idle.glb", 1.7],
	["09_widow_idle", "npc_widow_idle.glb", 1.6],
]

var out_dir := "verify_out/rig_audit"
var _pairs: Array = []   # [{tag, x}]

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
	pm.size = Vector2(48, 48)
	ground.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.10, 0.12, 0.16)
	fm.roughness = 0.95
	ground.material_override = fm
	add_child(ground)

	for i in MODELS.size():
		var tag: String = MODELS[i][0]
		var glb: String = MODELS[i][1]
		var native_h: float = MODELS[i][2]
		var x := float(i) * PAIR_SPACING
		var path := GEN + glb
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
	print("RIG_AUDIT_SNAP ", ProjectSettings.globalize_path(path))

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
	print("RIG_AUDIT_DONE")
	get_tree().quit()
