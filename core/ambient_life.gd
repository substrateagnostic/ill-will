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
const CROW_GLB := "res://assets/models/meshy/generated/npc_crow_perched.glb"  # the crow landed (W3): real perched silhouette, no longer a tinted gull
const SEAGULL_GLB := "res://assets/models/meshy/seagull.glb"
const GROUNDSKEEPER_GLB := ""   # "" -> KayKit Barbarian, re-tinted muted brown
const MOURNER_GLB := ""         # "" -> KayKit walker under the ghost shader

const KAYKIT_BARBARIAN := "res://assets/models/kaykit/Barbarian.glb"
const KAYKIT_KNIGHT := "res://assets/models/kaykit/Knight.glb"
const KAYKIT_MAGE := "res://assets/models/kaykit/Mage.glb"
const KAYKIT_ROGUE := "res://assets/models/kaykit/Rogue.glb"

const GEN := "res://assets/models/meshy/generated/"

# ---------------------------------------------------------------- rigged troupe
## THE RIGGING WAVE (E3, night 5): three humanoids given real bones via Meshy's
## auto-rig + preset animations. Each member prefers its animated GLB when it is
## on disk (MeshyProp.instance_rigged, keyed off the rig's real-world NATIVE
## height — NEVER an AABB, which reads ~1/100 on a skinned mesh) and falls back
## to the old static+procedural path when absent. Native heights are the rig
## `height_meters` recorded in tools/meshy_rig_wave_report.json.
const GROUNDSKEEPER_ANIM := GEN + "npc_groundskeeper_idle.glb"
const GROUNDSKEEPER_NATIVE := 1.8
const MOURNER_ELDERLY_ANIM := GEN + "npc_mourner_elderly_idle.glb"
const MOURNER_ELDERLY_NATIVE := 1.65
const MOURNER_HOODED_ANIM_BOW := GEN + "npc_mourner_hooded_bow.glb"    # "pay respects"
const MOURNER_HOODED_ANIM_IDLE := GEN + "npc_mourner_hooded_idle.glb"  # fallback if bow absent
const MOURNER_HOODED_NATIVE := 1.75

# ---------------------------------------------------------------- tuning
const SCAN_HZ := 8.0            # proximity/behaviour scan rate (throttled _process)
const LOD_FAR := 30.0          # beyond this from player AND camera, a member idles

var _rng := RandomNumberGenerator.new()   # OWN stream — NEVER EstateState.rng
var _members: Array[AmbientMember] = []
var _walkers_root: Node3D
var _cam: Camera3D
var _grounds: Node3D
var _scan_accum := 0.0
var _podium := Vector3(3.5, 0.0, -2.5)   # fallback "who's losing" gaze point

## Build the troupe on the grounds. `grounds` is $Grounds (we parent everything
## under it), `walkers_root` is $Grounds/Walkers, `cam` the estate camera.
func setup(grounds: Node3D, walkers_root: Node3D, cam: Camera3D) -> void:
	_walkers_root = walkers_root
	_cam = cam
	_grounds = grounds
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

## Dev-only: force Old Rake into his stare at a point (the jump trigger, minus
## the physics race — the gameplay path is the vy>2 check in Groundskeeper.tick).
func debug_stare(world_pos: Vector3) -> void:
	for m in _members:
		if m is Groundskeeper:
			(m as Groundskeeper).debug_force_stare(world_pos)

## Dev-only: the front mourner consults its watch now (verify shots).
func debug_check_watch() -> void:
	for m in _members:
		if m is GhostQueue:
			(m as GhostQueue).debug_check_watch()

## Dev-only: freeze the seagull mid-wheel and pop the runt lantern bright, so a
## windowed shot catches both airborne/figureless members in place.
func debug_extras() -> void:
	for m in _members:
		if m is Seagull:
			(m as Seagull).debug_pose(10.0, -2.2)
		elif m is MoodyLantern:
			(m as MoodyLantern).debug_bright()

# ---------------------------------------------------------------- member wiring
func _build_members() -> void:
	_add_member(CrowGallery.new())
	_add_member(Groundskeeper.new())
	_add_member(GhostQueue.new())
	_add_member(Atmosphere.new())
	_add_member(Seagull.new())
	_add_member(MoodyLantern.new())

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

func grounds() -> Node3D:
	return _grounds

## Cross-member gags (the seagull steals Old Rake's leaves; a guttering lantern
## startles the flock). Return null-safe so a member can be absent.
func groundskeeper() -> Groundskeeper:
	for m in _members:
		if m is Groundskeeper:
			return m as Groundskeeper
	return null

func gallery() -> CrowGallery:
	for m in _members:
		if m is CrowGallery:
			return m as CrowGallery
	return null

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

## RIGGING WAVE: prefer a Meshy-rigged, animated GLB when it exists on disk.
## Returns a wrapper whose skinned model is scaled by target/native (feet at
## native y=0) with its shipped skeletal clip looping — or null when the path is
## absent, so callers fall back to their static character() path. First path in
## `paths` that resolves wins (lets a member prefer e.g. a bow over an idle).
static func rigged_or_null(paths: Array, native_height: float, height: float, animate := true) -> Node3D:
	for p in paths:
		var path := String(p)
		if path != "" and ResourceLoader.exists(path):
			return MeshyProp.instance_rigged(path, native_height, height, 0.0, animate)
	return null

## The AnimationPlayer of a rigged wrapper (for pausing a skeletal loop), or null.
static func anim_player_of(root: Node) -> AnimationPlayer:
	var ap := root.find_child("AnimationPlayer", true, false)
	if ap is AnimationPlayer:
		return ap as AnimationPlayer
	return null

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

	## A bigger flap — one crow startles off its perch and resettles. Called when
	## the runt lantern pops (doc §3.7 crosses §3.3).
	func startle() -> void:
		if _crows.is_empty():
			return
		var crow: Node3D = _crows[rr().randi_range(0, _crows.size() - 1)]
		var y0: float = crow.position.y
		var tw := crow.create_tween()
		tw.tween_property(crow, "position:y", y0 + 0.55, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(crow, "rotation:y", crow.rotation.y + rr().randf_range(-1.0, 1.0), 0.22)
		tw.tween_property(crow, "position:y", y0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

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
	const RAKING := 0
	const SURVEY := 1
	const STARE := 2
	const LEAF_HOME := [
		Vector3(0.14, 0.02, 0.50), Vector3(-0.12, 0.02, 0.56), Vector3(0.02, 0.02, 0.66)]

	var _model: Node3D
	var _rigged := false                 # true when Old Rake has Meshy bones
	var _anim: AnimationPlayer           # his skeletal loop (frozen mid-stare)
	var _rake: Node3D
	var _leaves: Array[MeshInstance3D] = []
	var _bubble: AmbientLife.GossipBubble
	var _state := RAKING
	var _state_t := 0.0
	var _rake_tw: Tween
	var _base_yaw := 0.0
	var _mutter_t := 0.0

	func build() -> void:
		reaction_radius = 3.0
		anchor = Vector3(-3.2, 0.0, 1.4)
		position = anchor
		_base_yaw = deg_to_rad(28.0)   # angled toward the lawn, working
		rotation.y = _base_yaw
		var path := AmbientLife.GROUNDSKEEPER_GLB
		if path == "" or not ResourceLoader.exists(path):
			path = AmbientLife.KAYKIT_BARBARIAN
		# prefer his rigged idle; the procedural rake + leaves layer on top of it.
		# (No broom/rake preset exists in the library — every "sweep" is a kick —
		# so his raking stays the swinging prop, now over real skeletal bones.)
		var rigged := AmbientLife.rigged_or_null([AmbientLife.GROUNDSKEEPER_ANIM], AmbientLife.GROUNDSKEEPER_NATIVE, 1.35)
		if rigged != null:
			_model = rigged
			_rigged = true
			_anim = AmbientLife.anim_player_of(_model)
			print("AMBIENT_RIGGED groundskeeper <- ", AmbientLife.GROUNDSKEEPER_ANIM)
		else:
			_model = AmbientLife.character(path, 1.35)
		AmbientLife.tint_model(_model, Color(0.60, 0.50, 0.40))   # muted groundskeeper browns
		add_child(_model)
		_rake = _build_rake()
		add_child(_rake)
		_rake.position = Vector3(0.16, 0.0, 0.30)
		for home in LEAF_HOME:
			var leaf := _build_leaf()
			add_child(leaf)
			leaf.position = home
			_leaves.append(leaf)
		_bubble = AmbientLife.GossipBubble.new()
		add_child(_bubble)
		_bubble.position = Vector3(0.0, 2.3, 0.0)
		_bubble.scale = Vector3(0.62, 0.62, 0.62)   # a mutter, not a broadcast
		_state_t = 4.0
		_mutter_t = rr().randf_range(16.0, 28.0)
		_start_rake_sweep()

	func tick(dt: float, nearest: Node3D, nearest_dist: float, _losing: Vector3, lod: bool) -> void:
		var near := nearest != null and nearest_dist < reaction_radius
		# the jab that stops him: a jump inside his patch
		if near and _state != STARE and _player_jumping(nearest):
			_enter_stare(nearest)
			return
		if _state == STARE:
			if not near:
				_exit_stare()
			elif nearest != null:
				_face(nearest.global_position, 0.25)   # track them, unblinking
			return
		if not lod:
			return
		_state_t -= dt
		if _state_t <= 0.0:
			if _state == RAKING:
				_state = SURVEY
				_state_t = 1.6
				if _rake_tw != null and _rake_tw.is_valid():
					_rake_tw.kill()
				# straighten, hand on back, survey the pile... then a sigh
				var tw := create_tween()
				tw.tween_property(self, "position:y", 0.06, 0.5).set_trans(Tween.TRANS_SINE)
				tw.tween_interval(0.5)
				tw.tween_property(self, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			else:
				_state = RAKING
				_state_t = rr().randf_range(3.5, 5.0)
				_reset_leaves()   # the pile never grows; the same three, forever
				_start_rake_sweep()
		# a rare, dry mutter of shop-talk (a real chronicle fact)
		_mutter_t -= dt
		if _mutter_t <= 0.0:
			_mutter_t = rr().randf_range(18.0, 32.0)
			if _state == RAKING:
				var lines: Array = life.chronicle_lines()
				if not lines.is_empty():
					_bubble.show_line(String(lines[rr().randi_range(0, lines.size() - 1)]))
					var b := _bubble
					get_tree().create_timer(4.5).timeout.connect(func() -> void:
						if is_instance_valid(b):
							b.hide_bubble())

	func _player_jumping(p: Node3D) -> bool:
		var v: Variant = p.get("velocity")
		return v is Vector3 and (v as Vector3).y > 2.0

	func _enter_stare(p: Node3D) -> void:
		_state = STARE
		_bubble.hide_bubble()
		if _rake_tw != null and _rake_tw.is_valid():
			_rake_tw.kill()
		_freeze_anim(true)     # he STOPS — the stare is the joke, so freeze the loop
		_scatter_leaves()
		_face(p.global_position, 0.2)

	func _exit_stare() -> void:
		_state = RAKING
		_state_t = rr().randf_range(3.0, 4.5)
		_freeze_anim(false)    # back to work
		_face_yaw(_base_yaw, 0.4)
		_reset_leaves()
		_start_rake_sweep()

	## Freeze/resume the skeletal loop (rigged path only; a no-op on KayKit static).
	func _freeze_anim(frozen: bool) -> void:
		if _anim != null:
			_anim.speed_scale = 0.0 if frozen else 1.0

	## Public: the vengeful seagull undoes his work (doc §3.5 crosses §3.1).
	func scatter_leaves() -> void:
		_scatter_leaves()

	## Dev-only: latch the stare toward a point (verify shots).
	func debug_force_stare(world_pos: Vector3) -> void:
		_state = STARE
		_bubble.hide_bubble()
		if _rake_tw != null and _rake_tw.is_valid():
			_rake_tw.kill()
		_freeze_anim(true)
		_scatter_leaves()
		_face(world_pos, 0.2)

	func _scatter_leaves() -> void:
		for leaf in _leaves:
			var to := leaf.position + Vector3(rr().randf_range(-0.7, 0.7), rr().randf_range(0.15, 0.35), rr().randf_range(0.2, 0.8))
			var tw := leaf.create_tween()
			tw.set_parallel(true)
			tw.tween_property(leaf, "position", to, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(leaf, "rotation:y", rr().randf_range(-6.0, 6.0), 0.55)

	func _reset_leaves() -> void:
		for i in _leaves.size():
			var leaf := _leaves[i]
			var tw := leaf.create_tween()
			tw.tween_property(leaf, "position", LEAF_HOME[i], 0.3)

	func _start_rake_sweep() -> void:
		if _rake_tw != null and _rake_tw.is_valid():
			_rake_tw.kill()
		_rake.rotation.x = -0.12
		_rake_tw = create_tween().set_loops()
		_rake_tw.tween_property(_rake, "rotation:x", 0.16, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_rake_tw.tween_property(_rake, "rotation:x", -0.12, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _face(world_pos: Vector3, t: float) -> void:
		var flat := world_pos - global_position
		flat.y = 0.0
		if flat.length() < 0.05:
			return
		_face_yaw(atan2(flat.x, flat.z), t)

	func _face_yaw(yaw: float, t: float) -> void:
		var tw := create_tween()
		tw.tween_property(self, "rotation:y", yaw, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func _build_rake() -> Node3D:
		var rake := Node3D.new()
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.40, 0.27, 0.16)
		wood.roughness = 0.9
		var handle := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.018
		hm.bottom_radius = 0.024
		hm.height = 1.1
		handle.mesh = hm
		handle.material_override = wood
		handle.rotation.x = deg_to_rad(58.0)
		handle.position = Vector3(0.0, 0.52, 0.18)
		rake.add_child(handle)
		var head := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.34, 0.03, 0.05)
		head.mesh = bm
		head.material_override = wood
		head.position = Vector3(0.0, 0.04, 0.62)
		rake.add_child(head)
		return rake

	func _build_leaf() -> MeshInstance3D:
		var leaf := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.26, 0.22)
		qm.orientation = PlaneMesh.FACE_Y
		leaf.mesh = qm
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.66, 0.36, 0.12)
		lm.cull_mode = BaseMaterial3D.CULL_DISABLED
		lm.roughness = 1.0
		leaf.material_override = lm
		return leaf

# ================================================================ 3.4 THE QUEUE
## The Patient Ghost(s): a polite queue of two for a mausoleum door that never
## opens. They hover, shuffle forward, and the front one checks a pocket watch;
## when a living walker passes they step aside and wave it ahead, then resettle
## at the back of the (still empty) line. (doc 26 §3.4)
class GhostQueue extends AmbientMember:
	const DOOR := Vector3(-7.7, 0.0, -7.6)   # the mausoleum front (never opens)
	var _ghosts: Array[Ghost] = []
	var _aside := false

	func build() -> void:
		reaction_radius = 3.2
		anchor = Vector3(-7.55, 0.0, -6.1)
		var figs := [AmbientLife.KAYKIT_MAGE, AmbientLife.KAYKIT_ROGUE]
		var homes := [Vector3(-7.55, 0.0, -6.35), Vector3(-7.6, 0.0, -5.72)]
		# RIGGING WAVE: real mourners get real bones. Front (with the pocket-watch
		# gag) is the weary elder on a quiet idle; back is the hooded figure that
		# prefers a "pay respects" bow, falling back to its own idle. Each falls
		# back to the ghostly-hover KayKit stand-in when its GLB is absent.
		var anim_sets := [
			[AmbientLife.MOURNER_ELDERLY_ANIM],
			[AmbientLife.MOURNER_HOODED_ANIM_BOW, AmbientLife.MOURNER_HOODED_ANIM_IDLE],
		]
		var natives := [AmbientLife.MOURNER_ELDERLY_NATIVE, AmbientLife.MOURNER_HOODED_NATIVE]
		for i in 2:
			var fig: String = AmbientLife.MOURNER_GLB
			if fig == "" or not ResourceLoader.exists(fig):
				fig = String(figs[i])
			var g := Ghost.new()
			add_child(g)
			g.build(anim_sets[i], float(natives[i]), fig, homes[i], DOOR, i == 0)
			g.begin(rr())
			_ghosts.append(g)

	func tick(dt: float, nearest: Node3D, nearest_dist: float, _losing: Vector3, lod: bool) -> void:
		if not lod:
			return
		var pass_by := nearest != null and nearest_dist < reaction_radius
		if pass_by and not _aside:
			_aside = true
			for g in _ghosts:
				g.step_aside()       # "after you" — let the living cut in
		elif not pass_by and _aside:
			_aside = false
			for g in _ghosts:
				g.resettle()
		for g in _ghosts:
			g.tick(dt, rr())

	## Dev-only: make the front mourner consult its watch now (verify shots).
	func debug_check_watch() -> void:
		if not _ghosts.is_empty():
			_ghosts[0].check_watch()

## One patient revenant. Hovers, shuffles up the (empty) line, consults a watch.
class Ghost extends Node3D:
	var _model: Node3D
	var _rigged := false          # true when this mourner has Meshy bones
	var _watch: Node3D
	var _home := Vector3.ZERO
	var _is_front := false
	var _bob_tw: Tween
	var _shuffle_t := 0.0
	var _watch_t := 0.0
	var _busy := false

	func build(anim_paths: Array, native_height: float, fallback_path: String, home: Vector3, face_target: Vector3, is_front: bool) -> void:
		_home = home
		_is_front = is_front
		position = home
		var rigged := AmbientLife.rigged_or_null(anim_paths, native_height, 1.32)
		if rigged != null:
			_model = rigged
			_rigged = true
			print("AMBIENT_RIGGED mourner <- ", str(anim_paths))
		else:
			_model = AmbientLife.character(fallback_path, 1.32)
		AmbientLife.ghostify(_model)
		add_child(_model)
		var flat := face_target - home
		flat.y = 0.0
		if flat.length() > 0.05:
			rotation.y = atan2(flat.x, flat.z)
		if is_front:
			_watch = _build_watch()
			add_child(_watch)
			_watch.position = Vector3(0.16, 0.82, 0.28)
			_watch.visible = false

	func begin(rng: RandomNumberGenerator) -> void:
		# a slow spectral hover — on the MODEL, so it never fights the node's own
		# position tweens (shuffle / step-aside). ONLY for the figureless KayKit
		# stand-in: a rigged mourner carries its own skeletal motion, and a
		# whole-body hover on top of that just fights the loop, so gate it off.
		if not _rigged:
			_bob_tw = _model.create_tween().set_loops()
			_bob_tw.tween_property(_model, "position:y", 0.14, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_bob_tw.tween_property(_model, "position:y", 0.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_shuffle_t = rng.randf_range(4.0, 7.0)
		_watch_t = rng.randf_range(6.0, 11.0)

	func tick(dt: float, rng: RandomNumberGenerator) -> void:
		if _busy:
			return
		_shuffle_t -= dt
		if _shuffle_t <= 0.0:
			_shuffle_t = rng.randf_range(5.0, 9.0)
			_shuffle_forward()
		if _is_front:
			_watch_t -= dt
			if _watch_t <= 0.0:
				_watch_t = rng.randf_range(8.0, 14.0)
				check_watch()

	## A hopeful 0.2 m creep toward a door that will not open, then settle back.
	func _shuffle_forward() -> void:
		var fwd := -global_transform.basis.z   # local forward
		fwd.y = 0.0
		fwd = fwd.normalized() * 0.2
		var tw := create_tween()
		tw.tween_property(self, "position", _home + fwd, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(1.4)
		tw.tween_property(self, "position", _home, 0.7).set_trans(Tween.TRANS_SINE)

	## Consult the pocket watch: it fades in, the mourner tips forward to read it,
	## then it fades away. Grief is real; the appointment after it is realer.
	func check_watch() -> void:
		if _watch == null:
			return
		_watch.visible = true
		_watch.scale = Vector3(0.6, 0.6, 0.6)
		var tw := create_tween()
		tw.tween_property(_watch, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_model, "rotation:x", 0.22, 0.25)
		tw.tween_interval(1.4)
		tw.tween_property(_model, "rotation:x", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			if is_instance_valid(_watch):
				_watch.visible = false)

	## "After you." Step aside and give a small bow to no one in particular.
	func step_aside() -> void:
		_busy = true
		var right := global_transform.basis.x
		right.y = 0.0
		var tw := create_tween()
		tw.tween_property(self, "position", _home + right.normalized() * 0.35, 0.4).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(_model, "rotation:x", 0.18, 0.3)
		tw.tween_property(_model, "rotation:x", 0.0, 0.3)

	func resettle() -> void:
		var tw := create_tween()
		tw.tween_property(self, "position", _home, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void: _busy = false)

	func _build_watch() -> Node3D:
		var w := Node3D.new()
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 0.02
		disc.mesh = cm
		disc.rotation.x = deg_to_rad(90.0)   # face outward like a held watch
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.95, 0.82, 0.35)
		gold.metallic = 0.6
		gold.roughness = 0.3
		gold.emission_enabled = true
		gold.emission = Color(1.0, 0.85, 0.4)
		gold.emission_energy_multiplier = 0.5
		disc.material_override = gold
		w.add_child(disc)
		return w

# ================================================================ 3.5 THE SEAGULL
## The estate's oldest grudge has feathers. Canon, wordless (doc 26 §3.5): it
## wheels overhead, then swoops — and when it swoops low over Old Rake's side of
## the lawn, it undoes his raking (crosses §3.1). Reuse-only: seagull.glb.
class Seagull extends AmbientMember:
	var _pivot: Node3D            # spins -> the bird wheels
	var _bird: Node3D            # dips on the pivot arm -> swoops
	var _spin_tw: Tween
	var _swoop_t := 0.0
	var _cooldown := 0.0

	func build() -> void:
		reaction_radius = 0.0     # airborne; it reacts to no one
		anchor = Vector3(0.0, 4.6, -1.5)
		_pivot = Node3D.new()
		_pivot.position = anchor
		add_child(_pivot)
		_bird = MeshyProp.instance(AmbientLife.SEAGULL_GLB, 0.62)
		_pivot.add_child(_bird)
		_bird.position = Vector3(5.2, 0.0, 0.0)   # out on the arm
		_bird.rotation.y = deg_to_rad(-90.0)      # face the direction of travel
		_spin_tw = create_tween().set_loops()
		_spin_tw.tween_property(_pivot, "rotation:y", TAU, 12.0).from(0.0)
		_swoop_t = rr().randf_range(6.0, 11.0)

	func tick(dt: float, _nearest: Node3D, _nd: float, _losing: Vector3, _lod: bool) -> void:
		_cooldown = maxf(0.0, _cooldown - dt)
		_swoop_t -= dt
		if _swoop_t <= 0.0 and _cooldown <= 0.0:
			_swoop_t = rr().randf_range(7.0, 13.0)
			_cooldown = 2.2
			_swoop()

	## A dive on the pivot arm: the bird drops toward the lawn and climbs back. At
	## the bottom, if it is over the west (Old Rake's) side, it scatters his pile.
	func _swoop() -> void:
		var y0: float = _bird.position.y
		var tw := _bird.create_tween()
		tw.tween_property(_bird, "position:y", -3.9, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(_at_bottom)
		tw.tween_property(_bird, "position:y", y0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func _at_bottom() -> void:
		if _bird.global_position.x < -1.0:
			var gk := life.groundskeeper()
			if gk != null:
				gk.scatter_leaves()   # it's the gull who undoes the raking
		Sfx.play("raven", -14.0)

	## Dev-only: park the bird at a wheel angle + arm-dip so a shot catches it.
	func debug_pose(angle_deg: float, y: float) -> void:
		if _spin_tw != null and _spin_tw.is_valid():
			_spin_tw.kill()
		_pivot.rotation.y = deg_to_rad(angle_deg)
		_bird.position.y = y

# ============================================================ 5. ATMOSPHERE FLOOR
## The wordless, figureless floor of life: fog wisps pooling in the graves,
## embers breathing over each lantern, and a distant crow-caw now and then. No
## reactions — it just makes the air feel occupied. (brief item 5)
class Atmosphere extends AmbientMember:
	# lantern glow positions (fixed in estate.tscn: Grounds/Lanterns/*)
	const LANTERNS := [
		Vector3(2.2, 0.95, 0.5), Vector3(-2.2, 0.95, 0.5),
		Vector3(5.2, 0.95, -4.5), Vector3(-5.2, 0.95, -4.5)]
	var _caw_t := 0.0

	func build() -> void:
		reaction_radius = 0.0
		anchor = Vector3(-7.3, 0.0, -6.0)
		_build_fog()
		for pos in LANTERNS:
			_build_embers(pos)
		_caw_t = rr().randf_range(8.0, 18.0)

	func tick(dt: float, _nearest: Node3D, _nd: float, _losing: Vector3, _lod: bool) -> void:
		_caw_t -= dt
		if _caw_t <= 0.0:
			_caw_t = rr().randf_range(14.0, 26.0)
			# a caw from somewhere in the dark — kept low, so it reads as distant
			Sfx.play("raven", rr().randf_range(-22.0, -17.0))

	func _build_fog() -> void:
		var fog := _particles(28, 10.0, Vector2(1.6, 1.1), Color(0.62, 0.72, 0.86, 0.10), false)
		fog.position = Vector3(-7.3, 0.28, -6.0)
		fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fog.emission_box_extents = Vector3(2.8, 0.22, 2.6)
		fog.direction = Vector3(1.0, 0.0, 0.25)
		fog.spread = 35.0
		fog.gravity = Vector3.ZERO
		fog.initial_velocity_min = 0.04
		fog.initial_velocity_max = 0.16
		fog.scale_amount_min = 0.7
		fog.scale_amount_max = 1.5
		fog.preprocess = 6.0
		add_child(fog)

	func _build_embers(at: Vector3) -> void:
		var em := _particles(9, 3.4, Vector2(0.05, 0.05), Color(1.0, 0.72, 0.32, 1.0), true)
		em.position = at
		em.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		em.emission_sphere_radius = 0.22
		em.direction = Vector3(0.0, 1.0, 0.0)
		em.spread = 25.0
		em.gravity = Vector3(0.0, 0.10, 0.0)   # embers drift up, not down
		em.initial_velocity_min = 0.08
		em.initial_velocity_max = 0.22
		em.scale_amount_min = 0.5
		em.scale_amount_max = 1.2
		em.preprocess = 2.0
		add_child(em)

	## A CPUParticles3D with a billboarded quad mesh + fade-in/out ramp. Cheap:
	## unshaded, few particles. `additive` embers glow; alpha fog just occludes.
	func _particles(amount: int, lifetime: float, mesh_size: Vector2, color: Color, additive: bool) -> CPUParticles3D:
		var p := CPUParticles3D.new()
		p.amount = amount
		p.lifetime = lifetime
		p.local_coords = false
		var qm := QuadMesh.new()
		qm.size = mesh_size
		p.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		mat.albedo_color = color
		mat.vertex_color_use_as_albedo = true
		if additive:
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.emission_enabled = true
			mat.emission = Color(color.r, color.g, color.b)
			mat.emission_energy_multiplier = 1.3
		p.material_override = mat
		# fade every particle in and out over its life so none pop
		var ramp := Gradient.new()
		ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
		ramp.add_point(0.35, color)
		ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
		p.color_ramp = ramp
		return p

# ============================================================ 3.7 MOODY LANTERNS
## The estate's infrastructure has moods. Every lantern glows steady except one
## runt that gutters on its own rhythm — dims, goes dark a beat, then pops back
## a touch too bright, startling the nearest crow off its perch (crosses §3.3).
## Reuse-only, figureless: it re-skins ONE existing lantern glow with its own
## material so the others stay steady. (doc 26 §3.7)
class MoodyLantern extends AmbientMember:
	var _mat: StandardMaterial3D
	var _base_energy := 2.0
	var _gutter_t := 0.0

	func build() -> void:
		reaction_radius = 0.0
		anchor = Vector3(5.2, 0.95, -4.5)   # the runt: Grounds/Lanterns/LGlow3
		var g := life.grounds()
		if g == null:
			return
		var glow := g.get_node_or_null("Lanterns/LGlow3") as MeshInstance3D
		if glow == null:
			return
		# give the runt its OWN material so guttering it doesn't dim the others
		var shared := glow.get_active_material(0)
		if shared is StandardMaterial3D:
			_mat = (shared as StandardMaterial3D).duplicate() as StandardMaterial3D
			_base_energy = _mat.emission_energy_multiplier
			glow.set_surface_override_material(0, _mat)
		_gutter_t = rr().randf_range(4.0, 8.0)

	func tick(dt: float, _nearest: Node3D, _nd: float, _losing: Vector3, _lod: bool) -> void:
		if _mat == null:
			return
		_gutter_t -= dt
		if _gutter_t <= 0.0:
			_gutter_t = rr().randf_range(5.0, 9.0)
			_gutter()

	## Dev-only: hold the runt at its bright pop (verify shots).
	func debug_bright() -> void:
		if _mat != null:
			_mat.emission_energy_multiplier = _base_energy * 1.9

	func _gutter() -> void:
		var tw := create_tween()
		tw.tween_property(_mat, "emission_energy_multiplier", _base_energy * 0.2, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_mat, "emission_energy_multiplier", 0.0, 0.25)
		tw.tween_interval(rr().randf_range(0.7, 1.1))          # dark, a worse night than yours
		tw.tween_property(_mat, "emission_energy_multiplier", _base_energy * 1.9, 0.14)   # pop, too bright
		tw.tween_callback(func() -> void:
			var gal := life.gallery()
			if gal != null:
				gal.startle())
		tw.tween_property(_mat, "emission_energy_multiplier", _base_energy, 0.6).set_trans(Tween.TRANS_SINE)
