extends TestCase
## VERA AND THE WAY ON (ROADMAP slice 2, step 7), and the slice's goal chain end
## to end: every slice 2 beat is reachable by the goal line alone. Camp, paid,
## armour, the yard's screen, back to Rook, Vera, the archive across the water;
## each hop said until the beat that ends it lands (Guide.way_goal), and the
## archive marked on the survey (StoryContent.TOLD). vera_knew is the price's
## answer, not a lead: her question waits on holdfast_price.

const Sx := preload("res://tests/save/save_fixture.gd")


func _lead(key: StringName) -> String:
	return String(StoryContent.LEAD.get(key, "<no %s line>" % key))


func test_the_goal_line_walks_slice_two_end_to_end() -> void:
	Story.forget()
	# Full size, as the game ships: the archive is the next leg's, on another body,
	# and a shrunken world may cast no second body at all.
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"iron_ore", 1)
	eq(Guide.goal(g), _lead(&"camp"), "iron in the bag: the crew's camp")
	Story.choose(&"rook.iron", &"paid")
	eq(Guide.goal(g), _lead(&"armour"), "paid: the armour the plate is for")
	g.inventory.add(&"kit_plate", 1)
	check(Guide.goal(g) != _lead(&"armour"), "the armour made, that want is met")
	# THE HOLDING (Holding): he has seen what a broken yard's hunters leave, and
	# before anybody he knows has been taken the goal says it for the burned roofs.
	Story.beat(&"holdfast_price")
	eq(Guide.goal(g), String(StoryContent.HOLDING_MOVE["lead_burned"]), "the price seen: beds, for the people a burned village leaves")
	eq(Guide.last_goal_key, &"holding", "keyed, so a tour can claim it")
	# The plan takes somebody out of a village that saw him, as a snatch night does.
	var folk := g.get_node("folk")
	var v := 0
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	(folk.get("seen_by") as Dictionary)[v] = g.clock.minutes
	g.get_node("45_taken").call(&"took", -1, "", -1, str(g.world.villages[v].get("name", "")),
		g.world.region_at(floori(at.x), floori(at.y)))
	eq(Guide.goal(g), _lead(&"holding"), "one of them taken: beds, for the people a yard would take")
	# He founds a holding the way a player does: its first piece, set down.
	g.inventory.add(&"driftwood", 6)
	g.inventory.add(&"rag", 2)
	var built: String = g.get_node("46_settlements").call(&"build_here", StructureKind.LEAN_TO)
	check(not built.begins_with("!"), "the first piece goes down: %s" % built)
	check(Guide.goal(g) != _lead(&"holding") and Guide.last_goal_key != &"holding", "a holding stands: that want is met")
	Story.beat(&"reaper_down")
	eq(Guide.goal(g), _lead(&"yard"), "the yard dark: its oldest screen")
	Story.beat(&"built_halcyon")
	eq(Guide.goal(g), _lead(&"rook_again"), "his old work read: back to the crew, who want a man who knows the machines")
	Story.beat(&"holdfast_hope")
	eq(Guide.goal(g), _lead(&"vera"), "the crew's hope in him: their leader, come to the camp")
	Story.beat(&"war_archive")
	eq(Guide.goal(g), _lead(&"archive"), "she has named the archive: across the water")
	eq(Guide.last_goal_key, &"archive", "keyed, so a tour can claim it")
	var told: Dictionary = StoryContent.TOLD
	var word := String((told.get(&"war_archive", {}) as Dictionary).get("word", "<no archive word>"))
	var marked := false
	for t: Dictionary in UiMapScreen.told(g):
		marked = marked or String(t.word) == word
	check(marked, "and the survey marks it")
	@warning_ignore("return_value_discarded")
	Story.meet(&"otto")
	check(Guide.goal(g) != _lead(&"archive"), "until he has met the man there")
	Sx.end(g)
	Story.forget()


func test_the_way_on_waits_for_the_crew_to_have_paid() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"iron_ore", 1)
	Story.beat(&"reaper_down")
	Story.beat(&"built_halcyon")
	eq(Guide.goal(g), _lead(&"camp"), "the road to the camp comes first, whatever he has read")
	Sx.end(g)
	Story.forget()


func _replies(t: StoryTalk) -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in t.replies():
		out.append(str(r.text))
	return out


func test_filed_under_weather_waits_on_the_price() -> void:
	Story.forget()
	var ask := "That village. They weren't angry, were they?"
	var t := StoryTalk.start(&"vera")
	check(not _replies(t).has(ask), "before he has seen what a broken yard costs, she is not asked")
	Story.forget()
	Story.beat(&"holdfast_price", -INF)
	t = StoryTalk.start(&"vera")
	check(_replies(t).has(ask), "after, he asks")
	var i := _replies(t).find(ask)
	if i >= 0:
		@warning_ignore("return_value_discarded")
		t.pick(i)
	check(Story.landed(&"vera_knew"), "and she tells him it is filed under weather")
	Story.forget()
