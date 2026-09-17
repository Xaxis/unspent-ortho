class_name Crafts
## The rules of getting on, getting off, and coming apart. Pure and headless: the
## system (src/systems/44_crafts.gd) only supplies the world, the keys and the
## drawing.
##
## Two rules keep a craft honest, and both are symmetries:
##   * A craft is set down, and stepped off onto, only within `launch` tiles and
##     only along a line the craft itself could travel. So a raft is shoved out
##     past the shallows and nosed back in, and neither end of a ride is a
##     teleport across a headland.
##   * A body steps off only onto ground it could have stood on anyway. Getting
##     off is never how a channel is crossed; the craft is.

## Tiles from a parked craft that `ride` reaches it at.
const BOARD_REACH := 2.2
## Tiles travelled over ground a body could not cross that count as a crossing
## (a tour's `ride_crossed`): far enough that no launch alone can claim it.
const CROSSED_TILES := 2.0
## How finely a line is sampled when asking whether a craft could travel it.
const LINE_STEP := 0.45


static func nearest(list: Array, at: Vector2, reach: float = BOARD_REACH) -> Craft:
	var best: Craft = null
	var best_d := reach * reach
	for c: Craft in list:
		var d := c.pos.distance_squared_to(at)
		if d <= best_d:
			best_d = d
			best = c
	return best


## True where a craft of this kind can be: the ground it travels over, inside the
## world. Nothing about levels here — a step is a question about a move.
static func crossable(world: WorldData, kind: StringName, p: Vector2) -> bool:
	var tx := floori(p.x)
	var ty := floori(p.y)
	if world == null or not world.in_bounds(tx, ty):
		return false
	var r := CraftKinds.ride(kind)
	return r != null and r.crosses(world.ground_at(tx, ty))


## Ground a body on foot could not cross at all. The measure of what a craft is
## for, and the one thing a crossing is counted in.
static func beyond_a_body(world: WorldData, p: Vector2) -> bool:
	var tx := floori(p.x)
	var ty := floori(p.y)
	return world != null and world.in_bounds(tx, ty) and world.ground_at(tx, ty) == Ground.DEEP_WATER


## Every point along a-b is ground this craft travels over.
static func clear_line(world: WorldData, kind: StringName, a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / LINE_STEP))
	for i in range(1, steps + 1):
		if not crossable(world, kind, a.lerp(b, float(i) / steps)):
			return false
	return true


## Every point along a-b is ground a body could walk or wade, or ground the craft
## travels over: what "step off without crossing anything" means.
static func wadeable_line(world: WorldData, query: WorldQuery, kind: StringName, a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / LINE_STEP))
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if crossable(world, kind, p):
			continue
		if query == null or not query.standable(floori(p.x), floori(p.y)):
			return false
	return true


## Where a craft carried in the pack is set down, and the body with it, or
## Vector2.INF when there is nowhere. A craft that has to float is shoved out to
## the deepest water it can reach, so boarding at the tideline puts it past the
## shallows; anything else is set down where the body stands, or as near to it as
## the ground allows.
static func launch_spot(world: WorldData, query: WorldQuery, kind: StringName, from: Vector2, facing: float = 0.0) -> Vector2:
	if world == null or not CraftKinds.known(kind):
		return Vector2.INF
	var reach := CraftKinds.launch_reach(kind)
	var want_deep := CraftKinds.afloat(kind)
	var ahead := Vector2.from_angle(facing)
	var best := Vector2.INF
	var best_score := -INF
	var r := ceili(reach)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := Vector2(floori(from.x) + dx + 0.5, floori(from.y) + dy + 0.5)
			var d := from.distance_to(p)
			if d > reach or not crossable(world, kind, p) or not clear_line(world, kind, from, p):
				continue
			# Deep water first (a float wants water under it), then the way the
			# body is turned, then the nearest: a shove, not a jump.
			var deep := 1.0 if (want_deep and beyond_a_body(world, p)) else 0.0
			var score := deep * 100.0 - d
			if d > 0.01:
				score += ahead.dot((p - from) / d) * 0.6
			if score > best_score:
				best_score = score
				best = p
	return best


## Where the body steps off, or Vector2.INF when there is nowhere to stand. Only
## ground a body could have walked or waded to, so leaving never crosses anything.
static func step_off_spot(world: WorldData, query: WorldQuery, kind: StringName, at: Vector2) -> Vector2:
	if world == null or query == null:
		return Vector2.INF
	var reach := CraftKinds.launch_reach(kind)
	var best := Vector2.INF
	var best_d := INF
	var r := ceili(reach)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var tx := floori(at.x) + dx
			var ty := floori(at.y) + dy
			if not world.in_bounds(tx, ty) or not query.standable(tx, ty):
				continue
			var p := Vector2(tx + 0.5, ty + 0.5)
			var d := at.distance_to(p)
			if d > reach or d >= best_d or not wadeable_line(world, query, kind, at, p):
				continue
			best_d = d
			best = p
	return best


## Hull lost per tile travelled over this ground: shallows grind a raft's drums,
## scree and swarf tear at a skirt, and a walker rig is machinery whatever it
## walks on.
static func wear_for(kind: StringName, ground: int) -> float:
	var row := CraftKinds.row(kind)
	if row.is_empty():
		return 0.0
	var table: Dictionary = row.get("wear", {})
	if table.has(ground):
		return float(table[ground])
	return float(row.get("wear_any", 0.0))


static func wear_per_step(kind: StringName) -> float:
	return float(CraftKinds.row(kind).get("wear_step", 0.0))


## &"" when `ride` would take this craft, else why not.
static func board_refusal(craft: Craft, from: Vector2) -> StringName:
	if craft == null:
		return &"none"
	if craft.pos.distance_to(from) > BOARD_REACH:
		return &"far"
	if craft.wrecked:
		return &"wrecked"
	return &""


## The line said when boarding, leaving or launching is refused.
static func refusal_line(why: StringName, kind: StringName = &"") -> String:
	var name := CraftKinds.display_name(kind) if kind != &"" else "craft"
	match why:
		&"afloat":
			return "The %s needs water under it. Take it to the shore." % name
		&"room":
			return "There is no room to set the %s down here." % name
		&"ashore":
			return "There is nowhere to step off. Bring it in closer."
		&"wrecked":
			return "The %s is finished. Nothing will carry you on it." % name
		&"none", &"far":
			return "There is nothing here to board."
	return "The %s will not have it." % name
