class_name USBoard
extends CanvasLayer
## THE UNDERSTUDY stage overlays: the REHEARSAL cue grid, the VOTE board where
## four accusations form in real time, and the RESOLUTION card that states the
## verdict — including, deliberately, whether a simple majority would have
## STALEMATED where the distributed scoring resolves.

const F_LUCKIEST := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const F_BALOO := preload("res://assets/fonts/Baloo2.ttf")
const F_FREDOKA := preload("res://assets/fonts/Fredoka.ttf")

const GOLD := Color(1.0, 0.83, 0.36)
const CRIMSON := Color(0.88, 0.26, 0.28)
const GREEN := Color(0.55, 0.95, 0.5)
const INK := Color(0.16, 0.12, 0.09)

var _root: Control

# rehearsal
var _reh_panel: Panel
var _reh_title: Label
var _reh_sub: Label
var _grid: HBoxContainer
var _word_panels: Array = []       # Panel per word
var _grid_words: Array = []        # String per word

# vote
var _vote_panel: Panel
var _vote_title: Label
var _cols: Array = []              # {root: Control, x: float, tally: VBoxContainer, name: Label}
var _carets: Dictionary = {}       # voter_idx -> Label ▼

# resolution
var _res_box: VBoxContainer
var _verdict: Label

func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_rehearsal()
	_build_vote()
	_build_resolution()
	visible = true
	hide_all()

func _mk(parent: Control, text: String, font: FontFile, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.07))
	l.add_theme_constant_override("outline_size", maxi(3, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l

func _panel(bg: Color, border: Color, radius: int) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(3)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

# ============================================================== rehearsal
func _build_rehearsal() -> void:
	_reh_panel = _panel(Color(0.08, 0.05, 0.07, 0.9), Color(0.5, 0.4, 0.3), 14)
	_reh_panel.position = Vector2(150, 470)
	_reh_panel.size = Vector2(980, 210)
	_root.add_child(_reh_panel)

	_reh_title = _mk(_reh_panel, "THE REHEARSAL", F_LUCKIEST, 30, GOLD)
	_reh_title.position = Vector2(0, 10)
	_reh_title.size = Vector2(980, 40)
	_reh_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_reh_sub = _mk(_reh_panel, "", F_BALOO, 20, Color(0.9, 0.85, 0.75))
	_reh_sub.position = Vector2(0, 48)
	_reh_sub.size = Vector2(980, 28)
	_reh_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", 14)
	_grid.position = Vector2(30, 86)
	_grid.size = Vector2(920, 110)
	_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reh_panel.add_child(_grid)

func show_grid(words: Array) -> void:
	_grid_words = words.duplicate()
	for c in _word_panels:
		c.queue_free()
	_word_panels.clear()
	for w in words:
		var p := _panel(Color(0.14, 0.11, 0.09, 0.98), Color(0.45, 0.38, 0.26), 10)
		p.custom_minimum_size = Vector2(140, 96)
		var l := _mk(p, str(w), F_LUCKIEST, 24, Color(0.94, 0.9, 0.8))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		p.pivot_offset = Vector2(70, 48)
		_grid.add_child(p)
		_word_panels.append(p)

func set_active(pname: String, col: Color, glyph: String) -> void:
	_reh_sub.text = "%s %s — DELIVER YOUR CUE" % [glyph, pname]
	_reh_sub.add_theme_color_override("font_color", col)

func set_word_cursor(idx: int, col: Color) -> void:
	for i in _word_panels.size():
		var p: Panel = _word_panels[i]
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
		if i == idx:
			sb.border_color = col
			sb.set_border_width_all(6)
			p.scale = Vector2(1.08, 1.08)
		else:
			sb.border_color = Color(0.45, 0.38, 0.26)
			sb.set_border_width_all(3)
			p.scale = Vector2.ONE

func lock_word(idx: int, on_script: bool, col: Color) -> void:
	if idx < 0 or idx >= _word_panels.size():
		return
	var p: Panel = _word_panels[idx]
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
	sb.border_color = col
	sb.set_border_width_all(6)
	sb.bg_color = Color(0.2, 0.16, 0.1, 0.98) if on_script else Color(0.22, 0.09, 0.09, 0.98)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(1.16, 1.16), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "scale", Vector2.ONE, 0.1)

func show_rehearsal(v: bool) -> void:
	_reh_panel.visible = v

# ============================================================== vote
func _build_vote() -> void:
	_vote_panel = _panel(Color(0.06, 0.04, 0.06, 0.82), Color(0.55, 0.2, 0.22), 16)
	_vote_panel.position = Vector2(140, 172)
	_vote_panel.size = Vector2(1000, 412)
	_root.add_child(_vote_panel)

	_vote_title = _mk(_vote_panel, "NAME THE PRETENDER", F_LUCKIEST, 40, CRIMSON)
	_vote_title.position = Vector2(0, 16)
	_vote_title.size = Vector2(1000, 54)
	_vote_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func show_vote(entries: Array) -> void:
	## entries: [{index,name,color}] in seat order
	for col in _cols:
		(col.root as Control).queue_free()
	for k in _carets.keys():
		(_carets[k] as Control).queue_free()
	_carets.clear()
	_cols.clear()
	var n := entries.size()
	var col_w := 210.0
	var total := col_w * n + 24.0 * (n - 1)
	var x0 := (1000.0 - total) / 2.0
	for i in n:
		var e: Dictionary = entries[i]
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cx := x0 + i * (col_w + 24.0)
		root.position = Vector2(cx, 92)
		root.size = Vector2(col_w, 300)
		_vote_panel.add_child(root)

		var head := _panel(Color(0.12, 0.09, 0.11, 0.96), e.color, 12)
		head.position = Vector2(0, 30)
		head.size = Vector2(col_w, 70)
		root.add_child(head)
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(hb)
		var badge := PlayerBadge.make(int(e.index), 30)
		badge.color = e.color
		hb.add_child(badge)
		var nm := _mk(null, str(e.name), F_LUCKIEST, 26, e.color)
		hb.add_child(nm)

		var tally := VBoxContainer.new()
		tally.position = Vector2(0, 108)
		tally.size = Vector2(col_w, 180)
		tally.alignment = BoxContainer.ALIGNMENT_BEGIN
		tally.add_theme_constant_override("separation", 4)
		tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tally)

		_cols.append({"root": root, "x": cx, "tally": tally, "name": str(e.name)})

	for e in entries:
		var caret := _mk(_vote_panel, "▼", F_LUCKIEST, 34, e.color)
		caret.size = Vector2(40, 40)
		caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caret.visible = false
		_carets[int(e.index)] = caret

func set_vote_cursor(voter_index: int, target_col: int) -> void:
	if not _carets.has(voter_index):
		return
	var caret: Label = _carets[voter_index]
	if target_col < 0 or target_col >= _cols.size():
		caret.visible = false
		return
	caret.visible = true
	var cx: float = float(_cols[target_col].x)
	# fan multiple carets over the same column so they don't fully overlap
	var offset := 0.0
	for k in _carets.keys():
		if k == voter_index:
			break
		var other: Label = _carets[k]
		if other.visible and absf(other.position.x - (92.0 + cx + 85.0)) < 60.0:
			offset += 26.0
	caret.position = Vector2(92.0 + cx + 60.0 + offset, 116.0)

func lock_vote(voter_index: int, voter_name: String, voter_color: Color, target_col: int) -> void:
	if _carets.has(voter_index):
		(_carets[voter_index] as Label).visible = false
	if target_col < 0 or target_col >= _cols.size():
		return
	var tally: VBoxContainer = _cols[target_col].tally
	var chip := _panel(Color(0.1, 0.08, 0.1, 0.95), voter_color, 8)
	chip.custom_minimum_size = Vector2(190, 34)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(hb)
	var badge := PlayerBadge.make(voter_index, 20)
	badge.color = voter_color
	hb.add_child(badge)
	var l := _mk(null, "%s ACCUSES" % voter_name, F_BALOO, 15, voter_color)
	hb.add_child(l)
	tally.add_child(chip)
	chip.scale = Vector2(0.7, 0.7)
	chip.pivot_offset = Vector2(95, 17)
	var tw := create_tween()
	tw.tween_property(chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("card", -4.0)

func mark_target(target_col: int, col: Color) -> void:
	if target_col < 0 or target_col >= _cols.size():
		return
	var root: Control = _cols[target_col].root
	for c in root.get_children():
		if c is Panel:
			var sb: StyleBoxFlat = (c as Panel).get_theme_stylebox("panel")
			sb.set_border_width_all(7)
			sb.border_color = col

func show_vote_panel(v: bool) -> void:
	_vote_panel.visible = v

# ============================================================== resolution
func _build_resolution() -> void:
	_verdict = _mk(_root, "", F_LUCKIEST, 34, Color.WHITE)
	_verdict.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_verdict.offset_left = 40
	_verdict.offset_right = -40
	_verdict.offset_top = 96
	_verdict.offset_bottom = 150
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.visible = false

	_res_box = VBoxContainer.new()
	_res_box.set_anchors_preset(Control.PRESET_CENTER)
	_res_box.offset_left = -520
	_res_box.offset_right = 520
	_res_box.offset_top = -40
	_res_box.offset_bottom = 220
	_res_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_res_box.add_theme_constant_override("separation", 12)
	_res_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_res_box)
	_res_box.visible = false

func show_verdict(text: String, col: Color) -> void:
	_verdict.text = text
	_verdict.add_theme_color_override("font_color", col)
	_verdict.visible = true
	_verdict.pivot_offset = Vector2(640, 27)
	_verdict.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(_verdict, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_res_lines(lines: Array) -> void:
	## lines: [{text,color,delay}]
	for c in _res_box.get_children():
		c.queue_free()
	_res_box.visible = true
	for ln in lines:
		var l := _mk(null, str(ln.text), F_LUCKIEST, 30, ln.color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		_res_box.add_child(l)
		var tw := create_tween()
		tw.tween_interval(float(ln.delay))
		tw.tween_property(l, "modulate:a", 1.0, 0.2)

func hide_resolution() -> void:
	_verdict.visible = false
	_res_box.visible = false

func hide_all() -> void:
	show_rehearsal(false)
	show_vote_panel(false)
	hide_resolution()
