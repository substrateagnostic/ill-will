class_name PlayerBadge
extends Control
## NEVER-COLOR-ALONE identity chip. Player identity in this anthology is a
## color (RED/GOLD/MINT/BLUE) — useless to a colorblind player on its own. This
## Control pairs every color with a SHAPE so identity travels as shape+color:
##
##   index 0 -> CIRCLE    index 2 -> SQUARE
##   index 1 -> TRIANGLE  index 3 -> DIAMOND
##
## Drawn procedurally in _draw() — no font, no textures, no glyph tofu risk.
## Filled with the player color, thin dark outline so it reads on any
## background. Sizing is driven by `size_px` (custom_minimum_size), so it drops
## straight into an HBox left of a name/score.
##
## One-liner HUD integration:
##   hbox.add_child(PlayerBadge.make(idx, 22))
## then optionally `badge.color = roster[idx].color` to match an exact palette.

enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }

## Fallback palette (mirrors GameState.PLAYER_COLORS) so the badge renders
## correctly even with no autoload — e.g. in an isolated probe scene.
const DEFAULT_COLORS: Array[Color] = [
	Color(0.92, 0.34, 0.30),  # 0 RED
	Color(0.25, 0.55, 0.90),  # 1 BLUE
	Color(0.95, 0.75, 0.20),  # 2 GOLD
	Color(0.30, 0.85, 0.60),  # 3 MINT
]
## Sentinel: color unset -> resolve from GameState/DEFAULT_COLORS at draw time.
const _UNSET := Color(-1, -1, -1, -1)

@export var player_index := 0:
	set(v):
		player_index = v
		queue_redraw()
@export var size_px := 22.0:
	set(v):
		size_px = maxf(4.0, v)
		custom_minimum_size = Vector2(size_px, size_px)
		queue_redraw()
## Explicit fill color. Leave unset to resolve from the player index.
@export var color: Color = _UNSET:
	set(v):
		color = v
		queue_redraw()
## 0..1 brightness for dead/eliminated states (1 = full, lower = darker).
@export_range(0.0, 1.0) var dim := 1.0:
	set(v):
		dim = clampf(v, 0.0, 1.0)
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the badge its natural size and vertically centered inside HBox rows
	# instead of stretching to the tallest sibling (which would distort shapes).
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(size_px, size_px)

func _resolve_color() -> Color:
	# HUD integration passes the exact roster color via `color`. When unset,
	# prefer the LIVE GameState palette (so colorblind palettes recolor badge
	# fills too); fall back to the static copy in probe/--script contexts
	# where autoloads don't exist.
	if color != _UNSET:
		return color
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root.has_node("GameState"):
		var cols: Array = (ml as SceneTree).root.get_node("GameState").PLAYER_COLORS
		if player_index >= 0 and player_index < cols.size():
			return cols[player_index]
	if player_index >= 0 and player_index < DEFAULT_COLORS.size():
		return DEFAULT_COLORS[player_index]
	return Color.WHITE

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		s = Vector2(size_px, size_px)
	var d := minf(s.x, s.y)
	var outline_w := maxf(1.5, d * 0.09)
	var fill := _resolve_color()
	if dim < 1.0:
		fill = fill.darkened(1.0 - dim)
	# Dark outline; nudge toward the fill's hue so it never looks like a sticker.
	var outline := Color(0.08, 0.07, 0.09, fill.a)
	var center := Vector2(s.x * 0.5, s.y * 0.5)
	# Inset so the outline stroke stays inside the control rect.
	var r := d * 0.5 - outline_w

	match player_index:
		1:  # TRIANGLE (point up)
			var pts := _triangle_points(center, r)
			draw_colored_polygon(pts, fill)
			_stroke_closed(pts, outline, outline_w)
		2:  # SQUARE
			var half := r * 0.92
			var rect := Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
			draw_rect(rect, fill, true)
			draw_rect(rect, outline, false, outline_w)
		3:  # DIAMOND
			var dpts := PackedVector2Array([
				center + Vector2(0, -r),
				center + Vector2(r, 0),
				center + Vector2(0, r),
				center + Vector2(-r, 0),
			])
			draw_colored_polygon(dpts, fill)
			_stroke_closed(dpts, outline, outline_w)
		_:  # 0 and any fallback -> CIRCLE
			draw_circle(center, r, fill)
			draw_circle(center, r, outline, false, outline_w, true)

func _triangle_points(center: Vector2, r: float) -> PackedVector2Array:
	# Equilateral-ish, pointing up, visually balanced inside the square rect.
	var top := center + Vector2(0, -r)
	var bl := center + Vector2(-r * 0.92, r * 0.78)
	var br := center + Vector2(r * 0.92, r * 0.78)
	return PackedVector2Array([top, br, bl])

func _stroke_closed(pts: PackedVector2Array, col: Color, w: float) -> void:
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	draw_polyline(loop, col, w, true)

# --- static helpers ----------------------------------------------------------

## "circle" | "triangle" | "square" | "diamond" for the given player index.
static func shape_name(p: int) -> String:
	match p:
		1: return "triangle"
		2: return "square"
		3: return "diamond"
		_: return "circle"

## Unicode shape glyph ● ▲ ■ ◆ for the given player index, for prefixing 3D
## Label3D name tags. VERIFIED to render (not tofu) in both Fredoka (project
## default) and LuckiestGuy — see docs/verify/badges-VERIFY.md.
static func glyph(p: int) -> String:
	match p:
		1: return "▲"
		2: return "■"
		3: return "◆"
		_: return "●"

## One-line HUD integration: `hbox.add_child(PlayerBadge.make(idx, 22))`.
static func make(p: int, badge_size: float) -> PlayerBadge:
	var b := PlayerBadge.new()
	b.player_index = p
	b.size_px = badge_size
	return b
