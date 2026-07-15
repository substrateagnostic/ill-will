class_name ProcessionBoardPath
extends Node3D
## The carriage drive: a looping 24-space rail around the manor grounds, built
## in trail.gd's parametric style (every position is a pure function of the
## space index, so the couch and a net mirror render byte-identical geometry).
## The space GRAMMAR lives in board_spaces.gd; this node owns the WORLD — stone
## positions, pawns, furniture, the roving Codicil beacon, and the animated hop.
##
## Board furniture prefers tonight's generated Meshy props (the SWAP-POINT paths
## below); when a generated GLB is absent it falls back to a committed estate
## prop or a trail-stone primitive, so the drive always renders.

const SPACES := 24
const S := preload("res://estate/procession/board_spaces.gd")

## Fixed base layout — 24 stones, effects all visible (board_spaces.TABLE).
## Counts: 6 SHRINE · 5 WEEPING GRAVE · 3 STALL · 1 CODICIL(home) · 2 SÉANCE ·
## 2 TOLLGATE · 2 VENDETTA · 3 BLANK. The Codicil then ROVES over this ring.
const LAYOUT: Array[String] = [
	S.BLANK,         # 0  the manor gate / start line
	S.SHRINE,        # 1
	S.WEEPING_GRAVE, # 2
	S.STALL,         # 3
	S.SHRINE,        # 4
	S.SEANCE,        # 5
	S.WEEPING_GRAVE, # 6
	S.SHRINE,        # 7
	S.TOLLGATE,      # 8
	S.VENDETTA,      # 9
	S.SHRINE,        # 10
	S.WEEPING_GRAVE, # 11
	S.STALL,         # 12
	S.CODICIL,       # 13  the Codicil's opening berth
	S.SHRINE,        # 14
	S.SEANCE,        # 15
	S.WEEPING_GRAVE, # 16
	S.BLANK,         # 17
	S.TOLLGATE,      # 18
	S.SHRINE,        # 19
	S.VENDETTA,      # 20
	S.WEEPING_GRAVE, # 21
	S.STALL,         # 22
	S.BLANK,         # 23
]

# ---- SWAP-POINTS for the incoming generated Meshy batch (waypoint stone,
# tollgate arch, codicil pedestal, signpost, hearse). If a file exists in the
# worktree it is used; otherwise the FALLBACK committed prop / primitive draws.
const GEN_WAYPOINT := "res://assets/models/meshy/generated/waypoint_stone.glb"
const GEN_TOLLARCH := "res://assets/models/meshy/generated/tollgate_arch.glb"
const GEN_CODICIL := "res://assets/models/meshy/generated/codicil_pedestal.glb"
const GEN_SIGNPOST := "res://assets/models/meshy/generated/signpost.glb"
const GEN_HEARSE := "res://assets/models/meshy/generated/hearse.glb"
# Committed fallbacks (verified present in assets/models/meshy/).
const FB_TOLLARCH := "res://assets/models/meshy/manor_gate.glb"
const FB_CODICIL := "res://assets/models/meshy/gilded_pot.glb"
const FB_STALL := "res://assets/models/meshy/market_stall.glb"
const FB_LANTERN := "res://assets/models/meshy/stone_lantern.glb"
const FB_GRAVE := "res://assets/models/meshy/broken_column.glb"
const FB_HEARSE := "res://assets/models/meshy/go_kart.glb"

# Ellipse geometry (manor-grounds scale). Space 0 sits at the manor gate.
const CENTER := Vector3(0.0, 0.0, -3.0)
const RADIUS_X := 17.0
const RADIUS_Z := 12.0

var spaces: Array = []            # [{index, type, pos}] — owner lives in owners{}
var owners := {}                  # tollgate space -> seat index that owns it
var grave_monument := {}          # weeping-grave space -> owner seat (toll payee)
var pawns := {}                   # seat -> Node3D
var stone_nodes: Array = []
var beacon: Node3D = null
var beacon_index := 13

func space_pos(i: int) -> Vector3:
	# Even spacing around the drive; space 0 at the gate (angle -90°, +Z front).
	var ang := TAU * float(posmod(i, SPACES)) / float(SPACES) - PI * 0.5
	# A gentle rise on the far side so the whole loop reads in a raked camera.
	var far := 0.5 * (1.0 - cos(ang - PI * 0.5))
	return CENTER + Vector3(cos(ang) * RADIUS_X, 0.04 + far * 0.6, sin(ang) * RADIUS_Z)

## Seat offset so four pawns share a stone without z-fighting.
func _seat_offset(seat: int) -> Vector3:
	return Vector3(0.42 * (seat - 1.5), 0.0, 0.34 * float((seat % 2) * 2 - 1))

func build(players: Array, monuments: Array) -> void:
	_build_ground()
	spaces.clear()
	stone_nodes.clear()
	for i in SPACES:
		var type: String = LAYOUT[i]
		spaces.append({"index": i, "type": type, "pos": space_pos(i)})
		_build_stone(i, type)
	_map_monuments(monuments, players)
	_build_furniture()
	for pl in players:
		var pawn := _make_pawn(pl)
		add_child(pawn)
		pawns[int(pl.index)] = pawn
		seat_pawn(int(pl.index), 0)
	_build_beacon()

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 52)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.13, 0.14, 0.12)
	gmat.roughness = 1.0
	ground.material_override = gmat
	ground.position = CENTER + Vector3(0, -0.02, 0)
	add_child(ground)
	# The drive itself — a darker ribbon torus hint under the stones.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS_X - 1.4
	tm.outer_radius = RADIUS_X + 1.4
	tm.rings = 48
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.09, 0.09, 0.11)
	ring.material_override = rmat
	ring.position = CENTER + Vector3(0, -0.01, 0)
	ring.scale = Vector3(1.0, 1.0, RADIUS_Z / RADIUS_X)
	ring.rotation_degrees.x = 90.0
	add_child(ring)

func _build_stone(i: int, type: String) -> void:
	var s := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 0.95
	mesh.height = 0.16
	s.mesh = mesh
	var mat := StandardMaterial3D.new()
	var col: Color = S.color(type)
	mat.albedo_color = col.lerp(Color(0.2, 0.2, 0.24), 0.35)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.25
	mat.roughness = 0.8
	s.material_override = mat
	add_child(s)
	s.global_position = space_pos(i)
	stone_nodes.append(s)
	# Icon + effect label floating over the stone (all effects announced).
	var tag := Label3D.new()
	tag.text = "%s\n%s" % [S.icon(type), S.display_name(type)]
	tag.font_size = 40
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = col
	tag.outline_size = 10
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.position = space_pos(i) + Vector3(0, 1.1, 0)
	add_child(tag)

## Bind each existing player monument to a weeping-grave stone (deterministic
## by order), so a rival landing there pays its owner the toll — the beloved
## MP "Orb" mechanic made permanent across nights (spec §engine).
func _map_monuments(monuments: Array, players: Array) -> void:
	grave_monument.clear()
	var graves: Array = []
	for i in SPACES:
		if LAYOUT[i] == S.WEEPING_GRAVE:
			graves.append(i)
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
			_mark_grave_monument(graves[g], (m as Dictionary).get("color", "ffffff"))
			g += 1

func _mark_grave_monument(space_idx: int, color_html) -> void:
	var col := Color.from_string(str(color_html), Color.WHITE)
	var head := _prop(GEN_WAYPOINT, FB_GRAVE, 1.5, col)
	head.global_position = space_pos(space_idx) + Vector3(0, 0.08, 0)
	add_child(head)

func _build_furniture() -> void:
	for i in SPACES:
		var type: String = LAYOUT[i]
		var here := space_pos(i)
		match type:
			S.TOLLGATE:
				var arch := _prop(GEN_TOLLARCH, FB_TOLLARCH, 3.4)
				arch.global_position = here + Vector3(0, 0.08, 0)
				arch.look_at_from_position(arch.global_position, CENTER, Vector3.UP)
				add_child(arch)
			S.STALL:
				var stall := _prop(GEN_SIGNPOST, FB_STALL, 2.2)
				stall.global_position = here + Vector3(1.2, 0.08, 0)
				add_child(stall)
			S.SHRINE:
				var lamp := _prop(GEN_WAYPOINT, FB_LANTERN, 1.6)
				lamp.global_position = here + Vector3(0, 0.08, -1.1)
				add_child(lamp)
	# The manor gate anchors space 0; a hearse waits just inside it.
	var gate := _prop(GEN_TOLLARCH, FB_TOLLARCH, 5.0)
	gate.global_position = space_pos(0) + Vector3(0, 0.08, 1.4)
	gate.look_at_from_position(gate.global_position, CENTER, Vector3.UP)
	add_child(gate)
	var hearse := _prop(GEN_HEARSE, FB_HEARSE, 2.0)
	hearse.global_position = space_pos(0) + Vector3(-2.4, 0.08, 1.2)
	add_child(hearse)
	var manor := Label3D.new()
	manor.text = "THE MANOR"
	manor.font_size = 64
	manor.pixel_size = 0.008
	manor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	manor.modulate = Color(1, 0.9, 0.5)
	manor.outline_size = 14
	manor.position = space_pos(0) + Vector3(0, 3.2, 1.4)
	add_child(manor)

func _build_beacon() -> void:
	beacon = _prop(GEN_CODICIL, FB_CODICIL, 1.8, Color(0.96, 0.86, 0.38))
	add_child(beacon)
	var glow := Label3D.new()
	glow.name = "BeaconTag"
	glow.text = "◆ CODICIL ◆"
	glow.font_size = 44
	glow.pixel_size = 0.007
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.modulate = Color(1, 0.9, 0.4)
	glow.outline_size = 12
	glow.position = Vector3(0, 2.4, 0)
	beacon.add_child(glow)
	set_beacon(beacon_index)

func set_beacon(i: int) -> void:
	beacon_index = posmod(i, SPACES)
	if beacon:
		beacon.global_position = space_pos(beacon_index) + Vector3(0, 0.1, 0)

## Instance a generated GLB if present, else the committed fallback, else a
## tinted primitive. Never returns null; purely visual.
func _prop(gen_path: String, fallback_path: String, height: float, tint := Color(0, 0, 0, 0)) -> Node3D:
	var path := gen_path if ResourceLoader.exists(gen_path) else fallback_path
	if ResourceLoader.exists(path):
		return MeshyProp.instance(path, height)
	# Primitive fallback so a fresh checkout with no props still renders.
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
	# A crown of identity: shape glyph + name in the player's colour.
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

func seat_pawn(seat: int, space_idx: int) -> void:
	if pawns.has(seat):
		pawns[seat].global_position = space_pos(space_idx) + _seat_offset(seat)

## Animated hop along the ring from -> to (handles wraparound). Returns the
## tween so the caller can await the whole board's move at once.
func advance_pawn(seat: int, from_idx: int, spaces_moved: int) -> Tween:
	var tw := create_tween()
	if not pawns.has(seat) or spaces_moved <= 0:
		tw.tween_interval(0.01)
		return tw
	for step in range(1, spaces_moved + 1):
		var idx := posmod(from_idx + step, SPACES)
		var target := space_pos(idx) + _seat_offset(seat)
		tw.tween_property(pawns[seat], "global_position", target + Vector3(0, 0.55, 0), 0.13) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(pawns[seat], "global_position", target, 0.11) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(Sfx.play.bind("card", -12.0, 0.15))
	return tw

func type_at(i: int) -> String:
	return LAYOUT[posmod(i, SPACES)]

func is_codicil_here(i: int) -> bool:
	return posmod(i, SPACES) == beacon_index

## Toll payee if a rival's monument stands on this grave, else -1.
func grave_owner(space_idx: int) -> int:
	return int(grave_monument.get(posmod(space_idx, SPACES), -1))

func tollgate_owner(space_idx: int) -> int:
	return int(owners.get(posmod(space_idx, SPACES), -1))

func set_tollgate_owner(space_idx: int, seat: int) -> void:
	owners[posmod(space_idx, SPACES)] = seat

## Camera anchor for a REVEAL push-in: slightly above and outside the stone.
func reveal_anchor(space_idx: int) -> Vector3:
	var p := space_pos(space_idx)
	var out := (p - CENTER)
	out.y = 0
	if out.length() > 0.01:
		out = out.normalized()
	return p + out * 4.2 + Vector3(0, 3.4, 0)
