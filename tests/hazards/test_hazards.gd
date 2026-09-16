extends TestCase
## The hazard model: what a place puts on a body through the hour, the weather,
## the height, a roof and a fire; what gear takes off it; and the order it is
## allowed to happen in (felt, then slower, then a slow drain that never kills).


static func place(hazards: Dictionary, hour: float = 12.0) -> Hazards.Place:
	var p := Hazards.Place.new()
	p.hazards = hazards
	p.hour = hour
	return p


func test_a_landscape_type_is_where_a_pressure_comes_from() -> void:
	# What a type declares is its worst; at noon the sun takes some of it off.
	var snow := Hazards.felt(place({&"cold": 0.7}))
	gt(float(snow.get(&"cold", 0.0)), Hazards.FELT, "the snowfield is felt even at noon")
	lt(float(snow.get(&"cold", 0.0)), Hazards.BITE, "but it does not bite in the middle of the day")
	gt(float(Hazards.felt(place({&"cold": 0.7}, 2.0))[&"cold"]), Hazards.HARM, "and the same place at night is dangerous")
	check(not snow.has(&"heat"), "and nothing it does not declare")
	var burning := Hazards.felt(place({&"heat": 0.7, &"fumes": 0.5}))
	gt(float(burning.get(&"heat", 0.0)), 0.6, "the burning is hot at noon")
	near(float(burning.get(&"fumes", 0.0)), 0.5, 1e-5, "and its air is bad whatever the hour")
	# Every id the registry names is one this model knows, so a new landscape
	# type cannot declare a pressure nothing can read.
	for d in BiomeRegistry.all():
		for id: Variant in d.hazards:
			check(Hazards.IDS.has(StringName(id)), "%s declares %s, which is not a hazard" % [d.id, id])


func test_night_is_dark_and_colder_and_the_heat_goes_with_the_sun() -> void:
	var noon := Hazards.felt(place({&"cold": 0.5, &"heat": 0.5, &"dark": 0.5}, 12.0))
	var night := Hazards.felt(place({&"cold": 0.5, &"heat": 0.5, &"dark": 0.5}, 1.0))
	gt(float(night[&"cold"]), float(noon[&"cold"]), "a night is colder than the same place at noon")
	lt(float(night[&"heat"]), float(noon[&"heat"]), "and the heat went with the sun")
	gt(float(night[&"dark"]), Hazards.FELT, "a dark place after nightfall is dark enough to read")
	check(float(noon[&"dark"]) < float(night[&"dark"]), "and less so at noon")


## The clock is a multiplier on what the landscape declares, never a term of its
## own: this is what stops every coast in the world growing two gauges at 23:00.
func test_the_hour_never_makes_a_pressure_the_landscape_did_not_declare() -> void:
	var mild := Hazards.felt(place({&"wet": 0.3}, 23.0))
	check(not mild.has(&"dark"), "a landscape that declares no dark is not dark at midnight")
	check(not mild.has(&"cold"), "nor cold because the sun went down")
	lt(Hazards.worst(mild), Hazards.FELT, "nothing on the slate at all, as before there were gauges")
	# ...and the most the hour can add anywhere is under the biting step, by
	# construction: what bites after dark is the landscape, deepened, never the
	# clock on its own.
	lt(Hazards.NIGHT_MOST, Hazards.BITE, "the hour's own share cannot reach the biting step")
	# A pinewood that calls itself half-dark wants a lamp at three in the morning,
	# and is still not a place that kills you for walking through it.
	var wood := Hazards.felt(place({&"dark": 0.4}, 3.0))
	gt(float(wood[&"dark"]), Hazards.BITE, "a place that declares dark is worth a lamp at night")
	lt(float(wood[&"dark"]), Hazards.HARM, "and walking it unlit still only slows you")


func test_weather_moves_the_pressures_of_the_place_it_falls_on() -> void:
	var dry := place({&"cold": 0.2})
	var wet := place({&"cold": 0.2})
	wet.weather = &"rain"
	wet.weather_strength = 1.0
	gt(float(Hazards.felt(wet).get(&"wet", 0.0)), Hazards.FELT, "rain wets a body")
	check(not Hazards.felt(dry).has(&"wet"), "and a clear sky does not")
	var blown := place({&"cold": 0.4})
	blown.wind = -0.9
	gt(float(Hazards.felt(blown)[&"cold"]), 0.4, "wind takes the warmth off")
	# A newer weather kind is read through its family, so nothing new is ignored.
	var whiteout := place({&"cold": 0.3})
	whiteout.weather = &"whiteout"
	whiteout.weather_strength = 1.0
	gt(float(Hazards.felt(whiteout)[&"cold"]), Hazards.BITE, "a whiteout is a blizzard to a body")


func test_high_ground_is_colder_and_a_fire_and_a_roof_answer_it() -> void:
	var low := place({&"cold": 0.4}, 2.0)
	var high := place({&"cold": 0.4}, 2.0)
	high.level = Hazards.HIGH_LEVEL + 8
	gt(float(Hazards.felt(high)[&"cold"]), float(Hazards.felt(low)[&"cold"]), "higher is colder")
	var out_in_it := place({&"cold": 0.8}, 2.0)
	var by_fire := place({&"cold": 0.8}, 2.0)
	by_fire.fire = 1.0
	gt(float(Hazards.felt(out_in_it)[&"cold"]), Hazards.HARM, "a bitter night out in it is dangerous")
	lt(float(Hazards.felt(by_fire)[&"cold"]), Hazards.BITE, "a fire stops it biting: you sit it out")
	var rained_on := place({})
	rained_on.weather = &"rain"
	rained_on.weather_strength = 1.0
	var under_a_roof := place({})
	under_a_roof.weather = &"rain"
	under_a_roof.weather_strength = 1.0
	under_a_roof.shelter = 1.0
	lt(float(Hazards.felt(under_a_roof).get(&"wet", 0.0)), float(Hazards.felt(rained_on)[&"wet"]), "a roof keeps the rain off")
	var dark := place({&"dark": 0.7}, 1.0)
	var lit := place({&"dark": 0.7}, 1.0)
	lit.lamp = true
	lt(float(Hazards.felt(lit).get(&"dark", 0.0)), float(Hazards.felt(dark)[&"dark"]), "a lit lamp undoes the dark")
	var wading := place({})
	wading.in_water = true
	near(float(Hazards.felt(wading)[&"wet"]), 1.0, 1e-5, "standing in it soaks you whatever the sky does")
	# A wet land is damp underfoot and no more until you are in it or under rain.
	var damp := place({&"wet": 0.6})
	lt(float(Hazards.felt(damp)[&"wet"]), Hazards.BITE, "walking a wet land dry-shod does not soak you")
	var damp_rain := place({&"wet": 0.6})
	damp_rain.weather = &"rain"
	damp_rain.weather_strength = 1.0
	gt(float(Hazards.felt(damp_rain)[&"wet"]), Hazards.BITE, "the same land in the rain does")


func test_gear_takes_its_share_and_never_all_of_it() -> void:
	var raw := {&"cold": 0.8}
	near(float(Hazards.after_resist(raw, {})[&"cold"]), 0.8, 1e-5, "bare, you carry all of it")
	near(float(Hazards.after_resist(raw, {&"cold": 0.5})[&"cold"]), 0.4, 1e-5, "half of it kept off")
	var everything := Hazards.after_resist(raw, {&"cold": 1.0})
	gt(float(everything.get(&"cold", 0.0)), 0.0, "a trace always shows on the slate")
	near(float(everything[&"cold"]), 0.8 * (1.0 - Hazards.RESIST_CAP), 1e-5, "capped, not erased")
	check(not Hazards.after_resist({}, {&"cold": 0.5}).has(&"cold"), "resisting what is not there gives nothing")


func test_a_pressure_is_felt_then_bites_then_drains_in_that_order() -> void:
	lt(Hazards.FELT, Hazards.BITE, "felt before it bites")
	lt(Hazards.BITE, Hazards.HARM, "bites before it harms")
	eq(Hazards.level_of(0.1), 0)
	eq(Hazards.level_of(Hazards.FELT), 1)
	eq(Hazards.level_of(Hazards.BITE), 2)
	eq(Hazards.level_of(Hazards.HARM), 3)
	# Felt: seen and heard, and nothing else.
	near(Hazards.move_factor({&"cold": Hazards.FELT}), 1.0, 1e-6, "being felt costs nothing")
	near(Hazards.drain({&"cold": Hazards.BITE}, 600.0), 0.0, 1e-6, "and biting still costs no health")
	lt(Hazards.move_factor({&"cold": 1.0}), 1.0, "at its worst it is in the legs")
	gt(Hazards.move_factor({&"cold": 1.0}), 0.5, "but a body is never stopped by weather")
	near(Hazards.move_factor({&"cold": 1.0}), 1.0 - Hazards.SLOW, 1e-6)


func test_the_drain_is_slow_and_never_takes_the_last_point() -> void:
	var an_hour := Hazards.drain({&"cold": 1.0}, 60.0)
	lt(an_hour, 2.0, "an hour at the worst there is costs about a point")
	gt(an_hour, 0.5, "but it does cost something")
	eq(Hazards.drained_health(12, 3.4), 9, "whole points only")
	eq(Hazards.drained_health(2, 40.0), Hazards.HARM_FLOOR, "it stops before the last one")
	eq(Hazards.drained_health(1, 99.0), 1, "and never goes under it")
	# Two pressures at once are heavy on the legs, not twice as deadly.
	near(Hazards.drain({&"cold": 1.0, &"heat": 1.0}, 60.0), an_hour, 1e-6)


func test_the_worst_pressure_is_the_one_the_body_answers() -> void:
	eq(Hazards.worst_id({&"cold": 0.3, &"fumes": 0.8}), &"fumes")
	near(Hazards.worst({&"cold": 0.3, &"fumes": 0.8}), 0.8, 1e-6)
	eq(Hazards.worst_id({}), &"")
	near(Hazards.worst({}), 0.0, 1e-6)


func test_every_hazard_has_a_line_a_cue_and_a_glyph() -> void:
	for id in Hazards.IDS:
		check(Hazards.line_for(id) != "", "%s has a line when it starts to bite" % id)
		var cue := HazardCues.cue(id)
		check(cue.has("mark") and cue.has("sound"), "%s has a cue" % id)
		var sound := StringName(cue.get("sound", &""))
		if sound != &"":
			check(SoundBank.SHEET.has(SoundNames.resolve(sound)), "%s's cue sound %s is on the sheet" % [id, sound])
		check(UiIcons.NEEDS.has(id), "%s has its own glyph on the slate" % id)


func test_cues_come_faster_the_harder_it_presses_and_never_below_felt() -> void:
	eq(HazardCues.beat(Hazards.FELT - 0.01), INF, "nothing is drawn before it is felt")
	lt(HazardCues.beat(1.0), HazardCues.beat(Hazards.FELT), "harder means more often")
	near(HazardCues.beat(1.0), HazardCues.FAST_BEAT, 1e-5)
	near(HazardCues.beat(Hazards.FELT), HazardCues.SLOW_BEAT, 1e-5)
	for id in Hazards.IDS:
		var ramp := HazardCues.ramp(id)
		gt(float(ramp.size()), 3.0, "%s's cue has a colour ramp" % id)
