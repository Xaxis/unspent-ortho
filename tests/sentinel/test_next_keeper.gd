extends TestCase
## THE SECOND KEEPER (ROADMAP slice 2, step 6; Sentinels.next_keeper): the
## nearest keeper of a design not yet taken. On seeds 1 and 7 that is the Tide
## Reaper first and the anvil once it is down (seed 7's second Tide Reaper, the
## nearer, is passed over). Teague names it the Candlestick (`anvil_named`), and
## from then the survey marks its strike field and the lead says it in his words,
## while it stands.

const Sx := preload("res://tests/save/save_fixture.gd")


func _state(design: StringName, at: Vector2, fallen := false) -> SentinelState:
	var s := SentinelState.new()
	s.design = design
	s.lair = at
	s.region = 0
	s.fallen = fallen
	return s


func test_a_design_once_taken_is_passed_over_for_the_nearest_other() -> void:
	var home := Vector2(0, 0)
	var near_reaper := _state(&"tide_reaper", Vector2(170, 0))
	var far_reaper := _state(&"tide_reaper", Vector2(350, 0))
	var anvil := _state(&"anvil", Vector2(500, 0))
	var states := [far_reaper, anvil, near_reaper]
	eq(Sentinels.next_keeper(states, home), near_reaper, "before any falls, the nearest")
	near_reaper.fallen = true
	eq(Sentinels.next_keeper(states, home), anvil, "its design taken, the nearest of another, past the second of its kind")
	anvil.fallen = true
	check(Sentinels.next_keeper(states, home) == null, "and none once every design standing is taken")


func test_on_seeds_1_and_7_the_second_keeper_is_the_anvil() -> void:
	for seed_value: int in [1, 7]:
		Sx.use_root("next-keeper-%d" % seed_value)
		var g := Sx.game(tree, ["--seed=%d" % seed_value, "--hour=11", "--weather=clear:0"])
		var states := Sentinels.live(g)
		var first := Sentinels.next_keeper(states, g.world.spawn)
		eq(first.design, &"tide_reaper", "seed %d: the Tide Reaper first" % seed_value)
		first.fallen = true
		var second := Sentinels.next_keeper(states, g.world.spawn)
		eq(second.design, &"anvil", "seed %d: the anvil second (%.0f tiles)" % [seed_value, second.lair.distance_to(g.world.spawn)])
		Sx.end(g)


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
	var reaper := Sentinels.next_keeper(states, g.world.spawn)
	eq(Guide.keeper_goal(g), "", "no lead before the Reaper is down")
	reaper.fallen = true
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.REAPER_DOWN)
	var anvil := Sentinels.next_keeper(states, g.world.spawn)
	eq(StoryMap.lair_pos(g.world, &"lair:anvil"), anvil.lair, "the place Teague names is the second keeper's lair")
	eq(Guide.keeper_goal(g), "", "down, but nobody has named the next: no lead in words not yet said")
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
