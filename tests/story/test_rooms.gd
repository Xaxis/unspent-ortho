extends TestCase
## What a room's story slots hold (StoryRooms, StoryContent.ROOMS): every slot a
## room's recipe opens is written for, every row the story writes is one a room
## can reach, a door deals its own, and the bunker says no more than the home
## coast's leg of the spine allows (docs/STORY.md).

## How many doors' worth of each kind to grow: enough that every deal a recipe
## makes (which bay holds the loom, which side the work room is on) comes up.
const DOORS := 60


func _grow(kind: StringName, n: int) -> InteriorLayout:
	return Interiors.kind(kind).recipe.call(&"lay", Rng.make(n, 0x51075)) as InteriorLayout


func test_every_room_the_story_writes_for_is_a_room() -> void:
	for room: StringName in StoryContent.ROOMS:
		# `kind:TENANT` is one household's room of that kind (StoryRooms.room_of).
		var kind := StringName(String(room).get_slice(":", 0))
		check(Interiors.kind(kind) != null, "%s is a kind of room (Interiors.RECIPES)" % room)


func test_every_slot_a_room_opens_holds_words() -> void:
	for kind: StringName in Interiors.RECIPES:
		var seen := {}
		for n in DOORS:
			var l := _grow(kind, n)
			for i in l.slots.size():
				var key := StoryRooms.key_of(l, l.slots[i])
				seen[key] = true
				var id := StoryRooms.held(kind, "door-%d" % n, l, i)
				check(id != &"", "%s: a slot at %s holds nothing" % [kind, key])
				check(StoryContent.FRAGMENTS.has(id), "%s: %s is written" % [kind, id])
		# And every row written for this room is one a slot can stand at.
		for key: StringName in StoryContent.ROOMS.get(kind, {}):
			check(seen.has(key), "%s: nothing in %d rooms is at %s, so nobody reads it" % [kind, DOORS, key])


func test_the_bunker_has_a_terminal_a_whiteboard_and_what_was_pinned() -> void:
	var l := _grow(&"bunker", 1)
	var got: Array[StringName] = []
	for i in l.slots.size():
		got.append(StoryRooms.held(&"bunker", "door", l, i))
	for id: StringName in [&"bunker_draft", &"bunker_board", &"bunker_drawing", &"bunker_phones", &"bunker_files"]:
		check(got.has(id), "the bunker holds %s" % id)


func test_a_door_deals_its_own_and_one_house_never_says_a_thing_twice() -> void:
	var dealt := {}
	for n in DOORS:
		var l := _grow(&"stilt_room", n)
		for i in l.slots.size():
			dealt[StoryRooms.held(&"stilt_room", "door-%d" % n, l, i)] = true
		# Two kists in one roundhouse hold two different things.
		var r := _grow(&"roundhouse", n)
		var in_house := {}
		for i in r.slots.size():
			var id := StoryRooms.held(&"roundhouse", "door-%d" % n, r, i)
			check(not in_house.has(id), "roundhouse %d says %s twice" % [n, id])
			in_house[id] = true
	eq(dealt.size(), (StoryContent.ROOMS[&"stilt_room"][&"wall:gauge"] as Array).size(), "every stilt house's post is one of the three, and all three stand somewhere")
	# The same door always says the same thing.
	var a := _grow(&"stilt_room", 3)
	eq(StoryRooms.held(&"stilt_room", "same", a, 0), StoryRooms.held(&"stilt_room", "same", _grow(&"stilt_room", 3), 0), "grown twice, the same words")


func test_a_room_s_words_are_never_dealt_to_a_sign_outside() -> void:
	var once := {}
	for kind: StringName in StoryContent.ROOMS:
		for key: StringName in StoryContent.ROOMS[kind]:
			for id: StringName in StoryContent.ROOMS[kind][key]:
				check(StoryFragments.placed(id), "%s belongs to a room" % id)
				check(not once.has(id), "%s is in %s and %s: one thing holds it" % [id, once.get(id, ""), kind])
				once[id] = kind
	for k: StringName in StoryFragments.KINDS:
		for d: BiomeDef in BiomeRegistry.all():
			for i in 60:
				var id := StoryFragments.pick(k, d.id, 11, i)
				check(id == &"" or not StoryRooms.placed(id), "%s dealt a room's words: %s" % [d.id, id])


## The bunker is on the home coast, the spine's first leg: its words may teach
## that he reported to somebody else (`was_cia`, whose other door is a page dealt
## anywhere) and nothing further along. What it holds of June and the play is
## found, never landed: those are the gates' to give.
func test_the_bunker_says_no_more_than_the_first_leg_allows() -> void:
	var landed: Array = []
	for key: StringName in StoryContent.ROOMS[&"bunker"]:
		for id: StringName in StoryContent.ROOMS[&"bunker"][key]:
			landed.append_array(StoryContent.beats_from(id))
	eq(landed, [&"was_cia"], "the bunker lands one thing")
	# What else a room may teach, and only through a page shut until it is earned
	# (docs/story/UNDER_THE_STONES.md): Kerr's binder, and the hulls' manifests.
	var may := {&"bunker:kerr": [&"cairn_knew"], &"hulk_hold": [&"echo_hulls"]}
	for room: StringName in StoryContent.ROOMS:
		if room == &"bunker":
			continue
		for key: StringName in StoryContent.ROOMS[room]:
			for id: StringName in StoryContent.ROOMS[room][key]:
				for b: StringName in StoryContent.beats_from(id):
					check((may.get(room, []) as Array).has(b), "%s in %s lands %s: what people leave is colour, never load" % [id, room, b])
				if room == &"hulk_hold" and not StoryContent.beats_from(id).is_empty():
					check(StoryContent.FRAGMENTS[id].has("until"), "%s lands the hulls only once the Echo is heard" % id)


func test_a_slot_s_words_are_read_off_what_it_stands_at() -> void:
	var l := InteriorLayout.new()
	l.things.append({"kind": &"desk", "at": Vector2(2, 2), "face": Vector2(0, 1), "solid": 0.45})
	l.things.append({"kind": &"whiteboard", "at": Vector2(5, 1), "face": Vector2(0, 1), "solid": 0.0})
	eq(StoryRooms.key_of(l, {"slot": &"terminal", "at": Vector2(2, 2)}), &"terminal:desk", "the terminal on the desk")
	eq(StoryRooms.key_of(l, {"slot": &"wall", "at": Vector2(4.6, 1.2)}), &"wall:whiteboard", "the wall nearest the board")
	l.slots.append({"slot": &"wall", "at": Vector2(9, 9), "face": Vector2(0, -1)})
	l.things.clear()
	l.things.append({"kind": &"nothing_written", "at": Vector2(9, 9), "face": Vector2(0, 1), "solid": 0.0})
	eq(StoryRooms.held(&"bunker", "d", l, 0), &"", "a slot at a thing nobody wrote for holds nothing")
