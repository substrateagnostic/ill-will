class_name LWBoulder
extends Node3D
## The rolling boulder, generalized for the procession course. Telegraphs its
## lane (glowing strip + "!" at the spawn edge), then a big stone sphere rolls
## along `dir` from `start` for `travel` meters — across the walkway, through
## anyone grounded (SQUISH), and off the far side into the dusk. Hop (B) over
## it — airborne pawns are safe, party-game logic. Code-driven; tick(delta)
## is only called while the race runs.

const SPEED := 5.6
const RADIUS := 0.95
const TELEGRAPH_T := 1.35

enum BState { TELEGRAPH, ROLLING, DONE }

var state: int = BState.TELEGRAPH
var owner_game: Node = null
var dir := Vector2.RIGHT
var travel := 20.0
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

## start: spawn point (off the walkway edge). p_dir: unit roll direction (XZ).
## strip_center/strip_len: telegraph strip clipped to the walkway.
func setup(start: Vector3, p_dir: Vector2, p_travel: float,
		strip_center: Vector3, strip_len: float, p_owner: Node) -> void:
	owner_game = p_owner
	dir = p_dir.normalized()
	travel = p_travel
	_start = Vector3(start.x, RADIUS, start.z)
	var perp := Vector2(-dir.y, dir.x)
	_roll_axis = Vector3(perp.x, 0, perp.y)

	# lane telegraph strip — clipped to the walkway so it never reads as a
	# glowing bridge floating over the void
	_strip = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(strip_len, 0.05, RADIUS * 2.1)
	_strip.mesh = sm
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_strip_mat.albedo_color = Color(1.0, 0.58, 0.12, 0.25)
	_strip_mat.emission_enabled = true
	_strip_mat.emission = Color(1.0, 0.5, 0.1)
	_strip_mat.emission_energy_multiplier = 0.9
	_strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_strip.material_override = _strip_mat
	_strip.position = Vector3(strip_center.x, 0.04, strip_center.z)
	_strip.rotation.y = -atan2(dir.y, dir.x)
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
	rmat.albedo_color = Color(0.58, 0.54, 0.5)
	rmat.roughness = 0.95
	_rock_mesh.material_override = rmat
	_rock.add_child(_rock_mesh)
	var lump_mat := StandardMaterial3D.new()
	lump_mat.albedo_color = Color(0.46, 0.43, 0.41)
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
			_strip_mat.albedo_color.a = 0.09 + 0.19 * pulse
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
			# fall off the FAR edge only (spawn side is also off-walkway,
			# and the rock must arrive at deck height, not under it)
			if _traveled > travel * 0.4 and owner_game != null \
					and not owner_game.over_ground(_rock.position):
				_fall_v += 18.0 * delta
				_rock.position.y -= _fall_v * delta
			_check_squish()
			if _traveled >= travel or _rock.position.y < -8.0:
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
