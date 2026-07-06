class_name LWPawn
extends RigidBody3D
## LAST WILL living pawn. KayKit body, snappy sumo control on a shrinking
## circular chapel-yard. A = shove, B = hop (gap-hop the boulder). No HP:
## void fall or boulder squish = eliminated for the round. Blessings and
## curses from the dead modulate this body: shield (eats one hit), swiftness
## (+20%), sluggish (-20%), butterfingers (no shove), haunted (wisp hunts).
##
## World-freeze: during the will-draft theater the controller freezes every
## living pawn (freeze=true + anim speed 0) so the deceased's six seconds
## own the room. Ghost spectators keep swaying — only the living hold still.

const MOVE_SPEED := 5.0
const ACCEL := 42.0
const SHOVE_RANGE := 1.85
const SHOVE_BASE := 8.0
const SHOVE_SPEED_SCALE := 1.4
const SHOVE_CD := 0.7
const HOP_IMPULSE := 6.6
const HOP_CD := 1.1
const STUN_TIME := 0.32
const VOID_Y := -7.0

signal died(index: int, cause: String)

var index := 0
var color := Color.WHITE
var alive := true
var owner_game: Node = null
var last_attacker := {}        # {type, index, name, color, time}

var move_input := Vector2.ZERO
var want_shove := false
var want_hop := false

# --- will effects -------------------------------------------------------
var bless_kind := ""           # "" | "shield" | "swift"
var bless_t := 0.0             # remaining seconds (shield: until hit/round end)
var bless_from := -1
var curse_kind := ""           # "" | "sluggish" | "butterfingers" | "haunted"
var curse_t := 0.0
var curse_from := -1

var world_frozen := false
var _stored_vel := Vector3.ZERO

var _stun := 0.0
var _shove_cd := 0.0
var _hop_cd := 0.0
var _squish_immune := 0.0
var _face := Vector3.FORWARD
var _grounded := false
var safe_spawn := Vector3.ZERO
var grace_until := 0.0

var model_pivot: Node3D
var anim: AnimationPlayer
var ring: MeshInstance3D
var _shield_orb: MeshInstance3D
var _swift_trail: CPUParticles3D
var _curse_drips: CPUParticles3D
var _status_label: Label3D
var _name_label: Label3D
var _cur_anim := ""
var _anim_lock := 0.0

# THE ILL WILL HIT KIT / COOLDOWN RING (docs/design/08-gamefeel-research.md).
# Presentation only — gated behind owner_game.fx_on() so --willtally runs NONE of
# it (the WILL_TALLY receipt stays byte-identical).
var _shove_ring: CooldownRing      # primary (outer) — SHOVE recharge
var _hop_ring: CooldownRing        # secondary (thin inner) — HOP recharge
var _squash_tw: Tween              # owns the coil/stretch/pop scale (one at a time)
var _cap_freeze := false           # --hitkitcap: hold cooldowns/physics for a staged shot

func setup(p_index: int, p_color: Color, p_name: String, char_scene: PackedScene, p_owner: Node) -> void:
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
	collision_layer = 2
	collision_mask = 1 | 2

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
	rmat.emission_energy_multiplier = 0.7
	ring.material_override = rmat
	ring.position.y = 0.03
	add_child(ring)

	# THE COOLDOWN RING — flat, player-colored, concentric just OUTSIDE the
	# identity feet-ring (outer 0.46). Two rings max: SHOVE (primary, outer band)
	# + HOP (secondary, thin inner band). Geometric fill = colorblind-safe.
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

	_name_label = Label3D.new()
	_name_label.text = PlayerBadge.glyph(index) + " " + p_name
	_name_label.font_size = 42
	_name_label.pixel_size = 0.006
	_name_label.modulate = color
	_name_label.outline_size = 10
	_name_label.outline_modulate = Color(0.06, 0.05, 0.09)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, 1.85, 0)
	add_child(_name_label)

	_status_label = Label3D.new()
	_status_label.font_size = 36
	_status_label.pixel_size = 0.006
	_status_label.outline_size = 9
	_status_label.outline_modulate = Color(0.06, 0.05, 0.09)
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.position = Vector3(0, 2.16, 0)
	_status_label.visible = false
	add_child(_status_label)

	_build_effect_fx()

func _build_effect_fx() -> void:
	_shield_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.72
	sm.height = 1.44
	_shield_orb.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(1.0, 0.87, 0.35, 0.22)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.82, 0.3)
	smat.emission_energy_multiplier = 0.7
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_orb.material_override = smat
	_shield_orb.position.y = 0.72
	_shield_orb.visible = false
	add_child(_shield_orb)

	_swift_trail = CPUParticles3D.new()
	_swift_trail.amount = 26
	_swift_trail.lifetime = 0.5
	_swift_trail.local_coords = false
	_swift_trail.direction = Vector3.UP
	_swift_trail.spread = 22.0
	_swift_trail.gravity = Vector3.ZERO
	_swift_trail.initial_velocity_min = 0.4
	_swift_trail.initial_velocity_max = 1.0
	_swift_trail.scale_amount_min = 0.35
	_swift_trail.scale_amount_max = 0.8
	var stm := SphereMesh.new()
	stm.radius = 0.05
	stm.height = 0.1
	_swift_trail.mesh = stm
	var stmat := StandardMaterial3D.new()
	stmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stmat.albedo_color = Color(1.0, 0.9, 0.45, 0.7)
	_swift_trail.material_override = stmat
	_swift_trail.emitting = false
	_swift_trail.position.y = 0.5
	add_child(_swift_trail)

	_curse_drips = CPUParticles3D.new()
	_curse_drips.amount = 20
	_curse_drips.lifetime = 0.8
	_curse_drips.local_coords = false
	_curse_drips.direction = Vector3.DOWN
	_curse_drips.spread = 35.0
	_curse_drips.gravity = Vector3(0, -3.0, 0)
	_curse_drips.initial_velocity_min = 0.1
	_curse_drips.initial_velocity_max = 0.5
	_curse_drips.scale_amount_min = 0.4
	_curse_drips.scale_amount_max = 0.9
	var cdm := SphereMesh.new()
	cdm.radius = 0.05
	cdm.height = 0.1
	_curse_drips.mesh = cdm
	var cdmat := StandardMaterial3D.new()
	cdmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cdmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cdmat.albedo_color = Color(0.45, 0.95, 0.5, 0.65)
	_curse_drips.material_override = cdmat
	_curse_drips.emitting = false
	_curse_drips.position.y = 1.5
	add_child(_curse_drips)

func _tint_model(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = _rim_material()
	for c in node.get_children():
		_tint_model(c)

func _rim_material() -> StandardMaterial3D:
	# a WHISPER of identity color — the KayKit texture must stay readable
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.13)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.12
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

# ---------------------------------------------------------------- effects
func speed_mult() -> float:
	var m := 1.0
	if bless_kind == "swift":
		m *= 1.2
	if curse_kind == "sluggish":
		m *= 0.8
	return m

func apply_bless(kind: String, from_idx: int, duration: float) -> void:
	bless_kind = kind
	bless_from = from_idx
	bless_t = duration
	_shield_orb.visible = (kind == "shield")
	_swift_trail.emitting = (kind == "swift")
	_refresh_status()

func apply_curse(kind: String, from_idx: int, duration: float) -> void:
	curse_kind = kind
	curse_from = from_idx
	curse_t = duration
	_curse_drips.emitting = true
	_refresh_status()

func clear_bless() -> void:
	bless_kind = ""
	bless_from = -1
	bless_t = 0.0
	_shield_orb.visible = false
	_swift_trail.emitting = false
	_refresh_status()

func clear_curse() -> void:
	curse_kind = ""
	curse_from = -1
	curse_t = 0.0
	_curse_drips.emitting = false
	_refresh_status()

## Called by the controller each PHYSICS tick, only while the round runs.
func tick_effects(delta: float) -> void:
	if bless_kind == "swift":
		bless_t -= delta
		if bless_t <= 0.0:
			clear_bless()
	if curse_kind != "" and curse_kind != "haunted":
		# haunted expiry is owned by the wisp
		curse_t -= delta
		if curse_t <= 0.0:
			clear_curse()

func _refresh_status() -> void:
	var lines: Array = []
	if bless_kind == "shield":
		lines.append("SHIELD")
	elif bless_kind == "swift":
		lines.append("SWIFT")
	if curse_kind == "sluggish":
		lines.append("SLUGGISH")
	elif curse_kind == "butterfingers":
		lines.append("NO SHOVE")
	elif curse_kind == "haunted":
		lines.append("HAUNTED")
	_status_label.visible = not lines.is_empty()
	_status_label.text = "\n".join(lines)
	if curse_kind != "" and bless_kind == "":
		_status_label.modulate = Color(0.55, 1.0, 0.55)
	elif bless_kind != "" and curse_kind == "":
		_status_label.modulate = Color(1.0, 0.85, 0.35)
	else:
		_status_label.modulate = Color(0.95, 0.95, 0.9)

## Consume the shield if present. Returns true when the hit was eaten.
func try_shield_block() -> bool:
	if bless_kind != "shield":
		return false
	clear_bless()
	Sfx.play("bounce", -2.0)
	var burst := CPUParticles3D.new()
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector3(0, 0.8, 0)
	burst.one_shot = true
	burst.amount = 24
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.0
	burst.gravity = Vector3(0, -3, 0)
	var bm := SphereMesh.new()
	bm.radius = 0.06
	bm.height = 0.12
	burst.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.85, 0.4)
	burst.material_override = bmat
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
	return true

# ---------------------------------------------------------------- freeze
func set_world_frozen(v: bool) -> void:
	if world_frozen == v or not alive:
		return
	world_frozen = v
	if v:
		_stored_vel = linear_velocity
		freeze = true
		if anim:
			anim.speed_scale = 0.0
	else:
		freeze = false
		linear_velocity = _stored_vel
		if anim:
			anim.speed_scale = 1.0

# ---------------------------------------------------------------- tick
func _physics_process(delta: float) -> void:
	if not alive or world_frozen:
		return
	if _cap_freeze:
		return   # --hitkitcap: hold cooldowns + physics for a staged shot
	if _shove_cd > 0.0: _shove_cd -= delta
	if _hop_cd > 0.0: _hop_cd -= delta
	if _squish_immune > 0.0: _squish_immune -= delta

	_grounded = global_position.y < 0.15 and absf(linear_velocity.y) < 1.5
	if _stun <= 0.0 and _grounded and speed() < 2.0 and not last_attacker.is_empty():
		last_attacker = {}

	if _stun > 0.0:
		_stun -= delta
	else:
		var desired := Vector3(move_input.x, 0.0, move_input.y) * MOVE_SPEED * speed_mult()
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

	# anti-tunnel: over the current platform footprint you can never be below
	# its surface (Jolt slab lesson from Dead Weight, adapted to the circle)
	var flat_r := Vector2(global_position.x, global_position.z).length()
	if global_position.y < -0.6 and owner_game != null and flat_r < owner_game.platform_radius - 0.05:
		global_position.y = 0.05
		linear_velocity.y = maxf(linear_velocity.y, 0.0)

	if global_position.y < VOID_Y:
		if owner_game != null and owner_game.game_time < grace_until:
			global_position = safe_spawn
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_stun = 0.0
		else:
			_die("void")

func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()

func _do_shove() -> void:
	if _shove_cd > 0.0 or owner_game == null:
		return
	if curse_kind == "butterfingers":
		Sfx.play("invalid", -6.0)
		return
	_shove_cd = SHOVE_CD
	# HIT KIT §B1 Phase 1 — windup whoosh (the thud is layered on connect in the
	# controller's on_shove_landed).
	Sfx.play("bounce", -7.0)
	_cur_anim = "Interact"
	if anim and anim.has_animation("Interact"):
		anim.play("Interact")
	_anim_lock = 0.35
	# READABILITY (presentation only — no change to range/power/timing): flash a
	# directional arc so you can see WHEN the shove fires and WHERE it reaches.
	# This is the KIT's swing-arc element (already in-tree); the coil below adds
	# the anticipation, and the victim pop/spark land in hit().
	if owner_game != null and owner_game.has_method("on_shove_fired"):
		owner_game.on_shove_fired(global_position, _face, color)
	var power := SHOVE_BASE + speed() * SHOVE_SPEED_SCALE
	var hit_any := false
	for other in owner_game.living_pawns():
		if other == self or not other.alive:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		if to.length() > SHOVE_RANGE:
			continue
		if _face.dot(to.normalized()) < 0.0:
			continue
		other.call_deferred("hit", to, power, "shove", index, owner_game.player_name(index), color)
		hit_any = true
	# HIT KIT windup coil (chunky crouch); a landed shove adds a forward
	# follow-through stretch for mass. Visual only — hitbox already resolved.
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

func is_grounded() -> bool:
	return _grounded

func hit(dir: Vector3, impulse: float, atk_type: String, atk_index: int, src_name: String, atk_color: Color) -> void:
	if not alive or world_frozen:
		return
	if try_shield_block():
		if owner_game != null and owner_game.has_method("on_shield_break"):
			owner_game.on_shield_break(index)
		return
	dir.y = 0.0
	var d := dir.normalized()
	apply_central_impulse(d * impulse + Vector3.UP * impulse * 0.14)
	_stun = STUN_TIME
	var t := 0.0
	if owner_game != null:
		t = owner_game.game_time
	last_attacker = {"type": atk_type, "index": atk_index, "name": src_name, "color": atk_color, "time": t}
	# HIT KIT §B1 Phase 2 — victim squash-pop + spark burst along the knockback
	# (kept even under reduced-motion). Gated off in --willtally.
	if _visuals_on():
		flash_pop()
		if owner_game.has_method("spark_at"):
			var strength := clampf(impulse / (SHOVE_BASE + 5.0 * SHOVE_SPEED_SCALE), 0.5, 1.5)
			owner_game.spark_at(global_position + Vector3(0, 0.9, 0) - d * 0.3, d, atk_color, strength)

# --- THE ILL WILL HIT KIT (presentation; gated behind owner_game.fx_on()) ---
func _visuals_on() -> bool:
	return owner_game != null and owner_game.has_method("fx_on") and owner_game.fx_on()

## HIT KIT §B1 Phase 1 — WINDUP coil (chunky crouch). A landed shove adds a
## forward follow-through stretch along facing (model_pivot local +Z); then
## settles. One tween owns the scale so pop/coil never fight. Visual only.
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
## cooldown timers. Hidden during a will-draft world-freeze and once idle-ready.
func _drive_rings(delta: float) -> void:
	if _shove_ring == null:
		return
	var reduced := not bool(PartySetup.pref("screen_shake", true))
	var active := alive and not world_frozen
	_shove_ring.tick(delta, clampf(1.0 - _shove_cd / SHOVE_CD, 0.0, 1.0), active, reduced)
	_hop_ring.tick(delta, clampf(1.0 - _hop_cd / HOP_CD, 0.0, 1.0), active, reduced)

## A soft push (ghost gust). Never blocked by shield; small, aimable spite.
func gust_push(dir: Vector3, impulse: float, ghost_index: int, ghost_name: String, ghost_color: Color) -> void:
	if not alive or world_frozen:
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var gd := dir.normalized()
	apply_central_impulse(gd * impulse + Vector3.UP * 0.8)
	var t := 0.0
	if owner_game != null:
		t = owner_game.game_time
	last_attacker = {"type": "gust", "index": ghost_index, "name": ghost_name, "color": ghost_color, "time": t}
	# A gust is SOFT spite — a small readability spark only (NO hitstop, NO pop,
	# per the research table). Gated off in --willtally.
	if _visuals_on() and owner_game.has_method("spark_at"):
		owner_game.spark_at(global_position + Vector3(0, 0.8, 0) - gd * 0.3, gd, ghost_color, 0.5)

## Haunted wisp contact: a stumble, not a launch.
func stumble() -> void:
	if not alive or world_frozen:
		return
	_stun = 0.55
	linear_velocity = Vector3(linear_velocity.x * 0.2, linear_velocity.y, linear_velocity.z * 0.2)
	_cur_anim = "Hit_A"
	if anim and anim.has_animation("Hit_A"):
		anim.play("Hit_A")
	_anim_lock = 0.45
	Sfx.play("splat", -8.0)

func squish() -> void:
	if not alive or _squish_immune > 0.0:
		return
	if try_shield_block():
		# the shield converts a squish into a shove away from the boulder
		_squish_immune = 0.9
		apply_central_impulse(Vector3(-_face.x, 0.6, -_face.z).normalized() * 7.0)
		if owner_game != null and owner_game.has_method("on_shield_break"):
			owner_game.on_shield_break(index)
		return
	# flatten the body for the beat before it disappears
	if model_pivot:
		var tw := create_tween()
		tw.tween_property(model_pivot, "scale:y", 0.12, 0.09)
	_die("squish")

func _process(delta: float) -> void:
	if _visuals_on():
		_drive_rings(delta)
	if alive and not world_frozen:
		_update_anim(delta)
		if _shield_orb.visible:
			var s := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.06
			_shield_orb.scale = Vector3(s, s, s)

func _die(cause: String) -> void:
	if not alive:
		return
	alive = false
	died.emit(index, cause)
	call_deferred("_disable_body")

func _disable_body() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	visible = false

func revive(pos: Vector3) -> void:
	alive = true
	world_frozen = false
	freeze = true
	visible = true
	global_position = pos
	safe_spawn = pos + Vector3(0, 0.1, 0)
	if owner_game != null:
		grace_until = owner_game.game_time + 1.5
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_stored_vel = Vector3.ZERO
	_stun = 0.0
	_shove_cd = 0.0
	_hop_cd = 0.0
	last_attacker = {}
	collision_layer = 2
	collision_mask = 1 | 2
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
	if anim:
		anim.speed_scale = 1.0
	clear_bless()
	clear_curse()
	_set_anim("Idle")
	call_deferred("set", "freeze", false)
