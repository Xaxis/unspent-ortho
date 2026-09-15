extends TestCase
## Darts take what they came for and go: a warden's arrest costs more at each
## meeting, gulls take food, a clerk that gets clear files you.

const F := preload("res://tests/fight/fixture.gd")


func test_warden_arrests_compound_to_the_cap() -> void:
	var body := Body.new()
	var got: Array[float] = []
	for i in 5:
		got.append(float(Snatch.apply(&"warden", body, null, 0.0).minutes))
	eq(got, [60.0, 120.0, 180.0, 240.0, 240.0] as Array[float])
	eq(body.health, 12, "never hurts")


func test_gulls_take_food_or_nothing() -> void:
	var inv := Inventory.new()
	inv.add(&"mussels", 2)
	inv.add(&"stone", 1)
	var r := Snatch.apply(&"gulls", Body.new(), inv, 0.0)
	eq(r.took, &"mussels")
	eq(inv.count(&"mussels"), 1)
	eq(inv.count(&"stone"), 1, "not the stone")
	var empty := Inventory.new()
	var r2 := Snatch.apply(&"gulls", Body.new(), empty, 0.0)
	eq(r2.took, &"")
	check(String(r2.line).contains("nothing"), "a line that says so")


func test_flock_costs_time_and_a_wound() -> void:
	var body := Body.new()
	var r := Snatch.apply(&"flock", body, null, 100.0)
	near(float(r.minutes), 90.0, 0.001)
	check(r.hurt)
	gt(body.hurt_until, 100.0 + 90.0)


func test_clerk_reads_you_and_files_when_clear() -> void:
	var sim := F.make_sim(F.flat_world(96, Ground.ASH, Country.BURNING), Vector2(40.5, 40.5))
	var c := sim.add_mob(&"clerk", Vector2(46.5, 40.5))
	F.ms(sim, 6000)
	var events := sim.drain()
	eq(F.count(events, &"snatch"), 1, "it came close and read you")
	eq(F.count(events, &"filed"), 1, "and got clear with it")
	check(c.removed, "and is gone")
	eq(sim.fight_on, false, "darts are never a fight")


func test_a_clerk_caught_first_files_nothing() -> void:
	var sim := F.make_sim(F.flat_world(96, Ground.ASH, Country.BURNING), Vector2(40.5, 40.5))
	var c := F.still(sim, &"clerk", Vector2(41.2, 40.5), PI)
	sim.press_swing()
	F.ms(sim, 300)
	var events := sim.drain()
	eq(F.count(events, &"killed"), 1, "life 6 scales to one blow")
	check(not c.alive)
	eq(F.count(events, &"filed"), 0)
