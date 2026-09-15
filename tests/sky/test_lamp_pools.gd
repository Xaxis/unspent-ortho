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
		gt(r, 1.0, "a pool you can stand in")
		near(Lights.omni_attenuation(sqrt(r * r + h * h), reach), 0.5, 1e-3, "half light at the pool's edge")
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
		near(Vector2(first.x, first.z).distance_to(Vector2(g.player.position.x, g.player.position.z)), 0.0, 0.01, "lantern pool on the player")

	# By day nobody's lamp leaves a pool in the ink.
	g.body.lamp_lit = false
	g.clock.minutes = 12.0 * 60.0
	await frames(20)
	eq(g.sky.lamps.size(), 0, "no pools at noon")
	g.queue_free()
	await frames(1)
	Weather.unforce()
