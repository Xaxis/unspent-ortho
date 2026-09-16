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
	for app: StringName in [&"loadout", &"reads", &"saves"]:
		s.select(app)
		s.handle(&"confirm")
	eq(opened, [&"loadout", &"reads", &"saves"] as Array[StringName], "gear, reads and saves open from home")
	check(s.is_open, "and home stays under them")
	s.select(&"controls")
	s.handle(&"confirm")
	eq(s.page, "keys")
	s.handle(&"back")
	eq(s.page, "list", "esc leaves the keys first")
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
	s.handle(&"confirm")
	eq(s.page, "keys")
	s.handle(&"back")
	eq(s.page, "list")
	check(s.is_open, "esc never closes the title")
	s.free()


func test_a_key_held_as_the_title_opens_is_not_a_press_on_it() -> void:
	var s := UiTitleMenu.new()
	tree.root.add_child(s)
	s.open()
	s.select(&"controls")
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
	eq(s.menu.selected().id, &"controls")
	s._read_keys()
	eq(s.page, "list", "the E that left the game does not choose on the title")
	Input.action_release(&"use")
	s._read_keys()
	Input.action_press(&"use")
	s._read_keys()
	Input.action_release(&"use")
	eq(s.page, "keys", "a fresh press does")
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
func test_gear_reads_and_saves_open_navigate_and_close() -> void:
	_listen()
	SlateFeeds.clear()
	for s: UiScreen in [UiLoadoutScreen.new(), UiReadsScreen.new(), UiSavesScreen.new()]:
		tree.root.add_child(s)
		s.open()
		check(s.is_open, "%s opens" % s.screen_name)
		var first := s.menu.index
		s.handle(&"down")
		if s.menu.rows.size() > 1:
			check(s.menu.index != first, "%s moves down" % s.screen_name)
		_sounds.clear()
		s.handle(&"confirm")
		if s.screen_name != &"reads":
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


func test_machine_reads_read_the_ground_when_nothing_living_does() -> void:
	SlateFeeds.clear()
	var g := Fx.flat()
	var s := UiReadsScreen.new()
	s.game = g
	tree.root.add_child(s)
	s.open()
	s.settle()
	s.refresh()
	check(s.menu.rows.is_empty(), "no machine in reach")
	var bare := await _said(s)
	check(_has_word(bare, "unworked ground"), "unworked land says so: %s" % str(bare))
	check(_has_word(bare, "survey"), "and the survey bearing still reads back")
	g.world.landmarks.append({"kind": &"quarry", "pos": g.player.pos + Vector2(20, 0), "dir": Vector2.RIGHT, "half": Vector2(4, 4), "mark": &"quarry"})
	g.world.landmarks.append({"kind": &"burn", "pos": g.player.pos + Vector2(0, -60), "dir": Vector2.RIGHT, "half": Vector2(4, 4), "mark": &"scorch"})
	# The page re-reads the ground twice a second, not per frame: it is the whole
	# landmark list, sorted (see UiReadsScreen.soil).
	s.refresh()
	var soil := s.ground()
	eq(s.soil(), soil, "the read the page draws is the read it last took")
	eq((soil.works as Array).size(), 2, "both works read")
	eq(StringName((soil.works as Array)[0].mark), &"quarry", "the nearest first")
	gt(float(soil.bearing), 0.0, "the machines surveyed this land along one bearing")
	var said := await _said(s)
	check(_has_word(said, UiReadsScreen.mark_words(&"quarry")), "what they did here, in words: %s" % str(said))
	check(_has_word(said, "20"), "and how far")
	# The sweep reaches READ_RADIUS; the works are further off than that. The
	# instrument says which way they lie rather than plotting nothing at all.
	check(_has_word(said, "1 work beyond reach"), "the radar owns the one it cannot plot: %s" % str(said))
	g.world.landmarks.append({"kind": &"cut", "pos": g.player.pos + Vector2(0, 80), "dir": Vector2.RIGHT, "half": Vector2(4, 4), "mark": &"cut"})
	s.refresh()
	check(_has_word(await _said(s), "2 works beyond reach"), "and counts them as they come")
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


func test_the_controls_page_names_the_key_that_puts_things_down() -> void:
	var keys := {}
	for pair: Array in UiPauseScreen.KEYS:
		keys[String(pair[0])] = String(pair[1])
	check(keys.has("x"), "X is on the controls page: %s" % str(keys.keys()))
	check(String(keys.get("x", "")).contains("hold") and String(keys.get("x", "")).contains("put down"), "and it says it is a hold: %s" % keys.get("x", ""))
	check(InputMap.has_action(&"drop"), "and the game answers that key")


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
