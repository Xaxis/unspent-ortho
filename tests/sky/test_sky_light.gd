extends TestCase


func test_tint_keys_match_the_source_exactly() -> void:
	# Night before 0.22, dawn at 0.30, noon 0.40-0.70, dusk at 0.80, night from 0.90.
	_v(SkyLight.tint_at(0.10 * 24.0), Vector3(0.56, 0.64, 0.90) * 0.82, "night")
	_v(SkyLight.tint_at(0.30 * 24.0), Vector3(1.00, 0.84, 0.70) * 0.86, "dawn")
	_v(SkyLight.tint_at(0.55 * 24.0), Vector3(1.00, 1.00, 0.99), "noon")
	_v(SkyLight.tint_at(0.80 * 24.0), Vector3(0.98, 0.74, 0.58) * 0.80, "dusk")
	_v(SkyLight.tint_at(0.95 * 24.0), Vector3(0.56, 0.64, 0.90) * 0.82, "late night")


func test_tint_is_continuous_across_the_whole_day_and_midnight() -> void:
	var prev := SkyLight.tint_at(23.99)
	for i in 24 * 60 + 1:
		var h := i / 60.0
		var t := SkyLight.tint_at(h)
		lt((t - prev).length(), 0.02, "jump at %.2f h" % h)
		prev = t
	_v(SkyLight.tint_at(0.0), SkyLight.tint_at(24.0), "midnight wraps")
	_v(SkyLight.tint_at(-1.0), SkyLight.tint_at(23.0), "negative hours wrap")


func test_night_is_blue_not_black() -> void:
	var t := SkyLight.tint_at(2.0) * Weather.light_level(2.0)
	gt(t.z, t.x, "blue over red")
	gt(t.z, 0.35, "blue channel keeps light")
	gt(t.x + t.y + t.z, 0.8, "not black")


func test_nothing_casts_at_night_and_the_sun_casts_by_day() -> void:
	for h: float in [0.0, 1.0, 2.0, 3.0, 4.0, 4.9, 20.6, 21.5, 23.0]:
		check(not SkyLight.sun_at(h).casts, "casts at %.1f" % h)
	for h: float in [6.0, 7.0, 9.0, 12.0, 15.0, 18.0, 19.5, 20.0]:
		check(SkyLight.sun_at(h).casts, "no shadow at %.1f" % h)
	lt(SkyLight.sun_at(2.0).energy, SkyLight.sun_at(12.0).energy, "moonlight is dim")


func test_sun_swings_seventy_degrees_about_the_key_and_never_jumps() -> void:
	var lo := INF
	var hi := -INF
	var prev := SkyLight.sun_at(23.99)
	for i in 24 * 60:
		var h := i / 60.0
		var s := SkyLight.sun_at(h)
		lo = minf(lo, s.azimuth)
		hi = maxf(hi, s.azimuth)
		lt(absf(float(s.azimuth) - float(prev.azimuth)), 0.5, "azimuth jump at %.2f" % h)
		lt(absf(float(s.elevation) - float(prev.elevation)), 1.0, "elevation jump at %.2f" % h)
		prev = s
	near(hi - lo, 70.0, 0.01, "swing")
	near((hi + lo) * 0.5, SkyLight.KEY_AZIMUTH, 0.01, "about the key")


func test_shadows_are_short_at_noon_and_long_at_the_day_ends() -> void:
	var noon: float = SkyLight.sun_at(12.75).elevation
	var morning: float = SkyLight.sun_at(6.0).elevation
	gt(noon, morning + 10.0, "noon sun higher")
	# At noon a caster's shadow is half its screen height: steep light.
	gt(noon, 65.0, "noon elevation")


func test_region_cast_follows_the_source_formula() -> void:
	_v(SkyLight.cast_tint(0.0, 0.0), Vector3.ONE, "neutral")
	var fire := SkyLight.country_tint(Country.BURNING)
	var ice := SkyLight.country_tint(Country.SNOWFIELD)
	var fen := SkyLight.country_tint(Country.MOSS)
	near(maxf(fire.x, maxf(fire.y, fire.z)), 1.0, 1e-6, "normalised")
	gt(fire.x, fire.z, "burning is warm")
	gt(ice.z, ice.x, "snowfield is cold")
	gt(fen.y, fen.x, "moss is green")
	gt(fen.y, fen.z, "moss is green over blue")
	# r = 1 + .075w - .03d, g = 1 - .02|w| + .015d, b = 1 - .085w - .045d, / max
	var c := Vector3(1.0 + 0.075 * 0.5 - 0.03 * -0.2, 1.0 - 0.02 * 0.5 + 0.015 * -0.2, 1.0 - 0.085 * 0.5 - 0.045 * -0.2)
	_v(SkyLight.cast_tint(0.5, -0.2), c / c.x, "formula")


func test_season_drains_blue_most() -> void:
	var d := SkyLight.season_drain(1.0)
	_v(d, Vector3(1.06, 0.96, 0.87), "full drain")
	_v(SkyLight.season_drain(0.0), Vector3.ONE, "no drain on day one")


func _v(a: Vector3, b: Vector3, msg: String) -> void:
	lt((a - b).length(), 1e-4, "%s: %s vs %s" % [msg, a, b])
