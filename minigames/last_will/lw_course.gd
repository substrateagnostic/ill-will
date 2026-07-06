class_name LWCourse
extends Node3D
## THE PROCESSION ROUTE — a linear 3-segment funeral gauntlet over the dusk
## void: start chapel -> winding graveyard path -> THE CRYPT. The spine runs
## along +X; z_center(x) bends it, half_width(x) narrows it, GAPS cut it.
## Built from flagstone slabs (one StaticBody, many shapes), stone lanterns,
## gravestones, a lychgate per checkpoint and a crypt facade at the end.
##
## Also owns the CURSE SLOTS — nine named stretches of road the dead may
## condemn from the will draft. Pure geometry + queries; no game state.

const START_X := -8.0            # back wall of the start plaza
const RACE_START_X := 0.0        # progress 0 for the HUD track
const FINISH_X := 198.0          # crypt door plane — crossing it wins
const END_X := 206.0             # floor ends here
const VOID_Y := -7.0

## gaps in the ossuary ridge — hop (B) or fall
const GAPS := [[150.0, 151.9], [171.0, 172.9]]

## checkpoint x positions (0 = start line). Respawn a little behind each.
const CHECKPOINTS := [0.0, 66.0, 138.0]

## spine bend knots (x, z_center) — smoothstepped between
const Z_KNOTS := [
	[-8.0, 0.0], [66.0, 0.0], [84.0, 4.5], [105.0, -4.5],
	[123.0, 3.0], [138.0, 0.0], [206.0, 0.0],
]
## width knots (x, half_width) — lerped between
const W_KNOTS := [
	[-8.0, 5.0], [2.0, 3.2], [62.0, 3.2], [65.0, 4.6], [71.0, 4.6],
	[76.0, 2.7], [92.0, 2.7], [95.0, 3.5], [101.0, 3.5], [104.0, 2.7],
	[131.0, 2.7], [136.0, 4.6], [142.0, 4.6], [146.0, 1.9],
	[189.0, 1.9], [193.0, 4.2], [206.0, 4.2],
]

## THE NINE STRETCHES — curse slots. Names are read aloud by the will cards.
const SLOTS := [
	{"id": 0, "name": "THE LYCHGATE ROAD", "x": 12.0, "len": 12.0},
	{"id": 1, "name": "THE PROCESSION ROW", "x": 30.0, "len": 12.0},
	{"id": 2, "name": "THE MOURNERS' MILE", "x": 48.0, "len": 12.0},
	{"id": 3, "name": "THE SEXTON'S BEND", "x": 84.0, "len": 11.0},
	{"id": 4, "name": "THE LANTERN WALK", "x": 98.0, "len": 10.0},
	{"id": 5, "name": "THE WILLOW TURN", "x": 120.0, "len": 11.0},
	{"id": 6, "name": "THE OSSUARY RIDGE", "x": 147.0, "len": 8.0},
	{"id": 7, "name": "THE PALLBEARERS' GAP", "x": 168.0, "len": 8.0},
	{"id": 8, "name": "THE CRYPT STEPS", "x": 188.0, "len": 8.0},
]

## base hazard placements (the controller spawns/ticks these)
const BOULDER_LANES := [16.0, 34.0, 52.0, 128.0]  # boulders cross here
const PENDULUM_GATES := [76.0, 112.0, 180.0]      # endless scythes swing here
const SPINNER_X := 98.0                            # rotating sweeper
const WALL_XS := [158.0, 176.0]                    # sliding wall pushers

var _floor_body: StaticBody3D

# ================================================================ queries
static func z_center(x: float) -> float:
	var n := Z_KNOTS.size()
	if x <= float(Z_KNOTS[0][0]):
		return float(Z_KNOTS[0][1])
	for i in range(1, n):
		var x1 := float(Z_KNOTS[i][0])
		if x <= x1:
			var x0 := float(Z_KNOTS[i - 1][0])
			var t := (x - x0) / maxf(x1 - x0, 0.001)
			return lerpf(float(Z_KNOTS[i - 1][1]), float(Z_KNOTS[i][1]), smoothstep(0.0, 1.0, t))
	return float(Z_KNOTS[n - 1][1])

static func half_width(x: float) -> float:
	var n := W_KNOTS.size()
	if x <= float(W_KNOTS[0][0]):
		return float(W_KNOTS[0][1])
	for i in range(1, n):
		var x1 := float(W_KNOTS[i][0])
		if x <= x1:
			var x0 := float(W_KNOTS[i - 1][0])
			var t := (x - x0) / maxf(x1 - x0, 0.001)
			return lerpf(float(W_KNOTS[i - 1][1]), float(W_KNOTS[i][1]), t)
	return float(W_KNOTS[n - 1][1])

static func in_gap(x: float) -> bool:
	for g in GAPS:
		if x >= float(g[0]) and x <= float(g[1]):
			return true
	return false

## Is (x,z) over solid road? (skin margin so edge-walkers aren't robbed)
static func over_ground(x: float, z: float) -> bool:
	if x < START_X or x > END_X:
		return false
	if in_gap(x):
		return false
	return absf(z - z_center(x)) <= half_width(x) + 0.15

## Spot on the road for a slot/stretch center.
static func slot_center(slot: Dictionary) -> Vector3:
	var x := float(slot.x)
	return Vector3(x, 0.0, z_center(x))

static func checkpoint_pos(cp: int, seat: int) -> Vector3:
	var x := float(CHECKPOINTS[clampi(cp, 0, CHECKPOINTS.size() - 1)])
	var spread: float = half_width(x) - 1.1
	var lateral := (-1.5 + float(seat)) / 1.5 * spread * 0.6
	return Vector3(x - 2.0 + 0.3 * float(seat % 2), 0.3, z_center(x) + lateral)

# ================================================================ build
func build() -> void:
	_floor_body = StaticBody3D.new()
	_floor_body.name = "Floor"
	_floor_body.collision_layer = 1
	_floor_body.collision_mask = 0
	add_child(_floor_body)
	_build_slabs()
	_build_start_chapel()
	_build_checkpoint_gates()
	_build_crypt()
	_build_dressing()

func _build_slabs() -> void:
	var cursor := START_X
	var i := 0
	while cursor < END_X - 0.05:
		var next := cursor + 1.6
		var skip := false
		for g in GAPS:
			var g0 := float(g[0])
			var g1 := float(g[1])
			if cursor >= g0 - 0.01 and cursor < g1:
				cursor = g1
				skip = true
				break
			if next > g0 and cursor < g0:
				next = g0
		if skip:
			continue
		next = minf(next, END_X)
		var cx := (cursor + next) / 2.0
		var l := next - cursor
		var hw := half_width(cx)
		var zc := z_center(cx)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(l - 0.05, 1.5, hw * 2.0)
		seg.mesh = bm
		var mat := StandardMaterial3D.new()
		var shade := 0.28 + 0.11 * float((i * 7) % 5) / 4.0
		mat.albedo_color = Color(shade * 0.96, shade * 0.94, shade * 1.14)
		mat.roughness = 0.95
		seg.material_override = mat
		seg.position = Vector3(cx, -0.76 - 0.012 * float((i * 5) % 3), zc)
		add_child(seg)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(l + 0.02, 1.5, hw * 2.0 + 0.1)
		cs.shape = box
		cs.position = Vector3(cx, -0.75, zc)
		_floor_body.add_child(cs)
		cursor = next
		i += 1

func _stone_mat(c := Color(0.5, 0.47, 0.52)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m

func _build_start_chapel() -> void:
	# broken chapel arch straddling the start line + candle pews
	var stone := _stone_mat()
	for zs in [-1.0, 1.0]:
		var hw := half_width(0.0)
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.9, 4.2, 0.9)
		pillar.mesh = pm
		pillar.material_override = stone
		pillar.position = Vector3(0.0, 2.1, zs * (hw + 0.7))
		add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.1, 0.7, half_width(0.0) * 2.0 + 2.6)
	lintel.mesh = lm
	lintel.material_override = stone
	lintel.position = Vector3(0.0, 4.35, 0.0)
	add_child(lintel)
	var sign := Label3D.new()
	sign.text = "THE PROCESSION"
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.modulate = Color(1.0, 0.85, 0.5)
	sign.outline_size = 14
	sign.outline_modulate = Color(0.08, 0.06, 0.1)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0.0, 5.3, 0.0)
	add_child(sign)
	# chapel back wall behind the spawns
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(1.0, 3.0, 11.4)
	wall.mesh = wm
	wall.material_override = _stone_mat(Color(0.36, 0.33, 0.4))
	wall.position = Vector3(START_X + 0.4, 1.5, 0.0)
	add_child(wall)
	for zs in [-3.4, 0.0, 3.4]:
		var lant := _make_lantern(true)
		lant.position = Vector3(START_X + 1.3, 0.0, zs)
		add_child(lant)

func _build_checkpoint_gates() -> void:
	# lychgates over checkpoints 1 and 2 (not the start — the chapel owns it)
	for ci in range(1, CHECKPOINTS.size()):
		var x := float(CHECKPOINTS[ci])
		var zc := z_center(x)
		var hw := half_width(x)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.3, 0.22, 0.18)
		wood.roughness = 0.9
		for zs in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.45, 3.4, 0.45)
			post.mesh = pm
			post.material_override = wood
			post.position = Vector3(x, 1.7, zc + zs * (hw + 0.4))
			add_child(post)
		var roof := MeshInstance3D.new()
		var rm := PrismMesh.new()
		rm.size = Vector3(2.4, 1.0, hw * 2.0 + 2.2)
		roof.mesh = rm
		roof.material_override = wood
		roof.position = Vector3(x, 3.9, zc)
		add_child(roof)
		var lant := _make_lantern(true)
		lant.scale = Vector3(0.8, 0.8, 0.8)
		lant.position = Vector3(x, 2.2, zc)
		add_child(lant)
		var tag := Label3D.new()
		tag.text = "CHECKPOINT"
		tag.font_size = 34
		tag.pixel_size = 0.007
		tag.modulate = Color(0.85, 0.9, 1.0)
		tag.outline_size = 10
		tag.outline_modulate = Color(0.08, 0.06, 0.1)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(x, 4.8, zc)
		add_child(tag)

func _build_crypt() -> void:
	var zc := z_center(FINISH_X)
	var stone := _stone_mat(Color(0.42, 0.4, 0.48))
	# facade: two flanks + pediment around a glowing doorway
	for zs in [-1.0, 1.0]:
		var flank := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(1.6, 5.0, 5.4)
		flank.mesh = fm
		flank.material_override = stone
		flank.position = Vector3(FINISH_X + 1.5, 2.5, zc + zs * 4.15)
		add_child(flank)
	var ped := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(2.6, 2.2, 14.6)
	ped.mesh = pm
	ped.material_override = stone
	ped.position = Vector3(FINISH_X + 1.5, 6.1, zc)
	add_child(ped)
	var glow := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.3, 4.4, 2.9)
	glow.mesh = gm
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.78, 0.4)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.66, 0.3)
	glow_mat.emission_energy_multiplier = 2.4
	glow.material_override = glow_mat
	glow.position = Vector3(FINISH_X + 2.1, 2.2, zc)
	add_child(glow)
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.72, 0.4)
	gl.light_energy = 2.6
	gl.omni_range = 8.0
	gl.position = Vector3(FINISH_X + 0.6, 2.4, zc)
	add_child(gl)
	# gate prop inside the doorway if the meshy asset exists
	var gate_glb := "res://assets/models/meshy/manor_gate.glb"
	if ResourceLoader.exists(gate_glb):
		var gate := MeshyProp.instance(gate_glb, 3.6)
		gate.rotation.y = PI / 2.0
		gate.position = Vector3(FINISH_X + 1.2, 0.0, zc)
		add_child(gate)
	var col_glb := "res://assets/models/meshy/broken_column.glb"
	if ResourceLoader.exists(col_glb):
		for zs in [-1.0, 1.0]:
			var col := MeshyProp.instance(col_glb, 3.0)
			col.position = Vector3(FINISH_X - 2.0, 0.0, zc + zs * 3.4)
			add_child(col)
	var tag := Label3D.new()
	tag.text = "THE CRYPT"
	tag.font_size = 72
	tag.pixel_size = 0.008
	tag.modulate = Color(1.0, 0.85, 0.5)
	tag.outline_size = 16
	tag.outline_modulate = Color(0.08, 0.06, 0.1)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(FINISH_X + 1.0, 8.0, zc)
	add_child(tag)
	# wall collider behind the finish plane so nobody runs out the back
	var wb := StaticBody3D.new()
	wb.collision_layer = 1
	wb.collision_mask = 0
	add_child(wb)
	var wc := CollisionShape3D.new()
	var ws := BoxShape3D.new()
	ws.size = Vector3(1.0, 5.0, 14.0)
	wc.shape = ws
	wc.position = Vector3(FINISH_X + 2.6, 2.0, zc)
	wb.add_child(wc)

func _build_dressing() -> void:
	# stone lanterns (meshy) at the plazas, box lanterns along the road
	var lant_glb := "res://assets/models/meshy/stone_lantern.glb"
	var meshy_spots := [2.0, 66.0, 138.0, 193.0]
	for x in meshy_spots:
		var zc := z_center(x)
		var hw := half_width(x)
		for zs in [-1.0, 1.0]:
			if ResourceLoader.exists(lant_glb):
				var sl := MeshyProp.instance(lant_glb, 1.5)
				sl.position = Vector3(x, 0.0, zc + zs * (hw - 0.6))
				add_child(sl)
				var ll := OmniLight3D.new()
				ll.light_color = Color(1.0, 0.7, 0.34)
				ll.light_energy = 1.6
				ll.omni_range = 4.5
				ll.position = Vector3(x, 1.6, zc + zs * (hw - 0.6))
				add_child(ll)
	# emissive box lanterns between (no lights — the glow material carries them)
	var side := 1.0
	for x in [10.0, 22.0, 34.0, 46.0, 58.0, 80.0, 92.0, 106.0, 118.0, 130.0, 156.0, 168.0, 186.0]:
		var zc2 := z_center(x)
		var hw2 := half_width(x)
		var lant := _make_lantern(false)
		lant.position = Vector3(x, 0.0, zc2 + side * (hw2 - 0.45))
		add_child(lant)
		side = -side
	# gravestone clusters (deterministic constants, decorative — off the walkway)
	var graves := [
		[7.0, 1.0, -14.0], [24.0, -1.0, 22.0], [40.0, 1.0, 8.0],
		[50.0, -1.0, -30.0], [82.0, 1.0, 12.0], [94.0, -1.0, -18.0],
		[110.0, 1.0, 28.0], [126.0, -1.0, -8.0], [144.0, 1.0, 16.0],
		[163.0, -1.0, -24.0], [185.0, 1.0, 6.0],
	]
	for g in graves:
		var gx := float(g[0])
		var gside := float(g[1])
		var zc3 := z_center(gx)
		var hw3 := half_width(gx)
		add_gravestone(self, Vector3(gx, 0.0, zc3 + gside * (hw3 - 0.55)), float(g[2]), 4.0)
	# drifting rock shards off in the void, so the fall has a middle distance
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.24, 0.22, 0.3)
	shard_mat.roughness = 1.0
	for sp in [Vector3(24.0, -3.2, -14.0), Vector3(64.0, -2.6, 13.0),
			Vector3(102.0, -3.6, -13.5), Vector3(142.0, -2.8, 12.0), Vector3(180.0, -3.4, -12.0)]:
		var shard := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 1.4
		sm.bottom_radius = 0.35
		sm.height = 2.0
		shard.mesh = sm
		shard.material_override = shard_mat
		shard.position = sp
		shard.rotation_degrees = Vector3(8.0, 40.0, -6.0)
		add_child(shard)

## Box-built glowing lantern (shared look with the old chapel-yard).
func _make_lantern(with_light: bool) -> Node3D:
	var root := Node3D.new()
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.09, 1.15, 0.09)
	post.mesh = pm
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.16, 0.13, 0.12)
	post.material_override = post_mat
	post.position.y = 0.57
	root.add_child(post)
	var cage := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.28, 0.32, 0.28)
	cage.mesh = cm
	var cage_mat := StandardMaterial3D.new()
	cage_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cage_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cage_mat.albedo_color = Color(1.0, 0.76, 0.38, 0.55)
	cage_mat.emission_enabled = true
	cage_mat.emission = Color(1.0, 0.7, 0.3)
	cage_mat.emission_energy_multiplier = 1.9
	cage.material_override = cage_mat
	cage.position.y = 1.3
	root.add_child(cage)
	var cap := MeshInstance3D.new()
	var capm := SphereMesh.new()
	capm.radius = 0.06
	capm.height = 0.12
	cap.mesh = capm
	cap.material_override = post_mat
	cap.position.y = 1.5
	root.add_child(cap)
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.34)
		l.light_energy = 2.1
		l.omni_range = 4.2
		l.position.y = 1.35
		root.add_child(l)
	return root

## Shared gravestone builder (also used by the RAISE THE DEAD curse).
static func add_gravestone(parent: Node3D, pos: Vector3, yaw_deg: float, tilt_deg: float,
		trim_color := Color.TRANSPARENT) -> Node3D:
	var grave_mat := StandardMaterial3D.new()
	grave_mat.albedo_color = Color(0.33, 0.32, 0.38)
	grave_mat.roughness = 1.0
	var stone := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.7, 0.14)
	body.mesh = bm
	body.material_override = grave_mat
	body.position.y = 0.35
	stone.add_child(body)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.25
	tm.bottom_radius = 0.25
	tm.height = 0.14
	top.mesh = tm
	top.material_override = grave_mat
	top.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	top.position.y = 0.7
	stone.add_child(top)
	if trim_color.a > 0.0:
		var trim := MeshInstance3D.new()
		var trm := BoxMesh.new()
		trm.size = Vector3(0.54, 0.08, 0.18)
		trim.mesh = trm
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = trim_color
		tmat.emission_enabled = true
		tmat.emission = trim_color
		tmat.emission_energy_multiplier = 1.4
		trim.material_override = tmat
		trim.position.y = 0.62
		stone.add_child(trim)
	stone.position = pos
	stone.rotation_degrees = Vector3(0.0, yaw_deg, tilt_deg)
	parent.add_child(stone)
	return stone
