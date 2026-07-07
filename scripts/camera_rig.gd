extends Node3D
## Diorama camera: frames the whole course from a 3/4 angle, with a gentle
## lean toward the ball so motion feels tracked without losing the overview.
##
## PAR v4: gains a mode enum. DIORAMA is the v3 pose (build/draft/roll/chaos).
## SHOT is the embodied aim camera — owner-corrected to a SMITE-style
## SKILL-SHOT framing, not a TPS shoulder cam: high pitched-down angle
## (~55 deg), behind/above the golfer, so the aim arrow + dots read across the
## whole lane (traps and cup in one glance) and the character is a reference
## point at the bottom of the view. set_mode() blends over the named times.
## shake / focus_on / start_flyover act on `cam` and stay mode-agnostic.

enum Mode { DIORAMA, SHOT }

const CAM_TO_SHOT := 0.6
const CAM_TO_DIORAMA := 0.5
const CAM_SHOT_BACK := 2.0    # m behind the avatar, along -facing
const CAM_SHOT_UP := 11.5     # m above the green (steep skill-shot pitch ~53deg)
const CAM_SHOT_AHEAD := 6.0   # look target this far down the aim line
## Tee-off glare fix (outside tester round 2: "lighting on tee off is too
## bright"). The SHOT pose stares straight down the sunlit lane, so bright
## green + white wall caps fill ~the whole frame. Scoped exposure drop while in
## SHOT mode reads overcast-bright; DIORAMA keeps the stock 1.0 exposure so the
## build/roll overview is untouched. Presentation only — zero physics impact.
const SHOT_EXPOSURE := 0.58

@export var course_center := Vector3(0, 0, -6.5)
@export var course_extent := Vector3(3.0, 0.0, 8.5)
@export var lean_strength := 0.22
## Where the camera parks between cinematics; main sets this from the course.
var home_position := Vector3(0, 12.5, 4.5)

var ball: Ball
var mode: int = Mode.DIORAMA
## The acting avatar the skill-shot pose frames (set by main per turn).
var shot_avatar: Node3D = null
var _shake := 0.0
var cinematic := false
var _focus_override := Vector3.INF
var _focus_timer := 0.0
var _blend_from := Transform3D.IDENTITY
var _blend_t := -1.0
var _blend_dur := 0.5
var _expo_tween: Tween = null

@onready var cam: Camera3D = $Camera3D

func set_mode(m: int, avatar: Node3D = null) -> void:
	if m == mode and (m != Mode.SHOT or avatar == shot_avatar):
		return
	mode = m
	shot_avatar = avatar
	_blend_from = cam.global_transform
	_blend_t = 0.0
	_blend_dur = CAM_TO_SHOT if m == Mode.SHOT else CAM_TO_DIORAMA
	# The skill-shot cam sits ~11m from the golfer; the diorama's near-blur
	# plane (5m) would smear the whole aim read. Presentation only.
	if cam.attributes != null:
		cam.attributes.dof_blur_near_enabled = m == Mode.DIORAMA
		# Glare fix: ease exposure down over the same blend so there's no pop.
		if _expo_tween != null and _expo_tween.is_valid():
			_expo_tween.kill()
		_expo_tween = create_tween()
		_expo_tween.tween_property(cam.attributes, "exposure_multiplier",
			SHOT_EXPOSURE if m == Mode.SHOT else 1.0, _blend_dur)

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func focus_on(pos: Vector3, duration: float) -> void:
	_focus_override = pos
	_focus_timer = duration

func start_flyover(duration: float) -> Tween:
	cinematic = true
	var start_pos := course_center + Vector3(course_extent.x * 0.7, 1.6, course_extent.z * 0.85 + 4.0)
	var end_pos := course_center + Vector3(-course_extent.x * 0.7, 1.8, -course_extent.z * 1.05 - 2.5)
	cam.global_position = start_pos
	var tw := create_tween()
	tw.tween_method(_flyover_step.bind(start_pos, end_pos), 0.0, 1.0, duration)
	tw.tween_callback(func():
		cinematic = false
		cam.position = home_position)
	return tw

func _flyover_step(t: float, start_pos: Vector3, end_pos: Vector3) -> void:
	var eased := ease(t, -1.8)
	cam.global_position = start_pos.lerp(end_pos, eased)
	var look_target := course_center + Vector3(0, 0.3, lerpf(course_extent.z * 0.55, -course_extent.z * 0.55, eased))
	cam.look_at(look_target, Vector3.UP)

## Target pose for the current mode. DIORAMA reproduces the v3 behavior exactly
## when the camera already parks at home (position home, lean toward the ball).
func _target_pose() -> Transform3D:
	if mode == Mode.SHOT and shot_avatar != null:
		var facing: Vector3 = shot_avatar.facing
		if facing.length() < 0.01:
			facing = Vector3(0, 0, -1)
		# While the golfer walks, anchor the frame on the golfer (the stride
		# reads); at address the anchor is the ball — the two coincide at the
		# 0.55m address distance, so the handoff has no pop.
		var anchor: Vector3 = shot_avatar.global_position + facing * 0.55
		if ball != null and not shot_avatar.is_walking():
			anchor = ball.global_position
		var pos: Vector3 = shot_avatar.global_position - facing * CAM_SHOT_BACK + Vector3.UP * CAM_SHOT_UP
		# Look DOWN THE AIM LINE, not at the ball: the golfer reads as a
		# reference point at the bottom edge while the lane fills the frame.
		var look: Vector3 = anchor + facing * CAM_SHOT_AHEAD
		var fwd := look - pos
		if fwd.length() < 0.05:
			fwd = facing
		return Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	var focus := course_center
	if _focus_timer > 0.0:
		focus = _focus_override
	elif ball != null and not ball.is_sunk:
		focus = course_center.lerp(ball.global_position, lean_strength)
	var home := global_transform * home_position
	return Transform3D(Basis.looking_at(focus - home, Vector3.UP), home)

func _process(delta: float) -> void:
	if cinematic:
		return
	if _focus_timer > 0.0:
		_focus_timer -= delta
	var target := _target_pose()
	if _blend_t >= 0.0:
		_blend_t += delta
		var t := clampf(_blend_t / _blend_dur, 0.0, 1.0)
		cam.global_transform = _blend_from.interpolate_with(target, smoothstep(0.0, 1.0, t))
		if _blend_t >= _blend_dur:
			_blend_t = -1.0
	else:
		var w := 1.0 - exp((-9.0 if mode == Mode.SHOT else -6.0) * delta)
		cam.global_transform = cam.global_transform.interpolate_with(target, w)
	if _shake > 0.002:
		cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-5.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
