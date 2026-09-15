// Drawn marks laid over the world by survival: ink ticks, stipple dust and smoke,
// sparks (docs/ART.md §7). Flat vertex colour, no light, no depth written. They are
// drawn in the transparent pass after the outline (SurvivalMarks sets a higher
// render_priority), still hidden by what stands in front of them, and never ringed
// by the outline: a dot of dust stays a dot. (Drawn opaque without depth, the
// ground laid down after them painted them out.)
// Colour alpha is the glow: 1 = tinted by the sky like the page under it,
// 0 = its own colour at any hour (sparks, embers).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://src/render/sky.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, sky_apply(COLOR.rgb, world_pos, TIME), COLOR.a);
	ALPHA = 1.0;
}
