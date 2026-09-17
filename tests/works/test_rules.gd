extends TestCase
## What breaking a depot changes (docs/VISION.md §2). Pure rules, so the whole of
## "the region quiets and slowly recovers" can be proved without running a world
## for four days.


func _site() -> WorksSite:
	var s := WorksSite.new()
	s.region = 2
	s.land = &"coast"
	s.pos = Vector2(100, 100)
	s.facing = 0.4
	s.yard = 3
	return s


func test_a_standing_depot_puts_bodies_on_the_land_and_a_broken_one_puts_none() -> void:
	var day := 24.0
	var standing := Works.bodies_in(day, false)
	var broken := Works.bodies_in(day, true)
	gt(float(standing), 40.0, "a working depot is why a region is busy")
	eq(broken, 0, "a broken one is why it is quiet: not thinned, stopped")
	eq(Works.own_every(true), INF, "nothing more comes out of its yard, ever")
	eq(Works.patrol_every(true), INF, "and nothing more walks its round")
	# Said as a ratio, because that is the measurement the quieting is judged by.
	print("works: %d bodies a day standing -> %d broken" % [standing, broken])


func test_the_plan_advances_where_it_stands_and_stops_where_it_is_broken() -> void:
	var s := _site()
	var first := Works.stage(s, 1.0, false)
	var later := Works.stage(s, 1.0 + Works.STAGE_DAYS * 2.0, false)
	gt(float(later), float(first), "a working depot raises another bay as the days go")
	lt(float(later), float(Works.STAGES), "and never past the last stage it has")
	# Broken on day 2: it is still at day 2's stage a fortnight later.
	eq(Works.stage(s, 30.0, true, 2.0), Works.stage(s, 2.0, false),
		"a dark yard never got any further with the plan")


func test_a_bigger_yard_is_further_on_than_a_small_one() -> void:
	var small := _site()
	small.yard = 1
	var big := _site()
	big.yard = 9
	gt(float(Works.stage(big, 1.0, false)), float(Works.stage(small, 1.0, false)),
		"a region with more of the plan's work in it is further on")


func test_the_land_takes_a_broken_yard_back_over_days_and_not_at_once() -> void:
	near(Works.greening(0.0), 0.0, 1e-4, "the morning after, it is bare")
	eq(Works.green_tufts(0.0), 0, "and nothing has grown")
	lt(Works.greening(Works.RECOVER_HOURS * 0.25), 0.3, "a day later it is barely started")
	near(Works.greening(Works.RECOVER_HOURS), 1.0, 1e-4, "four days on, the land has it")
	eq(Works.green_tufts(Works.RECOVER_HOURS), Works.GREEN_MOST, "with everything it means to put back")
	near(Works.greening(Works.RECOVER_HOURS * 4.0), 1.0, 1e-4, "and it does not go on for ever")


func test_a_part_can_only_be_reached_from_its_own_ground() -> void:
	var s := _site()
	for i in Works.PART_NAMES.size():
		eq(Works.part_near(s, s.part(i)), i, "standing on part %d is reaching part %d" % [i, i])
		# And nothing else: two parts are two walks.
		for j in Works.PART_NAMES.size():
			if i == j:
				continue
			check(Works.part_near(s, s.part(i)) != j, "part %d is not in reach of part %d" % [j, i])
	eq(Works.part_near(s, s.pos + Vector2(40, 40)), -1, "and nothing is in reach from off the yard")


func test_what_has_been_done_to_a_depot_survives_a_save() -> void:
	var st := WorksState.new()
	st.region = 4
	st.parts[0] = true
	st.parts[2] = true
	st.dark_at = 1234.5
	st.dark_day = 3.0
	st.tufts = 5
	st.stripped = true
	check(not st.broken(), "two of three is not broken")
	eq(st.broken_count(), 2, "two are open")
	# Through JSON, which is what a save really is.
	var back := WorksState.from_save(JSON.parse_string(JSON.stringify(st.save())))
	eq(back.region, 4, "the region it serves comes back")
	eq(back.parts, st.parts, "and which housings are open")
	near(back.dark_at, 1234.5, 1e-3, "and when it went dark")
	eq(back.tufts, 5, "and how far the land has taken it")
	check(back.stripped, "and that its yard has already been spent")


func test_a_depot_that_never_went_dark_comes_back_still_working() -> void:
	var st := WorksState.new()
	st.region = 1
	var back := WorksState.from_save(JSON.parse_string(JSON.stringify(st.save())))
	eq(back.dark_at, INF, "INF survives the round trip (SaveCodec), so it is not dark")
	near(back.dark_hours(9999.0), 0.0, 1e-4, "and no time has passed in the dark")
