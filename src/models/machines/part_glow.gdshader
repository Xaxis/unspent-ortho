// The working part's light as a world object: a camera-facing halo pulled a
// little toward the camera, drawn additively in three hard rings (pixel light
// has edges). Depth-tested, so when the part is on the far side the body hides
// the middle and only a spill shows round the silhouette ("over the shoulder").
// Brighter as the sky darkens; the machine's own light is never tinted by it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"

uniform vec3 glow = vec3(0.9098, 0.7608, 0.2275);
uniform float strength = 1.0;
uniform float toward_camera = 0.45;

varying float night;

void vertex() {
	vec4 origin = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 v = origin.xyz + vec3(VERTEX.xy * s, toward_camera);
	POSITION = PROJECTION_MATRIX * vec4(v, 1.0);
	vec3 tint = sky_apply(vec3(1.0), NODE_POSITION_WORLD, TIME);
	night = clamp(1.3 - dot(tint, vec3(0.3333)), 0.3, 1.0);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = r < 0.28 ? 0.7 : (r < 0.6 ? 0.34 : (r < 1.0 ? 0.12 : 0.0));
	// Pushed past the palette on purpose: added over blue night it must still be amber.
	ALBEDO = glow * vec3(1.45, 1.2, 0.8) * strength * night;
	ALPHA = a;
}
