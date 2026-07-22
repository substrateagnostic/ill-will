class_name SwapKart
extends Node3D
## A bumper kart (SWAP MEET). Fully kinematic, stepped by the world.
## Feel targets: forgiving + chunky. Auto-throttle, high steering
## authority, rubber rails (the world clamps to the corridor and calls
## bounce()), hold-B drift with lagging velocity direction, release for
## a boost proportional to drift time.
##
## The kart's "kinematic soul" (position, heading, velocity, corridor,
## progress, lap timing) is exactly what a SWAP exchanges - see
## swap_meet.gd _do_swap(). Everything else (score, cooldowns, items)
## stays with the player.

## --- feel numbers (the whole game lives in these) --------------------------
const TOP_SPEED := 8.0
const ACCEL_RATE := 2.3          # exp approach rate to target speed
const BRAKE_DECEL := 12.0
const REVERSE_MAX := 2.4
const STEER_RATE := 2.55         # rad/s at full stick, full authority
const STEER_SMOOTH := 13.0       # stick -> steer low-pass rate
const GRIP_NORMAL := 9.5         # vel dir alignment rate (1/s)
const GRIP_DRIFT := 3.0
const DRIFT_TURN_MULT := 1.6
const DRIFT_MIN_SPEED := 4.0
const DRIFT_MINI_T := 0.35       # held this long -> mini boost
const DRIFT_TURBO_T := 0.85
const BOOST_MINI := 2.5
const BOOST_TURBO := 4.0
const BOOST_MINI_DUR := 0.55
const BOOST_TURBO_DUR := 0.95
const DRIFT_CD := 2.0
const SPEED_CAP := 10.5
const WALL_REST := 0.5
const WALL_MIN_KEEP := 2.0       # rails never stick: min speed kept along wall
const GRAV := 13.0
const RAMP_LAUNCH := 0.62        # vy = speed * this at a ramp lip
const KART_R := 0.55
const AIR_STEER := 0.30

const CHAR_SCALE := 0.62

var world: Variant = null        # SwapMeet root (Variant avoids a cyclic class dependency)
var track: SwapTrack = null
var index: int = 0
var pname: String = ""
var color: Color = Color.WHITE

## kinematic soul (swapped wholesale on a SWAP)
var heading: Vector3 = Vector3(1, 0, 0)  # unit, XZ
var vel_dir: Vector3 = Vector3(1, 0, 0)  # unit, XZ; lags heading while drifting
var speed: float = 0.0                 # signed along vel_dir (negative = reverse)
var knock_vel: Vector3 = Vector3.ZERO  # windmill / bump impulse, decays
var y: float = 0.0
var vy: float = 0.0
var airborne: bool = false
var on_shortcut: bool = false
var hint: int = -1                   # nearest-segment cache (main)
var sc_hint: int = -1
var progress: float = 0.0              # lap * L + s, wrap-integrated
var last_s_eff: float = 0.0            # previous tick's effective main-loop s
var last_cross_time: float = 0.0       # race time when this POSITION last crossed the line
var laps_hw: int = -1                  # high-water laps completed (-1 = pre-line)
var gates_credited: int = 0            # checkpoint high-water for this race position
var lap_times: Array[float] = []        # history follows the race position it timed
var bog_speed_scale: float = 1.0        # derived surface state; refreshed by the world each tick

## driver state (stays with the player through swaps)
var finished: bool = false
var finish_place: int = 0
var orb_cd: float = 0.0
var drift_cd: float = 0.0
var swap_immune: float = 0.0
var knock_immune: float = 0.0
var has_golden: bool = false
var parked: bool = false              # test harness: no auto-throttle

## Inventory/debuff state stays with the driver through a position swap.
## held_item values mirror Swap Meet's ITEM_* constants; int avoids a cycle.
var held_item: int = -1
var orb_charges: int = 0
var bell_slow_t: float = 0.0
var crow_t: float = 0.0
var tumble_t: float = 0.0
var bot_speed_scale: float = 1.0

var drifting: bool = false
var drift_t: float = 0.0
var boost_t: float = 0.0
var boost_amt: float = 0.0
var steer: float = 0.0                 # smoothed stick.x
var locked: bool = true               # countdown / end freeze
var stuck_t: float = 0.0               # seconds jammed near-zero-speed while steering (ramp unstick)
var last_input_mag: float = 0.0        # magnitude of the raw player intent this tick

# ONLINE (phase 2): one-shot anim facts for the render mirror. play_anim()
# stamps them; the mirror replays the same one-shot off the counter delta.
# Pure bookkeeping on the couch (no reads, no prints).
var net_anim_id: int = 0             # 1 = Throw, 2 = Hit_A
var net_anim_n: int = 0

var _spin_t: float = 0.0               # windmill knock 360 visual
var _visual: Node3D
var _body_mat: StandardMaterial3D
var _anim: AnimationPlayer = null
var _front_wheels: Array = []
var _all_wheels: Array = []
var _tag: Label3D
var _ring_mat: StandardMaterial3D
var _sparks: CPUParticles3D
var _flame: MeshInstance3D
var _orb_ready_vis: MeshInstance3D
var _anim_until: float = 0.0
var _wheel_spin: float = 0.0

func setup(char_scene: PackedScene, col: Color, display_name: String) -> void:
	color = col
	pname = display_name
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * 1.15  # visual chunk > collision radius (party read)
	add_child(_visual)
	_build_kart()
	if char_scene != null:
		var inst: Node3D = char_scene.instantiate() as Node3D
		inst.scale = Vector3.ONE * CHAR_SCALE
		inst.position = Vector3(0, 0.30, -0.05)
		_visual.add_child(inst)
		_anim = inst.find_child("AnimationPlayer", true, false)
		if _anim != null and _anim.has_animation("Sit_Chair_Idle"):
			_anim.get_animation("Sit_Chair_Idle").loop_mode = Animation.LOOP_LINEAR
			_anim.play("Sit_Chair_Idle")
			if _anim.has_animation("Cheer"):
				_anim.get_animation("Cheer").loop_mode = Animation.LOOP_LINEAR
	_build_tag()
	_build_fx()

## Place on the main corridor at arclength s / lateral offset.
func place_at(s: float, lat: float) -> void:
	var sm: Dictionary = track.sample_at(s)
	var right: Vector3 = Vector3(sm.get("tangent", Vector3.FORWARD)).cross(Vector3.UP).normalized()
	global_position = Vector3(sm.get("pos", Vector3.ZERO)) + right * lat
	heading = Vector3(sm.get("tangent", Vector3.FORWARD)).normalized()
	vel_dir = heading
	speed = 0.0
	y = global_position.y
	on_shortcut = false
	hint = -1
	sc_hint = -1
	var q: Dictionary = track.nearest_main(global_position, -1)
	hint = int(q.idx)
	var s_here: float = float(q.get("s", 0.0))
	progress = s_here - track.total_len if s_here > track.total_len * 0.5 else s_here
	last_s_eff = s_here
	_orient(1000.0)

func center() -> Vector3:
	return global_position + Vector3(0, 0.5, 0)

## --- per-tick simulation ----------------------------------------------------

func step(dt: float, mv: Vector2, b_down: bool) -> void:
	orb_cd = maxf(0.0, orb_cd - dt)
	drift_cd = maxf(0.0, drift_cd - dt)
	swap_immune = maxf(0.0, swap_immune - dt)
	knock_immune = maxf(0.0, knock_immune - dt)
	bell_slow_t = maxf(0.0, bell_slow_t - dt)
	crow_t = maxf(0.0, crow_t - dt)
	tumble_t = maxf(0.0, tumble_t - dt)
	boost_t = maxf(0.0, boost_t - dt)
	last_input_mag = mv.length()   # raw player intent, before lock/finish overrides
	if locked:
		mv = Vector2.ZERO
		b_down = false
	if finished:
		mv = _cruise_input()
		b_down = false
	if tumble_t > 0.0:
		mv = Vector2.ZERO
		b_down = false
	# steering (smoothed stick, party-chunky)
	steer += (clampf(mv.x, -1.0, 1.0) - steer) * (1.0 - exp(-STEER_SMOOTH * dt))
	var authority: float = AIR_STEER if airborne else 1.0
	var eff_speed: float = absf(speed)
	var turn_scale: float = clampf(eff_speed / 1.5, 0.0, 1.0) * authority
	var drift_mult: float = DRIFT_TURN_MULT if drifting else 1.0
	var handling_scale: float = 0.78 if crow_t > 0.0 else 1.0
	var turn: float = -steer * STEER_RATE * drift_mult * turn_scale * handling_scale * dt
	if speed < -0.2:
		turn = -turn  # reversing: steer like a car backing up
	heading = heading.rotated(Vector3.UP, turn).normalized()
	# drift latch / release
	var want_drift: bool = b_down and not airborne and eff_speed > DRIFT_MIN_SPEED and drift_cd <= 0.0
	if want_drift and not drifting:
		drifting = true
		drift_t = 0.0
	elif drifting and not want_drift:
		_release_drift()
	if drifting:
		drift_t += dt
	# auto-throttle + brake/reverse
	var target: float = 0.0 if parked else TOP_SPEED * (0.93 if drifting else 1.0)
	target *= bog_speed_scale
	target *= 0.65 if bell_slow_t > 0.0 else 1.0
	target *= bot_speed_scale
	if tumble_t > 0.0:
		target = minf(target, 1.4)
	if boost_t > 0.0:
		target += boost_amt
	if mv.y > 0.4 and not airborne:
		speed = maxf(speed - BRAKE_DECEL * dt, -REVERSE_MAX * mv.y)
		if drifting:
			_release_drift()
	else:
		speed += (target - speed) * (1.0 - exp(-ACCEL_RATE * dt))
	speed = clampf(speed, -REVERSE_MAX, SPEED_CAP)
	# velocity direction lags heading while drifting (that IS the drift)
	var grip: float = GRIP_DRIFT if drifting else GRIP_NORMAL
	if airborne:
		grip *= 0.4
	if absf(speed) < 1.0:
		vel_dir = heading
	else:
		var ang: float = vel_dir.signed_angle_to(heading, Vector3.UP)
		vel_dir = vel_dir.rotated(Vector3.UP, ang * (1.0 - exp(-grip * dt))).normalized()
	# integrate
	global_position += vel_dir * speed * dt + knock_vel * dt
	knock_vel *= exp(-4.0 * dt)
	global_position.y = y
	_wheel_spin += speed * dt / 0.2
	_orient(dt)

func _cruise_input() -> Vector2:
	# finished karts parade around on a simple pure-pursuit line
	var q: Dictionary = track.nearest_main(global_position, hint) if not on_shortcut \
		else track.nearest_sc(global_position, sc_hint)
	var look_s: float = float(q.get("s", 0.0)) + 5.0
	var target: Vector3
	if on_shortcut:
		if look_s > track.sc_len:
			look_s -= track.sc_len  # will exit soon anyway
			target = Vector3(track.sample_at(track.sc_exit_s + look_s).pos)
		else:
			target = Vector3(track.sc_sample_at(look_s).pos)
	else:
		target = Vector3(track.sample_at(look_s).pos)
	var to: Vector3 = target - global_position
	to.y = 0.0
	var ang: float = heading.signed_angle_to(to.normalized(), Vector3.UP)
	return Vector2(clampf(-ang * 2.0, -1.0, 1.0), 0.35)  # gentle 65% throttle

func _release_drift() -> void:
	drifting = false
	drift_cd = DRIFT_CD
	if drift_t >= DRIFT_TURBO_T:
		boost_amt = BOOST_TURBO
		boost_t = BOOST_TURBO_DUR
		world.on_boost(self, 2)
	elif drift_t >= DRIFT_MINI_T:
		boost_amt = BOOST_MINI
		boost_t = BOOST_MINI_DUR
		world.on_boost(self, 1)
	drift_t = 0.0

## Rubber rail bounce. normal points INTO the track. Called by the world
## after it clamps position back inside the corridor.
func bounce(normal: Vector3) -> float:
	var v: Vector3 = vel_dir * speed + knock_vel
	var vn: float = v.dot(normal)
	if vn >= 0.0:
		return 0.0
	v -= (1.0 + WALL_REST) * vn * normal
	knock_vel = Vector3.ZERO
	var new_speed: float = v.length()
	if new_speed > 0.05:
		vel_dir = v / new_speed
	speed = clampf(new_speed, WALL_MIN_KEEP, SPEED_CAP)
	# heading chunks most of the way toward the rebound - never stick
	var ang: float = heading.signed_angle_to(vel_dir, Vector3.UP)
	heading = heading.rotated(Vector3.UP, ang * 0.7).normalized()
	return -vn

## Windmill boom knock: sideways shove, brief spin visual. Non-lethal.
func knock(dir: Vector3, power: float) -> void:
	knock_vel = dir * power
	speed = minf(speed, 3.0)
	knock_immune = 0.9
	_spin_t = 0.55
	if drifting:
		_release_drift()

func tumble() -> void:
	tumble_t = 0.85
	speed = minf(speed, 1.8)
	_spin_t = maxf(_spin_t, 0.85)
	knock_immune = 0.7
	if drifting:
		_release_drift()

func launch_air(launch_vy: float) -> void:
	airborne = true
	vy = launch_vy

func air_step(dt: float, floor_y: float) -> bool:
	vy -= GRAV * dt
	y += vy * dt
	if y <= floor_y and vy <= 0.0:
		y = floor_y
		vy = 0.0
		airborne = false
		return true  # landed
	return false

## --- swap support ------------------------------------------------------------

## The kinematic soul as a dict (world swaps two of these atomically).
func soul() -> Dictionary:
	return {
		"pos": global_position, "heading": heading, "vel_dir": vel_dir,
		"speed": speed, "knock_vel": knock_vel, "y": y, "vy": vy,
		"airborne": airborne, "on_shortcut": on_shortcut,
		"hint": hint, "sc_hint": sc_hint, "progress": progress,
		"last_s_eff": last_s_eff, "last_cross_time": last_cross_time,
		"laps_hw": laps_hw, "gates_credited": gates_credited,
		"lap_times": lap_times.duplicate(), "bog_speed_scale": bog_speed_scale,
	}

func apply_soul(s: Dictionary) -> void:
	global_position = Vector3(s.get("pos", Vector3.ZERO))
	heading = Vector3(s.get("heading", Vector3.FORWARD))
	vel_dir = Vector3(s.get("vel_dir", heading))
	speed = float(s.get("speed", 0.0))
	knock_vel = Vector3(s.get("knock_vel", Vector3.ZERO))
	y = float(s.get("y", 0.0))
	vy = float(s.get("vy", 0.0))
	airborne = bool(s.get("airborne", false))
	on_shortcut = bool(s.get("on_shortcut", false))
	hint = int(s.get("hint", -1))
	sc_hint = int(s.get("sc_hint", -1))
	progress = float(s.get("progress", 0.0))
	last_s_eff = float(s.get("last_s_eff", 0.0))
	last_cross_time = float(s.get("last_cross_time", 0.0))
	laps_hw = int(s.get("laps_hw", -1))
	gates_credited = int(s.get("gates_credited", 0))
	lap_times.clear()
	var saved_lap_times: Array = s.get("lap_times", [])
	for lap_time_value: Variant in saved_lap_times:
		lap_times.append(float(lap_time_value))
	bog_speed_scale = float(s.get("bog_speed_scale", 1.0))
	global_position.y = y
	_orient(1000.0)

func flash_tag() -> void:
	if _tag == null:
		return
	_tag.modulate = Color.WHITE
	_tag.scale = Vector3.ONE * 1.8
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_tag, "modulate", color, 0.7)
	tw.tween_property(_tag, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_anim(anim_name: String, hold: float) -> void:
	net_anim_n += 1
	net_anim_id = 1 if anim_name == "Throw" else 2
	if _anim == null:
		return
	if _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.12)
		_anim_until = world.now + hold

func cheer_forever() -> void:
	if _anim != null and _anim.has_animation("Cheer"):
		_anim.play("Cheer", 0.2)
		_anim_until = world.now + 99999.0

## --- visuals ------------------------------------------------------------------

const KART_GLB := "res://assets/models/meshy/go_kart.glb"
const KART_HEIGHT := 0.72        # in _visual-local units (the _visual scales x1.15)
const KART_YAW := 0.0            # steering wheel / nose faces +Z (forward)

func _build_kart() -> void:
	# Custom Meshy go-kart (rounded cream roadster body, exposed steering wheel)
	# replacing the box kart. Purely visual; the kinematic soul is unchanged.
	# Normalized so the wheels sit at y=0 and the nose faces +Z (KayKit forward).
	var kart: Node3D = MeshyProp.instance(KART_GLB, KART_HEIGHT, KART_YAW)
	kart.name = "KartModel"
	_visual.add_child(kart)
	# --- per-player identity (the model is cream, so identity is ADDED) ---
	# bumper ring wrapping the kart (it IS a bumper kart), tinted + emissive
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = color
	_body_mat.roughness = 0.45
	_body_mat.emission_enabled = true
	_body_mat.emission = color
	_body_mat.emission_energy_multiplier = 0.25
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.58
	tm.outer_radius = 0.80
	ring.mesh = tm
	ring.material_override = _body_mat
	ring.position = Vector3(0, 0.26, 0.05)
	ring.scale = Vector3(1.0, 0.5, 1.15)
	_visual.add_child(ring)
	# identity ring on the ground (top-down readability)
	var gring: MeshInstance3D = MeshInstance3D.new()
	var gt: TorusMesh = TorusMesh.new()
	gt.inner_radius = 0.78
	gt.outer_radius = 0.92
	gring.mesh = gt
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gring.material_override = _ring_mat
	gring.position = Vector3(0, 0.06, 0)
	gring.scale = Vector3(1, 0.25, 1)
	_visual.add_child(gring)

func _build_tag() -> void:
	_tag = Label3D.new()
	_tag.text = PlayerBadge.glyph(index) + " " + pname
	_tag.font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	_tag.font_size = 84
	_tag.pixel_size = 0.0058
	_tag.modulate = color
	_tag.outline_size = 22
	_tag.outline_modulate = Color(0.05, 0.05, 0.09)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.position = Vector3(0, 1.85, 0)
	add_child(_tag)

func _build_fx() -> void:
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = 26
	_sparks.lifetime = 0.35
	_sparks.direction = Vector3(0, 0.4, -1)
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 4.5
	_sparks.gravity = Vector3(0, -6, 0)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	_sparks.mesh = mesh
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.75, 0.2)
	_sparks.material_override = smat
	_sparks.position = Vector3(0, 0.15, -0.7)
	_visual.add_child(_sparks)
	_flame = MeshInstance3D.new()
	var fm: CylinderMesh = CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 0.17
	fm.height = 0.8
	_flame.mesh = fm
	var fmat: StandardMaterial3D = StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.6, 0.15, 0.9)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.45, 0.1)
	fmat.emission_energy_multiplier = 1.6
	_flame.material_override = fmat
	_flame.rotation_degrees = Vector3(-90, 0, 0)
	_flame.position = Vector3(0, 0.32, -1.05)
	_flame.visible = false
	_visual.add_child(_flame)
	# floating "orb ready" pip behind the seat
	_orb_ready_vis = MeshInstance3D.new()
	var om: SphereMesh = SphereMesh.new()
	om.radius = 0.14
	om.height = 0.28
	_orb_ready_vis.mesh = om
	var omat: StandardMaterial3D = StandardMaterial3D.new()
	omat.albedo_color = Color(0.75, 0.9, 1.0)
	omat.emission_enabled = true
	omat.emission = Color(0.5, 0.75, 1.0)
	omat.emission_energy_multiplier = 1.2
	_orb_ready_vis.material_override = omat
	_orb_ready_vis.position = Vector3(0, 0.95, -0.55)
	_visual.add_child(_orb_ready_vis)

func _orient(dt: float) -> void:
	var fwd: Vector3 = heading
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		return
	var target: Basis = Basis.looking_at(-fwd.normalized(), Vector3.UP)
	var k: float = clampf(1.0 - exp(-16.0 * dt), 0.0, 1.0)
	global_transform.basis = global_transform.basis.orthonormalized().slerp(target, k)

func _process(delta: float) -> void:
	if world == null:
		return
	# knock spin (windmill hit): one fast visual 360
	if _spin_t > 0.0:
		_spin_t = maxf(0.0, _spin_t - delta)
		_visual.rotate_y(delta * 10.0)
	else:
		_visual.rotation.y = 0.0
	# lean into steer, extra while drifting
	var lean: float = -steer * (0.24 if drifting else 0.10)
	_visual.rotation.z = lerpf(_visual.rotation.z, lean, 1.0 - exp(-10.0 * delta))
	# nose lift on boost
	var pitch: float = -0.09 if boost_t > 0.0 else 0.0
	_visual.rotation.x = lerpf(_visual.rotation.x, pitch, 1.0 - exp(-8.0 * delta))
	# wheels
	for w in _all_wheels:
		(w as MeshInstance3D).rotate_object_local(Vector3.UP, speed * delta * 4.0)
	for p in _front_wheels:
		(p as Node3D).rotation.y = lerpf((p as Node3D).rotation.y, -steer * 0.45, 1.0 - exp(-12.0 * delta))
	# drift sparks: color by charge tier
	if drifting and drift_t > 0.12:
		_sparks.emitting = true
		var smat: StandardMaterial3D = _sparks.material_override
		if drift_t >= DRIFT_TURBO_T:
			smat.albedo_color = Color(0.75, 0.4, 1.0)
		elif drift_t >= DRIFT_MINI_T:
			smat.albedo_color = Color(1.0, 0.75, 0.2)
		else:
			smat.albedo_color = Color(0.65, 0.8, 1.0)
	else:
		_sparks.emitting = false
	_flame.visible = boost_t > 0.0
	if _flame.visible:
		_flame.scale = Vector3.ONE * (0.7 + 0.5 * randf())
	# inventory pip: gold orb, item color, normal swap-orb charge, or hidden.
	if has_golden:
		_orb_ready_vis.visible = true
		_orb_ready_vis.scale = Vector3.ONE * (1.7 + 0.25 * sin(world.now * 6.0))
		var omat: StandardMaterial3D = _orb_ready_vis.material_override
		omat.albedo_color = Color(1.0, 0.85, 0.25)
		omat.emission = Color(1.0, 0.75, 0.1)
	elif held_item >= 0:
		_orb_ready_vis.visible = true
		_orb_ready_vis.scale = Vector3.ONE * (1.35 + 0.12 * sin(world.now * 7.0))
		var item_mat: StandardMaterial3D = _orb_ready_vis.material_override
		var item_color: Color = world.item_color(held_item)
		item_mat.albedo_color = item_color
		item_mat.emission = item_color
	else:
		_orb_ready_vis.visible = orb_charges > 0 and orb_cd <= 0.0 and not finished and not locked
		_orb_ready_vis.scale = Vector3.ONE
		var omat2: StandardMaterial3D = _orb_ready_vis.material_override
		omat2.albedo_color = Color(0.75, 0.9, 1.0)
		omat2.emission = Color(0.5, 0.75, 1.0)
	# swap immunity shimmer
	if swap_immune > 0.0:
		_visual.visible = fmod(world.now * 10.0, 1.0) < 0.7
	else:
		_visual.visible = true
	# seated anim restore after one-shots
	if _anim != null and _anim_until > 0.0 and world.now > _anim_until:
		_anim_until = 0.0
		if _anim.has_animation("Sit_Chair_Idle"):
			_anim.play("Sit_Chair_Idle", 0.25)
