extends TestCase
## The light index is a GRID now, and a grid is only ever as good as what it
## does not drop.
##
## `15_lights.sources` is every light in the WORLD -- 1,865 of them on seed 4 --
## and the three quarter-second passes each want the handful inside their own
## reach. They used to find them by walking the whole array, so one refresh tick
## was THREE full sweeps: measured walking seed 4 at 21:00, 3.3 ms typical and
## 8.5 ms worst, all of it in ONE frame, four times a second. Against an 8.3 ms
## budget that is one frame in fifteen given over entirely to light. With the
## grid the same walk measures 0.35 ms typical, 0.55 ms worst.
##
## **THE FAILURE A GRID MAKES IS SILENT.** A light whose cell the span does not
## reach is simply never lit, and nothing anywhere raises an error -- it looks
## like a dark house somebody meant to leave dark. So the test that matters is
## not the speed, it is that `_near` gives back exactly what the sweep it
## replaced would have found.
##
## Proved to bite both ways: with `span` forced to 0 the first test fails with
## "the grid dropped 21 lights", and with `_near` returning `sources` whole the
## second fails.

const Lights := preload("res://src/systems/15_lights.gd")


## EVERY CALLER MUST FREE WHAT THIS HANDS BACK. The Game is parented and set
## up, so its systems connect to the `Events` AUTOLOAD, which outlives the
## test. Three tests here leaked three Games and three live guide systems, and
## the damage landed on somebody ELSE: `test_guide`'s first-kill test heard the
## one kill four times and failed, 72 files later in the same shard, green on
## its own. TestCase has no teardown hook, so the free is the caller's.

func _world_with_lights() -> Array:
	var o := BootOptions.new()
	o.size = 96
	# Night, so every source a landscape has is one the passes would really want.
	o.hour = 23.0
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var lights: Node = null
	for s in g.systems:
		if s.get_script() == Lights:
			lights = s
	return [g, lights]


func test_the_grid_holds_every_light_the_sweep_would_have_found() -> void:
	var pair := _world_with_lights()
	var g: Game = pair[0]
	var lights: Node = pair[1]
	check(lights != null, "lights system")
	await frames(20)
	var all: Array = lights.get("sources")
	check(all.size() > 0, "a world with no lights in it proves nothing, got %d" % all.size())
	# Both reaches, and focuses off the spawn as well: an answer that happens to
	# be right where a cell begins is not evidence about the ones that do not.
	for reach: float in [Lights.REACH, Lights.GLOW_REACH]:
		for focus: Vector2 in [g.player.pos, g.player.pos + Vector2(19.0, -23.0), Vector2(8.5, 8.5), Vector2(64.0, 32.0)]:
			var near: Array = lights.call(&"_near", focus, reach)
			var held := {}
			for s: Dictionary in near:
				held[(s.prop as WorldProp).id] = true
			var missed := 0
			for s: Dictionary in all:
				var p: WorldProp = s.prop
				if p.pos.distance_to(focus) <= reach and not held.has(p.id):
					missed += 1
			check(missed == 0, "reach %.0f at %s: the grid dropped %d lights the sweep finds" % [reach, focus, missed])
	g.queue_free()
	await frames(1)


func test_the_grid_answers_by_PLACE_and_not_with_the_whole_world() -> void:
	# Off the island entirely. The sweep it replaced walked every source in the
	# world to answer this; the grid reads cells that hold nothing. It is also
	# the one call with negative coordinates in it, which is where a cell key
	# worked out by integer division rather than a floor would go wrong.
	var pair := _world_with_lights()
	var g: Game = pair[0]
	var lights: Node = pair[1]
	check(lights != null, "lights system")
	await frames(20)
	var all: Array = lights.get("sources")
	check(all.size() > 0, "lights to not find")
	var near: Array = lights.call(&"_near", Vector2(-400.0, -400.0), Lights.GLOW_REACH)
	check(near.is_empty(), "nowhere near the island holds no lights, got %d of %d" % [near.size(), all.size()])
	g.queue_free()
	await frames(1)


func test_a_crossing_rebuilds_the_index_instead_of_piling_a_second_world_on_it() -> void:
	# A portal points this system at the other realm's world while `sources`
	# still describes the one just left, so `realm_changed` throws the index
	# away and reads the new world. Run against the SAME world, the honest
	# proof is that re-indexing gives the same count and not twice it.
	var pair := _world_with_lights()
	var g: Game = pair[0]
	var lights: Node = pair[1]
	check(lights != null, "lights system")
	await frames(20)
	var was: int = (lights.get("sources") as Array).size()
	check(was > 0, "lights to re-index")
	lights.call(&"realm_changed", &"surface", &"underground")
	var now: int = (lights.get("sources") as Array).size()
	check(now == was, "one world re-indexed is one world's lights: was %d, now %d" % [was, now])
	var cells: Dictionary = lights.get("_cells")
	var filed := 0
	for key: int in cells.keys():
		filed += (cells[key] as Array).size()
	check(filed == now, "every source filed in exactly one cell: %d sources, %d filed" % [now, filed])
	g.queue_free()
	await frames(1)
