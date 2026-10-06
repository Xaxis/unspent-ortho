extends TestCase
## The story map's projection (StoryMap): the whole story laid on one world. Every
## beat is placed or says why not, arrows run beat to beat in each arc's own order,
## the filters keep exactly what they name, and every mark knows its line of source.

const SIZE := 256


func _map(seed_value: int) -> StoryMap:
	Story.forget()
	return StoryMap.project(WorldGen.generate(seed_value, SIZE))


func test_every_beat_is_placed_or_listed_with_why() -> void:
	for s: int in [1, 7]:
		var m := _map(s)
		eq(m.beats.size(), StoryContent.all_beats().size(), "seed %d: every beat of every arc is on the map" % s)
		var placed := 0
		for b: StringName in StoryContent.all_beats():
			var d: Dictionary = m.beats.get(b, {})
			check(not d.is_empty(), "seed %d: %s is projected" % [s, b])
			if d.is_empty():
				continue
			if d.place != &"":
				placed += 1
				check(m.places.has(d.place), "seed %d: %s stands at %s, a place of this world" % [s, b, d.place])
				check((d.pos as Vector2).is_finite() and (d.pos as Vector2).x >= 0.0 and (d.pos as Vector2).x < SIZE,
					"seed %d: %s is somewhere on the world" % [s, b])
				check(not m.unplaced.has(b), "seed %d: %s is not also listed as unplaced" % [s, b])
			else:
				check(m.unplaced.has(b), "seed %d: %s, with no place, is listed" % [s, b])
				check(str(d.why) != "" and str(d.why) != "no door", "seed %d: %s says why it has no place: %s" % [s, b, d.why])
		# The map is a map: most of the story stands somewhere.
		check(placed * 2 > m.beats.size(), "seed %d: %d of %d beats placed" % [s, placed, m.beats.size()])
		print("seed %d: %d of %d beats placed; unplaced: %s" % [s, placed, m.beats.size(), ", ".join(PackedStringArray(m.unplaced))])


## Coming home to his burned beds (`holding_burned`) is a witnessed door, and his
## holding is his own, built after the world was made: it stands at no place the
## map can read, and the map says why in the door's own words.
func test_his_burned_holding_is_a_door_with_no_place() -> void:
	for s: int in [1, 7]:
		var m := _map(s)
		var d: Dictionary = m.beats.get(&"holding_burned", {})
		check(not d.is_empty(), "seed %d: the beat for his burned holding is on the map" % s)
		if d.is_empty():
			continue
		eq(d.place, &"", "seed %d: at no place of the world's" % s)
		check(m.unplaced.has(&"holding_burned"), "seed %d: and listed as unplaced" % s)
		eq(str(d.why), str(StoryContent.WITNESSED.get(&"holding_burned", "")), "seed %d: with its door's own words" % s)


func test_a_beat_a_named_person_lands_stands_where_they_stand() -> void:
	var w := WorldGen.generate(1, SIZE)
	var m := StoryMap.project(w)
	var cast := StoryPlan.cast(w)
	var maren := StoryCast.get_def(&"maren")
	var hers := m.visible(&"", &"maren")
	check(not hers.is_empty(), "Maren lands beats")
	for b: StringName in hers:
		var first: Dictionary = m.beats[b].doors[0]
		if first.kind == &"talk" and first.cast == &"maren":
			eq(m.beats[b].pos as Vector2, cast[maren.at].pos as Vector2, "%s stands at Maren's fire" % b)


func test_arrows_follow_each_arc_in_its_own_order() -> void:
	var m := _map(1)
	var by_arc := {}
	for a: Dictionary in m.arrows:
		check(m.beats[a.from].arc == a.arc and m.beats[a.to].arc == a.arc, "an arrow stays in its arc")
		check(int(m.beats[a.from].index) < int(m.beats[a.to].index), "%s -> %s runs forward in %s" % [a.from, a.to, a.arc])
		if not by_arc.has(a.arc):
			by_arc[a.arc] = []
		(by_arc[a.arc] as Array).append(a)
	for arc: StringName in m.arcs:
		var placed: Array[StringName] = []
		for b: StringName in StoryContent.arc_beats(arc):
			if m.beats[b].place != &"":
				placed.append(b)
		var want: Array[Array] = []
		for i in range(1, placed.size()):
			# Two lands' locals are gathered by an arc, not walked between.
			if not (m.local(m.beats[placed[i - 1]].place) and m.local(m.beats[placed[i]].place)):
				want.append([placed[i - 1], placed[i]])
		var got: Array = by_arc.get(arc, [])
		eq(got.size(), want.size(), "%s: one arrow between each of its placed beats" % arc)
		for i in mini(got.size(), want.size()):
			eq(got[i].from, want[i][0], "%s arrow %d leaves the right beat" % [arc, i])
			eq(got[i].to, want[i][1], "%s arrow %d reaches the next" % [arc, i])
	# Story order: every beat once, legs never going back, an arc's beats in its order.
	eq(m.order.size(), m.beats.size())
	var seen := {}
	var last_leg := 0
	for b: StringName in m.order:
		check(not seen.has(b), "%s is in the order once" % b)
		seen[b] = true
		check(int(m.beats[b].at_leg) >= last_leg, "%s does not step back a leg" % b)
		last_leg = int(m.beats[b].at_leg)


func test_filters_keep_exactly_what_they_name() -> void:
	var m := _map(7)
	eq(m.visible().size(), m.beats.size(), "no filter keeps everything")
	for arc: StringName in m.arcs:
		var kept := m.visible(arc)
		var want: Array[StringName] = []
		for b: StringName in m.order:
			if m.beats[b].arc == arc:
				want.append(b)
		eq(kept, want, "arc %s keeps its own beats, in story order" % arc)
	for leg in StoryMap.LEGS.size():
		for b: StringName in m.visible(&"", &"", leg):
			eq(int(m.beats[b].leg), leg, "leg %d keeps only its own" % leg)
	for who: StringName in m.speakers():
		var kept := m.visible(&"", who)
		check(not kept.is_empty(), "%s is a speaker with beats" % who)
		for b: StringName in m.beats:
			var by := false
			for door: Dictionary in m.beats[b].doors:
				by = by or door.cast == who
			eq(kept.has(b), by, "%s: %s kept exactly when %s can land it" % [who, b, who])
	var both := m.visible(&"the_crew", &"rook")
	for b: StringName in both:
		eq(m.beats[b].arc, &"the_crew", "filters meet: the arc")
	check(m.visible(&"june", &"rook").is_empty() or m.visible(&"june", &"rook").all(func(b: StringName) -> bool: return m.beats[b].arc == &"june"), "and never widen")


func test_every_mark_knows_the_line_that_made_it() -> void:
	var m := _map(1)
	var text := FileAccess.get_file_as_string(StoryMap.CONTENT).split("\n")
	for b: StringName in m.beats:
		var src := str(m.beats[b].source)
		var line := src.get_slice(":", 1).to_int()
		check(line > 0, "%s has a line: %s" % [b, src])
		if line > 0:
			check(text[line - 1].contains("&\"%s\"" % b), "%s's line is its own: %s" % [b, text[line - 1].strip_edges().left(60)])
		for door: Dictionary in m.beats[b].doors:
			check(str(door.source).contains(":"), "%s's door %s has a line" % [b, door.id])


func test_the_source_index_reads_tables_one_tab_in() -> void:
	var src := "const A := {\n\t&\"x\": {\n\t\t&\"y\": 1,\n\t},\n}\nconst B := {\n\t&\"x\": 2,\n}\n"
	var ix := StoryMap.source_index(src)
	eq(int(ix.get("A", 0)), 1)
	eq(int(ix.get("A.x", 0)), 2, "an entry is the key one tab in")
	check(not ix.has("A.y"), "a key deeper in belongs to its entry")
	eq(int(ix.get("B.x", 0)), 7, "the same id in another table is its own")


func test_the_live_save_is_read_on_top() -> void:
	var m := _map(1)
	var first: StringName = StoryContent.arc_beats(&"who_he_was")[0]
	var second: StringName = StoryContent.arc_beats(&"who_he_was")[1]
	eq(m.state_of(first), &"open", "the first beat of an arc is open")
	eq(m.state_of(second), &"later")
	Story.beat(first)
	eq(m.state_of(first), &"landed")
	eq(m.state_of(second), &"withheld" if StoryPacing.settling() and StoryPacing.is_reveal(second) else &"open", "and the next opens")
	Story.now = 0.0
	Story.beat(&"body_new")
	check(StoryPacing.settling(), "a revelation settles")
	var reveal := &""
	for b: StringName in m.beats:
		if m.beats[b].reveal and not Story.landed(b):
			reveal = b
			break
	eq(m.state_of(reveal), &"withheld", "while it settles, no other revelation is offered")
	Story.forget()


## Opening the map must not stall the game: the projection of a full-size world
## costs well under the frame budget of a page open.
func test_projecting_costs_less_than_a_second() -> void:
	var w := WorldGen.generate(1, 512)
	StoryPlan.cast(w)
	var t := Time.get_ticks_usec()
	var m := StoryMap.project(w)
	var us := Time.get_ticks_usec() - t
	check(m.beats.size() > 0)
	cost_lt(float(us), 1000000.0, "projected in %d us" % us)
	print("story map projection: %d us on seed 1 at 512" % us)


## A streamed world still being laid is never projected: a map of part of it
## would say beats have no place that have one.
func test_a_world_not_yet_whole_is_not_projected() -> void:
	var w := WorldGen.generate(1, SIZE)
	check(StoryMap.whole(w), "a world grown today is whole")
	var part := GDScript.new()
	part.source_code = "extends WorldData\nvar whole := false\n"
	part.reload()
	var laying: WorldData = part.new(1, SIZE)
	check(not StoryMap.whole(laying), "one that says it is not whole is not")
	var m := StoryMap.project(laying)
	check(not m.laid, "and is not laid")
	eq(m.beats.size(), 0, "nothing is projected from it")
	eq(m.places.size(), 0, "and no place is read")
	check(StoryMap.project(w).laid, "a whole world is")


func test_every_step_back_a_leg_is_one() -> void:
	for s: int in [1, 7]:
		var m := _map(s)
		var want := 0
		for arc: StringName in m.arcs:
			var list: Array = StoryContent.arc_beats(arc)
			for i in range(1, list.size()):
				var a: Dictionary = m.beats[list[i - 1]]
				var b: Dictionary = m.beats[list[i]]
				if m.local(a.place) and m.local(b.place):
					continue
				if int(b.at_leg) < int(a.at_leg):
					want += 1
		eq(m.steps_back.size(), want, "seed %d: every step back, and only those" % s)
		for st: Dictionary in m.steps_back:
			check(int(m.beats[st.to].at_leg) < int(m.beats[st.from].at_leg), "%s -> %s steps back" % [st.from, st.to])
