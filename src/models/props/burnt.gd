class_name Burnt
## A HOUSE THE HUNTERS BURNED (Vera: "We break their works. They burn a village";
## 48_raids, Reprisal). Drawn from the house it was, in its own landscape's form,
## so a burned village still reads as that village: the roof gone but for a few
## rafters left standing, the thatch and the turf gone with it, and every wall
## blackened, the soot heaviest where the fire went up.
##
## Only a colour's RGB is charred: its alpha is a material mark (`made`) or a
## lamp's (`found`, kit.gd), and a lowered alpha would be a light that blinks.

const Kit := preload("res://src/models/props/kit.gd")

## Above this share of the house's height, whatever faces the sky (a roof's
## pitch, a floor, a sill) burned and fell; what faces sideways, the walls and the
## chimney, still stands. A height cut alone keeps a tall form's whole roof.
const ROOF_FROM := 0.3
## A face is a wall when its normal is this near level.
const WALL := 0.35
## Beams that fell in when the roof went, lying from a wall's top to the floor.
## A share of the roof's own faces kept instead reads as confetti in the air.
const BEAMS := 3
## Soot is the pen's own darkest ink and never under it (tests/render/
## test_dark_floor): a char darker than the ink floor is a hole, not a wall.
static var SOOT: Color = Palette.INK[0]


static func burn(k: Kit, seed_value: int) -> void:
	# The footprint is the house walls', not the whole kit's: a yard's stones and
	# fences lie outside the rooms the floor belongs to, and stand lower.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var m := k.made
	for v: Vector3 in m.verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var tall := lo.y + (hi.y - lo.y) * ROOF_FROM
	lo = Vector3(INF, lo.y, INF)
	hi = Vector3(-INF, hi.y, -INF)
	for t in range(0, m.verts.size() - 2, 3):
		var a := m.verts[t]
		var b := m.verts[t + 1]
		var c := m.verts[t + 2]
		if _is_wall(a, b, c) and maxf(a.y, maxf(b.y, c.y)) > tall:
			for v: Vector3 in [a, b, c]:
				lo = Vector3(minf(lo.x, v.x), lo.y, minf(lo.z, v.z))
				hi = Vector3(maxf(hi.x, v.x), hi.y, maxf(hi.z, v.z))
	_char(k.made)
	_char(k.found)
	# Thatch, turf and the green on a roof burn first and leave nothing.
	k.leaf = MeshKit.new()
	if not lo.is_finite():
		return
	# The floor inside is its boards burned to charcoal, not the grass the gallery or the village stands on.
	var ash := GroundColors.made(SOOT, GroundColors.TIMBER)
	var a := Vector3(lerpf(lo.x, hi.x, 0.04), maxf(lo.y, 0.0) + 0.07, lerpf(lo.z, hi.z, 0.04))
	var b := Vector3(lerpf(lo.x, hi.x, 0.96), a.y, lerpf(lo.z, hi.z, 0.96))
	k.made.quad(a, Vector3(a.x, a.y, b.z), b, Vector3(b.x, a.y, a.z), ash)
	var beam := GroundColors.made(SOOT.lightened(0.1), GroundColors.TIMBER)
	var top := lo.y + (hi.y - lo.y) * ROOF_FROM
	for i in BEAMS:
		var u := Rng.hash01(seed_value, i, 0xB6)
		var side := Rng.hash01(seed_value, i, 0xB7) < 0.5
		var from := Vector3(lerpf(a.x, b.x, u), top, a.z if side else b.z)
		var to := Vector3(lerpf(a.x, b.x, Rng.hash01(seed_value, i, 0xB8)), a.y + 0.08, lerpf(a.z, b.z, 0.5))
		k.made.strut(from, to, 0.06, 4, beam)


static func _char(kit: MeshKit) -> void:
	var n := kit.verts.size()
	if n < 3:
		return
	var lo := INF
	var hi := -INF
	for v: Vector3 in kit.verts:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	var span := maxf(hi - lo, 0.001)
	var cut := lo + span * ROOF_FROM
	var per_vertex_custom := kit.custom0.size() == n * 4
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom := PackedFloat32Array()
	for t in range(0, n - 2, 3):
		var cy := (kit.verts[t].y + kit.verts[t + 1].y + kit.verts[t + 2].y) / 3.0
		if cy > cut and not _is_wall(kit.verts[t], kit.verts[t + 1], kit.verts[t + 2]):
			continue
		for j in 3:
			var i := t + j
			var v := kit.verts[i]
			var up := clampf((v.y - lo) / span, 0.0, 1.0)
			var c := kit.colors[i]
			# Soot climbs: the foot of a wall keeps a trace of its stone or timber.
			var burnt := Color(c.r * 0.5, c.g * 0.46, c.b * 0.42).lerp(SOOT, 0.25 + 0.65 * up)
			# Never under the pen, channel by channel, whatever the wall was.
			burnt = Color(maxf(burnt.r, SOOT.r), maxf(burnt.g, SOOT.g), maxf(burnt.b, SOOT.b), c.a)
			verts.append(v)
			normals.append(kit.normals[i])
			colors.append(burnt)
			uvs.append(kit.uvs[i])
			uv2s.append(kit.uv2s[i])
			if per_vertex_custom:
				for q in 4:
					custom.append(kit.custom0[i * 4 + q])
	kit.verts = verts
	kit.normals = normals
	kit.colors = colors
	kit.uvs = uvs
	kit.uv2s = uv2s
	if per_vertex_custom:
		kit.custom0 = custom


## A face that stands upright: a wall, a chimney's side, a post.
static func _is_wall(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var face := (b - a).cross(c - a)
	return face.length() > 0.000001 and absf(face.normalized().y) < WALL
