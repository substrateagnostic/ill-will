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
