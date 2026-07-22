class_name SwapBot
extends RefCounted
## Seeded pure-pursuit driver. Empty seats use the same move/A/B surface as a
## human. The world supplies a deliberately mild 0.98..1.08 speed catch-up;
## every decision here remains on this bot's deterministic RNG stream.

const ITEM_SWAP_SHELL: int = 0
const ITEM_COFFIN: int = 1
const ITEM_BELL: int = 2
const ITEM_CROWS: int = 3

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

func setup(w, seat: int, seed_value: int) -> void:
	world = w
	index = seat
	rng.seed = seed_value
	_skill = rng.randf_range(0.93, 1.04)

func think(dt: float) -> void:
	a = false
	var kart: SwapKart = world.karts[index]
	var track: SwapTrack = world.track
	if kart.finished or kart.locked:
		move = Vector2.ZERO
		b = false
		return
	if kart.laps_hw != _lap_seen:
		_lap_seen = kart.laps_hw
		var place: int = world.position_of(index)
		var shortcut_odds: Array[float] = [0.16, 0.38, 0.66, 0.82]
		_take_shortcut = rng.randf() < shortcut_odds[clampi(place - 1, 0, 3)]

	var target: Vector3 = Vector3.ZERO
	var look_distance: float = 6.2 + absf(kart.speed) * 0.62
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
