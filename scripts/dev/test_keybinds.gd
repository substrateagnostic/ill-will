extends SceneTree
## Dev test: godot --headless --script res://scripts/dev/test_keybinds.gd
## Exercises core/player_input.gd custom keybinds: defaults, rebind,
## conflict-swap, pad A/B swap, describe_binding, save/load round-trip.
## Backs up and restores the real user://party_setup.json.

const PI_SCRIPT := preload("res://core/player_input.gd")
const SETUP := "user://party_setup.json"
const BACKUP := "user://party_setup.json.test_backup"

var fails := 0

func _init() -> void:
	var had_setup := FileAccess.file_exists(SETUP)
	if had_setup:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SETUP),
			ProjectSettings.globalize_path(BACKUP))
	var pi: Node = PI_SCRIPT.new()
	print("defaults:")
	_t(pi.binding_of(-1, "a") == KEY_SPACE, "WASD default A is Space")
	_t(pi.binding_of(-2, "a") == KEY_ENTER, "arrows default A is Enter")
	_t(pi.binding_of(-4, "up") == KEY_W, "KBM movement shares WASD map")
	print("rebind + conflict swap:")
	pi.set_key_binding(-1, "a", KEY_J)
	_t(pi.binding_of(-1, "a") == KEY_J, "rebind A to J")
	_t(pi.binding_of(-2, "a") == KEY_ENTER, "arrows map untouched")
	pi.set_key_binding(-1, "b", KEY_J)
	_t(pi.binding_of(-1, "b") == KEY_J, "rebind B to conflicting J")
	_t(pi.binding_of(-1, "a") == KEY_E, "A took B's old key (swap rule)")
	pi.reset_key_bindings(-1)
	_t(pi.binding_of(-1, "a") == KEY_SPACE, "reset restores defaults")
	print("pad swap + describe:")
	pi.assign(0, 2)
	pi.set_pad_swap(2, true)
	_t(pi.describe_binding(0, "a") == "(B)", "swapped pad describes A as (B)")
	pi.assign(1, -4)
	_t(pi.describe_binding(1, "a") == "LEFT CLICK", "KBM A is LEFT CLICK")
	pi.set_key_binding(-4, "up", KEY_I)
	_t(pi.describe_binding(1, "move").begins_with("I/"), "describe reflects live remap")
	print("persistence round-trip:")
	pi.set_key_binding(-1, "a", KEY_K)
	pi.save_setup()
	var pi2: Node = PI_SCRIPT.new()
	_t(pi2.load_setup(), "load_setup reads file")
	_t(pi2.binding_of(-1, "a") == KEY_K, "custom map survives reload")
	_t(pi2.pad_swapped(2), "pad swap survives reload")
	_t(pi2.binding_of(-2, "b") == KEY_SHIFT, "untouched device stays default")
	if had_setup:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP),
			ProjectSettings.globalize_path(SETUP))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETUP))
	pi.free()
	pi2.free()
	print("KEYBINDS_TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

func _t(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label)
