extends Node3D
## THROWAWAY capture lane — BIOME FILL wave 2 taste stills. Builds the REAL board
## on the REAL land and poses the framings the review needs:
##   forest floor mid + close (moss/leaf-litter, deadfall, brambles),
##   bog water mid + close + the bone-bridge crest (the water SHADER),
##   the boardwalk (routes/stones near water stay legible?),
##   the whole-board overview (the water-legibility verdict framing),
##   w6 forecourt (the draw-call watchline; prior record ~1513).
## Prints draw calls per framing. Never shipped, never wired into a receipt.
##
##   godot --path . tools/biome_shots.tscn -- --outdir=verify_out/biome2

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const G := preload("res://estate/procession/grounds.gd")

var board: ProcessionBoardGraph
var out_dir := "verify_out/biome2"

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
	# Seating matched to tools/grass_integ_shots.gd EXACTLY so the w6 forecourt
	# draw-call number is directly comparable to the grass-wave 1513 record
	# (isolates this wave's biome changes from pawn-placement noise). pawn1 on
	# the valley route also gives the boardwalk/water-edge legibility check.
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

## Ground-aware camera: y args are HEIGHTS ABOVE the land at that xz.
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
	print("BIOME_SNAP %s draw_calls=%d prims=%dk" % [ProjectSettings.globalize_path(path), dc, prims / 1000])

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(24)
	# ---- FOREST FLOOR: mid (moss + deadfall + brambles between the trunks) ----
	_gcam(Vector3(-3.0, 3.2, 15.0), Vector3(-11.0, 0.3, 3.0), 55.0)
	await _settle(); await _snap("forest_floor_mid")
	# ---- FOREST FLOOR: close low skim (read the moss/litter + a log + a bramble)
	_gcam(Vector3(-7.5, 0.9, 9.0), Vector3(-12.5, 0.30, 1.5), 60.0)
	await _settle(); await _snap("forest_floor_close")
	# ---- BOG WATER: mid, raking across the pond toward the deep dark centre ----
	_cam(Vector3(-27.0, 2.0, 7.0), Vector3(-40.0, -1.45, -9.0), 54.0)
	await _settle(); await _snap("bog_water_mid")
	# ---- BOG WATER: close low grazing (ripple normals, fresnel, shore blend) ----
	_cam(Vector3(-26.0, 0.15, 4.0), Vector3(-36.0, -1.50, -6.0), 58.0)
	await _settle(); await _snap("bog_water_close")
	# ---- THE BONE BRIDGE CREST: ribs breaking the surface (does it still read?) -
	_cam(Vector3(-29.5, 1.1, -9.0), Vector3(-37.5, -1.45, -15.7), 52.0)
	await _settle(); await _snap("bone_bridge_crest")
	# ---- THE BOARDWALK: a route/stone AT the water — legibility check ----
	_gcam(Vector3(-47.0, 2.2, 6.0), Vector3(-37.0, 0.0, -5.0), 54.0)
	await _settle(); await _snap("boardwalk_over_water")
	# ---- WHOLE-BOARD OVERVIEW: the water-legibility verdict framing ----
	_cam(BoardGraph.OVERVIEW_POS, board.CENTER, 52.0)
	await _settle(); await _snap("overview")
	# ---- w6 FORECOURT STRESS: the draw-call watchline ----
	_gcam(Vector3(7.0, 2.8, 49.0), Vector3(0.0, 1.6, 37.0), 52.0)
	await _settle(); await _snap("w6_forecourt")
	print("BIOME_SHOTS_DONE")
	get_tree().quit()
