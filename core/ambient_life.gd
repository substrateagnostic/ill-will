class_name AmbientLife
extends Node3D
## THE TROUPE — the estate grounds, made to breathe (doc 26 §3).
##
## The grounds are beautiful but dead: nothing moves that is not a player. This
## node hangs a small cast of background NPCs off the estate hub — crows that
## gossip the chronicle, a groundskeeper losing to three leaves, a ghost queue
## for a door that never opens — each a short behaviour loop with a *beat* where
## the joke lands (Untitled Goose Game's rule: set-up + punchline by behaviour,
## needing zero words).
##
## CONTRACT (this is also the online lobby, and the estate runs on modest PCs):
##   - PRESENTATION ONLY. Never writes EstateState; only READS chronicle_lines()
##     and standings(). Owns its OWN RandomNumberGenerator — never the sim rng —
##     so it can never desync a networked mirror.
##   - Near-zero cost: ONE throttled scan (SCAN_HZ) drives every member; motion
##     is tweens, not per-frame math; the whole troupe idles the instant the
##     grounds are hidden for a minigame (is_visible_in_tree gate).
##   - Lives UNDER $Grounds so the module-launch cleanup hides it too (props that
##     leak to root photobomb minigame frames — see estate.gd _spawn_executor).
##
## SWAP-CONSTS: several members stand in on shipped assets (a tinted seagull for a
## crow, a KayKit walker for a figure). When a real figure lands tonight, point
## the matching const at its .glb and the member adopts it with no other change.

# ---------------------------------------------------------------- swap-consts
const CROW_GLB := ""    # "" -> tinted seagull stand-in. A crow may land tonight.
const SEAGULL_GLB := "res://assets/models/meshy/seagull.glb"
const GROUNDSKEEPER_GLB := ""   # "" -> KayKit Barbarian, re-tinted muted brown
const MOURNER_GLB := ""         # "" -> KayKit walker under the ghost shader

const KAYKIT_BARBARIAN := "res://assets/models/kaykit/Barbarian.glb"
const KAYKIT_KNIGHT := "res://assets/models/kaykit/Knight.glb"
const KAYKIT_MAGE := "res://assets/models/kaykit/Mage.glb"
const KAYKIT_ROGUE := "res://assets/models/kaykit/Rogue.glb"

const GEN := "res://assets/models/meshy/generated/"

# ---------------------------------------------------------------- tuning
const SCAN_HZ := 8.0            # proximity/behaviour scan rate (throttled _process)
const LOD_FAR := 30.0          # beyond this from player AND camera, a member idles

var _rng := RandomNumberGenerator.new()   # OWN stream — NEVER EstateState.rng
var _members: Array[AmbientMember] = []
var _walkers_root: Node3D
var _cam: Camera3D
var _scan_accum := 0.0
var _podium := Vector3(3.5, 0.0, -2.5)   # fallback "who's losing" gaze point

## Build the troupe on the grounds. `grounds` is $Grounds (we parent everything
## under it), `walkers_root` is $Grounds/Walkers, `cam` the estate camera.
func setup(grounds: Node3D, walkers_root: Node3D, cam: Camera3D) -> void:
	_walkers_root = walkers_root
	_cam = cam
	_rng.randomize()   # local presentation — a different jitter each night is fine
	add_to_group("ambient_life")
	grounds.add_child(self)
	_build_graveyard()
	_build_members()

## Dev-only: force whatever the crows are gossiping to appear this instant, so a
## windowed verify shot is guaranteed to catch a bubble (see estate _ambient_test_run).
func debug_show_gossip() -> void:
	for m in _members:
		if m is CrowGallery:
			(m as CrowGallery).debug_pop_bubble()

# ---------------------------------------------------------------- member wiring
func _build_members() -> void:
	_add_member(CrowGallery.new())

func _add_member(m: AmbientMember) -> void:
	m.life = self
	add_child(m)
	m.build()
	_members.append(m)

# ---------------------------------------------------------------- the scan loop
func _process(delta: float) -> void:
	# The whole troupe sleeps while the grounds are hidden for a minigame.
	if not is_visible_in_tree():
		return
	_scan_accum += delta
	var step := 1.0 / SCAN_HZ
	if _scan_accum < step:
		return
	var dt := _scan_accum
	_scan_accum = 0.0
	var players := _gather_players()
	var losing := _losing_position(players)
	for m in _members:
		var nearest: Node3D = null
		var nd := 1.0e9
		for p in players:
			var d := m.anchor.distance_to(p.global_position)
			if d < nd:
				nd = d
				nearest = p
		var lod := nd < LOD_FAR
		if not lod and _cam != null:
			lod = _cam.global_position.distance_to(m.anchor) < LOD_FAR
		m.tick(dt, nearest, nd, losing, lod)

# ---------------------------------------------------------------- world queries
## Live player walkers on the grounds (never bots' logic — just their bodies).
func _gather_players() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _walkers_root == null or not is_instance_valid(_walkers_root):
		return out
	for c in _walkers_root.get_children():
		if c is Node3D and (c as Node3D).visible:
			out.append(c as Node3D)
	return out

## Where the crows should stare: the body of whoever is LOSING the night. Reads
## live standings; falls back to last night's last place, then the podium.
func _losing_position(players: Array[Node3D]) -> Vector3:
	var loser_idx := _losing_player_index()
	if loser_idx >= 0:
		for p in players:
			var pi_var: Variant = p.get("player_idx")
			if pi_var != null and int(pi_var) == loser_idx:
				return p.global_position
	if not players.is_empty():
		return players[0].global_position
	return _podium

func _losing_player_index() -> int:
	var order: Array = EstateState.standings()
	if order.is_empty():
		return -1
	var loser: int = int(order.back())
	var top: int = int(order[0])
	# If the field is undifferentiated (fresh night, everyone at 0), prefer last
	# night's DOORMAT so the birds still have an opinion.
	var pts_loser: int = int(EstateState.players[loser].points)
	var pts_top: int = int(EstateState.players[top].points)
	if pts_loser == pts_top and not EstateState.ledger.is_empty():
		var last: Dictionary = EstateState.ledger.back()
		for aw in last.get("awards", []):
			var a: Dictionary = aw
			if String(a.get("title", "")) == "THE DOORMAT":
				var who := String(a.get("who", ""))
				for i in EstateState.players.size():
					if String(EstateState.players[i].name) == who:
						return i
	return loser

## Chronicle lines the crows gossip. A READ of the estate's memory — never a
## write. May be as short as two lines on a fresh estate; that is fine.
func chronicle_lines() -> Array:
	return EstateState.chronicle_lines()

func rng() -> RandomNumberGenerator:
	return _rng

# ---------------------------------------------------------------- scenery
## A little burying ground in the open west of the lawn — homes for the crows,
## the mourners' door, a place for fog to pool. Clear of every existing landmark
## and off the central path, so no walker route is blocked.
func _build_graveyard() -> void:
	# thin iron fence sections along the south edge (crow perches, closest to cam)
	_prop(GEN + "estate_iron_gate.glb", 1.15, Vector3(-6.3, 0, -4.2), 12.0)
	_prop(GEN + "estate_iron_gate.glb", 1.15, Vector3(-7.9, 0, -4.5), -8.0)
	# headstones
	_prop(GEN + "grave_headstone_plain.glb", 1.0, Vector3(-6.5, 0, -5.4), 6.0)
	_prop(GEN + "grave_headstone_cracked.glb", 0.92, Vector3(-8.6, 0, -5.2), -14.0)
	_prop(GEN + "grave_small_obelisk.glb", 1.45, Vector3(-7.5, 0, -6.2), 0.0)
	_prop(GEN + "grave_celtic_cross.glb", 1.25, Vector3(-6.0, 0, -6.6), 20.0)
	# the dead tree (a high perch) and the door that never opens
	_prop(GEN + "estate_dead_tree.glb", 2.9, Vector3(-9.2, 0, -6.0), 40.0)
	_prop(GEN + "grave_mausoleum_front.glb", 2.6, Vector3(-7.7, 0, -7.6), 0.0)

## Instance a committed GLB at a spot, base on the ground. Returns the wrapper.
func _prop(path: String, height: float, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var w := MeshyProp.instance(path, height, yaw_deg)
	add_child(w)
	w.global_position = pos
	return w

# ================================================================ shared visuals
## A billboarded speech bubble: a dark panel with the estate's memory printed on
## it, floating over a member. Fades in/out; hides the instant a player leans in.
class GossipBubble extends Node3D:
	var _label: Label3D
	var _panel: MeshInstance3D
	var _tw: Tween

	func _init() -> void:
		_panel = MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2.7, 1.5)
		_panel.mesh = qm
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_color = Color(0.03, 0.02, 0.05, 0.82)
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pm.billboard_keep_scale = true
		pm.no_depth_test = true
		pm.render_priority = 1
		_panel.material_override = pm
		add_child(_panel)
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.render_priority = 2
		_label.fixed_size = false
		_label.pixel_size = 0.0043
		_label.font_size = 52
		_label.outline_size = 20
		_label.modulate = Color(1.0, 0.96, 0.82)
		_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.96)
		_label.width = 600.0
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		visible = false

	func show_line(text: String) -> void:
		_label.text = text
		# Visibility must NOT depend on the tween finishing — set the final scale
		# outright, then a small pop for life. (A tween-driven scale-from-zero left
		# the bubble at 1/100th size and effectively invisible.)
		scale = Vector3.ONE
		visible = true
		if _tw != null and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(self, "scale", Vector3.ONE, 0.20) \
			.from(Vector3(0.72, 0.72, 0.72)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func hide_bubble() -> void:
		if not visible:
			return
		if _tw != null and _tw.is_valid():
			_tw.kill()
		visible = false

# ---------------------------------------------------------------- model helpers
## Multiply every surface's albedo toward `mul` (keeps texture detail) — a cheap
## re-skin (white seagull -> dark crow, KayKit -> muted groundskeeper).
static func tint_model(root: Node, mul: Color) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base: Material = mi.get_active_material(s)
			var m: StandardMaterial3D
			if base is StandardMaterial3D:
				m = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				m = StandardMaterial3D.new()
			m.albedo_color = Color(m.albedo_color.r * mul.r, m.albedo_color.g * mul.g, m.albedo_color.b * mul.b, m.albedo_color.a)
			mi.set_surface_override_material(s, m)

## Replace every surface with a translucent, faintly-lit spectral material — the
## ghost look. Also stops the mesh casting shadows (a ghost throws none).
static func ghostify(root: Node) -> void:
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.60, 0.76, 0.88, 0.38)
	gm.emission_enabled = true
	gm.emission = Color(0.32, 0.52, 0.66)
	gm.emission_energy_multiplier = 0.6
	gm.rim_enabled = true
	gm.rim = 0.7
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = gm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Instance a KayKit/Meshy character GLB, uniformly scaled, AnimationPlayer set
## to a looped idle. Returns the wrapper (its child "Model" holds the mesh).
static func character(path: String, height := 1.35) -> Node3D:
	var w := MeshyProp.instance(path, height)
	var ap := w.find_child("AnimationPlayer", true, false)
	if ap is AnimationPlayer:
		var player := ap as AnimationPlayer
		for a in ["Idle", "Idle_A", "Idle_Loop"]:
			if player.has_animation(a):
				player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
				player.play(a)
				break
	return w

# ================================================================ member base
## A troupe member. The AmbientLife scan calls tick() at SCAN_HZ with the nearest
## player, its distance, the losing player's gaze point, and an LOD flag. Members
## drive smooth motion with tweens; tick() only advances timers and picks beats.
class AmbientMember extends Node3D:
	var life: AmbientLife
	var anchor: Vector3 = Vector3.ZERO
	var reaction_radius := 3.5

	func build() -> void:
		pass

	func tick(_dt: float, _nearest: Node3D, _nearest_dist: float, _losing: Vector3, _lod: bool) -> void:
		pass

	# convenience shared by members
	func rr() -> RandomNumberGenerator:
		return life.rng()

# ================================================================ 3.3 THE GALLERY
## Crows with opinions. They shuffle to face whoever is LOSING; a bubble over the
## flock gossips real chronicle lines as overheard birds; the instant a walker
## leans in they fall silent and snap innocently forward. (doc 26 §3.3 — the
## centerpiece: the estate's memory, leaking onto the lawn as ambient chatter.)
class CrowGallery extends AmbientMember:
	# perch: world position + the "innocent, looking-ahead" base yaw (radians).
	# Crows sit on the PALE STONE monuments (a dark bird reads against them; on the
	# black iron fence it vanished). Positions match _build_graveyard's stones.
	const PERCHES := [
		{"pos": Vector3(-7.5, 1.44, -6.2), "yaw": 0.10},    # small obelisk top
		{"pos": Vector3(-6.5, 1.02, -5.35), "yaw": -0.05},  # plain headstone top
		{"pos": Vector3(-8.6, 0.96, -5.15), "yaw": 0.22},   # cracked headstone top
		{"pos": Vector3(-6.0, 1.30, -6.55), "yaw": 0.05},   # celtic cross arm
	]
	var _crows: Array[Node3D] = []
	var _bubble: AmbientLife.GossipBubble
	var _lines: Array = []
	var _line_i := 0
	var _gossip_t := 0.0
	var _beat_t := 0.0
	var _silent := false
	var _last_aim := Vector3.INF

	func build() -> void:
		reaction_radius = 4.6
		anchor = Vector3(-7.4, 0.0, -5.2)
		var crow_path := AmbientLife.CROW_GLB
		if crow_path == "" or not ResourceLoader.exists(crow_path):
			crow_path = AmbientLife.SEAGULL_GLB
		var is_stand_in := crow_path == AmbientLife.SEAGULL_GLB
		for entry in PERCHES:
			var e: Dictionary = entry
			var crow := MeshyProp.instance(crow_path, 0.62)
			if is_stand_in:
				# the white gull reads as a crow once it is dark — but a mid charcoal,
				# not black: black birds vanished against the fence, and this arena is
				# soft with far-DOF, so they need to hold their silhouette.
				AmbientLife.tint_model(crow, Color(0.30, 0.30, 0.35))
			add_child(crow)
			crow.global_position = e["pos"]
			crow.rotation.y = float(e["yaw"])
			crow.set_meta("base_yaw", float(e["yaw"]))
			_crows.append(crow)
		_bubble = AmbientLife.GossipBubble.new()
		add_child(_bubble)
		_bubble.global_position = Vector3(-6.1, 3.05, -4.5)
		_refill_lines()
		_gossip_t = 1.5
		_beat_t = rr().randf_range(2.0, 4.0)

	func _refill_lines() -> void:
		_lines = life.chronicle_lines()
		# shuffle with OUR rng so the couch and a mirror need not agree (local only)
		for i in range(_lines.size() - 1, 0, -1):
			var j := rr().randi_range(0, i)
			var tmp: Variant = _lines[i]
			_lines[i] = _lines[j]
			_lines[j] = tmp
		_line_i = 0

	func tick(dt: float, nearest: Node3D, nearest_dist: float, losing: Vector3, lod: bool) -> void:
		var player_near := nearest != null and nearest_dist < reaction_radius
		if player_near and not _silent:
			_go_silent()
		elif not player_near and _silent:
			_resume()
		if _silent or lod == false:
			return
		# face the loser (only re-aim when the target has meaningfully moved)
		if _last_aim == Vector3.INF or _last_aim.distance_to(losing) > 0.6:
			_last_aim = losing
			_aim_flock(losing)
		# gossip cycle
		_gossip_t -= dt
		if _gossip_t <= 0.0:
			_gossip_t = rr().randf_range(5.0, 7.5)
			if _lines.is_empty():
				_refill_lines()
			if not _lines.is_empty():
				_bubble.show_line(String(_lines[_line_i]))
				_line_i += 1
				if _line_i >= _lines.size():
					_refill_lines()
		# the beat: a hop, and now and then a caw answered a moment later
		_beat_t -= dt
		if _beat_t <= 0.0:
			_beat_t = rr().randf_range(2.4, 4.5)
			_hop(_crows[rr().randi_range(0, _crows.size() - 1)])
			if rr().randf() < 0.4:
				Sfx.play("raven", -16.0)

	func _go_silent() -> void:
		_silent = true
		_bubble.hide_bubble()
		# heads snap forward — nothing to see here
		for crow in _crows:
			var y: float = float(crow.get_meta("base_yaw"))
			var tw := crow.create_tween()
			tw.tween_property(crow, "rotation:y", y, 0.18)

	func _resume() -> void:
		_silent = false
		_last_aim = Vector3.INF   # force a re-aim next tick
		_gossip_t = min(_gossip_t, 0.6)

	func _aim_flock(target: Vector3) -> void:
		for crow in _crows:
			var flat := target - crow.global_position
			flat.y = 0.0
			if flat.length() < 0.05:
				continue
			var yaw := atan2(flat.x, flat.z)
			var tw := crow.create_tween()
			tw.tween_property(crow, "rotation:y", yaw, 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _hop(crow: Node3D) -> void:
		var y0: float = crow.position.y
		var tw := crow.create_tween()
		tw.tween_property(crow, "position:y", y0 + 0.12, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(crow, "position:y", y0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	## Dev-only: pop the current gossip line up immediately (verify shots).
	func debug_pop_bubble() -> void:
		if _lines.is_empty():
			_refill_lines()
		if not _lines.is_empty():
			var i: int = clampi(_line_i, 0, _lines.size() - 1)
			_bubble.show_line(String(_lines[i]))

# ================================================================ 3.1 GROUNDSKEEPER
## Old Rake: Sisyphus with a rake. He rakes three leaves that never diminish. If
## a player jumps near his pile he stops and STARES until they leave — no line,
## the stare is the joke — then goes back to it. (doc 26 §3.1)
class Groundskeeper extends AmbientMember:
	pass

# ================================================================ 3.4 THE QUEUE
## The Patient Ghost(s): a polite queue for a mausoleum door that never opens.
## One checks a pocket watch; when a living walker passes, they wave it ahead.
## (doc 26 §3.4)
class GhostQueue extends AmbientMember:
	pass

# ================================================================ 3.5 THE SEAGULL
## The estate's oldest grudge has feathers. Canon, wordless (doc 26 §3.5): it
## wheels, dives, and undoes Old Rake's work. Built in the atmosphere pass.
class Seagull extends AmbientMember:
	pass
