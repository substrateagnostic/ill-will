class_name LWPendulum
extends Node3D
## The windmill-blade pendulum. Telegraphs with a red strip across the
## platform + creak, then swings a huge slatted blade through the yard for
## N passes. Contact = a violent lateral launch (usually into the dusk).
## Entirely code-driven (no physics body): the controller calls tick(delta)
## only while the round runs, so the will-draft freeze stops it mid-swing.

const PIVOT_Y := 8.6
const ARM_LEN := 7.7
const SWING_AMP := 0.96      # radians (~55 deg)
const PERIOD := 1.9          # seconds per full left-right-left cycle
const TELEGRAPH_T := 1.6
const RETRACT_T := 0.8
const HIT_PERP := 1.05       # half-width of the lethal strip
const HIT_ALONG := 1.7       # half-length of the blade contact zone
const HIT_Y := 2.1           # blade only bites when its center is low
const KNOCK := 15.0

enum PState { TELEGRAPH, ACTIVE, RETRACT, DONE }

var state: int = PState.TELEGRAPH
var owner_game: Node = null
var sweep_dir := Vector2.RIGHT   # unit, along the swing line
var _t := 0.0
var _swings := 3
var _phase_t := 0.0
var _hit_memo: Dictionary = {}   # pawn index -> last half-cycle stamped

var _pivot: Node3D
var _blade: Node3D
var _strip: MeshInstance3D
var _strip_mat: StandardMaterial3D
var _rise := 0.0

func setup(angle_deg: float, swings: int, p_owner: Node) -> void:
	owner_game = p_owner
	_swings = swings
	var a := deg_to_rad(angle_deg)
	sweep_dir = Vector2(cos(a), sin(a))
	rotation.y = -a   # local +X now points along sweep_dir in world space

	# telegraph strip on the ground along the sweep line
	_strip = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(14.5, 0.06, 2.1)
	_strip.mesh = sm
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_strip_mat.albedo_color = Color(1.0, 0.25, 0.2, 0.3)
	_strip_mat.emission_enabled = true
	_strip_mat.emission = Color(1.0, 0.2, 0.15)
	_strip_mat.emission_energy_multiplier = 1.0
	_strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_strip.material_override = _strip_mat
	_strip.position.y = 0.05
	add_child(_strip)

	# pivot high above the yard; gallows crossbar for silhouette
	_pivot = Node3D.new()
	_pivot.position.y = PIVOT_Y
	add_child(_pivot)

	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(15.0, 0.35, 0.35)
	beam.mesh = bm
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.38, 0.29, 0.24)
	beam_mat.roughness = 0.8
	beam.material_override = beam_mat
	beam.position.y = PIVOT_Y + 0.3
	add_child(beam)

	# arm (chain) + windmill blade
	_blade = Node3D.new()
	_pivot.add_child(_blade)
	var chain := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.16, ARM_LEN, 0.16)
	chain.mesh = cm
	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.6, 0.58, 0.64)
	chain_mat.metallic = 0.5
	chain_mat.roughness = 0.4
	chain.material_override = chain_mat
	chain.position.y = -ARM_LEN / 2.0
	_blade.add_child(chain)

	var plank_mat := StandardMaterial3D.new()
	plank_mat.albedo_color = Color(0.66, 0.48, 0.3)
	plank_mat.roughness = 0.85
	var slat_mat := StandardMaterial3D.new()
	slat_mat.albedo_color = Color(0.85, 0.73, 0.52)
	# windmill sail: main plank + lighter slats, swinging in the local XZ... XY plane
	var plank := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(3.4, 1.5, 0.3)
	plank.mesh = pm
	plank.material_override = plank_mat
	plank.position.y = -ARM_LEN
	_blade.add_child(plank)
	for i in 4:
		var slat := MeshInstance3D.new()
		var slm := BoxMesh.new()
		slm.size = Vector3(0.55, 1.66, 0.34)
		slat.mesh = slm
		slat.material_override = slat_mat
		slat.position = Vector3(-1.28 + i * 0.85, -ARM_LEN, 0.0)
		_blade.add_child(slat)
	# a menacing iron edge along the bottom
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(3.5, 0.16, 0.36)
	edge.mesh = em
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.55, 0.52, 0.58)
	edge_mat.metallic = 0.85
	edge_mat.roughness = 0.25
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(1.0, 0.3, 0.2)
	edge_mat.emission_energy_multiplier = 0.35
	edge.material_override = edge_mat
	edge.position.y = -ARM_LEN - 0.83
	_blade.add_child(edge)

	# start pulled back and high, hidden until telegraph ends
	_blade.rotation.z = SWING_AMP
	_pivot.position.y = PIVOT_Y + 6.0
	_rise = 6.0
	Sfx.play("grudge", -8.0, 0.02)

func blade_world_info() -> Dictionary:
	## center of the blade in world space + swing velocity sign along sweep_dir.
	## theta(t) = A*cos(wt); along = -sin(theta)*L; d(along)/dt has the sign
	## of sin(wt) — victims must be carried in the blade's TRAVEL direction.
	var ang := _blade.rotation.z
	var along := -sin(ang) * ARM_LEN        # local x of blade center
	var y := _pivot.position.y - cos(ang) * ARM_LEN
	var vel_sign := sin(_phase_t * TAU / PERIOD)
	return {"along": along, "y": y, "vel_sign": signf(vel_sign) if absf(vel_sign) > 0.05 else 0.0}

func tick(delta: float) -> void:
	_t += delta
	match state:
		PState.TELEGRAPH:
			var pulse := 0.5 + 0.5 * sin(_t * 11.0)
			_strip_mat.albedo_color.a = 0.14 + 0.3 * pulse
			_strip_mat.emission_energy_multiplier = 0.6 + 1.6 * pulse
			# blade descends into place during the telegraph
			_rise = maxf(0.0, _rise - delta * (6.0 / TELEGRAPH_T))
			_pivot.position.y = PIVOT_Y + _rise
			if _t >= TELEGRAPH_T:
				state = PState.ACTIVE
				_phase_t = 0.0
				_strip_mat.albedo_color.a = 0.10
				_strip_mat.emission_energy_multiplier = 0.5
		PState.ACTIVE:
			_phase_t += delta
			var cycles := _phase_t / PERIOD
			_blade.rotation.z = SWING_AMP * cos(cycles * TAU)
			# whoosh at each nadir crossing
			var half_idx := int(floor(cycles * 2.0 + 0.5))
			if not _hit_memo.has("_whoosh") or int(_hit_memo["_whoosh"]) != half_idx:
				if absf(_blade.rotation.z) < 0.25:
					_hit_memo["_whoosh"] = half_idx
					Sfx.play("bounce", -10.0, 0.15)
			_check_hits(half_idx)
			if cycles >= float(_swings):
				state = PState.RETRACT
				_t = 0.0
		PState.RETRACT:
			_pivot.position.y = PIVOT_Y + (_t / RETRACT_T) * 7.0
			_strip_mat.albedo_color.a = maxf(0.0, 0.1 * (1.0 - _t / RETRACT_T))
			if _t >= RETRACT_T:
				state = PState.DONE
		PState.DONE:
			pass

func _check_hits(half_idx: int) -> void:
	if owner_game == null:
		return
	var info := blade_world_info()
	if float(info.y) > HIT_Y:
		return
	for pawn in owner_game.living_pawns():
		var memo_key: int = pawn.index
		if _hit_memo.get(memo_key, -1) == half_idx:
			continue
		var p := Vector2(pawn.global_position.x, pawn.global_position.z)
		var along := p.dot(sweep_dir)
		var perp := absf(p.dot(Vector2(-sweep_dir.y, sweep_dir.x)))
		if perp > HIT_PERP:
			continue
		if absf(along - float(info.along)) > HIT_ALONG:
			continue
		_hit_memo[memo_key] = half_idx
		var s := float(info.vel_sign)
		if s == 0.0:
			s = 1.0 if along >= 0.0 else -1.0
		var dir := Vector3(sweep_dir.x * s, 0.0, sweep_dir.y * s)
		pawn.hit(dir, KNOCK, "pendulum", -1, "THE PENDULUM", Color(1.0, 0.4, 0.3))
		if owner_game.has_method("on_pendulum_hit"):
			owner_game.on_pendulum_hit(pawn.index)

func is_done() -> bool:
	return state == PState.DONE
