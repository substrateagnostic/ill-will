class_name ViewportKit
extends Node
## VIEWPORTKIT — a capped pool of extra SubViewport render targets (doc 34 §4).
##
## "Design once, use twice." The board PIP takes ONE view (quarter-res, tight
## far cull, corner thumbnail). Swap Meet's couch split-screen takes up to FOUR
## (full res, normal cull, tiled quadrants) — the one minigame that breaks the
## shared-camera rule on purpose. Same primitive underneath: a fixed pool of
## SubViewports with a HARD CAP, a per-view resolution scale, and per-view
## camera cull knobs (far plane + cull mask). One place to measure, one place
## to cap.
##
## CAMERA LAW (doc 34 §2, clause 4): every view here is its OWN Camera3D in its
## OWN SubViewport. The kit only ever poses ITS OWN cameras (aim_view). It never
## reads or writes the main camera, and nothing outside touches these. Two
## worlds, zero cross-writes — they cannot fight because they cannot touch.
##
## Determinism: a SubViewport renders nothing under headless (no DisplayServer),
## so an all-bot receipt is byte-identical whether the kit exists or not. The
## kit draws from no rng and no sim state.

## Hard cap on live render targets (the board takes 1, Swap Meet up to 4).
const MAX_VIEWS := 4

## One live render target: an off-screen SubViewport, its owning Camera3D, and
## an optional on-screen TextureRect that composites the render as a thumbnail.
class View extends RefCounted:
	var id: int = -1
	var viewport: SubViewport = null
	var camera: Camera3D = null
	var display: TextureRect = null   # null => API-only (renders, never shown)
	var res_scale: float = 0.25
	var cadence: int = 1              # render 1 of every N frames (1 = every frame)
	var _tick: int = 0
	var visible: bool = true

var _views: Dictionary = {}     # id -> View
var _next_id: int = 0
var _overlay: CanvasLayer = null
var _overlay_layer: int = 90
var _measuring := false

## Drive per-view update cadence. A thumbnail of another seat's turn reads fine
## at half rate; skipping the second render on alternate frames roughly halves
## the PIP's amortized frame-time cost (doc 34 §3 "let it be soft" / the
## fallback ladder's "PIP only during the roll phase", made gentler).
func _process(_delta: float) -> void:
	for id in _views:
		var v: View = _views[id]
		if v.cadence <= 1 or not v.visible or not is_instance_valid(v.viewport):
			continue
		v._tick += 1
		if v._tick >= v.cadence:
			v._tick = 0
			v.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Prepare the kit. `overlay_layer` is the CanvasLayer index the on-screen
## thumbnails composite on (high, so a PIP sits above the board but a
## full-screen director beat / ceremony scrim can still be raised above it).
func setup(overlay_layer := 90) -> void:
	_overlay_layer = overlay_layer

func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = _overlay_layer
	add_child(_overlay)

## Default shared world = the main window viewport's, so a view renders the SAME
## scene from another camera (no second scene, no second light rig).
func _main_world() -> World3D:
	var vp := get_viewport()
	return vp.find_world_3d() if vp != null else null

## Add a render target. Returns its id, or -1 if the cap is already full.
## opts (all optional):
##   world      : World3D  — shared world (defaults to the main viewport's)
##   res_scale  : float=0.25 — render size = main viewport size * res_scale
##   fov        : float=52.0
##   near       : float=0.05
##   far        : float=0.0  — camera far plane (0 keeps the engine default);
##                             a SHORT far is the PIP's first cull lever
##   cull_mask  : int=0      — camera visual-layer cull mask (0 keeps default,
##                             all layers); the PIP's second cull lever
##   rect       : Rect2      — on-screen footprint in px; omit for API-only
##   msaa       : int=Viewport.MSAA_DISABLED
func add_view(opts: Dictionary = {}) -> int:
	if _views.size() >= MAX_VIEWS:
		push_warning("ViewportKit: cap of %d views reached; add_view refused." % MAX_VIEWS)
		return -1
	var world: World3D = opts.get("world", _main_world())
	var res_scale: float = float(opts.get("res_scale", 0.25))
	var main_size := _main_size()
	var v := View.new()
	v.id = _next_id
	_next_id += 1
	v.res_scale = res_scale

	var sv := SubViewport.new()
	sv.name = "PipViewport%d" % v.id
	sv.size = Vector2i(maxi(1, int(round(main_size.x * res_scale))),
		maxi(1, int(round(main_size.y * res_scale))))
	sv.world_3d = world
	sv.own_world_3d = false
	sv.transparent_bg = false
	sv.msaa_3d = int(opts.get("msaa", Viewport.MSAA_DISABLED))
	# A thumbnail needs no crisp shadow atlas: shrink it hard so the PIP's
	# positional-shadow pass stays cheap (a lever below "far cull" for staying
	# under the frame-time gate). 0 leaves the engine default.
	var shadow_atlas: int = int(opts.get("shadow_atlas", 0))
	if shadow_atlas > 0:
		sv.positional_shadow_atlas_size = shadow_atlas
	# Own DEBUG draw stays off; no audio listener (the main viewport owns sound).
	sv.audio_listener_enable_3d = false
	add_child(sv)
	v.viewport = sv

	var cam := Camera3D.new()
	cam.fov = float(opts.get("fov", 52.0))
	cam.near = float(opts.get("near", 0.05))
	v.cadence = maxi(1, int(opts.get("cadence", 1)))
	var far: float = float(opts.get("far", 0.0))
	if far > 0.0:
		cam.far = far
	var cull_mask: int = int(opts.get("cull_mask", 0))
	if cull_mask != 0:
		cam.cull_mask = cull_mask
	sv.add_child(cam)
	cam.current = true   # sole camera of this SubViewport
	v.camera = cam

	if opts.has("rect"):
		_ensure_overlay()
		var tr := TextureRect.new()
		tr.texture = sv.get_texture()
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r: Rect2 = opts["rect"]
		tr.position = r.position
		tr.size = r.size
		_overlay.add_child(tr)
		v.display = tr

	if _measuring:
		RenderingServer.viewport_set_measure_render_time(sv.get_viewport_rid(), true)

	_views[v.id] = v
	_apply_update_mode(v)
	return v.id

## Resolve a view's render cadence into a SubViewport update mode. Hidden = off;
## every-frame = ALWAYS; strided = DISABLED here and pulsed to UPDATE_ONCE by
## _process on the cadence.
func _apply_update_mode(v: View) -> void:
	if not is_instance_valid(v.viewport):
		return
	if not v.visible:
		v.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif v.cadence <= 1:
		v.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		v.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_view_cadence(id: int, n: int) -> void:
	var v: View = _views.get(id, null)
	if v == null:
		return
	v.cadence = maxi(1, n)
	v._tick = 0
	_apply_update_mode(v)

func _main_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		var vs: Vector2 = vp.get_visible_rect().size
		if vs.x > 1.0 and vs.y > 1.0:
			return vs
	# Headless / pre-tree fallback: the project's configured window size.
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))

func has_view(id: int) -> bool:
	return _views.has(id)

func view_count() -> int:
	return _views.size()

func view_camera(id: int) -> Camera3D:
	var v: View = _views.get(id, null)
	return v.camera if v != null else null

func view_viewport(id: int) -> SubViewport:
	var v: View = _views.get(id, null)
	return v.viewport if v != null else null

## Pose a view's OWN camera. The kit never touches any camera but its own.
func aim_view(id: int, pos: Vector3, look: Vector3, up: Vector3 = Vector3.UP) -> void:
	var v: View = _views.get(id, null)
	if v == null or not is_instance_valid(v.camera):
		return
	v.camera.global_position = pos
	if pos.distance_to(look) > 0.001:
		v.camera.look_at(look, up)

## Feed a view an already-computed {pos, look} shot (board.reveal_shot shape).
func aim_view_shot(id: int, shot: Dictionary) -> void:
	aim_view(id, shot.get("pos", Vector3.ZERO), shot.get("look", Vector3.ZERO))

func set_view_visible(id: int, v: bool) -> void:
	var view: View = _views.get(id, null)
	if view == null:
		return
	view.visible = v
	if view.display != null and is_instance_valid(view.display):
		view.display.visible = v
	# Pause the render when hidden — a hidden PIP costs nothing.
	view._tick = 0
	_apply_update_mode(view)

func is_view_visible(id: int) -> bool:
	var view: View = _views.get(id, null)
	if view == null or view.display == null or not is_instance_valid(view.display):
		return false
	return view.display.visible

func set_display_rect(id: int, rect: Rect2) -> void:
	var v: View = _views.get(id, null)
	if v == null or v.display == null or not is_instance_valid(v.display):
		return
	v.display.position = rect.position
	v.display.size = rect.size

func remove_view(id: int) -> void:
	var v: View = _views.get(id, null)
	if v == null:
		return
	if v.display != null and is_instance_valid(v.display):
		v.display.queue_free()
	if is_instance_valid(v.viewport):
		v.viewport.queue_free()   # frees its child camera too
	_views.erase(id)

func clear() -> void:
	for id in _views.keys():
		remove_view(id)

# --------------------------------------------------------------------------
# PERF — one place to measure (doc 34 §3/§4). Draw calls are per-viewport;
# render time is opt-in per-viewport GPU/CPU milliseconds.
# --------------------------------------------------------------------------

## Enable/disable per-view render-time measurement for every current + future
## view (the SubViewports; the MAIN viewport is measured by the caller).
func measure(enable: bool) -> void:
	_measuring = enable
	for id in _views:
		var v: View = _views[id]
		if is_instance_valid(v.viewport):
			RenderingServer.viewport_set_measure_render_time(v.viewport.get_viewport_rid(), enable)

func view_draw_calls(id: int) -> int:
	var v: View = _views.get(id, null)
	if v == null or not is_instance_valid(v.viewport):
		return 0
	return RenderingServer.viewport_get_render_info(v.viewport.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)

func view_objects(id: int) -> int:
	var v: View = _views.get(id, null)
	if v == null or not is_instance_valid(v.viewport):
		return 0
	return RenderingServer.viewport_get_render_info(v.viewport.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)

func view_gpu_ms(id: int) -> float:
	var v: View = _views.get(id, null)
	if v == null or not is_instance_valid(v.viewport):
		return 0.0
	return RenderingServer.viewport_get_measured_render_time_gpu(v.viewport.get_viewport_rid())

func view_cpu_ms(id: int) -> float:
	var v: View = _views.get(id, null)
	if v == null or not is_instance_valid(v.viewport):
		return 0.0
	return RenderingServer.viewport_get_measured_render_time_cpu(v.viewport.get_viewport_rid())
