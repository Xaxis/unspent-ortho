extends TestCase
## Taking from the world: verbs, tools, hardness, wear, depletion, regrowth, reach.

const Fx := preload("res://tests/survival/fixture.gd")

static var _messages: PackedStringArray = []
static var _connected := false


static func _on_message(t: String) -> void:
	_messages.append(t)


func _listen() -> void:
	_messages.clear()
	if not _connected:
		_connected = true
		Events.message.connect(_on_message)


func test_every_take_gives_a_real_item() -> void:
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			check(not Items.def(o.item).is_empty(), "%s gives unknown item %s" % [PropKind.NAMES[kind], o.item])
			if not (o.bonus as Array).is_empty():
				check(not Items.def(o.bonus[0]).is_empty(), "%s bonus unknown" % PropKind.NAMES[kind])
			check(o.stuff == &"" or Items.STUFF_RANK.has(o.stuff), "%s bad stuff" % PropKind.NAMES[kind])


func test_the_knife_cuts_reeds_and_wears() -> void:
	var g := Fx.flat()
	var reeds := Fx.put(g, PropKind.REEDS, Vector2(0.9, 0))
	var t0 := g.clock.minutes
	eq(Survival.use_target(g), reeds, "reeds in front")
	eq(Survival.describe_target(g), "reeds - cut")
	check(Fx.take(g), "work started")
	eq(g.inventory.count(&"reeds"), 2, "two bundles")
	# 7 bare minutes, knife speed 8200 at half edge: 7 x lerp(10000, 8200, 0.5) / 10000.
	near(g.clock.minutes - t0, 7.0 * 0.91, 0.01, "work minutes")
	eq(g.inventory.edge(&"knife"), 5000 - 111, "one use of a 90-bite edge")
	check(g.world.depleted.has(reeds.id), "cut reeds are gone")
	near(g.world.depleted[reeds.id], g.clock.minutes + 24.0 * 60.0, 0.01, "reeds regrow in a day")
	check(Survival.use_target(g) == null, "nothing left to target")
	Fx.done(g)


func test_work_is_busy_until_finished_and_charges_time_at_the_end() -> void:
	var g := Fx.flat()
	Fx.put(g, PropKind.DRIFTWOOD, Vector2(0.8, 0))
	var t0 := g.clock.minutes
	check(Survival.use(g), "started")
	check(Survival.busy(g), "busy while working")
	check(not Survival.use(g), "a second use is refused while working")
	near(g.clock.minutes, t0, 0.001, "no time before the work completes")
	eq(g.inventory.count(&"driftwood"), 0, "nothing yet")
	check(Survival.finish_work(g), "finished")
	check(not Survival.busy(g), "free again")
	eq(g.inventory.count(&"driftwood"), 2, "driftwood")
	near(g.clock.minutes - t0, 3.0, 0.001, "gather is bare-handed minutes")
	Fx.done(g)


func test_tool_verbs_refuse_with_the_source_lines_and_cost_nothing() -> void:
	_listen()
	var g := Fx.flat()
	var ore := Fx.put(g, PropKind.IRON_ORE, Vector2(0.9, 0))
	var t0 := g.clock.minutes
	check(not Fx.take(g), "a knife does not break ore")
	eq(_messages[-1], "Not with that.")
	Survival.hold(g, &"")
	check(not Fx.take(g), "nor do hands")
	eq(_messages[-1], "Not with your hands.")
	eq(Survival.describe_target(g), "iron ore - no tool")
	near(g.clock.minutes, t0, 0.001, "refusals are free")
	g.world.depleted[ore.id] = INF
	var copper := Fx.put(g, PropKind.COPPER_ORE, Vector2(0.9, 0.05))
	g.inventory.add(&"pick")
	Survival.hold(g, &"pick")
	eq(Survival.use_target(g), copper)
	check(not Fx.take(g), "iron pick on a steel seam")
	eq(_messages[-1], "It rings, and nothing comes away.")
	eq(Survival.describe_target(g), "copper ore - too hard")
	eq(g.inventory.edge(&"pick"), 10000, "a refused seam does not wear the tool")
	Fx.done(g)


func test_a_vein_gives_three_takes_then_is_gone_for_good() -> void:
	var g := Fx.flat()
	g.inventory.add(&"pick")
	Survival.hold(g, &"pick")
	var ore := Fx.put(g, PropKind.IRON_ORE, Vector2(0.9, 0))
	for i in 3:
		check(Fx.take(g), "take %d" % i)
	eq(g.inventory.count(&"iron_ore"), 3)
	eq(g.world.depleted.get(ore.id, 0.0), INF, "never grows back")
	g.clock.skip(60.0 * 24.0 * 30.0)
	Survival.sweep(g, 1.0)
	check(g.world.depleted.has(ore.id), "still gone a month later")
	Fx.done(g)


func test_a_carried_tool_is_taken_in_hand_when_the_held_one_cannot_do_it() -> void:
	var g := Fx.flat()
	g.inventory.add(&"pick")
	Survival.hold(g, &"knife")
	Fx.put(g, PropKind.COAL_ORE, Vector2(0.9, 0))
	eq(Survival.describe_target(g), "coal ore - break", "the prompt names what the carried pick would do")
	check(Fx.take(g), "worked with the pick")
	eq(g.inventory.held, &"pick", "pick in hand")
	eq(g.inventory.count(&"coal"), 1)
	Fx.done(g)


func test_bare_handed_options_leave_the_prop_standing_and_come_back() -> void:
	_listen()
	var g := Fx.flat()
	var pine := Fx.put(g, PropKind.PINE, Vector2(0.9, 0))
	eq(Survival.describe_target(g), "pine - tap", "a knife taps a pine")
	check(Fx.take(g), "tapped")
	eq(g.inventory.count(&"resin"), 1)
	check(not g.world.depleted.has(pine.id), "a tapped pine still stands")
	check(not Fx.take(g), "tapped out")
	eq(_messages[-1], "There is nothing more on it yet.")
	eq(Survival.describe_target(g), "pine - picked over")
	g.clock.skip(96.0 * 60.0 + 1.0)
	Survival.sweep(g, 1.0)
	check(Fx.take(g), "resin again after four days")
	Fx.done(g)


func test_an_axe_fells_the_pine_for_good() -> void:
	var g := Fx.flat()
	g.inventory.add(&"axe_hand")
	Survival.hold(g, &"axe_hand")
	var pine := Fx.put(g, PropKind.PINE, Vector2(0.9, 0))
	eq(Survival.describe_target(g), "pine - fell")
	var t0 := g.clock.minutes
	check(Fx.take(g), "felled")
	eq(g.inventory.count(&"timber"), 2)
	near(g.clock.minutes - t0, 18.0 * 0.65, 0.01, "a new hand axe at 6500")
	eq(g.world.depleted.get(pine.id, 0.0), INF)
	Fx.done(g)


func test_a_boulder_gives_a_loose_stone_by_hand_and_breaks_with_a_pick() -> void:
	var g := Fx.flat()
	var b := Fx.put(g, PropKind.BOULDER, Vector2(1.0, 0))
	Fx.face(g, b)
	eq(Survival.describe_target(g), "boulder - gather")
	check(Fx.take(g), "loose stone")
	eq(g.inventory.count(&"stone"), 1)
	check(not g.world.depleted.has(b.id), "the boulder stays")
	g.inventory.add(&"pick")
	Survival.hold(g, &"pick")
	check(Fx.take(g), "broken")
	check(Fx.take(g), "broken again")
	eq(g.inventory.count(&"stone"), 5)
	check(g.world.depleted.has(b.id), "broken up and gone")
	Fx.done(g)


func test_a_snowfield_boulder_gives_crottle_after_its_loose_stone() -> void:
	var g := Fx.flat()
	var b := Fx.put(g, PropKind.BOULDER, Vector2(1.0, 0))
	var w := g.world
	w.ground[floori(b.pos.y) * w.size + floori(b.pos.x)] = Ground.SNOW
	Fx.face(g, b)
	check(Fx.take(g))
	eq(g.inventory.count(&"stone"), 1, "stone first")
	eq(Survival.describe_target(g), "boulder - scrape")
	check(Fx.take(g))
	eq(g.inventory.count(&"crottle"), 1, "then crottle off the crust")
	eq(Survival.describe_target(g), "boulder - picked over")
	Fx.done(g)


func test_every_verb_in_the_source_is_used_by_some_prop() -> void:
	var verbs := {}
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			verbs[o.verb] = true
	for v: StringName in [&"break", &"dig", &"fell", &"cut", &"gather", &"scrape", &"tap", &"turn"]:
		check(verbs.has(v), "no prop is worked by %s" % v)


func test_regrowth_brings_driftwood_back_and_resets_its_takes() -> void:
	var g := Fx.flat()
	var d := Fx.put(g, PropKind.DRIFTWOOD, Vector2(0.8, 0))
	check(Fx.take(g))
	check(g.world.depleted.has(d.id))
	g.clock.skip(11.0 * 60.0)
	Survival.sweep(g, 1.0)
	check(g.world.depleted.has(d.id), "not yet")
	g.clock.skip(2.0 * 60.0)
	Survival.sweep(g, 1.0)
	check(not g.world.depleted.has(d.id), "washed up again")
	eq(Survival.use_target(g), d, "workable again")
	check(Fx.take(g))
	eq(g.inventory.count(&"driftwood"), 4)
	Fx.done(g)


func test_nothing_grows_back_through_the_player() -> void:
	var g := Fx.flat()
	var gorse := Fx.put(g, PropKind.GORSE, Vector2(0.9, 0))
	check(Fx.take(g), "cut")
	check(g.world.depleted.has(gorse.id))
	g.clock.skip(73.0 * 60.0)
	var away := g.player.pos
	g.player.pos = gorse.pos
	Survival.sweep(g, 1.0)
	check(g.world.depleted.has(gorse.id), "held back while standing in it")
	g.player.pos = away
	g.clock.skip(31.0)
	Survival.sweep(g, 1.0)
	check(not g.world.depleted.has(gorse.id), "grown back once clear")
	Fx.done(g)


func test_reach_is_in_front_and_close() -> void:
	var g := Fx.flat()
	g.player.facing = 0.0
	var behind := Fx.put(g, PropKind.DRIFTWOOD, Vector2(-0.9, 0))
	check(Survival.use_target(g) == null, "behind is not a target")
	var far := Fx.put(g, PropKind.DRIFTWOOD, Vector2(2.0, 0))
	check(Survival.use_target(g) == null, "two tiles is out of reach")
	var near_one := Fx.put(g, PropKind.DRIFTWOOD, Vector2(1.0, 0.3))
	eq(Survival.use_target(g), near_one, "close and in front")
	g.player.facing = PI
	eq(Survival.use_target(g), behind, "turn round")
	check(far != null)
	Fx.done(g)


func test_a_workable_target_beats_a_closer_refused_one() -> void:
	var g := Fx.flat()
	Fx.put(g, PropKind.IRON_ORE, Vector2(0.75, -0.2))
	var drift := Fx.put(g, PropKind.DRIFTWOOD, Vector2(1.0, 0.2))
	eq(Survival.use_target(g), drift, "the driftwood you can take")
	Fx.done(g)


func test_the_dull_notice_is_given_once() -> void:
	_listen()
	var inv := Inventory.new()
	inv.add(&"knife")
	inv.set_edge(&"knife", 3700)
	check(not inv.wear(&"knife"), "3589 is not yet dull")
	check(inv.wear(&"knife"), "crossing 3500 notices")
	check(not inv.wear(&"knife"), "once")
	for i in 100:
		inv.wear(&"knife")
	eq(inv.edge(&"knife"), 0, "never below nothing, never breaks")
	check(inv.has(&"knife"), "still carried")
	var stave := Inventory.new()
	stave.add(&"stave")
	check(not stave.wear(&"stave"))
	eq(stave.edge(&"stave"), 10000, "bite 0 never dulls")


func test_a_blunt_tool_still_works_at_bare_hand_speed() -> void:
	near(Items.work_minutes(30.0, &"pick", 0), 30.0, 0.001, "blunt")
	near(Items.work_minutes(30.0, &"pick", 10000), 18.0, 0.001, "keen")
	near(Items.work_minutes(30.0, &"pick", 5000), 24.0, 0.001, "half")


func test_mussels_sometimes_bring_up_a_whelk_and_the_rock_stays() -> void:
	var g := Fx.flat()
	var whelks := 0
	for i in 12:
		var rock := Fx.put(g, PropKind.MUSSEL_ROCK, Vector2(0.9, 0))
		Fx.face(g, rock)
		check(Fx.take(g), "mussels %d" % i)
		check(not g.world.depleted.has(rock.id), "the rock stays")
		g.world.depleted[rock.id] = INF
	whelks = g.inventory.count(&"whelks")
	eq(g.inventory.count(&"mussels"), 12)
	check(whelks > 0 and whelks < 12, "some whelks, not always: %d" % whelks)
	Fx.done(g)


func test_use_on_nothing_builds_a_fire_then_eats_before_it_sleeps_by_it() -> void:
	var g := Fx.flat(40, 20.0)
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	g.inventory.add(&"mussels", 2)
	eq(Survival.describe_target(g), "campfire - build", "fed, it is evening, no fire: build")
	check(Survival.use(g), "built")
	eq(g.inventory.count(&"mussels"), 2, "fed: nothing eaten")
	check(not g.world.props.is_empty() and g.world.props[-1].kind == PropKind.FIRE, "a fire stands")
	g.clock.skip(3.0 * 60.0)
	SurvivalState.of(g).woke_at = g.clock.minutes - 20.0 * 60.0
	eq(Survival.describe_target(g), "fire - sleep", "fed, at night by a fire: sleep")
	g.body.fed_until = g.clock.minutes - 60.0
	eq(Survival.describe_target(g), "mussels - eat", "hungry at night: eat first, or wake starving")
	check(Survival.use(g), "ate")
	g.body.busy_until = 0.0
	eq(Survival.describe_target(g), "fire - sleep", "then sleep")
	check(Survival.use(g), "slept")
	eq(g.clock.hour(), 8.0, "woke at eight by a fire")
	g.body.fed_until = g.clock.minutes - 60.0
	eq(Survival.describe_target(g), "mussels - eat", "by day, hungry, with food: eat")
	check(Survival.use(g), "ate")
	eq(g.inventory.count(&"mussels"), 0)
	g.body.busy_until = 0.0
	eq(Survival.describe_target(g), "", "nothing left to do here")
	check(not Survival.use(g), "use on nothing does nothing")
	Fx.done(g)


func test_the_tide_rule_is_the_source_curve() -> void:
	near(Takes.tide(0.0), 0.0, 1e-6, "t=0 is low water")
	near(Takes.tide(745.0 / 2.0), 1.0, 1e-6, "high half a tide later")
	check(Takes.tide_is_low(1490.0), "low again after 24 h 50 m")
