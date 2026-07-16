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

# ----- title composition state (restored on title exit; see deliverable 3) -----
var _title_env_restore = null        # Environment to put back on $WorldEnvironment
var _title_cam_xform = null          # Transform3D to restore on $Camera3D
var _title_sun_energy := -1.0        # $Sun energy to restore (-1 = untouched)
var _title_extra: Array = []         # nodes we added (flicker lights etc.) to free

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
	_attract = AttractMode.new()
	_attract.name = "AttractMode"
	_attract_age = 0.0
	add_child(_attract)
	print("ATTRACT begin gid=%s" % String(pick.gid))
	_attract.begin(_estate, String(pick.gid), String(pick.name))
	_composed = false

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

func _compose_title() -> void:
	pass

func _dismiss_title() -> void:
	pass

## ---------------------------------------------------------------- verify

func _snap(tag: String) -> void:
	var vc: Node = get_node_or_null("/root/VerifyCapture")
	if vc != null and bool(vc.get("active")) and vc.has_method("snap"):
		vc.call("snap", tag)
