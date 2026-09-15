extends TestCase
## Survival inside a real running Game: boot options, the systems, the view and
## the effects, on real frames. Slower than the rule tests (it waits out one
## work in real time), so it is one test that checks the whole wiring.

const Fx := preload("res://tests/survival/fixture.gd")


func test_a_game_started_with_survival_options_works_builds_and_draws() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=96", "--give=driftwood:3,stone:2,mussels:1", "--held=axe_hand"]))
	eq(o.give, {&"driftwood": 3, &"stone": 2, &"mussels": 1}, "--give parsed")
	eq(o.held, "axe_hand", "--held parsed")
	var game := Game.new()
	tree.root.add_child(game)
	game.setup(o)
	check(game.inventory.has(&"axe_hand") and game.inventory.held == &"axe_hand", "holding the given axe")
	eq(game.inventory.edge(&"knife"), 5000, "the start knife is half worn")
	eq(game.inventory.count(&"driftwood"), 3, "given driftwood")
	var fx_found := false
	for s in game.systems:
		fx_found = fx_found or String(s.name).contains("survival_fx")
	check(fx_found, "the effects system loaded")

	# A pine in front of the player, felled through the real `use` path and real time.
	var pine := Fx.put(game, PropKind.PINE, Vector2.from_angle(game.player.facing) * 0.9)
	eq(Survival.describe_target(game), "pine - fell")
	check(Survival.use(game), "work started")
	check(Survival.busy(game), "busy")
	var t0 := Time.get_ticks_msec()
	while Survival.busy(game) and Time.get_ticks_msec() - t0 < 3000:
		await tree.process_frame
	check(not Survival.busy(game), "the work finished on its own")
	eq(game.inventory.count(&"timber"), 2, "timber from the felled pine")
	check(game.world.depleted.has(pine.id), "the pine is gone")

	# Build a fire where it stood: `use` on nothing with the makings in the creel.
	game.player.facing = PI
	var fire := Survival.build_fire(game)
	check(fire != null, "built a fire")
	await tree.process_frame
	await tree.process_frame
	# The effects system scans for fires twice a second.
	var t1 := Time.get_ticks_msec()
	var flame: Node = null
	while flame == null and Time.get_ticks_msec() - t1 < 1500:
		await tree.process_frame
		flame = game.find_child("fire_%d" % fire.id, true, false)
	check(flame is FireModel, "a flame burns on the built fire")
	game.queue_free()
	await tree.process_frame


func test_every_prop_that_is_taken_away_leaves_the_right_mark() -> void:
	for kind: int in Takes.table():
		var gone := false
		for o: Dictionary in Takes.options(kind):
			gone = gone or not o.keep
		var mark := RemnantModels.for_kind(kind)
		if kind in [PropKind.DRIFTWOOD, PropKind.WRACK]:
			eq(mark, &"", "%s washes away clean" % PropKind.NAMES[kind])
		elif gone:
			check(mark != &"", "%s leaves a mark when taken" % PropKind.NAMES[kind])
	for name in RemnantModels.NAMES:
		gt(RemnantModels.mesh(name).get_surface_count(), 0, "%s has a mesh" % name)


func test_fire_light_follows_the_dark() -> void:
	near(FireModel.darkness_at(12.0), 0.0, 1e-6, "no pool at noon")
	near(FireModel.darkness_at(23.0), 1.0, 1e-6, "full at night")
	near(FireModel.darkness_at(3.0), 1.0, 1e-6, "full before dawn")
	check(FireModel.darkness_at(20.0) > 0.0 and FireModel.darkness_at(20.0) < 1.0, "coming in at dusk")
	near(FireModel.darkness_at(8.0), 0.0, 1e-6, "gone by morning")
