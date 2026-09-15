extends TestCase
## The plate rule: a blow counts only from the working part's side; from any
## other side it rings, and does nothing but throw the swinger back.

const F := preload("res://tests/fight/fixture.gd")


func test_side_of_a_body_facing_east() -> void:
	var o := Vector2(10, 10)
	eq(FightRules.side_of(o, 0.0, o + Vector2(2, 0)), &"front", "ahead")
	eq(FightRules.side_of(o, 0.0, o + Vector2(-2, 0)), &"back", "behind")
	eq(FightRules.side_of(o, 0.0, o + Vector2(0, 2)), &"right", "south of an east-facing body")
	eq(FightRules.side_of(o, 0.0, o + Vector2(0, -2)), &"left", "north of an east-facing body")
	# Ties go to the facing axis, as the source's |dx| >= |dy|.
	eq(FightRules.side_of(o, 0.0, o + Vector2(1, 1)), &"front", "a diagonal tie")


func test_side_of_turns_with_the_body() -> void:
	var o := Vector2(10, 10)
	var north := -PI * 0.5
	eq(FightRules.side_of(o, north, o + Vector2(0, -2)), &"front")
	eq(FightRules.side_of(o, north, o + Vector2(2, 0)), &"right", "east of a north-facing body")
	eq(FightRules.side_of(o, north, o + Vector2(-2, 0)), &"left")
	eq(FightRules.side_of(o, north, o + Vector2(0, 2)), &"back")
	check(FightRules.reaches(&"none", o, 0.0, o + Vector2(-2, 0)), "no plate: every side reaches")
	check(FightRules.reaches(&"back", o, 0.0, o + Vector2(-2, 0), true), "a cutting edge reaches past plate")
	check(not FightRules.reaches(&"back", o, 0.0, o + Vector2(2, 0)), "the front of a back-part body is plate")


func _swing_at(kind: StringName, mob_facing: float, from_side: Vector2) -> Dictionary:
	var sim := F.make_sim()
	var at := Vector2(30.5, 20.5)
	var m := F.still(sim, kind, at, mob_facing)
	sim.hero.pos = at + from_side.normalized() * (m.radius + sim.hero.radius + 0.3)
	sim.hero.facing = (at - sim.hero.pos).angle()
	var before := m.health
	sim.press_swing()
	F.ms(sim, 260)
	var events := sim.drain()
	return {"sim": sim, "mob": m, "before": before, "events": events}


func test_harvester_is_hurt_only_from_the_front() -> void:
	# Facing west, its front (the intake) is to the west.
	var r := _swing_at(&"harvester", PI, Vector2(-1, 0))
	var m: MobState = r.mob
	var hit := F.first(r.events, &"hit")
	check(not hit.is_empty(), "a blow landed")
	eq(hit.get("plate", null), false, "from the front it reaches")
	eq(m.health, int(r.before) - 1, "fists do one")
	check(m.flare_until > 0.0, "the part flares on a real hit")


func test_harvester_rings_from_behind_and_does_nothing() -> void:
	var r := _swing_at(&"harvester", PI, Vector2(1, 0))
	var m: MobState = r.mob
	var sim: FightSim = r.sim
	var hit := F.first(r.events, &"hit")
	check(not hit.is_empty(), "the blow met the body")
	eq(hit.get("plate", null), true, "from behind it rings")
	eq(hit.get("damage", -1), 0, "no damage")
	eq(m.health, int(r.before), "health unchanged")
	eq(m.flare_until, 0.0, "the part does not flare")
	check(sim.hero.throw_until > 0.0, "the swinger takes recoil")
	eq(F.count(r.events, &"killed"), 0)


func test_cutter_is_hurt_only_from_behind() -> void:
	var front := _swing_at(&"cutter", 0.0, Vector2(1, 0))
	eq(F.first(front.events, &"hit").get("plate", null), true, "the front of a cutter is plate")
	var back := _swing_at(&"cutter", 0.0, Vector2(-1, 0))
	eq(F.first(back.events, &"hit").get("plate", null), false, "its drive is at the back")
	eq((back.mob as MobState).health, int(back.before) - 1)


func test_hauler_part_is_on_its_left_flank() -> void:
	# Facing east, its left is north.
	var left := _swing_at(&"hauler", 0.0, Vector2(0, -1))
	eq(F.first(left.events, &"hit").get("plate", null), false, "the hinge side reaches")
	var right := _swing_at(&"hauler", 0.0, Vector2(0, 1))
	eq(F.first(right.events, &"hit").get("plate", null), true, "the other flank rings")


func test_one_hit_per_target_per_blow() -> void:
	var r := _swing_at(&"dog.yard", 0.0, Vector2(1, 0))
	eq(F.count(r.events, &"hit"), 1, "one blow, one hit")


func test_a_half_worn_knife_does_what_fists_do() -> void:
	eq(FightRules.damage_at_edge(2, 5000), 1, "half edge rounds to 1")
	eq(FightRules.damage_at_edge(2, 10000), 2)
	eq(FightRules.damage_at_edge(4, 0), 1, "a dull edge still does 1")
