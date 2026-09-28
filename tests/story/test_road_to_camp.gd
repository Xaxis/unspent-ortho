extends TestCase
## THE ROAD TO THE CAMP (ROADMAP slice 2, step 1): Maren's lead sends him to the
## crew with iron. Once she has given it the survey marks their camp where the
## story cast it (StoryContent.TOLD), and with iron in the bag the goal is the
## crew (Guide.camp_goal) until he has spoken to Rook there.

const Sx := preload("res://tests/save/save_fixture.gd")


func _camp(g: Game) -> Vector2:
	for sys: Node in g.systems:
		if sys.name == "49_cast":
			var placed: Dictionary = sys.get("placed")
			if placed.has(&"the_camp"):
				return placed[&"the_camp"].pos
	return Vector2.INF


func test_her_lead_marks_the_camp_and_the_iron_goes_there() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	var line := String(StoryContent.LEAD.get(&"camp", "<no camp line>"))
	check(_camp(g) != Vector2.INF, "the story casts the crew's camp on the home coast")
	check(UiMapScreen.told(g).is_empty(), "before her lead the survey marks no camp")
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"iron_ore", 1)
	check(Guide.goal(g) != line, "and iron alone is no reason to look for the crew")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	var told := UiMapScreen.told(g)
	eq(told.size(), 1, "once she has sent him, the survey marks one place")
	if told.size() == 1:
		eq(Vector2(told[0].at), _camp(g), "the camp, where the story cast it")
		eq(String(told[0].word), String(StoryContent.TOLD[Guide.LEAD_BEAT].word), "lettered with her word for it")
	eq(Guide.goal(g), line, "and with iron in the bag the want is the crew who pay for it")
	g.inventory.remove(&"iron_ore", 1)
	check(Guide.goal(g) != line, "without iron there is nothing to take them yet")
	g.inventory.add(&"iron", 1)
	eq(Guide.goal(g), line, "worked iron does as well")
	@warning_ignore("return_value_discarded")
	Story.meet(Guide.CAMP_MET)
	check(Guide.goal(g) != line, "and once he has spoken to Rook at the camp, that want is met")
	Sx.end(g)
	Story.forget()


func test_a_place_off_the_glass_is_pinned_at_its_edge_on_its_bearing() -> void:
	var r := Rect2i(0, 0, 200, 100)
	eq(UiMapScreen.pin(Vector2i(100, 50), Vector2i(150, 60), r), Vector2i(150, 60), "on the glass, where it is")
	eq(UiMapScreen.pin(Vector2i(100, 50), Vector2i(-900, 50), r), Vector2i(0, 50), "due west and far, at the west edge")
	eq(UiMapScreen.pin(Vector2i(100, 50), Vector2i(100 - 400, 50 - 200), r), Vector2i(0, 0), "north-west on the corner's line, at the corner")
	var p := UiMapScreen.pin(Vector2i(100, 50), Vector2i(100, 5000), r)
	eq(p, Vector2i(100, 99), "due south, at the south edge below the player")
