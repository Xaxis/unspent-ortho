// HEAT HAZE: the air over hot ground wavering, on a disc lying on the ground at
// a body's feet (HeatFx). What it draws is the frame behind it, read a few pixels
// off where it lies and the offset rippling outward and climbing as it goes, so
// the ground and anything low on it seen through the disc swims. It is not a
// colour: nothing is painted, nothing is outlined (docs/LOOK.md, lit not drawn).
// Depth-tested and written to no depth, so a body standing in it hides it, and
// it fades to nothing at its rim and over the cue's own life (`strength`).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// 0..1: how much the air is moving now, eased in and out by HeatFx.
uniform float strength = 0.0;
uniform float seed = 0.0;
// How far the frame is pushed at full strength, as a share of its height.
uniform float reach = 0.004;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float rim = 1.0 - smoothstep(0.35, 1.0, r);
	// Two sets of ripples crossing, running out from the middle and drifting, so
	// the swim never settles into a ring.
	float t = TIME * 2.6 + seed * 17.0;
	vec2 q = wp.xz * 7.0;
	vec2 wob = vec2(sin(q.y + r * 9.0 - t * 1.7 + sin(q.x * 0.7 + t)),
		cos(q.x - r * 8.0 + t * 1.3 + sin(q.y * 0.6 - t * 0.8)));
	vec2 off = wob * reach * strength * rim * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
	ALBEDO = texture(screen, SCREEN_UV + off).rgb;
	ALPHA = rim * strength;
}
