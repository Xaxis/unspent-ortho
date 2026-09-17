extends TestCase
## What a landmark gives, and the promises it keeps about it (docs/VISION.md
## §6.1). ONE economy: every table is declared through `src/core/loot`, nothing
## is invented here, and a landscape's own elite material only ever comes out of
## a place standing in that landscape.

const SIZE := 256


func _site(kind: StringName, land: StringName, nth: int = 1) -> LandmarkSite:
	var s := LandmarkSite.new()
	s.kind = kind
	s.land = land
	s.region = 3
	s.nth = nth
	s.pos = Vector2(60 + nth * 11, 80)
	s.id = StringName("%s#%d" % [kind, nth])
	return s


func test_every_kind_is_worth_walking_to() -> void:
	Landmarks.declare_loot()
	for d: LandmarkDef in Landmarks.all():
		var rows := Drops.table(d.drops)
		check(not rows.is_empty(), "%s has a table" % d.id)
		gt(float(Drops.can_yield(d.drops).size()), 1.0, "%s holds more than one thing" % d.id)
		for row: Dictionary in rows:
			var id: StringName = row.get("item", &"")
			check(not Items.def(id).is_empty(), "%s promises %s, which nothing in the game is" % [d.id, id])


func test_what_a_place_holds_is_the_same_every_time_it_is_opened() -> void:
	Landmarks.declare_loot()
	var s := _site(&"lighthouse", &"coast")
	var a := Landmarks.loot(s, 4242)
	var b := Landmarks.loot(s, 4242)
	eq(str(b), str(a), "the same seed and the same place give the same things")
	check(not a.is_empty(), "and there is something in it")
	# Another world does not hold the same cache.
	var other := Landmarks.loot(s, 9999)
	var second := Landmarks.loot(_site(&"lighthouse", &"coast", 2), 4242)
	check(str(other) != str(a) or str(second) != str(a),
		"two different places, or two different seeds, are not one cache copied")


func test_a_landscapes_own_elite_only_comes_out_of_that_landscape() -> void:
	Landmarks.declare_loot()
	for d: LandmarkDef in Landmarks.all():
		for land: StringName in d.lands:
			for id: StringName in Drops.can_yield_here(d.drops, land):
				if Materials.where(id).is_empty():
					continue
				check(Materials.can_come_from(id, land, d.drops),
					"%s in the %s gives %s, which is not declared as coming from there" % [d.id, land, id])


## The whole promise of an elite material is that the same kind of place gives
## something different in each landscape it stands in — which is what makes the
## second one worth the walk.
func test_the_same_kind_of_place_holds_different_things_in_different_landscapes() -> void:
	Landmarks.declare_loot()
	var differs := 0
	for d: LandmarkDef in Landmarks.all():
		if d.lands.size() < 2:
			continue
		var first := str(Drops.can_yield_here(d.drops, d.lands[0]))
		for i in range(1, d.lands.size()):
			if str(Drops.can_yield_here(d.drops, d.lands[i])) != first:
				differs += 1
				break
	gt(float(differs), 1.0, "more than one kind pays a landscape's own way")


func test_what_has_been_found_and_opened_survives_a_save() -> void:
	var st := LandmarkState.new()
	check(st.find(&"lighthouse#1"), "finding one is news the first time")
	check(not st.find(&"lighthouse#1"), "and never again")
	check(st.open(&"firewatch#2"), "opening one is news the first time")
	check(not st.open(&"firewatch#2"), "and a cache cannot be emptied twice")
	check(st.is_found(&"firewatch#2"), "what has been opened has plainly been found")
	var back := LandmarkState.new()
	back.load_from(JSON.parse_string(JSON.stringify(st.save())))
	check(back.is_found(&"lighthouse#1"), "a place found stays on the map through a save")
	check(back.is_opened(&"firewatch#2"), "and an emptied cache stays empty")
	check(not back.is_opened(&"lighthouse#1"), "and one that was only found is still full")


## A player cannot reroll a cache by loading: the roll is a function of the seed
## and the site, so a save reloaded a hundred times gives the same thing.
func test_a_cache_cannot_be_rerolled_by_loading() -> void:
	Landmarks.declare_loot()
	var w := WorldGen.generate(5, SIZE)
	var sites := Landmarks.sites(w)
	check(not sites.is_empty(), "seed 5 holds somewhere to open")
	for site: LandmarkSite in sites:
		var first := str(Landmarks.loot(site, w.seed_value))
		for i in 5:
			eq(str(Landmarks.loot(site, w.seed_value)), first, "%s gives the same thing every time" % site.id)


## Two places of the same kind in one world are not one cache copied: the
## instance number is in the roll.
func test_two_of_a_kind_in_one_world_are_not_the_same_cache() -> void:
	Landmarks.declare_loot()
	var a := Landmarks.loot(_site(&"grown_hulk", &"moss", 1), 77)
	var b := Landmarks.loot(_site(&"grown_hulk", &"moss", 2), 77)
	check(str(a) != str(b), "the second hulk is its own cache")


## THE FINE AXE, and the seam it needed. `Sources` walks every drop table back
## to the roster body it comes off, so for a whole wave a landmark could hold
## nothing a machine carries: a wick in a lighthouse failed the economy's own
## test rather than being a find, and `axe_works` sat in the gear tree with a
## note saying the landmarks owned it and nothing in the world holding one.
## A table that is OPENED rather than killed now says so, and says where it
## stands, and the walker can answer with the walk.
func test_a_place_is_a_way_to_a_thing_and_the_economy_can_say_the_walk() -> void:
	GearEconomy.declare(true)
	Sources.clear()
	check(Sources.reachable(&"axe_works"), "the one piece that had no way to it: %s"
		% Sources.said(&"axe_works"))
	var steps := Sources.path_to(&"axe_works")
	eq(steps.size(), 1, "it is found, not made: %s" % [steps])
	eq(StringName(steps[0].get("how", &"")), &"open", "and it is opened at a place")
	eq(StringName(steps[0].get("place", &"")), &"landmark_firewatch")
	var said := Sources.said(&"axe_works")
	check(said.contains("firewatch") and not said.contains("no way to it"), said)
	# The landscapes it names are the ones a fire tower really stands in, asked
	# the way the placer asks: a landscape's own file, not the kind's own row.
	var lands: Array[StringName] = steps[0].get("lands", [] as Array[StringName])
	eq(lands, Landmarks.lands_of(&"firewatch"), "the walk names where they stand")
	for land: StringName in lands:
		var kinds := PackedStringArray()
		for d: LandmarkDef in Landmarks.for_land(land):
			kinds.append(String(d.id))
		check(kinds.has("firewatch"), "%s holds no fire tower to find it at" % land)


## And a place is the LAST answer, never the first: taking, killing and making
## are things a player can go and do again, and a cache is opened once. Anything
## with another way to it must still be told that way.
func test_a_cache_is_the_answer_only_for_what_nothing_else_leads_to() -> void:
	GearEconomy.declare(true)
	Sources.clear()
	# The hone lies in a fire tower too, and is made of a stone off any boulder.
	check(Drops.can_yield(&"landmark_firewatch").has(&"hone"), "a tower holds a hone")
	var steps := Sources.path_to(&"hone")
	check(not steps.is_empty(), "the hone has a way to it")
	eq(StringName(steps[steps.size() - 1].get("how", &"")), &"make",
		"a thing a player can make again is not sent to a one-off cache: %s" % Sources.said(&"hone"))
