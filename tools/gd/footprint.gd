extends RefCounted
## A model's drawn footprint against the circles that stop a body
## (tests/render/test_prop_footprint.gd, tools/gd/prop_walls_bake.gd). Triangles are clipped to a height band
## (what a walking body meets), projected to the ground plane and rasterised on
## CELL squares; the collision is the union of circles. Distances come from a
## nearest-site sweep, in tiles (one model unit is one tile across).
##
## Contract:
##   polys(tris, xf, out, lo, hi)  clipped XZ polygons of a triangle soup
##   measure(drawn, circles) -> {gap, walk, area, ...}
##     gap: how far the collision's edge stands from anything drawn (an
##          invisible wall); walk: how far drawn mass lies past the collision
##          (a body walks into what it sees).

const LO := 0.12
const HI := 1.6
const CELL := 0.1


static func _clip(poly: Array, y: float, keep_above: bool) -> Array:
	var out: Array = []
	var n := poly.size()
	for i in n:
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[(i + 1) % n]
		var ina := a.y >= y if keep_above else a.y <= y
		var inb := b.y >= y if keep_above else b.y <= y
		if ina:
			out.append(a)
		if ina != inb:
			var t := (y - a.y) / (b.y - a.y)
			out.append(a.lerp(b, t))
	return out


## Clipped XZ polygons of a triangle soup under `xf`.
static func polys(tris: PackedVector3Array, xf: Transform3D, out: Array, lo: float = LO, hi: float = HI) -> void:
	var t := 0
	while t + 2 < tris.size():
		var a := xf * tris[t]
		var b := xf * tris[t + 1]
		var c := xf * tris[t + 2]
		t += 3
		var ymin := minf(a.y, minf(b.y, c.y))
		var ymax := maxf(a.y, maxf(b.y, c.y))
		if ymax < lo or ymin > hi:
			continue
		var poly: Array = [a, b, c]
		if ymin < lo:
			poly = _clip(poly, lo, true)
		if poly.size() > 0 and ymax > hi:
			poly = _clip(poly, hi, false)
		if poly.is_empty():
			continue
		var p2 := PackedVector2Array()
		for v: Vector3 in poly:
			p2.append(Vector2(v.x, v.z))
		out.append(p2)


## Triangles of every visible MeshInstance3D under `root`, in root space.
static func node_polys(root: Node, out: Array, lo: float = LO, hi: float = HI, skip: Array = []) -> void:
	_node_polys(root, root, Transform3D.IDENTITY, out, lo, hi, skip)


static func _node_polys(root: Node, n: Node, xf: Transform3D, out: Array, lo: float, hi: float, skip: Array) -> void:
	if n != root and n is Node3D:
		if not (n as Node3D).visible or skip.has(String(n.name)):
			return
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
				var tri := PackedVector3Array()
				for i: int in idx:
					tri.append(v[i])
				polys(tri, xf, out, lo, hi)
			else:
				polys(v, xf, out, lo, hi)
	for c in n.get_children():
		_node_polys(root, c, xf, out, lo, hi, skip)


## {drawn bbox, area, gap (collision edge to nearest drawn), walk (drawn to
## nearest collision), ...}. `circles` are (x, z, r).
static func measure(drawn: Array, circles: Array) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: PackedVector2Array in drawn:
		for v in p:
			lo = lo.min(v)
			hi = hi.max(v)
	var dlo := lo
	var dhi := hi
	for c: Vector3 in circles:
		lo = lo.min(Vector2(c.x - c.z, c.y - c.z))
		hi = hi.max(Vector2(c.x + c.z, c.y + c.z))
	if not lo.is_finite():
		return {"empty": true}
	lo -= Vector2(1, 1)
	hi += Vector2(1, 1)
	var nx := ceili((hi.x - lo.x) / CELL)
	var nz := ceili((hi.y - lo.y) / CELL)
	var n := nx * nz
	var dmask := PackedByteArray()
	dmask.resize(n)
	var cmask := PackedByteArray()
	cmask.resize(n)
	for p: PackedVector2Array in drawn:
		_mark(p, dmask, lo, nx, nz)
	for c: Vector3 in circles:
		var cx0 := maxi(0, floori((c.x - c.z - lo.x) / CELL))
		var cx1 := mini(nx - 1, ceili((c.x + c.z - lo.x) / CELL))
		var cz0 := maxi(0, floori((c.y - c.z - lo.y) / CELL))
		var cz1 := mini(nz - 1, ceili((c.y + c.z - lo.y) / CELL))
		for z in range(cz0, cz1 + 1):
			for x in range(cx0, cx1 + 1):
				var ctr := lo + Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
				if ctr.distance_to(Vector2(c.x, c.y)) <= c.z:
					cmask[z * nx + x] = 1
	var out := {"empty": false, "dlo": dlo, "dhi": dhi}
	var dcount := 0
	for i in n:
		dcount += dmask[i]
	out.area = dcount * CELL * CELL
	var ccount := 0
	for i in n:
		ccount += cmask[i]
	out.carea = ccount * CELL * CELL
	# Collision edge cells: in the collision with a 4-neighbour outside it.
	var to_drawn := dt(dmask, nx, nz) if dcount > 0 else PackedFloat32Array()
	var gap := 0.0
	var gap_at := Vector2.ZERO
	var edges := 0
	var far_edges := 0
	if ccount > 0:
		for z in nz:
			for x in nx:
				var i := z * nx + x
				if cmask[i] == 0:
					continue
				var edge := x == 0 or z == 0 or x == nx - 1 or z == nz - 1 or cmask[i - 1] == 0 or cmask[i + 1] == 0 or cmask[i - nx] == 0 or cmask[i + nx] == 0
				if not edge:
					continue
				edges += 1
				var g := to_drawn[i] * CELL if dcount > 0 else INF
				if g > 0.3:
					far_edges += 1
				if g > gap:
					gap = g
					gap_at = lo + Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
	out.gap = gap
	out.gap_at = gap_at
	out.far_edge_share = float(far_edges) / maxf(1.0, float(edges))
	var walk := 0.0
	var walk_at := Vector2.ZERO
	var walk_area := 0
	if dcount > 0:
		var to_coll := dt(cmask, nx, nz) if ccount > 0 else PackedFloat32Array()
		for z in nz:
			for x in nx:
				var i := z * nx + x
				if dmask[i] == 0:
					continue
				var at := lo + Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
				var d := to_coll[i] * CELL if ccount > 0 else at.length()
				if d > 0.3:
					walk_area += 1
				if d > walk:
					walk = d
					walk_at = at
	out.walk = walk
	out.walk_at = walk_at
	out.walk_area = walk_area * CELL * CELL
	return out


static func _mark(p: PackedVector2Array, mask: PackedByteArray, lo: Vector2, nx: int, nz: int) -> void:
	var m := p.size()
	# Edges, so a wall seen edge-on (zero area in plan) still marks its line.
	for i in m:
		var a := p[i]
		var b := p[(i + 1) % m]
		var steps := maxi(1, ceili(a.distance_to(b) / (CELL * 0.5)))
		for s in steps + 1:
			var q := a.lerp(b, float(s) / steps)
			var x := floori((q.x - lo.x) / CELL)
			var z := floori((q.y - lo.y) / CELL)
			if x >= 0 and z >= 0 and x < nx and z < nz:
				mask[z * nx + x] = 1
	if m < 3:
		return
	var area := 0.0
	for i in m:
		area += p[i].cross(p[(i + 1) % m])
	if absf(area) < 1e-5:
		return
	var sgn := signf(area)
	var bl := p[0]
	var bh := p[0]
	for v in p:
		bl = bl.min(v)
		bh = bh.max(v)
	var x0 := maxi(0, floori((bl.x - lo.x) / CELL))
	var x1 := mini(nx - 1, floori((bh.x - lo.x) / CELL))
	var z0 := maxi(0, floori((bl.y - lo.y) / CELL))
	var z1 := mini(nz - 1, floori((bh.y - lo.y) / CELL))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var c := lo + Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
			var inside := true
			for i in m:
				var e := p[(i + 1) % m] - p[i]
				if e.cross(c - p[i]) * sgn < -1e-6:
					inside = false
					break
			if inside:
				mask[z * nx + x] = 1


## Distance (in cells) from every cell to the nearest set cell of `mask`.
static func dt(mask: PackedByteArray, nx: int, nz: int) -> PackedFloat32Array:
	var n := nx * nz
	var sx := PackedInt32Array()
	sx.resize(n)
	var sz := PackedInt32Array()
	sz.resize(n)
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		if mask[i] != 0:
			sx[i] = i % nx
			sz[i] = i / nx
			d[i] = 0.0
		else:
			sx[i] = -1
			d[i] = INF
	var fw: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	var bw: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]
	for z in nz:
		for x in nx:
			_relax(x, z, fw, sx, sz, d, nx, nz)
		for x in range(nx - 1, -1, -1):
			_relax(x, z, [Vector2i(1, 0)] as Array[Vector2i], sx, sz, d, nx, nz)
	for z in range(nz - 1, -1, -1):
		for x in range(nx - 1, -1, -1):
			_relax(x, z, bw, sx, sz, d, nx, nz)
		for x in nx:
			_relax(x, z, [Vector2i(-1, 0)] as Array[Vector2i], sx, sz, d, nx, nz)
	return d


static func _relax(x: int, z: int, ns: Array[Vector2i], sx: PackedInt32Array, sz: PackedInt32Array, d: PackedFloat32Array, nx: int, nz: int) -> void:
	var i := z * nx + x
	for o: Vector2i in ns:
		var jx := x + o.x
		var jz := z + o.y
		if jx < 0 or jz < 0 or jx >= nx or jz >= nz:
			continue
		var j := jz * nx + jx
		if sx[j] < 0:
			continue
		var dd := Vector2(x - sx[j], z - sz[j]).length()
		if dd < d[i]:
			d[i] = dd
			sx[i] = sx[j]
			sz[i] = sz[j]


static func fmt(name: String, solid_desc: String, r: Dictionary) -> String:
	if r.get("empty", true):
		return "AUDIT|%s|%s|empty" % [name, solid_desc]
	var dlo: Vector2 = r.dlo
	var dhi: Vector2 = r.dhi
	return "AUDIT|%s|%s|bbox x[%.2f,%.2f] z[%.2f,%.2f]|drawn %.2f|coll %.2f|gap %.2f @(%.2f,%.2f) share>0.3 %.2f|walk %.2f @(%.2f,%.2f) area>0.3 %.2f" % [
		name, solid_desc, dlo.x, dhi.x, dlo.y, dhi.y, r.area, r.carea,
		r.gap, (r.gap_at as Vector2).x, (r.gap_at as Vector2).y, r.far_edge_share,
		r.walk, (r.walk_at as Vector2).x, (r.walk_at as Vector2).y, r.walk_area]
