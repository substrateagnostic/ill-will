class_name LWWall
extends Node3D
## The pallbearers' pusher — Par's MOVING WALL visual language on the ossuary
## ridge: an iron-banded stone slab sliding side to side across the walkway
## on a visible track. It physically shoves pawns (AnimatableBody3D with
## sync_to_physics), and on a ridge this narrow "shoved" usually means "off".
## The uncovered side is the way through; it alternates. Ticked by the
## controller only while the race runs, so the will-draft freeze parks it.

var owner_game: Node = null
var _slider: AnimatableBody3D
var _phase := 0.0
var _rate := 0.9
var _travel := 1.7
var _zc := 0.0
var _len := 2.3

func setup(pos: Vector3, path_half_width: float, p_owner: Node, phase0 := 0.0) -> void:
	owner_game = p_owner
	global_position = Vector3(pos.x, 0.0, pos.z)
	_zc = pos.z
	_phase = phase0
	_len = path_half_width * 1.25
	_travel = path_half_width * 0.95

	# visible track groove across the walkway
	var track := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.9, 0.06, path_half_width * 2.0 + 0.6)
	track.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.16, 0.15, 0.19)
	tmat.roughness = 1.0
	track.material_override = tmat
	track.position.y = 0.03
	add_child(track)

	_slider = AnimatableBody3D.new()
	_slider.sync_to_physics = true
	_slider.collision_layer = 1
	_slider.collision_mask = 0
	add_child(_slider)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 1.5, _len)
	cs.shape = box
	cs.position.y = 0.75
	_slider.add_child(cs)
	var slab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.55, 1.4, _len)
	slab.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.44, 0.42, 0.5)
	smat.roughness = 0.9
	slab.material_override = smat
	slab.position.y = 0.72
	_slider.add_child(slab)
	for band_y in [0.28, 1.12]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.12, _len + 0.04)
		band.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.22, 0.2, 0.24)
		bmat.metallic = 0.7
		bmat.roughness = 0.45
		band.material_override = bmat
		band.position.y = band_y
		_slider.add_child(band)
	_apply_phase()

func tick(delta: float) -> void:
	_phase += delta * _rate
	_apply_phase()

func _apply_phase() -> void:
	if _slider != null:
		_slider.position = Vector3(0.0, 0.0, sin(_phase) * _travel)

## World-space z of the open lane right now (for the bots).
func gap_z() -> float:
	var off := sin(_phase) * _travel
	var s := signf(off)
	if s == 0.0:
		s = 1.0
	# the slab's center sits at _zc + off; the open lane hugs the far edge
	return _zc + off - s * (_len * 0.5 + 0.7)

func wall_x() -> float:
	return global_position.x
