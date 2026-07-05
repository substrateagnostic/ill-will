class_name Trap
extends Node3D
## Base for all placeable traps. Traps persist for the whole match and
## remember their author forever (royalties).

var trap_id := ""
var display_name := "Trap"
var author_index := -1
var author_color := Color.WHITE
var footprint_radius := 0.8
var is_ghost := false
## Chaos round cranks powered traps (windmill/crusher/fan) to 1.6x. Motion is
## time-based, so powered traps multiply their per-frame step by this.
var speed_scale := 1.0
## Number of clicks the placement flow needs to finish this trap. Default 1
## (drop it where the mouse is). Portal-style traps override to 2: the first
## click locks endpoint A, the second locks endpoint B, then it confirms.
var endpoint_count := 1

## Every disc a later placement must avoid overlapping. Default: one disc at the
## root. Multi-endpoint traps (portal) override to report BOTH rings so nothing
## gets built on top of a portal mouth. Each entry: {"pos": Vector3, "radius": float}.
func footprint_points() -> Array:
	return [{"pos": global_position, "radius": footprint_radius}]

# --- Placement interface (single-click default; overridden by portal) --------
## Where the validity check + preview disc should sit right now.
func active_placement_pos() -> Vector3:
	return global_position

func active_footprint_radius() -> float:
	return footprint_radius

## Move the currently-active footprint to a green-plane point.
func move_placement(pos: Vector3) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)

## Commit the current click. Return true when fully placed (confirm now),
## false when the trap still needs another click.
func advance_placement() -> bool:
	return true

## Footprints of endpoints already locked this placement (self-overlap guard).
func locked_footprint_points() -> Array:
	return []

func kill_ball(ball: Ball) -> void:
	if is_ghost or ball.is_sunk or ball.is_dead:
		return
	ball.die(self)

func set_author(idx: int, color: Color) -> void:
	author_index = idx
	author_color = color
	for m in find_children("Accent*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.5
		m.set_surface_override_material(0, mat)

func ghostify() -> void:
	is_ghost = true
	for co in find_children("*", "CollisionObject3D", true, false):
		co.collision_layer = 0
		co.collision_mask = 0
		if co is Area3D:
			co.monitoring = false
		if co is AnimatableBody3D:
			co.sync_to_physics = false
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.transparency = 0.55

func solidify() -> void:
	is_ghost = false
	for co in find_children("*", "CollisionObject3D", true, false):
		co.collision_layer = 1
		co.collision_mask = 1
		if co is Area3D:
			co.monitoring = true
		if co is AnimatableBody3D:
			co.sync_to_physics = true
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.transparency = 0.0
