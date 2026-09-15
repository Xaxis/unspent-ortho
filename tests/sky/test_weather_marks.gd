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
