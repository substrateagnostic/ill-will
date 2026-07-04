extends Node3D

const GRAVESTONE_SCENE := preload("res://scenes/gravestone.tscn")

var player_count := 4
var _t := 0.0

@onready var cam: Camera3D = $Camera3D
@onready var buttons := [$UI/Center/Box/Players/P2, $UI/Center/Box/Players/P3, $UI/Center/Box/Players/P4]

func _ready() -> void:
	player_count = GameState.player_count
	var args := OS.get_cmdline_user_args()
	if "--estate" in args:
		_start_estate()
		return
	for arg in args:
		if arg == "--skipmenu":
			_start()
			return
	_dress_set()
	$UI/Center/Box/StartBtn.pressed.connect(_start)
	$UI/Center/Box/EstateBtn.pressed.connect(_start_estate)
	for i in buttons.size():
		buttons[i].pressed.connect(_set_players.bind(i + 2))
	_set_players(player_count)

func _dress_set() -> void:
	var spots := [
		[Vector3(-1.4, 0, -8.2), GameState.PLAYER_COLORS[0], 3],
		[Vector3(0.6, 0, -4.4), GameState.PLAYER_COLORS[1], 6],
		[Vector3(-2.0, 0, -11.0), GameState.PLAYER_COLORS[3], 8],
	]
	for s in spots:
		var g := GRAVESTONE_SCENE.instantiate()
		$Deco.add_child(g)
		g.global_position = s[0]
		g.rotation_degrees.y = randf_range(-30, 30)
		g.setup(s[1], s[2])

func _process(delta: float) -> void:
	_t += delta * 0.07
	var center := Vector3(0, 0, -6.5)
	var radius := 12.5
	cam.global_position = center + Vector3(sin(_t) * radius, 8.5, cos(_t) * radius * 0.75)
	cam.look_at(center + Vector3(0, -0.5, 0), Vector3.UP)

func _set_players(n: int) -> void:
	player_count = n
	Sfx.play("card")
	for i in buttons.size():
		buttons[i].button_pressed = (i + 2) == n

func _start() -> void:
	Sfx.play("confirm")
	GameState.player_count = player_count
	GameState.reset_match()
	Transition.change_scene("res://scenes/main.tscn")

func _start_estate() -> void:
	Sfx.play("confirm")
	GameState.player_count = player_count
	GameState.reset_match()
	Transition.change_scene("res://estate/estate.tscn")
