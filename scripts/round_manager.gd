class_name RoundManager
extends Node
## Runs one round: stroke rotation in standings order until every ball is
## sunk or DNF (stroke cap).
##
## NORMAL mode: waits for all balls to rest between strokes (turn-based).
## CHAOS mode: no rest-waiting. The next player may putt the moment the
## previous stroke is CHAOS_TURN_GAP old, so balls stay live and collide. Each
## turn has a CHAOS_SHOT_CLOCK to act, and the whole round hard-ends at
## CHAOS_ROUND_TIME (any unsunk ball = DNF).

signal turn_started(player_idx: int)
signal round_finished(finish_order: Array, strokes: Dictionary)
signal ball_resolved(player_idx: int, status: String)

const STROKE_CAP := 6
const REST_TIMEOUT := 10.0
const CHAOS_TURN_GAP := 1.5
const CHAOS_SHOT_CLOCK := 10.0
const CHAOS_ROUND_TIME := 75.0

var balls: Array = []
var turn_order: Array = []
var strokes := {}
var resolved := {}
var finish_order: Array = []
var chaos_mode := false
var _turn_pointer := -1
var _awaiting_rest := false
var _rest_timer := 0.0
var _turn_timer := 0.0
var _round_timer := 0.0
var _round_over := false

func start_round(order: Array, round_balls: Array, chaos := false) -> void:
	turn_order = order
	balls = round_balls
	chaos_mode = chaos
	strokes.clear()
	resolved.clear()
	finish_order.clear()
	_round_over = false
	_awaiting_rest = false
	_rest_timer = 0.0
	_turn_timer = 0.0
	_round_timer = 0.0
	_turn_pointer = -1
	for p in turn_order:
		strokes[p] = 0
	_advance_turn()

func current_player() -> int:
	if _turn_pointer < 0:
		return -1
	return turn_order[_turn_pointer]

func notify_stroke() -> void:
	var p := current_player()
	if p >= 0:
		strokes[p] += 1
	_awaiting_rest = true
	_rest_timer = 0.0

func is_turn_ready() -> bool:
	if _round_over or _awaiting_rest:
		return false
	var p := current_player()
	if p < 0 or resolved.has(p):
		return false
	# CHAOS: the whole point is "no waiting" — the current seat may fire even
	# while its own ball (and everyone else's) is still rolling, so >=2 balls are
	# commonly live at once. NORMAL: wait for this ball to settle first.
	if chaos_mode:
		return true
	return balls[p].is_stopped()

func _physics_process(delta: float) -> void:
	if _round_over:
		return
	if chaos_mode:
		_round_timer += delta
		if _round_timer >= CHAOS_ROUND_TIME:
			_chaos_timeout()
			return
	if _awaiting_rest:
		_rest_timer += delta
		var ready := false
		if chaos_mode:
			# Don't wait for balls to settle; just enforce the inter-stroke gap.
			ready = _rest_timer >= CHAOS_TURN_GAP
		else:
			ready = _all_at_rest() or _rest_timer > REST_TIMEOUT
			if _rest_timer > REST_TIMEOUT and not _all_at_rest():
				print("REST_TIMEOUT hit; ball states: ", _debug_ball_states())
		if ready:
			_awaiting_rest = false
			_post_stroke_resolution()
	elif chaos_mode:
		# Shot clock: if the current player can't/won't putt in time, skip them.
		_turn_timer += delta
		if _turn_timer >= CHAOS_SHOT_CLOCK:
			_chaos_skip()

func _debug_ball_states() -> String:
	var parts := []
	for p in turn_order:
		var b = balls[p]
		parts.append("P%d sunk=%s stopped=%s v=%.3f" % [p, b.is_sunk, b.is_stopped(), b.linear_velocity.length()])
	return ", ".join(parts)

func _all_at_rest() -> bool:
	for p in turn_order:
		var b = balls[p]
		if not b.is_sunk and not b.is_stopped():
			return false
	return true

func on_ball_sunk(p: int) -> void:
	if _round_over or resolved.has(p) or not strokes.has(p):
		return
	resolved[p] = "sunk"
	finish_order.append(p)
	ball_resolved.emit(p, "sunk")

func on_ball_died(p: int) -> void:
	if _round_over or resolved.has(p) or not strokes.has(p):
		return
	resolved[p] = "dead"
	ball_resolved.emit(p, "dead")

func _post_stroke_resolution() -> void:
	var p := current_player()
	if p >= 0 and not resolved.has(p) and strokes[p] >= STROKE_CAP:
		resolved[p] = "dnf"
		balls[p].petrify()
		ball_resolved.emit(p, "dnf")
	_advance_turn()

func _chaos_skip() -> void:
	# Player let the shot clock expire; move on without a stroke.
	_turn_timer = 0.0
	_advance_turn()

func _chaos_timeout() -> void:
	for p in turn_order:
		if not resolved.has(p):
			resolved[p] = "dnf"
			balls[p].petrify()
			ball_resolved.emit(p, "dnf")
	_finish()

func _advance_turn() -> void:
	if resolved.size() >= turn_order.size():
		_finish()
		return
	for i in turn_order.size():
		_turn_pointer = (_turn_pointer + 1) % turn_order.size()
		var candidate: int = turn_order[_turn_pointer]
		if not resolved.has(candidate):
			_turn_timer = 0.0
			turn_started.emit(candidate)
			return
	_finish()

func _finish() -> void:
	if _round_over:
		return
	_round_over = true
	round_finished.emit(finish_order.duplicate(), strokes.duplicate())
