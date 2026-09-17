class_name WorldQuery
extends RefCounted
## Movement and spatial queries over WorldData. Pure, deterministic, headless.
##
## The world is walked on a flat plane in tile space; height is only visual.
## A body may step one level up or down; two or more is a cliff. Deep water
## blocks. Solid props block as circles.

var world: WorldData
var _cells: Dictionary = {} # int tile index -> Array[WorldProp]


func _init(w: WorldData) -> void:
	world = w
	for p in w.props:
		add_prop(p)


func add_prop(p: WorldProp) -> void:
	var k := floori(p.pos.y) * world.size + floori(p.pos.x)
	if not _cells.has(k):
		_cells[k] = []
	_cells[k].append(p)


func remove_prop(p: WorldProp) -> void:
	var k := floori(p.pos.y) * world.size + floori(p.pos.x)
	if _cells.has(k):
		_cells[k].erase(p)


## Every prop whose tile is within r tiles (square) of p.
func props_near(p: Vector2, r: float) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	# Clamp to the map: an unclamped tx past the east edge would wrap into the
	# next row's keys and return props twice.
	for ty in range(maxi(0, floori(p.y - r)), mini(world.size - 1, floori(p.y + r)) + 1):
		for tx in range(maxi(0, floori(p.x - r)), mini(world.size - 1, floori(p.x + r)) + 1):
			var k := ty * world.size + tx
			if _cells.has(k):
				for q: WorldProp in _cells[k]:
					out.append(q)
	return out


## The nearest prop within r whose kind is in `kinds` (empty = any), or null.
func nearest_prop(p: Vector2, r: float, kinds: Array[int] = []) -> WorldProp:
	var best: WorldProp = null
	var best_d := r * r
	for q in props_near(p, r):
		if not kinds.is_empty() and not kinds.has(q.kind):
			continue
		if world.depleted.has(q.id):
			continue
		var d := q.pos.distance_squared_to(p)
		if d <= best_d:
			best_d = d
			best = q
	return best


## `on` is the craft carrying the body (src/core/craft/), and the only thing that
## changes the answer: what a craft travels over counts as standable while it
## carries you. On foot it is null and the rules are a walker's.
func standable(tx: int, ty: int, on: CraftRide = null) -> bool:
	if not world.in_bounds(tx, ty):
		return false
	var g := world.ground[ty * world.size + tx]
	return on.crosses(g) if on != null else g != Ground.DEEP_WATER


## A craft may step further than a body's one level: two is a cliff to a body and
## a stride to a walker rig.
func passable(fx: int, fy: int, tx: int, ty: int, on: CraftRide = null) -> bool:
	if not standable(tx, ty, on):
		return false
	if fx == tx and fy == ty:
		return true
	var step := on.levels if on != null else 1
	return absi(world.level[fy * world.size + fx] - world.level[ty * world.size + tx]) <= step


## A body leaning into a trunk or boulder slides round it at least this share of its pace.
const SLIDE_MIN := 0.5


## Move a circle of radius r from p by delta, sliding round solid props and along
## walls. Returns the new position. Pushed into a circle the move is turned along
## its edge; testing x and y apart alone left a diagonal push dead against a
## trunk (both axes refused), so the player stuck instead of slipping past.
func move_body(p: Vector2, delta: Vector2, r: float, on: CraftRide = null) -> Vector2:
	if delta.length_squared() < 1e-12:
		return p
	var full := p + delta
	if _fits(p, full, r, on):
		return full
	var q := _blocker(p, full, r)
	if q != null:
		var n := p - q.pos
		n = n / n.length() if n.length_squared() > 1e-10 else -delta.normalized()
		var t := delta - n * delta.dot(n)
		if t.length_squared() > delta.length_squared() * 1e-4:
			var slide := t.normalized() * maxf(t.length(), delta.length() * SLIDE_MIN)
			if _fits(p, p + slide, r, on):
				return p + slide
	var nx := Vector2(p.x + delta.x, p.y)
	if not _fits(p, nx, r, on):
		nx = p
	var ny := Vector2(nx.x, nx.y + delta.y)
	if not _fits(nx, ny, r, on):
		ny = nx
	return ny


## The nearest solid prop a move from `from` to `to` pushes into, or null.
func _blocker(from: Vector2, to: Vector2, r: float) -> WorldProp:
	var best: WorldProp = null
	var best_d := INF
	for q in props_near(to, 2.0):
		if q.solid <= 0.0 or world.depleted.has(q.id):
			continue
		var rr := q.solid + r
		var after := q.pos.distance_squared_to(to)
		if after < rr * rr and after < q.pos.distance_squared_to(from) and after < best_d:
			best_d = after
			best = q
	return best


func _fits(from: Vector2, to: Vector2, r: float, on: CraftRide = null) -> bool:
	var ftx := floori(from.x)
	var fty := floori(from.y)
	for c: Vector2 in [to, to + Vector2(-r, -r), to + Vector2(r, -r), to + Vector2(-r, r), to + Vector2(r, r)]:
		if not passable(ftx, fty, floori(c.x), floori(c.y), on):
			return false
	for q in props_near(to, 2.0):
		if q.solid <= 0.0 or world.depleted.has(q.id):
			continue
		var rr := q.solid + r
		var after := q.pos.distance_squared_to(to)
		# Only block when it would bring us closer: bodies can always leave an overlap.
		if after < rr * rr and after < q.pos.distance_squared_to(from):
			return false
	return true
