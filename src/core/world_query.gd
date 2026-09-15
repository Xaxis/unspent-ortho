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


func standable(tx: int, ty: int) -> bool:
	return world.in_bounds(tx, ty) and world.ground[ty * world.size + tx] != Ground.DEEP_WATER


func passable(fx: int, fy: int, tx: int, ty: int) -> bool:
	if not standable(tx, ty):
		return false
	if fx == tx and fy == ty:
		return true
	return absi(world.level[fy * world.size + fx] - world.level[ty * world.size + tx]) <= 1


## Move a circle of radius r from p by delta, sliding along walls. Returns the new position.
func move_body(p: Vector2, delta: Vector2, r: float) -> Vector2:
	var nx := Vector2(p.x + delta.x, p.y)
	if not _fits(p, nx, r):
		nx = p
	var ny := Vector2(nx.x, nx.y + delta.y)
	if not _fits(nx, ny, r):
		ny = nx
	return ny


func _fits(from: Vector2, to: Vector2, r: float) -> bool:
	var ftx := floori(from.x)
	var fty := floori(from.y)
	for c: Vector2 in [to, to + Vector2(-r, -r), to + Vector2(r, -r), to + Vector2(-r, r), to + Vector2(r, r)]:
		if not passable(ftx, fty, floori(c.x), floori(c.y)):
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
