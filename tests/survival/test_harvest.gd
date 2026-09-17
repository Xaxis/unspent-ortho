extends TestCase
## The highlight's rule and the proportional taking (Harvest): what the use key
## would do to the thing in reach, read off the same choice the key makes, and a
## thing that is taken from in goes standing that much smaller, in view and in
## collision, through a save and back to whole when it grows back.

const Fx := preload("res://tests/survival/fixture.gd")


func test_nothing_in_reach_is_no_target() -> void:
	var g := Fx.flat()
	check(Harvest.target(g).is_empty(), "an empty field marks nothing")
	Fx.done(g)


func test_the_state_says_what_the_key_would_do() -> void:
	var g := Fx.flat()
	var drift := Fx.put(g, PropKind.DRIFTWOOD, Vector2(0.8, 0))
	var t := Harvest.target(g)
	eq(t.prop, drift, "the driftwood in front")
	eq(t.state, Harvest.WORKABLE, "gathered by hand, whatever is held")
	eq(t.item, &"driftwood")
	g.world.depleted[drift.id] = INF

	# A boulder with a knife in hand is not refused: a loose stone comes off it by
	# hand, and that is what the key would do, so that is what the mark says.
	var rock := Fx.put(g, PropKind.BOULDER, Vector2(1.0, 0.0))
	Fx.face(g, rock)
	eq(Harvest.target(g).state, Harvest.WORKABLE, "a loose stone off the boulder")
	eq(Harvest.target(g).verb, &"gather")
	g.world.depleted[rock.id] = INF

	# An iron seam with a knife in hand and a pick in the creel: the key would take the pick out.
	var iron := Fx.put(g, PropKind.IRON_ORE, Vector2(1.0, 0.0))
	Fx.face(g, iron)
	eq(Harvest.target(g).state, Harvest.NO_TOOL, "a knife does not break ore, and nothing else is carried")
	g.inventory.add(&"pick")
	var t2 := Harvest.target(g)
	eq(t2.prop, iron)
	eq(t2.state, Harvest.OTHER_TOOL, "the pick in the creel would break it")
	eq(t2.tool, &"pick")
	Survival.hold(g, &"pick")
	eq(Harvest.target(g).state, Harvest.WORKABLE, "with the pick in hand it breaks now")
	g.world.depleted[iron.id] = INF

	# An iron pick on a steel seam rings off it.
	var copper := Fx.put(g, PropKind.COPPER_ORE, Vector2(1.0, 0.0))
	Fx.face(g, copper)
	eq(Harvest.target(g).state, Harvest.TOO_HARD, "copper wants steel")
	Fx.done(g)


func test_the_mark_agrees_with_the_key() -> void:
	# Whatever the mark says, pressing the key does exactly that: WORKABLE and
	# OTHER_TOOL start work, every other state is refused.
	var kinds: Array[int] = [PropKind.DRIFTWOOD, PropKind.BOULDER, PropKind.IRON_ORE, PropKind.COPPER_ORE,
		PropKind.REEDS, PropKind.BUSH, PropKind.PINE, PropKind.WRECK, PropKind.PEAT_BANK]
	var kits: Array = [[], [&"pick"], [&"axe_hand", &"mattock"]]
	for kind in kinds:
		for kit: Array in kits:
			var g := Fx.flat()
			for id: StringName in kit:
				g.inventory.add(id)
			var p := Fx.put(g, kind, Vector2(1.0, 0.0))
			Fx.face(g, p)
			var t := Harvest.target(g)
			var label := "%s with %s" % [PropKind.NAMES[kind], kit]
			if t.is_empty():
				check(Survival.use_target(g) == null, "%s: no mark, nothing to use" % label)
			else:
				var says: bool = t.state == Harvest.WORKABLE or t.state == Harvest.OTHER_TOOL
				var did := Survival.use(g) and not SurvivalState.of(g).job.is_empty()
				eq(did, says, "%s: the mark said %s" % [label, t.state])
			Fx.done(g)


func test_a_bush_picked_bare_is_picked_over() -> void:
	var g := Fx.flat()
	var bush := Fx.put(g, PropKind.BUSH, Vector2(0.8, 0))
	check(Fx.take(g), "berries picked")
	var t := Harvest.target(g)
	eq(t.prop, bush, "still standing")
	eq(t.state, Harvest.PICKED_OVER)
	near(Harvest.shown(g, bush), 1.0, 1e-6, "picking berries leaves the bush whole")
	Fx.done(g)


func test_your_heap_is_yours() -> void:
	var g := Fx.flat()
	g.inventory.add(&"stone", 3)
	eq(Survival.drop(g, &"stone", 2), 2)
	var t := Harvest.target(g)
	check(not t.is_empty() and SurvivalState.of(g).left.has((t.prop as WorldProp).id), "the heap")
	eq(t.state, Harvest.YOURS)
	Fx.done(g)


func test_a_seam_stands_smaller_with_every_go_and_goes_on_the_last() -> void:
	var g := Fx.flat()
	g.inventory.add(&"pick")
	Survival.hold(g, &"pick")
	var seam := Fx.put(g, PropKind.STONE_ORE, Vector2(1.0, 0))
	Fx.face(g, seam)
	var scale0 := seam.scale
	var solid0 := seam.solid
	var uses := int(Takes.options(PropKind.STONE_ORE)[0].uses)
	eq(uses, 3, "a stone seam has three goes in it")
	for i in uses - 1:
		Fx.face(g, seam)
		check(Fx.take(g), "go %d" % (i + 1))
		var left := 1.0 - float(i + 1) / float(uses)
		near(Harvest.shown(g, seam), left, 1e-6, "what is left after go %d" % (i + 1))
		near(seam.scale, scale0 * Harvest.size_for(left), 1e-5, "drawn that much smaller")
		near(seam.solid, solid0 * Harvest.size_for(left), 1e-5, "and stops a body that much smaller")
		check(not g.world.depleted.has(seam.id), "still there")
	Fx.face(g, seam)
	check(Fx.take(g), "the last go")
	check(g.world.depleted.has(seam.id), "the last go takes it away")
	Fx.done(g)


func test_what_is_left_is_drawn_by_its_footprint() -> void:
	near(Harvest.size_for(1.0), 1.0, 1e-6, "whole")
	near(Harvest.size_for(0.25), 0.5, 1e-6, "a quarter left covers a quarter of the ground")
	near(Harvest.size_for(0.0), Harvest.SHOWN_LEAST, 1e-6, "never drawn to nothing")
	var last := 2.0
	for i in 11:
		var k := Harvest.size_for(1.0 - i / 10.0)
		check(k <= last, "less left is never drawn bigger")
		last = k


func test_a_take_that_keeps_the_thing_never_shrinks_it() -> void:
	var g := Fx.flat()
	g.inventory.add(&"mattock")
	Survival.hold(g, &"mattock")
	var tip := Fx.put(g, PropKind.TIP, Vector2(1.0, 0))
	Fx.face(g, tip)
	var scale0 := tip.scale
	check(Fx.take(g), "dug")
	near(Harvest.shown(g, tip), 1.0, 1e-6, "a tip dug over is still a tip")
	near(tip.scale, scale0, 1e-6)
	check(SurvivalState.of(g).base_size.is_empty(), "nothing remembered for a thing that never shrank")
	Fx.done(g)


func test_it_grows_back_to_the_size_it_was() -> void:
	var g := Fx.flat()
	var seam := Fx.put(g, PropKind.STONE_ORE, Vector2(1.0, 0))
	var scale0 := seam.scale
	var solid0 := seam.solid
	var state := SurvivalState.of(g)
	state.taken[SurvivalState.key(seam.id, 0)] = 2
	check(Harvest.apply_shown(g, seam), "shrunk")
	lt(seam.scale, scale0, "smaller")
	state.taken.clear()
	check(Harvest.apply_shown(g, seam), "restored")
	near(seam.scale, scale0, 1e-6, "its own scale again")
	near(seam.solid, solid0, 1e-6, "its own footprint again")
	check(not Harvest.apply_shown(g, seam), "nothing more to do")
	check(state.base_size.is_empty(), "forgotten once whole")
	Fx.done(g)


func test_a_half_taken_rock_comes_back_half_taken_from_a_save() -> void:
	# The same rock in two games, standing before the save's base as a generated one does.
	var g := Fx.flat()
	var h := Fx.flat()
	var a := Fx.put(g, PropKind.BOULDER, Vector2(2, 0))
	var b := Fx.put(h, PropKind.BOULDER, Vector2(2, 0))
	SaveCore.mark_base(g)
	SaveCore.mark_base(h)
	var scale0 := a.scale
	SurvivalState.of(g).taken[SurvivalState.key(a.id, 0)] = 1
	Harvest.apply_shown(g, a)
	var saved: Variant = JSON.parse_string(JSON.stringify(SaveCore.save_world(g), "", false, true))
	Fx.done(g)
	near(b.scale, scale0, 1e-6, "whole before the load")
	SaveCore.load_world(h, saved)
	near(Harvest.shown(h, b), 0.5, 1e-6, "one go of two")
	near(b.scale, scale0 * Harvest.size_for(0.5), 1e-5, "stands as it was left")
	Fx.done(h)
