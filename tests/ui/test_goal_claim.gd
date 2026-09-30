extends TestCase
## `goal:KEY` (90_ui.tour_seen, Guide.last_goal_key): a tour claims WHICH goal is
## pinned by its key, not its words, which change with the story and the fire.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_pinned_goal_is_claimed_by_its_key() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	var ui := Sx.system(g, "90_ui")
	# Her lead given, charcoal in hand by the village fire: the want is the haft.
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"charcoal", 2)
	await tree.create_timer(0.8).timeout
	eq(Guide.goal(g), String(StoryContent.LEAD[&"haft"]), "the haft is what is wanted")
	check(bool(ui.call(&"tour_seen", &"goal:haft")), "and the pinned goal is claimed as the haft")
	check(not bool(ui.call(&"tour_seen", &"goal:pick")), "not as another")
	Sx.end(g)
	Story.forget()
