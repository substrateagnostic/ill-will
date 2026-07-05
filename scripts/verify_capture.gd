extends Node
## Dev-only verification harness. Inert unless CLI user args are passed.
## Usage: godot --path . -- --shots=30,120,240 --autoputt=9.5,0,40 --outdir=verify_out
##   --shots      capture PNGs at these frame indices, quit after the last
##   --autoputt   power(m/s),angle_deg(0 = +Z toward cup),fire_at_frame
##   --outdir     directory relative to project root (default verify_out)

var shot_frames: Array[int] = []
var autoputts: Array = []
var autoplay: Array = []
var autobuild := false
var auctiontest := false
var _at_state := 0
var placetest := false
var _pt_frame := -1
var _pt_done := false
var out_dir := "verify_out"
var frame := 0
var active := false
var quit_after := 0
var trace_pos := false
var _ap_cooldown := 0

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
		elif arg.begins_with("--autoplay="):
			for pair in arg.trim_prefix("--autoplay=").split(","):
				var pa := pair.split(":")
				autoplay.append({"power": float(pa[0]), "angle": float(pa[1]) if pa.size() > 1 else 0.0})
			active = true
		elif arg == "--autobuild":
			autobuild = true
			active = true
		elif arg == "--placetest":
			placetest = true
			active = true
		elif arg == "--auctiontest":
			auctiontest = true
			active = true
		elif arg.begins_with("--quitafter="):
			quit_after = int(arg.trim_prefix("--quitafter="))
			active = true
		elif arg == "--tracepos":
			trace_pos = true
			active = true
		elif arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	if active:
		# Keep counting/capturing while the tree is paused (ESC settings shots).
		process_mode = Node.PROCESS_MODE_ALWAYS
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))

## Event-driven capture: game code calls this at moments worth a picture
## (e.g. the will reading). Inert unless the harness is active.
func snap(tag: String) -> void:
	if not active:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/snap_%s_%04d.png" % [out_dir, tag, frame]
	img.save_png(path)
	print("VERIFY_SNAP ", path)

func _run_placetest() -> void:
	var m := get_tree().current_scene
	if not m.has_method("get_phase_name"):
		return
	if m.get_phase_name() == "DRAFT" and _pt_frame < 0:
		m.debug_pick_card(0)
		_pt_frame = 0
		return
	if m.get_phase_name() != "BUILD" or _pt_frame < 0:
		return
	var pc: Node = m.find_child("PlacementController", false, false)
	if pc == null or not pc.active or pc.ghost == null:
		return
	_pt_frame += 1
	var t: float = clampf(_pt_frame / 180.0, 0.0, 1.0)
	pc.ghost.global_position = Vector3(lerpf(0.0, 1.5, t), 0.0, lerpf(-2.0, -9.0, t))
	pc._refresh()
	if _pt_frame % 45 == 0 or t >= 1.0:
		_pt_report(pc.ghost, "drag t=%.2f" % t)
	if t >= 1.0:
		var placed: Node3D = pc.ghost
		if pc._valid:
			pc._confirm()
			print("PLACETEST confirmed")
		else:
			print("PLACETEST INVALID at final spot")
		get_tree().create_timer(1.0).timeout.connect(func(): _pt_report(placed, "1s after confirm"))
		_pt_done = true

func _pt_report(trap: Node3D, tag: String) -> void:
	var parts := "PLACETEST %s | root=%s" % [tag, _v(trap.global_position)]
	for child_name in ["Pad", "Hammer", "Body", "Sides", "BladesBody", "Model"]:
		var c := trap.find_child(child_name, true, false)
		if c and c is Node3D:
			parts += " %s=%s" % [child_name, _v(c.global_position)]
	print(parts)

func _v(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]

func _process(_delta: float) -> void:
	if not active:
		return
	frame += 1
	var scene := get_tree().current_scene
	if scene == null:
		return
	for ap in autoputts:
		if ap.frame == frame:
			var pc := scene.find_child("PuttController", true, false)
			if pc == null:
				continue
			if ap.get("aim_only", false):
				if pc.has_method("debug_show_aim"):
					pc.debug_show_aim(ap.power, ap.angle)
			elif pc.has_method("debug_putt"):
				pc.debug_putt(ap.power, ap.angle)
	if trace_pos and frame % 6 == 0:
		var m := get_tree().current_scene
		if m != null and "balls" in m and not m.balls.is_empty():
			var parts := "TRACE f=%d" % frame
			for b in m.balls:
				parts += " %s" % _v(b.global_position)
			print(parts)
	if placetest and not _pt_done:
		_run_placetest()
	if auctiontest and scene.has_method("get_phase_name"):
		_ap_cooldown -= 1
		if _at_state == 0 and scene.get_phase_name() == "AUCTION" and _ap_cooldown <= 0:
			scene._on_bid(0)
			print("AUCTIONTEST bid placed as P0, high_bid=", scene.high_bid, " bidder=", scene.high_bidder)
			_at_state = 1
			_ap_cooldown = 30
		elif _at_state == 1 and scene.get_phase_name() == "CHOOSING" and _ap_cooldown <= 0:
			var btns: Array = []
			for row in scene.phase_box.get_children():
				if row is HBoxContainer:
					for b in row.get_children():
						if b is Button:
							btns.append(b)
			if btns.size() > 0:
				print("AUCTIONTEST clicking game button: ", btns[0].text)
				btns[0].pressed.emit()
				_at_state = 2
			else:
				print("AUCTIONTEST FAIL: no game buttons in CHOOSING panel")
				_at_state = 3
		elif _at_state == 2 and scene.get_phase_name() == "GAME":
			print("AUCTIONTEST PASS: game launched via clicked button")
			_at_state = 3
	if autobuild:
		var m := scene
		if m.has_method("get_phase_name"):
			_ap_cooldown -= 1
			if _ap_cooldown <= 0 and m.get_phase_name() == "DRAFT":
				m.debug_pick_card(0)
				print("VERIFY_DRAFT picked frame=", frame)
				_ap_cooldown = 40
			elif _ap_cooldown <= 0 and m.get_phase_name() == "BUILD":
				m.debug_place_auto()
				print("VERIFY_BUILD placed frame=", frame)
				_ap_cooldown = 40
	if not autoplay.is_empty():
		_ap_cooldown -= 1
		var main := scene
		if _ap_cooldown <= 0 and main.has_method("is_turn_ready") and main.is_turn_ready():
			var pc := main.find_child("PuttController", true, false)
			if pc:
				var shot: Dictionary = autoplay.pop_front()
				pc.debug_putt(shot.power, shot.angle)
				print("VERIFY_AUTOPLAY fired p=%.1f a=%.1f frame=%d" % [shot.power, shot.angle, frame])
				_ap_cooldown = 30
	if frame in shot_frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/shot_%04d.png" % [out_dir, frame]
		img.save_png(path)
		print("VERIFY_SHOT ", path)
		if not shot_frames.is_empty() and frame >= shot_frames.max() and quit_after == 0:
			print("VERIFY_DONE")
			get_tree().quit()
	if quit_after > 0 and frame >= quit_after:
		print("VERIFY_DONE")
		get_tree().quit()
