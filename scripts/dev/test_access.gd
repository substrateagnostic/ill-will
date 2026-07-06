extends SceneTree
## Dev test: godot --headless --script res://scripts/dev/test_access.gd
## Exercises the ACCESS tab data path: GameState colorblind PALETTES +
## apply_palette (4 modes, in-place mutation so live readers update, unknown-id
## fallback, classic restore) and the user://prefs.json persistence that
## core/party_setup.gd uses for the "palette" and "ui_scale" prefs.
## Backs up and restores the real user://prefs.json.
##
## NOTE: game_state.gd is self-contained so we preload + instantiate it directly.
## party_setup.gd references autoload singletons (PlayerInput/GameState/Sfx),
## which are not yet registered as globals at --script compile time, so it can't
## be preloaded here. Instead we round-trip the exact JSON + user://prefs.json
## store its set_pref/_load_prefs use; the windowed screenshot boots exercise the
## full party_setup read-and-apply path end-to-end (pre-written prefs -> palette).

const GS_SCRIPT := preload("res://scripts/game_state.gd")
const PREFS := "user://prefs.json"
const BACKUP := "user://prefs.json.test_backup"

var fails := 0

func _init() -> void:
	var had_prefs := FileAccess.file_exists(PREFS)
	if had_prefs:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PREFS),
			ProjectSettings.globalize_path(BACKUP))

	print("palette data:")
	# .new() runs member init (PLAYER_COLORS) but NOT _ready, so no autoload deps.
	var gs: Node = GS_SCRIPT.new()
	_t(gs.PALETTES.size() == 4, "PALETTES has 4 modes")
	for id in ["classic", "deutan", "protan", "tritan"]:
		var pal: Array = gs.PALETTES.get(id, [])
		_t(pal.size() == 4, "%s palette has 4 colors" % id)

	print("apply_palette:")
	var classic_red: Color = gs.PLAYER_COLORS[0]
	var live_ref: Array = gs.PLAYER_COLORS
	gs.apply_palette("deutan")
	var deutan_red: Color = gs.PALETTES["deutan"][0]
	_t(gs.PLAYER_COLORS[0] == deutan_red, "apply deutan sets RED")
	_t(gs.PLAYER_COLORS.size() == 4, "still 4 seats after apply")
	_t(live_ref[0] == deutan_red, "mutates the SAME array in place (live readers update)")
	gs.apply_palette("tritan")
	var tritan_mint: Color = gs.PALETTES["tritan"][3]
	_t(gs.PLAYER_COLORS[3] == tritan_mint, "apply tritan sets MINT")
	gs.apply_palette("classic")
	_t(gs.PLAYER_COLORS[0] == classic_red, "apply classic restores shipped RED")
	gs.apply_palette("nonsense")
	_t(gs.PLAYER_COLORS[0] == classic_red, "unknown id falls back to classic")
	gs.free()

	print("prefs persistence (palette + ui_scale) via user://prefs.json:")
	# Mirror party_setup._save_prefs: JSON.stringify -> user://prefs.json.
	var out := {"palette": "tritan", "ui_scale": 1.2, "screen_shake": false}
	var wf := FileAccess.open(PREFS, FileAccess.WRITE)
	_t(wf != null, "prefs.json opens for write")
	if wf:
		wf.store_string(JSON.stringify(out))
		wf.close()
	# Mirror party_setup._load_prefs: read + JSON.parse_string back to Dictionary.
	var text := FileAccess.open(PREFS, FileAccess.READ).get_as_text()
	var back = JSON.parse_string(text)
	_t(back is Dictionary, "prefs.json parses back to a Dictionary")
	var d: Dictionary = back if back is Dictionary else {}
	_t(str(d.get("palette", "classic")) == "tritan", "palette pref survives round-trip")
	_t(absf(float(d.get("ui_scale", 1.0)) - 1.2) < 0.0001, "ui_scale pref survives round-trip")
	_t(str(d.get("missing_key", "def")) == "def", "absent key returns caller default")

	if had_prefs:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP),
			ProjectSettings.globalize_path(PREFS))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))

	print("ACCESS_TEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

func _t(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label)
