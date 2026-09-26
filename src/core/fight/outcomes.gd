class_name Outcomes
## What a bad end costs, applied to the body, the bag and the one clock
## (design-extract §6.5). No death and no respawn: time is what you lose.
##   downed   +180 minutes (and the threat's own toll) where you fell; wake hurt at 3
##   carried  +480 minutes, a shift of work: wake at the nearest rock face within
##            300 tiles, facing it, lamp burnt out, hurt; and the bag stays where
##            you were taken (Survival.leave_bag, which 40_fight calls); near a
##            holding of your own, you wake at its hearth (home_hearth)

const ORE := [PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE]
const ROCK := [PropKind.BOULDER, PropKind.CLINTS, PropKind.STANDING_STONE]
## Uses a hard-enough breaking tool loses over a forced shift (the source's 16 at iron).
const SHIFT_WEAR := 16
## Rock faces tried, nearest first, before giving up on a place to stand.
const BESIDE_TRIES := 12
## The radii `working_near` widens through; the last reaches any range.
const SHELLS: Array[float] = [16.0, 32.0, 64.0, 128.0, INF]

## Tiles searched out from the track for somewhere to be stood after an arrest.
const OFF_TRACK_RANGE := 8
## Tiles within which a holding with its hearth standing is where a carried
## player wakes (SETTLE.md S1).
const CARRIED_HOME := 60.0

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


## YOUR HOLDING IS WHERE YOU COME BACK TO. The standing hearth of the nearest
## holding in `places` within CARRIED_HOME of `from`, and a place to wake
## beside it facing it: {pos, facing} or {} (then the rock face, as ever).
static func home_hearth(places: Array, from: Vector2, world: WorldData, query: WorldQuery) -> Dictionary:
	var best: Structure = null
	var best_d := CARRIED_HOME
	for s: Settlement in places:
		for p: Structure in s.structures_of(StructureKind.HEARTH):
			if not p.standing():
				continue
			var d := p.pos.distance_to(from)
			if d <= best_d:
				best_d = d
				best = p
	if best == null:
		return {}
	# South-east of it first, as at a rock face: the fire is seen past the player.
	for d: Vector2 in [Vector2(1, 1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, 0), Vector2(0, -1), Vector2(-1, -1)]:
		var at := best.pos + d.normalized() * 1.1
		var tx := floori(at.x)
		var ty := floori(at.y)
		if query != null and (not query.standable(tx, ty) or Ground.is_water(world.ground_at(tx, ty))):
			continue
		return {"pos": at, "facing": (best.pos - at).angle()}
	return {}


## Where a warden leaves the player it arrested: the nearest ground beside the
## track that is not track (road or floor), not water, a step at most up or down
## from where they stood, and clear of solid props. Returns {pos, moved};
## `moved` false (pos = from) when already off the track or nowhere fits.
static func off_the_track(world: WorldData, query: WorldQuery, from: Vector2) -> Dictionary:
	var fx := floori(from.x)
	var fy := floori(from.y)
	if not _on_track(world.ground_at(fx, fy)):
		return {"pos": from, "moved": false}
	# Walked out from where you stood, a step up or down at a time, so the side
	# of the track you are left on is one you could have walked to.
	var best := Vector2.ZERO
	var best_d := INF
	var seen := {Vector2i(fx, fy): true}
	var frontier: Array[Vector2i] = [Vector2i(fx, fy)]
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			for s in steps:
				var t := c + s
				if seen.has(t) or maxi(absi(t.x - fx), absi(t.y - fy)) > OFF_TRACK_RANGE:
					continue
				seen[t] = true
				if not query.passable(c.x, c.y, t.x, t.y) or Ground.is_water(world.ground_at(t.x, t.y)):
					continue
				if _on_track(world.ground_at(t.x, t.y)):
					next.append(t)
					continue
				var at := Vector2(t.x + 0.5, t.y + 0.5)
				var d := at.distance_to(from)
				if d < best_d and not _blocked(query, at, null):
					best = at
					best_d = d
		frontier = next
	if best_d < INF:
		return {"pos": best, "moved": true}
	return {"pos": from, "moved": false}


static func _on_track(g: int) -> bool:
	return g == Ground.ROAD or g == Ground.FLOOR


static func _blocked(query: WorldQuery, at: Vector2, except: WorldProp) -> bool:
	for q in query.props_near(at, 2.0):
		if not WorldProp.same(q, except) and q.solid > 0.0 and q.pos.distance_to(at) < q.solid + Tuning.PLAYER_RADIUS:
			return true
	return false


## A standable place beside the nearest ore (else bare rock) within `range_tiles`,
## and the facing that looks at it. {} if there is none.
##
## Searched outward in SHELLS, not over the world's props: the range is
## hundreds of tiles and a streamed world holds only what is near
## (whole_world_readers.txt). Candidates are tried nearest first, the lowest id
## of the equally near first, at most BESIDE_TRIES of each kind in all; every
## candidate inside a shell is in hand before any past it is tried, so the
## answer is the one a sweep of every prop gave, and it is almost always found
## in the first shells.
static func working_near(world: WorldData, query: WorldQuery, from: Vector2, range_tiles: float) -> Dictionary:
	for kinds: Array in [ORE, ROCK]:
		var tries := 0
		var lo2 := -1.0
		for shell: float in SHELLS:
			var hi := minf(shell, range_tiles)
			var hi2 := hi * hi
			var cands: Array[WorldProp] = []
			var dists: Array[float] = []
			for p in query.props_near(from, hi):
				if kinds.has(p.kind) and not world.depleted.has(p.id):
					var d := p.pos.distance_squared_to(from)
					if d > lo2 and d <= hi2:
						cands.append(p)
						dists.append(d)
			var order := range(cands.size())
			order.sort_custom(func(a: int, b: int) -> bool:
				return dists[a] < dists[b] or (dists[a] == dists[b] and cands[a].id < cands[b].id))
			for i: int in order:
				if tries >= BESIDE_TRIES:
					break
				tries += 1
				var spot := _beside(world, query, cands[i])
				if not spot.is_empty():
					return spot
			if tries >= BESIDE_TRIES or hi >= range_tiles:
				break
			lo2 = hi2
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
		if _blocked(query, at, p):
			continue
		return {"pos": at, "facing": (p.pos - at).angle(), "prop": p}
	return {}
