extends Trap
## NERF (playtest: "Spike trap OP, just be killin everyone" — always-armed,
## zero-tell insta-kill on any touch). Now a retract/extend telegraph, the
## exact house pattern the crusher already ships and already passed playtest:
## position-driven motion, a height-threshold kill gate polled every physics
## frame, no ball physics/materials/stroke touched, footprint/placement
## economics untouched (footprint_radius, click count unchanged).
##
## Cycle numbers are copy-pasted from crusher_trap.gd on purpose — same 2.6s
## period, same 1.5s safe dwell / 0.12s fast transition / 0.53s danger dwell /
## 0.45s slow transition. The crusher's armed/safe ratio (~29% lethal window)
## already shipped and was never flagged as OP, so spikes now carries a bite
## in the same ballpark instead of an invented number (probe-verified actual
## armed fraction: ~34%, tools/spikes_cycle_probe.gd — the mirrored ramp
## asymmetry lands a few points higher, still nowhere near the old 100%).
## Direction is mirrored: spikes are safe DOWN (retracted, hidden below the
## plate) and lethal UP (extended), the reverse of the hammer's
## safe-up/lethal-down.

const UP_Y := 0.2     # extended/lethal — matches the original always-up pose
const DOWN_Y := -0.16 # retracted/safe — sunk flush beneath the plate top
const ARM_Y := -0.02  # ~38.5% risen; same danger-onset fraction as the crusher

var _t := 0.0
var _armed := false

func _init() -> void:
	trap_id = "spikes"
	display_name = "SPIKE STRIP"
	footprint_radius = 0.95

## WAVE 2 grief-trigger: snap to the same cycle position crusher's grief
## snaps to (right at the boundary into the fast strike transition).
func grief_trigger() -> bool:
	_t = 1.5
	return true

func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta * speed_scale, 2.6)
	var y := DOWN_Y
	if _t < 1.5:
		y = DOWN_Y
	elif _t < 1.62:
		y = lerpf(DOWN_Y, UP_Y, (_t - 1.5) / 0.12)
	elif _t < 2.15:
		y = UP_Y
	else:
		y = lerpf(UP_Y, DOWN_Y, (_t - 2.15) / 0.45)
	for spike in [$S1, $S2, $S3, $S4]:
		spike.position.y = y
	var now_armed := y > ARM_Y
	if now_armed and not _armed:
		Sfx.play("creak", -4.0)
	_armed = now_armed
	if not is_ghost and _armed:
		for body in $Zone.get_overlapping_bodies():
			if body is Ball:
				kill_ball(body)
