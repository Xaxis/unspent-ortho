extends TestCase
## Lamplight lifts the ink (docs/LOOK.md section 6): the lights system hands the
## same positions and ranges it gives its OmniLight3Ds to the sky, so the pool
## the light paints is the pool the hatching leaves.

const Lights := preload("res://src/systems/15_lights.gd")
const SkySource := preload("res://tests/sky/shader_source.gd")


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
	# The lantern's own pool comes first and follows the player. Asked BEFORE any
	# lamp is planted beside it, and that ordering is the point: where another
	# lamp already lights the ground the lantern is deliberately drawn down to
	# nothing (`night *= 1.0 - 0.9 * under`), `_set_light` then refuses it under
	# 0.01, nothing is pushed to the front, and lamps[0] is whichever village
	# light the chunk stream had reached. Asserting "the lantern comes first"
	# while standing in a lamp's pool asks for the opposite of what the lights
	# promise, and it failed about one run in three with the same number because
	# under load a frame takes longer, the indexing cadence catches up inside the
	# same twenty frames, and the planted lamp joins the pools in time to
	# suppress it. Nothing was racing.
	g.body.lamp_lit = true
	await frames(20)
	check(not g.sky.lamps.is_empty(), "lantern pool")
	if not g.sky.lamps.is_empty():
		var first: Vector4 = g.sky.lamps[0]
		var off := Vector2(first.x, first.z).distance_to(Vector2(g.player.position.x, g.player.position.z))
		gt(off, 0.3, "the lantern's light is out of the body")
		lt(off, 0.8, "and still at the player's hand")
	g.body.lamp_lit = false
	await frames(3)

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
	# at all, so no disc can appear on bright ground (docs/LOOK.md section 6).
	var day := Vector3(1.0, 1.0, 0.99)
	near(Lights.gloom(12.0, day, 1.0), 0.0, 0.02, "noon is not gloom")
	near(Lights.gloom(13.0, day, 1.0), 0.0, 0.02, "nor the afternoon")
	# Seven in the evening is the START of the dusk, not the dark: the tint has
	# gone warm but the sun is still lighting the land, so a lamp is a flame in
	# the hand and lays almost nothing. The gloom belongs to how little light
	# there is, never to how warm the tint has gone (art review finding 2).
	gt(Lights.gloom(19.0, Vector3(0.98, 0.8, 0.66), 0.9), 0.1, "the evening has begun")
	lt(Lights.gloom(19.0, Vector3(0.98, 0.8, 0.66), 0.9), 0.4, "but seven is not the dark")
	# Half past eight is two thirds of the way through the evening now, not all but
	# done: `day_gone` runs 16:48 to 21:36 and the frame there reads 74 against the
	# 55 it did when the light landed at nine (SkyLight.EVENING_FROM). The lamp is
	# worth carrying a little later and a little less early, which is the twilight
	# that was missing.
	gt(Lights.gloom(20.5, Vector3(0.88, 0.71, 0.65), 0.78), 0.65, "half past eight is")
	gt(Lights.gloom(21.5, Vector3(0.7, 0.66, 0.78), 0.72), 0.9, "and half past nine all but")
	near(Lights.gloom(23.0, Vector3(0.56, 0.64, 0.9), 0.7), 1.0, 0.02, "and the dead of night is all of it")
	gt(Lights.gloom(12.0, Vector3(0.5, 0.55, 0.66), 1.0), 0.2, "a storm dark enough at noon is gloom too")
	# Every pool colour is the light's own, and the ones people carry are warm.
	for kind: int in [PropKind.LAMP, PropKind.HOUSE, PropKind.FIRE, PropKind.FIRE_TOWER]:
		var c := Lights.neon_colour({"kind": kind})
		gt(c.x, c.z + 0.2, "a %s burns warm" % PropKind.NAMES[kind])
	gt(Lights.LANTERN_WARM.x, Lights.LANTERN_WARM.z + 0.2, "and so does the lantern people carry")
	# Cold, but low chroma with it: the machines' own light is a violet-white
	# work lamp (Works.STRIP), the same colour as the strip casting it, and the
	# amber lens is the only saturated thing they own.
	var cold := Lights.neon_colour({"kind": PropKind.CHECKPOINT})
	gt(cold.z, cold.x, "the machines' own light is cold")
	gt(cold.z - cold.x, Lights.LANTERN_WARM.z - Lights.LANTERN_WARM.x + 0.3,
		"and the other way from what a person carries")


func test_the_machines_lights_stutter_after_a_strike_and_a_hearth_does_not() -> void:
	# A strike knocks the machines' grid about, so their own lights dip with it.
	for kind: int in [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT]:
		check(Lights.POWERED_SOURCES.has(kind), "%s runs on the machines' power" % PropKind.NAMES[kind])
	for kind: int in [PropKind.FIRE, PropKind.HOUSE, PropKind.LAMP, PropKind.KILN, PropKind.VENT]:
		check(not Lights.POWERED_SOURCES.has(kind), "%s is nobody's grid" % PropKind.NAMES[kind])
	# The neon a shack stole off a machine is on that grid too, and now its TUBE
	# is as well: `GroundColors.NEON` is a mark of its own and world.gdshader
	# multiplies it by `sky_power()`, so the tube, its pool, its glint in wet
	# ground and its shafts in fog all dip together. A hearth in the same wall
	# keeps burning (the lamp codes, which that branch leaves alone).
	check(Lights.POWERED_SOURCES.has(PropKind.SHACK), "a shack's stolen neon blinks with the machines it was cut from")
	Weather.unforce()


## The sky's own wash, run here with the numbers the shader is tuned by. It is a
## per-channel GAIN and nothing else, so this handful of lines IS the operator.
static func _wash(c: Vector3, lamp: Vector3, pool: float, gloom: float, k: Vector3) -> Vector3:
	var ll := lamp.x * 0.3 + lamp.y * 0.59 + lamp.z * 0.11
	if ll < 0.001 or pool <= 0.0:
		return c
	var hue := lamp / ll
	var gain := Vector3.ONE.lerp(hue, k.y) * k.z
	var lit := Vector3(c.x * gain.x, c.y * gain.y, c.z * gain.z)
	return c.lerp(lit, pool * k.x * gloom)


static func _luma(c: Vector3) -> float:
	return c.x * 0.2126 + c.y * 0.7152 + c.z * 0.0722


static func _sat(c: Vector3) -> float:
	var hi := maxf(c.x, maxf(c.y, c.z))
	var lo := minf(c.x, minf(c.y, c.z))
	return 0.0 if hi < 1e-5 else (hi - lo) / hi


func test_a_night_pool_tints_the_ground_and_never_flattens_it() -> void:
	# The rule the village at 23:00 caught us on. A pool is light falling on
	# things, which MULTIPLIES them: whatever is under it keeps its own value and
	# its ratio to its neighbours. An operator that lifts every surface toward a
	# level the light picks turns a campfire, a bench and a person's clothes into
	# one flat orange disc — brighter and more saturated than the noon disc this
	# package was built to remove (docs/LOOK.md section 6).
	var code := SkySource.text(SkySource.SKY_INC)
	check(code.contains("mix(c, c * gain,"), "the wash multiplies the ground; nothing may lift it toward a common level")
	var k := Vector3(SkySource.number(code, "const float SKY_POOL_WASH"), SkySource.number(code, "const float SKY_POOL_TILT"), SkySource.number(code, "const float SKY_POOL_LIFT"))
	lt(k.x, 0.45, "a pool tints the page, it does not repaint it")
	# The village square at 23:00, in the palette's own colours: a charred log in
	# the fire, the turf beside it, the cobbles, a bench, and the three colours
	# of the player's own clothes. Every one inside the lantern's core.
	var under: Array[Vector3] = []
	for c: Color in [Palette.INK[1], Palette.MOSS[3], Palette.STONE[2], Palette.LINEN[2], Palette.MOSS[2], Palette.SLATE[3], Palette.RUST[4], Palette.RIME[5]]:
		under.append(Vector3(c.r, c.g, c.b))
	var lamp := Lights.LANTERN_WARM
	var lit: Array[Vector3] = []
	for c: Vector3 in under:
		lit.append(_wash(c, lamp, 1.0, 1.0, k))
	# Contrast: every pair keeps its ratio. The charred log stayed about six and
	# a half times darker than the turf; it may not come out one and a half.
	for i in under.size():
		for j in range(i + 1, under.size()):
			for ch in 3:
				var was_ch := under[i][ch] / maxf(under[j][ch], 1e-5)
				var now_ch := lit[i][ch] / maxf(lit[j][ch], 1e-5)
				near(now_ch / was_ch, 1.0, 1e-4, "%d against %d keeps channel %d exactly" % [i, j, ch])
			var was := _luma(under[i]) / maxf(_luma(under[j]), 1e-5)
			var now := _luma(lit[i]) / maxf(_luma(lit[j]), 1e-5)
			near(now / was, 1.0, 0.08, "%d against %d keeps its contrast" % [i, j])
	# And the spread of the whole square, channel by channel, does not close up.
	for ch in 3:
		var a := _spread(under, ch)
		var b := _spread(lit, ch)
		gt(b, a * 0.95, "channel %d keeps its spread under the pool" % ch)
	# The core is a tint, not a paint pot: on ground with no colour of its own it
	# stays well under the saturation of a coloured thing.
	var grey := _wash(Vector3(0.22, 0.22, 0.22), lamp, 1.0, 1.0, k)
	lt(_sat(grey), 0.3, "the pool's core is never a saturated disc")
	gt(_luma(grey) / 0.22, 1.05, "and it is still a light: the ground under it lifts")
	# And nothing under it is repainted: a warm lamp on a warm bench warms it,
	# it does not turn it into a colour of the lamp's choosing.
	for i in under.size():
		lt(_sat(lit[i]) - _sat(under[i]), 0.2, "%d keeps its own chroma" % i)


func test_the_pool_is_the_lights_own_colour_and_not_the_grounds() -> void:
	# art 12: the pool must be the LIGHT's colour laid on the ground. Because the
	# wash is one gain, every surface under a lamp turns the same way by the same
	# amount — cold stone and warm turf alike — instead of each ground's own hue
	# simply being turned up.
	var code := SkySource.text(SkySource.SKY_INC)
	var k := Vector3(SkySource.number(code, "const float SKY_POOL_WASH"), SkySource.number(code, "const float SKY_POOL_TILT"), SkySource.number(code, "const float SKY_POOL_LIFT"))
	var warm := Lights.LANTERN_WARM
	var cold := Lights.MACHINE_COLD
	var shift := -1.0
	for c: Color in [Palette.STONE[2], Palette.MOSS[3], Palette.RIME[5], Palette.EARTH[2]]:
		var was := Vector3(c.r, c.g, c.b)
		var now := _wash(was, warm, 1.0, 1.0, k)
		var turn := (now.x / maxf(now.z, 1e-5)) / (was.x / maxf(was.z, 1e-5))
		gt(turn, 1.15, "a lamp lays its own warm over %s" % c)
		if shift < 0.0:
			shift = turn
		near(turn, shift, 0.01, "and turns every ground the same way, because it is one light")
		# The machines' strip is a cold violet-WHITE, not a cyan (the machines'
		# palette runs low chroma: only the amber lens is saturated). So the
		# proof is not a big blue shift; it is that it turns a ground the other
		# way from a lamp, far enough that a player can tell the two pools apart
		# across a village at night.
		var chill := _wash(was, cold, 1.0, 1.0, k)
		var chill_turn := (chill.x / maxf(chill.z, 1e-5)) / (was.x / maxf(was.z, 1e-5))
		lt(chill_turn, 1.0, "the machines' strip lays its own cold over %s" % c)
		lt(chill_turn, turn * 0.85, "and nothing like the lamp does")
	# The ring is the same colour as the core, half as far: two flat steps.
	var stone := Vector3(Palette.STONE[2].r, Palette.STONE[2].g, Palette.STONE[2].b)
	var core := _wash(stone, warm, 1.0, 1.0, k)
	var ring := _wash(stone, warm, 0.5, 1.0, k)
	gt(_luma(core), _luma(ring) + 0.004, "the core is a step above the ring")
	gt(_luma(ring), _luma(stone) + 0.004, "and the ring a step above the dark")
	# And in daylight there is no pool at all, whatever the lamp.
	eq(_wash(stone, warm, 1.0, 0.0, k), stone, "a lamp lit at noon lays nothing")


## Standard deviation of one channel over a set of colours.
static func _spread(set: Array[Vector3], ch: int) -> float:
	var mean := 0.0
	for c: Vector3 in set:
		mean += c[ch]
	mean /= float(set.size())
	var var_ := 0.0
	for c: Vector3 in set:
		var_ += (c[ch] - mean) * (c[ch] - mean)
	return sqrt(var_ / float(set.size()))
