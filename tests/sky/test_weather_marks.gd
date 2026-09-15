extends TestCase
## What falls through the air, and what the sky hands the shaders.


func test_marks_start_and_stop_with_the_weather_without_restarting() -> void:
	var v := WeatherView.new()
	tree.root.add_child(v)
	v.setup(null)
	var look := WeatherLook.compose([{"kind": &"rain", "strength": 1.0, "weight": 1.0}])
	v.update(look, 0.5, Vector3.ZERO, 0.016)
	check(v.rain.emitting and v.rain.visible, "rain falls")
	check(v.splash.emitting, "rain splashes")
	check(not v.snow.emitting, "no snow in rain")
	var m: ShaderMaterial = v.rain.material_override
	gt(float(m.get_shader_parameter("slant")), 0.0, "a wind to the right leans strokes right")
	# Easing down never restarts the emitter: only the shader thins the marks.
	var light := WeatherLook.compose([{"kind": &"rain", "strength": 0.2, "weight": 1.0}])
	v.update(light, -0.5, Vector3.ZERO, 0.016)
	check(v.rain.emitting, "still falling as it eases")
	lt(float(m.get_shader_parameter("density")), 1.0, "thinner")
	lt(float(m.get_shader_parameter("slant")), 0.0, "leans with the wind")
	v.update(WeatherLook.compose([]), 0.0, Vector3.ZERO, 0.016)
	check(not v.rain.emitting and not v.rain.visible, "rain stops")
	# Still air still slants rain a little: straight-down strokes read as scratches.
	v.update(look, 0.0, Vector3.ZERO, 0.016)
	gt(absf(float(m.get_shader_parameter("slant"))), 0.2, "rain is always drawn on a slant")
	v.queue_free()
	await frames(1)


func test_a_strike_draws_a_bolt_that_flickers_out() -> void:
	var v := WeatherView.new()
	tree.root.add_child(v)
	v.setup(null)
	v.strike(Vector3(4, 0, 4), 77)
	check(v.bolt.visible, "bolt drawn")
	var calm := WeatherLook.compose([])
	for i in 30:
		v.update(calm, 0.0, Vector3.ZERO, 0.02)
	check(not v.bolt.visible, "gone after a few frames")
	v.strike(Vector3(4, 0, 4), 77, true)
	for i in 30:
		v.update(calm, 0.0, Vector3.ZERO, 0.02)
	check(v.bolt.visible, "a held strike stays for the shot")
	v.queue_free()
	await frames(1)


func test_lamp_pools_pack_one_per_column_for_the_ink() -> void:
	var pools: Array[Vector4] = [Vector4(1, 2, 3, 4.5), Vector4(5, 6, 7, 2.5)]
	var p := SkyLight.lamp_columns(pools)
	eq(p.size(), 2, "two mat4 globals")
	eq(p[0].x, Vector4(1, 2, 3, 4.5), "first pool in the first column")
	eq(p[0].y, Vector4(5, 6, 7, 2.5), "second pool")
	eq(p[0].z, Vector4.ZERO, "unused columns are empty")
	eq(p[1].w, Vector4.ZERO, "and in the second matrix")
	var many: Array[Vector4] = []
	for i in 11:
		many.append(Vector4(i, 0, 0, 1))
	var q := SkyLight.lamp_columns(many)
	eq(q[1].w, Vector4(7, 0, 0, 1), "eighth pool is the last")


func test_marks_fall_only_over_the_countries_that_make_them_unless_forced() -> void:
	Weather.unforce()
	var v := WeatherView.new()
	tree.root.add_child(v)
	v.setup(null)
	var look := WeatherLook.compose([{"kind": &"ash", "strength": 1.0, "weight": 0.5}, {"kind": &"snow", "strength": 1.0, "weight": 0.25}, {"kind": &"rain", "strength": 1.0, "weight": 0.25}])
	v.update(look, 0.2, Vector3.ZERO, 0.016)
	eq(int((v.ash.material_override as ShaderMaterial).get_shader_parameter("ground_mask")), 2, "ash over ash country")
	eq(int((v.snow.material_override as ShaderMaterial).get_shader_parameter("ground_mask")), 1, "snow over snow country")
	eq(int((v.rain.material_override as ShaderMaterial).get_shader_parameter("ground_mask")), 3, "rain over country that gets wet")
	Weather.force(&"ash", 1.0)
	v.update(look, 0.2, Vector3.ZERO, 0.016)
	eq(int((v.ash.material_override as ShaderMaterial).get_shader_parameter("ground_mask")), 0, "forced weather falls anywhere")
	Weather.unforce()
	v.queue_free()
	await frames(1)


func test_drizzle_rings_drips_and_devils_come_with_their_weather() -> void:
	Weather.unforce()
	var v := WeatherView.new()
	tree.root.add_child(v)
	v.setup(null)
	var drizzle := WeatherLook.compose([{"kind": &"drizzle", "strength": 1.0, "weight": 1.0}])
	v.update(drizzle, 0.1, Vector3.ZERO, 0.016)
	check(v.drizzle.emitting, "drizzle falls as its own fine grain")
	check(not v.rain.emitting, "not as rain strokes")
	check(v.rings.emitting, "and rings spread on standing water")
	var pts := PackedVector3Array([Vector3(1, 2, 1), Vector3(2, 2, 1)])
	v.set_drip_points(pts)
	v.set_drips(0.6, false)
	check(v.drips.emitting, "wet eaves drip")
	eq(v.drips.emission_points, pts, "from the points they were given")
	v.set_drips(0.6, true)
	check(not v.drips.emitting, "nothing drips in the snow")
	var devils: Array[Dictionary] = [{"at": Vector3(3, 1, 4), "life": 0.8, "seed": 5}]
	v.set_devils(devils)
	check(v.devils[0].visible, "a devil spins where it was placed")
	near((v.devils[0].global_position - Vector3(3, 1, 4)).length(), 0.0, 1e-4, "on its ground point")
	check(not v.devils[1].visible, "only as many as there are")
	var none: Array[Dictionary] = []
	v.set_devils(none)
	check(not v.devils[0].visible, "and gone when the dust settles")
	v.queue_free()
	await frames(1)


func test_snow_squall_and_whiteout_are_told_apart_at_a_glance() -> void:
	var v := WeatherView.new()
	tree.root.add_child(v)
	v.setup(null)
	var snow_mat: ShaderMaterial = v.snow.material_override
	# Flakes are a cold body with a pale glint, or they vanish over lying snow.
	gt(float(snow_mat.get_shader_parameter("highlight")), 0.5, "flakes carry a highlight")
	var body: Color = snow_mat.get_shader_parameter("color_a")
	lt(body.get_luminance(), 0.5, "the flake's body is darker than the snow it falls over")
	v.update(WeatherLook.compose([{"kind": &"snow", "strength": 1.0, "weight": 1.0}]), 0.2, Vector3.ZERO, 0.016)
	check(v.snow.emitting and v.flurry.emitting, "snow falls, with big flakes near the eye")
	check(not v.spindrift.emitting, "a squall in a light wind does not blow along the ground")
	gt(float(snow_mat.get_shader_parameter("columns")), 0.6, "a squall comes in dense curtains")
	v.update(WeatherLook.compose([{"kind": &"whiteout", "strength": 1.0, "weight": 1.0}]), 0.2, Vector3.ZERO, 0.016)
	check(v.spindrift.emitting, "a whiteout blows snow along the ground")
	near(float((v.spindrift.material_override as ShaderMaterial).get_shader_parameter("density")), 1.0, 1e-3, "at full strength")
	lt(float(snow_mat.get_shader_parameter("columns")), 0.05, "and has no gaps between curtains")
	v.update(WeatherLook.compose([]), 0.2, Vector3.ZERO, 0.016)
	check(not v.snow.emitting and not v.spindrift.emitting, "a clear day has none of it")
	v.queue_free()
	await frames(1)


func test_the_sky_knows_where_the_player_is_for_a_whiteout() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 13.0
	o.weather = "whiteout:1"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	await frames(2)
	var f := g.camera.target
	near(Vector2(g.sky.focus.x, g.sky.focus.z).distance_to(Vector2(f.x, f.z)), 0.0, 0.5, "the whiteout closes in on the camera's focus")
	gt(g.sky.air.w, 0.9, "a whiteout")
	g.queue_free()
	await frames(1)
	Weather.unforce()
