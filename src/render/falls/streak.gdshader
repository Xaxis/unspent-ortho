// A PIECE OF THE PLATFORM BURNING THROUGH THE SKY (src/core/sky/fall_schedule.gd
// says when and where; src/render/falls/streak_view.gd hands one fall's numbers
// over). One draw a fall: a MultiMesh of ribbons, INSTANCE_CUSTOM.x saying which
// part each instance is --
//   0      the body's line, from where it lit up to its head (or its breakup):
//          the head, the hot wake behind it and the train it leaves
//   1..6   the pieces it breaks into, each its own line off the break point
//   7      the breakup's flash, a quad facing the eye
// Each ribbon is a strip of STEPS segments laid along its line, its vertices
// crowded toward the head (`crowd`) where everything happens, plus one pair
// (UV.x 2) that rounds the head off in front.
//
// EVERY POINT KNOWS HOW LONG AGO THE HEAD PASSED IT (`v_a`, real seconds), and
// that one number is the whole look: at 0 it is the head, plasma white with a
// violet fringe; a few tenths later it is the wake cooling through gold to
// orange and deep red; seconds on it is the train -- its own ember glow gone,
// widened, drifting in the winds of its own height (`wind_at`, which shears it
// into a twist), lit only by what light reaches that height: the sun at dusk,
// long after the land has lost it, and the moon.
//
// COMPRESSED SPACE and HULL-DOWN as the colossi (colossus.gdshader's header):
// every vertex is moved along its own view ray into the room inside the far
// plane, so where it is on the glass is exact and only depth is squashed; a
// far path drops below the horizon on the small planet R_EFF. A ribbon is
// additive light and writes no depth, so squashing never matters to it; the
// land still stands in front of it.
//
// THE AIR it is seen through is the ring's (orbit_sky.gdshaderinc
// `orbit_through`, above the weather: blue lost first near the horizon), and
// the dome's clouds -- drawn in the sky pass, BEHIND this main-pass ribbon --
// are asked again here (`streak_cloud_amount`) and let take it, so a streak
// goes behind cloud rather than burning over it.
//
// MINIMUM WIDTHS in pixels (`MIN_PX`, `HEAD_PX`) with the light a widened line
// did not have given back (`thin`), so a head three hundred kilometres off is a
// sharp point of a pixel and never a crawl of dashes.
//
// Transparent: streak_view.gd gives the material its render_priority.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled, skip_vertex_transform;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/render/sky_dome.gdshaderinc"

// THE FALL, in metres from `f_origin` (the eye's ground point): where it lit
// up, which way it goes, how long its lit path is, and its clock.
uniform vec3 f_origin = vec3(0.0);
uniform vec3 f_p0 = vec3(0.0, 100000.0, 0.0);
uniform vec3 f_dir = vec3(1.0, -0.2, 0.0);
uniform float f_len = 300000.0;
uniform float f_secs = 1.0;
uniform float f_age = 0.0;
// The breakup: its real second and its share of the path (dust: the whole).
uniform float f_tb = 1.0;
uniform float f_sb = 1.0;
// Real seconds its train lasts.
uniform float f_train = 2.0;
// Light NOW, worked out on the CPU (FallSchedule head_level, flash_level,
// piece_level) times the class's energy and the distance's: the head, the flash.
uniform float f_head = 0.0;
uniform float f_flash = 0.0;
// The pieces: (direction, speed m/s) and (life s, light now, 0, 0).
uniform vec4 f_piece_dir[6];
uniform vec4 f_piece_k[6];
uniform int f_pieces = 0;
// The head's true radius (m), its halo (px), how fast its wake cools (s), its
// train's own glow and how much light the train scatters, and the share of all
// of it the hour lets be seen (a dust streak is nothing by day; a mass is).
uniform float f_core_m = 100.0;
uniform float f_halo_px = 4.0;
uniform float f_wake_s = 0.12;
uniform float f_train_own = 0.6;
uniform float f_scatter = 1.0;
uniform float f_vis = 1.0;
// The winds of the train's height: speed (m/s), wavelength in height (m), two
// phases.
uniform vec4 f_wind = vec4(40.0, 7000.0, 0.0, 1.0);

// Compressed space (ColossusView.compress), the lens's pixel, the weather.
uniform float comp_d0 = 1148.0;
uniform float comp_max = 1393.0;
uniform float comp_l = 25.0;
uniform float px_angle = 0.001;
uniform float thick = 0.0;

const float R_EFF = 4.5e6;
const float MIN_PX = 0.9;
const float HEAD_PX = 0.8;
// How many core radii a head's ribbon reaches out, so its glow fades to nothing
// inside it.
const float HEAD_REACH = 4.0;
// Where the head's light stops gaining in proportion.
const float HEAD_KNEE = 4.0;
const float PIECE_SLOW = 0.7;
// How fast a train widens: metres over the square root of its age.
const float TRAIN_GROW = 260.0;
// How much of the light a piece's own train keeps, against the body's.
const float PIECE_TRAIN = 0.35;
// The flash: its least size on the glass, and its true one.
const float FLASH_PX = 26.0;
const float FLASH_M = 5000.0;
// Heights a train holds in, km: fading in from x to y at the bottom, out from
// z to w at the top.
const vec4 TRAIN_BAND = vec4(34.0, 52.0, 92.0, 106.0);

const vec3 PLASMA = vec3(0.93, 0.95, 1.0);
const vec3 VIOLET = vec3(0.62, 0.36, 1.0);
const vec3 FLASH_COL = vec3(0.86, 1.0, 0.90);
const vec3 EMBER_LOW = vec3(0.55, 0.12, 0.10);
const vec3 DUSK_GOLD = vec3(1.25, 0.82, 0.48);
// Real seconds the wake's own ember lasts on the train.
const float OWN_S = 2.5;

varying vec3 v_true;
varying vec3 v_seen;
varying float v_a;
varying float v_across;
varying float v_ahead;
varying float v_px;
varying float v_head;
varying float v_tw;
varying float v_thin;
varying float v_sub;
varying vec2 v_quad;
varying float v_part;
varying float v_along;
// How bright the head was when it passed here, against its best (the train
// it leaves is as thick as the burning was), and how near the line's own end.
varying float v_birth;
// Where on its ribbon a fragment is, 0 on the line to 1 at the edge, and 0 to
// 1 out along the head's rounded front.
varying float v_side;
varying float v_front;

// The mirrors of FallSchedule's motion, named the same.
float head_s(float t) {
	float x = clamp(t, 0.0, 1.0);
	return 1.2 * x - 0.2 * x * x;
}

float time_at(float s) {
	return (1.2 - sqrt(max(1.44 - 0.8 * clamp(s, 0.0, 1.0), 0.0))) / 0.4;
}

float piece_x(vec4 d, vec4 k, float tau) {
	float t = clamp(tau, 0.0, k.x);
	float dec = d.w * PIECE_SLOW / k.x;
	return d.w * t - 0.5 * dec * t * t;
}

float piece_tau_at(vec4 d, vec4 k, float x) {
	float dec = d.w * PIECE_SLOW / k.x;
	return (d.w - sqrt(max(d.w * d.w - 2.0 * dec * x, 0.0))) / dec;
}

// THE WINDS UP THERE, by height: two layers of shear at different wavelengths,
// so a train drifting in them for a minute folds into a slow corkscrew and no
// two stretches of it bend the same way.
vec3 wind_at(float h) {
	float l = f_wind.y;
	return vec3(
		sin(h / l + f_wind.z) + 0.5 * sin(h / (l * 0.43) + 2.1 * f_wind.w),
		0.22 * sin(h / (l * 0.71) + f_wind.w),
		cos(h / (l * 1.3) + f_wind.w) + 0.4 * cos(h / (l * 0.37) + f_wind.z)) * f_wind.x;
}

float compress_len(float d) {
	if (d <= comp_d0) {
		return d;
	}
	return min(comp_d0 + comp_l * log(1.0 + (d - comp_d0) / comp_l), comp_max);
}

// Crowd a strip's vertices toward its head (u = 1).
float crowd(float u) {
	return 1.0 - pow(1.0 - clamp(u, 0.0, 1.0), 2.5);
}

void vertex() {
	int part = int(INSTANCE_CUSTOM.x + 0.5);
	float u = UV.x;
	float side = UV.y * 2.0 - 1.0;
	bool cap = u > 1.5;
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 p = vec3(0.0);
	vec3 t = f_dir;
	float a = 0.0;
	float head = 0.0;
	float sub = 1.0;
	bool gone = false;
	v_part = float(part);
	v_quad = vec2(0.0);
	vec3 pb = f_p0 + f_dir * f_sb * f_len;
	if (part == 0) {
		float s_end = min(head_s(f_age / f_secs), f_sb);
		float s = s_end * crowd(u);
		p = f_p0 + f_dir * s * f_len;
		v_along = s * f_len;
		// Thin where it lit up, full by the breakup, closing off at its end.
		v_birth = smoothstep(0.0, 0.35, s / max(f_sb, 0.01)) * (1.0 - smoothstep(0.93, 1.0, s / max(s_end, 1e-4)) * step(f_head, 0.0));
		a = max(f_age - time_at(s) * f_secs, 0.0);
		head = f_head;
		gone = f_age > f_secs + f_train;
	} else if (part <= f_pieces && part <= 6) {
		vec4 d = f_piece_dir[part - 1];
		vec4 k = f_piece_k[part - 1];
		float tau = f_age - f_tb;
		float x = piece_x(d, k, tau) * crowd(u);
		p = pb + d.xyz * x;
		v_along = x + float(part) * 37000.0;
		v_birth = pow(clamp(1.0 - piece_tau_at(d, k, x) / k.x, 0.0, 1.0), 1.3);
		t = d.xyz;
		a = max(tau - piece_tau_at(d, k, x), 0.0);
		head = k.y;
		sub = PIECE_TRAIN;
		gone = tau <= 0.0 || tau > k.x + f_train * PIECE_TRAIN;
	} else if (part == 7) {
		gone = f_flash <= 0.001;
		p = pb;
	} else {
		gone = true;
	}
	v_true = vec3(0.0);
	v_seen = vec3(0.0, 1.0, 0.0);
	v_a = 0.0;
	v_across = 0.0;
	v_ahead = 0.0;
	v_px = 1.0;
	v_head = 0.0;
	v_tw = 1.0;
	v_thin = 0.0;
	v_sub = 0.0;
	v_along = 0.0;
	v_birth = 1.0;
	v_side = side;
	v_front = cap ? 1.0 : 0.0;
	if (gone) {
		// Nothing of this part is lit: every vertex on one point, no area.
		VERTEX = vec3(0.0);
	} else {
		// The train drifts in the winds of its own height as it ages.
		p += wind_at(p.y) * a;
		vec3 world = f_origin + p;
		float dist = distance(world, eye);
		float px = dist * px_angle;
		float w;
		float ahead = 0.0;
		if (part == 7) {
			float r = max(FLASH_M, FLASH_PX * px);
			float x = cap ? 1.0 : u * 2.0 - 1.0;
			v_quad = vec2(x, side);
			world += (INV_VIEW_MATRIX[0].xyz * x + INV_VIEW_MATRIX[1].xyz * side) * r;
			w = r;
		} else {
			float tw = f_core_m * 1.5 + TRAIN_GROW * sqrt(a);
			float tw_draw = max(tw, MIN_PX * px);
			v_tw = tw_draw;
			v_thin = tw / tw_draw;
			// Round the head the halo reaches: wide enough at and just behind it.
			// Wide enough for the halo AND for the core's own falloff (a near
			// mass's core is many pixels): a ribbon narrower than its core
			// cuts the head off square.
			float reach = max(f_halo_px * px, HEAD_REACH * max(f_core_m, HEAD_PX * px));
			float halo = head > 0.0 ? reach * (1.0 - smoothstep(0.0, f_wake_s * 6.0, a)) : 0.0;
			w = max(tw_draw, halo);
			if (cap) {
				ahead = head > 0.0 ? max(reach, MIN_PX * px) : 0.0;
				world += normalize(t) * ahead;
				w = ahead;
			}
			vec3 across = normalize(cross(normalize(t), world - eye));
			world += across * side * w;
		}
		v_true = world;
		v_a = a;
		v_across = side * w;
		v_ahead = ahead;
		v_px = px;
		v_head = head;
		v_sub = sub;
		// HULL-DOWN on the small planet, then compressed along its own ray.
		float flat_d = length(world.xz - eye.xz);
		vec3 drawn = world - vec3(0.0, flat_d * flat_d / (2.0 * R_EFF), 0.0);
		v_seen = normalize(drawn - eye);
		vec3 v = (VIEW_MATRIX * vec4(drawn, 1.0)).xyz;
		float d = length(v);
		if (d > comp_d0) {
			v *= compress_len(d) / d;
		}
		VERTEX = v;
	}
}

// DUPLICATE of orbit_sky.gdshaderinc `orbit_cloud_amount` (itself the dome's
// three lines): to be deduped into a shared `dome_cloud_amount(d)`.
float streak_cloud_amount(vec3 d) {
	float h = d.y;
	if (h <= 0.0) {
		return 0.0;
	}
	vec2 p = d.xz / (h + 0.08) * 1.6 + dome_drift * 0.004;
	float n = dome_fbm(p);
	float amount = smoothstep(1.0 - (0.18 + dome_cover * 0.72), 1.02 - dome_cover * 0.35, n);
	return amount * smoothstep(0.0, 0.18, h);
}

// DUPLICATE of orbit_sky.gdshaderinc `orbit_through`: the light that gets down
// through the air from above it, per channel, blue lost first.
vec3 streak_through(vec3 d) {
	float s = max(d.y, 0.0) + 0.035;
	float tau = (0.045 + 0.10 * (1.0 + thick * 3.0)) / s;
	return exp(-tau * vec3(0.55, 0.85, 1.35)) * smoothstep(-0.01, 0.015, d.y);
}

// THE WAKE COOLING, by how many wake-times ago the head passed: plasma white,
// gold, orange, a deep red going out.
vec3 cooling(float x) {
	vec3 c = mix(PLASMA, vec3(1.0, 0.80, 0.52), smoothstep(0.0, 0.6, x));
	c = mix(c, vec3(1.0, 0.44, 0.13), smoothstep(0.5, 1.8, x));
	return mix(c, vec3(0.62, 0.10, 0.05), smoothstep(1.6, 3.5, x));
}

// A hue through the one door, at an energy.
vec3 lit(vec3 hue, float e) {
	return matter_albedo(hue) * e;
}

void fragment() {
	vec3 c = vec3(0.0);
	if (v_part > 6.5) {
		// THE BREAKUP: a hard pale-green burst and a soft shell round it.
		float r = length(v_quad);
		float burst = exp(-r * r * 30.0) + exp(-r * 7.0) * 0.22;
		c = lit(FLASH_COL, f_flash * burst * (1.0 - smoothstep(0.85, 1.0, r)));
	} else {
		float d = sqrt(v_across * v_across + v_ahead * v_ahead);
		if (v_head > 0.0) {
			// However bright the head, its light is brought to nothing before
			// the ribbon's edges and its front, so it is never cut off square.
			float win = (1.0 - smoothstep(0.45, 1.0, abs(v_side))) * (1.0 - smoothstep(0.2, 1.0, v_front));
			// THE HEAD and its hot wake: a sub-pixel core drawn a pixel wide
			// with the light it did not have given back, a violet fringe where
			// the plasma's edge is, and a halo of glare round it.
			float core_w = max(f_core_m, HEAD_PX * v_px);
			float thin = clamp(f_core_m / core_w, 0.12, 1.0);
			float x = v_a / f_wake_s;
			float wake = exp(-x * 0.9);
			float core = exp(-pow(d / core_w, 2.0));
			float fringe = clamp(exp(-pow(d / (core_w * 2.2), 2.0)) - core, 0.0, 1.0) * exp(-x * 2.0);
			float halo = exp(-d / (f_halo_px * v_px * 0.3)) * exp(-x * 3.0);
			float a_core = v_head * wake * core * mix(thin, 1.0, 0.4) * 3.0;
			float a_fringe = v_head * fringe * 0.9;
			float a_halo = v_head * halo * 0.35;
			// A soft knee on the whole of it: past HEAD_KNEE the head gains
			// slowly, so a near one is a white point whose wake still grades
			// down its length, never a bar burned flat to white.
			float knee = 1.0 / (1.0 + (a_core + a_fringe + a_halo) / HEAD_KNEE);
			c += (lit(cooling(x), a_core) + lit(VIOLET, a_fringe) + lit(PLASMA, a_halo)) * knee * win;
		}
		// THE TRAIN: its own ember glow for the first seconds, then only the
		// light that reaches its height.
		// A soft core and a wider haze round it, and BEADS along it: a train is
		// never even -- it forms where the air at its height let it (between
		// TRAIN_BAND km), and in knots and gaps along its length.
		float prof = (exp(-pow(v_across / v_tw, 2.0)) + 0.22 * exp(-pow(v_across / (v_tw * 3.0), 2.0))) * v_thin;
		float km = v_true.y / 1000.0;
		float band = smoothstep(TRAIN_BAND.w, TRAIN_BAND.z, km) * smoothstep(TRAIN_BAND.x, TRAIN_BAND.y, km);
		float n = ink_vnoise(vec2(v_along / 7000.0, float(f_pieces) * 3.1 + f_wind.z)) * 0.65
			+ ink_vnoise(vec2(v_along / 1900.0, 7.0 + f_wind.w)) * 0.35;
		float beads = 0.12 + 1.9 * smoothstep(0.28, 0.8, n);
		prof *= mix(1.0, band * beads, smoothstep(0.3, 3.0, v_a)) * mix(1.0, v_birth, smoothstep(0.1, 1.0, v_a));
		float span = f_train * v_sub;
		float fade = 1.0 - smoothstep(span * 0.45, span, v_a);
		// The ember of the wake is gone in a few seconds whatever the class: what
		// lasts is only the light the train scatters.
		float own = f_train_own * smoothstep(0.02, 0.4, v_a) * exp(-v_a / min(OWN_S, max(0.12 * span, 0.2)));
		vec3 own_col = mix(vec3(1.0, 0.46, 0.18), vec3(0.62, 0.86, 0.70), smoothstep(1.5, 10.0, v_a));
		vec3 sun = normalize(dome_sun_dir);
		float sun_el = asin(clamp(sun.y, -1.0, 1.0));
		float over = sun_el + sqrt(2.0 * max(v_true.y, 0.0) / R_EFF);
		float sees = smoothstep(-0.004, 0.05, over);
		vec3 sun_col = mix(EMBER_LOW * dome_glow_color, dome_glow_color, smoothstep(0.0, 0.1, over));
		sun_col = mix(sun_col, dome_sun_color, smoothstep(0.05, 0.35, sun_el));
		// Near the terminator the light up there has come the long way through
		// the air: gold, then rose, never the pale of the dusk sky under it.
		sun_col *= mix(vec3(1.0), DUSK_GOLD, 1.0 - smoothstep(0.06, 0.22, over));
		float phase = 0.45 + 1.6 * pow(max(dot(v_seen, sun), 0.0), 6.0);
		float dense = smoothstep(0.5, 5.0, v_a) * fade * v_sub;
		vec3 scat = matter_albedo(sun_col) * (sees * phase * f_scatter * dense);
		float moon = dome_night * smoothstep(0.0, 0.12, dome_moon_dir.y);
		scat += lit(vec3(0.62, 0.72, 1.0), moon * f_scatter * dense * 0.24);
		c += (lit(own_col, own * v_sub) + scat) * prof;
	}
	// Through the air, behind the clouds, as much as the hour lets be seen.
	c *= streak_through(v_seen) * (1.0 - streak_cloud_amount(v_seen)) * f_vis;
	ALBEDO = c;
}
