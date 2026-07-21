class_name HowtoCards
extends RefCounted

## How-to-Play cards (UFO 50 pattern): goal + LIVE controls per seat via
## PlayerInput.describe_binding — the card can't lie about bindings. The GOAL prose
## now lives in dialog.json ("howto.goals.<id>") so Alex can rewrite it in one file;
## this dict keeps only the per-seat control labels (a/b/jump), which mirror the
## button legend and are not prose. goal_for(id) fetches the live goal line.
const HOWTO := {
	"par": {"a": "", "b": ""},
	"echo": {"a": "STRIKE", "b": "DASH (hold: PARRY)", "jump": "HOP (cosmetic — just for kicks)"},
	"tilt": {"a": "SHOVE (answer to CLASH)", "b": "BRACE"},
	"orbital": {"a": "hold: AIM+THROW / tap: CATCH", "b": "JUMP the gap"},
	"mower": {"a": "RAM HORN", "b": "BOOST (wider cut)"},
	"greed": {"a": "GRAB / TACKLE", "b": "DASH", "jump": "HOP (cosmetic — just for kicks)"},
	"swap": {"a": "THROW SWAP ORB", "b": "hold: DRIFT, release: BOOST"},
	"deadweight": {"a": "SHOVE", "b": "HOP"},
	"throne": {"a": "SHOVE / DECREE", "b": "DASH / GUARD", "jump": "HOP (cosmetic — just for kicks)"},
	"lastwill": {"a": "SHOVE", "b": "HOP"},
	"widowsgaze": {"a": "GRAB / BANK (hold)", "b": "SHOVE"},
	"seance": {"a": "CHANT ON THE PULSE", "b": "SURGE (anonymous)"},
	"understudy": {"a": "COMMIT (move = choose)", "b": "—"},
	"maskedball": {"a": "CURTSY (scores in the circle)", "b": "UNMASK (one mark)"},
	"pallbearers": {"a": "RESTUFF (mash on a drop)", "b": "", "jump": "HOP / HEAVE (both = clear mud)"},  # B7-HOOK
}

## The live goal line for a how-to card, from dialog.json.
static func goal_for(id: String) -> String:
	return Dialog.text("howto.goals." + id)

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
		if not ResourceLoader.exists(String(info.scene)):
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
	goal.text = goal_for(id)
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
			l.text = "%s — plays itself; needs no manual" % GameState.PLAYER_NAMES[i]
			l.modulate.a = 0.5
		elif NetSession.is_seat_remote(i):
			l.text = "%s — attends from a distant house" % GameState.PLAYER_NAMES[i]
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
		estate._launch_game(id))
	btns.add_child(play)
	if id != "par":
		var prac := Button.new()
		prac.custom_minimum_size = Vector2(200, 54)
		prac.text = "PRACTICE (no stakes)"
		prac.pressed.connect(func():
			estate._launch_game(id, true))
		btns.add_child(prac)
	var back := Button.new()
	back.custom_minimum_size = Vector2(120, 54)
	back.text = "BACK"
	back.pressed.connect(Callable(estate, "_enter_selector"))
	btns.add_child(back)
	estate.phase_box.add_child(btns)
