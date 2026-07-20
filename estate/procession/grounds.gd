class_name ProcessionGrounds
extends Node3D
## THE GROUNDS (doc 33, G1) — the world-first inversion. This node owns the
## LAND: sculpted terrain, the water, the authored path network with real
## surfaces (flagstone / gravel / grass / dirt / plank / causeway / cut stone),
## the hedge maze, the bridges, and the manor silhouette on its rise.
##
## The board does NOT lay the world out any more — the world was here first.
## Each path segment exports STATIONS (arc-length-even points along its
## authored spline, ≥2 stone-widths apart) and board_graph.generate() snaps
## its logical nodes onto them. Node ids, types, edges, and dist are untouched
## — only world positions moved — so the topology checksum (positions
## excluded) and every match receipt survive the inversion (doc 33 §3).
##
## Everything static here is PURE and deterministic (fixed-seed noise, no
## scene access), because generate() runs headless for --boardgraphtest.
## GROUNDS BAR (doc 28 §0a): no flat ground, no visible tiling, surfaces vary
## by place, integrated-GPU envelope — MultiMesh for every repeated element.

# --------------------------------------------------------------------------
# WORLD ANCHORS — south (+z) to north (-z): forecourt, lands, manor rise.
# --------------------------------------------------------------------------
const WATER_Y := -1.55             # the Weeping Valley's standing water
const BROOK_Y := -0.45             # the garden brook's surface
const PLANK_Y := -1.05             # boardwalk deck over the bog water
const TERRAIN_SEED := 33771       # doc 33's own stream — never the night seed

# --------------------------------------------------------------------------
# PATH SEGMENTS — authored control polylines (xz; y is sampled from the land).
# Surface spans are control-point index ranges. THE MAZE IS THE PATH: the
# garden_a points walk the true solution of the hedge maze (grid below).
# --------------------------------------------------------------------------
const SEGS := {
	"approach": {
		"pts": [Vector2(0, 38), Vector2(0, 31), Vector2(0, 24)],
		"surf": [[0, 2, "flagstone"]],
	},
	"garden_a": {
		# Guide points at (24.25, 19.9) and (37.75, -15.9) steer the spline
		# square THROUGH the mouth and the far door — without them the
		# catmull-rom cut the corner through the boundary hedge (producer
		# catch, live jam night 2).
		"pts": [Vector2(0, 24), Vector2(8, 22.5), Vector2(16, 20),
			Vector2(24.25, 19.9),
			Vector2(24.25, 15.25), Vector2(28.75, 15.25), Vector2(33.25, 15.25),
			Vector2(33.25, 10.75), Vector2(33.25, 6.25), Vector2(28.75, 6.25),
			Vector2(28.75, 1.75), Vector2(28.75, -2.75), Vector2(33.25, -2.75),
			Vector2(37.75, -2.75), Vector2(37.75, -7.25), Vector2(37.75, -11.75),
			Vector2(37.75, -15.9),
			Vector2(30, -16.2), Vector2(21, -15.0), Vector2(12, -12.8), Vector2(0, -16)],
		"surf": [[0, 4, "gravel"], [4, 15, "grass"], [15, 20, "gravel"]],
	},
	"garden_b": {
		"pts": [Vector2(0, -16), Vector2(12, -18), Vector2(25, -20),
			Vector2(34, -23), Vector2(38, -30), Vector2(34, -37),
			Vector2(28, -40), Vector2(22, -43), Vector2(12, -45), Vector2(0, -42)],
		"surf": [[0, 6, "gravel"], [6, 7, "bridge"], [7, 9, "gravel"]],
	},
	"hollow_a": {
		"pts": [Vector2(0, 24), Vector2(-7, 19), Vector2(-14, 15),
			Vector2(-9, 9), Vector2(-16, 3), Vector2(-9, -2),
			Vector2(-15, -8), Vector2(-6, -12), Vector2(0, -16)],
		"surf": [[0, 8, "dirt"]],
	},
	"hollow_b": {
		"pts": [Vector2(0, -16), Vector2(-7, -20), Vector2(-4, -26),
			Vector2(-11, -30), Vector2(-7, -36), Vector2(-2, -39), Vector2(0, -42)],
		"surf": [[0, 6, "dirt"]],
	},
	"valley_a": {
		# the tail arcs to enter the crossroads from its NORTH face — the
		# fork's grammar (producer, live jam 2): arrivals from the north,
		# departures from the south, so the junction never reads as an X
		"pts": [Vector2(0, 24), Vector2(-12, 22), Vector2(-24, 20),
			Vector2(-33, 15), Vector2(-38, 7), Vector2(-40, -2),
			Vector2(-36, -9), Vector2(-24, -13.5), Vector2(-11, -14), Vector2(0, -16)],
		"surf": [[0, 3, "causeway"], [3, 6, "plank"], [6, 9, "causeway"]],
	},
	"valley_b": {
		# the lobe crossing is BOARDWALK — the bone bridge is not a road
		# piece: it is the dormant Estate Stirs bypass (doc 28 §4 major 2),
		# sunken in the pond until its night comes
		"pts": [Vector2(0, -16), Vector2(-12, -19), Vector2(-24, -22),
			Vector2(-31, -26), Vector2(-30, -33), Vector2(-24, -37),
			Vector2(-16, -40), Vector2(-8, -42), Vector2(0, -42)],
		"surf": [[0, 3, "causeway"], [3, 4, "plank"], [4, 8, "causeway"]],
	},
	"homestretch": {
		"pts": [Vector2(0, -42), Vector2(0, -50), Vector2(0, -58)],
		"surf": [[0, 2, "road"]],
	},
}

## Landmark anchors = segment endpoints (kept explicit so a reader can see the
## geography without tracing splines).
const LYCH_XZ := Vector2(0, 38)
const FORK1_XZ := Vector2(0, 24)
const FORK2_XZ := Vector2(0, -16)
const MERGE_XZ := Vector2(0, -42)
const GATE_XZ := Vector2(0, -58)

## The garden brook — carved into the land, crossed once by garden_b's
## footbridge, ending in a reed pool at the rise's toe.
const BROOK := [Vector2(40, -34), Vector2(32, -39), Vector2(24, -42),
	Vector2(16, -44), Vector2(13.5, -44.5)]

# --------------------------------------------------------------------------
# THE HEDGE MAZE (Garden Row half a) — a 4x7 cell grid, 4.5u cells. The true
# path is garden_a's control points; every other cell is a dead-end branch so
# the block reads as a MAZE from the air and a green canyon from the couch.
# Walls are listed as OPEN pairs (everything not open is hedge).
# --------------------------------------------------------------------------
const MAZE_CELL := 4.5
const MAZE_COLS := 4
const MAZE_ROWS := 7
const MAZE_ORIGIN := Vector2(24.25, 15.25)   # cell (0,0) centre; +col=+x, +row=-z
## east-west openings "c,r" = open between (c,r) and (c+1,r)
const MAZE_OPEN_E := ["0,0", "1,0", "2,0", "1,2", "1,4", "2,4",
	"0,1", "1,3", "2,2", "0,6", "1,6", "1,5"]
## north-south openings "c,r" = open between (c,r) and (c,r+1)
## ("2,3" opens THE CART COURT — the dead-end cell beside the cart's station
## becomes a market clearing off the corridor; the hearse-cart hero parks IN
## it instead of clipping a hedge wall.)
const MAZE_OPEN_N := ["2,0", "2,1", "1,2", "1,3", "3,4", "3,5",
	"3,0", "1,0", "0,1", "0,2", "3,2", "1,4", "2,5", "0,4", "0,5", "2,3"]
const HEDGE_H := 1.85
const HEDGE_T := 1.0
const CART_COURT := Vector2(33.25, 1.75)   # cell (2,3)'s centre

## True when a ground point stands inside the maze block (apron included) —
## furniture placement asks before parking anything wide off a corridor.
static func in_maze(x: float, z: float) -> bool:
	return _maze_mask(x, z) > 0.55

# --------------------------------------------------------------------------
# TERRAIN — a pure authored height function. Features, in reading order: the
# universal unrest (no flat ground, ever), the forecourt table, the manor
# rise, the valley basin + the bone-bridge lobe, the brook cut, the levelled
# parterre around the maze.
# --------------------------------------------------------------------------
## Hand-rolled value noise — no FastNoiseLite Resource (a static Resource
## leaks + segfaults at headless exit), no engine-version dependence: the land
## is deterministic FOREVER, same doctrine as the LAYOUT stream.
static func _hash2(ix: int, iz: int, salt: int) -> float:
	var h := ix * 374761393 + iz * 668265263 + (TERRAIN_SEED + salt) * 1442695041
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 32768.0 - 1.0

static func _vnoise(x: float, z: float, salt: int) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - float(ix)
	var fz := z - float(iz)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	return lerpf(
		lerpf(_hash2(ix, iz, salt), _hash2(ix + 1, iz, salt), ux),
		lerpf(_hash2(ix, iz + 1, salt), _hash2(ix + 1, iz + 1, salt), ux), uz)

## broad land unrest (two octaves) · fine grain
static func _n1(x: float, z: float) -> float:
	return _vnoise(x * 0.045, z * 0.045, 11) * 0.72 \
		+ _vnoise(x * 0.094 + 37.0, z * 0.094, 23) * 0.28

static func _n2(x: float, z: float) -> float:
	return _vnoise(x * 0.13, z * 0.13, 47)

static func _ss(t: float) -> float:   # smootherstep 0..1
	var c := clampf(t, 0.0, 1.0)
	return c * c * c * (c * (c * 6.0 - 15.0) + 10.0)

static func height(x: float, z: float) -> float:
	var h := _n1(x, z) * 0.62 + _n2(x, z) * 0.22
	# the forecourt table (south) — the hub's future ground, gently raised
	h += 1.3 * _ss((z - 32.0) / 8.0)
	# the manor rise (north) — the finish visible from everywhere
	h += 5.0 * _ss((-z - 44.0) / 16.0)
	# the valley basin — water below path grade, drama for the boardwalk
	var bdx := (x + 34.0) / 13.0
	var bdz := (z + 6.0) / 22.0
	h += -3.0 * exp(-(bdx * bdx + bdz * bdz))
	# the bone-bridge lobe — the pond's dark southern arm
	var ldx := (x + 30.0) / 8.0
	var ldz := (z + 30.0) / 7.0
	h += -2.3 * exp(-(ldx * ldx + ldz * ldz))
	# the bypass channel — the deep the dormant bone bridge lies in (and will
	# someday span): guaranteed open water along the doc-33 claim line
	var cdx := (x + 39.0) / 5.0
	var cdz := (z + 13.0) / 6.5
	h += -1.5 * exp(-(cdx * cdx + cdz * cdz))
	# the brook cut
	var bd := _brook_dist(x, z)
	h += -1.15 * exp(-(bd * bd) / (2.1 * 2.1))
	# THE ROLLING ESTATE (tenth watch, producer pick): broad meadow swells
	# between the routes. Masked hard off the water table (basin/lobe/channel
	# keep their levels, the brook keeps its cut) and off the forecourt table
	# (the hub's furniture was surveyed against flat ground). Paths conform —
	# stations re-derive their y from here; xz never moves, so no receipt can.
	var swell := 1.05 + 0.95 * _vnoise(x * 0.021 + 91.0, z * 0.021, 71)
	var wet := exp(-(bdx * bdx + bdz * bdz)) + exp(-(ldx * ldx + ldz * ldz)) \
		+ exp(-(cdx * cdx + cdz * cdz))
	swell *= clampf(1.0 - 1.6 * wet, 0.0, 1.0) * _ss((bd - 2.2) / 3.2) \
		* (1.0 - _ss((z - 26.0) / 8.0))
	h += swell
	# the authored swells: a meadow rise east of the garden loop, a long low
	# ridge beyond the bog — the estate rolls toward its dark edges
	var mdx := (x - 45.0) / 10.0
	var mdz := (z - 6.0) / 16.0
	h += 2.2 * exp(-(mdx * mdx + mdz * mdz))
	var rdx := (x + 53.0) / 6.5
	var rdz := (z + 6.0) / 18.0
	h += 2.6 * exp(-(rdx * rdx + rdz * rdz))
	# the parterre level — hedges want tended ground (blend, never a slab)
	var flat := _maze_mask(x, z)
	h = lerpf(h, h * 0.30 + 0.25, flat)
	return h

static func _brook_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 999.0
	for i in BROOK.size() - 1:
		var a: Vector2 = BROOK[i]
		var b: Vector2 = BROOK[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

static func _maze_mask(x: float, z: float) -> float:
	# rounded-rect falloff around the maze block (+2u apron)
	var half_w := MAZE_COLS * MAZE_CELL * 0.5 + 2.0
	var half_h := MAZE_ROWS * MAZE_CELL * 0.5 + 2.0
	var cx := MAZE_ORIGIN.x - MAZE_CELL * 0.5 + MAZE_COLS * MAZE_CELL * 0.5
	var cz := MAZE_ORIGIN.y + MAZE_CELL * 0.5 - MAZE_ROWS * MAZE_CELL * 0.5
	var dx := maxf(absf(x - cx) - half_w, 0.0)
	var dz := maxf(absf(z - cz) - half_h, 0.0)
	return 1.0 - _ss(sqrt(dx * dx + dz * dz) / 6.0)

## True when this ground point stands under the valley's open water.
static func under_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_Y - 0.05

## Ground-snap: keep xz, resolve y from the land (+dy). The one helper every
## placement in the world goes through — nothing floats, nothing drowns.
static func snap(p: Vector3, dy := 0.0) -> Vector3:
	return Vector3(p.x, height(p.x, p.z) + dy, p.z)

# --------------------------------------------------------------------------
# SPLINES + STATIONS — centripetal-ish Catmull-Rom through the authored
# points, arc-length table, even stations. All static, all deterministic.
# --------------------------------------------------------------------------
static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## Sample the segment's spline into a dense polyline: [{p:Vector2, s:float,
## t01:float}] where s = cumulative arc length, t01 = control-point param
## (idx + frac) / (n-1) — surface spans key off t01.
static func sample_segment(tag: String, per_span := 14) -> Array:
	var pts: Array = (SEGS[tag] as Dictionary).pts
	var n := pts.size()
	var out: Array = []
	var s := 0.0
	var prev: Vector2 = pts[0]
	out.append({"p": prev, "s": 0.0, "t01": 0.0})
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for k in range(1, per_span + 1):
			var t := float(k) / float(per_span)
			var p := _cr(p0, p1, p2, p3, t)
			s += prev.distance_to(p)
			prev = p
			out.append({"p": p, "s": s, "t01": (float(i) + t) / float(n - 1)})
	return out

## Surface name at a segment param (t01 in control-point space).
static func surface_at(tag: String, t01: float) -> String:
	var pts: Array = (SEGS[tag] as Dictionary).pts
	var n1 := float(pts.size() - 1)
	for span in ((SEGS[tag] as Dictionary).surf as Array):
		if t01 >= float(span[0]) / n1 - 0.0001 and t01 <= float(span[1]) / n1 + 0.0001:
			return String(span[2])
	return "dirt"

## Deck-aware ground height for a point ON the path at param t01: plank spans
## ride the boardwalk, bridge spans arch bank-to-bank, everything else walks
## the land.
static func path_y(tag: String, t01: float, p: Vector2) -> float:
	var surf := surface_at(tag, t01)
	if surf == "plank":
		return PLANK_Y
	if surf == "bridge":
		var span := _span_of(tag, "bridge")
		var pts: Array = (SEGS[tag] as Dictionary).pts
		var n1 := float(pts.size() - 1)
		var a: Vector2 = pts[int(span[0])]
		var b: Vector2 = pts[int(span[1])]
		var tt := clampf((t01 - float(span[0]) / n1) / maxf(float(span[1] - span[0]) / n1, 0.001), 0.0, 1.0)
		var ya := height(a.x, a.y)
		var yb := height(b.x, b.y)
		return lerpf(ya, yb, tt) + 0.55 * sin(PI * tt) + 0.10
	if surf == "causeway":
		return maxf(height(p.x, p.y), WATER_Y + 0.35) + 0.10
	return height(p.x, p.y) + 0.02

static func _span_of(tag: String, surf: String) -> Array:
	for span in ((SEGS[tag] as Dictionary).surf as Array):
		if String(span[2]) == surf:
			return span
	return [0, 0, surf]

## n arc-length-even interior stations along a segment (endpoints excluded —
## they are the landmark nodes themselves). Returns Array[Vector3], y resolved
## deck-aware. THE STATION LAW: counts come from board data; the land decides
## where they stand.
static func stations(tag: String, n: int) -> Array:
	var line := sample_segment(tag)
	var total: float = line[line.size() - 1].s
	var out: Array = []
	var j := 0
	for k in range(1, n + 1):
		var target := total * float(k) / float(n + 1)
		while j < line.size() - 1 and float(line[j].s) < target:
			j += 1
		var j0 := maxi(j - 1, 0)
		var seg := float(line[j].s) - float(line[j0].s)
		var frac := 0.0 if seg <= 0.0 else (target - float(line[j0].s)) / seg
		var p: Vector2 = (line[j0].p as Vector2).lerp(line[j].p, frac)
		var t01 := lerpf(float(line[j0].t01), float(line[j].t01), frac)
		out.append(Vector3(p.x, path_y(tag, t01, p) + 0.02, p.y))
	return out

## The full station map the board generator consumes: landmark anchors + every
## segment's interior stations, counts read from board data (grounds own the
## geometry; the board owns the counts and types).
static func station_map(board_data: Dictionary) -> Dictionary:
	var out := {
		"lychgate": Vector3(LYCH_XZ.x, height(LYCH_XZ.x, LYCH_XZ.y) + 0.04, LYCH_XZ.y),
		"fork1": Vector3(FORK1_XZ.x, height(FORK1_XZ.x, FORK1_XZ.y) + 0.04, FORK1_XZ.y),
		"fork2": Vector3(FORK2_XZ.x, height(FORK2_XZ.x, FORK2_XZ.y) + 0.04, FORK2_XZ.y),
		"merge": Vector3(MERGE_XZ.x, height(MERGE_XZ.x, MERGE_XZ.y) + 0.04, MERGE_XZ.y),
		"gate": Vector3(GATE_XZ.x, height(GATE_XZ.x, GATE_XZ.y) + 0.04, GATE_XZ.y),
	}
	out["approach"] = stations("approach", (board_data.approach_types as Array).size())
	out["homestretch"] = stations("homestretch", int(board_data.homestretch))
	var seg_for := {"garden": ["garden_a", "garden_b"], "hollow": ["hollow_a", "hollow_b"],
		"valley": ["valley_a", "valley_b"]}
	for r in (board_data.routes as Array):
		var rd := r as Dictionary
		var tags: Array = seg_for[String(rd.tag)]
		out[String(tags[0])] = stations(String(tags[0]), int(rd.half_a))
		out[String(tags[1])] = stations(String(tags[1]), int(rd.half_b))
	return out

# --------------------------------------------------------------------------
# BUILD — the land made visible. Instance side only; every repeated element
# rides a MultiMesh (GROUNDS BAR perf envelope).
# --------------------------------------------------------------------------
const EXT_X := Vector2(-58.0, 52.0)      # terrain extents
const EXT_Z := Vector2(-80.0, 58.0)
const GRID := 1.4                         # terrain vertex pitch

## Station keep-out points (the board passes its node positions in) so the
## scatter never crowds a stone a pawn must land on.
var _keep_out: Array = []

func build_all(keep_out: Array = []) -> void:
	_keep_out = keep_out
	_build_terrain()
	_build_water()
	for tag in SEGS:
		_build_path(String(tag))
	_build_hedge_maze()
	_build_manor_silhouette()
	# G2 — the lands dressed (each dresser is asset-gated: a fresh checkout
	# without the Meshy kit still builds the full G1 world)
	_dress_garden()
	_dress_forest()
	_dress_bog()
	_dress_meadows()

## Sculpted heightmesh with per-vertex biome colour — one draw call. Colour
## carries the land's identity (mossy lawn, wood loam, bog murk, worn climb);
## a fine mottle keeps any two yards from matching (no visible tiling).
func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int((EXT_X.y - EXT_X.x) / GRID)
	var nz := int((EXT_Z.y - EXT_Z.x) / GRID)
	for iz in range(nz + 1):
		for ix in range(nx + 1):
			var x := EXT_X.x + float(ix) * GRID
			var z := EXT_Z.x + float(iz) * GRID
			# the rim rolls DOWN into the dark (mesh-only droop — the height()
			# the stations read never changes): no floating table edge on the
			# horizon, the estate just... ends.
			var rim := minf(minf(x - EXT_X.x, EXT_X.y - x), minf(z - EXT_Z.x, EXT_Z.y - z))
			var droop := 0.0
			if rim < 5.0:
				var rt := (5.0 - rim) / 5.0
				droop = -7.0 * rt * rt
			st.set_color(_ground_color(x, z).darkened(clampf(-droop * 0.09, 0.0, 0.55)))
			st.set_uv(Vector2(float(ix) / float(nx), float(iz) / float(nz)))
			st.add_vertex(Vector3(x, height(x, z) + droop, z))
	for iz in range(nz):
		for ix in range(nx):
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + (nx + 1)
			var d := c + 1
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)

func _ground_color(x: float, z: float) -> Color:
	var lawn := Color(0.088, 0.108, 0.078)        # damp moonlit green
	var garden := Color(0.080, 0.122, 0.068)      # tended, a shade richer
	var woods := Color(0.066, 0.077, 0.050)       # loam under gloom
	var bog := Color(0.085, 0.079, 0.058)         # olive murk
	var worn := Color(0.106, 0.104, 0.097)        # the climb, trodden grey
	var c := lawn
	c = c.lerp(garden, _ss((x - 8.0) / 12.0) * _ss((z + 48.0) / 24.0))
	c = c.lerp(woods, clampf(1.0 - absf(x + 8.0) / 14.0, 0.0, 1.0) * 0.85)
	var bdx := (x + 33.0) / 17.0
	var bdz := (z + 12.0) / 26.0
	c = c.lerp(bog, clampf(exp(-(bdx * bdx + bdz * bdz)) * 1.7, 0.0, 1.0))
	c = c.lerp(worn, _ss((-z - 42.0) / 12.0))
	c = c.lerp(worn, _ss((z - 33.0) / 7.0) * 0.7)  # forecourt wear
	# mud ring where the land dips toward standing water
	var h := height(x, z)
	if h < WATER_Y + 0.9:
		c = c.lerp(Color(0.062, 0.055, 0.044), clampf((WATER_Y + 0.9 - h) / 0.9, 0.0, 1.0))
	# the mottle — the lawn is never one green
	var m := _n2(x * 1.7 + 40.0, z * 1.7 - 40.0)
	c = c.lightened(m * 0.08) if m > 0.0 else c.darkened(-m * 0.10)
	return c

## The valley's standing water + the brook — SHAPED to the land: quads are
## emitted only where the ground actually lies below the waterline, so the
## shore is the terrain's own contour, never a plane's edge. Dark murk with a
## faint self-glow (a bog at night is its own lamp), one material, one mesh.
func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.4
	var count := 0
	var x := EXT_X.x
	while x < EXT_X.y:
		var z := EXT_Z.x
		while z < EXT_Z.y:
			var lvl := _water_level(x + step * 0.5, z + step * 0.5)
			if not is_nan(lvl):
				# emit if ANY corner dips under — the last quad tucks its far
				# edge beneath the rising shore
				var below := false
				for cx in [x, x + step]:
					for cz in [z, z + step]:
						if height(float(cx), float(cz)) < lvl + 0.06:
							below = true
				if below:
					st.add_vertex(Vector3(x, lvl, z))
					st.add_vertex(Vector3(x, lvl, z + step))
					st.add_vertex(Vector3(x + step, lvl, z))
					st.add_vertex(Vector3(x + step, lvl, z))
					st.add_vertex(Vector3(x, lvl, z + step))
					st.add_vertex(Vector3(x + step, lvl, z + step))
					count += 1
			z += step
		x += step
	if count == 0:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.034, 0.060, 0.068)
	mat.metallic = 0.45
	mat.roughness = 0.10
	mat.emission_enabled = true
	mat.emission = Color(0.055, 0.125, 0.135)
	mat.emission_energy_multiplier = 0.85
	mi.material_override = mat
	add_child(mi)

## Waterline at a point: the valley pond in its basin bounds, the brook along
## its cut. NAN = dry land.
static func _water_level(x: float, z: float) -> float:
	if x > -59.0 and x < -8.0 and z > -40.0 and z < 12.0:
		return WATER_Y
	if _brook_dist(x, z) < 3.4:
		return BROOK_Y
	return NAN

# --------------------------------------------------------------------------
# PATHS — each surface built its own way; ribbons conform to the land.
# --------------------------------------------------------------------------
func _build_path(tag: String) -> void:
	var line := sample_segment(tag, 18)
	# split the dense polyline into runs of one surface each
	var runs: Array = []
	var cur := ""
	for e in line:
		var s := surface_at(tag, float(e.t01))
		if s != cur:
			runs.append({"surf": s, "pts": []})
			cur = s
		(runs[runs.size() - 1].pts as Array).append(e)
	for run in runs:
		var pts: Array = run.pts
		if pts.size() < 2:
			continue
		match String(run.surf):
			"gravel":
				_ribbon(tag, pts, 2.3, Color(0.155, 0.148, 0.132), 0.35, 0.03)
			"grass":
				_ribbon(tag, pts, 1.9, Color(0.078, 0.108, 0.058), 0.25, 0.015)
			"dirt":
				_ribbon(tag, pts, 1.7, Color(0.108, 0.090, 0.070), 0.55, 0.025)
			"causeway":
				_causeway(tag, pts)
			"plank":
				_boardwalk(tag, pts)
			"bridge":
				_bridge(tag, pts)
			"flagstone":
				_slab_road(tag, pts, 2.9, 1.35, Color(0.135, 0.135, 0.145))
			"road":
				_slab_road(tag, pts, 3.2, 1.5, Color(0.140, 0.138, 0.148))

## A terrain-conforming strip with ragged, wandering edges — a WALKED path,
## never a printed one. Width breathes with noise; edges jitter per vertex.
func _ribbon(tag: String, pts: Array, width: float, col: Color, rag: float, lift: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p: Vector2 = pts[i].p
		var t01: float = pts[i].t01
		var nxt: Vector2 = (pts[mini(i + 1, pts.size() - 1)].p as Vector2)
		var prv: Vector2 = (pts[maxi(i - 1, 0)].p as Vector2)
		var dir := (nxt - prv)
		if dir.length() < 0.001:
			dir = Vector2(0, -1)
		var perp := Vector2(-dir.y, dir.x).normalized()
		var breathe := 1.0 + 0.18 * _n2(p.x * 2.0, p.y * 2.0)
		var half := width * 0.5 * breathe
		var jl := rag * _n2(p.x * 3.1 + 11.0, p.y * 3.1)
		var jr := rag * _n2(p.x * 3.1 - 17.0, p.y * 3.1 + 5.0)
		var l := p + perp * (half + jl)
		var r := p - perp * (half + jr)
		var shade := 1.0 + 0.10 * _n1(p.x * 1.3, p.y * 1.3)
		st.set_color(Color(col.r * shade, col.g * shade, col.b * shade))
		st.add_vertex(Vector3(l.x, path_y(tag, t01, l) + lift, l.y))
		st.set_color(Color(col.r * shade, col.g * shade, col.b * shade).darkened(0.12))
		st.add_vertex(Vector3(r.x, path_y(tag, t01, r) + lift, r.y))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)

## Cut stone slabs laid two abreast with stagger and settle — the processional
## road and the forecourt walk. One MultiMesh per run.
func _slab_road(tag: String, pts: Array, width: float, slab_len: float, col: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(width * 0.46, 0.10, slab_len * 0.88)
	mm.mesh = bm
	var xforms: Array = []
	var total: float = pts[pts.size() - 1].s
	var start: float = pts[0].s
	var d := start
	var row := 0
	while d < total:
		var e := _at_arc(pts, d)
		var p: Vector2 = e.p
		var dir: Vector2 = e.dir
		var perp := Vector2(-dir.y, dir.x)
		for side: float in [-1.0, 1.0]:
			var off := perp * side * width * 0.25
			off += dir * (0.5 * slab_len * 0.5 * (1.0 if side > 0 else -1.0) * float(row % 2))
			var c := p + off
			var y := path_y(tag, float(e.t01), c) + 0.02
			var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
			basis = basis.rotated(basis.x, 0.02 * sin(float(row) * 3.7 + side))
			xforms.append({"t": Transform3D(basis, Vector3(c.x, y, c.y)),
				"c": Color(col.lightened(0.06 * sin(float(row) * 5.3 + side * 2.0)))})
		d += slab_len
		row += 1
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i].t)
		mm.set_instance_color(i, xforms[i].c)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)

## The bog causeway: a low stone spine kept above the waterline, with rough
## curb stones along its edges.
func _causeway(tag: String, pts: Array) -> void:
	_ribbon(tag, pts, 2.2, Color(0.125, 0.124, 0.118), 0.2, 0.03)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.26, 0.62)
	mm.mesh = bm
	var xforms: Array = []
	var total: float = pts[pts.size() - 1].s
	var d: float = pts[0].s
	var k := 0
	while d < total:
		var e := _at_arc(pts, d)
		var p: Vector2 = e.p
		var dir: Vector2 = e.dir
		var perp := Vector2(-dir.y, dir.x)
		var side := 1.0 if k % 2 == 0 else -1.0
		var c := p + perp * side * 1.25
		var y := path_y(tag, float(e.t01), c)
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.y) + 0.35 * sin(float(k) * 7.1))
		xforms.append({"t": Transform3D(basis, Vector3(c.x, y + 0.06, c.y)),
			"c": Color(0.118, 0.117, 0.112).lightened(0.05 * sin(float(k) * 3.3))})
		d += 1.9
		k += 1
	_commit_mm(mm, xforms, 0.95)

## The boardwalk: planks laid crosswise on paired posts sunk into the water.
func _boardwalk(tag: String, pts: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(2.5, 0.07, 0.5)
	mm.mesh = bm
	var xforms: Array = []
	var post_mm := MultiMesh.new()
	post_mm.transform_format = MultiMesh.TRANSFORM_3D
	post_mm.use_colors = true
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.09
	pmesh.bottom_radius = 0.11
	pmesh.height = 1.6
	post_mm.mesh = pmesh
	var posts: Array = []
	var total: float = pts[pts.size() - 1].s
	var d: float = pts[0].s
	var k := 0
	while d < total:
		var e := _at_arc(pts, d)
		var p: Vector2 = e.p
		var dir: Vector2 = e.dir
		var yaw := atan2(dir.x, dir.y)
		var wob := 0.02 * sin(float(k) * 5.7) + 0.015 * sin(float(k) * 11.3)
		var basis := Basis(Vector3.UP, yaw + wob * 3.0)
		basis = basis.rotated(basis.z, wob)
		var wood := Color(0.118, 0.094, 0.066).lightened(0.07 * sin(float(k) * 2.9))
		xforms.append({"t": Transform3D(basis, Vector3(p.x, PLANK_Y + wob, p.y)), "c": wood})
		if k % 4 == 2:
			var perp := Vector2(-dir.y, dir.x)
			for side: float in [-1.0, 1.0]:
				var c := p + perp * side * 1.15
				posts.append({"t": Transform3D(Basis(Vector3.UP, yaw),
					Vector3(c.x, PLANK_Y - 0.75, c.y)), "c": Color(0.095, 0.078, 0.058)})
		d += 0.62
		k += 1
	_commit_mm(mm, xforms, 0.9)
	_commit_mm(post_mm, posts, 0.95)

## A bridge span: a humble stone footbridge over the garden brook. The deck
## math (path_y) is the truth — the model dresses it. (The BONE BRIDGE is
## NOT a road piece — see THE DORMANT BYPASS in _dress_bog.)
const BONE_BRIDGE := "res://assets/models/meshy/generated/bone_bridge.glb"

## THE BONE BRIDGE's bypass line (doc 28 §4 MAJOR 2, SPACE CLAIM — doc 33
## §7): when the Estate Stirs, it RISES here and Weeping Valley gains a
## shortcut across the deep, valley_a's boardwalk to valley_b's south
## approach, skipping the western horseshoe AND fork2. Until that night it
## lies SUNKEN, ribs breaking the surface — a visible omen, never a road.
const BYPASS_A := Vector2(-43.0, -5.0)
const BYPASS_B := Vector2(-33.0, -24.5)

func _bridge(tag: String, pts: Array) -> void:
	var a: Vector2 = pts[0].p
	var b: Vector2 = (pts[pts.size() - 1].p as Vector2)
	var mid := (a + b) * 0.5
	var span := a.distance_to(b)
	var mid_t: float = pts[pts.size() / 2].t01
	var deck_mid := path_y(tag, mid_t, mid)
	# G2: the forged stone footbridge hero spans the garden brook
	if tag == "garden_b" and ResourceLoader.exists(KIT + "garden_footbridge.glb"):
		var fb := MeshyProp.instance(KIT + "garden_footbridge.glb", 1.7)
		add_child(fb)
		fb.global_position = Vector3(mid.x, deck_mid - 1.15, mid.y)
		fb.look_at(Vector3(b.x, deck_mid - 1.15, b.y), Vector3.UP)
		return
	# the garden footbridge fallback (pre-kit): a gentle slab arch
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps := 14
	var dirv := (b - a).normalized()
	var perp := Vector2(-dirv.y, dirv.x)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		var t01 := lerpf(float(pts[0].t01), float(pts[pts.size() - 1].t01), t)
		var y := path_y(tag, t01, p)
		st.set_color(Color(0.130, 0.130, 0.138))
		var l := p + perp * 1.1
		var r := p - perp * 1.1
		st.add_vertex(Vector3(l.x, y, l.y))
		st.set_color(Color(0.118, 0.118, 0.126))
		st.add_vertex(Vector3(r.x, y, r.y))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mi.material_override = mat
	add_child(mi)
	# low parapet walls
	for side: float in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.22, 0.4, span * 0.9)
		wall.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.115, 0.115, 0.122)
		wmat.roughness = 0.9
		wall.material_override = wmat
		add_child(wall)
		var c := mid + perp * side * 1.05
		wall.global_position = Vector3(c.x, path_y(tag, mid_t, c) + 0.30, c.y)
		wall.look_at(Vector3(b.x + perp.x * side * 1.05, deck_mid + 0.30, b.y + perp.y * side * 1.05), Vector3.UP)

## Arc-length lookup on a dense run: {p, dir, t01}.
func _at_arc(pts: Array, d: float) -> Dictionary:
	var j := 0
	while j < pts.size() - 1 and float(pts[j].s) < d:
		j += 1
	var p: Vector2 = pts[j].p
	var prv: Vector2 = (pts[maxi(j - 1, 0)].p as Vector2)
	var nxt: Vector2 = (pts[mini(j + 1, pts.size() - 1)].p as Vector2)
	var dir := (nxt - prv)
	dir = dir.normalized() if dir.length() > 0.001 else Vector2(0, -1)
	return {"p": p, "dir": dir, "t01": float(pts[j].t01)}

func _commit_mm(mm: MultiMesh, xforms: Array, rough: float) -> void:
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, (xforms[i] as Dictionary).t)
		mm.set_instance_color(i, (xforms[i] as Dictionary).c)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = rough
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)

# --------------------------------------------------------------------------
# THE HEDGE MAZE — walls wherever the grid is not OPEN. Each wall run is a
# body box + jittered crown clumps, all one MultiMesh; corner posts stand a
# head taller. G2 re-dresses the same wall lines with the Meshy hedge kit.
# --------------------------------------------------------------------------
func _build_hedge_maze() -> void:
	# gather every wall run first — the SAME lines feed either dressing
	var runs: Array = []
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			# east wall of (c,r)
			if c < MAZE_COLS - 1 and not MAZE_OPEN_E.has("%d,%d" % [c, r]):
				runs.append({"at": _cell(c, r) + Vector2(MAZE_CELL * 0.5, 0), "dir": Vector2(0, 1)})
			# north wall of (c,r)
			if r < MAZE_ROWS - 1 and not MAZE_OPEN_N.has("%d,%d" % [c, r]):
				runs.append({"at": _cell(c, r) + Vector2(0, -MAZE_CELL * 0.5), "dir": Vector2(1, 0)})
	# boundary: south (entrance gap at col 0), north (exit gap at col 3),
	# west and east full runs
	for c in range(MAZE_COLS):
		if c != 0:
			runs.append({"at": _cell(c, 0) + Vector2(0, MAZE_CELL * 0.5), "dir": Vector2(1, 0)})
		if c != 3:
			runs.append({"at": _cell(c, MAZE_ROWS - 1) + Vector2(0, -MAZE_CELL * 0.5), "dir": Vector2(1, 0)})
	for r in range(MAZE_ROWS):
		runs.append({"at": _cell(0, r) + Vector2(-MAZE_CELL * 0.5, 0), "dir": Vector2(0, 1)})
		runs.append({"at": _cell(MAZE_COLS - 1, r) + Vector2(MAZE_CELL * 0.5, 0), "dir": Vector2(0, 1)})
	# G2: the living hedge kit re-dresses the wall lines (straight pieces,
	# an overgrown variant ~1-in-5). G1 fallback: the jittered box clusters.
	var straight := _kit_sources(KIT + "hedge_wall_straight.glb",
		Vector3(1.15, HEDGE_H + 0.15, MAZE_CELL + 0.6))
	var overgrown := _kit_sources(KIT + "hedge_wall_overgrown.glb",
		Vector3(1.15, HEDGE_H + 0.15, MAZE_CELL + 0.6))
	if not straight.is_empty():
		var pl_s: Array = []
		var pl_o: Array = []
		for run in runs:
			var at := run.at as Vector2
			var dir := run.dir as Vector2
			var seedf := at.x * 3.1 + at.y * 7.7
			var yaw := atan2(dir.x, dir.y) + 0.03 * sin(seedf * 1.7)
			# mirror half the pieces so no two neighbours read identical
			var flip := PI if sin(seedf * 2.9) > 0.0 else 0.0
			var basis := Basis(Vector3.UP, yaw + flip)
			var t := Transform3D(basis, snap(Vector3(at.x, 0, at.y), -0.10))
			if not overgrown.is_empty() and _h01(at.x, at.y, 223) < 0.20:
				pl_o.append(t)
			else:
				pl_s.append(t)
		_kit_multimesh(straight, pl_s)
		_kit_multimesh(overgrown, pl_o)
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)   # unit box; scale per instance
	mm.mesh = bm
	var xforms: Array = []
	for run in runs:
		_hedge_run(xforms, run.at as Vector2, run.dir as Vector2)
	_commit_mm(mm, xforms, 1.0)

func _cell(c: int, r: int) -> Vector2:
	return Vector2(MAZE_ORIGIN.x + float(c) * MAZE_CELL, MAZE_ORIGIN.y - float(r) * MAZE_CELL)

## One wall segment (cell-edge length) centred at `at`, running along `dir`.
## Built as THREE overlapping sub-boxes with tiny offsets, yaw and height
## jitter (the wall face breaks into planes that catch the moon differently —
## a clipped living thing, not poured concrete), plus low crown clumps. The
## green is calibrated against the estate_hedge_topiary hero (t3 A/B).
func _hedge_run(xforms: Array, at: Vector2, dir: Vector2) -> void:
	var yaw := atan2(dir.x, dir.y)
	var perp := Vector2(-dir.y, dir.x)
	var y := height(at.x, at.y)
	var seedf := at.x * 3.1 + at.y * 7.7
	var green := Color(0.092, 0.182, 0.050)
	var seg_len := (MAZE_CELL + HEDGE_T * 0.5) / 3.0
	for k in 3:
		var along := (float(k) - 1.0) * seg_len
		var cpos := at + dir * along + perp * 0.09 * sin(seedf * 5.3 + float(k) * 2.4)
		var h := HEDGE_H + 0.16 * sin(seedf * 3.1 + float(k) * 1.9)
		var body := Basis(Vector3.UP, yaw + 0.045 * sin(seedf * 1.7 + float(k) * 3.7)) \
			* Basis(Vector3.FORWARD, 0.025 * sin(seedf + float(k))) \
			* Basis.from_scale(Vector3(HEDGE_T + 0.06 * sin(seedf * 7.7 + float(k)), h, seg_len + 0.55))
		var v := 0.07 * sin(seedf * 2.3 + float(k) * 5.1)
		var tone := green.lightened(v) if v > 0.0 else green.darkened(-v * 1.3)
		xforms.append({"t": Transform3D(body, Vector3(cpos.x, y + h * 0.5 - 0.14, cpos.y)), "c": tone})
		# a crown clump riding each sub-box — unclipped growth on the top line
		var s := 0.8 + 0.35 * absf(sin(seedf * 5.1 + float(k) * 3.3))
		var crown := Basis(Vector3.UP, yaw + sin(seedf + float(k)) * 0.6) \
			* Basis.from_scale(Vector3(HEDGE_T * 0.85 * s, 0.5 * s, 1.05 * s))
		xforms.append({"t": Transform3D(crown,
			Vector3(cpos.x, y + h - 0.16 + 0.1 * sin(seedf * 7.0 + float(k)), cpos.y)),
			"c": tone.darkened(0.10)})

# --------------------------------------------------------------------------
# THE MANOR — a dark massing on its rise beyond the gate, warm windows lit.
# Never visited (yet); always visible. The moving target, doc 33 §3.
# --------------------------------------------------------------------------
func _build_manor_silhouette() -> void:
	var root := Node3D.new()
	root.name = "ManorSilhouette"
	add_child(root)
	var base_y := height(0.0, -70.0)
	root.position = Vector3(0.0, base_y, -70.0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.040, 0.041, 0.050)
	dark.roughness = 0.95
	var blocks := [
		{"s": Vector3(17.0, 7.5, 6.5), "p": Vector3(0, 3.75, 0)},          # hall
		{"s": Vector3(6.5, 5.5, 5.5), "p": Vector3(-11.0, 2.75, 0.8)},     # west wing
		{"s": Vector3(6.5, 6.0, 5.5), "p": Vector3(11.0, 3.0, 0.6)},       # east wing
		{"s": Vector3(3.2, 11.5, 3.2), "p": Vector3(4.2, 5.75, -1.0)},     # tower
	]
	for bdef in blocks:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = (bdef as Dictionary).s
		b.mesh = bm
		b.material_override = dark
		b.position = (bdef as Dictionary).p
		root.add_child(b)
	var roofs := [
		{"s": Vector3(17.6, 3.4, 7.1), "p": Vector3(0, 9.2, 0)},
		{"s": Vector3(7.1, 2.6, 6.1), "p": Vector3(-11.0, 6.8, 0.8)},
		{"s": Vector3(7.1, 2.6, 6.1), "p": Vector3(11.0, 7.3, 0.6)},
		{"s": Vector3(4.0, 2.2, 4.0), "p": Vector3(4.2, 12.6, -1.0)},
	]
	for rdef in roofs:
		var pr := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = (rdef as Dictionary).s
		pr.mesh = pm
		pr.material_override = dark
		pr.position = (rdef as Dictionary).p
		root.add_child(pr)
	# a few windows awake — warm, faint, watching
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.3, 0.22, 0.1)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.72, 0.35)
	lit.emission_energy_multiplier = 1.6
	for wdef in [Vector3(-3.5, 4.6, 3.31), Vector3(2.0, 5.4, 3.31),
			Vector3(6.2, 3.4, 3.31), Vector3(4.2, 9.8, 0.66),
			Vector3(-11.0, 3.9, 3.61)]:
		var w := MeshInstance3D.new()
		var qm := BoxMesh.new()
		qm.size = Vector3(0.55, 0.95, 0.06)
		w.mesh = qm
		w.material_override = lit
		w.position = wdef
		root.add_child(w)

# --------------------------------------------------------------------------
# G2 — THE LANDS DRESSED (doc 33 §5). The Meshy biome kits re-dress the same
# authored geometry: hedge wall lines get living hedge pieces, the Hollow
# fills with forest, the Valley grows its bog, the Garden its parterres and
# statuary. Every dresser is ASSET-GATED (missing GLB -> G1 fallback stays),
# every scatter is DETERMINISTIC (hash of position, no rng streams), and
# every repeated piece rides a MultiMesh built from the GLB's own meshes
# (GROUNDS BAR: draw calls stay flat no matter how thick the forest).
# --------------------------------------------------------------------------
const KIT := "res://assets/models/meshy/generated/"

## Extract MultiMesh sources from a GLB: one {mesh, norm} per MeshInstance3D,
## where norm maps the ORIGINAL mesh into a box of target dims centred at
## origin, base at y=0 (the same normalisation MeshyProp.instance applies,
## baked into a transform so thousands of copies cost one draw call per mesh).
## dims: x/z = footprint (NAN = keep aspect from the height scale), y = height.
func _kit_sources(path: String, dims: Vector3) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var scene: PackedScene = load(path)
	if scene == null:
		return []
	var model: Node3D = scene.instantiate()
	var found: Array = []
	_collect_meshes(model, Transform3D.IDENTITY, found)
	var boxes: Array[AABB] = []
	for f in found:
		boxes.append((f.local as Transform3D) * ((f.mesh as Mesh).get_aabb()))
	if boxes.is_empty():
		model.free()
		return []
	var aabb: AABB = boxes[0]
	for i in range(1, boxes.size()):
		aabb = aabb.merge(boxes[i])
	model.free()
	if aabb.size.y < 0.0001:
		return []
	# longest horizontal axis becomes the LENGTH axis (z) — hedge pieces etc.
	var pre := Basis.IDENTITY
	var lx := aabb.size.x
	var lz := aabb.size.z
	if lx > lz:
		pre = Basis(Vector3.UP, PI * 0.5)
		var t := lx
		lx = lz
		lz = t
	var sy := dims.y / aabb.size.y
	var sx := sy if is_nan(dims.x) else dims.x / maxf(lx, 0.0001)
	var sz := sy if is_nan(dims.z) else dims.z / maxf(lz, 0.0001)
	var c := aabb.get_center()
	var norm := Transform3D(Basis.from_scale(Vector3(sx, sy, sz)), Vector3.ZERO) \
		* Transform3D(pre, Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, Vector3(-c.x, -aabb.position.y, -c.z))
	var out: Array = []
	for f in found:
		out.append({"mesh": f.mesh, "norm": norm * (f.local as Transform3D)})
	return out

func _collect_meshes(node: Node, xform: Transform3D, found: Array) -> void:
	var here := xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found.append({"mesh": (node as MeshInstance3D).mesh, "local": here})
	for c in node.get_children():
		_collect_meshes(c, here, found)

## Commit a set of world placements against a kit source list — one MultiMesh
## per source mesh, materials as authored in the GLB.
func _kit_multimesh(sources: Array, placements: Array) -> void:
	if sources.is_empty() or placements.is_empty():
		return
	for src in sources:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = src.mesh
		mm.instance_count = placements.size()
		for i in placements.size():
			mm.set_instance_transform(i, (placements[i] as Transform3D) * (src.norm as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)

## One hero instance (single placement, full scene) — the garden statues,
## the landmarks. Returns true if the asset existed.
func _hero(path: String, h: float, pos: Vector3, yaw := 0.0) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var prop := MeshyProp.instance(path, h)
	add_child(prop)
	prop.global_position = pos
	prop.rotation.y = yaw
	return true

# ---- scatter support -----------------------------------------------------

## Distance from a point to the nearest control polyline of the named segs.
func _path_dist(p: Vector2, tags: Array) -> float:
	var best := 999.0
	for tag in tags:
		var pts: Array = (SEGS[String(tag)] as Dictionary).pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best

func _keep_dist(p: Vector2) -> float:
	var best := 999.0
	for k in _keep_out:
		var kv := k as Vector3
		best = minf(best, p.distance_to(Vector2(kv.x, kv.z)))
	return best

const ALL_SEGS := ["approach", "garden_a", "garden_b", "hollow_a", "hollow_b",
	"valley_a", "valley_b", "homestretch"]

## Deterministic 0..1 hash for a scatter cell.
static func _h01(x: float, z: float, salt: int) -> float:
	return _hash2(int(round(x * 7.0)), int(round(z * 7.0)), salt) * 0.5 + 0.5

# ---- THE GARDEN (authored pieces — a tended land is placed, not scattered) -

func _dress_garden() -> void:
	# parterre beds flanking the gravel walk + the fountain court
	var beds := [
		{"p": Vector2(6.5, 25.8), "yaw": 0.35},
		{"p": Vector2(6.5, 20.0), "yaw": 0.35},
		{"p": Vector2(14.0, 23.6), "yaw": 0.42},
		{"p": Vector2(27.6, -27.4), "yaw": -0.9},
		{"p": Vector2(29.2, -33.2), "yaw": -0.7},
	]
	for b in beds:
		var bp := b.p as Vector2
		_hero(KIT + "garden_parterre_bed.glb", 0.55,
			snap(Vector3(bp.x, 0, bp.y), -0.03), float(b.yaw))
	# statuary — the mourner watches the fork2 stretch, the urnbearer the court
	_hero(KIT + "garden_statue_mourner.glb", 2.4,
		snap(Vector3(20.5, 0, -18.6), -0.04), PI * 0.8)
	_hero(KIT + "garden_statue_urnbearer.glb", 2.4,
		snap(Vector3(35.2, 0, -26.2), -0.04), -PI * 0.35)
	# an abandoned tea table off the garden_b walk
	_hero(KIT + "garden_table_abandoned.glb", 1.0,
		snap(Vector3(24.5, 0, -23.6), -0.02), 0.6)
	# the maze centrepiece — the weeping angel at the end of the long false
	# corridor (cell 0,3): a reward only the lost (and the overhead camera) see
	_hero(KIT + "maze_center_statue.glb", 2.5,
		snap(Vector3(24.25, 0, 1.75), -0.03), PI)
	# living arches IN the wall line over the maze mouth and its far door
	# (the mouth arch floated 2.25u south of the boundary on the first pass —
	# it stands in the hedge line now)
	_hero(KIT + "hedge_arch_gap.glb", 2.5,
		snap(Vector3(MAZE_ORIGIN.x, 0, MAZE_ORIGIN.y + MAZE_CELL * 0.5), -0.1), 0.0)
	_hero(KIT + "hedge_arch_gap.glb", 2.5,
		snap(Vector3(_cell(3, 6).x, 0, _cell(3, 6).y - MAZE_CELL * 0.5), -0.1), 0.0)

# ---- THE HOLLOW WOODS (a true forest — trunks ARE the separation) ---------

func _dress_forest() -> void:
	var canopy := [
		{"path": KIT + "forest_tree_dark_oak.glb", "h": 6.5, "w": 0.30},
		{"path": KIT + "forest_tree_twisted_pine.glb", "h": 7.0, "w": 0.30},
		{"path": KIT + "forest_tree_bare_elm.glb", "h": 6.2, "w": 0.25},
		{"path": KIT + "forest_tree_hollow_snag.glb", "h": 4.0, "w": 0.15},
	]
	var srcs: Array = []
	var have := false
	for t in canopy:
		var s := _kit_sources(String(t.path), Vector3(NAN, float(t.h), NAN))
		srcs.append(s)
		if not s.is_empty():
			have = true
	if not have:
		return
	var buckets: Array = [[], [], [], []]
	var woods_segs := ["hollow_a", "hollow_b"]
	var x := -26.0
	while x < 6.0:
		var z := -34.0
		while z < 30.0:
			_forest_try(srcs, canopy, buckets, woods_segs, x, z)
			z += 3.4
		x += 3.4
	for ti in canopy.size():
		_kit_multimesh(srcs[ti], buckets[ti])
	# undergrowth along the dirt track's edges
	var under := [
		{"path": KIT + "forest_stump.glb", "h": 0.7, "salt": 131, "rate": 0.30},
		{"path": KIT + "forest_root_tangle.glb", "h": 0.9, "salt": 137, "rate": 0.35},
		{"path": KIT + "forest_deadfall_log.glb", "h": 0.8, "salt": 139, "rate": 0.30},
		{"path": KIT + "forest_mushroom_cluster.glb", "h": 0.5, "salt": 149, "rate": 0.45},
	]
	for u in under:
		var us := _kit_sources(String(u.path), Vector3(NAN, float(u.h), NAN))
		if us.is_empty():
			continue
		var pl: Array = []
		var ux := -24.0
		while ux < 4.0:
			var uz := -32.0
			while uz < 28.0:
				var salt := int(u.salt)
				var jx := ux + 2.2 * (_h01(ux, uz, salt) - 0.5)
				var jz := uz + 2.2 * (_h01(ux, uz, salt + 1) - 0.5)
				var p := Vector2(jx, jz)
				var d := _path_dist(p, woods_segs)
				if d > 2.2 and d < 5.5 and _keep_dist(p) > 3.2 \
						and height(jx, jz) > WATER_Y + 0.3 \
						and _h01(jx, jz, salt + 2) < float(u.rate):
					var sc2 := 0.8 + 0.4 * _h01(jx, jz, salt + 3)
					var b2 := Basis(Vector3.UP, TAU * _h01(jx, jz, salt + 4)) \
						* Basis.from_scale(Vector3(sc2, sc2, sc2))
					pl.append(Transform3D(b2, snap(Vector3(jx, 0, jz), -0.05)))
				uz += 4.6
			ux += 4.6
		_kit_multimesh(us, pl)

## One forest canopy candidate — returns true if a tree was placed.
func _forest_try(srcs: Array, canopy: Array, buckets: Array, woods_segs: Array,
		x: float, z: float) -> bool:
	var jx := x + 3.0 * (_h01(x, z, 101) - 0.5)
	var jz := z + 3.0 * (_h01(x, z, 103) - 0.5)
	var p := Vector2(jx, jz)
	# the woods stay east of the bog basin — no oaks wading the shore
	# (producer's bypass sightline from the causeway stays clear)
	if jx < -19.0:
		return false
	var d_woods := _path_dist(p, woods_segs)
	if d_woods < 3.2 or d_woods > 11.0:
		return false
	if _path_dist(p, ALL_SEGS) < 3.2 or _keep_dist(p) < 3.8:
		return false
	if height(jx, jz) < WATER_Y + 0.3 or _maze_mask(jx, jz) > 0.15:
		return false
	# the crossroads glades stay open — the forks breathe
	if p.distance_to(FORK1_XZ) < 7.0 or p.distance_to(FORK2_XZ) < 7.0:
		return false
	var roll := _h01(jx, jz, 107)
	var pick := 0
	var acc := 0.0
	for ti in canopy.size():
		acc += float((canopy[ti] as Dictionary).w)
		if roll <= acc:
			pick = ti
			break
	if (srcs[pick] as Array).is_empty():
		return false
	var sc := 0.8 + 0.5 * _h01(jx, jz, 109)
	var basis := Basis(Vector3.UP, TAU * _h01(jx, jz, 113)) * Basis.from_scale(Vector3(sc, sc, sc))
	(buckets[pick] as Array).append(Transform3D(basis, snap(Vector3(jx, 0, jz), -0.06)))
	return true

# ---- THE WEEPING VALLEY (the bog grows in) --------------------------------

func _dress_bog() -> void:
	# reeds crowd every shoreline (pond AND brook) — the water reads as EDGES
	var reeds := _kit_sources(KIT + "bog_reed_cluster.glb", Vector3(NAN, 1.4, NAN))
	if not reeds.is_empty():
		var pl: Array = []
		var x := EXT_X.x + 2.0
		while x < 46.0:
			var z := EXT_Z.x + 2.0
			while z < 20.0:
				var jx := x + 2.0 * (_h01(x, z, 151) - 0.5)
				var jz := z + 2.0 * (_h01(x, z, 153) - 0.5)
				var h := height(jx, jz)
				var lvl := _water_level(jx, jz)
				if not is_nan(lvl) and h > lvl - 0.35 and h < lvl + 0.4 \
						and _path_dist(Vector2(jx, jz), ALL_SEGS) > 2.4 \
						and _keep_dist(Vector2(jx, jz)) > 3.0 \
						and _h01(jx, jz, 157) < 0.6:
					var sc := 0.75 + 0.5 * _h01(jx, jz, 159)
					var b := Basis(Vector3.UP, TAU * _h01(jx, jz, 161)) \
						* Basis.from_scale(Vector3(sc, sc, sc))
					pl.append(Transform3D(b, Vector3(jx, maxf(h, lvl - 0.25) - 0.04, jz)))
				z += 2.6
			x += 2.6
		_kit_multimesh(reeds, pl)
	# hummocks dot the shallow water
	var hums := _kit_sources(KIT + "bog_hummock.glb", Vector3(NAN, 0.5, NAN))
	if not hums.is_empty():
		var pl2: Array = []
		var hx := -56.0
		while hx < -10.0:
			var hz := -38.0
			while hz < 12.0:
				var jx := hx + 2.5 * (_h01(hx, hz, 163) - 0.5)
				var jz := hz + 2.5 * (_h01(hx, hz, 167) - 0.5)
				var h := height(jx, jz)
				if h < WATER_Y - 0.15 and h > WATER_Y - 0.8 \
						and _path_dist(Vector2(jx, jz), ["valley_a", "valley_b"]) > 3.0 \
						and _h01(jx, jz, 169) < 0.4:
					var sc := 0.8 + 0.5 * _h01(jx, jz, 173)
					var b := Basis(Vector3.UP, TAU * _h01(jx, jz, 179)) \
						* Basis.from_scale(Vector3(sc, sc, sc))
					pl2.append(Transform3D(b, Vector3(jx, WATER_Y - 0.10, jz)))
				hz += 5.2
			hx += 5.2
		_kit_multimesh(hums, pl2)
	# willows bow along the banks — sparse, mournful
	var wil_a := _kit_sources(KIT + "bog_willow_weeping.glb", Vector3(NAN, 5.5, NAN))
	var wil_b := _kit_sources(KIT + "bog_willow_gnarled.glb", Vector3(NAN, 4.5, NAN))
	var wa: Array = []
	var wb: Array = []
	var wx := -56.0
	while wx < -6.0:
		var wz := -42.0
		while wz < 20.0:
			var jx := wx + 3.0 * (_h01(wx, wz, 181) - 0.5)
			var jz := wz + 3.0 * (_h01(wx, wz, 191) - 0.5)
			var h := height(jx, jz)
			if h > WATER_Y + 0.15 and h < WATER_Y + 1.6 \
					and _path_dist(Vector2(jx, jz), ALL_SEGS) > 3.4 \
					and _keep_dist(Vector2(jx, jz)) > 4.0 \
					and _h01(jx, jz, 193) < 0.45:
				var sc := 0.8 + 0.45 * _h01(jx, jz, 197)
				var b := Basis(Vector3.UP, TAU * _h01(jx, jz, 199)) \
					* Basis.from_scale(Vector3(sc, sc, sc))
				var t := Transform3D(b, snap(Vector3(jx, 0, jz), -0.08))
				if _h01(jx, jz, 211) < 0.55:
					wa.append(t)
				else:
					wb.append(t)
			wz += 7.0
		wx += 7.0
	_kit_multimesh(wil_a, wa)
	_kit_multimesh(wil_b, wb)
	# authored loneliness: the sunken fences, the gallows tree, the watch ruin
	_hero(KIT + "bog_fence_sunken.glb", 1.0, snap(Vector3(-20.0, 0, 10.5), -0.12), 0.5)
	_hero(KIT + "bog_fence_sunken.glb", 1.0, snap(Vector3(-17.5, 0, -24.5), -0.14), -0.8)
	_hero(KIT + "bog_gallows_tree.glb", 5.0, snap(Vector3(-45.5, 0, 11.0), -0.06), PI * 0.6)
	_hero(KIT + "valley_watch_ruin.glb", 3.5, snap(Vector3(-49.0, 0, -20.0), -0.15), PI * 0.25)
	# THE DORMANT BYPASS (doc 28 §4 MAJOR 2, producer ruling live jam 2):
	# the bone bridge lies SUNKEN on its claim line, top ribs breaking the
	# water — the estate's most visible omen. It rises in the Stirs lane.
	if ResourceLoader.exists(BONE_BRIDGE):
		# seated in the bypass channel's deep (t≈0.55 along the claim line)
		var mid := BYPASS_A.lerp(BYPASS_B, 0.55)
		var ribs := MeshyProp.instance(BONE_BRIDGE, 3.4)
		ribs.name = "BoneBridgeRibs"   # the Stirs rise ceremony finds it by name
		add_child(ribs)
		# sunk to TIP depth — only the rib crowns break the surface, bones in
		# the bog, never an arch silhouette (a dormant thing must not read as
		# a bridge from ANY review angle until its night comes)
		ribs.global_position = Vector3(mid.x, WATER_Y - 2.95, mid.y)
		ribs.look_at(Vector3(BYPASS_B.x, WATER_Y - 2.95, BYPASS_B.y), Vector3.UP)
		# the GLB's span runs across its local Z — square it onto the claim
		# line so the ribs already point bank-to-bank (it RISES IN PLACE when
		# the Estate Stirs; no rotation at rise time, just the lift + ramps)
		ribs.rotate_y(PI * 0.5)
	# THE FORK MEDIAN (producer, live jam 2 — the anti-X read): physical
	# separation between fork2's arrival and departure strands. Garden side:
	# a low clipped hedge border; bog side: one more drowned fence run.
	# tenth watch: the median wears cast iron now (the filler wave's estate
	# fence run) — the clipped-hedge stand-in stays as the fresh-checkout
	# fallback until the GLB exists.
	var median := _kit_sources(KIT + "estate_iron_fence_run.glb", Vector3(0.4, 1.2, 5.4))
	var msink := -0.06
	if median.is_empty():
		median = _kit_sources(KIT + "hedge_wall_straight.glb", Vector3(0.8, 0.95, 5.4))
		msink = -0.10
	if not median.is_empty():
		var pl3: Array = []
		for hx: float in [9.0, 14.5, 20.0]:
			var hz := -15.9 - (hx - 9.0) * 0.12
			pl3.append(Transform3D(Basis(Vector3.UP, PI * 0.53),
				snap(Vector3(hx, 0, hz), msink)))
		_kit_multimesh(median, pl3)
	_hero(KIT + "bog_fence_sunken.glb", 1.0, snap(Vector3(-15.0, 0, -16.6), -0.12), PI * 0.53)


# ---- THE LIVING LAWN (tenth watch — ground cover + the rolling estate) ----

## Dense hash-scattered meadow cover over every open lawn: grass tufts as the
## base coat everywhere, wildflowers drifting off the garden walks, ferns in
## the hollow's shade, field boulders riding the new swells. All MultiMesh —
## the whole living lawn costs ~a dozen draw calls. Keep-outs: path aprons
## (tighter than trees — grass may hug a road), the maze block, the water,
## the station keep-outs, and (boulders only) every Estate Stirs claim.
func _dress_meadows() -> void:
	var covers := [
		{"path": KIT + "ground_grass_tuft_a.glb", "h": 0.42, "salt": 311,
			"rate": 0.85, "step": 2.1, "dmin": 1.6, "kind": "grass"},
		{"path": KIT + "ground_grass_tuft_b.glb", "h": 0.36, "salt": 331,
			"rate": 0.80, "step": 2.3, "dmin": 1.6, "kind": "grass"},
		{"path": KIT + "ground_wildflower_clump.glb", "h": 0.5, "salt": 347,
			"rate": 0.30, "step": 3.1, "dmin": 2.0, "kind": "garden"},
		{"path": KIT + "ground_fern.glb", "h": 0.55, "salt": 353,
			"rate": 0.35, "step": 3.3, "dmin": 2.2, "kind": "hollow"},
	]
	for c in covers:
		var srcs := _kit_sources(String(c.path), Vector3(NAN, float(c.h), NAN))
		if srcs.is_empty():
			continue
		var salt := int(c.salt)
		# One MultiMesh per source per cover — chunking was tried and made
		# the worst framing WORSE (the forecourt shot sees every chunk;
		# draw calls scale with MMI count, not instances).
		var pl: Array = []
		var x := EXT_X.x + 2.0
		while x < EXT_X.y - 2.0:
			var z := EXT_Z.x + 2.0
			while z < EXT_Z.y - 2.0:
				var jx := x + 1.8 * (_h01(x, z, salt) - 0.5)
				var jz := z + 1.8 * (_h01(x, z, salt + 1) - 0.5)
				if _lawn_ok(Vector2(jx, jz), String(c.kind), float(c.dmin)) \
						and _h01(jx, jz, salt + 2) < float(c.rate):
					var sc := 0.55 + 0.4 * _h01(jx, jz, salt + 3)
					var b := Basis(Vector3.UP, TAU * _h01(jx, jz, salt + 4)) \
						* Basis.from_scale(Vector3(sc, sc, sc))
					pl.append(Transform3D(b, snap(Vector3(jx, 0, jz), -0.10)))
				z += float(c.step)
			x += float(c.step)
		_kit_multimesh(_moonlit_sources(srcs), pl)
	# field boulders — sparse, riding the risen ground only, never on a claim.
	# ONE scatter variant (draw-call budget: w6 forecourt is the watchline);
	# the tall standing stone serves as three authored ridge heroes instead.
	var rocks := [
		{"path": KIT + "ground_boulder_a.glb", "h": 0.85, "salt": 367, "rate": 0.20},
	]
	_hero(KIT + "ground_boulder_b.glb", 1.5, snap(Vector3(-52.0, 0, 2.0), -0.16), 0.7)
	_hero(KIT + "ground_boulder_b.glb", 1.2, snap(Vector3(-54.0, 0, -12.0), -0.14), 2.3)
	_hero(KIT + "ground_boulder_b.glb", 1.7, snap(Vector3(45.0, 0, 12.0), -0.18), 4.1)
	for r in rocks:
		var rs := _kit_sources(String(r.path), Vector3(NAN, float(r.h), NAN))
		if rs.is_empty():
			continue
		var rsalt := int(r.salt)
		var rpl: Array = []
		var rx := EXT_X.x + 4.0
		while rx < EXT_X.y - 4.0:
			var rz := EXT_Z.x + 4.0
			while rz < EXT_Z.y - 4.0:
				var jx := rx + 3.5 * (_h01(rx, rz, rsalt) - 0.5)
				var jz := rz + 3.5 * (_h01(rx, rz, rsalt + 1) - 0.5)
				var p := Vector2(jx, jz)
				if height(jx, jz) > 1.35 and _path_dist(p, ALL_SEGS) > 4.5 \
						and _keep_dist(p) > 4.5 and _claim_dist(p) > 4.5 \
						and _maze_mask(jx, jz) < 0.05 and jz < 30.0 \
						and _h01(jx, jz, rsalt + 2) < float(r.rate):
					var sc := 0.75 + 0.7 * _h01(jx, jz, rsalt + 3)
					var b := Basis(Vector3.UP, TAU * _h01(jx, jz, rsalt + 4)) \
						* Basis.from_scale(Vector3(sc, sc, sc))
					rpl.append(Transform3D(b, snap(Vector3(jx, 0, jz), -0.14)))
				rz += 8.5
			rx += 8.5
		_kit_multimesh(rs, rpl)

## One gate for every blade: open land only — and grass grows in DRIFTS,
## never a carpet (the first pass carpeted the estate wall-to-wall: roads
## drowned, the bog vanished, moonlight read as noon — GROUNDS BAR says no
## uniformity, and COLOR IS GOOD needs dark to pop against).
func _lawn_ok(p: Vector2, kind: String, dmin: float) -> bool:
	if _path_dist(p, ALL_SEGS) < dmin or _keep_dist(p) < 2.6:
		return false
	if height(p.x, p.y) < WATER_Y + 0.25 or _maze_mask(p.x, p.y) > 0.1:
		return false
	if p.y > 34.0:
		return false   # the forecourt table keeps its worn flagstone
	if kind == "grass":
		# the bog stays MUD — sparse tussocks only, west of the treeline
		if p.x < -20.0 and p.y > -32.0 and p.y < 10.0:
			return _h01(p.x, p.y, 97) < 0.16
		# meadow drifts: broad noise carves bare dark soil between them
		var drift := _vnoise(p.x * 0.048 + 57.0, p.y * 0.048, 91)
		if drift < -0.15:
			return false
	match kind:
		"garden":
			return _path_dist(p, ["garden_a", "garden_b"]) < 10.0
		"hollow":
			return p.x > -19.0 and _path_dist(p, ["hollow_a", "hollow_b"]) < 8.0
	return true

## Distance to the nearest Estate Stirs ground claim (doc 33 §5b) — the
## boulder pass keeps off them; grass may grow anywhere (a ghost road
## breaking through meadow is the point).
func _claim_dist(p: Vector2) -> float:
	# the procession-road lane (a segment) + the point claims
	var a := Vector2(31.0, -29.0)
	var b := Vector2(-14.0, -18.0)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var best := p.distance_to(a + ab * t)
	for q: Vector2 in [Vector2(-16.0, 3.0), Vector2(-24.0, 0.0),
			Vector2(-13.0, 6.0), Vector2(-13.0, -15.0), Vector2(-20.0, 4.0),
			Vector2(-10.0, -52.0)]:
		best = minf(best, p.distance_to(q))
	return best

# --------------------------------------------------------------------------
# G3 — THE PHYSICS FLOOR (estate hub only). The walkabout's CharacterBody
# walkers need ground to stand on; board mode's pawns never touch physics,
# so only estate.gd calls this. One HeightMapShape sampled at 1u from the
# SAME height() the stations read — the land the toys play on and the land
# the family walks are provably the same land.
# --------------------------------------------------------------------------
func build_collision() -> void:
	var w := int(EXT_X.y - EXT_X.x) + 1
	var d := int(EXT_Z.y - EXT_Z.x) + 1
	var data := PackedFloat32Array()
	data.resize(w * d)
	for iz in d:
		for ix in w:
			data[iz * w + ix] = height(EXT_X.x + float(ix), EXT_Z.x + float(iz))
	var hm := HeightMapShape3D.new()
	hm.map_width = w
	hm.map_depth = d
	hm.map_data = data
	var shape := CollisionShape3D.new()
	shape.shape = hm
	var body := StaticBody3D.new()
	body.name = "GroundsCollision"
	body.collision_layer = 1
	body.add_child(shape)
	add_child(body)
	body.position = Vector3((EXT_X.x + EXT_X.y) * 0.5, 0.0, (EXT_Z.x + EXT_Z.y) * 0.5)

## THE ESTATE STIRS reaches for the dormant ribs at rise time (null on a
## fresh checkout without the asset — the graph mutation fires regardless).
func bone_bridge() -> Node3D:
	return get_node_or_null("BoneBridgeRibs")

## Moonlight-grade a kit source list: the filler GLBs came back daylight-
## bright (Meshy greens); the estate lives at night. Duplicate each mesh's
## surface materials with darkened, slightly cooled albedo — MultiMesh has
## no per-instance material hook, so the copy happens once per source.
func _moonlit_sources(srcs: Array) -> Array:
	var out: Array = []
	for src in srcs:
		var mesh := (src.mesh as Mesh).duplicate() as Mesh
		for si in mesh.get_surface_count():
			var mat := mesh.surface_get_material(si)
			if mat is BaseMaterial3D:
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = Color(
					d.albedo_color.r * 0.60, d.albedo_color.g * 0.66,
					d.albedo_color.b * 0.72, d.albedo_color.a)
				mesh.surface_set_material(si, d)
		out.append({"mesh": mesh, "norm": src.norm})
	return out
