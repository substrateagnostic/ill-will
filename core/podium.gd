class_name Podium
extends Node3D
## Reusable end-of-session podium ceremony. Instantiate, add to tree, call
## present(entries) — entries: [{name, color, char_scene: PackedScene, rank}]
## rank 0 = champion. Emits `done` after the ceremony.
##
## E1 — THE CORONATION art pass: the set is dressed as THE ESTATE ACKNOWLEDGING
## AN HEIR, not a game show. House look via EnvKit.MOONLIT (night blue, AGX, moon
## key + warm lantern pools), estate-stone plinths on a moonlit lawn, the family
## crypt and a sparse ring of markers behind, an estate-palette fall, a funeral
## wreath at the champion's plinth and a plain headstone for the fourth. The
## CONTRACT is untouched: present/stage_entries signatures + semantics, the entry
## dicts, avatar instancing/cosmetics/animation, the ~1.3s victor capture, the
## net-mirror rule (stage_entries never frees itself), and the -60y offscreen root.

signal done

const BLOCK_HEIGHTS := [1.5, 1.0, 0.6]
const BLOCK_X := [0.0, -1.7, 1.7]
const CEREMONY_TIME := 6.5
## M2 PODIUM EXIT (Andrew: "getting stuck in the podium screen for awhile — let
## the player exit at their leisure"). Once the coronation has read for this brief
## beat, a human couch hands the pace to the players: any seat's A (or click /
## Enter) advances immediately, and the screen then waits as long as they like —
## never a forced timer. An all-bot / verify session has no one to press A, so it
## auto-advances on the ceremony clock exactly as before (receipts unaffected).
const REVEAL_MIN := 1.6

var _continue_layer: CanvasLayer = null
var _continue_ready := false
var _continue_hit := false

# --- estate set dressing (all committed GLBs; guarded so a bare checkout still
# renders the tableau). Placed BEHIND the podium — the camera looks down +z. ---
const GEN := "res://assets/models/meshy/generated/"
const PROP_MAUSOLEUM := GEN + "grave_mausoleum_front.glb"
const PROP_LAMPPOST := GEN + "estate_lamppost.glb"
const PROP_DEADTREE := GEN + "estate_dead_tree.glb"
const PROP_WREATH := GEN + "board_funeral_wreath.glb"
const PROP_HEADSTONE := GEN + "grave_headstone_plain.glb"
const PROP_HEADSTONE_CELTIC := GEN + "grave_celtic_cross.glb"
const PROP_HEADSTONE_CRACKED := GEN + "grave_headstone_cracked.glb"
const FONT_IMFELL := "res://assets/fonts/IMFellEnglish-Regular.ttf"

@onready var cam := Camera3D.new()
var _imfell: Font = null

func _ready() -> void:
	global_position = Vector3(0, -60, 0)
	if ResourceLoader.exists(FONT_IMFELL):
		_imfell = load(FONT_IMFELL)
	# THE HOUSE LOOK, as code: moon-cool night, AGX, ground fog. The key is lifted
	# a touch and a cool rim added so the heirs read against the deep blue; the
	# warm lantern pools (below) supply the only warmth.
	EnvKit.apply(self, EnvKit.MOONLIT, {
		"key_energy": 1.3,
		"fill_energy": 0.38,
		"rim_energy": 0.5,
		"fog_density": 0.010,
	})
	# THE GROUNDS: a moonlit lawn plot — dark green gone plum in the blue light —
	# where the prototype had a bare grey disc.
	var floor_mesh := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 7.0
	fm.bottom_radius = 7.0
	fm.height = 0.2
	floor_mesh.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.075, 0.095, 0.082)
	fmat.roughness = 0.95
	fmat.metallic = 0.0
	floor_mesh.material_override = fmat
	floor_mesh.position.y = -0.1
	add_child(floor_mesh)
	_build_estate_set()
	# Camera pulled up/back modestly from the prototype so the wreath at the base,
	# the fourth's marker at x~4, and a little of the crypt behind all sit in frame.
	cam.position = Vector3(0, 3.7, 8.4)
	cam.rotation_degrees = Vector3(-15, 0, 0)
	cam.fov = 46.0
	add_child(cam)

## The estate come to witness: the family crypt stands square behind the podium,
## flanked by two lit lampposts (warm pools blooming against the moon key — the
## title-screen lantern grammar), with a dead tree and a few grave markers ringed
## further back. Counts kept modest so the 1-2-3 read stays clean.
func _build_estate_set() -> void:
	_dress(PROP_MAUSOLEUM, Vector3(0, 0, -6.9), 3.0, 180.0)
	_lamppost(Vector3(-4.5, 0, -3.3))
	_lamppost(Vector3(4.5, 0, -3.3))
	_dress(PROP_DEADTREE, Vector3(-6.3, 0, -4.7), 4.0, 25.0)
	_dress(PROP_HEADSTONE, Vector3(-3.1, 0, -4.9), 1.3, -18.0)
	_dress(PROP_HEADSTONE_CELTIC, Vector3(3.0, 0, -5.1), 1.6, 12.0)
	_dress(PROP_HEADSTONE_CRACKED, Vector3(5.8, 0, -4.4), 1.2, -8.0)

## Instance a committed prop at a LOCAL position (so it rides the -60y root with
## the rest of the set) scaled to `height`. No-op if the GLB is absent.
func _dress(path: String, pos: Vector3, height: float, yaw := 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var prop := MeshyProp.instance(path, height, yaw)
	add_child(prop)
	prop.position = pos

## A lamppost + its warm shadowless glow pool. The pool is added even if the post
## GLB is missing, so the estate's one warmth against the moonlight always reads.
func _lamppost(pos: Vector3) -> void:
	if ResourceLoader.exists(PROP_LAMPPOST):
		var post := MeshyProp.instance(PROP_LAMPPOST, 2.8)
		add_child(post)
		post.position = pos
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.42)
	lamp.light_energy = 3.0
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	add_child(lamp)
	lamp.position = pos + Vector3(0, 2.6, 0)

func present(entries: Array, ceremony_time := CEREMONY_TIME) -> void:
	stage_entries(entries)
	_scribe_victor(entries)
	if _has_human():
		# A human is watching: let the coronation land, then it's theirs to leave.
		await get_tree().create_timer(REVEAL_MIN).timeout
		await await_continue()
	else:
		# Bots / verify / attract: no hands on the couch — keep the old clock.
		await get_tree().create_timer(ceremony_time).timeout
	done.emit()

## Show the subtle "A · CONTINUE" affordance and return the moment any seat's A
## (or a click / Enter) is pressed. For callers that stage the tableau themselves
## (procession's heir crown) and want the couch to control the exit. Auto-returns
## after `bot_fallback` seconds when no human is present so nothing can hang.
func await_continue(bot_fallback := 2.5) -> void:
	if not _has_human():
		await get_tree().create_timer(bot_fallback).timeout
		return
	_show_continue()
	_continue_ready = true
	_continue_hit = false
	# Swallow one frame so an A still held from the final gameplay input doesn't
	# instantly skip the ceremony the couch just reached.
	await get_tree().process_frame
	var pi := get_node_or_null(^"/root/PlayerInput")
	while not _continue_hit:
		if pi != null:
			for s in 4:
				if pi.has_method("just_pressed") and pi.just_pressed(s, "a"):
					_continue_hit = true
					break
		if not _continue_hit:
			await get_tree().process_frame
	Sfx.play("ui_confirm")
	_continue_ready = false

## Any seat's A is polled in await_continue; a mouse click or Enter routes here.
func _unhandled_input(event: InputEvent) -> void:
	if not _continue_ready:
		return
	if event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		_continue_hit = true
		get_viewport().set_input_as_handled()

## A human is anyone with a real device who is not a bot (remote guests count —
## their injected input drives PlayerInput just like a couch pad).
func _has_human() -> bool:
	var pi := get_node_or_null(^"/root/PlayerInput")
	if pi == null:
		return false
	for s in 4:
		if pi.has_method("is_remote") and pi.is_remote(s):
			return true
		var is_bot: bool = pi.has_method("is_bot") and pi.is_bot(s)
		var dev: int = pi.device_of(s) if pi.has_method("device_of") else -99
		if not is_bot and dev != -99:
			return true
	return false

## The affordance: a subtle bottom-center "A · CONTINUE" in the house stationery,
## the A drawn as the first human seat's real device glyph (pad button or key)
## with a describe_binding text fallback. Gently pulses so it reads as "ready when
## you are", never a nag.
func _show_continue() -> void:
	if _continue_layer != null and is_instance_valid(_continue_layer):
		return
	_continue_layer = CanvasLayer.new()
	_continue_layer.layer = 5
	add_child(_continue_layer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.anchor_top = 1.0
	row.offset_top = -96.0
	row.offset_bottom = -40.0
	_continue_layer.add_child(row)
	var seat := _first_human_seat()
	var tex: Texture2D = _glyph_a(seat)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(40, 40)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
	else:
		var akey := Label.new()
		akey.text = _a_text(seat)
		if _imfell:
			akey.add_theme_font_override("font", _imfell)
		akey.add_theme_font_size_override("font_size", 30)
		akey.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
		akey.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06))
		akey.add_theme_constant_override("outline_size", 6)
		row.add_child(akey)
	var lbl := Label.new()
	lbl.text = "CONTINUE"
	if _imfell:
		lbl.add_theme_font_override("font", _imfell)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06))
	lbl.add_theme_constant_override("outline_size", 6)
	row.add_child(lbl)
	# fade in, then a soft breathing pulse — "ready when you are"
	row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.4)
	tw.chain().set_loops()
	tw.tween_property(row, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(row, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

func _first_human_seat() -> int:
	var pi := get_node_or_null(^"/root/PlayerInput")
	if pi == null:
		return 0
	for s in 4:
		if pi.has_method("is_remote") and pi.is_remote(s):
			continue   # a glyph for a remote seat can't be drawn on this machine
		var is_bot: bool = pi.has_method("is_bot") and pi.is_bot(s)
		var dev: int = pi.device_of(s) if pi.has_method("device_of") else -99
		if not is_bot and dev != -99:
			return s
	return 0

func _glyph_a(seat: int) -> Texture2D:
	# Device-aware: a pad seat gets its button glyph, a KBM seat its key glyph.
	return InputGlyphs.texture_for(seat, "a")

func _a_text(seat: int) -> String:
	var pi := get_node_or_null(^"/root/PlayerInput")
	if pi != null and pi.has_method("describe_binding"):
		return str(pi.describe_binding(seat, "a"))
	return "A"

## THE ESTATE'S MEMORY: the winner tableau is a picture worth keeping. Wait a
## beat so the champion has struck their cheer and the confetti is falling, then
## let MomentScribe grab THE VICTOR (priority 2 — below a deciding-moment freeze,
## above ordinary colour). Host-path only: present() rides the host clock, while
## net mirrors call stage_entries() directly and never reach here.
func _scribe_victor(entries: Array) -> void:
	var champ := ""
	for e in entries:
		if int(e.get("rank", -1)) == 0:
			champ = String(e.get("name", ""))
			break
	await get_tree().create_timer(1.3).timeout
	MomentScribe.capture("victor", "THE VICTOR", 2, [champ] if champ != "" else [])

## Build the tableau without the timer. present() rides it on the host; net
## mirrors call it directly — the HOST decides when a mirrored ceremony ends,
## so a client podium must never free itself on a local clock.
func stage_entries(entries: Array) -> void:
	cam.current = true
	for entry in entries:
		var rank: int = entry.rank
		var color: Color = entry.color
		var pos := Vector3.ZERO
		if rank < 3:
			var block := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.4, BLOCK_HEIGHTS[rank], 1.4)
			block.mesh = bm
			# Estate stone: dark, matte, weathered — the tier height carries the
			# rank now, not a pastel tint.
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.15, 0.15, 0.18)
			mat.roughness = 0.9
			mat.metallic = 0.0
			block.material_override = mat
			block.position = Vector3(BLOCK_X[rank], BLOCK_HEIGHTS[rank] / 2.0, 0)
			add_child(block)
			var num := Label3D.new()
			num.text = str(rank + 1)
			if _imfell:
				num.font = _imfell
			num.font_size = 140
			num.pixel_size = 0.004
			num.modulate = Color(0.87, 0.82, 0.71)   # bone / parchment
			num.outline_size = 10
			num.outline_modulate = Color(0.03, 0.03, 0.05, 0.9)
			num.position = Vector3(BLOCK_X[rank], BLOCK_HEIGHTS[rank] / 2.0, 0.72)
			add_child(num)
			# The champion's plinth takes the funeral wreath, leaned at a front
			# corner so it never covers the carved "1".
			if rank == 0 and ResourceLoader.exists(PROP_WREATH):
				var wreath := MeshyProp.instance(PROP_WREATH, 1.05, 8.0)
				add_child(wreath)
				wreath.position = Vector3(BLOCK_X[0] + 0.64, 0.0, 0.92)
				wreath.rotation_degrees = Vector3(-10, 8, 0)
			pos = Vector3(BLOCK_X[rank], BLOCK_HEIGHTS[rank], 0)
		else:
			pos = Vector3(3.4, 0, 0.8)
			# THE FOURTH PLACE: the estate notes a fourth place. One deadpan touch —
			# a plain headstone at the fallen heir's head, nothing else.
			if ResourceLoader.exists(PROP_HEADSTONE):
				var stone := MeshyProp.instance(PROP_HEADSTONE, 1.15, 6.0)
				add_child(stone)
				stone.position = Vector3(4.35, 0.0, 0.5)
		var scene: PackedScene = entry.char_scene
		var inst := scene.instantiate()
		inst.scale = Vector3(0.9, 0.9, 0.9)
		add_child(inst)
		inst.global_position = global_position + pos
		# Net mirrors ship explicit worn ids (the HOST's wardrobe truth) because
		# a guest's local cosmetics.json knows nothing about the host's estate.
		if entry.has("cosmetics"):
			for cid in entry.cosmetics:
				Cosmetics.equip(inst, String(cid))
		elif entry.has("player"):
			Cosmetics.apply_to_character(inst, entry.player)
		if rank >= 3:
			inst.rotation_degrees.y = 200.0
		var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if anim:
			var wanted: String = ["Cheer", "Idle", "Sit_Floor_Idle", "Lie_Idle"][mini(rank, 3)]
			if anim.has_animation(wanted):
				anim.get_animation(wanted).loop_mode = Animation.LOOP_LINEAR
				anim.play(wanted)
		var tag := Label3D.new()
		tag.text = entry.name
		if _imfell:
			tag.font = _imfell
		tag.font_size = 64
		tag.pixel_size = 0.005
		tag.modulate = color
		tag.outline_size = 18
		tag.outline_modulate = Color(0.10, 0.04, 0.11, 1.0)   # house plum
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = pos + Vector3(0, 2.0, 0)
		add_child(tag)
	_confetti()
	Sfx.play("match_win")
	# R9 — THE FIRST DUCKING SCAFFOLD's first caller: dip the Music bus under the
	# sting so it (and the deferred toll below) actually cut through the light
	# bed instead of fighting it. Bus-level, so it never touches play_slot's own
	# crossfade; ~1.5s hold comfortably covers the 0.5s toll deferral below.
	Music.duck(-6.0, 1.5)
	# A single distant toll layered UNDER the sting — the estate tolling for an
	# heir. Additive (never replaces match_win); deferred a beat so it reads as a
	# far bell after the flourish. Both host and mirror reach here, so both ring.
	get_tree().create_timer(0.5).timeout.connect(func() -> void: Sfx.play("bell_toll", -9.0))

## THE FALL — the same celebratory shower, in the estate's palette: ash flecks,
## gray-lavender petals, and a few warm ember motes that bloom on the AGX glow.
## Presentation only; shape and cadence unchanged from the prototype confetti.
func _confetti() -> void:
	var palettes := [
		{"albedo": Color(0.74, 0.74, 0.77), "emit": false},   # ash fleck
		{"albedo": Color(0.62, 0.58, 0.72), "emit": false},   # gray-lavender petal
		{"albedo": Color(1.0, 0.55, 0.22), "emit": true},     # ember mote
	]
	var i := 0
	for x in [-2.0, 0.0, 2.0]:
		var p := CPUParticles3D.new()
		add_child(p)
		p.position = Vector3(x, 5.5, 0.2)
		p.amount = 34
		p.lifetime = 4.0
		p.preprocess = 0.6
		p.direction = Vector3.DOWN
		p.spread = 22.0
		p.initial_velocity_min = 0.3
		p.initial_velocity_max = 1.0
		p.gravity = Vector3(0.1, -1.3, 0)
		p.angular_velocity_min = -220.0
		p.angular_velocity_max = 220.0
		var pal: Dictionary = palettes[i % palettes.size()]
		var is_ember: bool = bool(pal["emit"])
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.035, 0.035) if is_ember else Vector3(0.085, 0.015, 0.05)
		var m := StandardMaterial3D.new()
		m.albedo_color = pal["albedo"]
		m.roughness = 0.85
		if is_ember:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_enabled = true
			m.emission = pal["albedo"]
			m.emission_energy_multiplier = 2.0
		mesh.material = m
		p.mesh = mesh
		p.emitting = true
		i += 1
