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


func test_never_enters_deep_water_or_crosses_a_cliff() -> void:
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
		check(w.ground_at(tx, ty) != Ground.DEEP_WATER, "in deep water at %s" % p.pos)
		var l := w.level_at(tx, ty)
		if absi(l - prev) > 1:
			fail("crossed a cliff %d -> %d at %s" % [prev, l, p.pos])
			break
		prev = l
	p.free()


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
