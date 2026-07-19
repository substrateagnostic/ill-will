class_name DWFighter
extends RigidBody3D
## A living sumo brawler wearing a KayKit body. Snappy 5 m/s control. No HP:
## you die by leaving the floor and falling into the void gutter. On death the
## controller turns you into a poltergeist.
##
## M4 MOVESET (playtest-requested, producer-ruled: "a brace and a dash for
## skilled maneuvers, maybe a super smash" — the ghost furniture-fling stays
## EXACTLY as shipped; these tools are the living's counterweight). Stays
## inside the house `move + A + B` verb budget (docs/design/16 §0 — no third
## button anywhere in this anthology) via tap/hold split, echoing
## echo_chamber's own A/B split (docs/design/08-gamefeel-research.md):
##   A tap                -> SHOVE (unchanged)
##   A hold ~1.7-1.9s      -> charge (grow/glow telegraph) -> auto-fires
##                            SUPER SMASH, a radial shove with no facing gate
##   B tap                -> HOP (unchanged)
##   B hold >=0.15s        -> BRACE: rooted, heavy knockback resistance,
##                            stamina-capped (auto-releases), briefly MORE
##                            vulnerable right after release (no turtling)
##   quick double-tap of a MOVE direction -> DASH: a short velocity burst,
##                            cooldown-ringed, no i-frames (dodge by spacing,
##                            not invulnerability), no phase-through of bodies
## Bots drive the same functions through one-shot `want_*` triggers (below)
## instead of held buttons, using dead_weight.gd's seeded rng for policy —
## see `_bot_living()` there. Getting hit drops an in-progress smash charge
## (never a brace — resistance is the whole point of holding one).

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
const FLOOR_HALF := 6.0     # matches dead_weight.gd's FLOOR_HALF: the floor's
                             # real ±6 footprint. Nothing legitimate stands past it.

# ---- M4 MOVESET: SUPER SMASH (A-hold charge -> radial shove) --------------
const SMASH_ARM_T := 0.16      # A-hold past this commits to charging (below = a normal tap shove)
const SMASH_CHARGE_T := 1.7    # charge duration once armed; auto-fires at completion
                                # (total real hold ~1.86s -- house spec "hold A ~1.5-2s")
const SMASH_CD := 6.5          # long cooldown after firing (~9x SHOVE_CD -- an occasional bomb, not a spam tool)
const SMASH_RANGE := 2.6       # radial burst radius -- NO facing/arc gate (unlike SHOVE_ARC)
const SMASH_BASE := 17.0       # base knockback, roughly 2x SHOVE_BASE
const SMASH_SPEED_SCALE := 1.5 # matches SHOVE_SPEED_SCALE
const SMASH_SCALE_PEAK := 1.24 # model_pivot grow at full charge (the "grow" telegraph)

# ---- M4 MOVESET: BRACE (B-hold -> plant) -----------------------------------
const BRACE_THRESHOLD := 0.15   # B-hold past this commits to bracing (below = a normal tap hop)
const BRACE_MAX_HOLD := 2.2     # stamina cap; forced release past this (no turtling forever)
const BRACE_CD := 1.6           # cooldown before re-braceable
const BRACE_VULN_T := 0.3       # extra-vulnerable window right after ANY brace release
const BRACE_KNOCK_FACTOR := 0.3 # knockback multiplier while actively braced (70% resisted)
const BRACE_VULN_FACTOR := 1.35 # knockback multiplier during the post-release vulnerable window

# ---- M4 MOVESET: DASH (double-tap a MOVE direction -> burst) --------------
const DASH_SPEED := 10.5        # constant-velocity burst speed while dashing
const DASH_TIME := 0.2          # burst duration
const DASH_CD := 1.2            # cooldown ring
const DASH_TAP_WINDOW := 0.32   # max gap between two same-direction taps to register a dash
const DASH_TAP_MIN := 0.35      # move_input magnitude that counts as a directional "tap"

const RING_BASE_EMISSION := 0.6 # the identity ring's normal emission (BRACE pulses off this)

signal fell(index: int)

var index := 0
var color := Color.WHITE
var alive := true
var owner_game: Node = null
var last_attacker := {}        # {type, index, name, color, time}
var bot_driven := false        # set once by dead_weight.gd:_begin() — gates the
                                # human-only double-tap DASH gesture detector

var move_input := Vector2.ZERO
var want_shove := false        # one-shot tap trigger (bots + verify probes)
var want_hop := false          # one-shot tap trigger (bots + verify probes)
var want_dash := false         # one-shot trigger (bots); humans double-tap MOVE instead
var want_smash := false        # one-shot: bot commits to a full smash charge right now
var want_brace := false        # one-shot: bot commits to a full brace right now
var a_down := false            # HUMAN raw A held state (bots leave this false)
var b_down := false            # HUMAN raw B held state (bots leave this false)
var aim_face := Vector3.ZERO   # KBM cursor dir; ZERO => use walk-facing (bots/non-KBM)

var _stun := 0.0
var _shove_cd := 0.0
var _hop_cd := 0.0
var _face := Vector3.FORWARD
var _grounded := false
var safe_spawn := Vector3.ZERO
var grace_until := 0.0
var _oob_time := 0.0   # off-map safe-spot fix: seconds spent "grounded" while
                        # beyond the real floor edge (see FLOOR_HALF below)

# ---- M4 MOVESET state ----
var _a_prev := false
var _a_active := false
var _a_hold := 0.0
var _charging_smash := false
var _smash_charge_t := 0.0
var _smash_cd := 0.0

var _b_prev := false
var _b_active := false
var _b_hold := 0.0
var _bracing := false
var _brace_t := 0.0            # stamina spent this hold
var _brace_cd := 0.0
var _brace_vuln := 0.0         # >0 = the post-release vulnerable window is active

var _dash_t := -1.0            # >=0 while a dash burst is in flight
var _dash_dir := Vector3.FORWARD
var _dash_cd := 0.0
var _move_was_active := false  # rising-edge tracker for the double-tap-dash gesture
var _dash_tap_t := -1.0        # seconds since the last qualifying directional tap (-1 = none pending)
var _dash_tap_dir := Vector3.ZERO

# ONLINE mirror facts (docs/design/10 §4.3): pure counters/tags read by the
# host's _net_state() so the client fires the same juice from deltas. Additive
# only — never consulted by the sim, so --dwbalance receipts are untouched.
var net_shoves := 0            # shoves actually fired (whiffs included)
var net_hits := 0              # times this body took a hit()
var net_hit_dir := Vector3.FORWARD   # knockback dir of the last hit (for sparks)
var net_dashes := 0            # dashes fired (M4 mirror fact)
var net_smashes := 0           # super smashes FIRED, whiffs included (M4 mirror fact,
                                # mirrors net_shoves' own semantics — landed-hit juice
                                # already rides the generic net_hits delta below)

var model_pivot: Node3D
var anim: AnimationPlayer
var ring: MeshInstance3D
var _ring_mat: StandardMaterial3D  # the identity ring's material (brace pulses its emission)
var _cur_anim := ""
var _anim_lock := 0.0

# THE ILL WILL HIT KIT / COOLDOWN RING (docs/design/08-gamefeel-research.md).
# Presentation only — all gated behind owner_game.fx_on() so the reproducible
# --dwbalance sim runs NONE of it (byte-identical determinism receipt).
var _shove_ring: CooldownRing      # primary (outer) — SHOVE recharge
var _hop_ring: CooldownRing        # secondary (thin inner) — HOP recharge
# M4: DASH earns its own ring (a frequent, spammable tool — the anti-goal's
# "≤2 rings" budget is a clutter guard, not a body count; BRACE and SUPER
# SMASH deliberately do NOT get rings (see _start_brace/_set_smash_visual
# doc comments below) so the total stays exactly 3, one per verb-family
# (A, B, MOVE), never 5.
var _dash_ring: CooldownRing       # M4 — DASH recharge
var _squash_tw: Tween              # owns the coil/stretch/pop scale (one at a time)
var _cap_freeze := false           # --hitkitcap: hold cooldowns/physics for a staged shot

# M4 SUPER SMASH charge telegraph: swaps every mesh's identity-rim overlay for
# a shared red-hot overlay (Echo's exact `_set_charge_visual` values) while
# charging, then restores each mesh's OWN rim material — never a flat
# full-body recolor (house rule: doc 08 §D "do not over-tint the models").
var _mesh_instances: Array = []
var _rim_mats: Array = []          # parallel to _mesh_instances: each one's normal rim material
var _charge_overlay: StandardMaterial3D

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
	rmat.emission_energy_multiplier = RING_BASE_EMISSION
	ring.material_override = rmat
	ring.position.y = 0.03
	add_child(ring)
	_ring_mat = rmat

	# THE COOLDOWN RING — flat, player-colored, concentric just OUTSIDE the
	# identity feet-ring (outer 0.46). SHOVE (primary, outer) + HOP (secondary,
	# thin inner), unchanged since the HIT KIT lane. M4 adds DASH one band
	# further out (0.665-0.74) — see the class doc comment on _dash_ring.
	_shove_ring = CooldownRing.new()
	add_child(_shove_ring)
	_shove_ring.setup(color, 0.64, 0.56, 0.045, 0.9)
	_hop_ring = CooldownRing.new()
	add_child(_hop_ring)
	_hop_ring.setup(color, 0.53, 0.475, 0.045, 0.9)
	_dash_ring = CooldownRing.new()
	add_child(_dash_ring)
	_dash_ring.setup(color, 0.74, 0.665, 0.045, 0.9)

	# M4 SUPER SMASH charge overlay — Echo's exact red-hot values
	# (echo_chamber/fighter.gd:184-188), reused verbatim per the brief's
	# "exactly the echo/house telegraph language."
	_charge_overlay = StandardMaterial3D.new()
	_charge_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_charge_overlay.albedo_color = Color(1.0, 0.28, 0.16, 0.42)
	_charge_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_charge_overlay.emission_enabled = true
	_charge_overlay.emission = Color(1.0, 0.22, 0.1)
	_charge_overlay.emission_energy_multiplier = 0.6

	model_pivot = Node3D.new()
	model_pivot.name = "ModelPivot"
	add_child(model_pivot)
	if char_scene != null:
		var body := char_scene.instantiate()
		body.scale = Vector3(0.95, 0.95, 0.95)
		model_pivot.add_child(body)
		anim = body.find_child("AnimationPlayer", true, false)
		_tint_model(body)
		_collect_meshes(body)
		_loop("Idle")
		_loop("Running_A")
		_set_anim("Idle")

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_instances.append(node)
		_rim_mats.append((node as MeshInstance3D).material_overlay)
	for c in node.get_children():
		_collect_meshes(c)

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
	# BRACE always wins the pose — a held stance, never interrupted by a stale
	# anim_lock from whatever the fighter was doing the instant before.
	if _bracing:
		_set_anim("Blocking")
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
		_set_anim("Idle")   # also covers _charging_smash — movement is rooted, so speed() ~= 0

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _cap_freeze:
		return   # --hitkitcap: hold cooldowns + physics for a staged shot
	if _shove_cd > 0.0: _shove_cd -= delta
	if _hop_cd > 0.0: _hop_cd -= delta
	if _smash_cd > 0.0: _smash_cd -= delta
	if _brace_cd > 0.0: _brace_cd -= delta
	if _brace_vuln > 0.0: _brace_vuln -= delta
	if _dash_cd > 0.0: _dash_cd -= delta

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
	elif _dash_t >= 0.0:
		# M4 DASH: constant-velocity burst, direct velocity override (RigidBody3D
		# equivalent of Echo's CharacterBody3D dash) — never touches
		# collision_layer/mask, so it can never phase through another body.
		_dash_t += delta
		linear_velocity = Vector3(_dash_dir.x * DASH_SPEED, linear_velocity.y, _dash_dir.z * DASH_SPEED)
		if _dash_t >= DASH_TIME:
			_dash_t = -1.0
	elif _bracing or _charging_smash:
		# M4 BRACE / SUPER-SMASH charge: both root the fighter (a committed
		# stance), so movement input is ignored and residual velocity decays.
		var v0 := linear_velocity
		linear_velocity = Vector3(move_toward(v0.x, 0.0, ACCEL * delta), v0.y, move_toward(v0.z, 0.0, ACCEL * delta))
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

	_tick_dash_gesture(delta)
	_tick_a_button(delta)
	_tick_b_button(delta)

	if want_shove:
		want_shove = false
		_do_shove()
	if want_hop:
		want_hop = false
		_do_hop()
	if want_dash:
		want_dash = false
		_try_dash(Vector3(move_input.x, 0.0, move_input.y) if move_input.length() > 0.1 else _face)
	if want_smash:
		want_smash = false
		_arm_smash_charge()
	if want_brace:
		want_brace = false
		_start_brace()
	if _charging_smash:
		_smash_charge_t += delta
		if _smash_charge_t >= SMASH_CHARGE_T:
			_finish_smash_charge()
	if _bracing:
		_brace_t += delta
		if _brace_t >= BRACE_MAX_HOLD:
			_end_brace()   # stamina exhausted — no turtling forever

	# hard safety net: a fighter standing over the floor footprint can NEVER be
	# below its surface (Jolt can shove bodies down through the slab when two
	# capsules ram or a heavy prop slams them). Only past the ±6 lip may you sink.
	if global_position.y < -0.6 and absf(global_position.x) < 5.9 and absf(global_position.z) < 5.9:
		global_position.y = 0.05
		linear_velocity.y = maxf(linear_velocity.y, 0.0)

	# off-map safe-spot fix: the floor collider is a flat ±6 box, so a capsule
	# resting right at (or wedged past) that edge can still read "grounded" from
	# partial shape overlap — a fluke ledge with nothing legitimate on it (the
	# design is "walk off, you fall": see _build_stage). A genuine edge-fall
	# leaves _grounded false almost immediately as gravity takes over, so this
	# only fires on a body that's actually come to rest out of bounds.
	var out_of_bounds := absf(global_position.x) > FLOOR_HALF or absf(global_position.z) > FLOOR_HALF
	if _grounded and out_of_bounds:
		_oob_time += delta
	else:
		_oob_time = 0.0

	var oob_fall := _oob_time > 0.25
	if global_position.y < VOID_Y or oob_fall:
		# grace at round start: spawn jank rescues instead of killing
		if owner_game != null and owner_game.game_time < grace_until:
			global_position = safe_spawn
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_stun = 0.0
			_oob_time = 0.0
		else:
			if oob_fall:
				# evidence line: this is the ledge-clip / wedged-prop path, not a
				# clean edge-fall. Turned up ~1 round in 4 in a 20-round bot sim
				# (seed 7) before this fix, always at the ±6 lip, never mid-floor.
				print("DW_OOB_SAFEFALL seat=%d pos=(%.2f,%.2f,%.2f)" % [
					index, global_position.x, global_position.y, global_position.z])
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

# ============================================================================
# M4 MOVESET — BRACE, DASH, SUPER SMASH
# ============================================================================

## A-button hold resolver (HUMANS only — bots/probes drive want_shove/
## want_smash directly, see dead_weight.gd:_bot_living). Mirrors Echo's own
## A split: a quick tap still fires a normal SHOVE through the SAME one-shot
## want_shove path bots use (zero behavior change for a fast tap); holding
## past SMASH_ARM_T arms a SUPER SMASH that auto-fires at SMASH_CHARGE_T — no
## release needed, so there's nothing to "hold forever and wait for the
## perfect moment": the charge itself is the exposure window (hit() drops it).
func _tick_a_button(delta: float) -> void:
	if a_down and not _a_prev:
		_a_active = true
		_a_hold = 0.0
	if _a_active and a_down:
		_a_hold += delta
		if not _charging_smash and _a_hold >= SMASH_ARM_T:
			_arm_smash_charge()
	if _a_active and not a_down:
		_a_active = false
		if not _charging_smash:
			want_shove = true   # short tap, or a hold that never armed (smash on cd)
	_a_prev = a_down

## B-button hold resolver (HUMANS only). A quick tap still fires HOP; holding
## past BRACE_THRESHOLD commits to BRACE. Unlike the smash charge, brace does
## NOT auto-fire — the player chooses when to drop it (Echo's parry does the
## same) — the stamina cap in _physics_process is the only forced release.
func _tick_b_button(delta: float) -> void:
	if b_down and not _b_prev:
		_b_active = true
		_b_hold = 0.0
	if _b_active and b_down:
		_b_hold += delta
		if not _bracing and _b_hold >= BRACE_THRESHOLD:
			_start_brace()
	if _b_active and not b_down:
		_b_active = false
		if _bracing:
			_end_brace()
		else:
			want_hop = true   # short tap, or a hold that never braced (on cd)
	_b_prev = b_down

## Double-tap-a-direction DASH gesture — the house `move + A + B` verb budget
## (docs/design/16-jump-and-visibility.md §0: "there is no third button... it
## would break the one architectural rule every module was built against")
## rules out a dedicated button, so DASH rides the existing MOVE axis instead,
## exactly the brief's own "or double-direction" alternative. HUMANS only;
## bots fire want_dash directly with their own seeded policy.
func _tick_dash_gesture(delta: float) -> void:
	if bot_driven:
		return
	var active := move_input.length() > DASH_TAP_MIN
	if active and not _move_was_active:
		var dir3 := Vector3(move_input.x, 0.0, move_input.y).normalized()
		if _dash_tap_t >= 0.0 and _dash_tap_t <= DASH_TAP_WINDOW and dir3.dot(_dash_tap_dir) > 0.5:
			_try_dash(dir3)
			_dash_tap_t = -1.0
		else:
			_dash_tap_t = 0.0
			_dash_tap_dir = dir3
	elif _dash_tap_t >= 0.0:
		_dash_tap_t += delta
		if _dash_tap_t > DASH_TAP_WINDOW:
			_dash_tap_t = -1.0
	_move_was_active = active

## Begin a SUPER SMASH charge (gated; a no-op if not eligible — so a human
## holding A past SMASH_ARM_T while smash is on cooldown just falls through
## to a normal tap SHOVE on release, no dead input). Bots reach this via the
## one-shot want_smash trigger.
func _arm_smash_charge() -> void:
	if _charging_smash or _smash_cd > 0.0 or _bracing or _stun > 0.0 or not alive:
		return
	_charging_smash = true
	_smash_charge_t = 0.0
	_set_smash_visual(true)
	if _visuals_on():
		Sfx.play("bounce", -8.0)   # quiet charge-start whoosh; the glow carries the tell

func _finish_smash_charge() -> void:
	_charging_smash = false
	_set_smash_visual(false)
	_do_super_smash()

## M4 SUPER SMASH charge telegraph — "grow/glow," Echo's exact language and
## exact overlay values (echo_chamber/fighter.gd `_set_charge_visual`): scale
## up + swap every mesh's identity rim for a shared red-hot overlay while
## charging, restoring each mesh's OWN rim material when it ends (fire,
## cancel, or an interrupting hit). No cooldown ring for smash by design (see
## the _dash_ring doc comment on the class) — the glow itself is the
## readiness tell, and there's no way to waste an A-hold while it's on
## cooldown (see _tick_a_button), so a missing ring costs nothing functional.
func _set_smash_visual(active: bool) -> void:
	if model_pivot == null or not _visuals_on():
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_squash_tw = create_tween()
	var target := Vector3(SMASH_SCALE_PEAK, SMASH_SCALE_PEAK, SMASH_SCALE_PEAK) if active else Vector3.ONE
	_squash_tw.tween_property(model_pivot, "scale", target, 0.15 if active else 0.12)
	for i in _mesh_instances.size():
		var mi: MeshInstance3D = _mesh_instances[i]
		if is_instance_valid(mi):
			mi.material_overlay = _charge_overlay if active else _rim_mats[i]

## M4 SUPER SMASH — the payoff of a full charge: a RADIAL shove (no
## _face.dot() gate, unlike SHOVE_ARC) at roughly 2x SHOVE's range and base
## knockback, long cooldown. Mirrors _do_shove()'s prop-shove wiring so a
## smash reads as a heavier shove, not a different verb; victim-side HIT KIT
## dressing (pop/spark/hitstop) rides the same hit()/on_smash_landed() paths
## shove already uses, auto-scaled up by the bigger power value.
func _do_super_smash() -> void:
	_smash_cd = SMASH_CD
	net_smashes += 1
	if owner_game == null:
		return
	if _visuals_on():
		Sfx.play("bumper", -1.0)   # the heaviest confirm in the bank
		if owner_game.has_method("on_smash_fired"):
			owner_game.on_smash_fired(global_position, color)
	_cur_anim = "2H_Melee_Attack_Slice"
	if anim and anim.has_animation("2H_Melee_Attack_Slice"):
		anim.play("2H_Melee_Attack_Slice")
	_anim_lock = 0.42
	var my_speed := speed()
	var power := SMASH_BASE + my_speed * SMASH_SPEED_SCALE
	var hit_any := false
	for other in owner_game.living_fighters():
		if other == self or not other.alive:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		if to.length() > SMASH_RANGE:
			continue
		other.call_deferred("hit", to, power, "player", index, "%s" % name, color)
		hit_any = true
	for prop in owner_game.props():
		if prop.possessed_by >= 0:
			continue
		var pto: Vector3 = prop.global_position - global_position
		pto.y = 0.0
		if pto.length() <= SMASH_RANGE:
			prop.apply_central_impulse(pto.normalized() * power * 0.5 + Vector3.UP * 0.6)
	windup_coil(hit_any)
	if hit_any and owner_game.has_method("on_smash_landed"):
		owner_game.on_smash_landed(global_position)

## M4 BRACE. No dedicated cooldown ring by design (see the _dash_ring doc
## comment) — the tell IS the pose: the Blocking anim wins priority in
## _update_anim, a chunky coil, and the identity ring's OWN emission pulsing
## up for the duration (house "geometry/brightness, never a competing ring"
## language, doc 08 §B2). Guarded so bot want_brace and human B-hold funnel
## through the same path.
func _start_brace() -> void:
	if _bracing or _brace_cd > 0.0 or _stun > 0.0 or _charging_smash or not alive:
		return
	_bracing = true
	_brace_t = 0.0
	if not _visuals_on():
		return
	Sfx.play("confirm", -4.0)
	if model_pivot:
		if _squash_tw and _squash_tw.is_valid():
			_squash_tw.kill()
		_squash_tw = create_tween()
		_squash_tw.tween_property(model_pivot, "scale", Vector3(1.08, 0.90, 1.08), 0.08)
	if _ring_mat:
		_ring_mat.emission_energy_multiplier = CooldownRing.READY_EMISSION * RING_BASE_EMISSION

## Ends a brace, whether by early release (human let go of B), the stamina
## cap (BRACE_MAX_HOLD), or a round reset. Idempotent — safe to call from
## multiple triggers in the same tick.
func _end_brace() -> void:
	if not _bracing:
		return
	_bracing = false
	_brace_cd = BRACE_CD
	_brace_vuln = BRACE_VULN_T   # M4 anti-turtle: briefly MORE vulnerable right after
	if _visuals_on() and model_pivot:
		if _squash_tw and _squash_tw.is_valid():
			_squash_tw.kill()
		_squash_tw = create_tween()
		_squash_tw.tween_property(model_pivot, "scale", Vector3.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _ring_mat:
		_ring_mat.emission_energy_multiplier = RING_BASE_EMISSION

## M4 DASH — a short constant-velocity burst (RigidBody3D equivalent of
## Echo's CharacterBody3D dash), direct velocity override for DASH_TIME.
## `dir`: explicit MOVE input direction when present, else current facing
## (mirrors Echo's _start_dash fallback). Deliberately grants NO i-frames and
## never touches collision_layer/mask — "no phase-through of players" per the
## brief; you dodge a shove by outrunning it, not by turning intangible.
func _try_dash(dir: Vector3) -> void:
	if _dash_cd > 0.0 or _stun > 0.0 or _bracing or _charging_smash or _dash_t >= 0.0 or not alive:
		return
	var d := dir
	d.y = 0.0
	_dash_dir = d.normalized() if d.length() > 0.05 else _face
	_dash_cd = DASH_CD
	_dash_t = 0.0
	net_dashes += 1
	if model_pivot:
		model_pivot.rotation.y = atan2(_dash_dir.x, _dash_dir.z)
	_cur_anim = "Dodge_Forward"
	if anim and anim.has_animation("Dodge_Forward"):
		anim.play("Dodge_Forward")
	_anim_lock = DASH_TIME + 0.05
	if _visuals_on():
		Sfx.play("bounce", -6.0)
	if owner_game and owner_game.has_method("on_dash_fired"):
		owner_game.on_dash_fired(global_position, _dash_dir, color)

func hit(dir: Vector3, impulse: float, atk_type: String, atk_index: int, src_name: String, atk_color: Color) -> void:
	if not alive:
		return
	dir.y = 0.0
	var d := dir.normalized()
	# M4 BRACE — heavy knockback resistance while held; a brief window of
	# EXTRA vulnerability right after any release (the anti-turtle cost).
	var eff_impulse := impulse
	if _bracing:
		eff_impulse *= BRACE_KNOCK_FACTOR
	elif _brace_vuln > 0.0:
		eff_impulse *= BRACE_VULN_FACTOR
	apply_central_impulse(d * eff_impulse + Vector3.UP * eff_impulse * 0.14)
	_stun = STUN_TIME
	net_hits += 1
	net_hit_dir = d
	var t := 0.0
	if owner_game != null:
		t = owner_game.game_time
	last_attacker = {"type": atk_type, "index": atk_index, "name": src_name, "color": atk_color, "time": t}
	# M4 — a landed hit drops an in-progress SUPER SMASH charge (never a
	# brace — resistance IS the point of holding one) and cancels any dash in
	# flight so its velocity override can't stomp the knockback we just
	# applied. Force _a_active false too, so a still-held human A doesn't
	# silently re-arm next tick — the charge is fully wasted, matching the
	# brief's "interruptible by being hit (drops the charge)."
	if _charging_smash:
		_charging_smash = false
		_a_active = false
		_set_smash_visual(false)
	_dash_t = -1.0
	# HIT KIT §B1 Phase 2 — victim squash-pop + spark burst along the knockback
	# (kept even under reduced-motion; a read, not a shake). Covers shoves AND
	# ghost-fling hits (both route through here). Gated off in the balance sim.
	if _visuals_on():
		flash_pop()
		if owner_game.has_method("spark_at"):
			var strength := clampf(eff_impulse / (SHOVE_BASE + 5.0 * SHOVE_SPEED_SCALE), 0.5, 1.5)
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
	_dash_ring.tick(delta, clampf(1.0 - _dash_cd / DASH_CD, 0.0, 1.0), alive, reduced)

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
	_oob_time = 0.0
	last_attacker = {}
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	_anim_lock = 0.0
	_cur_anim = ""
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	if model_pivot:
		model_pivot.scale = Vector3.ONE
	# M4 MOVESET reset — a fresh life starts with every hold, cooldown, and
	# telegraph clean, exactly like SHOVE/HOP above.
	a_down = false
	b_down = false
	want_dash = false
	want_smash = false
	want_brace = false
	_a_prev = false
	_a_active = false
	_a_hold = 0.0
	_charging_smash = false
	_smash_charge_t = 0.0
	_smash_cd = 0.0
	_b_prev = false
	_b_active = false
	_b_hold = 0.0
	_bracing = false
	_brace_t = 0.0
	_brace_cd = 0.0
	_brace_vuln = 0.0
	_dash_t = -1.0
	_dash_cd = 0.0
	_move_was_active = false
	_dash_tap_t = -1.0
	if _ring_mat:
		_ring_mat.emission_energy_multiplier = RING_BASE_EMISSION
	for i in _mesh_instances.size():
		var mi: MeshInstance3D = _mesh_instances[i]
		if is_instance_valid(mi):
			mi.material_overlay = _rim_mats[i]
	if _shove_ring:
		_shove_ring.tick(0.0, 1.0, false, false)   # force-hide the cooldown rings
	if _hop_ring:
		_hop_ring.tick(0.0, 1.0, false, false)
	if _dash_ring:
		_dash_ring.tick(0.0, 1.0, false, false)
	_set_anim("Idle")
	call_deferred("set", "freeze", false)
