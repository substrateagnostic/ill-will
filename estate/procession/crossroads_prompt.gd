class_name CrossroadsPrompt
extends Control
## THE CROSSROADS CHOICE — a minimal A/B/C road picker shown when a HUMAN
## mover's walk reaches a fork. One centred parchment-dark panel (the house
## chrome: dark scrim + gold rule), the mover's name in their colour, and one
## button per branch: route name, route colour chip, stones-to-the-gate, and
## the personality blurb. Gamepad-first per core/ui_focus.gd — buttons are
## wired with the gold focus ring and the cursor parks on the first road;
## UP/DOWN moves, A commits. A silent mover auto-commits the focused road when
## the window expires, so one wandering-off human never stalls the table.
##
## PRESENTATION + INPUT ONLY. The prompt draws no rng and mutates no sim
## state; it returns an index into the fork's branch options and dies.
## Bots never see it (their strategy picks in procession.gd); the capture
## harness poses it once with bot data for the verification screenshot.

const WINDOW_SECONDS := 12.0

var _chosen := -1
var _buttons: Array = []
var _timer_lbl: Label = null

## Build + show. `options` from board.branch_options(); `mover` = {name,color}.
func open(mover: Dictionary, options: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks under the modal
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _panel_box())
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var header := Label.new()
	header.text = Dialog.text("procession.crossroads.header") % String(mover.get("name", "MOURNER"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", mover.get("color", Color.WHITE))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	header.add_theme_constant_override("outline_size", 8)
	col.add_child(header)

	var glyphs := ["A", "B", "C", "D"]
	for k in options.size():
		var opt: Dictionary = options[k]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(560, 64)
		btn.text = "%s   %s" % [glyphs[k % glyphs.size()],
			Dialog.text("procession.crossroads.option") % [String(opt.label), int(opt.left)]]
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", (opt.color as Color).lerp(Color.WHITE, 0.35))
		btn.pressed.connect(_pick.bind(k))
		col.add_child(btn)
		_buttons.append(btn)
		var blurb := Label.new()
		blurb.text = String(opt.get("blurb", ""))
		blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blurb.add_theme_font_size_override("font_size", 15)
		blurb.modulate = Color(opt.color as Color, 0.85)
		col.add_child(blurb)

	var hint := Label.new()
	hint.text = Dialog.text("procession.crossroads.hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate.a = 0.7
	col.add_child(hint)
	_timer_lbl = hint
	UiFocus.grab_first(panel)

## Await the mover's road. Returns the chosen branch index; the focused button
## commits on timeout so the table never stalls.
func run() -> int:
	var t := 0.0
	while _chosen < 0 and t < WINDOW_SECONDS:
		await get_tree().process_frame
		t += get_process_delta_time()
	if _chosen < 0:
		# Timeout: commit whichever road holds the focus cursor (index 0 if lost).
		var vp := get_viewport()
		var owner := vp.gui_get_focus_owner() if vp != null else null
		_chosen = maxi(0, _buttons.find(owner))
	return _chosen

func _pick(index: int) -> void:
	if _chosen < 0:
		_chosen = index
		Sfx.play("ui_move")

func _panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.04, 0.06, 0.93)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.78, 0.66, 0.36)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	return sb
