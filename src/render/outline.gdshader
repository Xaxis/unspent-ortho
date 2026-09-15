// Screen-space ink, drawn on a full-screen quad in front of the camera.
//
// Silhouettes: a pixel is inked when a neighbour is FARTHER by more than
// `threshold` world units, which puts the line on the near object's own edge,
// one pixel wide, never doubled onto the background.
//
// Creases: under an orthographic camera a flat face has linear depth, so the
// second difference of depth is zero on it and jumps where two faces meet. A
// convex fold (a terrace lip over a wall that faces the camera, a roof ridge)
// gets a lighter line, broken now and then like a pen lifting.
//
// The ink is not black: it leans a little toward the colour it is drawn over,
// so a line on snow is a blue-grey pen and a line on ash is near black.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float threshold = 0.45;
uniform float strength = 0.82;
uniform float crease = 0.022;
uniform float crease_strength = 0.45;
uniform vec3 ink : source_color = vec3(0.031, 0.027, 0.059);
// Neon halo: light spills from bright saturated pixels into the rain and haze
// as a stippled glow, a few pixels out. Never a smooth bloom.
uniform float halo_strength = 0.55;

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float d = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float r = linear_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float l = linear_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = linear_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float b = linear_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float e = max(max(r - d, l - d), max(u - d, b - d));
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	// Ink turns blue under the moon (docs/ART.md section 1, law 4).
	vec3 pen = mix(sky_line(ink), c * 0.35, 0.25);
	float edge = step(threshold, e);
	// Convex folds: the pixel is nearer than the average of its neighbours.
	float fold = max((l + r) * 0.5 - d, (u + b) * 0.5 - d);
	vec2 wpx = floor(FRAGCOORD.xy) + world_px;
	float lift = step(0.12, ink_hash(floor(wpx / 3.0) + vec2(41.0, 7.0)));
	float cr = step(crease, fold) * (1.0 - edge) * step(e, threshold) * lift;
	vec3 outc = mix(c, pen, max(edge * strength, cr * crease_strength));
	// Halo: look out along eight directions at three radii for neon.
	vec3 glow = vec3(0.0);
	float haze = 1.0 + sky_fog.z * 0.8 + sky_settle.z * 0.6;
	for (int ri = 0; ri < 3; ri++) {
		float rad = (ri == 0 ? 2.0 : (ri == 1 ? 3.0 : 5.0)) * haze;
		float fall = ri == 0 ? 0.5 : (ri == 1 ? 0.3 : 0.16);
		for (int di = 0; di < 8; di++) {
			float a = float(di) * 0.7854 + float(ri) * 0.39;
			vec3 s = texture(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * px * rad).rgb;
			float mx = max(s.r, max(s.g, s.b));
			float mn = min(s.r, min(s.g, s.b));
			float neon = smoothstep(0.5, 0.85, mx) * smoothstep(0.3, 0.6, (mx - mn) / max(mx, 0.001));
			glow += s * neon * fall;
		}
	}
	glow /= 8.0;
	float gl = max(glow.r, max(glow.g, glow.b));
	// Stipple: the glow is laid as dots whose density is its strength.
	float dots = step(ink_hash(wpx + vec2(13.0, 77.0)), clamp(gl * 3.0 * halo_strength, 0.0, 0.7));
	outc = mix(outc, max(outc, glow / max(gl, 0.001) * 0.85), dots);
	ALBEDO = outc;
}
