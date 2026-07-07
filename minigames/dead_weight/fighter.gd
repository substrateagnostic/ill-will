class_name DWFighter
extends RigidBody3D
## A living sumo brawler wearing a KayKit body. Snappy 5 m/s control, A = shove
## (knockback scales with your speed), B = hop. No HP: you die by leaving the
## floor and falling into the void gutter. On death the controller turns you
## into a poltergeist.

const MOVE_SPEED := 5.0
const ACCEL := 42.0
const SHOVE_RANGE := 1.9
const SHOVE_ARC := 0.0         # dot() threshold: target must be in the front hemisphere
const SHOVE_BASE := 8.0
const SHOVE_SPEED_SCALE := 1.5
const SHOVE_CD := 0.7
const HOP_IMPULSE := 5.0
const HOP_CD := 1.5
const STUN_TIME := 0.32
const VOID_Y := -5.0        # below the floor slab (bottom at y=-3); only edge falls reach here

signal fell(index: int)

var index := 0
var color := Color.WHITE
var alive := true
var owner_game: Node = null
var last_attacker := {}        # {type, index, name, color, time}

var move_input := Vector2.ZERO
var want_shove := false
var want_hop := false
var aim_face := Vector3.ZERO   # KBM cursor dir; ZERO => use walk-facing (bots/non-KBM)

var _stun := 0.0
var _shove_cd := 0.0
var _hop_cd := 0.0
var _face := Vector3.FORWARD
var _grounded := false
var safe_spawn := Vector3.ZERO
var grace_until := 0.0

# ONLINE mirror facts (docs/design/10 §4.3): pure counters/tags read by the
# host's _net_state() so the client fires the same juice from deltas. Additive
# only — never consulted by the sim, so --dwbalance receipts are untouched.
var net_shoves := 0            # shoves actually fired (whiffs included)
var net_hits := 0              # times this body took a hit()
var net_hit_dir := Vector3.FORWARD   # knockback dir of the last hit (for sparks)

var model_pivot: Node3D
var anim: AnimationPlayer
var ring: MeshInstance3D
var _cur_anim := ""
var _anim_lock := 0.0

# THE ILL WILL HIT KIT / COOLDOWN RING (docs/design/08-gamefeel-research.md).
# Presentation only — all gated behind owner_game.fx_on() so the reproducible
# --dwbalance sim runs NONE of it (byte-identical determinism receipt).
var _shove_ring: CooldownRing      # primary (outer) — SHOVE recharge
var _hop_ring: CooldownRing        # secondary (thin inner) — HOP recharge
var _squash_tw: Tween              # owns the coil/stretch/pop scale (one at a time)
var _cap_freeze := false           # --hitkitcap: hold cooldowns/physics for a staged shot

func setup(p_index: int, p_color: Color, char_scene: PackedScene, p_owner: Node) -> void:
	index = p_index
	color = p_color
	owner_game = p_owner
	mass = 1.5
	gravity_scale = 1.0
	continuous_cd = true
	can_sleep = false
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	linear_damp = 0.0
	collision_layer = 2                 # fighters
	collision_mask = 1 | 2 | 4          # floor, fighters, props
	add_to_group("dw_fighters")

	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.05
	physics_material_override = pm

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var caps := CapsuleShape3D.new()
	caps.radius = 0.32
	caps.height = 1.1
	shape.shape = caps
	shape.position.y = 0.55
	add_child(shape)

	# identity ring at the feet
	ring = MeshInstance3D.new()
	ring.name = "Ring"
	var rmesh := CylinderMesh.new()
	rmesh.top_radius = 0.42
	rmesh.bottom_radius = 0.46
	rmesh.height = 0.04
	ring.mesh = rmesh
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = 0.6
	ring.material_override = rmat
	ring.position.y = 0.03
	add_child(ring)

	# THE COOLDOWN RING — flat, player-colored, concentric just OUTSIDE the
	# identity feet-ring (outer 0.46). Geometric fill = colorblind-safe. Two
	# rings max: SHOVE (primary, outer band) + HOP (secondary, thin inner band).
	_shove_ring = CooldownRing.new()
	add_child(_shove_ring)
	_shove_ring.setup(color, 0.64, 0.56, 0.045, 0.9)
	_hop_ring = CooldownRing.new()
	add_child(_hop_ring)
	_hop_ring.setup(color, 0.53, 0.475, 0.045, 0.9)

	model_pivot = Node3D.new()
	model_pivot.name = "ModelPivot"
	add_child(model_pivot)
	if char_scene != null:
		var body := char_scene.instantiate()
		body.scale = Vector3(0.95, 0.95, 0.95)
		model_pivot.add_child(body)
		anim = body.find_child("AnimationPlayer", true, false)
		_tint_model(body)
		_loop("Idle")
		_loop("Running_A")
		_set_anim("Idle")

func _tint_model(node: Node) -> void:
	# add a rim of identity color so team read is instant even at distance
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.rim_enabled = true
		m.rim = 0.6
		m.rim_tint = 0.9
		# leave the KayKit texture but push a colored rim via emission-ish tint
		mi.material_overlay = _rim_material()
	for c in node.get_children():
		_tint_model(c)

func _rim_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.28)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	m.rim = 0.8
	return m

func _loop(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func _set_anim(n: String) -> void:
	if anim == null or _cur_anim == n or not anim.has_animation(n):
		return
	_cur_anim = n
	anim.play(n)

func _update_anim(delta: float) -> void:
	if anim == null:
		return
	if _anim_lock > 0.0:
		_anim_lock -= delta
		return
	if _stun > 0.0:
		_set_anim("Hit_A")
	elif not _grounded:
		_set_anim("Jump_Idle")
	elif speed() > 0.7:
		_set_anim("Running_A")
	else:
		_set_anim("Idle")

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _cap_freeze:
		return   # --hitkitcap: hold cooldowns + physics for a staged shot
	if _shove_cd > 0.0: _shove_cd -= delta
	if _hop_cd > 0.0: _hop_cd -= delta

	# ground check + attacker-forgiveness on the PHYSICS tick so seeded runs
	# stay reproducible (frame timing must never affect gameplay state).
	# Whoever last hit you stays on the hook until you're genuinely safe:
	# grounded, unstunned, AND no longer sliding — a blow that skids you off
	# the lip still counts even though your feet never left the floor.
	_grounded = global_position.y < 0.15 and absf(linear_velocity.y) < 1.5
	if _stun <= 0.0 and _grounded and speed() < 2.0 and not last_attacker.is_empty():
		last_attacker = {}

	if _stun > 0.0:
		_stun -= delta
	else:
		var desired := Vector3(move_input.x, 0.0, move_input.y) * MOVE_SPEED
		var v := linear_velocity
		v.x = move_toward(v.x, desired.x, ACCEL * delta)
		v.z = move_toward(v.z, desired.z, ACCEL * delta)
		linear_velocity = Vector3(v.x, linear_velocity.y, v.z)
		if desired.length() > 0.2:
			_face = desired.normalized()
			if model_pivot:
				var target_yaw := atan2(_face.x, _face.z)
				model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))

	if want_shove:
		want_shove = false
		_do_shove()
	if want_hop:
		want_hop = false
		_do_hop()

	# hard safety net: a fighter standing over the floor footprint can NEVER be
	# below its surface (Jolt can shove bodies down through the slab when two
	# capsules ram or a heavy prop slams them). Only past the ±6 lip may you sink.
	if global_position.y < -0.6 and absf(global_position.x) < 5.9 and absf(global_position.z) < 5.9:
		global_position.y = 0.05
		linear_velocity.y = maxf(linear_velocity.y, 0.0)

	if global_position.y < VOID_Y:
		# grace at round start: spawn jank rescues instead of killing
		if owner_game != null and owner_game.game_time < grace_until:
			global_position = safe_spawn
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_stun = 0.0
		else:
			_fall()

func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()

func _do_shove() -> void:
	if _shove_cd > 0.0 or owner_game == null:
		return
	_shove_cd = SHOVE_CD
	net_shoves += 1
	# KBM humans shove toward the cursor: point _face at the aim (so the cone AND
	# the body face it) for this shove. Bots / non-KBM leave aim_face ZERO and
	# keep their walk-derived _face exactly as before.
	if aim_face != Vector3.ZERO:
		_face = aim_face.normalized()
		if model_pivot:
			model_pivot.rotation.y = atan2(_face.x, _face.z)
	# HIT KIT §B1 Phase 1 — windup whoosh (thud is layered on connect in the
	# controller's on_shove_landed). Readability arc telegraphs WHEN + WHERE.
	Sfx.play("bounce", -7.0)
	if owner_game.has_method("on_shove_fired"):
		owner_game.on_shove_fired(global_position, _face, color)
	_cur_anim = "Interact"
	if anim and anim.has_animation("Interact"):
		anim.play("Interact")
	_anim_lock = 0.35
	var my_speed := speed()
	var power := SHOVE_BASE + my_speed * SHOVE_SPEED_SCALE
	var hit_any := false
	for other in owner_game.living_fighters():
		if other == self or not other.alive:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		if to.length() > SHOVE_RANGE:
			continue
		if _face.dot(to.normalized()) < SHOVE_ARC:
			continue
		other.call_deferred("hit", to, power, "player", index, "%s" % name, color)
		hit_any = true
	# also shove nearby free props so the arena stays kinetic
	for prop in owner_game.props():
		if prop.possessed_by >= 0:
			continue
		var pto: Vector3 = prop.global_position - global_position
		pto.y = 0.0
		if pto.length() <= SHOVE_RANGE and _face.dot(pto.normalized()) >= SHOVE_ARC:
			prop.apply_central_impulse(pto.normalized() * power * 0.5 + Vector3.UP * 0.5)
	# HIT KIT windup coil (chunky crouch); a landed shove adds a forward
	# follow-through stretch for mass. Visual only — the hitbox already resolved.
	windup_coil(hit_any)
	if hit_any and owner_game.has_method("on_shove_landed"):
		owner_game.on_shove_landed(global_position)

func _do_hop() -> void:
	if _hop_cd > 0.0 or not _grounded:
		return
	_hop_cd = HOP_CD
	Sfx.play("putt", -6.0)
	_cur_anim = "Jump_Start"
	if anim and anim.has_animation("Jump_Start"):
		anim.play("Jump_Start")
	_anim_lock = 0.3
	apply_central_impulse(Vector3.UP * HOP_IMPULSE)

func hit(dir: Vector3, impulse: float, atk_type: String, atk_index: int, src_name: String, atk_color: Color) -> void:
	if not alive:
		return
	dir.y = 0.0
	var d := dir.normalized()
	apply_central_impulse(d * impulse + Vector3.UP * impulse * 0.14)
	_stun = STUN_TIME
	net_hits += 1
	net_hit_dir = d
	var t := 0.0
	if owner_game != null:
		t = owner_game.game_time
	last_attacker = {"type": atk_type, "index": atk_index, "name": src_name, "color": atk_color, "time": t}
	# HIT KIT §B1 Phase 2 — victim squash-pop + spark burst along the knockback
	# (kept even under reduced-motion; a read, not a shake). Covers shoves AND
	# ghost-fling hits (both route through here). Gated off in the balance sim.
	if _visuals_on():
		flash_pop()
		if owner_game.has_method("spark_at"):
			var strength := clampf(impulse / (SHOVE_BASE + 5.0 * SHOVE_SPEED_SCALE), 0.5, 1.5)
			owner_game.spark_at(global_position + Vector3(0, 0.9, 0) - d * 0.3, d, atk_color, strength)

# --- THE ILL WILL HIT KIT (presentation; gated behind owner_game.fx_on()) ---
func _visuals_on() -> bool:
	return owner_game != null and owner_game.has_method("fx_on") and owner_game.fx_on()

## HIT KIT §B1 Phase 1 — WINDUP coil (chunky crouch). A landed shove adds a
## forward follow-through stretch along facing (model_pivot local +Z) for mass;
## then settles. One tween owns the scale, so pop/coil never fight. Visual only.
func windup_coil(landed := false) -> void:
	if model_pivot == null or not _visuals_on():
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_squash_tw = create_tween()
	_squash_tw.tween_property(model_pivot, "scale", Vector3(1.08, 0.90, 1.08), 0.05)
	if landed:
		_squash_tw.tween_property(model_pivot, "scale", Vector3(0.92, 1.0, 1.12), 0.06)
	_squash_tw.tween_property(model_pivot, "scale", Vector3.ONE, 0.11) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## HIT KIT §B1 Phase 2 — victim impact pop (flatten wide, snap back over 0.16s).
func flash_pop() -> void:
	if model_pivot == null or not _visuals_on():
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	model_pivot.scale = Vector3(1.22, 0.85, 1.22)
	_squash_tw = create_tween()
	_squash_tw.tween_property(model_pivot, "scale", Vector3.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## THE COOLDOWN RING — SHOVE (outer) + HOP (thin inner) fill 0->ready off their
## cooldown timers. Geometry = colorblind-safe; hides itself once idle-ready.
func _drive_rings(delta: float) -> void:
	if _shove_ring == null:
		return
	var reduced := not bool(PartySetup.pref("screen_shake", true))
	_shove_ring.tick(delta, clampf(1.0 - _shove_cd / SHOVE_CD, 0.0, 1.0), alive, reduced)
	_hop_ring.tick(delta, clampf(1.0 - _hop_cd / HOP_CD, 0.0, 1.0), alive, reduced)

func _process(delta: float) -> void:
	if alive:
		_update_anim(delta)
	if _visuals_on():
		_drive_rings(delta)

func _fall() -> void:
	if not alive:
		return
	alive = false
	fell.emit(index)
	call_deferred("_disable_body")

func _disable_body() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	visible = false

func revive(pos: Vector3) -> void:
	alive = true
	freeze = true
	visible = true
	global_position = pos
	safe_spawn = pos + Vector3(0, 0.1, 0)
	if owner_game != null:
		grace_until = owner_game.game_time + 1.5
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_stun = 0.0
	_shove_cd = 0.0
	_hop_cd = 0.0
	last_attacker = {}
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	_anim_lock = 0.0
	_cur_anim = ""
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	if model_pivot:
		model_pivot.scale = Vector3.ONE
	if _shove_ring:
		_shove_ring.tick(0.0, 1.0, false, false)   # force-hide the cooldown rings
	if _hop_ring:
		_hop_ring.tick(0.0, 1.0, false, false)
	_set_anim("Idle")
	call_deferred("set", "freeze", false)
