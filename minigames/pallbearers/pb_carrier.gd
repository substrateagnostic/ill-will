class_name PBCarrier
extends Node3D
## One pallbearer in PALLBEARERS — a KayKit body pinned to one end of a coffin.
##
## PURE VISUAL / render-only. The controller (pallbearers.gd) owns every game
## decision (the blended carry, divergence, drops, restuffing) and drives this
## node's world position + facing each physics tick, exactly as the coffin rig
## demands. This node owns only body state: the model, the identity ring, the
## HOP bob + jostle squash (the twist), and the restuff mash pump. No physics
## body, no move_and_slide — the whole rig is a deterministic kinematic sim so
## the seeded receipt is byte-identical run to run.

const BASE_SCALE := 0.9
const MODEL_YAW_OFFSET := 0.0          # KayKit adventurers face +Z; atan2(x,z) needs no flip

var player_index := -1                 # roster index, or -1 for a filler bot
var team := 0
var is_front := true
var color := Color.WHITE
var char_path := ""

var yaw := 0.0
var _hop_bob := 0.0                    # current visual hop height
var _hop_vel := 0.0
var _grip_lean := 0.0

var _pivot: Node3D
var _anim: AnimationPlayer
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _squash_tw: Tween
var _cur_anim := ""
var _anim_hold := 0.0


func setup(index: int, col: Color, char_scene: String, front: bool, team_id: int) -> void:
	player_index = index
	color = col
	char_path = char_scene
	is_front = front
	team = team_id

	_pivot = Node3D.new()
	add_child(_pivot)
	var ps: PackedScene = load(char_path) if ResourceLoader.exists(char_path) else null
	if ps != null:
		var inst: Node = ps.instantiate()
		(inst as Node3D).scale = Vector3(BASE_SCALE, BASE_SCALE, BASE_SCALE)
		_pivot.add_child(inst)
		_anim = inst.find_child("AnimationPlayer", true, false)
		for a in ["Idle", "Running_A", "Walking_A"]:
			if _anim != null and _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	else:
		# fallback body so the game reads even with no KayKit asset
		var mi := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.3
		cap.height = 1.3
		mi.mesh = cap
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col.darkened(0.2)
		mi.material_override = mat
		mi.position.y = 0.75
		_pivot.add_child(mi)

	# identity feet ring (house style: color = player)
	_ring = MeshInstance3D.new()
	var rmesh := CylinderMesh.new()
	rmesh.top_radius = 0.46
	rmesh.bottom_radius = 0.52
	rmesh.height = 0.05
	_ring.mesh = rmesh
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = col
	_ring_mat.emission_enabled = true
	_ring_mat.emission = col
	_ring_mat.emission_energy_multiplier = 0.6
	_ring_mat.roughness = 0.5
	_ring.material_override = _ring_mat
	_ring.position.y = 0.04
	add_child(_ring)

	_play("Idle")


## Called every physics tick by the controller. `moving` picks locomotion clip;
## `grip` (0..1) leans the body toward the coffin it holds (carry read).
func drive(delta: float, world_pos: Vector3, face_yaw: float, moving: bool, grip: float) -> void:
	yaw = face_yaw
	# spring the hop bob back to ground
	if _hop_bob > 0.0 or _hop_vel != 0.0:
		_hop_vel -= 26.0 * delta
		_hop_bob = maxf(0.0, _hop_bob + _hop_vel * delta)
		if _hop_bob <= 0.0:
			_hop_bob = 0.0
			_hop_vel = 0.0
	global_position = world_pos + Vector3(0.0, _hop_bob, 0.0)
	_grip_lean = lerpf(_grip_lean, clampf(grip, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
	_pivot.rotation.x = -0.12 * _grip_lean      # a slight forward stoop under the weight
	_anim_hold = maxf(0.0, _anim_hold - delta)
	if _anim_hold <= 0.0:
		_play("Running_A" if moving else "Idle")


## THE TWIST — a hop that jostles the coffin. Visual: a quick vertical pop + a
## squash. The controller decides what the hop does to the carry (nudge / heave /
## divergence spike); this is only the body's read of it.
func hop() -> void:
	_hop_vel = 5.2
	_squash(Vector3(0.86, 1.2, 0.86), 0.18)
	_one_shot("Jump_Full_Short", 0.3)


## Restuff mash — a punch/interact pump while stuffing the deceased back in.
func mash_pump() -> void:
	_one_shot("Unarmed_Melee_Attack_Punch_A", 0.22)
	_squash(Vector3(1.1, 0.9, 1.1), 0.14)


func stumble() -> void:
	_one_shot("Hit_A", 0.5)
	_squash(Vector3(1.18, 0.85, 1.18), 0.18)


func cheer() -> void:
	_one_shot("Cheer", 3.0)


func slump() -> void:
	# the losing carriers set the pall down and mourn (or sulk)
	_one_shot("Idle", 3.0)
	_pivot.rotation.x = 0.2


func _squash(to: Vector3, back_time: float) -> void:
	if _pivot == null:
		return
	if _squash_tw != null and _squash_tw.is_valid():
		_squash_tw.kill()
	_pivot.scale = to
	_squash_tw = create_tween()
	_squash_tw.tween_property(_pivot, "scale", Vector3.ONE, back_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_ring_energy(e: float) -> void:
	if _ring_mat != null:
		_ring_mat.emission_energy_multiplier = e


func _one_shot(anim_name: String, hold: float) -> void:
	if _anim != null and _anim.has_animation(anim_name):
		_cur_anim = anim_name
		_anim.play(anim_name, 0.08)
		_anim_hold = hold


func _play(anim_name: String) -> void:
	if _anim == null or _cur_anim == anim_name:
		return
	var want := anim_name
	if not _anim.has_animation(want):
		want = "Idle"
		if _cur_anim == want or not _anim.has_animation(want):
			return
	_cur_anim = want
	_anim.play(want, 0.15)
