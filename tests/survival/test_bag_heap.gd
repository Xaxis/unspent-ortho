extends TestCase
## CARRIED OFF COSTS PLACE AS WELL AS TIME (mechanics improvement 4a;
## Survival.leave_bag). What the player carried stays on a heap where they were
## taken; what is on the body stays on it; the heap is marked on the survey and
## carries the player's own rag in the world; `use` takes it all back; and a
## save keeps it. Losing the bag is a walk back the player can see, never a
## loss they cannot.

const Sx := preload("res://tests/save/save_fixture.gd")


func _game() -> Game:
	Sx.use_root("bag-heap")
	return Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--give=knife:1,driftwood:6,stone:4,lamp:1,oil:2,kit_rig:1", "--held=knife"])


## A bad end, as 40_fight has it: the fight's outcome for the player carried off.
func _carried_off(g: Game) -> void:
	var fight := Sx.system(g, "40_fight")
	fight.call("_on_outcome", {"outcome": &"carried"})


func test_carried_off_leaves_the_bag_where_it_took_you_and_keeps_what_is_on_you() -> void:
	var g := _game()
	var inv := g.inventory
	inv.wear_kit(&"kit_rig")
	var taken_at := g.player.pos
	var had := inv.items.duplicate()
	var lines: Array[String] = []
	var said := func(t: String) -> void: lines.append(t)
	Events.message.connect(said)
	_carried_off(g)
	Events.message.disconnect(said)
	var state := SurvivalState.of(g)
	eq(state.bags.size(), 1, "one heap left by the bad end")
	var heap: WorldProp = g.world.props[state.bags.keys()[0]]
	lt(heap.pos.distance_to(taken_at), 1.6, "where they were taken (%.2f tiles off)" % heap.pos.distance_to(taken_at))
	gt(g.player.pos.distance_to(heap.pos), 0.0, "and the player woke somewhere else")
	eq(heap.variant, PropModels.BAG_CAIRN, "under the player's own rag")
	var goods: Dictionary = state.left[heap.id]
	eq(int(goods.get(&"driftwood", 0)), 6, "the driftwood is on it")
	eq(int(goods.get(&"stone", 0)), 4, "and the stone")
	eq(int(goods.get(&"lamp", 0)), int(had.get(&"lamp", 0)), "and the lamp")
	eq(inv.count(&"knife"), 1, "the knife in the hand stayed in it")
	eq(inv.held, &"knife", "held")
	eq(inv.count(&"kit_rig"), 1, "the kit worn stayed on")
	eq(inv.count(&"driftwood"), 0, "nothing else came with them")
	check(lines.has(Survival.BAG_LINE), "and they were told so in words: %s" % [lines])
	eq(Guide.goal(g), Guide.BAG_GOAL, "and it stands as the goal until they have them back")
	# The survey marks it.
	var marked := UiMapScreen.bags(g)
	eq(marked.size(), 1, "the survey has one bag mark")
	if marked.size() == 1:
		lt(marked[0].distance_to(heap.pos), 0.01, "on the heap")
	# And it all comes back.
	g.player.pos = heap.pos + Vector2(0.9, 0.0)
	eq(Survival.heap_near(g), heap, "stood by it, it is the heap in reach")
	var left_n := 0
	for k: Variant in goods:
		if not String(k).begins_with("edge:"):
			left_n += int(goods[k])
	var carried_n := 0
	for k: Variant in had:
		carried_n += int(had[k])
	eq(left_n, carried_n - 2, "all of it but the knife and the rig was left")
	var got := Survival.take_back(g, heap)
	eq(got, left_n, "everything that was left came back")
	eq(inv.count(&"driftwood"), 6, "the driftwood")
	eq(state.bags.size(), 0, "and the mark is gone with the heap")
	eq(UiMapScreen.bags(g).size(), 0, "from the survey too")
	check(Guide.goal(g) != Guide.BAG_GOAL, "and the goal goes back to the day's own")
	Sx.end(g)
	Sx.finish()


func test_a_save_keeps_the_heap_and_what_is_on_it() -> void:
	var g := _game()
	_carried_off(g)
	var state := SurvivalState.of(g)
	var id: int = state.bags.keys()[0]
	var at: Vector2 = g.world.props[id].pos
	var saver := Sx.system(g, "05_save")
	# Clear of the machines a save would wait out, as a player who walked off would be.
	Sx.system(g, "30_mobs").get("coast").set("spawning", false)
	g.player.sim.clear_mobs()
	# Up off the ground: the wake after a bad end is a moment of lying there.
	g.body.busy_until = 0.0
	await frames(4)
	eq(saver.call("save_to", 1), "", "saved")
	Sx.end(g)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "slot 1 boots")
	var b := Sx.game(tree, [], o)
	var s2 := SurvivalState.of(b)
	eq(s2.bags.size(), 1, "the bag heap is still a bag heap")
	if s2.bags.size() == 1:
		var id2: int = s2.bags.keys()[0]
		var heap: WorldProp = b.world.props[id2]
		lt(heap.pos.distance_to(at), 0.01, "where it was")
		eq(heap.variant, PropModels.BAG_CAIRN, "under the rag")
		eq(int((s2.left[id2] as Dictionary).get(&"driftwood", 0)), 6, "with the driftwood on it")
	Sx.end(b)
	Sx.finish()


## Put down or carried off, the network where it happened files it: the price of
## a bad end is place, time, and the region looking harder for you after.
func test_a_bad_end_is_filed_against_the_region_it_happened_in() -> void:
	var g := _game()
	var disp := Sx.system(g, "32_disposition")
	var inter: Interference = disp.get("interference")
	var net := Interference.network(g.world, g.player.pos)
	var before := inter.value(net)
	var fight := Sx.system(g, "40_fight")
	fight.call("_on_outcome", {"outcome": &"downed"})
	var after := inter.value(net)
	gt(after - before, Interference.CAUSES[&"downed"] - 0.001, "downed files %.2f against the region (%.3f to %.3f)" % [Interference.CAUSES[&"downed"], before, after])
	Sx.end(g)
	Sx.finish()


func test_no_cairn_world_gen_lays_is_drawn_as_a_bag() -> void:
	for h in 4000:
		lt(float(PropModels.pick_variant(PropKind.CAIRN, h * 7919 - 20000)), float(PropModels.BAG_CAIRN), "a dealt cairn is one of the dealt three")
		if PropModels.pick_variant(PropKind.CAIRN, h * 7919 - 20000) >= PropModels.BAG_CAIRN:
			break
