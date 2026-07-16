class_name ProcessionExecutorBody
extends Node3D
## THE EXECUTOR, EMBODIED (doc 24 F7). A static Meshy figure given the illusion
## of life by PUPPET TRANSFORMS ONLY — no rig, no skeleton. The animation
## research is emphatic that "alive" comes from a breathing idle, anticipation,
## and follow-through, not from bones (doc 24 §2). So this node owns a small
## vocabulary of tween recipes on the figure's own transform:
##
##   • BREATHING IDLE — a ~16/min vertical bob + a lazy sway, always running.
##   • ANTICIPATE     — a lean BACK before a reveal (the wind-up).
##   • PRESENT        — a snap FORWARD + a turn toward the stone being named.
##   • NOD / APPROVE  — a slow assenting dip (good news, a Codicil claim).
##   • TUT            — a dry sideways head-tilt (a grave, a loss).
##   • RISE           — arms-up escalation (THE HOUSE AWAKENS).
##   • PAGE-TURN      — a downward glance over the ledger, between rounds.
##
## Every gesture animates a small set of OFFSET vars (`_g_*`); `_process`
## composes them with the breathing each frame. Because gestures overshoot and
## settle (BACK/ELASTIC easings) the motion carries follow-through without a
## second spring, and because a new gesture kills the previous tween the whole
## library is interruptible and frame-rate independent. Presentation only:
## nothing here touches the sim, the rng, or the tally.

# ---- the figure ---------------------------------------------------------------
# SWAP-CONST: last night's host GLB. A finer executor figure may land later
# tonight — point this at it and nothing else changes (doc 24 F6/F7). The
# manifest ships this at the meshy ROOT, not generated/ (see LICENSE-NOTE).
const EXECUTOR_GLB := "res://assets/models/meshy/executor_butler.glb"
# THE RIG (day 5): the same butler through Meshy auto-rig + preset Idle. When
# this ships, he breathes from the skeleton and the tween idle steps back to a
# garnish; the gesture library stays, layered on the pivot above the bones.
# Rigged exports must NOT be AABB-sized (mesh AABB reads ~1/100) — native
# height comes from the rig request (tools/meshy_rig_trial_report.json).
const EXECUTOR_GLB_RIGGED := "res://assets/models/meshy/executor_butler_idle.glb"
const RIGGED_NATIVE_HEIGHT := 1.9
const FIGURE_HEIGHT := 2.55
# The GLB's modelled front may not be +Z; nudge this (radians) if he faces away.
const FIGURE_YAW_OFFSET := 0.0

# ---- breathing ----------------------------------------------------------------
const BREATHE_FREQ := 1.75          # rad/s → ~16-17 breaths/min
const BREATHE_BOB := 0.018          # metres of vertical sway (subtle, ~2cm)
const BREATHE_SWAY := 0.020         # radians of idle lean/roll

# ---- gesture shape ------------------------------------------------------------
const LEAN_PRESENT := 0.16          # forward lean at the reveal (radians)
const LEAN_BACK := 0.085            # anticipation lean-back (radians)
const TILT_TUT := 0.14              # dry head-tilt amount (radians, Z)
const NOD_DIP := 0.11               # nod dip (radians, forward)
const YAW_CLAMP := 0.62             # max turn toward a stone (radians, ~35°)

var _pivot: Node3D = null           # everything animated hangs off this
var _figure: Node3D = null          # the MeshyProp wrapper
var _base_y := 0.0                  # figure foot height (placement)
var _base_yaw := 0.0                # facing set at placement (world radians)
var _breathe_t := 0.0
var _prng := RandomNumberGenerator.new()

# Live gesture offsets, composed every frame in _process.
var _g_lean := 0.0                  # rotation.x  (+forward)
var _g_tilt := 0.0                  # rotation.z  (dry tilt)
var _g_yaw := 0.0                   # rotation.y  (turn toward a stone; offset)
var _g_bob := 0.0                   # position.y  (nod / page dip)
var _g_scale := 0.0                 # uniform squash on emphasis
var _gesture_tw: Tween = null
var _rigged := false                # skeletal idle carries the breath

func _init(prng_seed := 0) -> void:
	_prng.seed = prng_seed
	_breathe_t = _prng.randf() * TAU   # desync the idle phase per night

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_rigged = ResourceLoader.exists(EXECUTOR_GLB_RIGGED)
	if _rigged:
		_figure = MeshyProp.instance_rigged(EXECUTOR_GLB_RIGGED,
				RIGGED_NATIVE_HEIGHT, FIGURE_HEIGHT, rad_to_deg(FIGURE_YAW_OFFSET))
	else:
		_figure = MeshyProp.instance(EXECUTOR_GLB, FIGURE_HEIGHT, rad_to_deg(FIGURE_YAW_OFFSET))
	_figure.name = "Figure"
	_pivot.add_child(_figure)

## Plant the host on the drive, facing `face_target`. Call after add_child.
func stand_at(pos: Vector3, face_target: Vector3) -> void:
	global_position = pos
	_base_y = 0.0
	var dir := face_target - pos
	dir.y = 0.0
	if dir.length() > 0.01:
		_base_yaw = atan2(dir.x, dir.z)

## The world yaw (as a _g_yaw OFFSET from base facing) that turns the host toward
## `pos`, clamped so he inclines toward a stone without spinning on the spot.
func yaw_toward(pos: Vector3) -> float:
	var dir := pos - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return 0.0
	var want := atan2(dir.x, dir.z)
	var delta := wrapf(want - _base_yaw, -PI, PI)
	return clampf(delta, -YAW_CLAMP, YAW_CLAMP)

func _process(delta: float) -> void:
	if _pivot == null:
		return
	_breathe_t += delta
	# With bones, the skeletal idle owns the breath; the tween idle drops to a
	# whisper so the two rhythms never visibly fight.
	var breath := 0.35 if _rigged else 1.0
	var bob := sin(_breathe_t * BREATHE_FREQ) * BREATHE_BOB * breath
	var sway := sin(_breathe_t * BREATHE_FREQ * 0.5 + 0.6) * BREATHE_SWAY * breath
	_pivot.position.y = _base_y + _g_bob + bob
	_pivot.rotation.x = _g_lean + sway * 0.35
	_pivot.rotation.z = _g_tilt + sway
	_pivot.rotation.y = _base_yaw + _g_yaw
	var s := 1.0 + _g_scale
	_pivot.scale = Vector3(1.0 + _g_scale * 0.5, s, 1.0 + _g_scale * 0.5)

# ---- gesture library ----------------------------------------------------------
func _new_gesture() -> Tween:
	if _gesture_tw != null and _gesture_tw.is_valid():
		_gesture_tw.kill()
	_gesture_tw = create_tween()
	return _gesture_tw

## The wind-up: lean back and incline toward the stone about to be named. Bigger
## stakes lean harder. Held by the caller (executor.anticipate) for the pause.
func anticipate(yaw_off: float, stakes: float) -> void:
	var back := LEAN_BACK * (0.6 + 0.5 * stakes)
	var tw := _new_gesture()
	tw.set_parallel(true)
	tw.tween_property(self, "_g_lean", -back, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_g_yaw", yaw_off * 0.6, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## The strike: snap FORWARD to present the stone, then play the reaction beat.
## `mood`: one of ProcessionExecutor.MOOD_* — decides the follow-through gesture.
func present(yaw_off: float, stakes: float, mood: int) -> void:
	var lean := LEAN_PRESENT * (0.7 + 0.5 * stakes)
	var tw := _new_gesture()
	tw.set_parallel(true)
	# Snap forward with a touch of overshoot (BACK ease = built-in follow-through).
	tw.tween_property(self, "_g_lean", lean, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_g_yaw", yaw_off, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_g_scale", 0.04 + 0.05 * stakes, 0.10).set_trans(Tween.TRANS_SINE)
	# then the reaction, chained after the strike settles.
	tw.chain().tween_property(self, "_g_scale", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	_react(mood)

func _react(mood: int) -> void:
	# `mood` mirrors ProcessionExecutor.MOOD_*; kept as ints so the body needn't
	# preload the host. NEUTRAL/BLANK deliberately do nothing (the dry anticlimax).
	match mood:
		1: _nod(0.7)        # MOOD_GOOD
		2: _tut()           # MOOD_BAD
		3: _nod(1.0)        # MOOD_CODICIL — a slow, weighty assent
		4: _watch()         # MOOD_WATCH — a considering tilt
		5: rise()           # MOOD_RISE

## Public assent, for the eulogy's solemn reading cadence.
func nod(weight := 0.6) -> void:
	_nod(weight)

## A slow assenting dip — good news, a Codicil claimed.
func _nod(weight: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_g_bob", -NOD_DIP * weight, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_g_bob", 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## A single dry sideways head-tilt — a grave, a loss. Understatement, not glee.
func _tut() -> void:
	var dir := 1.0 if _prng.randf() < 0.5 else -1.0
	var tw := create_tween()
	tw.tween_property(self, "_g_tilt", TILT_TUT * dir, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_g_tilt", 0.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## A considering half-tilt held a beat — a vendetta, the séance.
func _watch() -> void:
	var dir := 1.0 if _prng.randf() < 0.5 else -1.0
	var tw := create_tween()
	tw.tween_property(self, "_g_tilt", TILT_TUT * 0.55 * dir, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(self, "_g_tilt", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## THE HOUSE AWAKENS — the host rises, arms of the cloak flung up, then settles.
func rise() -> void:
	var tw := _new_gesture()
	tw.set_parallel(true)
	tw.tween_property(self, "_g_bob", 0.22, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_g_scale", 0.10, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().set_parallel(true)
	tw.tween_property(self, "_g_bob", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_g_scale", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The ledger turns between rounds — a downward glance and a small forward bow.
func page_turn() -> void:
	var tw := _new_gesture()
	tw.tween_property(self, "_g_lean", 0.10, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_g_bob", -0.03, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.25)
	tw.tween_property(self, "_g_lean", 0.03, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_g_bob", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

## Ease home to the idle rest pose (called at the close of a reveal cascade).
func settle() -> void:
	var tw := _new_gesture()
	tw.set_parallel(true)
	tw.tween_property(self, "_g_lean", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_g_yaw", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_g_tilt", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
