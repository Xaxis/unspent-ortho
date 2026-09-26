class_name Climb
## Climbing (mechanics improvement 5a): up a rock face too tall to jump, on the
## jump key, a level at a time, on breath. Pure, like `Jump.plan`: the whole climb
## is planned at the press against the breath there is, and replayed by
## `AbilityMotion.climb`, so what is drawn and what a test measured are the same.
##
##   Climb.face(world, query, from, dir, reach) -> Dictionary
##       the rock face ahead within `reach` tiles: {foot, top, from_level,
##       to_level, from_height, top_height}, or {} when there is none
##   Climb.plan(world, query, from, dir, wind) -> Climb.Plan or null
##
## The rules (docs, mechanics DESIGN §5):
##   - only ROCK faces: the upper tile's ground is rock or limestone. Turf, sand,
##     scree and snow give nothing to hold, and a player reads which is which by
##     the ground itself and by the route marked up a face they face (54_gear).
##   - a face is at least FightRules.LEDGE_LEVELS tall (anything less is a step
##     or a jump), and the top is the shelf at the head of it
##   - WIND_PER_LEVEL breath a level, RATE levels a second, and nothing may be
##     swung on the face (the hero is `airborne` while it lasts)
##   - short of breath, it climbs what it can, the arms give out, and the body
##     comes back down the face to where it started, taking 1 health per 3 levels
##     fallen past Jump.DOWN_LEVELS: the first fall damage in the game
##   - while on the face the body is at the level it has climbed to
##     (FightSim.hero_level), so a machine below reaches it only while it is
##     within a ledge of the ground, as every blow already works (1a)
##
## ASSUMES THE HEIGHTFIELD. A face is the step between two tiles' levels and the
## top is the tile past it, one level per tile, nothing overhead. Ground above
## ground -- an overhang, a cave roof, a bridge of rock (the design for geometry
## above the heightfield) -- is invisible to this: a face under an overhang would
## be climbed straight through the roof, and a roof's underside is no face at
## all. When that lands, `face` must ask for the first solid above the foot and
## stop there, and the top must be a surface that geometry declares, not
## `level_at` of the next tile.

## Grounds a face may be climbed on: the upper tile's, since the wall is its side.
const GROUNDS: Array[int] = [Ground.ROCK, Ground.LIMESTONE]
## Breath a level: a long face is not climbed from a standing start after a fight.
const WIND_PER_LEVEL := 180.0
## Levels a second up the face.
const RATE := 1.2
## Seconds to get over the lip onto the top, and to come back down a face when
## the arms give out.
const LIP_SECONDS := 0.3
const SLIDE_SECONDS := 0.5
## How far ahead, tiles, a face is looked for from where the body stands.
const REACH := 0.9
## The step along the heading the face is looked for in.
const PROBE := 0.05


class Plan:
	extends RefCounted
	var from := Vector2.ZERO
	var top := Vector2.ZERO
	var dir := Vector2.ZERO
	var from_level := 0
	var to_level := 0
	var from_height := 0.0
	var top_height := 0.0
	## Levels the face is, and levels the breath there was gets the body up.
	var levels := 0
	var reached := 0
	## The arms gave out before the top: the body comes back down to `from`.
	var slides := false
	var wind := 0.0
	var fall_damage := 0
	var seconds := 0.0

	func up_seconds() -> float:
		return float(reached) / Climb.RATE

	## [position, height in the world, level the body is at] `t` seconds in.
	func at(t: float) -> Array:
		var up := up_seconds()
		if t < up:
			var lv := t * Climb.RATE
			return [from, from_height + lv * WorldData.STEP, from_level + floori(lv)]
		var u := clampf((t - up) / (Climb.SLIDE_SECONDS if slides else Climb.LIP_SECONDS), 0.0, 1.0)
		var peak := from_height + float(reached) * WorldData.STEP
		if slides:
			# Down the face faster and faster, to where it started.
			return [from, lerpf(peak, from_height, u * u), from_level + floori(float(reached) * (1.0 - u * u))]
		return [from.lerp(top, u), lerpf(peak, top_height, u), to_level]


## Is this ground climbable?
static func holds(ground: int) -> bool:
	return GROUNDS.has(ground)


static func face(world: WorldData, query: WorldQuery, from: Vector2, dir: Vector2, reach: float = REACH) -> Dictionary:
	if world == null or dir.length() < 0.01:
		return {}
	var d := dir.normalized()
	var here := Vector2i(floori(from.x), floori(from.y))
	var from_level := world.level_at(here.x, here.y)
	var p := from
	var travelled := 0.0
	while travelled <= reach + Tuning.PLAYER_RADIUS:
		p += d * PROBE
		travelled += PROBE
		var t := Vector2i(floori(p.x), floori(p.y))
		if t == here:
			continue
		var lv := world.level_at(t.x, t.y)
		if lv - from_level < FightRules.LEDGE_LEVELS:
			return {}
		if not holds(world.ground_at(t.x, t.y)):
			return {}
		# Over the lip onto the shelf, clear of it by a body's width.
		var top := p + d * (Tuning.PLAYER_RADIUS + 0.2)
		var tt := Vector2i(floori(top.x), floori(top.y))
		if world.level_at(tt.x, tt.y) != lv or (query != null and not query.standable(tt.x, tt.y)):
			return {}
		return {"foot": from, "top": top, "from_level": from_level, "to_level": lv,
			"from_height": world.height_at(from), "top_height": world.height_at(top)}
	return {}


static func plan(world: WorldData, query: WorldQuery, from: Vector2, dir: Vector2, wind: float) -> Plan:
	var f := face(world, query, from, dir)
	if f.is_empty():
		return null
	var p := Plan.new()
	p.from = from
	p.top = f.top
	p.dir = dir.normalized()
	p.from_level = f.from_level
	p.to_level = f.to_level
	p.from_height = f.from_height
	p.top_height = f.top_height
	p.levels = p.to_level - p.from_level
	p.reached = mini(p.levels, floori(maxf(0.0, wind) / WIND_PER_LEVEL))
	p.slides = p.reached < p.levels
	p.wind = float(p.reached) * WIND_PER_LEVEL
	p.fall_damage = fall_damage(p.reached) if p.slides else 0
	p.seconds = p.up_seconds() + (SLIDE_SECONDS if p.slides else LIP_SECONDS)
	return p


## The nearest place to stand at the foot of a rock face at least `min_levels`
## tall, and the way to face it: {at, dir, plan} or {}. For tours and tests,
## which name a face and never a coordinate (`ledge climb`).
static func find(world: WorldData, query: WorldQuery, near: Vector2, reach: float = 60.0, min_levels: int = Jump.UP_LEVELS + 1) -> Dictionary:
	if world == null:
		return {}
	var cx := floori(near.x)
	var cy := floori(near.y)
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for r in range(0, int(reach) + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var tx := cx + dx
				var ty := cy + dy
				if not world.in_bounds(tx, ty) or (query != null and not query.standable(tx, ty)) or Ground.is_water(world.ground_at(tx, ty)):
					continue
				var here := world.level_at(tx, ty)
				for d in dirs:
					var nx := tx + int(d.x)
					var ny := ty + int(d.y)
					if not world.in_bounds(nx, ny) or world.level_at(nx, ny) - here < min_levels or not holds(world.ground_at(nx, ny)):
						continue
					var at := Vector2(tx + 0.5, ty + 0.5)
					var p := plan(world, query, at, d, 1e9)
					if p != null:
						return {"at": at, "dir": d, "plan": p}
	return {}


## Health a body loses coming down `levels` of face: 1 for every 3 (or part of
## them) past what a jump may drop.
static func fall_damage(levels: int) -> int:
	return ceili(float(maxi(0, levels - Jump.DOWN_LEVELS)) / 3.0)
