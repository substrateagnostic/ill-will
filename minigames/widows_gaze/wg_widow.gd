class_name WGWidow
extends Node3D
## THE WIDOW — the ghostly matriarch beside the coffin. On GREEN she weeps into
## the casket, back to the room; on the STING she WHIPS around and her eyes lamp
## on. Everything the room fears lives in this one node.
##
## Built from primitives + cloth-dark materials (a veiled mourning figure). She
## is a SINGLE scene node so a proper Meshy widow can replace her later in one
## line: drop a model at WIDOW_GLB and _build_body() uses it instead. The gaze
## eyes / turn tweens are model-agnostic (they drive this node's rotation + two
## emissive eye nodes the swap keeps).
##
## Facing convention: model forward is +Z. She sits at the deep -Z end facing the
## coffin further behind her (yaw = PI, back to the players at +Z). A whip-turn
## tweens yaw -> 0 so she faces the room; a fake-out only reaches a half-turn and
## recoils back to the coffin.

const WIDOW_GLB := "res://assets/models/meshy/widow.glb"   # swap seam (absent for now)
const WEEP_YAW := PI            # facing the coffin (back to the room)
const GAZE_YAW := 0.0           # whipped around, facing the players
const EYE_COLD := Color(0.75, 0.90, 1.0)
const EYE_HOT := Color(1.0, 0.35, 0.30)

var _model_root: Node3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _gaze_light: OmniLight3D
var _turn_tw: Tween
var _sob_t := 0.0
var _weeping := true
var _gaze_on := false


func build() -> void:
	rotation.y = WEEP_YAW
	_model_root = Node3D.new()
	_model_root.name = "WidowModel"
	add_child(_model_root)
	if ResourceLoader.exists(WIDOW_GLB):
		var m := MeshyProp.instance(WIDOW_GLB, 2.4)
		_model_root.add_child(m)
	else:
		_build_primitive_body()
		_model_root.scale = Vector3(1.25, 1.25, 1.25)   # presence at camera distance
	_build_eyes()
	# cold underlight, lit only while the gaze is on — washes the deep field red
	_gaze_light = OmniLight3D.new()
	_gaze_light.light_color = EYE_HOT
	_gaze_light.light_energy = 0.0
	_gaze_light.omni_range = 15.0
	_gaze_light.position = Vector3(0, 1.6, 1.6)
	add_child(_gaze_light)
	# a faint violet mourning aura so her silhouette reads against the dark wall
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.65, 0.5, 0.95)
	rim.light_energy = 1.1
	rim.omni_range = 4.0
	rim.position = Vector3(0, 2.6, 0)
	add_child(rim)


func _cloth(col: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = 0.0
	return m


func _build_primitive_body() -> void:
	# mourning dress — a tall tapered bell of near-black cloth
	var dress := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.28
	dm.bottom_radius = 0.78
	dm.height = 1.7
	dress.mesh = dm
	dress.material_override = _cloth(Color(0.09, 0.08, 0.11))
	dress.position.y = 0.85
	_model_root.add_child(dress)

	# shoulders / shawl
	var shawl := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.34
	sm.height = 0.5
	shawl.mesh = sm
	shawl.scale = Vector3(1.3, 0.7, 1.0)
	shawl.material_override = _cloth(Color(0.12, 0.11, 0.15))
	shawl.position.y = 1.55
	_model_root.add_child(shawl)

	# pale head
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.19
	hm.height = 0.4
	head.mesh = hm
	var hmat := _cloth(Color(0.78, 0.74, 0.72), 0.7)
	hmat.emission_enabled = true
	hmat.emission = Color(0.35, 0.36, 0.45)
	hmat.emission_energy_multiplier = 0.25
	head.material_override = hmat
	head.position.y = 1.85
	_model_root.add_child(head)

	# mourning veil — a translucent dark cone draping over head + shoulders
	var veil := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = 0.05
	vm.bottom_radius = 0.44
	vm.height = 0.95
	veil.mesh = vm
	var vmat := _cloth(Color(0.05, 0.05, 0.08))
	vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vmat.albedo_color = Color(0.05, 0.05, 0.08, 0.72)
	veil.material_override = vmat
	veil.position.y = 1.72
	_model_root.add_child(veil)

	# clasped pale hands in front
	var hands := MeshInstance3D.new()
	var hsm := SphereMesh.new()
	hsm.radius = 0.11
	hsm.height = 0.2
	hands.mesh = hsm
	hands.scale = Vector3(1.4, 0.8, 1.0)
	hands.material_override = head.material_override
	hands.position = Vector3(0, 1.15, 0.34)
	_model_root.add_child(hands)


func _build_eyes() -> void:
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.06, 0.06, 0.08)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = EYE_COLD
	_eye_mat.emission_energy_multiplier = 0.0     # dark until the gaze lamps on
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.045
		em.height = 0.09
		eye.mesh = em
		eye.material_override = _eye_mat
		# on the face (+Z), just below the veil hem
		eye.position = Vector3(0.07 * sx, 1.82, 0.17)
		_model_root.add_child(eye)
		if sx < 0.0:
			_eye_l = eye
		else:
			_eye_r = eye


## GREEN — she turns her back and weeps into the coffin. `instant` snaps (round
## start); otherwise she settles back gently.
func weep(instant := false) -> void:
	_weeping = true
	_set_gaze_internal(false)
	_kill_turn()
	if instant:
		rotation.y = WEEP_YAW
		return
	_turn_tw = create_tween()
	_turn_tw.tween_property(self, "rotation:y", WEEP_YAW, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## THE WHIP — she snaps around to face the room over `dur`, with a hair of
## overshoot so it reads as violent. Eyes lamp on separately via set_gaze() the
## instant the whip lands (the controller times that with the RED state).
func whip_turn(dur := 0.5) -> void:
	_weeping = false
	_kill_turn()
	_turn_tw = create_tween()
	_turn_tw.tween_property(self, "rotation:y", GAZE_YAW - 0.12, dur * 0.72) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turn_tw.tween_property(self, "rotation:y", GAZE_YAW, dur * 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A FAKE-OUT — she twists halfway as if to turn, thinks better of it, and sinks
## back to the coffin. No eyes. The stumble in the middle is the tell the room
## learns to read.
func fakeout_turn(dur := 0.5) -> void:
	_weeping = false
	_kill_turn()
	_turn_tw = create_tween()
	_turn_tw.tween_property(self, "rotation:y", PI * 0.58, dur * 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turn_tw.tween_interval(0.06)
	_turn_tw.tween_property(self, "rotation:y", WEEP_YAW, dur * 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tw.tween_callback(func() -> void: _weeping = true)


## Lamp the eyes on/off. The gaze light and eye emission ride this.
func set_gaze(on: bool) -> void:
	_set_gaze_internal(on)


func _set_gaze_internal(on: bool) -> void:
	_gaze_on = on
	if _eye_mat:
		_eye_mat.emission = EYE_HOT if on else EYE_COLD
		var tw := create_tween()
		tw.tween_property(_eye_mat, "emission_energy_multiplier", 6.0 if on else 0.0, 0.12)
	if _gaze_light:
		var lt := create_tween()
		lt.tween_property(_gaze_light, "light_energy", 5.5 if on else 0.0, 0.14)


func facing_players_frac() -> float:
	# 0 = fully weeping (coffin), 1 = fully facing the room — for HUD/mirror
	var d := absf(wrapf(rotation.y - GAZE_YAW, -PI, PI))
	return clampf(1.0 - d / PI, 0.0, 1.0)


func _kill_turn() -> void:
	if _turn_tw and _turn_tw.is_valid():
		_turn_tw.kill()


func tick(delta: float, _t: float) -> void:
	# a slow grief sob while weeping — the shoulders heave (visual only)
	if _weeping and _model_root:
		_sob_t += delta
		var heave := sin(_sob_t * 2.3) * 0.02 + sin(_sob_t * 5.1) * 0.006
		_model_root.position.y = heave
		_model_root.rotation.x = sin(_sob_t * 2.3) * 0.03
	elif _model_root:
		_model_root.position.y = lerpf(_model_root.position.y, 0.0, 1.0 - exp(-6.0 * delta))
		_model_root.rotation.x = lerpf(_model_root.rotation.x, 0.0, 1.0 - exp(-6.0 * delta))
