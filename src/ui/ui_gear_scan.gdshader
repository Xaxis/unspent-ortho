// The slate's scanner, for a body rendered in a world of its own (UiGearFigure).
// Every drawn pixel becomes one of the slate's steps: value picks the step,
// Bayer-dithered between two at the slate's own pixels; what the body wears that
// was taken from the machines (the FOUND mask) goes to the module's violet, as the
// slate draws anything found; the amber of a working part stays the brightest step. The silhouette's edge is lit
// so the figure stands off the glass, and a line sweeps down it after a change.
//
// The tones duplicate UiTheme.PHOSPHOR and UiTheme.MACHINE on purpose (a shader
// cannot read a GDScript const); tests/ui/test_gear_figure.gd fails if they drift.
shader_type canvas_item;
uniform float lo = 0.06;
uniform float hi = 0.8;
uniform float scan = 1.0;
// White where the body is FOUND (UiGearFigure renders the same body flat on its own
// layer): which pixels are machine parts is read off the model, never guessed from
// a colour.
uniform sampler2D found_mask : filter_nearest;
const vec3 P0 = vec3(0.0902, 0.1882, 0.1608);
const vec3 P1 = vec3(0.1686, 0.3608, 0.2980);
const vec3 P2 = vec3(0.3098, 0.6078, 0.5059);
const vec3 P3 = vec3(0.5294, 0.8510, 0.7098);
const vec3 P4 = vec3(0.7882, 0.9843, 0.8863);
const vec3 M1 = vec3(0.2941, 0.2588, 0.4549);
const vec3 M2 = vec3(0.5216, 0.4745, 0.7529);
const vec3 M3 = vec3(0.7020, 0.6588, 0.9176);
const vec3 M4 = vec3(0.8784, 0.8588, 1.0);

vec3 hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

float bayer(ivec2 p) {
	int x = p.x % 4;
	int y = p.y % 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	ivec2 at = ivec2(floor(UV / px));
	float edge = 0.0;
	if (c.a > 0.5) {
		edge = texture(TEXTURE, UV + vec2(px.x, 0.0)).a < 0.5 || texture(TEXTURE, UV - vec2(px.x, 0.0)).a < 0.5
			|| texture(TEXTURE, UV + vec2(0.0, px.y)).a < 0.5 || texture(TEXTURE, UV - vec2(0.0, px.y)).a < 0.5 ? 1.0 : 0.0;
	}
	if (c.a <= 0.5) {
		COLOR = vec4(0.0);
	} else {
		float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
		float v = clamp((lum - lo) / max(0.001, hi - lo), 0.0, 1.0);
		float level = v * 4.0;
		int idx = int(floor(level));
		if (fract(level) > bayer(at)) { idx += 1; }
		idx = clamp(idx, 0, 4);
		vec3 h = hsv(c.rgb);
		// Violet enough and lit enough to be plate: a person's dark blue eye is neither.
		bool found = texture(found_mask, UV).r > 0.5;
		bool amber = found && h.y > 0.45 && h.x > 0.03 && h.x < 0.15 && h.z > 0.55;
		vec3 col;
		if (amber) {
			col = P4;
		} else if (found) {
			col = idx <= 1 ? M1 : (idx == 2 ? M2 : (idx == 3 ? M3 : M4));
		} else {
			col = idx <= 0 ? P0 : (idx == 1 ? P1 : (idx == 2 ? P2 : (idx == 3 ? P3 : P4)));
		}
		if (edge > 0.5) {
			col = found ? M3 : (idx >= 3 ? P4 : P3);
		}
		COLOR = vec4(col, 1.0);
	}
	if (scan < 1.0) {
		float d = abs(UV.y - scan);
		if (UV.y > scan && COLOR.a > 0.0) {
			COLOR.rgb = mix(COLOR.rgb, P0, 0.6);
		}
		if (d < px.y * 1.5) {
			COLOR = vec4(P4, 1.0);
		}
	}
}
