class_name ProcessionMinimap
extends Control
## THE DRIVE, AT A GLANCE (W9). A small parchment inset that keeps the whole
## carriage loop legible while the camera is pushed into one landing: the ring of
## 24 stones as notches, each mourner as their player-colour glyph on the stone
## they stand on, the roving Codicil as a gold diamond, and the manor gate marked
## at the top. It answers "where is everyone, and where is the Deed" without
## pulling the camera back.
##
## PRESENTATION ONLY. It renders from data the board already holds — the logical
## pawn `positions`, the Codicil's `beacon_index` — both of which a net mirror
## receives every tick (_net_apply), so the inset renders identically on the couch
## and a guest. No rng, no sim state, no tally. Chrome matches the putt meters'
## parchment-dark ground + warm gold frame (pawn_putt.PuttMeter._panel()).

const PANEL_W := 212.0
const PANEL_H := 196.0
const RING_CX := 106.0        # ring centre inside the panel
const RING_CY := 116.0
const RING_RX := 84.0         # ellipse radii (wider than tall — matches the drive)
const RING_RY := 62.0
const SPACES := 24

var _board: ProcessionBoardPath = null
var _roster: Array = []
var _positions: Array = []
var _beacon := 13
var _font: Font = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	size = custom_minimum_size
	_font = ThemeDB.fallback_font
	queue_redraw()

func configure(board: ProcessionBoardPath, roster: Array) -> void:
	_board = board
	_roster = roster
	_beacon = board.beacon_index if board != null else 13
	queue_redraw()

## Push the live read (logical positions + Codicil berth). Cheap; call it whenever
## the HUD refreshes. Presentation only.
func set_state(positions: Array, beacon_index: int) -> void:
	_positions = positions
	_beacon = beacon_index
	queue_redraw()

## Panel-local pixel for a space index, on the ellipse ring. Space 0 (the gate) is
## the top of the ring; the loop runs clockwise, matching the board's own layout.
func _space_px(i: int) -> Vector2:
	var ang := TAU * float(posmod(i, SPACES)) / float(SPACES) - PI * 0.5
	return Vector2(RING_CX + cos(ang) * RING_RX, RING_CY + sin(ang) * RING_RY)

func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	# Title
	draw_string(_font, Vector2(16, 24), "THE DRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(0.90, 0.84, 0.66))
	# The ring path — a faint bone ellipse the notches sit on.
	var prev := _space_px(0)
	for i in range(1, SPACES + 1):
		var p := _space_px(i)
		draw_line(prev, p, Color(0.55, 0.50, 0.40, 0.55), 2.0)
		prev = p
	# Stone notches (skip the gate + Codicil, drawn as their own marks).
	for i in SPACES:
		if i == 0 or i == _beacon:
			continue
		draw_circle(_space_px(i), 3.2, Color(0.80, 0.74, 0.60, 0.85))
	# The manor gate at space 0 — a small warm arch dot + tick, so "home" reads.
	var gate := _space_px(0)
	draw_circle(gate, 5.0, Color(0.86, 0.78, 0.52))
	draw_string(_font, Vector2(gate.x - 16.0, gate.y - 9.0), "GATE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.86, 0.80, 0.60))
	# The roving Codicil — a gold diamond with a soft halo (the objective).
	var bpos := _space_px(_beacon)
	draw_circle(bpos, 9.0, Color(0.96, 0.82, 0.32, 0.28))
	_draw_diamond(bpos, 6.4, Color(0.98, 0.86, 0.38))
	# The mourners — each as their player-colour disc + badge glyph, fanned a touch
	# outward by seat so pawns sharing a stone stay distinct.
	for seat in _positions.size():
		if seat >= _roster.size():
			continue
		var idx := int(_positions[seat])
		var base := _space_px(idx)
		var out := (base - Vector2(RING_CX, RING_CY))
		out = out.normalized() if out.length() > 0.5 else Vector2.UP
		var pip := base + out * (7.0 + 4.0 * float(seat % 2)) \
			+ out.orthogonal() * (float(seat) - 1.5) * 4.0
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
