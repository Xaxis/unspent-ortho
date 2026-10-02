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
## On a world of several bodies, the height a river's source rises from at least
## (`rivers`): what the eleventh highest source in the world stood at when one
## budget served every body.
const RIVER_HEAD := 11.0
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
	var threshold := maxf(12.0, RIVER_CATCHMENT * c.body_k * c.body_k)
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
	# EACH CONTINENT KEEPS ITS OWN RIVERS: every source that rises from RIVER_HEAD
	# or higher, up to MAX_RIVERS a body, which asks nothing of any other body.
	# One budget for the world took its eleven highest sources wherever they
	# stood, so a landscape raised on another continent took home's rivers away;
	# shared by size instead, home lost two thirds of its own. Asked of the
	# source, a world lays about the rivers it did (seeds 1, 7, 42, 90210: 12,
	# 9, 14 and 7 against 11) and home the ones its own high ground carries.
	var bodies := maxi(1, c.bodies.size())
	var count := 0
	var laid := {}
	for src in sources:
		if bodies <= 1 and count >= MAX_RIVERS:
			break
		if bodies > 1 and src.x < roundi(RIVER_HEAD * 100.0):
			break
		var body := c.w.continent_at(roundi(GenFields.cell_centre(src.y % cw, step)), roundi(GenFields.cell_centre(src.y / cw, step)))
		if bodies > 1 and int(laid.get(body, 0)) >= MAX_RIVERS:
			continue
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
		# Meandered from its own source cell, not its place in the world's count.
		if _lay(c, pts, accs, joined, count if bodies <= 1 else Rng.hash_ints(src.y, body) & 0xFFFF):
			count += 1
			laid[body] = int(laid.get(body, 0)) + 1
	c.mark(&"rivers.lay")
	_settle_crossings(c)
	_carve_valleys(c)
	c.mark(&"rivers.valleys")


## WHERE TWO RIVERS CROSS, the one laid later can take the shared tiles below
## the other's bed (`_wet` keeps the lower), and the first then climbs back out
## of the crossing. Each line is walked from its source and its bed held at or
## under every bed behind it, until nothing moves.
static func _settle_crossings(c: GenContext) -> void:
	var size := c.size
	var river_e := c.river_e
	var elev := c.elev
	for pass_n in 4:
		var moved := false
		for line in c.rivers:
			var running := 1e9
			for p in line:
				var i := int(p.y) * size + int(p.x)
				if river_e[i] > running:
					river_e[i] = running
					elev[i] = running
					moved = true
				else:
					running = river_e[i]
		if not moved:
			return


## Rasterise one river. Returns false if it laid nothing useful.
static func _lay(c: GenContext, pts: PackedVector2Array, accs: PackedFloat32Array, joined: bool, index: int) -> bool:
	var size := c.size
	var land := c.land
	var water := c.water
	var elev := c.elev
	var river_e := c.river_e
	var lift := c.slot_lift
	var lifted := not lift.is_empty()
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
	var simple := _cut_loops(tiles, widths, normals)
	tiles = simple[0]
	widths = simple[1]
	normals = simple[2]
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
		running = maxf(1.0, minf(running, elev[i] - (lift[i] if lifted else 0.0) - 0.55))
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


## A RIVER IS A SIMPLE PATH: where the traced line folds back onto a tile it has
## already crossed, the loop between the two visits is cut out. The meander noise
## and the corner fill make almost every line fold somewhere (10 or 11 of 11 rivers
## a seed at 1300), and a tile keeps ONE bed -- the lowest of its visits -- so a
## fold after a drop left a tile the river had passed at the higher bed and then
## returned to: water standing a level above the water beside it, and a line that
## climbs (seed 90210, river 4, at 982,280: beds 7.3 then 5.8 then 7.3 again). With
## one visit per tile, a tile's bed is its visit's bed, and the beds never rise.
## Only the interior is cut: the source and the mouth are where they were, since
## a loop closes on a tile the path already holds. The wider of the two visits'
## widths is kept. Packed arrays are values here, so the simple path is RETURNED.
static func _cut_loops(tiles: PackedInt32Array, widths: PackedByteArray, normals: PackedVector2Array) -> Array:
	var at := {}
	var t := PackedInt32Array()
	var wd := PackedByteArray()
	var nm := PackedVector2Array()
	for k in tiles.size():
		var i := tiles[k]
		if at.has(i):
			var keep: int = at[i]
			for m in range(keep + 1, t.size()):
				at.erase(t[m])
			t.resize(keep + 1)
			wd.resize(keep + 1)
			nm.resize(keep + 1)
			wd[keep] = maxi(wd[keep], widths[k])
			continue
		at[i] = t.size()
		t.append(i)
		wd.append(widths[k])
		nm.append(normals[k])
	return [t, wd, nm]


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
## THE VALLEY FIELD IS CAPPED at one level over the tallest land: nothing at or
## above it can carve, and capped, a value is decided by paths costing less
## than the cap, which the cheapest valley (0.4 a half-cell) holds within
## VALLEY_REACH half-cells. So a section with that much round its own tiles,
## and its rows on the world's bands with their reach, carves them as the whole
## world does (streamed worldgen S4g; tests/stream/test_valley_window.gd).
const VALLEY_CAP := GenRelief.MAX_LEVEL + 1.0
const VALLEY_REACH := 78
## The bands the field is swept in, and how far each sweeps past its own rows:
## a valley side climbs at least 0.6 levels a cell, so this many cells reach
## past the highest ground.
const VALLEY_BAND := 24
const VALLEY_BAND_REACH := ceili((GenRelief.MAX_LEVEL + 1) / 0.6)

## A test's hook: set, `_carve_valleys` keeps what it carves from in `before`.
static var keeping := false
static var before: Dictionary = {}


static func _carve_valleys(c: GenContext) -> void:
	# Worked at half resolution: a valley side is smooth over two tiles, and the
	# bed itself is exact because river tiles keep their own elevation.
	var coarse_cost: PackedFloat32Array = GenCountries.params(c, [&"valley"])[&"valley"]
	if keeping:
		before = {"elev": GenFields.snapshot(c.elev), "water": GenFields.snapshot(c.water), "river_e": GenFields.snapshot(c.river_e),
			"land": GenFields.snapshot(c.land), "cost": GenFields.snapshot(coarse_cost), "cw": c.cw, "size": c.size}
	carve(c.elev, c.water, c.land, c.river_e, coarse_cost, c.cw, c.size, Rect2i(0, 0, c.size, c.size))


## Carve the valleys into `elev` over the tiles of `core`, from arrays that are
## the whole world's: the whole world as one core, or a section, which reads only
## the tiles within its reach (`valley_window`).
static func carve(elev: PackedFloat32Array, water: PackedByteArray, land: PackedByteArray, river_e: PackedFloat32Array,
		coarse_cost: PackedFloat32Array, cw: int, size: int, core: Rect2i) -> void:
	var hw := GenFields.coarse_width(size, 2)
	var win := valley_window(core, size)
	var gx0 := win.position.x
	var gy0 := win.position.y
	var ww := win.size.x
	var wh := win.size.y
	var cost_all := GenFields.upsample(coarse_cost, cw, 2, hw) if win.size.x == hw and win.size.y == hw else PackedFloat32Array()
	var cost := PackedFloat32Array()
	cost.resize(ww * wh)
	if not cost_all.is_empty():
		for k in cost.size():
			cost[k] = cost_all[k] * 2.0
	else:
		var part := GenFields.upsample_rect(coarse_cost, cw, cw, 0, 0, cw, 2, hw, gx0, gy0, ww, wh)
		for k in cost.size():
			cost[k] = part[k] * 2.0
	var v := PackedFloat32Array()
	v.resize(ww * wh)
	v.fill(1e6)
	GenFields.rows(wh, func(h0: int, h1: int) -> void:
		for hy in range(h0, h1):
			for hx in ww:
				# The half-cell's four tiles.
				for dy in 2:
					var y := (gy0 + hy) * 2 + dy
					if y >= size:
						continue
					for dx in 2:
						var x := (gx0 + hx) * 2 + dx
						if x >= size:
							continue
						var i := y * size + x
						if water[i] == 1:
							var k := hy * ww + hx
							v[k] = minf(v[k], river_e[i] + 0.9)
	)
	v = GenFields.banded([v, cost], ww, VALLEY_BAND_REACH, func(arrays: Array, width: int) -> Array:
		var vv: PackedFloat32Array = arrays[0]
		GenFields.propagate_min_field(vv, width, arrays[1])
		return [vv, arrays[1]]
	, VALLEY_BAND)[0]
	GenFields.rows(wh, func(h0: int, h1: int) -> void:
		for k in range(h0 * ww, h1 * ww):
			v[k] = minf(v[k], VALLEY_CAP)
	)
	var up := GenFields.upsample_rect(v, ww, wh, gx0, gy0, hw, 2, size, core.position.x, core.position.y, core.size.x, core.size.y)
	GenFields.rows(core.size.y, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			for x in core.size.x:
				var i := (core.position.y + y) * size + core.position.x + x
				var u := up[y * core.size.x + x]
				if land[i] != 0 and water[i] == 0 and u < elev[i]:
					elev[i] = maxf(1.0, u)
	)


## The half-resolution cells a section's valleys are swept over: VALLEY_REACH
## round its own cells across, and down whole bands of the world's, with each
## band's reach, so every band it holds is swept over the rows the whole world
## sweeps it over.
static func valley_window(core: Rect2i, size: int) -> Rect2i:
	var hw := GenFields.coarse_width(size, 2)
	if core == Rect2i(0, 0, size, size):
		return Rect2i(0, 0, hw, hw)
	var cx0 := maxi(0, floori(core.position.x / 2.0) - VALLEY_REACH - 1)
	var cx1 := mini(hw, ceili(core.end.x / 2.0) + VALLEY_REACH + 1)
	var b0 := floori(maxf(0.0, floor(core.position.y / 2.0) - 1.0) / VALLEY_BAND)
	var b1 := ceili(minf(hw, ceilf(core.end.y / 2.0) + 1.0) / VALLEY_BAND)
	var cy0 := maxi(0, b0 * VALLEY_BAND - VALLEY_BAND_REACH)
	cy0 = floori(float(cy0) / VALLEY_BAND) * VALLEY_BAND
	var cy1 := mini(hw, b1 * VALLEY_BAND + VALLEY_BAND_REACH)
	return Rect2i(cx0, cy0, cx1 - cx0, cy1 - cy0)


## Pools and tarns, after terracing: round, a dozen tiles or more, on flat
## dry ground, sited on a jittered grid so they never crowd. Blackwater pools
## pock the Moss (more of them deeper in), tarns freeze on the Snowfield's
## flats, the odd tarn lies in the Pinewood and behind the Coast. Each is a
## distance field about its centre, lobed so no two are the same shape.

## And with `keeping` set, `still` keeps what it lays pools on here.
static var before_still: Dictionary = {}

## POOLS ARE DECIDED WHERE THEY LIE (streamed worldgen S4g). Each landscape's
## cell proposes the first of its spots where a whole pool would lie, from the
## land alone. In two rounds, a proposal stands when it outranks every other
## within its crowding reach -- the landscape's `order` first (the wettest land
## keeps its pools), then a roll of its own -- and in the second round only the
## proposals no first-round pool crowds out are weighed, so a proposal that lost
## to one that itself lost can still stand (one round cost the moss a fifth of
## its pools). Nothing about it hangs on which pools were laid before, so a
## section with POOL_MARGIN round its own tiles lays their pools as the whole
## world does (tests/stream/test_pool_window.gd). The reach keeps two standing
## pools' discs and their dry rims apart.
const POOL_GAP := 5.0
const POOL_SPREAD := 1.3
## A section's pools are judged over its tiles and the crowding reach round
## them (plus a pool's own reach); the second round weighs proposals a reach
## further, whose standing hangs on the first round two reaches further again;
## each proposal comes from a cell up to the largest cell's width beyond, and
## reads its disc and rim round its spot.
const POOL_R_MOST := 5.5
const POOL_CELL_MOST := 52
const POOL_REACH := ceili(maxf(2.0 * POOL_R_MOST + POOL_GAP, POOL_SPREAD * 2.0 * POOL_R_MOST + 3.0)) + 10
const POOL_MARGIN := 4 * POOL_REACH + POOL_CELL_MOST + 10


static func still(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	if keeping:
		before_still = {"level": GenFields.snapshot(w.level), "land": GenFields.snapshot(c.land), "water": GenFields.snapshot(c.water),
			"country": GenFields.snapshot(w.country), "blend": GenFields.snapshot(w.blend), "inland": GenFields.snapshot(c.inland)}
	c.pools = pools_square(c.s, pool_specs(c), w.level, c.land, c.water, w.country, w.blend, c.inland, size, Vector2i.ZERO, size,
		Rect2i(0, 0, size, size), c.pool_ground)


## Cell size in tiles, chance a cell holds a pool, radius range and the water
## itself come from each landscape (BiomeDef.pools): [type, spec], wettest first.
static func pool_specs(c: GenContext) -> Array:
	var out: Array = []
	for cc: int in c.land_types:
		if not c.defs[cc].pools.is_empty():
			out.append([cc, c.defs[cc].pools])
	out.sort_custom(func(x: Array, y: Array) -> bool:
		return int(x[1].get("order", 50)) < int(y[1].get("order", 50)))
	return out


## The pools whose water lies in `core`, over a square of the world `side` wide
## at `origin` (the whole world, or a section with POOL_MARGIN round its core):
## each one's tiles in the core get water 2 and its ground, and the standing
## pools touching the core come back as (x, y, r).
static func pools_square(seed_value: int, specs: Array, level: PackedInt32Array, land: PackedByteArray, water: PackedByteArray,
		country: PackedByteArray, blend: PackedFloat32Array, inland: PackedFloat32Array, side: int, origin: Vector2i,
		world_size: int, core: Rect2i, pool_ground: PackedByteArray) -> PackedVector3Array:
	var judged := core.grow(POOL_REACH)
	var asked := judged.grow(3 * POOL_REACH)
	# Proposals: [x, y, r, rank, rank roll, ground, tiles (world indices),
	# the spot's place among its cell's, the cell]. A cell proposes every spot
	# where a whole pool would lie: its first may be crowded out where a later
	# one is not.
	var props: Array = []
	for k in specs.size():
		var cc: int = specs[k][0]
		var spec: Dictionary = specs[k][1]
		var cell := int(spec.cell)
		var cells := world_size / cell
		var salt := cc * 7919
		for gy in range(maxi(0, floori(float(asked.position.y) / cell)), mini(cells, ceili(float(asked.end.y) / cell))):
			for gx in range(maxi(0, floori(float(asked.position.x) / cell)), mini(cells, ceili(float(asked.end.x) / cell))):
				var cx0 := (gx + 0.5) * cell
				var cy0 := (gy + 0.5) * cell
				var ci := _at(clampi(floori(cx0), 0, world_size - 1), clampi(floori(cy0), 0, world_size - 1), origin, side)
				if ci < 0 or country[ci] != cc:
					continue
				if GenFields.h01(seed_value, gx, gy, 442 + salt) > float(spec.chance) * (1.0 - blend[ci]):
					continue
				var r := lerpf(float(spec.r_min), float(spec.r_max), GenFields.h01(seed_value, gx, gy, 443 + salt))
				# A few spots in the cell: pools need a flat to lie on.
				for attempt in 5:
					var px := (gx + 0.2 + GenFields.h01(seed_value, gx * 8 + attempt, gy, 440 + salt) * 0.6) * cell
					var py := (gy + 0.2 + GenFields.h01(seed_value, gx * 8 + attempt, gy, 441 + salt) * 0.6) * cell
					var tx := floori(px)
					var ty := floori(py)
					if tx < 8 or ty < 8 or tx >= world_size - 8 or ty >= world_size - 8:
						continue
					var i0 := _at(tx, ty, origin, side)
					if i0 < 0 or country[i0] != cc or land[i0] == 0 or inland[i0] < 6.0:
						continue
					var tiles := _pool_tiles(seed_value, Vector3(px, py, r), gx * 31 + gy * 17 + cc, level, land, water, origin, side, world_size)
					if tiles.is_empty():
						continue
					props.append([px, py, r, k, GenFields.h01(seed_value, gx, gy, 445 + salt), int(spec.ground), tiles, attempt,
						Vector3i(cc, gx, gy)])
	# Proposals by 32-tile bucket: wider than any crowding reach (17.3 tiles), and a
	# cell's own spots lie within three buckets of each other.
	var buckets := {}
	for n in props.size():
		var key := Vector2i(floori(float(props[n][0]) / 32.0), floori(float(props[n][1]) / 32.0))
		var list: PackedInt32Array = buckets.get(key, PackedInt32Array())
		list.append(n)
		buckets[key] = list
	# The proposals crowding each: within its reach and the other's.
	var rivals: Array[PackedInt32Array] = []
	rivals.resize(props.size())
	for n in props.size():
		var a: Array = props[n]
		var at := Vector2(a[0], a[1])
		var home := Vector2i(floori(at.x / 32.0), floori(at.y / 32.0))
		var cell_a: Vector3i = a[8]
		var list := PackedInt32Array()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for m: int in buckets.get(home + Vector2i(dx, dy), PackedInt32Array()):
					var b: Array = props[m]
					var cell_b: Vector3i = b[8]
					# A cell holds one pool: its own spots are always rivals.
					if m != n and (cell_b == cell_a or at.distance_to(Vector2(b[0], b[1])) < _crowd(float(a[2]), float(b[2]))):
						list.append(m)
		rivals[n] = list
	# Round one: the proposals that outrank all their rivals.
	var first := PackedByteArray()
	first.resize(props.size())
	for n in props.size():
		var best := true
		for m in rivals[n]:
			if _outranks(props[m], props[n]):
				best = false
				break
		first[n] = 1 if best else 0
	# Round two: of the proposals no round-one pool crowds, those that outrank
	# every such rival.
	var open := PackedByteArray()
	open.resize(props.size())
	for n in props.size():
		if first[n] != 0:
			continue
		var free := true
		for m in rivals[n]:
			if first[m] != 0:
				free = false
				break
		open[n] = 1 if free else 0
	var out := PackedVector3Array()
	for n in props.size():
		var a: Array = props[n]
		var at := Vector2(a[0], a[1])
		if not judged.has_point(Vector2i(at.floor())):
			continue
		var stands := first[n] != 0
		if not stands and open[n] != 0:
			stands = true
			for m in rivals[n]:
				if open[m] != 0 and _outranks(props[m], a):
					stands = false
					break
		if not stands:
			continue
		var touches := false
		for i: int in a[6]:
			var p := Vector2i(i % world_size, i / world_size)
			if not core.has_point(p):
				continue
			var li := _at(p.x, p.y, origin, side)
			water[li] = 2
			pool_ground[li] = a[5]
			touches = true
		if touches:
			out.append(Vector3(a[0], a[1], a[2]))
	return out


## How near two pools of radius ra and rb may stand: the spacing pools have
## always kept, or, where larger, what keeps one's disc and its two tiles of dry
## rim off the other's water (a disc reaches POOL_SPREAD times its radius, and a
## tile is judged at its centre, half a tile either way).
static func _crowd(ra: float, rb: float) -> float:
	return maxf(ra + rb + POOL_GAP, POOL_SPREAD * (ra + rb) + 3.0)


## Proposal `b` outranks `a`: its landscape pools first, then the lower roll,
## then its cell's earlier spot, then (never met in practice, but a rank must
## be total) the earlier place.
static func _outranks(b: Array, a: Array) -> bool:
	if int(b[3]) != int(a[3]):
		return int(b[3]) < int(a[3])
	if float(b[4]) != float(a[4]):
		return float(b[4]) < float(a[4])
	if int(b[7]) != int(a[7]):
		return int(b[7]) < int(a[7])
	if float(b[1]) != float(a[1]):
		return float(b[1]) < float(a[1])
	return float(b[0]) < float(a[0])


## The index of world tile (x, y) in a square `side` wide at `origin`, or -1.
static func _at(x: int, y: int, origin: Vector2i, side: int) -> int:
	var lx := x - origin.x
	var ly := y - origin.y
	return ly * side + lx if lx >= 0 and ly >= 0 and lx < side and ly < side else -1


## Pool tiles for a centre, as world indices: a lobed disc, only where the level
## matches the centre's, the largest piece of it, or none if it is not whole
## enough to keep or its ground round it is not dry land.
static func _pool_tiles(seed_value: int, p: Vector3, salt: int, level: PackedInt32Array, land: PackedByteArray, water: PackedByteArray,
		origin: Vector2i, side: int, world_size: int) -> PackedInt32Array:
	var none := PackedInt32Array()
	var c0 := _at(floori(p.x), floori(p.y), origin, side)
	if c0 < 0:
		return none
	var l0 := level[c0]
	var ri := ceili(p.z * POOL_SPREAD) + 2
	var ph1 := GenFields.h01(seed_value, salt, 0, 444) * TAU
	var ph2 := GenFields.h01(seed_value, salt, 1, 444) * TAU
	var inside := PackedInt32Array()
	var total := 0
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			var i := _at(x, y, origin, side)
			if i < 0:
				return none
			var q := Vector2(x + 0.5 - p.x, y + 0.5 - p.y)
			var ang := q.angle()
			var edge := p.z * (1.0 + 0.2 * sin(ang * 2.0 + ph1) + 0.1 * sin(ang * 3.0 + ph2))
			var d := q.length()
			if d < edge + 2.0:
				# The pool and the ground round it: dry land, no river.
				if land[i] == 0 or water[i] != 0:
					return none
			if d >= edge:
				continue
			total += 1
			if level[i] == l0 and level[i - 1] >= l0 and level[i + 1] >= l0 and level[i - side] >= l0 and level[i + side] >= l0:
				inside.append(i)
	# One piece of water: the level test lets a fifth of the disc fall out, and
	# over a terrace step that split a pool into scraps of one to four tiles.
	inside = _largest_piece(inside, side)
	if inside.size() < 12 or inside.size() < total * 0.8:
		return none
	# Back to the world's indices, so a proposal names the same tiles in any square.
	var world := PackedInt32Array()
	for i in inside:
		world.append((origin.y + i / side) * world_size + origin.x + i % side)
	return world


## The biggest 4-connected run of `tiles` (indices into a `size`-wide grid).
static func _largest_piece(tiles: PackedInt32Array, size: int) -> PackedInt32Array:
	var left := {}
	for i in tiles:
		left[i] = true
	var best := PackedInt32Array()
	for start in tiles:
		if not left.has(start):
			continue
		var piece := PackedInt32Array([start])
		left.erase(start)
		var head := 0
		while head < piece.size():
			var i := piece[head]
			head += 1
			for j: int in [i - 1, i + 1, i - size, i + size]:
				if left.has(j):
					left.erase(j)
					piece.append(j)
		if piece.size() > best.size():
			best = piece
	return best


## Drain every pool with a tile inside the circle (whole pools only, so none
## is left as a sliver).
static func drain_pools(c: GenContext, at: Vector2, radius: float) -> void:
	drain_into(c.pools, c.water, c.size, Vector2i.ZERO, c.size, at, radius)


## `drain_pools` over a square `side` wide at `origin` in a world `world_size`
## wide: the whole world, or a section, which drains only its own tiles.
static func drain_into(pools: PackedVector3Array, water: PackedByteArray, side: int, origin: Vector2i, world_size: int,
		at: Vector2, radius: float) -> void:
	for q in pools:
		if Vector2(q.x, q.y).distance_to(at) >= radius + q.z * 1.3:
			continue
		var ri := ceili(q.z * 1.3) + 1
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var x := floori(q.x) + dx
				var y := floori(q.y) + dy
				if x < 0 or y < 0 or x >= world_size or y >= world_size:
					continue
				var i := _at(x, y, origin, side)
				if i >= 0 and water[i] == 2:
					water[i] = 0


## Drain every pool a road runs through, whole, so none is left as slivers.
static func drain_crossed(c: GenContext) -> void:
	drain_crossed_into(c.pools, c.road, c.water, c.size, Vector2i.ZERO, c.size)


## `drain_crossed` over a square: a pool is crossed when a road tile lies in its
## box, which a section sees when the box lies within it.
static func drain_crossed_into(pools: PackedVector3Array, road: PackedByteArray, water: PackedByteArray, side: int, origin: Vector2i,
		world_size: int) -> void:
	for q in pools:
		var ri := ceili(q.z * 1.3) + 1
		var crossed := false
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var x := floori(q.x) + dx
				var y := floori(q.y) + dy
				if x < 0 or y < 0 or x >= world_size or y >= world_size:
					continue
				var i := _at(x, y, origin, side)
				if i >= 0 and road[i] != 0:
					crossed = true
		if crossed:
			drain_into(pools, water, side, origin, world_size, Vector2(q.x, q.y), 0.0)
