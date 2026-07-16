class_name AttractMode
extends CanvasLayer
## THE HOUSE REHEARSES — the estate's attract mode (doc 25 §3.2).
##
## After the title sits idle, the house rehearses: a bot-only exhibition of a
## random (non-theater) minigame, launched through the estate's EXISTING proven
## exhibition path (exhibition = true -> _launch_game, exactly what --exhibtest=
## exercises), presented under a live 1920s film-decay wash with an intertitle
## card in the estate's voice and a persistent "any input" interrupt affordance
## (the named lesson from doc 25's ATTRACT-3). FrontEndDirector owns the trigger,
## the seat backup/restore, and teardown; this node owns only the presentation.
##
## It never touches saves or EstateState — it forces seats to bots for the
## exhibition (the director restores them on exit) and rides the shell's own
## zombie-module sweep (PartySetup.quit_to_title) for a clean return to title.

const SHADER_PATH := "res://assets/shaders/attract_filmwash.gdshader"
const HEADER_FONT := "res://assets/fonts/Bangers-Regular.ttf"
const BODY_FONT := "res://assets/fonts/Fredoka.ttf"
const CARD_HOLD := 3.0

var _estate: Node = null
var _module: Node = null
var _card_box: VBoxContainer = null
var _caption: Label = null

## Launch the rehearsal. `estate` is the live estate scene; `gid`/`game_name`
## are the module the director picked. All seats are forced to bots here; the
## director has already snapshotted them and restores them on teardown.
func begin(estate: Node, gid: String, game_name: String) -> void:
	_estate = estate
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_wash()
	_build_caption()
	_build_card(game_name)
	for i in 4:
		PlayerInput.set_bot(i, true)
	estate.set("exhibition", true)
	estate.call("_launch_game", gid)
	_module = estate.get("_module")
	_run_card()

## The estate has ended the exhibition (match over -> it leaves Phase.GAME and
## frees its module) or the scene went away — the director should tear us down.
func should_end() -> bool:
	if not is_instance_valid(_estate):
		return true
	if not is_instance_valid(_module):
		return true
	if _estate.has_method("get_phase_name") and str(_estate.call("get_phase_name")) != "GAME":
		return true
	return false

## ---------------------------------------------------------------- presentation

func _build_wash() -> void:
	var wash := ColorRect.new()
	wash.name = "FilmWash"
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = load(SHADER_PATH)
	if sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		wash.material = mat
	add_child(wash)

func _build_caption() -> void:
	_caption = Label.new()
	_caption.text = "ANY INPUT ENDS THE REHEARSAL"
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.offset_top = -66
	_caption.offset_bottom = -26
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bfont: Variant = load(BODY_FONT)
	if bfont != null:
		_caption.add_theme_font_override("font", bfont)
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74))
	_caption.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.0))
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.modulate.a = 0.5
	add_child(_caption)
	# A slow gutter so the interrupt affordance reads as alive, never a dead label.
	var pulse := create_tween().set_loops()
	pulse.tween_property(_caption, "modulate:a", 0.78, 1.1).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_caption, "modulate:a", 0.42, 1.1).set_trans(Tween.TRANS_SINE)

func _build_card(game_name: String) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card_box = VBoxContainer.new()
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_box.add_theme_constant_override("separation", 14)
	_card_box.modulate.a = 0.0
	center.add_child(_card_box)
	var hfont: Variant = load(HEADER_FONT)
	var bfont: Variant = load(BODY_FONT)
	_card_box.add_child(_mk_label(hfont, 76, Color(0.95, 0.92, 0.82), "THE HOUSE REHEARSES"))
	_card_box.add_child(_rule())
	_card_box.add_child(_mk_label(bfont if bfont != null else hfont, 46, Color(0.98, 0.96, 0.9), "\"%s\"" % game_name))
	_card_box.add_child(_rule())
	_card_box.add_child(_mk_label(bfont if bfont != null else hfont, 22, Color(0.78, 0.73, 0.6),
		"performed for no one. recorded regardless."))

func _mk_label(font: Variant, size: int, col: Color, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.0))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _rule() -> Control:
	# The ornamental double-rule of a proper intertitle card (newsreel's dressing).
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for w in [Vector2(320, 2), Vector2(220, 1)]:
		var line := ColorRect.new()
		line.color = Color(0.8, 0.75, 0.6, 0.85)
		line.custom_minimum_size = w
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(line)
	return box

func _run_card() -> void:
	Sfx.play("card", -4.0)
	var tw := create_tween()
	tw.tween_property(_card_box, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await _verify_snap("attract_card")
	await _sleep(CARD_HOLD)
	var tw2 := create_tween()
	tw2.tween_property(_card_box, "modulate:a", 0.0, 0.5)
	await tw2.finished
	await _verify_snap("attract_wash")

func _sleep(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

## Verify-only capture at the two beats worth a picture (intertitle, then the
## live film-wash with the caption). Inert unless the harness is active.
func _verify_snap(tag: String) -> void:
	var vc: Node = get_node_or_null("/root/VerifyCapture")
	if vc == null or not bool(vc.get("active")):
		return
	if vc.has_method("snap"):
		await vc.call("snap", tag)
