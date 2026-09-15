class_name GenWater
## Stage 4: rivers and still water.
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
	var heap_p := PackedFloat32Array()
	var heap_i := PackedInt32Array()
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
			_push(heap_p, heap_i, 0.0, k)
	while not heap_i.is_empty():
		var k := _pop(heap_p, heap_i)
		order.append(k)
		var gx := k % cw
		var gy := k / cw
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
				filled[nb] = maxf(ec[nb], filled[k] + 0.01)
				parent[nb] = k
				_push(heap_p, heap_i, filled[nb], nb)
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
	var sources: Array[Vector2i] = []
	for k in cn:
		if is_river[k] != 0 and has_child[k] == 0:
			sources.append(Vector2i(roundi(ec[k] * 100.0), k))
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


static func _push(hp: PackedFloat32Array, hi: PackedInt32Array, p: float, id: int) -> void:
	hp.append(p)
	hi.append(id)
	var j := hp.size() - 1
	while j > 0:
		var parent := (j - 1) >> 1
		if hp[parent] <= p:
			break
		hp[j] = hp[parent]
		hi[j] = hi[parent]
		j = parent
	hp[j] = p
	hi[j] = id


static func _pop(hp: PackedFloat32Array, hi: PackedInt32Array) -> int:
	var top := hi[0]
	var last := hp.size() - 1
	var p := hp[last]
	var id := hi[last]
	hp.resize(last)
	hi.resize(last)
	if last == 0:
		return top
	var j := 0
	while true:
		var l := j * 2 + 1
		if l >= last:
			break
		var r := l + 1
		var m := l
		if r < last and hp[r] < hp[l]:
			m = r
		if hp[m] >= p:
			break
		hp[j] = hp[m]
		hi[j] = hi[m]
		j = m
	hp[j] = p
	hi[j] = id
	return top


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
	for y in size:
		var row := y * size
		var hrow := (y >> 1) * hw
		for x in size:
			var i := row + x
			if water[i] == 1:
				var k := hrow + (x >> 1)
				v[k] = minf(v[k], river_e[i] + 0.9)
	GenFields.propagate_min_field(v, hw, cost)
	var up := GenFields.upsample(v, hw, 2, size)
	for i in c.n:
		if land[i] != 0 and water[i] == 0 and up[i] < elev[i]:
			elev[i] = maxf(1.0, up[i])


## Pools and tarns, on flat ground only, after terracing.
static func still(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var pools := GenFields.noise(c.s, 431, 1.0 / 8.0, 2)
	var fields := GenFields.field(GenFields.noise(c.s, 432, 1.0 / 46.0, 2), size, 4)
	var land := c.land
	var water := c.water
	var level := w.level
	var country := w.country
	var blend := w.blend
	var marked := PackedInt32Array()
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			var i := y * size + x
			if land[i] == 0 or water[i] != 0:
				continue
			var thr := 9.0
			var fl := fields[i]
			match country[i]:
				Country.MOSS:
					# Pools crowd together deeper into the fen.
					thr = 0.2 + blend[i] * 0.9 - maxf(0.0, fl) * 0.3
				Country.SNOWFIELD:
					thr = 0.42 - maxf(0.0, fl) * 0.2
				Country.PINEWOOD:
					thr = 0.5 - maxf(0.0, fl) * 0.1
				Country.COAST:
					thr = 0.56 - maxf(0.0, fl) * 0.1
			if thr > 1.0:
				continue
			var l := level[i]
			if level[i - 1] != l or level[i + 1] != l or level[i - size] != l or level[i + size] != l:
				continue
			if pools.get_noise_2d(x, y) + fl * 0.25 < thr:
				continue
			water[i] = 2
			marked.append(i)
	# Erode twice: puddles and slivers go, round pools stay.
	for round_i in 2:
		var drop := PackedInt32Array()
		for i in marked:
			if water[i] != 2:
				continue
			var nb := int(water[i - 1] == 2) + int(water[i + 1] == 2) + int(water[i - size] == 2) + int(water[i + size] == 2)
			if nb < 2:
				drop.append(i)
		for i in drop:
			water[i] = 0
