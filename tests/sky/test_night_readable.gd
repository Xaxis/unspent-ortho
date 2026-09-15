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
		gt(f, 0.89, "never dims far")
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
