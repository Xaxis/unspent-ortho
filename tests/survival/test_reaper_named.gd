extends TestCase
## THE TIDE REAPER, NAMED (ROADMAP slice 1 step 3; Guide.edge_line,
## Guide.keeper_name): before anyone has told him, the steel edge's goal is the
## plain line; once Hob has named the yard and its keeper (`reaper_named`) the
## same want is the short form of what Hob said, by the name Hob gave it; and
## Hob's talk reaches the naming on the obvious replies.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_steel_goal_is_hobs_once_he_has_named_it() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	# The knife has rung off the coast's keeper: the goal is the steel edge.
	SurvivalState.of(g).plates[&"steel"] = &"coast"
	var plain := Guide.edge_goal(g)
	eq(plain, "Iron rings off the reaper; steel bites. A kiln to temper the knife: eight stones.", "before anyone has named it, plain")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.NAMED_BEAT)
	var who := Guide.keeper_name(&"coast")
	eq(who, String(StoryContent.KEEPER_NAMED[&"coast"]), "the keeper by the name Hob gave it")
	eq(Guide.edge_goal(g), String(StoryContent.EDGE[&"kiln_stones"]).replace("{who}", who), "and the want in his words")
	check(Guide.edge_goal(g) != plain, "which are not the plain line")
	Sx.end(g)
	Story.forget()


func test_hobs_talk_names_it_on_the_obvious_replies() -> void:
	Story.forget()
	var talk := StoryTalk.start(&"hob")
	var reached := false
	for i in 12:
		if talk.over:
			break
		if talk.node == &"reaper" or Story.landed(Guide.NAMED_BEAT):
			reached = true
			break
		talk.pick(0)
	check(reached or Story.landed(Guide.NAMED_BEAT), "talking to Hob once, taking the first reply each time, names the yard and its keeper")
	Story.forget()
