extends Trap
## Two linked rings. A ball entering either ring is teleported to the other,
## keeping its speed and heading (nudged out the far side so it doesn't loop).
## Placed with TWO clicks: first locks ring A, second locks ring B.

const EXIT_OFFSET := 0.5
const COOLDOWN := 0.55

var _active := 0
var _locked_a := false
var _cooldowns := {}

@onready var ring_a: Node3D = $RingA
@onready var ring_b: Node3D = $RingB

func _init() -> void:
	trap_id = "portal_pair"
	display_name = "PORTAL PAIR"
	footprint_radius = 0.6
	endpoint_count = 2

func _ready() -> void:
	ring_a.get_node("Sense").body_entered.connect(_on_enter.bind(0))
	ring_b.get_node("Sense").body_entered.connect(_on_enter.bind(1))

# --- placement interface -------------------------------------------------------
func _ring(idx: int) -> Node3D:
	return ring_b if idx == 1 else ring_a

func active_placement_pos() -> Vector3:
	return _ring(_active).global_position

func move_placement(pos: Vector3) -> void:
	_ring(_active).global_position = Vector3(pos.x, 0.0, pos.z)

func advance_placement() -> bool:
	if _active == 0:
		_active = 1
		_locked_a = true
		ring_b.global_position = ring_a.global_position + Vector3(0.9, 0.0, 0.0)
		return false
	return true

func locked_footprint_points() -> Array:
	if _locked_a:
		return [{"pos": ring_a.global_position, "radius": footprint_radius}]
	return []

func footprint_points() -> Array:
	return [
		{"pos": ring_a.global_position, "radius": footprint_radius},
		{"pos": ring_b.global_position, "radius": footprint_radius},
	]

# --- runtime -------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	ring_a.get_node("Spin").rotate_y(1.6 * delta)
	ring_b.get_node("Spin").rotate_y(-1.6 * delta)
	for k in _cooldowns.keys():
		_cooldowns[k] -= delta
		if _cooldowns[k] <= 0.0:
			_cooldowns.erase(k)

func _on_enter(body: Node3D, which: int) -> void:
	if is_ghost or not body is Ball or body.is_sunk or body.is_dead:
		return
	if _cooldowns.has(body):
		return
	var dst: Node3D = ring_b if which == 0 else ring_a
	var vel: Vector3 = body.linear_velocity
	var flat := Vector3(vel.x, 0.0, vel.z)
	var dir := flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
	body.global_position = dst.global_position + dir * EXIT_OFFSET + Vector3(0, 0.15, 0)
	body.linear_velocity = vel
	_cooldowns[body] = COOLDOWN
	Sfx.play("bumper", -7.0)
