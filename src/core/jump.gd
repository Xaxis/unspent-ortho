class_name Jump
## A person's jump (owner, 2026-09-17): up onto a ledge a walk cannot step, across
## a gap a walk cannot cross, down a drop a walk will not take — and no further.
##
## The owner's reach: **up 2 levels, across a 2-tile gap, down 3 levels.** Walking
## already steps one level either way; two or more is a cliff. Anything taller
## than a jump is still a wall, and anything deeper is still the glide's to get
## down, so the wing and the rope keep their reasons to exist.
##
## Nothing here is a lookup of "is this tile jumpable". A jump is an ARC, planned
## whole at the press as pure arithmetic over the world: it rises to `APEX`,
## carries the body along at the pace it was moving, is stopped by any ground
## higher than the body is at that instant, and comes down on whatever is under
## it. So a 2-level ledge is reachable because the apex clears it, a 3-level one
## is not because it does not, and a gap is crossed because the body is still in
## the air over it. The reach the owner asked for is what the numbers produce,
## and `tests/jump` holds them to it rather than trusting a comment.
##
## The one rule that is not the arc's: **a jump never goes over a drop deeper than
## `DOWN_LEVELS`**. A planned landing that would is planned again with that deep
## ground treated as a wall, so the body comes down at the lip instead of off the
## edge — a key pressed at a sea cliff must never be the end of a run. Deep water
## is the exception: a drop into it is a dive, and the water takes it.
##
##   Jump.plan(world, query, from, dir, speed)   -> JumpPlan (the whole arc)
##   Jump.find(world, query, near, kind, reach)  -> {at, dir} somewhere a jump of
##                                                  that kind lands, for tours and tests

## World units above the take-off the arc peaks at. A level is `WorldData.STEP`
## (0.5), so this clears two levels (1.0) with room to come down ON them, and
## never three (1.5).
const APEX := 1.25
## Seconds from the take-off to the top of the arc. Together with APEX this is
## the whole of the jump's weight: a short, committed hop, not a float.
const RISE := 0.3
const GRAVITY := 2.0 * APEX / (RISE * RISE)
const LIFT_OFF := 2.0 * APEX / RISE
## Tiles a second the body carries through the air. A jump taken on the move
## keeps at least CARRY, a run's pace keeps a run's; a jump from standing still
## hops forward along the facing at STAND, enough to get onto a ledge the player
## is standing against and no more. CARRY is what makes a two-tile gap crossable
## from the MIDDLE of the lip tile and a three-tile one not from its very edge
## (tests/jump holds both ends of that).
const CARRY := 4.5
const STAND := 2.2
## The reach, as the owner put it. UP and GAP are what the arc produces with the
## numbers above (tests/jump proves it); DOWN is enforced (see the header).
const UP_LEVELS := 2
const GAP_TILES := 2
const DOWN_LEVELS := 3
## Seconds per step of the planned arc: fine enough that a ledge's lip is not
## stepped through at a run.
const DT := 1.0 / 120.0
## No arc lasts longer than this, whatever the world does.
const LONGEST := 2.0
## The kinds of jump, by where it landed against where it took off.
const HOP := &"hop"
const UP := &"up"
const ACROSS := &"across"
const DOWN := &"down"
const DIVE := &"dive"


## The whole arc of a jump from `from` along `dir` (ZERO = straight up) at `speed`
## tiles a second, for a body of `radius`. Deterministic: the same press in the
## same world plans the same jump.
static func plan(world: WorldData, query: WorldQuery, from: Vector2, dir: Vector2, speed: float, radius: float = Tuning.PLAYER_RADIUS) -> JumpPlan:
	var p := _arc(world, query, from, dir, speed, radius, false)
	if p.too_deep:
		# Off the edge of something deeper than a jump: come down at the lip.
		p = _arc(world, query, from, dir, speed, radius, true)
	return p


static func _arc(world: WorldData, query: WorldQuery, from: Vector2, dir: Vector2, speed: float, radius: float, guard_drops: bool) -> JumpPlan:
	var p := JumpPlan.new()
	p.from = from
	p.from_level = _level(world, from)
	var take_off := _ground(world, from)
	p.from_height = take_off
	var d := dir.normalized() if dir.length() > 0.001 else Vector2.ZERO
	p.dir = d
	var at := from
	var h := take_off
	var vz := LIFT_OFF
	var t := 0.0
	var crossed_gap := false
	p.points.append(at)
	p.heights.append(h)
	while t < LONGEST:
		t += DT
		vz -= GRAVITY * DT
		h += vz * DT
		if d != Vector2.ZERO:
			at = _carry(world, query, at, d * speed * DT, radius, h, p.from_level, guard_drops)
		var ground := _ground(world, at)
		var level := _level(world, at)
		if level <= p.from_level - UP_LEVELS or _deep(world, at):
			crossed_gap = crossed_gap or at.distance_to(from) > radius
		if vz < 0.0 and h <= ground:
			h = ground
			p.points.append(at)
			p.heights.append(h)
			break
		p.points.append(at)
		p.heights.append(h)
	p.seconds = float(p.points.size() - 1) * DT
	p.to = at
	p.to_level = _level(world, at)
	p.to_height = _ground(world, at)
	var dived := _deep(world, at)
	p.too_deep = not guard_drops and not dived and p.to_level < p.from_level - DOWN_LEVELS
	p.kind = _kind(p, crossed_gap, dived)
	return p


## One step of the body through the air: blocked by ground higher than it is right
## now and by anything solid, sliding along what stops it the way a walk does.
static func _carry(world: WorldData, query: WorldQuery, at: Vector2, step: Vector2, radius: float, h: float, from_level: int, guard_drops: bool) -> Vector2:
	var full := at + step
	if _clear(world, query, at, full, radius, h, from_level, guard_drops):
		return full
	var x := Vector2(at.x + step.x, at.y)
	if _clear(world, query, at, x, radius, h, from_level, guard_drops):
		return x
	var y := Vector2(at.x, at.y + step.y)
	if _clear(world, query, at, y, radius, h, from_level, guard_drops):
		return y
	return at


static func _clear(world: WorldData, query: WorldQuery, from: Vector2, to: Vector2, radius: float, h: float, from_level: int, guard_drops: bool) -> bool:
	if world == null:
		return true
	for c: Vector2 in [to, to + Vector2(-radius, -radius), to + Vector2(radius, -radius), to + Vector2(-radius, radius), to + Vector2(radius, radius)]:
		var tx := floori(c.x)
		var ty := floori(c.y)
		if not world.in_bounds(tx, ty):
			return false
		# Ground higher than the body is, this instant, is a wall to fly into.
		if float(maxi(0, world.level_at(tx, ty))) * WorldData.STEP > h + 1e-4:
			return false
		if guard_drops and world.ground_at(tx, ty) != Ground.DEEP_WATER and world.level_at(tx, ty) < from_level - DOWN_LEVELS:
			return false
	if query == null:
		return true
	# Solid things stop a body in the air as they stop one on the ground: nothing
	# the world records says how tall a boulder or a wall is, and a jump that went
	# through a house because nobody wrote its height down would be a worse lie
	# than one that stops at it.
	for q in query.props_near(to, 2.0):
		if q.solid <= 0.0 or world.depleted.has(q.id):
			continue
		var rr := q.solid + radius
		var after := q.pos.distance_squared_to(to)
		if after < rr * rr and after < q.pos.distance_squared_to(from):
			return false
	for c: Vector3 in query.blocks_at(to):
		var at := Vector2(c.x, c.y)
		var rr := c.z + radius
		var after := at.distance_squared_to(to)
		if after < rr * rr and after < at.distance_squared_to(from):
			return false
	return true


static func _kind(p: JumpPlan, crossed_gap: bool, dived: bool) -> StringName:
	if dived and p.to_level < p.from_level:
		return DIVE
	var rise := p.to_level - p.from_level
	if rise >= UP_LEVELS:
		return UP
	if rise <= -UP_LEVELS:
		return DOWN
	if crossed_gap:
		return ACROSS
	return HOP


## The ground's own height under a point, as the world draws it (the sea floor
## clamps to 0, which is the water's surface for a body: nothing lands lower).
static func _ground(world: WorldData, p: Vector2) -> float:
	return world.height_at(p) if world != null else 0.0


static func _level(world: WorldData, p: Vector2) -> int:
	return world.level_at(floori(p.x), floori(p.y)) if world != null else 0


static func _deep(world: WorldData, p: Vector2) -> bool:
	return world != null and world.ground_at(floori(p.x), floori(p.y)) == Ground.DEEP_WATER


## How fast a jump carries the body: at least CARRY on the move, the body's own
## pace when that is faster, and STAND from standing still.
static func speed_for(moving: bool, pace: float) -> float:
	return maxf(CARRY, pace) if moving else STAND


# --- finding one, by name ---------------------------------------------------------

## Somewhere near `near` a jump of `kind` (UP, ACROSS, DOWN) lands, taken from a
## standing start on dry ground with a walker's carry: `{at, dir}`, or {} when
## there is none within `reach` tiles. What a tour stages by (`ledge KIND`) and a
## test stands a body at, so neither ever names a coordinate.
static func find(world: WorldData, query: WorldQuery, near: Vector2, kind: StringName, reach: float = 40.0) -> Dictionary:
	if world == null:
		return {}
	var cx := floori(near.x)
	var cy := floori(near.y)
	var r_max := int(reach)
	for r in range(0, r_max + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var tx := cx + dx
				var ty := cy + dy
				if not world.in_bounds(tx, ty) or world.ground_at(tx, ty) == Ground.DEEP_WATER:
					continue
				var at := Vector2(tx + 0.5, ty + 0.5)
				if query != null and not _stands_clear(world, query, at):
					continue
				for i in 8:
					var dir := Vector2.from_angle(TAU * float(i) / 8.0)
					if not _could_be(world, at, dir, kind):
						continue
					var p := plan(world, query, at, dir, CARRY)
					if p.kind == kind and p.to.distance_to(at) > 0.6:
						return {"at": at, "dir": dir, "plan": p}
	return {}


## A cheap look along `dir` before an arc is planned: the levels a tile or two
## ahead would have to have for a jump of `kind` to land there at all. Planning
## every direction of every tile of a search would be millions of steps.
static func _could_be(world: WorldData, at: Vector2, dir: Vector2, kind: StringName) -> bool:
	var here := world.level_at(floori(at.x), floori(at.y))
	var levels: Array[int] = []
	var deep: Array[bool] = []
	for k in 4:
		var q := at + dir * (0.8 + 0.8 * float(k))
		var tx := floori(q.x)
		var ty := floori(q.y)
		if not world.in_bounds(tx, ty):
			return false
		levels.append(world.level_at(tx, ty))
		deep.append(world.ground_at(tx, ty) == Ground.DEEP_WATER)
	match kind:
		UP:
			return levels[0] - here == UP_LEVELS or levels[1] - here == UP_LEVELS
		DOWN:
			var drop := here - levels[0]
			return not deep[0] and drop >= UP_LEVELS and drop <= DOWN_LEVELS
		ACROSS:
			var gap := here - levels[0] >= UP_LEVELS or deep[0]
			var far := false
			for k in range(1, 4):
				far = far or (absi(levels[k] - here) < UP_LEVELS and not deep[k])
			return gap and far
	return true


## A standing spot with room for a body: nothing solid on it, all its corners on
## its own level so the take-off is not a scramble off a slope.
static func _stands_clear(world: WorldData, query: WorldQuery, at: Vector2) -> bool:
	var r := Tuning.PLAYER_RADIUS
	var level := world.level_at(floori(at.x), floori(at.y))
	for c: Vector2 in [at + Vector2(-r, -r), at + Vector2(r, -r), at + Vector2(-r, r), at + Vector2(r, r)]:
		if world.level_at(floori(c.x), floori(c.y)) != level:
			return false
	for q in query.props_near(at, 1.5):
		if q.solid > 0.0 and not world.depleted.has(q.id) and q.pos.distance_to(at) < q.solid + r:
			return false
	return query.blocks_at(at).is_empty()
