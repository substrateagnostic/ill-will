class_name ProcessionBoardGraph
extends Node3D
## THE PROCESSION's board, night 7 (doc 28 §3): a branching A-to-B GRAPH from
## the LYCHGATE to the MANOR GATE, replacing the 24-space ring. Three route
## personalities — GARDEN ROW (safe/long, offerings + the Peddler's Cart),
## HOLLOW WOODS (short/wild, grave-goods boxes + séance circles), WEEPING
## VALLEY (the gamble, open graves + the Ferryman's Toll) — joined by two
## CROSSROADS forks (one splits the roads, one mid-track lets you switch) and
## a merge before the gate.
##
## DATA-DRIVEN (presets.gd doctrine): routes, stone counts, and space-type
## ratios are declared in BOARD below; the generator turns that data into
## nodes + directed edges deterministically. The LAYOUT rng stream is seeded
## from the board data itself (never the night seed), so the topology receipt
## (--boardgraphtest) is night-independent and stable forever. Space-type
## ratios follow doc 28 §3 (~45% path, ~20% offering, ~15% séance, ~8% box,
## ~5% grave, ~4% toll, remainder crossroads/cart), flavoured per route.
##
## Route lengths are the producer-locked defaults (die study, night 7): the
## movement die lands as a d8 at meter integration, so a single pawn's walked
## path is ~28-32 stones gate-to-gate (garden 32 / valley 30 / hollow 28) and
## a median night still closes in roll-phase 5-6. Nothing in the walk code
## assumes a max roll — lengths and die are both dials.
##
## This node owns the WORLD: stone meshes, path ribbons, furniture (Meshy
## swap-point catalogue carried over from the ring), pawns, hop tweens, putt
## previews, and camera anchor helpers. The GRAMMAR lives in board_spaces.gd.

const S := preload("res://estate/procession/board_spaces.gd")

# --------------------------------------------------------------------------
# BOARD DATA — the one dictionary future boards vary.
# --------------------------------------------------------------------------
const BOARD := {
	"id": "estate_procession",
	"layout_seed": 771177,             # LAYOUT stream — board data, never the night seed
	"lychgate": Vector3(0.0, 0.0, 26.0),
	"fork1": Vector3(0.0, 0.0, 19.0),
	"fork2": Vector3(0.0, 0.0, 0.0),
	"merge": Vector3(0.0, 0.0, -19.0),
	"gate": Vector3(0.0, 0.0, -26.0),
	"approach_types": ["offering"],    # stones LYCHGATE → CROSSROADS 1
	"homestretch": 1,                  # path stones MERGE → MANOR GATE
	"routes": [
		{
			"tag": "garden", "label": "GARDEN ROW", "color": Color("6fbf6a"),
			"blurb": "SAFE AND LONG · OFFERINGS AND THE PEDDLER'S CART",
			"half_a": 12, "half_b": 13, "bulge_a": 21.0, "bulge_b": 19.0,
			"wobble": 1.0, "rise": 0.0,
			"ratios": {"offering": 0.40, "seance": 0.12, "grave_goods": 0.05},
			"fixtures": [{"type": "cart", "half": "a", "at": 0.5}],
		},
		{
			"tag": "hollow", "label": "HOLLOW WOODS", "color": Color("9a6fd8"),
			"blurb": "SHORT AND WILD · GRAVE GOODS AND SÉANCE CIRCLES",
			"half_a": 10, "half_b": 11, "bulge_a": -9.0, "bulge_b": -7.5,
			"wobble": 1.5, "rise": 0.7,
			"ratios": {"grave_goods": 0.22, "seance": 0.28, "offering": 0.07},
			"fixtures": [],
		},
		{
			"tag": "valley", "label": "WEEPING VALLEY", "color": Color("5f8fb3"),
			"blurb": "THE GAMBLE · OPEN GRAVES AND THE FERRYMAN'S TOLL",
			"half_a": 12, "half_b": 11, "bulge_a": -21.0, "bulge_b": -19.0,
			"wobble": 1.2, "rise": -0.4,
			"ratios": {"open_grave": 0.17, "ferry_toll": 0.13, "offering": 0.08,
				"seance": 0.14, "grave_goods": 0.05},
			"fixtures": [],
		},
	],
}

## The grounds' focal centre + the shared overview camera home (board_camera
## and procession read these so the director and posed shots stay in lock-step).
const CENTER := Vector3(0.0, 0.0, 0.0)
const OVERVIEW_POS := Vector3(-4.0, 38.0, 42.0)

# ---- SWAP-POINTS: the shipped meshy gothic batch (docs/verify/meshy-forge-
# VERIFY.md), carried over from the ring wholesale. Fallbacks keep a fresh
# checkout rendering.
const GEN_DIR := "res://assets/models/meshy/generated/"
const GEN_WAYPOINT := GEN_DIR + "board_waypoint_lantern.glb"
const GEN_TOLLARCH := GEN_DIR + "board_tollgate_arch.glb"
const GEN_SIGNPOST := GEN_DIR + "board_grim_signpost.glb"
const GEN_HEARSE := GEN_DIR + "board_hearse_cart.glb"
const GEN_CRYPT := GEN_DIR + "board_crypt_door.glb"
const GEN_PLANCHETTE := GEN_DIR + "board_planchette.glb"
const GEN_ANGEL := GEN_DIR + "estate_broken_angel.glb"
const GEN_WELL := GEN_DIR + "estate_covered_well.glb"
const GEN_DEADTREE := GEN_DIR + "estate_dead_tree.glb"
const GEN_FOUNTAIN := GEN_DIR + "estate_dry_fountain.glb"
const GEN_TOPIARY := GEN_DIR + "estate_hedge_topiary.glb"
const GEN_IRONGATE := GEN_DIR + "estate_iron_gate.glb"
const GEN_LAMPPOST := GEN_DIR + "estate_lamppost.glb"
const GEN_WHEELBARROW := GEN_DIR + "estate_wheelbarrow.glb"
const GRAVE_VARIANTS: Array[String] = [
	GEN_DIR + "grave_headstone_plain.glb",
	GEN_DIR + "grave_celtic_cross.glb",
	GEN_DIR + "grave_headstone_cracked.glb",
	GEN_DIR + "grave_small_obelisk.glb",
	GEN_DIR + "grave_cherub_stone.glb",
	GEN_DIR + "grave_tilted_slab.glb",
	GEN_DIR + "grave_mausoleum_front.glb",
	GEN_DIR + "grave_iron_fence_plot.glb",
]
const FB_TOLLARCH := "res://assets/models/meshy/manor_gate.glb"
const FB_LANTERN := "res://assets/models/meshy/stone_lantern.glb"
const FB_CRATE := "res://assets/models/meshy/crate.glb"
const FB_GRAVE := "res://assets/models/meshy/broken_column.glb"
const FB_COLUMN := "res://assets/models/meshy/broken_column.glb"
const FB_HEARSE := "res://assets/models/meshy/go_kart.glb"

# --------------------------------------------------------------------------
# GRAPH STATE (filled by build() from generate())
# --------------------------------------------------------------------------
var graph := {}                    # the generate() product (nodes/routes/landmarks/dist)
var nodes: Array = []              # [{id, type, route, pos, next:Array[int]}]
var grave_monument := {}           # open-grave node id -> owner seat (toll payee)
var pawns := {}                    # seat -> Node3D
var stone_nodes: Array = []

# --------------------------------------------------------------------------
# GENERATION — pure data -> graph. Static so --boardgraphtest can print the
# topology receipt without instancing a scene. Deterministic: the only rng is
# the LAYOUT stream seeded from board data.
# --------------------------------------------------------------------------
static func generate(board_data: Dictionary = BOARD) -> Dictionary:
	# Work on a deep copy — BOARD is a const (read-only recursively) and the
	# type assigner stashes per-route scratch inside the route dicts.
	var data := board_data.duplicate(true)
	var lrng := RandomNumberGenerator.new()
	lrng.seed = int(data.layout_seed)
	var out_nodes: Array = []
	var landmarks := {}

	# --- common approach: LYCHGATE -> approach stones -> CROSSROADS 1 ---
	var lych: Vector3 = data.lychgate
	var fork1: Vector3 = data.fork1
	var fork2: Vector3 = data.fork2
	var merge: Vector3 = data.merge
	var gate: Vector3 = data.gate
	landmarks["lychgate"] = out_nodes.size()
	out_nodes.append({"id": 0, "type": S.BLANK, "route": "common", "pos": lych, "next": []})
	var approach: Array = data.approach_types
	for k in approach.size():
		var t := float(k + 1) / float(approach.size() + 1)
		out_nodes.append({"id": out_nodes.size(), "type": String(approach[k]),
			"route": "common", "pos": lych.lerp(fork1, t), "next": []})
	landmarks["fork1"] = out_nodes.size()
	out_nodes.append({"id": out_nodes.size(), "type": S.CROSSROADS, "route": "common",
		"pos": fork1, "next": []})

	# --- route halves. Types are assigned per route over both halves at once
	# (ratios -> counts by largest remainder; hazards never adjacent; the first
	# and last stone of each half stay path so forks breathe). ---
	var route_meta: Array = []
	var half_a_start := {}
	var half_b_start := {}
	for r in data.routes:
		var rd := r as Dictionary
		var types := _route_types(rd, lrng)
		half_a_start[rd.tag] = out_nodes.size()
		_append_half(out_nodes, rd, "a", fork1, fork2, types)
		route_meta.append({"tag": rd.tag, "label": rd.label, "color": rd.color,
			"blurb": rd.blurb, "half_a": int(rd.half_a), "half_b": int(rd.half_b)})
	landmarks["fork2"] = out_nodes.size()
	out_nodes.append({"id": out_nodes.size(), "type": S.CROSSROADS, "route": "common",
		"pos": fork2, "next": []})
	for r in data.routes:
		var rd := r as Dictionary
		var types_b: Dictionary = rd.get("_types_b", {})
		half_b_start[rd.tag] = out_nodes.size()
		_append_half(out_nodes, rd, "b", fork2, merge, types_b)

	# --- merge + homestretch + MANOR GATE ---
	landmarks["merge"] = out_nodes.size()
	out_nodes.append({"id": out_nodes.size(), "type": S.BLANK, "route": "common",
		"pos": merge, "next": []})
	var stretch := int(data.homestretch)
	for k in stretch:
		var t := float(k + 1) / float(stretch + 1)
		out_nodes.append({"id": out_nodes.size(), "type": S.BLANK, "route": "common",
			"pos": merge.lerp(gate, t), "next": []})
	landmarks["gate"] = out_nodes.size()
	out_nodes.append({"id": out_nodes.size(), "type": S.GATE, "route": "common",
		"pos": gate, "next": []})

	# --- edges: chains, forks fan out in route declaration order ---
	var f1 := int(landmarks.fork1)
	var f2 := int(landmarks.fork2)
	var mg := int(landmarks.merge)
	var gt := int(landmarks.gate)
	for i in f1:
		out_nodes[i]["next"] = [i + 1]
	for r in data.routes:
		var rd := r as Dictionary
		var a0 := int(half_a_start[rd.tag])
		var na := int(rd.half_a)
		(out_nodes[f1]["next"] as Array).append(a0)
		for k in na:
			out_nodes[a0 + k]["next"] = [a0 + k + 1] if k < na - 1 else [f2]
		var b0 := int(half_b_start[rd.tag])
		var nb := int(rd.half_b)
		(out_nodes[f2]["next"] as Array).append(b0)
		for k in nb:
			out_nodes[b0 + k]["next"] = [b0 + k + 1] if k < nb - 1 else [mg]
	for i in range(mg, gt):
		out_nodes[i]["next"] = [i + 1]
	out_nodes[gt]["next"] = []

	# --- weighted distance-to-finish per node (shortest remaining stones).
	# THE ranking key for un-finished pawns — node ids mean nothing across
	# routes; remaining distance always does. Also feeds bot strategy. ---
	var dist: Array[int] = []
	dist.resize(out_nodes.size())
	for i in dist.size():
		dist[i] = 99999
	dist[gt] = 0
	var changed := true
	while changed:
		changed = false
		for n in out_nodes:
			var best: int = dist[int(n.id)]
			for nx in (n.next as Array):
				if dist[int(nx)] + 1 < best:
					best = dist[int(nx)] + 1
			if best < dist[int(n.id)]:
				dist[int(n.id)] = best
				changed = true

	for r in data.routes:
		(r as Dictionary).erase("_types_b")   # scratch from _route_types
	return {"id": String(data.id), "nodes": out_nodes, "routes": route_meta,
		"landmarks": landmarks, "dist": dist,
		"half_a_start": half_a_start, "half_b_start": half_b_start}

## Assign this route's space types: ratios -> counts (largest remainder over
## the route's total stones), then a LAYOUT-rng shuffle over free slots with
## the placement rules. Returns the half-"a" map; stashes half-"b" in the
## route dict under "_types_b" (scratch, erased by generate()).
static func _route_types(rd: Dictionary, lrng: RandomNumberGenerator) -> Dictionary:
	var na := int(rd.half_a)
	var nb := int(rd.half_b)
	var total := na + nb
	var ratios: Dictionary = rd.ratios
	# counts by largest remainder (deterministic tie-break: type name)
	var ratio_sum := 0.0
	for t in ratios:
		ratio_sum += float(ratios[t])
	var want := int(round(ratio_sum * float(total)))
	var floors := {}
	var rems: Array = []
	var floor_sum := 0
	for t in ratios:
		var exact := float(ratios[t]) * float(total)
		floors[t] = int(floor(exact))
		floor_sum += int(floors[t])
		rems.append({"t": String(t), "r": exact - floor(exact)})
	rems.sort_custom(func(a, b):
		if absf(float(a.r) - float(b.r)) > 0.0001:
			return float(a.r) > float(b.r)
		return String(a.t) < String(b.t))
	var extra := want - floor_sum
	for e in rems:
		if extra <= 0:
			break
		floors[e.t] = int(floors[e.t]) + 1
		extra -= 1
	# slots: {half, idx}; ends of each half reserved as path; fixtures reserved.
	var fixture_at := {}
	for f in (rd.get("fixtures", []) as Array):
		var fd := f as Dictionary
		var n := na if String(fd.half) == "a" else nb
		var idx := clampi(int(round(float(fd.at) * float(n - 1))), 1, n - 2)
		fixture_at["%s%d" % [String(fd.half), idx]] = String(fd.type)
	var free: Array = []
	for k in na:
		if k == 0 or k == na - 1 or fixture_at.has("a%d" % k):
			continue
		free.append({"h": "a", "i": k})
	for k in nb:
		if k == 0 or k == nb - 1 or fixture_at.has("b%d" % k):
			continue
		free.append({"h": "b", "i": k})
	for k in range(free.size() - 1, 0, -1):
		var j := lrng.randi_range(0, k)
		var tmp = free[k]; free[k] = free[j]; free[j] = tmp
	# place: hazards first (spacing rule), then the rest.
	var order: Array[String] = ["open_grave", "ferry_toll", "offering", "seance", "grave_goods"]
	var placed := {}   # "h<idx>" -> type
	for t in order:
		var count := int(floors.get(t, 0))
		var attempts := 0
		while count > 0 and not free.is_empty() and attempts < 200:
			attempts += 1
			var slot: Dictionary = free.pop_front()
			var key := "%s%d" % [String(slot.h), int(slot.i)]
			if (t == "open_grave" or t == "ferry_toll") and _hazard_beside(placed, slot):
				free.append(slot)   # requeue; try a spaced slot first
				continue
			placed[key] = t
			count -= 1
		# Never DROP a declared stone: if spacing could not be honoured, place
		# the remainder anyway (a crowded bog beats a lying ratio table).
		while count > 0 and not free.is_empty():
			var slot2: Dictionary = free.pop_front()
			placed["%s%d" % [String(slot2.h), int(slot2.i)]] = t
			count -= 1
	var out_a := {}
	var out_b := {}
	for key in fixture_at:
		var k := String(key)
		if k.begins_with("a"):
			out_a[int(k.substr(1))] = "cart"
		else:
			out_b[int(k.substr(1))] = "cart"
	for key in placed:
		var k := String(key)
		if k.begins_with("a"):
			out_a[int(k.substr(1))] = String(placed[key])
		else:
			out_b[int(k.substr(1))] = String(placed[key])
	rd["_types_b"] = out_b
	return out_a

static func _hazard_beside(placed: Dictionary, slot: Dictionary) -> bool:
	for d in [-1, 1]:
		var t := String(placed.get("%s%d" % [String(slot.h), int(slot.i) + d], ""))
		if t == "open_grave" or t == "ferry_toll":
			return true
	return false

## One half of a route: stones evenly spaced (arc length) along a quadratic
## bezier between the two anchor forks, with a gentle perpendicular wobble and
## the route's rise/dip. types maps local index -> type (default path).
static func _append_half(out_nodes: Array, rd: Dictionary, half: String,
		from: Vector3, to: Vector3, types: Dictionary) -> void:
	var n := int(rd.half_a) if half == "a" else int(rd.half_b)
	var bulge := float(rd.bulge_a) if half == "a" else float(rd.bulge_b)
	var ctrl := (from + to) * 0.5 + Vector3(bulge, 0.0, 0.0)
	var pts := _even_bezier(from, ctrl, to, n)
	for k in n:
		var p: Vector3 = pts[k]
		# perpendicular wobble (deterministic sine, never rng) + route rise
		var t := float(k + 1) / float(n + 1)
		var tangent := _bezier_tangent(from, ctrl, to, t)
		var perp := tangent.cross(Vector3.UP).normalized()
		var phase := 0.9 if half == "a" else 2.3
		p += perp * float(rd.wobble) * sin(float(k) * 1.7 + phase)
		var route_t := t * 0.5 if half == "a" else 0.5 + t * 0.5
		p.y = 0.04 + float(rd.rise) * sin(PI * route_t)
		out_nodes.append({"id": out_nodes.size(), "type": String(types.get(k, S.BLANK)),
			"route": String(rd.tag), "pos": p, "next": []})

static func _bezier(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * c + t * t * b

static func _bezier_tangent(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var v := 2.0 * (1.0 - t) * (c - a) + 2.0 * t * (b - c)
	return v.normalized() if v.length() > 0.001 else Vector3.FORWARD

## n interior points at even arc length along the bezier (endpoints excluded —
## they are the fork/merge nodes themselves).
static func _even_bezier(a: Vector3, c: Vector3, b: Vector3, n: int) -> Array:
	var samples := 256
	var cum: Array[float] = [0.0]
	var prev := a
	for s in range(1, samples + 1):
		var p := _bezier(a, c, b, float(s) / float(samples))
		cum.append(cum[s - 1] + prev.distance_to(p))
		prev = p
	var total: float = cum[samples]
	var out: Array = []
	for k in range(1, n + 1):
		var target := total * float(k) / float(n + 1)
		var s := 1
		while s < samples and cum[s] < target:
			s += 1
		var seg: float = cum[s] - cum[s - 1]
		var frac: float = 0.0 if seg <= 0.0 else (target - cum[s - 1]) / seg
		out.append(_bezier(a, c, b, (float(s - 1) + frac) / float(samples)))
	return out

# --------------------------------------------------------------------------
# TOPOLOGY RECEIPT (--boardgraphtest)
# --------------------------------------------------------------------------
static func topology_receipt(board_data: Dictionary = BOARD) -> Array[String]:
	var data := board_data.duplicate(true)
	var g := generate(data)
	var ns: Array = g.nodes
	var lm: Dictionary = g.landmarks
	var dist: Array = g.dist
	var lines: Array[String] = []
	var edges := 0
	var counts := {}
	for n in ns:
		edges += (n.next as Array).size()
		var t := String(n.type)
		counts[t] = int(counts.get(t, 0)) + 1
	lines.append("BOARDGRAPH board=%s nodes=%d edges=%d" % [String(g.id), ns.size(), edges])
	# per-route lengths: stones stepped fork1 -> merge (both crossroads counted)
	for r in (g.routes as Array):
		var rd := r as Dictionary
		var rlen := 1 + int(rd.half_a) + 1 + int(rd.half_b)
		var walked := int(lm.fork1) + rlen + 1 + int(data.homestretch) + 1
		lines.append("BOARDGRAPH route=%s len=%d (a=%d b=%d) walked_gate_to_gate=%d" % [
			String(rd.label), rlen, int(rd.half_a), int(rd.half_b), walked])
	# space-type ratio table
	var order := [S.BLANK, S.OFFERING, S.SEANCE, S.GRAVE_GOODS, S.OPEN_GRAVE,
		S.FERRY_TOLL, S.CART, S.CROSSROADS, S.GATE]
	var parts: Array[String] = []
	for t in order:
		var c := int(counts.get(t, 0))
		parts.append("%s=%d(%.1f%%)" % [t, c, 100.0 * float(c) / float(ns.size())])
	lines.append("BOARDGRAPH types " + " ".join(parts))
	# distance-to-finish (shortest remaining stones) at the landmarks + forks
	lines.append("BOARDGRAPH dist lychgate=%d fork1=%d fork2=%d merge=%d gate=%d" % [
		int(dist[int(lm.lychgate)]), int(dist[int(lm.fork1)]),
		int(dist[int(lm.fork2)]), int(dist[int(lm.merge)]), int(dist[int(lm.gate)])])
	var dparts: Array[String] = []
	for n in ns:
		dparts.append("%d:%d" % [int(n.id), int(dist[int(n.id)])])
	lines.append("BOARDGRAPH dist_all " + " ".join(dparts))
	# crossroads reachability: every fork branch must reach the gate
	var reach_ok := true
	for fk in ["fork1", "fork2"]:
		for branch in (ns[int(lm[fk])].next as Array):
			var ok := _reaches(ns, int(branch), int(lm.gate))
			var tag := String(ns[int(branch)].route)
			lines.append("BOARDGRAPH reach %s->%s=%s" % [fk, tag, "OK" if ok else "FAIL"])
			reach_ok = reach_ok and ok
	# stable checksum over ids/types/routes/edges (positions excluded — floats)
	var sig := ""
	for n in ns:
		sig += "%d:%s:%s:%s|" % [int(n.id), String(n.type), String(n.route),
			str(n.next)]
	lines.append("BOARDGRAPH checksum=%08x" % (sig.hash() & 0xFFFFFFFF))
	lines.append("BOARDGRAPH_%s" % ("OK" if reach_ok else "FAIL"))
	return lines

static func _reaches(ns: Array, from: int, target: int) -> bool:
	var seen := {}
	var stack := [from]
	while not stack.is_empty():
		var i := int(stack.pop_back())
		if i == target:
			return true
		if seen.has(i):
			continue
		seen[i] = true
		for nx in (ns[i].next as Array):
			stack.append(int(nx))
	return false

# --------------------------------------------------------------------------
# GRAPH READS (procession / camera / executor / minimap all speak these)
# --------------------------------------------------------------------------
func node_count() -> int:
	return nodes.size()

func space_pos(i: int) -> Vector3:
	return (nodes[i].pos as Vector3) if i >= 0 and i < nodes.size() else Vector3.ZERO

func type_at(i: int) -> String:
	return String(nodes[i].type) if i >= 0 and i < nodes.size() else S.BLANK

func route_of(i: int) -> String:
	return String(nodes[i].route) if i >= 0 and i < nodes.size() else "common"

func next_of(i: int) -> Array:
	return (nodes[i].next as Array) if i >= 0 and i < nodes.size() else []

func is_fork(i: int) -> bool:
	return next_of(i).size() > 1

## Shortest remaining stones to the Manor Gate — THE ranking key for pawns
## still on the road (node ids mean nothing across routes; distance does).
func dist_to_gate(i: int) -> int:
	var dist: Array = graph.get("dist", [])
	return int(dist[i]) if i >= 0 and i < dist.size() else 99999

func gate_id() -> int:
	return int((graph.landmarks as Dictionary).gate)

func lychgate_pos() -> Vector3:
	return space_pos(int((graph.landmarks as Dictionary).lychgate))

func gate_pos() -> Vector3:
	return space_pos(gate_id())

## Route metadata by tag (label/color/blurb) for prompts, ribbons, HUD.
func route_info(tag: String) -> Dictionary:
	for r in (graph.routes as Array):
		if String((r as Dictionary).tag) == tag:
			return r as Dictionary
	return {"tag": tag, "label": tag.to_upper(), "color": Color(0.8, 0.76, 0.6),
		"blurb": ""}

## The middle stone of a route's first half — a flyover waypoint.
func route_mid_pos(tag: String) -> Vector3:
	var start := int((graph.half_a_start as Dictionary).get(tag, 0))
	var ri := route_info(tag)
	return space_pos(start + int(ri.get("half_a", 1)) / 2)

## Options at a fork, for the crossroads prompt + bot strategy:
## [{node, route, label, color, blurb, left}] — left = stones to the gate
## stepping onto that branch.
func branch_options(fork_id: int) -> Array:
	var out: Array = []
	for nx in next_of(fork_id):
		var tag := route_of(int(nx))
		var ri := route_info(tag)
		out.append({"node": int(nx), "route": tag, "label": String(ri.label),
			"color": ri.color, "blurb": String(ri.get("blurb", "")),
			"left": dist_to_gate(int(nx)) + 1})
	return out

## The first node of a given type (capture hero shots).
func first_of_type(type: String) -> int:
	for n in nodes:
		if String(n.type) == type:
			return int(n.id)
	return 0

## Toll payee if a rival's monument stands on this open grave, else -1.
func grave_owner(node_id: int) -> int:
	return int(grave_monument.get(node_id, -1))

# --------------------------------------------------------------------------
# BUILD — the world from the graph
# --------------------------------------------------------------------------
func build(players: Array, monuments: Array) -> void:
	graph = generate()
	nodes = graph.nodes
	_build_ground()
	stone_nodes.clear()
	for n in nodes:
		_build_stone(int(n.id), String(n.type))
	_build_ribbons()
	_map_monuments(monuments, players)
	_build_furniture()
	for pl in players:
		var pawn := _make_pawn(pl)
		add_child(pawn)
		pawns[int(pl.index)] = pawn
		seat_pawn(int(pl.index), 0)

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(64, 72)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.055, 0.065, 0.085)   # cool damp lawn under moonlight
	gmat.roughness = 1.0
	ground.material_override = gmat
	ground.position = CENTER + Vector3(0, -0.02, 0)
	add_child(ground)

## Flagstone ribbons under every edge so each road reads as a walked path even
## in the dark — faintly tinted by the destination's route colour.
func _build_ribbons() -> void:
	for n in nodes:
		for nx in (n.next as Array):
			var a: Vector3 = n.pos
			var b: Vector3 = nodes[int(nx)].pos
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.5, 0.05, a.distance_to(b))
			seg.mesh = bm
			var mat := StandardMaterial3D.new()
			var rcol: Color = route_info(route_of(int(nx))).color if route_of(int(nx)) != "common" \
				else Color(0.5, 0.5, 0.55)
			mat.albedo_color = Color(0.16, 0.17, 0.205).lerp(rcol, 0.14)
			mat.roughness = 0.95
			seg.material_override = mat
			add_child(seg)
			var mid := (a + b) * 0.5
			seg.global_position = Vector3(mid.x, (a.y + b.y) * 0.5 - 0.03, mid.z)
			if a.distance_to(b) > 0.01:
				seg.look_at(Vector3(b.x, seg.global_position.y, b.z), Vector3.UP)

func _build_stone(i: int, type: String) -> void:
	var pos := space_pos(i)
	var typed := type != S.BLANK
	var col: Color = S.color(type)
	if not typed:
		col = route_info(route_of(i)).color if route_of(i) != "common" else S.color(S.BLANK)
	# Dark stone puck; colour identity in a lit emissive rim (bloom under
	# MOONLIT). Path stones are smaller + dimmer so the TYPED stones carry the
	# board's grammar and 60 stones don't shout at once.
	var s := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.86 if typed else 0.6
	mesh.bottom_radius = 0.98 if typed else 0.7
	mesh.height = 0.18
	s.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.115, 0.14).lerp(col, 0.12)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.06
	mat.roughness = 0.92
	s.material_override = mat
	add_child(s)
	s.global_position = pos
	stone_nodes.append(s)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.74 if typed else 0.5
	tm.outer_radius = 0.90 if typed else 0.62
	tm.rings = 8
	tm.ring_segments = 28
	rim.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col.darkened(0.2)
	rmat.emission_enabled = true
	rmat.emission = col
	rmat.emission_energy_multiplier = 2.6 if typed else 1.1
	rmat.roughness = 0.5
	rim.material_override = rmat
	rim.rotation_degrees.x = 90.0
	add_child(rim)
	rim.global_position = pos + Vector3(0, 0.10, 0)
	if not typed:
		return
	# Typed stones carry the engraved rune + the billboard identity tag (the
	# colour-blind-safe read; never colour alone). Path stones stay quiet.
	var rune := Label3D.new()
	rune.text = S.icon(type)
	rune.font_size = 120
	rune.pixel_size = 0.0032
	rune.rotation_degrees = Vector3(-90, 0, 0)
	rune.modulate = col.lerp(Color.WHITE, 0.35)
	rune.outline_size = 22
	rune.outline_modulate = Color(0, 0, 0, 0.85)
	rune.no_depth_test = false
	rune.position = pos + Vector3(0, 0.115, 0)
	add_child(rune)
	var tag := Label3D.new()
	tag.text = "%s  %s" % [S.icon(type), S.display_name(type)]
	tag.font_size = 40
	tag.pixel_size = 0.0056
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = col.lerp(Color.WHITE, 0.15)
	tag.outline_size = 12
	tag.outline_modulate = Color(0, 0, 0, 0.92)
	tag.position = pos + Vector3(0, 1.15, 0)
	add_child(tag)

## Bind existing player monuments to OPEN GRAVE stones (deterministic by node
## order) so a rival landing there pays its owner — the cross-night orb kept.
func _map_monuments(monuments: Array, players: Array) -> void:
	grave_monument.clear()
	var graves: Array = []
	for n in nodes:
		if String(n.type) == S.OPEN_GRAVE:
			graves.append(int(n.id))
	var name_to_seat := {}
	for pl in players:
		name_to_seat[String(pl.name)] = int(pl.index)
	var g := 0
	for m in monuments:
		if g >= graves.size():
			break
		var owner_name := String((m as Dictionary).get("owner", ""))
		if name_to_seat.has(owner_name):
			grave_monument[graves[g]] = int(name_to_seat[owner_name])
			_mark_grave_monument(int(graves[g]), (m as Dictionary).get("color", "ffffff"))
			g += 1

func _mark_grave_monument(node_id: int, color_html) -> void:
	var col := Color.from_string(str(color_html), Color.WHITE)
	var votive := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.12
	cyl.height = 0.34
	votive.mesh = cyl
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = col.darkened(0.3)
	vmat.emission_enabled = true
	vmat.emission = col
	vmat.emission_energy_multiplier = 2.2
	votive.material_override = vmat
	add_child(votive)
	votive.global_position = space_pos(node_id) + Vector3(0.55, 0.17, 0.45)

# --------------------------------------------------------------------------
# FURNITURE — swap-point catalogue on the graph
# --------------------------------------------------------------------------
func _place(node: Node3D, pos: Vector3) -> void:
	add_child(node)
	node.global_position = pos

func _place_facing(node: Node3D, pos: Vector3, target: Vector3) -> void:
	add_child(node)
	node.look_at_from_position(pos, target, Vector3.UP)

## Outward from the walked line at node i: perpendicular to the local path
## direction (radial-from-centre made graph-shaped).
func _outward(i: int) -> Vector3:
	var here := space_pos(i)
	var nxt := next_of(i)
	var dir := Vector3.FORWARD
	if not nxt.is_empty():
		dir = space_pos(int(nxt[0])) - here
	elif i > 0:
		dir = here - space_pos(i - 1)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	var perp := dir.normalized().cross(Vector3.UP)
	# push AWAY from the grounds' centreline so props sit outboard of the road
	var radial := here - CENTER
	radial.y = 0.0
	if radial.length() > 0.01 and perp.dot(radial.normalized()) < 0.0:
		perp = -perp
	return perp.normalized()

func _build_furniture() -> void:
	for n in nodes:
		var i := int(n.id)
		var type := String(n.type)
		var here := space_pos(i)
		var out := _outward(i)
		match type:
			S.OFFERING:
				_place(_prop(GEN_LAMPPOST, FB_LANTERN, 2.4), here + out * 1.1 + Vector3(0, 0.06, 0))
			S.OPEN_GRAVE:
				_place(_prop(_grave_variant_for(i), FB_GRAVE, 1.7), here + out * 0.9 + Vector3(0, 0.06, 0))
			S.GRAVE_GOODS:
				_place(_prop(FB_CRATE, FB_CRATE, 0.9), here + out * 1.15 + Vector3(0, 0.06, 0))
				_place(_prop(FB_LANTERN, FB_LANTERN, 1.5), here + out * 1.15 + Vector3(0.7, 0.06, 0.2))
			S.SEANCE:
				_place(_prop(GEN_PLANCHETTE, FB_LANTERN, 0.35), here + out * 1.05 + Vector3(0, 0.06, 0))
			S.FERRY_TOLL:
				_place_facing(_prop(GEN_TOLLARCH, FB_TOLLARCH, 3.4), here + Vector3(0, 0.06, 0),
					here + _flow_dir(i) * 4.0)
			S.CART:
				_place_facing(_prop(GEN_HEARSE, FB_HEARSE, 2.1), here + out * 1.5 + Vector3(0, 0.06, 0), here)
				_place(_prop(FB_LANTERN, FB_LANTERN, 1.5), here + out * 2.3 + Vector3(0.5, 0.06, 0.3))
			S.CROSSROADS:
				_place(_prop(GEN_SIGNPOST, FB_LANTERN, 2.6), here + out * 1.4 + Vector3(0, 0.06, 0))
		# Sparse route-biome dressing every 4th stone, outboard.
		if type == S.BLANK and i % 4 == 1:
			match route_of(i):
				"garden":
					_place(_prop(GEN_TOPIARY, FB_COLUMN, 2.2), here + out * 2.6 + Vector3(0, 0.04, 0))
				"hollow":
					_place(_prop(GEN_DEADTREE, FB_COLUMN, 3.8), here + out * 2.8 + Vector3(0, 0.04, 0))
				"valley":
					_place(_prop([GEN_WELL, GEN_ANGEL, GEN_WHEELBARROW][posmod(i, 3)],
						FB_COLUMN, 2.2), here + out * 2.7 + Vector3(0, 0.04, 0))
	_build_lychgate()
	_build_manor_gate()
	_build_perimeter()

func _grave_variant_for(node_id: int) -> String:
	return GRAVE_VARIANTS[posmod(node_id, GRAVE_VARIANTS.size())]

## Direction of travel at node i (toward its first exit).
func _flow_dir(i: int) -> Vector3:
	var nxt := next_of(i)
	if nxt.is_empty():
		return Vector3.FORWARD
	var v := space_pos(int(nxt[0])) - space_pos(i)
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD

## THE LYCHGATE — the start: a covered iron arch over the first stone, the
## hearse waiting beside it, a crooked signpost pointing up the road.
func _build_lychgate() -> void:
	var start := lychgate_pos()
	var flow := _flow_dir(0)
	_place_facing(_prop(GEN_TOLLARCH, FB_TOLLARCH, 4.2), start + Vector3(0, 0.06, 0), start + flow * 6.0)
	_place_facing(_prop(GEN_HEARSE, FB_HEARSE, 2.1), start + Vector3(-3.0, 0.06, 1.2), start)
	_place(_prop(GEN_SIGNPOST, FB_LANTERN, 2.6), start + Vector3(2.6, 0.06, 0.6))
	var tag := Label3D.new()
	tag.text = "THE LYCHGATE"
	tag.font_size = 56
	tag.pixel_size = 0.008
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.8, 0.85, 1.0)
	tag.outline_size = 14
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.position = start + Vector3(0, 3.9, 0)
	add_child(tag)

## THE MANOR GATE — the finish: the grand arch, warm light, the bell's home.
func _build_manor_gate() -> void:
	var gate := gate_pos()
	var back := (gate - CENTER)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	_place_facing(_prop(GEN_TOLLARCH, FB_TOLLARCH, 5.4), gate + back * 1.4 + Vector3(0, 0.06, 0), CENTER)
	_place(_prop(GEN_LAMPPOST, FB_LANTERN, 2.6), gate + back * 0.8 + Vector3(3.2, 0.06, 0))
	_place(_prop(GEN_LAMPPOST, FB_LANTERN, 2.6), gate + back * 0.8 + Vector3(-3.2, 0.06, 0))
	# A warm pool of light on the finish — the one gold glow on the grounds
	# (the Codicil's beacon language, re-pointed at the true objective).
	var lamp := OmniLight3D.new()
	lamp.name = "GateGlow"
	lamp.light_color = Color(1.0, 0.86, 0.42)
	lamp.light_energy = 2.6
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	lamp.position = gate + back * 1.0 + Vector3(0, 2.6, 0)
	add_child(lamp)
	var manor := Label3D.new()
	manor.text = "THE MANOR GATE"
	manor.font_size = 64
	manor.pixel_size = 0.008
	manor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	manor.modulate = Color(1, 0.9, 0.5)
	manor.outline_size = 14
	manor.outline_modulate = Color(0, 0, 0, 0.9)
	manor.position = gate + back * 1.6 + Vector3(0, 4.4, 0)
	add_child(manor)

## Sparse fixed perimeter dressing — deterministic hand-placed set, scaled to
## the A-to-B grounds. Never draws from any rng.
func _build_perimeter() -> void:
	var pieces: Array = [
		{"p": GEN_CRYPT, "pos": Vector3(-14.0, 0.06, 12.0), "h": 3.4},
		{"p": GEN_DEADTREE, "pos": Vector3(14.5, 0.06, 8.0), "h": 4.3},
		{"p": GEN_ANGEL, "pos": Vector3(-15.5, 0.06, -9.0), "h": 3.0},
		{"p": GEN_WELL, "pos": Vector3(13.5, 0.06, -12.0), "h": 2.4},
		{"p": GEN_FOUNTAIN, "pos": Vector3(0.0, 0.02, 9.5), "h": 1.5},
		{"p": GEN_IRONGATE, "pos": Vector3(7.5, 0.06, 22.0), "h": 2.3},
		{"p": GEN_IRONGATE, "pos": Vector3(-7.5, 0.06, 22.0), "h": 2.3},
		{"p": GEN_TOPIARY, "pos": Vector3(9.0, 0.06, -21.0), "h": 2.6},
		{"p": GEN_TOPIARY, "pos": Vector3(-9.0, 0.06, -21.0), "h": 2.6},
	]
	for e in pieces:
		_place(_prop(String(e["p"]), FB_COLUMN, float(e["h"])), e["pos"] as Vector3)

## Instance a generated GLB if present, else the committed fallback, else a
## tinted primitive. Never returns null; purely visual. (Ring-era code, kept.)
func _prop(gen_path: String, fallback_path: String, height: float, tint := Color(0, 0, 0, 0)) -> Node3D:
	var path := gen_path if ResourceLoader.exists(gen_path) else fallback_path
	if ResourceLoader.exists(path):
		return MeshyProp.instance(path, height)
	var wrap := Node3D.new()
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.35
	cm.height = height
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint if tint.a > 0.0 else Color(0.6, 0.6, 0.65)
	m.material_override = mat
	m.position.y = height * 0.5
	wrap.add_child(m)
	return wrap

# --------------------------------------------------------------------------
# PAWNS + MOVEMENT
# --------------------------------------------------------------------------
func _make_pawn(pl: Dictionary) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.28
	bm.height = 1.0
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pl.color
	mat.emission_enabled = true
	mat.emission = Color(pl.color) * 0.4
	mat.roughness = 0.4
	body.material_override = mat
	body.position.y = 0.62
	root.add_child(body)
	var tag := Label3D.new()
	tag.text = "%s %s" % [PlayerBadge.glyph(int(pl.index)), String(pl.name)]
	tag.font_size = 42
	tag.pixel_size = 0.007
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = pl.color
	tag.outline_size = 10
	tag.position.y = 1.5
	root.add_child(tag)
	return root

## Seat offset so four pawns share a stone without z-fighting.
func _seat_offset(seat: int) -> Vector3:
	return Vector3(0.42 * (seat - 1.5), 0.0, 0.34 * float((seat % 2) * 2 - 1))

func seat_pawn(seat: int, node_id: int) -> void:
	if pawns.has(seat):
		pawns[seat].global_position = space_pos(node_id) + _seat_offset(seat)

## Animated hop along an explicit node path (the walk the sim already chose,
## forks resolved). Returns the tween so the caller can await the whole board.
func advance_pawn_path(seat: int, path: Array) -> Tween:
	var tw := create_tween()
	if not pawns.has(seat) or path.is_empty():
		tw.tween_interval(0.01)
		return tw
	for node_id in path:
		var target := space_pos(int(node_id)) + _seat_offset(seat)
		tw.tween_property(pawns[seat], "global_position", target + Vector3(0, 0.55, 0), 0.13) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(pawns[seat], "global_position", target, 0.11) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(Sfx.play.bind("card", -12.0, 0.15))
	return tw

# --------------------------------------------------------------------------
# PUTT TARGET PREVIEW (F29) — unchanged language, graph destinations
# --------------------------------------------------------------------------
var _preview: Dictionary = {}      # seat -> Node3D reticle+tooltip marker

func set_putt_preview(seat: int, node_id: int, color: Color) -> void:
	if node_id < 0 or node_id >= nodes.size():
		return
	var marker: Node3D
	if _preview.has(seat):
		marker = _preview[seat]
	else:
		marker = _make_preview_marker(color)
		add_child(marker)
		_preview[seat] = marker
	marker.visible = true
	marker.global_position = space_pos(node_id) + Vector3(0, 0.16, 0)
	var tip := marker.get_node(^"Tip") as Label3D
	if tip != null:
		var t := type_at(node_id)
		tip.text = "%s · %s" % [S.display_name(t), S.rule(t)]
		tip.modulate = color.lerp(Color.WHITE, 0.25)
		tip.position = Vector3(0, 3.9 + 0.5 * float(seat), 0)

func clear_putt_preview(seat: int) -> void:
	if _preview.has(seat):
		(_preview[seat] as Node3D).visible = false

func clear_all_putt_previews() -> void:
	for seat in _preview:
		(_preview[seat] as Node3D).visible = false

func _make_preview_marker(color: Color) -> Node3D:
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.12
	tm.outer_radius = 1.34
	tm.rings = 6
	tm.ring_segments = 24
	ring.mesh = tm
	ring.material_override = _emissive(color, 4.5)
	ring.rotation_degrees.x = 90.0
	root.add_child(ring)
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.10
	bm.bottom_radius = 0.20
	bm.height = 3.2
	beam.mesh = bm
	var bmat := _emissive(color, 2.4)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(color.r, color.g, color.b, 0.28)
	beam.material_override = bmat
	beam.position = Vector3(0, 1.6, 0)
	root.add_child(beam)
	var chev := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.0
	cm.height = 0.5
	chev.mesh = cm
	chev.material_override = _emissive(color, 4.0)
	chev.position = Vector3(0, 3.2, 0)
	root.add_child(chev)
	var tip := Label3D.new()
	tip.name = "Tip"
	tip.font_size = 48
	tip.pixel_size = 0.0062
	tip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tip.no_depth_test = true
	tip.outline_size = 14
	tip.outline_modulate = Color(0, 0, 0, 0.92)
	tip.modulate = color
	tip.position = Vector3(0, 3.9, 0)
	root.add_child(tip)
	return root

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.albedo_color = color
	return m

# --------------------------------------------------------------------------
# CAMERA ANCHORS (the ring's shot vocabulary, re-derived per node)
# --------------------------------------------------------------------------
## Outward for shots: away from the centreline, perpendicular to travel.
func _shot_out(node_id: int) -> Vector3:
	var out := _outward(node_id)
	return out if out.length() > 0.01 else Vector3.BACK

func reveal_anchor(node_id: int) -> Vector3:
	var p := space_pos(node_id)
	return p + _shot_out(node_id) * 4.2 + Vector3(0, 3.4, 0)

## Type-aware landing framing (doc 24 F3), graph edition. {pos, look}.
func reveal_shot(node_id: int, type: String) -> Dictionary:
	var p := space_pos(node_id)
	var out := _shot_out(node_id)
	match type:
		S.OPEN_GRAVE:
			return {"pos": p + out * 2.7 + Vector3(0, 1.2, 0),
				"look": p + out * 0.9 + Vector3(0, 1.4, 0)}
		S.OFFERING:
			return {"pos": p + out * 3.2 + Vector3(0, 2.6, 0),
				"look": p + Vector3(0, 0.9, 0)}
		S.SEANCE:
			return {"pos": p + out * 3.0 + Vector3(0, 3.2, 0),
				"look": p + out * 1.0 + Vector3(0, 0.2, 0)}
		S.FERRY_TOLL:
			# Low through the toll arch, the flow of travel in frame.
			return {"pos": p - _flow_dir(node_id) * 3.6 + Vector3(0, 1.7, 0),
				"look": p + Vector3(0, 1.5, 0)}
		S.CART:
			return {"pos": p + out * 3.6 + Vector3(0, 2.0, 0),
				"look": p + out * 1.4 + Vector3(0, 1.1, 0)}
		S.GATE:
			# Hero low angle into the gate's warm glow — the arrival shot.
			return {"pos": p - _flow_at_gate() * 4.4 + Vector3(0, 2.2, 0),
				"look": p + Vector3(0, 2.0, 0)}
		_:
			return {"pos": p + out * 3.4 + Vector3(0, 2.8, 0),
				"look": p + Vector3(0, 0.7, 0)}

func _flow_at_gate() -> Vector3:
	var v := gate_pos() - CENTER
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.BACK
