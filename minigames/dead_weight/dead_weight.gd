extends Minigame
## DEAD WEIGHT — a sumo brawl in a cozy attic where the knocked-out become
## POLTERGEISTS who possess the furniture and hurl it at the living.
## Extends the anthology Minigame contract: begin(config) -> finished(results).
## Also self-starts standalone (0.5s after _ready) with a default 4-player
## config so the scene runs on its own for testing.

enum Phase { PRE, ROUND, BETWEEN, DONE }

const CHAR_SCENES := [
	preload("res://assets/models/kaykit/Barbarian.glb"),
	preload("res://assets/models/kaykit/Knight.glb"),
	preload("res://assets/models/kaykit/Mage.glb"),
	preload("res://assets/models/kaykit/Rogue.glb"),
]

const ROUND_TIME := 75.0
const KILL_CREDIT_WINDOW := 4.0      # safety cap; recovery-clear is the real gate
const SPAWN_LOCK_TIME := 3.0         # props near spawns unpossessable this long
const SPAWN_LOCK_RADIUS := 2.0
const POINTS_TABLE := [4, 2, 1, 0]
const ROYALTY := 2
const FLOOR_HALF := 6.0

# prop layout: tier + grid-ish scatter (deterministic, jittered by rng)
const PROP_TIERS := ["wardrobe", "crate", "lamp", "chair", "crate", "lamp",
	"wardrobe", "chair", "crate", "lamp", "chair", "crate"]

var game_time := 0.0
var phase := Phase.PRE
var rng := RandomNumberGenerator.new()

var players: Array = []               # per-player match state dicts
var _fighters: Array = []             # index -> DWFighter or null (ghost-start)
var _ghosts: Dictionary = {}          # index -> DWGhost (dead this round)
var _props: Array = []                # Array[DWProp]
var _spawns: Array = []               # Array[Vector3] revival points
var _elim_order: Array = []           # indices in death order this round
var _currency_log: Array = []
var _kill_events: Array = []          # {killer:int, victim:int, cause:String}; killer -1 = void
var _highlights: Array = []
var _last_kill_line := ""             # the kill that ended the round, if any
var _last_kill_color := Color.WHITE

var round_index := 0                  # 0-based
var rounds_total := 3
var round_elapsed := 0.0
var _between_timer := 0.0             # counts down to the next round start
var _round_resolving := false
var _decider := "none"                # what ended the round (balance metric)

# modes
var _started := false
var _all_bots := false
var _aim_probe_on := false
var _aim_probe_deg := 0.0
var _probe_shove := false        # false => poltergeist fling probe, true => living shove
var _dw_probe_manual := false    # skip driving p0 (fling probe steers it directly)
var _balance_rounds := 0
var _balance_tally := {"living": 0, "ghost": 0, "void": 0}
var _dbg := {"possess": 0, "ghost_hits": 0, "round_len": 0.0}
var _ghost_hold: Dictionary = {}      # ghost bot possession dwell timers

# fx
var _shake := 0.0
var _time_token := 0

@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var banner: Label = $UI/Banner
@onready var round_label: Label = $UI/RoundLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var score_rows: VBoxContainer = $UI/ScorePanel/ScoreRows
@onready var spawn_root: Node3D = $SpawnRoot

func _ready() -> void:
	_parse_args()
	_build_stage()
	banner.visible = false
	await get_tree().create_timer(0.5).timeout
	if not _started:
		_begin(_default_config())

# ---------------------------------------------------------------- stage
func _build_stage() -> void:
	var we: WorldEnvironment = $WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.5, 0.62)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.08, 0.14)
	env.fog_density = 0.02
	env.fog_sky_affect = 0.0
	we.environment = env

	cam.global_position = Vector3(0, 13.5, 11.5)
	cam.look_at(Vector3(0, 0.3, -0.4), Vector3.UP)
	cam.fov = 52.0

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	add_child(sun)
	sun.rotation_degrees = Vector3(-56.0, -34.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	add_child(fill)
	fill.rotation_degrees = Vector3(-24.0, 140.0, 0.0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.55, 0.68, 1.0)

	# floor: 12x12 platform with nothing beyond the lip — walk off, you fall
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	$Arena.add_child(floor_body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# a thick slab (top at y=0) so nothing can be shoved down through it —
	# only walking off the ±6 edge drops you into the void
	bs.size = Vector3(12.0, 3.0, 12.0)
	cs.shape = bs
	cs.position = Vector3(0, -1.5, 0)
	floor_body.add_child(cs)
	var fm := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(12.0, 3.0, 12.0)
	fm.mesh = fmesh
	fm.position = Vector3(0, -1.5, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.36, 0.26, 0.19)
	fmat.roughness = 0.85
	fm.material_override = fmat
	floor_body.add_child(fm)

	# a warm rug so the middle reads "cozy attic", not "arena"
	var rug := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(6.5, 0.02, 6.5)
	rug.mesh = rmesh
	rug.position = Vector3(0, 0.011, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.5, 0.22, 0.24)
	rmat.roughness = 0.9
	rug.material_override = rmat
	$Arena.add_child(rug)

	_build_void_ring()

func _build_void_ring() -> void:
	# a glowing gutter at the very lip of the floor: fall past it and you die
	var glow := Color(0.2, 0.95, 1.0)
	var bars := [
		{"size": Vector3(12.4, 0.08, 0.3), "pos": Vector3(0, 0.04, 5.95)},
		{"size": Vector3(12.4, 0.08, 0.3), "pos": Vector3(0, 0.04, -5.95)},
		{"size": Vector3(0.3, 0.08, 12.4), "pos": Vector3(5.95, 0.04, 0)},
		{"size": Vector3(0.3, 0.08, 12.4), "pos": Vector3(-5.95, 0.04, 0)},
	]
	for b in bars:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = b["size"]
		mi.mesh = mesh
		mi.position = b["pos"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = glow
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 4.0
		mi.material_override = mat
		$Arena.add_child(mi)

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--dwbots":
			_all_bots = true
		elif arg.begins_with("--dwbalance="):
			_balance_rounds = maxi(1, int(arg.trim_prefix("--dwbalance=")))
			_all_bots = true
		elif arg.begins_with("--dwrounds="):
			rounds_total = clampi(int(arg.trim_prefix("--dwrounds=")), 1, 9)
		elif arg.begins_with("--aimprobe="):
			_aim_probe_on = true
			_probe_shove = false
			_aim_probe_deg = float(arg.trim_prefix("--aimprobe="))
		elif arg.begins_with("--aimshove="):
			_aim_probe_on = true
			_probe_shove = true
			_aim_probe_deg = float(arg.trim_prefix("--aimshove="))
	if _aim_probe_on:
		_dw_probe_manual = not _probe_shove
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verify_out"))

func _seed_from_args() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return 1

func _default_config() -> Dictionary:
	var count := 4
	var roles: Array = []
	var dwghosts := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			count = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--dwghosts="):
			dwghosts = int(arg.trim_prefix("--dwghosts="))
	if _balance_rounds > 0:
		count = 3
	if _aim_probe_on:
		count = 2   # p0 = KBM human, p1 = inert stand-in (victim / bystander)
	var roster: Array = []
	PlayerInput.auto_assign(count)
	if _aim_probe_on:
		PlayerInput.assign(0, -4)
		PlayerInput.assign(1, -99)
		var av := deg_to_rad(_aim_probe_deg)
		PlayerInput.set_debug_aim(0, Vector3(sin(av), 0.0, cos(av)))
	for i in count:
		roster.append({
			"index": i,
			"name": GameState.PLAYER_NAMES[i],
			"color": GameState.PLAYER_COLORS[i],
			"char_scene": "",
			"device": PlayerInput.device_of(i),
			"bot": false if _aim_probe_on else PlayerInput.standalone_bot_default(i),
		})
	# roles: default all living; balance = last player is a permanent ghost;
	# --dwghosts=N starts the last N players as ghosts.
	for i in count:
		roles.append("living")
	if _balance_rounds > 0:
		roles[count - 1] = "ghost"
	for i in range(count - dwghosts, count):
		if i >= 0:
			roles[i] = "ghost"
	if _aim_probe_on and not _probe_shove:
		roles[0] = "ghost"   # p0 rises as a poltergeist to fling furniture
	return {"roster": roster, "rounds": rounds_total, "rng_seed": _seed_from_args(),
		"practice": false, "roles": roles}

func begin(config: Dictionary) -> void:
	_begin(config)

func _begin(config: Dictionary) -> void:
	_started = true
	rng.seed = int(config.get("rng_seed", 1))
	rounds_total = clampi(int(config.get("rounds", 3)), 1, 9)
	if _balance_rounds > 0:
		rounds_total = _balance_rounds
		Engine.time_scale = 6.0   # sim fast-forward; bot logic runs per physics tick
	var roster: Array = config.get("roster", [])
	var roles: Array = config.get("roles", [])
	players.clear()
	_fighters.clear()
	for i in roster.size():
		var r: Dictionary = roster[i]
		var role := "living"
		if i < roles.size():
			role = str(roles[i])
		players.append({
			"index": int(r.get("index", i)),
			"name": str(r.get("name", "P%d" % i)),
			"color": r.get("color", Color.WHITE),
			"device": int(r.get("device", -99)),
			# Per-player: bot-driven if the roster marks this seat a bot (shell
			# sets it from estate._is_bot; standalone from PlayerInput) OR the
			# legacy --dwbots / --dwbalance flags force ALL bots.
			"is_bot": _all_bots or bool(r.get("bot", false)),
			"role": role,
			"total": 0,
			"ghost_kills": 0,
			"deaths": 0,
			"streak": 0,
			"best_streak": 0,
		})
		var char_path := str(r.get("char_scene", ""))
		var char_scene: PackedScene = null
		if char_path != "" and ResourceLoader.exists(char_path):
			char_scene = load(char_path)
		else:
			char_scene = CHAR_SCENES[i % CHAR_SCENES.size()]
		if role == "living":
			var f := DWFighter.new()
			f.name = "Fighter%d" % i
			spawn_root.add_child(f)
			f.setup(i, players[i].color, char_scene, self)
			f.fell.connect(_on_fighter_fell)
			_fighters.append(f)
		else:
			_fighters.append(null)
	_layout_spawns(players.size())
	_build_props()
	_rebuild_scoreboard()
	hint_label.text = "A = SHOVE   B = HOP   ·   THE DEAD POSSESS THE FURNITURE"
	round_index = 0
	_start_round()
	if _aim_probe_on:
		_run_dw_probe()

func _layout_spawns(count: int) -> void:
	_spawns.clear()
	var corners := [Vector3(-3.2, 0, -3.2), Vector3(3.2, 0, 3.2),
		Vector3(3.2, 0, -3.2), Vector3(-3.2, 0, 3.2)]
	for i in count:
		_spawns.append(corners[i % corners.size()])

func _build_props() -> void:
	# scatter props on a jittered ring/grid, avoiding the spawn corners
	var slots: Array = []
	var cols := 4
	for gx in cols:
		for gz in 3:
			var px := lerpf(-4.0, 4.0, gx / float(cols - 1))
			var pz := lerpf(-3.6, 3.6, gz / 2.0)
			slots.append(Vector3(px, 0, pz))
	for i in PROP_TIERS.size():
		var tier: String = PROP_TIERS[i]
		var prop := DWProp.new()
		prop.name = "Prop%d_%s" % [i, tier]
		spawn_root.add_child(prop)
		var base := Color(0.6, 0.45, 0.32).lerp(Color(0.5, 0.36, 0.5), rng.randf() * 0.5)
		if tier == "wardrobe":
			base = Color(0.45, 0.32, 0.24)
		elif tier == "lamp":
			base = Color(0.85, 0.78, 0.5)
		prop.setup(tier, base, self)
		var slot: Vector3 = slots[i % slots.size()]
		slot += Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		slot = _nudge_off_spawns(slot)
		slot.y = prop.rest_height()
		prop.home_spawn = slot
		_props.append(prop)

func _nudge_off_spawns(slot: Vector3) -> Vector3:
	# never seat a prop on a fighter spawn corner — the physics overlap would
	# fling the fighter off the floor at round start
	var corners := [Vector3(-3.2, 0, -3.2), Vector3(3.2, 0, 3.2),
		Vector3(3.2, 0, -3.2), Vector3(-3.2, 0, 3.2)]
	for _iter in 6:
		var worst := 0.0
		var push := Vector3.ZERO
		for c in corners:
			var d := Vector2(slot.x - c.x, slot.z - c.z).length()
			if d < 2.6 and (2.6 - d) > worst:
				worst = 2.6 - d
				var away := Vector2(slot.x - c.x, slot.z - c.z)
				if away.length() < 0.01:
					away = Vector2(0.5, 0.5)
				away = away.normalized() * 2.7
				push = Vector3(c.x + away.x, 0, c.z + away.y) - slot
		if worst <= 0.0:
			break
		slot += push
		slot.x = clampf(slot.x, -4.8, 4.8)
		slot.z = clampf(slot.z, -4.8, 4.8)
	return slot

# ---------------------------------------------------------------- round flow
func _start_round() -> void:
	print("DW_ROUND_START %d/%d t=%.1f ts=%.3f" % [round_index + 1, rounds_total, game_time, Engine.time_scale])
	phase = Phase.ROUND
	round_elapsed = 0.0
	_round_resolving = false
	_decider = "none"
	_elim_order.clear()
	_clear_ghosts()
	var darken := round_index * 0.22
	for prop in _props:
		prop.reset_for_round(darken)
	for i in players.size():
		if players[i].role == "ghost":
			_spawn_ghost(i, Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)))
		else:
			var f: DWFighter = _fighters[i]
			var jitter := Vector3(rng.randf_range(-0.7, 0.7), 0.2, rng.randf_range(-0.7, 0.7))
			f.revive(_spawns[i] + jitter)
	round_label.text = "ROUND %d / %d" % [round_index + 1, rounds_total]
	_rebuild_scoreboard()
	if _balance_rounds == 0:
		_flash_banner("ROUND %d\nFIGHT!" % (round_index + 1), Color(1, 0.85, 0.2), 1.6)

func _living_count() -> int:
	var n := 0
	for f in _fighters:
		if f != null and f.alive:
			n += 1
	return n

func _living_participants() -> int:
	var n := 0
	for p in players:
		if p.role == "living":
			n += 1
	return n

func _on_fighter_fell(index: int) -> void:
	if phase != Phase.ROUND:
		return
	_elim_order.append(index)
	players[index].deaths += 1
	players[index].streak = 0
	_currency_log.append({"type": "grudge", "player": index, "amount": 1, "reason": "shoved into the void"})

	var f: DWFighter = _fighters[index]
	var death_pos := f.global_position
	var atk: Dictionary = f.last_attacker
	var credit_type := "void"
	var credit_line := "THE VOID CLAIMS %s" % players[index].name
	var credit_color := Color(0.6, 0.85, 1.0)
	# kill attribution (reporting only): killer -1 = the void / an accident.
	var kill_killer := -1
	var kill_cause := "void"
	if atk.size() > 0 and (game_time - float(atk.get("time", -99.0))) <= KILL_CREDIT_WINDOW:
		var ai: int = int(atk.get("index", -1))
		if atk.get("type", "") == "ghost" and ai >= 0 and ai != index:
			credit_type = "ghost"
			credit_color = atk.get("color", Color.WHITE)
			credit_line = "%s (%s) CLAIMS %s" % [atk.get("name", "THE THING"), players[ai].name, players[index].name]
			players[ai].total += ROYALTY
			players[ai].ghost_kills += 1
			_currency_log.append({"type": "royalty", "player": ai, "amount": ROYALTY,
				"reason": "poltergeist kill on %s" % players[index].name})
			_highlights.append(credit_line)
			kill_killer = ai
			kill_cause = "furniture"
		elif atk.get("type", "") == "player" and ai >= 0 and ai != index:
			credit_type = "player"
			credit_color = atk.get("color", Color.WHITE)
			credit_line = "%s BOOTS %s INTO THE VOID" % [players[ai].name, players[index].name]
			_highlights.append(credit_line)
			kill_killer = ai
			kill_cause = "shove"
	_kill_events.append({"killer": kill_killer, "victim": index, "cause": kill_cause})

	print("DW_DEATH round=%d t=%.1fs %s (%s)" % [round_index + 1, round_elapsed, credit_line, credit_type])
	if _balance_rounds == 0:
		Sfx.play("splat")
		Sfx.play("death")
		_spawn_death_fx(death_pos, players[index].color)
		_flash_banner(credit_line, credit_color, 2.0)
		_shake = maxf(_shake, 0.5)
		_time_hit(0.32, 0.4)

	# record what ended the round for the balance metric + banner spotlight
	if _living_count() <= 1 and _decider == "none":
		_decider = credit_type
		_last_kill_line = credit_line
		_last_kill_color = credit_color

	# rise as a poltergeist for the rest of the round
	_spawn_ghost(index, death_pos)
	_rebuild_scoreboard()
	call_deferred("_check_round_end")

func _check_round_end() -> void:
	if phase != Phase.ROUND or _round_resolving:
		return
	var alive := _living_count()
	var participants := _living_participants()
	if participants >= 2 and alive <= 1:
		_resolve_round()
	elif participants == 1 and alive == 0:
		_resolve_round()

func _resolve_round() -> void:
	_round_resolving = true
	phase = Phase.BETWEEN
	# stop survivors in their tracks: bot/player input is no longer applied in
	# BETWEEN, and stale velocity must not carry anyone off the lip
	for f in _fighters:
		if f != null and f.alive:
			f.move_input = Vector2.ZERO
			f.want_shove = false
			f.want_hop = false
			f.linear_velocity = Vector3(0, f.linear_velocity.y, 0)
	# finishing order: survivors first, then reverse of death order
	var survivors: Array = []
	for i in players.size():
		if players[i].role == "living" and _fighters[i] != null and _fighters[i].alive:
			survivors.append(i)
	var finishing: Array = survivors.duplicate()
	var dead_desc: Array = _elim_order.duplicate()
	dead_desc.reverse()
	for i in dead_desc:
		finishing.append(i)
	for pos in finishing.size():
		var pi: int = finishing[pos]
		if pos < POINTS_TABLE.size():
			players[pi].total += POINTS_TABLE[pos]
	# survivors extend their streak
	for i in survivors:
		players[i].streak += 1
		players[i].best_streak = maxi(players[i].best_streak, players[i].streak)

	if _balance_rounds > 0:
		var key := "void"
		if _decider == "player":
			key = "living"
		elif _decider == "ghost":
			key = "ghost"
		_balance_tally[key] += 1
		_dbg.round_len += round_elapsed
		_next_round_or_finish(0.05)
		return

	var champ := "THE VOID"
	var champ_color := Color(0.7, 0.85, 1.0)
	if survivors.size() > 0:
		champ = players[survivors[0]].name
		champ_color = players[survivors[0]].color
	Sfx.play("round_over")
	# if a kill ended the round, the kill line keeps the spotlight
	var text := "%s SURVIVES\nROUND %d" % [champ, round_index + 1]
	var text_color := champ_color
	if _last_kill_line != "":
		text = "%s\n%s SURVIVES ROUND %d" % [_last_kill_line, champ, round_index + 1]
		text_color = _last_kill_color
		_last_kill_line = ""
	_flash_banner(text, text_color, 2.8)
	_rebuild_scoreboard()
	_next_round_or_finish(3.2)

func _next_round_or_finish(delay: float) -> void:
	round_index += 1
	if round_index >= rounds_total:
		call_deferred("_finish_match")
		return
	if delay <= 0.1:
		_start_round()
	else:
		# tick-driven (not awaited): survives any time_scale weirdness
		_between_timer = delay

func _finish_match() -> void:
	phase = Phase.DONE
	print("KILL_EVENTS n=%d %s" % [_kill_events.size(), JSON.stringify(_kill_events)])
	if _balance_rounds > 0:
		_print_balance()
		get_tree().quit()
		return
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if players[a].total != players[b].total:
			return players[a].total > players[b].total
		return a < b)
	var champ: int = order[0]
	print("DW_MATCH_OVER champ=%s pts=%d" % [players[champ].name, players[champ].total])
	_flash_banner("%s WINS DEAD WEIGHT" % players[champ].name, players[champ].color, 6.0)
	Sfx.play("match_win")
	_spawn_confetti(_spawns[champ] + Vector3(0, 1.2, 0), players[champ].color)

	var points: Dictionary = {}
	for i in players.size():
		points[i] = players[i].total
	# best streak highlight
	var best_streak_player := -1
	var best_streak := 0
	for i in players.size():
		if players[i].best_streak > best_streak:
			best_streak = players[i].best_streak
			best_streak_player = i
	if best_streak_player >= 0 and best_streak >= 2:
		_highlights.insert(0, "%s survived %d rounds straight" % [players[best_streak_player].name, best_streak])
	var monuments: Array = []
	for i in players.size():
		if players[i].ghost_kills >= 3:
			monuments.append({"player": i, "kind": "poltergeist",
				"label": "%s, Dead and Still Winning" % players[i].name})
	var results := {
		"placements": order,
		"points": points,
		"currency_events": _currency_log.duplicate(),
		"kill_events": _kill_events.duplicate(),
		"highlights": _dedup(_highlights).slice(0, 3),
		"monuments": monuments,
	}
	if has_method("report_finished"):
		report_finished(results)
	else:
		finished.emit(results)

func _print_balance() -> void:
	var total: int = _balance_tally.living + _balance_tally.ghost + _balance_tally.void
	# "living wins" = the ghost did NOT land the decisive kill (living shove or accident)
	var living_side: int = _balance_tally.living + _balance_tally.void
	var living_pct := 0.0
	if total > 0:
		living_pct = 100.0 * living_side / float(total)
	print("======== DEAD WEIGHT BALANCE ========")
	print("seed=%d rounds=%d" % [rng.seed, total])
	print("living-shove=%d ghost-kill=%d void/accident=%d" % [_balance_tally.living, _balance_tally.ghost, _balance_tally.void])
	print("LIVING WIN %% = %.1f%%   ghost-decided %% = %.1f%%   [target living 55-75%%]" % [living_pct, 100.0 - living_pct])
	print("telemetry: possessions=%d ghost_hits=%d avg_round=%.1fs" % [_dbg.possess, _dbg.ghost_hits, _dbg.round_len / float(maxi(total, 1))])
	print("DRIVE_FORCE=%.1f KNOCK_SCALE=%.2f KNOCK_MAX=%.1f" % [DWProp.DRIVE_FORCE, DWProp.KNOCK_SCALE, DWProp.KNOCK_MAX])
	print("=====================================")

func _dedup(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		if not out.has(x):
			out.append(x)
	return out

# ---------------------------------------------------------------- ghosts
func _spawn_ghost(index: int, pos: Vector3) -> void:
	if _ghosts.has(index):
		return
	var g := DWGhost.new()
	g.name = "Ghost%d" % index
	spawn_root.add_child(g)
	g.setup(index, players[index].color, self)
	g.spawn_at(pos + Vector3(0, 1.0, 0))
	_ghosts[index] = g
	_ghost_hold[index] = 0.0

func _clear_ghosts() -> void:
	for k in _ghosts.keys():
		var g: DWGhost = _ghosts[k]
		g.force_release()
		g.queue_free()
	_ghosts.clear()

# ---------------------------------------------------------------- input/AI
func _physics_process(delta: float) -> void:
	game_time += delta
	if _shake > 0.001:
		cam.h_offset = rng.randf_range(-1, 1) * _shake * 0.3
		cam.v_offset = rng.randf_range(-1, 1) * _shake * 0.3
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-6.0 * delta))
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	if phase == Phase.BETWEEN and _between_timer > 0.0:
		_between_timer -= delta
		if _between_timer <= 0.0:
			_start_round()
		return
	if phase != Phase.ROUND:
		return
	round_elapsed += delta
	_update_timer_label()

	for i in players.size():
		if _dw_probe_manual and i == 0:
			continue   # the fling probe steers p0's ghost directly
		if _ghosts.has(i):
			_drive_ghost(i)
		elif _fighters[i] != null and _fighters[i].alive:
			_drive_fighter(i)

	if round_elapsed >= _round_cap():
		_resolve_round()

func _round_cap() -> float:
	return 22.0 if _balance_rounds > 0 else ROUND_TIME

func _drive_fighter(i: int) -> void:
	var f: DWFighter = _fighters[i]
	if players[i].is_bot:
		_bot_living(f)
	else:
		f.move_input = PlayerInput.get_move(i)
		f.aim_face = PlayerInput.get_aim_dir(i, f.global_position, cam)   # ZERO for non-KBM
		if PlayerInput.just_pressed(i, "a"):
			f.want_shove = true
		if PlayerInput.just_pressed(i, "b"):
			f.want_hop = true

func _drive_ghost(i: int) -> void:
	var g: DWGhost = _ghosts[i]
	if players[i].is_bot:
		_bot_ghost(g)
	else:
		g.move_input = PlayerInput.get_move(i)
		# while possessing, fling the prop toward the cursor (anchor on the prop);
		# free-flying stays WASD. ZERO for non-KBM => unchanged move_input drive.
		if g.possessing != null:
			g.aim_drive = PlayerInput.get_aim_dir(i, g.possessing.global_position, cam)
		else:
			g.aim_drive = Vector3.ZERO
		g.want_possess = PlayerInput.is_down(i, "a")
		g.want_release = PlayerInput.just_pressed(i, "b")

func _bot_living(f: DWFighter) -> void:
	var here := Vector2(f.global_position.x, f.global_position.z)
	var target := _nearest_living_other(f)
	var mv := Vector2.ZERO
	if target != null:
		var tp := Vector2(target.global_position.x, target.global_position.z)
		var dist := here.distance_to(tp)
		# approach the target from the CENTER side, so our shove sends them outward
		var outward := tp
		if outward.length() < 0.4:
			outward = Vector2(0, 1)
		outward = outward.normalized()
		var approach := tp - outward * 1.15
		if dist < 1.9:
			mv = (tp - here)          # close for the kill
		else:
			mv = approach - here
		if mv.length() > 0.01:
			mv = mv.normalized()
		if dist < DWFighter.SHOVE_RANGE + 0.1:
			f.want_shove = true
	# a little seeded wander so mirror-image bots don't play identical rounds
	mv += Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
	# edge avoidance: steer hard back toward center near the lip
	if absf(here.x) > 3.6:
		mv.x += -signf(here.x) * 3.0
	if absf(here.y) > 3.6:
		mv.y += -signf(here.y) * 3.0
	# dodge a fast possessed prop bearing down
	var threat := _incoming_prop(f)
	if threat != null:
		var away := here - Vector2(threat.global_position.x, threat.global_position.z)
		if away.length() > 0.01:
			var perp := Vector2(-away.y, away.x).normalized()
			mv += perp * 1.3
	if mv.length() > 0.01:
		mv = mv.normalized()
	f.move_input = mv

func _bot_ghost(g: DWGhost) -> void:
	var target := _nearest_living_any(g.global_position)
	if g.possessing != null:
		if target == null:
			g.want_release = true
			return
		# ram the victim TOWARD the nearest void edge: approach from the center
		# side so the prop's momentum shoves them outward, not inward
		var prop_xz := Vector2(g.possessing.global_position.x, g.possessing.global_position.z)
		var tgt_xz := Vector2(target.global_position.x, target.global_position.z)
		var outward := tgt_xz
		if outward.length() < 0.4:
			outward = Vector2(0, 1)
		outward = outward.normalized()
		var to_tgt := (tgt_xz - prop_xz)
		if to_tgt.length() > 0.05 and to_tgt.normalized().dot(outward) > 0.15:
			# prop is center-ward of the victim: charge straight through them
			g.move_input = to_tgt.normalized()
		else:
			# prop is on the wrong side: swing around to the center side first
			var flank := tgt_xz - outward * 2.3
			var to_flank := flank - prop_xz
			g.move_input = to_flank.normalized() if to_flank.length() > 0.05 else to_tgt.normalized()
		_ghost_hold[g.index] = _ghost_hold.get(g.index, 0.0) + get_physics_process_delta_time()
		if _ghost_hold[g.index] > 8.0:
			g.want_release = true
			_ghost_hold[g.index] = 0.0
		return
	# hunt a prop near the target (fall back to nearest prop to the ghost)
	var prop := _possessable_prop_near(target.global_position if target != null else g.global_position)
	if prop == null:
		g.move_input = Vector2(-g.global_position.x, -g.global_position.z).normalized()
		g.want_possess = false
		return
	var pd := Vector2(prop.global_position.x - g.global_position.x,
		prop.global_position.z - g.global_position.z)
	g.move_input = pd.normalized() if pd.length() > 0.01 else Vector2.ZERO
	g.want_possess = pd.length() <= DWGhost.POSSESS_RANGE

func _nearest_living_other(f: DWFighter) -> DWFighter:
	var best: DWFighter = null
	var bd := 1e9
	for other in _fighters:
		if other == null or other == f or not other.alive:
			continue
		var d: float = f.global_position.distance_to(other.global_position)
		if d < bd:
			bd = d
			best = other
	return best

func _nearest_living_any(from: Vector3) -> DWFighter:
	var best: DWFighter = null
	var bd := 1e9
	for f in _fighters:
		if f == null or not f.alive:
			continue
		var d: float = from.distance_to(f.global_position)
		if d < bd:
			bd = d
			best = f
	return best

func _incoming_prop(f: DWFighter) -> DWProp:
	for prop in _props:
		if prop.possessed_by < 0:
			continue
		var to: Vector3 = f.global_position - prop.global_position
		to.y = 0
		if to.length() < 2.5 and prop.linear_velocity.length() > 2.5:
			if prop.linear_velocity.normalized().dot(to.normalized()) > 0.4:
				return prop
	return null

func _possessable_prop_near(pos: Vector3) -> DWProp:
	var best: DWProp = null
	var bd := 1e9
	for prop in _props:
		if not prop.can_be_possessed():
			continue
		var d: float = pos.distance_to(prop.global_position)
		if d < bd:
			bd = d
			best = prop
	return best

# ---------------------------------------------------------------- callbacks used by children
func living_fighters() -> Array:
	var out: Array = []
	for f in _fighters:
		if f != null and f.alive:
			out.append(f)
	return out

func props() -> Array:
	return _props

func prop_locked_by_spawn(prop: DWProp) -> bool:
	if round_elapsed >= SPAWN_LOCK_TIME:
		return false
	for s in _spawns:
		var d := Vector2(prop.global_position.x - s.x, prop.global_position.z - s.z).length()
		if d < SPAWN_LOCK_RADIUS:
			return true
	return false

func on_shove_landed(_pos: Vector3) -> void:
	_shake = maxf(_shake, 0.28)
	_time_hit(0.001, 0.05)   # 0.05s hit-pause

func on_possess(_g: DWGhost, _p: DWProp) -> void:
	if _balance_rounds > 0:
		_dbg.possess += 1

func note_ghost_hit() -> void:
	if _balance_rounds > 0:
		_dbg.ghost_hits += 1

# ---------------------------------------------------------------- fx / ui
func _time_hit(scale: float, real_duration: float) -> void:
	_time_token += 1
	var my := _time_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_duration, true, false, true).timeout
	if my == _time_token:
		Engine.time_scale = 1.0

func _update_timer_label() -> void:
	var remaining: int = int(ceil(maxf(0.0, _round_cap() - round_elapsed)))
	timer_label.text = "%02d" % remaining

func _flash_banner(text: String, color: Color, duration: float) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func(): banner.visible = false)

func _rebuild_scoreboard() -> void:
	for c in score_rows.get_children():
		c.queue_free()
	var order: Array = range(players.size())
	order.sort_custom(func(a, b):
		if players[a].total != players[b].total:
			return players[a].total > players[b].total
		return a < b)
	for i in order:
		var p: Dictionary = players[i]
		var dead: bool = (p.role == "ghost" or _ghosts.has(i)) or (_fighters[i] != null and not _fighters[i].alive)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var badge := PlayerBadge.make(i, 24)
		badge.color = p.color
		if dead:
			badge.dim = 0.45
		hb.add_child(badge)
		var row := Label.new()
		var tag := ""
		if p.role == "ghost" or _ghosts.has(i):
			tag = "  ☠"
		elif _fighters[i] != null and not _fighters[i].alive:
			tag = "  ☠"
		var extras := ""
		if p.ghost_kills > 0:
			extras += "  †%d" % p.ghost_kills
		row.text = "%s  %d%s%s" % [p.name, p.total, extras, tag]
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", p.color)
		row.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
		row.add_theme_constant_override("outline_size", 5)
		hb.add_child(row)
		score_rows.add_child(hb)

func _spawn_death_fx(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = pos + Vector3(0, 0.3, 0)
	p.one_shot = true
	p.amount = 30
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _spawn_confetti(pos: Vector3, color: Color) -> void:
	for c in [color, Color(1, 0.9, 0.4), Color.WHITE]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.global_position = pos
		p.one_shot = true
		p.amount = 18
		p.lifetime = 1.2
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.5
		p.gravity = Vector3(0, -7.0, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.02, 0.08)
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		p.material_override = mat
		p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)

# ---------------------------------------------------------------- mouse-aim probe
# --aimprobe=<deg>: poltergeist flings a possessed crate toward the cursor.
# --aimshove=<deg>: a living fighter's shove cone points at the cursor.
# Each writes two shots to verify_out/ proving the action follows the CYAN aim
# ray, not the WHITE baseline (WASD-drive dir / walk-facing).
func _run_dw_probe() -> void:
	while phase != Phase.ROUND:
		await get_tree().physics_frame
	if _probe_shove:
		await _dw_probe_shove()
	else:
		await _dw_probe_fling()
	await get_tree().create_timer(0.2).timeout
	print("DW_AIMPROBE_DONE")
	get_tree().quit()


func _dw_probe_fling() -> void:
	var g: DWGhost = _ghosts[0]
	var prop: DWProp = _props[2]   # a lamp: light enough to hurl fast and read as thrown
	var aim_yaw := deg_to_rad(_aim_probe_deg)
	var wasd_dir := Vector3(1, 0, 0)                    # baseline: "WASD" drives it +X
	prop.global_position = Vector3(0, prop.rest_height() + 0.1, 0)
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	g.global_position = Vector3(0, DWGhost.HOVER_Y, 0)
	g._begin_possession(prop)
	g.aim_drive = Vector3.ZERO
	g.move_input = Vector2(wasd_dir.x, wasd_dir.z)
	_dw_probe_arrow(Vector3.ZERO, atan2(wasd_dir.x, wasd_dir.z), Color(1, 1, 1), 3.0)     # WASD (white)
	_dw_probe_arrow(Vector3.ZERO, aim_yaw, Color(0.2, 0.95, 1.0), 3.0)                    # cursor (cyan)
	await get_tree().create_timer(0.45).timeout
	await _dw_grab("fling_facing")
	print("DW_AIMPROBE fling baseline prop_vel=%s (WASD +X)" % str(prop.linear_velocity))
	prop.global_position = Vector3(0, prop.rest_height() + 0.1, 0)
	prop.linear_velocity = Vector3.ZERO
	g.global_position = Vector3(0, DWGhost.HOVER_Y, 0)
	g.move_input = Vector2.ZERO
	g.aim_drive = Vector3(sin(aim_yaw), 0.0, cos(aim_yaw))
	await get_tree().create_timer(0.85).timeout
	await _dw_grab("fling_acting")
	var vdir := rad_to_deg(atan2(prop.linear_velocity.x, prop.linear_velocity.z))
	print("DW_AIMPROBE fling prop_vel=%s dir=%.0fdeg aim=%.0fdeg matches=%s" % [
		str(prop.linear_velocity), vdir, _aim_probe_deg, str(absf(vdir - _aim_probe_deg) < 25.0)])


func _dw_probe_shove() -> void:
	var f: DWFighter = _fighters[0]
	var victim: DWFighter = _fighters[1]
	var aim_yaw := deg_to_rad(_aim_probe_deg)
	var face_yaw := aim_yaw + PI * 0.5
	var aim_dir := Vector3(sin(aim_yaw), 0.0, cos(aim_yaw))
	f.global_position = Vector3(0, 0.1, 0)
	f.linear_velocity = Vector3.ZERO
	f._face = Vector3(sin(face_yaw), 0.0, cos(face_yaw))
	if f.model_pivot:
		f.model_pivot.rotation.y = face_yaw
	victim.global_position = Vector3(0, 0.1, 0) + aim_dir * (DWFighter.SHOVE_RANGE - 0.4)
	victim.linear_velocity = Vector3.ZERO
	_dw_probe_arrow(Vector3.ZERO, face_yaw, Color(1, 1, 1), 3.0)                          # facing (white)
	_dw_probe_arrow(Vector3.ZERO, aim_yaw, Color(0.2, 0.95, 1.0), 3.0)                    # cursor (cyan)
	await get_tree().create_timer(0.5).timeout
	await _dw_grab("shove_facing")
	var v_before := victim.global_position
	print("DW_AIMSHOVE face=%.0fdeg aim=%.0fdeg victim_before=(%.2f,%.2f)" % [
		rad_to_deg(face_yaw), _aim_probe_deg, v_before.x, v_before.z])
	f.want_shove = true
	await get_tree().create_timer(0.25).timeout
	await _dw_grab("shove_acting")
	var knocked := victim.global_position - v_before
	var kdir := rad_to_deg(atan2(knocked.x, knocked.z))
	print("DW_AIMSHOVE victim moved %.2fm dir=%.0fdeg aim=%.0fdeg matches=%s" % [
		knocked.length(), kdir, _aim_probe_deg,
		str(knocked.length() > 0.2 and absf(kdir - _aim_probe_deg) < 35.0)])


func _dw_probe_arrow(origin: Vector3, yaw_a: float, col: Color, length: float) -> void:
	var dir := Vector3(sin(yaw_a), 0.0, cos(yaw_a))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.8
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, length)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = origin + dir * (length * 0.5) + Vector3(0, 0.9, 0)
	mi.rotation.y = yaw_a
	add_child(mi)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.42, 0.42, 0.42)
	tip.mesh = tm
	tip.material_override = mat
	tip.position = origin + dir * length + Vector3(0, 0.9, 0)
	add_child(tip)


func _dw_grab(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("DW_AIMPROBE_SKIP_HEADLESS ", tag)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://verify_out/dead_weight_aim_%s.png" % tag
	img.save_png(path)
	print("DW_AIMPROBE_CAP ", path)


# ---------------------------------------------------------------- verify hooks
func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_turn_ready() -> bool:
	return phase == Phase.ROUND
