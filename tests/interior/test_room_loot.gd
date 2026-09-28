extends TestCase
## WHAT A ROOM HOLDS (docs/GEAR.md §7, G6). A room is lived in exactly when its
## recipe seats people (a household, or squatters: `SEATS`, InteriorKind.seats);
## every other room is the machines' or nobody's, and what it holds is in a
## strongbox. What a lived-in room holds is on its kept-by shelf, and is theirs.
## Every kind has a row of what it holds (Interiors.LOOT).

const LIVED: Array[StringName] = [&"cottage", &"home", &"stilt_room", &"hulk_hold", &"tower_lobby",
	&"cliff_room", &"rooted_floor", &"tenement", &"roundhouse", &"squat", &"face_hold"]
const UNLIVED: Array[StringName] = [&"weapons_hall", &"foundry", &"data_hall", &"saw_hall",
	&"maintenance_bay", &"laid_table", &"bunker", &"frozen_hold", &"container_warren"]


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
			# The people who live there (a DWELLER, 21_doors) are no machine.
			var machines := 0
			for r: Dictionary in lay(k, s).residents:
				if r.role != &"dweller":
					machines += 1
			eq(machines, 0, "%s: nobody lives with a machine at its post" % id)


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


## Every lived-in room has its kept-by shelf, one of its own pieces (the
## recipe's `KEPT_BY`). Stood at it, `use` is the shelf's; stood at any story slot
## beside it, the slot's, so no words go unread for a shelf.
func test_a_lived_in_room_has_a_kept_by_shelf_and_every_slot_still_reads() -> void:
	for id: StringName in LIVED:
		var k := Interiors.kind(id)
		check(not k.kept_by.is_empty(), "%s names its shelf" % id)
		for s in 12:
			var l := lay(k, s)
			var i := KeptBy.shelf(l, k)
			check(i >= 0, "%s (%d): its shelf is in the room" % [id, s])
			if i < 0:
				continue
			var th: Dictionary = l.things[i]
			check(KeptBy.at_hand(l, k, (th.at as Vector2) + (th.face as Vector2) * 0.7), "%s (%d): stood at its %s, it is at hand" % [id, s, th.kind])
			for slot: Dictionary in l.slots:
				var before := (slot.at as Vector2) + (slot.face as Vector2) * 0.6
				check(not KeptBy.at_hand(l, k, before), "%s (%d): stood at its %s slot, the words are read" % [id, s, slot.slot])
	for id: StringName in UNLIVED:
		eq(KeptBy.shelf(lay(Interiors.kind(id), 0), Interiors.kind(id)), -1, "%s keeps nothing for anybody" % id)


## On good terms: the region has thanked the player for something it asked and he
## did (StorySubarc, Story.heard "REGION:goal:said"). Asked is not enough, and one
## region's thanks are not another's.
func test_good_terms_are_a_regions_thanks() -> void:
	Story.forget()
	check(not KeptBy.on_terms(5), "a stranger")
	Story.hear(&"5:recover")
	check(not KeptBy.on_terms(5), "asked is not thanked")
	Story.hear(&"5:recover:said")
	check(KeptBy.on_terms(5), "thanked for what he did")
	check(not KeptBy.on_terms(6), "and only there")
	check(not KeptBy.on_terms(-1), "nowhere is nobody's")
	Story.forget()


func test_what_a_shelf_says_is_by_line_id() -> void:
	for line: StringName in [KeptBy.THEIRS, KeptBy.GIVEN, KeptBy.GAVE]:
		check(str(StoryContent.KEPT_BY.get(line, "")) != "", "%s has words" % line)
