class_name ProcessionBoardSpaces
extends RefCounted
## Public, announced grammar for every stone on the drive.  The table is the
## rulebook: board rendering, bot valuation, reveal copy, and net snapshots all
## read these same facts, so a space can never have a hidden second meaning.

const BLANK := "blank"
const SHRINE := "shrine"
const WEEPING_GRAVE := "weeping_grave"
const STALL := "stall"
const CODICIL := "codicil"
const SEANCE := "seance"
const TOLLGATE := "tollgate"
const VENDETTA := "vendetta"

const TABLE := {
	BLANK: {
		"name": "PATH STONE", "icon": "·", "color": Color("72747d"),
		"rule": "A merciful administrative error.", "bot_value": 0.0,
	},
	SHRINE: {
		"name": "SHRINE", "icon": "+", "color": Color("65d58b"),
		"rule": "+3 GRUDGE", "bot_value": 5.0,
	},
	WEEPING_GRAVE: {
		"name": "WEEPING GRAVE", "icon": "−", "color": Color("b04d68"),
		"rule": "−2 GRUDGE · MONUMENT OWNER RECEIVES THE TOLL", "bot_value": -5.0,
	},
	STALL: {
		"name": "THE STALL", "icon": "!", "color": Color("e4a54c"),
		"rule": "TAKE ONE ANNOUNCED SABOTAGE ITEM", "bot_value": 3.0,
	},
	CODICIL: {
		"name": "THE CODICIL", "icon": "D", "color": Color("f4db62"),
		"rule": "BUY A DEED · COST 10 + 2 PER DEED HELD", "bot_value": 20.0,
	},
	SEANCE: {
		"name": "SÉANCE CIRCLE", "icon": "?", "color": Color("a77de8"),
		"rule": "SPIN THE VISIBLE FOUR-SLOT PLANCHETTE", "bot_value": 2.0,
	},
	TOLLGATE: {
		"name": "TOLLGATE", "icon": "$", "color": Color("64b9d5"),
		"rule": "PASS: PAY OWNER 2 · LAND: TAKE POT AND OWN", "bot_value": 2.0,
	},
	VENDETTA: {
		"name": "VENDETTA", "icon": "V", "color": Color("ef7058"),
		"rule": "NEMESIS WITHIN 5: SEALED 0–3 GRUDGE WAGER", "bot_value": 1.0,
	},
}

const SEANCE_WHEEL := [
	{"title": "MERCIFUL DRAFT", "rule": "EVERY MOURNER RECEIVES 2 GRUDGE"},
	{"title": "EQUAL SHARES", "rule": "DEED LEADER PAYS EACH RIVAL 1 GRUDGE"},
	{"title": "ROAD LEVY", "rule": "EACH TOLLGATE POT RECEIVES 3 GRUDGE"},
	{"title": "FAVORED MEDIUM", "rule": "MEDIUM RECEIVES 4; ALL OTHERS RECEIVE 1"},
]

const ITEMS := [
	{"id": "mourning_pin", "name": "MOURNING PIN", "rule": "+1 SPACE ON YOUR NEXT PUTT"},
	{"id": "black_ribbon", "name": "BLACK RIBBON", "rule": "DEED LEADER −1 SPACE NEXT PUTT"},
	{"id": "grave_salt", "name": "GRAVE SALT", "rule": "CANCEL YOUR NEXT GRAVE LOSS"},
]

static func fact(type: String) -> Dictionary:
	return TABLE.get(type, TABLE[BLANK]) as Dictionary

static func display_name(type: String) -> String:
	return String(fact(type).name)

static func color(type: String) -> Color:
	return fact(type).color as Color

static func icon(type: String) -> String:
	return String(fact(type).icon)

static func rule(type: String) -> String:
	return String(fact(type).rule)

static func bot_value(type: String) -> float:
	return float(fact(type).bot_value)

static func legend_text() -> String:
	return "SHRINE +3  ·  GRAVE −2  ·  STALL ITEM  ·  CODICIL BUY DEED  ·  " \
		+ "SÉANCE VISIBLE WHEEL  ·  TOLL PASS 2 / LAND CLAIM  ·  VENDETTA WAGER"

static func wheel_text() -> String:
	var lines: Array[String] = []
	for i in SEANCE_WHEEL.size():
		var slot: Dictionary = SEANCE_WHEEL[i]
		lines.append("%d  %s — %s" % [i + 1, String(slot.title), String(slot.rule)])
	return "\n".join(lines)
