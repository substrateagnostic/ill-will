class_name SeanceWheel
extends Control
## THE ONE VISIBLE WHEEL (doc 24 F13). The SÉANCE space's planchette dial, made to
## actually spin: a four-slot wheel whose needle accelerates, then decelerates
## onto the slot the SIM ALREADY CHOSE. The wheel is pure theater — it animates
## TOWARD a decided result and never decides anything, so the receipt is safe. It
## draws no rng at all; the spin is a fixed number of turns plus the target angle.
##
## Angle convention: 0 points UP, increasing CLOCKWISE. Slot i is centred at
## i*90° so a landed needle sits in the middle of its wedge. Reuses the séance
## minigame's "rotate a pointer to a heading" idea, restated for a fixed dial.

const SPIN_TURNS := 3.0
const SPIN_DUR := 2.2
const HOLD := 0.55
const DIAM := 384.0

# THE STOP BUTTON (W6) — a prominent, entirely powerless control. Presentation
# only: the wheel's outcome is decided by the sim before it ever spins, so this
# button does nothing to it and emits nothing to the net mirror. It depresses,
# waits a beat, and files one deadpan line. The lines escalate by press count and
# hold at the last, across the whole night (the estate keeps count).
const STOP_TOAST := [
	"The wheel has received your input.",
	"The wheel will proceed.",
	"The wheel appreciates your continued involvement.",
]

# Wedge tints — a purple séance family, each distinct so the four read apart
# (title text rides on top; never colour alone).
const WEDGE_COLORS: Array[Color] = [
	Color(0.42, 0.30, 0.62),
	Color(0.30, 0.36, 0.66),
	Color(0.56, 0.32, 0.52),
	Color(0.34, 0.46, 0.60),
]

var fast := false
var _needle := 0.0                 # radians, 0 = up, clockwise
var _landed := -1                  # slot to highlight once settled (-1 = none)
var _titles: Array[String] = []
# STOP button (W6). Built once when the dial is interactive (windowed, not fast);
# a child of the dial so it fades and hides exactly with it, and never draws in a
# headless/fast run.
var _stop_btn: Button = null
var _toast: Label = null
var _toast_tw: Tween = null
var _stop_count := 0

func setup(host: Control, slot_titles: Array, is_fast: bool) -> void:
	fast = is_fast
	_titles.clear()
	for t in slot_titles:
		_titles.append(String(t))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(DIAM, DIAM)
	size = Vector2(DIAM, DIAM)
	offset_left = -DIAM * 0.5; offset_right = DIAM * 0.5
	# Sit a touch above centre so the reveal lower-third never covers the dial.
	offset_top = -DIAM * 0.5 - 70.0; offset_bottom = DIAM * 0.5 - 70.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	host.add_child(self)
	# The dial is only ever interactive in a real windowed sitting; the fast soak
	# and any headless run never build the button, so it can't touch the receipt.
	if not fast and DisplayServer.get_name() != "headless":
		_build_stop_ui()

## The powerless STOP control + its deadpan toast. Both children of the dial, so
## the dial's visibility and modulate carry them.
func _build_stop_ui() -> void:
	_stop_btn = Button.new()
	_stop_btn.text = "STOP"
	_stop_btn.focus_mode = Control.FOCUS_NONE
	_stop_btn.custom_minimum_size = Vector2(184, 58)
	_stop_btn.size = _stop_btn.custom_minimum_size
	_stop_btn.pivot_offset = _stop_btn.custom_minimum_size * 0.5
	_stop_btn.add_theme_font_size_override("font_size", 26)
	# Centred horizontally, just below the disc (the dial sits above screen centre,
	# so this lands near centre — prominent, clear of the wedges).
	_stop_btn.position = Vector2(DIAM * 0.5 - 92.0, DIAM + 8.0)
	_stop_btn.pressed.connect(_on_stop_pressed)
	add_child(_stop_btn)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(DIAM + 80.0, 0)
	_toast.size = Vector2(DIAM + 80.0, 40.0)
	_toast.position = Vector2(-40.0, DIAM + 78.0)
	_toast.add_theme_font_size_override("font_size", 21)
	_toast.add_theme_color_override("font_color", Color(0.92, 0.87, 0.76))
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.07))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)

## Press → depress → a beat → a deadpan toast. Never touches _landed / the spin /
## the sim; sends nothing across the wire. Pure joy (W6).
func _on_stop_pressed() -> void:
	if _stop_btn != null:
		_stop_btn.scale = Vector2(0.93, 0.93)
		var tw := create_tween()
		tw.tween_property(_stop_btn, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Sfx.play("card", -8.0)
	var idx := mini(_stop_count, STOP_TOAST.size() - 1)
	_stop_count += 1
	var line: String = STOP_TOAST[idx]
	get_tree().create_timer(0.35).timeout.connect(func() -> void: _show_toast(line))

func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_interval(2.4)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tw.tween_callback(func() -> void:
		if _toast != null:
			_toast.visible = false)

## --- dev capture (W6): windowed-only, drives the button for a screenshot. ---
func debug_show() -> void:
	_needle = 0.0
	_landed = -1
	visible = true
	modulate.a = 1.0
	queue_redraw()

func debug_press_stop() -> void:
	_on_stop_pressed()

## Spin the needle to the pre-decided slot and settle. Async; the caller awaits
## it so the outcome text lands AFTER the wheel does. Instant/no-op under fast.
func spin_to(slot: int) -> void:
	var n := maxi(1, _titles.size())
	var target_slot := ((slot % n) + n) % n
	var target := deg_to_rad(360.0 * SPIN_TURNS + float(target_slot) * (360.0 / float(n)))
	if fast:
		_needle = target
		_landed = target_slot
		return
	_landed = -1
	_needle = 0.0
	visible = true
	modulate.a = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_method(_set_needle, 0.0, target, SPIN_DUR) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_landed = target_slot
		Sfx.play("sink", -3.0)
		queue_redraw())
	tw.tween_interval(HOLD)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	visible = false

func _set_needle(a: float) -> void:
	_needle = a
	queue_redraw()

func _draw() -> void:
	var n := maxi(1, _titles.size())
	var center := size * 0.5
	var radius := DIAM * 0.5 - 16.0
	var font := ThemeDB.fallback_font
	# Backing disc.
	draw_circle(center, radius + 10.0, Color(0.05, 0.04, 0.08, 0.92))
	# Wedges.
	for i in n:
		var mid_deg := float(i) * (360.0 / float(n))
		var half := (360.0 / float(n)) * 0.5
		var pts := PackedVector2Array()
		pts.append(center)
		var steps := 16
		for s in range(steps + 1):
			var d := mid_deg - half + (2.0 * half) * float(s) / float(steps)
			pts.append(center + _dir(deg_to_rad(d)) * radius)
		var base: Color = WEDGE_COLORS[i % WEDGE_COLORS.size()]
		var c := base.lerp(Color.WHITE, 0.35) if i == _landed else base
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.92 if i == _landed else 0.72))
		# Slot title, wrapped short, at the wedge centre.
		var label_pos := center + _dir(deg_to_rad(mid_deg)) * (radius * 0.60)
		var title: String = _titles[i] if i < _titles.size() else ""
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 19)
		draw_string(font, label_pos - Vector2(tw.x * 0.5, -6), title,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 19,
			Color.WHITE if i == _landed else Color(0.92, 0.9, 0.98))
	# Gold rim.
	draw_arc(center, radius + 10.0, 0.0, TAU, 64, Color(0.82, 0.72, 0.42), 3.0)
	# Needle — a planchette pointer from the hub to the rim.
	var tip := center + _dir(_needle) * (radius - 6.0)
	var back := center - _dir(_needle) * 26.0
	var perp := _dir(_needle + PI * 0.5) * 12.0
	var needle := PackedVector2Array([tip, center + perp, back, center - perp])
	draw_colored_polygon(needle, Color(0.98, 0.86, 0.5))
	draw_circle(center, 15.0, Color(0.14, 0.12, 0.18))
	draw_arc(center, 15.0, 0.0, TAU, 20, Color(0.82, 0.72, 0.42), 2.0)

## Unit screen direction for an up-zero, clockwise angle (screen Y is down).
func _dir(theta: float) -> Vector2:
	return Vector2(sin(theta), -cos(theta))
