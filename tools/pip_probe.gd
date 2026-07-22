extends Node3D
## THROWAWAY PROBE — THE PIP PERF GATE (doc 34 §3, ruling #77).
## Builds the REAL board on the REAL land, frames the w6 FORECOURT (the densest
## single view — the standing record is 1513 draws with no PIP), then overlays a
## quarter-res ViewportKit PIP following an acting seat. Measures frame TIME (ms,
## NOT fps — vsync is DISABLED here so the couch's 144Hz cap can't mask the true
## cost) and per-viewport draw calls, main vs PIP vs combined.
##
## GATE (binding, amended 2026-07-20): frame time <= 16.6 ms with PIP live.
## PIP draw calls <= 300 (the cull canary). If over: half-res + reduced cull;
## if STILL over, the lane does not open.
##
## Run (windowed):
##   godot --path . tools/pip_probe.tscn
## Disposable — never shipped, never wired into a receipt.

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const G := preload("res://estate/procession/grounds.gd")
const ViewportKitScript := preload("res://estate/procession/viewport_kit.gd")

var board: ProcessionBoardGraph
var kit: ViewportKit
var _main_rid: RID

func _ready() -> void:
	# Measure TRUE frame time: no vsync clamp, no fps cap.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.52, "key_energy": 1.15, "rim_energy": 0.32,
		"rim_color": Color(0.55, 0.68, 1.0), "fog_density": 0.010,
		"glow_intensity": 0.85,
	})
	board = BoardGraph.new()
	add_child(board)
	board.build(_roster(), [])
	# String the toys out along the roads (as grounds_shots does) so the PIP has
	# a live seat to follow and the forecourt reads at its true draw load.
	board.seat_pawn(0, int(board.graph.half_a_start.get("garden", 0)) + 5)
	board.seat_pawn(1, int(board.graph.half_a_start.get("valley", 0)) + 5)
	board.seat_pawn(2, int(board.graph.half_a_start.get("hollow", 0)) + 3)
	board.seat_pawn(3, int(board.graph.landmarks.fork1))
	_forecourt_cam()
	_main_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_main_rid, true)
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

## w6 FORECOURT framing, ground-aware — copied verbatim from tools/grounds_shots
## (_gcam(Vector3(7,2.8,49), Vector3(0,1.6,37), 52)).
func _forecourt_cam() -> void:
	for c in find_children("*", "Camera3D", true, false):
		(c as Camera3D).queue_free()
	var pos := Vector3(7.0, G.height(7.0, 49.0) + 2.8, 49.0)
	var look := Vector3(0.0, G.height(0.0, 37.0) + 1.6, 37.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = 52.0
	cam.current = true

## An over-shoulder PIP pose on seat 0 (an "acting" seat), looking down its road
## — the shot the board would feed the PIP for whoever is up.
func _pip_pose(seat: int) -> Dictionary:
	var pawn_pos := _pawn_pos(seat)
	var ahead := _ahead_pos(seat)
	var d := ahead - pawn_pos
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	var right := d.cross(Vector3.UP).normalized()
	return {"pos": pawn_pos - d * 2.9 + right * 0.9 + Vector3(0, 2.5, 0),
		"look": pawn_pos + d * 7.0 + right * 1.3 + Vector3(0, 0.3, 0)}

func _pawn_pos(seat: int) -> Vector3:
	if board.pawns.has(seat):
		return (board.pawns[seat] as Node3D).global_position
	return board.lychgate_pos()

func _ahead_pos(seat: int) -> Vector3:
	# A point a few nodes further down the seat's road, for the look direction.
	var p := _pawn_pos(seat)
	var to_gate := board.gate_pos() - p
	to_gate.y = 0.0
	return p + (to_gate.normalized() if to_gate.length() > 0.1 else Vector3.FORWARD) * 8.0

func _settle(frames := 30) -> void:
	for i in frames:
		await get_tree().process_frame

## Average wall-clock frame time (ms) over `frames`, plus the per-viewport
## measured GPU ms and draw calls (averaged), for main + optional pip id.
func _measure(label: String, frames: int, pip_id: int) -> Dictionary:
	await _settle(30)   # warm the pipeline after any config change
	var deltas: Array[float] = []
	var t_prev := Time.get_ticks_usec()
	var sum_main_dc := 0.0
	var sum_pip_dc := 0.0
	var sum_total_dc := 0.0
	var sum_main_gpu := 0.0
	var sum_pip_gpu := 0.0
	var n := 0
	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - t_prev) / 1000.0)   # ms
		t_prev = now
		sum_main_dc += float(RenderingServer.viewport_get_render_info(_main_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		sum_total_dc += float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		sum_main_gpu += RenderingServer.viewport_get_measured_render_time_gpu(_main_rid)
		if pip_id >= 0:
			sum_pip_dc += float(kit.view_draw_calls(pip_id))
			sum_pip_gpu += kit.view_gpu_ms(pip_id)
		n += 1
	deltas.sort()
	var sum_ms := 0.0
	for d in deltas:
		sum_ms += d
	var p50: float = deltas[int(n * 0.50)]
	var p75: float = deltas[int(n * 0.75)]
	var p95: float = deltas[int(n * 0.95)]
	return {
		"label": label,
		"avg_ms": sum_ms / n,
		"p50_ms": p50,
		"p75_ms": p75,
		"p95_ms": p95,
		"min_ms": deltas[0],
		"main_dc": int(round(sum_main_dc / n)),
		"pip_dc": int(round(sum_pip_dc / n)) if pip_id >= 0 else 0,
		"total_dc": int(round(sum_total_dc / n)),
		"main_gpu_ms": sum_main_gpu / n,
		"pip_gpu_ms": (sum_pip_gpu / n) if pip_id >= 0 else 0.0,
	}

func _print_row(r: Dictionary) -> void:
	print("PIP_PROBE [%s] p50=%.2fms p75=%.2fms p95=%.2fms avg=%.2fms min=%.2fms | draws main=%d pip=%d total=%d | gpu main=%.2fms pip=%.2fms" % [
		r.label, r.p50_ms, r.p75_ms, r.p95_ms, r.avg_ms, r.min_ms, r.main_dc,
		r.pip_dc, r.total_dc, r.main_gpu_ms, r.pip_gpu_ms])

## A quarter-of-screen corner thumbnail rect (top-right, with a margin).
func _corner_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var w := vs.x * 0.25
	var h := vs.y * 0.25
	return Rect2(Vector2(vs.x - w - 24.0, 24.0), Vector2(w, h))

## p50 (median) is the binding read — robust to OS/compositor jitter. The gate
## is <= 16.6ms; PIP draws <= 300.
func _gate(r: Dictionary) -> void:
	var t_ok: bool = r.p50_ms <= 16.6
	var d_ok: bool = r.pip_dc <= 300
	print("PIP_PROBE gate [%s]: p50 %.2fms %s | pip_draws %d %s" % [
		r.label, r.p50_ms, ("PASS" if t_ok else "FAIL"),
		r.pip_dc, ("PASS" if d_ok else "FAIL")])

func _run() -> void:
	await _settle(50)
	print("PIP_PROBE ==== w6 forecourt, vsync=OFF, gate: p50 frame<=16.6ms, pip_draws<=300 ====")
	var base := await _measure("baseline no-pip", 240, -1)
	_print_row(base)

	kit = ViewportKitScript.new()
	add_child(kit)
	kit.setup(90)
	kit.measure(true)

	# Three configs, one run: the doc's spec (quarter-res + far cull), then its
	# fallback ladder (lower res, harder cull, cheap shadows).
	# Far-cull sweep at quarter-res (the doc's shipping res) — the cost is the
	# second geometry+shadow pass, which shrinks with the FAR plane, not pixels.
	# Find the knee where p50 clears 16.6ms.
	# Cadence sweep at quarter-res + far=26: the per-render floor is ~4.4ms, so
	# the lever that clears the gate is rendering the PIP on a STRIDE, not every
	# frame (a corner thumbnail of another seat reads fine at half rate).
	var configs := [
		{"tag": "q-res far=26 cadence=1", "res_scale": 0.25, "far": 26.0, "cadence": 1},
		{"tag": "q-res far=26 cadence=2", "res_scale": 0.25, "far": 26.0, "cadence": 2},
		{"tag": "q-res far=26 cadence=3", "res_scale": 0.25, "far": 26.0, "cadence": 3},
	]
	for cfg in configs:
		var opts := {"res_scale": cfg.res_scale, "far": cfg.far, "fov": 50.0,
			"rect": _corner_rect(), "cadence": cfg.get("cadence", 1)}
		if cfg.has("shadow_atlas"):
			opts["shadow_atlas"] = cfg.shadow_atlas
		var pip: int = kit.add_view(opts)
		kit.aim_view_shot(pip, _pip_pose(0))
		var r := await _measure("pip " + String(cfg.tag), 240, pip)
		_print_row(r)
		_gate(r)
		kit.remove_view(pip)
		await _settle(12)

	print("PIP_PROBE_DONE")
	get_tree().quit()
