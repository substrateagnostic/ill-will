class_name USReveal
extends CanvasLayer
## THE CASTING — sequential, private role delivery for one shared screen.
## The house lights fall. The Executor calls each seat in turn; only the named
## player looks. A face-down script card sits centre stage. On the called
## player's own button it turns over — THE PLAY for the cast, or the bare word
## UNDERSTUDY for the one who never got a script. Then it turns face-down again
## and the next seat is called. Nobody sees another's card.

const F_LUCKIEST := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const F_BALOO := preload("res://assets/fonts/Baloo2.ttf")
const F_FREDOKA := preload("res://assets/fonts/Fredoka.ttf")

const PARCHMENT := Color(0.93, 0.87, 0.72)
const INK := Color(0.17, 0.12, 0.08)
const GOLD := Color(1.0, 0.83, 0.36)
const CRIMSON := Color(0.86, 0.24, 0.26)

var _root: Control
var _dim: ColorRect
var _call_label: Label
var _eyes_label: Label
var _card: Panel
var _card_sb: StyleBoxFlat
var _card_back: Control
var _card_face: Control
var _face_kicker: Label
var _face_title: Label
var _face_body: Label
var _prompt: Label
var _seal: Label
var _pulse := 0.0
var _accent := Color.WHITE

func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.01, 0.03, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	_call_label = _mk(_root, "", F_LUCKIEST, 58, Color.WHITE)
	_call_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_call_label.offset_left = 20
	_call_label.offset_right = -20
	_call_label.offset_top = 70
	_call_label.offset_bottom = 150
	_call_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_eyes_label = _mk(_root, "EVERYONE ELSE — EYES DOWN", F_BALOO, 22, Color(0.82, 0.62, 0.6))
	_eyes_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_eyes_label.offset_left = 20
	_eyes_label.offset_right = -20
	_eyes_label.offset_top = 150
	_eyes_label.offset_bottom = 186
	_eyes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# the script card
	_card = Panel.new()
	_card_sb = StyleBoxFlat.new()
	_card_sb.bg_color = Color(0.12, 0.09, 0.11, 0.98)
	_card_sb.set_border_width_all(6)
	_card_sb.border_color = Color.WHITE
	_card_sb.set_corner_radius_all(14)
	_card_sb.shadow_color = Color(0, 0, 0, 0.6)
	_card_sb.shadow_size = 20
	_card.add_theme_stylebox_override("panel", _card_sb)
	_card.size = Vector2(520, 360)
	_card.position = Vector2(640 - 260, 210)
	_card.pivot_offset = Vector2(260, 180)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)

	# face-down back: a wax-sealed folded script
	_card_back = Control.new()
	_card_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_back)
	var back_fill := ColorRect.new()
	back_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_fill.color = Color(0.16, 0.11, 0.13)
	back_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_back.add_child(back_fill)
	var back_word := _mk(_card_back, "THE SCRIPT", F_LUCKIEST, 34, Color(0.55, 0.45, 0.4))
	back_word.set_anchors_preset(Control.PRESET_CENTER_TOP)
	back_word.offset_left = -200
	back_word.offset_right = 200
	back_word.offset_top = 96
	back_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal = _mk(_card_back, "✕", F_LUCKIEST, 78, CRIMSON)
	_seal.set_anchors_preset(Control.PRESET_CENTER)
	_seal.offset_left = -80
	_seal.offset_right = 80
	_seal.offset_top = -20
	_seal.offset_bottom = 110
	_seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# face-up: the part
	_card_face = Control.new()
	_card_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_face)
	var face_fill := ColorRect.new()
	face_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	face_fill.color = PARCHMENT
	face_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_face.add_child(face_fill)
	_face_kicker = _mk(_card_face, "TONIGHT'S PLAY", F_BALOO, 20, Color(0.5, 0.36, 0.2))
	_face_kicker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_face_kicker.offset_left = 14
	_face_kicker.offset_right = -14
	_face_kicker.offset_top = 34
	_face_kicker.offset_bottom = 64
	_face_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_title = _mk(_card_face, "", F_LUCKIEST, 44, INK)
	_face_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_face_title.offset_left = 14
	_face_title.offset_right = -14
	_face_title.offset_top = 78
	_face_title.offset_bottom = 210
	_face_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_face_body = _mk(_card_face, "", F_BALOO, 20, Color(0.32, 0.24, 0.16))
	_face_body.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_face_body.offset_left = 28
	_face_body.offset_right = -28
	_face_body.offset_top = 214
	_face_body.offset_bottom = 348
	_face_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_face_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_card_face.visible = false

	_prompt = _mk(_root, "", F_LUCKIEST, 30, GOLD)
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_left = 20
	_prompt.offset_right = -20
	_prompt.offset_top = -150
	_prompt.offset_bottom = -110
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	visible = false

func _mk(parent: Control, text: String, font: FontFile, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.07))
	l.add_theme_constant_override("outline_size", maxi(3, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# --- API --------------------------------------------------------------------
func open() -> void:
	visible = true
	_root.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.93, 0.4)

func show_call(pname: String, col: Color, glyph: String) -> void:
	_accent = col
	_card.visible = true
	# seat name HUGE for the one player peeking; standing instruction for the rest
	_call_label.text = "%s %s — YOUR PART" % [glyph, pname]
	_call_label.add_theme_color_override("font_color", col)
	_eyes_label.text = "EVERYONE ELSE — EYES DOWN · LISTEN FOR YOUR VOICE"
	_eyes_label.add_theme_color_override("font_color", Color(0.82, 0.62, 0.6))
	_eyes_label.visible = true
	_card_sb.border_color = col
	_show_back()
	_prompt.text = "%s: PRESS  A  TO READ" % pname
	_prompt.visible = true

## Roll-call intro — eyes OPEN, before the lights fall. No card yet.
func show_rollcall_intro() -> void:
	_card.visible = false
	_call_label.text = "YOUR COLOUR HAS A VOICE"
	_call_label.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	_eyes_label.text = "EYES OPEN — LEARN YOUR SOUND BEFORE THE LIGHTS FALL"
	_eyes_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	_eyes_label.visible = true
	_prompt.text = "each colour speaks in turn — listen"
	_prompt.visible = true

## Roll-call slot — one colour learns its summons, eyes OPEN, name HUGE.
func show_teach(pname: String, col: Color, glyph: String) -> void:
	_accent = col
	_card.visible = false
	_call_label.text = "%s %s" % [glyph, pname]
	_call_label.add_theme_color_override("font_color", col)
	_eyes_label.text = "THIS IS YOUR VOICE — REMEMBER IT"
	_eyes_label.add_theme_color_override("font_color", Color(0.82, 0.7, 0.6))
	_eyes_label.visible = true
	_prompt.text = "%s — three ticks in your tone" % pname
	_prompt.visible = true

## Interstitial between two seats — eyes down, hold the silence.
func show_gap() -> void:
	_card.visible = false
	_call_label.text = "EYES DOWN"
	_call_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.72))
	_eyes_label.text = "LISTEN FOR YOUR VOICE — THE NEXT COLOUR IS COMING"
	_eyes_label.add_theme_color_override("font_color", Color(0.7, 0.66, 0.66))
	_eyes_label.visible = true
	_prompt.visible = false

func flip_to_cast(play_title: String) -> void:
	_face_kicker.text = "TONIGHT'S PLAY"
	_face_kicker.add_theme_color_override("font_color", Color(0.5, 0.36, 0.2))
	_face_title.text = play_title
	_face_title.add_theme_color_override("font_color", INK)
	_face_body.text = "You have read the script. Move like you belong on this stage — and do not overplay it."
	_flip()
	_prompt.text = "PRESS  A  WHEN COMMITTED"

## ONLINE: a REMOTE seat's card is dealt to its peer alone. The host screen and
## every other guest's mirror flip to THIS — a redacted face, no play, no role.
## (Seance's "THE CARD IS DELIVERED TO THEIR SCREEN ALONE", the understudy cut.)
func flip_to_redacted(pname: String, col: Color, glyph: String) -> void:
	_face_kicker.text = "%s %s" % [glyph, pname]
	_face_kicker.add_theme_color_override("font_color", col)
	_face_title.text = "SUMMONED\nACROSS THE WIRE"
	_face_title.add_theme_color_override("font_color", Color(0.62, 0.58, 0.68))
	_face_body.text = "THE SCRIPT IS DELIVERED TO THEIR SCREEN ALONE"
	_flip()
	_prompt.text = "their part is theirs alone"

func flip_to_understudy(candidates: Array) -> void:
	_face_kicker.text = "YOU ARE THE"
	_face_kicker.add_theme_color_override("font_color", Color(0.6, 0.2, 0.2))
	_face_title.text = "UNDERSTUDY"
	_face_title.add_theme_color_override("font_color", Color(0.7, 0.16, 0.18))
	var joined := ""
	for i in candidates.size():
		joined += str(candidates[i])
		if i < candidates.size() - 1:
			joined += "   ·   "
	_face_body.text = "You never got the script. Tonight's play is one of:\n" + joined + "\nWatch the rehearsal. Deduce it. Blend."
	_flip()
	_prompt.text = "PRESS  A  WHEN COMMITTED"

func _show_back() -> void:
	_card_back.visible = true
	_card_face.visible = false
	_card.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _flip() -> void:
	# a quick horizontal squash to sell the turn-over
	var tw := create_tween()
	tw.tween_property(_card, "scale:x", 0.04, 0.13).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_card_back.visible = false
		_card_face.visible = true)
	tw.tween_property(_card, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("card", -2.0)

func close() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		visible = false
		_dim.color.a = 0.0
		_card_face.visible = false
		_card_back.visible = true)

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	var g := 0.6 + 0.4 * sin(_pulse * 3.0)
	_prompt.modulate.a = g
	if _card_back.visible:
		_seal.add_theme_color_override("font_color", Color(_accent.r, _accent.g, _accent.b, 0.5 + 0.5 * g))
