class_name EchoGhost
extends Node3D
## A recorded past self, replayed by DIRECT TRANSFORM APPLICATION — never
## re-simulated. Given the round clock t, it looks up the recorded 30Hz
## sample, applies position/rotation straight to the transform, and re-fires
## the swings it made in its original round (which damage LIVE players and
## earn the OWNER a bounty). Ghosts are translucent, owner-tinted, and cannot
## be damaged — they already happened.

const REC_HZ := 30.0
const MODEL_YAW_OFFSET := PI          # must match EchoFighter

# anim-state ids mirror EchoFighter
const ST_IDLE := 0
const ST_RUN := 1
const ST_SWING := 2
const ST_DASH := 3
const ST_HIT := 4
const ST_DEAD := 5

var take: Dictionary = {}
var owner_index := 0
var owner_color := Color.WHITE
var round_no := 0
var main: Node = null
var opacity := 0.55
var yaw := 0.0

var _pivot: Node3D
var _anim: AnimationPlayer
var _cur_anim := ""
var _last_index := -1
var _mats: Array = []
var _mesh_instances: Array = []


func setup() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var scene: PackedScene = load(take["char"])
	var inst := scene.instantiate()
	inst.scale = Vector3(0.9, 0.9, 0.9)
	_pivot.add_child(inst)
	_anim = inst.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A"]:
		if _anim and _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_tint(inst)


func _tint(node: Node) -> void:
	for c in node.get_children():
		_tint(c)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		# ghosts never cast shadows (readability + perf, per spec)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh_instances.append(mi)
		var surf := 0
		if mi.mesh:
			surf = mi.mesh.get_surface_count()
		for s in surf:
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = Color(owner_color.r, owner_color.g, owner_color.b, opacity)
			mat.emission_enabled = true
			mat.emission = owner_color
			mat.emission_energy_multiplier = 0.35
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(s, mat)
			_mats.append(mat)


func set_opacity(o: float) -> void:
	opacity = o
	for m in _mats:
		var mat := m as StandardMaterial3D
		var c := mat.albedo_color
		mat.albedo_color = Color(c.r, c.g, c.b, o)


func set_shadows(on: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in _mesh_instances:
		(mi as MeshInstance3D).cast_shadow = mode


func reset_replay() -> void:
	_last_index = -1


## Apply the recorded state at round-clock time t (seconds). Direct transform
## write; fires any swings whose recorded strike-frames we cross.
func replay(t: float) -> void:
	var count: int = take["count"]
	if count <= 0:
		return
	var pos_arr: PackedVector3Array = take["pos"]
	var yaw_arr: PackedFloat32Array = take["yaw"]
	var state_arr: PackedByteArray = take["state"]
	var fire_arr: PackedByteArray = take["fire"]

	var f := t * REC_HZ
	var i := int(f)
	if i < 0:
		i = 0
	var frac := f - float(i)
	var i2 := i + 1
	if i >= count - 1:
		i = count - 1
		i2 = i
		frac = 0.0
	if i2 > count - 1:
		i2 = count - 1

	var pa := pos_arr[i]
	var pb := pos_arr[i2]
	# a large gap means a respawn teleport — snap instead of sliding across
	if pa.distance_to(pb) > 4.0:
		frac = 0.0
	global_position = pa.lerp(pb, frac)
	yaw = lerp_angle(yaw_arr[i], yaw_arr[i2], frac)
	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET

	if i != _last_index:
		var j := _last_index + 1
		while j <= i:
			if j >= 0 and j < count and fire_arr[j] == 1 and main:
				main.resolve_swing(pos_arr[j], yaw_arr[j], owner_index, true, null, round_no)
			j += 1
		_apply_state_anim(state_arr[i])
		_last_index = i


func _apply_state_anim(s: int) -> void:
	match s:
		ST_RUN:
			_play("Running_A")
		ST_SWING:
			_play("1H_Melee_Attack_Slice_Horizontal", false)
		ST_DASH:
			_play("Dodge_Forward", false)
		ST_HIT:
			_play("Hit_A", false)
		ST_DEAD:
			_play("Death_A", false)
		_:
			_play("Idle")


func _play(anim_name: String, loop := true) -> void:
	if _anim == null or _cur_anim == anim_name:
		return
	if not _anim.has_animation(anim_name):
		return
	if loop:
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name)
	_cur_anim = anim_name
