extends TestCase
## The arc view's graph (StoryArcGraph): every beat of an arc, in its order, joined
## beat to beat; every door that can land a beat hung on it with the lines said
## and who says them; what must be known first joined to the door it opens; the
## gates a beat opens; and every node naming its line of source.

const SIZE := 256


func _map() -> StoryMap:
	Story.forget()
	return StoryMap.project(WorldGen.generate(1, SIZE))


func test_every_beat_of_every_arc_is_a_node_in_order() -> void:
	var m := _map()
	for arc: StringName in m.arcs:
		var g := StoryArcGraph.build(m, arc)
		var list: Array = StoryContent.arc_beats(arc)
		var beats: Array[StringName] = []
		for n: Dictionary in g.nodes:
			if n.kind == &"beat":
				beats.append(n.beat)
		eq(beats, Array(list, TYPE_STRING_NAME, &"", null), "%s: its beats, in its order" % arc)
		var next := 0
		for e: Dictionary in g.edges:
			check(not g.node(e.from).is_empty() and not g.node(e.to).is_empty(), "%s: an edge joins two nodes" % arc)
			if e.kind == &"next":
				next += 1
				eq(int(g.node(e.to).col), int(g.node(e.from).col) + 1, "%s: next runs one beat on" % arc)
		eq(next, maxi(0, list.size() - 1), "%s: beat to beat, all the way" % arc)


func test_every_door_hangs_on_its_beat_with_its_lines() -> void:
	var m := _map()
	for arc: StringName in m.arcs:
		var g := StoryArcGraph.build(m, arc)
		for b: StringName in StoryContent.arc_beats(arc):
			var doors := 0
			for e: Dictionary in g.edges:
				if e.kind == &"lands" and e.to == StringName("beat:%s" % b):
					doors += 1
			var want := {}
			for door: Dictionary in m.beats[b].doors:
				want["%s:%s" % [door.id, door.get("node", &"")]] = true
			eq(doors, want.size(), "%s: every door of %s hangs on it" % [arc, b])
		for n: Dictionary in g.nodes:
			check(str(n.source).contains(":") and str(n.source).begins_with("src/"), "%s: %s names its line: %s" % [arc, n.id, n.source])
			check(not (n.lines as Array).is_empty(), "%s: %s says something" % [arc, n.id])
			if n.get("door", &"") == &"talk":
				var said := false
				for l: Array in n.lines:
					said = said or (str(l[0]) != "" and str(l[0]) != "where" and str(l[0]) != "once known")
				check(said, "%s: %s gives its lines with who says them" % [arc, n.id])


func test_what_must_be_known_first_opens_the_door() -> void:
	var m := _map()
	# June is not in the square until her name has been said (cast/june.gd).
	var g := StoryArcGraph.build(m, &"june")
	var june := StoryCast.get_def(&"june")
	var found := false
	for e: Dictionary in g.edges:
		if e.kind == &"needs" and e.known == june.appears_when:
			found = true
			eq(g.node(e.to).kind, &"door", "a need opens a door")
	check(found, "june_named opens the doors June stands at")
	# A beat that opens a gate into 2029 has it hung over it.
	var who := StoryArcGraph.build(m, &"who_he_was")
	var gates := 0
	for e: Dictionary in who.edges:
		if e.kind == &"opens":
			gates += 1
			eq(who.node(e.to).kind, &"gate")
	var want := 0
	for gate: Dictionary in StoryGates.GATES:
		if StoryContent.beat_arc(gate.opens) == &"who_he_was":
			want += 1
	eq(gates, want, "every gate a beat of who he was opens")
