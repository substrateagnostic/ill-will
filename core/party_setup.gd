extends CanvasLayer
## Autoload PartySetup: ESC-toggled pause overlay for assigning each player
## a control surface (mouse / keyboard half / gamepad) or marking them as a
## BOT. Choices persist to user://party_setup.json and flow into minigame
## rosters via PlayerInput.

const DEVICE_CYCLE := [-3, -1, -2, 0, 1, 2, 3]
const DEVICE_NAMES := {-3: "MOUSE/SHARED", -1: "KEYBOARD (WASD)", -2: "KEYBOARD (ARROWS)", 0: "GAMEPAD 1", 1: "GAMEPAD 2", 2: "GAMEPAD 3", 3: "GAMEPAD 4"}

var panel: PanelContainer
var rows_box: VBoxContainer
var open := false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerInput.load_setup()
	panel = PanelContainer.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 380)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PLAYERS & CONTROLS   (ESC to close — game is paused)"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 8)
	box.add_child(rows_box)
	var hint := Label.new()
	hint.text = "Changes apply to the next game launched (estate phases apply live).\nGamepads must press a button once to be detected by the OS."
	hint.add_theme_font_size_override("font_size", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.75
	box.add_child(hint)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	open = not open
	panel.visible = open
	get_tree().paused = open
	if open:
		_rebuild()
	else:
		PlayerInput.save_setup()

func _rebuild() -> void:
	for c in rows_box.get_children():
		c.queue_free()
	for i in GameState.player_count:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		var name_l := Label.new()
		name_l.text = GameState.PLAYER_NAMES[i]
		name_l.custom_minimum_size = Vector2(90, 0)
		name_l.add_theme_font_size_override("font_size", 24)
		name_l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(name_l)
		var bot_btn := Button.new()
		bot_btn.custom_minimum_size = Vector2(130, 48)
		bot_btn.text = "BOT" if PlayerInput.is_bot(i) else "HUMAN"
		bot_btn.pressed.connect(func():
			PlayerInput.set_bot(i, not PlayerInput.is_bot(i))
			bot_btn.text = "BOT" if PlayerInput.is_bot(i) else "HUMAN"
			Sfx.play("card"))
		row.add_child(bot_btn)
		var dev_btn := Button.new()
		dev_btn.custom_minimum_size = Vector2(240, 48)
		dev_btn.text = DEVICE_NAMES.get(PlayerInput.device_of(i), "UNASSIGNED")
		dev_btn.pressed.connect(func():
			var cur := DEVICE_CYCLE.find(PlayerInput.device_of(i))
			var next: int = DEVICE_CYCLE[(cur + 1) % DEVICE_CYCLE.size()]
			PlayerInput.assign(i, next)
			dev_btn.text = DEVICE_NAMES.get(next, "UNASSIGNED")
			Sfx.play("card"))
		row.add_child(dev_btn)
		rows_box.add_child(row)
