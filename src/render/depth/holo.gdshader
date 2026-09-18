// A hologram standing over the street (HoloView): the owner's direction for the
// Slums asks for holograms and advertising and technology everywhere, and the
// boards on brackets are the advertising. This is the other half — LIGHT
// STANDING IN THE AIR, which is a different thing from a lit surface and is the
// one piece of a cyberpunk city this engine did not have in any form.
//
// It is additive and it is not lit: a hologram is not a surface the sun falls on,
// it is a thing projecting itself, and the moment it takes a light it reads as a
// painted card. It writes no depth either, so it can never occlude anything —
// which is how it keeps the promise the rest of the depth layer keeps, without a
// cut of its own.
//
// It burns on the MACHINES' power (`sky_power`) and only once the light has gone
// (`neon_burn`), like every other stolen light in this game, so a strike stutters
// the advertising over the lane exactly as it stutters the strip it was cut from.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

// The colour this one throws. ONE MATERIAL PER COLOUR rather than an instance
// uniform: `set_instance_shader_parameter` did not reach this shader through a
// `material_override` at all — measured, the column came out the same colour
// after the deal was changed, pixel for pixel (61,173,179 in two frames that
// should have differed). A uniform on four materials cannot fail that way.
uniform vec3 holo_tint = vec3(1.0, 0.52, 0.16);

// Where in the panel this fragment is: x across, y up from the foot, both 0..1.
// Taken off the MODEL rather than off UV, for the reason flier_shade records.
varying vec2 panel;
// The scan's own phase, off the instance's place in the world, so two standing
// side by side never blink in step and nothing has to be set per instance.
varying float seedling;

void vertex() {
	// The mesh is built in a unit box: x and z across, y 0..1 up.
	panel = vec2(length(VERTEX.xz) * 2.0, clamp(VERTEX.y, 0.0, 1.0));
	seedling = fract(dot(NODE_POSITION_WORLD.xz, vec2(0.1732, 0.3119)));
}

void fragment() {
	// A COLUMN, not a rectangle. It is brightest at the foot and gone by the top,
	// because a projector throws from below and the air thins out what it throws.
	float up = 1.0 - smoothstep(0.35, 1.0, panel.y);
	// Soft at the edges: a hologram with a straight edge is a poster.
	float side = 1.0 - smoothstep(0.55, 1.0, panel.x);
	// The scan: bands running up it, and a coarse dropout that makes it a
	// projection and not a gradient. TIME rather than a uniform, because this is
	// the one thing in the picture that should never be still.
	float t = TIME * 0.6 + seedling * 31.0;
	float bands = 0.62 + 0.38 * sin((panel.y * 34.0 - t * 6.0) * 3.14159);
	float dropout = step(0.12, fract(panel.y * 7.0 - t * 1.7));
	float grain = 0.85 + 0.15 * ink_hash(floor(vec2(panel.x * 40.0, panel.y * 90.0 - t * 18.0)));
	float a = up * side * bands * dropout * grain;
	// Only when the light has gone, and on the machines' own power.
	float dim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
	a *= neon_burn(dim) * sky_power();
	// 1.25 and not more: emission carries a colour toward the page as it burns
	// (the PIXEL_WASH rule the tour claims are matched under), so an overdriven
	// column arrives white and the street loses the one warm saturated thing in it.
	ALBEDO = matter_light(holo_tint) * a * 1.25;
	ALPHA = clamp(a, 0.0, 1.0);
}
