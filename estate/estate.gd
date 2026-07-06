extends Node3D
## THE ESTATE — night-loop shell: GROUNDS -> AUCTION -> GAME -> RECKONING.
## v1 "clipboard" grounds (panel UI); walkable grounds is phase E2.

enum Phase { LOBBY, SELECTOR, GROUNDS, TILES, AUCTION, CHOOSING, GAME, RECKONING, NIGHT_END, TITLE }

const TILE_COST := 2

const MODULES := {
	"par": {"name": "PAR FOR THE CURSE", "scene": "res://scenes/main.tscn", "mode": "gamestate"},
	"echo": {"name": "ECHO CHAMBER", "scene": "res://minigames/echo_chamber/echo_chamber.tscn", "mode": "contract"},
	"tilt": {"name": "TILT", "scene": "res://minigames/tilt/tilt.tscn", "mode": "contract"},
	"orbital": {"name": "ORBITAL DODGEBALL", "scene": "res://minigames/orbital/orbital.tscn", "mode": "contract"},
	"mower": {"name": "MOWER MAYHEM", "scene": "res://minigames/mower/mower.tscn", "mode": "contract"},
	"greed": {"name": "GREED INC.", "scene": "res://minigames/greed/greed.tscn", "mode": "contract"},
	"swap": {"name": "SWAP MEET", "scene": "res://minigames/swap_meet/swap_meet.tscn", "mode": "contract"},
	"deadweight": {"name": "DEAD WEIGHT", "scene": "res://minigames/dead_weight/dead_weight.tscn", "mode": "contract"},
	"throne": {"name": "THE THRONE", "scene": "res://minigames/throne/throne.tscn", "mode": "contract"},
	"lastwill": {"name": "LAST WILL", "scene": "res://minigames/last_will/last_will.tscn", "mode": "contract"},
	"seance": {"name": "THE SÉANCE", "scene": "res://minigames/seance/seance.tscn", "mode": "contract", "theater": true},
	"understudy": {"name": "THE UNDERSTUDY", "scene": "res://minigames/understudy/understudy.tscn", "mode": "contract", "theater": true},
	"mock": {"name": "EXHIBITION MATCH", "scene": "res://estate/mock_game.tscn", "mode": "contract"},
}
const CHAR_PATHS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const GROUNDS_TIME := 20.0
const BID_TIME := 8.0
## Pre-game GET READY card: launch when all humans ready or this many seconds
## elapse, whichever first. A soak (all bots) never sees it.
const READY_GATE_TIME := 15.0

var phase := Phase.GROUNDS
var bots := false
var mockonly := false
var pool_override: Array = []
var auction_options: Array = []
var high_bid := 0
var high_bidder := -1
var _bid_timer := 0.0
var _grounds_timer := GROUNDS_TIME
var _module: Node = null
var _bet_targets := {}
var _monuments_drawn := 0
var walkers: Array = []
var _saved_env: Environment = null
var _selected_walker := -1
var _bot_wander_timer := 0.0
var _tile_buyers: Array = []
var exhibition := false
var _practice := false

# ----- ONLINE PHASE 1 (doc 10): the estate IS the shared lobby -----
var _netprobe := ""               # "" | "host" | "join" | "couch" (NETPROBE rig)
var _np_last_trace := -2
var _net_game_name := ""          # what the spectate card names mid-game
var _net_state_accum := 0.0       # 5 Hz lobby-fact broadcast
var _net_walker_accum := 0.0      # 15 Hz walker snapshot broadcast
var _net_walker_seq := 0
var _client_last_state := {}      # client: last mirrored lobby facts
var _client_panel_sig := ""       # client: rebuild panel only when facts change
var _client_walker_targets := {}  # client: p -> {pos, rot, moving} interp targets

# ----- READY ROOM v2 (seat tri-state, join/ready, pre-game GET READY card) -----
var _lobby_ready := {}            # seat -> bool: lobby READY chip toggled on
var _lobby_ready_edge := {}       # seat -> physics frame of last READY toggle
var _kb_join_held := {}           # keyboard device (-1/-2) -> bool: A-key edge
var _join_ready_lock := {}        # seat -> bool: swallow the join press so it
                                  # does not also flip READY until A releases
var _ready_gate_active := false   # the pre-game GET READY card is up
var _ready_gate_id := ""
var _ready_gate_practice := false
var _ready_gate_countdown := 0.0
var _ready_gate_ready := {}       # seat -> bool: readied on the pre-game card
var _ready_gate_needed: Array = []  # human seats that must press A to launch

@onready var cam: Camera3D = $Camera3D
@onready var top_bar: HBoxContainer = $UI/TopBar/Row
@onready var phase_panel: PanelContainer = $UI/PhasePanel
@onready var phase_box: VBoxContainer = $UI/PhasePanel/Box
@onready var banner: Label = $UI/Banner
@onready var plinths: Node3D = $Plinths
@onready var wall_text: Label3D = $GraffitiWall/Lines

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var start_night_now := false
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--estatebots":
			bots = true
		elif arg == "--mockonly":
			mockonly = true
		elif arg == "--estate":
			start_night_now = true
		elif arg.begins_with("--pool="):
			pool_override = Array(arg.trim_prefix("--pool=").split(","))
		elif arg.begins_with("--netprobe="):
			_netprobe = arg.trim_prefix("--netprobe=")
		elif arg.begins_with("--exhibtest="):
			var gid := arg.trim_prefix("--exhibtest=")
			get_tree().create_timer(1.2).timeout.connect(func():
				exhibition = true
				_launch_game(gid))
		elif arg == "--lobbyshot":
			get_tree().create_timer(1.2).timeout.connect(func():
				_enter_lobby()
				get_tree().create_timer(0.4).timeout.connect(func():
					VerifyCapture.snap("lobbyrows")))
		elif arg == "--slotshot":
			get_tree().create_timer(1.2).timeout.connect(func():
				_build_slot_panel()
				get_tree().create_timer(0.4).timeout.connect(func():
					VerifyCapture.snap("slots")))
		elif arg == "--strolltest":
			get_tree().create_timer(1.5).timeout.connect(func():
				_enter_lobby()
				_enter_stroll()
				if not walkers.is_empty():
					walkers[0].global_position = Vector3(6.4, 0.1, -4.2)
				get_tree().create_timer(1.0).timeout.connect(func():
					VerifyCapture.snap("stroll_prompt")
					get_tree().create_timer(0.6).timeout.connect(func():
						_exit_stroll("selector")
						get_tree().create_timer(0.5).timeout.connect(func():
							VerifyCapture.snap("stroll_selector")))))
		elif arg == "--howtotest":
			get_tree().create_timer(1.2).timeout.connect(func():
				_hide_title()
				_show_howto("orbital")
				VerifyCapture.snap("howto"))
		elif arg == "--wardrobetest":
			# Self-contained: backs up and restores the REAL saves it mutates
			# (buying writes estate_save.json; equipping writes cosmetics.json).
			get_tree().create_timer(1.2).timeout.connect(func():
				var est := ProjectSettings.globalize_path(EstateState.slot_path(EstateState.current_slot))
				var cos := ProjectSettings.globalize_path("user://cosmetics.json")
				if FileAccess.file_exists(est):
					DirAccess.copy_absolute(est, est + ".wt_bak")
				if FileAccess.file_exists(cos):
					DirAccess.copy_absolute(cos, cos + ".wt_bak")
				_enter_lobby()
				EstateState.legacy[0] = 50
				_build_wardrobe_panel()
				_wardrobe_tap("viking_helm")
				print("WARDROBETEST legacy=%d owned=%s worn=%s" % [EstateState.legacy_of(0), str(EstateState.owned_cosmetics(0)), str(Cosmetics.get_player_cosmetics(0))])
				VerifyCapture.snap("wardrobe")
				get_tree().create_timer(1.0).timeout.connect(func():
					for pair in [[est + ".wt_bak", est], [cos + ".wt_bak", cos]]:
						if FileAccess.file_exists(pair[0]):
							DirAccess.copy_absolute(pair[0], pair[1])
							DirAccess.remove_absolute(pair[0])
					print("WARDROBETEST saves restored")))
		elif arg == "--readytest":
			# Windowed GET READY card proof. Self-contained: backs up/restores
			# party_setup.json (the ready/join flows persist seat choices).
			get_tree().create_timer(1.2).timeout.connect(func():
				var ps := ProjectSettings.globalize_path("user://party_setup.json")
				if FileAccess.file_exists(ps):
					DirAccess.copy_absolute(ps, ps + ".rrbak")
				_hide_title()
				PlayerInput.assign(0, -1)
				PlayerInput.set_bot(0, false)
				PlayerInput.assign(1, -2)
				PlayerInput.set_bot(1, false)
				PlayerInput.set_bot(2, true)
				PlayerInput.set_bot(3, true)
				_show_get_ready("orbital")
				_ready_gate_ready[1] = true
				var gr := phase_box.get_node_or_null("GateRow1")
				if gr:
					var chip := gr.get_node_or_null("GateChip")
					if chip:
						chip.text = "READY"
						chip.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
						chip.modulate.a = 1.0
				_refresh_ready_gate_countdown()
				_ready_gate_active = false
				VerifyCapture.snap("readyroom_getready")
				get_tree().create_timer(1.0).timeout.connect(func():
					if FileAccess.file_exists(ps + ".rrbak"):
						DirAccess.copy_absolute(ps + ".rrbak", ps)
						DirAccess.remove_absolute(ps + ".rrbak")
					print("READYTEST saves restored")
					get_tree().quit()))
		elif arg == "--readylobbytest":
			# Windowed lobby proof: an EMPTY chair (dim) + a READY chip + a
			# waiting START button. Self-contained backup/restore of the seats.
			get_tree().create_timer(1.2).timeout.connect(func():
				var ps := ProjectSettings.globalize_path("user://party_setup.json")
				if FileAccess.file_exists(ps):
					DirAccess.copy_absolute(ps, ps + ".rrbak")
				_enter_lobby()
				PlayerInput.assign(0, -1)
				PlayerInput.set_bot(0, false)
				PlayerInput.set_bot(1, false)
				PlayerInput.assign(1, -99)
				PlayerInput.assign(2, -2)
				PlayerInput.set_bot(2, false)
				PlayerInput.set_bot(3, true)
				_lobby_ready[0] = true
				_build_lobby_panel()
				VerifyCapture.snap("readyroom_lobby")
				get_tree().create_timer(1.0).timeout.connect(func():
					if FileAccess.file_exists(ps + ".rrbak"):
						DirAccess.copy_absolute(ps + ".rrbak", ps)
						DirAccess.remove_absolute(ps + ".rrbak")
					print("READYLOBBYTEST saves restored")
					get_tree().quit()))
	if "--skipmenu" in args:
		Transition.change_scene("res://scenes/main.tscn")
		return
	GameState.player_count = 4
	GameState.reset_match()
	EstateState.ensure_players(4)
	PlayerInput.auto_assign(4)
	_spawn_walkers()
	_spawn_toys()
	_spawn_executor()
	$Trail.build(EstateState.players, EstateState.gate_statues)
	$Trail.seat_all(EstateState.trail_pos)
	_redraw_monuments()
	_redraw_graffiti()
	banner.visible = false
	_saved_env = $WorldEnvironment.environment
	_net_wire_signals()
	if start_night_now:
		_play_pressed()
	else:
		_enter_title()
	if _netprobe != "":
		_netprobe_run()
	elif NetSession.is_host():
		# --net=host CLI boot: straight to the open lobby with the invite code.
		_hide_title()
		_enter_lobby()

## ----- TITLE SCREEN (front door; PLAY -> straight into the night) -----

var _title_layer: Control = null

## PLAY = the full game, immediately. Resumes an in-progress run at its
## between-nights rest; otherwise begins a fresh run at night one.
func _play_pressed() -> void:
	Sfx.play("confirm")
	_hide_title()
	_fill_empty_seats_with_bots()
	PlayerInput.save_setup()
	GameState.reset_match()
	if not EstateState.night_length_forced:
		EstateState.night_length = clampi(int(PartySetup.pref("night_length", 3)), 1, 9)
	var resuming: bool = EstateState.run_active and EstateState.at_boundary
	EstateState.start_night(4)
	$Trail.seat_all(EstateState.trail_pos)
	$UI/TopBar.visible = true
	_rebuild_top_bar()
	if resuming:
		print("RUN resumed at boundary (night %d next)" % (EstateState.run_night + 1))
		_enter_grounds()
		return
	if EstateState.nights_played > 0:
		_flash("NIGHT %d — THE ESTATE REMEMBERS" % (EstateState.nights_played + 1), Color(1, 0.85, 0.2), 2.2)
	_enter_auction()

## NEW GAME / slot management: each slot is a whole estate universe.
func _build_slot_panel() -> void:
	phase = Phase.LOBBY
	_hide_title()
	Sfx.play("card")
	_clear_panel("THE THREE ESTATES — pick where tonight happens", Color(0.9, 0.95, 0.9))
	for n in [1, 2, 3]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		var summary := EstateState.slot_summary(n)
		var lab := Label.new()
		lab.text = "SLOT %d — %s" % [n, summary if summary != "" else "an empty deed"]
		lab.custom_minimum_size = Vector2(360, 0)
		lab.add_theme_font_size_override("font_size", 18)
		if n == EstateState.current_slot:
			lab.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		row.add_child(lab)
		var load_btn := Button.new()
		load_btn.custom_minimum_size = Vector2(170, 46)
		load_btn.text = "PLAY THIS ESTATE"
		load_btn.pressed.connect(func():
			Sfx.play("confirm")
			EstateState.load_slot(n)
			get_tree().reload_current_scene())
		row.add_child(load_btn)
		var wipe_btn := Button.new()
		wipe_btn.custom_minimum_size = Vector2(190, 46)
		wipe_btn.text = "START FRESH" if summary == "" else "WIPE & START FRESH"
		wipe_btn.pressed.connect(func():
			if summary != "" and not wipe_btn.text.begins_with("REALLY"):
				wipe_btn.text = "REALLY? CLICK AGAIN"
				Sfx.play("invalid")
				return
			Sfx.play("grudge")
			EstateState.new_game(n)
			get_tree().reload_current_scene())
		row.add_child(wipe_btn)
		phase_box.add_child(row)
	var hint := Label.new()
	hint.text = "Wiping a slot erases that estate's monuments, ledger, and wardrobe. The Executor will pretend not to notice."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.65
	phase_box.add_child(hint)
	var back := Button.new()
	back.text = "BACK TO TITLE"
	back.pressed.connect(_enter_title)
	phase_box.add_child(back)

func _enter_title() -> void:
	phase = Phase.TITLE
	Music.play_slot("lobby")
	$UI/TopBar.visible = false
	phase_panel.visible = false
	banner.visible = false
	if _title_layer != null:
		_title_layer.visible = true
		return
	_title_layer = Control.new()
	_title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(_title_layer)
	if ResourceLoader.exists("res://assets/ui/title_bg.png"):
		var bg := TextureRect.new()
		bg.texture = load("res://assets/ui/title_bg.png")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_title_layer.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.08, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_layer.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_title_layer.add_child(box)
	var logo := Label.new()
	logo.text = "ILL WILL"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists("res://assets/fonts/LuckiestGuy-Regular.ttf"):
		logo.add_theme_font_override("font", load("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	logo.add_theme_font_size_override("font_size", 120)
	logo.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	logo.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
	logo.add_theme_constant_override("outline_size", 22)
	box.add_child(logo)
	var sub := Label.new()
	sub.text = "a party nobody asked for"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate.a = 0.85
	box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(360, 92)
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(_play_pressed)
	var pc := CenterContainer.new()
	pc.add_child(play)
	box.add_child(pc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var newg := Button.new()
	newg.text = "NEW GAME"
	newg.custom_minimum_size = Vector2(160, 56)
	newg.pressed.connect(_build_slot_panel)
	row.add_child(newg)
	var settings := Button.new()
	settings.text = "SETTINGS"
	settings.custom_minimum_size = Vector2(160, 56)
	settings.pressed.connect(func():
		Sfx.play("card")
		PartySetup.toggle())
	row.add_child(settings)
	var mini := Button.new()
	mini.text = "MINIGAMES"
	mini.custom_minimum_size = Vector2(170, 56)
	mini.pressed.connect(func():
		Sfx.play("card")
		_enter_selector())
	row.add_child(mini)
	var ward := Button.new()
	ward.text = "WARDROBE"
	ward.custom_minimum_size = Vector2(160, 56)
	ward.pressed.connect(func():
		Sfx.play("card")
		phase = Phase.LOBBY
		_hide_title()
		_build_wardrobe_panel())
	row.add_child(ward)
	box.add_child(row)
	var net_row := HBoxContainer.new()
	net_row.alignment = BoxContainer.ALIGNMENT_CENTER
	net_row.add_theme_constant_override("separation", 14)
	var host_btn := Button.new()
	host_btn.text = "HOST NIGHT"
	host_btn.custom_minimum_size = Vector2(200, 50)
	host_btn.pressed.connect(_host_night_pressed)
	net_row.add_child(host_btn)
	var join_btn := Button.new()
	join_btn.text = "JOIN NIGHT"
	join_btn.custom_minimum_size = Vector2(200, 50)
	join_btn.pressed.connect(_build_join_panel)
	net_row.add_child(join_btn)
	box.add_child(net_row)
	var hint := Label.new()
	hint.text = "PLAY = the full game — nights of minigames until someone takes the manor"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.6
	box.add_child(hint)

func _hide_title() -> void:
	if _title_layer != null:
		_title_layer.visible = false

## ----- LOBBY (PLAY setup: seats, night length, wardrobe) -----

func _enter_lobby() -> void:
	phase = Phase.LOBBY
	_hide_title()
	Music.play_slot("lobby")
	$UI/TopBar.visible = false
	_lobby_ready.clear()
	_join_ready_lock.clear()
	_flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0)
	_build_lobby_panel()

func _build_lobby_panel() -> void:
	_clear_panel("who's on the couch?", Color(0.9, 0.95, 0.9))
	for i in 4:
		var status := _seat_status(i)
		var row := HBoxContainer.new()
		row.name = "SeatRow%d" % i
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		if status == "EMPTY":
			row.modulate.a = 0.5
		row.add_child(PlayerBadge.make(i, 20))
		var name_l := Label.new()
		name_l.text = GameState.PLAYER_NAMES[i]
		name_l.custom_minimum_size = Vector2(80, 0)
		name_l.add_theme_font_size_override("font_size", 24)
		name_l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(name_l)
		# Tri-state: HUMAN -> BOT -> EMPTY -> HUMAN. EMPTY becomes a bot at
		# night start; a device joining (press A) claims a BOT/EMPTY seat.
		var status_btn := Button.new()
		status_btn.custom_minimum_size = Vector2(120, 44)
		status_btn.text = status
		status_btn.disabled = status == "REMOTE"
		status_btn.pressed.connect(func():
			_cycle_seat_status(i)
			Sfx.play("card")
			_build_lobby_panel())
		row.add_child(status_btn)
		var dev_btn := Button.new()
		dev_btn.custom_minimum_size = Vector2(210, 44)
		if status == "REMOTE":
			dev_btn.text = "REMOTE LINK · %d ms" % NetSession.rtt_of_seat(i)
			dev_btn.disabled = true
		else:
			dev_btn.text = PartySetup.DEVICE_NAMES.get(PlayerInput.device_of(i), "UNASSIGNED")
			dev_btn.pressed.connect(func():
				var cur := PartySetup.DEVICE_CYCLE.find(PlayerInput.device_of(i))
				var nxt: int = PartySetup.DEVICE_CYCLE[(cur + 1) % PartySetup.DEVICE_CYCLE.size()]
				PlayerInput.assign(i, nxt)
				PlayerInput.set_bot(i, false)
				Sfx.play("card")
				_build_lobby_panel())
		row.add_child(dev_btn)
		var chip := _make_ready_chip()
		chip.name = "ReadyChip"
		chip.visible = (status == "HUMAN" or status == "REMOTE") and _lobby_ready.get(i, false)
		row.add_child(chip)
		phase_box.add_child(row)
	if NetSession.is_host():
		var online := Label.new()
		var code := NetSession.invite_code()
		online.text = "OPEN NIGHT — CODE %s  ·  %s  ·  %d guest(s) at the gate" % [
			code if code != "" else "(share the address)", NetSession.listen_addr(), NetSession.guest_count()]
		online.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		online.add_theme_font_size_override("font_size", 17)
		online.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		phase_box.add_child(online)
	# Two button rows — six buttons in one row overflowed the panel.
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	var len_btn := Button.new()
	len_btn.custom_minimum_size = Vector2(170, 56)
	len_btn.text = "NIGHT: %d GAMES" % EstateState.night_length
	len_btn.pressed.connect(func():
		var opts := [3, 5, 7]
		EstateState.night_length = opts[(opts.find(EstateState.night_length) + 1) % opts.size()]
		len_btn.text = "NIGHT: %d GAMES" % EstateState.night_length
		Sfx.play("card"))
	btn_row.add_child(len_btn)
	var start_btn := Button.new()
	start_btn.name = "StartBtn"
	start_btn.custom_minimum_size = Vector2(300, 56)
	start_btn.text = _start_btn_text()
	start_btn.pressed.connect(_start_night_from_lobby)
	btn_row.add_child(start_btn)
	phase_box.add_child(btn_row)
	var btn_row2 := HBoxContainer.new()
	btn_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row2.add_theme_constant_override("separation", 14)
	var sel_btn := Button.new()
	sel_btn.custom_minimum_size = Vector2(190, 48)
	var n_games := 0
	for mid in MODULES:
		if mid != "mock" and ResourceLoader.exists(String(MODULES[mid].scene)):
			n_games += 1
	sel_btn.text = "MINIGAMES (%d)" % n_games
	sel_btn.pressed.connect(_enter_selector)
	btn_row2.add_child(sel_btn)
	var ward_btn := Button.new()
	ward_btn.custom_minimum_size = Vector2(160, 48)
	ward_btn.text = "WARDROBE"
	ward_btn.pressed.connect(_build_wardrobe_panel)
	btn_row2.add_child(ward_btn)
	var stroll_btn := Button.new()
	stroll_btn.custom_minimum_size = Vector2(200, 48)
	stroll_btn.text = "WALK THE GROUNDS"
	stroll_btn.pressed.connect(_enter_stroll)
	btn_row2.add_child(stroll_btn)
	var title_btn := Button.new()
	title_btn.custom_minimum_size = Vector2(110, 48)
	title_btn.text = "◄ TITLE"
	title_btn.pressed.connect(_enter_title)
	btn_row2.add_child(title_btn)
	phase_box.add_child(btn_row2)
	var quote := Label.new()
	quote.text = "“%s”  — The Executor" % _executor_greeting()
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(700, 0)
	quote.add_theme_font_size_override("font_size", 16)
	quote.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	quote.modulate.a = 0.85
	phase_box.add_child(quote)
	var hint := Label.new()
	hint.text = "PAD A or KEYBOARD Space/Enter takes an open seat  ·  A again = READY  ·  KB+MOUSE joins by button (its A is the mouse)  ·  ESC = players & controls"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(760, 0)
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate.a = 0.7
	phase_box.add_child(hint)

func _start_night_from_lobby() -> void:
	_fill_empty_seats_with_bots()
	PlayerInput.save_setup()
	GameState.reset_match()
	EstateState.start_night(4)
	$Trail.reset_pawns()
	banner.visible = false
	$UI/TopBar.visible = true
	Sfx.play("confirm")
	if EstateState.nights_played > 0:
		_flash("NIGHT %d — THE ESTATE REMEMBERS" % (EstateState.nights_played + 1), Color(1, 0.85, 0.2), 2.5)
	_enter_grounds()

## ----- READY ROOM SEATS: tri-state, join, ready chips -----

## HUMAN (device + not bot) / BOT / EMPTY (unassigned + not bot) /
## REMOTE (a networked guest drives this seat through the PlayerInput relay).
func _seat_status(i: int) -> String:
	if NetSession.is_seat_remote(i):
		return "REMOTE"
	if PlayerInput.is_bot(i):
		return "BOT"
	if PlayerInput.device_of(i) == -99:
		return "EMPTY"
	return "HUMAN"

## The seat button cycle: HUMAN -> BOT -> EMPTY -> HUMAN. Leaving HUMAN drops
## the READY chip; EMPTY frees the device so a joiner can take it.
func _cycle_seat_status(i: int) -> void:
	if _seat_status(i) == "REMOTE":
		return  # a guest's presence is not the host's to cycle
	match _seat_status(i):
		"HUMAN":
			PlayerInput.set_bot(i, true)
			_lobby_ready.erase(i)
			_join_ready_lock.erase(i)
		"BOT":
			PlayerInput.set_bot(i, false)
			PlayerInput.assign(i, -99)
		_:  # EMPTY -> HUMAN
			PlayerInput.set_bot(i, false)
			if PlayerInput.device_of(i) == -99:
				PlayerInput.assign(i, _first_free_device())

## First device in the PartySetup cycle not already held by another seat,
## falling back to MOUSE/SHARED (-3) if the couch is somehow full.
func _first_free_device() -> int:
	var taken: Array = []
	for i in 4:
		taken.append(PlayerInput.device_of(i))
	for d in PartySetup.DEVICE_CYCLE:
		if not taken.has(d):
			return int(d)
	return -3

## EMPTY seats (unassigned, not bot) become bots when the night begins — a
## soak never stalls on an unmanned chair.
func _fill_empty_seats_with_bots() -> void:
	for i in 4:
		if _seat_status(i) == "EMPTY":
			PlayerInput.set_bot(i, true)

## READY status chip: green token that sits at the end of a seat row. Plain
## Label to match the estate's other rows (no stylebox surgery).
func _make_ready_chip() -> Label:
	var chip := Label.new()
	chip.text = "READY"
	chip.add_theme_font_size_override("font_size", 20)
	chip.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
	chip.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.08))
	chip.add_theme_constant_override("outline_size", 6)
	return chip

## Seats still expected to press A before the night can begin (unready humans).
func _waiting_seats() -> Array:
	var out: Array = []
	for i in 4:
		var st := _seat_status(i)
		if (st == "HUMAN" or st == "REMOTE") and not _lobby_ready.get(i, false):
			out.append(i)
	return out

func _start_btn_text() -> String:
	var waiting := _waiting_seats()
	if waiting.is_empty():
		return "START THE NIGHT"
	var names: Array = []
	for i in waiting:
		names.append(GameState.PLAYER_NAMES[i])
	return "START THE NIGHT  (waiting: %s)" % ", ".join(names)

## Unseated keyboard half (Space = -1, Enter = -2) joins the first open seat,
## mirroring press-A pad join. Default keys only (a fresh device has no remap
## yet); KB+MOUSE stays button-driven since its A is the left mouse button.
func _poll_kb_join() -> void:
	var seated: Array = []
	for i in 4:
		seated.append(PlayerInput.device_of(i))
	for pair in [[-1, KEY_SPACE], [-2, KEY_ENTER]]:
		var dev: int = pair[0]
		var keycode: int = pair[1]
		var down := Input.is_physical_key_pressed(keycode)
		if not down:
			_kb_join_held.erase(dev)
			continue
		if _kb_join_held.get(dev, false) or seated.has(dev):
			continue
		_kb_join_held[dev] = true
		_claim_seat_for_device(dev)

## Claim the first BOT/EMPTY seat as a HUMAN on `dev`. Shared by pad + keyboard
## join. Returns the seat index, or -1 if the couch is full of humans.
func _claim_seat_for_device(dev: int) -> int:
	for i in 4:
		if _seat_status(i) == "BOT" or _seat_status(i) == "EMPTY":
			PlayerInput.assign(i, dev)
			PlayerInput.set_bot(i, false)
			_lobby_ready.erase(i)
			_join_ready_lock[i] = true
			PlayerInput.save_setup()
			Sfx.play("confirm")
			var glyph: String = PartySetup.DEVICE_NAMES.get(dev, "A DEVICE")
			_flash("%s JOINS THE PARTY (%s)" % [GameState.PLAYER_NAMES[i], glyph], GameState.PLAYER_COLORS[i], 2.2)
			get_tree().create_timer(2.3).timeout.connect(func():
				if phase == Phase.LOBBY:
					_flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0))
			if phase == Phase.LOBBY:
				_build_lobby_panel()
			return i
	return -1

## Seated humans toggle their READY chip with A. Pads and keyboard halves only
## (KB+MOUSE / SHARED A collides with clicking the lobby's own buttons).
func _poll_lobby_ready() -> void:
	for i in 4:
		var st := _seat_status(i)
		if st != "HUMAN" and st != "REMOTE":
			continue
		if st != "REMOTE":  # remote seats always have a discrete relayed A
			var d := PlayerInput.device_of(i)
			if d != -1 and d != -2 and d < 0:
				continue  # skip -3 (shared) and -4 (KB+mouse)
		# A freshly joined seat swallows its still-held join press; only once A
		# is released does the same button start toggling READY.
		if _join_ready_lock.get(i, false):
			if not PlayerInput.is_down(i, "a"):
				_join_ready_lock.erase(i)
			continue
		if PlayerInput.just_pressed(i, "a"):
			# just_pressed holds for a whole physics tick; when render fps
			# outruns physics, two _process frames can see the same edge and
			# double-toggle. Consume each edge once, keyed by physics frame.
			var pf := Engine.get_physics_frames()
			if _lobby_ready_edge.get(i, -1) == int(pf):
				continue
			_lobby_ready_edge[i] = int(pf)
			_lobby_ready[i] = not _lobby_ready.get(i, false)
			if _netprobe != "":
				print("NETPROBE toggle seat=%d ready=%s pf=%d" % [i, str(_lobby_ready[i]), pf])
			Sfx.play("card")
			var row := phase_box.get_node_or_null("SeatRow%d" % i)
			if row:
				var chip := row.get_node_or_null("ReadyChip")
				if chip:
					chip.visible = _lobby_ready[i]

## Keep the START button label's waiting list current as seats ready up.
## find_child, not get_node: StartBtn sits nested inside a button row.
func _update_lobby_start_btn() -> void:
	var btn := phase_box.find_child("StartBtn", true, false)
	if btn and btn is Button:
		btn.text = _start_btn_text()

## ----- MINIGAME SELECTOR (flat grid per UFO 50 pattern) -----

func _enter_selector() -> void:
	phase = Phase.SELECTOR
	_hide_title()
	Music.play_slot("lobby")
	Sfx.play("card")
	_clear_panel("PICK A GAME — exhibition match, no stakes", Color(0.9, 0.95, 0.9))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in MODULES:
		var info: Dictionary = MODULES[id]
		# Theater specials appear the moment their scene lands on disk.
		if id == "mock" or not ResourceLoader.exists(String(info.scene)):
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(158, 84)
		b.text = String(info.name) + ("\n· at the theater ·" if info.get("theater", false) else "")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_show_howto.bind(String(id)))
		grid.add_child(b)
	var center := CenterContainer.new()
	center.add_child(grid)
	phase_box.add_child(center)
	var back := Button.new()
	back.text = "BACK TO TITLE"
	back.pressed.connect(_enter_title)
	phase_box.add_child(back)

## How-to-Play cards (UFO 50 pattern): goal + LIVE controls per seat via
## PlayerInput.describe_binding — the card can't lie about bindings.
const HOWTO := {
	"par": {"goal": "Sabotage golf. Draft a trap, place it on the SHARED hole, then putt it yourself. Your trap's kills pay YOU royalties. Last round is CHAOS: everyone putts at once.", "a": "", "b": ""},
	"echo": {"goal": "Duel beside your own GHOST — it replays your previous round. Shatter the others before the past catches up.", "a": "STRIKE", "b": "DASH (hold: PARRY)"},
	"tilt": {"goal": "The floor is one platter and everyone's weight tilts it. Fall off and you return as a vengeful seagull.", "a": "SHOVE (answer to CLASH)", "b": "BRACE"},
	"orbital": {"goal": "Dodgeball on a tiny planet. Throws ORBIT forever — a 45-second-old ball still kills, and its thrower still gets paid.", "a": "hold: AIM+THROW / tap: CATCH", "b": "JUMP the gap"},
	"mower": {"goal": "Mow more lawn than anyone. Coverage is score; ramming is diplomacy.", "a": "RAM HORN", "b": "BOOST (wider cut)"},
	"greed": {"goal": "One pot of gold, four sets of hands. Bank it down your chute; tackle whoever is richer.", "a": "GRAB / TACKLE", "b": "DASH"},
	"swap": {"goal": "Kart race where your weapon TRADES PLACES with whoever it hits. The lead is a rumor.", "a": "THROW SWAP ORB", "b": "hold: DRIFT, release: BOOST"},
	"deadweight": {"goal": "Sumo where the dead never leave — they possess the furniture and fling it at the living.", "a": "SHOVE", "b": "HOP"},
	"throne": {"goal": "One throne, four claimants. Reigning scores. Decrees blast, guards defend, gravity votes last.", "a": "SHOVE / DECREE", "b": "DASH / GUARD"},
	"lastwill": {"goal": "A funeral procession race: first to the crypt inherits. Every death freezes the world while the deceased writes a curse into the road.", "a": "SHOVE", "b": "HOP"},
	"seance": {"goal": "A co-op séance: guide the planchette to the spirit's word — but one of you was paid in grudge to make it fail without getting caught. The Executor is the medium.", "a": "CHANT ON THE PULSE", "b": "SURGE (anonymous)"},
	"understudy": {"goal": "Everyone knows tonight's play but the understudy, who must bluff along. Rehearse, interrogate, vote — the scoring never stalemates.", "a": "COMMIT (move = choose)", "b": "—"},
}

func _show_howto(id: String) -> void:
	Sfx.play("card")
	var info: Dictionary = MODULES[id]
	_clear_panel(String(info.name), Color(1, 0.9, 0.5))
	var how: Dictionary = HOWTO.get(id, {"goal": "?", "a": "A", "b": "B"})
	var goal := Label.new()
	goal.text = String(how.goal)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(680, 0)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_box.add_child(goal)
	var ctl_title := Label.new()
	ctl_title.text = "— CONTROLS TONIGHT (live from your settings) —"
	ctl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl_title.modulate.a = 0.7
	ctl_title.add_theme_font_size_override("font_size", 15)
	phase_box.add_child(ctl_title)
	for i in 4:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(PlayerBadge.make(i, 16))
		var l := Label.new()
		if PlayerInput.is_bot(i):
			l.text = "%s — bot, needs no manual" % GameState.PLAYER_NAMES[i]
			l.modulate.a = 0.5
		elif NetSession.is_seat_remote(i):
			l.text = "%s — REMOTE — plays from their own machine" % GameState.PLAYER_NAMES[i]
		elif id == "par":
			l.text = "%s — MOUSE: aim, hold, release to putt (hotseat — pass it on)" % GameState.PLAYER_NAMES[i]
		else:
			l.text = "%s — MOVE %s  ·  %s: %s  ·  %s: %s" % [
				GameState.PLAYER_NAMES[i], PlayerInput.describe_binding(i, "move"),
				PlayerInput.describe_binding(i, "a"), String(how.a),
				PlayerInput.describe_binding(i, "b"), String(how.b)]
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(l)
		phase_box.add_child(row)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	var play := Button.new()
	play.custom_minimum_size = Vector2(220, 54)
	play.text = "PLAY — EXHIBITION"
	play.pressed.connect(func():
		exhibition = true
		_launch_game(id))
	btns.add_child(play)
	if id != "par":
		var prac := Button.new()
		prac.custom_minimum_size = Vector2(200, 54)
		prac.text = "PRACTICE (no stakes)"
		prac.pressed.connect(func():
			exhibition = true
			_launch_game(id, true))
		btns.add_child(prac)
	var back := Button.new()
	back.custom_minimum_size = Vector2(120, 54)
	back.text = "BACK"
	back.pressed.connect(_enter_selector)
	btns.add_child(back)
	phase_box.add_child(btns)

func get_phase_name() -> String:
	return Phase.keys()[phase]

func _is_bot(p: int) -> bool:
	return bots or PlayerInput.is_bot(p)

func _all_bots() -> bool:
	if bots:
		return true
	for i in EstateState.players.size():
		if not PlayerInput.is_bot(i):
			return false
	return true

const CHAR_SCENES := [
	preload("res://assets/models/kaykit/Barbarian.glb"),
	preload("res://assets/models/kaykit/Knight.glb"),
	preload("res://assets/models/kaykit/Mage.glb"),
	preload("res://assets/models/kaykit/Rogue.glb"),
]

func _spawn_walkers() -> void:
	for i in EstateState.players.size():
		var w := EstateWalker.new()
		$Grounds/Walkers.add_child(w)
		w.global_position = Vector3(-1.5 + i * 1.0, 0.1, 1.0)
		w.setup(CHAR_SCENES[i], EstateState.players[i].color, i)
		Cosmetics.apply_to_character(w, i)
		walkers.append(w)

## ----- THE EXECUTOR (host; voice register: Saki — dry, immaculate, lethal) -----

const EXECUTOR_GLB := "res://assets/models/meshy/executor_butler.glb"
const THEATER_GLB := "res://assets/models/meshy/theater_stage.glb"

## Everything spawned here parents under $Grounds — the module-launch
## cleanup hides Grounds, so props must live there or they leak into
## minigame frames (Alex caught the Theater photobombing a game).
func _spawn_executor() -> void:
	if ResourceLoader.exists(THEATER_GLB):
		var th := MeshyProp.instance(THEATER_GLB, 3.2, 205.0)
		$Grounds.add_child(th)
		th.global_position = Vector3(6.4, 0.0, -5.6)
		var ttag := Label3D.new()
		ttag.text = "THE THEATER"
		ttag.font_size = 44
		ttag.pixel_size = 0.006
		ttag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ttag.modulate = Color(1.0, 0.75, 0.75)
		ttag.outline_size = 12
		$Grounds.add_child(ttag)
		ttag.global_position = th.global_position + Vector3(0, 3.6, 0)
	if not ResourceLoader.exists(EXECUTOR_GLB):
		return
	var ex := MeshyProp.instance(EXECUTOR_GLB, 1.9, 25.0)
	$Grounds.add_child(ex)
	ex.global_position = Vector3(2.6, 0.0, -3.4)
	var tag := Label3D.new()
	tag.text = "THE EXECUTOR"
	tag.font_size = 40
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.85, 0.8, 0.95)
	tag.outline_size = 10
	$Grounds.add_child(tag)
	tag.global_position = ex.global_position + Vector3(0, 2.15, 0)

## One Saki-voiced line for the lobby, drawn from the ledger's memory.
func _executor_greeting() -> String:
	if EstateState.ledger.is_empty():
		return "The Executor is pleased to receive you. The estate had been expecting someone; it was not, in candour, you."
	var last: Dictionary = EstateState.ledger.back()
	var aw: Array = last.get("awards", [])
	if aw.is_empty():
		return "Welcome back. The estate kept the lights on and the grudges filed."
	var a: Dictionary = aw[EstateState.rng.randi_range(0, aw.size() - 1)]
	var who := str(a.get("who", "someone"))
	var title := str(a.get("title", "themselves"))
	# One rare line honors the estate's first outside guest (2026-07-05),
	# whose field report on the seagull is archived in docs/playtests/.
	if EstateState.rng.randf() < 0.07:
		return "The first guest left a note about the seagull. The estate declines to repeat it, but agrees it was beautiful."
	var lines := [
		"Welcome back. We remembered %s as %s, and see no reason to revise.",
		"The ledger has %s down as %s. The ledger is seldom wrong twice.",
		"%s returns. Last night they were %s. The estate expects consistency.",
		"Do come in. %s will find their reputation as %s exactly where they left it.",
	]
	return String(lines[EstateState.rng.randi_range(0, lines.size() - 1)]) % [who, title]

## ----- THE WARDROBE (cosmetics store; LEGACY buys vanity) -----

const WARDROBE_PRICES := {
	"propeller_beanie": 10, "party_cone": 12, "chef_hat": 14,
	"flower_crown": 15, "jester_cap": 18, "viking_helm": 20,
	"tophat_monocle": 25, "halo": 30,
}
const WARDROBE_TAGLINES := {
	"propeller_beanie": "dignity optional", "party_cone": "mandatory fun",
	"chef_hat": "you cooked", "flower_crown": "gentle menace",
	"jester_cap": "you will be mocked", "viking_helm": "heritage item",
	"tophat_monocle": "old money", "halo": "earned innocence",
}
var _wardrobe_player := 0

func _build_wardrobe_panel() -> void:
	_clear_panel("THE WARDROBE — legacy buys vanity", Color(0.95, 0.85, 1.0))
	var seat_row := HBoxContainer.new()
	seat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seat_row.add_theme_constant_override("separation", 10)
	for i in EstateState.players.size():
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(150, 44)
		pb.text = "%s  %d LEGACY" % [GameState.PLAYER_NAMES[i], EstateState.legacy_of(i)]
		pb.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		pb.disabled = i == _wardrobe_player
		pb.pressed.connect(func():
			_wardrobe_player = i
			Sfx.play("card")
			_build_wardrobe_panel())
		seat_row.add_child(pb)
	phase_box.add_child(seat_row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var worn: Dictionary = Cosmetics.get_player_cosmetics(_wardrobe_player)
	for id in WARDROBE_PRICES:
		var owned: bool = id in EstateState.owned_cosmetics(_wardrobe_player)
		var wearing: bool = id in worn.values()
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 74)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var nice: String = str(id).replace("_", " ").to_upper()
		if wearing:
			b.text = "%s\nWEARING — tap to doff" % nice
		elif owned:
			b.text = "%s\nOWNED — tap to wear" % nice
		else:
			b.text = "%s\n%d LEGACY — %s" % [nice, WARDROBE_PRICES[id], WARDROBE_TAGLINES[id]]
			b.disabled = EstateState.legacy_of(_wardrobe_player) < WARDROBE_PRICES[id]
		b.pressed.connect(_wardrobe_tap.bind(String(id)))
		grid.add_child(b)
	var center := CenterContainer.new()
	center.add_child(grid)
	phase_box.add_child(center)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func():
		Sfx.play("card")
		if phase == Phase.GROUNDS:
			_build_freeroam_panel()
		else:
			_enter_title())
	phase_box.add_child(back)
	var hint := Label.new()
	hint.text = "LEGACY = the estate's memory of your points, paid at each dawn. It buys nothing but respect."
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.65
	phase_box.add_child(hint)

func _wardrobe_tap(id: String) -> void:
	var p := _wardrobe_player
	var worn: Dictionary = Cosmetics.get_player_cosmetics(p)
	if id in EstateState.owned_cosmetics(p):
		if id in worn.values():
			var slot: String = Cosmetics.REGISTRY[id].get("slot", "head")
			Cosmetics.remove_player_cosmetic(p, slot)
			Sfx.play("card")
		else:
			Cosmetics.set_player_cosmetic(p, id)
			Sfx.play("confirm")
	elif EstateState.buy_cosmetic(p, id, WARDROBE_PRICES[id]):
		Cosmetics.set_player_cosmetic(p, id)
		Sfx.play("grudge", -4.0)
		_flash("%s BUYS %s" % [EstateState.players[p].name, id.replace("_", " ").to_upper()], EstateState.players[p].color, 2.0)
	else:
		Sfx.play("invalid")
		return
	_refresh_walker_cosmetics(p)
	_build_wardrobe_panel()

func _refresh_walker_cosmetics(p: int) -> void:
	if p >= walkers.size() or not is_instance_valid(walkers[p]):
		return
	for slot in Cosmetics.SLOT_ATTACHMENTS:
		Cosmetics.unequip(walkers[p], slot)
	Cosmetics.apply_to_character(walkers[p], p)

func _spawn_toys() -> void:
	var colors := [Color(0.95, 0.5, 0.2), Color(0.4, 0.75, 0.95), Color(0.85, 0.85, 0.3)]
	for i in 3:
		var b := RigidBody3D.new()
		b.mass = 0.5
		var shape := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.3
		shape.shape = s
		b.add_child(shape)
		var m := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.3
		mesh.height = 0.6
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		m.material_override = mat
		b.add_child(m)
		b.linear_damp = 0.6
		b.angular_damp = 0.4
		$Grounds/Toys.add_child(b)
		b.global_position = Vector3(-2.0 + i * 2.0, 0.4, -1.5)

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.GAME or _module != null or _ready_gate_active or NetSession.is_client():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var origin := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 60.0, 3)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		if phase == Phase.TILES and not _tile_buyers.is_empty():
			_place_tile(_tile_buyers[0], hit.position)
		elif hit.collider is EstateWalker:
			_select_walker(hit.collider.player_idx)
		elif _selected_walker >= 0:
			walkers[_selected_walker].walk_target = hit.position

func _select_walker(idx: int) -> void:
	_selected_walker = idx
	for w in walkers:
		w.set_selected(w.player_idx == idx)
	Sfx.play("card", -8.0)

## ----- STROLL MODE (DRG dual pattern: every panel has a walk-up twin) -----

const STROLL_SPOTS := [
	{"name": "THE THEATER", "pos": Vector3(6.4, 0, -5.6), "r": 2.6, "act": "selector"},
	{"name": "THE WARDROBE", "pos": Vector3(-3.0, 0, -2.2), "r": 2.2, "act": "wardrobe"},
]
var _strolling := false

func _enter_stroll() -> void:
	_strolling = true
	Sfx.play("card")
	phase_panel.visible = false
	banner.add_theme_font_size_override("font_size", 26)
	_flash("walk to a landmark  ·  A enter  ·  B desk", Color(0.9, 0.95, 0.9), 9999.0)

func _exit_stroll(open_act := "") -> void:
	_strolling = false
	banner.remove_theme_font_size_override("font_size")
	banner.visible = false
	match open_act:
		"selector":
			_enter_selector()
		"wardrobe":
			_build_wardrobe_panel()
		_:
			if phase == Phase.GROUNDS:
				_build_freeroam_panel()
			else:
				_build_lobby_panel()

func _poll_stroll() -> void:
	var near_spot: Dictionary = {}
	var near_player := -1
	for i in EstateState.players.size():
		# Remote walkers stroll but never open the host's desks/panels — panel
		# authority stays with the machine that owns the screen (spec §5.3).
		if PlayerInput.is_bot(i) or NetSession.is_seat_remote(i) or i >= walkers.size() or not is_instance_valid(walkers[i]):
			continue
		for spot in STROLL_SPOTS:
			var d: float = walkers[i].global_position.distance_to(spot.pos)
			if d <= float(spot.r):
				near_spot = spot
				near_player = i
				break
		if near_player >= 0:
			break
	if near_player >= 0:
		banner.text = "%s — A: enter %s  ·  B: desk" % [GameState.PLAYER_NAMES[near_player], near_spot.name]
		if PlayerInput.just_pressed(near_player, "a"):
			Sfx.play("confirm")
			_exit_stroll(String(near_spot.act))
			return
	else:
		banner.text = "WALK THE GROUNDS — approach a landmark, A to enter, B back to the desk"
	for i in EstateState.players.size():
		if not PlayerInput.is_bot(i) and not NetSession.is_seat_remote(i) and PlayerInput.just_pressed(i, "b"):
			Sfx.play("card")
			_exit_stroll()
			return

var _join_held := {}

## Press-A-to-join (digest join flow): a gamepad nobody is seated on
## presses A in the LOBBY and claims the first BOT/EMPTY seat as HUMAN.
func _poll_pad_join() -> void:
	var seated: Array = []
	for i in 4:
		seated.append(PlayerInput.device_of(i))
	for pad in Input.get_connected_joypads():
		var down := Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
		if not down:
			_join_held.erase(pad)
			continue
		if _join_held.get(pad, false) or pad in seated:
			continue
		_join_held[pad] = true
		_claim_seat_for_device(pad)

## A seated pad vanishing during LOBBY/GROUNDS hands its seat to a bot (Executor
## register) and frees the pad, so reconnect + press-A can retake a seat. Mid-
## minigame disconnects belong to the module's own loop — see readyroom-VERIFY.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if phase == Phase.LOBBY:
			_flash("GAMEPAD %d RESTORED — PRESS A TO TAKE A SEAT" % (device + 1), Color(0.85, 0.9, 1.0), 2.4)
			get_tree().create_timer(2.5).timeout.connect(func():
				if phase == Phase.LOBBY:
					_flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0))
		return
	if phase != Phase.LOBBY and phase != Phase.GROUNDS:
		return
	for i in 4:
		if PlayerInput.device_of(i) == device and not PlayerInput.is_bot(i):
			PlayerInput.set_bot(i, true)
			PlayerInput.assign(i, -99)
			_lobby_ready.erase(i)
			_join_ready_lock.erase(i)
			Sfx.play("grudge", -4.0)
			_flash("GAMEPAD %d LOST — %s PLAYS ITSELF UNTIL FURTHER NOTICE" % [device + 1, GameState.PLAYER_NAMES[i]], GameState.PLAYER_COLORS[i], 2.6)
			if phase == Phase.LOBBY:
				get_tree().create_timer(2.7).timeout.connect(func():
					if phase == Phase.LOBBY:
						_flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0))
				_build_lobby_panel()

func _process(delta: float) -> void:
	if NetSession.is_client():
		_client_process(delta)
		return
	if NetSession.is_host():
		_net_host_broadcast(delta)
	if _ready_gate_active:
		_poll_ready_gate(delta)
	if phase == Phase.LOBBY or phase == Phase.GROUNDS:
		if _strolling:
			_poll_stroll()
		else:
			_poll_pad_join()
			_poll_kb_join()
			_poll_lobby_ready()
			_update_lobby_start_btn()
	# NETPROBE holds bot wander still: its rng draws are wall-clock-timed, which
	# would desync the seeded draw order between couch and relay proof runs.
	if _module == null and not walkers.is_empty() and _netprobe == "":
		_bot_wander_timer -= delta
		if _bot_wander_timer <= 0.0:
			_bot_wander_timer = 1.6
			var bot_walkers: Array = walkers.filter(func(w): return _is_bot(w.player_idx))
			if not bot_walkers.is_empty():
				var w: EstateWalker = bot_walkers[EstateState.rng.randi_range(0, bot_walkers.size() - 1)]
				w.walk_target = Vector3(EstateState.rng.randf_range(-6.0, 6.0), 0, EstateState.rng.randf_range(-7.0, 1.5))
	if phase == Phase.GROUNDS:
		# Free roam has no countdown for humans — the estate rests until
		# CONTINUE. Bot-only tables move on after a short breath.
		if _all_bots():
			_grounds_timer -= delta
			if _grounds_timer <= GROUNDS_TIME - 4.0:
				_bots_buy_tiles()
				_continue_to_night()
	elif phase == Phase.AUCTION:
		_bid_timer -= delta
		_update_auction_clock()
		if _bid_timer < BID_TIME - 1.0 and high_bidder < 0:
			_bots_bid()
		if _bid_timer <= 0.0:
			_resolve_auction()

func _rebuild_top_bar() -> void:
	for c in top_bar.get_children():
		c.queue_free()
	for i in EstateState.standings():
		var pl = EstateState.players[i]
		top_bar.add_child(PlayerBadge.make(i, 18))
		var l := Label.new()
		l.text = " %s %d  ♠%d   " % [pl.name, pl.points, pl.grudge]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", pl.color)
		top_bar.add_child(l)
	var info := Label.new()
	info.text = "|  GAME %d/%d   POT %d♠" % [mini(EstateState.games_played + 1, EstateState.night_length), EstateState.night_length, EstateState.pot]
	info.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(info)

func _clear_panel(title: String, color := Color(1, 0.9, 0.5)) -> void:
	for c in phase_box.get_children():
		# Detach BEFORE queue_free: a dying child keeps its name until end of
		# frame, so a same-frame rebuild would get its named rows auto-renamed
		# (@SeatRow1@...) and every later get_node_or_null update would miss.
		phase_box.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_box.add_child(t)
	phase_panel.visible = true

## FREE ROAM — the estate rests between nights. The grounds are walkable
## (stroll on by default), trap tiles are bought here, and the night
## begins when someone presses CONTINUE. No countdown for humans.
func _enter_grounds() -> void:
	phase = Phase.GROUNDS
	Music.play_slot("grounds")
	_grounds_timer = GROUNDS_TIME
	_tile_buyers.clear()
	_rebuild_top_bar()
	if _all_bots():
		_build_freeroam_panel()
		return
	_enter_stroll()

func _build_freeroam_panel() -> void:
	_strolling = false
	banner.remove_theme_font_size_override("font_size")
	banner.visible = false
	_clear_panel("THE ESTATE RESTS — night %d awaits" % (EstateState.run_night + 1))
	var hint := Label.new()
	hint.text = "Walk the grounds (B closes this desk) · visit the wardrobe or theater · seed a trap tile · continue when ready"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(700, 0)
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate.a = 0.75
	phase_box.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i in EstateState.players.size():
		if _is_bot(i) or NetSession.is_seat_remote(i):
			continue
		var pl = EstateState.players[i]
		var tile_btn := Button.new()
		tile_btn.custom_minimum_size = Vector2(190, 48)
		tile_btn.text = "%s: TRAP TILE %d♠" % [pl.name, TILE_COST]
		tile_btn.add_theme_color_override("font_color", pl.color)
		tile_btn.pressed.connect(func():
			if not _tile_buyers.has(i) and EstateState.spend_grudge(i, TILE_COST):
				_tile_buyers.append(i)
				tile_btn.text = "%s: TILE BOUGHT" % pl.name
				tile_btn.disabled = true
				Sfx.play("grudge")
				_rebuild_top_bar()
			else:
				Sfx.play("invalid"))
		row.add_child(tile_btn)
	phase_box.add_child(row)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 14)
	var roam := Button.new()
	roam.custom_minimum_size = Vector2(220, 56)
	roam.text = "WALK THE GROUNDS"
	roam.pressed.connect(_enter_stroll)
	row2.add_child(roam)
	var cont := Button.new()
	cont.custom_minimum_size = Vector2(300, 56)
	cont.text = "CONTINUE — NIGHT %d" % (EstateState.run_night + 1)
	cont.pressed.connect(_continue_to_night)
	row2.add_child(cont)
	phase_box.add_child(row2)

## Leaves free roam for the night's first auction (placing bought tiles
## first if any).
func _continue_to_night() -> void:
	if phase != Phase.GROUNDS:
		return
	_strolling = false
	banner.remove_theme_font_size_override("font_size")
	banner.visible = false
	Sfx.play("confirm")
	if EstateState.nights_played > 0 and EstateState.games_played == 0:
		_flash("NIGHT %d — THE ESTATE REMEMBERS" % (EstateState.nights_played + 1), Color(1, 0.85, 0.2), 2.2)
	_enter_tiles()

func _bots_place_bets() -> void:
	for i in EstateState.players.size():
		if _is_bot(i):
			EstateState.place_bet(i, EstateState.rng.randi_range(0, EstateState.players.size() - 1))

func _bots_buy_tiles() -> void:
	for i in EstateState.players.size():
		if _is_bot(i) and EstateState.rng.randf() < 0.55 and not _tile_buyers.has(i):
			if EstateState.spend_grudge(i, TILE_COST):
				_tile_buyers.append(i)

func _enter_tiles() -> void:
	if _tile_buyers.is_empty():
		_enter_auction()
		return
	phase = Phase.TILES
	_rebuild_top_bar()
	_prompt_next_tile()

func _prompt_next_tile() -> void:
	if _tile_buyers.is_empty():
		_enter_auction()
		return
	var p: int = _tile_buyers[0]
	var pl = EstateState.players[p]
	_clear_panel("%s — CLICK THE LAWN TO SEED YOUR TRAP TILE" % pl.name, pl.color)
	if _is_bot(p):
		var spot := Vector3(EstateState.rng.randf_range(-5.0, 5.0), 0, EstateState.rng.randf_range(-6.0, 1.0))
		_place_tile(p, spot)

func _place_tile(p: int, pos: Vector3) -> void:
	if Vector2(pos.x, pos.z + 4.0).length() > 11.0:
		Sfx.play("invalid")
		return
	_tile_buyers.pop_front()
	var tile := TrapTile.new()
	$Grounds.add_child(tile)
	tile.global_position = Vector3(pos.x, 0.0, pos.z)
	tile.setup(p, EstateState.players[p].color)
	tile.tripped.connect(_on_tile_tripped)
	Sfx.play("place")
	_prompt_next_tile()

func _on_tile_tripped(victim: int, owner_idx: int) -> void:
	var taken := EstateState.steal_grudge(victim, owner_idx, 1)
	print("TILE_TRIP victim=%d owner=%d stole=%d" % [victim, owner_idx, taken])
	var v = EstateState.players[victim]
	var o = EstateState.players[owner_idx]
	var suffix := " and steals 1♠" if taken > 0 else ""
	_flash("%s'S TILE TRIPS %s%s" % [o.name, v.name, suffix], o.color, 2.0)
	EstateState.add_graffiti("%s tripped %s on the grounds" % [o.name, v.name])
	_redraw_graffiti()
	_rebuild_top_bar()

func _enter_auction() -> void:
	if phase == Phase.AUCTION:
		return
	phase = Phase.AUCTION
	Music.play_slot("auction")
	high_bid = 0
	high_bidder = -1
	_bid_timer = BID_TIME
	var pool := ["mock", "mock", "mock"] if mockonly else ["par", "echo", "tilt", "orbital", "mower", "greed", "swap", "deadweight", "throne", "lastwill"]
	if not mockonly and bool(PartySetup.pref("theater_in_pool", false)):
		for tid in ["seance", "understudy"]:
			if ResourceLoader.exists(String(MODULES[tid].scene)):
				pool.append(tid)
	if not pool_override.is_empty():
		pool = pool_override
	auction_options.clear()
	# Sample WITHOUT replacement — Andrew's auction offered LAST WILL twice.
	var bag := pool.duplicate()
	for k in 3:
		if bag.is_empty():
			bag = pool.duplicate()
		var pick := EstateState.rng.randi_range(0, bag.size() - 1)
		auction_options.append(bag[pick])
		bag.remove_at(pick)
	_bots_place_bets()
	_rebuild_top_bar()
	_clear_panel("THE AUCTION — bid grudge to choose the game")
	if EstateState.games_played == 0 and not EstateState.vendetta.is_empty():
		var v: Dictionary = EstateState.vendetta
		var vl := Label.new()
		vl.text = "“An unsettled matter: %s hunted %s last night. The estate has opened a book on the reprisal (+3♠).”  — The Executor" % [EstateState.players[int(v.hunter)].name, EstateState.players[int(v.prey)].name]
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.custom_minimum_size = Vector2(700, 0)
		vl.add_theme_font_size_override("font_size", 15)
		vl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.75))
		phase_box.add_child(vl)
	var exec_lines := [
		"The Executor opens the bidding. Spite is legal tender.",
		"The Executor reminds the room that generosity is not on the block.",
		"The Executor accepts grudge, resentment, and exact change.",
	]
	var eq := Label.new()
	eq.text = "“%s”" % String(exec_lines[EstateState.rng.randi_range(0, exec_lines.size() - 1)])
	eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eq.add_theme_font_size_override("font_size", 15)
	eq.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	eq.modulate.a = 0.8
	phase_box.add_child(eq)
	var opts := Label.new()
	var names: Array = []
	for id in auction_options:
		names.append(MODULES[id].name)
	opts.text = "on the block:  " + " / ".join(names)
	opts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_box.add_child(opts)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in EstateState.players.size():
		var pl = EstateState.players[i]
		var b := Button.new()
		b.text = "%s: RAISE TO %d♠" % [pl.name, high_bid + 1]
		# Remote seats bid via panel intents (phase 2) — the host's cursor
		# never spends another player's grudge.
		b.disabled = _is_bot(i) or NetSession.is_seat_remote(i)
		b.pressed.connect(_on_bid.bind(i))
		row.add_child(b)
	row.name = "BidRow"
	phase_box.add_child(row)
	# Side bets ride the auction now (free roam replaced the betting phase).
	var bet_row := HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 10)
	for i in EstateState.players.size():
		if _is_bot(i) or EstateState.bets.has(i) or NetSession.is_seat_remote(i):
			continue
		var pl = EstateState.players[i]
		_bet_targets[i] = (i + 1) % EstateState.players.size()
		var tb := Button.new()
		tb.custom_minimum_size = Vector2(120, 40)
		tb.text = "on %s" % EstateState.players[_bet_targets[i]].name
		tb.add_theme_font_size_override("font_size", 15)
		tb.pressed.connect(func():
			_bet_targets[i] = (_bet_targets[i] + 1) % EstateState.players.size()
			tb.text = "on %s" % EstateState.players[_bet_targets[i]].name)
		bet_row.add_child(tb)
		var bb := Button.new()
		bb.custom_minimum_size = Vector2(150, 40)
		bb.text = "%s BETS 1♠" % pl.name
		bb.add_theme_font_size_override("font_size", 15)
		bb.add_theme_color_override("font_color", pl.color)
		bb.pressed.connect(func():
			if EstateState.place_bet(i, _bet_targets[i]):
				bb.text = "BET PLACED"
				bb.disabled = true
				tb.disabled = true
				Sfx.play("card")
				_rebuild_top_bar())
		bet_row.add_child(bb)
	if bet_row.get_child_count() > 0:
		phase_box.add_child(bet_row)
	var clock := Label.new()
	clock.name = "Clock"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_box.add_child(clock)

func _on_bid(p: int) -> void:
	var pl = EstateState.players[p]
	if pl.grudge < high_bid + 1:
		Sfx.play("invalid")
		return
	high_bid += 1
	high_bidder = p
	_bid_timer = minf(_bid_timer + 3.0, BID_TIME)
	Sfx.play("card")
	var row := phase_box.get_node_or_null("BidRow")
	if row:
		for i in row.get_child_count():
			var b: Button = row.get_child(i)
			b.text = "%s: RAISE TO %d♠" % [EstateState.players[i].name, high_bid + 1]

func _update_auction_clock() -> void:
	var clock := phase_box.get_node_or_null("Clock")
	if clock:
		var lead := "no bids — cheapest seat chooses" if high_bidder < 0 else "%s leads at %d♠" % [EstateState.players[high_bidder].name, high_bid]
		clock.text = "%s   (%ds)" % [lead, ceili(_bid_timer)]

func _bots_bid() -> void:
	var candidates: Array = []
	for i in EstateState.players.size():
		if _is_bot(i) and EstateState.players[i].grudge > high_bid:
			candidates.append(i)
	if candidates.is_empty():
		return
	_on_bid(candidates[EstateState.rng.randi_range(0, candidates.size() - 1)])

func _resolve_auction() -> void:
	if phase != Phase.AUCTION:
		return
	phase = Phase.CHOOSING
	var chooser := high_bidder
	if chooser >= 0:
		EstateState.players[chooser].grudge = maxi(0, EstateState.players[chooser].grudge - high_bid)
		EstateState.pot += high_bid
		_rebuild_top_bar()
	else:
		chooser = EstateState.standings().back()
	if _is_bot(chooser):
		_launch_game(auction_options[EstateState.rng.randi_range(0, auction_options.size() - 1)])
		return
	_clear_panel("%s CHOOSES" % EstateState.players[chooser].name, EstateState.players[chooser].color)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in auction_options:
		var b := Button.new()
		b.text = MODULES[id].name
		b.custom_minimum_size = Vector2(220, 90)
		b.pressed.connect(_launch_game.bind(id))
		row.add_child(b)
	phase_box.add_child(row)

## ----- PRE-GAME GET READY CARD (night flow) -----

## The How-to card in a GET READY skin: goal + live per-seat controls, and each
## human presses their A to ready (chip flips green). Launches when every human
## is ready or after READY_GATE_TIME, whichever first. Feels like _show_howto.
func _show_get_ready(id: String, practice := false) -> void:
	_ready_gate_active = true
	_ready_gate_id = id
	_ready_gate_practice = practice
	_ready_gate_countdown = READY_GATE_TIME
	_ready_gate_ready.clear()
	_ready_gate_needed.clear()
	Sfx.play("card")
	var info: Dictionary = MODULES[id]
	var how: Dictionary = HOWTO.get(id, {"goal": "?", "a": "A", "b": "B"})
	_clear_panel("GET READY — %s" % String(info.name), Color(1, 0.9, 0.5))
	var goal := Label.new()
	goal.text = String(how.goal)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(680, 0)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_box.add_child(goal)
	var ctl_title := Label.new()
	ctl_title.text = "— CONTROLS TONIGHT (press your A to ready) —"
	ctl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl_title.modulate.a = 0.7
	ctl_title.add_theme_font_size_override("font_size", 15)
	phase_box.add_child(ctl_title)
	for i in EstateState.players.size():
		var row := HBoxContainer.new()
		row.name = "GateRow%d" % i
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(PlayerBadge.make(i, 16))
		var l := Label.new()
		if PlayerInput.is_bot(i):
			l.text = "%s — bot, needs no manual" % GameState.PLAYER_NAMES[i]
			l.modulate.a = 0.5
		elif NetSession.is_seat_remote(i):
			l.text = "%s — REMOTE — readies from their own estate" % GameState.PLAYER_NAMES[i]
		elif id == "par":
			l.text = "%s — MOUSE: aim, hold, release to putt (hotseat — pass it on)" % GameState.PLAYER_NAMES[i]
		else:
			l.text = "%s — MOVE %s  ·  %s: %s  ·  %s: %s" % [
				GameState.PLAYER_NAMES[i], PlayerInput.describe_binding(i, "move"),
				PlayerInput.describe_binding(i, "a"), String(how.a),
				PlayerInput.describe_binding(i, "b"), String(how.b)]
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(l)
		# A human with a discrete A must press it; a shared/mouse seat (-3) has
		# none, so it counts as ready on arrival and the countdown covers it.
		if not PlayerInput.is_bot(i):
			var d := PlayerInput.device_of(i)
			if d == -3:
				_ready_gate_ready[i] = true
			else:
				_ready_gate_ready[i] = false
				_ready_gate_needed.append(i)
				var chip := _make_ready_chip()
				chip.name = "GateChip"
				chip.text = "PRESS A"
				chip.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
				chip.modulate.a = 0.85
				row.add_child(chip)
		phase_box.add_child(row)
	var count := Label.new()
	count.name = "GateCountdown"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 18)
	count.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	phase_box.add_child(count)
	_refresh_ready_gate_countdown()

func _all_ready_gate() -> bool:
	for i in _ready_gate_needed:
		if not _ready_gate_ready.get(i, false):
			return false
	return true

func _refresh_ready_gate_countdown() -> void:
	var count := phase_box.get_node_or_null("GateCountdown")
	if count == null or not count is Label:
		return
	var waiting: Array = []
	for i in _ready_gate_needed:
		if not _ready_gate_ready.get(i, false):
			waiting.append(GameState.PLAYER_NAMES[i])
	if waiting.is_empty():
		count.text = "all ready — the estate begins"
	else:
		count.text = "waiting on %s  ·  begins in %ds" % [", ".join(waiting), ceili(maxf(_ready_gate_countdown, 0.0))]

func _poll_ready_gate(delta: float) -> void:
	_ready_gate_countdown -= delta
	for i in _ready_gate_needed:
		if not _ready_gate_ready.get(i, false) and PlayerInput.just_pressed(i, "a"):
			_ready_gate_ready[i] = true
			Sfx.play("confirm")
			var row := phase_box.get_node_or_null("GateRow%d" % i)
			if row:
				var chip := row.get_node_or_null("GateChip")
				if chip and chip is Label:
					chip.text = "READY"
					chip.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
					chip.modulate.a = 1.0
	_refresh_ready_gate_countdown()
	if _all_ready_gate() or _ready_gate_countdown <= 0.0:
		_ready_gate_active = false
		_do_launch_game(_ready_gate_id, _ready_gate_practice)

## Night-flow entry: the chosen game shows a GET READY card (goal + live
## controls + per-seat A-to-ready) before it launches. Exhibition/practice from
## the selector already showed the How-to card, so they skip straight to launch;
## an all-bot soak skips the card entirely so it never stalls.
func _launch_game(id: String, practice := false) -> void:
	if phase == Phase.GAME or _ready_gate_active:
		return
	if not exhibition and not _all_bots():
		_show_get_ready(id, practice)
		return
	_do_launch_game(id, practice)

func _do_launch_game(id: String, practice := false) -> void:
	if phase == Phase.GAME:
		return
	phase = Phase.GAME
	Music.stop()
	_hide_title()
	banner.visible = false
	_practice = practice
	phase_panel.visible = false
	Sfx.play("confirm")
	var info: Dictionary = MODULES[id]
	_net_game_name = String(info.name)
	var scene: PackedScene = load(info.scene)
	_module = scene.instantiate()
	$Grounds.visible = false
	$Grounds.process_mode = Node.PROCESS_MODE_DISABLED
	plinths.visible = false
	$GraffitiWall.visible = false
	$Trail.visible = false
	$Trail.process_mode = Node.PROCESS_MODE_DISABLED
	$Sun.visible = false
	$WorldEnvironment.environment = null
	$UI/TopBar.visible = false
	if info.mode == "gamestate":
		GameState.player_count = EstateState.players.size()
		GameState.reset_match()
		get_tree().root.add_child(_module)
		if _module.has_signal("finished"):
			_module.finished.connect(_on_module_finished, CONNECT_ONE_SHOT)
	else:
		add_child(_module)
		_module.finished.connect(_on_module_finished, CONNECT_ONE_SHOT)
		var roster: Array = []
		for pl in EstateState.players:
			roster.append({
				"index": pl.index, "name": pl.name, "color": pl.color,
				"char_scene": CHAR_PATHS[pl.index],
				"device": PlayerInput.device_of(pl.index),
				"bot": _is_bot(pl.index),
			})
		_module.begin({
			"roster": roster,
			"rounds": 2 if _practice else clampi(int(PartySetup.pref("mg_rounds", 4)), 2, 6),
			"rng_seed": EstateState.rng.randi(),
			"practice": _practice,
		})
	cam.current = false

func _on_module_finished(results: Dictionary) -> void:
	if _module:
		_module.queue_free()
		_module = null
	$Grounds.visible = true
	$Grounds.process_mode = Node.PROCESS_MODE_INHERIT
	plinths.visible = true
	$Trail.visible = true
	$Trail.process_mode = Node.PROCESS_MODE_INHERIT
	$Sun.visible = true
	$WorldEnvironment.environment = _saved_env
	$GraffitiWall.visible = true
	$UI/TopBar.visible = true
	cam.current = true
	var placements: Array = results.get("placements", [])
	if placements.size() >= 2:
		await _present_match_podium(placements)
	if exhibition:
		exhibition = false
		$UI/TopBar.visible = false
		var champ_line := "EXHIBITION OVER"
		if not placements.is_empty():
			var w = EstateState.players[placements[0]]
			champ_line = "EXHIBITION: %s TAKES IT" % w.name
		_flash(champ_line, Color(0.9, 0.95, 0.9), 3.0)
		_enter_selector()
		return
	var ticker := EstateState.apply_results(results)
	_redraw_monuments()
	_redraw_graffiti()
	_enter_reckoning(ticker)

## Every minigame ends on the podium (Alex's call): quick shared ceremony
## with characters, hats, and confetti before the estate takes over again.
func _present_match_podium(placements: Array) -> void:
	phase_panel.visible = false
	banner.visible = false
	var podium := Podium.new()
	add_child(podium)
	var entries: Array = []
	for rank in placements.size():
		var p: int = placements[rank]
		var pl = EstateState.players[p]
		entries.append({
			"name": pl.name, "color": pl.color, "rank": rank,
			"char_scene": CHAR_SCENES[p], "player": p,
		})
	podium.present(entries, 2.0 if _all_bots() else 4.2)
	await podium.done
	podium.queue_free()
	cam.current = true

func _enter_reckoning(ticker: Array) -> void:
	phase = Phase.RECKONING
	_rebuild_top_bar()
	_clear_panel("THE RECKONING")
	Sfx.play("round_over")
	if ticker.size() > 8:
		var extra := ticker.size() - 7
		ticker = ticker.slice(0, 7)
		ticker.append("...and %d more (carved into the graffiti wall)" % extra)
	for line in ticker:
		var l := Label.new()
		l.text = str(line)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		phase_box.add_child(l)
	var i := 0
	for c in phase_box.get_children():
		if c is Label and c.modulate.a == 0.0:
			var tw := create_tween()
			tw.tween_interval(0.35 * i)
			tw.tween_property(c, "modulate:a", 1.0, 0.3)
			i += 1
	await get_tree().create_timer(0.35 * ticker.size() + 0.5).timeout
	var btn := Button.new()
	btn.text = "TO THE AUCTION" if EstateState.games_played < EstateState.night_length else "THE NIGHT SETTLES"
	btn.pressed.connect(_after_reckoning)
	phase_box.add_child(btn)
	if _all_bots():
		get_tree().create_timer(2.0).timeout.connect(_after_reckoning)

## THE PARADE — once per night: every pawn advances by their NIGHT total,
## worst first, winner last. Handles tollgate claims/payments. Returns a
## summit player index (the manor is reached — the RUN ends) or -1.
func _run_parade() -> int:
	var deltas := {}
	for pl in EstateState.players:
		deltas[int(pl.index)] = int(pl.points)
	var order: Array = deltas.keys()
	order.sort_custom(func(a, b): return deltas[a] < deltas[b])
	var summit := -1
	for p in order:
		var delta: int = deltas[p]
		if delta <= 0:
			continue
		var from: int = EstateState.trail_pos[p]
		var to: int = mini(from + delta, Trail.STONES - 1)
		if to == from:
			continue
		var tw: Tween = $Trail.advance_pawn(p, from, to)
		await tw.finished
		EstateState.trail_pos[p] = to
		print("PARADE p=%d from=%d to=%d" % [p, from, to])
		for s in range(from + 1, to + 1):
			if s in Trail.TOLLGATES:
				if not EstateState.tollgates.has(s):
					EstateState.tollgates[s] = p
					_flash("%s CLAIMS THE TOLLGATE" % EstateState.players[p].name, EstateState.players[p].color, 1.6)
					EstateState.add_graffiti("%s claimed a tollgate" % EstateState.players[p].name)
				elif EstateState.tollgates[s] != p:
					var owner_idx: int = EstateState.tollgates[s]
					var taken := EstateState.steal_grudge(p, owner_idx, 1)
					if taken > 0:
						EstateState.record_toll(owner_idx, taken)
						_flash("%s PAYS %s'S TOLL (1♠)" % [EstateState.players[p].name, EstateState.players[owner_idx].name], EstateState.players[owner_idx].color, 1.6)
				await get_tree().create_timer(0.7).timeout
		if to >= Trail.STONES - 1:
			if summit < 0 or EstateState.players[p].points > EstateState.players[summit].points:
				summit = p
		_rebuild_top_bar()
	_redraw_graffiti()
	return summit

func _after_reckoning() -> void:
	if phase != Phase.RECKONING:
		return
	if EstateState.games_played >= EstateState.night_length:
		_night_ceremonies()
	else:
		_enter_auction()

## The night is settled: podium -> will reading -> parade -> free roam
## (or, if the parade reaches the manor, the RUN is over).
func _night_ceremonies() -> void:
	phase = Phase.NIGHT_END
	var champ = EstateState.end_night(EstateState.standings()[0])
	$Trail.add_statue(EstateState.gate_statues.back(), EstateState.gate_statues.size() - 1)
	_redraw_monuments()
	_rebuild_top_bar()
	phase_panel.visible = false
	var podium := Podium.new()
	add_child(podium)
	var entries: Array = []
	var order := EstateState.standings()
	for rank in order.size():
		var pl = EstateState.players[order[rank]]
		entries.append({
			"name": pl.name, "color": pl.color, "rank": rank,
			"char_scene": CHAR_SCENES[order[rank]],
			"player": order[rank],
		})
	podium.present(entries)
	_flash("%s WINS THE NIGHT\nthe estate will remember" % champ.name, champ.color, 9999.0)
	print("NIGHT_OVER winner=", champ.name, " monuments=", EstateState.monuments.size())
	await podium.done
	podium.queue_free()
	cam.current = true
	banner.visible = false
	_enter_will_reading(champ)

## After the podium: the night's superlatives, read aloud like an
## inheritance. Ends at the DAWN button, which returns to the lobby —
## the estate is the main menu, so every night must find its way home.
func _enter_will_reading(champ) -> void:
	Music.play_slot("ceremony")
	var awards: Array = EstateState.night_superlatives(champ.index)
	_clear_panel("THE READING OF THE WILL", Color(0.85, 0.75, 1.0))
	var head := Label.new()
	head.text = "The estate has reviewed the evening's conduct and finds it, on the whole, actionable.\n%s wins the night." % champ.name
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", champ.color)
	phase_box.add_child(head)
	for aw in awards:
		var pl = EstateState.players[aw.player]
		var l := Label.new()
		l.text = "%s, %s — %s" % [pl.name, aw.title, aw.line]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", pl.color)
		l.modulate.a = 0.0
		phase_box.add_child(l)
	if not EstateState.vendetta.is_empty() and EstateState.vendetta_settled_by < 0:
		var v: Dictionary = EstateState.vendetta
		var open_l := Label.new()
		open_l.text = "The matter of %s and %s remains open. The estate is patient." % [
			EstateState.players[int(v.hunter)].name, EstateState.players[int(v.prey)].name]
		open_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		open_l.add_theme_font_size_override("font_size", 15)
		open_l.modulate.a = 0.0
		open_l.self_modulate.a = 0.7
		phase_box.add_child(open_l)
	var i := 0
	for c in phase_box.get_children():
		if c is Label and c.modulate.a == 0.0:
			var tw := create_tween()
			tw.tween_interval(0.45 * i)
			tw.tween_property(c, "modulate:a", 1.0, 0.3)
			i += 1
	print("WILL_READ night=%d awards=%d vendetta_settled=%d" % [EstateState.nights_played, awards.size(), EstateState.vendetta_settled_by])
	await get_tree().create_timer(0.45 * i + 0.6).timeout
	VerifyCapture.snap("will_reading")
	if phase != Phase.NIGHT_END:
		return
	var btn := Button.new()
	btn.text = "TO THE PARADE"
	btn.pressed.connect(_night_parade)
	phase_box.add_child(btn)
	if _all_bots():
		get_tree().create_timer(2.5).timeout.connect(_night_parade)

var _parade_running := false

func _night_parade() -> void:
	if phase != Phase.NIGHT_END or _parade_running:
		return
	_parade_running = true
	phase_panel.visible = false
	Music.play_slot("grounds")
	var summit := await _run_parade()
	EstateState.save_estate()
	_parade_running = false
	if summit >= 0:
		_flash("%s REACHES THE MANOR" % EstateState.players[summit].name, EstateState.players[summit].color, 3.0)
		await get_tree().create_timer(2.2).timeout
		_run_over(summit)
		return
	_start_boundary()

## The rest between nights: arm the next night, then free roam.
func _start_boundary() -> void:
	GameState.reset_match()
	EstateState.start_night(4)
	_rebuild_top_bar()
	banner.visible = false
	print("DAWN free roam (night %d next)" % (EstateState.run_night + 1))
	_enter_grounds()

## Someone took the manor — the full game ends here.
func _run_over(p: int) -> void:
	phase = Phase.NIGHT_END
	var pl = EstateState.finish_run(p)
	_redraw_monuments()
	_redraw_graffiti()
	Music.play_slot("ceremony")
	var podium := Podium.new()
	add_child(podium)
	var order: Array = EstateState.trail_pos.keys()
	order.sort_custom(func(a, b): return EstateState.trail_pos[a] > EstateState.trail_pos[b])
	var entries: Array = []
	for rank in order.size():
		var q = EstateState.players[order[rank]]
		entries.append({"name": q.name, "color": q.color, "rank": rank,
			"char_scene": CHAR_SCENES[order[rank]], "player": order[rank]})
	podium.present(entries)
	_flash("%s TAKES THE MANOR\nthe estate has an heir" % pl.name, pl.color, 9999.0)
	await podium.done
	podium.queue_free()
	cam.current = true
	banner.visible = false
	_clear_panel("THE ESTATE HAS AN HEIR", Color(1, 0.85, 0.2))
	var l := Label.new()
	l.text = "%s took the manor after %d nights.\n“The keys, the grounds, the grudges — all of it passes to %s.\nThe estate offers its condolences to everyone else.”  — The Executor" % [pl.name, maxi(1, EstateState.run_night), pl.name]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	l.add_theme_color_override("font_color", pl.color)
	phase_box.add_child(l)
	var btn := Button.new()
	btn.text = "RETURN TO THE TITLE"
	btn.pressed.connect(func():
		GameState.reset_match()
		_enter_title())
	phase_box.add_child(btn)
	if _all_bots():
		get_tree().create_timer(4.0).timeout.connect(func():
			if phase == Phase.NIGHT_END:
				GameState.reset_match()
				_enter_title())

func _flash(text: String, color: Color, dur: float) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if dur < 100.0:
		var tw2 := create_tween()
		tw2.tween_interval(dur)
		tw2.tween_callback(func(): banner.visible = false)

func _redraw_monuments() -> void:
	for c in plinths.get_children():
		c.queue_free()
	# Show the 8 newest stones in 3 columns with staggered label heights;
	# older history stays in the save (and the ledger), not on the lawn.
	var all: Array = EstateState.monuments
	var shown: Array = all.slice(maxi(0, all.size() - 8))
	for m_idx in shown.size():
		var m: Dictionary = shown[m_idx]
		var col := Color.from_string(str(m.color), Color.WHITE)
		var obelisk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.45, 1.3, 0.45)
		obelisk.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		obelisk.material_override = mat
		obelisk.position = Vector3(-7.7 + (m_idx % 3) * 1.05, 0.65, 0.9 - floorf(m_idx / 3.0) * 1.6)
		plinths.add_child(obelisk)
		var tag := Label3D.new()
		tag.text = str(m.label)
		tag.font_size = 30
		tag.pixel_size = 0.0042
		tag.position = obelisk.position + Vector3(0, 0.82 + (m_idx % 3) * 0.3, 0.3)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 8
		plinths.add_child(tag)
	if all.size() > shown.size():
		var older := Label3D.new()
		older.text = "+%d older stones (the ledger keeps them)" % (all.size() - shown.size())
		older.font_size = 26
		older.pixel_size = 0.0042
		older.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		older.modulate = Color(0.8, 0.78, 0.75)
		older.outline_size = 8
		plinths.add_child(older)
		older.position = Vector3(-6.6, 2.4, -3.2)

func _redraw_graffiti() -> void:
	var lines: Array = EstateState.graffiti.slice(-10)
	wall_text.text = "\n".join(PackedStringArray(lines))

## ===== ONLINE PHASE 1 — the estate as the shared lobby (doc 10 §5) =====
## Host: remote peers claim seats; their walkers stroll these grounds on
## relayed input; READY and the GET READY gate poll PlayerInput as ever
## (relay-transparent). Client: renders a mirror of the lobby facts + walker
## snapshots; minigames stay host-screen-only this phase (spectate card).

func _net_wire_signals() -> void:
	NetSession.seat_requested.connect(_on_net_seat_requested)
	NetSession.peer_left_seat.connect(_on_net_peer_left_seat)
	NetSession.panel_intent_received.connect(_on_net_panel_intent)
	NetSession.seat_granted.connect(_on_net_seat_granted)
	NetSession.lobby_state_received.connect(_on_net_lobby_state)
	NetSession.walker_state_received.connect(_on_net_walker_state)
	NetSession.session_closed.connect(_on_net_session_closed)
	NetSession.probe_first_input.connect(_on_net_probe_first_input)

## ----- host side -----

func _host_night_pressed() -> void:
	if not NetSession.is_online():
		var err: int = NetSession.host_night()
		if err != OK:
			Sfx.play("invalid")
			_flash("THE ESTATE COULD NOT OPEN ITS DOORS (port %d is otherwise engaged)" % NetSession.DEFAULT_PORT, Color(0.9, 0.6, 0.6), 3.0)
			return
	Sfx.play("confirm")
	_enter_lobby()

## A guest knocked. Seat policy is the shell's: first BOT/EMPTY chair becomes
## theirs; a couch full of humans declines politely. Mid-game joins wait for
## the boundary (rejoin-at-boundary is phase 3).
func _on_net_seat_requested(peer_id: int) -> void:
	if phase != Phase.LOBBY and phase != Phase.GROUNDS and phase != Phase.TITLE:
		NetSession.grant_seat(peer_id, -1, "the estate is mid-game — knock again between games")
		return
	for i in 4:
		var st := _seat_status(i)
		if st == "BOT" or st == "EMPTY":
			PlayerInput.assign(i, -99)
			PlayerInput.set_bot(i, false)
			_lobby_ready.erase(i)
			_join_ready_lock.erase(i)
			NetSession.grant_seat(peer_id, i)
			Sfx.play("confirm")
			_flash("%s JOINS FROM AFAR" % GameState.PLAYER_NAMES[i], GameState.PLAYER_COLORS[i], 2.2)
			get_tree().create_timer(2.3).timeout.connect(func():
				if phase == Phase.LOBBY:
					_flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0))
			if phase == Phase.LOBBY:
				_build_lobby_panel()
			return
	NetSession.grant_seat(peer_id, -1, "the couch is full of humans")

## The wire dropped: the seat flips BOT on the existing Executor register.
## Mid-game the relay already feeds neutral input (the pawn idles); the bot
## flag takes over at the next boundary, exactly the couch unplug behavior.
func _on_net_peer_left_seat(seat: int, _peer_id: int) -> void:
	if seat < 0 or seat > 3:
		return
	PlayerInput.set_bot(seat, true)
	_lobby_ready.erase(seat)
	_join_ready_lock.erase(seat)
	Sfx.play("grudge", -4.0)
	_flash("THE WIRE TO %s WENT DEAD — %s PLAYS ITSELF UNTIL FURTHER NOTICE" % [GameState.PLAYER_NAMES[seat], GameState.PLAYER_NAMES[seat]], GameState.PLAYER_COLORS[seat], 2.6)
	if phase == Phase.LOBBY:
		get_tree().create_timer(2.7).timeout.connect(func():
			if phase == Phase.LOBBY:
				_flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0))
		_build_lobby_panel()

## Semantic UI intents from guests (spec §5.3): the client clicked a mirrored
## control, the host runs the seat-parameterized handler. Phase 1 ships the
## ready toggle; auction raises/bets/tiles ride the same pipe in phase 2.
func _on_net_panel_intent(seat: int, intent: Dictionary) -> void:
	match String(intent.get("kind", "")):
		"ready_toggle":
			if _ready_gate_active and seat in _ready_gate_needed:
				if not _ready_gate_ready.get(seat, false):
					_ready_gate_ready[seat] = true
					Sfx.play("confirm")
					_refresh_ready_gate_countdown()
			elif phase == Phase.LOBBY or phase == Phase.GROUNDS:
				_lobby_ready[seat] = not _lobby_ready.get(seat, false)
				Sfx.play("card")
				if phase == Phase.LOBBY:
					_build_lobby_panel()

## 5 Hz lobby facts (reliable) + 15 Hz walker snapshots (unreliable_ordered).
func _net_host_broadcast(delta: float) -> void:
	if not NetSession.has_guests():
		return
	_net_state_accum += delta
	if _net_state_accum >= 0.2:
		_net_state_accum = 0.0
		NetSession.send_lobby_state(_net_build_lobby_state())
	_net_walker_accum += delta
	if _net_walker_accum >= 1.0 / 15.0:
		_net_walker_accum = 0.0
		_net_walker_seq += 1
		var ws := _net_build_walker_state(_net_walker_seq)
		NetSession.send_walker_state(ws)
		if _netprobe != "" and _net_walker_seq % 15 == 0:
			print("NETHASH side=host seq=%d h=%s" % [_net_walker_seq, NetSession.snapshot_hash(ws)])

func _net_build_lobby_state() -> Dictionary:
	var seats: Array = []
	for i in 4:
		seats.append({
			"name": GameState.PLAYER_NAMES[i],
			"status": _seat_status(i),
			"ready": _lobby_ready.get(i, false),
			"ping": NetSession.rtt_of_seat(i),
		})
	var standings: Array = []
	for i in EstateState.standings():
		var pl = EstateState.players[i]
		standings.append({"name": pl.name, "points": pl.points, "grudge": pl.grudge})
	var state := {
		"phase": get_phase_name(),
		"night": EstateState.run_night + 1,
		"code": NetSession.invite_code(),
		"addr": NetSession.listen_addr(),
		"seats": seats,
		"standings": standings,
	}
	if _ready_gate_active:
		var waiting: Array = []
		for i in _ready_gate_needed:
			if not _ready_gate_ready.get(i, false):
				waiting.append(GameState.PLAYER_NAMES[i])
		state["gate"] = {
			"name": String(MODULES[_ready_gate_id].name),
			"goal": String(HOWTO.get(_ready_gate_id, {"goal": ""}).goal),
			"waiting": waiting,
			"countdown": ceili(maxf(_ready_gate_countdown, 0.0)),
		}
	if phase == Phase.GAME:
		state["game"] = _net_game_name
	return state

func _net_build_walker_state(seq: int) -> Dictionary:
	var w := {}
	for i in walkers.size():
		if not is_instance_valid(walkers[i]):
			continue
		var wk: EstateWalker = walkers[i]
		w[i] = [
			snappedf(wk.global_position.x, 0.001), snappedf(wk.global_position.y, 0.001),
			snappedf(wk.global_position.z, 0.001), snappedf(wk.rotation.y, 0.001),
			Vector2(wk.velocity.x, wk.velocity.z).length() > 0.5,
		]
	return {"seq": seq, "w": w}

## ----- client side (the estate-only mirror) -----

func _build_join_panel() -> void:
	phase = Phase.LOBBY
	_hide_title()
	Sfx.play("card")
	_clear_panel("JOIN A NIGHT — the host reads you their code", Color(0.9, 0.95, 0.9))
	var entry := LineEdit.new()
	entry.name = "JoinEntry"
	entry.placeholder_text = "6-char code or IP:PORT"
	entry.custom_minimum_size = Vector2(360, 50)
	entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ec := CenterContainer.new()
	ec.add_child(entry)
	phase_box.add_child(ec)
	var status := Label.new()
	status.name = "JoinStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 15)
	status.modulate.a = 0.8
	phase_box.add_child(status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var join := Button.new()
	join.text = "KNOCK"
	join.custom_minimum_size = Vector2(180, 52)
	join.pressed.connect(func():
		var err: int = NetSession.join_night(entry.text)
		if err != OK:
			Sfx.play("invalid")
			status.text = "that code does not parse — check it with the host"
		else:
			Sfx.play("card")
			status.text = "knocking at the estate gate...")
	row.add_child(join)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120, 52)
	back.pressed.connect(func():
		NetSession.leave()
		_enter_title())
	row.add_child(back)
	phase_box.add_child(row)
	var hint := Label.new()
	hint.text = "LAN or port-forwarded internet this phase — Steam invites arrive with phase 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.6
	phase_box.add_child(hint)

func _on_net_seat_granted(seat: int, reason: String) -> void:
	if seat < 0:
		_flash("THE ESTATE DECLINED: %s" % reason, Color(0.9, 0.6, 0.6), 3.2)
		var status := phase_box.get_node_or_null("JoinStatus")
		if status and status is Label:
			status.text = reason
		NetSession.leave()
		return
	# Local device feeds the relay through the SAME per-index API; a pad if
	# one is connected, else the WASD keyboard half. Tape mode samples nothing.
	if not NetSession.tape_mode():
		var pads := Input.get_connected_joypads()
		PlayerInput.assign(seat, pads[0] if pads.size() > 0 else -1)
		PlayerInput.set_bot(seat, false)
	_enter_client_lobby()

func _enter_client_lobby() -> void:
	phase = Phase.LOBBY
	_hide_title()
	Music.play_slot("lobby")
	$UI/TopBar.visible = false
	# Walkers become mirror puppets: the host owns every transform.
	for w in walkers:
		if is_instance_valid(w):
			w.set_physics_process(false)
	_flash("SEAT CLAIMED — YOUR WALKER IS ON THE HOST'S GROUNDS", Color(0.35, 0.9, 0.5), 3.0)
	_client_panel_sig = ""
	_client_build_panel()

func _on_net_lobby_state(state: Dictionary) -> void:
	_client_last_state = state
	var sig := JSON.stringify(state)
	if sig != _client_panel_sig:
		_client_panel_sig = sig
		_client_build_panel()

func _on_net_walker_state(state: Dictionary) -> void:
	var w: Dictionary = state.get("w", {})
	for k in w:
		var arr: Array = w[k]
		if arr.size() < 5:
			continue
		_client_walker_targets[int(str(k))] = {
			"pos": Vector3(float(arr[0]), float(arr[1]), float(arr[2])),
			"rot": float(arr[3]), "moving": bool(arr[4]),
		}
	if _netprobe != "" and int(state.get("seq", 0)) % 15 == 0:
		print("NETHASH side=client seq=%d h=%s" % [int(state.get("seq", 0)), NetSession.snapshot_hash(state)])

func _client_process(delta: float) -> void:
	for p in _client_walker_targets:
		if p >= walkers.size() or not is_instance_valid(walkers[p]):
			continue
		var t: Dictionary = _client_walker_targets[p]
		var w: EstateWalker = walkers[p]
		w.global_position = w.global_position.lerp(t.pos, 1.0 - exp(-12.0 * delta))
		w.rotation.y = lerp_angle(w.rotation.y, float(t.rot), 1.0 - exp(-10.0 * delta))
		if w.anim:
			var want: String = "Walking_A" if bool(t.moving) else "Idle"
			if w.anim.current_animation != want and w.anim.has_animation(want):
				w.anim.play(want)

## The client lobby: rebuilt from mirrored facts, never from local state.
func _client_build_panel() -> void:
	var state := _client_last_state
	var phase_name := String(state.get("phase", "LOBBY"))
	if phase_name == "GAME":
		_client_build_spectate_panel(state)
		return
	_clear_panel("AN ONLINE NIGHT — hosted across the wire", Color(0.9, 0.95, 0.9))
	var seats: Array = state.get("seats", [])
	if seats.is_empty():
		var wait := Label.new()
		wait.text = "waiting for the estate to describe itself..."
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait.modulate.a = 0.7
		phase_box.add_child(wait)
		return
	for i in seats.size():
		var s: Dictionary = seats[i]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		if String(s.get("status", "")) == "EMPTY":
			row.modulate.a = 0.5
		row.add_child(PlayerBadge.make(i, 20))
		var name_l := Label.new()
		name_l.text = String(s.get("name", "?")) + ("  (you)" if i == NetSession.my_seat() else "")
		name_l.custom_minimum_size = Vector2(170, 0)
		name_l.add_theme_font_size_override("font_size", 22)
		name_l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(name_l)
		var st_l := Label.new()
		st_l.text = String(s.get("status", "?"))
		st_l.custom_minimum_size = Vector2(110, 0)
		st_l.add_theme_font_size_override("font_size", 18)
		st_l.modulate.a = 0.85
		row.add_child(st_l)
		if bool(s.get("ready", false)):
			row.add_child(_make_ready_chip())
		phase_box.add_child(row)
	if phase_name == "RECKONING":
		var r_t := Label.new()
		r_t.text = "— THE RECKONING SETTLES ON THE HOST'S SCREEN —"
		r_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_t.add_theme_font_size_override("font_size", 16)
		r_t.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		phase_box.add_child(r_t)
		for s in state.get("standings", []):
			var rl := Label.new()
			rl.text = "%s  %d pts  ♠%d" % [String(s.get("name", "?")), int(s.get("points", 0)), int(s.get("grudge", 0))]
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			phase_box.add_child(rl)
	var gate: Dictionary = state.get("gate", {})
	if not gate.is_empty():
		var g_t := Label.new()
		g_t.text = "GET READY — %s" % String(gate.get("name", "?"))
		g_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g_t.add_theme_font_size_override("font_size", 22)
		g_t.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		phase_box.add_child(g_t)
		var g_goal := Label.new()
		g_goal.text = String(gate.get("goal", ""))
		g_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g_goal.custom_minimum_size = Vector2(640, 0)
		g_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phase_box.add_child(g_goal)
		var g_w := Label.new()
		var waiting: Array = gate.get("waiting", [])
		g_w.text = "all ready — curtain up" if waiting.is_empty() else "waiting on %s  ·  begins in %ds" % [", ".join(PackedStringArray(waiting)), int(gate.get("countdown", 0))]
		g_w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g_w.add_theme_font_size_override("font_size", 16)
		g_w.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
		phase_box.add_child(g_w)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	var ready_btn := Button.new()
	ready_btn.text = "READY"
	ready_btn.custom_minimum_size = Vector2(200, 52)
	ready_btn.pressed.connect(func():
		Sfx.play("card")
		NetSession.send_panel_intent({"kind": "ready_toggle"}))
	btn_row.add_child(ready_btn)
	var leave_btn := Button.new()
	leave_btn.text = "LEAVE THE NIGHT"
	leave_btn.custom_minimum_size = Vector2(200, 52)
	leave_btn.pressed.connect(func():
		NetSession.leave())
	btn_row.add_child(leave_btn)
	phase_box.add_child(btn_row)
	var hint := Label.new()
	hint.text = "MOVE strolls your walker on the host's grounds  ·  your A (or READY) toggles ready  ·  the host holds the keys to the night"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(700, 0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.7
	phase_box.add_child(hint)

## Phase-1 posture (spec §8): games not yet mirrored render host-side only;
## the client keeps its seat, its input still relays, and this card says so.
func _client_build_spectate_panel(state: Dictionary) -> void:
	_clear_panel("NIGHT %d — %s" % [int(state.get("night", 1)), String(state.get("game", "A GAME"))], Color(1, 0.9, 0.5))
	var body := Label.new()
	body.text = "The game is on the host's screen — your inputs still reach your pawn.\nFull remote mirrors arrive in phase 2; the estate keeps your seat warm."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 0)
	phase_box.add_child(body)
	var standings: Array = state.get("standings", [])
	if not standings.is_empty():
		var s_t := Label.new()
		s_t.text = "— THE LADDER TONIGHT —"
		s_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_t.add_theme_font_size_override("font_size", 15)
		s_t.modulate.a = 0.7
		phase_box.add_child(s_t)
		for s in standings:
			var l := Label.new()
			l.text = "%s  %d pts  ♠%d" % [String(s.get("name", "?")), int(s.get("points", 0)), int(s.get("grudge", 0))]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			phase_box.add_child(l)

func _on_net_session_closed(reason: String) -> void:
	_client_last_state = {}
	_client_walker_targets.clear()
	_client_panel_sig = ""
	for w in walkers:
		if is_instance_valid(w):
			w.set_physics_process(true)
	if _netprobe != "":
		return  # the probe script owns its own exit
	if phase == Phase.LOBBY or phase == Phase.GROUNDS:
		_flash("THE NIGHT WENT DARK — %s" % reason, Color(0.9, 0.6, 0.6), 3.0)
		_enter_title()

## ===== NETPROBE — two-instance verification rig (doc 10 §7) =====
## host:  windowed, --net=host --netprobe=host --mockonly-equivalent night
## join:  windowed, --net=join=127.0.0.1:8910 --nettape --netprobe=join
## couch: headless, --netprobe=couch — SAME tape through the SAME injector
##        with no wire, for the determinism diff. Traces print as
##        NETPROBE_TRACE lines; results as NETPROBE_RESULTS.

func _physics_process(_delta: float) -> void:
	if _netprobe == "" or NetSession.is_client() or walkers.size() < 2 or not is_instance_valid(walkers[1]):
		return
	var t: int = NetSession.trace_tick()
	if t >= 0 and t <= 300 and t % 30 == 0 and t != _np_last_trace:
		_np_last_trace = t
		var pos: Vector3 = walkers[1].global_position
		print("NETPROBE_TRACE tick=%d p1=(%.3f,%.3f,%.3f)" % [t, pos.x, pos.y, pos.z])

func _np_snap(tag: String) -> void:
	if DisplayServer.get_name() != "headless":
		await VerifyCapture.snap(tag)

func _on_net_probe_first_input(seat: int) -> void:
	if _netprobe == "" or seat != 1:
		return
	_np_anchor_walker()

## Pin the probed walker to a fixed mark the instant its input stream begins,
## so couch and relay traces share an origin (bot wander history differs).
func _np_anchor_walker() -> void:
	if walkers.size() > 1 and is_instance_valid(walkers[1]):
		walkers[1].global_position = Vector3(0.0, 0.1, -2.5)
		walkers[1].velocity = Vector3.ZERO
		walkers[1].walk_target = Vector3.INF
		print("NETPROBE anchor seat1 (0.0,0.1,-2.5)")

func _netprobe_run() -> void:
	print("NETPROBE mode=%s" % _netprobe)
	NetSession.code_selftest()
	var ps := ProjectSettings.globalize_path("user://party_setup.json")
	var pf := ProjectSettings.globalize_path("user://prefs.json")
	if _netprobe != "join":
		for f in [ps, pf]:
			if FileAccess.file_exists(f):
				DirAccess.copy_absolute(f, f + ".npbak")
	await get_tree().create_timer(1.0).timeout
	if _netprobe == "join":
		await _netprobe_join_flow()
	else:
		await _netprobe_host_flow(ps, pf)

func _np_wait(cond: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().create_timer(0.2).timeout
	return true

func _netprobe_host_flow(ps: String, pf: String) -> void:
	mockonly = true
	_hide_title()
	PlayerInput.assign(0, -1)
	PlayerInput.set_bot(0, false)
	for i in [1, 2, 3]:
		PlayerInput.set_bot(i, true)
	if _netprobe == "host" and not NetSession.is_host():
		NetSession.host_night()
	_enter_lobby()
	if _netprobe == "couch":
		await get_tree().create_timer(1.0).timeout
		PlayerInput.assign(1, -99)
		PlayerInput.set_bot(1, false)
		_lobby_ready.erase(1)
		_np_anchor_walker()
		NetSession.start_local_tape(1)
		_build_lobby_panel()
	else:
		var claimed := func() -> bool: return NetSession.is_seat_remote(1)
		if not await _np_wait(claimed, 60.0):
			print("NETPROBE FAIL: no remote claim on seat 1")
			await _netprobe_finish(ps, pf)
			return
		print("NETPROBE seat 1 claimed by peer %d" % NetSession.peer_of_seat(1))
	await get_tree().create_timer(1.0).timeout
	await _np_snap("online_host_claim")
	# tape: 5 s stroll (traced) + READY press at tick 300
	var seat1_ready := func() -> bool: return bool(_lobby_ready.get(1, false))
	var got_ready: bool = await _np_wait(seat1_ready, 30.0)
	print("NETPROBE seat1 lobby ready=%s" % str(got_ready))
	await _np_snap("online_host_ready")
	_start_night_from_lobby()
	await get_tree().create_timer(1.5).timeout
	_continue_to_night()
	var gate_up := func() -> bool: return _ready_gate_active
	if await _np_wait(gate_up, 40.0):
		_ready_gate_ready[0] = true
		_refresh_ready_gate_countdown()
		await get_tree().create_timer(0.6).timeout
		await _np_snap("online_host_gate")
	var in_game := func() -> bool: return phase == Phase.GAME
	if not await _np_wait(in_game, 40.0):
		print("NETPROBE FAIL: night never reached GAME")
		await _netprobe_finish(ps, pf)
		return
	await get_tree().create_timer(1.2).timeout
	await _np_snap("online_host_game")
	var reckoned := func() -> bool: return phase == Phase.RECKONING
	if await _np_wait(reckoned, 40.0):
		await get_tree().create_timer(1.2).timeout
		await _np_snap("online_host_reckoning")
	var parts := "NETPROBE_RESULTS"
	for pl in EstateState.players:
		parts += " %s:pts=%d,grudge=%d" % [pl.name, pl.points, pl.grudge]
	print(parts)
	await _netprobe_finish(ps, pf)

func _netprobe_finish(ps: String, pf: String) -> void:
	for f in [ps, pf]:
		if FileAccess.file_exists(f + ".npbak"):
			DirAccess.copy_absolute(f + ".npbak", f)
			DirAccess.remove_absolute(f + ".npbak")
	print("NETPROBE saves restored")
	print("NETPROBE_DONE")
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()

func _netprobe_join_flow() -> void:
	var seated := func() -> bool: return NetSession.my_seat() >= 0
	if not await _np_wait(seated, 60.0):
		print("NETPROBE FAIL: never granted a seat")
		get_tree().quit()
		return
	print("NETPROBE granted seat %d" % NetSession.my_seat())
	await get_tree().create_timer(2.0).timeout
	await _np_snap("online_client_lobby")
	var my := NetSession.my_seat()
	var see_ready := func() -> bool:
		var seats: Array = _client_last_state.get("seats", [])
		return my < seats.size() and bool(seats[my].get("ready", false))
	var ready_seen: bool = await _np_wait(see_ready, 30.0)
	print("NETPROBE client sees own ready=%s" % str(ready_seen))
	await get_tree().create_timer(0.5).timeout
	await _np_snap("online_client_ready")
	var gate_seen := func() -> bool: return _client_last_state.has("gate")
	if await _np_wait(gate_seen, 40.0):
		await get_tree().create_timer(0.6).timeout
		await _np_snap("online_client_gate")
	var game_seen := func() -> bool: return String(_client_last_state.get("phase", "")) == "GAME"
	if await _np_wait(game_seen, 40.0):
		await get_tree().create_timer(1.2).timeout
		await _np_snap("online_client_spectate")
	var reck_seen := func() -> bool: return String(_client_last_state.get("phase", "")) == "RECKONING"
	if await _np_wait(reck_seen, 40.0):
		await get_tree().create_timer(1.0).timeout
		await _np_snap("online_client_reckoning")
	print("NETPROBE_CLIENT_DONE")
	# outlive the host by a breath so its quit lands first, then leave
	await get_tree().create_timer(6.0).timeout
	get_tree().quit()
