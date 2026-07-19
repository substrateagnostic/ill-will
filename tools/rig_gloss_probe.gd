extends Node3D
## ZA finish audit — fix-verification probe. Instances rigged Meshy GLBs
## through the SAME integrator the game uses (MeshyProp.instance_rigged),
## unlike tools/asset_probe.gd's raw load() (which leaves skinned models at
## their ~1/100 bind-pose scale and never applies the de-gloss material fix
## in scripts/meshy_prop.gd). Side-by-side: static sibling on the left,
## rigged/animated version on the right, so the specular-sheen fix is visible
## in the same shot as the untouched matte statics.
## Run: godot --path . tools/rig_gloss_probe.tscn -- --shots=60 --outdir=verify_out/x

const GEN := "res://assets/models/meshy/generated/"
const PED_TOP := 0.5
const SPACING := 2.2

# (static_glb, rigged_glb, native_height, target_height)
const PAIRS := [
	["npc_reaper.glb", "npc_reaper_walk.glb", 3.5, 1.9],
	["npc_reaper.glb", "npc_reaper_sweep.glb", 3.5, 1.9],
	["npc_widow.glb", "npc_widow_idle.glb", 1.6, 1.5],
	["npc_ferryman.glb", "npc_ferryman_idle.glb", 1.85, 1.7],
	["npc_gravedigger.glb", "npc_gravedigger_idle.glb", 1.7, 1.7],
]

func _ready() -> void:
	_build_env()
	var cam := Camera3D.new()
	add_child(cam)
	var x := 0.0
	for pair in PAIRS:
		var static_name: String = pair[0]
		var rigged_name: String = pair[1]
		var native_h: float = pair[2]
		var target_h: float = pair[3]
		_pedestal(x)
		var s := MeshyProp.instance(GEN + static_name, target_h)
		add_child(s)
		s.global_position = Vector3(x, PED_TOP, 0)
		_name_tag(x, static_name.replace(".glb", "") + "\n(STATIC)", Color(0.6, 0.9, 1.0))
		x += SPACING
		_pedestal(x)
		var r := MeshyProp.instance_rigged(GEN + rigged_name, native_h, target_h)
		add_child(r)
		r.global_position = Vector3(x, PED_TOP, 0)
		_name_tag(x, rigged_name.replace(".glb", "") + "\n(RIGGED, fixed)", Color(1.0, 0.85, 0.5))
		x += SPACING * 1.6

	var row_end := x - SPACING
	var center_x := row_end / 2.0
	cam.global_position = Vector3(center_x, 1.9, maxf(row_end, 4.0) * 0.5 + 3.2)
	cam.look_at(Vector3(center_x, 1.0, 0), Vector3.UP)
	cam.fov = 55.0
	cam.current = true
	_cam = cam
	_row_end = row_end

var _cam: Camera3D
var _row_end := 0.0
var _frame := 0

func _process(_dt: float) -> void:
	if _cam == null:
		return
	_frame += 1
	if _frame == 20:
		_cam.global_position = Vector3(1.1, 1.55, 4.2)
		_cam.look_at(Vector3(1.1, 1.05, 0), Vector3.UP)
		_cam.fov = 40.0
	elif _frame == 50:
		_cam.global_position = Vector3(7.8, 1.55, 4.2)
		_cam.look_at(Vector3(7.8, 1.05, 0), Vector3.UP)
		_cam.fov = 40.0

func _pedestal(x: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, PED_TOP, 0.9)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.26, 0.33)
	mi.material_override = mat
	mi.position = Vector3(x, PED_TOP / 2.0, 0)
	add_child(mi)

func _name_tag(x: float, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(x, 2.1, 0)
	add_child(l)

func _build_env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.15, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.52, 0.5, 0.62)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
	pm.size = Vector2(30, 20)
	floor_mi.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.22, 0.2, 0.26)
	floor_mi.material_override = fmat
	add_child(floor_mi)
