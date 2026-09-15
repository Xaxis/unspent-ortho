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
	# Cheapest breach per pair of regions, found along every region boundary.
	var best := {} # pair key -> Vector3i(upper tile, lower tile, drop)
	var level := w.level
	for y in range(1, size - 1):
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
				var cur: Vector3i = best.get(key, Vector3i(-1, -1, 99))
				if drop >= cur.z:
					continue
				if _ramp_fits(c, label, hi, lo, drop):
					best[key] = Vector3i(hi, lo, drop)
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
		var ra := _find(root, label[e.x])
		var rb := _find(root, label[e.y])
		if ra == rb:
			continue
		root[ra] = rb
		_cut(c, e.x, e.y, e.z)


## Walkable regions: 4-connected, a step of at most one level, deep water
## (level < 0) excluded. Returns labels (-1 = deep water) and fills sizes.
static func regions(level: PackedInt32Array, size: int, sizes: PackedInt32Array) -> PackedInt32Array:
	var n := level.size()
	var label := PackedInt32Array()
	label.resize(n)
	label.fill(-1)
	sizes.clear()
	var stack := PackedInt32Array()
	stack.resize(n)
	for start in n:
		if label[start] != -1 or level[start] < 0:
			continue
		var id := sizes.size()
		var count := 0
		label[start] = id
		var top := 0
		stack[0] = start
		top = 1
		while top > 0:
			top -= 1
			var i := stack[top]
			count += 1
			var l := level[i]
			var x := i % size
			var j := i - 1
			if x > 0 and label[j] == -1 and level[j] >= 0 and absi(level[j] - l) <= 1:
				label[j] = id
				stack[top] = j
				top += 1
			j = i + 1
			if x < size - 1 and label[j] == -1 and level[j] >= 0 and absi(level[j] - l) <= 1:
				label[j] = id
				stack[top] = j
				top += 1
			j = i - size
			if j >= 0 and label[j] == -1 and level[j] >= 0 and absi(level[j] - l) <= 1:
				label[j] = id
				stack[top] = j
				top += 1
			j = i + size
			if j < n and label[j] == -1 and level[j] >= 0 and absi(level[j] - l) <= 1:
				label[j] = id
				stack[top] = j
				top += 1
		sizes.append(count)
	return label


static func _find(root: PackedInt32Array, a: int) -> int:
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
