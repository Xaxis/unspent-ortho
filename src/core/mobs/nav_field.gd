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


func _init(w: WorldData, q: WorldQuery) -> void:
	world = w
	query = q
	_dist.resize(_side * _side)
	_level.resize(_side * _side)


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
					if there == NOT_GROUND or absi(there - here) > 1:
						continue
					if diagonal:
						# Both corners must be ground a body can pass through on the way.
						var a := _level[ly * side + nlx]
						var b := _level[nly * side + lx]
						if a == NOT_GROUND or b == NOT_GROUND or absi(a - here) > 1 or absi(a - there) > 1 \
								or absi(b - here) > 1 or absi(b - there) > 1:
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


## The direction to walk from `p` to take the next step down the field
## (Vector2.ZERO when there is none to take).
func direction(p: Vector2) -> Vector2:
	var tx := floori(p.x)
	var ty := floori(p.y)
	var here := steps(tx, ty)
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
