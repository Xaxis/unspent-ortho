extends TestCase

const Sx := preload("res://tests/save/save_fixture.gd")
## The secret is hidden in the ORDER of three memories (StorySecret, docs/STORY.md
## §4): kitchen, car, the hall. Two keepers hold two of them and the Seeker's 2029
## gives back the third, and the order they come back in is the version he holds.


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


func test_in_order_the_key_turns_and_out_of_order_it_catches() -> void:
	Story.forget()
	var t := 0.0
	for m: StringName in StorySecret.KEY:
		t += 10.0
		Story.now = t
		Story.beat(m)
	eq(StorySecret.version(), &"secret_whole", "kitchen, car, the hall")
	Story.forget()
	var backwards: Array[StringName] = [&"mem_hall", &"mem_kitchen", &"mem_car"]
	t = 0.0
	for m: StringName in backwards:
		t += 10.0
		Story.now = t
		Story.beat(m)
	eq(StorySecret.version(), &"secret_misremembered", "the hall first turns it the wrong way")
	Story.forget()
	Story.beat(&"mem_kitchen")
	eq(StorySecret.version(), &"", "nothing until all three are back")
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
