extends TestCase
## UP A WALKER'S LEG THE CLIMB HAS HIS MOVE AND USE KEYS AND NOTHING ELSE
## (Game.input_blocked against Game.keys_held): the lamp key lights his lamp
## there, and it burns in his hand where he hangs and is heard from him; the
## slate opens and he eats from his bag; a move key still climbs and never walks
## the body left on the land; and nothing he does from a page reaches the land
## under him: nothing is put down, nothing made, and no machine down there holds
## his hands, since no blow passes between his level and theirs.

const Walk := preload("res://src/core/colossus/colossus_walk.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

const SEED := 1
const SIZE := 48
## WalkerClimb.PITCHES: the knee, well up the leg.
const KNEE := 2


## A walk minute from which leg 0 of the small world's walker stands for a while.
func _planted_minute() -> float:
	var d: RefCounted = Def.walkers(SIZE)[0]
	var r: RefCounted = Route.make(d, SEED, SIZE)
	var m := 0.0
	while m < 2000.0:
		var ok := true
		var t := 0.0
		while t < 240.0 and ok:
			ok = int(Walk.pose(d, r, m + t).swinging) != 0
			t += 5.0
		if ok:
			return m
		m += 10.0
	return 0.0


func _game(hour: int = 11) -> Game:
	var o := BootOptions.parse(PackedStringArray(["--seed=%d" % SEED, "--size=%d" % SIZE, "--hour=%d" % hour,
		"--colossus=0@%.0f" % _planted_minute(), "--give=stew:2,driftwood:2"]))
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	g.player.sim.clear_mobs()
	return g


static func _system(g: Game, named: String) -> Node:
	for s in g.systems:
		if s.name == named:
			return s
	return null


## On leg 0 at `pitch`'s `hold`.
func _hang(g: Game, pitch: int, hold: int) -> WalkerClimb:
	var sys := _system(g, "43_climb")
	await process_frames(4)
	var c := WalkerClimb.begin(0, SEED)
	c.pitch = pitch
	c.hold = hold
	sys.set("walker", 0)
	sys.call(&"_begin", c)
	await process_frames(3)
	return c


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await process_frames(3)
	Input.action_release(action)
	await process_frames(3)


func _run(secs: float) -> void:
	await tree.create_timer(secs).timeout


func test_on_the_leg_the_lamp_key_is_his_and_a_move_key_the_climbs() -> void:
	var g := _game()
	var climb: WalkerClimb = await _hang(g, 0, 0)
	check(g.aloft and g.player.hanging, "up the leg")
	check(not g.body.lamp_lit, "his lamp unlit at noon")
	await _tap(&"lamp")
	check(g.body.lamp_lit, "the lamp key lights his lamp on the leg")
	var ground := g.player.pos
	Input.action_press(&"move_up")
	await _run(float(WalkerClimb.HOLD_EVERY) / Climb.RATE + 0.6)
	Input.action_release(&"move_up")
	check(climb.hold >= 1, "a move key is still the climb's: it takes him to the next hold (%d)" % climb.hold)
	lt(g.player.pos.distance_to(ground), 0.01, "and the body left on the land does not walk")
	g.queue_free()
	await process_frames(2)


func test_hung_high_his_lamp_burns_and_is_heard_where_he_hangs() -> void:
	# At night, when the lantern lays its light (in daylight it lays none).
	var g := _game(22)
	await _hang(g, KNEE, 1)
	var lights := _system(g, "15_lights")
	# Where it was heard, against where the figure hung as it was (the leg moves).
	var heard: Array[float] = []
	var on_sfx := func(n: StringName, at: Vector3) -> void:
		if n == &"lamp_on":
			heard.append(at.distance_to(g.player.model.global_position))
	Events.sfx.connect(on_sfx)
	# Lit by the lamp's own path, not its key (the first test has the key).
	lights.call(&"toggle_lantern")
	Events.sfx.disconnect(on_sfx)
	await process_frames(2)
	var figure := g.player.model.global_position
	gt(figure.y - g.world.height_at(g.player.pos), 10.0, "hung on the knee, well off the land (%.0f m up)" % (figure.y - g.world.height_at(g.player.pos)))
	check(g.body.lamp_lit, "his lamp lit")
	var lantern: Node3D = lights.get("lantern")
	var light: OmniLight3D = lights.get("lantern_light")
	check(lantern.visible and light.visible, "and drawn, and laying its light")
	lt(lantern.global_position.distance_to(figure), 1.5, "in his hand where he hangs, not on the land below (%.1f m off)" % lantern.global_position.distance_to(figure))
	var hand: Vector3 = (lights.get_script() as GDScript).get_script_constant_map().LANTERN_HAND
	var local := g.player.model.global_transform.affine_inverse() * lantern.global_position
	lt(local.distance_to(hand), 0.1, "at his side in the figure's own frame, as he carries it on the land (%.2f m off)" % local.distance_to(hand))
	lt(light.global_position.distance_to(figure), 2.0, "and its light with it (%.1f m off)" % light.global_position.distance_to(figure))
	eq(heard.size(), 1, "the lamp is heard lit")
	if not heard.is_empty():
		lt(heard[0], 1.5, "from him up there (%.1f m off)" % heard[0])
	lt(g.view.focus.distance_to(g.player.pos), 0.01, "and the land streams round where he left it")
	g.queue_free()
	await process_frames(2)


func test_on_the_leg_the_slate_is_his_and_feeds_him() -> void:
	var g := _game()
	await _hang(g, KNEE, 1)
	var ui := _system(g, "90_ui")
	await _tap(&"inventory")
	var top: UiScreen = ui.call(&"top")
	check(top != null and top.screen_name == &"inventory", "the carry page opens on the leg")
	await _tap(&"inventory")
	await _tap(&"map")
	top = ui.call(&"top")
	check(top != null and top.screen_name == &"map", "and the survey")
	await _tap(&"map")
	# A machine stirred on the land under the leg: nothing passes between his
	# level and its, so it holds neither his hands nor his slate.
	g.player.sim.add_mob(&"runner", g.player.pos + Vector2(-4, 0))
	check(not Survival.threat_near(g), "no machine on the land below is a threat to him up here")
	g.body.fed_until = g.clock.minutes - 600.0
	check(UiLink.eat(g, g.inventory, &"stew"), "he eats from his bag on the leg")
	gt(g.body.fed_until, g.clock.minutes, "and is fed")
	g.queue_free()
	await process_frames(2)


func test_from_the_leg_nothing_reaches_the_land() -> void:
	var g := _game()
	await _hang(g, KNEE, 1)
	eq(Survival.drop(g, &"driftwood", 1), 0, "nothing is put down from the leg")
	eq(g.inventory.count(&"driftwood"), 2, "it stays in his bag")
	var r := {}
	for h: Dictionary in Crafting.recipes_at(&"hand"):
		if h.get("tool", &"") == &"" and h.get("builds", &"") == &"" and h.get("action", &"") == &"" and not Crafting.sets_going(h):
			r = h
			break
	check(not r.is_empty(), "a plain thing made by hand")
	for id: StringName in (r.needs as Dictionary):
		g.inventory.add(id, int(r.needs[id]))
	var minutes := g.clock.minutes
	check(Crafting.why_not(g, r) != "", "nothing is made with his hands on the leg")
	check(not UiLink.make(g, g.inventory, r), "the making is refused")
	near(g.clock.minutes, minutes, 0.01, "and no time goes on it")
	check(String(_system(g, "90_ui").call(&"why_not_open", &"crafting")) != "", "the making page does not open up there")
	g.queue_free()
	await process_frames(2)
