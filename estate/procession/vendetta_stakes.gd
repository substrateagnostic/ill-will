class_name ProcessionVendettaStakes
extends Control
## THE SEALED VENDETTA — the board's signature 1v1, made a human decision. When
## two mourners meet within five stones, each LOCAL HUMAN raises their 0–3 stake
## by holding (A) over ~2.5s and releasing to seal it; both stakes are hidden
## behind a wax seal while charging, then revealed together with a beat between.
##
## Bots and remote guests never reach this overlay — the host rolls their stake
## the old way (procession._stake_for) and only *renders* it here, which is how
## the all-bot verification soak stays byte-identical (no human, no overlay, no
## new rng). Presentation only: procession.gd owns the input loop and the timing;
## this node only paints two panels and a header.

const PANEL_W := 300.0
const PANEL_H := 158.0
const PANEL_GAP := 34.0
# The whole cluster rides a touch above dead centre so it clears the reveal
# lower-third's band even on shorter viewports (the two used to share the lower
# strip). The lower-third is also suppressed while this overlay is up.
const LIFT := 46.0
const TextFit := preload("res://estate/procession/text_fit.gd")

var _header: Label
var _scrim: PanelContainer
var _panels: Array = []   # [StakePanel, StakePanel]

class StakePanel:
	extends Control
	var pname := "MOURNER"
	var pcolor := Color.WHITE
	var glyph := "◆"
	var is_human := false
	var state := 0        # 0 = raising, 1 = sealed (wax, hidden), 2 = revealed
	var fill := 0.0       # 0..1 charge, drives the lit pip count while raising
	var stake := 0        # 0..3 revealed level

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(300.0, 158.0)
		queue_redraw()

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.10, 0.086, 0.067, 0.94)
		box.border_color = Color(0.78, 0.66, 0.36)
		box.set_border_width_all(3)
		box.set_corner_radius_all(12)
		box.shadow_color = Color(0, 0, 0, 0.5)
		box.shadow_size = 8
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		# Owner header strip — colour band + badge glyph + name (never colour alone).
		# The name ellipsizes so a long mourner never bleeds past the panel frame.
		draw_rect(Rect2(6, 6, size.x - 12, 30), Color(pcolor.r, pcolor.g, pcolor.b, 0.22), true)
		var head := "%s  %s" % [glyph, TextFit.ellipsize(font, pname, size.x - 56.0, 22)]
		draw_string(font, Vector2(16, 30), head,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 22, pcolor.lerp(Color.WHITE, 0.18))
		var pip_y := 52.0
		var pip_h := 44.0
		var gap := 10.0
		var pw := (size.x - 32.0 - gap * 2.0) / 3.0
		if state == 1:
			# A wax seal over the pips — the stake is committed and hidden.
			var c := Vector2(size.x * 0.5, pip_y + pip_h * 0.5)
			draw_circle(c, 30.0, Color(0.46, 0.10, 0.10, 0.94))
			draw_circle(c, 30.0, Color(0.72, 0.20, 0.18, 0.6))
			draw_arc(c, 30.0, 0.0, TAU, 40, Color(0.86, 0.36, 0.30), 2.5)
		else:
			var lit := stake if state == 2 else int(round(clampf(fill, 0.0, 1.0) * 3.0))
			for n in 3:
				var rx := 16.0 + float(n) * (pw + gap)
				var r := Rect2(rx, pip_y, pw, pip_h)
				var on := n < lit
				var fc := pcolor if on else Color(0.16, 0.15, 0.19)
				draw_rect(r, Color(fc.r, fc.g, fc.b, 0.85 if on else 0.5), true)
				draw_rect(r, Color(0.82, 0.72, 0.42), false, 2.0)
				draw_string(font, Vector2(rx + pw * 0.5 - 6.0, pip_y + pip_h * 0.5 + 8.0),
					str(n + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
					Color(0.96, 0.93, 0.86) if on else Color(0.5, 0.48, 0.52))
		var foot := ""
		var col := Color(0.90, 0.84, 0.66)
		match state:
			0:
				foot = "RAISE — HOLD (A)" if is_human else "the estate rolls…"
			1:
				foot = "SEALED"
				col = Color(0.86, 0.40, 0.34)
			2:
				foot = "STAKE %d" % stake
				col = pcolor.lerp(Color.WHITE, 0.25)
		draw_string(font, Vector2(16, size.y - 14), foot, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 24, 22, col)

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A dark scrim behind the header + panels so they read over the lit board.
	_scrim = PanelContainer.new()
	_scrim.anchor_left = 0.5; _scrim.anchor_right = 0.5
	_scrim.anchor_top = 0.5; _scrim.anchor_bottom = 0.5
	var half_w := PANEL_W + PANEL_GAP * 0.5 + 40.0
	_scrim.offset_left = -half_w; _scrim.offset_right = half_w
	_scrim.offset_top = -168.0 - LIFT; _scrim.offset_bottom = 130.0 - LIFT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.78)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.62, 0.52, 0.30, 0.75)
	_scrim.add_theme_stylebox_override("panel", sb)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	_header = Label.new()
	_header.anchor_left = 0.5; _header.anchor_right = 0.5
	_header.anchor_top = 0.5; _header.anchor_bottom = 0.5
	_header.offset_left = -360.0; _header.offset_right = 360.0
	_header.offset_top = -150.0 - LIFT; _header.offset_bottom = -108.0 - LIFT
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.text = "A SEALED VENDETTA — RAISE, THEN RELEASE"
	_header.add_theme_font_size_override("font_size", 32)
	_header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62))
	_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_header.add_theme_constant_override("outline_size", 8)
	add_child(_header)

	for k in 2:
		var p := StakePanel.new()
		p.anchor_left = 0.5; p.anchor_right = 0.5
		p.anchor_top = 0.5; p.anchor_bottom = 0.5
		var lx := PANEL_GAP * 0.5 if k == 1 else -PANEL_W - PANEL_GAP * 0.5
		p.offset_left = lx; p.offset_right = lx + PANEL_W
		p.offset_top = -60.0 - LIFT; p.offset_bottom = -60.0 + PANEL_H - LIFT
		add_child(p)
		_panels.append(p)
	visible = false

## Open the overlay for a duel. Each info dict: {name, color, glyph, human}.
func show_duel(a: Dictionary, b: Dictionary) -> void:
	_apply(_panels[0], a)
	_apply(_panels[1], b)
	visible = true

func _apply(p: StakePanel, info: Dictionary) -> void:
	p.pname = String(info.get("name", "MOURNER"))
	p.pcolor = info.get("color", Color.WHITE)
	p.glyph = String(info.get("glyph", "◆"))
	p.is_human = bool(info.get("human", false))
	p.state = 0
	p.fill = 0.0
	p.stake = 0
	p.queue_redraw()

func set_fill(side: int, ratio: float) -> void:
	if side >= 0 and side < _panels.size():
		var p: StakePanel = _panels[side]
		p.fill = clampf(ratio, 0.0, 1.0)
		p.queue_redraw()

func set_sealed(side: int) -> void:
	if side >= 0 and side < _panels.size():
		var p: StakePanel = _panels[side]
		p.state = 1
		p.queue_redraw()

func reveal(side: int, stake: int) -> void:
	if side >= 0 and side < _panels.size():
		var p: StakePanel = _panels[side]
		p.stake = clampi(stake, 0, 3)
		p.state = 2
		p.queue_redraw()

func hide_all() -> void:
	visible = false
