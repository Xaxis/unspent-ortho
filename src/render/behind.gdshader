// A BODY THE LAND HIDES IS STILL DRAWN: where a wall, a slot's side or a heap
// stands between the camera and a person or a machine, the hidden part of the
// body is stippled through it in the body's own ink (docs/LOOK.md law 5: stipple,
// never a fade). The land never opens -- nothing is cut out of it -- the body is
// drawn over it. A next pass of the body's own material: it draws only where the
// opaque world in the depth texture lies nearer the eye than this surface.
//
// People are in the transparent pass and never in the depth texture, so the
// ground under them is further than they are and nothing is drawn; a machine's
// own opaque body IS in it, and the margin keeps it from finding itself.
//
// THE SEA IS NOT A WALL. A swimmer is IN it: what is under the sheet is hidden
// the way water hides it, and stippled through it the legs of a man treading
// water stood on the waves in a checker (the swimming frames, 2026-10-10). The
// hiding surface is known to be the sea by where it lies, flat at SEA_Y, which
// no step of the land ever is (WorldData.STEP is 0.5).
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled, fog_disabled, blend_mix;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// The body's ink: pale for people, the machines' cold band for machines.
uniform vec3 ink : source_color = vec3(0.86, 0.82, 0.72);
// How much nearer the world must be, in world units, before a surface counts
// as hidden: a body never finds its own skin, or the ground at its feet.
uniform float margin = 0.6;
// The sea's sheet (TerrainMesher.WATER_Y; tests/swim/test_swim.gd holds them
// together), and how far off it a hiding surface still counts as the sea: the
// open sea past the map is laid 0.02 under it.
const float SEA_Y = 0.3;
const float SEA_NEAR = 0.04;

void fragment() {
	// Only for the camera looking down, where a wall can stand between it and a
	// body in a slot. Over the shoulder the eye stands behind the player and a
	// body's own kit on its back, or a ledge's lip at its knees, would stipple
	// it (measured: a jacket checkered under its pack).
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		discard;
	}
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
#endif
	vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene = -v.z / v.w;
	float self = -VERTEX.z;
	if (scene > self - margin) {
		discard;
	}
	vec3 hider = (INV_VIEW_MATRIX * vec4(v.xyz / v.w, 1.0)).xyz;
	vec3 here = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (abs(hider.y - SEA_Y) < SEA_NEAR && here.y < SEA_Y) {
		discard;
	}
	// Half the pixels, on a pattern pinned to the screen in pairs, so it reads
	// as a figure drawn through the wall and not a ghost fading in it.
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	if (mod(cell.x + cell.y, 2.0) > 0.5) {
		discard;
	}
	ALBEDO = matter_albedo(ink);
}
