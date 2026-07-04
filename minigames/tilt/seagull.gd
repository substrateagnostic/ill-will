class_name TiltSeagull
extends Node3D
## Eliminated players come back as seagulls: free flight above the platter,
## A drops one guano bomb per 4s. Built from primitives (no bird model in
## the committed asset set) with the player's color on wingtips + a neck
## ring so identity survives death.

const SPEED := 6.0
const ALT := 5.2
const BOMB_CD := 4.0
const RANGE := 11.0

var player_index := 0
var pcolor := Color.WHITE
var bomb_cd := 0.0

var _wing_l: Node3D
var _wing_r: Node3D
var _clock := 0.0
var _yaw := 0.0

func setup(index: int, color: Color) -> void:
	player_index = index
	pcolor = color
	_build()

func tick(delta: float, move: Vector2) -> void:
	_clock += delta
	bomb_cd = maxf(0.0, bomb_cd - delta)
	var v := move.normalized() if move.length() > 1.0 else move
	position.x += v.x * SPEED * delta
	position.z += v.y * SPEED * delta
	var flat := Vector2(position.x, position.z)
	if flat.length() > RANGE:
		flat = flat.normalized() * RANGE
		position.x = flat.x
		position.z = flat.y
	position.y = lerpf(position.y, ALT + sin(_clock * 2.0) * 0.25, minf(1.0, 2.5 * delta))
	if v.length() > 0.1:
		_yaw = lerp_angle(_yaw, atan2(-v.x, -v.y), minf(1.0, 6.0 * delta))
	rotation.y = _yaw
	var flap := sin(_clock * 9.0) * 0.62
	_wing_l.rotation.z = flap
	_wing_r.rotation.z = -flap

func can_bomb() -> bool:
	return bomb_cd <= 0.0

func drop() -> void:
	bomb_cd = BOMB_CD

func _build() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.97, 0.95)
	white.roughness = 0.8
	var tint := StandardMaterial3D.new()
	tint.albedo_color = pcolor
	tint.emission_enabled = true
	tint.emission = pcolor * 0.6
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.95, 0.55, 0.1)
	# body (capsule laid along -Z = forward)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.18
	bm.height = 0.75
	body.mesh = bm
	body.rotation.x = PI / 2.0
	body.material_override = white
	add_child(body)
	# head
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.14
	hm.height = 0.28
	head.mesh = hm
	head.position = Vector3(0.0, 0.14, -0.36)
	head.material_override = white
	add_child(head)
	# beak
	var beak := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 0.0
	km.bottom_radius = 0.05
	km.height = 0.2
	beak.mesh = km
	beak.position = Vector3(0.0, 0.13, -0.52)
	beak.rotation.x = -PI / 2.0
	beak.material_override = orange
	add_child(beak)
	# neck ring in player color
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.13
	rm.outer_radius = 0.20
	ring.mesh = rm
	ring.position = Vector3(0.0, 0.09, -0.26)
	ring.rotation.x = PI / 2.0
	ring.material_override = tint
	add_child(ring)
	# tail
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.16, 0.03, 0.22)
	tail.mesh = tm
	tail.position = Vector3(0.0, 0.03, 0.42)
	tail.material_override = white
	add_child(tail)
	# wings (pivot at shoulder so they flap)
	_wing_l = _wing(white, tint, -1.0)
	_wing_r = _wing(white, tint, 1.0)
	add_child(_wing_l)
	add_child(_wing_r)

func _wing(white: StandardMaterial3D, tint: StandardMaterial3D, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.14 * side, 0.06, 0.0)
	var wing := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.75, 0.03, 0.3)
	wing.mesh = wm
	wing.position.x = 0.38 * side
	wing.material_override = white
	pivot.add_child(wing)
	var tip := MeshInstance3D.new()
	var tm2 := BoxMesh.new()
	tm2.size = Vector3(0.16, 0.032, 0.3)
	tip.mesh = tm2
	tip.position.x = 0.83 * side
	tip.material_override = tint
	pivot.add_child(tip)
	return pivot
