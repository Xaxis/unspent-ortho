extends TestCase
## How it can end (StoryEnding, docs/STORY.md): the last choice at the
## channel, read against the version of the secret he holds, then everyone the
## story touched as he left them.


## All three back (the car first, as the home coast deals it: it commits nothing),
## held; the version is the reliving at the channel.
func _secret() -> void:
	for m: StringName in [&"mem_car", &"mem_kitchen", &"mem_hall"]:
		Story.beat(m, -INF)
	# In play 49_story lands this once all three are back.
	Story.beat(StorySecret.HELD, -INF)


func _walk(picks: Array) -> void:
	var t := StoryTalk.start(&"the_channel")
	for want: Variant in picks:
		var i := -1
		var rs := t.replies()
		for k in rs.size():
			if str(rs[k].text) == str(want):
				i = k
		check(i >= 0, "the channel offers \"%s\" at %s" % [want, t.node])
		if i < 0:
			return
		@warning_ignore("return_value_discarded")
		t.pick(i)


func _ending() -> String:
	return "\n".join(StoryEnding.lines())


func test_without_the_secret_he_can_only_give_it_up_or_keep_silent() -> void:
	Story.forget()
	var t := StoryTalk.start(&"the_channel")
	var said := PackedStringArray()
	for r: Dictionary in t.replies():
		said.append(str(r.text))
	check(not said.has("Break them."), "nothing to break them with")
	check(said.has("It's yours. Take it.") and said.has("[say nothing]"), "but he can give, or say nothing")
	Story.forget()


func test_the_same_choice_ends_differently_with_the_secret_whole_or_turned() -> void:
	Story.forget()
	_secret()
	_walk(["Break them.", "[the kitchen]", "[the car]"])
	eq(StoryEnding.choice(), &"broke")
	var whole := _ending()
	check(whole.contains("so does the thing at the other end"), "whole: both giants break:\n%s" % whole)
	Story.forget()
	_secret()
	_walk(["Break them.", "[the hall]", "[the kitchen]"])
	var turned := _ending()
	check(turned.contains("The thing at the other end does not"), "turned: only HALCYON breaks:\n%s" % turned)
	Story.forget()


func test_who_is_left_is_what_he_did() -> void:
	Story.forget()
	Story.beat(&"play_kept", -INF)
	Story.choose(&"vera.people", &"kept_quiet")
	Story.beat(&"rook_told", -INF)
	Story.beat(&"dace_left", -INF)
	Story.choose(&"lark.coffee", &"told_lark")
	_walk(["[say nothing]"])
	var e := _ending()
	for line: String in ["paper crown", "a war that is weather", "Rook shot Teague", "Dace is not there", "coffee"]:
		check(e.contains(line), "the ending remembers: %s\n%s" % [line, e])
	Story.forget()


func test_the_end_is_a_page_the_channel_closes_onto_and_nobody_else_says() -> void:
	eq(StringName(str(StoryContent.TALKS[&"the_channel"].get("after", &""))), &"the_end", "the channel closes onto the end")
	check(StoryFragments.placed(&"channel_console"), "the console stands only at the channel")
	check(not _dealt(&"the_end"), "and the end is never dealt to a notebook in the world")
	for trade: StringName in PersonLook.TRADES:
		check(StoryProps.talk_for({"trade": trade}, null) != &"the_channel", "no %s says the channel's words" % trade)


func _dealt(id: StringName) -> bool:
	for kind: StringName in StoryFragments.KINDS:
		for i in 300:
			if StoryFragments.pick(kind, &"coast", 1, i) == id:
				return true
	return false


func test_every_ending_fits_the_page() -> void:
	var wide := UiTalkView.PANEL.size.x - UiTalkView.MARGIN * 2 - 8
	for c: StringName in StoryEnding.CHOICES:
		for in_order: bool in [true, false]:
			Story.forget()
			_secret()
			Story.beat(&"secret_whole" if in_order else &"secret_misremembered", -INF)
			Story.choose(&"the_channel.open", c)
			var lines := StoryEnding.lines()
			for l: String in lines:
				check(UiFont.width(l) <= wide, "%s runs off the glass: %s" % [c, l])
			check(UiTalkView.panel_for(lines.size(), 0).size.y < UiTalkView.TALLEST, "%s fits" % c)
	Story.forget()
