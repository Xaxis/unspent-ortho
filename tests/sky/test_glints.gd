extends TestCase
## The glint list (docs/LOOK.md section 6): the lights that exist near the camera
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
	eq((packed[1] as Array)[0], Vector4(0.1, 0.2, 0.3, 1), "colour, and full shafts by default")
	var fire: Array[Dictionary] = [{"at": Vector3.ZERO, "rgb": Vector3.ONE, "level": 1.0, "shaft": 0.0}]
	eq(((Glints.pack(fire)[1] as Array)[0] as Vector4).w, 0.0, "a light may throw no shafts")
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
	# Lights that draw their own strokes throw no shafts (a fire) or weak ones (a
	# lamp), or a fire in fog becomes a spark burst; a window throws the most.
	var weighed := 0
	for c: Dictionary in lights.get("glint_list"):
		var at: Vector3 = c.at
		if Vector2(at.x, at.z).distance_to(fire.pos) < 0.6:
			eq(float(c.shaft), 0.0, "a fire throws no shafts")
			weighed += 1
		elif Vector2(at.x, at.z).distance_to(lamp.pos) < 0.6:
			lt(float(c.shaft), 0.5, "a lamp throws only weak shafts")
			weighed += 1
	eq(weighed, 2, "the fire and the lamp were both weighed")
	check(kinds.has(PropKind.LAMP), "the lamp glints")
	gt(float(g.sky.glints.size()), 1.0, "glints reach the sky: %s" % [g.sky.glints])
	eq(g.sky.glints.size(), g.sky.glint_colors.size(), "a colour for each")
	lt(float(g.sky.glints.size()), SkyLight.MAX_GLINTS + 1.0, "within budget")
	# No OmniLight was made for a glint: the pool stays its size.
	var omni := 0
	for n in lights.get_children():
		if n is OmniLight3D:
			omni += 1
	# How many lights burn is the TIER's (`Quality.lamps`), and it is no longer
	# MAX_LAMPS: that is the size of the shader's packed pool, which held the
	# engine to seven lamps for the game's whole life and left a city dark. The
	# count here is that row plus the lantern, plus one for the reach light,
	# which is not a glint and not a lamp -- it says what the `use` key would
	# work right now (15_lights, LANTERN's answer to a bracket).
	eq(omni, Quality.lamp_count() + 1, "the glint list adds no lights")
	g.queue_free()
	await frames(1)
	Weather.unforce()


## The land's own lights (landscape): a shack's stolen neon, the machines' cold
## strip and flood, a relay's beacon. Each lights a pool or glints where its
## model says, in its own colour, and nothing is lit on a variant that has none.
func test_the_lands_works_and_wired_shacks_give_light_where_their_models_do() -> void:
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
	var base := g.player.pos
	var add := func(kind: int, at: Vector2, lit_variant: bool) -> WorldProp:
		var id := g.world.props.size()
		# A spot whose model is (or is not) the one with a light. Asked through
		# `variant_of`, never by hashing here: a model is dealt by kind and
		# POSITION (`WorldProp.deal_hash`), so the spot is nudged a quarter tile
		# at a time until the prop standing there is the model wanted.
		var spot: Vector2 = base + at
		while (PropModels.variant_of(WorldProp.new(id, kind, spot, 0.0, 1.0), g.world.seed_value) % 2 == 1) != lit_variant:
			spot.x += 0.25
		var p := WorldProp.new(id, kind, spot, 0.0, 1.0)
		g.world.props.append(p)
		return p
	var shack: WorldProp = add.call(PropKind.SHACK, Vector2(3, 0), true)
	var dark_shack: WorldProp = add.call(PropKind.SHACK, Vector2(-3, 0), false)
	var gate: WorldProp = add.call(PropKind.CHECKPOINT, Vector2(0, 3), false)
	var relay: WorldProp = add.call(PropKind.RELAY, Vector2(0, -4), false)
	await frames(20)
	var by_prop := {}
	for src: Dictionary in lights.get("sources"):
		by_prop[(src.prop as WorldProp).id] = src
	check(by_prop.has(shack.id), "a shack with stolen tech is a light")
	check(not by_prop.has(dark_shack.id), "one with nothing wired in is not")
	check(by_prop.has(gate.id) and float(by_prop[gate.id].range) > 0.0, "the gate's flood throws a pool")
	check(by_prop.has(relay.id) and by_prop[relay.id].get("blink", false), "the relay's beacon blinks")
	var near := func(p: WorldProp, list: Array) -> bool:
		for c: Dictionary in list:
			var at: Vector3 = c.at
			if Vector2(at.x, at.z).distance_to(p.pos) < 1.5 and float(c.level) > 0.0:
				return true
		return false
	check(near.call(shack, lights.get("glint_list")), "the neon is mirrored in the wet ground")
	check(near.call(gate, lights.get("glint_list")), "and the flood")
	var c: Color = PropModels.glow_points(PropKind.SHACK, 1, maxi(Country.COAST, g.world.country_at(floori(shack.pos.x), floori(shack.pos.y))))[0].color
	check(Lights.neon_colour(by_prop[shack.id]).is_equal_approx(Vector3(c.r, c.g, c.b)), "the shack's light is its tube's own colour")
	eq(Lights.neon_colour(by_prop[gate.id]), Lights.MACHINE_COLD, "the gate's is the machines' cold")
	var pools: Array = g.sky.lamps
	var pooled := false
	for pool: Vector4 in pools:
		if Vector2(pool.x, pool.z).distance_to(gate.pos) < 1.5:
			pooled = true
	check(pooled, "the flood's pool reaches the sky")
	g.queue_free()
	await frames(1)
	Weather.unforce()
