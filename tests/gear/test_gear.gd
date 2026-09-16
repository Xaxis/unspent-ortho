extends TestCase
## Slots, sockets, tiers and resistance maths; the loadout as data; and the
## content: every piece of gear can be reached from a normal game, is drawn, and
## resists something a landscape actually has.


func test_a_piece_goes_in_its_own_slot_and_a_module_where_it_fits() -> void:
	var l := Loadout.new()
	check(l.fit(&"body", &"wrap_warm"), "a wrap is a body piece")
	check(not l.fit(&"head", &"wrap_warm"), "and not a head one")
	eq(l.item(&"body"), &"wrap_warm")
	check(not l.fit(&"body", &"mod_wadding"), "a module is not a piece")
	check(l.socket(&"body", &"mod_wadding"), "it sockets instead")
	check(not l.socket(&"head", &"mod_wadding"), "but only where there is a socket to take it")
	eq(l.modules(&"body"), [&"mod_wadding"] as Array[StringName])
	eq(l.free_sockets(&"body"), 0, "a wrap takes one")
	check(not l.socket(&"body", &"mod_wadding"), "and no more than one")
	check(not l.socket(&"body", &"mod_filter"), "a filter only fits over a face")


func test_swapping_a_piece_keeps_the_modules_its_sockets_can_hold() -> void:
	var l := Loadout.new()
	l.fit(&"body", &"vest_heatsink")
	l.socket(&"body", &"mod_foil")
	l.socket(&"body", &"mod_spring")
	eq(l.modules(&"body").size(), 2, "the vest takes two")
	l.fit(&"body", &"wrap_warm")
	eq(l.modules(&"body").size(), 1, "a wrap has room for one; the other comes out")
	l.clear_slot(&"body")
	eq(l.item(&"body"), &"")
	eq(l.modules(&"body").size(), 0, "and taking it off empties its sockets")


func test_the_hand_slot_follows_the_inventory_and_is_never_fitted() -> void:
	var l := Loadout.new()
	eq(l.free_sockets(&"tool"), 0, "an empty hand has no socket")
	l.hold(&"knife")
	eq(l.item(&"tool"), &"knife", "the loadout shows what is in hand")
	l.clear_slot(&"tool")
	eq(l.item(&"tool"), &"knife", "and never puts it down: carrying owns that")


func test_gear_no_longer_carried_comes_off_by_itself() -> void:
	var l := Loadout.new()
	l.fit(&"body", &"vest_heatsink")
	l.socket(&"body", &"mod_spring")
	var creel := {&"vest_heatsink": 1, &"mod_spring": 1}
	l.keep_only(func(id: StringName, n: int) -> bool: return int(creel.get(id, 0)) >= n)
	eq(l.item(&"body"), &"vest_heatsink", "what is carried stays on")
	creel.erase(&"mod_spring")
	l.keep_only(func(id: StringName, n: int) -> bool: return int(creel.get(id, 0)) >= n)
	eq(l.modules(&"body").size(), 0, "a module traded away comes out of its socket")
	creel.erase(&"vest_heatsink")
	l.keep_only(func(id: StringName, n: int) -> bool: return int(creel.get(id, 0)) >= n)
	eq(l.item(&"body"), &"", "and so does the piece")


func test_two_pieces_share_what_is_left_and_never_reach_all_of_it() -> void:
	var l := Loadout.new()
	l.fit(&"body", &"wrap_warm")
	near(float(Gear.resist_total(l)[&"cold"]), 0.35, 1e-5, "one piece is its own number")
	l.socket(&"body", &"mod_wadding")
	# 0.35 and 0.20: each takes its share of what the other left.
	near(float(Gear.resist_total(l)[&"cold"]), 1.0 - 0.65 * 0.8, 1e-5, "and two share the rest")
	lt(float(Gear.resist_total(l)[&"cold"]), 1.0, "never all of it")
	var stacked := {}
	for i in 12:
		Gear.combine(stacked, {&"cold": 0.5})
	lt(float(stacked[&"cold"]), 1.0, "however much is piled on")


func test_a_loadout_says_which_abilities_it_grants() -> void:
	var l := Loadout.new()
	eq(Gear.abilities_of(l).size(), 0, "bare, none")
	l.fit(&"back", &"glide_wing")
	eq(Gear.abilities_of(l), [&"glide"] as Array[StringName], "the wing is the glide")
	l.socket(&"back", &"mod_spring")
	eq(Gear.abilities_of(l), [&"glide", &"dash"] as Array[StringName], "a module adds its own")
	l.fit(&"hands", &"boots_magnet")
	l.socket(&"hands", &"mod_spring")
	eq(Gear.abilities_of(l).size(), 3, "and the same ability twice is still one")


func test_a_loadout_goes_through_a_save_and_comes_back() -> void:
	var l := Loadout.new()
	l.fit(&"head", &"rebreather")
	l.socket(&"head", &"mod_filter")
	l.fit(&"back", &"glide_wing")
	l.hold(&"knife")
	# Through JSON, as SaveGame puts it: keys as Strings, numbers as floats.
	var round_trip: Variant = JSON.parse_string(JSON.stringify(l.save()))
	var back := Loadout.new()
	back.load_from(round_trip)
	eq(back.item(&"head"), &"rebreather")
	eq(back.modules(&"head"), [&"mod_filter"] as Array[StringName])
	eq(back.item(&"back"), &"glide_wing")
	eq(back.item(&"tool"), &"", "the hand is not saved here: carrying owns it")
	eq(Gear.resist_total(back), Gear.resist_total(l), "the same resistances come back")
	back.load_from("not a loadout")
	eq(back.item(&"head"), &"rebreather", "rubbish leaves it alone")


func test_every_piece_of_gear_is_made_drawn_and_worth_wearing() -> void:
	var landscape_hazards := {}
	for d in BiomeRegistry.all():
		for id: Variant in d.hazards:
			landscape_hazards[StringName(id)] = true
	var made_by := {}
	for r: Dictionary in Recipes.LIST:
		for id: Variant in (r.get("makes", {}) as Dictionary):
			made_by[StringName(id)] = r.id
	var taken: Dictionary = {}
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			taken[StringName(o.item)] = kind
	for id: StringName in Items.DEFS:
		if not Gear.is_wearable(id) and not Gear.is_module(id):
			continue
		check(Gear.TIERS.has(Gear.tier(id)), "%s is made, mended or found" % id)
		# Reachable: either a person can make it, or the world holds it.
		check(made_by.has(id) or taken.has(id), "%s can be had in a normal game" % id)
		if Gear.tier(id) == &"found":
			check(not made_by.has(id), "%s is found: it is taken whole, never made" % id)
			check(taken.has(id), "%s comes off the machines' own works" % id)
		# Drawn: a mark in a list and a sketch at size.
		var shape: StringName = UiIcons.style_of(id)[0]
		check(UiIcons.SHAPES.has(shape), "%s has a list mark" % id)
		check(UiSketch.SHAPES.has(shape), "%s has a sketch" % id)
		# Worth wearing: it answers a pressure this game can put on a body, or it
		# grants an ability. (Some answer landscapes still to come: radiation and
		# EM belong to the glass desert and the server fields.)
		var r := Gear.resist_of(id)
		var useful := Gear.ability_of(id) != &""
		for h: Variant in r:
			check(Hazards.IDS.has(StringName(h)), "%s resists %s, which is not a hazard" % [id, h])
			useful = useful or Hazards.IDS.has(StringName(h))
		check(useful, "%s answers something the world does" % id)
	# And every pressure the landscapes here actually declare has an answer you
	# can wear, so no place is a wall.
	for h: StringName in landscape_hazards:
		var answered := false
		for id: StringName in Items.DEFS:
			answered = answered or Gear.resist_of(id).has(h)
		check(answered, "nothing worn answers %s, which a landscape here puts on you" % h)


## A recipe that exists is not a recipe that can be made: every ingredient of
## every piece of gear has to be something the world gives or something else
## makes, all the way down. Unreachable gear is a dead page on the slate.
func test_every_piece_of_gear_can_be_reached_from_a_normal_start() -> void:
	var have := {&"knife": true, &"lamp": true}
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			have[StringName(o.item)] = true
			for b: Variant in (o.get("bonus", []) as Array):
				if b is StringName or b is String:
					have[StringName(b)] = true
	# Make everything that can be made, over and over, until nothing new appears.
	var grew := true
	while grew:
		grew = false
		for r: Dictionary in Recipes.LIST:
			var can := true
			for id: Variant in (r.get("needs", {}) as Dictionary):
				can = can and have.has(StringName(id))
			for id: Variant in (r.get("keeps", {}) as Dictionary):
				can = can and have.has(StringName(id))
			if not can:
				continue
			for id: Variant in (r.get("makes", {}) as Dictionary):
				if not have.has(StringName(id)):
					have[StringName(id)] = true
					grew = true
	for id: StringName in Items.DEFS:
		if Gear.is_wearable(id) or Gear.is_module(id):
			check(have.has(id), "%s cannot be reached from a normal start" % id)
	check(have.has(&"wick"), "a found charge can be had, or found tech is dead weight")


func test_every_slot_has_something_to_put_in_it() -> void:
	for slot in Gear.SLOTS:
		if slot == Gear.HAND_SLOT or slot == &"craft":
			continue
		gt(float(Gear.wearables_for(slot).size()), 0.0, "%s has gear made for it" % slot)
	# Every module fits somewhere real.
	for id: StringName in Items.DEFS:
		if not Gear.is_module(id):
			continue
		var fits := 0
		for slot in Gear.SLOTS:
			fits += 1 if Gear.fits(id, slot) else 0
		gt(float(fits), 0.0, "%s fits a slot that exists" % id)


func test_the_three_idioms_are_told_apart_by_the_data_and_by_the_slate() -> void:
	check(Gear.is_mended(&"glide_wing"), "a wing of plate bound to a frame is mended")
	check(not Gear.is_mended(&"wrap_warm"), "a wrap is made")
	check(not Gear.is_mended(&"shield_plate"), "a plate cut whole off a machine is found")
	eq(Gear.tier(&"shield_plate"), &"found")
	eq(Gear.tier(&"knife"), &"made", "anything with no tier of its own is made")
	eq(Gear.tier(&"las_hand"), &"found", "unless it is machine tech")
	# A mended thing is drawn in both palettes at once (docs/ART.md §10).
	var cols := UiIcons.colours_for(&"glide_wing")
	check(UiTheme.MACHINE.has(cols["3"]), "its plate is the stolen module's violet")
	check(UiTheme.PHOSPHOR.has(cols["5"]), "its cord is phosphor")
	var made := UiIcons.colours_for(&"wrap_warm")
	for v: Color in made.values():
		check(UiTheme.PHOSPHOR.has(v), "a made thing is all phosphor")
	var found := UiIcons.colours_for(&"shield_plate")
	for v: Color in found.values():
		check(UiTheme.MACHINE.has(v), "a found thing is all violet")
