extends TestCase
## The menu standard: wrap, skip headings, faded rows still selectable, held
## keys repeat after 0.35 s then every 0.06 s.


func _rows() -> Array[Dictionary]:
	return [
		{"header": &"tools"},
		{"id": &"a"},
		{"id": &"b", "enabled": false},
		{"header": &"food"},
		{"id": &"c"},
	]


func test_starts_on_the_first_selectable_row() -> void:
	var m := UiMenu.new()
	m.set_rows(_rows())
	eq(m.index, 1, "first row is a heading, so index")
	eq(m.selected().id, &"a")


func test_moves_skip_headings_and_wrap() -> void:
	var m := UiMenu.new()
	m.set_rows(_rows())
	check(m.move(1))
	eq(m.selected().id, &"b", "faded rows can be chosen")
	m.move(1)
	eq(m.selected().id, &"c", "heading skipped")
	m.move(1)
	eq(m.selected().id, &"a", "wraps to the top")
	m.move(-1)
	eq(m.selected().id, &"c", "wraps to the bottom")


func test_empty_menu_selects_nothing() -> void:
	var m := UiMenu.new()
	var only_headers: Array[Dictionary] = [{"header": &"x"}]
	m.set_rows(only_headers)
	eq(m.index, -1)
	check(m.selected().is_empty())
	check(not m.move(1), "nothing to move to")


func test_choice_follows_its_row_when_rows_change() -> void:
	var m := UiMenu.new()
	m.set_rows(_rows())
	m.move(1)
	m.move(1)
	eq(m.selected().id, &"c")
	var fewer: Array[Dictionary] = [{"header": &"food"}, {"id": &"c"}, {"id": &"d"}]
	m.set_rows(fewer)
	eq(m.selected().id, &"c", "kept on the same id")
	var gone: Array[Dictionary] = [{"id": &"d"}, {"id": &"e"}]
	m.set_rows(gone)
	check(not m.selected().is_empty(), "falls back to a nearby row")


func test_held_direction_repeats_after_the_delay() -> void:
	var m := UiMenu.new()
	var dt := 1.0 / 60.0
	eq(m.hold(1, dt), 1, "press moves at once")
	var moves := 0
	var t := 0.0
	while t < UiMenu.REPEAT_DELAY - 2.0 * dt:
		moves += m.hold(1, dt)
		t += dt
	eq(moves, 0, "no repeat before the delay")
	moves = 0
	for i in 60:
		moves += m.hold(1, dt)
	# One second more of holding: about 1 / 0.06 repeats.
	check(moves >= 14 and moves <= 18, "repeats per second of hold: %d" % moves)
	eq(m.hold(0, dt), 0, "release")
	eq(m.hold(1, dt), 1, "a fresh press moves at once again")


func test_absorbed_direction_waits_for_release() -> void:
	var m := UiMenu.new()
	m.absorb(1)
	var moves := 0
	for i in 120:
		moves += m.hold(1, 1.0 / 60.0)
	eq(moves, 0, "a key down when the menu opened does not scroll it")
	m.hold(0, 0.1)
	eq(m.hold(1, 0.016), 1)
