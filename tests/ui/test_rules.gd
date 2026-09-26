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


## Starving is not "hungry, worse": it is the rung where the body goes down, and
## a lit lamp running dry takes the light and the slate's power with it.
func test_the_last_rung_of_hunger_and_the_lamp_running_dry() -> void:
	var b := Body.new()
	b.fed_until = 1000.0
	var t := 1000.0
	while b.hunger_level(t) < 3:
		t += 10.0
	eq(UiRules.needs(b, t, 10.0)[0].level, 3, "starving is its own rung")
	b.fed_until = t + 100000.0
	check(UiRules.needs(b, t, 10.0, UiRules.CREEL, 10.0, false).is_empty(), "an unlit lamp asks nothing")
	check(UiRules.needs(b, t, 10.0, UiRules.CREEL, Survival.LAMP_LOW_MINUTES * 2.0, true).is_empty(), "nor a full one")
	var low := UiRules.needs(b, t, 10.0, UiRules.CREEL, Survival.LAMP_LOW_MINUTES * 0.8, true)
	eq(low.size(), 1)
	eq(low[0].need, &"lamp")
	eq(low[0].level, 2, "low oil is the accent")
	near(float(low[0].value), 0.8, 0.01, "the gauge reads what is left, not how bad it is")
	var last := UiRules.needs(b, t, 10.0, UiRules.CREEL, Survival.LAMP_LOW_MINUTES * 0.1, true)
	eq(last[0].level, 3, "minutes from guttering is the last rung")
	var p := UiRules.pressures(b, t, 10.0, UiRules.CREEL, Survival.LAMP_LOW_MINUTES * 0.1, true)
	eq(p[0].id, &"lamp", "and it reaches the gauges with its own value")
	near(float(p[0].value), 0.1, 0.01)


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
	eq(m.lines.size(), UiMessages.MAX, "never more lines than the cap")
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
	# The refusal was read while the fight was on; what stands after it is the
	# queue, in order, up to the cap.
	eq(said, ["It is not biting the way it did.", "Took 1 plate."], "the rest follow, in order")
	check(said.size() <= UiMessages.MAX, "and never more of them than the glass holds")


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


func test_a_line_said_on_a_page_is_not_said_again_after() -> void:
	var hud := Hud.new()
	tree.root.add_child(hud)
	Events.screen_changed.emit(&"inventory", true)
	Events.message.emit("The knife in hand.")
	check(hud.messages.lines.is_empty(), "the page took it; the HUD does not queue it")
	Events.screen_changed.emit(&"inventory", false)
	check(hud.messages.lines.is_empty(), "nor play it when the page closes")
	Events.message.emit("Took 2 timber.")
	eq(hud.messages.lines.size(), 1, "with no page open, the HUD says it")
	hud.free()


func test_a_new_landscape_is_pinged_once_it_holds() -> void:
	var w := UiPlaceWatch.new()
	eq(w.step(&"coast", 0.016), &"coast", "the start is named at once")
	eq(w.step(&"coast", 5.0), &"", "and only once")
	eq(w.step(&"moss", 0.5), &"", "a step over the border is not yet a crossing")
	eq(w.step(&"coast", 0.5), &"", "back again: nothing")
	eq(w.step(&"moss", 0.1), &"")
	var got := &""
	for i in 20:
		var r := w.step(&"moss", 0.1)
		if r != &"":
			got = r
	eq(got, &"moss", "holding the new landscape names it")
	eq(w.step(&"sea", 3.0), &"", "wading out to sea names nothing")


func test_the_slate_runs_off_the_lamp_or_a_charge_and_dims_when_low() -> void:
	eq(UiRules.slate_power(UiRules.POWER_LAMP_MINUTES, 0), 1.0, "a full flask")
	eq(UiRules.slate_power(0.0, UiRules.POWER_CHARGES), 1.0, "or enough charges")
	near(UiRules.slate_power(UiRules.POWER_LAMP_MINUTES * 0.5, 1), 0.5, 1e-4, "whichever holds more")
	eq(UiRules.slate_power(0.0, 0), 0.0, "nothing left")
	eq(UiRules.brightness(1.0), 1.0)
	eq(UiRules.brightness(UiSlate.LOW_POWER), 1.0, "full brightness down to the low line")
	check(UiRules.brightness(UiSlate.LOW_POWER * 0.5) < 1.0, "it dips below it")
	eq(UiRules.brightness(0.0), UiSlate.DIM_FLOOR, "never darker than the floor")
	check(UiSlate.DIM_FLOOR >= 0.75, "the floor keeps it readable")
	eq(UiRules.cell_segments(1.0), 4)
	eq(UiRules.cell_segments(0.5), 2)
	eq(UiRules.cell_segments(0.2), 1, "a sliver still shows a segment")
	eq(UiRules.cell_segments(0.0), 0)


func test_charges_show_only_with_something_that_spends_them() -> void:
	check(not UiRules.charge_shown(&""), "bare hands")
	check(not UiRules.charge_shown(&"knife"), "a made tool spends nothing")
	check(UiRules.charge_shown(&"las_hand"), "a found weapon spends charges")


func test_pressures_are_gauges_only_while_they_matter() -> void:
	var b := Body.new()
	b.fed_until = 1000.0
	check(UiRules.pressures(b, 900.0, 5.0).is_empty(), "fed, dry, light, no hazard: no gauges")
	b.pressure = {&"cold": 0.1}
	check(UiRules.pressures(b, 900.0, 5.0).is_empty(), "a hazard too faint to feel is not shown")
	b.pressure = {&"heat": 0.4, &"cold": 0.9}
	var list := UiRules.pressures(b, 900.0, 5.0)
	var ids: Array = list.map(func(p: Dictionary) -> StringName: return p.id)
	eq(ids, [&"cold", &"heat"], "felt hazards, in a fixed order")
	eq(list[0].level, 2, "a hard pressure is the warning")
	eq(list[1].level, 1, "a lighter one is quiet")
	b.wet = 0.9
	eq(UiRules.pressures(b, 900.0, 5.0)[0].id, &"wet", "the body's needs come first")


func test_a_share_never_reads_nothing_once_something_is_seen() -> void:
	eq(UiRules.share(0.0), "0%")
	eq(UiRules.share(0.0004), "0.1%")
	eq(UiRules.share(0.034), "3.4%")
	eq(UiRules.share(0.5), "50%")


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


## ONE CORE, TWO USES (GEAR.md G5): a keeper's core read on the slate says both
## things it can become, side by side, and what each gives and costs, so the
## choice is read before it is made. Anything else says nothing of the kind.
func test_a_keepers_core_reads_as_a_choice() -> void:
	var uses := UiRules.core_uses(&"reaper_core")
	eq(uses.size(), 2, "the reaper's core: two uses")
	eq(uses[0].get("makes", &""), &"stolen cell", "power a holding: the stolen cell")
	eq(uses[1].get("makes", &""), &"undertow", "or wear it: the undertow")
	for u: Dictionary in uses:
		check(String(u.get("title", "")) != "", "each use is named")
		gt((u.get("gives", []) as Array).size(), 1, "and says what it gives and what it costs: %s" % u.get("makes"))
	check(" ".join(PackedStringArray(uses[0].gives)).contains("4 power"), "the cell's power is a number")
	# A core whose power is not built yet still reads as a holding's cell.
	eq(UiRules.core_uses(&"plumb_core").size(), 1, "the plumb's core: a cell until its power is made")
	eq(UiRules.core_uses(&"scrap").size(), 0, "scrap is no keeper's core")
