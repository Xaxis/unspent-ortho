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
	_listen_screens()
	for i in 3:
		await tree.process_frame
	check(await _tap_until(&"pause", _opened(&"pause")), "esc opens home")
	for pair: Array in [[&"inventory", &"inventory"], [&"map", &"map"]]:
		check(await _tap_until(pair[0], _opened(pair[1])), "%s on home opens %s" % pair)
		check(tree.paused, "the world stays stopped")
		check(await _tap_until(&"pause", func() -> bool: return not _live.has(pair[1])), "esc backs out to home")
		var back: UiScreen = ui.call("top")
		check(back != null and back.screen_name == &"pause", "and home is under it")
	# Making still needs somewhere to make things: beside a fire it opens over home.
	g.world.props.append(WorldProp.new(99997, PropKind.FIRE, g.player.pos + Vector2(1, 0), 0.0, 1.0))
	g.query.add_prop(g.world.props.back())
	check(await _tap_until(&"craft", _opened(&"crafting")), "c on home opens making beside a fire")
	check(await _tap_until(&"pause", func() -> bool: return not _live.has(&"crafting")), "esc leaves making")
	check(await _tap_until(&"pause", _opened(&"")), "and esc again leaves home")
	check(ui.call("top") == null and not tree.paused, "and the world goes on")
	_drop_screens()
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


## What is open now, kept by the apps' own word (Events.screen_changed).
var _live := {}


func _listen_screens() -> void:
	_live.clear()
	if not Events.screen_changed.is_connected(_note_screen):
		Events.screen_changed.connect(_note_screen)


func _drop_screens() -> void:
	if Events.screen_changed.is_connected(_note_screen):
		Events.screen_changed.disconnect(_note_screen)


func _note_screen(n: StringName, open: bool) -> void:
	if open:
		_live[n] = true
	else:
		_live.erase(n)


## Tap a key the way a player does, then wait until the apps have said they did
## what was expected with it, or a real second has gone by. The wait is on the
## signal the apps emit, never on a count of frames: on a loaded machine a frame
## can carry no key read at all, and a gate that fails then is a gate nobody
## trusts. Returns false if the word never came.
func _tap_until(action: StringName, done: Callable, seconds: float = 4.0) -> bool:
	Input.action_press(action)
	await tree.process_frame
	Input.action_release(action)
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(done.call()):
		if Time.get_ticks_msec() >= deadline:
			return false
		await tree.process_frame
	# Let the frame the press was made in end, or the next reader sees it again.
	await tree.process_frame
	return true


## Wait until app `n` is on the glass (&"" = nothing is).
func _opened(n: StringName) -> Callable:
	return func() -> bool: return _live.has(n) if n != &"" else _live.is_empty()


func test_the_real_actions_open_and_close_pages() -> void:
	# Tours press actions (Input.action_press), not key events: the notebook answers both.
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	_listen_screens()
	await tree.process_frame
	check(await _tap_until(&"inventory", _opened(&"inventory")), "the inventory action opens the carrying page")
	var s: UiScreen = ui.call("top")
	check(s != null and s.screen_name == &"inventory", "and it is the one on the glass")
	await tree.process_frame
	check(ui.call("top") == s, "and it stays open")
	check(await _tap_until(&"pause", _opened(&"")), "esc closes the page")
	check(not tree.paused, "and does not fall through to pause")
	check(await _tap_until(&"map", _opened(&"map")), "the map action opens the map")
	var m: UiScreen = ui.call("top")
	check(m != null and m.screen_name == &"map", "the map is on the glass")
	check(await _tap_until(&"map", _opened(&"")), "and its own key closes it")
	_drop_screens()
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
	_listen_screens()
	for i in 3:
		await tree.process_frame
	check(ui.call("top") == null, "nothing open before the first key")
	check(await _tap_until(&"inventory", _opened(&"inventory")), "I opens carrying")
	check(await _tap_until(&"map", _opened(&"map")), "M on carrying switches to the map")
	var top: UiScreen = ui.call("top")
	check(top != null and top.screen_name == &"map", "the map is the app on the glass")
	eq((ui.get("stack") as Array).size(), 1, "one app on the glass, not two")
	check(not (ui.get("screens") as Dictionary)[&"inventory"].is_open, "carrying closed")
	check(g.input_blocked(), "and play stays paused through the switch")
	# Tapped again straight after: a held key's note must not swallow the next press.
	check(await _tap_until(&"map", _opened(&"")), "the map's own key closes it")
	check(not g.input_blocked(), "play resumes: %s" % str(g.open_screens))
	_drop_screens()
	g.free()


func test_gear_reads_and_saves_are_reached_from_home_with_real_keys() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	for i in 3:
		await tree.process_frame
	_listen_screens()
	for app: StringName in [&"loadout", &"reads", &"saves"]:
		check(await _tap_until(&"pause", _opened(&"pause")), "esc opens home")
		var home: UiPauseScreen = ui.call("top")
		var guard := 0
		while home.menu.selected().get("id") != app and guard < 10:
			await _tap(&"move_down")
			guard += 1
		eq(home.menu.selected().get("id"), app, "down reaches %s" % app)
		check(await _tap_until(&"use", _opened(app)), "e opens %s over home" % app)
		check(tree.paused, "the world stays stopped under it")
		check(await _tap_until(&"pause", func() -> bool: return not _live.has(app)), "esc backs out to home")
		var back: UiScreen = ui.call("top")
		check(back != null and back.screen_name == &"pause", "and home is still under it")
		check(await _tap_until(&"pause", _opened(&"")), "and esc again resumes")
		check(ui.call("top") == null and not tree.paused, "the world goes on")
	_drop_screens()
	g.free()


## A patch of another landscape, written into the world a long way off.
func _patch(g: Game, country: int, at: Vector2) -> Vector2:
	var size := g.world.size
	var c := Vector2(clampf(at.x, 6.0, size - 7.0), clampf(at.y, 6.0, size - 7.0))
	for y in range(floori(c.y) - 4, floori(c.y) + 5):
		for x in range(floori(c.x) - 4, floori(c.x) + 5):
			g.world.country[y * size + x] = country
	return c


## The caption must never lie about where the player is standing. The watcher
## reads the land under them every frame — an open app is not a blindfold — and
## a jump (a tour's `place`, a load, later a portal) is said at once, not after
## the walked border's settle.
func test_the_watcher_reads_the_land_under_the_player_after_a_jump() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	_listen_screens()
	for i in 3:
		await tree.process_frame
	var watch: UiPlaceWatch = ui.get("_places")
	check(watch.announced != &"", "where the player woke was said")
	var other := Country.SNOWFIELD if watch.announced != &"snowfield" else Country.MOSS
	var away := _patch(g, other, g.player.pos + Vector2(24, 0))
	var was := g.hud.place
	check(await _tap_until(&"inventory", _opened(&"inventory")), "an app takes the glass")
	# The fight body owns where the player is: a jump moves it too (CLAUDE.md).
	g.player.pos = away
	if g.player.sim != null:
		g.player.sim.hero.pos = away
	for i in 3:
		await tree.process_frame
	eq(watch.announced, StringName(Country.NAMES[other]), "the watcher read the land under the player with an app up")
	eq(g.hud.place, was, "and nothing was pinged where nobody could read it")
	check(await _tap_until(&"pause", _opened(&"")), "the app closes")
	for i in 3:
		await tree.process_frame
	eq(g.hud.place, BiomeRegistry.get_def(StringName(Country.NAMES[other])).display_name, "and the name waiting is pinged then")
	_drop_screens()
	g.free()


## A name that waited for a glass nobody could read is only said if it is still
## true. Cross a border in a fight, be pushed back over it, and have the fight
## end inside the settle: the caption must say the ground under the player, not
## the landscape they were in when the machine came.
func test_a_caption_that_waited_is_dropped_when_the_ground_changed_under_it() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	for i in 3:
		await tree.process_frame
	var watch: UiPlaceWatch = ui.get("_places")
	var home_land := watch.announced
	check(home_land != &"", "where the player woke was said")
	var other := Country.SNOWFIELD if home_land != &"snowfield" else Country.MOSS
	var other_name := BiomeRegistry.get_def(StringName(Country.NAMES[other])).display_name
	var home_pos := g.player.pos
	var was := g.hud.place
	# Over the border, with a machine on them: the name waits for a quiet glass.
	_stand(g, _patch(g, other, home_pos + Vector2(5, 0)))
	ui.call("_watch_place", 0.2, true)
	ui.call("_watch_place", UiPlaceWatch.SETTLE, true)
	eq(StringName(ui.get("_pending_place")), StringName(Country.NAMES[other]), "the name waits")
	eq(g.hud.place, was, "and nothing is pinged where nobody can read it")
	# Pushed back over the border, and the fight ends there.
	_stand(g, home_pos)
	ui.call("_watch_place", 0.2, true)
	ui.call("_watch_place", 0.2, false)
	check(g.hud.place != other_name, "the caption never says the land they were pushed out of")
	ui.call("_watch_place", 0.2, false)
	eq(watch.announced, home_land, "the watcher reads the ground under the player again")
	eq(g.hud.place, BiomeRegistry.get_def(home_land).display_name, "and the caption says that")
	g.free()


## Move the player as a walk does: the fight body owns where they are (CLAUDE.md).
func _stand(g: Game, at: Vector2) -> void:
	g.player.pos = at
	if g.player.sim != null:
		g.player.sim.hero.pos = at


## The first hour's guide speaks through the slate as well as the message line:
## what to want stands on the HUD, and the key it is teaching sits on the hint row.
func test_the_goal_and_the_key_the_guide_teaches_reach_the_hud() -> void:
	var g := _make()
	var ui := _ui(g)
	_calm(g)
	for i in 3:
		await tree.process_frame
	ui.call("_feed_hud")
	eq(g.hud.goal, Guide.goal(g), "the goal stands on the glass")
	check(g.hud.goal != "", "and there is always something to want")
	var teach: Dictionary = ui.call("_guide_hint")
	check(not teach.is_empty() and String(teach.get("key", "")) != "", "the guide has a key to teach: %s" % str(teach))
	if UiLink.use_hint(g) == "" and UiLink.stations_here(g).is_empty():
		eq(g.hud.hint, String(teach.line), "and the row teaches it where there is nothing else to do")
		eq(g.hud.hint_key, String(teach.key), "with the key it is about")
	g.free()


## The drop verb is reachable the way a player reaches it: open carrying, choose
## a row, press X.
func test_x_on_the_carrying_page_puts_a_thing_down() -> void:
	var g := _make(["--give=driftwood:3"])
	var ui := _ui(g)
	_calm(g)
	_listen_screens()
	for i in 3:
		await tree.process_frame
	check(await _tap_until(&"inventory", _opened(&"inventory")), "carrying opens")
	var s := ui.call("top") as UiInventoryScreen
	s.select(&"driftwood")
	eq(s.menu.selected().get("id"), &"driftwood", "the driftwood is chosen")
	var before := g.inventory.count(&"driftwood")
	gt(float(before), 0.0, "something to put down")
	check(await _tap_until(&"drop", func() -> bool: return g.inventory.count(&"driftwood") < before), "x puts it down: %s" % s.note)
	check(Survival.heap_near(g) != null, "onto a heap in the world")
	_drop_screens()
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
