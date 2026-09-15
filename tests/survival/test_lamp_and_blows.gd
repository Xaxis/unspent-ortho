extends TestCase
## The lamp's oil, a blow breaking off work, a hand held fast, and a fire kept
## out from under a roof.

const Fx := preload("res://tests/survival/fixture.gd")


func test_a_flask_burns_six_hours_then_a_carried_one_is_poured_in() -> void:
	var r := Condition.burn_lamp(360.0, 100.0, 0)
	near(float(r.left), 260.0, 1e-6)
	check(not r.out, "still lit")
	r = Condition.burn_lamp(60.0, 100.0, 1)
	near(float(r.left), 320.0, 1e-6, "a flask poured in")
	eq(r.flasks, 1)
	r = Condition.burn_lamp(60.0, 800.0, 3)
	eq(r.flasks, 3, "a long night drinks flask after flask")
	near(float(r.left), 340.0, 1e-6)
	r = Condition.burn_lamp(60.0, 100.0, 0)
	check(r.out, "dry, it goes out")
	near(float(r.left), 0.0, 1e-6)


func test_the_lit_lamp_drinks_the_creel_and_goes_out_dry() -> void:
	var g := Fx.flat()
	g.inventory.add(&"lamp")
	g.inventory.add(&"oil")
	var lines: Array[String] = []
	var on_line := func(t: String) -> void: lines.append(t)
	Events.message.connect(on_line)
	Survival.burn_lamp(g)
	g.body.lamp_lit = true
	g.clock.skip(300.0)
	Survival.burn_lamp(g)
	check(g.body.lamp_lit, "lit on its first flask")
	near(Survival.lamp_oil(g), 60.0 + 360.0, 1e-3, "an hour in the lamp and a flask carried")
	g.clock.skip(120.0)
	Survival.burn_lamp(g)
	eq(g.inventory.count(&"oil"), 0, "the carried flask went in")
	check(g.body.lamp_lit, "still lit")
	g.clock.skip(400.0)
	Survival.burn_lamp(g)
	check(not g.body.lamp_lit, "out when dry")
	check(lines.has("The lamp gutters, and goes out."), "and says so")
	g.body.lamp_lit = true
	g.clock.skip(1.0)
	Survival.burn_lamp(g)
	check(not g.body.lamp_lit, "a dry lamp will not stay lit")
	g.body.lamp_lit = false
	Events.message.disconnect(on_line)
	Fx.done(g)


func test_an_unlit_lamp_burns_nothing_and_no_lamp_means_no_light() -> void:
	var g := Fx.flat()
	g.inventory.add(&"lamp")
	Survival.burn_lamp(g)
	g.clock.skip(2000.0)
	Survival.burn_lamp(g)
	near(Survival.lamp_oil(g), 360.0, 1e-3, "unlit keeps its oil")
	g.inventory.remove(&"lamp")
	g.body.lamp_lit = true
	Survival.burn_lamp(g)
	check(not g.body.lamp_lit, "nothing to light")
	Fx.done(g)


func test_sleep_puts_the_lamp_out_and_keeps_its_oil() -> void:
	var g := Fx.flat(40, 22.0)
	g.inventory.add(&"lamp")
	Survival.burn_lamp(g)
	g.body.lamp_lit = true
	Survival.build(g, &"fire", true)
	SurvivalState.of(g).woke_at = g.clock.minutes - 16.0 * 60.0
	check(Survival.sleep(g), "slept")
	check(not g.body.lamp_lit, "put out to sleep")
	Survival.burn_lamp(g)
	near(Survival.lamp_oil(g), 360.0, 1e-3, "no oil burnt through the night")
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
