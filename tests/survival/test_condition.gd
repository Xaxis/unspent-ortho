extends TestCase
## The body: hunger, eating, load, wet, tired, sleep, collapse. A worn body is
## slower, never stopped.

const Fx := preload("res://tests/survival/fixture.gd")


func test_a_fresh_body_walks_at_full_speed_and_a_worn_one_never_stops() -> void:
	near(Condition.move_factor(0), 1.0, 1e-6)
	var extra := Condition.step_extra(200.0, 40.0, 3, true, true, true)
	eq(extra, 2 + 4 + 3, "laden twice, starving, tired, wet, hurt")
	var f := Condition.move_factor(extra)
	near(f, Condition.MIN_FACTOR, 1e-6, "floored")
	gt(f, 0.4, "never stopped")
	var prev := 2.0
	for e in 10:
		var m := Condition.move_factor(e)
		check(m <= prev, "more cost is never faster")
		prev = m


func test_load_slows_at_the_creel_and_again_at_twice_it() -> void:
	eq(Condition.step_extra(39.0, 40.0, 0, false, false, false), 0)
	eq(Condition.step_extra(40.0, 40.0, 0, false, false, false), 1)
	eq(Condition.step_extra(80.0, 40.0, 0, false, false, false), 2)
	var g := Fx.flat()
	g.inventory.add(&"stone", 13)
	Survival.update_body(g)
	near(g.body.load, 40.0, 0.001, "thirteen stones and a knife")
	lt(g.body.move_factor, 1.0, "laden is slower")
	g.inventory.add(&"basket")
	Survival.update_body(g)
	near(g.body.move_factor, 1.0, 0.001, "a basket carries the rest")
	Fx.done(g)


func test_hunger_follows_the_source_hours() -> void:
	var b := Body.new()
	b.fed_until = 1000.0
	eq(b.hunger_level(999.0), 0)
	eq(b.hunger_level(1000.0 + 5.9 * 60.0), 1, "peckish until 20 h after eating")
	eq(b.hunger_level(1000.0 + 6.1 * 60.0), 2, "hungry")
	eq(b.hunger_level(1000.0 + 16.1 * 60.0), 3, "starving after 30 h")


func test_eating_moves_the_last_meal_forward_but_never_past_now() -> void:
	near(Condition.fed_after_eating(600.0, 1000.0, 4.0), 840.0, 1e-6, "four hours more")
	near(Condition.fed_after_eating(1000.0 + 13.0 * 60.0, 1000.0, 10.0), 1000.0 + 14.0 * 60.0, 1e-6, "full is full")
	eq(Condition.best_food([&"mussels", &"stew"] as Array[StringName], 6.0), &"mussels", "no waste")
	eq(Condition.best_food([&"mussels", &"stew"] as Array[StringName], 20.0), &"stew", "the big meal when it fits")
	eq(Condition.best_food([&"stew", &"bread"] as Array[StringName], 1.0), &"bread", "else the smallest")
	eq(Condition.best_food([&"stone"] as Array[StringName], 5.0), &"", "stone is not food")


func test_eat_from_the_creel() -> void:
	var g := Fx.flat()
	g.clock.skip(9.0 * 60.0) # three hours past fed
	eq(g.body.hunger_level(g.clock.minutes), 1, "peckish")
	check(not Survival.eat(g, &"mussels"), "nothing to eat")
	g.inventory.add(&"mussels", 2)
	eq(Survival.describe_target(g), "", "out on the land, use on nothing never eats")
	Survival.build(g, &"fire", true)
	eq(Survival.describe_target(g), "mussels - eat", "by a fire it does")
	var t0 := g.clock.minutes
	check(Survival.eat(g, &"mussels"))
	eq(g.inventory.count(&"mussels"), 1)
	eq(g.body.hunger_level(g.clock.minutes), 0, "fed again")
	near(g.clock.minutes - t0, 10.0, 0.001, "ten minutes to eat")
	Fx.done(g)


func test_starving_on_your_feet_you_sit_down_for_a_shift() -> void:
	var g := Fx.flat()
	var said: Array[String] = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	g.clock.skip(30.0 * 60.0)
	eq(g.body.hunger_level(g.clock.minutes), 3)
	var t0 := g.clock.minutes
	g.player.speed = 3.0
	Survival.tick(g, 0.0)
	near(g.clock.minutes, t0, 0.001, "starving begins with a warning, not a fall")
	check(said.has(Survival.STARVING_LINE), "and it is said: %s" % [said])
	g.clock.skip(Survival.STARVING_GRACE_MINUTES)
	var t1 := g.clock.minutes
	g.player.speed = 0.0
	Survival.tick(g, 0.0)
	near(g.clock.minutes, t1, 0.001, "standing still, nothing happens")
	g.player.speed = 3.0
	Survival.tick(g, 0.0)
	near(g.clock.minutes - t1, 480.0, 0.001, "walking on past the warning, a shift gone")
	eq(g.body.hunger_level(g.clock.minutes), 0, "as if you ate seven hours ago")
	Events.message.disconnect(listen)
	Fx.done(g)


func test_hungry_and_starving_read_differently() -> void:
	var g := Fx.flat()
	var said: Array[String] = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	g.clock.skip(12.5 * 60.0)
	eq(g.body.hunger_level(g.clock.minutes), 2, "hungry")
	Survival.tick(g, 0.0)
	Survival.tick(g, 0.0)
	eq(said.count(Survival.HUNGRY_LINE), 1, "hungry is said once")
	var hungry_pace := g.body.move_factor
	g.clock.skip(10.0 * 60.0)
	eq(g.body.hunger_level(g.clock.minutes), 3, "starving")
	Survival.tick(g, 0.0)
	eq(said.count(Survival.STARVING_LINE), 1, "starving has its own line")
	lt(g.body.move_factor, hungry_pace - 0.05, "and a slower body")
	Events.message.disconnect(listen)
	Fx.done(g)


func test_sleep_by_a_fire_at_night_wakes_at_eight() -> void:
	var g := Fx.flat(40, 14.0)
	check(Survival.sleep_refusal(g) != "", "no fire")
	Survival.build(g, &"fire", true)
	eq(Survival.sleep_refusal(g), "It is too light to sleep.")
	g.clock.skip(8.0 * 60.0) # 22:00
	eq(Survival.sleep_refusal(g), "")
	eq(Survival.describe_target(g), "fire - sleep")
	g.clock.skip(0.0)
	check(Survival.sleep(g))
	near(g.clock.hour(), 8.0, 0.001, "wake at eight without a roof")
	eq(g.clock.day(), 1, "the next day")
	eq(Survival.sleep_refusal(g), "It is too light to sleep.")
	Fx.done(g)


func test_sleep_in_a_village_wakes_at_six_and_not_straight_after_waking() -> void:
	var g := Fx.flat(40, 2.0)
	g.world.villages.append({"pos": g.player.pos + Vector2(4, 0), "country": Country.COAST, "name": "x"})
	SurvivalState.of(g).woke_at = g.clock.minutes - 60.0
	eq(Survival.sleep_refusal(g), "You are not tired yet.")
	SurvivalState.of(g).woke_at = g.clock.minutes - 5.0 * 60.0
	check(Survival.sleep(g), "slept")
	near(g.clock.hour(), 6.0, 0.001, "under a roof, up at six")
	eq(g.clock.day(), 0, "same day")
	Fx.done(g)


func test_awake_eighteen_hours_is_tired_and_slower() -> void:
	var g := Fx.flat()
	Survival.update_body(g)
	near(g.body.move_factor, 1.0, 0.001)
	SurvivalState.of(g).woke_at = g.clock.minutes - 18.0 * 60.0
	g.body.fed_until = g.clock.minutes + 600.0
	Survival.update_body(g)
	eq(g.body.tired, 1.0)
	lt(g.body.move_factor, 1.0)
	Fx.done(g)


func test_wading_wets_you_and_a_fire_dries_you_faster() -> void:
	var g := Fx.flat()
	var w := g.world
	var tx := floori(g.player.pos.x)
	var ty := floori(g.player.pos.y)
	w.ground[ty * w.size + tx] = Ground.WATER
	Survival.sweep(g, 1.0)
	Survival.update_body(g)
	near(g.body.wet, 1.0, 0.001, "soaked")
	lt(g.body.move_factor, 1.0, "wet is slower")
	w.ground[ty * w.size + tx] = Ground.GRASS
	g.clock.skip(45.0)
	Survival.update_body(g)
	near(g.body.wet, 0.5, 0.01, "drying in the air")
	Survival.build(g, &"fire", true)
	for i in 10:
		Survival.sweep(g, 1.0)
	Survival.update_body(g)
	near(g.body.wet, 0.5 - 50.0 / 90.0 if 0.5 - 50.0 / 90.0 > 0.0 else 0.0, 0.01, "a fire dries you")
	Fx.done(g)


func test_wake_minute_is_the_next_one() -> void:
	near(Condition.wake_minute(22.0 * 60.0, false), 32.0 * 60.0, 1e-6)
	near(Condition.wake_minute(3.0 * 60.0, true), 6.0 * 60.0, 1e-6)
	near(Condition.wake_minute(1440.0 + 7.0 * 60.0, true), 2880.0 + 6.0 * 60.0, 1e-6)


func test_the_landscapes_own_weathers_wet_as_the_kinds_they_act_like() -> void:
	check(Condition.wets("whiteout", 0.8), "a whiteout wets like a blizzard")
	check(Condition.wets("drizzle", 0.5), "drizzle wets")
	check(not Condition.wets("glare", 1.0), "glare does not")
	check(not Condition.wets("dry_storm", 1.0), "nor dry lightning")
	check(not Condition.wets("haze", 1.0), "nor haze")
