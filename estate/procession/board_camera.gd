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
var board: ProcessionBoardGraph = null
var fast := false

var _driving := false                 # when false, procession poses the cam directly
## Stills-lane forensics: every named shot logs itself + its caller, so a frame
## that faces the wrong way can name the intruder instead of leaving a guess.
var trace := false
# A gentle 3/4 overview (a touch off the grounds' axis) instead of a dead-centre,
# perfectly-symmetric head-on — reads more cinematic while still showing all
# three roads. Home comes from the board (OVERVIEW_POS) so the director and
# procession's posed shots agree by construction.
var _base_pos := ProcessionBoardGraph.OVERVIEW_POS
var _base_look := Vector3.ZERO
var _tw: Tween = null
var _t := 0.0                          # handheld clock (seconds, wall time)
var _home_pos := ProcessionBoardGraph.OVERVIEW_POS
var _home_look := Vector3.ZERO

func setup(camera: Camera3D, board_graph: ProcessionBoardGraph, is_fast: bool) -> void:
	cam = camera
	board = board_graph
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
	_trace("hold")
	_kill_tween()
	_driving = false

func _trace(shot: String) -> void:
	if not trace:
		return
	var who := "?"
	var st := get_stack()
	if st.size() > 2:
		who = "%s:%d" % [String(st[2]["function"]), int(st[2]["line"])]
	print("CAMTRACE shot=%s caller=%s base=%s look=%s" % [shot, who,
		str(_base_pos), str(_base_look)])

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

## ESTABLISH — a low, close pose at the LYCHGATE looking up the road north
## (pre-flyover start frame).
func establish() -> void:
	_trace("establish")
	var lych := board.lychgate_pos()
	_snap(lych + Vector3(0.0, 5.5, 9.0), lych + Vector3(0, 1.6, -14.0))

## The opening flyover: a smooth multi-key tour (position AND look-at
## interpolated together) — the lychgate, a rise over GARDEN ROW, the sweep
## across HOLLOW WOODS and WEEPING VALLEY, a hero glide onto the MANOR GATE,
## then a settle to the whole-board overview. Awaits the tour but breaks EARLY
## the instant any player taps (skip: a Callable -> bool). Instant under fast.
func flyover(skip: Callable) -> void:
	_trace("flyover")
	activate()
	if fast or not is_instance_valid(cam) or board == null:
		_snap(_home_pos, _home_look)
		return
	var lych := board.lychgate_pos()
	var garden := board.route_mid_pos("garden")
	var valley := board.route_mid_pos("valley")
	var gate := board.gate_pos()
	var keys: Array = [
		{"p": lych + Vector3(0.0, 5.5, 9.0), "l": lych + Vector3(0, 1.6, -14.0)},
		{"p": garden + Vector3(9.0, 11.0, 5.0), "l": garden + Vector3(-2, 0.6, -3)},
		{"p": valley + Vector3(-10.0, 13.0, 0.0), "l": valley + Vector3(2, 0.6, -3)},
		{"p": gate + Vector3(5.0, 7.5, 9.0), "l": gate + Vector3(0, 2.2, 0)},
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
	_trace("whole_board")
	activate()
	_ease_to(_home_pos, _home_look, dur)

## MOVE_TRAVEL (F2) — a low raking dolly that TRAVELS along the drive while all
## four pawns hop at once, so the procession reads as a procession, not a static
## overhead diagram. A gentle lateral push in the direction of travel.
func move_travel(dur := 0.9) -> void:
	_trace("move_travel")
	activate()
	if fast:
		_snap(_home_pos, _home_look)
		return
	var c: Vector3 = board.CENTER
	var start := c + Vector3(-4.0, 12.0, 32.0)
	var end := c + Vector3(4.0, 11.2, 31.0)
	var look := c + Vector3(0, 1.1, 0)
	_kill_tween()
	# Ease DOWN from wherever we were (usually the whole-board overview) into the
	# low raking start, THEN push laterally along the drive — no hard cut into the
	# dolly (the old code snapped _base_pos to `start`, a visible jump each round).
	_tw = create_tween()
	_tw.tween_method(_set_base_pos, _base_pos, start, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.parallel().tween_method(_set_base_look, _base_look, look, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_method(_set_base_pos, start, end, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## LANDING_PUSH (F3) — type-aware close-up on a landing with a short overshoot
## "punch-in" (past the target, settle back) — the single most reliable camera-
## juice trick. `shot` is {pos, look} from board.reveal_shot(idx, type).
func landing_push(shot: Dictionary) -> void:
	_trace("landing_push")
	activate()
	var pos: Vector3 = shot.get("pos", _home_pos)
	var look: Vector3 = shot.get("look", _home_look)
	if fast:
		_snap(pos, look)
		return
	# Overshoot: nudge 12% closer to the subject, then settle back to the anchor.
	var overshoot: Vector3 = look + (pos - look) * 0.88
	_kill_tween()
	# Ease the AIM from the previous shot's look into this landing (the old code
	# snapped _base_look, so the frame's aim cut between reveals). The aim leads the
	# push and handheld rides on top.
	var from_look := _base_look
	_tw = create_tween()
	_tw.tween_method(_set_base_pos, _base_pos, overshoot, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_method(_set_base_pos, overshoot, pos, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.parallel().tween_method(_set_base_look, from_look, look, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## OVER_SHOULDER (P3, doc 28 §9) — during a seat's LAST BREATH roll, frame over
## the FIGURINE's shoulder looking down its road, so the glowing heatmap stones
## run up-frame while the meter sweeps at bottom-center (its CanvasLayer stays
## on top by construction). `ease_in` plays the 0.45s settle on the FIRST
## showing only; after that the shot is a hard cut — the roll's whole camera
## cost stays inside the ≤5s roll-act budget.
func over_shoulder(pawn_pos: Vector3, dir: Vector3, ease_in := false,
		gate_clearance := false) -> void:
	_trace("over_shoulder")
	activate()
	var d := dir
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	var right := d.cross(UP).normalized()
	# gate_clearance: the roller stands under a hero arch (the LYCHGATE) — a
	# tight shoulder frame would sit inside the model. Swing wide of the posts,
	# angled down the same road, so the figurine AND the heatmap still read.
	var pos := pawn_pos - d * 3.6 + right * 3.4 + Vector3(0, 3.0, 0) if gate_clearance \
		else pawn_pos - d * 2.9 + right * 0.9 + Vector3(0, 2.5, 0)
	# Aim a touch right of the road so the figurine + its stones sit left of
	# centre — clear of the meter's bottom-centre lane.
	var look := pawn_pos + d * 7.0 + right * 1.3 + Vector3(0, 0.3, 0)
	if fast:
		_snap(pos, look)
		return
	if ease_in:
		_ease_to(pos, look, 0.45)
	else:
		_snap(pos, look)

## TRAVEL_CUT (P3) — on release, CUT to a medium of the landing area (the
## reveal_shot anchor pulled back and up) so the figurine hops through frame
## toward its stone; the landing push-in then does the close-up. A hard cut,
## never an ease — the release lands the frame.
func travel_cut(shot: Dictionary) -> void:
	_trace("travel_cut")
	activate()
	var pos: Vector3 = shot.get("pos", _home_pos)
	var look: Vector3 = shot.get("look", _home_look)
	var wide := look + (pos - look) * 2.1 + Vector3(0, 2.6, 0)
	_snap(wide, look)

## TWO_SHOT (F3/F14) — frame two pawns facing off (vendetta), holding both in
## frame from a low outside angle on the midpoint.
func two_shot(a: Vector3, b: Vector3) -> void:
	_trace("two_shot")
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
	_trace("beacon_hero")
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
	_trace("standings")
	activate()
	if points.is_empty():
		whole_board(0.6)
		return
	var lead: Vector3 = points[0]
	var pos := Vector3(lead.x * 0.4, 22.0, 30.0)
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
