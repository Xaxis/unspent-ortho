class_name AbilityGrapple
extends Ability
## A magnet line off the boots: it takes hold of something solid ahead, or of a
## ledge, and pulls the body to it over ground a walk could not climb. What it
## can reach is what the land already holds, so a player learns to read props
## and lips as handholds.

const RANGE := 8.0
## How wide a cone ahead the line will look in, in radians either side.
const CONE := 0.7
## A prop is only worth hooking if it has this much body to take a line: a post,
## a sign, a mast, a wreck. Tufts and wrack have nothing to hold.
const SOLID := 0.1
const SPEED := 14.0
const COOLDOWN := 2.6
const WIND := 200.0
## Levels above the body that count as a ledge to be pulled onto.
const LEDGE_LEVELS := 2
## THE VERTICAL LINE (mechanics improvement 5b). At the foot of a face, of any
## ground, with something solid standing at its top -- a post, a pylon, a bolt,
## a mast -- the line goes straight UP to that hold and hauls the body up the
## face and over the lip, HAUL_RATE levels a second, no more than MAX_UP levels
## (a ledge further up than that is out of the line's reach, vertical or not).
## A hold is a solid prop on the top's own level within HOLD_REACH of the lip.
const MAX_UP := 8
const HAUL_RATE := 6.0
const HOLD_REACH := 2.0
## How near the foot of a face the body must stand for the line to go up it.
const FOOT_REACH := 1.2
## What a line hauled up a face takes hold of: an upright thing a magnet line
## wraps and a body's weight does not pull over -- a trunk, a post, a mast, a
## pylon, a rod -- not a shrub, a heap or a boulder, which a player would never
## read as a hold.
const HOLD_KINDS: Array[int] = [PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE,
	PropKind.PYLON, PropKind.LAMP, PropKind.POLE, PropKind.SIGN, PropKind.TIDE_GAUGE, PropKind.FIRE_TOWER,
	PropKind.RELAY, PropKind.THEODOLITE_MAST, PropKind.STRIKE_ROD, PropKind.MOORING_POST, PropKind.SPAN_PYLON,
	PropKind.STANDING_STONE]


func _init() -> void:
	id = &"grapple"
	name = "grapple"
	action = &"ability_grapple"
	cooldown = COOLDOWN
	wind = WIND
	note = "t  to a hold"


## What the line would take hold of: {pos: Vector2, height: float, what: StringName}
## or {} if nothing is in range. Pure.
static func anchor(world: WorldData, query: WorldQuery, at: Vector2, dir: Vector2) -> Dictionary:
	if world == null or dir.length() < 0.01:
		return {}
	var d := dir.normalized()
	var up := vertical(world, query, at, d)
	if not up.is_empty():
		return up
	var best: Dictionary = {}
	var best_d := INF
	if query != null:
		for p: WorldProp in query.props_near(at, RANGE):
			if p.solid < SOLID:
				continue
			var to := p.pos - at
			var away := to.length()
			if away < 1.2 or away > RANGE or absf(to.angle_to(d)) > CONE:
				continue
			if away < best_d:
				best_d = away
				best = {"pos": p.pos, "height": world.height_at(p.pos), "what": &"prop"}
	# A lip of rock in front is as good a hold as a post.
	var here := world.level_at(floori(at.x), floori(at.y))
	var travelled := 1.5
	while travelled <= RANGE:
		var q := at + d * travelled
		var tx := floori(q.x)
		var ty := floori(q.y)
		if not _inside(world, q):
			break
		var l := world.level_at(tx, ty)
		if l - here > MAX_UP:
			break
		if l - here >= LEDGE_LEVELS and (query == null or query.standable(tx, ty)):
			if travelled < best_d:
				return {"pos": q, "height": world.height_at(q), "what": &"ledge"}
			break
		travelled += 0.5
	return best


## The vertical line: a face at the foot of which the body stands, no taller
## than MAX_UP, and a solid prop at its top to hold. {pos (the top), height,
## what: &"face", hold: Vector2, plan: Climb.Plan} or {}. Pure.
static func vertical(world: WorldData, query: WorldQuery, at: Vector2, d: Vector2) -> Dictionary:
	if query == null:
		return {}
	var p := Climb.plan(world, query, at, d, 1e9, true)
	if p == null or p.levels > MAX_UP or p.from.distance_to(p.on_face) > FOOT_REACH:
		return {}
	var best: WorldProp = null
	var best_d := INF
	for q: WorldProp in query.props_near(p.top, HOLD_REACH + 1.0):
		if not HOLD_KINDS.has(q.kind) or world.depleted.has(q.id):
			continue
		if world.level_at(floori(q.pos.x), floori(q.pos.y)) != p.to_level:
			continue
		var dd := q.pos.distance_to(p.top)
		if dd <= HOLD_REACH and dd < best_d:
			best_d = dd
			best = q
	if best == null:
		return {}
	p.rate = HAUL_RATE
	p.seconds = p.up_seconds() + Climb.LIP_SECONDS
	return {"pos": p.top, "height": p.top_height, "what": &"face", "hold": best.pos, "plan": p}


## The nearest foot of a face the vertical line goes up, at least `min_levels`
## tall (by default one a jump will not do), for tours and tests, which name one
## and never a coordinate (`ledge haul`): {at, dir} or {}.
static func find_vertical(world: WorldData, query: WorldQuery, near: Vector2, reach: float = 80.0, min_levels: int = Jump.UP_LEVELS + 1) -> Dictionary:
	if world == null or query == null:
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
				if not world.in_bounds(tx, ty) or not query.standable(tx, ty) or Ground.is_water(world.ground_at(tx, ty)):
					continue
				var here := world.level_at(tx, ty)
				for d in dirs:
					var nx := tx + int(d.x)
					var ny := ty + int(d.y)
					if not world.in_bounds(nx, ny):
						continue
					var up := world.level_at(nx, ny) - here
					if up < maxi(LEDGE_LEVELS, min_levels) or up > MAX_UP:
						continue
					var at := Vector2(tx + 0.5, ty + 0.5)
					if not vertical(world, query, at, d).is_empty():
						return {"at": at, "dir": d}
	return {}


static func _inside(world: WorldData, p: Vector2) -> bool:
	return p.x >= 1.0 and p.y >= 1.0 and p.x <= world.size - 2.0 and p.y <= world.size - 2.0


func refusal(ctx: AbilityCtx) -> StringName:
	var b := ctx.body()
	if b == null or ctx.game == null:
		return &"nothing"
	if b.grip > 0:
		return &"held"
	if anchor(ctx.game.world, ctx.game.query, ctx.pos(), ctx.heading()).is_empty():
		return &"no_anchor"
	return &""


func on_press(ctx: AbilityCtx) -> bool:
	var a := anchor(ctx.game.world, ctx.game.query, ctx.pos(), ctx.heading())
	if a.is_empty():
		return false
	var at := ctx.pos()
	var target: Vector2 = a.pos
	if a.what == &"face":
		var m := AbilityMotion.climb_face(a.plan)
		m.kind = &"haul"
		var hold: Vector2 = a.hold
		m.hold = Vector3(hold.x, ctx.game.world.height_at(hold), hold.y)
		ctx.motion = m
		ctx.draw(&"grapple", {"at": at, "to": hold, "what": a.what, "seconds": m.seconds})
		return true
	var short := 0.9 if a.what == &"prop" else 0.0
	ctx.motion = AbilityMotion.grapple(at, target, SPEED, short, ctx.game.world.height_at(at), float(a.height))
	# The mark on the anchor is held for as long as the pull runs, so the hold is
	# on screen from the press to the arrival.
	ctx.draw(&"grapple", {"at": at, "to": target, "what": a.what, "seconds": ctx.motion.seconds})
	return true
