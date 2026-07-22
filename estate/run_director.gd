class_name RunDirector
extends Node
## Match authority for THE PROCESSION.
##
## The Estate is the shell and Procession is the board host. This node owns the
## state that survives a board reset and drives the exact three-night sequence:
## intro -> night -> settlement -> interlude -> reset -> finale. Presentation,
## turn resolution, and module contracts remain on their existing hosts.

enum RunPhase {
	IDLE,
	INTRO,
	NIGHT_OPEN,
	NIGHT_GAME,
	NIGHT_SETTLEMENT,
	INTERLUDE,
	BOARD_RESET,
	FINALE,
	COMPLETE,
}

signal match_finished(tally: Dictionary)
signal phase_changed(phase: RunPhase, night_index: int)

const DEFAULT_MATCH_NIGHTS := 3
const BOARD_SCENE_PATH := "res://estate/procession/procession.tscn"
const ARRIVAL_WREATHS: Array = [
	[8, 5, 3, 1],
	[10, 6, 3, 2],
	[12, 7, 4, 2],
]

var phase: RunPhase = RunPhase.IDLE
var match_nights: int = DEFAULT_MATCH_NIGHTS
var turn_cap: int = 12
var night_index: int = 0

# Match state: these arrays survive Procession's per-night board reset. The
# board host receives references to them and mutates the director-owned data.
var pennies: Array[int] = []
var wreaths: Array[int] = []
var inventory: Array = []
var wreath_sources: Array = []
var minigame_firsts: Array[int] = []
var board_firsts: Array[int] = []
var last_night_board_rank: Array[int] = []
var moved_total: Array[int] = []
var first_interlude_game: String = ""

var board_host: Node = null
var hub_host: Node = null
var final_tally: Dictionary = {}
var _running: bool = false

func configure_match(nights: int, phase_turn_cap: int = 12) -> void:
	match_nights = clampi(nights, 1, 5)
	turn_cap = clampi(phase_turn_cap, 4, 40)

func is_running() -> bool:
	return _running

## Estate-facing entry point. The HubHost callbacks keep shell-specific nodes,
## camera restoration, and the existing net pump on Estate; the director owns
## their order and the lifetime of the BoardHost it launches.
func start_match(host: Node, settings: Dictionary) -> void:
	if _running:
		return
	hub_host = host
	hub_host.call("prepare_run_host")
	var config_value: Variant = hub_host.call("build_run_config", settings)
	if not config_value is Dictionary:
		push_error("RunDirector: HubHost returned an invalid run config")
		return
	var board_config: Dictionary = (config_value as Dictionary).duplicate(true)
	board_config["run_director"] = self
	var scene_resource: Resource = load(BOARD_SCENE_PATH)
	if not scene_resource is PackedScene:
		push_error("RunDirector: Procession BoardHost scene is missing")
		return
	var launched_board: Node = (scene_resource as PackedScene).instantiate()
	get_tree().root.add_child(launched_board)
	hub_host.call("attach_run_board", launched_board)
	launched_board.call("begin", board_config)
	hub_host.call("run_board_started", launched_board)

## Build fresh match-level state. Called once by the board host after its real
## roster is known; no per-night reset may call this.
func initialize_match_state(player_count: int, starting_pennies: int) -> void:
	pennies.clear()
	wreaths.clear()
	inventory.clear()
	wreath_sources.clear()
	minigame_firsts.clear()
	board_firsts.clear()
	last_night_board_rank.clear()
	moved_total.clear()
	first_interlude_game = ""
	for _seat in player_count:
		pennies.append(starting_pennies)
		wreaths.append(0)
		inventory.append({})
		wreath_sources.append({"arrival": 0, "mini": 0, "award": 0, "liquid": 0})
		minigame_firsts.append(0)
		board_firsts.append(0)
		last_night_board_rank.append(0)
		moved_total.append(0)

## Attach the board subsystem and start the match state machine. The host API is
## deliberately narrow and signal-driven: a module's final frame remains the
## contract, and the director never computes a minigame or board result itself.
func run(board: Node) -> void:
	if _running:
		return
	board_host = board
	_running = true
	if board_host.has_signal("night_over"):
		board_host.connect("night_over", _on_board_tally, CONNECT_ONE_SHOT)
	_drive_match()

func _drive_match() -> void:
	_set_phase(RunPhase.INTRO)
	await board_host.call("run_match_intro")
	for next_night in range(1, match_nights + 1):
		night_index = next_night
		board_host.call("set_run_context", night_index, match_nights)
		_set_phase(RunPhase.NIGHT_OPEN)
		await board_host.call("run_night_open")
		_set_phase(RunPhase.NIGHT_GAME)
		await board_host.call("run_night_game")
		_set_phase(RunPhase.NIGHT_SETTLEMENT)
		await board_host.call("run_night_settlement")
		if night_index < match_nights:
			_set_phase(RunPhase.INTERLUDE)
			await board_host.call("run_interlude_game")
			_set_phase(RunPhase.BOARD_RESET)
			board_host.call("reset_night_board")
	_set_phase(RunPhase.FINALE)
	await board_host.call("run_match_finale")
	_set_phase(RunPhase.COMPLETE)
	_running = false

func _set_phase(next_phase: RunPhase) -> void:
	phase = next_phase
	phase_changed.emit(phase, night_index)

func arrival_wreaths_for_night(for_night: int) -> Array:
	var table_index: int = clampi(for_night - 1, 0, ARRIVAL_WREATHS.size() - 1)
	return ARRIVAL_WREATHS[table_index]

## FINAL BELL arbitration happens only after the BoardHost completes the current
## roll phase. Everyone home closes immediately; otherwise the armed bell grants
## exactly one additional full round. The turn-cap fallback remains a board rule.
func final_bell_closes_night(seats_arrived: Array, bell_round: int,
		current_round: int) -> bool:
	var all_home: bool = true
	for arrived_value in seats_arrived:
		if not bool(arrived_value):
			all_home = false
			break
	if all_home:
		return true
	return bell_round >= 0 and current_round >= bell_round + 1

## Grand standings: wreaths, board firsts, last-night board rank, then
## minigame firsts. Seat index is display order only, never heir arbitration.
func match_order() -> Array:
	var order: Array = []
	for seat in wreaths.size():
		order.append(seat)
	order.sort_custom(func(a: int, b: int) -> bool:
		if wreaths[a] != wreaths[b]:
			return wreaths[a] > wreaths[b]
		if board_firsts[a] != board_firsts[b]:
			return board_firsts[a] > board_firsts[b]
		if last_night_board_rank[a] != last_night_board_rank[b]:
			return last_night_board_rank[a] < last_night_board_rank[b]
		if minigame_firsts[a] != minigame_firsts[b]:
			return minigame_firsts[a] > minigame_firsts[b]
		return a < b)
	return order

## A tie surviving the complete announced chain produces joint heirs.
func match_heirs() -> Array:
	var order: Array = match_order()
	var top: int = int(order[0])
	var heirs: Array = [top]
	for order_index in range(1, order.size()):
		var seat: int = int(order[order_index])
		if wreaths[seat] == wreaths[top] and board_firsts[seat] == board_firsts[top] \
				and last_night_board_rank[seat] == last_night_board_rank[top] \
				and minigame_firsts[seat] == minigame_firsts[top]:
			heirs.append(seat)
	return heirs

func _on_board_tally(tally: Dictionary) -> void:
	final_tally = tally.duplicate(true)
	if hub_host != null:
		hub_host.call("finish_run_host", board_host, final_tally)
	match_finished.emit(final_tally)
