class_name GenAccess
## Stage 9: every piece of land worth standing on can be walked to.
##
## Terraces, scarps, gorges and calderas make cliffs, and cliffs can wall a
## plateau off. Walkable regions are labelled (a body steps one level; deep
## water blocks), then regions are joined cheapest-first, like a spanning
## tree, by cutting a scree breach: a straight ramp into the higher region, one
## level per tile. Pinnacles too small to matter are left alone.

## Regions smaller than this are rocks, not places.
const MIN_REGION := 24


## A plateau wider or taller than this is BIG: it is not decided round its own
## edge, it is one of the places the small plateaus are joined to. Measured at
## 1840 (seeds 1, 42, 90210), the smaller side of every breach cut spanned at
## most 67 tiles, and no breach ever joined two big plateaus: a section with
## ACCESS_REACH round its core decides its breaches as the whole world does
## (streamed worldgen S4e3, tests/stream/test_access_window.gd).
const ACCESS_REACH := 128


static func run(c: GenContext) -> void:
	# The whole world is its own square: its plateaus and breaches are found
	# once and serve the plan and the pass alike.
	var sizes := PackedInt32Array()
	var label := regions(c.w.level, c.size, sizes)
	var big := _big(label, sizes, c.size)
	var edges := _edges(c.w.level, c.water, c.village, label, sizes, c.size, Vector2i.ZERO, c.size)
	c.mark(&"access.scan")
	var plan := _plan(label, sizes, big, edges)
	_join(c.w.level, c.ramp, label, sizes, big, edges, plan)
	c.mark(&"access.join")


## THE PLAN'S SHARE: the breaches that join the BIG plateaus of each landmass to
## one another. A section joins its small plateaus to whichever big one is
## cheapest and never learns whether the big ones meet, so the plan does: the
## cheapest spanning tree over every plateau, pruned of small plateaus at its
## leaves until only the ways between big ones are left. Returned as
## (upper tile, lower tile, drop), tile indices in this square.
static func plan_links(level: PackedInt32Array, water: PackedByteArray, village: PackedByteArray, size: int) -> Array[Vector3i]:
	var sizes := PackedInt32Array()
	var label := regions(level, size, sizes)
	return _plan(label, sizes, _big(label, sizes, size), _edges(level, water, village, label, sizes, size, Vector2i.ZERO, size))


static func _plan(label: PackedInt32Array, sizes: PackedInt32Array, big: Dictionary, edges: Array[Vector3i]) -> Array[Vector3i]:
	var root := PackedInt32Array()
	root.resize(sizes.size())
	for r in root.size():
		root[r] = r
	var tree: Array[Vector3i] = []
	for e in edges:
		var ra := find_root(root, label[e.x])
		var rb := find_root(root, label[e.y])
		if ra == rb:
			continue
		root[ra] = rb
		tree.append(e)
	# Prune: a small plateau at a leaf of the tree joins nothing big to anything.
	var degree := {}
	for e in tree:
		degree[label[e.x]] = int(degree.get(label[e.x], 0)) + 1
		degree[label[e.y]] = int(degree.get(label[e.y], 0)) + 1
	var keep := PackedByteArray()
	keep.resize(tree.size())
	keep.fill(1)
	var changed := true
	while changed:
		changed = false
		for k in tree.size():
			if keep[k] == 0:
				continue
			var la := label[tree[k].x]
			var lb := label[tree[k].y]
			var leaf := -1
			if int(degree[la]) == 1 and not big.has(la):
				leaf = la
			elif int(degree[lb]) == 1 and not big.has(lb):
				leaf = lb
			if leaf < 0:
				continue
			keep[k] = 0
			degree[la] = int(degree[la]) - 1
			degree[lb] = int(degree[lb]) - 1
			changed = true
	var out: Array[Vector3i] = []
	for k in tree.size():
		if keep[k] != 0:
			out.append(tree[k])
	return out


## Every piece of land worth standing on joined, over one square of `size`
## tiles at `origin` in a world `world_size` wide: the whole world, or a section
## with ACCESS_REACH + 2 tiles of the world round its core. `plan` holds the
## plan's breaches (`plan_links`) in this square's tile indices, -1 where they
## fall outside it. Big plateaus, the plan's, and any run to the square's edge
## count as one place already joined; each small plateau is joined to it, or to
## the small ones round it, cheapest first.
static func access(level: PackedInt32Array, water: PackedByteArray, village: PackedByteArray, ramp: PackedByteArray,
		size: int, plan: Array[Vector3i], origin: Vector2i, world_size: int) -> void:
	var sizes := PackedInt32Array()
	var label := regions(level, size, sizes)
	_join(level, ramp, label, sizes, _big(label, sizes, size), _edges(level, water, village, label, sizes, size, origin, world_size), plan)


static func _join(level: PackedInt32Array, ramp: PackedByteArray, label: PackedInt32Array, sizes: PackedInt32Array,
		big: Dictionary, edges: Array[Vector3i], plan: Array[Vector3i]) -> void:
	var root := PackedInt32Array()
	root.resize(sizes.size())
	for r in root.size():
		root[r] = r
	var main := -1
	for la: int in big:
		if main < 0:
			main = la
		else:
			root[find_root(root, la)] = find_root(root, main)
	for e in plan:
		if e.x < 0 or e.y < 0:
			continue
		_cut(level, ramp, e.x, e.y, e.z)
		for la: int in [label[e.x], label[e.y]]:
			if main < 0:
				main = la
			else:
				root[find_root(root, la)] = find_root(root, main)
	for e in edges:
		var ra := find_root(root, label[e.x])
		var rb := find_root(root, label[e.y])
		if ra == rb:
			continue
		root[ra] = rb
		_cut(level, ramp, e.x, e.y, e.z)


## Plateaus of MIN_REGION tiles or more that are BIG: wider or taller than
## ACCESS_REACH, or running to the square's outermost usable ring (where the
## square cannot see where they end). Label -> true.
static func _big(label: PackedInt32Array, sizes: PackedInt32Array, size: int) -> Dictionary:
	const BAND := 16
	var parts: Array[Dictionary] = []
	parts.resize(ceili(float(size) / BAND))
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		var box := {}
		for y in range(y0, y1):
			for x in size:
				var la := label[y * size + x]
				if la < 0 or sizes[la] < MIN_REGION:
					continue
				if not box.has(la):
					box[la] = Vector4i(x, y, x, y)
					continue
				var r: Vector4i = box[la]
				if x < r.x or x > r.z or y > r.w:
					box[la] = Vector4i(mini(r.x, x), r.y, maxi(r.z, x), maxi(r.w, y))
		parts[y0 / BAND] = box
	, BAND)
	var box := {}
	for part in parts:
		for la: int in part:
			var p: Vector4i = part[la]
			var r: Vector4i = box.get(la, p)
			box[la] = Vector4i(mini(r.x, p.x), mini(r.y, p.y), maxi(r.z, p.z), maxi(r.w, p.w))
	var out := {}
	for la: int in box:
		var r: Vector4i = box[la]
		if r.z - r.x + 1 > ACCESS_REACH or r.w - r.y + 1 > ACCESS_REACH or r.x <= 1 or r.y <= 1 or r.z >= size - 2 or r.w >= size - 2:
			out[la] = true
	return out


## The cheapest breach between every pair of touching plateaus of MIN_REGION
## tiles or more, as (upper tile, lower tile, drop), cheapest first. Ties go by
## the upper tile's place in the WORLD (`origin`, `world_size`), so a section
## orders its breaches as the whole world does.
static func _edges(level: PackedInt32Array, water: PackedByteArray, village: PackedByteArray, label: PackedInt32Array,
		sizes: PackedInt32Array, size: int, origin: Vector2i, world_size: int) -> Array[Vector3i]:
	# Cheapest breach per pair of regions, found along every region boundary:
	# one dictionary per band, merged in band order so the first cheapest
	# breach in reading order wins, as a single pass would choose.
	const BAND := 12
	var parts: Array[Dictionary] = []
	parts.resize(ceili(float(size) / BAND))
	GenFields.rows(size - 1, func(y0: int, y1: int) -> void:
		var found := {} # pair key -> Vector3i(upper tile, lower tile, drop)
		for y in range(maxi(y0, 1), y1):
			for x in range(1, size - 1):
				var i := y * size + x
				var la := label[i]
				if la < 0 or sizes[la] < MIN_REGION:
					continue
				for side in 2:
					var j := i + 1 if side == 0 else i + size
					var lb := label[j]
					if lb == la or lb < 0 or sizes[lb] < MIN_REGION:
						continue
					var hi := i if level[i] > level[j] else j
					var lo := j if hi == i else i
					var drop := level[hi] - level[lo]
					var key := mini(la, lb) * 1048576 + maxi(la, lb)
					var cur: Vector3i = found.get(key, Vector3i(-1, -1, 99))
					if drop >= cur.z:
						continue
					if _ramp_fits(level, water, village, label, size, hi, lo, drop):
						found[key] = Vector3i(hi, lo, drop)
		parts[y0 / BAND] = found
	, BAND)
	var best := {}
	for part in parts:
		for key: int in part:
			var e: Vector3i = part[key]
			var cur: Vector3i = best.get(key, Vector3i(-1, -1, 99))
			if e.z < cur.z:
				best[key] = e
	var edges: Array[Vector3i] = []
	for key: int in best:
		edges.append(best[key])
	var place := func(i: int) -> int:
		return (origin.y + i / size) * world_size + origin.x + i % size
	edges.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.z < b.z or (a.z == b.z and place.call(a.x) < place.call(b.x)))
	return edges


## Walkable regions: 4-connected, a step of at most one level, deep water
## (level < 0) excluded. Returns labels (-1 = deep water; a label is the index
## of one tile in the region) and fills sizes, indexed by label.
##
## Union-find, band by band on the worker pool (each band only links its own
## tiles), then the bands are stitched together along their seams.
static func regions(level: PackedInt32Array, size: int, sizes: PackedInt32Array) -> PackedInt32Array:
	var n := level.size()
	var up := PackedInt32Array()
	up.resize(n)
	const BAND := 16
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var row := y * size
			for x in size:
				var i := row + x
				var l := level[i]
				if l < 0:
					up[i] = -1
					continue
				up[i] = i
				if x > 0:
					var lw := level[i - 1]
					if lw >= 0 and lw - l <= 1 and l - lw <= 1:
						var a := i - 1
						while up[a] != a:
							up[a] = up[up[a]]
							a = up[a]
						up[i] = a
				if y > y0:
					var ln := level[i - size]
					if ln >= 0 and ln - l <= 1 and l - ln <= 1:
						var a := i - size
						while up[a] != a:
							up[a] = up[up[a]]
							a = up[a]
						var b := i
						while up[b] != b:
							up[b] = up[up[b]]
							b = up[b]
						if a != b:
							up[maxi(a, b)] = mini(a, b)
	, BAND)
	for y in range(BAND, size, BAND):
		var row := y * size
		for x in size:
			var i := row + x
			var l := level[i]
			var ln := level[i - size]
			if l < 0 or ln < 0 or ln - l > 1 or l - ln > 1:
				continue
			var a := i - size
			while up[a] != a:
				up[a] = up[up[a]]
				a = up[a]
			var b := i
			while up[b] != b:
				up[b] = up[up[b]]
				b = up[b]
			if a != b:
				up[maxi(a, b)] = mini(a, b)
	var label := PackedInt32Array()
	label.resize(n)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			var a := up[i]
			if a < 0:
				label[i] = -1
				continue
			while up[a] != a:
				a = up[a]
			label[i] = a
	)
	sizes.resize(n)
	sizes.fill(0)
	for i in n:
		var a := label[i]
		if a >= 0:
			sizes[a] += 1
	return label


static func find_root(root: PackedInt32Array, a: int) -> int:
	while root[a] != a:
		root[a] = root[root[a]]
		a = root[a]
	return a


## A ramp from lo into hi needs drop - 1 tiles of the same high region in a
## straight line beyond hi, standing on dry ground outside villages.
static func _ramp_fits(level: PackedInt32Array, water: PackedByteArray, village: PackedByteArray, label: PackedInt32Array,
		size: int, hi: int, lo: int, drop: int) -> bool:
	var n := level.size()
	var step := hi - lo
	var lh := level[hi]
	for k in drop:
		var t := hi + step * k
		if t < 0 or t >= n:
			return false
		if absi((t % size) - (hi % size)) > drop + 1:
			return false
		if label[t] != label[hi] or level[t] != lh or water[t] != 0 or village[t] != 0:
			return false
	return true


static func _cut(level: PackedInt32Array, ramp: PackedByteArray, hi: int, lo: int, drop: int) -> void:
	var step := hi - lo
	var ll := level[lo]
	for k in drop - 1:
		var t := hi + step * k
		level[t] = ll + 1 + k
		ramp[t] = 1
