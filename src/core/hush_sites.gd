class_name HushSites
extends RefCounted
## THE HUSH'S RINGS (docs/HUSH.md H0): the stone circles of a landscape that
## declares `BiomeDef.hush` (the crags), found where a body is from the stones
## themselves -- never the Cairn's cast stones, which are a landmark mesh and no
## prop. Worldgen lays a circle's stones round its centre, each turned to face
## it (GenScatter `stone_circle`), so a ring is the stones that stand near each
## other, and its centre is where their facing lines meet (least squares).
## Windowed: read through the query's props near a point, so a streamed world
## that holds only the sections round the player finds the same rings.

## Fewer stones than this is a stone, not a ring (the crags stand single stones
## too); stones further apart than JOIN are two groups.
const MIN_STONES := 5
const JOIN := 5.0


class Ring:
	## A stable id: its lowest stone's prop id.
	var id := 0
	var centre := Vector2.ZERO
	var radius := 0.0
	## Prop ids of its stones, round the circle.
	var stones := PackedInt32Array()


## The rings with a stone within `reach` of `at`, in hush landscapes only.
static func near(w: WorldData, q: WorldQuery, at: Vector2, reach: float) -> Array[Ring]:
	var out: Array[Ring] = []
	# 23_hush looks four times a second wherever the player is, and walking every
	# prop in reach is milliseconds on the web; almost everywhere no landscape in
	# reach has a hush at all, and that is a scan of the country bytes.
	if not hush_in(w, at, reach + JOIN * 2.0):
		return out
	var stones: Array[WorldProp] = []
	for p: WorldProp in q.props_near(at, reach + JOIN * 2.0):
		if p.kind != PropKind.STANDING_STONE or w.depleted.has(p.id):
			continue
		var d := BiomeRegistry.by_index(w.country_at(floori(p.pos.x), floori(p.pos.y)))
		if d != null and d.hush:
			stones.append(p)
	# Groups are indices into `stones`: a prop is a view of its row, and is
	# never held or compared as an object (test_prop_identity).
	var taken := PackedByteArray()
	taken.resize(stones.size())
	for si in stones.size():
		if taken[si] == 1:
			continue
		# The group this stone stands in: every stone within JOIN of one in it.
		var group := PackedInt32Array([si])
		taken[si] = 1
		var k := 0
		while k < group.size():
			var here := stones[group[k]].pos
			for oi in stones.size():
				if taken[oi] == 0 and stones[oi].pos.distance_to(here) <= JOIN:
					taken[oi] = 1
					group.append(oi)
			k += 1
		if group.size() < MIN_STONES:
			continue
		var r := _ring_of(stones, group)
		if r != null and r.centre.distance_to(at) <= reach + r.radius:
			out.append(r)
	return out


## The ring whose centre is nearest `at` within `reach`, or null.
static func nearest(w: WorldData, q: WorldQuery, at: Vector2, reach: float) -> Ring:
	var best: Ring = null
	for r: Ring in near(w, q, at, reach):
		if best == null or r.centre.distance_to(at) < best.centre.distance_to(at):
			best = r
	return best


## Whether `p` stands inside ring `r` (within its stones, `pad` more or less).
static func inside(r: Ring, p: Vector2, pad := 0.0) -> bool:
	return r.centre.distance_to(p) <= r.radius + pad


## Centre by least squares on the stones' facing lines: each stone looks along
## `rot` at the centre, so the centre is the point nearest every such line.
static func _ring_of(stones: Array[WorldProp], group: PackedInt32Array) -> Ring:
	var a := 0.0
	var b := 0.0
	var c := 0.0
	var bx := 0.0
	var by := 0.0
	for gi in group:
		var s := stones[gi]
		var d := Vector2.from_angle(s.rot)
		# (I - d d^T), and its product with the stone's position.
		var m00 := 1.0 - d.x * d.x
		var m01 := -d.x * d.y
		var m11 := 1.0 - d.y * d.y
		a += m00
		b += m01
		c += m11
		bx += m00 * s.pos.x + m01 * s.pos.y
		by += m01 * s.pos.x + m11 * s.pos.y
	var det := a * c - b * b
	if absf(det) < 1e-6:
		return null
	var r := Ring.new()
	r.centre = Vector2((c * bx - b * by) / det, (a * by - b * bx) / det)
	var sum := 0.0
	var order := Array(group)
	order.sort_custom(func(p: int, o: int) -> bool:
		return (stones[p].pos - r.centre).angle() < (stones[o].pos - r.centre).angle())
	for gi: int in order:
		sum += stones[gi].pos.distance_to(r.centre)
		r.stones.append(stones[gi].id)
	r.radius = sum / order.size()
	# Its lowest stone's prop id: fixed for the seed, whatever window found it
	# (the fitted centre moves by a hair with the stones a window holds).
	var lowest := r.stones[0]
	for id in r.stones:
		lowest = mini(lowest, id)
	r.id = lowest
	return r


## The landscapes that declare a hush, by country index.
static var _hush_countries := PackedByteArray()
static var _hush_known := false


## Whether any tile within `reach` (square, as `WorldQuery.props_near` reads) of
## `at` is a hush landscape's. Exact: a native search of each row's country
## bytes, so it can never miss a ring that `near` would have found.
static func hush_in(w: WorldData, at: Vector2, reach: float) -> bool:
	if not _hush_known:
		_hush_known = true
		for d: BiomeDef in BiomeRegistry.all():
			if d.hush:
				_hush_countries.append(d.index)
	if _hush_countries.is_empty():
		return false
	var x0 := maxi(0, floori(at.x - reach))
	var x1 := mini(w.size - 1, floori(at.x + reach))
	var y0 := maxi(0, floori(at.y - reach))
	var y1 := mini(w.size - 1, floori(at.y + reach))
	if x0 > x1 or y0 > y1:
		return false
	for y in range(y0, y1 + 1):
		var row := w.country.slice(y * w.size + x0, y * w.size + x1 + 1)
		for c in _hush_countries:
			if row.has(c):
				return true
	return false
