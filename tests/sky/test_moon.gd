extends TestCase
## THE MOON HAS PHASES (Weather.moon_phase, SkyLight.moon_share): time, not
## worldgen, so no seed moves. Nights vary: a full moon lights the land, and a
## new-moon night is truly dark where only the land's own lights show. The first
## night of a game is the full moon, which is also what keeps every frame shot on
## day 1 (the canon's) exactly where it was.


func test_the_first_night_is_the_full_moon() -> void:
	for hour: float in [19.5, 21.0, 23.0, 26.0]:
		near(SkyLight.moon_share(Weather.moon_phase(hour * 60.0)), 1.0, 0.01,
			"day 1 at %.1f h is lit by a full moon" % hour)


func test_the_moon_wanes_to_new_and_back() -> void:
	var half := Weather.LUNAR_DAYS * 0.5 * 1440.0 + Weather.MOON_FULL_AT
	lt(SkyLight.moon_share(Weather.moon_phase(half)), 0.2, "half a month on, the moon is new")
	near(SkyLight.moon_share(Weather.moon_phase(half * 2.0 - Weather.MOON_FULL_AT)), 1.0, 0.01, "and a month on, full again")
	var prev := 2.0
	var m := Weather.MOON_FULL_AT
	while m < half:
		var s := SkyLight.moon_share(Weather.moon_phase(m))
		lt(s, prev + 1e-6, "it only wanes on the way to new (%.0f)" % m)
		prev = s
		m += 360.0


func test_a_new_moon_takes_the_moon_off_the_land_and_leaves_the_rest() -> void:
	var sky := SkyLight.new()
	tree.root.add_child(sky)
	sky.set_hour(23.0)
	sky.moon_phase = 0.0
	sky.compose()
	var full := sky.sun.light_energy
	sky.moon_phase = 0.5
	sky.compose()
	var new_moon := sky.sun.light_energy
	lt(new_moon, full * 0.25, "a new-moon night has almost no moonlight")
	gt(new_moon, 0.0, "but the sky is not switched off")
	sky.set_hour(12.0)
	sky.moon_phase = 0.5
	sky.compose()
	var noon_new := sky.sun.light_energy
	sky.moon_phase = 0.0
	sky.compose()
	near(noon_new, sky.sun.light_energy, 1e-5, "and noon does not know what the moon is doing")
	sky.queue_free()
	await frames(1)
