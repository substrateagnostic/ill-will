extends Node3D
## Par for the Curse — implements the anthology module contract by
## duck-typing core/minigame.gd (signal finished + results dictionary).

signal finished(results: Dictionary)

enum Phase { DRAFT, BUILD, PUTT, BETWEEN }

const BALL_SCENE := preload("res://scenes/ball.tscn")
const GRAVESTONE_SCENE := preload("res://scenes/gravestone.tscn")
const CHAR_SCENES := [
	preload("res://assets/models/kaykit/Barbarian.glb"),
	preload("res://assets/models/kaykit/Knight.glb"),
	preload("res://assets/models/kaykit/Mage.glb"),
	preload("res://assets/models/kaykit/Rogue.glb"),
]
const BUILD_TIME_LIMIT := 25.0
const ROYALTY := 2
## Each player drafts + places this many traps per build phase. Playtest
## verdict (Alex): 1 placement, MORE TRAP TYPES — density saturates maps.
const TRAPS_PER_BUILD := 1
const CHAOS_TRAP_SPEED := 1.6
## THE KILLCAM: a normal-round death freezes the table for this long while the
## victim's final seconds replay from a low angle near the killing trap. Hard cap;
## any player input skips it, bot-only matches auto-skip much faster. Chaos never
## pauses. The table is frozen via get_tree().paused, so the turn resumes exactly
## KILLCAM_DURATION later and NO physics advances — determinism is untouched.
const KILLCAM_DURATION := 1.6

var balls: Array = []
## PAR v4: the caddies became the players (PlayerAvatar). Same reaction API.
var avatars: Array = []
var _last_green_pos := {}
var round_manager: RoundManager
var course: Course
var phase := Phase.BETWEEN
var draft_order: Array = []
var draft_pointer := 0
var current_hand: Array = []
var grudge_card_idx := -1
var autobuild_count := 0
var _picks_this_turn := 0
var _build_timer := 0.0
var _currency_log: Array = []
## Anthology kill ledger (module contract results.kill_events). Each entry is
## {killer: int, victim: int, cause: String}; killer == -1 means environment or
## self-inflicted (no OTHER player to credit), cause is the trap_id slug. Pure
## reporting — appended alongside the existing royalty/grudge attribution.
var _kill_events: Array = []
var _highlights: Array = []
var _golden_hour_done := false
## Chaos concurrency telemetry: peak number of balls in motion at once. Printed
## each time a new peak is reached so a verify run can prove true overlap.
var _chaos_peak_movers := 0
## Looping heat-color pulse on the chaos turn banner (presentation only).
var _chaos_banner_tween: Tween = null

# --- minimal per-player bot driver (turn-based) --------------------------------
# A seat plays itself if PlayerInput marks it a bot OR the --parbots flag forces
# ALL seats to bots. Human seats are untouched (mouse drives draft/build/putt).
# It drives the SAME debug entry points a verify run uses, so no gameplay/putt
# physics is affected. All bot randomness comes from _bot_rng (seeded from
# GameState.rng), so a --parbots match is reproducible per --seed.
var _par_bot_all := false
## KILLCAM state. _killcam is the presentation node; _nokillcam disables the
## feature (CLI + timing-sensitive harness paths); _killcam_claimed enforces ONE
## killcam per stroke resolution (extra deaths on the same putt only get a banner).
var _killcam: Killcam = null
var _nokillcam := false
var _killcam_claimed := false
var _killcam_test_mode := ""
var _killcam_t0 := 0
## Verify-only: quit right after MATCH_OVER (skipping the winner flyover) so
## headless determinism soaks self-terminate fast. Never set in real play.
var _par_quit := false
var _bot_rng := RandomNumberGenerator.new()
var _bot_ctx := ""          # actionable-turn key; resets the think timer on change
var _bot_think_t := 0.0
## PAR v4 WAVE 1 — embodied third-person shots. The AvatarShot state machine
## walks the acting avatar to its ball and fires the frozen debug_putt at the
## swing's contact frame. _embodied=false (--v3putt or pref "par_embodied")
## restores the exact v3 interface (drag putt, no walk gate, diorama-only cam).
var avatar_shot: AvatarShot = null
var _embodied := true

@onready var putt_controller: Node3D = $PuttController
@onready var placement: Node3D = $PlacementController
@onready var camera_rig: Node3D = $CameraRig
@onready var sun: DirectionalLight3D = $Sun
@onready var fill_light: DirectionalLight3D = $FillLight
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var turn_label: Label = $UI/TurnLabel
@onready var stroke_label: Label = $UI/StrokeLabel
@onready var round_label: Label = $UI/RoundLabel
@onready var banner: Label = $UI/Banner
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows
@onready var draft_panel: PanelContainer = $UI/DraftPanel
@onready var draft_label: Label = $UI/DraftPanel/DraftBox/DraftLabel
@onready var card_row: HBoxContainer = $UI/DraftPanel/DraftBox/CardRow
@onready var build_hint: Label = $UI/BuildHint

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--parbots":
			_par_bot_all = true
		elif arg == "--nokillcam":
			_nokillcam = true
		elif arg == "--parquit":
			_par_quit = true
		elif arg.begins_with("--killcamtest="):
			_killcam_test_mode = arg.trim_prefix("--killcamtest=")
		elif arg == "--v3putt":
			_embodied = false
	if _embodied:
		_embodied = bool(PartySetup.pref("par_embodied", true))
	# Seed the bot rng FROM GameState.rng without consuming its stream (read the
	# seed value, don't draw), so drafting/course/trap RNG is untouched.
	_bot_rng.seed = int(GameState.rng.seed) ^ 0x9E3779B9
	_setup_course()
	round_manager = RoundManager.new()
	round_manager.name = "RoundManager"
	add_child(round_manager)
	round_manager.turn_started.connect(_on_turn_started)
	round_manager.round_finished.connect(_on_round_finished)
	round_manager.ball_resolved.connect(_on_ball_resolved)
	putt_controller.stroke_taken.connect(_on_stroke_taken)
	course.ball_entered_cup.connect(_on_cup_entry)
	course.ball_entered_gutter.connect(_on_ball_gutter)
	placement.trap_container = course.get_node("TrapContainer")
	placement.course = course
	placement.trap_placed.connect(_on_trap_placed)
	_apply_course_camera()
	_killcam = Killcam.new()
	_killcam.name = "Killcam"
	add_child(_killcam)
	_killcam.finished.connect(_on_killcam_finished)
	avatar_shot = AvatarShot.new()
	avatar_shot.name = "AvatarShot"
	add_child(avatar_shot)
	avatar_shot.setup(self, putt_controller, camera_rig, $UI)
	avatar_shot.contact_fired.connect(_on_swing_contact)
	# v3 drag putt lives behind the settings pref (spec OQ2); embodied-off = v3 feel.
	putt_controller.drag_enabled = (not _embodied) or bool(PartySetup.pref("par_drag_putt", false))
	_spawn_balls()
	banner.visible = false
	if _killcam_test_mode == "chaos":
		GameState.round_num = GameState.rounds_total
	_rebuild_scoreboard()
	_start_round()
	if _killcam_test_mode != "":
		call_deferred("_run_killcam_test", _killcam_test_mode)

func _setup_course() -> void:
	print("COURSE selected: %s" % GameState.course_id)
	var scene: PackedScene = load("res://scenes/courses/%s.tscn" % GameState.course_id)
	course = scene.instantiate()
	course.name = "Course"
	add_child(course)
	move_child(course, 0)

func _apply_course_camera() -> void:
	camera_rig.course_center = course.course_center
	camera_rig.course_extent = course.course_extent
	camera_rig.home_position = course.camera_position
	var cam: Camera3D = camera_rig.get_node("Camera3D")
	cam.position = course.camera_position
	cam.fov = course.camera_fov

func _spawn_balls() -> void:
	var n: int = GameState.players.size()
	for i in n:
		var b: Ball = BALL_SCENE.instantiate()
		b.player_index = i
		b.player_color = GameState.players[i].color
		add_child(b)
		b.global_position = _tee_pos(i)
		b.sunk.connect(round_manager.on_ball_sunk.bind(i))
		b.sunk.connect(_on_any_ball_sunk.bind(i))
		b.died.connect(_on_ball_died.bind(i))
		b.came_to_rest.connect(_on_ball_rest.bind(b))
		_last_green_pos[b] = b.global_position
		balls.append(b)
		var a := PlayerAvatar.new()
		add_child(a)
		a.setup(CHAR_SCENES[i], GameState.players[i].color)
		_place_avatar_home(a, i)
		avatars.append(a)
	# Wave-1 physics isolation: avatars NEVER exchange contacts with balls (the
	# sim stays byte-identical to v3). Griefer ball-contact arrives in wave 2.
	for a in avatars:
		for b in balls:
			a.add_collision_exception_with(b)
	course.balls = balls

## Park an avatar at its tee-address spot: just behind its ball, facing the cup.
func _place_avatar_home(a: PlayerAvatar, i: int) -> void:
	var tee := _tee_pos(i)
	var to_cup: Vector3 = course.cup_position() - tee
	to_cup.y = 0.0
	to_cup = to_cup.normalized() if to_cup.length() > 0.01 else Vector3(0, 0, -1)
	var pos := tee - to_cup * AvatarShot.ADDRESS_BACK
	a.teleport_to(Vector3(pos.x, 0.05, pos.z))
	a.face_dir(to_cup)

func _tee_pos(i: int) -> Vector3:
	var tees: Array = course.tee_positions()
	var n: int = GameState.players.size()
	var idx: int = i if n == 4 else i + (4 - n) / 2
	idx = clampi(idx, 0, tees.size() - 1)
	var pos: Vector3 = tees[idx]
	return pos

func _start_round() -> void:
	banner.visible = false
	camera_rig.set_mode(camera_rig.Mode.DIORAMA)
	for i in balls.size():
		balls[i].reset_for_round(_tee_pos(i))
		avatars[i].revive()
		_place_avatar_home(avatars[i], i)
	if GameState.is_chaos_round():
		round_label.text = "CHAOS ROUND"
		_enter_chaos_round()
		_begin_putt_phase()
		return
	round_label.text = "ROUND %d / %d" % [GameState.round_num, GameState.rounds_total]
	var standings := GameState.standings()
	draft_order = standings.duplicate()
	draft_order.reverse()
	draft_pointer = 0
	_picks_this_turn = 0
	_begin_draft_turn()

func _enter_chaos_round() -> void:
	course.set_trap_speed_scale(CHAOS_TRAP_SPEED)
	_apply_golden_hour()
	Sfx.play("match_win", -4.0)
	_flash_banner("CHAOS ROUND\nNO WAITING — ALL LIVE", Color(1.0, 0.55, 0.2), 2.8)
	_set_chaos_turn_banner()

## Chaos is simultaneous: a per-player "X'S TURN" banner lies. Replace the turn
## label with a persistent, heat-pulsing "CHAOS — EVERYONE AT ONCE" (same
## Luckiest Guy label, so it matches the existing banner style). Stroke counters
## keep updating for whoever the shot clock is on. Presentation only — no
## gameplay/timing change.
func _set_chaos_turn_banner() -> void:
	turn_label.text = "CHAOS — EVERYONE AT ONCE"
	if _chaos_banner_tween != null and _chaos_banner_tween.is_valid():
		_chaos_banner_tween.kill()
	_chaos_banner_tween = create_tween().set_loops()
	_chaos_banner_tween.tween_method(_set_turn_label_color, 0.0, 1.0, 0.55)
	_chaos_banner_tween.tween_method(_set_turn_label_color, 1.0, 0.0, 0.55)

## Alternate the chaos banner between two heat colors (gold-orange <-> ember red).
func _set_turn_label_color(t: float) -> void:
	var hot := Color(1.0, 0.82, 0.22)
	var ember := Color(1.0, 0.33, 0.13)
	turn_label.add_theme_color_override("font_color", hot.lerp(ember, t))

func _stop_chaos_turn_banner() -> void:
	if _chaos_banner_tween != null and _chaos_banner_tween.is_valid():
		_chaos_banner_tween.kill()
	_chaos_banner_tween = null

func _apply_golden_hour() -> void:
	if _golden_hour_done:
		return
	_golden_hour_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "light_color", Color(1.0, 0.5, 0.24), 1.4)
	tw.tween_property(sun, "light_energy", 1.7, 1.4)
	tw.tween_property(sun, "rotation_degrees", Vector3(-14, -128, 0), 1.4)
	tw.tween_property(fill_light, "light_color", Color(1.0, 0.62, 0.4), 1.4)
	var env: Environment = world_env.environment
	tw.tween_property(env, "fog_light_color", Color(1.0, 0.55, 0.3), 1.4)
	tw.tween_property(env, "fog_density", 0.012, 1.4)
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	tw.tween_property(sky_mat, "sky_top_color", Color(0.78, 0.42, 0.34), 1.4)
	tw.tween_property(sky_mat, "sky_horizon_color", Color(1.0, 0.55, 0.28), 1.4)

func _begin_draft_turn() -> void:
	if draft_pointer >= draft_order.size():
		_begin_putt_phase()
		return
	phase = Phase.DRAFT
	var p: int = draft_order[draft_pointer]
	var player = GameState.players[p]
	current_hand = TrapCatalog.random_hand(GameState.rng)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forcetrap="):
			current_hand[0] = arg.trim_prefix("--forcetrap=")
	grudge_card_idx = -1
	# Cursed-luck and grudge picks only apply to a player's FIRST trap this turn.
	var is_last_place: bool = _picks_this_turn == 0 and p == GameState.standings().back() and GameState.round_num > 1
	if is_last_place:
		current_hand[0] = TrapCatalog.random_cursed(GameState.rng)
	if _picks_this_turn == 0 and player.grudge > 0:
		grudge_card_idx = current_hand.size()
		current_hand.append(TrapCatalog.random_cursed(GameState.rng))
	var pick_tag := "" if TRAPS_PER_BUILD <= 1 else "  (%d/%d)" % [_picks_this_turn + 1, TRAPS_PER_BUILD]
	draft_label.text = "%s — DRAFT YOUR TRAP%s%s" % [player.name, pick_tag, "  (CURSED LUCK: last place)" if is_last_place else ""]
	draft_label.add_theme_color_override("font_color", player.color)
	for c in card_row.get_children():
		c.queue_free()
	for idx in current_hand.size():
		var id: String = current_hand[idx]
		var info: Dictionary = TrapCatalog.info(id)
		var btn := Button.new()
		var cursed := TrapCatalog.is_cursed(id)
		var title: String = ("☠ " + info.name) if cursed else info.name
		if idx == grudge_card_idx:
			title = "GRUDGE PICK\n" + title
		btn.text = "%s\n\n%s" % [title, info.desc]
		btn.custom_minimum_size = Vector2(230, 160)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		if cursed:
			btn.modulate = Color(1.0, 0.75, 1.0)
		btn.pressed.connect(_on_card_picked.bind(idx))
		card_row.add_child(btn)
	draft_panel.visible = true
	turn_label.text = "%s IS SCHEMING" % player.name
	turn_label.add_theme_color_override("font_color", player.color)
	stroke_label.text = ""

func _on_card_picked(card_idx: int) -> void:
	if phase != Phase.DRAFT or card_idx >= current_hand.size():
		return
	var p: int = draft_order[draft_pointer]
	var player = GameState.players[p]
	var id: String = current_hand[card_idx]
	Sfx.play("card")
	if card_idx == grudge_card_idx:
		Sfx.play("grudge")
		player.grudge = maxi(0, player.grudge - 1)
	draft_panel.visible = false
	phase = Phase.BUILD
	_build_timer = 0.0
	build_hint.visible = true
	var info: Dictionary = TrapCatalog.info(id)
	turn_label.text = "%s PLACES: %s" % [player.name, info.name]
	placement.begin(TrapCatalog.load_scene(id), p, player.color, info.get("params", {}))
	# Course saturated for this footprint? Skip the placement silently.
	if not placement.has_valid_placement():
		placement.cancel()
		build_hint.visible = false
		_advance_after_placement()

func _on_trap_placed(_trap: Trap) -> void:
	build_hint.visible = false
	_advance_after_placement()

func _advance_after_placement() -> void:
	_picks_this_turn += 1
	if _picks_this_turn < TRAPS_PER_BUILD:
		_begin_draft_turn()
	else:
		_picks_this_turn = 0
		draft_pointer += 1
		_begin_draft_turn()

func _begin_putt_phase() -> void:
	phase = Phase.PUTT
	round_manager.start_round(GameState.standings(), balls, GameState.is_chaos_round())

func _process(delta: float) -> void:
	# mouse putting is disabled on a bot's turn (the bot drives it instead)
	var cur := round_manager.current_player()
	putt_controller.enabled = phase == Phase.PUTT and round_manager.is_turn_ready() and not _is_bot(cur)
	_bot_tick(delta)
	if phase == Phase.PUTT and GameState.is_chaos_round():
		_track_chaos_concurrency()
	if phase == Phase.BUILD:
		_build_timer += delta
		if _build_timer > BUILD_TIME_LIMIT:
			placement.cancel()
			build_hint.visible = false
			_flash_banner("TOO SLOW — TRAP FORFEITED", Color(0.8, 0.8, 0.8), 1.5)
			_advance_after_placement()

## Counts balls currently rolling (chaos round). Prints on each new peak so the
## overlap is provable from the log; the peak line naming 3+ movers pairs with
## the concurrency screenshot.
func _track_chaos_concurrency() -> void:
	var movers := 0
	for b in balls:
		if b == null or b.is_sunk or b.is_dead or b.is_petrified or b.in_transit:
			continue
		if b.linear_velocity.length() > 0.6:
			movers += 1
	if movers >= 2:
		print("CHAOS_CONCURRENT movers=%d frame=%d" % [movers, Engine.get_process_frames()])
	if movers > _chaos_peak_movers:
		_chaos_peak_movers = movers
		print("CHAOS_CONCURRENT_PEAK movers=%d frame=%d" % [movers, Engine.get_process_frames()])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		GameState.reset_match()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

## Ramp launches can strand a ball off the green but still on the table.
## When a ball rests off-green, send it home to its last on-green lie.
func _on_ball_rest(b: Ball) -> void:
	if b.is_sunk or b.is_dead or b.is_petrified:
		return
	if course.is_point_on_green(b.global_position):
		_last_green_pos[b] = b.global_position
		return
	var home: Vector3 = _last_green_pos.get(b, _tee_pos(b.player_index))
	b.last_rest_position = home
	b.call_deferred("reset_to_rest")
	Sfx.play("invalid", -6.0)
	_flash_banner("%s WENT EXPLORING — RETURNED" % GameState.players[b.player_index].name, Color(0.85, 0.85, 0.85), 1.4)

func _on_cup_entry(body: Node3D) -> void:
	if body is Ball and not body.is_sunk:
		body.mark_sunk()

## Adventure gutter (gauntlet only): a ball that leaves the green at a marked
## mouth is swept down a side channel and delivered near the cup after a visible
## detour — a risk/reward alternative to the plain return-home everywhere else.
func _on_ball_gutter(body: Node3D, target: Vector3) -> void:
	if not body is Ball or body.is_sunk or body.is_dead or body.is_petrified or body.in_transit:
		return
	var b: Ball = body
	b.enter_gutter()
	Sfx.play("bounce", -2.0)
	print("GUTTER: %s took the channel -> near cup" % GameState.players[b.player_index].name)
	_flash_banner("%s HIT THE ADVENTURE GUTTER!" % GameState.players[b.player_index].name, Color(0.3, 0.9, 1.0), 1.6)
	var start: Vector3 = b.global_position
	# Two-hop detour: dip out to a side waypoint (below the lip), then rise to the
	# green near the cup. Quadratic-ish path via nested lerps for a swept feel.
	var mid := Vector3((start.x + target.x) * 0.5, -1.1, (start.z + target.z) * 0.5 + 1.2)
	var tw := create_tween()
	tw.tween_method(func(t: float): _gutter_step(b, start, mid, target, t), 0.0, 1.0, 1.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _gutter_land(b, target))

func _gutter_step(b: Ball, a: Vector3, mid: Vector3, c: Vector3, t: float) -> void:
	if not is_instance_valid(b):
		return
	var p := a.lerp(mid, t).lerp(mid.lerp(c, t), t)
	b.global_position = p

func _gutter_land(b: Ball, target: Vector3) -> void:
	if not is_instance_valid(b):
		return
	b.exit_gutter(target)
	_last_green_pos[b] = target
	print("GUTTER_DONE: delivered near cup at %.1f,%.1f" % [target.x, target.z])

func _on_turn_started(p: int) -> void:
	var player = GameState.players[p]
	putt_controller.ball = balls[p]
	camera_rig.ball = balls[p]
	if _embodied:
		# Walk the acting avatar to its ball; the swing fires the frozen putt.
		avatar_shot.begin_turn(p, avatars[p], balls[p], _is_bot(p), GameState.is_chaos_round())
		# Camera: skill-shot framing for the normal-round shot (owner note:
		# SMITE-style, aim line readable across the lane). CHAOS keeps the v3
		# diorama — several balls are live at once and the overview must read.
		if not GameState.is_chaos_round():
			camera_rig.set_mode(camera_rig.Mode.SHOT, avatars[p])
	if GameState.is_chaos_round():
		# Simultaneous play: keep the persistent CHAOS banner (set on round
		# entry) instead of a misleading per-player turn line. The stroke
		# counter still tracks whoever the shot clock is currently on.
		_update_stroke_label(p)
		return
	turn_label.text = "%s'S TURN" % player.name
	turn_label.add_theme_color_override("font_color", player.color)
	_update_stroke_label(p)

## Contact frame fired (the ball is away): hand the roll back to the diorama so
## trap-dodging reads from the overview — the readability the v1 spec demanded.
func _on_swing_contact(_p: int) -> void:
	if not GameState.is_chaos_round():
		camera_rig.set_mode(camera_rig.Mode.DIORAMA)

func _on_stroke_taken() -> void:
	# A fresh stroke opens a new resolution window -> the next death may claim a killcam.
	_killcam_claimed = false
	# A stroke fired outside the swing (drag putt, --autoplay direct, --autoputt,
	# killcam tests) stands the embodied state machine down for this turn.
	avatar_shot.on_external_stroke()
	round_manager.notify_stroke()
	_update_stroke_label(round_manager.current_player())

func _update_stroke_label(p: int) -> void:
	if p < 0:
		stroke_label.text = ""
		return
	stroke_label.text = "STROKE %d / %d" % [mini(round_manager.strokes[p] + 1, RoundManager.STROKE_CAP), RoundManager.STROKE_CAP]

func _on_any_ball_sunk(p: int) -> void:
	print("BALL_SUNK p=%d round=%d" % [p, GameState.round_num])
	Sfx.play("sink")
	avatars[p].react("Cheer")
	_spawn_confetti(course.get_node("CupArea").global_position + Vector3(0, 0.6, 0), GameState.players[p].color)
	_flash_banner("%s SINKS IT!" % GameState.players[p].name, GameState.players[p].color, 1.4)

func _on_ball_died(killer: Trap, victim: int) -> void:
	var v = GameState.players[victim]
	v.grudge += 1
	var death_pos: Vector3 = balls[victim].global_position
	Sfx.play("splat")
	Sfx.play("death")
	avatars[victim].react_death()
	camera_rig.shake(0.35)
	camera_rig.focus_on(death_pos, 1.3)
	_spawn_death_fx(death_pos, v.color)
	_spawn_gravestone(death_pos, v.color)
	_currency_log.append({"type": "grudge", "player": victim, "amount": 1, "reason": "died"})
	# Anthology kill attribution (reporting only; behavior below is unchanged).
	# killer -1 = environment/self (authorless course trap OR a player's own
	# trap); a real killer (>=0) mirrors exactly who earns the royalty.
	var kev_killer := -1
	var kev_cause := "course"
	if killer != null:
		kev_cause = killer.trap_id
		if killer.author_index >= 0 and killer.author_index != victim:
			kev_killer = killer.author_index
	_kill_events.append({"killer": kev_killer, "victim": victim, "cause": kev_cause})
	var credit := "THE COURSE"
	var credit_color := Color(0.9, 0.9, 0.9)
	if killer != null and killer.author_index >= 0:
		var a = GameState.players[killer.author_index]
		credit = "%s'S %s" % [a.name, killer.display_name]
		credit_color = a.color
		if killer.author_index == victim:
			_highlights.append("%s died to their OWN %s" % [a.name, killer.display_name])
		else:
			a.score += ROYALTY
			a.royalties += ROYALTY
			avatars[killer.author_index].react("Cheer")
			_currency_log.append({"type": "royalty", "player": killer.author_index, "amount": ROYALTY, "reason": "killed %s" % v.name})
			_rebuild_scoreboard()
	elif killer != null:
		credit = killer.display_name
	if GameState.is_chaos_round():
		_highlights.append("CHAOS CLAIMED %s" % v.name)
	print("DEATH: %s by %s (round %d)" % [v.name, credit, GameState.round_num])
	_flash_banner("%s DIED!\nDEATH BY: %s" % [v.name, credit], credit_color, 2.4)
	round_manager.on_ball_died(victim)
	_resolve_death_cinematics(victim, killer, death_pos, credit, credit_color)

func _slow_mo() -> void:
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.4, true, false, true).timeout
	Engine.time_scale = 1.0

# --- THE KILLCAM ---------------------------------------------------------------
## Decide what a death looks like: a full replay (normal round, first death of the
## stroke), a credit banner (chaos, or an already-claimed stroke), or a
## timeline-neutral no-op (headless / determinism harness / --nokillcam). Builds
## the authorship credit once and hands it to whichever path runs.
func _resolve_death_cinematics(victim: int, killer: Trap, death_pos: Vector3, credit: String, credit_color: Color) -> void:
	var self_kill := killer != null and killer.author_index == victim
	var has_author := killer != null and killer.author_index >= 0 and not self_kill
	var border_color := credit_color
	var show_border := has_author
	var banner_text := ""
	if self_kill:
		# The Executor's dry register; no author to credit, so no border.
		banner_text = "SELF-INFLICTED.\nTHE ESTATE APPLAUDS."
		show_border = false
	elif has_author:
		banner_text = "%s\n— SIGNED WORK" % credit
	else:
		banner_text = "%s\n— UNSIGNED" % credit
		border_color = Color(0.78, 0.74, 0.67)
		show_border = true
	var banner_color: Color = border_color if show_border else Color(0.95, 0.9, 0.78)

	# CHAOS never pauses — play stays live; the authorship gets a banner only.
	if GameState.is_chaos_round():
		_flash_banner(banner_text, banner_color, 1.6)
		print("KILLCAM chaos-banner victim=%d" % victim)
		return

	# One killcam per stroke resolution. Extra deaths on the same putt just banner.
	if _killcam_claimed:
		_flash_banner(banner_text, banner_color, 1.4)
		print("KILLCAM already-claimed victim=%d -> banner-only" % victim)
		_slow_mo()
		return
	_killcam_claimed = true

	# Determinism-sensitive contexts: the killcam must not touch the timeline.
	if not _killcam_timeline_active():
		print("KILLCAM neutral skip=%s victim=%d author=%d" % [_killcam_skip_reason(), victim, killer.author_index if killer != null else -1])
		_slow_mo()
		return

	_start_killcam(victim, death_pos, border_color, show_border, banner_text)

## The killcam pauses/holds only when it can be seen AND won't corrupt a
## determinism diff. When this is false the death path stays a pure no-op on the
## physics timeline (identical to --nokillcam), so autoplay/headless receipts hold.
func _killcam_timeline_active() -> bool:
	if _nokillcam:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	if VerifyCapture.autobuild or not VerifyCapture.autoplay.is_empty():
		return false
	return true

func _killcam_skip_reason() -> String:
	if _nokillcam:
		return "nokillcam"
	if DisplayServer.get_name() == "headless":
		return "headless"
	if VerifyCapture.autobuild or not VerifyCapture.autoplay.is_empty():
		return "autoplay"
	return "none"

## A bot-only match (all seats bots, or --parbots) auto-skips the killcam fast so
## soaks/demos never drag.
func _is_bot_only_match() -> bool:
	if _par_bot_all:
		return true
	for i in GameState.players.size():
		if not PlayerInput.is_bot(i):
			return false
	return true

## Freeze the table and hand the victim's recorded final motion to the killcam.
## The pause holds round_manager (no turn advance, no next putt) until the replay
## ends; because the tree is paused, ZERO physics steps elapse — the moving traps
## resume at the exact phase they were frozen at, so outcomes are unchanged.
func _start_killcam(victim: int, death_pos: Vector3, border_color: Color, show_border: bool, banner_text: String) -> void:
	var vb: Ball = balls[victim]
	var samples: Array = vb.get_replay_samples(2.0)
	var approach := Vector3.ZERO
	if samples.size() >= 2:
		var last: Transform3D = samples[samples.size() - 1]
		var earlier: Transform3D = samples[maxi(0, samples.size() - 10)]
		approach = last.origin - earlier.origin
	# Hide the real (dead) ball so only the replay clone shows during the freeze.
	vb.visible = false
	var ball_color: Color = GameState.players[victim].color
	var restore_cam: Camera3D = camera_rig.get_node("Camera3D")
	get_tree().paused = true
	_killcam_t0 = Time.get_ticks_msec()
	print("KILLCAM play victim=%d samples=%d dur=%.2f botonly=%s" % [victim, samples.size(), KILLCAM_DURATION, str(_is_bot_only_match())])
	_killcam.play(samples, death_pos, approach, ball_color, border_color, show_border, banner_text, KILLCAM_DURATION, _is_bot_only_match(), restore_cam)

func _on_killcam_finished() -> void:
	get_tree().paused = false
	print("KILLCAM done held_ms=%d" % (Time.get_ticks_msec() - _killcam_t0))

func _spawn_death_fx(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	# Keep bursting while a killcam has the table paused, so the splat reads.
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.global_position = pos + Vector3(0, 0.15, 0)
	p.emitting = false
	p.one_shot = true
	p.amount = 28
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.6
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _spawn_gravestone(pos: Vector3, color: Color) -> void:
	var g := GRAVESTONE_SCENE.instantiate()
	course.get_node("GravestoneContainer").add_child(g)
	g.global_position = course.clamp_gravestone(pos)
	g.rotation_degrees.y = GameState.rng.randf_range(-25.0, 25.0)
	g.setup(color, GameState.round_num)

func _on_ball_resolved(p: int, status: String) -> void:
	if status == "dnf":
		GameState.players[p].grudge += 1
		_flash_banner("%s IS OUT OF STROKES" % GameState.players[p].name, Color(0.7, 0.7, 0.7), 1.4)

func _on_round_finished(finish_order: Array, _strokes: Dictionary) -> void:
	phase = Phase.BETWEEN
	camera_rig.set_mode(camera_rig.Mode.DIORAMA)
	GameState.award_round_points(finish_order)
	_rebuild_scoreboard()
	GameState.round_num += 1
	if GameState.is_match_over():
		var champ: int = GameState.standings()[0]
		print("MATCH_OVER champ=", GameState.players[champ].name)
		var points := {}
		var monuments: Array = []
		for i in GameState.players.size():
			points[i] = GameState.players[i].score
			if GameState.players[i].royalties >= 6:
				monuments.append({"player": i, "kind": "butcher", "label": "%s, Architect of Ruin" % GameState.players[i].name})
		print("KILL_EVENTS n=", _kill_events.size(), " ", _kill_events)
		# Determinism receipt: killcam is presentation-only, so this line must be
		# byte-identical across killcam-on / --nokillcam runs of the same seed.
		print("FINAL_RESULT placements=%s points=%s" % [str(GameState.standings()), str(points)])
		var results := {
			"placements": GameState.standings(),
			"points": points,
			"currency_events": _currency_log.duplicate(),
			"kill_events": _kill_events.duplicate(),
			"highlights": _highlights.slice(0, 3),
			"monuments": monuments,
		}
		if _par_quit:
			finished.emit(results)
			get_tree().quit()
			return
		_stop_chaos_turn_banner()
		turn_label.text = ""
		stroke_label.text = ""
		round_label.text = "FINAL"
		_flash_banner("THE COURSE REMEMBERS", Color(1, 0.85, 0.2), 8.0)
		var tw: Tween = camera_rig.start_flyover(8.5)
		await tw.finished
		print("FLYOVER_DONE")
		Sfx.play("match_win")
		avatars[champ].react("Cheer")
		_spawn_confetti(avatars[champ].global_position + Vector3(0, 1.5, 0), GameState.players[champ].color)
		_flash_banner("%s WINS THE MATCH!\n(press R for a rematch)" % GameState.players[champ].name, GameState.players[champ].color, 9999.0)
		finished.emit(results)
		return
	Sfx.play("round_over")
	_flash_banner("ROUND OVER", Color(1, 0.85, 0.2), 2.6)
	await get_tree().create_timer(3.0).timeout
	_start_round()

func _flash_banner(text: String, color: Color, duration: float) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.55, 0.55)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func(): banner.visible = false)

func _spawn_confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 16
		p.lifetime = 1.1
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -7.0, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.02, 0.07)
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	for i in GameState.standings():
		var player = GameState.players[i]
		# Shape+color identity chip (never-color-alone), matching every other
		# game's scoreboard: PlayerBadge left of the name.
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(i, 24)
		badge.color = player.color
		hb.add_child(badge)
		var row := Label.new()
		var extras := ""
		if player.royalties > 0:
			extras += "  †%d" % player.royalties
		if player.grudge > 0:
			extras += "  ♠%d" % player.grudge
		row.text = "%s  %d%s" % [player.name, player.score, extras]
		row.add_theme_font_size_override("font_size", 26)
		row.add_theme_color_override("font_color", player.color)
		hb.add_child(row)
		score_rows.add_child(hb)

func is_turn_ready() -> bool:
	return phase == Phase.PUTT and round_manager.is_turn_ready()

## --swingplay harness gate: the turn is open AND the acting avatar holds the
## address stance, so an auto swing can be queued through the embodied path.
func is_swing_ready() -> bool:
	return is_turn_ready() and _embodied and avatar_shot.is_addressed(round_manager.current_player())

## --swingplay: fire this exact (power, angle) through walk->address->charge->
## swing-contact. Numbers pass through UNTOUCHED (the byte-identical receipt).
func begin_auto_swing(power: float, angle_deg: float) -> bool:
	return avatar_shot.auto_swing(power, angle_deg)

func debug_pick_card(i: int) -> void:
	if phase == Phase.DRAFT:
		_on_card_picked(mini(i, current_hand.size() - 1))

func debug_place_auto() -> void:
	if phase != Phase.BUILD or not placement.active:
		return
	var rot := float((autobuild_count * 45) % 180)
	autobuild_count += 1
	if not placement.debug_place_scan(rot, GameState.rng):
		# Saturated: bail on this placement and move the build along.
		placement.cancel()
		build_hint.visible = false
		_advance_after_placement()

# --- minimal per-player bot ----------------------------------------------------
func _is_bot(i: int) -> bool:
	return _par_bot_all or (i >= 0 and PlayerInput.is_bot(i))

## Drives whichever seat currently owns the turn, if that seat is a bot. Fires
## once per actionable turn after a short think delay; a human seat is skipped
## (its mouse input flows normally). Chaos rounds have no draft/build, so only
## the PUTT branch runs there.
func _bot_tick(delta: float) -> void:
	var actor := -1
	match phase:
		Phase.DRAFT:
			if draft_pointer < draft_order.size():
				actor = draft_order[draft_pointer]
		Phase.BUILD:
			if placement.active and draft_pointer < draft_order.size():
				actor = draft_order[draft_pointer]
		Phase.PUTT:
			if round_manager.is_turn_ready():
				actor = round_manager.current_player()
	if actor < 0 or not _is_bot(actor):
		_bot_ctx = ""
		_bot_think_t = 0.0
		return
	# ctx changes whenever the actionable turn changes; the stroke count keeps
	# successive putts by the same bot (in one turn) as distinct think windows
	var ctx := "%d:%d" % [phase, actor]
	if phase == Phase.PUTT:
		ctx += ":%d" % int(round_manager.strokes.get(actor, 0))
	if ctx != _bot_ctx:
		_bot_ctx = ctx
		_bot_think_t = 0.0
	_bot_think_t += delta
	match phase:
		Phase.DRAFT:
			if _bot_think_t >= 1.0:
				debug_pick_card(0)          # pick the first offered card
		Phase.BUILD:
			if _bot_think_t >= 1.0:
				_bot_build()
		Phase.PUTT:
			# v4 walk layer: the bot's avatar must ARRIVE at its ball before the
			# think clock starts (spec: cadence counts from arrival). While it
			# walks, keep resetting the timer. If the embodied machine is NOT
			# running this shot (begin_turn declined — e.g. the ball died between
			# rounds), fall through to the v3 direct path so the turn resolves.
			if _embodied and avatar_shot.is_pending(actor) and not avatar_shot.is_addressed(actor):
				_bot_think_t = 0.0
				return
			# CHAOS: fire the instant the turn opens and DON'T wait for the ball to
			# settle — that's what keeps several balls live at once. NORMAL: the
			# old calm turn-based cadence (think a beat, wait for rest).
			if GameState.is_chaos_round():
				if _bot_think_t >= 0.2:
					_bot_putt(actor)
			elif _bot_think_t >= 1.5 and balls[actor].is_stopped():
				_bot_putt(actor)

func _bot_build() -> void:
	if phase != Phase.BUILD or not placement.active:
		return
	var rot := _bot_rng.randf_range(0.0, 360.0)
	if not placement.debug_place_scan(rot, GameState.rng):
		# course saturated for this footprint: skip the placement, move on
		placement.cancel()
		build_hint.visible = false
		_advance_after_placement()

## Aim straight at the cup with a little noise; power scales with distance.
## Routed through the existing debug_putt entry point (no putt-feel constants
## touched). angle 0 = -Z; debug_putt does dir = (0,0,-1).rotated(UP, angle).
func _bot_putt(actor: int) -> void:
	var b: Ball = balls[actor]
	var cup := course.cup_position()
	var to := cup - b.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.001 else Vector3(0, 0, -1)
	var angle := rad_to_deg(atan2(-dir.x, -dir.z)) + _bot_rng.randf_range(-4.0, 4.0)
	var power := clampf(dist * 0.5 + _bot_rng.randf_range(0.0, 1.0), 2.0, 13.0)
	putt_controller.ball = b
	# v4: the same seeded numbers, fired through the swing's contact frame. The
	# rng draw count per stroke is unchanged, so --parbots stays reproducible.
	if _embodied and avatar_shot.bot_swing(power, angle):
		return
	putt_controller.debug_putt(power, angle)

func get_phase_name() -> String:
	return Phase.keys()[phase]

# --- KILLCAM screenshot harness (--killcamtest=signed|self|chaos) --------------
## Drives any draft/build to completion, then stages a controlled kill on ball 0
## so the killcam (signed/self) or the chaos credit banner can be captured
## deterministically. Verification-only; never runs in normal play.
func _run_killcam_test(mode: String) -> void:
	var guard := 0
	while (phase == Phase.DRAFT or phase == Phase.BUILD) and guard < 400:
		guard += 1
		if phase == Phase.DRAFT:
			debug_pick_card(0)
		elif phase == Phase.BUILD:
			debug_place_auto()
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.3).timeout
	await _stage_kill("signed" if mode == "skip" else mode)
	if mode == "skip":
		# Prove player-skip: inject a SPACE press mid-replay; the killcam must end
		# early (held_ms far below the 1600ms cap).
		await get_tree().create_timer(0.25, true, false, true).timeout
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		ev.keycode = KEY_SPACE
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.4, true, false, true).timeout
		get_tree().quit()
		return
	# Snap late in the replay (ball has arrived at the trap) while the killcam
	# still holds the table paused (process_always timer keeps ticking).
	await get_tree().create_timer(1.05, true, false, true).timeout
	VerifyCapture.snap("killcam_%s" % mode)
	# Let the replay finish naturally so the hard-cap held_ms is logged too.
	await get_tree().create_timer(0.75, true, false, true).timeout
	get_tree().quit()

func _stage_kill(mode: String) -> void:
	var vb: Ball = balls[0]
	var crusher: Trap = TrapCatalog.load_scene("crusher").instantiate()
	course.get_node("TrapContainer").add_child(crusher)
	var kill_at: Vector3 = vb.global_position + Vector3(0, 0, -2.0)
	crusher.global_position = Vector3(kill_at.x, 0.0, kill_at.z)
	if mode == "self":
		crusher.set_author(0, GameState.players[0].color)
	else:
		crusher.set_author(1, GameState.players[1].color)
	crusher.solidify()
	putt_controller.ball = vb
	putt_controller.debug_putt(6.0, 0.0)          # angle 0 = -Z, straight at the trap
	await get_tree().create_timer(0.85).timeout
	# In real play the ball dies AT the trap; stage that here so the low camera
	# frames both the crusher and the incoming ball.
	crusher.global_position = Vector3(vb.global_position.x, 0.0, vb.global_position.z)
	if crusher.has_node("Hammer"):
		crusher.get_node("Hammer").position.y = 0.28   # freeze the hammer mid-slam
	vb.die(crusher)
