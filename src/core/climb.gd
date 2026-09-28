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
## A LADDER (WorldData.add_ladder) makes its riser a face whatever the ground,
## climbed at LADDER_RATE for LADDER_WIND a level, and the same key takes a body
## back DOWN it (`down`): a jump never drops more than Jump.DOWN_LEVELS, so a
## ladder's top is otherwise a lip nobody leaves.
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
## Up a ladder: rungs, not holds, so faster and far cheaper than rock.
const LADDER_RATE := 3.0
const LADDER_WIND := 30.0
## Seconds to get over the lip onto the top, and to come back down a face when
## the arms give out.
const LIP_SECONDS := 0.3
const SLIDE_SECONDS := 0.5
## How far ahead, tiles, a face is looked for from where the body stands.
const REACH := 0.9
## The step along the heading the face is looked for in.
const PROBE := 0.05
## Where a climber's middle is from the rock: a hand's reach in, so the arms are
## on the face and the body reads as against it, never hanging over the drop
## behind. Stepped to at the start, over APPROACH_SECONDS.
const ON_FACE := Tuning.PLAYER_RADIUS + 0.05
const APPROACH_SECONDS := 0.15


class Plan:
	extends RefCounted
	var from := Vector2.ZERO
	## Where the body climbs: ON_FACE out from the rock, straight in from `from`.
	var on_face := Vector2.ZERO
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
	## Levels a second up the face: Climb.RATE by hand, faster on a line
	## (AbilityGrapple's vertical haul) or a ladder.
	var rate := Climb.RATE
	## Down a ladder: from the lip (`from`, at `from_level`) to its foot (`top`,
	## at `to_level`, the lower), stepping off at the bottom.
	var down := false

	## Seconds from the press until the top (or until the arms give out): the
	## step in to the rock, then the climb.
	func up_seconds() -> float:
		return Climb.APPROACH_SECONDS + float(reached) / rate

	## [position, height in the world, level the body is at] `t` seconds in.
	func at(t: float) -> Array:
		if t < Climb.APPROACH_SECONDS:
			return [from.lerp(on_face, t / Climb.APPROACH_SECONDS), from_height, from_level]
		var up := up_seconds()
		if down:
			if t < up:
				var dl := (t - Climb.APPROACH_SECONDS) * rate
				return [on_face, from_height - dl * WorldData.STEP, from_level - floori(dl)]
			var v := clampf((t - up) / Climb.LIP_SECONDS, 0.0, 1.0)
			return [on_face.lerp(top, v), lerpf(from_height - float(levels) * WorldData.STEP, top_height, v), to_level]
		if t < up:
			var lv := (t - Climb.APPROACH_SECONDS) * rate
			return [on_face, from_height + lv * WorldData.STEP, from_level + floori(lv)]
		var u := clampf((t - up) / (Climb.SLIDE_SECONDS if slides else Climb.LIP_SECONDS), 0.0, 1.0)
		var peak := from_height + float(reached) * WorldData.STEP
		if slides:
			# Down the face faster and faster, to its foot.
			return [on_face, lerpf(peak, from_height, u * u), from_level + floori(float(reached) * (1.0 - u * u))]
		return [on_face.lerp(top, u), lerpf(peak, top_height, u), to_level]


## Is this ground climbable?
static func holds(ground: int) -> bool:
	return GROUNDS.has(ground)


## `any_ground`: a face of whatever ground, for a line that does not need the
## rock to hold (AbilityGrapple's vertical haul hangs off a prop at the top).
static func face(world: WorldData, query: WorldQuery, from: Vector2, dir: Vector2, reach: float = REACH, any_ground: bool = false) -> Dictionary:
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
		var ladder := world.ladder_between(here, t)
		if not any_ground and not ladder and not holds(world.ground_at(t.x, t.y)):
			return {}
		# Over the lip onto the shelf, clear of it by a body's width.
		var top := p + d * (Tuning.PLAYER_RADIUS + 0.2)
		var tt := Vector2i(floori(top.x), floori(top.y))
		if world.level_at(tt.x, tt.y) != lv or (query != null and not query.standable(tt.x, tt.y)):
			return {}
		# Mass hanging over the face (WorldData.overhead): a climb is only as
		# tall as the room over its foot, and a shelf with less than a body's
		# room over it is no top. Nothing climbs a ceiling.
		if world.has_overhead():
			var tall := int(ceil(Tuning.PLAYER_HEIGHT / WorldData.STEP))
			if world.headroom_at(here.x, here.y) < lv - from_level + tall or world.headroom_at(tt.x, tt.y) < tall:
				return {}
		return {"foot": from, "top": top, "wall": p - d * PROBE * 0.5, "from_level": from_level, "to_level": lv,
			"from_height": world.height_at(from), "top_height": world.height_at(top), "ladder": ladder}
	return {}


static func plan(world: WorldData, query: WorldQuery, from: Vector2, dir: Vector2, wind: float, any_ground: bool = false) -> Plan:
	var f := face(world, query, from, dir, REACH, any_ground)
	if f.is_empty():
		# By hand only: a line (any_ground) hauls up, never down a ladder.
		return null if any_ground else down(world, query, from, dir)
	var per_level := LADDER_WIND if f.ladder else WIND_PER_LEVEL
	var p := Plan.new()
	if f.ladder:
		p.rate = LADDER_RATE
	p.from = from
	p.top = f.top
	p.dir = dir.normalized()
	# In to the rock along the heading, never past where it stands already.
	var wall: Vector2 = f.wall
	var in_to := wall - p.dir * ON_FACE
	p.on_face = in_to if (in_to - from).dot(p.dir) > 0.0 else from
	p.from_level = f.from_level
	p.to_level = f.to_level
	p.from_height = f.from_height
	p.top_height = f.top_height
	p.levels = p.to_level - p.from_level
	p.reached = mini(p.levels, floori(maxf(0.0, wind) / per_level))
	p.slides = p.reached < p.levels
	p.wind = float(p.reached) * per_level
	p.fall_damage = fall_damage(p.reached) if p.slides else 0
	p.seconds = p.up_seconds() + (SLIDE_SECONDS if p.slides else LIP_SECONDS)
	return p


## Down a ladder from its top, facing the drop: the lip within REACH ahead is a
## riser with a ladder on it, at least a ledge deep. Null anywhere else, so off
## a plain edge the key is still a jump. Costs no breath and never slides.
static func down(world: WorldData, query: WorldQuery, from: Vector2, dir: Vector2) -> Plan:
	if world == null or dir.length() < 0.01:
		return null
	var d := dir.normalized()
	var here := Vector2i(floori(from.x), floori(from.y))
	var from_level := world.level_at(here.x, here.y)
	var p := from
	var travelled := 0.0
	while travelled <= REACH + Tuning.PLAYER_RADIUS:
		p += d * PROBE
		travelled += PROBE
		var t := Vector2i(floori(p.x), floori(p.y))
		if t == here:
			continue
		var lv := world.level_at(t.x, t.y)
		if from_level - lv < FightRules.LEDGE_LEVELS or not world.ladder_between(here, t):
			return null
		var foot := p + d * (Tuning.PLAYER_RADIUS + 0.2)
		var ft := Vector2i(floori(foot.x), floori(foot.y))
		if world.level_at(ft.x, ft.y) != lv or (query != null and not query.standable(ft.x, ft.y)):
			return null
		var c := Plan.new()
		c.down = true
		c.from = from
		c.dir = d
		# Over the lip, a hand's reach out from the riser, and down the rungs.
		c.on_face = p - d * PROBE * 0.5 + d * ON_FACE
		c.top = foot
		c.from_level = from_level
		c.to_level = lv
		c.from_height = world.height_at(from)
		c.top_height = world.height_at(foot)
		c.levels = from_level - lv
		c.reached = c.levels
		c.rate = LADDER_RATE
		c.seconds = c.up_seconds() + LIP_SECONDS
		return c
	return null


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
