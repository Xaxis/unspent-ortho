extends TestCase


func test_weather_is_a_multiply_that_never_brightens_toward_white() -> void:
	for k: StringName in WeatherLook.MULTIPLY:
		var m: Vector3 = WeatherLook.MULTIPLY[k]
		check(m.x <= 1.0 and m.y <= 1.0 and m.z <= 1.0, "%s multiply <= 1" % k)
	for k: StringName in Weather.KINDS:
		check(WeatherLook.MULTIPLY.has(k), "every kind has a multiply: %s" % k)
		check(WeatherLook.COVER.has(k), "every kind has a cloud cover: %s" % k)


func test_zero_strength_is_no_weather_at_all() -> void:
	for k: StringName in Weather.KINDS:
		var l := WeatherLook.compose([{"kind": k, "strength": 0.0, "weight": 1.0}])
		lt((l.tint as Vector3 - Vector3.ONE).length(), 1e-6, "%s tint" % k)
		for f: String in ["rain", "hail", "snow", "ash", "dust", "fog", "heat", "overcast", "storm"]:
			near(float(l[f]), 0.0, 1e-6, "%s %s" % [k, f])


func test_full_rain_rains_and_hides_the_sun() -> void:
	var l := WeatherLook.compose([{"kind": &"rain", "strength": 1.0, "weight": 1.0}])
	gt(l.rain, 0.5, "rain falls")
	gt(l.overcast, 0.6, "sun hidden")
	_near3(l.tint, WeatherLook.MULTIPLY[&"rain"], "rain multiply")
	var s := WeatherLook.compose([{"kind": &"storm", "strength": 1.0, "weight": 1.0}])
	near(s.storm, 1.0, 1e-6, "storm strength carried for lightning")


func test_a_border_mixes_weathers_by_share() -> void:
	var half := WeatherLook.compose([
		{"kind": &"rain", "strength": 1.0, "weight": 0.5},
		{"kind": &"snow", "strength": 1.0, "weight": 0.5},
	])
	var rain := WeatherLook.compose([{"kind": &"rain", "strength": 1.0, "weight": 1.0}])
	var snow := WeatherLook.compose([{"kind": &"snow", "strength": 1.0, "weight": 1.0}])
	near(half.rain, rain.rain * 0.5, 1e-6, "half the rain")
	near(half.snow, snow.snow * 0.5, 1e-6, "half the snow")
	# Continuity: a small change in share makes a small change in the look.
	var a := WeatherLook.compose([{"kind": &"storm", "strength": 1.0, "weight": 0.50}, {"kind": &"clear", "strength": 0.0, "weight": 0.50}])
	var b := WeatherLook.compose([{"kind": &"storm", "strength": 1.0, "weight": 0.51}, {"kind": &"clear", "strength": 0.0, "weight": 0.49}])
	lt((a.tint as Vector3 - b.tint).length(), 0.01, "tint continuous")
	lt(absf(a.rain - b.rain), 0.02, "rain continuous")


func test_each_country_signature_weather_draws_its_marks() -> void:
	gt(WeatherLook.compose([{"kind": &"snow", "strength": 1.0, "weight": 1.0}]).snow, 0.5, "snow")
	gt(WeatherLook.compose([{"kind": &"ash", "strength": 1.0, "weight": 1.0}]).ash, 0.5, "ash")
	gt(WeatherLook.compose([{"kind": &"fog", "strength": 1.0, "weight": 1.0}]).fog, 0.5, "fog")
	gt(WeatherLook.compose([{"kind": &"heat", "strength": 1.0, "weight": 1.0}]).heat, 0.5, "heat")
	gt(WeatherLook.compose([{"kind": &"dust", "strength": 1.0, "weight": 1.0}]).dust, 0.5, "dust")


func _near3(a: Vector3, b: Vector3, msg: String) -> void:
	lt((a - b).length(), 1e-4, "%s: %s vs %s" % [msg, a, b])


func test_a_fair_sky_shades_at_most_a_quarter_of_the_land() -> void:
	for k: StringName in WeatherLook.COVER:
		lt(float((WeatherLook.COVER[k] as Array)[0]), 0.25, "%s at strength 0 leaves the day bright" % k)
	var fair := WeatherLook.compose([{"kind": &"clear", "strength": 0.0, "weight": 1.0}])
	lt(float(fair.cover), 0.25, "a clear day's clouds are a scatter, not an overcast")


func test_a_storm_rains_without_a_fog_veil() -> void:
	var storm := WeatherLook.compose([{"kind": &"storm", "strength": 1.0, "weight": 1.0}])
	near(float(storm.fog), 0.0, 1e-6, "no fog in a storm")
	gt(float(storm.rain), 0.9, "it pours")
