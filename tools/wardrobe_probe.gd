extends Node3D
## Wardrobe probe: all four KayKit characters in a row under the house lighting,
## cycling through every cosmetic in core/cosmetics.gd so hat fit can be judged
## per head from screenshots.
##
## Run windowed:
##   godot --path . tools/wardrobe_probe.tscn -- --shots=25,70,115,... --outdir=verify_out/wardrobe
## Cosmetics auto-cycle every CYCLE frames (bare heads first, then registry order,
## sorted). Pin a single cosmetic instead with:  -- --cosmetic=viking_helm
## Or one per character:  -- --combo=viking_helm,tophat_monocle,halo,flower_crown
## (VerifyCapture autoload handles --shots / --outdir / quit.)

const Cosmetics := preload("res://core/cosmetics.gd")

const CHAR_PATHS := [
	"res://assets/models/kaykit/Barbarian.glb",
	"res://assets/models/kaykit/Knight.glb",
	"res://assets/models/kaykit/Mage.glb",
	"res://assets/models/kaykit/Rogue.glb",
]
const SPACING := 1.9
const CYCLE := 45  # frames per cosmetic

var chars: Array[Node3D] = []
var ids: Array = []
var pinned := ""
var combo: PackedStringArray = []
var _frame := 0
var _step := -1  # -1 = bare heads

func _ready() -> void:
	_build_env()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cosmetic="):
			pinned = arg.trim_prefix("--cosmetic=")
		elif arg.begins_with("--combo="):
			combo = arg.trim_prefix("--combo=").split(",")

	for i in CHAR_PATHS.size():
		var ps: PackedScene = load(CHAR_PATHS[i])
		var inst: Node3D = ps.instantiate()
		inst.position = Vector3(i * SPACING, 0, 0)
		inst.rotation.y = 0.0
		add_child(inst)
		_strip_handslots(inst)
		var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if anim:
			for a in anim.get_animation_list():
				if a.to_lower().contains("idle"):
					anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
					anim.play(a)
					break
		chars.append(inst)
		var label := Label3D.new()
		label.text = CHAR_PATHS[i].get_file().replace(".glb", "")
		label.font_size = 40
		label.pixel_size = 0.004
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(i * SPACING, 0.35, 0.8)
		add_child(label)

	ids = Cosmetics.ids()
	print("WARDROBE ids=", ids)

	_tag = Label3D.new()
	_tag.font_size = 56
	_tag.pixel_size = 0.005
	_tag.outline_size = 14
	_tag.modulate = Color(1.0, 0.9, 0.5)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var mid := (CHAR_PATHS.size() - 1) * SPACING / 2.0
	_tag.position = Vector3(mid, 2.95, 0)
	add_child(_tag)
	_apply(-1)

	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(mid, 1.95, 5.6)
	cam.look_at(Vector3(mid, 1.55, 0), Vector3.UP)
	cam.fov = 42.0
	cam.current = true

	if pinned != "":
		_apply(ids.find(pinned))
	elif not combo.is_empty():
		var parts := ""
		for i in chars.size():
			if i < combo.size() and combo[i] != "" and combo[i] != "none":
				Cosmetics.equip(chars[i], combo[i])
				parts += combo[i] + " "
		_tag.text = ""
		print("WARDROBE_COMBO ", parts.strip_edges())

var _tag: Label3D

func _process(_dt: float) -> void:
	if pinned != "" or not combo.is_empty():
		return
	_frame += 1
	var step := int(_frame / CYCLE) - 1  # first CYCLE frames: bare heads
	if step != _step and step < ids.size():
		_step = step
		_apply(step)

func _apply(step: int) -> void:
	for c in chars:
		Cosmetics.unequip(c, "head")
		Cosmetics.unequip(c, "hand_l")
		Cosmetics.unequip(c, "hand_r")
	if step < 0 or step >= ids.size():
		_tag.text = "(bare)"
		print("WARDROBE_STEP bare frame=", _frame)
		return
	var id: String = ids[step]
	_tag.text = id
	for c in chars:
		Cosmetics.equip(c, id)
	print("WARDROBE_STEP %s frame=%d" % [id, _frame])

func _strip_handslots(inst: Node) -> void:
	# hide stock weapons/shields so heads read clearly (capes stay)
	for slot_name in ["handslot_l", "handslot_r"]:
		var n := inst.find_child(slot_name, true, false)
		if n:
			for c in n.get_children():
				if c is MeshInstance3D:
					c.visible = false

func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.15, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.52, 0.5, 0.62)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	we.environment = e
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -34, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 140, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.55, 0.68, 1.0)
	add_child(fill)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 20)
	floor_mi.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.22, 0.2, 0.26)
	floor_mi.material_override = fmat
	add_child(floor_mi)
