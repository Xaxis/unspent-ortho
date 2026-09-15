extends TestCase
## What the land can hold under the sky (SkyGround), and whose weather falls
## where: at a border, snow lies only on snow country, ash only on the burning,
## and the marks in the air follow the country under the focus.

const SkySystem := preload("res://src/systems/10_sky.gd")


func test_each_thing_lies_only_on_the_countries_that_make_it() -> void:
	var snow := SkyGround.capable(&"snowfield")
	var burn := SkyGround.capable(&"burning")
	eq(snow.x, 1.0, "snow lies on the snowfield")
	eq(snow.y, 0.0, "no ash on the snowfield")
	eq(burn.y, 1.0, "ash lies on the burning")
	eq(burn.x, 0.0, "no snow on burning clinker")
	eq(burn.z, 0.0, "the burning never rains, so it is never wet")
	eq(SkyGround.capable(&"moss").z, 1.0, "the moss gets wet")


func test_the_mask_blends_across_an_ecotone_and_knows_a_hollow() -> void:
	var w := WorldData.new(1, 32)
	for y in 32:
		for x in 32:
			var i := y * 32 + x
			w.country[i] = Country.SNOWFIELD if x < 16 else Country.BURNING
			# A ridge with a hollow dug in the middle of the burning half.
			w.level[i] = 1 if (absi(x - 24) < 2 and absi(y - 16) < 2) else 6
	var i_blend := 16 * 32 + 15
	w.blend[i_blend] = 0.5
	w.country2[i_blend] = Country.BURNING
	var img := SkyGround.image(w)
	var snow_side := img.get_pixel(4, 16)
	var burn_side := img.get_pixel(28, 8)
	gt(snow_side.r, 0.99, "snow may lie deep in the snowfield")
	lt(snow_side.g, 0.01, "ash may not")
	gt(burn_side.g, 0.99, "ash may lie deep in the burning")
	lt(burn_side.r, 0.01, "snow may not")
	near(img.get_pixel(15, 16).r, 0.5, 0.02, "half way across the ecotone, half")
	var ridge := img.get_pixel(4, 4).a * SkyGround.HEIGHT_RANGE
	near(ridge, 3.0, 0.2, "flat ground's smoothed height is its height")
	var around_hollow := img.get_pixel(24, 16).a * SkyGround.HEIGHT_RANGE
	gt(around_hollow - 0.5, 1.0, "a hollow sits well below its neighbourhood, so fog lies in it")


func test_marks_in_the_air_follow_the_landscape_under_the_focus() -> void:
	var w := WorldData.new(1, 16)
	for i in w.country.size():
		w.country[i] = Country.SNOWFIELD if (i % 16) < 8 else Country.BURNING
	eq(SkySystem.fall_type(w, Vector2(3, 3)), BiomeRegistry.at(w, Vector2(3, 3)).id, "the type BiomeRegistry finds")
	eq(SkySystem.fall_type(w, Vector2(3, 3)), &"snowfield", "snowfield")
	eq(SkySystem.fall_type(w, Vector2(12, 3)), &"burning", "burning")
	eq(SkySystem.fall_type(w, Vector2(-5, 99)), &"snowfield", "clamped to the map, never the sea beyond it")


func test_a_game_at_a_border_falls_one_country_and_lays_each_where_it_belongs() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 12.0
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var sky_sys: Node = null
	for s in g.systems:
		if s.get_script() == SkySystem:
			sky_sys = s
	check(sky_sys != null, "sky system loaded")
	var focus := Vector2(g.player.position.x, g.player.position.z)
	var here := SkySystem.fall_type(g.world, focus)
	var wx := Weather.at_type(g.world.seed_value, g.clock.minutes, here)
	var own := WeatherLook.compose([{"kind": wx.kind, "strength": wx.strength, "weight": 1.0}])
	await frames(2)
	for k: String in SkySystem.FALL_KEYS:
		near(float(sky_sys.look[k]), float(own[k]), 0.05, "%s falls as the focus country's own" % k)
	g.queue_free()
	await frames(1)
