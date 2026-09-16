extends TestCase
## The hazards system inside a real running game: it reads the place the player
## stands in, writes Body.pressure, slows the legs, says its line once, drains
## slowly, and keeps its state through a save.

var game: Game


func _boot(extra: PackedStringArray = PackedStringArray()) -> Node:
	var args := PackedStringArray(["--seed=1", "--size=48", "--hour=12"])
	args.append_array(extra)
	game = Game.new()
	tree.root.add_child(game)
	game.setup(BootOptions.parse(args))
	return _system("52_hazards")


func test_the_system_reads_the_place_and_writes_what_the_body_feels() -> void:
	var sys := _boot()
	check(sys != null, "52_hazards loaded")
	var p: Hazards.Place = sys.call("place")
	check(p != null, "it can say what the place is doing")
	near(p.hour, game.clock.hour(), 1e-4, "on the game's own clock")
	eq(p.hazards, BiomeRegistry.at(game.world, game.player.pos).hazards, "from the landscape type it stands in")
	# A place with a real pressure in it: the body carries it within one sweep.
	sys.call("_sweep", 1.0)
	eq(game.body.pressure, Hazards.after_resist(sys.call("raw"), game.body.resist), "what is left after the gear")
	game.free()


func test_a_cold_night_is_felt_in_the_legs_and_said_once() -> void:
	var sys := _boot(["--hour=1"])
	# Stand the body in a bitter place by hand: the coast at 1 a.m. is mild.
	game.body.resist = {}
	var p := Hazards.Place.new()
	p.hazards = {&"cold": 0.95}
	p.hour = 1.0
	var raw := Hazards.felt(p)
	game.body.pressure = Hazards.after_resist(raw, {})
	gt(Hazards.worst(game.body.pressure), Hazards.BITE, "a bitter night bites")
	Survival.update_body(game)
	lt(game.body.move_factor, 1.0, "it is in the legs")
	var before := game.body.move_factor
	game.body.pressure = {}
	Survival.update_body(game)
	gt(game.body.move_factor, before, "and out of them again when it lets go")
	# The line is said once, not every sweep.
	var said: Array[String] = []
	var listener := func(line: String) -> void: said.append(line)
	Events.message.connect(listener)
	game.body.pressure = {&"cold": 0.9}
	sys.call("_tell", game.body.pressure)
	sys.call("_tell", game.body.pressure)
	Events.message.disconnect(listener)
	eq(said.size(), 1, "said once while it lasts")
	eq(said[0], Hazards.line_for(&"cold"))
	game.free()


func test_the_drain_takes_health_slowly_and_leaves_the_body_standing() -> void:
	var sys := _boot()
	game.body.health = game.body.max_health
	# Ten world hours of the worst pressure there is, a sweep at a time.
	for i in 120:
		sys.call("_drain", {&"cold": 1.0}, 5.0 / Tuning.MINUTES_PER_SECOND)
	lt(float(game.body.health), float(game.body.max_health), "it has cost health")
	eq(game.body.health, Hazards.HARM_FLOOR, "down to the floor and no further")
	for i in 200:
		sys.call("_drain", {&"cold": 1.0}, 5.0 / Tuning.MINUTES_PER_SECOND)
	eq(game.body.health, Hazards.HARM_FLOOR, "the weather never kills")
	game.free()


func test_a_fire_and_a_roof_reach_the_system_not_just_the_rules() -> void:
	var sys := _boot()
	near(float(sys.call("_fire")), 0.0, 1e-5, "no fire out here")
	Survival.build(game, &"fire", true)
	gt(float(sys.call("_fire")), 0.0, "a fire you laid warms you")
	game.free()


func test_the_gauges_the_slate_shows_are_the_pressures_the_body_carries() -> void:
	_boot()
	game.body.pressure = {&"cold": 0.9, &"dark": Hazards.FELT * 0.5}
	var shown := UiRules.pressures(game.body, game.clock.minutes, 0.0)
	var ids: Array[StringName] = []
	for row: Dictionary in shown:
		ids.append(row.id)
	check(ids.has(&"cold"), "a cold that bites is on the glass")
	check(not ids.has(&"dark"), "one too faint to feel is not")
	for row: Dictionary in shown:
		if row.id == &"cold":
			eq(row.level, 2, "and it is the warning colour")
	game.free()


func test_what_the_hazards_keep_through_a_save() -> void:
	var sys := _boot()
	sys.call("_tell", {&"cold": 0.9})
	var saved: Variant = sys.call("_save")
	sys.call("_load", {"said": [], "carried": 0.0})
	sys.call("_load", saved)
	var said: Array[String] = []
	var listener := func(line: String) -> void: said.append(line)
	Events.message.connect(listener)
	sys.call("_tell", {&"cold": 0.9})
	Events.message.disconnect(listener)
	eq(said.size(), 0, "a line already said is not said again after a load")
	game.free()


func _system(part: String) -> Node:
	for s in game.systems:
		if String(s.name).contains(part):
			return s
	return null
