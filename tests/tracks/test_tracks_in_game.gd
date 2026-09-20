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


## THE FIRST FOOTFALL USED TO BUILD THE THING IT NEEDED, AND IT COST 15.2 ms.
##
## `TrackMarks.warm()` builds every mark's TEXTURES, and was written because a
## lazily built mark is a hitch with a delay on it. `lay` has a SECOND lazy build
## beside them that the warm never reached: `_groups`, a MultiMesh and a
## `StandardMaterial3D` per shape|white|rough. That material is a shader variant
## (alpha, normal map, vertex-colour albedo) and the first group of a run is what
## compiles it -- measured walking seed 4, **15.2 ms in the frame the player took
## their first step**, with every other lay of a 700-frame run under 1 ms.
##
## setup() warms the group for the ground underfoot now. **The failure this
## really guards is a warm-up that builds the WRONG group**: `foot_shape` has to
## return the shape `_lay` will go on to ask for, or the warm is a green light
## over the exact hitch it exists to remove. So one ground of each mark kind --
## a PRINT keeps the foot's own shape, a SCUFF and a FLATTEN replace it.
func test_the_first_footfall_finds_its_group_already_built() -> void:
	for ground: int in [Ground.SAND, Ground.SHINGLE, Ground.GRASS]:
		var g := _world(ground)
		var sys := _system(g)
		var groups: Dictionary = sys.get("marks").get("_groups")
		var before := groups.size()
		gt(float(before), 0.0, "setup warms a group for the ground underfoot (%d)" % ground)
		_walk(g, sys, Vector2.RIGHT, 3.0)
		# Without this the test passes on a ground that keeps nothing, which is
		# the escape hatch that makes a green light mean nothing at all.
		check(not (sys.get("live") as Array).is_empty(), "ground %d really laid marks" % ground)
		eq(groups.size(), before,
			"walking on %d built a group setup should already have: %s" % [ground, str(groups.keys())])
