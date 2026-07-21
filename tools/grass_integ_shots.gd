extends Node3D
## THROWAWAY capture lane — the LIVING LAWN integration stills. Builds the REAL
## board on the REAL land (shader-grass now IN grounds._dress_meadows) and poses
## the framings the taste review needs: the w6 forecourt STRESS shot (the
## draw-call watchline), a meadow mid, a close glancing skim, the whole-board
## overview, a bog mid, and a live TRAMPLE frame (two pawns walked onto the
## meadow so the real GrassField driver bends the blades). Prints draw calls per
## framing. Never shipped, never wired into a receipt.
##
##   godot --path . tools/grass_integ_shots.tscn -- --outdir=verify_out/grass_integ

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const G := preload("res://estate/procession/grounds.gd")

var board: ProcessionBoardGraph
var out_dir := "verify_out/grass_integ"

# a lush open meadow spot east of the garden loop (real land, real grass gate).
# Sits on the east flank of the authored swell (~45,6) where the drift runs thick.
const MEADOW := Vector2(49.0, 5.0)

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

func _gcam(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	var p := Vector3(pos.x, G.height(pos.x, pos.z) + pos.y, pos.z)
	var l := Vector3(look.x, G.height(look.x, look.z) + look.y, look.z)
	_cam(p, l, fov)

func _snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/%s.png" % [out_dir, tag]
	img.save_png(path)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("GRASS_SNAP %s draw_calls=%d prims=%dk" % [ProjectSettings.globalize_path(path), dc, prims / 1000])

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(24)
	# ---- w6 forecourt STRESS (the draw-call watchline; prior record 1510) ----
	_gcam(Vector3(7.0, 2.8, 49.0), Vector3(0.0, 1.6, 37.0), 52.0)
	await _settle(); await _snap("w6_forecourt")
	# ---- whole-board overview ----
	_cam(BoardGraph.OVERVIEW_POS, board.CENTER, 52.0)
	await _settle(); await _snap("overview")
	# ---- meadow mid ----
	_gcam(Vector3(MEADOW.x, 2.8, MEADOW.y + 12.0),
		Vector3(MEADOW.x, 0.5, MEADOW.y), 52.0)
	await _settle(); await _snap("meadow_mid")
	# ---- close glancing skim across the blade tops (shard-artifact case) ----
	# sit LOW inside the turf so blades fill the near frame at a raking angle
	_gcam(Vector3(MEADOW.x - 0.5, 0.55, MEADOW.y + 5.0),
		Vector3(MEADOW.x + 2.0, 0.40, MEADOW.y - 2.0), 56.0)
	await _settle(); await _snap("meadow_close_glancing")
	# ---- bog mid (short/olive/wet biome) ----
	_gcam(Vector3(-24.0, 2.4, 9.0), Vector3(-24.0, 0.2, -1.0), 52.0)
	await _settle(); await _snap("bog_mid")
	# ---- TRAMPLE: walk two pawns into the thick meadow, let GrassField bend it ----
	var c0 := Vector2(MEADOW.x - 0.5, MEADOW.y + 1.0)
	var c1 := Vector2(MEADOW.x + 1.5, MEADOW.y - 1.5)
	if board.pawns.has(0):
		(board.pawns[0] as Node3D).global_position = Vector3(c0.x, G.height(c0.x, c0.y), c0.y)
	if board.pawns.has(1):
		(board.pawns[1] as Node3D).global_position = Vector3(c1.x, G.height(c1.x, c1.y), c1.y)
	# close, low framing so the flattened rings at their feet read
	_gcam(Vector3(MEADOW.x + 0.5, 1.6, MEADOW.y + 6.5),
		Vector3(MEADOW.x, 0.3, MEADOW.y - 0.5), 50.0)
	await _settle(12); await _snap("meadow_trample")
	print("GRASS_SHOTS_DONE")
	get_tree().quit()
