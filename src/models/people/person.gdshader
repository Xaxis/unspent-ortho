// MADE, for people: world.gdshader's wash, paper and hatched shade in the hand
// (Ink.HAND), plus the two things docs/ART.md section 5 asks of people only:
//
//  * no ink outline. People draw in the transparent pass AFTER the camera's
//    outline quad (render_priority 10, ALPHA 1), so the depth copy the outline
//    reads never contains them and nothing inks their silhouette. They still
//    write and test depth, so the world occludes them and they occlude
//    themselves. Their shadow comes from a shadows-only twin (SkinRig).
//  * a readability rim instead, drawn by the next pass (person_rim.gdshader).
//
// Hatching never covers a face: skin (UV2.y > 0.5 marks it) takes the shade
// colour but no ink strokes.
shader_type spatial;
render_mode cull_back, specular_disabled, depth_draw_always;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/models/people/person_light.gdshaderinc"

uniform vec3 shade_tint = vec3(0.66, 0.68, 0.82);
uniform vec3 ink_tint = vec3(0.42, 0.40, 0.55);
uniform float emission_strength = 0.0;

varying vec3 world_pos;
varying float style_packed;
varying float skin;
// The stepped pool of the nearest lamp or fire this fragment stands in (0, 0.5,
// 1), handed from fragment() to light() so the moon and the fill give way to it.
varying float in_pool;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	style_packed = UV.x;
	skin = UV2.y;
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	vec3 c = COLOR.rgb * paper(px);
	vec3 at;
	vec4 lamp = person_nearest_light(world_pos, 1.05, at);
	// Only where the page is dim: by day a lamp's pool is not a colour on a face.
	float gloom = max(sky_view.y, sky_shade.w);
	in_pool = sky_pool(lamp.a, world_pos) * step(0.35, gloom);
	ALBEDO = person_in_light(sky_apply(c, world_pos, TIME), c, lamp, in_pool);
	ALPHA = 1.0;
	EMISSION = c * emission_strength + neon_skyglow(c) * 1.4;
}

void light() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.0, ndl) * step(0.5, ATTENUATION);
		float band = ndl > 0.42 ? 1.0 : 0.9;
		float depth = lit > 0.5 ? 0.0 : clamp(0.55 - ndl * 0.8, 0.0, 1.0);
		int style = int(mod(style_packed, 16.0) + 0.5);
		float ink = skin > 0.5 ? 0.0 : (1.0 - lit) * hatch(style, px, depth);
		vec3 k = mix(shade_tint * sky_shade.rgb, vec3(band), lit);
		k = mix(k, ink_tint, ink * 0.6);
		// In a fire's pool the moon and the fill give way to the fire.
		DIFFUSE_LIGHT += LIGHT_COLOR * k * (1.0 - in_pool * 0.4) / PI;
	} else {
		// The same pool the land draws (world.gdshader), so a person in lamplight
		// stands in it rather than in a softer disc of their own.
		vec3 up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float a = sky_pool(clamp(ATTENUATION * step(-0.2, ndl), 0.0, 1.0) * sky_lamp_gate(up.y, (INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).y), world_pos);
		DIFFUSE_LIGHT += LIGHT_COLOR * a * 0.6 / PI;
	}
}
