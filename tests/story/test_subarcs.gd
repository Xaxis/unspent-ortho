extends TestCase
## What a region asks of him (StorySubarc, docs/VISION.md §10.4): raised from the
## region's own state, said by somebody who lives there, answered by the world
## rather than counted, and outranked by what the region itself is doing.

const Sx := preload("res://tests/save/save_fixture.gd")


func _look(works: Vector2, dark: bool, marks: Array[Dictionary]) -> StorySubarcLook:
	var look := StorySubarcLook.new()
	look.region = 3
	look.land = &"coast"
	look.works = works
	look.works_dark = dark
	look.landmarks = marks
	return look


func _mark(name_: String, found: bool, opened: bool) -> Dictionary:
	return {"id": 1, "kind": &"mast", "name": name_, "pos": Vector2(10, 10), "found": found, "opened": opened}


func test_a_region_asks_for_the_yard_first_then_its_own_losses() -> void:
	Story.forget()
	var lit := _look(Vector2(20, 20), false, [_mark("the mast", true, false)])
	eq(StringName(str(StorySubarc.raised(lit).goal)), &"sabotage", "a yard still running comes first")
	var dark := _look(Vector2(20, 20), true, [_mark("the mast", true, false)])
	eq(StringName(str(StorySubarc.raised(dark).goal)), &"recover", "then a cache nobody went back for")
	var opened := _look(Vector2(20, 20), true, [_mark("the mast", true, true), _mark("the tower", false, false)])
	eq(StringName(str(StorySubarc.raised(opened).goal)), &"discover", "then a place nobody has walked to")
	var nothing := _look(Vector2.INF, true, [_mark("the mast", true, true)])
	check(StorySubarc.raised(nothing).is_empty(), "and a region with nothing wrong asks nothing")
	Story.forget()


func test_it_is_said_once_and_thanked_when_the_world_says_so() -> void:
	Story.forget()
	var lit := _look(Vector2(20, 20), false, [])
	var said := StorySubarc.raised(lit)
	var ask := StorySubarc.talk(lit, said)
	check(not ask.is_empty(), "somebody who lives here says it")
	check("\n".join(ask.nodes[&"open"].says).contains("yard"), "in their own words")
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(ask)
	check(Story.heard(said.id), "having said it, they have said it")
	check(StorySubarc.talk(lit, said).is_empty(), "and they do not say it again")
	# The world answers it: the yard goes dark.
	var dark := _look(Vector2(20, 20), true, [])
	var thanks := StorySubarc.talk(dark, said)
	check(not thanks.is_empty() and "\n".join(thanks.nodes[&"open"].says).contains("dark"), "then they thank him")
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(thanks)
	# Thanked, the next thing they have to say is what the place is like now.
	var quiet := StorySubarc.talk(dark, said)
	check(not quiet.is_empty() and "\n".join(quiet.nodes[&"open"].says).contains("quiet"), "then the quiet")
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(quiet)
	check(StorySubarc.talk(dark, said).is_empty(), "and then they have said everything")
	Story.forget()


func test_what_the_region_is_doing_outranks_what_it_wants() -> void:
	Story.forget()
	var hunted := _look(Vector2(20, 20), false, [])
	hunted.level = &"hunted"
	eq(StorySubarc.mood(hunted), &"during", "they are looking for him")
	var warned := StorySubarc.talk(hunted, StorySubarc.raised(hunted))
	check("\n".join(warned.nodes[&"open"].says).contains("asking after somebody"), "so he is warned, not asked")
	Story.forget()
	var free := _look(Vector2(20, 20), true, [])
	free.keeper_down = true
	eq(StorySubarc.mood(free), &"after", "the plan has lost the place")
	var quiet := StorySubarc.talk(free, StorySubarc.raised(free))
	check("\n".join(quiet.nodes[&"open"].says).contains("quiet"), "and somebody says what a quiet is like")
	Story.forget()


func test_somebody_in_the_region_says_it_in_a_running_game() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11", "--folk=6"])
	await frames(6)
	var story: Node = Sx.system(g, "49_story")
	var look: StorySubarcLook = story.call("subarc_look")
	check(look.region >= 0, "he stands in a region")
	var said: Dictionary = StorySubarc.raised(look)
	if said.is_empty():
		Sx.end(g)
		Story.forget()
		return
	var folk: Node = Sx.system(g, "folk")
	var rows: Array = folk.get("folk")
	check(not rows.is_empty(), "somebody lives here")
	if not rows.is_empty():
		story.call("_start_talk", rows[0])
		var talk: StoryTalk = story.get("talk")
		check(talk != null and not talk.made.is_empty(), "and what they say is what the region asks")
		check(Story.heard(said.id), "which is remembered")
	Sx.end(g)
	Story.forget()


func test_saying_he_will_is_remembered_and_changes_what_they_say_after() -> void:
	Story.forget()
	var lit := _look(Vector2(20, 20), false, [])
	var said := StorySubarc.raised(lit)
	var ask := StorySubarc.talk(lit, said)
	var replies: Array = ask.nodes[&"open"].replies
	eq(replies.size(), 2, "he can say he will, or say nothing")
	check(str(replies[1].text) == "[say nothing]", "and saying nothing is always one of them")
	var t := StoryTalk.of_made(ask)
	@warning_ignore("return_value_discarded")
	t.pick(0)
	check(StorySubarc.promised(said), "he said he would")
	var dark := _look(Vector2(20, 20), true, [])
	var thanks := StorySubarc.talk(dark, said)
	check("\n".join(thanks.nodes[&"open"].says).contains("You said you'd see to it"), "so they say he said he would")
	Story.forget()
	# And when he never said it, they thank him for a thing that was simply done.
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(StorySubarc.talk(lit, said))
	var quiet := StorySubarc.talk(dark, said)
	check("\n".join(quiet.nodes[&"open"].says).contains("We heard it stop in the night"), "and otherwise they only say what happened")
	Story.forget()
