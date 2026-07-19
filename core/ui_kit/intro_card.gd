class_name IntroCard
extends CanvasLayer
## Mario Party-style minigame intro card, shown at load (doc 14 §5).
## Game name (big) + one-line goal + a controls block (real bindings via
## PlayerInput.describe_binding, texture glyphs via a global InputGlyphs class if
## one exists — feature-detected, NO hard dependency) + a rotating tip line + a
## READY ring: all listed players press A to start early, else auto-start after
## `auto_secs` (default 12s) with a visible radial countdown. Skinnable accent.
## (Was 6s; DOUBLED per Alex's night-6 playtest — fast readers could barely
## finish a guide before it auto-advanced. 2x auto-advance reads comfortably.)
##
## Usage:
##   var card := IntroCard.new()
##   add_child(card)
##   card.started.connect(_start_round)
##   card.present({
##       name = "MOWER MAYHEM",
##       goal = "Mow stripes in your color. Coverage IS score.",
##       accent = Color(0.4, 0.8, 0.3),
##       seats = [0, 1],                          # human seats that must ready (may be empty)
##       controls = [{action="move", label="STEER"},
##                   {action="a", label="RAM HORN"},
##                   {action="b", label="BOOST"}],
##       glyph_seat = 0,                          # seat to read bindings from (default first of `seats`)
##       tips = ["Ram a rival to steal their turf.", "Overtime doubles your cut."],
##       legend = "+2 KILL   ·   +1 CATCH-STEAL",     # optional: a small STATIC
##                                                     # scoring key under the tip
##                                                     # line (never rotates, unlike
##                                                     # `tips` — opt-in per game).
##       auto_secs = 12.0,
##   })

signal started                                  ## ready reached (or auto-start elapsed)

const _FONT_BIG := "res://assets/fonts/LuckiestGuy-Regular.ttf"
const _FONT_BODY := "res://assets/fonts/Baloo2.ttf"
const TIP_INTERVAL := 2.6
const GOLD := Color(1, 0.85, 0.25)

var _spec: Dictionary = {}
var _seats: Array = []
var _readied: Dictionary = {}
var _auto_secs := 12.0
var _elapsed := 0.0
var _tip_t := 0.0
var _tip_i := 0
var _tips: Array = []
var _accent := GOLD
var _finished := false

var _pi: Node = null
var _root: Control
var _tip_label: Label
var _ring: _ReadyRing
var _pip_box: HBoxContainer
var _pips: Dictionary = {}          # seat -> PlayerBadge

func _init() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_pi = get_node_or_null(^"/root/PlayerInput")

## Show the card. Returns immediately; listen to `started`.
func present(spec: Dictionary) -> void:
	_spec = spec
	_seats = spec.get("seats", [])
	_auto_secs = float(spec.get("auto_secs", 12.0))
	_tips = spec.get("tips", [])
	_accent = spec.get("accent", GOLD)
	_build_ui()

func _build_ui() -> void:
	# dim backdrop so the card reads over any 3D scene
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.07, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.anchor_left = 0.0
	col.anchor_right = 1.0
	col.anchor_top = 0.12
	col.anchor_bottom = 0.9
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)

	var name_lbl := _mk_label(_FONT_BIG, 64, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.text = str(_spec.get("name", ""))
	name_lbl.add_theme_color_override("font_color", _accent)
	col.add_child(name_lbl)

	var goal_lbl := _mk_label(_FONT_BODY, 28, HORIZONTAL_ALIGNMENT_CENTER)
	goal_lbl.text = str(_spec.get("goal", ""))
	goal_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	col.add_child(goal_lbl)

	col.add_child(_spacer(10))

	# controls block
	var controls: Array = _spec.get("controls", [])
	if not controls.is_empty():
		var cbox := HBoxContainer.new()
		cbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cbox.add_theme_constant_override("separation", 26)
		cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var seat := int(_spec.get("glyph_seat", _seats[0] if not _seats.is_empty() else 0))
		for c in controls:
			cbox.add_child(_control_chip(seat, str(c.get("action", "")), str(c.get("label", ""))))
		col.add_child(cbox)

	col.add_child(_spacer(6))

	# rotating tip line
	_tip_label = _mk_label(_FONT_BODY, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_tip_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	if not _tips.is_empty():
		_tip_label.text = "TIP:  " + str(_tips[0])
	col.add_child(_tip_label)

	# optional static legend (e.g. a scoring key) — unlike `tips` this never
	# rotates, so it's the right place for a small fact a player should be
	# able to read once and keep in mind (playtest: "How am I getting
	# points?"). Opt-in via spec["legend"]; every other game's present() call
	# is unaffected since this is empty by default.
	var legend := str(_spec.get("legend", ""))
	if legend != "":
		var legend_lbl := _mk_label(_FONT_BODY, 18, HORIZONTAL_ALIGNMENT_CENTER)
		legend_lbl.text = legend
		legend_lbl.add_theme_color_override("font_color", Color(0.68, 0.7, 0.8))
		col.add_child(legend_lbl)

	col.add_child(_spacer(16))

	# READY ring + per-seat pips
	_ring = _ReadyRing.new()
	_ring.custom_minimum_size = Vector2(110, 110)
	_ring.accent = _accent
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_ring)

	var ready_hint := _mk_label(_FONT_BODY, 20, HORIZONTAL_ALIGNMENT_CENTER)
	ready_hint.add_theme_color_override("font_color", Color(0.75, 0.77, 0.85))
	ready_hint.text = "PRESS  A  TO START" if not _seats.is_empty() else "STARTING..."
	ready_hint.name = "ReadyHint"
	col.add_child(ready_hint)

	if not _seats.is_empty():
		_pip_box = HBoxContainer.new()
		_pip_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_pip_box.add_theme_constant_override("separation", 12)
		_pip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for s in _seats:
			var pip := PlayerBadge.make(int(s), 26)
			pip.dim = 0.35
			_pip_box.add_child(pip)
			_pips[int(s)] = pip
		col.add_child(_pip_box)

## One control chip: a texture glyph if an InputGlyphs global class exists,
## else the real key/button text from PlayerInput.describe_binding.
func _control_chip(seat: int, action: String, label: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph_tex := _glyph_texture(seat, action)
	if glyph_tex != null:
		var tr := TextureRect.new()
		tr.texture = glyph_tex
		tr.custom_minimum_size = Vector2(34, 34)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(tr)
	else:
		var key := _mk_label(_FONT_BIG, 24, HORIZONTAL_ALIGNMENT_CENTER)
		key.text = _binding_text(seat, action)
		key.add_theme_color_override("font_color", _accent)
		hb.add_child(key)
	var lab := _mk_label(_FONT_BODY, 22, HORIZONTAL_ALIGNMENT_LEFT)
	lab.text = label
	lab.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	hb.add_child(lab)
	return hb

func _binding_text(seat: int, action: String) -> String:
	if _pi != null and _pi.has_method("describe_binding"):
		return str(_pi.describe_binding(seat, action))
	return action.to_upper()

## Feature-detect a global class named "InputGlyphs" (doc 14 item 13). None
## exists today, so this returns null and the text path runs — but if a future
## kit adds one exposing a static `glyph(seat, action) -> Texture2D`, it's used
## with zero changes here. No hard dependency.
func _glyph_texture(seat: int, action: String) -> Texture2D:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "InputGlyphs":
			var scr := load(str(c.get("path", "")))
			if scr != null and scr.has_method("glyph"):
				var t = scr.glyph(seat, action)
				return t if t is Texture2D else null
			return null
	return null

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	# rotate tips
	if _tips.size() > 1:
		_tip_t += delta
		if _tip_t >= TIP_INTERVAL:
			_tip_t = 0.0
			_tip_i = (_tip_i + 1) % _tips.size()
			_tip_label.text = "TIP:  " + str(_tips[_tip_i])
	# poll ready presses (human seats only)
	if _pi != null:
		for s in _seats:
			var seat := int(s)
			if not _readied.get(seat, false) and _pi.just_pressed(seat, "a"):
				_readied[seat] = true
				if _pips.has(seat):
					(_pips[seat] as PlayerBadge).dim = 1.0
				Sfx.play("confirm", -3.0)
	# ring fill = readied fraction OR the auto-timer's approach, whichever is fuller
	var auto_frac := clampf(_elapsed / maxf(_auto_secs, 0.01), 0.0, 1.0)
	var ready_frac := 0.0
	if not _seats.is_empty():
		ready_frac = float(_readied.size()) / float(_seats.size())
	_ring.fill = maxf(auto_frac, ready_frac)
	_ring.queue_redraw()
	# start conditions: all humans readied, or the auto window elapsed
	var all_ready := not _seats.is_empty() and _readied.size() >= _seats.size()
	if all_ready or _elapsed >= _auto_secs:
		_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	Sfx.play("confirm", 0.0)
	started.emit()
	# quick fade-out, then free
	var fade := create_tween()
	fade.set_parallel(true)
	for child in get_children():
		if child is CanvasItem:
			fade.tween_property(child, "modulate:a", 0.0, 0.22)
	fade.chain().tween_callback(queue_free)

func _mk_label(font_path: String, size: int, halign: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = halign
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

## Radial countdown ring, drawn procedurally (no glyph/texture dependency).
class _ReadyRing extends Control:
	var fill := 0.0          # 0..1 depleting/filling arc
	var accent := Color(1, 0.85, 0.25)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		# track
		draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.15), 8.0, true)
		# fill arc from the top, clockwise
		var start := -PI * 0.5
		draw_arc(c, r, start, start + TAU * clampf(fill, 0.0, 1.0), 64, accent, 8.0, true)
		# center "A" prompt
		var f := ThemeDB.fallback_font
		var txt := "A"
		var fs := int(r * 0.9)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(f, c - tw * 0.5 + Vector2(0, tw.y * 0.35), txt,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs, accent)
