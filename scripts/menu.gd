extends Control

var player_count := 4

@onready var buttons := [$Center/Box/Players/P2, $Center/Box/Players/P3, $Center/Box/Players/P4]

func _ready() -> void:
	player_count = GameState.player_count
	for arg in OS.get_cmdline_user_args():
		if arg == "--skipmenu":
			_start()
			return
	$Center/Box/StartBtn.pressed.connect(_start)
	for i in buttons.size():
		buttons[i].pressed.connect(_set_players.bind(i + 2))
	_set_players(player_count)

func _set_players(n: int) -> void:
	player_count = n
	Sfx.play("card")
	for i in buttons.size():
		buttons[i].button_pressed = (i + 2) == n

func _start() -> void:
	Sfx.play("confirm")
	GameState.player_count = player_count
	GameState.reset_match()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
