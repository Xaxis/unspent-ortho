class_name NavField
extends RefCounted
## The way to the player over the ground, out to RADIUS tiles (design-extract
## §7.4: a distance field of radius 24). A chaser whose straight line meets a
## cliff follows the field round it instead. Built from the tile the player
## stands on, only when a body actually needs it and the player has changed
## tile since; open ground never builds it at all.
##
## Costs are STRAIGHT per step along an axis and DIAGONAL per diagonal, so the
## short way round is the one taken; a diagonal needs both of its sides open,
## so nothing squeezes between two cliff corners.

const RADIUS := 24
const FAR := 1 << 20
const STRAIGHT := 2
const DIAGONAL := 3
## A cell that is not ground (deep water, off the world).
const NOT_GROUND := -1000000
## The eight steps out of a cell and what each costs.
const STEP_X: PackedInt32Array = [-1, 0, 1, -1, 1, -1, 0, 1]
const STEP_Y: PackedInt32Array = [-1, -1, -1, 0, 0, 1, 1, 1]
const STEP_COST: PackedInt32Array = [DIAGONAL, STRAIGHT, DIAGONAL, STRAIGHT, STRAIGHT, DIAGONAL, STRAIGHT, DIAGONAL]

var world: WorldData
var query: WorldQuery
var centre := Vector2i(-100000, -100000)
## Rebuilds so far (tests read it to know the field is cached).
var builds := 0
var _side := RADIUS * 2 + 1
var _dist := PackedInt32Array()
var _level := PackedInt32Array()
## A FIELD LAID FOR ONE BODY (`for_body`), by the rules its own move is held to
## (FightSim moves every body as WorldQuery.move_body does): the levels it can
## step, the headroom it needs, and the solid props that stop it at its move
## radius -- all but the kinds it BREAKS (Roster `breaks`), which it goes through.
## The player's field has none of these set: a step of one, no headroom, and
## props left to the body's own slide, as it always has. A keeper followed the
## player's field onto a way its own move would not take and stopped there.
var step := 1
var tall := 0
var prop_radius := 0.0
var breaks: Array = []

## Building, in order: idle (nothing in hand), the ground, the solids, Dial's.
enum { IDLE, FILL, STAMP, DIAL }
var _doing := IDLE
var _p_centre := Vector2i(-100000, -100000)
var _p_level := PackedInt32Array()
var _p_dist := PackedInt32Array()
var _p_cell := 0
var _p_buckets: Array[PackedInt32Array] = []
var _p_k := 0
var _p_i := 0


func _init(w: WorldData, q: WorldQuery) -> void:
	world = w
	query = q
	_dist.resize(_side * _side)
	_level.resize(_side * _side)
	_p_dist.resize(_side * _side)
	_p_level.resize(_side * _side)


## A field for the body whose roster row is `row` and whose move radius is `r`.
static func for_body(w: WorldData, q: WorldQuery, row: Dictionary, r: float) -> NavField:
	var f := NavField.new(w, q)
	f.step = maxi(1, int(row.get("climbs", 1)))
	f.tall = int(ceil(float(row.get("height", 1.0)) / WorldData.STEP))
	f.prop_radius = r
	f.breaks = breaks_of(row)
	return f


## The prop kinds a roster row breaks through, as PropKind ids (its `breaks`
## names; a machine's rule, and only what it declares).
static func breaks_of(row: Dictionary) -> Array:
	var out: Array = []
	for name: Variant in row.get("breaks", []):
		var k := PropKind.NAMES.find(str(name))
		if k >= 0:
			out.append(k)
	return out


## Make sure the field leads to `target`, now. Cheap when the target has not
## left its tile. A caller on the frame's clock asks `request` and lets
## `advance` lay it a slice at a time instead.
func update(target: Vector2) -> void:
	request(target)
	@warning_ignore("return_value_discarded")
	advance(1 << 30)


## A FIELD IS LAID A SLICE AT A TIME. Asked for a new tile, it starts a build
## beside the one it has, and keeps answering from the old one (`steps`,
## `direction`) until `advance` has laid every cell of the new one and swaps it
## in. A whole city field at once was 4-9 ms of one frame, and the player's and
## a pack's all came due on the frame the player crossed a tile. What a slice
## may do is counted in cells, not time, so a fixed-step fight lays its fields
## on the same slices every run. True when a build was started.
func request(target: Vector2) -> bool:
	var c := Vector2i(floori(target.x), floori(target.y))
	if (_doing == IDLE and c == centre) or (_doing != IDLE and c == _p_centre):
		return false
	_p_centre = c
	builds += 1
	_doing = FILL
	_p_cell = 0
	return true


## A build is in hand (`request`), not yet swapped in.
func pending() -> bool:
	return _doing != IDLE


## The tile this field leads to now, or will once its build is in.
func laid_to(tile: Vector2i) -> bool:
	return (_doing == IDLE and centre == tile) or (_doing != IDLE and _p_centre == tile)


## Lay up to `budget` cells of the build in hand; the cells it used. Filling a
## cell, stamping the solids (`_side` cells' worth, about what it costs) and
## settling a cell in Dial's are a cell each.
func advance(budget: int) -> int:
	var used := 0
	while _doing != IDLE and used < budget:
		match _doing:
			FILL:
				used += _fill(budget - used)
			STAMP:
				_stamp_solids()
				used += _side
				_start_dial()
			DIAL:
				used += _dial(budget - used)
	return used


## The ground of up to `n` cells, from `_p_cell` on: its level, or NOT_GROUND
## where a body of these rules cannot be. Locals, not members: a member read is
## a lookup each time.
func _fill(n: int) -> int:
	var size := world.size
	var grounds := world.ground
	var levels := world.level
	var side := _side
	var ox := _p_centre.x - RADIUS
	var oy := _p_centre.y - RADIUS
	var level := _p_level
	var cell := _p_cell
	var last := mini(side * side, cell + n)
	var done := last - cell
	while cell < last:
		var lx := cell % side
		var ly := cell / side
		var x := ox + lx
		var y := oy + ly
		var l := NOT_GROUND
		if x >= 0 and y >= 0 and x < size and y < size:
			var i := y * size + x
			if grounds[i] != Ground.DEEP_WATER:
				l = levels[i]
		# A body's own limits (`for_body`). The target's tile and its neighbours
		# are left: a player stands beside a tree, and a field is laid to them.
		if l != NOT_GROUND and tall > 0 and (absi(lx - RADIUS) > 1 or absi(ly - RADIUS) > 1) and world.headroom_at(x, y) < tall:
			l = NOT_GROUND
		level[cell] = l
		cell += 1
	_p_level = level
	_p_cell = cell
	if cell >= side * side:
		_doing = STAMP if prop_radius > 0.0 and query != null else DIAL
		if _doing == DIAL:
			_start_dial()
	return done


func _stamp_solids() -> void:
	var ox := _p_centre.x - RADIUS
	var oy := _p_centre.y - RADIUS
	var lo := Vector2(ox, oy)
	var hi := Vector2(ox + _side, oy + _side)
	_stamp(query.ordinary_rows_in(lo, hi, prop_radius), ox, oy)
	_stamp(query.wide_rows_in(lo, hi, prop_radius), ox, oy)
	_stamp_walls(query.wall_rows_in(lo, hi, prop_radius + WorldQuery.BLOCK_SLACK), ox, oy)


func _start_dial() -> void:
	_doing = DIAL
	_p_dist.fill(FAR)
	var start := RADIUS * _side + RADIUS
	_p_buckets.clear()
	_p_k = 0
	_p_i = 0
	if _p_level[start] == NOT_GROUND:
		_swap()
		return
	_p_dist[start] = 0
	_p_buckets.append(PackedInt32Array([start]))


## Dial's buckets (costs are small integers, so the frontier is a list per cost),
## settling up to `n` cells and resuming where the last slice stopped.
func _dial(n: int) -> int:
	var side := _side
	var level := _p_level
	var dist := _p_dist
	var buckets := _p_buckets
	var k := _p_k
	var i := _p_i
	var done := 0
	while k < buckets.size() and done < n:
		var bucket := buckets[k]
		while i < bucket.size() and done < n:
			var cell := bucket[i]
			i += 1
			done += 1
			if dist[cell] != k:
				continue
			var lx := cell % side
			var ly := cell / side
			var here := level[cell]
			for d in 8:
				var nlx := lx + STEP_X[d]
				var nly := ly + STEP_Y[d]
				if nlx < 0 or nly < 0 or nlx >= side or nly >= side:
					continue
				var ni := nly * side + nlx
				var nd := k + STEP_COST[d]
				if dist[ni] <= nd:
					continue
				var there := level[ni]
				if there == NOT_GROUND or absi(there - here) > step:
					continue
				if STEP_COST[d] == DIAGONAL:
					# Both corners must be ground a body can pass through on the way.
					var a := level[ly * side + nlx]
					var b := level[nly * side + lx]
					if a == NOT_GROUND or b == NOT_GROUND or absi(a - here) > step or absi(a - there) > step \
							or absi(b - here) > step or absi(b - there) > step:
						continue
				dist[ni] = nd
				while buckets.size() <= nd:
					buckets.append(PackedInt32Array())
				buckets[nd].append(ni)
		if i >= bucket.size():
			k += 1
			i = 0
	_p_dist = dist
	_p_k = k
	_p_i = i
	if k >= buckets.size():
		_swap()
	return done


## The build in hand becomes the field; the old arrays take the next build.
func _swap() -> void:
	var level := _level
	var dist := _dist
	_level = _p_level
	_dist = _p_dist
	_p_level = level
	_p_dist = dist
	centre = _p_centre
	_doing = IDLE


## THE SOLIDS A BODY CANNOT STAND IN, STAMPED ONCE PER REBUILD by their own
## footprint: each shuts every cell whose centre lies within its solid plus the
## body's radius, the answer `prop_stands_in` gives cell by cell. Asked cell by
## cell, 2,401 searches of the tiles round each, a city field took 17-21 ms of
## the main thread whenever a routing machine's target crossed a tile (the p99
## of a 20-machine chase); one search of the field's square per tier is the
## same answer. The target's tile and its neighbours stay open, as `update`
## leaves them.
func _stamp(rows: PackedInt32Array, ox: int, oy: int) -> void:
	var t := world.table
	for row in rows:
		var solid := t.solid[row]
		if solid <= 0.0 or world.depleted.has(t.id[row]) or breaks.has(t.kind[row]):
			continue
		var at: Vector2 = t.pos[row]
		var rr := solid + prop_radius
		for ly in range(maxi(0, floori(at.y - rr - 0.5) - oy), mini(_side - 1, ceili(at.y + rr - 0.5) - oy) + 1):
			for lx in range(maxi(0, floori(at.x - rr - 0.5) - ox), mini(_side - 1, ceili(at.x + rr - 0.5) - ox) + 1):
				if absi(lx - RADIUS) <= 1 and absi(ly - RADIUS) <= 1:
					continue
				if Vector2(ox + lx + 0.5, oy + ly + 0.5).distance_squared_to(at) < rr * rr:
					_p_level[ly * _side + lx] = NOT_GROUND


## A walled prop's walls (PropWalls) shut cells as its solid would: what stops a
## body moving (WorldQuery._fits) is what the field routes round. Each prop's
## shut tiles are the query's, worked out once per body size (wall_tiles), so a
## rebuild only lays them.
func _stamp_walls(rows: PackedInt32Array, ox: int, oy: int) -> void:
	var n := world.size
	for row in rows:
		for k in query.wall_tiles(row, prop_radius):
			var lx := k % n - ox
			var ly := k / n - oy
			if lx < 0 or ly < 0 or lx >= _side or ly >= _side or (absi(lx - RADIUS) <= 1 and absi(ly - RADIUS) <= 1):
				continue
			_p_level[ly * _side + lx] = NOT_GROUND


## Cost from this tile to the player's; FAR when there is no way within the radius.
func steps(tx: int, ty: int) -> int:
	var lx := tx - centre.x + RADIUS
	var ly := ty - centre.y + RADIUS
	if lx < 0 or ly < 0 or lx >= _side or ly >= _side:
		return FAR
	return _dist[ly * _side + lx]


## True when the ground's way from `p` is longer than the straight line
## (the field must be up to date for the player's tile).
func detour_needed(p: Vector2) -> bool:
	var tx := floori(p.x)
	var ty := floori(p.y)
	var s := steps(tx, ty)
	if s >= FAR:
		return false
	var ax := absi(tx - centre.x)
	var ay := absi(ty - centre.y)
	# On open ground the field is exactly the straight distance; any more is a way round.
	return s > STRAIGHT * maxi(ax, ay) + (DIAGONAL - STRAIGHT) * mini(ax, ay)


## A body's steps from where it stands: its own tile's, else the best of the
## tiles beside it, because its middle can sit on a tile its field closes (beside
## a prop at its station) while it can still step off it.
func steps_from(p: Vector2) -> int:
	var tx := floori(p.x)
	var ty := floori(p.y)
	var best := steps(tx, ty)
	if prop_radius <= 0.0 or best < FAR:
		return best
	var r := 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			best = mini(best, steps(tx + dx, ty + dy) + STRAIGHT * maxi(absi(dx), absi(dy)))
	return best


## The direction to walk from `p` to take the next step down the field
## (Vector2.ZERO when there is none to take). A body on a tile its own field
## closes steps toward the best open tile beside it first (`steps_from`).
func direction(p: Vector2) -> Vector2:
	var tx := floori(p.x)
	var ty := floori(p.y)
	var here := steps(tx, ty)
	if here >= FAR and prop_radius > 0.0:
		var r := 1
		var to := Vector2.ZERO
		var near := FAR
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var s := steps(tx + dx, ty + dy)
				if s < FAR:
					var cost := s + STRAIGHT * maxi(absi(dx), absi(dy))
					if cost < near:
						near = cost
						to = Vector2(tx + dx + 0.5, ty + dy + 0.5) - p
		return to.normalized() if to.length_squared() > 1e-6 else Vector2.ZERO
	if here >= FAR or here == 0:
		return Vector2.ZERO
	var best := here
	var best_dir := Vector2.ZERO
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var s := steps(tx + dx, ty + dy)
			if s < best:
				best = s
				best_dir = Vector2(tx + dx + 0.5, ty + dy + 0.5) - p
	return best_dir.normalized() if best_dir.length_squared() > 1e-6 else Vector2.ZERO


## Whether a solid prop stands where a body of `radius` at `p` would be (its
## move's test, WorldQuery._fits), leaving the kinds in `through`.
static func prop_stands_in(q: WorldQuery, p: Vector2, radius: float, through: Array = []) -> bool:
	var t := q.world.table
	for row in q.solid_rows_near(p, radius):
		var solid := t.solid[row]
		if solid <= 0.0 or q.world.depleted.has(t.id[row]) or through.has(t.kind[row]):
			continue
		var rr := solid + radius
		if t.pos[row].distance_squared_to(p) < rr * rr:
			return true
	for c: Vector3 in q.walls_at(p):
		var rr := c.z + radius
		if Vector2(c.x, c.y).distance_squared_to(p) < rr * rr:
			return true
	return false


## Whether the straight line from a to b is clear of solid props for a body of
## `radius`, sampled every half tile, leaving the kinds in `through`.
static func props_clear(q: WorldQuery, a: Vector2, b: Vector2, radius: float, through: Array = []) -> bool:
	var d := a.distance_to(b)
	var steps := maxi(1, ceili(d / 0.5))
	for i in range(1, steps + 1):
		if prop_stands_in(q, a.lerp(b, float(i) / float(steps)), radius, through):
			return false
	return true


## Can a body of `radius` walk the straight line from a to b? Along the middle
## and both flanks, every tile the line touches must be ground, each a step of
## at most one level from the last. Cheap: this is what keeps the field from
## being built on open ground.
static func line_walkable(w: WorldData, a: Vector2, b: Vector2, radius: float = 0.0) -> bool:
	if not _line(w, a, b):
		return false
	if radius <= 0.0 or a.distance_squared_to(b) < 1e-6:
		return true
	var side := (b - a).normalized().orthogonal() * radius
	return _line(w, a + side, b + side) and _line(w, a - side, b - side)


static func _line(w: WorldData, a: Vector2, b: Vector2) -> bool:
	var x := floori(a.x)
	var y := floori(a.y)
	var bx := floori(b.x)
	var by := floori(b.y)
	if not _ground(w, x, y):
		return false
	var d := b - a
	var sx := 1 if d.x > 0.0 else -1
	var sy := 1 if d.y > 0.0 else -1
	var tdx := absf(1.0 / d.x) if absf(d.x) > 1e-9 else INF
	var tdy := absf(1.0 / d.y) if absf(d.y) > 1e-9 else INF
	var tmx := (((x + 1) - a.x) if sx > 0 else (a.x - x)) * tdx if tdx < INF else INF
	var tmy := (((y + 1) - a.y) if sy > 0 else (a.y - y)) * tdy if tdy < INF else INF
	var last := w.level_at(x, y)
	var guard := 0
	while (x != bx or y != by) and guard < 128:
		guard += 1
		if absf(tmx - tmy) < 1e-6:
			# Through a corner exactly: both tiles beside it must pass too.
			if not _ground(w, x + sx, y) or not _ground(w, x, y + sy) \
					or absi(w.level_at(x + sx, y) - last) > 1 or absi(w.level_at(x, y + sy) - last) > 1:
				return false
			x += sx
			y += sy
			tmx += tdx
			tmy += tdy
		elif tmx < tmy:
			x += sx
			tmx += tdx
		else:
			y += sy
			tmy += tdy
		if not _ground(w, x, y):
			return false
		var l := w.level_at(x, y)
		if absi(l - last) > 1:
			return false
		last = l
	return true


static func _ground(w: WorldData, x: int, y: int) -> bool:
	return w.in_bounds(x, y) and w.ground_at(x, y) != Ground.DEEP_WATER
