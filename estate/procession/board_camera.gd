class_name ProcessionCamera
extends Node
## THE CAMERA DIRECTOR — a named-shot spine for THE PROCESSION's broadcast layer
## (doc 24 F1/F2/F3). One vocabulary of shots — ESTABLISH, WHOLE_BOARD,
## MOVE_TRAVEL, LANDING_PUSH, TWO_SHOT, BEACON_HERO, STANDINGS — each a
## position+look-at pair the director eases between, with a low-amplitude
## handheld sway layered on top so the frame never reads as a locked tripod.
##
## PRESENTATION ONLY. The director never reads or writes sim state and never
## draws from the sim rng. The handheld micro-motion is a deterministic layered-
## sine function of the engine clock (no rng at all), so two runs render
## byte-identically — and the headless receipt renders nothing. Every shot
## collapses to an instant snap under `fast`, so the soak never tweens.
##
## Motion discipline (never motion-sick): gentle SINE eases, NO camera roll
## (z-rotation is never touched), handheld amplitude in single-digit centimetres.

const UP := Vector3.UP

# Handheld sway — tiny positional + aim wobble, layered sines (no rng, no roll).
const SWAY_POS := Vector3(0.055, 0.038, 0.05)   # metres, per-axis amplitude
const SWAY_LOOK := 0.03                          # metres of aim drift

var cam: Camera3D = null
var board: ProcessionBoardPath = null
var fast := false

var _driving := false                 # when false, procession poses the cam directly
var _base_pos := Vector3(0, 23, 23)
var _base_look := Vector3(0, 0, -3)
var _tw: Tween = null
var _t := 0.0                          # handheld clock (seconds, wall time)
var _home_pos := Vector3(0, 23, 23)
var _home_look := Vector3(0, 0, -3)

func setup(camera: Camera3D, board_path: ProcessionBoardPath, is_fast: bool) -> void:
	cam = camera
	board = board_path
	fast = is_fast
	if board != null:
		_home_look = board.CENTER
	_base_pos = _home_pos
	_base_look = _home_look

## Begin driving: the director owns the camera each frame until hold() is called.
## No-op under fast (the soak never renders, so the director stays inert).
func activate() -> void:
	if fast:
		return
	_driving = true

## Release the camera so procession can pose it directly (capture hero shots,
## podium). The director stops writing to the cam until the next shot/activate.
func hold() -> void:
	_kill_tween()
	_driving = false

func _process(delta: float) -> void:
	if not _driving or not is_instance_valid(cam):
		return
	_t += delta
	cam.global_position = _base_pos + _handheld_pos()
	var look := _base_look + _handheld_look()
	if cam.global_position.distance_to(look) > 0.01:
		cam.look_at(look, UP)

## Layered-sine positional sway — three incommensurate frequencies per axis so
## the pattern never visibly repeats; amplitude a few centimetres.
func _handheld_pos() -> Vector3:
	return Vector3(
		SWAY_POS.x * (sin(_t * 0.73) * 0.6 + sin(_t * 1.71 + 1.1) * 0.4),
		SWAY_POS.y * (sin(_t * 0.91 + 1.3) * 0.7 + sin(_t * 2.13) * 0.3),
		SWAY_POS.z * (sin(_t * 0.61 + 2.1) * 0.6 + sin(_t * 1.29 + 0.4) * 0.4))

func _handheld_look() -> Vector3:
	return Vector3(
		SWAY_LOOK * sin(_t * 0.83 + 0.5),
		SWAY_LOOK * sin(_t * 1.07 + 2.2),
		0.0)

# --------------------------------------------------------------------------
# NAMED SHOTS — each sets the base pose (tweened) that _process composits.
# --------------------------------------------------------------------------

## ESTABLISH — a low, close pose at the manor gate (pre-flyover start frame).
func establish() -> void:
	_snap(Vector3(0.0, 6.5, 6.0), board.CENTER + Vector3(0, 1.6, -11.0))

## The opening flyover: a smooth multi-key tour (position AND look-at
## interpolated together) — the gate, a rise along the drive, the far sweep, a
## glide past the Codicil, then a settle to the whole-board overview. Awaits the
## tour but breaks EARLY the instant any player taps (skip: a Callable -> bool).
## Instant under fast.
func flyover(skip: Callable) -> void:
	activate()
	if fast or not is_instance_valid(cam) or board == null:
		_snap(_home_pos, _home_look)
		return
	var bpos := board.space_pos(board.beacon_index)
	var keys: Array = [
		{"p": Vector3(0.0, 6.5, 6.0), "l": board.CENTER + Vector3(0, 1.6, -11.0)},
		{"p": Vector3(-24.0, 13.0, 9.0), "l": board.CENTER + Vector3(-4, 0.6, 2)},
		{"p": Vector3(-9.0, 20.0, -28.0), "l": board.CENTER + Vector3(0, 1.0, -2)},
		{"p": bpos + Vector3(6.0, 8.0, 7.0), "l": bpos + Vector3(0, 1.6, 0)},
		{"p": _home_pos, "l": _home_look},
	]
	_kill_tween()
	var seg_dur := 1.0
	for i in range(1, keys.size()):
		var a: Dictionary = keys[i - 1]
		var b: Dictionary = keys[i]
		var ap: Vector3 = a["p"]
		var al: Vector3 = a["l"]
		var bp: Vector3 = b["p"]
		var bl: Vector3 = b["l"]
		# Drive the base pose across this segment while _process rides handheld on
		# top; poll for a skip every frame so any tap breaks the tour cleanly.
		var seg_t := 0.0
		while seg_t < seg_dur:
			if skip.is_valid() and bool(skip.call()):
				_snap(_home_pos, _home_look)
				return
			var k := seg_t / seg_dur
			var e := _ease_inout(k)
			_base_pos = ap.lerp(bp, e)
			_base_look = al.lerp(bl, e)
			await get_tree().process_frame
			seg_t += get_process_delta_time()
	_snap(_home_pos, _home_look)

## WHOLE_BOARD — ease back to the raked overview (the objective read).
func whole_board(dur := 0.6) -> void:
	activate()
	_ease_to(_home_pos, _home_look, dur)

## MOVE_TRAVEL (F2) — a low raking dolly that TRAVELS along the drive while all
## four pawns hop at once, so the procession reads as a procession, not a static
## overhead diagram. A gentle lateral push in the direction of travel.
func move_travel(dur := 0.9) -> void:
	activate()
	if fast:
		_snap(_home_pos, _home_look)
		return
	var c: Vector3 = board.CENTER
	var start := c + Vector3(-3.2, 9.0, 24.0)
	var end := c + Vector3(3.2, 8.4, 23.2)
	var look := c + Vector3(0, 1.1, 0)
	_kill_tween()
	_base_pos = start
	_base_look = look
	_tw = create_tween().set_parallel(true)
	_tw.tween_method(_set_base_pos, start, end, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## LANDING_PUSH (F3) — type-aware close-up on a landing with a short overshoot
## "punch-in" (past the target, settle back) — the single most reliable camera-
## juice trick. `shot` is {pos, look} from board.reveal_shot(idx, type).
func landing_push(shot: Dictionary) -> void:
	activate()
	var pos: Vector3 = shot.get("pos", _home_pos)
	var look: Vector3 = shot.get("look", _home_look)
	if fast:
		_snap(pos, look)
		return
	# Overshoot: nudge 12% closer to the subject, then settle back to the anchor.
	var overshoot: Vector3 = look + (pos - look) * 0.88
	_kill_tween()
	_base_look = look   # the aim leads; handheld rides on top
	_tw = create_tween()
	_tw.tween_method(_set_base_pos, _base_pos, overshoot, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_method(_set_base_pos, overshoot, pos, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.parallel().tween_method(_set_base_look, _base_look, look, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## TWO_SHOT (F3/F14) — frame two pawns facing off (vendetta), holding both in
## frame from a low outside angle on the midpoint.
func two_shot(a: Vector3, b: Vector3) -> void:
	activate()
	var mid := (a + b) * 0.5
	var span: float = maxf(3.0, a.distance_to(b))
	var out := mid - board.CENTER
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	var pos := mid + out * (span * 0.9 + 2.4) + Vector3(0, 2.2, 0)
	var look := mid + Vector3(0, 0.9, 0)
	if fast:
		_snap(pos, look)
		return
	_ease_to(pos, look, 0.5)

## BEACON_HERO (F17) — a hero low-angle push toward the Codicil so its gold glow
## flares into lens as the Deed is claimed.
func beacon_hero(beacon_pos: Vector3, dur := 0.55) -> void:
	activate()
	var out := beacon_pos - board.CENTER
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	var pos := beacon_pos + out * 3.6 + Vector3(0, 2.0, 0)
	var look := beacon_pos + Vector3(0, 1.5, 0)
	if fast:
		_snap(pos, look)
		return
	_kill_tween()
	_tw = create_tween()
	_tw.tween_method(_set_base_pos, _base_pos, pos, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_method(_set_base_look, _base_look, look, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## STANDINGS (F4) — a slow truck across the ordered pawns, pulling up and back so
## the whole pecking order reads. `positions` are pawn world points, best-first.
func standings(points: Array) -> void:
	activate()
	if points.is_empty():
		whole_board(0.6)
		return
	var lead: Vector3 = points[0]
	var pos := Vector3(lead.x * 0.4, 15.0, 20.0)
	var look := board.CENTER + Vector3(0, 0.6, 0)
	if fast:
		_snap(pos, look)
		return
	_ease_to(pos, look, 0.8)

# --------------------------------------------------------------------------
# internals
# --------------------------------------------------------------------------
func _snap(pos: Vector3, look: Vector3) -> void:
	_kill_tween()
	_base_pos = pos
	_base_look = look
	if is_instance_valid(cam) and not _driving:
		# Even when not driving, honour an explicit snap so a held cam still lands.
		cam.global_position = pos
		if pos.distance_to(look) > 0.01:
			cam.look_at(look, UP)

func _ease_to(pos: Vector3, look: Vector3, dur: float) -> void:
	if fast or dur <= 0.0:
		_base_pos = pos
		_base_look = look
		return
	_kill_tween()
	_tw = create_tween().set_parallel(true)
	_tw.tween_method(_set_base_pos, _base_pos, pos, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_method(_set_base_look, _base_look, look, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_base_pos(v: Vector3) -> void:
	_base_pos = v

func _set_base_look(v: Vector3) -> void:
	_base_look = v

func _kill_tween() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null

func _ease_inout(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	# Smoothstep-style sine ease so segment joins stay continuous.
	return 0.5 - 0.5 * cos(x * PI)
