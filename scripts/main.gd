extends Node3D

var strokes := 0

@onready var ball: Ball = $Ball
@onready var putt_controller: Node3D = $PuttController
@onready var camera_rig: Node3D = $CameraRig
@onready var course: Node3D = $Course
@onready var stroke_label: Label = $UI/StrokeLabel
@onready var banner: Label = $UI/Banner

func _ready() -> void:
	putt_controller.ball = ball
	camera_rig.ball = ball
	course.balls = [ball]
	putt_controller.stroke_taken.connect(_on_stroke)
	ball.sunk.connect(_on_sunk)
	course.ball_entered_cup.connect(_on_ball_entered_cup)
	banner.visible = false
	_update_hud()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _on_ball_entered_cup(body: Node3D) -> void:
	if body == ball:
		ball.mark_sunk()

func _on_stroke() -> void:
	strokes += 1
	_update_hud()

func _on_sunk() -> void:
	banner.text = "SUNK IN %d!" % strokes
	banner.visible = true

func _update_hud() -> void:
	stroke_label.text = "STROKES: %d" % strokes
