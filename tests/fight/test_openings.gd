extends TestCase
## The working side is learnable and reachable: every machine that bites is
## spent after a bite it missed (it says so, and its part flares), turns slowly
## while spent and between runs, and turns slower than a player walks round it
## at close quarters. A bite that lands opens nothing. A body only bites what it
## faces. Workers are indifferent until struck or stood in the way of.

const F := preload("res://tests/fight/fixture.gd")


static func _biters() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in Roster.kinds():
		var r := Roster.row(k)
		if r.get("machine", false) and r.has("bite"):
			out.append(k)
	return out


func test_every_biting_machine_is_spent_after_a_bite_that_missed() -> void:
	for kind in _biters():
		var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
		# Far to one side: the bite goes past nobody.
		sim.hero.pos = Vector2(20.5, 40.5)
		var m := F.still(sim, kind, Vector2(20.5, 20.5), 0.0)
		m.calm_until = INF
		m.start_blow(m.bite, sim.now)
		var events: Array[Dictionary] = []
		F.ms(sim, m.bite.windup + m.bite.active + 8)
		events.append_array(sim.drain())
		eq(F.count(events, &"opened"), 1, "%s says its bite is spent" % kind)
		check(m.spent(sim.now), "%s is spent after its bite" % kind)
		var window := m.bite.recovery + m.bite.cooldown
		gt(float(window), 600.0, "%s stays spent long enough to be reached (%d ms)" % [kind, window])
		F.ms(sim, m.bite.recovery + 16)
		lt(m.turn_rate_at(sim.now), FightRules.RECOVER_TURN + 0.001, "%s turns slowly while spent" % kind)


func test_a_bite_that_lands_opens_nothing() -> void:
	var sim := F.make_sim()
	var m := F.still(sim, &"runner", Vector2(21.5, 20.5), PI)
	sim.hero.pos = Vector2(20.5, 20.5)
	m.start_blow(m.bite, sim.now)
	F.ms(sim, m.bite.windup + m.bite.active + 16)
	var events := sim.drain()
	eq(F.count(events, &"hurt"), 1, "the bite met the player")
	eq(F.count(events, &"opened"), 0, "and nothing opened")
	check(not m.spent(sim.now), "not spent")
	lt(float(m.blow.recovery + m.blow.cooldown), float(m.bite.recovery + m.bite.cooldown), "and ready again sooner")


func test_machines_turn_slower_than_a_player_walks_round_them() -> void:
	var knife := Blow.for_item(&"knife", 5000)
	for kind in Roster.kinds():
		var r := Roster.row(kind)
		if not r.get("machine", false) or r.get("part", &"none") == &"none":
			continue
		var m := MobState.new(kind, Vector2(10, 10))
		var circle := m.radius + Tuning.PLAYER_RADIUS + knife.reach * 0.5
		lt(m.turn_rate, Tuning.WALK_SPEED / circle, "%s tracks a walking player round it (%.2f rad/s)" % [kind, m.turn_rate])


func test_a_runner_that_misses_leaves_its_back_to_a_dodge() -> void:
	# The rule the first meeting teaches: out of the bite aside, and its overrun
	# leaves its back within a walk before it has wound back.
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var r := F.still(sim, &"runner", Vector2(21.8, 20.5), PI)
	r.calm_until = 0.0
	r.disturbed = true
	r.set_mood(MobState.ATTACKING, sim.now)
	Brains.bite(r, sim)
	# Seen after a human's reaction, dodged aside.
	F.ms(sim, 220)
	sim.hero.move = Vector2(0, 1)
	sim.press_dodge()
	F.ms(sim, r.bite.windup - 220 + r.bite.active + 24)
	eq(F.count(sim.drain(), &"hurt"), 0, "the bite went past")
	check(r.spent(sim.now), "spent")
	var reached := false
	while r.spent(sim.now) and not reached:
		var back := r.pos - Vector2.from_angle(r.facing) * (r.radius + sim.hero.radius + 0.45)
		var to := back - sim.hero.pos
		sim.hero.move = to.normalized() if to.length() > 0.1 else Vector2.ZERO
		sim.slices(2)
		reached = FightRules.side_of(r.pos, r.facing, sim.hero.pos) == &"back" and sim.hero.pos.distance_to(r.pos) < r.radius + sim.hero.radius + 1.0
	check(reached, "a walk reached its back before it wound back")


func test_walking_into_a_standing_machine_slides_round_to_its_back() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var r := F.still(sim, &"runner", Vector2(21.9, 20.5), PI)
	r.bite = null
	var back := r.pos + Vector2(r.radius + sim.hero.radius + 0.45, 0)
	var reached := false
	for i in 150:
		sim.hero.move = (back - sim.hero.pos).normalized()
		sim.slices(1)
		if sim.hero.pos.distance_to(back) < 0.25:
			reached = true
			break
	check(reached, "straight at its back through its body, the walk went round (%s)" % sim.hero.pos)
	lt(float(sim.now), 1400.0, "in about a second (%d ms)" % sim.now)


func test_a_machine_only_bites_what_it_faces() -> void:
	var sim := F.make_sim()
	var r := F.still(sim, &"runner", Vector2(21.2, 20.5), 0.0)
	# The player is at its back, in strike range.
	sim.hero.pos = Vector2(20.5, 20.5)
	r.calm_until = 0.0
	r.disturbed = true
	r.set_mood(MobState.ATTACKING, sim.now)
	F.ms(sim, 200)
	eq(F.count(sim.drain(), &"windup"), 0, "no bite at the air in front of it")


func test_an_indifferent_worker_sees_the_player_and_works_on() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := sim.add_mob(&"harvester", Vector2(26.5, 20.5))
	h.facing = PI
	F.ms(sim, 3000)
	var events := sim.drain()
	eq(F.count(events, &"alerted"), 0, "it does not rouse")
	check(not h.roused(), "and does not come for the player")
	eq(sim.fight_on, false, "nothing to fight")
	gt(float(F.count(events, &"noticed")), 0.0, "though it looks up")


func test_struck_a_worker_turns_on_the_player() -> void:
	var sim := F.make_sim()
	var h := F.still(sim, &"harvester", Vector2(22.5, 20.5), PI)
	h.calm_until = 0.0
	sim.hero.pos = h.pos + Vector2(-(h.radius + sim.hero.radius + 0.3), 0)
	sim.press_swing()
	F.ms(sim, 200)
	var events := sim.drain()
	eq(F.count(events, &"disturbed"), 1, "disturbed")
	check(h.roused(), "and roused")


func test_stood_in_its_way_a_worker_warns_then_turns_on_the_player() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := sim.add_mob(&"hauler", Vector2(23.0, 20.5))
	h.facing = PI
	h.aim = PI
	h.line_a = Vector2(30.5, 20.5)
	h.line_b = Vector2(10.5, 20.5)
	h.line_to_b = true
	var crowded_at := -1.0
	var warned_at := -1.0
	var disturbed_at := -1.0
	for i in 200:
		F.ms(sim, 50)
		sim.hero.health = FightRules.HEALTH
		for e in sim.drain():
			if e.type == &"crowded" and crowded_at < 0.0:
				crowded_at = sim.now
			if e.type == &"crowd_warning" and warned_at < 0.0:
				warned_at = sim.now
			if e.type == &"disturbed" and disturbed_at < 0.0:
				disturbed_at = sim.now
		if disturbed_at >= 0.0:
			break
	check(crowded_at >= 0.0, "it stops at the player on its path")
	check(warned_at > crowded_at, "it warns first")
	check(disturbed_at > warned_at, "and, left there, takes it as interference")
	gt(disturbed_at - crowded_at, FightSim.CROWD_MS - 150.0, "only after being held up %d ms" % FightSim.CROWD_MS)
	gt(disturbed_at - warned_at, FightSim.CROWD_MS * 0.5 - 150.0, "with half of that to step aside")


## A harvester on its round, and a player who walks up from the side to look at
## it and stands there: looked at, walked past, turned round at the end of its
## row, it never takes the player as interference.
func test_walking_up_to_look_at_a_worker_never_disturbs_it() -> void:
	for across: float in [2.5, 1.5]:
		var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 28.5))
		var h := sim.add_mob(&"harvester", Vector2(17.5, 20.5))
		h.line_a = Vector2(14.5, 20.5)
		h.line_b = Vector2(26.5, 20.5)
		h.line_to_b = true
		h.facing = 0.0
		h.aim = 0.0
		var stand := Vector2(20.5, 20.5 + across)
		var bad := 0
		var turned := 0
		var t := 0.0
		while t < 14000.0:
			var to := stand - sim.hero.pos
			sim.hero.move = to.normalized() if to.length() > 0.1 else Vector2.ZERO
			F.ms(sim, 32)
			t += 32.0
			sim.hero.health = FightRules.HEALTH
			# Mid-row, well clear of where it turns back at either end.
			if h.speed > 0.2 and h.pos.x > 19.5 and h.pos.x < 21.5 and absf(sin(h.facing)) > 0.35:
				turned += 1
			for e in sim.drain():
				if e.type in [&"disturbed", &"alerted", &"crowd_warning"]:
					bad += 1
		eq(bad, 0, "%.1f tiles beside its round: never warned or disturbed" % across)
		check(h.indifferent() and not h.roused(), "still at its work")
		eq(turned, 0, "a glance never turned its hull off its row while it walked")


func test_looked_at_a_worker_walks_on_without_stopping() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 24.5))
	var h := sim.add_mob(&"hauler", Vector2(14.5, 20.5))
	h.line_a = Vector2(14.5, 20.5)
	h.line_b = Vector2(28.5, 20.5)
	h.line_to_b = true
	h.facing = 0.0
	h.aim = 0.0
	var noticed := 0
	var stood := 0
	for i in 150:
		F.ms(sim, 32)
		for e in sim.drain():
			noticed += int(e.type == &"noticed")
		if i > 5 and h.speed < 0.2:
			stood += 1
	gt(float(noticed), 0.0, "it looked up at the player")
	eq(stood, 0, "and kept walking its round")


func test_a_watcher_calls_hunters_not_workers() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
	sim.add_mob(&"watcher", Vector2(40.5, 30.5))
	var worker := sim.add_mob(&"harvester", Vector2(55.5, 30.5))
	worker.line_a = worker.pos
	worker.line_b = worker.pos
	F.ms(sim, 900)
	eq(F.count(sim.drain(), &"called"), 1, "the watcher calls")
	eq(worker.mood, MobState.IDLE, "a worker in earshot goes on working")


func test_a_worker_on_its_round_does_not_hush_the_notebook() -> void:
	var sim := F.make_sim()
	var h := F.still(sim, &"harvester", Vector2(24.5, 20.5), PI)
	var mob := Mob.new()
	mob.setup(h, sim.world, null, FigureModel.new())
	check(not mob.hostile, "indifferent: not a hostile to the notebook")
	h.disturbed = true
	h.set_mood(MobState.ATTACKING, sim.now)
	mob.sync_view(0.0, sim.now)
	check(mob.hostile, "roused, it is")
	mob.free()
