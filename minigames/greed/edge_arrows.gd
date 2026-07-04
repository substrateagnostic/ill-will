class_name GreedEdgeArrows
extends Control
## Screen-edge chevrons that all point at the CARRIER — the "everyone is
## looking at you" feel target. One arrow per non-carrier player, in that
## player's color, pinned to the screen border on the bearing to the carrier
## and rotated to point at them. Redrawn every frame from the controller.

var carrier_screen := Vector2.ZERO
var carrier_active := false
var arrows: Array = []                  # [{color: Color}] per non-carrier
var _pulse := 0.0

const MARGIN := 54.0
const SIZE := 34.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func update_arrows(active: bool, screen_pos: Vector2, list: Array, t: float) -> void:
	carrier_active = active
	carrier_screen = screen_pos
	arrows = list
	_pulse = t
	queue_redraw()


func _draw() -> void:
	if not carrier_active or arrows.is_empty():
		return
	# use the true viewport size — a CanvasLayer Control's own `size` can lag a
	# layout pass and collapse the arrows to the origin
	var vp := get_viewport_rect().size
	var center := vp * 0.5
	var beat := 1.0 + 0.15 * sin(_pulse * 8.0)
	var dir := carrier_screen - center
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var edge := _edge_point(center, dir, vp)
	for i in arrows.size():
		var entry: Dictionary = arrows[i]
		var col: Color = entry["color"]
		var spread := (float(i) - (arrows.size() - 1) * 0.5) * (SIZE * 1.7)
		var pos := edge + perp * spread
		pos.x = clampf(pos.x, MARGIN, vp.x - MARGIN)
		pos.y = clampf(pos.y, MARGIN, vp.y - MARGIN)
		_draw_chevron(pos, dir, col, beat)


## Point where the ray from center along dir hits the inset screen rectangle.
func _edge_point(center: Vector2, dir: Vector2, vp: Vector2) -> Vector2:
	var hx := vp.x * 0.5 - MARGIN
	var hy := vp.y * 0.5 - MARGIN
	var tx := hx / maxf(absf(dir.x), 0.0001)
	var ty := hy / maxf(absf(dir.y), 0.0001)
	var tt := minf(tx, ty)
	return center + dir * tt


func _draw_chevron(pos: Vector2, dir: Vector2, col: Color, beat: float) -> void:
	var s := SIZE * beat
	var perp := Vector2(-dir.y, dir.x)
	var tip := pos + dir * s
	var l := pos - dir * (s * 0.35) + perp * (s * 0.95)
	var r := pos - dir * (s * 0.35) - perp * (s * 0.95)
	# dark drop-shadow for punch, then the colored fill, then a bright core
	var sh := PackedVector2Array([tip + dir * 4.0 + Vector2(2, 2),
		l + Vector2(2, 2), r + Vector2(2, 2)])
	draw_colored_polygon(sh, Color(0.05, 0.03, 0.0, 0.85))
	draw_colored_polygon(PackedVector2Array([tip, l, r]), col)
	var ctip := pos + dir * (s * 0.55)
	var cl := pos - dir * (s * 0.05) + perp * (s * 0.5)
	var cr := pos - dir * (s * 0.05) - perp * (s * 0.5)
	draw_colored_polygon(PackedVector2Array([ctip, cl, cr]), col.lightened(0.45))
