extends TestCase
## TAKING A PIECE APART AT A BENCH (GEAR.md G7; Reforge.salvage). Every carried
## piece of gear that was made from a recipe can be taken apart at a bench: a
## row on the making page, "take apart the ...", that gives back its elite
## material always and half of the rest. Nothing is dead loot.


func test_a_rare_rung_taken_apart_gives_back_its_elite_material() -> void:
	var inv := Inventory.new()
	inv.add(&"mod_capacitor")
	var rows := Reforge.salvage_recipes(inv)
	var row: Dictionary = {}
	for r: Dictionary in rows:
		if (r.needs as Dictionary).has(&"mod_capacitor"):
			row = r
	check(not row.is_empty(), "a carried capacitor bank can be taken apart")
	eq(StringName(row.get("at", &"")), &"bench", "at a bench")
	check(UiRules.recipe_title(row).begins_with("take apart"), "and says so: %s" % UiRules.recipe_title(row))
	check(Crafting.make(inv, row), "it comes apart")
	eq(inv.count(&"mod_capacitor"), 0, "the piece is gone")
	gt(float(inv.count(GearTree.made_of(&"mod_capacitor"))), 0.0, "and its elite material is back (%s)" % GearTree.made_of(&"mod_capacitor"))


func test_nothing_without_a_recipe_is_offered() -> void:
	var inv := Inventory.new()
	inv.add(&"knife")
	inv.add(&"scrap", 3)
	for r: Dictionary in Reforge.salvage_recipes(inv):
		check(not (r.needs as Dictionary).has(&"scrap"), "a material is not taken apart")
