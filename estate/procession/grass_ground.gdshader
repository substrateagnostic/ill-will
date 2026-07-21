shader_type spatial;
render_mode diffuse_burley;
// ILL WILL — LIVING LAWN ground patch (stretch). A splat-style albedo blend
// under the grass so the "consistent fill" reads: grass-soil where the drift
// is thick, bare dirt where it thins, mud pooling in the wet places. Pure
// procedural value-noise (no textures) so it costs nothing to ship and never
// tiles. The mesh carries a moonlit per-vertex base tint (like grounds.gd's
// terrain); this shader mixes dirt/mud detail over it.

uniform vec3 grass_soil : source_color = vec3(0.092, 0.122, 0.068);
uniform vec3 dirt_color : source_color = vec3(0.128, 0.102, 0.074);
uniform vec3 mud_color  : source_color = vec3(0.074, 0.064, 0.050);
uniform float wetness = 0.0;        // 0 meadow .. 1 bog edge
uniform float noise_scale = 0.16;

varying vec3 v_wpos;

float hash(vec2 p){ p = fract(p * vec2(123.34, 345.45)); p += dot(p, p + 34.345); return fract(p.x * p.y); }
float vnoise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p){
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++){ s += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return s;
}

void vertex(){ v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment(){
	vec2 wp = v_wpos.xz;
	float n  = fbm(wp * noise_scale);
	float n2 = fbm(wp * noise_scale * 4.1 + 11.0);

	vec3 base = COLOR.rgb;                                  // in-world moonlit tint
	vec3 col = mix(dirt_color, grass_soil, smoothstep(0.34, 0.66, n));
	col = mix(col, base, 0.45);                             // keep the biome tint

	float mud = clamp(wetness * (0.45 + smoothstep(0.62, 0.20, n)), 0.0, 1.0);
	col = mix(col, mud_color, mud);

	col *= 0.88 + 0.24 * n2;                                // fine grain, no flat read

	ALBEDO = col;
	ROUGHNESS = mix(1.0, 0.5, wetness * smoothstep(0.55, 0.18, n));  // wet = shinier
	SPECULAR = mix(0.18, 0.55, wetness);
	METALLIC = 0.0;
}
