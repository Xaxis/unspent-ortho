class_name TerrainMesher
extends RefCounted
## Builds one CHUNK x CHUNK tile area into meshes. The tile grid is the rules'
## business, never the eye's (docs/ART.md): the land is drawn as CONTOUR TERRACES.
##
## A continuous elevation field f(x, y) is the bilinear interpolation of tile
## levels (sampled at tile centres) warped by noise. A point is on terrace L when
## f >= L - 0.5. Marching squares over a half-tile lattice traces each terrace
## edge as a curve; every terrace is a flat wash at L * STEP and every edge is a
## wall down to the terrace below, hatched as strata. Two-level cliffs therefore
## read as stacked rock ledges, one-level steps as a single inked lip, and a
## coastline as a survey contour rather than a staircase.
##
## Channels written per vertex are documented in src/render/world.gdshader.

const CHUNK := 32
const WATER_Y := 0.3
const SEA_FLOOR := -1.0
## Lattice samples per tile. 2 = half-tile cells.
const RES := 2
## How far (in levels) the noise warps the field: shapes curves, never moves a cliff far.
const WARP := 0.32

var world: WorldData
var _grade: FastNoiseLite
var _warp: FastNoiseLite
var _land_dist: PackedFloat32Array


func _init(w: WorldData) -> void:
	world = w
	_grade = FastNoiseLite.new()
	_grade.seed = Rng.hash_ints(w.seed_value, 31) & 0x7FFFFFFF
	_grade.frequency = 1.0 / 9.0
	_grade.fractal_octaves = 2
	_warp = FastNoiseLite.new()
	_warp.seed = Rng.hash_ints(w.seed_value, 32) & 0x7FFFFFFF
	_warp.frequency = 1.0 / 3.5
	_warp.fractal_octaves = 2
	var land := PackedByteArray()
	land.resize(w.size * w.size)
	for i in land.size():
		land[i] = 1 if w.level[i] > 0 else 0
	_land_dist = WorldGen.distance_field(land, w.size)
	# The chamfer distance steps at 45 degrees; a few blur passes turn the chart's
	# depth bands into soundings that follow the coast.
	for _pass in 3:
		_land_dist = _blur(_land_dist, w.size)


static func _blur(d: PackedFloat32Array, size: int) -> PackedFloat32Array:
	var out := d.duplicate()
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			if d[i] <= 0.0:
				continue
			out[i] = (d[i] * 4.0 + d[i - 1] + d[i + 1] + d[i - size] + d[i + size]) / 8.0
	return out


static func level_height(l: int) -> float:
	if l > 0:
		return l * WorldData.STEP
	return 0.0 if l == 0 else SEA_FLOOR


func _lv(x: int, y: int) -> float:
	return float(world.level_at(clampi(x, 0, world.size - 1), clampi(y, 0, world.size - 1)))


## The continuous elevation field, in levels, at tile-space point (x, y).
func field(x: float, y: float) -> float:
	var gx := x - 0.5
	var gy := y - 0.5
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - ix
	var fy := gy - iy
	var a := _lv(ix, iy)
	var b := _lv(ix + 1, iy)
	var c := _lv(ix, iy + 1)
	var d := _lv(ix + 1, iy + 1)
	var v := lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
	# Warp only where the land actually changes height, so flats stay flat.
	var spread := maxf(maxf(a, b), maxf(c, d)) - minf(minf(a, b), minf(c, d))
	if spread > 0.0:
		v += _warp.get_noise_2d(x * 4.0, y * 4.0) * WARP
	return v


func tile_grade(x: int, y: int) -> int:
	var v := _grade.get_noise_2d(x, y)
	if v < -0.28:
		return 0
	if v > 0.32:
		return 2
	return 1


func top_color(x: int, y: int) -> Color:
	var g := world.ground_at(x, y)
	return GroundColors.top(g, tile_grade(x, y))


## Returns [terrain: ArrayMesh, water: ArrayMesh or null].
func build_chunk(cx: int, cy: int) -> Array:
	var w := world
	var t := MeshKit.new()
	var sea := MeshKit.new()
	var x0 := cx * CHUNK
	var y0 := cy * CHUNK
	var x1 := mini(w.size, x0 + CHUNK)
	var y1 := mini(w.size, y0 + CHUNK)
	var n := (x1 - x0) * RES
	var m := (y1 - y0) * RES
	var step := 1.0 / RES
	# Sample the field once per lattice point.
	var f := PackedFloat32Array()
	f.resize((n + 1) * (m + 1))
	var gl := PackedByteArray()
	gl.resize((n + 1) * (m + 1))
	for j in m + 1:
		for i in n + 1:
			var sx := x0 + i * step
			var sy := y0 + j * step
			f[j * (n + 1) + i] = field(sx, sy)
			# Ground at a lattice point, looked up through a small warp so type
			# boundaries wander instead of following tile edges.
			var wx := sx + 0.01 + _warp.get_noise_2d(sx * 3.0 + 50.0, sy * 3.0) * 0.45
			var wy := sy + 0.01 + _warp.get_noise_2d(sx * 3.0, sy * 3.0 + 50.0) * 0.45
			gl[j * (n + 1) + i] = world.ground_at(floori(wx), floori(wy))
	for j in m:
		for i in n:
			var px := x0 + i * step
			var py := y0 + j * step
			var v00 := f[j * (n + 1) + i]
			var v10 := f[j * (n + 1) + i + 1]
			var v11 := f[(j + 1) * (n + 1) + i + 1]
			var v01 := f[(j + 1) * (n + 1) + i]
			_grounds = [gl[j * (n + 1) + i], gl[j * (n + 1) + i + 1], gl[(j + 1) * (n + 1) + i + 1], gl[(j + 1) * (n + 1) + i]]
			var start := t.vertex_count()
			_cell(t, px, py, step, v00, v10, v11, v01)
			_blend_grounds(t, start, px, py, step)
	_build_sea(sea, x0, y0, x1, y1)
	var water: ArrayMesh = sea.build() if sea.vertex_count() > 0 else null
	return [t.build(), water]


func _terrace(v: float) -> int:
	return floori(v + 0.5)


## One lattice cell: the lowest terrace fills the square; each higher terrace is
## the marching-squares region above its threshold, with walls on its edge.
func _cell(k: MeshKit, px: float, py: float, s: float, v00: float, v10: float, v11: float, v01: float) -> void:
	var lo := _terrace(minf(minf(v00, v10), minf(v11, v01)))
	var hi := _terrace(maxf(maxf(v00, v10), maxf(v11, v01)))
	var c00 := Vector2(px, py)
	var c10 := Vector2(px + s, py)
	var c11 := Vector2(px + s, py + s)
	var c01 := Vector2(px, py + s)
	_paint_top(k, (c00 + c11) * 0.5, lo)
	var h0 := level_height(lo)
	k.quad(Vector3(c00.x, h0, c00.y), Vector3(c01.x, h0, c01.y), Vector3(c11.x, h0, c11.y), Vector3(c10.x, h0, c10.y), _top_wash)
	var corners: Array[Vector2] = [c00, c10, c11, c01]
	var vals: PackedFloat32Array = [v00, v10, v11, v01]
	for L in range(lo + 1, hi + 1):
		var thr := L - 0.5
		var poly: Array[Vector2] = []
		var crossings: Array[Vector2] = []
		var inside: Array[bool] = []
		for e in 4:
			var a := vals[e]
			var b := vals[(e + 1) % 4]
			var ina := a >= thr
			inside.append(ina)
			if ina:
				poly.append(corners[e])
			if ina != (b >= thr):
				var tt := clampf((thr - a) / (b - a), 0.05, 0.95)
				var p := corners[e].lerp(corners[(e + 1) % 4], tt)
				poly.append(p)
				crossings.append(p)
		if poly.size() < 3:
			continue
		var h := level_height(L)
		var hb := level_height(L - 1)
		var centre := (v00 + v10 + v11 + v01) * 0.25 >= thr
		var saddle := inside[0] == inside[2] and inside[1] == inside[3] and inside[0] != inside[1]
		_paint_top(k, _centroid(poly), L)
		if saddle and not centre:
			# Two separate islands at the inside corners.
			for e in 4:
				if inside[e]:
					var before := corners[e].lerp(corners[(e + 3) % 4], clampf((thr - vals[e]) / (vals[(e + 3) % 4] - vals[e]), 0.05, 0.95))
					var after := corners[e].lerp(corners[(e + 1) % 4], clampf((thr - vals[e]) / (vals[(e + 1) % 4] - vals[e]), 0.05, 0.95))
					_fan(k, [corners[e], after, before], h)
					_wall(k, after, before, hb, h, L)
			continue
		_fan(k, poly, h)
		if crossings.size() == 2:
			_wall(k, crossings[0], crossings[1], hb, h, L)
		elif crossings.size() == 4:
			# Saddle with the centre inside: walls cut off the two outside corners.
			for e in 4:
				if not inside[e]:
					var before := corners[e].lerp(corners[(e + 3) % 4], clampf((thr - vals[e]) / (vals[(e + 3) % 4] - vals[e]), 0.05, 0.95))
					var after := corners[e].lerp(corners[(e + 1) % 4], clampf((thr - vals[e]) / (vals[(e + 1) % 4] - vals[e]), 0.05, 0.95))
					_wall(k, before, after, hb, h, L)


var _top_wash := Color.WHITE
## Ground ids at the current cell's corners: c00, c10, c11, c01.
var _grounds: Array[int] = [0, 0, 0, 0]


## Give every upward vertex of the cell just built a primary wash (the most
## common corner ground), a second wash (the next), and a per-vertex weight
## toward the second: the shader turns it into a ragged, curving boundary.
func _blend_grounds(k: MeshKit, start: int, px: float, py: float, s: float) -> void:
	var a := _grounds[0]
	var b := -1
	var counts := {}
	for g in _grounds:
		counts[g] = counts.get(g, 0) + 1
	var best := 0
	for g: int in counts:
		if counts[g] > best:
			best = counts[g]
			a = g
	for g in _grounds:
		if g != a:
			b = g
			break
	var ca := GroundColors.top(a, 1)
	var cb := GroundColors.top(b, 1) if b >= 0 else ca
	var w00 := 1.0 if _grounds[0] == b else 0.0
	var w10 := 1.0 if _grounds[1] == b else 0.0
	var w11 := 1.0 if _grounds[2] == b else 0.0
	var w01 := 1.0 if _grounds[3] == b else 0.0
	for v in range(start, k.vertex_count()):
		if k.normals[v].y < 0.5:
			continue
		var p := k.verts[v]
		var fx := clampf((p.x - px) / s, 0.0, 1.0)
		var fy := clampf((p.z - py) / s, 0.0, 1.0)
		var col := ca
		var col2 := cb
		# Keep the per-terrace value shift applied by _paint_top.
		if roundi(p.y / WorldData.STEP) % 2 == 1 and p.y > 0.0:
			col = col.darkened(0.03)
			col2 = col2.darkened(0.03)
		k.colors[v] = col
		var o := v * 4
		k.custom0[o] = col2.r
		k.custom0[o + 1] = col2.g
		k.custom0[o + 2] = col2.b
		k.custom0[o + 3] = 0.0 if b < 0 else lerpf(lerpf(w00, w10, fx), lerpf(w01, w11, fx), fy)
		k.uv2s[v] = Vector2(0.0, 1.0)


## Set the kit's ink channels and _top_wash for a terrace surface at point p.
func _paint_top(k: MeshKit, p: Vector2, L: int) -> void:
	var tx := clampi(floori(p.x), 0, world.size - 1)
	var ty := clampi(floori(p.y), 0, world.size - 1)
	var i := ty * world.size + tx
	var g := world.ground[i]
	var c := world.country[i]
	_top_wash = GroundColors.top(g, tile_grade(tx, ty))
	# Terraces one level apart alternate a hair in value: the contour is felt, not seen.
	if L % 2 == 1:
		_top_wash = _top_wash.darkened(0.03)
	k.style = Ink.COUNTRY_STYLE[c] if L > 0 else Ink.NONE
	var c2 := world.country2[i]
	var b := world.blend[i]
	k.style2 = Ink.COUNTRY_STYLE[c2] if b > 0.0 else k.style
	k.style_blend = b
	k.wash_blend = 0.0
	k.sway = 0.0


func _fan(k: MeshKit, poly: Array, h: float) -> void:
	var c := _centroid(poly)
	var cc := Vector3(c.x, h, c.y)
	for e in poly.size():
		var a: Vector2 = poly[e]
		var b: Vector2 = poly[(e + 1) % poly.size()]
		# Perimeter order runs clockwise in x-east/z-south seen from above; tri() wants CCW.
		k.tri(cc, Vector3(b.x, h, b.y), Vector3(a.x, h, a.y), _top_wash)


func _centroid(poly: Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in poly:
		c += p
	return c / poly.size()


## A wall along a terrace edge from p to q, from height hb up to h, facing downhill.
func _wall(k: MeshKit, p: Vector2, q: Vector2, hb: float, h: float, L: int) -> void:
	var mid := (p + q) * 0.5
	var along := (q - p)
	if along.length_squared() < 1e-8:
		return
	var perp := Vector2(-along.y, along.x).normalized()
	# quad() below faces (dz, -dx) = -perp; flip so that points downhill.
	if field(mid.x + perp.x * 0.08, mid.y + perp.y * 0.08) < field(mid.x - perp.x * 0.08, mid.y - perp.y * 0.08):
		var tmp := p
		p = q
		q = tmp
	var tx := clampi(floori(mid.x), 0, world.size - 1)
	var ty := clampi(floori(mid.y), 0, world.size - 1)
	var g := world.ground[ty * world.size + tx]
	var col := GroundColors.side(g, posmod(L, 2))
	k.style = Ink.CONTOUR
	k.style2 = Ink.CONTOUR
	k.style_blend = 0.0
	# The wall is built so its normal points from the high side to the low side.
	k.quad(Vector3(q.x, hb, q.y), Vector3(p.x, hb, p.y), Vector3(p.x, h, p.y), Vector3(q.x, h, q.y), col)


## The sea as a chart: one flat sheet per chunk on a half-tile lattice, carrying
## distance-to-land in COLOR.a; water.gdshader draws depth bands and foam.
func _build_sea(k: MeshKit, x0: int, y0: int, x1: int, y1: int) -> void:
	var any := false
	for y in range(y0, y1):
		for x in range(x0, x1):
			if world.level[y * world.size + x] <= 0:
				any = true
				break
		if any:
			break
	if not any:
		return
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	k.style_blend = 0.0
	var s := 1.0 / RES
	var nx := (x1 - x0) * RES
	var ny := (y1 - y0) * RES
	for j in ny:
		for i in nx:
			var ax := x0 + i * s
			var ay := y0 + j * s
			# Skip cells well inland: the land hides them anyway.
			if field(ax + s * 0.5, ay + s * 0.5) > 1.6:
				continue
			var da := _depth_at(ax, ay)
			var db := _depth_at(ax + s, ay)
			var dc := _depth_at(ax + s, ay + s)
			var dd := _depth_at(ax, ay + s)
			k.quad(Vector3(ax, WATER_Y, ay), Vector3(ax, WATER_Y, ay + s), Vector3(ax + s, WATER_Y, ay + s), Vector3(ax + s, WATER_Y, ay), Color(1, 1, 1, da))
			# Vertex alpha must vary per corner: patch the six colours just written.
			var nverts := k.colors.size()
			var order := [da, dc, dd, da, db, dc] # emitted order a,c,b per tri (see MeshKit.tri)
			for v in 6:
				var col := k.colors[nverts - 6 + v]
				col.a = order[v]
				k.colors[nverts - 6 + v] = col


## 0 at the shore, 1 in deep water, smooth across the lattice.
func _depth_at(x: float, y: float) -> float:
	var tx := clampi(floori(x), 0, world.size - 1)
	var ty := clampi(floori(y), 0, world.size - 1)
	var d := _land_dist[ty * world.size + tx]
	var fx := clampf(x - tx, 0.0, 1.0)
	var fy := clampf(y - ty, 0.0, 1.0)
	var tx2 := clampi(tx + 1, 0, world.size - 1)
	var ty2 := clampi(ty + 1, 0, world.size - 1)
	var d2 := lerpf(lerpf(d, _land_dist[ty * world.size + tx2], fx), lerpf(_land_dist[ty2 * world.size + tx], _land_dist[ty2 * world.size + tx2], fx), fy)
	return clampf((d2 - 0.5) / 9.0, 0.0, 1.0)
