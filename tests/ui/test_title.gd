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
	pause.handle(&"down")
	pause.handle(&"down")
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
