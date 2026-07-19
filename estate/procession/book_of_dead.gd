class_name ProcessionBook
extends Control
## THE BOOK OF THE DEAD (doc 32, v1 — sealed side-bets, cosmetic stakes).
##
## During every roll phase a quiet `📖 B · BET` hint sits under each seat's
## corner chip. B TOGGLES the seat's book strip open at its corner (never the
## centre, never over the meter); flick left/right walks the seat cameos; A
## SEALS; B closes without sealing. Re-open to change your mind until the
## minigame slams the book shut (an audible thump — last call). A sealed chip
## wears a wax mark: public THAT you bet, private WHOM. Self-bets are allowed
## — the cameo wears a mirror glint, and losing one earns the Executor's
## public ribbing. Bots bet (seeded upstream in procession — this control
## NEVER draws rng). Reveal at settlement: seals flip to cameos, the correct
## catch gold. Stakes v1 are cosmetic: a laurel wisp on the figurine next
## cycle + a chronicle line + an album record.
##
## Input rules (verb budget, doc 28 §0a): the ACTIVE roller's book closes at
## their turn (their A belongs to THE LAST BREATH); opening the book during a
## bot's over-shoulder roll deliberately coexists with the B camera-skip —
## you get your book AND the wide table view, one press.

const HINT_TEXT := "📖 B · BET"
const SEAL_TEXT := "📖 ⬤"
const WAX := Color(0.62, 0.12, 0.10)

var roster: Array = []
var bets: Array[int] = []          # per seat: -1 none, else target seat
var active := false                # a roll phase is open for bets
var meter_seat := -1               # seat driving THE LAST BREATH right now

var _pro: Node = null              # procession (chip anchors)
var _open: Array[bool] = []
var _sel: Array[int] = []
var _flick: Array[int] = []        # -1/0/1 stick latch per seat
var _strips: Array = []            # per seat {root, cams:Array, frames:Array}
var _hints: Array = []             # per seat Label
var _reveal_root: Control = null

func setup(pro: Node, ros: Array) -> void:
	_pro = pro
	roster = ros
	bets.resize(ros.size()); bets.fill(-1)
	_open.resize(ros.size()); _open.fill(false)
	_sel.resize(ros.size()); _sel.fill(0)
	_flick.resize(ros.size()); _flick.fill(0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in ros.size():
		var hint := Label.new()
		hint.text = HINT_TEXT
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45, 0.75))
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		hint.add_theme_constant_override("outline_size", 5)
		hint.visible = false
		add_child(hint)
		_hints.append(hint)
		_strips.append(_make_strip(i))

## The strip: a slim ink panel of four seat cameos above the seat's chip.
func _make_strip(seat: int) -> Dictionary:
	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.075, 0.94)
	sb.set_border_width_all(2)
	sb.border_color = Color(roster[seat].color).darkened(0.2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	root.add_theme_stylebox_override("panel", sb)
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	var cams: Array = []
	var frames: Array = []
	for t in roster.size():
		var frame := PanelContainer.new()
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0, 0, 0, 0)
		fb.set_border_width_all(2)
		fb.border_color = Color(1, 1, 1, 0.0)
		fb.set_corner_radius_all(6)
		fb.content_margin_left = 3; fb.content_margin_right = 3
		fb.content_margin_top = 3; fb.content_margin_bottom = 3
		frame.add_theme_stylebox_override("panel", fb)
		row.add_child(frame)
		var cam := PlayerBadge.make(t, 34)
		cam.color = roster[t].color
		frame.add_child(cam)
		if t == seat:
			# the mirror glint — a self-bet knows itself
			var glint := Label.new()
			glint.text = "✦"
			glint.add_theme_font_size_override("font_size", 12)
			glint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
			glint.position = Vector2(24, -2)
			frame.add_child(glint)
		cams.append(cam)
		frames.append(fb)
	return {"root": root, "cams": cams, "frames": frames}

# --------------------------------------------------------------------------
# PHASE HOOKS (procession drives these)
# --------------------------------------------------------------------------

## A new cycle's roll phase opens: bets reset, hints on.
func open_phase() -> void:
	active = true
	for i in roster.size():
		bets[i] = -1
		_open[i] = false
		_sel[i] = i   # start the flick on your own cameo — self-bet is one A away
	_layout()

## The minigame intro slams the book shut — the audible last call.
func slam() -> void:
	if not active:
		return
	active = false
	for i in roster.size():
		_open[i] = false
	_layout()
	Sfx.play("impact_wood", -10.0, 0.62)

## A seeded bot bet arrives from upstream (procession draws, the book obeys).
func place_bet(seat: int, target: int) -> void:
	bets[seat] = clampi(target, 0, roster.size() - 1)
	_layout()

## The settlement reveal: seals flip to cameos; the correct catch gold.
## Returns the seats whose bets named a winner. ~2s, zero words.
func reveal(winners: Array, fast: bool) -> Array:
	var correct: Array = []
	for i in bets.size():
		if bets[i] >= 0 and winners.has(bets[i]):
			correct.append(i)
	if fast:
		return correct
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 18)
	strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	strip.offset_top = -240
	strip.offset_bottom = -170
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(strip)
	_reveal_root = strip
	var any := false
	for i in bets.size():
		if bets[i] < 0:
			continue
		any = true
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_child(cell)
		var who := PlayerBadge.make(i, 30)
		who.color = roster[i].color
		cell.add_child(who)
		var arrow := Label.new()
		arrow.text = "▾"
		arrow.add_theme_font_size_override("font_size", 13)
		arrow.add_theme_color_override("font_color", Color(0.8, 0.76, 0.66))
		arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(arrow)
		var cam := PlayerBadge.make(bets[i], 40)
		cam.color = roster[bets[i]].color
		if correct.has(i):
			cam.modulate = Color(1.35, 1.2, 0.75)
		else:
			cam.modulate = Color(0.55, 0.55, 0.6)
		cell.add_child(cam)
	if any:
		Sfx.play("impact_wood", -14.0, 1.1)
	return correct

func clear_reveal() -> void:
	if _reveal_root != null:
		_reveal_root.queue_free()
		_reveal_root = null

# --------------------------------------------------------------------------
# INPUT — local humans only; bots and remotes never touch this surface.
# --------------------------------------------------------------------------
func _process(_dt: float) -> void:
	if not active or _pro == null:
		return
	for i in roster.size():
		if bool(roster[i].bot):
			continue
		if _pro.has_method("_is_remote_seat") and bool(_pro._is_remote_seat(i)):
			continue
		# the active roller's hands belong to THE LAST BREATH
		if i == meter_seat:
			if _open[i]:
				_open[i] = false
				_layout()
			continue
		if PlayerInput.just_pressed(i, "b"):
			_open[i] = not _open[i]
			_layout()
		if not _open[i]:
			continue
		var mx := PlayerInput.get_move(i).x
		var step := 0
		if mx > 0.6 and _flick[i] != 1:
			step = 1
			_flick[i] = 1
		elif mx < -0.6 and _flick[i] != -1:
			step = -1
			_flick[i] = -1
		elif absf(mx) < 0.3:
			_flick[i] = 0
		if step != 0:
			_sel[i] = posmod(_sel[i] + step, roster.size())
			Sfx.play("ui_move", -18.0)
			_layout()
		if PlayerInput.just_pressed(i, "a"):
			bets[i] = _sel[i]
			_open[i] = false
			Sfx.play("ui_confirm", -14.0, 0.8)
			_layout()

## Re-anchor every strip/hint to its chip and repaint states. Cheap; called
## on state changes and once per open_phase (chips do not move mid-phase).
func _layout() -> void:
	for i in roster.size():
		var chip: Vector2 = _pro._chip_screen_pos(i)
		var hint := _hints[i] as Label
		hint.visible = active
		hint.text = SEAL_TEXT if bets[i] >= 0 else HINT_TEXT
		hint.add_theme_color_override("font_color",
			WAX if bets[i] >= 0 else Color(0.85, 0.74, 0.45, 0.75))
		# the chips hug the screen's bottom edge — "under your corner" tucks
		# just ABOVE the chip panel, where there is actually sky to sit in
		hint.position = chip + Vector2(-34.0, -96.0)
		var s := _strips[i] as Dictionary
		var root := s.root as Control
		root.visible = active and _open[i]
		if root.visible:
			root.position = chip + Vector2(-92.0, -196.0)
			for t in roster.size():
				var fb := s.frames[t] as StyleBoxFlat
				var chosen := t == _sel[i]
				fb.border_color = Color(1, 0.86, 0.42, 1.0) if chosen else Color(1, 1, 1, 0.06)
				(s.cams[t] as Control).modulate = Color(1.15, 1.1, 1.0) if chosen \
					else Color(0.7, 0.7, 0.75)
