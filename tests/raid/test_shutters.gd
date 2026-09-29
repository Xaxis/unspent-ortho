extends TestCase
## SHUTTERS ON THE BEDS (slice 2 step 4): warned of a raid, a holding with its
## beds shuttered sends its people in behind the boards (Settlement.inside), and
## nothing is worked while they are in. A snatcher has to break the boards before
## it can take anybody behind them, and on paper it needs twice the force.
## Measured before (seed 4): a raid on an open holding carried one person out
## live, and a siege he was away for took one on paper.

const Sx := preload("res://tests/save/save_fixture.gd")


## A holding of a hut, a bunk and a plot with two living there, `shut` or not.
func _holding(shut: bool) -> Settlement:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(20, 20))
	for k: int in [StructureKind.HUT, StructureKind.BUNK, StructureKind.PLOT]:
		@warning_ignore("return_value_discarded")
		s.add(k, Vector2(20, 20) + Vector2.from_angle(float(k)) * 2.0)
	if shut:
		@warning_ignore("return_value_discarded")
		s.add(StructureKind.SHUTTERS, Vector2(21, 20))
	for i in 2:
		s.people.append(s.take_person_id())
	return s


func test_on_paper_a_siege_takes_nobody_from_behind_the_shutters() -> void:
	var open := _holding(false)
	open.inside = true
	var bare := RaidResolve.resolve(open, RaidStage.SIEGE, 4, 1)
	eq((bare.took as Array).size(), 1, "an open holding loses one to a siege settled on paper")
	var shut := _holding(true)
	shut.inside = true
	check(shut.all_barred(), "gone in, every one of them is behind the boards")
	var kept := RaidResolve.resolve(shut, RaidStage.SIEGE, 4, 1)
	eq((kept.took as Array).size(), 0, "shuttered and in, the snatcher's share is not enough to break through")
	shut.inside = false
	eq(shut.barred(), 0, "out, the boards bar nobody")


func test_nothing_is_worked_while_they_are_in() -> void:
	var s := _holding(true)
	s.inside = true
	eq(SettlementRules._works_factor(s), 0.0, "in behind the shutters, nobody is out working")
	s.inside = false
	gt(SettlementRules._works_factor(s), 0.0, "out, they are")


## The live snatcher at a holding whose people are all in: while the boards stand
## it is at them and takes nobody (the flock that snatches has no bite of its own,
## so it tears at them and goes); once something has broken them, it takes one
## when its wait is up, as it does at an open holding.
func _snatch(shut: bool, break_after: int) -> Dictionary:
	Sx.use_root("shutters")
	var pieces := "hut,bunk,plot" + (",shutters" if shut else "")
	var g := Sx.game(tree, ["--seed=4", "--size=64", "--hour=10", "--holding=" + pieces])
	await frames(3)
	var coast: Coast = Sx.system(g, "30_mobs").get("coast")
	coast.spawning = false
	coast.rounds = false
	var sim: FightSim = g.player.sim
	sim.clear_mobs()
	var sys := Sx.system(g, "48_raids")
	var s: Settlement = Sx.system(g, "46_settlements").call("here")
	while s.people.size() < 2:
		s.people.append(s.take_person_id())
	s.inside = true
	g.player.hero.pos = s.centre + Vector2(40, 0)
	g.player.pos = g.player.hero.pos
	var plan := RaidPlan.new()
	plan.stage = RaidStage.RAID
	var m := sim.add_mob(RaidRoles.kind_for(RaidRoles.SNATCHER), s.centre + Vector2(1.5, 0.0))
	m.raider = true
	var r := {"plan": plan.id, "role": RaidRoles.SNATCHER, "target": -1, "settlement": s.id, "since": sim.now,
		"strike_at": -INF, "closest": INF, "stalled_at": sim.now, "side": 1.0}
	var people0 := s.people.size()
	var held := s.people.size()
	# Each phase well past a snatcher's wait in the yard (SNATCH_MS), in frames.
	for i in 960:
		await frames(1)
		if i == break_after and s.shutter_to_break() != null:
			held = s.people.size()
			s.destroy_structure(s.shutter_to_break().id)
		if m.removed or not m.alive:
			break
		sys.call("_drive_snatcher", plan, s, m, r, sim)
	var out := {"people0": people0, "held": held, "people": s.people.size(), "tore": bool(r.get("tore", false))}
	Sx.end(g)
	Sx.finish()
	return out


func test_a_snatcher_must_break_the_boards_first() -> void:
	var open: Dictionary = await _snatch(false, -1)
	eq(int(open.people), int(open.people0) - 1, "at an open holding it takes one when its wait is up")
	var shut: Dictionary = await _snatch(true, 480)
	check(bool(shut.tore), "behind the shutters it goes for the boards")
	eq(int(shut.held), int(shut.people0), "and while they stand it takes nobody")
	eq(int(shut.people), int(shut.people0) - 1, "the boards broken, it takes one as it would have")


func test_the_warning_sends_them_in_and_the_end_lets_them_out() -> void:
	Sx.use_root("shutters")
	var g := Sx.game(tree, ["--seed=4", "--size=64", "--hour=10", "--holding=hut,bunk,plot,shutters"])
	await frames(3)
	var sys := Sx.system(g, "48_raids")
	var s: Settlement = Sx.system(g, "46_settlements").call("here")
	while s.people.size() < 2:
		s.people.append(s.take_person_id())
	var said: Array[String] = []
	var hear := func(t: String) -> void: said.append(t)
	Events.message.connect(hear)
	sys.call("_warn", s, RaidStage.SURVEY)
	check(not s.inside, "a survey is only looked at: nobody goes in for it")
	sys.call("_warn", s, RaidStage.RAID)
	check(s.inside, "warned of a raid, they go in behind the shutters")
	check(said.has(StoryContent.DEFEND["in"] % s.name), "and the glass says so")
	var plan: RaidPlan = (sys.get("plans") as Array).back()
	sys.call("_end", plan, s, &"held")
	check(not s.inside, "the raid over, they come out")
	check(said.has(StoryContent.DEFEND["held_raid"] % s.name), "everybody who went in")
	Events.message.disconnect(hear)
	Sx.end(g)
	Sx.finish()
