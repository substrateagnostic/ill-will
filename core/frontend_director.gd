class_name FrontEndDirector
extends Node
## THE FRONT-END DIRECTOR — the always-on brain for the title screen and attract
## mode (doc 25 B4 lane). It lives as a child of the PartySetup autoload, so it
## survives scene reloads and processes while the tree is paused, and it drives
## the front-end WITHOUT editing estate.gd: it watches the live estate scene's
## public phase, reads its title layer, and calls its exhibition-launch path from
## the outside. All coupling to the estate is read-only or through already-proven
## entry points; nothing here mutates estate.gd's source.
##
## Responsibilities:
##   - TITLE composition (deliverable 3): compose a lit hero shot + pad focus when
##     the title appears; restore the grounds look when it leaves.
##   - ATTRACT (deliverable 2): after IDLE_SECONDS of no input at the title, run a
##     bot-only exhibition under the film wash; ANY input returns to the title.

const IDLE_SECONDS := 45.0

# Curated non-theater exhibition pool (gid must be a key in estate.MODULES; a
# theater game assumes present humans reacting to each other and reads as broken
# empty, so none are listed). Filtered to games whose scene actually ships.
const ATTRACT_GAMES := [
	{"gid": "greed", "name": "GREED INC.", "scene": "res://minigames/greed/greed.tscn"},
	{"gid": "orbital", "name": "ORBITAL DODGEBALL", "scene": "res://minigames/orbital/orbital.tscn"},
	{"gid": "tilt", "name": "TILT", "scene": "res://minigames/tilt/tilt.tscn"},
	{"gid": "deadweight", "name": "DEAD WEIGHT", "scene": "res://minigames/dead_weight/dead_weight.tscn"},
	{"gid": "throne", "name": "THE THRONE", "scene": "res://minigames/throne/throne.tscn"},
	{"gid": "widowsgaze", "name": "THE WIDOW'S GAZE", "scene": "res://minigames/widows_gaze/widows_gaze.tscn"},
	{"gid": "lastwill", "name": "LAST WILL", "scene": "res://minigames/last_will/last_will.tscn"},
	{"gid": "echo", "name": "ECHO CHAMBER", "scene": "res://minigames/echo_chamber/echo_chamber.tscn"},
	{"gid": "swap", "name": "SWAP MEET", "scene": "res://minigames/swap_meet/swap_meet.tscn"},
	{"gid": "mower", "name": "MOWER MAYHEM", "scene": "res://minigames/mower/mower.tscn"},
]

var _estate: Node = null
var _composed := false
var _idle := 0.0
var _threshold := IDLE_SECONDS
var _attract: AttractMode = null
var _seat_bak: Dictionary = {}       # seat -> {bot, dev} snapshot for the rehearsal
var _force_gid := ""
var _disabled := false

# Verify-only: prove "any input returns to the title" by injecting a synthetic
# key through the real input pipeline after the rehearsal has been running.
var _verify_interrupt := false
var _attract_age := 0.0
var _interrupt_fired := false
var _pending_snap := ""

# ----- title composition state (all restored on title exit; deliverable 3) -----
var _title_env: Environment = null   # Environment to put back on $WorldEnvironment
var _title_env_saved := false
var _title_cam: Transform3D = Transform3D.IDENTITY  # to restore on $Camera3D
var _title_cam_saved := false
var _title_sun_energy := -1.0        # $Sun energy to restore (-1 = untouched)
var _title_extra: Array[Node3D] = [] # flicker lights we added, to free on exit
var _flicker_base: Array[float] = [] # per-light base energy (parallels _title_extra)
var _hidden_tags: Array[Node3D] = [] # grounds dev billboards hidden for the title
var _flicker_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg == "--attractnow":
			_threshold = 1.6            # verify: trip attract shortly after the title
		elif arg.begins_with("--attractgid="):
			_force_gid = arg.trim_prefix("--attractgid=")
			_threshold = 1.6
		elif arg == "--noattract":
			_disabled = true
		elif arg == "--attractinterrupt":
			_threshold = 1.6
			_verify_interrupt = true

func _process(delta: float) -> void:
	if _attract != null:
		_attract_age += delta
		if _verify_interrupt and not _interrupt_fired and _attract_age > 1.6:
			_interrupt_fired = true
			var ev := InputEventKey.new()
			ev.keycode = KEY_ENTER
			ev.physical_keycode = KEY_ENTER
			ev.pressed = true
			print("ATTRACT verify: injecting synthetic input to interrupt")
			Input.parse_input_event(ev)
		if _attract.should_end():
			_end_attract()
		return
	var scene := get_tree().current_scene
	var is_title: bool = scene != null and scene.has_method("get_phase_name") \
		and str(scene.call("get_phase_name")) == "TITLE"
	if is_title:
		_estate = scene
		if not _title_ready():
			return
		if not _composed:
			_compose_title()
			_composed = true
			if _pending_snap != "":
				_snap(_pending_snap)
				_pending_snap = ""
		_flicker_lanterns(delta)
		_idle += delta
		if _idle >= _threshold and _attract_ok():
			_start_attract()
	else:
		if _composed:
			_dismiss_title()
			_composed = false
		_idle = 0.0
		_estate = scene if (scene != null and scene.has_method("get_phase_name")) else null

func _input(event: InputEvent) -> void:
	if _attract != null:
		if _is_real_input(event):
			get_viewport().set_input_as_handled()
			_end_attract()
		return
	if _composed and _is_real_input(event):
		_idle = 0.0

## Any deliberate input from any device — the arcade rule: attract dies on the
## first knock at the door, and the idle clock resets whenever a hand is present.
func _is_real_input(e: InputEvent) -> bool:
	if e is InputEventKey:
		return e.pressed and not e.echo
	if e is InputEventJoypadButton:
		return e.pressed
	if e is InputEventJoypadMotion:
		return absf((e as InputEventJoypadMotion).axis_value) > 0.5
	if e is InputEventMouseButton:
		return e.pressed
	if e is InputEventMouseMotion:
		return (e as InputEventMouseMotion).relative.length() > 3.0
	if e is InputEventScreenTouch:
		return e.pressed
	return false

func _title_ready() -> bool:
	if _estate == null or not is_instance_valid(_estate):
		return false
	var tl = _estate.get("_title_layer")
	return tl != null and is_instance_valid(tl) and (tl as CanvasItem).visible

## ---------------------------------------------------------------- attract mode

func _attract_ok() -> bool:
	if _disabled or _attract != null:
		return false
	if NetSession.is_host() or NetSession.is_client():
		return false          # online is a shared surface; attract is couch-only
	if _estate == null or not is_instance_valid(_estate):
		return false
	if str(_estate.get("_netprobe")) != "":
		return false          # netprobe rigs must not have their timing perturbed
	return true

func _pick_module() -> Dictionary:
	if _force_gid != "":
		for g in ATTRACT_GAMES:
			if String(g.gid) == _force_gid:
				return g
	var pool: Array = []
	for g in ATTRACT_GAMES:
		if ResourceLoader.exists(String(g.scene)):
			pool.append(g)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]

func _start_attract() -> void:
	var pick := _pick_module()
	if pick.is_empty():
		_idle = 0.0
		return
	# Snapshot seats so the rehearsal (all bots) restores exactly what it found.
	_seat_bak.clear()
	for i in 4:
		_seat_bak[i] = {"bot": PlayerInput.is_bot(i), "dev": PlayerInput.device_of(i)}
	# Tear down the title composition BEFORE launching so our flicker lights and
	# moonlit env never leak into the exhibition's own render.
	_dismiss_title()
	_composed = false
	_attract = AttractMode.new()
	_attract.name = "AttractMode"
	_attract_age = 0.0
	add_child(_attract)
	print("ATTRACT begin gid=%s" % String(pick.gid))
	_attract.begin(_estate, String(pick.gid), String(pick.name))

func _end_attract() -> void:
	# Restore the couch exactly as it was before the rehearsal.
	for i in _seat_bak:
		PlayerInput.set_bot(int(i), bool(_seat_bak[i].bot))
		PlayerInput.assign(int(i), int(_seat_bak[i].dev))
	_seat_bak.clear()
	if is_instance_valid(_attract):
		_attract.queue_free()
	_attract = null
	_idle = 0.0
	_composed = false
	var ms: Node = get_node_or_null("/root/MomentScribe")
	if ms != null and ms.has_method("clear_game"):
		ms.call("clear_game")   # the rehearsal recorded nothing worth keeping
	var restored := "ATTRACT end -> title | seats restored:"
	for i in 4:
		restored += " %d=%s/%d" % [i, ("bot" if PlayerInput.is_bot(i) else "human"), PlayerInput.device_of(i)]
	print(restored)
	if _verify_interrupt:
		_pending_snap = "attract_interrupt"
	# Tear the exhibition module down + return to a clean title exactly the way
	# the shell already does it: zombie sweep + time_scale reset + scene reload.
	PartySetup.quit_to_title()

## ---------------------------------------------------------------- title (D3)

## Compose the title into a lit hero shot: EnvKit MOONLIT mood + fog on the
## grounds env, a deliberate camera angle onto the manor gate/house, warm
## flickering lantern light, a dressed wordmark, and — the doc 25 gap — pad
## focus grabbed on PLAY. Everything mutated here is snapshotted and restored in
## _dismiss_title so the grounds/lobby/game are untouched once the title leaves.
func _compose_title() -> void:
	var est := _estate
	if est == null or not is_instance_valid(est):
		return
	# --- mood lighting: swap the grounds env for a moonlit one (fog included) ---
	var we := est.get_node_or_null("WorldEnvironment")
	if we != null and we is WorldEnvironment:
		if not _title_env_saved:
			_title_env = (we as WorldEnvironment).environment
			_title_env_saved = true
		(we as WorldEnvironment).environment = EnvKit.build_environment(
			EnvKit._merged(EnvKit.MOONLIT, {"fog_density": 0.024, "ambient_energy": 0.42}))
	# --- dim the grounds sun to a moon key so the mood reads at night ---
	var sun := est.get_node_or_null("Sun")
	if sun != null and sun is DirectionalLight3D:
		if _title_sun_energy < 0.0:
			_title_sun_energy = (sun as DirectionalLight3D).light_energy
		(sun as DirectionalLight3D).light_energy = 0.38
	# --- a deliberate camera angle: pulled back and near-level so the dark night
	# sky carries the wordmark and the moonlit manor + gate sit low behind it ---
	var cam := est.get_node_or_null("Camera3D")
	if cam != null and cam is Camera3D:
		if not _title_cam_saved:
			_title_cam = (cam as Camera3D).transform
			_title_cam_saved = true
		(cam as Camera3D).global_position = Vector3(0.0, 5.1, 9.0)
		(cam as Camera3D).look_at(Vector3(0.0, 2.7, -12.5), Vector3.UP)
	# --- hide the grounds' dev billboards (THE EXECUTOR / THE THEATER etc.) so
	# the title reads as a composed shot, not the working grounds ---
	_hide_ground_tags(est)
	# --- warm flickering lantern light (cheap shadowless omnis, freed on exit) ---
	_spawn_lantern_flicker(est)
	# --- title layer: reveal the composed LIVE scene (a stale flat title_bg.png
	# was covering it), grab pad focus, dress the wordmark, lighten the shade ---
	var tl = est.get("_title_layer")
	if tl != null and is_instance_valid(tl):
		_hide_static_bg(tl)
		_wire_focus(tl)
		_dress_wordmark(tl)
		_soften_shade(tl)

func _dismiss_title() -> void:
	var est := _estate
	if est != null and is_instance_valid(est):
		var we := est.get_node_or_null("WorldEnvironment")
		if we != null and we is WorldEnvironment and _title_env_saved:
			(we as WorldEnvironment).environment = _title_env
		var cam := est.get_node_or_null("Camera3D")
		if cam != null and cam is Camera3D and _title_cam_saved:
			(cam as Camera3D).transform = _title_cam
		var sun := est.get_node_or_null("Sun")
		if sun != null and sun is DirectionalLight3D and _title_sun_energy >= 0.0:
			(sun as DirectionalLight3D).light_energy = _title_sun_energy
	for o in _title_extra:
		if is_instance_valid(o):
			o.queue_free()
	_title_extra.clear()
	_flicker_base.clear()
	for t in _hidden_tags:
		if is_instance_valid(t):
			(t as Node3D).visible = true
	_hidden_tags.clear()
	_title_env = null
	_title_env_saved = false
	_title_cam_saved = false
	_title_sun_energy = -1.0

## Warm, shadowless omni lights that dress the night: one at each of the four
## estate lanterns (positions from estate.tscn) plus a broad backlight lifting
## the manor + gate out of the dark so the house reads as the hero behind the
## menu. Idempotent: cleared and rebuilt so a re-entered title never stacks
## lights. Flickered per frame by _flicker_lanterns while composed.
func _spawn_lantern_flicker(est: Node) -> void:
	for o in _title_extra:
		if is_instance_valid(o):
			o.queue_free()
	_title_extra.clear()
	_flicker_base.clear()
	var spots := [Vector3(2.2, 1.15, 0.5), Vector3(-2.2, 1.15, 0.5),
		Vector3(5.2, 1.15, -4.5), Vector3(-5.2, 1.15, -4.5)]
	for pos: Vector3 in spots:
		_add_title_light(est, pos, Color(1.0, 0.72, 0.42), 1.7, 5.5)
	# The manor backlight: a wider, warmer pool at the gate/house so the moonlit
	# threshold glows behind PLAY instead of vanishing into the night.
	_add_title_light(est, Vector3(0.0, 3.2, -11.6), Color(1.0, 0.82, 0.6), 3.0, 11.0)

func _add_title_light(est: Node, pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var o := OmniLight3D.new()
	o.light_color = col
	o.light_energy = energy
	o.omni_range = rng
	o.shadow_enabled = false
	o.position = pos
	est.add_child(o)
	_title_extra.append(o)
	_flicker_base.append(energy)

## Hide the grounds' working furniture for the title: the floating dev
## billboards (Label3D "THE EXECUTOR" / "THE THEATER"), the monument plinths
## (past-champion blocks + their labels) and the graffiti wall. All restored on
## exit. Turns the working grounds into a composed shot.
func _hide_ground_tags(est: Node) -> void:
	for t in _hidden_tags:
		if is_instance_valid(t):
			(t as Node3D).visible = true
	_hidden_tags.clear()
	var grounds := est.get_node_or_null("Grounds")
	if grounds != null:
		for l in grounds.find_children("*", "Label3D", true, false):
			if (l as Node3D).visible:
				(l as Node3D).visible = false
				_hidden_tags.append(l as Node3D)
	for path in ["Plinths", "GraffitiWall"]:
		var n := est.get_node_or_null(path)
		if n != null and n is Node3D and (n as Node3D).visible:
			(n as Node3D).visible = false
			_hidden_tags.append(n as Node3D)

func _flicker_lanterns(delta: float) -> void:
	_flicker_t += delta
	for idx: int in _title_extra.size():
		var o := _title_extra[idx]
		if not is_instance_valid(o) or not o is OmniLight3D:
			continue
		var base: float = _flicker_base[idx] if idx < _flicker_base.size() else 1.7
		var ph := _flicker_t * (6.0 + float(idx) * 0.8) + float(idx) * 1.7
		var f: float = 0.80 + 0.20 * (0.6 * sin(ph) + 0.4 * sin(ph * 2.3 + 1.0))
		(o as OmniLight3D).light_energy = base * f

## The title has an optional full-rect title_bg.png TextureRect that, when the
## file ships, is drawn OVER the live grounds — a stale flat render with baked
## debug name tags. Hide it so the composed moonlit scene (fog, flicker, the
## wandering cast) becomes the hero shot doc 25 asks for.
func _hide_static_bg(tl: Node) -> void:
	for c in tl.get_children():
		if c is TextureRect:
			(c as TextureRect).visible = false
			return

## The doc 25 focus gap: nothing had initial focus, so a controller-only player
## could not move onto PLAY. Grab focus on PLAY (first button in tree order) and
## give every menu item a visible focus highlight so pad navigation reads.
func _wire_focus(tl: Node) -> void:
	var buttons := tl.find_children("*", "Button", true, false)
	if buttons.is_empty():
		return
	for b in buttons:
		var btn := b as Button
		btn.focus_mode = Control.FOCUS_ALL
		if not btn.focus_entered.is_connected(_on_btn_focus):
			btn.focus_entered.connect(_on_btn_focus.bind(btn))
			btn.focus_exited.connect(_on_btn_unfocus.bind(btn))
	var first := buttons[0] as Control
	first.grab_focus()
	first.call_deferred("grab_focus")   # belt-and-suspenders: focus after layout

func _on_btn_focus(btn: Button) -> void:
	btn.modulate = Color(1.35, 1.3, 0.85)   # a warm brighten so the pad cursor reads

func _on_btn_unfocus(btn: Button) -> void:
	btn.modulate = Color.WHITE

func _dress_wordmark(tl: Node) -> void:
	for l in tl.find_children("*", "Label", true, false):
		if l is Label and (l as Label).text == "ILL WILL":
			var lb := l as Label
			lb.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
			lb.add_theme_constant_override("shadow_offset_x", 5)
			lb.add_theme_constant_override("shadow_offset_y", 8)
			lb.add_theme_constant_override("shadow_outline_size", 10)
			return

func _soften_shade(tl: Node) -> void:
	# The flat dim ColorRect can lift now that EnvKit provides the mood; keep a
	# light backing so the menu text still reads over the moonlit grounds.
	for c in tl.get_children():
		if c is ColorRect:
			(c as ColorRect).color = Color(0.04, 0.03, 0.07, 0.28)
			return

## ---------------------------------------------------------------- verify

func _snap(tag: String) -> void:
	var vc: Node = get_node_or_null("/root/VerifyCapture")
	if vc != null and bool(vc.get("active")) and vc.has_method("snap"):
		vc.call("snap", tag)
