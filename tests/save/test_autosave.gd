extends TestCase
## When the autosave is written: after sleep, on coming into another landscape
## (once it holds underfoot), every three world hours, and never while a fight
## is on; a call made mid-fight waits for the calm and is taken once.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_sleep_asks_for_a_save_that_waits_for_calm() -> void:
	var r := AutosaveRules.new(600.0, &"coast")
	eq(r.due(601.0, true), &"", "nothing to save at the start")
	r.slept()
	eq(r.due(1080.0, false), &"", "not in a fight")
	eq(r.due(1081.0, false), &"", "still not")
	eq(r.due(1082.0, true), &"sleep", "the calm comes: saved")
	eq(r.due(1083.0, true), &"", "and only once")
	near(r.last_minutes, 1082.0)


func test_a_new_landscape_asks_once_it_holds_underfoot() -> void:
	var r := AutosaveRules.new(0.0, &"coast")
	r.step_land(&"coast", 5.0)
	eq(r.due(1.0, true), &"", "the landscape you start in is not an arrival")
	# A border walked along: a step in, a step out.
	r.step_land(&"moss", 0.0)
	r.step_land(&"moss", 1.0)
	r.step_land(&"coast", 0.0)
	eq(r.due(2.0, true), &"", "a step over the border and back is not an arrival")
	r.step_land(&"sea", 5.0)
	eq(r.due(3.0, true), &"", "the sea is no landscape to arrive in")
	r.step_land(&"moss", 0.0)
	r.step_land(&"moss", 1.0)
	r.step_land(&"moss", 1.2)
	eq(r.due(4.0, false), &"", "arrived mid-fight: wait")
	eq(r.due(5.0, true), &"land", "arrived: saved")
	r.step_land(&"moss", 10.0)
	eq(r.due(6.0, true), &"", "staying is not arriving again")


func test_every_three_hours_and_any_save_restarts_the_count() -> void:
	var r := AutosaveRules.new(100.0)
	eq(r.due(100.0 + AutosaveRules.EVERY_MINUTES - 1.0, true), &"", "not yet")
	eq(r.due(100.0 + AutosaveRules.EVERY_MINUTES, false), &"", "due, but a fight is on")
	eq(r.due(100.0 + AutosaveRules.EVERY_MINUTES + 30.0, true), &"hours", "saved when it is over")
	r.saved(400.0)
	eq(r.due(400.0 + AutosaveRules.EVERY_MINUTES - 1.0, true), &"", "a manual save restarts the hours")
	eq(r.due(400.0 + AutosaveRules.EVERY_MINUTES, true), &"hours")


func test_the_running_game_autosaves_on_sleep_but_not_with_a_machine_on_it() -> void:
	Sx.use_root("autosave")
	var g := Sx.game(tree, ["--seed=1", "--size=48"])
	var saver := Sx.system(g, "05_save")
	var written: Array = []
	saver.connect("wrote", func(slot: int, reason: StringName) -> void: written.append([slot, reason]))
	# A machine on the player: the sleep's save waits.
	var mobs := Sx.system(g, "30_mobs")
	mobs.get("coast").set("spawning", false)
	g.player.sim.clear_mobs()
	check(mobs.call("place_near_player", &"runner") != null, "a runner is put beside the player")
	await _frames(3)
	check(not bool(saver.call("calm")), "a hostile close is not calm")
	# (A short skip: a whole night would clear the coast, and with it the runner.)
	Events.time_skipped.emit(10.0, &"sleep")
	await _frames(3)
	eq(written, [], "no save while it is there")
	check(not SaveSlots.exists(SaveSlots.AUTO), "no autosave file yet")
	eq(saver.call("save_to", 1), "Not with that so close.", "nor a manual one")
	g.player.sim.clear_mobs()
	# The body's node goes on the next frame or so; a loaded machine may take a few more.
	await _until(func() -> bool: return not written.is_empty(), 240)
	check(bool(saver.call("calm")), "calm again")
	eq(written, [[SaveSlots.AUTO, &"sleep"]], "the sleep's save, once it is over")
	var r := SaveFile.read(SaveSlots.path(SaveSlots.AUTO))
	check(r.ok, "the autosave reads: %s" % r.why)
	eq(SaveCodec.to_int(r.header.get("seed")), 1)
	check(r.data.has("inventory") and r.data.has("world"), "with the game in it")
	# Three hours on the clock asks again.
	g.clock.minutes += AutosaveRules.EVERY_MINUTES + 1.0
	await _until(func() -> bool: return written.size() > 1, 240)
	eq(written.back(), [SaveSlots.AUTO, &"hours"], "three hours on")
	Sx.end(g)
	Sx.finish()


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Process frames until `done` holds, or `most` frames have gone.
func _until(done: Callable, most: int) -> void:
	for i in most:
		if done.call():
			return
		await tree.process_frame
