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


func test_crafting_needs_a_station() -> void:
	var g := _make()
	var ui := _ui(g)
	var said: Array = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	check(not ui.call("open_screen", &"crafting") or UiRules.station_near(g.query, g.player.pos) != &"", "no station, no making page")
	g.world.props.append(WorldProp.new(99999, PropKind.FIRE, g.player.pos + Vector2(1, 0), 0.0, 1.0))
	g.query.add_prop(g.world.props.back())
	check(ui.call("open_screen", &"crafting"), "opens beside a fire")
	eq((ui.call("top") as UiCraftingScreen).station, &"fire")
	Events.message.disconnect(listen)
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
