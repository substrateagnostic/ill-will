class_name OrbTrail
extends MeshInstance3D
## Fading ribbon trail for one dodgeball (ORBITAL DODGEBALL).
## The ball feeds add_point() every physics tick while flying; the world
## calls render() every visual frame. Points older than LIFE seconds
## evaporate, so a caught/rested ball's ribbon burns out on its own within
## 2 seconds. Color follows the ball's current owner - the late-game sky
## becomes a spirograph of everyone's old throws.

const LIFE := 2.0
const WIDTH := 0.2
const MAX_ALPHA := 0.9

var color := Color(0.9, 0.9, 0.92)

var _pts: Array = []  # [{ p: Vector3, t: float }]
var _im: ImmediateMesh

func _ready() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m

func add_point(p: Vector3, now: float) -> void:
	_pts.append({"p": p, "t": now})

func clear_points() -> void:
	_pts.clear()
	_im.clear_surfaces()

## Rebuild the camera-facing ribbon strip. Cheap: <= ~120 points per ball.
func render(now: float, cam_pos: Vector3) -> void:
	while _pts.size() > 0 and now - _pts[0].t > LIFE:
		_pts.pop_front()
	_im.clear_surfaces()
	if _pts.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _pts.size()
	for i in n:
		var p: Vector3 = _pts[i].p
		var age: float = now - _pts[i].t
		var k := clampf(1.0 - age / LIFE, 0.0, 1.0)
		var dir: Vector3
		if i < n - 1:
			dir = _pts[i + 1].p - p
		else:
			dir = p - _pts[i - 1].p
		if dir.length_squared() < 0.000001:
			dir = Vector3.UP
		var side := dir.cross(cam_pos - p)
		if side.length_squared() < 0.000001:
			side = Vector3.UP
		side = side.normalized() * (WIDTH * 0.5 * (0.35 + 0.65 * k))
		var c := Color(color.r, color.g, color.b, MAX_ALPHA * k * k)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p - side)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p + side)
	_im.surface_end()
