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
const Spaces := preload("res://estate/procession/board_spaces.gd")
const Presets := preload("res://estate/procession/presets.gd")
const BoardCamera := preload("res://estate/procession/board_camera.gd")
const BoardFx := preload("res://estate/procession/board_fx.gd")
const SeanceWheelScene := preload("res://estate/procession/seance_wheel.gd")
const MinigameRouletteScene := preload("res://estate/procession/minigame_roulette.gd")

const CHAR_SCENES := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const REVEAL_BEAT := 2.2
# F24 reveal-cascade reactions: waiting-player button -> attributed glyph.
const REACT_COOLDOWN_MS := 550
const REACT_MAP := {"b": "HA!", "up": "OOH", "down": "OOF"}
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
var _capture := false            # windowed: pose beats + snap for screenshots
var _phase := "boot"
var _round_codicil_seat := -1   # who claims the Codicil this round (pass-or-land)
var _preview_active := false    # F29: live putt target reticles during the roll
var _react_last: Array[int] = []   # F24: per-seat last-reaction wall-clock (cooldown)
var _reacted_demo := false         # F24: capture fires the reaction demo once

# ---- nodes ---- (concrete types so method returns infer without annotation)
var board: ProcessionBoardPath
var putt: ProcessionPawnPutt
var codicil: ProcessionCodicil
var executor: ProcessionExecutor
var cam: Camera3D
var board_camera: ProcessionCamera    # F1: the named-shot camera director
var fx: ProcessionFx                  # F10/F11/F17: flying numbers + the Deed token
var _fx_host: Control
var seance_wheel: SeanceWheel         # F13: the visible four-slot planchette dial
var roulette: MinigameRoulette        # F22: the pre-minigame card-shuffle roulette
var final_kit: Node
var _ui: CanvasLayer
var _topbar: Control
var _chiprow: Control
var _reveal: RichTextLabel
var _lowerthird: PanelContainer         # dark scrim housing the reveal line
var _reveal_badge: PlayerBadge          # affected-player portrait in the lower-third
var _reveal_seat := -1                  # seat the current reveal line is about (-1 = none)
var _announce: Label
var _announce_scrim: Control            # dark band behind the centre ceremony cards
var _round_lbl: Label
var _codicil_lbl: Label
var _chips: Array = []               # per seat: {badge, grudge_lbl, deeds_lbl}
var _cam_home := Vector3(0, 23, 23)

# Lower-third geometry (anchored bottom-centre; slides up on show).
const LT_HALF_W := 620.0
const LT_REST_TOP := -338.0
const LT_REST_BOTTOM := -196.0
const LT_SLIDE := 34.0

# ---- will clauses (announced at night start, paid at the reading) ----
var clauses: Array = []

func _ready() -> void:
	call_deferred("_autostart")

## F29: while the roll is live, paint each charging seat's projected landing stone
## with a seat-coloured reticle + rule tooltip, so steering at a space is a real
## decision. Presentation only; inert under the fast soak and outside the roll.
func _process(_delta: float) -> void:
	if _fast or not _preview_active or putt == null or board == null:
		return
	for i in roster.size():
		var sp := putt.preview_spaces(i)
		if sp > 0:
			var dest := posmod(positions[i] + sp, BoardPath.SPACES)
			board.set_putt_preview(i, dest, roster[i].color)
		else:
			board.clear_putt_preview(i)

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
	_capture = _autoplay and DisplayServer.get_name() != "headless"
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
	# The soak compresses real time: pawn_putt is frame/tick-based, so a higher
	# time_scale changes only how fast the same ticks elapse — the tally stays
	# byte-identical. Interactive/windowed play runs at 1.0.
	if _autoplay and _fast:
		Engine.time_scale = 8.0
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
	_react_last.resize(n)
	for i in n:
		_react_last[i] = -100000
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
	# THE HOUSE LOOK, as code — the shared MOONLIT rig (cool night key, warm fill,
	# ground fog, AGX tonemap, bloom-on-emissives). Overrides lift the ambient a
	# touch and add a faint cool rim so four pawn colours + eight space types all
	# parse at couch distance under the dark. (core/env_kit.gd owns the preset.)
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"ambient_energy": 0.52,
		"key_energy": 1.15,
		"rim_energy": 0.32,
		"rim_color": Color(0.55, 0.68, 1.0),
		"fog_density": 0.010,
		"glow_intensity": 0.85,
	})

	board = BoardPath.new()
	add_child(board)
	# The soak ignores the persistent monument set so the receipt is independent
	# of whatever the user's save happens to hold; real play reads the estate.
	board.build(roster, [] if _autoplay else EstateState.monuments)

	codicil = Codicil.new()
	add_child(codicil)
	codicil.set_space(board.beacon_index)

	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.global_position = _cam_home
	cam.look_at(board.CENTER, Vector3.UP)
	cam.current = true

	# The camera director owns the named-shot spine (F1/F2/F3). It stays inert
	# under the fast soak (no rendering) and only drives the cam once activated.
	board_camera = BoardCamera.new()
	add_child(board_camera)
	board_camera.setup(cam, board, _fast)

	putt = PawnPutt.new()
	add_child(putt)

	executor = Executor.new()
	add_child(executor)

func _build_hud() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)

	# Top status bar rides on a dark scrim so ROUND / CODICIL read over any
	# scenery (≥30px @1080p, well over the 26px floor).
	var top_panel := PanelContainer.new()
	top_panel.name = "TopBar"
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_top = 10
	top_panel.offset_left = 14
	top_panel.offset_right = -14
	top_panel.add_theme_stylebox_override("panel", _scrim_box(Color(0.04, 0.045, 0.07, 0.82)))
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top_panel)
	_topbar = top_panel

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	top_panel.add_child(top)

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
	_chiprow = chiprow
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
		_chips.append({"grudge": stat_l, "panel": panel})

	# ---- REVEAL lower-third: a broadcast-style band pinned bottom-centre, with a
	# dark translucent scrim + gold rule, the affected player's PlayerBadge, and
	# the Executor's line set in the anthology's heaviest face. Slides up 0.25s.
	_lowerthird = PanelContainer.new()
	_lowerthird.name = "LowerThird"
	_lowerthird.anchor_left = 0.5; _lowerthird.anchor_right = 0.5
	_lowerthird.anchor_top = 1.0; _lowerthird.anchor_bottom = 1.0
	_lowerthird.offset_left = -LT_HALF_W; _lowerthird.offset_right = LT_HALF_W
	_lowerthird.offset_top = LT_REST_TOP; _lowerthird.offset_bottom = LT_REST_BOTTOM
	_lowerthird.add_theme_stylebox_override("panel", _lowerthird_box())
	_lowerthird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lowerthird.modulate.a = 0.0
	_lowerthird.visible = false
	_ui.add_child(_lowerthird)
	var lt_margin := MarginContainer.new()
	lt_margin.add_theme_constant_override("margin_left", 26)
	lt_margin.add_theme_constant_override("margin_right", 26)
	lt_margin.add_theme_constant_override("margin_top", 14)
	lt_margin.add_theme_constant_override("margin_bottom", 14)
	_lowerthird.add_child(lt_margin)
	var lt_row := HBoxContainer.new()
	lt_row.add_theme_constant_override("separation", 20)
	lt_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	lt_margin.add_child(lt_row)
	_reveal_badge = PlayerBadge.make(0, 62)
	_reveal_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reveal_badge.visible = false
	lt_row.add_child(_reveal_badge)

	_reveal = RichTextLabel.new()
	_reveal.bbcode_enabled = true
	_reveal.fit_content = true
	_reveal.scroll_active = false
	_reveal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal.custom_minimum_size = Vector2(LT_HALF_W * 2.0 - 150.0, 96)
	_reveal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reveal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_reveal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# No serif ships in the project; Baloo2 is its heaviest, most formal face —
	# the closest to a will-reading register available. (Follow-up: add a gothic
	# serif TTF for the Executor's proclamations.)
	var serif: FontFile = load("res://assets/fonts/Baloo2.ttf")
	if serif != null:
		_reveal.add_theme_font_override("normal_font", serif)
		_reveal.add_theme_font_override("bold_font", serif)
	_reveal.add_theme_font_size_override("normal_font_size", 34)
	_reveal.add_theme_color_override("default_color", Color(0.96, 0.94, 0.88))
	_reveal.visible = false
	lt_row.add_child(_reveal)
	_reveal.visibility_changed.connect(_on_reveal_vis_changed)

	# A soft dark band behind the centre ceremony cards (clauses, reckoning, house,
	# crown) so their text never fights bright scenery. Toggled with _announce.
	_announce_scrim = PanelContainer.new()
	_announce_scrim.name = "AnnounceScrim"
	_announce_scrim.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_announce_scrim.offset_left = -620; _announce_scrim.offset_right = 620
	_announce_scrim.offset_top = -180; _announce_scrim.offset_bottom = 180
	_announce_scrim.add_theme_stylebox_override("panel", _scrim_box(Color(0.03, 0.03, 0.05, 0.72)))
	_announce_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_scrim.visible = false
	_ui.add_child(_announce_scrim)

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

	# The FX layer rides ABOVE the chips so flying numbers + the Deed token land
	# on the HUD (F10/F11/F17). A full-rect, input-transparent Control.
	_fx_host = Control.new()
	_fx_host.name = "FxHost"
	_fx_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fx_host)
	fx = BoardFx.new()
	add_child(fx)
	fx.setup(_fx_host, cam, _fast)

	# The séance dial (F13) — a visible four-slot wheel that spins to the sim's
	# pre-decided slot. Titles come straight from the announced grammar.
	var wheel_titles: Array = []
	for slot in Spaces.SEANCE_WHEEL:
		wheel_titles.append(String((slot as Dictionary).title))
	seance_wheel = SeanceWheelScene.new()
	seance_wheel.setup(_fx_host, wheel_titles, _fast)

	# The minigame roulette (F22) — a card-shuffle that lands on the chosen game.
	roulette = MinigameRouletteScene.new()
	roulette.setup(_fx_host)

	executor.setup(_reveal, cam)
	# The endgame kit escalates music + light on the final Deed (juice floor).
	final_kit = FinalStretch.attach(self, null, {"ticks": false})
	_refresh_hud()

## The world point a flying number lifts off from — above the seat's pawn if it
## exists, else the stone it stands on (F10/F11).
func _pawn_src(seat: int) -> Vector3:
	if board != null and board.pawns.has(seat):
		return (board.pawns[seat] as Node3D).global_position + Vector3(0, 1.15, 0)
	return board.space_pos(positions[seat]) + Vector3(0, 1.0, 0) if board else Vector3.ZERO

## A grudge (or deed) delta popup at the seat's pawn, arcing to its chip. glyph
## carries the currency; the sign + glyph mean it never reads as colour alone.
func _pop_grudge(seat: int, amount: int, glyph := "♠") -> void:
	if _fast or fx == null or amount == 0:
		return
	fx.fly_number(amount, glyph, _pawn_src(seat), _chip_screen_pos(seat), roster[seat].color)

## A grudge TRANSFER: the value lifts off the payer's pawn and flies to the
## collector's chip in the COLLECTOR's colour — the MP "Orb" toll, made visible.
func _pop_transfer(from_seat: int, to_seat: int, amount: int) -> void:
	if _fast or fx == null or amount <= 0:
		return
	fx.fly_number(amount, "♠", _pawn_src(from_seat), _chip_screen_pos(to_seat), roster[to_seat].color)

## A flying number lifting off a fixed world point (a stone, a gate) rather than a
## pawn — used for pass-through tolls where the payer is mid-hop.
func _pop_at(world_from: Vector3, seat_target: int, amount: int, color: Color) -> void:
	if _fast or fx == null or amount == 0:
		return
	fx.fly_number(amount, "♠", world_from, _chip_screen_pos(seat_target), color)

## Screen-space centre of a seat's HUD chip — the homing target for flying numbers
## and the Deed token (F10/F11/F17).
func _chip_screen_pos(seat: int) -> Vector2:
	if seat >= 0 and seat < _chips.size():
		var panel: Control = _chips[seat].get("panel")
		if panel != null and panel.is_inside_tree():
			return panel.global_position + panel.size * 0.5
	var vp := get_viewport()
	return vp.get_visible_rect().size * Vector2(0.5, 0.92) if vp else Vector2(640, 660)

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
	if _announce_scrim:
		_announce_scrim.visible = true

func _hide_announce() -> void:
	if _announce:
		_announce.visible = false
	if _announce_scrim:
		_announce_scrim.visible = false

# --------------------------------------------------------------------------
# HUD styling + the reveal lower-third (presentation only)
# --------------------------------------------------------------------------
## A dark translucent scrim panel with a thin gold rule — the house chrome.
func _scrim_box(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.62, 0.52, 0.30, 0.75)
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

## The reveal band: deeper scrim, heavier ornate gold frame.
func _lowerthird_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.04, 0.06, 0.90)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.78, 0.66, 0.36)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.content_margin_left = 6; sb.content_margin_right = 6
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	return sb

## Point the lower-third badge at the seat the current line concerns (-1 hides it).
func _apply_reveal_badge(seat: int) -> void:
	if _reveal_badge == null:
		return
	if seat >= 0 and seat < roster.size():
		_reveal_badge.player_index = seat
		_reveal_badge.color = roster[seat].color
		_reveal_badge.visible = true
	else:
		_reveal_badge.visible = false

## The Executor's banner toggles the inner RichTextLabel's visibility; the panel
## follows it — sliding up on show, vanishing on clear_banner().
func _on_reveal_vis_changed() -> void:
	if _lowerthird == null or _reveal == null:
		return
	if _reveal.visible:
		_apply_reveal_badge(_reveal_seat)
		if not _lowerthird.visible:
			_lowerthird.visible = true
			_slide_in_lowerthird()
	else:
		_lowerthird.visible = false
		_lowerthird.modulate.a = 0.0

## 0.25s slide-up + fade for the reveal band (skipped under the fast soak).
func _slide_in_lowerthird() -> void:
	if _lowerthird == null:
		return
	_lowerthird.offset_top = LT_REST_TOP + LT_SLIDE
	_lowerthird.offset_bottom = LT_REST_BOTTOM + LT_SLIDE
	if _fast:
		_lowerthird.offset_top = LT_REST_TOP
		_lowerthird.offset_bottom = LT_REST_BOTTOM
		_lowerthird.modulate.a = 1.0
		return
	_lowerthird.modulate.a = 0.0
	var tw := _lowerthird.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_lowerthird, "offset_top", LT_REST_TOP, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lowerthird, "offset_bottom", LT_REST_BOTTOM, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lowerthird, "modulate:a", 1.0, 0.22)

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
	# --- Establishing flyover: a wide raked view of the whole drive, greeting
	# in the executor banner, no clause text yet (they don't overlap). ---
	_reveal_seat = -1
	executor.say(Executor.pick(Executor.GREETING, rng), Color(0.9, 0.88, 0.98))
	# --- Establishing shot at the gate, then a cinematic flyover: a tour of the
	# drive, the manor gate + hearse, and the roving Codicil — the opening of a
	# Mario-Party board, re-staged around the new gothic dressing. The director
	# owns the shot spine now (F1); any player tap skips the tour (F1 skip). ---
	board_camera.establish()
	if not _fast:
		await board_camera.flyover(_flyover_skip)
	if _capture:
		board_camera.hold()   # the hero shots below pose the cam directly
		await _cap_snap("flyover")
		await _capture_showcase()
	else:
		VerifyCapture.snap("flyover")
	await _beat(1.6)
	# --- The will clauses, read BEFORE a single putt — nothing hidden decides. ---
	executor.clear_banner()
	board_camera.whole_board(0.6)
	var lines: Array[String] = []
	for c in clauses:
		lines.append("◆ %s — +1 Deed to whoever %s" % [c.title, c.desc])
	_announce_text("TONIGHT'S WILL CLAUSES\n\n" + "\n".join(lines), Color(0.85, 0.78, 1.0))
	if _capture:
		await _cap_snap("will_clause")
	else:
		VerifyCapture.snap("will_clause")
	await _beat(3.0)
	_hide_announce()
	executor.clear_banner()

## Capture only: snap the live putt-target reticles a beat into the roll, without
## blocking the roll's all_released await.
func _snap_putt_preview_later() -> void:
	await _beat(0.85)
	if _preview_active:
		await _cap_snap("putt_preview")

## Any human tap (A or B) breaks the opening flyover — the director polls this
## each frame during its tour. All-bots (autoplay/capture) never trips it, so the
## full tour plays for the verification screenshots.
func _flyover_skip() -> bool:
	for i in roster.size():
		if not bool(roster[i].bot):
			if PlayerInput.just_pressed(i, "a") or PlayerInput.just_pressed(i, "b"):
				return true
	return false

## Windowed capture only: pose two hero shots for the Steam-page verification —
## the dressed board wide, and a weeping grave in close with its headstone. Never
## runs headless (gated by _capture) so it can't perturb the receipt.
func _capture_showcase() -> void:
	executor.clear_banner()   # hero shots stand clean, no greeting banner
	# A clean, head-on elevated hero of the whole dressed drive (nothing blocks
	# centre; the Codicil glow anchors the far arc).
	cam.global_position = Vector3(0.0, 17.5, 28.0)
	cam.look_at(board.CENTER + Vector3(0, 1.4, 0), Vector3.UP)
	print("SHOWCASE board_wide cam=", cam.global_position)
	await _cap_snap("board_wide")
	# A weeping grave in close: a headstone with its lit pink rim, board dark
	# behind. Index 16 -> grave_headstone_plain (a clean upright stone).
	var gi := 16
	var gp := board.space_pos(gi)
	var outward := gp - board.CENTER
	outward.y = 0.0
	outward = outward.normalized() if outward.length() > 0.01 else Vector3.BACK
	cam.global_position = gp + outward * 2.9 + Vector3(0.0, 1.3, 0.0)
	cam.look_at(gp + outward * 0.9 + Vector3(0, 0.85, 0), Vector3.UP)
	print("SHOWCASE grave_detail cam=", cam.global_position)
	await _cap_snap("grave_detail")
	cam.global_position = _cam_home
	cam.look_at(board.CENTER, Vector3.UP)

func _round() -> void:
	_phase = "roll"
	_hide_announce()
	# --- ROLL: all live pawns putt at once (own corner meter). ---
	# Windowed capture: pose the four corner meters mid-charge for a clean shot
	# before the live roll (the fast soak resolves a real roll in a few frames).
	if _capture and round_num == 1:
		putt.stage_midcharge([0.42, 0.58, 0.50, 0.64])
		await _cap_snap("putt_meters")
		putt.end_roll_visuals()
	var targets := _bot_targets()
	putt.begin_roll(targets, rng)
	_preview_active = true   # F29: live target reticles follow each charging meter
	if not _capture:
		VerifyCapture.snap("putt_meters")
	elif round_num == 2:
		# Fire-and-forget so the delayed snap never sits between begin_roll and the
		# all_released await (which would risk missing the signal). Round 2 spreads
		# the pawns around the ring so the reticles land at distinct stones.
		_snap_putt_preview_later()
	var results: Array = await putt.all_released
	_preview_active = false
	board.clear_all_putt_previews()
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

	# --- MOVE: every pawn travels at once; a low raking dolly TRAVELS along the
	# drive (F2) so the procession reads as a procession, not a static overhead. ---
	_phase = "move"
	board_camera.move_travel(0.9)
	# The Codicil is a moving target you REACH: the first pawn (by seat) whose
	# hop passes OR lands on the beacon this round, and can afford it, claims it.
	# Resolved as that seat's REVEAL beat; relocation happens on the claim.
	_round_codicil_seat = -1
	for i in roster.size():
		if _path_crosses(positions[i], moved[i], board.beacon_index) \
				and grudge[i] >= codicil.price_for(deeds[i]):
			_round_codicil_seat = i
			break
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
	board_camera.whole_board(0.5)
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
			if _path_crosses(positions[i], n, board.beacon_index) and grudge[i] >= codicil.price_for(deeds[i]):
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
			_flash_line("%s spends a MOURNING PIN (+1 space)" % roster[i].name, roster[i].color, i)
		if items[i].ribbon > 0:
			items[i].ribbon -= 1
			moved[i] = maxi(1, moved[i] - 1)
			_flash_line("%s is dragged by a BLACK RIBBON (−1 space)" % roster[i].name, roster[i].color, i)

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
				_pop_at(board.space_pos(idx) + Vector3(0, 1.0, 0), owner, pay,
					roster[owner].color)   # F11: pass-toll coins arc to the owner

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
	# The affected player's badge rides the lower-third for this landing's line.
	_reveal_seat = seat
	_apply_reveal_badge(seat)
	# Type-aware landing close-up with an overshoot punch-in (F3). The Codicil
	# claim gets its own hero push (F17), staged inside _resolve_codicil.
	if not _fast and seat != _round_codicil_seat:
		board_camera.landing_push(board.reveal_shot(idx, board.type_at(idx)))
	var col: Color = roster[seat].color
	var name := String(roster[seat].name)
	if seat == _round_codicil_seat:
		await _resolve_codicil(seat)
	else:
		match board.type_at(idx):
			Spaces.SHRINE: _resolve_shrine(seat, name, col)
			Spaces.WEEPING_GRAVE: _resolve_grave(seat, name, col)
			Spaces.STALL: _resolve_stall(seat, name, col)
			Spaces.SEANCE: await _resolve_seance(seat, name, col)
			Spaces.TOLLGATE: _resolve_tollgate(seat, name, col)
			Spaces.VENDETTA: _resolve_vendetta(seat, name, col)
			_: executor.say(Executor.pick(Executor.BLANK, rng, [name]), col)
	_refresh_hud()
	_push_net()
	if seat == _round_codicil_seat:
		if _capture:
			await _cap_snap("codicil")
		else:
			VerifyCapture.snap("codicil")
		await _reveal_beat(seat, REVEAL_BEAT)
	elif _capture:
		# Let the landing push-in settle before the verification snap, so the
		# type-aware close-up (F3) is judged at rest, not mid-travel. Windowed
		# capture only — the headless receipt never takes this branch.
		await _beat(0.7)
		await _cap_snap("reveal")
		# Demo the reveal-cascade REACT glyphs (F24) once, for the screenshot —
		# real play drives these from live waiting-player button taps.
		if not _reacted_demo:
			_reacted_demo = true
			_capture_demo_reactions(seat)
			await _beat(0.55)
			await _cap_snap("reactions")
		await _reveal_beat(seat, maxf(0.0, REVEAL_BEAT - 0.7))
	else:
		VerifyCapture.snap("reveal")
		await _reveal_beat(seat, REVEAL_BEAT)

# --------------------------------------------------------------------------
# F24 — REVEAL-CASCADE REACT BUTTONS. During a landing reveal the WAITING players
# can tap to float an attributed laugh/jeer/wince over the victim's stone. Purely
# cosmetic, rate-limited, couch-first (remote seats are guarded out cleanly until
# a net path exists). No sim impact — it never touches grudge/deeds/rng.
# --------------------------------------------------------------------------
## The reveal hold, made reactive: same skippable wait as _beat, but each frame it
## also polls the waiting players' reaction buttons.
func _reveal_beat(victim: int, seconds: float) -> void:
	if _fast:
		await get_tree().process_frame
		return
	var t := 0.0
	while t < seconds:
		if _phase != "heir" and _all_press_skip():
			return
		_poll_reactions(victim)
		await get_tree().process_frame
		t += get_process_delta_time()

## Read every waiting human's reaction buttons and float a glyph on a press,
## rate-limited per seat. Bots and remote seats are skipped (couch-first).
func _poll_reactions(victim: int) -> void:
	var now := Time.get_ticks_msec()
	for i in roster.size():
		if i == victim or bool(roster[i].bot):
			continue
		if PlayerInput.has_method("is_remote") and PlayerInput.is_remote(i):
			continue
		if now - _react_last[i] < REACT_COOLDOWN_MS:
			continue
		for action in REACT_MAP:
			if PlayerInput.just_pressed(i, String(action)):
				_react_last[i] = now
				_spawn_reaction(victim, i, String(REACT_MAP[action]))
				break

## Float a reactor's attributed glyph over the victim's stone: their badge glyph +
## the reaction word, in the reactor's colour, rising and fading. Never headless.
func _spawn_reaction(victim: int, reactor: int, word: String) -> void:
	if _fast or board == null or not board.pawns.has(victim):
		return
	var lbl := Label3D.new()
	lbl.text = "%s %s" % [PlayerBadge.glyph(reactor), word]
	lbl.font_size = 44
	lbl.pixel_size = 0.0062
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.outline_size = 13
	lbl.outline_modulate = Color(0, 0, 0, 0.92)
	lbl.modulate = Color(roster[reactor].color).lerp(Color.WHITE, 0.15)
	board.add_child(lbl)
	# Fan reactions out by reactor so several never stack, at head height over the
	# victim so they read inside the reveal close-up.
	var base: Vector3 = (board.pawns[victim] as Node3D).global_position \
		+ Vector3(0.62 * (float(reactor) - 1.5), 1.3, 0.0)
	lbl.global_position = base
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position", base + Vector3(0, 1.1, 0), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(lbl.queue_free)

## Windowed capture only: fire a couple of scripted reactions from waiting seats so
## the F24 glyphs appear in the verification screenshot (real play uses live taps).
func _capture_demo_reactions(victim: int) -> void:
	for i in roster.size():
		if i == victim:
			continue
		_spawn_reaction(victim, i, String(REACT_MAP.values()[i % REACT_MAP.size()]))

# ---- per-space resolutions ----
func _resolve_shrine(seat: int, name: String, col: Color) -> void:
	grudge[seat] += 3
	stats[seat].shrines += 1
	Sfx.play("grudge", -4.0)
	_pop_grudge(seat, 3)   # F10: +3♠ arcs from the shrine to the chip
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
		_pop_transfer(seat, owner, toll)   # F11: the toll flies to the monument owner
		executor.say(Executor.pick(Executor.GRAVE_TOLL, rng,
			[name, roster[owner].name, roster[owner].name, toll]), col)
	else:
		var loss := mini(2, grudge[seat])
		grudge[seat] -= loss
		stats[seat].lost += loss
		_pop_grudge(seat, -loss)   # F11: −N♠ falls from the pawn
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
	# The SIM decides the slot (unchanged rng draw); the visible wheel is theater
	# that spins TO it (F13). Effects apply as the needle lands, so the dial reads
	# like it caused the outcome — but it never decides anything.
	var slot := rng.randi_range(0, Spaces.SEANCE_WHEEL.size() - 1)
	var w: Dictionary = Spaces.SEANCE_WHEEL[slot]
	Sfx.play("bumper", -6.0)
	if not _fast:
		# Match the lower-third to the séance during the spin (the outcome line
		# lands after the needle settles).
		executor.say("The planchette stirs for %s. The circle turns…" % name,
			Color(0.78, 0.6, 0.95))
		if _capture:
			# Fire the spin, snap it mid-turn for the verification screenshot, then
			# let it settle. Windowed capture only; never on the headless receipt.
			seance_wheel.spin_to(slot)
			await _beat(1.1)
			await _cap_snap("seance_wheel")
			await _beat(2.0)
		else:
			await seance_wheel.spin_to(slot)
	var _before: Array[int] = grudge.duplicate()
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
	# F10/F11: the communal outcome, made visible — each seat's delta flies to its
	# chip so the whole table sees who the circle favoured.
	for i in roster.size():
		_pop_grudge(i, grudge[i] - _before[i])
	executor.say(Executor.pick(Executor.SEANCE, rng) + "  [%s — %s]" % [w.title, w.rule],
		Color(0.78, 0.6, 0.95))

func _resolve_tollgate(seat: int, name: String, col: Color) -> void:
	board.set_tollgate_owner(positions[seat], seat)
	grudge[seat] += 2   # the collected pot (abstracted)
	stats[seat].duels += 1
	Sfx.play("sink", -4.0)
	_pop_grudge(seat, 2)   # F10: the pot arcs to the new gate-owner's chip
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
	_pop_transfer(lose, win, moved_g)   # F11: the spoils fly from loser to winner
	executor.say(Executor.pick(Executor.VENDETTA_RESULT, rng, [roster[win].name, roster[lose].name]) \
		+ "  (%d♠, stakes %d vs %d)" % [moved_g, s_a, s_b], roster[win].color)
	# A decisive vendetta is a deciding beat for the newsreel (F5).
	MomentScribe.capture("vendetta", "%s BREAKS %s (%d♠)" % [
		roster[win].name, roster[lose].name, moved_g], 2, [win, lose], "procession")

## THE DEED MONEY-SHOT (F17). The economy's climax: hero push into the Codicil, a
## gold flare, a wax-sealed Deed flying to the buyer's chip, the price draining
## from their grudge, and the beacon RELOCATING visibly (a gold wisp streak) so
## the moving target is never lost. The sim (charge/grant/relocation rng) is
## byte-identical to before; only the theater is new, all gated behind not _fast.
func _resolve_codicil(seat: int) -> void:
	var name := String(roster[seat].name)
	var col: Color = roster[seat].color
	var price := codicil.price_for(deeds[seat])
	if grudge[seat] < price:
		executor.say(Executor.pick(Executor.CODICIL_SHORT, rng, [name]) + "  (needs %d♠)" % price, col)
		return
	var beacon_pos := board.beacon_world_pos()
	if not _fast:
		board_camera.beacon_hero(beacon_pos)
	# --- sim: charge the price, grant the Deed (unchanged order + effects) ---
	grudge[seat] -= price
	deeds[seat] += 1
	stats[seat].deeds_bought += 1
	stats[seat].spent += price
	Sfx.play("match_win", -6.0)
	executor.say(Executor.pick(Executor.CODICIL, rng, [name]) + "  (−%d♠ → ◆%d)" % [price, deeds[seat]], col)
	_refresh_hud()
	# --- theater: flare, the Deed flies to the buyer, the price drains away ---
	if not _fast:
		board.flare_beacon()
		var chip := _chip_screen_pos(seat)
		fx.fly_deed(beacon_pos, chip, col)
		fx.fly_number(-price, "♠", beacon_pos, chip, col)
		if _capture:
			await _beat(0.3)                 # catch the Deed in flight + the flare
			await _cap_snap("deed_moneyshot")
	# The estate's memory ceremony (F5): the deciding-moment still.
	MomentScribe.capture("codicil_claim", "%s CLAIMS A DEED (◆%d)" % [name, deeds[seat]],
		3, [seat], "procession")
	# --- relocation: logical index updates now; the beacon TRAVELS on screen ---
	var new_idx := codicil.choose_relocation(rng, BoardPath.SPACES)
	if _fast:
		board.set_beacon(new_idx)
	else:
		var tw: Tween = board.travel_beacon(new_idx)
		if tw != null and tw.is_valid():
			await tw.finished
	if final_kit and deeds[seat] >= deed_goal - 1 and decision_layer:
		final_kit.escalate()

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

## Does a hop of `moved` from `from_idx` pass over OR land on `target` (the
## Codicil beacon)? A move of 0 never reaches anything.
func _path_crosses(from_idx: int, moved: int, target: int) -> bool:
	for step in range(1, moved + 1):
		if posmod(from_idx + step, BoardPath.SPACES) == target:
			return true
	return false

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

func _flash_line(text: String, col: Color, seat := -1) -> void:
	if _reveal:
		_reveal_seat = seat
		_apply_reveal_badge(seat)
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
	# The SIM picks the game (unchanged rng draw); the roulette (F22) is theater
	# that lands on it, then calls "TAKE YOUR PLACES" (the estate's voice, doc 26).
	var mid: String = CONTRACT_POOL[rng.randi_range(0, CONTRACT_POOL.size() - 1)]
	if _fast:
		pass   # the soak skips the roulette entirely
	elif _capture:
		roulette.present(CONTRACT_POOL, mid)   # fire, snap mid-spin, then wait out
		await _beat(1.2)
		await _cap_snap("roulette")
		while not roulette.finished:
			await get_tree().process_frame
	else:
		await roulette.present(CONTRACT_POOL, mid)
	_hide_announce()
	var placements: Array = await _run_minigame(mid)
	# RECKONING — placements pay 5/3/2/1 Grudge (and movement in QUICK WAKE).
	_phase = "reckoning"
	var lines: Array[String] = []
	for rank in placements.size():
		var p := int(placements[rank])
		var pay: int = POINTS[rank] if rank < POINTS.size() else 0
		grudge[p] += pay
		if not decision_layer:
			var adv: int = POINTS[rank] if rank < POINTS.size() else 0
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
			_pop_grudge(winner_seat, 1, "◆")   # F10: the bonus Deed flies to the chip
			lines.append("%s — %s (%s)  +1 Deed → ◆%d" % [
				c.title, roster[winner_seat].name, c.desc, deeds[winner_seat]])
		else:
			lines.append("%s — unclaimed. The estate keeps the Deed." % c.title)
	# Clear the executor's opening line so it does not sit behind the card.
	executor.clear_banner()
	_announce_text("THE READING OF THE WILL\n\n" + "\n".join(lines), Color(0.85, 0.78, 1.0))
	_refresh_hud()
	if _capture:
		await _cap_snap("will_reading")
	else:
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
	# Skipped under the autoplay SOAK so the verification stays save-independent
	# and byte-identical run to run (real play / the estate merge always writes).
	var pl: Dictionary = roster[winner]
	if not _autoplay:
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
	# Hide the board HUD (chips/top bar/reveal) but KEEP the announce layer so the
	# crown banner reads over the podium.
	_topbar.visible = false
	_chiprow.visible = false
	_reveal.visible = false
	podium.stage_entries(entries)
	_announce_text("%s IS CROWNED HEIR\n◆%d DEEDS · SEED %d" % [pl.name, deeds[winner], seed_value],
		Color(pl.color))
	_announce.visible = true
	# The victor's crown — the newsreel's headline still (F5).
	MomentScribe.capture("heir_crowned", "%s IS CROWNED HEIR (◆%d)" % [pl.name, deeds[winner]],
		3, [winner], "procession")
	if _capture:
		await _cap_snap("heir_crowned")
	else:
		VerifyCapture.snap("heir_crowned")
	await _beat(6.0 if not _fast else 0.2)
	if is_instance_valid(podium):
		podium.queue_free()
	_topbar.visible = true
	_chiprow.visible = true

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

## Windowed capture: let a couple of frames render so tweens/labels settle,
## then snap. Inert in headless (VerifyCapture.snap no-ops without a viewport).
func _cap_snap(tag: String) -> void:
	# Let the camera settle, THEN await the snap coroutine to completion — snap()
	# awaits frame_post_draw internally, so if we don't await it here the capture
	# fires a frame later and lands on the NEXT camera cut (swapped hero shots).
	for _i in 3:
		await get_tree().process_frame
	await VerifyCapture.snap(tag)

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
