class_name DialogPager
extends CanvasLayer
## THE NINTENDO PAGER (producer note, night-6 playtest). A long speech no longer
## dumps every paragraph on one screen. Hand it an array of paragraphs and it
## shows ONE per screen: press A (any seat), press ui_accept, or CLICK to advance;
## if nobody does, a circular countdown ring auto-advances slowly (paced ~6-10s by
## paragraph length, generous on purpose). The last page closes the card.
##
## House look: the project theme's panel + Fredoka body, a LuckiestGuy title, the
## countdown ring drawn procedurally (same language as IntroCard's ready ring).
##
## Usage:
##   var pager := DialogPager.new()
##   add_child(pager)
##   pager.closed.connect(_after)
##   pager.present(Dialog.paras("estate.house_rules.rules"), {
##       title = "THE HOUSE RULES",
##       sig = "— The Executor",
##       accent = Color(1, 0.85, 0.2),
##       seats = [0, 1],              # human seats whose A advances (optional)
##   })

signal closed                                   ## the final page was dismissed

const _FONT_TITLE := "res://assets/fonts/LuckiestGuy-Regular.ttf"
const _FONT_BODY := "res://assets/fonts/Fredoka.ttf"
const _THEME := "res://assets/ui/theme.tres"
const GOLD := Color(1, 0.85, 0.25)

## Auto-advance pacing: a generous base plus a per-character crawl, clamped to the
## producer's 6-10s window. Long paragraphs get the full ten; short ones still six.
const _AUTO_BASE := 5.0
const _AUTO_PER_CHAR := 0.035
const _AUTO_MIN := 6.0
const _AUTO_MAX := 10.0

var _paras: Array = []
var _idx := 0
var _accent := GOLD
var _sig := ""
var _seats: Array = []
var _auto := _AUTO_MIN
var _elapsed := 0.0
var _finished := false
var _pi: Node = null

var _body_lbl: Label
var _sig_lbl: Label
var _page_lbl: Label
var _hint_lbl: Label
var _ring: _CountRing

func _init() -> void:
	layer = 5   # above IntroCard(4) / a game HUD — the pager owns the screen
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_pi = get_node_or_null(^"/root/PlayerInput")

## Show the paragraphs. Returns immediately; listen to `closed`. Blank entries are
## dropped so a stray empty string never wastes a screen.
func present(paras: Array, opts: Dictionary = {}) -> void:
	_paras = []
	for p in paras:
		var s := String(p).strip_edges()
		if s != "":
			_paras.append(s)
	if _paras.is_empty():
		_paras = [""]
	_accent = opts.get("accent", GOLD)
	_sig = String(opts.get("sig", ""))
	_seats = opts.get("seats", [])
	_build_ui(String(opts.get("title", "")))
	_show_page(0)

func _build_ui(title: String) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.07, 0.86)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	if ResourceLoader.exists(_THEME):
		panel.theme = load(_THEME)   # the house panel style + fonts
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	if title != "":
		var title_lbl := _mk_label(_FONT_TITLE, 42, HORIZONTAL_ALIGNMENT_CENTER)
		title_lbl.text = title
		title_lbl.add_theme_color_override("font_color", _accent)
		col.add_child(title_lbl)

	_body_lbl = _mk_label(_FONT_BODY, 25, HORIZONTAL_ALIGNMENT_CENTER)
	_body_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.custom_minimum_size = Vector2(760, 120)
	col.add_child(_body_lbl)

	_sig_lbl = _mk_label(_FONT_BODY, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_sig_lbl.add_theme_color_override("font_color", _accent)
	_sig_lbl.modulate.a = 0.8
	_sig_lbl.visible = false
	col.add_child(_sig_lbl)

	col.add_child(_spacer(6))

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)

	_ring = _CountRing.new()
	_ring.custom_minimum_size = Vector2(64, 64)
	_ring.accent = _accent
	foot.add_child(_ring)

	_hint_lbl = _mk_label(_FONT_BODY, 20, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_lbl.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	foot.add_child(_hint_lbl)

	_page_lbl = _mk_label(_FONT_BODY, 16, HORIZONTAL_ALIGNMENT_CENTER)
	_page_lbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.82))
	_page_lbl.modulate.a = 0.7
	col.add_child(_page_lbl)

func _show_page(i: int) -> void:
	_idx = i
	_elapsed = 0.0
	var para := String(_paras[i])
	_body_lbl.text = para
	_auto = clampf(_AUTO_BASE + para.length() * _AUTO_PER_CHAR, _AUTO_MIN, _AUTO_MAX)
	var last := i == _paras.size() - 1
	_sig_lbl.text = _sig
	_sig_lbl.visible = last and _sig != ""
	_hint_lbl.text = ("press A or click  ·  begin" if last else "press A or click  ·  continue")
	_page_lbl.text = "%d / %d" % [i + 1, _paras.size()]
	_page_lbl.visible = _paras.size() > 1
	if _ring != null:
		_ring.fill = 0.0
		_ring.remain = _auto
		_ring.queue_redraw()
	Sfx.play("card", -6.0)

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	# any human seat's A advances (respects the game's live per-seat bindings)
	var advance := false
	if _pi != null:
		for s in _seats:
			if _pi.just_pressed(int(s), "a"):
				advance = true
				break
	if not advance and Input.is_action_just_pressed(&"ui_accept"):
		advance = true
	if _ring != null:
		_ring.fill = clampf(_elapsed / maxf(_auto, 0.01), 0.0, 1.0)
		_ring.remain = maxf(_auto - _elapsed, 0.0)
		_ring.queue_redraw()
	if advance:
		_advance()
	elif _elapsed >= _auto:
		_advance()

## Mouse (any device) advances too — handled here so the click never leaks to the
## scene under the dim backdrop.
func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	if _finished:
		return
	if _idx >= _paras.size() - 1:
		_close()
	else:
		_show_page(_idx + 1)

func _close() -> void:
	if _finished:
		return
	_finished = true
	Sfx.play("confirm", 0.0)
	closed.emit()
	var fade := create_tween()
	fade.set_parallel(true)
	for child in get_children():
		if child is CanvasItem:
			fade.tween_property(child, "modulate:a", 0.0, 0.2)
	fade.chain().tween_callback(queue_free)

func _mk_label(font_path: String, size: int, halign: int) -> Label:
	var l := Label.new()
	if ResourceLoader.exists(font_path):
		l.add_theme_font_override("font", load(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = halign
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

## The circular countdown: a track ring plus an arc that sweeps from the top as the
## idle timer runs out, with the whole seconds left drawn in the middle. Drawn
## procedurally — no glyph/texture dependency (IntroCard._ReadyRing precedent).
class _CountRing extends Control:
	var fill := 0.0            # 0..1 elapsed fraction of the current page
	var remain := 0.0          # seconds left, for the centre number
	var accent := Color(1, 0.85, 0.25)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 6.0, true)
		var start := -PI * 0.5
		draw_arc(c, r, start, start + TAU * clampf(fill, 0.0, 1.0), 48, accent, 6.0, true)
		var f := ThemeDB.fallback_font
		var txt := str(ceili(remain))
		var fs := int(r * 0.95)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(f, c - tw * 0.5 + Vector2(0, tw.y * 0.32), txt,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs, accent)
