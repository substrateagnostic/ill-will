class_name ProcessionExecutor
extends Node
## THE EXECUTOR — dice-master and host of the wake. He owns the serial half of
## every round: the staggered REVEAL cascade where each landing is named, one
## victim at a time, camera pushed in. His register is the will-reading voice
## from estate.gd — dry, formal, and quietly delighted by everyone's misfortune.
##
## Presentation only: the state machine (procession.gd) decides WHAT happened
## and applies it; the Executor only decides how cruelly to phrase it. All line
## choices are drawn from a passed-in seeded RNG, so the couch and a net mirror
## hear the same eulogy.

# ~40 dry line variants, pooled by the beat they narrate. The lines themselves
# now live in dialog.json (keys "executor.*") so Alex can rewrite the Executor's
# whole register in one file; these getters just fetch the current pool. %s slots
# are filled by procession.gd with player names (already colour-tagged in the
# banner). pick() indexes by pool SIZE, so a seeded draw stays deterministic as
# long as an edit keeps the same number of lines.
static var GREETING: Array:
	get: return Dialog.paras("executor.greeting")
static var SHRINE: Array:
	get: return Dialog.paras("executor.shrine")
static var GRAVE: Array:
	get: return Dialog.paras("executor.grave")
static var GRAVE_TOLL: Array:
	get: return Dialog.paras("executor.grave_toll")
static var STALL: Array:
	get: return Dialog.paras("executor.stall")
static var CODICIL: Array:
	get: return Dialog.paras("executor.codicil")
static var CODICIL_SHORT: Array:
	get: return Dialog.paras("executor.codicil_short")
static var SEANCE: Array:
	get: return Dialog.paras("executor.seance")
static var TOLLGATE_TAKE: Array:
	get: return Dialog.paras("executor.tollgate_take")
static var TOLLGATE_PASS: Array:
	get: return Dialog.paras("executor.tollgate_pass")
static var VENDETTA: Array:
	get: return Dialog.paras("executor.vendetta")
static var VENDETTA_RESULT: Array:
	get: return Dialog.paras("executor.vendetta_result")
static var BLANK: Array:
	get: return Dialog.paras("executor.blank")
# --- graph-board pools (doc 28 space set; the ring pools above stay for any
# caller that still speaks them — pools are data, not topology) ---
static var OFFERING: Array:
	get: return Dialog.paras("executor.offering")
static var GRAVE_GOODS: Array:
	get: return Dialog.paras("executor.grave_goods")
static var CART: Array:
	get: return Dialog.paras("executor.cart")
static var FERRY: Array:
	get: return Dialog.paras("executor.ferry")
static var CROSSROADS_LAND: Array:
	get: return Dialog.paras("executor.crossroads_land")
static var ARRIVAL: Array:
	get: return Dialog.paras("executor.arrival")
static var BELL: Array:
	get: return Dialog.paras("executor.bell")
static var HOUSE_AWAKENS: Array:
	get: return Dialog.paras("executor.house_awakens")
static var HOUSE_LOSER: Array:
	get: return Dialog.paras("executor.house_loser")
static var WILL_OPEN: Array:
	get: return Dialog.paras("executor.will_open")
# Dry commentary for the dead air at the top of a round (F9). Drawn from the
# PRESENTATION rng only (via aside()), so it never touches the sim stream.
static var ROUND_OPENER: Array:
	get: return Dialog.paras("executor.round_opener")

# --- THE NON-PLAY VOICE (W6) --------------------------------------------------
# The Executor's register, extended to the moments when nobody is playing: the
# pause overlay, a long idle at a menu desk, and the quit-confirm. Surfaced by
# core/party_setup.gd (the shell overlay), drawn via the same seeded pick(). These
# are LOCAL UI narration only — they never touch the sim stream or the net mirror,
# so they carry no receipt weight. Composure stays flat; the codicil does the work.

## Fires once when the settings/pause overlay is opened mid-night. One line, on
## the pause screen. No %s.
static var PAUSE: Array:
	get: return Dialog.paras("executor.pause")
## Fires after a long true idle at a menu desk awaiting the couch. Exactly one
## %s per line (the kept-waiting seat's name); pass [name].
static var IDLE: Array:
	get: return Dialog.paras("executor.idle")
## Fires when a departure is initiated at the quit-confirm. No %s.
static var QUIT_CONFIRM: Array:
	get: return Dialog.paras("executor.quit_confirm")

# --- THE BODY (doc 24 F6/F7) --------------------------------------------------
const Body := preload("res://estate/procession/executor_body.gd")

# Reaction moods handed to the body's strike. Kept as ints so the body needn't
# preload this script. NEUTRAL is the dry no-reaction default (the anticlimax).
const MOOD_NEUTRAL := 0
const MOOD_GOOD := 1
const MOOD_BAD := 2
const MOOD_CODICIL := 3
const MOOD_WATCH := 4
const MOOD_RISE := 5

var banner: RichTextLabel = null   # procession supplies the reveal banner
var after_say := Callable()        # procession hook: fit + grow the band per line
var cam: Camera3D = null           # procession supplies the live camera
var body: ProcessionExecutorBody = null   # the embodied host (null when headless)
var board: ProcessionBoardGraph = null    # supplies stone positions for gestures
# PRESENTATION-side rng — used only for gesture variety and the eulogy templates,
# NEVER the sim stream, so no flourish can shift the byte-identical receipt.
var _prng := RandomNumberGenerator.new()

func setup(reveal_banner: RichTextLabel, camera: Camera3D) -> void:
	banner = reveal_banner
	cam = camera

# --------------------------------------------------------------------------
# EMBODIMENT + GESTURE ORCHESTRATION (doc 24 F6/F7)
# --------------------------------------------------------------------------
## Give the host a body and a place to stand. No-op under headless — the soak has
## no viewport, so the receipt path never builds or animates the figure and the
## tally stays byte-identical.
func embody(world: Node3D, board_ref: ProcessionBoardGraph, prng_seed: int) -> void:
	board = board_ref
	_prng.seed = prng_seed * 2654435761 + 1013904223   # a presentation stream of our own
	if DisplayServer.get_name() == "headless":
		return
	body = Body.new(int(_prng.randi()))
	world.add_child(body)
	# Stand him at THE MANOR GATE (doc 28 §10 — the Executor rings the Bell),
	# just inside the arch on the finish apron, facing the grounds' CENTER so
	# every landing anywhere on the three roads plays out before him.
	var gate := board.gate_pos()
	var out := gate - board.CENTER
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	var right := out.cross(Vector3.UP).normalized()
	var stand := gate - out * 2.2 + right * 0.5
	stand.y = gate.y
	body.stand_at(stand, board.CENTER)

func has_body() -> bool:
	return body != null

## THE HOUSE AWAKENS — the host rises (F7).
func gesture_house_rise() -> void:
	if body != null:
		body.rise()

## Between rounds: the ledger turns (F7). The dry round-opener aside is layered on
## by the procession hook in part 3; the page-turn ships with the body.
func begin_round() -> void:
	if body != null:
		body.page_turn()

## Paint a dry aside during the dead air (round openers, colour commentary). Drawn
## from the PRESENTATION rng, so it never perturbs the sim stream or the receipt.
func aside(pool: Array, color: Color, args: Array = []) -> void:
	if banner == null:
		return
	say(pick(pool, _prng, args), color)

## Ease the host home to his idle rest pose at the close of a reveal cascade.
func settle_body() -> void:
	if body != null:
		body.settle()

## A low three-quarter host shot from the drive side — the eulogy framing and the
## verification stills. Eased; leaves the per-frame look-at aimed at his face.
func frame_body(dur := 0.8) -> void:
	if cam == null or body == null:
		return
	var focus := body.global_position + Vector3(0, 1.7, 0)
	var fwd := (board.CENTER - body.global_position) if board != null else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var pos := body.global_position + fwd * 3.9 + side * 1.6 + Vector3(0, 1.85, 0)
	_aim = focus
	_aiming = true
	var tw := cam.create_tween()
	tw.tween_property(cam, "global_position", pos, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Windowed capture only (doc 24 verify): pose the idle body, then a staged
## reveal gesture, grabbing each via the procession's settled snap. Never headless.
func showcase_gestures(proc: Node) -> void:
	if body == null:
		return
	frame_body(0.6)
	await proc.get_tree().create_timer(0.75).timeout   # let the framing tween settle
	await proc._cap_snap("exec_idle")
	# Gesture at the homestretch stone beside his gate post.
	var stone := board.space_pos(board.node_count() - 2) if board != null else Vector3.ZERO
	var yaw := body.yaw_toward(stone)
	body.anticipate(yaw, 0.85)
	await proc.get_tree().create_timer(0.45).timeout
	body.present(yaw, 0.9, MOOD_CODICIL)
	await proc.get_tree().create_timer(0.28).timeout
	await proc._cap_snap("exec_gesture")

# --------------------------------------------------------------------------
# COMIC TIMING (doc 24 F8) — the anticipation cascade for one reveal
# --------------------------------------------------------------------------
## THE WIND-UP. Before the punchline the host leans BACK and inclines toward the
## stone, holds a beat SCALED BY STAKES (a Deed claim gets the longest lean-in),
## then SNAPS forward as the line lands, with the reaction beat keyed to the
## space. The caller awaits this between the camera push and the resolve, so the
## pause becomes felt silence, not dead air. Presentation only, gated by the
## caller behind `not _fast`, so the headless receipt never runs a frame of it.
func anticipate(space_idx: int, is_codicil: bool) -> void:
	if body == null or board == null:
		return
	var stone := board.space_pos(space_idx)
	var stakes := _stakes_for(space_idx, is_codicil)
	var yaw := body.yaw_toward(stone)
	body.anticipate(yaw, stakes)
	# 0.26s floor + up to ~0.75s more for the biggest swings (the Codicil).
	var hold := 0.26 + stakes * 0.75
	await get_tree().create_timer(hold).timeout
	body.present(yaw, stakes, _mood_for(space_idx, is_codicil))

## How much drama a landing carries, 0..1 — sets both the lean depth and the
## length of the anticipation pause. The MANOR GATE (an arrival) is the crown;
## a blank path stone is the anticlimax and barely earns a beat.
func _stakes_for(space_idx: int, is_codicil: bool) -> float:
	if is_codicil:
		return 1.0   # legacy hook — no caller passes true on the graph board
	match board.type_at(space_idx):
		ProcessionBoardSpaces.GATE: return 1.0
		ProcessionBoardSpaces.VENDETTA: return 0.8
		ProcessionBoardSpaces.OPEN_GRAVE: return 0.7
		ProcessionBoardSpaces.SEANCE: return 0.62
		ProcessionBoardSpaces.FERRY_TOLL: return 0.55
		ProcessionBoardSpaces.OFFERING: return 0.5
		ProcessionBoardSpaces.CART: return 0.45
		ProcessionBoardSpaces.GRAVE_GOODS: return 0.4
		ProcessionBoardSpaces.CROSSROADS: return 0.3
	return 0.16   # BLANK / path stone — the dry anticlimax

## The reaction gesture keyed to the space (see MOOD_* / body._react).
func _mood_for(space_idx: int, is_codicil: bool) -> int:
	if is_codicil:
		return MOOD_CODICIL
	match board.type_at(space_idx):
		ProcessionBoardSpaces.GATE: return MOOD_CODICIL
		ProcessionBoardSpaces.OFFERING: return MOOD_GOOD
		ProcessionBoardSpaces.CART: return MOOD_GOOD
		ProcessionBoardSpaces.OPEN_GRAVE: return MOOD_BAD
		ProcessionBoardSpaces.FERRY_TOLL: return MOOD_BAD
		ProcessionBoardSpaces.VENDETTA: return MOOD_WATCH
		ProcessionBoardSpaces.SEANCE: return MOOD_WATCH
		ProcessionBoardSpaces.CROSSROADS: return MOOD_WATCH
	return MOOD_NEUTRAL

## Fill one line from a pool by seeded index (deterministic).
static func pick(pool: Array, rng: RandomNumberGenerator, args: Array = []) -> String:
	var raw: String = String(pool[rng.randi_range(0, pool.size() - 1)])
	if args.is_empty():
		return raw
	return raw % args

## Show a reveal line in the banner, colour-keyed to the acting seat. The push-
## in is driven by procession (it owns the anchor); this only paints the text.
func say(text: String, color: Color) -> void:
	if banner == null:
		return
	banner.clear()
	banner.push_color(color)
	banner.append_text(text)
	banner.pop_all()
	# The band fits its font + grows to hold this line BEFORE it slides in, so the
	# estate's wordier proclamations (and the eulogy) never clip. The band's own
	# `normal_font_size` theme size now governs — no inline push fighting the fit.
	if after_say.is_valid():
		after_say.call()
	banner.visible = true

func clear_banner() -> void:
	if banner:
		banner.visible = false

## Paint one eulogy line (F33) with a solemn reading cadence on the body — a slow
## nod on some lines, a ledger page-turn on others. Same lower-third as a reveal.
func say_eulogy(text: String, color: Color, index: int) -> void:
	say(text, color)
	if body == null:
		return
	if index % 3 == 2:
		body.page_turn()
	elif index % 2 == 0:
		body.nod(0.5)

var _aim := Vector3.ZERO   # live look-at target, tracked every frame while set
var _aiming := false

func _process(_delta: float) -> void:
	# Keeping the aim in _process lets a position tween and the look direction
	# resolve together without a fragile per-step method tween.
	if _aiming and is_instance_valid(cam):
		cam.look_at(_aim, Vector3.UP)

## THE DECIDING-MOMENT push toward a landing (reuses the FinalStretch language).
func push_to(anchor: Vector3, look_at: Vector3) -> void:
	if cam == null:
		return
	_aim = look_at
	_aiming = true
	var tw := cam.create_tween()
	tw.tween_property(cam, "global_position", anchor, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func reset_camera(home_pos: Vector3, look_at: Vector3, dur := 0.5) -> void:
	if cam == null:
		return
	_aim = look_at
	_aiming = true
	var tw := cam.create_tween()
	tw.tween_property(cam, "global_position", home_pos, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
