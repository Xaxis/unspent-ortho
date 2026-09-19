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
## Bearings tried, and how far along each. Fixed counts, so the answer is the
## same on every machine.
const BEARINGS := 72
const STEP := 1.0

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


static func _look(w: WorldData) -> Vector2:
	var from := w.spawn
	var best := Vector2.INF
	var best_score := -1e9
	for b in BEARINGS:
		var dir := Vector2.from_angle(TAU * float(b) / float(BEARINGS))
		# Out to the waterline first — the spawn stands beside a village and not
		# on the sand, so the first tiles of any bearing are dry and that is not a
		# reason to give up on it. Once the walk is IN the water, land ends it:
		# a site somebody can wade to is not offshore, whatever its distance.
		var afloat := false
		var d := 1.0
		while d <= FURTHEST:
			var p := from + dir * d
			var x := floori(p.x)
			var y := floori(p.y)
			if not w.in_bounds(x, y):
				break
			var g := w.ground_at(x, y)
			var wet := Ground.is_water(g)
			if wet:
				afloat = true
			elif afloat:
				break
			if afloat and d >= NEAREST and g == Ground.DEEP_WATER:
				# The nearest such place wins, so it reads from the shore.
				var at := Vector2(x + 0.5, y + 0.5)
				# AND THE WHOLE CROSSING IS WALKED BEFORE IT IS ACCEPTED. The loop
				# above steps `STEP` along a bearing and this walks the finished
				# line tile by tile to the site's own centre -- the same line, but
				# sampled at a different phase and ending half a tile further on,
				# which is exactly how a one-tile bar got missed here and caught by
				# the test that holds the claim. A place chosen by one rule and
				# judged by another is only ever accidentally right.
				if not _no_way_out(w, from, at):
					break
				var score := 100.0 - d
				if score > best_score:
					best_score = score
					best = at
				break
			d += STEP
	return best


## Once the line from `from` to `to` is IN the water, does it stay in it? No bar,
## no spit, no stepping stones: only a craft crosses it.
##
## Walked at the finest step the tiles have, so nothing can hide between two
## samples. `_look` steps a bearing in whole units and a one-tile bar sat exactly
## in the gap; the rule a place is chosen by has to be the rule it is judged by.
static func _no_way_out(w: WorldData, from: Vector2, to: Vector2) -> bool:
	var steps := maxi(2, int(ceilf(from.distance_to(to) * 2.0)))
	var afloat := false
	for i in range(1, steps + 1):
		var q := from.lerp(to, float(i) / float(steps))
		if Ground.is_water(w.ground_at(floori(q.x), floori(q.y))):
			afloat = true
		elif afloat:
			return false
	return afloat


## Everything the site stands on, as circles a body cannot walk through, in the
## shape `WorldQuery.set_blocks` takes. A platform is a wall in the water.
static func blocks(w: WorldData) -> Array:
	var p := site(w)
	if p == Vector2.INF:
		return []
	return [Vector3(p.x, p.y, 3.0)]
