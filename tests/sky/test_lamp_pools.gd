extends TestCase
## Lamplight lifts the ink (docs/ART.md section 6): the lights system hands the
## same positions and ranges it gives its OmniLight3Ds to the sky, so the pool
## the light paints is the pool the hatching leaves.

const Lights := preload("res://src/systems/15_lights.gd")


func test_pool_radius_is_where_the_light_is_half() -> void:
	for spec: Array in Lights.SOURCES.values():
		var reach := float(spec[0])
		var h := float(spec[2])
		var r := Lights.pool_radius(reach, h)
		gt(r, 0.6, "a core you can stand in")
		lt(r, 2.2, "a pool, not a floodlit square")
		near(Lights.omni_attenuation(sqrt(r * r + h * h), reach), Lights.POOL_CORE, 1e-3, "the core ends where the light crosses the core step")
		var ring := Lights.pool_radius(reach, h, Lights.POOL_RING)
		gt(ring - r, 0.35, "a ring wide enough to read as a second step")
	lt(Lights.pool_radius(4.0, 9.0), 1e-6, "a light too high leaves no pool")


func test_lamps_hand_their_pools_to_the_ink_at_night_only() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 23.0
	o.weather = "clear:0"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var lights: Node = null
	for s in g.systems:
		if s.get_script() == Lights:
			lights = s
	check(lights != null, "lights system loaded")
	# A lamp two tiles from the player, placed after the world was indexed.
	var at := g.player.pos + Vector2(2, 0)
	var lamp := WorldProp.new(g.world.props.size(), PropKind.LAMP, at, 0.0, 1.0)
	g.world.props.append(lamp)
	await frames(20)
	var found := false
	for p: Vector4 in g.sky.lamps:
		if Vector2(p.x, p.z).distance_to(at) < 0.01:
			found = true
			near(p.w, float(Lights.SOURCES[PropKind.LAMP][0]), 1e-4, "pool range is the light's range")
	check(found, "the lamp's pool reaches the sky at night: %s" % [g.sky.lamps])
	lt(g.sky.lamps.size(), SkyLight.MAX_LAMPS + 1, "never more pools than the sky can hold")

	# The lantern's own pool comes first and follows the player.
	g.body.lamp_lit = true
	await frames(3)
	check(not g.sky.lamps.is_empty(), "lantern pool")
	if not g.sky.lamps.is_empty():
		var first: Vector4 = g.sky.lamps[0]
		var off := Vector2(first.x, first.z).distance_to(Vector2(g.player.position.x, g.player.position.z))
		gt(off, 0.3, "the lantern's light is out of the body")
		lt(off, 0.8, "and still at the player's hand")

	# By day nobody's lamp leaves a pool in the ink — the lit lantern included.
	g.body.lamp_lit = false
	g.clock.minutes = 12.0 * 60.0
	await frames(20)
	eq(g.sky.lamps.size(), 0, "no pools at noon")
	g.body.lamp_lit = true
	await frames(5)
	eq(g.sky.lamps.size(), 0, "and none from a lamp lit at noon: a flame in the hand, nothing on the ground")
	check(not lights.lantern_light.visible, "the lantern's own light is out in daylight")
	g.queue_free()
	await frames(1)


func test_a_lamp_lit_in_daylight_lays_nothing_and_at_night_lays_its_own_colour() -> void:
	# The rule the snowfield caught us on: at noon a lit lamp must add no light
	# at all, so no disc can appear on bright ground (docs/ART.md section 6).
	var day := Vector3(1.0, 1.0, 0.99)
	near(Lights.gloom(12.0, day, 1.0), 0.0, 0.02, "noon is not gloom")
	near(Lights.gloom(13.0, day, 1.0), 0.0, 0.02, "nor the afternoon")
	gt(Lights.gloom(19.0, Vector3(0.98, 0.8, 0.66), 0.9), 0.3, "dusk is")
	near(Lights.gloom(23.0, Vector3(0.56, 0.64, 0.9), 0.7), 1.0, 0.02, "and the dead of night is all of it")
	gt(Lights.gloom(12.0, Vector3(0.5, 0.55, 0.66), 1.0), 0.2, "a storm dark enough at noon is gloom too")
	# Every pool colour is the light's own, and the ones people carry are warm.
	for kind: int in [PropKind.LAMP, PropKind.HOUSE, PropKind.FIRE, PropKind.FIRE_TOWER]:
		var c := Lights.neon_colour({"kind": kind})
		gt(c.x, c.z + 0.2, "a %s burns warm" % PropKind.NAMES[kind])
	gt(Lights.LANTERN_WARM.x, Lights.LANTERN_WARM.z + 0.2, "and so does the lantern people carry")
	var cold := Lights.neon_colour({"kind": PropKind.CHECKPOINT})
	gt(cold.z, cold.x + 0.2, "the machines' own light is cold")


func test_stolen_neon_runs_on_the_machines_power_and_a_hearth_does_not() -> void:
	# A shack's neon came off a machine and is wired to their grid: a strike
	# stutters it with the rest of their lights. Fires and hearths are nobody's.
	for kind: int in [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT, PropKind.SHACK]:
		check(Lights.POWERED_SOURCES.has(kind), "%s runs on the machines' power" % PropKind.NAMES[kind])
	for kind: int in [PropKind.FIRE, PropKind.HOUSE, PropKind.LAMP, PropKind.KILN, PropKind.VENT]:
		check(not Lights.POWERED_SOURCES.has(kind), "%s is nobody's grid" % PropKind.NAMES[kind])
	Weather.unforce()
