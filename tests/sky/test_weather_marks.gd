extends TestCase
## What falls through the air, and what the sky hands the shaders.

const SkySource := preload("res://tests/sky/shader_source.gd")


static func _param(m: ShaderMaterial, name: String, fallback: float) -> float:
	var v: Variant = m.get_shader_parameter(name)
	return fallback if v == null else float(v)


## How pale a snow mark reads on the page with all its pixels counted: the paper
## body, plus the shade rim under the share of marks that carry one. precip's
## fleck is a len x len block (a cross at three pixels across) with a rim one row
## under it; a blown streak is a row len long with the same rim under it. A rim
## is a hold when it is a pixel under a fleck and a dash when it runs the length
## of every streak, and only counting the pixels tells the two apart.
static func _mark_tone(m: ShaderMaterial) -> float:
	var mode := int(m.get_shader_parameter("mode"))
	var lp: Vector2 = m.get_shader_parameter("length_px")
	var run := (lp.x + lp.y) * 0.5
	var body: Color = m.get_shader_parameter("color_b")
	var rim: Color = m.get_shader_parameter("color_a")
	var flick := mode == int(WeatherView.Mode.FLICK)
	var body_px := run if flick else (5.0 if run > 2.5 else run * run)
	var rim_px := run if flick else (1.0 if run > 2.5 else run)
	rim_px *= clampf(_param(m, "underline", 0.0) if flick else _param(m, "mix_b", 0.0), 0.0, 1.0)
	return (body_px * body.get_luminance() + rim_px * rim.get_luminance()) / maxf(body_px + rim_px, 1e-5)


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
	# A flake is paper first, held by one pixel of the snowfield's own blue
	# shade: pale against pale (docs/LOOK.md section 3). The dark speck belongs to
	# the Burning's ash, and a whiteout drawn in it reads as dirt on the lens.
	#
	# So the mark is weighed against the PAGE IT FALLS ON, not against itself: a
	# rim eighty luma under lying snow passes "darker than its own body" and
	# still reads as a dark dash. What counts is how much dark the whole mark
	# carries — its rim's depth times how much of the mark the rim is.
	var sky := SkySource.text(SkySource.SKY_INC)
	var lying := SkySource.luma(SkySource.vec3_const(sky, "const vec3 SKY_SNOW"))
	var blown := SkySource.luma(SkySource.vec3_const(sky, "const vec3 SKY_WHITEOUT"))
	for m: ShaderMaterial in [snow_mat, v.flurry.material_override, v.spindrift.material_override]:
		var body: Color = m.get_shader_parameter("color_b")
		var rim: Color = m.get_shader_parameter("color_a")
		gt(body.get_luminance(), lying - 0.01, "the mark's body is at least as pale as the snow it falls on")
		lt(rim.get_luminance(), body.get_luminance() - 0.15, "and a step of shade holds it")
		lt(lying - _mark_tone(m), 0.15, "the whole mark reads pale against lying snow")
		lt(blown - _mark_tone(m), 0.18, "and pale against the paler page a whiteout lays")
	gt(float(snow_mat.get_shader_parameter("highlight")), 0.5, "flakes are drawn with that rim")
	var blow := float((v.spindrift.material_override as ShaderMaterial).get_shader_parameter("underline"))
	gt(blow, 0.3, "the streaks the wind blows are held too")
	lt(blow, 0.8, "but only some of them: a streak is ten flecks long, and every one rimmed is a field of dashes")
	var ash_body: Color = (v.ash.material_override as ShaderMaterial).get_shader_parameter("color_a")
	lt(ash_body.get_luminance(), 0.2, "ash stays the dark speck")
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


func test_the_page_a_whiteout_leaves_is_paler_than_the_snow_it_falls_on() -> void:
	var code := SkySource.text(SkySource.SKY_INC)
	var white := SkySource.number(code, "const vec3 SKY_WHITEOUT")
	var snow := SkySource.number(code, "const vec3 SKY_SNOW")
	gt(white, snow + 0.02, "the white a whiteout lays is paler than lying snow, or it says nothing")
	var far := SkySource.number(code, "const float SKY_WHITEOUT_FAR")
	gt(far, SkySource.number(code, "const float SKY_WHITEOUT_NEAR") + 4.0, "and it closes in over a distance, never in one step")
	lt(far, 20.0, "taking the far field inside the screen")
	check(code.contains("sky_wind.xy * time"), "the white blows past on the wind rather than sitting still")


func test_wet_ground_and_the_pool_are_drawn_edges_not_masks() -> void:
	var code := SkySource.text(SkySource.SKY_INC)
	gt(SkySource.number(code, "SKY_WET_FEATHER"), 0.08, "a wet patch's edge is a wide band of stipple, not a cut line")
	# The darkening and the slick spread by their own wetness — rain that has
	# settled, and a land that never dries — but over ONE lay of patches, so a
	# wet afternoon picks out the same hollows twice and not two sets of them.
	eq(code.count("sky_wet_cover("), 3, "one lay of wet patches, and every reader of it goes through that door")
	check(code.contains("step(sky_hash(px + vec2(7.0, 61.0)), sky_wet_cover"), "and it is stippled, never blended")
	# The pool is the light's colour, and only the dark carries it.
	check(code.contains("vec3 sky_lamp_wash("), "a pool has a wash of its own")
	check(code.contains("pool * SKY_POOL_WASH * sky_gloom()"), "which shows only as far as the gloom does")


## A light SPILLS into the air round it, and that is what says it is a light
## and not a bright rectangle.
##
## It used to be a stippled halo drawn in screen space on the outline quad,
## gated on how dark the air was, because nothing in the pipeline could bloom.
## LANTERN renders in HDR, so the spill is the Environment's own glow, over a
## threshold above white: only a thing that is really EMITTING gets one, which
## is the same rule the gate used to state as "the hour decides it" and is a
## truer statement of it -- a snowfield at noon is bright and emits nothing.
##
## The other half of the old halo, the shafts a light throws through fog, is
## still screen space and still gated, but on the TIER now rather than on the
## hour: it is the web's stand-in for volumetric air (src/render/shafts.gdshader).
func test_a_light_spills_into_the_air_and_only_a_light_does() -> void:
	var e := SkyLight.build_environment()
	check(e.glow_enabled, "light bleeds")
	gt(e.glow_hdr_threshold, 1.0,
		"over white, so a pale landscape at noon does not bloom")
	gt(e.glow_bloom, 0.0, "and there is some bloom under the threshold")
	var code := SkySource.text(SkySource.SHAFTS)
	check(not code.contains("halo_strength"), "the screen-space halo is gone")
	check(code.contains("shaft_strength"), "the shafts it shared a pass with are not")
	check(code.contains("float air = clamp(sky_fog.z"),
		"and a shaft still needs air to be carried in")


func test_drips_are_drops_under_a_crown_not_lines() -> void:
	lt(float(Drips.SOURCES[PropKind.PINE][2]), 3.0, "a pine drips from a couple of points")
	lt(float(Drips.SOURCES[PropKind.BROADLEAF][2]), 4.0, "a crown from a few")
	var v := WeatherView.new()
	tree.root.add_child(v)
	v.setup(null)
	var m: ShaderMaterial = v.drips.material_override
	eq(m.get_shader_parameter("color_a"), Palette.RIME[3], "drips are water-blue")
	lt(float(m.get_shader_parameter("mix_b")), 0.2, "only now and then a pale bead")
	# About one drop at a time per drip point over a short fall.
	lt(float(v.drips.amount) / float(Drips.MAX_POINTS), 1.5, "never a queue of drops making a line")
	lt(v.drips.lifetime, 0.35, "a short fall")
	v.queue_free()
	await frames(1)
