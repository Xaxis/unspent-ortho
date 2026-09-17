extends TestCase
## The character page (UiCharacterScreen): every row goes through everything it may
## be and back, every choice is one the people model keeps, the words fit the list,
## "someone else" deals a new body, and "begin" hands over a body with no gear on it.


func test_every_row_goes_through_all_it_may_be_and_back() -> void:
	var look := PersonLook.BASE.duplicate(true)
	for row: Dictionary in UiCharacterScreen.ROWS:
		if row.has("extra"):
			var on := UiCharacterScreen.stepped(look, row, 1)
			check((on.extras as Array).has(row.extra) != (look.extras as Array).has(row.extra), "%s toggles" % row.id)
			var off := UiCharacterScreen.stepped(on, row, 1)
			var a: Array = (off.extras as Array).duplicate()
			var b: Array = (look.extras as Array).duplicate()
			a.sort()
			b.sort()
			eq(a, b, "%s toggles back" % row.id)
			continue
		var all := UiCharacterScreen.choices(row.key)
		gt(float(all.size()), 1.0, "%s has choices" % row.id)
		var seen := {}
		var at := look
		for i in all.size():
			at = UiCharacterScreen.stepped(at, row, 1)
			seen[str(at[row.key])] = true
			# What is chosen is what the model keeps: nothing quietly falls back.
			eq(str(PersonLook.normalize(at)[row.key]), str(at[row.key]), "%s %s reaches the body" % [row.id, at[row.key]])
		eq(seen.size(), all.size(), "%s visits every choice" % row.id)
		# Start from a value the row offers, so going round comes back to it.
		var start := look.duplicate(true)
		start[row.key] = all[0]
		var round := start
		for i in all.size():
			round = UiCharacterScreen.stepped(round, row, 1)
		eq(str(round[row.key]), str(all[0]), "%s wraps round" % row.id)
		var back := UiCharacterScreen.stepped(UiCharacterScreen.stepped(start, row, 1), row, -1)
		eq(str(back[row.key]), str(all[0]), "%s steps back" % row.id)


func test_the_words_fit_the_list() -> void:
	var width := UiSlate.LIST.size.x - UiSlate.MARGIN_L - 8 - 4
	for row: Dictionary in UiCharacterScreen.ROWS:
		var look := PersonLook.BASE.duplicate(true)
		var n := 2 if row.has("extra") else UiCharacterScreen.choices(row.key).size()
		for i in n:
			look = UiCharacterScreen.stepped(look, row, 1)
			var words := UiCharacterScreen.value_words(look, row)
			check(words != "", "%s says what it is" % row.id)
			lt(float(UiFont.width(String(row.label)) + UiFont.width(words) + 30), float(width), "%s: '%s' fits beside its label" % [row.id, words])
	eq(UiCharacterScreen.value_words({"skin_v": 1}, {"key": "skin_v"}), "darker")


func test_begin_hands_over_a_body_and_someone_else_deals_a_new_one() -> void:
	var s := UiCharacterScreen.new()
	tree.root.add_child(s)
	s.seed_value = 7
	s.open()
	var given: Array = []
	s.begun.connect(func(look: Dictionary) -> void: given.append(look))
	s.select(&"build")
	s.handle(&"right")
	var build: StringName = s.look.build
	check(build != &"man", "right changed the build: %s" % build)
	eq(s.figure.worn().get("build"), build, "and the body beside the list changed with it")
	s.select(&"shuffle")
	var before := var_to_str(s.look)
	s.handle(&"confirm")
	check(var_to_str(s.look) != before, "someone else is somebody else")
	check((s.look.get("salvage", []) as Array).is_empty(), "dealt without a stranger's salvage")
	s.select(&"begin")
	s.handle(&"confirm")
	eq(given.size(), 1, "begin hands the body over")
	var look: Dictionary = given[0]
	eq(look.get("gear"), [&"slate"], "with the slate on the wrist and no other kit")
	check(not look.has("kit") and not look.has("salvage"), "gear is the world's to put on")
	s.free()
