extends TestCase
## The economy inside a real running game: a machine that goes down hands over the
## part it was carrying, a hard pour can come out wrong, the gear page says what a
## modifier decides, prising a panel out on the road can cost it, and all of it
## comes back through a save.

var game: Game


func _boot(extra: PackedStringArray = PackedStringArray()) -> Node:
	var args := PackedStringArray(["--seed=1", "--size=48", "--hour=12"])
	args.append_array(extra)
	game = Game.new()
	tree.root.add_child(game)
	game.setup(BootOptions.parse(args))
	return _system("56_economy")


func _system(part: String) -> Node:
	for s in game.systems:
		if String(s.name).contains(part):
			return s
	return null


func test_the_economy_is_declared_before_anything_reads_it() -> void:
	Materials.clear()
	Drops.clear()
	var sys := _boot()
	check(sys != null, "56_economy loaded")
	gt(float(Materials.known().size()), 10.0, "the materials are declared")
	gt(float(Drops.sources().size()), 5.0, "and what each machine gives up")
	check(Materials.can_come_from(&"tide_iron", &"", &"harvester"), "a harvester keeps its tide iron")
	game.free()


func test_a_machine_that_goes_down_hands_over_what_it_was_carrying() -> void:
	var sys := _boot()
	var at := game.world.to_3d(game.player.pos)
	var got := false
	# The roll is deterministic per kill, so this puts a run of them down the way a
	# player would and asks that the part comes out inside that run.
	for i in 30:
		Events.killed.emit(&"harvester", at)
		if game.inventory.count(&"tide_iron") > 0:
			got = true
			break
	check(got, "a run of harvesters gives up tide iron")
	check(sys.call("tour_seen", &"spoils"), "and a tour can see it happened")
	check(sys.call("tour_seen", &"elite:tide_iron"))
	game.free()


func test_a_body_that_went_down_across_the_island_is_not_in_your_hands() -> void:
	var sys := _boot()
	var far := game.world.to_3d(game.player.pos + Vector2(200, 200))
	for i in 30:
		Events.killed.emit(&"harvester", far)
	eq(game.inventory.count(&"tide_iron"), 0, "it was not your fight")
	check(not sys.call("tour_seen", &"spoils"))
	game.free()


func test_the_plate_a_machine_drops_is_still_the_fights_to_give() -> void:
	# The roster's `drops` is spent by 40_fight; nothing here may double it.
	_boot()
	for kind: StringName in EliteStock.kinds():
		check(not Drops.can_yield(kind).has(&"scrap"),
			"%s's plate is the roster's to give, not the economy's" % kind)
	game.free()


func test_a_hard_pour_can_come_out_wrong_and_leaves_something_behind() -> void:
	var sys := _boot()
	var spoiled := 0
	var flawed := 0
	for i in 60:
		game.inventory.add(&"blade_seal")
		Events.made.emit(&"blade_seal", 1)
		if game.inventory.count(&"blade_seal") == 0:
			if game.inventory.count(&"blade_die") > 0:
				flawed += 1
				game.inventory.remove(&"blade_die")
			else:
				spoiled += 1
		else:
			game.inventory.remove(&"blade_seal")
	gt(float(spoiled + flawed), 0.0, "the top rung has teeth")
	lt(float(spoiled + flawed), 60.0 * 0.6, "and it is not mostly teeth")
	gt(float(flawed), 0.0, "and some of them come out flawed but usable")
	gt(float(game.inventory.count(&"spoil")), 0.0, "a ruined pour still leaves stock")
	check(sys.call("tour_seen", &"spoiled"))
	game.free()


func test_an_ordinary_craft_is_exactly_what_it_always_was() -> void:
	# The kiln already made cemented steel long before the economy existed, and
	# nothing this package added may quietly put a risk on it.
	_boot()
	for i in 40:
		game.inventory.add(&"knife_shear")
		Events.made.emit(&"knife_shear", 1)
		eq(game.inventory.count(&"knife_shear"), 1, "a cemented knife is never spoiled")
		game.inventory.remove(&"knife_shear")
	eq(game.inventory.count(&"spoil"), 0)
	game.free()


func test_the_gear_page_says_what_a_modifier_decides() -> void:
	_boot(["--fit=vest_heatsink,mod_cooling"])
	var feed := SlateFeeds.feed(&"loadout", game)
	var said := ""
	for row: Dictionary in (feed.get("slots", []) as Array):
		for m: Dictionary in (row.get("modules", []) as Array):
			if StringName(m.get("id", &"")) == &"mod_cooling":
				said = String(m.get("grants", ""))
	check(said.contains("heat"), "the page says what the loop is for, not its percentage: '%s'" % said)
	game.free()


func test_the_page_says_when_two_parts_are_fighting() -> void:
	var sys := _boot(["--fit=knife_mono,mod_lattice,mod_damp"])
	var l: Loadout = _system("54_gear").get("loadout")
	check(l.modules(Gear.HAND_SLOT).has(&"mod_lattice"), "the lattice is on the haft")
	var said := ""
	var feed := SlateFeeds.feed(&"loadout", game)
	for row: Dictionary in (feed.get("slots", []) as Array):
		for m: Dictionary in (row.get("modules", []) as Array):
			if StringName(m.get("id", &"")) == &"mod_lattice":
				said = String(m.get("grants", ""))
	check(said.contains("!"), "a conflict is marked on the row: '%s'" % said)
	check(sys.call("tour_seen", &"conflict"), "and a tour can see it")
	game.free()


func test_a_panel_prised_out_on_the_road_can_break() -> void:
	_boot(["--give=vest_heatsink:1,mod_cooling:60"])
	var gear := _system("54_gear")
	var l: Loadout = gear.get("loadout")
	check(not Survival.stations_near(game).has(&"bench"),
		"this spawn stands at a bench, so the field rule cannot be read here")
	var broke := 0
	for i in 50:
		l.fit(&"body", &"vest_heatsink")
		check(l.socket(&"body", &"mod_cooling"), "the loop goes in")
		var before := game.inventory.count(&"mod_cooling")
		gear.call("_pull_modules", &"body")
		l.clear_slot(&"body")
		if game.inventory.count(&"mod_cooling") < before:
			broke += 1
	gt(float(broke), 0.0, "a drilled loop can come away in pieces out in the field")
	lt(float(broke), 50.0 * 0.6, "and mostly it survives")
	game.free()


func test_the_counts_the_rolls_ride_on_come_back_through_a_save() -> void:
	var sys := _boot()
	var at := game.world.to_3d(game.player.pos)
	for i in 5:
		Events.killed.emit(&"lineman", at)
	var saved: Variant = JSON.parse_string(JSON.stringify(sys.call("_save")))
	check(SaveGame.registered(&"economy"), "the system registered its key")
	game.free()
	sys = _boot()
	sys.call("_load", saved)
	eq(int(sys.get("_kills")), 5, "the kill count came back, so nothing is rerolled by loading")
	game.free()
