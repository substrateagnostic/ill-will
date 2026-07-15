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
## ACCESS: colorblind palette ids (match GameState.PALETTES) + display labels.
const PALETTE_IDS := ["classic", "deutan", "protan", "tritan"]
const PALETTE_LABELS := ["CLASSIC", "DEUTERANOPIA", "PROTANOPIA", "TRITANOPIA"]

var panel: PanelContainer
var tabs: TabContainer
var open := false

var _prefs := {}
var _seats_box: VBoxContainer
var _controls_box: VBoxContainer
var _bind_device := -1
var _listen_action := ""
var _listen_btn: Button = null
var _quit_hold: HoldConfirm = null
var _quit_button_held: bool = false

var _disconnect_panel: PanelContainer = null
var _disconnect_title: Label = null
var _disconnect_body: Label = null
var _disconnect_host_hold: HoldConfirm = null
var _disconnect_active: bool = false
var _disconnect_seat: int = -1
var _disconnect_device: int = -99
var _disconnect_prev_paused: bool = false
var _disconnect_claim_held: Dictionary = {}

# The guest-side "THE HOST HAS PAUSED" overlay. PartySetup is the shell's global
# overlay owner (settings + controller-disconnect already live here), so the
# host-pause curtain rides the same PROCESS_MODE_ALWAYS CanvasLayer. It is driven
# purely by NetSession.host_pause_changed and only ever shows on a client.
var _hostpause_root: Control = null

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var joy_cb: Callable = Callable(self, "_on_joy_connection_changed")
	if not Input.joy_connection_changed.is_connected(joy_cb):
		Input.joy_connection_changed.connect(joy_cb)
	PlayerInput.load_setup()
	_load_prefs()
	_apply_audio_prefs()
	_apply_video_prefs()
	_apply_access_prefs()
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
	tabs.add_child(_build_game_tab())
	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_video_tab())
	tabs.add_child(_build_access_tab())
	# Playtest (Andrew): no way to leave a game — escape hatch from anywhere.
	var quit_row: HBoxContainer = HBoxContainer.new()
	quit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quit_row.add_theme_constant_override("separation", 12)
	var quit_btn: Button = Button.new()
	quit_btn.text = "QUIT TO TITLE  (forfeits the current game)"
	quit_btn.custom_minimum_size = Vector2(0, 44)
	quit_btn.button_down.connect(func(): _quit_button_held = true)
	quit_btn.button_up.connect(func(): _quit_button_held = false)
	quit_row.add_child(quit_btn)
	_quit_hold = HoldConfirm.new()
	_quit_hold.configure(3.0)
	_quit_hold.completed.connect(quit_to_title)
	quit_row.add_child(_quit_hold)
	box.add_child(quit_row)
	_build_disconnect_overlay()
	_build_hostpause_overlay()
	# NetSession autoloads AFTER PartySetup (project.godot order), so its node is
	# not in the tree yet — wire the guest-pause signals on the next idle frame.
	call_deferred("_wire_net_pause_signals")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opensettings="):
			var t := int(arg.trim_prefix("--opensettings="))
			get_tree().create_timer(0.8).timeout.connect(func():
				if not open:
					toggle()
				tabs.current_tab = clampi(t, 0, tabs.get_tab_count() - 1))
		elif arg.begins_with("--fake-disconnect="):
			# Dev-only: a real pad-unplug can't be simulated headlessly, so this
			# seats a local human on a phantom gamepad and fires the SAME overlay
			# path after 2s so the reclaim/bot card can be captured windowed.
			var seat := clampi(int(arg.trim_prefix("--fake-disconnect=")), 0, 3)
			get_tree().create_timer(2.0).timeout.connect(func():
				GameState.player_count = maxi(GameState.player_count, seat + 1)
				PlayerInput.assign(seat, 0)
				PlayerInput.set_bot(seat, false)
				_begin_disconnect_overlay(seat, 0)
				VerifyCapture.snap("input2_disconnect"))

## Forfeit whatever is running and return to the title, leaving NOTHING behind.
## Playtest bug (Andrew, round 2): modules launch parented at the TREE ROOT, so
## change_scene_to_file frees the estate but not a live game — quitting mid-
## match left a zombie module simulating under the next launch ("echo chamber
## is now on top" of golf). free_stray_root_nodes() is the root fix; the time
## scale reset covers quitting mid-hitstop (HIT KIT runs at 0.15 for 45ms).
func quit_to_title() -> void:
	_disconnect_active = false
	_quit_button_held = false
	if _quit_hold != null:
		_quit_hold.cancel()
	if _disconnect_panel != null:
		_disconnect_panel.visible = false
	open = false
	panel.visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	PlayerInput.save_setup()
	_save_prefs()
	Music.stop()
	Sfx.play("card")
	free_stray_root_nodes()
	get_tree().change_scene_to_file("res://estate/estate.tscn")

## Free every child of /root that is neither an autoload nor the current scene
## (modules and podiums live there during play; on any path back to the title
## they are zombies). Autoload names come from ProjectSettings so the list can
## never drift. Returns how many nodes were freed (receipt for the harness).
func free_stray_root_nodes() -> int:
	var autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var pname := str(prop.name)
		if pname.begins_with("autoload/"):
			autoloads[pname.trim_prefix("autoload/")] = true
	var freed := 0
	var root := get_tree().root
	for child in root.get_children():
		if child == get_tree().current_scene:
			continue
		if autoloads.has(str(child.name)):
			continue
		print("ROOTSWEEP freeing stray: ", child.name)
		child.queue_free()
		freed += 1
	return freed

func _input(event: InputEvent) -> void:
	if _disconnect_active:
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
		return
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
	if _disconnect_active:
		return
	open = not open
	panel.visible = open
	get_tree().paused = open
	# Tell the guests the estate held its breath (host only — a guest's own ESC
	# pauses just its local tree and must never freeze the shared table).
	_net_reflect_host_pause(open)
	if open:
		_rebuild_seats()
		_rebuild_controls()
	else:
		_stop_listen()
		PlayerInput.save_setup()
		_save_prefs()

func _process(delta: float) -> void:
	if _disconnect_active:
		_poll_disconnect_overlay(delta)
	if _quit_hold != null:
		var quit_held: bool = open and not _disconnect_active and _quit_button_held
		_quit_hold.tick(quit_held, delta)

## ----- controller disconnect safety (global couch overlay) -----

func _build_disconnect_overlay() -> void:
	_disconnect_panel = PanelContainer.new()
	_disconnect_panel.visible = false
	_disconnect_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_disconnect_panel.set_anchors_preset(Control.PRESET_CENTER)
	_disconnect_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_disconnect_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_disconnect_panel.custom_minimum_size = Vector2(760, 320)
	add_child(_disconnect_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_disconnect_panel.add_child(box)
	_disconnect_title = Label.new()
	_disconnect_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disconnect_title.add_theme_font_size_override("font_size", 30)
	_disconnect_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	box.add_child(_disconnect_title)
	_disconnect_body = Label.new()
	_disconnect_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disconnect_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disconnect_body.custom_minimum_size = Vector2(680, 0)
	_disconnect_body.add_theme_font_size_override("font_size", 19)
	box.add_child(_disconnect_body)
	var host_row: HBoxContainer = HBoxContainer.new()
	host_row.alignment = BoxContainer.ALIGNMENT_CENTER
	host_row.add_theme_constant_override("separation", 12)
	var hold_label: Label = Label.new()
	hold_label.text = "HOST HOLDS B TO LET A BOT CONTINUE"
	hold_label.add_theme_font_size_override("font_size", 18)
	host_row.add_child(hold_label)
	_disconnect_host_hold = HoldConfirm.new()
	_disconnect_host_hold.configure(2.0)
	_disconnect_host_hold.completed.connect(_convert_disconnected_seat_to_bot)
	host_row.add_child(_disconnect_host_hold)
	box.add_child(host_row)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if _disconnect_active and device == _disconnect_device:
			_reclaim_disconnected_seat(device)
		return
	if _disconnect_active or not _gameplay_running():
		return
	var seat: int = _local_human_seat_for_device(device)
	if seat < 0:
		return
	_begin_disconnect_overlay(seat, device)

func _gameplay_running() -> bool:
	var current: Node = get_tree().current_scene
	if current == null:
		return false
	if current.has_method("_input2_gameplay_running"):
		return bool(current.call("_input2_gameplay_running"))
	var scene_path: String = current.scene_file_path
	return scene_path == "res://scenes/main.tscn" or scene_path.begins_with("res://minigames/")

func _local_human_seat_for_device(device: int) -> int:
	for i: int in range(GameState.player_count):
		if PlayerInput.device_of(i) != device:
			continue
		if PlayerInput.is_bot(i) or PlayerInput.is_remote(i) or NetSession.is_seat_remote(i):
			continue
		return i
	return -1

func _begin_disconnect_overlay(seat: int, device: int) -> void:
	_disconnect_active = true
	_disconnect_seat = seat
	_disconnect_device = device
	_disconnect_prev_paused = get_tree().paused
	_disconnect_claim_held.clear()
	_disconnect_host_hold.cancel()
	_disconnect_title.text = "%s'S CONTROLLER DISCONNECTED" % GameState.PLAYER_NAMES[seat]
	_disconnect_title.add_theme_color_override("font_color", GameState.PLAYER_COLORS[seat])
	_disconnect_body.text = "Reconnect gamepad %d to resume automatically. Press A on any unclaimed gamepad to reclaim this seat. The host may hold B to convert the seat to BOT and continue." % (device + 1)
	_disconnect_panel.visible = true
	get_tree().paused = true
	_net_reflect_host_pause(true)
	Sfx.play("grudge", -4.0)

func _poll_disconnect_overlay(delta: float) -> void:
	if Input.get_connected_joypads().has(_disconnect_device):
		_reclaim_disconnected_seat(_disconnect_device)
		return
	for pad: int in Input.get_connected_joypads():
		var down: bool = Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
		if not down:
			_disconnect_claim_held.erase(pad)
			continue
		if bool(_disconnect_claim_held.get(pad, false)):
			continue
		_disconnect_claim_held[pad] = true
		if _pad_available_for_reclaim(pad):
			_reclaim_disconnected_seat(pad)
			return
	var host_held: bool = _host_b_held()
	_disconnect_host_hold.tick(host_held, delta)

func _pad_available_for_reclaim(pad: int) -> bool:
	for i: int in range(GameState.player_count):
		if i == _disconnect_seat:
			continue
		if PlayerInput.device_of(i) == pad and not PlayerInput.is_bot(i) and not PlayerInput.is_remote(i):
			return false
	return true

func _host_b_held() -> bool:
	if GameState.player_count <= 0:
		return false
	if PlayerInput.is_bot(0) or PlayerInput.is_remote(0) or NetSession.is_seat_remote(0):
		return false
	return PlayerInput.is_down(0, "b")

func _reclaim_disconnected_seat(device: int) -> void:
	PlayerInput.assign(_disconnect_seat, device)
	PlayerInput.set_bot(_disconnect_seat, false)
	PlayerInput.save_setup()
	Sfx.play("confirm")
	_end_disconnect_overlay()

func _convert_disconnected_seat_to_bot() -> void:
	PlayerInput.set_bot(_disconnect_seat, true)
	PlayerInput.assign(_disconnect_seat, -99)
	PlayerInput.save_setup()
	Sfx.play("card")
	_end_disconnect_overlay()

func _end_disconnect_overlay() -> void:
	_disconnect_panel.visible = false
	_disconnect_active = false
	_disconnect_claim_held.clear()
	_disconnect_host_hold.cancel()
	get_tree().paused = _disconnect_prev_paused
	# Reflect the resolved pause state (the settings overlay may still hold it).
	_net_reflect_host_pause(get_tree().paused)

## ----- host pause across the wire (the estate holds its breath) -----

## Push the host's own pause to every guest. HOST-ONLY by design: a guest's ESC
## pauses only its local tree, so gating on is_host() guarantees a guest can
## never freeze the shared simulation for everyone else (fix-list item 4).
func _net_reflect_host_pause(paused: bool) -> void:
	if NetSession.is_host():
		NetSession.set_host_paused(paused)

## The guest-side curtain: a full-screen dim + a centered card in the house
## voice. Built once, hidden; NetSession.host_pause_changed toggles it.
func _build_hostpause_overlay() -> void:
	_hostpause_root = Control.new()
	_hostpause_root.name = "HostPauseOverlay"
	_hostpause_root.visible = false
	_hostpause_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_hostpause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Eat the clicks/keys that fall on the curtain so a guest cannot poke the
	# frozen game underneath; ESC still reaches _input (settings stay reachable).
	_hostpause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hostpause_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_hostpause_root.add_child(dim)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(720, 240)
	_hostpause_root.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	var title := Label.new()
	title.text = "THE HOST HAS PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	box.add_child(title)
	var body := Label.new()
	body.text = "the estate holds its breath"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	box.add_child(body)
	var foot := Label.new()
	foot.text = "your seat is held — the night resumes the moment the host returns"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 15)
	foot.modulate.a = 0.7
	box.add_child(foot)

func _wire_net_pause_signals() -> void:
	if not NetSession.host_pause_changed.is_connected(_on_net_host_pause):
		NetSession.host_pause_changed.connect(_on_net_host_pause)
	if not NetSession.session_closed.is_connected(_on_net_session_closed_hostpause):
		NetSession.session_closed.connect(_on_net_session_closed_hostpause)

func _on_net_host_pause(paused: bool) -> void:
	if _hostpause_root == null:
		return
	_hostpause_root.visible = paused
	Sfx.play("card", -6.0)

## The wire went dark while the curtain was up — drop it so a guest is not left
## staring at "held breath" after it has already been kicked back to the title.
func _on_net_session_closed_hostpause(_reason: String) -> void:
	if _hostpause_root != null:
		_hostpause_root.visible = false

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

## ----- GAME tab (run configuration; applies to the next night) -----

func _build_game_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "GAME"
	v.add_theme_constant_override("separation", 14)
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 16)
	var l1 := Label.new()
	l1.text = "GAMES PER NIGHT"
	row1.add_child(l1)
	var nights := OptionButton.new()
	nights.custom_minimum_size = Vector2(140, 44)
	for opt in [3, 5, 7]:
		nights.add_item(str(opt))
	nights.selected = maxi(0, [3, 5, 7].find(int(pref("night_length", 3))))
	nights.item_selected.connect(func(idx: int):
		set_pref("night_length", [3, 5, 7][idx])
		Sfx.play("card"))
	row1.add_child(nights)
	v.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 16)
	var l2 := Label.new()
	l2.text = "ROUNDS PER MINIGAME"
	row2.add_child(l2)
	var rounds := OptionButton.new()
	rounds.custom_minimum_size = Vector2(140, 44)
	for opt in [2, 3, 4, 5]:
		rounds.add_item(str(opt))
	rounds.selected = maxi(0, [2, 3, 4, 5].find(int(pref("mg_rounds", 4))))
	rounds.item_selected.connect(func(idx: int):
		set_pref("mg_rounds", [2, 3, 4, 5][idx])
		Sfx.play("card"))
	row2.add_child(rounds)
	v.add_child(row2)
	var theater := CheckButton.new()
	theater.text = "THEATER GAMES IN THE NIGHT ROTATION (Séance, Understudy)"
	theater.button_pressed = bool(pref("theater_in_pool", false))
	theater.toggled.connect(func(on: bool):
		set_pref("theater_in_pool", on)
		Sfx.play("card"))
	var tc := CenterContainer.new()
	tc.add_child(theater)
	v.add_child(tc)
	var note := Label.new()
	note.text = "The full game runs night after night until someone takes the manor.\nChanges apply from the next night."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.modulate.a = 0.65
	v.add_child(note)
	return v

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

## Applied on boot (from _ready, after _load_prefs) and live on change.
func _apply_access_prefs() -> void:
	GameState.apply_palette(str(pref("palette", "classic")))
	get_tree().root.content_scale_factor = float(pref("ui_scale", 1.0))

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
	# COLORBLIND PALETTE — persists to pref "palette", applied via GameState.
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 16)
	var pl := Label.new()
	pl.text = "COLOR PALETTE"
	prow.add_child(pl)
	var pob := OptionButton.new()
	pob.custom_minimum_size = Vector2(340, 44)
	for n in PALETTE_LABELS:
		pob.add_item(n)
	pob.selected = maxi(0, PALETTE_IDS.find(str(pref("palette", "classic"))))
	pob.item_selected.connect(func(idx: int):
		var id: String = PALETTE_IDS[idx]
		_prefs["palette"] = id
		GameState.apply_palette(id)
		Sfx.play("card"))
	prow.add_child(pob)
	v.add_child(prow)
	# UI SCALE — persists to pref "ui_scale", drives content_scale_factor.
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", 16)
	var sl := Label.new()
	sl.text = "UI SCALE"
	sl.custom_minimum_size = Vector2(120, 0)
	srow.add_child(sl)
	var s := HSlider.new()
	s.min_value = 1.0
	s.max_value = 1.3
	s.step = 0.05
	s.value = float(pref("ui_scale", 1.0))
	s.custom_minimum_size = Vector2(400, 32)
	var pct := Label.new()
	pct.text = "%d%%" % roundi(s.value * 100)
	pct.custom_minimum_size = Vector2(64, 0)
	s.value_changed.connect(func(val: float):
		_prefs["ui_scale"] = val
		get_tree().root.content_scale_factor = val
		pct.text = "%d%%" % roundi(val * 100))
	srow.add_child(s)
	srow.add_child(pct)
	v.add_child(srow)
	var note := Label.new()
	note.text = "Palettes keep all four seats distinct under color blindness; identity also\ntravels as name + badge SHAPE. Palette applies to the next game launched\n(estate panels refresh each phase). UI scale applies instantly."
	note.add_theme_font_size_override("font_size", 15)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate.a = 0.65
	v.add_child(note)
	return v
