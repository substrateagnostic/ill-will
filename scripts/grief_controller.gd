class_name GriefController
extends Node
## PAR v4 WAVE 2 — LIVE CHAOS GRIEFING (the owner's day-one wish). In the CHAOS
## round every avatar is on the course at once: the non-stroking players
## direct-control their characters and grief whoever the shot clock is on.
##
## THE INVARIANT, ADAPTED: ball physics stay frozen. Avatars NEVER touch balls
## (the wave-1 collision exceptions are permanent) — griefing is AVATAR-VS-
## AVATAR. The verbs, inside the existing 2-button budget:
##   MOVE  walk/run the course (get_move; -3 mouse seats auto-grief via seek-bot)
##   A     SHOVE — HIT KIT feel per docs/design/08 (windup, hitstop, victim pop,
##         sparks, knockback). A shove that connects with the ACTING golfer
##         flinches their shot: address staggers, a live charge fires NOW with a
##         deflected angle (avatar_shot.flinch — only the (power, angle) INPUT
##         to the frozen debug_putt changes).
##   B     HOP (clears the knee-high walls onto the aprons) — or, standing at a
##         powered trap, TRIGGER it early (trap.grief_trigger: crusher slams,
##         fan gusts, bumper kicks, windmill lurches; kill rule untouched).
##
## Anti-frustration (spec, non-negotiable): cup exclusion disc (no camping the
## hole), shove/trigger cooldowns, flinch immunity so shoves can't chain-stun.
## Griefing earns GRUDGE + a highlight, never points (main._credit_grief).
##
## Determinism: every bot decision draws from _rng (seeded from GameState.rng's
## seed without consuming its stream) inside _physics_process — a --parbots
## chaos round is reproducible per --seed, run to run.

const GRIEF_REACH := 1.1
const SHOVE_CD := 0.8
const HOP_CD := 0.9
const TRIGGER_CD := 2.0          # per trap
const TRIGGER_RANGE := 1.0       # m beyond the trap's footprint that counts as "at it"
const SHOVE_WINDUP := 0.08       # HIT KIT: coil before the strike lands (<0.10)
const KNOCK_V := 5.2             # shove knockback on the victim avatar (m/s)
const KNOCK_UP := 2.6
const FLINCH_IMMUNE_T := 1.2     # a freshly-flinched golfer can't be re-flinched
const REVIVE_T := 1.6            # chaos: the death drama plays, then you rise
const PIT_Y := -0.8              # fell into the chasm (widow's walk)
const PIT_WINDOW := 4.0          # s a shove stays credited for a chasm fall
const STUCK_HOP_T := 0.55        # seek-bot: this long without progress -> hop

var active := false

var _main: Node3D
var _course: Course
var _avatars: Array = []
var _balls: Array = []
var _rng := RandomNumberGenerator.new()

var _shove_cd := {}       # p -> s
var _hop_cd := {}         # p -> s
var _windup := {}         # p -> {"t": s, "dir": Vector3}
var _immune := {}         # victim p -> s
var _trap_cd := {}        # trap instance id -> s
var _revive_t := {}       # p -> s down so far
var _seek_goal := {}      # p -> Vector3
var _seek_t := {}         # p -> s until goal re-pick
var _hop_wish := {}       # p -> bool
var _stuck_t := {}        # p -> s without progress
var _last_pos := {}       # p -> Vector3
## Pit respawn points are double-buffered: _safe_old is the grounded spot from
## ~20-40 ticks ago, so a respawn lands well BACK from the lip you fell off
## (respawning on the exact edge just tipped you straight back in).
var _safe_old := {}       # p -> Vector3
var _safe_new := {}       # p -> Vector3
var _safe_tick := {}      # p -> on-floor tick counter
var _pit_grace := {}      # p -> ticks of pit-check grace after a respawn
## After a chasm fall the seek-bot stays NEAR its respawn anchor for a few
## seconds instead of marching straight back over the lip (direct move_toward
## has no pathing — spec OQ5 — so this is the anti-lemming rule).
var _pit_anchor := {}     # p -> Vector3
var _side_lock := {}      # p -> s of local-wander lockdown
var _last_shove_on := {}  # victim p -> {"by": int, "t": ticks}
var _hitstop_cd := 0.0
var _cup_log_cd := 0.0
var _snapped := {}
var _active_t := 0.0   # s since activation (snap receipts wait out the intro banner)

## --griefprobe=verb,tick[,verb,tick...] — deterministically inject one griefer
## action at an exact physics tick (verbs: shove, cup, trigger, hop).
var _probes: Array = []
var _probe_cup := {}      # {"p": int, "until": int, "min_d": float}

func setup(main: Node3D) -> void:
	_main = main
	# Seed WITHOUT consuming GameState.rng's stream (read the seed, don't draw),
	# and distinct from main._bot_rng's xor so the two layers never correlate.
	_rng.seed = int(GameState.rng.seed) ^ 0x51EF6E55
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--griefprobe="):
			var parts := arg.trim_prefix("--griefprobe=").split(",")
			var k := 0
			while k + 2 <= parts.size():
				_probes.append({"verb": parts[k], "tick": int(parts[k + 1])})
				k += 2

func activate(course: Course, avatars: Array, balls: Array) -> void:
	_course = course
	_avatars = avatars
	_balls = balls
	active = true
	for p in _avatars.size():
		_shove_cd[p] = 0.0
		_hop_cd[p] = 0.0
		_seek_t[p] = 0.0
		_stuck_t[p] = 0.0
		_revive_t[p] = 0.0
		_last_pos[p] = _avatars[p].global_position
		_safe_old[p] = _avatars[p].global_position
		_safe_new[p] = _avatars[p].global_position
		_safe_tick[p] = 0
		_pit_grace[p] = 0
		_avatars[p].set_brawl(true)
	print("GRIEF_ON players=%d" % _avatars.size())

func deactivate() -> void:
	if not active:
		return
	active = false
	for a in _avatars:
		if a != null:
			a.set_brawl(false)
	print("GRIEF_OFF")

func _physics_process(delta: float) -> void:
	if not active or _main == null:
		return
	_active_t += delta
	_hitstop_cd = maxf(_hitstop_cd - delta, 0.0)
	_cup_log_cd = maxf(_cup_log_cd - delta, 0.0)
	for k in _immune.keys():
		_immune[k] = maxf(_immune[k] - delta, 0.0)
	for k in _trap_cd.keys():
		_trap_cd[k] = maxf(_trap_cd[k] - delta, 0.0)
	_tick_probes()
	var actor: int = _main.round_manager.current_player()
	for p in _avatars.size():
		var av: PlayerAvatar = _avatars[p]
		if av == null or not is_instance_valid(av):
			continue
		_shove_cd[p] = maxf(_shove_cd[p] - delta, 0.0)
		_hop_cd[p] = maxf(_hop_cd[p] - delta, 0.0)
		if av.is_downed():
			# The estate's dead still walk: the ball stays dead, the character
			# gets back up to grief (chaos-only flavor; normal rounds stay down).
			_revive_t[p] += delta
			if _revive_t[p] >= REVIVE_T:
				av.revive()
				_revive_t[p] = 0.0
			continue
		_revive_t[p] = 0.0
		if _windup.has(p):
			_tick_windup(p, av, delta)
		if p == actor and _main.avatar_shot.is_pending(p):
			continue   # the embodied shot machine owns this body right now
		if int(_probe_cup.get("p", -1)) != p:
			_drive(p, av, delta)   # (--griefprobe=cup steers this seat itself)
		_cup_exclusion(p, av, delta)
		_pit_check(p, av)
	_brawl_snap()

# --- per-seat drive ------------------------------------------------------------

func _drive(p: int, av: PlayerAvatar, delta: float) -> void:
	if _is_direct_human(p):
		var mv: Vector2 = PlayerInput.get_move(p)
		if mv.length() > 0.15:
			av.control_move(_cam_relative(mv))
		if PlayerInput.just_pressed(p, "a"):
			_try_shove(p, av)
		if PlayerInput.just_pressed(p, "b"):
			_try_b_verb(p, av)
		return
	_bot_drive(p, av, delta)

## A seat with a movement-capable device: kb halves, KB+MOUSE, pads. -3 (pure
## mouse) has no move analog — its griefer auto-walks via the seek-bot (spec
## OQ1 default) while its OWN shots keep mouse aim.
func _is_direct_human(p: int) -> bool:
	if _main._is_bot(p):
		return false
	var d: int = PlayerInput.device_of(p)
	return d >= 0 or d == -1 or d == -2 or d == -4

func _bot_drive(p: int, av: PlayerAvatar, delta: float) -> void:
	if _side_lock.get(p, 0.0) > 0.0:
		_side_lock[p] = float(_side_lock[p]) - delta
	_seek_t[p] -= delta
	if _seek_t[p] <= 0.0:
		_seek_t[p] = _rng.randf_range(0.5, 1.1)
		_pick_goal(p, av)
	var goal: Vector3 = _seek_goal.get(p, av.global_position)
	var to := goal - av.global_position
	to.y = 0.0
	if to.length() > 0.35:
		av.control_move(to.normalized())
	# stuck against a wall -> hop it (the aprons are the griefer highway)
	var moved: float = (av.global_position - _last_pos[p]).length()
	_last_pos[p] = av.global_position
	if to.length() > 0.6 and moved < 0.012:
		_stuck_t[p] += delta
	else:
		_stuck_t[p] = 0.0
	if (_stuck_t[p] >= STUCK_HOP_T or _hop_wish.get(p, false)) and _hop_cd[p] <= 0.0:
		_hop_wish[p] = false
		_stuck_t[p] = 0.0
		_do_hop(p, av)
	# in shove reach of a rival -> swing at them (cooldown limits the rate)
	if _shove_cd[p] <= 0.0 and not _windup.has(p):
		var victim := _nearest_rival(p, av, GRIEF_REACH * 0.95)
		if victim >= 0:
			var vd: Vector3 = _avatars[victim].global_position - av.global_position
			av.face_dir(vd)
			_try_shove(p, av)
	# standing at a powered trap -> sometimes slam it early
	var t := _trap_in_range(av)
	if t != null and _trap_cd.get(t.get_instance_id(), 0.0) <= 0.0 and _rng.randf() < 0.05:
		_do_trigger(p, av, t)

## Goal: the acting golfer (grief the shooter), a nearby powered trap (so the
## trigger verb fires across a match), or a wander point. All draws seeded.
func _pick_goal(p: int, av: PlayerAvatar) -> void:
	var actor: int = _main.round_manager.current_player()
	var roll := _rng.randf()
	_hop_wish[p] = _rng.randf() < 0.14
	var jitter := Vector3(_rng.randf_range(-0.7, 0.7), 0.0, _rng.randf_range(-0.7, 0.7))
	if _side_lock.get(p, 0.0) > 0.0:
		# fresh out of the pit: brawl locally, don't lemming back over the lip
		_seek_goal[p] = _pit_anchor.get(p, av.global_position) + jitter * 2.0
		return
	if roll < 0.22:
		var t := _nearest_powered_trap(av)
		if t != null:
			_seek_goal[p] = t.global_position + jitter * 0.5
			return
	var target := -1
	if actor >= 0 and actor != p and _avatars[actor] != null and not _avatars[actor].is_downed():
		target = actor
	else:
		target = _nearest_rival(p, av, 999.0)
	if target >= 0:
		_seek_goal[p] = _avatars[target].global_position + jitter
	else:
		_seek_goal[p] = av.global_position + jitter * 3.0

# --- verbs -----------------------------------------------------------------------

func _try_shove(p: int, av: PlayerAvatar) -> void:
	if _shove_cd[p] > 0.0 or _windup.has(p):
		return
	_shove_cd[p] = SHOVE_CD
	_windup[p] = {"t": SHOVE_WINDUP, "dir": av.facing}
	av.play_action("Unarmed_Melee_Attack_Punch_A", 0.45)
	Sfx.play("putt", -12.0)   # whoosh

func _tick_windup(p: int, av: PlayerAvatar, delta: float) -> void:
	var w: Dictionary = _windup[p]
	w["t"] = float(w["t"]) - delta
	if float(w["t"]) > 0.0:
		return
	_windup.erase(p)
	_strike(p, av, w["dir"])

func _strike(p: int, av: PlayerAvatar, dir: Vector3) -> void:
	var victim := -1
	var best := GRIEF_REACH
	for q in _avatars.size():
		if q == p or _avatars[q] == null or _avatars[q].is_downed():
			continue
		var to: Vector3 = _avatars[q].global_position - av.global_position
		to.y = 0.0
		if to.length() <= best and dir.dot(to.normalized() if to.length() > 0.01 else dir) > 0.1:
			best = to.length()
			victim = q
	if victim < 0:
		print("GRIEF_SHOVE by=%d whiff phys=%d" % [p, Engine.get_physics_frames()])
		return
	var vav: PlayerAvatar = _avatars[victim]
	var push := dir.normalized()
	# HIT KIT impact (docs/design/08): knockback + victim pop + attacker
	# follow-through + sparks + thud + shake + throttled micro-hitstop.
	vav.apply_knock(push * KNOCK_V + Vector3.UP * KNOCK_UP)
	vav.flash_pop()
	av.flash_lunge()
	var mid: Vector3 = (av.global_position + vav.global_position) * 0.5 + Vector3.UP * 0.85
	_spark(mid, GameState.players[p].color, push)
	_main.camera_rig.shake(0.28)
	Sfx.play("bumper", -5.0)
	_hitstop()
	var flinch := ""
	if _immune.get(victim, 0.0) <= 0.0:
		flinch = _main.avatar_shot.flinch(victim, push)
		if flinch != "":
			_immune[victim] = FLINCH_IMMUNE_T
	if flinch == "" and vav.anim != null:
		vav.play_action("Hit_A", 0.35)
	_last_shove_on[victim] = {"by": p, "t": Engine.get_physics_frames()}
	_main.note_grief(p, victim, "shove")
	print("GRIEF_SHOVE by=%d victim=%d flinch=%s phys=%d" % [p, victim, flinch, Engine.get_physics_frames()])
	# Snap receipt: a shove CONNECTING with the acting golfer mid-shot — but
	# only once the round-intro banner is gone, so the frame reads.
	if not _snapped.has("griefshove") and flinch != "" and _active_t > 6.0:
		_snapped["griefshove"] = true
		VerifyCapture.snap("griefshove")

func _try_b_verb(p: int, av: PlayerAvatar) -> void:
	var t := _trap_in_range(av)
	if t != null and _trap_cd.get(t.get_instance_id(), 0.0) <= 0.0:
		_do_trigger(p, av, t)
		return
	if _hop_cd[p] <= 0.0:
		_do_hop(p, av)

func _do_hop(p: int, av: PlayerAvatar) -> void:
	_hop_cd[p] = HOP_CD
	av.hop()
	Sfx.play("bounce", -14.0)
	print("GRIEF_HOP p=%d phys=%d" % [p, Engine.get_physics_frames()])

func _do_trigger(p: int, av: PlayerAvatar, t: Trap) -> void:
	if not t.grief_trigger():
		return
	_trap_cd[t.get_instance_id()] = TRIGGER_CD
	av.play_action("Interact", 0.5)
	Sfx.play("place", -6.0)
	_main.note_grief_trap(p, t)
	print("GRIEF_TRIGGER by=%d trap=%s phys=%d" % [p, t.trap_id, Engine.get_physics_frames()])

# --- anti-frustration ---------------------------------------------------------------

## No griefer may camp the hole: soft radial pushback at the cup-exclusion disc
## (radius = the course's cup no-build radius). Outpaces the run speed, so the
## boundary is a wall you slide around, not a place you can stand.
func _cup_exclusion(p: int, av: PlayerAvatar, delta: float) -> void:
	var cup: Vector3 = _course.cup_position()
	var away := Vector3(av.global_position.x - cup.x, 0.0, av.global_position.z - cup.z)
	var r: float = _course.cup_no_build_radius
	if away.length() >= r:
		return
	if away.length() < 0.01:
		away = Vector3(0, 0, 1)
	var target := cup + away.normalized() * r
	target.y = av.global_position.y
	av.global_position = av.global_position.move_toward(target, 6.5 * delta)
	if _cup_log_cd <= 0.0:
		_cup_log_cd = 0.4
		print("GRIEF_CUP_PUSH p=%d d=%.2f r=%.2f" % [p, away.length(), r])

## Fell into the chasm (widow's walk) or off the world: respawn at a grounded
## spot from ~half a second BACK (never the lip itself); a fresh shove earns
## the shover the highlight.
func _pit_check(p: int, av: PlayerAvatar) -> void:
	if _pit_grace.get(p, 0) > 0:
		_pit_grace[p] = int(_pit_grace[p]) - 1
		return
	if av.global_position.y > PIT_Y:
		if av.is_on_floor() and av.global_position.y > -0.1:
			_safe_tick[p] = int(_safe_tick[p]) + 1
			if int(_safe_tick[p]) % 20 == 0:
				_safe_old[p] = _safe_new[p]
				_safe_new[p] = av.global_position
		return
	var by := -1
	if _last_shove_on.has(p):
		var e: Dictionary = _last_shove_on[p]
		if Engine.get_physics_frames() - int(e["t"]) <= int(PIT_WINDOW * 60.0):
			by = int(e["by"])
	var home: Vector3 = _safe_old.get(p, _main._tee_pos(p))
	av.teleport_to(home + Vector3.UP * 0.1)
	av.play_action("Hit_A", 0.4)
	_pit_grace[p] = 30
	_pit_anchor[p] = home
	_side_lock[p] = 6.0
	_seek_t[p] = 0.0   # bot: pick a fresh goal from the respawn spot
	print("GRIEF_PIT p=%d by=%d phys=%d" % [p, by, Engine.get_physics_frames()])
	_main.on_avatar_pitfall(p, by)

# --- helpers ------------------------------------------------------------------------

func _nearest_rival(p: int, av: PlayerAvatar, max_d: float) -> int:
	var best := max_d
	var who := -1
	for q in _avatars.size():
		if q == p or _avatars[q] == null or _avatars[q].is_downed():
			continue
		var d: float = Vector2(_avatars[q].global_position.x - av.global_position.x,
			_avatars[q].global_position.z - av.global_position.z).length()
		if d < best:
			best = d
			who = q
	return who

func _trap_in_range(av: PlayerAvatar) -> Trap:
	var t := _nearest_powered_trap(av)
	if t == null:
		return null
	var d: float = Vector2(t.global_position.x - av.global_position.x,
		t.global_position.z - av.global_position.z).length()
	return t if d <= t.footprint_radius + TRIGGER_RANGE else null

func _nearest_powered_trap(av: PlayerAvatar) -> Trap:
	var container: Node = _course.get_node("TrapContainer")
	var best := INF
	var found: Trap = null
	for t in container.get_children():
		if not t is Trap or t.is_ghost:
			continue
		if not t.trap_id in ["crusher", "fan", "bumper", "windmill"]:
			continue
		var d: float = Vector2(t.global_position.x - av.global_position.x,
			t.global_position.z - av.global_position.z).length()
		if d < best:
			best = d
			found = t
	return found

func _cam_relative(mv: Vector2) -> Vector3:
	var cam: Camera3D = _main.camera_rig.get_node("Camera3D")
	if cam == null:
		return Vector3(mv.x, 0.0, mv.y)
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	var right: Vector3 = cam.global_transform.basis.x
	right.y = 0.0
	if fwd.length() < 0.01 or right.length() < 0.01:
		return Vector3(mv.x, 0.0, mv.y)
	var v := right.normalized() * mv.x + fwd.normalized() * (-mv.y)
	return v.normalized() * minf(mv.length(), 1.0) if v.length() > 0.05 else Vector3.ZERO

## HIT KIT micro-hitstop: 45ms at 0.15 scale, one at a time, 0.14s throttle.
## Presentation only — physics ticks advance identically (skip headless anyway).
func _hitstop() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _hitstop_cd > 0.0 or Engine.time_scale < 0.99:
		return
	_hitstop_cd = 0.14
	Engine.time_scale = 0.15
	get_tree().create_timer(0.045, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0)

## HIT KIT spark burst at the contact midpoint (white -> attacker color).
func _spark(pos: Vector3, color: Color, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	_main.add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.emitting = false
	p.amount = 10
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -6.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE.lerp(color, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	p.emitting = true
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)

## Once per chaos round: 3+ avatars scrumming while a ball rolls = the brawl shot.
func _brawl_snap() -> void:
	if _snapped.has("brawl") or not VerifyCapture.active or _active_t < 8.0:
		return
	var alive: Array = []
	for a in _avatars:
		if a != null and not a.is_downed():
			alive.append(a)
	if alive.size() < 3:
		return
	var packed := 0
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			if alive[i].global_position.distance_to(alive[j].global_position) < 3.5:
				packed += 1
	var rolling := false
	for b in _balls:
		if b != null and not b.is_sunk and not b.is_dead and b.linear_velocity.length() > 1.0:
			rolling = true
	if packed >= 3 and rolling:
		_snapped["brawl"] = true
		VerifyCapture.snap("brawl")

# --- --griefprobe -------------------------------------------------------------------

func _tick_probes() -> void:
	var now := Engine.get_physics_frames()
	if not _probe_cup.is_empty():
		var p: int = _probe_cup["p"]
		var av: PlayerAvatar = _avatars[p]
		var cup: Vector3 = _course.cup_position()
		var d: float = Vector2(av.global_position.x - cup.x, av.global_position.z - cup.z).length()
		_probe_cup["min_d"] = minf(float(_probe_cup["min_d"]), d)
		var to := cup - av.global_position
		to.y = 0.0
		av.control_move(to.normalized())
		if now >= int(_probe_cup["until"]):
			print("GRIEFPROBE_CUP p=%d min_d=%.2f exclude_r=%.2f" % [p, _probe_cup["min_d"], _course.cup_no_build_radius])
			_probe_cup = {}
	for pr in _probes.duplicate():
		if now < int(pr["tick"]):
			continue
		_probes.erase(pr)
		_run_probe(String(pr["verb"]))

func _run_probe(verb: String) -> void:
	var actor: int = _main.round_manager.current_player()
	var g := -1
	for p in _avatars.size():
		if p != actor and _avatars[p] != null and not _avatars[p].is_downed():
			g = p
			break
	if g < 0:
		print("GRIEFPROBE no griefer available verb=%s" % verb)
		return
	var av: PlayerAvatar = _avatars[g]
	match verb:
		"shove":
			var tgt := actor if actor >= 0 and actor != g else _nearest_rival(g, av, 999.0)
			if tgt < 0:
				return
			var vav: PlayerAvatar = _avatars[tgt]
			var behind: Vector3 = vav.global_position - vav.facing * 0.75
			av.teleport_to(Vector3(behind.x, vav.global_position.y + 0.05, behind.z))
			av.face_dir(vav.global_position - av.global_position)
			_shove_cd[g] = 0.0
			_windup.erase(g)
			print("GRIEFPROBE shove staged by=%d target=%d" % [g, tgt])
			_try_shove(g, av)
		"cup":
			_probe_cup = {"p": g, "until": Engine.get_physics_frames() + 600, "min_d": 999.0}
			print("GRIEFPROBE cup staged p=%d" % g)
		"trigger":
			var t := _nearest_powered_trap(av)
			if t == null:
				print("GRIEFPROBE trigger: no powered trap on course")
				return
			var side: Vector3 = t.global_position + Vector3(t.footprint_radius + 0.5, 0.0, 0.0)
			av.teleport_to(Vector3(side.x, 0.05, side.z))
			_trap_cd[t.get_instance_id()] = 0.0
			print("GRIEFPROBE trigger staged by=%d trap=%s" % [g, t.trap_id])
			_do_trigger(g, av, t)
		"hop":
			_hop_cd[g] = 0.0
			print("GRIEFPROBE hop staged p=%d" % g)
			_do_hop(g, av)
