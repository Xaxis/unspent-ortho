extends TestCase
## The seam every package that puts something in the player's hands writes to
## (docs/VISION.md). These tests pin the two promises the economy rests on:
## a grade buys options rather than raw power, and an elite material exists where
## it was declared to and nowhere else.


## The runner has no setup hook, so a test that declares starts by clearing.
func _fresh() -> void:
	Materials.clear()
	Drops.clear()


func test_a_grade_buys_modifiers_not_damage() -> void:
	eq(Rarity.slots(Rarity.COMMON), 0, "a common piece is the thing itself")
	eq(Rarity.slots(Rarity.RARE), 2, "rare carries two")
	eq(Rarity.slots(Rarity.RELIC), 3, "a relic carries three sockets")
	check(Rarity.unique(Rarity.RELIC), "and one thing only it does")
	check(not Rarity.unique(Rarity.PRIME), "which a prime does not")
	check(Rarity.ordinary(Rarity.UNCOMMON), "uncommon turns up anywhere")
	check(not Rarity.ordinary(Rarity.RARE), "rare wants a place worth walking to")
	eq(Rarity.of_name(Rarity.name_of(Rarity.PRIME)), Rarity.PRIME, "a grade survives being written down")


func test_an_elite_material_comes_from_where_it_was_declared_and_nowhere_else() -> void:
	_fresh()
	Materials.declare(&"tide_iron", {"lands": [&"coast"], "what": "pitted and rust-bled"})
	Materials.declare(&"sentinel_core", {"sources": [&"sentinel_coast"], "rarity": Rarity.RELIC})
	check(Materials.can_come_from(&"tide_iron", &"coast"), "the coast has its iron")
	check(not Materials.can_come_from(&"tide_iron", &"snowfield"), "the snowfield does not")
	check(Materials.can_come_from(&"sentinel_core", &"", &"sentinel_coast"), "a keeper gives up its core")
	check(not Materials.can_come_from(&"sentinel_core", &"coast"), "and walking the coast does not")
	check(not Materials.can_come_from(&"nothing_at_all", &"coast"), "a material nobody declared comes from nowhere")
	eq(Materials.in_land(&"coast"), [&"tide_iron"], "a slate can say what a landscape holds")


func test_a_material_that_comes_from_nowhere_is_a_mistake() -> void:
	_fresh()
	Materials.declare(&"orphan", {})
	Materials.declare(&"misplaced", {"lands": [&"atlantis"]})
	var said := "; ".join(Materials.problems([&"coast", &"snowfield"]))
	check(said.contains("orphan"), "a material with no source is named: %s" % said)
	check(said.contains("atlantis"), "so is one that names a landscape nobody built: %s" % said)


func test_the_same_kill_on_the_same_seed_always_gives_the_same_things() -> void:
	_fresh()
	Drops.declare(&"harvester", [
		{"item": &"plate", "count": Vector2i(2, 5)},
		{"item": &"lens", "chance": 0.5},
	])
	var a := Drops.roll(&"harvester", 7, 31)
	var b := Drops.roll(&"harvester", 7, 31)
	eq(JSON.stringify(a), JSON.stringify(b), "loading the game again does not reroll it")
	var other := Drops.roll(&"harvester", 7, 32)
	check(JSON.stringify(a) != JSON.stringify(other) or a.is_empty(), "the next machine is its own")
	for got: Dictionary in a:
		if got.item == &"plate":
			check(int(got.count) >= 2 and int(got.count) <= 5, "a count stays inside what was declared")


func test_a_thing_yields_only_what_belongs_where_it_stands() -> void:
	_fresh()
	Drops.declare(&"wreck", [
		{"item": &"plate"},
		{"item": &"fulgurite", "only_in": [&"salt_flats"]},
	])
	var on_the_coast := Drops.can_yield_here(&"wreck", &"coast")
	var on_the_flats := Drops.can_yield_here(&"wreck", &"salt_flats")
	check(not on_the_coast.has(&"fulgurite"), "the coast's wrecks hold no lightning glass")
	check(on_the_flats.has(&"fulgurite"), "the flats' wrecks do")


func test_what_a_source_is_worth_breaking_can_be_asked() -> void:
	_fresh()
	Drops.declare(&"sentinel_coast", [{"item": &"sentinel_core", "rarity": Rarity.RELIC}])
	Drops.declare(&"depot", [{"item": &"sentinel_core", "chance": 0.05}])
	check(Drops.can_yield(&"sentinel_coast").has(&"sentinel_core"), "a keeper's core is on its table")
	eq(Drops.sources_of(&"sentinel_core").size(), 2, "and both ways to it can be found")
