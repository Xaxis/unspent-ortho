extends TestCase
## Stations, recipes, building, mending.

const Fx := preload("res://tests/survival/fixture.gd")
const STATIONS: Array[StringName] = [&"hand", &"fire", &"bench", &"kiln", &"wheel", &"loom"]


func test_every_recipe_is_well_formed() -> void:
	var ids := {}
	for r: Dictionary in Recipes.LIST:
		check(not ids.has(r.id), "duplicate recipe %s" % r.id)
		ids[r.id] = true
		check(STATIONS.has(r.at), "%s at unknown station %s" % [r.id, r.at])
		gt(r.minutes, 0.0, "%s takes time" % r.id)
		for group: String in ["needs", "makes", "keeps"]:
			var d: Dictionary = r.get(group, {})
			for id: StringName in d:
				check(not Items.def(id).is_empty(), "%s %s unknown item %s" % [r.id, group, id])
				gt(int(d[id]), 0, "%s %s count" % [r.id, id])
		var shape := int(not (r.makes as Dictionary).is_empty()) + int(r.has("builds")) + int(r.has("action"))
		eq(shape, 1, "%s makes, builds or mends: exactly one" % r.id)
		if r.has("tool"):
			check(Takes.TOOL_VERBS.has(r.tool), "%s tool verb" % r.id)


func test_every_made_tool_has_a_recipe_and_the_top_rung_stays_found() -> void:
	var made := {}
	for r: Dictionary in Recipes.LIST:
		for id: StringName in r.makes:
			made[id] = true
	for id: StringName in Items.DEFS:
		var d: Dictionary = Items.DEFS[id]
		if d.get("group", &"") == &"tool" and id != &"axe_works":
			check(made.has(id), "no way to make %s" % id)
		if d.get("group", &"") == &"found":
			check(not made.has(id), "found things are never made: %s" % id)
	check(not made.has(&"axe_works"), "the fine axe is never made")


func test_recipes_at_lists_by_station() -> void:
	for s: StringName in [&"hand", &"fire", &"bench", &"kiln"]:
		gt(Crafting.recipes_at(s).size(), 0, "recipes at %s" % s)
	eq(Crafting.recipes_at(&""), Crafting.recipes_at(&"hand"), "&\"\" means anywhere")
	eq(Crafting.recipe(&"charcoal").at, &"fire")
	check(Crafting.recipe(&"nope").is_empty())


func test_build_a_campfire_from_driftwood_and_stone() -> void:
	var g := Fx.flat()
	eq(Survival.station_near(g), &"", "no station on an open field")
	check(Survival.build_fire(g) == null, "nothing to build with")
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	eq(Survival.describe_target(g), "campfire - build?")
	var t0 := g.clock.minutes
	var props_before := g.world.props.size()
	var fire := Survival.build_fire(g)
	check(fire != null, "built")
	eq(fire.kind, PropKind.FIRE)
	eq(g.world.props.size(), props_before + 1, "a new prop in the world")
	eq(g.world.props[fire.id], fire, "id is its index")
	eq(g.inventory.count(&"driftwood"), 0)
	eq(g.inventory.count(&"stone"), 0)
	near(g.clock.minutes - t0, float(Crafting.recipe(&"campfire").minutes), 0.001, "building takes time")
	eq(Survival.station_near(g), &"fire")
	check(g.query.nearest_prop(fire.pos, 0.5) == fire, "in the query: it blocks and it is found")
	var level := g.world.level_at(floori(g.player.pos.x), floori(g.player.pos.y))
	eq(g.world.level_at(floori(fire.pos.x), floori(fire.pos.y)), level, "on flat ground")
	Fx.done(g)


func test_a_screen_that_only_holds_the_inventory_can_still_build() -> void:
	var g := Fx.flat()
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	var r := Crafting.recipe(&"campfire")
	check(not Crafting.make(g.inventory, r), "no game bound: no world to build in")
	eq(g.inventory.count(&"driftwood"), 3, "nothing spent")
	Crafting.bind(g)
	var t0 := g.clock.minutes
	check(Crafting.make(g.inventory, r), "built through make")
	eq(Survival.station_near(g), &"fire")
	near(g.clock.minutes, t0, 0.001, "make leaves the minutes to its caller")
	check(not Crafting.make(Inventory.new(), r), "another inventory is not the bound game's")
	Crafting.bind(null)
	Fx.done(g)


func test_no_fire_on_water_or_a_slope() -> void:
	var g := Fx.flat()
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	var w := g.world
	var c := Vector2i(floori(g.player.pos.x), floori(g.player.pos.y))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if dx != 0 or dy != 0:
				var i := (c.y + dy) * w.size + c.x + dx
				w.ground[i] = Ground.WATER if (dx + dy) % 2 == 0 else Ground.GRASS
				w.level[i] = 1 if (dx + dy) % 2 == 0 else 4
	check(Survival.build_fire(g) == null, "no flat dry spot")
	eq(g.inventory.count(&"driftwood"), 3, "nothing spent")
	Fx.done(g)


func test_charcoal_at_a_fire_charges_its_minutes() -> void:
	var g := Fx.flat()
	g.inventory.add(&"driftwood", 4)
	var r := Crafting.recipe(&"charcoal")
	check(Crafting.can_make(g.inventory, r), "the creel has it")
	eq(Crafting.why_not(g, r), "Not without a fire.")
	check(not Crafting.make_in(g, r), "no fire here")
	Survival.build(g, &"fire", true)
	eq(Crafting.why_not(g, r), "")
	var t0 := g.clock.minutes
	check(Crafting.sets_going(r), "charcoal is longer than a jump of the clock: it cooks while you walk")
	check(Crafting.make_in(g, r), "set going")
	eq(g.inventory.count(&"driftwood"), 0, "the wood went on the fire")
	eq(g.inventory.count(&"charcoal"), 0, "nothing out yet")
	near(g.clock.minutes - t0, Survival.SET_GOING_MINUTES, 0.001, "setting it going is a few minutes, not the whole burn")
	eq(Survival.cooking(g).size(), 1, "the fire holds the work")
	g.inventory.add(&"driftwood", 4)
	check(Crafting.why_not(g, r).begins_with("The fire is working"), "one thing on a fire at a time: %s" % Crafting.why_not(g, r))
	# Walk off and come back after it is done.
	var home := g.player.pos
	g.player.pos += Vector2(8, 0)
	g.clock.skip(float(r.minutes))
	Survival.tick(g, 0.0)
	eq(g.inventory.count(&"charcoal"), 0, "away from the fire nothing comes")
	g.player.pos = home
	Survival.tick(g, 0.0)
	eq(g.inventory.count(&"charcoal"), 2, "back at it, the charcoal is taken")
	eq(Survival.cooking(g).size(), 0, "and the fire is free")
	eq(Crafting.why_not(g, r), "")
	Fx.done(g)


func test_a_haft_needs_a_blade() -> void:
	var inv := Inventory.new()
	inv.add(&"driftwood", 2)
	var r := Crafting.recipe(&"haft")
	check(not Crafting.can_make(inv, r), "no blade")
	inv.add(&"knife")
	check(Crafting.can_make(inv, r), "a knife whittles")
	check(Crafting.make(inv, r))
	eq(inv.count(&"haft"), 1)


func test_a_made_tool_goes_in_empty_hands_but_not_over_a_different_tool() -> void:
	var inv := Inventory.new()
	inv.add(&"scrap")
	inv.add(&"haft")
	inv.add(&"charcoal")
	check(Crafting.make(inv, Crafting.recipe(&"pick_made")))
	eq(inv.held, &"pick", "empty hands take it")
	inv.add(&"knife")
	inv.set_held(&"knife")
	inv.add(&"iron")
	inv.add(&"haft")
	inv.add(&"charcoal", 2)
	check(Crafting.make(inv, Crafting.recipe(&"axe_iron")))
	eq(inv.held, &"knife", "the knife stays in hand")


func test_hone_to_six_tenths_and_reedge_at_a_fire_to_new() -> void:
	var g := Fx.flat()
	var sharpen := Crafting.recipe(&"sharpen")
	eq(Crafting.why_not(g, sharpen), "Not without what it needs.", "needs a hone")
	g.inventory.add(&"stone")
	check(Crafting.make_in(g, Crafting.recipe(&"hone")), "a hone from a stone")
	eq(g.inventory.count(&"hone"), 1)
	check(Survival.hone(g), "honed")
	eq(g.inventory.edge(&"knife"), 6000, "5000 + 2500 caps at 6000")
	eq(g.inventory.count(&"hone"), 1, "the hone is kept")
	check(not Survival.hone(g), "no keener by hand")
	g.inventory.add(&"charcoal")
	check(not Survival.reedge(g), "re-edging needs a fire")
	Survival.build(g, &"fire", true)
	g.inventory.remove(&"hone")
	g.inventory.set_edge(&"knife", 4000)
	check(Crafting.make_in(g, Crafting.recipe(&"sharpen_fire")), "a fire's stone hones without a hone")
	eq(g.inventory.edge(&"knife"), 6000)
	check(Survival.reedge(g), "re-edged")
	eq(g.inventory.edge(&"knife"), 10000)
	eq(g.inventory.count(&"charcoal"), 0)
	Fx.done(g)


func test_found_tools_are_never_mended() -> void:
	var inv := Inventory.new()
	inv.add(&"las_hand")
	inv.set_held(&"las_hand")
	inv.set_edge(&"las_hand", 1000)
	inv.add(&"hone")
	check(not Crafting.can_make(inv, Crafting.recipe(&"sharpen")))


func test_cementation_eats_the_knife_and_gives_steel_in_hand() -> void:
	var g := Fx.flat()
	g.inventory.add(&"charcoal", 4)
	Survival.build(g, &"kiln", true)
	eq(Survival.station_near(g), &"kiln")
	var t0 := g.clock.minutes
	var r := Crafting.recipe(&"knife_cemented")
	check(Crafting.make_in(g, r))
	check(not g.inventory.has(&"knife"))
	near(g.clock.minutes - t0, Survival.SET_GOING_MINUTES, 0.001, "set going in the kiln")
	g.clock.skip(float(r.minutes))
	Survival.tick(g, 0.0)
	eq(g.inventory.held, &"knife_shear", "the steel knife comes out into the hand")
	Fx.done(g)


func test_no_making_jumps_the_clock_more_than_half_an_hour() -> void:
	for r: Dictionary in Recipes.LIST:
		if Crafting.sets_going(r):
			continue
		lt(float(r.minutes), Survival.MAX_JUMP_MINUTES + 0.01, "%s jumps the clock %s minutes" % [r.id, r.minutes])
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			lt(float(o.min), Survival.MAX_JUMP_MINUTES + 0.01, "%s %s takes %s minutes" % [PropKind.NAMES[kind], o.verb, o.min])


func test_nothing_is_made_with_a_hunter_close() -> void:
	var g := Fx.flat()
	var sim := FightSim.new(g.world, g.query)
	sim.hero.pos = g.player.pos
	g.player.sim = sim
	g.inventory.add(&"driftwood", 2)
	var r := Crafting.recipe(&"haft")
	eq(Crafting.why_not(g, r), "")
	var runner := sim.add_mob(&"runner", g.player.pos + Vector2(5, 0))
	eq(Crafting.why_not(g, r), Survival.THREAT_LINE, "refused with a runner five tiles off")
	var t0 := g.clock.minutes
	check(not Crafting.make_in(g, r), "and make_in makes nothing")
	eq(g.inventory.count(&"driftwood"), 2, "nothing spent")
	near(g.clock.minutes, t0, 0.001, "no time passes")
	runner.pos = g.player.pos + Vector2(12, 0)
	eq(Crafting.why_not(g, r), "", "far off, it may be made")
	var worker := sim.add_mob(&"harvester", g.player.pos + Vector2(4, 0))
	eq(Crafting.why_not(g, r), "", "a worker on its round is no threat")
	worker.disturbed = true
	worker.set_mood(MobState.ATTACKING, 0.0)
	eq(Crafting.why_not(g, r), Survival.THREAT_LINE, "a roused one is")
	g.player.sim = null
	Fx.done(g)


func test_a_house_is_a_bench() -> void:
	var g := Fx.flat()
	Fx.put(g, PropKind.HOUSE, Vector2(2.4, 0))
	var s := Survival.stations_near(g)
	check(s.has(&"bench"), "bench in a house: %s" % [s])
	check(not s.has(&"fire"), "a campfire is still yours to build")
	eq(s[-1], &"hand")
	Fx.done(g)


func test_suggest_prefers_a_first_tool() -> void:
	var g := Fx.flat()
	Survival.build(g, &"fire", true)
	g.inventory.add(&"driftwood", 6)
	g.inventory.add(&"scrap")
	g.inventory.add(&"haft")
	g.inventory.add(&"charcoal")
	eq(Crafting.suggest(g).get("id", &""), &"pick_made", "a pick before more charcoal")
	Fx.done(g)


func test_kit_is_worn_one_piece_at_a_time_and_the_rig_carries_more() -> void:
	var inv := Inventory.new()
	near(inv.creel(), 40.0, 0.001)
	inv.add(&"kit_rig")
	check(inv.wears(&"rig"), "the first piece goes on")
	near(inv.creel(), 60.0, 0.001, "a rig carries twenty more")
	inv.add(&"kit_plate")
	check(inv.wears(&"rig") and not inv.wears(&"plate"), "one piece at a time")
	check(inv.wear_kit(&"kit_plate"))
	check(inv.wears(&"plate") and not inv.wears(&"rig"))
	near(inv.creel(), 40.0, 0.001)
	check(not inv.wear_kit(&"stone"), "stone is not kit")
	inv.remove(&"kit_plate")
	check(not inv.wears(&"plate"), "taken off when gone")


func test_no_two_items_share_a_name() -> void:
	var seen := {}
	for id: StringName in Items.DEFS:
		var n := Items.display_name(id)
		check(not seen.has(n), "%s and %s are both called %s" % [seen.get(n, ""), id, n])
		seen[n] = id
