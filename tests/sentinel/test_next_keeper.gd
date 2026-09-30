extends TestCase
## THE SECOND KEEPER (ROADMAP slice 2, step 6; Sentinels.next_keeper): the
## nearest keeper of a design not yet taken. On seeds 1 and 7 that is the Tide
## Reaper first and the anvil once it is down (seed 7's second Tide Reaper, the
## nearer, is passed over). Once named by Nell it is the Candlestick; the survey
## marks its strike field and the lead says it, while it stands.

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


func test_once_the_reaper_is_down_the_survey_and_the_lead_point_at_the_strike_field() -> void:
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
	eq(Guide.keeper_goal(g), String(StoryContent.LEAD[&"strike_field"]), "the strike field's lead")
	var marks := UiMapScreen.told(g)
	var marked := false
	for m: Dictionary in marks:
		marked = marked or (m.word == "the strike field" and (m.at as Vector2).distance_to(anvil.lair) < 0.5)
	check(marked, "and the survey marks it at the anvil's lair (%s)" % [marks])
	anvil.fallen = true
	eq(Guide.keeper_goal(g), "", "until it falls")
	Sx.end(g)
	Story.forget()


func test_nell_names_it_the_candlestick() -> void:
	Story.forget()
	eq(Guide.keeper_name(&"glass_desert"), "the keeper", "before anyone has named it")
	@warning_ignore("return_value_discarded")
	Story.beat(&"reaper_down")
	var talk := StoryTalk.start(&"nell")
	var asked := false
	for r: Dictionary in talk.replies():
		asked = asked or r.get("to", &"") == &"candlestick"
	check(asked, "once the Reaper is down, Nell can be asked what keeps the strike field")
	var at := -1
	var i := 0
	for r: Dictionary in talk.replies():
		if r.get("to", &"") == &"candlestick":
			at = i
		i += 1
	talk.pick(at)
	check(Story.landed(&"anvil_named"), "and naming it lands anvil_named")
	eq(Guide.keeper_name(&"glass_desert"), "the Candlestick", "after which it is the Candlestick")
	eq(Guide.keeper_name(&"coast"), "the reaper", "and the coast's keeper keeps its own naming")
	Story.forget()
