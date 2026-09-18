extends TestCase
## Minutes on a generated coast at once: the spawner puts bodies out, a player
## walks about and fights what comes the way a careful player does, and
## nothing breaks the rules the other tests pin one at a time. Also the
## budget: the whole layer must cost a small part of a frame per second played.

const F := preload("res://tests/fight/fixture.gd")
const Bot := preload("res://tests/fight/bot.gd")

const SECONDS := 90.0


func test_minutes_on_a_generated_coast() -> void:
	var w := WorldGen.generate(3, 128)
	var q := WorldQuery.new(w)
	var hero := Hero.new()
	hero.body = Body.new()
	hero.inventory = Inventory.new()
	hero.inventory.add(&"knife")
	hero.inventory.set_held(&"knife")
	hero.pos = w.spawn
	var moment := Moment.new()
	moment.seed_value = 3
	moment.minutes = 2.0 * 1440.0 + 9.0 * 60.0
	var sim := FightSim.new(w, q, hero, moment)
	var spawner := Spawner.new()
	# Ten times the ordinary trickle, so a short soak meets plenty.
	spawner.rate = 3.0
	var coast := Coast.new(sim, spawner)
	var bot := Bot.new(sim)
	var rng := Rng.make(3, 77)
	var waypoint := hero.pos
	var kinds := {}
	var outcomes := {}
	var most := 0
	var meetings := 0
	var start_minutes := moment.minutes
	# One sample per SECOND OF PLAY, and the middle of them is the answer. A
	# total over 90 seconds is one number holding every hiccup the scheduler had
	# in a minute and a half, which is why this bound used to be a flat 120 ms
	# over a measured 18 -- nearly seven times its own figure, and so unable to
	# see a fivefold regression. The middle sample throws the scheduler's tail
	# away instead of making room for it (TestCase.middle).
	var per_second: Array[float] = []
	var steps_a_second := int(1000.0 / 16.0)
	var t0 := Time.get_ticks_usec()
	var chunk := t0
	var steps := int(SECONDS * 1000.0 / 16.0)
	for i in steps:
		if i > 0 and i % steps_a_second == 0:
			var now := Time.get_ticks_usec()
			per_second.append(float(now - chunk) / 1000.0)
			chunk = now
		moment.minutes += 16.0 / 1000.0
		coast.tick()
		var near := false
		for m in sim.mobs:
			if m.alive and m.pos.distance_to(hero.pos) < 6.0 and m.approach != &"dart":
				near = true
		if near:
			bot.act()
		else:
			if hero.pos.distance_to(waypoint) < 1.0 or i % 400 == 0:
				waypoint = w.spawn + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-30.0, 30.0))
			hero.move = (waypoint - hero.pos).normalized()
			hero.run = false
		sim.slices(2)
		for e in sim.drain():
			if e.type == &"outcome":
				outcomes[e.outcome] = int(outcomes.get(e.outcome, 0)) + 1
			elif e.type == &"snatch":
				meetings += 1
		most = maxi(most, sim.living())
		for m in sim.mobs:
			kinds[m.kind] = true
			check(not is_nan(m.pos.x) and not is_nan(m.pos.y), "%s has a place" % m.kind)
			var cull := Spawner.PATROL_CULL if m.patrol else Spawner.CULL
			check(Senses.chebyshev(m.pos, hero.pos) <= cull + 1.0, "%s culled past %d" % [m.kind, cull])
		if hero.health <= 0:
			hero.health = FightRules.HEALTH
	var ms_per_second := middle(per_second)
	var mean_ms := (Time.get_ticks_usec() - t0) / 1000.0 / SECONDS
	var game_hours := (moment.minutes - start_minutes) / 60.0
	print("  soak: %d kinds %s, most living %d, outcomes %s, %d dart meetings in %.1f game hours, %.2f ms per second played (middle of %d; mean %.2f)"
		% [kinds.size(), kinds.keys(), most, outcomes, meetings, game_hours, ms_per_second, per_second.size(), mean_ms])
	# Even at ten times the trickle, darts keep to their gap: seen, met rarely.
	lt(float(meetings), game_hours * 60.0 / Coast.MEETING_GAP + 1.01, "dart meetings per game hour")
	lt(float(most), float(Spawner.MAX_LIVING) + 0.5, "six living at most")
	gt(float(kinds.size()), 1.0, "the coast put more than one kind out")
	check(not is_nan(hero.pos.x) and w.in_bounds(floori(hero.pos.x), floori(hero.pos.y)), "the player is still on the coast")
	# A second of play is sixty frames, 1000 ms. The middle second measures 6.95
	# ms on a quiet machine with ten times the ordinary spawning (mean 8.56, and
	# the gap between those two IS the scheduler). This comment said "about 18"
	# for the whole life of the test, which was a MEAN taken under load being
	# read as the cost of the code -- the same mistake one line down was making.
	#
	# 45 leaves a loaded machine room for a slow middle second without leaving
	# room for the runaway this is here to catch (a field rebuilt every slice,
	# which is orders out, not tens of percent). It is the middle second that
	# has to hold, not every one: the bad seconds are the scheduler's and there
	# is no point pretending otherwise.
	lt(ms_per_second, 45.0, "cheap enough to run every frame")
