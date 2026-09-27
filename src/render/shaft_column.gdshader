// THE DAY FALLING THROUGH A TEAR, on a tier with no volumetric air (11_dome).
//
// Where the renderer has volumetric fog, a tear's spot light stands in it as a
// column by itself (and a sinkhole's in its own FogVolume). Compatibility has
// neither, so the web saw a pool of light on the floor with nothing above it:
// the one thing a hole in the roof must show is the light coming DOWN. This is
// that column as geometry, an open cylinder from the tear to the pool.
//
// Additive and unlit, like holo.gdshader: it is light standing in the air, not
// a surface the light falls on, and it writes no depth, so it can never hide a
// body. Its edge is soft because a column of lit air is thickest where the eye
// looks through its middle and thin where it grazes the side; its ends fade so
// it never draws a lid or a disc. Near the eye it fades out altogether: an
// additive sheet across the lens is a white frame, which is exactly what a
// broken fore layer did under this same tear.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

// The day's colour here, a palette colour (11_dome's SINK_* / SHAFT_*). One
// material per shaft, never an instance uniform (holo.gdshader says why).
uniform vec3 column_tint = vec3(0.88, 0.94, 1.0);
// How much the air shows it, 0..1: the hour and the lid, from 11_dome.
uniform float column_strength = 1.0;

// The most one pass through the column adds. The column is seen through two
// walls, so the middle of it adds about twice this; kept low enough that glow
// lifts it into a column and never into a white slab.
const float COLUMN_MOST = 0.11;
// View-space distance over which the column fades in from the eye.
const float EYE_CLEAR = 1.5;
const float EYE_FULL = 5.0;

varying vec3 world_pos;
varying float along;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// A unit CylinderMesh: y runs -0.5 at the pool to 0.5 at the tear.
	along = 0.5 - VERTEX.y;
}

void fragment() {
	// Through the middle, not along the side.
	float through = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float body = through * through;
	// In at the tear, out into the pool.
	float ends = smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.82, 1.0, along));
	float eye = smoothstep(EYE_CLEAR, EYE_FULL, length(VERTEX));
	// Dust turning in the light: sparse world-pinned specks that drift down, so
	// the column is air with something in it and not a tube.
	// A speck is a point in the world, round and a few pixels across wherever
	// the eye is, never a cell of a grid.
	vec3 drift = world_pos * 3.0 + vec3(0.0, TIME * 1.1, 0.0);
	vec3 cell = floor(drift);
	vec3 at = vec3(ink_hash(cell.xy + cell.z * 7.1), ink_hash(cell.yz + 3.3), ink_hash(cell.zx + 9.7));
	float lit = step(0.93, ink_hash(cell.xz + cell.y * 1.7 + vec2(7.0, 29.0)));
	float dust = lit * (1.0 - smoothstep(0.05, 0.12, length(fract(drift) - at))) * 3.0;
	float a = COLUMN_MOST * column_strength * ends * eye * (body + dust * body);
	ALBEDO = matter_light(column_tint);
	ALPHA = clamp(a, 0.0, 1.0);
}
