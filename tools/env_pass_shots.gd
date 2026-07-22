extends Node3D
## THROWAWAY capture lane — the ENV PASS stills (thirteenth watch: Fable-3
## ground cover, bog banks, relief, outskirts). Builds the REAL board on the
## REAL land and poses the review framings: the meadow-to-path edge close (the
## ragged fringe + stubble), the bog bank (mud lip / tussocks / breakers), an
## outskirts horizon from a low camera (treeline + haze + gradient sky — the
## no-blue-box proof), the whole-board overview, and the w6 forecourt STRESS
## shot (the draw-call watchline). Prints draw calls per framing. Never shipped,
## never wired into a receipt.
##
##   godot --path . tools/env_pass_shots.tscn -- --outdir=verify_out/env_pass

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const G := preload("res://estate/procession/grounds.gd")

var board: ProcessionBoardGraph
var out_dir := "verify_out/env_pass"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	# the SAME env the procession's _build_world applies (sky + teal fog dials)
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.52,
		"key_energy": 1.15,
		"rim_energy": 0.32,
		"rim_color": Color(0.55, 0.68, 1.0),
		"bg_mode": "sky",
		"sky_ambient": false,
		"sky_top": Color(0.008, 0.014, 0.020),
		"sky_horizon": Color(0.052, 0.106, 0.102),
		"ground_horizon": Color(0.040, 0.078, 0.072),
		"ground_bottom": Color(0.008, 0.012, 0.012),
		"fog_color": Color(0.058, 0.104, 0.100),
		"fog_density": 0.011,
		"fog_aerial": 0.14,
		"fog_sky_affect": 0.5,
		"glow_intensity": 0.85,
	})
	board = BoardGraph.new()
	add_child(board)
	board.build(_roster(), [])
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
	print("ENV_SNAP %s draw_calls=%d prims=%dk" % [ProjectSettings.globalize_path(path), dc, prims / 1000])

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(24)
	# ---- w6 forecourt STRESS (the draw-call watchline; prior record ~1513) ----
	_gcam(Vector3(7.0, 2.8, 49.0), Vector3(0.0, 1.6, 37.0), 52.0)
	await _settle(); await _snap("w6_forecourt")
	# ---- whole-board overview (sky + fog + outskirts framing the estate) ----
	_cam(BoardGraph.OVERVIEW_POS, board.CENTER, 52.0)
	await _settle(); await _snap("overview")
	# ---- meadow-to-path edge CLOSE: the ragged fringe where turf meets the
	# garden gravel (fingers, worn dirt hem, stubble lapping the skirt) ----
	_gcam(Vector3(10.0, 1.5, 26.5), Vector3(15.5, 0.1, 20.0), 54.0)
	await _settle(); await _snap("meadow_path_edge")
	# ---- the bog BANK: mud lip, tussock ring, reeds, half-sunk breakers ----
	_gcam(Vector3(-13.0, 2.2, 3.5), Vector3(-27.0, -1.3, -6.0), 52.0)
	await _settle(); await _snap("bog_bank")
	# ---- outskirts horizon, LOW camera: treeline + haze + gradient sky (the
	# no-blue-box proof — the frame must end in atmosphere). From the east
	# meadow rise, over open turf, past the maze's north shoulder ----
	_gcam(Vector3(44.0, 2.6, 16.0), Vector3(110.0, 14.0, 4.0), 58.0)
	await _settle(); await _snap("outskirts_horizon_east")
	# ---- and the west look across the bog toward the ridge + treeline ----
	_gcam(Vector3(-4.0, 2.6, -6.0), Vector3(-85.0, 10.0, -14.0), 56.0)
	await _settle(); await _snap("outskirts_horizon_west")
	print("ENV_SHOTS_DONE")
	get_tree().quit()
