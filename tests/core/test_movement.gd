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
