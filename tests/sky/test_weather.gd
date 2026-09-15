extends TestCase


func test_same_seed_and_minute_give_the_same_weather() -> void:
	Weather.unforce()
	for seed_value: int in [1, 7, 20260905]:
		for m: float in [0.0, 480.0, 1234.5, 9999.0, 40000.0]:
			for c: int in Country.LAND:
				var a := Weather.at_place(seed_value, m, c)
				var b := Weather.at_place(seed_value, m, c)
				eq(a.kind, b.kind, "kind")
				eq(a.strength, b.strength, "strength")
				eq(a.wind, b.wind, "wind")
	check(Weather.at(3, 600.0).kind == Weather.at_place(3, 600.0, Country.COAST).kind, "at() reads the coast")


func test_strength_is_zero_wherever_the_kind_changes() -> void:
	Weather.unforce()
	for seed_value: int in [1, 2, 11]:
		for c: int in Country.LAND:
			var prev := Weather.at_place(seed_value, 0.0, c)
			var changes := 0
			# Ten-minute steps over thirty days; a change is only ever seen where
			# strength has already fallen to (nearly) nothing.
			var m := 10.0
			while m < 30.0 * 1440.0:
				var w := Weather.at_place(seed_value, m, c)
				if w.kind != prev.kind:
					changes += 1
					lt(prev.strength, 0.001, "strength before %s->%s at %d" % [prev.kind, w.kind, m])
					lt(w.strength, 0.001, "strength after %s->%s at %d" % [prev.kind, w.kind, m])
				prev = w
				m += 10.0
			gt(changes, 5, "kinds change over thirty days (country %d)" % c)


func test_strength_and_wind_never_jump() -> void:
	Weather.unforce()
	var bad := 0
	for i in 6000:
		var m := i * 7.3
		var c: int = Country.LAND[i % Country.LAND.size()]
		var a := Weather.at_place(4, m, c)
		var b := Weather.at_place(4, m + 0.05, c)
		if a.kind != b.kind:
			continue
		if absf(a.strength - b.strength) > 0.005 or absf(a.wind - b.wind) > 0.01:
			bad += 1
			if bad < 5:
				fail("jump at %f (%s): strength %f->%f wind %f->%f" % [m, a.kind, a.strength, b.strength, a.wind, b.wind])


func test_spells_last_seventeen_hours_with_sin_squared_strength() -> void:
	Weather.unforce()
	var s := 5
	var m := 3000.0
	var i := Weather.spell_index(s, m)
	var p := Weather.spell_phase(s, m)
	var start := m - p * Weather.SPELL_MINUTES
	eq(Weather.spell_index(s, start + 1.0), i, "same spell just after start")
	eq(Weather.spell_index(s, start + Weather.SPELL_MINUTES - 1.0), i, "same spell just before end")
	eq(Weather.spell_index(s, start + Weather.SPELL_MINUTES + 1.0), i + 1, "next spell")
	near(Weather.spell_phase(s, start + Weather.SPELL_MINUTES * 0.5), 0.5, 1e-3, "mid phase")


func test_every_country_table_sums_to_one_hundred_and_has_its_signature_weather() -> void:
	for c in Weather.TABLES.size():
		var total := 0
		for row: Array in Weather.TABLES[c]:
			total += int(row[1])
			check(Weather.KINDS.has(row[0]), "known kind %s" % row[0])
		eq(total, 100, "table %d" % c)
	var seen := {}
	for c: int in Country.LAND:
		seen[c] = {}
		for spell in 400:
			seen[c][Weather.kind_for(9, spell, c)] = true
	for k: StringName in [Weather.RAIN, Weather.STORM, Weather.FOG]:
		check(seen[Country.COAST].has(k), "coast has %s" % k)
		check(seen[Country.MOSS].has(k), "moss has %s" % k)
	check(seen[Country.SNOWFIELD].has(Weather.SNOW), "snow on the snowfield")
	check(not seen[Country.SNOWFIELD].has(Weather.RAIN), "no rain on the snowfield")
	check(seen[Country.BURNING].has(Weather.ASH), "ash-fall in the burning")
	check(seen[Country.BURNING].has(Weather.HEAT), "heat in the burning")
	check(seen[Country.BONELANDS].has(Weather.HEAT), "heat in the bonelands")
	check(not seen[Country.BURNING].has(Weather.SNOW), "no snow in the burning")


func test_clear_hardens_to_grey_after_the_turning() -> void:
	for spell in 200:
		var early := Weather.kind_for(4, spell, Country.COAST, 3)
		var late := Weather.kind_for(4, spell, Country.COAST, Weather.TURNING_DAY + 2)
		if early == Weather.CLEAR:
			eq(late, Weather.GREY, "spell %d" % spell)
		else:
			eq(late, early, "spell %d" % spell)


func test_forced_weather_is_seen_by_everyone_and_can_be_lifted() -> void:
	Weather.force(&"snow", 0.8)
	var w := Weather.at_place(1, 100.0, Country.BURNING)
	eq(w.kind, &"snow", "forced kind")
	near(w.strength, 0.8, 1e-6, "forced strength")
	eq(Weather.at(2, 5000.0).kind, &"snow", "at() too")
	Weather.unforce()
	eq(Weather.forced_kind, &"", "lifted")


func test_wind_is_bounded() -> void:
	Weather.unforce()
	for i in 3000:
		var m := i * 37.0
		var w := Weather.at_place(8, m, i % 7)
		check(w.wind >= -1.0 and w.wind <= 1.0, "wind %f" % w.wind)


func test_lightning_only_in_storms_and_more_at_their_height() -> void:
	var weak := 0
	var strong := 0
	for m in 4000:
		check(Weather.lightning(3, m, Weather.RAIN, 1.0) < 0.0, "no lightning in rain")
		if Weather.lightning(3, m, Weather.STORM, 0.3) >= 0.0:
			weak += 1
		var f := Weather.lightning(3, m, Weather.STORM, 1.0)
		if f >= 0.0:
			strong += 1
			check(f < 1.0, "fraction of the minute")
	gt(strong, weak * 3, "S^2 scaling")
	# 0.22 per minute at full strength.
	near(strong / 4000.0, 0.22, 0.03, "rate at full strength")
	gt(Weather.strike_distance(3, 5, 0.0), Weather.strike_distance(3, 5, 1.0), "strong storms strike close")


func test_night_fall_and_light_level_follow_the_source_clock() -> void:
	near(Weather.night_fall(12.0), 0.0, 1e-6, "noon")
	near(Weather.night_fall(20.5), 0.5, 1e-6, "half dark at 20:30")
	near(Weather.night_fall(23.0), 1.0, 1e-6, "night")
	near(Weather.night_fall(2.0), 1.0, 1e-6, "small hours")
	near(Weather.night_fall(5.25), 0.5, 1e-6, "half light at 05:15")
	near(Weather.night_fall(6.0), 0.0, 1e-6, "dawn done")
	near(Weather.night_fall(24.0), Weather.night_fall(0.0), 1e-6, "wraps")
	near(Weather.light_level(0.0), 1.0 - 0.62 * 0.68, 1e-6, "darkest light")
	gt(Weather.light_level(0.0), 0.5, "night is not black")


func test_tide_has_two_highs_a_day_and_starts_low() -> void:
	near(Weather.tide(0.0), 0.0, 1e-6, "low at t=0")
	near(Weather.tide(372.5), 1.0, 1e-6, "high a quarter-period later")
	near(Weather.tide(745.0), 0.0, 1e-6, "low again")
	check(Weather.is_low_tide(10.0), "low tide")
	check(Weather.is_high_tide(372.0), "high tide")
	check(Weather.tide_rising(100.0), "rising after low")
	check(not Weather.tide_rising(500.0), "falling after high")


func test_season_drains_then_holds() -> void:
	near(Weather.season_turn(0.0), 0.0, 1e-6)
	near(Weather.season_turn(17.0 * 1440.0), 0.5, 1e-6)
	near(Weather.season_turn(90.0 * 1440.0), 1.0, 1e-6)


func test_nothing_settles_without_weather_and_forced_snow_builds() -> void:
	Weather.force(&"clear", 0.0)
	var s := Weather.settled(1, 5000.0, Country.COAST)
	near(s.snow + s.ash + s.wet, 0.0, 1e-6, "clear skies leave nothing")
	Weather.force(&"snow", 1.0)
	var early := Weather.settled(1, 5000.0, Country.SNOWFIELD)
	gt(early.snow, 0.9, "a long snowfall covers the ground")
	near(early.wet, 0.0, 1e-6, "snow is not rain")
	Weather.force(&"rain", 1.0)
	gt(Weather.settled(1, 5000.0, Country.COAST).wet, 0.9, "a long rain soaks it")
	Weather.unforce()


func test_settled_cover_is_continuous_and_lags_the_weather() -> void:
	Weather.unforce()
	var bad := 0
	var fell_after := 0
	for i in 800:
		var m := 2000.0 + i * 11.3
		var a := Weather.settled(6, m, Country.SNOWFIELD)
		var b := Weather.settled(6, m + 1.0, Country.SNOWFIELD)
		for k: String in ["snow", "ash", "wet"]:
			if absf(float(a[k]) - float(b[k])) > 0.02:
				bad += 1
		# Cover outlives the fall: snow still lies where none is falling.
		if Weather.at_place(6, m, Country.SNOWFIELD).strength < 0.01 and a.snow > 0.2:
			fell_after += 1
	eq(bad, 0, "cover never jumps in a minute")
	gt(fell_after, 0, "snow lies after it stops")
