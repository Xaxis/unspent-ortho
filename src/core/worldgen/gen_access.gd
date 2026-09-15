class_name GenAccess
## Stage 7: every piece of land worth standing on can be walked to.
##
## Terraces, scarps, gorges and calderas make cliffs, and cliffs can wall a
## plateau off. Walkable regions are labelled (a body steps one level; deep
## water blocks), then regions are joined cheapest-first, like a spanning
## tree, by cutting a scree breach: a straight ramp into the higher region, one
## level per tile. Pinnacles too small to matter are left alone.

## Regions smaller than this are rocks, not places.
const MIN_REGION := 24


static func run(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var n := c.n
	var sizes := PackedInt32Array()
	var label := regions(w.level, size, sizes)
	c.mark(&"access.regions")
	# Cheapest breach per pair of regions, found along every region boundary:
	# one dictionary per band, merged in band order so the first cheapest
	# breach in reading order wins, as a single pass would choose.
	var level := w.level
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
					if _ramp_fits(c, label, hi, lo, drop):
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
	c.mark(&"access.scan")
	var edges: Array[Vector3i] = []
	for key: int in best:
		var e: Vector3i = best[key]
		edges.append(e)
	edges.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.z < b.z or (a.z == b.z and a.x < b.x))
	var root := PackedInt32Array()
	root.resize(sizes.size())
	for r in root.size():
		root[r] = r
	for e in edges:
		var ra := find_root(root, label[e.x])
		var rb := find_root(root, label[e.y])
		if ra == rb:
			continue
		root[ra] = rb
		_cut(c, e.x, e.y, e.z)


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
static func _ramp_fits(c: GenContext, label: PackedInt32Array, hi: int, lo: int, drop: int) -> bool:
	var size := c.size
	var step := hi - lo
	var lh := c.w.level[hi]
	for k in drop:
		var t := hi + step * k
		if t < 0 or t >= c.n:
			return false
		if absi((t % size) - (hi % size)) > drop + 1:
			return false
		if label[t] != label[hi] or c.w.level[t] != lh or c.water[t] != 0 or c.village[t] != 0:
			return false
	return true


static func _cut(c: GenContext, hi: int, lo: int, drop: int) -> void:
	var step := hi - lo
	var ll := c.w.level[lo]
	for k in drop - 1:
		var t := hi + step * k
		c.w.level[t] = ll + 1 + k
		c.ramp[t] = 1
