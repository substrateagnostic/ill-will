class_name BoardOrbit
extends Node
## THE PLAYER CAMERA — the strategy-layer lens (doc 34 §1, ruling #77).
##
## "Downtime is only downtime when you can't strategize." A high THIRD-PERSON
## Smite-pitch camera that FOLLOWS the acting figurine, always angled so the
## road ahead reads — the player owns it, orbiting (yaw) and zooming (distance)
## on the RIGHT STICK / MOUSE, orthogonal to the four-button verb budget. This
## replaces the old forced whole-board overhead resting state, which showed
## nothing you could plan against (doc 34 §5: whole_board the RESTING STATE
## dies; whole_board the director SHOT lives on in board_camera).
##
## CAMERA LAW (doc 34 §2): one master at a time. The orbit and the director
## (board_camera) are the two owners of the main camera; only one is CURRENT.
## activate() takes the frame (yielding the director via hold()); a director
## ceremony's activate() yields the orbit right back. An owner that has yielded
## writes NOTHING — clause 1. While driving, the orbit is the SOLE writer of the
## main camera's position (clause 2) and look_at (clause 3).
##
## Determinism (doc 24 §0): presentation only. Reads input + the wall clock,
## never sim state or rng. Inert under `fast` (the soak never renders) and under
## headless (no input, no DisplayServer) — so an all-bot receipt is byte-
## identical whether the orbit exists or not.

const UP := Vector3.UP

# Smite-style framing. Pitch is fixed high; the player owns yaw + distance.
const PITCH_DEG := 56.0                 # down-angle of the camera over the focus
const DIST_MIN := 7.0                   # zoom clamp (world units)
const DIST_MAX := 30.0
const DIST_DEFAULT := 15.0
const DIST_SURVEY := 27.0               # the "survey the board" pull-back
const AHEAD_BIAS := 6.5                 # look target pushed this far up the road
const LOOK_UP := 1.1                    # raise the look target off the ground
const FOCUS_UP := 0.6                   # raise the orbit pivot off the ground

# Player control rates.
const YAW_RATE := 2.6                   # rad/sec at full stick
const ZOOM_RATE := 22.0                 # units/sec at full stick
const MOUSE_YAW := 0.006                # rad per pixel of right-drag
const MOUSE_ZOOM := 1.4                 # units per wheel notch
const STICK_DEADZONE := 0.2
# When the player stops steering, the yaw eases back to the road-aligned base so
# the road ahead re-centres (never fights live input — only realigns at rest).
const REALIGN_DELAY := 1.4              # seconds of no input before realign
const REALIGN_RATE := 1.5               # realign lerp speed
const FOLLOW_K := 9.0                   # position follow smoothing (higher=snappier)

var cam: Camera3D = null
var board: ProcessionBoardGraph = null
var fast := false
var _director: ProcessionCamera = null

var _driving := false
var _focus_seat := -1                   # >=0: follow this seat's live pawn
var _focus_static := Vector3.ZERO       # used when _focus_seat < 0
var _road_dir := Vector3.FORWARD        # travel direction at the focus (for base yaw)
var _yaw := 0.0                         # current orbit yaw (world)
var _yaw_user := 0.0                    # player's offset from the road-aligned base
var _dist := DIST_DEFAULT
var _idle := 0.0                        # seconds since the last player steer
var _cam_pos := Vector3.ZERO            # smoothed camera position
var _inited := false
# Mouse steering accumulators (drained each frame).
var _m_yaw := 0.0
var _m_zoom := 0.0
var _m_dragging := false

func setup(camera: Camera3D, board_graph: ProcessionBoardGraph, is_fast: bool) -> void:
	cam = camera
	board = board_graph
	fast = is_fast
	_dist = DIST_DEFAULT

## Mutual-exclusion back-reference: the orbit yields the director on activate,
## and the director yields the orbit on any of its named shots (board_camera.
## activate). Set once at build.
func set_director(d: ProcessionCamera) -> void:
	_director = d

func is_driving() -> bool:
	return _driving

## Take the main camera (player-owned time). Yields the director. No-op under
## fast — the soak never renders, so the orbit stays inert.
func activate() -> void:
	if fast:
		return
	if _director != null:
		_director.hold()
	if not _driving:
		# Seed the smoothed pose from wherever the camera stands so the handoff
		# from a director beat eases in, never cuts.
		if is_instance_valid(cam):
			_cam_pos = cam.global_position
		_inited = true
	_driving = true

## Release the camera (a director beat or a manual capture pose takes over). An
## owner that has yielded writes nothing.
func hold() -> void:
	_driving = false

## Follow a seat's LIVE pawn — the acting figurine during its roll/turn.
func follow_seat(seat: int) -> void:
	_focus_seat = seat
	_refresh_road_dir()

## Focus a fixed world point (e.g. a survey of the board centre).
func focus_point(p: Vector3, road_dir := Vector3.FORWARD) -> void:
	_focus_seat = -1
	_focus_static = p
	_road_dir = road_dir if road_dir.length() > 0.05 else Vector3.FORWARD

## Pull back to a wide survey of the board — "between-turn stillness, survey the
## board, read the award races" (doc 34 §1). Keeps the current focus.
func survey() -> void:
	_dist = DIST_SURVEY
	_idle = REALIGN_DELAY   # let the road re-centre for the wide read

func _refresh_road_dir() -> void:
	if board == null:
		return
	var f := _focus_pos()
	var to_gate := board.gate_pos() - f
	to_gate.y = 0.0
	_road_dir = to_gate.normalized() if to_gate.length() > 0.1 else Vector3.FORWARD

func _focus_pos() -> Vector3:
	if _focus_seat >= 0 and board != null and board.pawns.has(_focus_seat):
		return (board.pawns[_focus_seat] as Node3D).global_position
	return _focus_static

func _process(delta: float) -> void:
	if not _driving or not is_instance_valid(cam) or board == null:
		return
	if not cam.current:
		return   # a module owns the frame; don't fight a non-current camera
	_refresh_road_dir()
	_read_input(delta)

	# Base yaw sits BEHIND the pawn relative to travel, so the road runs up-frame.
	var base_yaw := atan2(-_road_dir.x, -_road_dir.z)
	if _idle >= REALIGN_DELAY:
		# Ease the player's offset back to zero so the road re-centres at rest.
		_yaw_user = lerpf(_yaw_user, 0.0, clampf(REALIGN_RATE * delta, 0.0, 1.0))
	_yaw = base_yaw + _yaw_user

	var focus := _focus_pos() + Vector3(0, FOCUS_UP, 0)
	var pitch := deg_to_rad(PITCH_DEG)
	# Offset from focus to camera: behind (horizontal) + above (pitch).
	var horiz := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var offset := (horiz * cos(pitch) + UP * sin(pitch)) * _dist
	var target_pos := focus + offset

	# Exponential follow so a walking pawn / focus change eases, never snaps.
	var a := clampf(1.0 - exp(-FOLLOW_K * delta), 0.0, 1.0)
	_cam_pos = _cam_pos.lerp(target_pos, a) if _inited else target_pos
	_inited = true

	cam.global_position = _cam_pos
	# Look a touch UP the road so the board AHEAD is always in frame to plan.
	var look := focus + _road_dir * AHEAD_BIAS + Vector3(0, LOOK_UP, 0)
	if _cam_pos.distance_to(look) > 0.01:
		cam.look_at(look, UP)

## Right stick (any pad) = orbit yaw + zoom; mouse right-drag = yaw, wheel = zoom.
## Orthogonal to the face-button verbs (doc 34 §1). No input => no motion, so a
## bot capture is steady and byte-identical.
func _read_input(delta: float) -> void:
	if fast:
		return
	var yaw_in := 0.0
	var zoom_in := 0.0
	for pad in Input.get_connected_joypads():
		var rx := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		if absf(rx) > STICK_DEADZONE:
			yaw_in += rx
		if absf(ry) > STICK_DEADZONE:
			zoom_in += ry
	var steering := false
	# Right stick (rate * delta).
	if absf(yaw_in) > 0.001:
		_yaw_user += yaw_in * YAW_RATE * delta
		steering = true
	if absf(zoom_in) > 0.001:
		_dist = clampf(_dist + zoom_in * ZOOM_RATE * delta, DIST_MIN, DIST_MAX)
		steering = true
	# Mouse deltas (already in radians / world units, drained per frame).
	if absf(_m_yaw) > 0.00001:
		_yaw_user += _m_yaw
		steering = true
	if absf(_m_zoom) > 0.00001:
		_dist = clampf(_dist + _m_zoom, DIST_MIN, DIST_MAX)
		steering = true
	_m_yaw = 0.0
	_m_zoom = 0.0
	if steering:
		_idle = 0.0
	else:
		_idle += delta

func _unhandled_input(event: InputEvent) -> void:
	if fast or not _driving:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_m_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_m_zoom -= MOUSE_ZOOM
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_m_zoom += MOUSE_ZOOM
	elif event is InputEventMouseMotion and _m_dragging:
		_m_yaw += (event as InputEventMouseMotion).relative.x * MOUSE_YAW
