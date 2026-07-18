extends Node3D
## THE PROCESSION — ILL WILL's board night, rebuilt on the doc-28 graph board.
## One wake per session: roll your pawn from the LYCHGATE to the MANOR GATE
## through three route personalities (GARDEN ROW / HOLLOW WOODS / WEEPING
## VALLEY) joined by two CROSSROADS. The first pawn through the gate rings
## THE FINAL BELL — everyone else gets exactly one more turn, then the night
## is scored by arrival order, then remaining distance. The wedge survives:
## PARALLELISE the roll+move, SERIALISE the reveal.
##
## Self-boots from the CLI via procession_boot.gd (--procession), OR is handed
## a roster by estate.gd at merge via begin(config). Deterministic under four
## NAMED rng streams (Codex correction #2, night 7):
##   LAYOUT — board topology; seeded from board DATA, never the night seed
##            (board_graph.gd), so --boardgraphtest is night-independent.
##   ROLL   — _roll_rng: LAST BREATH turn streams (one child stream seeded per
##            turn: crit band deal, period jitter, the face draw), bot aim
##            scans, bot crossroads choices.
##   EVENT  — _event_rng: séance slots, item draws + bot shop/item policy,
##            minigame pick/minisim, award draws + tie-breaks, house-awakens.
##   VOICE/DRAMA — _voice_rng/_drama_prng: Executor line picks + board-drama
##            flourishes. Presentation only; can never shift the tally.
##
## P2 (this lane): the roll is THE LAST BREATH meter — SEQUENTIAL, one seat at
## a time in wreath-standings order LEADER FIRST (doc 28 §8 law 1), d8 base,
## with the always-on AIM HEATMAP painting live landing probabilities down the
## roller's road. pawn_putt.gd stays on disk untouched (Par receipts reference
## its constants) — it is simply no longer wired here.
##
## The Codicil is RETIRED as a purchase stop (doc 28 §1); codicil.gd stays on
## disk, unwired. The ring (board_path.gd) is retired the same way. This
## deliberately kills the frozen seed-7 ring receipt — sanctioned, doc 28 §13.
##
## Online: _net_state()/_net_apply() ship the whole board as facts; the host
## simulates, mirrors render truth.

const BoardGraph := preload("res://estate/procession/board_graph.gd")
const LastBreath := preload("res://estate/procession/last_breath.gd")
const Executor := preload("res://estate/procession/executor_host.gd")
const Spaces := preload("res://estate/procession/board_spaces.gd")
const BoardCamera := preload("res://estate/procession/board_camera.gd")
const RoadPrompt := preload("res://estate/procession/crossroads_prompt.gd")
const BoardFx := preload("res://estate/procession/board_fx.gd")
const SeanceWheelScene := preload("res://estate/procession/seance_wheel.gd")
const MinigameRouletteScene := preload("res://estate/procession/minigame_roulette.gd")
const VendettaStakes := preload("res://estate/procession/vendetta_stakes.gd")
const TextFit := preload("res://estate/procession/text_fit.gd")
const Minimap := preload("res://estate/procession/board_minimap.gd")

const CHAR_SCENES := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const REVEAL_BEAT := 2.2
const RAISE_TIME := 2.5              # sealed-stakes hold-to-raise window (seconds)
# One-word-ish epitaphs the duel winner hangs on the loser's pawn for the rest of
# the night, in the estate's gravestone register (doc 26): death is a filing, not
# a scream; affection is logged as liability. Chosen from the PRESENTATION rng.
# Epitaphs + interim framing lines now live in dialog.json ("procession.epitaphs",
# "procession.interim_lines"); these getters fetch them. Both are drawn from the
# PRESENTATION rng by SIZE, so an edit that keeps the line count stays deterministic
# and never touches the sim stream / the frozen receipt.
static var EPITAPHS: Array:
	get: return Dialog.paras("procession.epitaphs")
static var INTERIM_LINES: Array:
	get: return Dialog.paras("procession.interim_lines")
# F24 reveal-cascade reactions: waiting-player button -> attributed glyph.
const REACT_COOLDOWN_MS := 550
const REACT_MAP := {"b": "HA!", "up": "OOH", "down": "OOF"}
const POINTS := [5, 3, 2, 1]        # RECKONING / will placement -> Grudge
const CONTRACT_POOL := ["echo", "tilt", "orbital", "mower", "greed", "swap",
	"deadweight", "throne", "lastwill", "pallbearers"]  # B7-HOOK
const MODULE_SCENES := {
	"pallbearers": "res://minigames/pallbearers/pallbearers.tscn",  # B7-HOOK
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
var seed_value := 0
var roster: Array = []
var grudge: Array[int] = []         # PENNIES on screen (internal name kept — RC §3:
                                    # 14 minigame receipts reference "grudge")
var wreaths: Array[int] = []        # THE victory currency (doc 28 §6) — persists all match
var deeds: Array[int] = []          # will-clause trophies only (Codicil retired)
var positions: Array[int] = []      # per seat: current GRAPH NODE id
var moved_total: Array[int] = []
var trail: Array = []               # per seat: Array[int] walked node history (slip-backs)
var arrived: Array = []             # per seat: bool — through the Manor Gate (home, untouchable)
var arrival_order: Array = []       # seats in gate-crossing order
var bell_round := -1                # round THE FINAL BELL rang (-1 = still open)
var turn_cap := 12                  # doc 28 §8 rule 4 — distance ranking backstop
var items: Array = []               # per seat: {pin,ribbon,salt} counts
var stats: Array = []               # per seat: will-clause stat dict
var round_num := 0
var winner := -1
var _started := false
var _autoplay := false
var _fast := false
var _minisim := true
var _mirror := false
var _capture := false            # windowed: pose beats + snap for screenshots
var _vendettatest := false       # dev flag: force the board-drama presentation with bot data (screenshots)
var _longnames := false          # dev flag (W9): worst-case long names to stress the text surfaces
var _graphtest := false          # --boardgraphtest: print the topology receipt and quit
# ---- the NAMED rng streams (header doctrine; LAYOUT lives in board_graph) ----
var _roll_rng := RandomNumberGenerator.new()     # ROLL: band deals, bot aim, bot road picks
var _event_rng := RandomNumberGenerator.new()    # EVENT: séance, items, minigame pick, house
var _voice_rng := RandomNumberGenerator.new()    # VOICE: Executor line picks (presentation)
var _drama_prng := RandomNumberGenerator.new()   # DRAMA: interim lines + epitaph pick (presentation)
var _epitaphs: Array = []        # per seat: epitaph String a duel winner hung ("" = none)
var _epitaph_tags := {}          # seat -> Label3D (the persistent gravestone tag riding the pawn)
var _stakes_ui: VendettaStakes = null   # sealed-stakes overlay (lazy; windowed only)
var _phase := "boot"
var _react_last: Array[int] = []   # F24: per-seat last-reaction wall-clock (cooldown)
var _reacted_demo := false         # F24: capture fires the reaction demo once
var _prompt_demoed := false        # capture poses the crossroads prompt once (screenshot b)
var _breath_posed := false         # capture poses the meter + heatmap once (P2 screenshot a)
var _arrived_this_round: Array = []   # seats whose walk crossed the gate THIS round
# ---- THE LAST BREATH turn state (P2) ----
const N_FACES_BASE := 8            # doc 28 §5: d8 locked (WRITs widen per roll)
var _breath_faces: Array = []      # all_released payload for the turn in flight
var _heat_seat := -1               # seat whose aim the heatmap paints (-1 = off)
var _heat_frame := 0               # coarse update cadence (every 3rd frame)

# ---- nodes ---- (concrete types so method returns infer without annotation)
var board: ProcessionBoardGraph
var breath: ProcessionLastBreath
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
var _reveal_font: Font                  # the reveal band's face (for measuring the fit)
var _lowerthird: PanelContainer         # dark scrim housing the reveal line
var _reveal_badge: PlayerBadge          # affected-player portrait in the lower-third
var _reveal_seat := -1                  # seat the current reveal line is about (-1 = none)
var _minimap: Minimap                   # F-mini: corner board inset (place read)
var _announce: Label
var _announce_scrim: Control            # dark band behind the centre ceremony cards
var _round_lbl: Label
var _objective_lbl: Label               # top-right: the gate / FINAL BELL state
var _chips: Array = []               # per seat: {badge, grudge_lbl, deeds_lbl}
var _cam_home: Vector3 = BoardGraph.OVERVIEW_POS   # 3/4 overview; lock-step with board_camera

# Lower-third geometry (anchored bottom-centre; slides up on show). The band's
# BOTTOM edge is pinned; its TOP grows upward to fit long copy (the eulogy and the
# estate's wordier reveals), so no line is ever clipped by the frame. LT_REST_TOP
# is the one-line resting height; _lt_top holds the current (possibly grown) top.
const LT_HALF_W := 620.0
const LT_REST_TOP := -338.0
const LT_REST_BOTTOM := -196.0
const LT_SLIDE := 34.0
const LT_MAX_TOP := -560.0               # ceiling: the band never grows past this
const LT_VPAD := 30.0                    # panel + margin padding around the text
const REVEAL_FONT_MAX := 34              # reveal band: comfortable size for short lines
const REVEAL_FONT_MIN := 24              # reveal band: floor once the band has grown fully
var _lt_top := LT_REST_TOP               # current band top (recomputed per show)

# Centre ceremony-card fit (the readings / reckoning / crown). The card is a fixed
# band; long clause lines + long names are fitted DOWN into it so the whole block
# reads without spilling past the scrim.
const ANNOUNCE_FONT_MAX := 46
const ANNOUNCE_FONT_MIN := 22
const ANNOUNCE_FIT_W := 1120.0           # inner width the card wraps at
const ANNOUNCE_FIT_H := 344.0            # inner height the card must fit within

# ---- will clauses (announced at night start, paid at the reading) ----
var clauses: Array = []

func _ready() -> void:
	call_deferred("_autostart")

## THE AIM HEATMAP (P2, always-on — producer-locked). While the active seat's
## LAST BREATH needle sweeps, the reachable stones down their road glow with the
## LIVE landing distribution from the meter's side-effect-free weights read
## (current_weights() picks the crit kernel iff the needle sits in the band, so
## crit sharpening is reflected as it happens). Coarse cadence (every 3rd
## frame) is plenty — the read is for a couch, not a scope. Presentation only:
## never consumes any stream, never mutates sim state.
func _process(_delta: float) -> void:
	if _fast or board == null or breath == null:
		return
	if _heat_seat < 0:
		return
	_heat_frame += 1
	if _heat_frame % 3 != 0:
		return
	_paint_heatmap(_heat_seat)

## One heatmap frame: face f lands at _preview_dest(seat, f + pending bonus)
## down the seat's preferred road (the same no-rng walk the bots use), glowing
## by probability (w normalized to the likeliest face) with a percent tag.
func _paint_heatmap(seat: int) -> void:
	var weights: Array[float] = breath.current_weights()
	var bonus := _pending_steps_bonus(seat)
	var entries: Array = []
	var wmax := 0.0001
	for w in weights:
		wmax = maxf(wmax, float(w))
	for f in weights.size():
		entries.append({"node": _preview_dest(seat, f + 1 + bonus), "face": f + 1,
			"p": float(weights[f]), "w": float(weights[f]) / wmax})
	board.show_heatmap(entries, roster[seat].color)

## Announced movement bonuses that shift every face's landing (LUCKY PENNY —
## P2 item pass). Kept honest: the heatmap must glow the stones you will
## actually reach.
func _pending_steps_bonus(_seat: int) -> int:
	return 0

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
	# --boardgraphtest: print the topology receipt (pure data, no world) and quit.
	if _graphtest:
		for line in BoardGraph.topology_receipt():
			print(line)
		get_tree().quit()
		return
	# The board-drama probe forces the presentation path (interim reading + sealed
	# stake meters) with bot data, at full ceremony length, so a windowed capture
	# can screenshot beats an all-bot soak skips by design. Never on the receipt.
	if _vendettatest:
		_fast = false
	_mirror = NetSession.is_client()
	_capture = _autoplay and DisplayServer.get_name() != "headless"
	if config.has("seed"):
		seed_value = int(config.seed)
	if config.has("turn_cap"):
		turn_cap = clampi(int(config.turn_cap), 4, 40)
	# Seed the NAMED streams (header doctrine). Distinct affine salts per stream
	# so no draw in one can ever shift another; presentation streams can never
	# shift the tally at all.
	_roll_rng.seed = seed_value * 1103515245 + 12345
	_event_rng.seed = seed_value * 22695477 + 1
	_voice_rng.seed = seed_value * 134775813 + 5
	_drama_prng.seed = seed_value * 2246822519 + 3266489917
	roster = config.get("roster", []) if config.has("roster") else _default_roster()
	if _longnames:
		_apply_longnames()   # W9: stress the text surfaces with worst-case names
	_init_arrays()
	_build_world()
	_build_hud()
	_choose_clauses()
	# The soak compresses real time: under _fast the LAST BREATH queue resolves
	# in a single frame per turn (no live sweep), so time_scale only speeds the
	# ceremonies — the tally stays byte-identical. Windowed play runs at 1.0.
	if _autoplay and _fast:
		Engine.time_scale = 8.0
	print("PROCESSION boot seed=%d board=%s turn_cap=%d players=%d autoplay=%s minisim=%s" % [
		seed_value, String(BoardGraph.BOARD.id), turn_cap, roster.size(),
		str(_autoplay), str(_minisim)])
	_run_night()

func _parse_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--turncap="):
			turn_cap = clampi(int(arg.trim_prefix("--turncap=")), 4, 40)
		elif arg.begins_with("--deedgoal=") or arg.begins_with("--preset="):
			# Ring-era dials, retired with the Codicil (doc 28). Accepted so old
			# command lines don't crash; they change nothing.
			print("PROCESSION note: %s is retired on the graph board (use --turncap=N)" % arg.split("=")[0])
		elif arg == "--boardgraphtest":
			_graphtest = true     # topology receipt: nodes/edges/routes/ratios/reach
		elif arg.begins_with("--autoplay="):
			_autoplay = true
			_fast = true
			_minisim = true
		elif arg == "--realmini":
			_minisim = false     # launch real modules even under autoplay
		elif arg == "--slowsim":
			_fast = false         # keep ceremonies at full length (for capture)
		elif arg == "--vendettatest":
			_vendettatest = true  # force the board-drama presentation with bot data (see _boot)
		elif arg == "--longnames":
			_longnames = true     # W9: force worst-case long names to stress the text surfaces

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

## W9 dev flag: overwrite the roster names with worst-case long strings so a
## windowed capture exercises every text surface (reveals, readings, reckoning,
## the crown) against the longest content the boxes could ever hold. Presentation
## test only — names are display strings, never part of the sim/receipt.
func _apply_longnames() -> void:
	var long := [
		"ALEXANDRA-WORTHINGTON", "BARTHOLOMEW THE THIRD",
		"CLEMENTINE ASHWORTH-VANE", "MONTGOMERY DUPONT IV"]
	for i in roster.size():
		roster[i].name = String(long[i % long.size()])

func _init_arrays() -> void:
	var n := roster.size()
	grudge.resize(n); deeds.resize(n); positions.resize(n); moved_total.resize(n)
	wreaths.resize(n)
	for i in n:
		wreaths[i] = 0
	_react_last.resize(n)
	for i in n:
		_react_last[i] = -100000
	items.clear(); stats.clear()
	trail.clear(); arrived.clear(); arrival_order.clear()
	_arrived_this_round.clear()
	bell_round = -1
	_epitaphs.clear()
	_epitaphs.resize(n)
	for i in n:
		_epitaphs[i] = ""
		grudge[i] = EstateState.STARTING_GRUDGE + 3   # a small float so turn 1 has stakes
		deeds[i] = 0
		positions[i] = 0                # node 0 = THE LYCHGATE
		moved_total[i] = 0
		trail.append([0])               # walked history (slip-backs retrace it)
		arrived.append(false)
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

	board = BoardGraph.new()
	add_child(board)
	# The soak ignores the persistent monument set so the receipt is independent
	# of whatever the user's save happens to hold; real play reads the estate.
	board.build(roster, [] if _autoplay else EstateState.monuments)

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

	# THE LAST BREATH (P2): the sequential roll meter. It owns its own
	# CanvasLayer (never occludable, RD §5), so it needs no HUD host.
	breath = LastBreath.new()
	add_child(breath)
	breath.configure(roster, _mirror)
	breath._fast = _fast
	breath.all_released.connect(_on_breath_released)

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
	_objective_lbl = _chip_label("LYCHGATE → MANOR GATE", 30, Color(1, 0.88, 0.4))
	top.add_child(_objective_lbl)

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
	# B2-HOOK: the Executor's proclamations (and the eulogy, same lower-third) are
	# set in IM Fell English — an OFL-licensed 17th-century gothic serif, the
	# will-reading register the estate deserves. Scoped to this band only, never
	# the whole UI. Baloo2 remains the fallback if the face fails to load.
	var serif: FontFile = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
	if serif == null:
		serif = load("res://assets/fonts/Baloo2.ttf")
	if serif != null:
		_reveal.add_theme_font_override("normal_font", serif)
		_reveal.add_theme_font_override("bold_font", serif)
	_reveal_font = serif if serif != null else ThemeDB.fallback_font
	_reveal.add_theme_font_size_override("normal_font_size", REVEAL_FONT_MAX)
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

	# THE DRIVE inset (W9) — a small parchment minimap pinned top-left, below the
	# status bar. Shown during MOVE/REVEAL (place legibility while the camera is
	# pushed in); hidden for the roll, where the corner meters live. Renders from
	# the same mirrored data the board already holds, so a net guest sees it too.
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	_minimap.anchor_left = 0.0; _minimap.anchor_right = 0.0
	_minimap.anchor_top = 0.0; _minimap.anchor_bottom = 0.0
	_minimap.offset_left = 24.0; _minimap.offset_top = 66.0
	_minimap.offset_right = 24.0 + Minimap.PANEL_W
	_minimap.offset_bottom = 66.0 + Minimap.PANEL_H
	_minimap.visible = false
	_ui.add_child(_minimap)
	_minimap.configure(board, roster)

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
	executor.after_say = _fit_reveal_band      # fit + grow the band for every line
	executor.embody(self, board, seed_value)   # B2-HOOK: give the host a body (F6/F7)
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
		_round_lbl.text = "ROUND %d / %d" % [round_num, turn_cap]
	if _objective_lbl:
		if bell_round >= 0:
			_objective_lbl.text = "☠ THE BELL HAS RUNG — LAST TURN"
		else:
			_objective_lbl.text = "LYCHGATE → MANOR GATE"
	for i in _chips.size():
		if bool(arrived[i]):
			_chips[i].grudge.text = "%d♠  ◆%d  HOME #%d" % [
				grudge[i], deeds[i], arrival_order.find(i) + 1]
		else:
			_chips[i].grudge.text = "%d♠  ◆%d  %d⚑" % [
				grudge[i], deeds[i], board.dist_to_gate(positions[i]) if board else 0]
	_sync_minimap()

## Show THE DRIVE inset only during MOVE/REVEAL (place legibility while the camera
## is pushed in), and feed it the current logical positions + Codicil berth. The
## roll owns the corners (meters); ceremonies own the centre (cards). Presentation
## only — reads mirrored state, never the sim.
func _sync_minimap() -> void:
	if _minimap == null:
		return
	var show := (_phase == "move" or _phase == "reveal") and (board == null or board.visible)
	_minimap.visible = show
	if show:
		_minimap.set_state(positions)

func _announce_text(text: String, color := Color(0.95, 0.95, 1.0), hold := 2.0) -> void:
	if _announce == null:
		return
	_announce.text = text
	# Fit the whole multi-line block into the card with the REAL face the label
	# draws in, so a wordy reading or a long name shrinks to fit instead of
	# spilling past the scrim. Deterministic (no rng) — safe on the receipt path.
	var font := _announce.get_theme_font("font")
	var size := TextFit.fit_size(font, text, ANNOUNCE_FIT_W, ANNOUNCE_FIT_H,
		ANNOUNCE_FONT_MAX, ANNOUNCE_FONT_MIN)
	_announce.add_theme_font_size_override("font_size", size)
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

## Fit the reveal band to the CURRENT line: shrink the face just enough for width,
## then grow the band UPWARD (bottom pinned) so every line fits without clipping.
## Called from executor.say() before the band is shown, and again on each new line
## while it stays up (the eulogy cadence), gliding the height between lines.
## Deterministic geometry only — never touches rng or the tally.
func _fit_reveal_band() -> void:
	if _reveal == null or _lowerthird == null or _reveal_font == null:
		return
	_apply_reveal_badge(_reveal_seat)   # badge state set before we measure the width
	var text := _reveal.get_parsed_text()
	var badge_w := 86.0 if (_reveal_badge and _reveal_badge.visible) else 0.0
	var inner_w := (LT_HALF_W * 2.0) - 52.0 - badge_w      # 26px side margins + badge
	var avail_h := (LT_REST_BOTTOM - LT_MAX_TOP) - LT_VPAD  # tallest inner the band allows
	var size := TextFit.fit_size(_reveal_font, text, inner_w, avail_h,
		REVEAL_FONT_MAX, REVEAL_FONT_MIN)
	_reveal.add_theme_font_size_override("normal_font_size", size)
	var needed := TextFit.wrapped_height(_reveal_font, text, inner_w, size) + LT_VPAD
	var band_h := clampf(needed, LT_REST_BOTTOM - LT_REST_TOP, LT_REST_BOTTOM - LT_MAX_TOP)
	_lt_top = LT_REST_BOTTOM - band_h
	# Already on-screen (line-to-line, e.g. the eulogy): glide to the new height.
	# The reveal-from-hidden case is animated by _slide_in_lowerthird using _lt_top.
	if _lowerthird.visible:
		if _fast:
			_lowerthird.offset_top = _lt_top
		else:
			var tw := _lowerthird.create_tween()
			tw.tween_property(_lowerthird, "offset_top", _lt_top, 0.18) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 0.25s slide-up + fade for the reveal band (skipped under the fast soak). Slides
## to the fitted top (_lt_top) so a grown band rises to its full height.
func _slide_in_lowerthird() -> void:
	if _lowerthird == null:
		return
	_lowerthird.offset_top = _lt_top + LT_SLIDE
	_lowerthird.offset_bottom = LT_REST_BOTTOM + LT_SLIDE
	if _fast:
		_lowerthird.offset_top = _lt_top
		_lowerthird.offset_bottom = LT_REST_BOTTOM
		_lowerthird.modulate.a = 1.0
		return
	_lowerthird.modulate.a = 0.0
	var tw := _lowerthird.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_lowerthird, "offset_top", _lt_top, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lowerthird, "offset_bottom", LT_REST_BOTTOM, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lowerthird, "modulate:a", 1.0, 0.22)

# --------------------------------------------------------------------------
# WILL CLAUSES (announced up front, paid at the reading — Pro Rules transparency)
# --------------------------------------------------------------------------
func _choose_clauses() -> void:
	clauses = [
		{"stat": "moved", "title": Dialog.text("procession.clauses.longest_title"),
			"desc": Dialog.text("procession.clauses.longest_desc")},
		{"stat": "lost", "title": Dialog.text("procession.clauses.betrayed_title"),
			"desc": Dialog.text("procession.clauses.betrayed_desc")},
		{"stat": "duels", "title": Dialog.text("procession.clauses.bloody_title"),
			"desc": Dialog.text("procession.clauses.bloody_desc")},
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
		# Once THE FINAL BELL has rung the night is closing — the stragglers get
		# their one roll and nothing else. Blocks only fire on an open road.
		if bell_round < 0 and round_num % 2 == 0:
			await _minigame_block()
		if bell_round < 0 and round_num % 3 == 0:
			await _house_awakens()
		if round_num >= turn_cap:
			if not _fast:
				_announce_text(Dialog.text("procession.bell.closing"), Color(1, 0.6, 0.4))
				await _beat(2.0)
				_hide_announce()
			break   # doc 28 §8 rule 4: the cap ends it; distance ranks the rest
	await _will_reading()
	await ProcessionEulogy.deliver(self, executor)   # B2-HOOK: procedural closing eulogy (F33)
	await _heir_crowned()
	_emit_tally()

func _intro() -> void:
	Music.play_slot("grounds")
	# --- Establishing flyover: a wide raked view of the whole drive, greeting
	# in the executor banner, no clause text yet (they don't overlap). ---
	_reveal_seat = -1
	executor.say(Executor.pick(Executor.GREETING, _voice_rng), Color(0.9, 0.88, 0.98))
	# --- Establishing shot at the lychgate, then a cinematic flyover: a tour of
	# the three roads and the Manor Gate — the opening of a Mario-Party board,
	# re-staged around the branching grounds. The director owns the shot spine
	# (F1); any player tap skips the tour (F1 skip). ---
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
		lines.append(Dialog.text("procession.clauses.line") % [c.title, c.desc])
	_announce_text(Dialog.text("procession.clauses.card_header") + "\n\n" + "\n".join(lines), Color(0.85, 0.78, 1.0))
	if _capture:
		await _cap_snap("will_clause")
	else:
		VerifyCapture.snap("will_clause")
	await _beat(3.0)
	_hide_announce()
	executor.clear_banner()

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
	# A clean elevated hero of the WHOLE branching board — lychgate at the
	# bottom of frame, the three route ribbons, the Manor Gate glowing at top.
	cam.global_position = Vector3(0.0, 42.0, 44.0)
	cam.look_at(board.CENTER + Vector3(0, 0.5, -2.0), Vector3.UP)
	print("SHOWCASE board_wide cam=", cam.global_position)
	await _cap_snap("board_wide")
	# An open grave in close: a headstone with its lit rim, board dark behind.
	var gi := board.first_of_type(Spaces.OPEN_GRAVE)
	var gp := board.space_pos(gi)
	var outward := gp - board.CENTER
	outward.y = 0.0
	outward = outward.normalized() if outward.length() > 0.01 else Vector3.BACK
	cam.global_position = gp + outward * 2.9 + Vector3(0.0, 1.3, 0.0)
	cam.look_at(gp + outward * 0.9 + Vector3(0, 0.85, 0), Vector3.UP)
	print("SHOWCASE grave_detail cam=", cam.global_position)
	await _cap_snap("grave_detail")
	if executor.has_body():
		await executor.showcase_gestures(self)   # B2-HOOK: host idle + gesture stills (F7)
	cam.global_position = _cam_home
	cam.look_at(board.CENTER, Vector3.UP)

## ONE ROUND, SEQUENTIAL (doc 28 §2/§8 law 1): every live seat takes a full
## turn — roll on THE LAST BREATH, walk, resolve — one at a time, in current
## wreath-standings order LEADER FIRST (leader commits blind, trailers act
## informed). Home pawns sit their turns out entirely (the simultaneous-roll
## wart died with pawn_putt).
func _round() -> void:
	_phase = "roll"
	_hide_announce()
	_sync_minimap()
	_arrived_this_round.clear()
	executor.begin_round()   # B2-HOOK: page-turn the ledger between rounds (F7)
	if not _fast:
		_reveal_seat = -1
		executor.aside(Executor.ROUND_OPENER, Color(0.82, 0.80, 0.92), [round_num])   # B2-HOOK: dead-air aside (F9)
		await _beat(0.9)
	for seat in _roll_order():
		if bool(arrived[seat]):
			continue
		await _take_turn(seat)
	executor.clear_banner()
	executor.settle_body()   # B2-HOOK: host eases home after the cascade (F7)
	board_camera.whole_board(0.5)   # camera belongs to the director (F1-F3)
	_refresh_hud()

## Roll order = CURRENT WREATH STANDINGS, leader first (doc 28 §8 law 1).
## Every tie explicit and stable: wreaths desc → pennies desc → seat asc.
func _roll_order() -> Array:
	var order: Array = []
	for i in roster.size():
		order.append(i)
	order.sort_custom(func(a, b):
		if wreaths[a] != wreaths[b]:
			return wreaths[a] > wreaths[b]
		if grudge[a] != grudge[b]:
			return grudge[a] > grudge[b]
		return a < b)
	return order

## ONE TURN: frame the roller, roll THE LAST BREATH (heatmap live), walk the
## stones (forks prompt/strategize), ring the bell on a crossing, reveal the
## landing. The whole table watches one seat at a time — the reveal cascade
## is now inline with the turn.
func _take_turn(seat: int) -> void:
	_phase = "roll"
	_sync_minimap()
	if not _fast:
		_frame_roller(seat)
	# Windowed capture: pose the meter + heatmap once for the verification
	# still (the fast soak resolves a live roll in a single frame).
	if _capture and not _breath_posed:
		_breath_posed = true
		await _pose_breath_shot(seat)
	var face := await _roll_breath(seat, N_FACES_BASE)
	var steps := _apply_turn_items(seat, face)
	# --- WALK: node-to-node along the seat's road; forks prompt humans, bots
	# draw strategy from the ROLL stream. Excess past the gate is forfeited. ---
	_phase = "move"
	var path: Array = await _resolve_walk(seat, steps)
	if not path.is_empty():
		_pay_passthrough_tolls(seat, path)
		board_camera.move_travel(0.9)
		var tw: Tween = board.advance_pawn_path(seat, path)
		positions[seat] = int(path.back())
		(trail[seat] as Array).append_array(path)
		moved_total[seat] += path.size()
		stats[seat].moved += path.size()
		if board.type_at(positions[seat]) == Spaces.GATE and not bool(arrived[seat]):
			arrived[seat] = true
			arrival_order.append(seat)
			_arrived_this_round.append(seat)
		_sync_minimap()   # THE DRIVE inset lights up for the travel + reveal
		if not _fast and tw and tw.is_valid():
			await tw.finished
		elif _fast:
			board.seat_pawn(seat, positions[seat])
	if _capture and round_num == 1 and seat == _roll_order().back():
		await _cap_snap("drive_minimap")   # THE DRIVE ribbons, first travel beat
	_push_net()
	# --- THE FINAL BELL: the first crossing this night rings it, mid-round —
	# the rest of the queue still takes this turn (phase completes), then one
	# more full round for everyone (doc 28 §15 roll-phase completion). ---
	if bell_round < 0 and _arrived_this_round.has(seat):
		await _ring_bell(seat)
	# --- REVEAL: the landing, Executor voice, type-aware close-up. ---
	_phase = "reveal"
	if not path.is_empty():
		await _reveal_landing(seat)
	if breath.meter != null:
		breath.meter.visible = false

func _ring_bell(ringer: int) -> void:
	bell_round = round_num
	if final_kit:
		final_kit.escalate()
	Sfx.play("match_win", -4.0)
	MomentScribe.capture("final_bell", "%s RINGS THE FINAL BELL" % roster[ringer].name,
		3, [ringer], "procession")
	if not _fast:
		board_camera.landing_push(board.reveal_shot(board.gate_id(), Spaces.GATE))
		_announce_text(Dialog.text("procession.bell.header") + "\n\n"
			+ Dialog.text("procession.bell.rung") % roster[ringer].name,
			Color(1, 0.85, 0.4))
		if _capture:
			await _cap_snap("final_bell")
		await _beat(2.6)
		_hide_announce()

# --------------------------------------------------------------------------
# THE LAST BREATH turn plumbing (P2)
# --------------------------------------------------------------------------
## Run one seat's roll on the meter. Each turn gets its OWN child stream seeded
## from the ROLL stream (one randi here), so the meter's documented consumption
## (crit band + period + one face draw) can never smear across turns, and bot
## brains (a separate salt-derived stream inside the component) re-deal per
## turn. Returns the face (1..n_faces).
func _roll_breath(seat: int, n_faces: int) -> int:
	var turn_rng := RandomNumberGenerator.new()
	turn_rng.seed = _roll_rng.randi()
	_breath_faces = []
	_heat_seat = seat
	breath.begin_night_roll([seat], _turn_targets(seat, n_faces), turn_rng, n_faces)
	while _breath_faces.is_empty():
		await get_tree().process_frame
	_heat_seat = -1
	board.clear_heatmap()
	return clampi(int(_breath_faces[seat]), 1, n_faces)

func _on_breath_released(faces: Array) -> void:
	_breath_faces = faces

## The bot's wanted face for this turn: the highest-value stone reachable in
## 1..n_faces down its preferred road (previewed with the same no-rng walk the
## heatmap uses); a small ROLL-stream jitter keeps four bots distinct.
## Humans aim by hand — their slot is inert.
func _turn_targets(seat: int, n_faces: int) -> Array:
	var out: Array = []
	out.resize(roster.size())
	out.fill(3)
	if not bool(roster[seat].bot):
		return out
	var best_n := 1
	var best_v := -999.0
	for n in range(1, n_faces + 1):
		var v: float = Spaces.bot_value(board.type_at(_preview_dest(seat, n)))
		v += _roll_rng.randf_range(-0.6, 0.6)
		if v > best_v:
			best_v = v
			best_n = n
	out[seat] = best_n
	return out

## Frame the active roller: a raised shot from behind their stone looking down
## the road, so the meter (bottom-center) and the glowing heatmap stones share
## the frame. P3's over-shoulder minifig camera replaces this.
func _frame_roller(seat: int) -> void:
	var here := board.space_pos(positions[seat])
	var ahead := board.space_pos(_preview_dest(seat, 4))
	var dir := ahead - here
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	board_camera.landing_push({"pos": here - dir * 5.4 + Vector3(0, 4.6, 0),
		"look": here + dir * 3.4 + Vector3(0, 0.4, 0)})

## Windowed capture only: pose the meter mid-sweep with the crit band telegraphed
## and the heatmap lit at the same needle position, snap, tear down. Never
## touches any rng stream (weights_for_p is side-effect-free).
func _pose_breath_shot(seat: int) -> void:
	if breath.meter == null:
		return
	var pose_p := 0.62
	breath.meter.retarget(seat, String(roster[seat].name), roster[seat].color, 0.5, N_FACES_BASE)
	breath.meter.set_needle(0.3)     # sweep past the crit band once…
	breath.meter.set_needle(pose_p)  # …so the tell is drawn at the pose
	breath.meter.visible = true
	var weights: Array[float] = breath.weights_for_p(pose_p, N_FACES_BASE)
	var wmax := 0.0001
	for w in weights:
		wmax = maxf(wmax, float(w))
	var entries: Array = []
	for f in weights.size():
		entries.append({"node": _preview_dest(seat, f + 1), "face": f + 1,
			"p": float(weights[f]), "w": float(weights[f]) / wmax})
	board.show_heatmap(entries, roster[seat].color)
	await _beat(0.5)
	await _cap_snap("breath_heatmap")
	board.clear_heatmap()
	breath.meter.visible = false

## Walk `steps` stones from the seat's node, resolving forks. Returns the node
## path (may be shorter than steps: the gate ends every walk). Bot/soak fork
## choices draw from the ROLL stream in seat order; humans draw nothing.
func _resolve_walk(seat: int, steps: int) -> Array:
	var path: Array = []
	var cur := positions[seat]
	for _k in steps:
		var nxt := board.next_of(cur)
		if nxt.is_empty():
			break   # standing at the gate
		var branch := 0
		if nxt.size() > 1:
			branch = await _choose_branch(seat, cur)
		cur = int(nxt[branch])
		path.append(cur)
	return path

## A fork decision. Bots (and the soak): leader keeps to GARDEN ROW, the last
## seat gambles on WEEPING VALLEY, the middle takes HOLLOW WOODS — with a
## seeded 25% wildcard so four bots never railroad. Humans get the A/B/C
## prompt (no rng). Capture poses the prompt once with the bot's data.
func _choose_branch(seat: int, fork_id: int) -> int:
	var options: Array = board.branch_options(fork_id)
	var is_human := not bool(roster[seat].bot) and not _is_remote_seat(seat)
	if is_human and _drama_visible():
		return await _prompt_branch(seat, options)
	# bot strategy — ROLL stream, fixed draw shape (1 float + optional 1 int)
	var pref := _route_pref(seat)
	var pick := -1
	if _roll_rng.randf() < 0.25:
		pick = _roll_rng.randi_range(0, options.size() - 1)
	else:
		for k in options.size():
			if String((options[k] as Dictionary).route) == pref:
				pick = k
				break
		if pick < 0:
			pick = 0
	if _capture and not _prompt_demoed:
		_prompt_demoed = true
		await _demo_prompt(seat, options)
	return pick

## The seat's PREFERRED road by standing (no rng — shared by bot strategy,
## the F29 preview walk, and the human prompt's default focus order).
## Leader (fewest stones left) → garden (safe); last → valley (the gamble);
## middle seats → hollow.
func _route_pref(seat: int) -> String:
	var better := 0
	var worse := 0
	for j in roster.size():
		if j == seat or bool(arrived[j]):
			continue
		var dj := board.dist_to_gate(positions[j])
		var di := board.dist_to_gate(positions[seat])
		if dj < di or (dj == di and j < seat):
			better += 1
		else:
			worse += 1
	if better == 0:
		return "garden"
	if worse == 0:
		return "valley"
	return "hollow"

## The human crossroads prompt: camera on the fork, the minimal A/B/C picker,
## the table waits. Returns the branch index; draws nothing from any stream.
func _prompt_branch(seat: int, options: Array) -> int:
	board_camera.landing_push(board.reveal_shot(positions[seat], Spaces.CROSSROADS))
	var prompt := RoadPrompt.new()
	_ui.add_child(prompt)
	prompt.open({"name": roster[seat].name, "color": roster[seat].color}, options)
	var pick: int = await prompt.run()
	prompt.queue_free()
	return clampi(pick, 0, options.size() - 1)

## Windowed capture only: pose the crossroads prompt with bot data long enough
## for the verification screenshot, then tear it down. Never headless.
func _demo_prompt(seat: int, options: Array) -> void:
	var prompt := RoadPrompt.new()
	_ui.add_child(prompt)
	prompt.open({"name": roster[seat].name, "color": roster[seat].color}, options)
	await _beat(0.7)
	await _cap_snap("crossroads_prompt")
	prompt.queue_free()

## F29 preview destination: walk n stones taking the seat's preferred road at
## any fork. Pure read — no rng, no await, no mutation.
func _preview_dest(seat: int, n: int) -> int:
	var cur := positions[seat]
	var pref := _route_pref(seat)
	for _k in n:
		var nxt := board.next_of(cur)
		if nxt.is_empty():
			break
		var step := int(nxt[0])
		if nxt.size() > 1:
			for opt in board.branch_options(cur):
				if String((opt as Dictionary).route) == pref:
					step = int((opt as Dictionary).node)
					break
		cur = step
	return cur

## Movement adjustments from held items, applied to this turn's rolled face
## (announced when spent). P2's priced item pass replaces the free pin/ribbon.
func _apply_turn_items(seat: int, face: int) -> int:
	var steps := face
	if items[seat].pin > 0:
		items[seat].pin -= 1
		steps += 1
		_flash_line(Dialog.text("procession.narration.pin") % roster[seat].name, roster[seat].color, seat)
	if items[seat].ribbon > 0:
		items[seat].ribbon -= 1
		steps = maxi(1, steps - 1)
		_flash_line(Dialog.text("procession.narration.ribbon") % roster[seat].name, roster[seat].color, seat)
	return steps

## THE FERRYMAN'S TOLL, in passing: crossing a toll stone mid-walk pays 2♠ to
## the Ferryman (the estate; no player owns the river — doc 28 §6). Landing on
## one is handled in the reveal. The player-owned tollgate died with the ring.
func _pay_passthrough_tolls(seat: int, path: Array) -> void:
	for k in path.size() - 1:   # intermediate stones only; the landing reveals
		var idx := int(path[k])
		if board.type_at(idx) == Spaces.FERRY_TOLL:
			var pay := mini(2, grudge[seat])
			if pay <= 0:
				continue
			grudge[seat] -= pay
			stats[seat].lost += pay
			_pop_at(board.space_pos(idx) + Vector3(0, 1.0, 0), seat, -pay,
				roster[seat].color)   # F11: the fee falls off at the arch
			if not _fast:
				_flash_line(Dialog.text("procession.narration.ferry_pass") % roster[seat].name,
					roster[seat].color, seat)

func _reveal_landing(seat: int) -> void:
	var idx := positions[seat]
	# The affected player's badge rides the lower-third for this landing's line.
	_reveal_seat = seat
	_apply_reveal_badge(seat)
	# Type-aware landing close-up with an overshoot punch-in (F3). The camera
	# belongs to the director; the body's comic wind-up (B2, F8) plays
	# underneath it — lean-in while the shot settles, line on the snap.
	if not _fast:
		board_camera.landing_push(board.reveal_shot(idx, board.type_at(idx)))
		await executor.anticipate(idx, false)   # B2-HOOK: comic-timing wind-up (F8)
	var col: Color = roster[seat].color
	var name := String(roster[seat].name)
	if _arrived_this_round.has(seat):
		_resolve_arrival(seat, name, col)
	else:
		match board.type_at(idx):
			Spaces.OFFERING: _resolve_offering(seat, name, col)
			Spaces.OPEN_GRAVE: _resolve_grave(seat, name, col)
			Spaces.GRAVE_GOODS: _resolve_box(seat, name, col)
			Spaces.CART: _resolve_cart(seat, name, col)
			Spaces.SEANCE: await _resolve_seance(seat, name, col)
			Spaces.FERRY_TOLL: _resolve_ferry(seat, name, col)
			Spaces.CROSSROADS: executor.say(Executor.pick(Executor.CROSSROADS_LAND, _voice_rng, [name]), col)
			Spaces.VENDETTA: await _resolve_vendetta(seat, name, col)
			_: executor.say(Executor.pick(Executor.BLANK, _voice_rng, [name]), col)
	_refresh_hud()
	_push_net()
	if _capture:
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
func _resolve_offering(seat: int, name: String, col: Color) -> void:
	grudge[seat] += 3
	stats[seat].shrines += 1
	Sfx.play("grudge", -4.0)
	_pop_grudge(seat, 3)   # F10: +3♠ arcs from the offering to the chip
	executor.say(Executor.pick(Executor.OFFERING, _voice_rng, [name]), col)

func _resolve_grave(seat: int, name: String, col: Color) -> void:
	if items[seat].salt > 0:
		items[seat].salt -= 1
		executor.say(Dialog.text("procession.narration.grave_salt") % name, col)
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
		executor.say(Executor.pick(Executor.GRAVE_TOLL, _voice_rng,
			[name, roster[owner].name, roster[owner].name, toll]), col)
	else:
		var loss := mini(2, grudge[seat])
		grudge[seat] -= loss
		stats[seat].lost += loss
		_pop_grudge(seat, -loss)   # F11: −N♠ falls from the pawn
		executor.say(Executor.pick(Executor.GRAVE, _voice_rng, [name]), col)

## GRAVE GOODS — the free item box (EVENT stream picks the item).
func _resolve_box(seat: int, name: String, col: Color) -> void:
	var item := _grant_item(seat)
	Sfx.play("card", -6.0)
	executor.say(Executor.pick(Executor.GRAVE_GOODS, _voice_rng, [name]) + "  (%s)" % item.name, col)

## THE PEDDLER'S CART — tonight it hands over one item with better patter; the
## priced shop (doc 28 §6 wares table) is the economy lane's to build (P2).
func _resolve_cart(seat: int, name: String, col: Color) -> void:
	var item := _grant_item(seat)
	Sfx.play("card", -6.0)
	executor.say(Executor.pick(Executor.CART, _voice_rng, [name]) + "  (%s)" % item.name, col)

## THE FERRYMAN'S TOLL, landed on: pay 2♠ to the river. No owner, no refunds.
func _resolve_ferry(seat: int, name: String, col: Color) -> void:
	var pay := mini(2, grudge[seat])
	grudge[seat] -= pay
	stats[seat].lost += pay
	Sfx.play("sink", -4.0)
	_pop_grudge(seat, -pay)
	executor.say(Executor.pick(Executor.FERRY, _voice_rng, [name]), col)

## ARRIVAL — through the Manor Gate: home, untouchable, filed by the minute.
func _resolve_arrival(seat: int, name: String, col: Color) -> void:
	var rank := arrival_order.find(seat) + 1
	Sfx.play("match_win", -6.0)
	executor.say(Executor.pick(Executor.ARRIVAL, _voice_rng, [name])
		+ "  (HOME #%d)" % rank, col)
	MomentScribe.capture("gate_arrival", "%s REACHES THE MANOR GATE (#%d)" % [name, rank],
		2, [seat], "procession")

## Deal one announced item from the shared pool (EVENT stream). The black
## ribbon aims itself at the race leader, as ever.
func _grant_item(seat: int) -> Dictionary:
	var pool := Spaces.ITEMS
	var item: Dictionary = pool[_event_rng.randi_range(0, pool.size() - 1)]
	match String(item.id):
		"mourning_pin": items[seat].pin += 1
		"grave_salt": items[seat].salt += 1
		"black_ribbon":
			var leader := _race_leader(seat)
			if leader >= 0:
				items[leader].ribbon += 1
	return item

func _resolve_seance(seat: int, name: String, col: Color) -> void:
	# The SIM decides the slot (unchanged rng draw); the visible wheel is theater
	# that spins TO it (F13). Effects apply as the needle lands, so the dial reads
	# like it caused the outcome — but it never decides anything.
	var slot := _event_rng.randi_range(0, Spaces.SEANCE_WHEEL.size() - 1)
	var w: Dictionary = Spaces.SEANCE_WHEEL[slot]
	Sfx.play("bumper", -6.0)
	if not _fast:
		# Match the lower-third to the séance during the spin (the outcome line
		# lands after the needle settles).
		executor.say(Dialog.text("procession.narration.seance_stir") % name,
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
		1:  # EQUAL SHARES — the race leader pays each rival 1
			var lead := _race_leader(-1)
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
	executor.say(Executor.pick(Executor.SEANCE, _voice_rng) + "  [%s — %s]" % [w.title, w.rule],
		Color(0.78, 0.6, 0.95))

## Kept for data-driven boards that declare VENDETTA stones — the base
## estate_procession board has none (doc 28 §3 has no duel space; GRUDGE MATCH
## is its own interlude). Dormant, not dead.
func _resolve_vendetta(seat: int, name: String, col: Color) -> void:
	var nemesis := _nearest_within(seat, 5)
	if nemesis < 0:
		executor.say(Dialog.text("procession.narration.vendetta_alone") % name, col)
		return
	# THE STAKE (doc 18 signature 1v1). Bots + remote guests roll the old hidden
	# 0–3 (via _stake_for → sim rng). LOCAL HUMANS raise their own stake, sealed
	# and simultaneous, over ~2.5s (_sealed_stakes). The all-bot soak has no local
	# human, so it always takes the else branch below — same three draws, same
	# order (stake, stake, VENDETTA line) — and the receipt stays frozen.
	var s_a: int
	var s_b: int
	if _drama_visible() and (_is_local_human(seat) or _is_local_human(nemesis) or _vendettatest):
		executor.say(Executor.pick(Executor.VENDETTA, _voice_rng, [name, roster[nemesis].name]), col)
		var sealed: Array = await _sealed_stakes(seat, nemesis)
		s_a = int(sealed[0])
		s_b = int(sealed[1])
	else:
		s_a = _stake_for(seat)
		s_b = _stake_for(nemesis)
		executor.say(Executor.pick(Executor.VENDETTA, _voice_rng, [name, roster[nemesis].name]), col)
	# sealed stakes resolve visibly: higher stake takes the difference.
	var win := seat if s_a >= s_b else nemesis
	var lose := nemesis if win == seat else seat
	var low := mini(s_a, s_b)
	if s_a == s_b:
		executor.say(Dialog.text("procession.narration.vendetta_wash") % [
			name, roster[nemesis].name, s_a], col)
		return
	var moved_g := mini(low + 1, grudge[lose])
	grudge[lose] -= moved_g
	grudge[win] += moved_g
	stats[win].duels += 1
	stats[lose].lost += moved_g
	_pop_transfer(lose, win, moved_g)   # F11: the spoils fly from loser to winner
	executor.say(Executor.pick(Executor.VENDETTA_RESULT, _voice_rng, [roster[win].name, roster[lose].name]) \
		+ "  (%d♠, stakes %d vs %d)" % [moved_g, s_a, s_b], roster[win].color)
	# A decisive vendetta is a deciding beat for the newsreel (F5).
	MomentScribe.capture("vendetta", "%s BREAKS %s (%d♠)" % [
		roster[win].name, roster[lose].name, moved_g], 2, [win, lose], "procession")
	# THE EPITAPH (doc 18): the winner hangs a seeded gravestone tag on the loser's
	# pawn for the rest of the night. Gated inside _hang_epitaph — never in the soak.
	_hang_epitaph(lose, win)
	if _capture and String(_epitaphs[lose]) != "":
		await _snap_epitaph(lose)

# ---- helpers ----
## Nemesis search for the (dormant) vendetta stone: the closest rival by
## RACE distance — |stones-left(a) − stones-left(b)| — since node ids mean
## nothing across routes. Home pawns are beyond the reach of grudges.
func _nearest_within(seat: int, reach: int) -> int:
	var best := -1
	var best_d := reach + 1
	for j in roster.size():
		if j == seat or bool(arrived[j]):
			continue
		var d: int = absi(board.dist_to_gate(positions[seat]) - board.dist_to_gate(positions[j]))
		if d <= reach and d < best_d:
			best_d = d
			best = j
	return best

## Bot / remote-guest stake: a hidden 0–3 roll from the EVENT stream, capped by
## the seat's purse. LOCAL HUMAN seats never reach this — they raise their own
## stake sealed (see _sealed_stakes). Dormant with the base board (no vendetta
## stones), alive for any board data that declares them.
func _stake_for(seat: int) -> int:
	return clampi(_event_rng.randi_range(0, 3), 0, grudge[seat])

## The race leader (fewest stones to the gate; home pawns rank by arrival).
## The black ribbon's target and the séance's EQUAL SHARES payer.
func _race_leader(exclude: int) -> int:
	var order := _final_order()
	for p in order:
		if int(p) != exclude:
			return int(p)
	return -1

func _flash_line(text: String, col: Color, seat := -1) -> void:
	if _reveal:
		_reveal_seat = seat
		_apply_reveal_badge(seat)
		executor.say(text, col)

# --------------------------------------------------------------------------
# BOARD DRAMA (W1) — gating + the sealed stake + the epitaph + the interim read.
# Every player-facing beat below is gated by _drama_visible(): SKIPPED entirely
# under the headless soak and any all-bot table (the "a soak never sees it" idiom
# from estate.gd READY_GATE_TIME), so the byte-identical receipt never renders one
# and never draws the sim rng for one. --vendettatest forces the path with bot
# data so a windowed capture can screenshot what an all-bot run hides.
# --------------------------------------------------------------------------
## Any LOCAL human at the table? Bots and remote guests both read false.
func _has_human() -> bool:
	for i in roster.size():
		if not bool(roster[i].bot) and not _is_remote_seat(i):
			return true
	return false

func _is_remote_seat(seat: int) -> bool:
	return PlayerInput.has_method("is_remote") and PlayerInput.is_remote(seat)

## A seat that raises its own sealed stake — a local human, never a bot or a guest
## attending from a distant house (they keep the hidden roll, per the doctrine).
func _is_local_human(seat: int) -> bool:
	return not bool(roster[seat].bot) and not _is_remote_seat(seat)

## The one gate for all board-drama presentation: never headless, and either a
## real human is present or the dev probe is forcing it with bot data.
func _drama_visible() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return _has_human() or _vendettatest

## THE SEALED VENDETTA. Collects both 0–3 stakes: local humans raise their own by
## holding (A) over ~2.5s (released level = stake, hidden behind a wax seal until
## the reveal); bots + remote guests keep the hidden sim-rng roll (_stake_for),
## only *rendered* here. Both reveal together, a beat between. Returns [s_a, s_b].
func _sealed_stakes(a: int, b: int) -> Array:
	var seats := [a, b]
	var human := [_is_local_human(a), _is_local_human(b)]
	var stake := [0, 0]
	var sealed := [false, false]
	var fill := [0.0, 0.0]
	var hold_t := [0.0, 0.0]
	var auto_target := [0.0, 0.0]
	# The VENDETTA proclamation is up in the lower-third as we arrive; let it read a
	# beat, then CLEAR it so the sealed-stakes overlay owns the screen alone. The two
	# were sharing the lower band and the banner clipped mid-sentence behind the
	# overlay (director note W9). Host-only human path — never the soak, so the extra
	# beat cannot touch the byte-identical receipt.
	await _beat(1.1)
	executor.clear_banner()
	# Non-human sides pre-decide (bot/remote hidden roll), then auto-charge visibly.
	for k in 2:
		if not human[k]:
			stake[k] = _stake_for(seats[k])
			auto_target[k] = float(stake[k]) / 3.0
	_ensure_stakes_ui()
	_stakes_ui.show_duel(_stake_info(a), _stake_info(b))
	var cap_mid := _capture
	# In capture, hold the raise phase open long enough that the mid-raise snap
	# lands with pips lit, even when both auto sides pick low. Zero in real play.
	var min_raise := 0.9 if _capture else 0.0
	var elapsed := 0.0
	while not (sealed[0] and sealed[1]) and elapsed < RAISE_TIME + 0.6:
		var dt := get_process_delta_time()
		for k in 2:
			if sealed[k]:
				continue
			var s: int = seats[k]
			if human[k]:
				if PlayerInput.is_down(s, "a"):
					hold_t[k] += dt
					fill[k] = clampf(hold_t[k] / RAISE_TIME, 0.0, 1.0)
					_stakes_ui.set_fill(k, fill[k])
					if hold_t[k] >= RAISE_TIME:
						stake[k] = _level_from_fill(fill[k], s)
						sealed[k] = true
						_stakes_ui.set_sealed(k)
				elif hold_t[k] > 0.0:
					stake[k] = _level_from_fill(fill[k], s)
					sealed[k] = true
					_stakes_ui.set_sealed(k)
			else:
				fill[k] = minf(fill[k] + dt / maxf(0.4, RAISE_TIME * 0.55), auto_target[k])
				_stakes_ui.set_fill(k, fill[k])
				if fill[k] >= auto_target[k] - 0.001 and elapsed >= min_raise:
					sealed[k] = true
					_stakes_ui.set_sealed(k)
		elapsed += dt
		if cap_mid and elapsed > 0.5:
			cap_mid = false
			await _cap_snap("vendetta_raise")
		await get_tree().process_frame
	# Window expired: seal anyone who never committed (a silent human stakes 0).
	for k in 2:
		if not sealed[k]:
			if human[k]:
				stake[k] = _level_from_fill(fill[k], seats[k])
			sealed[k] = true
			_stakes_ui.set_sealed(k)
	# Reveal both, together, with a beat between the two flips.
	_stakes_ui.reveal(0, stake[0])
	if _capture:
		await _cap_snap("vendetta_reveal")
	await _beat(0.9)
	_stakes_ui.reveal(1, stake[1])
	await _beat(1.2)
	_stakes_ui.hide_all()
	return [stake[0], stake[1]]

## A local human's released charge → a 0–3 stake, capped by the purse (matching
## _stake_for's grudge clamp so a raise can never bid more than a roll could).
func _level_from_fill(f: float, seat: int) -> int:
	return clampi(int(round(clampf(f, 0.0, 1.0) * 3.0)), 0, grudge[seat])

## The per-duelist panel descriptor the sealed-stakes overlay renders from.
func _stake_info(seat: int) -> Dictionary:
	return {"name": String(roster[seat].name), "color": roster[seat].color,
		"glyph": PlayerBadge.glyph(seat), "human": _is_local_human(seat)}

## Lazily build the sealed-stakes overlay (windowed only; the soak never calls it).
func _ensure_stakes_ui() -> void:
	if _stakes_ui != null and is_instance_valid(_stakes_ui):
		return
	_stakes_ui = VendettaStakes.new()
	_ui.add_child(_stakes_ui)
	_stakes_ui.setup()

## THE INTERIM READING (doc 18). The will clauses are announced at minute 0 and
## paid at the end with nothing visible between; each HOUSE AWAKENS, the Executor
## reads the running leaders so the secret race is felt all night. Presentation
## only, PRESENTATION rng only, gated out of the soak entirely.
func _interim_reading() -> void:
	if not _drama_visible():
		return
	executor.clear_banner()
	# His framing line first (lower-third, his voice), then the standings card.
	executor.say(String(INTERIM_LINES[_drama_prng.randi_range(0, INTERIM_LINES.size() - 1)]),
		Color(0.85, 0.78, 1.0))
	await _beat(1.8)
	executor.clear_banner()
	var lines: Array[String] = []
	for c in clauses:
		var lead := _stat_leader(String(c.stat))
		if lead >= 0:
			lines.append(Dialog.text("procession.interim.line") % [
				c.title, roster[lead].name, _interim_metric(String(c.stat), lead)])
		else:
			lines.append(Dialog.text("procession.interim.contested") % c.title)
	_announce_text(Dialog.text("procession.interim.header") + "\n\n" + "\n".join(lines)
		+ "\n\n" + Dialog.text("procession.interim.trailer"),
		Color(0.85, 0.78, 1.0))
	if _capture:
		await _cap_snap("interim_reading")
	await _beat(3.0)
	_hide_announce()

## The running value for a clause, phrased for the interim card (no rng).
func _interim_metric(stat: String, seat: int) -> String:
	var v := int(stats[seat].get(stat, 0))
	match stat:
		"moved": return Dialog.text("procession.interim.metric_stones") % v
		"lost": return Dialog.text("procession.interim.metric_bled") % v
		"duels": return Dialog.text("procession.interim.metric_board") % v
	return "%d" % v

## THE EPITAPH. The duel winner hangs a seeded gravestone tag on the loser's pawn
## for the rest of the night, and — in real play only — files one line to the
## estate's graffiti. Gated: the soak never reaches here (no drama, no rng, no
## estate write), so it can never perturb the receipt or a real user's ledger.
func _hang_epitaph(loser: int, winner: int) -> void:
	if not _drama_visible():
		return
	var epitaph := String(EPITAPHS[_drama_prng.randi_range(0, EPITAPHS.size() - 1)])
	_epitaphs[loser] = epitaph
	_render_epitaph(loser, epitaph)
	# The estate keeps the last word — persisted at heir-crowning, like the heir
	# monument, and only when this is real play (autoplay probes never write).
	if not _autoplay:
		EstateState.add_graffiti(Dialog.text("procession.epitaph_graffiti") % [
			String(roster[winner].name), String(roster[loser].name), epitaph])

## Ride a small IM Fell gravestone tag on the loser's pawn (matches the pawn
## name-tag idiom; a child of the pawn node so it follows every hop). Reused if the
## seat already carries one — a fresh defeat re-carves the stone.
func _render_epitaph(seat: int, epitaph: String) -> void:
	if board == null or not board.pawns.has(seat):
		return
	var pawn: Node3D = board.pawns[seat]
	var tag: Label3D
	if _epitaph_tags.has(seat) and is_instance_valid(_epitaph_tags[seat]):
		tag = _epitaph_tags[seat]
	else:
		tag = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 30
		tag.pixel_size = 0.0056
		tag.outline_size = 12
		tag.outline_modulate = Color(0, 0, 0, 0.92)
		tag.modulate = Color(0.86, 0.83, 0.74)   # bone / carved parchment
		tag.position = Vector3(0, 1.9, 0)          # above the name tag (1.5)
		var serif: FontFile = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
		if serif != null:
			tag.font = serif
		pawn.add_child(tag)
		_epitaph_tags[seat] = tag
	tag.text = "“%s”" % epitaph

## Windowed capture only: pose a close hero on the freshly-carved loser so the
## epitaph tag reads in the verification still, then hand the camera back to the
## director (the cascade's next shot re-activates it). Never headless.
func _snap_epitaph(loser: int) -> void:
	if not _capture or board == null or not board.pawns.has(loser):
		return
	board_camera.hold()
	var pawn: Node3D = board.pawns[loser]
	var p := pawn.global_position
	var out := p - board.CENTER
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	# A closer, gently raked-down hero so the carved tag (y≈1.9) reads centred with
	# ground behind it, not the distant manor label.
	cam.global_position = p + out * 2.3 + Vector3(0, 2.9, 0)
	cam.look_at(p + Vector3(0, 1.75, 0), Vector3.UP)
	await _cap_snap("epitaph")

# --------------------------------------------------------------------------
# MINIGAME BLOCK  (every 2nd round)
# --------------------------------------------------------------------------
func _minigame_block() -> void:
	_phase = "minigame"
	executor.clear_banner()
	# item offer — a quick shop beat: each seat is handed a random item (EVENT
	# stream; the ribbon aims itself at the race leader inside _grant_item).
	for i in roster.size():
		_grant_item(i)
	# The EVENT stream picks the game; the roulette (F22) is theater that lands
	# on it, then calls "TAKE YOUR PLACES" (the estate's voice, doc 26).
	var mid: String = CONTRACT_POOL[_event_rng.randi_range(0, CONTRACT_POOL.size() - 1)]
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
	# RECKONING — placements pay 5/3/2/1 Grudge.
	_phase = "reckoning"
	var lines: Array[String] = []
	for rank in placements.size():
		var p := int(placements[rank])
		var pay: int = POINTS[rank] if rank < POINTS.size() else 0
		grudge[p] += pay
		lines.append(Dialog.text("procession.reckoning.line") % [roster[p].name, rank + 1, pay])
	_announce_text(Dialog.text("procession.reckoning.header") + "\n\n" + "\n".join(lines), Color(0.95, 0.85, 0.6))
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
	module.begin({"roster": mroster, "rounds": 2, "rng_seed": _event_rng.randi(), "practice": false})
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
	# Fisher-Yates with the EVENT stream — deterministic, unbiased.
	for i in range(order.size() - 1, 0, -1):
		var j := _event_rng.randi_range(0, i)
		var t = order[i]; order[i] = order[j]; order[j] = t
	return order

# --------------------------------------------------------------------------
# THE HOUSE AWAKENS  (every 3rd round — all-in survivathon)
# --------------------------------------------------------------------------
func _house_awakens() -> void:
	_phase = "house"
	executor.clear_banner()
	executor.gesture_house_rise()   # B2-HOOK: the host rises (F7)
	_announce_text(Dialog.text("procession.house_awakens.header") + "\n\n" + Executor.pick(Executor.HOUSE_AWAKENS, _voice_rng),
		Color(1, 0.4, 0.35))
	if final_kit:
		final_kit.escalate()
	await _beat(2.4)
	# Safe stones: a seeded handful of the graph (EVENT stream). Each pawn on
	# the road "putts" for safety; those who miss slip back 2 stones ALONG
	# THEIR OWN WALKED TRAIL (a graph has no minus-two; the estate remembers
	# where you stepped). Home pawns are untouchable.
	var safe := {}
	for k in 8:
		safe[_event_rng.randi_range(0, board.node_count() - 1)] = true
	var caught: Array[String] = []
	for i in roster.size():
		var reached := _event_rng.randf() < (0.45 + 0.1 * float(deeds[i] == 0))
		if bool(arrived[i]):
			continue
		if not reached and not safe.has(positions[i]):
			_slip_back(i, 2)
			caught.append(String(roster[i].name))
			stats[i].lost += 1
	if caught.is_empty():
		_announce_text(Dialog.text("procession.house_awakens.header") + "\n\n" + Dialog.text("procession.house_awakens.safe"),
			Color(0.7, 0.85, 1.0))
	else:
		_announce_text(Dialog.text("procession.house_awakens.header") + "\n\n" + ", ".join(caught) + Dialog.text("procession.house_awakens.slip_suffix"),
			Color(1, 0.55, 0.4))
	_refresh_hud()
	_push_net()
	await _beat(2.2)
	_hide_announce()
	# THE INTERIM READING (W1): read the running will-clause leaders so the secret
	# race announced at minute 0 is felt all night. Skipped under the soak/all-bots.
	await _interim_reading()
	if final_kit and final_kit.has_method("round_reset"):
		final_kit.round_reset()

# --------------------------------------------------------------------------
# WIN CHECK + CEREMONIES
# --------------------------------------------------------------------------
## Retrace the seat's own walked trail `steps` stones (THE HOUSE AWAKENS).
func _slip_back(seat: int, steps: int) -> void:
	var t: Array = trail[seat]
	for _k in steps:
		if t.size() > 1:
			t.pop_back()
	positions[seat] = int(t.back())
	board.seat_pawn(seat, positions[seat])

## The night closes when everyone is home, or one full round after THE FINAL
## BELL rang (doc 28: every other player gets exactly one more turn).
func _check_win() -> bool:
	var all_home := true
	for i in roster.size():
		if not bool(arrived[i]):
			all_home = false
			break
	if all_home:
		return true
	return bell_round >= 0 and round_num >= bell_round + 1

func _will_reading() -> void:
	_phase = "will"
	executor.clear_banner()
	Music.play_slot("ceremony")
	executor.say(Executor.pick(Executor.WILL_OPEN, _voice_rng), Color(0.85, 0.75, 1.0))
	var lines: Array[String] = []
	for c in clauses:
		var winner_seat := _stat_leader(String(c.stat))
		if winner_seat >= 0:
			deeds[winner_seat] += 1
			stats[winner_seat].will_bonus = int(stats[winner_seat].get("will_bonus", 0)) + 1
			_pop_grudge(winner_seat, 1, "◆")   # F10: the bonus Deed flies to the chip
			lines.append(Dialog.text("procession.will_reading.line") % [
				c.title, roster[winner_seat].name, c.desc, deeds[winner_seat]])
		else:
			lines.append(Dialog.text("procession.will_reading.unclaimed") % c.title)
	# Clear the executor's opening line so it does not sit behind the card.
	executor.clear_banner()
	_announce_text(Dialog.text("procession.will_reading.header") + "\n\n" + "\n".join(lines), Color(0.85, 0.78, 1.0))
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
			"label": Dialog.text("procession.heir.monument") % [pl.name, deeds[winner]],
			"night": EstateState.nights_played,
			"kind": "heir",
		})
		EstateState.add_graffiti(Dialog.text("procession.heir.graffiti") % pl.name)
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
	# The seed is verification plumbing — real heirs get a clean crown.
	var crown := Dialog.text("procession.heir.crown_gate") % pl.name
	if _autoplay:
		crown += " · SEED %d" % seed_value
	_announce_text(crown, Color(pl.color))
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

## The night's standings: arrival order first (crossing beats everything),
## then the DISTANCE RANKING (fewest stones to the gate — the doc 28 §8
## turn-cap fallback), then grudge, then seat. Every tie explicit and stable.
func _final_order() -> Array:
	var order: Array = []
	for i in roster.size():
		order.append(i)
	order.sort_custom(func(a, b):
		var aa := arrival_order.find(a)
		var bb := arrival_order.find(b)
		if (aa >= 0) != (bb >= 0):
			return aa >= 0
		if aa >= 0 and bb >= 0 and aa != bb:
			return aa < bb
		var da := board.dist_to_gate(positions[a])
		var db := board.dist_to_gate(positions[b])
		if da != db:
			return da < db
		if grudge[a] != grudge[b]:
			return grudge[a] > grudge[b]
		return a < b)
	return order

func _emit_tally() -> void:
	var routes: Array = []
	var left: Array = []
	for i in roster.size():
		routes.append(board.route_of(positions[i]))
		left.append(board.dist_to_gate(positions[i]))
	var tally := {
		"seed": seed_value, "board": String(BoardGraph.BOARD.id), "rounds": round_num,
		"turn_cap": turn_cap, "bell_round": bell_round,
		"heir": winner, "heir_name": String(roster[winner].name),
		"arrivals": arrival_order.duplicate(),
		"grudge": grudge.duplicate(), "deeds": deeds.duplicate(),
		"moved": moved_total.duplicate(), "positions": positions.duplicate(),
		"routes": routes, "left": left,
	}
	print("PROCESSION_TALLY ", JSON.stringify(tally))
	for i in roster.size():
		var home := arrival_order.find(i)
		print("  seat %d %s: ◆%d  %d♠  moved=%d  pos=%d  route=%s  left=%d%s" % [
			i, roster[i].name, deeds[i], grudge[i], moved_total[i], positions[i],
			routes[i], int(left[i]), ("  HOME#%d" % (home + 1)) if home >= 0 else ""])
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
	var routes: Array = []
	for i in roster.size():
		routes.append(board.route_of(positions[i]) if board else "common")
	return {
		"phase": _phase, "round": round_num,
		"grudge": grudge.duplicate(), "deeds": deeds.duplicate(),
		"positions": positions.duplicate(), "moved": moved_total.duplicate(),
		"routes": routes, "arrived": arrived.duplicate(),
		"arrival_order": arrival_order.duplicate(), "bell_round": bell_round,
		"banner": _reveal.get_parsed_text() if _reveal and _reveal.visible else "",
	}

func _net_apply(state: Dictionary) -> void:
	_phase = String(state.get("phase", _phase))
	round_num = int(state.get("round", round_num))
	grudge.assign(state.get("grudge", grudge))
	deeds.assign(state.get("deeds", deeds))
	positions.assign(state.get("positions", positions))
	moved_total.assign(state.get("moved", moved_total))
	arrived = state.get("arrived", arrived)
	arrival_order = state.get("arrival_order", arrival_order)
	bell_round = int(state.get("bell_round", bell_round))
	if board:
		for i in mini(positions.size(), roster.size()):
			board.seat_pawn(i, positions[i])
	_refresh_hud()
	var banner_text := String(state.get("banner", ""))
	if _reveal:
		if banner_text.is_empty():
			_reveal.visible = false
		else:
			executor.say(banner_text, Color.WHITE)
