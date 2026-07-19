extends RefCounted
class_name InputGlyphs
## Static helper for per-player input prompt textures. Text always falls back
## to PlayerInput.describe_binding(), preserving custom remaps and remote text.

const GLYPH_ROOT: String = "res://assets/ui/glyphs/"
const BRAND_XBOX: String = "xbox"
const BRAND_PLAYSTATION: String = "playstation"
const BRAND_NINTENDO: String = "nintendo"
const BRAND_GENERIC: String = "generic"

const PAD_PATHS: Dictionary = {
	BRAND_XBOX: {
		"a": "xbox_button_a.png", "b": "xbox_button_b.png",
		"x": "xbox_button_x.png", "y": "xbox_button_y.png",
		"move": "xbox_stick_l.png", "left_stick": "xbox_stick_l.png",
		"right_stick": "xbox_stick_r.png", "dpad": "xbox_dpad.png",
		"lb": "xbox_lb.png", "rb": "xbox_rb.png", "start": "xbox_button_start.png",
	},
	BRAND_PLAYSTATION: {
		"a": "playstation_button_cross.png", "b": "playstation_button_circle.png",
		"x": "playstation_button_square.png", "y": "playstation_button_triangle.png",
		"move": "playstation_stick_l.png", "left_stick": "playstation_stick_l.png",
		"right_stick": "playstation_stick_r.png", "dpad": "playstation_dpad.png",
		"lb": "playstation_trigger_l1.png", "rb": "playstation_trigger_r1.png",
		"start": "playstation5_button_options.png",
	},
	BRAND_NINTENDO: {
		"a": "switch_button_b.png", "b": "switch_button_a.png",
		"x": "switch_button_y.png", "y": "switch_button_x.png",
		"move": "switch_stick_l.png", "left_stick": "switch_stick_l.png",
		"right_stick": "switch_stick_r.png", "dpad": "switch_dpad.png",
		"lb": "switch_button_l.png", "rb": "switch_button_r.png", "start": "switch_button_plus.png",
	},
	BRAND_GENERIC: {
		"a": "generic_button.png", "b": "generic_button_circle.png",
		"x": "generic_button_square.png", "y": "generic_button_square.png",
		"move": "generic_stick.png", "left_stick": "generic_stick.png",
		"right_stick": "generic_joystick.png", "dpad": "generic_stick.png",
		"lb": "generic_button_trigger_a.png", "rb": "generic_button_trigger_b.png",
		"start": "generic_button.png",
	},
}

const KEY_PATHS: Dictionary = {
	KEY_W: "keyboard_w.png",
	KEY_A: "keyboard_a.png",
	KEY_S: "keyboard_s.png",
	KEY_D: "keyboard_d.png",
	KEY_E: "keyboard_e.png",
	KEY_SPACE: "keyboard_space.png",
	KEY_ENTER: "keyboard_enter.png",
	KEY_SHIFT: "keyboard_shift.png",
	KEY_UP: "keyboard_arrow_up.png",
	KEY_DOWN: "keyboard_arrow_down.png",
	KEY_LEFT: "keyboard_arrow_left.png",
	KEY_RIGHT: "keyboard_arrow_right.png",
}

static var _texture_cache: Dictionary = {}

static func brand_for_device(device: int) -> String:
	if device < 0:
		return "keyboard"
	var joy_name: String = Input.get_joy_name(device).to_lower()
	if joy_name.contains("xbox") or joy_name.contains("xinput") or joy_name.contains("microsoft"):
		return BRAND_XBOX
	if joy_name.contains("playstation") or joy_name.contains("dualshock") or joy_name.contains("dualsense") or joy_name.contains("sony"):
		return BRAND_PLAYSTATION
	if joy_name.contains("switch") or joy_name.contains("joy-con") or joy_name.contains("joycon") or joy_name.contains("nintendo") or joy_name.contains("pro controller"):
		return BRAND_NINTENDO
	return BRAND_GENERIC

static func texture_for(player_idx: int, action: String) -> Texture2D:
	if PlayerInput.is_remote(player_idx):
		return null
	var device: int = PlayerInput.device_of(player_idx)
	if device >= 0:
		var brand: String = brand_for_device(device)
		var key: String = _pad_action_key(device, action)
		var brand_paths: Dictionary = PAD_PATHS.get(brand, PAD_PATHS[BRAND_GENERIC])
		return _texture(String(brand_paths.get(key, "")))
	if device == -3:
		return _mouse_texture(action)
	if device == -4 and (action == "a" or action == "b"):
		return _mouse_texture(action)
	return _keyboard_texture(device, action)

static func text_for(player_idx: int, action: String) -> String:
	return PlayerInput.describe_binding(player_idx, action)

## M2 DEVICE-AWARE INSTRUCTIONS — the bridge IntroCard (core/ui_kit/intro_card.gd)
## feature-detects. It looks for a global class named "InputGlyphs" exposing a
## static `glyph(seat, action) -> Texture2D`; we exposed `texture_for` instead, so
## the detection silently failed and every intro card fell back to plain text.
## This alias completes the rollout: with it present, all 15 games' intro cards
## now show the glyph for the DEVICE EACH SEAT IS USING — a pad seat sees its
## button, a KBM seat sees its key — with the describe_binding text as the
## fallback whenever a glyph asset is missing (or the seat is remote).
static func glyph(player_idx: int, action: String) -> Texture2D:
	return texture_for(player_idx, action)

static func texture_for_key(keycode: int) -> Texture2D:
	return _texture(String(KEY_PATHS.get(keycode, "")))

static func _pad_action_key(device: int, action: String) -> String:
	if action != "a" and action != "b":
		return action
	if not PlayerInput.pad_swapped(device):
		return action
	return "b" if action == "a" else "a"

static func _keyboard_texture(device: int, action: String) -> Texture2D:
	if action == "move":
		if device == -2:
			return _texture("keyboard_arrows.png")
		return _texture("keyboard_w.png")
	var keycode: int = PlayerInput.binding_of(device, action)
	return texture_for_key(keycode)

static func _mouse_texture(action: String) -> Texture2D:
	if action == "move":
		return _texture("mouse_move.png")
	if action == "a":
		return _texture("mouse_left.png")
	if action == "b":
		return _texture("mouse_right.png")
	return null

static func _texture(file_name: String) -> Texture2D:
	if file_name == "":
		return null
	var path: String = GLYPH_ROOT + file_name
	if not _texture_cache.has(path):
		if ResourceLoader.exists(path):
			_texture_cache[path] = load(path)
		else:
			_texture_cache[path] = null
	return _texture_cache[path] as Texture2D
