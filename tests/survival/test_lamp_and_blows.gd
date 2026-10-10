extends TestCase
## The headlamp, a blow breaking off work, a hand held fast, and a fire kept
## out from under a roof.

const Fx := preload("res://tests/survival/fixture.gd")


## THE HEADLAMP NEEDS NOTHING TO RUN ON (owner, 2026-10-09): an old LED headlamp,
## lit through a whole night and the day after, with no oil carried, is still on.
func test_the_headlamp_stays_on_with_nothing_to_run_on() -> void:
	var g := Fx.flat()
	g.inventory.add(&"lamp")
	g.inventory.remove(&"oil", g.inventory.count(&"oil"))
	g.body.lamp_lit = true
	for i in 30:
		g.clock.skip(60.0)
		Survival.keep_lamp(g)
	check(g.body.lamp_lit, "thirty hours on, still lit")
	eq(Items.display_name(&"lamp"), "headlamp", "and it is a headlamp")
	Fx.done(g)


func test_no_headlamp_carried_means_no_light() -> void:
	var g := Fx.flat()
	g.inventory.remove(&"lamp", g.inventory.count(&"lamp"))
	g.body.lamp_lit = true
	Survival.keep_lamp(g)
	check(not g.body.lamp_lit, "nothing to light")
	Fx.done(g)


func test_sleep_switches_the_headlamp_off() -> void:
	var g := Fx.flat(40, 22.0)
	g.inventory.add(&"lamp")
	g.body.lamp_lit = true
	Survival.build(g, &"fire", true)
	SurvivalState.of(g).woke_at = g.clock.minutes - 16.0 * 60.0
	check(Survival.sleep(g), "slept")
	check(not g.body.lamp_lit, "switched off to sleep")
	Fx.done(g)


func test_a_blow_breaks_off_the_work_with_nothing_taken_and_no_time_gone() -> void:
	var g := Fx.flat()
	g.inventory.add(&"axe_hand")
	Survival.hold(g, &"axe_hand")
	var pine := Fx.put(g, PropKind.PINE, Vector2(1.0, 0))
	Fx.face(g, pine)
	var t0 := g.clock.minutes
	check(Survival.use(g), "felling")
	check(Survival.busy(g), "busy")
	check(Survival.interrupt(g), "broken off")
	check(not Survival.busy(g), "free to move at once")
	check(not Survival.finish_work(g), "nothing left to finish")
	eq(g.inventory.count(&"timber"), 0, "nothing taken")
	near(g.clock.minutes, t0, 1e-6, "no time charged")
	eq(g.inventory.edge(&"axe_hand"), 10000, "no wear")
	check(not g.world.depleted.has(pine.id), "the pine stands")
	check(not Survival.interrupt(g), "nothing to break off now")
	Fx.done(g)


func test_nothing_to_do_while_something_has_hold_of_you() -> void:
	var g := Fx.flat()
	var reeds := Fx.put(g, PropKind.REEDS, Vector2(0.8, 0))
	Fx.face(g, reeds)
	g.body.grip = 3
	check(not Survival.use(g), "held fast")
	g.body.grip = 0
	check(Survival.use(g), "free, it cuts")
	Fx.done(g)


func test_no_fire_under_the_eaves_of_a_house() -> void:
	var g := Fx.flat()
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	var house := Fx.put(g, PropKind.HOUSE, Vector2(4.2, 0))
	g.player.facing = 0.0
	var fire := Survival.build_fire(g)
	check(fire != null, "built somewhere")
	if fire != null:
		gt(fire.pos.distance_to(house.pos), 2.1 + PropKind.SOLID[PropKind.FIRE], "clear of the roof")
	Fx.done(g)


func test_a_short_body_is_hurt_and_slower() -> void:
	var g := Fx.flat()
	Survival.update_body(g)
	near(g.body.move_factor, 1.0, 1e-6)
	g.body.health = g.body.max_health - 1
	check(Survival.is_hurt(g), "hurt")
	Survival.update_body(g)
	lt(g.body.move_factor, 1.0, "slower")
	Fx.done(g)
