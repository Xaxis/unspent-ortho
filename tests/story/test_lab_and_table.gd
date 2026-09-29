extends TestCase
## THE LAB AND RUTH'S TABLE (ROADMAP slice 2, step 5). Each reveal has a door on
## the first leg that the story stands itself: the yard's oldest screen at the
## first works (`yard_commits`, dark until the Reaper is down; built_halcyon),
## and a steel document box at the crew's camp (`handler_note`, shut until
## built_halcyon is felt; was_cia). The people of the lab and the table stand in
## the Before only once the reveal that opens their gate has been felt, so STORY's
## gate order holds: his house, then the lab, then Ruth's table.

const Sx := preload("res://tests/save/save_fixture.gd")
## What stands at each place, and how far off its slot it may stand.
const THINGS := {&"the_yard": PropKind.CONSOLE, &"the_camp": PropKind.DOC_BOX}
const NEAR := 10.0


func _args(s: int) -> Array:
	# Full size, as the game ships (one world size everywhere): on a shrunken world
	# the camp can fall inside a keeper's ground and nothing may stand there.
	return ["--seed=%d" % s, "--hour=11", "--weather=clear:0"]


func _slot(g: Game, slot: StringName) -> Vector2:
	var placed := StoryPlan.cast(g.world)
	return placed[slot].pos if placed.has(slot) else Vector2.INF


## Walk up to a slot: the story stands its thing once he is near and the ground
## round it is streamed in (49_cast STAND_NEAR, on its twice-a-second check).
func _visit(g: Game, slot: StringName) -> void:
	var at := _slot(g, slot)
	# `place`, as a tour's warp does: the fight body owns where he stands.
	var p := g.player.place(at + Vector2(3.0, 0.0))
	g.view.ensure_near(p)
	for i in 120:
		await process_frames(1)
		if not _stood(g, int(THINGS[slot]), at).is_empty():
			break


## The things set down in play of `kind` near `at` (a save keeps these).
func _stood(g: Game, kind: int, at: Vector2) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	for i in range(g.world.generated(), g.world.prop_count()):
		var q := g.world.prop_at(i)
		if q.kind == kind and q.pos.distance_to(at) <= NEAR:
			out.append(q)
	return out


func test_the_yard_and_the_camp_each_stand_a_thing_with_their_own_words() -> void:
	for s: int in [1, 7]:
		Story.forget()
		var g := Sx.game(tree, _args(s))
		await process_frames(2)
		for slot: StringName in THINGS:
			var at := _slot(g, slot)
			check(at.is_finite(), "seed %d casts %s" % [s, slot])
			eq(_stood(g, int(THINGS[slot]), at).size(), 0, "nothing stood there before he comes near")
			await _visit(g, slot)
			var got := _stood(g, int(THINGS[slot]), at)
			eq(got.size(), 1, "seed %d: one thing stands at %s" % [s, slot])
			if got.size() != 1:
				continue
			var p := got[0]
			var t := Vector2i(p.pos.floor())
			check(g.query.standable(t.x, t.y) and not Ground.is_water(g.world.ground_at(t.x, t.y)), "on dry ground you can stand at")
			check(g.query.body_fits(p.pos, 0.6), "and not inside a building's footprint")
			for q: WorldProp in g.query.props_near(p.pos, StoryProps.REACH + 2.0):
				if q.id != p.id and StoryProps.readable(q.kind):
					check(q.pos.distance_to(p.pos) - q.solid > StoryProps.REACH, "no other words in reach of it to take its `use`")
			for row: Dictionary in Sx.system(g, "49_cast").get("people"):
				check((row.pos as Vector2).distance_to(p.pos) > StoryProps.REACH, "no one cast stands where its `use` would speak to them (%s)" % row.character)
			for gate: Dictionary in StoryGates.all(g.world):
				check(p.pos.distance_to(gate.pos as Vector2) > 1.5 + StoryProps.CLOSE + PropKind.SOLID[p.kind], "far enough from %s that reading it never crosses" % gate.id)
			for st: SentinelState in Sentinels.states(g.world):
				var def := Sentinels.by_id(st.design)
				check(p.pos.distance_to(st.lair) > def.reach, "clear of %s's ground" % st.design)
			var words := StoryContent.PLACED.get(slot, []) as Array
			check(not words.is_empty(), "%s has words of its own" % slot)
			if not words.is_empty():
				eq(StoryFragments.held_by(g.world, g.query, p), StringName(words[0]), "and the thing there holds them")
		Sx.end(g)
	Story.forget()


func test_they_stand_where_they_stood_after_a_save_and_a_stream() -> void:
	Sx.use_root("lab-and-table")
	Story.forget()
	var a := Sx.game(tree, _args(1))
	await process_frames(2)
	var was := {}
	for slot: StringName in THINGS:
		await _visit(a, slot)
		var got := _stood(a, int(THINGS[slot]), _slot(a, slot))
		if got.size() == 1:
			was[slot] = got[0].pos
	eq(was.size(), 2, "both stand to begin with")
	# Out to the camp and back: the sections round both stream in and out.
	var home: Vector2 = a.player.pos
	for slot: StringName in THINGS:
		a.view.ensure_near(a.player.place(_slot(a, slot)))
		await process_frames(20)
		var seen := false
		for q: WorldProp in a.query.props_near(_slot(a, slot), NEAR):
			seen = seen or (q.kind == int(THINGS[slot]) and was.has(slot) and q.pos == was[slot])
		check(seen, "walked up to, %s's thing is there in the streamed world" % slot)
	a.view.ensure_near(a.player.place(home))
	await process_frames(20)
	eq(Sx.system(a, "05_save").call("save_to", 3), "", "saved")
	Sx.end(a)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(3, o), "", "and loaded")
	var b := Sx.game(tree, [], o)
	await process_frames(2)
	for slot: StringName in THINGS:
		await _visit(b, slot)
		var got := _stood(b, int(THINGS[slot]), _slot(b, slot))
		eq(got.size(), 1, "one thing at %s after the load, not a second set down beside it" % slot)
		if got.size() == 1 and was.has(slot):
			eq(got[0].pos, was[slot] as Vector2, "where it stood")
			eq(StoryFragments.held_by(b.world, b.query, got[0]), StringName((StoryContent.PLACED.get(slot, [&""]) as Array)[0]), "holding the same words")
	Sx.end(b)
	Sx.finish()
	Story.forget()


func _read_at(g: Game, slot: StringName) -> PackedStringArray:
	var got := _stood(g, int(THINGS[slot]), _slot(g, slot))
	if got.size() != 1:
		return PackedStringArray()
	var story := Sx.system(g, "49_story")
	story.call("_start_reading", got[0])
	var lines: PackedStringArray = story.get("view").get("reading")
	story.call("_close_reading") if story.has_method("_close_reading") else null
	g.talking = false
	return lines


func test_the_order_holds_house_then_lab_then_table() -> void:
	Story.forget()
	var g := Sx.game(tree, _args(1))
	await process_frames(2)
	for slot: StringName in THINGS:
		await _visit(g, slot)
	var box := _read_at(g, &"the_camp")
	check(box.size() > 0 and box[0].begins_with("A typed page, folded small"), "the box's page, read before the lab, is shut")
	check(not Story.landed(&"was_cia"), "and lands nothing")
	var screen := _read_at(g, &"the_yard")
	check(screen.size() > 0 and screen[screen.size() - 1] == "IN USE. OPERATOR NOT REQUIRED.", "the yard's screen is busy while the Reaper keeps it")
	check(not Story.landed(&"built_halcyon"), "and gives up nothing")
	Story.now = 1000.0
	Story.beat(&"reaper_down")
	screen = _read_at(g, &"the_yard")
	check(Story.landed(&"built_halcyon") and Story.landed(&"priya_warned"), "the yard dark, his own last merge is on it")
	box = _read_at(g, &"the_camp")
	check(not Story.landed(&"was_cia"), "the box still shut while the lab is being felt")
	Story.now += StoryPacing.SETTLE
	box = _read_at(g, &"the_camp")
	check(Story.landed(&"was_cia"), "then the page is his handler's")
	Sx.end(g)
	Story.forget()


func test_the_lab_and_the_table_wait_on_their_reveals() -> void:
	Story.forget()
	Story.now = 100.0
	for id: StringName in [&"kerr", &"priya_then", &"ruth"]:
		check(not StoryCast.get_def(id).present(), "%s is not in the Before on the first morning" % id)
	Story.beat(&"built_halcyon")
	Story.now += StoryPacing.SETTLE
	check(StoryCast.get_def(&"kerr").present() and StoryCast.get_def(&"priya_then").present(), "the lab's people, once he has felt that he built it")
	check(not StoryCast.get_def(&"ruth").present(), "Ruth not yet")
	Story.beat(&"was_cia")
	Story.now += StoryPacing.SETTLE
	check(StoryCast.get_def(&"ruth").present(), "Ruth, once he has felt who he reported to")
	Story.forget()
