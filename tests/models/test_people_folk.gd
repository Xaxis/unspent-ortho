extends TestCase
## The folk system: villages stream in without stalling a frame, and villagers
## go indoors for the night instead of blinking out.

static var _world: WorldData


func _game(hour: float = 12.0) -> Game:
	if _world == null:
		_world = WorldGen.generate(5)
	var g := Game.new()
	g.world = _world
	g.query = WorldQuery.new(_world)
	g.clock = WorldClock.new(hour)
	g.player = Player.new()
	g.player.world = _world
	g.player.query = g.query
	g.player.pos = _world.spawn
	return g


func _folk(g: Game) -> GameSystem:
	var f: GameSystem = (load("res://src/systems/35_folk.gd") as GDScript).new()
	f.game = g
	return f


func _free(g: Game, f: GameSystem) -> void:
	for p: Dictionary in f.get("folk"):
		(p.model as Node).free()
	f.free()
	g.player.free()
	g.free()


func test_a_village_streams_in_one_person_at_a_time() -> void:
	var g := _game()
	var f := _folk(g)
	g.player.pos = _world.villages[0].pos
	f.call("_stream", false)
	eq((f.get("folk") as Array).size(), 0, "nobody built in the streaming frame")
	var waiting := (f.get("queue") as Array).size()
	gt(waiting, 1, "a village's worth queued")
	check(f.call("pump"), "one built")
	eq((f.get("folk") as Array).size(), 1, "exactly one per pump")
	while f.call("pump"):
		pass
	eq((f.get("folk") as Array).size(), waiting, "the whole village in the end")
	g.player.pos = _world.villages[0].pos + Vector2(300, 300)
	f.call("_stream", false)
	eq((f.get("folk") as Array).size(), 0, "gone when far")
	_free(g, f)


func test_leaving_before_the_queue_empties_drops_the_rest() -> void:
	var g := _game()
	var f := _folk(g)
	g.player.pos = _world.villages[0].pos
	f.call("_stream", false)
	f.call("pump")
	g.player.pos = _world.villages[0].pos + Vector2(300, 300)
	f.call("_stream", false)
	eq((f.get("queue") as Array).size(), 0, "no building for a village you left")
	_free(g, f)


func test_setup_streaming_builds_the_first_village_at_once() -> void:
	var g := _game()
	var f := _folk(g)
	g.player.pos = _world.villages[0].pos
	f.call("_stream", true)
	gt((f.get("folk") as Array).size(), 0, "the first frame is complete")
	eq((f.get("queue") as Array).size(), 0, "nothing left over")
	_free(g, f)


func test_villagers_walk_home_at_dusk_and_come_out_at_dawn() -> void:
	var g := _game()
	var f := _folk(g)
	g.player.pos = _world.villages[0].pos
	f.call("_stream", true)
	var people: Array = f.get("folk")
	gt(people.size(), 0, "villagers")
	for p: Dictionary in people:
		f.call("_step", p, 1.0 / 30.0, true)
	for p: Dictionary in people:
		# No camera in a test: nobody is watching, so they may go in straight away.
		eq(p.state, &"in", "indoors at night")
		check(not (p.model as Node3D).visible, "hidden once indoors")
		check(not (p.model as PersonModel).busy(), "work put down")
	for p: Dictionary in people:
		f.call("_step", p, 1.0 / 30.0, false)
	for p: Dictionary in people:
		eq(p.state, &"out", "out at dawn")
		check((p.model as Node3D).visible, "seen again")
		near((p.pos as Vector2).distance_to(p.door), 0.0, 0.2, "from their own door")
	_free(g, f)


func test_night_hours() -> void:
	var folk: GDScript = load("res://src/systems/35_folk.gd")
	check(folk.call("is_night", 23.0), "23:00 is night")
	check(folk.call("is_night", 3.0), "03:00 is night")
	check(not folk.call("is_night", 12.0), "noon is day")
	check(not folk.call("is_night", 20.0), "20:00 still out")
