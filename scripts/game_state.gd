extends Node
## Match-level state: roster, scores, round counter. Autoloaded as GameState.

const PLAYER_COLORS := [
	Color(0.92, 0.34, 0.30),
	Color(0.25, 0.55, 0.90),
	Color(0.95, 0.75, 0.20),
	Color(0.30, 0.85, 0.60),
]
const PLAYER_NAMES := ["RED", "BLUE", "GOLD", "MINT"]
const POINTS_TABLE := {2: [3, 1], 3: [4, 2, 1], 4: [5, 3, 2, 1]}

var player_count := 4
var rounds_total := 9
var round_num := 1
var players: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			player_count = clampi(int(arg.trim_prefix("--players=")), 2, 4)
	reset_match()

func reset_match() -> void:
	round_num = 1
	players.clear()
	for i in player_count:
		players.append({
			"name": PLAYER_NAMES[i],
			"color": PLAYER_COLORS[i],
			"score": 0,
			"grudge": 0,
			"royalties": 0,
		})

func standings() -> Array:
	var idx := range(players.size())
	idx.sort_custom(func(a, b):
		if players[a].score != players[b].score:
			return players[a].score > players[b].score
		return a < b)
	return idx

func award_round_points(finish_order: Array) -> void:
	var pts: Array = POINTS_TABLE[players.size()]
	for i in finish_order.size():
		if i < pts.size():
			players[finish_order[i]].score += pts[i]

func is_match_over() -> bool:
	return round_num > rounds_total
