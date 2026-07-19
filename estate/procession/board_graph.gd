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

# ---- ZF WAVE (P3): the doc-28 §4/§10-11 hero set, forged 2026-07-18 (tools/
# meshy_forge_report.json "procession" entries). Statics scale by AABB via
# _prop; RIGGED NPCs must use their NATIVE rig heights (a skinned export's
# mesh AABB reads ~1/100 — meshy_forge_report note), via _rigged_npc below.
const ZF_LYCHGATE := GEN_DIR + "lychgate.glb"
const ZF_MANORGATE := GEN_DIR + "manor_gate.glb"
const ZF_CART := GEN_DIR + "peddlers_cart.glb"
const ZF_SHRINE := GEN_DIR + "checkpoint_shrine.glb"
const ZF_CHEST := GEN_DIR + "grave_goods_chest.glb"
const ZF_SKIFF := GEN_DIR + "ferryman_skiff.glb"
const ZF_FERRYMAN := GEN_DIR + "npc_ferryman_idle.glb"      # native 1.85m
const ZF_GRAVEDIGGER := GEN_DIR + "npc_gravedigger_idle.glb" # native 1.7m
const ZF_WIDOW := GEN_DIR + "npc_widow_idle.glb"             # native 1.6m
const ZF_REAPER_BASE := GEN_DIR + "npc_reaper.glb"           # the standing sculpt — dormant
const ZF_SCYTHE := GEN_DIR + "reaper_scythe.glb"             # forged separately (hand-parent later)
## THE REAPER's dormant post — the far graveyard edge beyond Weeping Valley,
## outside every route bulge, barely lit. He activates in a future Estate
## Stirs lane; tonight he is just... present.
const REAPER_POST := Vector3(-25.0, 0.0, -13.0)

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
## [{node, route, label, color, blurb, left}] — left = stones to the gate if
## you STAY on that road (switching again at the next fork is your business;
## the signpost quotes each road's own length, so personalities read true).
func branch_options(fork_id: int) -> Array:
	var out: Array = []
	for nx in next_of(fork_id):
		var tag := route_of(int(nx))
		var ri := route_info(tag)
		out.append({"node": int(nx), "route": tag, "label": String(ri.label),
			"color": ri.color, "blurb": String(ri.get("blurb", "")),
			"left": _stay_route_dist(int(nx), tag)})
	return out

## Stones to the gate from `node` (inclusive of stepping onto it), keeping to
## route `tag` at any later fork. Pure graph walk — no rng.
func _stay_route_dist(node: int, tag: String) -> int:
	var steps := 1          # stepping onto `node` is the first stone
	var cur := node
	var guard := nodes.size() + 4
	while guard > 0 and not next_of(cur).is_empty():
		guard -= 1
		var nxt := next_of(cur)
		var step := int(nxt[0])
		if nxt.size() > 1:
			for nx in nxt:
				if route_of(int(nx)) == tag:
					step = int(nx)
					break
		cur = step
		steps += 1
	return steps

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
## in the dark. THE A-LOOK dims the route tint to near-subliminal — route
## IDENTITY lives in THE DRIVE minimap; the world stays dark and moody, the
## ribbon just a faint darker seam of a path underfoot.
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
			mat.albedo_color = Color(0.105, 0.11, 0.13).lerp(rcol, 0.05)
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
	# THE A-LOOK (doc 28 §0a de-neon, producer-approved mockup A). Dark stone puck
	# — the footing you land on. Colour identity now lives in a FLAT ground
	# surround inlaid in the lawn AROUND the stone, never an upright neon rim.
	var s := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.86 if typed else 0.6
	mesh.bottom_radius = 0.98 if typed else 0.7
	mesh.height = 0.18
	s.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.115, 0.14).lerp(col, 0.10)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.05
	mat.roughness = 0.92
	s.material_override = mat
	add_child(s)
	s.global_position = pos
	stone_nodes.append(s)
	# GROUND SURROUND: the rim TorusMesh laid FLAT (no x-rotation — that rotation
	# is exactly what stood the old rims up into "arches"). Space-type tint kept
	# but SUBTLE + AGX-friendly: path stones are a near-neutral whisper, specials
	# a touch stronger and carry a RING PATTERN so the type reads with ZERO
	# English (the interim colour-blind read until the C-props lane lands).
	var s_inner := 1.02 if typed else 0.72
	var s_outer := 1.20 if typed else 0.86
	var s_emit := 1.30 if typed else 0.14
	_ground_ring(pos, col, s_inner, s_outer, s_emit)
	if typed:
		_inlay_pool(pos, col, s_inner - 0.06, 0.5)
		_ring_pattern(pos, type, col, s_inner, s_outer)

## A single flat emissive ground ring inlaid in the lawn (TorusMesh lies in XZ
## by default — NEVER x-rotated, which is what made the old rims stand upright).
func _ground_ring(pos: Vector3, col: Color, inner: float, outer: float, emit: float,
		segments := 40) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 6
	tm.ring_segments = segments
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col.darkened(0.4)
	rmat.emission_enabled = true
	rmat.emission = col
	rmat.emission_energy_multiplier = emit
	rmat.roughness = 0.6
	ring.material_override = rmat
	add_child(ring)
	ring.global_position = pos + Vector3(0, 0.05, 0)

## A soft round emissive pool inside a special's surround so it reads as a lit
## inlay, not a bare hoop. Emission low — a glow field, never a lamp.
func _inlay_pool(pos: Vector3, col: Color, radius: float, emit: float) -> void:
	var d := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.012
	cm.radial_segments = 36
	d.mesh = cm
	var dmat := StandardMaterial3D.new()
	dmat.emission_enabled = true
	dmat.emission = col
	dmat.emission_energy_multiplier = emit
	dmat.albedo_color = col.darkened(0.6)
	dmat.roughness = 0.7
	d.material_override = dmat
	add_child(d)
	d.global_position = pos + Vector3(0, 0.035, 0)

## RING PATTERN per special type — the colour-blind-safe read (ZERO-ENGLISH law,
## doc 28 §0a) until the C-props lane gives each stone its own object. Cheap
## accent geometry on the flat surround:
##   offering = SOLID (clean ring)       · seance = DASHED (beaded ring)
##   grave_goods = DOUBLE (twin ring)    · open_grave = NOTCHED (radial ticks)
##   ferry_toll = GATED (two cross-bars) · crossroads = SPOKED
##   cart / gate = SOLID (each already unmistakable by its hero prop + light).
func _ring_pattern(pos: Vector3, type: String, col: Color, inner: float, outer: float) -> void:
	var mid := (inner + outer) * 0.5
	match type:
		S.SEANCE:
			_ring_dashes(pos, col, mid, 12)
		S.GRAVE_GOODS:
			_ground_ring(pos, col, inner - 0.26, outer - 0.26, 1.1, 32)
		S.OPEN_GRAVE:
			_ring_notches(pos, col, inner, outer, 6)
		S.FERRY_TOLL:
			_ring_gate_bars(pos, col, mid)
		S.CROSSROADS:
			_ring_spokes(pos, col, inner)
		_:
			pass   # offering / cart / gate: the clean solid ring

func _accent_mat(col: Color, emit: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = emit
	m.albedo_color = col.darkened(0.3)
	m.roughness = 0.55
	return m

func _accent_box(pos: Vector3, size: Vector3, yaw: float, mat: StandardMaterial3D) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	b.mesh = bm
	b.material_override = mat
	add_child(b)
	b.global_position = pos
	b.rotation.y = yaw

## DASHED: bright beads spaced evenly around the surround (séance).
func _ring_dashes(pos: Vector3, col: Color, radius: float, count: int) -> void:
	var mat := _accent_mat(col, 1.6)
	for k in count:
		var a := TAU * float(k) / float(count)
		_accent_box(pos + Vector3(cos(a) * radius, 0.055, sin(a) * radius),
			Vector3(0.15, 0.03, 0.10), -a, mat)

## NOTCHED: radial tick bars crossing the ring (open grave).
func _ring_notches(pos: Vector3, col: Color, inner: float, outer: float, count: int) -> void:
	var mid := (inner + outer) * 0.5
	var span := (outer - inner) + 0.20
	var mat := _accent_mat(col, 1.8)
	for k in count:
		var a := TAU * float(k) / float(count) + 0.26
		_accent_box(pos + Vector3(cos(a) * mid, 0.055, sin(a) * mid),
			Vector3(0.09, 0.035, span), -a, mat)

## GATED: two cross-bars straddling the surround — a toll gate laid flat (ferry).
func _ring_gate_bars(pos: Vector3, col: Color, radius: float) -> void:
	var mat := _accent_mat(col, 1.7)
	for sgn in [-1.0, 1.0]:
		_accent_box(pos + Vector3(0, 0.06, sgn * radius),
			Vector3(0.72, 0.045, 0.12), 0.0, mat)

## SPOKED: four short spokes reaching toward the centre — a crossroads.
func _ring_spokes(pos: Vector3, col: Color, inner: float) -> void:
	var mat := _accent_mat(col, 1.5)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.79
		_accent_box(pos + Vector3(cos(a) * inner * 0.5, 0.055, sin(a) * inner * 0.5),
			Vector3(0.08, 0.035, inner * 0.7), -a, mat)

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
	var ferry_dressed := false
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
				# ZF: the grave-goods chest, scaled small — a coffer, not a crate.
				_place(_prop(ZF_CHEST, FB_CRATE, 0.55), here + out * 1.1 + Vector3(0, 0.06, 0))
				_place(_prop(FB_LANTERN, FB_LANTERN, 1.5), here + out * 1.15 + Vector3(0.7, 0.06, 0.2))
			S.SEANCE:
				_place(_prop(GEN_PLANCHETTE, FB_LANTERN, 0.35), here + out * 1.05 + Vector3(0, 0.06, 0))
			S.FERRY_TOLL:
				_place_facing(_prop(GEN_TOLLARCH, FB_TOLLARCH, 3.4), here + Vector3(0, 0.06, 0),
					here + _flow_dir(i) * 4.0)
				# ZF: THE FERRYMAN and his skiff hold the valley toll (first one only —
				# one ferryman works this river; further tolls keep the bare arch).
				if not ferry_dressed and route_of(i) == "valley":
					ferry_dressed = true
					var moor := here + out * 2.7 + Vector3(0, 0.02, 0)
					_place_facing(_prop(ZF_SKIFF, FB_CRATE, 0.8), moor, moor + _flow_dir(i) * 4.0)
					_place_facing(_rigged_npc(ZF_FERRYMAN, 1.85, 1.85),
						here + out * 1.8 + Vector3(0, 0.04, 0), here)
			S.CART:
				# ZF: the hearse-drawn Peddler's Cart replaces the ring-era hearse.
				_place_facing(_prop(ZF_CART, FB_HEARSE, 2.4), here + out * 1.6 + Vector3(0, 0.06, 0), here)
				_place(_prop(FB_LANTERN, FB_LANTERN, 1.5), here + out * 2.3 + Vector3(0.5, 0.06, 0.3))
			S.CROSSROADS:
				_place(_prop(GEN_SIGNPOST, FB_LANTERN, 2.6), here + out * 1.4 + Vector3(0, 0.06, 0))
				# ZF: a checkpoint shrine marks each crossroads landmark, opposite the post.
				_place(_prop(ZF_SHRINE, FB_LANTERN, 2.5), here - out * 1.6 + Vector3(0, 0.06, 0))
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
	# ZF: the merge landmark gets its own shrine — the roads reunite in prayer.
	var mg := int((graph.landmarks as Dictionary).merge)
	_place(_prop(ZF_SHRINE, FB_LANTERN, 2.5),
		space_pos(mg) + _outward(mg) * 1.8 + Vector3(0, 0.06, 0))
	_build_lychgate()
	_build_manor_gate()
	_build_npc_troupe()
	_build_perimeter()

## ZF NPC troupe (doc 28 §10 — one beat each, never a cutscene). THE GRAVEDIGGER
## idles by the Hollow Woods; THE WIDOW mourns along Garden Row. THE REAPER is
## placed DORMANT and DISTANT — looming motionless at the far graveyard edge,
## barely lit. He activates in a future Estate Stirs lane; tonight he is
## just... present. All rigged instancing uses NATIVE heights (forge report).
func _build_npc_troupe() -> void:
	var dig_id := _route_mid_id("hollow")
	_place_facing(_rigged_npc(ZF_GRAVEDIGGER, 1.7, 1.7),
		space_pos(dig_id) + _outward(dig_id) * 3.2 + Vector3(0, 0.04, 0), space_pos(dig_id))
	var wid_id := _route_mid_id("garden")
	_place_facing(_rigged_npc(ZF_WIDOW, 1.6, 1.6),
		space_pos(wid_id) + _outward(wid_id) * 3.0 + Vector3(0, 0.04, 0), space_pos(wid_id))
	# THE REAPER — the standing sculpt, motionless at the graveyard's edge,
	# facing across the valley toward the gate; his scythe planted beside him.
	if ResourceLoader.exists(ZF_REAPER_BASE):
		_place_facing(_prop(ZF_REAPER_BASE, FB_COLUMN, 4.1),
			REAPER_POST, gate_pos() + Vector3(0, 0.0, 4.0))
		_place(_prop(ZF_SCYTHE, FB_LANTERN, 3.6), REAPER_POST + Vector3(1.4, 0.0, 0.6))
		# Barely lit: one faint, sickly pool so the silhouette reads at distance —
		# never a hero light. (Existing kit only; shadows off, tight range.)
		var pall := OmniLight3D.new()
		pall.name = "ReaperPall"
		pall.light_color = Color(0.52, 0.72, 0.62)
		pall.light_energy = 0.5
		pall.omni_range = 7.0
		pall.shadow_enabled = false
		add_child(pall)
		pall.global_position = REAPER_POST + Vector3(0.6, 3.2, 0.6)

## The node id at the middle of a route's first half (placement anchor).
func _route_mid_id(tag: String) -> int:
	var start := int((graph.half_a_start as Dictionary).get(tag, 0))
	return start + int(route_info(tag).get("half_a", 1)) / 2

## Instance a RIGGED Meshy NPC by its native rig height (never the AABB — a
## skinned export's AABB reads ~1/100). `frozen` plays the first clip's first
## frame and stops there (the dormant Reaper); otherwise the clip loops (idle
## NPCs). Returns an empty wrapper when the asset is missing (fresh checkout).
func _rigged_npc(path: String, native_h: float, target_h: float, frozen := false) -> Node3D:
	if not ResourceLoader.exists(path):
		return Node3D.new()
	var npc := MeshyProp.instance_rigged(path, native_h, target_h, 0.0, not frozen)
	if frozen:
		var anim: AnimationPlayer = npc.find_child("AnimationPlayer", true, false)
		if anim != null and anim.get_animation_list().size() > 0:
			anim.play(String(anim.get_animation_list()[0]))
			anim.seek(0.0, true)
			anim.speed_scale = 0.0   # motionless — dormant until the Estate Stirs
	return npc

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

## THE LYCHGATE — the start: the ZF covered lychgate over the first stone, the
## hearse waiting beside it, a crooked signpost pointing up the road.
func _build_lychgate() -> void:
	var start := lychgate_pos()
	var flow := _flow_dir(0)
	_place_facing(_prop(ZF_LYCHGATE, FB_TOLLARCH, 4.4), start + Vector3(0, 0.06, 0), start + flow * 6.0)
	_place_facing(_prop(GEN_HEARSE, FB_HEARSE, 2.1), start + Vector3(-3.0, 0.06, 1.2), start)
	_place(_prop(GEN_SIGNPOST, FB_LANTERN, 2.6), start + Vector3(2.6, 0.06, 0.6))
	# A-LOOK / ZERO-ENGLISH: the covered lychgate arch + hearse + signpost ARE
	# the read — no floating "THE LYCHGATE" caption. (The pawns start here; the
	# name never needs to surface.)

## THE MANOR GATE — the finish: the ZF grand arch, warm light, the bell's home.
func _build_manor_gate() -> void:
	var gate := gate_pos()
	var back := (gate - CENTER)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	_place_facing(_prop(ZF_MANORGATE, FB_TOLLARCH, 5.6), gate + back * 1.4 + Vector3(0, 0.06, 0), CENTER)
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
	# A-LOOK / ZERO-ENGLISH: the grand arch + the one warm gold pool on the
	# grounds ARE the beacon — no floating "THE MANOR GATE" caption. Its name
	# surfaces only on ARRIVAL, via the travelling pawn's landing label.

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
# PAWNS + MOVEMENT — FIGURINE PAWNS (P3, producer-locked, doc 28 §11 option b):
# NOT walking mini-people. Toy-style figurines of the four characters, built
# in-engine from each roster seat's character scene, frozen in a sculpt pose,
# mounted on a round seat-coloured base with a slight ceramic glaze. They HOP
# stone-to-stone with a dry woody clack. The fiction stays clean: you play a
# board game ABOUT them while the characters heckle from the grounds.
# --------------------------------------------------------------------------
const FIGURINE_SCALE := 0.56       # KayKit adventurer -> toy read on a 0.86r stone
const FIGURINE_POSE_T := 0.35      # freeze the Idle a beat in: a stance, not a T-pose
const BASE_H := 0.10               # the round base's height (figurine feet sit here)

func _make_pawn(pl: Dictionary) -> Node3D:
	var root := Node3D.new()
	var col: Color = pl.color
	# --- the round base: dark glazed puck + a seat-coloured emissive rim ---
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.34
	bm.bottom_radius = 0.38
	bm.height = BASE_H
	base.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.13, 0.125, 0.16).lerp(col, 0.10)
	bmat.roughness = 0.22
	bmat.metallic = 0.15
	base.material_override = bmat
	base.position.y = BASE_H * 0.5
	root.add_child(base)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.30
	tm.outer_radius = 0.38
	tm.rings = 6
	tm.ring_segments = 24
	rim.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col.darkened(0.15)
	rmat.emission_enabled = true
	rmat.emission = col
	rmat.emission_energy_multiplier = 1.7
	rmat.roughness = 0.35
	rim.material_override = rmat
	rim.rotation_degrees.x = 90.0
	rim.position.y = BASE_H * 0.7
	root.add_child(rim)
	# --- the figurine: the seat's real character mesh, frozen mid-idle ---
	var fig := _make_figurine(pl)
	fig.position.y = BASE_H
	root.add_child(fig)
	var tag := Label3D.new()
	tag.text = "%s %s" % [PlayerBadge.glyph(int(pl.index)), String(pl.name)]
	tag.font_size = 42
	tag.pixel_size = 0.007
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = col
	tag.outline_size = 10
	tag.position.y = 1.5
	root.add_child(tag)
	return root

## The sculpt: instance the seat's character scene, freeze its Idle a beat in
## (play + seek + speed 0 — a pose, never a performance), glaze every mesh,
## and carry the seat's wardrobe cosmetics onto the toy (hats ride skeletons,
## so the frozen pose seats them correctly). Fallback: the old capsule, so a
## missing character asset can never break a fresh checkout.
func _make_figurine(pl: Dictionary) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = "Figurine"
	var path := String(pl.get("char_scene", ""))
	if path == "" or not ResourceLoader.exists(path):
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 1.0
		body.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = pl.color
		mat.emission_enabled = true
		mat.emission = Color(pl.color) * 0.4
		body.material_override = mat
		body.position.y = 0.52
		wrap.add_child(body)
		return wrap
	var scene: PackedScene = load(path)
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * FIGURINE_SCALE
	wrap.add_child(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim != null:
		var pose := ""
		for cand in ["Idle", "Idle_A", "Cheer"]:
			if anim.has_animation(cand):
				pose = cand
				break
		if pose == "" and anim.get_animation_list().size() > 0:
			pose = String(anim.get_animation_list()[0])
		if pose != "":
			anim.play(pose)
			anim.seek(FIGURINE_POSE_T, true)
			anim.speed_scale = 0.0   # frozen: a figurine, not an actor
	Cosmetics.apply_to_character(wrap, int(pl.get("index", 0)))
	_apply_glaze(wrap)
	return wrap

## A slight ceramic/glaze feel: every mesh gets a translucent glossy overlay
## pass (rim-lit, low alpha) so the toys read as fired + painted under MOONLIT.
static func _apply_glaze(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		(node as MeshInstance3D).material_overlay = _glaze_material()
	for c in node.get_children():
		_apply_glaze(c)

static func _glaze_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.07)
	m.metallic = 0.55
	m.roughness = 0.16
	m.rim_enabled = true
	m.rim = 0.45
	m.rim_tint = 0.35
	return m

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
		# The figurine's clack: dry and woody (house bank, no new asset) — a toy
		# base knocking on stone, not a card flip.
		tw.tween_callback(Sfx.play.bind("impact_wood", -13.0, 0.2))
	return tw

# --------------------------------------------------------------------------
# AIM HEATMAP (P2 → THE A-LOOK, doc 28 §0a/§15 — the legibility flagship, now
# ZERO-ENGLISH). While the active seat's LAST BREATH needle sweeps, the
# reachable stones down their road glow with the LIVE landing probability —
# expressed as RING BRIGHTNESS, never a percent. The candidate ring SHARES the
# stone's ground surround: type keeps the HUE, heat modulates only the
# INTENSITY (likelier = brighter), breathing gently with the sweep. A crit-band
# release in prospect sharpens the contrast (brightest brighten, dimmest dim).
# Pure presentation: a pooled marker set fed by procession each few frames;
# never draws rng, never touches generate() (the topology receipt cannot move).
# --------------------------------------------------------------------------
var _heat_markers: Array = []      # pooled {root, ring, ring_mat} dicts

## entries: [{node, face, p, w}] — p = probability 0..1, w = p normalized to
## the max face (brightness). Duplicate nodes merge (walks clamp at the gate).
## `crit` = the needle currently sits in this roll's crit band (sharpen).
func show_heatmap(entries: Array, _seat_color: Color, crit := false) -> void:
	var by_node := {}
	for e in entries:
		var d := e as Dictionary
		var n := int(d.node)
		if by_node.has(n):
			by_node[n].p += float(d.p)
			by_node[n].w = maxf(float(by_node[n].w), float(d.w))
		else:
			by_node[n] = {"p": float(d.p), "w": float(d.w)}
	var keys: Array = by_node.keys()
	keys.sort()
	while _heat_markers.size() < keys.size():
		_heat_markers.append(_make_heat_marker())
	# A gentle shared pulse so the candidate rings breathe with the sweep.
	var pulse := 0.86 + 0.14 * sin(float(Time.get_ticks_msec()) * 0.006)
	var contrast := 2.1 if crit else 1.15
	var k := 0
	for n in keys:
		var m: Dictionary = _heat_markers[k]
		var w := clampf(float(by_node[n].w), 0.0, 1.0)
		# CRIT sharpens: push each candidate's brightness away from the midpoint.
		var wd := clampf(0.5 + (w - 0.5) * contrast, 0.0, 1.0)
		# TYPE keeps the HUE (path stones read neutral); heat = INTENSITY only.
		var hue: Color = S.color(type_at(int(n)))
		var root := m.root as Node3D
		root.visible = true
		root.global_position = space_pos(int(n)) + Vector3(0, 0.065, 0)
		var mat := m.ring_mat as StandardMaterial3D
		mat.emission = hue
		mat.emission_energy_multiplier = (0.30 + 3.6 * wd) * pulse
		mat.albedo_color = Color(hue.r, hue.g, hue.b, 0.22 + 0.5 * wd)
		k += 1
	for i in range(k, _heat_markers.size()):
		(_heat_markers[i].root as Node3D).visible = false

func clear_heatmap() -> void:
	for m in _heat_markers:
		(m.root as Node3D).visible = false

# --------------------------------------------------------------------------
# CONTEXTUAL NAME LABELS (ZERO-ENGLISH law, doc 28 §0a). The board carries NO
# always-on space-name text. A space's NAME surfaces only where a decision
# needs it: the stone a travelling pawn will LAND on (show_landing_label,
# driven by procession as the toy hops), and any special stone a walkabout
# stroller comes within ~2 stones of (reveal_names_near, driven by the estate
# hub). Crossroads names live in the 2D crossroads prompt. Path stones stay
# nameless — a merciful administrative error needs no caption.
# --------------------------------------------------------------------------
var _landing_label: Label3D = null
var _approach_labels := {}          # node_id -> Label3D (walkabout approach pool)

func _name_label(font := 44, pixel := 0.0062) -> Label3D:
	var l := Label3D.new()
	l.font_size = font
	l.pixel_size = pixel
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.no_depth_test = true
	return l

## The travelling pawn's destination names itself while the toy hops toward it
## (the ONE label a normal turn shows). Path stones stay quiet. col tints the
## text to the mover's seat colour.
func show_landing_label(node_id: int, col: Color) -> void:
	if node_id < 0 or node_id >= nodes.size():
		return
	if _landing_label == null:
		_landing_label = _name_label()
		add_child(_landing_label)
	var t := type_at(node_id)
	if t == S.BLANK:
		_landing_label.visible = false
		return
	_landing_label.text = S.display_name(t)
	_landing_label.modulate = col.lerp(Color.WHITE, 0.25)
	_landing_label.position = space_pos(node_id) + Vector3(0, 1.15, 0)
	_landing_label.visible = true

func clear_landing_label() -> void:
	if _landing_label != null:
		_landing_label.visible = false

## Walkabout approach-reveal: name every SPECIAL stone whose position is within
## `radius` metres of `world_pos` (≈2 stones at the graph's ~2.2m spacing),
## hide the rest. The estate walkabout hub calls this each frame with the
## stroller's ground position; the board stays wordless until a character walks
## up to a stone. Pooled + idempotent — safe to call every frame.
func reveal_names_near(world_pos: Vector3, radius := 6.0) -> void:
	for n in nodes:
		var i := int(n.id)
		var t := String(n.type)
		if t == S.BLANK:
			continue
		var near := space_pos(i).distance_to(world_pos) <= radius
		if near and not _approach_labels.has(i):
			var l := _name_label(38, 0.0056)
			l.text = S.display_name(t)
			l.modulate = S.color(t).lerp(Color.WHITE, 0.2)
			l.position = space_pos(i) + Vector3(0, 1.0, 0)
			add_child(l)
			_approach_labels[i] = l
		elif not near and _approach_labels.has(i):
			(_approach_labels[i] as Label3D).queue_free()
			_approach_labels.erase(i)

func clear_approach_names() -> void:
	for i in _approach_labels.keys():
		(_approach_labels[i] as Label3D).queue_free()
	_approach_labels.clear()

# --------------------------------------------------------------------------
# WREATH OF DEBT markers (P2 cart item): an owner-coloured coin ring on the
# trapped stone — announced sabotage is VISIBLE sabotage (Pro Rules).
# --------------------------------------------------------------------------
var _debt_markers := {}            # node_id -> Node3D

func set_debt_marker(node_id: int, color: Color) -> void:
	clear_debt_marker(node_id)
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.52
	tm.outer_radius = 0.70
	tm.rings = 6
	tm.ring_segments = 20
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.6
	mat.albedo_color = color
	ring.material_override = mat
	ring.rotation_degrees.x = 90.0
	root.add_child(ring)
	var tag := Label3D.new()
	tag.text = "DEBT"
	tag.font_size = 34
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 10
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.modulate = color.lerp(Color.WHITE, 0.25)
	tag.position = Vector3(0, 0.55, 0)
	root.add_child(tag)
	add_child(root)
	root.global_position = space_pos(node_id) + Vector3(0, 0.16, 0)
	_debt_markers[node_id] = root

func clear_debt_marker(node_id: int) -> void:
	if _debt_markers.has(node_id):
		(_debt_markers[node_id] as Node3D).queue_free()
		_debt_markers.erase(node_id)

func clear_all_debt_markers() -> void:
	for n in _debt_markers.keys():
		clear_debt_marker(int(n))

func _make_heat_marker() -> Dictionary:
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.04
	tm.outer_radius = 1.26
	tm.rings = 6
	tm.ring_segments = 32
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.42)
	mat.emission_energy_multiplier = 1.0
	mat.albedo_color = Color(1.0, 0.85, 0.42, 0.4)
	ring.material_override = mat
	# FLAT — shares the stone's ground surround (no x-rotation). The BRIGHTNESS
	# is the whole read now; there is no percent label. (ZERO-ENGLISH law.)
	root.add_child(ring)
	add_child(root)
	root.visible = false
	return {"root": root, "ring": ring, "ring_mat": mat}

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
