// The readability rim for people (docs/ART.md section 5): a one-pixel line
// round the silhouette in the person's own colours, one ramp step lighter on the
// side toward the key light (screen upper left) and one step darker opposite.
// Never ink-black. Drawn as a next pass of person.gdshader: the back faces,
// pushed out across the screen by exactly one texel along the smoothed normal
// SkinRig stores in TANGENT (skinned with the bones, so the rim follows limbs).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, skip_vertex_transform, fog_disabled, shadows_disabled;

#include "res://src/render/sky.gdshaderinc"

uniform vec3 step_down = vec3(0.700, 0.704, 0.749);
// Rim width in texels of the 640x360 image.
uniform float width = 1.0;

varying vec3 world_pos;
varying float toward;

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
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 lit = toward > -0.2 ? min(c / step_down, vec3(1.0)) : c * step_down;
	ALBEDO = sky_apply(lit, world_pos, TIME);
	ALPHA = 1.0;
}
