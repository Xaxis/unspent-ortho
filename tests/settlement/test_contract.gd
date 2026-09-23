extends TestCase
## The seam the settlement and raids packages both write to (docs/VISION.md).
## These tests pin the shape and the two decisions inside it: what a machine
## makes of a place, and what hides it. Change them only with both packages.


func test_a_place_holds_its_pieces_and_finds_them_by_kind_and_family() -> void:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(100, 100), "the yard")
	var hut := s.add(StructureKind.HUT, Vector2(101, 100))
	s.add(StructureKind.PALISADE, Vector2(103, 100))
	s.add(StructureKind.PALISADE, Vector2(104, 100))
	eq(s.pieces.size(), 3, "three pieces standing")
	eq(s.structures_of(StructureKind.PALISADE).size(), 2, "both lengths of palisade")
	eq(s.defences().size(), 2, "the palisade is a defence")
	eq(s.of_family(StructureKind.Family.SHELTER).size(), 1, "the hut is shelter")
	eq(s.piece(hut.id).kind, StructureKind.HUT, "a piece is found by its id")


func test_a_piece_breaks_and_is_mended() -> void:
	var s := Settlement.new(1)
	var wall := s.add(StructureKind.PLATE_WALL, Vector2.ZERO, 10.0)
	check(not s.damage_structure(wall.id, 4.0), "four is not the end of it")
	near(wall.health, 6.0, 1e-4, "it took the blow")
	check(s.damage_structure(wall.id, 6.0), "the blow that ruined it says so")
	check(wall.ruined, "ruined")
	check(not wall.standing(), "and no longer standing")
	wall.repair(10.0)
	check(wall.standing(), "mended, it stands again")
	near(wall.health, 10.0, 1e-4, "back to its full strength, no further")


func test_what_a_machine_makes_of_a_place_is_its_loudest_mistake() -> void:
	var quiet := Settlement.new(1)
	quiet.add(StructureKind.HUT, Vector2.ZERO)
	quiet.add(StructureKind.PLOT, Vector2(2, 0))
	quiet.add(StructureKind.CATCHMENT, Vector2(4, 0))
	var loud := Settlement.new(2)
	loud.add(StructureKind.HUT, Vector2.ZERO)
	# A mast with nothing driving it is a pole; this one is wired to the array.
	loud.add(StructureKind.RADIO_MAST, Vector2(2, 0)).powered = true
	lt(quiet.signature().total(), 0.05, "a hut, a plot and a water butt say nothing")
	gt(loud.signature().total(), 0.9, "one mast on the roof gives the whole place away")
	eq(loud.signature().loudest(), &"radio", "and the mast is what a machine reports")


func test_a_dozen_hearths_are_still_one_column_of_smoke() -> void:
	var one := Settlement.new(1)
	one.add(StructureKind.HEARTH, Vector2.ZERO)
	var many := Settlement.new(2)
	for i in 12:
		many.add(StructureKind.HEARTH, Vector2(i * 2, 0))
	near(many.signature().total(), one.signature().total(), 1e-4, "comfort does not accumulate into betrayal")


func test_a_piece_that_needs_power_and_has_none_almost_says_nothing() -> void:
	var s := Settlement.new(1)
	var shop := s.add(StructureKind.MACHINE_SHOP, Vector2.ZERO)
	var dark := s.signature().total()
	shop.powered = true
	gt(s.signature().total(), dark * 2.0, "running, it is a different place")


func test_a_spoofer_earns_its_place_by_taking_from_every_channel() -> void:
	var s := Settlement.new(1)
	s.add(StructureKind.RADIO_MAST, Vector2.ZERO)
	s.add(StructureKind.FORGE, Vector2(2, 0))
	var seen := s.signature().total()
	# A spoofer is a machine's voice and runs on a machine's power
	# (tests/settlement/test_defences.gd holds the dark one to hiding nothing).
	s.add(StructureKind.SPOOFER, Vector2(4, 0)).powered = true
	lt(s.signature().total(), seen * 0.7, "hidden, the same town reads much quieter")


func test_people_coming_and_going_are_themselves_a_sign() -> void:
	var s := Settlement.new(1)
	s.add(StructureKind.HUT, Vector2.ZERO)
	var empty := s.signature().traffic
	for i in 4:
		s.people.append(i)
	gt(s.signature().traffic, empty, "a town with people in it is a town with traffic")


func test_a_whole_town_survives_a_trip_through_json() -> void:
	var s := Settlement.new(7, Realm.UNDERGROUND, Vector2(12.5, -3.25), "the quarry")
	var mast := s.add(StructureKind.RADIO_MAST, Vector2(13, -3))
	mast.powered = true
	mast.staffed_by = 4
	var wall := s.add(StructureKind.PLATE_WALL, Vector2(15, -3), 8.0)
	s.damage_structure(wall.id, 3.0)
	s.people.append(4)
	s.stores["scrap"] = 12
	s.attention = 0.42
	var back := Settlement.from_dict(JSON.parse_string(JSON.stringify(s.as_dict())))
	eq(back.id, 7, "id")
	eq(back.realm, Realm.UNDERGROUND, "the realm it was built in")
	eq(back.name, "the quarry", "name")
	near(back.centre.x, 12.5, 1e-4, "where it stands")
	eq(back.pieces.size(), 2, "both pieces")
	check(back.piece(mast.id).powered, "the mast is still running")
	eq(back.piece(mast.id).staffed_by, 4, "and still staffed")
	near(back.piece(wall.id).health, 5.0, 1e-4, "the wall is still dented")
	eq(back.people.size(), 1, "the person who lives there")
	near(back.attention, 0.42, 1e-4, "and what the machines think of it")
	var next := back.add(StructureKind.HUT, Vector2.ZERO)
	check(next.id > wall.id, "a piece built after loading gets a fresh id")
