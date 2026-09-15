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


func test_the_first_meeting_is_one_runner_a_fair_walk_off_out_of_view() -> void:
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
	var d := r.pos.distance_to(sim.hero.pos)
	check(d >= Spawner.FIRST_RING_MIN - 1.0 and d <= Spawner.FIRST_RING_MAX + 1.0, "12-15 tiles off: %.1f" % d)
	check(not c.spawner.in_view(sim.hero.pos, r.pos), "out of view")
	eq(c.first_meeting, 0, "out on the coast")
	sim.now += 10000.0
	c.tick()
	eq(sim.mobs.filter(func(m: MobState) -> bool: return m.first_meeting).size(), 1, "never a second")
	sim.remove_mob(r)
	c.tick()
	eq(c.first_meeting, 1, "met, it is over")
	check(not c.shut().has(&"runner"), "and hunters may come again")


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
	eq(sim.fight_on, false, "no fight")


func test_a_patrol_is_culled_further_out_than_a_hunter() -> void:
	check(not Spawner.should_cull(Vector2(30, 0), Vector2.ZERO, true), "a patrol at 30 stays")
	check(Spawner.should_cull(Vector2(30, 0), Vector2.ZERO, false), "a hunter at 30 goes")
