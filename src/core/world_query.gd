class_name WorldQuery
extends RefCounted
## Movement and spatial queries over WorldData. Pure, deterministic, headless.
##
## The world is walked on a flat plane in tile space; height is only visual.
## A body may step one level up or down; two or more is a cliff. Deep water
## blocks. Solid props block as circles.

var world: WorldData
var _cells: Dictionary = {} # int tile index -> Array[WorldProp]
## Circles that stop a body but are NOT props: the mass of something a package
## draws itself and the world never recorded — a landmark's tower, a depot's deck
## (src/core/landmarks, src/core/works). Kept apart from props on purpose: nothing
## may take one, hear one, shelter under one or read it as cover, because it is
## only a wall. Owned by whoever set it, so a realm crossing replaces the set
## rather than piling a second island's walls on top of the first's.
var _blocks: Dictionary = {}    # int tile index -> Array[Vector3] (x, z, radius)
var _block_by: Dictionary = {}  # owner -> Array[Vector3]
## Tiles of slack when a circle is stamped into the grid, so one tile lookup is
## enough for any body narrower than this.
const BLOCK_SLACK := 1.0


func _init(w: WorldData) -> void:
	world = w
	for p in w.props:
		add_prop(p)


## Everything `owner` stops a body with, replacing whatever it said before. The
## circles are in TILE space, `(x, y, radius)`.
func set_blocks(owner: StringName, circles: Array[Vector3]) -> void:
	if circles.is_empty():
		if not _block_by.has(owner):
			return
		@warning_ignore("return_value_discarded")
		_block_by.erase(owner)
	else:
		_block_by[owner] = circles
	_blocks.clear()
	for rows: Variant in _block_by.values():
		for c: Vector3 in rows as Array[Vector3]:
			var r := ceili(c.z + BLOCK_SLACK)
			var cx := floori(c.x)
			var cy := floori(c.y)
			for ty in range(maxi(0, cy - r), mini(world.size - 1, cy + r) + 1):
				for tx in range(maxi(0, cx - r), mini(world.size - 1, cx + r) + 1):
					var k := ty * world.size + tx
					if not _blocks.has(k):
						_blocks[k] = []
					(_blocks[k] as Array).append(c)


## The walls whose tile `p` stands in. One lookup: every circle is stamped into
## every tile it could stop a body in, so this is the whole answer.
func blocks_at(p: Vector2) -> Array:
	var tx := floori(p.x)
	var ty := floori(p.y)
	if tx < 0 or ty < 0 or tx >= world.size or ty >= world.size:
		return []
	return _blocks.get(ty * world.size + tx, [])


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
## `swims` is a body that can take deep water on its own (a person, a beast, the
## dredger): to anything else deep water is the wall it has always been. A craft
## under the body answers first, because a raft is not a swimmer.
func standable(tx: int, ty: int, on: CraftRide = null, swims: bool = false) -> bool:
	if not world.in_bounds(tx, ty):
		return false
	var g := world.ground[ty * world.size + tx]
	if on != null:
		return on.crosses(g)
	return swims or g != Ground.DEEP_WATER


## A craft may step further than a body's one level: two is a cliff to a body and
## a stride to a walker rig.
func passable(fx: int, fy: int, tx: int, ty: int, on: CraftRide = null, swims: bool = false) -> bool:
	if not standable(tx, ty, on, swims):
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
func move_body(p: Vector2, delta: Vector2, r: float, on: CraftRide = null, swims: bool = false) -> Vector2:
	if delta.length_squared() < 1e-12:
		return p
	var full := p + delta
	if _fits(p, full, r, on, swims):
		return full
	var hit := _blocker(p, full, r)
	if hit.is_finite():
		var n := p - Vector2(hit.x, hit.y)
		n = n / n.length() if n.length_squared() > 1e-10 else -delta.normalized()
		var t := delta - n * delta.dot(n)
		if t.length_squared() > delta.length_squared() * 1e-4:
			var slide := t.normalized() * maxf(t.length(), delta.length() * SLIDE_MIN)
			if _fits(p, p + slide, r, on, swims):
				return p + slide
	var nx := Vector2(p.x + delta.x, p.y)
	if not _fits(p, nx, r, on, swims):
		nx = p
	var ny := Vector2(nx.x, nx.y + delta.y)
	if not _fits(nx, ny, r, on, swims):
		ny = nx
	return ny


## The nearest thing a move from `from` to `to` pushes into, as its centre, or
## Vector2.INF. A solid prop or one of `set_blocks`' walls: the slide is the same
## either way, so the caller is told where the middle of it is and nothing else.
func _blocker(from: Vector2, to: Vector2, r: float) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for q in props_near(to, 2.0):
		if q.solid <= 0.0 or world.depleted.has(q.id):
			continue
		var rr := q.solid + r
		var after := q.pos.distance_squared_to(to)
		if after < rr * rr and after < q.pos.distance_squared_to(from) and after < best_d:
			best_d = after
			best = q.pos
	for c: Vector3 in blocks_at(to):
		var at := Vector2(c.x, c.y)
		var rr := c.z + r
		var after := at.distance_squared_to(to)
		if after < rr * rr and after < at.distance_squared_to(from) and after < best_d:
			best_d = after
			best = at
	return best


func _fits(from: Vector2, to: Vector2, r: float, on: CraftRide = null, swims: bool = false) -> bool:
	var ftx := floori(from.x)
	var fty := floori(from.y)
	for c: Vector2 in [to, to + Vector2(-r, -r), to + Vector2(r, -r), to + Vector2(-r, r), to + Vector2(r, r)]:
		if not passable(ftx, fty, floori(c.x), floori(c.y), on, swims):
			return false
	for q in props_near(to, 2.0):
		if q.solid <= 0.0 or world.depleted.has(q.id):
			continue
		var rr := q.solid + r
		var after := q.pos.distance_squared_to(to)
		# Only block when it would bring us closer: bodies can always leave an overlap.
		if after < rr * rr and after < q.pos.distance_squared_to(from):
			return false
	for c: Vector3 in blocks_at(to):
		var at := Vector2(c.x, c.y)
		var rr := c.z + r
		var after := at.distance_squared_to(to)
		if after < rr * rr and after < at.distance_squared_to(from):
			return false
	return true
