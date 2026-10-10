class_name WakeSpot
extends RefCounted
## WHERE THE SEA LEFT HIM (docs/STORY.md: "Waking in the surf: released from the
## black site offshore; Maren pulls him out"). A new game's first morning opens
## on him face down on the tideline of the spawn beach, where the line from the
## beach out to the black site comes ashore, so the site stands in the sea
## behind him and the land is ahead.
##
##   WakeSpot.find(world) -> {at, maren, face}, or {} where there is no such place
##
## `at` is where he lies: a dry tile touching the water near where the line
## comes ashore, on a beach with wading water off it (not a lip over deep water),
## open to the sky the length of him, so the view sees a body and not a ridge
## (`_lie_cost`); `maren` a dry tile at the water's edge a few paces from him and
## on his level, where she waits; `face` the bearing inland, away from the water
## round him, the way he lies and stands. PURE: a function of the world, never saved.

## How far past the tideline the beach must still be wading water, in tiles: a
## shore he could have washed up on, not a drop into deep water.
const WADE_IN := 2.5
## How far round from the site's bearing a line to it may turn to find wading
## water, either way: past this the site no longer stands behind him.
const TURN_MOST := deg_to_rad(60.0)
const TURN_STEP := deg_to_rad(10.0)
## How far along a line the tideline is looked for.
const REACH := 60.0
## How far round the landing a shore tile is looked for, in tiles, and how much
## a tile of distance weighs against a unit of height (low wins first) for his
## place and for hers. Sand and shingle are where the sea leaves things: other
## ground costs NOT_BEACH. She stands at least MAREN_APART clear of his body,
## and about MAREN_PACES off.
const LIE_REACH := 8
const EDGE_REACH := 5
const EDGE_NEAR := 0.15
const NOT_BEACH := 0.6
const MAREN_NEAR := 0.5
const MAREN_APART := 1.2
const MAREN_PACES := 2.2
## How far toward the water from his tile's centre he lies, his boots at its
## edge, and how far up the beach from there his head reaches (PersonAnim's
## lying body, a little over).
const SEAWARD := 0.15
const HEAD := 1.2
const STEP := 0.5


static func find(w: WorldData) -> Dictionary:
	if w == null or w.realm != Realm.SURFACE:
		return {}
	var site := BlackSite.site(w)
	if site == Vector2.INF:
		return {}
	var base := (site - w.spawn).angle()
	var turn := 0.0
	while turn <= TURN_MOST + 0.001:
		for sign: float in ([1.0] if turn == 0.0 else [1.0, -1.0]):
			var got := _along(w, base + turn * sign)
			if not got.is_empty():
				return got
		turn += TURN_STEP
	return {}


## Out from the spawn along `bearing`: the last dry tile before the first water,
## then the wading water past it. Nothing where the water starts deep, or the
## line meets no water before REACH.
static func _along(w: WorldData, bearing: float) -> Dictionary:
	var dir := Vector2.from_angle(bearing)
	var dry := Vector2.INF
	var t := 0.0
	while t < REACH:
		var p := w.spawn + dir * t
		if not _inside(w, p):
			return {}
		if Ground.is_water(_ground(w, p)):
			break
		dry = p
		t += STEP
	if t >= REACH or dry == Vector2.INF:
		return {}
	var shore_t := t
	var at := Vector2.INF
	while t <= shore_t + WADE_IN:
		var p := w.spawn + dir * t
		if not _inside(w, p):
			break
		var g := _ground(w, p)
		if not Ground.is_water(g) or Ground.is_deep(g):
			break
		at = p
		t += STEP
	# Less than a pace of wading water is a lip over the deep, not a beach.
	if at == Vector2.INF or at.distance_to(w.spawn + dir * shore_t) < 1.0:
		return {}
	var lie := _edge(w, dry, LIE_REACH, func(p: Vector2) -> float: return _lie_cost(w, p, at))
	if lie == Vector2.INF:
		return {}
	var inland := _inland(w, lie)
	var head := lie + inland * HEAD
	var level := w.level_at(floori(lie.x), floori(lie.y))
	var maren := _edge(w, lie, EDGE_REACH, func(p: Vector2) -> float:
		if w.level_at(floori(p.x), floori(p.y)) != level or Geometry2D.get_closest_point_to_segment(p, lie, head).distance_to(p) < MAREN_APART:
			return INF
		return MAREN_NEAR * absf(p.distance_to(lie) - MAREN_PACES))
	if maren == Vector2.INF:
		return {}
	return {"at": lie - inland * SEAWARD, "maren": maren, "face": inland.angle()}


## What lying at `p` costs, INF where the view would not see him: his head up
## the beach on the same level as his boots, and nothing higher round either,
## or the body lies behind a ridge (the first washed-up frames: a strip of grass
## under a terrace, and nobody there). Then the nearer the line's landing `at`
## the better, and sand or shingle before anything else.
static func _lie_cost(w: WorldData, p: Vector2, at: Vector2) -> float:
	var inland := _inland(w, p)
	if inland == Vector2.ZERO:
		return INF
	var level := w.level_at(floori(p.x), floori(p.y))
	var head := p + inland * HEAD
	if Ground.is_water(_ground(w, head)) or w.level_at(floori(head.x), floori(head.y)) != level:
		return INF
	for end: Vector2 in [p, head]:
		for y in range(floori(end.y) - 1, floori(end.y) + 2):
			for x in range(floori(end.x) - 1, floori(end.x) + 2):
				if w.level_at(x, y) > level:
					return INF
	var g := _ground(w, p)
	return EDGE_NEAR * p.distance_to(at) + (0.0 if g == Ground.SAND or g == Ground.SHINGLE else NOT_BEACH)


## The LOWEST dry tile touching the water within `reach` of `centre`, `far`
## adding to a tile's height what its place costs (INF rules it out), or INF
## where nothing will do. The line's own last dry tile is often the lip of a
## terrace a step above the beach: she stood on one over him like a statue on a
## plinth (the first wake frames).
static func _edge(w: WorldData, centre: Vector2, reach: int, far: Callable) -> Vector2:
	var best := Vector2.INF
	var best_score := INF
	var cx := floori(centre.x)
	var cy := floori(centre.y)
	for y in range(cy - reach, cy + reach + 1):
		for x in range(cx - reach, cx + reach + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if not _inside(w, p) or Ground.is_water(w.ground_at(x, y)) or not _touches_water(w, x, y):
				continue
			var score := w.height_at(p) + float(far.call(p))
			if score < best_score:
				best_score = score
				best = p
	return best


## Away from the water round `p`: the way up the beach from where the sea left
## him, or zero where no water is near enough to say.
static func _inland(w: WorldData, p: Vector2) -> Vector2:
	var away := Vector2.ZERO
	var cx := floori(p.x)
	var cy := floori(p.y)
	for y in range(cy - 2, cy + 3):
		for x in range(cx - 2, cx + 3):
			if (x != cx or y != cy) and _inside(w, Vector2(x, y)) and Ground.is_water(w.ground_at(x, y)):
				away += (p - Vector2(x + 0.5, y + 0.5)).normalized()
	return away.normalized() if away.length() > 0.01 else Vector2.ZERO


static func _touches_water(w: WorldData, x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q := Vector2(x + d.x + 0.5, y + d.y + 0.5)
		if _inside(w, q) and Ground.is_water(w.ground_at(x + d.x, y + d.y)):
			return true
	return false


static func _ground(w: WorldData, p: Vector2) -> int:
	return w.ground_at(floori(p.x), floori(p.y))


static func _inside(w: WorldData, p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < float(w.size) and p.y < float(w.size)


static func _centre(p: Vector2) -> Vector2:
	return Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
