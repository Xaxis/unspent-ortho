extends TestCase
## Modifiers combine, conflict, and can be pulled back out again (docs/VISION.md
## §6.1, "Modifiers are the elegance"). Every rule here is one a player can feel:
## a part that pays for another's heat, a part that shouts through another's hush,
## and a panel that may break when you prise it out on the road.


func _kit(ids: Array[StringName]) -> Dictionary:
	var out: Dictionary = {}
	for id in ids:
		Gear.combine(out, Gear.resist_of(id))
	Modifiers.settle(ids, out)
	return out


func test_every_module_says_what_decision_it_changes() -> void:
	for id: StringName in Items.DEFS:
		if not Gear.is_module(id):
			continue
		check(ModifierTable.has(id), "%s is a module and says nothing about what it is for" % id)
		var said := ModifierTable.decision(id)
		gt(float(said.length()), 12.0, "%s's decision is too short to teach anything: '%s'" % [id, said])
		check(not said.begins_with("resist"), "%s reads as a number, not a decision" % id)


## The gear page has ONE line beside a socket and it does not clip. The first
## version of this put the whole sentence there, and it ran out of the list panel
## and printed itself across the resistances column (tours/gear-economy.tour frame
## 05, read and rejected). So the width is measured here, in the real font,
## against the real panel, for every module and for every price it could be
## paying — because the conflict line is what shows when something is wrong, which
## is exactly when a player most needs to be able to read it.
func test_what_the_gear_page_says_about_a_module_fits_the_row_it_is_drawn_in() -> void:
	# Where UiLoadoutScreen draws it, ASKED FOR rather than copied: it used to say
	# 71 and 8 here, which were that panel's numbers in the old 640x360 space. The
	# screen moved them to 142 and 16 when the base did and this did not follow, so
	# the test allowed 737 px against the row's real 658 -- a conflict line between
	# the two passed here and ran across the resistances column, which is the one
	# thing this test exists to stop.
	var x0 := UiSlate.LIST.position.x + UiSlate.MARGIN_L
	var room := (UiSlate.LIST.end.x - UiLoadoutScreen.LIST_PAD_R) - (x0 + UiLoadoutScreen.ROW_TEXT_X)
	var kits: Array = [
		[] as Array[StringName],
		[&"mod_lattice"] as Array[StringName],
		[&"mod_lattice", &"mod_cooling"] as Array[StringName],
		[&"mod_lattice", &"mod_damp", &"mod_signet"] as Array[StringName],
		[&"mod_capacitor", &"mod_leech"] as Array[StringName],
		[&"mod_gyro", &"mod_clamp"] as Array[StringName],
	]
	for id: StringName in Items.DEFS:
		if not Gear.is_module(id):
			continue
		for kit: Array in kits:
			var with_it: Array[StringName] = [id]
			for other: StringName in kit:
				if other != id:
					with_it.append(other)
			var line := "%s  %s" % [UiRules.item_name(id), Modifiers.note(id, with_it)]
			check(UiFont.width(line) <= room,
				"'%s' is %d px wide and the row holds %d" % [line, UiFont.width(line), room])


func test_a_spoofer_and_a_lattice_put_each_other_out() -> void:
	# VISION's own example: one hides you, the other shouts, and a name shouted is
	# not a name worn.
	var l := Loadout.new()
	l.fit(&"body", &"wrap_warm")
	l.socket(&"body", &"mod_signet")
	eq(Gear.abilities_of(l), [&"spoof"] as Array[StringName], "the signet wears their name")
	l.hold(&"knife_mono")
	check(l.socket(Gear.HAND_SLOT, &"mod_lattice"), "the lattice binds to the haft")
	check(not Gear.abilities_of(l).has(&"spoof"), "and it shouts the name off you")
	# Two prices are being paid here, and both are real: the name is shouted off,
	# and the lattice is running hot with nothing to carry the heat away.
	var dropped := 0
	for why: Dictionary in Modifiers.conflicts(l.all_ids()):
		check(String(why.get("line", "")).length() > 8, "a conflict says why: %s" % why.get("line"))
		dropped += 1 if StringName((why.get("effect", {}) as Dictionary).get("drop", &"")) == &"spoof" else 0
	eq(dropped, 1, "the spoof is taken away once, by the part that shouts")


func test_a_hush_is_smothered_by_anything_that_rings() -> void:
	var quiet := _kit([&"mod_damp"] as Array[StringName])
	var both := _kit([&"mod_damp", &"mod_harmonic"] as Array[StringName])
	lt(float(both.get(&"resonance", 0.0)), float(quiet.get(&"resonance", 0.0)),
		"the harmonic edge rings through the damper")
	# A cost is a price, never a refusal: the damper still does most of its job.
	gt(float(both.get(&"resonance", 0.0)), float(quiet.get(&"resonance", 0.0)) * 0.4,
		"and it is a price, not a part that has stopped working")


func test_heat_has_to_go_somewhere_and_the_loop_is_where() -> void:
	var lattice := _kit([&"vest_heatsink", &"mod_lattice"] as Array[StringName])
	var paid := _kit([&"vest_heatsink", &"mod_lattice", &"mod_cooling"] as Array[StringName])
	var bare := _kit([&"vest_heatsink"] as Array[StringName])
	lt(float(lattice.get(&"heat", 0.0)), float(bare.get(&"heat", 0.0)),
		"a shock lattice with nothing to carry its heat away costs the kit")
	gt(float(paid.get(&"heat", 0.0)), float(lattice.get(&"heat", 0.0)),
		"a cooling loop pays for it")
	var unpaid := Modifiers.unpaid([&"vest_heatsink", &"mod_lattice"] as Array[StringName])
	eq(unpaid.size(), 1, "and the page says what is unpaid: %s" % [unpaid])
	eq(Modifiers.unpaid([&"mod_lattice", &"mod_cooling"] as Array[StringName]).size(), 0,
		"once it is paid, nothing is owed")


func test_two_parts_that_do_the_same_thing_make_a_build() -> void:
	var one := _kit([&"mod_capacitor"] as Array[StringName])
	var two := _kit([&"mod_capacitor", &"mod_leech"] as Array[StringName])
	var apart := {}
	Gear.combine(apart, Gear.resist_of(&"mod_capacitor"))
	Gear.combine(apart, Gear.resist_of(&"mod_leech"))
	gt(float(two.get(&"em", 0.0)), float(apart.get(&"em", 0.0)),
		"a bank and a leech coil together are more than the two of them added up")
	gt(float(two.get(&"em", 0.0)), float(one.get(&"em", 0.0)), "and more than either alone")
	eq(Modifiers.combos([&"mod_capacitor", &"mod_leech"] as Array[StringName]).size(), 1,
		"said once, as one combination")
	var braced := _kit([&"mod_gyro", &"mod_clamp"] as Array[StringName])
	var gyro := _kit([&"mod_gyro"] as Array[StringName])
	gt(float(braced.get(&"collapse", 0.0)), float(gyro.get(&"collapse", 0.0)) + 0.1,
		"braced and clamped, the floor can go out from under you")


func test_the_same_parts_always_settle_to_the_same_numbers() -> void:
	var a := _kit([&"mod_lattice", &"mod_cooling", &"mod_damp", &"mod_capacitor"] as Array[StringName])
	var b := _kit([&"mod_capacitor", &"mod_damp", &"mod_cooling", &"mod_lattice"] as Array[StringName])
	eq(b, a, "the order they were socketed in is not part of the answer")


## **RETIRED, BECAUSE ITS PREMISE WAS REMOVED RATHER THAN ITS RULE RELAXED.**
##
## This forbade any part that costs the kit (`loud`, `hot`) from answering a
## pressure a landscape really declares. The reason was never that such a part is
## wrong: it was that `tests/hazards/test_whole_kit.gd:best_kit` found the best
## kit for a landscape by ADDING resistances and never charging the price, so if
## a costing part were ever the best answer, the guarantee "this place can be
## worn through" would have been optimistic by exactly the size of the cost.
##
## The machine city declares EM and `mod_lattice` answers EM, so this fired --
## and this file's own instruction for that day was "the fix then is to settle
## inside `best_kit`, not to weaken this". `best_kit` settles now, at every step
## of its search, through the same `Modifiers.settle` the live game uses. The
## guarantee is kept where it is enforced:
## `test_whole_kit.gd:test_a_part_that_costs_the_kit_is_charged_for_it`.
##
## Deleting a rule to make a suite green is the cardinal sin; this is the other
## thing, and the difference is that the condition the rule was written under no
## longer holds and the protection moved rather than vanished.


# --- taking it back out again --------------------------------------------------

func test_cord_unties_anywhere_and_a_drilled_panel_does_not() -> void:
	check(Reforge.unties(&"mod_wadding"), "a rag comes off")
	check(Reforge.unties(&"mod_grip"), "so does a bound grip")
	check(not Reforge.unties(&"mod_cooling"), "a loop is drilled into its frame")
	check(not Reforge.risky(&"mod_cooling", true), "at a bench, nothing is risked")
	check(Reforge.risky(&"mod_cooling", false), "out in the field it is")
	check(Reforge.warning(&"mod_cooling", false) != "", "and the page says so first")
	eq(Reforge.warning(&"mod_cooling", true), "", "and says nothing at a bench")


func test_a_pull_is_the_same_pull_however_often_the_game_is_reloaded() -> void:
	for n: int in 12:
		eq(Reforge.survives(&"mod_cooling", false, 7, n), Reforge.survives(&"mod_cooling", false, 7, n),
			"the same pull answers the same way")
	var broke := 0
	for n: int in 200:
		if not Reforge.survives(&"mod_cooling", false, 7, n):
			broke += 1
	gt(float(broke), 0.0, "a field pull can cost the part")
	lt(float(broke), 200.0 * 0.5, "and usually does not")
	var at_bench := 0
	for n: int in 200:
		at_bench += 0 if Reforge.survives(&"mod_cooling", true, 7, n) else 1
	eq(at_bench, 0, "a bench never costs the part")


func test_breaking_a_piece_down_always_gives_the_elite_material_back() -> void:
	# Nothing is dead loot: the journey is never spent twice.
	for id: StringName in GearTree.ids():
		var elite := GearTree.made_of(id)
		if elite == &"":
			continue
		var back := Reforge.salvage(id)
		check(back.has(elite), "breaking %s down should give its %s back" % [id, elite])
		gt(float(int(back[elite])), 0.0, "and more than none of it")
