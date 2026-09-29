extends TestCase
## WE BREAK THEIR WORKS, THEY BURN A VILLAGE (Vera; slice 2 step 3). Pure: a
## housing broken on a live yard sends the yard's hunters to the nearest roof,
## and the roof burns MARCH_MINUTES later unless the yard has gone dark by then.
## A dark yard sends nobody: the region is let be (Maren, reaper_down).


func _house(id: int, at: Vector2) -> WorldProp:
	return WorldProp.new(id, PropKind.HOUSE, at, 0.0, 1.0)


func test_the_hunters_go_for_the_nearest_roof() -> void:
	var yard := Vector2(100, 100)
	var props: Array[WorldProp] = [_house(1, Vector2(160, 100)), _house(2, Vector2(130, 90)),
		WorldProp.new(3, PropKind.BOULDER, Vector2(105, 100), 0.0, 1.0)]
	eq(Reprisal.nearest_roof(props, yard), Vector2(130, 90), "the nearest house, not a boulder")
	var none: Array[WorldProp] = [WorldProp.new(4, PropKind.BOULDER, Vector2(105, 100), 0.0, 1.0)]
	eq(Reprisal.nearest_roof(none, yard), Vector2.INF, "and nobody to burn where there is no roof")
	var gone := {2: INF}
	eq(Reprisal.nearest_roof(props, yard, gone), Vector2(160, 100), "a roof already burned is passed over for the next")


func test_a_roof_burns_after_the_march_unless_the_yard_is_dark() -> void:
	var r := Reprisal.new()
	check(r.send(7, Vector2(130, 90), 1000.0), "a housing broken sends them")
	check(not r.send(7, Vector2(130, 90), 1010.0), "one party a yard: a second housing does not send another")
	eq(r.burning_now(1000.0 + Reprisal.MARCH_MINUTES - 1.0).size(), 0, "not before they get there")
	var due := r.burning_now(1000.0 + Reprisal.MARCH_MINUTES)
	eq(due.size(), 1, "on the march's end, the roof")
	if due.size() == 1:
		eq(due[0], Vector2(130, 90), "that one")
	eq(r.burning_now(1000.0 + Reprisal.MARCH_MINUTES * 2.0).size(), 0, "and it burns once")


func test_a_yard_put_dark_before_they_arrive_calls_them_back() -> void:
	var r := Reprisal.new()
	check(r.send(7, Vector2(130, 90), 1000.0), "sent")
	r.call_off(7)
	eq(r.burning_now(1000.0 + Reprisal.MARCH_MINUTES + 1.0).size(), 0, "a dark yard ends it: nothing burns")
	check(r.send(7, Vector2(130, 90), 2000.0), "and a yard lit again could send again")


func test_the_march_survives_a_save() -> void:
	var r := Reprisal.new()
	check(r.send(7, Vector2(130, 90), 1000.0), "sent")
	var back := Reprisal.new()
	back.load_from(JSON.parse_string(JSON.stringify(r.save())))
	eq(back.burning_now(1000.0 + Reprisal.MARCH_MINUTES).size(), 1, "the march comes back with the game")
