extends TestCase
## THE TALK IS PACED BY THE PLAYER (owner, 2026-10-09; UiTalkView, 49_story).
## What is said types out a line at a time and never moves on by itself; a press
## while a line is typing finishes it, a press on a finished line goes on, and
## the replies come up only once the last line is out.


func _game() -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--talk=maren"])))
	return g


func _story(g: Game) -> Node:
	return g.get_node("49_story")


func test_a_line_types_out_and_waits_for_the_player() -> void:
	var g := _game()
	await frames(2)
	var story := _story(g)
	var view: UiTalkView = story.get("view")
	check(view.showing() and view.talk != null, "Maren is talking")
	var says := view.talk.says()
	gt(float(says.size()), 1.0, "she has more than one line to say")
	check(view.typed < says[0].length(), "the first line is still typing as it opens (%.1f of %d)" % [view.typed, says[0].length()])
	check(not view.lines_done(), "and the replies are not up")
	# Left alone a long while: the first line finishes and it WAITS.
	for i in 120:
		await frames(1)
	eq(view.line, 0, "it never moves on to the next line by itself")
	eq(int(view.typed), says[0].length(), "the first line is all out")
	check(not view.lines_done(), "still no replies")
	g.queue_free()
	await frames(1)


func test_a_press_finishes_a_line_then_goes_on_then_says_the_reply() -> void:
	var g := _game()
	await frames(2)
	var story := _story(g)
	var view: UiTalkView = story.get("view")
	var says := view.talk.says()
	var node := view.talk.node
	# Pressed while the first line types: it is finished at once, and that is all.
	story.call(&"_read_talk_keys", true)
	eq(view.line, 0, "a press while typing stays on the line")
	eq(int(view.typed), says[0].length(), "and finishes it")
	# Pressed again: on to the next line, typing from its start.
	story.call(&"_read_talk_keys", true)
	eq(view.line, 1, "a press on a finished line goes on")
	check(view.typed < 1.0, "and the next line starts typing")
	for i in says.size() - 1:
		story.call(&"_read_talk_keys", true)
		if view.lines_done():
			break
		story.call(&"_read_talk_keys", true)
	check(view.lines_done(), "every line is out, and the replies are up")
	eq(view.talk.node, node, "no reply was said while the lines went by")
	# Now the press says the lit reply, and the talk moves on.
	story.call(&"_read_talk_keys", true)
	check(view.talk == null or view.talk.node != node, "the press said the reply")
	g.queue_free()
	await frames(1)
