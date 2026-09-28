extends TestCase
## MAREN'S LEAD (Guide._led, ROADMAP slice 1 step 2): before she has given it the
## first hour's goals are the plain recipe; once her lead has landed
## (`marens_lead`) the same moment is said in her words (StoryContent.LEAD), the
## fire's name filled in; and her talk reaches the lead on its obvious replies.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_goal_is_her_lead_once_she_has_given_it() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	# Charcoal in hand by the village fire: the want is the haft, a line her lead
	# words differently (her charcoal lines already said why, and are the same).
	g.inventory.add(&"charcoal", 2)
	eq(Guide.goal(g), "A haft, whittled from wood.", "before her lead, the plain want")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	eq(Guide.goal(g), String(StoryContent.LEAD[&"haft"]), "once she has given it, the same want in her words")
	Sx.end(g)
	Story.forget()


func test_her_talk_reaches_the_lead_on_the_obvious_replies() -> void:
	Story.forget()
	var talk := StoryTalk.start(&"maren")
	var reached := false
	# The first reply at every node: a player who just keeps talking.
	for i in 12:
		if talk.over:
			break
		if talk.node == &"lead" or Story.landed(Guide.LEAD_BEAT):
			reached = true
			break
		talk.pick(0)
	check(reached or Story.landed(Guide.LEAD_BEAT), "talking to her once, taking the first reply each time, gives his first lead")
	Story.forget()
