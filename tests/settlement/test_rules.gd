extends TestCase
## What a holding does with its own time (docs/VISION.md §9). Every one of these
## is about the same promise: a place the player walked away from six hours ago
## has done six hours of work when they come back, and exactly six — no more for
## having been watched, no less for having been forgotten.


func a_place() -> Settlement:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(100, 100), "the holding")
	s.worked_at = 0.0
	return s


func ctx() -> Dictionary:
	# No landscape named: the weather is a calm default, so a rule under test is
	# never at the mercy of which spell a seed happened to roll.
	return {"seed": 4, "land": &""}


func test_a_holding_settles_up_in_whole_slices_and_never_a_part_of_one() -> void:
	var s := a_place()
	var report := SettlementRules.catch_up(s, SettlementRules.SLICE * 3.5, ctx())
	near(float(report.minutes), SettlementRules.SLICE * 3.0, 1e-4, "three whole slices settled")
	near(s.worked_at, SettlementRules.SLICE * 3.0, 1e-4, "and the clock stands on a boundary")


func test_six_hours_away_is_the_same_holding_as_twelve_half_hours_watched() -> void:
	var away := a_place()
	var watched := a_place()
	for s: Settlement in [away, watched]:
		var plot := s.add(StructureKind.PLOT, Vector2(101, 100))
		s.add(StructureKind.CATCHMENT, Vector2(102, 100))
		s.add(StructureKind.STORE, Vector2(103, 100))
		s.people.append(1)
		plot.staffed_by = 1
	# One long absence against a dozen short looks over the same six hours.
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(away, 360.0, ctx())
	for step in 12:
		@warning_ignore("return_value_discarded")
		SettlementRules.catch_up(watched, float(step + 1) * 30.0, ctx())
	eq(int(away.stores.get(&"berries", 0)), int(watched.stores.get(&"berries", 0)), "the same crop either way")
	near(away.piece(1).health, watched.piece(1).health, 1e-4, "the same wear on the plot")
	near(away.hunger, watched.hunger, 1e-4, "the same hunger")
	near(away.worked_at, watched.worked_at, 1e-4, "settled to the same minute")
	gt(float(away.stores.get(&"berries", 0)), 0.0, "and six staffed hours grew something")


func test_a_plot_with_nobody_on_it_grows_nothing() -> void:
	var s := a_place()
	s.add(StructureKind.PLOT, Vector2(101, 100))
	s.add(StructureKind.CATCHMENT, Vector2(102, 100))
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 720.0, ctx())
	eq(int(s.stores.get(&"berries", 0)), 0, "twelve hours and not a berry: hands are the whole of it")


func test_a_plot_nobody_waters_grows_half() -> void:
	var wet := a_place()
	var dry := a_place()
	for s: Settlement in [wet, dry]:
		var plot := s.add(StructureKind.PLOT, Vector2(101, 100))
		s.add(StructureKind.STORE, Vector2(103, 100))
		s.people.append(1)
		plot.staffed_by = 1
	wet.add(StructureKind.CATCHMENT, Vector2(102, 100))
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(wet, 1440.0, ctx())
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(dry, 1440.0, ctx())
	gt(float(wet.stores.get(&"berries", 0)), float(dry.stores.get(&"berries", 0)), "the catchment is worth building")


func test_a_mast_runs_on_the_wind_and_then_on_what_was_banked() -> void:
	var s := a_place()
	var mast := s.add(StructureKind.RADIO_MAST, Vector2(101, 100))
	s.people.append(1)
	mast.staffed_by = 1
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 60.0, ctx())
	check(not mast.powered, "nothing to run it on: the mast is a pole")
	s.add(StructureKind.WIND_SPINNER, Vector2(102, 100))
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 120.0, ctx())
	check(mast.powered, "the spinner carries it")
	# The spinner gone, the batteries hold it up for a while and then let go.
	s.pieces.erase(s.structures_of(StructureKind.WIND_SPINNER)[0])
	s.add(StructureKind.BATTERY_STACK, Vector2(103, 100))
	s.charge = 4.0
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 150.0, ctx())
	check(mast.powered, "the bank carries it through a still hour")
	lt(s.charge, 4.0, "and the bank is that much emptier")


func test_a_still_week_kills_the_wind_spinners() -> void:
	var still := {"kind": Weather.CLEAR, "strength": 0.0, "wind": 0.05}
	var blowing := {"kind": Weather.CLEAR, "strength": 0.0, "wind": 0.8}
	near(SettlementRules.source(StructureKind.WIND_SPINNER, still, 12.0), 0.0, 1e-4, "no wind, no power")
	gt(SettlementRules.source(StructureKind.WIND_SPINNER, blowing, 12.0), 0.9, "a good blow turns it fully")


func test_everything_standing_wears_and_the_rain_takes_the_hand_s_work_faster() -> void:
	var s := a_place()
	var thatch := s.add(StructureKind.LEAN_TO, Vector2(101, 100))
	var plate := s.add(StructureKind.PLATE_WALL, Vector2(102, 100))
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 1440.0, ctx())
	lt(thatch.condition(), 1.0, "a day standing costs the lean-to something")
	gt(thatch.max_health - thatch.health, plate.max_health - plate.health, "and costs the thatch more than the plate")
	gt(SettlementRules.weather_wear(&"storm", 1.0, StructureKind.Idiom.MADE),
		SettlementRules.weather_wear(&"storm", 1.0, StructureKind.Idiom.MENDED), "a storm is harder on the hand's work")
	near(SettlementRules.weather_wear(&"clear", 0.0, StructureKind.Idiom.MADE), 1.0, 1e-4, "a fair day is just a day")


func test_hands_not_on_a_plot_keep_the_place_standing_and_pay_for_it() -> void:
	var s := a_place()
	var wall := s.add(StructureKind.PALISADE, Vector2(101, 100))
	wall.health = wall.max_health * 0.3
	s.people.append(1)
	s.stores[&"timber"] = 4
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 600.0, ctx())
	gt(wall.condition(), 0.3, "somebody mended it")
	lt(float(s.stores.get(&"timber", 0)), 4.0, "out of the stores, not out of nothing")


func test_a_holding_with_nothing_to_mend_with_does_not_mend() -> void:
	var s := a_place()
	var wall := s.add(StructureKind.PALISADE, Vector2(101, 100))
	wall.health = wall.max_health * 0.5
	s.people.append(1)
	var was := wall.health
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 600.0, ctx())
	lt(wall.health, was, "an empty store mends nothing: it only wears")


func test_a_piece_nobody_mends_falls_down_and_says_so_once() -> void:
	var s := a_place()
	var net := s.add(StructureKind.NETTING, Vector2(101, 100))
	net.health = 0.2
	var report := SettlementRules.catch_up(s, 600.0, ctx())
	check(net.ruined, "it came apart")
	eq((report["ruined"] as Array).size(), 1, "reported once")
	var again := SettlementRules.catch_up(s, 1200.0, ctx())
	eq((again["ruined"] as Array).size(), 0, "and never again: wreckage does not fall down twice")


func test_people_eat_what_is_stored_and_walk_away_when_there_is_none() -> void:
	var fed := a_place()
	fed.add(StructureKind.STORE, Vector2(101, 100))
	fed.people.append(1)
	fed.stores[&"bread"] = 20
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(fed, 1440.0, ctx())
	near(fed.hunger, 0.0, 1e-3, "somebody with bread is not hungry")
	lt(float(fed.stores.get(&"bread", 0)), 20.0, "and the bread went down")
	var starved := a_place()
	starved.people.append(1)
	starved.people.append(2)
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(starved, 4320.0, ctx())
	lt(float(starved.people.size()), 2.0, "three days with nothing to eat and somebody has gone")


func test_a_hungry_holding_gets_less_done() -> void:
	var s := a_place()
	var plot := s.add(StructureKind.PLOT, Vector2(101, 100))
	s.add(StructureKind.CATCHMENT, Vector2(102, 100))
	s.add(StructureKind.STORE, Vector2(103, 100))
	s.people.append(1)
	plot.staffed_by = 1
	s.hunger = 1.0
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 360.0, ctx())
	var starving := int(s.stores.get(&"berries", 0))
	var other := a_place()
	var p2 := other.add(StructureKind.PLOT, Vector2(101, 100))
	other.add(StructureKind.CATCHMENT, Vector2(102, 100))
	other.add(StructureKind.STORE, Vector2(103, 100))
	other.people.append(1)
	p2.staffed_by = 1
	# Eight loaves, not thirty: a store filled to its own brim has no room for a
	# crop, which is a rule of its own and not the one under test here.
	other.stores[&"bread"] = 8
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(other, 360.0, ctx())
	gt(float(other.stores.get(&"berries", 0)), float(starving), "a fed holding out-works a starving one")


func test_a_store_is_what_stops_a_surplus_going_to_waste() -> void:
	var s := a_place()
	var plot := s.add(StructureKind.PLOT, Vector2(101, 100))
	s.add(StructureKind.CATCHMENT, Vector2(102, 100))
	s.people.append(1)
	plot.staffed_by = 1
	var report := SettlementRules.catch_up(s, 4320.0, ctx())
	gt(float((report["spoiled"] as Dictionary).get(&"berries", 0)), 0.0, "nowhere to put it, so it was lost")
	lt(s.stored(), s.store_room() + 0.001, "and the holding never holds more than it has room for")


func test_a_piece_staffed_by_somebody_who_has_gone_is_a_piece_standing_empty() -> void:
	var s := a_place()
	var plot := s.add(StructureKind.PLOT, Vector2(101, 100))
	plot.staffed_by = 7
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 60.0, ctx())
	eq(plot.staffed_by, -1, "nobody by that name lives here")


func test_the_dark_is_when_a_window_gives_a_place_away_and_smoke_is_when_it_does_not() -> void:
	var s := a_place()
	s.add(StructureKind.HEARTH, Vector2(101, 100))
	s.night = 0.0
	var day := s.signature()
	s.night = 1.0
	var dark := s.signature()
	gt(dark.light, day.light, "a hearth is seen further at night")
	lt(dark.smoke, day.smoke, "and its smoke is seen less")
	near(SettlementRules.night_at(13.0 * 60.0), 0.0, 1e-4, "one in the afternoon is broad day")
	near(SettlementRules.night_at(23.0 * 60.0), 1.0, 1e-4, "eleven at night is night")


func test_a_piece_falling_apart_gives_less_away_than_one_kept_up() -> void:
	var s := a_place()
	var mast := s.add(StructureKind.RADIO_MAST, Vector2(101, 100))
	mast.powered = true
	var whole := s.signature().total()
	mast.health = mast.max_health * 0.3
	lt(s.signature().total(), whole, "a mast held together with cord does not carry as far")


func test_a_holding_settled_after_a_week_away_does_not_stall_the_load() -> void:
	var s := a_place()
	var plot := s.add(StructureKind.PLOT, Vector2(101, 100))
	s.people.append(1)
	plot.staffed_by = 1
	var t0 := Time.get_ticks_msec()
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 60.0 * 24.0 * 30.0, ctx())
	lt(float(Time.get_ticks_msec() - t0), 300.0 * machine_slack(), "a month away is settled in a blink")
	near(s.worked_at, floorf(60.0 * 24.0 * 30.0 / SettlementRules.SLICE) * SettlementRules.SLICE, 1e-4,
		"and the holding's clock is up to date either way")
