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

# ---- THE PROCESSION graph board (doc 28 §3) ------------------------------
# The A-to-B board's space set. The ring-era types above stay declared so the
# retired ring files (board_path.gd, codicil.gd) still parse; the graph board
# (board_graph.gd) speaks only the types below plus BLANK (its path stones)
# and SEANCE (the circle survives unchanged).
const OFFERING := "offering"          # +3 · the mercy stone (was SHRINE)
const OPEN_GRAVE := "open_grave"      # −2 · the hazard (was WEEPING GRAVE)
const GRAVE_GOODS := "grave_goods"    # free item box (was THE STALL)
const FERRY_TOLL := "ferry_toll"      # pay the Ferryman 2, pass or land
const CART := "cart"                  # the Peddler's Cart — the priced shop (P2)
const CROSSROADS := "crossroads"      # a fork — the mover chooses the road
const GATE := "gate"                  # the Manor Gate — arrival ends the walk

# ---- P2 DISPLAY SEAM — the currency rename lives HERE and only here. ------
# Internally the shop currency is still "grudge" (RC §3 / doc 28 §13: 14
# minigame receipts reference the internal string and currency_events keep
# their names). Everything the PLAYER reads calls it PENNIES, and the victory
# currency is WREATHS. One seam, so a future rename is one edit.
const PENNY_GLYPH := "¢"
const WREATH_GLYPH := "⚘"
const PENNIES_LABEL := "PENNIES"
const WREATHS_LABEL := "WREATHS"

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
	# ---- graph-board space set (doc 28 §3) ----
	OFFERING: {
		"name": "OFFERING", "icon": "+", "color": Color("65d58b"),
		"rule": "+3 PENNIES", "bot_value": 5.0,
	},
	OPEN_GRAVE: {
		"name": "OPEN GRAVE", "icon": "−", "color": Color("b04d68"),
		"rule": "−2 PENNIES · MONUMENT OWNER RECEIVES THE TOLL", "bot_value": -5.0,
	},
	GRAVE_GOODS: {
		"name": "GRAVE GOODS", "icon": "!", "color": Color("e4a54c"),
		"rule": "TAKE ONE ANNOUNCED ITEM FROM THE BOX", "bot_value": 3.0,
	},
	FERRY_TOLL: {
		"name": "FERRYMAN'S TOLL", "icon": "$", "color": Color("64b9d5"),
		"rule": "PAY THE FERRYMAN 2 PENNIES · PASS OR LAND", "bot_value": -2.0,
	},
	CART: {
		"name": "PEDDLER'S CART", "icon": "C", "color": Color("f4db62"),
		"rule": "THE CART SELLS ITS WARES · LAST PLACE 30% OFF", "bot_value": 4.0,
	},
	CROSSROADS: {
		"name": "CROSSROADS", "icon": "Y", "color": Color("c9c2a8"),
		"rule": "CHOOSE YOUR ROAD", "bot_value": 0.5,
	},
	GATE: {
		"name": "THE MANOR GATE", "icon": "⌂", "color": Color("f4c95d"),
		"rule": "ARRIVE · RING THE FINAL BELL", "bot_value": 30.0,
	},
}

const SEANCE_WHEEL := [
	{"title": "MERCIFUL DRAFT", "rule": "EVERY MOURNER RECEIVES 2 PENNIES"},
	{"title": "EQUAL SHARES", "rule": "THE LEADER PAYS EACH RIVAL 1 PENNY"},
	{"title": "ROAD LEVY", "rule": "EVERY MOURNER RECEIVES 1 PENNY"},
	{"title": "FAVORED MEDIUM", "rule": "MEDIUM RECEIVES 4; ALL OTHERS RECEIVE 1"},
]

const ITEMS := [
	{"id": "mourning_pin", "name": "MOURNING PIN", "rule": "+1 SPACE ON YOUR NEXT PUTT"},
	{"id": "black_ribbon", "name": "BLACK RIBBON", "rule": "DEED LEADER −1 SPACE NEXT PUTT"},
	{"id": "grave_salt", "name": "GRAVE SALT", "rule": "CANCEL YOUR NEXT GRAVE LOSS"},
]   # ring-era free items — RETIRED with the priced cart (kept so old saves parse)

# ---- THE PEDDLER'S CART, PRICED (P2; doc 28 §6, d8-scaled magnitudes). ----
# kind drives the guardrails: max ONE die/movement item armed per turn
# ("boost"/"movement"/"die"), offensive items ("offense"/"trap") never stack
# on the same target in the same roll, inventory cap 3. BLACK VEIL is passive
# (spends itself on your next hazard). Prices are the announced rulebook —
# wreath LAST place shops at 30% off, announced, never hidden.
const INV_CAP := 3
const CART_WARES := [
	{"id": "lucky_penny", "name": "LUCKY PENNY", "cost": 5, "kind": "boost",
		"rule": "+3 ON YOUR NEXT ROLL"},
	{"id": "black_veil", "name": "BLACK VEIL", "cost": 5, "kind": "defense",
		"rule": "NEGATES YOUR NEXT HAZARD (SPENDS ITSELF)"},
	{"id": "shovel", "name": "PALLBEARER'S SHOVEL", "cost": 7, "kind": "movement",
		"rule": "DIG AHEAD 4 STONES · NOTHING TRIGGERS ON THE WAY"},
	{"id": "writ_d10", "name": "d10 WRIT", "cost": 8, "kind": "die",
		"rule": "YOUR NEXT ROLL IS A d10"},
	{"id": "crows_cut", "name": "CROW'S CUT", "cost": 10, "kind": "offense",
		"rule": "STEAL 5 PENNIES FROM A CHOSEN RIVAL"},
	{"id": "funeral_bell", "name": "FUNERAL BELL", "cost": 12, "kind": "offense",
		"rule": "THE TRACK LEADER SLIPS BACK 4 · HOME PAWNS ARE BEYOND REACH"},
	{"id": "writ_d12", "name": "d12 WRIT", "cost": 14, "kind": "die",
		"rule": "YOUR NEXT ROLL IS A d12"},
	{"id": "wreath_debt", "name": "WREATH OF DEBT", "cost": 20, "kind": "trap",
		"rule": "TRAP THIS STONE · FIRST RIVAL LANDING PAYS YOU 5"},
	{"id": "invitation", "name": "THE INVITATION", "cost": 22, "kind": "pick",
		"rule": "CHOOSE THE NEXT MINIGAME"},
	{"id": "wisp", "name": "WILL-O'-THE-WISP", "cost": 25, "kind": "movement",
		"rule": "TELEPORT TO THE NEXT FIXTURE ON YOUR ROAD"},
]
# GRAVE GOODS boxes hand out the cheap tier free (modern MP's lesson).
const BOX_POOL := ["lucky_penny", "black_veil", "shovel"]

static func ware(id: String) -> Dictionary:
	for w in CART_WARES:
		if String((w as Dictionary).id) == id:
			return w as Dictionary
	return {"id": id, "name": id.to_upper(), "cost": 0, "kind": "boost", "rule": ""}

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
