extends TestCase
## The world writing him down (docs/STORY_SYSTEM.md §7): what he did that could be
## seen is noted, the people's record hears it late, the machines' files it at once,
## and every page fits the glass it is read on.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_before_he_does_anything_the_notebook_is_about_others() -> void:
	Story.forget()
	var said := StoryFragments.lines(&"hearsay")
	check(" ".join(said).contains("years apart"), "the notebook tells of others first")
	check(" ".join(StoryFragments.lines(&"error_log")).contains("NO ENTRIES"), "and the log has nothing")
	Story.forget()


func test_the_people_hear_late_and_the_machines_file_at_once() -> void:
	Story.forget()
	Story.note(&"works_dark", &"moss", 100.0)
	Story.now = 100.0 + 1.0
	check(not " ".join(StoryFragments.lines(&"hearsay")).contains("moss"), "an hour on, nobody has heard")
	check(" ".join(StoryFragments.lines(&"error_log")).contains("WORKS LOST (MOSS)"), "but the machines have it already")
	Story.now = 100.0 + StoryLedger.LAG + 1.0
	check(" ".join(StoryFragments.lines(&"hearsay")).contains("put a works yard dark, in the moss"), "half a day on, it is told")
	Story.forget()


func test_one_thing_seen_is_one_thing() -> void:
	Story.forget()
	Story.note(&"filed", &"coast", 10.0)
	Story.note(&"filed", &"coast", 30.0)
	eq(Story.ledger().size(), 1, "read twice by clerks inside the hour is one thing")
	Story.note(&"filed", &"coast", 200.0)
	eq(Story.ledger().size(), 2, "and a second reading later is another")
	Story.forget()


func test_every_page_fits_the_glass() -> void:
	# The longest name any landscape has, in every act, in both voices.
	var longest := &""
	for d: BiomeDef in BiomeRegistry.all():
		if d.display_name.length() > String(BiomeRegistry.get_def(longest).display_name if longest != &"" else "").length():
			longest = d.id
	var wide := UiTalkView.PANEL.size.x - UiTalkView.MARGIN * 2 - 8
	var pane := UiSlate.SPARE.size.x - UiSlate.MARGIN_L - UiSlate.MARGIN_R
	Story.forget()
	var t := 0.0
	for act: StringName in StoryLedger.ACTS:
		Story.note(act, longest, t)
		t += 100.0
	Story.now = t + StoryLedger.LAG
	for id: StringName in [&"hearsay", &"error_log"]:
		var lines := StoryFragments.lines(id)
		for l: String in lines:
			check(UiFont.width(l) <= mini(int(wide), int(pane)), "%s fits: %s" % [id, l])
		check(UiTalkView.panel_for(lines.size(), 0).size.y < UiTalkView.TALLEST, "%s is not cut off" % id)
	Story.forget()


func test_the_ledger_comes_back_through_a_save() -> void:
	Story.forget()
	Story.note(&"keeper_fell", &"burning", 500.0)
	var d := Story.save_state()
	Story.forget()
	eq(Story.ledger().size(), 0)
	Story.load_state(JSON.parse_string(JSON.stringify(d)))
	eq(Story.ledger().size(), 1, "what the world saw survives the save")
	eq(Story.ledger()[0].act, &"keeper_fell")
	eq(Story.ledger()[0].land, &"burning")
	Story.forget()


func test_what_he_does_in_play_is_noted() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	Events.works_broken.emit(0, &"moss")
	Events.sentinel_fell.emit(0, &"coast", &"force")
	var acts := {}
	for e: Dictionary in Story.ledger():
		acts[e.act] = e.land
	eq(acts.get(&"works_dark", &""), &"moss", "a works put dark is seen, where it was")
	eq(acts.get(&"keeper_fell", &""), &"coast", "and so is a keeper brought down")
	Sx.end(g)
	Story.forget()
