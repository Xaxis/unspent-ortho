// The sky as it is SEEN, for a camera that can see the horizon
// (SkyLight.sees_horizon: the eye-level, over-the-shoulder view).
//
// The play camera never shows the sky: it looks down at 57 degrees, and the sky
// there is only what metal and water reflect, which a ProceduralSkyMaterial does
// well. Seen, a sky has to carry an hour on its own -- a low sun warming the
// horizon on its side of the world and not the other, the stars over a coast at
// midnight, the moon, weather coming over -- and a gradient of two colours
// carries none of that. SkyLight swaps this in only while the horizon is in
// frame, so the orthographic game reflects exactly the sky it always did.
//
// Every colour is the hour's own, handed over by SkyLight from the same keys the
// light is built from (DAY/DUSK/NIGHT_SKY_*, bent by the landscape's air), so the
// sky can never disagree with the light it is the source of.
//
// THE SUN HERE IS WHERE THE SUN REALLY IS. The light's own bearing is chosen for
// the length of a shadow on screen and never drops much below sixty degrees
// (SkyLight._elevation_for_shadow); drawn there, the disc would hang overhead
// at dusk. `sun_dir` shares its AZIMUTH -- so the warm side of the sky is the
// side the light comes from -- and takes its elevation off the clock.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.29, 0.42, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.68, 0.74);
uniform vec3 ground_color : source_color = vec3(0.20, 0.20, 0.18);
// The low sun's warmth along the horizon on its own side, and how much of it
// there is (0 at noon and in the dead of night).
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.30);
uniform float glow = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 moon_dir = vec3(0.0, 1.0, 0.0);
// 0 in daylight .. 1 once night has fallen: stars and the moon.
uniform float night = 0.0;
// How much of the sky the weather has covered (0..1), how dark its underside
// is, and where it has drifted to (tiles).
uniform float cover = 0.0;
uniform float cloud_dark = 0.0;
uniform vec2 drift = vec2(0.0);
uniform float energy = 1.0;
// HOW MUCH OF THIS SKY IS SEEN, 0..1 (SkyLight.horizon_share). At 0 it draws the
// ProceduralSkyMaterial it replaces, number for number, so the swap between the
// two changes nothing -- not in the frame and not in what metal reflects -- and
// the drawn sky comes in over the band instead of in one frame.
uniform float seen = 1.0;
uniform vec3 p_top : source_color = vec3(0.385, 0.454, 0.55);
uniform vec3 p_horizon : source_color = vec3(0.646, 0.656, 0.67);
uniform vec3 p_ground_horizon : source_color = vec3(0.646, 0.656, 0.67);
uniform vec3 p_ground_bottom : source_color = vec3(0.2, 0.169, 0.133);
uniform float p_sky_curve = 0.15;
uniform float p_ground_curve = 0.02;
uniform float p_sun_angle_max = 0.5;
uniform float p_sun_curve = 0.15;
uniform float p_sky_energy = 1.0;
uniform float p_ground_energy = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// Godot's ProceduralSkyMaterial (scene/resources/3d/sky_material.cpp), with its
// cover texture left out because this game never sets one.
vec3 sun_in(vec3 sky, vec3 d, bool on, vec3 dir, float size, vec3 col, float en) {
	if (!on) {
		return sky;
	}
	float a = acos(clamp(dot(dir, d), -1.0, 1.0));
	if (a < size) {
		return col * en;
	}
	if (a < p_sun_angle_max) {
		float c2 = (a - size) / (p_sun_angle_max - size);
		return mix(col * en, sky, clamp(1.0 - pow(1.0 - c2, 1.0 / p_sun_curve), 0.0, 1.0));
	}
	return sky;
}

vec3 procedural(vec3 d) {
	float v_angle = acos(clamp(d.y, -1.0, 1.0));
	float c = (1.0 - v_angle / (PI * 0.5));
	vec3 sky = mix(p_horizon, p_top, clamp(1.0 - pow(1.0 - c, 1.0 / p_sky_curve), 0.0, 1.0));
	sky *= p_sky_energy;
	sky = sun_in(sky, d, LIGHT0_ENABLED, LIGHT0_DIRECTION, LIGHT0_SIZE, LIGHT0_COLOR, LIGHT0_ENERGY);
	sky = sun_in(sky, d, LIGHT1_ENABLED, LIGHT1_DIRECTION, LIGHT1_SIZE, LIGHT1_COLOR, LIGHT1_ENERGY);
	sky = sun_in(sky, d, LIGHT2_ENABLED, LIGHT2_DIRECTION, LIGHT2_SIZE, LIGHT2_COLOR, LIGHT2_ENERGY);
	sky = sun_in(sky, d, LIGHT3_ENABLED, LIGHT3_DIRECTION, LIGHT3_SIZE, LIGHT3_COLOR, LIGHT3_ENERGY);
	c = (v_angle - (PI * 0.5)) / (PI * 0.5);
	vec3 ground = mix(p_ground_horizon, p_ground_bottom, clamp(1.0 - pow(1.0 - c, 1.0 / p_ground_curve), 0.0, 1.0));
	ground *= p_ground_energy;
	return mix(ground, sky, step(0.0, d.y));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	if (seen <= 0.0) {
		COLOR = procedural(d);
	} else {
		float h = d.y;
		// The dome: the horizon colour is where the air closes (the depth fog takes
		// its colour from here at eye level), so the land's far edge meets the sky on
		// no line. The ground half keeps the horizon colour at the line itself.
		vec3 col;
		if (h >= 0.0) {
			col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
		} else {
			col = mix(horizon_color, ground_color, pow(clamp(-h * 3.0, 0.0, 1.0), 0.6));
		}
		// The low sun's glow: warm on its own side of the sky, strongest along the
		// horizon and gone by a third of the way up.
		vec2 flat_d = normalize(d.xz + vec2(1e-5));
		vec2 flat_s = normalize(sun_dir.xz + vec2(1e-5));
		float toward = max(dot(flat_d, flat_s), 0.0);
		float band = exp(-max(h, 0.0) * 5.5) * (h > -0.05 ? 1.0 : exp((h + 0.05) * 30.0));
		col = mix(col, glow_color, clamp(glow * band * (0.25 + 0.75 * pow(toward, 4.0)), 0.0, 1.0));
		// Weather over the sky: a cover of cloud, lit on the sun's side, and never
		// down at the horizon, where the air has already taken the sky over.
		if (h > 0.0) {
			vec2 p = d.xz / (h + 0.08) * 1.6 + drift * 0.004;
			float n = fbm(p);
			float amount = smoothstep(1.0 - (0.18 + cover * 0.72), 1.02 - cover * 0.35, n);
			amount *= smoothstep(0.0, 0.18, h);
			vec3 lit = mix(horizon_color * 1.05, mix(sun_color, glow_color, glow * 0.8), 0.35 + 0.35 * toward);
			vec3 cloud = mix(lit, horizon_color * 0.55, clamp(cloud_dark + (n - 0.5) * 0.6, 0.0, 1.0));
			cloud = mix(cloud, col * 0.6, night * 0.85);
			col = mix(col, cloud, amount);
		}
		float clear = 1.0 - clamp(cover * 1.3, 0.0, 1.0);
		// The sun itself, where it really is, with a halo that the weather dims.
		float sd = dot(d, normalize(sun_dir));
		float disc = smoothstep(0.99990, 0.99995, sd);
		float halo = pow(max(sd, 0.0), 900.0) * 0.8 + pow(max(sd, 0.0), 60.0) * 0.18;
		float up = smoothstep(-0.03, 0.02, sun_dir.y);
		// A low sun is seen through the most air: it reddens into the glow and dims.
		vec3 disc_col = mix(sun_color, glow_color * 1.4, glow * 0.8);
		col += disc_col * (disc * mix(5.0, 2.2, glow) + halo) * up * mix(1.0, 0.2, 1.0 - clear);
		// The stars and the moon come out only once the sun is really down.
		float dark = night * smoothstep(-0.02, -0.18, sun_dir.y);
		if (!AT_CUBEMAP_PASS) {
			// The moon: a small pale disc, never a lamp, a little darker at its limb.
			float md = dot(d, normalize(moon_dir));
			float moon = smoothstep(0.99900, 0.99925, md);
			float limb = clamp((md - 0.99900) / 0.00100, 0.0, 1.0);
			col = mix(col, vec3(0.80, 0.82, 0.88) * mix(0.55, 1.0, sqrt(limb)), moon * dark * clear);
			col += vec3(0.55, 0.60, 0.75) * pow(max(md, 0.0), 400.0) * 0.25 * dark * clear;
			// Stars: a fixed field, only where night has fallen and the sky is clear,
			// thinning into the air near the horizon.
			if (h > 0.02 && dark > 0.0) {
				vec2 uv = vec2(atan(d.x, d.z), asin(h)) * 190.0;
				vec2 cell = floor(uv);
				float s = hash21(cell);
				if (s > 0.9965) {
					vec2 at = vec2(hash21(cell + 7.1), hash21(cell + 3.7));
					float r = length(fract(uv) - at);
					float bright = (s - 0.9965) / 0.0035;
					col += vec3(0.85, 0.88, 1.0) * smoothstep(0.35, 0.0, r) * (0.25 + bright * 0.9)
						* dark * clear * smoothstep(0.02, 0.25, h);
				}
			}
		}
		COLOR = seen >= 1.0 ? col * energy : mix(procedural(d), col * energy, seen);
	}
}
