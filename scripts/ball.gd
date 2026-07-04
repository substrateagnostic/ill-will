class_name Ball
extends RigidBody3D

signal sunk
signal came_to_rest

const STOP_SPEED := 0.12
const MAX_SPEED := 15.0

var player_color := Color(1.0, 0.42, 0.35)
var is_sunk := false
var last_rest_position := Vector3.ZERO
var _was_moving := false

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	last_rest_position = global_position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = player_color
	mat.roughness = 0.35
	mesh.set_surface_override_material(0, mat)

func _physics_process(_delta: float) -> void:
	if is_sunk:
		return
	var speed := linear_velocity.length()
	if speed > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	if _was_moving and speed < STOP_SPEED and global_position.y > -0.05:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		_was_moving = false
		last_rest_position = global_position
		came_to_rest.emit()
	elif speed >= STOP_SPEED:
		_was_moving = true
	if global_position.y < -3.0:
		reset_to_rest()

func putt(direction: Vector3, speed: float) -> void:
	if is_sunk:
		return
	direction.y = 0.0
	var dir := direction.normalized()
	var s := clampf(speed, 0.0, MAX_SPEED)
	linear_velocity = dir * s
	angular_velocity = Vector3.UP.cross(dir) * (s / 0.15)
	_was_moving = true

func is_stopped() -> bool:
	return not _was_moving and not is_sunk

func mark_sunk() -> void:
	if is_sunk:
		return
	is_sunk = true
	freeze = true
	sunk.emit()

func reset_to_rest() -> void:
	freeze = true
	global_position = last_rest_position + Vector3(0, 0.3, 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	_was_moving = true
