extends TestCase
## THE CLIMB UP A WALKER, IN A RUNNING GAME (43_climb, ROADMAP slice 3 step 7d):
## once on the leg the keys are the climb's, the body hangs where the hold is on
## this frame's pose and the climb's eye is the one drawing, the move up key takes
## him hold to hold and stops him on a ledge until it is pressed again, a fall is a
## wound and lost minutes and never a death, and the hub reads the panel in the
## crown, whose talk put down lets him back onto the ground.

const Walk := preload("res://src/core/colossus/colossus_walk.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

const SEED := 1
const SIZE := 48


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


func _game() -> Game:
	var o := BootOptions.parse(PackedStringArray(["--seed=%d" % SEED, "--size=%d" % SIZE, "--hour=11",
		"--colossus=0@%.0f" % _planted_minute()]))
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


## Real seconds, while the game runs.
func _run(secs: float) -> void:
	await tree.create_timer(secs).timeout


func test_on_the_leg_the_keys_and_the_eye_are_the_climbs() -> void:
	var g := _game()
	var sys := _system(g, "43_climb")
	await process_frames(4)
	var colossi := tree.get_first_node_in_group(&"colossi")
	sys.set("walker", 0)
	sys.call(&"_begin", WalkerClimb.begin(0, SEED))
	await process_frames(3)
	var climb: WalkerClimb = sys.get("climb")
	check(g.aloft and g.player.hanging, "up the leg, the ground's keys are not his")
	check(tree.root.get_viewport().get_camera_3d() == sys.get("_cam"), "and the climb's eye is the one drawing")
	var def: RefCounted = colossi.view.defs[0]
	var at := climb.world_pos(def, colossi.view.poses[0])
	lt(g.player.model.global_position.distance_to(at), 2.0, "the body hangs at the hold on this frame's pose (%.2f m off)" % g.player.model.global_position.distance_to(at))
	var ground := g.player.pos
	Input.action_press(&"move_up")
	await _run(float(WalkerClimb.HOLD_EVERY) / Climb.RATE + 0.6)
	check(climb.hold >= 1, "the move up key takes him to the next hold (%d)" % climb.hold)
	lt(g.player.pos.distance_to(ground), 0.01, "and the body on the ground below does not walk")
	# Holding on up to the ledge five holds up, and on past it for as long again.
	var ledge := WalkerClimb.STANCE_EVERY / WalkerClimb.HOLD_EVERY
	await _run((float(WalkerClimb.HOLD_EVERY) / Climb.RATE + 0.2) * float(ledge) + 2.0)
	eq(climb.hold, ledge, "a key held stops him on the ledge")
	Input.action_release(&"move_up")
	await process_frames(3)
	Input.action_press(&"move_up")
	await _run(float(WalkerClimb.HOLD_EVERY) / Climb.RATE + 0.6)
	Input.action_release(&"move_up")
	gt(float(climb.hold), float(ledge), "and pressed again, he sets off from it")
	g.queue_free()
	await process_frames(2)


func test_a_fall_wounds_him_and_the_minutes_pass_but_never_kills() -> void:
	var g := _game()
	var sys := _system(g, "43_climb")
	await process_frames(4)
	sys.set("walker", 0)
	sys.call(&"_begin", WalkerClimb.begin(0, SEED))
	await process_frames(2)
	var climb: WalkerClimb = sys.get("climb")
	g.body.health = 2
	var minutes := g.clock.minutes
	climb.wound = WalkerClimb.WOUND_MOST
	climb.lost_minutes = WalkerClimb.CAUGHT_MINUTES
	sys.call(&"_on", &"fell")
	eq(g.body.health, 1, "wounded to the last of him, not killed")
	gt(g.clock.minutes - minutes, WalkerClimb.CAUGHT_MINUTES - 0.5, "and the minutes on the cable pass")
	g.queue_free()
	await process_frames(2)


func test_the_hub_reads_the_panel_and_its_talk_let_go_puts_him_down() -> void:
	Story.forget()
	var g := _game()
	var sys := _system(g, "43_climb")
	var story := _system(g, "49_story")
	await process_frames(4)
	sys.set("walker", 0)
	var c := WalkerClimb.begin(0, SEED)
	c.pitch = WalkerClimb.PITCHES.size() - 1
	c.hold = c.holds_in(c.pitch) - 2
	sys.call(&"_begin", c)
	await process_frames(2)
	Input.action_press(&"move_up")
	await _run(float(WalkerClimb.HOLD_EVERY) / Climb.RATE + 0.6)
	Input.action_release(&"move_up")
	eq(c.state, WalkerClimb.DONE, "the last hold is the hub")
	check(g.talking and story.get("talk") != null and (story.get("talk") as StoryTalk).id == &"the_enclave", "and the panel there answers")
	check(Story.knows(&"enclave_panel"), "which is read")
	var minutes := g.clock.minutes
	story.call(&"_close")
	await process_frames(3)
	check(sys.get("climb") == null and not g.aloft and not g.player.hanging, "the talk put down, he is back on the ground")
	check(tree.root.get_viewport().get_camera_3d() == g.camera, "and the play camera is drawing again")
	gt(g.clock.minutes - minutes, 1.0, "and the way down took its time")
	g.queue_free()
	await process_frames(2)
	Story.forget()
