class_name MBErrandHUD
extends Control
## Icon-only errand vignettes for THE CORONER. Each hidden guest gets a
## seat-colored strip: current errand large, the next two small, then pennies.
## No errand name is ever rendered; the ballroom props repeat these silhouettes.

const CLOCK := 0
const PUNCH := 1
const WEST := 2

var rows: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_rows(value: Array) -> void:
	rows = value.duplicate(true)
	queue_redraw()

func _draw() -> void:
	if rows.is_empty():
		return
	var left_y := 88.0
	var right_y := 88.0
	for row in rows:
		var seat := int(row.get("seat", 0))
		var right := seat == 1 or seat == 3
		var at := Vector2(size.x - 258.0, right_y) if right else Vector2(20.0, left_y)
		if right:
			right_y += 78.0
		else:
			left_y += 78.0
		_draw_row(at, row)

func _draw_row(at: Vector2, row: Dictionary) -> void:
	var col: Color = row.get("color", Color.WHITE)
	var rect := Rect2(at, Vector2(238, 66))
	draw_style_box(_panel(col), rect)
	var font := ThemeDB.fallback_font
	var glyph := str(row.get("glyph", "?"))
	draw_string(font, at + Vector2(10, 43), glyph, HORIZONTAL_ALIGNMENT_CENTER, 30, 26, col)
	var kinds: Array = row.get("kinds", [CLOCK, PUNCH, WEST])
	var centers := [at + Vector2(74, 33), at + Vector2(124, 33), at + Vector2(166, 33)]
	for j in mini(3, kinds.size()):
		var radius := 23.0 if j == 0 else 18.0
		var alpha := 1.0 if j == 0 else 0.42
		_draw_icon(centers[j], int(kinds[j]), radius, Color(0.95, 0.91, 0.75, alpha))
		if j == 0:
			var progress := clampf(float(row.get("progress", 0.0)), 0.0, 1.0)
			draw_arc(centers[j], radius + 4.0, -PI * 0.5,
				-PI * 0.5 + TAU * progress, 24, col, 4.0, true)
	# Pennies use the estate's established spade coin mark; the numeral is data,
	# not an English instruction.
	draw_circle(at + Vector2(213, 25), 15.0, Color(0.94, 0.72, 0.2, 0.95))
	draw_string(font, at + Vector2(201, 32), "♠", HORIZONTAL_ALIGNMENT_CENTER,
		24, 17, Color(0.14, 0.09, 0.05))
	draw_string(font, at + Vector2(198, 57), str(int(row.get("income", 0))),
		HORIZONTAL_ALIGNMENT_CENTER, 30, 16, Color.WHITE)

func _panel(col: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.025, 0.055, 0.86)
	box.border_color = Color(col.r, col.g, col.b, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(9)
	return box

func _draw_icon(c: Vector2, kind: int, r: float, col: Color) -> void:
	match kind:
		CLOCK:
			# Clock face + hands; the small chevron underneath is the bow.
			draw_arc(c - Vector2(0, 3), r * 0.58, 0, TAU, 24, col, 2.5, true)
			draw_line(c - Vector2(0, 3), c + Vector2(0, -r * 0.42), col, 2.4, true)
			draw_line(c - Vector2(0, 3), c + Vector2(r * 0.32, 1), col, 2.4, true)
			draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.36, r * 0.55), c + Vector2(0, r * 0.78),
				c + Vector2(r * 0.36, r * 0.55)]), col, 2.5, true)
		PUNCH:
			# Goblet/bowl + three linger beats.
			draw_arc(c - Vector2(0, 4), r * 0.58, 0.15, PI - 0.15, 18, col, 3.0, true)
			draw_line(c + Vector2(-r * 0.58, -2), c + Vector2(-r * 0.4, r * 0.28), col, 2.5)
			draw_line(c + Vector2(r * 0.58, -2), c + Vector2(r * 0.4, r * 0.28), col, 2.5)
			draw_line(c + Vector2(0, r * 0.28), c + Vector2(0, r * 0.58), col, 2.5)
			draw_line(c + Vector2(-r * 0.28, r * 0.62), c + Vector2(r * 0.28, r * 0.62), col, 2.5)
			for x in [-0.34, 0.0, 0.34]:
				draw_circle(c + Vector2(r * float(x), -r * 0.62), 2.0, col)
		WEST:
			# Three hall arches + a west-pointing waltz trail.
			for x in [-0.42, 0.0, 0.42]:
				var cc := c + Vector2(r * float(x), -2)
				draw_arc(cc, r * 0.28, PI, TAU, 10, col, 2.3, true)
				draw_line(cc + Vector2(-r * 0.28, 0), cc + Vector2(-r * 0.28, r * 0.62), col, 2.3)
				draw_line(cc + Vector2(r * 0.28, 0), cc + Vector2(r * 0.28, r * 0.62), col, 2.3)
			draw_polyline(PackedVector2Array([
				c + Vector2(r * 0.42, r * 0.65), c + Vector2(0, r * 0.48),
				c + Vector2(-r * 0.48, r * 0.7)]), col, 2.5, true)
			draw_line(c + Vector2(-r * 0.48, r * 0.7), c + Vector2(-r * 0.25, r * 0.48), col, 2.5)
			draw_line(c + Vector2(-r * 0.48, r * 0.7), c + Vector2(-r * 0.2, r * 0.78), col, 2.5)
