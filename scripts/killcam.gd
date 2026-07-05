class_name Killcam
extends Node3D
## THE KILLCAM — a brief, skippable instant-replay of a ball's death, viewed from
## a low dramatic camera near the killing trap, crediting the trap's author.
##
## Presentation ONLY. It plays recorded transforms (Ball.get_replay_samples) on a
## throwaway visual clone; the real balls/traps/round state are never touched. In
## real windowed play `main` freezes the table with get_tree().paused while this
## runs (this node is PROCESS_MODE_ALWAYS), so no physics advances during the
## replay — the turn resumes exactly when the killcam ends. See killcam-VERIFY.md.

signal finished

const REPLAY_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BOT_SKIP_TIME := 0.4          # bot-only matches bail this fast (soaks stay quick)
const BORDER_PX := 7.0

var active := false
var _elapsed := 0.0
var _duration := 1.6
var _samples: Array = []            # Array[Transform3D] oldest -> newest
var _bot_only := false
var _restore_cam: Camera3D = null
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _look := Vector3.ZERO

var _cam: Camera3D
var _clone: MeshInstance3D
var _clone_mat: StandardMaterial3D
var _overlay: CanvasLayer
var _vignette: ColorRect
var _border: Array = []             # 4 ColorRects: top, bottom, left, right
var _banner: Label
var _tag: Label
var _skip_hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_camera()
	_build_clone()
	_build_overlay()
	_overlay.visible = false

func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.current = false
	add_child(_cam)

func _build_clone() -> void:
	_clone = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.15
	m.height = 0.3
	m.radial_segments = 24
	m.rings = 12
	_clone.mesh = m
	_clone_mat = StandardMaterial3D.new()
	_clone_mat.roughness = 0.3
	_clone_mat.emission_enabled = true
	_clone.material_override = _clone_mat
	_clone.visible = false
	add_child(_clone)

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 12
	add_child(_overlay)

	# Edge vignette — a full-screen dark radial falloff so the replay reads as a
	# framed cinematic moment.
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float inner = 0.35;
uniform float outer = 0.92;
uniform float strength = 0.88;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(inner, outer, d) * strength;
	COLOR = vec4(tint.rgb, v);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_vignette.material = sm
	_overlay.add_child(_vignette)

	# Thin author-colored frame (four edge bars).
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(frame)
	for i in 4:
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match i:
			0:  # top
				bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
				bar.custom_minimum_size = Vector2(0, BORDER_PX)
				bar.offset_bottom = BORDER_PX
			1:  # bottom
				bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				bar.offset_top = -BORDER_PX
			2:  # left
				bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
				bar.offset_right = BORDER_PX
			3:  # right
				bar.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
				bar.offset_left = -BORDER_PX
		frame.add_child(bar)
		_border.append(bar)

	# Author credit banner (bottom third), Luckiest Guy to match main's banners.
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_banner.anchor_top = 0.72
	_banner.anchor_bottom = 0.72
	_banner.offset_top = 0.0
	_banner.offset_bottom = 120.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_override("font", REPLAY_FONT)
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.0))
	_banner.add_theme_constant_override("outline_size", 10)
	_overlay.add_child(_banner)

	# "INSTANT REPLAY" tag, top-left.
	_tag = Label.new()
	_tag.position = Vector2(28, 22)
	_tag.text = "◉ INSTANT REPLAY"
	_tag.add_theme_font_override("font", REPLAY_FONT)
	_tag.add_theme_font_size_override("font_size", 22)
	_tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4))
	_tag.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.0))
	_tag.add_theme_constant_override("outline_size", 7)
	_overlay.add_child(_tag)

	# Skip hint, bottom-right.
	_skip_hint = Label.new()
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -260.0
	_skip_hint.offset_top = -44.0
	_skip_hint.offset_right = -20.0
	_skip_hint.offset_bottom = -14.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.text = "CLICK / SPACE TO SKIP ▸"
	_skip_hint.add_theme_font_size_override("font_size", 18)
	_skip_hint.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_skip_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	_skip_hint.add_theme_constant_override("outline_size", 5)
	_overlay.add_child(_skip_hint)

## Kick off a replay. `samples` are Transform3D snapshots oldest->newest (the
## victim's final motion). `look_pos` is the death point; `approach_dir` is the
## victim's horizontal heading at death (frames the low angle). Colors/banner
## carry the authorship credit. `restore_cam` is made current again on finish.
func play(samples: Array, look_pos: Vector3, approach_dir: Vector3,
		ball_color: Color, border_color: Color, show_border: bool,
		banner_text: String, duration: float, bot_only: bool,
		restore_cam: Camera3D) -> void:
	_samples = _trim_leading_still(samples)
	_look = look_pos
	_duration = maxf(0.3, duration)
	_bot_only = bot_only
	_restore_cam = restore_cam
	_elapsed = 0.0
	active = true

	# Compose a low, near-the-trap angle looking at the kill point.
	var dir := approach_dir
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = Vector3(0, 0, -1)
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.05:
		side = Vector3(1, 0, 0)
	_cam_from = look_pos - dir * 1.15 + side * 2.35 + Vector3(0, 0.6, 0)
	_cam_to = look_pos - dir * 0.7 + side * 1.7 + Vector3(0, 0.48, 0)   # subtle push-in
	_cam.global_position = _cam_from
	_cam.look_at(look_pos + Vector3(0, 0.1, 0), Vector3.UP)
	_cam.current = true

	# Clone at the first replay pose.
	_clone_mat.albedo_color = ball_color
	_clone_mat.emission = ball_color * 0.45
	if _samples.is_empty():
		_clone.global_position = look_pos
	else:
		var first: Transform3D = _samples[0]
		_clone.global_transform = first
	_clone.visible = true

	# Overlay dressing.
	_banner.text = banner_text
	_banner.add_theme_color_override("font_color", border_color if show_border else Color(0.9, 0.88, 0.82))
	for bar in _border:
		var cr: ColorRect = bar
		cr.color = border_color
		cr.visible = show_border
	_overlay.visible = true

func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	# Bot-only matches (soaks / demos) bail early so nothing drags.
	if _bot_only and _elapsed >= BOT_SKIP_TIME:
		stop()
		return
	if _elapsed >= _duration:
		stop()
		return
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	# Camera: gentle push-in over the replay.
	_cam.global_position = _cam_from.lerp(_cam_to, ease(t, 0.6))
	_cam.look_at(_look + Vector3(0, 0.1, 0), Vector3.UP)
	# Clone: play the recorded transforms across the replay window.
	if not _samples.is_empty():
		var n := _samples.size()
		if n == 1:
			var only: Transform3D = _samples[0]
			_clone.global_transform = only
		else:
			var f := t * float(n - 1)
			var i := int(floorf(f))
			var frac := f - float(i)
			var j := mini(i + 1, n - 1)
			var a: Transform3D = _samples[i]
			var b: Transform3D = _samples[j]
			_clone.global_transform = a.interpolate_with(b, frac)

func _unhandled_input(event: InputEvent) -> void:
	if not active or _bot_only:
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed:
		skip = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		stop()

func stop() -> void:
	if not active:
		return
	active = false
	_overlay.visible = false
	_clone.visible = false
	_cam.current = false
	if _restore_cam != null and is_instance_valid(_restore_cam):
		_restore_cam.current = true
	finished.emit()

## Drop leading frames where the ball had not yet moved, so the replay opens on
## motion rather than a stationary lie. Keeps a tail of at least a few frames.
func _trim_leading_still(samples: Array) -> Array:
	if samples.size() < 6:
		return samples
	var start := 0
	while start < samples.size() - 5:
		var a: Transform3D = samples[start]
		var b: Transform3D = samples[start + 1]
		if a.origin.distance_to(b.origin) > 0.012:
			break
		start += 1
	if start > 0:
		return samples.slice(start)
	return samples
