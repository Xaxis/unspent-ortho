extends TestCase
## The tracks system on a world of ground (53_tracks): a body walked across sand
## leaves a trail of prints behind it, rock keeps nothing, a board lying on the
## sand is never printed into, a mark wears away in world time and faster under
## the weather that fills it, and a crossing leaves the old world's prints behind.

const Fx := preload("res://tests/survival/fixture.gd")


func _world(ground: int) -> Game:
	var g := Fx.flat(40, 10.0)
	for i in g.world.ground.size():
		if g.world.level[i] > 0:
			g.world.ground[i] = ground
	return g


func _system(g: Game) -> Node:
	var sys: Node = load("res://src/systems/53_tracks.gd").new()
	sys.setup(g)
	return sys


func _walk(g: Game, sys: Node, dir: Vector2, tiles: float) -> void:
	var frame := 1.0 / 60.0
	var speed := 3.4
	var gone := 0.0
	while gone < tiles:
		g.player.pos += dir * speed * frame
		gone += speed * frame
		sys.call("step", frame)


func test_a_walk_across_sand_leaves_a_trail_behind() -> void:
	var g := _world(Ground.SAND)
	var sys := _system(g)
	var start := g.player.pos
	_walk(g, sys, Vector2.RIGHT, 6.0)
	var live: Array = sys.get("live")
	gt(float(live.size()), 5.0, "a print every step: %d" % live.size())
	for mk: Dictionary in live:
		eq(mk.ground, Ground.SAND)
		eq(mk.shape, TrackPath.SHAPE_FOOT)
		check(mk.at.x >= start.x - 0.2 and mk.at.x <= g.player.pos.x + 0.1, "behind the body, along the way it came")
	check(sys.call("tour_seen", &"tracks:sand"), "a tour sees it")
	sys.free()
	Fx.done(g)


func test_rock_keeps_nothing_and_grass_only_bends() -> void:
	var g := _world(Ground.ROCK)
	var sys := _system(g)
	_walk(g, sys, Vector2.RIGHT, 6.0)
	eq((sys.get("live") as Array).size(), 0, "rock keeps no mark")
	check(sys.call("tour_seen", &"no_tracks"))
	sys.free()
	Fx.done(g)
	var h := _world(Ground.GRASS)
	var gs := _system(h)
	_walk(h, gs, Vector2.DOWN, 5.0)
	var live: Array = gs.get("live")
	gt(float(live.size()), 3.0)
	eq(live[0].shape, TrackGround.FLATTEN, "a boot on grass only bends it")
	gs.free()
	Fx.done(h)


func test_nothing_is_pressed_into_a_thing_lying_on_the_ground() -> void:
	var g := _world(Ground.SAND)
	var board := Survival.add_prop(g, PropKind.DRIFTWOOD, g.player.pos + Vector2(2.0, 0.0))
	var sys := _system(g)
	_walk(g, sys, Vector2.RIGHT, 4.0)
	for mk: Dictionary in sys.get("live"):
		gt((mk.at as Vector2).distance_to(board.pos), maxf(board.solid, 0.3), "no print on the driftwood")
	sys.free()
	Fx.done(g)


func test_a_print_wears_away_in_world_time_and_faster_in_what_fills_it() -> void:
	var g := _world(Ground.SNOW)
	var sys := _system(g)
	_walk(g, sys, Vector2.RIGHT, 4.0)
	var n := (sys.get("live") as Array).size()
	gt(float(n), 2.0, "prints in the snow")
	Weather.force(&"clear", 0.0)
	g.clock.minutes += 60.0
	sys.call("wear")
	eq((sys.get("live") as Array).size(), n, "an hour on a still day: all still there")
	var faded: float = (sys.get("live") as Array)[0].wear
	gt(faded, 0.0, "but worn a little")
	Weather.force(&"snow", 1.0)
	g.clock.minutes += 60.0
	sys.call("wear")
	eq((sys.get("live") as Array).size(), 0, "an hour of snowfall fills them in")
	Weather.unforce()
	check(sys.call("tour_seen", &"no_tracks"))
	sys.free()
	Fx.done(g)


func test_a_crossing_leaves_the_old_worlds_prints_behind() -> void:
	var g := _world(Ground.ASH)
	var sys := _system(g)
	_walk(g, sys, Vector2.RIGHT, 4.0)
	gt(float((sys.get("live") as Array).size()), 0.0)
	sys.call("realm_changed", &"surface", &"underground")
	eq((sys.get("live") as Array).size(), 0, "none carried across")
	sys.free()
	Fx.done(g)
