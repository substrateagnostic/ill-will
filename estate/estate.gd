extends Node3D
## THE ESTATE — hub shell for THE PROCESSION and exhibition minigames.

enum Phase { LOBBY, SELECTOR, GROUNDS, GAME, TITLE }

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
	"pallbearers": {"name": "PALLBEARERS", "scene": "res://minigames/pallbearers/pallbearers.tscn", "mode": "contract"},  # B7-HOOK
}
const CHAR_PATHS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const GROUNDS_TIME := 20.0
var phase := Phase.GROUNDS
var bots := false
var _grounds_timer := GROUNDS_TIME
var _module: Node = null
var _monuments_drawn := 0
var walkers: Array = []
var _saved_env: Environment = null
var _selected_walker := -1
var _skip_panel_focus := false    # one-shot: _build_lobby_panel opts out of the L1 pad-focus grab
var _bot_wander_timer := 0.0
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
# Exhibition podiums mirror as host-authored facts.
var _net_ceremony := {}
var _client_podium: Podium = null # client: the restaged podium (host decides its end)
var _client_cer_stage := ""       # client: ceremony stage currently rendered
var _client_banner_sig := ""      # client: last mirrored banner (flash once per change)
var _client_hats_sig := ""        # client: last applied wardrobe facts

# ----- READY ROOM v2 (seat tri-state, join/ready) -----
var _lobby_ready := {}            # seat -> bool: lobby READY chip toggled on
var _lobby_ready_edge := {}       # seat -> physics frame of last READY toggle
var _kb_join_held := {}           # keyboard device (-1/-2) -> bool: A-key edge
var _join_ready_lock := {}        # seat -> bool: swallow the join press so it
                                  # does not also flip READY until A releases
var _start_button_held: bool = false
var _start_force_hold: HoldConfirm = null

@onready var cam: Camera3D = $Camera3D
@onready var phase_panel: PanelContainer = $UI/PhasePanel
@onready var phase_box: VBoxContainer = $UI/PhasePanel/Box
@onready var banner: Label = $UI/Banner
@onready var plinths: Node3D = $Plinths
@onready var wall_text: Label3D = $GraffitiWall/Lines

# ---- G3 (doc 33): THE HUB LIVES ON THE FORECOURT. One offset carries the
# whole hub cluster onto the procession grounds' forecourt table; the WORLD
# (terrain + the full board) mounts under $Grounds with the inverse offset so
# the module-launch hide/show law (the photobomb rule, ~line 1245) governs
# everything with zero new toggle sites. The estate.gd phase machine is
# untouched — only transforms moved.
var hub_off := Vector3.ZERO
var _world_board: ProcessionBoardGraph = null

## The module OWNS the screen (same law as procession._assert_module_camera):
## with several cameras alive in one tree, clear_current promotion is a
## lottery — assert the launched module's first camera explicitly. Modules
## that build a camera later in their own flow assert themselves past this.
func _assert_module_camera(module: Node) -> void:
	var cams := module.find_children("*", "Camera3D", true, false)
	if not cams.is_empty():
		(cams[0] as Camera3D).make_current()

## The forecourt anchor + the world under the lawn. Called FIRST in _ready —
## every later spawn is hub-relative.
func _mount_world() -> void:
	hub_off = Vector3(0.0, ProcessionGrounds.height(0.0, 51.0) + 0.03, 51.0)
	# retire the diorama backdrop — the REAL manor stands on its rise now
	for dead in ["Lawn", "Hill", "HillMound", "Castle", "ManorGate", "Path"]:
		if $Grounds.has_node(dead):
			$Grounds.get_node(dead).queue_free()
	$Grounds.position = hub_off
	$GraffitiWall.position += hub_off
	$Plinths.position += hub_off
	cam.position += hub_off
	# the diorama's dreamy DOF was tuned for a 12u lawn; the view is an
	# ESTATE now — push the far blur out so the manor reads through the haze
	if cam.attributes is CameraAttributesPractical:
		var at := cam.attributes as CameraAttributesPractical
		at.dof_blur_far_distance = 55.0
		at.dof_blur_far_transition = 40.0
	var world := Node3D.new()
	world.name = "EstateWorld"
	$Grounds.add_child(world)
	world.position = -hub_off   # cancels the hub offset: the world stays put
	var board := ProcessionBoardGraph.new()
	world.add_child(board)
	var ros: Array = []
	for i in EstateState.players.size():
		ros.append({"index": i, "name": String(EstateState.players[i].name),
			"color": EstateState.players[i].color,
			"char_scene": ["res://assets/models/kaykit/Barbarian.glb",
				"res://assets/models/kaykit/Knight.glb",
				"res://assets/models/kaykit/Mage.glb",
				"res://assets/models/kaykit/Rogue.glb"][i % 4],
			"device": -1, "bot": true})
	board.build(ros, EstateState.monuments)
	board.grounds.build_collision()
	_world_board = board

func _ready() -> void:
	# Defense-in-depth vs zombie games (Andrew round 2): modules/podiums live at
	# the TREE ROOT during play; on ANY path that reboots the estate scene, a
	# survivor there is a stale game stacking under this boot. Sweep first.
	PartySetup.free_stray_root_nodes()
	Engine.time_scale = 1.0
	_mount_world()   # G3: the forecourt anchor + the estate below the lawn
	# M2: dress the shared estate-desk panel in the house stationery (ink + gold
	# hairline) instead of the old grey theme panel, so every desk built into it
	# matches the title door.
	Stationery.panel(phase_panel)
	# Slot picks reload this scene and reopen the unified PLAY panel.
	if EstateState.pending_play:
		EstateState.pending_play = false
		call_deferred("_build_play_panel")
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var open_play_now := false
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--estatebots":
			bots = true
		elif arg == "--estate":
			open_play_now = true
		elif arg.begins_with("--netprobe="):
			_netprobe = arg.trim_prefix("--netprobe=")
		elif arg.begins_with("--exhibtest="):
			var gid := arg.trim_prefix("--exhibtest=")
			get_tree().create_timer(1.2).timeout.connect(func():
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
		elif arg.begins_with("--m2shots="):
			# M2 UI CONSISTENCY verification (windowed). Captures the restyled desks
			# and a device-aware minigame. `--m2shots=kbm` also grabs the menus (they
			# are device-independent); `--m2shots=pad` grabs only the game. Pair with
			# --shots=<big> to arm VerifyCapture. Self-contained; quits.
			var _m2dev := arg.trim_prefix("--m2shots=")
			get_tree().create_timer(1.0).timeout.connect(func(): _m2_capture(_m2dev))
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
					walkers[0].global_position = hub_off + Vector3(6.4, 0.1, -4.2)
				get_tree().create_timer(1.0).timeout.connect(func():
					VerifyCapture.snap("stroll_prompt")
					get_tree().create_timer(0.6).timeout.connect(func():
						_exit_stroll("selector")
						get_tree().create_timer(0.5).timeout.connect(func():
							VerifyCapture.snap("stroll_selector")))))
		elif arg == "--padreclaimtest":
			# GAMEPAD EVERYWHERE (L1) bug 2 proof: a pad seated on the grounds is
			# dropped then reconnected; the seat must come back HUMAN on its pad
			# (pre-fix it stayed bot/-99 and the walker froze). Headless; quits.
			get_tree().create_timer(1.0).timeout.connect(_pad_reclaim_test_run)
		elif arg == "--focussweep":
			# GAMEPAD EVERYWHERE (L1) verification: build every estate desk and log
			# which control the pad-focus cursor landed on. Proves each screen is
			# navigable by a controller alone. Headless; self-contained; quits.
			get_tree().create_timer(1.0).timeout.connect(_focus_sweep_run)
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
			# Windowed proof (P3): PLAY is THE PROCESSION only — the nights +
			# turn-cap dials and GO.
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
					walkers[0].global_position = hub_off + Vector3(-6.6, 0.1, 2.2)
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
	_redraw_monuments()
	_redraw_graffiti()
	banner.visible = false
	_apply_night_grounds()
	_saved_env = $WorldEnvironment.environment
	_net_wire_signals()
	if open_play_now:
		_build_play_panel()
	else:
		_enter_title()
	if _netprobe != "":
		_netprobe_run()
	elif NetSession.is_host():
		# --net=host CLI boot: straight to the open lobby with the invite code.
		_hide_title()
		_enter_lobby()
	_booted = true   # NIT 6: from here on, scene swaps play the iris wipe

## NIGHT GROUNDS (night 6, Alex's tonal call): the walkabout joins the night.
## The title hero shot (MOONLIT, darker) and the procession board (MOONLIT)
## were already night; the daylight hub between them was the one lights-up
## jolt in the flow. Swap the .tscn's FILMIC day env for the house MOONLIT
## look and turn the warm sun into the moon key BEFORE _saved_env is captured,
## so every existing swap-out/restore cycle round-trips the night untouched.
func _apply_night_grounds() -> void:
	$WorldEnvironment.environment = EnvKit.build_environment(EnvKit._merged(EnvKit.MOONLIT, {
		"bg_mode": "sky",         # open grounds: graded night sky, not flat void
		"ambient_energy": 0.32,   # playable hub — brighter than the title's 0.24 hero drop
		"exposure": 0.9,          # sink the lawn's day-green toward the board's night plum
		"fog_density": 0.008,     # a breath of ground haze; monuments stay readable
	}))
	var sun := $Sun as DirectionalLight3D
	sun.light_color = Color(0.62, 0.72, 1.0)
	sun.light_energy = 0.6
	# Warm counter-fill (MOONLIT's fill spec) so faces and stone don't go dead
	# blue. A child of $Sun: every existing `$Sun.visible` toggle carries it,
	# so it can never leak into a minigame's own rig.
	var fill := DirectionalLight3D.new()
	fill.name = "MoonFill"
	fill.light_color = Color(1.0, 0.83, 0.62)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	sun.add_child(fill)
	fill.global_rotation_degrees = Vector3(-24, -135, 0)

## ----- TITLE SCREEN (front door; PLAY -> straight into the night) -----

var _title_layer: Control = null

## PLAY: THE PROCESSION is the game — one panel, the night-count + turn-cap
## dials, and GO. The flow is seats/lobby → walkabout → lychgate → match.
func _build_play_panel() -> void:
	phase = Phase.LOBBY
	_hide_title()
	Sfx.play("ui_move")
	_clear_panel(Dialog.text("estate.play.header"), Color(1, 0.9, 0.5))
	var proc_title := Label.new()
	proc_title.text = "THE PROCESSION"
	proc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proc_title.add_theme_font_size_override("font_size", 34)
	proc_title.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	phase_box.add_child(proc_title)
	var proc_desc := Label.new()
	proc_desc.text = Dialog.text("estate.play.procession_desc")
	proc_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	proc_desc.custom_minimum_size = Vector2(660, 0)
	proc_desc.add_theme_font_size_override("font_size", 15)
	proc_desc.modulate.a = 0.8
	phase_box.add_child(proc_desc)
	# The two match dials, persisted like mg_rounds: NIGHTS (1/2/3) and the
	# TURN CAP backstop (8/12/16). Defaults are the doc-28 shipping shape.
	var dial_row := HBoxContainer.new()
	dial_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dial_row.add_theme_constant_override("separation", 12)
	var nights_dial := Button.new()
	nights_dial.custom_minimum_size = Vector2(200, 48)
	nights_dial.text = "NIGHTS: %d" % _proc_nights()
	nights_dial.pressed.connect(func():
		Sfx.play("ui_move")
		var opts := [1, 2, 3]
		PartySetup.set_pref("proc_nights", opts[(opts.find(_proc_nights()) + 1) % opts.size()])
		nights_dial.text = "NIGHTS: %d" % _proc_nights())
	dial_row.add_child(nights_dial)
	var cap_dial := Button.new()
	cap_dial.custom_minimum_size = Vector2(200, 48)
	cap_dial.text = "TURN CAP: %d" % _proc_turncap()
	cap_dial.pressed.connect(func():
		Sfx.play("ui_move")
		var opts := [8, 12, 16]
		PartySetup.set_pref("proc_turncap", opts[(opts.find(_proc_turncap()) + 1) % opts.size()])
		cap_dial.text = "TURN CAP: %d" % _proc_turncap())
	dial_row.add_child(cap_dial)
	phase_box.add_child(dial_row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	phase_box.add_child(spacer)
	# GO — gather the mourners: seats first, then the walkabout, then the gate.
	var go_btn := Button.new()
	go_btn.custom_minimum_size = Vector2(460, 78)
	go_btn.text = "GO — GATHER THE MOURNERS"
	go_btn.add_theme_font_size_override("font_size", 28)
	go_btn.pressed.connect(func():
		Sfx.play("ui_confirm")
		_enter_lobby())
	var pc := CenterContainer.new()
	pc.add_child(go_btn)
	phase_box.add_child(pc)
	var back := Button.new()
	back.text = "BACK TO TITLE"
	back.pressed.connect(_enter_title)
	phase_box.add_child(back)

func _proc_nights() -> int:
	return clampi(int(PartySetup.pref("proc_nights", 3)), 1, 3)

func _proc_turncap() -> int:
	return clampi(int(PartySetup.pref("proc_turncap", 12)), 4, 40)

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
	# G3 photobomb law, applied to the one launch that never had it: the hub
	# AND the estate's copy of the world hide while the procession runs its
	# own — two identical worlds in one space z-fight and the match "plays in
	# the background" (Alex's catch, first live PLAY on the new forecourt).
	$Grounds.visible = false
	$Grounds.process_mode = Node.PROCESS_MODE_DISABLED
	$GraffitiWall.visible = false
	$Plinths.visible = false
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
		$Grounds.visible = true
		$Grounds.process_mode = Node.PROCESS_MODE_INHERIT
		$GraffitiWall.visible = true
		$Plinths.visible = true
		cam.current = true
		_enter_title(), CONNECT_ONE_SHOT)
	# P3: the PLAY-panel dials feed the real match config.
	proc.begin({"roster": roster, "seed": EstateState.rng.randi(),
		"match_nights": _proc_nights(), "turn_cap": _proc_turncap()})
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
	Sfx.play("ui_move")
	_clear_panel(Dialog.text("estate.slot.header"), Color(0.9, 0.95, 0.9))
	for n in [1, 2, 3]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		var summary := EstateState.slot_summary(n)
		var lab := Label.new()
		lab.text = "SLOT %d — %s" % [n, summary if summary != "" else Dialog.text("estate.slot.empty")]
		lab.custom_minimum_size = Vector2(360, 0)
		lab.add_theme_font_size_override("font_size", 18)
		if n == EstateState.current_slot:
			lab.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		row.add_child(lab)
		var load_btn := Button.new()
		load_btn.custom_minimum_size = Vector2(170, 46)
		load_btn.text = "PLAY THIS ESTATE"
		load_btn.pressed.connect(func():
			Sfx.play("ui_confirm")
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
	hint.text = Dialog.text("estate.slot.wipe_warning")
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
	# D1 (THE FRONT DOOR art pass): the tagline + hint speak in the house's
	# funeral-stationery voice — IM Fell English, parchment ink — the same face
	# the Executor's event cards use (procession.gd). Copy is verbatim; the
	# lighter serif is kept legible by a bump in size and a warm parchment tone.
	var serif: Font = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
	var sub := Label.new()
	sub.text = Dialog.text("estate.title.tagline")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if serif != null:
		sub.add_theme_font_override("font", serif)
	sub.add_theme_font_size_override("font_size", 25)
	sub.add_theme_color_override("font_color", Color(0.87, 0.81, 0.67))
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
		Sfx.play("ui_move")
		PartySetup.toggle())
	row.add_child(settings)
	var mini := Button.new()
	mini.text = "MINIGAMES"
	mini.custom_minimum_size = Vector2(170, 56)
	mini.pressed.connect(func():
		Sfx.play("ui_move")
		_enter_selector())
	row.add_child(mini)
	var ward := Button.new()
	ward.text = "WARDROBE"
	ward.custom_minimum_size = Vector2(160, 56)
	ward.pressed.connect(func():
		Sfx.play("ui_move")
		phase = Phase.LOBBY
		_hide_title()
		_build_wardrobe_panel())
	row.add_child(ward)
	# No exit path existed from the title screen at all (Alex: "no exit game
	# button") — HOLD to confirm (same ritual as the slot-wipe buttons above),
	# then close the app via PartySetup.quit_app() so both quit paths (this one
	# and the pause menu's SHUT THE ESTATE) share one exit.
	var quit_title := Button.new()
	quit_title.text = "HOLD: QUIT"
	quit_title.custom_minimum_size = Vector2(160, 56)
	row.add_child(quit_title)
	var quit_title_hold := HoldConfirm.new()
	quit_title_hold.bind_button(quit_title, 5.0)
	quit_title_hold.completed.connect(PartySetup.quit_app)
	row.add_child(quit_title_hold)
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
	# D1: dress every title button in the funeral stationery — dark ink panel,
	# gold hairline, parchment text; gamepad/hover focus lifts the whole border to
	# full gold (see _style_title_button). Structure, handlers, tab order and the
	# PLAY-first focus grab are all unchanged — this is presentation only.
	var title_btns: Array[Button] = [play, newg, settings, mini, ward, quit_title, host_btn, join_btn]
	for b in title_btns:
		_style_title_button(b)
	var hint := Label.new()
	hint.text = Dialog.text("estate.title.footer")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if serif != null:
		hint.add_theme_font_override("font", serif)
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.60))
	box.add_child(hint)

## D1 — THE FRONT DOOR: one title button, dressed as the house's funeral
## stationery. Near-black ink panel + gold hairline (the register of the
## Executor's event cards, procession.gd _lowerthird_box), parchment text, and a
## focus state that lifts the whole border to full gold so a gamepad cursor is
## unmistakable from couch distance. Labels are set in IM Fell English too — the
## labels are ALL-CAPS action words (no lowercase old-style figures to muddy),
## and a couch-distance screenshot confirmed they stay instantly legible while
## unifying the whole door into the house's one gothic voice. The grow-on-focus
## is added by FrontEndDirector's focus hook, which complements the gold ring.
func _style_title_button(btn: Button) -> void:
	# M2: the title door and every front-of-house menu now share ONE definition of
	# the stationery — core/ui_kit/stationery.gd. This delegates so the door and the
	# PLAY/SETTINGS/WARDROBE/lobby desks can never drift apart again.
	Stationery.button(btn)

func _hide_title() -> void:
	if _title_layer != null:
		_title_layer.visible = false

## ----- LOBBY (PLAY setup: seats, night length, wardrobe) -----

func _enter_lobby() -> void:
	phase = Phase.LOBBY
	_net_set_ceremony({})
	_hide_title()
	Music.play_slot("lobby")
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
	_clear_panel(Dialog.text("estate.lobby.header"), Color(0.9, 0.95, 0.9))
	_skip_panel_focus = true   # L1: keep the lobby on its couch A=join/ready model (see _focus_panel_deferred)
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
			Sfx.play("ui_move")
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
				Sfx.play("ui_move")
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
	# Read back the PROCESSION match shape chosen on the PLAY panel.
	var match_lbl := Label.new()
	match_lbl.text = "THE PROCESSION · %d NIGHT%s · CAP %d" % [
		_proc_nights(), "" if _proc_nights() == 1 else "S", _proc_turncap()]
	match_lbl.add_theme_font_size_override("font_size", 18)
	match_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	btn_row.add_child(match_lbl)
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
		if ResourceLoader.exists(String(MODULES[mid].scene)):
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
	hint.text = Dialog.text("estate.lobby.controls")
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
	# Seats are settled; gather on the grounds and ready at the lychgate.
	banner.visible = false
	Sfx.play("ui_confirm")
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
	Sfx.play("ui_error")
	_flash("WAITING ON %s - HOST MAY HOLD START" % ", ".join(_seat_names(waiting)), Color(1.0, 0.72, 0.35), 2.0)

func _force_start_night_from_lobby() -> void:
	if phase != Phase.LOBBY:
		return
	Sfx.play("ui_confirm")
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
			Sfx.play("ui_confirm")
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
	Sfx.play("ui_move")
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
			Sfx.play("ui_move")
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
		w.global_position = hub_off + Vector3(-1.5 + i * 1.0, 0.1, 1.0)
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
		th.global_position = hub_off + Vector3(6.4, 0.0, -5.6)
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
	# Prefer the rigged breathing idle (day 5); the static figure is the fallback.
	var ex: Node3D
	if ResourceLoader.exists(ProcessionExecutorBody.EXECUTOR_GLB_RIGGED):
		ex = MeshyProp.instance_rigged(ProcessionExecutorBody.EXECUTOR_GLB_RIGGED,
				ProcessionExecutorBody.RIGGED_NATIVE_HEIGHT, 1.9, 25.0)
	else:
		ex = MeshyProp.instance(EXECUTOR_GLB, 1.9, 25.0)
	$Grounds.add_child(ex)
	ex.global_position = hub_off + Vector3(2.6, 0.0, -3.4)
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
	_album_wall.global_position = hub_off + Vector3(-6.6, 1.7, 2.2)
	_album_wall.rotation.y = deg_to_rad(22)

## One Saki-voiced line for the lobby, drawn from the ledger's memory.
func _executor_greeting() -> String:
	if EstateState.ledger.is_empty():
		return Dialog.text("estate.greeting.empty")
	var last: Dictionary = EstateState.ledger.back()
	var aw: Array = last.get("awards", [])
	if aw.is_empty():
		return Dialog.text("estate.greeting.no_awards")
	var a: Dictionary = aw[EstateState.rng.randi_range(0, aw.size() - 1)]
	var who := str(a.get("who", "someone"))
	var title := str(a.get("title", "themselves"))
	# One rare line honors the estate's first outside guest (2026-07-05),
	# whose field report on the seagull is archived in docs/playtests/.
	if EstateState.rng.randf() < 0.07:
		return Dialog.text("estate.greeting.seagull")
	var lines: Array = Dialog.paras("estate.greeting.pool")
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
		b.global_position = hub_off + Vector3(-2.0 + i * 2.0, 0.4, -1.5)

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.GAME or _module != null or NetSession.is_client():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var origin := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 60.0, 3)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		if hit.collider is EstateWalker:
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
	# P3: the walk-up ready-up — stand at the gate, press A, the match begins
	# (live only once the seats are settled; in the lobby it opens the panel).
	# G3: the zone stands at the REAL lychgate arch now (hub-local -13z).
	{"name": "THE LYCHGATE", "pos": Vector3(0.0, 0, -13.0), "r": 2.8, "act": "procession"},
]
var _strolling := false

func _enter_stroll() -> void:
	_strolling = true
	Sfx.play("card")
	phase_panel.visible = false
	banner.add_theme_font_size_override("font_size", 26)
	_flash(Dialog.text("estate.walkabout.stroll_banner"), Color(0.9, 0.95, 0.9), 9999.0)

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
		"procession":
			# On the pre-match grounds the lychgate starts the match; from a
			# lobby stroll it returns to the seats.
			if phase == Phase.GROUNDS:
				_continue_to_night()
			else:
				_build_lobby_panel()
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
			# G3: spot positions are hub-local; walkers live in world space
			var d: float = walkers[i].global_position.distance_to(hub_off + (spot.pos as Vector3))
			if d <= float(spot.r):
				near_spot = spot
				near_player = i
				break
		if near_player >= 0:
			break
	if near_player >= 0:
		banner.text = Dialog.text("estate.walkabout.near") % [GameState.PLAYER_NAMES[near_player], near_spot.name]
		if PlayerInput.just_pressed(near_player, "a"):
			Sfx.play("confirm")
			_exit_stroll(String(near_spot.act))
			return
	else:
		banner.text = Dialog.text("estate.walkabout.idle")
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
		l.text = Dialog.text("estate.album.empty")
	else:
		l.text = Dialog.text("estate.album.some") % _plural_nights(n)
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
# L1 bug 2: device id -> the seat it was bumped from when it dropped on the
# grounds/lobby, so a reconnect of the SAME id re-seats it (see _on_joy_connection_changed).
var _stranded_pad_seats := {}

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
## register) and frees the pad. GAMEPAD EVERYWHERE (L1) bug 2: the CONNECT branch
## used to only flash — so a wireless pad that dropped across a minigame's scene
## swap (very common on Windows) came back a bot at device -99, and get_move()
## then returned ZERO forever: the character was frozen on the walkabout. The
## handler is now symmetric — a returning pad RECLAIMS the exact seat it was
## bumped from (remembered in _stranded_pad_seats). If the OS re-enumerates it
## under a new joypad id (also common), auto-reclaim can't match, so the press-A
## reclaim path is now reachable on the walkabout too (see _process).
## Mid-minigame disconnects still belong to PartySetup's overlay — see readyroom.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		# Re-seat the returning pad on the seat it was stranded from, but only if
		# that seat is still the vacant bot we left (nobody else pressed A into it).
		if _stranded_pad_seats.has(device):
			var seat: int = int(_stranded_pad_seats[device])
			if PlayerInput.is_bot(seat) and PlayerInput.device_of(seat) == -99:
				PlayerInput.assign(seat, device)
				PlayerInput.set_bot(seat, false)
				PlayerInput.save_setup()
				Sfx.play("ui_confirm")
				_flash("GAMEPAD %d RESTORED — %s IS YOURS AGAIN" % [device + 1, GameState.PLAYER_NAMES[seat]], GameState.PLAYER_COLORS[seat], 2.4)
				if phase == Phase.LOBBY:
					_build_lobby_panel()
			_stranded_pad_seats.erase(device)
			return
		if phase == Phase.LOBBY:
			_flash("GAMEPAD %d RESTORED — PRESS A TO TAKE A SEAT" % (device + 1), Color(0.85, 0.9, 1.0), 2.4)
			# NIT 4: transient notice fades on its own; no "ILL WILL" title over the panel
		return
	if phase != Phase.LOBBY and phase != Phase.GROUNDS:
		return
	for i in 4:
		if PlayerInput.device_of(i) == device and not PlayerInput.is_bot(i):
			_stranded_pad_seats[device] = i   # so a reconnect can hand the seat straight back
			PlayerInput.set_bot(i, true)
			PlayerInput.assign(i, -99)
			_lobby_ready.erase(i)
			_join_ready_lock.erase(i)
			Sfx.play("grudge", -4.0)
			_flash("GAMEPAD %d LOST — %s PLAYS ITSELF (RECONNECT OR PRESS A TO RETAKE)" % [device + 1, GameState.PLAYER_NAMES[i]], GameState.PLAYER_COLORS[i], 2.6)
			if phase == Phase.LOBBY:
				# NIT 4: transient notice fades on its own; no "ILL WILL" title over the panel
				_build_lobby_panel()

func _process(delta: float) -> void:
	if NetSession.is_client():
		_client_process(delta)
		return
	if NetSession.is_host():
		_net_host_broadcast(delta)
	# G3: strollers stay on the estate (the heightmap ends at the rim), and
	# special stones whisper their names to the lead walker — the A-LOOK
	# approach-reveal, wired to the real hub at last (pooled, per-frame safe).
	# Parked entirely while a module owns the screen (the hub is hidden).
	if phase != Phase.GAME and not walkers.is_empty():
		for w in walkers:
			if not is_instance_valid(w):
				continue
			w.global_position.x = clampf(w.global_position.x,
				ProcessionGrounds.EXT_X.x + 4.0, ProcessionGrounds.EXT_X.y - 4.0)
			w.global_position.z = clampf(w.global_position.z,
				ProcessionGrounds.EXT_Z.x + 4.0, ProcessionGrounds.EXT_Z.y - 4.0)
		if _world_board != null and is_instance_valid(walkers[0]):
			_world_board.reveal_names_near(walkers[0].global_position)
	if phase == Phase.LOBBY or phase == Phase.GROUNDS:
		if _strolling:
			# L1 bug 2: a dropped/late pad must be able to reclaim a seat while the
			# table is on the walkabout too — _poll_pad_join only ever acts on an
			# UNSEATED pad, so it never fights a seated stroller's landmark A.
			_poll_pad_join()
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
		# Free roam has no countdown for humans. Bot-only tables move on after
		# a short breath.
		if _all_bots():
			_grounds_timer -= delta
			if _grounds_timer <= GROUNDS_TIME - 4.0:
				_continue_to_night()

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
	# GAMEPAD EVERYWHERE (L1): every estate desk is built here first, then the
	# caller adds its buttons. Defer the pad-focus grab one idle frame so it lands
	# AFTER those buttons exist — it parks the focus cursor on the first enabled
	# one so a controller can drive the panel, and no-ops when the panel has no
	# buttons or a pad cursor already lives inside it (UiFocus.grab_first).
	call_deferred("_focus_panel_deferred")

## L1 verification (--focussweep): build each estate desk and report which
## control the pad-focus cursor parked on. A desk is pad-navigable iff a Button
## takes focus (the LOBBY is the one deliberate "none" — see _focus_panel_deferred).
func _focus_sweep_run() -> void:
	PlayerInput.assign(0, 0)                        # a (phantom) seated human pad
	PlayerInput.set_bot(0, false)
	for i in range(1, 4):
		PlayerInput.set_bot(i, true)
	var screens: Array = [
		["play_panel", func() -> void: _build_play_panel()],
		["slot_panel", func() -> void: _build_slot_panel()],
		["selector", func() -> void: _enter_selector()],
		["howto_card", func() -> void: _show_howto("orbital")],
		["wardrobe", func() -> void: _build_wardrobe_panel()],
		["family_album", func() -> void: _build_album_panel()],
		["freeroam_grounds", func() -> void: phase = Phase.GROUNDS; _build_freeroam_panel()],
		["lobby_seats", func() -> void: _build_lobby_panel()],
	]
	for s in screens:
		(s[1] as Callable).call()
		await get_tree().process_frame
		await get_tree().process_frame
		var f: Control = get_viewport().gui_get_focus_owner()
		var desc := "NONE"
		if f != null:
			desc = "%s '%s'" % [f.get_class(), (f.get("text") if f.get("text") != null else "")]
		print("FOCUSSWEEP %-17s -> %s" % [s[0], desc])
	print("FOCUSSWEEP done")
	get_tree().quit()

## M2 UI CONSISTENCY capture: seat two humans on the requested device type, shoot
## the restyled PLAY/SETTINGS/WARDROBE desks (kbm pass only — they are device-
## independent), then launch TILT and shoot its intro card (device glyphs) and its
## always-on hint bar. Real-time timers so the paused SETTINGS beat still advances.
func _m2_capture(dev: String) -> void:
	var d0 := -1 if dev == "kbm" else 0
	var d1 := -2 if dev == "kbm" else 1
	PlayerInput.assign(0, d0); PlayerInput.set_bot(0, false)
	PlayerInput.assign(1, d1); PlayerInput.set_bot(1, false)
	PlayerInput.set_bot(2, true); PlayerInput.set_bot(3, true)
	if dev == "kbm":
		_build_play_panel()
		await get_tree().create_timer(0.7).timeout
		await VerifyCapture.snap("menu_play")                 # await: snap is async
		PartySetup.toggle()                                   # open SETTINGS (pauses tree)
		await get_tree().create_timer(0.8, true, false, true).timeout
		await VerifyCapture.snap("menu_settings")
		await get_tree().create_timer(0.2, true, false, true).timeout
		PartySetup.toggle()                                   # close
		await get_tree().create_timer(0.3).timeout
		_build_wardrobe_panel()
		await get_tree().create_timer(0.7).timeout
		await VerifyCapture.snap("menu_wardrobe")
		await get_tree().create_timer(0.3).timeout
		_enter_title()
		await get_tree().create_timer(0.4).timeout
	_launch_game("tilt")
	await get_tree().create_timer(2.0).timeout
	await VerifyCapture.snap("game_introcard_%s" % dev)      # device-aware glyphs
	await get_tree().create_timer(13.0).timeout              # intro auto-starts (12s)
	await VerifyCapture.snap("game_hintbar_%s" % dev)        # persistent, device-aware
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## L1 bug 2 proof (--padreclaimtest): drive the real disconnect->reconnect on the
## grounds and log the seat state at each step. Exercises _on_joy_connection_changed.
## Self-contained: the reclaim path persists via PlayerInput.save_setup(), so this
## backs up and restores party_setup.json (house convention for verify hooks).
func _pad_reclaim_test_run() -> void:
	var ps := ProjectSettings.globalize_path("user://party_setup.json")
	if FileAccess.file_exists(ps):
		DirAccess.copy_absolute(ps, ps + ".prbak")
	phase = Phase.GROUNDS
	PlayerInput.assign(0, 0)
	PlayerInput.set_bot(0, false)
	print("PADRECLAIM start   seat0 bot=%s dev=%d" % [str(PlayerInput.is_bot(0)), PlayerInput.device_of(0)])
	_on_joy_connection_changed(0, false)   # pad drops across the minigame / idle
	print("PADRECLAIM dropped seat0 bot=%s dev=%d (want bot=true dev=-99)" % [str(PlayerInput.is_bot(0)), PlayerInput.device_of(0)])
	_on_joy_connection_changed(0, true)    # same pad returns
	print("PADRECLAIM back    seat0 bot=%s dev=%d (want bot=false dev=0)" % [str(PlayerInput.is_bot(0)), PlayerInput.device_of(0)])
	var ok := (not PlayerInput.is_bot(0)) and PlayerInput.device_of(0) == 0
	print("PADRECLAIM result: %s" % ("PASS — walker driven by its pad again" if ok else "FAIL"))
	if FileAccess.file_exists(ps + ".prbak"):
		DirAccess.copy_absolute(ps + ".prbak", ps)
		DirAccess.remove_absolute(ps + ".prbak")
		print("PADRECLAIM party_setup.json restored")
	get_tree().quit()

## Deferred by _clear_panel: hand the freshly-built desk a pad-focus cursor.
## The LOBBY ("who's on the couch") opts out: there a pad's A is the couch
## join/ready button (_poll_lobby_ready) and its focused buttons cycle a seat
## HUMAN/BOT — a focus cursor would make one A press do both. The lobby stays on
## its documented couch model (A join/ready, B leave, hold Start to begin); the
## settings SEATS tab is the focus-navigable way to drive seats from a pad.
func _focus_panel_deferred() -> void:
	# M2 UI CONSISTENCY: every estate desk (PLAY, NEW GAME, HOST/JOIN NIGHT, the
	# lobby seats, free roam) is built into phase_box and reaches here one idle
	# frame later — the single choke point to dress its buttons in the house
	# stationery, before UiFocus wires the gold ring + lift. Runs even for the
	# lobby (which skips the pad-focus grab) so its seat buttons match too.
	Stationery.apply_tree(phase_box)
	if _skip_panel_focus:
		_skip_panel_focus = false
		return
	UiFocus.grab_first(phase_box)

## Pre-match free roam. The grounds are walkable and the match begins when the
## table gathers at the lychgate. There is no countdown for humans.
func _enter_grounds() -> void:
	phase = Phase.GROUNDS
	_net_set_ceremony({})
	_grounds_timer = GROUNDS_TIME
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
	_clear_panel(Dialog.text("estate.walkabout.freeroam_header"))
	var hint := Label.new()
	hint.text = Dialog.text("estate.walkabout.freeroam_hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(700, 0)
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate.a = 0.75
	phase_box.add_child(hint)
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
	cont.text = "READY AT THE LYCHGATE"
	cont.pressed.connect(_continue_to_night)
	row2.add_child(cont)
	phase_box.add_child(row2)

## Leaves free roam and launches THE PROCESSION.
func _continue_to_night() -> void:
	if phase != Phase.GROUNDS:
		return
	_strolling = false
	banner.remove_theme_font_size_override("font_size")
	banner.visible = false
	Sfx.play("confirm")
	_enter_procession()

## Exhibition minigames launch from their how-to card. Modules with their own
## IntroCard keep that ready-up; the hub does not add a second gate.
func _launch_game(id: String, practice := false) -> void:
	if phase == Phase.GAME:
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
	$Sun.visible = false
	$WorldEnvironment.environment = null
	if info.mode == "gamestate":
		GameState.player_count = EstateState.players.size()
		GameState.reset_match()
		get_tree().root.add_child(_module)
		_assert_module_camera(_module)
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
		_assert_module_camera(_module)
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
	$Sun.visible = true
	$WorldEnvironment.environment = _saved_env
	$GraffitiWall.visible = true
	cam.current = true
	var placements: Array = results.get("placements", [])
	if placements.size() >= 2:
		await _present_match_podium(placements)
	var champ_line := "EXHIBITION OVER"
	if not placements.is_empty():
		var w = EstateState.players[placements[0]]
		champ_line = "EXHIBITION: %s TAKES IT" % w.name
	_flash(champ_line, Color(0.9, 0.95, 0.9), 3.0)
	_enter_selector()

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

func _flash(text: String, color: Color, dur: float) -> void:
	# Podium banners ride the stage facts so guests see the same words.
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
	return NetLobby.build_lobby_state(self)

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
	$Sun.visible = false
	$WorldEnvironment.environment = null
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

## The host narrates an exhibition podium as facts; the guest restages it and
## never simulates an outcome.
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
		return
	_client_cer_stage = stg
	if not cer.has("banner"):
		banner.visible = false
		_client_banner_sig = ""
	print("NET ceremony stage: %s" % stg)
	if stg == "match_podium":
		_client_show_podium(cer)

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
## host:  windowed, --net=host --netprobe=host
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
		walkers[1].global_position = hub_off + Vector3(0.0, 0.1, -2.5)
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
	var in_game := func() -> bool: return phase == Phase.GAME
	if not await _np_wait(in_game, 40.0):
		print("NETPROBE FAIL: procession never reached GAME")
		await _netprobe_finish(ps, pf)
		return
	await get_tree().create_timer(1.2).timeout
	await _np_snap("online_host_game")
	print("NETPROBE_RESULTS procession_started=true")
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
	var game_seen := func() -> bool: return String(_client_last_state.get("phase", "")) == "GAME"
	if await _np_wait(game_seen, 40.0):
		await get_tree().create_timer(1.2).timeout
		await _np_snap("online_client_game")
	print("NETPROBE_CLIENT_DONE")
	# outlive the host by a breath so its quit lands first, then leave
	await get_tree().create_timer(6.0).timeout
	get_tree().quit()

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
			w.global_position = hub_off + Vector3(-1.5 + w.player_idx * 1.0, 0.1, 1.4)
	if al != null and al.has_method("debug_show_gossip"):
		al.debug_show_gossip()
	await get_tree().create_timer(0.4).timeout
	await _ambient_snap("gallery")
	# THE GALLERY (silenced) — a walker leans into the flock; heads snap forward
	if not walkers.is_empty():
		walkers[0].global_position = hub_off + Vector3(-7.2, 0.1, -4.6)
	await get_tree().create_timer(0.9).timeout
	await _ambient_snap("gallery_silent")
	# THE GROUNDSKEEPER (mid-stare) — a walker jumps at Old Rake's pile; the
	# leaves scatter and he freezes, staring, until they leave. (Gameplay uses
	# the vy>2 jump check; the shot forces the latch to dodge the physics race.)
	# Park the other walkers away so Old Rake and his scattered pile read clear.
	var al2: Node = get_tree().get_first_node_in_group("ambient_life")
	for w in walkers:
		if is_instance_valid(w) and w.player_idx != 0:
			w.global_position = hub_off + Vector3(7.5 + w.player_idx * 0.8, 0.1, -1.0)
	if not walkers.is_empty():
		walkers[0].global_position = Vector3(-2.2, 0.1, 2.05)
		walkers[0].velocity = Vector3(0, 6, 0)
		if al2 != null and al2.has_method("debug_stare"):
			al2.debug_stare(walkers[0].global_position)
	await get_tree().create_timer(0.6).timeout
	if not walkers.is_empty():
		walkers[0].global_position = Vector3(-2.2, 0.1, 2.05)   # hold them in his glare
	await get_tree().create_timer(0.1).timeout
	await _ambient_snap("groundskeeper_stare")
	# THE QUEUE — two ghost mourners hovering at a mausoleum door that never
	# opens; the front one consults its pocket watch. Clear the walkers away so
	# the ghosts are in their resting queue (no "after you" step-aside firing).
	for w in walkers:
		if is_instance_valid(w):
			w.global_position = Vector3(2.0 + w.player_idx * 1.0, 0.1, 3.0)
	await get_tree().create_timer(0.6).timeout
	if al2 != null and al2.has_method("debug_check_watch"):
		al2.debug_check_watch()
	await get_tree().create_timer(0.4).timeout
	await _ambient_snap("queue")
	# ATMOSPHERE — fog wisps in the graves, embers over the lanterns. Walkers
	# tucked to the far side so the floor of life reads on its own.
	for w in walkers:
		if is_instance_valid(w):
			w.global_position = Vector3(8.0 + w.player_idx * 0.7, 0.1, 2.5)
	await get_tree().create_timer(0.8).timeout
	await _ambient_snap("atmosphere")
	# EXTRAS — the vengeful seagull wheeling, and the runt lantern popped bright.
	if al2 != null and al2.has_method("debug_extras"):
		al2.debug_extras()
	await get_tree().create_timer(0.3).timeout
	await _ambient_snap("extras")
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
