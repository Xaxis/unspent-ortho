extends TestCase
## The journal (docs/STORY.md §13): what it shows of the story, what it keeps back,
## and that reading it is only reading.
##
## Every test here picks its arc, fragment and conversation out of the content
## rather than naming one, so a writer can rename every word of it and these
## still ask the same questions. Story is static state: each test forgets it
## first and last, so nothing leaks into the next file.

const Sx := preload("res://tests/save/save_fixture.gd")


func _ids(rows: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Dictionary in rows:
		if r.has("id"):
			out.append(r.id)
	return out


func _headers(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in rows:
		if r.has("header"):
			out.append(String(r.header))
	return out


func _row(rows: Array[Dictionary], id: StringName) -> Dictionary:
	for r: Dictionary in rows:
		if r.get("id", &"") == id:
			return r
	return {}


## An arc with more than one beat, so landing one of them leaves others unsaid.
func _arc_with_beats() -> StringName:
	for arc: StringName in StoryContent.arcs():
		if StoryContent.arc_beats(arc).size() > 1:
			return arc
	return &""


## A fragment whose words include a blank line, which is the hard case for
## giving it back exactly: a blank line is how a notice is laid out.
func _fragment_with_a_gap() -> StringName:
	for id: StringName in StoryFragments.all():
		if StoryFragments.lines(id).has(""):
			return id
	return StoryFragments.all()[0]


## Where a conversation first asks something, and the first answer it records.
func _first_answer() -> Dictionary:
	for talk: StringName in StoryContent.TALKS:
		var def: Dictionary = StoryContent.TALKS[talk]
		var node := StringName(str(def.get("start", &"")))
		for r: Dictionary in def.nodes.get(node, {}).get("replies", []):
			if StringName(str(r.get("pick", &""))) != &"":
				return {"talk": talk, "node": node, "pick": StringName(str(r.pick)),
					"text": String(r.text), "title": String(def.get("title", ""))}
	return {}


## Everything the story can hold, all at once: every fragment read, every beat
## landed, one answer at every node that records one.
func _everything() -> void:
	for id: StringName in StoryFragments.all():
		Story.read(id)
	for b: StringName in StoryContent.all_beats():
		Story.beat(b)
	for talk: StringName in StoryContent.TALKS:
		var nodes: Dictionary = StoryContent.TALKS[talk].nodes
		for node: StringName in nodes:
			for r: Dictionary in nodes[node].get("replies", []):
				if StringName(str(r.get("pick", &""))) != &"":
					Story.choose(StringName("%s.%s" % [talk, node]), StringName(str(r.pick)))
					break


## What the screen draws on its next frame, as text rects: `[{text, rect}]`.
func _drawn(s: UiScreen) -> Array[Dictionary]:
	UiDraw.tape.clear()
	UiDraw.taping = true
	s.queue_redraw()
	await tree.process_frame
	UiDraw.taping = false
	var out: Array[Dictionary] = []
	for d: Dictionary in UiDraw.tape:
		if d.kind == &"text" and d.ci == s:
			out.append({"text": String(d.text), "rect": Rect2i(d.rect)})
	UiDraw.tape.clear()
	return out


func _open() -> UiJournalScreen:
	var s := UiJournalScreen.new()
	tree.root.add_child(s)
	s.open()
	s.settle()
	return s


func test_a_new_game_has_nothing_written_and_says_so() -> void:
	Story.forget()
	var rows := UiJournalScreen.rows_now()
	eq(rows.size(), 1, "one row and nothing else: %s" % str(rows))
	eq(_headers(rows).size(), 0, "no arc, no read, no said")
	eq(rows[0].get("id"), &"nothing")
	check(bool(rows[0].get("dim", false)), "and it is drawn dim, as nothing to choose")
	check(String(rows[0].title) != "", "it says something")
	var s := _open()
	var said: Array[String] = []
	for d: Dictionary in await _drawn(s):
		said.append(String(d.text))
	check(said.has("JOURNAL"), "the page is the journal")
	check(said.has(String(rows[0].title)), "and its one row is on the glass: %s" % str(said))
	s.free()
	Story.forget()


func test_one_beat_shows_its_arc_and_nothing_of_what_is_still_to_come() -> void:
	Story.forget()
	var arc := _arc_with_beats()
	check(arc != &"", "the content has an arc with more than one beat")
	var beats: Array = StoryContent.arc_beats(arc)
	# Not the first beat: a page that listed the arc from its start would pass.
	var landed: StringName = beats[1]
	Story.beat(landed)
	var rows := UiJournalScreen.rows_now()
	eq(_headers(rows), [String(StoryContent.ARCS[arc].title)] as Array[String], "that arc's title and no other heading")
	eq(_ids(rows), [StringName("beat_%s" % landed)] as Array[StringName], "and that beat alone")
	for other: StringName in StoryContent.all_beats():
		if other == landed:
			continue
		for r: Dictionary in rows:
			check(r.get("beat", &"") != other, "%s has not landed and is not listed" % other)
			check(String(r.get("title", "")) != UiJournalScreen.short_of(other), "nor is it named")
	# No count of what is missing, anywhere on the page.
	var s := _open()
	s.select(StringName("beat_%s" % landed))
	for d: Dictionary in await _drawn(s):
		var t := String(d.text)
		check(not t.contains("%") and not t.contains(" of %d" % beats.size()), "no score on the page: %s" % t)
		check(not (t.contains("1") and t.contains(str(beats.size()))), "no tally of the arc: %s" % t)
	var said: Array[String] = []
	for d: Dictionary in await _drawn(s):
		said.append(String(d.text))
	var whole := " ".join(said)
	for word: String in StoryContent.beat_says(landed).split(" ", false):
		check(whole.contains(word), "the spare pane says the whole beat: %s" % word)
	s.free()
	Story.forget()


func test_a_thing_read_is_kept_with_its_words_exactly_as_written() -> void:
	Story.forget()
	var id := _fragment_with_a_gap()
	Story.read(id)
	var rows := UiJournalScreen.rows_now()
	check(_headers(rows).has("read"), "a read section: %s" % str(_headers(rows)))
	var row := _row(rows, StringName("read_%s" % id))
	check(not row.is_empty(), "with the thing in it")
	eq(String(row.get("title", "")), StoryFragments.title_of(id), "called what the player would call it")
	var lines := StoryFragments.lines(id)
	var shown := UiJournalScreen.page_lines(UiSlate.SPARE.size.x - UiSlate.MARGIN_L - UiSlate.MARGIN_R, lines)
	eq(shown.count(""), lines.count(""), "every blank line is still a blank line")
	var s := _open()
	s.select(StringName("read_%s" % id))
	eq(s.section(), &"read")
	# Everything below the pane's heading, in order, is the fragment's words.
	var body: Array[String] = []
	for d: Dictionary in await _drawn(s):
		var r: Rect2i = d.rect
		if UiSlate.SPARE.encloses(r) and r.position.y >= UiSlate.SPARE.position.y + UiJournalScreen.PANE_DOWN + UiJournalScreen.UNDER_HEADING:
			body.append(String(d.text))
	eq(" ".join(body).split(" ", false), " ".join(lines).split(" ", false), "the words, in the order they were written")
	s.free()
	Story.forget()


func test_an_answer_given_is_kept_with_the_words_that_were_said() -> void:
	Story.forget()
	var a := _first_answer()
	check(not a.is_empty(), "the content has a conversation that records an answer")
	var where := StringName("%s.%s" % [a.talk, a.node])
	Story.choose(where, a.pick)
	var rows := UiJournalScreen.rows_now()
	check(_headers(rows).has("said"), "a said section")
	var row := _row(rows, StringName("said_%s" % where))
	check(not row.is_empty(), "with the answer in it")
	eq(String(row.get("title", "")), String(a.title), "titled by who it was said to")
	eq(String(row.get("said", "")), String(a.text), "and the words themselves, not the pick's id")


func test_an_answer_the_words_have_gone_from_shows_its_id_plainly() -> void:
	Story.forget()
	var a := _first_answer()
	# A pick rewritten out of a talk that still exists, and a talk that does not.
	Story.choose(StringName("%s.%s" % [a.talk, a.node]), &"a_line_nobody_kept")
	Story.choose(&"a_talk_since_cut.somewhere", &"whatever_it_was")
	var rows := UiJournalScreen.rows_now()
	var kept := _row(rows, StringName("said_%s.%s" % [a.talk, a.node]))
	eq(String(kept.get("title", "")), String(a.title), "the talk still has its name")
	eq(String(kept.get("said", "")), "a_line_nobody_kept", "and the answer says its id")
	var cut := _row(rows, &"said_a_talk_since_cut.somewhere")
	eq(String(cut.get("title", "")), "a_talk_since_cut", "a cut talk is named by its id")
	eq(String(cut.get("said", "")), "whatever_it_was")
	# And drawing them does not fall over.
	var s := _open()
	s.select(&"said_a_talk_since_cut.somewhere")
	gt(float((await _drawn(s)).size()), 0.0, "the page still draws")
	s.free()
	Story.forget()


func test_reading_the_journal_changes_nothing_in_the_story() -> void:
	Story.forget()
	_everything()
	var before := JSON.stringify(Story.save_state())
	var s := _open()
	for i in s.menu.rows.size() + 2:
		@warning_ignore("return_value_discarded")
		s.handle(&"confirm")
		@warning_ignore("return_value_discarded")
		s.handle(&"left")
		@warning_ignore("return_value_discarded")
		s.handle(&"right")
		await _drawn(s)
		@warning_ignore("return_value_discarded")
		s.handle(&"down")
	s.close()
	eq(JSON.stringify(Story.save_state()), before, "every row confirmed and drawn, and the story is as it was")
	s.free()
	Story.forget()


func test_every_word_stays_on_its_own_pane() -> void:
	Story.forget()
	_everything()
	var s := _open()
	var seen := 0
	for row: Dictionary in s.menu.rows:
		if not row.has("id"):
			continue
		s.select(row.id)
		for d: Dictionary in await _drawn(s):
			var r: Rect2i = d.rect
			check(UiSlate.GLASS_RECT.encloses(r), "'%s' is on the glass" % d.text)
			if r.position.y < UiSlate.BODY.position.y or r.end.y > UiSlate.LIST.end.y:
				continue
			if r.position.x >= UiSlate.SPARE.position.x:
				check(r.end.x <= UiSlate.SPARE.end.x - UiSlate.MARGIN_R + 2 and r.end.y <= UiSlate.SPARE.end.y,
					"'%s' stays on the spare pane (%s)" % [d.text, row.id])
			else:
				check(r.end.x <= UiSlate.LIST.end.x, "'%s' stays in the list (%s)" % [d.text, row.id])
			seen += 1
	gt(float(seen), 20.0, "every row was drawn")
	s.free()
	# However long a line somebody writes, it is broken to the pane.
	var width := 200
	var long := PackedStringArray(["   " + "a clerk's column heading that goes on well past the glass ".repeat(4), "", "ONEWORDTHATCANNOTBEBROKENANYWHEREATALLONEWORDTHATCANNOTBEBROKEN"])
	for l: String in UiJournalScreen.page_lines(width, long):
		check(UiFont.width(l) <= width, "broken to %d px: %s" % [width, l])
	Story.forget()


## The journal's key is its own: nothing else in the map answers to it.
func test_the_journal_is_on_a_key_nothing_else_uses() -> void:
	check(InputMap.has_action(&"journal"), "the journal has a key")
	var code := PlayerSettings.key_of(&"journal")
	check(code != KEY_NONE, "and it is on one")
	for action: StringName in InputMap.get_actions():
		if action == &"journal" or String(action).begins_with("ui_"):
			continue
		for e: InputEvent in InputMap.action_get_events(action):
			var k := e as InputEventKey
			if k != null:
				check(k.physical_keycode != code and k.keycode != code, "%s is on the journal's key too" % action)
	var bindable := false
	for b: Dictionary in PlayerSettings.BINDABLE:
		bindable = bindable or b.action == &"journal"
	check(bindable, "and a player can move it")
	var home := UiPauseScreen.new()
	home.refresh()
	check(_ids(home.menu.rows).has(&"journal"), "home lists it too")
	home.free()


func test_the_journal_opens_on_its_key_keeps_up_with_the_story_and_closes() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128"])
	await frames(3)
	var ui := Sx.system(g, "90_ui")
	# Something read while the page is shut: the journal opens on it.
	var first := StoryFragments.all()[0]
	Story.read(first)
	Input.action_press(&"journal")
	await frames(4)
	Input.action_release(&"journal")
	await frames(4)
	var top: UiScreen = ui.call("top")
	check(top != null and top.screen_name == &"journal", "the key opens the journal")
	var page := top as UiJournalScreen
	if page != null:
		eq(page.menu.selected().get("id"), StringName("read_%s" % first), "open at what was found last")
		check(bool(Sx.system(g, "49_story").call("tour_seen", &"journal:read")), "and a tour can ask what it shows")
		# Something read while it is open is on it at once.
		var second := StoryFragments.all()[1]
		Story.read(second)
		check(_ids(page.menu.rows).has(StringName("read_%s" % second)), "the page keeps up")
	Input.action_press(&"journal")
	await frames(4)
	Input.action_release(&"journal")
	await frames(4)
	check(ui.call("top") == null, "and the key closes it again")
	# Never over a conversation: its keys are the conversation's.
	g.talking = true
	Input.action_press(&"journal")
	await frames(4)
	Input.action_release(&"journal")
	await frames(4)
	check(ui.call("top") == null, "the journal does not open over somebody talking")
	g.talking = false
	Sx.end(g)
	Story.forget()
