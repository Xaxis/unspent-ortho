extends TestCase
## The sky's rules for reading a frame at any hour (docs/ART.md sections 5, 6):
## people take a fill light of their own in low light, water never takes
## lamplight, the lantern's light sits outside the body, dusk's warmth lands on
## lit faces while shade stays cool, and a lightning flash is a few frames.

const Lights := preload("res://src/systems/15_lights.gd")
const SkySystem := preload("res://src/systems/10_sky.gd")
const ShaderSource := preload("res://tests/sky/shader_source.gd")


func test_people_are_tagged_for_their_fill_and_water_is_kept_from_lamps() -> void:
	var sky := SkyLight.new()
	tree.root.add_child(sky)
	var person := PersonModel.new()
	tree.root.add_child(person)
	var body := MeshInstance3D.new()
	person.add_child(body)
	check(body.layers & SkyLight.LAYER_FIGURES != 0, "a mesh inside a person takes the figure fill")
	check(body.layers & 1 != 0, "and stays on the ordinary layer for the sun")
	var sea := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = load(SkyLight.WATER_SHADER)
	sea.material_override = mat
	tree.root.add_child(sea)
	eq(sea.layers, SkyLight.LAYER_WATER, "water is on its own layer alone")
	var rock := MeshInstance3D.new()
	tree.root.add_child(rock)
	eq(rock.layers & SkyLight.LAYER_FIGURES, 0, "a rock is not a person")
	eq(sky.figure_light.light_cull_mask, SkyLight.LAYER_FIGURES, "the fill lights people only")
	sky.set_hour(12.0)
	check(not sky.figure_light.visible, "no fill at noon")
	sky.set_hour(23.0)
	check(sky.figure_light.visible, "a fill at night")
	gt(sky.figure_light.light_energy, 0.3, "enough to read by")
	for n: Node in [sky, person, sea, rock]:
		n.queue_free()
	await frames(1)


func test_lamps_never_light_water_and_the_lantern_is_out_of_the_body() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 23.0
	o.lamp = true
	o.weather = "clear:0"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var lights: Node = null
	for s in g.systems:
		if s.get_script() == Lights:
			lights = s
	check(lights != null, "lights system loaded")
	await frames(3)
	for l: OmniLight3D in lights.lights:
		eq(l.light_cull_mask & SkyLight.LAYER_WATER, 0, "no lamp lights the sea")
	var lantern: OmniLight3D = lights.lantern_light
	eq(lantern.light_cull_mask & SkyLight.LAYER_WATER, 0, "nor the lantern")
	check(lantern.visible, "lantern lit")
	var off := Vector2(lantern.position.x - g.player.position.x, lantern.position.z - g.player.position.z)
	gt(off.length(), 0.35, "the lantern's light is beside the body, not inside it")
	gt(lantern.position.y - g.player.position.y, 0.8, "and above the hand")
	g.queue_free()
	await frames(1)
	Weather.unforce()


func test_a_hearth_flickers_in_brightness_only() -> void:
	var house := {"kind": PropKind.HOUSE, "h": 0.37, "h2": 0.9}
	var seen := {}
	for i in 60:
		var f := Lights.flicker(house, i * 0.05)
		gt(f, 0.79, "never dims far")
		lt(f, 1.001, "never brighter than its level")
		seen[snappedf(f, 0.001)] = true
	gt(seen.size(), 4.0, "it does flicker")
	var fire := {"kind": PropKind.FIRE, "h": 0.2, "h2": 0.2}
	gt(absf(Lights.flicker(fire, 0.0) - Lights.flicker(fire, 0.5)) + absf(Lights.flicker(fire, 0.2) - Lights.flicker(fire, 0.7)), 0.0, "a fire flickers")


func test_dusk_is_warm_on_lit_faces_and_cool_in_shade() -> void:
	var noon := SkyLight.tint_at(12.0)
	var cool_noon := SkyLight.shade_cool(noon)
	near((cool_noon - Vector3.ONE).length(), 0.0, 0.03, "shade is untouched under a white noon")
	near(SkyLight.sun_glow(noon, SkyLight.sun_at(12.0)), 1.0, 0.02, "no glow at noon")
	var dusk := SkyLight.tint_at(19.2)
	var cool := SkyLight.shade_cool(dusk)
	# As world.gdshader lays it: albedo * tint, lit by the sun through shade_tint * cool.
	var shade_tint := Vector3(0.66, 0.68, 0.82)
	var shade := dusk * cool * shade_tint
	gt(shade.z, shade.x, "shade at dusk leans blue: %s" % shade)
	var uncorrected := dusk * shade_tint
	lt(uncorrected.z, uncorrected.x, "where it would have been brown without the correction")
	gt(dusk.x, dusk.z, "while the tint on lit faces stays warm")
	gt(SkyLight.sun_glow(dusk, SkyLight.sun_at(19.2)), 1.05, "a low sun glows on what it lights")
	near(SkyLight.sun_glow(SkyLight.tint_at(1.0), SkyLight.sun_at(1.0)), 1.0, 1e-6, "no glow from the moon")
	# The keys themselves are untouched.
	near(SkyLight.tint_at(12.0).x, 1.0, 1e-6, "noon key")


func test_a_flash_is_a_few_light_frames_not_a_veil() -> void:
	lt(float(SkySystem.FLASH_FRAMES.size()), 5.0, "a few frames")
	for f: float in SkySystem.FLASH_FRAMES:
		lt(f, 0.4, "never more than a pale step")
	eq(SkySystem.FLASH_FRAMES[SkySystem.FLASH_FRAMES.size() - 1] > 0.0, true, "ends on a flicker, then gone")


func test_a_bolt_is_whole_pixels_with_a_pale_core_inked_either_side() -> void:
	var a := BoltDraw.cells(1234, 300.0)
	var b := BoltDraw.cells(1234, 300.0)
	eq((a[0] as Dictionary).size(), (b[0] as Dictionary).size(), "seeded: the same bolt twice")
	var core: Dictionary = a[0]
	var ink: Dictionary = a[1]
	check(core.has(Vector2i.ZERO), "it lands on its ground point")
	var main := 0
	var fork := 0
	for c: Vector2i in core:
		check(not ink.has(c), "ink never over the core")
		if int(core[c]) == 2:
			main += 1
		else:
			fork += 1
	gt(main, 300.0 * 2.0 * 0.9, "the main stroke runs the whole way, two pixels wide")
	gt(fork, 30.0, "and forks")
	# Every row of the main stroke from the top to the ground is drawn.
	for y in range(-299, 1):
		var row := false
		for x in range(-200, 201):
			if int(core.get(Vector2i(x, y), 0)) == 2:
				row = true
				break
		check(row, "no gap in the stroke at row %d" % y)
		if not row:
			break
	# Ink sits beside the core, left and right.
	var inked_sides := 0
	for c: Vector2i in core:
		if ink.has(c + Vector2i(-1, 0)) or ink.has(c + Vector2i(1, 0)):
			inked_sides += 1
	gt(float(inked_sides), core.size() * 0.8, "inked either side")


func test_the_lamp_action_lights_and_puts_out_the_lantern() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 23.0
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	# The lamp action is polled on drawn frames: after a slow frame physics can
	# step several times before one is drawn, so count drawn frames here.
	await _drawn(2)
	check(not g.body.lamp_lit, "starts dark")
	Input.action_press("lamp")
	await _drawn(5)
	check(g.body.lamp_lit, "a press of the lamp action lights it")
	await _drawn(5)
	check(g.body.lamp_lit, "holding it does not flicker it off")
	Input.action_release("lamp")
	await _drawn(3)
	Input.action_press("lamp")
	await _drawn(3)
	Input.action_release("lamp")
	await _drawn(3)
	check(not g.body.lamp_lit, "a second press puts it out")
	g.queue_free()
	await _drawn(1)


func test_lighting_the_lamp_after_the_clock_jumps_keeps_its_oil() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 8.0
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	g.inventory.add(&"lamp")
	await _drawn(2)
	var lights: GameSystem = null
	for sys in g.systems:
		if sys.name == "15_lights":
			lights = sys
	check(lights != null, "the lights system is loaded")
	var oil := Survival.lamp_oil(g)
	g.clock.minutes += 15.0 * 60.0
	lights.call("toggle_lantern")
	Survival.burn_lamp(g)
	check(g.body.lamp_lit, "a lamp lit after a jump in the clock stays lit")
	near(Survival.lamp_oil(g), oil, 1.0, "the dark hours before it was lit burnt no oil")
	g.body.lamp_lit = false
	g.queue_free()
	await _drawn(1)


func test_a_burning_dusk_keeps_its_warm_darks() -> void:
	# At 19:30 the evening is only a third of the way to night, so the darks are
	# only a third lifted: the lift follows HOW DARK IT IS, not how warm the tint
	# has gone. It was the other way round, and every night term came on at once
	# in the middle of a bright evening (art review finding 2).
	var cold := SkyLight.dusk_lift(19.5, SkyLight.type_tint(&"snowfield"))
	var late := SkyLight.dusk_lift(20.75, SkyLight.type_tint(&"snowfield"))
	var burning := SkyLight.dusk_lift(19.5, SkyLight.type_tint(&"burning"))
	gt(cold, 0.25, "a snowfield dusk has begun to lift its darks to blue")
	lt(cold, 0.5, "but only as far as the evening has come")
	gt(late, 0.9, "and all the way once the night is on it")
	lt(burning, cold * 0.5, "a burning dusk keeps them warm")
	near(SkyLight.dusk_lift(12.0, Vector3.ONE), 0.0, 0.02, "nothing to lift at noon")
	lt(SkyLight.dusk_lift(18.0, Vector3.ONE), 0.05, "nor at six, which is still the day")


## The level of light a lit face takes at an hour: the tint's own luminance times
## the sun's energy times its low-sun glow. It is what the art review's mean
## luminance sweep measures, on the CPU and without a frame.
static func _level(h: float) -> float:
	return SkyLight.light_level(h)


## And its warmth, the R-B of that same sweep.
static func _warmth(h: float) -> float:
	var t := SkyLight.tint_at(h)
	var s := SkyLight.sun_at(h)
	return (t.x - t.z) * float(s.energy) * SkyLight.sun_glow(t, s)


## The finding this package answers: measured over 18:00-20:00 the game got
## BRIGHTER and steadily BLUER, then dropped a third in half an hour. The light's
## own level must fall from the afternoon to the night and never turn back, and
## no ten minutes of it may take more than a fifteenth of a noon.
func test_the_evening_falls_instead_of_brightening() -> void:
	var noon := _level(12.0)
	gt(noon, 0.9, "noon is full light")
	var prev := _level(16.8)
	var h := 16.9
	while h <= 21.0001:
		var l := _level(h)
		lt(l, prev + 1e-4, "the light turns back up at %.2f h" % h)
		lt(prev - l, noon * 0.075, "the light drops off a cliff at %.2f h" % h)
		prev = l
		h += 0.1
	gt(_level(18.0), noon * 0.75, "six o'clock is still the day")
	lt(_level(20.0), _level(18.0) * 0.75, "eight has lost a quarter of it and more")
	lt(_level(21.0), noon * 0.45, "and by nine it has gone")
	gt(_level(21.0), _level(23.0) * 0.95, "landing on the night rather than under it")


func test_the_evening_warms_into_the_last_of_the_sun_and_only_then_turns_blue() -> void:
	gt(_warmth(19.2), _warmth(16.8) + 0.25, "the sun goes down warm")
	gt(_warmth(19.2), _warmth(18.0), "warmer at seven than at six")
	gt(_warmth(20.0), _warmth(18.0), "and still warm at eight, when the level has gone")
	lt(_warmth(21.0), 0.0, "only then does the blue of the sky take the land")
	lt(_warmth(12.0), 0.05, "noon is white")


## The other half of it: every term that belongs to the dark hangs off low_light,
## and low_light must mean how little light there is. It used to read a WARM tint
## as a dark one, so the skyglow's blue wash came up at seven in the evening.
func test_the_darks_follow_how_dark_it_is_not_how_warm_the_tint_has_gone() -> void:
	near(SkyLight.low_light(12.0), 0.0, 0.01, "noon")
	lt(SkyLight.low_light(18.0), 0.05, "six o'clock is still daylight")
	lt(SkyLight.low_light(19.2), 0.35, "the dusk key is warm, not dark")
	gt(SkyLight.low_light(20.5), 0.8, "by half past eight it really is going")
	near(SkyLight.low_light(23.0), 1.0, 0.01, "night")
	var prev := SkyLight.low_light(17.0)
	var h := 17.1
	while h <= 21.0001:
		var g := SkyLight.low_light(h)
		gt(g, prev - 1e-4, "the dark turns back at %.2f h" % h)
		prev = g
		h += 0.1


## THE FINDING, PINNED ON THE WHOLE COMPOSED PICTURE AND NOT ON ONE TERM OF IT.
##
## This test used to read `light_level(h) * (1 + share * night_dark(h))` — the
## night's floor as a multiply ON the light. The shader does not compose a frame
## that way. It lays the floor UNDER the wash, with a knee, so a light wash takes
## none of it and a dark one takes nearly all; and the skyglow is EMISSION added
## over everything afterwards, at the same strength whatever the hour. Modelled
## as a multiply, an evening that rose by eleven per cent in the frames was
## invisible here and this test was green through it (art review, wave A2).
##
## SkyLight.frame_level composes what sky_apply() composes. The rule is the
## finding's own sentence, on every landscape there is: from six in the evening
## to ten at night the picture falls, every ten minutes of it, and never turns
## back up.
func test_no_landscapes_evening_ever_turns_back_up() -> void:
	var lands: Array = SkyLight.MOOD.keys()
	lands.append(&"")
	for id: StringName in lands:
		var def := BiomeRegistry.get_def(id) if id != &"" else null
		var name := String(id) if id != &"" else "a landscape with no mood of its own"
		var prev := SkyLight.frame_level(17.0, SkyLight.type_light(def, 17.0))
		var worst := 0.0
		var worst_at := 0.0
		var h := 17.1
		while h <= 22.0001:
			var f := SkyLight.frame_level(h, SkyLight.type_light(def, h))
			if f - prev > worst:
				worst = f - prev
				worst_at = h
			prev = f
			h += 0.1
		# A tenth of a per cent of a noon is float noise; a rise a player sees is
		# five per cent (the frames measured 11.9% in the moss at half past eight).
		lt(worst, 0.002, "%s turns back up by %.4f at %.2f h" % [name, worst, worst_at])


## And it is a real fall, not a flat line: the evening spends a third of the
## afternoon's light, most of it between seven and nine.
func test_every_landscapes_evening_spends_a_third_of_the_afternoon() -> void:
	for id: StringName in SkyLight.MOOD:
		var def := BiomeRegistry.get_def(id)
		var afternoon := SkyLight.frame_level(17.0, SkyLight.type_light(def, 17.0))
		var night := SkyLight.frame_level(22.0, SkyLight.type_light(def, 22.0))
		lt(night, afternoon * 0.78, "%s gives up a fifth of its afternoon and more" % id)
		# And it lands at nine, as the brief asks: the evening proper does the
		# work, and what is left after nine is a whisker.
		var six := SkyLight.frame_level(18.0, SkyLight.type_light(def, 18.0))
		var nine := SkyLight.frame_level(21.0, SkyLight.type_light(def, 21.0))
		lt(nine, six * 0.82, "%s: the three hours from six take a fifth and more" % id)
		gt(night, nine * 0.94, "%s has landed by nine, not gone on falling into the night" % id)


## The landscapes do not all fall together: docs/ART.md section 3 gives each one
## its own dusk, and the rows have to make that measurable rather than pretty.
func test_each_landscape_keeps_the_dusk_its_own_row_promises() -> void:
	var share := {}
	for id: StringName in SkyLight.MOOD:
		var def := BiomeRegistry.get_def(id)
		var day := SkyLight.frame_level(16.0, SkyLight.type_light(def, 16.0))
		var seven := SkyLight.frame_level(19.0, SkyLight.type_light(def, 19.0))
		share[id] = seven / day
	lt(share[&"pinewood"], share[&"coast"] * 0.95, "the pines are darker at seven, against their own afternoon, than the coast")
	lt(share[&"pinewood"], share[&"burning"] * 0.95, "and than the burning, which holds its heat")
	gt(share[&"burning"], share[&"bonelands"], "the bonelands fall off the end of the day harder than the burning")
	# The burning's dusk is a furnace and its night keeps the warmth; the
	# snowfield's last hour is the bluest thing in the game.
	var burn := SkyLight.type_light(BiomeRegistry.get_def(&"burning"), 19.5) * SkyLight.tint_at(19.5)
	gt(burn.x - burn.z, 0.3, "the burning's dusk is a furnace")
	var burn_night := SkyLight.type_light(BiomeRegistry.get_def(&"burning"), 23.5) * SkyLight.tint_at(23.5)
	gt(burn_night.x, burn_night.z, "and its night is still warm")
	var snow := SkyLight.type_light(BiomeRegistry.get_def(&"snowfield"), 20.5) * SkyLight.tint_at(20.5)
	for id: StringName in SkyLight.MOOD:
		if id == &"snowfield":
			continue
		var other := SkyLight.type_light(BiomeRegistry.get_def(id), 20.5) * SkyLight.tint_at(20.5)
		lt(snow.x - snow.z, other.x - other.z, "the snowfield's last hour is bluer than %s's" % id)


## A landscape's mood is a multiply on the hour and never a filter: noon reads as
## day everywhere, and the burning — the darkest, warmest row there is — is still
## a day and not a dusk.
func test_noon_still_reads_as_day_in_every_landscape() -> void:
	var plain := SkyLight.frame_level(12.0, Vector3.ONE)
	for id: StringName in SkyLight.MOOD:
		var def := BiomeRegistry.get_def(id)
		var noon := SkyLight.frame_level(12.0, SkyLight.type_light(def, 12.0))
		gt(noon, plain * 0.72, "%s at noon is still a day" % id)
		gt(noon, SkyLight.frame_level(20.0, SkyLight.type_light(def, 20.0)) * 1.35, "%s: noon is well clear of eight in the evening" % id)


## Each row's SETTLE KEY: from nine o'clock a landscape's own light does not move
## again until the morning. A row that climbs back to a bright midnight key after
## the light has stopped falling is a land brightening through the small hours,
## which is finding 2 all over again in slow motion.
func test_no_landscapes_light_climbs_through_the_small_hours() -> void:
	for id: StringName in SkyLight.MOOD:
		var def := BiomeRegistry.get_def(id)
		var h := 21.0
		var prev := SkyLight.frame_level(h, SkyLight.type_light(def, h))
		while h <= 27.0001:
			var f := SkyLight.frame_level(h, SkyLight.type_light(def, h))
			lt(f - prev, 0.002, "%s brightens through the night at %.2f h" % [id, fposmod(h, 24.0)])
			prev = f
			h += 0.25


## sky_night itself: the one term everything that lifts the dark hangs off.
func test_the_night_term_is_nothing_by_day_all_of_it_at_night_and_never_turns_back() -> void:
	near(SkyLight.night_dark(12.0), 0.0, 1e-6, "noon")
	near(SkyLight.night_dark(8.0), 0.0, 1e-6, "eight in the morning is full day")
	lt(SkyLight.night_dark(18.0), 0.02, "and six in the evening still is")
	gt(SkyLight.night_dark(19.5), 0.2, "half past seven has begun")
	lt(SkyLight.night_dark(19.5), 0.55, "but is nowhere near the night")
	lt(SkyLight.night_dark(20.5), 0.9, "half past eight is not the night either: the light still has a sixth of its fall left")
	near(SkyLight.night_dark(SkyLight.DARK_FULL), 1.0, 1e-6, "full where the light stops falling, and not before")
	near(SkyLight.night_dark(23.0), 1.0, 1e-6, "and all night")
	near(SkyLight.night_dark(3.0), 1.0, 1e-6, "including the small hours")
	var prev := SkyLight.night_dark(17.0)
	var h := 17.1
	while h <= 21.0001:
		var n := SkyLight.night_dark(h)
		gt(n, prev - 1e-4, "it turns back at %.2f h" % h)
		prev = n
		h += 0.1
	# The dawn is the same rule read backwards: the light comes back, it goes.
	gt(SkyLight.night_dark(5.0), 0.9, "still dark at five")
	lt(SkyLight.night_dark(7.5), 0.02, "gone by half past seven in the morning")
	# A sky darker than its hour is the other half of it, so a storm at ten in
	# the morning still keeps its shapes readable (docs/ART.md section 6).
	near(SkyLight.weather_dark(Vector3.ONE), 0.0, 1e-6, "clear weather is no dark at all")
	gt(SkyLight.weather_dark(Vector3(0.5, 0.52, 0.6)), 0.3, "a heavy storm is")


## The two terms sky_night carries. The glow is held back behind the floor
## through the evening, but a storm gets BOTH in full: the lag is the night's
## own pacing and must never take the glow off a dark sky at ten in the morning.
func test_a_storm_at_ten_keeps_its_glow_while_the_evening_holds_its_own_back() -> void:
	var clear := Vector3.ONE
	var storm := Vector3(0.5, 0.52, 0.6)
	var noon := SkyLight.night_terms(10.0, storm)
	gt(noon.x, 0.3, "a storm at ten has the floor under its washes")
	near(noon.y, noon.x, 1e-6, "and all of its skyglow, lag or no lag")
	var eve := SkyLight.night_terms(20.0, clear)
	gt(eve.x, 0.4, "the evening's floor is well up by eight")
	lt(eve.y, eve.x * 0.7, "and its glow is behind it")
	var night := SkyLight.night_terms(23.0, clear)
	near(night.x, 1.0, 1e-6, "night is all floor")
	near(night.y, 1.0, 1e-6, "and all glow")
	var midday := SkyLight.night_terms(12.0, clear)
	near(midday.x, 0.0, 1e-6, "noon has no floor")
	near(midday.y, 0.0, 1e-6, "and no glow")
	# Neither term may arrive in a lump: the frames measured an eleven per cent
	# rise in the half hour where the glow went 0.21 to 1.00 (art review, wave A2).
	# The biggest half hour either of them is allowed is the light's own biggest
	# half hour, 20:00 to 20:30, where the sun gives up a quarter of the evening.
	var h := 18.0
	while h <= 21.9001:
		var a := SkyLight.night_terms(h, clear)
		var b := SkyLight.night_terms(h + 0.5, clear)
		lt(b.x - a.x, 0.32, "the floor arrives in a lump at %.2f h" % h)
		lt(b.y - a.y, 0.45, "the skyglow arrives in a lump at %.2f h" % h)
		h += 0.1
	var most := SkyLight.night_terms(20.5, clear) - SkyLight.night_terms(20.0, clear)
	var light_most := (SkyLight.light_level(20.0) - SkyLight.light_level(20.5)) / (SkyLight.light_level(SkyLight.DARK_FROM) - SkyLight.light_level(SkyLight.DARK_FULL))
	gt(light_most, 0.2, "and that half hour really is where the light goes")
	lt(most.y, light_most * 2.0, "the glow's biggest half hour is no more than twice the light's")


## The constants frame_level composes with are the shader's own. A tuned number
## that moves in sky.gdshaderinc and not here would leave every evening test
## measuring a picture the game no longer draws.
func test_the_cpu_composition_uses_the_shaders_own_numbers() -> void:
	var code := ShaderSource.text(ShaderSource.SKY_INC)
	var floor_c := ShaderSource.vec3_const(code, "SKY_NIGHT_FLOOR")
	near((floor_c - SkyLight.NIGHT_FLOOR).length(), 0.0, 1e-6, "the night floor: shader %s, SkyLight %s" % [floor_c, SkyLight.NIGHT_FLOOR])
	near(ShaderSource.number(code, "SKY_NIGHT_KNEE"), SkyLight.NIGHT_KNEE, 1e-6, "the knee")
	near(ShaderSource.number(code, "SKY_GLOW_LEVEL"), SkyLight.GLOW_LEVEL, 1e-6, "the skyglow's level")
	near(ShaderSource.number(code, "SKY_GLOW_FLOOR"), SkyLight.GLOW_FLOOR, 1e-6, "the skyglow's floor")
	check(code.contains("SKY_NIGHT_FLOOR * sky_night.x"), "the floor is spent against sky_night.x")
	check(code.contains("* sky_night.y"), "and the skyglow against sky_night.y")


## Dusk is long low shadows. They used to stop at 20:30 because they were keyed
## off how far night had fallen, and that curve is two and a half hours wide now.
func test_the_sun_casts_through_the_whole_dusk_and_its_shadows_fade_out() -> void:
	check(SkyLight.casts_at(19.5), "half past seven still casts")
	check(SkyLight.casts_at(20.25), "and so does the last of it")
	check(not SkyLight.casts_at(21.0), "gone by nine")
	check(not SkyLight.casts_at(4.9), "and not before the sun is properly up")
	near(SkyLight.shadow_strength(12.0), 1.0, 1e-6, "full at noon")
	gt(SkyLight.shadow_strength(19.5), 0.9, "still solid at half seven")
	lt(SkyLight.shadow_strength(20.25), 0.5, "going with the light")
	near(SkyLight.shadow_strength(20.5), 0.0, 1e-6, "and gone where the sun stops casting")
	near(SkyLight.shadow_strength(2.0), 0.0, 1e-6, "the moon casts nothing")


## n drawn (process) frames: what a system that polls input in _process sees.
func _drawn(n: int) -> void:
	for i in n:
		await tree.process_frame
