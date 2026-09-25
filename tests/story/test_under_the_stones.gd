extends TestCase
## Under the stones (docs/story/UNDER_THE_STONES.md): Cairn sank the bunkers, one
## is his, the terminal in it wakes only for a man who knows his passwords still
## work, the files only once he knows whom he wrote to, and the drowned city's
## hulls say whose they were only to somebody who has heard the Echo.

const SIZE := 256


func _clean() -> void:
	Story.forget()
	Story.now = 0.0


func _page(id: StringName) -> String:
	return "\n".join(StoryFragments.lines(id))


func test_his_terminal_is_dark_until_the_oldest_machines_take_his_passwords() -> void:
	_clean()
	check(StoryFragments.locked(&"bunker_draft"), "shut before built_halcyon")
	check(not _page(&"bunker_draft").contains("WHITETHORN"), "and says nothing of whom he wrote to")
	Story.beat(&"built_halcyon", -INF)
	check(not StoryFragments.locked(&"bunker_draft"), "awake once it is felt")
	check(_page(&"bunker_draft").contains("WHITETHORN"), "and the draft is there")
	check(StoryContent.beats_from(&"bunker_draft").has(&"was_cia"), "reading it is knowing he had two employers")
	_clean()


func test_a_beat_only_just_landed_does_not_wake_it() -> void:
	_clean()
	Story.beat(&"built_halcyon")
	check(StoryFragments.locked(&"bunker_draft"), "a revelation still settling keeps it dark")
	_clean()


func test_the_files_open_only_after_he_knows() -> void:
	_clean()
	Story.beat(&"built_halcyon", -INF)
	check(StoryFragments.locked(&"bunker_files"), "shut before was_cia")
	Story.beat(&"was_cia", -INF)
	check(not StoryFragments.locked(&"bunker_files"), "open after")
	_clean()


func test_the_hulls_say_whose_they_were_only_after_the_echo_is_heard() -> void:
	_clean()
	for id: StringName in StoryContent.ROOMS[&"hulk_hold"][&"wall:builders_plate"]:
		check(StoryFragments.locked(id), "%s: colour before echo_voice" % id)
		check(not _page(id).contains("REASON"), "%s: no manifest yet" % id)
		check(StoryContent.beats_from(id).has(&"echo_hulls"), "%s lands the hulls" % id)
	Story.beat(&"echo_voice", -INF)
	for id: StringName in StoryContent.ROOMS[&"hulk_hold"][&"wall:builders_plate"]:
		check(_page(id).contains("REASON: don't."), "%s: the Echo's own word" % id)
	_clean()


func test_every_shut_page_fits_its_glass_shut_and_open() -> void:
	var wide := UiTalkView.PANEL.size.x - UiTalkView.MARGIN * 2 - 8
	var pane := UiSlate.SPARE.size.x - UiSlate.MARGIN_L - UiSlate.MARGIN_R
	var n := 0
	for id: StringName in StoryContent.FRAGMENTS:
		var f: Dictionary = StoryContent.FRAGMENTS[id]
		if not f.has("until"):
			continue
		n += 1
		var u := StringName(str(f.until))
		check(StoryContent.BEATS.has(u) or StoryContent.FRAGMENTS.has(u), "%s waits on %s, which is real" % [id, u])
		check(not (f.get("locked", []) as Array).is_empty(), "%s says something while shut" % id)
		for set: String in ["lines", "locked"]:
			var ls: Array = f.get(set, [])
			for l: String in ls:
				check(UiFont.width(l) <= wide and UiFont.width(l) <= pane, "%s %s runs off: %s" % [id, set, l])
			check(UiTalkView.panel_for(ls.size(), 0).size.y < UiTalkView.TALLEST, "%s %s fits" % [id, set])
	gt(float(n), 3.0, "the terminal, the files and the hulls' plates are shut")


func test_cairn_is_an_arc_and_the_cold_copy_is_found_on_the_ring() -> void:
	check(StoryContent.ARCS.has(&"cairn"), "Cairn is a thread")
	eq(StoryContent.arc_beats(&"cairn"), [&"cairn_stones", &"cairn_home", &"cairn_knew", &"cairn_cold"], "in order")
	check(bool(StoryContent.BEATS[&"cairn_cold"].get("reveal", false)), "the cold copy is a revelation")
	var at := ""
	for id: StringName in StoryContent.FRAGMENTS:
		if StoryContent.beats_from(id).has(&"cairn_cold"):
			at = String(id)
	check(at != "" and (StoryContent.PLACED[&"the_ring"] as Array).has(StringName(at)), "and it is read on the ring, leg 4, never dealt")
	check(_page(&"shuttle_manifest").contains("TAPE"), "the case went up on Priya's shuttle, a lead long before")


func test_every_tenant_writes_for_every_slot_a_bunker_opens() -> void:
	var keys := {}
	for n in 40:
		var l := Interiors.kind(&"bunker").recipe.call(&"lay", Rng.make(n, 0x51075)) as InteriorLayout
		for s: Dictionary in l.slots:
			keys[StoryRooms.key_of(l, s)] = true
	for tenant: StringName in StoryRooms.TENANTS:
		var row := StoryRooms.room_of(&"bunker", tenant)
		check(StoryContent.ROOMS.has(row), "%s is written" % row)
		for k: StringName in keys:
			check((StoryContent.ROOMS.get(row, {}) as Dictionary).has(k), "%s has words at %s" % [row, k])


## A full-sized world: at the plan tests' 256 tiles a coast holds one ring at
## most, and the deal is a count across all of them.
func test_one_bunker_is_his_and_one_kerr_s_and_the_rest_are_dealt() -> void:
	for s: int in [3]:
		StoryRooms.forget()
		var w := WorldGen.generate(s, Tuning.WORLD_SIZE)
		var dealt := StoryRooms.tenants(w)
		var count := {}
		for key: String in dealt:
			count[dealt[key]] = int(count.get(dealt[key], 0)) + 1
		var n := 0
		for t: Threshold in Interiors.thresholds(w):
			if t.kind == &"bunker":
				n += 1
				check(dealt.has(t.key), "seed %d: every bunker was sunk for somebody" % s)
		gt(float(n), 3.0, "seed %d: four rings or more on his coast" % s)
		eq(int(count.get(StoryRooms.HIS, 0)), 1, "seed %d: exactly one is his" % s)
		eq(int(count.get(StoryRooms.KERR, 0)), 1, "seed %d: and one Kerr's" % s)
		eq(int(count.get(StoryRooms.PRIYA, 0)), 1, "seed %d: and Priya's" % s)
		gt(float(count.get(StoryRooms.CAME, 0)), 0.0, "seed %d: and a household that lived out the war" % s)
		for once: StringName in [StoryRooms.KERR, StoryRooms.PRIYA, StoryRooms.HOLDFAST]:
			check(int(count.get(once, 0)) <= 1, "seed %d: one %s at most" % [s, once])
		eq(dealt, StoryRooms._deal(w), "seed %d: the same deal every time" % s)
	StoryRooms.forget()


func test_only_the_terminal_teaches_was_cia_in_his_bunker_and_his_alone() -> void:
	for tenant: StringName in StoryRooms.TENANTS:
		var row := StoryRooms.room_of(&"bunker", tenant)
		for key: StringName in StoryContent.ROOMS.get(row, {}):
			for id: StringName in StoryContent.ROOMS[row][key]:
				var b := StoryContent.beats_from(id)
				if tenant == StoryRooms.HIS:
					check(b.is_empty() or b == [&"was_cia"], "%s lands only was_cia" % id)
				elif tenant == StoryRooms.KERR:
					check(b.is_empty() or b == [&"cairn_knew"], "%s lands only cairn_knew" % id)
				else:
					eq(b, [], "%s is colour" % id)
