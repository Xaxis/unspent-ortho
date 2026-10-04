class_name WorldQuery
extends RefCounted
## Movement and spatial queries over WorldData. Pure, deterministic, headless.
##
## The world is walked on a flat plane in tile space; height is only visual.
## A body may step one level up or down; two or more is a cliff. Deep water
## blocks. Solid props block as circles.

var world: WorldData
## Tile index -> the table rows of the props standing on it (`WorldData.table`):
## rows, not objects, so a world's props are not held here as ~130k objects.
var _cells: Dictionary = {}
## Tile index -> props the world does not hold (a settlement's ghosts of what it
## plans to build): objects, a handful, stopping bodies like any prop.
var _ghosts: Dictionary = {}
## Circles that stop a body but are NOT props: the mass of something a package
## draws itself and the world never recorded — a landmark's tower, a depot's deck
## (src/core/landmarks, src/core/works). Kept apart from props on purpose: nothing
## may take one, hear one, shelter under one or read it as cover, because it is
## only a wall. Owned by whoever set it, so a realm crossing replaces the set
## rather than piling a second island's walls on top of the first's.
var _blocks: Dictionary = {}    # int tile index -> Array[Vector3] (x, z, radius)
## Lines sight does not pass and nothing else notices: (ax, ay, bx, by) in tile
## space. The veil's falling water (FightSim.veils), set by the fight as it
## stands and falls; `Senses.line_clear` reads it, so what cannot see through it
## is everything that looks, and bodies, blows and sound go through.
var sight_screens: Array[Vector4] = []
var _block_by: Dictionary = {}  # owner -> Array[Vector3]
## Tiles of slack when a circle is stamped into the grid, so one tile lookup is
## enough for any body narrower than this.
const BLOCK_SLACK := 1.0


## The widest solid any prop here has, which sets how far round a body every
## search for what stops it must look (`solid_reach`). A fixed two tiles let a
## body sink into any solid over about 1.72, 1.45 tiles into one of 3.22 (city
## buildings, the big coastal houses, murals). Only grows: a prop taken away
## leaves it as wide.
var _solid_most := 0.0


func _init(w: WorldData) -> void:
	world = w
	w.sync_table()
	var pos := w.table.pos
	var solid := w.table.solid
	for row in w.table.size():
		_file(floori(pos[row].y) * w.size + floori(pos[row].x), row)
		_solid_most = maxf(_solid_most, solid[row])


## How far round a point a body of radius r can be touched by a prop's solid:
## the window every search for what stops a body has to look through.
func solid_reach(r: float) -> float:
	return _solid_most + r


func _file(k: int, row: int) -> void:
	if not _cells.has(k):
		_cells[k] = PackedInt32Array()
	var cell: PackedInt32Array = _cells[k]
	cell.append(row)
	_cells[k] = cell


## Everything `owner` stops a body with, replacing whatever it said before. The
## circles are in TILE space, `(x, y, radius)`.
func set_blocks(owner: StringName, circles: Array[Vector3]) -> void:
	# ONLY THIS OWNER'S STAMP IS REDONE. This used to `_blocks.clear()` and
	# restamp EVERY owner whenever any one of them changed, so a chapter turning
	# over re-stamped the landmarks, the works yards and the holdings as well --
	# measured at 6.8 ms of `24_holds`' 7.4 ms worst frame, all of it spent on
	# circles that had not moved.
	#
	# The header above `_set_walls` says that rebuild is cheap "because a world
	# holds tens of these, not thousands", which is true of the CALLER's circles
	# and says nothing about everyone else's. The count was never the variable.
	if not _block_by.has(owner) and circles.is_empty():
		return
	_unstamp(_block_by.get(owner, [] as Array[Vector3]))
	if circles.is_empty():
		@warning_ignore("return_value_discarded")
		_block_by.erase(owner)
	else:
		# Kept as OUR copy: `_unstamp` has to be handed exactly what was stamped,
		# and a caller that reuses and mutates its own array would otherwise leave
		# entries behind that nothing can find again.
		_block_by[owner] = circles.duplicate()
		_stamp(_block_by[owner])


## Every tile a circle could stop a body in, stamped with the circle itself, so
## `blocks_at` is one lookup.
func _stamp(circles: Array[Vector3]) -> void:
	for c: Vector3 in circles:
		var r := ceili(c.z + BLOCK_SLACK)
		var cx := floori(c.x)
		var cy := floori(c.y)
		for ty in range(maxi(0, cy - r), mini(world.size - 1, cy + r) + 1):
			for tx in range(maxi(0, cx - r), mini(world.size - 1, cx + r) + 1):
				var k := ty * world.size + tx
				if not _blocks.has(k):
					_blocks[k] = []
				(_blocks[k] as Array).append(c)


## The exact inverse, walking the same tiles. `erase` takes ONE match, which is
## right: `_stamp` appended one entry per circle per tile, so two owners holding
## an identical circle keep one entry each.
func _unstamp(circles: Array[Vector3]) -> void:
	for c: Vector3 in circles:
		var r := ceili(c.z + BLOCK_SLACK)
		var cx := floori(c.x)
		var cy := floori(c.y)
		for ty in range(maxi(0, cy - r), mini(world.size - 1, cy + r) + 1):
			for tx in range(maxi(0, cx - r), mini(world.size - 1, cx + r) + 1):
				var k := ty * world.size + tx
				var got: Variant = _blocks.get(k)
				if got == null:
					continue
				(got as Array).erase(c)
				if (got as Array).is_empty():
					@warning_ignore("return_value_discarded")
					_blocks.erase(k)


## The walls whose tile `p` stands in. One lookup: every circle is stamped into
## every tile it could stop a body in, so this is the whole answer.
func blocks_at(p: Vector2) -> Array:
	var tx := floori(p.x)
	var ty := floori(p.y)
	if tx < 0 or ty < 0 or tx >= world.size or ty >= world.size:
		return []
	return _blocks.get(ty * world.size + tx, [])


func add_prop(p: WorldProp) -> void:
	_solid_most = maxf(_solid_most, p.solid)
	var k := floori(p.pos.y) * world.size + floori(p.pos.x)
	var row := world.row_of_id(p.id)
	if row >= 0:
		_file(k, row)
		return
	if not _ghosts.has(k):
		_ghosts[k] = [] as Array[WorldProp]
	(_ghosts[k] as Array[WorldProp]).append(p)


func remove_prop(p: WorldProp) -> void:
	var k := floori(p.pos.y) * world.size + floori(p.pos.x)
	var row := world.row_of_id(p.id)
	if row >= 0 and _cells.has(k):
		var cell: PackedInt32Array = _cells[k]
		var at := cell.find(row)
		if at >= 0:
			cell.remove_at(at)
			_cells[k] = cell
		return
	if _ghosts.has(k):
		var ghosts: Array[WorldProp] = _ghosts[k]
		for i in ghosts.size():
			if WorldProp.same(ghosts[i], p):
				ghosts.remove_at(i)
				return


## Every prop whose tile is within r tiles (square) of p.
func props_near(p: Vector2, r: float) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	for row in rows_near(p, r):
		out.append(world.prop_at(row))
	out.append_array(ghosts_near(p, r))
	return out


## The table rows of every prop whose tile is within r tiles (square) of p: what
## a hot loop reads the columns by, making no object.
func rows_near(p: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	# Clamp to the map: an unclamped tx past the east edge would wrap into the
	# next row's keys and return props twice.
	for ty in range(maxi(0, floori(p.y - r)), mini(world.size - 1, floori(p.y + r)) + 1):
		for tx in range(maxi(0, floori(p.x - r)), mini(world.size - 1, floori(p.x + r)) + 1):
			var k := ty * world.size + tx
			if _cells.has(k):
				out.append_array(_cells[k])
	return out


## The ghosts (props the world does not hold) within r tiles (square) of p.
func ghosts_near(p: Vector2, r: float) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	if _ghosts.is_empty():
		return out
	for ty in range(maxi(0, floori(p.y - r)), mini(world.size - 1, floori(p.y + r)) + 1):
		for tx in range(maxi(0, floori(p.x - r)), mini(world.size - 1, floori(p.x + r)) + 1):
			var k := ty * world.size + tx
			if _ghosts.has(k):
				out.append_array(_ghosts[k])
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
##
## `tall`: levels of headroom the body needs (a body `h` world units tall needs
## ceili(h / STEP)). Where mass hangs over a tile (WorldData.overhead) a body
## taller than the room under it cannot go there: a low roof is a wall to a
## person and a crawlway to a runner. 0 asks nothing overhead.
func passable(fx: int, fy: int, tx: int, ty: int, on: CraftRide = null, swims: bool = false, tall: int = 0) -> bool:
	if not standable(tx, ty, on, swims):
		return false
	if tall > 0 and world.has_overhead() and world.headroom_at(tx, ty) < tall:
		return false
	if fx == tx and fy == ty:
		return true
	var step := on.levels if on != null else 1
	return absi(world.level[fy * world.size + fx] - world.level[ty * world.size + tx]) <= step


## Whether something set down with footprint radius `r` at `spot` (a holding's
## piece, a craft station) stands flat: its middle and its four reaches all on
## dry, standable ground of one level, the spot's own, within a body's one step
## of `from_level` underfoot. The spot's level and not the player's: on terraced
## ground the tile the player stands on is often the only one of its level for a
## stride round, and asking for that level refused every spot near the bonelands'
## place (0 of 169 tiles within six, against 30 flat a step off).
func flat_footing(spot: Vector2, r: float, from_level: int) -> bool:
	var level := world.level_at(floori(spot.x), floori(spot.y))
	if absi(level - from_level) > 1:
		return false
	for c: Vector2 in [spot, spot + Vector2(r, 0), spot - Vector2(r, 0), spot + Vector2(0, r), spot - Vector2(0, r)]:
		var tx := floori(c.x)
		var ty := floori(c.y)
		if not standable(tx, ty) or Ground.is_water(world.ground_at(tx, ty)) or world.level_at(tx, ty) != level:
			return false
	return true


## Whether a body of radius `r` stands WHOLE at `p`, by its own move's rules: the
## middle and every corner on ground it can be on, each a step (on's) from the
## middle's tile with `tall` levels of room over it. A body put down where this
## is false can be frozen: with one corner on the terrace above, every move that
## leaves that corner in its tile is refused (`_fits`), and a step a frame never
## leaves it. Props are not asked: the move always lets a body out of one it
## overlaps, and a save made standing against a built fire must load as it was.
func body_fits(p: Vector2, r: float, on: CraftRide = null, swims: bool = false, tall: int = 0) -> bool:
	var ftx := floori(p.x)
	var fty := floori(p.y)
	for c: Vector2 in [p, p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(-r, r), p + Vector2(r, r)]:
		if not passable(ftx, fty, floori(c.x), floori(c.y), on, swims, tall):
			return false
	return true


## Where a body of radius `r` is put when something puts it at `p` (a start, a
## load, a door, a respawn, a warp, a tour): `p` itself if it stands whole there
## (`body_fits`), else the nearest spot within `reach` tiles that does, else `p`
## as asked. The one door every placement goes through, so no path can leave a
## body where its own move will not take it out again.
func stand_at(p: Vector2, r: float, on: CraftRide = null, swims: bool = false, tall: int = 0, reach: float = 6.0) -> Vector2:
	if body_fits(p, r, on, swims, tall):
		return p
	# Rings a quarter tile apart, sixteen ways round each: the nearest first.
	var ring := 0.25
	while ring <= reach:
		var n := maxi(16, int(ring * 16.0))
		for i in n:
			var q := p + Vector2.from_angle(TAU * float(i) / float(n)) * ring
			if body_fits(q, r, on, swims, tall):
				return q
		ring += 0.25
	return p


## A body leaning into a trunk or boulder slides round it at least this share of its pace.
const SLIDE_MIN := 0.5


## Move a circle of radius r from p by delta, sliding round solid props and along
## walls. Returns the new position. Pushed into a circle the move is turned along
## its edge; testing x and y apart alone left a diagonal push dead against a
## trunk (both axes refused), so the player stuck instead of slipping past.
func move_body(p: Vector2, delta: Vector2, r: float, on: CraftRide = null, swims: bool = false, tall: int = 0) -> Vector2:
	if delta.length_squared() < 1e-12:
		return p
	var full := p + delta
	if _fits(p, full, r, on, swims, tall):
		return full
	var hit := _blocker(p, full, r)
	if hit.is_finite():
		var n := p - Vector2(hit.x, hit.y)
		n = n / n.length() if n.length_squared() > 1e-10 else -delta.normalized()
		var t := delta - n * delta.dot(n)
		if t.length_squared() > delta.length_squared() * 1e-4:
			var slide := t.normalized() * maxf(t.length(), delta.length() * SLIDE_MIN)
			if _fits(p, p + slide, r, on, swims, tall):
				return p + slide
	var nx := Vector2(p.x + delta.x, p.y)
	if not _fits(p, nx, r, on, swims, tall):
		nx = p
	var ny := Vector2(nx.x, nx.y + delta.y)
	if not _fits(nx, ny, r, on, swims, tall):
		ny = nx
	return ny


## The nearest thing a move from `from` to `to` pushes into, as its centre, or
## Vector2.INF. A solid prop or one of `set_blocks`' walls: the slide is the same
## either way, so the caller is told where the middle of it is and nothing else.
func _blocker(from: Vector2, to: Vector2, r: float) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	var t := world.table
	for row in rows_near(to, solid_reach(r)):
		var solid := t.solid[row]
		if solid <= 0.0 or world.depleted.has(t.id[row]):
			continue
		var at := t.pos[row]
		var rr := solid + r
		var after := at.distance_squared_to(to)
		if after < rr * rr and after < at.distance_squared_to(from) and after < best_d:
			best_d = after
			best = at
	for q in ghosts_near(to, solid_reach(r)):
		if q.solid <= 0.0:
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


func _fits(from: Vector2, to: Vector2, r: float, on: CraftRide = null, swims: bool = false, tall: int = 0) -> bool:
	var ftx := floori(from.x)
	var fty := floori(from.y)
	for o: Vector2 in [Vector2.ZERO, Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		var c := to + o
		var was := from + o
		# Ground this corner already hangs over it may go on hanging over, as a
		# body may always leave a prop it overlaps: judged from the tile the
		# middle is on now, a corner it came in with from the step above could be
		# two levels off, and every step short of clearing it in one was refused
		# (a body trapped for good; tests/core/test_movement.gd, the stair corner).
		if o != Vector2.ZERO and floori(c.x) == floori(was.x) and floori(c.y) == floori(was.y):
			continue
		if not passable(ftx, fty, floori(c.x), floori(c.y), on, swims, tall):
			return false
	var t := world.table
	for row in rows_near(to, solid_reach(r)):
		var solid := t.solid[row]
		if solid <= 0.0 or world.depleted.has(t.id[row]):
			continue
		var at := t.pos[row]
		var rr := solid + r
		var after := at.distance_squared_to(to)
		# Only block when it would bring us closer: bodies can always leave an overlap.
		if after < rr * rr and after < at.distance_squared_to(from):
			return false
	for q in ghosts_near(to, solid_reach(r)):
		if q.solid <= 0.0:
			continue
		var rr := q.solid + r
		var after := q.pos.distance_squared_to(to)
		if after < rr * rr and after < q.pos.distance_squared_to(from):
			return false
	for c: Vector3 in blocks_at(to):
		var at := Vector2(c.x, c.y)
		var rr := c.z + r
		var after := at.distance_squared_to(to)
		if after < rr * rr and after < at.distance_squared_to(from):
			return false
	return true
