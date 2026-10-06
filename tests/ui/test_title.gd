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


## `seconds` is TITLE time, stepped by hand: the fade and the hold are the
## title's own clock. But the next coast is built by a WORKER thread in REAL time,
## and while that builds the title's clock is not spent: stepped 4 ms apart, a
## 20 s budget left the worker well under a real second, which held alone and ran
## out whenever the shard's neighbours kept the box or the pool busy (the gate
## failed "a coast is drawn" twice, on code that passed alone, and a 1.5 s stall
## in the worker reproduces it exactly). So the worker's wait is bounded by a
## wall-clock deadline instead, WORKER_WAIT stretched by `machine_slack`.
const WORKER_WAIT := 60.0


func _run(t: UiTitle, seconds: float, until: Callable) -> bool:
	var dt := 0.1
	var waited := 0.0
	seconds *= machine_slack()
	var deadline := Time.get_ticks_msec() + int(WORKER_WAIT * 1000.0 * machine_slack())
	while waited < seconds:
		if not is_instance_valid(t) or until.call():
			return true
		var building := t._task >= 0
		t._process(dt)
		await tree.process_frame
		# Chunks stream from a worker in real time; a headless frame takes well
		# under a millisecond, so give the worker a little of it per step.
		OS.delay_msec(4)
		if building and Time.get_ticks_msec() < deadline:
			continue
		waited += dt
	return until.call()


func test_title_keeps_its_coast_until_the_player_turns_the_island() -> void:
	var t := _title()
	var holder := t.get_parent()
	check(await _run(t, 20.0, func() -> bool: return t.world != null), "a coast is drawn")
	eq(t.seed_value, 5)
	check(t.menu.is_open, "the menu is up")
	# Idle for longer than the old cycle ever waited: no next world is grown.
	t._shown_for = 600.0
	t._process(0.05)
	check(not t._drawing(), "an idle title grows no other world")
	eq(t.seed_value, 5, "and keeps the coast it shows")
	t.change_seed(1)
	check(await _run(t, 30.0, func() -> bool: return t.seed_value == 6), "right draws the next coast")
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


## The black stand-ins a scene's lights are drawn beside, as [class, reach, angle,
## casts] under `root`: the light state every material's program is built for.
func _light_state(root: Node) -> Array:
	var out: Array = []
	for n: Node in root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l.light_color != Color.BLACK or l.shadow_enabled:
			continue
		var reach := INF
		var angle := 0.0
		if l is OmniLight3D:
			reach = (l as OmniLight3D).omni_range
		elif l is SpotLight3D:
			reach = (l as SpotLight3D).spot_range
			angle = (l as SpotLight3D).spot_angle
		# A lamp of the pool, out for now, is not a stand-in: they reach everything.
		if reach < ConstantLights.REACH:
			continue
		out.append([l.get_class(), reach, angle])
	out.sort()
	return out


func test_the_title_draws_its_coast_in_the_games_light_state() -> void:
	# A program is built per light state, so a coast drawn without the game's black
	# stand-ins had every one of its programs built again on the press.
	var t := _title()
	var holder := t.get_parent()
	check(await _run(t, 20.0, func() -> bool: return t.world != null), "a coast is drawn")
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"])))
	var game_state := _light_state(g)
	eq(game_state.size(), 3, "the game stands its omni, spot and sun stand-ins")
	eq(_light_state(t), game_state, "and the title stands the same three")
	t._process(0.1)
	var omni := t.find_children("*", "OmniLight3D", true, false)[0] as OmniLight3D
	near(omni.position.distance_to(t.camera.target), 3.0, 0.01, "over what the title's camera looks at")
	g.queue_free()
	holder.free()
	await frames(1)
