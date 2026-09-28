class_name WakeSpot
extends RefCounted
## WHERE HE COMES UP (docs/STORY.md: "Waking in the surf: released from the black
## site offshore; Maren pulls him out"). A new game's first morning starts him in
## the shallows off the spawn beach, on the line from the beach out to the black
## site, so the site stands in the sea behind him and the shore is ahead.
##
##   WakeSpot.find(world) -> {at, maren, face}, or {} where there is no such place
##
## `at` is a wading tile (water, not deep: he stands in it, he does not swim) a
## few paces out from the tideline; `maren` a dry tile at the water's edge near
## it, on the beach rather than a step above it, where she waits; `face` the
## bearing from `at` to her. PURE: a function of the world, never saved.

## How far past the tideline he comes up, in tiles: out in the surf, and still
## in his depth.
const WADE_IN := 2.5
## How far round from the site's bearing a line to it may turn to find wading
## water, either way: past this the site no longer stands behind him.
const TURN_MOST := deg_to_rad(60.0)
const TURN_STEP := deg_to_rad(10.0)
## How far along a line the tideline is looked for.
const REACH := 60.0
## How far round the landing Maren's place is looked for, in tiles, and how much
## a tile of distance from him weighs against a unit of height (low wins first).
const EDGE_REACH := 5
const EDGE_NEAR := 0.15
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
	# Less than a pace of wading water is a tideline, not a surf to rise out of.
	if at == Vector2.INF or at.distance_to(w.spawn + dir * shore_t) < 1.0:
		return {}
	var edge := _edge(w, dry, at)
	return {"at": _centre(at), "maren": edge, "face": (edge - at).angle()}


## Where Maren waits: the LOWEST dry tile touching the water near where the line
## came ashore, and of those the nearest him. The line's own last dry tile is
## often the lip of a terrace a step above the beach, and she stood on it over
## him like a statue on a plinth (the first wake frames).
static func _edge(w: WorldData, dry: Vector2, at: Vector2) -> Vector2:
	var best := _centre(dry)
	var best_score := INF
	var cx := floori(dry.x)
	var cy := floori(dry.y)
	for y in range(cy - EDGE_REACH, cy + EDGE_REACH + 1):
		for x in range(cx - EDGE_REACH, cx + EDGE_REACH + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if not _inside(w, p) or Ground.is_water(w.ground_at(x, y)) or not _touches_water(w, x, y):
				continue
			var score := w.height_at(p) + EDGE_NEAR * p.distance_to(at)
			if score < best_score:
				best_score = score
				best = p
	return best


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
