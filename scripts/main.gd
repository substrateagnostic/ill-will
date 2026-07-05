extends Node3D
## Par for the Curse — implements the anthology module contract by
## duck-typing core/minigame.gd (signal finished + results dictionary).

signal finished(results: Dictionary)

enum Phase { DRAFT, BUILD, PUTT, BETWEEN }

const BALL_SCENE := preload("res://scenes/ball.tscn")
const GRAVESTONE_SCENE := preload("res://scenes/gravestone.tscn")
const CHAR_SCENES := [
	preload("res://assets/models/kaykit/Barbarian.glb"),
	preload("res://assets/models/kaykit/Knight.glb"),
	preload("res://assets/models/kaykit/Mage.glb"),
	preload("res://assets/models/kaykit/Rogue.glb"),
]
const BUILD_TIME_LIMIT := 25.0
const ROYALTY := 2
## Each player drafts + places this many traps per build phase (v2: hazard
## density doubled). Grudge/cursed rules apply to the first pick only.
const TRAPS_PER_BUILD := 2
const CHAOS_TRAP_SPEED := 1.6

var balls: Array = []
var caddies: Array = []
var round_manager: RoundManager
var course: Course
var phase := Phase.BETWEEN
var draft_order: Array = []
var draft_pointer := 0
var current_hand: Array = []
var grudge_card_idx := -1
var autobuild_count := 0
var _picks_this_turn := 0
var _build_timer := 0.0
var _currency_log: Array = []
var _highlights: Array = []
var _golden_hour_done := false

# --- minimal per-player bot driver (turn-based) --------------------------------
# A seat plays itself if PlayerInput marks it a bot OR the --parbots flag forces
# ALL seats to bots. Human seats are untouched (mouse drives draft/build/putt).
# It drives the SAME debug entry points a verify run uses, so no gameplay/putt
# physics is affected. All bot randomness comes from _bot_rng (seeded from
# GameState.rng), so a --parbots match is reproducible per --seed.
var _par_bot_all := false
var _bot_rng := RandomNumberGenerator.new()
var _bot_ctx := ""          # actionable-turn key; resets the think timer on change
var _bot_think_t := 0.0

@onready var putt_controller: Node3D = $PuttController
@onready var placement: Node3D = $PlacementController
@onready var camera_rig: Node3D = $CameraRig
@onready var sun: DirectionalLight3D = $Sun
@onready var fill_light: DirectionalLight3D = $FillLight
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var turn_label: Label = $UI/TurnLabel
@onready var stroke_label: Label = $UI/StrokeLabel
@onready var round_label: Label = $UI/RoundLabel
@onready var banner: Label = $UI/Banner
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows
@onready var draft_panel: PanelContainer = $UI/DraftPanel
@onready var draft_label: Label = $UI/DraftPanel/DraftBox/DraftLabel
@onready var card_row: HBoxContainer = $UI/DraftPanel/DraftBox/CardRow
@onready var build_hint: Label = $UI/BuildHint

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--parbots":
			_par_bot_all = true
	# Seed the bot rng FROM GameState.rng without consuming its stream (read the
	# seed value, don't draw), so drafting/course/trap RNG is untouched.
	_bot_rng.seed = int(GameState.rng.seed) ^ 0x9E3779B9
	_setup_course()
	round_manager = RoundManager.new()
	round_manager.name = "RoundManager"
	add_child(round_manager)
	round_manager.turn_started.connect(_on_turn_started)
	round_manager.round_finished.connect(_on_round_finished)
	round_manager.ball_resolved.connect(_on_ball_resolved)
	putt_controller.stroke_taken.connect(_on_stroke_taken)
	course.ball_entered_cup.connect(_on_cup_entry)
	placement.trap_container = course.get_node("TrapContainer")
	placement.course = course
	placement.trap_placed.connect(_on_trap_placed)
	_apply_course_camera()
	_spawn_balls()
	banner.visible = false
	_rebuild_scoreboard()
	_start_round()

func _setup_course() -> void:
	print("COURSE selected: %s" % GameState.course_id)
	var scene: PackedScene = load("res://scenes/courses/%s.tscn" % GameState.course_id)
	course = scene.instantiate()
	course.name = "Course"
	add_child(course)
	move_child(course, 0)

func _apply_course_camera() -> void:
	camera_rig.course_center = course.course_center
	camera_rig.course_extent = course.course_extent
	camera_rig.home_position = course.camera_position
	var cam: Camera3D = camera_rig.get_node("Camera3D")
	cam.position = course.camera_position
	cam.fov = course.camera_fov

func _spawn_balls() -> void:
	var n: int = GameState.players.size()
	for i in n:
		var b: Ball = BALL_SCENE.instantiate()
		b.player_index = i
		b.player_color = GameState.players[i].color
		add_child(b)
		b.global_position = _tee_pos(i)
		b.sunk.connect(round_manager.on_ball_sunk.bind(i))
		b.sunk.connect(_on_any_ball_sunk.bind(i))
		b.died.connect(_on_ball_died.bind(i))
		balls.append(b)
		var c := Caddy.new()
		add_child(c)
		var side := -1.0 if i % 2 == 0 else 1.0
		var cx: float = course.course_center.x + (course.course_extent.x + 0.9) * side
		var cz: float = course.course_center.z + 0.2 + floorf(i / 2.0) * 1.5
		c.global_position = Vector3(cx, -0.4, cz)
		c.rotation_degrees.y = 105.0 * side
		c.setup(CHAR_SCENES[i], GameState.players[i].color)
		caddies.append(c)
	course.balls = balls

func _tee_pos(i: int) -> Vector3:
	var tees: Array = course.tee_positions()
	var n: int = GameState.players.size()
	var idx: int = i if n == 4 else i + (4 - n) / 2
	idx = clampi(idx, 0, tees.size() - 1)
	var pos: Vector3 = tees[idx]
	return pos

func _start_round() -> void:
	banner.visible = false
	for i in balls.size():
		balls[i].reset_for_round(_tee_pos(i))
		caddies[i].revive()
	if GameState.is_chaos_round():
		round_label.text = "CHAOS ROUND"
		_enter_chaos_round()
		_begin_putt_phase()
		return
	round_label.text = "ROUND %d / %d" % [GameState.round_num, GameState.rounds_total]
	var standings := GameState.standings()
	draft_order = standings.duplicate()
	draft_order.reverse()
	draft_pointer = 0
	_picks_this_turn = 0
	_begin_draft_turn()

func _enter_chaos_round() -> void:
	course.set_trap_speed_scale(CHAOS_TRAP_SPEED)
	_apply_golden_hour()
	Sfx.play("match_win", -4.0)
	_flash_banner("CHAOS ROUND\nNO WAITING — ALL LIVE", Color(1.0, 0.55, 0.2), 2.8)

func _apply_golden_hour() -> void:
	if _golden_hour_done:
		return
	_golden_hour_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "light_color", Color(1.0, 0.5, 0.24), 1.4)
	tw.tween_property(sun, "light_energy", 1.7, 1.4)
	tw.tween_property(sun, "rotation_degrees", Vector3(-14, -128, 0), 1.4)
	tw.tween_property(fill_light, "light_color", Color(1.0, 0.62, 0.4), 1.4)
	var env: Environment = world_env.environment
	tw.tween_property(env, "fog_light_color", Color(1.0, 0.55, 0.3), 1.4)
	tw.tween_property(env, "fog_density", 0.012, 1.4)
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	tw.tween_property(sky_mat, "sky_top_color", Color(0.78, 0.42, 0.34), 1.4)
	tw.tween_property(sky_mat, "sky_horizon_color", Color(1.0, 0.55, 0.28), 1.4)

func _begin_draft_turn() -> void:
	if draft_pointer >= draft_order.size():
		_begin_putt_phase()
		return
	phase = Phase.DRAFT
	var p: int = draft_order[draft_pointer]
	var player = GameState.players[p]
	current_hand = TrapCatalog.random_hand(GameState.rng)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forcetrap="):
			current_hand[0] = arg.trim_prefix("--forcetrap=")
	grudge_card_idx = -1
	# Cursed-luck and grudge picks only apply to a player's FIRST trap this turn.
	var is_last_place: bool = _picks_this_turn == 0 and p == GameState.standings().back() and GameState.round_num > 1
	if is_last_place:
		current_hand[0] = TrapCatalog.random_cursed(GameState.rng)
	if _picks_this_turn == 0 and player.grudge > 0:
		grudge_card_idx = current_hand.size()
		current_hand.append(TrapCatalog.random_cursed(GameState.rng))
	var pick_tag := "" if TRAPS_PER_BUILD <= 1 else "  (%d/%d)" % [_picks_this_turn + 1, TRAPS_PER_BUILD]
	draft_label.text = "%s — DRAFT YOUR TRAP%s%s" % [player.name, pick_tag, "  (CURSED LUCK: last place)" if is_last_place else ""]
	draft_label.add_theme_color_override("font_color", player.color)
	for c in card_row.get_children():
		c.queue_free()
	for idx in current_hand.size():
		var id: String = current_hand[idx]
		var info: Dictionary = TrapCatalog.info(id)
		var btn := Button.new()
		var cursed := TrapCatalog.is_cursed(id)
		var title: String = ("☠ " + info.name) if cursed else info.name
		if idx == grudge_card_idx:
			title = "GRUDGE PICK\n" + title
		btn.text = "%s\n\n%s" % [title, info.desc]
		btn.custom_minimum_size = Vector2(230, 160)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		if cursed:
			btn.modulate = Color(1.0, 0.75, 1.0)
		btn.pressed.connect(_on_card_picked.bind(idx))
		card_row.add_child(btn)
	draft_panel.visible = true
	turn_label.text = "%s IS SCHEMING" % player.name
	turn_label.add_theme_color_override("font_color", player.color)
	stroke_label.text = ""

func _on_card_picked(card_idx: int) -> void:
	if phase != Phase.DRAFT or card_idx >= current_hand.size():
		return
	var p: int = draft_order[draft_pointer]
	var player = GameState.players[p]
	var id: String = current_hand[card_idx]
	Sfx.play("card")
	if card_idx == grudge_card_idx:
		Sfx.play("grudge")
		player.grudge = maxi(0, player.grudge - 1)
	draft_panel.visible = false
	phase = Phase.BUILD
	_build_timer = 0.0
	build_hint.visible = true
	var info: Dictionary = TrapCatalog.info(id)
	turn_label.text = "%s PLACES: %s" % [player.name, info.name]
	placement.begin(TrapCatalog.load_scene(id), p, player.color, info.get("params", {}))
	# Course saturated for this footprint? Skip the placement silently.
	if not placement.has_valid_placement():
		placement.cancel()
		build_hint.visible = false
		_advance_after_placement()

func _on_trap_placed(_trap: Trap) -> void:
	build_hint.visible = false
	_advance_after_placement()

func _advance_after_placement() -> void:
	_picks_this_turn += 1
	if _picks_this_turn < TRAPS_PER_BUILD:
		_begin_draft_turn()
	else:
		_picks_this_turn = 0
		draft_pointer += 1
		_begin_draft_turn()

func _begin_putt_phase() -> void:
	phase = Phase.PUTT
	round_manager.start_round(GameState.standings(), balls, GameState.is_chaos_round())

func _process(delta: float) -> void:
	# mouse putting is disabled on a bot's turn (the bot drives it instead)
	var cur := round_manager.current_player()
	putt_controller.enabled = phase == Phase.PUTT and round_manager.is_turn_ready() and not _is_bot(cur)
	_bot_tick(delta)
	if phase == Phase.BUILD:
		_build_timer += delta
		if _build_timer > BUILD_TIME_LIMIT:
			placement.cancel()
			build_hint.visible = false
			_flash_banner("TOO SLOW — TRAP FORFEITED", Color(0.8, 0.8, 0.8), 1.5)
			_advance_after_placement()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		GameState.reset_match()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_cup_entry(body: Node3D) -> void:
	if body is Ball and not body.is_sunk:
		body.mark_sunk()

func _on_turn_started(p: int) -> void:
	var player = GameState.players[p]
	putt_controller.ball = balls[p]
	camera_rig.ball = balls[p]
	turn_label.text = "%s'S TURN" % player.name
	turn_label.add_theme_color_override("font_color", player.color)
	_update_stroke_label(p)

func _on_stroke_taken() -> void:
	round_manager.notify_stroke()
	_update_stroke_label(round_manager.current_player())

func _update_stroke_label(p: int) -> void:
	if p < 0:
		stroke_label.text = ""
		return
	stroke_label.text = "STROKE %d / %d" % [mini(round_manager.strokes[p] + 1, RoundManager.STROKE_CAP), RoundManager.STROKE_CAP]

func _on_any_ball_sunk(p: int) -> void:
	print("BALL_SUNK p=%d round=%d" % [p, GameState.round_num])
	Sfx.play("sink")
	caddies[p].react("Cheer")
	_spawn_confetti(course.get_node("CupArea").global_position + Vector3(0, 0.6, 0), GameState.players[p].color)
	_flash_banner("%s SINKS IT!" % GameState.players[p].name, GameState.players[p].color, 1.4)

func _on_ball_died(killer: Trap, victim: int) -> void:
	var v = GameState.players[victim]
	v.grudge += 1
	var death_pos: Vector3 = balls[victim].global_position
	Sfx.play("splat")
	Sfx.play("death")
	caddies[victim].react_death()
	camera_rig.shake(0.35)
	camera_rig.focus_on(death_pos, 1.3)
	_spawn_death_fx(death_pos, v.color)
	_spawn_gravestone(death_pos, v.color)
	_currency_log.append({"type": "grudge", "player": victim, "amount": 1, "reason": "died"})
	var credit := "THE COURSE"
	var credit_color := Color(0.9, 0.9, 0.9)
	if killer != null and killer.author_index >= 0:
		var a = GameState.players[killer.author_index]
		credit = "%s'S %s" % [a.name, killer.display_name]
		credit_color = a.color
		if killer.author_index == victim:
			_highlights.append("%s died to their OWN %s" % [a.name, killer.display_name])
		else:
			a.score += ROYALTY
			a.royalties += ROYALTY
			caddies[killer.author_index].react("Cheer")
			_currency_log.append({"type": "royalty", "player": killer.author_index, "amount": ROYALTY, "reason": "killed %s" % v.name})
			_rebuild_scoreboard()
	elif killer != null:
		credit = killer.display_name
	if GameState.is_chaos_round():
		_highlights.append("CHAOS CLAIMED %s" % v.name)
	print("DEATH: %s by %s (round %d)" % [v.name, credit, GameState.round_num])
	_flash_banner("%s DIED!\nDEATH BY: %s" % [v.name, credit], credit_color, 2.4)
	round_manager.on_ball_died(victim)
	_slow_mo()

func _slow_mo() -> void:
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.4, true, false, true).timeout
	Engine.time_scale = 1.0

func _spawn_death_fx(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos + Vector3(0, 0.15, 0)
	p.emitting = false
	p.one_shot = true
	p.amount = 28
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.6
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _spawn_gravestone(pos: Vector3, color: Color) -> void:
	var g := GRAVESTONE_SCENE.instantiate()
	course.get_node("GravestoneContainer").add_child(g)
	g.global_position = course.clamp_gravestone(pos)
	g.rotation_degrees.y = GameState.rng.randf_range(-25.0, 25.0)
	g.setup(color, GameState.round_num)

func _on_ball_resolved(p: int, status: String) -> void:
	if status == "dnf":
		GameState.players[p].grudge += 1
		_flash_banner("%s IS OUT OF STROKES" % GameState.players[p].name, Color(0.7, 0.7, 0.7), 1.4)

func _on_round_finished(finish_order: Array, _strokes: Dictionary) -> void:
	phase = Phase.BETWEEN
	GameState.award_round_points(finish_order)
	_rebuild_scoreboard()
	GameState.round_num += 1
	if GameState.is_match_over():
		var champ: int = GameState.standings()[0]
		print("MATCH_OVER champ=", GameState.players[champ].name)
		turn_label.text = ""
		stroke_label.text = ""
		round_label.text = "FINAL"
		_flash_banner("THE COURSE REMEMBERS", Color(1, 0.85, 0.2), 8.0)
		var tw: Tween = camera_rig.start_flyover(8.5)
		await tw.finished
		print("FLYOVER_DONE")
		Sfx.play("match_win")
		caddies[champ].react("Cheer")
		_spawn_confetti(caddies[champ].global_position + Vector3(0, 1.5, 0), GameState.players[champ].color)
		_flash_banner("%s WINS THE MATCH!\n(press R for a rematch)" % GameState.players[champ].name, GameState.players[champ].color, 9999.0)
		var points := {}
		var monuments: Array = []
		for i in GameState.players.size():
			points[i] = GameState.players[i].score
			if GameState.players[i].royalties >= 6:
				monuments.append({"player": i, "kind": "butcher", "label": "%s, Architect of Ruin" % GameState.players[i].name})
		finished.emit({
			"placements": GameState.standings(),
			"points": points,
			"currency_events": _currency_log.duplicate(),
			"highlights": _highlights.slice(0, 3),
			"monuments": monuments,
		})
		return
	Sfx.play("round_over")
	_flash_banner("ROUND OVER", Color(1, 0.85, 0.2), 2.6)
	await get_tree().create_timer(3.0).timeout
	_start_round()

func _flash_banner(text: String, color: Color, duration: float) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.55, 0.55)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func(): banner.visible = false)

func _spawn_confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 16
		p.lifetime = 1.1
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -7.0, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.02, 0.07)
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	for i in GameState.standings():
		var player = GameState.players[i]
		var row := Label.new()
		var extras := ""
		if player.royalties > 0:
			extras += "  †%d" % player.royalties
		if player.grudge > 0:
			extras += "  ♠%d" % player.grudge
		row.text = "%s  %d%s" % [player.name, player.score, extras]
		row.add_theme_font_size_override("font_size", 26)
		row.add_theme_color_override("font_color", player.color)
		score_rows.add_child(row)

func is_turn_ready() -> bool:
	return phase == Phase.PUTT and round_manager.is_turn_ready()

func debug_pick_card(i: int) -> void:
	if phase == Phase.DRAFT:
		_on_card_picked(mini(i, current_hand.size() - 1))

func debug_place_auto() -> void:
	if phase != Phase.BUILD or not placement.active:
		return
	var rot := float((autobuild_count * 45) % 180)
	autobuild_count += 1
	if not placement.debug_place_scan(rot, GameState.rng):
		# Saturated: bail on this placement and move the build along.
		placement.cancel()
		build_hint.visible = false
		_advance_after_placement()

# --- minimal per-player bot ----------------------------------------------------
func _is_bot(i: int) -> bool:
	return _par_bot_all or (i >= 0 and PlayerInput.is_bot(i))

## Drives whichever seat currently owns the turn, if that seat is a bot. Fires
## once per actionable turn after a short think delay; a human seat is skipped
## (its mouse input flows normally). Chaos rounds have no draft/build, so only
## the PUTT branch runs there.
func _bot_tick(delta: float) -> void:
	var actor := -1
	match phase:
		Phase.DRAFT:
			if draft_pointer < draft_order.size():
				actor = draft_order[draft_pointer]
		Phase.BUILD:
			if placement.active and draft_pointer < draft_order.size():
				actor = draft_order[draft_pointer]
		Phase.PUTT:
			if round_manager.is_turn_ready():
				actor = round_manager.current_player()
	if actor < 0 or not _is_bot(actor):
		_bot_ctx = ""
		_bot_think_t = 0.0
		return
	# ctx changes whenever the actionable turn changes; the stroke count keeps
	# successive putts by the same bot (in one turn) as distinct think windows
	var ctx := "%d:%d" % [phase, actor]
	if phase == Phase.PUTT:
		ctx += ":%d" % int(round_manager.strokes.get(actor, 0))
	if ctx != _bot_ctx:
		_bot_ctx = ctx
		_bot_think_t = 0.0
	_bot_think_t += delta
	match phase:
		Phase.DRAFT:
			if _bot_think_t >= 1.0:
				debug_pick_card(0)          # pick the first offered card
		Phase.BUILD:
			if _bot_think_t >= 1.0:
				_bot_build()
		Phase.PUTT:
			if _bot_think_t >= 1.5 and balls[actor].is_stopped():
				_bot_putt(actor)

func _bot_build() -> void:
	if phase != Phase.BUILD or not placement.active:
		return
	var rot := _bot_rng.randf_range(0.0, 360.0)
	if not placement.debug_place_scan(rot, GameState.rng):
		# course saturated for this footprint: skip the placement, move on
		placement.cancel()
		build_hint.visible = false
		_advance_after_placement()

## Aim straight at the cup with a little noise; power scales with distance.
## Routed through the existing debug_putt entry point (no putt-feel constants
## touched). angle 0 = -Z; debug_putt does dir = (0,0,-1).rotated(UP, angle).
func _bot_putt(actor: int) -> void:
	var b: Ball = balls[actor]
	var cup := course.cup_position()
	var to := cup - b.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.001 else Vector3(0, 0, -1)
	var angle := rad_to_deg(atan2(-dir.x, -dir.z)) + _bot_rng.randf_range(-4.0, 4.0)
	var power := clampf(dist * 0.5 + _bot_rng.randf_range(0.0, 1.0), 2.0, 13.0)
	putt_controller.ball = b
	putt_controller.debug_putt(power, angle)

func get_phase_name() -> String:
	return Phase.keys()[phase]
