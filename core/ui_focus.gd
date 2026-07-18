class_name UiFocus
extends Object
## GAMEPAD EVERYWHERE (L1) — shared focus plumbing for the estate's mouse-first
## menus. Godot's UI navigation (ui_up/down/left/right + ui_accept) only drives a
## menu once SOME Control holds focus; a panel built for the mouse that never
## calls grab_focus is dead to a gamepad even with the input map fixed. Every menu
## that wants pad play routes its buttons through here on (re)build:
##   UiFocus.grab_first(container)
## which wires a subtle, house-styled focus lift on each button and parks the
## focus cursor on the first enabled one — unless a valid focus already lives
## inside the container (so a rebuild mid-navigation, or a mouse user, is not
## yanked back to the top).
##
## The lift matches the title door (core/frontend_director.gd _on_btn_focus): a
## small centered grow + a warm parchment-gold tint. Scale is a render transform,
## so a focused button never reflows its row — neighbours stay put.

const _LIFT_SCALE := Vector2(1.05, 1.05)
const _LIFT_TINT := Color(1.08, 1.06, 0.98)
# House gold (the title door's focus ring, frontend_director / estate _style_title_button).
const _RING_GOLD := Color(1.0, 0.86, 0.45, 1.0)

## A gold hairline ring drawn ONLY on the focus state (draw_center off), so it
## rides on top of a button's own skin — the green pill keeps its look and the
## focused one gains an unmistakable gold outline. High corner radius hugs the
## pill; the expand margins sit the ring just outside the button edge.
static func _focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(3)
	sb.border_color = _RING_GOLD
	sb.set_corner_radius_all(24)
	sb.expand_margin_left = 4.0
	sb.expand_margin_right = 4.0
	sb.expand_margin_top = 4.0
	sb.expand_margin_bottom = 4.0
	return sb

## Wire the focus lift + gold ring on every Button under `root` (idempotent via a
## node meta flag) and return them in tree order.
static func wire(root: Node) -> Array:
	var btns: Array = root.find_children("*", "Button", true, false)
	for b in btns:
		var btn := b as Button
		if btn.focus_mode == Control.FOCUS_NONE:
			btn.focus_mode = Control.FOCUS_ALL
		if btn.has_meta("uifocus_wired"):
			continue
		btn.set_meta("uifocus_wired", true)
		# A button that already dresses its own focus (the title door) keeps it;
		# everything else gets the shared gold ring so pad focus is legible.
		if not btn.has_theme_stylebox_override("focus"):
			btn.add_theme_stylebox_override("focus", _focus_ring())
		btn.focus_entered.connect(_lift.bind(btn))
		btn.focus_exited.connect(_drop.bind(btn))
		# A lift left on-screen when the mouse presses the button (which does not
		# fire focus_exited) would freeze the grow; clear it on the click path too.
		btn.mouse_exited.connect(_drop.bind(btn))
	return btns

## Park focus on the first enabled, visible button under `root`. No-op (keeps the
## current cursor) when focus already sits on a live control inside `root`.
static func grab_first(root: Node) -> void:
	if root == null or not (root is Node) or not (root as Node).is_inside_tree():
		return
	var btns := wire(root)
	var vp := (root as Node).get_viewport()
	if vp != null:
		var owner := vp.gui_get_focus_owner()
		if owner != null and is_instance_valid(owner) and root.is_ancestor_of(owner):
			return
	for b in btns:
		var btn := b as Button
		if not btn.disabled and btn.is_visible_in_tree():
			btn.grab_focus()
			return

static func _lift(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	btn.scale = _LIFT_SCALE
	btn.modulate = _LIFT_TINT

static func _drop(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	if btn.has_focus():
		return   # mouse left but the pad cursor is still here — keep the lift
	btn.scale = Vector2.ONE
	btn.modulate = Color.WHITE
