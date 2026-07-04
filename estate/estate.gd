extends Node3D
## THE ESTATE — night-loop shell: GROUNDS -> AUCTION -> GAME -> RECKONING.
## v1 "clipboard" grounds (panel UI); walkable grounds is phase E2.

enum Phase { GROUNDS, TILES, AUCTION, GAME, RECKONING, NIGHT_END }

const TILE_COST := 2

const MODULES := {
	"par": {"name": "PAR FOR THE CURSE", "scene": "res://scenes/main.tscn", "mode": "gamestate"},
	"echo": {"name": "ECHO CHAMBER", "scene": "res://minigames/echo_chamber/echo_chamber.tscn", "mode": "contract"},
	"tilt": {"name": "TILT", "scene": "res://minigames/tilt/tilt.tscn", "mode": "contract"},
	"orbital": {"name": "ORBITAL DODGEBALL", "scene": "res://minigames/orbital/orbital.tscn", "mode": "contract"},
	"mower": {"name": "MOWER MAYHEM", "scene": "res://minigames/mower/mower.tscn", "mode": "contract"},
	"greed": {"name": "GREED INC.", "scene": "res://minigames/greed/greed.tscn", "mode": "contract"},
	"swap": {"name": "SWAP MEET", "scene": "res://minigames/swap_meet/swap_meet.tscn", "mode": "contract"},
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
var _selected_walker := -1
var _bot_wander_timer := 0.0
var _tile_buyers: Array = []

@onready var cam: Camera3D = $Camera3D
@onready var top_bar: HBoxContainer = $UI/TopBar/Row
@onready var phase_panel: PanelContainer = $UI/PhasePanel
@onready var phase_box: VBoxContainer = $UI/PhasePanel/Box
@onready var banner: Label = $UI/Banner
@onready var plinths: Node3D = $Plinths
@onready var wall_text: Label3D = $GraffitiWall/Lines

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--estatebots":
			bots = true
		elif arg == "--mockonly":
			mockonly = true
		elif arg.begins_with("--pool="):
			pool_override = Array(arg.trim_prefix("--pool=").split(","))
	EstateState.start_night(GameState.player_count)
	PlayerInput.auto_assign(GameState.player_count)
	_spawn_walkers()
	_spawn_toys()
	$Trail.build(EstateState.players, EstateState.gate_statues)
	_redraw_monuments()
	_redraw_graffiti()
	banner.visible = false
	if EstateState.nights_played > 0:
		_flash("NIGHT %d — THE ESTATE REMEMBERS" % (EstateState.nights_played + 1), Color(1, 0.85, 0.2), 2.5)
	_enter_grounds()

func get_phase_name() -> String:
	return Phase.keys()[phase]

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
		walkers.append(w)

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
	if bots and _module == null and not walkers.is_empty():
		_bot_wander_timer -= delta
		if _bot_wander_timer <= 0.0:
			_bot_wander_timer = 1.6
			var w: EstateWalker = walkers[EstateState.rng.randi_range(0, walkers.size() - 1)]
			w.walk_target = Vector3(EstateState.rng.randf_range(-6.0, 6.0), 0, EstateState.rng.randf_range(-7.0, 1.5))
	if phase == Phase.GROUNDS:
		_grounds_timer -= delta
		_update_grounds_clock()
		if _grounds_timer <= 0.0 or (bots and _grounds_timer < GROUNDS_TIME - 1.5):
			if bots:
				_bots_buy_tiles()
				_bots_place_bets()
			_enter_tiles()
	elif phase == Phase.AUCTION:
		_bid_timer -= delta
		_update_auction_clock()
		if bots and _bid_timer < BID_TIME - 1.0 and high_bidder < 0:
			_bots_bid()
		if _bid_timer <= 0.0:
			_resolve_auction()

func _rebuild_top_bar() -> void:
	for c in top_bar.get_children():
		c.queue_free()
	for i in EstateState.standings():
		var pl = EstateState.players[i]
		var l := Label.new()
		l.text = "%s %d  ♠%d   " % [pl.name, pl.points, pl.grudge]
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
		EstateState.place_bet(i, EstateState.rng.randi_range(0, EstateState.players.size() - 1))

func _bots_buy_tiles() -> void:
	for i in EstateState.players.size():
		if EstateState.rng.randf() < 0.55 and not _tile_buyers.has(i):
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
	if bots:
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
	high_bid = 0
	high_bidder = -1
	_bid_timer = BID_TIME
	var pool := ["mock", "mock", "mock"] if mockonly else ["par", "echo", "tilt", "orbital", "mower", "greed", "swap"]
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
		b.text = "%s BID %d♠" % [pl.name, high_bid + 1]
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
			b.text = "%s BID %d♠" % [EstateState.players[i].name, high_bid + 1]

func _update_auction_clock() -> void:
	var clock := phase_box.get_node_or_null("Clock")
	if clock:
		var lead := "no bids — cheapest seat chooses" if high_bidder < 0 else "%s leads at %d♠" % [EstateState.players[high_bidder].name, high_bid]
		clock.text = "%s   (%ds)" % [lead, ceili(_bid_timer)]

func _bots_bid() -> void:
	var p := EstateState.rng.randi_range(0, EstateState.players.size() - 1)
	_on_bid(p)

func _resolve_auction() -> void:
	var chooser := high_bidder
	if chooser >= 0:
		EstateState.players[chooser].grudge -= high_bid
		EstateState.pot += high_bid
	else:
		chooser = EstateState.standings().back()
	var chosen: String = auction_options[0]
	if bots:
		chosen = auction_options[EstateState.rng.randi_range(0, auction_options.size() - 1)]
		_launch_game(chosen)
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

func _launch_game(id: String) -> void:
	if phase == Phase.GAME:
		return
	phase = Phase.GAME
	phase_panel.visible = false
	Sfx.play("confirm")
	var info: Dictionary = MODULES[id]
	var scene: PackedScene = load(info.scene)
	_module = scene.instantiate()
	$Grounds.visible = false
	$Grounds.process_mode = Node.PROCESS_MODE_DISABLED
	plinths.visible = false
	$GraffitiWall.visible = false
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
			})
		_module.begin({
			"roster": roster,
			"rounds": 4,
			"rng_seed": EstateState.rng.randi(),
			"practice": false,
		})
	cam.current = false

func _on_module_finished(results: Dictionary) -> void:
	if _module:
		_module.queue_free()
		_module = null
	$Grounds.visible = true
	$Grounds.process_mode = Node.PROCESS_MODE_INHERIT
	plinths.visible = true
	$GraffitiWall.visible = true
	$UI/TopBar.visible = true
	cam.current = true
	var ticker := EstateState.apply_results(results)
	_redraw_monuments()
	_redraw_graffiti()
	_enter_reckoning(ticker)

func _enter_reckoning(ticker: Array) -> void:
	phase = Phase.RECKONING
	_rebuild_top_bar()
	_clear_panel("THE RECKONING")
	Sfx.play("round_over")
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
	if bots:
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
		})
	podium.present(entries)
	_flash("%s WINS THE NIGHT\nthe estate will remember" % champ.name, champ.color, 9999.0)
	print("NIGHT_OVER winner=", champ.name, " monuments=", EstateState.monuments.size())
	await podium.done
	podium.queue_free()
	cam.current = true

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
