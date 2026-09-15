extends TestCase
## Survival inside a real running Game: boot options, the strand, the systems,
## the view and the drawing, on real frames. One small game serves every check,
## and it runs on survival's fixed clock (--hold) so no check waits on the wall:
## _run(s) lets exactly s seconds of survival time pass, 1/60 s a frame.

const Fx := preload("res://tests/survival/fixture.gd")

var game: Game


func test_survival_works_builds_and_draws_inside_a_running_game() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=48", "--give=driftwood:3,stone:2,mussels:1",
		"--held=axe_hand", "--hold=0"]))
	eq(o.give, {&"driftwood": 3, &"stone": 2, &"mussels": 1}, "--give parsed")
	eq(o.held, "axe_hand", "--held parsed")
	near(o.hold, 0.0, 1e-6, "--hold parsed")
	game = Game.new()
	tree.root.add_child(game)
	game.setup(o)
	check(game.inventory.has(&"axe_hand") and game.inventory.held == &"axe_hand", "holding the given axe")
	eq(game.inventory.edge(&"knife"), 5000, "the start knife is half worn")
	eq(game.inventory.count(&"driftwood"), 3, "given driftwood")
	var fx := _system("survival_fx")
	var sys := _system("50_survival")
	check(fx != null, "the effects system loaded")
	check(sys != null and sys.has_method("eat"), "a system offers eat(id) to screens")
	eq(Strand.plan(game).size(), 0, "setup laid the strand: there is nothing left to lay")

	# A pine felled through `use`, the blow caught at an exact moment on the fixed clock.
	var pine := _put(PropKind.PINE)
	eq(Survival.describe_target(game), "pine - fell")
	check(Survival.use(game), "felling")
	await _run(0.4)
	near(Survival.fixed_now, 0.4, 1e-4, "stopped at the moment asked for")
	check(Survival.busy(game), "still at work: the blow is caught, not finished")
	gt((fx.get("_tick") as Array).size(), 0, "one blow's ink burst is on the page")
	gt((fx.get("_fleck") as Array).size(), 0, "and flecks of wood")
	await _run(1.0)
	check(not Survival.busy(game), "the work finished on its own")
	check(game.world.depleted.has(pine.id), "the pine is down")
	eq(game.inventory.count(&"timber"), 2, "its timber in the creel")
	await _run(2.0)
	check(game.find_children("remnant_stump", "", true, false).size() > 0, "a stump layer exists")

	# A fire where it stood, and its flame burns.
	var fire := Survival.build_fire(game)
	check(fire != null, "built a fire")
	await _run(0.6)
	check(game.find_child("fire_%d" % fire.id, true, false) is FireModel, "a flame burns on the built fire")

	# Holding `use` works a vein out; letting go takes once.
	game.inventory.add(&"pick")
	Survival.hold(game, &"pick")
	game.player.facing += PI * 0.5
	var vein := _put(PropKind.IRON_ORE)
	check(Survival.use(game), "first blow")
	sys.set("scripted_use_held", true)
	for i in 8:
		await _run(1.0)
		if game.world.depleted.has(vein.id):
			break
	eq(game.inventory.count(&"iron_ore"), 3, "three takes from one press held down")
	check(game.world.depleted.has(vein.id), "worked out")
	await _run(0.5)
	check(not Survival.busy(game), "and it stops there")
	sys.set("scripted_use_held", false)
	var rock := _put(PropKind.MUSSEL_ROCK)
	check(Survival.use(game), "mussels")
	await _run(1.5)
	eq(game.inventory.count(&"mussels"), 2, "let go: one take only")
	check(not SurvivalState.of(game).spent.has(SurvivalState.key(rock.id, 0)), "rock not picked over")

	# A blow on the player breaks off the work; a blow that rings off, or lands elsewhere, does not.
	check(Survival.use(game), "at the rock again")
	Events.hit.emit(null, game.player, 0, true, Vector3.ZERO)
	check(Survival.busy(game), "a blow that rings off does not stop the work")
	Events.hit.emit(null, game.camera, 2, false, Vector3.ZERO)
	check(Survival.busy(game), "a blow on something else does not either")
	Events.hit.emit(null, game.player, 2, false, Vector3.ZERO)
	check(not Survival.busy(game), "a blow on the player does")
	eq(game.inventory.count(&"mussels"), 2, "and nothing came away")

	game.body.fed_until = game.clock.minutes - 60.0
	check(sys.call("eat", &"mussels"), "eaten through the system")
	eq(game.inventory.count(&"mussels"), 1)
	await _run(1.0)

	# The real key: a press is read from the action's held state, whenever in a frame
	# it was made (a device, or a tour's Input.action_press), and holding it is one press.
	game.player.facing += PI * 0.5
	var reeds := _put(PropKind.REEDS)
	Input.action_press("use")
	await tree.process_frame
	await tree.process_frame
	check(Survival.busy(game), "a press of the use key started the work")
	var started_at: float = SurvivalState.of(game).job.get("done_at", -1.0)
	await tree.process_frame
	eq(SurvivalState.of(game).job.get("done_at", -1.0), started_at, "held down, it is still the one press")
	Input.action_release("use")
	await _run(1.5)
	check(game.world.depleted.has(reeds.id), "and the reeds were cut")
	game.queue_free()
	await tree.process_frame
	eq(Survival.fixed_now, -1.0, "real time again once the game is gone")


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


func test_every_item_hops_into_the_hands_as_a_drawn_token() -> void:
	for id: StringName in Items.DEFS:
		var g := SurvivalMarks.glyph_for(id)
		check(SurvivalMarks.GLYPHS.has(g), "%s has a token (%s)" % [id, g])
	for g in SurvivalMarks.GLYPHS:
		gt(SurvivalMarks.glyph(g).get_surface_count(), 0, "%s token has a mesh" % g)
	gt(SurvivalMarks.dot().get_surface_count(), 0)
	gt(SurvivalMarks.tick().get_surface_count(), 0)
	gt(SurvivalMarks.shard().get_surface_count(), 0)
	check(SurvivalMarks.overlay().render_priority > 0 and SurvivalMarks.material().render_priority > 0,
		"marks draw after the outline pass, or it paints them out")


## Let `seconds` of survival time pass on the fixed clock, a 1/60 s frame at a time.
func _run(seconds: float) -> void:
	game.options.hold = Survival.fixed_now + seconds
	for i in ceili(seconds * 60.0) + 2:
		await tree.process_frame


func _system(part: String) -> Node:
	for s in game.systems:
		if String(s.name).contains(part):
			return s
	return null


## A prop just in front of the player, wherever it stands.
func _put(kind: int) -> WorldProp:
	# In a running game the fight body owns facing and hands it back to the
	# player every frame: turn both, or the turn is undone before a key is read.
	if game.player.hero != null:
		game.player.hero.facing = game.player.facing
	return Fx.put(game, kind, Vector2.from_angle(game.player.facing) * (0.55 + PropKind.SOLID[kind]))
