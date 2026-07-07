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

## ONLINE mirror: XZ position is lerped by the game from snapshots; this keeps
## the local life alive — altitude bob, yaw toward travel, wing pivots.
func mirror_tick(delta: float, vel: Vector2) -> void:
	_clock += delta
	position.y = lerpf(position.y, ALT + sin(_clock * 2.0) * 0.25, minf(1.0, 2.5 * delta))
	if vel.length() > 0.1:
		_yaw = lerp_angle(_yaw, atan2(-vel.x, -vel.y), minf(1.0, 6.0 * delta))
	rotation.y = _yaw
	var flap := sin(_clock * 9.0) * 0.62
	_wing_l.rotation.z = flap
	_wing_r.rotation.z = -flap

func can_bomb() -> bool:
	return bomb_cd <= 0.0

func drop() -> void:
	bomb_cd = BOMB_CD

const SEAGULL_GLB := "res://assets/models/meshy/seagull.glb"
const SEAGULL_HEIGHT := 0.58
const SEAGULL_YAW := -90.0      # rotate so the beak points -Z (the flight-forward axis)

func _build() -> void:
	# Custom Meshy seagull (standing, wings folded, white body / grey wings /
	# orange beak+legs) replacing the primitive bird. The model is static, so the
	# wing-flap code drives two harmless empty pivots; identity survives death via
	# an added player-color collar ring. Beak faces -Z so the flight-orientation
	# math (rotation.y = atan2(-v.x,-v.y)) still points the bird where it flies.
	var gull := MeshyProp.instance(SEAGULL_GLB, SEAGULL_HEIGHT, SEAGULL_YAW)
	gull.name = "GullModel"
	add_child(gull)
	# player-color collar ring (identity read)
	var tint := StandardMaterial3D.new()
	tint.albedo_color = pcolor
	tint.emission_enabled = true
	tint.emission = pcolor * 0.6
	var collar := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.10
	rm.outer_radius = 0.17
	collar.mesh = rm
	collar.position = Vector3(0.0, 0.36, 0.0)
	collar.rotation.x = PI / 2.0
	collar.material_override = tint
	add_child(collar)
	# empty wing pivots: the static model has no separate wings, but tick() still
	# rotates these each frame — harmless, keeps the flap code untouched.
	_wing_l = Node3D.new()
	_wing_r = Node3D.new()
	add_child(_wing_l)
	add_child(_wing_r)
