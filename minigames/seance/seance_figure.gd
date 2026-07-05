class_name SeanceFigure
extends Node3D
## A séance sitter: KayKit body standing at the table, one hand over the
## board, holding a lit taper candle. The candle is the player's public
## "hand" — it FLARES on every chant tap (A), which is the round's designed
## behavioral tell: anyone can watch one suspect's rhythm, nobody can watch
## all four (deniability by parallelism, per the research doc).
##
## Steering is deliberately NOT visualized per player — like a real Ouija
## planchette, four hands share one motion and observers cannot decompose
## the forces. Only taps (candle flare) and anonymous surges (ripple on the
## planchette itself) are visible.

var index := 0
var player_color := Color.WHITE
var anim: AnimationPlayer

var _model_pivot: Node3D
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _flare_light: OmniLight3D
var _flare_t := 0.0
var _cur_anim := ""
var _anim_lock := 0.0
var _sway_seed := 0.0

func setup(p_index: int, p_color: Color, p_name: String, char_scene: PackedScene) -> void:
	index = p_index
	player_color = p_color
	_sway_seed = float(p_index) * 1.7

	_model_pivot = Node3D.new()
	_model_pivot.name = "ModelPivot"
	add_child(_model_pivot)
	if char_scene != null:
		var body := char_scene.instantiate()
		body.scale = Vector3(0.92, 0.92, 0.92)
		_model_pivot.add_child(body)
		anim = body.find_child("AnimationPlayer", true, false)
		_tint_model(body)
		_loop("Idle")
		_set_anim("Idle")

	# identity ring on the stage floor
	var ring := MeshInstance3D.new()
	var rmesh := CylinderMesh.new()
	rmesh.top_radius = 0.44
	rmesh.bottom_radius = 0.48
	rmesh.height = 0.03
	ring.mesh = rmesh
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = p_color
	rmat.emission_enabled = true
	rmat.emission = p_color
	rmat.emission_energy_multiplier = 0.55
	ring.material_override = rmat
	ring.position.y = 0.02
	add_child(ring)

	# name tag: glyph + name (never color alone)
	var tag := Label3D.new()
	tag.text = PlayerBadge.glyph(p_index) + " " + p_name
	tag.font_size = 44
	tag.pixel_size = 0.0055
	tag.modulate = p_color
	tag.outline_size = 11
	tag.outline_modulate = Color(0.05, 0.04, 0.07)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.25, 0)
	add_child(tag)

	_build_candle()

func _build_candle() -> void:
	# a taper held out in front of the sitter, over the table edge
	var candle := Node3D.new()
	candle.name = "Candle"
	candle.position = Vector3(0.28, 1.05, -0.52)   # local: forward is -Z
	add_child(candle)
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.035
	sm.bottom_radius = 0.045
	sm.height = 0.24
	stick.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.92, 0.88, 0.78)
	smat.roughness = 0.7
	stick.material_override = smat
	candle.add_child(stick)
	_flame = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.13
	_flame.mesh = fm
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_mat.albedo_color = Color(1.0, 0.82, 0.45, 0.92)
	_flame_mat.emission_enabled = true
	_flame_mat.emission = Color(1.0, 0.68, 0.3)
	_flame_mat.emission_energy_multiplier = 1.4
	_flame.material_override = _flame_mat
	_flame.position.y = 0.19
	candle.add_child(_flame)
	_flare_light = OmniLight3D.new()
	_flare_light.light_color = Color(1.0, 0.75, 0.42)
	_flare_light.light_energy = 0.0
	_flare_light.omni_range = 2.6
	_flare_light.position.y = 0.24
	candle.add_child(_flare_light)

## Chant tap: the candle jumps. Identical visual for on-beat and off-beat —
## observers must judge the TIMING themselves. That is the game.
func flare() -> void:
	_flare_t = 0.22

func set_flame_lit(v: bool) -> void:
	_flame.visible = v

func _tint_model(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = _rim_material()
	for c in node.get_children():
		_tint_model(c)

func _rim_material() -> StandardMaterial3D:
	# whisper of identity color; KayKit texture stays readable (house style).
	# NOTE: this room is nearly black, so emissive overlays read 4x hotter
	# than in daylight games — keep these numbers tiny or the sitters turn
	# into lava lamps (verified by screenshot, first pass did exactly that).
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(player_color.r, player_color.g, player_color.b, 0.05)
	m.emission_enabled = true
	m.emission = player_color
	m.emission_energy_multiplier = 0.025
	m.rim_enabled = true
	m.rim = 0.8
	return m

func _loop(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func _set_anim(n: String) -> void:
	if anim == null or _cur_anim == n or not anim.has_animation(n):
		return
	_cur_anim = n
	anim.play(n)

## One-shot reaction with a lock so ambient sway doesn't stomp it.
func play_reaction(n: String, lock: float) -> void:
	if anim == null or not anim.has_animation(n):
		return
	_cur_anim = n
	anim.play(n)
	_anim_lock = lock

## Reveal theater.
func react_unmasked_caught() -> void:
	play_reaction("Death_A", 9.0)

func react_cheer() -> void:
	_loop("Cheer")
	play_reaction("Cheer", 9.0)

func _process(delta: float) -> void:
	if _anim_lock > 0.0:
		_anim_lock -= delta
		if _anim_lock <= 0.0:
			_set_anim("Idle")
	# candle flare decay
	if _flare_t > 0.0:
		_flare_t = maxf(0.0, _flare_t - delta)
		var k := _flare_t / 0.22
		_flare_light.light_energy = 1.5 * k
		_flame_mat.emission_energy_multiplier = 1.4 + 2.4 * k
		var s := 1.0 + 0.55 * k
		_flame.scale = Vector3(s, s, s)
	else:
		_flare_light.light_energy = 0.0
		# idle flicker
		var f := 1.0 + 0.07 * sin(Time.get_ticks_msec() * 0.011 + _sway_seed * 9.0)
		_flame.scale = Vector3(f, f, f)
		_flame_mat.emission_energy_multiplier = 1.3 + 0.25 * sin(Time.get_ticks_msec() * 0.007 + _sway_seed * 5.0)
	# ambient sway: sitters lean over the board, slow breathing motion
	if _anim_lock <= 0.0 and _model_pivot != null:
		_model_pivot.rotation.x = 0.06 + 0.02 * sin(Time.get_ticks_msec() * 0.00093 + _sway_seed)
