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
const Treads := preload("res://src/core/colossus/colossus_treads.gd")

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


## Put him at `at`, the fight's body with him (it is what the ground's systems
## move, and he follows it).
static func _stand(g: Game, at: Vector2) -> void:
	g.player.pos = at
	g.player.hero.pos = at


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
	eq(int(colossi.view.climbed), 0, "and the walker he is on is drawn all there, never given to the air by its hub's distance")
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


## A RIDE TAKES IN THE ISLAND: in the middle of a ride the eye is kilometres off
## the leg, the island and the leg's knee both in its frame, so the leg's line
## runs down to the island, on a lens long enough that the island is no speck;
## on a hold it is the climb's own eye again.
func test_a_ride_takes_in_the_island() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=7", "--place=tread0", "--colossus=2@tread0+30",
		"--hour=12", "--weather=clear:0"])))
	g.player.sim.clear_mobs()
	var sys := _system(g, "43_climb")
	var k: Dictionary = (sys.get_script() as GDScript).get_script_constant_map()
	await process_frames(4)
	sys.call(&"_stage", "drum:ride:0.5")
	await process_frames(3)
	var c: WalkerClimb = sys.get("climb")
	check(c != null and c.state == WalkerClimb.RIDE, "riding up from the drum")
	if c == null:
		g.queue_free()
		return
	var cam: Camera3D = sys.get("_cam")
	var land: Vector3 = sys.call(&"_land")
	var colossi := tree.get_first_node_in_group(&"colossi")
	var w: int = sys.get("walker")
	var him: Transform3D = sys.call(&"body_frame", colossi.view.defs[w], colossi.view.poses[w])
	gt(cam.global_position.distance_to(him.origin), 1000.0, "mid-ride the eye is kilometres off the leg")
	check(cam.is_position_in_frustum(land), "the island's middle is in the frame")
	var knee: Vector3 = (colossi.view.poses[w].knees as Array)[c.leg]
	check(cam.is_position_in_frustum(knee), "and so is the knee of the leg he is in, so its line runs down to the island")
	var to_land := land - cam.global_position
	var share := float(g.world.size) * 0.5 / (to_land.length() * tan(deg_to_rad(cam.fov) * 0.5))
	gt(share, 0.1, "and the island is no speck in it (%.2f of the half frame)" % share)
	lt(cam.fov, float(k.EYE_FOV), "on a lens longer than the climb's own")
	c.state = WalkerClimb.CLIMB
	c.busy = 0.0
	await process_frames(3)
	eq(cam.fov, float(k.EYE_FOV), "on a hold, the climb's own lens")
	eq(cam.near, float(k.EYE_NEAR), "and its own near plane")
	g.queue_free()
	await process_frames(2)


## THE CLIMB'S TWO HINTS NAME HIS OWN KEY, IN THEIR MOMENT: nothing is hinted
## away from every cable; at the foot of a planted foot's cable, in its tread,
## the hint names the key `use` is on, puts it on the cap, and follows it when it is rebound; and as
## his leg goes up under him the swing's hint is said once a swing, naming none.
func test_the_climbs_hints_name_his_own_key_in_their_moment() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=7", "--place=tread0", "--colossus=2@tread0+30",
		"--hour=12", "--weather=clear:0"])))
	g.player.sim.clear_mobs()
	var sys := _system(g, "43_climb")
	var said: Array = []
	var listen := func(t: String, key: String) -> void: said.append([t, key])
	Events.hint.connect(listen)
	await process_frames(4)
	var rim: Dictionary = {}
	for f: Dictionary in sys.call(&"_feet_in_treads"):
		if bool(f.planted):
			rim = f
			break
	check(not rim.is_empty(), "a foot stands in a tread")
	if not rim.is_empty():
		var pad: Vector3 = (rim.pads as Array)[0]
		var on: Vector2 = sys.call(&"_cable_foot", rim)
		var off := on + Vector2(Treads.rim_r(pad) * 4.0, 0.0)
		_stand(g, off)
		await process_frames(3)
		check(not bool(sys.call(&"tour_seen", &"climb_cable")) and said.is_empty(), "away from the cable nothing is hinted: %s" % [said])
		_stand(g, on)
		await process_frames(3)
		check(bool(sys.call(&"tour_seen", &"climb_cable")), "at the cable's foot in the crater he can take it")
		eq(said.size(), 1, "and the climb's hint is said, once: %s" % [said])
		if said.size() == 1:
			check(String(said[0][0]).contains(PlayerSettings.label_of(&"use")), "naming the key `use` is on: %s" % said[0][0])
			eq(String(said[0][1]), PlayerSettings.cap_of(&"use"), "on its cap")
			check(not String(said[0][0]).contains("%s"), "spelled, not a template")
		@warning_ignore("return_value_discarded")
		PlayerSettings.bind_key(&"use", KEY_Q)
		_stand(g, off)
		await process_frames(3)
		_stand(g, on)
		await process_frames(3)
		PlayerSettings.reset_keys()
		eq(said.size(), 2, "walked off and back, it is said again")
		if said.size() == 2:
			check(String(said[1][0]).contains("Q") and String(said[1][1]) == "q", "in the key it was moved to: %s [%s]" % [said[1][0], said[1][1]])
	said.clear()
	sys.set("walker", int(rim.get("walker", 0)))
	sys.call(&"_begin", WalkerClimb.begin(int(rim.get("leg", 0)), 7))
	await process_frames(2)
	var standing := {"swinging": -1}
	var swinging := {"swinging": int(rim.get("leg", 0))}
	for pose: Dictionary in [standing, swinging, swinging, standing, swinging]:
		sys.call(&"_say_swing", pose)
	eq(said.size(), 2, "the swing's hint is said as each swing begins: %s" % [said])
	for s: Array in said:
		eq(String(s[1]), "", "and names no key")
	Events.hint.disconnect(listen)
	g.queue_free()
	await process_frames(2)


## EVERY RIDE UP INSIDE THE BONE IS SAID, keyed by the pitch just climbed, and
## the hub's own pitch, which ends at the panel, and the cable, which goes
## straight on up the drum, have none.
func test_every_ride_is_said_and_the_hub_is_not() -> void:
	var rides: Dictionary = StoryContent.CLIMB.get(&"climb_ride", {})
	var ridden := 0
	for i in WalkerClimb.PITCHES.size():
		var id: StringName = WalkerClimb.PITCHES[i].id
		if i < WalkerClimb.PITCHES.size() - 1 and float(WalkerClimb.PITCHES[i].ride) > 0.0:
			check(String(rides.get(id, "")) != "", "the ride up from %s is said" % id)
			ridden += 1
		else:
			check(not rides.has(id), "%s has no ride line" % id)
	eq(rides.size(), ridden, "and no line waits for a ride that is not taken")


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
	# The key that took him up the last hold is still down as it opens, and is
	# not a press on its replies (measured: the first reply offered was the last).
	eq(int((story.get("view") as UiTalkView).choice), 0, "the climb's key is not a reply")
	check(Story.knows(&"enclave_panel"), "which is read")
	var minutes := g.clock.minutes
	story.call(&"_close")
	await process_frames(3)
	check(sys.get("climb") == null and not g.aloft and not g.player.hanging, "the talk put down, he is back on the ground")
	check(tree.root.get_viewport().get_camera_3d() == g.camera, "and the play camera is drawing again")
	var colossi := tree.get_first_node_in_group(&"colossi")
	eq(int(colossi.view.climbed), -1, "and no walker is drawn as the one he is on")
	gt(g.clock.minutes - minutes, 1.0, "and the way down took its time")
	g.queue_free()
	await process_frames(2)
	Story.forget()
