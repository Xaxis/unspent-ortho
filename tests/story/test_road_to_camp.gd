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
	Story.meet(&"rook")
	eq(Guide.goal(g), line, "met, not yet paid: the promise still stands")
	Story.choose(&"rook.iron", StringName(StoryContent.PAID[&"rook.iron"].pick))
	check(Guide.goal(g) != line, "and once the crew have paid for the iron, that want is met")
	Sx.end(g)
	Story.forget()


func test_a_place_off_the_glass_is_pinned_at_its_edge_on_its_bearing() -> void:
	var r := Rect2i(0, 0, 200, 100)
	eq(UiMapScreen.pin(Vector2i(100, 50), Vector2i(150, 60), r), Vector2i(150, 60), "on the glass, where it is")
	eq(UiMapScreen.pin(Vector2i(100, 50), Vector2i(-900, 50), r), Vector2i(0, 50), "due west and far, at the west edge")
	eq(UiMapScreen.pin(Vector2i(100, 50), Vector2i(100 - 400, 50 - 200), r), Vector2i(0, 0), "north-west on the corner's line, at the corner")
	var p := UiMapScreen.pin(Vector2i(100, 50), Vector2i(100, 5000), r)
	eq(p, Vector2i(100, 99), "due south, at the south edge below the player")


func _offer(t: StoryTalk) -> int:
	var rs := t.replies()
	for k in rs.size():
		if not (rs[k].get("has", []) as Array).is_empty():
			return k
	return -1


## Maren's lead kept: at the camp Rook takes the iron and pays in plate
## (StoryContent.PAID), and the want becomes the plate armour it is for.
func test_the_crew_pay_for_the_iron_in_plate_for_armour() -> void:
	Story.forget()
	var bare := StoryTalk.start(&"rook")
	eq(_offer(bare), -1, "a talk that cannot see the bag offers no iron")
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	var t := StoryTalk.start(&"rook")
	t.holds = g.inventory.has
	eq(_offer(t), -1, "with no iron in the bag, nothing to sell")
	g.inventory.add(&"iron_ore", 1)
	var scrap := g.inventory.count(&"scrap")
	var k := _offer(t)
	check(k >= 0, "with iron, he can offer it")
	if k < 0:
		Sx.end(g)
		return
	@warning_ignore("return_value_discarded")
	t.pick(k)
	eq(t.node, &"iron", "and Rook answers it")
	eq(g.inventory.count(&"scrap"), scrap, "nothing changes hands until he takes the pay")
	@warning_ignore("return_value_discarded")
	t.pick(0)
	var row: Dictionary = StoryContent.PAID[&"rook.iron"]
	eq(g.inventory.count(&"iron_ore"), 0, "the crew have the iron")
	eq(g.inventory.count(&"scrap"), scrap + int(row.gives[&"scrap"]), "and he has their plate")
	eq(Guide.goal(g), String(StoryContent.LEAD.get(&"armour", "<no armour line>")), "the want is the armour the plate is for")
	g.inventory.add(StringName(row.makes), 1)
	check(Guide.goal(g) != String(StoryContent.LEAD.get(&"armour", "<no armour line>")), "until it is made")
	Sx.end(g)
	Story.forget()
