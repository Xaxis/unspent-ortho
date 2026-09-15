class_name Senses
## How a machine or creature notices the player (design-extract §7.4).
##   sight   = sees x (1 - 0.8 x nightfall x 0.62), undone by a lit lamp,
##             x weather, x records (each filing +20%), with a clear line
##   hearing = hears x (1 + 0.35 x laden tier) x (1.35 running): never night, never weather
## You hear it before you see it; it hears you whatever the dark.

## The source's darkest night is 0.62 of full dark.
const DARKEST := 0.62
const NIGHT_SIGHT := 0.8
const FILED_SIGHT := 0.2
const FILED_CAP := 5
const LADEN_HEARING := 0.35
const RUN_HEARING := 1.35
## A tile at least this many levels above both ends of a line hides one from the other.
const RIDGE_LEVELS := 2
## Props at least this wide (solid radius) block a line: houses, boulders, heaps. Trees do not.
const BLOCKING_SOLID := 0.42


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
	return hears * (1.0 + LADEN_HEARING * m.laden_tier) * (RUN_HEARING if m.running else 1.0)


## Distances are Chebyshev on the grid, as the source measured them.
static func chebyshev(a: Vector2, b: Vector2) -> float:
	return maxf(absf(a.x - b.x), absf(a.y - b.y))


static func sees(row: Dictionary, from: Vector2, target: Vector2, m: Moment, world: WorldData, query: WorldQuery) -> bool:
	var r := sight_range(row, m)
	return r > 0.0 and chebyshev(from, target) <= r and line_clear(world, query, from, target)


static func hears(row: Dictionary, from: Vector2, target: Vector2, m: Moment) -> bool:
	var r := hearing_range(row, m)
	return r > 0.0 and chebyshev(from, target) <= r


static func notices(row: Dictionary, from: Vector2, target: Vector2, m: Moment, world: WorldData, query: WorldQuery) -> bool:
	return hears(row, from, target, m) or sees(row, from, target, m, world, query)


## A clear line between two points: walks every tile the segment touches. A
## corner passed exactly blocks only if both tiles beside it are solid.
static func line_clear(world: WorldData, query: WorldQuery, a: Vector2, b: Vector2) -> bool:
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
			var side_a := _solid(world, query, x + sx, y, eye)
			var side_b := _solid(world, query, x, y + sy, eye)
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
		if (x != bx or y != by) and _solid(world, query, x, y, eye):
			return false
	return true


static func _solid(world: WorldData, query: WorldQuery, x: int, y: int, eye: int) -> bool:
	if world.level_at(x, y) >= eye + RIDGE_LEVELS:
		return true
	if query == null:
		return false
	for p in query.props_near(Vector2(x + 0.5, y + 0.5), 0.0):
		if p.solid >= BLOCKING_SOLID and not world.depleted.has(p.id):
			return true
	return false
