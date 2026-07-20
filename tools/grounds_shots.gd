extends Node3D
## THROWAWAY capture lane G1 — THE GROUNDS verification stills (doc 33).
## Builds the REAL board on the REAL land and poses two framings sets:
##   THE TEST STRETCH (producer-promised, reviewed FIRST): the hedge maze —
##     overhead read, corridor read, the mouth, a false branch.
##   THE LANDS: overview, boardwalk, bone bridge, hollow track, the climb,
##     forecourt, brook bridge, garden court.
## Disposable — never shipped, never wired into a receipt.
##
## Run (windowed, project-relative outdir):
##   godot --path . tools/grounds_shots.tscn -- --outdir=verify_out/g1_grounds

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const G := preload("res://estate/procession/grounds.gd")

var board: ProcessionBoardGraph
var out_dir := "verify_out/g1_grounds"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.52,
		"key_energy": 1.15,
		"rim_energy": 0.32,
		"rim_color": Color(0.55, 0.68, 1.0),
		"fog_density": 0.010,
		"glow_intensity": 0.85,
	})
	board = BoardGraph.new()
	add_child(board)
	board.build(_roster(), [])
	# String the toys out where the framings look: one mid-maze, one on the
	# boardwalk, one on the hollow track, one at the fork.
	board.seat_pawn(0, int(board.graph.half_a_start.get("garden", 0)) + 5)
	board.seat_pawn(1, int(board.graph.half_a_start.get("valley", 0)) + 5)
	board.seat_pawn(2, int(board.graph.half_a_start.get("hollow", 0)) + 3)
	board.seat_pawn(3, int(board.graph.landmarks.fork1))
	_run()

func _roster() -> Array:
	var out: Array = []
	for i in 4:
		out.append({
			"index": i, "name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": ["res://assets/models/kaykit/Barbarian.glb",
				"res://assets/models/kaykit/Knight.glb",
				"res://assets/models/kaykit/Mage.glb",
				"res://assets/models/kaykit/Rogue.glb"][i],
			"device": -1, "bot": true,
		})
	return out

func _cam(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	for c in find_children("*", "Camera3D", true, false):
		(c as Camera3D).queue_free()
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
	# doc 33 §6 frame-budget receipt: draw calls per framing (target < ~1500)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("G1_SNAP %s draw_calls=%d prims=%dk" % [ProjectSettings.globalize_path(path), dc, prims / 1000])

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

## Ground-aware camera: y args are HEIGHTS ABOVE the land at that xz.
func _gcam(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	var p := Vector3(pos.x, G.height(pos.x, pos.z) + pos.y, pos.z)
	var l := Vector3(look.x, G.height(look.x, look.z) + look.y, look.z)
	_cam(p, l, fov)

func _run() -> void:
	await _settle(20)
	# ---- THE TEST STRETCH (review first) ----
	_cam(Vector3(31, 48, 16), Vector3(31, 0, 0.5), 46.0)
	await _settle(); await _snap("t1_maze_overhead")
	_gcam(Vector3(33.25, 1.5, 14.0), Vector3(33.25, 0.7, 4.0), 58.0)
	await _settle(); await _snap("t2_maze_corridor")
	_gcam(Vector3(24.25, 1.9, 25.0), Vector3(24.25, 0.5, 16.0), 52.0)
	await _settle(); await _snap("t3_maze_mouth")
	_gcam(Vector3(23.0, 5.5, 21.0), Vector3(29.0, 0.0, 10.0), 50.0)
	await _settle(); await _snap("t4_maze_falsebranch")
	# ---- THE LANDS ----
	_cam(BoardGraph.OVERVIEW_POS, board.CENTER, 52.0)
	await _settle(); await _snap("w1_overview")
	_gcam(Vector3(-47.0, 2.2, 6.0), Vector3(-37.0, 0.0, -5.0), 54.0)
	await _settle(); await _snap("w2_boardwalk")
	_gcam(Vector3(-21.0, 4.5, -2.0), Vector3(-38.0, -1.4, -15.0), 50.0)
	await _settle(); await _snap("w3_dormant_bypass")
	_gcam(Vector3(-15.0, 2.6, 19.0), Vector3(-9.0, 0.3, 6.0), 54.0)
	await _settle(); await _snap("w4_hollow_track")
	_gcam(Vector3(-7.0, 3.0, -35.0), Vector3(0.0, 1.2, -54.0), 50.0)
	await _settle(); await _snap("w5_merge_climb")
	_gcam(Vector3(7.0, 2.8, 49.0), Vector3(0.0, 1.6, 37.0), 52.0)
	await _settle(); await _snap("w6_forecourt")
	_gcam(Vector3(31.0, 2.4, -35.0), Vector3(24.0, -0.5, -41.5), 52.0)
	await _settle(); await _snap("w7_brook_bridge")
	_cam(Vector3(1.0, 34.0, 4.0), Vector3(0.0, 0.0, -17.0), 52.0)
	await _settle(); await _snap("w8_fork_grammar")
	print("G1_SHOTS_DONE")
	get_tree().quit()
