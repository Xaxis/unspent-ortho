extends TestCase
## The first hour guide: a goal that follows what the player has and lacks, key
## hints that fit the moment and retire once used, and a running game that says
## the goal at wake and the keys after it, a few seconds apart.

const Fx := preload("res://tests/survival/fixture.gd")


func test_the_goal_walks_the_way_in() -> void:
	var g := Fx.flat()
	g.inventory.remove(&"knife")
	g.inventory.add(&"knife")
	check(Guide.goal(g).contains("three driftwood and two stones"), "first a fire, and what it takes: %s" % Guide.goal(g))
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	check(Guide.goal(g).contains("lay it"), "with the makings, lay it: %s" % Guide.goal(g))
	Survival.build(g, &"fire", true)
	check(Guide.goal(g).contains("Charcoal"), "a fire: charcoal next: %s" % Guide.goal(g))
	g.inventory.add(&"charcoal", 1)
	check(Guide.goal(g).contains("haft"), "then a haft: %s" % Guide.goal(g))
	g.inventory.add(&"haft", 1)
	check(Guide.goal(g).contains("tip"), "then plate: %s" % Guide.goal(g))
	g.inventory.add(&"scrap", 1)
	check(Guide.goal(g).contains("pick"), "then the pick: %s" % Guide.goal(g))
	g.inventory.add(&"pick", 1)
	check(Guide.goal(g).contains("ore"), "then the ore: %s" % Guide.goal(g))
	g.body.fed_until = g.clock.minutes - 8.0 * 60.0
	check(Guide.goal(g).contains("Eat"), "hunger comes first: %s" % Guide.goal(g))
	Fx.done(g)


func test_hints_fit_the_moment_and_stay_retired() -> void:
	var g := Fx.flat()
	var retired := {}
	eq(Guide.hint_for(g, retired).get("id", &""), &"walk", "at wake: the walking keys")
	var drift := Fx.put(g, PropKind.DRIFTWOOD, Vector2(0.9, 0))
	Fx.face(g, drift)
	eq(Guide.hint_for(g, retired).get("id", &""), &"take", "facing something: E")
	retired[&"take"] = true
	eq(Guide.hint_for(g, retired).get("id", &""), &"walk", "used once, it is not said again")
	g.clock.skip(13.0 * 60.0)
	g.inventory.add(&"lamp")
	eq(Guide.hint_for(g, retired).get("id", &""), &"lamp", "night asks for the lamp")
	g.body.lamp_lit = true
	check(Guide.hint_for(g, retired).get("id", &"") != &"lamp", "lit, it does not")
	Fx.done(g)


func test_a_running_game_says_the_goal_at_wake_then_the_keys() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var guide: Node = g.get_node("58_guide")
	check(guide != null, "the guide system loads")
	if guide == null:
		g.free()
		return
	var said: Array[String] = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	guide.call("_process", 1.0)
	eq(said.size(), 0, "not in the first second")
	guide.call("_process", 1.0)
	eq(said.size(), 1, "then the goal")
	if said.size() >= 1:
		eq(said[0], Guide.goal(g), "the goal line")
	guide.call("_process", 1.0)
	eq(said.size(), 1, "and the next waits its turn")
	guide.call("_process", 5.0)
	eq(said.size(), 2, "a hint after")
	var retired: Dictionary = guide.get("retired")
	check(retired.size() >= 1, "said hints retire")
	Events.took.emit(&"driftwood", 2)
	check(retired.has(&"take"), "a take retires the take hint")
	Events.message.disconnect(listen)
	g.queue_free()
	await frames(1)


func test_the_first_kill_of_a_game_is_said_once() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var said: Array[String] = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	Events.killed.emit(&"gulls", Vector3.ZERO)
	eq(said.size(), 0, "a gull is not a fight won")
	Events.killed.emit(&"runner", Vector3.ZERO)
	eq(said, [load("res://src/systems/58_guide.gd").KILL_LINE] as Array[String], "the first kill is said")
	Events.killed.emit(&"runner", Vector3.ZERO)
	eq(said.size(), 1, "and only the first")
	Events.message.disconnect(listen)
	g.queue_free()
	await frames(1)
