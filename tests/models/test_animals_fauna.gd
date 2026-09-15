extends TestCase
## The fauna system: village animals stream with the player, are never mobs,
## and react to someone walking into them.

static var _world: WorldData


func _game() -> Game:
	if _world == null:
		_world = WorldGen.generate(5)
	var g := Game.new()
	g.world = _world
	g.query = WorldQuery.new(_world)
	g.player = Player.new()
	g.player.world = _world
	g.player.query = g.query
	g.player.pos = _world.spawn
	return g


func _fauna(g: Game) -> GameSystem:
	var f: GameSystem = (load("res://src/systems/37_fauna.gd") as GDScript).new()
	f.game = g
	return f


func _free(g: Game, f: GameSystem) -> void:
	for b: Dictionary in f.get("beasts"):
		(b.model as Node).free()
	f.free()
	g.player.free()
	g.free()


func test_villages_bring_their_animals_and_take_them_away() -> void:
	var g := _game()
	var f := _fauna(g)
	var v: Vector2 = _world.villages[0].pos
	g.player.pos = v
	f.call("_stream", true)
	var beasts: Array = f.get("beasts")
	gt(beasts.size(), 0, "animals near a village")
	for b: Dictionary in beasts:
		check(not (b.model as Node).is_in_group(&"mobs"), "%s is not a mob" % b.kind)
		check([&"dog", &"sheep", &"gull"].has(b.kind), "a village kind")
	g.player.pos = v + Vector2(200, 200)
	f.call("_stream", false)
	eq((f.get("beasts") as Array).filter(func(b: Dictionary) -> bool: return b.village == 0).size(), 0, "gone when far")
	_free(g, f)


func test_a_gull_lifts_off_when_you_come_close_and_lands_again() -> void:
	var g := _game()
	var f := _fauna(g)
	var at := g.player.pos + Vector2(1.5, 0)
	f.call("_add", &"gull", at, -2, 7)
	var b: Dictionary = (f.get("beasts") as Array)[0]
	g.player.pos = at + Vector2(-1.0, 0)
	for i in 30:
		f.call("_step", b, 1.0 / 30.0, false)
	check(b.state == &"flee" or b.state == &"fly", "took off, state %s" % b.state)
	g.player.pos = at + Vector2(-100, 0)
	var landed := false
	for i in 30 * 20:
		f.call("_step", b, 1.0 / 30.0, false)
		if b.state == &"stand":
			landed = true
			break
	check(landed, "came down again")
	gt((b.pos as Vector2).distance_to(at), 1.0, "somewhere else")
	_free(g, f)


func test_sheep_scatter_from_someone_walking_into_them() -> void:
	var g := _game()
	var f := _fauna(g)
	var at := g.player.pos
	var spot := Vector2(-1, -1)
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var p := at + Vector2(dx, dy)
			if spot.x < 0.0 and f.call("_ok", p) and f.call("_ok", p + Vector2(1, 0)) and f.call("_ok", p + Vector2(2, 0)):
				spot = p
	check(spot.x >= 0.0, "room for a sheep")
	f.call("_add", &"sheep", spot + Vector2(1, 0), -2, 3)
	var b: Dictionary = (f.get("beasts") as Array)[0]
	g.player.pos = spot
	g.player.speed = 3.4
	var start: Vector2 = b.pos
	for i in 20:
		f.call("_step", b, 1.0 / 30.0, false)
	eq(b.state, &"flee", "running")
	gt((b.pos as Vector2).distance_to(g.player.pos), start.distance_to(g.player.pos) - 0.01, "away from you")
	_free(g, f)


func test_a_village_streams_its_animals_in_one_at_a_time() -> void:
	var g := _game()
	var f := _fauna(g)
	g.player.pos = _world.villages[0].pos
	f.call("_stream", false)
	eq((f.get("beasts") as Array).size(), 0, "nothing built in the streaming frame")
	var waiting := (f.get("queue") as Array).size()
	gt(waiting, 0, "queued")
	f.call("pump")
	eq((f.get("beasts") as Array).size(), 1, "one per pump")
	_free(g, f)


func test_spawned_animals_are_built_once_and_match_a_varied_one() -> void:
	for k: StringName in [&"dog", &"sheep", &"gull"]:
		var a := AnimalModel.spawn(k, null, 17) as AnimalModel
		var b := FigureModel.create(k) as AnimalModel
		b.vary(17)
		eq(a.seed_value, 17, "%s seeded" % k)
		eq(a.rig.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR], b.rig.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR], "%s same animal" % k)
		eq(a.builds, 1, "%s built once" % k)
		eq(b.builds, 2, "%s: create then vary builds twice" % k)
		a.free()
		b.free()


func test_gulls_fly_off_at_dusk_and_back_at_dawn() -> void:
	var g := _game()
	var f := _fauna(g)
	var at := g.player.pos + Vector2(6, 0)
	f.call("_add", &"gull", at, -2, 9)
	var b: Dictionary = (f.get("beasts") as Array)[0]
	g.player.pos = at + Vector2(-100, 0)
	var gone := false
	for i in 30 * 4:
		f.call("_step", b, 1.0 / 30.0, true)
		if not (b.model as Node3D).visible:
			gone = true
			break
		check(b.state == &"flee" or b.state == &"fly", "in the air while visible, state %s" % b.state)
	check(gone, "out of sight after taking off")
	gt((b.pos as Vector2).distance_to(at), 0.5, "flew, did not blink out on the spot")
	for i in 30:
		f.call("_step", b, 1.0 / 30.0, true)
	check(not (b.model as Node3D).visible, "stays away all night")
	f.call("_step", b, 1.0 / 30.0, false)
	check((b.model as Node3D).visible, "back at dawn")
	eq(b.state, &"fly", "flying in")
	var landed := false
	for i in 30 * 12:
		f.call("_step", b, 1.0 / 30.0, false)
		if b.state == &"stand":
			landed = true
			break
	check(landed, "lands again")
	near((b.pos as Vector2).distance_to(b.home), 0.0, 0.5, "on its own shore")
	_free(g, f)
