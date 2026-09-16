extends TestCase
## Roles and dispositions, against the table in docs/VISION.md §2. Every
## machine on the coast has a place in the plan, and its place decides what it
## makes of the player before anything has happened.


func test_every_machine_has_a_role_and_its_rows_default_disposition_matches_it() -> void:
	var seen: Dictionary = {}
	for kind: StringName in Roster.kinds():
		var row := Roster.row(kind)
		if not row.get("machine", false):
			continue
		var role := Roles.of(kind)
		check(Roles.ALL.has(role), "%s has a role in the plan" % kind)
		seen[role] = true
		eq(Roster.disposition(kind), Roles.default_disposition(role),
			"%s (%s) starts at its role's disposition" % [kind, role])
	check(seen.has(Roles.WORKER) and seen.has(Roles.KEEPER) and seen.has(Roles.WATCHER)
		and seen.has(Roles.HUNTER), "the coast holds workers, keepers, watchers and hunters")


func test_the_table_of_defaults_is_the_visions() -> void:
	eq(Roles.default_disposition(Roles.WORKER), &"indifferent", "workers")
	eq(Roles.default_disposition(Roles.KEEPER), &"wary", "keepers")
	eq(Roles.default_disposition(Roles.WATCHER), &"observant", "watchers and clerks")
	eq(Roles.default_disposition(Roles.HUNTER), &"hostile", "hunters")
	eq(Roles.default_disposition(Roles.RECYCLER), &"indifferent", "recyclers")


func test_what_turns_each_role_is_the_visions_right_hand_column() -> void:
	for cause: StringName in [&"blocked", &"damaged", &"theft"]:
		check(Roles.turns(Roles.WORKER, cause), "a worker turns when %s" % cause)
	check(not Roles.turns(Roles.WORKER, &"trespass"), "a worker does not keep a site")
	check(not Roles.turns(Roles.WORKER, &"curfew"), "nor a curfew")
	check(Roles.turns(Roles.KEEPER, &"trespass") and Roles.turns(Roles.KEEPER, &"curfew"),
		"a keeper holds its site and its hours")
	check(Roles.turns(Roles.HUNTER, &"anything at all"), "a hunter needs no reason")
	for cause: StringName in [&"blocked", &"damaged", &"theft", &"trespass"]:
		check(not Roles.turns(Roles.WATCHER, cause), "nothing makes a watcher fight (%s)" % cause)
	check(Roles.files(Roles.WATCHER) and not Roles.fights(Roles.WATCHER), "it reports instead")
	check(Roles.turns(Roles.RECYCLER, &"downed"), "a recycler comes for the downed")


func test_a_role_a_row_does_not_name_is_read_from_its_disposition() -> void:
	eq(Roles.of_row({"machine": true, "disposition": &"indifferent"}), Roles.WORKER)
	eq(Roles.of_row({"machine": true, "disposition": &"wary"}), Roles.KEEPER)
	eq(Roles.of_row({"machine": true, "disposition": &"observant"}), Roles.WATCHER)
	eq(Roles.of_row({"machine": true}), Roles.HUNTER, "hostile by default")
	eq(Roles.of_row({"machine": false}), Roles.HUNTER, "a creature has no place in the plan")


func test_interference_raises_a_worker_a_step_at_a_time_and_never_a_watcher() -> void:
	eq(Disposition.of(Roles.WORKER, 0), &"indifferent", "a calm region: it works on")
	eq(Disposition.of(Roles.WORKER, 1), &"wary", "wary: it looks up")
	eq(Disposition.of(Roles.WORKER, 2), &"hostile", "hostile: it stops working and comes")
	eq(Disposition.of(Roles.WORKER, 3), &"hostile", "hunted: the harvest comes for you too")
	eq(Disposition.of(Roles.KEEPER, 0), &"wary", "a keeper starts a step ahead")
	eq(Disposition.of(Roles.KEEPER, 2), &"hostile")
	for lvl: int in [0, 1, 2, 3]:
		eq(Disposition.of(Roles.WATCHER, lvl), &"observant", "a watcher only ever files (level %d)" % lvl)
		eq(Disposition.of(Roles.HUNTER, lvl), &"hostile", "a hunter is already hostile (level %d)" % lvl)


func test_a_disturbed_body_is_hostile_whatever_its_region_thinks() -> void:
	eq(Disposition.of(Roles.WORKER, 0, true), &"hostile", "robbed in a calm region")
	eq(Disposition.of(Roles.KEEPER, 0, true), &"hostile")
	eq(Disposition.of(Roles.WATCHER, 0, true), &"observant", "except the one that does not fight")
	check(Disposition.turned_by(Roles.WORKER, &"theft"), "theft turns a worker")
	check(not Disposition.turned_by(Roles.WORKER, &"curfew"), "a curfew is not its business")
	check(not Disposition.turned_by(Roles.WATCHER, &"damaged"), "a watcher struck still does not fight")


func test_dispositions_are_a_ladder_with_a_real_middle() -> void:
	check(Disposition.rank(&"hostile") > Disposition.rank(&"wary"))
	check(Disposition.rank(&"wary") > Disposition.rank(&"indifferent"))
	# Every rung is somewhere a worker actually stands as its region heats, and
	# each one is a different thing to meet (FightSim reads watchful()).
	eq(Disposition.of(Roles.WORKER, 0), &"indifferent")
	eq(Disposition.of(Roles.WORKER, 1), &"wary", "the middle is a rung, not a label")
	eq(Disposition.of(Roles.WORKER, 2), &"hostile")
	check(Disposition.works_on(&"indifferent") and not Disposition.works_on(&"wary"))
	check(Disposition.watchful(&"wary"), "and the middle has a name the simulation reads")
	check(not Disposition.watchful(&"indifferent") and not Disposition.watchful(&"hostile"))


func test_a_live_body_carries_its_role_from_the_roster() -> void:
	var h := MobState.new(&"harvester", Vector2(4, 4), 1)
	eq(h.role, Roles.WORKER, "a harvester is a worker")
	eq(h.disposition, &"indifferent")
	check(h.indifferent(), "and works on")
	var w := MobState.new(&"watcher", Vector2(4, 4), 1)
	eq(w.role, Roles.WATCHER)
	var r := MobState.new(&"runner", Vector2(4, 4), 1)
	eq(r.role, Roles.HUNTER)
	eq(r.disposition, &"hostile")
