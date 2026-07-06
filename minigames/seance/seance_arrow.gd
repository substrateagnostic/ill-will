class_name SeanceArrow
extends Node3D
## A sitter's spectral pull-pointer for THE SÉANCE.
##
## PRESENTATION ONLY. It reads a sitter's CURRENT summed pull each frame and
## shows which way they are dragging the planchette — so the table can watch
## the arrows against the letter the circle needs, and the saboteur (pulling
## the wrong way, or yanking away from a charging letter) becomes detectable.
## It touches NO forces, NO physics, NO focus meter, NO rng: pure visualization.
##
## Owner's design change (2026-07): overrides the original Ouija-deniability
## choice of never visualizing individual hands. One arrow per sitter, BOTS
## INCLUDED (a bot saboteur's pull is the whole point). Anchored at that
## sitter's rim of the board, it rotates to the pull heading; its length and
## opacity scale with pull strength; it fades out ~0.4s after the hand goes
## idle. Style follows the room — an unshaded warm-glow wisp (no hard HUD
## lines), player-colored, with a billboard badge glyph so identity travels as
## shape+color, never color alone.

const HEAD_LEN := 0.13
const MIN_LEN := 0.17           # shortest visible wisp (a faint nudge still reads)
const MAX_LEN := 0.66           # a full-strength yank
const FADE_TIME := 0.4          # seconds to vanish after the hand stops
const IDLE_EPS := 0.06          # pull under this = idle (matches the physics gate ~0.05)

var index := 0
var _color := Color.WHITE
var _shaft: MeshInstance3D
var _shaft_mat: StandardMaterial3D
var _head: MeshInstance3D
var _head_mat: StandardMaterial3D
var _glyph: Label3D
var _shown := 0.0               # 0..1 visible strength (drives length + opacity)

## anchor = world rim point at this sitter's edge of the board.
func setup(p_index: int, p_color: Color, anchor: Vector3) -> void:
	index = p_index
	_color = p_color
	position = anchor
	# shaft: a thin glowing bar built along +X (tail at the origin, growing
	# toward the pull). Scaled each frame, so the mesh stays a unit bar.
	_shaft = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.0, 0.008, 0.05)
	_shaft.mesh = sm
	_shaft_mat = _wisp_mat()
	_shaft.material_override = _shaft_mat
	add_child(_shaft)
	# head: a soft cone (a CylinderMesh with a zero top, like the planchette
	# tip) turned to point +X down the shaft.
	_head = MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.0
	hm.bottom_radius = 0.088
	hm.height = HEAD_LEN
	_head.mesh = hm
	_head_mat = _wisp_mat()
	_head.material_override = _head_mat
	_head.rotation_degrees = Vector3(0.0, 0.0, -90.0)   # +Y cone -> +X
	add_child(_head)
	# badge glyph floating over the tail — identity as shape+color, never
	# color alone (matches the sitters' nameplate glyphs).
	_glyph = Label3D.new()
	_glyph.text = PlayerBadge.glyph(p_index)
	_glyph.font_size = 40
	_glyph.pixel_size = 0.0040
	_glyph.modulate = p_color
	_glyph.outline_size = 9
	_glyph.outline_modulate = Color(0.05, 0.04, 0.07, 1.0)
	_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph.no_depth_test = true
	_glyph.fixed_size = false
	_glyph.position = Vector3(0.0, 0.17, 0.0)
	add_child(_glyph)
	_apply(0.0)

func _wisp_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(_color.r, _color.g, _color.b, 0.0)
	m.emission_enabled = true
	m.emission = _color
	m.emission_energy_multiplier = 1.0
	return m

## Feed the sitter's CURRENT pull (world vector; XZ used, magnitude 0..1).
## Visual only — never write anything the sim reads back.
func drive(pull: Vector3, delta: float) -> void:
	var mag := clampf(Vector2(pull.x, pull.z).length(), 0.0, 1.0)
	if mag > IDLE_EPS:
		# aim at the heading; local +X was built to point down the shaft
		rotation.y = atan2(-pull.z, pull.x)
		# ease up fast so a hard yank reads immediately (wispy, not instant)
		_shown = lerpf(_shown, mag, 1.0 - exp(-22.0 * delta))
	else:
		# hand idle: linear fade to nothing over ~FADE_TIME, keeping the last
		# heading so the wisp dissipates pointing where they let go
		_shown = maxf(0.0, _shown - delta / FADE_TIME)
	_apply(_shown)

func _apply(k: float) -> void:
	var vis := k > 0.002
	_shaft.visible = vis
	_head.visible = vis
	_glyph.visible = vis
	if not vis:
		return
	var length := MIN_LEN + (MAX_LEN - MIN_LEN) * k
	var shaft_len := maxf(0.001, length - HEAD_LEN)
	_shaft.scale = Vector3(shaft_len, 1.0, 1.0)
	_shaft.position.x = shaft_len * 0.5
	_head.position.x = shaft_len + HEAD_LEN * 0.5
	# soft glow: faint at rest, brighter on a hard pull (env glow blooms it)
	var a := 0.14 + 0.6 * k
	_shaft_mat.albedo_color.a = a
	_head_mat.albedo_color.a = clampf(a + 0.12, 0.0, 0.92)
	_shaft_mat.emission_energy_multiplier = 0.8 + 2.2 * k
	_head_mat.emission_energy_multiplier = 1.0 + 2.6 * k
	_glyph.modulate.a = clampf(0.4 + 0.6 * k, 0.0, 1.0)

## The sitting is over: snuff the pointer at once (no pull to show in TALK/VOTE).
func snuff() -> void:
	_shown = 0.0
	_apply(0.0)
