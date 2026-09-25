// THE DOME AS IT IS SEEN, as functions any shader can ask: the sky shader that
// draws it (sky_eye.gdshader) and anything that has to stand IN the same air and
// take its colour from the same sky (the colossi, src/render/colossus/).
//
// It was the body of sky_eye.gdshader and it is moved here WITHOUT A NUMBER
// CHANGED, so the sky it draws is the sky it drew: the arithmetic is the same
// arithmetic in the same order, only named. The one thing it cannot carry is the
// ProceduralSkyMaterial's sun terms, because LIGHTn_* exist only in a sky shader;
// `dome_procedural_sky` returns the gradient before them and the sky shader lays
// them on itself.
//
// Every uniform is `dome_`-prefixed so a spatial shader can include this beside
// sky.gdshaderinc without a name meeting one there. SkyLight fills them all from
// ONE dictionary (`SkyLight.seen_air`), so a second reader can never disagree
// with the sky about what colour the air is.
#ifndef SKY_DOME_GDSHADERINC
#define SKY_DOME_GDSHADERINC

uniform vec3 dome_top_color : source_color = vec3(0.29, 0.42, 0.66);
uniform vec3 dome_horizon_color : source_color = vec3(0.62, 0.68, 0.74);
uniform vec3 dome_ground_color : source_color = vec3(0.20, 0.20, 0.18);
// The low sun's warmth along the horizon on its own side, and how much of it
// there is (0 at noon and in the dead of night).
uniform vec3 dome_glow_color : source_color = vec3(1.0, 0.55, 0.30);
uniform float dome_glow = 0.0;
uniform vec3 dome_sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 dome_sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 dome_moon_dir = vec3(0.0, 1.0, 0.0);
// 0 in daylight .. 1 once night has fallen: stars and the moon.
uniform float dome_night = 0.0;
// How much of the sky the weather has covered (0..1), how dark its underside
// is, and where it has drifted to (tiles).
uniform float dome_cover = 0.0;
uniform float dome_cloud_dark = 0.0;
uniform vec2 dome_drift = vec2(0.0);
uniform float dome_energy = 1.0;
// HOW MUCH OF THIS SKY IS SEEN, 0..1 (SkyLight.horizon_share). At 0 it draws the
// ProceduralSkyMaterial it replaces, number for number, so the swap between the
// two changes nothing -- not in the frame and not in what metal reflects -- and
// the drawn sky comes in over the band instead of in one frame.
uniform float dome_seen = 1.0;
uniform vec3 dome_p_top : source_color = vec3(0.385, 0.454, 0.55);
uniform vec3 dome_p_horizon : source_color = vec3(0.646, 0.656, 0.67);
uniform vec3 dome_p_ground_horizon : source_color = vec3(0.646, 0.656, 0.67);
uniform vec3 dome_p_ground_bottom : source_color = vec3(0.2, 0.169, 0.133);
uniform float dome_p_sky_curve = 0.15;
uniform float dome_p_ground_curve = 0.02;
uniform float dome_p_sun_angle_max = 0.5;
uniform float dome_p_sun_curve = 0.15;
uniform float dome_p_sky_energy = 1.0;
uniform float dome_p_ground_energy = 1.0;

float dome_hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float dome_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = dome_hash21(i);
	float b = dome_hash21(i + vec2(1.0, 0.0));
	float c = dome_hash21(i + vec2(0.0, 1.0));
	float d = dome_hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float dome_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * dome_vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// THE CLOUD COVER, the one reading of it. The dome draws its clouds from these,
// and everything seen through them (the orbit's ring, a falling streak, a
// colossus) asks the same three lines rather than keep a copy of them.
// The noise the dome's clouds are drawn from, in direction `d` (above the horizon).
float dome_cloud_noise(vec3 d) {
	vec2 p = d.xz / (d.y + 0.08) * 1.6 + dome_drift * 0.004;
	return dome_fbm(p);
}

// How much of the sky that noise covers at elevation `h`: never down at the
// horizon, where the air has already taken the sky over.
float dome_cloud_cover(float n, float h) {
	float amount = smoothstep(1.0 - (0.18 + dome_cover * 0.72), 1.02 - dome_cover * 0.35, n);
	return amount * smoothstep(0.0, 0.18, h);
}

// The cloud between the eye and direction `d`, 0..1.
float dome_cloud_amount(vec3 d) {
	if (d.y <= 0.0) {
		return 0.0;
	}
	return dome_cloud_cover(dome_cloud_noise(d), d.y);
}

// Godot's ProceduralSkyMaterial (scene/resources/3d/sky_material.cpp), with its
// cover texture left out because this game never sets one: one light's disc.
vec3 dome_sun_in(vec3 sky, vec3 d, bool on, vec3 dir, float size, vec3 col, float en) {
	if (!on) {
		return sky;
	}
	float a = acos(clamp(dot(dir, d), -1.0, 1.0));
	if (a < size) {
		return col * en;
	}
	if (a < dome_p_sun_angle_max) {
		float c2 = (a - size) / (dome_p_sun_angle_max - size);
		return mix(col * en, sky, clamp(1.0 - pow(1.0 - c2, 1.0 / dome_p_sun_curve), 0.0, 1.0));
	}
	return sky;
}

// The procedural sky's upper half before any light's disc is laid on it.
vec3 dome_procedural_sky(vec3 d) {
	float v_angle = acos(clamp(d.y, -1.0, 1.0));
	float c = (1.0 - v_angle / (PI * 0.5));
	vec3 sky = mix(dome_p_horizon, dome_p_top, clamp(1.0 - pow(1.0 - c, 1.0 / dome_p_sky_curve), 0.0, 1.0));
	sky *= dome_p_sky_energy;
	return sky;
}

// And the procedural sky put together from its upper half (with whatever discs
// the caller could lay on it) and its ground.
vec3 dome_procedural_join(vec3 d, vec3 sky) {
	float v_angle = acos(clamp(d.y, -1.0, 1.0));
	float c = (v_angle - (PI * 0.5)) / (PI * 0.5);
	vec3 ground = mix(dome_p_ground_horizon, dome_p_ground_bottom, clamp(1.0 - pow(1.0 - c, 1.0 / dome_p_ground_curve), 0.0, 1.0));
	ground *= dome_p_ground_energy;
	return mix(ground, sky, step(0.0, d.y));
}

#ifdef DOME_ORBIT
// The ring in the sky (src/render/orbit/): only the seen sky defines this.
#include "res://src/render/orbit/orbit_sky.gdshaderinc"
#endif

// The seen dome in direction `d` (world space, unit), before `dome_energy`.
// `cubemap` is the radiance pass: no moon and no stars, which is exactly what
// the depth fog's aerial perspective samples, so a caller asking with `true` is
// asking for the colour the land's own air closes into.
vec3 dome_seen_col(vec3 d, bool cubemap) {
	float h = d.y;
	// The dome: the horizon colour is where the air closes (the depth fog takes
	// its colour from here at eye level), so the land's far edge meets the sky on
	// no line. The ground half keeps the horizon colour at the line itself.
	vec3 col;
	if (h >= 0.0) {
		col = mix(dome_horizon_color, dome_top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(dome_horizon_color, dome_ground_color, pow(clamp(-h * 3.0, 0.0, 1.0), 0.6));
	}
	// The low sun's glow: warm on its own side of the sky, strongest along the
	// horizon and gone by a third of the way up.
	vec2 flat_d = normalize(d.xz + vec2(1e-5));
	vec2 flat_s = normalize(dome_sun_dir.xz + vec2(1e-5));
	float toward = max(dot(flat_d, flat_s), 0.0);
	float band = exp(-max(h, 0.0) * 5.5) * (h > -0.05 ? 1.0 : exp((h + 0.05) * 30.0));
	col = mix(col, dome_glow_color, clamp(dome_glow * band * (0.25 + 0.75 * pow(toward, 4.0)), 0.0, 1.0));
	// Weather over the sky: a cover of cloud, lit on the sun's side, and never
	// down at the horizon, where the air has already taken the sky over.
	if (h > 0.0) {
		float n = dome_cloud_noise(d);
		float amount = dome_cloud_cover(n, h);
		vec3 lit = mix(dome_horizon_color * 1.05, mix(dome_sun_color, dome_glow_color, dome_glow * 0.8), 0.35 + 0.35 * toward);
		vec3 cloud = mix(lit, dome_horizon_color * 0.55, clamp(dome_cloud_dark + (n - 0.5) * 0.6, 0.0, 1.0));
		cloud = mix(cloud, col * 0.6, dome_night * 0.85);
		col = mix(col, cloud, amount);
	}
#ifdef DOME_ORBIT
	// The ring: its light added OVER the air and UNDER the clouds (orbit_sky's
	// header), its hull taking the sun, the moon and the stars away behind it.
	vec4 orbit_seen = cubemap ? vec4(0.0) : orbit_at(d);
	col = col * (1.0 - orbit_seen.a * orbit_mass) + orbit_seen.rgb;
	float orbit_hide = orbit_seen.a;
#else
	float orbit_hide = 0.0;
#endif
	float clear = 1.0 - clamp(dome_cover * 1.3, 0.0, 1.0);
	// The sun itself, where it really is, with a halo that the weather dims.
	float sd = dot(d, normalize(dome_sun_dir));
	float disc = smoothstep(0.99990, 0.99995, sd);
	float halo = pow(max(sd, 0.0), 900.0) * 0.8 + pow(max(sd, 0.0), 60.0) * 0.18;
	float up = smoothstep(-0.03, 0.02, dome_sun_dir.y);
	// A low sun is seen through the most air: it reddens into the glow and dims.
	vec3 disc_col = mix(dome_sun_color, dome_glow_color * 1.4, dome_glow * 0.8);
	col += disc_col * (disc * mix(5.0, 2.2, dome_glow) + halo) * up * mix(1.0, 0.2, 1.0 - clear) * (1.0 - orbit_hide);
	// The stars and the moon come out only once the sun is really down.
	float dark = dome_night * smoothstep(-0.02, -0.18, dome_sun_dir.y) * (1.0 - orbit_hide);
	if (!cubemap) {
		// The moon: a small pale disc, never a lamp, a little darker at its limb.
		float md = dot(d, normalize(dome_moon_dir));
		float moon = smoothstep(0.99900, 0.99925, md);
		float limb = clamp((md - 0.99900) / 0.00100, 0.0, 1.0);
		col = mix(col, vec3(0.80, 0.82, 0.88) * mix(0.55, 1.0, sqrt(limb)), moon * dark * clear);
		col += vec3(0.55, 0.60, 0.75) * pow(max(md, 0.0), 400.0) * 0.25 * dark * clear;
		// Stars: a fixed field, only where night has fallen and the sky is clear,
		// thinning into the air near the horizon.
		if (h > 0.02 && dark > 0.0) {
			vec2 uv = vec2(atan(d.x, d.z), asin(h)) * 190.0;
			vec2 cell = floor(uv);
			float s = dome_hash21(cell);
			if (s > 0.9965) {
				vec2 at = vec2(dome_hash21(cell + 7.1), dome_hash21(cell + 3.7));
				float r = length(fract(uv) - at);
				float bright = (s - 0.9965) / 0.0035;
				col += vec3(0.85, 0.88, 1.0) * smoothstep(0.35, 0.0, r) * (0.25 + bright * 0.9)
					* dark * clear * smoothstep(0.02, 0.25, h);
			}
		}
	}
	return col;
}

// What the sky shader writes to COLOR, given the procedural sky in `d` (already
// put together by the caller) and the seen dome: the one blend over the band.
vec3 dome_color(vec3 procedural, vec3 col) {
	return dome_seen >= 1.0 ? col * dome_energy : mix(procedural, col * dome_energy, dome_seen);
}

#endif
