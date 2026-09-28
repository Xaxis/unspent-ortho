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


func _init(w: WorldData, q: WorldQuery) -> void:
	world = w
	query = q
	_dist.resize(_side * _side)
	_level.resize(_side * _side)


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


## Make sure the field leads to `target`. Cheap when the target has not left its tile.
func update(target: Vector2) -> void:
	var c := Vector2i(floori(target.x), floori(target.y))
	if c == centre:
		return
	centre = c
	builds += 1
	_dist.fill(FAR)
	var size := world.size
	var ox := c.x - RADIUS
	var oy := c.y - RADIUS
	for ly in _side:
		var y := oy + ly
		for lx in _side:
			var x := ox + lx
			var l := NOT_GROUND
			if x >= 0 and y >= 0 and x < size and y < size:
				var i := y * size + x
				if world.ground[i] != Ground.DEEP_WATER:
					l = world.level[i]
			# A body's own limits (`for_body`). The target's tile and its neighbours
			# are left: a player stands beside a tree, and a field is laid to them.
			var near_target := absi(lx - RADIUS) <= 1 and absi(ly - RADIUS) <= 1
			if l != NOT_GROUND and not near_target:
				if tall > 0 and world.headroom_at(x, y) < tall:
					l = NOT_GROUND
				elif prop_radius > 0.0 and query != null and prop_stands_in(query, Vector2(x + 0.5, y + 0.5), prop_radius, breaks):
					l = NOT_GROUND
			_level[ly * _side + lx] = l
	var start := RADIUS * _side + RADIUS
	if _level[start] == NOT_GROUND:
		return
	# Dial's buckets: costs are small integers, so the frontier is a list per cost.
	var buckets: Array[PackedInt32Array] = [PackedInt32Array([start])]
	_dist[start] = 0
	var k := 0
	var side := _side
	while k < buckets.size():
		var i := 0
		while i < buckets[k].size():
			var cell := buckets[k][i]
			i += 1
			if _dist[cell] != k:
				continue
			var lx := cell % side
			var ly := cell / side
			var here := _level[cell]
			for dy: int in [-1, 0, 1]:
				var nly := ly + dy
				if nly < 0 or nly >= side:
					continue
				for dx: int in [-1, 0, 1]:
					var nlx := lx + dx
					if (dx == 0 and dy == 0) or nlx < 0 or nlx >= side:
						continue
					var ni := nly * side + nlx
					var diagonal := dx != 0 and dy != 0
					var nd := k + (DIAGONAL if diagonal else STRAIGHT)
					if _dist[ni] <= nd:
						continue
					var there := _level[ni]
					if there == NOT_GROUND or absi(there - here) > step:
						continue
					if diagonal:
						# Both corners must be ground a body can pass through on the way.
						var a := _level[ly * side + nlx]
						var b := _level[nly * side + lx]
						if a == NOT_GROUND or b == NOT_GROUND or absi(a - here) > step or absi(a - there) > step \
								or absi(b - here) > step or absi(b - there) > step:
							continue
					_dist[ni] = nd
					while buckets.size() <= nd:
						buckets.append(PackedInt32Array())
					buckets[nd].append(ni)
		k += 1


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
	for row in q.rows_near(p, 2.0 + radius):
		var solid := t.solid[row]
		if solid <= 0.0 or q.world.depleted.has(t.id[row]) or through.has(t.kind[row]):
			continue
		var rr := solid + radius
		if t.pos[row].distance_squared_to(p) < rr * rr:
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
