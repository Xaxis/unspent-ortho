extends TestCase
## The keys page of the settings app, drawn: a row that can be chosen has to be a
## row that can be seen. The page grows with every action a package adds, and the
## journal's key was the one that pushed "put the keys back" off the glass.


func test_every_row_of_the_keys_page_is_on_the_glass_when_it_is_chosen() -> void:
	PlayerSettings.forget_for_test()
	var s := UiSettingsScreen.new()
	tree.root.add_child(s)
	s.open()
	s.settle()
	s.select(&"keys")
	@warning_ignore("return_value_discarded")
	s.handle(&"confirm")
	eq(s.page, "keys", "the keys page is open")
	check(s.menu.rows.size() > 17, "longer than the pane holds, which is the case this is about: %d" % s.menu.rows.size())
	for row: Dictionary in s.menu.rows:
		if not UiMenu.selectable(row):
			continue
		s.select(row.id)
		UiDraw.tape.clear()
		UiDraw.taping = true
		s.queue_redraw()
		await tree.process_frame
		UiDraw.taping = false
		# The key strip says "back" too: only a word inside the list pane counts.
		var seen := false
		for d: Dictionary in UiDraw.tape:
			if d.kind == &"text" and d.ci == s and String(d.text) == String(row.text):
				seen = seen or UiSlate.LIST.encloses(Rect2i(d.rect))
		check(seen, "'%s' is drawn in the list pane when it is chosen" % row.text)
	UiDraw.tape.clear()
	s.free()
	PlayerSettings.forget_for_test()
