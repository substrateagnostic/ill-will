class_name TiltPlatter
extends Node3D
## The one platter everybody stands on, balanced on a pin over the ocean.
##
## Tilt model (spec v1 recommendation): the disc is a kinematic VISUAL —
## no RigidBody. Tilt is a 2D vector in platter-local XZ, pointing toward
## the downhill direction, magnitude in radians. Every physics tick the
## game feeds in the mass points (players + loose coins); their torque sum
## defines a target tilt, and a second-order spring-damper chases it:
##
##   T'' = OMEGA^2 * (target - T) - 2*ZETA*OMEGA * T'
##
## ZETA < 1 gives the spec's slight overshoot; OMEGA ~4.2 gives the ~0.4s
## response lag. Because the dynamics chase a bounded target, the system
## cannot run away (idle test: 4 symmetric bots hold |tilt| < 3 deg).
## Rotation is applied directly to the Disc child; players are NOT
## children of the disc — the game composes their world transform from
## disc.global_transform each tick (manual platter-local kinematics, per
## the spec's risk section: never trust floor friction).

const RADIUS := 7.0
const TOP_Y := 0.25            # local Y of the disc's standing surface
const PAWN_Y := 0.30           # where feet sit (atop the ring layers)
const FALL_R := RADIUS - 0.1   # beyond this local radius you're overboard
const OMEGA := 4.2             # spring natural frequency -> ~0.4s lag
const ZETA := 0.55             # < 1 -> slight overshoot
const GAIN_DEG := 2.9          # degrees of target tilt per unit torque
const WARN_DEG := 14.0         # low-side klaxon + edge glow past this
const BASE_MAX_DEG := 22.0
const SUDDEN_MAX_DEG := 30.0   # sudden death: +8 deg limit
const OCEAN_Y := -6.0

var disc: Node3D
var tilt := Vector2.ZERO       # radians, local XZ, points downhill
var tilt_vel := Vector2.ZERO
var max_tilt_deg := BASE_MAX_DEG
var gain_scale := 1.0
var overtime_scale := 1.0      # OVERTIME (doc 09 §3.3): tie at the horn tilts
                               # 1.5x harder on top of the sudden-death gain

var _forced := false
var _force_target := Vector2.ZERO
var _rim_mat: StandardMaterial3D
var _lamp: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _pin_root: Node3D
var _clock := 0.0

func _ready() -> void:
	_build()

func update_tilt(delta: float, mass_points: Array) -> void:
	var target := Vector2.ZERO
	if _forced:
		target = _force_target
	else:
		var torque := Vector2.ZERO
		for mp in mass_points:
			var pos: Vector2 = mp.pos
			var m: float = mp.m
			torque += pos * m
		var mag_deg := torque.length() * GAIN_DEG * gain_scale * overtime_scale
		if mag_deg > 0.001:
			target = torque.normalized() * deg_to_rad(minf(mag_deg, max_tilt_deg))
	var acc := (target - tilt) * (OMEGA * OMEGA) - tilt_vel * (2.0 * ZETA * OMEGA)
	tilt_vel += acc * delta
	tilt += tilt_vel * delta
	var hard := deg_to_rad(max_tilt_deg + 2.0)  # overshoot allowance, then wall
	if tilt.length() > hard:
		var n := tilt.normalized()
		tilt = n * hard
		var outward := tilt_vel.dot(n)
		if outward > 0.0:
			tilt_vel -= n * outward
	disc.rotation = Vector3(tilt.y, 0.0, -tilt.x)
	_clock += delta
	_update_glow()

func tilt_deg() -> float:
	return rad_to_deg(tilt.length())

func downhill() -> Vector2:
	return tilt.normalized() if tilt.length() > 0.0001 else Vector2.ZERO

## World height of the standing surface at a local XZ point.
func surface_world(lp: Vector2) -> Vector3:
	return disc.global_transform * Vector3(lp.x, PAWN_Y, lp.y)

func reset() -> void:
	tilt = Vector2.ZERO
	tilt_vel = Vector2.ZERO
	disc.rotation = Vector3.ZERO
	_forced = false
	overtime_scale = 1.0
	set_sudden_death(false)

## OVERTIME: the horn found >1 survivor — the platter itself breaks the tie,
## tilting 1.5x harder than sudden death until someone goes over.
func set_overtime(on: bool) -> void:
	overtime_scale = 1.5 if on else 1.0

func set_sudden_death(on: bool) -> void:
	max_tilt_deg = SUDDEN_MAX_DEG if on else BASE_MAX_DEG
	gain_scale = 1.6 if on else 1.0
	var rise := 1.2 if on else 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(disc, "position:y", rise, 0.9).set_trans(Tween.TRANS_CUBIC)
	var pin_h := -OCEAN_Y - 0.25
	tw.tween_property(_pin_root, "scale:y", (pin_h + rise) / pin_h, 0.9)

func debug_force_tilt(dir: Vector2, degrees: float) -> void:
	_forced = true
	_force_target = dir.normalized() * deg_to_rad(degrees)

## ONLINE mirror (doc 10 §4.3): the HOST owns the spring — a render mirror is
## HANDED the authoritative tilt (already interpolated by the game) and only
## applies it: disc rotation + rim glow + warning lamp. Never integrates mass.
func mirror_set_tilt(t: Vector2, delta: float) -> void:
	tilt = t
	disc.rotation = Vector3(tilt.y, 0.0, -tilt.x)
	_clock += delta
	_update_glow()

# -- construction -----------------------------------------------------------

func _build() -> void:
	disc = Node3D.new()
	disc.name = "Disc"
	add_child(disc)
	# base slab (cream), top face at TOP_Y
	var base := _cyl(RADIUS, 0.5, Color(0.89, 0.80, 0.60))
	base.position.y = 0.0
	disc.add_child(base)
	# dark underside rim band so the disc reads at a glance from 3/4
	var band := _cyl(RADIUS + 0.02, 0.18, Color(0.42, 0.28, 0.18))
	band.position.y = -0.17
	disc.add_child(band)
	# concentric target rings (stacked thin discs of shrinking radius)
	var radii: Array = [5.9, 4.7, 3.5, 2.3, 1.1]
	for i in radii.size():
		var col := Color(0.85, 0.46, 0.24) if i % 2 == 0 else Color(0.96, 0.91, 0.74)
		if i == radii.size() - 1:
			col = Color(0.30, 0.24, 0.20)  # dark hub marks the pivot
		var layer := _cyl(radii[i], 0.012, col)
		layer.position.y = TOP_Y + 0.008 + i * 0.012
		disc.add_child(layer)
	# rim warning glow (energy ramps with tilt)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 6.78
	tm.outer_radius = 7.06
	rim.mesh = tm
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.albedo_color = Color(0.55, 0.12, 0.08)
	_rim_mat.emission_enabled = true
	_rim_mat.emission = Color(1.0, 0.22, 0.10)
	_rim_mat.emission_energy_multiplier = 0.0
	rim.material_override = _rim_mat
	rim.position.y = TOP_Y + 0.02
	disc.add_child(rim)
	# low-side warning lamp (pulsing red puddle at the downhill rim)
	_lamp = MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 2.2
	lm.bottom_radius = 2.2
	lm.height = 0.02
	_lamp.mesh = lm
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lamp_mat.albedo_color = Color(1.0, 0.15, 0.08, 0.0)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.2, 0.1)
	_lamp_mat.emission_energy_multiplier = 1.6
	_lamp.material_override = _lamp_mat
	_lamp.position.y = TOP_Y + 0.09
	_lamp.visible = false
	disc.add_child(_lamp)
	# the pin: anchored at the ocean floor, scales up when it "rises"
	_pin_root = Node3D.new()
	_pin_root.name = "PinRoot"
	_pin_root.position.y = OCEAN_Y
	add_child(_pin_root)
	var pin_h := -OCEAN_Y - 0.25
	var pin := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.16
	pm.bottom_radius = 1.35
	pm.height = pin_h
	pin.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.35, 0.30, 0.34)
	pmat.metallic = 0.55
	pmat.roughness = 0.4
	pin.material_override = pmat
	pin.position.y = pin_h / 2.0
	_pin_root.add_child(pin)
	var foot := _cyl(2.1, 0.5, Color(0.28, 0.24, 0.27))
	foot.position.y = 0.25
	_pin_root.add_child(foot)

## Colored spawn-quadrant marker on the rim (player identity + compass).
func add_quadrant_marker(angle: float, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.05, 0.5)
	marker.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.35
	marker.material_override = mat
	var r := 6.35
	marker.position = Vector3(cos(angle) * r, TOP_Y + 0.075, sin(angle) * r)
	marker.rotation.y = -angle + PI / 2.0
	disc.add_child(marker)

func _update_glow() -> void:
	var deg := tilt_deg()
	var frac := clampf((deg - 8.0) / (WARN_DEG + 6.0 - 8.0), 0.0, 1.0)
	_rim_mat.emission_energy_multiplier = frac * 2.6
	if deg > WARN_DEG:
		_lamp.visible = true
		var d := downhill()
		_lamp.position = Vector3(d.x * 4.9, TOP_Y + 0.09, d.y * 4.9)
		var pulse := 0.45 + 0.25 * sin(_clock * 9.0)
		_lamp_mat.albedo_color.a = pulse
	else:
		_lamp.visible = false

func _cyl(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	return mi
