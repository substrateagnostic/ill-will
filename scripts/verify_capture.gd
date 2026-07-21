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
var placetest := false
var _pt_frame := -1
var _pt_done := false
## --stealtest: during the first BUILD turn (expected to belong to a BOT), inject
## a synthetic mouse move + left click and log whether they drive the ghost /
## confirm the placement. Receipt for the "click fast enough and you can steal
## the bot's trap" bug: pre-fix the click places the trap at the mouse point;
## post-fix both events are inert and the bot's own scan placement stands.
var stealtest := false
var _st_state := 0
var _st_wait := 0
var out_dir := "verify_out"
var frame := 0
var active := false
var quit_after := 0
var trace_pos := false
## PAR v4: --swingplay routes --autoplay shots through the embodied swing
## (walk -> address -> charge -> contact-frame debug_putt) instead of calling
## debug_putt directly. Same numbers in; the byte-identical receipt diffs the
## two runs. --traceall logs every ball position EVERY physics tick (PTRACE) so
## the per-tick roll of a v3 shot and a v4 swing can be compared exactly,
## independent of when the stroke fired.
var swingplay := false
var trace_all := false
## --physputt=power,angle,tick[,power,angle,tick...] — fire debug_putt at EXACT
## physics ticks. Pairs a v3-direct run tick-for-tick against a v4 swing run
## (whose SWING_FIRE logs its tick), so powered-trap phases align and the diff
## isolates the interface: same tick + same numbers must equal same roll.
var physputts: Array = []
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
		elif arg == "--stealtest":
			stealtest = true
			active = true
		elif arg.begins_with("--quitafter="):
			quit_after = int(arg.trim_prefix("--quitafter="))
			active = true
		elif arg == "--tracepos":
			trace_pos = true
			active = true
		elif arg == "--swingplay":
			swingplay = true
			active = true
		elif arg.begins_with("--physputt="):
			var pp := arg.trim_prefix("--physputt=").split(",")
			var k := 0
			while k + 3 <= pp.size():
				physputts.append({"power": float(pp[k]), "angle": float(pp[k + 1]), "tick": int(pp[k + 2])})
				k += 3
			active = true
		elif arg == "--traceall":
			trace_all = true
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
	# The camera this frame ACTUALLY rendered with — drivers can be posed and
	# current yet not be the one on glass (the wrong-way-stills hunt).
	var vc := get_viewport().get_camera_3d()
	if vc != null:
		print("VERIFY_SNAP_CAM tag=%s cam=%s pos=%s fwd=%s" % [tag,
			str(vc.get_path()), str(vc.global_position),
			str(-vc.global_transform.basis.z)])
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
	if _pt_frame == 1:
		# Tee-exclusion receipt: parking the ghost ON tee 0 must read INVALID
		# (per-tee no-build zones). The drag overwrites the position right after.
		var tee: Vector3 = pc.course.tee_positions()[0]
		pc.ghost.move_placement(tee)
		pc._refresh()
		print("PLACETEST tee-probe at %s valid=%s" % [_v(tee), str(pc._valid)])
	var t: float = clampf(_pt_frame / 180.0, 0.0, 1.0)
	pc.ghost.global_position = Vector3(lerpf(0.0, 1.5, t), 0.0, lerpf(-2.0, -9.0, t))
	pc._refresh()
	if _pt_frame % 45 == 0 or t >= 1.0:
		_pt_report(pc.ghost, "drag t=%.2f" % t)
		# Windowed runs also snap the ghost mid-drag, so the rendered trap can be
		# eyeballed against the printed node positions (crusher pad/hammer report).
		if DisplayServer.get_name() != "headless":
			snap("placetest_%03d" % _pt_frame)
	if t >= 1.0:
		var placed: Node3D = pc.ghost
		if pc._valid:
			pc._confirm()
			print("PLACETEST confirmed")
		else:
			print("PLACETEST INVALID at final spot")
		get_tree().create_timer(1.0).timeout.connect(func(): _pt_report(placed, "1s after confirm"))
		_pt_done = true

func _run_stealtest(m: Node) -> void:
	if _st_state >= 4 or not m.has_method("get_phase_name"):
		return
	_st_wait -= 1
	if _st_wait > 0:
		return
	var pc: Node = m.find_child("PlacementController", false, false)
	if pc == null:
		return
	match _st_state:
		0:
			if m.get_phase_name() != "BUILD" or not pc.active or pc.ghost == null:
				return
			print("STEALTEST build turn open | ghost_at=%s placed_traps=%d screen_pt=%s cam=%s" % [_v(pc.ghost.global_position), _st_placed(pc), str(_st_screen_point(pc)), str(get_viewport().get_camera_3d().global_position)])
			var mm := InputEventMouseMotion.new()
			mm.position = _st_screen_point(pc)
			Input.parse_input_event(mm)
			_st_state = 1
			_st_wait = 5
		1:
			var alive: bool = pc.active and pc.ghost != null
			print("STEALTEST after synthetic MOUSE MOTION | ghost_at=%s ghost_alive=%s" % [_v(pc.ghost.global_position) if alive else "(gone)", str(alive)])
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = true
			mb.position = _st_screen_point(pc)
			Input.parse_input_event(mb)
			_st_state = 2
			_st_wait = 5
		2:
			var alive2: bool = pc.active and pc.ghost != null
			print("STEALTEST after synthetic CLICK | placed_traps=%d ghost_alive=%s" % [_st_placed(pc), str(alive2)])
			for t in pc.trap_container.get_children():
				if t is Trap and not t.is_ghost:
					print("STEALTEST placed trap %s author=%d at %s" % [t.trap_id, t.author_index, _v(t.global_position)])
			# Liveness tail: the current builder (a bot) must still complete its
			# OWN placement through debug_place_scan once its think delay fires.
			_st_state = 3
			_st_wait = 240
		3:
			print("STEALTEST bot-liveness | placed_traps=%d" % _st_placed(pc))
			for t in pc.trap_container.get_children():
				if t is Trap and not t.is_ghost:
					print("STEALTEST placed trap %s author=%d at %s" % [t.trap_id, t.author_index, _v(t.global_position)])
			_st_state = 4

## Screen point over a legal build spot: a point 2m short of the course center
## on the active camera. Unprojected so the receipt is camera-pose-agnostic.
func _st_screen_point(pc: Node) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var c: Vector3 = pc.course.course_center
	return cam.unproject_position(Vector3(c.x, 0.0, c.z + 2.0))

## Solid (non-ghost) traps on the course right now.
func _st_placed(pc: Node) -> int:
	var n := 0
	for t in pc.trap_container.get_children():
		if t is Trap and not t.is_ghost:
			n += 1
	return n

func _pt_report(trap: Node3D, tag: String) -> void:
	var parts := "PLACETEST %s | root=%s" % [tag, _v(trap.global_position)]
	for child_name in ["Pad", "Hammer", "Body", "Sides", "BladesBody", "Model"]:
		var c := trap.find_child(child_name, true, false)
		if c and c is Node3D:
			parts += " %s=%s" % [child_name, _v(c.global_position)]
	print(parts)

func _v(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]

func _v4(v: Vector3) -> String:
	return "(%.4f,%.4f,%.4f)" % [v.x, v.y, v.z]

## --traceall: every physics tick, every ball, 0.1mm resolution. The frozen-putt
## receipt extracts each ball's moving segment from two runs and byte-diffs.
func _physics_process(_delta: float) -> void:
	if not physputts.is_empty():
		var tick := Engine.get_physics_frames()
		for pp in physputts:
			if pp.tick == tick:
				var scene := get_tree().current_scene
				var pc := scene.find_child("PuttController", true, false) if scene else null
				if pc and pc.has_method("debug_putt"):
					pc.debug_putt(pp.power, pp.angle)
					print("VERIFY_PHYSPUTT fired p=%.1f a=%.1f tick=%d" % [pp.power, pp.angle, tick])
	if not trace_all:
		return
	var m := get_tree().current_scene
	if m == null or not "balls" in m or m.balls.is_empty():
		return
	var parts := "PTRACE t=%d" % Engine.get_physics_frames()
	for b in m.balls:
		# Resolved balls animate by wall-clock tween (sink dip, gutter sweep) —
		# presentation, not sim. Log a state marker so the receipt only ever
		# compares LIVE physics positions.
		if b.is_sunk:
			parts += " SUNK"
		elif b.is_dead:
			parts += " DEAD"
		elif b.is_petrified:
			parts += " PETRIFIED"
		elif b.in_transit:
			parts += " TRANSIT"
		else:
			parts += " %s" % _v4(b.global_position)
	print(parts)

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
	if stealtest:
		_run_stealtest(scene)
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
		if swingplay and _ap_cooldown <= 0 and main.has_method("is_swing_ready") and main.is_swing_ready():
			# v4 embodied route: the avatar has walked in and holds the address
			# stance; queue the exact same numbers through the swing.
			var sshot: Dictionary = autoplay.pop_front()
			if main.begin_auto_swing(sshot.power, sshot.angle):
				print("VERIFY_SWINGQUEUE p=%.1f a=%.1f frame=%d" % [sshot.power, sshot.angle, frame])
				_ap_cooldown = 30
			else:
				autoplay.push_front(sshot)
		elif not swingplay and _ap_cooldown <= 0 and main.has_method("is_turn_ready") and main.is_turn_ready():
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
