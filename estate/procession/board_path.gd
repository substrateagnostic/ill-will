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

# ---- SWAP-POINTS for the shipped meshy-6 gothic batch (docs/verify/
# meshy-forge-VERIFY.md). Every board fixture now resolves to a purpose-built
# funeral-gothic GLB; the committed props below remain as fallbacks so a fresh
# checkout that lacks the generated batch still renders a coherent drive.
const GEN_DIR := "res://assets/models/meshy/generated/"
const GEN_WAYPOINT := GEN_DIR + "board_waypoint_lantern.glb"   # green-man marker stone
const GEN_TOLLARCH := GEN_DIR + "board_tollgate_arch.glb"      # wrought-iron gate
const GEN_CODICIL := GEN_DIR + "board_codicil_pedestal.glb"    # fluted column + scroll
const GEN_SIGNPOST := GEN_DIR + "board_grim_signpost.glb"      # crooked multi-arrow post
const GEN_HEARSE := GEN_DIR + "board_hearse_cart.glb"          # draped black hearse
const GEN_CRYPT := GEN_DIR + "board_crypt_door.glb"            # stone arch + iron door
const GEN_PLANCHETTE := GEN_DIR + "board_planchette.glb"       # séance pointer
# Estate perimeter dressing (all gothic, all KEEP).
const GEN_ANGEL := GEN_DIR + "estate_broken_angel.glb"
const GEN_WELL := GEN_DIR + "estate_covered_well.glb"
const GEN_DEADTREE := GEN_DIR + "estate_dead_tree.glb"
const GEN_FOUNTAIN := GEN_DIR + "estate_dry_fountain.glb"
const GEN_TOPIARY := GEN_DIR + "estate_hedge_topiary.glb"
const GEN_IRONGATE := GEN_DIR + "estate_iron_gate.glb"         # thin (0.22) fence section
const GEN_LAMPPOST := GEN_DIR + "estate_lamppost.glb"          # glowing lantern head
const GEN_WHEELBARROW := GEN_DIR + "estate_wheelbarrow.glb"
# Headstone variety for WEEPING GRAVE stones — assigned deterministically by
# space index (never randi() in a visual path; the receipt must not shift).
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
# Committed fallbacks (verified present in assets/models/meshy/).
const FB_TOLLARCH := "res://assets/models/meshy/manor_gate.glb"
const FB_CODICIL := "res://assets/models/meshy/gilded_pot.glb"
const FB_LANTERN := "res://assets/models/meshy/stone_lantern.glb"
const FB_CRATE := "res://assets/models/meshy/crate.glb"
const FB_GRAVE := "res://assets/models/meshy/broken_column.glb"
const FB_COLUMN := "res://assets/models/meshy/broken_column.glb"
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
	gmat.albedo_color = Color(0.055, 0.065, 0.085)   # cool damp lawn under moonlight
	gmat.roughness = 1.0
	ground.material_override = gmat
	ground.position = CENTER + Vector3(0, -0.02, 0)
	add_child(ground)
	# The drive itself — a paler flagstone ribbon torus under the stones so the
	# loop reads as a walked path even in the dark.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS_X - 1.4
	tm.outer_radius = RADIUS_X + 1.4
	tm.rings = 48
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.16, 0.17, 0.205)
	rmat.roughness = 0.95
	ring.material_override = rmat
	ring.position = CENTER + Vector3(0, -0.01, 0)
	ring.scale = Vector3(1.0, 1.0, RADIUS_Z / RADIUS_X)
	ring.rotation_degrees.x = 90.0
	add_child(ring)

func _build_stone(i: int, type: String) -> void:
	var pos := space_pos(i)
	var col: Color = S.color(type)
	# The marker is a DARK STONE puck — the colour identity now lives in a lit
	# emissive rim ring (bloom under MOONLIT) rather than a flat toy-bright face,
	# so each space reads as a carved, moonlit stone marker on the drive.
	var s := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.86
	mesh.bottom_radius = 0.98
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
	# Emissive rim ring — the lit "rune circle" that carries the colour code.
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.74
	tm.outer_radius = 0.90
	tm.rings = 8
	tm.ring_segments = 28
	rim.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col.darkened(0.2)
	rmat.emission_enabled = true
	rmat.emission = col
	rmat.emission_energy_multiplier = 2.6
	rmat.roughness = 0.5
	rim.material_override = rmat
	rim.rotation_degrees.x = 90.0
	add_child(rim)
	rim.global_position = pos + Vector3(0, 0.10, 0)
	# A small ENGRAVED 3D icon lying flat on the stone (the space-type sigil),
	# emissive so it glows as an inlaid rune under moonlight.
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
	# Billboard identity label above the stone — icon + name, colour-keyed. Kept
	# as the colour-blind-safe text tag (never colour alone).
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

## A weeping grave that a rival's monument OWNS gets a small owner-coloured votive
## flame beside its (already-placed) headstone — the toll marker. Purely visual;
## the base headstone for every grave is placed in _build_furniture.
func _mark_grave_monument(space_idx: int, color_html) -> void:
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
	votive.global_position = space_pos(space_idx) + Vector3(0.55, 0.17, 0.45)

## Seat a prop under this node, THEN place it — global_position/look_at both need
## the node inside the tree, so add_child must come first.
func _place(node: Node3D, pos: Vector3) -> void:
	add_child(node)
	node.global_position = pos

func _place_facing(node: Node3D, pos: Vector3, target: Vector3) -> void:
	add_child(node)
	node.look_at_from_position(pos, target, Vector3.UP)

func _build_furniture() -> void:
	for i in SPACES:
		var type: String = LAYOUT[i]
		var here := space_pos(i)
		# Push furniture a touch OUTBOARD of the stone so pawns own the disc and
		# the drive stays readable as a path.
		var out := _outward(i)
		match type:
			S.TOLLGATE:
				_place_facing(_prop(GEN_TOLLARCH, FB_TOLLARCH, 3.4), here + Vector3(0, 0.06, 0), CENTER)
			S.STALL:
				# A gothic peddler's stash: a crate under a stone lantern (the
				# striped market tent is retired — it read carnival, not funeral).
				_place(_prop(FB_CRATE, FB_CRATE, 0.9), here + out * 1.15 + Vector3(0, 0.06, 0))
				_place(_prop(FB_LANTERN, FB_LANTERN, 1.5), here + out * 1.15 + Vector3(0.7, 0.06, 0.2))
			S.SHRINE:
				# A lit lamppost — small mercy on the drive, and a warm glow point
				# that blooms against the cool moonlight.
				_place(_prop(GEN_LAMPPOST, FB_LANTERN, 2.4), here + out * 1.1 + Vector3(0, 0.06, 0))
			S.WEEPING_GRAVE:
				# Deterministic headstone variety by space index (no RNG).
				_place(_prop(_grave_variant_for(i), FB_GRAVE, 1.7), here + out * 0.9 + Vector3(0, 0.06, 0))
			S.SEANCE:
				# The planchette lies flat beside the circle, séance-ready.
				_place(_prop(GEN_PLANCHETTE, FB_LANTERN, 0.35), here + out * 1.05 + Vector3(0, 0.06, 0))
	_build_manor_gate()
	_build_perimeter()

## Grave variant for a weeping-grave space — pure function of the space index so
## the couch and any net mirror render identical headstones.
func _grave_variant_for(space_idx: int) -> String:
	return GRAVE_VARIANTS[posmod(space_idx, GRAVE_VARIANTS.size())]

## Unit vector pointing from the drive centre outward through space `i` (in the
## ellipse's world scale, then normalised) — used to seat furniture just outboard.
func _outward(i: int) -> Vector3:
	var v := space_pos(i) - CENTER
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD

## The manor gate + hearse cluster and the grim signpost anchor space 0 (start).
func _build_manor_gate() -> void:
	var start := space_pos(0)
	var out := _outward(0)
	_place_facing(_prop(GEN_TOLLARCH, FB_TOLLARCH, 5.0), start + out * 1.6 + Vector3(0, 0.06, 0), CENTER)
	# The hearse waits just inside the gate — the pink kart is retired.
	_place_facing(_prop(GEN_HEARSE, FB_HEARSE, 2.1), start + out * 1.4 + Vector3(-2.6, 0.06, 0), start)
	# A crooked signpost at the fork tells the mourners which way the wake turns.
	_place(_prop(GEN_SIGNPOST, FB_LANTERN, 2.6), start + Vector3(2.4, 0.06, 0.4))
	var manor := Label3D.new()
	manor.text = "THE MANOR"
	manor.font_size = 64
	manor.pixel_size = 0.008
	manor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	manor.modulate = Color(1, 0.9, 0.5)
	manor.outline_size = 14
	manor.outline_modulate = Color(0, 0, 0, 0.9)
	manor.position = start + out * 1.6 + Vector3(0, 3.6, 0)
	add_child(manor)

## Sparse, deterministic perimeter dressing OUTSIDE the drive ring. Every entry
## is placed by a fixed angle/radius so nothing here draws from the sim RNG.
## Kept tasteful — the drive must always read clearly as a loop.
func _build_perimeter() -> void:
	# {path, angle_deg, radius_out, height}. Angles avoid the manor gate (-90°).
	var ring: Array = [
		{"p": GEN_CRYPT, "a": 205.0, "o": 1.62, "h": 3.4},
		{"p": GEN_DEADTREE, "a": 250.0, "o": 1.70, "h": 4.3},
		{"p": FB_COLUMN, "a": 20.0, "o": 1.55, "h": 2.5},
		{"p": GEN_ANGEL, "a": 65.0, "o": 1.58, "h": 3.0},
		{"p": GEN_WELL, "a": 115.0, "o": 1.66, "h": 2.4},
		{"p": GEN_IRONGATE, "a": 150.0, "o": 1.50, "h": 2.3},
		{"p": GEN_FOUNTAIN, "a": 300.0, "o": 1.66, "h": 1.4},
		{"p": GEN_TOPIARY, "a": 335.0, "o": 1.58, "h": 2.6},
		{"p": GEN_DEADTREE, "a": 35.0, "o": 1.78, "h": 3.6},
		{"p": GEN_IRONGATE, "a": 130.0, "o": 1.50, "h": 2.3},
		{"p": GEN_WHEELBARROW, "a": 172.0, "o": 1.40, "h": 1.1},
	]
	for e in ring:
		var ang := deg_to_rad(float(e["a"]))
		var o := float(e["o"])
		var p := CENTER + Vector3(cos(ang) * RADIUS_X * o, 0.06, sin(ang) * RADIUS_Z * o)
		_place(_prop(String(e["p"]), FB_COLUMN, float(e["h"])), p)
	# A low dry-fountain centrepiece far at the back of the courtyard — a focal
	# silhouette for the flyover that never blocks the readable ring of stones.
	_place(_prop(GEN_FOUNTAIN, FB_COLUMN, 1.6), CENTER + Vector3(0, 0.02, -1.0))

func _build_beacon() -> void:
	beacon = _prop(GEN_CODICIL, FB_CODICIL, 2.0, Color(0.96, 0.86, 0.38))
	add_child(beacon)
	# A gold OMNI glow so the objective marker is the brightest thing on the drive
	# — the one warm pool of light in the moonlight (shadowless; perf-cheap).
	var lamp := OmniLight3D.new()
	lamp.name = "BeaconGlow"
	lamp.light_color = Color(1.0, 0.86, 0.42)
	lamp.light_energy = 3.2
	lamp.omni_range = 8.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 1.6, 0)
	beacon.add_child(lamp)
	# An emissive halo disc at the base so the pedestal reads as consecrated.
	var halo := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 1.05
	hm.bottom_radius = 1.05
	hm.height = 0.04
	halo.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.2, 0.16, 0.06)
	hmat.emission_enabled = true
	hmat.emission = Color(1.0, 0.85, 0.4)
	hmat.emission_energy_multiplier = 2.4
	halo.material_override = hmat
	halo.position = Vector3(0, 0.12, 0)
	beacon.add_child(halo)
	var glow := Label3D.new()
	glow.name = "BeaconTag"
	glow.text = "◆ THE CODICIL ◆"
	glow.font_size = 48
	glow.pixel_size = 0.007
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.modulate = Color(1, 0.92, 0.5)
	glow.outline_size = 14
	glow.outline_modulate = Color(0, 0, 0, 0.92)
	glow.position = Vector3(0, 2.7, 0)
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

## Type-aware landing framing (doc 24 F3): each event gets a pose that expresses
## it. Returns {pos, look}. A WEEPING GRAVE is shot low, looking UP at the
## headstone; the CODICIL gets a hero low angle so its glow flares; a SHRINE
## reads warm from a shallow rise; the rest use the generic above-and-outside
## anchor. Pure geometry — no rng, no sim read.
func reveal_shot(space_idx: int, type: String) -> Dictionary:
	var p := space_pos(space_idx)
	var out := (p - CENTER)
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	match type:
		S.WEEPING_GRAVE:
			# Low and close, looking UP the headstone (which sits outboard at 0.9).
			return {"pos": p + out * 2.7 + Vector3(0, 1.2, 0),
				"look": p + out * 0.9 + Vector3(0, 1.4, 0)}
		S.CODICIL:
			# Hero low angle into the pedestal's gold glow.
			return {"pos": p + out * 3.4 + Vector3(0, 1.9, 0),
				"look": p + Vector3(0, 1.6, 0)}
		S.SHRINE:
			# A shallow warm rise on the lamppost mercy.
			return {"pos": p + out * 3.2 + Vector3(0, 2.6, 0),
				"look": p + Vector3(0, 0.9, 0)}
		S.SEANCE:
			# Slightly higher so the spinning planchette dial reads flat-on.
			return {"pos": p + out * 3.0 + Vector3(0, 3.2, 0),
				"look": p + out * 1.0 + Vector3(0, 0.2, 0)}
		_:
			return {"pos": p + out * 3.4 + Vector3(0, 2.8, 0),
				"look": p + Vector3(0, 0.7, 0)}
