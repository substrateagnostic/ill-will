class_name EnvKit
extends RefCounted
## THE HOUSE LOOK, AS CODE. One place that owns ILL WILL's cinematic lighting so
## every game reads as the same anthology instead of twelve ad-hoc WorldEnvironments.
##
## Three presets, each a factory that builds a configured Environment + a light
## rig and hangs them off a game root:
##   MOONLIT   — exteriors / night arenas: deep-blue ambient, cool moon key, warm
##               fill, ground fog. Bloom only on emissives.
##   CANDLELIT — interiors (attic, great-hall): warm amber key, deep shadow
##               falloff, stronger AO, optional dust motes.
##   STAGELIT  — theater / performance arenas: hard overhead key spot, near-black
##               surround, cool rim. Emissives (ghost trails, gold rings) sing.
##
## USAGE
##   EnvKit.apply(self, EnvKit.CANDLELIT, {"key_energy": 0.8})
##   -> inserts/updates a WorldEnvironment + rig lights, all tagged EnvKit.GROUP,
##      and returns { world_env, environment, key, fill, rim, lights } so a game
##      can keep refs (e.g. dead_weight dims `environment`/`key` on THE HOUSE AWAKENS).
##
## Every parameter is overridable via the `overrides` dictionary (merged over the
## preset defaults). Re-applying is idempotent: the previous rig is freed and
## rebuilt, so a game may re-apply on a state change without stacking lights.
##
## HOUSE TONEMAP = AGX (Godot 4.6 TONE_MAPPER_AGX). Chosen over Filmic for its
## gentler highlight shoulder: candle flames, ghost rims and gold boundary rings
## roll off to *colored* glow instead of clipping to white, so the high-threshold
## glow reads as bloom-on-emissives, never a white UV smear. AGX also keeps deep
## shadows neutral, which suits all three moods.
##
## PERFORMANCE CONTRACT (must hold 60fps, 4 pawns + fx, mid PC):
##   - exactly ONE shadowed key light per rig; every fill/rim is shadowless
##   - cheap wins only: AGX tonemap, screen/additive glow, classic depth fog, SSAO
##   - NO SDFGI, NO volumetric fog, NO screen-space reflections
## Godot 4.6 ships no built-in vignette (Environment/CameraAttributes have none);
## a full-screen vignette shader is deliberately skipped — it would both cost a
## pass and darken the arena-edge ring-out zones that MUST stay readable.

const GROUP := "envkit_rig"

# Preset ids (unnamed enum so callers write EnvKit.MOONLIT / .CANDLELIT / .STAGELIT)
enum { MOONLIT, CANDLELIT, STAGELIT }


## Build/refresh the house look on `root`. Returns a dict of the nodes created so
## callers can animate them later. Idempotent (see GROUP).
static func apply(root: Node3D, preset: int, overrides: Dictionary = {}) -> Dictionary:
	var p := _merged(preset, overrides)

	# --- idempotency: reuse an existing WorldEnvironment, free prior rig lights ---
	var world_env: WorldEnvironment = _find_world_env(root)
	for n in root.find_children("*", "", true, false):
		if n.is_in_group(GROUP) and n != world_env:
			n.free()
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "EnvKitWorld"
		root.add_child(world_env)
	world_env.add_to_group(GROUP)

	world_env.environment = build_environment(p)

	var lights: Array[Node3D] = []
	var key := _build_key(p)
	root.add_child(key)
	key.add_to_group(GROUP)
	lights.append(key)

	var fill: DirectionalLight3D = null
	if float(p["fill_energy"]) > 0.0:
		fill = _build_dir(p["fill_color"], p["fill_energy"], p["fill_angle"], false, "EnvKitFill")
		root.add_child(fill)
		fill.add_to_group(GROUP)
		lights.append(fill)

	var rim: DirectionalLight3D = null
	if float(p["rim_energy"]) > 0.0:
		rim = _build_dir(p["rim_color"], p["rim_energy"], p["rim_angle"], false, "EnvKitRim")
		root.add_child(rim)
		rim.add_to_group(GROUP)
		lights.append(rim)

	return {
		"world_env": world_env,
		"environment": world_env.environment,
		"key": key,
		"fill": fill,
		"rim": rim,
		"lights": lights,
		"params": p,
	}


## The Environment factory, split out so a game can grab a configured Environment
## without a light rig if it wants to manage its own lights.
static func build_environment(p: Dictionary) -> Environment:
	var e := Environment.new()

	# background
	if String(p["bg_mode"]) == "sky":
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = p["sky_top"]
		sm.sky_horizon_color = p["sky_horizon"]
		sm.ground_horizon_color = p["ground_horizon"]
		sm.ground_bottom_color = p["ground_bottom"]
		sm.sun_angle_max = 30.0
		sky.sky_material = sm
		e.background_mode = Environment.BG_SKY
		e.sky = sky
		e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = p["bg_color"]
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = p["ambient_color"]
	e.ambient_light_energy = float(p["ambient_energy"])

	# tonemap (AGX house standard)
	e.tonemap_mode = int(p["tonemap"])
	e.tonemap_exposure = float(p["exposure"])
	e.tonemap_white = float(p["white"])

	# glow — bloom only on emissives (high hdr threshold)
	e.glow_enabled = bool(p["glow"])
	if e.glow_enabled:
		e.glow_intensity = float(p["glow_intensity"])
		e.glow_bloom = float(p["glow_bloom"])
		e.glow_strength = float(p["glow_strength"])
		e.glow_hdr_threshold = float(p["glow_threshold"])
		e.glow_blend_mode = int(p["glow_blend"])

	# fog — classic depth fog only (NO volumetrics)
	e.fog_enabled = bool(p["fog"])
	if e.fog_enabled:
		e.fog_light_color = p["fog_color"]
		e.fog_density = float(p["fog_density"])
		e.fog_sky_affect = float(p["fog_sky_affect"])
		e.fog_aerial_perspective = float(p["fog_aerial"])

	# SSAO — cheap contact-shadow grounding
	e.ssao_enabled = bool(p["ssao"])
	if e.ssao_enabled:
		e.ssao_radius = float(p["ssao_radius"])
		e.ssao_intensity = float(p["ssao_intensity"])
		e.ssao_power = float(p["ssao_power"])

	return e


## Warm, slow-falling dust motes for candlelit interiors. Additive, unshaded,
## cheap (few particles). Caller places it where it wants and owns its lifetime.
##   region: box the motes drift through (world units); pos: where its top-center sits.
static func add_dust_motes(root: Node3D, region: Vector3 = Vector3(11, 6, 11), \
		pos: Vector3 = Vector3(0, 5, 0), amount: int = 46, \
		color: Color = Color(1.0, 0.86, 0.62)) -> CPUParticles3D:
	var d := CPUParticles3D.new()
	d.name = "EnvKitDust"
	d.amount = amount
	d.lifetime = 9.0
	d.preprocess = 6.0
	d.local_coords = false
	d.position = pos
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = region * 0.5
	d.direction = Vector3(0, -1, 0)
	d.spread = 12.0
	d.gravity = Vector3(0.03, -0.06, 0.0)   # a barely-there sink + drift
	d.initial_velocity_min = 0.02
	d.initial_velocity_max = 0.10
	d.scale_amount_min = 0.012
	d.scale_amount_max = 0.03
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	d.material_override = mat
	# fade the motes in and out over their life so none pop (CPUParticles3D
	# takes a Gradient directly, unlike the GPU particle process material)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(0.5, Color(color.r, color.g, color.b, 0.5))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	d.color_ramp = ramp
	root.add_child(d)
	d.add_to_group(GROUP)
	return d


# ---------------------------------------------------------------- internals

static func _find_world_env(root: Node) -> WorldEnvironment:
	for n in root.find_children("*", "WorldEnvironment", true, false):
		return n
	return null


static func _build_key(p: Dictionary) -> Node3D:
	if String(p["key_type"]) == "spot":
		var s := SpotLight3D.new()
		s.name = "EnvKitKey"
		s.light_color = p["key_color"]
		s.light_energy = float(p["key_energy"])
		s.spot_range = float(p["key_spot_range"])
		s.spot_angle = float(p["key_spot_angle"])
		s.spot_attenuation = float(p["key_spot_attenuation"])
		s.spot_angle_attenuation = float(p["key_spot_angle_attenuation"])
		s.shadow_enabled = bool(p["key_shadow"])
		s.position = p["key_pos"]
		s.look_at(p["key_target"], Vector3.UP)
		return s
	return _build_dir(p["key_color"], p["key_energy"], p["key_angle"], bool(p["key_shadow"]), "EnvKitKey")


static func _build_dir(color: Color, energy: float, angle_deg: Vector3, shadow: bool, nm: String) -> DirectionalLight3D:
	var d := DirectionalLight3D.new()
	d.name = nm
	d.light_color = color
	d.light_energy = energy
	d.rotation_degrees = angle_deg
	d.shadow_enabled = shadow
	return d


## Preset defaults merged with caller overrides. Every key here is overridable.
static func _merged(preset: int, overrides: Dictionary) -> Dictionary:
	var d := _defaults(preset)
	for k in overrides:
		d[k] = overrides[k]
	return d


static func _defaults(preset: int) -> Dictionary:
	match preset:
		MOONLIT:
			return {
				"name": "MOONLIT",
				"bg_mode": "color",
				"bg_color": Color(0.017, 0.030, 0.055),
				"sky_top": Color(0.04, 0.06, 0.12),
				"sky_horizon": Color(0.10, 0.13, 0.22),
				"ground_horizon": Color(0.06, 0.07, 0.10),
				"ground_bottom": Color(0.02, 0.03, 0.05),
				"ambient_color": Color(0.34, 0.42, 0.62),
				"ambient_energy": 0.42,
				"tonemap": Environment.TONE_MAPPER_AGX,
				"exposure": 1.05,
				"white": 1.0,
				"glow": true,
				"glow_intensity": 0.70,
				"glow_bloom": 0.05,
				"glow_strength": 1.0,
				"glow_threshold": 1.0,
				"glow_blend": Environment.GLOW_BLEND_MODE_SCREEN,
				"fog": true,
				"fog_color": Color(0.10, 0.16, 0.28),
				"fog_density": 0.012,
				"fog_sky_affect": 0.35,
				"fog_aerial": 0.0,
				"ssao": true,
				"ssao_radius": 0.9,
				"ssao_intensity": 1.4,
				"ssao_power": 1.5,
				"key_type": "dir",
				"key_color": Color(0.62, 0.72, 1.0),
				"key_energy": 1.0,
				"key_angle": Vector3(-58, 40, 0),
				"key_shadow": true,
				"fill_color": Color(1.0, 0.83, 0.62),
				"fill_energy": 0.22,
				"fill_angle": Vector3(-24, -135, 0),
				"rim_color": Color(0.55, 0.68, 1.0),
				"rim_energy": 0.0,
				"rim_angle": Vector3(-12, 175, 0),
				# spot params (unused by dir key, present so overrides can switch type)
				"key_pos": Vector3(0, 20, 6),
				"key_target": Vector3(0, 0, 0),
				"key_spot_range": 40.0,
				"key_spot_angle": 45.0,
				"key_spot_attenuation": 0.6,
				"key_spot_angle_attenuation": 0.4,
			}
		STAGELIT:
			return {
				"name": "STAGELIT",
				"bg_mode": "color",
				"bg_color": Color(0.012, 0.012, 0.018),
				"sky_top": Color(0.02, 0.02, 0.03),
				"sky_horizon": Color(0.03, 0.03, 0.05),
				"ground_horizon": Color(0.02, 0.02, 0.03),
				"ground_bottom": Color(0.01, 0.01, 0.015),
				"ambient_color": Color(0.40, 0.45, 0.58),
				"ambient_energy": 0.32,
				"tonemap": Environment.TONE_MAPPER_AGX,
				"exposure": 1.0,
				"white": 1.0,
				"glow": true,
				"glow_intensity": 0.90,
				"glow_bloom": 0.05,
				"glow_strength": 1.05,
				"glow_threshold": 1.0,
				"glow_blend": Environment.GLOW_BLEND_MODE_ADDITIVE,
				"fog": false,
				"fog_color": Color(0.05, 0.05, 0.07),
				"fog_density": 0.006,
				"fog_sky_affect": 0.0,
				"fog_aerial": 0.0,
				"ssao": true,
				"ssao_radius": 0.8,
				"ssao_intensity": 1.7,
				"ssao_power": 1.6,
				# Hard directional key = the reliable "stage in the void" look: a
				# bright, crisp, shadow-casting key over a near-black surround. (A
				# real followspot — key_type:"spot" — is available as an override for
				# CLOSE theater rigs where the throw is short; over a top-down arena's
				# ~20-unit camera throw a spot's range-falloff makes it read too dim,
				# so the arena presets use the directional form.)
				"key_type": "dir",
				"key_color": Color(1.0, 0.97, 0.90),
				"key_energy": 1.5,
				"key_angle": Vector3(-62, 18, 0),
				"key_shadow": true,
				"fill_color": Color(1.0, 0.90, 0.80),
				"fill_energy": 0.16,
				"fill_angle": Vector3(-42, 12, 0),
				"rim_color": Color(0.50, 0.63, 0.98),
				"rim_energy": 0.85,
				"rim_angle": Vector3(-14, 182, 0),
				# followspot params (only used when overridden to key_type:"spot")
				"key_pos": Vector3(0.0, 12.0, 3.0),
				"key_target": Vector3(0.0, 0.0, -0.3),
				"key_spot_range": 24.0,
				"key_spot_angle": 40.0,
				"key_spot_attenuation": 0.5,
				"key_spot_angle_attenuation": 0.35,
			}
		_:  # CANDLELIT
			return {
				"name": "CANDLELIT",
				"bg_mode": "color",
				"bg_color": Color(0.045, 0.030, 0.026),
				"sky_top": Color(0.07, 0.05, 0.05),
				"sky_horizon": Color(0.14, 0.10, 0.08),
				"ground_horizon": Color(0.10, 0.07, 0.05),
				"ground_bottom": Color(0.05, 0.035, 0.028),
				"ambient_color": Color(0.52, 0.42, 0.34),
				"ambient_energy": 0.44,
				"tonemap": Environment.TONE_MAPPER_AGX,
				"exposure": 1.05,
				"white": 1.0,
				"glow": true,
				"glow_intensity": 0.65,
				"glow_bloom": 0.07,
				"glow_strength": 1.0,
				"glow_threshold": 0.95,
				"glow_blend": Environment.GLOW_BLEND_MODE_SCREEN,
				"fog": true,
				"fog_color": Color(0.13, 0.08, 0.055),
				"fog_density": 0.010,
				"fog_sky_affect": 0.0,
				"fog_aerial": 0.0,
				"ssao": true,
				"ssao_radius": 0.7,
				"ssao_intensity": 2.1,
				"ssao_power": 1.8,
				"key_type": "dir",
				"key_color": Color(1.0, 0.80, 0.55),
				"key_energy": 1.05,
				"key_angle": Vector3(-55, -34, 0),
				"key_shadow": true,
				"fill_color": Color(0.95, 0.72, 0.52),
				"fill_energy": 0.20,
				"fill_angle": Vector3(-22, 140, 0),
				"rim_color": Color(1.0, 0.80, 0.55),
				"rim_energy": 0.0,
				"rim_angle": Vector3(-12, 175, 0),
				"key_pos": Vector3(0, 20, 6),
				"key_target": Vector3(0, 0, 0),
				"key_spot_range": 40.0,
				"key_spot_angle": 45.0,
				"key_spot_attenuation": 0.6,
				"key_spot_angle_attenuation": 0.4,
			}
