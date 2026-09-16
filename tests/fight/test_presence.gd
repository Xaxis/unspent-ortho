extends TestCase
## Seen often, met rarely: workers cross the land on their rounds where the
## player can watch them go by and are left be; hunters are thin on the first
## days; and the first hunter of a game is one runner, alone, a fair walk off
## and out of view, within the first minutes.

const F := preload("res://tests/fight/fixture.gd")


func _coast(minutes: float = 10.0 * 60.0) -> Coast:
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.moment.minutes = minutes
	var sp := Spawner.new()
	sp.rate = 0.0
	return Coast.new(sim, sp)


func test_hunters_are_thin_on_the_first_days_and_workers_are_not() -> void:
	var m := Moment.new()
	m.minutes = 10.0 * 60.0
	var runner := Roster.row(&"runner")
	var harvester := Roster.row(&"harvester")
	var day1 := Spawner.weight_at(runner, m)
	m.minutes += 2.0 * 1440.0
	var day3 := Spawner.weight_at(runner, m)
	lt(day1, day3 * 0.5, "a runner on day 1 is under half as likely as on day 3")
	eq(Spawner.weight_at(harvester, m), Spawner.weight_of(harvester), "workers are as common as ever")
	check(not Spawner.is_hunter(Roster.row(&"gulls")), "gulls are not hunters")
	check(not Spawner.is_hunter(Roster.row(&"clerk")), "nor are darts")


func test_no_hunter_comes_out_before_the_first_meeting() -> void:
	var c := _coast()
	var shut := c.shut()
	check(shut.has(&"runner") and shut.has(&"dog.yard"), "hunters held back: %s" % [shut.keys()])
	check(not shut.has(&"harvester"), "workers are not")


func test_the_first_meeting_is_one_runner_seen_on_its_round_before_it_sees() -> void:
	var c := _coast()
	var sim := c.sim
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return not m.patrol).size(), 0, "no hunter at the start")
	sim.now = Coast.FIRST_MEETING_MS + 10.0
	c.tick()
	var runners := sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting)
	eq(runners.size(), 1, "one runner comes")
	if runners.size() != 1:
		return
	var r: MobState = runners[0]
	eq(r.kind, Coast.FIRST_KIND)
	check(c.spawner.in_view(sim.hero.pos, r.pos, Spawner.FIRST_VIEW_MARGIN + 0.01), "put out in view")
	gt(Senses.chebyshev(r.pos, sim.hero.pos), Coast.FIRST_SEES + 1.0, "further off than it notices (%.1f)" % Senses.chebyshev(r.pos, sim.hero.pos))
	check(not Senses.notices(r.row, r.pos, sim.hero.pos, sim.moment, sim.world, sim.query), "it has not noticed the player")
	eq(c.first_meeting, 0, "out on the coast")
	# The player stands and watches it come along its round.
	for p: MobState in sim.mobs.filter(func(m: MobState) -> bool: return m.patrol):
		sim.remove_mob(p)
	var seen_ms := 0.0
	var noticed_at := -1.0
	var chased_at := -1.0
	for i in 40 * 60:
		sim.slices(2)
		c.tick()
		if c.spawner.in_view(sim.hero.pos, r.pos, 0.0) and noticed_at < 0.0:
			seen_ms += 16.0
		for e in sim.drain():
			if e.type == &"alerted" and noticed_at < 0.0:
				noticed_at = sim.now
		if r.roused():
			chased_at = sim.now
			break
	print("  info first meeting: in view %d ms before it noticed, came %d ms after" % [seen_ms, chased_at - noticed_at])
	gt(seen_ms, 2000.0, "in view for a good while before it noticed (%d ms)" % seen_ms)
	check(noticed_at > 0.0, "it notices a player who stays")
	gt(chased_at - noticed_at, 600.0, "and stands a moment, seen to see, before it comes")
	eq(r.row, Roster.row(&"runner"), "roused, it has a runner's senses again")
	sim.now += 10000.0
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting).size(), 1, "never a second")
	sim.remove_mob(r)
	c.tick()
	eq(c.first_meeting, 1, "met, it is over")
	check(not c.shut().has(&"runner"), "and hunters may come again")


func test_the_first_meeting_waits_for_a_player_who_is_well_and_rested() -> void:
	var c := _coast()
	var sim := c.sim
	sim.now = Coast.FIRST_MEETING_MS + 10.0
	sim.hero.health = Coast.FIRST_MIN_HEALTH - 1
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting).size(), 0, "not on a hurt player")
	sim.hero.health = FightRules.HEALTH
	sim.last_fight_end_at = sim.now - 10000.0
	sim.now += Coast.FIRST_RETRY_MS
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting).size(), 0, "not straight after a fight")
	sim.now = sim.last_fight_end_at + Coast.FIRST_QUIET_MS + Coast.FIRST_RETRY_MS
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting).size(), 1, "well, and a while after, it comes")


func test_no_hunter_comes_out_for_a_while_after_a_bad_end() -> void:
	var c := _coast()
	var sim := c.sim
	c.first_meeting = 1
	check(not c.shut().has(&"runner"), "after the first meeting hunters may come")
	var dog := sim.add_mob(&"dog.feral", sim.hero.pos + Vector2(0.8, 0))
	dog.calm_until = 0.0
	dog.set_mood(MobState.ATTACKING, sim.now)
	sim.hero.health = 1
	for i in 400:
		sim.slices(2)
		if sim.last_outcome == &"downed":
			break
	eq(sim.last_outcome, &"downed", "downed")
	check(c.shut().has(&"runner") and c.shut().has(&"dog.yard"), "hunters kept off a player who just came round")
	check(not c.shut().has(&"harvester"), "workers are not")
	sim.now += Coast.AFTER_DOWNED_MS
	check(not c.shut().has(&"runner"), "a few minutes on, they may come again")


func test_workers_cross_the_land_in_view_and_leave_a_still_player_be() -> void:
	var c := _coast()
	var sim := c.sim
	c.tick()
	var patrols := sim.mobs.filter(func(m: MobState) -> bool: return m.patrol)
	eq(patrols.size(), 1, "a worker is put on its round")
	if patrols.size() != 1:
		return
	var p: MobState = patrols[0]
	check(p.indifferent(), "indifferent")
	check(not c.spawner.in_view(sim.hero.pos, p.pos), "it starts out of view")
	var seen := false
	var nearest := INF
	for i in 30 * 60:
		sim.slices(2)
		c.tick()
		if p.removed:
			break
		seen = seen or c.spawner.in_view(sim.hero.pos, p.pos, -1.0)
		nearest = minf(nearest, p.pos.distance_to(sim.hero.pos))
		check(not p.roused(), "never comes for a player who leaves it be")
		if p.roused():
			break
	check(seen, "the player sees it go by")
	gt(nearest, Spawner.PATROL_PASS_MIN - 1.5, "at a distance (%.1f)" % nearest)
	check(p.removed, "and, its crossing done, it comes off the land out of sight")
	eq(sim.fight_on, false, "no fight")


func test_a_patrol_is_culled_further_out_than_a_hunter() -> void:
	check(not Spawner.should_cull(Vector2(30, 0), Vector2.ZERO, true), "a patrol at 30 stays")
	check(Spawner.should_cull(Vector2(30, 0), Vector2.ZERO, false), "a hunter at 30 goes")


func test_the_first_meeting_is_alone() -> void:
	var c := _coast()
	var sim := c.sim
	sim.now = Coast.FIRST_MEETING_MS + 10.0
	var worker := sim.add_mob(&"hauler", sim.hero.pos + Vector2(8, 0))
	worker.line_a = worker.pos
	worker.line_b = worker.pos
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting).size(), 0, "not with a worker eight tiles off")
	sim.remove_mob(worker)
	sim.now += Coast.FIRST_RETRY_MS
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting).size(), 1, "alone, it comes")
	for p: MobState in sim.mobs.filter(func(m: MobState) -> bool: return m.patrol):
		sim.remove_mob(p)
	sim.slices(1)
	sim.now += Coast.PATROL_EVERY_MS * 3.0
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.patrol and not m.removed).size(), 0, "and no patrol is put out while it is on")


## A patrol turned back by something in its way turns back; one that reached the
## end of its line in sight carries on. Neither stands pacing on one spot.
func test_a_patrol_blocked_on_its_round_turns_back_and_goes_on() -> void:
	var c := _coast()
	var sim := c.sim
	var w := sim.world
	# A cliff across its way two tiles on.
	for y in range(40, 58):
		w.level[y * w.size + 60] = 6
	var m := sim.add_mob(&"hauler", Vector2(56.5, 48.5))
	m.line_a = Vector2(44.5, 48.5)
	m.line_b = Vector2(70.5, 48.5)
	m.line_to_b = true
	m.patrol = true
	m.put_out_at = sim.now
	c.rounds = false
	var start := m.pos
	var furthest := 0.0
	for i in 20 * 60:
		sim.slices(2)
		c.tick()
		if m.removed:
			break
		furthest = maxf(furthest, start.distance_to(m.pos))
	gt(furthest, 6.0, "it turned back and went on its way (%.1f tiles)" % furthest)
