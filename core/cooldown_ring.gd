class_name CooldownRing
extends MeshInstance3D
## THE COOLDOWN RING (docs/design/08-gamefeel-research.md §B2).
##
## A flat, player-colored radial ring on the ground, concentric with the
## character's identity feet-ring. It wipes empty->full as an ability recharges
## (geometry = colorblind-safe: arc length, never red/green), ready-flashes on
## completion (x1.6 emission + 1.12 scale-pop + a soft tick), and hides itself
## while the ability sits idle-ready so a permanently-ready move adds no clutter.
##
## Fill form copies Greed's show_grab_progress (greed_player.gd:297) — the house
## reference: scale the torus by the fill fraction. Presentation only; it never
## touches gameplay state (reads a fraction, draws a ring).

const HIDE_AFTER := 0.4       # keep a freshly-ready ring up this long, then hide
const READY_EMISSION := 1.6   # emission spike multiplier on the ready-flash
const READY_POP := 1.12       # scale-pop on the ready-flash (dropped in reduced-motion)
const FLASH_TIME := 0.15      # ready-flash duration
const CHARGE_DIM := 0.44      # emission is ~0.4x of base while charging

var _mat: StandardMaterial3D
var _base_energy := 0.9
var _was_charging := false
var _flash_t := 0.0
var _ready_hold := 0.0

## color: the owner's identity color. outer/inner: ring radii (a hair outside the
## identity ring). y: local height off the ground. base_energy: idle emission.
func setup(color: Color, outer_r := 0.68, inner_r := 0.60, y := 0.05, base_energy := 0.9) -> void:
	_base_energy = base_energy
	var tm := TorusMesh.new()
	tm.inner_radius = inner_r
	tm.outer_radius = outer_r
	tm.rings = 6
	tm.ring_segments = 40
	mesh = tm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = base_energy
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = _mat
	position.y = y
	visible = false

## Recolor to the current owner (the king changes each reign in Throne).
func set_color(c: Color) -> void:
	if _mat:
		_mat.albedo_color = Color(c.r, c.g, c.b, 0.9)
		_mat.emission = c

## Drive every frame.
##   frac    : 0 at fire -> 1 fully recharged (READY).
##   active  : is this ring's owner live right now (else force-hidden).
##   reduced : reduced-motion — drops the scale-pop, keeps the emission spike.
func tick(delta: float, frac: float, active: bool, reduced: bool) -> void:
	if not active:
		visible = false
		_was_charging = false
		_ready_hold = 0.0
		_flash_t = 0.0
		return
	var charging := frac < 0.999
	# charging -> ready transition fires the ready-flash (the key "you can act again" cue)
	if _was_charging and not charging:
		_flash_t = FLASH_TIME
		_ready_hold = HIDE_AFTER
		Sfx.play("confirm", -14.0)
	_was_charging = charging
	if charging:
		visible = true
		_ready_hold = 0.0
		var f := clampf(frac, 0.05, 1.0)
		scale = Vector3(f, 1.0, f)
		_mat.emission_energy_multiplier = _base_energy * CHARGE_DIM
	else:
		_ready_hold = maxf(0.0, _ready_hold - delta)
		scale = Vector3.ONE
		_mat.emission_energy_multiplier = _base_energy
		visible = _ready_hold > 0.0
	# ready-flash animation (emission spike always; scale-pop unless reduced-motion)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		var k := _flash_t / FLASH_TIME     # 1 -> 0
		_mat.emission_energy_multiplier = _base_energy * lerpf(1.0, READY_EMISSION, k)
		if not reduced:
			var s := lerpf(1.0, READY_POP, k)
			scale = Vector3(s, 1.0, s)
		visible = true
