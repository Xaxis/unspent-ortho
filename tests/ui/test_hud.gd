extends TestCase
## The slate's edge overlay: readouts show and hide by the rules. Health, the
## clock and the thing in hand always; wind only while some is spent; charges
## only with something in hand that spends them; a pressure only while it is
## felt; the use hint never near a hostile; no text in a fight.


func _hud() -> Hud:
	var hud := Hud.new()
	tree.root.add_child(hud)
	return hud


func _run(hud: Hud, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		hud._process(1.0 / 30.0)
		t += 1.0 / 30.0


func test_the_always_readouts_and_the_quiet_ones() -> void:
	var hud := _hud()
	hud.set_body(12, 12, 2400.0, 2400.0)
	hud.set_held(&"knife")
	hud.set_charge(UiRules.charge_shown(&"knife"), 3)
	hud.settle()
	var s := hud.shown()
	eq(s[&"health"], 1.0)
	eq(s[&"clock"], 1.0)
	eq(s[&"held"], 1.0)
	eq(s[&"wind"], 0.0, "full wind is not shown")
	eq(s[&"charge"], 0.0, "a knife spends no charges: none shown")
	hud.set_body(12, 12, 1200.0, 2400.0)
	_run(hud, 0.5)
	eq(hud.shown()[&"wind"], 1.0, "spent wind comes up")
	hud.set_body(12, 12, 2400.0, 2400.0)
	_run(hud, 1.0)
	eq(hud.shown()[&"wind"], 0.0, "and goes once it is back")
	hud.set_held(&"las_hand")
	hud.set_charge(UiRules.charge_shown(&"las_hand"), 2)
	_run(hud, 0.4)
	eq(hud.shown()[&"charge"], 1.0, "a found weapon in hand shows its charges")
	hud.free()


func test_pressures_come_and_go_as_gauges() -> void:
	var hud := _hud()
	var b := Body.new()
	b.fed_until = 1000.0
	hud.set_pressures(UiRules.pressures(b, 900.0, 5.0))
	hud.settle()
	check(not hud.shown().has(&"cold"), "nothing felt, no gauge")
	b.pressure = {&"cold": 0.8}
	hud.set_pressures(UiRules.pressures(b, 900.0, 5.0))
	_run(hud, 1.0)
	eq(hud.shown().get(&"cold", 0.0), 1.0, "the cold comes up as a gauge")
	b.pressure = {}
	hud.set_pressures(UiRules.pressures(b, 900.0, 5.0))
	_run(hud, 1.0)
	check(not hud.shown().has(&"cold"), "and goes when it no longer presses")
	hud.free()


func test_the_hint_fades_and_the_ping_hushes_in_a_fight() -> void:
	var hud := _hud()
	hud.set_hint("pine - fell")
	_run(hud, 0.3)
	eq(hud.shown()[&"hint"], 1.0, "a hint shows")
	hud.set_hint("")
	_run(hud, 0.3)
	eq(hud.shown()[&"hint"], 0.0, "and fades out")
	hud.show_place("moss")
	_run(hud, 1.0)
	eq(hud.shown()[&"place"], 1.0, "the location ping holds in calm")
	hud.set_quiet(true)
	_run(hud, Hud.PLACE_HUSH + 0.05)
	eq(hud.shown()[&"place"], 0.0, "and is gone in a fight")
	hud.free()


## The ping's brackets close in from outside the word. At no point in the rise
## does a bracket stand over a letter, whatever the name is called.
func test_the_place_name_is_never_struck_through_by_its_own_brackets() -> void:
	for word: int in [20, 46, 86, 140]:
		var last := 9999
		for step in 21:
			var grow := step / 20.0
			var half := Hud.place_half(word, grow)
			gt(float(half), word / 2.0 + 6.0, "at %.2f in, the bracket is clear of a %d px name" % [grow, word])
			check(half <= last, "and it only ever closes in")
			last = half
		eq(Hud.place_half(word, 1.0), roundi(word / 2.0 + 12.0), "and comes to rest just off the word")


## The ping's ring used to be an ellipse grown from the middle of the screen,
## and its 0.5 vertical squash clustered the samples at the height of the
## letters: `C O A S T` read `C ⌷CH:S T`. The ring now rings out from the edge
## of the name's own plate and is never inside it, at any width, at any moment
## of the ping.
func test_the_ping_ring_never_crosses_the_name() -> void:
	for word: int in [20, 46, 86, 140]:
		var plate := Hud.place_plate(word)
		var name_box := Rect2i(320 - word / 2, Hud.PLACE_Y, word, 10)
		check(plate.encloses(name_box), "a %d px name sits on the plate" % word)
		var seen := 0
		for step in 60:
			var age := step / 60.0 * Hud.PLACE_IN * 1.5
			for p in Hud.ring_points(age, plate):
				seen += 1
				check(not plate.grow(1).has_point(p), "no ring pixel inside the plate at %.2f s" % age)
		gt(float(seen), 200.0, "and there is still a ring to see for a %d px name" % word)
	eq(Hud.ring_points(Hud.PLACE_IN * 1.5 + 0.01, Hud.place_plate(46)).size(), 0, "the ring is spent by the end of the rise")


## The badges in the top right already say which pressures are on the body. A
## line whose whole subject is one of them is not also written across the
## middle of the world: the gauge answers for it. The last rung is the one
## exception — starving and a dry lamp still get words.
func test_a_pressure_the_badge_says_is_not_also_said_in_words() -> void:
	var hud := _hud()
	var b := Body.new()
	b.fed_until = 1000.0
	b.pressure = {&"cold": 0.8}
	hud.set_pressures(UiRules.pressures(b, 900.0, 5.0))
	hud.settle()
	hud.show_message(Hazards.LINES[&"cold"])
	_run(hud, 0.3)
	check(hud.messages.visible().is_empty(), "the cold badge answers for the cold line")
	check(hud._gauge_flare.has(&"cold"), "and says so: brackets close on the tile")
	hud.show_message("A wall of them came out of the trees.")
	eq(hud.messages.visible().size(), 1, "a line no readout says is still said, at once")
	hud.free()


func test_the_last_rung_still_gets_words() -> void:
	var hud := _hud()
	var b := Body.new()
	b.fed_until = 0.0
	hud.set_pressures(UiRules.pressures(b, 100000.0, 5.0))
	hud.settle()
	eq(hud.gauge_level(&"hunger"), 3, "starving is the last rung")
	hud.show_message(Survival.STARVING_LINE)
	_run(hud, 0.3)
	eq(hud.messages.visible().size(), 1, "the rung that ends the run is still said aloud")
	hud.free()


## A line about a pressure nothing is showing a gauge for is never swallowed.
func test_a_line_with_no_gauge_on_the_glass_is_said() -> void:
	var hud := _hud()
	hud.settle()
	hud.show_message(Hazards.LINES[&"heat"])
	_run(hud, 0.3)
	eq(hud.messages.visible().size(), 1, "no heat gauge up, so the words come")
	eq(UiMessages.gauge_for("Took 2 timber."), &"", "an ordinary line belongs to no readout")
	eq(UiMessages.gauge_for(Survival.HUNGRY_LINE), &"hunger", "and the hunger line to the hunger gauge")
	for id: Variant in Hazards.LINES:
		eq(UiMessages.gauge_for(String(Hazards.LINES[id])), StringName(id), "%s has its gauge" % id)
	hud.free()


## The UI is the quietest layer: the slate's one warning colour is kept for the
## rung that ends the run. A pressure that merely bites is phosphor, with only
## its meter — the part that says how bad it is — in the dimmed warning.
func test_the_badge_keeps_the_loudest_colour_for_the_last_rung() -> void:
	eq(Hud.gauge_ink(1), UiTheme.TEXT, "a felt pressure is phosphor")
	eq(Hud.gauge_ink(2), UiTheme.TEXT, "and so is one that bites")
	eq(Hud.gauge_ink(3), UiTheme.WARN, "the last rung is the warning")
	eq(Hud.gauge_meter_ink(1), UiTheme.TEXT)
	eq(Hud.gauge_meter_ink(2), UiTheme.WARN_DIM, "a biting meter is the warning, dimmed")
	eq(Hud.gauge_meter_ink(3), UiTheme.WARN)
	lt(UiTheme.WARN_DIM.get_luminance(), UiTheme.WARN.get_luminance(), "which is quieter than the warning itself")


func test_the_lamp_and_the_last_rung_of_hunger_are_gauges() -> void:
	var hud := _hud()
	var b := Body.new()
	b.fed_until = 0.0
	# Starving (level 3) and a lamp down to its last minutes, both felt at once.
	hud.set_pressures(UiRules.pressures(b, 100000.0, 5.0, UiRules.CREEL, 6.0, true))
	hud.settle()
	var ids := {}
	for p in hud.pressures:
		ids[p.id] = p
	check(ids.has(&"hunger") and int(ids[&"hunger"].level) == 3, "starving is its own rung")
	check(ids.has(&"lamp") and int(ids[&"lamp"].level) == 3, "and so is a lamp about to gutter")
	lt(float(ids[&"lamp"].value), 0.2, "its gauge reads how little is left")
	eq(hud.shown().get(&"lamp", 0.0), 1.0, "the lamp gauge is up")
	hud.set_pressures(UiRules.pressures(b, 100000.0, 5.0, UiRules.CREEL, 6.0, false))
	_run(hud, 1.0)
	check(not hud.shown().has(&"lamp"), "an unlit lamp spends no oil and asks nothing")
	hud.free()


## The gauges are drawn right to left from the clock, so the order they come in
## is the order they stand out from it: the body's own needs first, hunger — the
## rung that ends the run — nearest the clock, then what the land presses with.
func test_the_gauge_nearest_the_clock_is_the_one_that_ends_the_run() -> void:
	eq(Hud.gauge_order([&"tired", &"wet", &"hunger"]), [&"hunger", &"wet", &"tired"] as Array[StringName], "needs in the order they cost you")
	eq(Hud.gauge_order([&"radiation", &"cold", &"lamp", &"hunger"]), [&"hunger", &"lamp", &"cold", &"radiation"] as Array[StringName], "then the land's pressures, by name")
	eq(Hud.gauge_order([&"cold"]), [&"cold"] as Array[StringName], "a pressure with no need beside it")
	eq(Hud.gauge_order([]), [] as Array[StringName], "nothing felt, nothing drawn")
	for k: StringName in Hud.GAUGE_ORDER:
		check(UiIcons.NEEDS.has(k), "%s has a glyph of its own" % k)


func test_every_hazard_the_land_names_has_a_gauge_glyph() -> void:
	for d in BiomeRegistry.all():
		for h: Variant in d.hazards:
			check(UiIcons.NEEDS.has(StringName(h)), "%s (from %s) has its own glyph" % [h, d.id])
	for id: StringName in [&"cold", &"heat", &"fumes", &"toxins", &"radiation", &"wet", &"dark", &"vacuum", &"pressure", &"em", &"resonance", &"time_shear"]:
		check(UiIcons.NEEDS.has(id), "%s from VISION §6 has a glyph" % id)
	for k: StringName in UiIcons.NEEDS:
		var rows: Array = UiIcons.NEEDS[k]
		eq(rows.size(), 9, "%s is 9 rows" % k)
		for r: String in rows:
			eq(r.length(), 9, "%s is 9 wide" % k)
	eq(UiIcons.pressure_rows(&"no_such_hazard"), UiIcons.PRESSURE_ANY, "an unknown pressure still has a gauge")

