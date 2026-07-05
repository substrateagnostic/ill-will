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
## Chaos round pays double, winner-take-more.
const CHAOS_POINTS_TABLE := {2: [6, 2], 3: [10, 6, 4], 4: [10, 6, 4, 2]}
const COURSE_IDS := ["fairway", "dogleg", "green", "the_gauntlet"]

var player_count := 4
## rounds_total INCLUDES the final chaos round. Default 4 = 3 normal + chaos.
## --rounds=N still works: N-1 normal + 1 chaos (N=1 -> chaos only).
var rounds_total := 4
var round_num := 1
var players: Array = []
var rng := RandomNumberGenerator.new()
## Chosen once per match (seeded), unless --course= forces it.
var course_id := "fairway"
var _course_override := ""

func _ready() -> void:
	rng.randomize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			player_count = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--seed="):
			rng.seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--rounds="):
			rounds_total = clampi(int(arg.trim_prefix("--rounds=")), 1, 18)
		elif arg.begins_with("--course="):
			var c := arg.trim_prefix("--course=")
			if c in COURSE_IDS:
				_course_override = c
	reset_match()

func reset_match() -> void:
	round_num = 1
	if _course_override != "":
		course_id = _course_override
	else:
		course_id = COURSE_IDS[rng.randi_range(0, COURSE_IDS.size() - 1)]
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
	var table: Dictionary = CHAOS_POINTS_TABLE if is_chaos_round() else POINTS_TABLE
	var pts: Array = table[players.size()]
	for i in finish_order.size():
		if i < pts.size():
			players[finish_order[i]].score += pts[i]

func is_match_over() -> bool:
	return round_num > rounds_total

## The final round of the match is always the chaos round.
func is_chaos_round() -> bool:
	return round_num == rounds_total
