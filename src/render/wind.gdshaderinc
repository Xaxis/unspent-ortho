// THE ONE WIND: how far, and which way, anything that sways is pushed.
// world.gdshader, leaf.gdshader, fore.gdshader and grass.gdshader all move by
// this, so a gust visibly crosses grass, then a bush, then a crown, in one field.
// Include it after sky.gdshaderinc (sky_wind, sky_gust, sky_shock).
//
// Three rules it keeps, each a fault the copied sway had:
//   THE PHASE IS sky_wind.w. 10_sky advances it by the wind, so a sway never
//   jumps when the weather eases. Anything written as the engine clock
//   times a rate does, by the clock times the change in rate. It wraps at 1000 turns: every beat below runs at
//   a whole or 0.8-multiple of it, so the wrap lands on a whole turn.
//   THE LEAN IS sky_wind.xy. A westerly lays the grass east.
//   THE GUST FIELD TRAVELS by sky_gust.xy, an offset 10_sky integrates
//   (src/core/foliage/wind_field.gd, whose gust_at this is term for term).

global uniform float wind_strength;

// Where bodies pushed through the grass (18_trample, TrampleField): rg the lean
// as 128 + 127 x lean, b how far it is pressed down. `foliage_trample_at`: xz the
// window's low corner, z 1 / its span; outside the window nothing is pressed,
// and z 0 (the default, where no 18_trample runs: the title, the gallery) is no
// window at all, so an unbound texture is never read as a lean.
global uniform sampler2D foliage_trample : filter_linear, repeat_enable;
global uniform vec4 foliage_trample_at;

// (lean x, lean z, pressed 0..1) at world xz.
vec3 trample_at(vec2 xz) {
	vec2 tuv = (xz - foliage_trample_at.xy) * foliage_trample_at.z;
	if (foliage_trample_at.z <= 0.0 || tuv.x < 0.0 || tuv.y < 0.0 || tuv.x >= 1.0 || tuv.y >= 1.0) {
		return vec3(0.0);
	}
	vec4 tr = texture(foliage_trample, xz * foliage_trample_at.z);
	return vec3((tr.rg * 255.0 - 128.0) / 127.0, tr.b);
}

// Held equal to WindField by tests/render/test_wind.gd.
const float GUST_CELL = 11.0;
const float GUST_PERIOD = 64.0;
const float FRONT_SHORT = 1.5;
const float FRONT_LONG = 0.5;
// How much further a full gust lays a tip over than the steady lean does.
const float GUST_LEAN = 2.2;
// How much a tip's push turns its face toward the sky, per unit of push over
// its sway weight: the travelling sheen a front makes under a real sun.
const float WIND_TILT = 3.0;

float wind_hash(vec2 c) {
	vec2 m = mod(c, GUST_PERIOD);
	return fract(sin(m.x * 127.1 + m.y * 311.7) * 43758.5453);
}

float wind_vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = q - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(wind_hash(i), wind_hash(i + vec2(1.0, 0.0)), u.x),
		mix(wind_hash(i + vec2(0.0, 1.0)), wind_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0..1: how much gust stands at world xz now.
float gust_at(vec2 xz) {
	// The lattice in the wind's frame: bands across the wind (WindField.frame).
	vec2 d = sky_gust.zw;
	vec2 s = vec2(-d.y, d.x);
	vec2 p = xz / GUST_CELL;
	vec2 q = d * dot(p, d) * FRONT_SHORT + s * dot(p, s) * FRONT_LONG - sky_gust.xy;
	float n = wind_vnoise(q) * 0.65 + wind_vnoise(q * 2.0 + 17.0) * 0.35;
	return smoothstep(0.42, 0.78, n);
}

// How much darker a sward's ground reads where it is pressed flat and where it
// is parted: seen from above, the ring round a body and the path behind it.
const float GROUND_PRESSED = 0.24;

// How much lighter a sward's ground reads under a full gust front.
const float GROUND_SHEEN = 0.26;

// -0.25..0.75: the gust over a sward's ground, less in a calm, so a front shows
// as a travelling paler band and the lull between as a little darker.
float wind_sheen(vec2 xz) {
	float blowing = clamp(length(sky_wind.xy) * 1.6, 0.0, 1.0);
	return (gust_at(xz) * mix(0.45, 1.0, sky_wind.z) - 0.25) * blowing;
}

// The unit bearing the wind blows toward: sky_wind.xy's, or through a calm the
// last one it had (sky_gust.zw), so a dead wind never swings the grass to +x.
vec2 wind_dir() {
	float l = length(sky_wind.xy);
	return l > 1e-3 ? sky_wind.xy / l : sky_gust.zw;
}

// World-space push on a vertex resting at `rest` with sway weight `weight` (0 at
// the root) and per-plant `seed` 0..1. `stiff` 1 is a crown; below 1 bends more.
// The steady lean and its sway, a gust squared on top (a front lays the grass
// over, the lull lets it up), and a colossus's landing.
vec3 wind_push(vec3 rest, float weight, float seed, float stiff) {
	vec2 dir = wind_dir();
	vec2 side = vec2(-dir.y, dir.x);
	float t = sky_wind.w + seed * 6.283 + rest.x * 0.35 + rest.z * 0.21;
	float g = gust_at(rest.xz) * mix(0.45, 1.0, sky_wind.z);
	vec2 p = (dir * (0.45 + 0.6 * sin(t)) + side * 0.4 * cos(t * 0.8)) * (0.55 + 0.45 * g)
		+ dir * g * g * GUST_LEAN;
	vec3 push = vec3(p.x, 0.0, p.y) * weight * 0.07 * (0.25 + wind_strength) / max(stiff, 0.05);
	return push + sky_shock(rest) * weight * SHOCK_BEND;
}

// A face bent over by `push` turns toward the sky on its windward side and
// away on its lee. `n` and `push` in one space; `weight` the vertex's sway.
vec3 wind_tilt(vec3 n, vec3 push, float weight, vec3 up) {
	float k = WIND_TILT / max(weight, 0.05);
	return normalize(n + up * dot(n, push) * k);
}

// A world-space push moved into view space, in whole texels under the
// orthographic camera so a blade steps a pixel and never smears. Under the lens a
// texel has no fixed size in the world, so the push goes through whole.
vec3 wind_view(vec3 push, mat4 view, mat4 proj, vec2 vp_size) {
	vec3 vp = mat3(view) * push;
	if (proj[3][3] > 0.5) {
		float texel = 2.0 / max(abs(proj[1][1]) * vp_size.y, 1.0);
		vp.xy = round(vp.xy / texel) * texel;
	}
	return vp;
}
