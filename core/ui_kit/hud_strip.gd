class_name HudStrip
extends Control
## Shared-camera player-order strip (doc 14 item 9 / §4.1). ILL WILL is NOT
## split-screen, so per-player status lives in ONE persistent strip along a
## screen edge in seat order (left->right, mirroring the lobby/port order), not
## four corner quadrants. Compact per-player chips: badge (shape+color, never
## color-alone) + name + live score/status. Pulse API for lead changes + a
## stinger hook.
##
## Text clears the 26px@1080p / scalable floor (doc 14 item 4); the anthology's
## global ui_scale (PartySetup -> content_scale_factor) scales it further.
##
## Usage:
##   var strip := HudStrip.make([
##       {player=0, name="RED",  color=col0},
##       {player=1, name="BLUE", color=col1},
##   ], {anchor="top", score_type=HudStrip.ScoreType.POINTS, y=72})
##   game_ui_canvaslayer.add_child(strip)
##   strip.set_score(0, 3, "x2 coins")
##   strip.pulse(1)                 # lead-change bump
##   strip.set_lead(1)              # crown + optional stinger

signal lead_changed(player: int)

enum ScoreType { POINTS, PERCENT, TIME, RAW }

const _FONT_BIG := "res://assets/fonts/LuckiestGuy-Regular.ttf"
const _FONT_BODY := "res://assets/fonts/Baloo2.ttf"

var score_type := ScoreType.POINTS
var score_prefix := ""
var stinger_hook: Callable = Callable()      ## optional: called(player) on set_lead

var _bar: HBoxContainer
var _chips: Dictionary = {}                  # player -> {box, score, status, crown, dim}
var _lead := -1
var _font_size := 26

## One-liner constructor. entries: [{player, name, color}].
## opts: anchor("top"|"bottom"), y(edge inset px), score_type, score_prefix,
##       font_size, badge_size.
static func make(entries: Array, opts: Dictionary = {}) -> HudStrip:
	var s := HudStrip.new()
	s.setup(entries, opts)
	return s

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(entries: Array, opts: Dictionary = {}) -> void:
	score_type = int(opts.get("score_type", ScoreType.POINTS))
	score_prefix = str(opts.get("score_prefix", ""))
	_font_size = int(opts.get("font_size", 26))     # doc 14 item 4 floor
	var badge_size := float(opts.get("badge_size", 26))
	var anchor := str(opts.get("anchor", "top"))
	var y := float(opts.get("y", 8.0))

	# span the full width; pin to the chosen edge
	anchor_left = 0.0
	anchor_right = 1.0
	if anchor == "bottom":
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_top = -(y + 52.0)
		offset_bottom = -y
	else:
		anchor_top = 0.0
		offset_top = y
		offset_bottom = y + 52.0

	for c in get_children():
		c.queue_free()
	_chips.clear()

	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 20)
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)

	for e in entries:
		_bar.add_child(_build_chip(e, badge_size))

func _build_chip(e: Dictionary, badge_size: float) -> Control:
	var player := int(e.get("player", 0))
	# NB: `.get(k, default)` evaluates `default` eagerly, and _color_for/_name_for
	# touch autoloads — guard with has() so they only run when actually needed.
	var col: Color = e["color"] if e.has("color") else _color_for(player)
	var nm: String = e["name"] if e.has("name") else _name_for(player)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.pivot_offset = Vector2(70, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.1, 0.55)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.border_color = Color(1, 0.86, 0.3)
	sb.set_border_width_all(0)   # leader gets a gold border (set_lead) — a
	                             # position+color cue that never duplicates a badge shape
	panel.add_theme_stylebox_override("panel", sb)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var badge := PlayerBadge.make(player, badge_size)
	badge.color = col
	box.add_child(badge)

	var name_lbl := _mk_label(_FONT_BODY, _font_size - 2, HORIZONTAL_ALIGNMENT_LEFT)
	name_lbl.text = nm
	name_lbl.add_theme_color_override("font_color", col)
	box.add_child(name_lbl)

	var score_lbl := _mk_label(_FONT_BIG, _font_size, HORIZONTAL_ALIGNMENT_RIGHT)
	score_lbl.text = score_prefix + _fmt(0.0)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(score_lbl)

	var status_lbl := _mk_label(_FONT_BODY, _font_size - 6, HORIZONTAL_ALIGNMENT_LEFT)
	status_lbl.text = ""
	status_lbl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.4))
	box.add_child(status_lbl)

	_chips[player] = {"panel": panel, "sb": sb, "score": score_lbl,
		"status": status_lbl, "badge": badge, "name": name_lbl, "color": col}
	return panel

## Update a chip's live score + optional trailing status ("x2 coins", "GULL",
## "SPUN!"). A dead/eliminated look comes free by passing dim=true.
func set_score(player: int, value, status := "", dim := false) -> void:
	if not _chips.has(player):
		return
	var chip: Dictionary = _chips[player]
	(chip.score as Label).text = score_prefix + _fmt(float(value))
	(chip.status as Label).text = status
	(chip.badge as PlayerBadge).dim = 0.4 if dim else 1.0
	(chip.name as Label).modulate.a = 0.55 if dim else 1.0
	(chip.score as Label).modulate.a = 0.55 if dim else 1.0

## Lead-change pulse: a quick scale/brightness bump on the chip. Layout-safe
## (Control.scale is visual — neighbours don't reflow).
func pulse(player: int) -> void:
	if not _chips.has(player) or not FinalStretch.motion_ok():
		return
	var panel: Control = _chips[player].panel
	panel.pivot_offset = panel.size * 0.5
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.16, 1.16), 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Mark the current leader: a gold border on the new leader's chip, cleared on
## the old, plus a pulse. Fires `lead_changed` + the stinger hook only on a change.
func set_lead(player: int) -> void:
	if player == _lead or not _chips.has(player):
		return
	if _lead >= 0 and _chips.has(_lead):
		(_chips[_lead].sb as StyleBoxFlat).set_border_width_all(0)
	_lead = player
	(_chips[player].sb as StyleBoxFlat).set_border_width_all(3)
	pulse(player)
	lead_changed.emit(player)
	if stinger_hook.is_valid():
		stinger_hook.call(player)

func _fmt(v: float) -> String:
	match score_type:
		ScoreType.PERCENT:
			return "%d%%" % int(round(v))
		ScoreType.TIME:
			if v >= 60.0:
				return "%d:%02d" % [int(v) / 60, int(v) % 60]
			return "%.1f" % v
		ScoreType.RAW:
			return "%.0f" % v
		_:
			return str(int(round(v)))

func _mk_label(font_path: String, size: int, halign: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = halign
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Tree-independent autoload lookup (the PlayerBadge pattern) — safe to call
## before this node is added to the scene tree (e.g. from the make() constructor).
func _gamestate() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root.has_node("GameState"):
		return (ml as SceneTree).root.get_node("GameState")
	return null

func _color_for(player: int) -> Color:
	var gs := _gamestate()
	if gs != null and player >= 0 and player < gs.PLAYER_COLORS.size():
		return gs.PLAYER_COLORS[player]
	return PlayerBadge.DEFAULT_COLORS[player % PlayerBadge.DEFAULT_COLORS.size()]

func _name_for(player: int) -> String:
	var gs := _gamestate()
	if gs != null and player >= 0 and player < gs.PLAYER_NAMES.size():
		return str(gs.PLAYER_NAMES[player])
	return "P%d" % (player + 1)
