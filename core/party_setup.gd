extends CanvasLayer
## Autoload PartySetup: the flat ESC settings overlay (research digest 04 —
## settings never go diegetic). Tabs: SEATS / CONTROLS / AUDIO / VIDEO /
## ACCESS. Seat + keybind choices persist via PlayerInput (party_setup.json);
## everything else persists in user://prefs.json and applies on boot.
##
## Games read toggles via PartySetup.pref("screen_shake", true) etc.

const DEVICE_CYCLE := [-4, -3, -1, -2, 0, 1, 2, 3]
const DEVICE_NAMES := {-4: "KB (WASD) + MOUSE", -3: "MOUSE/SHARED", -1: "KEYBOARD (WASD)", -2: "KEYBOARD (ARROWS)", 0: "GAMEPAD 1", 1: "GAMEPAD 2", 2: "GAMEPAD 3", 3: "GAMEPAD 4"}

const PREFS_PATH := "user://prefs.json"
const BIND_DEVICES := [-1, -2, -4]
const BIND_ACTIONS := ["up", "left", "down", "right", "a", "b"]

var panel: PanelContainer
var tabs: TabContainer
var open := false

var _prefs := {}
var _seats_box: VBoxContainer
var _controls_box: VBoxContainer
var _bind_device := -1
var _listen_action := ""
var _listen_btn: Button = null

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerInput.load_setup()
	_load_prefs()
	_apply_audio_prefs()
	_apply_video_prefs()
	panel = PanelContainer.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(880, 560)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "SETTINGS   (ESC to close — game is paused)"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_seats_box = VBoxContainer.new()
	_seats_box.name = "SEATS"
	_seats_box.add_theme_constant_override("separation", 8)
	tabs.add_child(_seats_box)
	_controls_box = VBoxContainer.new()
	_controls_box.name = "CONTROLS"
	_controls_box.add_theme_constant_override("separation", 6)
	tabs.add_child(_controls_box)
	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_video_tab())
	tabs.add_child(_build_access_tab())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opensettings="):
			var t := int(arg.trim_prefix("--opensettings="))
			get_tree().create_timer(0.8).timeout.connect(func():
				if not open:
					toggle()
				tabs.current_tab = clampi(t, 0, tabs.get_tab_count() - 1))

func _input(event: InputEvent) -> void:
	if _listen_action != "" and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_stop_listen()
			return
		PlayerInput.set_key_binding(_bind_device, _listen_action, event.physical_keycode)
		_stop_listen()
		_rebuild_controls()
		Sfx.play("confirm")
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	open = not open
	panel.visible = open
	get_tree().paused = open
	if open:
		_rebuild_seats()
		_rebuild_controls()
	else:
		_stop_listen()
		PlayerInput.save_setup()
		_save_prefs()

## ----- prefs (audio/video/access) -----

func pref(key: String, def):
	return _prefs.get(key, def)

func set_pref(key: String, value) -> void:
	_prefs[key] = value
	_save_prefs()

func _load_prefs() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var data = JSON.parse_string(FileAccess.open(PREFS_PATH, FileAccess.READ).get_as_text())
	if data is Dictionary:
		_prefs = data

func _save_prefs() -> void:
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_prefs))

func _apply_audio_prefs() -> void:
	_apply_volume("Master", float(pref("vol_master", 1.0)))
	_apply_volume("Music", float(pref("vol_music", 0.8)))
	_apply_volume("SFX", float(pref("vol_sfx", 1.0)))

func _apply_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))

func _apply_video_prefs() -> void:
	match str(pref("video_mode", "windowed")):
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"exclusive":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(pref("vsync", true)) else DisplayServer.VSYNC_DISABLED)

## ----- SEATS tab (who's on the couch) -----

func _rebuild_seats() -> void:
	for c in _seats_box.get_children():
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
		_seats_box.add_child(row)
	var hint := Label.new()
	hint.text = "Changes apply to the next game launched (estate phases apply live).\nGamepads must press a button once to be detected by the OS."
	hint.add_theme_font_size_override("font_size", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.75
	_seats_box.add_child(hint)

## ----- CONTROLS tab (remap; device-keyed) -----

func _rebuild_controls() -> void:
	for c in _controls_box.get_children():
		c.queue_free()
	var pick_row := HBoxContainer.new()
	pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pick_row.add_theme_constant_override("separation", 10)
	var pick_l := Label.new()
	pick_l.text = "REBIND DEVICE:"
	pick_row.add_child(pick_l)
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(260, 44)
	for d in BIND_DEVICES:
		pick.add_item(DEVICE_NAMES[d])
	pick.selected = BIND_DEVICES.find(_bind_device)
	pick.item_selected.connect(func(idx: int):
		_bind_device = BIND_DEVICES[idx]
		_stop_listen()
		_rebuild_controls())
	pick_row.add_child(pick)
	_controls_box.add_child(pick_row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for act in BIND_ACTIONS:
		var mouse_locked: bool = _bind_device == -4 and (act == "a" or act == "b")
		var al := Label.new()
		al.text = {"up": "MOVE UP", "down": "MOVE DOWN", "left": "MOVE LEFT",
			"right": "MOVE RIGHT", "a": "ACTION A", "b": "ACTION B"}[act]
		grid.add_child(al)
		if mouse_locked:
			var fixed := Label.new()
			fixed.text = ("LEFT CLICK" if act == "a" else "RIGHT CLICK") + "  (fixed — that's the device)"
			fixed.modulate.a = 0.7
			grid.add_child(fixed)
		else:
			var kb := Button.new()
			kb.custom_minimum_size = Vector2(190, 40)
			kb.text = OS.get_keycode_string(PlayerInput.binding_of(_bind_device, act))
			kb.pressed.connect(func():
				_stop_listen()
				_listen_action = act
				_listen_btn = kb
				kb.text = "PRESS A KEY…")
			grid.add_child(kb)
	var center := CenterContainer.new()
	center.add_child(grid)
	_controls_box.add_child(center)
	var reset := Button.new()
	reset.text = "RESET THIS DEVICE TO DEFAULTS"
	reset.pressed.connect(func():
		PlayerInput.reset_key_bindings(_bind_device)
		_rebuild_controls()
		Sfx.play("card"))
	var reset_c := CenterContainer.new()
	reset_c.add_child(reset)
	_controls_box.add_child(reset_c)
	var pads_l := Label.new()
	pads_l.text = "— GAMEPADS —"
	pads_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pads_l.modulate.a = 0.7
	_controls_box.add_child(pads_l)
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		var none := Label.new()
		none.text = "no gamepads detected"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.modulate.a = 0.55
		_controls_box.add_child(none)
	for pad in pads:
		var sw := CheckButton.new()
		sw.text = "GAMEPAD %d: SWAP A/B" % (pad + 1)
		sw.button_pressed = PlayerInput.pad_swapped(pad)
		sw.toggled.connect(func(v: bool):
			PlayerInput.set_pad_swap(pad, v)
			Sfx.play("card"))
		var sc := CenterContainer.new()
		sc.add_child(sw)
		_controls_box.add_child(sc)
	var note := Label.new()
	note.text = "Binding a key already in use swaps the two actions — nothing can go unbound.\nHow-to-Play cards always show your live bindings."
	note.add_theme_font_size_override("font_size", 14)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate.a = 0.65
	_controls_box.add_child(note)

func _stop_listen() -> void:
	if _listen_btn != null and is_instance_valid(_listen_btn) and _listen_action != "":
		_listen_btn.text = OS.get_keycode_string(PlayerInput.binding_of(_bind_device, _listen_action))
	_listen_action = ""
	_listen_btn = null

## ----- AUDIO tab -----

func _build_audio_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "AUDIO"
	v.add_theme_constant_override("separation", 14)
	v.add_child(_volume_row("MASTER", "vol_master", 1.0, "Master"))
	v.add_child(_volume_row("MUSIC", "vol_music", 0.8, "Music"))
	v.add_child(_volume_row("SFX", "vol_sfx", 1.0, "SFX"))
	var note := Label.new()
	note.text = "the soundtrack arrives when the resident violist approves it"
	note.add_theme_font_size_override("font_size", 14)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate.a = 0.55
	v.add_child(note)
	return v

func _volume_row(label: String, key: String, def: float, bus_name: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(pref(key, def))
	s.custom_minimum_size = Vector2(420, 32)
	var pct := Label.new()
	pct.text = "%d%%" % roundi(s.value * 100)
	pct.custom_minimum_size = Vector2(64, 0)
	s.value_changed.connect(func(v: float):
		_prefs[key] = v
		_apply_volume(bus_name, v)
		pct.text = "%d%%" % roundi(v * 100)
		if bus_name == "SFX":
			Sfx.play("card", -6.0))
	row.add_child(s)
	row.add_child(pct)
	return row

## ----- VIDEO tab -----

func _build_video_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "VIDEO"
	v.add_theme_constant_override("separation", 14)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = "DISPLAY MODE"
	row.add_child(l)
	var modes := ["windowed", "borderless", "exclusive"]
	var mode_names := ["WINDOWED", "BORDERLESS FULLSCREEN", "EXCLUSIVE FULLSCREEN"]
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(320, 44)
	for n in mode_names:
		ob.add_item(n)
	ob.selected = maxi(0, modes.find(str(pref("video_mode", "windowed"))))
	ob.item_selected.connect(func(idx: int):
		_prefs["video_mode"] = modes[idx]
		_apply_video_prefs()
		Sfx.play("card"))
	row.add_child(ob)
	v.add_child(row)
	var vs := CheckButton.new()
	vs.text = "VSYNC"
	vs.button_pressed = bool(pref("vsync", true))
	vs.toggled.connect(func(on: bool):
		_prefs["vsync"] = on
		_apply_video_prefs()
		Sfx.play("card"))
	var vc := CenterContainer.new()
	vc.add_child(vs)
	v.add_child(vc)
	return v

## ----- ACCESS tab -----

func _build_access_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "ACCESS"
	v.add_theme_constant_override("separation", 14)
	var shake := CheckButton.new()
	shake.text = "SCREEN SHAKE"
	shake.button_pressed = bool(pref("screen_shake", true))
	shake.toggled.connect(func(on: bool):
		_prefs["screen_shake"] = on
		Sfx.play("card"))
	var sc := CenterContainer.new()
	sc.add_child(shake)
	v.add_child(sc)
	var note := Label.new()
	note.text = "Player shapes (never color alone) are rolling out across all game HUDs.\nColorblind palettes and text scaling land with the lobby pass."
	note.add_theme_font_size_override("font_size", 15)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate.a = 0.65
	v.add_child(note)
	return v
