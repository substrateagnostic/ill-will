class_name SeanceUI
extends CanvasLayer
## Dynamic UI for THE SÉANCE: the eyes-closed casting overlay, the
## accusation portraits with per-voter badge chips, and the settlement rows.
## Static HUD (timer, banner, blanks, focus bar, Executor line) lives in
## seance.tscn; this layer owns everything that is built per-roster.
##
## Vote UX per the research doc: stick swings your chip across the other
## three portraits, A locks it. Pointing is PUBLIC (at a séance table you
## point with your whole arm); the lock is a commitment — locked chips
## brighten and stamp. Scoring is distributed, so herding can embarrass
## you but never resolves the round by majority.

var _font_luckiest: FontFile
var _font_baloo: FontFile

var _cast: ColorRect
var _cast_title: Label
var _cast_sub: Label
var _cast_card: Label

var _vote_root: Control
var _portrait_boxes: Dictionary = {}   # target index -> VBoxContainer chip zone
var _portrait_frames: Dictionary = {}  # target index -> PanelContainer
var _chips: Dictionary = {}            # voter index -> Control chip
var _chip_badges: Dictionary = {}      # voter index -> PlayerBadge
var _chip_locks: Dictionary = {}       # voter index -> Label
var _settle_rows: VBoxContainer

func _init() -> void:
	layer = 20
	_font_luckiest = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	_font_baloo = load("res://assets/fonts/Baloo2.ttf")

func _ready() -> void:
	_build_cast_overlay()
	_build_settle_rows()

# ------------------------------------------------------------- cast overlay
func _build_cast_overlay() -> void:
	_cast = ColorRect.new()
	_cast.color = Color(0.015, 0.01, 0.025, 0.985)
	_cast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cast.visible = false
	add_child(_cast)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	_cast.add_child(vb)
	_cast_title = Label.new()
	_cast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_title.add_theme_font_override("font", _font_luckiest)
	_cast_title.add_theme_font_size_override("font_size", 52)
	_cast_title.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.09))
	_cast_title.add_theme_constant_override("outline_size", 12)
	vb.add_child(_cast_title)
	_cast_sub = Label.new()
	_cast_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_sub.add_theme_font_override("font", _font_baloo)
	_cast_sub.add_theme_font_size_override("font_size", 26)
	_cast_sub.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
	vb.add_child(_cast_sub)
	_cast_card = Label.new()
	_cast_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_card.add_theme_font_override("font", _font_baloo)
	_cast_card.add_theme_font_size_override("font_size", 30)
	_cast_card.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
	_cast_card.add_theme_constant_override("outline_size", 8)
	vb.add_child(_cast_card)

func cast_show(title: String, title_color: Color, sub: String, card: String, card_color: Color) -> void:
	_cast.visible = true
	_cast_title.text = title
	_cast_title.add_theme_color_override("font_color", title_color)
	_cast_sub.text = sub
	_cast_card.text = card
	_cast_card.add_theme_color_override("font_color", card_color)

func cast_hide() -> void:
	_cast.visible = false

# ------------------------------------------------------------- vote panel
## players: Array of {index, name, color}. Builds one portrait per player —
## every seat can be pointed at (the Charlatan may be accused too).
func build_vote_panel(players: Array) -> void:
	if _vote_root != null:
		_vote_root.queue_free()
	_portrait_boxes.clear()
	_portrait_frames.clear()
	_chips.clear()
	_chip_badges.clear()
	_chip_locks.clear()
	_vote_root = Control.new()
	_vote_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vote_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote_root.visible = false
	add_child(_vote_root)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 26)
	hb.anchor_left = 0.0
	hb.anchor_right = 1.0
	hb.anchor_top = 0.16
	hb.anchor_bottom = 0.16
	hb.offset_bottom = 210.0
	_vote_root.add_child(hb)
	for pl in players:
		var idx := int(pl.index)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		hb.add_child(col)
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.05, 0.09, 0.92)
		sb.border_color = pl.color
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 18.0
		sb.content_margin_right = 18.0
		sb.content_margin_top = 12.0
		sb.content_margin_bottom = 10.0
		frame.add_theme_stylebox_override("panel", sb)
		col.add_child(frame)
		_portrait_frames[idx] = frame
		var inner := VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		frame.add_child(inner)
		var badge_holder := CenterContainer.new()
		badge_holder.custom_minimum_size = Vector2(64, 64)
		inner.add_child(badge_holder)
		var badge := PlayerBadge.make(idx, 54)
		badge.color = pl.color
		badge_holder.add_child(badge)
		var nm := Label.new()
		nm.text = str(pl.name)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_override("font", _font_luckiest)
		nm.add_theme_font_size_override("font_size", 24)
		nm.add_theme_color_override("font_color", pl.color)
		nm.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
		nm.add_theme_constant_override("outline_size", 7)
		inner.add_child(nm)
		# chip zone: accusing badges land under the portrait
		var zone := VBoxContainer.new()
		zone.alignment = BoxContainer.ALIGNMENT_BEGIN
		zone.add_theme_constant_override("separation", 2)
		zone.custom_minimum_size = Vector2(120, 96)
		col.add_child(zone)
		_portrait_boxes[idx] = zone
	# one chip per voter, parked nowhere until the vote starts. Dark panel
	# behind each chip so it reads over the bright board (screenshot lesson).
	for pl in players:
		var voter := int(pl.index)
		var chip := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.05, 0.04, 0.07, 0.88)
		csb.set_corner_radius_all(6)
		csb.content_margin_left = 8.0
		csb.content_margin_right = 8.0
		csb.content_margin_top = 3.0
		csb.content_margin_bottom = 3.0
		chip.add_theme_stylebox_override("panel", csb)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		chip.add_child(row)
		var cb := PlayerBadge.make(voter, 20)
		cb.color = pl.color
		cb.dim = 0.5
		row.add_child(cb)
		var lock := Label.new()
		lock.text = "?"
		lock.add_theme_font_override("font", _font_baloo)
		lock.add_theme_font_size_override("font_size", 18)
		lock.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
		row.add_child(lock)
		_chips[voter] = chip
		_chip_badges[voter] = cb
		_chip_locks[voter] = lock

func show_vote_panel(v: bool) -> void:
	if _vote_root != null:
		_vote_root.visible = v

## Move voter's chip under `target` portrait; style by locked state.
func set_vote_chip(voter: int, target: int, locked: bool) -> void:
	if not _chips.has(voter) or not _portrait_boxes.has(target):
		return
	var chip: Control = _chips[voter]
	var zone: VBoxContainer = _portrait_boxes[target]
	if chip.get_parent() != zone:
		if chip.get_parent() != null:
			chip.get_parent().remove_child(chip)
		zone.add_child(chip)
	var badge: PlayerBadge = _chip_badges[voter]
	badge.dim = 1.0 if locked else 0.5
	var lock: Label = _chip_locks[voter]
	lock.text = "LOCKED" if locked else "?"
	lock.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if locked else Color(0.7, 0.66, 0.6))

func remove_vote_chip(voter: int) -> void:
	if _chips.has(voter) and _chips[voter].get_parent() != null:
		_chips[voter].get_parent().remove_child(_chips[voter])

## Reveal styling: dim every portrait except the unmasked charlatan.
func spotlight_portrait(charlatan: int) -> void:
	for idx in _portrait_frames:
		var frame: PanelContainer = _portrait_frames[idx]
		frame.modulate = Color(1, 1, 1, 1.0) if idx == charlatan else Color(0.45, 0.42, 0.5, 0.75)

# ------------------------------------------------------------- settlement
func _build_settle_rows() -> void:
	_settle_rows = VBoxContainer.new()
	_settle_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_settle_rows.add_theme_constant_override("separation", 4)
	_settle_rows.anchor_left = 0.0
	_settle_rows.anchor_right = 1.0
	_settle_rows.anchor_top = 0.67
	_settle_rows.anchor_bottom = 0.67
	_settle_rows.offset_bottom = 150.0
	add_child(_settle_rows)

## animate=true fades the row in over ~0.18s, for the staggered readout; the
## default (all-at-once) path stays byte-identical for headless/tally.
func add_settle_row(text: String, color: Color, animate := false) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font_baloo)
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.07))
	l.add_theme_constant_override("outline_size", 7)
	_settle_rows.add_child(l)
	if animate:
		l.modulate.a = 0.0
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.18)

## Punctuate the completed ledger with a brief warm overbright flash (the total
## has landed). The room's glow blooms the >1 modulate, then it settles back.
func pulse_settle() -> void:
	if _settle_rows == null:
		return
	_settle_rows.modulate = Color(1.6, 1.5, 1.2)
	var tw := _settle_rows.create_tween()
	tw.tween_property(_settle_rows, "modulate", Color(1, 1, 1, 1), 0.45).set_trans(Tween.TRANS_SINE)

func clear_settle_rows() -> void:
	for c in _settle_rows.get_children():
		c.queue_free()
