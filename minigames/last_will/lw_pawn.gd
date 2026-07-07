class_name LWPawn
extends RigidBody3D
## LAST WILL racer. KayKit body, snappy sumo control, now pointed down a
## funeral procession course. A = shove, B = hop (gap-hop the ossuary ridge,
## hop the boulder). No HP: void fall or boulder squish costs a LIFE — and
## buys the beloved six-second WILL DRAFT.
##
## Terrain/curse modifiers are pushed by the controller each physics tick
## (terrain_speed / terrain_accel reset to 1.0 before curses apply), so the
## pawn itself stays dumb about what a greased flagstone is.
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
var last_curse := {}           # {author, slug, name, color, time} — curse touch

var move_input := Vector2.ZERO
var want_shove := false
var want_hop := false

# --- terrain / curse modifiers (controller-owned, reset each tick) --------
var terrain_speed := 1.0
var terrain_accel := 1.0

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

# ONLINE wire facts (phase 2): pure counters the mirror diffs for impact
# juice. The sim never reads them; --willtally receipts stay byte-identical.
var net_hits := 0
var net_hit_dir := Vector3.ZERO
var net_shoves := 0

var model_pivot: Node3D
var anim: AnimationPlayer
var ring: MeshInstance3D
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
	_name_label.pixel_size = 0.0072
	_name_label.modulate = color
	_name_label.outline_size = 10
	_name_label.outline_modulate = Color(0.06, 0.05, 0.09)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, 1.85, 0)
	add_child(_name_label)

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

## Stamped by course curses on contact/exposure so a death within 3s pays the
## author royalties (cause = the curse slug in kill_events).
func note_curse_touch(author: int, slug: String, author_name: String, author_color: Color) -> void:
	var t := 0.0
	if owner_game != null:
		t = owner_game.game_time
	last_curse = {"author": author, "slug": slug, "name": author_name,
		"color": author_color, "time": t}

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
		var desired := Vector3(move_input.x, 0.0, move_input.y) * MOVE_SPEED * terrain_speed
		var v := linear_velocity
		var acc := ACCEL * terrain_accel * delta
		v.x = move_toward(v.x, desired.x, acc)
		v.z = move_toward(v.z, desired.z, acc)
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

	# anti-tunnel: over solid road you can never be below its surface
	# (Jolt slab lesson from Dead Weight, adapted to the procession spine)
	if global_position.y < -0.6 and owner_game != null \
			and owner_game.over_ground(global_position):
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
	_shove_cd = SHOVE_CD
	net_shoves += 1   # wire fact (whiffs included — the couch whooshes both)
	# HIT KIT §B1 Phase 1 — windup whoosh (the thud is layered on connect in the
	# controller's on_shove_landed).
	Sfx.play("bounce", -7.0)
	_cur_anim = "Interact"
	if anim and anim.has_animation("Interact"):
		anim.play("Interact")
	_anim_lock = 0.35
	# READABILITY (presentation only — no change to range/power/timing): flash a
	# directional arc so you can see WHEN the shove fires and WHERE it reaches.
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
	dir.y = 0.0
	var d := dir.normalized()
	net_hits += 1     # wire fact: the mirror fires pop/spark off this counter
	net_hit_dir = d
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

## A soft push (ghost gust / gust corridor). Small, aimable spite.
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

func squish() -> void:
	if not alive or _squish_immune > 0.0:
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

func celebrate() -> void:
	## The finisher holds the crypt doorstep: frozen in place, cheering.
	freeze = true
	linear_velocity = Vector3.ZERO
	move_input = Vector2.ZERO
	_anim_lock = 999.0
	_cur_anim = "Cheer"
	if anim and anim.has_animation("Cheer"):
		anim.get_animation("Cheer").loop_mode = Animation.LOOP_LINEAR
		anim.play("Cheer")

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
	_squish_immune = 0.9
	last_attacker = {}
	last_curse = {}
	terrain_speed = 1.0
	terrain_accel = 1.0
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
	_set_anim("Idle")
	call_deferred("set", "freeze", false)
