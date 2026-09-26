extends TestCase
## THE GATE (SETTLE.md S3). A yard ringed in palisade walled its builder in: the
## gate is a length of wall a body walks through (no footprint), that still
## turns a raid's force as a wall does, and that is the weak point a breaching
## party goes for first -- so where the breach comes is where the player put it.


func test_a_gate_is_built_walked_through_and_counts_as_wall() -> void:
	check(StructureKind.buildable(StructureKind.GATE), "a gate can be put up")
	eq(StructureKind.solid(StructureKind.GATE), 0.0, "and walked through")
	gt(StructureKind.defence(StructureKind.GATE), 0.0, "and still turns a raid's force")
	lt(StructureKind.defence(StructureKind.GATE), StructureKind.defence(StructureKind.PALISADE), "less than the stakes either side of it")
	check(StructureModel.drawn(StructureKind.GATE), "and it is drawn")


func test_a_breaching_party_goes_for_the_gate_first() -> void:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(20, 20))
	s.add(StructureKind.PLATE_WALL, Vector2(22, 20))
	s.add(StructureKind.PALISADE, Vector2(22, 22))
	var gate := s.add(StructureKind.GATE, Vector2(22, 21))
	eq(RaidRoles.breach_target(s), gate.id, "the gate, not the plate wall beside it")
	s.destroy_structure(gate.id)
	check(RaidRoles.breach_target(s) != gate.id, "and with the gate down, the heaviest wall again")
