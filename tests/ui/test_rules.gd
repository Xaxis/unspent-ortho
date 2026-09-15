extends TestCase
## What the quiet layer shows and when.


class FakeMob:
	extends RefCounted
	var pos := Vector2.ZERO
	var alive := true
	var kind := &"runner"


func _mob(p: Vector2, alive: bool = true) -> FakeMob:
	var m := FakeMob.new()
	m.pos = p
	m.alive = alive
	return m


func test_health_is_cells_of_three() -> void:
	eq(UiRules.health_cells(12, 12), PackedInt32Array([3, 3, 3, 3]), "full")
	eq(UiRules.health_cells(8, 12), PackedInt32Array([3, 3, 2, 0]), "hurt")
	eq(UiRules.health_cells(0, 12), PackedInt32Array([0, 0, 0, 0]), "down")
	eq(UiRules.health_cells(15, 15).size(), 5, "plate adds a cell")
	eq(UiRules.health_cells(13, 13), PackedInt32Array([3, 3, 3, 3, 1]), "a part cell")


func test_wind_only_shows_when_spent() -> void:
	check(not UiRules.wind_shown(2400.0, 2400.0), "full wind hidden")
	check(UiRules.wind_shown(1700.0, 2400.0), "spent wind shown")


func test_needs_appear_only_when_they_matter() -> void:
	var b := Body.new()
	b.fed_until = 1000.0
	check(UiRules.needs(b, 900.0, 10.0).is_empty(), "fed, dry, light: nothing")
	# Survival owns where peckish and hungry begin; find them rather than assume.
	var t := 1000.0
	while b.hunger_level(t) < 1:
		t += 10.0
	var peckish := UiRules.needs(b, t, 10.0)
	eq(peckish.size(), 1)
	eq(peckish[0].need, &"hunger")
	eq(peckish[0].level, 1, "peckish is quiet")
	while b.hunger_level(t) < 2:
		t += 10.0
	eq(UiRules.needs(b, t, 10.0)[0].level, 2, "hungry is the accent")
	check(UiRules.needs(b, 900.0, 45.0, 60.0).is_empty(), "a bigger creel carries more before it tells")
	b.wet = 0.9
	var list := UiRules.needs(b, 900.0, UiRules.CREEL * 2.0)
	var names: Array = list.map(func(n: Dictionary) -> StringName: return n.need)
	check(names.has(&"wet") and names.has(&"load"), "wet and laden: %s" % str(names))
	for n in list:
		if n.need == &"load":
			eq(n.level, 2, "twice the creel is the accent")


func test_hostile_near_ignores_the_dead_and_the_far() -> void:
	var p := Vector2(50, 50)
	check(not UiRules.hostile_near([], p), "nobody")
	check(not UiRules.hostile_near([_mob(Vector2(59, 50))], p), "9 tiles is not near")
	check(UiRules.hostile_near([_mob(Vector2(56, 55))], p), "within 8")
	check(not UiRules.hostile_near([_mob(Vector2(51, 50), false)], p), "dead does not count")
	near(UiRules.nearest_hostile([_mob(Vector2(53, 54)), _mob(Vector2(60, 50))], p), 5.0, 1e-4)


func test_use_hint_hides_in_a_fight_busy_or_paged() -> void:
	var p := Vector2(10, 10)
	check(UiRules.hint_allowed(false, false, [], p), "calm")
	check(not UiRules.hint_allowed(false, false, [_mob(Vector2(14, 10))], p), "hostile near")
	check(UiRules.hint_allowed(false, false, [_mob(Vector2(30, 10))], p), "hostile far")
	check(not UiRules.hint_allowed(true, false, [], p), "busy")
	check(not UiRules.hint_allowed(false, true, [], p), "a page is open")


func test_prop_hints_name_the_verb() -> void:
	eq(UiRules.prop_hint(PropKind.PINE), "pine - fell")
	eq(UiRules.prop_hint(PropKind.BOULDER), "boulder - break")
	eq(UiRules.prop_hint(PropKind.MUSSEL_ROCK), "mussel rock - gather")
	eq(UiRules.prop_hint(PropKind.FIRE), "fire - make")
	eq(UiRules.hint_key(PropKind.FIRE), "c")
	eq(UiRules.hint_key(PropKind.PINE), "e")
	eq(UiRules.prop_hint(PropKind.LAMP), "", "nothing to do to a lamp post")


func test_use_target_prefers_what_is_ahead() -> void:
	var w := WorldData.new(1, 16)
	for i in w.level.size():
		w.level[i] = 1
	var behind := WorldProp.new(0, PropKind.PINE, Vector2(7.0, 8.5), 0.0, 1.0)
	var ahead := WorldProp.new(1, PropKind.BOULDER, Vector2(9.2, 8.5), 0.0, 1.0)
	w.props = [behind, ahead]
	var q := WorldQuery.new(w)
	var t := UiRules.use_target(q, Vector2(8.1, 8.5), 0.0)
	check(t == ahead, "facing east picks the boulder")
	t = UiRules.use_target(q, Vector2(8.1, 8.5), PI)
	check(t == behind, "facing west picks the pine")
	w.depleted[ahead.id] = INF
	t = UiRules.use_target(q, Vector2(8.1, 8.5), 0.0)
	check(t == behind, "a taken prop is not a target")
	w.props.append(WorldProp.new(2, PropKind.FIRE, Vector2(3.5, 3.5), 0.0, 1.0))
	q = WorldQuery.new(w)
	eq(UiRules.station_near(q, Vector2(4.5, 4.5)), &"fire")
	eq(UiRules.station_near(q, Vector2(12.5, 12.5)), &"")


func test_inventory_groups_in_notebook_order() -> void:
	var inv := Inventory.new()
	inv.add(&"stone", 3)
	inv.add(&"mussels", 2)
	inv.add(&"knife")
	var rows := UiRules.inventory_rows(inv)
	var shape: Array = rows.map(func(r: Dictionary) -> String: return String(r.get("header", r.get("id"))))
	eq(shape, ["tools", "knife", "food", "mussels", "goods", "stone"])
	eq(rows[5].count, 3, "count")


func test_give_is_parsed_and_never_doubles() -> void:
	var g := BootOptions.parse(["--give=stone:3,timber,scrap:2"]).give
	eq(g, {&"stone": 3, &"timber": 1, &"scrap": 2})
	var inv := Inventory.new()
	inv.add(&"stone", 1)
	UiRules.apply_give(inv, g)
	UiRules.apply_give(inv, g)
	eq(inv.count(&"stone"), 3, "topped up to 3, once")
	eq(inv.count(&"scrap"), 2)


func test_messages_stack_fade_and_count_repeats() -> void:
	var m := UiMessages.new()
	m.push("Took 2 timber.")
	m.step(1.0)
	m.push("The edge is going.")
	var shown := m.visible()
	eq(shown.size(), 2, "two said close together are both shown")
	eq(shown[1].text, "The edge is going.", "newest last")
	m.push("The edge is going.")
	eq(m.visible().size(), 2, "a repeat does not stack")
	eq(m.visible()[1].text, "The edge is going. ×2", "it is counted")
	for i in 5:
		m.push("line %d" % i)
	eq(m.lines.size(), UiMessages.MAX, "at most three lines")
	m.step(UiMessages.HOLD + UiMessages.FADE + 0.1)
	check(m.visible().is_empty(), "all faded")
	check(m.lines.is_empty(), "and forgotten")


func test_nothing_is_said_in_a_fight_until_it_is_over() -> void:
	var m := UiMessages.new()
	m.quiet = true
	m.push("It is not biting the way it did.")
	m.push("Took 1 plate.")
	check(m.visible().is_empty(), "no text while a hostile is close")
	m.push("Not with that so close.", true)
	eq(m.visible().size(), 1, "a refusal is said at once")
	m.quiet = false
	var said: Array = m.visible().map(func(l: Dictionary) -> String: return l.text)
	eq(said, ["Not with that so close.", "It is not biting the way it did.", "Took 1 plate."], "the rest follow, in order")


func test_text_already_on_screen_leaves_when_a_fight_comes() -> void:
	var m := UiMessages.new()
	m.push("Took 2 timber.")
	m.step(0.5)
	m.push("Not with that so close.", true)
	m.quiet = true
	m.step(UiMessages.HUSH * 0.5)
	var said: Array = m.visible().map(func(l: Dictionary) -> String: return l.text)
	eq(said.size(), 2, "half way through the hush both still show")
	check(m.visible()[0].alpha < 0.75, "but the old line is already fading: %s" % m.visible()[0].alpha)
	m.step(UiMessages.HUSH * 0.5 + 0.02)
	said = m.visible().map(func(l: Dictionary) -> String: return l.text)
	eq(said, ["Not with that so close."], "gone within the hush; a refusal said now stays")
	var hud := Hud.new()
	hud.show_place("moss")
	for i in 60:
		hud.step_place(1.0 / 60.0)
	eq(hud.place_alpha(), 1.0, "a place name holds in calm")
	hud.messages.quiet = true
	hud.step_place(1.0 / 60.0)
	check(hud.place_alpha() > 0.9, "and fades from where it stood, no pop: %s" % hud.place_alpha())
	for i in 18:
		hud.step_place(1.0 / 60.0)
	eq(hud.place_alpha(), 0.0, "gone within %s s of a fight" % Hud.PLACE_HUSH)
	hud.messages.quiet = false
	hud.step_place(1.0 / 60.0)
	eq(hud.place_alpha(), 0.0, "and it does not come back after")
	hud.free()


func test_a_new_country_is_announced_once_it_holds() -> void:
	var w := UiPlaceWatch.new()
	eq(w.step(Country.COAST, 0.016), Country.COAST, "the start is named at once")
	eq(w.step(Country.COAST, 5.0), -1, "and only once")
	eq(w.step(Country.MOSS, 0.5), -1, "a step over the border is not yet a crossing")
	eq(w.step(Country.COAST, 0.5), -1, "back again: nothing")
	eq(w.step(Country.MOSS, 0.1), -1)
	var got := -1
	for i in 20:
		var r := w.step(Country.MOSS, 0.1)
		if r >= 0:
			got = r
	eq(got, Country.MOSS, "holding the new country names it")
	eq(w.step(Country.SEA, 3.0), -1, "wading out to sea names nothing")


func test_clock_at_names_the_day_only_when_it_changes() -> void:
	eq(UiRules.clock_at(8.0 * 60.0 + 270.0, 8.0 * 60.0), "12:30")
	eq(UiRules.clock_at(22.0 * 60.0 + 300.0, 22.0 * 60.0), "day 2 03:00")


func test_durations_read_like_a_notebook() -> void:
	eq(UiRules.duration(45.0), "45 min")
	eq(UiRules.duration(240.0), "4 h")
	eq(UiRules.duration(270.0), "4 h 30")


func test_recipes_are_named_by_what_they_make_and_told_apart() -> void:
	var fire_a := {"id": &"campfire", "at": &"hand", "needs": {&"driftwood": 3, &"stone": 2}, "makes": {}, "builds": &"fire"}
	var fire_b := {"id": &"campfire_timber", "at": &"hand", "needs": {&"timber": 1, &"stone": 2}, "makes": {}, "builds": &"fire"}
	var coal := {"id": &"charcoal", "at": &"fire", "needs": {&"driftwood": 4}, "makes": {&"charcoal": 2}}
	var haft_a := {"id": &"haft", "at": &"hand", "needs": {&"driftwood": 2}, "makes": {&"haft": 1}}
	var haft_b := {"id": &"haft_timber", "at": &"hand", "needs": {&"timber": 1}, "makes": {&"haft": 2}}
	var hone := {"id": &"sharpen", "at": &"hand", "needs": {}, "makes": {}, "action": &"hone"}
	var all: Array[Dictionary] = [fire_a, fire_b, coal, haft_a, haft_b, hone]
	eq(UiRules.recipe_title(coal, all), "charcoal ×2", "alone, just what it makes")
	eq(UiRules.recipe_title(fire_a, all), "build a fire, of driftwood", "two ways to a fire, told apart")
	eq(UiRules.recipe_title(fire_b, all), "build a fire, of timber")
	eq(UiRules.recipe_title(haft_b, all), "haft ×2, of timber", "the same thing in other numbers is still a twin")
	eq(UiRules.recipe_title(hone, all), "sharpen what is in hand")
	eq(UiRules.recipe_output(coal), &"charcoal")
	eq(UiRules.station_words(&"hand"), "by hand")
	eq(UiRules.station_words(&"kiln"), "at the kiln")


func test_why_not_names_the_shortfall() -> void:
	var inv := Inventory.new()
	inv.add(&"driftwood", 1)
	var r := {"id": &"charcoal", "at": &"fire", "minutes": 180.0, "needs": {&"driftwood": 4}, "makes": {&"charcoal": 2}}
	eq(UiLink.why_not(null, inv, r), "Short of three driftwood.")
	eq(UiLink.missing(inv, r), {&"driftwood": 3})
	inv.add(&"driftwood", 3)
	eq(UiLink.why_not(null, inv, r), "", "all in hand")
	check(UiLink.make(null, inv, r), "made without a game")
	eq(inv.count(&"charcoal"), 2)
	eq(UiLink.group_of(&"knife"), &"tools")
	eq(UiLink.group_of(&"mussels"), &"food")
	eq(UiLink.group_of(&"stone"), &"goods")


func test_a_shortfall_reads_as_plain_english() -> void:
	eq(UiRules.counted("a piece of plate", 1), "a piece of plate", "one of a thing that counts itself keeps its article")
	eq(UiRules.counted("a piece of plate", 2), "two pieces of plate", "more than one: the number takes the article's place")
	eq(UiRules.counted("an axe", 3), "three axes")
	eq(UiRules.counted("a box of matches", 2), "two boxes of matches")
	eq(UiRules.counted("a berry", 4), "four berries")
	eq(UiRules.counted("some salt", 2), "two salt")
	eq(UiRules.counted("driftwood", 3), "three driftwood", "a stuff name is counted as it is")
	eq(UiRules.counted("mussels", 1), "one mussels")
	eq(UiRules.bare("a piece of plate"), "piece of plate")
	var inv := Inventory.new()
	var r := {"id": &"brace", "at": &"bench", "needs": {&"scrap": 2}, "makes": {&"kit_brace": 1}}
	var line := UiLink.why_not(null, inv, r)
	eq(line, "Short of %s." % UiRules.counted(UiRules.item_name(&"scrap"), 2))
	for bad: String in ["one a ", "two a ", "one an ", "two an "]:
		check(not line.contains(bad), "no number before an article: %s" % line)
	inv.add(&"scrap", 3)
	var rows := UiRules.inventory_rows(inv)
	eq(UiRules.list_name(&"scrap", 3), UiRules.plural(UiRules.item_name(&"scrap")), "a list row of several says the plural")
	eq(rows.size(), 2)
