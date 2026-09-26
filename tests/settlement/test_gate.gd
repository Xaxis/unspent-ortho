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


## THE GATE STOPS MACHINES (SETTLE.md S3b): a wall the player's own feet pass
## and every other body's do not. A runner walking into the yard through the
## gate is held at it while it stands, and goes through once it is wrecked; the
## player walks through it either way.
const F := preload("res://tests/fight/fixture.gd")


## A line of wall across the field at x = LINE, each of it a gate's hold, so the
## only way to the player on the far side is through it.
const LINE := 30.5


func _walls() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for y in 64:
		out.append(Vector3(LINE, float(y) + 0.5, StructureKind.GATE_HOLD))
	return out


func test_an_intact_gate_holds_a_machine_and_the_player_walks_through() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(34.5, 20.5))
	sim.mob_walls = _walls()
	var m := sim.add_mob(&"runner", Vector2(26.5, 20.5))
	m.facing = 0.0
	m.aim = 0.0
	m.set_mood(MobState.CHASING, sim.now)
	F.ms(sim, 4000.0)
	lt(m.pos.x, LINE, "an intact gate holds the machine outside (x %.2f)" % m.pos.x)
	sim.mob_walls = [] as Array[Vector3]
	F.ms(sim, 4000.0)
	gt(m.pos.x, LINE, "a wrecked one lets it through (x %.2f)" % m.pos.x)
	# The player walks through an intact one.
	var sim2 := F.make_sim(F.flat_world(64), Vector2(26.5, 40.5))
	sim2.mob_walls = _walls()
	sim2.hero.move = Vector2.RIGHT
	F.ms(sim2, 2500.0)
	gt(sim2.hero.pos.x, LINE + 1.0, "the player walks through it (x %.2f)" % sim2.hero.pos.x)
