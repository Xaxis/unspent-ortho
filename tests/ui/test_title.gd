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
