// Weather marks: rain streaks that run DOWN in columns, hail, snow, ash, dust
// and embers. Drawn on CPUParticles3D (Compatibility-safe). The vertex stage
// builds each mark facing the camera from the particle's origin, so a streak is
// always the same number of pixels wide whatever the particle's rotation.
//
// Per particle, from CPUParticles3D colours: COLOR.r is a random 0..1 (from
// color_initial_ramp), COLOR.a the lifetime fade (from color_ramp).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;

#include "res://src/render/sky.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.59, 0.75, 0.82);
uniform vec3 color_b : source_color = vec3(0.87, 0.94, 0.97);
// Share of particles drawn in color_b.
uniform float mix_b = 0.0;
// Share of all particles shown: amount changes without restarting the emitter.
uniform float density = 1.0;
// 0 = streak along `fall`, 1 = square flake.
uniform float flake = 0.0;
// World units: x = width, y = length (streak) or size (flake).
uniform vec2 size = vec2(0.05, 0.4);
uniform vec3 fall = vec3(0.0, -1.0, 0.0);
// Flakes wander sideways by this many tiles.
uniform float sway = 0.0;
uniform float opacity = 0.7;
// 1 = an emitter (embers): ignores the night and flickers.
uniform float glow = 0.0;
// Snap flakes to this world grid so they land on whole pixels (0 = off).
uniform float texel = 0.0;

varying vec3 v_col;
varying float v_alpha;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float rnd = COLOR.r;
	float fade = COLOR.a;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 p;
	if (flake > 0.5) {
		float t = TIME * (0.7 + rnd * 0.9) + rnd * 60.0;
		origin += right * sway * sin(t) + up * sway * 0.3 * cos(t * 1.3);
		float s = size.y * (0.75 + 0.5 * fract(rnd * 13.7));
		if (texel > 0.0) {
			// Whole-texel flakes: snap the centre in the camera's screen plane.
			float ox = dot(origin, right);
			float oy = dot(origin, up);
			origin += right * (floor(ox / texel + 0.5) * texel - ox) + up * (floor(oy / texel + 0.5) * texel - oy);
		}
		p = origin + right * VERTEX.x * s + up * VERTEX.y * s;
	} else {
		vec3 f = normalize(fall);
		vec3 side = normalize(cross(f, normalize(INV_VIEW_MATRIX[2].xyz)));
		float len = size.y * (0.7 + 0.6 * fract(rnd * 7.31));
		p = origin + side * VERTEX.x * size.x - f * (VERTEX.y + 0.5) * len;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
	if (rnd > density) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	}
	v_col = fract(rnd * 31.17) < mix_b ? color_b : color_a;
	float flick = glow > 0.5 ? (0.55 + 0.45 * step(0.4, fract(sin(TIME * 17.0 + rnd * 91.0) * 43.7))) : 1.0;
	v_alpha = opacity * fade * flick;
}

void fragment() {
	// Marks in the air catch more light than the ground they fall on, or snow
	// vanishes against snow; at night they still go dark with everything.
	// A pale blue floor keeps flakes and streaks reading as weather at night
	// rather than as dark specks of dirt.
	vec3 light = max(sky_tint * sky_sun.z * 1.3, vec3(0.42, 0.48, 0.64));
	vec3 lit = v_col * clamp(light, vec3(0.0), vec3(1.0));
	vec3 c = mix(lit, v_col, glow);
	c = mix(c, vec3(0.9, 0.95, 1.0), sky_sun.w * 0.6 * (1.0 - glow));
	ALBEDO = c;
	ALPHA = v_alpha;
}
