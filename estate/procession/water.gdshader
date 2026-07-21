shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// ILL WILL — THE WEEPING VALLEY's standing water (BIOME FILL wave 2, TASTE lane).
// ONE plane, one material (grounds._build_water emits a single contour-shaped
// mesh; this shader does ALL the water read). A STILL NIGHT BOG, never an ocean:
//   • gentle animated ripple normals — layered scrolling value-noise, subtle
//   • fresnel edge glint under the moon key (broken by the ripple, never a sheet)
//   • depth-tinted murk — shallow edges wetter/lighter, deep centres go dark
//     (vertex COLOR.r carries the baked, normalised terrain depth 0..1)
//   • soft shore blend where water meets mud (screen-depth thickness → alpha +
//     a thin wet lightening at the exact waterline; the bank is never a hard cut)
//   • a faint self-glow (a bog at night is its own lamp) — TUNED DOWN from the
//     old flat-material murk-glow 0.85 (doc-33 legibility recheck: this settles it)
// Transparent (ALPHA output; transparents don't write depth, so DEPTH_TEXTURE
// holds the opaque scene behind) — the submerged rib-crowns, posts and shore mud
// read THROUGH the murk, which is what sells it as water and not a painted floor.
// No textures, no UVs: world-xz procedural, so it never tiles and costs nothing
// to ship (GROUNDS BAR: richness from composition, not per-pixel extravagance).

// ---- murk palette (moonlit cool, olive at the shallows, never grimdark grey) --
uniform vec3 shallow_color : source_color = vec3(0.058, 0.094, 0.082);
uniform vec3 deep_color    : source_color = vec3(0.012, 0.026, 0.033);
uniform vec3 moon_tint     : source_color = vec3(0.55, 0.70, 1.00);
uniform vec3 glow_color    : source_color = vec3(0.050, 0.120, 0.130);
uniform float glow_energy = 0.34;     // the bog's own faint lamp (was a flat 0.85)
uniform float depth_scale = 1.0;      // extra bias on the baked 0..1 depth ramp

// ---- ripple (gentle but VISIBLE — a still bog with a breath of wind, no surf) -
uniform float ripple_scale = 0.62;    // spatial frequency of the fine chop
uniform float ripple_speed = 0.34;    // scroll speed of the noise layers
uniform float ripple_amp = 0.55;      // normal-perturbation strength (first pass
                                      // 0.10 read as flat glass — this is the fix)
uniform float swell_scale = 0.10;     // the slow broad undulation under the chop
uniform float swell_amp = 0.34;

// ---- shore blend -------------------------------------------------------------
uniform float shore_fade = 0.85;      // metres of water-column over which the
                                      // edge softens (screen-depth thickness)
uniform float edge_light = 0.55;      // how much the exact waterline wets/lightens
uniform float deep_alpha = 0.94;      // opacity over the deep
uniform float shallow_alpha = 0.40;   // opacity at the shallow rim

// Godot 4.6 removed the DEPTH_TEXTURE builtin — the opaque scene depth now
// arrives through an explicit hinted uniform (used for the soft shore blend).
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 v_wpos;
varying float v_depth;                // baked normalised terrain depth 0..1

// -- hash / value-noise (matches the grounds' own hand-rolled noise family) ----
float whash(vec2 p){ p = fract(p * vec2(123.34, 345.45)); p += dot(p, p + 34.345); return fract(p.x * p.y); }
float wnoise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = whash(i), b = whash(i + vec2(1.0, 0.0));
	float c = whash(i + vec2(0.0, 1.0)), d = whash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex(){
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_depth = clamp(COLOR.r * depth_scale, 0.0, 1.0);
}

void fragment(){
	vec2 wp = v_wpos.xz;
	float t = TIME * ripple_speed;

	// Ripple height field: two scrolling noise layers (crossing directions so
	// the chop never reads as one marching wavefront) + a slow broad swell.
	// The normal comes from finite-difference slopes of this field — cheap, and
	// it warps the moon glint into a living, broken glitter instead of plastic.
	vec2 d1 = vec2(0.80, 0.62);
	vec2 d2 = vec2(-0.55, 0.84);
	float e = 0.35;                       // slope sample epsilon (world units)
	// layer A
	float aC = wnoise(wp * ripple_scale + d1 * t);
	float aX = wnoise((wp + vec2(e, 0.0)) * ripple_scale + d1 * t);
	float aZ = wnoise((wp + vec2(0.0, e)) * ripple_scale + d1 * t);
	// layer B (faster, finer, opposite drift)
	float bC = wnoise(wp * ripple_scale * 1.9 - d2 * t * 1.5);
	float bX = wnoise((wp + vec2(e, 0.0)) * ripple_scale * 1.9 - d2 * t * 1.5);
	float bZ = wnoise((wp + vec2(0.0, e)) * ripple_scale * 1.9 - d2 * t * 1.5);
	// slow swell
	float sC = wnoise(wp * swell_scale + vec2(0.13, -0.09) * t);
	float sX = wnoise((wp + vec2(e, 0.0)) * swell_scale + vec2(0.13, -0.09) * t);
	float sZ = wnoise((wp + vec2(0.0, e)) * swell_scale + vec2(0.13, -0.09) * t);

	vec2 slope = vec2(
		((aX - aC) + 0.85 * (bX - bC)) * ripple_amp + (sX - sC) * swell_amp,
		((aZ - aC) + 0.85 * (bZ - bC)) * ripple_amp + (sZ - sC) * swell_amp) / e;
	vec3 wnormal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wnormal, 0.0)).xyz);

	// Depth-tinted murk: shallow rim wetter/olive, deep centres swallow the light.
	float murk = smoothstep(0.0, 0.80, v_depth);
	vec3 col = mix(shallow_color, deep_color, murk);
	// a slow-drifting per-place murk so the pond is never one flat colour — this
	// moving tonal variation (not just the specular) is a big part of the water read
	col *= 0.80 + 0.36 * wnoise(wp * 0.09 + vec2(0.05, -0.04) * t);

	// Fresnel edge glint — broken by the ripple normal, tinted by the moon key.
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);   // world-space fragment->camera
	float fres = pow(clamp(1.0 - dot(wnormal, V), 0.0, 1.0), 3.5);
	col += moon_tint * fres * 0.26;

	// Soft shore blend from screen-space depth: how thick the water column is
	// between this surface and the opaque mud/props behind it. Thin at the bank.
	float scene_raw = texture(depth_tex, SCREEN_UV).x;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_raw, 1.0);
	float scene_dist = -(upos.z / upos.w);
	float water_dist = -VERTEX.z;                       // view-space depth of the surface
	float column = clamp((scene_dist - water_dist) / shore_fade, 0.0, 1.0);
	// the exact waterline wets & lightens (a thin bright hem, not white foam)
	float hem = (1.0 - column) * edge_light;
	col = mix(col, shallow_color * 1.7 + moon_tint * 0.05, hem);

	ALBEDO = col;
	// wetter/glossier over the deep, rougher/scummier at the murky shallows
	ROUGHNESS = mix(0.55, 0.14, murk) * (1.0 - 0.4 * fres);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	// the bog's own faint lamp, strongest over the deep (tuned down from 0.85)
	EMISSION = glow_color * glow_energy * (0.35 + 0.65 * murk);
	// opacity: near-solid over the deep, sheer at the rim, sheerest at the hem
	float a = mix(shallow_alpha, deep_alpha, murk);
	ALPHA = clamp(a * (0.35 + 0.65 * column), 0.30, 1.0);
}
