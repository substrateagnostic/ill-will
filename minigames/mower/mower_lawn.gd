class_name MowerLawn
extends Node3D
## THE ENGINE ROOM. A coverage grid (GW x GH cells over a 16x12 m lawn)
## driving ONE plane + ONE shader via ONE R8 data texture. Cell flips are
## written into an Image and committed to the ImageTexture at most once per
## frame (commit()), per the spec's perf rule. There are NO per-cell nodes.
##
## Owner codes (stored per cell in `cells` and in the texture's red byte):
##   0        uncut tall grass
##   1..4     mowed + tinted to player (index+1)
##   BLOCKED  no-mow bed (birdbath / flowerbed), excluded from scoring
##
## Coordinate map: world X in [-HX, HX] -> cell col 0..GW-1,
##                 world Z in [-HZ, HZ] -> cell row 0..GH-1.
## The plane's UV is (col/GW, row/GH) so the shader and CPU agree per texel.

const GW := 64
const GH := 48
const HX := 8.0
const HZ := 6.0
const CELL := 0.25             # (2*HX)/GW == (2*HZ)/GH == 0.25
const BLOCKED := 200

var cells := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _mat: ShaderMaterial
var _dirty := false

# live tallies so scoring never rescans the grid
var owner_cells := [0, 0, 0, 0]
var uncut_cells := 0
var mowable_total := 0

# obstacle circles in world XZ for the mowers to collide with (beds are solid)
var solid_circles: Array = []  # {c: Vector2, r: float}

func build(player_colors: Array) -> void:
	cells.resize(GW * GH)
	# lawn mesh + shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0 * HX, 2.0 * HZ)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var mi := MeshInstance3D.new()
	mi.name = "LawnSurface"
	mi.mesh = plane
	var sh := load("res://minigames/mower/lawn.gdshader") as Shader
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var stripe := load("res://assets/textures/grass_stripes.png") as Texture2D
	_mat.set_shader_parameter("stripe_tex", stripe)
	_mat.set_shader_parameter("grid_size", Vector2(GW, GH))
	var cols: Array = []
	for i in 4:
		var c: Color = player_colors[i] if i < player_colors.size() else Color.WHITE
		cols.append(Vector3(c.r, c.g, c.b))
	_mat.set_shader_parameter("p_colors", cols)
	mi.material_override = _mat
	add_child(mi)
	# init all uncut, then carve beds
	for i in cells.size():
		cells[i] = 0
	uncut_cells = GW * GH
	_img = Image.create(GW, GH, false, Image.FORMAT_R8)
	_img.fill(Color(0, 0, 0))
	_tex = ImageTexture.create_from_image(_img)
	_mat.set_shader_parameter("coverage_tex", _tex)
	_recount_mowable()

func set_overtime(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("overtime", v)

## Presentation-only: spotlight one owner's cells for the tally ceremony.
## owner_code 1..4 = the player being lit (0 = ceremony off), gain 0..1 = glow.
func set_tally(owner_code: int, gain: float) -> void:
	if _mat:
		_mat.set_shader_parameter("tally_owner", owner_code)
		_mat.set_shader_parameter("tally_gain", gain)
		# owner_code 0 = ceremony off (no dim); >0 = recede every other player's turf
		_mat.set_shader_parameter("tally_active", 1.0 if owner_code > 0 else 0.0)

# -- coordinate helpers -------------------------------------------------------

func col_of(wx: float) -> int:
	return clampi(int((wx + HX) / CELL), 0, GW - 1)

func row_of(wz: float) -> int:
	return clampi(int((wz + HZ) / CELL), 0, GH - 1)

func cell_center(cx: int, cy: int) -> Vector2:
	return Vector2(-HX + (cx + 0.5) * CELL, -HZ + (cy + 0.5) * CELL)

func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cx < GW and cy >= 0 and cy < GH

# -- beds / obstacles ---------------------------------------------------------

## Carve a rectangular no-mow bed (world-space center + half extents).
func add_bed_rect(center: Vector2, half: Vector2) -> void:
	var x0 := col_of(center.x - half.x)
	var x1 := col_of(center.x + half.x)
	var y0 := row_of(center.y - half.y)
	var y1 := row_of(center.y + half.y)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			_block(cx, cy)
	solid_circles.append({"c": center, "r": maxf(half.x, half.y)})
	_recount_mowable()

## Carve a circular no-mow bed (birdbath).
func add_bed_circle(center: Vector2, r: float) -> void:
	var x0 := col_of(center.x - r)
	var x1 := col_of(center.x + r)
	var y0 := row_of(center.y - r)
	var y1 := row_of(center.y + r)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if cell_center(cx, cy).distance_to(center) <= r:
				_block(cx, cy)
	solid_circles.append({"c": center, "r": r})
	_recount_mowable()

func _block(cx: int, cy: int) -> void:
	if not in_bounds(cx, cy):
		return
	var idx := cy * GW + cx
	if cells[idx] == BLOCKED:
		return
	var old := cells[idx]
	if old == 0:
		uncut_cells -= 1
	elif old >= 1 and old <= 4:
		owner_cells[old - 1] -= 1
	cells[idx] = BLOCKED
	_img.set_pixel(cx, cy, Color(float(BLOCKED) / 255.0, 0, 0))
	_dirty = true

func _recount_mowable() -> void:
	var blocked := 0
	for i in cells.size():
		if cells[i] == BLOCKED:
			blocked += 1
	mowable_total = GW * GH - blocked

# -- the cut ------------------------------------------------------------------

## Stamp an oriented deck rectangle, converting cells to `owner` (1..4).
## Returns {fresh, stolen, recut} counts for stats + steal drag.
func paint_deck(center: Vector2, fwd: Vector2, half_w: float, half_l: float, owner: int) -> Dictionary:
	var f := fwd.normalized() if fwd.length() > 0.001 else Vector2(0, 1)
	var right := Vector2(f.y, -f.x)
	var reach := maxf(half_w, half_l) + CELL
	var x0 := col_of(center.x - reach)
	var x1 := col_of(center.x + reach)
	var y0 := row_of(center.y - reach)
	var y1 := row_of(center.y + reach)
	var fresh := 0
	var stolen := 0
	var recut := 0
	var code := owner  # owner already 1..4
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var idx := cy * GW + cx
			var cur := cells[idx]
			if cur == BLOCKED:
				continue
			var wc := cell_center(cx, cy)
			var d := wc - center
			if absf(d.dot(f)) <= half_l and absf(d.dot(right)) <= half_w:
				if cur == code:
					recut += 1
					continue
				if cur == 0:
					uncut_cells -= 1
					fresh += 1
				else:
					owner_cells[cur - 1] -= 1
					stolen += 1
				cells[idx] = code
				owner_cells[code - 1] += 1
				_img.set_pixel(cx, cy, Color(float(code) / 255.0, 0, 0))
	if fresh > 0 or stolen > 0:
		_dirty = true
	return {"fresh": fresh, "stolen": stolen, "recut": recut}

## Ram "turf theft" burst: flip up to n cells nearest `impact` that belong to
## anyone but `attacker` (owner code) to the attacker. Returns cells stolen.
func steal_burst(impact: Vector2, attacker: int, n: int) -> int:
	var rad := 1.4
	var cand: Array = []
	var x0 := col_of(impact.x - rad)
	var x1 := col_of(impact.x + rad)
	var y0 := row_of(impact.y - rad)
	var y1 := row_of(impact.y + rad)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var idx := cy * GW + cx
			var cur := cells[idx]
			if cur == BLOCKED or cur == 0 or cur == attacker:
				continue
			var dd: float = cell_center(cx, cy).distance_squared_to(impact)
			cand.append({"idx": idx, "d": dd, "cx": cx, "cy": cy, "cur": cur})
	cand.sort_custom(func(a, b): return float(a.d) < float(b.d))
	var taken := 0
	for e in cand:
		if taken >= n:
			break
		var idx: int = e.idx
		var cur: int = e.cur
		owner_cells[cur - 1] -= 1
		cells[idx] = attacker
		owner_cells[attacker - 1] += 1
		_img.set_pixel(int(e.cx), int(e.cy), Color(float(attacker) / 255.0, 0, 0))
		taken += 1
	if taken > 0:
		_dirty = true
	return taken

## Push the accumulated Image to the GPU. Call ONCE per frame from the root.
func commit() -> void:
	if _dirty:
		_tex.update(_img)
		_dirty = false

# -- scoring ------------------------------------------------------------------

func coverage_pct(owner_index: int) -> float:
	if mowable_total <= 0:
		return 0.0
	return 100.0 * float(owner_cells[owner_index]) / float(mowable_total)

func uncut_pct() -> float:
	if mowable_total <= 0:
		return 0.0
	return 100.0 * float(uncut_cells) / float(mowable_total)

func owner_at_world(w: Vector2) -> int:
	return cells[row_of(w.y) * GW + col_of(w.x)]
