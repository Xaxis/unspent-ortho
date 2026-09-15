extends TestCase
## Beds are placed by the world: the country under the player turning toward
## its neighbour by blend, the sea by distance and side, weather by kind and
## strength. Every name the rules can ask for exists in the sheet.

const Fixture := preload("res://tests/audio/audio_fixture.gd")


## A 96-tile world (off the map counts as sea, as on every real coast): sea in the west ten columns, moss land turning toward
## pinewood along the middle.
func _world() -> WorldData:
	var w := WorldData.new(3, 96)
	for y in 96:
		for x in 96:
			var i := y * 96 + x
			if x < 10:
				w.level[i] = 0
				w.ground[i] = Ground.WATER
				w.country[i] = Country.SEA
			else:
				w.level[i] = 2
				w.ground[i] = Ground.MOSS
				w.country[i] = Country.MOSS
				w.country2[i] = Country.PINEWOOD
				w.blend[i] = clampf((x - 10) / 60.0, 0.0, 0.5)
	return w


func test_country_weights_turn_toward_the_neighbour_by_blend() -> void:
	var w := _world()
	var at := Vector2(28.5, 20.5)
	var weights := SoundMix.country_weights(w, at)
	var bl: float = w.blend[20 * 96 + 28]
	near(float(weights.get(&"bed_moss", 0.0)), 1.0 - bl, 1e-5, "moss")
	near(float(weights.get(&"bed_pines", 0.0)), bl, 1e-5, "pines")
	var pure := SoundMix.country_weights(w, Vector2(10.5, 5.5))
	near(float(pure.get(&"bed_moss", 0.0)), 1.0, 1e-5, "pure moss at blend 0")


func test_the_sea_is_found_with_its_distance_and_its_side() -> void:
	var w := _world()
	var near_sea := SoundMix.sea_near(w, Vector2(20.5, 30.5))
	near(float(near_sea["distance"]), 10.5, 1.0, "sea distance")
	lt((near_sea["direction"] as Vector2).x, -0.9, "the sea is west")
	var far := SoundMix.sea_near(w, Vector2(45.5, 48.5))
	check(is_inf(float(far["distance"])), "no sea within 24 tiles")


func test_shore_fades_out_with_distance_from_the_sea() -> void:
	near(SoundMix.shore_weight(1.0), 1.0)
	var prev := 1.0
	for d in range(2, 30):
		var s := SoundMix.shore_weight(float(d))
		check(s <= prev + 1e-6, "shore rises with distance at %d" % d)
		prev = s
	eq(SoundMix.shore_weight(22.0), 0.0, "gone by 22 tiles")


func test_weather_beds_follow_kind_and_strength_and_damp_the_land() -> void:
	var w := _world()
	var p := Vector2(40.5, 40.5)
	var calm := SoundMix.bed_levels(w, p, {"kind": &"fair", "strength": 0.0, "wind": 0.0}, {"distance": INF}, {"distance": INF}, 0.0)
	var rain := SoundMix.bed_levels(w, p, {"kind": &"rain", "strength": 0.6, "wind": 0.0}, {"distance": INF}, {"distance": INF}, 0.0)
	near(float(rain[&"weather_rain"]), 0.6, 1e-6, "rain at 0.6")
	eq(float(rain[&"weather_storm"]), 0.0, "no storm bed in rain")
	lt(float(rain[&"bed_moss"]), float(calm[&"bed_moss"]), "rain softens the country")
	var fog := SoundMix.bed_levels(w, p, {"kind": &"fog", "strength": 1.0, "wind": 0.0}, {"distance": INF}, {"distance": INF}, 0.0)
	lt(float(fog[&"bed_moss"]), float(calm[&"bed_moss"]), "fog softens the country")
	var gale := SoundMix.bed_levels(w, p, {"kind": &"fair", "strength": 0.0, "wind": 1.0}, {"distance": INF}, {"distance": INF}, 12.0)
	gt(float(gale[&"weather_gust"]), 0.0, "a full wind gusts")
	eq(float(calm[&"weather_gust"]), 0.0, "no gusts in a calm")


func test_weather_of_any_shape_is_normalised() -> void:
	var a := SoundMix.normalize_weather({"kind": "Rain", "strength": 2.0, "wind": -3.0})
	eq(a["kind"], &"rain")
	eq(a["strength"], 1.0)
	eq(a["wind"], -1.0)
	eq(SoundMix.normalize_weather(null)["kind"], &"fair")
	var fallback := SoundMix.weather_at(1, 600.0)
	check(fallback.has("kind") and fallback.has("strength") and fallback.has("wind"), "weather_at always answers")


func test_gusts_breathe_between_a_lull_and_full() -> void:
	var lo := INF
	var hi := -INF
	for t in range(0, 3000, 3):
		var g := SoundMix.gust(float(t))
		lo = minf(lo, g)
		hi = maxf(hi, g)
	gt(lo, 0.09, "never dead")
	lt(hi, 1.01, "never over")
	gt(hi - lo, 0.6, "gusts vary")


func test_every_bed_the_rules_can_ask_for_exists() -> void:
	for c: int in SoundMix.COUNTRY_BED:
		check(SoundBank.has_sound(SoundMix.COUNTRY_BED[c]), "country bed %s" % SoundMix.COUNTRY_BED[c])
	for k: StringName in SoundMix.WEATHER_BED:
		check(SoundBank.has_sound(SoundMix.WEATHER_BED[k]), "weather bed %s" % SoundMix.WEATHER_BED[k])
	for bed: StringName in SoundBeds.SCATTER:
		check(SoundBank.has_sound(bed), "scattering bed %s" % bed)
		for entry: Array in SoundBeds.SCATTER[bed]:
			check(SoundBank.has_sound(entry[0]), "scatter %s" % entry[0])
			check(float(entry[1]) > 0.0 and float(entry[2]) >= float(entry[1]), "gap range for %s" % entry[0])
	for g in Ground.COUNT:
		check(SoundBank.has_sound(SoundEffects.step_name(g)), "footfall for ground %s" % Ground.NAMES[g])
	for c: int in Country.LAND:
		check(SoundBank.has_sound(SoundMusic.name_for(c)), "music for %s" % Country.NAMES[c])
	for name: StringName in SoundBeds.LENGTH:
		check(SoundBank.has_sound(name), "bed length for unknown %s" % name)


func test_the_shore_loop_is_its_wave_cycles_and_seamless() -> void:
	var b := Fixture.baked(&"bed_shore")
	eq(b.samples.size(), roundi(SoundBeds.LENGTH[&"bed_shore"] * b.rate), "shore length")
	var cycles: float = SoundBeds.LENGTH[&"bed_shore"] / SoundBeds.SHORE_CYCLE
	near(cycles, roundf(cycles), 1e-6, "whole wave cycles")
	lt(Synth.seam_ratio(b.samples), 1.5, "shore seam")
	var rain := Fixture.baked(&"weather_rain")
	lt(Synth.seam_ratio(rain.samples), 1.5, "rain seam")
