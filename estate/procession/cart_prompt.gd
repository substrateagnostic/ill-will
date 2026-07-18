class_name ProcessionCartPrompt
extends Control
## THE PEDDLER'S PROMPT — one modal list picker for every P2 table decision:
## the priced cart (wares with prices, unaffordables greyed), the pre-roll
## item beat, THE INVITATION's game pick, CROW'S CUT target choice, and the
## LETTERS OF ADMINISTRATION acceptance. House chrome (dark scrim + gold
## rule), gamepad-first per core/ui_focus.gd, and TIME-BOXED — a wandering
## human auto-commits the LEAVE row when the window expires, so one absent
## seat never stalls the table.
##
## PRESENTATION + INPUT ONLY (the crossroads_prompt doctrine): draws no rng,
## mutates no sim state; returns an index into `entries` (or -1 for LEAVE)
## and dies. Bots never see it; capture poses it once for the verification
## screenshot.

var _chosen := -999
var _buttons: Array = []
var _leave_btn: Button = null
var _window := 12.0

## entries: [{label, sub?, color?, disabled?}]. focus_leave parks the cursor
## on the LEAVE row (opt-in prompts default to declining).
func open(header: String, sub: String, header_color: Color, entries: Array,
		leave_label: String, focus_leave := false, window := 12.0) -> void:
	_window = window
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _panel_box())
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var head := Label.new()
	head.text = header
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 32)
	head.add_theme_color_override("font_color", header_color)
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	head.add_theme_constant_override("outline_size", 8)
	col.add_child(head)
	if sub != "":
		var subl := Label.new()
		subl.text = sub
		subl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subl.add_theme_font_size_override("font_size", 18)
		subl.modulate = Color(0.92, 0.88, 0.72)
		col.add_child(subl)

	for k in entries.size():
		var e: Dictionary = entries[k]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(620, 46)
		btn.text = String(e.get("label", "?"))
		btn.disabled = bool(e.get("disabled", false))
		btn.add_theme_font_size_override("font_size", 22)
		var ec: Color = e.get("color", Color(0.95, 0.92, 0.8))
		btn.add_theme_color_override("font_color",
			ec if not btn.disabled else Color(ec, 0.4))
		btn.pressed.connect(_pick.bind(k))
		col.add_child(btn)
		_buttons.append(btn)
		var subrule := String(e.get("sub", ""))
		if subrule != "":
			var rl := Label.new()
			rl.text = subrule
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rl.add_theme_font_size_override("font_size", 14)
			rl.modulate = Color(ec, 0.55 if btn.disabled else 0.85)
			col.add_child(rl)

	_leave_btn = Button.new()
	_leave_btn.custom_minimum_size = Vector2(620, 46)
	_leave_btn.text = leave_label
	_leave_btn.add_theme_font_size_override("font_size", 22)
	_leave_btn.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	_leave_btn.pressed.connect(_pick.bind(-1))
	col.add_child(_leave_btn)

	UiFocus.grab_first(panel)
	if focus_leave and _leave_btn != null:
		_leave_btn.grab_focus()

## Await the choice: an entries index, or -1 (LEAVE / window expired while the
## cursor sat on LEAVE — the focused row commits on timeout).
func run() -> int:
	var t := 0.0
	while _chosen == -999 and t < _window:
		await get_tree().process_frame
		t += get_process_delta_time()
	if _chosen == -999:
		var vp := get_viewport()
		var owner := vp.gui_get_focus_owner() if vp != null else null
		_chosen = _buttons.find(owner) if _buttons.has(owner) else -1
	return _chosen

func _pick(index: int) -> void:
	if _chosen == -999:
		_chosen = index
		Sfx.play("ui_move")

func _panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.04, 0.06, 0.94)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.78, 0.66, 0.36)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	return sb
