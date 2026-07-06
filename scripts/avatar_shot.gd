class_name AvatarShot
extends Node
## PAR v4 WAVE 1 — the embodied third-person shot state machine. On a turn the
## acting PlayerAvatar walks to its ball (WALK), takes the 2H_Melee_Idle address
## stance (ADDRESS), aims + hold-release charges (CHARGE), then plays
## 2H_Melee_Attack_Slice and — at SWING_CONTACT_T into the clip — fires the ONE
## frozen entry point: putt_controller.debug_putt(power, angle). Nothing here
## touches Ball.putt, damping, the cup magnet, or any putt-feel constant: this
## node only decides WHEN debug_putt is called and with what (power, angle).
##
## Input map (spec section 1):
##   -3 mouse/shared  aim = cursor on the ground plane, LMB hold-release
##   -4 KB+MOUSE      aim = PlayerInput.get_aim_dir cursor, A/LMB hold-release
##   pads / kb halves aim = get_move heading (camera-relative), A hold-release
## Bots and the --swingplay harness route through bot_swing()/auto_swing(), which
## pass their (power, angle) THROUGH UNCHANGED so the byte-identical receipt
## compares the exact same numbers the v3 path would fire.

signal contact_fired(player: int)

enum State { IDLE, WALK, ADDRESS, CHARGE, SWING, DONE }

const WALK_CAP := 1.4          # s of walking before the remainder teleports
const ARRIVE_DIST := 0.8       # m from ball that counts as arrived
const ADDRESS_BACK := 0.55     # m the avatar stands behind the ball, along -aim
const CHASE_DIST := 1.6        # chaos: ball rolled this far away -> re-walk
const POWER_CHARGE_T := 1.1    # s for the meter to ramp min->max (ping-pong)
const SWING_CONTACT_T := 0.18  # s into 2H_Melee_Attack_Slice when contact fires
const SWING_TOTAL_T := 0.85    # s the swing state holds before returning to idle
const POWER_MIN := 1.2
const POWER_MAX := 13.0

var state: int = State.IDLE
var actor := -1

var _main: Node3D
var _putt: Node3D
var _cam_rig: Node3D
var _avatar: PlayerAvatar
var _ball: Ball
var _is_bot := false
var _chaos := false

var _aim_dir := Vector3(0, 0, -1)
var _walk_t := 0.0
var _charge_t := 0.0
var _charge_power := POWER_MIN
var _swing_t := 0.0
var _fired := false
var _self_stroke := false
## Queued exact shot for bots / --swingplay (pass-through, no recompute).
var _pending_power := -1.0
var _pending_angle := 0.0
var _auto_charge := false      # swingplay: ramp the meter up to _pending_power

var _walkprobe := false
var _swingsnap := false
var _snapped := {}

var _meter_root: Control
var _meter_fill: ColorRect
var _meter_label: Label

func setup(main: Node3D, putt: Node3D, cam_rig: Node3D, ui: CanvasLayer) -> void:
	_main = main
	_putt = putt
	_cam_rig = cam_rig
	for arg in OS.get_cmdline_user_args():
		if arg == "--walkprobe":
			_walkprobe = true
		elif arg == "--swingsnap":
			_swingsnap = true
	_build_meter(ui)

# --- turn lifecycle ---------------------------------------------------------------

func begin_turn(p: int, avatar: PlayerAvatar, ball: Ball, is_bot: bool, chaos: bool) -> void:
	_reset_presentation()
	actor = p
	_avatar = avatar
	_ball = ball
	_is_bot = is_bot
	_chaos = chaos
	_pending_power = -1.0
	_auto_charge = false
	_fired = false
	_walk_t = 0.0
	_aim_dir = _dir_to_cup()
	if _avatar == null or _ball == null or ball.is_sunk or ball.is_dead or ball.is_petrified:
		state = State.IDLE
		return
	state = State.WALK
	_avatar.walk_to(_ball.global_position, _chaos)

## The current actor's avatar has arrived and holds the address stance.
func is_addressed(p: int) -> bool:
	return state == State.ADDRESS and actor == p

## An outside path fired a stroke (v3 drag, --autoplay direct, --autoputt,
## killcam tests). Stand down cleanly; the sim already has the ball.
func on_external_stroke() -> void:
	if _self_stroke:
		return
	if state == State.WALK or state == State.ADDRESS or state == State.CHARGE or (state == State.SWING and not _fired):
		_reset_presentation()
		if _avatar != null:
			_avatar.stop_walk()
			_avatar.play_idle()
		state = State.DONE

## Bot layer: fire the seeded (power, angle) through the swing. Pass-through.
func bot_swing(power: float, angle_deg: float) -> bool:
	if state != State.ADDRESS:
		return false
	_pending_power = power
	_pending_angle = angle_deg
	_aim_dir = _dir_for_angle(angle_deg)
	_start_swing()
	return true

## --swingplay harness: charge the meter up to `power` (visible, deterministic:
## ramp time is a pure function of power), then swing. Pass-through numbers.
func auto_swing(power: float, angle_deg: float) -> bool:
	if state != State.ADDRESS:
		return false
	_pending_power = power
	_pending_angle = angle_deg
	_aim_dir = _dir_for_angle(angle_deg)
	_auto_charge = true
	_charge_t = 0.0
	_charge_power = POWER_MIN
	state = State.CHARGE
	_meter_root.visible = true
	return true

# --- per-tick machine (fixed 1/60 physics delta => deterministic timings) ---------

func _physics_process(delta: float) -> void:
	match state:
		State.WALK:
			_tick_walk(delta)
		State.ADDRESS:
			_tick_address(delta)
		State.CHARGE:
			_tick_charge(delta)
		State.SWING:
			_tick_swing(delta)

func _tick_walk(delta: float) -> void:
	_walk_t += delta
	_avatar.walk_to(_ball.global_position, _chaos)
	var dist := _flat_dist(_avatar.global_position, _ball.global_position)
	if dist <= ARRIVE_DIST:
		_arrive(dist)
	elif _walk_t >= WALK_CAP:
		# Teleport-dolly the remainder (spec): land at the address point.
		var pos := _ball.global_position - _aim_dir * ADDRESS_BACK
		_avatar.teleport_to(Vector3(pos.x, maxf(_ball.global_position.y - 0.15, 0.02), pos.z))
		_arrive(_flat_dist(_avatar.global_position, _ball.global_position))

func _arrive(dist: float) -> void:
	_avatar.stop_walk()
	_avatar.play_loop("2H_Melee_Idle")
	_avatar.face_dir(_aim_dir)
	state = State.ADDRESS
	if _walkprobe:
		print("AVATAR_ARRIVED p=%d dist=%.2f" % [actor, dist])
	_snap_once("address")

func _tick_address(delta: float) -> void:
	if _chaos and _flat_dist(_avatar.global_position, _ball.global_position) > CHASE_DIST:
		state = State.WALK
		_walk_t = 0.0
		_putt.hide_preview()
		return
	if _is_bot:
		# hold the stance facing the cup; main's bot driver calls bot_swing().
		_settle_address(delta)
		return
	_aim_dir = _read_aim()
	_settle_address(delta)
	_putt.show_aim_preview(_aim_dir, POWER_MIN)
	if _charge_held():
		state = State.CHARGE
		_charge_t = 0.0
		_charge_power = POWER_MIN
		_meter_root.visible = true

func _tick_charge(delta: float) -> void:
	if _auto_charge:
		# deterministic ascend to the queued power, then swing with EXACT numbers
		_charge_t += delta
		_charge_power = minf(POWER_MIN + (POWER_MAX - POWER_MIN) * (_charge_t / POWER_CHARGE_T), _pending_power)
		_update_meter()
		_putt.show_aim_preview(_aim_dir, _charge_power)
		if _charge_power >= _pending_power - 0.001:
			_snap_once("charge")
			_start_swing()
		return
	_aim_dir = _read_aim()
	_settle_address(delta)
	_charge_t += delta
	var t := _pingpong01(_charge_t / POWER_CHARGE_T)
	_charge_power = lerpf(POWER_MIN, POWER_MAX, t)
	_update_meter()
	_putt.show_aim_preview(_aim_dir, _charge_power)
	if t > 0.45 and t < 0.55:
		_snap_once("charge")
	if not _charge_held():
		_start_swing()

func _start_swing() -> void:
	state = State.SWING
	_swing_t = 0.0
	_fired = false
	_meter_root.visible = false
	_avatar.face_dir(_aim_dir)
	_avatar.play_once("2H_Melee_Attack_Slice")

func _tick_swing(delta: float) -> void:
	_swing_t += delta
	if not _fired and _swing_t >= SWING_CONTACT_T:
		_fired = true
		_fire_contact()
	if _swing_t >= SWING_TOTAL_T:
		_putt.hide_preview()
		_avatar.play_loop("Idle")
		state = State.DONE

## THE frozen impulse. Bots/harness fire their exact queued numbers; humans fire
## the meter power + the spec's angle formula (inverse of debug_putt's rotation).
func _fire_contact() -> void:
	var power := _charge_power
	var angle := rad_to_deg(atan2(-_aim_dir.x, -_aim_dir.z))
	if _pending_power >= 0.0:
		power = _pending_power
		angle = _pending_angle
	_putt.ball = _ball
	_putt.hide_preview()
	_self_stroke = true
	_putt.debug_putt(power, angle)
	_self_stroke = false
	print("SWING_FIRE p=%d power=%.2f angle=%.2f phys=%d" % [actor, power, angle, Engine.get_physics_frames()])
	_snap_once("contact")
	if _swingsnap and not _snapped.has("blend"):
		_snapped["blend"] = true
		get_tree().create_timer(0.25).timeout.connect(func(): VerifyCapture.snap("blend"))
		get_tree().create_timer(0.95).timeout.connect(func(): VerifyCapture.snap("diorama"))
	contact_fired.emit(actor)

# --- helpers -----------------------------------------------------------------------

func _settle_address(delta: float) -> void:
	var pos := _ball.global_position - _aim_dir * ADDRESS_BACK
	_avatar.slide_toward(pos, delta)
	_avatar.face_dir(_aim_dir)

func _dir_to_cup() -> Vector3:
	if _main == null or _ball == null:
		return Vector3(0, 0, -1)
	var to: Vector3 = _main.course.cup_position() - _ball.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3(0, 0, -1)

## Inverse of debug_putt's rotation: angle 0 = -Z toward the fairway cup.
func _dir_for_angle(angle_deg: float) -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(angle_deg))

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _pingpong01(x: float) -> float:
	var m := fmod(x, 2.0)
	return m if m <= 1.0 else 2.0 - m

func _cam() -> Camera3D:
	return _cam_rig.get_node("Camera3D") as Camera3D

## Per-device aim (falls back to the last good direction, never zero).
func _read_aim() -> Vector3:
	var d: int = PlayerInput.device_of(actor)
	var cam := _cam()
	if d == -4:
		var v: Vector3 = PlayerInput.get_aim_dir(actor, _ball.global_position, cam)
		if v != Vector3.ZERO:
			return v
	elif d >= 0 or d == -1 or d == -2:
		var mv: Vector2 = PlayerInput.get_move(actor)
		if mv.length() > 0.2 and cam != null:
			var fwd := -cam.global_transform.basis.z
			fwd.y = 0.0
			var right := cam.global_transform.basis.x
			right.y = 0.0
			if fwd.length() > 0.01 and right.length() > 0.01:
				var v := right.normalized() * mv.x + fwd.normalized() * (-mv.y)
				if v.length() > 0.2:
					return v.normalized()
	else:
		# -3 mouse/shared (and unassigned hotseat): cursor on the ground plane
		var v := _cursor_dir(cam)
		if v != Vector3.ZERO:
			return v
	return _aim_dir

func _cursor_dir(cam: Camera3D) -> Vector3:
	if cam == null:
		return Vector3.ZERO
	var mp := cam.get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, _ball.global_position.y).intersects_ray(
		cam.project_ray_origin(mp), cam.project_ray_normal(mp))
	if hit == null:
		return Vector3.ZERO
	var dir: Vector3 = hit - _ball.global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.08 else Vector3.ZERO

func _charge_held() -> bool:
	var d: int = PlayerInput.device_of(actor)
	if d == -3 or d == -99:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return PlayerInput.is_down(actor, "a")

func _reset_presentation() -> void:
	if _meter_root != null:
		_meter_root.visible = false
	if _putt != null:
		_putt.hide_preview()

func _snap_once(tag: String) -> void:
	if not _swingsnap or _snapped.has(tag):
		return
	_snapped[tag] = true
	VerifyCapture.snap(tag)

# --- charge meter UI (presentation only) --------------------------------------------

func _build_meter(ui: CanvasLayer) -> void:
	_meter_root = PanelContainer.new()
	_meter_root.name = "ChargeMeter"
	_meter_root.visible = false
	_meter_root.anchor_left = 0.5
	_meter_root.anchor_right = 0.5
	_meter_root.anchor_top = 1.0
	_meter_root.anchor_bottom = 1.0
	_meter_root.offset_left = -160.0
	_meter_root.offset_right = 160.0
	_meter_root.offset_top = -86.0
	_meter_root.offset_bottom = -34.0
	ui.add_child(_meter_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_meter_root.add_child(box)
	_meter_label = Label.new()
	_meter_label.text = "POWER"
	_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meter_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_meter_label)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 0.85)
	bg.custom_minimum_size = Vector2(300, 18)
	box.add_child(bg)
	_meter_fill = ColorRect.new()
	_meter_fill.color = Color(0.3, 0.9, 0.35)
	_meter_fill.position = Vector2(2, 2)
	_meter_fill.size = Vector2(0, 14)
	bg.add_child(_meter_fill)

func _update_meter() -> void:
	var t := clampf((_charge_power - POWER_MIN) / (POWER_MAX - POWER_MIN), 0.0, 1.0)
	_meter_fill.size.x = 296.0 * t
	_meter_fill.color = Color(0.3, 0.9, 0.35).lerp(Color(0.95, 0.25, 0.2), t)
