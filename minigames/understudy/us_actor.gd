class_name USActor
extends Node3D
## THE UNDERSTUDY — one actor standing on their mark, under their own spotlight.
## A KayKit body (whisper of identity color via rim overlay), a billboarded
## name tag (shape glyph + name so identity is never color-alone), a floor mark
## ring, and a personal SpotLight3D the controller brightens/dims as the scene
## moves. Actors never move under physics; they are performers, not fighters.

const SPOT_BASE := 3.0
const SPOT_FOCUS := 7.5

var index := 0
var color := Color.WHITE
var pname := ""

var _model_pivot: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _name_label: Label3D
var _status_label: Label3D
var _mark: MeshInstance3D
var _mark_mat: StandardMaterial3D
var _spot: SpotLight3D
var _cur_anim := ""
var _anim_lock := 0.0
var _base_face := 0.0

func setup(p_index: int, p_color: Color, p_name: String, char_scene: PackedScene, face_yaw: float) -> void:
	index = p_index
	color = p_color
	pname = p_name
	_base_face = face_yaw

	# floor mark ring in the player's color — a footlight pool on the boards
	_mark = MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.62
	rm.bottom_radius = 0.66
	rm.height = 0.04
	_mark.mesh = rm
	_mark_mat = StandardMaterial3D.new()
	_mark_mat.albedo_color = color
	_mark_mat.emission_enabled = true
	_mark_mat.emission = color
	_mark_mat.emission_energy_multiplier = 0.55
	_mark.material_override = _mark_mat
	_mark.position.y = 0.02
	add_child(_mark)

	_model_pivot = Node3D.new()
	_model_pivot.name = "ModelPivot"
	add_child(_model_pivot)
	_model_pivot.rotation.y = face_yaw
	if char_scene != null:
		_model = char_scene.instantiate()
		_model.scale = Vector3(1.0, 1.0, 1.0)
		_model_pivot.add_child(_model)
		_anim = _model.find_child("AnimationPlayer", true, false)
		_tint(_model)
		for a in ["Idle", "Cheer", "Hit_A", "Running_A"]:
			if _anim and _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		play_idle()

	_name_label = Label3D.new()
	_name_label.text = PlayerBadge.glyph(index) + " " + p_name
	_name_label.font_size = 42
	_name_label.pixel_size = 0.0062
	_name_label.modulate = color
	_name_label.outline_size = 11
	_name_label.outline_modulate = Color(0.05, 0.04, 0.07)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, 2.02, 0)
	_name_label.no_depth_test = true
	add_child(_name_label)

	_status_label = Label3D.new()
	_status_label.font_size = 34
	_status_label.pixel_size = 0.0062
	_status_label.outline_size = 9
	_status_label.outline_modulate = Color(0.05, 0.04, 0.07)
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.position = Vector3(0, 2.34, 0)
	_status_label.no_depth_test = true
	_status_label.visible = false
	add_child(_status_label)

	_spot = SpotLight3D.new()
	_spot.light_color = color.lerp(Color(1.0, 0.93, 0.78), 0.55)
	_spot.light_energy = SPOT_BASE
	_spot.spot_range = 9.0
	_spot.spot_angle = 26.0
	_spot.spot_attenuation = 1.4
	_spot.shadow_enabled = false
	_spot.position = Vector3(0, 5.4, 1.6)
	_spot.rotation_degrees = Vector3(-72.0, 0, 0)
	add_child(_spot)

func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(color.r, color.g, color.b, 0.13)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.12
		m.rim_enabled = true
		m.rim = 0.7
		(node as MeshInstance3D).material_overlay = m
	for c in node.get_children():
		_tint(c)

# --- stage direction --------------------------------------------------------
func set_focus(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_spot, "light_energy", SPOT_FOCUS if on else SPOT_BASE, 0.35)
	_mark_mat.emission_energy_multiplier = 1.3 if on else 0.55

func set_lit(energy: float) -> void:
	_spot.light_energy = energy

func dim_out() -> void:
	# a suspected / dismissed actor: cut their spotlight to near dark
	var tw := create_tween()
	tw.tween_property(_spot, "light_energy", 0.4, 0.4)
	_mark_mat.emission_energy_multiplier = 0.2
	_name_label.modulate = color.darkened(0.4)

func face_front() -> void:
	var tw := create_tween()
	tw.tween_property(_model_pivot, "rotation:y", _base_face, 0.3)

func turn_to(yaw: float) -> void:
	var tw := create_tween()
	tw.tween_property(_model_pivot, "rotation:y", yaw, 0.3)

func show_status(text: String, col: Color) -> void:
	_status_label.text = text
	_status_label.modulate = col
	_status_label.visible = text != ""

func hide_status() -> void:
	_status_label.visible = false

func play_idle() -> void:
	_play("Idle")

func play_cheer() -> void:
	_play_once("Cheer", 2.6)

func play_flinch() -> void:
	_play_once("Hit_A", 0.7)

func _play(n: String) -> void:
	if _anim == null or _cur_anim == n or not _anim.has_animation(n):
		return
	_anim.play(n)
	_cur_anim = n

func _play_once(n: String, hold: float) -> void:
	if _anim == null or not _anim.has_animation(n):
		return
	_anim.play(n)
	_cur_anim = n
	_anim_lock = hold

func tick(delta: float) -> void:
	if _anim_lock > 0.0:
		_anim_lock -= delta
		if _anim_lock <= 0.0:
			_play("Idle")

# --- ONLINE mirror (docs/design/10 §4.3) ------------------------------------
## Compact visual state for the wire: [spotlight energy, status text (or ""),
## status colour html, current anim tag]. All PUBLIC — the actor never carries
## hidden role info (the understudy's status label only appears at RESOLVE).
func net_pack() -> Array:
	return [
		snappedf(_spot.light_energy, 0.05),
		_status_label.text if _status_label.visible else "",
		_status_label.modulate.to_html(false),
		_cur_anim,
	]

## Apply a wire pack on the mirror: snap the spotlight, mirror the status label,
## and re-fire cheer/flinch when the anim tag changes (juice from the delta).
func net_apply(lit: float, status_text: String, status_col: String, anim: String) -> void:
	_spot.light_energy = lit
	_mark_mat.emission_energy_multiplier = 1.3 if lit >= SPOT_FOCUS - 0.5 else (0.2 if lit <= 0.5 else 0.55)
	if status_text == "":
		_status_label.visible = false
	else:
		_status_label.text = status_text
		_status_label.modulate = Color(status_col)
		_status_label.visible = true
	if anim != _cur_anim:
		match anim:
			"Cheer": play_cheer()
			"Hit_A": play_flinch()
			_: play_idle()
