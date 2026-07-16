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
	"widowsgaze": {"name": "THE WIDOW'S GAZE", "scene": "res://minigames/widows_gaze/widows_gaze.tscn", "mode": "contract"},
	"seance": {"name": "THE SÉANCE", "scene": "res://minigames/seance/seance.tscn", "mode": "contract", "theater": true},
	"understudy": {"name": "THE UNDERSTUDY", "scene": "res://minigames/understudy/understudy.tscn", "mode": "contract", "theater": true},
	"maskedball": {"name": "MASKED BALL", "scene": "res://minigames/masked_ball/masked_ball.tscn", "mode": "contract", "theater": true},
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
# ----- ONLINE PHASE 2 (doc 10 §4.3): game mirrors. The shell owns the pump —
# a contract module exposing _net_state() gets it fanned to guests at 20 Hz;
# clients boot the SAME scene in mirror mode and feed _net_apply(). -----
var _net_mirror_id := ""          # module id while a mirrorable game runs
var _booted := false              # NIT 6: gate the scene-swap wipe off during _ready
var _net_module_accum := 0.0      # 20 Hz module-state pump
var _net_module_seq := 0
var _client_last_state := {}      # client: last mirrored lobby facts
var _client_panel_sig := ""       # client: rebuild panel only when facts change
var _client_walker_targets := {}  # client: p -> {pos, rot, moving} interp targets
# ----- ONLINE PHASE 3 (this lane): PODIUMS + NIGHT CEREMONIES mirror. The host
# narrates each ceremony stage as facts riding the 5 Hz lobby channel; clients
# restage the same podium/panel locally — render truth, never simulate it. -----
var _net_ceremony := {}           # host: current ceremony stage facts ({} = none)
var _net_ticker: Array = []       # host: reckoning ticker lines (facts while RECKONING)
var _net_auction_flavor := {}     # host: executor quip + vendetta notice this auction
var _net_chooser := -1            # host: who won the auction (CHOOSING phase fact)
var _client_podium: Podium = null # client: the restaged podium (host decides its end)
var _client_cer_stage := ""       # client: ceremony stage currently rendered
var _client_banner_sig := ""      # client: last mirrored banner (flash once per change)
var _client_trail := {}           # client: p -> stone rendered on the local trail
var _client_trail_tweens := {}    # client: p -> running advance tween (parade mirror)
var _client_hats_sig := ""        # client: last applied wardrobe facts
var _client_statues := {}         # client: statue idx already added to the gate

# ----- READY ROOM v2 (seat tri-state, join/ready, pre-game GET READY card) -----
var _lobby_ready := {}            # seat -> bool: lobby READY chip toggled on
var _lobby_ready_edge := {}       # seat -> physics frame of last READY toggle
var _kb_join_held := {}           # keyboard device (-1/-2) -> bool: A-key edge
var _join_ready_lock := {}        # seat -> bool: swallow the join press so it
                                  # does not also flip READY until A releases
var _start_button_held: bool = false
var _start_force_hold: HoldConfirm = null
var _ready_gate_active := false   # the pre-game GET READY card is up
var _ready_gate_id := ""
var _ready_gate_practice := false
var _ready_gate_countdown := 0.0
var _ready_gate_ready := {}       # seat -> bool: readied on the pre-game card
var _ready_gate_needed: Array = []  # human seats that must press A to launch

# ----- FIRST-NIGHT HOUSE RULES card (economy primer, once per fresh estate) --
var _house_rules_active := false   # the one-time HOUSE RULES card is up
var _house_rules_countdown := 0.0
var _house_rules_ready := {}       # seat -> bool: pressed A to continue
var _house_rules_needed: Array = []  # local human seats that must press A

@onready var cam: Camera3D = $Camera3D
@onready var top_bar: HBoxContainer = $UI/TopBar/Row
@onready var phase_panel: PanelContainer = $UI/PhasePanel
@onready var phase_box: VBoxContainer = $UI/PhasePanel/Box
@onready var banner: Label = $UI/Banner
@onready var plinths: Node3D = $Plinths
@onready var wall_text: Label3D = $GraffitiWall/Lines

func _ready() -> void:
	# Defense-in-depth vs zombie games (Andrew round 2): modules/podiums live at
	# the TREE ROOT during play; on ANY path that reboots the estate scene, a
	# survivor there is a stale game stacking under this boot. Sweep first.
	PartySetup.free_stray_root_nodes()
	Engine.time_scale = 1.0
	# Slot panel picks (PLAY THIS ESTATE / START FRESH) reload this scene; the
	# player expects to be IN the game, not back at the title (Andrew: "trying
	# to start a new estate game just brings me back to the main menu").
	if EstateState.pending_play:
		EstateState.pending_play = false
		call_deferred("_play_pressed")
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
		elif arg.begins_with("--quittest="):
			# Zombie-module receipt (Andrew round 2): forfeit the running game
			# after N seconds. Combined with --exhibtest, the reload re-arms and
			# relaunches, so each cycle proves quit -> sweep -> clean relaunch.
			var qt := float(arg.trim_prefix("--quittest="))
			get_tree().create_timer(qt).timeout.connect(func():
				var names: Array = []
				for c in get_tree().root.get_children():
					names.append(str(c.name))
				print("QUITTEST root before quit: ", ", ".join(names))
				PartySetup.quit_to_title())
		elif arg == "--lobbyshot":
			get_tree().create_timer(1.2).timeout.connect(func():
				_enter_lobby()
				get_tree().create_timer(0.4).timeout.connect(func():
					VerifyCapture.snap("lobbyrows")))
		elif arg == "--wipeshot":
			# NIT 6 proof: seat a human so the scene-swap iris is NOT skipped, then
			# fire a wrapped transition. _wipe_swap() snaps "estate_wipe" at mid-cover.
			get_tree().create_timer(1.2).timeout.connect(func():
				PlayerInput.assign(0, -1)
				PlayerInput.set_bot(0, false)
				_enter_grounds()
				get_tree().create_timer(TransitionWipe.COVER_TIME + 0.8).timeout.connect(
					func(): get_tree().quit()))
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
			HowtoCards.schedule_howto_test(self)
		elif arg == "--input2holdtest":
			get_tree().create_timer(1.2).timeout.connect(func():
				_build_slot_panel()
				var hold: Node = phase_box.find_child("SlotHold1", true, false)
				if hold != null and hold is HoldConfirm:
					var hold_ring: HoldConfirm = hold as HoldConfirm
					hold_ring.set_progress(0.48)
				VerifyCapture.snap("input2_hold_confirm"))
		elif arg == "--wardrobetest":
			WardrobePanel.schedule_wardrobe_test(self)
		elif arg == "--readytest":
			HowtoCards.schedule_ready_test(self)
		elif arg == "--houserulestest":
			HowtoCards.schedule_house_rules_test(self)
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
		elif arg == "--playmenutest":
			# Windowed proof: PLAY offers THE PROCESSION (featured) + the Deed-goal
			# dial + CLASSIC NIGHTS.
			get_tree().create_timer(1.2).timeout.connect(func():
				_build_play_panel()
				get_tree().create_timer(0.4).timeout.connect(func():
					VerifyCapture.snap("play_menu")))
		elif arg == "--proctest":
			# Windowed proof: launch THE PROCESSION from the menu path with an
			# all-bot table. Pair with --shots= to catch the board + a REVEAL.
			get_tree().create_timer(1.0).timeout.connect(func():
				for i in 4:
					PlayerInput.set_bot(i, true)
				_enter_procession())
		elif arg == "--albumtest":
			# Windowed proof: the FAMILY ALBUM gallery + its walk-up hotspot on the
			# grounds. Self-contained backup/restore of the seats.
			get_tree().create_timer(1.4).timeout.connect(func():
				var ps := ProjectSettings.globalize_path("user://party_setup.json")
				if FileAccess.file_exists(ps):
					DirAccess.copy_absolute(ps, ps + ".albak")
				_enter_lobby()
				_enter_stroll()
				if not walkers.is_empty():
					walkers[0].global_position = Vector3(-6.6, 0.1, 2.2)
				get_tree().create_timer(1.0).timeout.connect(func():
					VerifyCapture.snap("album_hotspot")
					get_tree().create_timer(0.6).timeout.connect(func():
						_exit_stroll("album")
						get_tree().create_timer(0.5).timeout.connect(func():
							VerifyCapture.snap("album_panel")
							if FileAccess.file_exists(ps + ".albak"):
								DirAccess.copy_absolute(ps + ".albak", ps)
								DirAccess.remove_absolute(ps + ".albak")
							print("ALBUMTEST saves restored")))))
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
	_ambient_life_setup()   # B3-HOOK: the troupe that makes the grounds breathe (core/ambient_life.gd)
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
	_booted = true   # NIT 6: from here on, scene swaps play the iris wipe

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

## PLAY: the estate offers THE PROCESSION as tonight's featured rite (with the
## Deed-goal dial), and the classic auctioned-minigame run as the alternative.
func _build_play_panel() -> void:
	phase = Phase.LOBBY
	_hide_title()
	Sfx.play("card")
	_clear_panel("PLAY — how does the estate settle its debts tonight?", Color(1, 0.9, 0.5))
	# --- THE PROCESSION: the featured night mode ---
	var proc_btn := Button.new()
	proc_btn.custom_minimum_size = Vector2(460, 78)
	proc_btn.text = "THE PROCESSION"
	proc_btn.add_theme_font_size_override("font_size", 30)
	proc_btn.pressed.connect(_enter_procession)
	var pc := CenterContainer.new()
	pc.add_child(proc_btn)
	phase_box.add_child(pc)
	var proc_desc := Label.new()
	proc_desc.text = "The funeral board: pawns putt the loop, the Codicil pays out Deeds, and the first to the goal inherits the manor."
	proc_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	proc_desc.custom_minimum_size = Vector2(660, 0)
	proc_desc.add_theme_font_size_override("font_size", 15)
	proc_desc.modulate.a = 0.8
	phase_box.add_child(proc_desc)
	# The Deed-goal dial (Short 4 / Full 6 / Vigil 9) — persisted like mg_rounds.
	var dial_row := HBoxContainer.new()
	dial_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dial_row.add_theme_constant_override("separation", 10)
	var dial_lbl := Label.new()
	dial_lbl.text = "NIGHT LENGTH:"
	dial_lbl.add_theme_font_size_override("font_size", 15)
	dial_lbl.modulate.a = 0.85
	dial_row.add_child(dial_lbl)
	var dial := Button.new()
	dial.custom_minimum_size = Vector2(220, 44)
	dial.text = _deed_goal_label()
	dial.pressed.connect(func():
		Sfx.play("card")
		_cycle_deed_goal()
		dial.text = _deed_goal_label())
	dial_row.add_child(dial)
	phase_box.add_child(dial_row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	phase_box.add_child(spacer)
	# --- CLASSIC NIGHTS: the auctioned-minigame run, still selectable ---
	var classic_btn := Button.new()
	classic_btn.custom_minimum_size = Vector2(360, 52)
	classic_btn.text = "CLASSIC NIGHTS"
	classic_btn.pressed.connect(_play_pressed)
	var cc := CenterContainer.new()
	cc.add_child(classic_btn)
	phase_box.add_child(cc)
	var classic_desc := Label.new()
	classic_desc.text = "Auctioned minigames, night after night, until someone climbs the trail and takes the manor."
	classic_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classic_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	classic_desc.custom_minimum_size = Vector2(660, 0)
	classic_desc.add_theme_font_size_override("font_size", 14)
	classic_desc.modulate.a = 0.65
	phase_box.add_child(classic_desc)
	var back := Button.new()
	back.text = "BACK TO TITLE"
	back.pressed.connect(_enter_title)
	phase_box.add_child(back)

## The Deed-goal dial: 4/6/9 = Short/Full/Vigil (doc 18/19), persisted in prefs.
const DEED_GOALS := [4, 6, 9]

func _deed_goal_label() -> String:
	var g := clampi(int(PartySetup.pref("deed_goal", 4)), 4, 9)
	var tier := "SHORT" if g <= 4 else ("FULL" if g <= 6 else "VIGIL")
	return "%s  ·  %d deeds" % [tier, g]

func _cycle_deed_goal() -> void:
	var g := clampi(int(PartySetup.pref("deed_goal", 4)), 4, 9)
	var idx: int = DEED_GOALS.find(g)
	if idx < 0:
		idx = 0
	PartySetup.set_pref("deed_goal", DEED_GOALS[(idx + 1) % DEED_GOALS.size()])

## Launch THE PROCESSION board mode (doc 19). The scene lives at the tree root
## like a gamestate module (zombie-swept); it supplies its own camera, HUD and
## environment, so the shell only hides its own overlays and folds home after.
func _enter_procession() -> void:
	phase = Phase.GAME
	_net_set_ceremony({})
	Music.stop()
	_hide_title()
	banner.visible = false
	phase_panel.visible = false
	$UI/TopBar.visible = false
	_fill_empty_seats_with_bots()
	PlayerInput.save_setup()
	var proc: Node = load("res://estate/procession/procession.tscn").instantiate()
	get_tree().root.add_child(proc)   # root, like a gamestate module (zombie-swept)
	# Track it as the live module so the estate's bot-wander stays parked and the
	# 20 Hz host mirror pump has a target (procession exposes _net_state()).
	_module = proc
	_net_game_name = "THE PROCESSION"
	var roster: Array = []
	for pl in EstateState.players:
		roster.append({"index": pl.index, "name": pl.name, "color": pl.color,
			"char_scene": CHAR_PATHS[pl.index], "device": PlayerInput.device_of(pl.index),
			"bot": _is_bot(pl.index)})
	proc.night_over.connect(func(_tally):
		_module = null
		_net_mirror_id = ""
		if is_instance_valid(proc):
			proc.queue_free()
		cam.current = true
		_enter_title(), CONNECT_ONE_SHOT)
	proc.begin({"roster": roster, "seed": EstateState.rng.randi(),
		"deed_goal": clampi(int(PartySetup.pref("deed_goal", 4)), 4, 9)})
	# ONLINE PHASE 2: fan the board to guests through the existing 20 Hz module
	# pump exactly as for a contract minigame (procession exposes _net_state).
	if NetSession.is_host() and proc.has_method("_net_state"):
		_net_mirror_id = "procession"
		_net_module_seq = 0
		_net_module_accum = 0.0

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
			EstateState.pending_play = true
			get_tree().reload_current_scene())
		row.add_child(load_btn)
		var wipe_btn := Button.new()
		wipe_btn.custom_minimum_size = Vector2(190, 46)
		wipe_btn.text = "HOLD: START FRESH" if summary == "" else "HOLD: WIPE FRESH"
		row.add_child(wipe_btn)
		var wipe_hold: HoldConfirm = HoldConfirm.new()
		wipe_hold.name = "SlotHold%d" % n
		wipe_hold.bind_button(wipe_btn, 5.0)
		wipe_hold.completed.connect(_start_fresh_slot.bind(n))
		row.add_child(wipe_hold)
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

func _start_fresh_slot(slot_idx: int) -> void:
	Sfx.play("grudge")
	EstateState.new_game(slot_idx)
	EstateState.pending_play = true
	get_tree().reload_current_scene()

func _enter_title() -> void:
	phase = Phase.TITLE
	_net_set_ceremony({})
	# NIT 6: return to the title behind the iris wipe (skipped at boot/soak/client)
	_wipe_swap(_enter_title_swap)

func _enter_title_swap() -> void:
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
	play.pressed.connect(_build_play_panel)
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
	hint.text = "PLAY = tonight's rite — THE PROCESSION board, or classic auctioned minigame nights"
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
	_net_set_ceremony({})
	_hide_title()
	Music.play_slot("lobby")
	$UI/TopBar.visible = false
	_lobby_ready.clear()
	_join_ready_lock.clear()
	# NIT 4: the persistent "ILL WILL" title banner collided with the lobby
	# panel's "who's on the couch?" header — the panel header is the title in
	# the lobby, so keep the banner hidden while the seat panel is open. (No
	# wipe here: several verify hooks call _enter_lobby() then build synchronously.)
	banner.visible = false
	_dedupe_human_devices()
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
		elif status == "BOT":
			# NIT 4: a BOT plays itself — showing its vestigial device ("KEYBOARD
			# (ARROWS)") read as a claimed seat. A dash makes clear no hand is here.
			dev_btn.text = "—"
			dev_btn.disabled = true
		elif status == "EMPTY":
			dev_btn.text = "UNASSIGNED"
			dev_btn.disabled = true
		else:
			dev_btn.text = PartySetup.DEVICE_NAMES.get(PlayerInput.device_of(i), "UNASSIGNED")
			# NIT 4: cycle only to devices no other HUMAN seat holds — two humans
			# can never resolve to (or display) the same device (doc 14 item 2).
			dev_btn.pressed.connect(func():
				PlayerInput.assign(i, _next_free_device(i))
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
	start_btn.pressed.connect(_try_start_night_from_lobby)
	start_btn.button_down.connect(func(): _start_button_held = true)
	start_btn.button_up.connect(func(): _start_button_held = false)
	btn_row.add_child(start_btn)
	_start_force_hold = HoldConfirm.new()
	_start_force_hold.name = "ForceStartHold"
	_start_force_hold.configure(1.5)
	_start_force_hold.visible = not _waiting_seats().is_empty()
	_start_force_hold.completed.connect(_force_start_night_from_lobby)
	btn_row.add_child(_start_force_hold)
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
	_start_button_held = false
	if _start_force_hold != null:
		_start_force_hold.cancel()
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

## Is `dev` held by any HUMAN seat other than `seat`? (Only real human hands
## collide — a BOT/EMPTY seat's leftover device number is not a claim.)
func _device_taken_by_other(seat: int, dev: int) -> bool:
	for j in 4:
		if j == seat:
			continue
		if _seat_status(j) == "HUMAN" and PlayerInput.device_of(j) == dev:
			return true
	return false

## NIT 4: the seat's next device in the cycle that no OTHER human seat holds, so
## a human cycling their input can never land on a device already in use.
func _next_free_device(seat: int) -> int:
	var cycle: Array = PartySetup.DEVICE_CYCLE
	var n := cycle.size()
	var cur := cycle.find(PlayerInput.device_of(seat))
	for step in range(1, n + 1):
		var cand: int = cycle[(cur + step) % n]
		if not _device_taken_by_other(seat, cand):
			return cand
	return PlayerInput.device_of(seat)   # couch full: keep the current device

## NIT 4: two HUMAN seats can never display the same device (doc 14 item 2). On
## lobby entry, reassign any later collider (e.g. from a restored setup) to a
## free device before the seat panel draws.
func _dedupe_human_devices() -> void:
	var seen: Array = []
	for i in 4:
		if _seat_status(i) != "HUMAN":
			continue
		var dev := PlayerInput.device_of(i)
		if seen.has(dev):
			var free := _first_free_device()
			PlayerInput.assign(i, free)
			seen.append(free)
		else:
			seen.append(dev)

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

func _try_start_night_from_lobby() -> void:
	if phase != Phase.LOBBY:
		return
	var waiting: Array = _waiting_seats()
	if waiting.is_empty():
		_start_night_from_lobby()
		return
	Sfx.play("invalid")
	_flash("WAITING ON %s - HOST MAY HOLD START" % ", ".join(_seat_names(waiting)), Color(1.0, 0.72, 0.35), 2.0)

func _force_start_night_from_lobby() -> void:
	if phase != Phase.LOBBY:
		return
	Sfx.play("confirm")
	_start_night_from_lobby()

func _seat_names(seats: Array) -> Array:
	var names: Array = []
	for seat in seats:
		names.append(GameState.PLAYER_NAMES[int(seat)])
	return names

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
			# NIT 4: the join flash fades on its own; do NOT restore the "ILL WILL"
			# title over the lobby panel (that was the header overlap).
			if phase == Phase.LOBBY:
				_build_lobby_panel()
				call_deferred("_flash_lobby_seat", i)
			return i
	return -1

func _flash_lobby_seat(seat: int) -> void:
	var row: Node = phase_box.get_node_or_null("SeatRow%d" % seat)
	if row == null or not row is Control:
		return
	var control: Control = row as Control
	control.modulate = Color(1.45, 1.35, 0.85, 1.0)
	control.scale = Vector2(1.04, 1.04)
	var tween: Tween = create_tween()
	tween.tween_property(control, "modulate", Color.WHITE, 0.22)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, 0.22)

func _poll_lobby_release() -> void:
	for i: int in range(4):
		if _seat_status(i) != "HUMAN":
			continue
		var device: int = PlayerInput.device_of(i)
		if device != -1 and device != -2 and device < 0:
			continue
		if PlayerInput.just_pressed(i, "b"):
			_release_lobby_seat(i)

func _release_lobby_seat(seat: int) -> void:
	PlayerInput.set_bot(seat, false)
	PlayerInput.assign(seat, -99)
	_lobby_ready.erase(seat)
	_join_ready_lock.erase(seat)
	PlayerInput.save_setup()
	Sfx.play("card")
	_flash("%s LEAVES THE COUCH" % GameState.PLAYER_NAMES[seat], GameState.PLAYER_COLORS[seat], 1.8)
	if phase == Phase.LOBBY:
		_build_lobby_panel()

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
	if _start_force_hold != null:
		_start_force_hold.visible = not _waiting_seats().is_empty()

func _poll_lobby_force_start(delta: float) -> void:
	if _start_force_hold == null:
		return
	if _waiting_seats().is_empty():
		_start_button_held = false
		_start_force_hold.cancel()
		return
	var held: bool = _start_button_held or _host_start_held()
	_start_force_hold.tick(held, delta)

func _host_start_held() -> bool:
	if PlayerInput.is_bot(0) or PlayerInput.is_remote(0) or NetSession.is_seat_remote(0):
		return false
	var device: int = PlayerInput.device_of(0)
	if device < 0:
		return false
	return Input.is_joy_button_pressed(device, JOY_BUTTON_START)

func _enter_selector() -> void:
	phase = Phase.SELECTOR
	HowtoCards.enter_selector(self, MODULES)

func _show_howto(id: String) -> void:
	HowtoCards.show_howto(self, MODULES, id)

func get_phase_name() -> String:
	return Phase.keys()[phase]

func _input2_gameplay_running() -> bool:
	return phase == Phase.GAME

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
	_refresh_album_wall()               # the family album gallery is part of the grounds
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

## THE ESTATE'S MEMORY: the walk-up family album gallery. Rebuilt each time the
## grounds are set up (and after each night's newsreel) so freshly-archived
## nights appear on the salon wall.
var _album_wall: FamilyAlbumWall = null

func _refresh_album_wall() -> void:
	if _album_wall != null and is_instance_valid(_album_wall):
		_album_wall.queue_free()
	_album_wall = FamilyAlbumWall.new()
	_album_wall.slot = EstateState.current_slot
	$Grounds.add_child(_album_wall)
	# A quiet corner of the grounds, angled toward the lawn.
	_album_wall.global_position = Vector3(-6.6, 1.7, 2.2)
	_album_wall.rotation.y = deg_to_rad(22)

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

var _wardrobe_player := 0

func _build_wardrobe_panel() -> void:
	WardrobePanel.build(self)

func _wardrobe_tap(id: String) -> void:
	WardrobePanel.tap(self, id)

func _refresh_walker_cosmetics(p: int) -> void:
	WardrobePanel.refresh_walker_cosmetics(walkers, p)

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
	if phase == Phase.GAME or _module != null or _ready_gate_active or _house_rules_active or NetSession.is_client():
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
	{"name": "THE FAMILY ALBUM", "pos": Vector3(-6.6, 0, 2.2), "r": 2.4, "act": "album"},
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
		"album":
			_build_album_panel()
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

## THE FAMILY ALBUM desk: the salon wall is the real exhibit; this panel is the
## Executor's caption for it.
func _build_album_panel() -> void:
	_clear_panel("THE FAMILY ALBUM", Color(0.9, 0.85, 0.7))
	var n := FamilyAlbumWall.entries(EstateState.current_slot).size()
	var l := Label.new()
	if n == 0:
		l.text = "The estate has taken no portraits yet. Give it a night; it is patient, and it is watching."
	else:
		l.text = "%s hang in the salon. The estate remembers every face it has framed, and forgives none of them." % _plural_nights(n)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	phase_box.add_child(l)
	var btn := Button.new()
	btn.text = "BACK TO THE GROUNDS"
	btn.pressed.connect(_build_freeroam_panel)
	phase_box.add_child(btn)

func _plural_nights(n: int) -> String:
	return "%d portrait%s" % [n, "" if n == 1 else "s"]

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
			# NIT 4: transient notice fades on its own; no "ILL WILL" title over the panel
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
				# NIT 4: transient notice fades on its own; no "ILL WILL" title over the panel
				_build_lobby_panel()

func _process(delta: float) -> void:
	if NetSession.is_client():
		_client_process(delta)
		return
	if NetSession.is_host():
		_net_host_broadcast(delta)
	if _ready_gate_active:
		_poll_ready_gate(delta)
	if _house_rules_active:
		_poll_house_rules(delta)
	# The HOUSE RULES card can be up while phase is still GROUNDS (the --estate
	# boot default) — suppress lobby join/ready polling so its A means "continue".
	if (phase == Phase.LOBBY or phase == Phase.GROUNDS) and not _house_rules_active:
		if _strolling:
			_poll_stroll()
		else:
			_poll_pad_join()
			_poll_kb_join()
			_poll_lobby_release()
			_poll_lobby_ready()
			_update_lobby_start_btn()
			_poll_lobby_force_start(delta)
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
	_net_set_ceremony({})   # boundary handoff: guests return to grounds + panel
	_grounds_timer = GROUNDS_TIME
	_tile_buyers.clear()
	_rebuild_top_bar()
	# NIT 6: the swap into free roam rides the iris wipe (skipped for soaks/clients)
	_wipe_swap(func() -> void:
		Music.play_slot("grounds")
		if _all_bots():
			_build_freeroam_panel()
		else:
			_enter_stroll())

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

func _should_show_house_rules() -> bool:
	return HowtoCards.should_show_house_rules(self)

func _maybe_show_house_rules() -> bool:
	return HowtoCards.maybe_show_house_rules(self)

func _show_house_rules() -> void:
	HowtoCards.show_house_rules(self)

func _all_house_rules_ready() -> bool:
	return HowtoCards.all_house_rules_ready(self)

func _refresh_house_rules_countdown() -> void:
	HowtoCards.refresh_house_rules_countdown(self)

func _poll_house_rules(delta: float) -> void:
	HowtoCards.poll_house_rules(self, delta)

func _enter_auction() -> void:
	if phase == Phase.AUCTION:
		return
	# A brand-new estate meets THE HOUSE RULES before its first auction. The card
	# marks itself shown and re-enters here when dismissed (flag now blocks it).
	if _maybe_show_house_rules():
		return
	phase = Phase.AUCTION
	_net_set_ceremony({})
	_net_auction_flavor = {}
	_net_chooser = -1
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
		_net_auction_flavor["vendetta"] = vl.text
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
	_net_auction_flavor["quip"] = eq.text
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
	_net_chooser = chooser
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

func _show_get_ready(id: String, practice := false) -> void:
	HowtoCards.show_get_ready(self, MODULES, READY_GATE_TIME, id, practice)

func _all_ready_gate() -> bool:
	return HowtoCards.all_ready_gate(self)

func _refresh_ready_gate_countdown() -> void:
	HowtoCards.refresh_ready_gate_countdown(self)

func _poll_ready_gate(delta: float) -> void:
	HowtoCards.poll_ready_gate(self, delta)

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

## NIT 6: route an estate scene swap through the ui_kit iris/curtain wipe (doc
## 14 §5 — fully obscure the swap for its ~340ms). phase is set by the caller
## BEFORE this so state stays correct while the visual swap runs hidden. Skipped
## for an all-bot soak and for net clients (they mirror the host), so headless
## verify flows never stall or shift their frame-indexed receipts.
func _wipe_swap(swap: Callable, style := TransitionWipe.IRIS) -> void:
	if not _booted or _all_bots() or NetSession.is_client():
		swap.call()
		return
	TransitionWipe.play(self, swap, style)
	var vc := get_node_or_null("/root/VerifyCapture")
	if vc != null and vc.active:
		get_tree().create_timer(TransitionWipe.COVER_TIME * 0.5, true, false, true) \
			.timeout.connect(func() -> void: vc.snap("estate_wipe"))

func _do_launch_game(id: String, practice := false) -> void:
	if phase == Phase.GAME:
		return
	phase = Phase.GAME   # re-entry guard set before the wipe covers the swap
	_wipe_swap(_launch_game_swap.bind(id, practice))

func _launch_game_swap(id: String, practice := false) -> void:
	_net_set_ceremony({})
	Music.stop()
	_hide_title()
	banner.visible = false
	_practice = practice
	phase_panel.visible = false
	Sfx.play("confirm")
	var info: Dictionary = MODULES[id]
	_net_game_name = String(info.name)
	MomentScribe.note_game(id)          # label captures with the game id
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
		# PAR ONLINE (doc 22 §7a): gamestate modules with _net_state ride the
		# same 20 Hz pump as minigames; par self-detects host role in _ready.
		if NetSession.is_host() and _module.has_method("_net_state"):
			_net_mirror_id = id
			_net_module_seq = 0
			_net_module_accum = 0.0
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
		# ONLINE PHASE 2 seam: a module exposing _net_state() gets mirrored to
		# guests; the fact rides the 5 Hz lobby state and boots their mirror.
		if NetSession.is_host() and _module.has_method("_net_state"):
			_net_mirror_id = id
			_net_module_seq = 0
			_net_module_accum = 0.0
	cam.current = false

func _on_module_finished(results: Dictionary) -> void:
	_net_mirror_id = ""   # ONLINE PHASE 2: guests' mirrors fold when this fact drops
	MomentScribe.clear_game()           # back on the grounds
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
	# Guests get the same ceremony: set the stage facts in the SAME frame that
	# dropped the mirror fact, so one client rebuild folds the game and raises
	# the podium (no spectate-card flicker between them).
	_net_set_ceremony({"stage": "match_podium", "game": _net_game_name,
		"placements": placements})
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
	_net_ticker = ticker.duplicate()
	_net_set_ceremony({})   # podium folds on every guest; the ticker takes over
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
		_net_push_facts()   # guests' pawns chase the trail fact per advance
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
	_net_set_ceremony({"stage": "night_podium", "placements": order,
		"champ": champ.index, "statue": EstateState.gate_statues.back(),
		"statue_idx": EstateState.gate_statues.size() - 1})
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
	# THE ESTATE'S MEMORY: the night's newsreel plays before the will is read,
	# then its stills are archived into the family album and the reel is reset.
	var reel_moments := MomentScribe.night_moments()
	if not reel_moments.is_empty():
		await _play_newsreel(reel_moments)
	FamilyAlbumWall.archive(reel_moments, EstateState.current_slot)
	MomentScribe.clear_night()
	_refresh_album_wall()               # rebuild the grounds gallery with tonight's frames
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
	var aw_facts: Array = []
	for aw in awards:
		var pl = EstateState.players[aw.player]
		var l := Label.new()
		l.text = "%s, %s — %s" % [pl.name, aw.title, aw.line]
		aw_facts.append([int(aw.player), l.text])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", pl.color)
		l.modulate.a = 0.0
		phase_box.add_child(l)
	var vend_text := ""
	if not EstateState.vendetta.is_empty() and EstateState.vendetta_settled_by < 0:
		var v: Dictionary = EstateState.vendetta
		var open_l := Label.new()
		open_l.text = "The matter of %s and %s remains open. The estate is patient." % [
			EstateState.players[int(v.hunter)].name, EstateState.players[int(v.prey)].name]
		vend_text = open_l.text
		open_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		open_l.add_theme_font_size_override("font_size", 15)
		open_l.modulate.a = 0.0
		open_l.self_modulate.a = 0.7
		phase_box.add_child(open_l)
	# THE GRUDGE LEDGER: the estate recalls a pattern or two from across the
	# nights, in the same dry register as the will. These fade in with the
	# award stagger below (they start at modulate.a == 0, like the award rows).
	for cl in EstateState.chronicle_lines(2):
		var chl := Label.new()
		chl.text = String(cl)
		chl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chl.custom_minimum_size = Vector2(680, 0)
		chl.add_theme_font_size_override("font_size", 15)
		chl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
		chl.modulate.a = 0.0
		phase_box.add_child(chl)
	# The superlative cards travel as composed lines — the guest's reading is
	# word-for-word the couch's, sequenced by the same stagger.
	_net_set_ceremony({"stage": "will", "champ": champ.index, "head": head.text,
		"awards": aw_facts, "vendetta": vend_text})
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

## Host-side silent-film ceremony (net mirrors stay on the night_podium facts
## until the will facts arrive — the newsreel is host-screen only this phase,
## exactly like the minigames). Blocks until the reel finishes or is skipped.
func _play_newsreel(moments: Array) -> void:
	var done := [false]
	Newsreel.play(moments, func(): done[0] = true)
	while not done[0]:
		await get_tree().process_frame

var _parade_running := false

func _night_parade() -> void:
	if phase != Phase.NIGHT_END or _parade_running:
		return
	_parade_running = true
	phase_panel.visible = false
	Music.play_slot("grounds")
	_net_set_ceremony({"stage": "parade"})
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
	_net_set_ceremony({"stage": "run_podium", "placements": order, "heir": p})
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
	_net_set_ceremony({"stage": "heir", "heir": p, "text": l.text})
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
	# Mid-ceremony banners (WINS THE NIGHT, tollgate claims, REACHES THE MANOR)
	# ride the stage facts so guests see the same words at the same beat.
	if not _net_ceremony.is_empty():
		_net_ceremony["banner"] = [text, color.to_html(), dur]
		_net_push_facts()
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
	MonumentsView.redraw_monuments(plinths)

func _redraw_graffiti() -> void:
	MonumentsView.redraw_graffiti(wall_text)

func _net_wire_signals() -> void:
	NetLobby.wire_signals(self)

func _host_night_pressed() -> void:
	NetLobby.host_night_pressed(self)

func _on_net_seat_requested(peer_id: int) -> void:
	NetLobby.on_seat_requested(self, peer_id)

func _on_net_peer_left_seat(seat: int, _peer_id: int) -> void:
	NetLobby.on_peer_left_seat(self, seat, _peer_id)

func _on_net_panel_intent(seat: int, intent: Dictionary) -> void:
	NetLobby.on_panel_intent(self, seat, intent)

func _net_host_broadcast(delta: float) -> void:
	NetLobby.host_broadcast(self, delta)

func _net_build_lobby_state() -> Dictionary:
	return NetLobby.build_lobby_state(self, MODULES)

func _net_hats() -> Dictionary:
	return NetLobby.hats()

func _net_set_ceremony(cer: Dictionary) -> void:
	NetLobby.set_ceremony(self, cer)

func _net_push_facts() -> void:
	NetLobby.push_facts(self)

func _net_build_walker_state(seq: int) -> Dictionary:
	return NetLobby.build_walker_state(self, seq)

## ----- client side (the estate-only mirror) -----

func _build_join_panel() -> void:
	NetLobby.build_join_panel(self, Phase.LOBBY)

func _on_net_seat_granted(seat: int, reason: String) -> void:
	NetLobby.on_seat_granted(self, seat, reason)

func _enter_client_lobby() -> void:
	NetLobby.enter_client_lobby(self, Phase.LOBBY)

func _on_net_lobby_state(state: Dictionary) -> void:
	NetLobby.on_lobby_state(self, state)

func _on_net_walker_state(state: Dictionary) -> void:
	NetLobby.on_walker_state(self, state)

func _client_process(delta: float) -> void:
	NetLobby.client_process(self, delta)

## ----- PHASE 2: the game mirror (client side of the handoff seam) -----

## Snapshots for the running game -> straight into the mirror's _net_apply.
func _on_net_module_state(state: Dictionary) -> void:
	NetLobby.on_module_state(self, state)

## Hidden info for MY seat (rpc_id said so) -> the mirror's private handler.
func _on_net_module_private(data: Dictionary) -> void:
	NetLobby.on_module_private(self, data)

## Boot the same module scene in mirror mode: same roster shape the host
## builds, no seed, no sim — _net_apply drives everything.
var _client_mirror_up := false   # guards teardown: never touch a HOST module

func _client_ensure_mirror(id: String) -> void:
	if _module != null:
		return
	if not MODULES.has(id):
		return
	_client_mirror_up = true
	print("NET mirror boot: %s" % id)
	var info: Dictionary = MODULES[id]
	phase_panel.visible = false
	banner.visible = false
	Music.stop()
	$Grounds.visible = false
	$Grounds.process_mode = Node.PROCESS_MODE_DISABLED
	plinths.visible = false
	$GraffitiWall.visible = false
	$Trail.visible = false
	$Trail.process_mode = Node.PROCESS_MODE_DISABLED
	$Sun.visible = false
	$WorldEnvironment.environment = null
	$UI/TopBar.visible = false
	var scene: PackedScene = load(info.scene)
	_module = scene.instantiate()
	# PAR ONLINE (doc 22 §7b): gamestate modules mirror themselves — par
	# self-detects the client role in _ready; no begin() contract to call.
	if String(info.get("mode", "")) == "gamestate":
		get_tree().root.add_child(_module)
		cam.current = false
		return
	add_child(_module)
	var roster: Array = []
	for pl in EstateState.players:
		roster.append({
			"index": pl.index, "name": pl.name, "color": pl.color,
			"char_scene": CHAR_PATHS[pl.index], "device": -99, "bot": false,
		})
	_module.begin({"roster": roster, "rounds": 2, "rng_seed": 0,
		"practice": false, "net_mirror": true})
	cam.current = false

## The host's module finished (or the night moved on): fold the mirror and
## give the estate back. Client-only by construction (_client_build_panel).
func _client_teardown_mirror() -> void:
	if _module == null or not _client_mirror_up:
		return
	_client_mirror_up = false
	print("NET mirror fold")
	_module.queue_free()
	_module = null
	$Grounds.visible = true
	$Grounds.process_mode = Node.PROCESS_MODE_INHERIT
	plinths.visible = true
	$Trail.visible = true
	$Trail.process_mode = Node.PROCESS_MODE_INHERIT
	$Sun.visible = true
	$GraffitiWall.visible = true
	$WorldEnvironment.environment = _saved_env
	cam.current = true

## The client lobby: rebuilt from mirrored facts, never from local state.
func _client_build_panel() -> void:
	NetLobby.client_build_panel(self, _client_last_state)

## Phase-1 posture (spec §8): games not yet mirrored render host-side only;
## the client keeps its seat, its input still relays, and this card says so.
func _client_build_spectate_panel(state: Dictionary) -> void:
	NetLobby.client_build_spectate_panel(self, state)

## ----- PHASE 3 (this lane): podiums + night ceremonies on the guest screen --
## The host narrates stages as facts; the guest RESTAGES them — same Podium
## scene, same composed lines, same banners — and never simulates an outcome.

## Auction visibility (spec item 3): bids, pot, the vendetta book and the
## Executor's quip as read-only rows. Bidding stays couch-side (no new inputs).
func _client_build_auction_rows(auc: Dictionary) -> void:
	NetLobby.client_build_auction_rows(self, auc)

func _client_render_ceremony(cer: Dictionary) -> void:
	# Banners ride the stage; flash each distinct one exactly once.
	var b: Array = cer.get("banner", [])
	var bsig := JSON.stringify(b)
	if bsig != _client_banner_sig:
		_client_banner_sig = bsig
		if b.size() >= 3:
			_flash(String(b[0]), Color.from_string(String(b[1]), Color.WHITE), float(b[2]))
	var stg := String(cer.get("stage", ""))
	if stg == _client_cer_stage:
		return  # already staged; only incremental facts (banner/trail) changed
	_client_cer_stage = stg
	# A fresh stage without a banner fact means the host cleared its banner
	# (podium flash -> will reading, will -> parade). Match it.
	if not cer.has("banner"):
		banner.visible = false
		_client_banner_sig = ""
	print("NET ceremony stage: %s" % stg)
	match stg:
		"match_podium", "night_podium", "run_podium":
			_client_show_podium(cer)
		"will":
			_client_show_will(cer)
		"parade":
			_client_clear_podium()
			phase_panel.visible = false
			Music.play_slot("grounds")
		"heir":
			_client_show_heir(cer)

func _client_end_ceremony() -> void:
	if _client_cer_stage == "":
		return
	_client_cer_stage = ""
	_client_banner_sig = ""
	_client_clear_podium()
	banner.visible = false

func _client_clear_podium() -> void:
	if _client_podium != null:
		if is_instance_valid(_client_podium):
			_client_podium.queue_free()
		_client_podium = null
		cam.current = true

## The same Podium scene the couch watches, restaged from placement facts.
## Hats ride the wardrobe facts — the host's closet, not this machine's.
func _client_show_podium(cer: Dictionary) -> void:
	_client_teardown_mirror()
	_client_clear_podium()
	phase_panel.visible = false
	var stg := String(cer.get("stage", ""))
	if stg == "night_podium" and cer.has("statue"):
		var sidx := int(cer.get("statue_idx", 0))
		if not _client_statues.has(sidx):
			_client_statues[sidx] = true
			$Trail.add_statue(cer["statue"], sidx)
	if stg == "run_podium":
		Music.play_slot("ceremony")
	var hats: Dictionary = _client_last_state.get("hats", {})
	var podium := Podium.new()
	_client_podium = podium
	add_child(podium)
	var entries: Array = []
	var placements: Array = cer.get("placements", [])
	for rank in placements.size():
		var p := int(placements[rank])
		entries.append({
			"name": GameState.PLAYER_NAMES[p], "color": GameState.PLAYER_COLORS[p],
			"rank": rank, "char_scene": CHAR_SCENES[p],
			"cosmetics": _hats_of(hats, p),
		})
	podium.stage_entries(entries)

## THE READING OF THE WILL, word for word, with the couch's 0.45 s stagger.
func _client_show_will(cer: Dictionary) -> void:
	_client_clear_podium()
	Music.play_slot("ceremony")
	var champ := int(cer.get("champ", 0))
	_clear_panel("THE READING OF THE WILL", Color(0.85, 0.75, 1.0))
	var head := Label.new()
	head.text = String(cer.get("head", ""))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", GameState.PLAYER_COLORS[champ])
	phase_box.add_child(head)
	var awards: Array = cer.get("awards", [])
	for aw in awards:
		if not (aw is Array) or aw.size() < 2:
			continue
		var l := Label.new()
		l.text = String(aw[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[clampi(int(aw[0]), 0, 3)])
		l.modulate.a = 0.0
		phase_box.add_child(l)
	if String(cer.get("vendetta", "")) != "":
		var open_l := Label.new()
		open_l.text = String(cer["vendetta"])
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
	var foot := Label.new()
	foot.text = "the host turns the page — the parade follows"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 13)
	foot.modulate.a = 0.55
	phase_box.add_child(foot)
	print("WILL_READ_MIRROR awards=%d vendetta=%s" % [awards.size(), str(String(cer.get("vendetta", "")) != "")])
	await get_tree().create_timer(0.45 * i + 0.6).timeout
	if _client_cer_stage == "will":
		VerifyCapture.snap("will_reading_mirror")

func _client_show_heir(cer: Dictionary) -> void:
	_client_clear_podium()
	var heir := clampi(int(cer.get("heir", 0)), 0, 3)
	_clear_panel("THE ESTATE HAS AN HEIR", Color(1, 0.85, 0.2))
	var l := Label.new()
	l.text = String(cer.get("text", ""))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	l.add_theme_color_override("font_color", GameState.PLAYER_COLORS[heir])
	phase_box.add_child(l)
	var foot := Label.new()
	foot.text = "the run is over — the host decides what the estate does with the rest of the evening"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 13)
	foot.modulate.a = 0.55
	phase_box.add_child(foot)
	print("HEIR_MIRROR heir=%d" % heir)
	VerifyCapture.snap("heir_mirror")

## Seat the local trail pawns at the HOST's stones; during the parade stage,
## advances animate stone-by-stone exactly like the couch (host paces them —
## each advance lands as its own fact push).
func _client_apply_trail(trail: Dictionary, animate: bool) -> void:
	var reseat := false
	for k in trail:
		var p := int(str(k))
		var to := int(trail[k])
		var cur := int(_client_trail.get(p, -1))
		if to == cur:
			continue
		var old: Tween = _client_trail_tweens.get(p, null)
		if old != null and old.is_valid():
			old.kill()
		if animate and cur >= 0 and to > cur and $Trail.pawns.has(p):
			_client_trail_tweens[p] = $Trail.advance_pawn(p, cur, to)
		else:
			reseat = true
		_client_trail[p] = to
	if reseat:
		$Trail.seat_all(_client_trail)

## Wear the host estate's wardrobe truth on the mirrored walkers.
func _client_apply_hats(hats: Dictionary) -> void:
	var sig := JSON.stringify(hats)
	if sig == _client_hats_sig:
		return
	_client_hats_sig = sig
	for i in walkers.size():
		if not is_instance_valid(walkers[i]):
			continue
		for slot in ["head", "hand_l", "hand_r", "chest"]:
			Cosmetics.unequip(walkers[i], slot)
		for cid in _hats_of(hats, i):
			Cosmetics.equip(walkers[i], String(cid))

## RPC dictionaries keep int keys, JSON round-trips make them strings — take both.
func _hats_of(hats: Dictionary, p: int) -> Array:
	if hats.has(p):
		return hats[p]
	return hats.get(str(p), [])

func _on_net_session_closed(reason: String) -> void:
	_client_teardown_mirror()   # no-op unless a mirror is actually up
	_client_end_ceremony()
	_client_trail.clear()
	_client_trail_tweens.clear()
	_client_hats_sig = ""
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
	# Phase-2 séance probe rides the REAL selector: --pool=seance keeps the
	# auction honest and the mock game out. Without a pool, phase-1 mock night.
	mockonly = pool_override.is_empty()
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
	var auction_up := func() -> bool: return phase == Phase.AUCTION
	if await _np_wait(auction_up, 20.0):
		await get_tree().create_timer(1.0).timeout
		await _np_snap("online_host_auction")
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
	var podium_up := func() -> bool: return String(_net_ceremony.get("stage", "")) == "match_podium"
	if await _np_wait(podium_up, 40.0 if mockonly else 420.0):
		await get_tree().create_timer(1.5).timeout
		await _np_snap("online_host_matchpodium")
	var reckoned := func() -> bool: return phase == Phase.RECKONING
	# a real séance night runs ~4 min; the mock night is done inside 40 s
	if await _np_wait(reckoned, 40.0 if mockonly else 420.0):
		await get_tree().create_timer(1.2).timeout
		await _np_snap("online_host_reckoning")
	var parts := "NETPROBE_RESULTS"
	for pl in EstateState.players:
		parts += " %s:pts=%d,grudge=%d" % [pl.name, pl.points, pl.grudge]
	print(parts)
	# NIGHT CEREMONIES leg (--night=1 probes): the reckoning settles the night —
	# press the host's own CONTINUE, then walk night podium -> will reading ->
	# parade -> boundary, pausing at each stage so both sides' snaps land.
	if phase == Phase.RECKONING and EstateState.games_played >= EstateState.night_length:
		_after_reckoning()
		var npod_up := func() -> bool: return String(_net_ceremony.get("stage", "")) == "night_podium"
		if await _np_wait(npod_up, 20.0):
			await get_tree().create_timer(2.0).timeout
			await _np_snap("online_host_nightpodium")
		var will_up := func() -> bool: return String(_net_ceremony.get("stage", "")) == "will"
		if await _np_wait(will_up, 30.0):
			await get_tree().create_timer(4.0).timeout
			await _np_snap("online_host_will")
		_night_parade()
		var parade_up := func() -> bool: return String(_net_ceremony.get("stage", "")) == "parade"
		if await _np_wait(parade_up, 15.0):
			await get_tree().create_timer(1.0).timeout
			await _np_snap("online_host_parade")
		var at_boundary := func() -> bool: return phase == Phase.GROUNDS
		if await _np_wait(at_boundary, 60.0):
			await get_tree().create_timer(1.5).timeout
			await _np_snap("online_host_boundary")
		print("NETPROBE ceremonies leg done (boundary=%s)" % str(phase == Phase.GROUNDS))
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
	var auction_seen := func() -> bool: return not (_client_last_state.get("auction", {}) as Dictionary).is_empty()
	if await _np_wait(auction_seen, 40.0):
		await get_tree().create_timer(1.0).timeout
		await _np_snap("online_client_auction")
	var gate_seen := func() -> bool: return _client_last_state.has("gate")
	if await _np_wait(gate_seen, 40.0):
		await get_tree().create_timer(0.6).timeout
		await _np_snap("online_client_gate")
	var game_seen := func() -> bool: return String(_client_last_state.get("phase", "")) == "GAME"
	if await _np_wait(game_seen, 40.0):
		await get_tree().create_timer(1.2).timeout
		# phase 1 this was the spectate card; with a mirrorable game it is the
		# booted mirror itself (the séance stage, INTRO/CAST)
		await _np_snap("online_client_game")
	var pod_seen := func() -> bool: return _client_cer_fact() == "match_podium"
	if await _np_wait(pod_seen, 420.0):
		await get_tree().create_timer(1.5).timeout
		await _np_snap("online_client_matchpodium")
	var reck_seen := func() -> bool: return String(_client_last_state.get("phase", "")) == "RECKONING"
	if await _np_wait(reck_seen, 60.0):
		await get_tree().create_timer(1.0).timeout
		await _np_snap("online_client_reckoning")
	# NIGHT CEREMONIES leg — only when the host's night actually settles
	# (--night=1 probes). A phase-1/2 probe host quits at the reckoning instead;
	# the session drop skips this whole block.
	var night_end_seen := func() -> bool: return String(_client_last_state.get("phase", "")) == "NIGHT_END" or not NetSession.is_online()
	if await _np_wait(night_end_seen, 30.0) and NetSession.is_online():
		var npod_seen := func() -> bool: return _client_cer_fact() == "night_podium"
		if await _np_wait(npod_seen, 20.0):
			await get_tree().create_timer(2.0).timeout
			await _np_snap("online_client_nightpodium")
		var will_seen := func() -> bool: return _client_cer_fact() == "will"
		if await _np_wait(will_seen, 30.0):
			await get_tree().create_timer(3.6).timeout
			await _np_snap("online_client_will")
		var parade_seen := func() -> bool: return _client_cer_fact() == "parade"
		if await _np_wait(parade_seen, 30.0):
			await get_tree().create_timer(1.2).timeout
			await _np_snap("online_client_parade")
		var grounds_seen := func() -> bool: return String(_client_last_state.get("phase", "")) == "GROUNDS" and _client_cer_fact() == ""
		if await _np_wait(grounds_seen, 60.0):
			await get_tree().create_timer(1.5).timeout
			await _np_snap("online_client_boundary")
	print("NETPROBE_CLIENT_DONE")
	# outlive the host by a breath so its quit lands first, then leave
	await get_tree().create_timer(6.0).timeout
	get_tree().quit()

## The ceremony stage as the CLIENT knows it — from facts, never local state.
func _client_cer_fact() -> String:
	return String((_client_last_state.get("ceremony", {}) as Dictionary).get("stage", ""))

# ============================================================ AMBIENT LIFE (B3)
## The estate grounds, made to breathe. This is the ONE setup region the ambient
## lane owns in estate.gd (see the B3-HOOK call in _ready). Everything else lives
## in core/ambient_life.gd. Purely presentational: it only READS the chronicle
## and standings, owns its own RNG, and never writes an estate save.
func _ambient_life_setup() -> void:
	var al := AmbientLife.new()
	al.name = "AmbientLife"
	al.setup($Grounds, $Grounds/Walkers, cam)
	if "--ambienttest" in OS.get_cmdline_user_args():
		_ambient_test_run.call_deferred()

## Windowed proof for the troupe: seat a human, seed a few nights of memory (in
## RAM only — never saved), stroll the grounds, and photograph each member in
## place. Self-contained; quits when done. Dev-only (guarded on --ambienttest).
func _ambient_test_run() -> void:
	await get_tree().create_timer(1.2).timeout
	_ambient_seed_chronicle()
	_enter_lobby()
	_enter_stroll()
	var al: Node = get_tree().get_first_node_in_group("ambient_life")
	# let the grounds settle and the troupe take a few scans
	await get_tree().create_timer(2.4).timeout
	# THE GALLERY — crows gossiping, a bubble up, no one leaning in. Park the
	# (wandering bot) walkers south so the flock reads clear of the graveyard.
	for w in walkers:
		if is_instance_valid(w):
			w.global_position = Vector3(-1.5 + w.player_idx * 1.0, 0.1, 1.4)
	if al != null and al.has_method("debug_show_gossip"):
		al.debug_show_gossip()
	await get_tree().create_timer(0.4).timeout
	await _ambient_snap("gallery")
	# THE GALLERY (silenced) — a walker leans into the flock; heads snap forward
	if not walkers.is_empty():
		walkers[0].global_position = Vector3(-7.2, 0.1, -4.6)
	await get_tree().create_timer(0.9).timeout
	await _ambient_snap("gallery_silent")
	print("AMBIENTTEST done")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

## A few nights of synthetic conduct so the crows have something to gossip. Shape
## matches end_night()'s ledger/monuments; rebuilds the chronicle in place. RAM
## ONLY — no save() is ever called, so the owner's slots are untouched.
func _ambient_seed_chronicle() -> void:
	EstateState.ledger = [
		{"night": 0, "winner": "GOLD", "awards": [
			{"who": "BLUE", "title": "THE SNAKE", "line": ""},
			{"who": "MINT", "title": "THE DOORMAT", "line": ""},
			{"who": "RED", "title": "NEMESIS OF BLUE", "line": ""}]},
		{"night": 1, "winner": "GOLD", "awards": [
			{"who": "MINT", "title": "THE DOORMAT", "line": ""},
			{"who": "RED", "title": "NEMESIS OF BLUE", "line": ""},
			{"who": "GOLD", "title": "THE HOARDER", "line": ""}]},
		{"night": 2, "winner": "MINT", "awards": [
			{"who": "MINT", "title": "THE ARCHITECT", "line": ""},
			{"who": "RED", "title": "THE RECKONER", "line": ""}]},
	]
	EstateState.monuments = [
		{"owner": "GOLD", "label": "GOLD — Champion of Night 1", "night": 0},
		{"owner": "GOLD", "label": "GOLD — Champion of Night 2", "night": 1},
		{"owner": "MINT", "label": "MINT — Champion of Night 3", "night": 2},
		{"owner": "MINT", "label": "the spite obelisk", "night": 2},
	]
	EstateState.chronicle = {"by_name": {"BLUE": {"events": {"quiet_betrayal": 1}}}}
	EstateState._rebuild_chronicle()

## Grab the current frame to verify_out/ (own capture — does not depend on the
## VerifyCapture harness being armed).
func _ambient_snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var out := "verify_out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out))
	var path := "res://%s/ambient_%s.png" % [out, tag]
	img.save_png(path)
	print("AMBIENT_SNAP ", ProjectSettings.globalize_path(path))
