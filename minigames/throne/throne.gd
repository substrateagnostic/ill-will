extends Minigame
## THE THRONE — one throne, four tyrants-in-waiting. Whoever SITS scores every
## second and wields court powers (DECREE BLAST, SUMMON GUARD) but CANNOT move;
## everyone else must gang up to drain the king's GRIP and fling them down the
## steps — then instantly betray each other in a scramble for the empty seat.
## One continuous 2.5-min match; the last 30s is a "succession crisis" worth
## double. Placements by throne-seconds.
##
## Anthology module contract: root of minigames/throne/throne.tscn, extends
## Minigame (begin(config) -> finished(results)). Runs standalone too — if
## begin() isn't called 0.5s after _ready it self-starts a 4-player config
## (GameState colors/names, KayKit chars, seed from --seed= or 1) with bots
## driving the empty seats.
##
## CLI user args (after --):
##   --thronebots         all players are seeded self-play bots
##   --seed=N             rng seed for standalone start (default 1)
##   --players=N          standalone roster size 2..4
##   --matchtime=S        override the 150s match length (min 20)
##   --thronebalance      headless fast bot sim: print per-player throne-time
##                        shares + guard-enclosure assertion, then quit
##   --shots=N,...        handled by the house VerifyCapture autoload (PNGs)

enum Phase { PRE, PLAY, DONE }

const CHAR_SCENES := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]

const ARENA_HALF := 6.0
const DAIS_TOP_Y := 0.51
var SEAT_POS := Vector3(0, DAIS_TOP_Y, 0.12)

const MATCH_TIME := 150.0
const CRISIS_TIME := 30.0          # last 30s: throne scores double
const CRISIS_RATE := 2.0
const NORMAL_RATE := 1.0

const SEAT_RADIUS := 1.7           # touch this close to the seat to claim it
const CEREMONY := 0.4              # coronation delay before the reign is live
const RE_SIT_CD := 2.0

const GRIP_MAX := 3
const GRIP_REGEN := 8.0            # +1 grip every 8s while seated
const LAUNCH_FORCE := 15.0

const DECREE_CD_BASE := 1.8
const DECREE_FATIGUE := 0.2        # each decree while seated is 0.2s slower
const DECREE_RADIUS := 3.6
const DECREE_FORCE := 11.0
const DECREE_TRIGGER := 2.6        # bot: blast when a challenger is this close

const GUARD_LIFE := 6.0
const GUARD_CD := 4.0
const GUARD_RADIUS := 2.35         # distance from centre to plant the wall
const GUARD_TRIGGER := 3.2         # bot: summon when a challenger is this close
const APPROACHES := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]

# ---- match state
var game_time := 0.0
var phase := Phase.PRE
var rng := RandomNumberGenerator.new()
var _match_time := MATCH_TIME

var players: Array = []            # per-player static info dicts
var _royals: Array = []            # index -> Royal
var bot_enabled: Array = []
var bots: ThroneBots

# ---- throne state (one king at a time)
var king := -1                     # index of the seated player, or -1
var seating_index := -1            # who is mid-coronation
var ceremony_t := 0.0
var grip := 0
var grip_regen_t := 0.0
var decree_cd := 0.0
var decree_uses := 0               # fatigue counter, reset each reign
var guard_cd := 0.0
var active_guard: StaticBody3D = null
var reign_start := 0.0
var _last_dethrone_t := -99.0     # keeps the DETHRONES banner its beat vs a fast re-seat

# ---- scoring / stats
var score_accum: Dictionary = {}   # index -> float (crisis-weighted points)
var throne_time: Dictionary = {}   # index -> float (raw seconds seated; fairness metric)
var dethronings: Dictionary = {}   # index -> int (kingslayings)
var longest_reign: Dictionary = {} # index -> float (best single reign)
var _last_coin: Dictionary = {}    # index -> int (coin-tick tracking)
var _currency_log: Array = []
var _highlights: Array = []
var _next_pity_at := 60.0

# ---- modes / fx
var _started := false
var _all_bots := false
var _balance := false
var _balance_scale := 1.0   # faithful physics: time_scale scales the tick delta,
                            # so anything >1 changes movement integration
var _fx := true
var _crisis_announced := false
var _shake := 0.0
var _time_token := 0
var _gold_stream: CPUParticles3D = null

@onready var arena: Node3D = $Arena
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var spawn_root: Node3D = $SpawnRoot
@onready var banner: Label = $UI/Banner
@onready var timer_label: Label = $UI/TimerLabel
@onready var crisis_label: Label = $UI/CrisisLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows

# throne HUD (grip pips + fatigue bar above the king), built in code
var throne_hud: Control
var grip_pips: Array = []
var fatigue_fill: ColorRect

# =====================================================================
func _ready() -> void:
	# cap render fps so --shots frame indices map predictably to game-time
	# (physics is a fixed tick, so this never touches gameplay)
	Engine.max_fps = 60
	_parse_args()
	_build_stage()
	_build_hud()
	banner.visible = false
	crisis_label.visible = false
	await get_tree().create_timer(0.5).timeout
	if not _started:
		_begin(_default_config())

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--thronebots":
			_all_bots = true
		elif arg == "--thronebalance":
			# official fairness probe: real gameplay (FX + slow-mo ON) at
			# time_scale 1, print per-player throne-time shares, then quit
			_balance = true
			_all_bots = true
		elif arg == "--thronebalancefast":
			# reproducible no-FX variant for quick iteration (no slow-mo beats)
			_balance = true
			_all_bots = true
			_fx = false
		elif arg.begins_with("--matchtime="):
			_match_time = maxf(20.0, float(arg.trim_prefix("--matchtime=")))
		elif arg.begins_with("--thronescale="):
			_balance_scale = clampf(float(arg.trim_prefix("--thronescale=")), 1.0, 8.0)

func _seed_from_args() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return 1

func _default_config() -> Dictionary:
	var count := 4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			count = clampi(int(arg.trim_prefix("--players=")), 2, 4)
	var roster: Array = []
	PlayerInput.auto_assign(count)
	for i in count:
		roster.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": CHAR_SCENES[i % CHAR_SCENES.size()],
			"device": PlayerInput.device_of(i),
		})
	return {"roster": roster, "rounds": 1, "rng_seed": _seed_from_args(), "practice": false}

func begin(config: Dictionary) -> void:
	_begin(config)

func _begin(config: Dictionary) -> void:
	if _started:
		return
	_started = true
	rng.seed = int(config.get("rng_seed", 1))
	if _balance:
		Engine.time_scale = _balance_scale
	var roster: Array = config.get("roster", [])
	bots = ThroneBots.new()
	bots.setup(int(config.get("rng_seed", 1)) ^ 0x7405, roster.size())

	for i in roster.size():
		var r: Dictionary = roster[i]
		var col: Color = r.get("color", Color.WHITE)
		players.append({
			"index": int(r.get("index", i)),
			"name": str(r.get("name", "P%d" % i)),
			"color": col,
			"device": int(r.get("device", -99)),
		})
		var dev := int(r.get("device", -99))
		# bot flag convention (fleet-standard): explicit roster "bot" wins,
		# --thronebots forces all, else standalone fills empty seats with bots.
		var is_bot := false
		if _all_bots:
			is_bot = true
		elif r.has("bot"):
			is_bot = bool(r["bot"])
		else:
			is_bot = dev == -3 or dev == -99
		bot_enabled.append(is_bot)

		var char_scene: PackedScene = null
		var char_path := str(r.get("char_scene", ""))
		if char_path != "" and ResourceLoader.exists(char_path):
			char_scene = load(char_path)
		else:
			char_scene = load(CHAR_SCENES[i % CHAR_SCENES.size()])
		var royal := Royal.new()
		royal.name = "Royal%d" % i
		spawn_root.add_child(royal)
		royal.setup(i, col, char_scene, self)
		royal.global_position = _spawn_pos(i, roster.size())
		_royals.append(royal)

		score_accum[i] = 0.0
		throne_time[i] = 0.0
		dethronings[i] = 0
		longest_reign[i] = 0.0
		_last_coin[i] = 0

	hint_label.text = "MOVE   ·   A = SHOVE / DECREE   ·   B = DASH / GUARD   |   SIT THE THRONE TO REIGN"
	print("THRONE_BEGIN players=%d seed=%d bots=%s balance=%s" % [
		players.size(), int(config.get("rng_seed", 1)), str(bot_enabled), str(_balance)])
	_start_match()

func _spawn_pos(i: int, n: int) -> Vector3:
	# ring the challengers around the dais, evenly spread
	var ang := TAU * float(i) / float(maxi(n, 1)) + PI * 0.25
	var radius := 4.6
	return Vector3(cos(ang) * radius, 0.1, sin(ang) * radius)

func _start_match() -> void:
	phase = Phase.PLAY
	game_time = 0.0
	_rebuild_scoreboard()
	if _fx:
		_flash_banner("SEIZE THE THRONE", Color(1, 0.85, 0.25), 2.2)

# =====================================================================
# main loop
# =====================================================================
func _physics_process(delta: float) -> void:
	if _shake > 0.001:
		cam.h_offset = rng.randf_range(-1, 1) * _shake * 0.3
		cam.v_offset = rng.randf_range(-1, 1) * _shake * 0.3
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	if phase != Phase.PLAY:
		return
	game_time += delta
	_update_timer_label()

	# court cooldowns
	if decree_cd > 0.0: decree_cd -= delta
	if guard_cd > 0.0: guard_cd -= delta
	_tick_guard(delta)

	# drive every player (bots or humans)
	for i in players.size():
		var r: Royal = _royals[i]
		if bot_enabled[i]:
			var intent: Dictionary = bots.decide(i, self, delta)
			_apply_intent(i, r, intent.get("move", Vector2.ZERO), bool(intent.get("a", false)), bool(intent.get("b", false)))
		else:
			var mv := PlayerInput.get_move(i)
			_apply_intent(i, r, mv, PlayerInput.just_pressed(i, "a"), PlayerInput.just_pressed(i, "b"))

	_update_seating(delta)
	_update_reign(delta)
	_update_pity()

	if game_time >= _match_time:
		_finish_match()

func _apply_intent(i: int, r: Royal, mv: Vector2, a: bool, b: bool) -> void:
	if i == king:
		if ceremony_t > 0.0:
			return
		if a:
			_try_decree()
		if b:
			_try_guard()
	else:
		r.move_input = mv
		if a:
			r.want_shove = true
		if b:
			r.want_dash = true

# =====================================================================
# seating / coronation
# =====================================================================
func _update_seating(delta: float) -> void:
	if seating_index >= 0:
		ceremony_t -= delta
		var sr: Royal = _royals[seating_index]
		sr.global_position = SEAT_POS
		if ceremony_t <= 0.0:
			_crown(seating_index)
		return
	if king >= 0:
		return
	# find the nearest eligible challenger touching the seat
	var best := -1
	var bestd := SEAT_RADIUS
	for r in _royals:
		if r.is_king or r.re_sit_cd > 0.0:
			continue
		var d: float = Vector2(r.global_position.x - SEAT_POS.x, r.global_position.z - SEAT_POS.z).length()
		if d < bestd:
			bestd = d
			best = r.index
	if best >= 0:
		_begin_coronation(best)

func _begin_coronation(i: int) -> void:
	seating_index = i
	ceremony_t = CEREMONY
	king = i                          # occupied (blocks others) but reign not yet live
	var r: Royal = _royals[i]
	r.become_king(SEAT_POS)
	grip = GRIP_MAX
	grip_regen_t = 0.0
	decree_cd = 0.0
	decree_uses = 0
	guard_cd = 0.0
	reign_start = game_time
	_attach_crown(r)
	_set_gold_stream(true)
	print("THRONE_CROWN t=%.1f %s takes the seat" % [game_time, players[i].name])
	if _fx:
		Sfx.play("sink", -2.0)
		# don't stomp a just-fired DETHRONES banner on an instant re-seat — the
		# fling deserves its slow-mo beat before the next coronation is announced
		if game_time - _last_dethrone_t > 1.1:
			_flash_banner("%s TAKES THE THRONE" % players[i].name, players[i].color, 1.6)
	_rebuild_scoreboard()

func _crown(i: int) -> void:
	seating_index = -1
	ceremony_t = 0.0
	reign_start = game_time           # reign officially starts now
	if _fx:
		Sfx.play("confirm")

func _update_reign(delta: float) -> void:
	_update_throne_hud()
	if king < 0 or seating_index >= 0:
		return
	# score + coin tick
	var crisis := _match_time - game_time <= CRISIS_TIME
	var rate := CRISIS_RATE if crisis else NORMAL_RATE
	score_accum[king] += rate * delta
	throne_time[king] += delta
	var whole := int(score_accum[king])
	if whole > _last_coin[king]:
		_last_coin[king] = whole
		if _fx:
			Sfx.play("card", -8.0, 0.02 if not crisis else 0.12)
		_rebuild_scoreboard()
	# grip regen
	if grip < GRIP_MAX:
		grip_regen_t += delta
		if grip_regen_t >= GRIP_REGEN:
			grip_regen_t = 0.0
			grip += 1
			_update_throne_hud()

# =====================================================================
# court powers
# =====================================================================
func _try_decree() -> void:
	if king < 0 or decree_cd > 0.0 or ceremony_t > 0.0:
		return
	decree_cd = DECREE_CD_BASE + float(decree_uses) * DECREE_FATIGUE
	decree_uses += 1
	var hits := 0
	for r in _royals:
		if r.is_king:
			continue
		var to: Vector3 = r.global_position - SEAT_POS
		to.y = 0.0
		var d := to.length()
		if d <= DECREE_RADIUS:
			var falloff := clampf(1.0 - d / DECREE_RADIUS, 0.35, 1.0)
			var dir := to.normalized() if d > 0.05 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
			r.apply_blast(dir, DECREE_FORCE * falloff)
			hits += 1
	if _fx:
		Sfx.play("bumper", 1.0)
		_spawn_shockwave(SEAT_POS, players[king].color)
		_shake = maxf(_shake, 0.45)
		_update_throne_hud()

func _try_guard() -> void:
	if king < 0 or guard_cd > 0.0 or ceremony_t > 0.0 or active_guard != null:
		return
	var approach := _pick_threatened_approach()
	# SAFETY ASSERTION (spec Risk): a guard can never fully enclose the dais.
	# Only one guard exists at a time, so at least APPROACHES-1 approaches stay
	# open. Compute and assert it, and print the check for the record.
	var blocked_after := 1
	var open_after := APPROACHES.size() - blocked_after
	assert(open_after >= 1, "guard placement would fully enclose the dais")
	print("THRONE_GUARD king=%s approach=%d blocked=%d/%d open=%d (>=1 OK)" % [
		players[king].name, approach, blocked_after, APPROACHES.size(), open_after])
	guard_cd = GUARD_CD
	_spawn_guard(approach)
	if _fx:
		Sfx.play("place", -1.0)

func _pick_threatened_approach() -> int:
	# the approach whose outward direction best faces the nearest challenger
	var target := Vector3.ZERO
	var bestd := 1e9
	for r in _royals:
		if r.is_king:
			continue
		var d: float = r.global_position.distance_to(SEAT_POS)
		if d < bestd:
			bestd = d
			target = r.global_position - SEAT_POS
	target.y = 0.0
	if target.length() < 0.05:
		return 0
	var tn := target.normalized()
	var best := 0
	var bestdot := -2.0
	for k in APPROACHES.size():
		var dot: float = (APPROACHES[k] as Vector3).dot(tn)
		if dot > bestdot:
			bestdot = dot
			best = k
	return best

func _spawn_guard(approach: int) -> void:
	var dir: Vector3 = APPROACHES[approach]
	var wall := StaticBody3D.new()
	wall.name = "Guard"
	wall.collision_layer = 4
	wall.collision_mask = 0
	spawn_root.add_child(wall)
	wall.global_position = SEAT_POS + dir * GUARD_RADIUS + Vector3(0, 0.0, 0)
	wall.look_at(SEAT_POS + Vector3(0, wall.global_position.y, 0), Vector3.UP)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 1.4, 0.35)
	cs.shape = box
	cs.position = Vector3(0, 0.7, 0)
	wall.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 1.4, 0.35)
	mi.mesh = bm
	mi.position = Vector3(0, 0.7, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.3, 0.36)
	mat.emission_enabled = true
	mat.emission = players[king].color
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	wall.add_child(mi)
	wall.set_meta("expire", game_time + GUARD_LIFE)
	active_guard = wall

func _tick_guard(_delta: float) -> void:
	if active_guard == null:
		return
	if not is_instance_valid(active_guard):
		active_guard = null
		return
	if game_time >= float(active_guard.get_meta("expire", 0.0)):
		active_guard.queue_free()
		active_guard = null

func _clear_guard() -> void:
	if active_guard != null and is_instance_valid(active_guard):
		active_guard.queue_free()
	active_guard = null

# =====================================================================
# grip / dethrone
# =====================================================================
func on_shove_landed(_pos: Vector3) -> void:
	if _fx:
		_shake = maxf(_shake, 0.18)

func on_king_shoved(attacker: int, dir: Vector3) -> void:
	if king < 0 or seating_index >= 0 or attacker == king:
		return
	grip -= 1
	_update_throne_hud()
	if _fx:
		Sfx.play("bounce", -1.0)
		_shake = maxf(_shake, 0.3)
	if grip <= 0:
		_dethrone(attacker, dir)

func _dethrone(slayer: int, dir: Vector3) -> void:
	var fallen := king
	var reign_len := game_time - reign_start
	_last_dethrone_t = game_time
	longest_reign[fallen] = maxf(longest_reign[fallen], reign_len)
	dethronings[slayer] += 1
	_currency_log.append({"type": "royalty", "player": slayer, "amount": 1,
		"reason": "dethroned %s" % players[fallen].name})
	if _fx:
		_highlights.append("%s DETHRONED %s" % [players[slayer].name, players[fallen].name])

	var r: Royal = _royals[fallen]
	_detach_crown_to_physics(r, dir)
	r.launch(dir, LAUNCH_FORCE)
	_set_gold_stream(false)

	king = -1
	seating_index = -1
	ceremony_t = 0.0
	grip = 0
	decree_uses = 0
	_clear_guard()

	if _fx:
		Sfx.play("splat")
		Sfx.play("death", -3.0)
		_flash_banner("%s DETHRONES %s" % [players[slayer].name, players[fallen].name], players[slayer].color, 1.8)
		_shake = maxf(_shake, 0.95)
		_time_hit(0.2, 0.6)      # slow-mo beat as the crown tumbles down the steps
	print("THRONE_DETHRONE t=%.1f %s dethroned %s (reign %.1fs)" % [game_time, players[slayer].name, players[fallen].name, reign_len])
	_rebuild_scoreboard()

# =====================================================================
# pity (grudge for players locked out of the throne)
# =====================================================================
func _update_pity() -> void:
	if game_time < _next_pity_at:
		return
	var minute := int(round(_next_pity_at / 60.0))
	_next_pity_at += 60.0
	for i in players.size():
		if throne_time[i] <= 0.001:
			_currency_log.append({"type": "grudge", "player": i, "amount": 1,
				"reason": "%d full minute(s) with no throne time" % minute})
			if _fx:
				Sfx.play("grudge")
				_flash_banner("THE COURT PITIES %s" % players[i].name, Color(0.7, 0.75, 0.85), 1.6)
			print("THRONE_PITY t=%.1f court pities %s" % [game_time, players[i].name])

# =====================================================================
# finish
# =====================================================================
func _finish_match() -> void:
	phase = Phase.DONE
	if king >= 0:
		longest_reign[king] = maxf(longest_reign[king], game_time - reign_start)
	if _balance:
		_print_balance()
		get_tree().quit()
		return

	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if score_accum[a] != score_accum[b]:
			return score_accum[a] > score_accum[b]
		return a < b)
	var champ: int = order[0]
	_set_gold_stream(false)
	Sfx.play("match_win")
	_flash_banner("%s RULES\nTHE THRONE" % players[champ].name, players[champ].color, 6.0)
	_spawn_confetti(SEAT_POS + Vector3(0, 1.4, 0), players[champ].color)

	var points: Dictionary = {}
	for i in players.size():
		points[i] = int(score_accum[i])

	# highlights: longest reign + top kingslayer
	var lr_player := -1
	var lr_best := 0.0
	for i in players.size():
		if longest_reign[i] > lr_best:
			lr_best = longest_reign[i]
			lr_player = i
	if lr_player >= 0 and lr_best >= 1.0:
		_highlights.insert(0, "%s held the longest reign: %ds" % [players[lr_player].name, int(round(lr_best))])
	var ks_player := -1
	var ks_best := 0
	for i in players.size():
		if dethronings[i] > ks_best:
			ks_best = dethronings[i]
			ks_player = i
	if ks_player >= 0 and ks_best >= 1:
		_highlights.append("%s: %d kingslaying(s)" % [players[ks_player].name, ks_best])

	var monuments: Array = []
	for i in players.size():
		if dethronings[i] >= 3:
			monuments.append({"player": i, "kind": "usurper",
				"label": "%s, The Usurper" % players[i].name})

	var results := {
		"placements": order,
		"points": points,
		"currency_events": _currency_log.duplicate(),
		"highlights": _dedup(_highlights).slice(0, 3),
		"monuments": monuments,
	}
	print("THRONE_MATCH_OVER champ=%s pts=%d placements=%s points=%s currency=%d highlights=%d monuments=%d" % [
		players[champ].name, points[champ], str(order), str(points), _currency_log.size(), _dedup(_highlights).slice(0, 3).size(), monuments.size()])
	if has_method("report_finished"):
		report_finished(results)
	else:
		finished.emit(results)

func _print_balance() -> void:
	var total := 0.0
	for i in players.size():
		total += throne_time[i]
	var shares: Array = []
	var maxpct := 0.0
	for i in players.size():
		var pct: float = 100.0 * throne_time[i] / maxf(total, 0.001)
		shares.append(pct)
		maxpct = maxf(maxpct, pct)
	var parts: Array = []
	for i in players.size():
		parts.append("%s=%.1f%%(%.1fs)" % [players[i].name, shares[i], throne_time[i]])
	var verdict := "PASS" if maxpct <= 55.0 else "FAIL"
	print("======== THRONE BALANCE ========")
	print("seed=%d match=%.0fs total_seated=%.1fs" % [rng.seed, _match_time, total])
	print("shares: " + ", ".join(PackedStringArray(parts)))
	print("THRONE_BALANCE seed=%d max_share=%.1f%% cap=55%% %s" % [rng.seed, maxpct, verdict])
	var dcounts: Array = []
	for i in players.size():
		dcounts.append("%s=%d" % [players[i].name, dethronings[i]])
	print("dethronings: " + ", ".join(PackedStringArray(dcounts)))
	print("knobs: GRIP_MAX=%d GRIP_REGEN=%.1f DECREE_FATIGUE=%.2f DECREE_FORCE=%.1f LAUNCH=%.1f RE_SIT=%.1f" % [
		GRIP_MAX, GRIP_REGEN, DECREE_FATIGUE, DECREE_FORCE, LAUNCH_FORCE, RE_SIT_CD])
	print("================================")

func _dedup(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		if not out.has(x):
			out.append(x)
	return out

# =====================================================================
# accessors used by bots
# =====================================================================
func royals() -> Array:
	return _royals

func royals_by_index(i: int) -> Royal:
	if i < 0 or i >= _royals.size():
		return null
	return _royals[i]

# =====================================================================
# crown
# =====================================================================
func _make_crown_mesh() -> Node3D:
	var root := Node3D.new()
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 0.2
	band.mesh = tm
	band.rotation_degrees = Vector3(90, 0, 0)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.25)
	gold.metallic = 0.9
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.15)
	gold.emission_energy_multiplier = 0.6
	band.material_override = gold
	root.add_child(band)
	for k in 5:
		var spike := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.0
		pm.bottom_radius = 0.05
		pm.height = 0.18
		spike.mesh = pm
		spike.material_override = gold
		var ang := TAU * k / 5.0
		spike.position = Vector3(cos(ang) * 0.18, 0.11, sin(ang) * 0.18)
		root.add_child(spike)
	return root

func _attach_crown(r: Royal) -> void:
	if r.crown_anchor == null:
		return
	for c in r.crown_anchor.get_children():
		c.queue_free()
	var crown := _make_crown_mesh()
	crown.name = "Crown"
	crown.scale = Vector3(1.35, 1.35, 1.35)
	r.crown_anchor.add_child(crown)

func _detach_crown_to_physics(r: Royal, dir: Vector3) -> void:
	# clear the worn crown and spawn a physics crown that bounces down the steps
	if r.crown_anchor:
		for c in r.crown_anchor.get_children():
			c.queue_free()
	var body := RigidBody3D.new()
	body.name = "FlyingCrown"
	body.collision_layer = 8
	body.collision_mask = 1          # only the environment/steps
	body.mass = 0.4
	body.continuous_cd = true
	spawn_root.add_child(body)
	if r.crown_anchor:
		body.global_position = r.crown_anchor.global_position
	else:
		body.global_position = SEAT_POS + Vector3(0, 1.4, 0)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.55
	pm.friction = 0.4
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	cs.shape = sph
	body.add_child(cs)
	var cm := _make_crown_mesh()
	cm.scale = Vector3(1.4, 1.4, 1.4)
	body.add_child(cm)
	var d := dir.normalized() if dir.length() > 0.05 else Vector3(0, 0, 1)
	body.apply_central_impulse(d * 4.6 + Vector3.UP * 5.2)
	body.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.9)
	get_tree().create_timer(4.5).timeout.connect(func():
		if is_instance_valid(body):
			body.queue_free())

func _set_gold_stream(on: bool) -> void:
	if on:
		if _gold_stream == null:
			_gold_stream = CPUParticles3D.new()
			_gold_stream.name = "GoldStream"
			spawn_root.add_child(_gold_stream)
			_gold_stream.global_position = SEAT_POS + Vector3(0, 0.4, 0)
			_gold_stream.amount = 40
			_gold_stream.lifetime = 1.3
			_gold_stream.direction = Vector3.UP
			_gold_stream.spread = 14.0
			_gold_stream.initial_velocity_min = 1.6
			_gold_stream.initial_velocity_max = 2.8
			_gold_stream.gravity = Vector3(0, 0.7, 0)
			var em := CPUParticles3D.EMISSION_SHAPE_SPHERE
			_gold_stream.emission_shape = em
			_gold_stream.emission_sphere_radius = 0.35
			var mesh := SphereMesh.new()
			mesh.radius = 0.05
			mesh.height = 0.1
			_gold_stream.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.85, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.78, 0.2)
			mat.emission_energy_multiplier = 2.5
			_gold_stream.material_override = mat
		_gold_stream.emitting = true
		_gold_stream.visible = true
	else:
		if _gold_stream != null:
			_gold_stream.emitting = false
			_gold_stream.visible = false

# =====================================================================
# stage
# =====================================================================
func _build_stage() -> void:
	var we: WorldEnvironment = $WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.5, 0.42)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.22
	env.glow_hdr_threshold = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.07, 0.06)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	we.environment = env

	cam.global_position = Vector3(0, 10.6, 11.3)
	cam.look_at(Vector3(0, 1.15, -0.35), Vector3.UP)
	cam.fov = 49.0

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	add_child(sun)
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 0.9
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.shadow_enabled = true

	_build_floor()
	_build_carpet()
	_build_dais()
	_build_throne()
	_build_pillars_and_torches()
	_build_walls()

func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	arena.add_child(floor_body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(12.0, 1.0, 12.0)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(12.0, 1.0, 12.0)
	mi.mesh = bm
	mi.position = Vector3(0, -0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.26, 0.22, 0.2)
	mat.roughness = 0.9
	mi.material_override = mat
	floor_body.add_child(mi)

func _build_carpet() -> void:
	# a warm red rug so the middle reads "throne room", plus a gold trim ring
	var rug := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(9.0, 0.03, 9.0)
	rug.mesh = rm
	rug.position = Vector3(0, 0.02, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.45, 0.09, 0.11)
	rmat.roughness = 0.95
	rug.material_override = rmat
	arena.add_child(rug)
	# a brighter runner leading in from the front (+Z, toward camera)
	var runner := MeshInstance3D.new()
	var run_m := BoxMesh.new()
	run_m.size = Vector3(2.4, 0.04, 6.0)
	runner.mesh = run_m
	runner.position = Vector3(0, 0.03, 4.4)
	var run_mat := StandardMaterial3D.new()
	run_mat.albedo_color = Color(0.62, 0.12, 0.14)
	run_mat.roughness = 0.9
	runner.material_override = run_mat
	arena.add_child(runner)

func _build_dais() -> void:
	# three concentric cylinder steps: challengers climb them, the flung crown
	# bounces down them. All on the environment layer.
	var steps := [
		{"r": 3.0, "h": 0.17, "y": 0.085},
		{"r": 2.5, "h": 0.17, "y": 0.255},
		{"r": 2.0, "h": 0.17, "y": 0.425},
	]
	var idx := 0
	for s in steps:
		var body := StaticBody3D.new()
		body.name = "Step%d" % idx
		body.collision_layer = 1
		body.collision_mask = 0
		arena.add_child(body)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(s["r"])
		cyl.height = float(s["h"])
		cs.shape = cyl
		cs.position = Vector3(0, float(s["y"]), 0)
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(s["r"])
		cm.bottom_radius = float(s["r"])
		cm.height = float(s["h"])
		mi.mesh = cm
		mi.position = Vector3(0, float(s["y"]), 0)
		var mat := StandardMaterial3D.new()
		var shade := 0.34 + idx * 0.05
		mat.albedo_color = Color(shade, shade * 0.9, shade * 0.85)
		mat.roughness = 0.85
		mi.material_override = mat
		body.add_child(mi)
		idx += 1

const THRONE_GLB := "res://assets/models/meshy/throne.glb"
const THRONE_HEIGHT := 2.55       # base->crest height on the dais (was ~2.4 primitive)
const THRONE_YAW := 180.0         # seat opening faces +Z (toward the camera/king)

func _build_throne() -> void:
	# Custom Meshy throne (red tufted high back, gold ornate frame) replacing the
	# box-built throne. Purely visual — no collision here in either version; the
	# king's per-player identity still rides on the Royal body (ring + rim). The
	# GLB is normalized (scaled to THRONE_HEIGHT, base seated at the dais top).
	var base_y := DAIS_TOP_Y
	var throne := MeshyProp.instance(THRONE_GLB, THRONE_HEIGHT, THRONE_YAW)
	throne.name = "ThroneModel"
	throne.position = Vector3(0, base_y, -0.5)
	arena.add_child(throne)

func _build_pillars_and_torches() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.4, 0.37, 0.35)
	stone.roughness = 0.9
	for corner in [Vector3(3.7, 0, 3.7), Vector3(-3.7, 0, 3.7), Vector3(3.7, 0, -3.7), Vector3(-3.7, 0, -3.7)]:
		var pillar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.34
		cm.bottom_radius = 0.4
		cm.height = 4.2
		pillar.mesh = cm
		pillar.position = corner + Vector3(0, 2.1, 0)
		pillar.material_override = stone
		arena.add_child(pillar)
		# torch flame + warm point light at the top
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.16
		fm.height = 0.4
		flame.mesh = fm
		flame.position = corner + Vector3(0, 4.3, 0)
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(1.0, 0.6, 0.2)
		fmat.emission_enabled = true
		fmat.emission = Color(1.0, 0.55, 0.15)
		fmat.emission_energy_multiplier = 4.0
		flame.material_override = fmat
		arena.add_child(flame)
		var torch := OmniLight3D.new()
		torch.position = corner + Vector3(0, 4.3, 0)
		torch.light_color = Color(1.0, 0.62, 0.28)
		torch.light_energy = 3.2
		torch.omni_range = 8.0
		torch.set_meta("base_energy", 3.2)
		torch.name = "Torch"
		arena.add_child(torch)

func _build_walls() -> void:
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 0.17, 0.18)
	wmat.roughness = 0.95
	var defs := [
		{"size": Vector3(12.6, 3.4, 0.4), "pos": Vector3(0, 1.7, -6.2)},
		{"size": Vector3(12.6, 3.4, 0.4), "pos": Vector3(0, 1.7, 6.2)},
		{"size": Vector3(0.4, 3.4, 12.6), "pos": Vector3(-6.2, 1.7, 0)},
		{"size": Vector3(0.4, 3.4, 12.6), "pos": Vector3(6.2, 1.7, 0)},
	]
	for d in defs:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		arena.add_child(body)
		body.position = d["pos"]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = d["size"]
		cs.shape = bs
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = d["size"]
		mi.mesh = bm
		mi.material_override = wmat
		body.add_child(mi)

func _process(delta: float) -> void:
	# torch flicker (visual only; does not touch gameplay state)
	if _fx:
		for t in arena.get_children():
			if t is OmniLight3D:
				var base: float = float(t.get_meta("base_energy", 3.0))
				(t as OmniLight3D).light_energy = base + sin(game_time * 11.0 + t.position.x) * 0.4 + randf_range(-0.15, 0.15)

# =====================================================================
# UI
# =====================================================================
func _build_hud() -> void:
	throne_hud = Control.new()
	throne_hud.name = "ThroneHUD"
	throne_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throne_hud.size = Vector2(140, 44)
	$UI.add_child(throne_hud)
	# GRIP pips
	for i in GRIP_MAX:
		var pip := ColorRect.new()
		pip.size = Vector2(30, 12)
		pip.position = Vector2(i * 36, 0)
		throne_hud.add_child(pip)
		grip_pips.append(pip)
	# fatigue bar background + fill
	var fbg := ColorRect.new()
	fbg.size = Vector2(GRIP_MAX * 36 - 6, 8)
	fbg.position = Vector2(0, 20)
	fbg.color = Color(0, 0, 0, 0.55)
	throne_hud.add_child(fbg)
	fatigue_fill = ColorRect.new()
	fatigue_fill.size = Vector2(0, 8)
	fatigue_fill.position = Vector2(0, 20)
	fatigue_fill.color = Color(1.0, 0.5, 0.15, 0.9)
	throne_hud.add_child(fatigue_fill)
	var lbl := Label.new()
	lbl.name = "FatigueLabel"
	lbl.text = "TYRANNY"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.6))
	lbl.position = Vector2(0, 30)
	throne_hud.add_child(lbl)
	throne_hud.visible = false

func _update_throne_hud() -> void:
	if throne_hud == null:
		return
	if king < 0 or seating_index >= 0:
		throne_hud.visible = false
		return
	var r: Royal = _royals[king]
	var head := r.global_position + Vector3(0, 2.55, 0)
	if not cam.is_position_behind(head):
		var sp := cam.unproject_position(head)
		throne_hud.position = sp - Vector2(throne_hud.size.x * 0.5, 0)
		throne_hud.visible = true
	else:
		throne_hud.visible = false
	var kc: Color = players[king].color
	for i in grip_pips.size():
		var pip: ColorRect = grip_pips[i]
		pip.color = kc if i < grip else Color(0.15, 0.15, 0.17, 0.85)
	# fatigue: fills as the reign burns decrees; the walls close in
	var fat := clampf(float(decree_uses) / 10.0, 0.0, 1.0)
	fatigue_fill.size.x = (GRIP_MAX * 36 - 6) * fat

func _update_timer_label() -> void:
	var remaining: int = int(ceil(maxf(0.0, _match_time - game_time)))
	timer_label.text = "%d:%02d" % [remaining / 60, remaining % 60]
	var crisis := _match_time - game_time <= CRISIS_TIME
	if crisis and not _crisis_announced:
		_crisis_announced = true
		crisis_label.visible = true
		if _fx:
			Sfx.play("round_over")
			_flash_banner("SUCCESSION CRISIS\nTHRONE PAYS DOUBLE", Color(1, 0.4, 0.3), 2.4)
	if crisis:
		timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))

func _flash_banner(text: String, color: Color, duration: float) -> void:
	if not _fx:
		return
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func(): banner.visible = false)

func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if score_accum[a] != score_accum[b]:
			return score_accum[a] > score_accum[b]
		return a < b)
	for i in order:
		var p: Dictionary = players[i]
		var row := Label.new()
		var tag := ""
		if i == king and seating_index < 0:
			tag = "  ♔"
		elif i == seating_index:
			tag = "  …"
		row.text = "%s  %d%s" % [p.name, int(score_accum[i]), tag]
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", p.color)
		row.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
		row.add_theme_constant_override("outline_size", 5)
		score_rows.add_child(row)

# =====================================================================
# fx helpers
# =====================================================================
func _time_hit(scale: float, real_duration: float) -> void:
	if not _fx:
		return
	_time_token += 1
	var my := _time_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_duration, true, false, true).timeout
	if my == _time_token:
		Engine.time_scale = 1.0

func _spawn_shockwave(pos: Vector3, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.5
	ring.mesh = tm
	ring.position = pos + Vector3(0, 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	spawn_root.add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(DECREE_RADIUS * 2.2, 1.0, DECREE_RADIUS * 2.2), 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.85, 0.35), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 24
		p.lifetime = 1.6
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = 3.5
		p.initial_velocity_max = 7.0
		p.gravity = Vector3(0, -7.0, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 0.02, 0.09)
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.4).timeout.connect(p.queue_free)

# =====================================================================
# verify hooks
# =====================================================================
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.PLAY
