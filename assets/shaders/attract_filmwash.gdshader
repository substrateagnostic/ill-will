shader_type canvas_item;
render_mode blend_mix;

// ATTRACT-MODE FILM WASH — the estate's 1920s newsreel decay, applied LIVE over
// whatever is on screen (the bot exhibition) rather than a captured still.
//
// The shipped estate/newsreel.gdshader samples its own bound TEXTURE (a static
// frame) and adds Ken Burns — perfect for the will-reading reel, wrong for a
// live match we want to show whole. This is its decay pass (sepia, animated
// grain, gate flicker, drifting scratches, dust, vignette, 24fps gate) rebound
// to hint_screen_texture so it reads the moving game frame every tick, with NO
// zoom/pan. The newsreel shader is left untouched (doc 25: "no shader changes").
//
// Applied to a full-rect ColorRect on a CanvasLayer ABOVE the game; the
// intertitle card + interrupt caption are later siblings, so they stay crisp.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float sepia_amt : hint_range(0.0, 1.0) = 0.82;
uniform float grain_amt : hint_range(0.0, 1.0) = 0.13;
uniform float flicker_amt : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_amt : hint_range(0.0, 1.0) = 0.5;
uniform float scratch_amt : hint_range(0.0, 1.0) = 0.5;
uniform float dust_amt : hint_range(0.0, 1.0) = 0.45;
uniform float contrast = 1.12;

// Cheap hashes (identical to the newsreel pass so the two looks are siblings).
float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	// 24 fps gate: quantise time so grain/flicker/scratches step like real film.
	float gate = floor(TIME * 24.0);

	// The live frame under the wash.
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// Contrast then sepia (luminance mapped onto a warm aged gradient).
	col = clamp((col - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(
		clamp(lum * 1.07 + 0.06, 0.0, 1.0),
		clamp(lum * 0.86 + 0.03, 0.0, 1.0),
		clamp(lum * 0.62, 0.0, 1.0));
	col = mix(col, sepia, sepia_amt);

	// Gate flicker: irregular per-frame exposure wobble (two beats + a step).
	float fl = 1.0
		+ flicker_amt * 0.5 * sin(TIME * 11.0)
		+ flicker_amt * 0.5 * (hash11(gate) - 0.5);
	col *= fl;

	// Animated film grain (per-frame, per-pixel).
	float g = hash21(SCREEN_UV * vec2(720.0, 405.0) + gate);
	col += (g - 0.5) * grain_amt;

	// Drifting vertical scratches: bright hairlines that jump x and come and go.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float life = hash11(floor(TIME * 2.0 + fi * 13.0));
		if (life > 0.55) {
			float sx = hash11(floor(TIME * 2.0 + fi * 13.0) * 1.7 + fi);
			float d = abs(SCREEN_UV.x - sx);
			float line = smoothstep(0.0025, 0.0, d) * scratch_amt * (life - 0.55) * 2.0;
			col += line * vec3(0.9, 0.85, 0.7);
		}
	}

	// Dust & specks: sparse bright/dark motes that flicker each gate step.
	float dust = hash21(floor(SCREEN_UV * vec2(220.0, 130.0)) + gate * 1.31);
	if (dust > 0.9975) {
		col += vec3(0.8) * dust_amt;
	} else if (dust < 0.0012) {
		col -= vec3(0.6) * dust_amt;
	}

	// Vignette: heavy aged darkening at the corners.
	vec2 vd = SCREEN_UV - 0.5;
	float vig = smoothstep(0.82, 0.30, length(vd) * 1.35);
	col *= mix(1.0, vig, vignette_amt);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
