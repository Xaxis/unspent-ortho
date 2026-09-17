extends TestCase

static var _world: WorldData


static func _w() -> WorldData:
	if _world == null:
		_world = WorldGen.generate(5)
	return _world


func test_player_walks_and_faces_where_it_goes() -> void:
	var w := _w()
	var q := WorldQuery.new(w)
	var p := Player.new()
	p.world = w
	p.query = q
	p.pos = w.spawn
	var start := p.pos
	for i in 30:
		p.drive(Vector2(1, 0), false, 1.0 / 60.0)
	check(p.pos.x >= start.x, "moved backwards")
	near(p.facing, 0.0, 0.01, "facing east")
	p.free()


func test_never_crosses_a_cliff_however_far_it_walks() -> void:
	var w := _w()
	var q := WorldQuery.new(w)
	var p := Player.new()
	p.world = w
	p.query = q
	p.pos = w.spawn
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(0.7, 0.7), Vector2(-0.7, 0.7)]
	var prev := w.level_at(floori(p.pos.x), floori(p.pos.y))
	for i in 60 * 60:
		p.drive(dirs[(i / 90) % dirs.size()], true, 1.0 / 60.0)
		var tx := floori(p.pos.x)
		var ty := floori(p.pos.y)
		var l := w.level_at(tx, ty)
		if absi(l - prev) > 1:
			fail("crossed a cliff %d -> %d at %s" % [prev, l, p.pos])
			break
		prev = l
	p.free()


## Deep water was a wall to everything; it is a crossing now for a body that can
## swim, and the wall it always was for one that cannot (owner, 2026-09-17).
func test_deep_water_stops_what_cannot_swim_and_lets_a_swimmer_through() -> void:
	var w := WorldData.new(4, 32)
	for i in 32 * 32:
		w.level[i] = 1
		w.ground[i] = Ground.GRASS
		w.country[i] = Country.COAST
	# A channel of deep water four tiles wide, straight across the middle.
	for y in 32:
		for x in range(14, 18):
			w.ground[y * 32 + x] = Ground.DEEP_WATER
			w.level[y * 32 + x] = 0
	var q := WorldQuery.new(w)
	check(not q.standable(15, 10), "a body on its feet has no business out there")
	check(q.standable(15, 10, null, true), "a swimmer has")
	check(q.passable(13, 10, 14, 10, null, true), "and may step in from the bank")
	# Walked at the channel, a body that cannot swim is held on the near side.
	var from := Vector2(12.5, 10.5)
	var at := from
	for i in 300:
		at = q.move_body(at, Vector2(0.06, 0.0), Tuning.PLAYER_RADIUS)
	lt(at.x, 14.0, "held at the waterline, not in it: %s" % at)
	# The same walk, swimming, crosses and comes out the far side.
	at = from
	for i in 300:
		at = q.move_body(at, Vector2(0.06, 0.0), Tuning.PLAYER_RADIUS, null, true)
	gt(at.x, 18.0, "a swimmer is across and out: %s" % at)


## What it costs is time, and only time (owner's ruling): a stroke against a walk.
func test_a_stroke_is_slower_than_a_walk_and_a_wade_is_every_shallow() -> void:
	var w := WorldData.new(5, 8)
	for i in 8 * 8:
		w.level[i] = 1
		w.ground[i] = Ground.GRASS
	w.ground[1 * 8 + 1] = Ground.DEEP_WATER
	w.ground[1 * 8 + 2] = Ground.WATER
	w.ground[1 * 8 + 3] = Ground.RIVER
	w.ground[1 * 8 + 4] = Ground.BLACKWATER
	var dry := Hero.ground_speed(w, Vector2(0.5, 0.5), false)
	var deep := Hero.ground_speed(w, Vector2(1.5, 1.5), false)
	var wade := Hero.ground_speed(w, Vector2(2.5, 1.5), false)
	near(deep, Tuning.WALK_SPEED * Tuning.SWIM_FACTOR, 0.001, "a stroke is a stroke")
	near(wade, dry * Tuning.WADE_FACTOR, 0.001)
	lt(deep, wade, "and slower than a wade")
	for at: Vector2 in [Vector2(2.5, 1.5), Vector2(3.5, 1.5), Vector2(4.5, 1.5)]:
		near(Hero.ground_speed(w, at, false), dry * Tuning.WADE_FACTOR, 0.001,
			"every shallow water wades the same: %s" % Ground.NAMES[w.ground_at(floori(at.x), floori(at.y))])
	# Running is nothing in deep water: there is nothing to push against.
	near(Hero.ground_speed(w, Vector2(1.5, 1.5), true), deep, 0.001, "no running a swim")


static func _field(props: Array[Vector2], kind: int = PropKind.BROADLEAF) -> WorldQuery:
	var w := WorldData.new(3, 48)
	for i in 48 * 48:
		w.level[i] = 2
		w.ground[i] = Ground.GRASS
		w.country[i] = Country.COAST
	var q := WorldQuery.new(w)
	for p in props:
		var prop := WorldProp.new(w.props.size(), kind, p, 0.0, 1.0)
		w.props.append(prop)
		q.add_prop(prop)
	return q


## The playtest's pin: a run held north-east into a broadleaf at 211.29,400.21
## from 210.74,400.55 moved nothing for 36 seconds.
func test_a_body_pushed_diagonally_into_a_trunk_slides_round_it() -> void:
	var q := _field([Vector2(24.55, 23.66)])
	var p := Vector2(24.0, 24.0)
	var dir := Vector2(1, -1).normalized()
	var start := p
	for i in 120:
		p = q.move_body(p, dir * 5.4 / 60.0, Tuning.PLAYER_RADIUS)
	gt(p.distance_to(start), 4.0, "two seconds of running got past the trunk")
	gt((p - start).dot(dir), 3.0, "and on the way it was going")
	var trunk: WorldProp = q.world.props[0]
	gt(p.distance_to(trunk.pos), trunk.solid + Tuning.PLAYER_RADIUS - 0.01, "never inside it")


func test_head_on_into_a_boulder_still_stops() -> void:
	var q := _field([Vector2(26.0, 24.0)], PropKind.BOULDER)
	var p := Vector2(24.0, 24.0)
	for i in 120:
		p = q.move_body(p, Vector2(3.4 / 60.0, 0), Tuning.PLAYER_RADIUS)
	lt(absf(p.y - 24.0), 0.05, "square on, a body is not thrown sideways")
	var rock: WorldProp = q.world.props[0]
	gt(p.distance_to(rock.pos), rock.solid + Tuning.PLAYER_RADIUS - 0.01, "and stays outside it")


func test_a_body_slides_along_a_cliff_it_walks_into_at_an_angle() -> void:
	var q := _field([])
	for y in 48:
		q.world.level[y * 48 + 30] = 6
	var p := Vector2(28.5, 20.0)
	for i in 60:
		p = q.move_body(p, Vector2(1, 1).normalized() * 3.4 / 60.0, Tuning.PLAYER_RADIUS)
	gt(p.y - 20.0, 1.5, "slid along the wall")
	lt(p.x, 30.0, "without climbing it")


func test_screen_up_is_away_from_the_camera() -> void:
	var up := Player.screen_to_world(Vector2(0, -1), 45.0)
	check(up.x < 0.0 and up.y < 0.0, "screen up should be north-west, got %s" % up)
	var right := Player.screen_to_world(Vector2(1, 0), 45.0)
	check(right.x > 0.0 and right.y < 0.0, "screen right should be north-east, got %s" % right)


func test_clock_runs_on_real_time_not_on_walking() -> void:
	var c := WorldClock.new(8.0)
	for i in 60:
		c.advance(1.0)
	near(c.hour(), 9.0, 1e-6, "an hour of world time per real minute")
