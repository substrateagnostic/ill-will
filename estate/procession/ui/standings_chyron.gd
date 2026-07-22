class_name ProcessionChyron
extends Control
## THE LIVE STANDINGS SCOREBOARD (#87) — the funeral-program CHYRON.
##
## A slim, always-on strip of four seat slots (badge + wreath glyph + count,
## with a dim penny tail) that rides the procession HUD during play. Its one
## law: WREATH TOTALS NEVER CHANGE INVISIBLY. Every wreath a seat earns either
## flies in as an attributed number that LANDS in that seat's slot and ticks the
## count at the instant of scoring (fly_gain, extending the B1 broadcast), or is
## caught by reconcile() and ticked into place the moment the HUD refreshes — so
## a number can never quietly jump.
##
## At round end / on return from a minigame / as the FINAL BELL nears, the strip
## UNFURLS into a full parchment LEDGER (ledger_beat): each seat's total and the
## round's delta (+N ▲), ~4s, auto-dismissing, and skippable by ANY single input
## — the never-required law, it blocks no one.
##
## PRESENTATION ONLY. Jitter draws from a private wall-clock RNG, never the sim
## stream; every animated entry point no-ops under `fast`, so a headless receipt
## renders and perturbs nothing. HIDDEN during minigames for free: it is a child
## of the HUD CanvasLayer the board toggles off while a module owns the screen.

const Spaces := preload("res://estate/procession/board_spaces.gd")
const WREATH := Spaces.WREATH_GLYPH   # ⚘ — the estate's canonical currency marks,
const PENNY := Spaces.PENNY_GLYPH     # ¢   sourced once so the strip can never drift
const PARCHMENT := Color(0.92, 0.86, 0.70)      # the deed/ledger vellum (matches board_fx)
const INK := Color(0.20, 0.12, 0.06)            # will-reading ink
const GOLD := Color(1.0, 0.85, 0.45)            # the wreath glyph's warm pop
const UP := Color(0.42, 0.86, 0.46)             # gain arrow ▲
const DOWN := Color(0.92, 0.44, 0.36)           # loss arrow ▼
const RISE := 70.0                              # how far a flying number lifts before homing
const NUM_DUR := 0.80
const TICK_DUR := 0.42
const HOLD := 4.0                               # the ledger's auto-dismiss window

var cam: Camera3D = null
var fast := false

var _roster: Array = []
var _strip: PanelContainer
var _fly_host: Control
var _slots: Array = []                # per seat {slot, num, penny, shown:int, pending:int}
var _rng := RandomNumberGenerator.new()

var _ledger: PanelContainer
var _ledger_rows: VBoxContainer
var _ledger_base: Array[int] = []     # totals snapshot; the ledger delta is measured from here
var _ledger_open := false
var _serif: Font

## Build the strip, the fly layer above it, and the (hidden) parchment ledger.
## Slots stay in FIXED seat order so a flying number always has a stable target
## and the eye can hold one seat; rank is never printed (the counts show it —
## show, don't tell).
func setup(roster: Array, camera: Camera3D, is_fast: bool) -> void:
	_roster = roster
	cam = camera
	fast = is_fast
	_rng.seed = int(Time.get_ticks_usec())
	name = "StandingsChyron"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_serif = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
	if _serif == null:
		_serif = load("res://assets/fonts/Baloo2.ttf")

	_ledger_base.clear()
	for _i in _roster.size():
		_ledger_base.append(0)

	_build_strip()
	_build_ledger()

	_fly_host = Control.new()
	_fly_host.name = "ChyronFly"
	_fly_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fly_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fly_host)   # added last -> flying numbers draw above the strip

## The always-on strip: a dark scrim rule with a warm-gold edge (the moonlit dark
## with a color pop, never grimdark), pinned top-centre in the free band under the
## status bar. Each slot is one slim row: seat badge, gold ⚘, bright count, dim ¢.
func _build_strip() -> void:
	_strip = PanelContainer.new()
	_strip.name = "Chyron"
	_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.offset_top = 56.0
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.86)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.85, 0.70, 0.35, 0.55)   # thin gold program-rule
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 7; sb.content_margin_bottom = 7
	_strip.add_theme_stylebox_override("panel", sb)
	add_child(_strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_child(row)

	_slots.clear()
	for i in _roster.size():
		if i > 0:
			var div := Panel.new()
			div.custom_minimum_size = Vector2(2, 30)
			var dsb := StyleBoxFlat.new()
			dsb.bg_color = Color(0.55, 0.5, 0.42, 0.35)
			div.add_theme_stylebox_override("panel", dsb)
			div.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(div)

		var slot := HBoxContainer.new()
		slot.add_theme_constant_override("separation", 6)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)

		var badge := PlayerBadge.make(i, 26)
		badge.color = _color(i)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_child(badge)

		var glyph := _lbl(WREATH, 24, GOLD)
		slot.add_child(glyph)
		var num := _lbl("0", 27, Color(0.97, 0.96, 1.0))
		slot.add_child(num)
		var penny := _lbl("%s0" % PENNY, 15, Color(0.78, 0.76, 0.60))
		penny.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_child(penny)

		_slots.append({"slot": slot, "num": num, "penny": penny, "shown": 0, "pending": 0})

## The parchment LEDGER overlay, furled (scale.y 0) until ledger_beat() unrolls it.
func _build_ledger() -> void:
	_ledger = PanelContainer.new()
	_ledger.name = "Ledger"
	_ledger.set_anchors_preset(Control.PRESET_CENTER)
	_ledger.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ledger.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ledger.custom_minimum_size = Vector2(520, 0)
	_ledger.pivot_offset = Vector2(260, 0)     # unrolls downward from the top rod
	_ledger.scale = Vector2(1, 0)
	_ledger.modulate.a = 0.0
	_ledger.visible = false
	_ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.45, 0.30, 0.14)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 16
	sb.content_margin_left = 30; sb.content_margin_right = 30
	sb.content_margin_top = 20; sb.content_margin_bottom = 24
	_ledger.add_theme_stylebox_override("panel", sb)
	add_child(_ledger)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_ledger.add_child(col)

	# The one permitted word — set in the estate's will-reading face.
	var title := _lbl("THE LEDGER", 40, Color(0.30, 0.10, 0.07))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _serif != null:
		title.add_theme_font_override("font", _serif)
	title.add_theme_constant_override("outline_size", 0)
	col.add_child(title)

	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0, 3)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.55, 0.10, 0.10, 0.8)   # a red wax rule
	rule.add_theme_stylebox_override("panel", rsb)
	col.add_child(rule)

	_ledger_rows = VBoxContainer.new()
	_ledger_rows.add_theme_constant_override("separation", 10)
	col.add_child(_ledger_rows)

## ---------------------------------------------------------------- live ticks

## Set the dim penny tail on each slot (pennies never fly here — they belong to
## the chip broadcast; the strip just mirrors the current purse).
func set_pennies(grudge: Array) -> void:
	for i in _slots.size():
		if i < grudge.size():
			(_slots[i].penny as Label).text = "%s%d" % [PENNY, int(grudge[i])]

## Catch every wreath change the HUD knows about. For each seat the strip should
## show (total − in-flight), so a number already arcing toward a slot is not
## double-counted; anything else (arrival wreaths, liquidation, a debt trap that
## never flew) is ticked into place NOW — visibly, never a silent snap.
func reconcile(wreaths: Array) -> void:
	for i in _slots.size():
		if i >= wreaths.size():
			continue
		var desired: int = int(wreaths[i]) - int(_slots[i].pending)
		if int(_slots[i].shown) != desired:
			_tick_to(i, desired)

## A scoring wreath number, extending the B1 flying-number broadcast: it lifts
## off the world point that earned it and homes to the owning seat's slot, and
## the count ticks up at the instant it lands — momentum shown AT the moment of
## scoring. Returns immediately (fire-and-forget); reconcile() remains the
## backstop if the frame is skipped.
func fly_gain(seat: int, amount: int, world_from: Vector3, color: Color) -> void:
	if fast or amount == 0 or seat < 0 or seat >= _slots.size():
		return
	_slots[seat].pending = int(_slots[seat].pending) + amount
	var lbl := Label.new()
	var sign_s := "+" if amount > 0 else "−"
	lbl.text = "%s%d%s" % [sign_s, absi(amount), WREATH]
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.z_index = 30
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly_host.add_child(lbl)
	var from := _screen_of(world_from)
	lbl.pivot_offset = Vector2(20, 20)
	lbl.position = from
	lbl.scale = Vector2(0.4, 0.4)
	var lift := from + Vector2(_rng.randf_range(-24.0, 24.0), -RISE)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.05, 1.05), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", lift, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", _slot_screen_pos(seat), NUM_DUR) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(lbl, "scale", Vector2(0.6, 0.6), NUM_DUR)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, NUM_DUR).set_delay(NUM_DUR * 0.55)
	tw.tween_callback(func() -> void:
		_slots[seat].pending = int(_slots[seat].pending) - amount
		_tick_to(seat, int(_slots[seat].shown) + amount)
		lbl.queue_free())

## Roll the visible count from its current value to `target`, and pop the slot —
## the number is never allowed to just change.
func _tick_to(seat: int, target: int) -> void:
	var from: int = int(_slots[seat].shown)
	_slots[seat].shown = target
	var num := _slots[seat].num as Label
	if fast:
		num.text = str(target)
		return
	if from != target:
		var tw := num.create_tween()
		tw.tween_method(func(v: float) -> void: num.text = str(int(round(v))),
			float(from), float(target), TICK_DUR) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# a saturated pop on the slot + a colour flash on the number toward the seat hue
	var slot := _slots[seat].slot as Control
	slot.pivot_offset = slot.size * 0.5
	var up := target >= from
	var flash := (_color(seat) if up else DOWN).lerp(Color.WHITE, 0.15)
	num.modulate = flash
	var pt := slot.create_tween()
	pt.tween_property(slot, "scale", Vector2(1.16, 1.16), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(slot, "scale", Vector2(1, 1), 0.16).set_trans(Tween.TRANS_SINE)
	num.create_tween().tween_property(num, "modulate", Color.WHITE, TICK_DUR).set_trans(Tween.TRANS_SINE)

## ---------------------------------------------------------------- the ledger

## Unfurl the parchment, hold ~4s (auto-dismiss), then furl away. ANY single
## human input skips it early — it must never block anyone. A no-op under fast /
## when the strip is hidden (a module owns the screen).
func ledger_beat(wreaths: Array) -> void:
	if fast or not is_visible_in_tree() or _ledger_open:
		return
	_ledger_open = true
	_populate_ledger(wreaths)
	for i in wreaths.size():
		if i < _ledger_base.size():
			_ledger_base[i] = int(wreaths[i])
	_ledger.visible = true
	_ledger.scale = Vector2(1, 0)
	_ledger.modulate.a = 0.0
	var open_tw := _ledger.create_tween()
	open_tw.tween_property(_ledger, "scale", Vector2(1, 1), 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tw.parallel().tween_property(_ledger, "modulate:a", 1.0, 0.28)
	await open_tw.finished

	var t := 0.0
	while t < HOLD:
		if _skip_pressed():
			break
		await get_tree().process_frame
		t += get_process_delta_time()

	var close_tw := _ledger.create_tween()
	close_tw.tween_property(_ledger, "scale", Vector2(1, 0), 0.26) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_tw.parallel().tween_property(_ledger, "modulate:a", 0.0, 0.26)
	await close_tw.finished
	_ledger.visible = false
	_ledger_open = false

## Rebuild the ledger rows: leader first (this is the recap ceremony, a rank read
## is welcome here), each with total ⚘ and the round's delta as +N ▲ / −N ▼ / —.
func _populate_ledger(wreaths: Array) -> void:
	for c in _ledger_rows.get_children():
		c.queue_free()
	var order: Array = []
	for i in _roster.size():
		order.append(i)
	order.sort_custom(func(a, b): return int(wreaths[a]) > int(wreaths[b]))

	for seat in order:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.custom_minimum_size = Vector2(0, 40)
		_ledger_rows.add_child(row)

		var badge := PlayerBadge.make(int(seat), 30)
		badge.color = _color(int(seat))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)

		var total := _ink_lbl("%s%d" % [WREATH, int(wreaths[seat])], 32)
		total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(total)

		var base: int = int(_ledger_base[seat]) if int(seat) < _ledger_base.size() else 0
		var delta: int = int(wreaths[seat]) - base
		var d_lbl := _ink_lbl("", 30)
		if delta > 0:
			d_lbl.text = "+%d %s▲" % [delta, WREATH]
			d_lbl.add_theme_color_override("font_color", UP.lerp(INK, 0.15))
		elif delta < 0:
			d_lbl.text = "−%d %s▼" % [absi(delta), WREATH]
			d_lbl.add_theme_color_override("font_color", DOWN.lerp(INK, 0.15))
		else:
			d_lbl.text = "—"
			d_lbl.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28))
		row.add_child(d_lbl)

## ---------------------------------------------------------------- helpers

func _skip_pressed() -> bool:
	var pi := get_node_or_null(^"/root/PlayerInput")
	if pi == null:
		return false
	for i in _roster.size():
		if bool(_roster[i].bot):
			continue
		if pi.just_pressed(i, "a") or pi.just_pressed(i, "b"):
			return true
	return false

func _color(seat: int) -> Color:
	if seat >= 0 and seat < _roster.size():
		return _roster[seat].color
	return Color.WHITE

## Project a world point to strip-local (== viewport) pixels; screen centre if
## the point is behind the camera. Mirrors ProcessionFx._screen_of.
func _screen_of(world: Vector3) -> Vector2:
	if not is_instance_valid(cam):
		return size * 0.5
	if cam.is_position_behind(world):
		return size * 0.5
	return cam.unproject_position(world)

func _slot_screen_pos(seat: int) -> Vector2:
	if seat >= 0 and seat < _slots.size():
		var num: Control = _slots[seat].num
		if num != null and num.is_inside_tree():
			return num.global_position + num.size * 0.5
	return size * Vector2(0.5, 0.12)

func _lbl(text: String, sz: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _ink_lbl(text: String, sz: int) -> Label:
	# Parchment ink: the will-reading serif, no dark outline (it fights vellum).
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", INK)
	if _serif != null:
		l.add_theme_font_override("font", _serif)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
