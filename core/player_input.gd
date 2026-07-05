extends Node
## Autoload: PlayerInput. Per-player device abstraction for simultaneous
## couch play. Minigames NEVER read Input directly for player actions -
## they ask this by player index, so device assignment stays central.
##
## Device ids:
##   0..7  = gamepads (Godot joypad ids)
##   -1    = keyboard LEFT half  (WASD move, Space=a, E=b)
##   -2    = keyboard RIGHT half (arrows move, Enter=a, RShift=b)
##   -3    = mouse/shared (turn-based games like Par for the Curse; no
##           get_move - pointer input handled by the game itself)
##   -99   = unassigned
##
## API (all by player index):
##   get_move(p) -> Vector2      analog move, y = forward(-1)/back(+1)
##   is_down(p, "a"|"b") -> bool
##   just_pressed(p, "a"|"b") -> bool   (edge, valid within the frame)
##   assign(p, device) / device_of(p)
##   auto_assign(n) -> assigns gamepads first, then keyboard halves,
##                     remainder get -3 (shared/mouse)

const KEY_LEFT_MAP := {"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "a": KEY_SPACE, "b": KEY_E}
const KEY_RIGHT_MAP := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "a": KEY_ENTER, "b": KEY_SHIFT}

const SETUP_PATH := "user://party_setup.json"

var _devices := {}
var _down := {}
var _prev_down := {}
var _bots := {}

func assign(p: int, device: int) -> void:
	_devices[p] = device

func set_bot(p: int, v: bool) -> void:
	_bots[p] = v

func is_bot(p: int) -> bool:
	return _bots.get(p, false)

## True if a saved PartySetup file exists (seat choices persisted via the ESC
## overlay). Used to decide standalone bot defaults.
func has_setup() -> bool:
	return FileAccess.file_exists(SETUP_PATH)

## Standalone default for whether player p is bot-driven when a minigame
## self-starts with no shell roster. With NO saved PartySetup, everyone is a
## bot so the scene self-plays as a demo; once seats have been configured in
## the ESC overlay (party_setup.json exists), honor the HUMAN/BOT choice.
## The shell path never calls this - it sets roster[i].bot from estate._is_bot.
func standalone_bot_default(p: int) -> bool:
	return is_bot(p) or not has_setup()

func save_setup() -> void:
	var f := FileAccess.open(SETUP_PATH, FileAccess.WRITE)
	if f:
		var dev := {}
		var bot := {}
		for k in _devices:
			dev[str(k)] = _devices[k]
		for k in _bots:
			bot[str(k)] = _bots[k]
		f.store_string(JSON.stringify({"devices": dev, "bots": bot}))

func load_setup() -> bool:
	if not FileAccess.file_exists(SETUP_PATH):
		return false
	var data = JSON.parse_string(FileAccess.open(SETUP_PATH, FileAccess.READ).get_as_text())
	if not data is Dictionary:
		return false
	for k in data.get("devices", {}):
		_devices[int(k)] = int(data.devices[k])
	for k in data.get("bots", {}):
		_bots[int(k)] = bool(data.bots[k])
	return true

func device_of(p: int) -> int:
	return _devices.get(p, -99)

func auto_assign(n: int) -> void:
	var pads := Input.get_connected_joypads()
	var kb_halves := [-1, -2]
	for p in n:
		if _devices.get(p, -99) != -99:
			continue
		if p < pads.size():
			assign(p, pads[p])
		elif kb_halves.size() > 0:
			assign(p, kb_halves.pop_front())
		else:
			assign(p, -3)

func get_move(p: int) -> Vector2:
	var d := device_of(p)
	if d >= 0:
		var v := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		return v if v.length() > 0.18 else Vector2.ZERO
	var m := _keymap(d)
	if m.is_empty():
		return Vector2.ZERO
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(m.right): v.x += 1
	if Input.is_physical_key_pressed(m.left): v.x -= 1
	if Input.is_physical_key_pressed(m.down): v.y += 1
	if Input.is_physical_key_pressed(m.up): v.y -= 1
	return v.normalized() if v.length() > 1.0 else v

func is_down(p: int, action: String) -> bool:
	var d := device_of(p)
	if d >= 0:
		return Input.is_joy_button_pressed(d, JOY_BUTTON_A if action == "a" else JOY_BUTTON_B)
	var m := _keymap(d)
	return not m.is_empty() and Input.is_physical_key_pressed(m[action])

func just_pressed(p: int, action: String) -> bool:
	var key := "%d_%s" % [p, action]
	return _down.get(key, false) and not _prev_down.get(key, false)

func _physics_process(_delta: float) -> void:
	_prev_down = _down.duplicate()
	for p in _devices:
		for action in ["a", "b"]:
			_down["%d_%s" % [p, action]] = is_down(p, action)

func _keymap(d: int) -> Dictionary:
	if d == -1:
		return KEY_LEFT_MAP
	if d == -2:
		return KEY_RIGHT_MAP
	return {}
