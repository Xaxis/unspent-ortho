// The readability rim for people (docs/ART.md section 5): a one-pixel line
// round the silhouette in the person's own colours, one ramp step lighter on the
// side toward the key light (screen upper left) and one step darker opposite.
// Never ink-black. Drawn as a next pass of person.gdshader: the back faces,
// pushed out across the screen by exactly one texel along the smoothed normal
// SkinRig stores in TANGENT (skinned with the bones, so the rim follows limbs).
//
// Figures read at every hour: the rim takes a little colour from the nearest
// lamp, fire or lantern (the pools the lights system hands the sky), and in
// gloom the side of the outline facing that light catches it, so a person
// standing near a fire, or carrying the lantern, is drawn by its light.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, skip_vertex_transform, fog_disabled, shadows_disabled;

#include "res://src/render/sky.gdshaderinc"

uniform vec3 step_down = vec3(0.700, 0.704, 0.749);
// Rim width in texels of the 640x360 image.
uniform float width = 1.0;
// How far past a pool's own range a figure still takes its colour.
uniform float reach = 1.6;

varying vec3 world_pos;
varying float toward;
varying vec2 rim_dir;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 v = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = (MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz;
	vec2 dir = length(n.xy) > 1e-4 ? normalize(n.xy) : vec2(0.0);
	// Orthographic: 2 / P[1][1] is the view height in world units.
	float texel = 2.0 / PROJECTION_MATRIX[1][1] / VIEWPORT_SIZE.y;
	v.xy += dir * texel * width;
	// A hair toward the camera would let the rim cover the body; a hair away keeps it behind.
	v.z -= texel * 0.5;
	VERTEX = v;
	NORMAL = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	toward = dot(dir, normalize(vec2(-1.0, 1.0)));
	rim_dir = dir;
}

// The strongest light near a point, reached a little past its pool: rgb its
// colour, a its level 0..1; `at` its position.
vec4 nearest_light(vec3 p, out vec3 at) {
	vec4 best = vec4(0.0);
	at = p;
	for (int i = 0; i < 4; i++) {
		vec4 l1 = sky_lamps[i];
		float a1 = sky_omni(p, vec4(l1.xyz, l1.w * reach));
		if (a1 > best.a) {
			best = vec4(neon_lamp_rgb[i].rgb, a1);
			at = l1.xyz;
		}
		vec4 l2 = sky_lamps2[i];
		float a2 = sky_omni(p, vec4(l2.xyz, l2.w * reach));
		if (a2 > best.a) {
			best = vec4(neon_lamp_rgb2[i].rgb, a2);
			at = l2.xyz;
		}
	}
	return best;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 lit = toward > -0.2 ? min(c / step_down, vec3(1.0)) : c * step_down;
	vec3 at;
	vec4 lamp = nearest_light(world_pos, at);
	float strength = dot(lamp.rgb, vec3(1.0)) > 0.01 ? clamp(lamp.a * 1.5, 0.0, 1.0) : 0.0;
	// A little of the light's own colour in the line: warm by a fire, cold by the lantern.
	lit = mix(lit, lit * (0.5 + lamp.rgb * 0.75), strength * 0.55);
	vec3 col = sky_apply(lit, world_pos, TIME);
	float gloom = max(sky_view.y, sky_shade.w);
	// The side of the outline that faces the light catches it, in whole steps.
	vec2 to_light = (VIEW_MATRIX * vec4(at - world_pos, 0.0)).xy;
	float facing = length(to_light) > 1e-4 ? dot(rim_dir, normalize(to_light)) : 0.0;
	float catch_light = step(0.35, facing) * step(0.08, strength) * gloom;
	col = mix(col, lit * 0.4 + lamp.rgb * 0.4, catch_light * (0.25 + 0.3 * step(0.5, strength)));
	ALBEDO = col;
	ALPHA = 1.0;
}
