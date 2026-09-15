// MADE: everything a person or the land made. Terrain, props, houses, people.
// A flat palette wash, lit in two bands; shade is a colour AND ink hatching in
// the style of the country (or of the hand, for made things). See docs/ART.md.
//
// Vertex channels (MeshKit writes them):
//   COLOR.rgb  wash colour (palette sRGB)      COLOR.a   unused (keep 1)
//   CUSTOM0    rgb = second wash for an ecotone, a = blend toward it (0..1)
//   UV.x       hatch styles, style1 + style2 * 16      UV.y  style blend (0..1)
//   UV2.x      wind sway weight (0 = rigid)
//   UV2.y      sway phase when swaying; on rigid geometry, how much the wash
//              breaks into large organic light/dark patches (terrain uses 1)
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

global uniform float wind_strength;
// The one-step shade: pushed toward blue-violet. Ink colour is darker still.
uniform vec3 shade_tint = vec3(0.66, 0.68, 0.82);
uniform vec3 ink_tint = vec3(0.42, 0.40, 0.55);
uniform float emission_strength = 0.0;

varying vec3 world_pos;
varying vec3 wash2;
varying float wash_blend;
varying float style_packed;
varying float style_blend;
varying float patchy;

void vertex() {
	float sway = UV2.x;
	if (sway > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float t = TIME * 1.3 + UV2.y * 6.283 + wp.x * 0.35 + wp.z * 0.21;
		float gust = 0.6 + 0.4 * sin(TIME * 0.37 + wp.x * 0.05);
		vec3 push = vec3(sin(t), 0.0, cos(t * 0.8)) * sway * 0.06 * (0.3 + wind_strength) * gust;
		VERTEX += (inverse(mat3(MODEL_MATRIX)) * push);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wash2 = CUSTOM0.rgb;
	wash_blend = CUSTOM0.a;
	style_packed = UV.x;
	style_blend = UV.y;
	patchy = UV2.x > 0.0 ? 0.0 : UV2.y;
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	vec3 c = COLOR.rgb;
	// A second wash (another ground, another country) meets this one on a ragged
	// pixel edge: never a muddy average, never a tile square.
	if (wash_blend > 0.0 && ink_edge(wash_blend, px) > 0.5) {
		c = wash2;
	}
	if (patchy > 0.0) {
		float pn = ink_vnoise(world_pos.xz * 0.11) * 0.65 + ink_vnoise(world_pos.xz * 0.37) * 0.35;
		c *= 1.0 + patchy * (step(0.64, pn) * 0.055 - step(pn, 0.34) * 0.05);
	}
	c *= paper(px);
	ALBEDO = sky_apply(c, world_pos, TIME);
	EMISSION = c * emission_strength;
}

void light() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.0, ndl) * step(0.5, ATTENUATION);
		float band = ndl > 0.42 ? 1.0 : 0.9;
		// Depth of shade: 0 in cast shadow on a sunward face, 1 on a face turned away.
		float depth = lit > 0.5 ? 0.0 : clamp(0.55 - ndl * 0.8, 0.0, 1.0);
		int style = ink_style(style_packed, style_blend, px);
		float ink = (1.0 - lit) * hatch(style, px, depth);
		vec3 k = mix(shade_tint, vec3(band), lit);
		k = mix(k, ink_tint, ink * 0.75);
		DIFFUSE_LIGHT += LIGHT_COLOR * k / PI;
	} else {
		// Lamps and fire: three hard steps, a warm pool that covers the ink.
		float a = clamp(ATTENUATION * step(-0.2, ndl), 0.0, 1.0);
		a = floor(a * 3.0 + 0.5) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
