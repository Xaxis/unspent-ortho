extends TestCase
## The title: it shows a coast, draws the next one after a while, and New game
## starts a game on the coast being shown.
##
## WHAT IS ON DISK IS PART OF WHAT NEW GAME DOES, so the tests that press it give
## themselves a slot folder of their own. `UiTitleMenu` asks once, before a new
## game writes over an autosave, and that ask is a real feature — but it made
## these two tests depend on whether some EARLIER test in the same shard had left
## an autosave in the runner's shared folder. They failed in the gate and passed
## run alone, which read as a flake and was diagnosed twice as the three shards
## sharing a save directory. They do share one, and that was not it: shard 0 run
## completely by itself failed the same way. It is one process, in file order.
##
## So the precondition is stated instead of inherited, and the ask has a test of
## its own below — it had none, and the only thing exercising it was the accident.

const Sx := preload("res://tests/save/save_fixture.gd")


func _title() -> UiTitle:
	var holder := Node.new()
	holder.name = "holder"
	tree.root.add_child(holder)
	var t := UiTitle.new()
	holder.add_child(t)
	t.setup(BootOptions.parse(["--size=48", "--seed=5"]))
	return t


## `seconds` is TITLE time, stepped by hand, but what it waits for is a coast
## built by a WORKER thread in real time -- so the step budget is really a fixed
## wall-clock budget of about 4 ms a step. That fits on a quiet box (2 s alone)
## and runs out under load: at load 76-112 the worker was several times slower
## and the gate failed "a coast is drawn" on code that passed alone. Waiting is
## exactly what `machine_slack` is for, so the budget stretches with the box.
func _run(t: UiTitle, seconds: float, until: Callable) -> bool:
	var dt := 0.1
	var waited := 0.0
	seconds *= machine_slack()
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
	Sx.use_root("title-new")
	var t := _title()
	var holder := t.get_parent()
	check(await _run(t, 20.0, func() -> bool: return t.world != null), "a coast is drawn")
	t.menu.select(&"new")
	t.menu.handle(&"confirm")
	# Who wakes comes first: the character page, and nothing started behind it.
	check(t.character.is_open, "new game opens the character page")
	check(not t._starting, "and the game waits for it")
	t.character.select(&"build")
	t.character.handle(&"right")
	var build: StringName = t.character.look.build
	t.character.select(&"begin")
	t.character.handle(&"confirm")
	check(not t.character.is_open, "begin closes the page")
	var started := func() -> bool: return holder.get_node_or_null("game") != null
	check(await _run(t, 10.0, started), "new game replaces the title")
	var game := holder.get_node_or_null("game") as Game
	if game != null:
		eq(game.options.seed_value, 5, "same coast")
		eq(StringName(game.options.avatar.get("build", &"")), build, "with the body made on the page")
	holder.free()
	Sx.finish()


func test_back_on_the_character_page_is_the_title_again() -> void:
	Sx.use_root("title-back")
	var t := _title()
	var holder := t.get_parent()
	t.menu.settle()
	t.menu.select(&"new")
	t.menu.handle(&"confirm")
	check(t.character.is_open, "the page is up")
	t.character.handle(&"back")
	check(not t.character.is_open, "back shuts it")
	check(not t._starting, "and nothing starts")
	check(t.menu.is_open, "the title's list is still there")
	holder.free()
	Sx.finish()


## The ask that made the two above depend on what ran before them, tested on
## purpose: with an autosave standing, the first press says what it would cost
## and starts nothing, and the second press goes through.
func test_new_game_asks_once_before_it_writes_over_an_autosave() -> void:
	Sx.use_root("title-ask")
	var g := Sx.game(tree, ["--seed=3", "--size=64"])
	eq(Sx.system(g, "05_save").call("save_to", SaveSlots.AUTO), "", "an autosave is written")
	Sx.end(g)
	check(SaveSlots.exists(SaveSlots.AUTO), "and it is on disk for the title to find")
	var t := _title()
	var holder := t.get_parent()
	t.menu.settle()
	t.menu.select(&"new")
	t.menu.handle(&"confirm")
	check(not t.character.is_open, "the first press does not start a game")
	check(not t._starting)
	eq(t.menu.note, UiTitleMenu.ASK_NEW, "it says what pressing again would cost")
	t.menu.handle(&"confirm")
	check(t.character.is_open, "the second press goes through to who wakes")
	holder.free()
	Sx.finish()


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
