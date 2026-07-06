class_name LWRaceHud
extends Control
## Race HUD: a PROCESSION TRACK across the top (chapel -> crypt, checkpoint
## ticks, one PlayerBadge per racer gliding along it) + a lives panel on the
## right (badge, name, three vector hearts). Identity is never color alone:
## the badges are the ● ▲ ■ ◆ shapes, and hearts sit beside them.

const F_BALOO := preload("res://assets/fonts/Baloo2.ttf")

const TRACK_X := 250.0
const TRACK_W := 780.0
const TRACK_Y := 84.0

var _players: Array = []       # live refs to the controller's player dicts
var _badges: Array = []        # PlayerBadge per player, riding the track
var _rows: Array = []          # {badge, label, hearts}
var _fracs: Array = []         # smoothed track fractions

class Hearts:
	extends Control
	var max_lives := 3
	var lives := 3
	var color := Color.WHITE
	func _init() -> void:
		custom_minimum_size = Vector2(66, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_state(n: int, c: Color) -> void:
		if n == lives and c == color:
			return
		lives = n
		color = c
		queue_redraw()
	func _draw() -> void:
		for i in max_lives:
			var cx := 11.0 + float(i) * 22.0
			var filled := i < lives
			_draw_heart(Vector2(cx, 10.0), 8.0,
				color if filled else Color(0.2, 0.18, 0.22, 0.9),
				filled)
	func _draw_heart(c: Vector2, s: float, col: Color, filled: bool) -> void:
		var outline := Color(0.06, 0.05, 0.08)
		# two lobes + point, drawn as circles over a triangle
		var tri := PackedVector2Array([
			c + Vector2(-s * 0.92, -s * 0.18),
			c + Vector2(s * 0.92, -s * 0.18),
			c + Vector2(0, s * 0.95),
		])
		draw_colored_polygon(tri, col)
		draw_circle(c + Vector2(-s * 0.45, -s * 0.3), s * 0.52, col)
		draw_circle(c + Vector2(s * 0.45, -s * 0.3), s * 0.52, col)
		if not filled:
			# hollow read for spent hearts: a dim pip in the middle
			draw_circle(c + Vector2(0, s * 0.05), s * 0.18, outline)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func build(players: Array) -> void:
	_players = players
	for b in _badges:
		b.queue_free()
	_badges.clear()
	_fracs.clear()
	for r in _rows:
		r.box.queue_free()
	_rows.clear()
	for i in players.size():
		var badge := PlayerBadge.make(int(players[i].index), 22)
		badge.color = players[i].color
		add_child(badge)
		_badges.append(badge)
		_fracs.append(0.0)
	# lives panel, top right
	var panel := PanelContainer.new()
	panel.position = Vector2(1060, 14)
	panel.size = Vector2(206, 30 + 30 * players.size())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	for i in players.size():
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge := PlayerBadge.make(int(players[i].index), 20)
		badge.color = players[i].color
		hb.add_child(badge)
		var nm := Label.new()
		nm.text = str(players[i].name)
		nm.add_theme_font_override("font", F_BALOO)
		nm.add_theme_font_size_override("font_size", 18)
		nm.add_theme_color_override("font_color", players[i].color)
		nm.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.1))
		nm.add_theme_constant_override("outline_size", 5)
		nm.custom_minimum_size = Vector2(58, 0)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(nm)
		var hearts := Hearts.new()
		hb.add_child(hearts)
		v.add_child(hb)
		_rows.append({"box": hb, "badge": badge, "label": nm, "hearts": hearts})
	queue_redraw()

## fracs: 0..1 course progress per player. ghosts: dim + hearts empty.
func refresh(delta: float) -> void:
	if _players.is_empty():
		return
	for i in _players.size():
		var p: Dictionary = _players[i]
		var frac := clampf(float(p.get("best_x", 0.0)) / LWCourse.FINISH_X, 0.0, 1.0)
		if bool(p.get("finished", false)):
			frac = 1.0
		_fracs[i] = lerpf(_fracs[i], frac, 1.0 - exp(-8.0 * delta))
		var badge: PlayerBadge = _badges[i]
		badge.position = Vector2(TRACK_X + TRACK_W * _fracs[i] - 11.0,
			TRACK_Y - 26.0 - float(i % 2) * 16.0)
		badge.dim = 1.0 if int(p.lives) > 0 or bool(p.get("finished", false)) else 0.4
		if i < _rows.size():
			var row: Dictionary = _rows[i]
			(row.hearts as Hearts).set_state(int(p.lives), p.color)
			(row.badge as PlayerBadge).dim = 1.0 if int(p.lives) > 0 else 0.4
			if int(row.get("last_total", -1)) != int(p.total):
				row["last_total"] = int(p.total)
				(row.label as Label).text = "%s %d" % [str(p.name), int(p.total)]

func _draw() -> void:
	# track bed
	var y := TRACK_Y
	draw_line(Vector2(TRACK_X - 6, y), Vector2(TRACK_X + TRACK_W + 6, y), Color(0.07, 0.06, 0.1, 0.85), 10.0)
	draw_line(Vector2(TRACK_X, y), Vector2(TRACK_X + TRACK_W, y), Color(0.45, 0.42, 0.52, 0.9), 4.0)
	# checkpoint ticks
	for cp in LWCourse.CHECKPOINTS:
		var fx := TRACK_X + TRACK_W * clampf(float(cp) / LWCourse.FINISH_X, 0.0, 1.0)
		draw_line(Vector2(fx, y - 8), Vector2(fx, y + 8), Color(0.8, 0.78, 0.9, 0.9), 3.0)
	# the crypt: a little arch at the finish
	var cx := TRACK_X + TRACK_W
	var gold := Color(1.0, 0.83, 0.4)
	draw_rect(Rect2(cx - 3, y - 16, 6, 16), gold)
	draw_rect(Rect2(cx - 10, y - 16, 20, 4), gold)
	draw_arc(Vector2(cx, y - 14), 9.0, PI, TAU, 16, gold, 3.0)
