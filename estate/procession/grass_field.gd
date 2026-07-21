class_name GrassField
extends Node3D
## THE LIVING LAWN's trample driver (integration, tenth watch). Every frame it
## gathers up to 8 world benders — the four pawns, the hearse-cart, and (on the
## dev walkabout) the stroller — and pushes their xz + radius into every grass
## ShaderMaterial's `benders` / `bender_count` uniforms, so the shader bends the
## blades away and presses them flat under whatever crosses the meadow.
##
## PRESENTATION ONLY. It READS node positions and WRITES shader uniforms — it
## never touches sim state, board data, or ANY rng stream, so it is safe to
## spawn on every table (a receipt soak included). It also idles in headless:
## there is no grass to bend where nothing renders.

const MAX_BENDERS := 8
const PAWN_RADIUS := 1.15
const CART_RADIUS := 2.10
const STROLLER_RADIUS := 1.50

var _mats: Array = []                 # Array[ShaderMaterial] from grounds.grass_materials
var _board: ProcessionBoardGraph = null
var _extra: Array = []                # [{node:Node3D, radius:float}] — walkabout stroller etc.
var _is_headless := false

func setup(board: ProcessionBoardGraph, mats: Array) -> void:
	_board = board
	_mats = mats
	_is_headless = DisplayServer.get_name() == "headless"
	# A soak never sees the grass bend; skip the per-frame work entirely so this
	# node can never even appear to perturb a headless receipt.
	set_process(not _is_headless and not _mats.is_empty())

## Register a transient bender (the walkabout stroller) — a Node3D whose
## world position tramples the grass at `radius` metres until it is removed.
func register_bender(node: Node3D, radius: float) -> void:
	if node != null:
		_extra.append({"node": node, "radius": radius})

func _process(_dt: float) -> void:
	if _mats.is_empty() or _board == null:
		return
	var arr := PackedVector4Array()
	arr.resize(MAX_BENDERS)
	var n := 0
	# the four pawns
	for seat in _board.pawns:
		if n >= MAX_BENDERS:
			break
		var pw := _board.pawns[seat] as Node3D
		if pw != null and pw.is_inside_tree():
			var p := pw.global_position
			arr[n] = Vector4(p.x, p.y, p.z, PAWN_RADIUS)
			n += 1
	# the hearse-cart (only once furniture placed it)
	if n < MAX_BENDERS and _board.cart_prop != null and _board.cart_prop.is_inside_tree():
		var cp := _board.cart_prop.global_position
		arr[n] = Vector4(cp.x, cp.y, cp.z, CART_RADIUS)
		n += 1
	# registered extras (the dev walkabout stroller)
	for e in _extra:
		if n >= MAX_BENDERS:
			break
		var node := e.node as Node3D
		if node != null and node.is_inside_tree():
			var q := node.global_position
			arr[n] = Vector4(q.x, q.y, q.z, float(e.radius))
			n += 1
	for i in range(n, MAX_BENDERS):
		arr[i] = Vector4(0.0, 0.0, 0.0, 0.0)
	for m in _mats:
		var sm := m as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("benders", arr)
			sm.set_shader_parameter("bender_count", n)
