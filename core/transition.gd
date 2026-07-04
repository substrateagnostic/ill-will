extends CanvasLayer
## Autoload Transition: soft fade between scenes. Transition.change_scene(path)

var rect: ColorRect

func _ready() -> void:
	layer = 100
	rect = ColorRect.new()
	rect.color = Color(0.05, 0.04, 0.06, 1)
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)

func change_scene(path: String) -> void:
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.22)
	await tw.finished
	get_tree().change_scene_to_file(path)
	var tw2 := create_tween()
	tw2.tween_interval(0.05)
	tw2.tween_property(rect, "modulate:a", 0.0, 0.3)
