// The working part's light as a world object (art-audio-extract §3): a
// camera-facing ring of loose amber pixels round the part. Not a soft veil and
// never bloom (docs/ART.md §6): whole palette pixels, ordered-dithered in rings
// and pinned to the world through world_px so the pattern never swims. Pulled a
// little toward the camera and depth-tested, so when the part is on the far side
// the body hides the ring and only the spill round the silhouette shows ("over
// the shoulder"). Thicker as the sky darkens; the machine's own light is never
// tinted by it.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform vec3 core = vec3(0.9098, 0.7608, 0.2275);
uniform vec3 rim = vec3(0.5608, 0.4157, 0.0706);
// 0 none .. 1 full night density (a flare goes past 1).
uniform float strength = 1.0;
uniform float toward_camera = 0.45;

varying float night;

void vertex() {
	vec4 origin = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 v = origin.xyz + vec3(VERTEX.xy * s, toward_camera);
	POSITION = PROJECTION_MATRIX * vec4(v, 1.0);
	vec3 tint = sky_apply(vec3(1.0), NODE_POSITION_WORLD, TIME);
	night = clamp(1.25 - dot(tint, vec3(0.3333)), 0.2, 1.0);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	// The core of the ring is left open: the lens itself is the brightest pixel.
	float d = 0.0;
	if (r > 0.3 && r < 0.62) {
		d = 0.55;
	} else if (r >= 0.62 && r < 1.0) {
		d = 0.2;
	}
	d *= clamp(strength, 0.0, 1.8) * night;
	if (bayer4(px) >= d) {
		discard;
	}
	ALBEDO = r < 0.62 ? core : rim;
}
