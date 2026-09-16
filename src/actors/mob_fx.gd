class_name MobFx
## Hit feel drawn into the notebook (docs/ART.md §7): a short ink burst where a
## blow lands, dust as stipple puffs, a plate's ring as a pen's sound marks and
## two or three bright pixels, a dashed ink ring on the ground, the swing's
## stroke, and a paper-white flash on a struck body. No particles that look like
## a physics engine: every mark is drawn in whole screen pixels by a shader on a
## single quad, and its patterns are pinned to the world through `world_px`.
##
## Ink and dust are tinted by the sky like the page they sit on; sparks and
## glints are light, so they are not. Each mark frees itself.

const _COMMON := """
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled%s;
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform int mode = 0;
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform vec3 col_a = vec3(0.91, 0.86, 0.75);
uniform vec3 col_b = vec3(0.71, 0.86, 0.93);
uniform vec3 ink_col = vec3(0.031, 0.027, 0.059);
uniform vec3 paper_col = vec3(0.91, 0.86, 0.75);
uniform vec2 dir = vec2(1.0, 0.0);
varying vec3 wp;
"""

const _BILLBOARD := """
void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2] * s.z, MODEL_MATRIX[3]);
	wp = MODEL_MATRIX[3].xyz;
}
"""

const _FLAT := """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
"""

## Every width below is in whole screen pixels (`pw` is one pixel in quad units),
## so a mark reads the same at the camera players get as in a close shot.
const _MARKS := """

vec4 ink_out() {
	return vec4(sky_apply(ink_col, wp, TIME), 1.0);
}

// The page under a mark: tinted by the sky, but held up a little so a mark still
// reads as drawn on paper where the land has gone dark.
vec4 paper_out() {
	return vec4(mix(sky_apply(paper_col, wp, TIME), paper_col, 0.4), 1.0);
}

// Ink where e < 0 (e: pixels outside the stroke), a paper edge `halo` pixels
// round it, nothing beyond.
vec4 inked(float e, float halo) {
	if (e < 0.0) {
		return ink_out();
	}
	if (e < halo) {
		return paper_out();
	}
	return vec4(0.0);
}

// Pixels outside a round-ended stroke from a to b (pixel space), half width hw.
float stroke(vec2 q, vec2 a, vec2 b, float hw) {
	vec2 ab = b - a;
	float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(q - (a + ab * t)) - hw;
}

// A short ink burst: tapered strokes thrown OUT from the point, and nothing at
// all at its heart. What a burst is for is to prove where the blow landed, so it
// must not be the thing standing in front of it: the amber working part shows
// through the middle of its own hit mark. Hence OPEN — the fraction of the
// radius that never takes ink — and hence no filled star. (docs/ART.md §7: a
// short ink burst, sparks off plate as two or three bright pixels.)
vec4 burst(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw;
	float e = 1e5;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float h = ink_hash(vec2(seed * 13.1 + fi, 3.7));
		float ang = fi / 7.0 * TAU + seed + (h - 0.5) * 0.7;
		vec2 d = vec2(cos(ang), sin(ang));
		float len = 0.72 + 0.28 * ink_hash(vec2(fi, seed * 7.3));
		float r0 = mix(OPEN, 0.84, pr) * len * (R - 2.0);
		float r1 = mix(OPEN + 0.34, 1.0, sqrt(pr)) * len * (R - 2.0);
		float along = dot(q, d);
		float k = clamp((along - r0) / max(r1 - r0, 1e-4), 0.0, 1.0);
		float hw = mix(1.2, 0.5, k) * (1.0 - pr * 0.3);
		e = min(e, stroke(q, d * r0, d * r1, hw));
	}
	return inked(e, 1.0);
}

// Dust as a drawn puff: a scalloped contour, inked on the side away from the
// light and paper on the lit side, stippled inside; the line breaks up and the
// dots thin as it settles.
vec4 puff(vec2 p, vec2 px, float pw, float pr) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float R = mix(0.55, 0.92, 1.0 - (1.0 - pr) * (1.0 - pr));
	float lobe = abs(sin(a * 2.5 + seed * 3.0));
	float edge = R * (0.78 + 0.22 * sqrt(lobe));
	float shade = dot(p / max(r, 1e-4), vec2(0.7071, 0.7071));
	float fade = 1.0 - pr;
	if (abs(r - edge) < pw * 0.75) {
		// Dashes fall out of the contour as it goes, starting on the lit side.
		float seg = floor((a / TAU + 0.5) * 18.0);
		if (ink_hash(vec2(seg, seed)) < pr * 1.1 - shade * 0.3) {
			return vec4(0.0);
		}
		return vec4(sky_apply(shade > -0.1 ? ink_col : col_a, wp, TIME), 1.0);
	}
	if (r > edge) {
		return vec4(0.0);
	}
	if (mod(px.x + px.y, 2.0) > 0.5) {
		return vec4(0.0);
	}
	float h = ink_hash(px + vec2(seed * 31.0, seed * 17.0));
	if (h > (0.12 + 0.3 * max(shade, 0.0)) * fade) {
		return vec4(0.0);
	}
	return vec4(sky_apply(shade > 0.25 ? col_b : col_a, wp, TIME), 1.0);
}

// A dashed ink ring spreading on the ground, edged with the page so it reads on
// dark ground; the dashes drop out as it goes. Lying flat, its pixel size differs
// across and along, so widths come from the radius' own screen rate.
vec4 ring(vec2 p, float pr) {
	float r = length(p);
	float pw = max(fwidth(r), 1e-4);
	float R = mix(0.3, 1.0, 1.0 - (1.0 - pr) * (1.0 - pr)) - pw * 3.0;
	float seg = floor((atan(p.y, p.x) / TAU + 0.5) * 14.0);
	if (mod(seg, 2.0) > 0.5 || ink_hash(vec2(seg, seed)) < pr * 0.95) {
		return vec4(0.0);
	}
	return inked(abs(r - R) / pw - 1.0, 1.0);
}

// Plate: the pen's sound marks, (( )), and two or three cold bright pixels. The
// arcs stand OUTSIDE the plate they rang off, and the sparks are pixels, not
// blobs: this mark says "that was armour", it does not hide the armour.
vec4 clang(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw - 2.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float ang = seed * 2.0 + fi * 2.1 + ink_hash(vec2(fi, seed)) * 0.8;
		vec2 at = vec2(cos(ang), sin(ang)) * mix(OPEN, 0.9, sqrt(pr)) * R;
		vec2 d = abs(q - at);
		if (pr < 0.85 && max(d.x, d.y) < (i == 0 ? 1.0 : 0.5)) {
			return vec4(col_b, 1.0);
		}
	}
	float r = length(q);
	float a = atan(q.y, q.x);
	float e = 1e5;
	for (int s = 0; s < 2; s++) {
		float base = s == 0 ? 0.0 : 3.14159;
		float off = abs(mod(a - base + 3.14159, TAU) - 3.14159);
		if (off > 0.62) {
			continue;
		}
		for (int j = 0; j < 2; j++) {
			if (pr > 0.9 - float(j) * 0.2) {
				continue;
			}
			float Rj = (mix(OPEN + 0.06, 0.78, pr) + float(j) * 0.2) * R;
			e = min(e, abs(r - Rj) - 0.7);
		}
	}
	return inked(e, 1.0);
}

// A glint: a small plus of light that shrinks to one pixel.
vec4 glint(vec2 p, float pw, float pr) {
	vec2 d = abs(p) / pw;
	float arm = floor(mix(3.0, 0.0, pr));
	if ((d.x < 0.5 && d.y < arm + 0.5) || (d.y < 0.5 && d.x < arm + 0.5)) {
		return vec4(d.x < 0.5 && d.y < 0.5 ? col_b : col_a, 1.0);
	}
	return vec4(0.0);
}

// A tell: three short strokes flicked along `dir`, the way a pen draws "about
// to": a fan that does not meet at its root (joined, it reads as an arrow). On a
// scrap of page of their own so they read over any ground. They spring out
// quickly and hold, then break away.
//
// `dir` is which way the fan flicks, in quad space (up the screen is -y). It
// exists so the tell can be aimed: over a body it flicks up, and over a
// MACHINE'S WORKING PART it flicks DOWN at it. A windup has to send the eye to
// the side that opens — the side that hurts you and the side you must hit —
// and three ticks floating above the hull sent it to the roof instead.
vec4 tell(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw;
	float grow = clamp(pr / 0.18, 0.0, 1.0);
	vec2 f = normalize(dir);
	vec2 n = vec2(-f.y, f.x);
	// The fan's root is off the quad, behind the flick.
	vec2 root = -f * 1.05 * R;
	float e = 1e5;
	for (int i = 0; i < 3; i++) {
		float ang = (float(i) - 1.0) * 0.72;
		vec2 d = f * cos(ang) + n * sin(ang);
		float r0 = (i == 1 ? 0.95 : 0.85) * R;
		float r1 = r0 + (i == 1 ? 0.8 : 0.6) * R * mix(0.4, 1.0, grow) - 3.0;
		if (pr > 0.8 && ink_hash(vec2(float(i), seed)) < (pr - 0.8) * 5.0) {
			continue;
		}
		// Heavier where the pen came down, lifting off at the far end.
		vec2 a = root + d * r0;
		vec2 b = root + d * r1;
		float t = clamp(dot(q - a, b - a) / max(dot(b - a, b - a), 1e-4), 0.0, 1.0);
		e = min(e, length(q - mix(a, b, t)) - mix(1.7, 0.6, t * t));
	}
	return inked(e, 1.0);
}

// Speed lines: three parallel ink dashes left behind a body that has just shot
// away along `dir` (screen, UV space), the middle one longest, with clear gaps
// between. They slide back and thin.
vec4 streak(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw - 2.0;
	vec2 d = normalize(dir);
	vec2 n = vec2(-d.y, d.x);
	float e = 1e5;
	for (int i = 0; i < 3; i++) {
		float fi = float(i) - 1.0;
		float len = (i == 1 ? 1.2 : 0.8) * R * (1.0 - pr * 0.5);
		// Laid out ahead of the quad's centre along dir and slid back as they go.
		float head = R * 0.9 - abs(fi) * R * 0.2 - pr * R * 0.4;
		vec2 a = d * head + n * fi * 5.0;
		vec2 b = d * (head - len) + n * fi * 5.0;
		// Full at the head, where the body was, drawn off to a point behind.
		vec2 ab = b - a;
		float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
		float hw = mix(1.3, 0.35, t) * (pr < 0.55 ? 1.0 : 0.6);
		e = min(e, length(q - (a + ab * t)) - hw);
	}
	return inked(e, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	float pw = max(fwidth(p.x), 1e-4);
	float pr = clamp(progress, 0.0, 1.0);
	vec4 o = vec4(0.0);
	if (mode == 0) { o = burst(p, pw, pr); }
	else if (mode == 1) { o = puff(p, px, pw, pr); }
	else if (mode == 2) { o = ring(p, pr); }
	else if (mode == 3) { o = clang(p, pw, pr); }
	else if (mode == 4) { o = glint(p, pw, pr); }
	else if (mode == 5) { o = tell(p, pw, pr); }
	else if (mode == 6) { o = streak(p, pw, pr); }
	if (o.a < 0.5) {
		discard;
	}
	ALBEDO = o.rgb;
	// In the transparent pass, after the ink outline has been laid over the
	// frame, so a mark sits on top of the page and is never drawn over by it.
	ALPHA = 1.0;
}
"""

## The swing's stroke over an arc mesh: u runs along the swing, v across it.
const _SWING := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform float head = 1.0;
uniform float tail = 0.7;
uniform vec3 paper_col = vec3(0.91, 0.86, 0.75);
uniform vec3 ink_col = vec3(0.031, 0.027, 0.059);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float from = head - tail;
	if (u > head || u < from) {
		discard;
	}
	float k = (u - from) / max(tail, 1e-4);
	// A crescent: full at the head, thinning to a hairline at the tail, from the
	// outer edge in.
	float inner = 1.0 - (0.15 + 0.85 * sqrt(k));
	if (v < inner) {
		discard;
	}
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	float pu = max(fwidth(u), 1e-5);
	float pv = max(fwidth(v), 1e-5);
	// Two whole pixels of ink on every edge, whatever the camera's distance.
	bool edge = v > 1.0 - pv * 2.0 || v < inner + pv * 2.0 || head - u < pu * 2.0;
	bool paper = !edge;
	// Only the leading hand's width fills with paper. Behind it the stroke breaks
	// into the hand's own lines, so a swing landing on a machine is a drawn arc
	// over it and not a solid wedge across it (docs/ART.md §7).
	if (!edge && k < 0.86) {
		if (mod(floor(v / pv), k < 0.45 ? 3.0 : 2.0) > 0.5) {
			discard;
		}
		paper = false;
	}
	vec3 c = paper ? paper_col : ink_col;
	vec3 lit = sky_apply(c, wp, TIME);
	ALBEDO = paper ? mix(lit, paper_col, 0.4) : lit;
	ALPHA = 1.0;
}
"""

const _FLASH := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
uniform vec3 col = vec3(0.91, 0.86, 0.75);
void fragment() {
	ALBEDO = col;
}
"""

const BURST := 0
const PUFF := 1
const RING := 2
const CLANG := 3
const GLINT := 4
const TELL := 5
const STREAK := 6

## World units per screen pixel of the 640x360 image (the fight system keeps it
## to the camera's). Marks are never smaller on screen than their *_PX sizes.
static var texel := 14.0 / 360.0
## Smallest on-screen size, in pixels, of each mark (its quad's full width).
## A hit mark has to be read at a glance and then be gone; it must never be the
## biggest thing in the frame, and it must never be the thing standing in front
## of what it proves (docs/ART.md §7: a SHORT ink burst, sparks as two or three
## bright pixels). The burst and the plate ring came in at 30 px with a filled
## paper star at the heart, which put an opaque disc over the amber working part
## at the exact moment the player needed to see it.
const BURST_PX := 22.0
const PUFF_PX := 16.0
const RING_PX := 22.0
const CLANG_PX := 20.0
const GLINT_PX := 9.0
const TELL_PX := 26.0
const STREAK_PX := 40.0
## The fraction of a burst's (and a plate ring's) radius that never takes ink, so
## what was struck shows through the middle of its own mark. Compiled into the
## shader as OPEN and measured against the machines' parts in
## tests/actors/test_hit_marks.gd.
const BURST_OPEN := 0.52
## Which way a tell's fan flicks, in quad space: up the screen over a body, down
## the screen when it is aimed at a working part below it.
const FLICK_UP := Vector2(0.0, -1.0)
const FLICK_DOWN := Vector2(0.0, 1.0)
const MARK_PRIORITY := 12
## A shot's held moment: marks are advanced a little and then stop where they are.
static var hold := false
## How far into its life a held mark is stopped (0..1).
static var hold_at := 0.3
static var _shaders: Dictionary = {}
static var _flash_mat: ShaderMaterial
static var _quad: QuadMesh


static func _shader(key: StringName) -> Shader:
	if _shaders.has(key):
		return _shaders[key]
	var s := Shader.new()
	# One number for the open heart of a mark, in the shader and in the test.
	var open := "#define OPEN %0.4f\n" % BURST_OPEN
	match key:
		&"over":
			s.code = "shader_type spatial;\n" + (_COMMON % ", depth_test_disabled") + open + _BILLBOARD + _MARKS
		&"flat":
			s.code = "shader_type spatial;\n" + (_COMMON % ", depth_test_disabled") + open + _FLAT + _MARKS
		&"swing":
			s.code = _SWING
		_:
			s.code = _FLASH
	_shaders[key] = s
	return s


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## One mark on a quad. `shader`: over (faces the camera) or flat (lies on the
## ground). Neither is hidden by what it is drawn on: the land's contours stand
## a little proud of a tile's level, and a depth-tested mark sank into them.
static func _mark(parent: Node, at: Vector3, size: float, mode: int, shader: StringName, seed_value: int, a: Color, b: Color) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = _shader(shader)
	mat.set_shader_parameter(&"mode", mode)
	mat.set_shader_parameter(&"seed", float(posmod(seed_value, 997)) * 0.731)
	mat.set_shader_parameter(&"col_a", _v3(a))
	mat.set_shader_parameter(&"col_b", _v3(b))
	mat.set_shader_parameter(&"ink_col", _v3(Palette.INK[0]))
	mat.set_shader_parameter(&"paper_col", _v3(Palette.LINEN[5]))
	mat.set_shader_parameter(&"progress", 0.0)
	# Marks draw after the land, the bodies and a part's light (priority 10): a
	# burst is the thing to read at the moment of a hit, and a flare swallowed it.
	mat.render_priority = MARK_PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * size * 0.5
	if shader == &"flat":
		mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	return mi


static func _run(mi: MeshInstance3D, seconds: float, travel: Vector3 = Vector3.ZERO) -> void:
	var mat := mi.material_override as ShaderMaterial
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"progress", t), 0.0, 1.0, seconds)
	if travel != Vector3.ZERO:
		tw.tween_property(mi, "global_position", mi.global_position + travel, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(mi.queue_free)
	if hold:
		tw.custom_step(seconds * hold_at)
		tw.pause()


static func _ok(parent: Node) -> bool:
	return parent != null and parent.is_inside_tree()


## `size` world units, or `min_px` screen pixels if that is larger.
static func at_least(size: float, min_px: float) -> float:
	return maxf(size, min_px * texel)


## World units covered by `n` screen pixels.
static func px(n: float) -> float:
	return n * texel


## Screen pixels at the heart of a burst that never take ink, at the moment of
## the blow. What was struck has to show through: the burst proves the hit, the
## part proves where to hit.
static func burst_clear_px(size: float = 0.9) -> float:
	return at_least(size, BURST_PX) / maxf(texel, 1e-5) * 0.5 * BURST_OPEN


## Where a blow landed: a burst of ink strokes over whatever was struck. An
## `accent` other than transparent adds two or three pixels of that light.
static func burst(parent: Node, at: Vector3, size: float = 0.9, seed_value: int = 0, accent: Color = Color(0, 0, 0, 0)) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, at_least(size, BURST_PX), BURST, &"over", seed_value, Palette.LINEN[5], Palette.LINEN[5]), 0.16)
	if accent.a > 0.0:
		glint(parent, at + Vector3(0, 0.05, 0), accent, seed_value + 5, 0.4)


## Dust thrown up at the feet and drifting along `dir` (tile space).
static func puff(parent: Node, at: Vector3, dir: Vector2, dust: Color, size: float = 0.6, seed_value: int = 0) -> void:
	if not _ok(parent):
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	size = at_least(size, PUFF_PX)
	var lift := Vector3(0, size * 0.35, 0)
	var mi := _mark(parent, at + lift, size, PUFF, &"over", seed_value, dust, dust.darkened(0.35))
	var t := 0.34 + Rng.hash01(seed_value, 1, 2) * 0.12
	_run(mi, t, Vector3(d.x, 0.0, d.y) * size * 0.9 + Vector3(0, size * 0.3, 0))


## A slow breath of pale steam and ash off a vent: a puff that rises and thins
## over `seconds`, drifting with the wind.
static func breath(parent: Node, at: Vector3, col: Color, size: float, seconds: float, drift: Vector2, seed_value: int) -> void:
	if not _ok(parent):
		return
	size = at_least(size, PUFF_PX)
	var mi := _mark(parent, at, size, PUFF, &"over", seed_value, col, col.darkened(0.2))
	_run(mi, seconds, Vector3(drift.x, size * 1.6, drift.y))


## Several puffs about a point, for a body landing or a charge setting off.
static func puffs(parent: Node, at: Vector3, dir: Vector2, dust: Color, count: int, size: float, seed_value: int) -> void:
	for i in count:
		var a := Rng.hash01(seed_value, i, 9) * TAU
		var r := size * (0.25 + Rng.hash01(seed_value, i, 10) * 0.45)
		var off := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var spread := dir + Vector2(off.x, off.z) * 0.8
		puff(parent, at + off, spread, dust, size * (0.7 + Rng.hash01(seed_value, i, 11) * 0.5), seed_value * 7 + i)


## A dashed ink ring spreading on the ground.
static func ring(parent: Node, at: Vector3, col: Color, radius: float = 0.8, seconds: float = 0.3) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at + Vector3(0, 0.04, 0), at_least(radius * 2.0, RING_PX), RING, &"flat", int(at.x * 13.0 + at.z * 7.0), col, col), seconds)


## A blow that rang off plate: sound marks and a few cold bright pixels.
static func clang(parent: Node, at: Vector3, seed_value: int = 0) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, at_least(1.0, CLANG_PX), CLANG, &"over", seed_value, Palette.COLD[3], Palette.COLD[3]), 0.2)


## A small plus of light shrinking to a pixel: a lens catching the light, a part flaring.
static func glint(parent: Node, at: Vector3, col: Color, seed_value: int = 0, size: float = 0.5) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, at_least(size, GLINT_PX), GLINT, &"over", seed_value, col, col.lightened(0.5)), 0.16)


## Flicked strokes for a blow that is coming: held for `seconds` (its windup).
## `anchor` is the thing being marked, in the world; the fan stands clear of it
## on screen (`up`: the camera's up vector) so it is never lost in a silhouette.
##
## `flick` says which way the strokes are thrown. FLICK_UP puts the fan above a
## body and throws it up and away — "about to". FLICK_DOWN puts the fan above the
## thing and throws it DOWN at it — "here, this one" — which is what a machine's
## windup wants: the player must look at the side that opens, not at the roof.
static func tell(parent: Node, anchor: Vector3, up: Vector3, seconds: float, seed_value: int = 0, size: float = 0.9, flick: Vector2 = FLICK_UP) -> void:
	if not _ok(parent):
		return
	size = at_least(size, TELL_PX)
	# Aimed down, the whole quad stands above the thing it points at; aimed up,
	# the fan's near ends are 0.45 of the half size below the quad's centre.
	# The fan's furthest tips are 0.4 of the half size from the quad's centre, so
	# aimed down it hangs a clear three pixels above the thing it points at: a
	# tell must send the eye to the part, never stand in front of it.
	var clear := (0.72 if flick == FLICK_DOWN else 0.45) * size * 0.5 + px(3.0)
	var mi := _mark(parent, anchor + up.normalized() * clear, size, TELL, &"over", seed_value, Palette.INK[0], Palette.INK[0])
	(mi.material_override as ShaderMaterial).set_shader_parameter(&"dir", flick)
	_run(mi, maxf(0.12, seconds))


## Speed lines left behind a body that shot off along `dir` (tile space) as a
## camera at `yaw_deg`/`pitch_deg` sees it. `at` is where the lines' heads
## are: they trail back from it, away from `dir`.
static func streak(parent: Node, at: Vector3, dir: Vector2, yaw_deg: float, pitch_deg: float, seed_value: int = 0, size: float = 1.1) -> void:
	if not _ok(parent) or dir.length() < 0.01:
		return
	size = at_least(size, STREAK_PX)
	var yaw := deg_to_rad(yaw_deg)
	var right := Vector2(cos(yaw), -sin(yaw))
	var up := Vector2(-sin(yaw), -cos(yaw))
	var d := dir.normalized()
	# UV y runs down the screen; the ground's up is foreshortened by the pitch.
	var screen := Vector2(d.dot(right), -d.dot(up) * sin(deg_to_rad(pitch_deg)))
	# The quad sits back along dir so the heads (drawn 0.9 of the way ahead in it) land on `at`.
	var back := 0.45 * size / maxf(0.2, screen.length())
	var mi := _mark(parent, at - Vector3(d.x, 0.0, d.y) * back, size, STREAK, &"over", seed_value, Palette.INK[0], Palette.INK[0])
	(mi.material_override as ShaderMaterial).set_shader_parameter(&"dir", screen.normalized())
	_run(mi, 0.2)


## Compile every mark's shader before the first blow needs it, so the first hit
## of a game is not also its first hitch. Each draws nothing and frees itself.
static func warm(parent: Node, at: Vector3) -> void:
	if not _ok(parent):
		return
	for key: StringName in [&"over", &"flat"]:
		var mi := _mark(parent, at, 0.5, BURST, key, 0, Palette.INK[0], Palette.INK[0])
		(mi.material_override as ShaderMaterial).set_shader_parameter(&"progress", 1.0)
		_free_after(mi, 0.25)
	var arc := MeshInstance3D.new()
	arc.mesh = swing_mesh(1.0, 1.0)
	var sm := swing_material()
	sm.set_shader_parameter(&"head", 0.0)
	sm.set_shader_parameter(&"tail", 0.0)
	arc.material_override = sm
	parent.add_child(arc)
	arc.global_position = at
	_free_after(arc, 0.25)
	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.01, 0.01)
	card.mesh = q
	card.material_override = _flash_material()
	parent.add_child(card)
	card.global_position = at - Vector3(0, 0.5, 0)
	_free_after(card, 0.25)


static func _free_after(n: Node, seconds: float) -> void:
	var tw := n.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(n.queue_free)


## The swing's arc: `reach` out from the body's centre, spread to cover `width`
## across. u runs from where the swing starts to where it ends; v from the
## inside of the stroke to its outer edge.
static func swing_mesh(reach: float, width: float) -> ArrayMesh:
	# Never a narrow flag: even a fist's sweep is drawn as a crescent a body wide.
	var spread := clampf(atan2(width * 0.5, maxf(0.3, reach)) * 1.5, 0.95, 1.5)
	reach = maxf(reach, 0.9)
	var inner := reach * 0.45
	var steps := 14
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in steps:
		var u0 := float(i) / steps
		var u1 := float(i + 1) / steps
		# From the right hand across to the left.
		var a0 := lerpf(spread, -spread, u0)
		var a1 := lerpf(spread, -spread, u1)
		var o0 := Vector3(cos(a0), 0.0, sin(a0))
		var o1 := Vector3(cos(a1), 0.0, sin(a1))
		verts.append_array([o0 * inner, o0 * reach, o1 * reach, o0 * inner, o1 * reach, o1 * inner])
		uvs.append_array([Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u0, 0), Vector2(u1, 1), Vector2(u1, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func swing_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(&"swing")
	mat.set_shader_parameter(&"paper_col", _v3(Palette.LINEN[5]))
	mat.set_shader_parameter(&"ink_col", _v3(Palette.INK[0]))
	mat.render_priority = MARK_PRIORITY
	return mat


## Paper-white over every drawn part of a body while `on` (skips glow cards,
## which are not ArrayMeshes, so a halo never flashes as a square, and
## shadow-only twins). MultiMesh parts (a flock's shards) flash too.
##
## A figure that can flash itself (`set_flash(on)`, a uniform in its own shader)
## is asked to. Otherwise each material_override is set aside and put back after;
## a figure that assigned its own material in between keeps what it assigned.
static func set_flash(root: Node, on: bool) -> void:
	if root == null:
		return
	if root.has_method(&"set_flash"):
		root.call(&"set_flash", on)
		return
	_flash_material()
	_flash_under(root, on)


static func _flash_material() -> ShaderMaterial:
	if _flash_mat == null:
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = _shader(&"flash")
		_flash_mat.set_shader_parameter(&"col", _v3(Palette.LINEN[5]))
	return _flash_mat


static func _flash_under(n: Node, on: bool) -> void:
	var gi := n as GeometryInstance3D
	if gi != null:
		var mi := n as MeshInstance3D
		var drawn := (mi == null or mi.mesh is ArrayMesh) and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if drawn:
			# (An overlay pass would be kinder, but the Compatibility renderer draws none.)
			if on and not gi.has_meta(&"unflashed"):
				gi.set_meta(&"unflashed", gi.material_override)
				gi.material_override = _flash_mat
			elif not on and gi.has_meta(&"unflashed"):
				# Put back only over our own flash: a material the figure chose since is its own.
				if gi.material_override == _flash_mat:
					gi.material_override = gi.get_meta(&"unflashed") as Material
				gi.remove_meta(&"unflashed")
	for c in n.get_children():
		_flash_under(c, on)
