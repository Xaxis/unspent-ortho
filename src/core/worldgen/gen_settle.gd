class_name GenSettle
## Stage 8: villages, the roads between them, and where the player wakes.
##
## Villages sit on flat dry ground on the island (never an islet), spread
## across countries by quota (the Coast holds the most; the Snowfield and the
## Burning get one hard outpost each, levelled out of rough ground if need
## be), each with its core levelled so houses stand square. Village 0 is on
## the south coast: the spawn village. Roads are least-cost paths over a
## half-resolution grid that prefer flat ground, avoid cliffs, share existing
## road, and cross rivers where they must (the crossing tiles become road and
## a `bridge` landmark). Rasterised roads are graded so every step along them
## is walkable, cut down to fords rather than lifting a river, and widened to
## ribbons on the diagonals. A village a tree edge fails to reach is joined to
## its nearest reachable neighbour.

## How many villages a world holds. Twelve was right for six landscapes; every
## landscape the registry adds brings its own people, or the new land takes a
## village off an old one and leaves it with no road and nobody to trade with.
const BASE_VILLAGES := 12
const BASE_LANDS := 6
const MIN_VILLAGES := 10


static func max_villages() -> int:
	return BASE_VILLAGES + maxi(0, BiomeRegistry.land().size() - BASE_LANDS)
const CORE := 9.5
## Only the square and the first ring of houses is levelled; the rest of the
## core keeps the lie of the land, so terraces run on through a village.
const FLAT := 6.5
## Tiles over which the ground eases from the levelled middle back to the
## land's, never faster than a level every APRON_RUN tiles.
const APRON := 13.0
const APRON_RUN := 2.0
## Farthest a house's footprint reaches from its square (see GenScatter).
const HOUSE_REACH := 14.5



static func villages(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var b := 8
	var bw := GenFields.coarse_width(size, b)
	var bn := bw * bw
	var bmin := PackedInt32Array()
	bmin.resize(bn)
	bmin.fill(99)
	var bmax := PackedInt32Array()
	bmax.resize(bn)
	bmax.fill(-99)
	var bwet := PackedByteArray()
	bwet.resize(bn)
	var level := w.level
	var land := c.land
	var water := c.water
	# Bands of 24 rows keep each 8-tile block inside one band.
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var brow := (y / b) * bw
			for x in size:
				var i := y * size + x
				var k := brow + x / b
				var l := level[i]
				# Pools may be filled for a village; rivers and the sea may not.
				if land[i] == 0 or water[i] == 1:
					bwet[k] = 1
				if l < bmin[k]:
					bmin[k] = l
				if l > bmax[k]:
					bmax[k] = l
	, 24)
	c.mark(&"settle.blocks")
	var cands: Array[Vector3] = [] # tile x, tile y, score
	var relaxed: Array[Vector3] = []
	# Rough ground is levelled for a village only where nothing better exists
	# (a mountain country's one outpost).
	var rough: Array[Vector3] = []
	for gy in range(1, bw - 1):
		for gx in range(1, bw - 1):
			var ks: PackedInt32Array = [(gy - 1) * bw + gx - 1, (gy - 1) * bw + gx, gy * bw + gx - 1, gy * bw + gx]
			var mn := 99
			var mx := -99
			var wet := false
			for k in ks:
				mn = mini(mn, bmin[k])
				mx = maxi(mx, bmax[k])
				wet = wet or bwet[k] != 0
			if wet or mn < 1:
				continue
			var tx := gx * b
			var ty := gy * b
			# Villages stand on the island, where a road can reach them.
			if w.blend[ty * size + tx] > 0.4 or c.islet[ty * size + tx] != 0:
				continue
			var near_water := 0.0
			for dk: Vector2i in [Vector2i(-2, 0), Vector2i(1, 0), Vector2i(0, -2), Vector2i(0, 1)]:
				var nx := gx + dk.x
				var ny := gy + dk.y
				if nx >= 0 and ny >= 0 and nx < bw and ny < bw and bwet[ny * bw + nx] != 0:
					near_water = 0.3
			var score := near_water + GenFields.h01(c.s, gx, gy, 61) * 0.25
			if mx - mn <= 1:
				cands.append(Vector3(tx, ty, score + (1.0 if mx == mn else 0.6)))
			elif mx - mn <= 2:
				relaxed.append(Vector3(tx, ty, score))
			elif mx - mn <= 4:
				rough.append(Vector3(tx, ty, score))
	var by_score := func(p: Vector3, q: Vector3) -> bool: return p.z > q.z
	cands.sort_custom(by_score)
	relaxed.sort_custom(by_score)
	rough.sort_custom(by_score)
	var gap := maxf(26.0, 56.0 * c.k)
	var chosen: Array[Vector3] = []
	# The spawn village: as far south as flat coast allows, and close enough to
	# the sea that the first frame holds the square and the water together (a
	# village deep inland wakes the player in a field). Ground that needs a
	# little levelling counts too (its score is lower); wider only if none fits.
	var r := c.land_rect
	var best := Vector3(-1, -1, -1e9)
	for far: float in [14.0, 20.0, 40.0]:
		for pool: Array[Vector3] in [cands, relaxed]:
			for p in pool:
				var i := int(p.y) * size + int(p.x)
				if not c.defs[w.country[i]].spawn_home:
					continue
				var d_in := c.inland[i]
				if d_in < 8.0 or d_in > far:
					continue
				var south := (p.y - r.position.y) / r.size.y
				var sc := south * 3.0 + p.z * 0.5 - absf(d_in - 10.0) * 0.08 + _sea_below(c, p.x, p.y) * 4.0
				if sc > best.z:
					best = Vector3(p.x, p.y, sc)
		if best.x >= 0.0:
			break
	if best.x < 0.0:
		best = Vector3(roundi(r.position.x + r.size.x * 0.5), roundi(r.end.y - 12.0), 0)
	chosen.append(best)
	var counts := PackedInt32Array()
	counts.resize(c.types)
	counts[w.country[int(best.y) * size + int(best.x)]] = 1
	# Every landscape is settled in the order it declares, so the land that
	# fills up what is left waits for the rest to have theirs.
	var settle_order: Array[int] = []
	settle_order.assign(c.land_types)
	settle_order.sort_custom(func(a: int, b: int) -> bool:
		return c.defs[a].village_order < c.defs[b].village_order)
	for pool: Array[Vector3] in [cands, relaxed, rough]:
		for cc: int in settle_order:
			for p in pool:
				if counts[cc] >= c.defs[cc].villages:
					break
				var i := int(p.y) * size + int(p.x)
				if w.country[i] != cc or _crowded(chosen, p, gap):
					continue
				chosen.append(p)
				counts[cc] += 1
	for pool: Array[Vector3] in [cands, relaxed]:
		for p in pool:
			if chosen.size() >= MIN_VILLAGES:
				break
			if not _crowded(chosen, p, gap):
				chosen.append(p)
	var rng := Rng.make(c.s, 62)
	var used := {}
	for p: Vector3 in chosen.slice(0, max_villages()):
		var tx := int(p.x)
		var ty := int(p.y)
		var cc := w.country[ty * size + tx]
		var id := w.villages.size()
		w.villages.append({
			"id": id,
			"pos": Vector2(tx + 0.5, ty + 0.5),
			"country": cc,
			"name": _name(rng, cc, used),
			"level": _level_here(c, tx, ty),
			"radius": CORE,
		})
		# Pools keep three tiles clear of the farthest house.
		GenWater.drain_pools(c, Vector2(tx + 0.5, ty + 0.5), HOUSE_REACH + 3.0)
		_flatten(c, tx, ty, w.villages[id].level)


static func _crowded(chosen: Array[Vector3], p: Vector3, gap: float) -> bool:
	for q in chosen:
		if Vector2(q.x, q.y).distance_squared_to(Vector2(p.x, p.y)) < gap * gap:
			return true
	return false


static func _name(rng: RandomNumberGenerator, cc: int, used: Dictionary) -> String:
	var list: Array = BiomeRegistry.by_index(cc).village_names
	if list.is_empty():
		list = ["%s Row" % BiomeRegistry.by_index(cc).display_name.capitalize()]
	for attempt in 8:
		var nm: String = list[rng.randi_range(0, list.size() - 1)]
		if not used.has(nm):
			used[nm] = true
			return nm
	for nm: String in list:
		if not used.has(nm):
			used[nm] = true
			return nm
	return "%s %d" % [list[0], used.size()]


static func _level_here(c: GenContext, tx: int, ty: int) -> int:
	var hist := {}
	var best := c.w.level[ty * c.size + tx]
	var best_n := 0
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var l := c.w.level_at(tx + dx, ty + dy)
			if l < 1:
				continue
			hist[l] = int(hist.get(l, 0)) + 1
			if hist[l] > best_n:
				best_n = hist[l]
				best = l
	return maxi(1, best)


## Level the core; ease an apron so nothing around it is a cliff and no
## village stands on a plinth. The core's edge wanders (never a drawn circle);
## beyond it the float elevation eases from the core's level back to the land's
## along a smoothstep, so terraces open out round the village instead of
## stacking at its edge, and the grounds (read from float elevation) follow.
static func _flatten(c: GenContext, tx: int, ty: int, lv: int) -> void:
	var w := c.w
	var size := c.size
	var reach := ceili(CORE * 1.2 + APRON)
	var ph1 := GenFields.h01(c.s, tx, ty, 63) * TAU
	var ph2 := GenFields.h01(c.s, tx, ty, 64) * TAU
	var ph3 := GenFields.h01(c.s, tx, ty, 67) * TAU
	var elev := c.elev
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := tx + dx
			var y := ty + dy
			if x < 1 or y < 1 or x >= size - 1 or y >= size - 1:
				continue
			var i := y * size + x
			if c.land[i] == 0 or c.water[i] == 1:
				continue
			var d := sqrt(float(dx * dx + dy * dy))
			var ang := atan2(float(dy), float(dx))
			var wander := 1.0 + 0.12 * sin(ang * 2.0 + ph1) + 0.08 * sin(ang * 3.0 + ph2)
			if d <= CORE * wander:
				c.village[i] = 1
				c.water[i] = 0
			var core := FLAT * wander
			if d <= core:
				w.level[i] = lv
				elev[i] = lv + 0.5
				continue
			# The apron's reach wanders too.
			var run := APRON * (1.0 + 0.3 * sin(ang * 4.0 + ph3))
			if d > core + run:
				continue
			var t := smoothstep(0.0, 1.0, (d - core) / run)
			var e := lerpf(lv + 0.5, elev[i], t)
			var allow := ceili((d - core) / APRON_RUN)
			elev[i] = e
			w.level[i] = clampi(floori(e), maxi(1, lv - allow), lv + allow)


## Radius of a village's square at an angle: about three and a half tiles,
## lobed so it reads as trodden ground, not a stamp.
static func square_radius(c: GenContext, v: Dictionary, ang: float) -> float:
	var vp: Vector2 = v.pos
	var ph1 := GenFields.h01(c.s, floori(vp.x), floori(vp.y), 65) * TAU
	var ph2 := GenFields.h01(c.s, floori(vp.x), floori(vp.y), 66) * TAU
	return 3.9 + 0.7 * sin(ang * 2.0 + ph1) + 0.45 * sin(ang * 3.0 + ph2)


static func roads(c: GenContext) -> void:
	var w := c.w
	var vs := w.villages
	if vs.size() < 2:
		return
	var size := c.size
	var hw := GenFields.coarse_width(size, 2)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, hw, hw)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var hmin := PackedInt32Array()
	hmin.resize(hw * hw)
	hmin.fill(99)
	var hmax := PackedInt32Array()
	hmax.resize(hw * hw)
	hmax.fill(-99)
	var hwet := PackedByteArray()
	hwet.resize(hw * hw)
	var hsea := PackedByteArray()
	hsea.resize(hw * hw)
	var hvil := PackedByteArray()
	hvil.resize(hw * hw)
	var level := w.level
	var land := c.land
	var water := c.water
	var village := c.village
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var hrow := (y / 2) * hw
			for x in size:
				var i := y * size + x
				var k := hrow + x / 2
				var l := level[i]
				if l < hmin[k]:
					hmin[k] = l
				if l > hmax[k]:
					hmax[k] = l
				if land[i] == 0:
					hsea[k] = 1
				elif water[i] > hwet[k]:
					hwet[k] = water[i]
				if village[i] != 0:
					hvil[k] = 1
	)
	c.mark(&"roads.cells")
	for hy in hw:
		for hx in hw:
			var k := hy * hw + hx
			if hsea[k] != 0:
				grid.set_point_solid(Vector2i(hx, hy), true)
				continue
			var mn := hmin[k]
			var mx := hmax[k]
			if hx < hw - 1:
				mn = mini(mn, hmin[k + 1])
				mx = maxi(mx, hmax[k + 1])
			if hy < hw - 1:
				mn = mini(mn, hmin[k + hw])
				mx = maxi(mx, hmax[k + hw])
			var wt := 1.0
			var rise := mx - mn
			if rise >= 3:
				wt += 60.0
			elif rise == 2:
				wt += 14.0
			elif rise == 1:
				wt += 1.2
			if hwet[k] == 1:
				wt += 12.0
			elif hwet[k] == 2:
				wt += 40.0
			if hvil[k] != 0:
				wt = 0.6
			grid.set_point_weight_scale(Vector2i(hx, hy), wt)
	c.mark(&"roads.grid")
	var root := PackedInt32Array()
	for j in vs.size():
		root.append(j)
	for e in _edges(vs, c.k):
		if _connect(c, grid, hw, e.x, e.y):
			root[GenAccess.find_root(root, e.x)] = GenAccess.find_root(root, e.y)
	# A tree edge can fail (a loch in the way, no footing): join any village
	# still cut off to its nearest neighbour that the road can reach.
	for j in vs.size():
		if GenAccess.find_root(root, j) == GenAccess.find_root(root, 0):
			continue
		var others: Array[Vector2] = []
		for k in vs.size():
			if GenAccess.find_root(root, k) != GenAccess.find_root(root, j):
				others.append(Vector2((vs[k].pos as Vector2).distance_to(vs[j].pos), k))
		others.sort()
		for o in others:
			if _connect(c, grid, hw, j, int(o.y)):
				root[GenAccess.find_root(root, j)] = GenAccess.find_root(root, int(o.y))
				break
	GenWater.drain_crossed(c)


static func _connect(c: GenContext, grid: AStarGrid2D, hw: int, from: int, to: int) -> bool:
	var vs := c.w.villages
	var a: Vector2 = vs[from].pos
	var b: Vector2 = vs[to].pos
	var ha := Vector2i(clampi(int(a.x) / 2, 0, hw - 1), clampi(int(a.y) / 2, 0, hw - 1))
	var hb := Vector2i(clampi(int(b.x) / 2, 0, hw - 1), clampi(int(b.y) / 2, 0, hw - 1))
	if grid.is_point_solid(ha) or grid.is_point_solid(hb):
		return false
	var path := grid.get_id_path(ha, hb)
	if path.size() < 2:
		return false
	for hp in path:
		grid.set_point_weight_scale(hp, minf(grid.get_point_weight_scale(hp), 0.45))
	_lay_road(c, path, a, b)
	return true


## A spanning tree over village squares plus a few short loops, as index pairs.
static func _edges(vs: Array[Dictionary], k: float) -> Array[Vector2i]:
	var n := vs.size()
	var out: Array[Vector2i] = []
	var inside := PackedByteArray()
	inside.resize(n)
	inside[0] = 1
	var longest := PackedFloat32Array()
	longest.resize(n)
	for step in n - 1:
		var bi := -1
		var bj := -1
		var bd := INF
		for i in n:
			if inside[i] == 0:
				continue
			for j in n:
				if inside[j] != 0:
					continue
				var d := (vs[i].pos as Vector2).distance_to(vs[j].pos)
				if d < bd:
					bd = d
					bi = i
					bj = j
		if bj < 0:
			break
		inside[bj] = 1
		out.append(Vector2i(bi, bj))
		longest[bi] = maxf(longest[bi], bd)
		longest[bj] = maxf(longest[bj], bd)
	for i in n:
		var bj := -1
		var bd := INF
		for j in n:
			if j == i or out.has(Vector2i(i, j)) or out.has(Vector2i(j, i)):
				continue
			var d := (vs[i].pos as Vector2).distance_to(vs[j].pos)
			if d < bd:
				bd = d
				bj = j
		if bj >= 0 and bd < maxf(longest[i], longest[bj]) * 1.3 and bd < 150.0 * maxf(k, 0.4):
			out.append(Vector2i(mini(i, bj), maxi(i, bj)))
	return out


static func _lay_road(c: GenContext, path: Array[Vector2i], a: Vector2, b: Vector2) -> void:
	var w := c.w
	var size := c.size
	var pts := PackedVector2Array()
	pts.append(a)
	for j in range(1, path.size() - 1):
		pts.append(Vector2(path[j].x * 2 + 1.0, path[j].y * 2 + 1.0))
	pts.append(b)
	# One Chaikin pass takes the lattice stair out of diagonals.
	var sm := PackedVector2Array()
	sm.append(pts[0])
	for j in pts.size() - 1:
		sm.append(pts[j].lerp(pts[j + 1], 0.25))
		sm.append(pts[j].lerp(pts[j + 1], 0.75))
	sm.append(pts[pts.size() - 1])
	var tiles := PackedInt32Array()
	var last := -1
	for j in sm.size() - 1:
		var p0 := sm[j]
		var p1 := sm[j + 1]
		var steps := maxi(1, ceili(p0.distance_to(p1) / 0.3))
		for t in steps + 1:
			var p := p0.lerp(p1, float(t) / steps)
			var tx := clampi(floori(p.x), 1, size - 2)
			var ty := clampi(floori(p.y), 1, size - 2)
			var i := ty * size + tx
			if i == last:
				continue
			if last >= 0:
				var lx := last % size
				var ly := last / size
				if lx != tx and ly != ty:
					# Step through the corner with the gentler level change.
					var c1 := ly * size + tx
					var c2 := ty * size + lx
					var d1 := absi(w.level[c1] - w.level[last]) + (4 if c.land[c1] == 0 else 0)
					var d2 := absi(w.level[c2] - w.level[last]) + (4 if c.land[c2] == 0 else 0)
					tiles.append(c1 if d1 <= d2 else c2)
			tiles.append(i)
			last = i
	var line := PackedVector2Array()
	var prev := w.level[tiles[0]]
	for j in tiles.size():
		var i := tiles[j]
		if c.land[i] == 0:
			# A causeway over a shallow gap.
			c.land[i] = 1
			w.level[i] = maxi(1, prev - 1)
		var l := w.level[i]
		if c.water[i] == 1:
			# A crossing never lifts the river (its bed only falls downstream):
			# the road cuts down to the ford instead.
			for back in range(j - 1, -1, -1):
				var t := tiles[back]
				if c.water[t] == 1:
					break
				var lt := clampi(w.level[t], l - (j - back), l + (j - back))
				if lt == w.level[t]:
					break
				w.level[t] = maxi(1, lt)
		elif l > prev + 1:
			l = prev + 1
		elif l < prev - 1:
			l = prev - 1
		w.level[i] = maxi(1, l)
		c.road[i] = 1
		prev = w.level[i]
		line.append(Vector2(i % size + 0.5, i / size + 0.5))
	w.roads.append(line)
	# Bridges: each run of road over river water, marked at its middle.
	var run_start := -1
	for j in tiles.size() + 1:
		var wet := j < tiles.size() and c.water[tiles[j]] == 1
		if wet and run_start < 0:
			run_start = j
		elif not wet and run_start >= 0:
			var mid := line[(run_start + j - 1) / 2]
			var along := (line[mini(j, line.size() - 1)] - line[maxi(run_start - 1, 0)]).normalized()
			var known := false
			for m in w.landmarks:
				if m.kind == &"bridge" and (m.pos as Vector2).distance_squared_to(mid) < 16.0:
					known = true
			if not known:
				w.landmarks.append({"kind": &"bridge", "pos": mid, "country": w.country_at(floori(mid.x), floori(mid.y)), "dir": along})
			run_start = -1
	# Fill the other corner of every stair step, so a diagonal road is a
	# ribbon two tiles wide rather than a zigzag one tile wide.
	for j in range(1, tiles.size() - 1):
		var i := tiles[j]
		var pv := tiles[j - 1]
		var nx := tiles[j + 1]
		if pv % size == nx % size or pv / size == nx / size:
			continue
		var other := pv + nx - i
		if other < 0 or other >= c.n or c.road[other] != 0:
			continue
		if c.land[other] == 0 or c.water[other] != 0 or absi(w.level[other] - w.level[i]) > 1:
			continue
		w.level[other] = w.level[i]
		c.road[other] = 1


## Share of sea in the half of a 14-tile disc that lies down the screen from a
## tile (world +x+y): where the first frame's sea would lie, below the square.
static func _sea_below(c: GenContext, tx: float, ty: float) -> float:
	var sea := 0
	var n := 0
	for dy in range(-14, 15, 2):
		for dx in range(-14, 15, 2):
			if dx + dy <= 0 or dx * dx + dy * dy > 196:
				continue
			var x := int(tx) + dx
			var y := int(ty) + dy
			n += 1
			if x < 0 or y < 0 or x >= c.size or y >= c.size or c.land[y * c.size + x] == 0:
				sea += 1
	return float(sea) / maxf(1.0, n)


## Wake beside the spawn village, on dry coast, facing the most open land.
static func spawn(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	if w.villages.is_empty():
		w.spawn = Vector2(size * 0.5, size * 0.5)
		return
	var v: Dictionary = w.villages[0]
	var vp: Vector2 = v.pos
	var lv: int = v.level
	var best := vp + Vector2(3, 3)
	var best_facing := -PI * 0.5
	var best_score := -1e9
	# The square's fire stands at the centre (GenScatter._villages): wake where
	# the frame holds it and the sea together. Houses keep clear of this spot.
	var square: Array[Vector2] = [vp + Vector2(-0.3, -0.5)]
	for ang_i in 16:
		var ang := ang_i / 16.0 * TAU
		for rad: float in [7.5, 9.0, 11.0, 12.5]:
			var p := vp + Vector2.from_angle(ang) * rad
			var tx := floori(p.x)
			var ty := floori(p.y)
			if not _dry_flat(c, tx, ty, lv):
				continue
			var q := Vector2(tx + 0.5, ty + 0.5)
			var view := _frame_view(c, q, square) * 2.0 - rad * 0.15
			for face_i in 8:
				var face := face_i / 8.0 * TAU
				var open := _openness(c, q, face)
				# Look inland (north-ish) and away from the houses.
				var away := Vector2.from_angle(face).dot((p - vp).normalized())
				var sc := view + open + away * 6.0 - Vector2.from_angle(face).y * 5.0
				if sc > best_score:
					best_score = sc
					best = q
					best_facing = face
	w.spawn = best
	w.spawn_facing = best_facing


## Once the grounds and houses exist, move the waking place to the spot beside
## the spawn village with the best first frame: some of the village in view, a
## road leading off, water or a copse, several grounds and a terrace or two,
## and not one dark ground filling the page. Keeps clear of every house.
static func frame_spawn(c: GenContext) -> void:
	var w := c.w
	if w.villages.is_empty():
		return
	var v: Dictionary = w.villages[0]
	var vp: Vector2 = v.pos
	var lv: int = v.level
	var houses: Array[Vector2] = []
	for prop in w.props:
		if prop.kind == PropKind.HOUSE:
			houses.append(prop.pos)
	var square: Array[Vector2] = []
	for prop in w.props:
		if (prop.kind == PropKind.FIRE or prop.kind == PropKind.BENCH or prop.kind == PropKind.LAMP) and prop.pos.distance_to(vp) < 5.0:
			square.append(prop.pos)
	var best := w.spawn
	var best_score := _frame_score(c, w.spawn, houses) + _frame_view(c, w.spawn, square) * 2.0 + 0.5
	for ang_i in 24:
		var ang := ang_i / 24.0 * TAU
		for rad: float in [6.5, 8.0, 9.5, 11.0, 12.5, 14.0, 15.5]:
			var p := vp + Vector2.from_angle(ang) * rad
			var tx := floori(p.x)
			var ty := floori(p.y)
			if not _dry_flat(c, tx, ty, lv) or w.country_at(tx, ty) != w.villages[0].country:
				continue
			var q := Vector2(tx + 0.5, ty + 0.5)
			var crowded := false
			for h in houses:
				if maxf(absf(h.x - q.x), absf(h.y - q.y)) < 5.5:
					crowded = true
			if crowded:
				continue
			var sc := _frame_score(c, q, houses) + _frame_view(c, q, square) * 2.0
			if sc > best_score:
				best_score = sc
				best = q
	if best == w.spawn:
		return
	w.spawn = best
	var best_facing := w.spawn_facing
	var best_open := -1e9
	for face_i in 8:
		var face := face_i / 8.0 * TAU
		var open := _openness(c, best, face)
		var away := Vector2.from_angle(face).dot((best - vp).normalized())
		var sc := open + away * 6.0 - Vector2.from_angle(face).y * 5.0
		if sc > best_open:
			best_open = sc
			best_facing = face
	w.spawn_facing = best_facing


## What the camera actually frames from p (yaw 45, 640x360 at view height 15:
## about 12 tiles either side, 8 up and down): the sea along one side and the
## village square (fire, bench, lamp) readable, not cut by the frame's edge.
static func _frame_view(c: GenContext, p: Vector2, square: Array[Vector2]) -> float:
	var w := c.w
	var sea := 0
	var total := 0
	for sy in range(-8, 9, 2):
		for sx in range(-12, 13, 2):
			# Screen right is world (1,-1)/sqrt2, screen down is (1,1)/sqrt2.
			var d := Vector2(sx + sy, sy - sx) * 0.7071
			var x := floori(p.x + d.x)
			var y := floori(p.y + d.y)
			total += 1
			if not w.in_bounds(x, y) or w.level_at(x, y) <= 0:
				sea += 1
	var score := 0.0
	var share := float(sea) / maxf(1.0, total)
	# Best with about a quarter of the page sea; any sea at all is worth a little.
	if share > 0.0 and share < 0.55:
		score += 2.0 + 7.0 * clampf(1.0 - absf(share - 0.25) / 0.25, 0.0, 1.0)
	var framed := 0
	for q in square:
		var d := q - p
		var sx := (d.x - d.y) * 0.7071
		var sy := (d.x + d.y) * 0.7071
		# In the upper part of the page and well inside it: the sea lies below.
		if absf(sx) < 9.5 and sy > -7.5 and sy < 2.0 and d.length() > 3.5:
			framed += 1
	if not square.is_empty():
		score += 8.0 * framed / square.size()
	return score


## How good a first frame the ground round p makes (see frame_spawn).
static func _frame_score(c: GenContext, p: Vector2, houses: Array[Vector2]) -> float:
	var w := c.w
	var size := c.size
	var counts := PackedInt32Array()
	counts.resize(Ground.COUNT)
	var field := 0
	var road := 0
	var wet := 0
	var copse := 0
	var other_level := 0
	var total := 0
	var cx := floori(p.x)
	var cy := floori(p.y)
	var l0 := w.level_at(cx, cy)
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			if dx * dx + dy * dy > 100:
				continue
			var x := cx + dx
			var y := cy + dy
			if not w.in_bounds(x, y):
				continue
			var i := y * size + x
			total += 1
			var g := w.ground[i]
			if w.level[i] <= 0 or Ground.is_water(g):
				wet += 1
				continue
			if g == Ground.ROAD:
				road += 1
				continue
			counts[g] += 1
			field += 1
			if w.level[i] != l0:
				other_level += 1
			if g == Ground.GRASS and c.forest[i] > 0.25:
				copse += 1
	var score := 0.0
	var top := 0
	for g in Ground.COUNT:
		if counts[g] >= 8:
			score += 1.5
		top = maxi(top, counts[g])
	score = minf(score, 7.5)
	var f := maxf(1.0, field)
	if top / f > 0.6:
		score -= (top / f - 0.6) * 10.0
	var dark := (counts[Ground.HEATH] + counts[Ground.PEAT] + counts[Ground.MUD]) / f
	if dark > 0.3:
		score -= (dark - 0.3) * 12.0
	if road >= 3:
		score += 2.0
	var wet_share := float(wet) / maxf(1.0, total)
	if wet >= 6 and wet_share < 0.35:
		score += 2.0
	if copse >= 10:
		score += 1.5
	var lv_share := float(other_level) / f
	if lv_share > 0.1 and lv_share < 0.5:
		score += 1.0
	var seen := 0
	for h in houses:
		var d := h.distance_to(p)
		if d > 5.5 and d < 11.0:
			seen += 1
	score += minf(3.0, seen) * 1.2
	return score


static func _dry_flat(c: GenContext, tx: int, ty: int, lv: int) -> bool:
	var w := c.w
	if tx < 2 or ty < 2 or tx >= c.size - 2 or ty >= c.size - 2:
		return false
	for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var i := (ty + d.y) * c.size + tx + d.x
		if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or absi(w.level[i] - lv) > 1:
			return false
	return true


static func _openness(c: GenContext, p: Vector2, face: float) -> float:
	var w := c.w
	var l0 := w.level_at(floori(p.x), floori(p.y))
	var score := 0.0
	var dir := Vector2.from_angle(face)
	for dist in range(2, 14, 2):
		for spread: float in [-0.35, 0.0, 0.35]:
			var q := p + dir.rotated(spread) * dist
			var tx := floori(q.x)
			var ty := floori(q.y)
			if not w.in_bounds(tx, ty):
				continue
			var i := ty * c.size + tx
			if c.land[i] != 0 and c.water[i] == 0 and absi(w.level[i] - l0) <= 2:
				score += 1.0
	return score
