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
##   STIRS  — _stirs_rng: THE ESTATE STIRS draws (event pools + their site
##            picks, doc 28 §4). Its own stream so the estate's hand can
##            never shift a séance, an item, or a roll — and vice versa.
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
const CartPrompt := preload("res://estate/procession/cart_prompt.gd")
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
# ---- THE MINIGAME CATALOG, UNIFIED (doc 28 §15): one registry, all 15 games
# (estate.gd MODULES minus the mock exhibition), drawn WITHOUT replacement per
# night; THE INVITATION item overrides one draw. Catalog metadata: launch kind
# (Par is a legacy launcher — landmine 3 — simulated until the P3 adapter) and
# team shape (Pallbearers settles 2v2: teammates get equal-tier pay).
const MINIGAME_ORDER: Array[String] = ["par", "echo", "tilt", "orbital",
	"mower", "greed", "swap", "deadweight", "throne", "lastwill",
	"widowsgaze", "seance", "understudy", "maskedball", "pallbearers"]
## THE OVERNIGHT FAMILY (producer ruling 2026-07-20, doc 28 §2 refined): the
## theater trio plays ONLY as the between-nights interlude — never in the
## round rotation — and the interlude draws ONLY from it. Exclusive both
## directions. Interlude 1 = the estate's random deal, announced by the
## Executor; interlude 2 = the DOORMAT's privilege from the remaining two.
const THEATER_ORDER: Array[String] = ["seance", "understudy", "maskedball"]
## The round-cycle registry: MINIGAME_ORDER minus the theater trio.
const CYCLE_ORDER: Array[String] = ["par", "echo", "tilt", "orbital",
	"mower", "greed", "swap", "deadweight", "throne", "lastwill",
	"widowsgaze", "pallbearers"]
const MINIGAMES := {
	"par": {"name": "PAR FOR THE CURSE", "scene": "res://scenes/main.tscn", "launch": "legacy", "team": "ffa"},
	"echo": {"name": "ECHO CHAMBER", "scene": "res://minigames/echo_chamber/echo_chamber.tscn", "launch": "contract", "team": "ffa"},
	"tilt": {"name": "TILT", "scene": "res://minigames/tilt/tilt.tscn", "launch": "contract", "team": "ffa"},
	"orbital": {"name": "ORBITAL DODGEBALL", "scene": "res://minigames/orbital/orbital.tscn", "launch": "contract", "team": "ffa"},
	"mower": {"name": "MOWER MAYHEM", "scene": "res://minigames/mower/mower.tscn", "launch": "contract", "team": "ffa"},
	"greed": {"name": "GREED INC.", "scene": "res://minigames/greed/greed.tscn", "launch": "contract", "team": "ffa"},
	"swap": {"name": "SWAP MEET", "scene": "res://minigames/swap_meet/swap_meet.tscn", "launch": "contract", "team": "ffa"},
	"deadweight": {"name": "DEAD WEIGHT", "scene": "res://minigames/dead_weight/dead_weight.tscn", "launch": "contract", "team": "ffa"},
	"throne": {"name": "THE THRONE", "scene": "res://minigames/throne/throne.tscn", "launch": "contract", "team": "ffa"},
	"lastwill": {"name": "LAST WILL", "scene": "res://minigames/last_will/last_will.tscn", "launch": "contract", "team": "ffa"},
	"widowsgaze": {"name": "THE WIDOW'S GAZE", "scene": "res://minigames/widows_gaze/widows_gaze.tscn", "launch": "contract", "team": "ffa"},
	"seance": {"name": "THE SÉANCE", "scene": "res://minigames/seance/seance.tscn", "launch": "contract", "team": "ffa"},
	"understudy": {"name": "THE UNDERSTUDY", "scene": "res://minigames/understudy/understudy.tscn", "launch": "contract", "team": "ffa"},
	"maskedball": {"name": "MASKED BALL", "scene": "res://minigames/masked_ball/masked_ball.tscn", "launch": "contract", "team": "ffa"},
	"pallbearers": {"name": "PALLBEARERS", "scene": "res://minigames/pallbearers/pallbearers.tscn", "launch": "contract", "team": "2v2"},  # B7-HOOK
}
# The economy heartbeat (doc 28 §6): minigame settlement per cycle.
const MINI_PENNIES := [10, 6, 3, 1]
const MINI_WREATHS := [2, 1, 1, 0]

signal night_over(tally: Dictionary)

# ---- night state (the tally reads out of these) ----
var seed_value := 0
var roster: Array = []
var grudge: Array[int] = []         # PENNIES on screen (internal name kept — RC §3:
                                    # 14 minigame receipts reference "grudge")
var wreaths: Array[int] = []        # THE victory currency (doc 28 §6) — persists all match
var positions: Array[int] = []      # per seat: current GRAPH NODE id
var moved_total: Array[int] = []
var trail: Array = []               # per seat: Array[int] walked node history (slip-backs)
var arrived: Array = []             # per seat: bool — through the Manor Gate (home, untouchable)
var arrival_order: Array = []       # seats in gate-crossing order
var bell_round := -1                # round THE FINAL BELL rang (-1 = still open)
var turn_cap := 12                  # doc 28 §8 rule 4 — distance ranking backstop
var items: Array = []               # per seat: Dictionary ware_id -> count (cap 3 total)
var stats: Array = []               # per seat: will-clause + award stat dict (per NIGHT)
# ---- THE PEDDLER'S CART item state (P2; guardrails per doc 28 §15) ----
var pending_die: Array[int] = []    # per seat: armed WRIT die (0 = the d8)
var pending_lucky: Array[int] = []  # per seat: armed LUCKY PENNY bonus steps
var debt_traps := {}                # node_id -> owner seat (WREATH OF DEBT)
var _move_item_used := false        # max ONE die/movement item per turn
var _offense_hit := {}              # per turn: target seat -> true (no-stack per target)
var _wisp_dest := -1                # WILL-O'-THE-WISP teleport (replaces the roll)
# ---- THE BOOK OF THE DEAD (doc 32 v1 — sealed side-bets, cosmetic) ----
var book: ProcessionBook = null     # the per-seat bet surface (UI builds it)
var _cycle_mini := ""               # this cycle's game, drawn at roll-phase start
var _laurel_next: Array = []        # per seat: correct bet -> laurel wisp next cycle
var _cart_demoed := false           # capture poses the cart UI once (P2 screenshot b)
var round_num := 0
var winner := -1
# ---- THE 3-NIGHT MATCH (doc 28 §2; landmine 1: night_length means games-per-
# night in the estate shell — this is a NEW field, never that one) ----
var match_nights := 3               # --nights=N; estate merge passes config.match_nights
var night_index := 1                # 1-based, current night
# Escalating FINAL BELL arrival wreaths by night (doc 28 §15 — night 3 can
# never be ceremonial). Crossing order first, then dist_to_gate ranking.
const ARRIVAL_WREATHS := [[8, 5, 3, 1], [10, 6, 3, 2], [12, 7, 4, 2]]
var wreath_src: Array = []          # per seat {arrival, mini, award, liquid} — THE READING streams
var mini_wins_match: Array[int] = []   # match-level minigame wins (LETTERS + finale tie-break)
var board_firsts: Array[int] = []      # nights finished #1 on the board (finale tie-break 1)
var night_final_rank: Array[int] = []  # board rank on the LAST night (finale tie-break 2)
var letters: Array = []             # per seat: LETTERS OF ADMINISTRATION active tonight
var _mini_pool: Array = []          # per-night draw-without-replacement pool
var _invitation_pick := ""          # THE INVITATION override for the next draw
var _interlude1_pick := ""          # interlude 1's game — later interludes may not repeat it (doc 28 §2)
var _started := false
var _autoplay := false
var _fast := false
var _minisim := true
var _mirror := false
var _capture := false            # windowed: pose beats + snap for screenshots
var _vendettatest := false       # dev flag: force the board-drama presentation with bot data (screenshots)
var _longnames := false          # dev flag (W9): worst-case long names to stress the text surfaces
var _graphtest := false          # --boardgraphtest: print the topology receipt and quit
var _stirnettest := false        # --stirnettest: host snapshot -> fresh mirror replay probe
var _walk := false               # --walk: dev walkabout on the grounds, no night
var _parprobe := false           # --parprobe: run the legacy Par adapter once, print, quit
# ---- the NAMED rng streams (header doctrine; LAYOUT lives in board_graph) ----
var _roll_rng := RandomNumberGenerator.new()     # ROLL: band deals, bot aim, bot road picks
var _event_rng := RandomNumberGenerator.new()    # EVENT: séance, items, minigame pick, house
var _voice_rng := RandomNumberGenerator.new()    # VOICE: Executor line picks (presentation)
var _drama_prng := RandomNumberGenerator.new()   # DRAMA: interim lines + epitaph pick (presentation)
var _stirs_rng := RandomNumberGenerator.new()    # STIRS: the estate's own hand (doc 28 §4)

# ---- THE ESTATE STIRS (doc 28 §4) ----
var stirs := ProcessionStirs.new()   # this game's drawn events + live minor state
var _stir_force_major := ""          # --stir=major[,minor] dev override (probes/stills)
var _stir_force_minor := ""
# Host keeps the mutation receipts because a latest-state snapshot must be
# sufficient for a guest arriving after either event fired. Clients keep a
# separate id guard: the 20 Hz channel repeats facts, never commands.
var _stir_info_by_id := {}            # event id -> receipt-shaped info Dictionary
var _stir_replayed := {}              # client event id -> true (topology already applied)
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
# ---- P3 presentation state ----
var _os_shown := 0                 # over-shoulder roll shots shown (1st eases in; later ones cut; skippable after the 1st)
var _award_tracker: PanelContainer = null   # doc 28 §9c: the 3 announced races, compact + live
var _award_rows: Array = []        # per-race {title: Label, lead: Label}
var _tracker_live := false         # armed at the first interim reading each night

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
var _chips: Array = []               # per seat: {badge, grudge_lbl}
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
	# THE A-LOOK heatmap: brightness = probability, no percents. Pass the live
	# crit-band state so a crit-release prospect sharpens the contrast.
	board.show_heatmap(entries, roster[seat].color, breath.in_crit_band())

## Announced movement bonuses that shift every face's landing (an armed LUCKY
## PENNY). Kept honest: the heatmap must glow the stones you will actually reach.
func _pending_steps_bonus(seat: int) -> int:
	return pending_lucky[seat] if seat < pending_lucky.size() else 0

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
	if config.has("match_nights"):
		match_nights = clampi(int(config.match_nights), 1, 5)
	# Seed the NAMED streams (header doctrine). Distinct affine salts per stream
	# so no draw in one can ever shift another; presentation streams can never
	# shift the tally at all.
	_roll_rng.seed = seed_value * 1103515245 + 12345
	_event_rng.seed = seed_value * 22695477 + 1
	_voice_rng.seed = seed_value * 134775813 + 5
	_drama_prng.seed = seed_value * 2246822519 + 3266489917
	# STIRS — its own named stream (doc 28 §15): the estate's own hand. No
	# stirs draw can shift a séance, an item, or a roll — and vice versa.
	_stirs_rng.seed = seed_value * 747796405 + 2891336453
	roster = config.get("roster", []) if config.has("roster") else _default_roster()
	if _longnames:
		_apply_longnames()   # W9: stress the text surfaces with worst-case names
	# P3: a real couch plays the REAL minigames (they are the board's engine
	# room, doc 28 §0). Probes and all-bot soaks keep the deterministic
	# minisim; --realmini still forces live modules for bot tables.
	if not _autoplay and _has_human():
		_minisim = false
	_init_arrays()
	_build_world()
	_build_hud()
	_choose_clauses()
	# The soak compresses real time: under _fast the LAST BREATH queue resolves
	# in a single frame per turn (no live sweep), so time_scale only speeds the
	# ceremonies — the tally stays byte-identical. Windowed play runs at 1.0.
	if _autoplay and _fast:
		Engine.time_scale = 8.0
	print("PROCESSION boot seed=%d board=%s turn_cap=%d nights=%d players=%d autoplay=%s minisim=%s" % [
		seed_value, String(BoardGraph.BOARD.id), turn_cap, match_nights, roster.size(),
		str(_autoplay), str(_minisim)])
	# THE ESTATE STIRS (doc 28 §4): drawn per GAME, announced as omens at the
	# intro, fired at fixed night beats. The draw is part of the match receipt.
	stirs.draw(_stirs_rng, _stir_force_major, _stir_force_minor)
	print("PROCESSION_STIRS major=%s minor=%s" % [stirs.major, stirs.minor])
	if _stirnettest:
		_stirnettest_run()
		return
	if _parprobe:
		_parprobe_run()   # dev probe: the legacy Par adapter, alone, then quit
		return
	if _walk:
		_enter_walk_mode()   # dev walkabout: the grounds, a body, no night
		return
	_run_match()

## DEV WALKABOUT (`--walk`, producer request — review the procession's course
## on foot without playing a night). Hides the match HUD, spawns a stroller
## at the lychgate, and live-tests the A-LOOK approach-reveal contract.
func _enter_walk_mode() -> void:
	_phase = "walkabout"
	if _ui != null:
		_ui.visible = false
	if breath != null and breath.meter != null:
		breath.meter.visible = false
	# the toys stay home — the review walk owns the road
	for s in pawns_seatlist():
		board.seat_pawn(s, 0)
	var stroller := GroundsWalk.new()
	add_child(stroller)
	stroller.setup(board, String(CHAR_SCENES[0]), GameState.PLAYER_COLORS[0])
	# the stroller tramples the living lawn as it wanders (presentation only)
	if board.grass_field != null:
		board.grass_field.register_bender(stroller, GrassField.STROLLER_RADIUS)
	print("PROCESSION walkabout: stick/WASD walk, hold A trot, ESC to leave")

func pawns_seatlist() -> Array:
	var out: Array = []
	for i in roster.size():
		out.append(i)
	return out

## Dev probe (`--parprobe`, never on a receipt): exercise the P3 legacy Par
## adapter end-to-end — real launch, real finish signal, validated placements
## — then quit. Pair with --autoplay=bots for an unattended run.
func _parprobe_run() -> void:
	_minisim = false
	print("PARPROBE launching legacy par via the catalog adapter")
	var placements: Array = await _run_minigame("par")
	print("PARPROBE placements=", placements)
	get_tree().quit()

func _parse_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--turncap="):
			turn_cap = clampi(int(arg.trim_prefix("--turncap=")), 4, 40)
		elif arg.begins_with("--nights="):
			# The 3-NIGHT MATCH dial (landmine 1: never the estate's night_length,
			# which means games-per-night). --nights=1 is the single-night probe.
			match_nights = clampi(int(arg.trim_prefix("--nights=")), 1, 5)
		elif arg.begins_with("--deedgoal=") or arg.begins_with("--preset="):
			# Ring-era dials, retired with the Codicil (doc 28). Accepted so old
			# command lines don't crash; they change nothing.
			print("PROCESSION note: %s is retired on the graph board (use --turncap=N)" % arg.split("=")[0])
		elif arg == "--boardgraphtest":
			_graphtest = true     # topology receipt: nodes/edges/routes/ratios/reach
		elif arg == "--stirnettest":
			# Headless only: fire the forced pair, snapshot it, and apply that
			# snapshot twice to a fresh mirror board.
			_stirnettest = true
			_autoplay = true
			_fast = true
			_minisim = true
		elif arg.begins_with("--autoplay="):
			_autoplay = true
			_fast = true
			_minisim = true
		elif arg == "--realmini":
			_minisim = false     # launch real modules even under autoplay
		elif arg == "--parprobe":
			_parprobe = true     # dev: run the legacy Par adapter once and quit
		elif arg == "--slowsim":
			_fast = false         # keep ceremonies at full length (for capture)
		elif arg == "--walk":
			_walk = true          # dev walkabout: stroll the grounds, no night
		elif arg == "--vendettatest":
			_vendettatest = true  # force the board-drama presentation with bot data (see _boot)
		elif arg == "--longnames":
			_longnames = true     # W9: force worst-case long names to stress the text surfaces
		elif arg.begins_with("--stir="):
			# Dev: force this game's Estate Stirs draw — "--stir=bone_bridge" or
			# "--stir=landslip,flood" (major[,minor]). Unknown names fall back to
			# the seeded draw. Frozen receipts use the natural draw.
			var parts := arg.trim_prefix("--stir=").split(",")
			for p in parts:
				var s := String(p).strip_edges()
				if s in ProcessionStirs.MAJORS:
					_stir_force_major = s
				elif s in ProcessionStirs.MINORS:
					_stir_force_minor = s

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
	grudge.resize(n); positions.resize(n); moved_total.resize(n)
	wreaths.resize(n)
	mini_wins_match.resize(n)
	board_firsts.resize(n)
	night_final_rank.resize(n)
	wreath_src.clear()
	letters.clear()
	for i in n:
		wreaths[i] = 0
		mini_wins_match[i] = 0
		board_firsts[i] = 0
		night_final_rank[i] = 0
		wreath_src.append({"arrival": 0, "mini": 0, "award": 0, "liquid": 0})
		letters.append(false)
	_mini_pool = CYCLE_ORDER.duplicate()
	_invitation_pick = ""
	_interlude1_pick = ""
	pending_die.resize(n)
	pending_lucky.resize(n)
	for i in n:
		pending_die[i] = 0
		pending_lucky[i] = 0
	debt_traps.clear()
	_wisp_dest = -1
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
		positions[i] = 0                # node 0 = THE LYCHGATE
		moved_total[i] = 0
		trail.append([0])               # walked history (slip-backs retrace it)
		arrived.append(false)
		items.append({})                # ware_id -> count (the priced cart's economy)
		stats.append({"moved": 0, "graves": 0, "lost": 0, "duels": 0,
			"shrines": 0, "deeds_bought": 0, "spent": 0,
			"hazards": 0, "seances": 0, "mini_wins": 0})

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
	board_camera.trace = _capture   # stills-lane forensics (CAMTRACE lines)

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

	# P3 FIX: the strip was anchored BOTTOM_WIDE with zero height before its
	# children existed, then grew DOWNWARD — every chip rendered off-screen
	# (visible in P2's own committed stills). Pin the height, grow UP, and
	# split the row around a centre gap so the LAST BREATH meter (bottom-
	# centre, its own layer) is never occluded — doc 28 §9's standings strip,
	# actually on screen.
	var chiprow := HBoxContainer.new()
	chiprow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	chiprow.alignment = BoxContainer.ALIGNMENT_CENTER
	chiprow.add_theme_constant_override("separation", 22)
	chiprow.offset_top = -152
	chiprow.offset_bottom = -14
	chiprow.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
		var badge := PlayerBadge.make(i, 24)
		badge.color = roster[i].color
		row.add_child(badge)
		var col := VBoxContainer.new()
		row.add_child(col)
		# P3 standings strip (doc 28 §9): rank + name, ROUTE icon line, purse,
		# held-item glyphs (cap 3) — a waiting seat answers "where is everyone
		# / what do they hold" at a glance. Compact faces: two chips must fit
		# each side of the meter's centre lane at 1080p.
		var name_l := _chip_label(String(roster[i].name), 24, roster[i].color)
		col.add_child(name_l)
		var route_l := _chip_label("", 15, Color(0.8, 0.78, 0.7))
		col.add_child(route_l)
		var stat_l := _chip_label("—", 24, Color(0.95, 0.95, 1.0))
		col.add_child(stat_l)
		var items_l := _chip_label("", 15, Color(0.93, 0.82, 0.52))
		items_l.visible = false
		col.add_child(items_l)
		panel.size_flags_vertical = Control.SIZE_SHRINK_END
		chiprow.add_child(panel)
		_chips.append({"grudge": stat_l, "panel": panel, "name": name_l,
			"route": route_l, "items": items_l})
		if i == 1:
			# The meter gap: seats 0-1 ride left of the LAST BREATH meter,
			# seats 2-3 right of it. The instrument's lane stays clear.
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(700, 0)
			chiprow.add_child(gap)

	# THE BOOK OF THE DEAD rides its own control above the chips (doc 32):
	# per-seat hint + strip + wax seals, anchored to the chip row it was born
	# under. Added after the chips so it always draws over them.
	_laurel_next.resize(roster.size())
	_laurel_next.fill(false)
	book = ProcessionBook.new()
	_ui.add_child(book)
	book.setup(self, roster)

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

	# P3 — THE THREE RACES (doc 28 §9c): a compact live tracker of the night's
	# 3 announced award races, pinned top-right under the objective. Armed at
	# the interim reading, refreshed with the HUD, disarmed at settlement.
	# House scrim chrome; never near the meter's bottom-center layer.
	_award_tracker = PanelContainer.new()
	_award_tracker.name = "AwardTracker"
	_award_tracker.anchor_left = 1.0; _award_tracker.anchor_right = 1.0
	_award_tracker.anchor_top = 0.0; _award_tracker.anchor_bottom = 0.0
	_award_tracker.offset_left = -470.0; _award_tracker.offset_right = -14.0
	_award_tracker.offset_top = 66.0
	_award_tracker.add_theme_stylebox_override("panel", _scrim_box(Color(0.05, 0.045, 0.08, 0.85)))
	_award_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_award_tracker.visible = false
	_ui.add_child(_award_tracker)
	var tr_col := VBoxContainer.new()
	tr_col.add_theme_constant_override("separation", 2)
	_award_tracker.add_child(tr_col)
	var tr_head := _chip_label(Dialog.text("procession.tracker.header"), 20, Color(0.85, 0.78, 1.0))
	tr_col.add_child(tr_head)
	_award_rows.clear()
	for _k in 3:
		var tr_row := HBoxContainer.new()
		tr_row.add_theme_constant_override("separation", 10)
		tr_col.add_child(tr_row)
		var t_l := _chip_label("", 19, Color(0.78, 0.72, 0.88))
		tr_row.add_child(t_l)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr_row.add_child(sp)
		var l_l := _chip_label("", 19, Color(0.95, 0.95, 1.0))
		tr_row.add_child(l_l)
		_award_rows.append({"row": tr_row, "title": t_l, "lead": l_l})

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

## A pennies (or wreath) delta popup at the seat's pawn, arcing to its
## chip. glyph carries the currency ("" = the penny glyph from the display
## seam); the sign + glyph mean it never reads as colour alone.
func _pop_grudge(seat: int, amount: int, glyph := "") -> void:
	if _fast or fx == null or amount == 0:
		return
	var g := glyph if glyph != "" else Spaces.PENNY_GLYPH
	fx.fly_number(amount, g, _pawn_src(seat), _chip_screen_pos(seat), roster[seat].color)

## A grudge TRANSFER: the value lifts off the payer's pawn and flies to the
## collector's chip in the COLLECTOR's colour — the MP "Orb" toll, made visible.
func _pop_transfer(from_seat: int, to_seat: int, amount: int) -> void:
	if _fast or fx == null or amount <= 0:
		return
	fx.fly_number(amount, Spaces.PENNY_GLYPH, _pawn_src(from_seat), _chip_screen_pos(to_seat), roster[to_seat].color)

## A flying number lifting off a fixed world point (a stone, a gate) rather than a
## pawn — used for pass-through tolls where the payer is mid-hop.
func _pop_at(world_from: Vector3, seat_target: int, amount: int, color: Color) -> void:
	if _fast or fx == null or amount == 0:
		return
	fx.fly_number(amount, Spaces.PENNY_GLYPH, world_from, _chip_screen_pos(seat_target), color)

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
		# the BOOK announcement (doc 32): the cycle's drawn game rides the
		# round strip so every bet is an informed one
		var mini_tag := ""
		if _cycle_mini != "" and MINIGAMES.has(_cycle_mini):
			mini_tag = "   📖 %s" % String((MINIGAMES[_cycle_mini] as Dictionary).name)
		_round_lbl.text = "ROUND %d / %d%s" % [round_num, turn_cap, mini_tag]
	if _objective_lbl:
		if bell_round >= 0:
			_objective_lbl.text = "☠ THE BELL HAS RUNG — LAST TURN"
		else:
			_objective_lbl.text = "LYCHGATE → MANOR GATE"
	# PENNIES + WREATHS on every chip (P2 display seam — internal names keep
	# "grudge"; the couch reads the two currencies at a glance, doc 28 §0).
	# P3 adds the standings strip reads: wreath rank on the name, ROUTE icon,
	# and the held-item glyph row (cap 3) — doc 28 §9's thinking budget.
	var standing := _roll_order()
	for i in _chips.size():
		var purse := "%d%s  %s%d" % [grudge[i], Spaces.PENNY_GLYPH,
			Spaces.WREATH_GLYPH, wreaths[i]]
		if bool(arrived[i]):
			_chips[i].grudge.text = "%s  HOME #%d" % [
				purse, arrival_order.find(i) + 1]
		else:
			_chips[i].grudge.text = "%s  %d⚑" % [
				purse, board.dist_to_gate(positions[i]) if board else 0]
		if _chips[i].has("name"):
			_chips[i].name.text = "#%d %s" % [standing.find(i) + 1, roster[i].name]
			var route_l: Label = _chips[i].route
			if bool(arrived[i]):
				route_l.text = "⌂ HOME"
				route_l.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
			elif board != null:
				var rt := board.route_of(positions[i])
				if rt == "common":
					route_l.text = "▸ THE DRIVE"
					route_l.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
				else:
					var ri := board.route_info(rt)
					route_l.text = "▸ %s" % String(ri.label)
					route_l.add_theme_color_override("font_color",
						Color(ri.color).lerp(Color.WHITE, 0.25))
			var glyphs: Array[String] = []
			var ids: Array = items[i].keys() if i < items.size() else []
			ids.sort()
			for raw in ids:
				for _c in _count_item(i, String(raw)):
					if glyphs.size() < Spaces.INV_CAP:
						glyphs.append(Spaces.ware_glyph(String(raw)))
			var items_l: Label = _chips[i].items
			items_l.text = " · ".join(glyphs)
			items_l.visible = not glyphs.is_empty()
	_refresh_award_tracker()
	_sync_minimap()

## P3 — refresh THE THREE RACES tracker rows (leader name + running stat).
## Visible only while armed (_tracker_live, set at the interim reading) and
## never under the fast soak. Presentation only: pure reads of stats/awards.
func _refresh_award_tracker() -> void:
	if _award_tracker == null:
		return
	_award_tracker.visible = _tracker_live and not _fast and not night_awards.is_empty()
	if not _award_tracker.visible:
		return
	for k in _award_rows.size():
		var row: Dictionary = _award_rows[k]
		if k >= night_awards.size():
			(row.row as Control).visible = false
			continue
		(row.row as Control).visible = true
		var a: Dictionary = night_awards[k]
		(row.title as Label).text = _award_title(a)
		var lead := _stat_leader(String(a.stat))
		var lead_l := row.lead as Label
		if lead >= 0:
			lead_l.text = "%s %d" % [roster[lead].name, int(stats[lead].get(String(a.stat), 0))]
			lead_l.add_theme_color_override("font_color",
				Color(roster[lead].color).lerp(Color.WHITE, 0.25))
		else:
			lead_l.text = "—"
			lead_l.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))

## Show THE DRIVE inset only during MOVE/REVEAL (place legibility while the camera
## is pushed in), and feed it the current logical positions + Codicil berth. The
## roll owns the corners (meters); ceremonies own the centre (cards). Presentation
## only — reads mirrored state, never the sim.
func _sync_minimap() -> void:
	if _minimap == null:
		return
	# P3 (doc 28 §9b): THE DRIVE stays visible through the ROLL phase too — a
	# waiting seat reads "where is everyone" while the meter sweeps. The inset
	# is top-left; the meter's own CanvasLayer owns bottom-center.
	var show := (_phase == "roll" or _phase == "move" or _phase == "reveal") \
		and (board == null or board.visible)
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
# THE MATCH — 3 nights (doc 28 §2), then THE READING. Wreaths, pennies and
# inventory persist across nights; the board resets between them.
# --------------------------------------------------------------------------
func _run_match() -> void:
	_phase = "intro"
	if final_kit and final_kit.has_method("play_started"):
		final_kit.play_started()
	await _intro()
	for n in range(1, match_nights + 1):
		night_index = n
		await _night_open()
		await _run_night_cycles()
		await _night_settlement()
		if night_index < match_nights:
			# P3 (doc 28 §2): between nights, after the will reading + LAST
			# RITES, the grounds offer ONE more game before the board resets.
			await _interlude_minigame()
			_board_reset()
	await _finale()

## The cycle loop: roll phase → move/resolve → MINIGAME (every cycle, doc 28
## §2) → the odd HOUSE AWAKENS, until the FINAL BELL's one-more-round closes
## it or the turn cap falls (doc 28 §8 rule 4: distance ranks the rest).
func _run_night_cycles() -> void:
	while true:
		round_num += 1
		_refresh_hud()
		await _stir_beat()   # THE ESTATE STIRS — fixed-beat fires (doc 28 §4)
		await _round()
		_stir_tick()         # temporary minors burn down at each round's end
		if _check_win():
			break
		# Once THE FINAL BELL has rung the night is closing — the stragglers get
		# their one roll and nothing else. Blocks only fire on an open road.
		if bell_round < 0:
			await _minigame_block()
		elif book != null and book.active:
			book.slam()   # the bell shuts the book — no game left to bet on
		if bell_round < 0 and round_num % 3 == 0:
			await _house_awakens()
		if round_num >= turn_cap:
			if not _fast:
				_announce_text(Dialog.text("procession.bell.closing"), Color(1, 0.6, 0.4))
				await _beat(2.0)
				_hide_announce()
			break

# --------------------------------------------------------------------------
# THE ESTATE STIRS — fixed-beat firing + ceremonies (doc 28 §4). The SIM
# mutation always applies (headless-identical); only the ceremony is gated.
# --------------------------------------------------------------------------
const STIR_COL := Color(0.64, 0.86, 0.72)   # the estate's sickly announce green
var _flood_fx: Array = []    # shallow-water discs over Garden Row (while flooded)
var _wake_fx: Array = []     # the mourner crowd (while the wake stands)
var _crow_fx: Array = []     # the court in session (until the robbery)

## Fixed beats: MINOR at night 1, top of round 3. Single-night probes also
## take the MAJOR at round 5 (multi-night games fire it at night 2 open).
func _stir_beat() -> void:
	if not stirs.minor_fired and night_index == 1 and round_num == 3:
		await _fire_stir("minor", stirs.minor)
	if not stirs.major_fired and match_nights == 1 and round_num == 5:
		await _fire_stir("major", stirs.major)

## Temporary minors burn down at each round's end; their dressing leaves
## with them.
func _stir_tick() -> void:
	if stirs.flood_left > 0:
		stirs.flood_left -= 1
		if stirs.flood_left == 0:
			_clear_stir_fx(_flood_fx)
	if stirs.wake_left > 0:
		stirs.wake_left -= 1
		if stirs.wake_left == 0:
			_clear_stir_fx(_wake_fx)

func _clear_stir_fx(fx: Array) -> void:
	for n in fx:
		if is_instance_valid(n):
			(n as Node).queue_free()
	fx.clear()

## Fire one drawn event: sim mutation first (always, deterministically),
## then the full camera ceremony — or a silent settle under the soak.
func _fire_stir(kind: String, id: String) -> void:
	if kind == "minor":
		stirs.minor_fired = true
	else:
		stirs.major_fired = true
	var info: Dictionary = stirs.apply(id, board, _stirs_rng)
	# Keep only the public ground truth printed by the receipt. This survives in
	# every later snapshot, making an unreliable latest-state channel safe for
	# both packet loss and a mirror that boots after the mutation.
	_stir_info_by_id[id] = _stir_wire_info(info)
	# The fire line carries the event's ground truth — entry/exit/stone ids
	# and the site — so a receipt can prove WHERE the estate moved, not just
	# that it did. Fixed key order (deterministic).
	var extras := ""
	for k in ["entry", "exit", "from", "to", "node"]:
		if info.has(k):
			extras += " %s=%s" % [k, str(info[k])]
	if info.has("stones"):
		extras += " stones=%s" % JSON.stringify(info.stones)
	if info.has("site"):
		var sv := info.site as Vector3
		extras += " site=(%.1f,%.1f)" % [sv.x, sv.z]
	print("PROCESSION_STIR_FIRE night=%d round=%d kind=%s id=%s%s" % [
		night_index, round_num, kind, id, extras])
	# Ceremony for anyone watching: a live table, or a windowed capture posing
	# the verification stills with bot data. The soak settles silently.
	if _fast or not (_drama_visible() or _capture):
		_stir_settle(id, info)
		return
	await _stir_ceremony(id, info)

## The no-ceremony settle: props land where the mutation says, instantly.
func _stir_settle(id: String, info: Dictionary) -> void:
	match id:
		"bone_bridge":
			var ribs := board.grounds.bone_bridge() if board.grounds != null else null
			if ribs != null:
				ribs.global_position.y = ProcessionGrounds.WATER_Y + BRIDGE_RISE_Y
				ribs.scale *= 1.8
		"hearse_moves":
			if board.cart_prop != null:
				board.cart_prop.global_position = board.cart_park_pos(int(info.to))
			if board.cart_lantern != null:
				board.cart_lantern.global_position = \
					board.cart_park_pos(int(info.to)) + Vector3(0.6, 0, 0.4)
		"flood":
			# The host's full ceremony owns these effects. A mirror never runs a
			# ceremony, so its settle path must stage the already-fired world.
			if _mirror and stirs.flood_left > 0:
				_settle_flood_fx()
		"wake":
			if _mirror and stirs.wake_left > 0:
				_settle_wake_fx(info)
		"crow_court":
			if _mirror and not stirs.crow_done and stirs.crow_stone >= 0:
				_settle_crow_fx(info)

## The full ceremony: the announce card reads over the site shot, then GETS
## OUT OF THE WAY — the effect plays on a clean frame with only the
## Executor's line standing, then the whole changed board reads wide.
## (First cut kept the card up through the effect; the Reaper carved his
## corridor entirely behind it. The card announces; it does not direct.)
func _stir_ceremony(id: String, info: Dictionary) -> void:
	# THE CAMERA LAW, ceremony edition: the director's camera may be DRIVEN
	# yet not CURRENT (a teardown's clear_current promotion is a lottery —
	# H-road rendered the gate camera while ours stood posed at the site).
	# Assert it before every stir, same doctrine as _assert_module_camera.
	# Second clause (the wrong-way stills): no foreign aimer may hold the
	# rotation — the host's per-frame look-at outranked a driving director.
	cam.current = true
	executor.release_camera()
	_reveal_seat = -1
	_apply_reveal_badge(-1)   # the estate speaks — no seat wears this line
	_announce_text("⚱ %s" % ProcessionStirs.title(id), STIR_COL, 30.0)
	executor.say(Dialog.text("procession.stirs.fire.%s" % id), STIR_COL)
	var shot := _stir_shot(id, info)
	board_camera.landing_push(shot)
	if _capture:   # framing debug for the stills lane only — never headless
		print("STIR_SHOT id=%s pos=%s look=%s" % [id, str(shot.pos), str(shot.look)])
	await _beat(1.7)
	_hide_announce()
	await _beat(0.3)
	match id:
		"bone_bridge":
			await _fx_bone_bridge(info)
		"reaper_shortcut":
			await _fx_reaper_shortcut(info)
		"landslip":
			await _fx_landslip(info)
		"procession_road":
			await _fx_procession_road(info)
		"flood":
			await _fx_flood()
		"hungry_grave":
			await _fx_stone_pop(info.get("node", -1))
		"hearse_moves":
			await _fx_hearse_moves(info)
		"wake":
			await _fx_wake(info)
		"crow_court":
			await _fx_crow_court(info)
	await _beat(0.7)
	if _capture:
		print("STIR_SNAP id=%s cam=%s current=%s base=%s look=%s driving=%s" % [id,
			str(board_camera.cam.global_position), str(board_camera.cam.current),
			str(board_camera._base_pos), str(board_camera._base_look),
			str(board_camera._driving)])
		await _cap_snap("stir_%s" % id)
	# The wide is the CHANGED BOARD, whole and wordless — the line already
	# read over the site shot; nothing sits on the estate now.
	executor.clear_banner()
	board_camera.whole_board(0.9)
	await _beat(1.4)
	if _capture:
		await _cap_snap("stir_%s_wide" % id)

## The site framing per event — set pieces get a SIDE-ON shot (never down
## the line: a risen arch swallows an on-axis camera), stone events reuse
## the type-aware reveal vocabulary.
func _stir_shot(id: String, info: Dictionary) -> Dictionary:
	var site := (info.get("site", Vector3.ZERO) as Vector3)
	match id:
		"bone_bridge", "reaper_shortcut", "landslip", "procession_road":
			var a := board.space_pos(int(info.get("entry", info.get("from", 0))))
			var b := board.space_pos(int(info.get("exit", info.get("to", 0))))
			var perp := (b - a).normalized().cross(Vector3.UP)
			if perp.length() < 0.01:
				perp = Vector3.BACK
			# THE NORTH-SIDE LAW (b2 stills): the estate climbs northward, so
			# a camera standing south always eats the manor skyline while the
			# subject sinks under the Executor's band. Stand NORTH of the
			# site, shoot south into the dark rim — the event pops.
			# EXCEPTION — bone_bridge: the north perp stands the lens inside
			# the valley watch-ruin; the east side looks WNW across the span
			# (manor far off-axis) with the dark west rim behind.
			if perp.z > 0.0 and id != "bone_bridge":
				perp = -perp
			# bridge: the 1.8× risen ribs span wide — stand further out or the
			# monument crops at frame edge. road: a lane reads from above, and
			# the low arm put the garden well square between lens and lane.
			var dist := 15.5 if id == "bone_bridge" else 10.0
			var high := 5.5 if id == "bone_bridge" else 4.5
			if id == "procession_road":
				dist = 11.0
				high = 7.0
			return {"pos": site + perp * dist + Vector3(0, high, 0),
				"look": site + Vector3(0, 1.0, 0)}
		"hearse_moves":
			# frame the DESTINATION from the north — the cart treks into frame
			# and parks; the trek's start can stay off-screen. Aim between the
			# park PAD and the new stone so both subjects hold the frame (the
			# cart stops at its pad, never on the stone).
			var to_p := board.space_pos(int(info.to))
			var focus := (to_p + board.cart_park_pos(int(info.to))) * 0.5
			return {"pos": focus + Vector3(3.0, 4.5, -9.0),
				"look": focus + Vector3(0, 1.0, 0)}
		"hungry_grave", "crow_court":
			# The gameplay reveal arm faces the rise (fine with a pawn on the
			# stone; empty ceremony stones lose to the manor skyline) — the
			# stir version obeys the north-side law like the set pieces.
			var np := board.space_pos(int(info.node))
			return {"pos": np + Vector3(1.6, 4.0, -6.5),
				"look": np + Vector3(0, 0.7, 0)}
		"wake":
			# the reveal vocab framed from inside the hollow's canopy — the
			# mourners take the same north-side stone arm as hungry/crow.
			var wp := board.space_pos(int((info.stones as Array)[1]))
			return {"pos": wp + Vector3(1.6, 4.0, -6.5),
				"look": wp + Vector3(0, 0.7, 0)}
		"flood":
			# high enough to read the pooled water OVER the maze hedges
			return {"pos": site + Vector3(2.0, 7.5, -10.5),
				"look": site + Vector3(0, 0.5, 0)}
	return {"pos": site + Vector3(8, 6, 8), "look": site}

## A freshly-born stone pops from the ground (container scale 0 → 1).
func _fx_stone_pop(node_id: int, delay := 0.0) -> void:
	var box := board.stone_container(node_id)
	if box == null:
		return
	box.scale = Vector3(0.001, 0.001, 0.001)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(box, "scale", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

## The risen ribs keep their legs in the water (base 1.35 under the surface)
## so the arch reads as a drowned thing standing up, never bones hovering —
## and the deck stones thread BETWEEN the rib arcs, not on top of them.
const BRIDGE_RISE_Y := -1.35

## MAJOR 2 — the ribs rise IN PLACE from the bog's deep; the deck stones
## surface after them. (No rotation at rise time — the dormant piece was
## already squared onto its claim line, grounds.gd doctrine.)
func _fx_bone_bridge(info: Dictionary) -> void:
	_light_stir_site((info.get("site", Vector3.ZERO) as Vector3),
		Color(0.72, 0.86, 0.80))
	var ribs := board.grounds.bone_bridge() if board.grounds != null else null
	if ribs != null:
		# The bog gives up MORE bone than it swallowed: the ribs grow as
		# they rise — height-normalized GLB spans ~9u of a 22u claim line;
		# the risen monument must read like the omen promised.
		var tw := create_tween()
		tw.tween_property(ribs, "global_position:y",
			ProcessionGrounds.WATER_Y + BRIDGE_RISE_Y, 2.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ribs, "scale", ribs.scale * 1.8, 2.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw.finished
	for k in (info.stones as Array).size():
		await _fx_stone_pop(int((info.stones as Array)[k]), 0.1)

## A permanent cold lamp over a risen set piece — dark bone against dark
## water is invisible from every review angle; a changed board must READ.
func _light_stir_site(site: Vector3, col: Color) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = col
	lamp.light_energy = 0.0
	lamp.omni_range = 11.0
	lamp.shadow_enabled = false
	board.add_child(lamp)
	lamp.global_position = site + Vector3(0, 4.6, 0)
	var tw := create_tween()
	tw.tween_property(lamp, "light_energy", 1.05, 1.8)

## MAJOR 1 — the dormant sculpt wakes: he rises, glides to the corridor, the
## scythe sweeps its arc alongside a rigged SWEEP hero pose held at the carve
## beat, and the carve stone surfaces where it fell. He keeps his new post at
## the cut's edge — watching what he opened.
##
## G4 (#81) call: the WALK clip stayed BENCHED. The camera holds a fixed shot
## on the site the whole beat (never tracks the traveler — true of the
## original static glide too), so a live walk cycle would only ever be seen
## arriving, never striding; and the "Slow Orc Walk" preset's own hunched,
## claw-handed pose (docs/verify/shots/asset_finish_rigfix_postfix_reaper_walk.png)
## reads as a lunge, not a glide. The static sculpt keeps doing the glide.
## SWEEP is wired, but NOT played live either — a real-time drift check
## (tools/_tmp_reaper_driftcheck, deleted after use) showed the clip's early
## seconds crouch the whole body down near ground level, and this event's
## site can land in low/watery ground (e.g. the Hollow Woods bog, site.y well
## below 0) where a crouched silhouette gets swallowed by the water surface —
## invisible in an actual ceremony capture even though the node, position and
## mesh were all verified correct. The fix: SEEK to a single held frame late
## in the clip (t=1.8s) where the pose stands tall, one arm raised — a hero
## silhouette no shorter than the static sculpt, so it can never sink below
## whatever the static sculpt would already clear. Frozen, not looping,
## mirroring the same freeze convention board_graph.gd already uses for the
## dormant Reaper (_rigged_npc frozen=true).
func _fx_reaper_shortcut(info: Dictionary) -> void:
	var site := (info.get("site", Vector3.ZERO) as Vector3)
	if board.reaper_prop != null:
		var stand := site + Vector3(2.6, 0, 2.2)
		# his pall travels with him — an unlit reaper is an invisible one
		var pall := board.get_node_or_null("ReaperPall") as Node3D
		if pall != null:
			var ptw := create_tween()
			ptw.tween_property(pall, "global_position",
				stand + Vector3(0.6, 3.2, 0.6), 2.6).set_trans(Tween.TRANS_SINE)
			ptw.parallel().tween_property(pall, "light_energy", 1.15, 2.6)
		var tw := create_tween()
		tw.tween_property(board.reaper_prop, "global_position:y",
			board.reaper_prop.global_position.y + 0.7, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(board.reaper_prop, "global_position",
			stand + Vector3(0, 0.7, 0), 2.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(board.reaper_prop, "global_position:y",
			stand.y + 0.05, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
		if board.reaper_scythe != null:
			var sc := board.reaper_scythe
			sc.global_position = stand + Vector3(-0.6, 0.4, -0.4)
			# G4: swap the static sculpt for the rigged SWEEP hero pose only
			# for this flourish — same native/target height as the static
			# prop (no scale pop), held at one dramatic frame (see doc block
			# above for why it isn't played live).
			board.reaper_prop.visible = false
			var sweeper := MeshyProp.instance_rigged(ProcessionBoardGraph.ZF_REAPER_SWEEP,
				ProcessionBoardGraph.REAPER_RIG_NATIVE_H, ProcessionBoardGraph.REAPER_RIG_TARGET_H)
			board.add_child(sweeper)
			sweeper.look_at_from_position(stand, Vector3(site.x, stand.y, site.z), Vector3.UP)
			var sw_anim: AnimationPlayer = sweeper.find_child("AnimationPlayer", true, false)
			if sw_anim != null and sw_anim.get_animation_list().size() > 0:
				var sname := String(sw_anim.get_animation_list()[0])
				sw_anim.play(sname)
				sw_anim.seek(1.8, true)
				sw_anim.speed_scale = 0.0
			var arc := create_tween()
			arc.tween_property(sc, "rotation:y", sc.rotation.y + PI * 1.4, 0.55) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			if _capture:
				await _cap_snap("reaper_sweep_pose")
			await arc.finished
			sweeper.queue_free()
			board.reaper_prop.visible = true
	for k in (info.stones as Array).size():
		await _fx_stone_pop(int((info.stones as Array)[k]))

## MAJOR 3 — the hillside gives way: boulders tumble the slip band and stay
## as the slide's debris; the redirect itself is pure graph.
func _fx_landslip(info: Dictionary) -> void:
	var from_p := board.space_pos(int(info.from))
	var to_p := board.space_pos(int(info.to))
	var rocks: Array = []
	for k in 6:
		# The same field boulders the swells wear (not grey boxes) — the slide's
		# debris must read as the ESTATE's stone. Modest tilt only: the prop is
		# base-normalised, so a hard tip swings it under its own footing.
		var r := MeshyProp.instance(
			ProcessionGrounds.KIT + "ground_boulder_a.glb",
			0.55 + 0.24 * float(k % 3))
		board.add_child(r)
		var t := (float(k) + 0.5) / 6.0
		r.global_position = from_p.lerp(to_p, t * 0.4) + Vector3(0, 3.2, 0)
		r.rotation = Vector3(0.22 * sin(k * 2.1), 0.9 * k, 0.22 * cos(k * 1.7))
		rocks.append({"n": r, "t": t})
	var tw := create_tween().set_parallel(true)
	for rk in rocks:
		var rest := from_p.lerp(to_p, 0.25 + 0.6 * float(rk.t))
		rest = ProcessionGrounds.snap(rest, 0.1)
		tw.tween_property(rk.n, "global_position", rest, 1.1 + 0.4 * float(rk.t)) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished

## MAJOR 4 — the ghost road lays itself stone by stone; one pale wisp walks
## it first, then leaves the living to argue over it.
func _fx_procession_road(info: Dictionary) -> void:
	_light_stir_site((info.get("site", Vector3.ZERO) as Vector3),
		Color(0.72, 0.82, 0.95))
	var ids := info.stones as Array
	var wisp := OmniLight3D.new()
	wisp.light_color = Color(0.75, 0.87, 1.0)
	wisp.light_energy = 1.6
	wisp.omni_range = 6.0
	wisp.shadow_enabled = false
	board.add_child(wisp)
	wisp.global_position = board.space_pos(int(info.entry)) + Vector3(0, 1.6, 0)
	for k in ids.size():
		var tw := create_tween()
		tw.tween_property(wisp, "global_position",
			board.space_pos(int(ids[k])) + Vector3(0, 1.6, 0), 0.5) \
			.set_trans(Tween.TRANS_SINE)
		await _fx_stone_pop(int(ids[k]))
	var out := create_tween()
	out.tween_property(wisp, "light_energy", 0.0, 0.8)
	out.tween_callback(wisp.queue_free)

## MINOR 1 — Garden Row closes: shallow floodwater pools over every garden
## stone for 2 rounds (fork options drop the road; stones still resolve).
func _fx_flood() -> void:
	_settle_flood_fx()
	await _beat(1.0)

## Immediate form shared by the host ceremony and a guest's no-ceremony
## settle. The empty guard also makes presentation replay harmless.
func _settle_flood_fx() -> void:
	if not _flood_fx.is_empty():
		return
	for n in board.nodes:
		if String(n.route) != "garden":
			continue
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.7
		cm.bottom_radius = 1.7
		cm.height = 0.02
		cm.radial_segments = 24
		disc.mesh = cm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.30, 0.48, 0.62, 0.55)
		m.metallic = 0.4
		m.roughness = 0.15
		m.emission_enabled = true
		m.emission = Color(0.2, 0.4, 0.55)
		m.emission_energy_multiplier = 0.3
		disc.material_override = m
		board.add_child(disc)
		disc.global_position = (n.pos as Vector3) + Vector3(0, 0.09, 0)
		_flood_fx.append(disc)

## MINOR 3 — the hearse treks to its new pad, lantern trailing.
func _fx_hearse_moves(info: Dictionary) -> void:
	var park := board.cart_park_pos(int(info.to))
	if board.cart_prop != null:
		var mid := (board.cart_prop.global_position + park) * 0.5 + Vector3(0, 0.8, 0)
		var tw := create_tween()
		tw.tween_property(board.cart_prop, "global_position", mid, 1.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(board.cart_prop, "global_position", park, 1.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw.finished
	if board.cart_lantern != null:
		board.cart_lantern.global_position = park + Vector3(0.6, 0, 0.4)
	await _fx_stone_pop(int(info.to))

## MINOR 4 — the mourners crowd their three stones (2 per stone, idling).
func _fx_wake(info: Dictionary) -> void:
	_settle_wake_fx(info)
	await _beat(1.0)

func _settle_wake_fx(info: Dictionary) -> void:
	if not _wake_fx.is_empty():
		return
	for sid in (info.stones as Array):
		var p := board.space_pos(int(sid))
		for k in 2:
			var side := 1.0 if k == 0 else -1.0
			var m := board.spawn_mourner(p + Vector3(side * 1.3, 0, 0.7 * side), p)
			if m != null:
				_wake_fx.append(m)

## MINOR 5 — the court convenes: two perched, one aloft, all patient.
func _fx_crow_court(info: Dictionary) -> void:
	_settle_crow_fx(info)
	await _beat(1.0)

func _settle_crow_fx(info: Dictionary) -> void:
	if not _crow_fx.is_empty():
		return
	var p := board.space_pos(int(info.node))
	for spec in [{"o": Vector3(0.8, 0.1, 0.5), "fly": false},
			{"o": Vector3(-0.7, 0.1, -0.4), "fly": false},
			{"o": Vector3(0.2, 2.2, -0.9), "fly": true}]:
		var c := board.spawn_crow(p + (spec.o as Vector3), bool(spec.fly))
		if c != null:
			_crow_fx.append(c)
	# A cold rim from BEHIND the court (south — the ceremony camera stands
	# north): black birds on a dark stone are invisible without an edge. It
	# rides in _crow_fx, so the scatter carries the light off with the murder.
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.75, 0.82, 1.0)
	rim.light_energy = 0.0
	rim.omni_range = 6.5
	rim.shadow_enabled = false
	board.add_child(rim)
	rim.global_position = p + Vector3(0.6, 2.6, 2.4)
	var tw := create_tween()
	tw.tween_property(rim, "light_energy", 1.3, 0.6)
	_crow_fx.append(rim)

## The court adjourns: the murder scatters skyward with its takings.
func _scatter_crows() -> void:
	for c in _crow_fx:
		if not is_instance_valid(c):
			continue
		var n := c as Node3D
		var tw := create_tween()
		tw.tween_property(n, "global_position",
			n.global_position + Vector3(_drama_prng.randf_range(-4, 4), 9.0,
				_drama_prng.randf_range(-4, 4)),
			1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(n.queue_free)
	_crow_fx.clear()

# --------------------------------------------------------------------------
# NIGHT OPEN — banner, the 3 announced awards, THE LETTERS (doc 28 §7/§8r5)
# --------------------------------------------------------------------------
const AWARD_WREATHS := 4
## DR (doc 29 opt A): the three will clauses pay WREATHS now — ◆ Deeds retired.
## One wreath per clause leader, booked to the announced-award stream.
const WILL_WREATHS := 1
## The award pool (doc 28 §7 — majority luck/behaviour-weighted, measured
## design law). BLOODIEST HAND is the ONE skill award; at most one skill
## award may be drawn per night.
const AWARD_POOL := [
	{"id": "longest", "stat": "moved", "skill": false},
	{"id": "mourned", "stat": "hazards", "skill": false},
	{"id": "generous", "stat": "spent", "skill": false},
	{"id": "uninvited", "stat": "seances", "skill": false},
	{"id": "bloodiest", "stat": "mini_wins", "skill": true},
]
var night_awards: Array = []          # tonight's 3 drawn award dicts
var _night_award_results: Array = []  # [[id, winner|-1], ...] for the night record
var _night_start_wreaths: Array[int] = []   # snapshot for the bounded legacy grant

func _award_title(a: Dictionary) -> String:
	return Dialog.text("procession.awards.%s_title" % String(a.id))

func _award_desc(a: Dictionary) -> String:
	return Dialog.text("procession.awards.%s_desc" % String(a.id))

func _night_open() -> void:
	_phase = "night_open"
	Music.play_slot("grounds")
	_tracker_live = false   # new night, new races — re-armed at the interim reading
	_mini_pool = CYCLE_ORDER.duplicate()
	_cycle_mini = ""   # a card left on the table when the bell rang dies with its night
	_night_start_wreaths = wreaths.duplicate()
	if not _fast and match_nights > 1:
		_announce_text(Dialog.text("procession.night.open") % [night_index, match_nights],
			Color(1, 0.88, 0.5))
		await _beat(2.0)
		_hide_announce()
	_draw_night_awards()
	await _announce_awards()
	await _letters_offer()
	# THE MAJOR fires as night 2 opens (fixed beat): the board is different
	# from here on, and it stays different for every night that follows.
	if night_index == 2 and not stirs.major_fired:
		await _fire_stir("major", stirs.major)

## Draw 3 of 5 at night start (EVENT stream, without replacement). At most one
## SKILL award may be drawn — with BLOODIEST HAND the pool's only skill entry
## the guard is structural, but the doctrine is enforced, not assumed.
func _draw_night_awards() -> void:
	night_awards.clear()
	_night_award_results.clear()
	var pool := AWARD_POOL.duplicate()
	var skill_drawn := false
	while night_awards.size() < 3 and not pool.is_empty():
		var i := _event_rng.randi_range(0, pool.size() - 1)
		var a: Dictionary = pool[i]
		pool.remove_at(i)
		if bool(a.skill) and skill_drawn:
			continue
		if bool(a.skill):
			skill_drawn = true
		night_awards.append(a)

## ANNOUNCED at night start by the Executor (never a hidden bonus star —
## R-A doctrine), races visible at the interim reading.
func _announce_awards() -> void:
	if _fast:
		return
	_reveal_seat = -1
	executor.say(Dialog.text("procession.awards.announce"), Color(0.85, 0.78, 1.0))
	await _beat(1.6)
	executor.clear_banner()
	var lines: Array[String] = []
	for a in night_awards:
		lines.append(Dialog.text("procession.awards.line") % [_award_title(a),
			_award_desc(a), AWARD_WREATHS, Spaces.WREATH_GLYPH])
	_announce_text(Dialog.text("procession.awards.header") + "\n\n" + "\n".join(lines),
		Color(0.85, 0.78, 1.0))
	if _capture and night_index == 1:
		await _cap_snap("night_awards")
		# Capture-only: arm THE THREE RACES tracker from the announcement so the
		# roll-phase stills show it (real play arms it at the interim reading,
		# which the all-bot capture's drama gate skips by design).
		_tracker_live = true
	await _beat(3.0)
	_hide_announce()

## LETTERS OF ADMINISTRATION (doc 28 §8 rule 5, locked v1): at night start a
## player with ZERO minigame wins so far AND bottom wreaths may PUBLICLY accept
## — the Executor reads it as a dry legal formality (comedy doing balance
## work). That night only: cart 30% off (it IS the discount), one free CROW'S
## CUT, arrival award bumped one tier. Opt-in, announced, time-boxed.
func _letters_offer() -> void:
	for i in roster.size():
		letters[i] = false
	if night_index < 2:
		return   # night 1 has no bottom to lift — everyone is tied at nothing
	var lo := wreaths[0]
	var hi := wreaths[0]
	for w in wreaths:
		lo = mini(lo, w)
		hi = maxi(hi, w)
	if hi <= lo:
		return
	for i in roster.size():
		if mini_wins_match[i] > 0 or wreaths[i] != lo:
			continue
		var accept := true
		if _is_local_human(i) and _drama_visible():
			var pick: int = await _pick_prompt(
				Dialog.text("procession.letters.header") % roster[i].name,
				Dialog.text("procession.letters.sub"), roster[i].color,
				[{"label": Dialog.text("procession.letters.accept_label")}],
				Dialog.text("procession.letters.decline_label"), true, 8.0)
			accept = pick == 0
		if not accept:
			continue
		letters[i] = true
		_grant_ware(i, "crows_cut")   # one free CROW'S CUT (cap 3 still binds)
		if not _fast:
			_reveal_seat = i
			executor.say(Executor.pick(Dialog.paras("procession.letters.reading"),
				_voice_rng, [roster[i].name]), roster[i].color)
			await _beat(2.6)
			executor.clear_banner()

# --------------------------------------------------------------------------
# NIGHT SETTLEMENT — arrivals, awards, the will, standings, LAST RITES
# --------------------------------------------------------------------------
var _carry_spent: Array[int] = []   # LAST RITES spending counts toward the NEXT night's race

func _night_settlement() -> void:
	# The races are over — the tracker stands down for the ceremonies (P3).
	_tracker_live = false
	if _award_tracker != null:
		_award_tracker.visible = false
	await _arrival_wreaths()
	await _award_payouts()
	await _will_reading()
	await _standings_reveal()
	# LAST RITES lands after this night's GENEROUS award has already been read —
	# its spending seeds the NEXT night's race instead of vanishing in the reset.
	var spent_before: Array[int] = []
	for i in roster.size():
		spent_before.append(int(stats[i].spent))
	await _last_rites()
	_carry_spent.clear()
	for i in roster.size():
		_carry_spent.append(int(stats[i].spent) - spent_before[i])
	_legacy_grant()
	_emit_night_record()

## The 3 announced award races pay out: 4 wreaths each, strict-max leader;
## GENUINE ties break by SEEDED rng, VISIBLY (announced as the estate's coin —
## doc 28 §8 law 3: no stable-sort bias, ever). Zero-data awards go unclaimed.
func _award_payouts() -> void:
	_phase = "awards"
	var lines: Array[String] = []
	for a in night_awards:
		var stat := String(a.stat)
		var best_v := 0
		for i in roster.size():
			best_v = maxi(best_v, int(stats[i].get(stat, 0)))
		if best_v <= 0:
			_night_award_results.append([String(a.id), -1])
			lines.append(Dialog.text("procession.awards.unclaimed") % _award_title(a))
			continue
		var tied: Array = []
		for i in roster.size():
			if int(stats[i].get(stat, 0)) == best_v:
				tied.append(i)
		var win := int(tied[0])
		var tie_note := ""
		if tied.size() > 1:
			win = int(tied[_event_rng.randi_range(0, tied.size() - 1)])
			tie_note = Dialog.text("procession.awards.tie_note")
		wreaths[win] += AWARD_WREATHS
		wreath_src[win].award += AWARD_WREATHS
		_night_award_results.append([String(a.id), win])
		lines.append(Dialog.text("procession.awards.pay_line") % [_award_title(a),
			roster[win].name, best_v, AWARD_WREATHS, Spaces.WREATH_GLYPH] + tie_note)
		_pop_grudge(win, AWARD_WREATHS, Spaces.WREATH_GLYPH)
	if not _fast:
		_announce_text(Dialog.text("procession.awards.pay_header") + "\n\n" + "\n".join(lines),
			Color(0.85, 0.78, 1.0))
		_refresh_hud()
		await _beat(3.2)
		_hide_announce()
	else:
		_refresh_hud()

## The wreath standings, revealed plainly at each night's end (doc 28 §2).
func _standings_reveal() -> void:
	if _fast:
		return
	var order := _roll_order()
	var lines: Array[String] = []
	for rank in order.size():
		var p := int(order[rank])
		lines.append(Dialog.text("procession.standings.line") % [rank + 1, roster[p].name,
			wreaths[p], Spaces.WREATH_GLYPH, grudge[p], Spaces.PENNY_GLYPH])
	_announce_text(Dialog.text("procession.standings.header") + "\n\n" + "\n".join(lines),
		Color(1, 0.88, 0.5))
	await _beat(3.0)
	_hide_announce()

## LAST RITES — the night-interlude store beat: every mourner visits the cart,
## trailers first (the rubber-band shops before the leaders do).
func _last_rites() -> void:
	_phase = "last_rites"
	if not _fast:
		_announce_text(Dialog.text("procession.lastrites.header"), Color(1, 0.88, 0.5))
		await _beat(1.6)
		_hide_announce()
	var order := _roll_order()
	order.reverse()
	for seat in order:
		await _shop(int(seat))

## Landmine 4: EstateState.end_night's legacy conversion must keep receiving a
## BOUNDED night-points source or the wardrobe economy starves. The procession
## grants each seat its night's wreath take, clamped 1..12, at every night end
## — real play only (autoplay probes never touch the save).
func _legacy_grant() -> void:
	if _autoplay:
		return
	for i in roster.size():
		var gained := wreaths[i] - int(_night_start_wreaths[i]) if i < _night_start_wreaths.size() else 1
		EstateState.legacy[i] = int(EstateState.legacy.get(i, 0)) + clampi(gained, 1, 12)
	EstateState.save_estate()

## One deterministic per-night record line for the match receipt.
func _emit_night_record() -> void:
	var rec := {
		"night": night_index, "rounds": round_num, "bell_round": bell_round,
		"arrivals": arrival_order.duplicate(), "awards": _night_award_results.duplicate(true),
		"wreaths": wreaths.duplicate(), "grudge": grudge.duplicate(),
		"letters": letters.duplicate(),
	}
	print("PROCESSION_NIGHT ", JSON.stringify(rec))

## The interlude board reset (doc 28 §2): wreaths, pennies and inventory
## persist; positions, arrivals, the bell, traps and the per-night stat
## races reset with the board.
func _board_reset() -> void:
	arrival_order.clear()
	_arrived_this_round.clear()
	bell_round = -1
	round_num = 0
	for i in roster.size():
		positions[i] = 0
		arrived[i] = false
		trail[i] = [0]
		pending_die[i] = 0
		pending_lucky[i] = 0
		board.seat_pawn(i, 0)
		for k in stats[i]:
			stats[i][k] = 0
		if i < _carry_spent.size():
			stats[i].spent = int(_carry_spent[i])
	_carry_spent.clear()
	debt_traps.clear()
	board.clear_all_debt_markers()
	if final_kit and final_kit.has_method("round_reset"):
		final_kit.round_reset()
	_refresh_hud()
	_push_net()

# --------------------------------------------------------------------------
# THE READING — the finale (doc 28 §2): totals revealed stream by stream,
# liquidation, most wreaths INHERITS. Tie-break chain per §15 — never a coin
# flip for the estate; a full tie crowns JOINT HEIRS.
# --------------------------------------------------------------------------
func _finale() -> void:
	_phase = "finale"
	executor.clear_banner()
	Music.play_slot("ceremony")
	# Liquidation FIRST (10 pennies -> 1 wreath, game end only) so the streams
	# below sum to the crowning totals.
	for i in roster.size():
		var lw := grudge[i] / 10
		wreaths[i] += lw
		wreath_src[i].liquid += lw
	if not _fast:
		_reveal_seat = -1
		executor.say(Dialog.text("procession.finale.opener"), Color(0.85, 0.75, 1.0))
		await _beat(2.0)
		executor.clear_banner()
	await _finale_stream("arrival", Color(1, 0.88, 0.5))
	await _finale_stream("mini", Color(0.85, 0.9, 1.0))
	await _finale_stream("award", Color(0.85, 0.78, 1.0))
	await _finale_stream("liquid", Color(0.75, 0.95, 0.8))
	# The totals card — the last read before the crown.
	if not _fast:
		var order := _match_order()
		var lines: Array[String] = []
		for rank in order.size():
			var p := int(order[rank])
			lines.append(Dialog.text("procession.standings.line") % [rank + 1,
				roster[p].name, wreaths[p], Spaces.WREATH_GLYPH, grudge[p], Spaces.PENNY_GLYPH])
		_announce_text(Dialog.text("procession.finale.totals_header") + "\n\n" + "\n".join(lines),
			Color(1, 0.88, 0.5))
		if _capture:
			await _cap_snap("reading_totals")
		await _beat(3.4)
		_hide_announce()
	await ProcessionEulogy.deliver(self, executor)   # B2-HOOK: procedural closing eulogy (F33)
	await _heir_crowned()
	_emit_tally()

## One stream card: the per-seat take from a single wreath source.
func _finale_stream(src: String, col: Color) -> void:
	if _fast:
		return
	var lines: Array[String] = []
	for i in roster.size():
		lines.append(Dialog.text("procession.finale.stream_line") % [roster[i].name,
			int(wreath_src[i].get(src, 0)), Spaces.WREATH_GLYPH])
	_announce_text(Dialog.text("procession.finale.stream_%s" % src) + "\n\n" + "\n".join(lines), col)
	await _beat(2.4)
	_hide_announce()

## Grand standings: wreaths desc, then the ANNOUNCED tie-break chain (doc 28
## §15): most board firsts → best last-night board rank → most minigame
## firsts. Seat index orders the display only — it can never decide the heir.
func _match_order() -> Array:
	var order: Array = []
	for i in roster.size():
		order.append(i)
	order.sort_custom(func(a, b):
		if wreaths[a] != wreaths[b]:
			return wreaths[a] > wreaths[b]
		if board_firsts[a] != board_firsts[b]:
			return board_firsts[a] > board_firsts[b]
		if night_final_rank[a] != night_final_rank[b]:
			return night_final_rank[a] < night_final_rank[b]
		if mini_wins_match[a] != mini_wins_match[b]:
			return mini_wins_match[a] > mini_wins_match[b]
		return a < b)
	return order

## Everyone still tied with the top seat after the WHOLE chain inherits
## together — JOINT HEIRS, never a coin flip (doc 28 §15).
func _match_heirs() -> Array:
	var order := _match_order()
	var top := int(order[0])
	var heirs: Array = [top]
	for k in range(1, order.size()):
		var p := int(order[k])
		if wreaths[p] == wreaths[top] and board_firsts[p] == board_firsts[top] \
				and night_final_rank[p] == night_final_rank[top] \
				and mini_wins_match[p] == mini_wins_match[top]:
			heirs.append(p)
	return heirs

## ARRIVAL WREATHS (doc 28 §6/§15): the FINAL BELL pays arrival order on the
## escalating night table — crossing order first, then dist_to_gate ranking
## for everyone still on the road (_final_order does exactly that). A LETTERS
## holder's award is bumped ONE TIER (doc 28 §8 rule 5), announced.
func _arrival_wreaths() -> void:
	_phase = "arrival_pay"
	var table: Array = ARRIVAL_WREATHS[clampi(night_index - 1, 0, ARRIVAL_WREATHS.size() - 1)]
	var order := _final_order()
	var lines: Array[String] = []
	for rank in order.size():
		var p := int(order[rank])
		var tier := rank
		var bumped := false
		if bool(letters[p]) and tier > 0:
			tier -= 1
			bumped = true
		var wd := int(table[mini(tier, table.size() - 1)])
		wreaths[p] += wd
		wreath_src[p].arrival += wd
		var home := arrival_order.find(p)
		var line := Dialog.text("procession.arrival.line") % [rank + 1, roster[p].name,
			wd, Spaces.WREATH_GLYPH]
		if home < 0:
			line += Dialog.text("procession.arrival.on_road")
		if bumped:
			line += Dialog.text("procession.arrival.bumped")
		lines.append(line)
	board_firsts[int(order[0])] += 1
	if night_index >= match_nights:
		for rank in order.size():
			night_final_rank[int(order[rank])] = rank
	if not _fast:
		_announce_text(Dialog.text("procession.arrival.header") + "\n\n" + "\n".join(lines),
			Color(1, 0.88, 0.5))
		_refresh_hud()
		await _beat(3.0)
		_hide_announce()
	else:
		_refresh_hud()

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
	# --- THE OMENS (doc 28 §4): the Executor reads this game's drawn Estate
	# Stirs — poetic line per event, plain names on the card. Announced at
	# game start, fired at their beats; nothing hidden decides. ---
	if not _fast:
		executor.say(Dialog.text("procession.stirs.omen_intro"), STIR_COL)
		await _beat(1.6)
		var omen_lines: Array[String] = []
		for ev in [stirs.major, stirs.minor]:
			omen_lines.append("⚱ %s — %s" % [ProcessionStirs.title(ev),
				Dialog.text("procession.stirs.omen.%s" % ev)])
		_announce_text(Dialog.text("procession.stirs.omen_header") + "\n\n"
			+ "\n".join(omen_lines), STIR_COL)
		if _capture:
			await _cap_snap("stirs_omens")
		await _beat(3.2)
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
	# bottom of frame, the three lands, the Manor Gate glowing on its rise.
	# (G1: the world grew ~3x with THE GROUNDS — the hero climbed with it.)
	cam.global_position = Vector3(0.0, 82.0, 92.0)
	cam.look_at(board.CENTER + Vector3(0, 0.5, -8.0), Vector3.UP)
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
	# ---- P3 verification stills ----
	# (a) the four figurines on stones — posed down the first garden stones for
	# a clean low hero (visual seat only: logical positions untouched, everyone
	# re-seated at the lychgate right after; capture-only theater).
	for i in roster.size():
		board.seat_pawn(i, 2 + i)
	var f_a := board.space_pos(3)
	var f_b := board.space_pos(5)
	var f_dir := (f_b - f_a)
	f_dir.y = 0.0
	f_dir = f_dir.normalized() if f_dir.length() > 0.1 else Vector3.FORWARD
	var f_perp := f_dir.cross(Vector3.UP).normalized()
	cam.global_position = f_a - f_dir * 1.6 + f_perp * 3.1 + Vector3(0, 1.5, 0)
	cam.look_at(f_a + f_dir * 2.4 + Vector3(0, 0.45, 0), Vector3.UP)
	await _cap_snap("figurine_pawns")
	for i in roster.size():
		board.seat_pawn(i, 0)
	# (c) the dressed LYCHGATE...
	var lych := board.lychgate_pos()
	cam.global_position = lych + Vector3(4.6, 3.2, 7.2)
	cam.look_at(lych + Vector3(0, 2.0, -1.0), Vector3.UP)
	await _cap_snap("lychgate_dressed")
	# ...AND the MANOR GATE.
	var gate := board.gate_pos()
	cam.global_position = gate + Vector3(-4.8, 3.4, 8.4)
	cam.look_at(gate + Vector3(0, 2.4, -1.0), Vector3.UP)
	await _cap_snap("manor_gate_dressed")
	# (e) THE REAPER, dormant and distant, barely lit at the graveyard edge.
	var rp: Vector3 = BoardGraph.REAPER_POST
	cam.global_position = rp + Vector3(6.4, 2.4, 8.8)
	cam.look_at(rp + Vector3(0, 2.6, 0), Vector3.UP)
	await _cap_snap("reaper_dormant")
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
	# THE BOOK OF THE DEAD (doc 32): the cycle's minigame is drawn NOW —
	# announced on the round strip — so bets are informed and the roll phase
	# gains anticipation. Sanctioned EVENT-order shift; receipts re-frozen
	# (VERIFY-BOARD §4). After the FINAL BELL there is no game to bet on.
	if bell_round < 0:
		if _cycle_mini == "":
			_cycle_mini = _draw_minigame()
		if book != null:
			book.open_phase()
			for i in roster.size():
				if bool(roster[i].bot):
					book.place_bet(i, _bot_bet_target(i))
		# the laurel wisps from last cycle's correct bets ride this cycle
		for i in roster.size():
			board.set_laurel(i, bool(_laurel_next[i]))
			_laurel_next[i] = false
		_refresh_hud()   # the round strip announces the drawn card at once
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

## ONE TURN: the pre-roll item beat, then roll THE LAST BREATH (heatmap live),
## walk the stones (forks prompt/strategize), ring the bell on a crossing,
## reveal the landing. The whole table watches one seat at a time — the reveal
## cascade is now inline with the turn.
func _take_turn(seat: int) -> void:
	_phase = "roll"
	_sync_minimap()
	_move_item_used = false
	_offense_hit.clear()
	if book != null:
		book.meter_seat = seat   # the roller's A belongs to THE LAST BREATH
	# --- THE ITEM BEAT: use held wares before the roll (doc 28 §15 resolution
	# order — movement items apply before travel). May teleport (wisp), dig
	# (shovel — possibly through the gate), arm boosts/writs, or sabotage. ---
	await _item_beat(seat)
	var path: Array = []
	var walked := 0
	if bool(arrived[seat]):
		pass   # the shovel carried them home — no roll, straight to the bell
	elif _wisp_dest >= 0:
		# WILL-O'-THE-WISP: the teleport IS the movement. One hop, nothing
		# crossed; ONLY the landing stone resolves (doc 28 §15).
		path = [_wisp_dest]
		_wisp_dest = -1
	else:
		if not _fast:
			_frame_roller(seat)
		# Windowed capture: pose the meter + heatmap once for the verification
		# still (the fast soak resolves a live roll in a single frame). Round 2+
		# only — round 1's rollers still stand under the lychgate arch.
		if _capture and not _breath_posed and round_num >= 2:
			_breath_posed = true
			await _pose_breath_shot(seat)
		var faces := N_FACES_BASE
		if pending_die[seat] > 0:   # an armed WRIT widens this roll's die
			faces = pending_die[seat]
			pending_die[seat] = 0
		var face := await _roll_breath(seat, faces)
		var steps := face + pending_lucky[seat]
		if pending_lucky[seat] > 0:
			_flash_line(Dialog.text("procession.items.lucky_spent") % [roster[seat].name,
				pending_lucky[seat]], roster[seat].color, seat)
			pending_lucky[seat] = 0
		# --- WALK: node-to-node along the seat's road; forks prompt humans,
		# bots draw strategy from the ROLL stream. Excess past the gate is
		# forfeited (the manor does not do refunds). ---
		_phase = "move"
		path = await _resolve_walk(seat, steps)
		walked = path.size()
	if not path.is_empty():
		if walked > 0:
			_pay_passthrough_tolls(seat, path)
			_crow_court_strike(seat, path)
		# P3: on release, CUT to the landing area — the figurine hops through frame
		# toward its stone (doc 28 §9: the camera frames the DECISION, not the walk).
		var land := int(path.back())
		board_camera.travel_cut(board.reveal_shot(land, board.type_at(land)))
		# ZERO-ENGLISH: the ONE space-name a normal turn shows — the destination
		# names itself while the toy hops toward it (cleared after the reveal).
		if not _fast:
			board.show_landing_label(land, roster[seat].color)
		var tw: Tween = board.advance_pawn_path(seat, path)
		positions[seat] = land
		(trail[seat] as Array).append_array(path)
		moved_total[seat] += walked
		stats[seat].moved += walked
		if board.type_at(positions[seat]) == Spaces.GATE and not bool(arrived[seat]):
			arrived[seat] = true
			arrival_order.append(seat)
			_arrived_this_round.append(seat)
		_sync_minimap()   # THE DRIVE inset lights up for the travel + reveal
		if not _fast and tw and tw.is_valid():
			# Travel ≤2s with hold-A fast-forward (doc 28 §9 action budget): any
			# human holding A triples the hop tween. Presentation only — the walk
			# was already resolved; the tween is theater.
			while tw.is_valid() and tw.is_running():
				if _any_human_holds_a():
					tw.set_speed_scale(3.2)
				await get_tree().process_frame
		elif _fast:
			board.seat_pawn(seat, positions[seat])
	if _capture and round_num == 1 and seat == _roll_order().back():
		await _cap_snap("drive_minimap")   # THE DRIVE ribbons, first travel beat
	# P3 still (a): the figurines strung out on the stones MID-MATCH — low over
	# the last roller's shoulder, the trailing toys on the road behind it.
	if _capture and round_num == 2 and seat == _roll_order().back():
		board_camera.hold()
		executor.clear_banner()   # a clean frame — the toys are the subject
		var pp := board.space_pos(positions[seat])
		if board.pawns.has(seat):
			pp = (board.pawns[seat] as Node3D).global_position
		var to_lych := board.lychgate_pos() - pp
		to_lych.y = 0.0
		to_lych = to_lych.normalized() if to_lych.length() > 0.1 else Vector3.BACK
		var side := to_lych.cross(Vector3.UP).normalized()
		# Raked 3/4 down-angle from above the dressing line (lamps 2.4, shrines
		# 2.5) so no prop can photobomb the toys again.
		cam.global_position = pp - to_lych * 3.4 + side * 0.8 + Vector3(0, 2.9, 0)
		cam.look_at(pp + to_lych * 3.6 + Vector3(0, 0.2, 0), Vector3.UP)
		await _cap_snap("figurines_midmatch")
	_push_net()
	# --- WREATH OF DEBT: a rival's trap on the landing stone collects now. ---
	if not path.is_empty():
		_check_debt_trap(seat)
	# --- THE FINAL BELL: the first crossing this night rings it, mid-round —
	# the rest of the queue still takes this turn (phase completes), then one
	# more full round for everyone (doc 28 §15 roll-phase completion). ---
	if bell_round < 0 and _arrived_this_round.has(seat):
		await _ring_bell(seat)
	# --- REVEAL: the landing, Executor voice, type-aware close-up. A shovel
	# that dug clean through the gate still gets its arrival read. ---
	_phase = "reveal"
	if not path.is_empty() or _arrived_this_round.has(seat):
		await _reveal_landing(seat)
	if breath.meter != null:
		breath.meter.visible = false
	if book != null:
		book.meter_seat = -1   # the roller's hands are their own again

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
		# P3: after the first showing, a waiting human can skip a BOT's over-
		# shoulder cinematic with B — camera falls back to the whole board while
		# the meter resolves untouched (sim never sees the skip).
		if not _fast and _os_shown > 1 and bool(roster[seat].bot) and _any_human_pressed_b():
			board_camera.whole_board(0.3)
		await get_tree().process_frame
	_heat_seat = -1
	board.clear_heatmap()
	return clampi(int(_breath_faces[seat]), 1, n_faces)

## Any LOCAL human currently holding A (the travel fast-forward).
func _any_human_holds_a() -> bool:
	for i in roster.size():
		if _is_local_human(i) and PlayerInput.is_down(i, "a"):
			return true
	return false

## Any LOCAL human tapping B this frame (the over-shoulder skip).
func _any_human_pressed_b() -> bool:
	for i in roster.size():
		if _is_local_human(i) and PlayerInput.just_pressed(i, "b"):
			return true
	return false

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

## Frame the active roller (P3): over the FIGURINE's shoulder, looking down its
## road — the heatmap stones glow ahead while the meter owns bottom-center. The
## first showing eases in (0.45s); every later roll hard-cuts, and a waiting
## human can skip a bot's cinematic with B (_roll_breath polls it). Budget-safe:
## the shot adds zero seconds to the roll act.
func _frame_roller(seat: int) -> void:
	var here := board.space_pos(positions[seat])
	var ahead := board.space_pos(_preview_dest(seat, 4))
	var pawn_pos := here
	if board.pawns.has(seat):
		pawn_pos = (board.pawns[seat] as Node3D).global_position
	# Gate clearance: at the LYCHGATE the hero arch swallows a tight shoulder
	# frame — swing outside its posts, angled down the road instead.
	board_camera.over_shoulder(pawn_pos, ahead - here, _os_shown == 0,
		positions[seat] == 0)
	_os_shown += 1

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
	# Pose the camera in the P3 OVER-SHOULDER frame: behind the figurine's
	# shoulder, the glowing road + percent tags running up-frame over the meter.
	executor.clear_banner()   # the round aside must not sit over the road
	board_camera.hold()
	var here := board.space_pos(positions[seat])
	var ahead := board.space_pos(_preview_dest(seat, 4))
	var dir := ahead - here
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP).normalized()
	var pawn_pos := here
	if board.pawns.has(seat):
		pawn_pos = (board.pawns[seat] as Node3D).global_position
	cam.global_position = pawn_pos - dir * 2.9 + right * 0.9 + Vector3(0, 2.5, 0)
	cam.look_at(pawn_pos + dir * 7.0 + right * 1.3 + Vector3(0, 0.3, 0), Vector3.UP)
	_sync_minimap()   # THE DRIVE rides the roll phase now (P3 §9b)
	await _beat(0.5)
	await _cap_snap("overshoulder_heatmap")
	# The thinking-budget wide (P3 screenshot d): standings strip + THE DRIVE +
	# meter, read together from the couch overview.
	cam.global_position = _cam_home
	cam.look_at(board.CENTER, Vector3.UP)
	await _beat(0.4)
	await _cap_snap("standings_drive")
	board.clear_heatmap()
	breath.meter.visible = false
	_frame_roller(seat)   # hand the frame back to the director's roll shot

# --------------------------------------------------------------------------
# THE ITEM BEAT + WARES (P2 — doc 28 §6/§15). Guardrails: inventory cap 3,
# max ONE die/movement item armed per turn, offensive items never stack on
# the same target in the same roll. Every use is ANNOUNCED (nothing hidden
# decides). Bot decisions draw from the EVENT stream, deterministically.
# --------------------------------------------------------------------------
func _item_beat(seat: int) -> void:
	if _inv_total(seat) <= 0:
		return
	if bool(roster[seat].bot) or not _drama_visible():
		await _bot_item_policy(seat)
		return
	for _k in Spaces.INV_CAP:
		var usable := _usable_items(seat)
		if usable.is_empty():
			return
		var entries: Array = []
		for id in usable:
			var w := Spaces.ware(String(id))
			entries.append({"label": "%s ×%d" % [String(w.name), _count_item(seat, String(id))],
				"sub": String(w.rule)})
		var pick: int = await _pick_prompt(
			Dialog.text("procession.items.header") % roster[seat].name, "",
			roster[seat].color, entries, Dialog.text("procession.items.keep_label"),
			true, 8.0)
		if pick < 0:
			return
		await _use_item(seat, String(usable[pick]))

## Held items a seat can legally spend RIGHT NOW (the guardrails as a filter).
## BLACK VEIL is passive — it spends itself on the next hazard.
func _usable_items(seat: int) -> Array:
	var out: Array = []
	var ids: Array = items[seat].keys()
	ids.sort()
	for raw in ids:
		var id := String(raw)
		if _count_item(seat, id) <= 0:
			continue
		match id:
			"black_veil":
				continue
			"lucky_penny", "shovel", "writ_d10", "writ_d12":
				if not _move_item_used:
					out.append(id)
			"wisp":
				if not _move_item_used and _wisp_target(seat) >= 0:
					out.append(id)
			"crows_cut":
				if not _crow_targets(seat).is_empty():
					out.append(id)
			"funeral_bell":
				var lead := _track_leader(seat)
				if lead >= 0 and not _offense_hit.has(lead):
					out.append(id)
			"wreath_debt":
				var node := positions[seat]
				if not debt_traps.has(node) and node != 0 \
						and board.type_at(node) != Spaces.GATE:
					out.append(id)
			"invitation":
				out.append(id)
	return out

## The bot's pre-roll spending brain: EVENT stream, every draw conditional on
## a held item (deterministic per seed). At most one movement/die arm + a
## sabotage swing per turn — bots obey the same guardrails humans do.
func _bot_item_policy(seat: int) -> void:
	# one die/movement item, priority: the wider die first
	if not _move_item_used:
		if _count_item(seat, "writ_d12") > 0 and _event_rng.randf() < 0.6:
			await _use_item(seat, "writ_d12")
		elif _count_item(seat, "writ_d10") > 0 and _event_rng.randf() < 0.6:
			await _use_item(seat, "writ_d10")
		elif _count_item(seat, "lucky_penny") > 0 and _event_rng.randf() < 0.5:
			await _use_item(seat, "lucky_penny")
		elif _count_item(seat, "shovel") > 0 and _event_rng.randf() < 0.35:
			await _use_item(seat, "shovel")
		elif _count_item(seat, "wisp") > 0 and _wisp_target(seat) >= 0 \
				and _event_rng.randf() < 0.3:
			await _use_item(seat, "wisp")
	if _count_item(seat, "crows_cut") > 0 and not _crow_targets(seat).is_empty() \
			and _event_rng.randf() < 0.5:
		await _use_item(seat, "crows_cut")
	if _count_item(seat, "funeral_bell") > 0:
		var lead := _track_leader(seat)
		if lead >= 0 and lead != seat and not _offense_hit.has(lead) \
				and _event_rng.randf() < 0.5:
			await _use_item(seat, "funeral_bell")
	if _count_item(seat, "wreath_debt") > 0 and not debt_traps.has(positions[seat]) \
			and positions[seat] != 0 and board.type_at(positions[seat]) != Spaces.GATE \
			and _event_rng.randf() < 0.35:
		await _use_item(seat, "wreath_debt")
	if _count_item(seat, "invitation") > 0 and _event_rng.randf() < 0.5:
		await _use_item(seat, "invitation")

## Spend one item. Human target/game choices prompt (no rng); bot choices
## draw from the EVENT stream. A cancelled human choice consumes NOTHING.
func _use_item(seat: int, id: String) -> void:
	if _count_item(seat, id) <= 0:
		return
	var name := String(roster[seat].name)
	var col: Color = roster[seat].color
	match id:
		"lucky_penny":
			_take_item(seat, id)
			_move_item_used = true
			pending_lucky[seat] = 3
			_flash_line(Dialog.text("procession.items.lucky") % name, col, seat)
		"writ_d10", "writ_d12":
			_take_item(seat, id)
			_move_item_used = true
			pending_die[seat] = 10 if id == "writ_d10" else 12
			_flash_line(Dialog.text("procession.items.writ") % [name,
				"d10" if id == "writ_d10" else "d12"], col, seat)
		"shovel":
			_take_item(seat, id)
			_move_item_used = true
			await _shovel_advance(seat)
		"wisp":
			var dest := _wisp_target(seat)
			if dest < 0:
				return
			_take_item(seat, id)
			_move_item_used = true
			_wisp_dest = dest
			_flash_line(Dialog.text("procession.items.wisp") % name, col, seat)
		"crows_cut":
			var target := await _pick_crow_target(seat)
			if target < 0:
				return
			_take_item(seat, id)
			_offense_hit[target] = true
			_crow_strike(seat, target)
		"funeral_bell":
			var lead := _track_leader(seat)
			if lead < 0:
				return
			_take_item(seat, id)
			_offense_hit[lead] = true
			_bell_drag(seat, lead)
		"wreath_debt":
			_take_item(seat, id)
			debt_traps[positions[seat]] = seat
			board.set_debt_marker(positions[seat], col)
			_flash_line(Dialog.text("procession.items.debt_set") % name, col, seat)
		"invitation":
			var pick := await _pick_invitation(seat)
			if pick == "":
				return
			_take_item(seat, id)
			_invitation_pick = pick
			_flash_line(Dialog.text("procession.items.invitation") % [name,
				String((MINIGAMES[pick] as Dictionary).name)], col, seat)

## CROW'S CUT: steal 5 pennies from the chosen rival. The victim's BLACK VEIL
## can swallow it (the item is still spent — crows were fed either way).
func _crow_strike(seat: int, target: int) -> void:
	if _veil_negates(target):
		_flash_line(Dialog.text("procession.items.crow_blocked") % roster[target].name,
			roster[target].color, target)
		return
	var pay := mini(5, grudge[target])
	grudge[target] -= pay
	grudge[seat] += pay
	stats[target].lost += pay
	stats[target].hazards += 1
	_pop_transfer(target, seat, pay)
	_flash_line(Dialog.text("procession.items.crow") % [roster[seat].name, pay,
		Spaces.PENNY_GLYPH, roster[target].name], roster[seat].color, seat)
	_refresh_hud()

## FUNERAL BELL: the track leader retraces 4 stones of their own trail. No
## triggers, no resolution (a reposition, doc 28 §15) — and NEVER a home pawn
## (_track_leader only ranks seats still on the road).
func _bell_drag(seat: int, lead: int) -> void:
	if _veil_negates(lead):
		_flash_line(Dialog.text("procession.items.bell_blocked") % roster[lead].name,
			roster[lead].color, lead)
		return
	_slip_back(lead, 4)
	stats[lead].hazards += 1
	_flash_line(Dialog.text("procession.items.bell") % roster[lead].name,
		roster[seat].color, lead)
	_refresh_hud()
	_push_net()

## PALLBEARER'S SHOVEL: dig ahead 4 stones down the preferred road. Nothing
## triggers on the way (no tolls, no boxes); the stop resolves ONLY if the
## turn ends there — i.e. the gate (an arrival is an arrival).
func _shovel_advance(seat: int) -> void:
	var path: Array = []
	var cur := positions[seat]
	var pref := _route_pref(seat)
	for _k in 4:
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
		path.append(cur)
	if path.is_empty():
		return
	_flash_line(Dialog.text("procession.items.shovel") % roster[seat].name,
		roster[seat].color, seat)
	positions[seat] = cur
	(trail[seat] as Array).append_array(path)
	moved_total[seat] += path.size()
	stats[seat].moved += path.size()
	if board.type_at(cur) == Spaces.GATE and not bool(arrived[seat]):
		arrived[seat] = true
		arrival_order.append(seat)
		_arrived_this_round.append(seat)
	if _fast:
		board.seat_pawn(seat, positions[seat])
	else:
		var tw := board.advance_pawn_path(seat, path)
		if tw and tw.is_valid():
			await tw.finished

## WILL-O'-THE-WISP destination: the next FIXTURE down the seat's preferred
## road — the Peddler's Cart first, else the first grave-goods box or séance
## circle. -1 when the road ahead holds nothing worth haunting.
func _wisp_target(seat: int) -> int:
	var pref := _route_pref(seat)
	var cur := positions[seat]
	var fallback := -1
	var guard := board.node_count() + 4
	while guard > 0:
		guard -= 1
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
		match board.type_at(cur):
			Spaces.CART:
				return cur
			Spaces.GRAVE_GOODS, Spaces.SEANCE:
				if fallback < 0:
					fallback = cur
	return fallback

## The track leader still ON THE ROAD (fewest stones to the gate; ties to the
## earlier seat). Home pawns are beyond the reach of grudges — doc 28 §8 law 2.
func _track_leader(exclude: int) -> int:
	var best := -1
	for j in roster.size():
		if j == exclude or bool(arrived[j]):
			continue
		if best < 0 or board.dist_to_gate(positions[j]) < board.dist_to_gate(positions[best]):
			best = j
	return best

## Rivals a CROW'S CUT can mark: on the road, holding pennies, not already
## struck this roll (offensive items no-stack per target per roll).
func _crow_targets(seat: int) -> Array:
	var out: Array = []
	for j in roster.size():
		if j == seat or bool(arrived[j]) or grudge[j] <= 0 or _offense_hit.has(j):
			continue
		out.append(j)
	return out

## Spend a held BLACK VEIL against an incoming hazard. Callers announce their
## own contextual line; this just eats the veil.
func _veil_negates(seat: int) -> bool:
	if _count_item(seat, "black_veil") <= 0:
		return false
	_take_item(seat, "black_veil")
	return true

## WREATH OF DEBT collection: the first RIVAL to land on a trapped stone pays
## its owner 5 (veil-negatable). The trap is spent either way.
func _check_debt_trap(seat: int) -> void:
	var node := positions[seat]
	if not debt_traps.has(node):
		return
	var owner := int(debt_traps[node])
	if owner == seat:
		return
	debt_traps.erase(node)
	board.clear_debt_marker(node)
	if _veil_negates(seat):
		_flash_line(Dialog.text("procession.items.veil") % roster[seat].name,
			roster[seat].color, seat)
		return
	var pay := mini(5, grudge[seat])
	grudge[seat] -= pay
	grudge[owner] += pay
	stats[seat].lost += pay
	stats[seat].hazards += 1
	_pop_transfer(seat, owner, pay)
	_flash_line(Dialog.text("procession.items.debt_paid") % [roster[seat].name, pay,
		Spaces.PENNY_GLYPH, roster[owner].name], roster[owner].color, seat)
	_refresh_hud()

# ---- inventory primitives ----
func _inv_total(seat: int) -> int:
	var total := 0
	for id in items[seat]:
		total += int(items[seat][id])
	return total

func _count_item(seat: int, id: String) -> int:
	return int(items[seat].get(id, 0))

func _take_item(seat: int, id: String) -> void:
	var c := _count_item(seat, id) - 1
	if c <= 0:
		items[seat].erase(id)
	else:
		items[seat][id] = c

func _grant_ware(seat: int, id: String) -> bool:
	if _inv_total(seat) >= Spaces.INV_CAP:
		return false
	items[seat][id] = _count_item(seat, id) + 1
	return true

# ---- human choice prompts (no rng — pure input, crossroads doctrine) ----
func _pick_prompt(header: String, sub: String, col: Color, entries: Array,
		leave_label: String, focus_leave: bool, window: float) -> int:
	var prompt := CartPrompt.new()
	_ui.add_child(prompt)
	prompt.open(header, sub, col, entries, leave_label, focus_leave, window)
	var pick: int = await prompt.run()
	prompt.queue_free()
	return pick

## The crow's mark: bots take the richest rival (EVENT-free, deterministic);
## humans choose. -1 = cancelled, nothing spent.
func _pick_crow_target(seat: int) -> int:
	var targets := _crow_targets(seat)
	if targets.is_empty():
		return -1
	if bool(roster[seat].bot) or not _drama_visible():
		var best := int(targets[0])
		for t in targets:
			if grudge[int(t)] > grudge[best]:
				best = int(t)
		return best
	var entries: Array = []
	for t in targets:
		entries.append({"label": "%s — %d%s" % [roster[int(t)].name, grudge[int(t)],
			Spaces.PENNY_GLYPH], "color": roster[int(t)].color})
	var pick: int = await _pick_prompt(
		Dialog.text("procession.items.crow_header") % roster[seat].name, "",
		roster[seat].color, entries, Dialog.text("procession.items.keep_label"), false, 10.0)
	return -1 if pick < 0 else int(targets[pick])

## THE INVITATION's game: bots draw from the night pool (EVENT stream);
## humans pick by name. "" = cancelled.
func _pick_invitation(seat: int) -> String:
	var pool := _mini_pool.duplicate()
	if pool.is_empty():
		pool = CYCLE_ORDER.duplicate()
	if bool(roster[seat].bot) or not _drama_visible():
		return String(pool[_event_rng.randi_range(0, pool.size() - 1)])
	var entries: Array = []
	for id in pool:
		entries.append({"label": String((MINIGAMES[String(id)] as Dictionary).name)})
	var pick: int = await _pick_prompt(
		Dialog.text("procession.items.invitation_header") % roster[seat].name, "",
		roster[seat].color, entries, Dialog.text("procession.items.keep_label"), false, 12.0)
	return "" if pick < 0 else String(pool[pick])

# --------------------------------------------------------------------------
# THE PEDDLER'S CART, PRICED (P2 — doc 28 §6). Landing on the cart fixture
# opens the shop; LAST RITES reopens it at every night interlude. Rubber-band:
# wreath LAST place shops at 30% off — an ANNOUNCED line, never hidden. The
# LETTERS OF ADMINISTRATION are the same 30% (it IS the discount; no stack).
# --------------------------------------------------------------------------
func _shop(seat: int) -> void:
	var disc := _discount_for(seat)
	if float(disc.mult) < 0.999 and not _fast:
		_flash_line(String(disc.reason) % roster[seat].name, roster[seat].color, seat)
		await _beat(1.2)
	if _capture and not _cart_demoed:
		_cart_demoed = true
		await _demo_cart(seat)
	if bool(roster[seat].bot) or not _drama_visible():
		_bot_shop(seat)
		return
	while _inv_total(seat) < Spaces.INV_CAP:
		var entries: Array = []
		for w in Spaces.CART_WARES:
			var wd := w as Dictionary
			var price := _price_for(seat, wd)
			entries.append({"label": "%s — %d%s" % [String(wd.name), price, Spaces.PENNY_GLYPH],
				"sub": String(wd.rule), "disabled": grudge[seat] < price})
		var sub := Dialog.text("procession.cart.sub") % [roster[seat].name, grudge[seat],
			Spaces.PENNY_GLYPH, _inv_total(seat), Spaces.INV_CAP]
		var pick: int = await _pick_prompt(Dialog.text("procession.cart.header"), sub,
			Color(1, 0.88, 0.5), entries, Dialog.text("procession.cart.leave_label"),
			false, 15.0)
		if pick < 0:
			break
		var ware: Dictionary = Spaces.CART_WARES[pick]
		var price := _price_for(seat, ware)
		if grudge[seat] < price:
			continue
		_buy_ware(seat, ware, price)

## Bot shopping: one considered purchase per visit, EVENT stream, every draw
## conditional on an affordable shelf (deterministic per seed).
func _bot_shop(seat: int) -> void:
	if _inv_total(seat) >= Spaces.INV_CAP:
		return
	var afford: Array = []
	for w in Spaces.CART_WARES:
		if grudge[seat] >= _price_for(seat, w as Dictionary):
			afford.append(w)
	if afford.is_empty():
		return
	if _event_rng.randf() > 0.65:
		return   # window-shops and moves on
	var ware: Dictionary = afford[_event_rng.randi_range(0, afford.size() - 1)]
	_buy_ware(seat, ware, _price_for(seat, ware))

func _price_for(seat: int, ware: Dictionary) -> int:
	return int(ceil(float(int(ware.cost)) * float(_discount_for(seat).mult)))

## The one discount rule. LETTERS first (it IS the discount — no stacking);
## else wreath LAST place (everyone tied at the bottom when someone stands
## higher counts; a four-way tie is no last place).
func _discount_for(seat: int) -> Dictionary:
	if bool(letters[seat]):
		return {"mult": 0.7, "reason": Dialog.text("procession.cart.discount_letters")}
	var lo := wreaths[0]
	var hi := wreaths[0]
	for w in wreaths:
		lo = mini(lo, w)
		hi = maxi(hi, w)
	if hi > lo and wreaths[seat] == lo:
		return {"mult": 0.7, "reason": Dialog.text("procession.cart.discount_last")}
	return {"mult": 1.0, "reason": ""}

func _buy_ware(seat: int, ware: Dictionary, price: int) -> void:
	grudge[seat] -= price
	stats[seat].spent += price
	_grant_ware(seat, String(ware.id))
	Sfx.play("card", -6.0)
	_pop_grudge(seat, -price)
	_flash_line(Dialog.text("procession.cart.buy") % [roster[seat].name,
		String(ware.name), price, Spaces.PENNY_GLYPH], roster[seat].color, seat)
	_refresh_hud()

## Windowed capture only: pose the cart UI with bot data for the verification
## screenshot, then tear it down. Never headless.
func _demo_cart(seat: int) -> void:
	var entries: Array = []
	for w in Spaces.CART_WARES:
		var wd := w as Dictionary
		var price := _price_for(seat, wd)
		entries.append({"label": "%s — %d%s" % [String(wd.name), price, Spaces.PENNY_GLYPH],
			"sub": String(wd.rule), "disabled": grudge[seat] < price})
	var prompt := CartPrompt.new()
	_ui.add_child(prompt)
	prompt.open(Dialog.text("procession.cart.header"),
		Dialog.text("procession.cart.sub") % [roster[seat].name, grudge[seat],
			Spaces.PENNY_GLYPH, _inv_total(seat), Spaces.INV_CAP],
		Color(1, 0.88, 0.5), entries, Dialog.text("procession.cart.leave_label"), false, 6.0)
	await _beat(0.7)
	await _cap_snap("peddler_cart")
	prompt.queue_free()

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
	var options := _fork_options(fork_id)
	var is_human := not bool(roster[seat].bot) and not _is_remote_seat(seat)
	if is_human and _drama_visible():
		return await _prompt_branch_mapped(seat, fork_id, options)
	# bot strategy — ROLL stream, fixed draw shape (1 float + optional 1 int)
	var pick := -1
	if _roll_rng.randf() < 0.25:
		pick = _roll_rng.randi_range(0, options.size() - 1)
	else:
		pick = _pref_pick(seat, options)
	if _capture and not _prompt_demoed:
		_prompt_demoed = true
		await _demo_prompt(seat, options)
	return _branch_index_of(fork_id, options, pick)

## The options a fork offers RIGHT NOW. THE FLOOD (doc 28 §4 minor 1) closes
## Garden Row: the fork simply stops offering it while the water stands
## (never below one option).
func _fork_options(fork_id: int) -> Array:
	var options: Array = board.branch_options(fork_id)
	if stirs.flood_left > 0 and options.size() > 1:
		var open: Array = options.filter(
			func(o: Dictionary) -> bool: return String(o.route) != "garden")
		if not open.is_empty():
			options = open
	return options

## The seat's NO-RNG pick among fork options (shared by bot strategy sans
## wildcard, the F29 preview walk, and bot aim — the three must agree or the
## heatmap lies): the pref road wins, unless a Stirs-born road (bridge,
## carve, ghost road — never a pref tag) is STRICTLY shorter. The estate's
## gifts get taken. A flooded-out pref falls to the shortest way home.
func _pref_pick(seat: int, options: Array) -> int:
	var pref := _route_pref(seat)
	var pick := -1
	var stir_pick := -1
	for k in options.size():
		var o := options[k] as Dictionary
		var tag := String(o.route)
		if tag == pref and (pick < 0
				or int(o.left) < int((options[pick] as Dictionary).left)):
			pick = k
		elif tag not in ["garden", "hollow", "valley", "common"] \
				and (stir_pick < 0
				or int(o.left) < int((options[stir_pick] as Dictionary).left)):
			stir_pick = k
	if stir_pick >= 0 and (pick < 0
			or int((options[stir_pick] as Dictionary).left) < int((options[pick] as Dictionary).left)):
		pick = stir_pick
	if pick < 0:
		pick = 0
		for k in options.size():
			if int((options[k] as Dictionary).left) < int((options[pick] as Dictionary).left):
				pick = k
	return pick

## Map a pick among (possibly filtered) options back to the node's real
## next[] index — _resolve_walk steps by that.
func _branch_index_of(fork_id: int, options: Array, pick: int) -> int:
	var target := int((options[clampi(pick, 0, options.size() - 1)] as Dictionary).node)
	var nxt := board.next_of(fork_id)
	for k in nxt.size():
		if int(nxt[k]) == target:
			return k
	return 0

func _prompt_branch_mapped(seat: int, fork_id: int, options: Array) -> int:
	var pick := await _prompt_branch(seat, options)
	return _branch_index_of(fork_id, options, pick)

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
	for _k in n:
		var nxt := board.next_of(cur)
		if nxt.is_empty():
			break
		var step := int(nxt[0])
		if nxt.size() > 1:
			# The same no-rng chooser the bot walk uses — preview, aim and
			# the real fork must agree or the heatmap lies (doc 28 §15).
			var options := _fork_options(cur)
			step = int((options[_pref_pick(seat, options)] as Dictionary).node)
		cur = step
	return cur

## THE FERRYMAN'S TOLL, in passing: crossing a toll stone mid-walk pays 2♠ to
## the Ferryman (the estate; no player owns the river — doc 28 §6). Landing on
## one is handled in the reveal. The player-owned tollgate died with the ring.
func _pay_passthrough_tolls(seat: int, path: Array) -> void:
	for k in path.size() - 1:   # intermediate stones only; the landing reveals
		var idx := int(path[k])
		if board.type_at(idx) == Spaces.FERRY_TOLL:
			if _veil_negates(seat):
				if not _fast:
					_flash_line(Dialog.text("procession.items.veil") % roster[seat].name,
						roster[seat].color, seat)
				continue
			var pay := mini(2, grudge[seat])
			if pay <= 0:
				continue
			grudge[seat] -= pay
			stats[seat].lost += pay
			stats[seat].hazards += 1
			_pop_at(board.space_pos(idx) + Vector3(0, 1.0, 0), seat, -pay,
				roster[seat].color)   # F11: the fee falls off at the arch
			if not _fast:
				_flash_line(Dialog.text("procession.narration.ferry_pass") % roster[seat].name,
					roster[seat].color, seat)

## CROW COURT (doc 28 §4 minor 5): the first pawn to pass or land on the
## court's stone is robbed of 3 pennies — then the murder scatters, paid.
## Veil-negatable like any hazard (the item is the insurance it claims).
func _crow_court_strike(seat: int, path: Array) -> void:
	if stirs.crow_stone < 0 or stirs.crow_done or not path.has(stirs.crow_stone):
		return
	stirs.crow_done = true
	var stone := stirs.crow_stone
	stirs.crow_stone = -1
	if _veil_negates(seat):
		if not _fast:
			_flash_line(Dialog.text("procession.items.veil") % roster[seat].name,
				roster[seat].color, seat)
			_scatter_crows()
		return
	var pay := mini(3, grudge[seat])
	if pay > 0:
		grudge[seat] -= pay
		stats[seat].lost += pay
		stats[seat].hazards += 1
		_pop_at(board.space_pos(stone) + Vector3(0, 1.2, 0), seat, -pay,
			roster[seat].color)
	if not _fast:
		_flash_line(Dialog.text("procession.stirs.crow_strike") % roster[seat].name,
			roster[seat].color, seat)
		_scatter_crows()

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
			Spaces.CART: await _resolve_cart(seat, name, col)
			Spaces.SEANCE: await _resolve_seance(seat, name, col)
			Spaces.FERRY_TOLL: _resolve_ferry(seat, name, col)
			Spaces.CROSSROADS: executor.say(Executor.pick(Executor.CROSSROADS_LAND, _voice_rng, [name]), col)
			Spaces.VENDETTA: await _resolve_vendetta(seat, name, col)
			_: executor.say(Executor.pick(Executor.BLANK, _voice_rng, [name]), col)
	# THE WAKE (doc 28 §4 minor 4), layered over the stone's own resolve:
	# landing among the mourners costs a toast (−2) but pays a wreath rumor —
	# a séance-style spin. Not a hazard: no veil, no hazard stat.
	if stirs.wake_left > 0 and stirs.wake_stones.has(idx) \
			and not _arrived_this_round.has(seat):
		var toast := mini(2, grudge[seat])
		if toast > 0:
			grudge[seat] -= toast
			stats[seat].lost += toast
			_pop_grudge(seat, -toast)
		if not _fast:
			_flash_line(Dialog.text("procession.stirs.wake_toast") % name, col, seat)
		await _resolve_seance(seat, name, col)
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
	# The board returns to wordless once the landing has been read (ZERO-ENGLISH).
	board.clear_landing_label()

# --------------------------------------------------------------------------
# F24 — REVEAL-CASCADE REACT BUTTONS. During a landing reveal the WAITING players
# can tap to float an attributed laugh/jeer/wince over the victim's stone. Purely
# cosmetic, rate-limited, couch-first (remote seats are guarded out cleanly until
# a net path exists). No sim impact — it never touches grudge/wreaths/rng.
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
	if _veil_negates(seat):
		executor.say(Dialog.text("procession.items.veil_grave") % name, col)
		return
	var owner := board.grave_owner(positions[seat])
	stats[seat].graves += 1
	stats[seat].hazards += 1
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

## GRAVE GOODS — the free item box: one CHEAP-tier ware (EVENT stream), the
## modern-MP positive-variance read. Full hands leave the box rattling.
func _resolve_box(seat: int, name: String, col: Color) -> void:
	var id := String(Spaces.BOX_POOL[_event_rng.randi_range(0, Spaces.BOX_POOL.size() - 1)])
	Sfx.play("card", -6.0)
	if _grant_ware(seat, id):
		executor.say(Executor.pick(Executor.GRAVE_GOODS, _voice_rng, [name])
			+ "  (%s)" % String(Spaces.ware(id).name), col)
	else:
		executor.say(Dialog.text("procession.items.box_full") % name, col)

## THE PEDDLER'S CART — the PRICED shop (doc 28 §6 wares table). The free
## handout died with P2; the peddler quotes prices and the table watches.
func _resolve_cart(seat: int, name: String, col: Color) -> void:
	executor.say(Executor.pick(Executor.CART, _voice_rng, [name]), col)
	await _shop(seat)

## THE FERRYMAN'S TOLL, landed on: pay 2♠ to the river. No owner, no refunds.
func _resolve_ferry(seat: int, name: String, col: Color) -> void:
	if _veil_negates(seat):
		executor.say(Dialog.text("procession.items.veil") % name, col)
		return
	var pay := mini(2, grudge[seat])
	grudge[seat] -= pay
	stats[seat].lost += pay
	stats[seat].hazards += 1
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

func _resolve_seance(seat: int, name: String, col: Color) -> void:
	# The SIM decides the slot (unchanged rng draw); the visible wheel is theater
	# that spins TO it (F13). Effects apply as the needle lands, so the dial reads
	# like it caused the outcome — but it never decides anything.
	var slot := _event_rng.randi_range(0, Spaces.SEANCE_WHEEL.size() - 1)
	var w: Dictionary = Spaces.SEANCE_WHEEL[slot]
	stats[seat].seances += 1
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
	# The three ANNOUNCED award races first (doc 28 §7 — races visible), then
	# the will-clause races (the ◆ ceremony trophies).
	for a in night_awards:
		var alead := _stat_leader(String(a.stat))
		if alead >= 0:
			lines.append(Dialog.text("procession.interim.line") % [_award_title(a),
				roster[alead].name,
				Dialog.text("procession.interim.metric_generic") % int(stats[alead].get(String(a.stat), 0))])
		else:
			lines.append(Dialog.text("procession.interim.contested") % _award_title(a))
	for c in clauses:
		var lead := _stat_leader(String(c.stat))
		if lead >= 0:
			lines.append(Dialog.text("procession.interim.line") % [
				c.title, roster[lead].name, _interim_metric(String(c.stat), lead)])
		else:
			lines.append(Dialog.text("procession.interim.contested") % c.title)
	# P3 (doc 28 §9c): the interim reading ARMS the compact live tracker — from
	# here the 3 announced races ride top-right through every roll phase.
	_tracker_live = true
	_refresh_award_tracker()
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
# MINIGAME BLOCK — one per CYCLE (doc 28 §2), drawn WITHOUT replacement per
# night from the full 15-game catalog; THE INVITATION overrides one draw.
# --------------------------------------------------------------------------
func _minigame_block() -> void:
	_phase = "minigame"
	executor.clear_banner()
	# The BOOK ordering (doc 32): the card was drawn at roll-phase start.
	# THE INVITATION still takes the slot — the pre-drawn card returns to the
	# night's pool (without-replacement stays honest); sealed bets STAND (you
	# bet on the cycle's outcome, whatever card ends up on the table).
	var mid := _cycle_mini
	_cycle_mini = ""
	if _invitation_pick != "":
		if mid != "":
			_mini_pool.append(mid)
		mid = _invitation_pick
		_invitation_pick = ""
		_mini_pool.erase(mid)
	if mid == "":
		mid = _draw_minigame()
	if book != null:
		book.slam()   # last call — the thump is the intro card's herald
	# The roulette (F22) is theater that lands on the pre-decided card.
	if _fast:
		pass   # the soak skips the roulette entirely
	elif _capture:
		roulette.present(MINIGAME_ORDER, mid)   # fire, snap mid-spin, then wait out
		await _beat(1.2)
		await _cap_snap("roulette")
		while not roulette.finished:
			await get_tree().process_frame
	else:
		await roulette.present(MINIGAME_ORDER, mid)
	_hide_announce()
	var placements: Array = await _run_minigame(mid)
	if placements.is_empty():
		return   # module error already surfaced — the cycle is voided, never randomized
	await _settle_minigame(mid, placements)

## THE INTERLUDE GROUNDS MINIGAME (P3, doc 28 §2): between nights, after the
## will reading + LAST RITES, one more game on the grounds. Interlude 1 is
## drawn RANDOM from the games not yet played that night; every later
## interlude is picked by the current DOORMAT (bottom wreaths — announced,
## a dignity beat, not a hidden hand), never repeating interlude 1's pick.
## Placements pay the normal cycle settlement (pennies + wreaths), landing
## AFTER the night record — the night reads as scored, the match feels it.
## Bots pick from the EVENT stream (seeded); a human doormat draws nothing.
func _interlude_minigame() -> void:
	_phase = "interlude"
	executor.clear_banner()
	# The overnight family only (producer ruling): the theater trio.
	var pool := THEATER_ORDER.duplicate()
	var pick := ""
	if _interlude1_pick == "":
		# --- interlude 1: the estate deals (EVENT stream, one randi) ---
		pick = String(pool[_event_rng.randi_range(0, pool.size() - 1)])
		_interlude1_pick = pick
		if not _fast:
			_reveal_seat = -1
			executor.say(Dialog.text("procession.interlude.random_line") \
				% String((MINIGAMES[pick] as Dictionary).name), Color(0.85, 0.78, 1.0))
			await _beat(2.0)
			executor.clear_banner()
	else:
		# --- interlude 2+: the DOORMAT's privilege (no repeat of interlude 1) ---
		pool.erase(_interlude1_pick)
		var doormat := int(_roll_order().back())
		if _is_local_human(doormat) and _drama_visible():
			var entries: Array = []
			for id in pool:
				entries.append({"label": String((MINIGAMES[String(id)] as Dictionary).name)})
			var p: int = await _pick_prompt(
				Dialog.text("procession.interlude.doormat_header") % roster[doormat].name,
				Dialog.text("procession.interlude.doormat_sub"), roster[doormat].color,
				entries, Dialog.text("procession.interlude.deal_label"), false, 12.0)
			# A declined privilege hands the deal back to the estate (seeded).
			pick = String(pool[_event_rng.randi_range(0, pool.size() - 1)]) if p < 0 \
				else String(pool[p])
		else:
			pick = String(pool[_event_rng.randi_range(0, pool.size() - 1)])   # bots pick seeded
		if not _fast:
			_reveal_seat = doormat
			executor.say(Dialog.text("procession.interlude.doormat_line") % [
				roster[doormat].name, String((MINIGAMES[pick] as Dictionary).name)],
				roster[doormat].color)
			await _beat(2.0)
			executor.clear_banner()
	if not _fast:
		_announce_text(Dialog.text("procession.interlude.header") + "\n\n"
			+ Dialog.text("procession.interlude.card_line") \
			% String((MINIGAMES[pick] as Dictionary).name), Color(1, 0.88, 0.5))
		if _capture and night_index == 1:
			await _cap_snap("interlude_card")
		await _beat(2.2)
		_hide_announce()
	var placements: Array = await _run_minigame(pick)
	if not placements.is_empty():
		await _settle_minigame(pick, placements)

## Draw the cycle's game: without replacement per night (pool refills at night
## start); THE INVITATION's pick takes the slot and leaves the pool intact
## minus itself. EVENT stream, one randi per natural draw.
func _draw_minigame() -> String:
	if _mini_pool.is_empty():
		_mini_pool = CYCLE_ORDER.duplicate()
	if _invitation_pick != "":
		var pick := _invitation_pick
		_invitation_pick = ""
		_mini_pool.erase(pick)
		return pick
	return String(_mini_pool.pop_at(_event_rng.randi_range(0, _mini_pool.size() - 1)))

## A bot's Book of the Dead pick (doc 32): seeded, weighted, imperfect — the
## form table (match minigame wins + wreath standings) tilts the odds, a real
## scatter keeps the book humble, and a bot backs itself a shade too often
## (the estate admires confidence). One EVENT draw per bot per cycle.
func _bot_bet_target(seat: int) -> int:
	var w: Array[float] = []
	var total := 0.0
	for t in roster.size():
		var v := 1.0 + float(mini_wins_match[t]) * 0.55 + float(wreaths[t]) * 0.04
		if t == seat:
			v *= 1.15
		w.append(v)
		total += v
	var roll := _event_rng.randf() * total
	for t in w.size():
		roll -= w[t]
		if roll <= 0.0:
			return t
	return roster.size() - 1

## THE RECKONING — settlement per cycle (doc 28 §6): pennies 10/6/3/1 +
## wreaths 2/1/1/0. TEAM-AWARE (doc 28 §15): a 2v2 game pays the winning
## teammates equal FIRST-tier and the losers equal THIRD-tier — never
## seat-ordinal inequity. Genuine ties (equal module scores) take the LOWER
## award. Results were validated against the real roster before this runs.
func _settle_minigame(mid: String, placements: Array) -> void:
	_phase = "reckoning"
	var meta: Dictionary = MINIGAMES.get(mid, {})
	var tiers: Array[int] = []
	tiers.resize(placements.size())
	if String(meta.get("team", "ffa")) == "2v2" and placements.size() == 4:
		tiers[0] = 0; tiers[1] = 0; tiers[2] = 2; tiers[3] = 2
	else:
		for k in placements.size():
			tiers[k] = k
		_apply_tie_tiers(placements, tiers)
	# THE BOOK pays FIRST (doc 32 v1 — before placements pay): seals flip to
	# cameos, the correct catch gold; a laurel wisp rides the winners' toys
	# next cycle; self-bet-and-lose earns the Executor's public ribbing.
	if book != null:
		var winners: Array = []
		for k in placements.size():
			if int(tiers[k]) == 0:
				winners.append(int(placements[k]))
		var correct: Array = book.reveal(winners, _fast)
		for c in correct:
			_laurel_next[int(c)] = true
			if not _fast:
				MomentScribe.capture("book_paid",
					"%s READ THE NIGHT RIGHTLY" % roster[int(c)].name, 5, [int(c)], mid)
		if not _fast:
			await _beat(2.0)
			for i in roster.size():
				if int(book.bets[i]) == i and not winners.has(i):
					_reveal_seat = i
					executor.say(Dialog.text("procession.book.selfbet_ribbing") \
						% [roster[i].name, roster[i].name], roster[i].color)
					await _beat(2.0)
					executor.clear_banner()
					break   # the joke lands once per settlement
			book.clear_reveal()
	var lines: Array[String] = []
	for k in placements.size():
		var p := int(placements[k])
		var tier := int(tiers[k])
		var pd: int = MINI_PENNIES[tier] if tier < MINI_PENNIES.size() else 0
		var wd: int = MINI_WREATHS[tier] if tier < MINI_WREATHS.size() else 0
		grudge[p] += pd
		wreaths[p] += wd
		wreath_src[p].mini += wd
		if tier == 0:
			stats[p].mini_wins += 1
			mini_wins_match[p] += 1
		lines.append(Dialog.text("procession.reckoning.line") % [
			roster[p].name, k + 1, pd, Spaces.PENNY_GLYPH, wd, Spaces.WREATH_GLYPH])
		_pop_grudge(p, pd)
	_announce_text(Dialog.text("procession.reckoning.header") + "\n\n" + "\n".join(lines), Color(0.95, 0.85, 0.6))
	_refresh_hud()
	_push_net()
	await _beat(2.4)
	_hide_announce()

## Genuine ties, FFA only: when the module reports scores ("points": seat ->
## score) and adjacent placements hold EQUAL scores, the whole tied group takes
## the LOWEST rank's award (doc 28 §15 — no seat-index favoritism). The sim
## path reports no scores, so it never ties.
func _apply_tie_tiers(placements: Array, tiers: Array[int]) -> void:
	var scores: Dictionary = _mini_results.get("points", {})
	if scores.is_empty():
		return
	for v in placements:
		if not scores.has(int(v)):
			return   # partial score sheet — placements stand as ranked
	var k := 0
	while k < placements.size():
		var j := k
		while j + 1 < placements.size() \
				and int(scores[int(placements[j + 1])]) == int(scores[int(placements[k])]):
			j += 1
		for m in range(k, j + 1):
			tiers[m] = j
		k = j + 1

## The module OWNS the screen. With three cameras alive in one tree (the
## estate hub's, this board's, and the module's own), Godot's clear_current
## promotion is a lottery — it can hand the frame to the estate's parked
## camera, framing a minigame from the forecourt sixty units away (Alex's
## catch, G3 live session). Most module cameras never mark themselves
## current (they relied on the single-camera fallback), so assert the
## module's first camera explicitly; a module that builds its camera later
## in its own flow will assert itself past this.
func _assert_module_camera(module: Node) -> void:
	var cams := module.find_children("*", "Camera3D", true, false)
	if not cams.is_empty():
		(cams[0] as Camera3D).make_current()

## The real module contract, reused from inside the board (spec §3). Under
## --autoplay the deterministic MINISIM stands in so the full night resolves
## fast and byte-identically; --realmini forces the live module. Results are
## VALIDATED against the real roster — a misfiling module voids the cycle
## with a surfaced error, it never gets silently re-randomized (doc 28 §15).
func _run_minigame(id: String) -> Array:
	var meta: Dictionary = MINIGAMES.get(id, {})
	if _minisim:
		return _sim_placements()
	if String(meta.get("launch", "contract")) == "legacy":
		return await _run_legacy_minigame(id, meta)
	var scene: PackedScene = load(String(meta.get("scene", "")))
	if scene == null:
		return await _module_error(id, "scene missing")
	var module: Node = scene.instantiate()
	board.visible = false
	cam.current = false
	_ui.visible = false
	add_child(module)
	_assert_module_camera(module)
	_mini_done = false
	_mini_out = []
	_mini_results = {}
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
	if not _valid_placements(_mini_out):
		return await _module_error(id, str(_mini_out))
	return _mini_out

## THE PAR ADAPTER (P3 — landmine 3, estate.gd's "gamestate" launch pattern):
## Par is a legacy launcher — no begin(), root-parented, GameState-reset, but
## it duck-types finished(results) like every module. This mirrors estate.gd's
## _launch_game_swap "gamestate" branch: reset GameState for the roster, place
## the module at the TREE ROOT (it owns the frame; PartySetup's boot-time
## free_stray_root_nodes is the safety net — never called here, since the
## procession itself rides the root at merge), and transition on the emitted
## signal, never a computed win (landmine 7). Procession's own EnvKit rig
## stands down while Par runs (a legacy scene brings its own world).
func _run_legacy_minigame(id: String, meta: Dictionary) -> Array:
	var scene: PackedScene = load(String(meta.get("scene", "")))
	if scene == null:
		return await _module_error(id, "scene missing")
	var module: Node = scene.instantiate()
	if not module.has_signal("finished"):
		module.free()
		return await _module_error(id, "no finished signal")
	# Par reads seats from PlayerInput/GameState, not a roster dict — make the
	# board's bot flags visible to it (autoplay probes included).
	for pl in roster:
		PlayerInput.set_bot(int(pl.index), bool(pl.bot))
	GameState.player_count = roster.size()
	GameState.rounds_total = 2   # one board cycle's worth (contract games run rounds=2)
	GameState.reset_match()
	board.visible = false
	cam.current = false
	_ui.visible = false
	if breath.meter != null:
		breath.meter.visible = false
	_envkit_standdown(true)
	_mini_done = false
	_mini_out = []
	_mini_results = {}
	module.finished.connect(_on_mini_finished, CONNECT_ONE_SHOT)
	get_tree().root.add_child(module)   # root placement — the legacy contract
	_assert_module_camera(module)
	while not _mini_done:
		await get_tree().process_frame
	if is_instance_valid(module):
		module.queue_free()
	_envkit_standdown(false)
	board.visible = true
	cam.current = true
	_ui.visible = true
	if not _valid_placements(_mini_out):
		return await _module_error(id, str(_mini_out))
	return _mini_out

## Mute/restore the procession's own EnvKit world + light rig while a legacy
## full-scene module runs (two live WorldEnvironments fight; a null
## environment stands aside). Presentation only.
var _envkit_saved: Environment = null

func _envkit_standdown(down: bool) -> void:
	for n in find_children("*", "", false, false):
		if not n.is_in_group("envkit_rig"):
			continue
		if n is WorldEnvironment:
			if down:
				_envkit_saved = (n as WorldEnvironment).environment
				(n as WorldEnvironment).environment = null
			elif _envkit_saved != null:
				(n as WorldEnvironment).environment = _envkit_saved
		elif n is Node3D:
			(n as Node3D).visible = not down

## Placements must be a permutation of the real roster — every seat exactly
## once. Anything else is a module bug the table deserves to SEE.
func _valid_placements(p: Array) -> bool:
	if p.size() != roster.size():
		return false
	var seen := {}
	for v in p:
		var s := int(v)
		if s < 0 or s >= roster.size() or seen.has(s):
			return false
		seen[s] = true
	return true

func _module_error(id: String, got: String) -> Array:
	print("PROCESSION MODULE ERROR game=%s results=%s want=permutation of %d seats — cycle voided, no settlement" % [
		id, got, roster.size()])
	if not _fast:
		_announce_text(Dialog.text("procession.mini.error") % String(
			(MINIGAMES.get(id, {}) as Dictionary).get("name", id)), Color(1, 0.5, 0.4))
		await _beat(2.2)
		_hide_announce()
	return []

var _mini_done := false
var _mini_out: Array = []
var _mini_results := {}    # the module's full results dict (scores feed tie policy)

func _on_mini_finished(results: Dictionary) -> void:
	_mini_results = results
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
		var reached := _event_rng.randf() < 0.45
		if bool(arrived[i]):
			continue
		if not reached and not safe.has(positions[i]):
			if _veil_negates(i):
				if not _fast:
					_flash_line(Dialog.text("procession.items.veil") % roster[i].name,
						roster[i].color, i)
				continue
			_slip_back(i, 2)
			caught.append(String(roster[i].name))
			stats[i].lost += 1
			stats[i].hazards += 1
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
			# DR (doc 29 opt A): the clause pays a WREATH now, not a ◆ Deed —
			# booked to the announced-award stream so the finale sums stay honest.
			wreaths[winner_seat] += WILL_WREATHS
			wreath_src[winner_seat].award += WILL_WREATHS
			_pop_grudge(winner_seat, WILL_WREATHS, Spaces.WREATH_GLYPH)   # F10: the wreath flies to the chip
			lines.append(Dialog.text("procession.will_reading.line") % [
				c.title, roster[winner_seat].name, c.desc, wreaths[winner_seat]])
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

## THE CROWN — most wreaths inherits the estate. JOINT HEIRS share the banner
## (and the monument) when the whole tie-break chain holds.
func _heir_crowned() -> void:
	_phase = "heir"
	var heirs := _match_heirs()
	winner = int(heirs[0])
	var joint := heirs.size() > 1
	var heir_names: Array[String] = []
	for h in heirs:
		heir_names.append(String(roster[int(h)].name))
	var crown_name := " & ".join(heir_names)
	# The heir is written to the estate as a permanent monument (kind="heir").
	# Skipped under the autoplay SOAK so the verification stays save-independent
	# and byte-identical run to run (real play / the estate merge always writes).
	var pl: Dictionary = roster[winner]
	if not _autoplay:
		for h in heirs:
			var hp: Dictionary = roster[int(h)]
			EstateState.monuments.append({
				"owner": String(hp.name),
				"color": Color(hp.color).to_html(),
				"label": Dialog.text("procession.heir.monument") % [hp.name, wreaths[int(h)]],
				"night": EstateState.nights_played,
				"kind": "heir",
			})
			EstateState.add_graffiti(Dialog.text("procession.heir.graffiti") % hp.name)
		EstateState.save_estate()
	Music.play_slot("ceremony")
	var podium := Podium.new()
	add_child(podium)
	var order := _match_order()
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
	var crown: String
	if joint:
		crown = Dialog.text("procession.heir.crown_joint") % [crown_name, wreaths[winner],
			Spaces.WREATH_GLYPH]
	else:
		crown = Dialog.text("procession.heir.crown_wreaths") % [crown_name, wreaths[winner],
			Spaces.WREATH_GLYPH]
	if _autoplay:
		crown += " · SEED %d" % seed_value
	_announce_text(crown, Color(pl.color))
	_announce.visible = true
	# The victor's crown — the newsreel's headline still (F5).
	MomentScribe.capture("heir_crowned", "%s INHERITS THE ESTATE (%d WREATHS)" % [
		crown_name, wreaths[winner]], 3, heirs, "procession")
	if _capture:
		await _cap_snap("heir_crowned")
	else:
		VerifyCapture.snap("heir_crowned")
	# M2 PODIUM EXIT (Andrew): the crown used to hold a fixed 6s before folding —
	# the "stuck in the podium screen" beat. A human couch now leaves at its
	# leisure (any seat's A / click / Enter), while the _fast verify path keeps its
	# 0.2s clock so receipts are unchanged (the snap above already fired).
	if _fast:
		await _beat(0.2)
	elif _autoplay:
		# Unattended slowsim capture: the crown holds its six seconds and
		# folds. Podium._has_human() reads the DEVICE map (the keyboard still
		# claims seat 0 in a CLI boot), so an --autoplay run must never gate
		# on the couch — a stills chain hung at the victory screen for 12
		# minutes before the producer noticed (tenth watch).
		await _beat(6.0)
	else:
		await podium.await_continue(6.0)
	if is_instance_valid(podium):
		podium.queue_free()
	_topbar.visible = true
	_chiprow.visible = true

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

## The MATCH record — the canonical receipt line (per-night PROCESSION_NIGHT
## lines already printed at each settlement).
func _emit_tally() -> void:
	var heirs := _match_heirs()
	var heir_names: Array[String] = []
	for h in heirs:
		heir_names.append(String(roster[int(h)].name))
	var src := {"arrival": [], "mini": [], "award": [], "liquid": []}
	for i in roster.size():
		for k in src:
			(src[k] as Array).append(int(wreath_src[i].get(k, 0)))
	var tally := {
		"seed": seed_value, "board": String(BoardGraph.BOARD.id),
		"nights": match_nights, "turn_cap": turn_cap,
		"heirs": heirs.duplicate(), "heir": winner,
		"heir_name": " & ".join(heir_names),
		"wreaths": wreaths.duplicate(), "grudge": grudge.duplicate(),
		"src": src,
		"board_firsts": board_firsts.duplicate(),
		"mini_wins": mini_wins_match.duplicate(),
		"moved": moved_total.duplicate(),
	}
	print("PROCESSION_MATCH ", JSON.stringify(tally))
	for i in roster.size():
		print("  seat %d %s: %s%d (arr %d + mini %d + awd %d + liq %d)  %d%s  moved=%d%s" % [
			i, roster[i].name, Spaces.WREATH_GLYPH, wreaths[i],
			int(wreath_src[i].arrival), int(wreath_src[i].mini),
			int(wreath_src[i].award), int(wreath_src[i].liquid),
			grudge[i], Spaces.PENNY_GLYPH, moved_total[i],
			"  HEIR" if heirs.has(i) else ""])
	print("PROCESSION_HEIR %s (seed %d, %d nights)" % [" & ".join(heir_names), seed_value, match_nights])
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

## Public, receipt-shaped event facts. `site` remains a Vector3 on Godot's
## Variant wire; arrays are deep-copied so the snapshot cannot alias live sim.
func _stir_wire_info(info: Dictionary) -> Dictionary:
	var out := {}
	for key in ["entry", "exit", "from", "to", "node", "stones", "site"]:
		if not info.has(key):
			continue
		var value: Variant = info[key]
		if typeof(value) == TYPE_ARRAY:
			value = (value as Array).duplicate(true)
		elif typeof(value) == TYPE_DICTIONARY:
			value = (value as Dictionary).duplicate(true)
		out[key] = value
	return out

func _net_stirs_state() -> Dictionary:
	var infos := {}
	for id in [stirs.minor, stirs.major]:
		if id != "" and _stir_info_by_id.has(id):
			infos[id] = (_stir_info_by_id[id] as Dictionary).duplicate(true)
	return {
		"major": stirs.major, "minor": stirs.minor,
		"major_fired": stirs.major_fired, "minor_fired": stirs.minor_fired,
		"info": infos,
		"flood_left": stirs.flood_left, "wake_left": stirs.wake_left,
		"crow_stone": stirs.crow_stone, "crow_done": stirs.crow_done,
	}

func _net_state() -> Dictionary:
	var routes: Array = []
	for i in roster.size():
		routes.append(board.route_of(positions[i]) if board else "common")
	return {
		"phase": _phase, "round": round_num,
		"grudge": grudge.duplicate(),
		"positions": positions.duplicate(), "moved": moved_total.duplicate(),
		"routes": routes, "arrived": arrived.duplicate(),
		"arrival_order": arrival_order.duplicate(), "bell_round": bell_round,
		"banner": _reveal.get_parsed_text() if _reveal and _reveal.visible else "",
		"stirs": _net_stirs_state(),
	}

func _net_apply(state: Dictionary) -> void:
	_phase = String(state.get("phase", _phase))
	round_num = int(state.get("round", round_num))
	grudge.assign(state.get("grudge", grudge))
	# Topology must exist before a mirrored pawn can be seated on a Stirs-born
	# node. Old snapshots without this key remain backward-compatible.
	if state.has("stirs"):
		_net_apply_stirs(state["stirs"] as Dictionary)
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

## Apply full current facts, then replay only fired IDs this board has never
## seen. This is intentionally snapshot logic, not an event queue: a guest's
## first packet may arrive minutes after both mutations.
func _net_apply_stirs(wire: Dictionary) -> void:
	stirs.major = String(wire.get("major", stirs.major))
	stirs.minor = String(wire.get("minor", stirs.minor))
	stirs.flood_left = int(wire.get("flood_left", stirs.flood_left))
	stirs.wake_left = int(wire.get("wake_left", stirs.wake_left))
	stirs.crow_stone = int(wire.get("crow_stone", stirs.crow_stone))
	stirs.crow_done = bool(wire.get("crow_done", stirs.crow_done))
	var infos: Dictionary = wire.get("info", {})
	for kind in ["minor", "major"]:
		var id := stirs.minor if kind == "minor" else stirs.major
		var fired := bool(wire.get("%s_fired" % kind, false))
		if kind == "minor":
			stirs.minor_fired = fired
		else:
			stirs.major_fired = fired
		if not fired or id == "" or _stir_replayed.has(id) or not infos.has(id):
			continue
		var info: Dictionary = (infos[id] as Dictionary).duplicate(true)
		if not _net_stir_info_ready(id, info):
			push_warning("PROCESSION mirror: incomplete Stirs info for %s" % id)
			continue
		# Guard BEFORE mutation. Even if presentation callbacks provoke another
		# apply in the same frame, this event id cannot touch the graph twice.
		_stir_replayed[id] = true
		_stir_info_by_id[id] = info
		_net_replay_stir(id, info)
		_stir_settle(id, info)
		print("PROCESSION_NET_STIR_REPLAY id=%s nodes=%d" % [id, board.nodes.size()])
	if stirs.flood_left <= 0 and not _flood_fx.is_empty():
		_clear_stir_fx(_flood_fx)
	if stirs.wake_left <= 0 and not _wake_fx.is_empty():
		_clear_stir_fx(_wake_fx)
	if stirs.crow_done and not _crow_fx.is_empty():
		_clear_stir_fx(_crow_fx)

func _net_stir_info_ready(id: String, info: Dictionary) -> bool:
	match id:
		"bone_bridge", "reaper_shortcut", "procession_road":
			return info.has("entry") and info.has("exit") \
				and info.has("stones") and info.has("site")
		"landslip", "hearse_moves":
			return info.has("from") and info.has("to") and info.has("site")
		"hungry_grave", "crow_court":
			return info.has("node") and info.has("site")
		"wake":
			return info.has("stones") and info.has("site")
		"flood":
			return info.has("site")
	return false

## Replay from host-chosen facts only: no draw, no candidate search, no client
## RNG. Each topology-changing case calls the same BoardGraph mutation API as
## ProcessionStirs.apply().
func _net_replay_stir(id: String, info: Dictionary) -> void:
	match id:
		"bone_bridge":
			var entry := int(info.entry)
			var exit_node := int(info.exit)
			var pa := board.space_pos(entry)
			var pb := board.space_pos(exit_node)
			var deck_y := ProcessionGrounds.WATER_Y + 0.55
			var deck: Array = [
				Vector3(lerpf(pa.x, pb.x, 0.36), deck_y, lerpf(pa.z, pb.z, 0.36)),
				Vector3(lerpf(pa.x, pb.x, 0.64), deck_y, lerpf(pa.z, pb.z, 0.64)),
			]
			board.register_route("bridge", "THE BONE BRIDGE", Color("d9d2bc"),
				"THE BOG'S OWN SHORTCUT · IT REMEMBERS BEING WALKED")
			_net_check_stir_ids(id, board.append_stir_chain(entry, exit_node, deck,
				"bridge"), info.stones as Array)
		"reaper_shortcut":
			board.register_route("carve", "THE REAPER'S CUT", Color("7fd6a8"),
				"HE OPENED IT · HE DID NOT SAY FOR WHOM")
			_net_check_stir_ids(id, board.append_stir_chain(int(info.entry),
				int(info.exit), [info.site as Vector3], "carve"), info.stones as Array)
		"landslip":
			board.replace_next(int(info.from), [int(info.to)])
		"procession_road":
			var entry := int(info.entry)
			var exit_node := int(info.exit)
			var pa := board.space_pos(entry)
			var pb := board.space_pos(exit_node)
			var lane: Array = []
			for k in 4:
				lane.append(ProcessionGrounds.snap(pa.lerp(pb,
					(float(k) + 1.0) / 5.0), 0.0))
			board.register_route("ghostroad", "THE PROCESSION ROAD", Color("bfd8ea"),
				"DEAD MEN PACED IT FIRST · IT WHISPERS")
			_net_check_stir_ids(id, board.append_stir_chain(entry, exit_node, lane,
				"ghostroad"), info.stones as Array)
		"hungry_grave":
			board.retype_stone(int(info.node), Spaces.OPEN_GRAVE)
		"hearse_moves":
			board.orphan_cart()
			board.retype_stone(int(info.from), Spaces.BLANK)
			board.retype_stone(int(info.to), Spaces.CART, false)
		"wake":
			stirs.wake_stones = (info.stones as Array).duplicate()
		"crow_court":
			# Current crow_stone/crow_done arrived above; the original node stays
			# in info so a still-sitting court can be staged on first apply.
			pass
		"flood":
			pass
	if _minimap != null:
		_minimap._refit_if_grown()
		_minimap.queue_redraw()

func _net_check_stir_ids(id: String, actual: Array, expected: Array) -> void:
	if actual != expected:
		push_error("PROCESSION mirror: %s stone ids host=%s client=%s" % [
			id, str(expected), str(actual)])

# --------------------------------------------------------------------------
# HEADLESS STIRS MIRROR PROBE (--stirnettest). This builds an actual fresh
# Procession scene and exercises _net_apply(_net_state()), including a second
# identical apply for the event-id idempotence proof.
# --------------------------------------------------------------------------
func _stirnettest_run() -> void:
	night_index = 1
	round_num = 3
	await _fire_stir("minor", stirs.minor)
	round_num = 5
	await _fire_stir("major", stirs.major)
	var state := _net_state()
	var wire: Dictionary = state.stirs
	var infos: Dictionary = wire.info
	print("PROCESSION_NET_STIR_WIRE major=%s fired=%s info=%s minor=%s fired=%s info=%s flood_left=%d wake_left=%d" % [
		String(wire.major), str(bool(wire.major_fired)), str(infos.get(wire.major, {})),
		String(wire.minor), str(bool(wire.minor_fired)), str(infos.get(wire.minor, {})),
		int(wire.flood_left), int(wire.wake_left)])

	var mirror = load("res://estate/procession/procession.tscn").instantiate()
	# Suppress its deferred self-boot; this is a real render shell with a fresh
	# base graph, but no second simulation is allowed to start.
	mirror._started = true
	mirror._autoplay = true
	mirror._fast = true
	mirror._mirror = true
	mirror.roster = roster.duplicate(true)
	get_tree().root.add_child(mirror)
	mirror._init_arrays()
	mirror._build_world()
	mirror._build_hud()
	mirror._choose_clauses()
	var base_nodes: int = mirror.board.nodes.size()
	mirror._net_apply(state)
	var host_nodes: int = board.nodes.size()
	var client_nodes: int = mirror.board.nodes.size()
	var host_adj := _stir_graph_checksum(board, true)
	var client_adj := _stir_graph_checksum(mirror.board, true)
	var host_shape := _stir_graph_checksum(board, false)
	var client_shape := _stir_graph_checksum(mirror.board, false)
	var first_replayed: int = mirror._stir_replayed.size()
	mirror._net_apply(state)
	var replay_nodes: int = mirror.board.nodes.size()
	var replay_adj := _stir_graph_checksum(mirror.board, true)
	var replay_shape := _stir_graph_checksum(mirror.board, false)
	var same := host_nodes == client_nodes and host_adj == client_adj \
		and host_shape == client_shape
	var idempotent: bool = replay_nodes == client_nodes and replay_adj == client_adj \
		and replay_shape == client_shape and mirror._stir_replayed.size() == first_replayed
	print("PROCESSION_NET_STIR_TOPOLOGY base_nodes=%d host_nodes=%d client_nodes=%d host_adj=%s client_adj=%s host_shape=%s client_shape=%s same=%s replay_nodes=%d replay_adj=%s idempotent=%s" % [
		base_nodes, host_nodes, client_nodes, host_adj, client_adj, host_shape,
		client_shape, str(same), replay_nodes, replay_adj, str(idempotent)])

	var settle_ok := true
	if stirs.major == "bone_bridge":
		var host_ribs: Node3D = board.grounds.bone_bridge() if board.grounds != null else null
		var client_ribs: Node3D = mirror.board.grounds.bone_bridge() \
			if mirror.board.grounds != null else null
		var ribs_same: bool = host_ribs != null and client_ribs != null \
			and host_ribs.global_position.is_equal_approx(client_ribs.global_position) \
			and host_ribs.scale.is_equal_approx(client_ribs.scale)
		settle_ok = settle_ok and ribs_same
		print("PROCESSION_NET_STIR_SETTLE bone_bridge same=%s y=%.2f scale=%s" % [
			str(ribs_same), client_ribs.global_position.y if client_ribs != null else INF,
			str(client_ribs.scale) if client_ribs != null else "missing"])
	if stirs.minor == "hearse_moves":
		var cart_same: bool = board.cart_prop != null and mirror.board.cart_prop != null \
			and board.cart_prop.global_position.is_equal_approx(
				mirror.board.cart_prop.global_position)
		settle_ok = settle_ok and cart_same
		print("PROCESSION_NET_STIR_SETTLE hearse_moves same=%s at=%s" % [
			str(cart_same), str(mirror.board.cart_prop.global_position) \
				if mirror.board.cart_prop != null else "missing"])

	# Temporary minors are current facts, not one-shot events. Prove their FX
	# survive an intermediate countdown snapshot and clear on the zero snapshot.
	var burn_ok := true
	if stirs.minor == "flood" or stirs.minor == "wake":
		var active_fx: int = mirror._flood_fx.size() if stirs.minor == "flood" \
			else mirror._wake_fx.size()
		_stir_tick()
		mirror._net_apply(_net_state())
		var mid_left: int = mirror.stirs.flood_left if stirs.minor == "flood" \
			else mirror.stirs.wake_left
		_stir_tick()
		mirror._net_apply(_net_state())
		var final_left: int = mirror.stirs.flood_left if stirs.minor == "flood" \
			else mirror.stirs.wake_left
		var final_fx: int = mirror._flood_fx.size() if stirs.minor == "flood" \
			else mirror._wake_fx.size()
		burn_ok = active_fx > 0 and mid_left == 1 and final_left == 0 and final_fx == 0
		print("PROCESSION_NET_STIR_BURNDOWN id=%s active_fx=%d mid_left=%d final_left=%d final_fx=%d clear=%s" % [
			stirs.minor, active_fx, mid_left, final_left, final_fx,
			str(burn_ok)])

	var ok: bool = same and idempotent and settle_ok and burn_ok
	print("PROCESSION_NET_STIR_%s" % ("OK" if ok else "FAIL"))
	mirror.queue_free()
	await get_tree().process_frame
	get_tree().quit()

## `adjacency_only` is the requested mutation checksum; the full shape hash
## additionally catches retypes and route-tag drift.
func _stir_graph_checksum(target: ProcessionBoardGraph,
		adjacency_only: bool) -> String:
	var sig := ""
	for n in target.nodes:
		if adjacency_only:
			sig += "%d:%s|" % [int(n.id), str(n.next)]
		else:
			sig += "%d:%s:%s:%s|" % [int(n.id), String(n.type),
				String(n.route), str(n.next)]
	return "%08x" % (sig.hash() & 0xFFFFFFFF)
