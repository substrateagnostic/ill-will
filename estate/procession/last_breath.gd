class_name ProcessionLastBreath
extends Node
## THE LAST BREATH — the board's movement roll (doc 28 §5, RD candidate B).
##
## A fast oscillating slider (Madden-kick-meter family). A triangle wave sweeps a
## needle 0->1->0; the seat presses A to RELEASE, and the release position `p`
## bends a REAL, auditable d6 distribution (geometric-decay kernel, k=1.6):
## full-left leans [40/25/15/10/6/4]%, center peaks faces 3/4, full-right mirrors.
## A narrow CRIT band — re-dealt every roll (W8 doctrine on a new surface) —
## sharpens the kernel to k=3.2 when the release lands inside it, roughly doubling
## top-face certainty WITHOUT moving the aim. The crit is checked at the release
## frame ONLY (RD §1 rule 1 — never randomize after the input commits) and is
## telegraphed by a glow band once the needle has swept past it once (rule 2).
##
## SEQUENTIAL: one active seat at a time, a queue in the given (standings) order,
## each roll gets its own seeded period jitter. `begin_night_roll(seats, targets,
## rng)` runs the queue and emits `all_released(faces)`.
##
## DETERMINISM (mirrors pawn_putt.gd's contract): the host owns every release. The
## FACE-DETERMINING rng stream (`_rng`, the one the caller passes) is a clean,
## dedicated stream — its ENTIRE consumption is: crit_center + one period deal per
## queued seat, both in begin_night_roll, then EXACTLY ONE `rng.randf()` per
## release (the face sample), in queue order. That's it — so integration can hand
## each roll its own seeded stream and know precisely what it consumes, whether
## the roller is human or bot. Bot AI decisions (crit-appetite bool, release
## jitter) draw from a SEPARATE, seed-derived `_bot_rng`, so they never perturb
## the face stream. Both streams are seeded from the caller's seed, so `--seed=`
## receipts stay byte-identical, and the `_fast` bots-only bypass resolves the
## whole queue in a single frame with identical draw order.
##
## CONFIGURABLE DIE: N_FACES is the DEFAULT (d6, what the economy is tuned to);
## begin_night_roll takes a per-roll `n_faces` so shop items (d8/d10 WRITs) can
## widen the die without a rewrite. The kernel is written in n_faces terms already.
##
## SELF-CONTAINED: this component owns its own CanvasLayer so the meter widget can
## never be occluded (RD §5 hard rule). It touches no live game wiring; it is
## exercised only through last_breath_harness.gd until board integration.

# ---- signals ---------------------------------------------------------------
signal seat_released(seat: int, face: int, p: float, crit: bool)
signal all_released(faces: Array)

# ---- frozen constants (RD §2.0–2.2, doc 28 §5) -----------------------------
const N_FACES := 6
const SWEEP_PERIOD_MS := 700.0     # full 0->1->0 sweep at baseline
const SWEEP_JITTER_MS := 60.0      # re-dealt per roll: kills metronome-counting
const BIAS_DECAY := 1.6            # geometric-decay kernel k, normal
const CRIT_DECAY := 3.2            # kernel k inside the crit band
const CRIT_HALF_WIDTH := 0.032     # ~45ms of sweep at baseline period
const AUTO_RELEASE_MS := 3200.0    # live-mode safety valve (never hit by bots)

# Meter footprint — a wide center-stage bar, house parchment/gold frame.
const METER_W := 660.0
const METER_H := 158.0

# ============================================================================
# WEIGHTING PRIMITIVE (RD §2.0, copied verbatim — the auditable heart of the
# roll; --autoplay receipts make this a checkable function of p, never theater).
# ============================================================================

## Continuous "aim point" in face-space: p=0 -> face 1, p=1 -> face N.
static func aim_center(n_faces: int, p: float) -> float:
	return 1.0 + clampf(p, 0.0, 1.0) * float(n_faces - 1)

## Geometric-decay weights: face i's raw weight is k^-|i - center|, normalized.
## Larger k = sharper (more certain); k=1.0 would be a flat/uniform roll.
static func weight_kernel(n_faces: int, p: float, k: float) -> Array[float]:
	var c := aim_center(n_faces, p)
	var raw: Array[float] = []
	var total := 0.0
	for i in range(1, n_faces + 1):
		var w: float = pow(k, -absf(float(i) - c))
		raw.append(w)
		total += w
	for i in raw.size():
		raw[i] /= total
	return raw

## One rng draw, seat-order, host-only. Never resampled by mirrors.
static func sample_face(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if roll < acc or i == weights.size() - 1:
			return i + 1
	return weights.size()

## Inverse of aim_center: the release ratio a bot aims for to want `face`.
static func p_for_target_face(face: int, n_faces: int) -> float:
	if n_faces <= 1:
		return 0.5
	return clampf(float(face - 1) / float(n_faces - 1), 0.0, 1.0)

# ---- PUBLIC WEIGHTS API (side-effect-free, NO rng) -------------------------
# For the integration's aim-time probability HEATMAP over the upcoming stones:
# these answer "what is the distribution right now" every frame without ever
# consuming the roll rng or mutating any state. `n_faces` defaults to d6.

## Normal (k=1.6) distribution the given release ratio would produce.
func weights_for_p(p: float, n_faces := N_FACES) -> Array[float]:
	return weight_kernel(n_faces, p, BIAS_DECAY)

## Crit (k=3.2) distribution — what the same aim yields if the release lands in
## the crit band. Sharper around the same center, never a different center.
func weights_for_p_crit(p: float, n_faces := N_FACES) -> Array[float]:
	return weight_kernel(n_faces, p, CRIT_DECAY)

## The LIVE distribution for the active roller's current needle position, picking
## the crit kernel iff the needle currently sits inside this roll's crit band.
## Purely a read of current state — safe to call every frame for the heatmap.
func current_weights() -> Array[float]:
	var p := meter.p if meter != null else 0.5
	var in_crit := absf(p - crit_center) <= CRIT_HALF_WIDTH
	return weight_kernel(_n_faces, p, CRIT_DECAY if in_crit else BIAS_DECAY)

## True iff the LIVE needle currently sits inside this roll's crit band — the
## aim heatmap reads this to sharpen its brightness contrast when a crit release
## is in prospect. A pure read of current state (no rng, no mutation).
func in_crit_band() -> bool:
	var p := meter.p if meter != null else 0.5
	return absf(p - crit_center) <= CRIT_HALF_WIDTH

# ============================================================================
# THE METER WIDGET (house look — parchment/gold family, matches pawn_putt.gd).
# ============================================================================

class LastBreathMeter:
	extends Control
	var seat := 0
	var pname := "PLAYER"
	var pcolor := Color.WHITE
	var n_faces := 6             # this roll's die size (drives the face labels)
	var p := 0.0                 # live needle position 0..1
	var crit_center := 0.5
	var crit_seen := false       # glow band telegraphs only after one sweep-past
	var released := false
	var result_face := 0
	var result_crit := false
	var flash := 0.0             # 0..1 release-flash envelope (decays in _process)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(METER_W, METER_H)
		set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		offset_left = -METER_W * 0.5
		offset_right = METER_W * 0.5
		offset_top = -METER_H - 40.0
		offset_bottom = -40.0
		queue_redraw()

	func retarget(s: int, name: String, col: Color, cc: float, nf := 6) -> void:
		seat = s
		pname = name
		pcolor = col
		n_faces = maxi(2, nf)
		crit_center = cc
		crit_seen = false
		released = false
		result_face = 0
		result_crit = false
		p = 0.0
		flash = 0.0
		queue_redraw()

	func set_needle(v: float) -> void:
		var prev := p
		p = clampf(v, 0.0, 1.0)
		# "swept past it once" — the moment the needle crosses crit_center in
		# either direction, the tell becomes visible (telegraphed, RD rule 2).
		if not crit_seen and minf(prev, p) <= crit_center and maxf(prev, p) >= crit_center:
			crit_seen = true
		queue_redraw()

	func seal(face: int, crit: bool) -> void:
		released = true
		result_face = face
		result_crit = crit
		flash = 1.0
		queue_redraw()

	func decay_flash(delta: float) -> void:
		if flash > 0.0:
			flash = maxf(0.0, flash - delta * 2.2)
			queue_redraw()

	func _bar_rect() -> Rect2:
		return Rect2(24, 66, size.x - 48, 40)

	func _draw() -> void:
		draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		# Owner strip — identity is shape+color, never color alone.
		draw_rect(Rect2(6, 6, size.x - 12, 30), Color(pcolor.r, pcolor.g, pcolor.b, 0.20), true)
		var title := "%s  ·  %s  —  THE LAST BREATH" % [PlayerBadge.glyph(seat), pname]
		draw_string(font, Vector2(18, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			pcolor.lerp(Color.WHITE, 0.15))

		var bar := _bar_rect()
		draw_rect(bar, Color(0.09, 0.08, 0.11), true)

		# CRIT tell — a subtle glow band, drawn only once telegraphed (crit_seen).
		if crit_seen:
			var cx := bar.position.x + crit_center * bar.size.x
			var hw := CRIT_HALF_WIDTH * bar.size.x
			var pulse := 0.30 + 0.14 * sin(float(Time.get_ticks_msec()) * 0.006)
			var band := Rect2(cx - hw, bar.position.y - 3, hw * 2.0, bar.size.y + 6)
			draw_rect(band, Color(0.98, 0.86, 0.45, pulse), true)
			draw_rect(band, Color(1.0, 0.93, 0.60, 0.85), false, 2.0)

		# Face labels 1..N along the bar at their aim-centers (p = (n-1)/(N-1)).
		var mid := (n_faces + 1) * 0.5
		for n in range(1, n_faces + 1):
			var fp := ProcessionLastBreath.p_for_target_face(n, n_faces)
			var x := bar.position.x + fp * bar.size.x
			draw_line(Vector2(x, bar.end.y), Vector2(x, bar.end.y + 7), Color(0.72, 0.63, 0.38), 2.0)
			var c := Color("65d58b") if float(n) <= mid else Color("f4c95d")
			draw_string(font, Vector2(x - 5, bar.end.y + 26), str(n),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, c)

		# Needle.
		var nx := bar.position.x + p * bar.size.x
		var needle_col := Color.WHITE
		if released and result_crit:
			needle_col = Color(1.0, 0.95, 0.55)
		draw_line(Vector2(nx, bar.position.y - 6), Vector2(nx, bar.end.y + 6), needle_col, 4.0)

		# Release flash — a bright wash over the bar, distinct gold if it critted.
		if flash > 0.0:
			var fcol := Color(1.0, 0.94, 0.55, 0.55 * flash) if result_crit \
				else Color(1.0, 1.0, 1.0, 0.42 * flash)
			draw_rect(bar.grow(4.0), fcol, true)

		draw_rect(bar, Color(0.82, 0.72, 0.42), false, 2.0)   # gold frame

		var foot := "HOLD A · RELEASE"
		if released:
			foot = "SEALED — ROLLED %d%s" % [result_face, "  · CRIT!" if result_crit else ""]
		draw_string(font, Vector2(18, size.y - 12), foot, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 32, 18, Color(0.90, 0.84, 0.66))

	func _panel() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.10, 0.086, 0.067, 0.94)
		box.border_color = Color(0.78, 0.66, 0.36)
		box.set_border_width_all(3)
		box.set_corner_radius_all(14)
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 8
		return box

# ============================================================================
# QUEUE STATE (RD §4 — the host-owned sequential roll machine)
# ============================================================================

var roster: Array = []                    # per-seat {name, color, bot, crit_appetite?}
var _fast := false                        # bots-only single-frame bypass (soak/receipt)
var mirror := false

# _rng is the FACE stream (caller-owned): crit_center + period deals + one
# randf() per release, nothing else. _bot_rng is the bot-brain stream (appetite +
# release jitter), seed-derived so it never perturbs the face stream.
var _rng: RandomNumberGenerator = null
var _bot_rng := RandomNumberGenerator.new()
const _BOT_RNG_SALT := 0x9E3779B9         # golden-ratio salt: bot seed = face_seed ^ salt
var roll_queue: Array[int] = []
var _targets: Array = []                  # seat -> wanted face (bot aim source, RD §4)
var _periods := {}                        # seat -> this roll's jittered period (dealt in begin_roll)
var _n_faces := N_FACES                   # per-roll die size (default d6)
var active_seat := -1
var active_period_ms := SWEEP_PERIOD_MS
var elapsed_ms := 0.0
var crit_center := 0.5
var _results := {}                        # seat -> face (assembled in queue order)
var _rolling := false

# Per-active-roller bot scratch.
var _bot_target_p := 0.5
var _bot_wants_crit := false
var _bot_released := false
var _bot_live_p := -1.0        # live-mode memoized release target (reset per seat)
var _bot_prev_p := -1.0        # live-mode previous needle sample (peak detection)

# Persona crit-appetite per seat (0..1) — aggressive seats hold out for the crit
# band even at a slightly worse aim; cautious seats take the safe crossing.
# One seeded bool is drawn per bot per roll against this float (RD §4).
var crit_appetite: Array[float] = [0.75, 0.25, 0.55, 0.90]

var _layer: CanvasLayer = null
var meter: LastBreathMeter = null

func configure(players: Array, net_mirror := false) -> void:
	roster = players
	mirror = net_mirror
	# Own CanvasLayer so the instrument is composited on top and can NEVER be
	# occluded by world VFX or heckling avatars (RD §5 hard rule).
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 100
		_layer.name = "LastBreathLayer"
		add_child(_layer)
		meter = LastBreathMeter.new()
		meter.name = "LastBreathMeter"
		_layer.add_child(meter)
	meter.visible = false

## Public entry: run one night's roll for `seats` (queue order = standings order,
## leader first), each wanting `targets[i]`. `n_faces` widens the die for a roll
## (default d6). Emits all_released(faces) when done.
func begin_night_roll(seats: Array, targets: Array, rng: RandomNumberGenerator, n_faces := N_FACES) -> void:
	_rng = rng
	_n_faces = maxi(2, n_faces)
	# Bot-brain stream: seed-derived from the face stream's seed so bot decisions
	# are deterministic for receipts yet never consume the dedicated face stream.
	_bot_rng.seed = _rng.seed ^ _BOT_RNG_SALT
	roll_queue.assign(seats)
	_targets = targets
	_results.clear()
	# ---- the FACE stream's ENTIRE begin_roll consumption: crit_center + one
	# period deal per queued seat (both here, up front). Nothing else touches _rng
	# until the single sample_face() draw at each release. ----
	crit_center = _rng.randf_range(0.12, 0.88)   # W8 doctrine: re-dealt geometry, per roll
	_periods.clear()
	for seat in roll_queue:
		_periods[seat] = SWEEP_PERIOD_MS + _rng.randf_range(-SWEEP_JITTER_MS, SWEEP_JITTER_MS)
	_rolling = true
	if _fast:
		# Bots-only: resolve the entire queue in this single frame, same draw order.
		while not roll_queue.is_empty():
			var seat: int = roll_queue.pop_front()
			_setup_active(seat)
			_release(seat, _bot_release_p(seat))
		_finish()
	else:
		_advance_queue()

## Per-seat setup. The period was already dealt from the face stream in
## begin_roll; the bot's crit-appetite bool draws from the bot-brain stream.
func _setup_active(seat: int) -> void:
	active_seat = seat
	elapsed_ms = 0.0
	_bot_released = false
	active_period_ms = float(_periods.get(seat, SWEEP_PERIOD_MS))
	_bot_live_p = -1.0
	_bot_prev_p = -1.0
	var is_bot := _seat_is_bot(seat)
	if is_bot:
		var tf: int = clampi(int(_target_for(seat)), 1, _n_faces)
		_bot_target_p = p_for_target_face(tf, _n_faces)
		_bot_wants_crit = _bot_rng.randf() < _appetite_for(seat)
	else:
		_bot_wants_crit = false
	if meter != null:
		meter.retarget(seat, _name_for(seat), _color_for(seat), crit_center, _n_faces)
		meter.visible = true

## The ratio a bot aims to release at. Draws the ±0.03 seeded release jitter so
## four bots never look robotically identical. An aggressive bot that drew
## wants_crit trades its exact aim to land inside the crit band (RD §4).
func _bot_release_p(_seat: int) -> float:
	var jitter := _bot_rng.randf_range(-0.03, 0.03)
	var base := crit_center if _bot_wants_crit else _bot_target_p
	return clampf(base + jitter, 0.0, 1.0)

## The one place a face is born: EXACTLY one _rng.randf() draw (inside
## sample_face), at release, in queue order — the whole per-release consumption of
## the dedicated face stream. Crit is decided HERE and only here (RD §1 rule 1).
func _release(seat: int, p: float) -> void:
	var in_crit := absf(p - crit_center) <= CRIT_HALF_WIDTH
	var k := CRIT_DECAY if in_crit else BIAS_DECAY
	var weights := weight_kernel(_n_faces, p, k)
	var face := sample_face(weights, _rng)
	_results[seat] = face
	if meter != null:
		meter.set_needle(p)
		meter.seal(face, in_crit)
	if in_crit and not _fast:
		# The tell fires on the SAME frame as release, never after. Reuses a house
		# sample (no new audio asset) — a small gothic bell reads as "you nailed it".
		Sfx.play("bell_small", -4.0)
	_bot_released = true
	seat_released.emit(seat, face, p, in_crit)

func _advance_queue() -> void:
	if roll_queue.is_empty():
		_finish()
		return
	_setup_active(roll_queue.pop_front())

func _finish() -> void:
	_rolling = false
	active_seat = -1
	var faces: Array = []
	for i in roster.size():
		faces.append(int(_results.get(i, 0)))
	all_released.emit(faces)

# ---- live (windowed) driver ------------------------------------------------
# Frame-rate INDEPENDENT: the sweep is driven by real delta in milliseconds, so a
# 60Hz capture and a 144Hz session sweep at the same wall-clock rate (the
# frame-vs-seconds trap the meter must avoid).
func _process(delta: float) -> void:
	if meter != null:
		meter.decay_flash(delta)
	if _fast or mirror or not _rolling or active_seat < 0:
		return
	elapsed_ms += delta * 1000.0
	var p := _sweep_ratio(elapsed_ms, active_period_ms)
	if meter != null:
		meter.set_needle(p)
	if _seat_is_bot(active_seat):
		_tick_bot(p)
	else:
		_tick_human(p)
	# Live safety valve: never let a stuck seat hang the queue.
	if not _bot_released and elapsed_ms >= AUTO_RELEASE_MS:
		_release(active_seat, p)
	if _bot_released:
		_advance_queue()

func _tick_human(p: float) -> void:
	if PlayerInput.just_pressed(active_seat, "a"):
		_release(active_seat, p)

## A bot watches the same triangle wave and releases on the FIRST crossing of its
## chosen release point (mirrors pawn_putt's `ratio >= target` idiom). If its want
## sits above the peak the sweep actually samples (a face-6 aim vs. frame timing),
## it releases at the turnaround so a high target can never hang the queue.
func _tick_bot(p: float) -> void:
	var want := _bot_release_target_live()
	var prev := _bot_prev_p
	_bot_prev_p = p
	var descending := prev >= 0.0 and p < prev
	# Fire after a few ms of travel (so a want near 0 doesn't release on frame 0),
	# either on crossing `want` or at the peak (prev) when `want` was just out of reach.
	if elapsed_ms > 24.0 and (p >= want or (descending and prev >= want - 0.05)):
		_release(active_seat, p)

## Live bots draw their jitter budget once (memoized per seat, reset in
## _setup_active) so the release target is stable across the sweep frames.
func _bot_release_target_live() -> float:
	if _bot_live_p < 0.0:
		_bot_live_p = _bot_release_p(active_seat)
	return _bot_live_p

# ---- roster helpers --------------------------------------------------------
func _seat_dict(seat: int) -> Dictionary:
	return roster[seat] as Dictionary if seat >= 0 and seat < roster.size() else {}

func _seat_is_bot(seat: int) -> bool:
	return bool(_seat_dict(seat).get("bot", false))

func _name_for(seat: int) -> String:
	return String(_seat_dict(seat).get("name", "PLAYER %d" % (seat + 1)))

func _color_for(seat: int) -> Color:
	return _seat_dict(seat).get("color", Color.WHITE) as Color

## Bot's wanted face: the per-roll `targets[seat]` (RD §4) takes precedence; a
## roster "target" field is the fallback (used by the standalone dev harness).
func _target_for(seat: int) -> int:
	if seat >= 0 and seat < _targets.size():
		return int(_targets[seat])
	return int(_seat_dict(seat).get("target", 3))

func _appetite_for(seat: int) -> float:
	var d := _seat_dict(seat)
	if d.has("crit_appetite"):
		return clampf(float(d["crit_appetite"]), 0.0, 1.0)
	return crit_appetite[seat] if seat < crit_appetite.size() else 0.5

func _sweep_ratio(t_ms: float, period_ms: float) -> float:
	var phase := fmod(t_ms / period_ms, 1.0) * 2.0
	return phase if phase <= 1.0 else 2.0 - phase   # triangle wave, 0..1..0

# ---- net sync (mirrors pawn_putt.gd's host-owns / mirror-renders contract) --
func _net_state() -> Dictionary:
	return {"rolling": _rolling, "active": active_seat, "p": meter.p if meter else 0.0,
		"period": active_period_ms, "crit_center": crit_center, "n_faces": _n_faces,
		"results": _results.duplicate()}
