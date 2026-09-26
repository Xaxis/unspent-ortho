extends TestCase
## What a room's story slots hold (StoryRooms, StoryContent.ROOMS): every slot a
## room's recipe opens is written for, every row the story writes is one a room
## can reach, a door deals its own, and the bunker says no more than the home
## coast's leg of the spine allows (docs/STORY.md).

## How many doors' worth of each kind to grow: enough that every deal a recipe
## makes (which bay holds the loom, which side the work room is on) comes up.
const DOORS := 60


func _grow(kind: StringName, n: int, land: int = -1) -> InteriorLayout:
	var k := Interiors.kind(kind)
	if k.by_land:
		return k.recipe.call(&"lay", Rng.make(n, 0x51075), land) as InteriorLayout
	return k.recipe.call(&"lay", Rng.make(n, 0x51075)) as InteriorLayout


## The ROOMS row a kind speaks from (InteriorKind.words).
func _row(kind: StringName) -> StringName:
	var w := Interiors.kind(kind).words
	return w if w != &"" else kind


## The lands a kind is grown in: every landscape for a kind laid by its land (a
## home, kept by that landscape's own), else the one.
func _lands_of(kind: StringName) -> Array[int]:
	var out: Array[int] = [-1]
	if Interiors.kind(kind).by_land:
		for d: BiomeDef in BiomeRegistry.all():
			out.append(d.index)
	return out


func test_every_room_the_story_writes_for_is_a_room() -> void:
	for room: StringName in StoryContent.ROOMS:
		# `kind:TENANT` is one household's room of that kind (StoryRooms.room_of).
		var kind := StringName(String(room).get_slice(":", 0))
		check(Interiors.kind(kind) != null, "%s is a kind of room (Interiors.RECIPES)" % room)


func test_every_slot_a_room_opens_holds_words() -> void:
	for kind: StringName in Interiors.RECIPES:
		var seen := {}
		for land: int in _lands_of(kind):
			for n in DOORS:
				var l := _grow(kind, n, land)
				for i in l.slots.size():
					var key := StoryRooms.key_of(l, l.slots[i])
					seen[key] = true
					var id := StoryRooms.held(_row(kind), "door-%d" % n, l, i, land)
					check(id != &"", "%s in %d: a slot at %s holds nothing" % [kind, land, key])
					check(StoryContent.FRAGMENTS.has(id), "%s: %s is written" % [kind, id])
		# And every row written for this room is one a slot can stand at.
		if _row(kind) != kind:
			continue
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


## A HOME SAYS ITS OWN LANDSCAPE'S WORDS: every landscape that keeps homes opens
## a home's two slots (the table, the household's first piece), and what they
## hold was written for that landscape and that household -- a pinewood home
## never gets a snowfield line, and a trapper's wall never a mason's.
func test_a_home_deals_only_its_own_landscapes_and_households_words() -> void:
	var lands := 0
	for d: BiomeDef in BiomeRegistry.all():
		if (d.home.get("households", {}) as Dictionary).is_empty():
			continue
		lands += 1
		for n in 20:
			var l := _grow(&"home", n, d.index)
			var keys := {}
			for i in l.slots.size():
				var key := StoryRooms.key_of(l, l.slots[i])
				keys[key] = true
				var id := StoryRooms.held(&"home", "door-%d" % n, l, i, d.index)
				var f: Dictionary = StoryContent.FRAGMENTS.get(id, {})
				var fl: Array = f.get("lands", [])
				check(fl.is_empty() or StoryRooms._holds(fl, String(d.id)), "%s home %d: %s was written for %s" % [d.id, n, id, fl])
				var fh: Array = f.get("households", [])
				check(fh.is_empty() or StoryRooms._holds(fh, String(l.dressing)), "%s %s home %d: %s was written for %s" % [d.id, l.dressing, n, id, fh])
			check(keys.has(&"desk:home") and keys.has(&"wall:home"), "%s %s home %d opens its table and its wall (%s)" % [d.id, l.dressing, n, keys.keys()])
	gt(float(lands), 15.0, "landscapes with homes asked (%d)" % lands)


## A SQUAT'S ONE SLOT is at its way out, with the machine city's words.
func test_a_squat_speaks_at_its_way_out() -> void:
	var mc := BiomeRegistry.get_def(&"machine_city")
	for n in 10:
		var l := _grow(&"squat", n, mc.index)
		eq(l.slots.size(), 1, "one slot")
		eq(StoryRooms.key_of(l, l.slots[0]), &"wall:squat", "at the crawl hole")
		check(StoryRooms.held(&"squat", "door-%d" % n, l, 0, mc.index) != &"", "holding words")


## THE COAST'S COTTAGES ARE HOMES TOO: they speak from the homes' row
## (InteriorKind.words), at their table and at their household's first piece,
## with lines written for the coast.
func test_the_coasts_cottages_speak_from_the_homes_row() -> void:
	var coast := BiomeRegistry.get_def(&"coast")
	for n in 12:
		var l := _grow(&"cottage", n)
		var keys := {}
		for i in l.slots.size():
			keys[StoryRooms.key_of(l, l.slots[i])] = true
			var id := StoryRooms.held(_row(&"cottage"), "door-%d" % n, l, i, coast.index)
			var fl: Array = (StoryContent.FRAGMENTS.get(id, {}) as Dictionary).get("lands", [])
			check(id != &"" and (fl.is_empty() or StoryRooms._holds(fl, "coast")), "cottage %d holds a coast line, not %s" % [n, id])
		check(keys.has(&"desk:home") and keys.has(&"wall:home"), "cottage %d (%s) opens its table and wall" % [n, l.dressing])
