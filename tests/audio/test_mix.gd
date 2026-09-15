extends TestCase
## The mix sheet holds the research: 0 dB is the weather bed at full strength,
## thunder alone sits +6..+10, world events -4..+5, the interface at or under
## -6; nothing carries its weight below 120 Hz; nothing clips.
## Every sound is audited by tools/audio.sh; here a representative of each
## family is rendered so the gate stays fast.

const Fixture := preload("res://tests/audio/audio_fixture.gd")


func _sample_keys() -> Array[StringName]:
	var keys: Array[StringName] = [&"weather_rain", &"bed_shore", &"shore_gull:0", &"pines_creak:2", &"thunder:0", &"thunder_far:1", &"music_burning:0", &"heat_tick:1"]
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
		var heard := float(Fixture.facts(key)["heard"])
		check(heard >= win[0] - 0.05 and heard <= win[1] + 0.05, "%s heard %+.2f dB outside %s" % [key, heard, str(win)])
		near(heard, b.heard, 0.05, "%s measured vs sheet" % key)
		# A recipe that needs a wild gain to reach its level is a broken recipe.
		check(b.gain_db > -30.0 and b.gain_db < 18.0, "%s needs %+.1f dB of call gain" % [key, b.gain_db])
		var peak := float(Fixture.facts(key)["peak"])
		lt(peak, 0.9, "%s peak" % key)
		# Heard levels are loudness; peaks must still fit after gain and buses,
		# so the master limiter only ever meets sums, never one sound alone.
		var out_db := 20.0 * log(peak) / log(10.0) + b.gain_db + SoundMix.bus_db(b.bus)
		lt(out_db, -0.5, "%s peaks at %+.1f dBFS after its gain and bus" % [key, out_db])
		# Its crest was fitted by limiting transients, not by squashing the sound.
		lt(b.limited_db, 16.0, "%s needed %.1f dB of limiting; soften the recipe's attack" % [key, b.limited_db])


func test_the_mix_is_loud_enough_for_laptop_speakers() -> void:
	check(SoundMix.REF_DBFS >= -22.0 and SoundMix.REF_DBFS <= -16.0, "the reference sits near -20 dBFS, got %.1f" % SoundMix.REF_DBFS)
	# A calm shore, deep in: the bed's loudest half-second after its gain and bus.
	var shore := Fixture.baked(&"bed_shore")
	var abs_db := 20.0 * log(Synth.loudest_rms(shore.samples, shore.rate, 0.5)) / log(10.0) + shore.gain_db + SoundMix.bus_db(shore.bus)
	gt(abs_db, -26.0, "a calm place is heard (%.1f dBFS)" % abs_db)
	var thunder := Fixture.baked(&"thunder:0")
	var peak_db := 20.0 * log(Synth.peak(thunder.samples)) / log(10.0) + thunder.gain_db + SoundMix.bus_db(thunder.bus)
	lt(peak_db, -0.5, "thunder alone stays under the limiter (%.1f dBFS)" % peak_db)


func test_nothing_carries_its_weight_below_120_hz() -> void:
	for key in _sample_keys():
		var b := Fixture.baked(key)
		var limit := 0.15 if b.category == &"thunder" else 0.06
		lt(float(Fixture.facts(key)["lf120"]), limit, "%s below 120 Hz" % key)


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
	for row: Array in SoundMix.BUSES:
		var idx := AudioServer.get_bus_index(row[0])
		lt(float(AudioServer.get_bus_index(row[1])), float(idx), "%s sends to a bus made before it" % row[0])
	eq(SoundMix.bus_db(&"Machines"), SoundMix.bus_db(&"Ambience"), "a machine bed sits where the country beds sit")
	check(SoundMix.bus_db(&"UI") < SoundMix.bus_db(&"SFX"), "the interface bus under world events")


func test_a_page_closes_over_the_world_bus_only() -> void:
	SoundBuses.ensure()
	var world := AudioServer.get_bus_index(&"World")
	SoundBuses.set_muffle(1.0)
	near(AudioServer.get_bus_volume_db(world), SoundMix.MUFFLE_DB, 1e-4, "muffled level")
	check(AudioServer.is_bus_effect_enabled(world, SoundBuses.WORLD_LOWPASS), "filter on")
	var lp := AudioServer.get_bus_effect(world, SoundBuses.WORLD_LOWPASS) as AudioEffectLowPassFilter
	near(lp.cutoff_hz, SoundMix.MUFFLE_HZ, 1.0, "cutoff")
	for bus: StringName in [&"Machines", &"UI", &"Music"]:
		eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), &"Master", "%s is not under the page" % bus)
	for bus: StringName in [&"SFX", &"Ambience"]:
		eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), &"World", "%s is under the page" % bus)
	SoundBuses.set_muffle(0.0)
	near(AudioServer.get_bus_volume_db(world), 0.0, 1e-4, "open air")
	check(not AudioServer.is_bus_effect_enabled(world, SoundBuses.WORLD_LOWPASS), "filter off")
