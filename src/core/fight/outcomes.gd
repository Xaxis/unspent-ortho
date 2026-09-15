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
## Rock faces tried, nearest first, before giving up on a place to stand.
const BESIDE_TRIES := 12

const DOWNED_LINE := "You come to where you fell. Hours have gone."
const CARRIED_LINE := "You wake at a rock face, hands raw, far from where you were. The lamp is out."


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
	var r2 := range_tiles * range_tiles
	for kinds: Array in [ORE, ROCK]:
		# Distances once, then nearest-first by selection: a large coast has tens of
		# thousands of props, and only the first few candidates are ever looked at.
		var cands: Array[WorldProp] = []
		var dists: PackedFloat32Array = []
		for p in world.props:
			if kinds.has(p.kind) and not world.depleted.has(p.id):
				var d := p.pos.distance_squared_to(from)
				if d <= r2:
					cands.append(p)
					dists.append(d)
		for attempt in mini(cands.size(), BESIDE_TRIES):
			var best := 0
			for i in dists.size():
				if dists[i] < dists[best]:
					best = i
			var spot := _beside(world, query, cands[best])
			if not spot.is_empty():
				return spot
			dists[best] = INF
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
