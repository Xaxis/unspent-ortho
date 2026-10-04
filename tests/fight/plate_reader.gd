extends "res://tests/fight/shoulder_reader.gd"
## The shoulder reader as the proof tour's player stands (tours/reaper_force.tour):
## between bites it does not keep its distance, it walks round the body to the
## plate side (opposite the working part) and stands against it, facing it,
## waiting for the tell. Everything else -- the tell answered react_ms late, the
## dodge out of the box, the strike only from where it reaches the part -- is the
## reader's. It moves by `hero.move` at the walk and is never put anywhere.
## Where the plate side is ground a blow does not pass to (a bank two levels up,
## the sea), it waits as the reader does. `keep_off` / `keep_on` hold its walk
## to firm ground or out on the flats; `home` is where it walks back to.

## Tiles off the skin it stands, as `walkto plate` stops (98_tour).
const PLATE_GAP := 0.45
## How far outside a guarded keeper's bite it waits (tiles).
const GUARD_MARGIN := 0.6
## Further than this from `home` it has been carried off (a down), not stood.
const STRANDED := 10.0
## Closer than this to a keeper, a lure goes back out to its spot to draw it.
const LURE_OFF := 4.0
## A keeper still at its work this long after the player came has not seen
## them: they walk up to it until it does.
const UNSEEN_MS := 3000.0
## Grounds it never walks onto (a player keeping off the flats), grounds it
## never walks off (one holding out on them), and where it walks back to when
## nothing is out (come to after a down at the edge of its ground).
var keep_off: Array = []
var keep_on: Array = []
var home := Vector2.INF
## A lure: once it has the keeper after it, it walks out to here (onto the
## `keep_on` ground) and holds there, dodging, as a player drawing it out does.
var lure := Vector2.INF
var _at_work_since := -1.0
var _walk_up_to := Vector2.INF


func _wait(m: MobState) -> void:
	var hero := sim.hero
	var off := 0.0
	match m.part:
		&"back": off = PI
		&"left": off = -PI * 0.5
		&"right": off = PI * 0.5
	var spot := m.pos + Vector2.from_angle(m.facing + off + PI) * (m.radius + hero.radius + PLATE_GAP)
	# A guarded part is shut until its bite has come down on nothing (FightSim
	# reaches_part), and the bite comes after a long tell over a pale ring: the
	# player stands off the ring, as its phase says, and closes in when it is open.
	if bool(m.row.get("guarded", false)) and m.bite != null:
		var out := Vector2.from_angle(m.facing + off + PI)
		var far := m.radius + hero.radius + PLATE_GAP
		while far < 6.0 and _in_box_of(m.bite, m, m.pos + out * far, GUARD_MARGIN):
			far += 0.25
		spot = m.pos + out * far
	if not sim.meets(spot, m.pos) or not sim.query.standable(floori(spot.x), floori(spot.y)):
		# Its plate is up a bank or in the sea: no blow passes there, and a player
		# sees that. They keep their distance and let it come, as the reader does.
		super(m)
		return
	var to_mob := m.pos - hero.pos
	hero.facing = to_mob.angle()
	if hero.pos.distance_to(spot) <= 0.25:
		hero.move = Vector2.ZERO
		return
	hero.move = _round_to(m, spot)


## A guarded part is no opening until its bite has come down on nothing
## (FightSim reaches_part): the charger's rule (turns badly between runs) read a
## planted keeper calling a strike as open, and walked the player into the ring.
func _open(m: MobState) -> bool:
	if bool(m.row.get("guarded", false)) and m.roused() and not m.spent(sim.now) and not m.stunned(sim.now):
		return false
	return super(m)


## A player sees a bank two levels up for what it is: no blow passes between it
## and the machine below. Every step is kept to ground that meets the body's
## level, turned aside if the straight step would climb off it; carried up
## there anyway, they come straight back down.
func act() -> void:
	super()
	var hero := sim.hero
	var m := _nearest()
	if m == null:
		# Walking up to a keeper at its work round what stands between, it goes on
		# to where it saw it while the way turns it out of sight.
		if _walk_up_to.is_finite() and hero.pos.distance_to(_walk_up_to) > 0.5:
			hero.move = _walk_to(_walk_up_to)
			return
		# Nothing in sight (come to at the edge of its ground after a down): back
		# the way a player walks it, round what stands between.
		hero.move = _walk_back() if home.is_finite() and hero.pos.distance_to(home) > 1.0 else Vector2.ZERO
		return
	var here_g := sim.world.ground_at(floori(hero.pos.x), floori(hero.pos.y))
	# Off the ground it holds out on, or near enough a keeper that stands its own
	# ground to be struck from it (the anvil plants at the edge of its plates and
	# bites from there; only a charge, from further off, carries it onto the sand).
	var drawing := not keep_on.has(here_g) or m.pos.distance_to(hero.pos) < LURE_OFF
	# Drawing it out, the walk to the lure comes first. Ground off its level on
	# the way (a rise between its plates and the sand) is crossed, not stepped
	# back off: the step back onto its level and the step on to the lure undid
	# each other every frame, and the player stood on the rise's lip in its row
	# while the anvil's bites caught it (seed 1's den, test_anvil_ways).
	if lure.is_finite() and m.roused() and drawing and hero.pos.distance_to(lure) > 0.3 and sim.now >= _escape_until:
		hero.move = (lure - hero.pos).normalized()
		return
	# A wary keeper wakes only to someone it has seen inside its guard, and stood
	# off it, held to the flats or behind a rise its level does not meet, the
	# reader waited and the keeper worked on: 240 s at 9.6 tiles, never roused
	# (the strike field's den, second-keeper). Unseen a while, a player walks up
	# to it the way a body can walk (`_route`: over a rise a step at a time).
	if m.roused():
		_at_work_since = -1.0
		_walk_up_to = Vector2.INF
	elif _at_work_since < 0.0:
		_at_work_since = sim.now
	if not m.roused() and sim.now - _at_work_since > UNSEEN_MS:
		_walk_up_to = m.pos + (hero.pos - m.pos).normalized() * (m.radius + hero.radius + 1.0)
		hero.move = _walk_to(_walk_up_to)
		return
	if not sim.meets_hero(m.pos):
		# Up on the bank beside it (a dodge can carry them there): down again,
		# the nearest way onto its level.
		hero.move = Vector2.ZERO
		for k in 16:
			var dir := Vector2.from_angle((m.pos - hero.pos).angle() + float((k + 1) / 2) * (TAU / 16.0) * (1.0 if k % 2 == 0 else -1.0))
			var at := hero.pos + dir * 0.8
			if sim.meets(at, m.pos) and sim.query.standable(floori(at.x), floori(at.y)):
				hero.move = dir
				return
		# No step near onto its level (come to on a rise off its ground after a
		# down): back the way it came at it, round what stands between.
		if home.is_finite() and not _holding_out():
			hero.move = _walk_back()
		return
	if hero.move.length() < 0.05:
		return
	# Held to a ground, it will turn further to stay on it (a dodge included,
	# which goes the way the keys point: FightSim reads hero.move at the press).
	var turns: Array[float] = [0.0, 0.6, -0.6, 1.2, -1.2]
	if not keep_off.is_empty() or not keep_on.is_empty():
		turns.append_array([1.8, -1.8, 2.4, -2.4, PI])
	for turn: float in turns:
		var step := hero.move.rotated(turn)
		var at := hero.pos + step.normalized() * 0.6
		var g := sim.world.ground_at(floori(at.x), floori(at.y))
		if keep_off.has(g) or (not keep_on.is_empty() and not keep_on.has(g)):
			continue
		if sim.meets(at, m.pos) and _gets_on(step):
			hero.move = step
			return
	# Every way on is ground it keeps off (come to up a bank past the flats):
	# a player walks round, back to where they came at it from. One holding out
	# on ground (`keep_on`) holds there instead, once it is on it.
	hero.move = _walk_back() if home.is_finite() and not _holding_out() else Vector2.ZERO


## Whether a step `dir` way takes the body on at least half a step's worth: a
## player sees a bank too high to step, a rock or a wall and turns along it.
## The level check above looks 0.6 ahead of the middle and passed a step whose
## corner caught a bank two levels up beside the Reaper's den (seed 1): pressed
## into it 1.3 s with the run held, its wind sat at the run's floor under a
## dodge's cost, and every dodge was refused while three bites landed and downed
## it (test_ways, reader 2: the same frames free and locked, on main too).
func _gets_on(dir: Vector2) -> bool:
	var hero := sim.hero
	var step := dir.normalized() * GETS_ON_STEP
	var moved := sim.query.move_body(hero.pos, step, hero.radius, null, false, FightSim.HERO_TALL) - hero.pos
	return moved.dot(dir.normalized()) > GETS_ON_STEP * 0.5

const GETS_ON_STEP := 0.3


## The walk back to `home`: tiles laid once by `_route` and followed, laid again
## when the body stops getting nearer the next one.
var _route_tiles: Array[Vector2i] = []
var _route_best := INF
var _route_since := 0.0
## Tiles a walk stuck on (a prop's edge the tile grid does not know): laid round.
var _stuck_on := {}


func _walk_back() -> Vector2:
	return _walk_to(home)


## The walk to `goal` by the tiles a body passes over (`_route`), laid again when
## the goal moves a tile or the walk stops gaining.
var _route_goal := Vector2.INF


func _walk_to(goal: Vector2) -> Vector2:
	var hero := sim.hero
	if not _route_goal.is_finite() or _route_goal.distance_to(goal) > 1.0:
		_route_goal = goal
		_route_tiles.clear()
	while not _route_tiles.is_empty() and hero.pos.distance_to(_centre(_route_tiles[0])) < 0.45:
		_route_tiles.pop_front()
		_route_best = INF
	if not _route_tiles.is_empty():
		var d := hero.pos.distance_to(_centre(_route_tiles[0]))
		if d < _route_best - 0.05:
			_route_best = d
			_route_since = sim.now
		elif sim.now - _route_since > 1000.0:
			_stuck_on[_route_tiles[0]] = true
			_route_tiles.clear()
	if _route_tiles.is_empty():
		_route_tiles = _route(goal, true)
		if _route_tiles.is_empty():
			_route_tiles = _route(goal, false)
		_route_best = INF
		_route_since = sim.now
	if _route_tiles.is_empty():
		return (goal - hero.pos).normalized()
	return (_centre(_route_tiles[0]) - hero.pos).normalized()


static func _centre(t: Vector2i) -> Vector2:
	return Vector2(t) + Vector2(0.5, 0.5)


## Holding out (`keep_on`) where the fight is: it stays put rather than walk
## off. Come to far from it after a down, it walks back like anyone.
func _holding_out() -> bool:
	return not keep_on.is_empty() and sim.hero.pos.distance_to(home) < STRANDED


## Whether tile `t` is ground it walks on (keep_off / keep_on).
func _keeps(t: Vector2i) -> bool:
	var g := sim.world.ground_at(t.x, t.y)
	return not keep_off.has(g) and (keep_on.is_empty() or keep_on.has(g))


## The shortest tile path to `to` a body fits along, first tile after the one it
## stands on to the goal. `keeping`: never onto ground it keeps off from ground it
## walks on (stranded on it, the way off first). Empty when there is none near.
func _route(to: Vector2, keeping: bool) -> Array[Vector2i]:
	var hero := sim.hero
	var from := Vector2i(floori(hero.pos.x), floori(hero.pos.y))
	var goal := Vector2i(floori(to.x), floori(to.y))
	var came := {from: from}
	var edge: Array[Vector2i] = [from]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while head < edge.size() and not came.has(goal) and came.size() < 6000:
		var at: Vector2i = edge[head]
		head += 1
		for d: Vector2i in dirs:
			var n := at + d
			if came.has(n) or _stuck_on.has(n) or absi(n.x - from.x) > 40 or absi(n.y - from.y) > 40:
				continue
			if keeping and _keeps(at) and not _keeps(n):
				continue
			if not sim.query.passable(at.x, at.y, n.x, n.y, null, false, FightSim.HERO_TALL) \
					or not sim.query.body_fits(_centre(n), hero.radius, null, false, FightSim.HERO_TALL):
				continue
			came[n] = at
			edge.append(n)
	var out: Array[Vector2i] = []
	if not came.has(goal):
		return out
	var t := goal
	while t != from:
		out.push_front(t)
		t = came[t]
	return out
