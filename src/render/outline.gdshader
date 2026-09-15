// Screen-space ink outline, drawn on a full-screen quad in front of the camera.
// A pixel is inked when a neighbour is FARTHER by more than `threshold` world
// units: that puts the line on the near object's own silhouette, one pixel wide,
// never doubled onto the background.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float threshold = 0.45;
uniform float strength = 0.82;
uniform vec3 ink : source_color = vec3(0.031, 0.027, 0.059);

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float d = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float e = 0.0;
	e = max(e, linear_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - d);
	e = max(e, linear_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - d);
	e = max(e, linear_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX) - d);
	e = max(e, linear_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX) - d);
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float edge = step(threshold, e);
	ALBEDO = mix(c, ink, edge * strength);
}
