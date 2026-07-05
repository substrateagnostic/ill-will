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
##   -4    = KB+MOUSE (WASD move, LMB=a, RMB=b; aim via get_aim_dir) —
##           the PC-native pick for aiming games
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

# Verification-only aim injection (populated by minigame --aimprobe modes). Empty
# in all normal play, so get_aim_dir/get_aim_screen behave byte-identically for
# real KBM cursors, gamepads, keyboard halves and bots. Keyed by player index.
var _dbg_aim := {}          # p -> Vector3  (world-space horizontal dir)
var _dbg_aim_screen := {}   # p -> Vector2  (x = screen right, y = screen UP)

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
	if d == -4:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if action == "a" else MOUSE_BUTTON_RIGHT)
	var m := _keymap(d)
	return not m.is_empty() and Input.is_physical_key_pressed(m[action])

## For aiming games: world-space direction from `from_pos` toward the mouse
## cursor projected on the horizontal plane at from_pos.y. Returns ZERO for
## non-KBM devices (caller falls back to facing/move direction).
func get_aim_dir(p: int, from_pos: Vector3, cam: Camera3D) -> Vector3:
	if device_of(p) != -4:
		return Vector3.ZERO
	if _dbg_aim.has(p):
		return _dbg_aim[p]
	if cam == null:
		return Vector3.ZERO
	var mp := cam.get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, from_pos.y).intersects_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
	if hit == null:
		return Vector3.ZERO
	var dir: Vector3 = hit - from_pos
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.05 else Vector3.ZERO

## Screen-space aim for games whose action plane is not the world horizontal
## (Orbital's spheres): a unit vector (x = screen right, y = screen UP) pointing
## from `world_anchor`'s projected screen position toward the mouse cursor. The
## caller maps this into its own screen-relative control frame. Returns ZERO for
## non-KBM devices, a null/absent camera, an anchor behind the camera, or a
## cursor essentially on top of the anchor.
func get_aim_screen(p: int, world_anchor: Vector3, cam: Camera3D) -> Vector2:
	if device_of(p) != -4:
		return Vector2.ZERO
	if _dbg_aim_screen.has(p):
		return _dbg_aim_screen[p]
	if cam == null or cam.is_position_behind(world_anchor):
		return Vector2.ZERO
	var anchor2d := cam.unproject_position(world_anchor)
	var d := cam.get_viewport().get_mouse_position() - anchor2d
	if d.length() < 4.0:
		return Vector2.ZERO
	return Vector2(d.x, -d.y).normalized()   # screen y is down; flip to y-up

## Verification hook (--aimprobe): pin a synthetic world-space aim for player p.
## Pass Vector3.ZERO to clear. Never called during normal play.
func set_debug_aim(p: int, world_dir: Vector3) -> void:
	if world_dir == Vector3.ZERO:
		_dbg_aim.erase(p)
	else:
		_dbg_aim[p] = world_dir.normalized()

## Verification hook (--aimprobe): pin a synthetic screen-space aim (x = right,
## y = up) for player p. Pass Vector2.ZERO to clear. Never called in normal play.
func set_debug_aim_screen(p: int, screen_dir: Vector2) -> void:
	if screen_dir == Vector2.ZERO:
		_dbg_aim_screen.erase(p)
	else:
		_dbg_aim_screen[p] = screen_dir.normalized()

func just_pressed(p: int, action: String) -> bool:
	var key := "%d_%s" % [p, action]
	return _down.get(key, false) and not _prev_down.get(key, false)

func _physics_process(_delta: float) -> void:
	_prev_down = _down.duplicate()
	for p in _devices:
		for action in ["a", "b"]:
			_down["%d_%s" % [p, action]] = is_down(p, action)

func _keymap(d: int) -> Dictionary:
	if d == -1 or d == -4:
		return KEY_LEFT_MAP
	if d == -2:
		return KEY_RIGHT_MAP
	return {}
