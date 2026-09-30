extends TestCase
## THE GOAL LINE IS HIS PURPOSE (Guide._goal_of): while a story lead is open the
## line is that lead's next step, never a rung of the recipe ladder, whatever the
## bag holds; after the reaper falls it says what he owes the crew, not "go mine";
## and with no lead left open it is empty, not the long game's next material.

const Sx := preload("res://tests/save/save_fixture.gd")

## The keys of the first hour's recipe steps and the long game's ladder: never
## the line once her errand is done.
const LADDER: Array[StringName] = [&"fire_gather", &"fire_lay", &"charcoal_gather", &"charcoal_set", &"haft", &"plate", &"pick"]


func _game() -> Game:
	Story.forget()
	return Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])


func test_an_upgraded_pick_keeps_the_story() -> void:
	var g := _game()
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick_spar", 1)
	var line := Guide.goal(g)
	check(not LADDER.has(Guide.last_goal_key), "the pick made into a better one, her errand is still done: [%s] %s" % [Guide.last_goal_key, line])
	eq(Guide.last_goal_key, &"ore", "the crew's iron is the want")
	Sx.end(g)
	Story.forget()


func test_hob_named_it_so_the_reaper_is_the_want() -> void:
	var g := _game()
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.NAMED_BEAT)
	eq(Guide.goal(g), String(StoryContent.LEAD[&"reaper"]), "named: end it")
	eq(Guide.last_goal_key, &"reaper", "keyed")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.REAPER_DOWN)
	eq(Guide.goal(g), String(StoryContent.LEAD[&"crew"]), "down: the crew, not the rock")
	eq(Guide.last_goal_key, &"crew", "keyed")
	g.inventory.add(&"iron_ore", 1)
	eq(Guide.last_goal_key if Guide.goal(g) != "" else &"", &"crew", "the iron in hand, the same errand")
	Sx.end(g)
	Story.forget()


func test_no_lead_open_no_line() -> void:
	var g := _game()
	await process_frames(2)
	eq(Guide.goal(g), "", "before her lead, nothing: no recipe out of nowhere")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"kit_plate", 1)
	g.inventory.add(&"cinder_glass", 1)
	Story.choose(Guide.CAMP_PAID, StringName(StoryContent.PAID[Guide.CAMP_PAID].pick))
	# The whole Holdfast leg behind him: the keeper named and down, every hop's
	# beat landed and the archive's man met.
	for b: StringName in [Guide.NAMED_BEAT, Guide.REAPER_DOWN, &"built_halcyon", &"holdfast_hope", &"war_archive"]:
		@warning_ignore("return_value_discarded")
		Story.beat(b, -INF)
	@warning_ignore("return_value_discarded")
	Story.meet(&"otto")
	var line := Guide.goal(g)
	eq(line, "", "paid and armoured with no hop open: the line is empty, not the ladder (%s)" % line)
	check(Guide.within_reach(g) != "", "and the long game's next want is on the making page: %s" % Guide.within_reach(g))
	Sx.end(g)
	Story.forget()


## Every recipe that consumes a pick makes one Guide.PICKS knows, so no upgrade,
## present or added later, can hide her errand as done.
func test_every_pick_made_from_a_pick_still_counts() -> void:
	for r: Dictionary in Recipes.LIST:
		var needs: Dictionary = r.get("needs", {})
		if not needs.keys().any(func(id: Variant) -> bool: return Guide.PICKS.has(StringName(id))):
			continue
		var makes: Dictionary = r.get("makes", {})
		for id: Variant in makes:
			check(Guide.PICKS.has(StringName(id)), "%s consumes a pick and makes %s, which Guide.PICKS must know" % [r.id, id])


## A goal that empties is not said: the bottom line keeps what was last heard
## rather than being blanked by a goal with nothing in it.
func test_an_emptied_goal_is_not_said() -> void:
	Story.forget()
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	var guide: Node = g.get_node("58_guide")
	var said: Array[String] = []
	var listen := func(t: String, _key: String) -> void: said.append(t)
	Events.hint.connect(listen)
	guide.call("_process", 2.0)
	check(said.size() == 1 and said[0] != "", "her errand's step is said: %s" % [said])
	Story.forget()
	for i in 8:
		guide.call("_process", 1.0)
	check(not said.has(""), "the goal emptied, nothing blank is said: %s" % [said])
	Events.hint.disconnect(listen)
	g.queue_free()
	await frames(1)
	Story.forget()


## PAID AND ARMOURED BEFORE ANYONE NAMED THE REAPER: the yard waits on its fall,
## so without a word from someone the line would be empty. Rook points him at the
## tide-pickers (his talk's `keeper` node, offered while the armour is carried and
## until reaper_named), and the goal is Hob's shore until Hob has named it.
func test_armoured_before_the_reaper_is_named_the_goal_is_the_tide_pickers() -> void:
	var g := _game()
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"kit_plate", 1)
	Story.choose(Guide.CAMP_PAID, StringName(StoryContent.PAID[Guide.CAMP_PAID].pick))
	var line := Guide.goal(g)
	check(line != "", "paid and armoured, nobody has named the Reaper: still a line")
	eq(Guide.last_goal_key, &"hob", "the tide-pickers: %s" % line)
	var talk := StoryTalk.start(&"rook")
	talk.holds = g.inventory.has
	check(talk.replies().any(func(r: Dictionary) -> bool: return r.get("to", &"") == &"keeper"), "and Rook has the word to give")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.NAMED_BEAT)
	eq(Guide.last_goal_key if Guide.goal(g) != "" else &"", &"reaper", "named: end it")
	talk = StoryTalk.start(&"rook")
	talk.holds = g.inventory.has
	check(not talk.replies().any(func(r: Dictionary) -> bool: return r.get("to", &"") == &"keeper"), "and Rook has nothing more to point at")
	Sx.end(g)
	Story.forget()
