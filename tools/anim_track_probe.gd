extends Node3D
## THROWAWAY — animation track probe (ballooning-midsection investigation).
##
## Hypothesis under test: the rig_audit2 phase stills show the ANIMATING
## instance of every bind/animating pair (see tools/rig_audit2.gd) with a
## ballooned/stretched midsection that the static bind-pose twin does not
## have. Suspicion: Meshy's preset animation clips carry TYPE_SCALE_3D tracks
## on hip/spine/root bones that were authored against Meshy's own generic
## rig and retarget badly onto these stylized bodies.
##
## This tool does NOT render anything — it loads each candidate GLB, finds
## its AnimationPlayer, and for every animation walks every track. For each
## track it prints the node path + track type; for TYPE_SCALE_3D tracks it
## additionally walks every key and prints the min/max value per axis so we
## can see how far the scale swings from the neutral 1.0.
##
## Run (headless):
##   godot --headless --path . tools/anim_track_probe.tscn -- --outdir=verify_out/anim_track_probe
## Output goes to stdout (redirect to a log) AND a plain-text report file
## under --outdir for easy diffing/reading after the run.

const GEN := "res://assets/models/meshy/generated/"

# Same rigged candidate set as tools/rig_audit2.gd's RIGGED_CANDIDATES — the
# exact models whose animating stills showed the ballooning.
const CANDIDATES := [
	# scope add (producer, mid-run): ORIGINAL elderly mourner idle — the
	# "famous rubber-bending cane" — to test whether the cane's bend is the
	# same scale-track disease as the midsection ballooning hypothesis, or
	# something else. npc_mourner_elderly_v2_idle_c243.glb (below, already in
	# the base candidate set) is the cane-LESS regen, so it can't show the bug
	# either way — this is the one model that still carries the cane prop.
	"npc_mourner_elderly_idle.glb",
	"npc_ferryman_idle_c243.glb",
	"npc_ferryman_idle_c47.glb",
	"npc_mourner_hooded_idle_c243.glb",
	"npc_mourner_hooded_idle_c245.glb",
	"npc_mourner_hooded_bow_c42.glb",
	"npc_widow_idle_c243.glb",
	"executor_butler_v2_idle_c243.glb",
	"executor_butler_v2_idle_c47.glb",
	"npc_mourner_elderly_v2_idle_c243.glb",
	"npc_mourner_forhire_idle_c243.glb",
]

var out_dir := "verify_out/anim_track_probe"
var _report: Array[String] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))

	for glb in CANDIDATES:
		_probe(glb)

	var report_path := "res://%s/anim_track_report.txt" % out_dir
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f != null:
		for line in _report:
			f.store_line(line)
		f.close()
	print("ANIM_TRACK_PROBE_REPORT ", ProjectSettings.globalize_path(report_path))
	print("ANIM_TRACK_PROBE_DONE")
	get_tree().quit()

func _emit(line: String) -> void:
	print(line)
	_report.append(line)

func _probe(glb: String) -> void:
	var path := GEN + glb
	_emit("=== %s ===" % glb)
	if not ResourceLoader.exists(path):
		_emit("  MISSING: %s" % path)
		return
	var scene: PackedScene = load(path)
	if scene == null:
		_emit("  LOAD FAIL")
		return
	var model: Node3D = scene.instantiate()
	add_child(model)

	var anim_player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim_player == null:
		_emit("  no AnimationPlayer found")
		model.queue_free()
		return

	var anim_names := anim_player.get_animation_list()
	if anim_names.size() == 0:
		_emit("  AnimationPlayer has no animations")
		model.queue_free()
		return

	for anim_name in anim_names:
		var anim: Animation = anim_player.get_animation(anim_name)
		_emit("  animation '%s' (len=%.2fs, tracks=%d)" % [anim_name, anim.length, anim.get_track_count()])
		for ti in anim.get_track_count():
			var track_path := String(anim.track_get_path(ti))
			var ttype := anim.track_get_type(ti)
			var type_name := _type_name(ttype)
			var key_count := anim.track_get_key_count(ti)
			if ttype == Animation.TYPE_SCALE_3D:
				var mn := Vector3(INF, INF, INF)
				var mx := Vector3(-INF, -INF, -INF)
				for ki in key_count:
					var v: Vector3 = anim.track_get_key_value(ti, ki)
					mn = mn.min(v)
					mx = mx.max(v)
				var dev_x := maxf(absf(mn.x - 1.0), absf(mx.x - 1.0))
				var dev_y := maxf(absf(mn.y - 1.0), absf(mx.y - 1.0))
				var dev_z := maxf(absf(mn.z - 1.0), absf(mx.z - 1.0))
				var max_dev := maxf(dev_x, maxf(dev_y, dev_z))
				var flag := "  <-- DEVIATES >2%%" if max_dev > 0.02 else ""
				_emit("    [%2d] %-40s %-14s keys=%-3d min=(%.4f,%.4f,%.4f) max=(%.4f,%.4f,%.4f)%s" % [
					ti, track_path, type_name, key_count, mn.x, mn.y, mn.z, mx.x, mx.y, mx.z, flag
				])
			else:
				_emit("    [%2d] %-40s %-14s keys=%d" % [ti, track_path, type_name, key_count])
	model.queue_free()

func _type_name(t: int) -> String:
	match t:
		Animation.TYPE_POSITION_3D:
			return "POSITION_3D"
		Animation.TYPE_ROTATION_3D:
			return "ROTATION_3D"
		Animation.TYPE_SCALE_3D:
			return "SCALE_3D"
		Animation.TYPE_BLEND_SHAPE:
			return "BLEND_SHAPE"
		Animation.TYPE_VALUE:
			return "VALUE"
		Animation.TYPE_METHOD:
			return "METHOD"
		Animation.TYPE_BEZIER:
			return "BEZIER"
		Animation.TYPE_AUDIO:
			return "AUDIO"
		Animation.TYPE_ANIMATION:
			return "ANIMATION"
		_:
			return "UNKNOWN(%d)" % t
