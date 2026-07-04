class_name TrapTile
extends Area3D
## A seeded walkway trap on the estate grounds. Owner-colored, fully
## visible (legible deviousness). One-shot: trips a non-owner walker,
## steals 1 grudge for the owner, then vanishes.

var owner_idx := -1
var owner_color := Color.WHITE
var armed := true

signal tripped(victim_idx: int, owner_idx: int)

func setup(idx: int, color: Color) -> void:
	owner_idx = idx
	owner_color = color
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.75
	cyl.height = 0.6
	shape.shape = cyl
	shape.position.y = 0.3
	add_child(shape)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.72
	dm.bottom_radius = 0.75
	dm.height = 0.035
	disc.mesh = dm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	mat.emission_enabled = true
	mat.emission = color * 0.5
	disc.material_override = mat
	disc.position.y = 0.02
	add_child(disc)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.68
	rm.outer_radius = 0.78
	ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color * 0.8
	ring.material_override = rmat
	ring.position.y = 0.04
	ring.scale.y = 0.3
	add_child(ring)
	body_entered.connect(_on_body)

func _on_body(body: Node3D) -> void:
	if not armed or not body is EstateWalker or body.player_idx == owner_idx:
		return
	armed = false
	tripped.emit(body.player_idx, owner_idx)
	body.trip(global_position)
	var p := CPUParticles3D.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 0.3, 0)
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = owner_color
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	queue_free()
