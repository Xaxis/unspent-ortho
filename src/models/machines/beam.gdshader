// A scanning beam as a drawn thing (docs/ART.md §6): a wedge of loose cold
// pixels thrown from a watcher's, warden's or clerk's eye onto what it reads.
// Never a smooth cone and never bloom: whole palette pixels, ordered-dithered,
// pinned to the world through world_px so the stipple never swims. Densest at
// the eye, thinning along its length, with a brighter lip where it lands.
// Faint by day (the sun outshines it), plain at night. Drawn on a unit quad
// whose corners the vertex stage folds into the wedge: local +X along the beam,
// +Z across it. Transparent pass, high render priority, after the ink outline
// repaints the frame: a light has no ink round it.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform vec3 col = vec3(0.6961, 0.7720, 0.8044);
uniform float beam_length = 2.5;
uniform float beam_spread = 1.2;
// 1 while it sweeps; lower when it has locked on something.
uniform float narrow = 1.0;
// 1 sweeping; higher when locked.
uniform float strength = 1.0;

varying float night;
varying vec2 wedge;

void vertex() {
	float along = UV.x;
	float across = (UV.y - 0.5) * 2.0;
	VERTEX = vec3(along * beam_length, 0.0, across * along * beam_spread * 0.5 * narrow);
	wedge = vec2(along, across);
	vec3 tint = sky_tint;
	night = clamp((0.92 - dot(tint, vec3(0.3333))) / 0.36, 0.0, 1.0);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void fragment() {
	float along = wedge.x;
	float across = abs(wedge.y);
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	// Thins along its length, sheds its edges, and lands in a lip at the end.
	float d = 0.2 * (1.0 - along * 0.75);
	d *= 1.0 - smoothstep(0.55, 1.0, across);
	if (along > 0.86) {
		d = 0.3 * (1.0 - smoothstep(0.7, 1.0, across));
	}
	if (along < 0.06) {
		d = 0.0;
	}
	d *= clamp(strength, 0.0, 2.0) * mix(0.3, 1.0, night);
	if (bayer4(px) >= d) {
		discard;
	}
	ALBEDO = col;
	ALPHA = 1.0;
}
