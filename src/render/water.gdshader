// The sea, drawn like a chart. COLOR.a carries distance from land (0 shore,
// 1 deep) interpolated across a half-tile lattice; the shader cuts it into
// flat depth bands with an ink line at each band edge, a lapping band of foam
// at the shore, and small wave ticks that come and go. No gradients, no gloss.
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform vec3 shallow : source_color = vec3(0.169, 0.388, 0.537);
uniform vec3 middle : source_color = vec3(0.106, 0.247, 0.376);
uniform vec3 deep : source_color = vec3(0.063, 0.149, 0.247);
uniform vec3 foam : source_color = vec3(0.867, 0.941, 0.969);
uniform vec3 line_ink : source_color = vec3(0.039, 0.082, 0.141);
uniform vec3 shade_tint = vec3(0.66, 0.68, 0.82);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float band_edge(float d, float t, float w) {
	return 1.0 - smoothstep(0.0, w, abs(d - t));
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	float d = COLOR.a;
	float w = max(fwidth(d), 1e-4) * 1.2;
	vec3 c = d < 0.14 ? shallow : (d < 0.5 ? middle : deep);
	// Ink at the band edges: a chart's depth contours.
	float edge = max(band_edge(d, 0.14, w), band_edge(d, 0.5, w));
	c = mix(c, mix(c, line_ink, 0.55), step(0.5, edge));
	// Foam laps: the shore band breathes in and out.
	float lap = 0.035 + 0.025 * sin(TIME * 1.1 + (world_pos.x + world_pos.z) * 0.6);
	if (d < lap) {
		c = foam;
	} else if (d < lap + 0.03 && ink_hash(px) < 0.5) {
		c = mix(foam, shallow, 0.5);
	}
	// Wave ticks: short 3-pixel dashes that appear and fade on a slow beat.
	float beat = floor(TIME * 0.9);
	vec2 cell = floor(px / vec2(9.0, 6.0));
	float h = ink_hash(cell + vec2(beat * 7.0, beat * 3.0));
	vec2 local = px - cell * vec2(9.0, 6.0);
	if (d > 0.2 && h < 0.07 && local.y == 2.0 && local.x >= 2.0 && local.x < 5.0) {
		c = mix(c, foam, 0.55);
	}
	ALBEDO = sky_apply(c, world_pos, TIME);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_tint, vec3(1.0), lit) / PI;
	} else {
		float a = floor(clamp(ATTENUATION, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
