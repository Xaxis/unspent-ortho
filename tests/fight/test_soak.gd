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
	var t0 := Time.get_ticks_usec()
	var steps := int(SECONDS * 1000.0 / 16.0)
	for i in steps:
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
		most = maxi(most, sim.living())
		for m in sim.mobs:
			kinds[m.kind] = true
			check(not is_nan(m.pos.x) and not is_nan(m.pos.y), "%s has a place" % m.kind)
			check(Senses.chebyshev(m.pos, hero.pos) <= Spawner.CULL + 1.0, "%s culled past 24" % m.kind)
		if hero.health <= 0:
			hero.health = FightRules.HEALTH
	var ms_per_second := (Time.get_ticks_usec() - t0) / 1000.0 / SECONDS
	print("  soak: %d kinds %s, most living %d, outcomes %s, %.2f ms per second played" % [kinds.size(), kinds.keys(), most, outcomes, ms_per_second])
	lt(float(most), float(Spawner.MAX_LIVING) + 0.5, "six living at most")
	gt(float(kinds.size()), 1.0, "the coast put more than one kind out")
	check(not is_nan(hero.pos.x) and w.in_bounds(floori(hero.pos.x), floori(hero.pos.y)), "the player is still on the coast")
	# A second of play is sixty frames, 1000 ms. Measured about 18 ms on an idle
	# machine with ten times the ordinary spawning; the bound is loose so a busy
	# machine passes and a runaway (a field rebuilt every slice) does not.
	lt(ms_per_second, 120.0, "cheap enough to run every frame")
