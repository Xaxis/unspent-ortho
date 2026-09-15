class_name Outcomes
## What a bad end costs, applied to the body, the bag and the one clock
## (design-extract §6.5). No death and no respawn: time is what you lose.
##   downed   +180 minutes (and the threat's own toll) where you fell; wake hurt at 3
##   carried  +480 minutes, a shift of work: wake at the nearest rock face within
##            300 tiles, facing it, lamp burnt out, hurt

const ORE := [PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE]
const ROCK := [PropKind.BOULDER, PropKind.CLINTS, PropKind.STANDING_STONE]
## Uses a hard-enough breaking tool loses over a forced shift (the source's 16 at iron).
const SHIFT_WEAR := 16

const DOWNED_LINE := "You come to on the ground where it left you. The light has moved."
const CARRIED_LINE := "You wake against cold rock with sore hands, a long way from where you were. The lamp is dry."
const WON_LINE := ""
const AWAY_LINE := ""


## Returns {minutes, line}. `by_kind` is the roster id of what put you down (may be empty).
static func downed(body: Body, clock: WorldClock, by_kind: StringName) -> Dictionary:
	var minutes := FightRules.DOWNED_MINUTES + float(Roster.row(by_kind).get("takes", 0.0))
	clock.skip(minutes)
	body.health = FightRules.DOWNED_WAKE_HEALTH
	body.grip = 0
	body.hurt_until = maxf(body.hurt_until, clock.minutes + FightRules.HURT_MINUTES)
	return {"minutes": minutes, "line": DOWNED_LINE}


## Returns {minutes, line, pos, facing, moved}. `from` is where you were taken.
static func carried(body: Body, inv: Inventory, clock: WorldClock, world: WorldData, query: WorldQuery, from: Vector2) -> Dictionary:
	var minutes := FightRules.CARRIED_MINUTES
	clock.skip(minutes)
	body.grip = 0
	body.lamp_lit = false
	body.hurt_until = maxf(body.hurt_until, clock.minutes + FightRules.HURT_MINUTES)
	if inv != null and inv.held != &"":
		var verb: StringName = Items.def(inv.held).get("verb", &"")
		if verb == &"break" or verb == &"dig":
			FightRules.wear(inv, inv.held, SHIFT_WEAR)
	var result := {"minutes": minutes, "line": CARRIED_LINE, "pos": from, "facing": 0.0, "moved": false}
	var spot := working_near(world, query, from, FightRules.CARRIED_RANGE)
	if not spot.is_empty():
		result.pos = spot.pos
		result.facing = spot.facing
		result.moved = true
	return result


## A standable place beside the nearest ore (else bare rock) within `range_tiles`,
## and the facing that looks at it. {} if there is none.
static func working_near(world: WorldData, query: WorldQuery, from: Vector2, range_tiles: float) -> Dictionary:
	for kinds: Array in [ORE, ROCK]:
		var props: Array[WorldProp] = []
		for p in world.props:
			if kinds.has(p.kind) and not world.depleted.has(p.id) and p.pos.distance_squared_to(from) <= range_tiles * range_tiles:
				props.append(p)
		props.sort_custom(func(a: WorldProp, b: WorldProp) -> bool:
			return a.pos.distance_squared_to(from) < b.pos.distance_squared_to(from))
		for p in props:
			var spot := _beside(world, query, p)
			if not spot.is_empty():
				return spot
	return {}


static func _beside(world: WorldData, query: WorldQuery, p: WorldProp) -> Dictionary:
	# South-east first: the camera looks north-west, so the rock is seen past the player.
	var dirs: Array[Vector2] = [Vector2(1, 1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, 0), Vector2(0, -1), Vector2(-1, -1)]
	for d in dirs:
		var at := p.pos + d.normalized() * (p.solid + Tuning.PLAYER_RADIUS + 0.35)
		var tx := floori(at.x)
		var ty := floori(at.y)
		if not query.standable(tx, ty) or Ground.is_water(world.ground_at(tx, ty)):
			continue
		var blocked := false
		for q in query.props_near(at, 2.0):
			if q != p and q.solid > 0.0 and q.pos.distance_to(at) < q.solid + Tuning.PLAYER_RADIUS:
				blocked = true
				break
		if blocked:
			continue
		return {"pos": at, "facing": (p.pos - at).angle(), "prop": p}
	return {}
