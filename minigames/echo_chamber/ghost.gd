class_name EchoGhost
extends Node3D
## A recorded past self, replayed by DIRECT TRANSFORM APPLICATION — never
## re-simulated. Given the round clock t, it looks up the recorded 30Hz
## sample, applies position/rotation straight to the transform, and re-fires
## the swings it made in its original round (which damage LIVE players and
## earn the OWNER a bounty). Ghosts are translucent, owner-tinted, and cannot
## be damaged — they already happened.
##
## v1.1 declutter (Alex's note): a ghost must NOT linger. The instant it
## reaches its recorded DEATH (first ST_DEAD sample) or the END of its
## recording, it fragments (one-shot shard burst in its tint) and despawns.
## It reports its endpoint drift to the controller first, so the determinism
## assertion stays honest (transform == recorded sample, max_err 0.000000).

const REC_HZ := 30.0
const MODEL_YAW_OFFSET := 0.0         # must match EchoFighter

# anim-state ids mirror EchoFighter
const ST_IDLE := 0
const ST_RUN := 1
const ST_SWING := 2       # LIGHT (Chop)
const ST_DASH := 3
const ST_HIT := 4
const ST_DEAD := 5
const ST_HEAVY := 6       # HEAVY (2H Slice)
const ST_PARRY := 7       # Blocking
const ST_CHARGE := 8      # heavy windup
const CHARGE_SCALE := 1.06

var take: Dictionary = {}
var owner_index := 0
var owner_color := Color.WHITE
var round_no := 0
var main: Node = null
var opacity := 0.55
var yaw := 0.0
var done := false                     # reached endpoint, fragmenting/freed

var _pivot: Node3D
var _anim: AnimationPlayer
var _cur_anim := ""
var _last_index := -1
var _end_index := 0                   # first ST_DEAD, else last sample
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
	for a in ["Idle", "Running_A", "Blocking"]:
		if _anim and _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_tint(inst)
	_compute_end_index()


## Endpoint: the first recorded death (so a ghost that died vanishes AT its
## death, not after replaying a respawn), otherwise the final sample.
func _compute_end_index() -> void:
	var count: int = take["count"]
	var state_arr: PackedByteArray = take["state"]
	_end_index = maxi(0, count - 1)
	for k in count:
		if state_arr[k] == ST_DEAD:
			_end_index = k
			break


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
## write; fires any swings whose recorded strike-frames we cross. Fragments and
## despawns the instant it reaches its recorded death or the end.
func replay(t: float) -> void:
	if done:
		return
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

	# reached the endpoint (recorded death or end): fire remaining swings up to
	# it, snap exactly onto the sample, report drift, then fragment + despawn.
	if i >= _end_index:
		_fire_swings(fire_arr, pos_arr, yaw_arr, _last_index + 1, _end_index, count)
		global_position = pos_arr[_end_index]
		yaw = yaw_arr[_end_index]
		_pivot.rotation.y = yaw + MODEL_YAW_OFFSET
		var err := global_position.distance_to(pos_arr[_end_index])
		_finish(err)
		return

	var pa := pos_arr[i]
	var pb := pos_arr[i2]
	# a large gap means a respawn teleport — snap instead of sliding across
	if pa.distance_to(pb) > 4.0:
		frac = 0.0
	global_position = pa.lerp(pb, frac)
	yaw = lerp_angle(yaw_arr[i], yaw_arr[i2], frac)
	_pivot.rotation.y = yaw + MODEL_YAW_OFFSET

	if i != _last_index:
		_fire_swings(fire_arr, pos_arr, yaw_arr, _last_index + 1, i, count)
		_apply_state_anim(state_arr[i])
		_last_index = i


func _fire_swings(fire_arr: PackedByteArray, pos_arr: PackedVector3Array, yaw_arr: PackedFloat32Array, from_j: int, to_j: int, count: int) -> void:
	var j := from_j
	while j <= to_j:
		if j >= 0 and j < count and fire_arr[j] != 0 and main:
			# fire kind: 2 => heavy, 1 => light. Ghost swings can't riposte.
			main.resolve_swing(pos_arr[j], yaw_arr[j], owner_index, true, null, round_no, fire_arr[j] == 2, false)
		j += 1


func _finish(err: float) -> void:
	if done:
		return
	done = true
	if main:
		main._report_determinism(err, owner_index, round_no)
		main._spawn_fragments(global_position + Vector3(0, 0.9, 0), owner_color)
	visible = false
	queue_free()


func _apply_state_anim(s: int) -> void:
	match s:
		ST_RUN:
			_pivot.scale = Vector3.ONE
			_play("Running_A")
		ST_SWING:
			_pivot.scale = Vector3.ONE
			_play("1H_Melee_Attack_Chop", false)
		ST_HEAVY:
			_pivot.scale = Vector3.ONE
			_play("2H_Melee_Attack_Slice", false)
		ST_CHARGE:
			_pivot.scale = Vector3.ONE * CHARGE_SCALE
			_play("Idle")
		ST_PARRY:
			_pivot.scale = Vector3.ONE
			_play("Blocking")
		ST_DASH:
			_pivot.scale = Vector3.ONE
			_play("Dodge_Forward", false)
		ST_HIT:
			_pivot.scale = Vector3.ONE
			_play("Hit_A", false)
		ST_DEAD:
			_pivot.scale = Vector3.ONE
			_play("Death_A", false)
		_:
			_pivot.scale = Vector3.ONE
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
