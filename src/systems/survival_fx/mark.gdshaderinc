// Drawn marks laid over the world by survival: ink ticks, stipple dust and smoke,
// sparks (docs/ART.md §7). Flat colour, no light, no depth written, drawn in the
// transparent pass after the outline (SurvivalMarks sets render_priority) so the
// outline never rings them: a dot of dust stays a dot. mark.gdshader is hidden by
// what stands in front of it; mark_over.gdshader is drawn over it, the way a pen
// draws a blow on top of the trunk that hides where it landed.
//
// Colour alpha says where a mark's colour comes from:
//   1.0   its own colour, tinted by the sky like the page under it (flecks of stuff)
//   0.5   ink or paper, whichever reads on what is already drawn behind the mark,
//         judged once per mark at its origin so a stroke never changes colour midway
//   0.0   its own colour at any hour: it carries its own light (sparks, embers)
#include "res://src/render/sky.gdshaderinc"

uniform sampler2D mark_backdrop : hint_screen_texture, filter_nearest;
uniform vec3 mark_ink : source_color = vec3(0.0706, 0.0667, 0.1137);
uniform vec3 mark_paper : source_color = vec3(0.9098, 0.8627, 0.7529);
// Behind a mark brighter than this, it is drawn in ink; darker, in paper.
uniform float mark_pale = 0.4;

varying vec3 world_pos;
varying flat vec2 mark_anchor;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	mark_anchor = clip.xy / clip.w * 0.5 + 0.5;
}

float mark_luma(vec2 uv, vec2 px) {
	vec3 c = texture(mark_backdrop, uv).rgb * 2.0;
	c += texture(mark_backdrop, uv + vec2(px.x * 3.0, 0.0)).rgb;
	c += texture(mark_backdrop, uv - vec2(px.x * 3.0, 0.0)).rgb;
	c += texture(mark_backdrop, uv + vec2(0.0, px.y * 3.0)).rgb;
	c += texture(mark_backdrop, uv - vec2(0.0, px.y * 3.0)).rgb;
	return dot(c / 6.0, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (COLOR.a > 0.25 && COLOR.a < 0.75) {
		col = mark_luma(mark_anchor, 1.0 / VIEWPORT_SIZE) > mark_pale ? mark_ink : mark_paper;
	}
	ALBEDO = COLOR.a < 0.25 ? col : sky_apply(col, world_pos, TIME);
	ALPHA = 1.0;
}
