extends TestCase
## THE CROWD READER (tests/fight/crowd_reader.gd): the measure every
## multi-machine number is taken with. Two cutters roused shoulder to shoulder,
## a careful player with the start knife, 24 bouts (eight starts round the
## compass, three runs of body ids each).
## The one-machine reader locks on the nearest and is flanked; a player who
## keeps the crowd on one side and strikes only the open one wins it.

const F := preload("res://tests/fight/fixture.gd")
const Reader := preload("res://tests/fight/reader.gd")
const CrowdReader := preload("res://tests/fight/crowd_reader.gd")
const ShoulderReader := preload("res://tests/fight/shoulder_reader.gd")

const TOOL := &"knife"
## Eight starts round the compass, each with three runs of body ids (they steer
## side-steps): one start's luck is not the measure.
const BOUTS := 24


## One gate bout: {won, downed, t, health_lost}. `kit` is what is fitted.
static func gate(crowd_reader: bool, start: int, kind: StringName = &"runner", count: int = 2,
		kit: Array[StringName] = [], seconds: float = 120.0, tool: StringName = TOOL, charges: int = 0, ids: int = 1000,
		shoulder := false, wind := 0.0, human := -1) -> Dictionary:
	# A body's id steers its side-steps (Brains); ids count up across a run, so
	# without this a bout's outcome would hang on how many ran before it.
	MobState._next_id = ids
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.moment.wind = wind
	if charges > 0:
		sim.hero.inventory.add(FightRules.CHARGE, charges)
	sim.hero.inventory.add(tool)
	sim.hero.inventory.set_held(tool)
	sim.hero.kit = FightKit.of(kit)
	var a := float(start) / 8.0 * TAU
	var mid := sim.hero.pos + Vector2.from_angle(a) * 5.0
	var side := Vector2.from_angle(a).orthogonal()
	var crowd: Array[MobState] = []
	for k in count:
		var m := sim.add_mob(kind, mid + side * (float(k) - 0.5 * float(count - 1)) * 1.1)
		m.facing = (sim.hero.pos - m.pos).angle()
		m.aim = m.facing
		# Roused as the game rouses a worker (FightSim._wake): turned on the
		# player, not at its work. Chasing and still `indifferent` is a state the
		# game never makes, and every reader takes it as a body not minding them.
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		crowd.append(m)
	# `shoulder`: the crowd reader as a player over the shoulder knows the fight
	# (tests/fight/shoulder_reader.gd), facing the crowd as it starts.
	var player: Variant = ShoulderReader.new(sim) if shoulder else (CrowdReader.new(sim) if crowd_reader else Reader.new(sim))
	# The measuring reader's human limits (Reader.human; tools/sweep.sh only).
	player.human = human
	if shoulder:
		sim.hero.facing = (mid - sim.hero.pos).angle()
	var t := 0.0
	var lost := 0
	var raked := 0
	var stripped := 0
	var cabled := 0
	while t < seconds * 1000.0:
		player.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
			if e.type == &"stripped":
				stripped += 1
			if e.type == &"cabled":
				cabled += 1
			if e.type == &"rake":
				raked += (e.bodies as Array).size()
			if e.type == &"outcome" and e.outcome in [&"downed", &"carried"]:
				return {"won": false, "downed": true, "t": t / 1000.0, "lost": lost, "heavies": int(player.heavies), "raked": raked, "stripped": stripped, "cabled": cabled}
		var left := 0
		for m in crowd:
			# A stripped machine (FightKit.unbuild) has no bite left: the fight
			# with it is over.
			left += int(m.alive and not m.stripped)
		if left == 0:
			return {"won": true, "downed": false, "t": t / 1000.0, "lost": lost, "heavies": int(player.heavies), "raked": raked, "stripped": stripped, "cabled": cabled}
	return {"won": false, "downed": false, "t": t / 1000.0, "lost": lost, "heavies": int(player.heavies), "raked": raked, "stripped": stripped, "cabled": cabled}


func test_the_crowd_reader_wins_what_the_single_reader_loses() -> void:
	var single := 0
	var crowd := 0
	var times := 0.0
	for i in BOUTS:
		single += int(gate(false, i % 8, &"cutter", 2, [], 120.0, TOOL, 0, 1000 + i / 8).won)
		var r := gate(true, i % 8, &"cutter", 2, [], 120.0, TOOL, 0, 1000 + i / 8)
		crowd += int(r.won)
		if r.won:
			times += float(r.t)
	print("  info two cutters at a gate, knife: the single reader wins %d of %d, the crowd reader %d (mean %.1f s)" % [single, BOUTS, crowd, times / maxf(crowd, 1)])
	gt(crowd, single + 3, "a player who keeps the crowd on one side wins more of it")
	gt(crowd, BOUTS * 2 / 3 - 1, "and wins most of it")


func test_a_walk_round_that_gains_nothing_is_given_up_and_the_keeper_let_come() -> void:
	# The stooped Reaper turns faster than a person goes round it, and does not
	# sweep a flank. A player who kept running for its back was never square to
	# strike and never bitten, for minutes. Seeing its face stay on them, they let
	# it come: its grip is dodged, and the stand after is the way to its back.
	MobState._next_id = 1000
	var def := Sentinels.for_land(&"coast")
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"axe_felling")
	sim.hero.inventory.set_held(&"axe_felling")
	sim.hero.kit = FightKit.of([])
	var m := sim.add_mob(def.kind, sim.hero.pos + Vector2(0.0, -1.8))
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, def.phases.size() - 1)
	# Facing away: the player starts a quarter off its stern, where the walk round began.
	m.facing = -PI * 0.5 - 0.75
	m.aim = m.facing
	m.disturbed = true
	m.set_mood(MobState.ATTACKING, sim.now)
	var r := ShoulderReader.new(sim)
	r.human = 11
	var before := m.health
	var t := 0.0
	while t < 30000.0 and m.health == before:
		r.act()
		sim.slices(2)
		t += 16.0
	lt(float(m.health), float(before), "the keeper was struck within 30 s (%.1f s)" % (t / 1000.0))
