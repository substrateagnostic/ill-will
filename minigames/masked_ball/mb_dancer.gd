class_name MBDancer
extends Node3D
## One dancer at the MASKED BALL — NPC and human bodies use the SAME class,
## the SAME KayKit model (Rogue, hooded), the SAME ivory half-mask, the SAME
## movement speed. Identity hiding IS the game: no ring, no tag, no color
## anywhere on a body until a REVEAL moment (unmask, waste-flash, last dance).
## This is the anthology's one deliberate exception to always-on PlayerBadge
## identity — documented in docs/verify/maskedball-VERIFY.md.
##
## The node is a dumb pawn: masked_ball.gd owns ALL logic ticks (NPC brain,
## input, separation, still-metric) and drives this node in a fixed order so
## the sim stays deterministic. Only _process visuals live here (sway, glint
## decay, curtsy tilt) and they never gate logic. In tally mode the pawn is
## built with visual=false: no model, no materials, no tweens — pure state.
##
## THE PRIVATE PULSE (self-ID channel, zero on-screen secrets): feather your
## stick (deflected, but below the move threshold) and your mask GLINTS while
## your body stays put. NPC masks glint on seeded timers too, so a glint means
## nothing to observers — the secret is the CORRELATION with your own hidden
## stick, which only you can generate and verify.

enum Act { PAUSE, DRIFT, TWIRL, CURTSY }

# ---- logic state (main reads/writes; deterministic) ----
var body := 0                 # dancer id 0..N-1
var seat := -1                # owning player seat, -1 = NPC
var revealed := false         # mask torn off (dead human) or last-dance reveal
var gone := false             # corpse faded out
var facing := 0.0
var still_t := 0.0            # continuous near-stillness (public tell metric)
var flash_t := 0.0            # waste-flash countdown (position leak)
var glint_cd := 0.0           # human feather-glint cooldown
var act: int = Act.PAUSE
var act_t := 0.0              # time left in TWIRL/CURTSY
var act_dur := 1.0
var last_curtsy_end := -99.0  # waltz time this body last finished a bow
# NPC brain state (main's crowd rng drives it)
var npc_t := 0.5              # pause countdown / drift retry
var waypoint := Vector3.ZERO
var glint_next := 3.0
var npc_errand := -1           # public fake: clock / punch / west hall
var npc_errand_stage := 0
var npc_errand_t := 0.0
## ONLINE mirror counter: every glint (NPC decoy, feather pulse, kill lunge)
## bumps it, UNTAGGED — the wire carries "this mask glinted", never "whose
## hand did it". A remote player's own correlation with their hidden stick is
## the only thing that gives one of these numbers meaning, exactly as on the
## couch. Pure int, never read by logic.
var glints := 0
# waltz sway phase (visual only, derived from body id — no rng)
var _sway := 0.0

# ---- visuals ----
var _visual := false
var _pivot: Node3D
var _anim: AnimationPlayer
var _mask_mat: StandardMaterial3D
var _mask: MeshInstance3D
var _glint_t := 0.0
var _walking := false
var _tag: Label3D = null
var _ring: MeshInstance3D = null
var _flash_light: OmniLight3D = null
var _reaction_lock := 0.0
var _dimmed := false
var _wobble_t := 0.0          # ghost-gust shiver (visual only)
var coroner := false
var waxed := false
var _opener: Node3D = null
var _opener_mat: StandardMaterial3D = null
var _coroner_ring: MeshInstance3D = null
var _wax_root: Node3D = null

func setup(p_body: int, char_scene: PackedScene, visual: bool) -> void:
	body = p_body
	_visual = visual
	_sway = float(p_body) * 1.318
	if not _visual:
		return
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	if char_scene != null:
		var model := char_scene.instantiate()
		_pivot.add_child(model)
		_anim = model.find_child("AnimationPlayer", true, false)
		for anim_name in ["Idle", "Walking_A", "Running_A", "Cheer"]:
			if _anim and _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		if _anim:
			_anim.play("Idle")
			# desync the crowd's idle bob so 20 bodies do not metronome
			_anim.seek(fmod(_sway, 1.0), true)
		_build_mask(model)

## Ivory half-mask + thin gold crest, identical on every dancer, riding the
## HEAD BONE so it follows every bow and twirl (the chibi KayKit head is a
## ~1u sphere centered near y=1.7; the face is +Z).
func _build_mask(model: Node) -> void:
	var parent: Node3D = _pivot
	var at := Vector3(0, 1.66, 0.42)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel != null:
		var bone := skel.find_bone("head")
		if bone >= 0:
			var att := BoneAttachment3D.new()
			att.name = "MaskMount"
			skel.add_child(att)
			att.bone_name = "head"
			parent = att
			at = Vector3(0, 0.42, 0.44)   # relative to the head bone (y=1.24)
	_mask = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.36
	mm.height = 0.6
	_mask.mesh = mm
	_mask.scale = Vector3(1.0, 0.72, 0.42)
	_mask_mat = StandardMaterial3D.new()
	_mask_mat.albedo_color = Color(0.93, 0.89, 0.8)
	_mask_mat.roughness = 0.35
	_mask_mat.emission_enabled = true
	_mask_mat.emission = Color(1.0, 0.95, 0.8)
	_mask_mat.emission_energy_multiplier = 0.12
	_mask.material_override = _mask_mat
	_mask.position = at
	parent.add_child(_mask)
	var crest := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.5, 0.1, 0.03)
	crest.mesh = cm
	var crest_mat := StandardMaterial3D.new()
	crest_mat.albedo_color = Color(0.72, 0.58, 0.25)
	crest_mat.metallic = 0.7
	crest_mat.roughness = 0.35
	crest.material_override = crest_mat
	crest.position = at + Vector3(0, 0.28, -0.04)
	parent.add_child(crest)

# ================================================================ logic API
func busy() -> bool:
	return act == Act.TWIRL or act == Act.CURTSY

func curtsying() -> bool:
	return act == Act.CURTSY

func begin_curtsy(dur: float) -> void:
	act = Act.CURTSY
	act_t = dur
	act_dur = dur
	still_t = 0.0

func begin_twirl(dur: float) -> void:
	act = Act.TWIRL
	act_t = dur
	act_dur = dur
	still_t = 0.0

## Ends when act_t hits 0 (main decrements and calls this).
func end_act() -> void:
	act = Act.PAUSE

func face_toward(dir: Vector3) -> void:
	if dir.length() > 0.02:
		facing = atan2(dir.x, dir.z)
	rotation.y = facing

## Mask glint — the private pulse / ambient NPC noise. Pure visual.
func glint() -> void:
	glints += 1
	_glint_t = 0.55

## The Coroner is the one public body. The silver letter-opener is deliberately
## oversized and emissive: its glint, ring and badge all say the same thing
## without asking the room to read prose.
func set_coroner(col: Color, tag_text: String) -> void:
	coroner = true
	if not _visual or _opener != null:
		return
	_coroner_ring = MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.43
	rm.outer_radius = 0.5
	_coroner_ring.mesh = rm
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = col
	ring_mat.emission_enabled = true
	ring_mat.emission = col
	ring_mat.emission_energy_multiplier = 1.15
	_coroner_ring.material_override = ring_mat
	_coroner_ring.position.y = 0.035
	add_child(_coroner_ring)
	_show_tag(tag_text, col)
	_opener = Node3D.new()
	_opener.name = "LetterOpener"
	_opener.position = Vector3(0.48, 1.05, 0.3)
	_opener.rotation_degrees = Vector3(68, 0, -24)
	add_child(_opener)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.075, 0.075, 1.05)
	blade.mesh = bm
	_opener_mat = StandardMaterial3D.new()
	_opener_mat.albedo_color = Color(0.82, 0.88, 0.96)
	_opener_mat.metallic = 0.92
	_opener_mat.roughness = 0.16
	_opener_mat.emission_enabled = true
	_opener_mat.emission = Color(0.72, 0.84, 1.0)
	_opener_mat.emission_energy_multiplier = 1.4
	blade.material_override = _opener_mat
	blade.position.z = 0.34
	_opener.add_child(blade)
	var grip := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.09
	gm.bottom_radius = 0.11
	gm.height = 0.38
	grip.mesh = gm
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.18, 0.07, 0.055)
	grip_mat.roughness = 0.68
	grip.material_override = grip_mat
	grip.rotation_degrees.x = 90.0
	grip.position.z = -0.34
	_opener.add_child(grip)

## Wrong accusation: the opener visibly clatters away and a red-wax X stays
## on the public Coroner for the rest of the errand race.
func mark_wax_cross() -> void:
	waxed = true
	if not _visual:
		return
	if _opener != null:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_opener, "position", Vector3(0.9, 0.05, 0.8), 0.42)
		tw.tween_property(_opener, "rotation_degrees", Vector3(260, 80, 120), 0.42)
	if _wax_root != null:
		return
	_wax_root = Node3D.new()
	_wax_root.name = "WaxCross"
	_wax_root.position = Vector3(0, 1.62, 0.48)
	add_child(_wax_root)
	var wax_mat := StandardMaterial3D.new()
	wax_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wax_mat.albedo_color = Color(0.76, 0.02, 0.035)
	wax_mat.emission_enabled = true
	wax_mat.emission = Color(0.95, 0.015, 0.02)
	wax_mat.emission_energy_multiplier = 1.5
	for ang in [-42.0, 42.0]:
		var slash := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.1, 0.78, 0.07)
		slash.mesh = sm
		slash.material_override = wax_mat
		slash.rotation_degrees.z = ang
		_wax_root.add_child(slash)

# ================================================================ mirror API
## Render-only accessors + pose setter for the ONLINE mirror (phase 2). The
## mirror never runs the sim; it pipes the host's public facts into the same
## fields _process already reads. Never called on the couch.
func walking() -> bool:
	return _walking

func dimmed() -> bool:
	return _dimmed

## Set the acted pose from a snapshot. Durations are the couch constants
## (CURTSY 1.15 / TWIRL 1.1) — only the tilt/spin shape reads act_dur.
func mirror_act(p_act: int, p_act_t: float) -> void:
	act = p_act
	act_t = p_act_t
	act_dur = 1.15 if p_act == Act.CURTSY else 1.1

# ================================================================ reveal fx
## Waste-flash: the accuser's own body lights up — the position leak. This IS
## a (self-inflicted) reveal moment, so the tag may carry glyph+name+color.
func do_flash(dur: float, col: Color, tag_text: String) -> void:
	flash_t = dur
	if not _visual:
		return
	if _flash_light == null:
		_flash_light = OmniLight3D.new()
		_flash_light.omni_range = 4.2
		_flash_light.position.y = 1.4
		add_child(_flash_light)
	_flash_light.light_color = col
	_flash_light.light_energy = 7.0
	_show_tag(tag_text, col)
	if _tag != null:
		get_tree().create_timer(dur).timeout.connect(func():
			if not revealed and _tag != null:
				_tag.visible = false)

## Full reveal: mask off, identity ring + glyph tag. `slain` picks the anim.
func reveal(col: Color, tag_text: String, slain: bool) -> void:
	revealed = true
	if not _visual:
		return
	_show_tag(tag_text, col)
	if _ring == null:
		_ring = MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.46
		rm.bottom_radius = 0.5
		rm.height = 0.03
		_ring.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = col
		rmat.emission_enabled = true
		rmat.emission = col
		rmat.emission_energy_multiplier = 0.8
		_ring.material_override = rmat
		_ring.position.y = 0.02
		add_child(_ring)
	if _mask != null:
		# the mask flies off and tumbles
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_mask, "position", _mask.position + Vector3(0.3, 0.9, 0.4), 0.55)
		tw.tween_property(_mask, "rotation", Vector3(2.2, 1.0, 2.8), 0.55)
		tw.chain().tween_property(_mask, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	if _anim != null:
		_anim.play("Death_A" if slain else "Cheer")
		_reaction_lock = 99.0

## Last-dance treatment for the hired bodies: fade to dark silhouettes.
func dim_npc() -> void:
	if _dimmed or not _visual:
		return
	_dimmed = true
	_apply_overlay(Color(0.03, 0.02, 0.05, 0.82))

func fade_out() -> void:
	gone = true
	if not _visual:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.7)
	tw.tween_callback(func(): visible = false)

## Ghost gust brushed past — visual shiver only, never touches logic.
func wobble() -> void:
	_wobble_t = 0.55

func _show_tag(text: String, col: Color) -> void:
	if _tag == null:
		_tag = Label3D.new()
		_tag.font_size = 44
		_tag.pixel_size = 0.0075
		_tag.outline_size = 11
		_tag.outline_modulate = Color(0.05, 0.04, 0.07)
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.no_depth_test = true
		_tag.position = Vector3(0, 2.55, 0)
		add_child(_tag)
	_tag.text = text
	_tag.modulate = col
	_tag.visible = true

func _apply_overlay(col: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	_paint(self, m)

func _paint(node: Node, m: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = m
	for c in node.get_children():
		_paint(c, m)

## Main tells the pawn whether it travelled this tick (anim + still metric
## live with main; this only swaps the visual gait).
func set_walking(moving: bool) -> void:
	if moving == _walking:
		return
	_walking = moving
	if not _visual or _anim == null or _reaction_lock > 0.0:
		return
	var want := "Idle"
	if moving:
		want = "Walking_A" if _anim.has_animation("Walking_A") else "Running_A"
	if _anim.has_animation(want):
		_anim.play(want)

# ================================================================ visuals
func _process(delta: float) -> void:
	if not _visual or gone:
		return
	if _reaction_lock > 0.0:
		_reaction_lock -= delta
	# glint decay
	if _glint_t > 0.0:
		_glint_t = maxf(0.0, _glint_t - delta)
		var k := _glint_t / 0.55
		_mask_mat.emission_energy_multiplier = 0.12 + 2.6 * k
	elif flash_t > 0.0:
		# waste-flash strobe (main decrements flash_t)
		_mask_mat.emission_energy_multiplier = 1.0 + 2.0 * absf(sin(Time.get_ticks_msec() * 0.02))
		if _flash_light != null:
			_flash_light.light_energy = 3.0 + 2.5 * absf(sin(Time.get_ticks_msec() * 0.02))
	else:
		_mask_mat.emission_energy_multiplier = 0.12
		if _flash_light != null:
			_flash_light.light_energy = 0.0
	if _pivot == null:
		return
	# waltz sway (3/4 lilt) + curtsy tilt + twirl spin + gust shiver
	var tilt := 0.0
	var spin := 0.0
	match act:
		Act.CURTSY:
			var k2 := clampf(1.0 - act_t / maxf(0.05, act_dur), 0.0, 1.0)
			tilt = 0.62 * sin(k2 * PI)
		Act.TWIRL:
			spin = TAU * (1.0 - act_t / maxf(0.05, act_dur))
		_:
			pass
	var t := Time.get_ticks_msec() * 0.001
	if _opener_mat != null and not waxed:
		_opener_mat.emission_energy_multiplier = 1.0 + 1.35 * absf(sin(t * 4.2))
	var sway := 0.05 * sin(t * 2.4 + _sway)
	if _wobble_t > 0.0:
		_wobble_t = maxf(0.0, _wobble_t - delta)
		sway += 0.16 * sin(t * 40.0) * (_wobble_t / 0.55)
	_pivot.rotation.x = tilt + 0.015 * sin(t * 1.7 + _sway * 2.0)
	_pivot.rotation.z = sway
	_pivot.rotation.y = spin
	_pivot.position.y = 0.02 * absf(sin(t * 2.4 + _sway))
