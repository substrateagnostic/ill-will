class_name Trail
extends Node3D
## The Pilgrimage Trail: 26 stones spiraling up the hill to the Manor.
## Pawns advance by points earned (never dice). Stations have teeth.

signal gate_paid(payer: int, owner_idx: int)

const STONES := 26
const TOLLGATES := [8, 16]
const HILL_CENTER := Vector3(0, 0, -13)
const HILL_HEIGHT := 2.1
const R_OUT := 6.2
const R_IN := 1.6

var pawns := {}
var stone_nodes: Array = []

func stone_pos(i: int) -> Vector3:
	var t := float(i) / float(STONES - 1)
	var ang_deg: float
	var r: float
	if t < 0.4:
		var s := t / 0.4
		ang_deg = lerpf(165.0, 15.0, s)
		r = lerpf(6.2, 4.9, s)
	elif t < 0.75:
		var s := (t - 0.4) / 0.35
		ang_deg = lerpf(15.0, 165.0, s)
		r = lerpf(4.9, 3.3, s)
	else:
		var s := (t - 0.75) / 0.25
		ang_deg = lerpf(165.0, 95.0, s)
		r = lerpf(3.3, 1.7, s)
	var ang := deg_to_rad(ang_deg)
	var h := maxf(0.0, HILL_HEIGHT * (1.0 - r / 4.2))
	return HILL_CENTER + Vector3(cos(ang) * r, h + 0.06, sin(ang) * r)

func build(players: Array, statues: Array) -> void:
	for i in STONES:
		var s := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.34
		mesh.bottom_radius = 0.38
		mesh.height = 0.09
		s.mesh = mesh
		var mat := StandardMaterial3D.new()
		var is_gate := i in TOLLGATES
		mat.albedo_color = Color(0.85, 0.7, 0.35) if is_gate else Color(0.75, 0.73, 0.7)
		mat.roughness = 0.85
		s.material_override = mat
		add_child(s)
		s.global_position = stone_pos(i)
		stone_nodes.append(s)
		if is_gate:
			var arch := MeshInstance3D.new()
			var am := TorusMesh.new()
			am.inner_radius = 0.4
			am.outer_radius = 0.5
			arch.mesh = am
			arch.material_override = mat
			add_child(arch)
			arch.global_position = stone_pos(i) + Vector3(0, 0.5, 0)
			arch.rotation_degrees.x = 90.0
		if i == STONES - 1:
			var flag_lbl := Label3D.new()
			flag_lbl.text = "THE MANOR"
			flag_lbl.font_size = 60
			flag_lbl.pixel_size = 0.006
			flag_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			flag_lbl.modulate = Color(1, 0.9, 0.5)
			flag_lbl.outline_size = 14
			add_child(flag_lbl)
			flag_lbl.global_position = stone_pos(i) + Vector3(0, 1.6, 0)
	for pl in players:
		var pawn := _make_pawn(pl.color, pl.name)
		add_child(pawn)
		pawns[pl.index] = pawn
		_seat_pawn(pl.index, 0)
	_draw_statues(statues)

func _make_pawn(color: Color, pname: String) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.13
	bm.height = 0.46
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	body.material_override = mat
	body.position.y = 0.28
	root.add_child(body)
	var tag := Label3D.new()
	tag.text = pname
	tag.font_size = 34
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = color
	tag.outline_size = 8
	tag.position.y = 0.72
	root.add_child(tag)
	return root

func _seat_pawn(p: int, stone: int) -> void:
	var offset := Vector3(0.12 * (p - 1.5), 0, 0.1 * ((p % 2) * 2 - 1))
	pawns[p].global_position = stone_pos(stone) + offset

## Animated advancement; calls gate_cb(payer, gate_idx) when crossing an
## owned tollgate stone (claim/pay handled by the caller). Returns the tween.
func advance_pawn(p: int, from_stone: int, to_stone: int) -> Tween:
	var tw := create_tween()
	for s in range(from_stone + 1, to_stone + 1):
		var target := stone_pos(s) + Vector3(0.12 * (p - 1.5), 0, 0.1 * ((p % 2) * 2 - 1))
		tw.tween_property(pawns[p], "global_position", target + Vector3(0, 0.25, 0), 0.11)
		tw.tween_property(pawns[p], "global_position", target, 0.09)
		tw.tween_callback(Sfx.play.bind("card", -12.0, 0.15))
	return tw

func add_statue(st: Dictionary, idx: int) -> void:
	var col := Color.from_string(str(st.color), Color.WHITE)
	var statue := _make_pawn(col, str(st.owner))
	statue.scale = Vector3(1.5, 1.5, 1.5)
	add_child(statue)
	var ang := deg_to_rad(200.0 + (idx % 8) * 20.0)
	statue.global_position = stone_pos(STONES - 1) + Vector3(cos(ang) * 1.3, 0, sin(ang) * 1.3)

func _draw_statues(statues: Array) -> void:
	for i in statues.size():
		var st: Dictionary = statues[i]
		var col := Color.from_string(str(st.color), Color.WHITE)
		var statue := _make_pawn(col, str(st.owner))
		statue.scale = Vector3(1.5, 1.5, 1.5)
		add_child(statue)
		var ang := deg_to_rad(200.0 + (i % 8) * 20.0)
		statue.global_position = stone_pos(STONES - 1) + Vector3(cos(ang) * 1.3, 0, sin(ang) * 1.3)
