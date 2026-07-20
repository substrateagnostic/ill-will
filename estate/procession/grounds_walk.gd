class_name GroundsWalk
extends Node3D
## DEV WALKABOUT (producer request, live jam night 2): stroll THE PROCESSION's
## grounds as a character, no night, no rolls — a director's review walk.
## Doubles as the live testbed for the A-LOOK approach-reveal contract:
## special stones name themselves as you wander near (ZERO-ENGLISH's one
## sanctioned whisper) via board.reveal_names_near(), wired here first.
##
##   godot --path . -- --procession --walk [--seed=N]
##
## Controls (seat 0): stick/WASD walk · hold A trot · start/ESC quits to the
## title. Kinematic on the terrain function (no physics floor exists out
## here); the boardwalk and bridges carry you at DECK height when you step
## onto their line. G3's real hub walkabout supersedes this probe.

const WALK_SPEED := 3.6
const TROT_SPEED := 7.4
const TURN_LERP := 10.0
const CAM_BACK := 4.6
const CAM_UP := 2.5
const CAM_LERP := 6.0
const DECK_REACH := 1.7          # how far off a path line a deck still carries you
const CHAR_SCALE := 0.78

var board: ProcessionBoardGraph = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _cam: Camera3D = null
var _walker := Vector3.ZERO
var _face := 0.0
var _decks: Array = []           # cached [{x,y,z}] deck points from every segment
var _anim_state := ""

func setup(b: ProcessionBoardGraph, char_scene_path: String, color: Color) -> void:
	board = b
	# start under the lychgate, facing the road north
	_walker = board.lychgate_pos() + Vector3(0.8, 0, 1.2)
	# the deck cache: every path segment sampled dense, deck-aware y
	for tag in ProcessionGrounds.SEGS:
		for e in ProcessionGrounds.sample_segment(String(tag), 10):
			var p: Vector2 = e.p
			var y := ProcessionGrounds.path_y(String(tag), float(e.t01), p)
			_decks.append(Vector3(p.x, y, p.y))
	# the body
	if ResourceLoader.exists(char_scene_path):
		var inst: Node3D = (load(char_scene_path) as PackedScene).instantiate()
		inst.scale = Vector3.ONE * CHAR_SCALE
		add_child(inst)
		_model = inst
		_anim = inst.find_child("AnimationPlayer", true, false)
		if _anim:
			for a in ["Idle", "Walking_A", "Running_A"]:
				if _anim.has_animation(a):
					_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			_play("Idle")
	else:
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 1.1
		body.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		body.material_override = mat
		body.position.y = 0.6
		add_child(body)
		_model = body
	global_position = _ground(_walker)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	get_parent().add_child.call_deferred(_cam)
	_cam.set_deferred("current", true)

func _play(a: String) -> void:
	if _anim and _anim_state != a and _anim.has_animation(a):
		_anim_state = a
		_anim.play(a, 0.2)

## Ground height under a point: the land (wading clamped at the waterline),
## or a path DECK when standing on its line and it rides above the land —
## the boardwalk and both bridges carry you across their water.
func _ground(p: Vector3) -> Vector3:
	var y := maxf(ProcessionGrounds.height(p.x, p.z), ProcessionGrounds.WATER_Y - 0.22)
	var best := DECK_REACH
	for d in _decks:
		var dv := d as Vector3
		var dist := Vector2(p.x - dv.x, p.z - dv.z).length()
		if dist < best and dv.y > y - 0.35:
			best = dist
			y = maxf(y, dv.y)
	return Vector3(p.x, y, p.z)

func _process(dt: float) -> void:
	if board == null or _cam == null:
		return
	var mv := PlayerInput.get_move(0)
	var trot := PlayerInput.is_down(0, "a")
	var speed := TROT_SPEED if trot else WALK_SPEED
	if mv.length() > 1.0:
		mv = mv.normalized()
	if mv.length() > 0.15:
		# camera-relative drive
		var fwd := -_cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var dir := (right * mv.x + fwd * -mv.y)
		if dir.length() > 0.01:
			dir = dir.normalized()
			_walker += dir * speed * dt
			_walker.x = clampf(_walker.x, ProcessionGrounds.EXT_X.x + 3.0, ProcessionGrounds.EXT_X.y - 3.0)
			_walker.z = clampf(_walker.z, ProcessionGrounds.EXT_Z.x + 3.0, ProcessionGrounds.EXT_Z.y - 3.0)
			_face = lerp_angle(_face, atan2(dir.x, dir.z), TURN_LERP * dt)
			_play("Running_A" if trot else "Walking_A")
	else:
		_play("Idle")
	var g := _ground(_walker)
	_walker.y = lerpf(_walker.y, g.y, minf(1.0, 14.0 * dt))
	global_position = Vector3(_walker.x, _walker.y, _walker.z)
	if _model:
		_model.rotation.y = _face
	# follow camera, gently behind
	var fwd_now := Vector3(sin(_face), 0, cos(_face))
	var want := global_position - fwd_now * CAM_BACK + Vector3(0, CAM_UP, 0)
	want.y = maxf(want.y, ProcessionGrounds.height(want.x, want.z) + 1.2)
	_cam.global_position = _cam.global_position.lerp(want, minf(1.0, CAM_LERP * dt))
	_cam.look_at(global_position + Vector3(0, 1.1, 0), Vector3.UP)
	# THE APPROACH-REVEAL, finally wired: specials whisper their names to a
	# stroller (pooled + idempotent — the board's own contract).
	board.reveal_names_near(global_position)
	# leave the grounds (ESC; the pad's START opens the house pause as anywhere)
	if Input.is_action_just_pressed("ui_cancel"):
		board.clear_approach_names()
		PartySetup.quit_to_title()
