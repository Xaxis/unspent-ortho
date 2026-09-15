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


func test_home_is_no_way_round_the_hostile_rule() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	for i in 3:
		await tree.process_frame
	# A fire in reach, so making would open if nothing were near.
	g.world.props.append(WorldProp.new(99998, PropKind.FIRE, g.player.pos + Vector2(1, 0), 0.0, 1.0))
	g.query.add_prop(g.world.props.back())
	var mob := _mob(g.player.pos + Vector2(1, 1), &"runner")
	await _tap(&"pause")
	var home: UiScreen = ui.call("top")
	check(home != null and home.screen_name == &"pause", "home opens beside a runner")
	home.select(&"loadout")
	await _tap(&"use")
	var gear: UiScreen = ui.call("top")
	check(gear != null and gear.screen_name == &"loadout", "gear only reads: it opens over home")
	for key: StringName in [&"inventory", &"craft", &"map"]:
		await _tap(key)
		var top: UiScreen = ui.call("top")
		check(top != null and top.screen_name == &"loadout", "%s from gear is refused with a runner that close" % key)
		check(top.note_warn and top.note == (ui.get_script() as GDScript).get_script_constant_map()["NEAR_LINE"], "and the glass says why: %s" % top.note)
	await _tap(&"pause")
	for key: StringName in [&"inventory", &"craft"]:
		await _tap(key)
		var top: UiScreen = ui.call("top")
		check(top != null and top.screen_name == &"pause", "%s on home is refused too" % key)
	check(not (ui.get("screens") as Dictionary)[&"inventory"].is_open, "carrying never opened")
	check(not (ui.get("screens") as Dictionary)[&"crafting"].is_open, "making never opened")
	await _tap(&"pause")
	check(ui.call("top") == null, "esc closes home")
	mob.free()
	g.free()


func test_app_keys_open_their_apps_over_home() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	for i in 3:
		await tree.process_frame
	await _tap(&"pause")
	for pair: Array in [[&"inventory", &"inventory"], [&"map", &"map"]]:
		await _tap(pair[0])
		var top: UiScreen = ui.call("top")
		check(top != null and top.screen_name == pair[1], "%s on home opens %s" % pair)
		check(tree.paused, "the world stays stopped")
		await _tap(&"pause")
		var back: UiScreen = ui.call("top")
		check(back != null and back.screen_name == &"pause", "esc backs out to home")
	# Making still needs somewhere to make things: beside a fire it opens over home.
	g.world.props.append(WorldProp.new(99997, PropKind.FIRE, g.player.pos + Vector2(1, 0), 0.0, 1.0))
	g.query.add_prop(g.world.props.back())
	await _tap(&"craft")
	var made: UiScreen = ui.call("top")
	check(made != null and made.screen_name == &"crafting", "c on home opens making beside a fire")
	await _tap(&"pause")
	await _tap(&"pause")
	check(ui.call("top") == null and not tree.paused, "and the world goes on")
	g.free()


func test_machine_reads_list_machines_not_animals() -> void:
	var g := _make()
	_calm(g)
	var dog := _mob(g.player.pos + Vector2(2, 0), &"dog.yard")
	var gull := _mob(g.player.pos + Vector2(0, 2), &"gulls")
	var runner := _mob(g.player.pos + Vector2(3, 0), &"runner")
	var feed := SlateFeeds.default_reads(g)
	var kinds: Array = (feed.scans as Array).map(func(s: Dictionary) -> StringName: return s.kind)
	eq(kinds, [&"runner"], "only the machine gives a signature")
	for m: Node in [dog, gull, runner]:
		m.free()
	g.free()


func _mob(at: Vector2, kind: StringName) -> Node:
	var mob := Node.new()
	mob.set_script(_mob_script())
	mob.set("pos", at)
	mob.set("kind", kind)
	mob.add_to_group(&"mobs")
	tree.root.add_child(mob)
	return mob


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


## No machine comes near while keys are tested: a slow run must not turn the
## test into a fight that refuses the apps.
func _calm(g: Game) -> void:
	for s in g.systems:
		if s.name == "30_mobs":
			(s.get("coast") as Object).set("spawning", false)
	if g.player.sim != null:
		g.player.sim.clear_mobs()


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
	# That press went down and up inside this frame: let the frame end, or the
	# next test's game reads it as just pressed.
	await tree.process_frame
	g.free()


func test_an_app_key_switches_the_glass_to_that_app() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	for i in 3:
		await tree.process_frame
	check(ui.call("top") == null, "nothing open before the first key")
	await _tap(&"inventory")
	var first: UiScreen = ui.call("top")
	check(first != null and first.screen_name == &"inventory", "I opens carrying")
	await _tap(&"map")
	var top: UiScreen = ui.call("top")
	check(top != null and top.screen_name == &"map", "M on carrying switches to the map")
	eq((ui.get("stack") as Array).size(), 1, "one app on the glass, not two")
	check(not (ui.get("screens") as Dictionary)[&"inventory"].is_open, "carrying closed")
	check(g.input_blocked(), "and play stays paused through the switch")
	# Tapped again straight after: a held key's note must not swallow the next press.
	await _tap(&"map")
	check(ui.call("top") == null, "the map's own key closes it")
	check(not g.input_blocked(), "play resumes: %s" % str(g.open_screens))
	g.free()


func test_gear_reads_and_saves_are_reached_from_home_with_real_keys() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	for i in 3:
		await tree.process_frame
	for app: StringName in [&"loadout", &"reads", &"saves"]:
		await _tap(&"pause")
		var home: UiPauseScreen = ui.call("top")
		check(home != null and home.screen_name == &"pause", "esc opens home")
		var guard := 0
		while home.menu.selected().get("id") != app and guard < 10:
			await _tap(&"move_down")
			guard += 1
		eq(home.menu.selected().get("id"), app, "down reaches %s" % app)
		await _tap(&"use")
		var top: UiScreen = ui.call("top")
		check(top != null and top.screen_name == app, "e opens %s over home" % app)
		check(tree.paused, "the world stays stopped under it")
		await _tap(&"pause")
		var back: UiScreen = ui.call("top")
		check(back != null and back.screen_name == &"pause", "esc backs out to home")
		await _tap(&"pause")
		check(ui.call("top") == null and not tree.paused, "and esc again resumes")
	g.free()


func test_the_slate_whines_once_when_power_runs_low() -> void:
	var g := _make()
	var ui := _ui(g)
	var heard: Array[StringName] = []
	var listen := func(n: StringName, _at: Vector3) -> void: heard.append(n)
	Events.sfx.connect(listen)
	SurvivalState.of(g).lamp_oil = UiRules.POWER_LAMP_MINUTES
	ui.call("_step_power")
	eq(heard.count(&"ui_slate_whine"), 0, "a full lamp: no whine")
	SurvivalState.of(g).lamp_oil = UiRules.POWER_LAMP_MINUTES * 0.1
	g.inventory.remove(&"oil", g.inventory.count(&"oil"))
	ui.call("_step_power")
	ui.call("_step_power")
	eq(heard.count(&"ui_slate_whine"), 1, "low: one whine, not one a frame")
	lt(g.hud.power, UiSlate.LOW_POWER, "the HUD dims with it")
	SurvivalState.of(g).lamp_oil = UiRules.POWER_LAMP_MINUTES
	ui.call("_step_power")
	SurvivalState.of(g).lamp_oil = UiRules.POWER_LAMP_MINUTES * 0.1
	ui.call("_step_power")
	eq(heard.count(&"ui_slate_whine"), 2, "refilled and run low again: it whines again")
	Events.sfx.disconnect(listen)
	g.free()


func test_the_land_seen_is_saved_and_loaded() -> void:
	var g := _make()
	var ui := _ui(g)
	var e: UiExplored = ui.get("explored")
	e.wander(g.world, g.player.pos, 120, 3)
	var saved: Variant = JSON.parse_string(JSON.stringify(ui.call("_save")))
	var seen := e.fraction()
	var trail := e.trail.size()
	g.free()
	var h := _make()
	var ui2 := _ui(h)
	ui2.call("_load", saved)
	var e2: UiExplored = ui2.get("explored")
	near(e2.fraction(), seen, 1e-6, "the same land is seen")
	eq(e2.trail.size(), trail, "the same way walked")
	check(SaveGame.keys().has(&"ui"), "the slate registers its save")
	h.free()
