extends TestCase
## The story in a RUNNING GAME: what the `use` key does when more than one thing
## could answer it.
##
## `use` is one key and three things answer it — somebody in front of you, a
## thing with words on it, or the ground under your hands. 49_story is numbered
## before survival so that the most specific wins, and its reach is generous on
## purpose so a key pressed at a villager who has just taken a step still lands.
## What that cost: a notice several tiles away outranked the driftwood the player
## was standing on and facing, so the key that meant "pick this up" opened a page
## instead — and every press after it went to the page. `tours/core_loop.tour`
## died at its first `await took` because of it.


func _game(args: PackedStringArray) -> Game:
	var o := BootOptions.parse(args)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func _story(g: Game) -> Node:
	return g.get_node("49_story")


## A thing with words on it and a thing to pick up, both in front of the player,
## and the nearer one wins whichever it is.
func test_the_ground_under_your_hands_beats_a_notice_across_the_square() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var story := _story(g)
	var at := g.player.pos
	g.player.facing = 0.0
	g.player.hero.facing = 0.0
	# A readable thing two tiles ahead (inside StoryProps.REACH, which is 3), and
	# driftwood half a tile ahead, which is what the hands are actually on.
	var sign_prop := Survival.add_prop(g, PropKind.SIGN, at + Vector2(2.2, 0.0), 0.0, 0.3)
	check(sign_prop != null, "a notice stands two tiles ahead")
	var wood := Survival.add_prop(g, PropKind.DRIFTWOOD, at + Vector2(0.6, 0.0), 0.0, 0.2)
	await frames(2)
	check(Survival.use_target(g) != null, "the driftwood is what the hands are on")
	story._open_what_is_in_front()
	check(not story.view.showing(), "a page opened over the thing the player was picking up")
	eq(story.reading, &"", "and nothing was read")
	# Take the driftwood away and the same key reads the notice, because now the
	# notice IS the nearest thing the key could mean.
	g.world.depleted[wood.id] = INF
	await frames(2)
	story._open_what_is_in_front()
	check(story.view.showing(), "with nothing under the hands, the notice is what the key meant")
	g.queue_free()
	await frames(1)


## A THING WITH NOTHING LEFT FOR THE KEY DOES NOT KEEP IT. A bush picked over at
## his feet kept the press from the villager he faced (tours/holdfast.tour, line
## 444): the ground under the hands wins only when a press would take something.
func test_a_picked_over_thing_under_the_hands_leaves_the_key_to_the_words() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var story := _story(g)
	var at := g.player.pos
	g.player.facing = 0.0
	g.player.hero.facing = 0.0
	var sign_prop := Survival.add_prop(g, PropKind.SIGN, at + Vector2(2.2, 0.0), 0.0, 0.3)
	check(sign_prop != null, "a notice stands two tiles ahead")
	var bush := Survival.add_prop(g, PropKind.BUSH, at + Vector2(0.6, 0.0), 0.0, 0.3)
	await frames(2)
	check(WorldProp.same(Survival.use_target(g), bush), "the bush is what the hands are on")
	var state := SurvivalState.of(g)
	for j in Takes.options(PropKind.BUSH).size():
		state.spent[SurvivalState.key(bush.id, j)] = INF
	await frames(2)
	eq(Harvest.target(g).get("state"), Harvest.PICKED_OVER, "and it is picked over")
	story._open_what_is_in_front()
	check(story.view.showing(), "the press goes to the words in front, not the spent bush")
	g.queue_free()
	await frames(1)


## A RELAY HAS WORDS ON IT AND IS ALSO THE PLAN'S WORKS. The same prop answers
## both readers at exactly the same distance, so the read won every time and two
## of the six plan works could never be robbed for the rest of the game — and the
## wick that feeds the lamp comes off a relay (`Sources.said(&"wick")`).
## `tours/disposition.tour` could not file a theft at a survey post because of it.
func test_a_thing_that_is_both_words_and_works_is_read_once_then_robbed() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var story := _story(g)
	Story.forget()
	var at := g.player.pos
	g.player.facing = 0.0
	g.player.hero.facing = 0.0
	var relay := Survival.add_prop(g, PropKind.RELAY, at + Vector2(0.9, 0.0), 0.0, 1.0)
	await frames(2)
	check(Takes.is_plan_work(relay.kind), "a relay is one of the plan's works")
	check(WorldProp.same(Survival.use_target(g), relay), "and it is what the hands are on")
	# FIRST press: the words, because a thing is only read once.
	story._open_what_is_in_front()
	check(story.view.showing(), "the first press reads what is written on it")
	var was: StringName = story.reading
	check(was != &"", "and there were words")
	story._close()
	await frames(2)
	# EVERY press after: the parts. Story stands down and survival has the key.
	story._open_what_is_in_front()
	check(not story.view.showing(),
		"a relay already read still opened a page, so it can never be robbed")
	check(Story.knows(was), "and what was read is remembered")
	g.queue_free()
	await frames(1)


## THE PRESS THAT PUTS THE WORDS DOWN IS THE STORY'S. Survival is numbered after
## 49_story, so the press that closed a page or a conversation reached it too: by
## a fire or in a village, hungry, it ate the best food carried, and with
## something under the hands it gathered that. `tours/back-at-camp.tour` lost its
## stew leaving the warden's words at the Covenant (49_story `use_spent`).
func test_the_press_that_puts_the_words_down_eats_nothing() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var story := _story(g)
	Story.forget()
	var at := g.player.pos
	g.player.facing = 0.0
	g.player.hero.facing = 0.0
	check(Survival.add_prop(g, PropKind.SIGN, at + Vector2(2.2, 0.0), 0.0, 0.3) != null, "a notice stands ahead")
	check(Survival.add_prop(g, PropKind.FIRE, at + Vector2(-1.5, 0.0), 0.0, 0.3) != null, "and a fire behind")
	g.inventory.add(&"stew", 1)
	g.body.fed_until = g.clock.minutes - 120.0
	await frames(2)
	check(Survival.at_rest(g), "by the fire, where a press on nothing eats")
	eq(g.body.hunger_level(g.clock.minutes), 1, "and peckish, so it would")
	await _press_use()
	check(story.view.showing(), "the key reads the notice")
	await _press_use()
	check(not story.view.showing(), "and puts it down")
	eq(g.inventory.count(&"stew"), 1, "and the press that put it down ate nothing")
	g.queue_free()
	await frames(1)


## The real key, as a player presses it.
func _press_use() -> void:
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	await process_frames(3)
