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
