class_name TrackMarks
extends Node3D
## The DRAWING of the marks a body leaves (the rule is TrackGround, the placement
## TrackPath, and 53_tracks ties them to the player).
##
## INTERIM, and it says so on purpose: prints belong in the ground's own material
## vocabulary eventually (the material rows and the wear-by-world-position of the
## lit world), so a print becomes the same kind of thing as rust in a bog rather
## than a separate object lying on top. Until then they are quads, because a quad
## works on both renderers and a Decal does not exist on gl_compatibility (the web).
##
## A mark is a DEPRESSION, not a sticker: each shape is a height field (a hollow and
## the rim it pushed up) turned into a normal map in code, so the real sun lights
## the rim facing it and shades the rim away from it, whatever the hour. No palette
## colour is used anywhere: the renderers read one a stop and a half apart (Forward+
## as linear light, gl_compatibility as it is), and black and white are the only
## values both agree on. So a mark is a black hollow let down to a little alpha,
## which darkens that ground's OWN colour, and lets its rim catch the light at the
## ground's roughness (a wet rim glints, dry ash does not). On a white ground (snow,
## salt) only the hollow is shaded: the pushed-up rim is as white as the ground it
## came from, and darkening it too drew a ring round every print. A white print lit
## by the sun was tried first and vanished into the snow: the land's own wash is
## not lit the way a StandardMaterial3D is, so white on white read as nothing.
##
## Every mark of one shape on one kind of ground is one MultiMesh: a few draw calls
## whatever the length of the trail. Each group keeps CAP marks and reuses the
## oldest slot, and says which slot it took so the caller can forget that mark.

const CAP := 160
## Size on the ground (world units), width across the heading and length along it.
const SIZE := {
	&"foot": Vector2(0.19, 0.38),
	&"scuff": Vector2(0.24, 0.6),
	&"flatten": Vector2(0.28, 0.42),
	&"rig": Vector2(0.78, 0.78),
	&"sweep": Vector2(1.15, 0.62),
}
## Texture size per shape (columns, rows): rows run along the heading.
const PIXELS := {
	&"foot": Vector2i(40, 84),
	&"scuff": Vector2i(32, 96),
	&"flatten": Vector2i(48, 72),
	&"rig": Vector2i(72, 72),
	&"sweep": Vector2i(96, 52),
}
## Just above the terrace, under anything standing on it.
const LIFT := 0.02

## key -> {mm: MultiMesh, next: int}
var _groups: Dictionary = {}
static var _textures: Dictionary = {}


## Lay a mark and answer [group key, slot]. `alpha` 0..1 is how plainly it reads.
func lay(shape: StringName, white: bool, rough: float, at: Vector3, angle: float, alpha: float) -> Array:
	var key := "%s|%s|%.2f" % [shape, "h" if white else "d", rough]
	var g: Dictionary = _groups.get(key, {})
	if g.is_empty():
		g = _group(key, shape, white, rough)
		_groups[key] = g
	var slot := int(g.next)
	g.next = (slot + 1) % CAP
	var mm: MultiMesh = g.mm
	var s: Vector2 = SIZE.get(shape, SIZE[&"foot"])
	# The plane's local +Z (the texture's rows) runs along the heading; tile space
	# (x, y) is world (x, z).
	var basis := Basis(Vector3.UP, PI * 0.5 - angle).scaled(Vector3(s.x, 1.0, s.y))
	mm.set_instance_transform(slot, Transform3D(basis, at + Vector3(0.0, LIFT, 0.0)))
	mm.set_instance_color(slot, Color(1.0, 1.0, 1.0, alpha))
	return [key, slot]


func fade(key: String, slot: int, alpha: float) -> void:
	var g: Dictionary = _groups.get(key, {})
	if g.is_empty():
		return
	(g.mm as MultiMesh).set_instance_color(slot, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))


func clear() -> void:
	for key: String in _groups:
		var mm: MultiMesh = _groups[key].mm
		for i in CAP:
			mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))


## Draw calls the marks take: one per group in use.
func groups() -> int:
	return _groups.size()


func _group(key: String, shape: StringName, white: bool, rough: float) -> Dictionary:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color.BLACK
	mat.vertex_color_use_as_albedo = true
	var tex: Array = textures(shape, white)
	mat.albedo_texture = tex[0]
	mat.normal_enabled = true
	mat.normal_texture = tex[1]
	mat.normal_scale = 1.0
	mat.roughness = rough
	mat.metallic = 0.0
	# After the land's outline pass, as every other mark on the ground is: at the
	# default priority that pass is drawn over the marks and they vanish.
	mat.render_priority = 9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plane
	mm.instance_count = CAP
	for i in CAP:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0.0, -100.0, 0.0)))
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))
	# The slots start parked out of sight, so the bounds the engine would work out
	# from them hold none of the marks laid later: the group is given the world.
	mm.custom_aabb = AABB(Vector3(-4096.0, -64.0, -4096.0), Vector3(8192.0, 256.0, 8192.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = key.replace("|", "_").replace(".", "")
	mi.multimesh = mm
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return {"mm": mm, "next": 0}


## [mask, normal] textures for a shape, made once; `hollow_only` for a white ground.
static func textures(shape: StringName, hollow_only: bool = false) -> Array:
	var key := "%s|%s" % [shape, hollow_only]
	if _textures.has(key):
		return _textures[key]
	var px: Vector2i = PIXELS.get(shape, PIXELS[&"foot"])
	var h := height_field(shape, px)
	var mask := Image.create_empty(px.x, px.y, true, Image.FORMAT_RGBA8)
	var normal := Image.create_empty(px.x, px.y, true, Image.FORMAT_RGB8)
	for y in px.y:
		for x in px.x:
			var v := h[y * px.x + x]
			# The hollow reads strongest, the pushed-up rim a little (on a dark ground).
			var a := clampf(maxf(-v, 0.0) * 1.15 + (0.0 if hollow_only else maxf(v, 0.0) * 0.35), 0.0, 1.0)
			mask.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
			var dx := _h(h, px, x + 1, y) - _h(h, px, x - 1, y)
			var dy := _h(h, px, x, y + 1) - _h(h, px, x, y - 1)
			var n := Vector3(-dx * 2.2, dy * 2.2, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	mask.generate_mipmaps()
	normal.generate_mipmaps()
	var out := [ImageTexture.create_from_image(mask), ImageTexture.create_from_image(normal)]
	_textures[key] = out
	return out


static func _h(h: PackedFloat32Array, px: Vector2i, x: int, y: int) -> float:
	return h[clampi(y, 0, px.y - 1) * px.x + clampi(x, 0, px.x - 1)]


## The shape as heights, -1 the bottom of the hollow to +1 the top of its rim, rows
## running along the heading (row 0 the back, the last row the front). Pure, so a
## test can hold every shape to having a hollow and a rim and nothing at its edges.
static func height_field(shape: StringName, px: Vector2i) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(px.x * px.y)
	for y in px.y:
		for x in px.x:
			var u := (float(x) + 0.5) / float(px.x)
			var v := (float(y) + 0.5) / float(px.y)
			h[y * px.x + x] = _height(shape, u, v)
	return h


## Signed distance inside an ellipse (<0 inside), in units of its smaller radius.
static func _ellipse(u: float, v: float, c: Vector2, r: Vector2) -> float:
	var q := Vector2((u - c.x) / r.x, (v - c.y) / r.y)
	return (q.length() - 1.0) * minf(r.x, r.y)


## A hollow where `d` < 0, a rim just outside it, nothing beyond.
static func _pressed(d: float, width: float, depth: float, rim: float) -> float:
	if d < 0.0:
		return -depth * smoothstep(0.0, width, -d)
	return rim * (1.0 - smoothstep(0.0, width * 1.6, d)) * smoothstep(-0.001, width * 0.4, d)


static func _height(shape: StringName, u: float, v: float) -> float:
	match shape:
		&"foot":
			# A boot: the sole wide at the ball and front, a separate heel behind it,
			# the tread across the sole in ridges.
			var sole := _ellipse(u, v, Vector2(0.5, 0.6), Vector2(0.28, 0.25))
			var heel := _ellipse(u, v, Vector2(0.5, 0.25), Vector2(0.23, 0.11))
			var d := minf(sole, heel)
			var hgt := _pressed(d, 0.05, 1.0, 0.45)
			if d < -0.02 and fmod(v * 11.0, 1.0) < 0.35:
				hgt += 0.3
			return hgt
		&"rig":
			# A machine foot: a round pad and three toes splayed forward, deep.
			var centre := Vector2(0.5, 0.4)
			var pad := _ellipse(u, v, centre, Vector2(0.17, 0.15))
			var d := pad
			for a: float in [-0.55, 0.0, 0.55]:
				var dir := Vector2(sin(a), cos(a))
				var mid := centre + dir * 0.2
				var rel := Vector2(u, v) - mid
				var q := Vector2(rel.dot(Vector2(dir.y, -dir.x)) / 0.055, rel.dot(dir) / 0.19)
				d = minf(d, (q.length() - 1.0) * 0.055)
			return _pressed(d, 0.04, 1.0, 0.55)
		&"scuff":
			# A foot dragged: a long shallow groove, streaked, the loose stuff heaped
			# at the front where it stopped.
			var groove := _ellipse(u, v, Vector2(0.5, 0.45), Vector2(0.26, 0.34))
			var hgt := _pressed(groove, 0.06, 0.55, 0.2)
			if groove < 0.0:
				hgt -= 0.18 * absf(sin(u * 23.0))
			hgt += 0.6 * exp(-pow((v - 0.84) / 0.045, 2.0)) * exp(-pow((u - 0.5) / 0.16, 2.0))
			return clampf(hgt, -1.0, 1.0)
		&"flatten":
			# Growth pushed down: shallow, soft-edged, bent along the way walked.
			var patch := _ellipse(u, v, Vector2(0.5, 0.5), Vector2(0.42, 0.44))
			var hgt := -0.5 * smoothstep(0.0, 0.18, -patch) if patch < 0.0 else 0.0
			if patch < 0.0:
				hgt -= 0.15 * absf(sin(u * 17.0 + v * 4.0))
			return hgt
		&"sweep":
			# A band brushed flat across the heading, streaks lying along it, soft at
			# both ends.
			var across := exp(-pow((v - 0.5) / 0.3, 4.0))
			var ends := smoothstep(0.0, 0.2, u) * smoothstep(1.0, 0.8, u)
			var hgt := -0.45 * across * ends
			hgt -= 0.12 * across * ends * absf(sin(v * 40.0))
			return hgt
	return 0.0
