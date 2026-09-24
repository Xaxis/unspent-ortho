extends TestCase
## The first hour guide: a goal that follows what the player has and lacks, key
## hints that fit the moment and retire once used, and a running game that says
## the goal at wake and the keys after it, a few seconds apart.

const Fx := preload("res://tests/survival/fixture.gd")


func test_the_goal_walks_the_way_in() -> void:
	var g := Fx.flat()
	g.inventory.remove(&"knife")
	g.inventory.add(&"knife")
	check(Guide.goal(g).contains("three driftwood and two stones"), "first a fire, and what it takes: %s" % Guide.goal(g))
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	check(Guide.goal(g).contains("lay it"), "with the makings, lay it: %s" % Guide.goal(g))
	Survival.build(g, &"fire", true)
	check(Guide.goal(g).contains("Charcoal"), "a fire: charcoal next: %s" % Guide.goal(g))
	g.inventory.add(&"charcoal", 1)
	check(Guide.goal(g).contains("haft"), "then a haft: %s" % Guide.goal(g))
	g.inventory.add(&"haft", 1)
	check(Guide.goal(g).contains("tip"), "then plate: %s" % Guide.goal(g))
	g.inventory.add(&"scrap", 1)
	check(Guide.goal(g).contains("pick"), "then the pick: %s" % Guide.goal(g))
	g.inventory.add(&"pick", 1)
	check(Guide.goal(g).contains("ore"), "then the ore: %s" % Guide.goal(g))
	g.body.fed_until = g.clock.minutes - 8.0 * 60.0
	check(Guide.goal(g).contains("Eat"), "hunger comes first: %s" % Guide.goal(g))
	Fx.done(g)


func test_hints_fit_the_moment_and_stay_retired() -> void:
	var g := Fx.flat()
	var retired := {}
	eq(Guide.hint_for(g, retired).get("id", &""), &"walk", "at wake: the walking keys")
	var drift := Fx.put(g, PropKind.DRIFTWOOD, Vector2(0.9, 0))
	Fx.face(g, drift)
	eq(Guide.hint_for(g, retired).get("id", &""), &"take", "facing something: E")
	retired[&"take"] = true
	eq(Guide.hint_for(g, retired).get("id", &""), &"walk", "used once, it is not said again")
	g.clock.skip(13.0 * 60.0)
	g.inventory.add(&"lamp")
	eq(Guide.hint_for(g, retired).get("id", &""), &"lamp", "night asks for the lamp")
	g.body.lamp_lit = true
	check(Guide.hint_for(g, retired).get("id", &"") != &"lamp", "lit, it does not")
	Fx.done(g)


func test_a_running_game_says_the_goal_at_wake_then_the_keys() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var guide: Node = g.get_node("58_guide")
	check(guide != null, "the guide system loads")
	if guide == null:
		g.free()
		return
	var said: Array[String] = []
	# Guide lines go out on the teaching channel, never on the queued message line.
	var listen := func(t: String, _key: String) -> void: said.append(t)
	Events.hint.connect(listen)
	guide.call("_process", 1.0)
	eq(said.size(), 0, "not in the first second")
	guide.call("_process", 1.0)
	eq(said.size(), 1, "then the goal")
	if said.size() >= 1:
		eq(said[0], Guide.goal(g), "the goal line")
	guide.call("_process", 1.0)
	eq(said.size(), 1, "and the next waits its turn")
	guide.call("_process", 5.0)
	eq(said.size(), 2, "a hint after")
	var retired: Dictionary = guide.get("retired")
	check(retired.size() >= 1, "said hints retire")
	Events.took.emit(&"driftwood", 2)
	check(retired.has(&"take"), "a take retires the take hint")
	Events.hint.disconnect(listen)
	g.queue_free()
	await frames(1)


func test_the_first_kill_of_a_game_is_said_once() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var said: Array[String] = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	Events.killed.emit(&"gulls", Vector3.ZERO)
	eq(said.size(), 0, "a gull is not a fight won")
	Events.killed.emit(&"runner", Vector3.ZERO)
	eq(said, [load("res://src/systems/58_guide.gd").KILL_LINE] as Array[String], "the first kill is said")
	Events.killed.emit(&"runner", Vector3.ZERO)
	eq(said.size(), 1, "and only the first")
	Events.message.disconnect(listen)
	g.queue_free()
	await frames(1)


## The goal says where: a fire in a village is the village fire, the one the
## player laid is theirs.
func test_the_goal_names_the_fire_it_sends_the_player_to() -> void:
	var g := Fx.flat()
	g.world.villages.append({"pos": g.player.pos + Vector2(4, 0), "country": Country.COAST, "name": "v"})
	var village_fire := Fx.put(g, PropKind.FIRE, Vector2(5, 0))
	check(Guide.goal(g).contains("at the village fire"), "the village's own: %s" % Guide.goal(g))
	eq(Guide.fire_name(g, village_fire), "the village fire")
	g.world.villages.clear()
	g.world.depleted[village_fire.id] = INF
	check(Guide.goal(g).contains("A fire before dark"), "no fire near: lay one: %s" % Guide.goal(g))
	var mine := Survival.build(g, &"fire", true)
	check(Guide.goal(g).contains("at your fire"), "one laid: %s" % Guide.goal(g))
	eq(Guide.fire_name(g, mine), "your fire")
	check(Guide.HINTS[&"worker"][0].contains("out of its path"), "the worker hint says what disturbs one")
	Fx.done(g)


## After a fight the goal comes back; after coming round from a downing, the
## goal once up, and no key hint until the hours have sunk in.
func test_the_goal_is_said_again_after_a_fight_and_keys_wait_after_a_downing() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var guide: Node = g.get_node("58_guide")
	var said: Array[String] = []
	var listen := func(t: String, _key: String) -> void: said.append(t)
	Events.hint.connect(listen)
	guide.call("_process", 2.0)
	eq(said.size(), 1, "the goal at wake")
	said.clear()
	Events.fight_ended.emit(&"downed")
	guide.call("_process", 1.0)
	eq(said.size(), 0, "nothing while the body lies there")
	guide.call("_process", 1.5)
	eq(said, [Guide.goal(g)] as Array[String], "up: the goal again")
	said.clear()
	for i in 8:
		guide.call("_process", 1.0)
	eq(said.size(), 0, "no key hint in the first seconds after coming round: %s" % [said])
	for i in 8:
		guide.call("_process", 1.0)
	gt(float(said.size()), 0.0, "then the hints resume")
	said.clear()
	Events.fight_ended.emit(&"won")
	# **LONGER THAN `SPACING`, OR THIS IS A TEST OF THE SCHEDULE.** The guide says
	# one line every 4.5 s and this allowed 3, so whether the goal arrived inside
	# the window depended on exactly when the last lesson happened to land. It
	# passed for as long as the lesson list produced a convenient rhythm and went
	# red the day a lesson was added -- with the behaviour it is about unchanged.
	for i in 6:
		guide.call("_process", 1.0)
	check(said.has(Guide.goal(g)), "a fight won: the goal again: %s" % [said])
	Events.hint.disconnect(listen)
	g.queue_free()
	await frames(1)


func test_a_lesson_names_the_key_that_actually_does_it() -> void:
	# **THE ONE PLACE A WRONG KEY COSTS THE MOST.** The lines used to carry their
	# letters -- "E takes what is in front of you" -- while a player may rebind
	# every action on the settings page. `PlayerSettings` is careful that a PAGE
	# can never drift from the live `InputMap`; the first thing the game ever
	# teaches was the one thing that could, and it would say E to somebody whose
	# key was Q, in the first hour, with no way of knowing which to believe.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var guide: Node = g.get_node("58_guide")
	if guide == null:
		g.free()
		return
	var line: String = guide.call("_spell", Guide.HINTS[&"take"][0], Guide.HINTS[&"take"][1])
	var was := PlayerSettings.key_of(&"use")
	check(line.contains(OS.get_keycode_string(was)), "the lesson names the key `use` is on: %s" % line)
	# Move it, and the lesson has to move with it.
	@warning_ignore("return_value_discarded")
	PlayerSettings.bind_key(&"use", KEY_Q)
	var moved: String = guide.call("_spell", Guide.HINTS[&"take"][0], Guide.HINTS[&"take"][1])
	check(moved.contains("Q"), "and follows it when it is rebound: %s" % moved)
	check(moved != line, "which is a different line from the one before")
	PlayerSettings.reset_keys()
	var back: String = guide.call("_spell", Guide.HINTS[&"take"][0], Guide.HINTS[&"take"][1])
	eq(back, line, "and comes back with the keys")
	g.free()


func test_the_game_teaches_the_key_that_reads_a_machine() -> void:
	# **THE VERB THE GUIDE NEVER NAMED.** A player can press 27 things and this
	# taught 11; targeting was one of the sixteen it did not, so the whole read
	# of a machine -- what it is, what it is doing, where its plate is thin --
	# belonged to whoever pressed an unmentioned key. It is said when the first
	# machine comes into view, ahead of the lines describing a runner and a
	# worker, because it is how you would find those out for yourself.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64", "--spawn=runner"])))
	var sim := g.player.sim
	var machine := false
	for m in sim.mobs:
		machine = machine or (m.alive and m.machine)
	check(machine, "a machine is in the world to be read")
	if not machine:
		g.free()
		return
	var offered := []
	for i in 6:
		var h := Guide.hint_for(g, {})
		offered.append(h.get("id", &""))
	check(offered.has(&"target"), "the lesson is offered with a machine in view, got %s" % str(offered[0]))
	# And holding the key spends it: doing the thing IS learning it.
	var guide: Node = g.get_node("58_guide")
	Input.action_press(&"target")
	guide.call("_watch")
	Input.action_release(&"target")
	check((guide.get("retired") as Dictionary).has(&"target"), "holding the key retires the lesson")
	g.free()


func test_the_game_teaches_the_jump_at_something_worth_jumping() -> void:
	# **INNATE AND UNTAUGHT.** Nothing grants the jump and nothing takes it away,
	# so a player who never learns it walks round every ledge the game meant them
	# to go over -- and it was one of the sixteen things the guide never named.
	# Said STANDING AT ONE, because a movement lesson given on flat ground is a
	# sentence about nothing.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=96"])))
	var sim := g.player.sim
	var spot := Jump.find(g.world, g.query, sim.hero.pos, Jump.UP, 40.0)
	if spot.is_empty():
		spot = Jump.find(g.world, g.query, sim.hero.pos, Jump.ACROSS, 40.0)
	check(not spot.is_empty(), "this world has a ledge to stand at")
	if spot.is_empty():
		g.free()
		return
	# On flat ground the lesson must NOT be offered -- that is the half that
	# stops it being said everywhere, which is what a key prompt on the glass is.
	var flat_ids := _offered(g)
	check(not flat_ids.has(&"jump"), "not said where a jump would do nothing")
	# Now stand at the ledge, facing it, the way the tour's `ledge` does.
	sim.hero.pos = spot.at
	sim.hero.facing = (spot.dir as Vector2).angle()
	g.player.pos = sim.hero.pos
	var at_ledge := _offered(g)
	check(at_ledge.has(&"jump"), "said standing at one, got %s" % str(at_ledge[0]))
	# And the feet leaving the ground spends it.
	var guide: Node = g.get_node("58_guide")
	sim.hero.airborne = true
	guide.call("_watch")
	check((guide.get("retired") as Dictionary).has(&"jump"), "jumping retires it")
	g.free()


func test_the_survey_is_offered_once_the_wake_is_out_of_sight() -> void:
	# The third of the sixteen, and the one the world's own size argues for: a
	# 1300-tile island is not a place anybody holds in their head. Said once the
	# wake is behind you, never before -- a survey of ground you can see is a
	# picture of nothing, and a lesson said everywhere is the key prompt on the
	# glass that docs/DESIGN.md forbids.
	var g := Fx.flat(200)
	# A few paces out, not standing ON the wake: at zero distance any threshold
	# passes, so the first version of this could not tell a lesson that waits
	# from one said everywhere. Five tiles is still well inside sight of home.
	var near_home: Vector2 = g.world.spawn + Vector2(5.0, 0)
	g.player.pos = near_home
	if g.player.sim != null:
		g.player.sim.hero.pos = near_home
	var at_home := _offered(g)
	check(not at_home.has(&"map"), "not while the wake is still in sight")
	# Walk out past it.
	var away: Vector2 = g.world.spawn + Vector2(Guide.MAP_FAR + 6.0, 0)
	g.player.pos = away
	if g.player.sim != null:
		g.player.sim.hero.pos = away
	var far := _offered(g)
	check(far.has(&"map"), "offered once it is not, got %s" % str(far[0]))
	Fx.done(g)


func test_crouching_is_taught_while_it_is_still_a_choice() -> void:
	# The pair to `target`: you have learned to look at a machine, now learn not
	# to be looked at. Said only with one in view that has NOT noticed you --
	# after it has, crouching is a regret rather than a choice, and a lesson
	# arriving then is the game telling you what you should have done.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64", "--spawn=hauler"])))
	var sim := g.player.sim
	var quiet: MobState = null
	for m in sim.mobs:
		if m.alive and m.machine and not m.roused():
			quiet = m
	check(quiet != null, "a machine is about that has not noticed the player")
	if quiet == null:
		g.free()
		return
	var offered := _offered(g)
	check(offered.has(&"crouch"), "offered while it has not seen you, got %s" % str(offered[0]))
	# Already crouching: the lesson has nothing to say.
	g.body.crouched = true
	var crouched := _offered(g)
	check(not crouched.has(&"crouch"), "and not while you already are")
	g.body.crouched = false
	# And doing it spends it.
	var guide: Node = g.get_node("58_guide")
	g.body.crouched = true
	guide.call("_watch")
	check((guide.get("retired") as Dictionary).has(&"crouch"), "crouching retires it")
	g.free()

## The lessons that apply right now, in the order the guide would say them.
##
## `hint_for` answers the FIRST one that is not retired, so calling it in a loop
## with an empty set returns the same lesson every time. Retiring each as it
## comes is how you see the list -- and a test that read the first answer alone
## was only passing when the lesson it wanted happened to be first.
func _offered(g: Game) -> Array:
	var out: Array = []
	var retired := {}
	for i in 12:
		var h := Guide.hint_for(g, retired)
		var id: StringName = h.get("id", &"")
		if id == &"":
			break
		out.append(id)
		retired[id] = true
	return out


func test_building_is_taught_when_the_creel_can_actually_build() -> void:
	# A whole pillar of the game nobody was told about (VISION §9): a player can
	# put a place up, keep it, and have the machines come for it. Said the first
	# time the creel really holds enough for a piece -- before that the lesson is
	# an advertisement, which is the thing a key prompt on the glass always is.
	var g := Fx.flat(60)
	check(not _offered(g).has(&"holding"), "not with an empty creel")
	# Fill it until something is buildable, the way play would.
	var want := StructureKind.BUILDABLE[0]
	for id: StringName in (SettlementBuild.missing(g.inventory, want) as Dictionary):
		g.inventory.add(id, int((SettlementBuild.missing(g.inventory, want) as Dictionary)[id]))
	check(SettlementBuild.can_make(g.inventory, want), "the creel now holds a piece")
	check(_offered(g).has(&"holding"), "offered once it does")
	Fx.done(g)

func test_a_fitted_ability_names_its_own_key() -> void:
	# **THE WHOLE GEAR PILLAR WAS BEHIND AN UNMENTIONED KEY.** A player finds a
	# wing, chooses it, puts it in the back slot -- and nothing in the game ever
	# said which key opens it. The same gap `target` was, and worse, because
	# this one the player went and earned.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64", "--fit=glide_wing"])))
	var book := Guide.ability_book(g)
	check(book != null, "the gear system keeps a book, found by what it keeps")
	if book == null:
		g.free()
		return
	check(book.has(&"glide"), "the wing granted the glide")
	eq(Guide.granted(g), [&"glide"] as Array[StringName], "granted, and the innate jump left out")
	var offered := _offered(g)
	check(offered.has(&"ability_glide"), "the glide names its key, got %s" % str(offered))
	check(not offered.has(&"ability_dash"), "and nothing names a key for gear nobody is wearing")
	# The line names the ACTION, so the key row and the words agree with the
	# keyboard rather than with a letter typed into this file.
	eq(Guide.HINTS[&"ability_glide"][1], [&"ability_glide"], "the lesson names the action")
	# Firing it is learning it, and the book is what wrote the moment down.
	var guide: Node = g.get_node("58_guide")
	book.ready_at[&"glide"] = 1.0
	guide.call("_watch")
	check((guide.get("retired") as Dictionary).has(&"ability_glide"), "firing it retires the lesson")
	g.free()


func test_no_ability_lesson_without_the_gear_that_grants_it() -> void:
	# The pair to it: a lesson that arrives before the player has the thing is an
	# advertisement, which is what a key prompt on the glass always is.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	eq(Guide.granted(g), [] as Array[StringName], "nothing fitted, nothing granted")
	var offered := _offered(g)
	for id: StringName in offered:
		check(not String(id).begins_with("ability_"), "no ability lesson, got %s" % id)
	g.free()


func test_the_key_row_on_the_glass_gets_a_spelled_line_and_a_real_key() -> void:
	# **THE SEAM NOBODY WAS WATCHING.** Every other test here asks `Guide` or
	# `58_guide`. This asks what 90_ui HANDS THE HUD -- which is where the whole
	# key row died silently when `hint_for` started answering `keys` instead of
	# `key`, and stayed dead with fourteen green tests over it. A shot found it,
	# so this is the instrument that should have.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var ui: Node = g.get_node("90_ui")
	check(ui != null, "the ui system loads")
	if ui == null:
		g.free()
		return
	ui.call("_step_guide", 999.0)
	var teach: Dictionary = ui.get("_teach")
	check(not teach.is_empty(), "the guide offers the glass a lesson at all")
	if teach.is_empty():
		g.free()
		return
	var line := String(teach.get("line", ""))
	var key := String(teach.get("key", ""))
	check(not line.contains("%s"), "the line is spelled, not a raw template: %s" % line)
	check(key != "", "and it carries a key for the cap")
	# The key is the one the keyboard actually has, not a letter typed anywhere.
	var walks := PlayerSettings.cap_of(Guide.MOVE[0])
	check(line.contains(PlayerSettings.label_of(Guide.MOVE)) or key == walks or key.length() <= 4,
		"the cap reads as a key, got %s" % key)
	g.free()


func test_the_journal_is_taught_once_there_is_something_in_it() -> void:
	# The only app the guide never named. Everything found is already written
	# down; a player never told carries the story in their head or loses it.
	# Said only once the book has a page, because a lesson that opens an empty
	# book teaches that the book is empty.
	Story.forget()
	var g := Fx.flat(60)
	check(not _offered(g).has(&"journal"), "nothing found yet, nothing to open")
	# Read one page, the way play would.
	var id: StringName = StoryContent.FRAGMENTS.keys()[0]
	check(Story.read(id), "a page is read")
	check(_offered(g).has(&"journal"), "offered once the book holds one, got %s" % str(_offered(g)))
	Story.forget()
	Fx.done(g)


func test_opening_the_journal_retires_its_lesson() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	var guide: Node = g.get_node("58_guide")
	guide.call("_on_screen", &"journal", true)
	check((guide.get("retired") as Dictionary).has(&"journal"), "opening it spends the lesson")
	g.free()


func test_the_swing_is_named_before_the_dodge_when_a_machine_comes_on() -> void:
	# **THE CORE VERB, NEVER NAMED.** `side` is the only lesson carrying `swing`,
	# it arrives after plate has already rung, and its words assume you have been
	# striking all along. Nothing said which key did it.
	#
	# The moment is STAGED, not waited for. The first version of this let the
	# runner rouse itself and skipped its own assertions when it had not -- and
	# it passed with the whole feature deleted. A test that excuses itself when
	# the moment does not arrive is testing nothing at all.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64", "--spawn=runner"])))
	var sim := g.player.sim
	var coming: MobState = null
	for m in sim.mobs:
		if m.alive and m.machine:
			coming = m
	check(coming != null, "a machine is on the land")
	if coming == null:
		g.free()
		return
	# Roused, hostile, and standing off past the radius that hushes the glass:
	# the exact moment both lessons are written for.
	coming.mood = MobState.CHASING
	coming.disposition = &"hostile"
	coming.pos = sim.hero.pos + Vector2(Survival.THREAT_RADIUS + 4.0, 0.0)
	var offered := _offered(g)
	check(offered.has(&"dodge"), "the dodge is offered at this moment, got %s" % str(offered))
	check(offered.has(&"fight"), "and so is the swing, got %s" % str(offered))
	check(offered.find(&"fight") < offered.find(&"dodge"), "the swing comes first: %s" % str(offered))
	# Swinging once spends it, the way a dodge spends its own.
	var guide: Node = g.get_node("58_guide")
	sim.hero.blow_at = 1.0
	guide.call("_watch")
	check((guide.get("retired") as Dictionary).has(&"fight"), "swinging retires it")
	g.free()


func test_the_swing_lesson_names_the_swing_key() -> void:
	eq(Guide.HINTS[&"fight"][1], [&"swing"], "it names the action, not a letter")
	check(not String(Guide.HINTS[&"fight"][0]).contains("J"), "and spells no key in its words")


func test_a_town_says_it_is_safe_ground_while_you_stand_in_it() -> void:
	# The owner's ask: "safe havens like towns to systematically teach players
	# the game". The ground round a village IS the safest in the game -- sixteen
	# of nineteen roster rows keep a `green_min` off it -- and nothing ever said
	# so. A safety the player cannot know about buys them nothing.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=256", "--village=0"])))
	check(not g.world.villages.is_empty(), "the world has a town")
	if g.world.villages.is_empty():
		g.free()
		return
	check(Haven.holds(g.world, g.player.pos), "--village=0 stands the player in one")
	check(_offered(g).has(&"haven"), "and the town says so, got %s" % str(_offered(g)))
	# Out in the country it has nothing to say.
	var v: Dictionary = g.world.villages[0]
	g.player.pos = (v.pos as Vector2) + Vector2(g.world.village_reach(v) + 40.0, 0.0)
	check(not Haven.holds(g.world, g.player.pos), "walked well clear of it")
	check(not _offered(g).has(&"haven"), "open country does not claim to be a haven")
	g.free()


func test_the_key_row_skips_a_lesson_that_names_no_key() -> void:
	# `haven`, `runner` and `worker` are things to KNOW, not things to press. The
	# slate's key row is drawn from `hint_for`, so a keyless lesson standing at
	# the front of the list blanked the row until the guide got round to saying
	# it -- which `runner` and `worker` have been doing since before `haven`.
	var g := Fx.flat(60)
	var retired := {}
	var keyed := Guide.hint_for(g, retired, true)
	check(not keyed.is_empty(), "the row is offered something")
	check(not (keyed.get("keys", []) as Array).is_empty(), "and it names a key")
	for id: StringName in [&"haven", &"runner", &"worker"]:
		eq((Guide.HINTS[id][1] as Array).size(), 0, "%s names no key, so the row must skip it" % id)
	Fx.done(g)


func test_somebody_who_lives_here_can_give_the_lesson_instead_of_the_glass() -> void:
	# docs/DESIGN.md §Safe havens: "the teaching lives in the place, not on the
	# glass. A lesson is somebody who lives there... never a key prompt hung in
	# the middle of the frame." A villager with nothing scripted used to answer
	# "They have nothing to say to you" -- a dead end standing exactly where a
	# teacher belongs.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=256", "--village=0"])))
	var guide: Node = g.get_node("58_guide")
	check(guide.has_method(&"teach_now"), "somebody in the game can be asked to teach")
	var said: Array[String] = []
	var listen := func(t: String, _key: String) -> void: said.append(t)
	Events.hint.connect(listen)
	var gave: bool = guide.call("teach_now")
	Events.hint.disconnect(listen)
	check(gave, "there was a lesson to give")
	eq(said.size(), 1, "and it was said once, got %s" % [said])
	if not said.is_empty():
		check(said[0].begins_with("\"") and said[0].ends_with("\""),
			"in somebody's voice rather than as a caption: %s" % said[0])
		check(not said[0].contains("%s"), "spelled, not a raw template")
	# **ONE CURRICULUM, NOT TWO.** A lesson given by a person is THE lesson, so it
	# is spent: the glass must not say it again afterwards.
	var retired: Dictionary = guide.get("retired")
	gt(float(retired.size()), 0.0, "giving it spends it")
	g.free()


func test_a_teacher_with_nothing_left_to_teach_says_so() -> void:
	# The fall-back has to survive, or a village with a taught player becomes a
	# row of people who answer nothing at all.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=256", "--village=0"])))
	var guide: Node = g.get_node("58_guide")
	var retired: Dictionary = guide.get("retired")
	for id: StringName in Guide.HINTS:
		retired[id] = true
	eq(guide.call("teach_now"), false, "with every lesson spent, nobody claims to teach")
	g.free()


func test_a_held_road_says_all_three_ways_past_it() -> void:
	# docs/DESIGN.md §Safe havens: "each haven teaches what the road out of it
	# will ask for". VISION §10.3 is emphatic that a hold is NOT a lock -- cut it,
	# answer the place, or leave the road, and all three are real. A player told
	# none of them meets a barricade and reads it as a wall, which is the message
	# saying no that §10.3 forbids, wearing a model.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=256"])))
	var holds: Node = g.get_node("24_holds")
	check(holds != null, "the holds system loads")
	if holds == null:
		g.free()
		return
	# Stand at a hold the plan still keeps. NO escape hatch if there is none:
	# a test that excuses itself when its moment does not arrive is reporting on
	# the weather, and this world is asserted to have one.
	var sites: Array = holds.get("sites")
	var closed_at := Vector2.INF
	for h: Variant in sites:
		if bool(holds.call("closed", h)):
			closed_at = h.pos
			break
	check(closed_at.is_finite(), "seed 4 has a road the plan is standing on")
	if not closed_at.is_finite():
		g.free()
		return
	g.player.pos = closed_at + Vector2(3.0, 0.0)
	check(_offered(g).has(&"road"), "walking up to it, the three ways are said: %s" % str(_offered(g)))
	# And far away it has nothing to say about a road nobody is near. "Far" is
	# far from EVERY hold the plan keeps, found rather than assumed: a point just
	# past ROAD_NEAR east of the first hold was open country until villages were
	# counted per area (GEN 24), and then it was the next hold's road.
	var far := Vector2.INF
	for step in range(int(Guide.ROAD_NEAR) + 20, g.world.size, 8):
		for b in 16:
			var q := closed_at + Vector2.from_angle(TAU * b / 16.0) * float(step)
			if g.world.level_at(floori(q.x), floori(q.y)) <= 0:
				continue
			var clear := true
			for h: Variant in sites:
				if bool(holds.call("closed", h)) and (h.pos as Vector2).distance_to(q) < Guide.ROAD_NEAR + 20.0:
					clear = false
					break
			if clear:
				far = q
				break
		if far.is_finite():
			break
	check(far.is_finite(), "seed 4 has land away from every held road")
	g.player.pos = far
	check(not _offered(g).has(&"road"), "and not from the other end of the island")
	# The words carry all three ways, because the whole point is that it is not a lock.
	var line := String(Guide.HINTS[&"road"][0])
	for way: String in ["Cut", "answer", "leave the road"]:
		check(line.contains(way), "the lesson names the %s way: %s" % [way, line])
	g.free()
