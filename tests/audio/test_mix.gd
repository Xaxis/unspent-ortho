extends TestCase
## The mix sheet holds the research: 0 dB is the weather bed at full strength,
## thunder alone sits +6..+10, world events -4..+5, the interface at or under
## -6; nothing carries its weight below 120 Hz; nothing clips.
## Every sound is audited by tools/audio.sh; here a representative of each
## family is rendered so the gate stays fast.

const Fixture := preload("res://tests/audio/audio_fixture.gd")


func _sample_keys() -> Array[StringName]:
	var keys: Array[StringName] = [&"weather_rain", &"bed_shore", &"shore_gull:0", &"pines_creak:2", &"thunder:0", &"thunder_far:1", &"music_burning:0"]
	for name: StringName in SoundBank.SHEET:
		var cat := SoundBank.category_of(name)
		if cat in [&"event", &"step", &"ui", &"machine"]:
			keys.append(SoundBank.key_for(name, 0))
	return keys


func test_every_sheet_level_sits_in_its_category_window() -> void:
	for name: StringName in SoundBank.SHEET:
		var row: Array = SoundBank.SHEET[name]
		var win: Array = SoundBank.CATEGORIES[row[0]]["window"]
		var heard: float = row[1]
		check(heard >= win[0] and heard <= win[1], "%s at %+.1f dB is outside %s %s" % [name, heard, row[0], str(win)])
		check(int(row[2]) >= 1, "%s needs at least one variant" % name)


func test_the_weather_bed_at_full_strength_is_the_reference() -> void:
	eq(SoundBank.SHEET[&"weather_rain"][1], 0.0, "rain is 0 dB")
	var rain := Fixture.baked(&"weather_rain")
	near(SoundMix.heard_db(rain), 0.0, 0.05, "rain measured")


func test_heard_levels_measured_from_samples_match_the_sheet() -> void:
	for key in _sample_keys():
		var b := Fixture.baked(key)
		var win: Array = SoundBank.CATEGORIES[b.category]["window"]
		var heard := SoundMix.heard_db(b)
		check(heard >= win[0] - 0.05 and heard <= win[1] + 0.05, "%s heard %+.2f dB outside %s" % [key, heard, str(win)])
		near(heard, b.heard, 0.05, "%s measured vs sheet" % key)
		# A recipe that needs a wild gain to reach its level is a broken recipe.
		check(b.gain_db > -30.0 and b.gain_db < 18.0, "%s needs %+.1f dB of call gain" % [key, b.gain_db])
		lt(Synth.peak(b.samples), 0.9, "%s peak" % key)


func test_nothing_carries_its_weight_below_120_hz() -> void:
	for key in _sample_keys():
		var b := Fixture.baked(key)
		var limit := 0.15 if b.category == &"thunder" else 0.06
		lt(Synth.low_energy_ratio(b.samples, b.rate, 120.0), limit, "%s below 120 Hz" % key)


func test_interface_is_quietest_and_thunder_is_loudest() -> void:
	var ui_max := -INF
	var event_min := INF
	var event_max := -INF
	var thunder_min := INF
	for name: StringName in SoundBank.SHEET:
		var row: Array = SoundBank.SHEET[name]
		match row[0]:
			&"ui": ui_max = maxf(ui_max, row[1])
			&"event", &"step":
				event_min = minf(event_min, row[1])
				event_max = maxf(event_max, row[1])
			&"thunder": thunder_min = minf(thunder_min, row[1])
	lt(ui_max, event_min, "interface under world events")
	lt(event_max, thunder_min, "thunder over everything")
	lt(ui_max, -5.99, "interface at or under -6 dB")


func test_a_refusal_is_a_different_sound_not_a_louder_one() -> void:
	var yes := Fixture.baked(&"ui_accept")
	var no := Fixture.baked(&"ui_back")
	check(SoundMix.heard_db(no) <= SoundMix.heard_db(yes) + 0.05, "back is no louder than accept")
	# Accept climbs E5 to B5; back falls A4 to E4. The notes share harmonics (an
	# E4 string rings at B5 too), so judge the notes back has that accept cannot,
	# and where each sound's weight sits.
	for f: float in [329.63, 440.0]:
		var yes_lo := Synth.tone_level(yes.samples, yes.rate, f, 0, 8192)
		var no_lo := Synth.tone_level(no.samples, no.rate, f, 0, 8192)
		gt(no_lo, yes_lo * 4.0, "back has %.0f Hz and accept does not (%.4f vs %.4f)" % [f, no_lo, yes_lo])
	var yes_c := Synth.centroid(yes.samples, yes.rate, 0, 8192)
	var no_c := Synth.centroid(no.samples, no.rate, 0, 8192)
	gt(yes_c, no_c * 1.3, "accept sits higher than back (%.0f Hz vs %.0f Hz)" % [yes_c, no_c])


func test_buses_are_made_in_code_with_the_research_levels() -> void:
	SoundBuses.ensure()
	SoundBuses.ensure()
	for row: Array in SoundMix.BUSES:
		var idx := AudioServer.get_bus_index(row[0])
		check(idx >= 0, "bus %s" % row[0])
		if idx < 0:
			continue
		near(AudioServer.get_bus_volume_db(idx), float(row[2]), 1e-4, "%s volume" % row[0])
		eq(AudioServer.get_bus_send(idx), row[1], "%s send" % row[0])
	near(db_to_linear(SoundMix.bus_db(&"SFX")), 0.75, 0.005, "sfx bus 0.75")
	near(db_to_linear(SoundMix.bus_db(&"Ambience")), 0.255, 0.003, "beds 0.255")
	eq(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Machines")), 2, "ensure twice adds effects once")
	check(SoundBuses.machine_lowpass() != null, "machines low-pass by distance")
