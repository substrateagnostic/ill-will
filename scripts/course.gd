class_name Course
extends Node3D
## Base for every course shape (fairway / dogleg / green). Owns the cup-magnet
## physics + cup-entry signal, and exposes geometry queries so nothing else
## hardcodes a single course's dimensions: playable region, tee slots, cup,
## no-build zones, camera framing, gravestone clamping. Each course .tscn sets
## the @export fields to describe its shape; the logic below is shared.

signal ball_entered_cup(body: Node3D)
## Emitted when a moving ball falls into an "adventure gutter" mouth (see the
## optional "Gutters" node). target = where the side channel should deliver it.
## Only courses that ship gutter Area3Ds ever fire this; main handles the detour.
signal ball_entered_gutter(body: Node3D, target: Vector3)

const MAGNET_RADIUS := 0.36
const MAGNET_MAX_SPEED := 5.0
const MAGNET_FORCE := 26.0

## Playable floor as a union of XZ rectangles (Rect2 position = min corner,
## size = extent along +X and +Z). A point counts as "on the green" if inside
## ANY rect. These are already inset from the walls a little.
@export var play_rects: Array[Rect2] = []
## Four tee anchor points (world space, y = ball spawn height). main picks a
## centered subset when fewer than 4 players.
@export var tee_slots: Array[Vector3] = []
## Extra no-build discs beyond the auto tee+cup zones (green humps, dogleg
## bank). Each entry is a Dictionary {"pos": Vector3, "radius": float}.
@export var extra_no_build: Array = []
@export var tee_no_build_radius := 1.5
@export var cup_no_build_radius := 1.3
## Diorama framing. The camera rig re-aims at course_center every frame, so we
## only need to hand it a good position; the extent drives the victory flyover.
@export var course_center := Vector3(0, 0, -6.5)
@export var course_extent := Vector3(3.0, 0.0, 8.5)
@export var camera_position := Vector3(0, 12.5, 4.5)
@export var camera_fov := 50.0

var balls: Array = []

@onready var cup_area: Area3D = $CupArea

func _ready() -> void:
	cup_area.body_entered.connect(func(body): ball_entered_cup.emit(body))
	# Optional adventure gutters: each Area3D under a "Gutters" node catches a
	# ball that leaves the green at that marked spot. Its "target" metadata is the
	# on-green point the side channel returns the ball to (default: near the cup).
	var gutters := get_node_or_null("Gutters")
	if gutters:
		for area in gutters.get_children():
			if area is Area3D:
				var tgt: Vector3 = area.get_meta("target", cup_position())
				area.body_entered.connect(_on_gutter_body.bind(tgt))

func _on_gutter_body(body: Node3D, target: Vector3) -> void:
	if body is Ball:
		ball_entered_gutter.emit(body, target)

func _physics_process(_delta: float) -> void:
	var cup := cup_area.global_position
	for b in balls:
		if b == null or b.is_sunk:
			continue
		var flat := Vector2(b.global_position.x - cup.x, b.global_position.z - cup.z)
		if flat.length() < MAGNET_RADIUS and b.linear_velocity.length() < MAGNET_MAX_SPEED and b.global_position.y > -0.2:
			var target := Vector3(cup.x, b.global_position.y - 0.5, cup.z)
			b.apply_central_force((target - b.global_position).normalized() * MAGNET_FORCE)

# --- Geometry interface (queried by PlacementController, main, camera) ---

func is_point_on_green(p: Vector3) -> bool:
	var pt := Vector2(p.x, p.z)
	for r in play_rects:
		if r.has_point(pt):
			return true
	return false

func tee_positions() -> Array:
	return tee_slots

func cup_position() -> Vector3:
	var c := cup_area.global_position
	return Vector3(c.x, 0.0, c.z)

func no_build_zones() -> Array:
	var zones: Array = []
	if tee_slots.size() > 0:
		# One disc PER TEE, not just the centroid: with tees spread up to 1.2m
		# from center, the single centroid disc left the outer spawns exposed —
		# a crusher could legally park beside a tee and menace the ball at
		# spawn (owner report, round 2). The centroid disc is kept because its
		# coverage is not a strict subset of the per-tee union.
		var centroid := Vector3.ZERO
		for t in tee_slots:
			centroid += t
			zones.append({"pos": Vector3(t.x, 0.0, t.z), "radius": tee_no_build_radius})
		centroid /= float(tee_slots.size())
		zones.append({"pos": Vector3(centroid.x, 0.0, centroid.z), "radius": tee_no_build_radius})
	zones.append({"pos": cup_position(), "radius": cup_no_build_radius})
	for z in extra_no_build:
		zones.append(z)
	return zones

## Snap a would-be gravestone onto the green and out of any no-build disc so
## it never lands off the course, in the cup, or on the tee.
func clamp_gravestone(pos: Vector3) -> Vector3:
	var best := Vector3(pos.x, 0.0, pos.z)
	if not is_point_on_green(best):
		var pt := Vector2(best.x, best.z)
		var closest := pt
		var best_d := INF
		for r in play_rects:
			var cx: float = clampf(pt.x, r.position.x, r.position.x + r.size.x)
			var cz: float = clampf(pt.y, r.position.y, r.position.y + r.size.y)
			var d := pt.distance_to(Vector2(cx, cz))
			if d < best_d:
				best_d = d
				closest = Vector2(cx, cz)
		best = Vector3(closest.x, 0.0, closest.y)
	for zone in no_build_zones():
		var zp: Vector3 = zone["pos"]
		var zr: float = zone["radius"]
		var away := Vector2(best.x - zp.x, best.z - zp.z)
		if away.length() < zr:
			if away.length() < 0.01:
				away = Vector2(0.0, 1.0)
			var pushed := away.normalized() * zr
			best = Vector3(zp.x + pushed.x, 0.0, zp.z + pushed.y)
	return best

## Chaos round cranks powered traps living in this course.
func set_trap_speed_scale(s: float) -> void:
	for t in $TrapContainer.get_children():
		if t is Trap:
			t.speed_scale = s
