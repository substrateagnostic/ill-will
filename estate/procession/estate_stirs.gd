class_name ProcessionStirs
extends RefCounted
## THE ESTATE STIRS (doc 28 §4) — the topology events. Drawn per GAME from
## two pools (guaranteed 1 MAJOR + 1 MINOR), announced by the Executor at
## game start as omens, fired at fixed night beats with full camera moments:
##   MINOR — night 1, top of round 3 (single-night probes likewise)
##   MAJOR — night 2 open (single-night probes: top of round 5)
## MAJORS permanently reroute the live graph — the board is different from
## here on (the mutations persist across the remaining nights; only pawns
## reset). MINORS are temporary or single-stone drama.
##
## Determinism: every draw comes from the dedicated STIRS stream (separate
## seeded streams doctrine, doc 28 §15 — séance/item/roll draws stay byte-
## identical). The match receipts re-freeze with the feature (ES era).
## The topology checksum (--boardgraphtest) hashes generate() and is
## untouched by construction.
##
## THE CRYPT stays sealed (producer ruling, tenth watch): the Reaper's
## Shortcut v1 carves the hollow↔valley passage only. The fourth route gets
## its own lane with the Gravedigger purchase path.

const S := preload("res://estate/procession/board_spaces.gd")

const MAJORS := ["bone_bridge", "reaper_shortcut", "landslip", "procession_road"]
const MINORS := ["flood", "hungry_grave", "hearse_moves", "wake", "crow_court"]

## SPACE CLAIMS (doc 33 §5b) — the ground each event was promised.
const CARVE_HOLLOW := Vector2(-16.0, 3.0)
const CARVE_VALLEY := Vector2(-24.0, 0.0)
const SLIP_CENTER := Vector2(-20.0, 4.0)
const ROAD_FROM := Vector2(31.0, -29.0)     # the fountain court
const ROAD_TO := Vector2(-14.0, -18.0)      # the bog's east shore
const HEARSE_PADS := [
	{"route": "hollow", "x": -13.0, "z": 6.0},
	{"route": "valley", "x": -13.0, "z": -15.0},
]

## Display names (plain announce cards — nothing hidden decides).
const TITLES := {
	"bone_bridge": "THE BONE BRIDGE", "reaper_shortcut": "THE REAPER'S SHORTCUT",
	"landslip": "THE LANDSLIP", "procession_road": "THE PROCESSION ROAD",
	"flood": "THE FLOOD", "hungry_grave": "THE HUNGRY GRAVE",
	"hearse_moves": "THE HEARSE MOVES ON", "wake": "THE WAKE",
	"crow_court": "CROW COURT",
}

var major := ""                 # this game's drawn MAJOR
var minor := ""                 # this game's drawn MINOR
var major_fired := false
var minor_fired := false

# ---- live minor state (procession reads these each round) ----
var flood_left := 0             # rounds GARDEN ROW stays closed
var wake_left := 0              # rounds the mourners crowd their stones
var wake_stones: Array = []     # the 3 crowded stone ids
var crow_stone := -1            # the court's stone (-1 = no court sitting)
var crow_done := false          # the first robbery scatters the murder

func draw(rng: RandomNumberGenerator, force_major := "", force_minor := "") -> void:
	major = force_major if force_major in MAJORS \
		else MAJORS[rng.randi_range(0, MAJORS.size() - 1)]
	minor = force_minor if force_minor in MINORS \
		else MINORS[rng.randi_range(0, MINORS.size() - 1)]

static func title(id: String) -> String:
	return String(TITLES.get(id, id.to_upper()))

## Apply one event's SIM mutation to the live board. Returns the info dict
## the ceremony frames (positions, node ids). Draw shape per event is fixed
## (receipt discipline): hungry_grave 1 · hearse 1 · wake 2 · crow 2 ·
## everything else 0 draws.
func apply(id: String, board: ProcessionBoardGraph,
		rng: RandomNumberGenerator) -> Dictionary:
	match id:
		"bone_bridge":
			return _apply_bone_bridge(board)
		"reaper_shortcut":
			return _apply_reaper_shortcut(board)
		"landslip":
			return _apply_landslip(board)
		"procession_road":
			return _apply_procession_road(board)
		"flood":
			flood_left = 2
			return {"event": id}
		"hungry_grave":
			return _apply_hungry_grave(board, rng)
		"hearse_moves":
			return _apply_hearse_moves(board, rng)
		"wake":
			return _apply_wake(board, rng)
		"crow_court":
			return _apply_crow_court(board, rng)
	return {"event": id}

## Entry = whichever end has more road left (the shortcut always runs toward
## the gate — edges are directed, doc 28 movement law).
static func _ordered(board: ProcessionBoardGraph, a: int, b: int) -> Array:
	return [a, b] if board.dist_to_gate(a) >= board.dist_to_gate(b) else [b, a]

## MAJOR 2 — the dormant ribs rise IN PLACE on the claim line; Weeping
## Valley gains a bypass over the pond's deep (two deck stones).
func _apply_bone_bridge(board: ProcessionBoardGraph) -> Dictionary:
	var a := ProcessionGrounds.BYPASS_A
	var b := ProcessionGrounds.BYPASS_B
	var ends := _ordered(board,
		board.nearest_node(a.x, a.y, "valley"),
		board.nearest_node(b.x, b.y, "valley"))
	var deck_y := ProcessionGrounds.WATER_Y + 0.55
	var pa := board.space_pos(int(ends[0]))
	var pb := board.space_pos(int(ends[1]))
	var deck: Array = [
		Vector3(lerpf(pa.x, pb.x, 0.36), deck_y, lerpf(pa.z, pb.z, 0.36)),
		Vector3(lerpf(pa.x, pb.x, 0.64), deck_y, lerpf(pa.z, pb.z, 0.64)),
	]
	board.register_route("bridge", "THE BONE BRIDGE", Color("d9d2bc"),
		"THE BOG'S OWN SHORTCUT · IT REMEMBERS BEING WALKED")
	var ids := board.append_stir_chain(int(ends[0]), int(ends[1]), deck, "bridge")
	return {"event": "bone_bridge", "entry": ends[0], "exit": ends[1],
		"stones": ids, "site": (pa + pb) * 0.5}

## MAJOR 1 — the scythe carves the hollow↔valley passage on its claim
## corridor. One carve stone midway. (The crypt descent waits for its lane.)
func _apply_reaper_shortcut(board: ProcessionBoardGraph) -> Dictionary:
	var ends := _ordered(board,
		board.nearest_node(CARVE_HOLLOW.x, CARVE_HOLLOW.y, "hollow"),
		board.nearest_node(CARVE_VALLEY.x, CARVE_VALLEY.y, "valley"))
	var pa := board.space_pos(int(ends[0]))
	var pb := board.space_pos(int(ends[1]))
	var mid := ProcessionGrounds.snap((pa + pb) * 0.5, 0.0)
	board.register_route("carve", "THE REAPER'S CUT", Color("7fd6a8"),
		"HE OPENED IT · HE DID NOT SAY FOR WHOM")
	var ids := board.append_stir_chain(int(ends[0]), int(ends[1]), [mid], "carve")
	return {"event": "reaper_shortcut", "entry": ends[0], "exit": ends[1],
		"stones": ids, "site": mid}

## MAJOR 3 — the hillside gives way: one Hollow Woods stone now empties into
## Weeping Valley. A REDIRECT, not a branch — the old road past it is
## scenery from here on (routes cross-contaminate, doc 28 §4).
func _apply_landslip(board: ProcessionBoardGraph) -> Dictionary:
	var h := board.nearest_node(SLIP_CENTER.x, SLIP_CENTER.y, "hollow")
	var v := board.nearest_node(SLIP_CENTER.x, SLIP_CENTER.y, "valley",
		board.dist_to_gate(h))
	if v < 0:
		v = board.nearest_node(SLIP_CENTER.x, SLIP_CENTER.y, "valley")
	var old_next: Array = board.next_of(h).duplicate()
	board.replace_next(h, [v])
	return {"event": "landslip", "from": h, "to": v, "stranded": old_next,
		"site": (board.space_pos(h) + board.space_pos(v)) * 0.5}

## MAJOR 4 — ghostly pallbearers tread a brand-new stone path down the
## reserved lane: fountain court → bog shore. Anyone may walk it.
func _apply_procession_road(board: ProcessionBoardGraph) -> Dictionary:
	var ends := _ordered(board,
		board.nearest_node(ROAD_FROM.x, ROAD_FROM.y, "garden"),
		board.nearest_node(ROAD_TO.x, ROAD_TO.y, "valley"))
	var pa := board.space_pos(int(ends[0]))
	var pb := board.space_pos(int(ends[1]))
	var lane: Array = []
	for k in 4:
		var t := (float(k) + 1.0) / 5.0
		lane.append(ProcessionGrounds.snap(pa.lerp(pb, t), 0.0))
	board.register_route("ghostroad", "THE PROCESSION ROAD", Color("bfd8ea"),
		"DEAD MEN PACED IT FIRST · IT WHISPERS")
	var ids := board.append_stir_chain(int(ends[0]), int(ends[1]), lane, "ghostroad")
	return {"event": "procession_road", "entry": ends[0], "exit": ends[1],
		"stones": ids, "site": pa.lerp(pb, 0.5)}

## MINOR 2 — one stone collapses into an Open Grave, permanently. Candidates
## honour the placement law (hazards never adjacent): plain path/offering
## stones with a single exit, no grave next door. 1 STIRS draw.
func _apply_hungry_grave(board: ProcessionBoardGraph,
		rng: RandomNumberGenerator) -> Dictionary:
	var cands: Array = []
	for n in board.nodes:
		var i := int(n.id)
		var t := String(n.type)
		if String(n.route) in ["garden", "hollow", "valley"] \
				and (t == S.BLANK or t == S.OFFERING) \
				and board.next_of(i).size() == 1:
			var beside := false
			for nx in board.next_of(i):
				if board.type_at(int(nx)) == S.OPEN_GRAVE:
					beside = true
			for n2 in board.nodes:
				if i in (n2.next as Array) and String(n2.type) == S.OPEN_GRAVE:
					beside = true
			if not beside:
				cands.append(i)
	var pick := int(cands[rng.randi_range(0, cands.size() - 1)])
	board.retype_stone(pick, S.OPEN_GRAVE)
	return {"event": "hungry_grave", "node": pick, "site": board.space_pos(pick)}

## MINOR 3 — the Peddler's Cart relocates to one of its anchor pads (doc 33
## §5b) on another route; the old stone forgets it was a shop. 1 STIRS draw.
func _apply_hearse_moves(board: ProcessionBoardGraph,
		rng: RandomNumberGenerator) -> Dictionary:
	var old := board.first_of_type(S.CART)
	var pad: Dictionary = HEARSE_PADS[rng.randi_range(0, HEARSE_PADS.size() - 1)]
	var target := -1
	var best := 1e18
	for n in board.nodes:
		if String(n.route) != String(pad.route) or String(n.type) != S.BLANK \
				or board.next_of(int(n.id)).size() != 1:
			continue
		var p := n.pos as Vector3
		var d: float = (p.x - float(pad.x)) ** 2 + (p.z - float(pad.z)) ** 2
		if d < best:
			best = d
			target = int(n.id)
	board.orphan_cart()
	board.retype_stone(old, S.BLANK)
	board.retype_stone(target, S.CART, false)
	return {"event": "hearse_moves", "from": old, "to": target,
		"site": board.space_pos(target)}

## MINOR 4 — mourners crowd 3 consecutive stones for 2 rounds: landing there
## costs a toast (−2 pennies) but pays a wreath rumor (a séance spin).
## 2 STIRS draws (route, offset).
func _apply_wake(board: ProcessionBoardGraph,
		rng: RandomNumberGenerator) -> Dictionary:
	var tag: String = ["garden", "hollow", "valley"][rng.randi_range(0, 2)]
	var start := int((board.graph.half_a_start as Dictionary)[tag])
	var span := int(board.route_info(tag).half_a)
	var o := rng.randi_range(1, span - 4)
	wake_stones = [start + o, start + o + 1, start + o + 2]
	wake_left = 2
	return {"event": "wake", "stones": wake_stones.duplicate(),
		"site": board.space_pos(start + o + 1)}

## MINOR 5 — the murder convenes on a late stone; the first pawn to pass or
## land is robbed (−3 pennies), scattering the court. 2 STIRS draws.
func _apply_crow_court(board: ProcessionBoardGraph,
		rng: RandomNumberGenerator) -> Dictionary:
	var tag: String = ["garden", "hollow", "valley"][rng.randi_range(0, 2)]
	var start := int((board.graph.half_b_start as Dictionary)[tag])
	var span := int(board.route_info(tag).half_b)
	crow_stone = start + rng.randi_range(1, span - 2)
	crow_done = false
	return {"event": "crow_court", "node": crow_stone,
		"site": board.space_pos(crow_stone)}
