extends Minigame
## SWAP MEET - anthology minigame (module contract: core/minigame.gd).
## A bumper-kart race where NOTHING does damage - every orb hit SWAPS
## your position with the victim's (position + velocity + progress,
## atomically). First place is a bullseye you wear: the leader gets a
## crown, and the golden orb pickup swaps its holder with the CURRENT
## LEADER from anywhere.
##
## Controls (PlayerInput): move.x steer, auto-throttle forward, move.y
## (pull back) brake/reverse. A uses a held item first, otherwise throws a
## collected swap orb. B holds drift; release cashes the charged boost.
## Human seats render through ViewportKit chase views; bots never get a view.
##
## Standalone: if the shell hasn't called begin() within 0.5s, the game
## begins itself with a default roster from GameState consts, KayKit
## chars seated on karts, seed from --seed or 1.
##
## CLI user args (after --):
##   --seed=N        rng seed for the default config (default 1)
##   --players=N     default roster size 2..4 (default 4)
##   --swapbots      seeded self-play bots on every seat
##   --fast=K        Engine.time_scale multiplier (mutes audio; dt stays
##                   exactly 1/60 - see orbital's determinism notes)
##   --autoquit      quit after the results report / test verdict
##   --laps=N        override 3 laps
##   --itemdensity=N item-box/orb-pickup density multiplier (default 1.0)
##   --swaptally     deterministic all-bot soak receipt (pair with --seed=N)
##   --timecap=N     override the 170s play / 240s --swaptally race cap
##   --swaptest=immunity   scripted orb drops prove 1s swap immunity
##   --swaptest=moment     two parked karts + one throw: the swap money shot
##   --shotsec=a,b,..      capture PNGs at these WALL-clock seconds
##   --shots=N,...         (VerifyCapture autoload) PNGs at frame indices
## All gameplay randomness comes from config.rng_seed. No physics bodies:
## karts, orbs, walls and hazards are hand-integrated each tick.

enum Phase { WAIT, INTRO, PLAY, END }

const KAYKIT_CHARS := ["Barbarian", "Knight", "Mage", "Rogue"]
const LAPS_DEFAULT := 3
const RACE_CAP := 170.0
const SOAK_RACE_CAP: float = 240.0
const FINISH_PTS := [5, 3, 2, 1]
const ORB_CD := 3.0
const SWAP_IMMUNITY := 1.0
const FREEZE_TICKS := 5          # 0.083s hit-stop on every swap
const PHOTO_FREEZE_TICKS := 10   # doc 09 §7.1: 10-tick line freeze on a photo finish
const PHOTO_MARGIN_UNITS := 1.2  # doc 09 §7.1: arm only when P2 is within 1.2 progress-units
const OVERTAKE_STING_CD := 1.5   # throttle so drafting duels don't machine-gun the sting
const GOLD_EVERY := 40.0
const GOLD_SPOT_FRACS := [0.16, 0.38, 0.60, 0.84]
const BOOM_LEN := 7.8
const BOOM_SPEED := 0.72
const KNOCK_POWER := 7.0
const KART_R := 0.55
const CAM_POS := Vector3(-5.0, 82.0, 62.0)
const CAM_LOOK := Vector3(-6.0, 0, 5.0)
const CAM_FOV := 52.0
const CHASE_FOV := 60.0
const ITEM_SWAP_SHELL: int = 0
const ITEM_COFFIN: int = 1
const ITEM_BELL: int = 2
const ITEM_CROWS: int = 3
const ITEM_NONE: int = -1
const ITEM_NAMES: Array[String] = ["SWAP-SHELL", "PALLBEARER'S COFFIN", "THE BELL", "CROW MURDER"]
const ITEM_COLORS: Array[Color] = [
	Color(0.18, 1.0, 0.68), Color(0.72, 0.25, 1.0),
	Color(1.0, 0.72, 0.12), Color(0.3, 0.18, 0.45),
]
const EDGE_BOX_COLORS: Array[Color] = [
	Color(1.0, 0.18, 0.5), Color(0.1, 0.9, 1.0),
	Color(0.75, 1.0, 0.12), Color(1.0, 0.62, 0.08),
]
const BASE_ITEM_BOXES: int = 12
const BASE_ORB_PICKUPS: int = 6
const PICKUP_RESPAWN: float = 5.0
const BELL_DURATION: float = 2.5
const CROW_DURATION: float = 3.0
const MAX_COFFINS_PER_SEAT: int = 3
const MAX_COFFINS_GLOBAL: int = 6
const SLIPSTREAM_GAP_SECONDS: float = 12.0
const SLIPSTREAM_SPEED_MULT: float = 1.08
const NET_KART_STRIDE: int = 17

var config: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var phase: int = Phase.WAIT
var now: float = 0.0                   # sim clock (stops during hit-stop)
var race_t: float = 0.0                # race clock (starts at GO)
var laps_total: int = LAPS_DEFAULT
var time_cap: float = RACE_CAP
var item_density: float = 1.0

var track: SwapTrack
var karts: Array = []            # SwapKart, array pos == player index
var bots: Array = []             # per player index: SwapBot or null (human seat)
var bot_enabled: Array = []      # per player index: bool, decided at begin()
var orbs: Array = []
var bots_enabled: bool = false        # legacy --swapbots flag: force ALL seats to bots

## MK64-style pickup layer. Records are dictionaries because both host and
## render mirror share the same compact visibility sync.
var _item_boxes: Array[Dictionary] = []
var _orb_pickups: Array[Dictionary] = []
var _coffins: Array[Dictionary] = []
var _coffin_serial: int = 0
var _item_stats: Dictionary = {"boxes": 0, "shells": 0, "coffins": 0, "bells": 0, "crows": 0}

## Human-only chase views. ViewportKit owns every SubViewport/camera; this
## module only stores seat -> kit id and asks the kit to pose/display them.
var _viewport_kit: ViewportKit = null
var _view_ids: Dictionary = {}
var _view_rects: Dictionary = {}
var _view_size: Vector2 = Vector2.ZERO
var _split_back: ColorRect = null
var _crow_mask: Control = null

var _points: Dictionary = {}
var _currency: Array = []
var _kill_events: Array = []     # {killer:int, victim:int, cause:String}; a swap heist "wrecks" the victim's race
var _names: Array = []
var _colors: Array = []
var _finish_count: int = 0
var _swaps_total: int = 0
var _swaps_blocked: int = 0
var _golden_swaps: int = 0
var _gaining_swaps: Dictionary = {}         # player -> count (thrower gained >=1)
var _gold_victims: Dictionary = {}          # player -> times golden-orbed
var _cruel_delta: int = 0
var _cruel_txt: String = ""
var _bounces: int = 0
var _reported: bool = false

var _intro_t: float = 0.0
var _intro_stage: int = -1
var _freeze_ticks: int = 0

var _stuck_test: bool = false          # dev --swapstuck: jam kart 0 to film the unstick
var _stuck_fired: bool = false
var _stuck_cap_delay: int = 8
var _stuck_captured: bool = false
var _gold_t: float = 0.0
var _gold_pickup: Node3D = null
var _gold_spot: Vector3 = Vector3.ZERO
var _booms: Array = []           # {pivot: Node3D, pos, angle, speed, glb_blades}
var _crown: Node3D = null
var _crown_on: int = -1
var _final_lap_called: bool = false
var _end_t: float = -1.0
# THE FINAL STRETCH kit (doc 09 §Q1/§7.3): the FINAL LAP is swap's stretch —
# tense music + the lighting nudge at the call, and a distance-driven tick
# ladder once the leader enters the last 10%. No lap timer, so no timer-label
# pulse. Never attached under --swaptest, so scripted receipts hold.
var _stretch: FinalStretch = null

var _begun: bool = false
var _cli_seed: int = 1
var _cli_players: int = 4
var _fast: float = 1.0
var _autoquit: bool = false
var _swaptally: bool = false
var _swaptally_next_pos_t: float = 10.0
var _time_cap_explicit: bool = false
var _test_mode: String = ""
var _test_stage: int = 0
var _shotsec: Array = []
var _vis_t: float = 0.0
var _shot_i: int = 0
var _shake: float = 0.0

var _cam: Camera3D
var _fx_root: Node3D
var _banner: RichTextLabel
var _event_label: Label
var _timer_label: Label
var _lap_label: Label
var _hint_label: Label
var _score_rows: VBoxContainer
var _row_labels: Array = []
var _event_until: float = 0.0
var _banner_gen: int = 0

# --- overtake sting + photo finish (doc 09 §7.1-2, presentation only) ---
var _sting_player: AudioStreamPlayer = null   # dedicated pitched 'sink' = lead-change identity
var _overtake_next: float = 0.0                      # sim-clock gate for the sting cooldown
var _crown_flash_tw: Tween = null
var _flash_rect: ColorRect = null              # flashbulb overlay (paparazzi frame)
var _photofin: bool = false                         # verify demo: forced close finish
var _photo_shots: bool = false                      # capture the photo-finish frames (demo)

# --- ONLINE PHASE 2 (docs/design/10 §4.3): the render mirror -----------------
# House pattern (online-seance-VERIFY.md PATTERN NOTES): host runs this ENTIRE
# sim exactly as couch; the estate pumps _net_state() at 20 Hz. The client
# boots this same scene with config.net_mirror = true — karts, orbs, crown,
# gold pickup and booms are rendered from facts, interpolated at 60 Hz
# (racing NEEDS smooth). Every ritual (SWAP beams, PHOTO FINISH freeze-flash,
# overtake sting, knocks) fires from counter deltas; banners/event lines ride
# as [gen, text] and replay the couch's own flashers. No hidden info anywhere.
var _mirror: bool = false
var _netdemo: bool = false                # --swapnetdemo: probe rig, stages a 1-lap
                                     # photo dash between the two bots at GO
var _netdemo_fire_t: float = -1.0          # sim-clock time of the rig's one scripted
                                     # orb drop (0 -> 1), the guaranteed SWAP beat
var _mir: Dictionary = {}                       # last applied snapshot (delta source)
var _net_oid: int = 0                    # host: orb wire ids
var _net_ban: Array = [0, "", 0.0]         # host: [banner gen, bbcode, duration]
var _net_ev_gen: int = 0                 # host: event-line gen
var _net_ev: Array = [0, "", "ffffff"]     # host: [gen, text, color]
var _net_swap: Array = [0, 0, 0, 0, Vector3.ZERO, Vector3.ZERO]  # [n, a, b, golden, posA, posB]
var _net_pf: Array = [0, -1, -1, 0.0]      # [n, winner, chaser, est_delta]
var _net_knock: Array = [0, -1]            # [n, victim] windmill boom hits
var _net_bounce: Array = [0, -1]           # [n, kart] wall thuds (latest per snap)
var _net_gp: Array = [0, 0, "ffffff"]      # [n, gate idx, color] scoring-gate pulses
var _net_gc: Array = [0, -1]               # [n, claimant] golden-orb claims
var _net_ov: int = 0                     # overtake stings
var _net_champ: int = -1                 # pre-announced at END, 1.8 s before finished()
var _net_snapped: Dictionary = {}    # host-side probe evidence latches
# client mirror scratch
var _mir_karts: Array = []           # per kart [pos target, yaw target]
var _mir_orbs: Dictionary = {}       # oid -> {"node", "pos"}
var _mir_coffins: Dictionary = {}    # coffin id -> {"node", "pos", "yaw"}
var _mir_snapped: Dictionary = {}    # mirror-side probe evidence latches

func _ready() -> void:
	_parse_args()
	_build_static()
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if not _begun:
			begin(_default_config()))

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--swapbots":
			bots_enabled = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--fast="):
			_fast = clampf(float(arg.trim_prefix("--fast=")), 1.0, 30.0)
		elif arg == "--autoquit":
			_autoquit = true
		elif arg.begins_with("--laps="):
			laps_total = clampi(int(arg.trim_prefix("--laps=")), 1, 9)
		elif arg.begins_with("--timecap="):
			time_cap = float(arg.trim_prefix("--timecap="))
			_time_cap_explicit = true
		elif arg.begins_with("--itemdensity="):
			item_density = clampf(float(arg.trim_prefix("--itemdensity=")), 0.25, 2.0)
		elif arg == "--swaptally":
			_swaptally = true
			bots_enabled = true
			_autoquit = true
		elif arg.begins_with("--swaptest="):
			_test_mode = arg.trim_prefix("--swaptest=")
		elif arg == "--photofin":
			# verify demo: two bot karts staged a hair apart on the final
			# approach so a genuine photo finish fires through the real path
			_photofin = true
			_photo_shots = true
			bots_enabled = true
		elif arg.begins_with("--shotsec="):
			for s in arg.trim_prefix("--shotsec=").split(","):
				_shotsec.append(float(s))
		elif arg == "--swapnetdemo":
			# ONLINE probe rig: at GO, restage as a 1-lap dash whose two BOT
			# karts start a hair apart on the final approach — the real
			# _finish_kart path then fires a genuine PHOTO FINISH across the
			# wire. Probe-only; receipts never pass it.
			_netdemo = true
		elif arg == "--swapstuck":
			# dev: jam kart 0 on the ramp (near-zero speed, input held) to prove
			# the anti-trap unstick fires. Films swap_unstick.png and quits.
			_stuck_test = true
			bots_enabled = true
	if _swaptally and not _time_cap_explicit:
		time_cap = SOAK_RACE_CAP
	if _swaptally and _fast <= 1.01:
		_fast = 8.0
	if _fast > 1.01:
		# Faster-than-realtime with dt pinned to exactly 1/60 (the sim is
		# tick-identical to live play): scale BOTH time_scale and tick rate.
		Engine.time_scale = _fast
		Engine.physics_ticks_per_second = int(60.0 * _fast)
		Engine.max_physics_steps_per_frame = maxi(8, int(60.0 * _fast))
		AudioServer.set_bus_mute(0, true)

func _default_config() -> Dictionary:
	PlayerInput.auto_assign(_cli_players)
	var roster: Array = []
	for i in _cli_players:
		roster.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": "res://assets/models/kaykit/%s.glb" % KAYKIT_CHARS[i],
			"device": PlayerInput.device_of(i),
			"bot": PlayerInput.standalone_bot_default(i),
		})
	return {"roster": roster, "rounds": 1, "rng_seed": _cli_seed, "practice": false,
		"laps": laps_total, "item_density": item_density}

func begin(cfg: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	config = cfg
	_mirror = bool(cfg.get("net_mirror", false))
	var seed_value: int = int(cfg.get("rng_seed", 1))
	rng.seed = seed_value
	laps_total = clampi(int(cfg.get("laps", laps_total)), 1, 9)
	item_density = clampf(float(cfg.get("item_density", item_density)), 0.25, 2.0)
	if cfg.get("practice", false):
		laps_total = mini(laps_total, 2)
	var roster: Array = cfg.get("roster", [])
	for pl in roster:
		var idx: int = pl.index
		_names.resize(maxi(_names.size(), idx + 1))
		_colors.resize(maxi(_colors.size(), idx + 1))
		_names[idx] = pl.name
		_colors[idx] = pl.color
		_points[idx] = 0
		_gaining_swaps[idx] = 0
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var kart: SwapKart = SwapKart.new()
		kart.world = self
		kart.track = track
		kart.index = pl.index
		add_child(kart)
		kart.setup(load(String(pl.char_scene)), pl.color, pl.name)
		# staggered grid just before the finish line
		var row: int = i / 2
		var col: int = i % 2
		kart.place_at(track.total_len - 2.2 - row * 1.9, -1.05 + 2.1 * col)
		karts.append(kart)
	# Per-player bots: a seat is bot-driven if the roster marks it a bot (shell
	# sets it from estate._is_bot; standalone from PlayerInput) OR the legacy
	# --swapbots flag forces ALL bots. Human seats get a null slot and read
	# PlayerInput. Seeds are per index, so the all-bots path is bit-identical to
	# before. Scripted --swaptest modes park the karts - no bot brains there.
	bot_enabled.resize(roster.size())
	bots.resize(roster.size())
	for i in roster.size():
		var roster_entry: Dictionary = roster[i]
		var device: int = int(roster_entry.get("device", -99))
		var empty_seat_bot: bool = device == -3 or device == -99
		var roster_bot: bool = bool(roster_entry.get("bot", empty_seat_bot))
		bot_enabled[i] = bots_enabled or roster_bot
		if bot_enabled[i] and _test_mode == "" and not _mirror:
			var bot: SwapBot = SwapBot.new()
			bot.setup(self, i, seed_value * 977 + i * 131)
			bots[i] = bot
	# Personalize the persistent hint bar with each human seat's REAL keys, once
	# per match now that the roster/bot map is known (docs/verify/realkeys-VERIFY.md).
	if _hint_label != null:
		_hint_label.text = _controls_bar()
	_build_crown()
	_build_pickups()
	_setup_player_views()
	if _test_mode == "":
		_stretch = FinalStretch.attach(self, null)
	if _mirror:
		# RENDER MIRROR: karts/crown/track stand ready; no bots, no countdown,
		# no sim — the first _net_apply drives every fact.
		phase = Phase.WAIT
		for k in karts:
			(k as SwapKart).locked = true
			_mir_karts.append([(k as SwapKart).global_position, 0.0])
		_update_score_rows()
		print("SWAP_MIRROR boot players=%d my_seat=%d" % [karts.size(), NetSession.my_seat()])
		return
	if _test_mode != "":
		_setup_test()
		return
	if _photofin:
		_setup_photofin()
		return
	phase = Phase.INTRO
	_intro_t = 0.0
	_intro_stage = -1
	_update_score_rows()

## --- static world -------------------------------------------------------------

func _build_static() -> void:
	_cam = Camera3D.new()
	_cam.position = CAM_POS
	_cam.fov = CAM_FOV
	add_child(_cam)
	_cam.look_at(CAM_LOOK)
	_cam.current = true
	_viewport_kit = ViewportKit.new()
	_viewport_kit.name = "PlayerViewportKit"
	add_child(_viewport_kit)
	_viewport_kit.setup(-1)
	var back_layer: CanvasLayer = CanvasLayer.new()
	back_layer.layer = -2
	add_child(back_layer)
	_split_back = ColorRect.new()
	_split_back.color = Color(0.015, 0.018, 0.035)
	_split_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split_back.visible = false
	back_layer.add_child(_split_back)
	_build_crow_mask()
	# THE HOUSE LOOK -- MOONLIT night market (core/env_kit.gd). The kart race runs
	# after dark: a cool moon key rakes the track, a strong WARM fill stands in for
	# the market's lamp strings, thin ground fog gives the far side depth, and the
	# high-threshold glow blooms the swap-orb + boost trails without touching the
	# UI. Replaces the old flat FILMIC day-env + hand-rolled sun.
	var rig: Dictionary = EnvKit.apply(self, EnvKit.MOONLIT, {
		"key_energy": 1.15,      # a touch brighter so asphalt + rumble strips read
		"fill_energy": 0.42,     # warm market-lamp fill washing the whole track
		"fog_density": 0.006,    # thin -- keep the far side of the track legible
	})
	# the track is large: keep the old shadow throw so karts cast across it
	(rig["key"] as DirectionalLight3D).directional_shadow_max_distance = 140.0
	track = SwapTrack.new()
	add_child(track)
	track.build()
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_build_booms()
	_build_ui()
	_build_sting_player()

func _build_crow_mask() -> void:
	var crow_layer: CanvasLayer = CanvasLayer.new()
	crow_layer.layer = 0
	add_child(crow_layer)
	_crow_mask = Control.new()
	_crow_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crow_mask.visible = false
	crow_layer.add_child(_crow_mask)
	for rect_data: Array in [
		[Vector2(0.0, 0.0), Vector2(1.0, 0.20)],
		[Vector2(0.0, 0.20), Vector2(0.15, 0.80)],
		[Vector2(0.82, 0.32), Vector2(0.18, 0.68)],
	]:
		var anchor_pos: Vector2 = Vector2(rect_data[0])
		var anchor_size: Vector2 = Vector2(rect_data[1])
		var veil: ColorRect = ColorRect.new()
		veil.color = Color(0.015, 0.008, 0.03, 0.56)
		veil.anchor_left = anchor_pos.x
		veil.anchor_top = anchor_pos.y
		veil.anchor_right = veil.anchor_left + anchor_size.x
		veil.anchor_bottom = veil.anchor_top + anchor_size.y
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crow_mask.add_child(veil)
	var label: Label = Label.new()
	label.text = "CROW MURDER\nCAW!  CAW!  CAW!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_override("font", load("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.7, 0.45, 1.0, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.0, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crow_mask.add_child(label)

func _setup_player_views() -> void:
	if _viewport_kit == null:
		return
	var human_seats: Array[int] = []
	for i: int in karts.size():
		if i < bot_enabled.size() and not bool(bot_enabled[i]):
			human_seats.append(i)
	if human_seats.is_empty():
		_cam.current = true
		_split_back.visible = false
		return
	_cam.current = false
	_split_back.visible = true
	_view_size = get_viewport().get_visible_rect().size
	var rects: Array[Rect2] = _split_rects(human_seats.size(), _view_size)
	for i: int in human_seats.size():
		var seat: int = human_seats[i]
		var rect: Rect2 = rects[i]
		var view_id: int = _viewport_kit.add_view({
			"world": get_viewport().find_world_3d(), "res_scale": 1.0,
			"far": 180.0, "near": 0.08, "fov": CHASE_FOV,
			"cull_mask": 0, "shadow_atlas": 1024, "cadence": 1,
			"rect": rect, "msaa": Viewport.MSAA_2X,
		})
		if view_id < 0:
			continue
		_view_ids[seat] = view_id
		_view_rects[seat] = rect
		var kart: SwapKart = karts[seat]
		var desired: Vector3 = kart.center() - kart.heading * 7.5 + Vector3.UP * 4.2
		_viewport_kit.aim_view(view_id, desired, kart.center() + kart.heading * 3.0)

func _split_rects(count: int, size: Vector2) -> Array[Rect2]:
	var gap: float = 3.0
	if count <= 1:
		return [Rect2(Vector2.ZERO, size)]
	if count == 2:
		var half_h: float = (size.y - gap) * 0.5
		return [Rect2(0, 0, size.x, half_h), Rect2(0, half_h + gap, size.x, half_h)]
	var half_w: float = (size.x - gap) * 0.5
	var half_h: float = (size.y - gap) * 0.5
	var rects: Array[Rect2] = [
		Rect2(0, 0, half_w, half_h), Rect2(half_w + gap, 0, half_w, half_h),
		Rect2(0, half_h + gap, half_w, half_h),
	]
	if count >= 4:
		rects.append(Rect2(half_w + gap, half_h + gap, half_w, half_h))
	return rects

func _layout_player_views() -> void:
	if _view_ids.is_empty():
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	if size.is_equal_approx(_view_size):
		return
	_view_size = size
	var seats: Array = _view_ids.keys()
	seats.sort()
	var rects: Array[Rect2] = _split_rects(seats.size(), size)
	for i: int in seats.size():
		var seat: int = int(seats[i])
		var view_id: int = int(_view_ids.get(seat, -1))
		var rect: Rect2 = rects[i]
		_view_rects[seat] = rect
		_viewport_kit.set_display_rect(view_id, rect)

func _update_chase_views(delta: float) -> void:
	if _view_ids.is_empty():
		return
	_layout_player_views()
	for seat_value in _view_ids.keys():
		var seat: int = int(seat_value)
		if seat < 0 or seat >= karts.size():
			continue
		var view_id: int = int(_view_ids.get(seat, -1))
		var kart: SwapKart = karts[seat]
		var right: Vector3 = kart.heading.cross(Vector3.UP).normalized()
		var drift_offset: float = kart.steer * (0.7 if kart.drifting else 0.25)
		var desired: Vector3 = kart.center() - kart.heading * 7.6 + Vector3.UP * 4.25 + right * drift_offset
		var look: Vector3 = kart.center() + kart.heading * 3.1 + Vector3.UP * 0.45
		var camera: Camera3D = _viewport_kit.view_camera(view_id)
		if camera == null:
			continue
		var blend: float = 1.0 - exp(-9.0 * delta)
		var camera_pos: Vector3 = camera.global_position.lerp(desired, blend)
		_viewport_kit.aim_view(view_id, camera_pos, look)
		var lean: float = -kart.steer * (0.045 if kart.drifting else 0.018)
		camera.rotation.z = lerp_angle(camera.rotation.z, lean, 1.0 - exp(-7.0 * delta))
	_update_crow_mask()

func _update_crow_mask() -> void:
	if _crow_mask == null:
		return
	var target: int = leader_unfinished()
	if target < 0 or target >= karts.size() or (karts[target] as SwapKart).crow_t <= 0.0 \
			or not _view_rects.has(target):
		_crow_mask.visible = false
		return
	var rect: Rect2 = _view_rects.get(target, Rect2())
	_crow_mask.position = rect.position
	_crow_mask.size = rect.size
	_crow_mask.visible = true

## A dedicated one-shot for the overtake sting: the same 'sink' asset the
## Sfx bank uses, but pitched up to 1.3 (doc 09 §7.2) so a lead change has
## its own audio identity, distinct from the swap's own 1.0-pitch sink.
func _build_sting_player() -> void:
	_sting_player = AudioStreamPlayer.new()
	_sting_player.bus = "SFX"
	var key: String = Sfx.BANK["sink"][0]
	_sting_player.stream = load("res://assets/audio/%s.ogg" % key)
	add_child(_sting_player)

## Windmill boom hazards at the two pinch points: a candy-striped arm
## sweeps across the track; getting clipped knocks you sideways
## (non-lethal). The Par windmill model stands at each pivot for flavor.
func _build_booms() -> void:
	var gate: Dictionary = track.windmill_gate()
	var center: Vector3 = Vector3(gate.get("pos", Vector3.ZERO))
	var tangent: Vector3 = Vector3(gate.get("tangent", Vector3.FORWARD))
	var right: Vector3 = tangent.cross(Vector3.UP).normalized()
	var width: float = float(gate.get("hw", 3.0))
	var pivot_pos: Vector3 = center - right * (width + 0.55)
	var phase_angle: float = atan2(right.z, right.x)
	var wm_scene: PackedScene = load("res://assets/models/minigolf/windmill.glb")
	var pivot: Node3D = Node3D.new()
	pivot.position = pivot_pos + Vector3(0, 0.48, 0)
	add_child(pivot)
	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 0.44
	base_mesh.bottom_radius = 0.62
	base_mesh.height = 0.55
	base.mesh = base_mesh
	base.material_override = _make_flat_material(Color(0.26, 0.24, 0.34))
	base.position = pivot_pos + Vector3(0, 0.2, 0)
	add_child(base)
	for seg: int in 6:
		var bar: MeshInstance3D = MeshInstance3D.new()
		var bar_mesh: BoxMesh = BoxMesh.new()
		bar_mesh.size = Vector3(BOOM_LEN / 6.0, 0.28, 0.34)
		bar.mesh = bar_mesh
		bar.material_override = _make_flat_material(SwapTrack.COL_RAILRED if seg % 2 == 0 else Color(0.98, 0.91, 0.72), 0.18)
		bar.position = Vector3(BOOM_LEN / 6.0 * (0.5 + seg), 0.0, 0.0)
		pivot.add_child(bar)
	var tip: MeshInstance3D = MeshInstance3D.new()
	var tip_mesh: SphereMesh = SphereMesh.new()
	tip_mesh.radius = 0.25
	tip_mesh.height = 0.5
	tip.mesh = tip_mesh
	tip.material_override = _make_flat_material(Color(1.0, 0.78, 0.1), 1.8)
	tip.position = Vector3(BOOM_LEN, 0, 0)
	pivot.add_child(tip)
	var blades: Node3D = null
	if wm_scene != null:
		var windmill: Node3D = wm_scene.instantiate()
		windmill.position = pivot_pos - right * 1.8
		windmill.scale = Vector3.ONE * 3.2
		windmill.rotation.y = atan2(tangent.x, tangent.z)
		add_child(windmill)
		blades = windmill.find_child("blades", true, false) as Node3D
	_booms.append({"pivot": pivot, "pos": pivot_pos, "angle": phase_angle,
		"speed": BOOM_SPEED, "blades": blades})

func _build_crown() -> void:
	_crown = Node3D.new()
	var band: MeshInstance3D = MeshInstance3D.new()
	var bm: CylinderMesh = CylinderMesh.new()
	bm.top_radius = 0.26
	bm.bottom_radius = 0.30
	bm.height = 0.16
	band.mesh = bm
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.2)
	gold.metallic = 0.8
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.7, 0.1)
	gold.emission_energy_multiplier = 0.5
	band.material_override = gold
	_crown.add_child(band)
	for i in 4:
		var spike: MeshInstance3D = MeshInstance3D.new()
		var sm: CylinderMesh = CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.07
		sm.height = 0.22
		spike.mesh = sm
		spike.material_override = gold
		var a: float = TAU * float(i) / 4.0
		spike.position = Vector3(cos(a) * 0.26, 0.17, sin(a) * 0.26)
		_crown.add_child(spike)
	var sparkle: CPUParticles3D = CPUParticles3D.new()
	sparkle.amount = 14
	sparkle.lifetime = 0.7
	sparkle.initial_velocity_min = 0.4
	sparkle.initial_velocity_max = 1.2
	sparkle.direction = Vector3.UP
	sparkle.spread = 70.0
	sparkle.gravity = Vector3(0, -1.5, 0)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	sparkle.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	sparkle.material_override = mat
	sparkle.emitting = true
	_crown.add_child(sparkle)
	# gold ground halo: the "shoot me" bullseye reads even when the crown
	# itself hides behind the name tag
	var halo: MeshInstance3D = MeshInstance3D.new()
	var ht: TorusMesh = TorusMesh.new()
	ht.inner_radius = 0.52
	ht.outer_radius = 0.62
	halo.mesh = ht
	var hmat: StandardMaterial3D = StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.albedo_color = Color(1.0, 0.82, 0.2, 0.85)
	halo.material_override = hmat
	halo.name = "Halo"
	halo.position = Vector3(0, -0.62, 0)  # crown sits ~1.42 above the kart
	halo.scale = Vector3(1, 0.2, 1)
	_crown.add_child(halo)
	_crown.scale = Vector3.ONE * 2.1
	_crown.visible = false
	add_child(_crown)

func item_color(item: int) -> Color:
	if item < 0 or item >= ITEM_COLORS.size():
		return Color.WHITE
	return ITEM_COLORS[item]

func item_name(item: int) -> String:
	if item < 0 or item >= ITEM_NAMES.size():
		return ""
	return ITEM_NAMES[item]

func _build_pickups() -> void:
	var box_count: int = maxi(4, int(roundf(float(BASE_ITEM_BOXES) * item_density)))
	for i: int in box_count:
		var frac: float = fposmod(0.08 + float(i) / float(box_count), 1.0)
		var sample: Dictionary = track.sample_at(frac * track.total_len)
		var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var lane: float = (-0.95 if i % 2 == 0 else 0.95)
		var pos: Vector3 = Vector3(sample.get("pos", Vector3.ZERO)) + right * lane + Vector3.UP * 0.7
		var node: Node3D = _make_item_box(EDGE_BOX_COLORS[i % EDGE_BOX_COLORS.size()])
		node.position = pos
		add_child(node)
		_item_boxes.append({"node": node, "active": true, "respawn": 0.0,
			"base_y": pos.y, "phase": float(i) * 0.71})
	var orb_count: int = maxi(3, int(roundf(float(BASE_ORB_PICKUPS) * item_density)))
	for i: int in orb_count:
		var frac: float = fposmod(0.16 + float(i) / float(orb_count), 1.0)
		var sample: Dictionary = track.sample_at(frac * track.total_len)
		var tangent: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD))
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var lane: float = 0.45 if i % 2 == 0 else -0.45
		var pos: Vector3 = Vector3(sample.get("pos", Vector3.ZERO)) + right * lane + Vector3.UP * 0.72
		var node: Node3D = _make_orb_pickup()
		node.position = pos
		add_child(node)
		_orb_pickups.append({"node": node, "active": true, "respawn": 0.0,
			"base_y": pos.y, "phase": float(i) * 0.93})

func _make_item_box(color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	var box: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE * 0.82
	box.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.7
	box.material_override = mat
	box.rotation = Vector3(0.45, 0.35, 0.2)
	root.add_child(box)
	var label: Label3D = Label3D.new()
	label.text = "?"
	label.font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	label.font_size = 78
	label.pixel_size = 0.008
	label.modulate = Color.WHITE
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root

func _make_orb_pickup() -> Node3D:
	var root: Node3D = Node3D.new()
	var orb: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.34
	mesh.height = 0.68
	orb.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.84, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.65, 1.0)
	mat.emission_energy_multiplier = 1.8
	orb.material_override = mat
	root.add_child(orb)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.42
	ring_mesh.outer_radius = 0.5
	ring.mesh = ring_mesh
	ring.material_override = mat
	root.add_child(ring)
	return root

func _step_pickups(dt: float) -> void:
	for record: Dictionary in _item_boxes:
		_step_pickup_record(record, dt, true)
	for record: Dictionary in _orb_pickups:
		_step_pickup_record(record, dt, false)

func _step_pickup_record(record: Dictionary, dt: float, item_box: bool) -> void:
	var node: Node3D = record.get("node", null) as Node3D
	if node == null or not is_instance_valid(node):
		return
	var active: bool = bool(record.get("active", false))
	if not active:
		var respawn: float = maxf(0.0, float(record.get("respawn", 0.0)) - dt)
		record["respawn"] = respawn
		if respawn <= 0.0:
			record["active"] = true
			node.visible = true
		return
	node.rotate_y(dt * (2.2 if item_box else 1.7))
	node.position.y = float(record.get("base_y", node.position.y)) \
		+ 0.12 * sin(now * 3.0 + float(record.get("phase", 0.0)))
	if phase != Phase.PLAY:
		return
	for kart_value in karts:
		var kart: SwapKart = kart_value
		if kart.finished or kart.airborne:
			continue
		if item_box and kart.held_item != ITEM_NONE:
			continue
		if not item_box and (kart.orb_charges > 0 or kart.has_golden):
			continue
		if kart.center().distance_to(node.global_position) > 1.15:
			continue
		record["active"] = false
		record["respawn"] = PICKUP_RESPAWN
		node.visible = false
		if item_box:
			kart.held_item = _draw_item(kart)
			_item_stats["boxes"] = int(_item_stats.get("boxes", 0)) + 1
			_flash_event("%s DRAWS %s" % [kart.pname, item_name(kart.held_item)], item_color(kart.held_item))
		else:
			kart.orb_charges = 1
			_flash_event("%s GRABS A SWAP ORB" % kart.pname, kart.color)
		Sfx.play("card", -3.0)
		_burst(kart.center(), item_color(kart.held_item) if item_box else Color(0.4, 0.75, 1.0), 10)
		break

func _draw_item(kart: SwapKart) -> int:
	var place: int = clampi(position_of(kart.index), 1, 4)
	var weights: Array[int]
	match place:
		1:
			weights = [8, 48, 12, 8]
		2:
			weights = [24, 34, 22, 18]
		3:
			weights = [42, 22, 30, 28]
		_:
			weights = [58, 15, 38, 36]
	var total: int = 0
	for weight: int in weights:
		total += weight
	var roll: int = rng.randi_range(1, total)
	for item: int in weights.size():
		roll -= weights[item]
		if roll <= 0:
			return item
	return ITEM_SWAP_SHELL

func kart_ahead_of(seat: int) -> int:
	var order: Array = _positions_list()
	var rank: int = order.find(seat)
	if rank <= 0:
		return -1
	return int(order[rank - 1])

func _use_item(kart: SwapKart) -> void:
	var item: int = kart.held_item
	if item == ITEM_NONE or kart.finished or kart.locked:
		return
	if item == ITEM_SWAP_SHELL and kart_ahead_of(kart.index) < 0:
		_flash_event("NO KART AHEAD FOR THE SWAP-SHELL", kart.color)
		return
	kart.held_item = ITEM_NONE
	match item:
		ITEM_SWAP_SHELL:
			_fire_swap_shell(kart)
		ITEM_COFFIN:
			_drop_coffin(kart)
		ITEM_BELL:
			_ring_bell(kart)
		ITEM_CROWS:
			_release_crows(kart)

func _fire_swap_shell(kart: SwapKart) -> void:
	var target: int = kart_ahead_of(kart.index)
	if target < 0:
		return
	var shell: SwapOrb = SwapOrb.new()
	shell.setup(self, kart.index, kart.color, false, true)
	_net_oid += 1
	shell.oid = _net_oid
	shell.target_idx = target
	_fx_root.add_child(shell)
	shell.global_position = kart.center() + kart.heading * 1.0 + Vector3.UP * 0.25
	shell.vel = kart.heading * 9.0
	orbs.append(shell)
	kart.play_anim("Throw", 0.7)
	_item_stats["shells"] = int(_item_stats.get("shells", 0)) + 1
	_flash_event("%s SENDS A SWAP-SHELL AT %s" % [kart.pname, _names[target]], ITEM_COLORS[ITEM_SWAP_SHELL])
	Sfx.play("putt", -1.0)
	print("ITEM_SHELL t=%.1f p=%d target=%d" % [race_t, kart.index, target])

func _drop_coffin(kart: SwapKart) -> void:
	var node: Node3D = _make_coffin(kart.color)
	var drop_pos: Vector3 = kart.global_position - kart.heading * 1.7
	var near: Dictionary = track.nearest_main(drop_pos, kart.hint)
	drop_pos.y = float(near.get("floor", 0.0)) + 0.32
	node.position = drop_pos
	node.rotation.y = atan2(kart.heading.x, kart.heading.z)
	add_child(node)
	_coffin_serial += 1
	_coffins.append({"id": _coffin_serial, "owner": kart.index, "node": node,
		"age": 0.0, "heading": kart.heading, "color": kart.color})
	var owner_records: Array[Dictionary] = []
	for record: Dictionary in _coffins:
		if int(record.get("owner", -1)) == kart.index:
			owner_records.append(record)
	while owner_records.size() > MAX_COFFINS_PER_SEAT:
		var oldest: Dictionary = owner_records.pop_front()
		_remove_coffin(oldest, true, "seat_cap")
	while _coffins.size() > MAX_COFFINS_GLOBAL:
		var global_oldest: Dictionary = _coffins[0]
		_remove_coffin(global_oldest, true, "global_cap")
	_item_stats["coffins"] = int(_item_stats.get("coffins", 0)) + 1
	_flash_event("%s DROPS THE PALLBEARER'S COFFIN" % kart.pname, ITEM_COLORS[ITEM_COFFIN])
	Sfx.play("place", -2.0)
	print("ITEM_COFFIN t=%.1f p=%d alive=%d" % [race_t, kart.index, _coffins.size()])

func _make_coffin(color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.05, 0.48, 1.85)
	body.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.08, 0.2)
	mat.metallic = 0.35
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	body.material_override = mat
	root.add_child(body)
	var cross: MeshInstance3D = MeshInstance3D.new()
	var cross_mesh: BoxMesh = BoxMesh.new()
	cross_mesh.size = Vector3(0.15, 0.08, 1.05)
	cross.mesh = cross_mesh
	cross.material_override = _make_flat_material(Color(0.78, 0.63, 0.25), 0.5)
	cross.position.y = 0.29
	root.add_child(cross)
	return root

func _make_flat_material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _step_coffins(dt: float) -> void:
	var hits: Array[Dictionary] = []
	for record: Dictionary in _coffins:
		var age: float = float(record.get("age", 0.0)) + dt
		record["age"] = age
		var node: Node3D = record.get("node", null) as Node3D
		if node == null or not is_instance_valid(node):
			hits.append(record)
			continue
		for kart_value in karts:
			var kart: SwapKart = kart_value
			if kart.finished or kart.airborne or kart.knock_immune > 0.0:
				continue
			if kart.index == int(record.get("owner", -1)) and age < 1.25:
				continue
			if kart.center().distance_to(node.global_position) < 1.05:
				kart.tumble()
				kart.play_anim("Hit_A", 0.7)
				_burst(kart.center(), ITEM_COLORS[ITEM_COFFIN], 16)
				_flash_event("%s HITS THE COFFIN" % kart.pname, kart.color)
				Sfx.play("crush")
				print("COFFIN_HIT t=%.1f owner=%d victim=%d" % [race_t, int(record.get("owner", -1)), kart.index])
				hits.append(record)
				break
	for record: Dictionary in hits:
		_remove_coffin(record)

func _remove_coffin(record: Dictionary, puff: bool = false, reason: String = "") -> void:
	var node: Node3D = record.get("node", null) as Node3D
	if node != null and is_instance_valid(node):
		if puff:
			var puff_color: Color = record.get("color", Color(0.72, 0.25, 1.0))
			_burst(node.global_position + Vector3.UP * 0.25, puff_color, 10)
		node.queue_free()
	_coffins.erase(record)
	if reason != "":
		print("COFFIN_DESPAWN t=%.1f owner=%d reason=%s alive=%d" % [
			race_t, int(record.get("owner", -1)), reason, _coffins.size()])

func _ring_bell(user: SwapKart) -> void:
	for kart_value in karts:
		var kart: SwapKart = kart_value
		if kart.index != user.index and not kart.finished:
			kart.bell_slow_t = maxf(kart.bell_slow_t, BELL_DURATION)
	_item_stats["bells"] = int(_item_stats.get("bells", 0)) + 1
	_flash_banner("[color=#ffd24a]THE BELL TOLLS![/color]\n[font_size=26]EVERYONE BUT %s SLOWS[/font_size]" % user.pname, 1.5)
	Sfx.play("round_over", -1.0)
	print("ITEM_BELL t=%.1f p=%d" % [race_t, user.index])

func _release_crows(user: SwapKart) -> void:
	var leader: int = leader_unfinished()
	if leader < 0:
		return
	var victim: SwapKart = karts[leader]
	victim.crow_t = maxf(victim.crow_t, CROW_DURATION)
	_item_stats["crows"] = int(_item_stats.get("crows", 0)) + 1
	_flash_banner("[color=#9f6cff]CROW MURDER![/color]\n[font_size=26]%s CAN'T SHAKE THE FLOCK[/font_size]" % victim.pname, 1.5)
	Sfx.play("grudge", -2.0)
	print("ITEM_CROWS t=%.1f p=%d leader=%d" % [race_t, user.index, leader])

## --- simulation loop -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	# THE HOUSE GUARD (spec §4.3): a mirror never simulates. Interp + juice only.
	if _mirror:
		_mirror_tick(delta)
		return
	if phase == Phase.WAIT:
		return
	var sdt: float = delta
	if _freeze_ticks > 0:
		# the swap hit-stop: tick-counted, never touches Engine.time_scale
		_freeze_ticks -= 1
		sdt = 0.0
	now += sdt
	if phase == Phase.INTRO:
		_intro_tick(sdt)
	if phase == Phase.PLAY:
		race_t += sdt
		_swaptally_position_tick()
		_stretch_tick()
	if sdt > 0.0:
		for bot in bots:
			if bot != null:
				bot.think(sdt)
	# karts
	for k in karts:
		var kart: SwapKart = k
		if kart.index < bots.size() and bots[kart.index] != null and phase == Phase.PLAY:
			var place: int = clampi(position_of(kart.index), 1, 4)
			kart.bot_speed_scale = _bot_rubber_scale(kart, place)
		else:
			kart.bot_speed_scale = 1.0
		var inp: Dictionary = _input_for(kart.index)
		if sdt > 0.0:
			kart.step(sdt, Vector2(inp.get("move", Vector2.ZERO)), bool(inp.get("b", false)))
			if _stuck_test and kart.index == 0 and phase == Phase.PLAY and not _stuck_fired:
				_force_stuck(kart)
			_constrain(kart, sdt)
			if phase == Phase.PLAY and bool(inp.get("a", false)):
				if kart.has_golden:
					_throw_orb(kart)
				elif kart.held_item != ITEM_NONE:
					_use_item(kart)
				else:
					_throw_orb(kart)
	if sdt > 0.0:
		_kart_bumps()
		_step_booms(sdt)
		_step_pickups(sdt)
		_step_coffins(sdt)
	# orbs (after karts so hits use final positions)
	if sdt > 0.0:
		var hits: Array = []
		for o in orbs:
			var orb: SwapOrb = o
			var victim: SwapKart = orb.step(sdt)
			if victim != null:
				hits.append({"orb": orb, "victim": victim})
		for h in hits:
			_resolve_hit(h.orb, h.victim)
		var alive: Array = []
		for o in orbs:
			if not (o as SwapOrb).dead:
				alive.append(o)
		orbs = alive
	if _stuck_test and _stuck_fired and not _stuck_captured and sdt > 0.0:
		_stuck_cap_delay -= 1
		if _stuck_cap_delay <= 0:
			_stuck_captured = true
			_grab_stuck_shot()
	if phase == Phase.PLAY and sdt > 0.0:
		_progress_all()
		_golden_tick(sdt)
		_update_crown()
		if _test_mode == "":
			if race_t > time_cap:
				_end_race()
			elif _finish_count >= karts.size():
				_end_race()
	if _test_mode != "" and sdt > 0.0:
		_test_tick()
	# --swapnetdemo: the rig's one scripted orb drop (kart 0 -> kart 1, both
	# still racing) so the SWAPPED! ritual is guaranteed on the wire.
	if _netdemo and _netdemo_fire_t > 0.0 and now >= _netdemo_fire_t and sdt > 0.0 and phase == Phase.PLAY:
		_netdemo_fire_t = -1.0
		_drop_orb_on(0, 1)
		print("SWAP_NETDEMO scripted orb drop 0 -> 1 t=%.1f" % race_t)

func _swaptally_position_tick() -> void:
	if not _swaptally or race_t + 0.0001 < _swaptally_next_pos_t:
		return
	while race_t + 0.0001 >= _swaptally_next_pos_t:
		for kart_value: Variant in karts:
			var kart: SwapKart = kart_value
			if kart.finished:
				continue
			var pos: Vector3 = kart.global_position
			print("SWAPBOT_POS p=%d t=%.1f cp=%d pos=(%.1f,%.1f)" % [
				kart.index, _swaptally_next_pos_t, kart.gates_credited, pos.x, pos.z])
		_swaptally_next_pos_t += 10.0

func _bot_rubber_scale(kart: SwapKart, place: int) -> float:
	var rubber_scales: Array[float] = [0.98, 1.01, 1.045, 1.08]
	var scale: float = float(rubber_scales[clampi(place - 1, 0, rubber_scales.size() - 1)])
	if place != karts.size() or race_t <= 1.0:
		return scale
	var leader_index: int = leader_unfinished()
	if leader_index < 0 or leader_index == kart.index:
		return scale
	var leader: SwapKart = karts[leader_index]
	var leader_pace: float = clampf(maxf(leader.progress, 0.0) / maxf(race_t, 1.0), 4.0, 10.0)
	var gap_seconds: float = maxf(leader.progress - kart.progress, 0.0) / leader_pace
	if gap_seconds > SLIPSTREAM_GAP_SECONDS:
		scale *= SLIPSTREAM_SPEED_MULT
	return scale

func _intro_tick(sdt: float) -> void:
	_intro_t += sdt
	var stage: int = -1
	if _intro_t < 1.1:
		stage = 0
	elif _intro_t < 1.7:
		stage = 1
	elif _intro_t < 2.3:
		stage = 2
	elif _intro_t < 2.9:
		stage = 3
	else:
		stage = 4
	if stage == _intro_stage:
		return
	_intro_stage = stage
	match stage:
		0:
			_flash_banner("[color=#ffd84d]SWAP MEET[/color]\n[font_size=26]EVERY HIT TRADES PLACES. SHOOT FIRST PLACE.[/font_size]", 1.05)
		1:
			_flash_banner("[color=#ff6b5e]3[/color]", 0.55)
			Sfx.play("card")
		2:
			_flash_banner("[color=#ffd84d]2[/color]", 0.55)
			Sfx.play("card")
		3:
			_flash_banner("[color=#7fe08a]1[/color]", 0.55)
			Sfx.play("card")
		4:
			_flash_banner("[color=#ffffff]GO!!![/color]", 0.8)
			Sfx.play("confirm")
			if _stretch != null:
				_stretch.play_started()   # FINAL STRETCH: light bed off the line
			phase = Phase.PLAY
			for k in karts:
				(k as SwapKart).locked = false
				(k as SwapKart).orb_cd = 1.5  # first seconds are pure racing
			if _netdemo:
				_netdemo_stage()

func _input_for(p: int) -> Dictionary:
	if phase != Phase.PLAY and phase != Phase.END:
		return {"move": Vector2.ZERO, "a": false, "b": false}
	if _test_mode != "":
		return {"move": Vector2.ZERO, "a": false, "b": false}
	if p < bots.size() and bots[p] != null:
		var bot: SwapBot = bots[p]
		return {"move": bot.move, "a": bot.a, "b": bot.b}
	return {
		"move": PlayerInput.get_move(p),
		"a": PlayerInput.just_pressed(p, "a"),
		"b": PlayerInput.is_down(p, "b"),
	}

## Corridor walls + floor + shortcut transitions + progress s for one kart.
func _constrain(kart: SwapKart, dt: float) -> void:
	var s_eff: float = 0.0
	var previous_bog_scale: float = kart.bog_speed_scale
	if kart.on_shortcut:
		var q: Dictionary = track.nearest_sc(kart.global_position, kart.sc_hint)
		kart.sc_hint = int(q.idx)
		var s_sc: float = float(q.get("s", 0.0))
		if s_sc > track.sc_len - 0.9:
			kart.on_shortcut = false
			print("SC_EXIT t=%.1f p=%d" % [race_t, kart.index])
			var qm: Dictionary = track.nearest_main(kart.global_position, -1)
			kart.hint = int(qm.idx)
			s_eff = float(qm.s)
			_apply_walls(kart, qm, 0.0, dt)
		else:
			_apply_walls(kart, q, track.sc_floor(s_sc), dt)
			kart.bog_speed_scale = 1.0
			s_eff = track.sc_entry_s + (s_sc / track.sc_len) * fposmod(track.sc_exit_s - track.sc_entry_s, track.total_len)
			_ramp_unstick(kart, q, s_sc, dt)
	else:
		var q2: Dictionary = track.nearest_main(kart.global_position, kart.hint)
		kart.hint = int(q2.idx)
		s_eff = float(q2.s)
		# shortcut entrance: near the mouth, HUGGING THE INFIELD SIDE
		# (where the arrow is; negative lat here), and moving into the
		# branch. Racing-line traffic keeps lat ~0 and is not captured.
		if not kart.finished and not kart.airborne \
				and float(q2.lat) < -1.1 \
				and kart.global_position.distance_to(track.sc_entry_pos) < 2.4:
			var shortcut_sample: Dictionary = track.sc_sample_at(2.5)
			var into: Vector3 = Vector3(shortcut_sample.get("pos", Vector3.ZERO)) - kart.global_position
			into.y = 0.0
			if into.length() > 0.3 and kart.heading.dot(into.normalized()) > 0.3:
				kart.on_shortcut = true
				kart.sc_hint = 0
				print("SC_ENTER t=%.1f p=%d" % [race_t, kart.index])
		var track_floor: float = float(q2.get("floor", 0.0))
		_apply_walls(kart, q2, track_floor, dt)
		kart.bog_speed_scale = track.bog_speed_scale(float(q2.get("s", 0.0)), float(q2.get("lat", 0.0)))
	# progress (wrap-aware delta on the effective main-loop arclength)
	var l: float = track.total_len
	var ds: float = s_eff - kart.last_s_eff
	if ds < -l * 0.5:
		ds += l
	elif ds > l * 0.5:
		ds -= l
	kart.progress += ds
	kart.last_s_eff = s_eff
	if kart.bog_speed_scale < 0.99 and previous_bog_scale >= 0.99:
		_burst(kart.global_position + Vector3.UP * 0.25, SwapTrack.COL_WATER, 12)
		Sfx.play("place", -5.0)
		print("BOG_SPLASH t=%.1f p=%d" % [race_t, kart.index])
	if phase == Phase.PLAY:
		_check_gates(kart)
		_check_laps(kart)

## Ramp/bridge anti-trap. A kart that pins itself against the narrow shortcut
## corridor (nose into a rail on the plank ramp) can grind to near-zero speed
## while the player keeps steering into it — the bots never do this (they hold
## ~5u/s straight through, so this never fires for them and their receipts are
## unchanged). After 1.5s jammed, give ONE gentle gutter-style nudge: recentre on
## the corridor a step further along the path and hand back a little forward speed.
## No teleport past the jam beyond that one nudge.
func _ramp_unstick(kart: SwapKart, q: Dictionary, s_sc: float, dt: float) -> void:
	if kart.locked or kart.finished or kart.airborne \
			or absf(kart.speed) >= 1.0 or kart.last_input_mag < 0.5:
		kart.stuck_t = 0.0
		return
	kart.stuck_t += dt
	if kart.stuck_t < 1.5:
		return
	kart.stuck_t = 0.0
	# nudge a step further along the shortcut centre-line (toward the exit)
	var fwd: Vector3 = Vector3(q.get("tangent", Vector3.FORWARD))
	var ahead: float = minf(s_sc + 1.2, track.sc_len)
	var ahead_sample: Dictionary = track.sc_sample_at(ahead)
	var centre: Vector3 = Vector3(ahead_sample.get("pos", Vector3.ZERO))
	kart.global_position = Vector3(centre.x, kart.y, centre.z)
	kart.heading = fwd
	kart.vel_dir = fwd
	kart.speed = maxf(kart.speed, 3.0)
	kart.knock_vel = Vector3.ZERO
	Sfx.play("bounce", -6.0)
	if _stuck_test and kart.index == 0:
		_stuck_fired = true
	print("SC_UNSTICK t=%.1f p=%d s=%.1f" % [race_t, kart.index, s_sc])


## Dev (--swapstuck): pin kart 0 on the plank ramp at near-zero speed with input
## "held", exactly the human trap the tester hit — so _ramp_unstick trips and we
## can film the recovery. Runs only under the flag; never touches normal play.
func _force_stuck(kart: SwapKart) -> void:
	if not kart.on_shortcut:
		kart.global_position = Vector3(track.sc_sample_at(3.2).pos)
		kart.on_shortcut = true
		kart.sc_hint = 0
		kart.airborne = false
		kart.y = track.sc_floor(3.2)
	kart.speed = 0.0
	kart.last_input_mag = 1.0   # simulate the player mashing forward into the jam


func _grab_stuck_shot() -> void:
	if DisplayServer.get_name() == "headless":
		print("SWAP_STUCK_CAP_SKIP_HEADLESS")
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	var path: String = "res://verify_out/swap_unstick.png"
	img.save_png(path)
	print("SWAP_STUCK_CAP ", path)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _apply_walls(kart: SwapKart, q: Dictionary, floor_y: float, dt: float) -> void:
	var hw: float = float(q.get("hw", 0.0)) - KART_R
	var lat: float = float(q.get("lat", 0.0))
	var right: Vector3 = Vector3(q.get("tangent", Vector3.FORWARD)).cross(Vector3.UP).normalized()
	if absf(lat) > hw:
		var side: float = signf(lat)
		var proj: Vector3 = Vector3(q.get("proj", Vector3.ZERO))
		kart.global_position = Vector3(proj.x, kart.global_position.y, proj.z) + right * hw * side
		var impact: float = kart.bounce(-right * side)
		if impact > 1.5:
			_bounces += 1
			_net_bounce = [int(_net_bounce[0]) + 1, kart.index]
			Sfx.play("bounce", clampf(-12.0 + impact * 1.1, -12.0, -2.0))
			if impact > 5.0:
				_shake = maxf(_shake, 0.12)
	# floor / airborne
	if kart.airborne:
		if kart.air_step(dt, floor_y):
			_burst(kart.global_position, Color(0.8, 0.72, 0.6), 8)
			Sfx.play("place", -6.0)
	else:
		if floor_y < kart.y - 0.5:
			kart.launch_air(maxf(kart.speed, 0.0) * SwapKart.RAMP_LAUNCH)
			Sfx.play("putt", -4.0)
			print("JUMP t=%.1f p=%d v=%.1f" % [race_t, kart.index, kart.speed])
		else:
			kart.y = floor_y
	kart.global_position.y = kart.y

func _check_gates(kart: SwapKart) -> void:
	var g: int = _gates_below(kart.progress)
	if g > kart.gates_credited:
		var earned: int = g - kart.gates_credited
		kart.gates_credited = g
		if not kart.finished:
			_points[kart.index] += earned
			var gi: int = (g - 1) % track.gate_s.size()
			track.pulse_gate(gi, kart.color)
			Sfx.play("card", -5.0)
			_net_gp = [int(_net_gp[0]) + 1, gi, kart.color.to_html(false)]
			_update_score_rows()

func _gates_below(prog: float) -> int:
	if prog <= 0.0:
		return 0
	var per: int = track.gate_s.size()
	var full: int = int(prog / track.total_len)
	var rem: float = prog - full * track.total_len
	var c: int = full * per
	for gs in track.gate_s:
		if rem >= gs:
			c += 1
	return c

## Escalated bot recovery. The target is the center of the last checkpoint this
## race position cleanly crossed. It grants no progress: only uncheckpointed
## distance is discarded, while checkpoint/lap ownership and timing stay put.
func bot_checkpoint_nudge(seat: int) -> bool:
	if seat < 0 or seat >= karts.size() or track.gate_s.is_empty():
		return false
	var kart: SwapKart = karts[seat]
	if kart.finished:
		return false
	var checkpoint: int = maxi(kart.gates_credited, 0)
	var per_lap: int = track.gate_s.size()
	var checkpoint_lap: int = int(checkpoint / per_lap)
	var within_lap: int = checkpoint % per_lap
	var target_s: float = 0.0
	if within_lap > 0:
		target_s = float(track.gate_s[within_lap - 1])
	var checkpoint_progress: float = float(checkpoint_lap) * track.total_len + target_s
	var sample: Dictionary = track.sample_at(target_s)
	var target_pos: Vector3 = Vector3(sample.get("pos", Vector3.ZERO))
	var target_heading: Vector3 = Vector3(sample.get("tangent", Vector3.FORWARD)).normalized()
	var old_pos: Vector3 = kart.center()
	_burst(old_pos, Color(0.72, 0.86, 1.0), 8)
	kart.global_position = target_pos
	kart.y = target_pos.y
	kart.global_position.y = kart.y
	kart.heading = target_heading
	kart.vel_dir = target_heading
	kart.speed = maxf(kart.speed, 3.5)
	kart.knock_vel = Vector3.ZERO
	kart.airborne = false
	kart.on_shortcut = false
	kart.sc_hint = -1
	var nearest: Dictionary = track.nearest_main(kart.global_position, -1)
	kart.hint = int(nearest.get("idx", -1))
	kart.last_s_eff = float(nearest.get("s", target_s))
	# Reset to already-earned checkpoint credit, never forward of it. This keeps
	# the physical line crossing and the monotonic lap scalar in the same frame.
	kart.progress = checkpoint_progress
	kart.bog_speed_scale = 1.0
	kart.tumble_t = 0.0
	kart.drifting = false
	kart.drift_t = 0.0
	kart.knock_immune = maxf(kart.knock_immune, 1.2)
	kart.swap_immune = maxf(kart.swap_immune, 1.0)
	kart._orient(1000.0)
	kart.flash_tag()
	_burst(kart.center(), kart.color, 12)
	print("BOT_NUDGE p=%d t=%.1f cp=%d pos=(%.1f,%.1f)" % [
		seat, race_t, checkpoint, target_pos.x, target_pos.z])
	return true

## FINAL STRETCH ticks (§7.3): once the leader enters the last 10% of the
## final lap, the remaining distance maps onto the kit's 10-step rising
## ladder — the room hears the line coming. Reads decided state only.
func _stretch_tick() -> void:
	if _stretch == null or not _stretch.escalated or _finish_count > 0:
		return
	var lead: int = _leader_all()
	if lead < 0:
		return
	var window: float = track.total_len * 0.1
	var remain: float = laps_total * track.total_len - (karts[lead] as SwapKart).progress
	if remain > window or remain < 0.0:
		return
	_stretch.tick(10.0 * remain / window)

func _check_laps(kart: SwapKart) -> void:
	var laps_done: int = int(floorf(kart.progress / track.total_len))
	if laps_done <= kart.laps_hw:
		return
	kart.laps_hw = laps_done
	var lt: float = race_t - kart.last_cross_time
	kart.last_cross_time = race_t
	if kart.laps_hw > 0:
		kart.lap_times.append(lt)
		print("LAP t=%.1f p=%d lap=%d time=%.1fs" % [race_t, kart.index, kart.laps_hw, lt])
	if kart.laps_hw >= laps_total and not kart.finished:
		_finish_kart(kart)
	elif kart.laps_hw == laps_total - 1 and not _final_lap_called and _leader_all() == kart.index:
		_final_lap_called = true
		if _stretch != null:
			_stretch.escalate()   # FINAL STRETCH: MK's final lap is HEARD (§7.3)
		_flash_banner("[color=#ffd84d]FINAL LAP![/color]", 1.4)
		Sfx.play("round_over", -4.0)
		_net_snap("net_finallap")

func _finish_kart(kart: SwapKart) -> void:
	kart.finished = true
	kart.has_golden = false
	_finish_count += 1
	kart.finish_place = _finish_count
	_points[kart.index] += FINISH_PTS[kart.finish_place - 1]
	kart.cheer_forever()
	if kart.finish_place == 1 and _stretch != null:
		_stretch.match_ended()   # nudge fades so the finish beat owns the screen
	# The race winner crossing with P2 a kart-length behind gets the money
	# shot instead of a plain banner (doc 09 §7.1). Everything below is
	# presentation - placements/points/physics are already decided above.
	var photo: bool = kart.finish_place == 1 and _try_photo_finish(kart)
	if not photo:
		Sfx.play("round_over")
		_confetti(kart.center(), kart.color)
		_flash_banner("[color=%s]%s[/color] FINISHES P%d!" % [kart.color.to_html(false), kart.pname, kart.finish_place], 1.6)
		# THE DECIDING MOMENT (doc 09 §Q2): a clean (non-photo) win still deserves the
		# shared fov punch + newsreel capture — the photo-finish path owns its own
		# camera below. Self-gates on reduced-motion inside the kit.
		if kart.finish_place == 1:
			FinalStretch.fov_punch(_cam, CAM_FOV, 6.0, 0.8, "THE FINISH")
	print("FINISH t=%.1f p=%d place=%d laps=%s" % [race_t, kart.index, kart.finish_place, str(kart.lap_times)])
	_update_score_rows()

## Arm+fire the photo finish if the winner just pipped the chaser. Returns
## true if the photo-finish presentation took over the finish beat. Reads
## only decided state (progress order); it never mutates the sim.
func _try_photo_finish(winner: SwapKart) -> bool:
	var chaser: SwapKart = null
	for i in _positions_list():
		var k: SwapKart = karts[i]
		if not k.finished:
			chaser = k
			break
	if chaser == null:
		return false
	var line: float = laps_total * track.total_len
	var margin_units: float = maxf(line - chaser.progress, 0.0)
	if margin_units > PHOTO_MARGIN_UNITS:
		return false
	# project the gap into a time delta from the chaser's current pace
	var est_delta: float = margin_units / maxf(absf(chaser.speed), 3.0)
	_photo_finish(winner, chaser, margin_units, est_delta)
	return true

## The freeze/flash/reveal sequence. Uses the tick-counted freeze (never
## Engine.time_scale) so it adds zero sim-time: placements stay identical.
func _photo_finish(winner: SwapKart, chaser: SwapKart, margin_units: float, est_delta: float) -> void:
	_freeze_ticks = maxi(_freeze_ticks, PHOTO_FREEZE_TICKS)   # 10-tick line freeze
	_shake = maxf(_shake, 0.5)
	# THE ESTATE'S MEMORY (doc 09 §Q2): the photo finish keeps its bespoke, tuned
	# _fov_punch below, but route the deciding-moment newsreel still through the
	# shared chokepoint so the money shot reaches the album like every other climax.
	MomentScribe.capture("deciding", "PHOTO FINISH", 3)
	_fov_punch(38.0, 0.85)                                    # camera punch to the line
	_flashbulb()
	Sfx.play("bumper", -2.0)
	_flash_banner("[color=#ffd84d]PHOTO FINISH![/color]", 3.4)
	var line_pos: Vector3 = winner.center()
	_confetti(line_pos, winner.color)                          # double confetti (doc §7.1)
	_confetti(line_pos + Vector3(1.4, 0.6, 0.0), chaser.color)
	# staged winner reveal on a process-always timer, so it still fires
	# while the physics tick loop is frozen
	var wname: String = winner.pname
	var wcol: String = winner.color.to_html(false)
	get_tree().create_timer(0.55, true, false, true).timeout.connect(func() -> void:
		_flashbulb()
		Sfx.play("match_win", -3.0)
		_confetti(winner.center(), winner.color)
		_confetti(winner.center() + Vector3(-1.4, 0.6, 0.0), Color(1, 0.9, 0.4))
		_flash_banner("[color=#ffd84d]PHOTO FINISH[/color]\n[font_size=30][color=#%s]%s[/color] BY %.1fs![/font_size]" % [wcol, wname, est_delta], 3.0)
		_net_snap("net_photofinish_reveal"))
	# ONLINE: the freeze-tick ceremony's facts land here, mid-race — many
	# snapshot beats before finished(), so lesson 1 (pump death) can't bite.
	_net_pf = [int(_net_pf[0]) + 1, winner.index, chaser.index, snappedf(est_delta, 0.01)]
	_net_snap("net_photofinish")
	print("PHOTO_FINISH t=%.1f winner=%d chaser=%d margin=%.2fu delta=%.2fs" %
		[race_t, winner.index, chaser.index, margin_units, est_delta])
	if _photo_shots:
		_schedule_photo_shots()

## FOV zoom-in and back on the fixed overhead cam - a "punch" to the line.
## Runs on the render tick, so it animates through the sim freeze.
func _fov_punch(target_fov: float, dur: float) -> void:
	if _cam == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_cam, "fov", target_fov, dur * 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cam, "fov", CAM_FOV, dur * 0.68).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## A single white paparazzi pop over the viewport.
func _flashbulb() -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(1, 1, 1, 0.0)
	_flash_rect.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.85, 0.03)
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.32)
	tw.tween_callback(func() -> void:
		if _flash_rect != null:
			_flash_rect.visible = false)

func _schedule_photo_shots() -> void:
	# beat 1: mid-freeze, karts pinned at the line under the PHOTO FINISH banner
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func() -> void: _capture_photo(1))
	# beat 2: the winner reveal + confetti
	get_tree().create_timer(0.78, true, false, true).timeout.connect(func() -> void: _capture_photo(2))
	if _autoquit:
		get_tree().create_timer(1.7, true, false, true).timeout.connect(func() -> void: get_tree().quit())

func _capture_photo(n: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	var path: String = "res://verify_out/photofinish_%02d.png" % n
	img.save_png(path)
	print("PHOTOFINISH_SHOT ", path)

## --- kart-kart bumps ------------------------------------------------------------

func _kart_bumps() -> void:
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			var a: SwapKart = karts[i]
			var b: SwapKart = karts[j]
			if absf(a.y - b.y) > 0.8:
				continue
			var d: Vector3 = b.global_position - a.global_position
			d.y = 0.0
			var dist: float = d.length()
			if dist > KART_R * 2.0 + 0.14 or dist < 0.001:
				continue
			var n: Vector3 = d / dist
			var overlap: float = KART_R * 2.0 + 0.14 - dist
			a.global_position -= n * overlap * 0.5
			b.global_position += n * overlap * 0.5
			var va: Vector3 = a.vel_dir * a.speed + a.knock_vel
			var vb: Vector3 = b.vel_dir * b.speed + b.knock_vel
			var closing: float = (va - vb).dot(n)
			if closing > 0.0:
				a.knock_vel -= n * closing * 0.55
				b.knock_vel += n * closing * 0.55
				if closing > 3.0:
					Sfx.play("bounce", -8.0)

## --- windmill booms ----------------------------------------------------------------

func _step_booms(dt: float) -> void:
	for boom_value in _booms:
		var boom: Dictionary = boom_value
		boom["angle"] = fposmod(float(boom.get("angle", 0.0)) + float(boom.get("speed", 0.0)) * dt, TAU)
		var pivot: Node3D = boom.get("pivot", null) as Node3D
		pivot.rotation.y = -float(boom.get("angle", 0.0))
		var blades: Node3D = boom.get("blades", null) as Node3D
		if blades != null:
			blades.rotate_object_local(Vector3(0, 0, 1), dt * 1.4)
		if phase != Phase.PLAY:
			continue
		var origin: Vector3 = Vector3(boom.get("pos", Vector3.ZERO))
		var angle: float = float(boom.get("angle", 0.0))
		var dir: Vector3 = Vector3(cos(angle), 0, sin(angle))
		for k in karts:
			var kart: SwapKart = k
			if kart.finished or kart.knock_immune > 0.0 or kart.y > 0.6:
				continue
			var rel: Vector3 = kart.global_position - origin
			rel.y = 0.0
			var along: float = clampf(rel.dot(dir), 0.0, BOOM_LEN)
			var closest: Vector3 = origin + dir * along
			if kart.global_position.distance_to(Vector3(closest.x, kart.global_position.y, closest.z)) < 0.78:
				var swing: Vector3 = Vector3.UP.cross(dir).normalized() * signf(float(boom.get("speed", 0.0)))
				kart.knock(swing, KNOCK_POWER)
				kart.play_anim("Hit_A", 0.5)
				Sfx.play("crush")
				_shake = maxf(_shake, 0.22)
				_burst(kart.center(), Color(1.0, 0.9, 0.6), 14)
				_net_knock = [int(_net_knock[0]) + 1, kart.index]
				print("KNOCK t=%.1f p=%d boom" % [race_t, kart.index])

## --- orbs & swapping -----------------------------------------------------------------

func _throw_orb(kart: SwapKart) -> void:
	if kart.locked:
		return
	if kart.finished:
		# finished players still get a toy: confetti honk
		_burst(kart.center() + Vector3(0, 1.0, 0), kart.color, 10)
		Sfx.play("card", -6.0)
		return
	if kart.orb_cd > 0.0:
		return
	if not kart.has_golden and kart.orb_charges <= 0:
		return
	kart.orb_cd = ORB_CD
	var was_golden: bool = kart.has_golden
	var golden: bool = was_golden
	var target: int = -1
	if golden:
		kart.has_golden = false
		target = leader_unfinished()
		if target == kart.index or target < 0:
			golden = false  # leader threw the golden: it flies as a normal orb
	else:
		kart.orb_charges = maxi(0, kart.orb_charges - 1)
	var orb: SwapOrb = SwapOrb.new()
	orb.setup(self, kart.index, kart.color, was_golden)
	_net_oid += 1
	orb.oid = _net_oid
	_fx_root.add_child(orb)
	orb.golden = golden
	orb.target_idx = target
	orb.global_position = kart.center() + kart.heading * 0.85 + Vector3(0, 0.35, 0)
	if golden:
		orb.vel = kart.heading * 8.0 + Vector3(0, 3.5, 0)
		Sfx.play("grudge")
		_flash_event("%s FIRES THE GOLDEN ORB AT %s!" % [kart.pname, _names[target]], Color(1.0, 0.85, 0.25))
	else:
		orb.vel = kart.heading * (8.5 + maxf(kart.speed, 0.0) * 0.6) + Vector3(0, 4.6, 0)
		Sfx.play("putt")
	orbs.append(orb)
	kart.play_anim("Throw", 0.7)
	print("THROW t=%.1f p=%d golden=%s" % [race_t, kart.index, str(golden)])

func _resolve_hit(orb: SwapOrb, victim: SwapKart) -> void:
	if orb.dead:
		return
	var thrower: SwapKart = karts[orb.owner_idx]
	# A lobbed orb can outlive its owner crossing the line. A finished race
	# position is sealed; it cannot be traded back into the active pack.
	if phase != Phase.PLAY or thrower.finished or victim.finished or victim == thrower:
		orb.fizzle()
		return
	if not orb.golden and victim.swap_immune > 0.0:
		orb.fizzle()
		return
	orb.dead = true
	orb.queue_free()
	_do_swap(thrower, victim, orb.golden)

func on_swap_blocked(_orb: SwapOrb, victim: SwapKart) -> void:
	_swaps_blocked += 1
	_flash_event("%s IS SWAP-PROOF (immunity)" % victim.pname, Color(0.8, 0.85, 1.0))
	print("SWAP_BLOCKED t=%.1f victim=%d" % [race_t, victim.index])

## THE verb. Atomic exchange of two karts' complete race-position souls, with the
## full ritual: 0.08s hit-stop, dual teleport beams in both colors,
## camera shake, name-tag flashes, SWAPPED! banner.
func _do_swap(a: SwapKart, b: SwapKart, golden: bool) -> void:
	var pre: Array = _positions_list()
	var pre_pos_a: int = pre.find(a.index) + 1
	var pre_pos_b: int = pre.find(b.index) + 1
	var pos_a: Vector3 = a.center()
	var pos_b: Vector3 = b.center()
	# the atomic trade
	var soul_a: Dictionary = a.soul()
	a.apply_soul(b.soul())
	b.apply_soul(soul_a)
	# Bot steering samples the route from its transformed position each tick;
	# only its stuck-watch baseline is driver-local and must be invalidated.
	if a.index < bots.size():
		var bot_a: SwapBot = bots[a.index] as SwapBot
		if bot_a != null:
			bot_a.position_exchanged()
	if b.index < bots.size():
		var bot_b: SwapBot = bots[b.index] as SwapBot
		if bot_b != null:
			bot_b.position_exchanged()
	a.swap_immune = SWAP_IMMUNITY
	b.swap_immune = SWAP_IMMUNITY
	a.play_anim("Hit_A", 0.4)
	b.play_anim("Hit_A", 0.4)
	a.flash_tag()
	b.flash_tag()
	# the ritual
	_freeze_ticks = FREEZE_TICKS
	_swap_fx(pos_a, a.color, b.color)
	_swap_fx(pos_b, b.color, a.color)
	_shake = maxf(_shake, 0.55 if golden else 0.4)
	# RUMBLE: both karts feel their kinematic souls yanked out from under them
	PlayerInput.rumble_hit(a.index, 0.55 if golden else 0.4)
	PlayerInput.rumble_hit(b.index, 0.55 if golden else 0.4)
	Sfx.play("sink")
	Sfx.play("bumper", -4.0)
	# accounting
	_swaps_total += 1
	var post: Array = _positions_list()
	var post_pos_a: int = post.find(a.index) + 1
	var post_pos_b: int = post.find(b.index) + 1
	var gain_a: int = pre_pos_a - post_pos_a
	var gain_b: int = pre_pos_b - post_pos_b
	var ca: String = a.color.to_html(false)
	var cb: String = b.color.to_html(false)
	if golden:
		_golden_swaps += 1
		_gold_victims[b.index] = int(_gold_victims.get(b.index, 0)) + 1
		_flash_banner("[color=#ffd84d]GOLDEN SWAP![/color]\n[color=#%s]%s[/color] ROBS [color=#%s]%s[/color]" % [ca, a.pname, cb, b.pname], 2.0)
	else:
		_flash_banner("[color=#ffffff]SWAPPED![/color]\n[color=#%s]%s[/color] [color=#ffffff]<->[/color] [color=#%s]%s[/color]" % [ca, a.pname, cb, b.pname], 1.6)
	for pair in [[a, gain_a, b], [b, gain_b, a]]:
		var who: SwapKart = pair[0]
		var gain: int = pair[1]
		var other: SwapKart = pair[2]
		if gain >= 1:
			_currency.append({"type": "royalty", "player": who.index, "amount": 1,
				"reason": "swap heist (+%d places)" % gain})
			if who == a:  # the thrower stole it: pickpocket credit + a kart_wreck kill
				_gaining_swaps[who.index] = int(_gaining_swaps[who.index]) + 1
				_kill_events.append({"killer": a.index, "victim": other.index,
					"cause": "golden_swap" if golden else "kart_wreck"})
			if gain > _cruel_delta:
				_cruel_delta = gain
				_cruel_txt = "%s pickpocketed %d place%s from %s" % [who.pname, gain, "s" if gain > 1 else "", other.pname]
		if pre.find(who.index) == 0 and post.find(who.index) != 0:
			_currency.append({"type": "grudge", "player": who.index, "amount": 1,
				"reason": "swapped out of 1st"})
			_flash_event("%s LOSES THE LEAD!" % who.pname, who.color)
	_update_score_rows()
	_net_swap = [int(_net_swap[0]) + 1, a.index, b.index, 1 if golden else 0,
		Vector3(snappedf(pos_a.x, 0.01), snappedf(pos_a.y, 0.01), snappedf(pos_a.z, 0.01)),
		Vector3(snappedf(pos_b.x, 0.01), snappedf(pos_b.y, 0.01), snappedf(pos_b.z, 0.01))]
	_net_snap("net_swap")
	print("SWAP t=%.1f thrower=%d victim=%d golden=%s gain=%d" % [race_t, a.index, b.index, str(golden), gain_a])

func on_orb_fizzle(orb: SwapOrb) -> void:
	_burst(orb.global_position, Color(0.7, 0.8, 0.95, 0.7), 6)
	orb.queue_free()

func on_boost(kart: SwapKart, tier: int) -> void:
	Sfx.play("bumper", -6.0 if tier == 1 else -1.0)
	if tier == 2:
		_burst(kart.global_position + Vector3(0, 0.3, 0), Color(0.8, 0.5, 1.0), 10)
	print("BOOST t=%.1f p=%d tier=%d" % [race_t, kart.index, tier])

## --- golden orb pickup ---------------------------------------------------------------

func _golden_tick(dt: float) -> void:
	if _gold_pickup != null:
		_gold_pickup.rotate_y(dt * 2.0)
		var bob: Node3D = _gold_pickup.get_node("Bob")
		bob.position.y = 1.0 + 0.18 * sin(now * 3.0)
		var lead: int = leader_unfinished()
		for k in karts:
			var kart: SwapKart = k
			# the leader can't claim it - the golden orb IS the bullseye
			# pointed at them; they drive right through
			if kart.finished or kart.airborne or kart.index == lead:
				continue
			if kart.global_position.distance_to(_gold_spot) < 1.25:
				_claim_golden(kart)
				break
		return
	var holder: bool = false
	for k in karts:
		if (k as SwapKart).has_golden:
			holder = true
	for o in orbs:
		if (o as SwapOrb).golden:
			holder = true
	if holder:
		return
	_gold_t += dt
	if _gold_t >= GOLD_EVERY:
		_gold_t = 0.0
		_spawn_golden()

func _spawn_golden() -> void:
	# The comeback verb: spawn AHEAD of the trailing kart so the player
	# who needs it most reaches it first. Seeded pick among qualifying
	# spots; falls back to the nearest spot ahead of the trailer.
	var order: Array = _positions_list()
	var trailer: SwapKart = null
	for i in range(order.size() - 1, -1, -1):
		if not (karts[order[i]] as SwapKart).finished:
			trailer = karts[order[i]]
			break
	if trailer == null:
		return
	var t_s: float = fposmod(trailer.progress, track.total_len)
	var candidates: Array = []
	var best_frac: float = -1.0
	var best_ahead: float = 1e9
	for f in GOLD_SPOT_FRACS:
		var ahead: float = fposmod(float(f) * track.total_len - t_s, track.total_len)
		if ahead > 6.0 and ahead < 45.0:
			candidates.append(f)
		if ahead > 6.0 and ahead < best_ahead:
			best_ahead = ahead
			best_frac = float(f)
	var frac: float = best_frac if best_frac > 0.0 else float(GOLD_SPOT_FRACS[0])
	if candidates.size() > 0:
		frac = float(candidates[rng.randi_range(0, candidates.size() - 1)])
	var sm: Dictionary = track.sample_at(frac * track.total_len)
	_build_gold_pickup(Vector3(sm.get("pos", Vector3.ZERO)))
	Sfx.play("confirm", -2.0)
	_flash_event("GOLDEN ORB ON THE TRACK - SWAPS YOU WITH THE LEADER (leaders can't grab it)", Color(1.0, 0.85, 0.25))
	print("GOLD_SPAWN t=%.1f s=%.1f" % [race_t, frac * track.total_len])


## Node half of the golden spawn, shared with the mirror (which calls it off
## the gold wire fact; the host's sfx/event line ride their own channels).
func _build_gold_pickup(spot: Vector3) -> void:
	_gold_spot = spot
	_gold_pickup = Node3D.new()
	_gold_pickup.position = _gold_spot
	var bob: Node3D = Node3D.new()
	bob.name = "Bob"
	bob.position.y = 1.0
	_gold_pickup.add_child(bob)
	var orb: MeshInstance3D = MeshInstance3D.new()
	var om: SphereMesh = SphereMesh.new()
	om.radius = 0.42
	om.height = 0.84
	orb.mesh = om
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.2)
	mat.metallic = 0.7
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	mat.emission_energy_multiplier = 1.4
	orb.material_override = mat
	bob.add_child(orb)
	var pillar: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 0.5
	pm.bottom_radius = 0.7
	pm.height = 9.0
	pillar.mesh = pm
	var pmat: StandardMaterial3D = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.albedo_color = Color(1.0, 0.8, 0.2, 0.16)
	pillar.material_override = pmat
	pillar.position.y = 4.5
	_gold_pickup.add_child(pillar)
	add_child(_gold_pickup)

func _claim_golden(kart: SwapKart) -> void:
	_gold_pickup.queue_free()
	_gold_pickup = null
	kart.has_golden = true
	_net_gc = [int(_net_gc[0]) + 1, kart.index]
	Sfx.play("sink", -3.0)
	_burst(kart.center(), Color(1.0, 0.85, 0.25), 20)
	_flash_banner("[color=#%s]%s[/color] [color=#ffd84d]HAS THE GOLDEN ORB[/color]" % [kart.color.to_html(false), kart.pname], 1.5)
	print("GOLD_CLAIM t=%.1f p=%d" % [race_t, kart.index])

## --- standings ----------------------------------------------------------------------

func _progress_all() -> void:
	# HUD refresh cadence
	if Engine.get_physics_frames() % 15 == 0:
		_update_score_rows()
		_update_timer_label()
		if phase == Phase.PLAY and race_t >= 8.0:
			_net_snap("net_midrace")   # latched probe evidence; inert offline

func _positions_list() -> Array:
	var order: Array = []
	for k in karts:
		order.append((k as SwapKart).index)
	order.sort_custom(func(x, y) -> bool:
		var a: SwapKart = karts[x]
		var b: SwapKart = karts[y]
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_place < b.finish_place
		if absf(a.progress - b.progress) > 0.001:
			return a.progress > b.progress
		return a.index < b.index)
	return order

func position_of(idx: int) -> int:
	return _positions_list().find(idx) + 1

func _leader_all() -> int:
	return _positions_list()[0]

func leader_unfinished() -> int:
	for i in _positions_list():
		if not (karts[i] as SwapKart).finished:
			return i
	return -1

func _update_crown() -> void:
	var lead: int = leader_unfinished()
	if lead != _crown_on:
		var prev: int = _crown_on
		_crown_on = lead
		if lead >= 0 and phase == Phase.PLAY:
			_flash_event("%s LEADS - AIM AT THE CROWN" % _names[lead], _colors[lead])
			# a genuine overtake (not the opening leader from -1): sting it
			if prev >= 0:
				_overtake_sting()
	if lead < 0:
		_crown.visible = false
		return
	var kart: SwapKart = karts[lead]
	_crown.visible = phase != Phase.WAIT
	_crown.global_position = kart.global_position + Vector3(0, 1.42 + 0.08 * sin(now * 4.0), 0)
	_crown.rotation.y += get_physics_process_delta_time() * 1.5

## The overtake sting (doc 09 §7.2): a pitched 'sink' + a crown pop, gated
## by a cooldown on the sim clock so a drafting duel of rapid swaps can't
## machine-gun it. Presentation only - no sim state touched.
func _overtake_sting() -> void:
	if now < _overtake_next:
		return
	_overtake_next = now + OVERTAKE_STING_CD
	if not _mirror:
		_net_ov += 1
	if _sting_player != null:
		_sting_player.pitch_scale = 1.3
		_sting_player.play()
	# crown flash x1.5 for 0.4s
	var base: Vector3 = Vector3.ONE * 2.1
	if _crown_flash_tw != null and _crown_flash_tw.is_valid():
		_crown_flash_tw.kill()
	_crown.scale = base * 1.5
	_crown_flash_tw = create_tween()
	_crown_flash_tw.tween_property(_crown, "scale", base, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	print("OVERTAKE t=%.1f leader=%d" % [race_t, _crown_on])

## --- race end -------------------------------------------------------------------------

func _end_race() -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	for coffin: Dictionary in _coffins.duplicate():
		_remove_coffin(coffin)
	var order: Array = _positions_list()
	# DNF karts still collect their placement points (transparent, kind)
	for pi in order.size():
		var kart: SwapKart = karts[order[pi]]
		if not kart.finished and pi < FINISH_PTS.size():
			_points[kart.index] += FINISH_PTS[pi]
	var winner: int = order[0]
	karts[winner].cheer_forever()
	Sfx.play("match_win")
	_confetti(karts[winner].center(), _colors[winner])
	_confetti(karts[winner].center() + Vector3(1.5, 1, 0), Color(1, 0.9, 0.4))
	_flash_banner("[color=#%s]%s CROSSES FIRST[/color]" % [_colors[winner].to_html(false), _names[winner]], 9999.0)
	# ONLINE: champ minted HERE, 1.8 s of pump before report_finished fires
	# below (lesson 1: facts minted the same tick as the report never land).
	_net_champ = winner
	_net_snap("net_end")
	for k in karts:
		(k as SwapKart).locked = false  # keep cruising behind the banner
	var highlights: Array = []
	if _cruel_txt != "":
		highlights.append(_cruel_txt)
	var worst_gold: int = 0
	var worst_gold_i: int = -1
	for i in _gold_victims:
		if int(_gold_victims[i]) > worst_gold:
			worst_gold = int(_gold_victims[i])
			worst_gold_i = int(i)
	if worst_gold_i >= 0:
		var times_txt: String = "at the worst moment"
		if worst_gold >= 2:
			times_txt = "%d times" % worst_gold
		highlights.append("%s ate the golden orb %s" % [_names[worst_gold_i], times_txt])
	var fast_t: float = 1e9
	var fast_i: int = -1
	for k in karts:
		var kart: SwapKart = k
		for lt in kart.lap_times:
			if float(lt) < fast_t:
				fast_t = float(lt)
				fast_i = kart.index
	if fast_i >= 0:
		highlights.append("Fastest lap: %s (%.1fs)" % [_names[fast_i], fast_t])
	var monuments: Array = []
	for i in _gaining_swaps:
		if int(_gaining_swaps[i]) >= 5:
			monuments.append({"player": int(i), "kind": "pickpocket",
				"label": "%s, The Pickpocket (%d liftings)" % [_names[int(i)], int(_gaining_swaps[i])]})
	var results: Dictionary = {
		"placements": order,
		"points": _points.duplicate(),
		"currency_events": _currency.duplicate(),
		"kill_events": _kill_events.duplicate(),
		"highlights": highlights.slice(0, 3),
		"monuments": monuments,
	}
	get_tree().create_timer(1.8, true, false, true).timeout.connect(func() -> void:
		if _reported:
			return
		_reported = true
		report_finished(results)
		print("SWAPMEET_RESULTS ", JSON.stringify(results))
		print("KILL_EVENTS n=%d %s" % [_kill_events.size(), JSON.stringify(_kill_events)])
		_print_sim_summary()
		if _autoquit:
			get_tree().create_timer(1.5, true, false, true).timeout.connect(func() -> void: get_tree().quit()))

func _print_sim_summary() -> void:
	var all_finished: bool = true
	var laps_txt: String = ""
	for k in karts:
		var kart: SwapKart = k
		if not kart.finished:
			all_finished = false
		var times: Array = []
		for lt in kart.lap_times:
			times.append("%.1f" % float(lt))
		laps_txt += " p%d=[%s]" % [kart.index, ",".join(times)]
	print("SWAPMEET_SIM race_t=%.1fs swaps=%d blocked=%d golden=%d bounces=%d gaining=%s" %
		[race_t, _swaps_total, _swaps_blocked, _golden_swaps, _bounces, str(_gaining_swaps)])
	print("SWAPMEET_LAPS%s" % laps_txt)
	if bots_enabled:
		var ok: bool = all_finished and race_t < 180.0 and _swaps_total >= 3
		print("SWAPMEET_ASSERT all_finished=%s race_t=%.1fs(<180) swaps=%d(>=3): %s" %
			[str(all_finished), race_t, _swaps_total, "PASS" if ok else "FAIL"])
	if _swaptally:
		var order: Array = _positions_list()
		var seed_value: int = int(config.get("rng_seed", _cli_seed))
		var payload: String = "%d|%d|%.2f|%s|%d|%d|%d|%d|%d|%d" % [
			seed_value, laps_total, item_density, str(order), _swaps_total,
			int(_item_stats.get("boxes", 0)), int(_item_stats.get("shells", 0)),
			int(_item_stats.get("coffins", 0)), int(_item_stats.get("bells", 0)),
			int(_item_stats.get("crows", 0)),
		]
		var digest: String = payload.sha256_text().substr(0, 12)
		var passed: bool = all_finished and _finish_count == karts.size() \
			and int(_item_stats.get("boxes", 0)) > 0 and int(_item_stats.get("shells", 0)) > 0
		print("SWAPTALLY seed=%d laps=%d item_density=%.2f order=%s swaps=%d boxes=%d shells=%d coffins=%d bells=%d crows=%d digest=%s %s" % [
			seed_value, laps_total, item_density, str(order), _swaps_total,
			int(_item_stats.get("boxes", 0)), int(_item_stats.get("shells", 0)),
			int(_item_stats.get("coffins", 0)), int(_item_stats.get("bells", 0)),
			int(_item_stats.get("crows", 0)), digest, "PASS" if passed else "FAIL"])

## --- scripted tests ----------------------------------------------------------------------

func _setup_test() -> void:
	phase = Phase.PLAY
	for k in karts:
		var kart: SwapKart = k
		kart.locked = false
		kart.parked = true
		kart.orb_charges = 1
	var l: float = track.total_len
	if _test_mode == "immunity" or _test_mode == "moment":
		karts[0].place_at(l * 0.26, -0.5)
		karts[1].place_at(l * 0.34, -0.5)
		if karts.size() > 2:
			karts[2].place_at(l * 0.18, 0.9)
		if karts.size() > 3:
			karts[3].place_at(l * 0.14, -0.9)
		# kart1 sits EXACTLY on kart0's throw line (deterministic hit)
		var k0: SwapKart = karts[0]
		var k1: SwapKart = karts[1]
		k1.global_position = k0.global_position + k0.heading * 7.5
		k1.heading = k0.heading
		k1.vel_dir = k0.heading
		var q: Dictionary = track.nearest_main(k1.global_position, -1)
		k1.hint = int(q.idx)
		k1.last_s_eff = float(q.s)
		k1.progress = float(q.s)
		k1._orient(1000.0)
	_update_score_rows()
	print("SWAPTEST %s armed" % _test_mode)

func _drop_orb_on(owner_i: int, target_i: int) -> void:
	var orb: SwapOrb = SwapOrb.new()
	orb.setup(self, owner_i, _colors[owner_i], false)
	_net_oid += 1
	orb.oid = _net_oid
	_fx_root.add_child(orb)
	orb.global_position = karts[target_i].center() + Vector3(0, 3.0, 0)
	# Drop in the victim's frame so a MOVING target (--swapnetdemo) is still
	# under the orb when it lands; the parked --swaptest karts have speed 0,
	# so their scripted receipts are byte-unchanged.
	var victim: SwapKart = karts[target_i]
	orb.vel = Vector3(0, -6.0, 0) + victim.vel_dir * maxf(victim.speed, 0.0)
	orbs.append(orb)

func _test_tick() -> void:
	if _test_mode == "immunity":
		# stage machine on sim time; orb drops take ~0.4s to land
		if _test_stage == 0 and now >= 1.0:
			_test_stage = 1
			_drop_orb_on(0, 1)  # -> swap 1
		elif _test_stage == 1 and now >= 1.8:
			_test_stage = 2
			_drop_orb_on(2, 1)  # within immunity -> must be blocked
		elif _test_stage == 2 and now >= 3.5:
			_test_stage = 3
			_drop_orb_on(2, 1)  # immunity expired -> swap 2
		elif _test_stage == 3 and now >= 4.6:
			_test_stage = 4
			var ok: bool = _swaps_total == 2 and _swaps_blocked >= 1
			print("SWAPMEET_TEST immunity swaps=%d blocked=%d: %s" %
				[_swaps_total, _swaps_blocked, "PASS" if ok else "FAIL"])
			if _autoquit:
				get_tree().quit()
	elif _test_mode == "moment":
		if _test_stage == 0 and now >= 1.0:
			_test_stage = 1
			karts[0].orb_cd = 0.0
			_throw_orb(karts[0])

## Verify demo (--photofin): stage two bot karts a hair apart on the final
## approach to the line, laps set so the next crossing finishes the race.
## They race the last ~2 units and pip each other -> the real _finish_kart
## path fires the photo finish. Run with --players=2. Not a sim path used
## by normal play, so it can't affect same-seed determinism.
func _setup_photofin() -> void:
	laps_total = 1
	phase = Phase.PLAY
	var line: float = track.total_len
	var setups: Array = [[2.2, -0.5], [3.0, 0.5]]   # [distance before line, lateral]
	var n: int = mini(karts.size(), 2)
	for i in n:
		var kart: SwapKart = karts[i]
		var s0: float = line - float(setups[i][0])
		kart.place_at(s0, float(setups[i][1]))
		kart.progress = s0            # a hair under one full lap
		kart.last_s_eff = s0
		kart.laps_hw = 0              # next line-cross => finish (laps_total == 1)
		kart.gates_credited = _gates_below(kart.progress)
		kart.orb_cd = 999.0           # no orb throws to disturb the run
		kart.locked = false
	for i in range(2, karts.size()):
		var k: SwapKart = karts[i]
		k.place_at(line - 16.0, 1.6)  # parked well back, out of the way
		k.locked = true
		k.parked = true
	_update_score_rows()
	print("PHOTOFIN demo armed laps=%d line=%.1f seats=%d" % [laps_total, line, n])

## --- FX -------------------------------------------------------------------------------------

func _swap_fx(pos: Vector3, col_arriving: Color, col_departing: Color) -> void:
	for cfg in [[col_departing, 0.85, 0.55], [col_arriving, 0.45, 0.95]]:
		var col: Color = cfg[0]
		var beam: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = float(cfg[1])
		cm.bottom_radius = float(cfg[1])
		cm.height = 7.0
		beam.mesh = cm
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(col.r, col.g, col.b, float(cfg[2]))
		beam.material_override = mat
		_fx_root.add_child(beam)
		beam.global_position = Vector3(pos.x, 3.2, pos.z)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(beam, "scale", Vector3(0.15, 1.15, 0.15), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
		tw.chain().tween_callback(beam.queue_free)
	_burst(pos, col_arriving, 18)
	_burst(pos + Vector3(0, 0.5, 0), col_departing, 12)
	# ground shock ring
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	ring.mesh = tm
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(col_arriving.r, col_arriving.g, col_arriving.b, 0.8)
	ring.material_override = rmat
	_fx_root.add_child(ring)
	ring.global_position = Vector3(pos.x, 0.1, pos.z)
	var tw2: Tween = create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(rmat, "albedo_color:a", 0.0, 0.45)
	tw2.chain().tween_callback(ring.queue_free)

func _burst(pos: Vector3, color: Color, amount: int) -> void:
	var part: CPUParticles3D = CPUParticles3D.new()
	_fx_root.add_child(part)
	part.global_position = pos
	part.one_shot = true
	part.amount = amount
	part.lifetime = 0.7
	part.explosiveness = 1.0
	part.direction = Vector3.UP
	part.spread = 180.0
	part.initial_velocity_min = 2.0
	part.initial_velocity_max = 5.0
	part.gravity = Vector3(0, -4, 0)
	part.damping_min = 1.0
	part.damping_max = 2.5
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	part.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	part.material_override = mat
	part.emitting = true
	get_tree().create_timer(1.4, true, false, true).timeout.connect(part.queue_free)

func _confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p: CPUParticles3D = CPUParticles3D.new()
		_fx_root.add_child(p)
		p.global_position = pos + Vector3(0, 0.5, 0)
		p.one_shot = true
		p.amount = 18
		p.lifetime = 1.2
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 7.5
		p.gravity = Vector3(0, -9, 0)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.09, 0.02, 0.09)
		p.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.2, true, false, true).timeout.connect(p.queue_free)

## --- presentation ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_vis_t += delta
	_update_chase_views(delta)
	if _mirror:
		_animate_mirror_pickups(delta)
	if phase == Phase.WAIT:
		return
	if _event_label.visible and now > _event_until:
		_event_label.visible = false
	# M2 CONTROL HINTS: the controls bar stays up the whole game (the "always on"
	# house policy) — the 9s auto-declutter is gone.
	if _shake > 0.002:
		var jx: float = randf_range(-1.0, 1.0)
		_cam.h_offset = jx * _shake * 0.35
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		ShakeKit.roll(_cam, _shake, jx)   # rotational force, reusing the jitter above
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-5.0 * delta))
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
		ShakeKit.clear(_cam)
	# shortcut arrow bob
	var arrow: Node3D = track.get_node_or_null("ScArrow") as Node3D
	if arrow != null:
		(arrow as Node3D).position.y = 1.7 + 0.22 * sin(_vis_t * 3.2)
	_shotsec_tick()

func _animate_mirror_pickups(delta: float) -> void:
	_animate_pickup_records(_item_boxes, delta)
	_animate_pickup_records(_orb_pickups, delta)

func _animate_pickup_records(records: Array[Dictionary], delta: float) -> void:
	for record: Dictionary in records:
		if not bool(record.get("active", false)):
			continue
		var node: Node3D = record.get("node", null) as Node3D
		if node == null or not is_instance_valid(node):
			continue
		node.rotate_y(delta * 2.0)
		node.position.y = float(record.get("base_y", node.position.y)) \
			+ 0.12 * sin(_vis_t * 3.0 + float(record.get("phase", 0.0)))

func _shotsec_tick() -> void:
	if _shotsec.is_empty():
		return
	if _vis_t < float(_shotsec[0]):
		return
	_shotsec.pop_front()
	_shot_i += 1
	var idx: int = _shot_i
	_capture_shot(idx)

func _capture_shot(idx: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))
	var path: String = "res://verify_out/shotsec_%02d.png" % idx
	img.save_png(path)
	print("SHOTSEC ", path)
	if _shotsec.is_empty() and _autoquit:
		get_tree().quit()

## --- UI -----------------------------------------------------------------------------------------

func _build_ui() -> void:
	var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	var baloo: Font = load("res://assets/fonts/Baloo2.ttf")
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	_timer_label = _mk_label(lg, 38, 9)
	_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_timer_label.offset_top = 6
	ui.add_child(_timer_label)
	_lap_label = _mk_label(lg, 26, 7)
	_lap_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lap_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_lap_label.offset_top = 52
	ui.add_child(_lap_label)
	_event_label = _mk_label(baloo, 23, 6)
	_event_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_event_label.offset_top = 88
	_event_label.visible = false
	ui.add_child(_event_label)
	# flashbulb overlay (photo finish). Added BEFORE the banner so the
	# "PHOTO FINISH" text still reads on top of the white pop.
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.visible = false
	ui.add_child(_flash_rect)
	_banner = RichTextLabel.new()
	_banner.bbcode_enabled = true
	_banner.fit_content = true
	_banner.scroll_active = false
	_banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.offset_top = 250.0
	_banner.add_theme_font_override("normal_font", lg)
	_banner.add_theme_font_size_override("normal_font_size", 52)
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.09))
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.visible = false
	ui.add_child(_banner)
	_score_rows = VBoxContainer.new()
	_score_rows.position = Vector2(16, 10)
	ui.add_child(_score_rows)
	_hint_label = _mk_label(baloo, 19, 6)
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.offset_bottom = -8
	_hint_label.text = "STEER move · A = USE ITEM / THROW ORB · hold B = DRIFT, release = BOOST"
	_hint_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	ui.add_child(_hint_label)

func _mk_label(font: Font, size: int, outline: int) -> Label:
	var l: Label = Label.new()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.09))
	l.add_theme_constant_override("outline_size", outline)
	return l

## ---- live-binding hint bar (real keys, not "A"/"B"; docs/verify/realkeys-VERIFY.md) ----
## Self-contained per the template; presentation only. Bindings are fixed per
## match, so the bar is built once at match start (from begin()).

## Seats driven by a HUMAN with a real device (not a bot, not unassigned). The
## bar personalizes only these.
func _human_seats() -> Array:
	var out: Array = []
	for i in bot_enabled.size():
		if not bot_enabled[i] and PlayerInput.device_of(i) != -99:
			out.append(i)
	return out

## Seats whose bindings the hint bar prints: the live humans, or seat 0 as a
## representative when a bot-only demo has no humans — so the bar always shows
## a REAL key, never an abstract "A =" verb (doc 14 nit 3, notation consistency).
func _hint_seats() -> Array:
	var seats: Array = _human_seats()
	return seats if not seats.is_empty() else [0]

## One button's live legend: "KEY = LABEL" when every hint seat shares the key
## (all pads -> "(A) = ..."), else the per-seat "LABEL: KEY/NAME · KEY/NAME" form.
func _btn_hint(action: String, label: String) -> String:
	var seats: Array = _hint_seats()
	var keys: Array[String] = []
	var same: bool = true
	for i in seats:
		var k: String = PlayerInput.describe_binding(int(i), action)
		if not keys.is_empty() and k != keys[0]:
			same = false
		keys.append(k)
	if same:
		return "%s = %s" % [keys[0], label]
	var parts: Array[String] = []
	for j in seats.size():
		parts.append("%s/%s" % [keys[j], GameState.PLAYER_NAMES[int(seats[j])]])
	return "%s: %s" % [label, " · ".join(parts)]

## The main hint bar, always real keys via describe_binding (matches the card).
func _controls_bar() -> String:
	return "STEER move   ·   %s   ·   %s" % [
		_btn_hint("a", "USE ITEM / THROW ORB"), _btn_hint("b", "DRIFT hold / BOOST release")]

func _update_score_rows() -> void:
	if _row_labels.is_empty():
		var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
		for i in karts.size():
			# Row is an HBox: [PlayerBadge, Label]. Slots are ranked by race
			# position, so the badge's player is reassigned each frame below.
			var hb: HBoxContainer = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			hb.add_child(PlayerBadge.make(0, 24))
			var l: Label = _mk_label(lg, 24, 7)
			hb.add_child(l)
			_score_rows.add_child(hb)
			_row_labels.append(l)
	var order: Array = _positions_list()
	for pi in order.size():
		var kart: SwapKart = karts[order[pi]]
		var l: Label = _row_labels[pi]
		var badge: PlayerBadge = l.get_parent().get_child(0) as PlayerBadge
		badge.player_index = kart.index
		badge.color = kart.color
		badge.dim = 1.0 if not kart.finished else 0.6
		var extra: String = ""
		if kart.finished:
			extra = "  FIN"
		elif kart.has_golden:
			extra = "  [GOLD ORB]"
		elif kart.held_item != ITEM_NONE:
			extra = "  [%s]" % item_name(kart.held_item)
		elif kart.orb_charges > 0:
			extra = "  [SWAP ORB]"
		l.text = "P%d %s · %d%s" % [pi + 1, kart.pname, int(_points[kart.index]), extra]
		l.add_theme_color_override("font_color", kart.color)

func _update_timer_label() -> void:
	var t: int = int(race_t)
	_timer_label.text = "%d:%02d" % [t / 60, t % 60]
	_timer_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.35) if time_cap - race_t < 20.0 and phase == Phase.PLAY else Color.WHITE)
	var lead: int = _leader_all()
	var lead_lap: int = clampi((karts[lead] as SwapKart).laps_hw + 1, 1, laps_total)
	if phase == Phase.END:
		_lap_label.text = "RACE OVER"
	else:
		_lap_label.text = "LAP %d/%d" % [lead_lap, laps_total]

func _flash_banner(bb: String, duration: float) -> void:
	_banner_gen += 1
	if not _mirror:
		_net_ban = [_banner_gen, bb, duration]   # mirror replays this flasher
	var gen: int = _banner_gen
	_banner.text = "[center]%s[/center]" % bb
	_banner.visible = true
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.5, 0.5)
	var pop: Tween = create_tween()
	pop.tween_property(_banner, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw: Tween = create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func() -> void:
			if _banner_gen == gen:
				_banner.visible = false)

func _flash_event(text: String, color: Color) -> void:
	if not _mirror:
		_net_ev_gen += 1
		_net_ev = [_net_ev_gen, text, color.to_html(false)]
	_event_label.text = text
	_event_label.add_theme_color_override("font_color", color)
	_event_label.visible = true
	_event_until = now + 2.4

## --- ONLINE (phase 2): the render mirror ----------------------------------------------------------
# Physics stays HOST-SIDE; the client renders. Karts ride a PackedInt32Array
# (NET_KART_STRIDE: motion + inventory + debuff facts); projectiles/coffins are
# keyed by wire id; pickup visibility, crown, gold and windmill ride facts.
# Progress + finished flags make _positions_list(), the ladder HUD and the
# FINAL STRETCH distance ticks work on the client through the SAME functions
# the host runs.

## HOST, pumped by the estate at 20 Hz. Compact PUBLIC facts only.
func _net_state() -> Dictionary:
	var kd: PackedInt32Array = PackedInt32Array()
	for k in karts:
		var kart: SwapKart = k
		var fl: int = 0
		if kart.drifting:
			fl |= 1
		if kart.boost_t > 0.0:
			fl |= 4 if kart.boost_amt >= SwapKart.BOOST_TURBO - 0.1 else 2
		if kart.finished:
			fl |= 8
		if kart.has_golden:
			fl |= 16
		if kart.swap_immune > 0.0:
			fl |= 32
		if kart.locked:
			fl |= 64
		if kart.airborne:
			fl |= 128
		if kart.on_shortcut:
			fl |= 256
		if kart.orb_cd <= 0.0:
			fl |= 512
		kd.append_array(PackedInt32Array([
			int(roundf(kart.global_position.x * 100.0)),
			int(roundf(kart.y * 100.0)),
			int(roundf(kart.global_position.z * 100.0)),
			int(roundf(atan2(kart.heading.x, kart.heading.z) * 1000.0)),
			int(roundf(kart.speed * 100.0)),
			int(roundf(kart.steer * 100.0)),
			int(roundf(kart.progress * 100.0)),
			fl,
			int(roundf(kart.drift_t * 100.0)),
			kart.finish_place,
			kart.net_anim_id, kart.net_anim_n,
			kart.held_item, kart.orb_charges,
			int(roundf(kart.bell_slow_t * 100.0)),
			int(roundf(kart.crow_t * 100.0)),
			int(roundf(kart.tumble_t * 100.0))]))
	var ob: Array = []
	for o in orbs:
		var orb: SwapOrb = o
		if orb.dead or not is_instance_valid(orb):
			continue
		var orb_type: int = 1 if orb.golden else (2 if orb.shell else 0)
		ob.append([orb.oid,
			int(roundf(orb.global_position.x * 100.0)),
			int(roundf(orb.global_position.y * 100.0)),
			int(roundf(orb.global_position.z * 100.0)),
			orb_type, orb.owner_idx])
	var coffin_facts: Array = []
	for record: Dictionary in _coffins:
		var coffin_node: Node3D = record.get("node", null) as Node3D
		if coffin_node == null or not is_instance_valid(coffin_node):
			continue
		coffin_facts.append([int(record.get("id", 0)), int(record.get("owner", -1)),
			int(roundf(coffin_node.global_position.x * 100.0)),
			int(roundf(coffin_node.global_position.y * 100.0)),
			int(roundf(coffin_node.global_position.z * 100.0)),
			int(roundf(coffin_node.rotation.y * 1000.0))])
	var item_bits: PackedByteArray = PackedByteArray()
	for record: Dictionary in _item_boxes:
		item_bits.append(1 if bool(record.get("active", false)) else 0)
	var orb_bits: PackedByteArray = PackedByteArray()
	for record: Dictionary in _orb_pickups:
		orb_bits.append(1 if bool(record.get("active", false)) else 0)
	var pts: PackedInt32Array = PackedInt32Array()
	for k in karts:
		pts.append(int(_points[(k as SwapKart).index]))
	var st: Dictionary = {
		"ph": phase, "rt": snappedf(race_t, 0.05), "lmax": laps_total,
		"fl": _final_lap_called,
		"kd": kd, "ob": ob, "cof": coffin_facts, "ib": item_bits,
		"op": orb_bits, "pts": pts,
		"ban": _net_ban, "ev": _net_ev,
		"sw": _net_swap, "pf": _net_pf,
		"kn": _net_knock, "bo": _net_bounce, "gp": _net_gp, "gc": _net_gc,
		"ov": _net_ov, "cr": _crown_on, "champ": _net_champ,
		"bm": _boom_wire_angles(),
	}
	if _gold_pickup != null:
		st["gold"] = [int(roundf(_gold_spot.x * 100.0)), int(roundf(_gold_spot.y * 100.0)),
			int(roundf(_gold_spot.z * 100.0))]
	return st

func _boom_wire_angles() -> PackedInt32Array:
	var angles: PackedInt32Array = PackedInt32Array()
	for boom: Dictionary in _booms:
		angles.append(int(roundf(float(boom.get("angle", 0.0)) * 1000.0)))
	return angles


## CLIENT. Latest-state-wins; all juice fires from DELTAS. Continuous motion
## only sets targets; _mirror_tick interpolates at the render rate.
func _net_apply(st: Dictionary) -> void:
	if not _mirror:
		return
	var prev: Dictionary = _mir
	_mir = st
	phase = int(st.get("ph", Phase.WAIT))
	race_t = float(st.get("rt", race_t))
	laps_total = int(st.get("lmax", laps_total))
	if prev.is_empty() and _stretch != null:
		_stretch.play_started()   # FINAL STRETCH: light bed on first snapshot
	# FINAL LAP flip (the stretch's escalation fact; its banner rides ban)
	if _stretch != null and bool(st.get("fl", false)) and not bool(prev.get("fl", false)):
		_stretch.escalate()
		_mir_latch("mirror_finallap")
	# --- karts: interp targets + instant facts; edges vs the PREVIOUS snapshot
	var kd: PackedInt32Array = st.get("kd", PackedInt32Array())
	var pkd: PackedInt32Array = prev.get("kd", PackedInt32Array())
	var fin_n: int = 0
	for i: int in karts.size():
		var o: int = i * NET_KART_STRIDE
		if o + NET_KART_STRIDE > kd.size():
			break
		var kart: SwapKart = karts[i]
		_mir_karts[i][0] = Vector3(kd[o] / 100.0, kd[o + 1] / 100.0, kd[o + 2] / 100.0)
		_mir_karts[i][1] = kd[o + 3] / 1000.0
		kart.y = kd[o + 1] / 100.0
		kart.speed = kd[o + 4] / 100.0
		kart.steer = kd[o + 5] / 100.0
		kart.progress = kd[o + 6] / 100.0
		kart.laps_hw = int(floorf(kart.progress / track.total_len))   # lap HUD
		kart.drift_t = kd[o + 8] / 100.0
		kart.finish_place = kd[o + 9]
		var fl: int = kd[o + 7]
		var pfl: int = pkd[o + 7] if o + NET_KART_STRIDE <= pkd.size() else 0
		kart.drifting = (fl & 1) != 0
		kart.boost_t = 1.0 if (fl & 6) != 0 else 0.0
		if (fl & 6) != 0 and (pfl & 6) == 0:
			var tier: int = 2 if (fl & 4) != 0 else 1
			Sfx.play("bumper", -6.0 if tier == 1 else -1.0)
			if tier == 2:
				_burst(kart.global_position + Vector3(0, 0.3, 0), Color(0.8, 0.5, 1.0), 10)
		kart.has_golden = (fl & 16) != 0
		kart.swap_immune = 1.0 if (fl & 32) != 0 else 0.0
		kart.locked = (fl & 64) != 0
		var air: bool = (fl & 128) != 0
		if air and (pfl & 128) == 0:
			Sfx.play("putt", -4.0)             # ramp launch
		elif not air and (pfl & 128) != 0:
			_burst(kart.global_position, Color(0.8, 0.72, 0.6), 8)
			Sfx.play("place", -6.0)            # landing
		kart.airborne = air
		kart.on_shortcut = (fl & 256) != 0
		kart.orb_cd = 0.0 if (fl & 512) != 0 else 1.0
		var fin: bool = (fl & 8) != 0
		if fin and (pfl & 8) == 0:
			Sfx.play("round_over", -6.0)
			kart.cheer_forever()
		kart.finished = fin
		if fin:
			fin_n += 1
		# one-shot anims off the counter delta (Throw includes its whoosh)
		var an: int = kd[o + 11]
		var pan: int = pkd[o + 11] if o + NET_KART_STRIDE <= pkd.size() else an
		if an != pan:
			var throw: bool = kd[o + 10] == 1
			kart.play_anim("Throw" if throw else "Hit_A", 0.7 if throw else 0.5)
			if throw:
				Sfx.play("putt")
		kart.held_item = kd[o + 12]
		kart.orb_charges = kd[o + 13]
		kart.bell_slow_t = float(kd[o + 14]) / 100.0
		kart.crow_t = float(kd[o + 15]) / 100.0
		kart.tumble_t = float(kd[o + 16]) / 100.0
	_finish_count = fin_n
	# --- orbs: keyed by wire id; vanish = fizzle/hit burst at last known spot
	var seen: Dictionary = {}
	var orb_facts: Array = st.get("ob", [])
	for fact_value in orb_facts:
		var e: Array = fact_value
		if e.size() < 6:
			continue
		var oid: int = int(e[0])
		var opos: Vector3 = Vector3(int(e[1]) / 100.0, int(e[2]) / 100.0, int(e[3]) / 100.0)
		seen[oid] = true
		if not _mir_orbs.has(oid):
			var orb: SwapOrb = SwapOrb.new()
			var orb_type: int = int(e[4])
			orb.setup(self, int(e[5]), _colors[int(e[5])], orb_type == 1, orb_type == 2)
			_fx_root.add_child(orb)
			orb.global_position = opos
			_mir_orbs[oid] = {"node": orb, "pos": opos}
		else:
			_mir_orbs[oid]["pos"] = opos
	for oid in _mir_orbs.keys():
		if not seen.has(oid):
			var node: SwapOrb = _mir_orbs[oid]["node"]
			if is_instance_valid(node):
				_burst(node.global_position, Color(0.7, 0.8, 0.95, 0.7), 6)
				node.queue_free()
			_mir_orbs.erase(oid)
	var coffin_facts: Array = st.get("cof", [])
	var item_bits: PackedByteArray = st.get("ib", PackedByteArray())
	var orb_bits: PackedByteArray = st.get("op", PackedByteArray())
	_apply_mirror_coffins(coffin_facts)
	_apply_pickup_visibility(_item_boxes, item_bits)
	_apply_pickup_visibility(_orb_pickups, orb_bits)
	# --- golden pickup lifecycle (claim burst rides the gc counter)
	if st.has("gold"):
		if _gold_pickup == null:
			var g: Array = st["gold"]
			if g.size() >= 3:
				_build_gold_pickup(Vector3(int(g[0]) / 100.0, int(g[1]) / 100.0, int(g[2]) / 100.0))
			else:
				_build_gold_pickup(Vector3(int(g[0]) / 100.0, 0.0, int(g[1]) / 100.0))
			Sfx.play("confirm", -2.0)
	elif _gold_pickup != null:
		_gold_pickup.queue_free()
		_gold_pickup = null
	# --- windmill booms: resync the sweep (advanced locally in _mirror_tick)
	var bm: PackedInt32Array = st.get("bm", PackedInt32Array())
	for i2: int in mini(bm.size(), _booms.size()):
		var boom: Dictionary = _booms[i2]
		boom["angle"] = fposmod(float(int(bm[i2])) / 1000.0, TAU)
	# --- crown owner (position glued in _mirror_tick; sting rides ov)
	_crown_on = int(st.get("cr", -1))
	# --- juice counters
	if int(st.get("ov", 0)) > int(prev.get("ov", 0)):
		_overtake_next = now - 1.0   # wire already gated the cooldown
		_overtake_sting()
	var sw: Array = st.get("sw", [0])
	var psw: Array = prev.get("sw", [0])
	if sw.size() >= 6 and int(sw[0]) > int(psw[0]):
		var ai: int = int(sw[1])
		var bi: int = int(sw[2])
		var gold: bool = int(sw[3]) == 1
		_swap_fx(sw[4], _colors[ai], _colors[bi])
		_swap_fx(sw[5], _colors[bi], _colors[ai])
		_shake = maxf(_shake, 0.55 if gold else 0.4)
		Sfx.play("sink")
		Sfx.play("bumper", -4.0)
		karts[ai].flash_tag()
		karts[bi].flash_tag()
		print("SWAP_MIRROR swap a=%d b=%d golden=%s" % [ai, bi, str(gold)])
		_mir_latch("mirror_swap")
	var pf: Array = st.get("pf", [0])
	var ppf: Array = prev.get("pf", [0])
	if pf.size() >= 4 and int(pf[0]) > int(ppf[0]):
		_mir_photo_finish(int(pf[1]), int(pf[2]))
	var kn: Array = st.get("kn", [0])
	if kn.size() >= 2 and int(kn[0]) > int(prev.get("kn", [0])[0]):
		var vic: int = int(kn[1])
		Sfx.play("crush")
		_shake = maxf(_shake, 0.22)
		if vic >= 0 and vic < karts.size():
			_burst((karts[vic] as SwapKart).center(), Color(1.0, 0.9, 0.6), 14)
	var bo: Array = st.get("bo", [0])
	if bo.size() >= 2 and int(bo[0]) > int(prev.get("bo", [0])[0]):
		Sfx.play("bounce", -8.0)
	var gp: Array = st.get("gp", [0])
	if gp.size() >= 3 and int(gp[0]) > int(prev.get("gp", [0])[0]):
		track.pulse_gate(int(gp[1]), Color(str(gp[2])))
		Sfx.play("card", -5.0)
	var gc: Array = st.get("gc", [0])
	if gc.size() >= 2 and int(gc[0]) > int(prev.get("gc", [0])[0]):
		var who: int = int(gc[1])
		Sfx.play("sink", -3.0)
		if who >= 0 and who < karts.size():
			_burst((karts[who] as SwapKart).center(), Color(1.0, 0.85, 0.25), 20)
	# --- champion (minted at END, 1.8 s before finished(); banner rides ban)
	var champ: int = int(st.get("champ", -1))
	if champ >= 0 and int(prev.get("champ", -1)) < 0:
		Sfx.play("match_win")
		_confetti((karts[champ] as SwapKart).center(), _colors[champ])
		_confetti((karts[champ] as SwapKart).center() + Vector3(1.5, 1, 0), Color(1, 0.9, 0.4))
		print("SWAP_MIRROR champ=%d" % champ)
		_mir_latch("mirror_end")
	# --- banner + event line: replay the couch's own flashers off the gens
	var ban: Array = st.get("ban", [0])
	if ban.size() >= 3 and int(ban[0]) != int(prev.get("ban", [0])[0]):
		_flash_banner(str(ban[1]), float(ban[2]))
	var ev: Array = st.get("ev", [0])
	if ev.size() >= 3 and int(ev[0]) != int(prev.get("ev", [0])[0]):
		_flash_event(str(ev[1]), Color(str(ev[2])))
	# --- HUD + the stretch's distance ladder (same functions the host runs)
	var pts: PackedInt32Array = st.get("pts", PackedInt32Array())
	for i3: int in mini(pts.size(), karts.size()):
		_points[(karts[i3] as SwapKart).index] = pts[i3]
	_update_score_rows()
	_update_timer_label()
	if phase == Phase.PLAY:
		_stretch_tick()
		if race_t >= 8.0:
			_mir_latch("mirror_midrace")

func _apply_mirror_coffins(facts: Array) -> void:
	var seen: Dictionary = {}
	for fact_value in facts:
		var fact: Array = fact_value
		if fact.size() < 6:
			continue
		var coffin_id: int = int(fact[0])
		var owner: int = int(fact[1])
		var pos: Vector3 = Vector3(float(fact[2]) / 100.0, float(fact[3]) / 100.0, float(fact[4]) / 100.0)
		var yaw: float = float(fact[5]) / 1000.0
		seen[coffin_id] = true
		if not _mir_coffins.has(coffin_id):
			var color: Color = _colors[owner] if owner >= 0 and owner < _colors.size() else Color.WHITE
			var node: Node3D = _make_coffin(color)
			add_child(node)
			_mir_coffins[coffin_id] = {"node": node}
		var record: Dictionary = _mir_coffins[coffin_id]
		var coffin_node: Node3D = record.get("node", null) as Node3D
		if coffin_node != null:
			coffin_node.global_position = pos
			coffin_node.rotation.y = yaw
	for id_value in _mir_coffins.keys():
		var coffin_id: int = int(id_value)
		if seen.has(coffin_id):
			continue
		var record: Dictionary = _mir_coffins[coffin_id]
		var node: Node3D = record.get("node", null) as Node3D
		if node != null and is_instance_valid(node):
			node.queue_free()
		_mir_coffins.erase(coffin_id)

func _apply_pickup_visibility(records: Array[Dictionary], bits: PackedByteArray) -> void:
	for i: int in mini(records.size(), bits.size()):
		var active: bool = bits[i] != 0
		records[i]["active"] = active
		var node: Node3D = records[i].get("node", null) as Node3D
		if node != null and is_instance_valid(node):
			node.visible = active


## The photo-finish ceremony, mirror side: flash + punch + double confetti now,
## the reveal pop at +0.55 s — banners ride the ban stream. Same real-time
## timers the host uses, so both screens beat together.
func _mir_photo_finish(wi: int, ci: int) -> void:
	_shake = maxf(_shake, 0.5)
	_fov_punch(38.0, 0.85)
	_flashbulb()
	Sfx.play("bumper", -2.0)
	if wi >= 0 and wi < karts.size():
		var line_pos: Vector3 = (karts[wi] as SwapKart).center()
		_confetti(line_pos, _colors[wi])
		if ci >= 0 and ci < karts.size():
			_confetti(line_pos + Vector3(1.4, 0.6, 0.0), _colors[ci])
	print("SWAP_MIRROR photo_finish winner=%d chaser=%d" % [wi, ci])
	_mir_latch("mirror_photofinish")
	get_tree().create_timer(0.55, true, false, true).timeout.connect(func() -> void:
		_flashbulb()
		Sfx.play("match_win", -3.0)
		if wi >= 0 and wi < karts.size():
			_confetti((karts[wi] as SwapKart).center(), _colors[wi])
			_confetti((karts[wi] as SwapKart).center() + Vector3(-1.4, 0.6, 0.0), Color(1, 0.9, 0.4))
		_mir_latch("mirror_photofinish_reveal"))


## CLIENT, per physics tick: interpolate kart/orb transforms toward the latest
## authoritative snapshot (racing NEEDS smooth); glue the crown, bob the gold,
## sweep the booms, advance the local clocks.
func _mirror_tick(delta: float) -> void:
	now += delta
	if _mir.is_empty():
		return
	if phase == Phase.PLAY:
		race_t += delta   # smooth timer between snaps; resynced every apply
	var k: float = 1.0 - exp(-18.0 * delta)
	for i: int in mini(_mir_karts.size(), karts.size()):
		var kart: SwapKart = karts[i]
		var tgt: Vector3 = _mir_karts[i][0]
		if kart.global_position.distance_to(tgt) > 4.0:
			kart.global_position = tgt   # SWAP teleports snap, never glide
		else:
			kart.global_position = kart.global_position.lerp(tgt, k)
		var ny: float = lerp_angle(atan2(kart.heading.x, kart.heading.z), float(_mir_karts[i][1]), k)
		kart.heading = Vector3(sin(ny), 0.0, cos(ny))
		kart.vel_dir = kart.heading
		kart._orient(delta)
	for oid_value in _mir_orbs:
		var oid: int = int(oid_value)
		var rec: Dictionary = _mir_orbs[oid]
		var node: SwapOrb = rec["node"]
		if not is_instance_valid(node):
			continue
		var tp: Vector3 = rec["pos"]
		if node.global_position.distance_to(tp) > 6.0:
			node.global_position = tp
		else:
			node.global_position = node.global_position.lerp(tp, 1.0 - exp(-30.0 * delta))
	# crown glued to the mirrored leader
	if _crown_on >= 0 and _crown_on < karts.size():
		var lead: SwapKart = karts[_crown_on]
		_crown.visible = phase != Phase.WAIT
		_crown.global_position = lead.global_position + Vector3(0, 1.42 + 0.08 * sin(now * 4.0), 0)
		_crown.rotation.y += delta * 1.5
	else:
		_crown.visible = false
	# gold pickup bob
	if _gold_pickup != null:
		_gold_pickup.rotate_y(delta * 2.0)
		(_gold_pickup.get_node("Bob") as Node3D).position.y = 1.0 + 0.18 * sin(now * 3.0)
	# windmill sweep: constant local advance, resynced by every snapshot
	for boom_value in _booms:
		var boom: Dictionary = boom_value
		boom["angle"] = fposmod(float(boom.get("angle", 0.0)) + float(boom.get("speed", 0.0)) * delta, TAU)
		var pivot: Node3D = boom.get("pivot", null) as Node3D
		pivot.rotation.y = -float(boom.get("angle", 0.0))
		var blades: Node3D = boom.get("blades", null) as Node3D
		if blades != null:
			blades.rotate_object_local(Vector3(0, 0, 1), delta * 1.4)


## Mirror-side latched evidence snaps (inert unless the probe harness is up).
func _mir_latch(tag: String) -> void:
	if _mir_snapped.has(tag):
		return
	_mir_snapped[tag] = true
	VerifyCapture.snap(tag)


## Host-side latched evidence snaps at the same beats (probe only; offline and
## headless receipts never activate VerifyCapture).
func _net_snap(tag: String) -> void:
	if _mirror or _net_snapped.has(tag) or not NetSession.is_online() or not NetSession.is_host():
		return
	_net_snapped[tag] = true
	VerifyCapture.snap(tag)


## Probe rig (--swapnetdemo), HOST, at GO: restage as a 1-lap dash. The two
## BOT karts start 2.2 / 3.0 units before the line — the chaser crosses ~0.8 u
## behind, inside the 1.2 u photo margin, so the REAL _finish_kart path fires
## the PHOTO FINISH. Human/remote karts start further back and finish the same
## short lap, so the whole night still reaches finished().
func _netdemo_stage() -> void:
	laps_total = 1
	var line: float = track.total_len
	var setups: Dictionary = {2: [12.0, -0.5], 3: [12.4, 0.5], 0: [26.0, 1.2], 1: [30.0, -1.2]}
	for i in karts.size():
		if not setups.has(i):
			continue
		var kart: SwapKart = karts[i]
		var s0: float = line - float(setups[i][0])
		kart.place_at(s0, float(setups[i][1]))
		kart.progress = s0
		kart.last_s_eff = s0
		kart.laps_hw = 0
		kart.gates_credited = _gates_below(kart.progress)
		kart.orb_cd = 999.0
		kart.locked = false
	_netdemo_fire_t = now + 4.2   # after the bots' photo dash, before 0/1 finish
	print("SWAP_NETDEMO staged 1-lap photo dash line=%.1f" % line)


## --- debug/verify surface -------------------------------------------------------------------------

func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_playing() -> bool:
	return phase == Phase.PLAY
