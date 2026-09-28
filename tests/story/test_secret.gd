extends TestCase

const Sx := preload("res://tests/save/save_fixture.gd")
## The secret is hidden in the ORDER of three memories (StorySecret, docs/STORY.md
## §4): kitchen, car, the hall. Two keepers hold two of them and the Seeker's 2029
## gives back the third, in any order; the order he RELIVES them in at the
## channel is the version (ruled 2026-09-28).


func test_his_own_hand_wrote_the_order_the_secret_keeps() -> void:
	var words := "\n".join(StoryFragments.lines(&"three_words"))
	check(words.contains("kitchen. car. the hall."), "the scratched list is the key's order")
	eq(StorySecret.KEY.size(), 3, "three memories")
	for m: StringName in StorySecret.KEY:
		check(StoryContent.BEATS.has(m), "%s is a beat" % m)


func test_every_memory_has_a_door() -> void:
	var held := {}
	for keeper: StringName in StoryContent.KEEPER_MEMORY:
		held[StoryContent.KEEPER_MEMORY[keeper].memory] = keeper
		var owner: BiomeDef = null
		for d: BiomeDef in BiomeRegistry.all():
			if d.sentinel == keeper:
				owner = d
		check(owner != null, "%s is some landscape's keeper" % keeper)
	check(held.has(&"mem_kitchen") and held.has(&"mem_car"), "the keepers hold the kitchen and the car")
	var hall := false
	for n: Dictionary in StoryContent.TALKS[&"hale"].nodes.values():
		hall = hall or (n.get("beats", []) as Array).has(&"mem_hall")
	check(hall, "and the hall comes back in the Seeker's 2029, walking out for the play")


func test_a_keeper_read_says_which_memory_it_keeps() -> void:
	var t := StoryContent.testimony(&"keeper", {"machine": true, "sentinel": &"pan_rake"})
	eq(str(t.says), "keeps a kitchen, at night")
	check(not StoryContent.testimony(&"keeper", {"machine": true, "sentinel": &"nobody_yet"}).is_empty(),
		"a keeper with no memory of his still keeps one not its own")


## The tide's keeper is on the home coast, so the car comes back first, and that
## must commit nothing: only the reliving at the channel decides.
func test_recovered_in_any_order_it_is_relived_in_one() -> void:
	for got: Array in [[&"mem_car", &"mem_kitchen", &"mem_hall"], [&"mem_hall", &"mem_car", &"mem_kitchen"]]:
		Story.forget()
		Story.beat(got[0], -INF)
		check(not StorySecret.complete(), "nothing until all three are back")
		for m: StringName in got:
			Story.beat(m, -INF)
		check(StorySecret.complete(), "all three back, in any order, he holds it")
		check(not StorySecret.whole(), "and the order they came back in decides nothing")
		Story.beat(StorySecret.HELD, -INF)
		for picks: Array in [["[the kitchen]", "[the car]"], ["[the car]", "[the kitchen]"], ["[the hall]", "[the kitchen]"]]:
			Story.forget_beat(&"secret_whole")
			Story.forget_beat(&"secret_misremembered")
			var t := StoryTalk.start(&"the_channel")
			for want: String in ["Break them."] + picks:
				var i := -1
				var rs := t.replies()
				for k in rs.size():
					if str(rs[k].text) == want:
						i = k
				check(i >= 0, "the channel offers %s" % want)
				if i < 0:
					break
				@warning_ignore("return_value_discarded")
				t.pick(i)
			var in_order: bool = picks[0] == "[the kitchen]" and picks[1] == "[the car]"
			eq(StorySecret.whole(), in_order, "relived %s: whole only as kitchen, car, the hall" % [picks])
			eq(Story.landed(&"secret_misremembered"), not in_order, "and turned otherwise")
	Story.forget()


func test_taking_a_keeper_in_a_running_game_gives_its_memory_back() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11"])
	await frames(3)
	Events.sentinel_fell.emit(0, &"salt_flats", &"force")
	check(Story.landed(&"mem_kitchen"), "the salt's keeper held the kitchen")
	check(not Story.landed(&"mem_car"), "and only the kitchen")
	Events.sentinel_fell.emit(1, &"coast", &"starve")
	check(Story.landed(&"mem_car"), "the tide's keeper held the car")
	Sx.end(g)
	Story.forget()
