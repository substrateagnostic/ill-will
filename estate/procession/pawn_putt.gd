class_name ProcessionPawnPutt
extends Node
## Simultaneous hold/release movement verb.  The host owns every release and
## turns it into one-dimensional distance along the carriage rail.  Online
## seats submit {seat, power, release_tick}; mirrors only render `_net_state`.
##
## FROZEN PAR PHYSICS (do not tune here):
##   linear_damp 0.5 => ideal distance = launch_speed / 0.5 = 2 × speed
##   below 0.9 m/s the low-speed brake multiplies velocity by 0.9 each tick
## These are copied from scripts/ball.gd and scripts/putt_controller.gd.  The
## board projection is analytic because the rail is one-dimensional; its meter
## bands are computed from that exact distance, never from hand-tuned buckets.

signal seat_released(seat: int, power: float, release_tick: int, spaces: int)
signal all_released(results: Array)

const LINEAR_DAMP := 0.5
const LOW_SPEED_BRAKE_AT := 0.9
const LOW_SPEED_BRAKE_FACTOR := 0.9
const STOP_SPEED := 0.12
const MIN_SPEED := 1.2
const MAX_SPEED := 13.0
const SPACE_DISTANCE := 3.55
const TARGET_SPACES := 6
const ROLL_TICKS := 8 * 60
const CHARGE_PERIOD_TICKS := 96
const SWEET_HALF_SPACE := 0.12
# Corner meter footprint — wide enough that the full "HOLD A · RELEASE ON A BAND"
# hint renders without clipping, tall enough for the parchment/gold frame.
const METER_W := 338.0
const METER_H := 110.0

class PuttMeter:
	extends Control
	var seat := 0
	var pname := "PLAYER"
	var pcolor := Color.WHITE
	var ratio := 0.0
	var released := false
	var result_spaces := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(METER_W, METER_H)
		queue_redraw()

	func set_readout(v: float, is_released: bool, spaces: int) -> void:
		ratio = clampf(v, 0.0, 1.0)
		released = is_released
		result_spaces = spaces
		queue_redraw()

	func _draw() -> void:
		var bg := Rect2(Vector2.ZERO, size)
		draw_style_box(_panel(), bg)
		var font := ThemeDB.fallback_font
		# Player-colour header strip so each meter reads its owner at a glance
		# even inside the shared gold gothic frame (never colour alone: badge
		# glyph + name ride on top).
		draw_rect(Rect2(5, 5, size.x - 10, 26), Color(pcolor.r, pcolor.g, pcolor.b, 0.20), true)
		var title := "%s  ·  %s" % [PlayerBadge.glyph(seat), pname]
		draw_string(font, Vector2(16, 27), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			pcolor.lerp(Color.WHITE, 0.15))
		var bar := Rect2(16, 46, size.x - 32, 29)
		draw_rect(bar, Color(0.09, 0.08, 0.11), true)
		for n in range(1, TARGET_SPACES + 1):
			var center := ProcessionPawnPutt.ratio_for_spaces(float(n))
			var half := ProcessionPawnPutt.ratio_for_distance(SPACE_DISTANCE * SWEET_HALF_SPACE)
			var rr := Rect2(bar.position.x + (center - half) * bar.size.x, bar.position.y,
				maxf(3.0, half * 2.0 * bar.size.x), bar.size.y)
			var c := Color("65d58b") if n <= 3 else Color("f4c95d")
			draw_rect(rr, Color(c.r, c.g, c.b, 0.56), true)
			draw_string(font, Vector2(rr.position.x + 2, bar.position.y + 22), str(n),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.06, 0.05, 0.08))
		var fill := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
		draw_rect(fill, Color(pcolor.r, pcolor.g, pcolor.b, 0.34), true)
		var needle_x := bar.position.x + bar.size.x * ratio
		draw_line(Vector2(needle_x, bar.position.y - 4),
			Vector2(needle_x, bar.end.y + 4), Color.WHITE, 4.0)
		draw_rect(bar, Color(0.82, 0.72, 0.42), false, 2.0)   # gold bar frame
		var foot := "HOLD A · RELEASE ON A BAND"
		if released:
			foot = "SEALED — %d SPACE%s" % [result_spaces, "" if result_spaces == 1 else "S"]
		# Full hint fits: the box is wider and the footer set at 18px inside a
		# 24px clip margin, so it renders whole ("…ON A BAND"), never clipped.
		draw_string(font, Vector2(15, size.y - 11), foot, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 24, 18, Color(0.90, 0.84, 0.66))

	func _panel() -> StyleBoxFlat:
		# Parchment-dark ground + a warm gold frame, matching the reveal
		# lower-third's gothic chrome.
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.10, 0.086, 0.067, 0.93)
		box.border_color = Color(0.78, 0.66, 0.36)
		box.set_border_width_all(3)
		box.set_corner_radius_all(12)
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 6
		return box

var roster: Array = []
var active := false
var mirror := false
var roll_tick := 0
var ratios: Array[float] = []
var powers: Array[float] = []
var release_ticks: Array[int] = []
var spaces: Array[int] = []
var holding: Array[bool] = []
var released: Array[bool] = []
var hold_ticks: Array[int] = []
var bot_enabled: Array[bool] = []
var bot_start_ticks: Array[int] = []
var bot_target_ratios: Array[float] = []
var meters: Array = []
var _net_intents := {}

func configure(players: Array, ui_parent: Control, net_mirror := false) -> void:
	roster = players
	mirror = net_mirror
	_clear_meters()
	for i in roster.size():
		var m := PuttMeter.new()
		m.name = "PuttMeter%d" % i
		m.seat = i
		m.pname = String((roster[i] as Dictionary).get("name", "PLAYER %d" % (i + 1)))
		m.pcolor = (roster[i] as Dictionary).get("color", Color.WHITE) as Color
		ui_parent.add_child(m)
		_place_meter(m, i)
		m.visible = false
		meters.append(m)

func begin_roll(targets: Array[int], rng: RandomNumberGenerator) -> void:
	active = true
	roll_tick = 0
	_net_intents.clear()
	_reset_arrays()
	for i in roster.size():
		bot_enabled[i] = bool((roster[i] as Dictionary).get("bot", false))
		var target := clampi(int(targets[i]) if i < targets.size() else 3, 1, TARGET_SPACES)
		var jitter := rng.randf_range(-0.012, 0.012)
		bot_target_ratios[i] = clampf(ratio_for_spaces(float(target)) + jitter, 0.0, 1.0)
		bot_start_ticks[i] = rng.randi_range(18, 58)
		var m: PuttMeter = meters[i]
		m.visible = true
		m.set_readout(0.0, false, 0)

func end_roll_visuals() -> void:
	active = false
	for m in meters:
		(m as PuttMeter).visible = false

func stage_midcharge(values: Array[float]) -> void:
	active = false
	if ratios.size() != roster.size():
		_reset_arrays()
	for i in meters.size():
		var ratio := float(values[i]) if i < values.size() else 0.5
		ratios[i] = ratio
		var m: PuttMeter = meters[i]
		m.visible = true
		m.set_readout(ratio, false, 0)

func submit_remote_intent(seat: int, power: float, release_tick: int) -> void:
	if not active or seat < 0 or seat >= roster.size() or released[seat]:
		return
	_net_intents[seat] = {
		"power": clampf(power, MIN_SPEED, MAX_SPEED),
		"release_tick": maxi(release_tick, roll_tick),
	}

func _physics_process(_delta: float) -> void:
	if not active or mirror:
		return
	roll_tick += 1
	for i in roster.size():
		if released[i]:
			continue
		if _net_intents.has(i):
			var packet: Dictionary = _net_intents[i]
			_release(i, float(packet.power), int(packet.release_tick))
			continue
		if bot_enabled[i]:
			_tick_bot(i)
		else:
			_tick_human(i)
	if roll_tick >= ROLL_TICKS:
		for i in roster.size():
			if not released[i]:
				var ratio := ratios[i] if ratios[i] > 0.02 else ratio_for_spaces(1.0)
				_release(i, speed_for_ratio(ratio), roll_tick)
	if _released_count() == roster.size():
		active = false
		var result: Array = []
		for i in roster.size():
			result.append({"seat": i, "power": powers[i], "release_tick": release_ticks[i],
				"distance": projected_distance(powers[i]), "spaces": spaces[i]})
		all_released.emit(result)

func _tick_bot(i: int) -> void:
	if roll_tick < bot_start_ticks[i]:
		return
	holding[i] = true
	hold_ticks[i] += 1
	var ratio := _wave_ratio(hold_ticks[i])
	ratios[i] = ratio
	(meters[i] as PuttMeter).set_readout(ratio, false, 0)
	if ratio >= bot_target_ratios[i] and hold_ticks[i] <= CHARGE_PERIOD_TICKS:
		_release(i, speed_for_ratio(ratio), roll_tick)

func _tick_human(i: int) -> void:
	if PlayerInput.just_pressed(i, "a") and not holding[i]:
		holding[i] = true
		hold_ticks[i] = 0
	if not holding[i]:
		return
	hold_ticks[i] += 1
	var ratio := _wave_ratio(hold_ticks[i])
	ratios[i] = ratio
	(meters[i] as PuttMeter).set_readout(ratio, false, 0)
	if not PlayerInput.is_down(i, "a") and hold_ticks[i] > 2:
		_release(i, speed_for_ratio(ratio), roll_tick)

func _release(i: int, power: float, tick: int) -> void:
	if released[i]:
		return
	released[i] = true
	holding[i] = false
	powers[i] = clampf(power, MIN_SPEED, MAX_SPEED)
	release_ticks[i] = tick
	ratios[i] = ratio_for_speed(powers[i])
	spaces[i] = spaces_for_power(powers[i])
	(meters[i] as PuttMeter).set_readout(ratios[i], true, spaces[i])
	Sfx.play("putt", -9.0 + 8.0 * ratios[i], 0.0)
	seat_released.emit(i, powers[i], tick, spaces[i])

func _wave_ratio(ticks: int) -> float:
	var phase := fmod(float(ticks) / float(CHARGE_PERIOD_TICKS), 2.0)
	return phase if phase <= 1.0 else 2.0 - phase

func _released_count() -> int:
	var count := 0
	for value in released:
		if value:
			count += 1
	return count

func _reset_arrays() -> void:
	var n := roster.size()
	ratios.resize(n)
	powers.resize(n)
	release_ticks.resize(n)
	spaces.resize(n)
	holding.resize(n)
	released.resize(n)
	hold_ticks.resize(n)
	bot_enabled.resize(n)
	bot_start_ticks.resize(n)
	bot_target_ratios.resize(n)
	for i in n:
		ratios[i] = 0.0
		powers[i] = MIN_SPEED
		release_ticks[i] = -1
		spaces[i] = 1
		holding[i] = false
		released[i] = false
		hold_ticks[i] = 0
		bot_enabled[i] = false
		bot_start_ticks[i] = 0
		bot_target_ratios[i] = 0.5

func _clear_meters() -> void:
	for m in meters:
		if is_instance_valid(m):
			(m as Node).queue_free()
	meters.clear()

func _place_meter(m: Control, i: int) -> void:
	# Anchor each meter to its own screen corner and pin its box with explicit
	# offsets. (set_anchors_and_offsets_preset + position fought each other and
	# threw seats 1–3 off-screen — only seat 0 rendered.)
	var w := METER_W
	var h := METER_H
	var mx := 26.0
	var my := 118.0
	match i:
		0:  # top-left
			m.anchor_left = 0.0; m.anchor_right = 0.0; m.anchor_top = 0.0; m.anchor_bottom = 0.0
			m.offset_left = mx; m.offset_top = my
		1:  # top-right
			m.anchor_left = 1.0; m.anchor_right = 1.0; m.anchor_top = 0.0; m.anchor_bottom = 0.0
			m.offset_left = -mx - w; m.offset_top = my
		2:  # bottom-left
			m.anchor_left = 0.0; m.anchor_right = 0.0; m.anchor_top = 1.0; m.anchor_bottom = 1.0
			m.offset_left = mx; m.offset_top = -my - h
		_:  # bottom-right
			m.anchor_left = 1.0; m.anchor_right = 1.0; m.anchor_top = 1.0; m.anchor_bottom = 1.0
			m.offset_left = -mx - w; m.offset_top = -my - h
	m.offset_right = m.offset_left + w
	m.offset_bottom = m.offset_top + h

func _net_state() -> Dictionary:
	return {"active": active, "tick": roll_tick, "ratios": ratios.duplicate(),
		"powers": powers.duplicate(), "released": released.duplicate(),
		"release_ticks": release_ticks.duplicate(), "spaces": spaces.duplicate()}

func _net_apply(state: Dictionary) -> void:
	active = bool(state.get("active", false))
	roll_tick = int(state.get("tick", 0))
	ratios.assign(state.get("ratios", []))
	powers.assign(state.get("powers", []))
	released.assign(state.get("released", []))
	release_ticks.assign(state.get("release_ticks", []))
	spaces.assign(state.get("spaces", []))
	for i in mini(meters.size(), ratios.size()):
		var m: PuttMeter = meters[i]
		m.visible = active or (i < released.size() and released[i])
		m.set_readout(ratios[i], i < released.size() and released[i],
			spaces[i] if i < spaces.size() else 0)

static func projected_distance(speed: float) -> float:
	# The 1-D rail projection of Par's frozen exponential roll.
	return clampf(speed, 0.0, MAX_SPEED) / LINEAR_DAMP

static func spaces_for_power(power: float) -> int:
	return maxi(1, int(floor((projected_distance(power) + SPACE_DISTANCE * 0.08) / SPACE_DISTANCE)))

static func speed_for_ratio(ratio: float) -> float:
	return lerpf(MIN_SPEED, MAX_SPEED, clampf(ratio, 0.0, 1.0))

static func ratio_for_speed(speed: float) -> float:
	return clampf((speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)

static func ratio_for_spaces(n: float) -> float:
	return ratio_for_speed(n * SPACE_DISTANCE * LINEAR_DAMP)

static func ratio_for_distance(distance: float) -> float:
	return distance * LINEAR_DAMP / (MAX_SPEED - MIN_SPEED)
