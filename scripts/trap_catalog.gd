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
	"spikes": {
		"scene": "res://scenes/traps/spikes.tscn",
		"name": "SPIKE STRIP",
		"desc": "Pop. No refunds. KILLS.",
	},
	"water": {
		"scene": "res://scenes/traps/water.tscn",
		"name": "WATER HAZARD",
		"desc": "Balls can't swim. KILLS.",
	},
	"crusher": {
		"scene": "res://scenes/traps/crusher.tscn",
		"name": "THE CRUSHER",
		"desc": "Slams on a timer. Time your putt or die. KILLS.",
	},
}

const CURSED := {
	"black_hole": {
		"scene": "res://scenes/traps/black_hole.tscn",
		"name": "BLACK HOLE",
		"desc": "Pulls everything in. Devours what it catches. KILLS.",
	},
	"mega_bumper": {
		"scene": "res://scenes/traps/bumper.tscn",
		"name": "MEGA BUMPER",
		"desc": "A bumper that holds a personal grudge.",
		"params": {"kick": 9.0},
	},
	"turbo_windmill": {
		"scene": "res://scenes/traps/windmill.tscn",
		"name": "TURBO WINDMILL",
		"desc": "Someone removed the safety governor.",
		"params": {"spin_speed": 3.6},
	},
	"storm_fan": {
		"scene": "res://scenes/traps/fan.tscn",
		"name": "CATEGORY 5 FAN",
		"desc": "Reclassified as a weather event.",
		"params": {"push": 16.0},
	},
}

static func info(id: String) -> Dictionary:
	return TRAPS.get(id, CURSED.get(id, {}))

static func is_cursed(id: String) -> bool:
	return CURSED.has(id)

static func random_hand(rng: RandomNumberGenerator, n := 3) -> Array:
	var ids := TRAPS.keys()
	var hand: Array = []
	while hand.size() < n and ids.size() > 0:
		var pick: String = ids[rng.randi_range(0, ids.size() - 1)]
		ids.erase(pick)
		hand.append(pick)
	return hand

static func random_cursed(rng: RandomNumberGenerator) -> String:
	var ids := CURSED.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]

static func load_scene(id: String) -> PackedScene:
	return load(info(id)["scene"])
