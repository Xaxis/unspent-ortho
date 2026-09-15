extends TestCase
## The first hour's survival rules: a drop verb for the slate, shore goods that
## leave room in the creel, `use` that never eats or sleeps away from a fire,
## night that asks for the lamp, the lamp saying when it is low, long takes and
## eating refused with a hunter close, and a busy station collected on return.

const Fx := preload("res://tests/survival/fixture.gd")


func _listen(said: Array[String]) -> Callable:
	var f := func(t: String) -> void: said.append(t)
	Events.message.connect(f)
	return f


func test_drop_puts_things_down_and_empties_the_hand() -> void:
	var g := Fx.flat()
	var said: Array[String] = []
	var f := _listen(said)
	g.inventory.add(&"driftwood", 5)
	eq(Survival.drop(g, &"driftwood", 2), 2, "two put down")
	eq(g.inventory.count(&"driftwood"), 3)
	eq(Survival.drop(g, &"driftwood", 9), 3, "no more than there is")
	check(not g.inventory.has(&"driftwood"))
	eq(Survival.drop(g, &"driftwood", 1), 0, "nothing left to drop")
	eq(Survival.drop(g, &"knife", 1), 1, "the knife in hand")
	eq(g.inventory.held, &"", "bare hands after")
	check(said.has("Left two driftwood."), "said: %s" % [said])
	near(g.body.load, g.inventory.bulk(), 0.001, "the body's load follows at once")
	Events.message.disconnect(f)
	Fx.done(g)


## Nothing put down is gone: it lies on one heap in front of the player, and
## `use` on the heap takes it all back, the knife as worn as it was left.
func test_what_is_put_down_lies_on_a_heap_that_use_takes_back() -> void:
	var g := Fx.flat()
	g.inventory.add(&"driftwood", 4)
	var props := g.world.props.size()
	Survival.drop(g, &"driftwood", 3)
	Survival.drop(g, &"knife", 1)
	eq(g.world.props.size(), props + 1, "one heap for both")
	var heap := Survival.heap_near(g)
	check(heap != null and heap.kind == PropKind.CAIRN, "a heap in reach")
	if heap == null:
		Fx.done(g)
		return
	g.player.pos = heap.pos + Vector2(-(heap.solid + Tuning.PLAYER_RADIUS + 0.2), 0)
	g.player.facing = 0.0
	eq(Survival.use_target(g), heap, "use finds it")
	eq(Survival.describe_target(g), "your things - take back")
	var t0 := g.clock.minutes
	check(Survival.use(g), "use takes it back")
	eq(g.inventory.count(&"driftwood"), 4, "all the wood")
	eq(g.inventory.count(&"knife"), 1, "and the knife")
	eq(g.inventory.edge(&"knife"), 5000, "as worn as it was left")
	eq(g.inventory.held, &"knife", "and back in the empty hand")
	near(g.clock.minutes, t0, 0.001, "no time")
	check(g.world.depleted.has(heap.id), "the heap is gone")
	check(Survival.heap_near(g) == null, "and nothing is left to take")
	Fx.done(g)


func test_a_heap_can_be_left_under_the_trees() -> void:
	var g := Fx.flat()
	for off: Vector2 in [Vector2(1.1, 0.4), Vector2(1.0, -0.6), Vector2(-0.3, 1.2), Vector2(-1.1, -0.4), Vector2(0.2, -1.3)]:
		Fx.put(g, PropKind.BROADLEAF, off)
	eq(Survival.drop(g, &"knife", 1), 1, "in a grove, still somewhere to put it")
	var heap := Survival.heap_near(g)
	check(heap != null, "a heap under the crowns")
	if heap != null:
		g.player.facing += PI
		eq(Survival.use_target(g), heap, "turned away, the heap at your feet is still what E takes")
		g.player.facing -= PI
		eq(Survival.use_target(g), heap, "before the tree in front of you")
		for q in g.query.props_near(heap.pos, 2.0):
			if q != heap:
				gt(q.pos.distance_to(heap.pos), q.solid + heap.solid, "clear of every trunk")
	Fx.done(g)


func test_nothing_is_put_down_with_a_hostile_close() -> void:
	var g := Fx.flat()
	var sim := FightSim.new(g.world, g.query)
	sim.hero.pos = g.player.pos
	g.player.sim = sim
	sim.add_mob(&"runner", g.player.pos + Vector2(-5, 0))
	eq(Survival.drop(g, &"knife", 1), 0, "not with a runner five tiles off")
	eq(g.inventory.held, &"knife", "still in hand")
	g.player.sim = null
	Fx.done(g)


func test_the_last_blade_counts_as_the_last_weapon() -> void:
	var g := Fx.flat()
	check(Survival.last_weapon(g, &"knife"), "the start knife is the only blade")
	g.inventory.add(&"driftwood", 2)
	check(not Survival.last_weapon(g, &"driftwood"), "wood does not fight")
	g.inventory.add(&"pick")
	check(not Survival.last_weapon(g, &"knife"), "with a pick carried the knife is not the last")
	Fx.done(g)


func test_the_first_fire_charcoal_and_haft_leave_room_in_the_creel() -> void:
	# Nine driftwood and two stone make a fire, charcoal and a haft (the playtest
	# was laden before the first fire with eight driftwood and a stone).
	var inv := Inventory.new()
	inv.add(&"knife")
	inv.add(&"lamp")
	inv.add(&"driftwood", 9)
	inv.add(&"stone", 2)
	inv.add(&"mussels", 4)
	lt(inv.bulk(), inv.creel() * 0.75, "a morning's gathering is under three quarters of a creel: %.1f" % inv.bulk())


func test_use_on_nothing_out_on_the_land_never_eats_or_sleeps() -> void:
	var g := Fx.flat(40, 22.0)
	g.inventory.add(&"lamp")
	g.body.lamp_lit = true
	g.inventory.add(&"mussels", 3)
	g.body.fed_until = g.clock.minutes - 7.0 * 60.0
	SurvivalState.of(g).woke_at = g.clock.minutes - 20.0 * 60.0
	check(not Survival.use(g), "hungry at night, nothing in front: nothing happens")
	eq(g.inventory.count(&"mussels"), 3, "the food is still in the creel")
	near(g.clock.hour(), 22.0, 0.01, "and the night is not slept away")
	check(Survival.eat(g, &"mussels"), "chosen from the carrying page, it eats")


func test_night_without_a_light_hides_what_a_hand_does_not_touch() -> void:
	var g := Fx.flat(40, 23.0)
	var said: Array[String] = []
	var f := _listen(said)
	var pine := Fx.put(g, PropKind.PINE, Vector2(1.5, 0))
	check(Survival.in_the_dark(g), "dark")
	check(Survival.use_target(g) == null, "a pine a step off is not found in the dark")
	check(not Survival.use(g), "use finds nothing")
	check(said.has(Survival.DARK_LINE), "and asks for the lamp: %s" % [said])
	g.inventory.add(&"lamp")
	g.body.lamp_lit = true
	check(not Survival.in_the_dark(g), "the lamp lights it")
	eq(Survival.use_target(g), pine, "lit, the pine is there")
	g.body.lamp_lit = false
	Survival.build(g, &"fire", true)
	check(not Survival.in_the_dark(g), "so does a fire")
	g.clock.skip(10.0 * 60.0)
	check(not Survival.in_the_dark(g), "and the morning")
	Events.message.disconnect(f)
	Fx.done(g)


func test_the_lamp_says_when_its_oil_is_low_once() -> void:
	var g := Fx.flat(40, 21.0)
	var said: Array[String] = []
	var f := _listen(said)
	g.inventory.add(&"lamp")
	g.body.lamp_lit = true
	var state := SurvivalState.of(g)
	state.lamp_at = g.clock.minutes
	state.lamp_oil = Survival.LAMP_LOW_MINUTES + 5.0
	Survival.tick(g, 0.0)
	eq(said.count(Survival.LAMP_LOW_LINE), 0, "plenty left")
	g.clock.skip(10.0)
	Survival.sweep(g, 1.0)
	Survival.tick(g, 0.0)
	Survival.tick(g, 0.0)
	eq(said.count(Survival.LAMP_LOW_LINE), 1, "low, said once")
	Events.message.disconnect(f)
	Fx.done(g)


func test_long_takes_and_meals_wait_until_the_hunter_is_gone() -> void:
	var g := Fx.flat()
	var sim := FightSim.new(g.world, g.query)
	sim.hero.pos = g.player.pos
	g.player.sim = sim
	var tip := Fx.put(g, PropKind.TIP, Vector2(1.3, 0))
	Fx.face(g, tip)
	sim.hero.pos = g.player.pos
	var runner := sim.add_mob(&"runner", g.player.pos + Vector2(-6, 0))
	check(Survival.threat_near(g), "a runner six tiles off")
	var t0 := g.clock.minutes
	check(not Survival.use(g), "turning over a tip is refused")
	check(SurvivalState.of(g).job.is_empty(), "nothing started")
	near(g.clock.minutes, t0, 0.001, "no time")
	g.inventory.add(&"mussels")
	check(not Survival.eat(g, &"mussels"), "nor a meal")
	var drift := Fx.put(g, PropKind.DRIFTWOOD, Vector2(0, -0.9))
	Fx.face(g, drift, Vector2(0, 1))
	check(Survival.use(g), "a quick grab off the strand is still a grab")
	Survival.finish_work(g)
	runner.pos = g.player.pos + Vector2(-20, 0)
	Fx.face(g, tip)
	check(Survival.use(g), "gone off, the tip may be worked")
	g.player.sim = null
	Fx.done(g)


func test_holding_drop_in_a_running_game_puts_down_what_is_in_hand_once() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64", "--give=driftwood:3", "--held=driftwood"])))
	var sys: Node = g.get_node("50_survival")
	eq(g.inventory.held, &"driftwood")
	Input.action_press(&"drop")
	sys.call("_process", 0.2)
	eq(g.inventory.count(&"driftwood"), 3, "a tap is not a drop")
	sys.call("_process", 0.4)
	eq(g.inventory.count(&"driftwood"), 2, "held, one is put down")
	sys.call("_process", 0.4)
	eq(g.inventory.count(&"driftwood"), 2, "once per hold")
	Input.action_release(&"drop")
	sys.call("_process", 0.1)
	check(Survival.heap_near(g) != null, "on a heap in front of the player")
	# The knife is the last blade: held X puts it away, and it stays in the creel.
	Survival.hold(g, &"knife")
	Input.action_press(&"drop")
	sys.call("_process", 0.3)
	sys.call("_process", 0.3)
	Input.action_release(&"drop")
	sys.call("_process", 0.1)
	eq(g.inventory.count(&"knife"), 1, "the only blade is never left on the ground")
	eq(g.inventory.held, &"", "it is put away")
	g.queue_free()
	await frames(1)


func test_patrols_may_pass_nearer_a_village_than_workers_are_put_out() -> void:
	var w := load("res://tests/fight/fixture.gd").flat_world(96) as WorldData
	w.villages.append({"pos": Vector2(48.5, 48.5), "country": Country.COAST, "name": "v"})
	var q := WorldQuery.new(w)
	var row := Roster.row(&"harvester")
	check(not Spawner.place_fits(row, w, q, 48 + 15, 48), "a harvester is not put to work 15 tiles from a green")
	check(Spawner.place_fits(Spawner._on_round(row), w, q, 48 + 15, 48), "but on its round it may pass there")
	check(not Spawner.place_fits(Spawner._on_round(row), w, q, 48 + 6, 48), "never into the village")


func test_a_press_of_use_on_nothing_is_answered() -> void:
	var g := Fx.flat()
	var heard: Array[StringName] = []
	var f := func(n: StringName, _at: Vector3) -> void: heard.append(n)
	Events.sfx.connect(f)
	check(not Survival.use(g), "nothing here")
	check(heard.has(&"refuse"), "but it is heard: %s" % [heard])
	Events.sfx.disconnect(f)
	Fx.done(g)
