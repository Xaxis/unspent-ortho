extends TestCase
## Reachable from a normal game start: the crouch key is a real key, the moment
## carries what the player is doing about being noticed, a region that heats
## changes what every machine in it makes of the player, the slate reads it,
## and it all comes back out of a save.
##
## Every cause the plan files is tested here through the thing that produces it
## in play (a blow on Events.hit, a body turned through FightSim.disturb, a
## clerk's filing on Body.filed), never by calling Interference.raise: a rule
## that is only ever exercised by its own unit test is a rule the game does not
## have.

const Sx := preload("res://tests/save/save_fixture.gd")


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
	near(worker, Interference.CAUSES[&"killed_worker"], 5e-3, "a dead worker is filed")
	Events.killed.emit(&"runner", at)
	await frames(2)
	near(f.value(net) - worker, Interference.CAUSES[&"killed_machine"], 5e-3, "a dead hunter is filed for less")
	Events.killed.emit(&"dog.yard", at)
	await frames(2)
	near(f.value(net), worker + Interference.CAUSES[&"killed_machine"], 5e-3, "a dead dog is nothing to the plan")
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
	check(f.counted.has("%d|filed" % net), "a filing is on the record")
	# And a warden that has you at its own hours is a broken curfew.
	var w: MobState = g.player.sim.mobs[0]
	eq(w.role, Roles.KEEPER, "a warden keeps its site and its hours")
	# Well off across the land, so it is coming for the player and not yet on them.
	w.pos = g.player.pos + Vector2(22.0, 0.0)
	w.home = w.pos
	w.set_mood(MobState.CHASING, g.player.sim.now)
	await frames(30)
	check(f.counted.has("%d|curfew" % net), "and so is the curfew")
	# Both, each worth itself and each counted once however many beats went by.
	var both: float = Interference.CAUSES[&"filed"] + Interference.CAUSES[&"curfew"]
	gt(f.value(net), both * 0.9, "the network carries both")
	lt(f.value(net), both + 1e-4, "and neither twice")
	g.queue_free()
	await frames(1)


## Events.hit carries NODES, not fighters (40_fight._node_of): a guard written
## against MobState is a branch the game can never take.
func test_striking_a_machine_at_its_work_is_filed_but_a_fight_it_started_is_not() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--spawn=harvester"]))
	await frames(3)
	var sys := _system(g)
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	var h: MobState = g.player.sim.mobs[0]
	check(h.node is Mob, "a blow lands on the body's node")
	eq(f.value(net), 0.0, "nothing filed yet")
	Events.hit.emit(g.player, h.node, 6, false, g.world.to_3d(h.pos))
	await frames(3)
	near(f.value(net), Interference.CAUSES[&"sabotage"], 5e-3, "damage to the plan's own is sabotage")
	# The same blow thrown at something that is already coming for the player is
	# not: defending yourself from what was sent after you cannot be the thing
	# that keeps the hunt alive.
	h.disturbed = true
	await frames(3)
	var before := f.value(net)
	f.counted.clear()
	Events.hit.emit(g.player, h.node, 6, false, g.world.to_3d(h.pos))
	await frames(3)
	near(f.value(net), before, 5e-3, "a blow in a fight the machines started files nothing")
	g.queue_free()
	await frames(1)


## blocked and trespass had no producer at all: they were rows in a table.
func test_being_in_the_way_reaches_the_network_without_anyone_filing_it() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--spawn=harvester"]))
	await frames(3)
	var sys := _system(g)
	var sim := g.player.sim
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	var h: MobState = sim.mobs[0]
	sim.disturb(h, &"blocked")
	check(h.disturbed and h.disturbed_by == &"blocked", "held up past its patience, it turns")
	await frames(20)
	check(f.counted.has("%d|blocked" % net), "and it reports what it took amiss")
	near(f.value(net), Interference.CAUSES[&"blocked"], 5e-3)
	g.queue_free()
	await frames(1)


func test_standing_on_the_site_a_keeper_holds_turns_it_and_is_filed() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--spawn=warden"]))
	await frames(3)
	var sys := _system(g)
	var sim := g.player.sim
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	var w: MobState = sim.mobs[0]
	eq(w.role, Roles.KEEPER)
	eq(w.disposition, &"wary", "a warden is born wary and stays there until it has a reason")
	check(not w.disturbed, "and has nothing against the player")
	# Its post is the ground the player is standing on, and it has them.
	w.home = g.player.pos
	w.pos = g.player.pos + Vector2(3.0, 0.0)
	w.suspicion = 1.0
	await frames(30)
	check(w.disturbed, "a keeper does not share its site")
	eq(w.disturbed_by, &"trespass")
	check(f.counted.has("%d|trespass" % net), "and the plan files the trespass")
	check(sys.call(&"tour_seen", &"trespass"))
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


## Being hunted has to be a thing a player can come out the far side of: the
## network can only have so many out at once, and what it sent and lost is not
## filed against the player who took it down.
func test_a_hunted_network_sends_only_so_many_and_does_not_file_its_own_losses() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(3)
	var sys := _system(g)
	var sim := g.player.sim
	var f: Interference = sys.get(&"interference")
	var net := Interference.network(g.world, g.player.pos)
	var coast: Node = g.get_node("30_mobs")
	(coast.get(&"coast") as Coast).spawning = false
	sim.clear_mobs()
	f.levels[net] = Interference.THRESHOLDS[3] + 0.05
	# Five chances to send, with the wait between them taken away each time.
	for i in 5:
		sys.set(&"_dispatch_at", -INF)
		sys.call(&"_dispatch")
	eq(sim.living(), 2, "it keeps two out after the player, not a queue of them")
	var sent: MobState = sim.mobs[0]
	check(sent.sent, "and they are marked as its own")
	var before := f.value(net)
	sent.alive = false
	Events.killed.emit(sent.kind, g.world.to_3d(sent.pos))
	await frames(3)
	near(f.value(net), before, 5e-3, "what it sent and lost is no news to the network that sent it")
	# The same kill, on one of the plan's own workers, with room on the file for
	# it to show. It has to die in the SAME network to be that network's news:
	# a network is a region now, and seven tiles off this spawn is already a
	# different landscape with its own file on the player.
	f.levels[net] = 0.3
	var low := f.value(net)
	var where := g.player.pos + Vector2(2.0, 0.0)
	eq(Interference.network(g.world, where), net, "the worker dies in this network")
	var other := sim.add_mob(&"harvester", where)
	other.alive = false
	Events.killed.emit(&"harvester", g.world.to_3d(other.pos))
	await frames(3)
	near(f.value(net) - low, Interference.CAUSES[&"killed_worker"], 5e-3, "a worker of the harvest is")
	g.queue_free()
	await frames(1)


## Every field this system holds ABOUT the clock, the body and the place has to
## be taken again in started(): 05_save only restores them there, after every
## setup has run. Getting this wrong decays a whole saved file away on the first
## frame, files the player for a clerk that read them before the save, and blows
## the horn over it.
func test_a_loaded_game_keeps_its_file_and_does_not_open_by_filing_the_player() -> void:
	Sx.use_root("disposition-load")
	var a := Sx.game(tree, ["--seed=1", "--size=64", "--hour=22", "--weather=clear:0"])
	await frames(3)
	var net := Interference.network(a.world, a.player.pos)
	var fa: Interference = Sx.system(a, "32_disposition").get(&"interference")
	fa.levels[net] = 0.6
	fa.scenes[net] = a.player.pos
	a.body.filed = 2
	a.clock.skip(2.0 * 1440.0)
	eq(Sx.system(a, "05_save").call("save_to", 3), "", "saved to slot 3")
	Sx.end(a)

	var horns: Array[StringName] = []
	var heard := func(n: StringName, _at: Vector3) -> void: horns.append(n)
	Events.sfx.connect(heard)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(3, o), "", "slot 3 boots")
	# The world is made at the default hour and the clock only arrives in
	# started(), which is what any door into a save that does not carry the hour
	# would do. The file must survive the gap either way.
	o.hour = Tuning.START_HOUR
	var b := Sx.game(tree, [], o)
	var fb: Interference = Sx.system(b, "32_disposition").get(&"interference")
	near(fb.value(net), 0.6, 1e-3, "the file comes back off the save")
	await frames(20)
	gt(fb.value(net), 0.55, "and is still there: no gap between two clocks decayed it away")
	check(not fb.counted.has("%d|filed" % net), "a filing from before the save is not filed again")
	check(not horns.has(&"works_horn"), "and no horn goes off over a night that is already over")
	Events.sfx.disconnect(heard)
	Sx.end(b)
	Sx.finish()


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
