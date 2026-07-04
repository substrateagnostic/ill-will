extends Node
## Dev-only verification harness. Inert unless CLI user args are passed.
## Usage: godot --path . -- --shots=30,120,240 --autoputt=9.5,0,40 --outdir=verify_out
##   --shots      capture PNGs at these frame indices, quit after the last
##   --autoputt   power(m/s),angle_deg(0 = +Z toward cup),fire_at_frame
##   --outdir     directory relative to project root (default verify_out)

var shot_frames: Array[int] = []
var autoputts: Array = []
var out_dir := "verify_out"
var frame := 0
var active := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			for s in arg.trim_prefix("--shots=").split(","):
				shot_frames.append(int(s))
			active = true
		elif arg.begins_with("--autoputt="):
			var p := arg.trim_prefix("--autoputt=").split(",")
			if p.size() >= 3:
				autoputts.append({"power": float(p[0]), "angle": float(p[1]), "frame": int(p[2])})
		elif arg.begins_with("--aimshow="):
			var a := arg.trim_prefix("--aimshow=").split(",")
			if a.size() >= 3:
				autoputts.append({"power": float(a[0]), "angle": float(a[1]), "frame": int(a[2]), "aim_only": true})
		elif arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	if active:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))

func _process(_delta: float) -> void:
	if not active:
		return
	frame += 1
	for ap in autoputts:
		if ap.frame == frame:
			var pc := get_tree().current_scene.find_child("PuttController", true, false)
			if pc == null:
				continue
			if ap.get("aim_only", false):
				if pc.has_method("debug_show_aim"):
					pc.debug_show_aim(ap.power, ap.angle)
			elif pc.has_method("debug_putt"):
				pc.debug_putt(ap.power, ap.angle)
	if frame in shot_frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/shot_%04d.png" % [out_dir, frame]
		img.save_png(path)
		print("VERIFY_SHOT ", path)
		if frame >= shot_frames.max():
			print("VERIFY_DONE")
			get_tree().quit()
