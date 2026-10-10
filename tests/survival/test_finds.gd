extends TestCase
## FINDS (docs/SALVAGE.md E4): taking the old world apart sometimes turns up a
## thing with words on it. Rolled off the world's seed, the prop and the take, so a
## reload cannot reroll one; filed in the journal and named, never opened over him;
## never the same words twice.


func _game() -> Game:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func test_the_story_has_finds_to_turn_up() -> void:
	var finds := 0
	for id: StringName in StoryContent.FRAGMENTS:
		if StoryFragments.kind_of(id) == StoryFragments.FIND:
			finds += 1
			check(StoryFragments.title_of(id) != "", "%s says what it is" % id)
			check(not StoryFragments.lines(id).is_empty(), "%s has words on it" % id)
	gt(float(finds), 9.0, "a dozen or so finds are written (%d)" % finds)


func test_a_tip_turns_up_a_find_now_and_then_and_the_same_one_every_time() -> void:
	var g := _game()
	await frames(4)
	Story.forget()
	var tip := Survival.add_prop(g, PropKind.TIP, g.player.pos + Vector2(1.2, 0.0), 0.0, 0.9)
	var first: Array[StringName] = []
	for takes in 40:
		first.append(Survival.find_for(g, tip, takes))
	var turned := first.filter(func(id: StringName) -> bool: return id != &"").size()
	gt(float(turned), 0.0, "forty takes from a tip turn something up (%d)" % turned)
	lt(float(turned), 16.0, "but not most of them (%d of 40)" % turned)
	# The same tip, the same takes: the same answer, whatever reloads in between.
	var again: Array[StringName] = []
	for takes in 40:
		again.append(Survival.find_for(g, tip, takes))
	eq(again, first, "the same takes turn up the same things")
	# Taken for real: each one is filed once, and a read one never turns up again.
	var got: Array[StringName] = []
	var on := func(id: StringName) -> void: got.append(id)
	Events.turned_up.connect(on)
	for takes in 40:
		Survival._turn_up(g, tip, takes)
	await frames(1)
	for takes in 40:
		Survival._turn_up(g, tip, takes)
	var seen := {}
	for id: StringName in got:
		check(not seen.has(id), "%s turned up twice" % id)
		seen[id] = true
	Events.turned_up.disconnect(on)
	g.queue_free()
	await frames(1)


func test_a_find_goes_in_the_journal_and_is_never_opened_over_him() -> void:
	var g := _game()
	await frames(4)
	Story.forget()
	var id := &""
	for f: StringName in StoryContent.FRAGMENTS:
		if StoryFragments.kind_of(f) == StoryFragments.FIND:
			id = f
			break
	check(id != &"", "there is a find to turn up")
	var said: Array[String] = []
	var on := func(line: String) -> void: said.append(line)
	Events.message.connect(on)
	Events.turned_up.emit(id)
	await frames(2)
	check(Story.knows(id), "it is in the journal")
	check(not (g.get_node("49_story").get("view") as Node).call(&"showing"), "and no page opened over him")
	check(said.size() > 0 and said[0].contains(StoryFragments.title_of(id)), "and he is told what it is: %s" % [said])
	Events.message.disconnect(on)
	g.queue_free()
	await frames(1)


## Nothing but the old world's things: a bush, a boulder, a tree never turn one up.
func test_only_salvage_turns_up_finds() -> void:
	var g := _game()
	await frames(4)
	var got: Array[StringName] = []
	var on := func(id: StringName) -> void: got.append(id)
	Events.turned_up.connect(on)
	for kind: int in [PropKind.BUSH, PropKind.BOULDER, PropKind.PINE, PropKind.MUSSEL_ROCK]:
		var p := Survival.add_prop(g, kind, g.player.pos + Vector2(2.0, 0.0), 0.0, 0.3)
		for takes in 40:
			Survival._turn_up(g, p, takes)
	eq(got.size(), 0, "nothing of nature's turns up words")
	Events.turned_up.disconnect(on)
	g.queue_free()
	await frames(1)
