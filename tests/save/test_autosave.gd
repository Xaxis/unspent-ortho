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
	r.step_land(&"coast", AutosaveRules.LAND_GAP)
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


func test_a_landscape_already_entered_or_too_soon_after_a_save_does_not_write_again() -> void:
	var r := AutosaveRules.new(0.0, &"coast")
	r.step_land(&"coast", AutosaveRules.LAND_GAP)
	for i in 3:
		r.step_land(&"moss", 0.0)
		r.step_land(&"moss", AutosaveRules.SETTLE + 1.0)
		r.step_land(&"coast", 0.0)
		r.step_land(&"coast", AutosaveRules.SETTLE + 1.0)
	eq(r.due(1.0, true), &"land", "moss, the first time: saved")
	r.step_land(&"moss", 0.0)
	r.step_land(&"moss", AutosaveRules.LAND_GAP)
	r.step_land(&"coast", 0.0)
	r.step_land(&"coast", AutosaveRules.LAND_GAP)
	check(not r.waiting(2.0), "walking the same border again asks for nothing")
	eq(r.due(2.0, true), &"")
	# A third landscape, close behind the last save: it waits out the gap.
	r.step_land(&"pinewood", 0.0)
	r.step_land(&"pinewood", AutosaveRules.SETTLE)
	check(r.waiting(3.0), "pinewood is new: a save is waiting")
	r.saved(3.0)
	r.step_land(&"burning", 0.0)
	r.step_land(&"burning", AutosaveRules.SETTLE)
	eq(r.due(4.0, true), &"", "but not within a minute of play of the last save")
	r.step_land(&"burning", AutosaveRules.LAND_GAP)
	eq(r.due(5.0, true), &"land", "once the minute is out")
	# Sleep and the hours are not held back by the gap.
	r.slept()
	eq(r.due(6.0, true), &"sleep", "sleep saves at once")
	# A loaded game remembers where it has been.
	var loaded := AutosaveRules.new(0.0, &"coast")
	loaded.enter_all(r.entered_list())
	eq(loaded.entered_list(), ["burning", "coast", "moss", "pinewood"])
	loaded.step_land(&"moss", 0.0)
	loaded.step_land(&"moss", AutosaveRules.LAND_GAP)
	check(not loaded.waiting(7.0), "moss was entered before the save")


func test_every_three_hours_and_any_save_restarts_the_count() -> void:
	var r := AutosaveRules.new(100.0)
	eq(r.due(100.0 + AutosaveRules.EVERY_MINUTES - 1.0, true), &"", "not yet")
	check(not r.waiting(100.0 + AutosaveRules.EVERY_MINUTES - 1.0), "nothing waiting: no need to ask whether it is quiet")
	check(r.waiting(100.0 + AutosaveRules.EVERY_MINUTES), "due")
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


func test_no_autosave_under_the_loading_page_either() -> void:
	Sx.use_root("autosave-boot-page")
	var g := Sx.game(tree, ["--seed=1", "--size=48"])
	var saver := Sx.system(g, "05_save")
	var written: Array = []
	saver.connect("wrote", func(slot: int, reason: StringName) -> void: written.append([slot, reason]))
	var mobs := Sx.system(g, "30_mobs")
	mobs.get("coast").set("spawning", false)
	g.player.sim.clear_mobs()
	# The loading page draws over the first frames of every start, and the first
	# autosave of a game falls due early enough to land under it on a machine
	# slow to lift it. Its picture would be the page, not the world.
	var page := Node.new()
	page.add_to_group(&"boot_page")
	tree.root.add_child(page)
	g.clock.minutes += AutosaveRules.EVERY_MINUTES + 1.0
	await _frames(10)
	check(bool(saver.call("calm")), "it is calm")
	check(bool(saver.call("under_boot_page")), "but the loading page is still up")
	check(not bool(saver.call("quiet")), "so it is not quiet")
	eq(written, [], "and no autosave is taken under it")
	tree.root.remove_child(page)
	page.free()
	await _until(func() -> bool: return not written.is_empty(), 60)
	eq(written, [[SaveSlots.AUTO, &"hours"]], "once the page has lifted")
	Sx.end(g)
	Sx.finish()


func test_no_autosave_under_an_open_page_nor_on_the_frame_it_closes() -> void:
	Sx.use_root("autosave-page")
	var g := Sx.game(tree, ["--seed=1", "--size=48"])
	var saver := Sx.system(g, "05_save")
	var ui := Sx.system(g, "90_ui")
	var written: Array = []
	saver.connect("wrote", func(slot: int, reason: StringName) -> void: written.append([slot, reason]))
	var mobs := Sx.system(g, "30_mobs")
	mobs.get("coast").set("spawning", false)
	g.player.sim.clear_mobs()
	await _frames(4)
	check(bool(ui.call("open_screen", &"map")), "the map is open (it does not pause the world)")
	check(not tree.paused, "the world runs under it")
	# The hours come round under the map, and a sleep asks too.
	g.clock.minutes += AutosaveRules.EVERY_MINUTES + 1.0
	await _frames(10)
	check(bool(saver.call("calm")), "it is calm")
	check(not bool(saver.call("quiet")), "but a page is open: not quiet")
	eq(written, [], "no autosave while the map is open (its picture would be the map)")
	(ui.call("top") as UiScreen).handle(&"back")
	check(g.open_screens.is_empty(), "the map is closed")
	await tree.process_frame
	eq(written, [], "nor on the frame it closes, which still shows the page")
	await _until(func() -> bool: return not written.is_empty(), 60)
	eq(written, [[SaveSlots.AUTO, &"hours"]], "once the world has been drawn again")
	# A save from the pause page takes the world as it was when the page opened.
	check(bool(ui.call("open_screen", &"pause")), "paused")
	eq(saver.call("save_to", 1), "", "a manual save needs only calm")
	eq(written.back(), [1, &"manual"])
	(ui.call("top") as UiScreen).handle(&"back")
	Sx.end(g)
	Sx.finish()


func test_leaving_for_the_title_writes_the_autosave_when_calm() -> void:
	Sx.use_root("autosave-leaving")
	var g := Sx.game(tree, ["--seed=1", "--size=48"])
	var saver := Sx.system(g, "05_save")
	var ui := Sx.system(g, "90_ui")
	var written: Array = []
	saver.connect("wrote", func(slot: int, reason: StringName) -> void: written.append([slot, reason]))
	var mobs := Sx.system(g, "30_mobs")
	mobs.get("coast").set("spawning", false)
	g.player.sim.clear_mobs()
	# A machine close: leaving cannot save.
	check(mobs.call("place_near_player", &"runner") != null, "a runner beside the player")
	await _frames(3)
	check(not bool(saver.call("calm")), "not calm")
	check(bool(ui.call("open_screen", &"pause")), "paused")
	var pause: UiPauseScreen = ui.call("top")
	eq(pause.saved_line(), "not saved yet", "the pause page says nothing is saved")
	var went := [0]
	pause.to_title = func() -> void: went[0] += 1
	pause.select(&"title")
	pause.handle(&"confirm")
	eq(went[0], 1, "to the title")
	eq(written, [], "not with a machine on the player")
	g.player.sim.clear_mobs()
	await _until(func() -> bool: return bool(saver.call("calm")), 240)
	# Calm: to the title writes the autosave first.
	check(bool(ui.call("open_screen", &"pause")), "paused again")
	pause.select(&"title")
	pause.handle(&"confirm")
	eq(went[0], 2)
	eq(written, [[SaveSlots.AUTO, &"quit"]], "leaving wrote the autosave")
	var r := SaveFile.read(SaveSlots.path(SaveSlots.AUTO))
	check(r.ok, "and it reads: %s" % r.why)
	check(bool(ui.call("open_screen", &"pause")), "paused once more")
	eq(pause.saved_line(), "saved just now", "the pause page says when it was saved")
	pause.handle(&"back")
	# The window closed from play: the same.
	saver.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	eq(written.size(), 2, "closing the window saves too")
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
