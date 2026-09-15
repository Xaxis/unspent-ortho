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

const _MARKS := """

// A short ink burst: tapered strokes thrown out from the point, a paper star at
// its heart for the first instant.
vec4 burst(vec2 p, float pw, float pr) {
	float r = length(p);
	float core_r = mix(0.46, 0.0, clamp(pr / 0.6, 0.0, 1.0));
	if (core_r > 0.0) {
		float a = atan(p.y, p.x) + seed;
		// Four points, pinched between: a drawn star, not a disc.
		float star = core_r * (0.45 + 0.55 * pow(abs(cos(a * 2.0)), 3.0));
		if (r < star) {
			return vec4(sky_apply(col_a, wp, TIME), 1.0);
		}
		if (r < star + pw * 1.2) {
			return vec4(sky_apply(ink_col, wp, TIME), 1.0);
		}
	}
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float h = ink_hash(vec2(seed * 13.1 + fi, 3.7));
		float ang = fi / 7.0 * TAU + seed + (h - 0.5) * 0.7;
		vec2 d = vec2(cos(ang), sin(ang));
		float len = 0.65 + 0.35 * ink_hash(vec2(fi, seed * 7.3));
		float r0 = mix(0.16, 0.8, pr) * len;
		float r1 = mix(0.42, 1.0, sqrt(pr)) * len;
		float along = dot(p, d);
		if (along < r0 || along > r1) {
			continue;
		}
		float k = (along - r0) / max(r1 - r0, 1e-4);
		float thick = mix(2.2, 0.55, k) * (1.0 - pr * 0.5) * pw;
		if (abs(dot(p, vec2(-d.y, d.x))) < thick) {
			return vec4(sky_apply(ink_col, wp, TIME), 1.0);
		}
	}
	return vec4(0.0);
}

// Dust as a drawn puff: a scalloped contour, inked on the side away from the
// light and paper on the lit side, stippled inside; the line breaks up and the
// dots thin as it settles.
vec4 puff(vec2 p, vec2 px, float pw, float pr) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float R = mix(0.55, 0.95, 1.0 - (1.0 - pr) * (1.0 - pr));
	float lobe = abs(sin(a * 2.5 + seed * 3.0));
	float edge = R * (0.78 + 0.22 * sqrt(lobe));
	float shade = dot(p / max(r, 1e-4), vec2(0.7071, 0.7071));
	float fade = 1.0 - pr;
	if (abs(r - edge) < pw * 0.6) {
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
	if (h > (0.1 + 0.3 * max(shade, 0.0)) * fade) {
		return vec4(0.0);
	}
	return vec4(sky_apply(shade > 0.25 ? col_b : col_a, wp, TIME), 1.0);
}

// A dashed ink ring spreading on the ground; the dashes drop out as it goes.
vec4 ring(vec2 p, float pr) {
	float r = length(p);
	float pw = fwidth(r);
	float R = mix(0.3, 1.0, 1.0 - (1.0 - pr) * (1.0 - pr));
	if (abs(r - R) > pw * 0.75) {
		return vec4(0.0);
	}
	float seg = floor((atan(p.y, p.x) / TAU + 0.5) * 14.0);
	if (mod(seg, 2.0) > 0.5 || ink_hash(vec2(seg, seed)) < pr * 0.95) {
		return vec4(0.0);
	}
	return vec4(sky_apply(col_a, wp, TIME), 1.0);
}

// Plate: the pen's sound marks, (( )), and two or three cold bright pixels.
vec4 clang(vec2 p, float pw, float pr) {
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float ang = seed * 2.0 + fi * 2.1 + ink_hash(vec2(fi, seed)) * 0.8;
		vec2 at = vec2(cos(ang), sin(ang)) * mix(0.1, 0.9, sqrt(pr));
		vec2 d = abs(p - at);
		if (pr < 0.85 && max(d.x, d.y) < pw * (i == 0 ? 1.0 : 0.5)) {
			return vec4(col_b, 1.0);
		}
	}
	float r = length(p);
	float a = atan(p.y, p.x);
	for (int s = 0; s < 2; s++) {
		float base = s == 0 ? 0.0 : 3.14159;
		float off = abs(mod(a - base + 3.14159, TAU) - 3.14159);
		if (off > 0.62) {
			continue;
		}
		for (int j = 0; j < 2; j++) {
			float R = mix(0.34, 0.58, pr) + float(j) * 0.2;
			if (abs(r - R) < pw * 0.7 && pr < 0.9 - float(j) * 0.2) {
				return vec4(sky_apply(ink_col, wp, TIME), 1.0);
			}
		}
	}
	return vec4(0.0);
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

// A tell: three short strokes flicked up off a body about to strike, the way a
// pen draws "about to". They grow out quickly and hold, then break away.
vec4 tell(vec2 p, float pw, float pr) {
	float grow = clamp(pr / 0.25, 0.0, 1.0);
	for (int i = 0; i < 3; i++) {
		float ang = (float(i) - 1.0) * 0.62;
		// Up the screen is -y in UV.
		vec2 d = vec2(sin(ang), -cos(ang));
		float r0 = 0.3;
		float r1 = r0 + (i == 1 ? 0.62 : 0.46) * grow;
		float along = dot(p, d);
		if (along < r0 || along > r1) {
			continue;
		}
		if (pr > 0.75 && ink_hash(vec2(float(i), floor(along / pw / 2.0) + seed)) < (pr - 0.75) * 4.0) {
			continue;
		}
		float k = (along - r0) / max(r1 - r0, 1e-4);
		if (abs(dot(p, vec2(-d.y, d.x))) < mix(1.4, 0.6, k) * pw) {
			return vec4(sky_apply(ink_col, wp, TIME), 1.0);
		}
	}
	return vec4(0.0);
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
	if (o.a < 0.5) {
		discard;
	}
	ALBEDO = o.rgb;
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
	// The stroke swells toward its head, from the outer edge in.
	if (v < 1.0 - (0.2 + 0.8 * k)) {
		discard;
	}
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	float pu = max(fwidth(u), 1e-5);
	float pv = max(fwidth(v), 1e-5);
	float inner = 1.0 - (0.2 + 0.8 * k);
	bool edge = v > 1.0 - pv * 1.3 || v < inner + pv * 1.3 || head - u < pu * 1.3;
	vec3 c = paper_col;
	if (edge && k > 0.25) {
		c = ink_col;
	} else if (k < 0.5) {
		// The trailing half breaks into the hand's strokes.
		if (mod(px.x - px.y, 3.0) > 0.5) {
			discard;
		}
		c = k < 0.25 ? ink_col : paper_col;
	}
	ALBEDO = sky_apply(c, wp, TIME);
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
	match key:
		&"over":
			s.code = "shader_type spatial;\n" + (_COMMON % ", depth_test_disabled") + _BILLBOARD + _MARKS
		&"billboard":
			s.code = "shader_type spatial;\n" + (_COMMON % "") + _BILLBOARD + _MARKS
		&"flat":
			s.code = "shader_type spatial;\n" + (_COMMON % "") + _FLAT + _MARKS
		&"swing":
			s.code = _SWING
		_:
			s.code = _FLASH
	_shaders[key] = s
	return s


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## One mark on a quad. `shader`: over (drawn over bodies), billboard (faces the
## camera, hidden behind bodies), flat (lies on the ground).
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
	mat.set_shader_parameter(&"progress", 0.0)
	# Marks draw after the land and bodies they sit on.
	mat.render_priority = 4
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


## Where a blow landed: a burst of ink strokes over whatever was struck. An
## `accent` other than transparent adds two or three pixels of that light.
static func burst(parent: Node, at: Vector3, size: float = 0.9, seed_value: int = 0, accent: Color = Color(0, 0, 0, 0)) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, size, BURST, &"over", seed_value, Palette.LINEN[5], Palette.LINEN[5]), 0.13)
	if accent.a > 0.0:
		glint(parent, at + Vector3(0, 0.05, 0), accent, seed_value + 5, 0.4)


## Dust thrown up at the feet and drifting along `dir` (tile space).
static func puff(parent: Node, at: Vector3, dir: Vector2, dust: Color, size: float = 0.6, seed_value: int = 0) -> void:
	if not _ok(parent):
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	var lift := Vector3(0, size * 0.35, 0)
	var mi := _mark(parent, at + lift, size, PUFF, &"billboard", seed_value, dust, dust.darkened(0.35))
	var t := 0.34 + Rng.hash01(seed_value, 1, 2) * 0.12
	_run(mi, t, Vector3(d.x, 0.0, d.y) * size * 0.9 + Vector3(0, size * 0.3, 0))


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
	_run(_mark(parent, at + Vector3(0, 0.04, 0), radius * 2.0, RING, &"flat", int(at.x * 13.0 + at.z * 7.0), col, col), seconds)


## A blow that rang off plate: sound marks and a few cold bright pixels.
static func clang(parent: Node, at: Vector3, seed_value: int = 0) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, 1.0, CLANG, &"over", seed_value, Palette.COLD[3], Palette.COLD[3]), 0.16)


## A small plus of light shrinking to a pixel: a lens catching the light, a part flaring.
static func glint(parent: Node, at: Vector3, col: Color, seed_value: int = 0, size: float = 0.5) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, size, GLINT, &"over", seed_value, col, col.lightened(0.5)), 0.16)


## Flicked strokes over a body whose blow is coming: held for `seconds` (its windup).
static func tell(parent: Node, at: Vector3, seconds: float, seed_value: int = 0, size: float = 0.9) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, size, TELL, &"over", seed_value, Palette.INK[0], Palette.INK[0]), maxf(0.12, seconds))


## Compile every mark's shader before the first blow needs it, so the first hit
## of a game is not also its first hitch. Each draws nothing and frees itself.
static func warm(parent: Node, at: Vector3) -> void:
	if not _ok(parent):
		return
	for key: StringName in [&"over", &"billboard", &"flat"]:
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
	var spread := clampf(atan2(width * 0.5, maxf(0.3, reach)) * 1.5, 0.6, 1.5)
	var inner := reach * 0.55
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
	mat.render_priority = 4
	return mat


## Paper-white over every drawn part of a body while `on` (skips glow cards,
## which are not ArrayMeshes, so a halo never flashes as a square).
## MultiMesh parts (a flock's shards) flash too.
static func set_flash(root: Node, on: bool) -> void:
	if root == null:
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
		var drawn := mi == null or mi.mesh is ArrayMesh
		if drawn:
			# The body's own material is set aside for the flash and put back after.
			# (An overlay pass would be kinder, but the Compatibility renderer draws none.)
			if on and not gi.has_meta(&"unflashed"):
				gi.set_meta(&"unflashed", gi.material_override)
				gi.material_override = _flash_mat
			elif not on and gi.has_meta(&"unflashed"):
				gi.material_override = gi.get_meta(&"unflashed") as Material
				gi.remove_meta(&"unflashed")
	for c in n.get_children():
		_flash_under(c, on)
