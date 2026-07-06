class_name LWSpinner
extends Node3D
## The graveyard sweeper — Par's SPINNER visual language ported to the
## procession: a flat four-armed cross spinning at ankle height on the
## Lantern Walk. Not a killer: pawns clipped by an arm get batted along the
## arm's travel (and a hair outward) — usually toward the edge lanterns.
## Hop (B) over the arms; airborne pawns are safe. Code-driven, ticked by
## the controller only while the race runs.

const ARM_REACH := 2.3
const ARM_HALF_W := 0.34
const PUSH := 5.2
const SPIN := 1.7            # rad/s
const REHIT_T := 0.6

var owner_game: Node = null
var _angle := 0.0
var _memo: Dictionary = {}   # pawn index -> game_time of last swat
var _arms: Node3D

func setup(pos: Vector3, p_owner: Node) -> void:
	owner_game = p_owner
	global_position = Vector3(pos.x, 0.0, pos.z)

	# hub stone
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.45
	hm.bottom_radius = 0.55
	hm.height = 0.5
	hub.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.4, 0.38, 0.44)
	hmat.roughness = 0.9
	hub.material_override = hmat
	hub.position.y = 0.25
	add_child(hub)

	_arms = Node3D.new()
	add_child(_arms)
	var glb := "res://assets/models/meshy/spinner_arms.glb"
	if ResourceLoader.exists(glb):
		# Meshy sweeper cross scaled so its span fills the reach the swat
		# math implies (ARM_REACH 2.3 => 4.6 span), kept low like Par's.
		var wrap := MeshyProp.instance(glb, 1.0)
		var model: Node3D = wrap.get_node("Model")
		var aabb := MeshyProp.merged_aabb_of_scaled(model)
		var span := maxf(aabb.size.x, aabb.size.z)
		if span > 0.001:
			var s := (ARM_REACH * 2.0) / span
			wrap.scale = Vector3(s, s, s)
			var h := aabb.size.y * s
			if h > 0.42:
				wrap.scale.y = s * (0.42 / h)
		wrap.position.y = 0.06
		_arms.add_child(wrap)
	else:
		var arm_mat := StandardMaterial3D.new()
		arm_mat.albedo_color = Color(0.5, 0.38, 0.26)
		arm_mat.roughness = 0.85
		for k in 2:
			var arm := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(ARM_REACH * 2.0, 0.22, ARM_HALF_W * 2.0)
			arm.mesh = am
			arm.material_override = arm_mat
			arm.position.y = 0.2
			arm.rotation.y = PI / 2.0 * float(k)
			_arms.add_child(arm)

func tick(delta: float) -> void:
	_angle = fmod(_angle + SPIN * delta, TAU)
	_arms.rotation.y = _angle
	if owner_game == null:
		return
	var now: float = owner_game.game_time
	for pawn in owner_game.living_pawns():
		if now - float(_memo.get(pawn.index, -99.0)) < REHIT_T:
			continue
		if pawn.global_position.y > 0.7:
			continue   # hopped over
		var rel := Vector2(pawn.global_position.x - global_position.x,
			pawn.global_position.z - global_position.z)
		var r := rel.length()
		if r > ARM_REACH + 0.3 or r < 0.05:
			continue
		var pang := atan2(rel.y, rel.x)
		# the visual cross spins +Y; its arms in the XZ plane sit at -_angle
		var band := atan2(ARM_HALF_W + 0.15, maxf(r, 0.4))
		for k in 4:
			var arm_ang := -_angle + PI / 2.0 * float(k)
			var d := wrapf(pang - arm_ang, -PI, PI)
			if absf(d) <= band:
				_memo[pawn.index] = now
				# swat along the arm's travel + a hair outward
				var tangent := Vector2(-rel.y, rel.x).normalized() * -1.0
				var push2 := (tangent * 0.85 + rel.normalized() * 0.4).normalized()
				pawn.hit(Vector3(push2.x, 0.0, push2.y), PUSH, "spinner", -1,
					"THE SWEEPER", Color(0.9, 0.7, 0.4))
				break
