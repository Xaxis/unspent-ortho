extends TestCase
## SOMEBODY CARRIED OFF A HOLDING IS REMEMBERED, wherever it stands. A raid takes
## a person through 48_raids `_take_person` (the live snatcher and the paper
## settle both), which files them at the depot of the region whose network took
## them. About one standable tile in eleven near the home coast's spawn is in no
## region at all (measured, seed 1 full size): a holding there lost its people
## with no record, and nobody can be rescued who is not on one.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_holding_in_no_region_still_files_who_it_loses() -> void:
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	await frames(3)
	var sp: Vector2 = g.world.spawn
	var spot := Vector2.INF
	for dy in range(-60, 61, 3):
		for dx in range(-60, 61, 3):
			var x := floori(sp.x) + dx
			var y := floori(sp.y) + dy
			if spot.is_finite() or not g.world.in_bounds(x, y) or not g.query.standable(x, y):
				continue
			if g.world.region_at(x, y) < 0:
				spot = Vector2(x + 0.5, y + 0.5)
	check(spot.is_finite(), "there is standable ground in no region near the spawn")
	if not spot.is_finite():
		Sx.end(g)
		return
	var h := g.get_node("46_settlements")
	var s: Settlement = h.call("found", g.world.realm, spot)
	@warning_ignore("return_value_discarded")
	h.call("place_piece", s, StructureKind.HUT, spot, 0.0)
	var who := s.take_person_id()
	s.people.append(who)
	var taken: Taken = g.get_node("45_taken").get("taken")
	g.get_node("48_raids").call("_take_person", s, who)
	eq(s.people.size(), 0, "they are carried off the holding")
	eq(taken.people.size(), 1, "and filed, so there is somebody to go and get back")
	if taken.people.size() == 1:
		check(taken.people[0].region >= 0, "held in a region, at a depot a player can walk to")
		eq(taken.people[0].home_name, s.name, "out of this holding")
	Sx.end(g)
