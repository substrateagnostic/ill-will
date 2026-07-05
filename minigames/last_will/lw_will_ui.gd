class_name LWWillUI
extends CanvasLayer
## THE SHOW. The will-drafting pause overlay: the world dims, the deceased's
## color frames the screen, a memorial portrait (live SubViewport bust) hangs
## on the left, three parchment cards fill the center, and a six-second
## timer drains along the bottom. The controller drives the state machine;
## this layer only performs.

const F_LUCKIEST := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const F_BALOO := preload("res://assets/fonts/Baloo2.ttf")
const F_FREDOKA := preload("res://assets/fonts/Fredoka.ttf")

const GOLD := Color(1.0, 0.83, 0.36)
const GOLD_DIM := Color(0.78, 0.62, 0.3)
const GREEN := Color(0.55, 0.95, 0.5)
const GREEN_DIM := Color(0.42, 0.66, 0.38)
const PARCHMENT := Color(0.94, 0.88, 0.74)
const INK := Color(0.16, 0.12, 0.09)

var _dc := Color.WHITE          # deceased color
var _pulse_t := 0.0
var _peek := false              # target phase: let the 3D world (and the
                                # skeletal hand) read through the dim

var _root: Control
var _dim: ColorRect
var _vig: TextureRect
var _edges: Array = []          # 4 frame bars
var _edges_soft: Array = []
var _title: Label
var _subtitle: Label
var _plaque: Panel
var _plaque_name: Label
var _portrait_vp: SubViewport
var _portrait_model: Node3D
var _portrait_spin: Node3D
var _portrait_light: OmniLight3D
var _cards_box: HBoxContainer
var _card_panels: Array = []
var _prompt: Label
var _target_label: Label
var _mode_box: HBoxContainer
var _mode_panels: Array = []
var _timer_bg: Panel
var _timer_fill: ColorRect
var _timer_label: Label
var _res_lines: VBoxContainer

func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	# radial vignette: transparent heart, heavy corners
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.82))
	grad.add_point(0.55, Color(0, 0, 0, 0.12))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.02)
	gt.width = 512
	gt.height = 512
	_vig = TextureRect.new()
	_vig.texture = gt
	_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.modulate.a = 0.0
	_root.add_child(_vig)

	# color frame: hard edge bars + soft glow bars
	for i in 4:
		var soft := ColorRect.new()
		soft.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(soft)
		_edges_soft.append(soft)
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)
		_edges.append(bar)
	_layout_frame()
	_peek = false

	_title = _mk_label("", F_LUCKIEST, 54, Color.WHITE)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 22
	_title.offset_bottom = 88
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)

	_subtitle = _mk_label("SIX SECONDS OF POSTHUMOUS POWER", F_BALOO, 19, Color(0.8, 0.74, 0.62))
	_subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_subtitle.offset_top = 86
	_subtitle.offset_bottom = 116
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_subtitle)

	_build_plaque()
	_build_cards_box()
	_build_prompt()
	_build_timer()
	_build_resolution()

	visible = false

func _mk_label(text: String, font: FontFile, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.06))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _layout_frame() -> void:
	var t := 9.0
	var st := 24.0
	# top, bottom, left, right
	var rects := [Rect2(0, 0, 1280, t), Rect2(0, 720 - t, 1280, t),
		Rect2(0, 0, t, 720), Rect2(1280 - t, 0, t, 720)]
	var softs := [Rect2(0, 0, 1280, st), Rect2(0, 720 - st, 1280, st),
		Rect2(0, 0, st, 720), Rect2(1280 - st, 0, st, 720)]
	for i in 4:
		var b: ColorRect = _edges[i]
		b.position = rects[i].position
		b.size = rects[i].size
		var s: ColorRect = _edges_soft[i]
		s.position = softs[i].position
		s.size = softs[i].size

func _build_plaque() -> void:
	_plaque = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.075, 0.1, 0.96)
	sb.border_width_left = 6
	sb.border_width_right = 6
	sb.border_width_top = 6
	sb.border_width_bottom = 6
	sb.border_color = Color.WHITE
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 14
	_plaque.add_theme_stylebox_override("panel", sb)
	_plaque.position = Vector2(58, 148)
	_plaque.size = Vector2(252, 372)
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plaque)

	_portrait_vp = SubViewport.new()
	_portrait_vp.size = Vector2i(240, 280)
	_portrait_vp.own_world_3d = true
	_portrait_vp.transparent_bg = true
	_portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_portrait_vp)

	var tex := TextureRect.new()
	tex.texture = _portrait_vp.get_texture()
	tex.position = Vector2(6, 6)
	tex.size = Vector2(240, 280)
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(tex)

	# black memorial ribbon across the top-right corner
	var ribbon := Polygon2D.new()
	ribbon.polygon = PackedVector2Array([Vector2(252 - 74, 0), Vector2(252, 74),
		Vector2(252, 46), Vector2(252 - 46, 0)])
	ribbon.color = Color(0.05, 0.05, 0.07, 0.95)
	_plaque.add_child(ribbon)

	_plaque_name = _mk_label("", F_LUCKIEST, 30, Color.WHITE)
	_plaque_name.position = Vector2(6, 288)
	_plaque_name.size = Vector2(240, 42)
	_plaque_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plaque.add_child(_plaque_name)

	var rip := _mk_label("BELOVED RIVAL — GONE TOO SOON", F_BALOO, 13, Color(0.66, 0.6, 0.52))
	rip.position = Vector2(6, 330)
	rip.size = Vector2(240, 26)
	rip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plaque.add_child(rip)

	# portrait world: camera + lights (model swapped per deceased)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.26, 2.4)
	cam.rotation_degrees = Vector3(-3, 0, 0)
	cam.fov = 35.0
	_portrait_vp.add_child(cam)
	_portrait_light = OmniLight3D.new()
	_portrait_light.position = Vector3(1.1, 1.9, 1.4)
	_portrait_light.light_energy = 2.4
	_portrait_light.omni_range = 7.0
	_portrait_vp.add_child(_portrait_light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 150, 0)
	fill.light_energy = 0.7
	fill.light_color = Color(0.7, 0.75, 1.0)
	_portrait_vp.add_child(fill)
	_portrait_spin = Node3D.new()
	_portrait_vp.add_child(_portrait_spin)

func _build_cards_box() -> void:
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 20)
	_cards_box.position = Vector2(360, 138)
	_cards_box.size = Vector2(846, 402)
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cards_box)

func _build_prompt() -> void:
	_prompt = _mk_label("", F_LUCKIEST, 52, GOLD)
	_prompt.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_prompt.offset_top = 168
	_prompt.offset_bottom = 240
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_root.add_child(_prompt)

	_target_label = _mk_label("", F_LUCKIEST, 72, Color.WHITE)
	_target_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_target_label.offset_top = 260
	_target_label.offset_bottom = 360
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.visible = false
	_root.add_child(_target_label)

	_mode_box = HBoxContainer.new()
	_mode_box.add_theme_constant_override("separation", 40)
	_mode_box.position = Vector2(400, 250)
	_mode_box.size = Vector2(560, 200)
	_mode_box.visible = false
	_mode_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mode_box)

func _build_timer() -> void:
	_timer_bg = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.85)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.5, 0.45, 0.4)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	_timer_bg.add_theme_stylebox_override("panel", sb)
	_timer_bg.position = Vector2(390, 630)
	_timer_bg.size = Vector2(440, 26)
	_timer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_timer_bg)

	_timer_fill = ColorRect.new()
	_timer_fill.position = Vector2(4, 4)
	_timer_fill.size = Vector2(432, 18)
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bg.add_child(_timer_fill)

	_timer_label = _mk_label("6", F_LUCKIEST, 40, Color.WHITE)
	_timer_label.position = Vector2(846, 612)
	_timer_label.size = Vector2(80, 56)
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_timer_label)

func _build_resolution() -> void:
	_res_lines = VBoxContainer.new()
	_res_lines.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_res_lines.offset_top = 240
	_res_lines.offset_bottom = 460
	_res_lines.add_theme_constant_override("separation", 18)
	_res_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_res_lines.visible = false
	_res_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_res_lines)

# ================================================================ API
func open(pname: String, color: Color, char_scene_path: String) -> void:
	_dc = color
	visible = true
	_title.text = "THE LAST WILL OF %s" % pname
	_title.add_theme_color_override("font_color", color.lightened(0.15))
	_plaque_name.text = pname
	_plaque_name.add_theme_color_override("font_color", color)
	var sb: StyleBoxFlat = _plaque.get_theme_stylebox("panel")
	sb.border_color = color
	# swap the portrait bust
	if _portrait_model != null:
		_portrait_model.queue_free()
		_portrait_model = null
	if char_scene_path != "" and ResourceLoader.exists(char_scene_path):
		var scene: PackedScene = load(char_scene_path)
		_portrait_model = scene.instantiate()
		_portrait_spin.add_child(_portrait_model)
		_portrait_model.position = Vector3(0, 0, 0)
		var anim: AnimationPlayer = _portrait_model.find_child("AnimationPlayer", true, false)
		if anim and anim.has_animation("Idle"):
			anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("Idle")
	_portrait_light.light_color = color.lightened(0.3)
	_portrait_spin.rotation.y = 0.0

	# entrance: dim + vignette + frame breathe in; cards come later
	_peek = false
	_cards_box.visible = false
	_prompt.visible = false
	_target_label.visible = false
	_mode_box.visible = false
	_res_lines.visible = false
	_set_timer_visible(false)
	_plaque.visible = true
	_title.visible = true
	_subtitle.visible = true
	_plaque.modulate.a = 0.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.68, 0.45)
	tw.tween_property(_vig, "modulate:a", 1.0, 0.45)
	tw.tween_property(_title, "modulate:a", 1.0, 0.5).set_delay(0.15)
	tw.tween_property(_subtitle, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tw.tween_property(_plaque, "modulate:a", 1.0, 0.5).set_delay(0.25)
	# dim carries a whisper of the deceased's color
	_dim.color = Color(_dc.r * 0.06, _dc.g * 0.06, _dc.b * 0.08, _dim.color.a)

func show_cards(cards: Array) -> void:
	for c in _card_panels:
		c.queue_free()
	_card_panels.clear()
	_cards_box.visible = true
	_cards_box.modulate = Color.WHITE
	_cards_box.scale = Vector2.ONE
	for i in cards.size():
		var panel := _make_card(cards[i])
		_cards_box.add_child(panel)
		_card_panels.append(panel)
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.82, 0.82)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "modulate:a", 1.0, 0.22).set_delay(0.07 * i)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.26).set_delay(0.07 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_timer_visible(true)

func _make_card(card: Dictionary) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(262, 396)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.08, 0.97)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.45, 0.38, 0.26)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.pivot_offset = Vector2(131, 198)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)

	var bl: Dictionary = card.bless
	var cu: Dictionary = card.curse

	var h1 := _mk_label("✦ BEQUEATH", F_BALOO, 14, GOLD_DIM)
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h1)
	var icon1 := LWCardIcon.new()
	icon1.custom_minimum_size = Vector2(0, 74)
	icon1.set_icon(str(bl.kind), GOLD)
	icon1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon1)
	var t1 := _mk_label(str(bl.title), F_LUCKIEST, 27, GOLD)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var d1 := _mk_label(str(bl.desc), F_BALOO, 14, Color(0.85, 0.8, 0.68))
	d1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d1.autowrap_mode = TextServer.AUTOWRAP_WORD
	d1.custom_minimum_size = Vector2(0, 48)
	v.add_child(d1)

	var mid := _mk_label("— upon one — a plague upon another —", F_BALOO, 12, Color(0.52, 0.47, 0.42))
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mid)

	var h2 := _mk_label("☠ CONDEMN", F_BALOO, 14, GREEN_DIM)
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h2)
	var icon2 := LWCardIcon.new()
	icon2.custom_minimum_size = Vector2(0, 74)
	icon2.set_icon(str(cu.kind), GREEN)
	icon2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon2)
	var t2 := _mk_label(str(cu.title), F_LUCKIEST, 27, GREEN)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	var d2 := _mk_label(str(cu.desc), F_BALOO, 14, Color(0.72, 0.82, 0.68))
	d2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d2.autowrap_mode = TextServer.AUTOWRAP_WORD
	d2.custom_minimum_size = Vector2(0, 48)
	v.add_child(d2)
	return p

func set_card_sel(idx: int) -> void:
	for i in _card_panels.size():
		var p: Panel = _card_panels[i]
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
		if i == idx:
			p.modulate = Color.WHITE
			sb.border_color = _dc
			sb.border_width_left = 5
			sb.border_width_right = 5
			sb.border_width_top = 5
			sb.border_width_bottom = 5
			var tw := create_tween()
			tw.tween_property(p, "scale", Vector2(1.09, 1.09), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			p.z_index = 2
		else:
			p.modulate = Color(0.62, 0.62, 0.62, 0.75)
			sb.border_color = Color(0.45, 0.38, 0.26)
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3
			var tw2 := create_tween()
			tw2.tween_property(p, "scale", Vector2.ONE, 0.12)
			p.z_index = 0

func lock_card(idx: int) -> void:
	# pop the chosen card, then ALL cards leave the stage — the choice gets
	# restated by the mode panels / resolution banners
	for i in _card_panels.size():
		var p: Panel = _card_panels[i]
		var tw := create_tween()
		if i == idx:
			tw.tween_property(p, "scale", Vector2(1.16, 1.16), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 0.0, 0.22).set_delay(0.2)
		else:
			tw.tween_property(p, "modulate:a", 0.0, 0.18)

func set_world_peek(v: bool) -> void:
	if _peek == v:
		return
	_peek = v
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.30 if v else 0.68, 0.3)
	tw.tween_property(_vig, "modulate:a", 0.45 if v else 1.0, 0.3)

func show_target_prompt(kind: String) -> void:
	_cards_box.visible = true
	set_world_peek(true)
	var tw := create_tween()
	tw.tween_property(_cards_box, "modulate:a", 0.0, 0.25)
	_prompt.visible = true
	_target_label.visible = true
	_mode_box.visible = false
	if kind == "bless":
		_prompt.text = "✦ BLESS WHOM?"
		_prompt.add_theme_color_override("font_color", GOLD)
	else:
		_prompt.text = "☠ NOW... CURSE WHOM?"
		_prompt.add_theme_color_override("font_color", GREEN)
	_prompt.pivot_offset = Vector2(640, 36)
	_prompt.scale = Vector2(0.7, 0.7)
	var tw2 := create_tween()
	tw2.tween_property(_prompt, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_target_display(pname: String, color: Color) -> void:
	_target_label.text = "◄  %s  ►" % pname
	_target_label.add_theme_color_override("font_color", color)
	_target_label.pivot_offset = Vector2(640, 50)
	_target_label.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(_target_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_mode_choice(bless_title: String, curse_title: String, survivor_name: String, survivor_color: Color) -> void:
	set_world_peek(true)
	var tw := create_tween()
	tw.tween_property(_cards_box, "modulate:a", 0.0, 0.25)
	_prompt.visible = true
	_prompt.text = "ONE HEIR REMAINS: %s" % survivor_name
	_prompt.add_theme_color_override("font_color", survivor_color)
	_target_label.visible = false
	_mode_box.visible = true
	for c in _mode_panels:
		c.queue_free()
	_mode_panels.clear()
	var opts := [{"txt": "BLESS THEM", "sub": bless_title, "col": GOLD},
		{"txt": "CURSE THEM", "sub": curse_title, "col": GREEN}]
	for o in opts:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(260, 150)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.09, 0.08, 0.97)
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_width_top = 4
		sb.border_width_bottom = 4
		sb.border_color = Color(0.4, 0.35, 0.25)
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		p.add_theme_stylebox_override("panel", sb)
		p.pivot_offset = Vector2(130, 75)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var l1 := _mk_label(str(o.txt), F_LUCKIEST, 30, o.col)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l1)
		var l2 := _mk_label(str(o.sub), F_BALOO, 16, Color(0.75, 0.7, 0.6))
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l2)
		p.add_child(v)
		_mode_box.add_child(p)
		_mode_panels.append(p)

func set_mode_sel(idx: int) -> void:
	for i in _mode_panels.size():
		var p: Panel = _mode_panels[i]
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
		if i == idx:
			p.modulate = Color.WHITE
			sb.border_color = _dc
			var tw := create_tween()
			tw.tween_property(p, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			p.modulate = Color(0.6, 0.6, 0.6, 0.8)
			sb.border_color = Color(0.4, 0.35, 0.25)
			var tw2 := create_tween()
			tw2.tween_property(p, "scale", Vector2.ONE, 0.12)

func show_resolution(lines: Array) -> void:
	## lines: [{text, color, delay}]
	_prompt.visible = false
	_target_label.visible = false
	_mode_box.visible = false
	_set_timer_visible(false)
	set_world_peek(true)
	var tw0 := create_tween()
	tw0.tween_property(_cards_box, "modulate:a", 0.0, 0.2)
	for c in _res_lines.get_children():
		c.queue_free()
	_res_lines.visible = true
	for ln in lines:
		var l := _mk_label(str(ln.text), F_LUCKIEST, 44, ln.color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		l.scale = Vector2(0.8, 0.8)
		l.pivot_offset = Vector2(640, 30)
		_res_lines.add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.16).set_delay(float(ln.delay))
		tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.2).set_delay(float(ln.delay)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func flash_no_heirs(pname: String, color: Color) -> void:
	open(pname, color, "")
	_subtitle.text = "NO HEIRS REMAIN — THE ESTATE PASSES TO THE VOID"

func set_timer(frac: float, secs: float) -> void:
	_timer_fill.size.x = 432.0 * clampf(frac, 0.0, 1.0)
	_timer_fill.color = _dc if frac > 0.33 else Color(1.0, 0.3, 0.2)
	_timer_label.text = str(int(ceil(secs)))
	_timer_label.add_theme_color_override("font_color", Color.WHITE if frac > 0.33 else Color(1.0, 0.45, 0.35))

func _set_timer_visible(v: bool) -> void:
	_timer_bg.visible = v
	_timer_label.visible = v

func close() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.32)
	tw.tween_callback(func():
		visible = false
		_peek = false
		_root.modulate.a = 1.0
		_dim.color.a = 0.0
		_vig.modulate.a = 0.0
		_res_lines.visible = false
		if _portrait_model != null:
			_portrait_model.queue_free()
			_portrait_model = null
	)

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_t += delta
	var pulse := 0.62 + 0.38 * sin(_pulse_t * 3.4)
	for b in _edges:
		(b as ColorRect).color = Color(_dc.r, _dc.g, _dc.b, 0.85 * pulse + 0.1)
	for s in _edges_soft:
		(s as ColorRect).color = Color(_dc.r, _dc.g, _dc.b, 0.16 * pulse)
	if _portrait_spin != null:
		_portrait_spin.rotation.y = sin(_pulse_t * 0.7) * 0.5
