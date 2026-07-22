extends Node3D
## THROWAWAY stills lane — THE PROCESSION CAMERA REWORK (#77, doc 34).
## Builds the REAL board and drives the REAL camera components (board_orbit the
## player follow, board_camera the ceremony director, viewport_kit the PIP) to
## capture the ruling's five states:
##   1 roll_follow      — the high Smite-pitch player orbit over the acting seat
##   2 pip_active       — main orbit surveys while the PIP holds the acting seat
##   3 movement_follow  — the orbit following a seat mid-road
##   4 fork_choice      — the orbit framing a seat AT a fork (plan the branch)
##   5 director_ceremony— the director commandeering the FULL frame (a two-shot)
##
## Run (windowed):
##   godot --path . tools/cam_rework_shots.tscn -- --outdir=verify_out/camera_rework
## Disposable — never shipped, never wired into a receipt.

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const BoardCamera := preload("res://estate/procession/board_camera.gd")
const BoardOrbitScript := preload("res://estate/procession/board_orbit.gd")
const ViewportKitScript := preload("res://estate/procession/viewport_kit.gd")

var board: ProcessionBoardGraph
var cam: Camera3D
var director: ProcessionCamera
var orbit: BoardOrbit
var kit: ViewportKit
var pip_id := -1
var out_dir := "verify_out/camera_rework"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.52, "key_energy": 1.15, "rim_energy": 0.32,
		"rim_color": Color(0.55, 0.68, 1.0), "fog_density": 0.010,
		"glow_intensity": 0.85,
	})
	board = BoardGraph.new()
	add_child(board)
	board.build(_roster(), [])
	# Seat the toys along the roads so every framing has a live figurine.
	board.seat_pawn(0, int(board.graph.half_a_start.get("garden", 0)) + 4)
	board.seat_pawn(1, int(board.graph.half_a_start.get("valley", 0)) + 6)
	board.seat_pawn(2, int(board.graph.half_a_start.get("hollow", 0)) + 3)
	board.seat_pawn(3, int(board.graph.landmarks.fork1))

	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.global_position = BoardGraph.OVERVIEW_POS
	cam.look_at(board.CENTER, Vector3.UP)
	cam.current = true

	director = BoardCamera.new()
	add_child(director)
	director.setup(cam, board, false)

	orbit = BoardOrbitScript.new()
	add_child(orbit)
	orbit.setup(cam, board, false)
	orbit.set_director(director)
	director.set_orbit(orbit)

	kit = ViewportKitScript.new()
	add_child(kit)
	kit.setup(90)
	pip_id = kit.add_view({"res_scale": 0.25, "far": 26.0, "fov": 50.0,
		"cadence": 1, "rect": _pip_rect()})   # cadence 1 here so a single frame renders
	kit.set_view_visible(pip_id, false)
	_run()

func _roster() -> Array:
	var out: Array = []
	var scenes := ["res://assets/models/kaykit/Barbarian.glb",
		"res://assets/models/kaykit/Knight.glb",
		"res://assets/models/kaykit/Mage.glb",
		"res://assets/models/kaykit/Rogue.glb"]
	for i in 4:
		out.append({"index": i, "name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i], "char_scene": scenes[i],
			"device": -1, "bot": true})
	return out

func _pip_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var w := vs.x * 0.25
	var h := vs.y * 0.25
	return Rect2(Vector2(vs.x - w - 24.0, 24.0), Vector2(w, h))

func _pawn(seat: int) -> Vector3:
	if board.pawns.has(seat):
		return (board.pawns[seat] as Node3D).global_position
	return board.space_pos(0)

## Aim the PIP over a seat's shoulder down its road (procession._pip_track).
func _pip_track(seat: int) -> void:
	var pawn_pos := _pawn(seat)
	var to_gate := board.gate_pos() - pawn_pos
	to_gate.y = 0.0
	var d := to_gate.normalized() if to_gate.length() > 0.1 else Vector3.FORWARD
	var right := d.cross(Vector3.UP).normalized()
	kit.aim_view(pip_id, pawn_pos - d * 3.2 + right * 1.0 + Vector3(0, 2.6, 0),
		pawn_pos + d * 6.0 + Vector3(0, 0.5, 0))

func _settle(frames := 48) -> void:
	for i in frames:
		await get_tree().process_frame

func _snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/%s.png" % [out_dir, tag]
	img.save_png(path)
	var vc := get_viewport().get_camera_3d()
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("CAMSHOT %s cam=%s pos=%s draws=%d" % [ProjectSettings.globalize_path(path),
		(vc.get_path() if vc else "none"), (str(vc.global_position) if vc else "-"), dc])

func _run() -> void:
	await _settle(30)

	# 1 — ROLL FOLLOW: the player orbit takes the frame over the acting seat.
	kit.set_view_visible(pip_id, false)
	orbit.follow_seat(2)
	orbit.activate()
	await _settle(60)   # let the exponential follow ease onto the pawn
	await _snap("cam1_roll_follow")

	# 2 — PIP ACTIVE: the player has orbited the main camera to SURVEY while the
	# PIP keeps the acting seat in view (plan while you watch, doc 34 §1).
	_pip_track(2)
	kit.set_view_visible(pip_id, true)
	orbit.follow_seat(0)
	orbit.survey()
	await _settle(60)
	await _snap("cam2_pip_active")

	# 3 — MOVEMENT FOLLOW: the orbit riding a seat further down its road.
	kit.set_view_visible(pip_id, false)
	orbit.follow_seat(1)
	await _settle(60)
	await _snap("cam3_movement_follow")

	# 4 — FORK CHOICE: the orbit framing a seat AT a fork, the branch ahead.
	orbit.follow_seat(3)   # seat 3 sits on fork1
	await _settle(60)
	await _snap("cam4_fork_choice")

	# 5 — DIRECTOR CEREMONY: the director commandeers the FULL frame (a vendetta
	# two-shot). board_camera.two_shot() activate()s, which yields the orbit.
	kit.set_view_visible(pip_id, false)
	director.two_shot(_pawn(0), _pawn(1))
	await _settle(60)
	await _snap("cam5_director_ceremony")

	print("CAMSHOTS_DONE (orbit_driving=%s director_driving=%s)" % [
		str(orbit.is_driving()), str(director._driving)])
	get_tree().quit()
