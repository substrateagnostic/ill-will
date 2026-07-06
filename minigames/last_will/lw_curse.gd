class_name LWCurse
extends Node3D
## An installed curse — a stretch of the procession route condemned by the
## dead. Four kinds:
##   scythe — an endless pendulum blade over the stretch (author-keeled)
##   grease — the flagstones lose all grip (accel crushed, momentum keeps)
##   gale   — a crosswind bursts across the stretch toward the void
##   stones — a rank of gravestones blocks the walkway, save one gap
## Every curse installs visibly in the author's color with a NAME PLAQUE
## (authorship forever, like Par traps): kills within 3s of a curse touch pay
## the author royalties and land in kill_events with cause = the curse slug.
## Ticked by the controller only while the race runs.

const TOUCH_GRACE := 3.0     # seconds a curse touch stays lethal-attributable
const GALE_PERIOD := 3.4
const GALE_ACTIVE := 1.3
const GALE_FORCE := 6.2      # impulse per second while the burst blows

var kind := "grease"
var author := -1
var author_name := ""
var author_color := Color.WHITE
var slot: Dictionary = {}
var install_order := 0

var owner_game: Node = null
var _cx := 0.0
var _len := 8.0
var _t := 0.0
var _gale_side := 1.0        # +1 pushes toward +z edge
var _stones_gap_z := 0.0
var _pendulum: LWPendulum
var _gale_parts: Array = []  # CPUParticles3D, toggled by burst phase
var _gale_sheets: Array = [] # translucent wind planes, alpha by burst phase
var _install_nodes: Array = []   # visuals that rise in on install (live only)

## side_seed: 0/1 drawn from the game rng at install (gale direction /
## stones gap side) so the receipt stays deterministic.
func setup(p_slot: Dictionary, p_kind: String, p_author: int, a_name: String,
		a_color: Color, side_seed: int, p_owner: Node) -> void:
	slot = p_slot
	kind = p_kind
	author = p_author
	author_name = a_name
	author_color = a_color
	owner_game = p_owner
	_cx = float(p_slot.x)
	_len = float(p_slot.len)
	_gale_side = 1.0 if side_seed % 2 == 0 else -1.0
	global_position = Vector3(_cx, 0.0, LWCourse.z_center(_cx))
	match kind:
		"scythe":
			_build_scythe()
		"grease":
			_build_grease()
		"gale":
			_build_gale()
		"stones":
			_build_stones(side_seed)
	_build_plaque()

func slug() -> String:
	return kind

func title() -> String:
	match kind:
		"scythe": return "THE SUMMONED SCYTHE"
		"grease": return "GREASED FLAGSTONES"
		"gale": return "A GUST CORRIDOR"
		_: return "A RANK OF THE DEAD"

# ================================================================ builds
func _build_scythe() -> void:
	_pendulum = LWPendulum.new()
	add_child(_pendulum)
	_pendulum.setup(global_position, 90.0, -1, owner_game, author_color)
	_pendulum.set_curse_identity(author, "scythe", author_name, author_color)

func _build_grease() -> void:
	var zc := LWCourse.z_center(_cx)
	var hw := LWCourse.half_width(_cx)
	var sheen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(_len, 0.04, hw * 2.0 - 0.2)
	sheen.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gc := author_color.lerp(Color(0.65, 0.9, 0.7), 0.35)
	mat.albedo_color = Color(gc.r, gc.g, gc.b, 0.30)
	mat.metallic = 0.9
	mat.roughness = 0.05
	mat.emission_enabled = true
	mat.emission = gc
	mat.emission_energy_multiplier = 0.35
	sheen.material_override = mat
	sheen.position = Vector3(0.0, 0.03, zc - global_position.z)
	add_child(sheen)
	_install_nodes.append(sheen)
	# slow oily drips at the stretch edges
	var drips := CPUParticles3D.new()
	drips.amount = 16
	drips.lifetime = 1.4
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = Vector3(_len * 0.5, 0.05, hw - 0.2)
	drips.direction = Vector3.UP
	drips.spread = 10.0
	drips.gravity = Vector3(0, 0.4, 0)
	drips.initial_velocity_min = 0.1
	drips.initial_velocity_max = 0.3
	drips.scale_amount_min = 0.25
	drips.scale_amount_max = 0.5
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	drips.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(gc.r, gc.g, gc.b, 0.5)
	drips.material_override = dmat
	drips.position.y = 0.1
	drips.emitting = true
	add_child(drips)

func _build_gale() -> void:
	var zc := LWCourse.z_center(_cx)
	var hw := LWCourse.half_width(_cx)
	# wind sheets: translucent planes leaning with the blow direction
	for i in 3:
		var sheet := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(_len * 0.28, 1.4, 0.06)
		sheet.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var gc := author_color.lerp(Color(0.8, 0.95, 1.0), 0.55)
		mat.albedo_color = Color(gc.r, gc.g, gc.b, 0.0)
		mat.emission_enabled = true
		mat.emission = gc
		mat.emission_energy_multiplier = 1.1
		sheet.material_override = mat
		sheet.position = Vector3(-_len * 0.32 + _len * 0.32 * float(i), 0.9,
			zc - global_position.z - _gale_side * (hw * 0.5 - 0.4 * float(i)))
		sheet.rotation_degrees = Vector3(0.0, 0.0, -_gale_side * 16.0)
		add_child(sheet)
		_gale_sheets.append(mat)
	# streaming wind particles, toggled by the burst
	var wind := CPUParticles3D.new()
	wind.amount = 34
	wind.lifetime = 0.7
	wind.local_coords = false
	wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wind.emission_box_extents = Vector3(_len * 0.5, 0.6, 0.3)
	wind.direction = Vector3(0, 0, _gale_side)
	wind.spread = 8.0
	wind.gravity = Vector3.ZERO
	wind.initial_velocity_min = 6.0
	wind.initial_velocity_max = 9.0
	wind.scale_amount_min = 0.3
	wind.scale_amount_max = 0.7
	var wm := SphereMesh.new()
	wm.radius = 0.06
	wm.height = 0.12
	wind.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gc2 := author_color.lerp(Color(0.8, 0.95, 1.0), 0.55)
	wmat.albedo_color = Color(gc2.r, gc2.g, gc2.b, 0.5)
	wind.material_override = wmat
	wind.position = Vector3(0.0, 0.9, zc - global_position.z - _gale_side * (hw - 0.3))
	wind.emitting = false
	add_child(wind)
	_gale_parts.append(wind)

func _build_stones(side_seed: int) -> void:
	var zc := LWCourse.z_center(_cx)
	var hw := LWCourse.half_width(_cx)
	var gap_side := 1.0 if (side_seed / 2) % 2 == 0 else -1.0
	_stones_gap_z = zc + gap_side * (hw - 0.85)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var z := zc - hw + 0.35
	var i := 0
	while z <= zc + hw - 0.35:
		if absf(z - _stones_gap_z) > 0.95:
			var stone := LWCourse.add_gravestone(self,
				Vector3(0.0, 0.0, z - global_position.z),
				90.0 + 9.0 * float((i * 7) % 3 - 1), 3.0 * float((i * 5) % 3 - 1),
				author_color)
			stone.scale = Vector3(1.35, 1.6, 1.35)
			_install_nodes.append(stone)
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(0.35, 2.2, 0.75)
			cs.shape = bx
			cs.position = Vector3(0.0, 1.1, z - global_position.z)
			body.add_child(cs)
		z += 0.8
		i += 1

func _build_plaque() -> void:
	# the author's plaque: a trimmed headstone at the stretch edge + name tag
	var zc := LWCourse.z_center(_cx)
	var hw := LWCourse.half_width(_cx)
	var pz := zc + hw + 0.75
	var stone := LWCourse.add_gravestone(self,
		Vector3(0.0, 0.0, pz - global_position.z), 8.0, -3.0, author_color)
	stone.scale = Vector3(1.2, 1.2, 1.2)
	var tag := Label3D.new()
	tag.text = "%s %s\n%s" % [PlayerBadge.glyph(author), author_name, title()]
	tag.font_size = 34
	tag.pixel_size = 0.0078
	tag.modulate = author_color
	tag.outline_size = 10
	tag.outline_modulate = Color(0.06, 0.05, 0.09)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0.0, 2.05, pz - global_position.z)
	add_child(tag)

## Live-mode install flourish: plaque stone + visuals rise from the sod.
## Purely visual — colliders and effects are live the instant setup() ran.
func play_install() -> void:
	for n in _install_nodes:
		if n is Node3D:
			var node := n as Node3D
			var target: Vector3 = node.position
			node.position.y = target.y - 1.4
			var tw := create_tween()
			tw.tween_property(node, "position:y", target.y, 0.7) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ================================================================ tick
func in_stretch(pawn: LWPawn) -> bool:
	if absf(pawn.global_position.x - _cx) > _len * 0.5:
		return false
	return absf(pawn.global_position.z - LWCourse.z_center(pawn.global_position.x)) \
		<= LWCourse.half_width(pawn.global_position.x) + 0.4

func tick(delta: float) -> void:
	_t += delta
	match kind:
		"scythe":
			if _pendulum != null:
				_pendulum.tick(delta)
		"grease":
			for pawn in owner_game.living_pawns():
				if in_stretch(pawn) and pawn.global_position.y < 0.6:
					pawn.terrain_accel *= 0.22
					pawn.terrain_speed *= 1.06
					pawn.note_curse_touch(author, "grease", author_name, author_color)
		"gale":
			var phase := fmod(_t, GALE_PERIOD)
			var active := phase < GALE_ACTIVE
			for p in _gale_parts:
				(p as CPUParticles3D).emitting = active
			for m in _gale_sheets:
				(m as StandardMaterial3D).albedo_color.a = 0.26 if active else 0.05
			if active:
				var dir := Vector3(0.0, 0.0, _gale_side)
				for pawn in owner_game.living_pawns():
					if in_stretch(pawn):
						pawn.apply_central_impulse(dir * GALE_FORCE * delta)
						pawn.note_curse_touch(author, "gale", author_name, author_color)
		"stones":
			pass   # static malice

## For the bots: where is the way through a stones rank
func stones_gap_z() -> float:
	return _stones_gap_z

func center_x() -> float:
	return _cx
