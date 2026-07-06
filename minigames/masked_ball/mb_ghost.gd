class_name MBGhost
extends Node3D
## Spectator wisp for an unmasked dancer. Dead players are already REVEALED,
## so color + glyph + name are correct here (house rule: nobody watches dead
## air — the ghost drifts above the ball and can GUST the crowd, a visual
## shiver that muddies the floor for the living; pure mischief, never logic).
## Purely presentational: masked_ball.gd owns the ghost's position and gust
## cooldown; this node just renders them.

var _mat: StandardMaterial3D
var _light: OmniLight3D
var _t := 0.0

func setup(p_color: Color, tag_text: String) -> void:
	var wisp := MeshInstance3D.new()
	var wm := SphereMesh.new()
	wm.radius = 0.26
	wm.height = 0.62
	wisp.mesh = wm
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(p_color.r, p_color.g, p_color.b, 0.5)
	_mat.emission_enabled = true
	_mat.emission = p_color
	_mat.emission_energy_multiplier = 1.1
	wisp.material_override = _mat
	add_child(wisp)
	# little tail
	var tail := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.13
	tm.height = 0.4
	tail.mesh = tm
	tail.material_override = _mat
	tail.position = Vector3(0, -0.38, 0)
	add_child(tail)
	_light = OmniLight3D.new()
	_light.light_color = p_color
	_light.light_energy = 0.5
	_light.omni_range = 3.0
	add_child(_light)
	var tag := Label3D.new()
	tag.text = tag_text
	tag.font_size = 34
	tag.pixel_size = 0.005
	tag.modulate = p_color
	tag.outline_size = 9
	tag.outline_modulate = Color(0.05, 0.04, 0.07)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 0.62, 0)
	add_child(tag)

## Gust ripple — an expanding ring under the wisp.
func gust_fx() -> void:
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.3
	rm.outer_radius = 0.38
	ring.mesh = rm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(_mat.emission.r, _mat.emission.g, _mat.emission.b, 0.6)
	ring.material_override = m
	ring.position = Vector3(0, -1.6, 0)
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(5.2, 1.0, 5.2), 0.7)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(ring.queue_free)

func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = 0.45 + 0.15 * sin(_t * 3.1)
	_mat.emission_energy_multiplier = 1.0 + 0.25 * sin(_t * 2.3)
