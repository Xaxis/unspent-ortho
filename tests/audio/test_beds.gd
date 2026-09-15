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


## Moss west of x = 48, pinewood east of it, no sea; blend everywhere `bl`.
func _two_countries(bl: float) -> WorldData:
	var w := WorldData.new(4, 96)
	for y in 96:
		for x in 96:
			var i := y * 96 + x
			w.level[i] = 2
			w.ground[i] = Ground.MOSS if x < 48 else Ground.NEEDLES
			w.country[i] = Country.MOSS if x < 48 else Country.PINEWOOD
			w.country2[i] = Country.PINEWOOD if x < 48 else Country.MOSS
			w.blend[i] = bl
	return w


func test_country_weights_turn_toward_the_neighbour_by_blend() -> void:
	var pure := SoundMix.country_weights(_two_countries(0.0), Vector2(15.5, 40.5))
	near(float(pure.get(&"bed_moss", 0.0)), 1.0, 1e-5, "deep in the moss, only moss")
	var blended := SoundMix.country_weights(_two_countries(0.3), Vector2(15.5, 40.5))
	near(float(blended.get(&"bed_moss", 0.0)), 0.7, 1e-5, "blend 0.3 turns it toward pinewood")
	near(float(blended.get(&"bed_pines", 0.0)), 0.3, 1e-5, "by exactly that")


func test_the_next_country_is_heard_before_it_is_underfoot() -> void:
	var w := _two_countries(0.0)
	var prev := -1.0
	var worst := 0.0
	for k in 81:
		var x := 28.0 + k * 0.5
		var weights := SoundMix.country_weights(w, Vector2(x, 40.5))
		var sum := 0.0
		for bed: StringName in weights:
			sum += float(weights[bed])
		near(sum, 1.0, 1e-5, "weights sum to 1 at %.1f" % x)
		var pines := float(weights.get(&"bed_pines", 0.0))
		if prev >= 0.0:
			check(pines >= prev - 1e-6, "pines never fall walking toward them (at %.1f)" % x)
			worst = maxf(worst, pines - prev)
		prev = pines
		if x == 44.5:
			check(pines > 0.1 and pines < 0.5, "4 tiles short of the pines they are already heard: %.2f" % pines)
	lt(worst, 0.2, "a border with no blend painted is still a crossfade, never a switch")


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
	var power := 0.0
	for bed in SoundMix.RAIN_SURFACES:
		power += float(rain[bed]) * float(rain[bed])
	near(sqrt(power), 0.6, 1e-5, "rain at 0.6, over whatever it falls on")
	gt(float(rain[&"weather_rain_water"]), 0.0, "in the moss some of it falls on black water")
	eq(float(rain[&"weather_storm"]), 0.0, "no storm bed in rain")
	lt(float(rain[&"bed_moss"]), float(calm[&"bed_moss"]), "rain softens the country")
	var fog := SoundMix.bed_levels(w, p, {"kind": &"fog", "strength": 1.0, "wind": 0.0}, {"distance": INF}, {"distance": INF}, 0.0)
	lt(float(fog[&"bed_moss"]), float(calm[&"bed_moss"]), "fog softens the country")
	var gale := SoundMix.bed_levels(w, p, {"kind": &"fair", "strength": 0.0, "wind": 1.0}, {"distance": INF}, {"distance": INF}, 12.0)
	gt(float(gale[&"weather_gust"]), 0.0, "a full wind gusts")
	eq(float(calm[&"weather_gust"]), 0.0, "no gusts in a calm")


func test_the_works_around_the_listener_are_found_by_name() -> void:
	var w := _two_countries(0.0)
	var q := WorldQuery.new(w)
	var at := Vector2(30.5, 30.5)
	var none := SoundMix.works_near(q, at)
	check(is_inf(float(none["installation"])) and is_inf(float(none["shelter"])), "open fen: nothing made")
	eq(float(none["wreck"]), 0.0)
	var id := 800000
	for spec: Array in [[PropKind.PYLON, Vector2(6, 0)], [PropKind.WRECK, Vector2(3, 2)], [PropKind.HOUSE, Vector2(-9, 0)], [PropKind.PINE, Vector2(0, 4)], [PropKind.PINE, Vector2(1, 5)]]:
		var prop := WorldProp.new(id, spec[0], at + spec[1], 0.0, 1.0)
		w.props.append(prop)
		q.add_prop(prop)
		id += 1
	var some := SoundMix.works_near(q, at)
	near(float(some["installation"]), 6.0, 0.01, "the pylon six tiles off")
	eq(float(some["grid"]), 0.0, "is too far off to hear its grid")
	near(float(some["shelter"]), 3.6, 0.1, "a wreck is a roof the rain drums on, nearer than the house")
	gt(float(some["wreck"]), 0.1, "wreckage the wind can find")
	gt(float(some["leaves"]), 0.0, "and canopy")
	eq(SoundMix.prop_class(PropKind.BOULDER), 0, "a boulder is none of these")
	w.depleted[800001] = INF
	lt(float(SoundMix.works_near(q, at)["wreck"]), float(some["wreck"]), "a wreck taken apart is no longer heard")


## Neon means something only where it stands (VISION §8): a village's power
## poles only sing faintly in the wind, a lone pylon's grid and hum are heard
## under it, several together carry further, and a name is judged by whole words.
func test_an_installation_is_heard_where_it_stands_and_a_pole_only_sings() -> void:
	eq(SoundMix.name_words("Dead tree-stump"), PackedStringArray(["dead", "tree", "stump"]), "whole words")
	eq(SoundMix._has_word(SoundMix.name_words("scarecrow"), SoundMix.WRECK_WORDS), "", "a scarecrow is no car")
	eq(SoundMix._has_word(SoundMix.name_words("rusted wrecks"), SoundMix.WRECK_WORDS), "wreck", "wrecks are wreckage")
	eq(SoundMix._has_word(SoundMix.name_words("gatehouse"), SoundMix.INSTALLATION_WORDS), "", "no installation hides inside a longer word")
	var pole := SoundMix.prop_class(PropKind.POLE)
	eq(pole & SoundMix.INSTALLATION, 0, "a pole is not an installation")
	eq(pole & SoundMix.WRECK, 0, "nor wreckage")
	check(pole & SoundMix.WIRE != 0, "it carries wire")
	check(SoundMix.prop_class(PropKind.PYLON) & SoundMix.INSTALLATION != 0, "a pylon is the machines'")
	for k: int in [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT, PropKind.STACK, PropKind.DRILL_RIG, PropKind.CONVEYOR, PropKind.RELAY]:
		check(SoundMix.prop_class(k) & SoundMix.INSTALLATION != 0, "the land's %s is the machines' and hums" % PropKind.NAMES[k])
	for k: int in [PropKind.DEBRIS, PropKind.VEHICLE, PropKind.HULL, PropKind.FENCE, PropKind.BARRICADE]:
		check(SoundMix.prop_class(k) & SoundMix.WRECK != 0, "a %s is wreckage the wind finds" % PropKind.NAMES[k])
	check(SoundMix.prop_class(PropKind.SHACK) & SoundMix.SHELTER != 0, "a shack's roof takes the rain")
	eq(SoundMix.prop_class(PropKind.GRAVE) & SoundMix.INSTALLATION, 0, "a grave hums nothing")
	var w := _two_countries(0.0)
	var q := WorldQuery.new(w)
	var at := Vector2(30.5, 30.5)
	var pole_prop := WorldProp.new(810000, PropKind.POLE, at + Vector2(1.5, 0), 0.0, 1.0)
	w.props.append(pole_prop)
	q.add_prop(pole_prop)
	var by_pole := SoundMix.works_near(q, at)
	eq(float(by_pole["grid"]), 0.0, "no grid under a pole")
	eq(float(by_pole["hum"]), 0.0, "no transformer hum")
	gt(float(by_pole["wires"]), 0.9, "only its wire")
	lt(SoundBeds.works_scatter_level("wires", by_pole), SoundMix.WIRE_FAINT + 1e-6, "singing faintly")
	q.remove_prop(pole_prop)
	var pylon := WorldProp.new(810001, PropKind.PYLON, at + Vector2(1.5, 0), 0.0, 1.0)
	w.props.append(pylon)
	q.add_prop(pylon)
	var under := SoundMix.works_near(q, at)
	gt(float(under["grid"]), 0.95, "under a pylon, its whole grid")
	gt(float(under["hum"]), 0.9, "and its hum")
	var reach := SoundMix.installation_reach(PropKind.PYLON)
	var lone := float(SoundMix.works_near(q, at + Vector2(-2.5, 0))["grid"])
	lt(lone, 0.5, "four tiles from a lone pylon, less than half (%.2f)" % lone)
	eq(float(SoundMix.works_near(q, at + Vector2(-reach, 0))["grid"]), 0.0, "past its reach, nothing")
	var id := 810002
	for off: Vector2 in [Vector2(1.5, 2.0), Vector2(1.5, -2.0)]:
		var more := WorldProp.new(id, PropKind.PYLON, at + off, 0.0, 1.0)
		w.props.append(more)
		q.add_prop(more)
		id += 1
	gt(float(SoundMix.works_near(q, at + Vector2(-2.5, 0))["grid"]), lone * 2.0, "several together carry further")


## On a real island the grid and the hum stay where the machines' lines run.
func test_the_grid_and_hum_are_never_everywhere() -> void:
	var world := WorldGen.generate(1, Tuning.WORLD_SIZE)
	var q := WorldQuery.new(world)
	var land := 0
	var grid := 0
	var hum := 0
	var village := 0
	var village_grid := 0
	for y in range(3, world.size, 8):
		for x in range(3, world.size, 8):
			if Ground.is_water(world.ground[y * world.size + x]):
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var works := SoundMix.works_near(q, p)
			land += 1
			grid += 1 if float(works["grid"]) > 0.0 else 0
			hum += 1 if float(works["hum"]) > 0.05 else 0
			for v: Dictionary in world.villages:
				if (v["pos"] as Vector2).distance_to(p) < 20.0:
					village += 1
					village_grid += 1 if float(works["grid"]) > 0.0 else 0
					break
	lt(100.0 * grid / land, 8.0, "the grid on %.1f%% of the land" % (100.0 * grid / land))
	lt(100.0 * hum / land, 8.0, "the hum on %.1f%% of the land" % (100.0 * hum / land))
	lt(100.0 * village_grid / maxi(1, village), 15.0, "and on %.1f%% of the ground by the villages" % (100.0 * village_grid / maxi(1, village)))


func test_the_dystopia_is_heard_where_it_stands() -> void:
	var w := _two_countries(0.0)
	var p := Vector2(20.5, 40.5)
	var calm := {"kind": &"clear", "strength": 0.0, "wind": 0.1}
	var gale := {"kind": &"clear", "strength": 0.0, "wind": 0.9}
	var far := {"distance": INF}
	var open := SoundMix.bed_levels(w, p, gale, far, far, 5.0, {})
	eq(float(open[&"bed_wreck"]), 0.0, "no wreckage, nothing for the wind to sing in")
	eq(float(open[&"bed_hum"]), 0.0, "no installation, no hum")
	var wrecked := SoundMix.bed_levels(w, p, gale, far, far, 5.0, {"wreck": 1.0})
	var wrecked_calm := SoundMix.bed_levels(w, p, calm, far, far, 5.0, {"wreck": 1.0})
	gt(float(wrecked[&"bed_wreck"]), float(wrecked_calm[&"bed_wreck"]) * 1.8, "the wreckage sings in a gale, murmurs in a calm")
	var prev := 1.1
	for d: float in [1.0, 4.0, 8.0, 12.0, 16.0]:
		var share := pow(SoundMix.installation_share(d, SoundMix.INSTALLATION_REACH_DEFAULT), 1.5)
		var hum := float(SoundMix.bed_levels(w, p, calm, far, far, 0.0, {"hum": share})[&"bed_hum"])
		check(hum <= prev, "the hum falls away with distance (%.2f at %.0f tiles)" % [hum, d])
		prev = hum
	eq(prev, 0.0, "gone past %.0f tiles" % SoundMix.INSTALLATION_REACH_DEFAULT)
	gt(float(open[&"bed_far_drone"]) + float(wrecked_calm[&"bed_far_drone"]), 0.0, "the machines far off are there by day")
	var night_remote := SoundMix.bed_levels(w, p, calm, far, far, 0.0, {"hour": 23.0, "remote": 1.0})
	var day_village := SoundMix.bed_levels(w, p, calm, far, far, 0.0, {"hour": 12.0, "remote": 0.0})
	gt(float(night_remote[&"bed_far_drone"]), float(day_village[&"bed_far_drone"]) * 2.0, "loudest far from people at night")
	var dry := SoundMix.bed_levels(w, p, calm, far, far, 0.0, {"shelter": 2.0, "wet": 0.0})
	var after_rain := SoundMix.bed_levels(w, p, calm, far, far, 0.0, {"shelter": 2.0, "wet": 0.8})
	eq(float(dry[&"bed_gutter"]), 0.0, "dry gutters are silent")
	gt(float(after_rain[&"bed_gutter"]), 0.6, "wet ones run beside a roof, even once the rain has stopped")


func test_rain_keeps_its_loudness_and_changes_its_surface() -> void:
	var w := _two_countries(0.0)
	var far := {"distance": INF}
	var rain := {"kind": &"rain", "strength": 0.8, "wind": 0.2}
	var places := {
		"open moss": [Vector2(20.5, 40.5), far, {}],
		"pinewood": [Vector2(80.5, 40.5), far, {"leaves": 0.6}],
		"shore": [Vector2(20.5, 40.5), {"distance": 2.0}, {}],
		"wreckyard": [Vector2(80.5, 40.5), far, {"wreck": 1.0, "shelter": 3.0}],
	}
	var surface := {}
	for name: String in places:
		var at: Array = places[name]
		var lv := SoundMix.bed_levels(w, at[0], rain, at[1], far, 0.0, at[2])
		var power := 0.0
		for bed in SoundMix.RAIN_SURFACES:
			power += float(lv[bed]) * float(lv[bed])
		near(sqrt(power), 0.8, 1e-5, "%s: the rain is as loud as ever" % name)
		surface[name] = lv
	gt(float(surface["pinewood"][&"weather_rain_leaves"]), 0.5, "in the pines it falls on needles")
	gt(float(surface["shore"][&"weather_rain_water"]), float(surface["pinewood"][&"weather_rain_water"]), "by the sea on water")
	gt(float(surface["wreckyard"][&"weather_rain_metal"]), 0.5, "in a wreckyard it drums on metal")
	var storm := SoundMix.bed_levels(w, Vector2(80.5, 40.5), {"kind": &"storm", "strength": 1.0, "wind": 0.9}, far, far, 0.0, {"wreck": 1.0})
	gt(float(storm[&"weather_rain_metal"]), 0.3, "a storm drums on metal too")
	var dry := SoundMix.bed_levels(w, Vector2(80.5, 40.5), {"kind": &"snow", "strength": 1.0, "wind": 0.2}, far, far, 0.0, {"wreck": 1.0})
	for bed in SoundMix.RAIN_SURFACES:
		eq(float(dry[bed]), 0.0, "snow is not rain (%s)" % bed)


func test_an_installations_hum_is_exact_and_loops() -> void:
	var b := Fixture.baked(&"bed_hum")
	lt(Synth.seam_ratio(b.samples), 2.0, "the hum loops without a seam")
	var n := b.samples.size()
	var h200 := Synth.tone_level(b.samples, b.rate, 200.0, 0, n)
	var off := Synth.tone_level(b.samples, b.rate, 250.0, 0, n)
	gt(h200, off * 10.0, "its harmonics sit exactly on 100 Hz multiples")
	lt(float(Fixture.facts(&"bed_hum")["lf120"]), 0.06, "its fundamental is left under the laptop line")


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
		for layer: StringName in ScoreStems.LAYERS:
			check(SoundBank.has_sound(ScoreStems.name_for(StringName(Country.NAMES[c]), layer)), "score %s for %s" % [layer, Country.NAMES[c]])
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


func _stand_in_weather() -> GDScript:
	var gd := GDScript.new()
	gd.source_code = """extends RefCounted
static func at(_s: int, _m: float) -> Dictionary:
	return {"kind": &"rain", "strength": 1.0, "wind": 0.2}
static func at_place(_s: int, _m: float, c: int) -> Dictionary:
	return {"kind": &"snow" if c == 4 else &"rain", "strength": 0.8, "wind": -0.3}
static func tide(_m: float) -> float:
	return 0.9
"""
	gd.reload()
	return gd


func _restore_weather() -> void:
	SoundMix.use_weather_script(load(SoundMix.WEATHER_PATH) if ResourceLoader.exists(SoundMix.WEATHER_PATH) else null)


func test_weather_is_read_for_the_country_underfoot() -> void:
	SoundMix.use_weather_script(_stand_in_weather())
	eq(SoundMix.weather_at(1, 600.0, Country.SNOWFIELD)["kind"], &"snow", "the front snows on the snowfield")
	eq(SoundMix.weather_at(1, 600.0, Country.COAST)["kind"], &"rain", "and rains on the coast")
	eq(SoundMix.weather_at(1, 600.0)["kind"], &"rain", "no country: Weather.at")
	near(SoundMix.tide_at(600.0), 0.9, 1e-6, "the tide comes from the sky's rules")
	_restore_weather()


func test_every_kind_the_sky_can_send_is_heard_or_deliberately_silent() -> void:
	var w := _world()
	var p := Vector2(40.5, 40.5)
	var silent := [&"clear", &"grey", &"fog", &"heat"]
	for kind: StringName in [&"clear", &"grey", &"rain", &"storm", &"fog", &"hail", &"snow", &"blizzard", &"ash", &"heat", &"dust"]:
		var lv := SoundMix.bed_levels(w, p, {"kind": kind, "strength": 0.7, "wind": 0.1}, {"distance": INF}, {"distance": INF}, 3.0)
		if kind in silent:
			check(not SoundMix.WEATHER_BED.has(kind), "%s has no bed" % kind)
			continue
		var bed: StringName = SoundMix.WEATHER_BED.get(kind, &"")
		check(SoundBank.has_sound(bed), "%s has a bed" % kind)
		var level := float(lv.get(bed, 0.0))
		if kind == &"rain":
			# Rain is spread over the surfaces it falls on, at the same power.
			var power := 0.0
			for surface in SoundMix.RAIN_SURFACES:
				power += float(lv[surface]) * float(lv[surface])
			level = sqrt(power)
		near(level, 0.7, 1e-5, "%s bed at its strength" % kind)
		var others := 0.0
		for other: StringName in SoundMix.WEATHER_BED.values():
			if other != bed:
				others += float(lv.get(other, 0.0))
		eq(others, 0.0, "only %s's bed is up" % kind)
	gt(float(SoundMix.bed_levels(w, p, {"kind": &"blizzard", "strength": 1.0, "wind": 0.0}, {"distance": INF}, {"distance": INF}, 3.0)[&"weather_gust"]), 0.5, "a blizzard gusts even between winds")
	# The landscapes' own kinds sound as the kind each acts like (Weather.family).
	for kind: StringName in Weather.FAMILY:
		var fam: StringName = Weather.family(kind)
		var lv := SoundMix.bed_levels(w, p, {"kind": kind, "strength": 0.7, "wind": 0.1}, {"distance": INF}, {"distance": INF}, 3.0)
		var same := SoundMix.bed_levels(w, p, {"kind": fam, "strength": 0.7, "wind": 0.1}, {"distance": INF}, {"distance": INF}, 3.0)
		eq(lv, same, "%s is heard as %s" % [kind, fam])
	for kind: StringName in SoundMix.WEATHER_SCATTER:
		check(SoundBank.has_sound(SoundMix.WEATHER_SCATTER[kind][0]), "weather scatter for %s" % kind)


func test_the_far_works_carry_on_still_nights_far_from_people() -> void:
	var w := _world()
	w.villages.append({"pos": Vector2(40.5, 40.5), "country": Country.MOSS, "name": "x"})
	var p := Vector2(90.5, 90.5)
	near(SoundMix.remoteness(w, Vector2(40.5, 42.5)), 0.0, 1e-6, "no works heard in a village")
	near(SoundMix.remoteness(w, p), 1.0, 1e-6, "well out of reach")
	var calm := {"kind": &"clear", "strength": 0.0, "wind": 0.05}
	var none := {"distance": INF}
	var night := float(SoundMix.bed_levels(w, p, calm, none, none, 0.0, {"hour": 23.0, "remote": 1.0})[&"bed_far_works"])
	var noon := float(SoundMix.bed_levels(w, p, calm, none, none, 0.0, {"hour": 12.0, "remote": 1.0})[&"bed_far_works"])
	var windy := float(SoundMix.bed_levels(w, p, {"kind": &"clear", "strength": 0.0, "wind": 0.9}, none, none, 0.0, {"hour": 23.0, "remote": 1.0})[&"bed_far_works"])
	var rain := float(SoundMix.bed_levels(w, p, {"kind": &"rain", "strength": 1.0, "wind": 0.05}, none, none, 0.0, {"hour": 23.0, "remote": 1.0})[&"bed_far_works"])
	var village := float(SoundMix.bed_levels(w, p, calm, none, none, 0.0, {"hour": 23.0, "remote": 0.0})[&"bed_far_works"])
	gt(night, 0.9, "a still night far out")
	check(noon > 0.0 and noon <= SoundMix.FAR_WORKS_DAY + 1e-6, "only a trace by day (%.2f vs %.2f at night)" % [noon, night])
	lt(windy, 0.05, "wind takes it")
	lt(rain, 0.15, "rain takes it")
	eq(village, 0.0, "not among people")


func test_high_water_brings_the_shore_closer() -> void:
	var w := _world()
	var p := Vector2(14.5, 40.5)
	var calm := {"kind": &"clear", "strength": 0.0, "wind": 0.0}
	var sea := SoundMix.sea_near(w, p)
	var low := float(SoundMix.bed_levels(w, p, calm, sea, {"distance": INF}, 0.0, {"tide": 0.0})[&"bed_shore"])
	var high := float(SoundMix.bed_levels(w, p, calm, sea, {"distance": INF}, 0.0, {"tide": 1.0})[&"bed_shore"])
	gt(high, low * 1.2, "high water is louder (%.2f vs %.2f)" % [high, low])


func test_walking_over_a_border_crossfades_without_a_step() -> void:
	var w := _two_countries(0.0)
	var t := SoundScene.levels_over_time({"at": Vector2(30.5, 40.5), "walk": Vector2(5.0, 0.0), "secs": 7.0, "hour": 12.0,
		"weather": {"kind": &"clear", "strength": 0.0, "wind": 0.3}}, w)
	var moss: PackedFloat32Array = t["lanes"][&"bed_moss"]
	var pines: PackedFloat32Array = t["lanes"][&"bed_pines"]
	gt(moss[0], pines[0] * 5.0, "starts in the moss")
	gt(pines[-1], moss[-1] * 5.0, "ends in the pines")
	var worst := 0.0
	for b in range(1, moss.size()):
		worst = maxf(worst, maxf(absf(moss[b] - moss[b - 1]), absf(pines[b] - pines[b - 1])))
	lt(worst, 0.03, "no bed jumps more than 3% in a twentieth of a second")
	var crossed := -1
	for b in moss.size():
		if pines[b] > moss[b]:
			crossed = b
			break
	var at_cross: Vector2 = t["path"][crossed]
	# Where the countries meet, plus the fade's lag at a walk (BED_FADE s at 5 tiles/s).
	near(at_cross.x, 48.0 + SoundMix.BED_FADE * 5.0, 2.0, "the beds cross where the countries do (%.1f)" % at_cross.x)


func test_living_scatter_keeps_its_hours_and_its_weather() -> void:
	var fair := {"kind": &"clear", "strength": 0.0, "wind": 0.2}
	var gull: Array = SoundBeds.SCATTER[&"bed_shore"][0]
	eq(gull[0], &"shore_gull")
	check(SoundMix.scatter_allowed(gull, 12.0, fair), "gulls at noon")
	check(not SoundMix.scatter_allowed(gull, 23.0, fair), "no gulls at night")
	check(not SoundMix.scatter_allowed(gull, 12.0, {"kind": &"storm", "strength": 0.8, "wind": 0.9}), "no gulls in a storm")
	check(SoundMix.scatter_allowed(gull, 12.0, {"kind": &"fog", "strength": 0.9, "wind": 0.0}), "gulls cry in fog")
	var birds := 0
	for bed: StringName in SoundBeds.SCATTER:
		for entry: Array in SoundBeds.SCATTER[bed]:
			if entry[0] == &"bird_song":
				birds += 1
				check(SoundMix.scatter_allowed(entry, 6.0, fair), "birds at first light in %s" % bed)
				check(not SoundMix.scatter_allowed(entry, 14.0, fair), "not all day in %s" % bed)
				check(not SoundMix.scatter_allowed(entry, 6.0, {"kind": &"rain", "strength": 0.7, "wind": 0.3}), "not in rain in %s" % bed)
	gt(float(birds), 1.0, "a dawn is heard in more than one country")
	for bed: StringName in SoundBeds.SCATTER:
		for entry: Array in SoundBeds.SCATTER[bed]:
			check(SoundMix.scatter_allowed([entry[0], entry[1], entry[2]], 3.0, fair), "entries without conditions always allowed")


func test_nights_fall_calmer() -> void:
	var w := WorldData.new(5, 48)
	for i in 48 * 48:
		w.level[i] = 2
		w.ground[i] = Ground.GRASS
		w.country[i] = Country.COAST
	var none := {"distance": INF}
	var weather := {"kind": &"clear", "strength": 0.0, "wind": 0.4}
	var day := float(SoundMix.bed_levels(w, Vector2(24, 24), weather, none, none, 5.0, {"hour": 13.0})[&"bed_wind"])
	var night := float(SoundMix.bed_levels(w, Vector2(24, 24), weather, none, none, 5.0, {"hour": 2.0})[&"bed_wind"])
	lt(night, day * 0.8, "the wind drops at night (%.2f vs %.2f)" % [night, day])


func test_night_wet_and_windy_scatter_conditions() -> void:
	var calm := {"kind": &"clear", "strength": 0.0, "wind": 0.1}
	var wisp := [&"moss_wisp", 1.0, 2.0, {"hours": [21.0, 4.5]}]
	check(SoundMix.scatter_allowed(wisp, 23.5, calm), "wisps before midnight")
	check(SoundMix.scatter_allowed(wisp, 2.0, calm), "and after it")
	check(not SoundMix.scatter_allowed(wisp, 12.0, calm), "not at noon")
	var drip := [&"pines_drip", 1.0, 2.0, {"wet": [&"rain", &"storm"]}]
	check(not SoundMix.scatter_allowed(drip, 12.0, calm), "no drip in the dry")
	check(SoundMix.scatter_allowed(drip, 12.0, {"kind": &"rain", "strength": 0.6, "wind": 0.2}), "drip in rain")
	check(not SoundMix.scatter_allowed(drip, 12.0, {"kind": &"rain", "strength": 0.05, "wind": 0.2}), "not at the first spots")
	var wire := [&"wire_sing", 1.0, 2.0, {"wind": 0.45}]
	check(not SoundMix.scatter_allowed(wire, 12.0, calm), "wires quiet in a calm")
	check(SoundMix.scatter_allowed(wire, 12.0, {"kind": &"clear", "strength": 0.0, "wind": -0.7}), "wires sing in a wind from either side")


func test_the_next_country_is_baked_while_it_is_a_walk_away() -> void:
	var w := _two_countries(0.0)
	var ahead := SoundMix.beds_ahead(w, Vector2(24.5, 40.5))
	check(ahead.has(&"bed_moss"), "here")
	check(ahead.has(&"bed_pines"), "and the pines 24 tiles east")
	eq(SoundMix.beds_ahead(w, Vector2(24.5, 40.5), 10.0), [&"bed_moss"] as Array[StringName], "not when far off")
