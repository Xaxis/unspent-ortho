extends TestCase
## The title: it shows a coast, draws the next one after a while, and New game
## starts a game on the coast being shown.


func _title() -> UiTitle:
	var holder := Node.new()
	holder.name = "holder"
	tree.root.add_child(holder)
	var t := UiTitle.new()
	holder.add_child(t)
	t.setup(BootOptions.parse(["--size=48", "--seed=5"]))
	return t


func _run(t: UiTitle, seconds: float, until: Callable) -> bool:
	var dt := 0.1
	var waited := 0.0
	while waited < seconds:
		if not is_instance_valid(t) or until.call():
			return true
		t._process(dt)
		await tree.process_frame
		# Chunks stream from a worker in real time; a headless frame takes well
		# under a millisecond, so give the worker a little of it per step.
		OS.delay_msec(4)
		waited += dt
	return until.call()


func test_title_shows_a_coast_then_the_next() -> void:
	var t := _title()
	var holder := t.get_parent()
	check(await _run(t, 20.0, func() -> bool: return t.world != null), "a coast is drawn")
	eq(t.seed_value, 5)
	check(t.menu.is_open, "the menu is up")
	t._shown_for = UiTitle.SEED_SECONDS + 1.0
	check(await _run(t, 30.0, func() -> bool: return t.seed_value == 6), "the next coast follows")
	t.change_seed(-1)
	check(await _run(t, 30.0, func() -> bool: return t.seed_value == 5), "left draws the previous coast")
	holder.free()


func test_pause_can_leave_for_the_title() -> void:
	var holder := Node.new()
	tree.root.add_child(holder)
	var g := Game.new()
	g.name = "game"
	holder.add_child(g)
	g.setup(BootOptions.parse(["--size=48", "--seed=2"]))
	var ui: Node = null
	for s in g.systems:
		if s.name == "90_ui":
			ui = s
	check(ui.call("open_screen", &"pause"))
	check(tree.paused)
	var pause: UiPauseScreen = ui.call("top")
	pause.select(&"title")
	pause.handle(&"confirm")
	await tree.process_frame
	await tree.process_frame
	check(not tree.paused, "the world is unpaused for the title")
	var title := holder.get_node_or_null("title") as UiTitle
	check(title != null, "the title replaced the game")
	check(not is_instance_valid(g) or g.is_queued_for_deletion(), "the game is gone")
	holder.free()


func test_new_game_starts_on_the_coast_shown() -> void:
	var t := _title()
	var holder := t.get_parent()
	check(await _run(t, 20.0, func() -> bool: return t.world != null), "a coast is drawn")
	t.menu.handle(&"confirm")
	var started := func() -> bool: return holder.get_node_or_null("game") != null
	check(await _run(t, 10.0, started), "new game replaces the title")
	var game := holder.get_node_or_null("game") as Game
	if game != null:
		eq(game.options.seed_value, 5, "same coast")
	holder.free()


func test_a_new_coast_fades_up_only_once_it_is_drawn() -> void:
	var t := _title()
	var holder := t.get_parent()
	check(await _run(t, 20.0, func() -> bool: return t.world != null), "a coast is drawn")
	check(t.view.pending() > 0, "its chunks stream in rather than all in one frame")
	var early := [false]
	var revealed := func() -> bool:
		if t.view.pending() > 0 and t._fade_to < 1.0:
			early[0] = true
		return t._fade_to == 0.0
	check(await _run(t, 20.0, revealed), "it fades up")
	check(not early[0], "never while chunks are still missing")
	eq(t.view.pending(), 0)
	holder.free()


func test_the_title_opens_on_land_away_from_villages() -> void:
	for s: int in [1, 4]:
		var w := WorldGen.generate(s, 256)
		var o := UiTitle.opening(w)
		var p: Vector2 = o[0]
		var d: Vector2 = o[1]
		gt(w.level_at(floori(p.x), floori(p.y)), 0, "seed %d opens on land" % s)
		check(UiTitle._village_clearance(w, p) >= UiTitle.VILLAGE_CLEAR, "seed %d opens clear of villages: %.0f" % [s, UiTitle._village_clearance(w, p)])
		near(d.length(), 1.0, 1e-4)
		var worst := INF
		for i in 10:
			worst = minf(worst, UiTitle._village_clearance(w, p + d * UiTitle.DRIFT_AHEAD * i / 9.0))
		check(worst > UiTitle.VILLAGE_CLEAR * 0.75, "seed %d drifts clear of villages for a while: %.0f" % [s, worst])
