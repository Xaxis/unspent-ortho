extends TestCase
## The sky's rules for reading a frame at any hour (docs/ART.md sections 5, 6):
## people take a fill light of their own in low light, water never takes
## lamplight, the lantern's light sits outside the body, dusk's warmth lands on
## lit faces while shade stays cool, and a lightning flash is a few frames.

const Lights := preload("res://src/systems/15_lights.gd")
const SkySystem := preload("res://src/systems/10_sky.gd")


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


## What the dark half of a dusk frame reads at, on the CPU: the light of the
## hour on a wash, plus the night's blue floor under it worth `share` of that
## wash. The floor is a lift of the WASH and the sun multiplies it afterwards,
## which is why it is inside the same bracket — and which is why an undivided
## floor cannot be spent slowly enough: see SkyLight.night_dark.
static func _darks(h: float, share: float) -> float:
	return SkyLight.light_level(h) * (1.0 + share * SkyLight.night_dark(h))


## The finding, in the one place it can be pinned without a frame. Measured on
## the coast at seed 7 the dark half of the picture read 54.0 at 19:30 and 58.4
## at 20:00: the floor put back more light than the dusk took. It must fall for
## any floor worth anything from a third to three fifths of a dark wash (the
## coast measures about two fifths), and the test walks the same ten minutes the
## sweep walks.
func test_the_floor_under_the_darks_is_never_spent_faster_than_the_light_goes() -> void:
	for share: float in [0.3, 0.4, 0.5, 0.6]:
		var prev := _darks(17.0, share)
		var h := 17.1
		while h <= 22.0001:
			var d := _darks(h, share)
			lt(d, prev + 1e-4, "the darks turn back up at %.2f h with a floor of %.2f" % [h, share])
			prev = d
			h += 0.1
	# And the margin is real rather than lucky: the same walk fails once the
	# floor is worth more than about two thirds of a dark wash, which is the
	# number to check against if SKY_NIGHT_FLOOR is ever raised.
	var broke := false
	var p := _darks(17.0, 0.9)
	var g := 17.1
	while g <= 22.0001:
		var d := _darks(g, 0.9)
		if d > p + 1e-4:
			broke = true
		p = d
		g += 0.1
	check(broke, "a floor worth nine tenths of a wash cannot be spent slowly enough, and this says so")


## sky_night itself: the one term everything that lifts the dark hangs off.
func test_the_night_term_is_nothing_by_day_all_of_it_at_night_and_never_turns_back() -> void:
	near(SkyLight.night_dark(12.0), 0.0, 1e-6, "noon")
	near(SkyLight.night_dark(8.0), 0.0, 1e-6, "eight in the morning is full day")
	lt(SkyLight.night_dark(18.0), 0.02, "and six in the evening still is")
	gt(SkyLight.night_dark(19.5), 0.2, "half past seven has begun")
	lt(SkyLight.night_dark(19.5), 0.55, "but is nowhere near the night")
	near(SkyLight.night_dark(20.5), 1.0, 0.02, "full where the light stops falling")
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
## through the evening, but a storm gets BOTH in full: the cube is the night's
## own pacing and must never take the glow off a dark sky at ten in the morning.
func test_a_storm_at_ten_keeps_its_glow_while_the_evening_holds_its_own_back() -> void:
	var clear := Vector3.ONE
	var storm := Vector3(0.5, 0.52, 0.6)
	var noon := SkyLight.night_terms(10.0, storm)
	gt(noon.x, 0.3, "a storm at ten has the floor under its washes")
	near(noon.y, noon.x, 1e-6, "and all of its skyglow, cube or no cube")
	var eve := SkyLight.night_terms(20.0, clear)
	gt(eve.x, 0.4, "the evening's floor is well up by eight")
	lt(eve.y, eve.x * 0.6, "and its glow is well behind it")
	var night := SkyLight.night_terms(23.0, clear)
	near(night.x, 1.0, 1e-6, "night is all floor")
	near(night.y, 1.0, 1e-6, "and all glow")
	var midday := SkyLight.night_terms(12.0, clear)
	near(midday.x, 0.0, 1e-6, "noon has no floor")
	near(midday.y, 0.0, 1e-6, "and no glow")


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
