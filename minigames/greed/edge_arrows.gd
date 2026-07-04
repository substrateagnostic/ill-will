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

const MARGIN := 46.0
const SIZE := 26.0


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
	var vp := size
	var center := vp * 0.5
	var beat := 1.0 + 0.12 * sin(_pulse * 8.0)
	for i in arrows.size():
		var entry: Dictionary = arrows[i]
		var col: Color = entry["color"]
		# bearing from screen center to the carrier
		var dir := carrier_screen - center
		if dir.length() < 1.0:
			dir = Vector2(0, -1)
		dir = dir.normalized()
		# perpendicular fan-out so multiple arrows don't stack exactly
		var perp := Vector2(-dir.y, dir.x)
		var spread := (float(i) - (arrows.size() - 1) * 0.5) * (SIZE * 1.6)
		var edge := _edge_point(center, dir, vp)
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
	var l := pos - dir * (s * 0.4) + perp * (s * 0.85)
	var r := pos - dir * (s * 0.4) - perp * (s * 0.85)
	var pts := PackedVector2Array([tip, l, r])
	# dark outline for punch, then the colored fill
	var out := PackedVector2Array([
		tip + dir * 3.0,
		l + (l - pos).normalized() * 3.0,
		r + (r - pos).normalized() * 3.0,
	])
	draw_colored_polygon(out, Color(0.08, 0.05, 0.02, 0.9))
	draw_colored_polygon(pts, col)
