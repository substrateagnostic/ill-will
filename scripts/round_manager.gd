class_name RoundManager
extends Node
## Runs one round: stroke rotation in standings order until every ball is
## sunk or DNF (stroke cap). Waits for all balls to rest between strokes.

signal turn_started(player_idx: int)
signal round_finished(finish_order: Array, strokes: Dictionary)
signal ball_resolved(player_idx: int, status: String)

const STROKE_CAP := 6
const REST_TIMEOUT := 10.0

var balls: Array = []
var turn_order: Array = []
var strokes := {}
var resolved := {}
var finish_order: Array = []
var _turn_pointer := -1
var _awaiting_rest := false
var _rest_timer := 0.0
var _round_over := false

func start_round(order: Array, round_balls: Array) -> void:
	turn_order = order
	balls = round_balls
	strokes.clear()
	resolved.clear()
	finish_order.clear()
	_round_over = false
	_awaiting_rest = false
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
	return p >= 0 and not resolved.has(p) and balls[p].is_stopped()

func _physics_process(delta: float) -> void:
	if not _awaiting_rest or _round_over:
		return
	_rest_timer += delta
	if _all_at_rest() or _rest_timer > REST_TIMEOUT:
		if _rest_timer > REST_TIMEOUT:
			print("REST_TIMEOUT hit; ball states: ", _debug_ball_states())
		_awaiting_rest = false
		_post_stroke_resolution()

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

func _advance_turn() -> void:
	if resolved.size() >= turn_order.size():
		_finish()
		return
	for i in turn_order.size():
		_turn_pointer = (_turn_pointer + 1) % turn_order.size()
		var candidate: int = turn_order[_turn_pointer]
		if not resolved.has(candidate):
			turn_started.emit(candidate)
			return
	_finish()

func _finish() -> void:
	if _round_over:
		return
	_round_over = true
	round_finished.emit(finish_order.duplicate(), strokes.duplicate())
