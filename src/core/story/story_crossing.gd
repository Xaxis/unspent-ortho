class_name StoryCrossing
## THE CROSSING (ROADMAP slice 3, step 1): where a raft puts in from the home body
## and lands on the next leg's, for the goal line and the survey (49_cast places
## it as `the_crossing` and `the_landing`). The NARROWEST open water between the
## two bodies within REACH of the line from the crew's camp, the last place of the
## home leg, to the archive, the next leg's: a raft's crossing is the shortest one
## a short walk off his road, never the one a straight line happens to hit (seed
## 1's ray met 279 tiles; its narrows are about 130, 60 tiles off the line).
## Scans only that band of shore, every STEP tiles.
##
## Two things he does are heard for the goal line (Guide.WAY): putting a craft
## afloat (44_crafts) and first standing on the far body (49_cast).

## The two places 49_cast adds to the cast for it: where he puts in, where he lands.
const LAUNCH := &"the_crossing"
const LANDING := &"the_landing"

const PUT_IN := &"seen:raft_put_in"
const CROSSED := &"seen:far_shore"


## How far off the camp-to-archive line a put-in or a landing may lie, in tiles.
const REACH := 120.0
## The band is read every STEP tiles each way: a shore found to within a tile or two.
const STEP := 2


## {launch: Vector2, land: Vector2, water: float (tiles)}, or {} where both ends
## stand on one body, either stands on none, or no open water joins the two
## bodies inside the band.
static func find(world: WorldData, from: Vector2, to: Vector2) -> Dictionary:
	return find_within(world, from, to, REACH)


static func find_within(world: WorldData, from: Vector2, to: Vector2, reach: float) -> Dictionary:
	if world == null or world.same_body(from, to):
		return {}
	var home := world.continent_at(floori(from.x), floori(from.y))
	var far := world.continent_at(floori(to.x), floori(to.y))
	if home == 0 or far == 0:
		return {}
	var lo := Vector2i((from.min(to) - Vector2(reach, reach)).floor())
	var hi := Vector2i((from.max(to) + Vector2(reach, reach)).ceil())
	var homes: Array[Vector2] = []
	var fars: Array[Vector2] = []
	for y in range(lo.y, hi.y + 1, STEP):
		for x in range(lo.x, hi.x + 1, STEP):
			var c := world.continent_at(x, y)
			if c != home and c != far:
				continue
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			if Geometry2D.get_closest_point_to_segment(p, from, to).distance_to(p) > reach:
				continue
			if not _shore(world, x, y):
				continue
			(homes if c == home else fars).append(p)
	return _narrowest(world, homes, fars)


## Every home shore paired with its nearest far shore, narrowest first; the first
## whose straight run is open water all the way is the crossing, or {}.
static func _narrowest(world: WorldData, homes: Array[Vector2], fars: Array[Vector2]) -> Dictionary:
	var pairs: Array[Array] = []
	for h in homes:
		var best := INF
		var at := Vector2.INF
		for f in fars:
			var d := h.distance_squared_to(f)
			if d < best:
				best = d
				at = f
		if at.is_finite():
			pairs.append([sqrt(best), h, at])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for pair in pairs:
		if _open_water(world, pair[1], pair[2]):
			return {"launch": pair[1], "land": pair[2], "water": float(pair[0])}
	return {}


## Where the raft crosses on a world the story is cast on (`cast`: StoryPlan.cast's
## answer): ashore at the world's landfall where it lies on the archive's body
## (`to_landfall`), else across the narrows between the crew's camp and the
## archive (`find`). The one rule the game (49_cast) and every test read the
## crossing by.
static func of(world: WorldData, cast: Dictionary) -> Dictionary:
	if not cast.has(&"the_camp") or not cast.has(&"the_archive"):
		return {}
	var camp: Vector2 = cast[&"the_camp"].pos
	var archive: Vector2 = cast[&"the_archive"].pos
	var c := {}
	if cast.has(&"the_landfall") and world.same_body(cast[&"the_landfall"].pos, archive):
		c = to_landfall(world, camp, cast[&"the_landfall"].pos)
	return c if not c.is_empty() else find(world, camp, archive)


## How far from the landfall the raft may come ashore, and put in from, in tiles:
## its far shore within ASHORE of it, the home shore within PUT_IN_REACH.
const ASHORE := 48.0
const PUT_IN_REACH := 300.0


## THE LANDFALL FIRST (StorySlot.LANDFALL): the raft comes ashore where the
## shortest water from home does, and the landfall's city stands its port and its
## clock there, not on whatever shore the narrows off his road happen to reach (on
## seed 7 those were 126 tiles off it). The narrowest open water from a home shore
## within PUT_IN_REACH of the landfall to a far shore within ASHORE of it, as
## `find` pairs them. {launch, land, water}, or {} where none, and the narrows
## decide.
static func to_landfall(world: WorldData, from: Vector2, landfall: Vector2) -> Dictionary:
	if world == null or not landfall.is_finite() or world.same_body(from, landfall):
		return {}
	var home := world.continent_at(floori(from.x), floori(from.y))
	var far := world.continent_at(floori(landfall.x), floori(landfall.y))
	if home == 0 or far == 0:
		return {}
	var homes: Array[Vector2] = []
	var fars: Array[Vector2] = []
	var lo := Vector2i((landfall - Vector2(PUT_IN_REACH, PUT_IN_REACH)).floor())
	var hi := Vector2i((landfall + Vector2(PUT_IN_REACH, PUT_IN_REACH)).ceil())
	for y in range(lo.y, hi.y + 1, STEP):
		for x in range(lo.x, hi.x + 1, STEP):
			var c := world.continent_at(x, y)
			if c != home and c != far:
				continue
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			var d := p.distance_to(landfall)
			if (c == home and d > PUT_IN_REACH) or (c == far and d > ASHORE) or not _shore(world, x, y):
				continue
			(homes if c == home else fars).append(p)
	return _narrowest(world, homes, fars)


## Land with water beside it.
static func _shore(world: WorldData, x: int, y: int) -> bool:
	if Ground.is_water(world.ground_at(x, y)):
		return false
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if Ground.is_water(world.ground_at(x + n.x, y + n.y)):
			return true
	return false


## Water on every tile of the run between two shores, their own tiles aside.
static func _open_water(world: WorldData, a: Vector2, b: Vector2) -> bool:
	var ta := Vector2i(a.floor())
	var tb := Vector2i(b.floor())
	var steps := ceili(a.distance_to(b) * 2.0)
	for i in range(1, steps):
		var t := Vector2i((a + (b - a) * (float(i) / float(steps))).floor())
		if t == ta or t == tb:
			continue
		if not Ground.is_water(world.ground_at(t.x, t.y)):
			# A step off the shore it left or onto the one it reaches is still
			# the shore, not land in the way.
			if world.continent_at(t.x, t.y) == world.continent_at(ta.x, ta.y) and t.distance_to(ta) < 3.0:
				continue
			if world.continent_at(t.x, t.y) == world.continent_at(tb.x, tb.y) and t.distance_to(tb) < 3.0:
				continue
			return false
	return true
