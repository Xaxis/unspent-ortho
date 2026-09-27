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
	# A keeper taken gives back the memory it was holding (49_story, sentinel_fell).
	for keeper: StringName in StoryContent.KEEPER_MEMORY:
		out[StoryContent.KEEPER_MEMORY[keeper].memory] = "the keeper %s taken" % keeper
	# The three memories back, in whatever order: the version he holds (StorySecret).
	for b: StringName in [&"secret_whole", &"secret_misremembered"]:
		out[b] = "StorySecret"
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
	for arc: StringName in [&"who_he_was", &"the_war", &"the_machines", &"the_holdfast", &"the_covenant", &"the_crew", &"june", &"the_colonies", &"priya", &"the_echo", &"the_secret"]:
		check(StoryContent.ARCS.has(arc), "%s is declared" % arc)
		gt(float(StoryContent.arc_beats(arc).size()), 2.0, "%s is more than a line" % arc)


func test_every_conversation_goes_somewhere_and_can_be_left() -> void:
	for talk: StringName in StoryContent.TALKS:
		var def: Dictionary = StoryContent.TALKS[talk]
		var nodes: Dictionary = def.nodes
		var start := StringName(str(def.get("start", &"")))
		check(nodes.has(start), "%s starts somewhere that exists" % talk)
		if def.has("cast"):
			check(StoryCast.get_def(StringName(str(def.cast))) != null, "%s belongs to %s, who is in the cast" % [talk, def.cast])
		elif bool(def.get("machine", false)):
			var opened := false
			for f: StringName in StoryContent.FRAGMENTS:
				opened = opened or StringName(str(StoryContent.FRAGMENTS[f].get("talk", &""))) == talk
			check(opened, "%s is a machine's, and some thing that answers opens it" % talk)
		else:
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
		if StoryContent.TALKS[talk].has("cast") or bool(StoryContent.TALKS[talk].get("machine", false)):
			continue
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
	for said: String in StoryContent.TESTIMONY_HOLDING.says:
		check(UiFont.width(said) <= read_wide, "a machine held at a ring's read fits: %s" % said)


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


func test_a_question_nobody_has_a_reason_to_ask_is_not_offered_yet() -> void:
	Story.forget()
	var t := _walk(&"the_digger", ["What was the building?"])
	for r: Dictionary in t.replies():
		check(str(r.text) != "Who wrote the orders that started the war?", "he asks who wrote the orders only once he knows he wrote orders of his own")
		check(str(r.text) != "It woke up with somebody in it.", "and says what woke up only once he knows")
	Story.forget()
	Story.beat(&"was_cia", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"the_digger", ["What was the building?", "Who wrote the orders that started the war?"])
	check(Story.landed(&"tradecraft"), "knowing what he was, the answer lands on him")
	Story.forget()


func test_the_war_is_told_by_those_who_lived_off_it() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"the_scavenger", ["What war?", "And the stations up there?"])
	check(Story.landed(&"forged_order"), "every order checked out")
	check(Story.landed(&"colonies"), "and the stations were lied to as well")
	Story.forget()


func test_the_covenant_costs_what_it_feeds() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"the_fed", ["What is the Covenant?", "And what does it cost?"])
	for b: StringName in [&"covenant_fed", &"covenant_price"]:
		check(Story.landed(b), "%s lands along the way" % b)
	eq(Story.chose(&"the_fed.covenant"), &"asked_cost", "and what the player asked is theirs")
	Story.forget()


func test_the_fire_keeper_sees_what_he_is_before_he_does() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"maren", ["Who pulled me out?", "[hold them out]"])
	check(Story.landed(&"body_new"), "his hands say it before he can")
	Story.forget()
	var t := _walk(&"rook", ["What do you want?"])
	for r: Dictionary in t.replies():
		check(str(r.text) != "I know the old machines.", "he cannot offer what he does not know he knows")
	Story.forget()
	Story.beat(&"built_halcyon", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"rook", ["What do you want?", "I know the old machines."])
	check(Story.landed(&"holdfast_hope"), "and once he does, he is a weapon to them")
	Story.forget()


func test_june_is_named_before_she_is_met() -> void:
	Story.forget()
	var t := _walk(&"imre", ["Why did you leave?"])
	for r: Dictionary in t.replies():
		check(str(r.text) != "Who is the Speaker?", "nobody asks after a Speaker they have not heard of")
	check(not StoryCast.get_def(&"june").present(), "and she is not there to be met")
	Story.forget()
	Story.beat(&"covenant_speaker", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"imre", ["Why did you leave?", "Who is the Speaker?"])
	check(Story.landed(&"june_named"), "Imre says her name")
	check(not StoryCast.get_def(&"june").present(), "and she sends for him once it has settled, not before")
	Story.now += StoryPacing.SETTLE
	check(StoryCast.get_def(&"june").present(), "and now she can be found")
	@warning_ignore("return_value_discarded")
	_walk(&"june", ["Do you know who I am?"])
	for b: StringName in [&"june_met", &"june_knew"]:
		check(Story.landed(b), "%s lands at her table" % b)
	Story.forget()


func test_dace_leaves_when_he_learns_whose_order_it_was() -> void:
	Story.forget()
	check(StoryCast.get_def(&"dace").present(), "he is with the crew")
	var t := _walk(&"dace", ["What happened?"])
	check(Story.landed(&"crew_war"), "he turned the key")
	for r: Dictionary in t.replies():
		check(str(r.text) != "The order was mine.", "a confession needs knowing what there is to confess")
	Story.forget()
	Story.beat(&"tradecraft", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"dace", ["What happened?", "The order was mine."])
	check(Story.landed(&"dace_left"), "told, he goes")
	check(not StoryCast.get_def(&"dace").present(), "and he is not at the camp any more")
	Story.forget()


## 49_story names no beat of its own: every event it watches lands a beat the
## content declares, and every witnessed beat has an event that lands it.
func test_every_witnessed_beat_has_an_event_and_every_event_a_beat() -> void:
	var landed_by := {}
	for event: StringName in StoryContent.WITNESS_ON:
		var b: StringName = StoryContent.WITNESS_ON[event]
		check(StoryContent.BEATS.has(b), "%s lands %s, which is declared" % [event, b])
		landed_by[b] = true
	for b: StringName in StoryContent.WITNESSED:
		check(landed_by.has(b), "%s is said to be witnessed, and some event lands it" % b)
	check(StoryContent.BEATS.has(StoryContent.SIGNET_AFTER), "the signet waits on a beat that exists")


func test_vera_comes_for_the_weapon_and_keeps_what_she_read() -> void:
	Story.forget()
	check(not StoryCast.get_def(&"vera").present(), "she is not at the camp until Rook has something to show her")
	Story.beat(&"holdfast_hope", -INF)
	check(StoryCast.get_def(&"vera").present(), "and then she is")
	var t := _walk(&"vera", [])
	for r: Dictionary in t.replies():
		check(str(r.text) != "They don't even see you, do they?", "nobody asks that who has not read a treaty")
	@warning_ignore("return_value_discarded")
	_walk(&"vera", ["What do you want from me?", "Where would I start?"])
	check(Story.landed(&"war_archive"), "she says where the war was written down: the lead across the water")
	Story.forget()
	Story.beat(&"ants", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"vera", ["They don't even see you, do they?", "Do your people know?", "I won't tell them."])
	check(Story.landed(&"vera_knew"), "she has read the machines' record of her war")
	eq(Story.chose(&"vera.people"), &"kept_quiet", "and what he promised her is his")
	Story.forget()


func test_teague_is_found_out_by_someone_else_first() -> void:
	Story.forget()
	var t := _walk(&"teague", ["Why do you fight?", "Who broke it?"])
	check(Story.landed(&"holdfast_price"), "his children are what the Holdfast costs")
	t = _walk(&"teague", [])
	for r: Dictionary in t.replies():
		check(str(r.text) != "The Covenant knows our roads.", "he cannot be faced with what nobody has told")
	@warning_ignore("return_value_discarded")
	_walk(&"solis", ["How do you know where I came from?"])
	check(Story.landed(&"teague_sold"), "Solis says it: somebody else's face carries it")
	Story.now += StoryPacing.SETTLE
	@warning_ignore("return_value_discarded")
	_walk(&"teague", ["The Covenant knows our roads.", "I won't say anything."])
	check(Story.landed(&"teague_clears"), "and Teague says why: nobody burns")
	Story.forget()


func test_solis_is_what_the_machines_made_of_a_man() -> void:
	Story.forget()
	var t := _walk(&"solis", [])
	for r: Dictionary in t.replies():
		check(str(r.text) != "You've no scars either.", "he sees it only once he knows it of himself")
	Story.beat(&"body_new", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"solis", ["You've no scars either."])
	check(Story.landed(&"solis_made"), "the war left half of him")
	Story.forget()


func test_lark_is_who_he_tells() -> void:
	Story.forget()
	var t := _walk(&"lark", ["I think so.", "Bitter. You drank it anyway."])
	for r: Dictionary in t.replies():
		check(str(r.text) != "I did this. The quiet. All of it.", "there is nothing to confess yet")
	Story.forget()
	Story.beat(&"singularity", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"lark", ["I think so.", "Like being awake.", "I did this. The quiet. All of it."])
	eq(Story.chose(&"lark.coffee"), &"told_lark", "and what he told her is remembered")
	Story.forget()


func test_the_ring_is_heard_long_before_it_is_reached() -> void:
	Story.forget()
	check(Story.read(&"ring_calling"), "a radio on a dead band")
	check(Story.landed(&"ring_voice"), "somebody up there is still calling")
	@warning_ignore("return_value_discarded")
	_walk(&"oksana", ["I heard you, on the ground."])
	eq(Story.chose(&"oksana.open"), &"told_heard", "and she is told so, when he gets there")
	@warning_ignore("return_value_discarded")
	_walk(&"oksana", ["What happened up here?"])
	check(Story.landed(&"ring_turned"), "the rings opened each other's locks")
	Story.now += StoryPacing.SETTLE
	@warning_ignore("return_value_discarded")
	_walk(&"oksana", ["What are you listening to?", "Whose notebook?"])
	check(Story.landed(&"ring_kept"), "and she kept what Priya brought up")
	Story.forget()


func test_priya_is_found_a_page_at_a_time_and_ends_on_the_ring() -> void:
	Story.forget()
	check(Story.read(&"commits"), "the lab's last changes")
	check(Story.landed(&"priya_warned"), "her name is on the change he merged over her")
	for page: StringName in [&"priya_suspicion", &"priya_liaison", &"priya_cadence", &"shuttle_manifest"]:
		check(Story.read(page), "%s can be read" % page)
	for b: StringName in [&"priya_suspected", &"priya_reported", &"priya_knew", &"priya_up"]:
		check(Story.landed(b), "%s lands from her pages" % b)
	check(not Story.landed(&"priya_last"), "what she left him is not on any page on the ground")
	Story.now += StoryPacing.SETTLE
	@warning_ignore("return_value_discarded")
	_walk(&"oksana", ["What are you listening to?"])
	Story.now += StoryPacing.SETTLE
	@warning_ignore("return_value_discarded")
	_walk(&"oksana", ["What are you listening to?", "Whose notebook?", "Yes.", "[take it]"])
	check(Story.landed(&"priya_last"), "it is handed to him on the ring")
	eq(Story.at(&"priya"), 1.0, "and the whole of her is known")
	Story.forget()


func test_the_echo_is_found_in_his_own_hand_and_his_daughter_s_luck() -> void:
	Story.forget()
	check(Story.read(&"note_to_self"), "a works log with one line out of place")
	check(Story.landed(&"echo_voice"), "something still writes notes to itself in his voice")
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"rook", ["Who paid you?", "Have you still got the note?", "That's my handwriting."])
	check(Story.landed(&"echo_hand"), "the note that paid Rook is his own")
	eq(Story.chose(&"rook.note"), &"told_rook_hand", "and he said so")
	Story.forget()
	Story.beat(&"june_named", -INF)
	Story.now = 5000.0
	var t := _walk(&"june", ["Do you know who I am?"])
	for r: Dictionary in t.replies():
		check(str(r.text) != "What does the voice say?", "she has just told him the voice is his: the next thing waits")
	Story.now += StoryPacing.SETTLE
	@warning_ignore("return_value_discarded")
	_walk(&"june", ["Do you know who I am?", "What does the voice say?"])
	check(Story.landed(&"echo_kept"), "and when it has settled, what the voice has done for her")
	Story.forget()


## The chain of leads (docs/DESIGN.md): every stop of the journey has
## somebody who says, in their own words, where the next one is.
func test_every_stop_of_the_journey_says_where_the_next_one_is() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"maren", ["Who pulled me out?", "[hold them out]", "I don't know."])
	check(Story.landed(&"holdfast_fight"), "home: Maren sends him to the crew's camp")
	Story.forget()
	Story.beat(&"holdfast_hope", -INF)
	@warning_ignore("return_value_discarded")
	_walk(&"vera", ["What do you want from me?", "Where would I start?"])
	check(Story.landed(&"war_archive"), "the camp: Vera sends him across the water to the archive")
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"otto", ["How the war started.", "Where is it?"])
	check(Story.landed(&"war_relay"), "the archive: Otto sends him down the shaft")
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"wren", ["Listen to what?", "What's down there?"])
	check(Story.landed(&"plant_below"), "below: Wren hears what the relay is part of")
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"sefa", ["Can it be climbed?", "I'm asking."])
	check(Story.landed(&"the_climb"), "the far shore: Sefa says how to go up")
	eq(Story.chose(&"sefa.climb"), &"asked_to_ride", "and he asked")
	Story.forget()


func test_telling_rook_about_teague_is_the_end_of_teague() -> void:
	Story.forget()
	Story.beat(&"teague_sold", -INF)
	check(StoryCast.get_def(&"teague").present(), "Teague is at the camp")
	@warning_ignore("return_value_discarded")
	_walk(&"rook", ["Teague sells our roads to the Covenant."])
	check(Story.landed(&"rook_told"), "Rook will see to it")
	check(not StoryCast.get_def(&"teague").present(), "and Teague is not at the camp after")
	check("\n".join(StoryEnding.lines()).contains("Rook shot Teague"), "and the ending remembers it")
	Story.forget()


## A revelation a page may deal anywhere also has somebody who says it, so the
## path does not hang on which sign a world happened to deal (docs/STORY.md).
func test_the_war_s_phrasing_and_the_forecast_each_have_a_person() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"otto", ["How the war started.", "Show me one."])
	check(Story.landed(&"tradecraft"), "Otto shows him an order in his own rhythm")
	Story.forget()
	@warning_ignore("return_value_discarded")
	_walk(&"sefa", ["Is anything written at the foot?"])
	check(Story.landed(&"ants"), "Sefa has read the forecast: next to people, a dash")
	Story.forget()
