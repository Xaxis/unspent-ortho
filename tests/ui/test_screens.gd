extends TestCase
## Apps open and close through Events.screen_changed, obey the menu standard,
## and do what their rows say, all without a world or a window. Every app is
## the same slate: it wakes when it opens, and its sounds are the slate's.

var _changes: Array = []
var _sounds: Array = []


func _listen() -> void:
	_changes.clear()
	_sounds.clear()
	Events.screen_changed.connect(_on_screen)
	Events.sfx.connect(_on_sfx)


func _unlisten() -> void:
	Events.screen_changed.disconnect(_on_screen)
	Events.sfx.disconnect(_on_sfx)


func _on_screen(n: StringName, open: bool) -> void:
	_changes.append([n, open])


func _on_sfx(n: StringName, _at: Vector3) -> void:
	_sounds.append(n)


func _inventory_screen() -> UiInventoryScreen:
	var s := UiInventoryScreen.new()
	s.inventory = Inventory.new()
	s.body = Body.new()
	tree.root.add_child(s)
	return s


func test_open_and_close_emit_screen_changed() -> void:
	_listen()
	var s := _inventory_screen()
	s.open()
	check(s.visible and s.is_open, "open shows")
	s.open()
	eq(_changes, [[&"inventory", true]], "opening twice emits once")
	check(s.handle(&"back"))
	check(not s.visible, "esc closes")
	eq(_changes, [[&"inventory", true], [&"inventory", false]])
	check(_sounds.has(&"ui_slate_wake") and _sounds.has(&"ui_slate_sleep"), "the slate's sounds: %s" % str(_sounds))
	s.open()
	s.handle(&"inventory")
	check(not s.is_open, "its own key closes it")
	s.open()
	s.handle(&"map")
	check(s.is_open, "another app's key does not")
	_sounds.clear()
	s.close(true)
	check(not _sounds.has(&"ui_slate_sleep"), "switching away does not put the slate to sleep")
	s.free()
	_unlisten()


func test_inventory_holds_tools_and_never_feeds_the_body_itself() -> void:
	_listen()
	var s := _inventory_screen()
	var inv := s.inventory
	inv.add(&"knife")
	inv.add(&"mussels", 2)
	inv.add(&"stone", 1)
	s.open()
	eq(s.menu.selected().id, &"knife", "tools come first")
	s.handle(&"confirm")
	eq(inv.held, &"knife", "confirm holds the tool")
	s.handle(&"confirm")
	eq(inv.held, &"", "confirm again puts it away")
	s.handle(&"down")
	eq(s.menu.selected().id, &"mussels")
	# Survival owns hunger: with no game to eat through, the row is refused with a reason.
	var before := s.body.fed_until
	check(not UiMenu.enabled(s.menu.selected()), "food with no one to eat it through is dim")
	_sounds.clear()
	s.handle(&"confirm")
	eq(inv.count(&"mussels"), 2, "nothing eaten")
	eq(s.body.fed_until, before, "the slate never writes the body")
	check(_sounds.has(&"ui_slate_deny") and s.note != "", "refused, saying why: %s" % s.note)
	check(s.note_warn, "a refusal is said in the warning")
	s.handle(&"down")
	eq(s.menu.selected().id, &"stone")
	check(not UiMenu.enabled(s.menu.selected()), "stone is dim")
	_sounds.clear()
	s.handle(&"confirm")
	check(_sounds.has(&"ui_slate_deny"), "a dim row is refused")
	check(s.note != "", "and says why")
	eq(inv.count(&"stone"), 1, "nothing happened to it")
	s.free()
	_unlisten()


func test_only_found_tools_are_held() -> void:
	var s := _inventory_screen()
	eq(s.verb_for(&"knife"), &"hold")
	eq(UiRules.item_group(&"wick"), &"found", "a charge is listed with found things")
	eq(s.verb_for(&"wick"), &"", "but a charge is not held")
	check(UiInventoryScreen.why_refused(&"wick").ends_with("."), "one plain sentence: %s" % UiInventoryScreen.why_refused(&"wick"))
	s.free()


func test_a_thing_leaving_keeps_the_cursor_nearby() -> void:
	var s := _inventory_screen()
	s.inventory.add(&"knife")
	s.inventory.add(&"mussels", 1)
	s.open()
	s.handle(&"down")
	s.inventory.remove(&"mussels")
	eq(s.inventory.count(&"mussels"), 0)
	check(not s.menu.selected().is_empty(), "cursor still on a row")
	s.free()


func test_crafting_makes_when_it_can_and_says_what_is_short() -> void:
	_listen()
	var s := UiCraftingScreen.new()
	s.inventory = Inventory.new()
	var pick := {"id": &"pick_made", "at": &"fire", "minutes": 240.0, "needs": {&"scrap": 1, &"timber": 1}, "makes": {&"pick": 1}}
	var stew := {"id": &"stew", "at": &"fire", "minutes": 60.0, "needs": {&"mussels": 4}, "makes": {&"stew": 2}}
	s.recipes_override = [pick, stew]
	tree.root.add_child(s)
	s.inventory.add(&"scrap", 1)
	s.inventory.add(&"timber", 1)
	s.inventory.add(&"mussels", 1)
	s.open()
	eq(_changes, [[&"crafting", true]])
	check(UiMenu.enabled(s.menu.rows[0]), "pick can be made")
	check(not UiMenu.enabled(s.menu.rows[1]), "stew is short")
	s.handle(&"down")
	s.handle(&"confirm")
	check(s.note.contains("three") and s.note.contains("mussels"), "says what is short: %s" % s.note)
	s.handle(&"up")
	s.handle(&"confirm")
	eq(s.inventory.count(&"pick"), 1, "made a pick")
	eq(s.inventory.count(&"scrap"), 0, "used the plate")
	check(not UiMenu.enabled(s.menu.rows[0]), "cannot make another")
	s.handle(&"craft")
	check(not s.is_open, "C closes the making app")
	s.free()
	_unlisten()


func test_home_opens_its_apps_and_its_keys_back_out_one_level() -> void:
	_listen()
	var s := UiPauseScreen.new()
	tree.root.add_child(s)
	s.open()
	eq(s.menu.selected().id, &"resume")
	var opened: Array[StringName] = []
	s.open_app = func(n: StringName) -> void: opened.append(n)
	for app: StringName in [&"loadout", &"saves"]:
		s.select(app)
		s.handle(&"confirm")
	eq(opened, [&"loadout", &"saves"] as Array[StringName], "gear and saves open from home")
	check(s.is_open, "and home stays under them")
	# Settings is an app like the others now, not a page of letters home turns into.
	s.select(&"settings")
	s.handle(&"confirm")
	eq(opened.back(), &"settings", "settings opens from home too")
	eq(s.page, "list", "and home is still home under it")
	check(s.is_open, "and home stays")
	s.select(&"resume")
	s.handle(&"confirm")
	check(not s.is_open, "resume closes")
	var went := [false]
	s.to_title = func() -> void: went[0] = true
	s.open()
	s.select(&"title")
	s.handle(&"confirm")
	check(went[0], "to the title calls through")
	s.free()
	_unlisten()


func test_title_menu_navigates_without_a_world() -> void:
	var s := UiTitleMenu.new()
	tree.root.add_child(s)
	s.open()
	eq(s.menu.selected().id, &"new")
	s.handle(&"up")
	eq(s.menu.selected().id, &"quit", "wraps")
	s.handle(&"up")
	# The row that was a list of letters is the settings app now: it opens over the
	# title rather than turning the title into a page of its own.
	eq(s.menu.selected().id, &"settings")
	s.handle(&"confirm")
	eq(s.page, "list", "the title stays the title")
	check(s.is_open, "esc never closes the title")
	s.free()


func test_a_key_held_as_the_title_opens_is_not_a_press_on_it() -> void:
	var s := UiTitleMenu.new()
	tree.root.add_child(s)
	s.open()
	s.select(&"settings")
	s.close()
	Input.action_press(&"use")
	# A press counts as "just pressed" until the frame it was made in is behind
	# Input's own reckoning. Let two frames pass, so what the title opens onto is
	# a key HELD from before it — which is what this is about — and not a press
	# made this instant. One frame is not enough: whether it is depends on where
	# in the frame the test itself is running, which is how this test came to
	# pass alone and fail in a full run.
	for i in 2:
		await tree.process_frame
	s.open()
	eq(s.menu.selected().id, &"settings")
	# What says the press was taken is the slate answering it: the row it is on
	# opens an app over the title, and this menu has no title scene behind it.
	_listen()
	s._read_keys()
	check(not _sounds.has(&"ui_slate_confirm"), "the E that left the game does not choose on the title")
	Input.action_release(&"use")
	s._read_keys()
	Input.action_press(&"use")
	s._read_keys()
	Input.action_release(&"use")
	check(_sounds.has(&"ui_slate_confirm"), "a fresh press does")
	_unlisten()
	s.free()
	# Input keeps a press "just pressed" for the rest of its frame: let it pass
	# before the next test's title reads the keys.
	for i in 2:
		await tree.process_frame


func test_the_title_slate_wakes_in_order() -> void:
	_listen()
	var s := UiTitleMenu.new()
	tree.root.add_child(s)
	s.open()
	check(not s.is_lit(), "it starts dark")
	eq(s.wake_stage(), [0.0, 0.0] as Array[float])
	s._process(UiTitleMenu.WAKE_AT[0] + 0.05)
	check(_sounds.has(&"ui_slate_wake"), "it chirps as the light comes")
	check(s.wake_stage()[0] > 0.0 and s.wake_stage()[1] == 0.0, "a line first: %s" % str(s.wake_stage()))
	s._process(UiTitleMenu.WAKE_AT[2])
	check(s.is_lit(), "then lit")
	s.sleep()
	check(not s.is_lit(), "and dark again as a game starts")
	s.free()
	_unlisten()


func test_map_pans_by_steps_and_changes_scale() -> void:
	var s := UiMapScreen.new()
	tree.root.add_child(s)
	s.open()
	var o := s.origin_px
	s.handle(&"right")
	s.handle(&"down")
	eq(s.origin_px - o, Vector2i(UiMapScreen.PAN_STEP, UiMapScreen.PAN_STEP), "a step each")
	var scale := s.map_scale
	s.handle(&"confirm")
	check(s.map_scale != scale, "e changes the scale")
	s.handle(&"map")
	check(not s.is_open, "M closes the map")
	s.free()


func test_making_lists_what_can_be_made_first_under_its_station() -> void:
	var s := UiCraftingScreen.new()
	s.inventory = Inventory.new()
	s.inventory.add(&"driftwood", 4)
	tree.root.add_child(s)
	var a := {"id": &"a", "at": &"fire", "minutes": 60.0, "needs": {&"scrap": 9}, "makes": {&"iron": 1}}
	var b := {"id": &"b", "at": &"fire", "minutes": 60.0, "needs": {&"driftwood": 4}, "makes": {&"charcoal": 2}}
	var c := {"id": &"c", "at": &"hand", "minutes": 20.0, "needs": {&"driftwood": 2}, "makes": {&"haft": 1}}
	s.recipes_override = [a, b, c]
	s.open()
	var order: Array = s.menu.rows.map(func(r: Dictionary) -> StringName: return r.id)
	eq(order, [&"b", &"a", &"c"], "within the fire, the makeable first")
	s.free()


func test_the_making_page_lists_only_what_has_been_in_the_pack() -> void:
	var s := UiCraftingScreen.new()
	s.inventory = Inventory.new()
	s.inventory.add(&"knife")
	s.inventory.add(&"driftwood", 3)
	s.inventory.add(&"stone", 2)
	s.stations = [&"fire", &"hand"]
	tree.root.add_child(s)
	s.open()
	var listed := func() -> Array:
		return s.menu.rows.filter(func(r: Dictionary) -> bool: return r.has("id")).map(func(r: Dictionary) -> StringName: return r.id)
	var first: Array = listed.call()
	for id: StringName in [&"campfire", &"charcoal", &"haft", &"hone"]:
		check(first.has(id), "%s is listed at the first fire: %s" % [id, first])
	for id: StringName in [&"tower_cable", &"raft", &"oil", &"stew", &"bench", &"scarf_mask"]:
		check(not first.has(id), "%s wants what has never been in the pack: %s" % [id, first])
	lt(float(first.size()), 12.0, "a first fire's page fits on one screen: %s" % first)
	for id: StringName in first:
		check(Crafting.known(s.inventory, Crafting.recipe(id)), "%s is known" % id)
	# Resin carried once: what it makes is on the page, and stays when the resin is gone.
	s.inventory.add(&"resin")
	s.refresh()
	check((listed.call() as Array).has(&"oil"), "resin found: oil is listed")
	s.inventory.remove(&"resin")
	s.refresh()
	check((listed.call() as Array).has(&"oil"), "and stays listed after the resin is used")
	s.free()


func test_an_app_wakes_with_a_scan_at_whole_pixels() -> void:
	var s := UiPauseScreen.new()
	tree.root.add_child(s)
	s.open()
	eq(s.wake, 0.0, "the glass starts dark")
	eq(s.position.y, 0.0, "the slate itself does not move")
	s._process(UiSlate.WAKE_SECONDS * 0.4)
	check(s.wake > 0.0 and s.wake < 1.0, "on its way: %s" % s.wake)
	s._process(UiSlate.WAKE_SECONDS)
	eq(s.wake, 1.0, "awake")
	s.close()
	s.open(true)
	eq(s.wake_seconds, UiSlate.SWITCH_SECONDS, "switching apps wakes it faster")
	var title := UiTitleMenu.new()
	tree.root.add_child(title)
	title.open()
	eq(title.wake, 1.0, "the title wakes its own way")
	s.free()
	title.free()


## The apps the wave's other packages fill: each opens, navigates, refuses with
## a reason until its package wires in, and closes.
func test_gear_and_saves_open_navigate_and_close() -> void:
	_listen()
	SlateFeeds.clear()
	for s: UiScreen in [UiLoadoutScreen.new(), UiSavesScreen.new()]:
		tree.root.add_child(s)
		s.open()
		check(s.is_open, "%s opens" % s.screen_name)
		var first := s.menu.index
		s.handle(&"down")
		if s.menu.rows.size() > 1:
			check(s.menu.index != first, "%s moves down" % s.screen_name)
		_sounds.clear()
		s.handle(&"confirm")
		check(_sounds.has(&"ui_slate_deny") and s.note != "", "%s says why it cannot yet: %s" % [s.screen_name, s.note])
		s.handle(&"back")
		check(not s.is_open, "%s closes" % s.screen_name)
		s.free()
	_unlisten()


func test_a_package_fills_an_app_through_its_feed() -> void:
	SlateFeeds.clear()
	var acted: Array[StringName] = []
	SlateFeeds.on_act(&"loadout", func(_g: Game, id: StringName) -> String:
		acted.append(id)
		return "Fitted.")
	SlateFeeds.provide(&"loadout", func(_g: Game) -> Dictionary:
		return {"slots": [{"id": &"head", "label": "head", "item": &"kit_lens", "modules": [{"id": &"m", "name": "seal", "grants": "cold"}]}], "resist": {&"cold": 0.5}, "abilities": [{"id": &"dash", "name": "dash", "ready": true, "note": ""}]})
	var g := UiLoadoutScreen.new()
	tree.root.add_child(g)
	g.open()
	eq(g.menu.selected().id, &"head")
	check(g.hazards().has(&"cold"), "resistances list every hazard")
	g.handle(&"confirm")
	eq(acted, [&"head"] as Array[StringName], "confirming calls the package's act")
	eq(g.note, "Fitted.")
	g.free()
	SlateFeeds.clear()


func test_gear_shows_every_resistance_however_many_the_land_names() -> void:
	SlateFeeds.clear()
	var names: Array[StringName] = [&"cold", &"heat", &"fumes", &"toxins", &"radiation", &"wet", &"dark", &"vacuum", &"pressure", &"em", &"resonance", &"time_shear", &"spores", &"glare"]
	var resist := {}
	for i in names.size():
		resist[names[i]] = 0.1 * (i % 4)
	var slots: Array = []
	for id: StringName in SlateFeeds.SLOTS:
		slots.append({"id": id, "label": String(id), "item": &"", "modules": []})
	SlateFeeds.provide(&"loadout", func(_g: Game) -> Dictionary: return {"slots": slots, "resist": resist, "abilities": [{"id": &"a", "name": "dash", "ready": true, "note": ""}]})
	var g := UiLoadoutScreen.new()
	tree.root.add_child(g)
	g.open()
	g.settle()
	var hz := g.hazards()
	gt(hz.size(), 13, "the feed's fourteen and the land's own")
	UiDraw.tape.clear()
	UiDraw.taping = true
	g.queue_redraw()
	await tree.process_frame
	UiDraw.taping = false
	var said: Array[String] = []
	for d: Dictionary in UiDraw.tape:
		if d.kind == &"text" and d.ci == g:
			said.append(String(d.text))
			check(UiSlate.GLASS_RECT.encloses(Rect2i(d.rect)), "'%s' is on the glass" % d.text)
	UiDraw.tape.clear()
	for h: StringName in hz:
		check(said.has(String(h).replace("_", " ")), "%s is drawn" % h)
	check(said.has("dash"), "the abilities are still listed")
	# However many: every one gets a cell on the panel, and none overlap.
	for n: int in [hz.size(), 30, 42]:
		var cells := UiLoadoutScreen.resist_cells(n)
		eq(cells.size(), n, "%d resistances, %d cells" % [n, n])
		for i in cells.size():
			check(UiSlate.SPARE.encloses(cells[i]), "cell %d of %d is on the panel" % [i, n])
			for j in range(i + 1, cells.size()):
				check(not cells[i].intersects(cells[j]), "cells %d and %d of %d apart" % [i, j, n])
	g.free()
	SlateFeeds.clear()


func test_every_app_is_drawn_on_the_one_slate() -> void:
	# The layouts every app shares keep clear of the glass's flaws.
	var crack := UiSlate.crack_zone(UiSlate.DEVICE)
	for r: Rect2i in [UiSlate.LIST, UiSlate.SPARE, UiSlate.BODY]:
		var content := r.grow_individual(-UiSlate.MARGIN_L + 2, 0, -UiSlate.MARGIN_R + 2, 0)
		check(content.position.x > UiSlate.dead_column_x(UiSlate.DEVICE), "content right of the dead column: %s" % r)
		check(not content.intersects(crack) or content.end.x <= crack.position.x, "content clear of the crack: %s" % r)
	check(UiSlate.GLASS_RECT.encloses(UiSlate.BODY), "the body is on the glass")
	eq(UiSlate.glass_of(UiSlate.DEVICE), UiSlate.GLASS_RECT, "the glass is where the bezel leaves it")


func test_two_keys_in_one_frame_both_reach_the_title() -> void:
	var s := UiTitleMenu.new()
	tree.root.add_child(s)
	s.open()
	eq(s.menu.selected().id, &"new")
	# A down and an up inside one frame (a slow frame while the coast streams in):
	# answering only the first would leave the choice a row away from where it began.
	Input.action_press(&"move_down")
	Input.action_press(&"move_up")
	s._read_keys()
	Input.action_release(&"move_down")
	Input.action_release(&"move_up")
	eq(s.menu.selected().id, &"new", "the choice comes back to where it was")
	s.free()
	for i in 2:
		await tree.process_frame


## The apps other packages will fill must still be worth opening on day one,
## and the making page must say when long work comes off the fire.
const Fx := preload("res://tests/survival/fixture.gd")


## Every word `s` draws on its next frame.
func _said(s: UiScreen) -> Array[String]:
	UiDraw.tape.clear()
	UiDraw.taping = true
	s.queue_redraw()
	await tree.process_frame
	UiDraw.taping = false
	var out: Array[String] = []
	for d: Dictionary in UiDraw.tape:
		if d.kind == &"text" and d.ci == s:
			out.append(String(d.text))
	UiDraw.tape.clear()
	return out


## A word drawn somewhere on the page (headings are set in capitals).
static func _has_word(said: Array[String], part: String) -> bool:
	for w in said:
		if w.to_lower().contains(part.to_lower()):
			return true
	return false


func test_an_empty_gear_slot_says_what_can_go_in_it() -> void:
	SlateFeeds.clear()
	for slot: StringName in SlateFeeds.SLOTS:
		check(SlateFeeds.fits(slot) != "", "%s says what it takes" % slot)
	check(SlateFeeds.fits(&"head").contains("lens"), "the head takes a lens: %s" % SlateFeeds.fits(&"head"))
	var g := Fx.flat()
	var s := UiLoadoutScreen.new()
	s.game = g
	tree.root.add_child(s)
	s.open()
	s.settle()
	var said := await _said(s)
	check(_has_word(said, "empty"), "a slot with nothing in it says so")
	check(_has_word(said, "takes"), "and what would fit: %s" % str(said))
	s.free()
	Fx.done(g)


func test_gear_says_what_this_land_presses_with() -> void:
	SlateFeeds.clear()
	var g := Fx.flat()
	g.body.pressure = {&"cold": 0.8}
	var s := UiLoadoutScreen.new()
	s.game = g
	tree.root.add_child(s)
	s.open()
	s.settle()
	check(s.here().has(&"cold"), "what is felt now is what this land presses with")
	eq(s.hazards()[0], &"cold", "and it is the first resistance listed, however many there are")
	var said := await _said(s)
	check(_has_word(said, BiomeRegistry.at(g.world, g.player.pos).display_name), "the land is named: %s" % str(said))
	check(_has_word(said, "presses"), "and what it does to you: %s" % str(said))
	s.free()
	Fx.done(g)


func test_the_making_page_says_when_long_work_comes_off_the_fire() -> void:
	var g := Fx.flat(40, 9.0)
	var quick := {"id": &"q", "at": &"hand", "minutes": 10.0, "needs": {}, "makes": {&"haft": 1}}
	var slow := {"id": &"s", "at": &"fire", "minutes": 180.0, "needs": {&"driftwood": 4}, "makes": {&"charcoal": 2}}
	check(not Crafting.sets_going(quick))
	check(Crafting.sets_going(slow), "long work at a station is set going")
	check(UiCraftingScreen.ready_line(g, quick).begins_with("done "), "work done on the spot: %s" % UiCraftingScreen.ready_line(g, quick))
	var line := UiCraftingScreen.ready_line(g, slow)
	check(line.begins_with("on the fire, ready at "), "long work is left on the fire: %s" % line)
	var want := UiRules.clock_at(g.clock.minutes + Survival.SET_GOING_MINUTES + 180.0, g.clock.minutes)
	check(line.ends_with(want), "at the hour survival will hand it back: %s" % line)
	# And what is already going is listed under the recipes.
	var fire := Fx.put(g, PropKind.FIRE, Vector2(1.0, 0))
	SurvivalState.of(g).cooking[fire.id] = {"prop": fire, "station": &"fire", "recipe": &"s",
		"makes": {&"charcoal": 2}, "done": g.clock.minutes + 120.0, "pos": fire.pos}
	var s := UiCraftingScreen.new()
	s.game = g
	s.inventory = g.inventory
	s.recipes_override = [slow]
	tree.root.add_child(s)
	s.open()
	s.settle()
	eq(s.jobs().size(), 1, "the fire is working")
	gt(float(UiCraftingScreen.cook_height(1)), 0.0, "and the list makes room for it")
	eq(UiCraftingScreen.cook_height(0), 0, "with nothing on, it takes no room")
	var said := await _said(s)
	check(_has_word(said, "on now"), "what is on the fire is listed: %s" % str(said))
	check(_has_word(said, "charcoal"), "by what it makes")
	check(_has_word(said, UiRules.clock_at(g.clock.minutes + 120.0, g.clock.minutes)), "and when to come back")
	# More jobs than rows: the row that counts the rest takes one of the rows, so
	# it counts the job it displaced in with them.
	eq(UiCraftingScreen.cooking_over(UiCraftingScreen.COOK_ROWS), 0, "every job that fits gets its own row")
	eq(UiCraftingScreen.cooking_over(UiCraftingScreen.COOK_ROWS + 1), 2, "one over: the last row stands for two")
	for k in 3:
		var more := Fx.put(g, PropKind.FIRE, Vector2(3.0 + k, 0))
		SurvivalState.of(g).cooking[more.id] = {"prop": more, "station": &"fire", "recipe": &"s",
			"makes": {&"charcoal": 2}, "done": g.clock.minutes + 130.0 + k * 10.0, "pos": more.pos}
	eq(s.jobs().size(), 4, "four fires going, three rows for them")
	var many := await _said(s)
	check(_has_word(many, "and 2 more on the go"), "and the count owns up to the one it displaced: %s" % str(many))
	s.free()
	Fx.done(g)


## The holding lists the pieces whose makings the player has carried, and the
## piece the goal asks for: all twenty-one on the first day, most wanting things
## from lands not yet walked, read as a wall of refusals.
func test_the_holding_lists_what_the_player_has_carried_the_makings_of() -> void:
	var g := Fx.flat()
	var was := Guide.last_goal_key
	Guide.last_goal_key = &""
	var s := UiSettlementScreen.new()
	s.game = g
	tree.root.add_child(s)
	s.open()
	var listed := func() -> Array:
		var out := []
		for r: Dictionary in s.menu.rows:
			if r.get("build", false):
				out.append(int(r.kind))
		return out
	check(not (listed.call() as Array).has(StructureKind.TURRET), "no turret before its makings were ever carried: %s" % str(listed.call()))
	check(not g.inventory.has_handled(&"rag"), "a rag has never been carried")
	check(not (listed.call() as Array).has(StructureKind.LEAN_TO), "so no lean-to")
	g.inventory.add(&"stone", 3)
	g.inventory.add(&"deadwood", 2)
	s.refresh()
	check((listed.call() as Array).has(StructureKind.HEARTH), "stone and deadwood carried: a hearth")
	Guide.last_goal_key = &"holding"
	s.refresh()
	check((listed.call() as Array).has(StructureKind.LEAN_TO), "the goal's lean-to is listed before its rag was found")
	Guide.last_goal_key = was
	s.free()
	Fx.done(g)


func test_the_controls_page_names_the_key_that_puts_things_down() -> void:
	var keys := {}
	for pair: Array in UiPauseScreen.KEYS:
		keys[UiPauseScreen.key_line(pair[0])] = String(pair[1])
	check(keys.has("x"), "X is on the controls page: %s" % str(keys.keys()))
	check(String(keys.get("x", "")).contains("hold") and String(keys.get("x", "")).contains("put down"), "and it says it is a hold: %s" % keys.get("x", ""))
	check(InputMap.has_action(&"drop"), "and the game answers that key")


## Every page of the slate with a key of its own is on the controls page: the
## journal and the holding answered keys the page never named.
func test_the_controls_page_names_every_page_key() -> void:
	var listed: Array[StringName] = []
	for pair: Array in UiPauseScreen.KEYS:
		listed.append_array(pair[0])
	for action: StringName in [&"inventory", &"craft", &"map", &"journal", &"holding"]:
		check(InputMap.has_action(action), "the game answers %s" % action)
		check(action in listed, "and the controls page names it: %s" % action)


func test_x_puts_a_row_down_and_asks_first_for_a_tool() -> void:
	var g := Fx.flat()
	g.inventory.add(&"driftwood", 3)
	var s := UiInventoryScreen.new()
	s.game = g
	s.inventory = g.inventory
	s.body = g.body
	tree.root.add_child(s)
	s.open()
	check(UiInventoryScreen.drop_asks(&"knife"), "a tool is asked about")
	check(not UiInventoryScreen.drop_asks(&"driftwood"), "a good is not")
	s.select(&"driftwood")
	check(s.handle(&"drop"), "x is the page's own key")
	eq(g.inventory.count(&"driftwood"), 0, "the whole heap of it goes down")
	check(Survival.heap_near(g) != null, "onto a heap the world keeps")
	s.select(&"knife")
	s.handle(&"drop")
	eq(g.inventory.count(&"knife"), 1, "a tool is not let go on one press")
	check(s.note.contains("knife") and s.note_warn, "it asks: %s" % s.note)
	check(s.asking(&"knife"), "and waits on the same row")
	# Every key label names the verb that key does: X still puts it down.
	var asked := await _said(s)
	check(_has_word(asked, "yes, put it down"), "the key says what X does, not what it does not: %s" % str(asked))
	s.handle(&"drop")
	eq(g.inventory.count(&"knife"), 0, "asked again, it goes down")
	check(not s.asking(&"knife"), "and the asking is over")
	s.free()
	Fx.done(g)


## A tool chosen in the pack is set against the one in hand on the hardness
## ladder, in words: what choosing it would change.
func test_the_pack_sets_a_tool_against_the_one_in_hand() -> void:
	var g := Fx.flat()
	g.inventory.add(&"knife")
	g.inventory.add(&"pick_steel")
	g.inventory.held = &"knife"
	var s := UiInventoryScreen.new()
	s.game = g
	s.inventory = g.inventory
	s.body = g.body
	tree.root.add_child(s)
	s.open()
	s.select(&"pick_steel")
	s.settle()
	var said := await _said(s)
	check(_has_word(said, "harder than your knife"), "a steel pick against the iron knife: %s" % str(said))
	s.select(&"knife")
	s.settle()
	said = await _said(s)
	check(not _has_word(said, "than your knife") and not _has_word(said, "as hard as"), "the knife is not set against itself: %s" % str(said))
	s.queue_free()
	Fx.done(g)


## A tool says its grade and what the grade buys. A rare tool read exactly like
## a common one, though the grade is the whole of what sets them apart.
func test_the_pack_says_a_tools_grade_and_its_modules() -> void:
	var g := Fx.flat()
	g.inventory.add(&"pick_steel")
	g.inventory.add(&"axe_works")
	var s := UiInventoryScreen.new()
	s.game = g
	s.inventory = g.inventory
	s.body = g.body
	tree.root.add_child(s)
	s.open()
	for id: StringName in [&"pick_steel", &"axe_works"]:
		s.select(id)
		s.settle()
		var said := await _said(s)
		var grade := String(GearTree.row(id).grade)
		var n := Gear.sockets(id)
		var want := grade if n <= 0 else "%s · takes %s" % [grade, "a module" if n == 1 else "%d modules" % n]
		check(_has_word(said, want), "%s says '%s': %s" % [id, want, str(said)])
	s.queue_free()
	Fx.done(g)


func test_the_pack_says_the_headlamp_is_worn_and_tells_twin_uses_apart() -> void:
	var g := Fx.flat()
	if not g.inventory.has(&"lamp"):
		g.inventory.add(&"lamp")
	var s := UiInventoryScreen.new()
	s.game = g
	s.inventory = g.inventory
	s.body = g.body
	tree.root.add_child(s)
	s.open()
	s.select(&"knife")
	s.settle()
	var said := await _said(s)
	var at := said.find("head")
	check(at >= 0 and at + 1 < said.size() and said[at + 1].contains("headlamp"), "the headlamp is worn on the head: %s" % str(said))
	# What it goes into is what he could make: nothing wanting things he has never
	# carried is named, only counted.
	check(not said.any(func(w: String) -> bool: return w.begins_with("steel knife")), "no steel knife before charcoal or an edge: %s" % str(said))
	check(_has_word(said, "not found yet"), "the rest are counted: %s" % str(said))
	g.inventory.add(&"charcoal")
	g.inventory.add(&"machine_edge")
	s.refresh()
	said = await _said(s)
	# Two recipes turn the knife into a steel knife: each line says which.
	var steel := said.filter(func(w: String) -> bool: return w.begins_with("steel knife"))
	gt(float(steel.size()), 1.0, "both ways to a steel knife are listed: %s" % str(said))
	for i in steel.size():
		eq(steel.find(steel[i]), i, "'%s' is said once" % steel[i])
	s.free()
	Fx.done(g)


## The long game's next want sits at the foot of the make page, but not while
## the first steps run: at a first fire it named a far land's material.
func test_the_make_page_keeps_the_long_want_until_the_first_steps_are_done() -> void:
	var Sx := preload("res://tests/save/save_fixture.gd")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--weather=clear:0"])
	await tree.process_frame
	var guide := g.get_node_or_null(^"58_guide")
	var want := Guide.within_reach(g)
	check(want != "", "the long game wants something here: %s" % want)
	var s := UiCraftingScreen.new()
	s.game = g
	s.inventory = g.inventory
	s.stations = [&"hand"]
	tree.root.add_child(s)
	guide.set("step_at", 0)
	s.open()
	check(not _has_word(await _said(s), "within reach"), "not while the first steps run")
	guide.set("step_at", -1)
	s.refresh()
	check(_has_word(await _said(s), "within reach"), "once they are done, it is there")
	s.free()
	Sx.end(g)


## E on a piece you wear puts it on, from the pack: an oilskin sat under TO WEAR
## with "e wear" on the key strip and the press did nothing at all.
func test_e_in_the_pack_puts_on_what_is_worn_and_lights_the_lamp() -> void:
	var Sx := preload("res://tests/save/save_fixture.gd")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--weather=clear:0"])
	await tree.process_frame
	g.inventory.add(&"oilskin")
	if not g.inventory.has(&"lamp"):
		g.inventory.add(&"lamp")
	var s := UiInventoryScreen.new()
	s.game = g
	s.inventory = g.inventory
	s.body = g.body
	tree.root.add_child(s)
	s.open()
	s.select(&"oilskin")
	eq(s.verb_for(&"oilskin"), &"wear", "an oilskin is worn")
	check(_has_word(await _said(s), "wear"), "and the key strip says so")
	s.handle(&"confirm")
	check(UiLink.fitted(g, &"oilskin"), "E puts it on: %s" % s.note)
	check(_has_word(await _said(s), "take off"), "then the key says what it does next")
	s.handle(&"confirm")
	check(not UiLink.fitted(g, &"oilskin"), "and E again takes it off: %s" % s.note)
	eq(s.verb_for(&"knife"), &"hold", "a tool is still held, not worn")
	s.select(&"lamp")
	var was := g.body.lamp_lit
	s.handle(&"confirm")
	check(g.body.lamp_lit != was, "E on the headlamp lights it or puts it out: %s" % s.note)
	s.free()
	Sx.end(g)


## Home says what earns the next bracket: they were only said once earned.
func test_home_says_what_earns_the_next_bracket() -> void:
	var Sx := preload("res://tests/save/save_fixture.gd")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--weather=clear:0"])
	await tree.process_frame
	var s := UiPauseScreen.new()
	s.game = g
	tree.root.add_child(s)
	s.open()
	s.settle()
	var said := await _said(s)
	check(_has_word(said, "+1: bring down 2 more machines"), "the first health bracket is two machines off: %s" % str(said))
	check(_has_word(said, "+1: run 250 more paces"), "and the first stamina bracket 250 paces: %s" % str(said))
	g.body.machines_down = 2
	g.body.run_tiles = 300.0
	said = await _said(s)
	var paces := "%d more paces" % ceili(Brackets.run_to_next(300.0))
	check(_has_word(said, "3 more machines") and _has_word(said, paces), "and they count down as he earns: %s" % str(said))
	s.free()
	Sx.end(g)


## Home says what the machines make of the player here: how far the network has
## noticed them, what a relic worn keeps telling it, and what the plan still
## holds this place for. These were on a page of their own few ever opened.
func test_home_says_what_the_machines_make_of_this_place() -> void:
	var Sx := preload("res://tests/save/save_fixture.gd")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--weather=clear:0", "--fit=glide_wing,mod_lock"])
	await tree.process_frame
	var s := UiPauseScreen.new()
	s.game = g
	tree.root.add_child(s)
	s.open()
	s.settle()
	var read := SlateFeeds.feed(&"reads", g)
	var said := await _said(s)
	check(_has_word(said, "the machines"), "home has the machines' read: %s" % str(said))
	check(_has_word(said, String(Interference.name_of(float(read.interference)))) and _has_word(said, String(read.network)),
		"how far the network has noticed them, and which: %s" % str(said))
	check(_has_word(said, String(StoryContent.READS_CAUSE[&"carried"])), "the relic worn is named as what feeds it: %s" % str(said))
	check(String(read.asking) != "" and _has_word(said, String(read.asking)), "and what the plan holds this place for: %s" % str(said))
	s.free()
	Sx.end(g)
