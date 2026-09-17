extends TestCase
## What a party is for, and what it goes at (docs/VISION.md §9.5). The pillar
## these hold: **a raid targets what MAKES the signature**, so the player's own
## build decides the fight — which is the only thing that makes the seven bars on
## the holding page a decision and not a readout.


func _place(pieces: Array[int]) -> Settlement:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(50, 50), "the holding")
	var i := 0
	for kind: int in pieces:
		var p := s.add(kind, Vector2(50 + float(i), 50))
		p.powered = true
		i += 1
	return s


func test_a_harvester_walks_to_whatever_is_shouting_loudest() -> void:
	# A mast and a hearth. The mast is the mistake, and the mast is what is
	# walked to, past the wall and past the roof.
	var s := _place([StructureKind.HUT, StructureKind.PALISADE, StructureKind.HEARTH,
		StructureKind.RADIO_MAST] as Array[int])
	s.night = 0.0
	var target := s.piece(RaidRoles.harvest_target(s))
	check(target != null, "it found something")
	eq(target.kind, StructureKind.RADIO_MAST, "the thing the slate names")
	# Take the mast down and the hearth becomes the loudest thing: the same rule
	# gives a different answer, which is the player's decision working.
	s.destroy_structure(target.id)
	var next := s.piece(RaidRoles.harvest_target(s))
	check(next != null and next.kind == StructureKind.HEARTH,
		"with the mast gone it is the smoke, %s" % (StructureKind.display_name(next.kind) if next != null else "nothing"))


func test_a_harvester_never_goes_for_the_wall() -> void:
	var s := _place([StructureKind.PLATE_WALL, StructureKind.RADIO_MAST] as Array[int])
	var target := s.piece(RaidRoles.harvest_target(s))
	check(target != null and not StructureKind.is_defence(target.kind), "walls are somebody else's job")


func test_a_breacher_goes_for_the_strongest_thing_in_the_way() -> void:
	var s := _place([StructureKind.NETTING, StructureKind.PALISADE, StructureKind.PLATE_WALL,
		StructureKind.RADIO_MAST] as Array[int])
	var target := s.piece(RaidRoles.breach_target(s))
	check(target != null, "it found something")
	eq(target.kind, StructureKind.PLATE_WALL, "the plate, not the net")
	# A holding with no defence at all: it comes through the roof.
	var open := _place([StructureKind.HUT, StructureKind.PLOT] as Array[int])
	var into := open.piece(RaidRoles.breach_target(open))
	check(into != null and into.family() == StructureKind.Family.SHELTER,
		"with no wall, the roof is the wall")


func test_a_snatcher_takes_whoever_is_at_work_first() -> void:
	var s := _place([StructureKind.PLOT, StructureKind.RADIO_MAST] as Array[int])
	s.people.append(4)
	s.people.append(7)
	s.pieces[1].staffed_by = 7
	eq(RaidRoles.snatch_target(s), 7, "the pair of hands that is doing something")
	s.pieces[1].staffed_by = -1
	eq(RaidRoles.snatch_target(s), 4, "and otherwise whoever is there")
	s.people.clear()
	eq(RaidRoles.snatch_target(s), -1, "an empty holding has nobody to take")


func test_each_trade_is_filled_by_a_body_that_suits_it() -> void:
	var breacher := RaidRoles.kind_for(RaidRoles.BREACHER)
	var harvester := RaidRoles.kind_for(RaidRoles.HARVESTER)
	var snatcher := RaidRoles.kind_for(RaidRoles.SNATCHER)
	var scout := RaidRoles.kind_for(RaidRoles.SCOUT)
	check(Roster.has(breacher), "a breacher is a real machine: %s" % breacher)
	gt(float(Roster.row(breacher).get("bite", {}).get("dmg", 0)), 0.0, "and it hits things")
	eq(Roles.of(harvester), Roles.WORKER, "a harvester is one of the plan's own workers")
	eq(Roles.of(scout), Roles.WATCHER, "a scout sees and files")
	check(Roster.has(snatcher), "a snatcher is a real machine: %s" % snatcher)
	# A keeper is never in a party by accident: it comes as a siege, deliberately.
	for role: StringName in [RaidRoles.BREACHER, RaidRoles.HARVESTER, RaidRoles.SNATCHER, RaidRoles.SCOUT]:
		eq(Roster.sentinel_of(RaidRoles.kind_for(role)), &"", "%s is not a landscape's keeper" % role)


func test_the_party_grows_with_the_step() -> void:
	var last := 0
	for stage: StringName in RaidStage.ORDER:
		var n := RaidStage.party_size(stage)
		check(n >= last, "%s brings at least as many as the step before it" % stage)
		last = n
		check(not RaidRoles.roles_for(stage).is_empty(), "%s has somebody in it" % stage)
	eq(RaidRoles.roles_for(RaidStage.SURVEY), [RaidRoles.SCOUT], "a survey is one pair of eyes")
	check(RaidRoles.roles_for(RaidStage.RAID).has(RaidRoles.BREACHER), "a raid brings a breacher")
	check(RaidStage.led_by_keeper(RaidStage.SIEGE), "and a siege brings the region's keeper")
	check(not RaidStage.led_by_keeper(RaidStage.RAID), "which a raid does not")


# --- what a party does when nobody is there to fight it -----------------------

func test_a_wall_turns_force_aside_and_never_all_of_it() -> void:
	eq(RaidResolve.turned(0.0), 0.0, "nothing built, nothing turned")
	gt(RaidResolve.turned(2.2), 0.0, "one plate wall is worth something")
	lt(RaidResolve.turned(1000.0), RaidResolve.MOST_TURNED + 1e-6, "and nothing is ever immune")
	gt(RaidResolve.through(RaidStage.SIEGE, 1000.0), 0.0, "a siege gets through whatever is built")
	var bare := RaidResolve.through(RaidStage.RAID, 0.0)
	var walled := RaidResolve.through(RaidStage.RAID, 6.6)
	lt(walled, bare, "three plate walls buy a holding pieces")


func test_a_raid_nobody_was_there_for_really_breaks_things() -> void:
	var s := _place([StructureKind.HUT, StructureKind.RADIO_MAST, StructureKind.PLOT] as Array[int])
	s.people.append(1)
	var whole := 0.0
	for p in s.pieces:
		whole += p.health
	var report := RaidResolve.resolve(s, RaidStage.RAID, 5, 1)
	check(not (report["broke"] as Array[int]).is_empty(), "something was broken")
	var after := 0.0
	for p in s.pieces:
		after += p.health
	lt(after, whole, "the yard is worse than it was")
	check(report["outcome"] != &"held", "and the holding did not hold")


func test_the_same_raid_on_the_same_seed_is_the_same_raid() -> void:
	var a := _place([StructureKind.HUT, StructureKind.RADIO_MAST] as Array[int])
	var b := _place([StructureKind.HUT, StructureKind.RADIO_MAST] as Array[int])
	var ra := RaidResolve.resolve(a, RaidStage.RAID, 11, 3)
	var rb := RaidResolve.resolve(b, RaidStage.RAID, 11, 3)
	eq(ra["broke"], rb["broke"], "the same pieces")
	eq(ra["outcome"], rb["outcome"], "and the same ending")
	for i in a.pieces.size():
		near(a.pieces[i].health, b.pieces[i].health, 1e-4, "dented in exactly the same places")


func test_a_full_store_is_taken_instead_of_the_walls() -> void:
	# Paying them off: goods lying loose in the store buy the pieces standing.
	var s := _place([StructureKind.HUT, StructureKind.STORE, StructureKind.RADIO_MAST] as Array[int])
	s.stores[&"berries"] = 20
	var report := RaidResolve.resolve(s, RaidStage.PROBE, 5, 1)
	check(not (report["stores"] as Dictionary).is_empty(), "they took what was lying about")
	eq(report["outcome"], &"held", "and left the place standing")
	for p in s.pieces:
		check(p.standing(), "%s is still up" % StructureKind.display_name(p.kind))
	lt(float(s.stores.get(&"berries", 0)), 20.0, "the crop is gone, and that is the price")


func test_a_place_giving_off_nothing_is_walked_through_and_left() -> void:
	var quiet := _place([StructureKind.LEAN_TO, StructureKind.PLOT] as Array[int])
	check(RaidResolve.nothing_here(quiet, RaidStage.RAID), "nothing here worth the walk")
	var loud := _place([StructureKind.RADIO_MAST] as Array[int])
	check(not RaidResolve.nothing_here(loud, RaidStage.RAID), "and a mast is worth the walk")


func test_a_holding_with_nothing_left_standing_is_razed() -> void:
	var s := _place([StructureKind.LEAN_TO] as Array[int])
	s.destroy_structure(s.pieces[0].id)
	eq(RaidResolve.outcome_of(s, {"broke": [1], "ruined": [1], "took": []}), &"razed",
		"nothing of it is standing")


func test_a_razed_holding_is_looted_and_not_killed() -> void:
	RaidSpoils.declare()
	check(not Drops.table(RaidSpoils.RAZED).is_empty(), "a razed holding leaves something")
	eq(Drops.body_of(RaidSpoils.RAZED), RaidSpoils.RAZED,
		"and it names no body: a holding is looted, not killed (src/core/loot/drops.gd)")
	eq(Drops.body_of(RaidSpoils.RECORD), RaidSpoils.RECORD, "so is a record off a carrier")
	var spoils := RaidSpoils.razed(3, 1)
	check(not spoils.is_empty(), "there is something in the ruins")
	eq(spoils, RaidSpoils.razed(3, 1), "and it is the same ruin every time it is looked at")
	check(not Items.def(RaidSpoils.RECORD_ITEM).is_empty(), "the record is a thing a person can carry")
