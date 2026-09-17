extends TestCase
## Every thread the story declares, held to the rules docs/STORY.md writes for it:
## every beat can actually land, every conversation goes somewhere and back, every
## word fits the glass it is shown on, and none of it says the quiet part.


## Every door a beat has, in one place: read off a thing, told in a conversation
## (a node reached or a reply given), read off a machine, or done to the player.
func _doors() -> Dictionary:
	var out := {}
	for id: StringName in StoryFragments.all():
		for b: StringName in StoryContent.beats_from(id):
			out[b] = "fragment %s" % id
	for talk: StringName in StoryContent.TALKS:
		var nodes: Dictionary = StoryContent.TALKS[talk].nodes
		for node: StringName in nodes:
			for b: StringName in nodes[node].get("beats", []):
				out[b] = "%s.%s" % [talk, node]
			for r: Dictionary in nodes[node].get("replies", []):
				for b: StringName in r.get("beats", []):
					out[b] = "%s.%s reply" % [talk, node]
	for role: StringName in StoryContent.TESTIMONY:
		for b: StringName in StoryContent.TESTIMONY[role].get("beats", []):
			out[b] = "testimony %s" % role
	for b: StringName in StoryContent.TESTIMONY_SENTINEL.get("beats", []):
		out[b] = "a keeper's testimony"
	for b: StringName in StoryContent.WITNESSED:
		out[b] = "witnessed"
	return out


func test_every_beat_has_a_door_the_player_can_find() -> void:
	var doors := _doors()
	for b: StringName in StoryContent.all_beats():
		check(doors.has(b), "%s can land somehow — nothing reads it, says it or does it" % b)
	for b: StringName in doors:
		check(StoryContent.BEATS.has(b), "%s (from %s) is declared" % [b, doors[b]])
	for b: StringName in StoryContent.BEATS:
		check(StoryContent.all_beats().has(b), "%s belongs to an arc that lists it" % b)


func test_the_arcs_story_md_promises_are_all_declared() -> void:
	for arc: StringName in [&"account", &"tide", &"quiet", &"key", &"clerk", &"went_in"]:
		check(StoryContent.ARCS.has(arc), "%s is declared" % arc)
		gt(float(StoryContent.arc_beats(arc).size()), 2.0, "%s is more than a line" % arc)


func test_every_conversation_goes_somewhere_and_can_be_left() -> void:
	for talk: StringName in StoryContent.TALKS:
		var def: Dictionary = StoryContent.TALKS[talk]
		var nodes: Dictionary = def.nodes
		var start := StringName(str(def.get("start", &"")))
		check(nodes.has(start), "%s starts somewhere that exists" % talk)
		check(PersonLook.TRADES.has(StringName(str(def.get("who", &"")))),
			"%s is for a trade people actually have: %s" % [talk, def.get("who", &"")])
		# Every node reachable from the start, every reply going to a node or out.
		var seen := {start: true}
		var queue: Array[StringName] = [start]
		while not queue.is_empty():
			var n: StringName = queue.pop_back()
			var replies: Array = nodes[n].get("replies", [])
			check(not replies.is_empty(), "%s.%s gives the player something to say" % [talk, n])
			for r: Dictionary in replies:
				var to := StringName(str(r.get("to", &"")))
				if to == &"":
					continue
				check(nodes.has(to), "%s.%s goes to %s, which exists" % [talk, n, to])
				if nodes.has(to) and not seen.has(to):
					seen[to] = true
					queue.append(to)
				var when := StringName(str(r.get("when", &"")))
				if when != &"":
					check(StoryContent.BEATS.has(when) or StoryContent.FRAGMENTS.has(when),
						"%s.%s asks for %s, which is a beat or a thing to read" % [talk, n, when])
		for n: StringName in nodes:
			check(seen.has(n), "%s.%s can be reached" % [talk, n])


func test_one_conversation_per_trade_so_nobody_is_silently_unreachable() -> void:
	var by: Dictionary = {}
	for talk: StringName in StoryContent.TALKS:
		var who := StringName(str(StoryContent.TALKS[talk].get("who", &"")))
		check(not by.has(who), "%s and %s are both for a %s, and only the first would ever be said" % [by.get(who, ""), talk, who])
		by[who] = talk


func test_every_word_fits_the_glass_it_is_shown_on() -> void:
	var wide := UiTalkView.PANEL.size.x - UiTalkView.MARGIN * 2 - 8
	for id: StringName in StoryFragments.all():
		var lines := StoryFragments.lines(id)
		for l: String in lines:
			check(UiFont.width(l) <= wide, "%s runs off the glass: %s" % [id, l])
		var r := UiTalkView.panel_for(lines.size(), 0)
		check(r.size.y < UiTalkView.TALLEST, "%s is not so long the page is cut off" % id)
	for talk: StringName in StoryContent.TALKS:
		var nodes: Dictionary = StoryContent.TALKS[talk].nodes
		for n: StringName in nodes:
			var says: Array = nodes[n].get("says", [])
			for l: String in says:
				check(UiFont.width(l) <= wide, "%s.%s runs off the glass: %s" % [talk, n, l])
			var replies: Array = nodes[n].get("replies", [])
			for r: Dictionary in replies:
				check(UiFont.width(str(r.text)) <= wide, "%s.%s reply runs off: %s" % [talk, n, r.text])
			check(UiTalkView.panel_for(says.size(), replies.size()).size.y < UiTalkView.TALLEST,
				"%s.%s fits without being cut" % [talk, n])
	# The journal keeps every page, in a pane narrower than the words panel: a line
	# written to fit the one and not the other leaves a word alone on a line of its own.
	var pane := UiSlate.SPARE.size.x - UiSlate.MARGIN_L - UiSlate.MARGIN_R
	for id: StringName in StoryFragments.all():
		for l: String in StoryFragments.lines(id):
			check(UiFont.width(l) <= pane, "%s wraps badly in the journal: %s" % [id, l])
	for b: StringName in StoryContent.BEATS:
		check(str(StoryContent.BEATS[b].get("short", "")) != "", "%s has a short name for the journal's list" % b)
	# The read panel is narrow glass: a machine's testimony must say it in its width.
	var read_wide := UiTargetView.PANEL.size.x - 10
	for role: StringName in StoryContent.TESTIMONY:
		var said := str(StoryContent.TESTIMONY[role].says)
		check(UiFont.width(said) <= read_wide, "what a %s is for fits the read: %s" % [role, said])
	check(UiFont.width(str(StoryContent.TESTIMONY_SENTINEL.says)) <= read_wide, "and a keeper's")


func test_the_new_words_never_say_it_either() -> void:
	var all: PackedStringArray = []
	for b: StringName in StoryContent.BEATS:
		all.append(StoryContent.beat_says(b))
	for arc: StringName in StoryContent.ARCS:
		all.append(str(StoryContent.ARCS[arc].title))
		all.append(str(StoryContent.ARCS[arc].note))
	for role: StringName in StoryContent.TESTIMONY:
		all.append(str(StoryContent.TESTIMONY[role].says))
	for talk: StringName in StoryContent.TALKS:
		for n: StringName in StoryContent.TALKS[talk].nodes:
			for r: Dictionary in StoryContent.TALKS[talk].nodes[n].get("replies", []):
				all.append(str(r.text))
	for l: String in all:
		check(not l.to_lower().contains("simulation"), "said the quiet part: %s" % l)


func test_every_role_of_the_plan_has_something_it_is_for() -> void:
	for role: StringName in Roles.ALL:
		check(StoryContent.TESTIMONY.has(role), "a %s is read as something" % role)
	eq(StoryContent.testimony(&"worker", {"machine": false}).size(), 0, "a creature is nothing of the plan's")
	check(not StoryContent.testimony(&"keeper", {"machine": true, "sentinel": &"pan_rake"}).is_empty(),
		"a landscape's keeper is read as what the rest answer to")


# --- the threads, walked -------------------------------------------------------

func _walk(talk: StringName, picks: Array[String]) -> StoryTalk:
	var t := StoryTalk.start(talk)
	for want: String in picks:
		var rs := t.replies()
		var i := -1
		for k in rs.size():
			if str(rs[k].text) == want:
				i = k
		check(i >= 0, "%s offers \"%s\" at %s" % [talk, want, t.node])
		if i < 0:
			return t
		@warning_ignore("return_value_discarded")
		t.pick(i)
	return t


func test_there_is_no_outside_only_once_there_is_more_than_one_of_here() -> void:
	Story.forget()
	var t := _walk(&"the_scavenger", ["With who?", "Why did they go?", "Did anybody come out?"])
	check(Story.landed(&"went_in_out"), "one came out")
	for r: Dictionary in t.replies():
		check(str(r.text) != "What does that mean?", "a question nobody has a reason to ask is not offered yet")
	Story.forget()
	Story.beat(&"branches")
	@warning_ignore("return_value_discarded")
	_walk(&"the_scavenger", ["With who?", "Why did they go?", "Did anybody come out?", "What does that mean?"])
	check(Story.landed(&"no_outside"), "knowing there is more than one of this place, the answer lands")
	Story.forget()


func test_the_quiet_region_costs_what_it_rests() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"the_glad", ["Is it?", "Agree on what?", "And if somebody does not agree?", "Is she?"])
	for b: StringName in [&"quiet_calm", &"quiet_glad", &"quiet_cost"]:
		check(Story.landed(b), "%s lands along the way" % b)
	eq(Story.chose(&"the_glad.agree"), &"asked_disagree", "and what the player asked is theirs")
	Story.forget()


func test_the_filed_asked() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"the_cutter", ["The works say?", "Easier than what?", "And it did."])
	check(Story.landed(&"clerk_asked"), "somebody asked to be written down")
	check(Story.landed(&"the_filed"), "and came back agreeing")
	Story.forget()
