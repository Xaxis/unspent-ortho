class_name MeshKit
extends RefCounted
## Procedural mesh builder. Every model in the game is made from these calls:
## boxes, prisms, cones, rocks, quads, with per-face vertex colour and a normal
## per face UNLESS the builder welds (see smoothing, below — most do not, and
## that is the `form` wave's remaining job). No asset files.
##
## Axes are Godot's: +Y up, +X east, +Z south. Units are tiles. Colours are the
## palette's sRGB values, and what happens to them next is the RENDERER's
## business, not this file's: `matter_albedo()` decodes on Forward+ and is the
## identity on Compatibility. This header used to say "the world shader converts
## to linear", which was true of one of the two renderers we ship.
##
##   var k := MeshKit.new()
##   k.block(0, 0, 0, 0.6, 1.2, 0.4, Palette.LINEN[2])
##   k.push(Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 1.2, 0)))
##   k.prism(0, 0, 0, 0.3, 0.5, 0.0, 6, Palette.SPRUCE[3])   # a cone
##   k.pop()
##   var mesh: ArrayMesh = k.build()

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var custom0 := PackedFloat32Array()

## The MATERIAL ROW applied to every vertex pushed while set. These are still
## named for the pen: `Ink.SPARSE` reads "few long diagonals; the page does the
## work" and there has been no page since LANTERN. What the number does now is
## tell one landscape's ground from another's (world.gdshader unpacks it as a
## row, CLAUDE.md says so) — so pick by what the surface IS, not by the doc
## comment on the constant.
var style := Ink.HAND
var style2 := Ink.HAND
var style_blend := 0.0
## Ecotone second wash and how far toward it (0 = none).
var wash2 := Color.BLACK
var wash_blend := 0.0
## Wind sway weight for vertices (0 rigid). Set per part: crown tips high, trunks 0.
var sway := 0.0
var sway_phase := 0.0
var _xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []
var _has_xf := false


## Compose a transform onto the current one until pop().
func push(t: Transform3D) -> MeshKit:
	_stack.append(_xf)
	_xf = _xf * t
	_has_xf = _xf != Transform3D.IDENTITY
	return self


func pop() -> MeshKit:
	_xf = _stack.pop_back()
	_has_xf = _xf != Transform3D.IDENTITY
	return self


## Translate, rotate about Y, uniform or per-axis scale.
func at(x: float, y: float, z: float, rot_y: float = 0.0, s: Vector3 = Vector3.ONE) -> MeshKit:
	var b := Basis(Vector3.UP, rot_y).scaled(s)
	return push(Transform3D(b, Vector3(x, y, z)))


## One triangle, counter-clockwise seen from the front. Flat normal.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> MeshKit:
	if _has_xf:
		a = _xf * a
		b = _xf * b
		c = _xf * c
	# Godot's front faces are clockwise in screen space; we author CCW and emit reversed.
	var n := (c - b).cross(a - b).normalized()
	verts.append(a)
	verts.append(c)
	verts.append(b)
	var uv := Vector2(style + style2 * 16, style_blend)
	var uv2 := Vector2(sway, sway_phase)
	for i in 3:
		normals.append(n)
		colors.append(col)
		uvs.append(uv)
		uv2s.append(uv2)
		custom0.append(wash2.r)
		custom0.append(wash2.g)
		custom0.append(wash2.b)
		custom0.append(wash_blend)
	return self


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> MeshKit:
	tri(a, b, c, col)
	tri(a, c, d, col)
	return self


## Axis-aligned box between two corners. `top` colours the +Y face.
func box(p0: Vector3, p1: Vector3, col: Color, top: Color = Color(0, 0, 0, 0), bottom: bool = false) -> MeshKit:
	var tc := col if top.a == 0.0 else top
	var x0 := p0.x
	var y0 := p0.y
	var z0 := p0.z
	var x1 := p1.x
	var y1 := p1.y
	var z1 := p1.z
	quad(Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), tc)
	if bottom:
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), col)
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), col)
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), col)
	quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), col)
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), col)
	return self


## Box standing on (cx, y0, cz) with footprint w x d and height h.
func block(cx: float, y0: float, cz: float, w: float, h: float, d: float, col: Color, top: Color = Color(0, 0, 0, 0)) -> MeshKit:
	return box(Vector3(cx - w * 0.5, y0, cz - d * 0.5), Vector3(cx + w * 0.5, y0 + h, cz + d * 0.5), col, top)


## Vertical n-sided frustum: radius r0 at y0, r1 at y1. r1 = 0 is a cone.
func prism(cx: float, y0: float, cz: float, r0: float, y1: float, r1: float, n: int, col: Color, top: Color = Color(0, 0, 0, 0), phase: float = 0.0, bottom: bool = false) -> MeshKit:
	var tc := col if top.a == 0.0 else top
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in n:
		var a := phase + float(i) / n * TAU
		lo.append(Vector3(cx + cos(a) * r0, y0, cz + sin(a) * r0))
		hi.append(Vector3(cx + cos(a) * r1, y1, cz + sin(a) * r1))
	var wall_from := verts.size()
	for i in n:
		var j := (i + 1) % n
		if r1 > 0.0:
			quad(lo[j], lo[i], hi[i], hi[j], col)
		else:
			tri(lo[j], lo[i], hi[i], col)
	if n >= ROUND_SIDES:
		# Seven sides and up is a drum, a pot, a trunk or a tank, never a nut:
		# it is round, and from the side at eye level a flat normal per side
		# makes it a faceted column. Walls only, so the ends stay flat ends.
		smooth_range(wall_from, verts.size(), 360.0 / n + 8.0)
	if r1 > 0.0:
		var c1 := Vector3(cx, y1, cz)
		for i in n:
			tri(c1, hi[(i + 1) % n], hi[i], tc)
	if bottom and r0 > 0.0:
		var c0 := Vector3(cx, y0, cz)
		for i in n:
			tri(c0, lo[i], lo[(i + 1) % n], col)
	return self


## Sides from which a prism is taken to be round and welded (see prism).
const ROUND_SIDES := 7


## A cylinder or bar between two arbitrary points (limbs, cables, struts).
func strut(a: Vector3, b: Vector3, r: float, n: int, col: Color) -> MeshKit:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return self
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	var basis := Basis(side, up, fwd)
	push(Transform3D(basis, a))
	var wall_from := verts.size()
	prism(0, 0, 0, r, length, r, n, col, Color(0, 0, 0, 0), PI / n, true)
	if n >= 5 and n < ROUND_SIDES:
		# A bar of five or six sides is a pole, a log, a pipe: round. Four is a
		# board or a beam and keeps its edges; three is a cable, too thin to
		# light as anything but a line. The prism's own weld covers seven up.
		smooth_range(wall_from, wall_from + n * 6, 360.0 / n + 8.0)
	pop()
	return self


## A low-poly jittered rock or clump, seeded so every copy differs.
func rock(cx: float, y0: float, cz: float, r: float, h: float, seed_value: int, col: Color, sides: int = 6) -> MeshKit:
	var ring: Array[Vector3] = []
	var mid := y0 + h * 0.45
	for i in sides:
		var a := float(i) / sides * TAU + Rng.hash01(seed_value, i) * 0.4
		var rr := r * (0.75 + Rng.hash01(seed_value, i, 1) * 0.35)
		ring.append(Vector3(cx + cos(a) * rr, mid + (Rng.hash01(seed_value, i, 2) - 0.5) * h * 0.2, cz + sin(a) * rr))
	var apex := Vector3(cx + (Rng.hash01(seed_value, 9) - 0.5) * r * 0.4, y0 + h, cz + (Rng.hash01(seed_value, 10) - 0.5) * r * 0.4)
	var base := Vector3(cx, y0, cz)
	var start := verts.size()
	for i in sides:
		var j := (i + 1) % sides
		var k := 1.0 + (Rng.hash01(seed_value, i, 3) - 0.5) * 0.12
		tri(apex, ring[j], ring[i], Color(col.r * k, col.g * k, col.b * k))
		tri(base, ring[i], ring[j], col.darkened(0.2))
	# A heap of matter is a rounded mass, not a cut stone: the same crease pass
	# the prop kit's stone takes, so a wad of straw and a boulder agree.
	smooth_range(start, verts.size())
	return self


## --- smoothing ---------------------------------------------------------------
## A flat normal per face is what a GEM is made of: every facet one value, every
## edge a hard step. It was the right call under a 640x360 wash-and-ink pipeline,
## where the ink drew the form and a normal only chose a shade band. Under a real
## sun it is the whole difference between stone and crystal, and it is why the
## boulders and the bushes read as low-poly cut glass (docs/LOOK.md law 1).
##
## `smooth_begin()` marks where a shape starts and `smooth_end(crease)` welds the
## vertices pushed since, averaging each one's normal over the faces meeting
## there that turn less than `crease` degrees — so a weathered mass rounds off
## while a fracture plane, a chamfer and a cut face stay hard. Area-weighted, so
## a big face leads and a sliver does not drag the average off.
##
## **It adds no triangles.** The same mesh, told where it curves. That is why it
## comes first: every other thing in this package costs something.
##
## **AND IT REACHES FOUR CALL SITES OUT OF SIXTY-FOUR MODEL FILES.** `rock`
## (below), `Kit.stone`, `Kit.clump` and `Sculpt`'s walls call `smooth_range`;
## `smooth_begin`/`smooth_end` have NO CALLERS ANYWHERE. Two independent audits
## found this separately. So every lathe, loft, disc, tbar and cbox on every
## machine, sentinel, house, tower, wreck, landmark, craft and settlement piece
## is still flat-shaded, which IS "models read faceted under real light".
##
## Two things whoever takes that needs before they start. The welding is
## CORRECT — `build()` passes normals straight through, `Kit.sway_by_height`
## writes uv2s only and cannot stale a weld, and `Broken.work_down` rebuilds
## normals itself, lerping the kept ones and giving the cut face its own hard
## normal. And it welds within `[from, to)`, i.e. PER SHAPE: a hull emitted as
## eight `cbox` calls still has eight hard seams. Deciding whether to bracket a
## whole assembly or each call is a judgement about where the creases belong,
## per model, which is why this is a wave and not a sweep.
const CREASE := 52.0
## Positions closer than this are the same corner. A tenth of a screen pixel at
## the play camera, so nothing a model actually separates is ever welded.
const WELD := 0.0005

var _smooth_from := -1


func smooth_begin() -> MeshKit:
	_smooth_from = verts.size()
	return self


## Average the normals pushed since `smooth_begin()` across creases under
## `crease_deg`. Call with the shape finished and before the next one starts.
func smooth_end(crease_deg: float = CREASE) -> MeshKit:
	if _smooth_from < 0:
		return self
	smooth_range(_smooth_from, verts.size(), crease_deg)
	_smooth_from = -1
	return self


## The same over an explicit vertex range, for a builder that already knows where
## its shape began (the prop kits keep their own marks).
func smooth_range(from: int, to: int, crease_deg: float = CREASE) -> MeshKit:
	to = mini(to, verts.size())
	if to - from < 3:
		return self
	var limit := cos(deg_to_rad(clampf(crease_deg, 0.0, 179.0)))
	# Triangle area rides in the accumulated normal's length, so a wide face
	# leads the average and a sliver cannot tip it.
	var weighted := PackedVector3Array()
	weighted.resize(to - from)
	for t in range(from, to, 3):
		if t + 2 >= to:
			break
		var area := (verts[t + 1] - verts[t]).cross(verts[t + 2] - verts[t]).length() * 0.5
		for c in 3:
			weighted[t + c - from] = normals[t + c] * area
	var at_corner := {}
	for i in range(from, to):
		var p := verts[i]
		var key := Vector3i(roundi(p.x / WELD), roundi(p.y / WELD), roundi(p.z / WELD))
		if not at_corner.has(key):
			at_corner[key] = PackedInt32Array()
		var bucket: PackedInt32Array = at_corner[key]
		bucket.append(i)
		at_corner[key] = bucket
	for key: Vector3i in at_corner:
		var group: PackedInt32Array = at_corner[key]
		if group.size() < 2:
			continue
		var blended := PackedVector3Array()
		blended.resize(group.size())
		for a in group.size():
			var n := normals[group[a]]
			var acc := Vector3.ZERO
			for b in group.size():
				# Its own face always counts; a neighbour only while the surface
				# keeps turning gently through this corner.
				if a == b or n.dot(normals[group[b]]) >= limit:
					acc += weighted[group[b] - from]
			blended[a] = acc.normalized() if acc.length_squared() > 1e-12 else n
		for a in group.size():
			normals[group[a]] = blended[a]
	return self


func vertex_count() -> int:
	return verts.size()


func build(into: ArrayMesh = null) -> ArrayMesh:
	var mesh := into if into != null else ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh
