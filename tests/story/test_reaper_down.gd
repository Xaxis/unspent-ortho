extends TestCase
## THE YARD BROKEN, SAID (ROADMAP slice 1; 44_sentinels, 49_story, 34_works,
## 45_taken): when the home coast's keeper falls the record says what could be
## seen of it falling (StoryContent.KEEPER_FELL), never the way's tactic hint;
## the beat the village talks about lands (KEEPER_DOWN); and whoever its yard
## held walks out only when the yard has gone dark, so "the yard is dark" is true
## when it is said.

const SEEDS: Array[int] = [1, 7, 3]
const SIZE := 256


func _game(seed_value: int) -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=%d" % seed_value, "--size=%d" % SIZE, "--hour=11", "--weather=clear:0"])))
	return g


func test_the_fall_is_said_as_seen_and_the_freed_walk_out_when_the_yard_is_dark() -> void:
	Story.forget()
	var g: Game = null
	var s: SentinelState = null
	for seed_value in SEEDS:
		g = _game(seed_value)
		await frames(3)
		var works := g.get_node("34_works")
		for st: SentinelState in g.get_node("44_sentinels").call(&"states"):
			if st.design == &"tide_reaper" and works.call(&"state", st.region) != null:
				s = st
		if s != null:
			break
		g.queue_free()
		await frames(1)
	check(s != null, "one of %s has the home coast's keeper in a region with a yard" % str(SEEDS))
	if s == null:
		return
	var def := Sentinels.by_id(s.design)
	var said: Array[String] = []
	Events.message.connect(func(t: String) -> void: said.append(t))
	var dark: Array[int] = []
	Events.yard_left_dark.connect(func(r: int, _l: StringName) -> void: dark.append(r))
	# Somebody the yard is holding, so there is somebody to walk out.
	g.get_node("45_taken").call(&"took", 1, "Ada", 0, "the village", s.region)
	var force := def.way_of(SentinelWay.FORCE)
	g.get_node("44_sentinels").call(&"_fell", s, def, force, s.lair)
	check(String(StoryContent.KEEPER_FELL[&"tide_reaper"][&"force"]) in said, "the record says what could be seen of it falling")
	check(Story.landed(StoryContent.KEEPER_DOWN[&"tide_reaper"]), "and the beat the village talks about lands")
	var taken := g.get_node("45_taken").get(&"taken") as Taken
	eq(taken.held_in(s.region).size(), 1, "whoever the yard holds is still held the moment it falls")
	eq(dark.size(), 0, "and the yard is not dark yet")
	g.clock.skip(WorksState.KEEPER_DARK_AFTER + 1.0)
	await frames(3)
	eq(dark, [s.region] as Array[int], "a moment later the yard goes dark")
	check(StoryContent.YARD_DARK in said, "and says so")
	eq(taken.held_in(s.region).size(), 0, "and only now does anybody walk out of it")
	g.queue_free()
	await frames(1)
	Story.forget()
