class_name GenWater
## Stages 5 and 7: rivers and still water.
##
## Rivers are traced, not painted: a priority flood from the sea over the
## coarse elevation gives every cell a way downhill to the sea (through any
## hollow), rain by country accumulates along it, and cells past a catchment
## threshold become rivers. Each river is smoothed, meandered, rasterised
## 4-connected, given a bed that never rises downstream, and cuts a valley
## whose sides are walkable (a gorge in the Bonelands). One tile wide at the
## source, widening to the mouth, always wadeable.
##
## Still water (after terracing): blackwater pools in the Moss, frozen tarns on
## Snowfield flats, the odd tarn elsewhere.

## Catchment in coarse cells x rain before a cell carries a river (512 world).
const RIVER_CATCHMENT := 120.0
const MAX_RIVERS := 11
## A river's head is where its catchment falls to this share of RIVER_CATCHMENT.
const HEAD_SHARE := 0.06


static func rivers(c: GenContext) -> void:
	var size := c.size
	var cw := c.cw
	var cn := cw * cw
	var step := GenContext.STEP
	var rain_p: PackedFloat32Array = GenCountries.params(c, [&"rain"])[&"rain"]
	var land := c.land
	var elev := c.elev
	var ec := PackedFloat32Array()
	ec.resize(cn)
	var landc := PackedByteArray()
	landc.resize(cn)
	for gy in cw:
		var ty := clampi(roundi(GenFields.cell_centre(gy, step)), 0, size - 1)
		for gx in cw:
			var k := gy * cw + gx
			var tx := clampi(roundi(GenFields.cell_centre(gx, step)), 0, size - 1)
			var i := ty * size + tx
			landc[k] = land[i]
			# A little jitter so drainage across flats wanders instead of ruling lines.
			ec[k] = elev[i] + GenFields.h01(c.s, gx, gy, 41) * 0.35
	# Priority flood from the sea.
	var parent := PackedInt32Array()
	parent.resize(cn)
	parent.fill(-1)
	var seen := PackedByteArray()
	seen.resize(cn)
	var filled := PackedFloat32Array()
	filled.resize(cn)
	# A bucket queue (a hundredth of a level per bucket): every push lands at
	# least one bucket above the cell being spread, so buckets are visited
	# once, in order, with no heap to keep.
	const PER_LEVEL := 100.0
	var buckets := int((GenRelief.MAX_LEVEL + 3) * PER_LEVEL)
	var bucket_top := PackedInt32Array()
	bucket_top.resize(buckets)
	bucket_top.fill(-1)
	var queued := PackedInt32Array()
	queued.resize(cn)
	var order := PackedInt32Array()
	for k in cn:
		if landc[k] != 0:
			continue
		seen[k] = 1
		var gx := k % cw
		var gy := k / cw
		var coastal := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := gx + dx
				var ny := gy + dy
				if nx >= 0 and ny >= 0 and nx < cw and ny < cw and landc[ny * cw + nx] != 0:
					coastal = true
		if coastal:
			queued[k] = bucket_top[0]
			bucket_top[0] = k
	var cur := 0
	while cur < buckets:
		var k := bucket_top[cur]
		if k < 0:
			cur += 1
			continue
		bucket_top[cur] = queued[k]
		order.append(k)
		var gx := k % cw
		var gy := k / cw
		var fk := filled[k] + 0.01
		for dy in range(-1, 2):
			var ny := gy + dy
			if ny < 0 or ny >= cw:
				continue
			for dx in range(-1, 2):
				var nx := gx + dx
				if nx < 0 or nx >= cw:
					continue
				var nb := ny * cw + nx
				if seen[nb] != 0:
					continue
				seen[nb] = 1
				var f := maxf(ec[nb], fk)
				filled[nb] = f
				parent[nb] = k
				var bk := clampi(int(f * PER_LEVEL), cur + 1, buckets - 1)
				queued[nb] = bucket_top[bk]
				bucket_top[bk] = nb
	c.mark(&"rivers.flood")
	var acc := PackedFloat32Array()
	acc.resize(cn)
	for k in cn:
		if landc[k] != 0:
			acc[k] = rain_p[k]
	for j in range(order.size() - 1, -1, -1):
		var k := order[j]
		if parent[k] >= 0:
			acc[parent[k]] += acc[k]
	var threshold := maxf(12.0, RIVER_CATCHMENT * c.k * c.k)
	var is_river := PackedByteArray()
	is_river.resize(cn)
	var has_child := PackedByteArray()
	has_child.resize(cn)
	for k in cn:
		if landc[k] != 0 and acc[k] >= threshold:
			is_river[k] = 1
	for k in cn:
		if is_river[k] != 0 and parent[k] >= 0:
			has_child[parent[k]] = 1
	# Each river's head is walked back uphill along its biggest feeder until
	# the catchment is a mere runnel: rivers rise on the high ground.
	var best_child := PackedInt32Array()
	best_child.resize(cn)
	best_child.fill(-1)
	for k in cn:
		var p := parent[k]
		if p >= 0 and landc[k] != 0 and (best_child[p] < 0 or acc[k] > acc[best_child[p]]):
			best_child[p] = k
	var head_acc := threshold * HEAD_SHARE
	var sources: Array[Vector2i] = []
	for k in cn:
		if is_river[k] != 0 and has_child[k] == 0:
			var head := k
			while best_child[head] >= 0 and acc[best_child[head]] >= head_acc:
				head = best_child[head]
			sources.append(Vector2i(roundi(ec[head] * 100.0), head))
	# Highest sources first: the long rivers claim their courses, the rest join.
	sources.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y))
	var traced := PackedByteArray()
	traced.resize(cn)
	c.river_e = PackedFloat32Array()
	c.river_e.resize(c.n)
	var count := 0
	for src in sources:
		if count >= MAX_RIVERS:
			break
		var cells := PackedInt32Array()
		var k := src.y
		var joined := false
		while k >= 0:
			cells.append(k)
			if landc[k] == 0:
				break
			if traced[k] != 0 and cells.size() > 1:
				joined = true
				break
			k = parent[k]
		if cells.size() < (6 if joined else 10):
			continue
		for kk in cells:
			traced[kk] = 1
		var pts := PackedVector2Array()
		for kk in cells:
			pts.append(Vector2(GenFields.cell_centre(kk % cw, step), GenFields.cell_centre(kk / cw, step)))
		if not joined and pts.size() >= 2:
			# Carry the mouth out past the waterline.
			pts.append(pts[pts.size() - 1] + (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized() * 4.0)
		var accs := PackedFloat32Array()
		for kk in cells:
			accs.append(acc[kk] / threshold)
		if _lay(c, pts, accs, joined, count):
			count += 1
	c.mark(&"rivers.lay")
	_carve_valleys(c)
	c.mark(&"rivers.valleys")


## Rasterise one river. Returns false if it laid nothing useful.
static func _lay(c: GenContext, pts: PackedVector2Array, accs: PackedFloat32Array, joined: bool, index: int) -> bool:
	var size := c.size
	var land := c.land
	var water := c.water
	var elev := c.elev
	var river_e := c.river_e
	# Chaikin twice: corners of the drainage lattice become bends.
	for it in 2:
		var sm := PackedVector2Array()
		var sa := PackedFloat32Array()
		sm.append(pts[0])
		sa.append(accs[0])
		for j in pts.size() - 1:
			var a := pts[j]
			var b := pts[j + 1]
			var aa := accs[mini(j, accs.size() - 1)]
			var ab := accs[mini(j + 1, accs.size() - 1)]
			sm.append(a.lerp(b, 0.25))
			sm.append(a.lerp(b, 0.75))
			sa.append(lerpf(aa, ab, 0.25))
			sa.append(lerpf(aa, ab, 0.75))
		sm.append(pts[pts.size() - 1])
		sa.append(accs[accs.size() - 1])
		pts = sm
		accs = sa
	var meander := GenFields.noise(c.s, 401 + index, 1.0 / 24.0, 2)
	var tiles := PackedInt32Array()
	var widths := PackedByteArray()
	var normals := PackedVector2Array()
	var arc := 0.0
	var last := -1
	var total := 0.0
	for j in pts.size() - 1:
		total += pts[j].distance_to(pts[j + 1])
	for j in pts.size() - 1:
		var a := pts[j]
		var b := pts[j + 1]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var dir := (b - a) / seg
		var nrm := Vector2(-dir.y, dir.x)
		var steps := maxi(1, ceili(seg / 0.3))
		for t in steps:
			var f := float(t) / steps
			var along := arc + seg * f
			var taper := clampf(minf(along, total - along) / 12.0, 0.0, 1.0)
			var p := a.lerp(b, f) + nrm * meander.get_noise_2d(along, 0.0) * 5.0 * taper
			var tx := clampi(floori(p.x), 1, size - 2)
			var ty := clampi(floori(p.y), 1, size - 2)
			var i := ty * size + tx
			if i == last:
				continue
			var ac := lerpf(accs[j], accs[mini(j + 1, accs.size() - 1)], f)
			var wdt := 1 if ac < 4.0 else (2 if ac < 14.0 else 3)
			if not joined and wdt >= 2 and total - along < 16.0:
				wdt += 1
			if last >= 0:
				var lx := last % size
				var ly := last / size
				if lx != tx and ly != ty:
					# Keep the channel 4-connected so water never leaks corner to corner.
					tiles.append(ly * size + tx)
					widths.append(wdt)
					normals.append(nrm)
			tiles.append(i)
			widths.append(wdt)
			normals.append(nrm)
			last = i
		arc += seg
	# Bed: never rises downstream, at least level 1 until the sea.
	var beds := PackedFloat32Array()
	beds.resize(tiles.size())
	var running := 1e9
	var end := tiles.size()
	for j in tiles.size():
		var i := tiles[j]
		if land[i] == 0:
			end = j
			break
		if joined and j > 2 and water[i] == 1:
			end = j
			break
		running = maxf(1.0, minf(running, elev[i] - 0.55))
		beds[j] = running
	if end < 4:
		return false
	if joined and end < tiles.size():
		# Meet the trunk at its own bed: never below it, and fall to it gently.
		var trunk := river_e[tiles[end]]
		for j in end:
			beds[j] = maxf(minf(beds[j], trunk + (end - j) * 0.7), trunk)
	var line := PackedVector2Array()
	for j in end:
		var i := tiles[j]
		var bed := beds[j]
		line.append(Vector2(i % size + 0.5, i / size + 0.5))
		_wet(c, i, bed)
		var wdt := widths[j]
		if wdt >= 2:
			_wet(c, _side_tile(c, i, normals[j]), bed)
		if wdt >= 3:
			_wet(c, _side_tile(c, i, -normals[j]), bed)
		if wdt >= 4:
			var side := _side_tile(c, i, normals[j])
			if side >= 0:
				_wet(c, _side_tile(c, side, normals[j]), bed)
	c.rivers.append(line)
	return true


static func _wet(c: GenContext, i: int, bed: float) -> void:
	if i < 0 or c.land[i] == 0:
		return
	if c.water[i] == 1:
		c.river_e[i] = minf(c.river_e[i], bed)
	else:
		c.water[i] = 1
		c.river_e[i] = bed
	c.elev[i] = c.river_e[i]


static func _side_tile(c: GenContext, i: int, nrm: Vector2) -> int:
	var size := c.size
	var x := i % size
	var y := i / size
	var ox := 0
	var oy := 0
	if absf(nrm.x) >= absf(nrm.y):
		ox = 1 if nrm.x > 0.0 else -1
	else:
		oy = 1 if nrm.y > 0.0 else -1
	var nx := x + ox
	var ny := y + oy
	if nx < 1 or ny < 1 or nx >= size - 1 or ny >= size - 1:
		return -1
	return ny * size + nx


## Valley sides: nothing within reach of a river stands higher than the bed
## plus a per-country slope times the distance, so banks stay walkable (or
## become gorges where the slope cost is high).
static func _carve_valleys(c: GenContext) -> void:
	# Worked at half resolution: a valley side is smooth over two tiles, and the
	# bed itself is exact because river tiles keep their own elevation.
	var size := c.size
	var hw := GenFields.coarse_width(size, 2)
	var coarse_cost: PackedFloat32Array = GenCountries.params(c, [&"valley"])[&"valley"]
	var cost := GenFields.upsample(coarse_cost, c.cw, 2, hw)
	for k in cost.size():
		cost[k] *= 2.0
	var water := c.water
	var land := c.land
	var elev := c.elev
	var river_e := c.river_e
	var v := PackedFloat32Array()
	v.resize(hw * hw)
	v.fill(1e6)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var row := y * size
			var hrow := (y >> 1) * hw
			for x in size:
				var i := row + x
				if water[i] == 1:
					var k := hrow + (x >> 1)
					v[k] = minf(v[k], river_e[i] + 0.9)
	)
	# A valley side climbs at least 0.6 levels a cell: 26 cells reach past the
	# highest ground.
	v = GenFields.banded([v, cost], hw, 26, func(arrays: Array, width: int) -> Array:
		var vv: PackedFloat32Array = arrays[0]
		GenFields.propagate_min_field(vv, width, arrays[1])
		return [vv, arrays[1]]
	)[0]
	var up := GenFields.upsample(v, hw, 2, size)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			if land[i] != 0 and water[i] == 0 and up[i] < elev[i]:
				elev[i] = maxf(1.0, up[i])
	)


## Pools and tarns, after terracing: round, a dozen tiles or more, on flat
## dry ground, sited on a jittered grid so they never crowd. Blackwater pools
## pock the Moss (more of them deeper in), tarns freeze on the Snowfield's
## flats, the odd tarn lies in the Pinewood and behind the Coast. Each is a
## distance field about its centre, lobed so no two are the same shape.

static func still(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var land := c.land
	var water := c.water
	var level := w.level
	var country := w.country
	var blend := w.blend
	# Cell size in tiles, chance a cell holds a pool, radius range and the water
	# itself all come from the landscape (BiomeDef.pools), laid in the order
	# each declares so the wettest land gets its pools first.
	var laid := PackedVector3Array()
	var pooled: Array[int] = []
	for cc: int in c.land_types:
		if not c.defs[cc].pools.is_empty():
			pooled.append(cc)
	pooled.sort_custom(func(x: int, y: int) -> bool:
		return int(c.defs[x].pools.get("order", 50)) < int(c.defs[y].pools.get("order", 50)))
	for cc: int in pooled:
		var spec: Dictionary = c.defs[cc].pools
		var cell := int(spec.cell)
		var cells := size / cell
		for gy in cells:
			for gx in cells:
				var salt := cc * 7919
				var cx0 := (gx + 0.5) * cell
				var cy0 := (gy + 0.5) * cell
				var ci := clampi(floori(cy0), 0, size - 1) * size + clampi(floori(cx0), 0, size - 1)
				if country[ci] != cc:
					continue
				if GenFields.h01(c.s, gx, gy, 442 + salt) > float(spec.chance) * (1.0 - blend[ci]):
					continue
				var r := lerpf(float(spec.r_min), float(spec.r_max), GenFields.h01(c.s, gx, gy, 443 + salt))
				# A few spots in the cell: pools need a flat to lie on.
				for attempt in 5:
					var px := (gx + 0.2 + GenFields.h01(c.s, gx * 8 + attempt, gy, 440 + salt) * 0.6) * cell
					var py := (gy + 0.2 + GenFields.h01(c.s, gx * 8 + attempt, gy, 441 + salt) * 0.6) * cell
					var tx := floori(px)
					var ty := floori(py)
					if tx < 8 or ty < 8 or tx >= size - 8 or ty >= size - 8:
						continue
					var i0 := ty * size + tx
					if country[i0] != cc or land[i0] == 0 or c.inland[i0] < 6.0:
						continue
					var centre := Vector3(px, py, r)
					var crowded := false
					for q in laid:
						if Vector2(q.x, q.y).distance_to(Vector2(px, py)) < q.z + r + 5.0:
							crowded = true
							break
					if not crowded and _lay_pool(c, centre, gx * 31 + gy * 17 + cc, int(spec.ground)):
						laid.append(centre)
						break
	c.pools = laid


## Pool tiles for a centre: lobed disc, only where level matches the centre.
## Writes water = 2 and returns true if the pool is whole enough to keep.
static func _lay_pool(c: GenContext, p: Vector3, salt: int, g: int) -> bool:
	var size := c.size
	var level := c.w.level
	var l0 := level[floori(p.y) * size + floori(p.x)]
	var ri := ceili(p.z * 1.3) + 2
	var ph1 := GenFields.h01(c.s, salt, 0, 444) * TAU
	var ph2 := GenFields.h01(c.s, salt, 1, 444) * TAU
	var inside := PackedInt32Array()
	var total := 0
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			var i := y * size + x
			var q := Vector2(x + 0.5 - p.x, y + 0.5 - p.y)
			var ang := q.angle()
			var edge := p.z * (1.0 + 0.2 * sin(ang * 2.0 + ph1) + 0.1 * sin(ang * 3.0 + ph2))
			var d := q.length()
			if d < edge + 2.0:
				# The pool and the ground round it: dry land, no river.
				if c.land[i] == 0 or c.water[i] != 0:
					return false
			if d >= edge:
				continue
			total += 1
			if level[i] == l0 and level[i - 1] >= l0 and level[i + 1] >= l0 and level[i - size] >= l0 and level[i + size] >= l0:
				inside.append(i)
	if inside.size() < 12 or inside.size() < total * 0.8:
		return false
	for i in inside:
		c.water[i] = 2
		c.pool_ground[i] = g
	return true


## Drain every pool with a tile inside the circle (whole pools only, so none
## is left as a sliver).
static func drain_pools(c: GenContext, at: Vector2, radius: float) -> void:
	for q in c.pools:
		if Vector2(q.x, q.y).distance_to(at) >= radius + q.z * 1.3:
			continue
		var ri := ceili(q.z * 1.3) + 1
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var x := floori(q.x) + dx
				var y := floori(q.y) + dy
				if x < 0 or y < 0 or x >= c.size or y >= c.size:
					continue
				var i := y * c.size + x
				if c.water[i] == 2:
					c.water[i] = 0


## Drain every pool a road runs through, whole, so none is left as slivers.
static func drain_crossed(c: GenContext) -> void:
	for q in c.pools:
		var ri := ceili(q.z * 1.3) + 1
		var crossed := false
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var x := floori(q.x) + dx
				var y := floori(q.y) + dy
				if x >= 0 and y >= 0 and x < c.size and y < c.size and c.road[y * c.size + x] != 0:
					crossed = true
		if crossed:
			drain_pools(c, Vector2(q.x, q.y), 0.0)
