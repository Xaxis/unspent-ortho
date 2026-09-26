class_name Senses
## How a machine or creature notices the player (design-extract §7.4).
##   sight   = sees x (1 - 0.8 x nightfall x 0.62), undone by a lit lamp,
##             x weather, x records (each filing +25%, four at most), with a clear line
##   hearing = hears x (1 + 0.35 x laden tier), and a MACHINE's x (1 + 0.6 x
##             nightfall), x the weather's noise (Weather.HEARING_CUT: rain,
##             storm, blizzard and blown dust cover your steps); not how fast
##             you go (running is the way to get away)
## You hear it before you see it; it hears you whatever the dark, and a machine
## hears you further in it (mechanics improvement 4b: sight falls at night, so
## by day the lamp and the open were what gave you away, and by night it is
## your steps; a crouch and soft ground are the night's answer).

## The source's darkest night is 0.62 of full dark.
const DARKEST := 0.62
const NIGHT_SIGHT := 0.8
const FILED_SIGHT := 0.25
const FILED_CAP := 4
const LADEN_HEARING := 0.35
## How much further a machine hears at full night (FightRules.nightfall 1).
const NIGHT_HEARING := 0.6
## A tile at least this many levels above both ends of a line hides one from the other.
const RIDGE_LEVELS := 2
## Props at least this wide (solid radius) block a line: houses, boulders, heaps. Trees do not.
const BLOCKING_SOLID := 0.42
## A wall (`WorldQuery.set_blocks`: a room's walls, a hall's racks, a hatch's
## housing, a colossus's pad) at least this wide blocks a line too. Only the
## ground and props were asked, so in every room a machine saw straight through
## its walls: a warden looked through a bay's wall at whoever hid in it.
const BLOCKING_WALL := 0.25


static func sight_range(row: Dictionary, m: Moment) -> float:
	var sees: float = row.get("sees", 0)
	if sees <= 0.0:
		return 0.0
	var dark := 0.0 if m.lamp_lit else m.nightfall() * DARKEST
	var records := 1.0 + FILED_SIGHT * mini(m.filed, FILED_CAP)
	return sees * (1.0 - NIGHT_SIGHT * dark) * m.weather_sight() * records


static func hearing_range(row: Dictionary, m: Moment) -> float:
	if row.get("sight_only", false):
		return 0.0
	var hears: float = row.get("hears", 0)
	var night := NIGHT_HEARING * m.nightfall() if row.get("machine", false) else 0.0
	return hears * (1.0 + LADEN_HEARING * m.laden_tier) * (1.0 + night) * m.weather_hearing()


## Distances are Chebyshev on the grid, as the source measured them.
static func chebyshev(a: Vector2, b: Vector2) -> float:
	return maxf(absf(a.x - b.x), absf(a.y - b.y))


## Noticing goes through StealthQuery, which adds what the player does about it
## (crouch, cover, the lamp, a spoofed signature, and the body's own cone when
## a `facing` is given). The ranges above are still the source's, and what the
## player cannot change.
static func sees(row: Dictionary, from: Vector2, target: Vector2, m: Moment, world: WorldData, query: WorldQuery, facing: float = NAN) -> bool:
	return StealthQuery.sees(row, from, target, m, world, query, facing)


static func hears(row: Dictionary, from: Vector2, target: Vector2, m: Moment) -> bool:
	return StealthQuery.hears(row, from, target, m)


static func notices(row: Dictionary, from: Vector2, target: Vector2, m: Moment, world: WorldData, query: WorldQuery, facing: float = NAN) -> bool:
	return StealthQuery.notices(row, from, target, m, world, query, facing)


## A clear line between two points: walks every tile the segment touches. A
## corner passed exactly blocks only if both tiles beside it are solid.
##
## `over` holds the ids of props the looker stands above and sees past (a
## turret over its own holding's walls, 47_defences); empty for everybody else.
static func line_clear(world: WorldData, query: WorldQuery, a: Vector2, b: Vector2, over: Dictionary = {}) -> bool:
	if world == null:
		return true
	var ax := floori(a.x)
	var ay := floori(a.y)
	var bx := floori(b.x)
	var by := floori(b.y)
	var eye := maxi(world.level_at(ax, ay), world.level_at(bx, by))
	var d := b - a
	var x := ax
	var y := ay
	var sx := 1 if d.x > 0.0 else -1
	var sy := 1 if d.y > 0.0 else -1
	var tdx := absf(1.0 / d.x) if absf(d.x) > 1e-9 else INF
	var tdy := absf(1.0 / d.y) if absf(d.y) > 1e-9 else INF
	var tmx := ((x + 1 - a.x) if sx > 0 else (a.x - x)) * tdx if tdx < INF else INF
	var tmy := ((y + 1 - a.y) if sy > 0 else (a.y - y)) * tdy if tdy < INF else INF
	var guard := 0
	while (x != bx or y != by) and guard < 256:
		guard += 1
		if absf(tmx - tmy) < 1e-6:
			var side_a := _solid(world, query, x + sx, y, eye, over)
			var side_b := _solid(world, query, x, y + sy, eye, over)
			if side_a and side_b:
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
		if (x != bx or y != by) and _solid(world, query, x, y, eye, over):
			return false
	return not _walled(query, a, b)


## Whether a wall stands across the line from `a` to `b`: a block circle the line
## passes through, other than one either end stands in.
static func _walled(query: WorldQuery, a: Vector2, b: Vector2) -> bool:
	if query == null:
		return false
	var n := ceili(a.distance_to(b) / 0.25)
	for i in range(1, n):
		var q := a.lerp(b, float(i) / float(n))
		for c: Vector3 in query.blocks_at(q):
			if c.z < BLOCKING_WALL:
				continue
			var at := Vector2(c.x, c.y)
			if q.distance_to(at) > c.z or a.distance_to(at) <= c.z or b.distance_to(at) <= c.z:
				continue
			return true
	return false


static func _solid(world: WorldData, query: WorldQuery, x: int, y: int, eye: int, over: Dictionary = {}) -> bool:
	if world.level_at(x, y) >= eye + RIDGE_LEVELS:
		return true
	if query == null:
		return false
	for p in query.props_near(Vector2(x + 0.5, y + 0.5), 0.0):
		if p.solid >= BLOCKING_SOLID and not world.depleted.has(p.id) and not over.has(p.id):
			return true
	return false
