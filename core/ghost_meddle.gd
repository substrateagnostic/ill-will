class_name GhostMeddle
extends Node3D
## THE HOUSE STANDARD FOR DEAD SEATS (doc 24 §6 / F25; exemplar
## minigames/dead_weight/dead_weight.gd, template minigames/last_will/lw_ghost.gd).
##
## "The dead get one verb." A knocked-out player becomes a drifting WISP in their
## own colour with their name floating faint above it, and gains exactly ONE small
## MEDDLE verb on their A button with a visible cooldown ring (core/cooldown_ring.gd
## conventions). When the verb lands the game files an ATTRIBUTION toast — "RED'S
## GHOST GUTTERED THE CANDLES" — in the estate's register (voice bible doc 26:
## death is administrative, no exclamation marks; the estate observes, never cheers).
##
## The verb is MISCHIEF, NOT MURDER. Each per-game meddle is a garnish: a gust that
## nudges a ball a few percent, a light that gutters, a floorboard that creaks. A
## meddle may never directly kill, never remove points, never decide a round on its
## own. The living should feel HAUNTED, not ROBBED.
##
## HUMAN-INPUT-ONLY, BY CONSTRUCTION. The game only raises a wisp for a dead HUMAN
## seat (never a bot), and the kit only polls PlayerInput — so a bot can never
## meddle and every all-bot CLI receipt (--*bots / --*tally) is byte-identical with
## or without this kit (no wisp is ever built on a receipt run). PlayerInput
## consults its _remote packet FIRST, so on the HOST a remote (online) dead
## player's A-press drives the SAME authoritative meddle with no new network
## messages: a SIM meddle (e.g. a nudged ball) rides the game's existing snapshot
## to the mirror; a PRESENTATION meddle (a light flicker) is cosmetic and each
## screen renders its own from local input. On a render mirror the kit is visuals
## only (the game already returns before its sim) — see tick_cosmetic.
##
## Per-game hook (≤6 lines, mirrors IntroCard):
##   _meddle = GhostMeddle.new(); add_child(_meddle)
##   _meddle.setup(self, cam, CD, presentation_only)
##   _meddle.set_bounds(Vector2.ZERO, Vector2(half_x, half_z))   # arena drift clamp
##   _meddle.meddled.connect(_on_ghost_meddle)                    # apply the nudge
## then, per authoritative physics tick:  _meddle.tick(delta)
## on a mirror tick:  _meddle.tick_cosmetic(delta, NetSession.my_seat())
## when a HUMAN seat dies:  _meddle.add_ghost(i, name, color, pos)
## when it respawns:  _meddle.remove_ghost(i)

## A dead human fired their verb this tick. `origin` is the wisp position, `aim` a
## horizontal unit vector (ZERO if the seat gave no direction). The game applies
## its small, safe nudge, then calls attribute(index, "<verb phrase>").
signal meddled(index: int, origin: Vector3, aim: Vector3)

const DEFAULT_CD := 3.0        # slow-charge: a garnish, effectively one per death

var _game: Node = null
var _cam: Camera3D = null
var _cd := DEFAULT_CD
var _presentation_only := false   # true => the meddle touches visuals only, so a
                                  # render-mirror may fire its own local seat's
                                  # verb (each screen renders its own flicker)
var _wisps: Dictionary = {}    # index -> GhostWisp
var _center := Vector2.ZERO    # arena centre (xz) for the drift clamp
var _half := Vector2(9.0, 9.0) # arena half-extents for the drift clamp
var _toast_layer: CanvasLayer = null
var _toast: Label = null
var _toast_t := 0.0

## game: the Minigame (unused hook for future needs). cam: for KBM cursor aim.
## cd: seconds between meddles. presentation_only: see _presentation_only above.
func setup(game: Node, cam: Camera3D, cd := DEFAULT_CD, presentation_only := false) -> void:
	_game = game
	_cam = cam
	_cd = maxf(0.5, cd)
	_presentation_only = presentation_only
	_build_toast()

## Arena bounds for the wisp free-fly clamp (so the dead stay in frame).
func set_bounds(center: Vector2, half: Vector2) -> void:
	_center = center
	_half = half
	for k in _wisps:
		(_wisps[k] as GhostWisp).set_bounds(_center, _half)

func has_ghost(index: int) -> bool:
	return _wisps.has(index)

func ghost_count() -> int:
	return _wisps.size()

## Raise a wisp for a newly-dead HUMAN seat. Callers MUST only pass human seats
## (never a bot) — that is what keeps every all-bot receipt byte-identical.
## drift: true = the wisp free-flies the arena floor from the player's move (the
## ground games). false = it hovers fixed at the death spot (spatial games like
## orbital, where a floor-clamped drift would fight the screen-relative controls).
func add_ghost(index: int, pname: String, color: Color, pos: Vector3, hover_y := 1.4, drift := true) -> void:
	if _wisps.has(index):
		return
	var w := GhostWisp.new()
	w.name = "GhostWisp%d" % index
	add_child(w)
	w.build(index, pname, color, hover_y, _cd, _game, drift)
	w.set_bounds(_center, _half)
	w.spawn_at(pos)
	_wisps[index] = w

func remove_ghost(index: int) -> void:
	if _wisps.has(index):
		var w: GhostWisp = _wisps[index]
		if is_instance_valid(w):
			w.queue_free()
		_wisps.erase(index)

func clear() -> void:
	for k in _wisps.keys():
		var w: GhostWisp = _wisps[k]
		if is_instance_valid(w):
			w.queue_free()
	_wisps.clear()

## Drive from the AUTHORITATIVE tick (host + couch). Reads each dead seat's move
## (drift) + A (meddle), fires `meddled` when the verb is ready. Never call on a
## render mirror (use tick_cosmetic there).
func tick(delta: float) -> void:
	_tick_toast(delta)
	for k in _wisps.keys():
		var w: GhostWisp = _wisps[k]
		if not is_instance_valid(w):
			continue
		w.tick_cooldown(delta)
		w.move_input = PlayerInput.get_move(k)
		if PlayerInput.just_pressed(k, "a") and w.ready():
			var aim := _aim_for(k, w)
			w.consume()
			meddled.emit(k, w.global_position, aim)

## Cosmetics pump for a render mirror. Drives the LOCAL seat's wisp from its own
## input (so a guest still feels present as a ghost); other dead seats idle-drift.
## For a PRESENTATION-only meddle the local seat's verb fires here too (each screen
## renders its own flicker — no sim, no network). A SIM meddle never fires on a
## mirror: the guest's A-press is relayed to the host, which applies it, and the
## result arrives through the game's existing snapshot stream.
func tick_cosmetic(delta: float, my_seat: int) -> void:
	_tick_toast(delta)
	for k in _wisps.keys():
		var w: GhostWisp = _wisps[k]
		if not is_instance_valid(w):
			continue
		if k == my_seat:
			w.tick_cooldown(delta)
			w.move_input = PlayerInput.get_move(k)
			if _presentation_only and PlayerInput.just_pressed(k, "a") and w.ready():
				var aim := _aim_for(k, w)
				w.consume()
				meddled.emit(k, w.global_position, aim)
		else:
			w.move_input = _decor_drift(w)

## File the attribution: "{NAME}'S GHOST {verb}." — estate register, no exclaim.
## Presentation only; safe from any display path (never on a receipt).
func attribute(index: int, verb: String) -> void:
	if not _wisps.has(index):
		return
	var w: GhostWisp = _wisps[index]
	_toast.text = "%s'S GHOST %s." % [w.pname, verb.to_upper()]
	_toast.add_theme_color_override("font_color", Color(w.color.r, w.color.g, w.color.b).lerp(Color.WHITE, 0.25))
	_toast_t = 2.2
	_toast.modulate.a = 1.0
	_toast.visible = true

## The dead-state hint-bar line for one seat, real keys via describe_binding
## (matches the _hint_seats pattern). verb: the short label ("GUST"/"GUTTER"...).
func hint_line(index: int, verb: String) -> String:
	if not _wisps.has(index):
		return ""
	var w: GhostWisp = _wisps[index]
	var mv: String = PlayerInput.describe_binding(index, "move")
	var fire: String = PlayerInput.describe_binding(index, "a")
	return "%s IS DEAD — %s drift · %s %s" % [w.pname, mv, fire, verb.to_upper()]

# ---------------------------------------------------------------- internals
func _aim_for(index: int, w: GhostWisp) -> Vector3:
	# TWIN-STICK CONVENTION (shared with dead_weight / last_will): mouse cursor
	# (KBM) or right stick (pad) AIMS; the LEFT drift channel is the fallback.
	var a := PlayerInput.get_aim_dir(index, w.global_position, _cam)   # KBM world dir
	if a == Vector3.ZERO:
		var st := PlayerInput.get_aim_stick(index)                     # pad right stick
		if st != Vector2.ZERO:
			a = Vector3(st.x, 0.0, st.y)
	if a == Vector3.ZERO:
		var mv := PlayerInput.get_move(index)                          # fallback: drift dir
		if mv != Vector2.ZERO:
			a = Vector3(mv.x, 0.0, mv.y)
	return a.normalized() if a.length() > 0.05 else Vector3.ZERO

## A slow, seedless idle wander for non-local mirror wisps. Uses the wall clock,
## never a sim RNG — cosmetic drift must not perturb determinism.
func _decor_drift(w: GhostWisp) -> Vector2:
	var t := Time.get_ticks_msec() * 0.001 + float(w.index) * 2.3
	return Vector2(sin(t * 0.6), cos(t * 0.47)) * 0.35

func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 40
	add_child(_toast_layer)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.0
	_toast.offset_top = 84.0
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.visible = false
	_toast_layer.add_child(_toast)

func _tick_toast(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t = maxf(0.0, _toast_t - delta)
		_toast.modulate.a = clampf(_toast_t / 0.6, 0.0, 1.0)   # ease out the last 0.6s
		if _toast_t <= 0.0:
			_toast.visible = false


## ------------------------------------------------------------------ GhostWisp
## The dead player's actor: a free-flying orb in their colour, a faint floating
## name, drifting wisps, a cooldown ring at its feet, and a "MEDDLE READY" tag.
## Construction follows DWGhost (dead_weight/poltergeist.gd) + LWGhostSeat
## (last_will/lw_ghost.gd). Presentation only; it holds no gameplay authority.
class GhostWisp:
	extends Node3D

	const FLY_SPEED := 6.0
	const FLY_ACCEL := 26.0

	var index := 0
	var pname := ""
	var color := Color.WHITE
	var hover_y := 1.4
	var drift := true
	var cd_full := GhostMeddle.DEFAULT_CD
	var owner_game: Node = null

	var move_input := Vector2.ZERO
	var _cd := 0.0
	var _vel := Vector3.ZERO
	var _center := Vector2.ZERO
	var _half := Vector2(9.0, 9.0)
	var _bob := 0.0

	var _orb: MeshInstance3D
	var _cd_ring: CooldownRing
	var _ready_label: Label3D

	func build(p_index: int, p_name: String, p_color: Color, p_hover: float, p_cd: float, p_owner: Node, p_drift := true) -> void:
		index = p_index
		pname = p_name
		color = p_color
		hover_y = p_hover
		drift = p_drift
		cd_full = maxf(0.5, p_cd)
		owner_game = p_owner
		_cd = 0.0                 # READY the instant you die — a dying breath
		_bob = float(p_index) * 1.7

		_orb = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		_orb.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(color.r, color.g, color.b, 0.7)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.4
		_orb.material_override = m
		add_child(_orb)

		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 1.9
		light.omni_range = 4.0
		add_child(light)

		var wisps := CPUParticles3D.new()
		wisps.amount = 18
		wisps.lifetime = 0.9
		wisps.local_coords = false
		wisps.direction = Vector3.UP
		wisps.spread = 28.0
		wisps.gravity = Vector3(0, 0.7, 0)
		wisps.initial_velocity_min = 0.25
		wisps.initial_velocity_max = 0.7
		wisps.scale_amount_min = 0.3
		wisps.scale_amount_max = 0.6
		var wm := SphereMesh.new()
		wm.radius = 0.06
		wm.height = 0.12
		wisps.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wmat.albedo_color = Color(color.r, color.g, color.b, 0.42)
		wisps.material_override = wmat
		wisps.emitting = true
		add_child(wisps)

		# faint floating name (colour + glyph, colourblind-safe)
		var nm := Label3D.new()
		nm.text = PlayerBadge.glyph(index) + " " + pname
		nm.font_size = 34
		nm.pixel_size = 0.006
		nm.modulate = Color(color.r, color.g, color.b, 0.7)
		nm.outline_size = 9
		nm.outline_modulate = Color(0.06, 0.05, 0.09)
		nm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nm.position = Vector3(0, 0.62, 0)
		nm.no_depth_test = true
		add_child(nm)

		# THE COOLDOWN RING at the wisp's feet: empty at fire -> full = READY.
		_cd_ring = CooldownRing.new()
		_cd_ring.setup(color, 0.62, 0.52, -hover_y + 0.06, 0.9)
		add_child(_cd_ring)

		_ready_label = Label3D.new()
		_ready_label.text = "MEDDLE READY"
		_ready_label.font_size = 24
		_ready_label.pixel_size = 0.006
		_ready_label.modulate = Color(0.85, 0.95, 1.0)
		_ready_label.outline_size = 7
		_ready_label.outline_modulate = Color(0.06, 0.05, 0.09)
		_ready_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_ready_label.position = Vector3(0, 0.94, 0)
		_ready_label.no_depth_test = true
		_ready_label.visible = false
		add_child(_ready_label)

	func set_bounds(center: Vector2, half: Vector2) -> void:
		_center = center
		_half = half

	func spawn_at(pos: Vector3) -> void:
		global_position = Vector3(pos.x, hover_y, pos.z)
		_vel = Vector3.ZERO

	func ready() -> bool:
		return _cd <= 0.0

	func consume() -> void:
		_cd = cd_full

	func tick_cooldown(delta: float) -> void:
		if _cd > 0.0:
			_cd = maxf(0.0, _cd - delta)

	func _process(delta: float) -> void:
		# free-fly drift (clamped to the arena so the dead stay in frame). A
		# stationary (drift=false) wisp holds the death spot and only bobs.
		if drift:
			var dir := Vector3(move_input.x, 0.0, move_input.y)
			var desired := dir * FLY_SPEED
			_vel.x = move_toward(_vel.x, desired.x, FLY_ACCEL * delta)
			_vel.z = move_toward(_vel.z, desired.z, FLY_ACCEL * delta)
			global_position += _vel * delta
			global_position.x = clampf(global_position.x, _center.x - _half.x, _center.x + _half.x)
			global_position.z = clampf(global_position.z, _center.y - _half.y, _center.y + _half.y)
			global_position.y = lerpf(global_position.y, hover_y, 1.0 - exp(-6.0 * delta))

		_bob += delta
		var s := 1.0 + sin(_bob * 6.0) * 0.12
		if _orb:
			_orb.scale = Vector3(s, s, s)

		if _cd_ring:
			var reduced := not bool(PartySetup.pref("screen_shake", true))
			_cd_ring.tick(delta, clampf(1.0 - _cd / cd_full, 0.0, 1.0), true, reduced)
		if _ready_label:
			var rdy := ready()
			_ready_label.visible = rdy
			if rdy:
				_ready_label.modulate.a = 0.6 + 0.35 * sin(_bob * 5.0)
