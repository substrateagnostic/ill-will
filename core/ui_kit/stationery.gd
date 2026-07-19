class_name Stationery
extends Object
## M2 — THE HOUSE STATIONERY, as one shared UI kit. The title door (estate.gd
## _style_title_button / _title_btn_box, the D1 facelift) is the house look:
## near-black ink panels, a thin gold hairline, parchment-ivory text set in IM
## Fell English, and a full-gold focus lift for couch-distance gamepad play. The
## anthology's front-of-house menus (PLAY, SETTINGS/SEATS, MINIGAMES, WARDROBE,
## HOST/JOIN NIGHT, the lobby) previously wore the old bright-green pill theme
## (assets/ui/theme.tres) and clashed with that door. This kit is the ONE place
## the stationery is defined; every menu applies it so the whole front end speaks
## the house's single gothic voice.
##
## Scope is MENUS ONLY. In-game HUDs (HudStrip, IntroCard, ResultsBoard, per-game
## bars) keep their own skins — do not route them through here.
##
## Seat-color accents (player name labels, PlayerBadge, seat swatches) are left
## untouched: this styles Buttons/OptionButtons and panel backgrounds, never the
## per-player identity Labels.
##
## Usage:
##   Stationery.button(btn)             # one button
##   Stationery.apply_tree(container)   # every Button/OptionButton under a panel
##   Stationery.panel(panel_container)  # a PanelContainer's ink background
##
## The gold focus box set here matches core/ui_focus.gd's L1 ring, so a button
## styled by this kit keeps an unmistakable gold focus outline; UiFocus.wire()
## still adds its grow+tint lift on top (it only skips its own ring when a focus
## override already exists, which this provides).

const FONT_IMFELL := "res://assets/fonts/IMFellEnglish-Regular.ttf"

# The exact stationery palette lifted from estate.gd _style_title_button (D1).
const INK_NORMAL := Color(0.05, 0.045, 0.07, 0.92)
const INK_HOVER := Color(0.10, 0.09, 0.12, 0.96)
const INK_PRESSED := Color(0.03, 0.028, 0.045, 0.96)
const INK_DISABLED := Color(0.04, 0.038, 0.055, 0.80)
const RULE_NORMAL := Color(0.60, 0.50, 0.30, 0.85)   # gold hairline
const RULE_HOVER := Color(0.85, 0.70, 0.40, 1.0)
const RULE_PRESSED := Color(0.72, 0.60, 0.34, 1.0)
const RULE_DISABLED := Color(0.40, 0.35, 0.24, 0.55)
const FOCUS_FILL := Color(0.85, 0.70, 0.35, 0.14)
const FOCUS_RULE := Color(1.0, 0.86, 0.45, 1.0)      # == UiFocus._RING_GOLD

const TEXT_NORMAL := Color(0.90, 0.86, 0.76)
const TEXT_HOVER := Color(1.0, 0.95, 0.82)
const TEXT_PRESSED := Color(0.86, 0.80, 0.64)
const TEXT_DISABLED := Color(0.55, 0.52, 0.46)

# The panel register: the Executor's event-card ink (procession _lowerthird_box),
# a shade darker than a button so buttons read as raised plates on it.
const PANEL_INK := Color(0.035, 0.03, 0.05, 0.94)
const PANEL_RULE := Color(0.52, 0.44, 0.27, 0.70)

## One stationery button box: ink fill + a gold hairline, gently rounded corners
## and the same content margins as the title door.
static func box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 10.0
	return sb

## Dress one Button (or OptionButton, CheckButton, MenuButton — anything deriving
## Button) in the house stationery. Idempotent via a node meta flag. Preserves an
## explicitly seat-accented button (meta "stationery_skip") untouched.
static func button(btn: Button) -> void:
	if btn == null or btn.has_meta("stationery_wired") or btn.has_meta("stationery_skip"):
		return
	btn.set_meta("stationery_wired", true)
	var serif: Font = _font()
	if serif != null:
		btn.add_theme_font_override("font", serif)
	btn.add_theme_stylebox_override("normal", box(INK_NORMAL, RULE_NORMAL, 2))
	btn.add_theme_stylebox_override("hover", box(INK_HOVER, RULE_HOVER, 2))
	btn.add_theme_stylebox_override("pressed", box(INK_PRESSED, RULE_PRESSED, 2))
	btn.add_theme_stylebox_override("disabled", box(INK_DISABLED, RULE_DISABLED, 2))
	var foc := box(FOCUS_FILL, FOCUS_RULE, 3)
	foc.expand_margin_left = 3.0
	foc.expand_margin_right = 3.0
	foc.expand_margin_top = 3.0
	foc.expand_margin_bottom = 3.0
	btn.add_theme_stylebox_override("focus", foc)
	btn.add_theme_color_override("font_color", TEXT_NORMAL)
	btn.add_theme_color_override("font_hover_color", TEXT_HOVER)
	btn.add_theme_color_override("font_focus_color", TEXT_HOVER)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRESSED)
	btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	# OptionButton draws a popup + arrow; keep its popup readable on ink.
	if btn is OptionButton:
		var pop := (btn as OptionButton).get_popup()
		pop.add_theme_color_override("font_color", TEXT_NORMAL)
		pop.add_theme_color_override("font_hover_color", TEXT_HOVER)

## Give a PanelContainer (or Panel) the stationery ink background + gold hairline.
static func panel(node: Control) -> void:
	if node == null or node.has_meta("stationery_wired"):
		return
	node.set_meta("stationery_wired", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_INK
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_RULE
	sb.set_content_margin_all(16.0)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	node.add_theme_stylebox_override("panel", sb)

## Walk a subtree and dress every Button/OptionButton in it. Seat-accented
## elements are Labels/PlayerBadges (never Buttons) and so are left alone; a
## button that must keep a per-player color can opt out with meta "stationery_skip".
static func apply_tree(root: Node) -> void:
	if root == null:
		return
	for b in root.find_children("*", "Button", true, false):
		button(b as Button)

static func _font() -> Font:
	if ResourceLoader.exists(FONT_IMFELL):
		return load(FONT_IMFELL)
	return null
