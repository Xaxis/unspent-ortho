extends TestCase
## THE NEXT KEEPER (ROADMAP slice 2, step 6; Sentinels.next_keeper): the
## nearest keeper of a design not yet taken, on a leg of the journey he can reach
## (Guide.bodies_reached). Home holds only the Reaper on seeds 1, 7 and 42, so the
## second keeper is the first across the water, from the crossing on. Teague
## names the Candlestick (`anvil_named`), and once it is one he can reach the
## survey marks its strike field and the lead says it in his words, while it
## stands.

const Sx := preload("res://tests/save/save_fixture.gd")


func _state(design: StringName, at: Vector2, fallen := false) -> SentinelState:
	var s := SentinelState.new()
	s.design = design
	s.lair = at
	s.region = 0
	s.fallen = fallen
	return s


## A world of two bodies: tiles x < 600 are body 1, x >= 640 body 2, between
## them water.
func _two_bodies() -> WorldData:
	var w := WorldData.new(0, 800)
	for y in w.size:
		for x in w.size:
			w.continent[y * w.size + x] = 1 if x < 600 else (2 if x >= 640 else 0)
	return w


func test_a_design_once_taken_is_passed_over_for_the_nearest_other() -> void:
	var w := _two_bodies()
	var home := Vector2(0, 0)
	var near_reaper := _state(&"tide_reaper", Vector2(170, 0))
	var far_reaper := _state(&"tide_reaper", Vector2(350, 0))
	var anvil := _state(&"anvil", Vector2(500, 0))
	var states := [far_reaper, anvil, near_reaper]
	var home_only: Array[int] = [1]
	eq(Sentinels.next_keeper(states, home, w, home_only), near_reaper, "before any falls, the nearest")
	near_reaper.fallen = true
	eq(Sentinels.next_keeper(states, home, w, home_only), anvil, "its design taken, the nearest of another, past the second of its kind")
	anvil.fallen = true
	check(Sentinels.next_keeper(states, home, w, home_only) == null, "and none once every design standing is taken")


## ONLY WHERE HE CAN GO: a keeper on a body he cannot reach is passed over
## however near it stands; once he can reach it, it is the next. A lair out in
## the shallows off a shore is on that shore's body.
func test_a_keeper_across_the_water_waits_until_he_can_cross() -> void:
	var w := _two_bodies()
	var home := Vector2(560, 10)
	var lockkeeper := _state(&"lockkeeper", Vector2(660, 10))
	var anvil := _state(&"anvil", Vector2(20, 10))
	var states := [lockkeeper, anvil]
	# As it will be once its fight reads (SentinelDef.ready).
	var def := Sentinels.by_id(&"lockkeeper")
	var was := def.ready
	def.ready = true
	var home_only: Array[int] = [1]
	var both: Array[int] = [1, 2]
	check(lockkeeper.lair.distance_to(home) < anvil.lair.distance_to(home), "the one across the water is the nearer")
	eq(Sentinels.next_keeper(states, home, w, home_only), anvil, "before he can cross: his own body's, the farther")
	eq(Sentinels.next_keeper(states, home, w, both), lockkeeper, "once he can: the nearer, across it")
	anvil.fallen = true
	check(Sentinels.next_keeper(states, home, w, home_only) == null, "with his own body's down, nothing across the water before he can cross")
	eq(Sentinels.body_of(w, Vector2(602, 10)), 1, "a lair in the shallows two tiles off a shore is on that shore's body")
	def.ready = was


## A FIGHT NOBODY CAN READ IS NO LEAD: a design not ready (SentinelDef.ready) is
## passed over however near it stands, and keeps its region unnamed. The
## lockkeeper dens at its city's lock thirty tiles off the raft's landing, and
## until its fight reads the far shore's next keeper is the anvil.
func test_a_keeper_whose_fight_is_not_built_is_never_the_next() -> void:
	var w := _two_bodies()
	var lockkeeper := _state(&"lockkeeper", Vector2(660, 10))
	var anvil := _state(&"anvil", Vector2(780, 10))
	var states := [lockkeeper, anvil]
	var both: Array[int] = [1, 2]
	check(not Sentinels.by_id(&"lockkeeper").ready, "the lockkeeper's fight is not built yet")
	eq(Sentinels.next_keeper(states, Vector2(560, 10), w, both), anvil, "so the anvil, though the lockkeeper is nearer")
	anvil.fallen = true
	check(Sentinels.next_keeper(states, Vector2(560, 10), w, both) == null, "and with the anvil down, no lead to it either")


## On whole worlds, the rule and not the world: before the crossing every next
## keeper is on home's body, and with home's designs taken there is none; from
## the crossing on, the next is on home's body or the far shore's (leg 1), never
## on a body off the journey. On main, home holds only the Reaper on all three
## seeds, and seed 1's nearest anvil (523 tiles) stands on an islet off it.
func test_on_whole_worlds_the_next_keeper_is_one_he_can_reach() -> void:
	for seed_value: int in [1, 7, 42]:
		Story.forget()
		Sx.use_root("next-keeper-%d" % seed_value)
		var g := Sx.game(tree, ["--seed=%d" % seed_value, "--hour=11", "--weather=clear:0"])
		var states := Sentinels.live(g)
		var home := StoryJourney.body_for(g.world, 0)
		var far := StoryJourney.body_for(g.world, 1)
		var journey := StoryJourney.bodies(g.world)
		var home_designs := {}
		for s: SentinelState in states:
			if s.region >= 0 and Sentinels.body_of(g.world, s.lair) == home:
				home_designs[s.design] = true
		var n := 0
		var next := Sentinels.next_keeper(states, g.world.spawn, g.world, Guide.bodies_reached(g))
		while next != null and n < 32:
			eq(Sentinels.body_of(g.world, next.lair), home, "seed %d, before the crossing: %s at %.0f tiles on home's body" % [seed_value, next.design, next.lair.distance_to(g.world.spawn)])
			next.fallen = true
			n += 1
			next = Sentinels.next_keeper(states, g.world.spawn, g.world, Guide.bodies_reached(g))
		eq(n, home_designs.size(), "seed %d: one for each design home holds (%s), then none" % [seed_value, home_designs.keys()])
		@warning_ignore("return_value_discarded")
		Story.hear(StoryCrossing.CROSSED)
		next = Sentinels.next_keeper(states, g.world.spawn, g.world, Guide.bodies_reached(g))
		check(next != null, "seed %d: from the crossing on, a keeper across the water" % seed_value)
		if next != null:
			var body := Sentinels.body_of(g.world, next.lair)
			eq(body, far, "seed %d: %s at %.0f tiles, on the far shore's body" % [seed_value, next.design, next.lair.distance_to(g.world.spawn)])
			check(journey.has(body), "seed %d: on the journey" % seed_value)
		Sx.end(g)
	Story.forget()


## Marked on the survey with Teague's word for its ground, at the anvil's lair.
static func _marked(g: Game, at: Vector2) -> bool:
	for m: Dictionary in UiMapScreen.told(g):
		if m.word == StoryContent.TOLD[&"anvil_named"].word and (m.at as Vector2).distance_to(at) < 0.5:
			return true
	return false


func test_once_teague_has_named_it_the_survey_and_the_lead_point_at_the_strike_field() -> void:
	Story.forget()
	Sx.use_root("next-keeper-lead")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	await process_frames(2)
	var states := Sentinels.live(g)
	var reaper := Sentinels.next_keeper(states, g.world.spawn, g.world, Guide.bodies_reached(g))
	eq(Guide.keeper_goal(g), "", "no lead before the Reaper is down")
	reaper.fallen = true
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.REAPER_DOWN)
	@warning_ignore("return_value_discarded")
	Story.beat(&"anvil_named")
	eq(Guide.keeper_goal(g), "", "named, but across the water before the raft: Teague's lead waits")
	check(not _marked(g, StoryMap.lair_pos(states, g.world.spawn, &"lair:anvil")), "and the survey marks no strike field he cannot reach")
	Story.forget()
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.REAPER_DOWN)
	@warning_ignore("return_value_discarded")
	Story.hear(StoryCrossing.CROSSED)
	var anvil := Sentinels.next_keeper(states, g.world.spawn, g.world, Guide.bodies_reached(g))
	eq(anvil.design if anvil != null else &"", &"anvil", "across: the far shore's anvil is the next")
	if anvil == null:
		Sx.end(g)
		Story.forget()
		return
	eq(StoryMap.lair_pos(states, g.world.spawn, &"lair:anvil", g.world, Guide.bodies_reached(g)), anvil.lair, "the place Teague names is the next keeper's lair")
	eq(Guide.keeper_goal(g), "", "nobody has named the next: no lead in words not yet said")
	check(not _marked(g, anvil.lair), "and nothing marked")
	@warning_ignore("return_value_discarded")
	Story.beat(&"anvil_named")
	eq(Guide.keeper_goal(g), String(StoryContent.LEAD[&"anvil"]), "named, the lead in his words")
	check(_marked(g, anvil.lair), "and the survey marks the strike field at its lair (%s)" % [UiMapScreen.told(g)])
	anvil.fallen = true
	eq(Guide.keeper_goal(g), "", "until it falls")
	Sx.end(g)
	Story.forget()


## Teague's reply to "Why do you fight?" is the only door the naming has: Nell,
## who once had one, talks as she always did.
func test_teague_names_it_the_candlestick() -> void:
	Story.forget()
	eq(Guide.keeper_name(&"glass_desert"), "the keeper", "before anyone has named it")
	eq(_reply_to(StoryTalk.start(&"teague"), &"mast"), -1, "with the Reaper standing, nothing to ask")
	@warning_ignore("return_value_discarded")
	Story.beat(&"reaper_down")
	var talk := StoryTalk.start(&"teague")
	var at := _reply_to(talk, &"mast")
	check(at >= 0, "once the Reaper is down, Teague can be asked what else keeps a yard like that")
	eq(at, _reply_to(talk, &"kids") + 1, "right after why he fights")
	check(talk.pick(at), "and he answers")
	check(Story.landed(&"anvil_named"), "which lands anvil_named")
	eq(Guide.keeper_name(&"glass_desert"), "the Candlestick", "after which it is the Candlestick")
	eq(Guide.keeper_name(&"coast"), "the reaper", "and the coast's keeper keeps its own naming")
	for talk_id: StringName in StoryContent.TALKS:
		var nodes: Dictionary = StoryContent.TALKS[talk_id].nodes
		for n: StringName in nodes:
			if (nodes[n].get("beats", []) as Array).has(&"anvil_named"):
				eq("%s.%s" % [talk_id, n], "teague.mast", "the naming is Teague's alone")
	Story.forget()


## Where in `talk`'s replies the one going to `node` stands, -1 when not offered.
static func _reply_to(talk: StoryTalk, node: StringName) -> int:
	var rs := talk.replies()
	for i in rs.size():
		if rs[i].get("to", &"") == node:
			return i
	return -1
