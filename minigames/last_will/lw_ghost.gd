class_name LWGhostSeat
extends Node3D
## Spectral onlooker: after willing, the dead take a floating stone pew at
## the platform edge (Lie/Sit idle poses) and every GUST_COOLDOWN seconds may
## send a gust — aim with move, A to release. Never out of the game.
##
## The seat bobs; the ghost body is a KayKit char re-skinned in a translucent
## ghost material tinted toward the owner's color. While the living are
## frozen for a will draft, the ghosts keep swaying — the dead own the pause.

const GUST_COOLDOWN := 10.0

var index := 0
var color := Color.WHITE
var pname := ""
var owner_game: Node = null

var aim_dir := Vector2.ZERO       # normalized, points where the gust will go
var gust_cd := GUST_COOLDOWN      # counts down only while the round runs
var _bob_t := 0.0

var _arrow: Node3D
var _ready_label: Label3D
var _ring: MeshInstance3D
var _seat_root: Node3D

func setup(p_index: int, p_color: Color, p_name: String, char_scene: PackedScene, seat_angle: float, p_owner: Node) -> void:
	index = p_index
	color = p_color
	pname = p_name
	owner_game = p_owner
	_bob_t = seat_angle  # desync the bobbing per seat

	var r := 8.3
	global_position = Vector3(cos(seat_angle) * r, 0.9, sin(seat_angle) * r)
	# face the platform center
	rotation.y = atan2(-global_position.x, -global_position.z)
	aim_dir = Vector2(-cos(seat_angle), -sin(seat_angle))  # default: inward

	_seat_root = Node3D.new()
	add_child(_seat_root)

	# floating stone pew
	var slab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.7, 0.28, 1.3)
	slab.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.36, 0.35, 0.42)
	smat.roughness = 0.9
	slab.material_override = smat
	slab.position.y = -0.14
	_seat_root.add_child(slab)

	# broken little headstone at the pew's back, in identity color trim
	var stone := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(0.5, 0.62, 0.14)
	stone.mesh = stm
	var stmat := StandardMaterial3D.new()
	stmat.albedo_color = Color(0.3, 0.29, 0.36)
	stone.material_override = stmat
	stone.position = Vector3(0, 0.3, 0.52)
	stone.rotation_degrees = Vector3(-8, 0, 4)
	_seat_root.add_child(stone)
	var trim := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.52, 0.08, 0.16)
	trim.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = color
	tmat.emission_enabled = true
	tmat.emission = color
	tmat.emission_energy_multiplier = 1.4
	trim.material_override = tmat
	trim.position = Vector3(0, 0.56, 0.52)
	trim.rotation_degrees = Vector3(-8, 0, 4)
	_seat_root.add_child(trim)

	_ring = MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.85
	rm.outer_radius = 0.98
	_ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = 1.0
	_ring.material_override = rmat
	_ring.position.y = -0.02
	_seat_root.add_child(_ring)

	# ghost body: translucent, tinted toward identity color, Sit/Lie pose
	if char_scene != null:
		var body := char_scene.instantiate()
		body.scale = Vector3(0.95, 0.95, 0.95)
		_seat_root.add_child(body)
		body.position.y = 0.02
		_ghostify(body)
		var anim: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
		if anim:
			var wanted := "Sit_Floor_Idle" if index % 2 == 0 else "Lie_Idle"
			if not anim.has_animation(wanted):
				wanted = "Idle"
			if anim.has_animation(wanted):
				anim.get_animation(wanted).loop_mode = Animation.LOOP_LINEAR
				anim.play(wanted)

	var nm := Label3D.new()
	nm.text = PlayerBadge.glyph(index) + " " + pname
	nm.font_size = 40
	nm.pixel_size = 0.006
	nm.modulate = Color(color.r, color.g, color.b, 0.85)
	nm.outline_size = 10
	nm.outline_modulate = Color(0.06, 0.05, 0.09)
	nm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nm.position = Vector3(0, 1.5, 0)
	_seat_root.add_child(nm)

	_ready_label = Label3D.new()
	_ready_label.text = "GUST READY — A"
	_ready_label.font_size = 30
	_ready_label.pixel_size = 0.006
	_ready_label.modulate = Color(0.75, 0.95, 1.0)
	_ready_label.outline_size = 8
	_ready_label.outline_modulate = Color(0.06, 0.05, 0.09)
	_ready_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ready_label.position = Vector3(0, 1.86, 0)
	_ready_label.visible = false
	_seat_root.add_child(_ready_label)

	_arrow = _build_arrow()
	add_child(_arrow)
	_arrow.visible = false

	var wisps := CPUParticles3D.new()
	wisps.amount = 14
	wisps.lifetime = 1.1
	wisps.local_coords = false
	wisps.direction = Vector3.UP
	wisps.spread = 25.0
	wisps.gravity = Vector3(0, 0.6, 0)
	wisps.initial_velocity_min = 0.2
	wisps.initial_velocity_max = 0.5
	wisps.scale_amount_min = 0.3
	wisps.scale_amount_max = 0.6
	var wm := SphereMesh.new()
	wm.radius = 0.06
	wm.height = 0.12
	wisps.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	wisps.material_override = wmat
	wisps.emitting = true
	wisps.position.y = 0.6
	_seat_root.add_child(wisps)

func _ghostify(node: Node) -> void:
	if node is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var gc := color.lerp(Color(0.72, 0.85, 1.0), 0.55)
		m.albedo_color = Color(gc.r, gc.g, gc.b, 0.42)
		m.emission_enabled = true
		m.emission = gc
		m.emission_energy_multiplier = 0.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(node as MeshInstance3D).material_override = m
	for c in node.get_children():
		_ghostify(c)

func _build_arrow() -> Node3D:
	var root := Node3D.new()
	root.position.y = 0.55
	var shaft := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.12, 0.05, 1.5)
	shaft.mesh = sm
	shaft.position.z = -1.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.95, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.6
	shaft.material_override = mat
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := PrismMesh.new()
	hm.size = Vector3(0.42, 0.5, 0.06)
	head.mesh = hm
	head.material_override = mat
	head.position.z = -2.05
	head.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(head)
	return root

## Ticked by the controller (only while the round is live for cooldown,
## every frame for the bob).
func tick_cooldown(delta: float) -> void:
	if gust_cd > 0.0:
		gust_cd -= delta

func gust_ready() -> bool:
	return gust_cd <= 0.0

func set_aim(v: Vector2) -> void:
	if v.length() > 0.3:
		aim_dir = v.normalized()

func consume_gust() -> void:
	gust_cd = GUST_COOLDOWN

func _process(delta: float) -> void:
	_bob_t += delta
	_seat_root.position.y = sin(_bob_t * 1.3) * 0.09
	var ready := gust_ready()
	_ready_label.visible = ready
	if ready:
		_ready_label.modulate.a = 0.65 + 0.35 * sin(_bob_t * 5.0)
	_arrow.visible = ready
	if ready:
		# arrow's -Z must point along aim_dir in WORLD space
		_arrow.global_rotation = Vector3(0.0, atan2(-aim_dir.x, -aim_dir.y), 0.0)
