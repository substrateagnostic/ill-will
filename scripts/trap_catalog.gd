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
	"portal_pair": {
		"scene": "res://scenes/traps/portal.tscn",
		"name": "PORTAL PAIR",
		"desc": "In one ring, out the other — speed intact. Place BOTH (two clicks).",
	},
	"ice_patch": {
		"scene": "res://scenes/traps/ice.tscn",
		"name": "ICE PATCH",
		"desc": "Frictionless. Your ball forgets how to stop.",
	},
	"boost_pad": {
		"scene": "res://scenes/traps/boost.tscn",
		"name": "BOOST PAD",
		"desc": "A shove in the arrows' direction. Rarely the one you wanted.",
	},
	"magnet_post": {
		"scene": "res://scenes/traps/magnet.tscn",
		"name": "MAGNET POST",
		"desc": "Drags every ball off its line. Won't kill you — just ruins you.",
	},
	"tunnel": {
		"scene": "res://scenes/traps/tunnel.tscn",
		"name": "TUNNEL",
		"desc": "Roll through the pipe. Roll over it and eat the roof.",
	},
	"moving_wall": {
		"scene": "res://scenes/traps/moving_wall.tscn",
		"name": "MOVING WALL",
		"desc": "A wall that won't hold still. Timing is everything.",
	},
	"trampoline": {
		"scene": "res://scenes/traps/trampoline.tscn",
		"name": "TRAMPOLINE",
		"desc": "Boings your ball up and away. Whee. Splat, maybe.",
	},
	"spinner": {
		"scene": "res://scenes/traps/spinner.tscn",
		"name": "SPINNER",
		"desc": "A lazy-susan of spite. Bats rolling balls off course.",
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
	"express_wall": {
		"scene": "res://scenes/traps/moving_wall.tscn",
		"name": "EXPRESS WALL",
		"desc": "The wall took stimulants. Wider, faster, meaner.",
		"params": {"rate": 3.1, "travel": 1.5},
	},
	"mega_magnet": {
		"scene": "res://scenes/traps/magnet.tscn",
		"name": "MEGA MAGNET",
		"desc": "An event horizon with a business license.",
		"params": {"pull": 13.0, "radius": 3.4},
	},
	"buzzsaw_spinner": {
		"scene": "res://scenes/traps/spinner.tscn",
		"name": "BUZZSAW SPINNER",
		"desc": "Same lazy susan, now caffeinated into a blender.",
		"params": {"spin": 6.5},
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
