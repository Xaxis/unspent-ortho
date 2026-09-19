class_name BlackSite
## The old THRESHOLD site: an offshore structure in the sea off the HOME coast,
## where Elias died in 2029 and where the Seeker grew the body he wakes in
## (docs/STORY.md). He comes ashore in the surf because he was let out of it, so
## it stands where the spawn beach can see it.
##
## PURE AND DERIVED, like `Works.sites` and `Landmarks.sites`: it is a function of
## the world and is never saved. Grow the same seed and it is in the same water.
##
##   BlackSite.site(world) -> Vector2    the place, or Vector2.INF if this world
##                                       has no sea off its spawn at all
##
## It is NOT a `Landmarks` kind on purpose. That rounds region by region on LAND
## and stands its cache on ground with nothing solid on it; this is in open water,
## one per world rather than one per region, and reached by raft.

## How far off the beach it stands. Near enough to read from the shore, far
## enough that nobody wades to it.
const NEAREST := 15.0
const FURTHEST := 40.0
## What the deck stands on the water as, and the deep water that must lie round
## it. **ONE DEEP TILE IS NOT A MOAT.** The old rule asked only that the site
## tile itself was deep and that one ray out to it stayed wet, and neither makes
## a place offshore: on all four test seeds the site sat on a single deep tile in
## a shelf of shallows, and a body that cannot swim walked to within one tile of
## the ladder. A walker stops at `WALL` because the deck is a wall; a moat only
## as wide as that wall leaves them standing against it with the bottom under
## their feet, which is wading whatever the distance from shore says. So the
## water is deep for one tile MORE than the wall, and the last of the way there
## is swum or rafted. Measured: every seed has such a tile 15-21 tiles out, at
## both 256 and the full world, so this costs the site nothing.
const WALL := 3.0
const MOAT := WALL + 1.0

static var _found: Dictionary = {}
## Worlds remembered at once; a test run grows hundreds and a game holds a few.
const CACHE_MOST := 64


## The site in `w`, or Vector2.INF where there is none.
static func site(w: WorldData) -> Vector2:
	# Keyed by the world itself, as Landmarks.sites is: two worlds grown from one
	# seed are not one world when a test has narrowed the registry, and a key of
	# seed, size and realm handed one of them the other's water.
	var key := w.get_instance_id()
	if _found.has(key):
		return _found[key]
	if _found.size() >= CACHE_MOST:
		_found.clear()
	var out := _look(w)
	_found[key] = out
	return out


## **ASK FOR THE PROPERTIES, NOT FOR A WALK THAT USUALLY HAS THEM.** This threw
## 72 rays out from the spawn and took the first deep tile past `NEAREST` on a
## ray that had not touched land since going wet. Every part of that was a proxy:
## the ray stood in for "offshore" and the dry-tile break stood in for "nobody
## wades to it", and both were wrong in both directions. A sandbar off to one
## side killed a bearing whose water was perfect, while a lone deep tile in a
## shelf of shallows passed and let a walker up to the ladder.
##
## So say the three things outright. It is in THE SEA (water joined to the map's
## edge, not a lake behind a spit); it has a MOAT of deep water, so the last of
## the way is swum; and it is `NEAREST` to `FURTHEST` from the spawn, measured to
## the tile that gets written down. The nearest one wins, so it still reads from
## the beach. No bearings, no step size, no walk that can be blocked by something
## that is not in the way.
static func _look(w: WorldData) -> Vector2:
	var sea := _sea(w)
	var from := w.spawn
	var best := Vector2.INF
	var best_out := INF
	var n := ceili(FURTHEST)
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var x := floori(from.x) + dx
			var y := floori(from.y) + dy
			if not w.in_bounds(x, y):
				continue
			var at := Vector2(x + 0.5, y + 0.5)
			var out := at.distance_to(from)
			if out < NEAREST or out > FURTHEST or out >= best_out:
				continue
			if sea[y * w.size + x] == 0:
				continue
			if w.ground_at(x, y) != Ground.DEEP_WATER or not _moated(w, x, y):
				continue
			best_out = out
			best = at
	return best


## Every water tile joined to the edge of the map: the sea, as against a pond
## inland that happens to be deep. One flood per world, which is why `site` is
## cached.
##
## **READ THE GRIDS, NOT THE ACCESSORS.** This was a Dictionary keyed by tile
## index and it asked `ground_at` for every neighbour, and at the full world that
## is 1.69 million hash inserts and as many function calls: measured 3.26 SECONDS,
## about a quarter of the whole of world generation, for a question about one
## platform. A `PackedByteArray` the size of the grid and a direct read of
## `w.ground` answer the same thing, tile for tile -- the site this picks is
## unchanged, which is the point, because moving it moves every world.
static func _sea(w: WorldData) -> PackedByteArray:
	var size := w.size
	var seen := PackedByteArray()
	seen.resize(size * size)
	var edge := PackedInt32Array()
	var ground := w.ground
	# One byte per ground id instead of a call per neighbour: the flood asks this
	# about four tiles for every tile it pops, so `Ground.is_water` was three
	# million calls at the full world.
	var wet := PackedByteArray()
	wet.resize(Ground.COUNT)
	for g in Ground.COUNT:
		wet[g] = 1 if Ground.is_water(g) else 0
	for i in size:
		for k: int in [i, (size - 1) * size + i, i * size, i * size + size - 1]:
			if seen[k] == 0 and wet[ground[k]] != 0:
				seen[k] = 1
				edge.append(k)
	while not edge.is_empty():
		var k := edge[edge.size() - 1]
		edge.remove_at(edge.size() - 1)
		var x := k % size
		var y := k / size
		if x > 0 and seen[k - 1] == 0 and wet[ground[k - 1]] != 0:
			seen[k - 1] = 1
			edge.append(k - 1)
		if x < size - 1 and seen[k + 1] == 0 and wet[ground[k + 1]] != 0:
			seen[k + 1] = 1
			edge.append(k + 1)
		if y > 0 and seen[k - size] == 0 and wet[ground[k - size]] != 0:
			seen[k - size] = 1
			edge.append(k - size)
		if y < size - 1 and seen[k + size] == 0 and wet[ground[k + size]] != 0:
			seen[k + size] = 1
			edge.append(k + size)
	return seen


## Everything the site stands on, as circles a body cannot walk through, in the
## shape `WorldQuery.set_blocks` takes. A platform is a wall in the water.
static func blocks(w: WorldData) -> Array:
	var p := site(w)
	if p == Vector2.INF:
		return []
	return [Vector3(p.x, p.y, WALL)]


## Whether every tile within `MOAT` of this one is deep water, so nothing that
## walks can stand within reach of the deck.
static func _moated(w: WorldData, cx: int, cy: int) -> bool:
	var n := ceili(MOAT)
	var size := w.size
	var ground := w.ground
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			if float(dx * dx + dy * dy) > MOAT * MOAT:
				continue
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= size or y >= size or ground[y * size + x] != Ground.DEEP_WATER:
				return false
	return true
