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
	# Guide lines go out on the teaching channel, never on the queued message line.
	var listen := func(t: String, _key: String) -> void: said.append(t)
	Events.hint.connect(listen)
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
	Events.hint.disconnect(listen)
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


## The goal says where: a fire in a village is the village fire, the one the
## player laid is theirs.
func test_the_goal_names_the_fire_it_sends_the_player_to() -> void:
	var g := Fx.flat()
	g.world.villages.append({"pos": g.player.pos + Vector2(4, 0), "country": Country.COAST, "name": "v"})
	var village_fire := Fx.put(g, PropKind.FIRE, Vector2(5, 0))
	check(Guide.goal(g).contains("at the village fire"), "the village's own: %s" % Guide.goal(g))
	eq(Guide.fire_name(g, village_fire), "the village fire")
	g.world.villages.clear()
	g.world.depleted[village_fire.id] = INF
	check(Guide.goal(g).contains("A fire before dark"), "no fire near: lay one: %s" % Guide.goal(g))
	var mine := Survival.build(g, &"fire", true)
	check(Guide.goal(g).contains("at your fire"), "one laid: %s" % Guide.goal(g))
	eq(Guide.fire_name(g, mine), "your fire")
	check(Guide.HINTS[&"worker"][0].contains("out of its path"), "the worker hint says what disturbs one")
	Fx.done(g)


## After a fight the goal comes back; after coming round from a downing, the
## goal once up, and no key hint until the hours have sunk in.
func test_the_goal_is_said_again_after_a_fight_and_keys_wait_after_a_downing() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var guide: Node = g.get_node("58_guide")
	var said: Array[String] = []
	var listen := func(t: String, _key: String) -> void: said.append(t)
	Events.hint.connect(listen)
	guide.call("_process", 2.0)
	eq(said.size(), 1, "the goal at wake")
	said.clear()
	Events.fight_ended.emit(&"downed")
	guide.call("_process", 1.0)
	eq(said.size(), 0, "nothing while the body lies there")
	guide.call("_process", 1.5)
	eq(said, [Guide.goal(g)] as Array[String], "up: the goal again")
	said.clear()
	for i in 8:
		guide.call("_process", 1.0)
	eq(said.size(), 0, "no key hint in the first seconds after coming round: %s" % [said])
	for i in 8:
		guide.call("_process", 1.0)
	gt(float(said.size()), 0.0, "then the hints resume")
	said.clear()
	Events.fight_ended.emit(&"won")
	for i in 3:
		guide.call("_process", 1.0)
	check(said.has(Guide.goal(g)), "a fight won: the goal again: %s" % [said])
	Events.hint.disconnect(listen)
	g.queue_free()
	await frames(1)


func test_a_lesson_names_the_key_that_actually_does_it() -> void:
	# **THE ONE PLACE A WRONG KEY COSTS THE MOST.** The lines used to carry their
	# letters -- "E takes what is in front of you" -- while a player may rebind
	# every action on the settings page. `PlayerSettings` is careful that a PAGE
	# can never drift from the live `InputMap`; the first thing the game ever
	# teaches was the one thing that could, and it would say E to somebody whose
	# key was Q, in the first hour, with no way of knowing which to believe.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var guide: Node = g.get_node("58_guide")
	if guide == null:
		g.free()
		return
	var line: String = guide.call("_spell", Guide.HINTS[&"take"][0], Guide.HINTS[&"take"][1])
	var was := PlayerSettings.key_of(&"use")
	check(line.contains(OS.get_keycode_string(was)), "the lesson names the key `use` is on: %s" % line)
	# Move it, and the lesson has to move with it.
	@warning_ignore("return_value_discarded")
	PlayerSettings.bind_key(&"use", KEY_Q)
	var moved: String = guide.call("_spell", Guide.HINTS[&"take"][0], Guide.HINTS[&"take"][1])
	check(moved.contains("Q"), "and follows it when it is rebound: %s" % moved)
	check(moved != line, "which is a different line from the one before")
	PlayerSettings.reset_keys()
	var back: String = guide.call("_spell", Guide.HINTS[&"take"][0], Guide.HINTS[&"take"][1])
	eq(back, line, "and comes back with the keys")
	g.free()


func test_the_game_teaches_the_key_that_reads_a_machine() -> void:
	# **THE VERB THE GUIDE NEVER NAMED.** A player can press 27 things and this
	# taught 11; targeting was one of the sixteen it did not, so the whole read
	# of a machine -- what it is, what it is doing, where its plate is thin --
	# belonged to whoever pressed an unmentioned key. It is said when the first
	# machine comes into view, ahead of the lines describing a runner and a
	# worker, because it is how you would find those out for yourself.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64", "--spawn=runner"])))
	var sim := g.player.sim
	var machine := false
	for m in sim.mobs:
		machine = machine or (m.alive and m.machine)
	check(machine, "a machine is in the world to be read")
	if not machine:
		g.free()
		return
	var offered := []
	for i in 6:
		var h := Guide.hint_for(g, {})
		offered.append(h.get("id", &""))
	check(offered.has(&"target"), "the lesson is offered with a machine in view, got %s" % str(offered[0]))
	# And holding the key spends it: doing the thing IS learning it.
	var guide: Node = g.get_node("58_guide")
	Input.action_press(&"target")
	guide.call("_watch")
	Input.action_release(&"target")
	check((guide.get("retired") as Dictionary).has(&"target"), "holding the key retires the lesson")
	g.free()


func test_the_game_teaches_the_jump_at_something_worth_jumping() -> void:
	# **INNATE AND UNTAUGHT.** Nothing grants the jump and nothing takes it away,
	# so a player who never learns it walks round every ledge the game meant them
	# to go over -- and it was one of the sixteen things the guide never named.
	# Said STANDING AT ONE, because a movement lesson given on flat ground is a
	# sentence about nothing.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=96"])))
	var sim := g.player.sim
	var spot := Jump.find(g.world, g.query, sim.hero.pos, Jump.UP, 40.0)
	if spot.is_empty():
		spot = Jump.find(g.world, g.query, sim.hero.pos, Jump.ACROSS, 40.0)
	check(not spot.is_empty(), "this world has a ledge to stand at")
	if spot.is_empty():
		g.free()
		return
	# On flat ground the lesson must NOT be offered -- that is the half that
	# stops it being said everywhere, which is what a key prompt on the glass is.
	var flat_ids := _offered(g)
	check(not flat_ids.has(&"jump"), "not said where a jump would do nothing")
	# Now stand at the ledge, facing it, the way the tour's `ledge` does.
	sim.hero.pos = spot.at
	sim.hero.facing = (spot.dir as Vector2).angle()
	g.player.pos = sim.hero.pos
	var at_ledge := _offered(g)
	check(at_ledge.has(&"jump"), "said standing at one, got %s" % str(at_ledge[0]))
	# And the feet leaving the ground spends it.
	var guide: Node = g.get_node("58_guide")
	sim.hero.airborne = true
	guide.call("_watch")
	check((guide.get("retired") as Dictionary).has(&"jump"), "jumping retires it")
	g.free()


func test_the_survey_is_offered_once_the_wake_is_out_of_sight() -> void:
	# The third of the sixteen, and the one the world's own size argues for: a
	# 1300-tile island is not a place anybody holds in their head. Said once the
	# wake is behind you, never before -- a survey of ground you can see is a
	# picture of nothing, and a lesson said everywhere is the key prompt on the
	# glass that docs/DESIGN.md forbids.
	var g := Fx.flat(200)
	# A few paces out, not standing ON the wake: at zero distance any threshold
	# passes, so the first version of this could not tell a lesson that waits
	# from one said everywhere. Five tiles is still well inside sight of home.
	var near_home: Vector2 = g.world.spawn + Vector2(5.0, 0)
	g.player.pos = near_home
	if g.player.sim != null:
		g.player.sim.hero.pos = near_home
	var at_home := _offered(g)
	check(not at_home.has(&"map"), "not while the wake is still in sight")
	# Walk out past it.
	var away: Vector2 = g.world.spawn + Vector2(Guide.MAP_FAR + 6.0, 0)
	g.player.pos = away
	if g.player.sim != null:
		g.player.sim.hero.pos = away
	var far := _offered(g)
	check(far.has(&"map"), "offered once it is not, got %s" % str(far[0]))
	Fx.done(g)


func test_crouching_is_taught_while_it_is_still_a_choice() -> void:
	# The pair to `target`: you have learned to look at a machine, now learn not
	# to be looked at. Said only with one in view that has NOT noticed you --
	# after it has, crouching is a regret rather than a choice, and a lesson
	# arriving then is the game telling you what you should have done.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64", "--spawn=hauler"])))
	var sim := g.player.sim
	var quiet: MobState = null
	for m in sim.mobs:
		if m.alive and m.machine and not m.roused():
			quiet = m
	check(quiet != null, "a machine is about that has not noticed the player")
	if quiet == null:
		g.free()
		return
	var offered := _offered(g)
	check(offered.has(&"crouch"), "offered while it has not seen you, got %s" % str(offered[0]))
	# Already crouching: the lesson has nothing to say.
	g.body.crouched = true
	var crouched := _offered(g)
	check(not crouched.has(&"crouch"), "and not while you already are")
	g.body.crouched = false
	# And doing it spends it.
	var guide: Node = g.get_node("58_guide")
	g.body.crouched = true
	guide.call("_watch")
	check((guide.get("retired") as Dictionary).has(&"crouch"), "crouching retires it")
	g.free()

## The lessons that apply right now, in the order the guide would say them.
##
## `hint_for` answers the FIRST one that is not retired, so calling it in a loop
## with an empty set returns the same lesson every time. Retiring each as it
## comes is how you see the list -- and a test that read the first answer alone
## was only passing when the lesson it wanted happened to be first.
func _offered(g: Game) -> Array:
	var out: Array = []
	var retired := {}
	for i in 12:
		var h := Guide.hint_for(g, retired)
		var id: StringName = h.get("id", &"")
		if id == &"":
			break
		out.append(id)
		retired[id] = true
	return out


func test_building_is_taught_when_the_creel_can_actually_build() -> void:
	# A whole pillar of the game nobody was told about (VISION §9): a player can
	# put a place up, keep it, and have the machines come for it. Said the first
	# time the creel really holds enough for a piece -- before that the lesson is
	# an advertisement, which is the thing a key prompt on the glass always is.
	var g := Fx.flat(60)
	check(not _offered(g).has(&"holding"), "not with an empty creel")
	# Fill it until something is buildable, the way play would.
	var want := StructureKind.BUILDABLE[0]
	for id: StringName in (SettlementBuild.missing(g.inventory, want) as Dictionary):
		g.inventory.add(id, int((SettlementBuild.missing(g.inventory, want) as Dictionary)[id]))
	check(SettlementBuild.can_make(g.inventory, want), "the creel now holds a piece")
	check(_offered(g).has(&"holding"), "offered once it does")
	Fx.done(g)
