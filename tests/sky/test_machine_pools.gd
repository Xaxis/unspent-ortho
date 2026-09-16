extends TestCase
## A live machine's light has to land on the ground it is standing on.
##
## It used to land nowhere: a machine's lens went into the GLINT list alone,
## which only mirrors in wet ground, so a watcher at 23:00 with its optic
## burning left the ground under it exactly as dark as the ground ten tiles off
## while a villager's lamp laid sixty pixels of light (art review, wave A
## finding 6). Its pool is cold, small and on the machines' power: nothing about
## a machine's light says safety.

const Lights := preload("res://src/systems/15_lights.gd")


func _game(hour: float, put: PackedStringArray = PackedStringArray()) -> Game:
	var o := BootOptions.new()
	o.size = 64
	o.hour = hour
	o.weather = "clear:0"
	o.put = put
	o.spawn = PackedStringArray([] if not put.is_empty() else ["watcher"])
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


## The pool the sky is handed for the nearest prop of `kind`, or Vector4.ZERO.
static func prop_pool(g: Game, kind: int) -> Vector4:
	var best := Vector4.ZERO
	for q in g.query.props_near(g.player.pos, 12.0):
		if q.kind != kind:
			continue
		for p: Vector4 in g.sky.lamps:
			if Vector2(p.x, p.z).distance_to(q.pos) < 1.2:
				best = p
	return best


## The pool the sky is handed for a machine, or Vector4.ZERO.
static func machine_pool(g: Game) -> Vector4:
	var best := Vector4.ZERO
	for m in g.get_tree().get_nodes_in_group(&"mobs"):
		var mob := m as Mob
		if mob == null or not mob.alive:
			continue
		var at: Vector3 = mob.call("part_position")
		for p: Vector4 in g.sky.lamps:
			if Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z)) < 1.0:
				best = p
	return best


## Poll until the spawned machine's pool shows: a body placed in view still walks
## its own round, and can be a second away from the reach a pool is handed at.
func _wait_for_pool(g: Game) -> Vector4:
	for i in 24:
		await frames(10)
		var p := machine_pool(g)
		if p.w > 0.0:
			return p
	return Vector4.ZERO


func test_a_live_machine_lays_a_pool_on_the_ground_at_night() -> void:
	var g := _game(23.0)
	var p: Vector4 = await _wait_for_pool(g)
	gt(p.w, 0.0, "the machine's pool reaches the sky: %s" % [g.sky.lamps])
	near(p.w, Lights.MACHINE_POOL.x, 1e-4, "at the machine's own reach")
	lt(p.w, float(Lights.SOURCES[PropKind.LAMP][0]), "and smaller than a villager's lamp")
	# Cold, and the machines' own strip colour: never the ochre of a hearth.
	var rgb := Vector3.ZERO
	for i in g.sky.lamps.size():
		if g.sky.lamps[i] == p:
			var c: Vector4 = g.sky.lamp_colors[i]
			rgb = Vector3(c.x, c.y, c.z)
	gt(rgb.z, rgb.x, "the pool is cold, not warm: %s" % rgb)
	g.free()


func test_no_machine_pool_by_day() -> void:
	var g := _game(12.0)
	await frames(30)
	eq(machine_pool(g), Vector4.ZERO, "nothing artificial shows above the day: %s" % [g.sky.lamps])
	g.free()


func test_the_pool_goes_out_with_the_machine() -> void:
	var g := _game(23.0)
	var p: Vector4 = await _wait_for_pool(g)
	gt(p.w, 0.0, "lit while it lives")
	for m in g.get_tree().get_nodes_in_group(&"mobs"):
		var mob := m as Mob
		if mob != null:
			mob.alive = false
			var model := mob.model as MachineModel
			if model != null:
				model.set_part_lit(false)
				model.set_pose(&"dead")
	await frames(60)
	eq(machine_pool(g).w, 0.0, "and dark once it is down")
	g.free()


## A vent is the one light in the game that reaches the ground at noon.
##
## A lamp lit at noon lays nothing — that rule is right and it stays. But the
## Burning's vents are open fire in the ground, and the art review measured them
## at noon as white-hot cores on flat ground with nothing under them: the
## landscape's own fire touching none of its own land (docs/ART.md section 3,
## "glow from below"). The hard part is that a pool ADDS to ground the sun
## already lights, so a vent's old daylight level moved the ground by two values
## out of 255, which is why the floor is what it is.
func test_a_vent_lights_its_own_ground_at_noon_and_a_lamp_does_not() -> void:
	check(Lights.lays_pool(PropKind.VENT, 0.0), "a vent lays its wash in full daylight")
	check(not Lights.lays_pool(PropKind.LAMP, 0.0), "a lamp lays nothing at noon")
	check(not Lights.lays_pool(PropKind.FIRE, 0.0), "nor does a campfire")
	check(Lights.lays_pool(PropKind.LAMP, 1.0), "and every light lays one at night")
	var vent_day := Lights.burning_level(PropKind.VENT, 1.0, 0.0)
	var fire_day := Lights.burning_level(PropKind.FIRE, 1.0, 0.0)
	gt(vent_day, fire_day * 8.0, "at noon a vent burns far harder than a campfire: %.2f vs %.2f" % [vent_day, fire_day])
	# And the night it already had is the night it keeps: the fix is daylight only.
	near(Lights.burning_level(PropKind.VENT, 1.0, 1.0), Lights.burning_level(PropKind.FIRE, 1.0, 1.0), 1e-5,
		"night is untouched")
	# No step on the way down: the floor eases out as the dark comes on.
	var last := Lights.burning_level(PropKind.VENT, 1.0, 0.0)
	for i in range(1, 21):
		var d := Lights.burning_level(PropKind.VENT, 1.0, i / 20.0)
		lt(absf(d - last), 0.12, "the vent's level walks, never jumps, at dark %.2f" % (i / 20.0))
		last = d


## And that wash actually reaches the SKY, in a running game, at noon.
##
## Everything above exercises the pure curve, and a pure curve would pass
## unchanged if the pool never left the CPU — which is what the daylight half of
## this fix dies of when it dies: a vent past REACH, or eight nearer sources
## taking the whole budget, and the ground is flat again with every test still
## green (wave A2 review). This one stands the player beside a vent at noon and
## asks the sky what it was handed.
func test_a_vents_wash_reaches_the_sky_at_noon_where_a_lamp_gets_nothing() -> void:
	var g := _game(12.0, PackedStringArray(["vent"]))
	var vent := Vector4.ZERO
	for i in 24:
		await frames(10)
		vent = prop_pool(g, PropKind.VENT)
		if vent.w > 0.0:
			break
	gt(vent.w, 0.0, "the vent's wash is in the sky's own pool list at noon: %s" % [g.sky.lamps])
	# The village's own lamps stand within the same reach and get nothing:
	# the daylight floor belongs to the one light that is a hole into fire.
	eq(prop_pool(g, PropKind.LAMP), Vector4.ZERO, "a lamp in the same reach still lays nothing at noon")
	eq(prop_pool(g, PropKind.FIRE), Vector4.ZERO, "nor does a campfire")
	g.free()


## A lightning flash drowns the pools; it is NOT daylight.
##
## The bug this guards: the flash is taken off the darkness before anything
## reads it, so a strong flash at night looks to a level curve exactly like
## noon. Every other light only gets dimmer for that. A vent is the one light
## with a daylight FLOOR, so reading a flash as noon burned it brighter than the
## night it was standing in. The flash must come off the level, not off the hour.
func test_a_flash_never_makes_a_vent_burn_harder() -> void:
	var calm := Lights.burning_level(PropKind.VENT, 1.0, 1.0)
	for f: float in [0.9, 0.7, 0.5]:
		var as_flash := calm * (1.0 - f)
		var as_daylight := Lights.burning_level(PropKind.VENT, 1.0, 1.0 - f)
		lt(as_flash, calm, "a flash of %.1f only ever dims a vent" % f)
		lt(as_flash, as_daylight, "and dims it instead of reading it as noon (%.2f vs %.2f)" % [as_flash, as_daylight])
	gt(Lights.burning_level(PropKind.VENT, 1.0, 0.1), calm,
		"the bug had teeth: a flash read as daylight burns brighter than the night")
