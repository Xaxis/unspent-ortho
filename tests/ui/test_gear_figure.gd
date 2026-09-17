extends TestCase
## The body on the gear page (UiGearFigure, UiLoadoutScreen): it is dressed from
## the feed the gear system fills with the same look the world puts on the player,
## it turns to show the slot chosen, a change of dress runs the scan again, and its
## scanner draws in the slate's own tones.

const Fx := preload("res://tests/survival/fixture.gd")


func test_the_scanner_draws_in_the_slates_own_tones() -> void:
	var code := FileAccess.get_file_as_string("res://src/ui/ui_gear_scan.gdshader")
	check(code != "", "the scanner is a shader file under src/ui")
	var pairs := {"P": UiTheme.PHOSPHOR, "M": UiTheme.MACHINE}
	var found := 0
	for line: String in code.split("\n"):
		var m := RegEx.create_from_string("const vec3 ([PM])(\\d) = vec3\\(([0-9.]+), ([0-9.]+), ([0-9.]+)\\);").search(line)
		if m == null:
			continue
		found += 1
		var want: Color = (pairs[m.get_string(1)] as Array)[m.get_string(2).to_int()]
		var got := Color(m.get_string(3).to_float(), m.get_string(4).to_float(), m.get_string(5).to_float())
		for c in 3:
			near(got[c], want[c], 1.5 / 255.0, "%s%s channel %d is UiTheme's" % [m.get_string(1), m.get_string(2), c])
	eq(found, 9, "five phosphor steps and four violet ones")


func test_every_slot_has_a_place_on_the_body_and_the_back_turns_it_round() -> void:
	for slot in Gear.SLOTS:
		check(UiLoadoutScreen.PARTS.has(slot), "%s has a part of the body" % slot)
	var back := UiLoadoutScreen.yaw_for(&"back")
	var front := UiLoadoutScreen.yaw_for(&"body")
	gt(absf(angle_difference(back, front)), 2.4, "the back slot turns the body round to show its back")
	check(UiSlate.SPARE.encloses(UiLoadoutScreen.FIGURE), "the figure stands on the spare panel")
	check(UiLoadoutScreen.FIGURE.end.x <= UiLoadoutScreen.RESIST_X, "clear of the resistances")


func test_a_change_of_dress_runs_the_scan_and_the_same_dress_does_not() -> void:
	var f := UiGearFigure.new()
	var look := PersonLook.BASE.duplicate(true)
	f.wear(look, &"knife", false)
	lt(f.scan, 1.0, "dressed: the scan runs")
	f.settle()
	eq(f.scan, 1.0, "settled")
	f.wear(look, &"knife", false)
	eq(f.scan, 1.0, "the same dress again: nothing to scan")
	var coated := look.duplicate(true)
	coated["coat"] = &"oilskin"
	f.wear(coated, &"knife", false)
	lt(f.scan, 1.0, "a coat on: the scan runs again")
	f.settle()
	f.wear(coated, &"pick", false)
	lt(f.scan, 1.0, "another tool in hand is a change too")
	f.free()


func test_the_page_draws_the_body_the_feed_names() -> void:
	SlateFeeds.clear()
	var worn := PersonLook.BASE.duplicate(true)
	worn["coat"] = &"oilskin"
	worn["kit"] = true
	SlateFeeds.provide(&"loadout", func(_g: Game) -> Dictionary:
		return {"slots": [{"id": &"body", "label": "body", "item": &"oilskin", "modules": []}, {"id": &"back", "label": "back", "item": &"", "modules": []}],
			"resist": {}, "abilities": [], "figure": {"look": worn, "held": &"pick", "wing": true}})
	var s := UiLoadoutScreen.new()
	tree.root.add_child(s)
	s.open()
	eq(StringName(s.figure.worn().get("coat", &"")), &"oilskin", "the figure wears what the feed says")
	eq(s.figure.held(), &"pick")
	check(s.figure.wing_worn(), "and the wing")
	near(s.figure.yaw_to, UiLoadoutScreen.yaw_for(&"body"), 1e-6, "turned to show the chosen slot")
	s.handle(&"down")
	near(s.figure.yaw_to, UiLoadoutScreen.yaw_for(&"back"), 1e-6, "the back chosen: it turns round")
	var was := s.figure.yaw_to
	s.handle(&"right")
	gt(absf(angle_difference(s.figure.yaw_to, was)), 0.1, "turned by hand")
	s.free()
	SlateFeeds.clear()


func test_without_a_feed_the_page_draws_the_bare_body() -> void:
	SlateFeeds.clear()
	var g := Fx.flat()
	var s := UiLoadoutScreen.new()
	s.game = g
	tree.root.add_child(s)
	s.open()
	eq(StringName(s.figure.worn().get("coat", &"x")), StringName(PersonLook.BASE.coat), "the base body")
	eq(s.figure.held(), g.inventory.held, "holding what is in hand")
	s.free()
	Fx.done(g)
