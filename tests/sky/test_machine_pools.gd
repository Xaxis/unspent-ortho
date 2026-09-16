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


func _game(hour: float) -> Game:
	var o := BootOptions.new()
	o.size = 64
	o.hour = hour
	o.weather = "clear:0"
	o.spawn = PackedStringArray(["watcher"])
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


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
