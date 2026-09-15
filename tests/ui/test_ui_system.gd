extends TestCase
## The ui system inside a real (small) game: it is loaded from src/systems,
## opens screens by name, blocks gameplay input while one is open, pauses the
## world only for pause, refuses pages with a hostile close, and keeps the map.

var _game: Game


func _make(extra: PackedStringArray = []) -> Game:
	var args := PackedStringArray(["--size=64", "--seed=4"])
	args.append_array(extra)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(args))
	return g


func _ui(g: Game) -> Node:
	for s in g.systems:
		if s.name == "90_ui":
			return s
	return null


func test_system_is_loaded_and_opens_screens() -> void:
	var g := _make()
	var ui := _ui(g)
	check(ui != null, "90_ui is loaded from src/systems")
	check(not g.input_blocked())
	check(ui.call("open_screen", &"inventory"), "inventory opens")
	check(g.input_blocked(), "gameplay input blocked while a page is open")
	check(not g.hud.visible, "the HUD steps aside for the notebook")
	var s: UiScreen = ui.call("top")
	s.handle(&"back")
	check(not g.input_blocked(), "and unblocked when it closes")
	check(g.hud.visible)
	check(ui.call("open_screen", &"map"), "map opens")
	ui.call("top").handle(&"map")
	check(ui.call("open_screen", &"pause"))
	check(tree.paused, "pause stops the world")
	ui.call("top").handle(&"back")
	check(not tree.paused, "and resumes it")
	g.free()


func test_crafting_needs_a_station_or_hand_work() -> void:
	var g := _make()
	var ui := _ui(g)
	var hand := not Crafting.recipes_at(&"hand").is_empty()
	var opened: bool = ui.call("open_screen", &"crafting")
	if hand:
		check(opened, "things made by hand can be made anywhere")
		eq((ui.call("top") as UiCraftingScreen).stations.back(), &"hand")
		ui.call("top").handle(&"back")
	else:
		check(not opened or Survival.station_near(g) != &"", "no station, no making page")
	g.world.props.append(WorldProp.new(99999, PropKind.FIRE, g.player.pos + Vector2(1, 0), 0.0, 1.0))
	g.query.add_prop(g.world.props.back())
	check(ui.call("open_screen", &"crafting"), "opens beside a fire")
	eq((ui.call("top") as UiCraftingScreen).stations[0], &"fire", "the fire's recipes come first")
	g.free()


func test_pages_are_refused_with_a_hostile_close() -> void:
	var g := _make()
	var ui := _ui(g)
	var mob := Node.new()
	mob.set_script(_mob_script())
	mob.set("pos", g.player.pos + Vector2(3, 0))
	mob.add_to_group(&"mobs")
	tree.root.add_child(mob)
	check(not ui.call("open_screen", &"inventory"), "not with a machine that close")
	check(not g.input_blocked())
	check(ui.call("open_screen", &"pause"), "pause is always allowed")
	ui.call("top").handle(&"back")
	mob.free()
	g.free()


func test_give_and_screen_options() -> void:
	var g := _make(["--give=stone:3,scrap:2", "--screen=inventory"])
	eq(g.inventory.count(&"stone"), 3)
	for i in 3:
		await tree.process_frame
	check(g.input_blocked(), "--screen opened the inventory")
	g.free()


func test_walking_is_remembered_for_the_map() -> void:
	var g := _make()
	var ui := _ui(g)
	var e: UiExplored = ui.get("explored")
	check(e.seen(floori(g.player.pos.x), floori(g.player.pos.y)), "the start is seen")
	g.free()


static func _mob_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar pos := Vector2.ZERO\nvar alive := true\nvar kind := &\"runner\"\n"
	s.reload()
	return s


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await tree.process_frame
	await tree.process_frame
	Input.action_release(action)
	await tree.process_frame


func test_the_real_actions_open_and_close_pages() -> void:
	# Tours press actions (Input.action_press), not key events: the notebook answers both.
	var g := _make()
	var ui := _ui(g)
	await tree.process_frame
	await _tap(&"inventory")
	var s: UiScreen = ui.call("top")
	check(s != null and s.screen_name == &"inventory", "the inventory action opens the carrying page")
	await tree.process_frame
	check(ui.call("top") == s, "and it stays open")
	await _tap(&"pause")
	check(ui.call("top") == null, "esc closes the page")
	check(not tree.paused, "and does not fall through to pause")
	await _tap(&"map")
	var m: UiScreen = ui.call("top")
	check(m != null and m.screen_name == &"map", "the map action opens the map")
	await _tap(&"map")
	check(ui.call("top") == null, "and closes it")
	# After a slow frame physics catches up in one go: a tap can go down and up
	# between two _process calls. The physics step notes it.
	Input.action_press(&"inventory")
	ui.call("_physics_process", 1.0 / 60.0)
	Input.action_release(&"inventory")
	ui.call("_physics_process", 1.0 / 60.0)
	ui.call("_process", 0.016)
	var q: UiScreen = ui.call("top")
	check(q != null and q.screen_name == &"inventory", "a tap seen only by physics still opens the page")
	g.free()
