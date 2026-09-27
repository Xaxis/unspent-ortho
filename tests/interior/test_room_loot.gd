extends TestCase
## WHAT A ROOM HOLDS (docs/GEAR.md §7, G6). A room is lived in exactly when its
## recipe seats people (a household, or squatters: `SEATS`, InteriorKind.seats);
## every other room is the machines' or nobody's, and what it holds is in a
## strongbox. What a lived-in room holds is on its kept-by shelf, and is theirs.
## Every kind has a row of what it holds (Interiors.LOOT).

const LIVED: Array[StringName] = [&"cottage", &"home", &"stilt_room", &"hulk_hold", &"tower_lobby",
	&"cliff_room", &"rooted_floor", &"tenement", &"roundhouse", &"squat"]
const UNLIVED: Array[StringName] = [&"weapons_hall", &"foundry", &"data_hall", &"saw_hall",
	&"maintenance_bay", &"laid_table", &"bunker", &"frozen_hold"]


static func lay(k: InteriorKind, s: int) -> InteriorLayout:
	var rng := Rng.make(s, 0x6060)
	return k.recipe.call(&"lay", rng, -1) if k.by_land else k.recipe.call(&"lay", rng)


func test_a_room_is_lived_in_only_where_its_recipe_seats_people() -> void:
	eq(LIVED.size() + UNLIVED.size(), Interiors.RECIPES.size(), "every kind is named here once")
	for id: StringName in LIVED:
		check(Interiors.kind(id).lived(), "%s is lived in" % id)
	for id: StringName in UNLIVED:
		check(not Interiors.kind(id).lived(), "%s is nobody's home" % id)
	for id: StringName in Interiors.RECIPES:
		var k := Interiors.kind(id)
		check(k.seats in [&"", &"household", &"squatters"], "%s seats what a room can (%s)" % [id, k.seats])
		if not k.lived():
			continue
		for s in 4:
			eq(lay(k, s).residents.size(), 0, "%s: nobody lives with a machine at its post" % id)


func test_every_room_has_what_it_holds() -> void:
	for id: StringName in Interiors.RECIPES:
		check(Interiors.LOOT.has(id), "%s has a row of what it holds" % id)
		for row: Dictionary in Interiors.LOOT.get(id, []):
			check(not Items.def(row.item).is_empty(), "%s holds %s, an item" % [id, row.item])
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


func test_a_room_nobody_lives_in_keeps_what_it_holds_in_a_strongbox() -> void:
	for id: StringName in UNLIVED:
		var k := Interiors.kind(id)
		for s in 4:
			var boxes := 0
			for th: Dictionary in lay(k, s).things:
				boxes += int(th.kind == &"strongbox")
			gt(float(boxes), 0.0, "%s (%d): a strongbox" % [id, s])
