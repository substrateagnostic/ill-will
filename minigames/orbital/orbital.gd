extends Minigame
## ORBITAL DODGEBALL - anthology minigame (module contract: core/minigame.gd).
## Dodgeball on 3 tiny planets with real radial gravity. Thrown balls NEVER
## despawn - they orbit the cluster, decaying over ~40s of space drag, and a
## kill credits the LAST THROWER forever ("GOLD'S GHOST ORBIT STRIKES" on a
## 30-second-old throw).
##
## Controls (PlayerInput): move = surface walk (screen-relative),
##   A tap (empty hands) = catch window, walk over a ball = pick up,
##   A hold (holding)    = aim + power ramp, release = throw,
##   B = jump (hop; at the near points you can hop to a neighboring planet).
##
## Standalone: runs self-contained - if the shell has not called begin()
## within 0.5s the game begins itself with a default 4-player roster built
## from GameState consts. CLI user args (after --):
##   --seed=N       rng seed for the default config (default 1)
##   --players=N    default-roster size 2..4 (default 4)
##   --orbbots      seeded self-play bots on every seat
##   --fast=K       Engine.time_scale multiplier for long sims (mutes audio)
##   --matchsec=N   override match length (default 180)
##   --autoquit     quit after the match report / test completion
##   --orbtest=circ bot circumnavigates each planet on constant stick input,
##                  logs heading continuity (control-flip evidence), quits
##   --orbtest=aim  player 0 holds a full-power aim forever (preview shots)
##   --shots=N,...  (VerifyCapture autoload) capture PNGs at those frames
## All gameplay randomness comes from config.rng_seed. No physics bodies are
## used at all - balls, pawns and collisions are hand-integrated in
## _physics_process, so there are no deferred-physics-state gotchas.

enum Phase { WAIT, PLAY, END }

const PLANET_DEFS := [
	{"radius": 3.0, "center": Vector3(-3.8, -2.1, 0), "gsurf": 13.0, "col": Color(0.28, 0.42, 0.52)},
	{"radius": 2.2, "center": Vector3(3.5, -2.5, 0), "gsurf": 12.0, "col": Color(0.55, 0.33, 0.24)},
	{"radius": 1.8, "center": Vector3(0.8, 3.3, 0), "gsurf": 11.0, "col": Color(0.42, 0.32, 0.58)},
]
const START_BALLS := [
	{"planet": 0, "n": Vector3(-0.25, 0.55, 0.80)},
	{"planet": 0, "n": Vector3(0.55, -0.45, 0.70)},
	{"planet": 1, "n": Vector3(0.30, 0.35, 0.89)},
	{"planet": 2, "n": Vector3(-0.40, 0.30, 0.87)},
]
const START_SPOTS := [
	{"planet": 0, "n": Vector3(0.65, 0.35, 0.68)},
	{"planet": 1, "n": Vector3(-0.45, 0.25, 0.86)},
	{"planet": 2, "n": Vector3(0.30, -0.20, 0.93)},
	{"planet": 0, "n": Vector3(-0.70, -0.30, 0.65)},
]
const KAYKIT_CHARS := ["Barbarian", "Knight", "Mage", "Rogue"]
const MATCH_LEN := 180.0
const BALL_SPAWN_EVERY := 45.0
const MAX_BALLS := 8
const KILL_POINTS := 2
const CATCH_POINTS := 1
const GHOST_AGE := 10.0
const MONUMENT_AGE := 25.0
const RESPAWN_DELAY := 3.0
const MAX_FLIGHT_AGE_ASSERT := 75.0
const BOUNDARY_R := 13.0
const CAM_POS := Vector3(-0.2, 0.2, 17.6)
const CAM_FOV := 46.0

var config := {}
var rng := RandomNumberGenerator.new()
var phase := Phase.WAIT
var now := 0.0
var match_len := MATCH_LEN
var time_left := MATCH_LEN

var planets: Array = []   # [{center, radius, mu, col}]
var pawns: Array = []     # [OrbPawn]
var balls: Array = []     # [OrbBall]
var bots: Array = []      # [OrbBot]
var bots_enabled := false

var kills := {}
var catches := {}
var deaths := {}
var _points := {}
var _currency: Array = []
var _respawn_queue: Array = []
var _oldest_kill_age := 0.0
var _oldest_kill_txt := ""
var _ghost_monument := {}   # player -> best ghost age > MONUMENT_AGE
var _best_catch_age := 0.0
var _best_catch_txt := ""
var _throws := 0
var _hops := 0
var _max_flight_age := 0.0
var _age_fail := false
var _next_spawn := BALL_SPAWN_EVERY
var _names: Array = []
var _colors: Array = []

var _begun := false
var _cli_seed := 1
var _cli_players := 4
var _fast := 1.0
var _autoquit := false
var _match_override := -1.0
var _test_mode := ""
var _shake := 0.0
var _circ := {}

var _cam: Camera3D
var _ball_root: Node3D
var _trail_root: Node3D
var _pawn_root: Node3D
var _fx_root: Node3D
var _aim_mesh: MeshInstance3D
var _aim_im: ImmediateMesh
var _banner: Label
var _event_label: Label
var _timer_label: Label
var _hint_label: Label
var _score_rows: VBoxContainer
var _row_labels: Array = []
var _event_until := 0.0

func _ready() -> void:
	_parse_args()
	_build_static()
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if not _begun:
			begin(_default_config()))

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--orbbots":
			bots_enabled = true
		elif arg.begins_with("--seed="):
			_cli_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--players="):
			_cli_players = clampi(int(arg.trim_prefix("--players=")), 2, 4)
		elif arg.begins_with("--fast="):
			_fast = clampf(float(arg.trim_prefix("--fast=")), 1.0, 30.0)
		elif arg == "--autoquit":
			_autoquit = true
		elif arg.begins_with("--matchsec="):
			_match_override = float(arg.trim_prefix("--matchsec="))
		elif arg.begins_with("--orbtest="):
			_test_mode = arg.trim_prefix("--orbtest=")
	if _fast > 1.01:
		Engine.time_scale = _fast
		Engine.max_physics_steps_per_frame = maxi(8, int(_fast) * 12)
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
		})
	return {"roster": roster, "rounds": 1, "rng_seed": _cli_seed, "practice": false}

func begin(cfg: Dictionary) -> void:
	if _begun:
		return
	_begun = true
	config = cfg
	rng.seed = int(cfg.rng_seed)
	match_len = _match_override if _match_override > 0.0 else (MATCH_LEN if not cfg.get("practice", false) else 90.0)
	time_left = match_len
	var roster: Array = cfg.roster
	for pl in roster:
		var idx: int = pl.index
		_names.resize(maxi(_names.size(), idx + 1))
		_colors.resize(maxi(_colors.size(), idx + 1))
		_names[idx] = pl.name
		_colors[idx] = pl.color
		kills[idx] = 0
		catches[idx] = 0
		deaths[idx] = 0
		_points[idx] = 0
	if _test_mode != "circ":
		for sb in START_BALLS:
			_spawn_ball_at(sb.planet, Vector3(sb.n).normalized(), true)
	for i in roster.size():
		var pl: Dictionary = roster[i]
		var pawn := OrbPawn.new()
		pawn.world = self
		pawn.index = pl.index
		_pawn_root.add_child(pawn)
		pawn.setup(load(String(pl.char_scene)), pl.color)
		var spot: Dictionary = START_SPOTS[i % START_SPOTS.size()]
		pawn.place_on(spot.planet, Vector3(spot.n).normalized())
		pawns.append(pawn)
	if bots_enabled:
		for i in roster.size():
			var bot := OrbBot.new()
			bot.setup(self, i, int(cfg.rng_seed) * 977 + i * 131)
			bots.append(bot)
	phase = Phase.PLAY
	_update_score_rows()
	if _test_mode == "circ":
		_circ_start()
	elif _test_mode == "aim":
		if balls.size() > 0:
			var b: OrbBall = balls[0]
			b.pick_up(0)
			pawns[0].held = b
	else:
		_flash_banner("ORBITAL DODGEBALL", Color(1.0, 0.85, 0.25), 2.2)
		_flash_event("BALLS NEVER DESPAWN. OLD ORBITS STILL KILL.", Color(0.85, 0.88, 1.0))

## --- static world (camera, light, stars, planets, ui) ----------------------

func _build_static() -> void:
	_cam = Camera3D.new()
	_cam.position = CAM_POS
	_cam.fov = CAM_FOV
	_cam.current = true
	add_child(_cam)
	var light := DirectionalLight3D.new()
	add_child(light)
	light.look_at_from_position(Vector3(6, 8, 14), Vector3.ZERO, Vector3.UP)
	light.light_energy = 1.25
	light.shadow_enabled = true
	var wenv := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.50)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	wenv.environment = env
	add_child(wenv)
	_build_stars()
	for def in PLANET_DEFS:
		var d: Dictionary = def
		var r: float = d.radius
		planets.append({"center": d.center, "radius": r, "mu": float(d.gsurf) * r * r, "col": d.col})
		_build_planet_visual(d.center, r, d.col)
	_trail_root = Node3D.new()
	add_child(_trail_root)
	_ball_root = Node3D.new()
	add_child(_ball_root)
	_pawn_root = Node3D.new()
	add_child(_pawn_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_aim_im = ImmediateMesh.new()
	_aim_mesh = MeshInstance3D.new()
	_aim_mesh.mesh = _aim_im
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	am.vertex_color_use_as_albedo = true
	am.no_depth_test = true
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	_aim_mesh.material_override = am
	add_child(_aim_mesh)
	_build_ui()

func _build_stars() -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = 314159  # decor only; constant across every match like an asset
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var orb := SphereMesh.new()  # unshaded sphere = crisp round star disc
	orb.radius = 0.16
	orb.height = 0.32
	orb.radial_segments = 10
	orb.rings = 5
	mm.mesh = orb
	mm.instance_count = 700
	for i in mm.instance_count:
		var dir := Vector3(srng.randf_range(-1, 1), srng.randf_range(-1, 1), srng.randf_range(-1, 1))
		if dir.length_squared() < 0.01:
			dir = Vector3.FORWARD
		var pos := dir.normalized() * srng.randf_range(48.0, 70.0)
		var s := srng.randf_range(0.4, 1.4)
		if srng.randf() < 0.05:
			s *= 2.4
		var xf := Transform3D(Basis().scaled(Vector3.ONE * s), pos)
		mm.set_instance_transform(i, xf)
		var warm := srng.randf()
		var c := Color(0.75 + 0.25 * warm, 0.78 + 0.16 * warm, 1.0 - 0.25 * warm)
		mm.set_instance_color(i, Color(c.r, c.g, c.b, srng.randf_range(0.2, 0.9)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	add_child(mmi)

func _build_planet_visual(center: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 48
	sm.rings = 24
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = center
	add_child(mi)
	# fresnel atmosphere shell
	var shell := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = r * 1.055
	sm2.height = r * 2.11
	sm2.radial_segments = 48
	sm2.rings = 24
	shell.mesh = sm2
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec3 tint = vec3(0.5, 0.7, 1.0);
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint * f;
	ALPHA = clamp(f, 0.0, 1.0) * 0.8;
}
"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	var glowc := col.lightened(0.45)
	smat.set_shader_parameter("tint", Vector3(glowc.r, glowc.g, glowc.b))
	shell.material_override = smat
	shell.position = center
	add_child(shell)

func _basis_up(n: Vector3) -> Basis:
	var axis := Vector3.UP.cross(n)
	if axis.length() < 0.001:
		return Basis() if n.y > 0.0 else Basis(Vector3(1, 0, 0), PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(n))

func _add_pedestal(planet_i: int, n: Vector3) -> void:
	var pl: Dictionary = planets[planet_i]
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.24
	cm.bottom_radius = 0.32
	cm.height = 0.22
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.72, 0.78)
	mat.roughness = 0.5
	mi.material_override = mat
	add_child(mi)
	mi.global_transform = Transform3D(_basis_up(n), Vector3(pl.center) + n * (float(pl.radius) + 0.11))

## --- gravity field ----------------------------------------------------------

func gravity_at(pos: Vector3) -> Vector3:
	var g := Vector3.ZERO
	for pl in planets:
		var d: Vector3 = Vector3(pl.center) - pos
		var dist := maxf(d.length(), 0.4)
		g += d / dist * (float(pl.mu) / (dist * dist))
	var rlen := pos.length()
	if rlen > BOUNDARY_R:
		g += -pos / rlen * ((rlen - BOUNDARY_R) * 1.6)
	return g

func nearest_planet(pos: Vector3) -> int:
	var best := 0
	var best_d := 1e9
	for i in planets.size():
		var d: float = pos.distance_to(Vector3(planets[i].center)) - float(planets[i].radius)
		if d < best_d:
			best_d = d
			best = i
	return best

func cam_right() -> Vector3:
	return _cam.global_basis.x

func cam_up() -> Vector3:
	return _cam.global_basis.y

func cam_axis() -> Vector3:
	return _cam.global_basis.z

func pawn_color(i: int) -> Color:
	return _colors[i]

func pawn_name(i: int) -> String:
	return _names[i]

## --- simulation loop --------------------------------------------------------

func _physics_process(delta: float) -> void:
	if phase == Phase.WAIT:
		return
	now += delta
	if phase == Phase.PLAY and bots_enabled:
		for bot in bots:
			bot.think(delta, now)
	var neutral := {"move": Vector2.ZERO, "a": false, "b": false}
	for p in pawns:
		var pw: OrbPawn = p
		var inp: Dictionary = _input_for(pw.index) if phase == Phase.PLAY else neutral
		pw.step(delta, now, inp.move, inp.a, inp.b)
		if pw.held != null:
			pw.held.global_position = pw.body_center() + pw.up_dir() * 0.5 + pw.heading * 0.25
	for b in balls:
		var bb: OrbBall = b
		bb.step(delta, now)
		if bb.state == OrbBall.S.FLYING and bb.owner_idx >= 0:
			var a := bb.age(now)
			if a > _max_flight_age:
				_max_flight_age = a
			if a > MAX_FLIGHT_AGE_ASSERT and not _age_fail:
				_age_fail = true
				print("ORBITAL_ASSERT FAIL flight age %.1fs > %.0fs" % [a, MAX_FLIGHT_AGE_ASSERT])
	if phase == Phase.PLAY:
		_resolve_pickups()
		_resolve_hits()
		_process_respawns()
		if _test_mode == "":
			if now >= _next_spawn and balls.size() < MAX_BALLS:
				_next_spawn += BALL_SPAWN_EVERY
				var pi := rng.randi_range(0, planets.size() - 1)
				_spawn_ball_at(pi, _random_visible_n(), false)
				Sfx.play("confirm")
				_flash_event("A NEW BALL DRIFTS IN", Color(0.85, 0.88, 1.0))
			time_left -= delta
			if time_left <= 0.0:
				_end_match()
		elif _test_mode == "circ":
			_circ_track()

func _input_for(p: int) -> Dictionary:
	if _test_mode == "circ":
		return {"move": Vector2(1, 0) if p == 0 else Vector2.ZERO, "a": false, "b": false}
	if _test_mode == "aim":
		return {"move": Vector2.ZERO, "a": p == 0, "b": false}
	if bots_enabled:
		var bot: OrbBot = bots[p]
		return {"move": bot.move, "a": bot.a, "b": bot.b}
	return {
		"move": PlayerInput.get_move(p),
		"a": PlayerInput.is_down(p, "a"),
		"b": PlayerInput.is_down(p, "b"),
	}

func _resolve_pickups() -> void:
	for b in balls:
		var bb: OrbBall = b
		if bb.state != OrbBall.S.REST:
			continue
		for p in pawns:
			var pw: OrbPawn = p
			if pw.alive and not pw.airborne and pw.held == null \
					and bb.global_position.distance_to(pw.global_position) < 0.8:
				bb.pick_up(pw.index)
				pw.held = bb
				pw._play_once("PickUp")
				Sfx.play("card", -6.0)
				break

func _resolve_hits() -> void:
	for b in balls:
		var bb: OrbBall = b
		if not bb.deadly():
			continue
		for p in pawns:
			var pw: OrbPawn = p
			if not pw.alive or pw.invuln > 0.0:
				continue
			if bb.owner_idx == pw.index and bb.age(now) < 0.8:
				continue  # grace: your throw cannot clip you point-blank
			var d := bb.global_position.distance_to(pw.body_center())
			if d < OrbPawn.CATCH_RADIUS and pw.catch_timer > 0.0 and pw.held == null:
				_do_catch(pw, bb)
				break
			elif d < OrbBall.RADIUS + OrbPawn.BODY_R:
				_do_kill(pw, bb)
				break

func _do_catch(pw: OrbPawn, bb: OrbBall) -> void:
	var stolen := bb.owner_idx >= 0 and bb.owner_idx != pw.index
	var b_age := bb.age(now)
	bb.pick_up(pw.index)
	pw.held = bb
	pw.invuln = maxf(pw.invuln, 0.5)
	pw.catch_timer = 0.0
	pw._play_once("PickUp")
	catches[pw.index] += 1
	if stolen:
		_points[pw.index] += CATCH_POINTS
		_update_score_rows()
	Sfx.play("bumper")
	_shake = maxf(_shake, 0.18)
	_spawn_burst(pw.body_center(), Color(1, 1, 1), 16)
	var extra := " — A %d-SECOND ORBIT!" % int(b_age) if b_age > GHOST_AGE else ""
	_flash_event("NICE CATCH — %s%s" % [pawn_name(pw.index), extra], pawn_color(pw.index))
	if b_age > _best_catch_age:
		_best_catch_age = b_age
		_best_catch_txt = "%s plucked a %d-second orbit out of the sky" % [pawn_name(pw.index), int(b_age)]
	print("CATCH t=%.1f p=%d ball_age=%.1f stolen=%s" % [now, pw.index, b_age, stolen])

func _do_kill(pw: OrbPawn, bb: OrbBall) -> void:
	var victim := pw.index
	var killer := bb.owner_idx
	var ball_age := bb.age(now)
	deaths[victim] += 1
	_currency.append({"type": "grudge", "player": victim, "amount": 1, "reason": "orbital dodgeball to the face"})
	if pw.held != null:
		var loose := pw.held
		pw.held = null
		loose.drop_loose(pw.srf_n * 2.0 + bb.vel.normalized(), now)
	var spin := bb.vel.cross(pw.srf_n)
	pw.die(bb.vel, spin)
	_respawn_queue.append({"t": now + RESPAWN_DELAY, "player": victim})
	Sfx.play("splat")
	Sfx.play("death")
	_shake = maxf(_shake, 0.5)
	_spawn_burst(pw.body_center(), pawn_color(victim), 30)
	if killer == victim:
		_flash_banner("%s ORBITED THEMSELF" % pawn_name(victim), pawn_color(victim), 2.2)
	elif killer >= 0:
		kills[killer] += 1
		_points[killer] += KILL_POINTS
		if ball_age > GHOST_AGE:
			_currency.append({"type": "royalty", "player": killer, "amount": 1,
				"reason": "ghost orbit kill (%ds old)" % int(ball_age)})
			_flash_banner("%s'S GHOST ORBIT STRIKES!\n%d-SECOND-OLD THROW TAKES OUT %s"
				% [pawn_name(killer), int(ball_age), pawn_name(victim)], pawn_color(killer), 2.8)
			if ball_age > float(_ghost_monument.get(killer, 0.0)):
				_ghost_monument[killer] = ball_age
		else:
			_flash_banner("%s SMACKS %s!" % [pawn_name(killer), pawn_name(victim)], pawn_color(killer), 2.0)
		if ball_age > _oldest_kill_age:
			_oldest_kill_age = ball_age
			_oldest_kill_txt = "%s's %d-second orbit found %s" % [pawn_name(killer), int(ball_age), pawn_name(victim)]
		_update_score_rows()
	print("KILL t=%.1f killer=%d victim=%d ball_age=%.1f" % [now, killer, victim, ball_age])
	_slow_mo()

func _process_respawns() -> void:
	var keep: Array = []
	for item in _respawn_queue:
		if now >= float(item.t):
			var pi := _least_crowded_planet()
			var n := _respawn_spot(pi)
			pawns[int(item.player)].respawn(pi, n)
			Sfx.play("confirm", -4.0)
			_spawn_burst(pawns[int(item.player)].body_center(), pawn_color(int(item.player)), 12)
		else:
			keep.append(item)
	_respawn_queue = keep

func _least_crowded_planet() -> int:
	var counts := [0, 0, 0]
	for p in pawns:
		var pw: OrbPawn = p
		if pw.alive and not pw.airborne:
			counts[pw.planet] += 1
	var best := 0
	for i in range(1, planets.size()):
		if counts[i] < counts[best]:
			best = i
	return best

func _respawn_spot(planet_i: int) -> Vector3:
	var best_n := _random_visible_n()
	var best_d := -1.0
	for _try in 5:
		var n := _random_visible_n()
		var pos: Vector3 = Vector3(planets[planet_i].center) + n * float(planets[planet_i].radius)
		var nearest := 99.0
		for b in balls:
			var bb: OrbBall = b
			if bb.deadly():
				nearest = minf(nearest, bb.global_position.distance_to(pos))
		if nearest > best_d:
			best_d = nearest
			best_n = n
	return best_n

func _random_visible_n() -> Vector3:
	var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(0.25, 1.0))
	return v.normalized()

func _spawn_ball_at(planet_i: int, n: Vector3, with_pedestal: bool) -> OrbBall:
	var b := OrbBall.new()
	b.world = self
	_ball_root.add_child(b)
	var pl: Dictionary = planets[planet_i]
	var lift := 0.22 if with_pedestal else 0.0
	b.global_position = Vector3(pl.center) + n * (float(pl.radius) + lift + OrbBall.RADIUS)
	b.state = OrbBall.S.REST
	b.rest_planet = planet_i
	var t := OrbTrail.new()
	_trail_root.add_child(t)
	b.trail = t
	b.refresh_color()
	balls.append(b)
	if with_pedestal:
		_add_pedestal(planet_i, n)
	return b

## --- event hooks from balls / pawns ----------------------------------------

func on_throw(pw: OrbPawn, bb: OrbBall) -> void:
	_throws += 1
	Sfx.play("putt")
	print("THROW t=%.1f p=%d speed=%.1f" % [now, pw.index, bb.vel.length()])

func on_jump(_pw: OrbPawn) -> void:
	Sfx.play("place", -6.0)

func on_land(pw: OrbPawn, prev_planet: int) -> void:
	if prev_planet != pw.planet:
		_hops += 1
		print("HOP t=%.1f p=%d %d->%d" % [now, pw.index, prev_planet, pw.planet])

func on_ball_bounce(_bb: OrbBall, impact: float) -> void:
	Sfx.play("bounce", clampf(-14.0 + impact * 1.4, -14.0, -3.0))

func on_ball_rest(bb: OrbBall) -> void:
	print("BALL_REST t=%.1f owner=%d flight=%.1fs" % [now, bb.owner_idx, bb.age(now)])

## --- match end ---------------------------------------------------------------

func _end_match() -> void:
	phase = Phase.END
	var order: Array = _points.keys()
	order.sort_custom(func(a, b):
		if _points[a] != _points[b]:
			return int(_points[a]) > int(_points[b])
		return int(a) < int(b))
	var winner: int = order[0]
	if not pawns[winner].alive:
		pawns[winner].respawn(_least_crowded_planet(), _random_visible_n())
	pawns[winner]._play_once("Cheer")
	Sfx.play("match_win")
	_spawn_burst(pawns[winner].body_center(), pawn_color(winner), 40)
	_flash_banner("%s RULES THE VOID!" % pawn_name(winner), pawn_color(winner), 9999.0)
	var highlights: Array = []
	if _oldest_kill_txt != "":
		highlights.append(_oldest_kill_txt)
	if _best_catch_age > GHOST_AGE:
		highlights.append(_best_catch_txt)
	var most_deaths := -1
	var eater := -1
	for i in deaths:
		if int(deaths[i]) > most_deaths:
			most_deaths = int(deaths[i])
			eater = int(i)
	if eater >= 0 and most_deaths >= 2:
		highlights.append("%s ate %d dodgeballs" % [pawn_name(eater), most_deaths])
	var monuments: Array = []
	for i in _ghost_monument:
		monuments.append({"player": int(i), "kind": "ghost_orbit",
			"label": "%s, Keeper of the %d-Second Orbit" % [pawn_name(int(i)), int(float(_ghost_monument[i]))]})
	var results := {
		"placements": order,
		"points": _points.duplicate(),
		"currency_events": _currency.duplicate(),
		"highlights": highlights.slice(0, 3),
		"monuments": monuments,
	}
	report_finished(results)
	print("ORBITAL_RESULTS ", JSON.stringify(results))
	var verdict := "PASS" if (not _age_fail and _max_flight_age < MAX_FLIGHT_AGE_ASSERT) else "FAIL"
	print("ORBITAL_SIM throws=%d hops=%d kills=%s catches=%s deaths=%s" % [_throws, _hops, str(kills), str(catches), str(deaths)])
	print("ORBITAL_ASSERT max_flight_age=%.1fs (<%.0fs): %s" % [_max_flight_age, MAX_FLIGHT_AGE_ASSERT, verdict])
	if _autoquit:
		get_tree().create_timer(2.0, true, false, true).timeout.connect(func() -> void: get_tree().quit())

func _slow_mo() -> void:
	if _fast > 1.01 or _test_mode != "":
		return
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.35, true, false, true).timeout
	Engine.time_scale = 1.0

## --- circumnavigation evidence mode (--orbtest=circ) ------------------------

func _circ_start() -> void:
	_circ = {"planet": 0, "prev_h": Vector3.ZERO, "prev_n": Vector3.ZERO,
		"angle": 0.0, "min_dot": 1.0, "flips": 0, "tick": 0}
	pawns[0].place_on(0, Vector3(0, 0, 1))
	print("CIRC_START constant screen-input (1,0); heading continuity logged")

func _circ_track() -> void:
	var pw: OrbPawn = pawns[0]
	if _circ.prev_h != Vector3.ZERO and pw.walking:
		var d: float = Vector3(_circ.prev_h).dot(pw.heading)
		_circ.min_dot = minf(float(_circ.min_dot), d)
		if d < 0.5:
			_circ.flips = int(_circ.flips) + 1
	_circ.prev_h = pw.heading
	if _circ.prev_n != Vector3.ZERO:
		_circ.angle = float(_circ.angle) + Vector3(_circ.prev_n).angle_to(pw.srf_n)
	_circ.prev_n = pw.srf_n
	_circ.tick = int(_circ.tick) + 1
	if int(_circ.tick) % 120 == 0:
		print("CIRC planet=%d deg=%.0f min_heading_dot=%.4f" % [int(_circ.planet), rad_to_deg(float(_circ.angle)), float(_circ.min_dot)])
	if float(_circ.angle) >= TAU:
		print("CIRC_OK planet=%d full_circle min_heading_dot=%.4f flips=%d" % [int(_circ.planet), float(_circ.min_dot), int(_circ.flips)])
		_circ.planet = int(_circ.planet) + 1
		if int(_circ.planet) >= planets.size():
			print("CIRC_DONE all 3 planets circumnavigated, zero control flips" if int(_circ.flips) == 0 else "CIRC_DONE with flips=%d" % int(_circ.flips))
			_test_mode = ""
			if _autoquit:
				get_tree().quit()
			return
		pawns[0].place_on(int(_circ.planet), Vector3(0, 0, 1))
		_circ.prev_h = Vector3.ZERO
		_circ.prev_n = Vector3.ZERO
		_circ.angle = 0.0
		_circ.min_dot = 1.0

## --- presentation (visual frame) ---------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.WAIT:
		return
	for b in balls:
		var bb: OrbBall = b
		if bb.trail != null:
			bb.trail.render(now, _cam.global_position)
	_draw_aim_previews()
	_update_timer_label()
	if _hint_label.visible and now > 7.0:
		_hint_label.visible = false
	if _event_label.visible and now > _event_until:
		_event_label.visible = false
	if _shake > 0.002:
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-5.0 * delta))
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0

func _draw_aim_previews() -> void:
	_aim_im.clear_surfaces()
	for p in pawns:
		var pw: OrbPawn = p
		if not pw.alive or pw.held == null or pw.charge < 0.0:
			continue
		var tv: Dictionary = pw.throw_vector()
		var pos: Vector3 = tv.origin
		var vel: Vector3 = tv.vel
		var col := pawn_color(pw.index)
		_aim_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var dt := 0.06
		var hit := false
		for i in 25:  # first 1.5s of the predicted path only (spec)
			vel += gravity_at(pos) * dt
			vel *= (1.0 - OrbBall.DRAG_BASE * dt)
			if vel.length() > OrbBall.SPEED_CAP:
				vel = vel.normalized() * OrbBall.SPEED_CAP
			pos += vel * dt
			for pl in planets:
				if pos.distance_to(Vector3(pl.center)) < float(pl.radius) + OrbBall.RADIUS:
					hit = true
			var fade := 1.0 - float(i) / 25.0
			var s := 0.06 + 0.05 * pw.charge
			if hit:
				s *= 2.0  # impact blip, then stop
			_aim_dot(pos, s, Color(col.r, col.g, col.b, 0.5 + 0.45 * fade))
			if hit:
				break
		_aim_im.surface_end()

func _aim_dot(p: Vector3, s: float, c: Color) -> void:
	# camera-facing diamond (reads as a deliberate dotted line, not a pixel)
	var r := cam_right() * s
	var u := cam_up() * s
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p - r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p + u)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p + r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p - r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p + r)
	_aim_im.surface_set_color(c)
	_aim_im.surface_add_vertex(p - u)

func _spawn_burst(pos: Vector3, color: Color, amount: int) -> void:
	var part := CPUParticles3D.new()
	_fx_root.add_child(part)
	part.global_position = pos
	part.one_shot = true
	part.amount = amount
	part.lifetime = 0.8
	part.explosiveness = 1.0
	part.direction = Vector3.UP
	part.spread = 180.0
	part.initial_velocity_min = 2.0
	part.initial_velocity_max = 5.0
	part.gravity = Vector3.ZERO
	part.damping_min = 1.5
	part.damping_max = 3.0
	part.scale_amount_min = 0.5
	part.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	part.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.8
	part.material_override = mat
	part.emitting = true
	get_tree().create_timer(1.6).timeout.connect(part.queue_free)

## --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	var baloo: Font = load("res://assets/fonts/Baloo2.ttf")
	var ui := CanvasLayer.new()
	add_child(ui)
	_timer_label = _mk_label(lg, 40, 10)
	_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_timer_label.offset_top = 8
	ui.add_child(_timer_label)
	_event_label = _mk_label(baloo, 24, 7)
	_event_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_event_label.offset_top = 62
	_event_label.visible = false
	ui.add_child(_event_label)
	_banner = _mk_label(lg, 46, 12)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.visible = false
	ui.add_child(_banner)
	_score_rows = VBoxContainer.new()
	_score_rows.position = Vector2(16, 12)
	ui.add_child(_score_rows)
	_hint_label = _mk_label(baloo, 19, 6)
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.offset_bottom = -10
	_hint_label.text = "MOVE walk the planet   ·   A hold = aim, release = THROW   ·   A tap = CATCH   ·   B = JUMP the gap"
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	ui.add_child(_hint_label)

func _mk_label(font: Font, size: int, outline: int) -> Label:
	var l := Label.new()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.09))
	l.add_theme_constant_override("outline_size", outline)
	return l

func _update_score_rows() -> void:
	if _row_labels.is_empty():
		var lg: Font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
		for i in _points:
			var l := _mk_label(lg, 26, 7)
			_score_rows.add_child(l)
			_row_labels.append({"label": l, "player": int(i)})
	for row in _row_labels:
		var i: int = row.player
		var l: Label = row.label
		l.text = "%s  %d" % [pawn_name(i), int(_points[i])]
		l.add_theme_color_override("font_color", pawn_color(i))

func _update_timer_label() -> void:
	if phase == Phase.END:
		_timer_label.text = "0:00"
		return
	var t := maxi(0, int(ceilf(time_left)))
	_timer_label.text = "%d:%02d" % [t / 60, t % 60]
	_timer_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.35) if time_left < 15.0 else Color.WHITE)

func _flash_banner(text: String, color: Color, duration: float) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.55, 0.55)
	var pop := create_tween()
	pop.tween_property(_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if duration < 100.0:
		var tw := create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func() -> void: _banner.visible = false)

func _flash_event(text: String, color: Color) -> void:
	_event_label.text = text
	_event_label.add_theme_color_override("font_color", color)
	_event_label.visible = true
	_event_until = now + 2.2

## --- debug/verify surface ------------------------------------------------------

func get_phase_name() -> String:
	return Phase.keys()[phase]

func is_playing() -> bool:
	return phase == Phase.PLAY
