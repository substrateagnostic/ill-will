extends Node3D

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
const TEE_XS := [-0.9, -0.3, 0.3, 0.9]
const TEE_Z := 0.0
const AUTOBUILD_SPOTS := [
	Vector3(1.4, 0, -4.0), Vector3(-1.5, 0, -8.5), Vector3(0.6, 0, -10.5),
	Vector3(-1.0, 0, -5.5), Vector3(1.8, 0, -11.5), Vector3(-1.8, 0, -3.0),
	Vector3(0.0, 0, -7.5), Vector3(2.0, 0, -6.0),
]

var balls: Array = []
var caddies: Array = []
var round_manager: RoundManager
var phase := Phase.BETWEEN
var draft_order: Array = []
var draft_pointer := 0
var current_hand: Array = []
var grudge_card_idx := -1
var autobuild_count := 0
var _build_timer := 0.0

@onready var putt_controller: Node3D = $PuttController
@onready var placement: Node3D = $PlacementController
@onready var camera_rig: Node3D = $CameraRig
@onready var course: Node3D = $Course
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
	round_manager = RoundManager.new()
	round_manager.name = "RoundManager"
	add_child(round_manager)
	round_manager.turn_started.connect(_on_turn_started)
	round_manager.round_finished.connect(_on_round_finished)
	round_manager.ball_resolved.connect(_on_ball_resolved)
	putt_controller.stroke_taken.connect(_on_stroke_taken)
	course.ball_entered_cup.connect(_on_cup_entry)
	placement.trap_container = course.get_node("TrapContainer")
	placement.trap_placed.connect(_on_trap_placed)
	_spawn_balls()
	banner.visible = false
	_rebuild_scoreboard()
	_start_round()

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
		c.global_position = Vector3(3.85 * side, -0.4, 0.2 + floorf(i / 2.0) * 1.5)
		c.rotation_degrees.y = 105.0 * side
		c.setup(CHAR_SCENES[i], GameState.players[i].color)
		caddies.append(c)
	course.balls = balls

func _tee_pos(i: int) -> Vector3:
	var n: int = GameState.players.size()
	var offset: float = TEE_XS[i] if n == 4 else (TEE_XS[i + (4 - n) / 2])
	return Vector3(offset, 0.15, TEE_Z)

func _start_round() -> void:
	banner.visible = false
	round_label.text = "ROUND %d / %d" % [GameState.round_num, GameState.rounds_total]
	for i in balls.size():
		balls[i].reset_for_round(_tee_pos(i))
		caddies[i].revive()
	var standings := GameState.standings()
	draft_order = standings.duplicate()
	draft_order.reverse()
	draft_pointer = 0
	_begin_draft_turn()

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
	var is_last_place: bool = p == GameState.standings().back() and GameState.round_num > 1
	if is_last_place:
		current_hand[0] = TrapCatalog.random_cursed(GameState.rng)
	if player.grudge > 0:
		grudge_card_idx = current_hand.size()
		current_hand.append(TrapCatalog.random_cursed(GameState.rng))
	draft_label.text = "%s — DRAFT YOUR TRAP%s" % [player.name, "  (CURSED LUCK: last place)" if is_last_place else ""]
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

func _on_trap_placed(_trap: Trap) -> void:
	build_hint.visible = false
	draft_pointer += 1
	_begin_draft_turn()

func _begin_putt_phase() -> void:
	phase = Phase.PUTT
	round_manager.start_round(GameState.standings(), balls)

func _process(delta: float) -> void:
	putt_controller.enabled = phase == Phase.PUTT and round_manager.is_turn_ready()
	if phase == Phase.BUILD:
		_build_timer += delta
		if _build_timer > BUILD_TIME_LIMIT:
			placement.cancel()
			build_hint.visible = false
			_flash_banner("TOO SLOW — TRAP FORFEITED", Color(0.8, 0.8, 0.8), 1.5)
			draft_pointer += 1
			_begin_draft_turn()

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
	var credit := "THE COURSE"
	var credit_color := Color(0.9, 0.9, 0.9)
	if killer != null and killer.author_index >= 0:
		var a = GameState.players[killer.author_index]
		credit = "%s'S %s" % [a.name, killer.display_name]
		credit_color = a.color
		if killer.author_index != victim:
			a.score += ROYALTY
			a.royalties += ROYALTY
			caddies[killer.author_index].react("Cheer")
			_rebuild_scoreboard()
	elif killer != null:
		credit = killer.display_name
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
	var gx := clampf(pos.x, -2.6, 2.6)
	var gz := clampf(pos.z, -14.6, 1.6)
	if gz > -2.0 and absf(gx) < 1.7:
		gz = -2.0
	g.global_position = Vector3(gx, 0, gz)
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
	var spot: Vector3 = AUTOBUILD_SPOTS[autobuild_count % AUTOBUILD_SPOTS.size()]
	autobuild_count += 1
	placement.debug_place(spot, float((autobuild_count * 45) % 180))

func get_phase_name() -> String:
	return Phase.keys()[phase]
