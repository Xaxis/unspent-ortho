extends TestCase
## Dev mode on the title: the app opens over the title's slate and takes the
## keys while it is up, a configuration kept there is written where the test
## runner keeps its own, and a new game from the title starts as the
## configuration says.


func _title() -> UiTitle:
	var holder := Node.new()
	holder.name = "holder"
	tree.root.add_child(holder)
	var t := UiTitle.new()
	holder.add_child(t)
	t.setup(BootOptions.parse(["--size=48", "--seed=5"]))
	return t


func test_the_app_opens_over_the_title_and_the_title_keeps_off_the_keys() -> void:
	var was_asked := DevMode.asked
	DevMode.asked = true
	var t := _title()
	check(t.dev != null, "the title has dev mode's hook")
	t.menu.settle()
	var before := t.menu.menu.index
	t.dev.open()
	check(t.dev.is_open(), "the dev app is up on the title")
	eq(t.dev.screen.page().rows().filter(func(r: Dictionary) -> bool: return r.get("id") == &"go").size(), 0, "no in-play pages without a game")
	Input.action_press(&"move_down")
	t.menu._process(0.016)
	Input.action_release(&"move_down")
	eq(t.menu.menu.index, before, "the title's own list did not move under it")
	t.dev.screen.handle(&"dev_toggle")
	check(not t.dev.is_open(), "` shuts it")
	t.get_parent().free()
	DevMode.asked = was_asked


func test_a_configuration_kept_on_the_test_runner_goes_to_its_own_folder() -> void:
	check(GameConfig.use("playtest") == "")
	GameConfig.set_value("world.hour", 19.5)
	var name := "test-kept-%d" % Time.get_ticks_usec()
	eq(GameConfig.keep_as(name), "")
	var path := GameConfig.user_dir().path_join(name + ".json")
	check(FileAccess.file_exists(path), "written under the test runner's own root")
	check(not FileAccess.file_exists(ProjectSettings.globalize_path(GameConfig.DIR).path_join(name + ".json")), "never into the repository's configs/")
	eq(GameConfig.active, name, "and in use")
	var back := GameConfig.read_file(name)
	eq(back.base, "", "a copy of playtest stands on playtest's own base (none)")
	eq(float(GameConfig.resolve(name).settings.get("world.hour", 0.0)), 19.5)
	eq(str(GameConfig.resolve(name).settings.get("dev.access", "")), "chord", "with everything playtest said")
	DirAccess.remove_absolute(path)
	GameConfig.clear()


func test_new_game_from_the_title_starts_as_the_configuration_says() -> void:
	GameConfig.clear()
	GameConfig.set_value("world.hour", 21.0)
	GameConfig.set_value("start.lamp", true)
	var holder := Node.new()
	tree.root.add_child(holder)
	var t := UiTitle.new()
	holder.add_child(t)
	t.setup(BootOptions.parse(["--size=48", "--seed=6"]))
	t._start_game()
	await tree.process_frame
	var game: Game = null
	for c in holder.get_children():
		if c is Game:
			game = c
	check(game != null, "a game took the title's place")
	if game != null:
		near(game.clock.hour(), 21.0, 0.05, "at the configuration's hour")
		check(game.options.lamp, "with the lamp lit")
	holder.free()
	GameConfig.clear()


func test_the_key_that_shuts_dev_mode_is_not_a_press_on_the_title() -> void:
	var was_asked := DevMode.asked
	DevMode.asked = true
	var t := _title()
	t.menu.settle()
	t.menu.select(&"new")
	t.dev.open()
	# e goes down on the app (it closes on it, here by hand) and is still held as
	# the title's list takes the keys back, frames later.
	Input.action_press(&"use")
	await tree.process_frame
	await tree.process_frame
	t.dev.screen.close()
	for i in 3:
		await tree.process_frame
	Input.action_release(&"use")
	await tree.process_frame
	check(not t._starting, "the held e did not start a new game")
	t.get_parent().free()
	DevMode.asked = was_asked
