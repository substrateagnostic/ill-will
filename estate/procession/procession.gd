extends Node3D
## THE PROCESSION — ILL WILL's flagship board night (doc 18 build spec, doc 13
## Approach A). One complete wake per session: putt your pawn round the manor
## drive, buy Deeds at the roving Codicil, inherit when the night's Deed goal
## hits. The wedge (doc 13 §A5): PARALLELISE the roll+move (no downtime),
## SERIALISE the reveal (the shared schadenfreude beat).
##
## Self-boots from the CLI via procession_boot.gd (--procession), OR is handed a
## roster by estate.gd at merge via begin(config) — see doc 19 for the snippet.
## Deterministic: every stochastic choice draws from `rng`, seeded by --seed, so
## the same seed twice yields an identical tally (the verification receipt).
##
## Online: _net_state()/_net_apply() ship the whole board as facts from day one;
## the host simulates, mirrors render truth. Putt intents are seat-attributed
## (pawn_putt.submit_remote_intent) — the thing Par-online still needs, solved
## here in new code.

const BoardPath := preload("res://estate/procession/board_path.gd")
const PawnPutt := preload("res://estate/procession/pawn_putt.gd")
const Codicil := preload("res://estate/procession/codicil.gd")
const Executor := preload("res://estate/procession/executor_host.gd")
const Spaces := ProcessionBoardSpaces
const Presets := ProcessionPresets

const CHAR_SCENES := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const REVEAL_BEAT := 2.2
const POINTS := [5, 3, 2, 1]        # RECKONING / will placement -> Grudge
const CONTRACT_POOL := ["echo", "tilt", "orbital", "mower", "greed", "swap",
	"deadweight", "throne", "lastwill"]
const MODULE_SCENES := {
	"echo": "res://minigames/echo_chamber/echo_chamber.tscn",
	"tilt": "res://minigames/tilt/tilt.tscn",
	"orbital": "res://minigames/orbital/orbital.tscn",
	"mower": "res://minigames/mower/mower.tscn",
	"greed": "res://minigames/greed/greed.tscn",
	"swap": "res://minigames/swap_meet/swap_meet.tscn",
	"deadweight": "res://minigames/dead_weight/dead_weight.tscn",
	"throne": "res://minigames/throne/throne.tscn",
	"lastwill": "res://minigames/last_will/last_will.tscn",
}

signal night_over(tally: Dictionary)

# ---- night state (the tally reads out of these) ----
var rng := RandomNumberGenerator.new()
var seed_value := 0
var roster: Array = []
var grudge: Array[int] = []
var deeds: Array[int] = []
var positions: Array[int] = []
var moved_total: Array[int] = []
var items: Array = []               # per seat: {pin,ribbon,salt} counts
var stats: Array = []               # per seat: will-clause stat dict
var round_num := 0
var deed_goal := 4
var movement_goal := 0
var decision_layer := true
var preset_id := "short"
var winner := -1
var _started := false
var _autoplay := false
var _fast := false
var _minisim := true
var _mirror := false
var _preset_explicit := false
var _phase := "boot"

# ---- nodes ----
var board: Node3D
var putt: Node
var codicil: Node
var executor: Node
var cam: Camera3D
var final_kit: Node
var _ui: CanvasLayer
var _reveal: RichTextLabel
var _announce: Label
var _round_lbl: Label
var _codicil_lbl: Label
var _chips: Array = []               # per seat: {badge, grudge_lbl, deeds_lbl}
var _cam_home := Vector3(0, 23, 23)

# ---- will clauses (announced at night start, paid at the reading) ----
var clauses: Array = []

func _ready() -> void:
	call_deferred("_autostart")

## estate.gd (merge path) calls this with a real roster BEFORE the deferred
## _autostart fires; the flag makes the two entry points mutually exclusive.
func begin(config: Dictionary) -> void:
	if _started:
		return
	_started = true
	_boot(config)

func _autostart() -> void:
	if _started:
		return
	_started = true
	_boot({})

# --------------------------------------------------------------------------
# BOOT
# --------------------------------------------------------------------------
func _boot(config: Dictionary) -> void:
	_parse_cli()
	_mirror = NetSession.is_client()
	if config.has("seed"):
		seed_value = int(config.seed)
	if config.has("deed_goal"):
		deed_goal = int(config.deed_goal)
	if config.has("preset"):
		preset_id = String(config.preset)
		_preset_explicit = true
	rng.seed = seed_value
	var preset := Presets.get_preset(preset_id) if _preset_explicit \
		else Presets.from_goal(deed_goal)
	decision_layer = bool(preset.get("decision_layer", true))
	movement_goal = int(preset.get("movement_goal", 0))
	if _preset_explicit and decision_layer:
		deed_goal = maxi(1, int(preset.get("deed_goal", deed_goal)))
	roster = config.get("roster", []) if config.has("roster") else _default_roster()
	_init_arrays()
	_build_world()
	_build_hud()
	_choose_clauses()
	print("PROCESSION boot seed=%d preset=%s deed_goal=%d players=%d autoplay=%s minisim=%s" % [
		seed_value, preset_id, deed_goal, roster.size(), str(_autoplay), str(_minisim)])
	_run_night()

func _parse_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--deedgoal="):
			deed_goal = clampi(int(arg.trim_prefix("--deedgoal=")), 1, 12)
		elif arg.begins_with("--preset="):
			preset_id = arg.trim_prefix("--preset=")
			_preset_explicit = true
		elif arg.begins_with("--autoplay="):
			_autoplay = true
			_fast = true
			_minisim = true
		elif arg == "--realmini":
			_minisim = false     # launch real modules even under autoplay
		elif arg == "--slowsim":
			_fast = false         # keep ceremonies at full length (for capture)

func _default_roster() -> Array:
	var out: Array = []
	for i in 4:
		var is_bot := _autoplay or PlayerInput.is_bot(i)
		out.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": CHAR_SCENES[i],
			"device": PlayerInput.device_of(i),
			"bot": is_bot,
		})
	return out

func _init_arrays() -> void:
	var n := roster.size()
	grudge.resize(n); deeds.resize(n); positions.resize(n); moved_total.resize(n)
	items.clear(); stats.clear()
	for i in n:
		grudge[i] = EstateState.STARTING_GRUDGE + 3   # a small float so turn 1 has stakes
		deeds[i] = 0
		positions[i] = 0
		moved_total[i] = 0
		items.append({"pin": 0, "ribbon": 0, "salt": 0})
		stats.append({"moved": 0, "graves": 0, "lost": 0, "duels": 0,
			"shrines": 0, "deeds_bought": 0, "spent": 0})

# --------------------------------------------------------------------------
# WORLD + HUD
# --------------------------------------------------------------------------
func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.34, 0.42)
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.07, 0.11)
	env.fog_density = 0.008
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, -38, 0)
	moon.light_energy = 0.85
	moon.light_color = Color(0.75, 0.8, 1.0)
	moon.shadow_enabled = true
	add_child(moon)

	board = BoardPath.new()
	add_child(board)
	board.build(roster, EstateState.monuments)

	codicil = Codicil.new()
	add_child(codicil)
	codicil.set_space(board.beacon_index)

	cam = Camera3D.new()
	cam.fov = 52.0
	cam.global_position = _cam_home
	add_child(cam)
	cam.look_at(board.CENTER, Vector3.UP)
	cam.current = true

	putt = PawnPutt.new()
	add_child(putt)

	executor = Executor.new()
	add_child(executor)

func _build_hud() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("separation", 18)
	top.offset_top = 12
	top.offset_left = 18
	top.offset_right = -18
	_ui.add_child(top)

	_round_lbl = _chip_label("ROUND 0", 30, Color(0.92, 0.9, 0.98))
	top.add_child(_round_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_codicil_lbl = _chip_label("CODICIL @ —", 30, Color(1, 0.88, 0.4))
	top.add_child(_codicil_lbl)

	var chiprow := HBoxContainer.new()
	chiprow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	chiprow.alignment = BoxContainer.ALIGNMENT_CENTER
	chiprow.add_theme_constant_override("separation", 22)
	chiprow.offset_bottom = -14
	_ui.add_child(chiprow)
	_chips.clear()
	for i in roster.size():
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.08, 0.9)
		sb.set_border_width_all(3)
		sb.border_color = roster[i].color
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		sb.content_margin_top = 6; sb.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var badge := PlayerBadge.make(i, 30)
		badge.color = roster[i].color
		row.add_child(badge)
		var col := VBoxContainer.new()
		row.add_child(col)
		var name_l := _chip_label(String(roster[i].name), 28, roster[i].color)
		col.add_child(name_l)
		var stat_l := _chip_label("2♠  ◆0", 30, Color(0.95, 0.95, 1.0))
		col.add_child(stat_l)
		chiprow.add_child(panel)
		_chips.append({"grudge": stat_l})

	_reveal = RichTextLabel.new()
	_reveal.bbcode_enabled = true
	_reveal.fit_content = true
	_reveal.scroll_active = false
	_reveal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reveal.custom_minimum_size = Vector2(1000, 120)
	_reveal.offset_left = -500; _reveal.offset_right = 500
	_reveal.offset_top = 150; _reveal.offset_bottom = 270
	_reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal.add_theme_font_size_override("normal_font_size", 40)
	_reveal.visible = false
	_ui.add_child(_reveal)

	_announce = Label.new()
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_announce.custom_minimum_size = Vector2(1100, 200)
	_announce.offset_left = -550; _announce.offset_right = 550
	_announce.offset_top = -120; _announce.offset_bottom = 120
	_announce.add_theme_font_size_override("font_size", 46)
	_announce.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_announce.add_theme_constant_override("outline_size", 10)
	_announce.visible = false
	_ui.add_child(_announce)

	# A dedicated full-rect Control hosts the four corner putt meters.
	var meter_host := Control.new()
	meter_host.name = "MeterHost"
	meter_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meter_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(meter_host)
	putt.configure(roster, meter_host, _mirror)

	executor.setup(_reveal, cam)
	# The endgame kit escalates music + light on the final Deed (juice floor).
	final_kit = FinalStretch.attach(self, null, {"ticks": false})
	_refresh_hud()

func _chip_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _refresh_hud() -> void:
	if _round_lbl:
		_round_lbl.text = "ROUND %d" % round_num
	if _codicil_lbl:
		_codicil_lbl.text = "CODICIL ◆ @ SPACE %d  (%d♠+%d/deed)" % [
			board.beacon_index, codicil.BASE_COST, codicil.COST_PER_DEED]
	for i in _chips.size():
		var extra := "  ×%d" % moved_total[i] if not decision_layer else ""
		_chips[i].grudge.text = "%d♠  ◆%d%s" % [grudge[i], deeds[i], extra]

func _announce_text(text: String, color := Color(0.95, 0.95, 1.0), hold := 2.0) -> void:
	if _announce == null:
		return
	_announce.text = text
	_announce.add_theme_color_override("font_color", color)
	_announce.visible = true

func _hide_announce() -> void:
	if _announce:
		_announce.visible = false

# --------------------------------------------------------------------------
# WILL CLAUSES (announced up front, paid at the reading — Pro Rules transparency)
# --------------------------------------------------------------------------
func _choose_clauses() -> void:
	clauses = [
		{"stat": "moved", "title": "THE LONGEST PROCESSION",
			"desc": "walked the most stones tonight"},
		{"stat": "lost", "title": "THE MOST BETRAYED",
			"desc": "bled the most Grudge to graves and tolls"},
		{"stat": "duels", "title": "THE BLOODIEST HAND",
			"desc": "won the most on the board — vendettas and claims"},
	]

# --------------------------------------------------------------------------
# THE NIGHT
# --------------------------------------------------------------------------
func _run_night() -> void:
	_phase = "intro"
	if final_kit and final_kit.has_method("play_started"):
		final_kit.play_started()
	await _intro()
	while true:
		round_num += 1
		_refresh_hud()
		await _round()
		if _check_win():
			break
		if round_num % 2 == 0:
			await _minigame_block()
			if _check_win():
				break
		if round_num % 3 == 0:
			await _house_awakens()
			if _check_win():
				break
		if round_num >= 60:
			break   # safety cap — a night must always end
	await _will_reading()
	await _heir_crowned()
	_emit_tally()

func _intro() -> void:
	Music.play_slot("grounds")
	_announce_text("THE PROCESSION\n%s" % Presets.get_preset(preset_id).get("label", "SHORT PROCESSION"),
		Color(1, 0.9, 0.5))
	executor.say(Executor.pick(Executor.GREETING, rng), Color(0.9, 0.88, 0.98))
	# A slow orbit of the whole drive so the table reads the board once.
	if not _fast:
		var tw := cam.create_tween()
		for a in range(0, 5):
			var ang := TAU * float(a) / 5.0
			var p := board.CENTER + Vector3(cos(ang) * 26.0, 22.0, sin(ang) * 26.0)
			tw.tween_property(cam, "global_position", p, 0.7)
		await tw.finished
		cam.global_position = _cam_home
		cam.look_at(board.CENTER, Vector3.UP)
	VerifyCapture.snap("flyover")
	# The clauses are read BEFORE a single putt — nothing hidden decides.
	var lines: Array[String] = []
	for c in clauses:
		lines.append("◆ %s — +1 Deed to whoever %s" % [c.title, c.desc])
	_announce_text("TONIGHT'S WILL CLAUSES\n\n" + "\n".join(lines), Color(0.85, 0.78, 1.0))
	VerifyCapture.snap("will_clause")
	await _beat(3.0)
	_hide_announce()
	executor.clear_banner()

func _round() -> void:
	_phase = "roll"
	_hide_announce()
	# --- ROLL: all live pawns putt at once (own corner meter). ---
	var targets := _bot_targets()
	putt.begin_roll(targets, rng)
	VerifyCapture.snap("putt_meters")
	var results: Array = await putt.all_released
	putt.end_roll_visuals()
	# spaces per seat, adjusted by held items (announced when spent).
	var moved: Array[int] = []
	moved.resize(roster.size())
	for i in roster.size():
		moved[i] = 1
	for r in results:
		var seat := int(r.seat)
		moved[seat] = int(r.spaces)
	_apply_item_movement(moved)

	# --- MOVE: every pawn travels at once; whole-board camera. ---
	_phase = "move"
	executor.reset_camera(_cam_home, board.CENTER, 0.35 if not _fast else 0.0)
	var tweens: Array = []
	for i in roster.size():
		_pay_passthrough_tolls(i, positions[i], moved[i])
		var tw: Tween = board.advance_pawn(i, positions[i], moved[i])
		tweens.append(tw)
		positions[i] = posmod(positions[i] + moved[i], BoardPath.SPACES)
		moved_total[i] += moved[i]
		stats[i].moved += moved[i]
	if not _fast:
		for tw in tweens:
			if tw and tw.is_valid():
				await tw.finished
	else:
		for i in roster.size():
			board.seat_pawn(i, positions[i])
	_push_net()

	# --- REVEAL: staggered Executor cascade, one landing at a time. ---
	_phase = "reveal"
	var order := _reveal_order(moved)
	for seat in order:
		await _reveal_landing(seat)
	executor.clear_banner()
	executor.reset_camera(_cam_home, board.CENTER, 0.4 if not _fast else 0.0)
	_refresh_hud()

## Bots aim for the highest-value reachable stone (1..6), Codicil first if
## affordable; a small seeded jitter keeps four bots from being identical.
func _bot_targets() -> Array[int]:
	var out: Array[int] = []
	out.resize(roster.size())
	for i in roster.size():
		if not bool(roster[i].bot):
			out[i] = 3
			continue
		var best_n := 1
		var best_v := -999.0
		for n in range(1, 7):
			var idx := posmod(positions[i] + n, BoardPath.SPACES)
			var v: float = Spaces.bot_value(board.type_at(idx))
			if board.is_codicil_here(idx) and grudge[i] >= codicil.price_for(deeds[i]):
				v = Spaces.bot_value(Spaces.CODICIL)
			v += rng.randf_range(-0.6, 0.6)
			if v > best_v:
				best_v = v
				best_n = n
		out[i] = best_n
	return out

func _apply_item_movement(moved: Array[int]) -> void:
	for i in roster.size():
		if items[i].pin > 0:
			items[i].pin -= 1
			moved[i] += 1
			_flash_line("%s spends a MOURNING PIN (+1 space)" % roster[i].name, roster[i].color)
		if items[i].ribbon > 0:
			items[i].ribbon -= 1
			moved[i] = maxi(1, moved[i] - 1)
			_flash_line("%s is dragged by a BLACK RIBBON (−1 space)" % roster[i].name, roster[i].color)

func _pay_passthrough_tolls(seat: int, from_idx: int, moved: int) -> void:
	for step in range(1, moved):   # intermediate spaces only; landing handled in reveal
		var idx := posmod(from_idx + step, BoardPath.SPACES)
		if board.type_at(idx) == Spaces.TOLLGATE:
			var owner := board.tollgate_owner(idx)
			if owner >= 0 and owner != seat:
				var pay := mini(2, grudge[seat])
				grudge[seat] -= pay
				grudge[owner] += pay
				stats[seat].lost += pay

func _reveal_order(moved: Array[int]) -> Array:
	var order: Array = []
	for i in roster.size():
		order.append(i)
	order.sort_custom(func(a, b):
		if moved[a] != moved[b]:
			return moved[a] < moved[b]
		return a < b)
	return order

func _reveal_landing(seat: int) -> void:
	var idx := positions[seat]
	if not _fast:
		executor.push_to(board.reveal_anchor(idx), board.pawns[seat].global_position)
	var col: Color = roster[seat].color
	var name := String(roster[seat].name)
	if board.is_codicil_here(idx):
		_resolve_codicil(seat)
	else:
		match board.type_at(idx):
			Spaces.SHRINE: _resolve_shrine(seat, name, col)
			Spaces.WEEPING_GRAVE: _resolve_grave(seat, name, col)
			Spaces.STALL: _resolve_stall(seat, name, col)
			Spaces.SEANCE: _resolve_seance(seat, name, col)
			Spaces.TOLLGATE: _resolve_tollgate(seat, name, col)
			Spaces.VENDETTA: _resolve_vendetta(seat, name, col)
			_: executor.say(Executor.pick(Executor.BLANK, rng, [name]), col)
	_refresh_hud()
	_push_net()
	VerifyCapture.snap("reveal")
	await _beat(REVEAL_BEAT)

# ---- per-space resolutions ----
func _resolve_shrine(seat: int, name: String, col: Color) -> void:
	grudge[seat] += 3
	stats[seat].shrines += 1
	Sfx.play("grudge", -4.0)
	executor.say(Executor.pick(Executor.SHRINE, rng, [name]), col)

func _resolve_grave(seat: int, name: String, col: Color) -> void:
	if items[seat].salt > 0:
		items[seat].salt -= 1
		executor.say("%s salts the grave — the loss is cancelled." % name, col)
		return
	var owner := board.grave_owner(positions[seat])
	stats[seat].graves += 1
	if owner >= 0 and owner != seat:
		var toll := mini(2, grudge[seat])
		grudge[seat] -= toll
		grudge[owner] += toll
		stats[seat].lost += toll
		stats[owner].duels += 1
		executor.say(Executor.pick(Executor.GRAVE_TOLL, rng,
			[name, roster[owner].name, roster[owner].name, toll]), col)
	else:
		var loss := mini(2, grudge[seat])
		grudge[seat] -= loss
		stats[seat].lost += loss
		executor.say(Executor.pick(Executor.GRAVE, rng, [name]), col)

func _resolve_stall(seat: int, name: String, col: Color) -> void:
	var pool := Spaces.ITEMS
	var item: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	match String(item.id):
		"mourning_pin": items[seat].pin += 1
		"grave_salt": items[seat].salt += 1
		"black_ribbon":
			items[seat].ribbon += 0   # ribbon is aimed at the leader, not self
			var leader := _deed_leader(seat)
			if leader >= 0:
				items[leader].ribbon += 1
	Sfx.play("card", -6.0)
	executor.say(Executor.pick(Executor.STALL, rng, [name]) + "  (%s)" % item.name, col)

func _resolve_seance(seat: int, name: String, col: Color) -> void:
	var slot := rng.randi_range(0, Spaces.SEANCE_WHEEL.size() - 1)
	var w: Dictionary = Spaces.SEANCE_WHEEL[slot]
	Sfx.play("bumper", -6.0)
	match slot:
		0:  # MERCIFUL DRAFT — every mourner +2
			for i in roster.size():
				grudge[i] += 2
		1:  # EQUAL SHARES — deed leader pays each rival 1
			var lead := _deed_leader(-1)
			if lead >= 0:
				for i in roster.size():
					if i != lead:
						var t := mini(1, grudge[lead])
						grudge[lead] -= t
						grudge[i] += t
		2:  # ROAD LEVY — flavour: everyone +1 (pots are abstracted)
			for i in roster.size():
				grudge[i] += 1
		3:  # FAVORED MEDIUM — the medium +4, all others +1
			for i in roster.size():
				grudge[i] += 4 if i == seat else 1
	executor.say(Executor.pick(Executor.SEANCE, rng) + "  [%s — %s]" % [w.title, w.rule],
		Color(0.78, 0.6, 0.95))

func _resolve_tollgate(seat: int, name: String, col: Color) -> void:
	board.set_tollgate_owner(positions[seat], seat)
	grudge[seat] += 2   # the collected pot (abstracted)
	stats[seat].duels += 1
	Sfx.play("sink", -4.0)
	executor.say(Executor.pick(Executor.TOLLGATE_TAKE, rng, [name]), col)

func _resolve_vendetta(seat: int, name: String, col: Color) -> void:
	var nemesis := _nearest_within(seat, 5)
	if nemesis < 0:
		executor.say("%s reaches the vendetta stone alone. No blood today." % name, col)
		return
	var s_a := _stake_for(seat)
	var s_b := _stake_for(nemesis)
	executor.say(Executor.pick(Executor.VENDETTA, rng, [name, roster[nemesis].name]), col)
	# sealed stakes resolve visibly: higher stake takes the difference.
	var win := seat if s_a >= s_b else nemesis
	var lose := nemesis if win == seat else seat
	var low := mini(s_a, s_b)
	if s_a == s_b:
		executor.say("%s and %s stake %d each — a wash. The estate is disappointed." % [
			name, roster[nemesis].name, s_a], col)
		return
	var moved_g := mini(low + 1, grudge[lose])
	grudge[lose] -= moved_g
	grudge[win] += moved_g
	stats[win].duels += 1
	stats[lose].lost += moved_g
	executor.say(Executor.pick(Executor.VENDETTA_RESULT, rng, [roster[win].name, roster[lose].name]) \
		+ "  (%d♠, stakes %d vs %d)" % [moved_g, s_a, s_b], roster[win].color)

func _resolve_codicil(seat: int) -> void:
	var name := String(roster[seat].name)
	var col: Color = roster[seat].color
	var price := codicil.price_for(deeds[seat])
	if grudge[seat] >= price:
		grudge[seat] -= price
		deeds[seat] += 1
		stats[seat].deeds_bought += 1
		stats[seat].spent += price
		Sfx.play("match_win", -6.0)
		executor.say(Executor.pick(Executor.CODICIL, rng, [name]) + "  (−%d♠ → ◆%d)" % [price, deeds[seat]], col)
		var new_idx := codicil.choose_relocation(rng, BoardPath.SPACES)
		board.set_beacon(new_idx)
		if final_kit and deeds[seat] >= deed_goal - 1 and decision_layer:
			final_kit.escalate()
	else:
		executor.say(Executor.pick(Executor.CODICIL_SHORT, rng, [name]) + "  (needs %d♠)" % price, col)

# ---- helpers ----
func _nearest_within(seat: int, reach: int) -> int:
	var best := -1
	var best_d := reach + 1
	for j in roster.size():
		if j == seat:
			continue
		var d := _ring_dist(positions[seat], positions[j])
		if d <= reach and d < best_d:
			best_d = d
			best = j
	return best

func _ring_dist(a: int, b: int) -> int:
	var raw: int = abs(a - b)
	return mini(raw, BoardPath.SPACES - raw)

func _stake_for(seat: int) -> int:
	if bool(roster[seat].bot):
		return clampi(rng.randi_range(0, 3), 0, grudge[seat])
	return clampi(rng.randi_range(0, 3), 0, grudge[seat])

func _deed_leader(exclude: int) -> int:
	var lead := -1
	for i in roster.size():
		if i == exclude:
			continue
		if lead < 0 or deeds[i] > deeds[lead] or (deeds[i] == deeds[lead] and grudge[i] > grudge[lead]):
			lead = i
	return lead

func _flash_line(text: String, col: Color) -> void:
	if _reveal:
		executor.say(text, col)

# --------------------------------------------------------------------------
# MINIGAME BLOCK  (every 2nd round)
# --------------------------------------------------------------------------
func _minigame_block() -> void:
	_phase = "minigame"
	executor.clear_banner()
	# item offer — a quick shop beat: each seat is handed a random stall item.
	for i in roster.size():
		var it: Dictionary = Spaces.ITEMS[rng.randi_range(0, Spaces.ITEMS.size() - 1)]
		match String(it.id):
			"mourning_pin": items[i].pin += 1
			"grave_salt": items[i].salt += 1
			"black_ribbon":
				var lead := _deed_leader(i)
				if lead >= 0: items[lead].ribbon += 1
	var mid := CONTRACT_POOL[rng.randi_range(0, CONTRACT_POOL.size() - 1)]
	_announce_text("THE WAKE PAUSES FOR A GAME\n%s" % mid.to_upper(), Color(0.8, 0.9, 1.0))
	await _beat(1.6)
	_hide_announce()
	var placements: Array = await _run_minigame(mid)
	# RECKONING — placements pay 5/3/2/1 Grudge (and movement in QUICK WAKE).
	_phase = "reckoning"
	var lines: Array[String] = []
	for rank in placements.size():
		var p := int(placements[rank])
		var pay := POINTS[rank] if rank < POINTS.size() else 0
		grudge[p] += pay
		if not decision_layer:
			var adv := POINTS[rank] if rank < POINTS.size() else 0
			moved_total[p] += adv
			positions[p] = posmod(positions[p] + adv, BoardPath.SPACES)
			board.seat_pawn(p, positions[p])
		lines.append("%s  #%d  +%d♠" % [roster[p].name, rank + 1, pay])
	_announce_text("THE RECKONING\n\n" + "\n".join(lines), Color(0.95, 0.85, 0.6))
	_refresh_hud()
	await _beat(2.4)
	_hide_announce()

## The real module contract, reused from inside the board (spec §3). Under
## --autoplay the deterministic MINISIM stands in so the full night resolves
## fast and byte-identically; --realmini forces the live module.
func _run_minigame(id: String) -> Array:
	if _minisim or not MODULE_SCENES.has(id):
		return _sim_placements()
	var scene: PackedScene = load(MODULE_SCENES[id])
	if scene == null:
		return _sim_placements()
	var module: Node = scene.instantiate()
	board.visible = false
	cam.current = false
	_ui.visible = false
	add_child(module)
	_mini_done = false
	_mini_out = []
	module.finished.connect(_on_mini_finished, CONNECT_ONE_SHOT)
	var mroster: Array = []
	for pl in roster:
		mroster.append({"index": pl.index, "name": pl.name, "color": pl.color,
			"char_scene": pl.char_scene, "device": pl.device, "bot": pl.bot})
	module.begin({"roster": mroster, "rounds": 2, "rng_seed": rng.randi(), "practice": false})
	while not _mini_done:
		await get_tree().process_frame
	if is_instance_valid(module):
		module.queue_free()
	board.visible = true
	cam.current = true
	_ui.visible = true
	if _mini_out.size() != roster.size():
		return _sim_placements()
	return _mini_out

var _mini_done := false
var _mini_out: Array = []

func _on_mini_finished(results: Dictionary) -> void:
	_mini_out = results.get("placements", [])
	_mini_done = true

func _sim_placements() -> Array:
	var order: Array = []
	for i in roster.size():
		order.append(i)
	# Fisher-Yates with the seeded stream — deterministic, unbiased.
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]; order[i] = order[j]; order[j] = t
	return order

# --------------------------------------------------------------------------
# THE HOUSE AWAKENS  (every 3rd round — all-in survivathon)
# --------------------------------------------------------------------------
func _house_awakens() -> void:
	_phase = "house"
	executor.clear_banner()
	_announce_text("THE HOUSE AWAKENS\n\n" + Executor.pick(Executor.HOUSE_AWAKENS, rng),
		Color(1, 0.4, 0.35))
	if final_kit:
		final_kit.escalate()
	await _beat(2.4)
	# Safe stones: a seeded third of the ring. Each pawn "putts" for safety;
	# those who miss slip back 2 (announced, all-in).
	var safe := {}
	for k in 8:
		safe[rng.randi_range(0, BoardPath.SPACES - 1)] = true
	var caught: Array[String] = []
	for i in roster.size():
		var reached := rng.randf() < (0.45 + 0.1 * float(deeds[i] == 0))
		if not reached and not safe.has(positions[i]):
			positions[i] = posmod(positions[i] - 2, BoardPath.SPACES)
			board.seat_pawn(i, positions[i])
			caught.append(String(roster[i].name))
			stats[i].lost += 1
	if caught.is_empty():
		_announce_text("THE HOUSE AWAKENS\n\nEveryone reaches a safe stone. The house sulks.",
			Color(0.7, 0.85, 1.0))
	else:
		_announce_text("THE HOUSE AWAKENS\n\n" + ", ".join(caught) + " slip back two stones.",
			Color(1, 0.55, 0.4))
	_refresh_hud()
	_push_net()
	await _beat(2.2)
	_hide_announce()
	if final_kit and final_kit.has_method("round_reset"):
		final_kit.round_reset()

# --------------------------------------------------------------------------
# WIN CHECK + CEREMONIES
# --------------------------------------------------------------------------
func _check_win() -> bool:
	if decision_layer:
		for i in roster.size():
			if deeds[i] >= deed_goal:
				return true
		return false
	for i in roster.size():
		if moved_total[i] >= movement_goal:
			return true
	return false

func _will_reading() -> void:
	_phase = "will"
	executor.clear_banner()
	Music.play_slot("ceremony")
	executor.say(Executor.pick(Executor.WILL_OPEN, rng), Color(0.85, 0.75, 1.0))
	var lines: Array[String] = []
	for c in clauses:
		var winner_seat := _stat_leader(String(c.stat))
		if winner_seat >= 0:
			deeds[winner_seat] += 1
			stats[winner_seat].will_bonus = int(stats[winner_seat].get("will_bonus", 0)) + 1
			lines.append("%s — %s (%s)  +1 Deed → ◆%d" % [
				c.title, roster[winner_seat].name, c.desc, deeds[winner_seat]])
		else:
			lines.append("%s — unclaimed. The estate keeps the Deed." % c.title)
	_announce_text("THE READING OF THE WILL\n\n" + "\n".join(lines), Color(0.85, 0.78, 1.0))
	_refresh_hud()
	VerifyCapture.snap("will_reading")
	await _beat(3.4)
	_hide_announce()

func _stat_leader(key: String) -> int:
	var best := -1
	for i in roster.size():
		var v := int(stats[i].get(key, 0))
		if v > 0 and (best < 0 or v > int(stats[best].get(key, 0))):
			best = i
	return best

func _heir_crowned() -> void:
	_phase = "heir"
	winner = _final_winner()
	# The heir is written to the estate as a permanent monument (kind="heir").
	var pl: Dictionary = roster[winner]
	EstateState.monuments.append({
		"owner": String(pl.name),
		"color": Color(pl.color).to_html(),
		"label": "%s — HEIR OF THE PROCESSION (◆%d, seed %d)" % [pl.name, deeds[winner], seed_value],
		"night": EstateState.nights_played,
		"kind": "heir",
	})
	EstateState.add_graffiti("%s inherited the manor at the procession" % pl.name)
	EstateState.save_estate()
	Music.play_slot("ceremony")
	var podium := Podium.new()
	add_child(podium)
	var order := _final_order()
	var entries: Array = []
	for rank in order.size():
		var p := int(order[rank])
		entries.append({"name": roster[p].name, "color": roster[p].color, "rank": rank,
			"char_scene": load(CHAR_SCENES[p % CHAR_SCENES.size()]), "player": p})
	_ui.visible = false
	podium.stage_entries(entries)
	_announce_text("%s IS CROWNED HEIR\n◆%d DEEDS · SEED %d" % [pl.name, deeds[winner], seed_value],
		Color(pl.color))
	_announce.visible = true
	VerifyCapture.snap("heir_crowned")
	await _beat(4.0 if not _fast else 0.2)
	if is_instance_valid(podium):
		podium.queue_free()
	_ui.visible = true

func _final_winner() -> int:
	return int(_final_order()[0])

func _final_order() -> Array:
	var order: Array = []
	for i in roster.size():
		order.append(i)
	order.sort_custom(func(a, b):
		if decision_layer and deeds[a] != deeds[b]:
			return deeds[a] > deeds[b]
		if not decision_layer and moved_total[a] != moved_total[b]:
			return moved_total[a] > moved_total[b]
		if grudge[a] != grudge[b]:
			return grudge[a] > grudge[b]
		return a < b)
	return order

func _emit_tally() -> void:
	var tally := {
		"seed": seed_value, "preset": preset_id, "rounds": round_num,
		"deed_goal": deed_goal, "heir": winner, "heir_name": String(roster[winner].name),
		"grudge": grudge.duplicate(), "deeds": deeds.duplicate(),
		"moved": moved_total.duplicate(), "positions": positions.duplicate(),
	}
	print("PROCESSION_TALLY ", JSON.stringify(tally))
	for i in roster.size():
		print("  seat %d %s: ◆%d  %d♠  moved=%d  pos=%d" % [
			i, roster[i].name, deeds[i], grudge[i], moved_total[i], positions[i]])
	print("PROCESSION_HEIR %s (seed %d, %d rounds)" % [roster[winner].name, seed_value, round_num])
	night_over.emit(tally)
	if _autoplay:
		await _beat(0.3)
		get_tree().quit()

# --------------------------------------------------------------------------
# BEAT — skippable/fast ceremony wait. Fast (autoplay) collapses to one frame
# so the headless soak stays deterministic (frame-based) AND quick.
# --------------------------------------------------------------------------
func _beat(seconds: float) -> void:
	if _fast:
		await get_tree().process_frame
		return
	var t := 0.0
	while t < seconds:
		# All-players-press-A skips any ceremony but the win reveal (spec).
		if _phase != "heir" and _all_press_skip():
			return
		await get_tree().process_frame
		t += get_process_delta_time()

func _all_press_skip() -> bool:
	var humans := 0
	var pressing := 0
	for i in roster.size():
		if not bool(roster[i].bot):
			humans += 1
			if PlayerInput.just_pressed(i, "a"):
				pressing += 1
	return humans > 0 and pressing >= humans

# --------------------------------------------------------------------------
# NET MIRROR (from day one). Host simulates; a client renders _net_apply only.
# --------------------------------------------------------------------------
func _push_net() -> void:
	# The estate shell owns the 20 Hz pump at merge; this hook keeps the local
	# HUD authoritative and gives the pump a coherent snapshot to fan out.
	pass

func _net_state() -> Dictionary:
	return {
		"phase": _phase, "round": round_num, "beacon": board.beacon_index if board else 0,
		"grudge": grudge.duplicate(), "deeds": deeds.duplicate(),
		"positions": positions.duplicate(), "moved": moved_total.duplicate(),
		"banner": _reveal.get_parsed_text() if _reveal and _reveal.visible else "",
	}

func _net_apply(state: Dictionary) -> void:
	_phase = String(state.get("phase", _phase))
	round_num = int(state.get("round", round_num))
	grudge.assign(state.get("grudge", grudge))
	deeds.assign(state.get("deeds", deeds))
	positions.assign(state.get("positions", positions))
	moved_total.assign(state.get("moved", moved_total))
	if board:
		board.set_beacon(int(state.get("beacon", board.beacon_index)))
		for i in mini(positions.size(), roster.size()):
			board.seat_pawn(i, positions[i])
	_refresh_hud()
	var banner_text := String(state.get("banner", ""))
	if _reveal:
		if banner_text.is_empty():
			_reveal.visible = false
		else:
			executor.say(banner_text, Color.WHITE)
