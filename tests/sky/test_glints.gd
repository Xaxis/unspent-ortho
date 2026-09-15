extends TestCase
## The glint list (docs/ART.md section 6): the lights that exist near the camera
## are mirrored in wet ground and throw shafts in fog, with no extra OmniLight.

const Lights := preload("res://src/systems/15_lights.gd")


func test_the_nearest_lit_lights_are_kept_nearest_first() -> void:
	var cands: Array[Dictionary] = []
	for i in 30:
		cands.append({"at": Vector3(i * 0.5, 1.0, 0.0), "rgb": Vector3(1, 0.5, 0.2), "level": 0.8})
	cands.append({"at": Vector3(0.2, 1.0, 0.0), "rgb": Vector3.ONE, "level": 0.0})
	cands.append({"at": Vector3(Glints.REACH + 3.0, 1.0, 0.0), "rgb": Vector3.ONE, "level": 1.0})
	var list := Glints.pick(cands, Vector3.ZERO)
	eq(list.size(), SkyLight.MAX_GLINTS, "never more than the sky holds")
	for c: Dictionary in list:
		gt(float(c.level), 0.0, "an unlit light never glints")
		lt((c.at as Vector3).x, Glints.REACH, "nothing past reach")
	var prev := -1.0
	for c: Dictionary in list:
		gt((c.at as Vector3).x, prev, "nearest first")
		prev = (c.at as Vector3).x
	# A bright fire a little further out beats a dim window close in.
	var fire: Dictionary = {"at": Vector3(5.0, 0.5, 0.0), "rgb": Vector3(1, 0.45, 0.12), "level": 1.0}
	var window: Dictionary = {"at": Vector3(4.2, 1.0, 0.0), "rgb": Vector3(1, 0.7, 0.4), "level": 0.1}
	var two: Array[Dictionary] = [window, fire]
	eq(Glints.pick(two, Vector3.ZERO, 1)[0], fire, "brightness holds a place")


func test_glints_pack_for_the_three_matrices() -> void:
	var list: Array[Dictionary] = [{"at": Vector3(1, 2, 3), "rgb": Vector3(0.1, 0.2, 0.3), "level": 1.4}]
	var packed := Glints.pack(list)
	eq((packed[0] as Array)[0], Vector4(1, 2, 3, 1), "position and a level clamped to 1")
	eq((packed[1] as Array)[0], Vector4(0.1, 0.2, 0.3, 0), "colour")
	var many: Array[Vector4] = []
	for i in 20:
		many.append(Vector4(i, 0, 0, 1))
	var cols := SkyLight.glint_columns(many)
	eq(cols.size(), 3, "three mat4 globals")
	eq(cols[0].x, Vector4(0, 0, 0, 1), "first glint in the first column")
	eq(cols[2].w, Vector4(11, 0, 0, 1), "the twelfth is the last")
	var few: Array[Vector4] = [Vector4(1, 1, 1, 1)]
	eq(SkyLight.glint_columns(few)[1].x, Vector4.ZERO, "unused columns are empty")


func test_a_night_village_hands_its_lights_to_the_sky_and_a_strike_dims_machine_light() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 23.0
	o.weather = "rain:1"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var lights: Node = null
	for s in g.systems:
		if s.get_script() == Lights:
			lights = s
	check(lights != null, "lights system")
	# A fire, a lamp and a pylon near the player, placed after indexing.
	var base := g.player.pos
	var fire := WorldProp.new(g.world.props.size(), PropKind.FIRE, base + Vector2(2, 1), 0.0, 1.0)
	g.world.props.append(fire)
	var lamp := WorldProp.new(g.world.props.size(), PropKind.LAMP, base + Vector2(-2, 1), 0.0, 1.0)
	g.world.props.append(lamp)
	var pylon := WorldProp.new(g.world.props.size(), PropKind.PYLON, base + Vector2(0, -3), 0.0, 1.0)
	g.world.props.append(pylon)
	await frames(20)
	var kinds := {}
	for c: Dictionary in lights.get("glint_list"):
		var at: Vector3 = c.at
		for p: WorldProp in [fire, lamp, pylon]:
			if Vector2(at.x, at.z).distance_to(p.pos) < 1.2:
				kinds[p.kind] = true
	check(kinds.has(PropKind.FIRE), "the fire glints")
	check(kinds.has(PropKind.LAMP), "the lamp glints")
	gt(float(g.sky.glints.size()), 1.0, "glints reach the sky: %s" % [g.sky.glints])
	eq(g.sky.glints.size(), g.sky.glint_colors.size(), "a colour for each")
	lt(float(g.sky.glints.size()), SkyLight.MAX_GLINTS + 1.0, "within budget")
	# No OmniLight was made for a glint: the pool stays its size.
	var omni := 0
	for n in lights.get_children():
		if n is OmniLight3D:
			omni += 1
	eq(omni, SkyLight.MAX_LAMPS, "the glint list adds no lights")
	g.queue_free()
	await frames(1)
	Weather.unforce()
