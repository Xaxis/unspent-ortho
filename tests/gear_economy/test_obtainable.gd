extends TestCase
## The other pinned promise: **every piece is obtainable by a path a player can
## actually walk**, and **an elite material comes only from the landscape or the
## enemy it was declared for** (docs/VISION.md §6.1).
##
## This is the test the brief asked for by name: it does not read a flag saying a
## thing is reachable, it walks the sources — a prop that stands in that
## landscape, a machine kind that spawns there, a recipe whose every input walks
## back the same way — and fails with the path it could not finish.


func _declared() -> void:
	GearEconomy.declare(true)
	Sources.clear()


func test_the_economy_has_nothing_wrong_with_it() -> void:
	_declared()
	var said := GearEconomy.problems()
	check(said.is_empty(), "\n  ".join(said))


func test_every_elite_material_has_exactly_one_source() -> void:
	_declared()
	for id: StringName in EliteStock.ids():
		var lands: Array = Materials.lands(id)
		var kinds: Array = Materials.sources(id)
		check(lands.size() + kinds.size() == 1,
			"%s is declared in %d landscapes and %d machines; VISION §6.1 allows one gate"
			% [id, lands.size(), kinds.size()])
		# And the contract agrees: it can come from there and from nowhere else.
		for land: StringName in Sources.lands():
			var expected := lands.has(land)
			eq(Materials.can_come_from(id, land), expected,
				"%s in the %s should be %s" % [id, land, expected])


## A landscape's own material is gated by a RAW only that landscape gives. This
## walks that claim: the raw is takeable there, and either no more than two
## landscapes hold the prop it comes off, or the take is gated on ground that only
## that landscape lays (which is how the snowfield keeps its crottle).
func test_a_landscapes_own_material_is_really_only_that_landscapes() -> void:
	_declared()
	for id: StringName in EliteStock.ids():
		var land := EliteStock.land_of(id)
		if land == &"":
			continue
		var raw := StringName(EliteStock.material(id).get("raw", &""))
		var where := Sources.lands_yielding(raw)
		check(where.has(land), "%s is refined from %s and the %s does not give it" % [id, raw, land])
		if where.size() <= 2:
			continue
		var ground: Array = Sources.option_yielding(raw).get("ground", [])
		check(not ground.is_empty(),
			"%s is refined from %s, which %d landscapes give and nothing gates: %s"
			% [id, raw, where.size(), where])


func test_a_machines_own_material_comes_off_a_machine_that_is_really_out_there() -> void:
	_declared()
	for id: StringName in EliteStock.ids():
		var kind := EliteStock.kind_of(id)
		if kind == &"":
			continue
		check(Roster.has(kind), "%s is cut out of %s, which is not in the roster" % [id, kind])
		var lands := Sources.lands_of_kind(kind)
		gt(float(lands.size()), 0.0, "%s spawns in a landscape a player can reach" % kind)
		# One kind, and no other kind, gives it up.
		var givers: Array = Drops.sources_of(id)
		eq(givers.size(), 1, "%s is given up by %s; one kind only" % [id, givers])


## Killing them has to actually hand it over. A chance nobody ever wins is not a
## path: this walks the deterministic rolls and counts.
func test_a_run_of_kills_really_hands_the_part_over() -> void:
	_declared()
	for seed_value: int in [1, 7, 12345]:
		for id: StringName in EliteStock.ids():
			if EliteStock.kind_of(id) == &"":
				continue
			var n := GearEconomy.kills_for(id, seed_value, 40)
			gt(float(n), 0.0, "%s never comes off a %s on seed %d"
				% [id, EliteStock.kind_of(id), seed_value])
			lt(float(n), 25.0, "%s took %d kills on seed %d, which is a grind not a gate"
				% [id, n, seed_value])


## Found while measuring the tour. `Drops.roll` salts its rolls by the ROW, not by
## the table, so a bare count of kills made every kind agree: the second harvester
## and the second warden both gave up their part, the third gave up part and
## weapon, the fourth gave nothing. A player would have learned "every other one"
## instead of learning the bodies, which is the opposite of what an economy gated
## on WHICH machine you beat is for. `GearEconomy.instance_of` mixes the kind in.
func test_each_kind_keeps_its_own_run_of_luck() -> void:
	_declared()
	for seed_value: int in [1, 7]:
		var firsts: Dictionary = {}
		for id: StringName in EliteStock.ids():
			if EliteStock.kind_of(id) == &"":
				continue
			firsts[GearEconomy.kills_for(id, seed_value, 40)] = true
		gt(float(firsts.size()), 1.0,
			"on seed %d every kind gives its part up on the same kill: %s" % [seed_value, firsts.keys()])


func test_every_piece_in_the_tree_can_be_walked_back_to_the_world() -> void:
	_declared()
	var owned_up: Array[StringName] = []
	for id: StringName in GearTree.ids():
		if String(GearTree.row(id).get("no_source", "")) != "":
			owned_up.append(id)
			continue
		check(Sources.reachable(id), "nothing leads to %s" % id)
		# And the path says something a person could follow.
		var said := Sources.said(id)
		check(said.length() > 8 and not said.contains("no way to it"), "%s: %s" % [id, said])
	# A row may only say it has no source if that is STILL TRUE, and only one may:
	# the pre-existing works axe. Anything else hiding behind the same note is a
	# piece somebody gave up on.
	eq(owned_up.size(), 1, "one piece in the game has no way to it: %s" % [owned_up])
	for id in owned_up:
		check(not Sources.reachable(id),
			"%s says nothing leads to it and something now does; take the note off" % id)


func test_every_elite_material_can_be_walked_back_too() -> void:
	_declared()
	for id: StringName in EliteStock.ids():
		check(Sources.reachable(id), "nothing leads to %s: %s" % [id, Sources.said(id)])


## Difficulty is the station, and it rises with the grade (VISION §6.1: "Craft
## difficulty matches the ladder"). The top rung is a bench with the machines' own
## jig kept in hand, which is itself cut off a machine.
func test_craft_difficulty_rises_with_the_grade() -> void:
	_declared()
	for id: StringName in GearTree.ids():
		if Gear.tier(id) != &"mended":
			continue
		var made := Sources.recipes_making(id)
		gt(float(made.size()), 0.0, "%s is mended and nothing makes it" % id)
		var tier := CraftTiers.of_recipe(made[0])
		match GearTree.grade(id):
			Rarity.UNCOMMON: check(tier >= CraftTiers.BENCH, "%s wants a bench at least" % id)
			Rarity.RARE: check(tier >= CraftTiers.BENCH, "%s wants a bench at least" % id)
			Rarity.PRIME, Rarity.RELIC:
				eq(tier, CraftTiers.JIG, "%s is %s and belongs on their own jig"
					% [id, Rarity.name_of(GearTree.grade(id))])
	# The jig is not something a person builds: it comes off a machine.
	check(EliteStock.kind_of(CraftTiers.JIG_TOOL) != &"", "the jig is taken, not made")
	check(Sources.recipes_making(CraftTiers.JIG_TOOL).is_empty(), "and it is never made")


func test_what_the_economy_gives_without_a_recipe_is_only_ever_real() -> void:
	_declared()
	var ids := GearEconomy.without_making()
	gt(float(ids.size()), 0.0, "a kill gives something")
	for id in ids:
		check(not Items.def(id).is_empty(), "%s is not an item" % id)
		var givers: Array = Drops.sources_of(id)
		gt(float(givers.size()), 0.0, "%s is claimed and nothing gives it" % id)
		for kind: StringName in givers:
			check(Roster.has(kind), "%s is claimed off %s, which does not exist" % [id, kind])
	check(not ids.has(CraftTiers.SPOIL_ITEM), "ruined stock is not a prize")


## What a landscape holds of its own, which is what the long game is made of: at
## least half the landscapes have something a player can only get by going there.
func test_landscapes_have_something_of_their_own_to_go_for() -> void:
	_declared()
	var with_something := 0
	var lands := Sources.lands()
	for land: StringName in lands:
		var here := GearEconomy.here(land)
		if not (here["own"] as Array).is_empty() or not (here["parts"] as Array).is_empty():
			with_something += 1
	gt(float(with_something), float(lands.size()) * 0.5,
		"%d of %d landscapes hold an elite material or a machine that gives one"
		% [with_something, lands.size()])
