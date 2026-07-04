class_name MowerUnit
extends Node3D
## One chunky ride-on mower with a seated KayKit rider. Movement is manual
## kinematic integration on the lawn plane (Vector2 pos/facing) — no physics
## bodies, matching the house pattern (see tilt_pawn.gd). Tank-simple control:
## the stick DIRECTION is a desired heading; the mower auto-drives forward and
## turns toward it. A = ram lunge, B = boost (wider deck, less steering).

const BASE_SPEED := 4.2
const BOOST_SPEED := 6.6
const TURN_RATE := 3.4          # rad/s toward desired heading
const BOOST_TURN := 1.9         # less steering while boosting
const DECK_W := 0.90            # cut stripe width (half-width used in paint)
const BOOST_DECK_W := 1.30
const DECK_LEN := 0.55
const DECK_AHEAD := 0.55        # deck sits ahead of the body center
const RADIUS := 0.62            # collision circle
const RAM_CD := 1.5
const RAM_TIME := 0.34
const RAM_SPEED := 10.5
const SPINOUT_TIME := 1.2
const STEAL_DRAG := 0.72        # speed factor while chewing enemy turf
const FUEL_DRAIN := 0.45        # per second while boosting
const FUEL_REGEN := 0.32        # per second otherwise
const FUEL_MIN_BOOST := 0.08

var player_index := 0
var pname := ""
var pcolor := Color.WHITE
var owner_code := 1             # index+1, what this mower paints

var pos := Vector2.ZERO
var facing := Vector2(0, 1)
var vel := Vector2.ZERO         # last-frame world velocity (for fx/bots)
var fuel := 1.0
var boosting := false
var ram_cd := 0.0
var ram_t := 0.0
var spin_t := 0.0
var spin_spd := 0.0
var over_enemy := 0             # deck cells stolen last frame (for drag/juice)

# stats
var ram_spinouts := 0          # rams that spun someone out
var ram_cells := 0             # enemy cells taken via ram bursts
var cells_stolen := 0          # enemy cells taken (ram + re-mow)
var stripe_len := 0.0          # current unbroken stripe distance
var best_stripe := 0.0

var _rider: Node3D
var _anim: AnimationPlayer
var _body_pivot: Node3D
var _clippings: CPUParticles3D
var _engine: AudioStreamPlayer
var _cur_anim := ""

func setup(index: int, display_name: String, color: Color, char_scene_path: String) -> void:
	player_index = index
	pname = display_name
	pcolor = color
	owner_code = index + 1
	_build_chassis(color)
	_seat_rider(char_scene_path, color)
	_build_clippings(color)
	_build_engine(index)

func _build_chassis(color: Color) -> void:
	_body_pivot = Node3D.new()
	_body_pivot.name = "Chassis"
	add_child(_body_pivot)
	# rear body block (player color)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.5, 1.15)
	body.mesh = bm
	body.material_override = _lit(color)
	body.position = Vector3(0, 0.42, -0.18)
	_body_pivot.add_child(body)
	# hood / cutting deck (darker, wider, up front)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.06, 0.16, 0.62)
	deck.mesh = dm
	deck.material_override = _lit(color.darkened(0.45))
	deck.position = Vector3(0, 0.16, 0.62)
	_body_pivot.add_child(deck)
	# engine cowl
	var cowl := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.7, 0.34, 0.5)
	cowl.mesh = cm
	cowl.material_override = _lit(Color(0.18, 0.18, 0.2))
	cowl.position = Vector3(0, 0.66, 0.28)
	_body_pivot.add_child(cowl)
	# steering column
	var col := MeshInstance3D.new()
	var colm := CylinderMesh.new()
	colm.top_radius = 0.04
	colm.bottom_radius = 0.04
	colm.height = 0.42
	col.mesh = colm
	col.material_override = _lit(Color(0.1, 0.1, 0.12))
	col.position = Vector3(0, 0.72, 0.02)
	col.rotation_degrees = Vector3(-24, 0, 0)
	_body_pivot.add_child(col)
	var wheel_ring := MeshInstance3D.new()
	var wr := TorusMesh.new()
	wr.inner_radius = 0.08
	wr.outer_radius = 0.15
	wheel_ring.mesh = wr
	wheel_ring.material_override = _lit(Color(0.08, 0.08, 0.1))
	wheel_ring.position = Vector3(0, 0.92, 0.14)
	wheel_ring.rotation_degrees = Vector3(66, 0, 0)
	_body_pivot.add_child(wheel_ring)
	# wheels: small front, big rear
	for sx in [-1.0, 1.0]:
		_add_wheel(Vector3(sx * 0.5, 0.2, 0.62), 0.2)
		_add_wheel(Vector3(sx * 0.52, 0.28, -0.42), 0.28)
	# identity flag on a pole
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.02
	pm.bottom_radius = 0.02
	pm.height = 0.8
	pole.mesh = pm
	pole.material_override = _lit(Color(0.12, 0.12, 0.14))
	pole.position = Vector3(0.38, 1.0, -0.5)
	_body_pivot.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.02, 0.22, 0.34)
	flag.mesh = fm
	var fmat := _lit(color)
	fmat.emission_enabled = true
	fmat.emission = color
	fmat.emission_energy_multiplier = 0.7
	flag.material_override = fmat
	flag.position = Vector3(0.38, 1.28, -0.66)
	_body_pivot.add_child(flag)

func _add_wheel(at: Vector3, r: float) -> void:
	var w := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = r
	wm.bottom_radius = r
	wm.height = 0.16
	w.mesh = wm
	w.material_override = _lit(Color(0.09, 0.09, 0.1))
	w.rotation_degrees = Vector3(0, 0, 90)
	w.position = at
	_body_pivot.add_child(w)

func _seat_rider(char_scene_path: String, color: Color) -> void:
	var ps := load(char_scene_path) as PackedScene
	if ps == null:
		return
	_rider = ps.instantiate()
	_rider.scale = Vector3(0.7, 0.7, 0.7)
	_rider.position = Vector3(0, 0.5, -0.28)
	_body_pivot.add_child(_rider)
	_anim = _rider.find_child("AnimationPlayer", true, false)
	for lp in ["Sit_Chair_Idle", "Idle", "Cheer"]:
		if _anim and _anim.has_animation(lp):
			_anim.get_animation(lp).loop_mode = Animation.LOOP_LINEAR
	_play("Sit_Chair_Idle")

func _build_clippings(color: Color) -> void:
	_clippings = CPUParticles3D.new()
	_clippings.emitting = false
	_clippings.amount = 26
	_clippings.lifetime = 0.55
	_clippings.local_coords = false
	_clippings.direction = Vector3(0, 1, -1)
	_clippings.spread = 42.0
	_clippings.initial_velocity_min = 2.2
	_clippings.initial_velocity_max = 4.6
	_clippings.gravity = Vector3(0, -9.0, 0)
	_clippings.scale_amount_min = 0.6
	_clippings.scale_amount_max = 1.3
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.02, 0.09)
	_clippings.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.62, 0.22).lerp(color, 0.25)
	_clippings.material_override = mat
	add_child(_clippings)

func _build_engine(index: int) -> void:
	_engine = AudioStreamPlayer.new()
	_engine.stream = load("res://assets/audio/impactGeneric_light_000.ogg")
	_engine.volume_db = -19.0
	# each player's put-put sits at a distinct pitch
	_engine.pitch_scale = 0.62 + 0.14 * index
	add_child(_engine)

func _lit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m

func reset(spawn: Vector2, face: Vector2) -> void:
	pos = spawn
	facing = face.normalized()
	vel = Vector2.ZERO
	fuel = 1.0
	boosting = false
	ram_cd = 0.0
	ram_t = 0.0
	spin_t = 0.0
	spin_spd = 0.0
	over_enemy = 0
	stripe_len = 0.0
	_apply_transform()

func deck_half_w(overtime: bool) -> float:
	var w := BOOST_DECK_W if boosting else DECK_W
	if overtime:
		w *= 2.0
	return w * 0.5

func deck_center() -> Vector2:
	return pos + facing * DECK_AHEAD

## Advance one tick. `inp` = {move:Vector2, a:bool(just), b:bool(down)}.
func drive(delta: float, inp: Dictionary) -> void:
	ram_cd = maxf(0.0, ram_cd - delta)
	var prev := pos
	if spin_t > 0.0:
		spin_t -= delta
		facing = facing.rotated(spin_spd * delta)
		boosting = false
		_set_clippings(false)
		_update_anim()
		_apply_transform()
		vel = (pos - prev) / maxf(delta, 0.0001)
		return

	var move: Vector2 = inp.get("move", Vector2.ZERO)
	# boost (B held) — needs fuel
	var want_boost: bool = bool(inp.get("b", false)) and fuel > FUEL_MIN_BOOST
	boosting = want_boost
	if boosting:
		fuel = maxf(0.0, fuel - FUEL_DRAIN * delta)
	else:
		fuel = minf(1.0, fuel + FUEL_REGEN * delta)

	# ram (A tapped) — short forward lunge
	if bool(inp.get("a", false)) and ram_cd <= 0.0 and ram_t <= 0.0:
		ram_t = RAM_TIME
		ram_cd = RAM_CD
	if ram_t > 0.0:
		ram_t -= delta

	# steering: desired heading from stick; auto-forward
	var turn := BOOST_TURN if boosting else TURN_RATE
	if move.length() > 0.25:
		var desired := move.normalized()
		var ang := facing.angle_to(desired)
		var step: float = clampf(ang, -turn * delta, turn * delta)
		facing = facing.rotated(step)

	# speed
	var speed := BOOST_SPEED if boosting else BASE_SPEED
	if ram_t > 0.0:
		speed = RAM_SPEED
	if over_enemy > 0 and ram_t <= 0.0:
		speed *= STEAL_DRAG
	pos += facing * speed * delta

	_set_clippings(true)
	_update_anim()
	_apply_transform()
	vel = (pos - prev) / maxf(delta, 0.0001)

func is_ramming() -> bool:
	return ram_t > 0.0

func spin_out(dir: float) -> void:
	spin_t = SPINOUT_TIME
	spin_spd = 9.0 * dir
	boosting = false
	stripe_len = 0.0
	if _anim and _anim.has_animation("Hit_A"):
		_cur_anim = "Hit_A"
		_anim.play("Hit_A", 0.1)

## record stripe progress from a cut result
func note_cut(dist: float, res: Dictionary) -> void:
	over_enemy = int(res.get("stolen", 0))
	cells_stolen += int(res.get("stolen", 0))
	if int(res.get("fresh", 0)) > 0 or int(res.get("stolen", 0)) > 0:
		stripe_len += dist
		best_stripe = maxf(best_stripe, stripe_len)
	else:
		stripe_len = 0.0

func engine_tick() -> void:
	if _engine and spin_t <= 0.0:
		_engine.play()

func cheer() -> void:
	_set_clippings(false)
	if _anim and _anim.has_animation("Cheer"):
		_cur_anim = "Cheer"
		_anim.play("Cheer", 0.2)

func _set_clippings(on: bool) -> void:
	if _clippings.emitting != on:
		_clippings.emitting = on
	if on:
		var back := -facing
		_clippings.direction = Vector3(back.x, 1.4, back.y).normalized()
		_clippings.global_position = to_global(Vector3(facing.x * DECK_AHEAD, 0.12, facing.y * DECK_AHEAD))

func _update_anim() -> void:
	if _cur_anim == "Cheer":
		return
	if spin_t > 0.0:
		return
	_play("Sit_Chair_Idle")

func _play(anim_name: String) -> void:
	if _anim == null or _cur_anim == anim_name:
		return
	if not _anim.has_animation(anim_name):
		return
	_cur_anim = anim_name
	_anim.play(anim_name, 0.2)

func _apply_transform() -> void:
	var yaw := atan2(facing.x, facing.y)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 0.0, pos.y))
	# lean into hard turns / ram for a little life
	if _body_pivot:
		var lean := clampf(spin_spd * 0.02, -0.25, 0.25) if spin_t > 0.0 else 0.0
		_body_pivot.rotation.z = lerpf(_body_pivot.rotation.z, lean, 0.3)
		_body_pivot.position.y = 0.06 if is_ramming() else 0.0
