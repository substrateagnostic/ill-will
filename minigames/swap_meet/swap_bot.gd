class_name SwapBot
extends RefCounted
## Seeded self-play driver (SWAP MEET, --swapbots). Emits the same
## move/A/B a human would: pure-pursuit on the corridor centerline,
## drift-charge through long corners, opportunistic swap-orb throws at
## anyone lined up ahead, golden orb fired the moment it's unfair.
## All randomness from a per-bot RNG derived from config.rng_seed.

var index := 0
var world = null
var rng := RandomNumberGenerator.new()

var move := Vector2.ZERO
var a := false           # one-tick tap
var b := false

var _skill := 1.0
var _take_shortcut := false
var _lap_seen := -1
var _throw_check_t := 0.0
var _drift_hold := false

func setup(w, i: int, seed_v: int) -> void:
	world = w
	index = i
	rng.seed = seed_v
	_skill = rng.randf_range(0.93, 1.04)

func think(dt: float) -> void:
	a = false
	var kart: SwapKart = world.karts[index]
	var track: SwapTrack = world.track
	if kart.finished or kart.locked:
		move = Vector2.ZERO
		b = false
		return
	# fresh lap: decide on the shortcut - it's the catch-up tool, so the
	# further back you are the more you want it (leaders mostly skip it)
	if kart.laps_hw != _lap_seen:
		_lap_seen = kart.laps_hw
		var pos: int = world.position_of(index)
		_take_shortcut = rng.randf() < [0.2, 0.5, 0.8, 0.9][clampi(pos - 1, 0, 3)]
	# --- steering: pure pursuit -------------------------------------------
	var target := Vector3.ZERO
	var look := 4.5 + absf(kart.speed) * 0.55
	if kart.on_shortcut:
		var q: Dictionary = track.nearest_sc(kart.global_position, kart.sc_hint)
		var ls: float = float(q.s) + look
		if ls <= track.sc_len:
			target = Vector3(track.sc_sample_at(ls).pos)
		else:
			target = Vector3(track.sample_at(track.sc_exit_s + (ls - track.sc_len)).pos)
	else:
		var q2: Dictionary = track.nearest_main(kart.global_position, kart.hint)
		var s_now := float(q2.s)
		var d_entry := fposmod(track.sc_entry_s - s_now, track.total_len)
		if _take_shortcut and d_entry < 11.0:
			target = track.sc_entry_pos if d_entry > 4.0 else Vector3(track.sc_sample_at(3.0).pos)
		else:
			target = Vector3(track.sample_at(s_now + look).pos)
	var to := target - kart.global_position
	to.y = 0.0
	var ang := kart.heading.signed_angle_to(to.normalized(), Vector3.UP)
	move = Vector2(clampf(-ang * (2.3 * _skill), -1.0, 1.0), 0.0)
	# --- drift through sustained corners ------------------------------------
	if not kart.on_shortcut:
		var q3: Dictionary = track.nearest_main(kart.global_position, kart.hint)
		var t_now := Vector3(track.sample_at(float(q3.s)).tangent)
		var t_far := Vector3(track.sample_at(float(q3.s) + 8.0).tangent)
		var bend := t_now.angle_to(t_far)
		if not _drift_hold and bend > 0.55 and absf(kart.speed) > 6.0 and kart.drift_cd <= 0.0:
			_drift_hold = true
		elif _drift_hold and (bend < 0.18 or absf(kart.speed) < 3.5):
			_drift_hold = false
	else:
		_drift_hold = false
	b = _drift_hold
	# --- throwing -------------------------------------------------------------
	_throw_check_t -= dt
	if _throw_check_t <= 0.0:
		_throw_check_t = 0.12
		if kart.has_golden and world.position_of(index) > 1:
			# fire the golden the moment it's unfair
			a = true
			return
		# leading WITH the golden: it downgrades to a normal lob, so spend
		# it like one (below) instead of hoarding a dead item
		if kart.orb_cd <= 0.0 and rng.randf() < (0.12 if not kart.has_golden else 0.25):
			var my_pos: int = world.position_of(index)
			# sometimes swap DOWN, why not; golden-holding leaders always may
			var mischief := rng.randf() < 0.3 or kart.has_golden
			for other in world.karts:
				var ok: SwapKart = other
				if ok.index == index or ok.finished or ok.swap_immune > 0.0:
					continue
				# prefer robbing people doing BETTER than you
				if world.position_of(ok.index) > my_pos and not mischief:
					continue
				var rel: Vector3 = ok.center() + ok.vel_dir * ok.speed * 0.55 - kart.center()
				rel.y = 0.0
				var dist := rel.length()
				if dist < 3.0 or dist > 12.5:
					continue
				if absf(kart.heading.signed_angle_to(rel.normalized(), Vector3.UP)) < 0.4:
					a = true
					break
