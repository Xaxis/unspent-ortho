// SHAFTS: the light a lamp, a fire or a machine's lens throws into fog and rain,
// drawn on a full-screen quad in front of the camera. It is the WEB path.
//
// This file used to be the ink: screen-space silhouettes and creases, a pen
// drawn round every edge in the world. LANTERN removed it (docs/LOOK.md: the
// world is lit, not drawn) -- an edge is now told by light and material, and a
// person, who is small and must never be lost, keeps a rim of their own
// (person_rim.gdshader). The neon halo went with it, because the Environment's
// glow does that properly and in HDR.
//
// What is left is the one thing screen space is still the right answer to.
// LOOK.md's degradation table says volumetric air is "true volumetrics" on the
// desktop and "screen-space shafts and depth fog" on the web, so this pass runs
// ONLY where the tier says volumetrics are off (Quality.ROWS.volumetric ->
// CameraRig). On a tier with real volumetric fog a light throws a real cone and
// this quad is not in the tree at all.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// Shafts from the glint list's lights in fog and rain.
uniform float shaft_strength = 0.9;
// The near focus, where the tier has no depth of field of its own (Quality
// `near_stand_in`, CameraRig.near_plane): view depth where the blur begins
// (negative = off), the depth over which it comes to full, and the radius of
// full blur as a share of the frame's height.
uniform float near_begin = -1.0;
uniform float near_ramp = 4.5;
uniform float near_reach = 0.015;
// Taps of the near blur, on a golden-angle spiral so twelve read as a disc.
const int NEAR_TAPS = 12;

// A light's shafts at this pixel: a few thin rays falling from it, fanned no
// more than SHAFT_FAN either side of straight down (light falls; it never
// sprays up over a roof), each a band of loose stipple that widens as it falls,
// longest straight down, a few lit at a time and changing their minds slowly. Returns the dot
// density 0..1. to_px: this pixel minus the light's, in pixels (y down).
const float SHAFT_RAYS = 6.0;
const float SHAFT_FAN = 0.87;
float shaft(vec2 to_px, float level, float air, float seed) {
	float r = length(to_px);
	float reach = 14.0 + 34.0 * air * (0.6 + 0.4 * level);
	// The rays open a few pixels below the light, so a fan never draws its apex
	// as a tent over the window.
	if (r > reach || r < 6.0 || to_px.y <= 0.0) {
		return 0.0;
	}
	// 0 straight down, negative toward screen-left.
	float a = atan(to_px.x, to_px.y);
	if (abs(a) > SHAFT_FAN + 0.12) {
		return 0.0;
	}
	float bin = clamp(floor((a + SHAFT_FAN) / (2.0 * SHAFT_FAN) * SHAFT_RAYS), 0.0, SHAFT_RAYS - 1.0);
	float centre = -SHAFT_FAN + (bin + 0.5) / SHAFT_RAYS * 2.0 * SHAFT_FAN + (ink_hash(vec2(bin, 3.0 + seed)) - 0.5) * 0.12;
	// Thin at the light, a loose band a pixel or two across further down: the
	// pixel's distance off the ray's line against that width.
	float off = abs(r * sin(a - centre));
	float width = 0.6 + r * 0.02;
	float lit_ray = step(0.4, ink_hash(vec2(bin, floor(TIME * 0.7 + seed * 3.0))));
	float c4 = pow(cos(centre), 4.0);
	float len = reach * (0.35 + 0.65 * c4) * (0.65 + 0.35 * ink_hash(vec2(bin, 7.0 + seed)));
	float t = r / max(len, 0.001);
	// Even along its length, a long dotted fall rather than a burst at the
	// light; it thins out only near its end.
	float ray = step(off, width) * step(t, 1.0) * lit_ray * (1.0 - t * t);
	// Between the rays the cone holds a sparse stipple of the same light, so the
	// fan reads as light falling through the air and never as a drawn glyph.
	float cone = step(abs(a), SHAFT_FAN) * 0.16 * (1.0 - smoothstep(0.35, 1.0, r / reach)) * c4;
	return max(ray, cone) * (0.55 + 0.45 * level) * (0.6 + 0.4 * air);
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
	vec3 outc = texture(screen_tex, SCREEN_UV).rgb;
	// The world point under this pixel: for where it lies from a light.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r * 2.0 - 1.0);
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r);
#endif
	vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz / vp.w, 1.0)).xyz;
	vec2 wpx = sky_px(wp);
	// Nothing this pass does touches a pixel unless it writes one. Writing the
	// frame back where nothing changed is not free on Compatibility: measured, it
	// lifted a clear noon on the web by 4.3 luma (`perf features`), and there is
	// no shaft at a clear noon to pay for it.
	bool touched = false;
	// The near blur, before the shafts, so a shaft falls sharp through it.
	if (near_begin > 0.0 && d < near_begin) {
		float nb = clamp((near_begin - d) / max(near_ramp, 0.001), 0.0, 1.0);
		if (nb > 0.001) {
			vec2 radius = vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0) * near_reach * nb;
			vec3 acc = outc;
			for (int i = 0; i < NEAR_TAPS; i++) {
				float ang = float(i) * 2.39996;
				float rr = sqrt((float(i) + 0.5) / float(NEAR_TAPS));
				acc += texture(screen_tex, SCREEN_UV + vec2(cos(ang), sin(ang)) * rr * radius).rgb;
			}
			outc = acc / float(NEAR_TAPS + 1);
			touched = true;
		}
	}
	// Shafts: the air that carries them is fog, rain and haze.
	float air = clamp(sky_fog.z * 1.1 + sky_air.x * 0.45 + sky_air.w * 0.3, 0.0, 1.0);
	if (air > 0.05) {
		vec2 here_px = sky_px(wp);
		for (int m = 0; m < 3; m++) {
			mat4 pos = m == 0 ? sky_glints : (m == 1 ? sky_glints2 : sky_glints3);
			mat4 rgb = m == 0 ? glint_rgb : (m == 1 ? glint_rgb2 : glint_rgb3);
			for (int i = 0; i < 4; i++) {
				vec4 g = pos[i];
				if (g.w <= 0.0 || rgb[i].w <= 0.0) {
					continue;
				}
				// Weak or no shafts from a light that draws its own strokes (glint_rgb.w).
				float weight = rgb[i].w;
				// Screen pixels from the light, y down the screen. The camera is
				// orthographic, so the pinned pixels of any two world points differ
				// by exactly their offset on the screen.
				vec2 to_px = here_px - sky_px(g.xyz);
				to_px.y = -to_px.y;
				if (to_px.y <= 0.0 || abs(to_px.x) > 46.0 || to_px.y > 46.0) {
					continue;
				}
				float sd = shaft(to_px, g.w, air, float(m * 4 + i) * 1.37) * weight;
				if (sd <= 0.0 || step(ink_hash(wpx + vec2(31.0, 11.0 + float(i))), sd * shaft_strength) < 0.5) {
					continue;
				}
				// A dot lies on whatever the scene shows at its pixel: where that is
				// nearer the eye than the light (a roof, a wall in front, the ground
				// the shaft has already gone a little way into), the shaft is behind it.
				float ldepth = -(VIEW_MATRIX * vec4(g.xyz, 1.0)).z;
				if (d < ldepth - 0.7) {
					continue;
				}
				// A light hidden behind a roof throws nothing at all: the scene at the
				// light's own pixel (and the pixels beside it, so a pixel's rounding
				// never decides) is nearer than the light.
				vec2 guv = SCREEN_UV - vec2(to_px.x, -to_px.y) * px;
				float gdepth = max(linear_depth(guv, INV_PROJECTION_MATRIX), max(linear_depth(guv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX), linear_depth(guv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX)));
				if (gdepth >= ldepth - 0.5) {
					outc = mix(outc, max(outc, rgb[i].rgb), 0.6);
					touched = true;
				}
			}
		}
	}
	if (!touched) {
		discard;
	}
	ALBEDO = outc;
}
