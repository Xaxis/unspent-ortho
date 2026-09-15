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
//
// Fog softens the pen: inside a bank the line lifts a length at a time and pales
// toward the bank, and a whiteout nearly takes it. Near lights in fog, rain or
// haze throw stippled shafts (the glint list, sky.gdshaderinc), never a bloom.
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
// Stippled shafts from the glint list's lights in fog and rain.
uniform float shaft_strength = 0.45;

// A light's shafts at this pixel: thin rays fanning out from it, longest
// downward where the light falls, each a dotted line one pixel wide, a few lit
// at a time and changing their minds slowly. Returns the dot density 0..1.
// to_px: this pixel minus the light's, in pixels (y down).
const float SHAFT_RAYS = 22.0;
float shaft(vec2 to_px, float level, float air, float seed) {
	float r = length(to_px);
	float reach = 10.0 + 44.0 * air * (0.6 + 0.4 * level);
	if (r > reach || r < 3.0) {
		return 0.0;
	}
	float a = atan(to_px.y, to_px.x) + seed;
	float bin = floor(a / 6.2832 * SHAFT_RAYS + 0.5);
	float centre = bin / SHAFT_RAYS * 6.2832;
	// One pixel wide at any distance: the pixel's distance off the ray's line.
	float off = abs(r * sin(a - centre));
	if (off > 0.6) {
		return 0.0;
	}
	float lit_ray = step(0.4, ink_hash(vec2(bin, floor(TIME * 0.7 + seed * 3.0))));
	float down = 0.15 + 0.85 * clamp(to_px.y / max(r, 1.0), 0.0, 1.0);
	float len = reach * down * (0.6 + 0.4 * ink_hash(vec2(bin, 7.0 + seed)));
	float fall = 1.0 - r / max(len, 0.001);
	return lit_ray * clamp(fall * 1.3, 0.0, 1.0) * (0.4 + 0.6 * level) * (0.5 + air);
}

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
	float ink_amount = max(edge * strength, cr * crease_strength);
	// The world point under this pixel: for fog, and for where it lies from a light.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r * 2.0 - 1.0);
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r);
#endif
	vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz / vp.w, 1.0)).xyz;
	if (sky_fog.z > 0.001 || sky_air.w > 0.001) {
		// Where this pixel's ground lies in a bank, the pen lifts a length at a
		// time and what is left pales toward the bank.
		float fogged = max(sky_fog_at(wp, wpx, 0.02), sky_air.w);
		float kept = step(ink_hash(floor(wpx / vec2(4.0, 2.0)) + vec2(9.0, 33.0)), 1.0 - fogged * 0.55);
		ink_amount *= kept * (1.0 - fogged * 0.45);
	}
	vec3 outc = mix(c, pen, ink_amount);
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
	// Shafts: the air that carries them is fog, rain and haze.
	float air = clamp(sky_fog.z * 1.1 + sky_air.x * 0.45 + sky_air.w * 0.3, 0.0, 1.0);
	if (air > 0.05) {
		vec2 here_px = sky_px(wp);
		for (int m = 0; m < 3; m++) {
			mat4 pos = m == 0 ? sky_glints : (m == 1 ? sky_glints2 : sky_glints3);
			mat4 rgb = m == 0 ? glint_rgb : (m == 1 ? glint_rgb2 : glint_rgb3);
			for (int i = 0; i < 4; i++) {
				vec4 g = pos[i];
				if (g.w <= 0.0) {
					continue;
				}
				// Screen pixels from the light, y down the screen. The camera is
				// orthographic, so the pinned pixels of any two world points differ
				// by exactly their offset on the screen.
				vec2 to_px = here_px - sky_px(g.xyz);
				to_px.y = -to_px.y;
				if (abs(to_px.x) > 56.0 || abs(to_px.y) > 56.0) {
					continue;
				}
				// A light hidden behind a roof throws nothing over the roof: the
				// scene at the light's own pixel (and the pixels beside it, so a
				// pixel's rounding never decides) is nearer than the light.
				vec2 guv = SCREEN_UV - vec2(to_px.x, -to_px.y) * px;
				float gdepth = max(linear_depth(guv, INV_PROJECTION_MATRIX), max(linear_depth(guv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX), linear_depth(guv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX)));
				float ldepth = -(VIEW_MATRIX * vec4(g.xyz, 1.0)).z;
				if (gdepth < ldepth - 0.5) {
					continue;
				}
				float sd = shaft(to_px, g.w, air, float(m * 4 + i) * 1.37);
				if (sd > 0.0 && step(ink_hash(wpx + vec2(31.0, 11.0 + float(i))), sd * shaft_strength * 1.6) > 0.5) {
					outc = mix(outc, max(outc, rgb[i].rgb), 0.75);
				}
			}
		}
	}
	ALBEDO = outc;
}
