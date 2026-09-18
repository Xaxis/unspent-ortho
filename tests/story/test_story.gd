extends TestCase

const Sx := preload("res://tests/save/save_fixture.gd")
## The story spine (docs/STORY.md): what is written, what a conversation does,
## what is remembered, and the rules the words themselves have to keep.


func test_every_arc_beat_and_fragment_agrees_with_the_tables() -> void:
	Story.forget()
	for arc: StringName in StoryContent.arcs():
		var beats: Array = StoryContent.arc_beats(arc)
		check(not beats.is_empty(), "%s has beats" % arc)
		for b: StringName in beats:
			check(StoryContent.BEATS.has(b), "%s is a beat that exists" % b)
			eq(StoryContent.beat_arc(b), arc, "%s belongs to the arc that lists it" % b)
			check(StoryContent.beat_says(b) != "", "%s says what the player now knows" % b)
	# Nothing may land a beat that is not declared, or the journal would hold a
	# line nobody wrote.
	for id: StringName in StoryFragments.all():
		for b: StringName in StoryContent.beats_from(id):
			check(StoryContent.BEATS.has(b), "%s lands %s, which is not a beat" % [id, b])


func test_every_fragment_is_a_readable_kind_with_words_on_it() -> void:
	for id: StringName in StoryFragments.all():
		var kind := StoryFragments.kind_of(id)
		check(StoryFragments.kinds().has(kind), "%s is one of the kinds a thing can be: %s" % [id, kind])
		check(StoryFragments.title_of(id) != "", "%s is called something" % id)
		var lines := StoryFragments.lines(id)
		check(lines.size() > 0, "%s has something written on it" % id)
		for l: String in lines:
			lt(float(l.length()), 72.0, "%s keeps its lines inside the glass: %s" % [id, l])


## The spine's own rule: the game never says the word in its own voice.
func test_the_game_never_says_the_word() -> void:
	for id: StringName in StoryFragments.all():
		for l: String in StoryFragments.lines(id):
			check(not l.to_lower().contains("simulation"),
				"%s says the quiet part: %s" % [id, l])
	for talk: StringName in StoryContent.TALKS:
		for node: StringName in StoryContent.TALKS[talk].nodes:
			for l: String in StoryContent.TALKS[talk].nodes[node].get("says", []):
				check(not l.to_lower().contains("simulation"), "%s.%s says it: %s" % [talk, node, l])


func test_which_thing_holds_which_words_never_changes_under_a_save() -> void:
	var a := StoryFragments.pick(StoryFragments.SIGN, &"coast", 7, 41)
	var b := StoryFragments.pick(StoryFragments.SIGN, &"coast", 7, 41)
	eq(a, b, "the same thing in the same world says the same thing")
	check(a != &"", "and the coast has signs with something on them")
	eq(StoryFragments.kind_of(a), StoryFragments.SIGN, "a sign holds a sign's words")
	# A kind nothing is written for yet comes back empty rather than wrong.
	eq(StoryFragments.pick(&"nonsense", &"coast", 7, 41), &"")


func test_reading_a_thing_is_knowing_it_and_only_once() -> void:
	Story.forget()
	var id := &"on_record"
	check(Story.read(id), "the first time is the first time")
	check(not Story.read(id), "and there is no second first time")
	check(Story.knows(id))
	eq(Story.found(), [id] as Array[StringName])
	# A clerk's screen with his own name on it: reading it IS the knowing.
	check(Story.landed(&"on_record_dead"), "and what it taught is known")
	gt(Story.at(&"who_he_was"), 0.0, "which moves the arc along")


func test_a_conversation_goes_where_the_replies_go() -> void:
	Story.forget()
	var t := StoryTalk.start(&"the_keeper")
	check(not t.over, "it started")
	check(t.says().size() > 0, "and it said something")
	var rs := t.replies()
	gt(float(rs.size()), 2.0, "with more than one thing to say back")
	# Saying nothing is always on the list (docs/STORY.md §13).
	var quiet := false
	for r: Dictionary in rs:
		if String(r.text).begins_with("["):
			quiet = true
	check(quiet, "and saying nothing is always one of them")
	check(t.pick(0), "the first reply goes somewhere")
	eq(Story.chose(&"the_keeper.open"), &"asked_where", "and what was said is remembered by where it was said")


func test_a_conversation_can_be_walked_to_its_end() -> void:
	# Every conversation, named people's too: always take the last reply, because
	# every node's last way out is a leaving one.
	for talk: StringName in StoryContent.TALKS:
		Story.forget()
		var t := StoryTalk.start(talk)
		var guard := 0
		while not t.over and guard < 40:
			guard += 1
			t.pick(t.replies().size() - 1)
		check(t.over, "%s: every node has a way out of the conversation" % talk)
		lt(float(guard), 40.0, "%s: and it is not a loop" % talk)
	Story.forget()


func test_a_reply_that_teaches_something_lands_its_beat() -> void:
	Story.forget()
	var t := StoryTalk.start(&"maren")
	# open -> who pulled you out -> hold out your hands: the body has no past.
	var to_pulled := -1
	var rs := t.replies()
	for i in rs.size():
		if String(rs[i].text).contains("pulled"):
			to_pulled = i
	gt(float(to_pulled), -1.0, "the keeper can be asked who pulled him out")
	t.pick(to_pulled)
	t.pick(0)
	check(Story.landed(&"body_new"), "being looked at is how he learns it")


func test_what_is_found_and_said_comes_back_through_a_save() -> void:
	Story.forget()
	Story.read(&"on_record")
	Story.choose(&"the_keeper.open", &"nothing")
	Story.beat(&"noticed")
	var d := Story.save_state()
	Story.forget()
	check(not Story.knows(&"on_record"), "forgotten is forgotten")
	Story.load_state(d)
	check(Story.knows(&"on_record"), "and a save brings it back")
	eq(Story.chose(&"the_keeper.open"), &"nothing")
	check(Story.landed(&"noticed"))
	check(Story.landed(&"on_record_dead"), "including what the reading itself taught")


## The seam with whoever places things: a placer asks for a kind and gets an id,
## and nothing about where it stands is the story's business.
func test_the_placer_seam_is_the_whole_of_what_a_placer_needs() -> void:
	for kind: StringName in StoryFragments.kinds():
		var id := StoryFragments.pick(kind, &"coast", 3, 9)
		if id == &"":
			continue
		eq(StoryFragments.kind_of(id), kind)
		check(StoryFragments.lines(id).size() > 0)
	# The props that can be read today are the machines' own notices and papers.
	check(StoryProps.readable(PropKind.SIGN))
	check(StoryProps.readable(PropKind.ARCHIVE))
	check(not StoryProps.readable(PropKind.PINE), "a tree says nothing")
	eq(StoryProps.kind_of(PropKind.SIGN), StoryFragments.SIGN)


func test_a_person_has_something_to_say_only_if_it_was_written_for_them() -> void:
	eq(StoryProps.talk_for({"trade": &"keeper"}, null), &"the_keeper")
	eq(StoryProps.talk_for({"character": &"maren", "trade": &"keeper"}, null), &"maren", "a named person says her own words, whatever her trade")
	eq(StoryProps.talk_for({}, null), &"", "somebody with no trade has nothing written")
	check(StoryProps.trades_with_talk().has(&"keeper"))


## A tour that waits on a beat or a fragment the words no longer declare waits
## for ever, and fails as a timeout that names nothing about why: slums_street
## waited on a beat of the previous story for a day after it was rewritten.
func test_every_tour_asks_after_words_that_exist() -> void:
	var dir := DirAccess.open("res://tours")
	check(dir != null, "the tours are there")
	if dir == null:
		return
	var rx := RegEx.create_from_string("(beat|knows):([a-z_0-9]+)")
	for f: String in dir.get_files():
		if not f.ends_with(".tour"):
			continue
		var text := FileAccess.get_file_as_string("res://tours/" + f)
		for m: RegExMatch in rx.search_all(text):
			var id := StringName(m.get_string(2))
			if m.get_string(1) == "beat":
				check(StoryContent.BEATS.has(id), "%s waits on beat %s, which the story does not declare" % [f, id])
			else:
				check(StoryContent.FRAGMENTS.has(id), "%s waits on reading %s, which is not written" % [f, id])


## The first thing the game says is the game's own voice (docs/STORY.md §12),
## said on the first morning and never again.
func test_the_first_morning_is_said_once() -> void:
	Sx.use_root("first-morning")
	Story.forget()
	var said := PackedStringArray()
	var hear := func(text: String) -> void: said.append(text)
	Events.message.connect(hear)
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=8"])
	# The first morning is said in a PROCESS frame, so ask for process frames.
	await process_frames(3)
	check(said.has("You come up out of the water."), "it says what happened to him: %s" % "\n".join(said))
	check(Story.began, "and remembers having said it")
	# A game carried on from a save is not told again: the story's own state is
	# applied before the first morning would be said (05_save starts before 49).
	var saver: Node = Sx.system(g, "05_save")
	eq(str(saver.call("save_to", 2)), "", "saved")
	Sx.end(g)
	said.clear()
	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "slot 2 boots")
	var g2 := Sx.game(tree, [], o)
	await process_frames(3)
	check(not said.has("You come up out of the water."), "a loaded game is not told again: %s" % "\n".join(said))
	Events.message.disconnect(hear)
	Sx.end(g2)
	Story.forget()
