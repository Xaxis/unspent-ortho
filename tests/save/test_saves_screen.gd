extends TestCase
## The saves page from the pause page: save lists the three slots and asks once
## more before writing over one; load lists the autosave too, fades what is
## empty or damaged and says why; loading replaces the running game with the
## saved one. And the tour's frame comparison tells like from unlike.

const Sx := preload("res://tests/save/save_fixture.gd")


class FakeSaver:
	extends RefCounted
	var saves: Array[int] = []
	var loads: Array[int] = []

	func save_to(slot: int) -> String:
		saves.append(slot)
		var header := {"clock": "day 1  08:00", "place": "coast", "saved_at": 1.0, "seed": 1, "size": 48}
		return "" if SaveFile.write(SaveSlots.path(slot), header, {}) == OK else "It would not save."

	func load_from(slot: int) -> String:
		loads.append(slot)
		return ""


func test_save_asks_before_writing_over_and_load_says_what_cannot_be_read() -> void:
	Sx.use_root("screen")
	var s := UiSavesScreen.new()
	var fake := FakeSaver.new()
	s.saver = fake
	tree.root.add_child(s)
	s.mode = &"save"
	s.open()
	eq(s.menu.rows.size(), 3, "save: three slots, no autosave")
	s.handle(&"confirm")
	eq(fake.saves, [1], "an empty slot is written at once")
	eq(s.note, "Saved to slot 1.")
	check((s.menu.selected().entry as Dictionary).ok, "and the row now holds it")
	s.handle(&"confirm")
	eq(fake.saves, [1], "a filled slot asks first")
	eq(s.note, "Again, to write over slot 1.")
	s.handle(&"confirm")
	eq(fake.saves, [1, 1], "and is written on the second press")
	s.handle(&"confirm")
	s.handle(&"down")
	s.handle(&"up")
	s.handle(&"confirm")
	eq(fake.saves, [1, 1], "moving away forgets the ask")
	s.close()

	_put(SaveSlots.path(2), "broken".to_utf8_buffer())
	s.mode = &"load"
	s.open()
	eq(s.menu.rows.size(), 4, "load: the autosave and three slots")
	s.select(&"slot_0")
	s.handle(&"confirm")
	eq(s.note, "The autosave is empty.", "an empty autosave says so")
	s.select(&"slot_2")
	check(not UiMenu.enabled(s.menu.selected()), "a damaged slot is faded")
	s.handle(&"confirm")
	eq(s.note, "Slot 2 is damaged and cannot be read.", "and says so plainly")
	eq(fake.loads, [], "nothing loads from them")
	s.select(&"slot_1")
	s.handle(&"confirm")
	eq(fake.loads, [1], "a good slot loads")
	eq(s.note, "Loading slot 1...")
	s.handle(&"confirm")
	s.handle(&"down")
	s.handle(&"back")
	eq(fake.loads, [1], "once loading, the page takes no more keys")
	check(s.is_open, "not even esc")
	s.close()
	s.open()
	s.select(&"slot_1")
	s.handle(&"confirm")
	eq(fake.loads, [1, 1], "opened again, it listens again")
	s.close()
	s.free()
	Sx.finish()


func test_load_from_the_pause_page_replaces_the_game_with_the_saved_one() -> void:
	Sx.use_root("pause-load")
	var holder := Node.new()
	tree.root.add_child(holder)
	var g := Game.new()
	g.name = "game"
	holder.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--size=48", "--seed=2"])))
	var ui := Sx.system(g, "90_ui")
	var saver := Sx.system(g, "05_save")
	g.inventory.add(&"stone", 5)
	g.clock.minutes = 3000.0
	check(bool(ui.call("open_screen", &"pause")), "paused")
	var pause: UiPauseScreen = ui.call("top")
	pause.select(&"save")
	pause.handle(&"confirm")
	var page: UiScreen = ui.call("top")
	check(page is UiSavesScreen and (page as UiSavesScreen).mode == &"save", "save opens the saves page over the pause page")
	page.handle(&"confirm")
	eq(page.note, "Saved to slot 1.")
	page.handle(&"back")
	check(ui.call("top") == pause, "esc comes back to the pause page")
	# Play on, then load what was saved.
	g.inventory.remove(&"stone", 5)
	g.clock.minutes = 5000.0
	pause.select(&"load")
	pause.handle(&"confirm")
	page = ui.call("top")
	check(page is UiSavesScreen and (page as UiSavesScreen).mode == &"load", "load opens the page in load mode")
	page.select(&"slot_1")
	page.handle(&"confirm")
	eq(saver.get("loaded_from"), -1)
	# E lands twice before the game gives way: one load, and no more saves.
	page.handle(&"confirm")
	eq(saver.call("load_from", 1), "Another game is on its way.", "a second load is refused")
	eq(saver.call("save_to", 2), "Another game is on its way.", "and so is a save")
	for i in 4:
		await tree.process_frame
	var next := holder.get_node_or_null("game") as Game
	check(next != null and next != g, "a new game stands in the old one's place")
	eq(holder.get_child_count(), 1, "one game, not two")
	check(not SaveSlots.exists(2), "the refused save wrote nothing")
	if next != null and next != g:
		check(not tree.paused, "unpaused")
		eq(next.inventory.count(&"stone"), 5, "carrying what was saved")
		near(next.clock.minutes, 3000.0, 0.5, "at the hour it was saved (and a few frames on)")
		eq(Sx.system(next, "05_save").get("loaded_from"), 1)
	holder.free()
	Sx.finish()


func test_the_tour_tells_matching_frames_from_different_ones() -> void:
	var tour: GDScript = load("res://src/systems/98_tour.gd")
	var a := Image.create(64, 36, false, Image.FORMAT_RGB8)
	a.fill(Color(0.3, 0.4, 0.5))
	var b := a.duplicate() as Image
	near(float(tour.call("frame_difference", a, b)), 0.0, 1e-6, "the same frame")
	b.fill_rect(Rect2i(0, 0, 4, 4), Color(1, 1, 1))
	var small := float(tour.call("frame_difference", a, b))
	check(small > 0.0 and small < 0.01, "a few pixels differ a little: %f" % small)
	var c := a.duplicate() as Image
	c.fill(Color(0.9, 0.1, 0.1))
	gt(float(tour.call("frame_difference", a, c)), 0.2, "another picture differs a lot")
	eq(float(tour.call("frame_difference", a, Image.create(10, 10, false, Image.FORMAT_RGB8))), 1.0, "sizes that differ cannot match")
	# A small thing lost in a big frame hides in the mean; a crop around it does not.
	var lost := a.duplicate() as Image
	lost.fill_rect(Rect2i(30, 10, 6, 6), Color(0.3, 0.4, 0.1))
	lt(float(tour.call("frame_difference", a, lost)), 0.01, "over the whole frame a small loss is under a loose tolerance")
	gt(float(tour.call("frame_difference", a, lost, Rect2i(26, 6, 14, 14))), 0.02, "around it, it is not")
	near(float(tour.call("frame_difference", a, lost, Rect2i(0, 20, 20, 16))), 0.0, 1e-6, "a crop elsewhere is unchanged")
	eq(float(tour.call("frame_difference", a, lost, Rect2i(60, 30, 10, 10))), 1.0, "a crop off the frame cannot match")


func _put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
