class_name ProcessionMinimap
extends Control
## THE DRIVE, AT A GLANCE (W9 → graph edition). A small parchment inset that
## keeps the whole board legible while the camera is pushed into one landing:
## the branching A-to-B graph drawn as ROUTE-COLOURED RIBBONS (garden green,
## hollow violet, valley bog-blue; common road in bone), typed stones as
## notches, the LYCHGATE and MANOR GATE named, forks as gold diamonds, and
## each mourner as their player-colour glyph on the stone they stand on.
##
## PRESENTATION ONLY. It renders from data the board already holds — the
## logical pawn `positions` — which a net mirror receives every tick
## (_net_apply), so the inset renders identically on the couch and a guest.
## No rng, no sim state, no tally. Chrome matches the putt meters' parchment-
## dark ground + warm gold frame.

const PANEL_W := 216.0
const PANEL_H := 264.0
const MARGIN := 20.0

var _board: ProcessionBoardGraph = null
var _roster: Array = []
var _positions: Array = []
var _font: Font = null
# cached projection (world x/z -> panel px), rebuilt on configure()
var _px: Array = []            # node id -> Vector2
var _edges: Array = []         # [{a: Vector2, b: Vector2, color: Color}]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	size = custom_minimum_size
	_font = ThemeDB.fallback_font
	queue_redraw()

func configure(board: ProcessionBoardGraph, roster: Array) -> void:
	_board = board
	_roster = roster
	_project()
	queue_redraw()

## Push the live read (logical positions). Cheap; call whenever the HUD
## refreshes. Presentation only.
func set_state(positions: Array) -> void:
	_positions = positions
	queue_redraw()

## Fit the graph's x/z bounds into the panel. North (the MANOR GATE, −z) is
## the TOP of the inset — the race reads upward, like a drive should.
func _project() -> void:
	_px.clear()
	_edges.clear()
	if _board == null or _board.nodes.is_empty():
		return
	var minx := INF; var maxx := -INF
	var minz := INF; var maxz := -INF
	for n in _board.nodes:
		var p: Vector3 = n.pos
		minx = minf(minx, p.x); maxx = maxf(maxx, p.x)
		minz = minf(minz, p.z); maxz = maxf(maxz, p.z)
	var spanx := maxf(maxx - minx, 0.001)
	var spanz := maxf(maxz - minz, 0.001)
	var w := PANEL_W - MARGIN * 2.0
	var h := PANEL_H - MARGIN * 2.0 - 14.0   # room for the title strip
	for n in _board.nodes:
		var p: Vector3 = n.pos
		_px.append(Vector2(
			MARGIN + (p.x - minx) / spanx * w,
			MARGIN + 14.0 + (p.z - minz) / spanz * h))
	for n in _board.nodes:
		var a: Vector2 = _px[int(n.id)]
		for nx in (n.next as Array):
			var route := _board.route_of(int(nx))
			var col: Color = _board.route_info(route).color if route != "common" \
				else Color(0.72, 0.66, 0.52)
			_edges.append({"a": a, "b": _px[int(nx)], "color": col})

func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	draw_string(_font, Vector2(16, 24), "THE DRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(0.90, 0.84, 0.66))
	if _board == null or _px.is_empty():
		return
	# Route ribbons — the branching roads, colour-keyed.
	for e in _edges:
		var col: Color = e.color
		draw_line(e.a as Vector2, e.b as Vector2, Color(col.r, col.g, col.b, 0.85), 2.6)
	# Stones: typed stones get their space colour; path stones a faint notch.
	for n in _board.nodes:
		var i := int(n.id)
		var t := String(n.type)
		if t == ProcessionBoardSpaces.CROSSROADS:
			_draw_diamond(_px[i], 5.4, Color(0.98, 0.86, 0.38))
		elif t == ProcessionBoardSpaces.GATE or i == 0:
			continue   # named marks below
		elif t == ProcessionBoardSpaces.BLANK:
			draw_circle(_px[i], 1.9, Color(0.80, 0.74, 0.60, 0.55))
		else:
			draw_circle(_px[i], 3.0, ProcessionBoardSpaces.color(t))
	# The two named ends.
	var lych: Vector2 = _px[0]
	draw_circle(lych, 4.6, Color(0.62, 0.68, 0.85))
	draw_string(_font, Vector2(lych.x - 34.0, lych.y + 16.0), "LYCHGATE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.76, 0.9))
	var gate: Vector2 = _px[_board.gate_id()]
	draw_circle(gate, 5.4, Color(0.96, 0.82, 0.32))
	# Label sits RIGHT of the gate dot — the dot rides the panel's top edge,
	# where a label above it collided with the THE DRIVE title strip.
	draw_string(_font, Vector2(gate.x + 9.0, gate.y + 5.0), "GATE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.96, 0.86, 0.5))
	# The mourners — player-colour disc + badge glyph, fanned by seat so pawns
	# sharing a stone stay distinct.
	for seat in _positions.size():
		if seat >= _roster.size():
			continue
		var idx := int(_positions[seat])
		if idx < 0 or idx >= _px.size():
			continue
		var base: Vector2 = _px[idx]
		var ang := TAU * float(seat) / 4.0 + 0.6
		var pip := base + Vector2(cos(ang), sin(ang)) * (8.0 + 2.0 * float(seat % 2))
		var col: Color = _roster[seat].get("color", Color.WHITE)
		draw_circle(pip, 8.0, Color(col.r, col.g, col.b, 0.96))
		draw_arc(pip, 8.0, 0.0, TAU, 18, Color(0.05, 0.04, 0.06), 1.6)
		var g := PlayerBadge.glyph(seat)
		draw_string(_font, pip + Vector2(-5.0, 5.0), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(0.04, 0.03, 0.05))

func _draw_diamond(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, col)

func _panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.086, 0.067, 0.93)
	box.border_color = Color(0.78, 0.66, 0.36)
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 6
	return box
