extends TestCase
## MENDED GEAR (slice 3 step 5): living on what the machines leave. The bench
## plate is spent by the blows it turns; spent, it turns nothing. Mended at the
## bench from scrap it turns again, and patched with a harvester's iron it is the
## mended plate, which turns more and wears slower.

const F := preload("res://tests/fight/fixture.gd")


## A sim with the hero wearing `plate` (as a player does, in the bag and worn).
func _plated(plate: StringName) -> FightSim:
	var sim := F.make_sim()
	sim.hero.inventory.add(plate)
	check(sim.hero.inventory.wear_kit(plate), "%s worn" % plate)
	sim.hero.read_body()
	sim.hero.health = 1000
	sim._begin()
	return sim


## Blows of three from a hunter until the plate turns nothing, or `cap`. Returns
## [blows it turned any of, points it turned in all].
func _until_spent(sim: FightSim, cap: int = 400) -> Array[int]:
	var m := F.still(sim, &"longlegs", sim.hero.pos + Vector2(3.0, 0.0), PI)
	var turned_blows := 0
	var turned := 0
	var quiet := 0
	for i in cap:
		var before := sim.hero.health
		sim._hurt_hero(m, 3, Vector2.RIGHT, 0.0, 0)
		sim.now += 2000.0
		var off := 3 - (before - sim.hero.health)
		turned += off
		if off > 0:
			turned_blows += 1
			quiet = 0
		else:
			quiet += 1
			# Fractions are carried: a quarter plate turns one blow in four.
			if quiet >= 8:
				break
	return [turned_blows, turned]


func test_the_plate_is_spent_by_the_blows_it_turns_and_then_turns_none() -> void:
	var sim := _plated(&"kit_plate")
	var inv := sim.hero.inventory
	eq(inv.edge(&"kit_plate"), 10000, "new plate is whole")
	var got := _until_spent(sim)
	gt(float(got[1]), 0.0, "it turned blows while it held")
	eq(inv.edge(&"kit_plate"), 0, "and it is spent")
	var spent := F.count(sim.drain(), &"plate_spent")
	eq(spent, 1, "said once as it goes")
	var m := F.still(sim, &"longlegs", sim.hero.pos + Vector2(3.0, 0.0), PI)
	var before := sim.hero.health
	for i in 4:
		sim._hurt_hero(m, 3, Vector2.RIGHT, 0.0, 0)
		sim.now += 2000.0
	eq(before - sim.hero.health, 12, "spent, it turns nothing")


func test_scrap_at_the_bench_mends_it() -> void:
	var sim := _plated(&"kit_plate")
	var inv := sim.hero.inventory
	@warning_ignore("return_value_discarded")
	_until_spent(sim)
	var r := Crafting.recipe(&"mend_plate")
	check(not r.is_empty(), "there is a way to mend it")
	eq(r.get("at", &""), &"bench", "at the bench")
	check(not Crafting.can_make(inv, r), "not from nothing")
	inv.add(&"scrap", 2)
	inv.add(&"rag", 1)
	check(Crafting.can_make(inv, r), "from what the machines leave")
	check(Crafting.make(inv, r), "mended")
	eq(inv.edge(&"kit_plate"), 10000, "whole again")
	check(not inv.has(&"scrap"), "the scrap went into it")
	var again := _until_spent(sim)
	gt(float(again[1]), 0.0, "and it turns blows again")


func test_the_mended_plate_turns_more_and_lasts_longer() -> void:
	var inv := Inventory.new()
	inv.add(&"kit_plate")
	inv.add(&"tide_iron")
	inv.add(&"scrap", 2)
	var r := Crafting.recipe(&"plate_mended")
	check(Crafting.can_make(inv, r), "the plate patched with a harvester's iron")
	check(Crafting.make(inv, r), "made")
	check(inv.has(&"plate_mended") and not inv.has(&"kit_plate"), "the plate became the mended plate")
	eq(Gear.tier(&"plate_mended"), &"mended", "and it is the mended tier")
	var base := _until_spent(_plated(&"kit_plate"))
	var mended := _until_spent(_plated(&"plate_mended"))
	gt(float(mended[1]), float(base[1]) * 2.0, "it turns more, for longer (%d against %d points)" % [mended[1], base[1]])
