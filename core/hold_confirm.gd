extends Control
class_name HoldConfirm
## Reusable hold-to-confirm ring. Progress is geometric (arc length, not color),
## with tick marks and a moving spoke so the state remains visible in grayscale.

signal completed

@export var duration: float = 1.0
@export var ring_color: Color = Color(1.0, 0.84, 0.25, 1.0)
@export var track_color: Color = Color(0.16, 0.14, 0.2, 0.92)

var progress: float = 0.0
var _complete_sent: bool = false
var _bound_button: BaseButton = null
var _bound_button_held: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(58.0, 58.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(seconds: float) -> void:
	duration = maxf(seconds, 0.05)
	cancel()

func bind_button(button: BaseButton, seconds: float) -> void:
	_bound_button = button
	configure(seconds)
	button.button_down.connect(func(): _bound_button_held = true)
	button.button_up.connect(func(): _bound_button_held = false)

func cancel() -> void:
	progress = 0.0
	_complete_sent = false
	queue_redraw()

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	_complete_sent = progress >= 1.0
	queue_redraw()

func tick(held: bool, delta: float) -> bool:
	if not held:
		if progress > 0.0 or _complete_sent:
			cancel()
		return false
	if _complete_sent:
		return false
	progress = clampf(progress + (delta / maxf(duration, 0.05)), 0.0, 1.0)
	queue_redraw()
	if progress >= 1.0:
		_complete_sent = true
		completed.emit()
		return true
	return false

func _process(delta: float) -> void:
	if _bound_button == null:
		return
	tick(_bound_button_held and is_instance_valid(_bound_button) and _bound_button.visible, delta)

func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = side * 0.38
	draw_circle(center, radius + 7.0, Color(0.03, 0.025, 0.04, 0.78))
	draw_arc(center, radius, 0.0, TAU, 64, track_color, 8.0, true)
	for i: int in range(12):
		var a: float = -PI * 0.5 + (TAU * float(i) / 12.0)
		var inner: Vector2 = center + Vector2(cos(a), sin(a)) * (radius - 7.0)
		var outer: Vector2 = center + Vector2(cos(a), sin(a)) * (radius + 5.0)
		draw_line(inner, outer, Color(0.95, 0.92, 0.82, 0.72), 2.0, true)
	if progress > 0.0:
		var end_angle: float = -PI * 0.5 + TAU * progress
		draw_arc(center, radius, -PI * 0.5, end_angle, 64, ring_color, 9.0, true)
		var spoke_end: Vector2 = center + Vector2(cos(end_angle), sin(end_angle)) * (radius + 8.0)
		draw_line(center, spoke_end, Color(1.0, 1.0, 1.0, 0.9), 3.0, true)
	var box_half: float = 5.0 + 8.0 * progress
	var rect: Rect2 = Rect2(center - Vector2(box_half, box_half), Vector2(box_half * 2.0, box_half * 2.0))
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.18 + 0.34 * progress), false, 2.0)
