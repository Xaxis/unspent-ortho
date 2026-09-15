class_name MobFx
## Hit feel in the world: knock dust, impact sparks, a plate ring, the swing's
## smear. Small solid shapes that grow, travel and shrink away, never alpha,
## so they stay on the pixel grid and in the palette. Each frees itself.
##
## Dust is lit by the sky (it is only ground thrown up); sparks and smears are
## light, so they are drawn unshaded.

const _LIT := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://src/render/sky.gdshaderinc"
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() { ALBEDO = sky_apply(COLOR.rgb, wp, TIME); }
"""
const _GLOW := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
void fragment() { ALBEDO = COLOR.rgb; }
"""

## A shot's held moment: effects are advanced a little and then stop where they are.
static var hold := false
static var _lit_mat: ShaderMaterial
static var _glow_mat: ShaderMaterial


static func lit_material() -> ShaderMaterial:
	if _lit_mat == null:
		var s := Shader.new()
		s.code = _LIT
		_lit_mat = ShaderMaterial.new()
		_lit_mat.shader = s
	return _lit_mat


static func glow_material() -> ShaderMaterial:
	if _glow_mat == null:
		var s := Shader.new()
		s.code = _GLOW
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = s
	return _glow_mat


static func _keep(tw: Tween, seconds: float) -> void:
	if hold:
		tw.custom_step(seconds)
		tw.pause()


static func _piece(parent: Node, col: Color, glow: bool) -> MeshInstance3D:
	var k := MeshKit.new()
	k.box(Vector3(-0.5, -0.5, -0.5), Vector3(0.5, 0.5, 0.5), col, col.lightened(0.12), true)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = glow_material() if glow else lit_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Dust kicked up at the feet, blown along `dir` (tile space). `seed_value` varies the shape.
static func puff(parent: Node, at: Vector3, dir: Vector2, col: Color, count: int = 4, size: float = 0.16, seed_value: int = 0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	for i in count:
		var h := Rng.hash01(seed_value, i, 3)
		var h2 := Rng.hash01(seed_value, i, 7)
		var shade := col.darkened(0.12) if i % 2 == 0 else col.lightened(0.06)
		var mi := _piece(parent, shade, false)
		var s := size * (0.7 + h * 0.6)
		var spread := Vector2.from_angle(h2 * TAU) * 0.18
		mi.position = at + Vector3(spread.x, 0.06 + h * 0.08, spread.y)
		mi.scale = Vector3.ONE * s * 0.4
		mi.rotation = Vector3(h * 2.0, h2 * 3.0, 0.0)
		var travel := Vector3(d.x + spread.x * 2.0, 0.0, d.y + spread.y * 2.0) * (0.35 + h * 0.3)
		var t := 0.30 + h2 * 0.18
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", mi.position + travel + Vector3(0, 0.22 + h * 0.2, 0), t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(mi, "scale", Vector3.ONE * s, t * 0.35).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(mi, "scale", Vector3.ONE * 0.001, t * 0.65).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
		_keep(tw, t * 0.3)


## Streaks thrown out from a struck point. Warm for a blow that reached, cold for plate.
static func spark(parent: Node, at: Vector3, cols: Array[Color], count: int = 6, length: float = 0.35, seed_value: int = 0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	for i in count:
		var h := Rng.hash01(seed_value, i, 11)
		var a := float(i) / count * TAU + h * 0.6
		var up := (Rng.hash01(seed_value, i, 13) - 0.3) * 1.2
		var dir := Vector3(cos(a), up, sin(a)).normalized()
		var mi := _piece(parent, cols[i % cols.size()], true)
		var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		mi.transform = Transform3D(basis.scaled(Vector3(0.045, 0.045, length * (0.6 + h * 0.6))), at + dir * 0.12)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", at + dir * (0.45 + h * 0.3), 0.11).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(0.01, 0.01, 0.02), 0.11).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
		_keep(tw, 0.04)


## The swing's smear: a thin fan of light across the blow box, bright on the
## side the swing ends. Built once per blow; the player shows and sweeps it.
static func smear_mesh(reach: float, width: float, col: Color) -> ArrayMesh:
	var r := reach
	var spread := clampf(atan2(width * 0.5, maxf(0.3, r)) * 1.6, 0.6, 1.5)
	var k := MeshKit.new()
	var steps := 9
	for i in steps:
		var a0 := lerpf(-spread, spread, float(i) / steps)
		var a1 := lerpf(-spread, spread, float(i + 1) / steps)
		var f := float(i + 1) / steps
		# A crescent that thickens toward the end of the swing: a slash, not a fan.
		var inner := r * lerpf(0.92, 0.7, f)
		var thick := 0.015 + 0.03 * f
		var c := col if i >= steps - 4 else col.darkened(0.4 * (1.0 - f))
		var p0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		var q0 := Vector3(cos(a0) * inner, 0.0, sin(a0) * inner)
		var q1 := Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)
		k.quad(q0 + Vector3(0, thick, 0), p0 + Vector3(0, thick, 0), p1 + Vector3(0, thick, 0), q1 + Vector3(0, thick, 0), c)
		k.quad(p0, p1, p1 + Vector3(0, thick * 2.0, 0), p0 + Vector3(0, thick * 2.0, 0), c.lightened(0.1))
	return k.build()


## A flat ring spreading on the ground: a charge setting off, a body landing, water closing.
static func ring(parent: Node, at: Vector3, col: Color, radius: float = 0.8, seconds: float = 0.3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var k := MeshKit.new()
	var n := 12
	for i in n:
		var a0 := float(i) / n * TAU
		var a1 := float(i + 1) / n * TAU
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		k.quad(o0 * 0.82, o0, o1, o1 * 0.82, col)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = lit_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = at + Vector3(0, 0.03, 0)
	mi.scale = Vector3(radius * 0.3, 1, radius * 0.3)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), seconds).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)
	_keep(tw, seconds * 0.4)
