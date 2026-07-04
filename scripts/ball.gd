class_name Ball
extends RigidBody3D

signal sunk
signal came_to_rest

const STOP_SPEED := 0.12
const MAX_SPEED := 15.0

var player_index := 0
var player_color := Color(1.0, 0.42, 0.35)
var is_sunk := false
var is_petrified := false
var last_rest_position := Vector3.ZERO
var _was_moving := false
var _mat: StandardMaterial3D

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	last_rest_position = global_position
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = player_color
	_mat.roughness = 0.35
	mesh.set_surface_override_material(0, _mat)

func _physics_process(_delta: float) -> void:
	if is_sunk or is_petrified:
		return
	var speed := linear_velocity.length()
	if speed > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	if speed < 0.9 and speed > 0.0:
		linear_velocity *= 0.9
		angular_velocity *= 0.9
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
	if is_sunk or is_petrified:
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
	sunk.emit()
	call_deferred("_sink_cleanup")

func _sink_cleanup() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3(0, -0.5, 0), 0.25)
	tw.parallel().tween_property(mesh, "scale", Vector3(0.4, 0.4, 0.4), 0.25)
	tw.tween_callback(func(): visible = false)

func petrify() -> void:
	is_petrified = true
	call_deferred("set", "freeze", true)
	if _mat:
		_mat.albedo_color = player_color.lerp(Color(0.45, 0.45, 0.48), 0.75)

func reset_for_round(tee_pos: Vector3) -> void:
	is_sunk = false
	is_petrified = false
	_was_moving = false
	visible = true
	freeze = true
	global_position = tee_pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	last_rest_position = tee_pos
	mesh.scale = Vector3.ONE
	collision_layer = 1
	collision_mask = 1
	if _mat:
		_mat.albedo_color = player_color
	call_deferred("set", "freeze", false)

func reset_to_rest() -> void:
	freeze = true
	global_position = last_rest_position + Vector3(0, 0.3, 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	_was_moving = true
