extends Node3D
## THROWAWAY — NPC WIRING verify lane (rigging batch c2b1d5e wire-in).
## Builds the REAL board on the REAL land and poses close framings on every
## NPC this lane touched: the three re-rigged c243 idles (ferryman/widow/
## hooded mourner), the two NEW roster NPCs (mourner-for-hire, magpie), and
## the WAKE's spawn_mourner() crowd-fill call (normally only fired mid-match
## by procession.gd _fx_wake, invoked here directly for verification).
##
## Disposable — never shipped, never wired into a receipt. Does not modify
## board_graph.gd or procession.gd.
##
## Run (windowed, project-relative outdir):
##   godot --path . tools/npc_wiring_shots.tscn -- --outdir=verify_out/npc_wiring_shots

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const S := preload("res://estate/procession/board_spaces.gd")

var board: ProcessionBoardGraph
var out_dir := "verify_out/npc_wiring_shots"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			out_dir = arg.trim_prefix("--outdir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.55,
		"key_energy": 1.2,
		"rim_energy": 0.32,
		"rim_color": Color(0.55, 0.68, 1.0),
		"fog_density": 0.010,
		"glow_intensity": 0.85,
	})
	board = BoardGraph.new()
	add_child(board)
	board.build([], [])
	_run()

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
	print("NPC_WIRING_SNAP ", ProjectSettings.globalize_path(path))

func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame

## Elevated 3/4 framing that clears HEDGE_H (1.85m) regardless of whether the
## post sits in the open or tucked in a maze corridor: camera stands above the
## NPC and pulls back toward the path (-out), looking down at it.
func _npc_shot(npc_pos: Vector3, out: Vector3, tag: String) -> void:
	var cam_pos := npc_pos + Vector3(0, 2.6, 0) - out * 2.0
	_cam(cam_pos, npc_pos + Vector3(0, 1.0, 0), 46.0)
	await _settle(30); await _snap(tag)

func _run() -> void:
	await _settle(30)

	# 1) THE FERRYMAN — re-rigged c243 idle, valley toll (first ferry_toll node).
	var ferry_id := board.first_of_type(S.FERRY_TOLL)
	var f_here := board.space_pos(ferry_id)
	var f_out := board._outward(ferry_id)
	print("NPC_WIRING_POS ferryman ", f_here + f_out * 1.8, " in_maze=", ProcessionGrounds.in_maze((f_here + f_out * 1.8).x, (f_here + f_out * 1.8).z))
	await _npc_shot(f_here + f_out * 1.8, f_out, "01_ferryman_toll")

	# 2) THE GRAVEDIGGER — untouched this lane, context/regression check only.
	var dig_id := board._route_mid_id("hollow")
	var d_out := board._outward(dig_id)
	await _npc_shot(board.space_pos(dig_id) + d_out * 3.4, d_out, "02_gravedigger_context")

	# 3) THE WIDOW — re-rigged c243 idle, garden troupe post.
	var wid_id := board._route_mid_id("garden")
	var w_out := board._outward(wid_id)
	# matches the corridor-safe 1.2m offset board_graph.gd uses since #90
	var w_pos := board.space_pos(wid_id) + w_out * 1.2
	print("NPC_WIRING_POS widow ", w_pos, " in_maze=", ProcessionGrounds.in_maze(w_pos.x, w_pos.z))
	await _npc_shot(w_pos, w_out, "03_widow_troupe")
	# her elevated 3/4 view got walled in by the hedge maze corridor (pre-
	# existing _route_mid_id/_outward*3.2 placement, untouched this lane) —
	# a straight-down bird's eye clears any hedge (1.85m) regardless of
	# corridor width, to confirm the swapped c243 clip itself is clean.
	_cam(w_pos + Vector3(0.4, 5.5, 0.4), w_pos, 46.0)
	await _settle(30); await _snap("03b_widow_topdown")

	# 4) THE MOURNER-FOR-HIRE — NEW roster NPC, beside the broken angel.
	# (ground-snapped, matching the real placement in board_graph.gd exactly —
	# the raw const's y=0 is NOT the true terrain height here.)
	var fh: Vector3 = board._gsnap(BoardGraph.MOURNER_FORHIRE_POST)
	print("NPC_WIRING_POS mourner_forhire ", fh)
	_cam(fh + Vector3(3.4, 1.8, 3.4), fh + Vector3(0, 1.0, 0), 46.0)
	await _settle(30); await _snap("04_mourner_forhire")
	# a wider two-shot including the broken angel she stands beside
	_cam(fh + Vector3(5.5, 3.2, 6.0), board._gsnap(Vector3(-19.5, 0.0, 28.5)), 52.0)
	await _settle(30); await _snap("04b_mourner_forhire_wide_with_angel")

	# 5) THE MAGPIE — NEW roster NPC, perched atop the lychgate's signpost
	# (the hip-roof apex was tried first and rejected — any off-centre offset
	# landed inside the sloped tile shell; a post's simple silhouette is the
	# reliable perch).
	var lych := board.lychgate_pos()
	var post := board._gsnap(lych + Vector3(3.0, 0, 0.8))
	var perch := post + Vector3(0.0, 2.5, 0.0)
	print("NPC_WIRING_POS magpie ", perch)
	_cam(perch + Vector3(1.2, 0.6, 1.2), perch, 40.0)
	await _settle(30); await _snap("05_magpie_perch_close")
	_cam(lych + Vector3(4.6, 3.2, 7.2), lych + Vector3(0, 2.0, -1.0), 50.0)
	await _settle(30); await _snap("05b_lychgate_with_magpie_wide")

	# 6) THE WAKE's mourner crowd — spawn_mourner() itself (c243 hooded idle),
	# invoked directly since it normally only fires mid-match. Two either side
	# of an open-grave stone, matching _fx_wake's own call pattern.
	var wake_id := board.first_of_type(S.OPEN_GRAVE)
	var wpos := board.space_pos(wake_id)
	var m1 := board.spawn_mourner(wpos + Vector3(1.3, 0, 0.7), wpos)
	var m2 := board.spawn_mourner(wpos + Vector3(-1.3, 0, -0.7), wpos)
	if m1 == null or m2 == null:
		print("NPC_WIRING_WARN spawn_mourner returned null (asset missing) — see doctrine note")
	await _settle(20)
	_cam(wpos + Vector3(3.0, 2.2, 3.4), wpos + Vector3(0, 1.0, 0), 48.0)
	await _settle(30); await _snap("06_wake_hooded_mourners")

	print("NPC_WIRING_SHOTS_DONE")
	get_tree().quit()
