class_name WardrobePanel
extends RefCounted

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

static func schedule_wardrobe_test(estate) -> void:
	# Self-contained: backs up and restores the REAL saves it mutates
	# (buying writes estate_save.json; equipping writes cosmetics.json).
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		var est := ProjectSettings.globalize_path(EstateState.slot_path(EstateState.current_slot))
		var cos := ProjectSettings.globalize_path("user://cosmetics.json")
		if FileAccess.file_exists(est):
			DirAccess.copy_absolute(est, est + ".wt_bak")
		if FileAccess.file_exists(cos):
			DirAccess.copy_absolute(cos, cos + ".wt_bak")
		estate._enter_lobby()
		EstateState.legacy[0] = 50
		estate._build_wardrobe_panel()
		estate._wardrobe_tap("viking_helm")
		print("WARDROBETEST legacy=%d owned=%s worn=%s" % [EstateState.legacy_of(0), str(EstateState.owned_cosmetics(0)), str(Cosmetics.get_player_cosmetics(0))])
		VerifyCapture.snap("wardrobe")
		estate.get_tree().create_timer(1.0).timeout.connect(func():
			for pair in [[est + ".wt_bak", est], [cos + ".wt_bak", cos]]:
				if FileAccess.file_exists(pair[0]):
					DirAccess.copy_absolute(pair[0], pair[1])
					DirAccess.remove_absolute(pair[0])
			print("WARDROBETEST saves restored")))

static func build(estate) -> void:
	estate._clear_panel("THE WARDROBE — legacy buys vanity", Color(0.95, 0.85, 1.0))
	var seat_row := HBoxContainer.new()
	seat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seat_row.add_theme_constant_override("separation", 10)
	for i in EstateState.players.size():
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(150, 44)
		pb.text = "%s  %d LEGACY" % [GameState.PLAYER_NAMES[i], EstateState.legacy_of(i)]
		pb.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		pb.disabled = i == estate._wardrobe_player
		pb.pressed.connect(func():
			estate._wardrobe_player = i
			Sfx.play("card")
			estate._build_wardrobe_panel())
		seat_row.add_child(pb)
	estate.phase_box.add_child(seat_row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var worn: Dictionary = Cosmetics.get_player_cosmetics(estate._wardrobe_player)
	for id in WARDROBE_PRICES:
		var owned: bool = id in EstateState.owned_cosmetics(estate._wardrobe_player)
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
			b.disabled = EstateState.legacy_of(estate._wardrobe_player) < WARDROBE_PRICES[id]
		b.pressed.connect(Callable(estate, "_wardrobe_tap").bind(String(id)))
		grid.add_child(b)
	var center := CenterContainer.new()
	center.add_child(grid)
	estate.phase_box.add_child(center)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func():
		Sfx.play("card")
		if estate.get_phase_name() == "GROUNDS":
			estate._build_freeroam_panel()
		else:
			estate._enter_title())
	estate.phase_box.add_child(back)
	var hint := Label.new()
	hint.text = "LEGACY = the estate's memory of your points, paid at each dawn. It buys nothing but respect."
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.65
	estate.phase_box.add_child(hint)

static func tap(estate, id: String) -> void:
	var p: int = estate._wardrobe_player
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
		estate._flash("%s BUYS %s" % [EstateState.players[p].name, id.replace("_", " ").to_upper()], EstateState.players[p].color, 2.0)
	else:
		Sfx.play("invalid")
		return
	estate._refresh_walker_cosmetics(p)
	estate._build_wardrobe_panel()

static func refresh_walker_cosmetics(walkers: Array, p: int) -> void:
	if p >= walkers.size() or not is_instance_valid(walkers[p]):
		return
	for slot in Cosmetics.SLOT_ATTACHMENTS:
		Cosmetics.unequip(walkers[p], slot)
	Cosmetics.apply_to_character(walkers[p], p)
