class_name LWCardIcon
extends Control
## Hand-drawn card glyphs for the will draft (no external art needed).
## kinds: scythe / grease / gale / stones — the four course curses.
## Drawn in the accent color with a dark under-stroke so they pop on parchment.

var kind := "scythe"
var accent := Color(0.55, 0.95, 0.5)

func set_icon(k: String, a: Color) -> void:
	kind = k
	accent = a
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var dark := Color(0.08, 0.06, 0.05, 0.9)
	match kind:
		"scythe":
			# hanging shaft + crescent blade
			var w := s * 0.07
			draw_line(c + Vector2(2, 3) + Vector2(0, -s * 0.42), c + Vector2(2, 3) + Vector2(0, s * 0.1), dark, w + 3)
			draw_line(c + Vector2(0, -s * 0.42), c + Vector2(0, s * 0.1), accent, w)
			draw_arc(c + Vector2(2, 3) + Vector2(0, s * 0.02), s * 0.3, PI * 0.1, PI * 0.9, 28, dark, w + 3)
			draw_arc(c + Vector2(0, s * 0.02), s * 0.3, PI * 0.1, PI * 0.9, 28, accent, w)
			draw_arc(c + Vector2(0, -s * 0.02), s * 0.26, PI * 0.2, PI * 0.8, 24, dark.lerp(accent, 0.25), w * 0.8)
		"grease":
			# a tipped urn spilling a slick
			var urn := PackedVector2Array()
			for p in [Vector2(-0.3, -0.34), Vector2(-0.06, -0.2), Vector2(-0.1, -0.02),
					Vector2(-0.34, -0.14)]:
				urn.append(c + p * s)
			var shadow := PackedVector2Array()
			for p in urn:
				shadow.append(p + Vector2(2, 3))
			draw_colored_polygon(shadow, dark)
			draw_colored_polygon(urn, accent)
			# the slick: three nested rounded blobs
			draw_circle(c + Vector2(s * 0.1, s * 0.22) + Vector2(2, 3), s * 0.26, dark)
			draw_circle(c + Vector2(s * 0.1, s * 0.22), s * 0.26, accent)
			draw_circle(c + Vector2(s * 0.16, s * 0.2), s * 0.16, accent.lightened(0.25))
			draw_circle(c + Vector2(s * 0.02, s * 0.28), s * 0.07, accent.lightened(0.4))
		"gale":
			# three streaming wind strokes with curled tails
			for i in 3:
				var y := (-0.24 + float(i) * 0.22) * s
				var w2 := s * 0.075
				var pts := PackedVector2Array()
				for k in 14:
					var t := float(k) / 13.0
					pts.append(c + Vector2(-s * 0.38 + t * s * 0.66,
						y - sin(t * PI) * s * 0.06))
				var sh := PackedVector2Array()
				for p in pts:
					sh.append(p + Vector2(2, 3))
				draw_polyline(sh, dark, w2 + 3)
				draw_polyline(pts, accent, w2)
				draw_arc(c + Vector2(s * 0.3, y - s * 0.1), s * 0.09,
					-PI * 0.5, PI * 0.75, 12, accent, w2 * 0.9)
		"stones":
			# a rank of three headstones, middle one tallest
			for i in 3:
				var x := (-0.28 + float(i) * 0.28) * s
				var h := (0.3 if i != 1 else 0.42) * s
				var wds := s * 0.2
				var r := Rect2(c + Vector2(x - wds * 0.5, s * 0.3 - h), Vector2(wds, h))
				draw_rect(Rect2(r.position + Vector2(2, 3), r.size), dark)
				draw_rect(r, accent.darkened(float(i) * 0.1))
				draw_circle(c + Vector2(x, s * 0.3 - h) + Vector2(2, 3), wds * 0.5, dark)
				draw_circle(c + Vector2(x, s * 0.3 - h), wds * 0.5, accent.darkened(float(i) * 0.1))
			draw_line(c + Vector2(-s * 0.4, s * 0.34), c + Vector2(s * 0.4, s * 0.34), dark, s * 0.05)
