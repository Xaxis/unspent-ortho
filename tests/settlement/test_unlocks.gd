extends TestCase
## THE BUILD LIST GROWS BY WHAT YOU END (SETTLE.md S5). A piece may ask for one
## of a set of rewards on top of its cost (StructureKind row `needs_one`): the
## STOLEN CELL, the loudest piece in the game, is powered by a keeper's core,
## any keeper's. Without one the slate says what would unlock it, not "short";
## the core goes into the cell and is not given back by salvage or taken by
## mending; and the cell is what makes a holding truly loud.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_stolen_cell_wants_a_keepers_core_and_says_so() -> void:
	check(StructureKind.buildable(StructureKind.STOLEN_CELL), "a stolen cell can be put up")
	var inv := Inventory.new()
	inv.add(&"scrap", 4)
	inv.add(&"copper", 4)
	var why := SettlementBuild.why_not(inv, StructureKind.STOLEN_CELL)
	eq(why, SettlementBuild.NEEDS_CORE_LINE, "without a core it says what would power it")
	inv.add(&"plumb_core", 1)
	eq(SettlementBuild.why_not(inv, StructureKind.STOLEN_CELL), "", "any keeper's core will do")
	check(SettlementBuild.take_cost(inv, StructureKind.STOLEN_CELL), "and it is paid")
	eq(inv.count(&"plumb_core"), 0, "the core went into it")
	check(not StructureKind.cost(StructureKind.STOLEN_CELL).has(&"plumb_core"), "and is not part of what mending or salvage deal in")


func test_it_is_the_loudest_thing_a_holding_can_stand_up() -> void:
	gt(float(StructureKind.signs(StructureKind.STOLEN_CELL).get("found_tech", 0.0)),
		float(StructureKind.signs(StructureKind.TURRET).get("found_tech", 0.0)), "louder in found tech than a turret")
	gt(float(StructureKind.row(StructureKind.STOLEN_CELL).get("power", 0.0)), float(StructureKind.row(StructureKind.SOLAR_ARRAY).get("power", 0.0)), "and more power than an array, day and night")


func test_any_keepers_core_powers_it() -> void:
	for def: SentinelDef in Sentinels.all():
		check(StructureKind.needs_one(StructureKind.STOLEN_CELL).has(def.core),
			"%s's core powers a stolen cell" % def.id)
