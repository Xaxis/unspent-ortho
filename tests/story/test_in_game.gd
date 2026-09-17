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
