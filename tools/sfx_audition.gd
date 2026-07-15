extends Control
## SFX AUDITION — the morning veto surface for the Night-4 AAA SFX pass.
##
##   godot --path . res://tools/sfx_audition.tscn
##
## A keyboard/gamepad-navigable grid of every Sfx bank key plus the ambience
## beds. Arrow keys / D-pad move the selection; Enter / A plays the highlighted
## sound (a random round-robin variant, with the bank's pitch wobble). Ambience
## beds crossfade in; press Backspace / Escape (or the STOP AMBIENCE tile) to
## fade the current bed out.
##
## Automated capture (used by the build verifier):
##   godot --headless is NOT used (need a framebuffer); run windowed with:
##   godot --path . res://tools/sfx_audition.tscn -- --shot --outdir=verify_out/sfx_night4

const COLS := 6

# key-prefix -> human source tag, for the tile subtitle
const SOURCE_TAGS := [
	["impact_", "Kenney Impact"],
	["whoosh_", "OGA Swishes"],
	["ui_", "Kenney Interface/UI"],
	["tick_", "Kenney Interface"],
	["stinger_dread", "OGA gong"],
	["stinger_", "Kenney Sci-Fi"],
	["bell_", "OGA 100CC0"],
	["raven", "OGA crow_caw"],
	["creak", "Kenney RPG"],
	["thunder_", "Kenney Sci-Fi"],
	["gust", "synth (pink noise)"],
	["chain", "OGA 100CC0 metal"],
	["thud_coffin", "Kenney/OGA wood"],
	["organ_stab", "OGA gong [PLACEHOLDER]"],
	["projector", "OGA 100CC0 machine"],
	["amb_night", "OGA crickets"],
	["amb_wind", "synth (brown noise)"],
	["amb_room", "synth (brown noise)"],
]
# original-12 tags
const ORIG_TAGS := {
	"putt": "Kenney Impact", "bounce": "Kenney Impact", "bumper": "Kenney Impact",
	"death": "Kenney Jingles", "crush": "Kenney Impact", "splat": "Kenney Impact",
	"sink": "Kenney Jingles", "round_over": "Kenney Jingles", "match_win": "Kenney Jingles",
	"card": "Kenney Interface", "place": "Kenney Interface", "confirm": "Kenney Interface",
	"invalid": "Kenney Interface", "grudge": "Kenney Interface",
}

var _shot := false
var _out_dir := "verify_out/sfx_night4"
var _frame := 0
var _status: Label

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--shot":
			_shot = true
		elif arg.begins_with("--outdir="):
			_out_dir = arg.trim_prefix("--outdir=")

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 14)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_child(root)
	add_child(m)

	var title := Label.new()
	title.text = "ILL WILL — SFX AUDITION   (arrows/D-pad move · Enter/A play · Backspace stop bed)"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	_status = Label.new()
	_status.text = "%d SFX keys + %d ambience beds — every key declicked, edges at zero" % [Sfx.BANK.size(), Ambience.BEDS.size()]
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = Color(0.8, 0.8, 0.85)
	root.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var first: Button = null
	for key in Sfx.BANK.keys():
		var variants: int = Sfx.BANK[key].size()
		var b := _make_tile(key, variants, _tag_for(key), Color(0.16, 0.14, 0.2))
		b.pressed.connect(func(): _play_sfx(key))
		grid.add_child(b)
		if first == null:
			first = b
	for key in Ambience.BEDS.keys():
		var b := _make_tile(key, 1, _tag_for(key), Color(0.12, 0.18, 0.16))
		b.pressed.connect(func(): _play_bed(key))
		grid.add_child(b)
	var stop := _make_tile("STOP AMBIENCE", 0, "fade current bed out", Color(0.22, 0.10, 0.10))
	stop.pressed.connect(func(): Ambience.stop())
	grid.add_child(stop)

	if first:
		first.grab_focus()

func _make_tile(key: String, variants: int, tag: String, col: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 62)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vtxt := "  (%dx)" % variants if variants > 1 else ("  (bed)" if variants == 1 and key.begins_with("amb_") else "")
	b.text = "%s%s\n%s" % [key, vtxt, tag]
	b.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sbf := sb.duplicate()
	sbf.bg_color = col.lightened(0.25)
	sbf.set_border_width_all(2)
	sbf.border_color = Color(1, 0.85, 0.3)
	b.add_theme_stylebox_override("focus", sbf)
	b.add_theme_stylebox_override("hover", sbf)
	return b

func _play_sfx(key: String) -> void:
	Sfx.play(key)
	if _status:
		_status.text = "played  " + key

func _play_bed(key: String) -> void:
	Ambience.play_bed(key)
	if _status:
		_status.text = "bed  " + key + "  (Backspace to stop)"

func _tag_for(key: String) -> String:
	if ORIG_TAGS.has(key):
		return ORIG_TAGS[key]
	for pair in SOURCE_TAGS:
		if key.begins_with(pair[0]):
			return pair[1]
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE or event.keycode == KEY_ESCAPE:
			Ambience.stop()
			if _status:
				_status.text = "ambience stopped"

func _process(_delta: float) -> void:
	if not _shot:
		return
	_frame += 1
	if _frame == 8:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out_dir))
		var img := get_viewport().get_texture().get_image()
		var path := "res://%s/audition.png" % _out_dir
		img.save_png(path)
		print("AUDITION_SHOT ", path)
		get_tree().quit()
