class_name HowtoCards
extends RefCounted

## First-night HOUSE RULES card: the opening auction of a brand-new estate pauses
## for a one-time economy primer. Humans press A to continue; the card auto-
## advances after this many seconds so bots / unattended tables never stall.
const HOUSE_RULES_TIME := 5.0

## How-to-Play cards (UFO 50 pattern): goal + LIVE controls per seat via
## PlayerInput.describe_binding — the card can't lie about bindings.
const HOWTO := {
	"par": {"goal": "Sabotage golf. Draft a trap, place it on the SHARED hole, then putt it yourself. Your trap's kills pay YOU royalties. Last round is CHAOS: everyone putts at once.", "a": "", "b": ""},
	"echo": {"goal": "Duel beside your own GHOST — it replays your previous round. Shatter the others before the past catches up.", "a": "STRIKE", "b": "DASH (hold: PARRY)", "jump": "HOP (cosmetic — just for kicks)"},
	"tilt": {"goal": "The floor is one platter and everyone's weight tilts it. Fall off and you return as a vengeful seagull.", "a": "SHOVE (answer to CLASH)", "b": "BRACE"},
	"orbital": {"goal": "Dodgeball on a tiny planet. Throws ORBIT forever — a 45-second-old ball still kills, and its thrower still gets paid.", "a": "hold: AIM+THROW / tap: CATCH", "b": "JUMP the gap"},
	"mower": {"goal": "Mow more lawn than anyone. Coverage is score; ramming is diplomacy.", "a": "RAM HORN", "b": "BOOST (wider cut)"},
	"greed": {"goal": "One pot of gold, four sets of hands. Bank it down your chute; tackle whoever is richer.", "a": "GRAB / TACKLE", "b": "DASH", "jump": "HOP (cosmetic — just for kicks)"},
	"swap": {"goal": "Kart race where your weapon TRADES PLACES with whoever it hits. The lead is a rumor.", "a": "THROW SWAP ORB", "b": "hold: DRIFT, release: BOOST"},
	"deadweight": {"goal": "Sumo where the dead never leave — they possess the furniture and fling it at the living.", "a": "SHOVE", "b": "HOP"},
	"throne": {"goal": "One throne, four claimants. Reigning scores. Decrees blast, guards defend, gravity votes last.", "a": "SHOVE / DECREE", "b": "DASH / GUARD", "jump": "HOP (cosmetic — just for kicks)"},
	"lastwill": {"goal": "A funeral procession race: first to the crypt inherits. Every death freezes the world while the deceased writes a curse into the road.", "a": "SHOVE", "b": "HOP"},
	"widowsgaze": {"goal": "Rob the wake. Creep the parlor for relics while the Widow weeps — FREEZE when she turns, or her gaze flings you back to the rope. A shove as the sting plays is a murder.", "a": "GRAB / BANK (hold)", "b": "SHOVE"},
	"seance": {"goal": "A co-op séance: guide the planchette to the spirit's word — but one of you was paid in grudge to make it fail without getting caught. The Executor is the medium.", "a": "CHANT ON THE PULSE", "b": "SURGE (anonymous)"},
	"understudy": {"goal": "Everyone knows tonight's play but the understudy, who must bluff along. Rehearse, interrogate, vote — the scoring never stalemates.", "a": "COMMIT (move = choose)", "b": "—"},
	"maskedball": {"goal": "A crowd of identical masked dancers — four of them are you, and nobody is told which. Find yourself, dance like furniture, curtsy to the throne, and spend your one mark to unmask a human. Wrong guess: you flash.", "a": "CURTSY (scores in the circle)", "b": "UNMASK (one mark)"},
}

static func schedule_howto_test(estate) -> void:
	# Seat two keyboard humans + two bots so the CONTROLS TONIGHT rows render
	# real brand glyphs (keyboard here) with text fallback. Self-contained:
	# backs up/restores party_setup.json (assign/set_bot persist seat choices).
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		var ps := ProjectSettings.globalize_path("user://party_setup.json")
		if FileAccess.file_exists(ps):
			DirAccess.copy_absolute(ps, ps + ".htbak")
		PlayerInput.assign(0, -1)
		PlayerInput.set_bot(0, false)
		PlayerInput.assign(1, -2)
		PlayerInput.set_bot(1, false)
		PlayerInput.set_bot(2, true)
		PlayerInput.set_bot(3, true)
		estate._hide_title()
		estate._show_howto("orbital")
		VerifyCapture.snap("howto")
		estate.get_tree().create_timer(1.0).timeout.connect(func():
			if FileAccess.file_exists(ps + ".htbak"):
				DirAccess.copy_absolute(ps + ".htbak", ps)
				DirAccess.remove_absolute(ps + ".htbak")
			print("HOWTOTEST saves restored")))

static func schedule_ready_test(estate) -> void:
	# Windowed GET READY card proof. Self-contained: backs up/restores
	# party_setup.json (the ready/join flows persist seat choices).
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		var ps := ProjectSettings.globalize_path("user://party_setup.json")
		if FileAccess.file_exists(ps):
			DirAccess.copy_absolute(ps, ps + ".rrbak")
		estate._hide_title()
		PlayerInput.assign(0, -1)
		PlayerInput.set_bot(0, false)
		PlayerInput.assign(1, -2)
		PlayerInput.set_bot(1, false)
		PlayerInput.set_bot(2, true)
		PlayerInput.set_bot(3, true)
		estate._show_get_ready("orbital")
		estate._ready_gate_ready[1] = true
		var gr: Node = estate.phase_box.get_node_or_null("GateRow1")
		if gr:
			var chip: Node = gr.get_node_or_null("GateChip")
			if chip:
				chip.text = "READY"
				chip.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
				chip.modulate.a = 1.0
		estate._refresh_ready_gate_countdown()
		estate._ready_gate_active = false
		VerifyCapture.snap("readyroom_getready")
		estate.get_tree().create_timer(1.0).timeout.connect(func():
			# DOUBLE-GATE COLLAPSE proofs (morning menu #4): the minimal
			# "everyone in" skin (online sync form), then a couch launch of an
			# intro-card game, which must SKIP the estate gate entirely and
			# land on the module's own IntroCard.
			estate._show_get_ready("tilt", false, true)
			estate._ready_gate_active = false
			VerifyCapture.snap("readyroom_gate_minimal")
			estate.get_tree().create_timer(1.0).timeout.connect(func():
				estate._launch_game("tilt")
				print("READYTEST collapse: gate_active=%s phase=%s (want false / GAME)" % [
					str(estate._ready_gate_active), estate.get_phase_name()])
				estate.get_tree().create_timer(1.6).timeout.connect(func():
					VerifyCapture.snap("readyroom_collapse_introcard")
					if FileAccess.file_exists(ps + ".rrbak"):
						DirAccess.copy_absolute(ps + ".rrbak", ps)
						DirAccess.remove_absolute(ps + ".rrbak")
					print("READYTEST saves restored")
					estate.get_tree().create_timer(0.4).timeout.connect(func():
						estate.get_tree().quit())))))

static func schedule_house_rules_test(estate) -> void:
	# Windowed HOUSE RULES card proof. Self-contained: backs up/restores
	# the slot save (_show_house_rules persists the "shown" flag). Forces a
	# brand-new estate in memory, then drives the real _enter_auction gate.
	estate.get_tree().create_timer(1.2).timeout.connect(func():
		var slot := ProjectSettings.globalize_path(EstateState.slot_path(EstateState.current_slot))
		var had_slot := FileAccess.file_exists(slot)
		if had_slot:
			DirAccess.copy_absolute(slot, slot + ".hrbak")
		EstateState.house_rules_shown = false
		EstateState.nights_played = 0
		EstateState.run_night = 0
		EstateState.games_played = 0
		EstateState.ledger.clear()
		estate._hide_title()
		estate.get_node("UI/TopBar").set("visible", true)
		estate._rebuild_top_bar()
		PlayerInput.assign(0, -1)
		PlayerInput.set_bot(0, false)
		PlayerInput.assign(1, -2)
		PlayerInput.set_bot(1, false)
		PlayerInput.set_bot(2, true)
		PlayerInput.set_bot(3, true)
		estate._enter_auction()
		print("HOUSERULESTEST card_up=%s needed=%s" % [str(estate._house_rules_active), str(estate._house_rules_needed)])
		VerifyCapture.snap("house_rules")
		estate.get_tree().create_timer(1.0).timeout.connect(func():
			if had_slot:
				DirAccess.copy_absolute(slot + ".hrbak", slot)
				DirAccess.remove_absolute(slot + ".hrbak")
			elif FileAccess.file_exists(slot):
				DirAccess.remove_absolute(slot)
			print("HOUSERULESTEST saves restored")
			estate.get_tree().quit()))

## ----- MINIGAME SELECTOR (flat grid per UFO 50 pattern) -----

static func enter_selector(estate, modules: Dictionary) -> void:
	estate._net_set_ceremony({})
	estate._hide_title()
	Music.play_slot("lobby")
	Sfx.play("card")
	estate._clear_panel("PICK A GAME — exhibition match, no stakes", Color(0.9, 0.95, 0.9))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in modules:
		var info: Dictionary = modules[id]
		# Theater specials appear the moment their scene lands on disk.
		if id == "mock" or not ResourceLoader.exists(String(info.scene)):
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(158, 84)
		b.text = String(info.name) + ("\n· at the theater ·" if info.get("theater", false) else "")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(Callable(estate, "_show_howto").bind(String(id)))
		grid.add_child(b)
	var center := CenterContainer.new()
	center.add_child(grid)
	estate.phase_box.add_child(center)
	var back := Button.new()
	back.text = "BACK TO TITLE"
	back.pressed.connect(Callable(estate, "_enter_title"))
	estate.phase_box.add_child(back)

## One live control chip: brand glyph via Input.get_joy_name (InputGlyphs), with
## an always-correct text fallback (describe_binding) when no glyph fits the
## device / remap. Optional leading caption and trailing meaning label.
static func _add_control_segment(row: HBoxContainer, player_idx: int, action: String, caption: String, meaning: String) -> void:
	if caption != "":
		var caption_l: Label = Label.new()
		caption_l.text = caption
		caption_l.add_theme_font_size_override("font_size", 14)
		caption_l.modulate.a = 0.72
		row.add_child(caption_l)
	var glyph: Texture2D = InputGlyphs.texture_for(player_idx, action)
	if glyph != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = glyph
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	else:
		var fallback: Label = Label.new()
		fallback.text = InputGlyphs.text_for(player_idx, action)
		fallback.add_theme_font_size_override("font_size", 16)
		fallback.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
		row.add_child(fallback)
	if meaning != "":
		var meaning_l: Label = Label.new()
		meaning_l.text = ": %s" % meaning
		meaning_l.add_theme_font_size_override("font_size", 15)
		row.add_child(meaning_l)

static func show_howto(estate, modules: Dictionary, id: String) -> void:
	Sfx.play("card")
	var info: Dictionary = modules[id]
	estate._clear_panel(String(info.name), Color(1, 0.9, 0.5))
	var how: Dictionary = HOWTO.get(id, {"goal": "?", "a": "A", "b": "B"})
	var goal := Label.new()
	goal.text = String(how.goal)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(680, 0)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estate.phase_box.add_child(goal)
	var ctl_title := Label.new()
	ctl_title.text = "— CONTROLS TONIGHT (live from your settings) —"
	ctl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl_title.modulate.a = 0.7
	ctl_title.add_theme_font_size_override("font_size", 15)
	estate.phase_box.add_child(ctl_title)
	for i in 4:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(PlayerBadge.make(i, 16))
		var has_jump: bool = String(how.get("jump", "")) != ""
		if not PlayerInput.is_bot(i) and not NetSession.is_seat_remote(i) and id != "par":
			_add_control_segment(row, i, "move", "", "")
			_add_control_segment(row, i, "a", "", "")
			_add_control_segment(row, i, "b", "", "")
			if has_jump:
				_add_control_segment(row, i, "jump", "", "")
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
			if has_jump:
				l.text += "  ·  %s: %s" % [PlayerInput.describe_binding(i, "jump"), String(how.jump)]
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(l)
		estate.phase_box.add_child(row)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	var play := Button.new()
	play.custom_minimum_size = Vector2(220, 54)
	play.text = "PLAY — EXHIBITION"
	play.pressed.connect(func():
		estate.exhibition = true
		estate._launch_game(id))
	btns.add_child(play)
	if id != "par":
		var prac := Button.new()
		prac.custom_minimum_size = Vector2(200, 54)
		prac.text = "PRACTICE (no stakes)"
		prac.pressed.connect(func():
			estate.exhibition = true
			estate._launch_game(id, true))
		btns.add_child(prac)
	var back := Button.new()
	back.custom_minimum_size = Vector2(120, 54)
	back.text = "BACK"
	back.pressed.connect(Callable(estate, "_enter_selector"))
	btns.add_child(back)
	estate.phase_box.add_child(btns)

## ----- FIRST-NIGHT HOUSE RULES (economy primer, once per fresh estate) -----

## Only a brand-new estate with human hands on it earns the lecture: opening
## auction (games_played 0), first night of the run, nothing in the ledger, the
## slot never taught before. Soaks (all bots) and guests (clients) skip it — so
## --auctiontest / --estatebots reach the auction untouched.
static func should_show_house_rules(estate) -> bool:
	if NetSession.is_client() or estate._all_bots():
		return false
	if EstateState.house_rules_shown:
		return false
	return EstateState.games_played == 0 and EstateState.run_night == 0 \
		and EstateState.nights_played == 0

static func maybe_show_house_rules(estate) -> bool:
	if not estate._should_show_house_rules():
		return false
	estate._show_house_rules()
	return true

## The card itself: the Executor's five-line primer on the economy a first-timer
## needs, then a per-seat A-to-continue gate (the GET READY chip pattern).
static func show_house_rules(estate) -> void:
	estate._house_rules_active = true
	estate._house_rules_countdown = HOUSE_RULES_TIME
	estate._house_rules_ready.clear()
	estate._house_rules_needed.clear()
	# Persist immediately: even if the night is abandoned on this card, the estate
	# has now "explained itself once" and will not lecture this slot again.
	EstateState.mark_house_rules_shown()
	print("HOUSE_RULES shown (first-night primer, slot %d)" % EstateState.current_slot)
	Sfx.play("card")
	estate._hide_title()
	estate.banner.visible = false
	estate._clear_panel("THE HOUSE RULES", Color(1, 0.85, 0.2))
	var intro := Label.new()
	intro.text = "You are new to the estate, so it will explain itself. Once. It keeps no patience for a slow study and less for a repeat question."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(720, 0)
	intro.add_theme_font_size_override("font_size", 16)
	intro.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	estate.phase_box.add_child(intro)
	var rules := [
		"POINTS are the ladder. Place well in each game and the estate counts you among the worthy; place last and it counts you anyway.",
		"♠ GRUDGE is spite made spendable — it buys your bids at THE AUCTION and the trap tiles you seed into the lawn.",
		"ROYALTIES are the house's kindest cruelty: the traps and curses you author pay YOU, every time they take somebody else.",
		"THE TRAIL climbs to the manor. First to the summit inherits it; the rest inherit the memory of the climb.",
		"Every night closes at THE READING, where the ledger is totted up aloud and no one, on principle, is flattered.",
	]
	for line in rules:
		var l := Label.new()
		l.text = "·  " + line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(720, 0)
		l.add_theme_font_size_override("font_size", 18)
		estate.phase_box.add_child(l)
	var sig := Label.new()
	sig.text = "— The Executor"
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sig.add_theme_font_size_override("font_size", 15)
	sig.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	sig.modulate.a = 0.8
	estate.phase_box.add_child(sig)
	# Per-seat A-to-continue (GET READY chip pattern). Bots, remote guests and the
	# shared/mouse seat (-3, no discrete A) count as ready on arrival.
	for i in EstateState.players.size():
		if PlayerInput.is_bot(i) or NetSession.is_seat_remote(i):
			continue
		if PlayerInput.device_of(i) == -3:
			estate._house_rules_ready[i] = true
			continue
		estate._house_rules_ready[i] = false
		estate._house_rules_needed.append(i)
		var row := HBoxContainer.new()
		row.name = "RulesRow%d" % i
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(PlayerBadge.make(i, 16))
		var nm := Label.new()
		nm.text = GameState.PLAYER_NAMES[i]
		nm.add_theme_font_size_override("font_size", 17)
		nm.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(nm)
		var chip: Label = estate._make_ready_chip()
		chip.name = "RulesChip"
		chip.text = "PRESS A"
		chip.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		chip.modulate.a = 0.85
		row.add_child(chip)
		estate.phase_box.add_child(row)
	# Humans get time to actually READ the primer — 5s is the bots/auto cap,
	# not a reading deadline. A pressing A still advances immediately.
	if not estate._house_rules_needed.is_empty():
		estate._house_rules_countdown = 45.0
	var count := Label.new()
	count.name = "RulesCountdown"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 18)
	count.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	estate.phase_box.add_child(count)
	estate._refresh_house_rules_countdown()

static func all_house_rules_ready(estate) -> bool:
	for i in estate._house_rules_needed:
		if not estate._house_rules_ready.get(i, false):
			return false
	return true

static func refresh_house_rules_countdown(estate) -> void:
	var count: Node = estate.phase_box.get_node_or_null("RulesCountdown")
	if count == null or not count is Label:
		return
	var waiting: Array = []
	for i in estate._house_rules_needed:
		if not estate._house_rules_ready.get(i, false):
			waiting.append(GameState.PLAYER_NAMES[i])
	if waiting.is_empty():
		count.text = "the estate is satisfied — to the auction"
	else:
		count.text = "press A to continue  ·  waiting on %s  ·  the auction opens in %ds" % [
			", ".join(waiting), ceili(maxf(estate._house_rules_countdown, 0.0))]

static func poll_house_rules(estate, delta: float) -> void:
	estate._house_rules_countdown -= delta
	for i in estate._house_rules_needed:
		if not estate._house_rules_ready.get(i, false) and PlayerInput.just_pressed(i, "a"):
			estate._house_rules_ready[i] = true
			Sfx.play("confirm")
			var row: Node = estate.phase_box.get_node_or_null("RulesRow%d" % i)
			if row:
				var chip: Node = row.get_node_or_null("RulesChip")
				if chip and chip is Label:
					chip.text = "READY"
					chip.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
					chip.modulate.a = 1.0
	estate._refresh_house_rules_countdown()
	if estate._all_house_rules_ready() or estate._house_rules_countdown <= 0.0:
		estate._house_rules_active = false
		estate._enter_auction()

## ----- PRE-GAME GET READY CARD (night flow) -----

## The How-to card in a GET READY skin: goal + live per-seat controls, and each
## human presses their A to ready (chip flips green). Launches when every human
## is ready or after READY_GATE_TIME, whichever first. Feels like _show_howto.
## `minimal` (the double-gate collapse): the module's own IntroCard will show
## the goal/controls next, so the card shrinks to an "everyone in" sync —
## per-seat ready chips + countdown only. Same gate machinery either way.
static func show_get_ready(estate, modules: Dictionary, ready_gate_time: float, id: String, practice := false, minimal := false) -> void:
	estate._ready_gate_active = true
	estate._ready_gate_id = id
	estate._ready_gate_practice = practice
	estate._ready_gate_countdown = ready_gate_time
	estate._ready_gate_ready.clear()
	estate._ready_gate_needed.clear()
	Sfx.play("card")
	var info: Dictionary = modules[id]
	var how: Dictionary = HOWTO.get(id, {"goal": "?", "a": "A", "b": "B"})
	estate._clear_panel(("EVERYONE IN — %s" if minimal else "GET READY — %s") % String(info.name), Color(1, 0.9, 0.5))
	if not minimal:
		var goal := Label.new()
		goal.text = String(how.goal)
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.custom_minimum_size = Vector2(680, 0)
		goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		estate.phase_box.add_child(goal)
	var ctl_title := Label.new()
	ctl_title.text = "— press your A when you're in —" if minimal \
			else "— CONTROLS TONIGHT (press your A to ready) —"
	ctl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl_title.modulate.a = 0.7
	ctl_title.add_theme_font_size_override("font_size", 15)
	estate.phase_box.add_child(ctl_title)
	for i in EstateState.players.size():
		var row := HBoxContainer.new()
		row.name = "GateRow%d" % i
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(PlayerBadge.make(i, 16))
		var has_jump: bool = String(how.get("jump", "")) != ""
		if not minimal and not PlayerInput.is_bot(i) and not NetSession.is_seat_remote(i) and id != "par":
			_add_control_segment(row, i, "move", "", "")
			_add_control_segment(row, i, "a", "", "")
			_add_control_segment(row, i, "b", "", "")
			if has_jump:
				_add_control_segment(row, i, "jump", "", "")
		var l := Label.new()
		if PlayerInput.is_bot(i):
			l.text = "%s — bot, needs no manual" % GameState.PLAYER_NAMES[i]
			l.modulate.a = 0.5
		elif NetSession.is_seat_remote(i):
			l.text = "%s — REMOTE — readies from their own estate" % GameState.PLAYER_NAMES[i]
		elif minimal:
			l.text = GameState.PLAYER_NAMES[i]
		elif id == "par":
			l.text = "%s — MOUSE: aim, hold, release to putt (hotseat — pass it on)" % GameState.PLAYER_NAMES[i]
		else:
			l.text = "%s — MOVE %s  ·  %s: %s  ·  %s: %s" % [
				GameState.PLAYER_NAMES[i], PlayerInput.describe_binding(i, "move"),
				PlayerInput.describe_binding(i, "a"), String(how.a),
				PlayerInput.describe_binding(i, "b"), String(how.b)]
			if has_jump:
				l.text += "  ·  %s: %s" % [PlayerInput.describe_binding(i, "jump"), String(how.jump)]
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		row.add_child(l)
		# A human with a discrete A must press it; a shared/mouse seat (-3) has
		# none, so it counts as ready on arrival and the countdown covers it.
		if not PlayerInput.is_bot(i):
			var d := PlayerInput.device_of(i)
			if d == -3:
				estate._ready_gate_ready[i] = true
			else:
				estate._ready_gate_ready[i] = false
				estate._ready_gate_needed.append(i)
				var chip: Label = estate._make_ready_chip()
				chip.name = "GateChip"
				chip.text = "PRESS A"
				chip.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
				chip.modulate.a = 0.85
				row.add_child(chip)
		estate.phase_box.add_child(row)
	var count := Label.new()
	count.name = "GateCountdown"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 18)
	count.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	estate.phase_box.add_child(count)
	estate._refresh_ready_gate_countdown()

static func all_ready_gate(estate) -> bool:
	for i in estate._ready_gate_needed:
		if not estate._ready_gate_ready.get(i, false):
			return false
	return true

static func refresh_ready_gate_countdown(estate) -> void:
	var count: Node = estate.phase_box.get_node_or_null("GateCountdown")
	if count == null or not count is Label:
		return
	var waiting: Array = []
	for i in estate._ready_gate_needed:
		if not estate._ready_gate_ready.get(i, false):
			waiting.append(GameState.PLAYER_NAMES[i])
	if waiting.is_empty():
		count.text = "all ready — the estate begins"
	else:
		count.text = "waiting on %s  ·  begins in %ds" % [", ".join(waiting), ceili(maxf(estate._ready_gate_countdown, 0.0))]

static func poll_ready_gate(estate, delta: float) -> void:
	estate._ready_gate_countdown -= delta
	for i in estate._ready_gate_needed:
		if not estate._ready_gate_ready.get(i, false) and PlayerInput.just_pressed(i, "a"):
			estate._ready_gate_ready[i] = true
			Sfx.play("confirm")
			var row: Node = estate.phase_box.get_node_or_null("GateRow%d" % i)
			if row:
				var chip: Node = row.get_node_or_null("GateChip")
				if chip and chip is Label:
					chip.text = "READY"
					chip.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
					chip.modulate.a = 1.0
	estate._refresh_ready_gate_countdown()
	if estate._all_ready_gate() or estate._ready_gate_countdown <= 0.0:
		estate._ready_gate_active = false
		estate._do_launch_game(estate._ready_gate_id, estate._ready_gate_practice)
