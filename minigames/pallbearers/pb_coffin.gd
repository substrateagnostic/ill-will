class_name PBCoffin
extends Node3D
## The pall itself — one coffin carried by a pair in PALLBEARERS, plus THE
## DECEASED who spills out of it when it drops.
##
## PURE VISUAL / render-only, driven by the controller (pallbearers.gd). Position
## + heading + a divergence-driven SWAY are set every physics tick. The lid pops
## and the deceased tumbles out on a drop; both are stuffed back on a restuff.
##
## The coffin body was primitives behind a one-line Meshy swap seam
## (COFFIN_GLB) until the ZA finish audit (night 8) found the handled
## carry-coffin had landed under `board_carry_coffin.glb` (the BOARD_DRESSING
## wave) — this seam was still pointed at the pre-forge placeholder filename
## `board_pall_coffin.glb`, which was never generated, so ResourceLoader.exists
## silently fell through to the primitives every run. Rewired to the shipped
## asset (walnut-red lid, gold corner fittings and carry handles — reads
## PAINTED on the finish-audit contact sheet, docs/verify/shots/
## asset_finish_board_*.png). The deceased is a wrapped shroud (a KayKit body
## would read as a live person; a shroud reads as cargo).

## Swap seam: drop a committed coffin GLB here and it replaces the primitives
## with zero controller changes (MeshyProp-normalized to LID_LEN height).
const COFFIN_GLB := "res://assets/models/meshy/generated/board_carry_coffin.glb"

const LEN := 2.5                       # long axis (travel/feet-first direction, local Z)
const WID := 0.72
const BODY_H := 0.46
const LID_H := 0.2

var team := 0
var accent := Color(0.85, 0.72, 0.35)

var _body: Node3D                      # the casket shell (everything but the lid)
var _lid: Node3D
var _shroud: Node3D                    # the deceased
var _label: Label3D                    # the complaint speech bubble
var _label_t := 0.0
var _lid_open := 0.0                   # 0 closed .. 1 fully popped
var _sway := 0.0
var _using_glb := false


func build(team_id: int, accent_col: Color) -> void:
	team = team_id
	accent = accent_col

	_body = Node3D.new()
	add_child(_body)

	if ResourceLoader.exists(COFFIN_GLB):
		var prop := MeshyProp.instance(COFFIN_GLB, LID_H + BODY_H)
		_body.add_child(prop)
		_using_glb = true
	else:
		_build_casket_primitives()

	# the lid — a separate child so it can pop off on a drop
	_lid = Node3D.new()
	add_child(_lid)
	_build_lid()

	# the deceased: a wrapped shroud, hidden inside until spilled
	_shroud = Node3D.new()
	add_child(_shroud)
	_build_shroud()
	_shroud.visible = false

	# the complaint bubble
	_label = Label3D.new()
	_label.font_size = 72
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(0.95, 0.93, 0.86)
	_label.outline_size = 18
	_label.outline_modulate = Color(0.08, 0.06, 0.08)
	_label.position = Vector3(0, 1.5, 0)
	_label.visible = false
	var lf: FontFile = load("res://assets/fonts/Baloo2.ttf")
	if lf != null:
		_label.font = lf
	add_child(_label)


func _build_casket_primitives() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.20, 0.13)      # warm walnut, reads at night
	wood.roughness = 0.5
	wood.metallic = 0.05
	# shell
	var shell := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(WID, BODY_H, LEN)
	shell.mesh = sb
	shell.material_override = wood
	shell.position.y = BODY_H * 0.5
	_body.add_child(shell)
	# gold trim rails (top edge of the body)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = accent
	gold.emission_enabled = true
	gold.emission = accent
	gold.emission_energy_multiplier = 1.4            # catches the moonlight, hero read
	gold.metallic = 0.8
	gold.roughness = 0.3
	for sx in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.06, 0.07, LEN * 0.98)
		rail.mesh = rb
		rail.material_override = gold
		rail.position = Vector3(sx * (WID * 0.5 - 0.02), BODY_H - 0.02, 0)
		_body.add_child(rail)
	# handles — three bars a side (the pallbearers' grip read)
	for sx in [-1.0, 1.0]:
		for hz in [-0.7, 0.0, 0.7]:
			var h := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.06, 0.05, 0.44)
			h.mesh = hb
			h.material_override = gold
			h.position = Vector3(sx * (WID * 0.5 + 0.04), BODY_H * 0.5, hz)
			_body.add_child(h)


func _build_lid() -> void:
	if _using_glb:
		# GLB path: a thin accent slab as the lid so the pop still reads
		var slab := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(WID * 0.96, 0.06, LEN * 0.96)
		slab.mesh = lb
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.13, 0.10)
		slab.material_override = m
		slab.position.y = BODY_H + LID_H
		_lid.add_child(slab)
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.23, 0.15)
	wood.roughness = 0.45
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(WID * 1.02, LID_H, LEN * 1.02)
	top.mesh = tb
	top.material_override = wood
	top.position.y = BODY_H + LID_H * 0.5
	_lid.add_child(top)
	# a small cross inlay on the lid
	var gold := StandardMaterial3D.new()
	gold.albedo_color = accent
	gold.emission_enabled = true
	gold.emission = accent
	gold.emission_energy_multiplier = 1.6
	gold.metallic = 0.8
	var v := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.08, 0.03, 0.6)
	v.mesh = vb
	v.material_override = gold
	v.position.y = BODY_H + LID_H + 0.005
	_lid.add_child(v)
	var h := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.30, 0.03, 0.08)
	h.mesh = hb
	h.material_override = gold
	h.position = Vector3(0, BODY_H + LID_H + 0.005, 0.18)
	_lid.add_child(h)


func _build_shroud() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.92, 0.90, 0.83)      # pale linen
	cloth.roughness = 0.9
	cloth.emission_enabled = true
	cloth.emission = Color(0.5, 0.5, 0.55)            # a faint moon-glow so the spill reads
	cloth.emission_energy_multiplier = 0.35
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.95
	body.mesh = cap
	body.material_override = cloth
	body.rotation.z = PI * 0.5           # lie the shroud along its long axis (local X)
	body.position.y = 0.3
	_shroud.add_child(body)
	# rope bindings
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.4, 0.32, 0.2)
	for rx in [-0.5, 0.0, 0.5]:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.24
		tm.outer_radius = 0.3
		r.mesh = tm
		r.material_override = rope
		r.rotation.z = PI * 0.5
		r.position = Vector3(rx, 0.28, 0)
		_shroud.add_child(r)


## The drop: lid pops off and the deceased spills out onto the ground beside the
## coffin. `dir` is the travel heading (local -> the shroud tumbles ahead).
func spill() -> void:
	_shroud.visible = true
	# tumble the deceased out to the SIDE, clear of both bearers (who stand on the
	# centreline at the coffin ends) and angled downstage so the camera sees it
	_shroud.position = Vector3(1.15, 0, -0.6)
	_shroud.rotation.y = 0.9
	# lid pop tween (visual only)
	var tw := create_tween()
	tw.tween_property(self, "_lid_open", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reseat() -> void:
	_shroud.visible = false
	var tw := create_tween()
	tw.tween_property(self, "_lid_open", 0.0, 0.22)


func is_spilled() -> bool:
	return _shroud.visible


## Restuff feedback: the shroud wiggles toward the coffin as it fills (0..1).
func set_restuff(frac: float) -> void:
	if not _shroud.visible:
		return
	var f := clampf(frac, 0.0, 1.0)
	_shroud.position = Vector3(lerpf(1.15, 0.0, f), 0.0, lerpf(-0.6, 0.0, f))
	_shroud.position.y = sin(f * TAU * 2.0) * 0.06


func say(line: String, dur := 2.6) -> void:
	_label.text = line
	_label.visible = true
	_label_t = dur
	_label.modulate.a = 1.0


## Driven every physics tick: heading + a divergence SWAY (roll) that telegraphs
## how close the pair is to dropping. `spilled_here` keeps the tilt lively when
## the deceased is out.
func drive(delta: float, sway_amount: float, wobble_t: float) -> void:
	_sway = lerpf(_sway, sway_amount, 1.0 - exp(-9.0 * delta))
	# roll + pitch wobble scaled by how unstable the carry is
	rotation.z = sin(wobble_t * 7.0) * 0.10 * _sway
	rotation.x = sin(wobble_t * 4.3 + 1.1) * 0.05 * _sway
	# lid lifts as it pops
	_lid.position.y = _lid_open * 0.5
	_lid.rotation.x = _lid_open * -1.1
	_lid.position.z = _lid_open * -0.5
	if _label_t > 0.0:
		_label_t = maxf(0.0, _label_t - delta)
		if _label_t < 0.6:
			_label.modulate.a = _label_t / 0.6
		if _label_t <= 0.0:
			_label.visible = false
