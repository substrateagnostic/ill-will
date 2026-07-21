extends Node3D
## SPIKE STRIP nerf probe (playtest fix — see scripts/traps/spikes_trap.gd).
## Standalone, no course/estate/GameState dependency: instances the real
## spikes.tscn + the real ball.tscn directly, freezes the ball motionless
## inside the trap's Zone from frame 0, and lets physics run untouched.
##
## Proves, purely from observed behavior (no private-var peeking):
##   1. The ball does NOT die on contact (frame 0) — the old always-armed
##      insta-kill is gone.
##   2. The ball survives a full safe (retracted) dwell while sitting inside
##      the zone the whole time.
##   3. The ball DOES die once the cycle arms (spikes extend) — still lethal.
##   4. The armed/safe duty cycle matches the documented ~28% (crusher-parity).
##
## Run: godot --headless --fixed-fps 60 --path . tools/spikes_cycle_probe.tscn
## Expected stdout (frame numbers are deterministic @60Hz fixed-fps):
##   SPIKES_PROBE start
##   SPIKES_ARM frame=90 y_s1=... (first frame spikes cross the danger threshold)
##   BALL_DIED frame=9X killer=spikes
##   SPIKES_DISARM frame=1.. (spikes retract back to safe)
##   ... repeats for a few cycles ...
##   SPIKES_PROBE done frames=468 armed_frames=~131 safe_frames=~337 armed_fraction=~0.28

const SPIKES_SCENE := preload("res://scenes/traps/spikes.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const RUN_FRAMES := 468  # 3 full 2.6s cycles @60Hz fixed-fps

var _trap: Trap
var _spike_mesh: MeshInstance3D
var _ball: Ball
var _frame := 0
var _was_armed := false
var _armed_frames := 0
var _died_at := -1
var _died_armed_check := false

func _ready() -> void:
	print("SPIKES_PROBE start")
	_trap = SPIKES_SCENE.instantiate()
	add_child(_trap)
	_trap.global_position = Vector3.ZERO
	_spike_mesh = _trap.get_node("S1")

	_ball = BALL_SCENE.instantiate()
	add_child(_ball)
	_ball.player_index = 0
	_ball.player_color = Color(0.9, 0.3, 0.3)
	# Sit the ball dead-center in the Zone (trap origin + the Zone's local
	# y-offset baked in spikes.tscn), frozen so it never moves on its own —
	# any death is caused ONLY by the trap's cycle, not by ball physics.
	_ball.global_position = _trap.global_position + Vector3(0, 0.25, 0)
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.died.connect(_on_ball_died)

func _on_ball_died(killer: Trap) -> void:
	if _died_at == -1:
		_died_at = _frame
		# Read the spike height FRESH, at the exact instant the death signal
		# fires (ground truth) — do not trust _was_armed, which is this
		# script's own cached copy from earlier in the tick and can be one
		# frame stale relative to sibling node processing order.
		var y_now: float = _spike_mesh.position.y
		_died_armed_check = y_now > -0.02
		print("BALL_DIED frame=%d killer=%s y_at_death=%.4f armed_at_death=%s" % [_frame, killer.trap_id, y_now, str(_died_armed_check)])

func _physics_process(_delta: float) -> void:
	_frame += 1
	var y: float = _spike_mesh.position.y
	var armed := y > -0.02  # same ARM_Y threshold spikes_trap.gd kills on
	if armed and not _was_armed:
		print("SPIKES_ARM frame=%d y=%.4f" % [_frame, y])
	elif not armed and _was_armed:
		print("SPIKES_DISARM frame=%d y=%.4f" % [_frame, y])
	if armed:
		_armed_frames += 1
	_was_armed = armed
	if _frame >= RUN_FRAMES:
		var safe_frames := RUN_FRAMES - _armed_frames
		print("SPIKES_PROBE done frames=%d armed_frames=%d safe_frames=%d armed_fraction=%.3f died_frame=%d died_while_armed=%s"
			% [RUN_FRAMES, _armed_frames, safe_frames, float(_armed_frames) / float(RUN_FRAMES), _died_at, str(_died_armed_check)])
		get_tree().quit()
