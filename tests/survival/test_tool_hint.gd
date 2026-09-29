extends TestCase
## WHAT TO HOLD FOR WHAT THE GOAL WANTS (Guide.goal_wants, Survival.describe_target):
## the held tool's verb decides what a thing gives, so with the pick in hand the
## wreckage breaks for plate while the goal wants its rag. The prompt says what to
## hold for it, only while the pinned goal is short of that item.

const Fx := preload("res://tests/survival/fixture.gd")


func _holding_wanted(g: Game) -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	Story.choose(Guide.CAMP_PAID, StringName(StoryContent.PAID[Guide.CAMP_PAID].pick))
	@warning_ignore("return_value_discarded")
	Story.hear(Holding.SEEN_BURNED)
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"kit_plate", 1)


func test_the_prompt_says_what_to_hold_for_what_the_goal_wants() -> void:
	var g := Fx.flat(40, 10.0)
	_holding_wanted(g)
	eq(Guide.last_goal_key if Guide.goal(g) != "" else &"", &"holding", "the goal is beds at a holding")
	check(Guide.goal_wants(g).has(&"rag"), "and a lean-to wants a rag he does not have")
	var wreck := Fx.put(g, PropKind.WRECKAGE, Vector2(1.5, 0.0))
	Fx.face(g, wreck)
	@warning_ignore("return_value_discarded")
	Survival.hold(g, &"pick")
	var said := Survival.describe_target(g)
	check(said.begins_with("wreckage - break"), "the pick breaks it: %s" % said)
	check(said.contains("rag"), "and the prompt says how to get the rag instead: %s" % said)
	@warning_ignore("return_value_discarded")
	Survival.hold(g, &"knife")
	said = Survival.describe_target(g)
	eq(said, "wreckage - gather", "the knife held, his hands gather the rag, and nothing more is said")
	g.inventory.add(&"rag", 1)
	@warning_ignore("return_value_discarded")
	Survival.hold(g, &"pick")
	check(not Survival.describe_target(g).contains("rag"), "with a rag in the bag, no hint")
	Story.forget()
	Fx.done(g)


## The hint names an item as a plural or a mass ("for rags", "for iron"), never a
## count noun ("for piece of plate"). Every item a GOAL_MAKES goal can want is
## named here, so a goal that comes to want a new one is read before it ships.
const HINT_WORD := {&"driftwood": "driftwood", &"rag": "rags", &"scrap": "plate", &"iron": "iron"}


func test_every_item_a_goal_can_want_is_named_as_many() -> void:
	for key: StringName in Guide.GOAL_MAKES:
		var makes: Dictionary = Guide.GOAL_MAKES[key]
		var needs: Dictionary = StructureKind.ROWS[int(makes.piece)].get("cost", {}) if makes.has("piece") \
			else Crafting.recipe(StringName(makes.recipe)).get("needs", {})
		for item: StringName in needs:
			check(HINT_WORD.has(item), "%s wants %s: its hint word is decided here" % [key, item])
			if HINT_WORD.has(item):
				eq(Items.many_name(item), String(HINT_WORD[item]), "the hint says: for %s" % HINT_WORD[item])
