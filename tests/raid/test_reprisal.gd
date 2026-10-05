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
		eq(due[0].roof, Vector2(130, 90), "that one")
		eq(due[0].kind, Reprisal.ROOF, "a village's roof")
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


## Out on the road, where a player can meet them: from the yard at the start,
## halfway at half the march, at the roof when it is due; and the save keeps it.
func test_the_party_walks_the_road_from_the_yard_to_the_roof() -> void:
	var r := Reprisal.new()
	eq(r.on_road(7, 1000.0), Vector2.INF, "nobody on the road before a housing is broken")
	check(r.send(7, Vector2(200, 100), 1000.0, Vector2(100, 100)), "sent")
	eq(r.on_road(7, 1000.0), Vector2(100, 100), "they set out from the yard")
	var half := r.on_road(7, 1000.0 + Reprisal.MARCH_MINUTES * 0.5)
	lt(half.distance_to(Vector2(150, 100)), 0.01, "halfway at half the march")
	eq(r.on_road(7, 1000.0 + Reprisal.MARCH_MINUTES), Vector2(200, 100), "at the roof when it is due")
	var back := Reprisal.new()
	back.load_from(JSON.parse_string(JSON.stringify(r.save())))
	lt(back.on_road(7, 1000.0 + Reprisal.MARCH_MINUTES * 0.5).distance_to(Vector2(150, 100)), 0.01, "and the road comes back with the game")


## A ROOF PAST REACH IS FARTHER TO WALK: the march keeps the pace it keeps inside
## REACH, so the player has the same window per tile of road. A roof 300 off takes
## twice the march, the party is halfway at half of it, and the save keeps it.
func test_a_far_roof_takes_a_longer_march_at_the_same_pace() -> void:
	var r := Reprisal.new()
	var yard := Vector2(100, 100)
	var roof := yard + Vector2(Reprisal.REACH * 2.0, 0)
	eq(Reprisal.march_minutes(yard, yard + Vector2(40, 0)), Reprisal.MARCH_MINUTES, "a roof in reach is the march it always was")
	eq(Reprisal.march_minutes(yard, roof), Reprisal.MARCH_MINUTES * 2.0, "twice the reach, twice the march")
	check(r.send(7, roof, 1000.0, yard), "sent")
	eq(r.burning_now(1000.0 + Reprisal.MARCH_MINUTES * 2.0 - 1.0).size(), 0, "not burned when a march in reach would be done")
	lt(r.on_road(7, 1000.0 + Reprisal.MARCH_MINUTES).distance_to(yard.lerp(roof, 0.5)), 0.01, "halfway at half the long march")
	var back := Reprisal.new()
	back.load_from(JSON.parse_string(JSON.stringify(r.save())))
	lt(back.on_road(7, 1000.0 + Reprisal.MARCH_MINUTES).distance_to(yard.lerp(roof, 0.5)), 0.01, "and the long road comes back with the game")
	eq(back.burning_now(1000.0 + Reprisal.MARCH_MINUTES * 2.0).size(), 1, "the roof burns when the long march is done")


## WHAT THEY WERE SENT FOR: his own camp or holding where no roof was left, and
## nothing at all where he has neither (48_raids `_target_for`). The kind rides
## the march, comes back with a save, and nobody is sent for NONE.
func test_the_march_knows_what_it_was_sent_for() -> void:
	var r := Reprisal.new()
	eq(r.kind_of(7), Reprisal.NONE, "nobody on the road, nothing sent for")
	check(not r.send(9, Vector2(10, 10), 1000.0, Vector2(0, 0), Reprisal.NONE), "for nothing, nobody is sent")
	check(r.send(7, Vector2(130, 90), 1000.0, Vector2(100, 90), Reprisal.HOLDING), "sent for his holding")
	eq(r.kind_of(7), Reprisal.HOLDING, "and the march knows it")
	var back := Reprisal.new()
	back.load_from(JSON.parse_string(JSON.stringify(r.save())))
	eq(back.kind_of(7), Reprisal.HOLDING, "and so does the march that comes back with the game")
	var due := back.burning_now(1000.0 + Reprisal.MARCH_MINUTES)
	eq(due.size(), 1, "and it arrives")
	if due.size() == 1:
		eq(due[0].kind, Reprisal.HOLDING, "at his holding")


## THE GLASS NAMES WHAT THEY WERE SENT FOR: every march a broken yard can send
## has its own words for each thing it can come to, and his camp and holding
## are never told in a village's words.
func test_every_kind_of_march_has_its_own_words() -> void:
	for kind: StringName in [Reprisal.ROOF, Reprisal.CAMP, Reprisal.HOLDING]:
		for event: StringName in [&"sent", &"called_back", &"met", &"burned"]:
			var line := StoryContent.reprisal_says(event, kind)
			check(line != "", "a march for his %s says when it is %s" % [kind, event])
			if kind != Reprisal.ROOF:
				check(line != StoryContent.REPRISAL[event], "in its own words, not a village's (%s, %s)" % [kind, event])
