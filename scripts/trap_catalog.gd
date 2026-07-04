class_name TrapCatalog
## Registry of draftable traps. Content axis of the whole game: add entries
## here as new trap scenes exist.

const TRAPS := {
	"wall": {
		"scene": "res://scenes/traps/wall.tscn",
		"name": "RUDE PLANK",
		"desc": "A wall. In the way. On purpose.",
	},
	"bumper": {
		"scene": "res://scenes/traps/bumper.tscn",
		"name": "BUMPER",
		"desc": "Kicks balls. Hard. No apologies.",
	},
	"windmill": {
		"scene": "res://scenes/traps/windmill.tscn",
		"name": "WINDMILL",
		"desc": "Spinning blades of mild inconvenience.",
	},
	"fan": {
		"scene": "res://scenes/traps/fan.tscn",
		"name": "BIG FAN",
		"desc": "Blows your putt off course. It's a big fan of chaos.",
	},
	"sand": {
		"scene": "res://scenes/traps/sand.tscn",
		"name": "SAND PIT",
		"desc": "Balls check in. Momentum doesn't check out.",
	},
	"ramp": {
		"scene": "res://scenes/traps/ramp.tscn",
		"name": "YEET RAMP",
		"desc": "Launches balls skyward. Landing not included.",
	},
}

static func random_hand(rng: RandomNumberGenerator, n := 3) -> Array:
	var ids := TRAPS.keys()
	var hand: Array = []
	while hand.size() < n and ids.size() > 0:
		var pick: String = ids[rng.randi_range(0, ids.size() - 1)]
		ids.erase(pick)
		hand.append(pick)
	return hand

static func load_scene(id: String) -> PackedScene:
	return load(TRAPS[id]["scene"])
