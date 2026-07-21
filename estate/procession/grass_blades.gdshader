shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// ILL WILL — LIVING LAWN prototype (TASTE lane, replacing the Meshy clump
// scatter in grounds.gd._dress_meadows). ONE MultiMesh of fanned blade-tufts;
// this spatial shader does all the life: layered wind sway, per-blade phase,
// root->tip colour gradient, up to 8 world-space TRAMPLE benders (bend away +
// press down, spring back when the bender leaves), and a distance density
// fade so far grass sinks into the ground instead of shimmering.
//
// PURE vertex-shaped blades — no alpha texture (blades taper to a point in
// geometry), so no scissor cost, no shard artifact at glancing angles.
// Uniform-scale instances only (the world<->local offset math assumes it).

// ---- WIND (subtle — a moonlit night estate, not a wheat field) -------------
uniform vec2 wind_dir = vec2(0.80, 0.55);
uniform float wind_strength = 0.11;
uniform float wind_speed = 1.05;
uniform float gust_scale = 0.035;   // spatial frequency of the slow gust swell

// ---- TRAMPLE benders (fed each frame from GDScript) ------------------------
uniform int bender_count = 0;
uniform vec4 benders[8];            // xyz = world pos, w = radius
uniform float bend_strength = 1.0;

// ---- COLOUR (moonlit cool green with life — never grimdark grey) -----------
uniform vec3 root_color : source_color = vec3(0.058, 0.088, 0.046);
uniform vec3 tip_color  : source_color = vec3(0.215, 0.420, 0.155);
uniform vec3 dry_tip    : source_color = vec3(0.300, 0.360, 0.130); // strawy pops
uniform vec3 moon_tint  : source_color = vec3(0.55, 0.72, 1.00);
uniform float moon_gain = 0.10;
uniform float ao_root = 0.60;
uniform float tuft_drift = 0.16;    // per-clump tint variance (kills tiling)

// ---- DISTANCE density fade -------------------------------------------------
uniform float fade_start = 26.0;
uniform float fade_end = 42.0;

varying float v_hf;        // height fraction root(0)->tip(1)
varying float v_hue;       // per-blade hue jitter 0..1
varying float v_bend;      // trample amount 0..1 at this vertex
varying vec3  v_wroot;     // instance root world pos (per-tuft constant)

float hash12(vec2 p){
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	float hf = UV.y;                 // 0 at root, 1 at tip
	v_hf = hf;
	float blade_rand = COLOR.r;      // per-blade random (phase) baked in mesh
	v_hue = COLOR.g;                 // per-blade hue jitter baked in mesh
	v_wroot = MODEL_MATRIX[3].xyz;   // per-instance constant (tuft origin)

	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// bend authority grows toward the tip (root stays planted)
	float hbend = hf * hf * 0.85 + hf * 0.15;

	// ---- WIND: two sines + a slow spatial gust envelope, world-space offset
	float t = TIME * wind_speed;
	float phase = dot(wpos.xz, vec2(0.35, 0.27)) + blade_rand * 6.2831;
	float gust = 0.6 + 0.4 * sin(dot(wpos.xz, vec2(gust_scale, gust_scale * 0.8)) - t * 0.5);
	float sway = (sin(phase + t) + 0.5 * sin(phase * 2.3 + t * 1.7)) * wind_strength * gust;
	vec2 wd = normalize(wind_dir);
	vec3 woff = vec3(wd.x, 0.0, wd.y) * sway * hbend;
	woff.y -= abs(sway) * 0.15 * hbend;   // slight bob so tips aren't rigid arcs

	// ---- TRAMPLE: push away from each bender + press the blade down
	float trample = 0.0;
	for (int i = 0; i < bender_count; i++) {
		vec3 b = benders[i].xyz;
		float r = max(benders[i].w, 0.001);
		vec2 d = wpos.xz - b.xz;
		float dist = length(d);
		if (dist < r) {
			float f = 1.0 - dist / r;
			f = f * f * (3.0 - 2.0 * f);          // smootherstep falloff
			vec2 away = dist > 0.001 ? d / dist : vec2(0.0, 1.0);
			float push = f * bend_strength * hbend;
			woff.xz += away * push * 0.60;         // splay outward
			woff.y  -= push * 0.95;                // flatten down
			trample = max(trample, f);
		}
	}
	v_bend = trample;

	// world offset -> local (uniform scale + rotation only)
	mat3 mb = mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz);
	float s2 = dot(mb[0], mb[0]);
	VERTEX += (transpose(mb) * woff) / max(s2, 0.0001);

	// ---- distance density fade: collapse far blades toward their root
	float cam_d = length(wpos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - clamp((cam_d - fade_start) / max(fade_end - fade_start, 0.001), 0.0, 1.0);
	VERTEX.y *= fade;

	// grass-mass normal: bias hard toward up so blades read as a soft mass,
	// not a field of individually-flickering shards under the moon key
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.55));
}

void fragment() {
	float hf = v_hf;
	vec3 col = mix(root_color, tip_color, smoothstep(0.0, 1.0, hf));
	// some blades run strawy/warm toward the tip (life, not uniform astroturf)
	col = mix(col, dry_tip, v_hue * hf * 0.45);
	// per-tuft tint drift so no two clumps match (fights tiling)
	float td = hash12(floor(v_wroot.xz * 1.7)) - 0.5;
	col *= 1.0 + td * tuft_drift;
	// cool moon light gathering toward the tips
	col += moon_tint * (hf * hf) * moon_gain;
	// trampled blades bruise a touch darker/olive
	col = mix(col, col * vec3(0.80, 0.85, 0.70), v_bend * 0.5);
	// root ambient occlusion (blades darker where they meet the soil)
	col *= mix(ao_root, 1.0, smoothstep(0.0, 0.35, hf));

	ALBEDO = col;
	ROUGHNESS = 0.86;
	SPECULAR = 0.18;
	// faint tip translucency so the moon backlight reads through the blade
	EMISSION = tip_color * (hf * hf) * 0.06;
}
