extends TestCase
## Screens open and close through Events.screen_changed, obey the menu
## standard, and do what their rows say, all without a world or a window.

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
	check(_sounds.has(&"open_book") and _sounds.has(&"close_book"), "book sounds: %s" % str(_sounds))
	s.open()
	s.handle(&"inventory")
	check(not s.is_open, "its own key closes it")
	s.open()
	s.handle(&"map")
	check(s.is_open, "another screen's key does not")
	s.free()
	_unlisten()


func test_inventory_holds_tools_and_eats_food() -> void:
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
	var before := s.body.fed_until
	s.handle(&"confirm")
	eq(inv.count(&"mussels"), 1, "ate one")
	gt(s.body.fed_until, before + 60.0, "fed for hours")
	s.handle(&"down")
	eq(s.menu.selected().id, &"stone")
	check(not UiMenu.enabled(s.menu.selected()), "stone is faded")
	_sounds.clear()
	s.handle(&"confirm")
	check(_sounds.has(&"refused"), "a faded row is refused")
	check(s.note != "", "and says why")
	eq(inv.count(&"stone"), 1, "nothing happened to it")
	s.free()
	_unlisten()


func test_eating_the_last_one_keeps_the_cursor_nearby() -> void:
	var s := _inventory_screen()
	s.inventory.add(&"knife")
	s.inventory.add(&"mussels", 1)
	s.open()
	s.handle(&"down")
	s.handle(&"confirm")
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
	check(not s.is_open, "C closes the making page")
	s.free()
	_unlisten()


func test_pause_keys_page_backs_out_one_level() -> void:
	_listen()
	var s := UiPauseScreen.new()
	tree.root.add_child(s)
	s.open()
	eq(s.menu.selected().id, &"resume")
	s.handle(&"down")
	s.handle(&"confirm")
	eq(s.page, "keys")
	s.handle(&"back")
	eq(s.page, "list", "esc leaves the keys page first")
	check(s.is_open, "and the pause page stays")
	s.handle(&"up")
	s.handle(&"confirm")
	check(not s.is_open, "resume closes")
	eq(_changes, [[&"pause", true], [&"pause", false]])
	var went := [false]
	s.to_title = func() -> void: went[0] = true
	s.open()
	s.handle(&"down")
	s.handle(&"down")
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
