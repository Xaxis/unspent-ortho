// Weather drawn into the notebook (docs/ART.md section 6): rain as short slanted
// ink strokes in columns, snow as paper flecks, ash as dark specks, heat as a
// wavering line, wind as the odd flick, splashes as tiny ticks. Every mark is
// built in whole SCREEN pixels around its particle (CPUParticles3D, so the
// Compatibility renderer draws it), one pixel wide, never blurred or blended.
//
// Per particle, from CPUParticles3D colours: COLOR.r is a random 0..1 (from
// color_initial_ramp), COLOR.a the lifetime (from color_ramp: 1 while alive,
// dropping to 0 at the ends for marks that fade in and out), COLOR.g the age
// 0..1 for marks that grow (rings). A dust devil's mesh carries three random
// numbers in COLOR.rgb instead and is spun about its node (SWIRL).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;

#include "res://src/render/sky.gdshaderinc"

// 0 stroke, 1 fleck, 2 heat wave, 3 wind flick, 4 splash tick, 5 spark (a
// small cross of light, for wisps), 6 ring spreading on standing water, 7 swirl
// (a fleck spun up a dust devil's column).
uniform int mode = 0;
// Swirl: a per-devil phase, so no two spin in step.
uniform float seed_phase = 0.0;
uniform vec3 color_a : source_color = vec3(0.18, 0.17, 0.27);
uniform vec3 color_b : source_color = vec3(0.59, 0.75, 0.82);
// Share of marks drawn in color_b.
uniform float mix_b = 0.0;
// Share of marks shown: the amount eases without restarting the emitter.
uniform float density = 1.0;
// Stroke: length in pixels (min, max). Fleck: size in pixels (min, max).
uniform vec2 length_px = vec2(5.0, 8.0);
// Stroke: pixels sideways per pixel down (negative leans left).
uniform float slant = 0.3;
// 0..1: how much marks gather into drifting columns (curtains of rain).
uniform float columns = 0.0;
// Flecks wander sideways by this many pixels.
uniform float wander = 0.0;
// 1 = the mark gives light (embers): not dimmed by the night, and it flickers.
uniform float glow = 0.0;
// Flickers per second of a glowing mark: embers change their minds, wisps pulse.
uniform float flicker_rate = 12.0;
// Pale marks read on dark ground and dark marks on pale: color_b flecks get a
// shade pixel under them in color_a when this is 1.
uniform float underline = 0.0;
// Flicks lead with their head: +1 moving screen-right, -1 moving left.
uniform float facing = 1.0;
// Which sky_ground channel says this weather belongs over the land below the
// mark: 0 anywhere, 1 snow country, 2 ash country, 3 wet country. Marks over
// other countries are dropped, so ash never falls over the snowfield beside
// the burning, nor snow over the clinker.
uniform int ground_mask = 0;

varying vec2 v_px;
varying vec3 v_col;
varying float v_len;
varying float v_rnd;
varying float v_age;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float rnd = COLOR.r;
	float alive = COLOR.a;
	v_rnd = rnd;
	v_age = COLOR.g;
	if (mode == 7) {
		// Up a column that widens toward the top, round and round, leaning a
		// little with the wind; marks near the top thin out as the grit falls.
		float spin = TIME * (3.2 + 1.8 * COLOR.b) + rnd * 6.2832 + seed_phase;
		float rise = fract(COLOR.g + TIME * (0.22 + 0.2 * COLOR.b) + seed_phase * 0.13);
		float r = mix(0.12, 1.2, rise * rise) * (0.7 + 0.3 * COLOR.b);
		origin += vec3(cos(spin) * r + rise * sin(TIME * 0.6 + seed_phase) * 0.5, rise * 3.4, sin(spin) * r * 0.8);
		alive = step(rise, 0.92) * step(0.03, rise);
		v_age = 0.0;
	}
	float len = floor(mix(length_px.x, length_px.y + 0.999, fract(rnd * 7.31)));
	v_len = len;
	vec4 c = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(origin, 1.0));
	vec2 ndc = c.xy / c.w;
	vec2 pix = floor((ndc * 0.5 + 0.5) * VIEWPORT_SIZE);
	if ((mode == 1 || mode == 5) && wander > 0.0) {
		pix.x += floor(sin(TIME * (0.8 + rnd) + rnd * 60.0) * wander + 0.5);
	}
	// The mark's box in pixels, relative to the anchor pixel.
	vec2 lo;
	vec2 hi;
	if (mode == 0) {
		lo = vec2(min(0.0, slant * len) - 1.0, -len - 1.0);
		hi = vec2(max(0.0, slant * len) + 2.0, 1.0);
	} else if (mode == 1) {
		lo = vec2(0.0, -underline);
		hi = vec2(len, len);
	} else if (mode == 2) {
		lo = vec2(-5.0, -2.0);
		hi = vec2(6.0, 3.0);
	} else if (mode == 3) {
		lo = vec2(facing > 0.0 ? -len : 0.0, -2.0);
		hi = vec2(facing > 0.0 ? 1.0 : len + 1.0, 3.0);
	} else if (mode == 6) {
		lo = vec2(-len - 2.0, -len - 2.0);
		hi = vec2(len + 3.0, len + 3.0);
	} else if (mode == 7) {
		lo = vec2(0.0, -1.0);
		hi = vec2(len, len);
	} else {
		lo = vec2(-2.0, -2.0);
		hi = vec2(3.0, 3.0);
	}
	vec2 corner = mix(lo, hi, VERTEX.xy + 0.5);
	v_px = corner;
	POSITION = vec4(((pix + corner) / VIEWPORT_SIZE * 2.0 - 1.0) * c.w, c.z, c.w);
	// Thin the marks: by density, by the lifetime fade (a random share drops out
	// as it fades, so marks never go translucent), and into columns.
	float keep = density * step(fract(rnd * 53.1), alive);
	if (ground_mask > 0) {
		vec4 g = textureLod(sky_ground, origin.xz * sky_view.z, 0.0);
		float m = ground_mask == 1 ? g.r : (ground_mask == 2 ? g.g : g.b);
		keep *= smoothstep(0.15, 0.85, m);
	}
	if (columns > 0.0) {
		// Curtains: bands a few tiles wide across the screen, bending a little
		// with depth so they read as squalls and not stripes, sweeping over the
		// land. Inside a curtain it pours; between them only a few drops fall.
		float across = dot(origin, vec3(0.7071, 0.0, -0.7071));
		float along = dot(origin, vec3(0.7071, 0.0, 0.7071));
		float col = sky_noise(vec2(across * 0.16 + along * 0.06 - TIME * 0.5, along * 0.03 + 3.0)) * 0.8 + sky_noise(vec2(across * 0.5 - TIME * 0.3, along * 0.1 + 9.0)) * 0.2;
		keep *= mix(1.0, 0.07 + 1.4 * smoothstep(0.5, 0.58, col), columns);
	}
	if (rnd > keep) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	}
	v_col = fract(rnd * 31.17) < mix_b ? color_b : color_a;
}

void fragment() {
	vec2 q = floor(v_px);
	bool on = false;
	bool shade = false;
	if (mode == 0) {
		// One pixel per row down the stroke, stepped sideways by the slant.
		on = q.y < 0.0 && q.y >= -v_len && q.x == floor(-slant * (q.y + 1.0) + 0.5);
	} else if (mode == 1) {
		on = q.x >= 0.0 && q.y >= 0.0 && q.x < v_len && q.y < v_len;
		shade = underline > 0.5 && q.y == -1.0 && q.x >= 0.0 && q.x < v_len;
		on = on || shade;
	} else if (mode == 2) {
		// A wavering line: ~~ drawn in nine pixels, its phase walking with time.
		float ph = floor(fract(TIME * 1.5 + v_rnd * 7.0) * 4.0);
		float y = mod(q.x + 3.0 + ph, 4.0);
		float wave = y < 1.0 ? 0.0 : (y < 2.0 ? 1.0 : (y < 3.0 ? 0.0 : -1.0));
		on = abs(q.x) <= 4.0 && q.y == wave;
	} else if (mode == 3) {
		// A flick: a flat stroke that lifts at its head.
		float x = q.x * sign(facing);
		float t = -x / max(v_len, 1.0);
		on = x <= 0.0 && x > -v_len && q.y == floor((1.0 - t) * (1.0 - t) * 1.6);
	} else if (mode == 5) {
		// A spark: a centre and its four neighbours; big ones reach two pixels.
		float r = abs(q.x) + abs(q.y);
		on = (q.x == 0.0 || q.y == 0.0) && r <= (v_len > 1.5 ? 2.0 : 1.0);
	} else if (mode == 6) {
		// A ring spreading on the water, flattened as the ground is seen, broken
		// into dashes as it grows, gone before it is wide.
		float rad = 1.0 + v_age * v_len;
		float d = length(vec2(q.x, q.y / 0.55));
		float dash = step(0.3, fract(atan(q.y, q.x) * 1.27 + v_rnd * 5.0));
		on = abs(d - rad) < 0.6 && (v_age < 0.35 || dash > 0.5) && v_age < 0.92;
	} else if (mode == 7) {
		on = q.x >= 0.0 && q.y >= -1.0 && q.x < v_len && q.y < v_len;
		shade = q.y == -1.0;
	} else {
		// A splash: two tiny ticks leaning out from where the drop landed.
		on = (q.y == 0.0 && abs(q.x) == 1.0) || (q.y == 1.0 && abs(q.x) == 2.0 && fract(v_rnd * 17.0) < 0.5);
	}
	if (!on) {
		discard;
	}
	vec3 col = shade ? color_a : v_col;
	// Marks in the air take the sky's light, but keep a floor so snow and rain
	// read as weather at night instead of vanishing into the dark.
	vec3 light = max(sky_tint * mix(1.0, sky_sun.z, 0.5) * 1.1, vec3(0.42, 0.48, 0.66));
	vec3 lit = col * min(light, vec3(1.0));
	float flick = step(0.35, fract(sin(floor(TIME * flicker_rate + v_rnd * 13.0) + v_rnd * 91.0) * 43.7));
	vec3 c = mix(lit, col, glow);
	if (glow > 0.5 && flick < 0.5) {
		discard;
	}
	ALBEDO = mix(c, SKY_PAGE, step(0.3, sky_sun.w) * (1.0 - glow) * 0.5);
}
