extends TestCase
## A notice is a reading a body took and is carrying home (docs/VISION.md §9.2).
## These hold the reading itself to the channels the slate already draws: what
## carries how far, who reads it well, and what a place that gives off nothing
## is worth to anybody.


func _place(pieces: Array[int], staffed: bool = false) -> Settlement:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(50, 50), "the holding")
	for kind: int in pieces:
		var p := s.add(kind, Vector2(50, 50))
		p.powered = true
		if staffed:
			p.staffed_by = 1
	return s


func test_a_place_that_gives_off_nothing_is_read_by_nobody() -> void:
	# A lean-to, a plot and a water butt are silent on purpose (the settlement
	# package's own decision): nothing about living somewhere gives it away.
	var quiet := _place([StructureKind.LEAN_TO, StructureKind.PLOT, StructureKind.CATCHMENT] as Array[int])
	var row := Roster.row(&"clerk")
	eq(Notices.read(quiet.signature(), quiet.centre, quiet.centre + Vector2(2, 0), row), {},
		"standing on top of it, a clerk has nothing to file")


func test_the_loudest_mistake_is_the_one_that_is_reported() -> void:
	var s := _place([StructureKind.HEARTH, StructureKind.RADIO_MAST] as Array[int])
	s.night = 0.0
	var read := Notices.read(s.signature(), s.centre, s.centre + Vector2(6, 0), Roster.row(&"clerk"))
	eq(read.get("channel"), &"radio", "the mast, not the smoke")
	# And the holding's own page says the same word, so the player can read it
	# before anything arrives.
	eq(s.signature().loudest(), &"radio", "what the slate names is what is filed")


func test_radio_carries_further_than_noise() -> void:
	gt(Notices.reach(&"radio"), Notices.reach(&"noise"), "the mast reaches further than the forge")
	gt(Notices.reach(&"found_tech"), Notices.reach(&"traffic"), "stolen tech answers from further off")
	var mast := _place([StructureKind.RADIO_MAST] as Array[int])
	var far := mast.centre + Vector2(Notices.reach(&"radio") - 1.0, 0.0)
	var past := mast.centre + Vector2(Notices.reach(&"radio") + 2.0, 0.0)
	eq(Notices.read(mast.signature(), mast.centre, past, Roster.row(&"clerk")), {},
		"past its reach, nothing")
	# Just inside it the reading is weak; under its nose it is strong.
	var near_read := Notices.read(mast.signature(), mast.centre, mast.centre + Vector2(3, 0), Roster.row(&"clerk"))
	var far_read := Notices.read(mast.signature(), mast.centre, far, Roster.row(&"clerk"))
	check(not near_read.is_empty(), "read from beside it")
	if not far_read.is_empty():
		gt(float(near_read.get("strength", 0.0)), float(far_read.get("strength", 0.0)),
			"nearer is a better reading")


func test_a_body_is_what_it_is_in_the_world_s_own_words() -> void:
	eq(Notices.kind_of(Roster.row(&"clerk")), &"clerk", "a clerk writes it down")
	eq(Notices.kind_of(Roster.row(&"watcher")), &"watcher", "a watcher logs it")
	eq(Notices.kind_of(Roster.row(&"flock")), &"drone", "something small photographs it")
	eq(Notices.kind_of(Roster.row(&"harvester")), &"worker", "a worker on its round files it")
	# A creature has nobody to tell.
	check(not Notices.reports(Roster.row(&"dog.feral")), "a dog files nothing")
	check(Notices.reports(Roster.row(&"harvester")), "everything in the plan does")


func test_a_watcher_takes_a_better_reading_than_a_worker() -> void:
	var s := _place([StructureKind.RADIO_MAST] as Array[int])
	var from := s.centre + Vector2(8, 0)
	var clerk := Notices.read(s.signature(), s.centre, from, Roster.row(&"clerk"))
	var worker := Notices.read(s.signature(), s.centre, from, Roster.row(&"harvester"))
	gt(float(clerk.get("strength", 0.0)), float(worker.get("strength", 0.0)),
		"seeing and filing is a watcher's whole trade")
	# And what it is worth when it gets home follows the same order.
	var a := Notice.new()
	a.carrier = &"clerk"
	a.strength = 1.0
	var b := Notice.new()
	b.carrier = &"harvester"
	b.strength = 1.0
	gt(Notices.worth(a), Notices.worth(b), "a clerk's record is worth more")


func test_the_player_s_own_spoof_blinds_a_reading_taken_over_them() -> void:
	var s := _place([StructureKind.RADIO_MAST] as Array[int])
	var from := s.centre + Vector2(5, 0)
	var plain := Notices.read(s.signature(), s.centre, from, Roster.row(&"clerk"), 0.0)
	var blind := Notices.read(s.signature(), s.centre, from, Roster.row(&"clerk"), 1.0)
	check(not plain.is_empty(), "read without the signet")
	eq(blind, {}, "and nothing at all with it running")


func test_a_carrier_makes_for_home_along_the_plan_s_own_line() -> void:
	var holding := Vector2(60, 60)
	var at := holding + Vector2(4, 0)
	var way := Notices.home_bearing(7, at, holding)
	var along := Vector2.from_angle(GenWorks.bearing(7))
	check(way.is_equal_approx(along) or way.is_equal_approx(-along),
		"it leaves along the bearing the machines surveyed this world on")
	gt(way.dot((at - holding).normalized()), 0.0, "and in the direction that leads away from the place")


func test_it_is_clear_of_the_yard_before_it_has_got_away() -> void:
	var n := Notice.new()
	n.at = Vector2(50, 50)
	check(not Notices.clear_of_holding(n, n.at + Vector2(3, 0)), "in the yard, still catchable")
	check(Notices.clear_of_holding(n, n.at + Vector2(Notices.CLEAR_OF + 1.0, 0)), "out of the yard")
	check(not Notices.got_away(n, n.at + Vector2(Notices.CLEAR_OF + 1.0, 0)), "and not yet gone")
	check(Notices.got_away(n, n.at + Vector2(Notices.GOT_AWAY + 1.0, 0)), "gone")
	gt(Notices.GOT_AWAY, Notices.CLEAR_OF, "there is a stretch between the two worth chasing over")


func test_a_notice_survives_a_trip_through_json() -> void:
	var n := Notice.new()
	n.id = 4
	n.settlement_id = 2
	n.realm = Realm.UNDERGROUND
	n.kind = &"clerk"
	n.carrier = &"clerk"
	n.channel = &"found_tech"
	n.strength = 0.62
	n.at = Vector2(12.5, -3.25)
	n.taken_at = 990.0
	var text := JSON.stringify(n.as_dict())
	var back := Notice.from_dict(JSON.parse_string(text) as Dictionary)
	eq(back.id, 4)
	eq(back.settlement_id, 2)
	eq(back.realm, Realm.UNDERGROUND, "a reading belongs to the realm it was taken in")
	eq(back.channel, &"found_tech")
	near(back.strength, 0.62, 1e-4)
	eq(back.at, Vector2(12.5, -3.25))
	check(back.carried(), "and it is still on its way")
