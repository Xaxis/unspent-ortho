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
// A body's own kit, ridden on its back or hung at its belt, is opaque and IN the
// depth texture: a hider found within this of the body's upright axis, above its
// feet, is the body itself and never stipples it. Set for people (PersonModel),
// whose margin can then come down from 0.6 to just over their own soles: at 0.6 a
// one-step bank (WorldData.STEP, 0.5 high, 0.6 deep at this pitch) never counted
// as a hider, and legs at the foot of the coast's commonest bank were simply gone.
// Machines keep 0 and the old margin: their own body is large and opaque.
uniform float own_radius = 0.0;
// The sea's sheet (TerrainMesher.WATER_Y; tests/swim/test_swim.gd holds them
// together), and how far off it a hiding surface still counts as the sea: the
// open sea past the map is laid 0.02 under it.
const float SEA_Y = 0.3;
const float SEA_NEAR = 0.04;

// Where the body stands: the model's origin is at its feet.
varying vec3 body_root;

void vertex() {
	body_root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
	// Not from the close eye over the shoulder: it stands behind the player, and
	// a ledge's lip at his knees would stipple him. By distance, not by lens: the
	// held-Z lock's lens stands well back and a body behind a bank must still show.
	if (PROJECTION_MATRIX[3][3] < 0.5 && distance(CAMERA_POSITION_WORLD, body_root) < 9.0) {
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
	vec2 off = hider.xz - body_root.xz;
	if (own_radius > 0.0 && dot(off, off) < own_radius * own_radius && hider.y > body_root.y + 0.08) {
		discard;
	}
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
