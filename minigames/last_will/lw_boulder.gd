class_name LWBoulder
extends Node3D
## The rolling boulder. Telegraphs its lane (glowing strip + "!" at the
## spawn edge), then a big stone sphere rolls straight across the yard and
## off the far side. Grounded contact = SQUISH (eliminated). Hop (B) over
## it — airborne pawns are safe, party-game logic. Code-driven; tick(delta)
## is only called while the round runs.

const SPEED := 5.6
const RADIUS := 0.95
const TELEGRAPH_T := 1.35
const TRAVEL := 20.0          # total distance start->despawn

enum BState { TELEGRAPH, ROLLING, DONE }

var state: int = BState.TELEGRAPH
var owner_game: Node = null
var dir := Vector2.RIGHT
var lane_offset := 0.0
var _t := 0.0
var _traveled := 0.0
var _start := Vector3.ZERO

var _rock: Node3D
var _rock_mesh: MeshInstance3D
var _strip: MeshInstance3D
var _strip_mat: StandardMaterial3D
var _bang: Label3D
var _roll_axis := Vector3.FORWARD
var _fall_v := 0.0

func setup(angle_deg: float, offset: float, p_owner: Node) -> void:
	owner_game = p_owner
	lane_offset = offset
	var a := deg_to_rad(angle_deg)
	dir = Vector2(cos(a), sin(a))
	var perp := Vector2(-dir.y, dir.x)
	var start2 := perp * offset - dir * (TRAVEL * 0.5)
	_start = Vector3(start2.x, RADIUS, start2.y)
	_roll_axis = Vector3(perp.x, 0, perp.y)

	# lane telegraph strip
	_strip = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(TRAVEL, 0.05, RADIUS * 2.1)
	_strip.mesh = sm
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_strip_mat.albedo_color = Color(1.0, 0.62, 0.15, 0.3)
	_strip_mat.emission_enabled = true
	_strip_mat.emission = Color(1.0, 0.55, 0.1)
	_strip_mat.emission_energy_multiplier = 1.2
	_strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_strip.material_override = _strip_mat
	_strip.position = Vector3(perp.x * offset, 0.04, perp.y * offset)
	_strip.rotation.y = -a
	add_child(_strip)

	# "!" marker floating at the spawn edge
	_bang = Label3D.new()
	_bang.text = "!"
	_bang.font_size = 160
	_bang.pixel_size = 0.006
	_bang.modulate = Color(1.0, 0.55, 0.1)
	_bang.outline_size = 24
	_bang.outline_modulate = Color(0.1, 0.04, 0.02)
	_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bang.position = _start + Vector3(dir.x, 0.8, dir.y) * 1.6
	add_child(_bang)

	# the rock itself (hidden until it rolls): craggy = sphere + offset lumps
	_rock = Node3D.new()
	_rock.position = _start
	_rock.visible = false
	add_child(_rock)
	_rock_mesh = MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = RADIUS
	rm.height = RADIUS * 2.0
	_rock_mesh.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.44, 0.42, 0.4)
	rmat.roughness = 0.95
	_rock_mesh.material_override = rmat
	_rock.add_child(_rock_mesh)
	var lump_mat := StandardMaterial3D.new()
	lump_mat.albedo_color = Color(0.36, 0.34, 0.33)
	lump_mat.roughness = 1.0
	for lp in [Vector3(0.5, 0.45, 0.3), Vector3(-0.4, -0.3, 0.5), Vector3(0.15, 0.6, -0.5), Vector3(-0.5, 0.2, -0.45)]:
		var lump := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.3
		lm.height = 0.6
		lump.mesh = lm
		lump.material_override = lump_mat
		lump.position = lp
		_rock_mesh.add_child(lump)
	Sfx.play("card", -4.0)

func tick(delta: float) -> void:
	match state:
		BState.TELEGRAPH:
			_t += delta
			var pulse := 0.5 + 0.5 * sin(_t * 12.0)
			_strip_mat.albedo_color.a = 0.12 + 0.3 * pulse
			_bang.modulate.a = 0.4 + 0.6 * pulse
			if _t >= TELEGRAPH_T:
				state = BState.ROLLING
				_rock.visible = true
				_bang.visible = false
				_strip_mat.albedo_color.a = 0.035
				_strip_mat.emission_energy_multiplier = 0.4
				Sfx.play("crush", -9.0, 0.2)
		BState.ROLLING:
			var step := SPEED * delta
			_traveled += step
			_rock.position += Vector3(dir.x, 0, dir.y) * step
			_rock_mesh.rotate(_roll_axis.normalized(), -step / RADIUS)
			# fall off the FAR edge only (spawn side is also off-platform,
			# and the rock must arrive at deck height, not under it)
			var flat_r := Vector2(_rock.position.x, _rock.position.z).length()
			var plat_r: float = owner_game.platform_radius if owner_game != null else 7.0
			if _traveled > TRAVEL * 0.5 and flat_r > plat_r + RADIUS * 0.4:
				_fall_v += 18.0 * delta
				_rock.position.y -= _fall_v * delta
			_check_squish()
			if _traveled >= TRAVEL or _rock.position.y < -8.0:
				state = BState.DONE
		BState.DONE:
			pass

func _check_squish() -> void:
	if owner_game == null or _rock.position.y < 0.0:
		return
	for pawn in owner_game.living_pawns():
		if not pawn.alive:
			continue
		var d := Vector2(pawn.global_position.x - _rock.position.x,
			pawn.global_position.z - _rock.position.z).length()
		if d > RADIUS + 0.38:
			continue
		if pawn.is_grounded() and pawn.global_position.y < 0.45:
			if owner_game.has_method("on_boulder_contact"):
				owner_game.on_boulder_contact(pawn)

func rock_pos() -> Vector3:
	return _rock.position

func is_done() -> bool:
	return state == BState.DONE
