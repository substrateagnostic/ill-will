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

# Custom key remaps, keyed by DEVICE id (-1/-2/-4), not player — a keyboard
# half means the same keys no matter who sits there. Absent device = defaults.
var _custom_maps := {}
# Per-gamepad A/B swap (pad id -> bool).
var _pad_swap := {}

# Verification-only aim injection (populated by minigame --aimprobe modes). Empty
# in all normal play, so get_aim_dir/get_aim_screen behave byte-identically for
# real KBM cursors, gamepads, keyboard halves and bots. Keyed by player index.
var _dbg_aim := {}          # p -> Vector3  (world-space horizontal dir)
var _dbg_aim_screen := {}   # p -> Vector2  (x = screen right, y = screen UP)

# ONLINE PHASE 1 — the _remote seam (docs/design/10-online-first-architecture.md
# §4.2). NetSession injects remote peers' 30 Hz input packets here; every query
# below consults _remote FIRST, so a remote human is architecturally identical
# to a local device. Empty in all couch play — zero behavior change offline.
# Packet shape per seat: {move:Vector2, a:bool, b:bool, presses_a:int,
#   presses_b:int, aim:Vector3, aim_screen:Vector2, stick:Vector2, seq:int}
var _remote := {}         # p -> latest injected packet state
var _remote_edge := {}    # p -> press-counter bookkeeping (dropped-tap rescue)

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
		var maps := {}
		var swaps := {}
		for k in _devices:
			dev[str(k)] = _devices[k]
		for k in _bots:
			bot[str(k)] = _bots[k]
		for k in _custom_maps:
			maps[str(k)] = _custom_maps[k]
		for k in _pad_swap:
			swaps[str(k)] = _pad_swap[k]
		f.store_string(JSON.stringify({"devices": dev, "bots": bot,
			"keymaps": maps, "pad_swap": swaps}))

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
	for k in data.get("keymaps", {}):
		var m := {}
		for act in data.keymaps[k]:
			m[str(act)] = int(data.keymaps[k][act])
		_custom_maps[int(k)] = m
	for k in data.get("pad_swap", {}):
		_pad_swap[int(k)] = bool(data.pad_swap[k])
	return true

## ----- custom keybinds (device-keyed; see docs/design/05-director-notes) -----

## Rebind one action on a keyboard device. If the key is already bound to
## another action on that device, the two actions swap keys (classic rule,
## no dead actions possible).
func set_key_binding(device: int, action: String, keycode: int) -> void:
	if not _custom_maps.has(device):
		var def := KEY_LEFT_MAP if device != -2 else KEY_RIGHT_MAP
		_custom_maps[device] = def.duplicate()
	var m: Dictionary = _custom_maps[device]
	for other in m:
		if other != action and int(m[other]) == keycode:
			m[other] = m[action]
	m[action] = keycode

func reset_key_bindings(device: int) -> void:
	_custom_maps.erase(device)

func has_custom_bindings(device: int) -> bool:
	return _custom_maps.has(device)

## Current keycode bound to an action on a keyboard device (-1 if n/a).
func binding_of(device: int, action: String) -> int:
	var m := _keymap(device)
	return int(m[action]) if m.has(action) else -1

func set_pad_swap(pad: int, v: bool) -> void:
	_pad_swap[pad] = v

func pad_swapped(pad: int) -> bool:
	return _pad_swap.get(pad, false)

## Human-readable binding for player p's action, from the LIVE maps — the
## How-to-Play cards call this so onboarding always reflects real settings.
## Actions: "a", "b", "move".
func describe_binding(p: int, action: String) -> String:
	if _remote.has(p):
		return "REMOTE"
	var d := device_of(p)
	if d == -99:
		return "—"
	if d >= 0:
		if action == "move":
			return "LEFT STICK"
		var swapped := pad_swapped(d)
		if action == "a":
			return "(B)" if swapped else "(A)"
		return "(A)" if swapped else "(B)"
	if d == -3:
		return "MOUSE"
	if d == -4 and action == "a":
		return "LEFT CLICK"
	if d == -4 and action == "b":
		return "RIGHT CLICK"
	var m := _keymap(d)
	if action == "move":
		return "%s/%s/%s/%s" % [OS.get_keycode_string(m.up), OS.get_keycode_string(m.left), OS.get_keycode_string(m.down), OS.get_keycode_string(m.right)]
	return OS.get_keycode_string(m[action]) if m.has(action) else "—"

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

## ----- the _remote injection API (host side; called by NetSession only) -----

## Latest-state injection for a remote seat. Also settles the press-counter
## ledger: presses that arrived BETWEEN packets (or in dropped datagrams) are
## owed a synthesized one-tick hold so the edge detector fires exactly once.
func set_remote_state(p: int, state: Dictionary) -> void:
	var first := not _remote.has(p)
	_remote[p] = state
	if first:
		# Opening balance: never fire phantom taps from a counter that started
		# mid-life; a currently-held button credits itself via its rising edge.
		_remote_edge[p] = {
			"a_credited": maxi(0, int(state.get("presses_a", 0)) - (1 if bool(state.get("a", false)) else 0)),
			"b_credited": maxi(0, int(state.get("presses_b", 0)) - (1 if bool(state.get("b", false)) else 0)),
			"a_eff": false, "b_eff": false, "a_prev": false, "b_prev": false,
		}
		return
	# Cap the synthesized-press backlog so a network stall can't burst-fire.
	var e: Dictionary = _remote_edge[p]
	for act in ["a", "b"]:
		var total := int(state.get("presses_" + act, 0))
		if total - int(e[act + "_credited"]) > 3:
			e[act + "_credited"] = total - 3

func clear_remote(p: int) -> void:
	_remote.erase(p)
	_remote_edge.erase(p)

func is_remote(p: int) -> bool:
	return _remote.has(p)

## Per physics tick: fold raw down-states + press counters into effective
## down-states. A natural rising edge credits one press; each still-owed press
## synthesizes a one-tick hold (from a released state, so the edge detector in
## _physics_process sees a clean rise). ~15 lines, per the spec's estimate.
func _tick_remote_edges() -> void:
	for p in _remote:
		var st: Dictionary = _remote[p]
		var e: Dictionary = _remote_edge[p]
		for act in ["a", "b"]:
			var raw := bool(st.get(act, false))
			var eff := raw
			if raw and not bool(e[act + "_prev"]):
				e[act + "_credited"] = int(e[act + "_credited"]) + 1
			elif not raw:
				var pending := int(st.get("presses_" + act, 0)) - int(e[act + "_credited"])
				if pending > 0 and not bool(e[act + "_eff"]):
					eff = true
					e[act + "_credited"] = int(e[act + "_credited"]) + 1
			e[act + "_prev"] = raw
			e[act + "_eff"] = eff

func get_move(p: int) -> Vector2:
	if _remote.has(p):
		var mv: Vector2 = _remote[p].get("move", Vector2.ZERO)
		return mv if mv.length() <= 1.0 else mv.normalized()  # never trust the wire
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
	if _remote.has(p):
		var e: Dictionary = _remote_edge.get(p, {})
		return bool(e.get(action + "_eff", bool(_remote[p].get(action, false))))
	var d := device_of(p)
	if d >= 0:
		var want_a := (action == "a") != pad_swapped(d)
		return Input.is_joy_button_pressed(d, JOY_BUTTON_A if want_a else JOY_BUTTON_B)
	if d == -4:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if action == "a" else MOUSE_BUTTON_RIGHT)
	var m := _keymap(d)
	return not m.is_empty() and Input.is_physical_key_pressed(m[action])

## For aiming games: world-space direction from `from_pos` toward the mouse
## cursor projected on the horizontal plane at from_pos.y. Returns ZERO for
## non-KBM devices (caller falls back to facing/move direction).
func get_aim_dir(p: int, from_pos: Vector3, cam: Camera3D) -> Vector3:
	if _remote.has(p):
		# Remote peers relay PRE-COMPUTED world-space unit vectors (computed
		# against their own mirrored render) — the _dbg_aim seam, networked.
		var ad: Vector3 = _remote[p].get("aim", Vector3.ZERO)
		return ad.normalized() if ad.length() > 0.05 else Vector3.ZERO
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
	if _remote.has(p):
		var asv: Vector2 = _remote[p].get("aim_screen", Vector2.ZERO)
		return asv.normalized() if asv.length() > 0.05 else Vector2.ZERO
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

## Right-stick AIM for pad devices: the raw right-stick vector (x = screen right,
## y = screen down, matching get_move's left-stick convention) or ZERO when the
## device is not a gamepad OR the stick sits inside a 0.25 deadzone. This is the
## twin-stick partner to get_move: callers wire LEFT (get_move) = MOVE and RIGHT
## (this / get_aim_dir cursor) = AIM. Non-pad devices (KBM cursor -4, keyboard
## halves -1/-2, shared -3, bots) get ZERO so they fall back to the mouse-cursor
## aim or the move direction — no existing device path changes.
func get_aim_stick(p: int) -> Vector2:
	if _remote.has(p):
		var stv: Vector2 = _remote[p].get("stick", Vector2.ZERO)
		return stv if stv.length() <= 1.0 else stv.normalized()
	var d := device_of(p)
	if d < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
	return v if v.length() > 0.25 else Vector2.ZERO

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
	_tick_remote_edges()
	_prev_down = _down.duplicate()
	for p in _devices:
		for action in ["a", "b"]:
			_down["%d_%s" % [p, action]] = is_down(p, action)
	for p in _remote:
		if not _devices.has(p):
			for action in ["a", "b"]:
				_down["%d_%s" % [p, action]] = is_down(p, action)

func _keymap(d: int) -> Dictionary:
	if _custom_maps.has(d):
		return _custom_maps[d]
	if d == -1 or d == -4:
		return KEY_LEFT_MAP
	if d == -2:
		return KEY_RIGHT_MAP
	return {}
