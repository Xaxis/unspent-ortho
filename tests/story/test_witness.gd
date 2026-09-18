extends TestCase
## The story in a running game, through the two channels that are not reading or
## talking (docs/STORY.md §13): what a machine is, by being watched, and what was
## done to the player. Each lands on the change, once, and says so.

const Sx := preload("res://tests/save/save_fixture.gd")


func _story(g: Game) -> Node:
	return Sx.system(g, "49_story")


func test_being_filed_is_written_down_once() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	var said: Array[String] = []
	var hear := func(t: String) -> void: said.append(t)
	Events.message.connect(hear)
	await frames(40)
	check(not Story.landed(StoryContent.WITNESS_ON[&"filed"]), "nothing lands for having done nothing")
	g.body.filed += 1
	await frames(45)
	check(Story.landed(StoryContent.WITNESS_ON[&"filed"]), "filed, it is known")
	var count := said.filter(func(t: String) -> bool: return t == StoryContent.beat_says(StoryContent.WITNESS_ON[&"filed"])).size()
	eq(count, 1, "and said once on the glass")
	g.body.filed += 1
	await frames(45)
	count = said.filter(func(t: String) -> bool: return t == StoryContent.beat_says(StoryContent.WITNESS_ON[&"filed"])).size()
	eq(count, 1, "and not again for being filed again")
	Events.message.disconnect(hear)
	Sx.end(g)
	Story.forget()


func test_a_record_in_the_hand_and_a_yard_put_dark_are_each_known() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	Events.took.emit(&"driftwood", 1)
	check(not Story.landed(StoryContent.WITNESS_ON[&"record"]), "driftwood is not a record")
	Events.took.emit(&"record", 1)
	check(Story.landed(StoryContent.WITNESS_ON[&"record"]), "a record is")
	Events.works_broken.emit(0, &"coast")
	check(Story.landed(StoryContent.WITNESS_ON[&"works_dark"]), "and a works put dark")
	Sx.end(g)
	Story.forget()


func test_the_signet_only_means_his_own_key_once_he_knows_he_had_one() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	g.body.spoof_until = g.clock.minutes + 30.0
	await frames(45)
	check(not Story.landed(StoryContent.WITNESS_ON[&"signet"]), "a signet fired by somebody who knows nothing of his old passwords is only a signet")
	Story.beat(StoryContent.SIGNET_AFTER)
	await frames(45)
	check(Story.landed(StoryContent.WITNESS_ON[&"signet"]), "knowing he wrote the old passwords, the signet is his own")
	Sx.end(g)
	Story.forget()


func test_standing_below_is_learning_what_grew_him() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	await frames(40)
	check(not Story.landed(StoryContent.WITNESS_ON[&"other_realm"]), "the surface is only here")
	var was := g.world.realm
	g.world.realm = Realm.UNDERGROUND
	await frames(45)
	g.world.realm = was
	check(Story.landed(StoryContent.WITNESS_ON[&"other_realm"]), "below, something grew him")
	Sx.end(g)
	Story.forget()


func test_a_machine_read_long_enough_tells_what_it_is_for() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11", "--weather=clear:0"])
	await frames(3)
	var sim: FightSim = g.player.sim
	# A watcher keeps to its rise, so it is still there to be read when the slate
	# has been on it long enough.
	var m := sim.add_mob(&"watcher", g.player.pos + Vector2(3, 0))
	check(m != null, "a watcher to read")
	var read := TargetRead.of(m, g.player.pos, sim.moment)
	eq(str(read.testimony), str(StoryContent.TESTIMONY[m.role].says), "the read says what a %s is for" % m.role)
	# The real key, held, as a player holds it.
	Input.action_press(&"target")
	var saw := false
	var budget := int((StoryContent.TESTIFY_SECONDS + 1.5) * 60.0 * TestCase.machine_slack())
	for i in budget:
		await frames(1)
		saw = saw or bool(_story(g).call("tour_seen", &"testimony"))
		if Story.landed(StoryContent.TESTIMONY[&"watcher"].beats[0]):
			break
	Input.action_release(&"target")
	check(saw, "the slate on it shows what it is for, and a tour can see that")
	check(Story.landed(StoryContent.TESTIMONY[&"watcher"].beats[0]), "held on a %s, what it is for lands" % m.kind)
	await frames(2)
	Sx.end(g)
	Story.forget()


func test_a_creature_is_nothing_of_the_plan_s() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	var sim: FightSim = g.player.sim
	var dog := sim.add_mob(&"dog", g.player.pos + Vector2(3, 0))
	if dog != null:
		eq(str(TargetRead.of(dog, g.player.pos, sim.moment).testimony), "", "a dog is read as a dog")
	Sx.end(g)
	Story.forget()
