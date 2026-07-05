class_name LWCardIcon
extends Control
## Hand-drawn card glyphs for the will draft (no external art needed).
## kinds: shield / swift / coin / sluggish / butterfingers / haunted.
## Drawn in the accent color with a dark under-stroke so they pop on parchment.

var kind := "shield"
var accent := Color(1.0, 0.85, 0.35)

func set_icon(k: String, a: Color) -> void:
	kind = k
	accent = a
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var dark := Color(0.08, 0.06, 0.05, 0.9)
	match kind:
		"shield":
			var pts := PackedVector2Array()
			for p in [Vector2(0, -0.42), Vector2(0.34, -0.3), Vector2(0.34, 0.05),
					Vector2(0, 0.44), Vector2(-0.34, 0.05), Vector2(-0.34, -0.3)]:
				pts.append(c + p * s)
			draw_colored_polygon(pts, dark)
			var pts2 := PackedVector2Array()
			for p in pts:
				pts2.append(c + (p - c) * 0.86)
			draw_colored_polygon(pts2, accent)
			var pts3 := PackedVector2Array()
			for p in pts:
				pts3.append(c + (p - c) * 0.55)
			draw_colored_polygon(pts3, dark.lerp(accent, 0.25))
		"swift":
			var bolt := PackedVector2Array()
			for p in [Vector2(0.1, -0.45), Vector2(-0.22, 0.05), Vector2(-0.02, 0.05),
					Vector2(-0.12, 0.45), Vector2(0.24, -0.08), Vector2(0.02, -0.08)]:
				bolt.append(c + p * s)
			var shadow := PackedVector2Array()
			for p in bolt:
				shadow.append(p + Vector2(2, 3))
			draw_colored_polygon(shadow, dark)
			draw_colored_polygon(bolt, accent)
		"coin":
			draw_circle(c + Vector2(2, 3), s * 0.36, dark)
			draw_circle(c, s * 0.36, accent)
			draw_arc(c, s * 0.27, 0, TAU, 40, dark, s * 0.035)
			# "1" engraved
			var w := s * 0.05
			draw_line(c + Vector2(-s * 0.05, -s * 0.1), c + Vector2(0, -s * 0.16), dark, w)
			draw_line(c + Vector2(0, -s * 0.16), c + Vector2(0, s * 0.16), dark, w)
			draw_line(c + Vector2(-s * 0.08, s * 0.16), c + Vector2(s * 0.08, s * 0.16), dark, w)
		"sluggish":
			# three heavy downward chevrons
			for i in 3:
				var y := (-0.26 + i * 0.24) * s
				var col := accent.darkened(i * 0.12)
				var w2 := s * 0.09
				draw_line(c + Vector2(-s * 0.3, y - s * 0.08), c + Vector2(0, y + s * 0.08), dark, w2 + 3)
				draw_line(c + Vector2(0, y + s * 0.08), c + Vector2(s * 0.3, y - s * 0.08), dark, w2 + 3)
				draw_line(c + Vector2(-s * 0.3, y - s * 0.08), c + Vector2(0, y + s * 0.08), col, w2)
				draw_line(c + Vector2(0, y + s * 0.08), c + Vector2(s * 0.3, y - s * 0.08), col, w2)
		"butterfingers":
			# a dropped ball slipping from an open hand: palm arc + falling circle + X
			draw_arc(c + Vector2(0, -s * 0.16), s * 0.24, PI * 0.15, PI * 0.85, 24, dark, s * 0.1)
			draw_arc(c + Vector2(0, -s * 0.16), s * 0.24, PI * 0.15, PI * 0.85, 24, accent, s * 0.07)
			draw_circle(c + Vector2(s * 0.02, s * 0.14), s * 0.13, dark)
			draw_circle(c + Vector2(s * 0.0, s * 0.12), s * 0.13, accent.lightened(0.2))
			var xw := s * 0.07
			var xr := s * 0.3
			var xc := c + Vector2(0, s * 0.12)
			draw_line(xc + Vector2(-xr, -xr), xc + Vector2(xr, xr), Color(0.85, 0.15, 0.1, 0.95), xw)
			draw_line(xc + Vector2(xr, -xr), xc + Vector2(-xr, xr), Color(0.85, 0.15, 0.1, 0.95), xw)
		"haunted":
			# wisp: teardrop body with a wavy tail + hollow eyes
			draw_circle(c + Vector2(2, 3) + Vector2(0, -s * 0.08), s * 0.26, dark)
			draw_circle(c + Vector2(0, -s * 0.08), s * 0.26, accent)
			var tail := PackedVector2Array()
			for i in 12:
				var t := i / 11.0
				tail.append(c + Vector2(sin(t * 9.0) * s * 0.1 * (1.0 - t * 0.4),
					s * (0.14 + t * 0.3)))
			draw_polyline(tail, dark, s * 0.11)
			draw_polyline(tail, accent, s * 0.07)
			draw_circle(c + Vector2(-s * 0.09, -s * 0.12), s * 0.05, dark)
			draw_circle(c + Vector2(s * 0.09, -s * 0.12), s * 0.05, dark)
