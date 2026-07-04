class_name Ball
extends RigidBody3D

signal sunk
signal died(killer: Trap)
signal came_to_rest

const STOP_SPEED := 0.12
const MAX_SPEED := 15.0

var player_index := 0
var player_color := Color(1.0, 0.42, 0.35)
var is_sunk := false
var is_dead := false
var is_petrified := false
var last_rest_position := Vector3.ZERO
var _was_moving := false
var _mat: StandardMaterial3D
var _trail: CPUParticles3D

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	add_to_group("balls")
	body_entered.connect(_on_contact)
	last_rest_position = global_position
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = player_color
	_mat.roughness = 0.35
	mesh.set_surface_override_material(0, _mat)
	_trail = CPUParticles3D.new()
	_trail.emitting = false
	_trail.amount = 22
	_trail.lifetime = 0.4
	_trail.local_coords = false
	_trail.direction = Vector3.ZERO
	_trail.spread = 0.0
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.0
	_trail.gravity = Vector3.ZERO
	_trail.scale_amount_min = 0.55
	_trail.scale_amount_max = 0.9
	_trail.scale_amount_curve = null
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.07
	tmesh.height = 0.14
	_trail.mesh = tmesh
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(player_color.r, player_color.g, player_color.b, 0.5)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail.material_override = tmat
	add_child(_trail)

func _physics_process(_delta: float) -> void:
	if is_sunk or is_petrified or is_dead:
		return
	var speed := linear_velocity.length()
	if _trail:
		_trail.emitting = speed > 3.5
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
	if is_sunk or is_petrified or is_dead:
		return
	direction.y = 0.0
	var dir := direction.normalized()
	var s := clampf(speed, 0.0, MAX_SPEED)
	linear_velocity = dir * s
	angular_velocity = Vector3.UP.cross(dir) * (s / 0.15)
	_was_moving = true

func _on_contact(_body: Node) -> void:
	var speed := linear_velocity.length()
	if speed > 1.6:
		Sfx.play("bounce", clampf(-14.0 + speed, -12.0, 0.0))

func is_stopped() -> bool:
	return is_dead or (not _was_moving and not is_sunk)

func die(killer: Trap) -> void:
	if is_sunk or is_dead:
		return
	is_dead = true
	_was_moving = false
	died.emit(killer)
	call_deferred("_death_cleanup")

func _death_cleanup() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	visible = false

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
	is_dead = false
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
