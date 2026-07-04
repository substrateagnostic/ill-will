extends Node3D

const BALL_SCENE := preload("res://scenes/ball.tscn")
const TEE_XS := [-0.9, -0.3, 0.3, 0.9]
const TEE_Z := 0.0

var balls: Array = []
var round_manager: RoundManager
var _between_rounds := false

@onready var putt_controller: Node3D = $PuttController
@onready var camera_rig: Node3D = $CameraRig
@onready var course: Node3D = $Course
@onready var turn_label: Label = $UI/TurnLabel
@onready var stroke_label: Label = $UI/StrokeLabel
@onready var round_label: Label = $UI/RoundLabel
@onready var banner: Label = $UI/Banner
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows

func _ready() -> void:
	round_manager = RoundManager.new()
	round_manager.name = "RoundManager"
	add_child(round_manager)
	round_manager.turn_started.connect(_on_turn_started)
	round_manager.round_finished.connect(_on_round_finished)
	round_manager.ball_resolved.connect(_on_ball_resolved)
	putt_controller.stroke_taken.connect(_on_stroke_taken)
	course.ball_entered_cup.connect(_on_cup_entry)
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
		balls.append(b)
	course.balls = balls

func _tee_pos(i: int) -> Vector3:
	var n: int = GameState.players.size()
	var offset: float = TEE_XS[i] if n == 4 else (TEE_XS[i + (4 - n) / 2])
	return Vector3(offset, 0.15, TEE_Z)

func _start_round() -> void:
	_between_rounds = false
	banner.visible = false
	round_label.text = "ROUND %d / %d" % [GameState.round_num, GameState.rounds_total]
	for i in balls.size():
		balls[i].reset_for_round(_tee_pos(i))
	round_manager.start_round(GameState.standings(), balls)

func _process(_delta: float) -> void:
	putt_controller.enabled = not _between_rounds and round_manager.is_turn_ready()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		GameState.reset_match()
		get_tree().reload_current_scene()

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
	stroke_label.text = "STROKE %d / %d" % [round_manager.strokes[p] + 1, RoundManager.STROKE_CAP]

func _on_any_ball_sunk(p: int) -> void:
	_flash_banner("%s SINKS IT!" % GameState.players[p].name, GameState.players[p].color, 1.4)

func _on_ball_resolved(p: int, status: String) -> void:
	if status == "dnf":
		_flash_banner("%s IS OUT OF STROKES" % GameState.players[p].name, Color(0.7, 0.7, 0.7), 1.4)

func _on_round_finished(finish_order: Array, _strokes: Dictionary) -> void:
	_between_rounds = true
	GameState.award_round_points(finish_order)
	_rebuild_scoreboard()
	GameState.round_num += 1
	if GameState.is_match_over():
		var champ: int = GameState.standings()[0]
		_flash_banner("%s WINS THE MATCH!" % GameState.players[champ].name, GameState.players[champ].color, 9999.0)
		return
	_flash_banner("ROUND OVER", Color(1, 0.85, 0.2), 2.6)
	await get_tree().create_timer(3.0).timeout
	_start_round()

func _flash_banner(text: String, color: Color, duration: float) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func(): banner.visible = false)

func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	for i in GameState.standings():
		var player = GameState.players[i]
		var row := Label.new()
		row.text = "%s  %d" % [player.name, player.score]
		row.add_theme_font_size_override("font_size", 26)
		row.add_theme_color_override("font_color", player.color)
		score_rows.add_child(row)

func is_turn_ready() -> bool:
	return round_manager.is_turn_ready() and not _between_rounds
