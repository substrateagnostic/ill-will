extends Node
## Autoload: FeedbackCapture. Thirteenth watch's last ship-to-strangers piece —
## two small, couch-first features (no text entry; testers have controllers,
## not keyboards):
##
##  1. VERSION — a single source of truth for the build number, shown small on
##     the title screen corner (estate.gd _enter_title_swap) and in the ESC
##     settings panel (party_setup.gd). export_presets.cfg's
##     application/file_version + application/product_version are EXPORT-TIME
##     metadata baked into the packaged .exe's PE header — Godot never mirrors
##     them into ProjectSettings, so there is nothing to read back at runtime.
##     This const is the runtime-readable twin. BUMP BOTH together on every
##     ship (see the matching comment left in export_presets.cfg).
##
##  2. PLAYTEST BOOKMARKS — "mark this moment" from anywhere: F9 on every
##     keyboard map (unbound in player_input.gd's KEY_LEFT_MAP/KEY_RIGHT_MAP/
##     KEY_KBM_MAP — cannot collide with a move/a/b/jump/plan binding), or a
##     ~0.6s hold of gamepad SELECT/BACK (JOY_BUTTON_BACK — the one couch face/
##     shoulder/dpad button PlayerInput never assigns to a, b, jump, plan or
##     plan_y; see player_input.gd's is_down()). A tap can't be a stray brush
##     of START (pause) or a move stick, so it needs no confirmation step.
##
##     Appends ONE line to user://playtest_notes.txt: timestamp, version,
##     scene, and whatever context is cheaply readable (THE PROCESSION's
##     night/round/acting seat via reflection on the live board node; a
##     running minigame's id; otherwise just the scene). Crash-safe — the file
##     is opened, appended, and closed for every single bookmark, never held
##     open. A 1.5s toast confirms the write landed. This never pauses the
##     tree, steals focus, or touches sim/rng state — bookmarking is a tester
##     side-channel, not a game action.

const VERSION := "0.4.0"   # <-- keep in lockstep with export_presets.cfg's
                            #     application/file_version + product_version

const NOTES_PATH := "user://playtest_notes.txt"
const HOLD_MS := 600        # gamepad SELECT/BACK long-hold threshold
const TOAST_TEXT := "⚑ noted"

var _pad_held_since: Dictionary = {}   # pad id -> Time.get_ticks_msec() when BACK went down
var _pad_fired: Dictionary = {}        # pad id -> true once this hold already wrote a bookmark

var _toast_layer: CanvasLayer = null
var _toast_label: Label = null
var _toast_tw: Tween = null

var _boot_test := false   # --feedbacktest: verify-only headless smoke test

func _ready() -> void:
	# Alive through pause (the ESC overlay pauses the tree) and every scene —
	# a bookmark must be takeable mid-pause too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_toast()
	for arg in OS.get_cmdline_user_args():
		if arg == "--feedbacktest":
			_boot_test = true
	if _boot_test:
		_run_boot_test.call_deferred()

## Verify-only headless smoke test (docs/verify idiom shared with MomentScribe's
## --newsreel-test etc.): prove the autoload loaded clean and a bookmark write
## actually lands in user:// under headless, no window/viewport required.
func _run_boot_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var line := _context_line()
	_append_note(line)
	print("FEEDBACK_CAPTURE_LINE " + line)
	var ok := FileAccess.file_exists(NOTES_PATH)
	print("FEEDBACK_CAPTURE_OK" if ok else "FEEDBACK_CAPTURE_FAIL")
	get_tree().quit()

## "v0.4.0" — the one string both display sites show.
func version_string() -> String:
	return "v" + VERSION

func _process(_delta: float) -> void:
	for pad: int in Input.get_connected_joypads():
		_poll_pad(pad)

## Edge + hold tracking per pad, same idiom as party_setup.gd's
## _poll_pause_buttons(): a dictionary of "since" timestamps keyed by pad id,
## with a "fired" latch so one long hold writes exactly one bookmark (release
## the button to arm the next one).
func _poll_pad(pad: int) -> void:
	var down: bool = Input.is_joy_button_pressed(pad, JOY_BUTTON_BACK)
	if not down:
		_pad_held_since.erase(pad)
		_pad_fired.erase(pad)
		return
	if bool(_pad_fired.get(pad, false)):
		return
	if not _pad_held_since.has(pad):
		_pad_held_since[pad] = Time.get_ticks_msec()
		return
	var since: int = int(_pad_held_since[pad])
	if Time.get_ticks_msec() - since >= HOLD_MS:
		_pad_fired[pad] = true
		_bookmark()

## F9 is a plain edge (no hold) — the keyboard has no ambiguous "brushed it
## mid-move" risk the way a gamepad's face/shoulder buttons do, and every
## keyboard map (LEFT/RIGHT/KBM) leaves F9 untouched.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F9:
		_bookmark()

func _bookmark() -> void:
	_append_note(_context_line())
	_show_toast()

## ---------------------------------------------------------------- context

func _context_line() -> String:
	var tree: SceneTree = get_tree()
	var cur: Node = tree.current_scene if tree != null else null
	var scene_name := "?"
	if cur != null:
		var fp: String = cur.scene_file_path
		scene_name = fp.get_file().get_basename() if fp != "" else String(cur.name)
	var extra := _extra_context(cur, tree)
	var ts := Time.get_datetime_string_from_system(false, true)   # "YYYY-MM-DD HH:MM:SS"
	var line := "%s | %s | scene=%s" % [ts, version_string(), scene_name]
	if extra != "":
		line += " | %s" % extra
	return line

## Best-available extra context: a running THE PROCESSION board (night/round/
## acting seat, all reflected off the live node so this file never needs to
## preload procession.gd or track its internals) beats a running minigame
## (which game), beats nothing.
func _extra_context(cur: Node, tree: SceneTree) -> String:
	if tree == null:
		return ""
	var mg := _find_minigame(cur, tree)
	if mg != null:
		return "minigame=%s" % _folder_of(mg.scene_file_path)
	var proc: Node = tree.root.get_node_or_null(^"Procession")
	if proc != null and is_instance_valid(proc):
		return _procession_context(proc)
	return ""

## A minigame instance is launched as a child of tree.root (or of the current
## scene) per the module contract (core/minigame.gd) — the estate shell never
## scene-switches for one. Mirrors MomentScribe._infer_game()'s scan so both
## systems agree on "which game is on screen" without coupling to each other.
func _find_minigame(cur: Node, tree: SceneTree) -> Node:
	if cur is Minigame and cur.scene_file_path != "":
		return cur
	var hosts: Array[Node] = [cur, tree.root]
	for host: Node in hosts:
		if host == null:
			continue
		for c in host.get_children():
			if c is Minigame and c.scene_file_path != "":
				return c
	return null

func _folder_of(path: String) -> String:
	return path.get_base_dir().get_file()

## Reflection-only reads (Object.get) off the live Procession node — round_num
## and night_index are plain top-level vars; _pip_seat ("the seat the PIP
## currently follows", -1 between turns) is the cheapest available proxy for
## "acting seat" without touching the sim. All three are read-only glances.
func _procession_context(proc: Node) -> String:
	var night_v: Variant = proc.get("night_index")
	var round_v: Variant = proc.get("round_num")
	var night_index: int = int(night_v) if night_v != null else -1
	var round_num: int = int(round_v) if round_v != null else -1
	var out := "procession night=%d round=%d" % [night_index, round_num]
	var seat_v: Variant = proc.get("_pip_seat")
	var seat: int = int(seat_v) if seat_v != null else -1
	if seat >= 0:
		var roster_v: Variant = proc.get("roster")
		if roster_v is Array and seat < (roster_v as Array).size():
			out += " seat=%s" % String((roster_v as Array)[seat].name)
	return out

## ---------------------------------------------------------------- file I/O

## Crash-safe: open, append, close — never held open between bookmarks.
func _append_note(line: String) -> void:
	var f: FileAccess
	if FileAccess.file_exists(NOTES_PATH):
		f = FileAccess.open(NOTES_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("FeedbackCapture: could not open " + NOTES_PATH)
		return
	f.store_line(line)
	f.close()

## ---------------------------------------------------------------- toast

## A bare CanvasLayer + Label, well above any HUD (layer 100), corner-parked
## so it can never block a click or a gamepad focus ring. Fade in/out only —
## no pause, no input capture; MOUSE_FILTER_IGNORE and PROCESS_MODE_ALWAYS so
## it never interacts with whatever's on screen, paused or not.
func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 100
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)
	_toast_label = Label.new()
	_toast_label.text = TOAST_TEXT
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_label.offset_left = -180.0
	_toast_label.offset_top = 18.0
	_toast_label.offset_right = -20.0
	_toast_label.offset_bottom = 48.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast_label.add_theme_color_override("font_color", Color(0.92, 0.87, 0.76))
	_toast_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.07))
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.modulate.a = 0.0
	_toast_layer.add_child(_toast_label)

func _show_toast() -> void:
	if _toast_label == null:
		return
	_toast_label.modulate.a = 0.0
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(1.05)
	_toast_tw.tween_property(_toast_label, "modulate:a", 0.0, 0.3)
