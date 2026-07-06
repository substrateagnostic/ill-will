shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// MOWER MAYHEM lawn shader. ONE material over ONE plane renders the whole
// coverage grid. coverage_tex is a GWxGH R8 data texture: each texel's red
// byte is a cell OWNER CODE (0 = uncut tall grass, 1..4 = player+1, 200 =
// no-mow soil). The CPU writes cell flips into an Image and pushes it to
// this texture at most once per frame (see mower_lawn.gd). No per-cell nodes.

uniform sampler2D coverage_tex : filter_nearest;
uniform sampler2D stripe_tex : filter_linear, repeat_enable;
uniform vec3 p_colors[4];
uniform vec2 grid_size = vec2(64.0, 48.0);
uniform float stripe_freq = 26.0;      // mow lines across the 12 m depth
uniform float cross_freq = 3.0;        // faint perpendicular banding
uniform float tint_gain = 1.20;        // how hard the owner hue modulates turf
uniform float tint_floor = 0.42;       // green turf kept under the tint
uniform vec3 uncut_color : source_color = vec3(0.10, 0.24, 0.08);
uniform vec3 mowed_base : source_color = vec3(0.40, 0.62, 0.26);
uniform vec3 soil_color : source_color = vec3(0.34, 0.22, 0.13);
uniform float overtime = 0.0;          // 0..1, pulses mowed brightness in OT
// TALLY CEREMONY spotlight: at time-up the root walks owner codes worst->best,
// saturating each player's turf in turn. tally_owner = the code being lit
// (0 = ceremony off), tally_gain = 0..1 ramp of that player's glow.
uniform int tally_owner = 0;
uniform float tally_gain = 0.0;
uniform float tally_active = 0.0;      // 1 while the ceremony recedes other turf

int owner_at(vec2 uv) {
	float r = texture(coverage_tex, uv).r;
	return int(r * 255.0 + 0.5);
}

void fragment() {
	vec2 uv = UV;
	int owner = owner_at(uv);

	// mow-stripe pattern: strong bands along X (the mow direction) plus a
	// faint cross weave so mowed turf reads as real cut grass, not flat paint.
	float band = texture(stripe_tex, vec2(uv.x * cross_freq, uv.y * stripe_freq)).g;
	float weave = 0.85 + 0.30 * band;

	vec3 col;
	float rough = 0.9;
	if (owner == 0) {
		// uncut TALL grass: dark, shaggy, high-frequency so the contrast with
		// a clean mowed stripe is unmistakable.
		float shag = texture(stripe_tex, vec2(uv.x * cross_freq * 6.0, uv.y * stripe_freq * 2.3)).g;
		col = uncut_color * (0.72 + 0.55 * shag);
		rough = 1.0;
	} else if (owner >= 200) {
		// no-mow bed soil
		float grain = texture(stripe_tex, vec2(uv.x * 40.0, uv.y * 40.0)).g;
		col = soil_color * (0.8 + 0.4 * grain);
		rough = 1.0;
	} else {
		vec3 pc = p_colors[owner - 1];
		// alternating mow rows get a light/dark sheen (the classic stripe look)
		float row = step(0.5, fract(uv.y * stripe_freq));
		vec3 grass = mowed_base * weave * mix(0.80, 1.14, row);
		// MODULATE the green turf by the owner hue (not a lerp to a bright
		// color) so each player's stripes stay rich, grass-anchored and clearly
		// distinct instead of washing out to pastel.
		col = grass * (tint_floor + tint_gain * pc);
		col *= 1.0 + overtime * 0.16 * band;   // OT shimmer
		rough = 0.78;
		// tally spotlight: the counted player's turf SATURATES to its pure hue
		// (brightness driven by luma so the bright sun can't wash it to white)
		// while the rest of the lawn recedes, so each reveal pops in sequence.
		if (owner == tally_owner) {
			float l = clamp(dot(col, vec3(0.30, 0.59, 0.11)), 0.18, 1.0);
			vec3 hue = pc / max(max(pc.r, max(pc.g, pc.b)), 0.001);  // full-value hue
			col = mix(col, hue * l * 1.6, tally_gain);
			EMISSION = hue * (0.4 * tally_gain);                      // hue-true glow
		} else {
			col = mix(col, col * 0.38, tally_active);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.15;
}
