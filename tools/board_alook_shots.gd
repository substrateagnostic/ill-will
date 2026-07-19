extends Node3D
## THROWAWAY capture lane AL — THE A-LOOK verification stills. Builds the REAL
## ProcessionBoardGraph (de-neoned ground surrounds, ring patterns, brightness
## heatmap, near-subliminal ribbons, ZERO-ENGLISH labels) and poses the four
## producer-requested framings, snapping each to PNG. Disposable — never shipped,
## never wired into a receipt. Presentation-only proof that the look reads.
##
## Run (windowed, project-relative outdir):
##   godot --path . tools/board_alook_shots.tscn -- --outdir=verify_out/board_alook
##
## Shots: a_overview · b_roll_heatmap · c_ring_patterns · d_crossroads_labels

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const S := preload("res://estate/procession/board_spaces.gd")
const RoadPrompt := preload("res://estate/procession/crossroads_prompt.gd")

var board: ProcessionBoardGraph
var _ui: CanvasLayer
var out_dir := "verify_out/board_alook"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	EnvKit.apply(self, EnvKit.MOONLIT)
	_ui = CanvasLayer.new()
	add_child(_ui)
	board = BoardGraph.new()
	add_child(board)
	var players := _roster()
	var monuments := [
		{"owner": "GOLD", "color": GameState.PLAYER_COLORS[2].to_html(false)},
		{"owner": "MINT", "color": GameState.PLAYER_COLORS[3].to_html(false)},
	]
	board.build(players, monuments)
	# String the four toys out along the road so the overview isn't bare.
	board.seat_pawn(0, board.graph.landmarks.fork1)
	board.seat_pawn(1, int(board.graph.half_a_start.get("garden", 0)) + 3)
	board.seat_pawn(2, int(board.graph.half_a_start.get("valley", 0)) + 2)
	board.seat_pawn(3, int(board.graph.half_a_start.get("hollow", 0)) + 4)
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

func _cam(pos: Vector3, look_at: Vector3, fov := 50.0) -> Camera3D:
	for c in find_children("*", "Camera3D", true, false):
		(c as Camera3D).queue_free()
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = pos
	cam.look_at(look_at, Vector3.UP)
	cam.fov = fov
	cam.current = true
	return cam

func _snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://%s/%s.png" % [out_dir, tag]
	img.save_png(path)
	print("ALOOK_SNAP ", ProjectSettings.globalize_path(path))

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	await _settle(10)

	# (a) OVERVIEW — the whole de-neoned board from the producer overview home.
	_cam(board.OVERVIEW_POS, board.CENTER, 52.0)
	await _settle(6)
	await _snap("a_overview")

	# (b) ROLL PHASE — the brightness heatmap live over a candidate stretch,
	# NO percents anywhere. Synthesize a d8 aim distribution down the garden road.
	var anchor := int(board.graph.half_a_start.get("garden", 0)) + 1
	var chain := _forward_chain(anchor, 8)
	var probs := [0.02, 0.06, 0.14, 0.26, 0.26, 0.16, 0.07, 0.03]
	var pmax := 0.26
	var entries: Array = []
	for k in chain.size():
		var p: float = probs[k] if k < probs.size() else 0.01
		entries.append({"node": chain[k], "face": k + 1, "p": p, "w": p / pmax})
	board.show_heatmap(entries, GameState.PLAYER_COLORS[0], true)   # crit prospect = sharpened
	var a0 := board.space_pos(chain[0])
	var a3 := board.space_pos(chain[min(3, chain.size() - 1)])
	var fdir := (a3 - a0)
	fdir.y = 0.0
	fdir = fdir.normalized() if fdir.length() > 0.1 else Vector3.FORWARD
	var right := fdir.cross(Vector3.UP).normalized()
	_cam(a0 - fdir * 3.0 + right * 1.4 + Vector3(0, 2.4, 0),
		board.space_pos(chain[min(5, chain.size() - 1)]) + Vector3(0, 0.2, 0), 48.0)
	# hold a few frames so the gentle pulse is mid-breath
	await _settle(14)
	board.show_heatmap(entries, GameState.PLAYER_COLORS[0], true)
	await _settle(2)
	await _snap("b_roll_heatmap")
	board.clear_heatmap()

	# (c) RING PATTERNS — a close pass centred on the first OPEN GRAVE (notched)
	# and its neighbours down WEEPING VALLEY, whose mix also packs offering(solid),
	# seance(dashed/beaded), grave_goods(double) and ferry_toll(gated) nearby, so
	# the distinct per-type patterns read side by side at couch distance.
	var grave := board.first_of_type(S.OPEN_GRAVE)
	var cchain := _forward_chain(grave, 6)
	var cen := Vector3.ZERO
	for nid in cchain:
		cen += board.space_pos(int(nid))
	cen /= float(cchain.size())
	# valley bulges to negative X — stand outboard on that side, low + raked.
	_cam(cen + Vector3(-5.6, 3.0, 3.0), cen + Vector3(0.6, 0.05, -0.4), 46.0)
	await _settle(8)
	await _snap("c_ring_patterns")

	# (d) CROSSROADS — the ONE place names legitimately appear: the 2D road
	# picker (route names) plus the in-world contextual label on the fork stone.
	var fork := int(board.graph.landmarks.fork1)
	var shot: Dictionary = board.reveal_shot(fork, S.CROSSROADS)
	_cam(shot.pos as Vector3, shot.look as Vector3, 50.0)
	board.show_landing_label(fork, GameState.PLAYER_COLORS[0])
	var prompt := RoadPrompt.new()
	_ui.add_child(prompt)
	prompt.open({"name": GameState.PLAYER_NAMES[0], "color": GameState.PLAYER_COLORS[0]},
		board.branch_options(fork))
	await _settle(10)
	await _snap("d_crossroads_labels")

	print("ALOOK_DONE")
	await _settle(2)
	get_tree().quit()

## Walk n stones forward from `start`, taking the first exit at any fork.
func _forward_chain(start: int, n: int) -> Array:
	var out: Array = [start]
	var cur := start
	while out.size() < n:
		var nxt: Array = board.next_of(cur)
		if nxt.is_empty():
			break
		cur = int(nxt[0])
		out.append(cur)
	return out
