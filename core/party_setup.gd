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

# THE EXECUTOR NARRATES WHEN YOU STOP PLAYING (W6, the Stanley Parable device).
# The estate's non-play voice — pause, a long idle at a menu desk, quit-confirm —
# drawn from the Executor's seeded pools. Local UI narration only: it never
# touches the sim stream or the net mirror and carries no receipt weight.
const Executor := preload("res://estate/procession/executor_host.gd")
const IDLE_SECS := 20.0            # true idle at a menu desk before the estate speaks
const NARR_PARCHMENT := Color(0.92, 0.87, 0.76)

var panel: PanelContainer
var tabs: TabContainer
var open := false

# A full-screen dim behind the settings panel so it reads as its own moment and
# nothing underneath (a LOBBY seat panel, a live minigame HUD) bleeds through or
# stays clickable — the doc 25 gap row 22 fix.
var _settings_scrim: ColorRect = null
# The estate's own phase panel (LOBBY/GROUNDS desk), hidden while settings is
# open and restored on close so the two never stack.
var _phase_panel_hidden: Control = null

var _prefs := {}
var _seats_box: VBoxContainer
var _controls_box: VBoxContainer
var _bind_device := -1
var _listen_action := ""
var _listen_btn: Button = null
var _quit_hold: HoldConfirm = null
var _quit_button_held: bool = false
var _quit_app_hold: HoldConfirm = null
var _quit_app_button_held: bool = false

var _disconnect_panel: PanelContainer = null
var _disconnect_title: Label = null
var _disconnect_body: Label = null
var _disconnect_host_hold: HoldConfirm = null
var _disconnect_active: bool = false
var _disconnect_seat: int = -1
var _disconnect_device: int = -99
var _disconnect_prev_paused: bool = false
var _disconnect_claim_held: Dictionary = {}

# GAMEPAD PAUSE (doc 25 §3.4): per-pad edge memory for JOY_BUTTON_START so a
# held button opens the pause overlay exactly once, mirroring the estate's own
# _poll_pad_join() edge idiom. pad id -> was-down-last-frame.
var _pause_btn_held: Dictionary = {}

# The guest-side "THE HOST HAS PAUSED" overlay. PartySetup is the shell's global
# overlay owner (settings + controller-disconnect already live here), so the
# host-pause curtain rides the same PROCESS_MODE_ALWAYS CanvasLayer. It is driven
# purely by NetSession.host_pause_changed and only ever shows on a client.
var _hostpause_root: Control = null

# W6 — the non-play voice. _pause_line rides on the settings panel; _narrate_label
# is a bottom caption for idle + quit-confirm. Seeded from a local presentation rng
# (no receipt weight). Idle bookkeeping tracks the last meaningful input so the
# estate only speaks after a true lull, and only once per lull.
var _pause_line: Label = null
var _narrate_root: Control = null
var _narrate_label: Label = null
var _narrate_tw: Tween = null
var _narr_rng := RandomNumberGenerator.new()
var _last_input_ms := 0
var _idle_narrated := false

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
	# Scrim first so it draws BEHIND the panel (CanvasLayer children draw in order).
	_settings_scrim = ColorRect.new()
	_settings_scrim.visible = false
	_settings_scrim.color = Color(0.02, 0.02, 0.04, 0.82)
	_settings_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_scrim)
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
	# W6 — the Executor's one line for the pause screen. Set fresh each open.
	_pause_line = Label.new()
	_pause_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_line.custom_minimum_size = Vector2(820, 0)
	_pause_line.add_theme_font_size_override("font_size", 16)
	_pause_line.add_theme_color_override("font_color", NARR_PARCHMENT)
	_pause_line.modulate.a = 0.82
	box.add_child(_pause_line)
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
	# W6 (FINAL DISPOSITION rename): the escape hatch, in the estate's dialect. The
	# parenthetical keeps the functional warning; only the display verb goes probate.
	quit_btn.text = "LEAVE THE ESTATE  (forfeits the night)"
	quit_btn.custom_minimum_size = Vector2(0, 44)
	quit_btn.button_down.connect(func():
		_quit_button_held = true
		_show_quit_line())
	quit_btn.button_up.connect(func(): _quit_button_held = false)
	quit_row.add_child(quit_btn)
	_quit_hold = HoldConfirm.new()
	# 5.0s, not 3.0 (doc 14 HOLDCONFIRM-1 / doc 25 §3.3.2): QUIT TO TITLE forfeits
	# three other players' game — a shared-consequence action gets the 5s ceiling.
	_quit_hold.configure(5.0)
	_quit_hold.completed.connect(quit_to_title)
	quit_row.add_child(_quit_hold)
	# The OTHER escape hatch (Alex: "no exit game button"): LEAVE THE ESTATE only
	# returns to the title scene — the app itself had no quit-to-desktop path from
	# either the pause menu or the title screen. Same hold-to-confirm ritual, same
	# Executor QUIT_CONFIRM line, but this one actually closes the window.
	var quit_app_btn: Button = Button.new()
	quit_app_btn.text = "SHUT THE ESTATE  (quits to desktop)"
	quit_app_btn.custom_minimum_size = Vector2(0, 44)
	quit_app_btn.button_down.connect(func():
		_quit_app_button_held = true
		_show_quit_line())
	quit_app_btn.button_up.connect(func(): _quit_app_button_held = false)
	quit_row.add_child(quit_app_btn)
	_quit_app_hold = HoldConfirm.new()
	_quit_app_hold.configure(5.0)   # closing the app is the biggest consequence of all
	_quit_app_hold.completed.connect(quit_app)
	quit_row.add_child(_quit_app_hold)
	box.add_child(quit_row)
	_build_disconnect_overlay()
	_build_hostpause_overlay()
	_build_narrate_overlay()
	_narr_rng.randomize()
	_last_input_ms = Time.get_ticks_msec()
	# The front-end director (title composition + attract mode) rides this
	# always-on autoload so it survives scene reloads and needs no estate.gd edit.
	var fe := FrontEndDirector.new()
	fe.name = "FrontEndDirector"
	add_child(fe)
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
		elif arg == "--w6idle":
			# W6 dev capture: seat a local human, drop the estate to a menu desk, then
			# force one idle-narration line (bypassing the 20s wait) and snap it.
			get_tree().create_timer(1.2).timeout.connect(func():
				PlayerInput.assign(0, -1)
				PlayerInput.set_bot(0, false)
				for i in range(1, 4):
					PlayerInput.set_bot(i, true)
				var est: Node = get_tree().current_scene
				if est != null and est.has_method("_enter_grounds"):
					est.call("_enter_grounds")
				get_tree().create_timer(0.8).timeout.connect(func():
					_show_idle_line(0)
					get_tree().create_timer(0.6).timeout.connect(func():
						VerifyCapture.snap("w6_idle")
						get_tree().create_timer(0.6).timeout.connect(get_tree().quit))))
		elif arg == "--w6quit":
			# W6 dev capture: open the pause overlay (shows the pause line + the renamed
			# LEAVE THE ESTATE button), fire the quit-confirm caption, and snap.
			get_tree().create_timer(1.0).timeout.connect(func():
				if not open:
					toggle()
				_show_quit_line()
				get_tree().create_timer(0.6).timeout.connect(func():
					VerifyCapture.snap("w6_quit")
					get_tree().create_timer(0.6).timeout.connect(get_tree().quit)))
		elif arg == "--w6quitapp":
			# Exit-game-button fix capture: open the pause overlay showing BOTH quit
			# paths side by side (LEAVE THE ESTATE / SHUT THE ESTATE), snap, then fake
			# a mid-hold on the new quit-to-desktop ring (set_progress — a real hold
			# can't be scripted headlessly) so the confirm-in-progress state is on
			# film too. Quits the app for real at the end, same as the sibling caps.
			get_tree().create_timer(1.0).timeout.connect(func():
				if not open:
					toggle()
				get_tree().create_timer(0.4).timeout.connect(func():
					VerifyCapture.snap("w6_quitapp_menu")
					if _quit_app_hold != null:
						_quit_app_hold.set_progress(0.55)
					get_tree().create_timer(0.4).timeout.connect(func():
						VerifyCapture.snap("w6_quitapp_hold")
						get_tree().create_timer(0.6).timeout.connect(get_tree().quit))))
		elif arg == "--w6wheelstop":
			# W6 dev capture: build the séance-wheel STOP button on a blank overlay and
			# drive three presses, snapping each escalating toast. Self-contained.
			get_tree().create_timer(1.0).timeout.connect(_w6_wheel_demo)
		elif arg == "--w6finaldisp":
			# W6 dev capture: the shared results board with NO title supplied, so it shows
			# the FINAL DISPOSITION default header and the {name} INHERITS winner default.
			get_tree().create_timer(1.0).timeout.connect(_w6_finaldisp_demo)
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
		elif arg == "--settingslobbyshot":
			# Repro (doc 25 gap row 22): open the ESC settings while the estate's
			# LOBBY phase_panel is up and snap the stacked result.
			get_tree().create_timer(1.3).timeout.connect(func():
				var est: Node = get_tree().current_scene
				if est != null and est.has_method("_enter_lobby"):
					est.call("_enter_lobby")
				get_tree().create_timer(0.4).timeout.connect(func():
					if not open:
						toggle()
					get_tree().create_timer(0.4).timeout.connect(func():
						VerifyCapture.snap("settings_over_lobby"))))
		elif arg.begins_with("--padpausetest="):
			# Dev-only: a physical pad Start press can't be sent headlessly, so this
			# seats a local human on (phantom) gamepad 0, drives the requested
			# context, then fires the SAME thing a JOY_BUTTON_START down-edge fires —
			# toggle() — and snaps the opened overlay. Proves both halves of the
			# gap fix: _pad_can_pause() recognises a seated human's pad, and toggle()
			# raises the pause overlay in that context. ctx = title|grounds|game.
			var ctx := arg.trim_prefix("--padpausetest=")
			get_tree().create_timer(1.3).timeout.connect(func():
				PlayerInput.assign(0, 0)
				PlayerInput.set_bot(0, false)
				var est: Node = get_tree().current_scene
				if ctx == "grounds" and est != null and est.has_method("_enter_grounds"):
					est.call("_enter_grounds")
				elif ctx == "game" and est != null and est.has_method("_do_launch_game"):
					for i in range(1, 4):
						PlayerInput.set_bot(i, true)
					est.call("_do_launch_game", "greed")
				get_tree().create_timer(1.8).timeout.connect(func():
					print("PADPAUSE ctx=%s pad0_can_pause=%s" % [ctx, str(_pad_can_pause(0))])
					if not open:
						toggle()
					VerifyCapture.snap("padpause_%s" % ctx)))

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
	# The scrim + phase-panel ref live on this autoload, which survives the scene
	# reload below — drop them so neither lingers over the fresh title.
	if _settings_scrim != null:
		_settings_scrim.visible = false
	_phase_panel_hidden = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	PlayerInput.save_setup()
	_save_prefs()
	Music.stop()
	Sfx.play("ui_back")
	free_stray_root_nodes()
	get_tree().change_scene_to_file("res://estate/estate.tscn")

## The full exit: closes the application, not just the current night. Reachable
## from the pause menu (this overlay) AND the title screen (estate.gd wires its
## own QUIT button through this same method — see _enter_title_swap).
func quit_app() -> void:
	_quit_app_button_held = false
	if _quit_app_hold != null:
		_quit_app_hold.cancel()
	PlayerInput.save_setup()
	_save_prefs()
	get_tree().quit()

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
		# free() NOW, not queue_free(): quit_to_title calls this immediately before
		# change_scene_to_file, and a deferred free leaves the stray alive THROUGH the
		# estate reload. For a physics-heavy module (DEAD WEIGHT keeps 12 props with
		# can_sleep=false + continuous_cd + contact_monitor) that means a whole tree of
		# never-sleeping CCD Jolt bodies keeps simulating during the long reload frame
		# (shader recompile), and the physics server tries to catch that delta up —
		# the "quit takes a full minute" playtest report. Tearing the space down
		# synchronously here (this is a UI callback, never inside a physics step, and
		# the caller is never itself a stray) hands the reload a clean, empty world.
		child.free()
		freed += 1
	return freed

func _input(event: InputEvent) -> void:
	if _is_meaningful_input(event):
		_mark_input()   # W6 idle timer: any real activity resets the lull
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
		Sfx.play("ui_confirm")
		return
	# ESC (keyboard) opens/closes the pause overlay; a gamepad B closes it while
	# open — but never OPENS it, since B is a live in-game action and raising the
	# pause screen is the Start button's job (_poll_pause_buttons). ui_cancel now
	# carries both Escape and JOY_BUTTON_B (project.godot, GAMEPAD EVERYWHERE L1).
	if event.is_action_pressed("ui_cancel"):
		if open:
			toggle()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			toggle()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	if _disconnect_active:
		return
	open = not open
	panel.visible = open
	if _settings_scrim != null:
		_settings_scrim.visible = open
	get_tree().paused = open
	_mark_input()
	# Tell the guests the estate held its breath (host only — a guest's own ESC
	# pauses just its local tree and must never freeze the shared table).
	_net_reflect_host_pause(open)
	if open:
		# W6 — one Executor line for the pause screen, fresh each open (never headless).
		if _pause_line != null and DisplayServer.get_name() != "headless":
			_pause_line.text = Executor.pick(Executor.PAUSE, _narr_rng)
		_hide_phase_panel()
		_rebuild_seats()
		_rebuild_controls()
		# M2 UI CONSISTENCY: the pause/SETTINGS overlay wore the old green pill theme
		# and clashed with the title door. Dress its panel + every tab button in the
		# house stationery (idempotent — the SEATS/CONTROLS tabs rebuild each open).
		Stationery.panel(panel)
		Stationery.apply_tree(panel)
		# GAMEPAD EVERYWHERE (L1): park the pad-focus cursor on the first control of
		# the visible tab (deferred, so it lands after the tabs rebuild) — the pause
		# overlay was mouse-only. B (ui_cancel) closes it; Start toggles it.
		call_deferred("_focus_settings_deferred")
	else:
		_restore_phase_panel()
		_stop_listen()
		PlayerInput.save_setup()
		_save_prefs()

## Hide the estate's own LOBBY/GROUNDS desk panel while settings is open so the
## two panels never stack (doc 25 gap row 22). Remembers it to restore on close.
func _hide_phase_panel() -> void:
	_phase_panel_hidden = null
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var pp = scene.get("phase_panel")
	if pp != null and pp is Control and (pp as Control).visible:
		_phase_panel_hidden = pp as Control
		(pp as Control).visible = false

func _restore_phase_panel() -> void:
	if _phase_panel_hidden != null and is_instance_valid(_phase_panel_hidden):
		_phase_panel_hidden.visible = true
	_phase_panel_hidden = null

## Deferred by toggle(): give the opened pause overlay a pad-focus cursor on the
## first control of its visible tab. No-op if it closed again before idle.
func _focus_settings_deferred() -> void:
	if open and panel != null:
		UiFocus.grab_first(panel)

func _process(delta: float) -> void:
	_poll_pause_buttons()
	if _disconnect_active:
		_poll_disconnect_overlay(delta)
	if _quit_hold != null:
		var quit_held: bool = open and not _disconnect_active and _quit_button_held
		_quit_hold.tick(quit_held, delta)
	if _quit_app_hold != null:
		var quit_app_held: bool = open and not _disconnect_active and _quit_app_button_held
		_quit_app_hold.tick(quit_app_held, delta)
	_update_idle()

## GAMEPAD PAUSE — the single cert-grade gap doc 25 names: KEY_ESCAPE was the ONLY
## thing that opened the pause overlay, so a controller-only player could never
## pause. Edge-detect JOY_BUTTON_START (Start/Options — the universal couch-pause
## button) on every connected pad and route it through toggle(), which already
## carries the correct host/guest broadcast semantics regardless of which local
## seat pressed it. Gated to a pad that drives a SEATED LOCAL HUMAN this session,
## so an all-bot attract exhibition (every seat a bot) is interrupted by a stray
## press rather than paused by it. Runs every frame (PROCESS_MODE_ALWAYS), so the
## same Start button also closes the overlay — the console pause convention.
func _poll_pause_buttons() -> void:
	if _disconnect_active or _listen_action != "":
		return
	for pad: int in Input.get_connected_joypads():
		var down: bool = Input.is_joy_button_pressed(pad, JOY_BUTTON_START)
		if not down:
			_pause_btn_held.erase(pad)
			continue
		if bool(_pause_btn_held.get(pad, false)):
			continue
		_pause_btn_held[pad] = true
		if _pad_can_pause(pad):
			toggle()
			return

## A pad may open the pause overlay only when it drives a seated LOCAL HUMAN
## (reuses the disconnect overlay's seat lookup, which already excludes bot /
## remote seats). An unseated or all-bot table is never paused from a pad.
func _pad_can_pause(pad: int) -> bool:
	return _local_human_seat_for_device(pad) >= 0

## ----- W6: the Executor narrates when you stop playing -----

## True only for input that counts as a player doing something — so stick drift and
## empty motion events never keep the idle timer from firing.
func _is_meaningful_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventMouseMotion:
		return true
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.3
	return false

func _mark_input() -> void:
	_last_input_ms = Time.get_ticks_msec()
	_idle_narrated = false

## Fire the patience line after a true lull at a menu desk. Gated hard so it never
## interrupts a live game, never fires headless, and never fires with no local human
## on the couch (an all-bot attract stays silent).
func _update_idle() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if open or _disconnect_active or _idle_narrated:
		return
	if Input.is_anything_pressed():
		_mark_input()
		return
	if not _idle_surface_ok():
		return
	var seat := _first_local_human_seat()
	if seat < 0:
		return
	if Time.get_ticks_msec() - _last_input_ms >= int(IDLE_SECS * 1000.0):
		_idle_narrated = true
		_show_idle_line(seat)

## A menu desk awaiting the couch — the LOBBY/GROUNDS/AUCTION/CHOOSING/TILES phases,
## where the estate's own panel is up and no game is running. Excludes the live game,
## the reveal ceremonies, and the title.
func _idle_surface_ok() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != "res://estate/estate.tscn":
		return false
	if _gameplay_running():
		return false
	var pp = scene.get("phase_panel")
	if pp == null or not (pp is Control) or not (pp as Control).visible:
		return false
	if scene.has_method("get_phase_name"):
		var ph := str(scene.call("get_phase_name"))
		if not (ph in ["LOBBY", "GROUNDS", "TILES", "AUCTION", "CHOOSING"]):
			return false
	return true

func _first_local_human_seat() -> int:
	for i: int in range(GameState.player_count):
		if PlayerInput.is_bot(i) or PlayerInput.is_remote(i) or NetSession.is_seat_remote(i):
			continue
		return i
	return -1

func _show_idle_line(seat: int) -> void:
	if seat < 0 or seat >= GameState.PLAYER_NAMES.size():
		return
	var nm := str(GameState.PLAYER_NAMES[seat])
	_narrate(Executor.pick(Executor.IDLE, _narr_rng, [nm]), 6.5)

func _show_quit_line() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_narrate(Executor.pick(Executor.QUIT_CONFIRM, _narr_rng), 5.5)

## The bottom-centre caption the idle + quit-confirm lines ride on. Built once,
## hidden; PROCESS_MODE_ALWAYS so a quit-confirm line reads while the tree is paused.
func _build_narrate_overlay() -> void:
	_narrate_root = Control.new()
	_narrate_root.name = "W6Narration"
	_narrate_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_narrate_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narrate_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_narrate_root)
	_narrate_label = Label.new()
	_narrate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narrate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrate_label.anchor_left = 0.12
	_narrate_label.anchor_right = 0.88
	_narrate_label.anchor_top = 0.82
	_narrate_label.anchor_bottom = 0.94
	_narrate_label.add_theme_font_size_override("font_size", 22)
	_narrate_label.add_theme_color_override("font_color", NARR_PARCHMENT)
	_narrate_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.07))
	_narrate_label.add_theme_constant_override("outline_size", 7)
	_narrate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrate_label.visible = false
	_narrate_root.add_child(_narrate_label)

func _narrate(text: String, hold: float) -> void:
	if _narrate_label == null:
		return
	_narrate_label.text = text
	_narrate_label.visible = true
	_narrate_label.modulate.a = 0.0
	if _narrate_tw != null and _narrate_tw.is_valid():
		_narrate_tw.kill()
	_narrate_tw = create_tween()
	_narrate_tw.tween_property(_narrate_label, "modulate:a", 1.0, 0.35)
	_narrate_tw.tween_interval(hold)
	_narrate_tw.tween_property(_narrate_label, "modulate:a", 0.0, 0.6)
	_narrate_tw.tween_callback(func() -> void:
		if _narrate_label != null:
			_narrate_label.visible = false)

## W6 dev capture: a self-contained séance-wheel STOP demo (windowed only).
func _w6_wheel_demo() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(dim)
	var wheel: Node = load("res://estate/procession/seance_wheel.gd").new()
	wheel.setup(host, ["MERCIFUL DRAFT", "EQUAL SHARES", "ROAD LEVY", "FAVORED MEDIUM"], false)
	wheel.debug_show()
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		wheel.debug_press_stop()
		await get_tree().create_timer(0.55).timeout
		VerifyCapture.snap("w6_wheelstop_%d" % (i + 1))
	await get_tree().create_timer(0.6).timeout
	get_tree().quit()

## W6 dev capture: the shared results board driven with default labels only.
func _w6_finaldisp_demo() -> void:
	var board: Node = load("res://core/ui_kit/results_board.gd").new()
	get_tree().root.add_child(board)
	var rows := [
		{"player": 1, "score": 58.0, "name": "BLUE", "callout": "sole heir"},
		{"player": 0, "score": 41.0, "name": "RED"},
		{"player": 2, "score": 33.0, "name": "GOLD"},
		{"player": 3, "score": 12.0, "name": "MINT"},
	]
	board.present(rows, {"score_type": 0})   # no title / win_title -> the new defaults
	await get_tree().create_timer(1.0).timeout
	VerifyCapture.snap("w6_finaldisp")       # header: FINAL DISPOSITION
	await get_tree().create_timer(4.0).timeout
	VerifyCapture.snap("w6_finaldisp_winner")  # winner: BLUE INHERITS
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()

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
	Sfx.play("ui_confirm")
	_end_disconnect_overlay()

func _convert_disconnected_seat_to_bot() -> void:
	PlayerInput.set_bot(_disconnect_seat, true)
	PlayerInput.assign(_disconnect_seat, -99)
	PlayerInput.save_setup()
	Sfx.play("ui_move")
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
	Sfx.play("ui_move", -6.0)

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
	_apply_volume("Ambience", float(pref("vol_ambience", 0.8)))

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
			Sfx.play("ui_move"))
		row.add_child(bot_btn)
		var dev_btn := Button.new()
		dev_btn.custom_minimum_size = Vector2(240, 48)
		dev_btn.text = DEVICE_NAMES.get(PlayerInput.device_of(i), "UNASSIGNED")
		dev_btn.pressed.connect(func():
			var cur := DEVICE_CYCLE.find(PlayerInput.device_of(i))
			var next: int = DEVICE_CYCLE[(cur + 1) % DEVICE_CYCLE.size()]
			PlayerInput.assign(i, next)
			dev_btn.text = DEVICE_NAMES.get(next, "UNASSIGNED")
			Sfx.play("ui_move"))
		row.add_child(dev_btn)
		_seats_box.add_child(row)
	var hint := Label.new()
	hint.text = Dialog.text("settings.hint")
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
		Sfx.play("ui_move"))
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
			Sfx.play("ui_move"))
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
		Sfx.play("ui_move"))
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
		Sfx.play("ui_move"))
	row2.add_child(rounds)
	v.add_child(row2)
	var theater := CheckButton.new()
	theater.text = "THEATER GAMES IN THE NIGHT ROTATION (Séance, Understudy)"
	theater.button_pressed = bool(pref("theater_in_pool", false))
	theater.toggled.connect(func(on: bool):
		set_pref("theater_in_pool", on)
		Sfx.play("ui_move"))
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
	# The estate's fourth bus (core/ambience.gd) routed straight to Master with no
	# fader — give it one now, before any game lane ships an unadjustable bed.
	v.add_child(_volume_row("AMBIENCE", "vol_ambience", 0.8, "Ambience"))
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
			Sfx.play("ui_move", -6.0))
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
		Sfx.play("ui_move"))
	row.add_child(ob)
	v.add_child(row)
	var vs := CheckButton.new()
	vs.text = "VSYNC"
	vs.button_pressed = bool(pref("vsync", true))
	vs.toggled.connect(func(on: bool):
		_prefs["vsync"] = on
		_apply_video_prefs()
		Sfx.play("ui_move"))
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
	# Effect-named, not diagnosis-named (doc 25 §3.3.3 / XAG118). Toggle ON = the
	# effects play; the pref KEY stays "screen_shake" — 13 game scripts read it by
	# that string (doc 25 §4), so only the on-screen label changes here.
	shake.text = "SCREEN EFFECTS  (shake · hit-stop · flash)"
	shake.button_pressed = bool(pref("screen_shake", true))
	shake.toggled.connect(func(on: bool):
		_prefs["screen_shake"] = on
		Sfx.play("ui_move"))
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
		Sfx.play("ui_move"))
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
