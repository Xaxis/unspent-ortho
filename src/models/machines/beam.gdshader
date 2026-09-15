// A scanning beam as a drawn thing (docs/ART.md §6): a wedge of loose cold
// pixels thrown from a watcher's, warden's or clerk's eye onto what it reads.
// Never a smooth cone and never bloom: whole palette pixels, ordered-dithered,
// pinned to the world through world_px so the stipple never swims. Densest at
// the eye, thinning along its length, with a brighter lip where it lands.
// Faint by day (the sun outshines it), plain at night. Drawn on a unit quad
// whose corners the vertex stage folds into the wedge: local +X along the beam,
// +Z across it. Transparent pass, high render priority, after the ink outline
// repaints the frame: a light has no ink round it.
//
// A flat wedge knows nothing of terraces, so each pixel asks the depth buffer
// what surface it lies over, and the light keeps to the machine's own terrace:
// none over ground half a step below its feet (it would hang over a ledge),
// none over a raised step close behind (it would cut into the step's wall or
// show inside it), and none where the wedge itself dips a step below the feet.
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
// How much of it the day leaves: a scan shows faintly, a work lamp not at all.
uniform float day_floor = 0.2;
// Width at the root as a fraction of the far end: 0 a scan's point, more for a lamp bar.
uniform float root_width = 0.0;
// World height of the ground the machine stands on (set every frame), and one
// terrace step (WorldData.STEP).
uniform float foot_y = 0.0;
uniform float step_h = 0.5;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float night;
varying vec2 wedge;
varying vec3 world;

void vertex() {
	float along = UV.x;
	float across = (UV.y - 0.5) * 2.0;
	VERTEX = vec3(along * beam_length, 0.0, across * mix(root_width, 1.0, along) * beam_spread * 0.5 * narrow);
	wedge = vec2(along, across);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

// True where this pixel's light could not be on the surface behind it.
bool off_the_ground(vec2 uv, mat4 inv_proj, mat4 inv_view) {
	if (world.y < foot_y - step_h) {
		return true;
	}
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	vec3 surface = (inv_view * vec4(v.xyz / v.w, 1.0)).xyz;
	if (surface.y < foot_y - step_h * 0.5) {
		return true;
	}
	// A raised step close behind the wedge: the light would be inside it or
	// cutting across its wall. A tall thing far behind is only seen through it.
	return surface.y > foot_y + step_h * 0.5 && distance(surface, world) < 1.5;
}

void fragment() {
	float along = wedge.x;
	float across = abs(wedge.y);
	if (off_the_ground(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX)) {
		discard;
	}
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	// Thins along its length, sheds its edges, and lands in a lip at the end.
	float d = 0.24 * (1.0 - along * 0.75);
	d *= 1.0 - smoothstep(0.55, 1.0, across);
	if (along > 0.86) {
		d = 0.26 * (1.0 - smoothstep(0.7, 1.0, across));
	}
	// Clear of the eye and whatever amber sits beside it.
	if (along < 0.12) {
		d = 0.0;
	}
	d *= clamp(strength, 0.0, 2.0) * mix(day_floor, 1.0, night);
	if (bayer4(px) >= d) {
		discard;
	}
	ALBEDO = col;
	ALPHA = 1.0;
}
