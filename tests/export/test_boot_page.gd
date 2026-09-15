extends TestCase
## The loading page makes the world, its view and the first view round the
## start, hands them to the scene it builds, reports every stage, and draws a
## sketch of the island with the start on it. BootWorld hands a world over only
## to the scene that asks for the same one.

const SIZE := 64


func _holder() -> Node:
	var holder := Node.new()
	holder.name = "holder"
	tree.root.add_child(holder)
	return holder


## Run a page to its hand-over, frame by frame; returns the progress seen each frame.
func _run_page(page: BootPage) -> Array[float]:
	var seen: Array[float] = []
	for i in 600:
		if page.scene != null and page.stages.done():
			break
		await tree.process_frame
		seen.append(page.progress())
		OS.delay_msec(2)
	return seen


func _check_game_page(threads: bool) -> void:
	BootWorld.clear()
	var holder := _holder()
	var o := BootOptions.parse(["--seed=4", "--size=%d" % SIZE])
	var page := BootPage.new()
	page._plan(holder, o, "game", threads)
	holder.add_child(page)
	var seen := await _run_page(page)
	var game := holder.get_node_or_null("game") as Game
	check(game != null, "the page built the game")
	if game != null:
		eq(game.world.seed_value, 4, "the game got the page's world")
		eq(game.world.size, SIZE)
		check(game.view.chunk_count() > 0, "the first view was drawn before the game existed")
		eq(game.view.chunk_at(game.player.pos) != null, true, "the ground under the player is built")
		eq(game.systems.size(), BootPage.system_scripts().size(), "every system loaded")
	check(not BootWorld.offered(), "the world was taken, not left on offer")
	var t := page.stages.timings()
	var ids: Array[StringName] = [&"code", &"world", &"view", &"near", &"start", &"draw"]
	ids.append(&"compiled" if threads else &"code2")
	for id: StringName in ids:
		check(t.has(id), "stage %s ran (%s)" % [id, "threads" if threads else "no threads"])
	eq(page.progress(), 1.0, "the line is full at the hand-over")
	for i in range(1, seen.size()):
		check(seen[i] >= seen[i - 1] - 0.0001, "the line never goes back")
	check(page._sketch != null, "the island was sketched")
	holder.free()


func test_game_page_with_threads() -> void:
	await _check_game_page(true)


func test_game_page_without_threads_runs_on_the_main_thread_in_steps() -> void:
	await _check_game_page(false)


func test_title_page_prepares_the_coast_it_opens_on() -> void:
	BootWorld.clear()
	var holder := _holder()
	var page := BootPage.new()
	page._plan(holder, BootOptions.parse(["--seed=6", "--size=%d" % SIZE]), "title")
	holder.add_child(page)
	await _run_page(page)
	var title := holder.get_node_or_null("title") as UiTitle
	check(title != null, "the page built the title")
	if title != null:
		for i in 200:
			if title.world != null:
				break
			title._process(0.05)
			await tree.process_frame
		check(title.world != null and title.world.seed_value == 6, "the title shows the page's coast")
		check(title.view != null and title.view.chunk_count() > 0, "with its first view already drawn")
	holder.free()


func test_new_game_from_the_title_keeps_the_coast_it_was_showing() -> void:
	BootWorld.clear()
	var holder := _holder()
	var title := BootPage.open_title(holder, BootOptions.parse(["--seed=7", "--size=%d" % SIZE])) as UiTitle
	for i in 300:
		if title.world != null and title.view != null:
			break
		title._process(0.05)
		await tree.process_frame
		OS.delay_msec(2)
	var shown := title.world
	check(shown != null, "the title shows a coast")
	title._start_game()
	var game := holder.get_node_or_null("game") as Game
	check(game != null, "new game starts")
	if game != null and shown != null:
		check(game.world == shown, "the game plays on the very world the title drew, not a second one")
		check(game.view.chunk_count() > 0, "and keeps its drawn chunks")
	holder.free()


func test_headless_opens_the_scene_at_once() -> void:
	var holder := _holder()
	var game := BootPage.open_game(holder, BootOptions.parse(["--seed=2", "--size=%d" % SIZE]))
	check(game is Game, "no page without a window: the game itself")
	eq(game.name, &"game")
	holder.free()


func test_start_of_matches_where_the_game_puts_the_player() -> void:
	var w := WorldGen.generate(3, SIZE)
	var river := GenPlaces.find(w, "river")
	var cases: Array = [
		[["--seed=3"], w.spawn],
		[["--seed=3", "--village=0"], (w.villages[0].pos as Vector2) + Vector2(3, 3) if not w.villages.is_empty() else w.spawn],
		[["--seed=3", "--at=20,30"], Vector2(20, 30)],
		[["--seed=3", "--place=river"], river if river.x >= 0 else w.spawn],
		[["--seed=3", "--place=nowhere"], w.spawn],
	]
	for c: Array in cases:
		var o := BootOptions.parse(PackedStringArray(c[0] + ["--size=%d" % SIZE]))
		eq(BootWorld.start_of(w, o), c[1], "the rule for %s" % str(c[0]))
		# The page draws round start_of; the game must stand the player on the same tile.
		var holder := _holder()
		var game := Game.new()
		game.name = "game"
		holder.add_child(game)
		game.setup(o)
		eq(game.player.pos, c[1], "the game starts %s there" % str(c[0]))
		holder.free()


func test_the_world_is_handed_only_to_a_scene_that_asks_for_it() -> void:
	var w := WorldGen.generate(9, SIZE)
	BootWorld.offer(w)
	check(BootWorld.world(8, SIZE) != w, "another seed makes its own world")
	check(BootWorld.offered(), "and leaves the offer")
	check(BootWorld.world(9, SIZE) == w, "the same seed and size take it")
	check(not BootWorld.offered(), "taken once")
	var v := BootWorld.view(w)
	check(v.world == w, "a view is made for a world with none on offer")
	BootWorld.offer(w, v)
	var other := BootWorld.view(WorldGen.generate(9, SIZE))
	check(other != v, "an offered view goes only with its own world")
	other.free()
	BootWorld.clear()
	check(not BootWorld.offered())


func test_build_near_draws_the_first_view_one_chunk_at_a_time() -> void:
	var w := WorldGen.generate(5, SIZE)
	var v := BootWorld.view(w)
	var left := BootWorld.build_near(v, w.spawn)
	eq(v.chunk_count(), 1, "one chunk per call")
	var calls := 1
	while left > 0 and calls < 64:
		left = BootWorld.build_near(v, w.spawn)
		calls += 1
	eq(v.pending(), 0, "nothing left to build near the start")
	eq(v.chunk_count(), calls, "one chunk per call, all of them")
	v.free()


func test_the_sketch_draws_the_coast_the_grid_and_the_villages() -> void:
	var w := WorldGen.generate(1, 256)
	var inks := {"coast": Color.RED, "contour": Color.GREEN, "river": Color.BLUE, "grid": Color.YELLOW, "village": Color.MAGENTA}
	var img := BootWorld.sketch(w, 112, inks)
	eq(img.get_size(), Vector2i(112, 112))
	var counts := {}
	for y in 112:
		for x in 112:
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				counts[c.to_html(false)] = int(counts.get(c.to_html(false), 0)) + 1
	gt(float(counts.get(Color.RED.to_html(false), 0)), 100.0, "a coastline")
	check(counts.has(Color.GREEN.to_html(false)), "contours inland")
	if not w.lines.is_empty():
		check(counts.has(Color.YELLOW.to_html(false)), "the machines' grid ruled across")
	check(counts.has(Color.MAGENTA.to_html(false)), "villages")
	var s := Vector2i((w.spawn * 112.0 / w.size).floor())
	eq(w.level_at(int(w.spawn.x), int(w.spawn.y)) > 0, true, "the start is on land, where the page marks it")
	check(s.x >= 0 and s.x < 112 and s.y >= 0 and s.y < 112, "the start's mark is on the sketch")


func test_without_threads_the_title_keeps_its_coast() -> void:
	BootWorld.clear()
	var holder := _holder()
	var title := BootPage.make_title(holder, BootOptions.parse(["--seed=8", "--size=%d" % SIZE])) as UiTitle
	for i in 300:
		if title.world != null and not title._drawing():
			break
		title._process(0.05)
		await tree.process_frame
	check(title.world != null, "the title shows a coast")
	title.cycle_coasts = false
	title._shown_for = UiTitle.SEED_SECONDS + 1.0
	title._process(0.05)
	check(not title._drawing(), "no new coast is started on a build that would make it on the main thread")
	title.cycle_coasts = true
	title._process(0.05)
	check(title._drawing(), "with threads the next coast is on its way")
	holder.free()

