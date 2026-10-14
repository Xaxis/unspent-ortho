extends TestCase
## THE FIRST STEPS (FirstSteps; owner, 2026-10-13): Maren's errand as a card of
## one-mechanic steps, in order, each with its count and key, done for good once
## done, and never skipped past a lesson by what the bag happens to hold.

const Fx := preload("res://tests/survival/fixture.gd")


func _at(g: Game, done: Dictionary) -> StringName:
	var rows := FirstSteps.list(g, done)
	var i := FirstSteps.current(rows)
	return &"" if i < 0 else StringName(rows[i].key)


func _row(g: Game, done: Dictionary, key: StringName) -> Dictionary:
	for r: Dictionary in FirstSteps.list(g, done):
		if r.key == key:
			return r
	return {}


func test_the_steps_walk_the_errand_in_order() -> void:
	Story.forget()
	var g := Fx.flat()
	var done := {}
	eq(_at(g, done), &"talk", "first: hear Maren out")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	eq(_at(g, done), &"driftwood", "her lead given: driftwood")
	g.inventory.add(&"driftwood", 2)
	var r := _row(g, done, &"driftwood")
	eq(int(r.have), 2, "counted")
	eq(int(r.need), 3, "out of three")
	eq(r.act, &"use", "with the use key")
	g.inventory.add(&"driftwood", 1)
	eq(_at(g, done), &"stones", "three in hand: stones")
	g.inventory.add(&"stone", 2)
	eq(_at(g, done), &"fire", "two stones: lay a fire")
	g.inventory.remove(&"driftwood", 3)
	g.inventory.remove(&"stone", 2)
	SurvivalState.of(g).built.append(Fx.put(g, PropKind.FIRE, Vector2(1.5, 0.0)))
	eq(_at(g, done), &"wood", "his fire laid: more wood for charcoal")
	check(bool(_row(g, done, &"stones").done), "and the stones stay done though they went into it")
	g.inventory.add(&"driftwood", 4)
	eq(_at(g, done), &"charcoal", "the wood in hand: burn charcoal")
	eq(_row(g, done, &"charcoal").act, &"craft", "with the make key")
	g.inventory.add(&"charcoal", 1)
	eq(_at(g, done), &"haft", "then a haft")
	g.inventory.add(&"haft", 1)
	eq(_at(g, done), &"plate", "then plate out of the tip")
	g.inventory.add(&"scrap", 1)
	eq(_at(g, done), &"pick", "then the pick")
	g.inventory.add(&"pick", 1)
	eq(_at(g, done), &"carry", "then find it in what is carried")
	done[&"carry"] = true
	eq(_at(g, done), &"iron", "then iron out of a slab")
	g.inventory.add(&"rebar", 1)
	eq(_at(g, done), &"survey", "then the survey")
	done[&"survey"] = true
	eq(_at(g, done), &"camp", "then out to the crew's camp")


## The wood the charcoal wants is wood after the fire: six in hand before one was
## laid counted the charcoal's wood done, and the card skipped the stones and the
## fire for "burn charcoal at your fire" with no fire to burn it at.
func test_wood_in_hand_before_a_fire_skips_nothing() -> void:
	Story.forget()
	var g := Fx.flat()
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"driftwood", 6)
	eq(_at(g, {}), &"stones", "six driftwood and no fire: still the stones, then the fire")


func test_a_step_once_done_stays_done() -> void:
	Story.forget()
	var g := Fx.flat()
	var done := {}
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"driftwood", 3)
	eq(_at(g, done), &"stones", "three driftwood: the first step done")
	g.inventory.remove(&"driftwood", 3)
	eq(_at(g, done), &"stones", "and spent, it is still done")


func test_a_page_opened_early_skips_no_lesson() -> void:
	Story.forget()
	var g := Fx.flat()
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	var done := {&"carry": true, &"survey": true}
	eq(_at(g, done), &"driftwood", "the carry page and the survey opened first teach nothing before them")


func test_a_target_is_the_nearest_still_there() -> void:
	Story.forget()
	var g := Fx.flat()
	var near := Fx.put(g, PropKind.DRIFTWOOD, Vector2(2.0, 0.0))
	var far := Fx.put(g, PropKind.DRIFTWOOD, Vector2(6.0, 0.0))
	var row := {"target": &"driftwood"}
	eq(FirstSteps.target_at(g, row, {}, Vector2.INF), near.pos, "the nearest driftwood")
	near.picked = true
	eq(FirstSteps.target_at(g, row, {}, Vector2.INF), far.pos, "a strand already taken is passed over")
	eq(FirstSteps.target_at(g, {"target": &"maren"}, {}, Vector2(9, 9)), Vector2(9, 9), "Maren where she stands")
	eq(FirstSteps.target_at(g, {"target": &"camp"}, {&"the_camp": {"pos": Vector2(40, 3)}}, Vector2.INF), Vector2(40, 3), "the camp where the story placed it")
	check(not FirstSteps.target_at(g, {"target": &""}, {}, Vector2.INF).is_finite(), "nothing to point at for a step done anywhere")


## While the card runs it is the curriculum: the errand's goal is not said again
## in words over it, nor a lesson it teaches by its own key; how to walk, and
## what a machine in view makes urgent, still are.
func test_the_card_is_said_once_not_twice() -> void:
	Story.forget()
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	var guide: Node = g.get_node("58_guide")
	var said: Array[String] = []
	var listen := func(t: String, _key: String) -> void: said.append(t)
	Events.hint.connect(listen)
	for i in 12:
		guide.call("_process", 1.0)
	check(bool(guide.call(&"steps_on")), "the card is up")
	check(not said.has(Guide.goal(g)), "her errand is not said over it: %s" % [said])
	for line in said:
		check(not line.contains("takes what is in front of you"), "nor the take lesson the card teaches: %s" % line)
	check(said.any(func(l: String) -> bool: return l.contains("walks")), "how to walk is: %s" % [said])
	Events.hint.disconnect(listen)
	g.queue_free()
	await frames(1)
	Story.forget()
