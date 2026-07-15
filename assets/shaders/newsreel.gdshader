shader_type canvas_item;
render_mode blend_mix;

// THE NIGHT'S NEWSREEL — decayed 1920s silent-film pass over each still.
// One material, driven mostly by TIME so it lives without per-frame script:
// Ken Burns (zoom/pan tweened per still), sepia, animated grain, gate flicker,
// vignette, drifting vertical scratches, dust specks, and a faint gate weave.
//
// Applied to a full-rect TextureRect whose texture is the captured frame. Per
// still the host tweens `zoom`, `pan`, and rolls `seed` so no two cards decay
// the same way. `reveal` (0..1) irises the still up from black on a cut.

uniform float zoom = 1.06;          // Ken Burns zoom (1 = none)
uniform vec2  pan = vec2(0.0);      // Ken Burns pan, in UV
uniform float seed = 0.0;           // per-still variation
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

uniform float sepia_amt : hint_range(0.0, 1.0) = 0.92;
uniform float grain_amt : hint_range(0.0, 1.0) = 0.16;
uniform float flicker_amt : hint_range(0.0, 1.0) = 0.10;
uniform float vignette_amt : hint_range(0.0, 1.0) = 0.55;
uniform float scratch_amt : hint_range(0.0, 1.0) = 0.6;
uniform float dust_amt : hint_range(0.0, 1.0) = 0.5;
uniform float weave_amt : hint_range(0.0, 1.0) = 0.5;
uniform float contrast = 1.18;

// Cheap hashes.
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
	float gate = floor(TIME * 24.0) + seed * 97.0;

	// Gate weave: a tiny sub-pixel horizontal wander per frame.
	float weave = (hash11(gate * 0.7) - 0.5) * 0.004 * weave_amt;

	// Ken Burns: zoom about centre, then pan.
	vec2 uv = (UV - 0.5) / zoom + 0.5 + pan;
	uv.x += weave;
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	vec3 col = texture(TEXTURE, uv).rgb;

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
	float g = hash21(UV * vec2(720.0, 405.0) + gate);
	col += (g - 0.5) * grain_amt;

	// Drifting vertical scratches: a couple of bright hairlines that jump x and
	// come and go over a few frames, like emulsion damage running the reel.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float life = hash11(floor(TIME * 2.0 + fi * 13.0) + seed);
		if (life > 0.55) {
			float sx = hash11(floor(TIME * 2.0 + fi * 13.0) * 1.7 + fi);
			float d = abs(UV.x - sx);
			float line = smoothstep(0.0025, 0.0, d) * scratch_amt * (life - 0.55) * 2.0;
			col += line * vec3(0.9, 0.85, 0.7);
		}
	}

	// Dust & specks: sparse bright/dark motes that flicker each gate step.
	float dust = hash21(floor(UV * vec2(220.0, 130.0)) + gate * 1.31);
	if (dust > 0.9975) {
		col += vec3(0.8) * dust_amt;
	} else if (dust < 0.0012) {
		col -= vec3(0.6) * dust_amt;
	}

	// Vignette: heavy aged darkening at the corners.
	vec2 vd = UV - 0.5;
	float vig = smoothstep(0.78, 0.32, length(vd) * 1.35);
	col *= mix(1.0, vig, vignette_amt);

	// Iris/reveal from black on a cut.
	col *= reveal;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
