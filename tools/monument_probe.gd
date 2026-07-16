extends Node3D
## Monument probe: fakes 8 champion stones (+1 spillover) in EstateState and
## calls MonumentsView.redraw_monuments under the house lighting, so the
## obelisk-GLB swap (estate/monuments_view.gd) can be judged from screenshots.
## Run BEFORE the GLB import to prove the BoxMesh fallback; after import the
## same run shows the tinted Meshy obelisks.
##
## Run: godot --path . tools/monument_probe.tscn -- --shots=30,60 --outdir=verify_out/monuments
## (VerifyCapture autoload handles the screenshots + quit.)

const OWNERS := [
	["GOLD", Color(0.95, 0.78, 0.2)],
	["RED", Color(0.9, 0.25, 0.22)],
	["BLUE", Color(0.3, 0.5, 0.95)],
	["MINT", Color(0.35, 0.9, 0.65)],
]

func _ready() -> void:
	_build_env()
	var fake: Array = []
	for i in 9:  # 9 -> exercises the "+N older stones" spillover label too
		var who: Array = OWNERS[i % OWNERS.size()]
		fake.append({
			"owner": who[0],
			"color": (who[1] as Color).to_html(),
			"label": "%s — Champion of Night %d" % [who[0], i + 1],
			"night": i,
		})
	EstateState.monuments = fake
	var plinths := Node3D.new()
	plinths.name = "Plinths"
	# probe frames the lawn slot the estate uses (stones spawn around x=-7.7)
	add_child(plinths)
	MonumentsView.redraw_monuments(plinths)
	print("MONUMENT_PROBE stones=%d glb=%s" % [
		fake.size(), str(ResourceLoader.exists(MonumentsView.MONUMENT_GLB))])

	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(-6.6, 2.6, 4.6)
	cam.look_at(Vector3(-6.6, 0.9, -1.0), Vector3.UP)
	cam.fov = 55.0
	cam.current = true

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
	floor_mi.position = Vector3(-6.6, 0, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.1, 0.13, 0.1)
	floor_mi.material_override = fmat
	add_child(floor_mi)
