class_name MeshKit
extends RefCounted
## Procedural mesh builder. Every model in the game is made from these calls:
## boxes, prisms, cones, rocks, quads, with flat normals and per-face vertex
## colour. No asset files.
##
## Axes are Godot's: +Y up, +X east, +Z south. Units are tiles. Colours are the
## palette's sRGB values; the world shader converts to linear.
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

## Ink channels (docs/ART.md) applied to every vertex pushed while set.
## Hatch style ids: see src/render/ink.gdshaderinc and Ink.
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
	for i in n:
		var j := (i + 1) % n
		if r1 > 0.0:
			quad(lo[j], lo[i], hi[i], hi[j], col)
		else:
			tri(lo[j], lo[i], hi[i], col)
	if r1 > 0.0:
		var c1 := Vector3(cx, y1, cz)
		for i in n:
			tri(c1, hi[(i + 1) % n], hi[i], tc)
	if bottom and r0 > 0.0:
		var c0 := Vector3(cx, y0, cz)
		for i in n:
			tri(c0, lo[i], lo[(i + 1) % n], col)
	return self


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
	prism(0, 0, 0, r, length, r, n, col, Color(0, 0, 0, 0), PI / n, true)
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
	for i in sides:
		var j := (i + 1) % sides
		var k := 1.0 + (Rng.hash01(seed_value, i, 3) - 0.5) * 0.12
		tri(apex, ring[j], ring[i], Color(col.r * k, col.g * k, col.b * k))
		tri(base, ring[i], ring[j], col.darkened(0.2))
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
