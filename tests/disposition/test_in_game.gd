extends TestCase
## Reachable from a normal game start: the crouch key is a real key, the moment
## carries what the player is doing about being noticed, a region that heats
## changes what every machine in it makes of the player, the slate reads it,
## and it all comes back out of a save.


func _game(args: PackedStringArray) -> Game:
	var o := BootOptions.parse(args)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func _system(g: Game) -> Node:
	return g.get_node("32_disposition")


func test_the_crouch_key_gets_the_player_down_and_the_world_reads_it() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(3)
	var body := g.body
	var m := g.player.sim.moment
	check(not body.crouched, "standing to begin with")
	check(not g.player.model.crouched, "and the figure is standing")
	near(m.loudness, StealthNoise.loudness(0.0, g.world.ground_at(floori(g.player.pos.x), floori(g.player.pos.y)), false, 0), 0.05,
		"standing still, the coast hears almost nothing of them")
	Input.action_press(&"crouch")
	await frames(3)
	check(body.crouched, "the crouch key gets them down")
	check(m.crouched, "the simulation knows")
	check(g.player.hero.crouched, "and so does the body that moves")
	check(g.player.model.crouched, "and the figure is drawn down")
	# Real keys: move and run held, crouched and then standing.
	Input.action_press(&"move_right")
	Input.action_press(&"run")
	var from := g.player.pos
	await frames(24)
	var crept := from.distance_to(g.player.pos)
	Input.action_release(&"crouch")
	await frames(4)
	check(not body.crouched, "and back up when it is let go")
	var stood_from := g.player.pos
	await frames(24)
	var walked := stood_from.distance_to(g.player.pos)
	Input.action_release(&"move_right")
	Input.action_release(&"run")
	gt(crept, 0.0, "creeping still gets you there")
	lt(crept, walked * 0.8, "but it is a good deal slower, and Shift does not help")
	g.queue_free()
	await frames(1)


func test_the_moment_carries_cover_and_a_lit_lamp_takes_it_away() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=23", "--weather=clear:0"]))
	await frames(3)
	var m := g.player.sim.moment
	gt(m.cover, 0.0, "the night is cover of its own")
	g.body.lamp_lit = true
	await frames(3)
	eq(m.cover, 0.0, "a lit lamp is no cover at all")
	g.queue_free()
	await frames(1)


func test_a_region_that_heats_turns_the_workers_in_it_and_cools_again() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--spawn=harvester"]))
	await frames(3)
	var sys := _system(g)
	var sim := g.player.sim
	eq(sim.living(), 1, "a harvester at its work")
	var h: MobState = sim.mobs[0]
	eq(h.role, Roles.WORKER)
	eq(h.disposition, &"indifferent", "and it takes no notice of the player")
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	f.levels[net] = Interference.THRESHOLDS[2] + 0.01
	await frames(30)
	eq(h.disposition, &"hostile", "a region at hostile: even the harvest comes for you")
	var mob := h.node as Mob
	var model := mob.model as MachineModel
	check(model != null, "a machine is drawn by a MachineModel")
	if model != null:
		eq(model.disposition, &"hostile", "and its status lamps blink what it thinks")
	f.levels.erase(net)
	await frames(30)
	eq(h.disposition, &"indifferent", "once the file is cold it goes back to work")
	g.queue_free()
	await frames(1)


func test_killing_a_worker_raises_the_network_and_a_hunter_raises_it_less() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(3)
	var sys := _system(g)
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	var at := g.world.to_3d(g.player.pos)
	Events.killed.emit(&"harvester", at)
	await frames(2)
	var worker := f.value(net)
	near(worker, Interference.CAUSES[&"killed_worker"], 1e-4, "a dead worker is filed")
	Events.killed.emit(&"runner", at)
	await frames(2)
	near(f.value(net) - worker, Interference.CAUSES[&"killed_machine"], 1e-4, "a dead hunter is filed for less")
	Events.killed.emit(&"dog.yard", at)
	await frames(2)
	near(f.value(net), worker + Interference.CAUSES[&"killed_machine"], 1e-4, "a dead dog is nothing to the plan")
	g.queue_free()
	await frames(1)


func test_being_filed_and_being_out_in_a_keepers_hours_both_reach_the_network() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=22", "--weather=clear:0", "--spawn=warden"]))
	await frames(3)
	var sys := _system(g)
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	# A clerk that got its reading away: the body carries the filing, and so does
	# the network the player was read in.
	g.body.filed += 1
	await frames(30)
	near(f.value(net), Interference.CAUSES[&"filed"], 2e-3, "a filing is on the record")
	# And a warden that has you at its own hours is a broken curfew.
	var w: MobState = g.player.sim.mobs[0]
	eq(w.role, Roles.KEEPER, "a warden keeps its site and its hours")
	# Well off across the land, so it is coming for the player and not yet on them.
	w.pos = g.player.pos + Vector2(22.0, 0.0)
	w.home = w.pos
	w.set_mood(MobState.CHASING, g.player.sim.now)
	await frames(30)
	near(f.value(net), Interference.CAUSES[&"filed"] + Interference.CAUSES[&"curfew"], 2e-3, "and so is the curfew")
	g.queue_free()
	await frames(1)


func test_a_rise_is_felt_in_the_world_and_never_written_on_the_screen() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--spawn=watcher"]))
	await frames(3)
	var sys := _system(g)
	var sim := g.player.sim
	var w: MobState = sim.mobs[0]
	eq(w.role, Roles.WATCHER)
	var lines: Array[String] = []
	Events.message.connect(func(t: String) -> void: lines.append(t))
	var horns: Array[StringName] = []
	Events.sfx.connect(func(n: StringName, _at: Vector3) -> void: horns.append(n))
	var f: Interference = sys.get(&"interference")
	f.levels[Interference.network(g.world, g.player.pos)] = Interference.THRESHOLDS[1] + 0.05
	await frames(40)
	check(w.look_until > sim.now or w.roused(), "the watcher turns toward the player")
	check(horns.has(&"works_horn"), "and a horn goes off at a works over the land")
	eq(lines.size(), 0, "nothing is said: the world says it")
	g.queue_free()
	await frames(1)


func test_the_slate_reads_the_network_and_every_machine_in_range() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--spawn=harvester,runner"]))
	await frames(3)
	var sys := _system(g)
	sys.call(&"raise", &"theft", g.player.pos)
	await frames(3)
	var feed := SlateFeeds.feed(&"reads", g)
	gt(float(feed.interference), 0.0, "the slate knows the network has filed something")
	check(String(feed.network).length() > 0, "and which network")
	var by_kind: Dictionary = {}
	for s: Dictionary in feed.scans:
		by_kind[s.kind] = s.disposition
	eq(by_kind.get(&"harvester"), &"indifferent", "the harvester is about its work")
	eq(by_kind.get(&"runner"), &"hostile", "the runner is not")
	g.queue_free()
	await frames(1)


func test_stripping_a_machines_own_works_turns_every_worker_that_can_see_it() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--spawn=harvester"]))
	await frames(3)
	var sys := _system(g)
	var sim := g.player.sim
	var h: MobState = sim.mobs[0]
	check(h.indifferent(), "a harvester about its work")
	var net := Interference.network(g.world, g.player.pos)
	var mast := Survival.add_prop(g, PropKind.RELAY, g.player.pos + Vector2(1.4, 0.0))
	g.player.facing = 0.0
	g.player.hero.facing = 0.0
	check(Takes.is_plan_work(mast.kind), "a relay mast belongs to the plan")
	check(Survival.work(g, mast), "and a bare hand can open it")
	await frames(6)
	check(h.disturbed, "the harvester stops working and turns on the thief")
	eq(h.disturbed_by, &"theft")
	eq(h.disposition, &"hostile")
	gt((sys.get(&"interference") as Interference).value(net), 0.0, "and the network files the theft")
	check(sys.call(&"tour_seen", &"theft"), "the tour can see it happen")
	g.queue_free()
	await frames(1)


func test_a_hunted_network_sends_a_hunter_and_a_calm_one_does_not() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(3)
	var sys := _system(g)
	var sim := g.player.sim
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	var coast: Node = g.get_node("30_mobs")
	(coast.get(&"coast") as Coast).spawning = false
	sim.clear_mobs()
	await frames(20)
	eq(sim.living(), 0, "a calm coast sends nothing")
	f.levels[net] = Interference.THRESHOLDS[3] + 0.05
	eq(f.level(net), 3, "hunted")
	await frames(40)
	gt(float(sim.living()), 0.0, "the network sends something after the player")
	var sent: MobState = sim.mobs[0]
	eq(Roles.of(sent.kind), Roles.HUNTER, "and what it sends is a hunter")
	gt(sent.pos.distance_to(g.player.pos), 10.0, "come from off over the land, not out of the air beside them")
	check(sys.call(&"tour_seen", &"hunter"))
	g.queue_free()
	await frames(1)


func test_interference_is_saved_and_comes_back() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(3)
	var sys := _system(g)
	var net := Interference.network(g.world, g.player.pos)
	sys.call(&"raise", &"killed_worker", g.player.pos)
	await frames(3)
	var before := (sys.get(&"interference") as Interference).value(net)
	gt(before, 0.0, "something was filed")
	check(SaveGame.registered(&"disposition"), "the system registered its own state")
	var data := SaveGame.collect()
	var text := JSON.stringify(data)
	var back := JSON.parse_string(text) as Dictionary
	(sys.get(&"interference") as Interference).levels.clear()
	SaveGame.apply({"disposition": back["disposition"]})
	near((sys.get(&"interference") as Interference).value(net), before, 1e-4, "and it comes back off the file")
	g.queue_free()
	await frames(1)
