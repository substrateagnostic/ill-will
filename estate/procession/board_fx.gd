class_name ProcessionFx
extends Node
## Reusable UI-space presentation helpers for THE PROCESSION (doc 24 F10/F11/F17):
## flying attributed value popups and the wax-seal Deed token. Everything lives on
## a full-rect Control over the HUD and projects a 3D source point to screen via
## the live camera, so a gain/loss physically travels from the stone that caused
## it to the owner's HUD chip.
##
## PRESENTATION ONLY. Jitter draws from a PRIVATE RandomNumberGenerator seeded
## from the wall clock — never the sim rng — and every entry point no-ops under
## fast, so the headless receipt renders and perturbs nothing.

const RISE := 64.0                # how far a popup lifts before homing to the chip
const NUM_DUR := 0.85
const DEED_DUR := 0.95

var host: Control = null
var cam: Camera3D = null
var fast := false
var _rng := RandomNumberGenerator.new()

func setup(host_control: Control, camera: Camera3D, is_fast: bool) -> void:
	host = host_control
	cam = camera
	fast = is_fast
	_rng.seed = int(Time.get_ticks_usec())

## Project a world point to screen space (viewport pixels == host-local, host is
## full-rect). Falls back to screen centre if the point is off-camera.
func _screen_of(world: Vector3) -> Vector2:
	if not is_instance_valid(cam) or host == null:
		return host.size * 0.5 if host else Vector2.ZERO
	if cam.is_position_behind(world):
		return host.size * 0.5
	return cam.unproject_position(world)

## A flying attributed value popup (F10/F11): spawns at `world_from`, arcs up and
## over to `screen_to` (the owner's chip), fades out on arrival. The glyph + sign
## carry the meaning so it is never colour alone.
func fly_number(amount: int, glyph: String, world_from: Vector3, screen_to: Vector2, color: Color) -> void:
	if fast or host == null or amount == 0:
		return
	var from := _screen_of(world_from)
	var lbl := Label.new()
	var sign_s := "+" if amount > 0 else "−"
	lbl.text = "%s%d%s" % [sign_s, absi(amount), glyph]
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.25))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.z_index = 20
	host.add_child(lbl)
	lbl.pivot_offset = Vector2(20, 20)
	lbl.position = from
	lbl.scale = Vector2(0.4, 0.4)
	var lift := from + Vector2(_rng.randf_range(-26.0, 26.0), -RISE)
	var tw := lbl.create_tween()
	# pop in
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# lift, then home to the chip along a two-segment arc
	tw.tween_property(lbl, "position", lift, 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", screen_to, NUM_DUR) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(lbl, "scale", Vector2(0.55, 0.55), NUM_DUR)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, NUM_DUR).set_delay(NUM_DUR * 0.45)
	tw.tween_callback(lbl.queue_free)

## The wax-sealed Deed (F17): a parchment scroll with a red seal rises from the
## pedestal and flies to the buyer's chip, shrinking, with a stamp-thud on lift.
func fly_deed(world_from: Vector3, screen_to: Vector2, color: Color) -> void:
	if fast or host == null:
		return
	var from := _screen_of(world_from)
	var token := _make_deed_token(color)
	host.add_child(token)
	token.pivot_offset = token.custom_minimum_size * 0.5
	token.position = from - token.custom_minimum_size * 0.5
	token.scale = Vector2(0.2, 0.2)
	token.z_index = 24
	Sfx.play("sink", -3.0)   # the stamp-thud of the seal
	var apex := from + Vector2(0.0, -RISE * 1.4)
	var tw := token.create_tween()
	tw.tween_property(token, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(token, "position", apex - token.custom_minimum_size * 0.5, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(token, "position", screen_to - token.custom_minimum_size * 0.25, DEED_DUR) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(token, "scale", Vector2(0.4, 0.4), DEED_DUR)
	tw.parallel().tween_property(token, "modulate:a", 0.0, DEED_DUR).set_delay(DEED_DUR * 0.55)
	tw.tween_callback(token.queue_free)

## A small parchment card with a red wax seal and the Deed diamond — the token
## that flies to the buyer. Colour-keyed border carries the owner's identity.
func _make_deed_token(color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 84)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.86, 0.70)          # parchment
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = color
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "◆ DEED"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.06, 0.06))
	panel.add_child(lbl)
	# the wax seal — a red disc pinned to the lower-right corner
	var seal := Panel.new()
	seal.custom_minimum_size = Vector2(30, 30)
	seal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	seal.offset_left = -34; seal.offset_top = -34
	seal.offset_right = -4; seal.offset_bottom = -4
	var seal_sb := StyleBoxFlat.new()
	seal_sb.bg_color = Color(0.62, 0.09, 0.10)
	seal_sb.set_corner_radius_all(16)
	seal_sb.set_border_width_all(2)
	seal_sb.border_color = Color(0.85, 0.2, 0.2)
	seal.add_theme_stylebox_override("panel", seal_sb)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(seal)
	return panel
