extends Node
## Match-level state: roster, scores, round counter. Autoloaded as GameState.

## Colorblind-safe seat palettes (research digest 04 MUST item). Each alternate
## is designed so all FOUR seats stay mutually distinguishable under that
## dichromacy — validated with Machado-2009 dichromacy simulation + CIEDE2000
## (min ΔE00 well past the just-distinct threshold; full hex tables + reasoning
## in docs/verify/access-VERIFY.md). Anchored on Okabe-Ito CVD-safe hues.
## Seat NAMES (RED/BLUE/GOLD/MINT) and badge SHAPES never change: hue is never
## the only identity channel, the shapes exist precisely so it isn't.
##   index: 0 RED (circle)  1 BLUE (triangle)  2 GOLD (square)  3 MINT (diamond)
const PALETTES := {
	"classic": [
		Color(0.92, 0.34, 0.30), Color(0.25, 0.55, 0.90),
		Color(0.95, 0.75, 0.20), Color(0.30, 0.85, 0.60),
	],
	# Deuteranopia (no M-cones): spread on the retained blue-yellow axis +
	# lightness. Vermillion red / vivid blue / lemon / teal-green.
	"deutan": [
		Color(0.769, 0.243, 0.0), Color(0.082, 0.322, 0.847),
		Color(0.941, 0.894, 0.259), Color(0.267, 0.667, 0.6),
	],
	# Protanopia (no L-cones; reds lose luminance): push RED darker so it becomes
	# a unique DARK anchor (lightness is retained), the rest stay bright.
	"protan": [
		Color(0.69, 0.227, 0.0), Color(0.0, 0.447, 0.698),
		Color(0.941, 0.894, 0.259), Color(0.0, 0.62, 0.451),
	],
	# Tritanopia (no S-cones; blue-yellow confusion): spread on the retained
	# red-green axis + lightness. Clean red / indigo / gold / spring green.
	"tritan": [
		Color(0.8, 0.2, 0.067), Color(0.231, 0.298, 0.753),
		Color(0.925, 0.831, 0.0), Color(0.0, 0.765, 0.537),
	],
}
## Active seat colors, mutated in place by apply_palette(). NOT a const: games
## read this at launch and estate panels rebuild per phase, so a live palette
## swap needs a mutable array (const Arrays are read-only in Godot 4). Defaults
## to the classic palette, byte-identical to the shipped colors.
var PLAYER_COLORS: Array = PALETTES["classic"].duplicate()
const PLAYER_NAMES := ["RED", "BLUE", "GOLD", "MINT"]
const POINTS_TABLE := {2: [3, 1], 3: [4, 2, 1], 4: [5, 3, 2, 1]}
## Chaos round pays double, winner-take-more.
const CHAOS_POINTS_TABLE := {2: [6, 2], 3: [10, 6, 4], 4: [10, 6, 4, 2]}
## WAVE 3: widows_walk is the v4 flagship — multi-lane spine, chasm crossing,
## elevated switchback green. Same random-per-match draw as the original four.
const COURSE_IDS := ["fairway", "dogleg", "green", "the_gauntlet", "widows_walk"]

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

## Swap the active seat palette in place (see PALETTES). Unknown ids fall back
## to classic. Mutates PLAYER_COLORS rather than reassigning it, so any live
## reader (estate panels, rebuilt per phase) picks the change up; a game already
## in progress keeps the palette it launched with — the ACCESS hint notes this
## applies-to-next-game caveat.
func apply_palette(id: String) -> void:
	var pal: Array = PALETTES.get(id, PALETTES["classic"])
	for i in mini(PLAYER_COLORS.size(), pal.size()):
		PLAYER_COLORS[i] = pal[i]

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
