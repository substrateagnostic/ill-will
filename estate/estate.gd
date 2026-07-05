extends Node3D
## THE ESTATE — night-loop shell: GROUNDS -> AUCTION -> GAME -> RECKONING.
## v1 "clipboard" grounds (panel UI); walkable grounds is phase E2.

enum Phase { LOBBY, SELECTOR, GROUNDS, TILES, AUCTION, CHOOSING, GAME, RECKONING, NIGHT_END }

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

@onready var cam: Camera3D = $Camera3D
@onready var top_bar: HBoxContainer = $UI/TopBar/Row
@onready var phase_panel: PanelContainer = $UI/PhasePanel
@onready var phase_box: VBoxContainer = $UI/PhasePanel/Box
@onready var banner: Label = $UI/Banner
@onready var plinths: Node3D = $Plinths
@onready var wall_text: Label3D = $GraffitiWall/Lines

func _ready() -> void:
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
		elif arg == "--howtotest":
			get_tree().create_timer(1.2).timeout.connect(func():
				_show_howto("orbital")
				VerifyCapture.snap("howto"))
		elif arg == "--wardrobetest":
			get_tree().create_timer(1.2).timeout.connect(func():
				EstateState.legacy[0] = 50
				_build_wardrobe_panel()
				_wardrobe_tap("viking_helm")
				print("WARDROBETEST legacy=%d owned=%s worn=%s" % [EstateState.legacy_of(0), str(EstateState.owned_cosmetics(0)), str(Cosmetics.get_player_cosmetics(0))])
				VerifyCapture.snap("wardrobe"))
	if "--skipmenu" in args:
		Transition.change_scene("res://scenes/main.tscn")
		return
	GameState.player_count = 4
	GameState.reset_match()
	EstateState.start_night(4)
	PlayerInput.auto_assign(4)
	_spawn_walkers()
	_spawn_toys()
	$Trail.build(EstateState.players, EstateState.gate_statues)
	_redraw_monuments()
	_redraw_graffiti()
	banner.visible = false
	_saved_env = $WorldEnvironment.environment
	if start_night_now:
		if EstateState.nights_played > 0:
			_flash("NIGHT %d — THE ESTATE REMEMBERS" % (EstateState.nights_played + 1), Color(1, 0.85, 0.2), 2.5)
		_enter_grounds()
	else:
		_enter_lobby()

## ----- LOBBY (the estate IS the main menu) -----

func _enter_lobby() -> void:
	phase = Phase.LOBBY
	Music.play_slot("lobby")
	$UI/TopBar.visible = false
	_flash("ILL WILL", Color(1, 0.85, 0.2), 9999.0)
	_build_lobby_panel()

func _build_lobby_panel() -> void:
	_clear_panel("who's on the couch?", Color(0.9, 0.95, 0.9))
	for i in 4:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		row.add_child(PlayerBadge.make(i, 20))
		var name_l := Label.new()
		name_l.text = GameState.PLAYER_NAMES[i]
		name_l.custom_minimum_size = Vector2(80, 0)
		name_l.add_theme_font_size_override("font_size", 24)
		name_l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(name_l)
		var bot_btn := Button.new()
		bot_btn.custom_minimum_size = Vector2(120, 44)
		bot_btn.text = "BOT" if PlayerInput.is_bot(i) else "HUMAN"
		bot_btn.pressed.connect(func():
			PlayerInput.set_bot(i, not PlayerInput.is_bot(i))
			bot_btn.text = "BOT" if PlayerInput.is_bot(i) else "HUMAN"
			Sfx.play("card"))
		row.add_child(bot_btn)
		var dev_btn := Button.new()
		dev_btn.custom_minimum_size = Vector2(210, 44)
		dev_btn.text = PartySetup.DEVICE_NAMES.get(PlayerInput.device_of(i), "UNASSIGNED")
		dev_btn.pressed.connect(func():
			var cur := PartySetup.DEVICE_CYCLE.find(PlayerInput.device_of(i))
			var nxt: int = PartySetup.DEVICE_CYCLE[(cur + 1) % PartySetup.DEVICE_CYCLE.size()]
			PlayerInput.assign(i, nxt)
			dev_btn.text = PartySetup.DEVICE_NAMES.get(nxt, "UNASSIGNED")
			Sfx.play("card"))
		row.add_child(dev_btn)
		phase_box.add_child(row)
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
	start_btn.custom_minimum_size = Vector2(240, 56)
	start_btn.text = "START THE NIGHT"
	start_btn.pressed.connect(_start_night_from_lobby)
	btn_row.add_child(start_btn)
	var sel_btn := Button.new()
	sel_btn.custom_minimum_size = Vector2(220, 56)
	sel_btn.text = "MINIGAMES (10)"
	sel_btn.pressed.connect(_enter_selector)
	btn_row.add_child(sel_btn)
	var ward_btn := Button.new()
	ward_btn.custom_minimum_size = Vector2(180, 56)
	ward_btn.text = "WARDROBE"
	ward_btn.pressed.connect(_build_wardrobe_panel)
	btn_row.add_child(ward_btn)
	phase_box.add_child(btn_row)
	var hint := Label.new()
	hint.text = "ESC = players & controls anytime  ·  the estate remembers everything"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate.a = 0.7
	phase_box.add_child(hint)

func _start_night_from_lobby() -> void:
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

## ----- MINIGAME SELECTOR (flat grid per UFO 50 pattern) -----

func _enter_selector() -> void:
	phase = Phase.SELECTOR
	Sfx.play("card")
	_clear_panel("PICK A GAME — exhibition match, no stakes", Color(0.9, 0.95, 0.9))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in MODULES:
		if id == "mock":
			continue
		var info: Dictionary = MODULES[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(158, 84)
		b.text = info.name
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_show_howto.bind(String(id)))
		grid.add_child(b)
	var center := CenterContainer.new()
	center.add_child(grid)
	phase_box.add_child(center)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_enter_lobby)
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
	"lastwill": {"goal": "A brawl where dying is power: the dead stop the world for six seconds and write curses into their will.", "a": "SHOVE", "b": "HOP"},
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
	back.text = "BACK TO THE GATES"
	back.pressed.connect(func():
		Sfx.play("card")
		_build_lobby_panel())
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
	if phase == Phase.GAME or _module != null:
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

func _process(delta: float) -> void:
	if _module == null and not walkers.is_empty():
		_bot_wander_timer -= delta
		if _bot_wander_timer <= 0.0:
			_bot_wander_timer = 1.6
			var bot_walkers: Array = walkers.filter(func(w): return _is_bot(w.player_idx))
			if not bot_walkers.is_empty():
				var w: EstateWalker = bot_walkers[EstateState.rng.randi_range(0, bot_walkers.size() - 1)]
				w.walk_target = Vector3(EstateState.rng.randf_range(-6.0, 6.0), 0, EstateState.rng.randf_range(-7.0, 1.5))
	if phase == Phase.GROUNDS:
		_grounds_timer -= delta
		_update_grounds_clock()
		if _grounds_timer <= 0.0 or (_all_bots() and _grounds_timer < GROUNDS_TIME - 1.5):
			_bots_buy_tiles()
			_bots_place_bets()
			_enter_tiles()
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
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_box.add_child(t)
	phase_panel.visible = true

func _enter_grounds() -> void:
	phase = Phase.GROUNDS
	Music.play_slot("grounds")
	_grounds_timer = GROUNDS_TIME
	_bet_targets.clear()
	_tile_buyers.clear()
	_rebuild_top_bar()
	_clear_panel("THE GROUNDS — place your bets on the next game")
	for i in EstateState.players.size():
		var pl = EstateState.players[i]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_l := Label.new()
		name_l.text = pl.name + "  "
		name_l.add_theme_color_override("font_color", pl.color)
		name_l.add_theme_font_size_override("font_size", 24)
		row.add_child(name_l)
		var target_btn := Button.new()
		_bet_targets[i] = (i + 1) % EstateState.players.size()
		target_btn.text = "on %s" % EstateState.players[_bet_targets[i]].name
		target_btn.pressed.connect(func():
			_bet_targets[i] = (_bet_targets[i] + 1) % EstateState.players.size()
			target_btn.text = "on %s" % EstateState.players[_bet_targets[i]].name)
		row.add_child(target_btn)
		var bet_btn := Button.new()
		bet_btn.text = "BET 1♠"
		bet_btn.pressed.connect(func():
			if EstateState.place_bet(i, _bet_targets[i]):
				bet_btn.text = "BET PLACED"
				bet_btn.disabled = true
				Sfx.play("card")
				_rebuild_top_bar())
		row.add_child(bet_btn)
		var tile_btn := Button.new()
		tile_btn.text = "TRAP TILE %d♠" % TILE_COST
		tile_btn.pressed.connect(func():
			if not _tile_buyers.has(i) and EstateState.spend_grudge(i, TILE_COST):
				_tile_buyers.append(i)
				tile_btn.text = "TILE BOUGHT"
				tile_btn.disabled = true
				Sfx.play("grudge")
				_rebuild_top_bar()
			else:
				Sfx.play("invalid"))
		row.add_child(tile_btn)
		if _is_bot(i):
			target_btn.disabled = true
			bet_btn.disabled = true
			tile_btn.disabled = true
			bet_btn.text = "BOT"
		phase_box.add_child(row)
	var clock := Label.new()
	clock.name = "Clock"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_box.add_child(clock)
	var skip := Button.new()
	skip.text = "TO THE AUCTION"
	skip.pressed.connect(_enter_auction)
	phase_box.add_child(skip)

func _update_grounds_clock() -> void:
	var clock := phase_box.get_node_or_null("Clock")
	if clock:
		clock.text = "%ds" % ceili(_grounds_timer)

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
	if not pool_override.is_empty():
		pool = pool_override
	auction_options.clear()
	for k in 3:
		auction_options.append(pool[EstateState.rng.randi_range(0, pool.size() - 1)])
	_rebuild_top_bar()
	_clear_panel("THE AUCTION — bid grudge to choose the game")
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
		b.disabled = _is_bot(i)
		b.pressed.connect(_on_bid.bind(i))
		row.add_child(b)
	row.name = "BidRow"
	phase_box.add_child(row)
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

func _launch_game(id: String, practice := false) -> void:
	if phase == Phase.GAME:
		return
	phase = Phase.GAME
	Music.stop()
	_practice = practice
	phase_panel.visible = false
	Sfx.play("confirm")
	var info: Dictionary = MODULES[id]
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
			"rounds": 2 if _practice else 4,
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
	if exhibition:
		exhibition = false
		$UI/TopBar.visible = false
		var champ_line := "EXHIBITION OVER"
		var placements: Array = results.get("placements", [])
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
	var summit := await _run_parade()
	if summit >= 0:
		_flash("%s REACHES THE MANOR!" % EstateState.players[summit].name, EstateState.players[summit].color, 3.0)
		await get_tree().create_timer(2.0).timeout
		_end_night(summit)
		return
	var btn := Button.new()
	btn.text = "BACK TO THE GROUNDS" if EstateState.games_played < EstateState.night_length else "END THE NIGHT"
	btn.pressed.connect(_after_reckoning)
	phase_box.add_child(btn)
	if _all_bots():
		get_tree().create_timer(2.0).timeout.connect(_after_reckoning)

## Advances every pawn by the points just earned, worst first, winner last.
## Handles tollgate claims/payments. Returns a summit player index or -1.
func _run_parade() -> int:
	var order: Array = EstateState.last_deltas.keys()
	order.sort_custom(func(a, b): return EstateState.last_deltas[a] < EstateState.last_deltas[b])
	var summit := -1
	for p in order:
		var delta: int = EstateState.last_deltas[p]
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
		_end_night()
	else:
		_enter_grounds()

func _end_night(champ_override := -1) -> void:
	phase = Phase.NIGHT_END
	var champ = EstateState.end_night(champ_override)
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
	head.text = "Night %d is settled. %s takes the manor." % [EstateState.nights_played, champ.name]
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
	var i := 0
	for c in phase_box.get_children():
		if c is Label and c.modulate.a == 0.0:
			var tw := create_tween()
			tw.tween_interval(0.45 * i)
			tw.tween_property(c, "modulate:a", 1.0, 0.3)
			i += 1
	print("WILL_READ night=%d awards=%d" % [EstateState.nights_played, awards.size()])
	await get_tree().create_timer(0.45 * i + 0.6).timeout
	VerifyCapture.snap("will_reading")
	if phase != Phase.NIGHT_END:
		return
	var btn := Button.new()
	btn.text = "DAWN — BACK TO THE GATES"
	btn.pressed.connect(_return_to_lobby)
	phase_box.add_child(btn)
	if _all_bots():
		get_tree().create_timer(2.5).timeout.connect(_return_to_lobby)

func _return_to_lobby() -> void:
	if phase != Phase.NIGHT_END:
		return
	Sfx.play("confirm")
	GameState.reset_match()
	EstateState.start_night(4)
	$Trail.reset_pawns()
	_rebuild_top_bar()
	banner.visible = false
	print("DAWN back to lobby")
	_enter_lobby()

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
	for m_idx in EstateState.monuments.size():
		var m: Dictionary = EstateState.monuments[m_idx]
		var col := Color.from_string(str(m.color), Color.WHITE)
		var obelisk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.45, 1.3, 0.45)
		obelisk.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		obelisk.material_override = mat
		obelisk.position = Vector3(-7.4 + (m_idx % 2) * 1.1, 0.65, 0.8 - floorf(m_idx / 2.0) * 1.7)
		plinths.add_child(obelisk)
		var tag := Label3D.new()
		tag.text = str(m.label)
		tag.pixel_size = 0.005
		tag.position = obelisk.position + Vector3(0, 0.95, 0.3)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plinths.add_child(tag)

func _redraw_graffiti() -> void:
	var lines: Array = EstateState.graffiti.slice(-10)
	wall_text.text = "\n".join(PackedStringArray(lines))
