class_name SwapBot
extends RefCounted
## Seeded pure-pursuit driver. Empty seats use the same move/A/B surface as a
## human. The world supplies a deliberately mild 0.98..1.08 speed catch-up;
## every decision here remains on this bot's deterministic RNG stream.

const ITEM_SWAP_SHELL: int = 0
const ITEM_COFFIN: int = 1
const ITEM_BELL: int = 2
const ITEM_CROWS: int = 3
const STUCK_WINDOW: float = 2.5
const STUCK_NET_ADVANCE: float = 3.5
const STUCK_MAX_PAUSE: float = 4.0
const UNSTUCK_TOTAL: float = 1.75
const UNSTUCK_RECOVER: float = 0.55
const UNSTUCK_LOOK: float = 4.0
const RECOVERY_ESCALATE_WINDOW: float = 15.0
const RECOVERIES_BEFORE_NUDGE: int = 2

var index: int = 0
var world: Variant = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var move: Vector2 = Vector2.ZERO
var a: bool = false
var b: bool = false

var _skill: float = 1.0
var _take_shortcut: bool = false
var _lap_seen: int = -1
var _action_check_t: float = 0.0
var _drift_hold: bool = false
var _window_start_progress: float = 0.0
var _window_elapsed: float = 0.0
var _window_pause: float = 0.0
var _progress_watch_ready: bool = false
var _unstuck_t: float = 0.0
var _recovery_attempts: int = 0
var _recovery_window_start: float = -1.0

func setup(w: Variant, seat: int, seed_value: int) -> void:
	world = w
	index = seat
	rng.seed = seed_value
	_skill = rng.randf_range(0.93, 1.04)

## A SWAP changes the progress frame discontinuously. Forget the old watchdog
## baseline so the new race position is never mistaken for a steering stall.
func position_exchanged() -> void:
	_progress_watch_ready = false
	_window_elapsed = 0.0
	_window_pause = 0.0
	_unstuck_t = 0.0
	_recovery_attempts = 0
	_recovery_window_start = -1.0
	_drift_hold = false

func think(dt: float) -> void:
	a = false
	var kart: SwapKart = world.karts[index]
	var track: SwapTrack = world.track
	if kart.finished or kart.locked:
		move = Vector2.ZERO
		b = false
		_progress_watch_ready = false
		_window_elapsed = 0.0
		_window_pause = 0.0
		_unstuck_t = 0.0
		_recovery_attempts = 0
		_recovery_window_start = -1.0
		return
	_update_stuck_watch(kart, dt)
	if kart.laps_hw != _lap_seen:
		_lap_seen = kart.laps_hw
		var place: int = world.position_of(index)
		var shortcut_odds: Array[float] = [0.16, 0.38, 0.66, 0.82]
		_take_shortcut = rng.randf() < shortcut_odds[clampi(place - 1, 0, 3)]

	var target: Vector3 = Vector3.ZERO
	var look_distance: float = 6.2 + absf(kart.speed) * 0.62
	if _unstuck_t > 0.0:
		look_distance = UNSTUCK_LOOK
	if kart.on_shortcut:
		var shortcut_near: Dictionary = track.nearest_sc(kart.global_position, kart.sc_hint)
		var shortcut_s: float = float(shortcut_near.get("s", 0.0)) + look_distance
		if shortcut_s <= track.sc_len:
			var shortcut_sample: Dictionary = track.sc_sample_at(shortcut_s)
			target = Vector3(shortcut_sample.get("pos", Vector3.ZERO))
		else:
			var exit_sample: Dictionary = track.sample_at(track.sc_exit_s + shortcut_s - track.sc_len)
			target = Vector3(exit_sample.get("pos", Vector3.ZERO))
	else:
		var main_near: Dictionary = track.nearest_main(kart.global_position, kart.hint)
		var current_s: float = float(main_near.get("s", 0.0))
		var entry_distance: float = fposmod(track.sc_entry_s - current_s, track.total_len)
		if _take_shortcut and entry_distance < 14.0:
			if entry_distance > 5.0:
				target = track.sc_entry_pos
			else:
				var shortcut_entry: Dictionary = track.sc_sample_at(3.0)
				target = Vector3(shortcut_entry.get("pos", Vector3.ZERO))
		else:
			var ahead_sample: Dictionary = track.sample_at(current_s + look_distance)
			target = Vector3(ahead_sample.get("pos", Vector3.ZERO))
	var to_target: Vector3 = target - kart.global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.001:
		var angle: float = kart.heading.signed_angle_to(to_target.normalized(), Vector3.UP)
		move = Vector2(clampf(-angle * (2.15 * _skill), -1.0, 1.0), 0.0)

	# First back straight out of the jam, then spend a short phase steering at
	# the freshly sampled next waypoint. Item/drift decisions wait until the
	# recovery is complete so they cannot interrupt it.
	if _unstuck_t > 0.0:
		_drift_hold = false
		b = false
		if _unstuck_t > UNSTUCK_RECOVER:
			move = Vector2(0.0, 1.0)
		return

	if not kart.on_shortcut:
		var curve_near: Dictionary = track.nearest_main(kart.global_position, kart.hint)
		var curve_s: float = float(curve_near.get("s", 0.0))
		var now_sample: Dictionary = track.sample_at(curve_s)
		var far_sample: Dictionary = track.sample_at(curve_s + 10.0)
		var tangent_now: Vector3 = Vector3(now_sample.get("tangent", Vector3.FORWARD))
		var tangent_far: Vector3 = Vector3(far_sample.get("tangent", Vector3.FORWARD))
		var bend: float = tangent_now.angle_to(tangent_far)
		if not _drift_hold and bend > 0.48 and absf(kart.speed) > 6.0 and kart.drift_cd <= 0.0:
			_drift_hold = true
		elif _drift_hold and (bend < 0.16 or absf(kart.speed) < 3.5):
			_drift_hold = false
	else:
		_drift_hold = false
	b = _drift_hold

	_action_check_t -= dt
	if _action_check_t > 0.0:
		return
	_action_check_t = 0.14
	var place: int = world.position_of(index)
	if kart.held_item >= 0:
		match kart.held_item:
			ITEM_SWAP_SHELL:
				a = world.kart_ahead_of(index) >= 0
			ITEM_COFFIN:
				a = rng.randf() < 0.30
			ITEM_BELL:
				a = place > 1 or rng.randf() < 0.18
			ITEM_CROWS:
				a = world.leader_unfinished() != index or rng.randf() < 0.12
		if a:
			return
	if kart.has_golden and place > 1:
		a = true
		return
	if kart.orb_charges <= 0 or kart.orb_cd > 0.0:
		return
	if rng.randf() > (0.15 if not kart.has_golden else 0.28):
		return
	var mischief: bool = rng.randf() < 0.28 or kart.has_golden
	for other_value in world.karts:
		var other: SwapKart = other_value
		if other.index == index or other.finished or other.swap_immune > 0.0:
			continue
		if world.position_of(other.index) > place and not mischief:
			continue
		var relative: Vector3 = other.center() + other.vel_dir * other.speed * 0.55 - kart.center()
		relative.y = 0.0
		var distance: float = relative.length()
		if distance >= 3.0 and distance <= 13.0 \
				and absf(kart.heading.signed_angle_to(relative.normalized(), Vector3.UP)) < 0.4:
			a = true
			break

## Greed's bot cure watches outcome rather than intent. This uses fixed 2.5s
## windows and NET arclength gain: little forward crests inside a wall-pocket
## oscillation cannot reset it. Tumble/airtime may defer at most four seconds.
func _update_stuck_watch(kart: SwapKart, dt: float) -> void:
	if not _progress_watch_ready:
		_reset_watch_window(kart.progress)
		return
	if _unstuck_t > 0.0:
		_unstuck_t = maxf(0.0, _unstuck_t - dt)
		if _unstuck_t <= 0.0:
			_reset_watch_window(kart.progress)
		return
	_window_elapsed += dt
	if kart.tumble_t > 0.0 or kart.airborne:
		_window_pause = minf(STUCK_MAX_PAUSE, _window_pause + dt)
	var measured_time: float = _window_elapsed - _window_pause
	if measured_time < STUCK_WINDOW:
		return
	var net_advance: float = kart.progress - _window_start_progress
	if net_advance >= STUCK_NET_ADVANCE:
		_reset_watch_window(kart.progress)
		return
	_trigger_stall(kart, net_advance)

func _reset_watch_window(progress_value: float) -> void:
	_window_start_progress = progress_value
	_window_elapsed = 0.0
	_window_pause = 0.0
	_progress_watch_ready = true

func _trigger_stall(kart: SwapKart, net_advance: float) -> void:
	var event_t: float = float(world.race_t)
	var pos: Vector3 = kart.global_position
	print("BOT_STALL p=%d t=%.1f cp=%d pos=(%.1f,%.1f) net=%.1f" % [
		index, event_t, kart.gates_credited, pos.x, pos.z, net_advance])
	if _recovery_window_start < 0.0 \
			or event_t - _recovery_window_start > RECOVERY_ESCALATE_WINDOW:
		_recovery_window_start = event_t
		_recovery_attempts = 0
	if _recovery_attempts >= RECOVERIES_BEFORE_NUDGE:
		var nudged: bool = bool(world.bot_checkpoint_nudge(index))
		if nudged:
			_recovery_attempts = 0
			_recovery_window_start = -1.0
			_unstuck_t = 0.0
			_drift_hold = false
			_reset_watch_window(kart.progress)
			print("BOT_UNSTUCK p=%d t=%.1f" % [index, event_t])
			return
	_recovery_attempts += 1
	_unstuck_t = UNSTUCK_TOTAL
	_drift_hold = false
	_reset_watch_window(kart.progress)
	print("BOT_UNSTUCK p=%d t=%.1f" % [index, event_t])
