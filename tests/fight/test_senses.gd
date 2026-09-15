extends TestCase
## Sight is dimmed by the dark (a lit lamp undoes it) and by weather, and grows
## with every filing; hearing is never dimmed; a ridge breaks a line.

const F := preload("res://tests/fight/fixture.gd")


func _at(hour: float) -> Moment:
	var m := Moment.new()
	m.minutes = hour * 60.0
	return m


func test_night_dims_sight_unless_the_lamp_is_lit() -> void:
	var row := Roster.row(&"harvester")
	var day := Senses.sight_range(row, _at(12.0))
	near(day, 9.0, 0.001, "sees 9 by day")
	var night := Senses.sight_range(row, _at(23.0))
	near(night, 9.0 * (1.0 - 0.8 * 0.62), 0.001, "about half at full dark")
	var lamp := _at(23.0)
	lamp.lamp_lit = true
	near(Senses.sight_range(row, lamp), 9.0, 0.001, "a lamp undoes the dark")
	near(Senses.sight_range(row, _at(20.5)), 9.0 * (1.0 - 0.8 * 0.62 * 0.5), 0.001, "half way through the dusk ramp")


func test_hearing_is_never_dimmed() -> void:
	var row := Roster.row(&"dog.yard")
	var night := _at(2.0)
	var fog := _at(12.0)
	fog.weather = &"fog"
	fog.weather_strength = 1.0
	near(Senses.hearing_range(row, night), 14.0, 0.001, "night")
	near(Senses.hearing_range(row, fog), 14.0, 0.001, "fog")
	lt(Senses.sight_range(row, fog), 8.0 * 0.56, "but fog takes sight")
	var laden := _at(12.0)
	laden.laden_tier = 2
	near(Senses.hearing_range(row, laden), 14.0 * 1.7, 0.001, "a heavy load is heard further")


func test_filing_raises_sight() -> void:
	var row := Roster.row(&"warden")
	var m := _at(12.0)
	var before := Senses.sight_range(row, m)
	m.filed = 2
	near(Senses.sight_range(row, m), before * 1.5, 0.001, "two filings, half as far again")
	m.filed = 9
	near(Senses.sight_range(row, m), before * 2.0, 0.001, "never more than double")


func test_a_watcher_goes_by_eye_alone() -> void:
	eq(Senses.hearing_range(Roster.row(&"watcher"), _at(12.0)), 0.0)


func test_night_lets_you_walk_closer() -> void:
	var w := F.flat_world(64)
	var q := WorldQuery.new(w)
	var row := Roster.row(&"cutter") # hears only 2
	var a := Vector2(10.5, 10.5)
	var b := Vector2(18.5, 10.5)
	check(Senses.notices(row, a, b, _at(12.0), w, q), "seen at 8 tiles by day")
	check(not Senses.notices(row, a, b, _at(1.0), w, q), "not at night")
	var lamp := _at(1.0)
	lamp.lamp_lit = true
	check(Senses.notices(row, a, b, lamp, w, q), "unless the lamp is lit")


func test_lines_are_broken_by_ridges_and_big_props_not_trees() -> void:
	var w := F.flat_world(64)
	w.level[10 * 64 + 14] = 5
	var q := WorldQuery.new(w)
	check(not Senses.line_clear(w, q, Vector2(10.5, 10.5), Vector2(18.5, 10.5)), "a ridge between")
	check(Senses.line_clear(w, q, Vector2(10.5, 12.5), Vector2(18.5, 12.5)), "clear beside it")
	var w2 := F.flat_world(64)
	w2.props.append(WorldProp.new(1, PropKind.HOUSE, Vector2(14.5, 10.5), 0.0, 1.0))
	w2.props.append(WorldProp.new(2, PropKind.PINE, Vector2(14.5, 20.5), 0.0, 1.0))
	var q2 := WorldQuery.new(w2)
	check(not Senses.line_clear(w2, q2, Vector2(10.5, 10.5), Vector2(18.5, 10.5)), "a house hides you")
	check(Senses.line_clear(w2, q2, Vector2(10.5, 20.5), Vector2(18.5, 20.5)), "a pine does not")


func test_every_weather_the_sky_sends_cuts_sight_by_its_own_measure() -> void:
	var m := _at(12.0)
	m.weather_strength = 1.0
	for kind: StringName in [&"whiteout", &"dry_storm", &"haze", &"dust"]:
		m.weather = kind
		near(m.weather_sight(), Weather.sight_factor(kind, 1.0), 1e-6, "%s" % kind)
		lt(m.weather_sight(), 0.9, "%s takes sight" % kind)
	m.weather = &"sand"
	near(m.weather_sight(), Weather.sight_factor(&"dust", 1.0), 1e-6, "the roster's sand is the sky's dust")
