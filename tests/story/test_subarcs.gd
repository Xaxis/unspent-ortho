extends TestCase
## What a region asks of him (StorySubarc, docs/VISION.md): raised from the
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
	# 512, not 256: the player has to wake in a region for anyone in it to ask,
	# and on seed 1 at 256 -- one of twelve seeds at that size, none at 512 or at
	# the shipped 1840 (GEN 24) -- the spawn has to choose between a place and a
	# beach the black site can stand off, and the black site is the spine's.
	var g := Sx.game(tree, ["--seed=1", "--size=512", "--hour=11", "--folk=6"])
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


## The quietest thing anybody says: the place is wholly done with him. A person
## says it from having watched him, never from a count of what he carried out.
func test_a_place_that_is_answered_says_so_in_the_words_of_somebody_watching() -> void:
	Story.forget()
	var look := _look(Vector2(20, 20), true, [])
	look.keeper_down = true
	look.answered = true
	eq(StorySubarc.mood(look), &"done", "answered outranks the plan having lost it")
	var page := StorySubarc.talk(look, StorySubarc.raised(look))
	var words := "\n".join(page.nodes[&"open"].says)
	check(words.contains("every track on this ground"), "what they have watched him do:\n%s" % words)
	check(not words.contains("enough") and not words.contains("counted"), "and nothing about a count")
	Story.forget()


## The one a yard is worth walking into for. The plan carries somebody off, the
## region stops asking about the ground and starts asking about the person, and
## the same act answers both.
func test_a_region_holding_somebody_asks_about_them_and_not_about_the_ground() -> void:
	Story.forget()
	var look := _look(Vector2(20, 20), false, [_mark("the mast", true, false)])
	look.held = ["somebody out of Oyster Row"]
	var said := StorySubarc.raised(look)
	eq(StringName(str(said.goal)), &"rescue", "a neighbour in the yard outranks the yard")
	eq(str(said.place), "somebody out of Oyster Row", "and they are spoken of as a person")
	var ask := StorySubarc.talk(look, said)
	var words := "\n".join(ask.nodes[&"open"].says)
	check(words.contains("They took somebody out of Oyster Row"), "in their own words:\n%s" % words)
	check(words.contains("dark doesn't hold anybody"), "and the answer is named without being a marker")
	# A region with nobody to break has no way to let anybody out, so it never
	# asks: a sub-arc that cannot be answered is a cruelty and not a story.
	var nowhere := _look(Vector2.INF, false, [])
	nowhere.held = ["somebody out of Oyster Row"]
	check(StringName(str(StorySubarc.raised(nowhere).get("goal", &""))) != &"rescue", "and no yard is no asking")
	Story.forget()


## The bug this closes is the shape the whole package had: the ACT that answers a
## goal is the act that stops the goal being raised, so the moment the yard went
## dark the region began asking for a cache instead and nobody ever thanked him.
func test_a_goal_the_world_answered_is_still_owed_a_thanks() -> void:
	Story.forget()
	var lit := _look(Vector2(20, 20), false, [_mark("the mast", true, false)])
	lit.held = ["Ruth"]
	var said := StorySubarc.raised(lit)
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(StorySubarc.talk(lit, said))
	check(Story.heard(said.id), "he was asked")
	# The yard goes dark: Ruth walks out, and the region now wants a cache.
	var dark := _look(Vector2(20, 20), true, [_mark("the mast", true, false)])
	dark.freed = ["Ruth"]
	var owed := StorySubarc.raised(dark)
	eq(StringName(str(owed.goal)), &"rescue", "what he answered outranks what they want next")
	eq(str(owed.place), "Ruth", "and they can still name who it was about")
	var thanks := StorySubarc.talk(dark, owed)
	check("\n".join(thanks.nodes[&"open"].says).contains("Ruth came up the road"), "so they can thank him for her")
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(thanks)
	# Thanked, the region goes back to wanting things.
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(StorySubarc.talk(dark, StorySubarc.raised(dark)))
	eq(StringName(str(StorySubarc.raised(dark).goal)), &"recover", "and then it asks for the next thing")
	Story.forget()


## What he was asked for is remembered with the asking, because the world answers
## by CHANGING: the cache he opened is no longer one that is waiting to be opened,
## so it cannot be found by looking for one.
func test_what_the_asking_was_about_outlives_the_thing_being_done() -> void:
	Story.forget()
	# No yard at all, so the region is quiet and has only its own losses to ask
	# about: a yard gone dark would be a MOOD, and a mood outranks an errand.
	var waiting := _look(Vector2.INF, false, [_mark("the mast", true, false), _mark("the tower", true, false)])
	var said := StorySubarc.raised(waiting)
	eq(StringName(str(said.goal)), &"recover")
	eq(str(said.place), "the mast")
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(StorySubarc.talk(waiting, said))
	eq(Story.heard_about(said.id), "the mast", "which cache it was is kept with the telling")
	var opened := _look(Vector2.INF, false, [_mark("the mast", true, true), _mark("the tower", true, false)])
	var owed := StorySubarc.raised(opened)
	eq(str(owed.place), "the mast", "so the thanks is for the one he opened")
	check("\n".join(StorySubarc.talk(opened, owed).nodes[&"open"].says).contains("his cache"), "in the words written for it")
	Story.forget()


## The whole of it in a running game: the plan is holding somebody at the yard the
## player is standing in, the region asks about THEM rather than about the ground,
## and the one act that answers it says so on the glass in the story's own words.
func test_a_staged_world_holds_somebody_and_the_region_asks_about_them() -> void:
	Story.forget()
	# AN ISLAND THAT CAN HOLD SOMEBODY, found rather than pinned. `--carried` needs
	# a depot with a village in its region, and which seeds have one moves with
	# every works change: at 256 the old siting left seed 4 with none and the
	# siting by region leaves seed 1 with none, six such depots across five seeds
	# either way. Pinning seed 1 was pinning its luck.
	var seed_value := -1
	for s: int in [1, 7, 42, 90210, 4]:
		var w := BootWorld.world(s, 256)
		for d: WorksSite in Works.sites(w):
			for v: Dictionary in w.villages:
				var at: Vector2 = v.get("pos", Vector2.INF)
				if w.region_at(floori(at.x), floori(at.y)) == d.region:
					seed_value = s
			if seed_value >= 0:
				break
		if seed_value >= 0:
			break
	check(seed_value >= 0, "some island in the sample can hold somebody")
	var g := Sx.game(tree, ["--seed=%d" % seed_value, "--size=256", "--hour=11", "--carried=1"])
	await frames(6)
	var story: Node = Sx.system(g, "49_story")
	# STAND AT THE YARD THEY ARE HELD IN, ASKED BY NAME. This used to boot with
	# `--place=works`, the FIRST depot, while `--carried` holds them at the first
	# depot with a VILLAGE in its region (`45_taken`): two rules that happened to
	# pick the same yard until works were sited in their own landscape's regions,
	# and then the player stood in an empty yard and the story saw nobody held.
	# `rescue:yard` is the name the taken package's header says to use.
	var yard: Vector2 = story.call("tour_place", "rescue:yard")
	check(yard.is_finite(), "the story can say where they are held")
	g.player.pos = yard
	g.player.hero.pos = yard
	await frames(6)
	var look: StorySubarcLook = story.call("subarc_look")
	check(not look.held.is_empty(), "the story sees who the yard is holding: %s" % [look.held])
	var said: Dictionary = StorySubarc.raised(look)
	eq(StringName(str(said.get("goal", &""))), &"rescue", "and the region asks about the person")
	eq(str(said.place), look.held[0], "by the name anybody here would use")
	# The one act. The works package's own signal is what frees them, so nothing
	# in the story had to know what a depot is.
	var lines := PackedStringArray()
	var heard := func(text: String) -> void: lines.append(text)
	Events.message.connect(heard)
	Events.works_broken.emit(look.region, look.land)
	await frames(2)
	Events.message.disconnect(heard)
	# Held to the WORDS and not to a phrase inside them: whether they walked out
	# by themselves or are waiting to be walked home is the taken package's call
	# (`StoryContent.TAKEN.freed` / `out`), and this test is only asking that the
	# act was announced at all.
	var who: String = look.held[0]
	var announced := false
	for said_line: String in lines:
		for key: String in ["freed", "out"]:
			if said_line == str(StoryContent.TAKEN[key]) % who:
				announced = true
	check(announced, "and somebody walks out of it: %s" % [lines])
	var after: StorySubarcLook = story.call("subarc_look")
	check(after.held.is_empty() and not after.freed.is_empty(), "the record outlives the rescue")
	check(StorySubarc.answered(after, &"rescue", str(said.place)), "and the world says it is answered")
	Sx.end(g)
	Story.forget()


## THE WALK HOME, and the only sub-arc that can end badly (`Escort`). Out of the
## yard is not home: somebody stood at its gate who will not come down the road
## alone is what the region asks about next, and what he gets asked for is a
## person and not an errand.
func _freed(who: String) -> StorySubarcLook:
	var look := _look(Vector2(20, 20), true, [])
	look.freed = [who]
	look.waiting = [who]
	return look


## A yard that is dark is a yard somebody put dark, so the quiet is always
## pending the first time anybody speaks after one. Say it and have done: the
## order is the feature — what he answered, then what the place is like now, then
## the next thing they want.
func _past_the_quiet(look: StorySubarcLook) -> void:
	var page := StorySubarc.talk(look, StorySubarc.raised(look))
	check("\n".join(page.nodes[&"open"].says).contains("quiet"), "the quiet is said first")
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(page)


func test_out_of_the_yard_is_not_home() -> void:
	Story.forget()
	var look := _freed("somebody out of Oyster Row")
	# The rescue's thanks is owed first and is said first: the region does not
	# hand him the next thing to do before anybody has said the last one happened.
	Story.hear(StringName("3:rescue"))
	Story.hear_about(StringName("3:rescue"), "somebody out of Oyster Row")
	eq(StringName(str(StorySubarc.raised(look).goal)), &"rescue", "what he answered is said first")
	Story.hear(StringName("3:rescue:said"))
	_past_the_quiet(look)
	var said := StorySubarc.raised(look)
	eq(StringName(str(said.goal)), &"escort", "and then they ask him to walk them home")
	var ask := StorySubarc.talk(look, said)
	var words := "\n".join(ask.nodes[&"open"].says)
	check(words.contains("stood at the gate of that yard still"), "in their own words:\n%s" % words)
	check(str(ask.nodes[&"open"].replies[0].text) == "I'll walk with them.", "and he can say he will")
	Story.forget()


func test_they_got_home_and_somebody_says_so() -> void:
	Story.forget()
	var look := _freed("Ruth")
	_past_the_quiet(look)
	var said := StorySubarc.raised(look)
	var t := StoryTalk.of_made(StorySubarc.talk(look, said))
	@warning_ignore("return_value_discarded")
	t.pick(0)
	check(StorySubarc.promised(said), "he said he would walk it")
	var home := _freed("Ruth")
	home.waiting = []
	home.arrived = ["Ruth"]
	var owed := StorySubarc.raised(home)
	eq(StringName(str(owed.goal)), &"escort", "arriving is what answers it")
	var thanks := "\n".join(StorySubarc.talk(home, owed).nodes[&"open"].says)
	check(thanks.contains("You said you'd walk it with them"), "and they say he said he would:\n%s" % thanks)
	check(thanks.contains("boots off"), "and what it looks like to be back")
	Story.forget()


## THE THIRD ENDING, and the reason the walk was worth building. Nothing calls it
## a failure, nobody asks him to account for it, and nobody forgives him: a
## village that has lost somebody says what it knows and leaves.
func test_he_got_them_out_and_did_not_get_them_home() -> void:
	Story.forget()
	var look := _freed("somebody out of Oyster Row")
	_past_the_quiet(look)
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(StorySubarc.talk(look, StorySubarc.raised(look)))
	check(Story.heard(&"3:escort"), "he was asked to walk them home")
	var gone := _freed("somebody out of Oyster Row")
	gone.waiting = []
	gone.lost_on_road = ["somebody out of Oyster Row"]
	var owed := StorySubarc.raised(gone)
	eq(StringName(str(owed.goal)), &"escort", "the region still has its last word to say")
	check(StorySubarc.failed(gone, &"escort", str(owed.place)), "and the world has ended it without it being done")
	check(not StorySubarc.answered(gone, &"escort", str(owed.place)), "which is never the same as done")
	var page := StorySubarc.talk(gone, owed)
	var words := "\n".join(page.nodes[&"open"].says)
	check(words.contains("never came up the road"), "somebody says what they know:\n%s" % words)
	check(words.contains("banked it"), "and what they did about it")
	for ugly: String in ["fail", "sorry", "forgive", "should have", "your fault"]:
		check(not words.to_lower().contains(ugly), "and nothing that grades him: %s" % ugly)
	eq((page.nodes[&"open"].replies as Array).size(), 1, "there is nothing to answer")
	# Said once, and then the place has its mood and nothing more.
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(page)
	var after := StorySubarc.raised(gone)
	check(StringName(str(after.get("goal", &""))) != &"escort", "and it is not said twice")
	Story.forget()


## Being come back for is a different thing to be told than the cold and the
## water, and only one of them is nobody's fault.
func test_the_machines_taking_them_back_is_its_own_ending() -> void:
	Story.forget()
	var look := _freed("Ruth")
	_past_the_quiet(look)
	@warning_ignore("return_value_discarded")
	StoryTalk.of_made(StorySubarc.talk(look, StorySubarc.raised(look)))
	var gone := _freed("Ruth")
	gone.waiting = []
	gone.lost_on_road = ["Ruth"]
	gone.lost_to = {"Ruth": &"hauler"}
	var words := "\n".join(StorySubarc.talk(gone, StorySubarc.raised(gone)).nodes[&"open"].says)
	check(words.contains("took Ruth again"), "they say what took them:\n%s" % words)
	check(words.contains("what we do with twice"), "and what a second time is")
	Story.forget()
