extends TestCase
## The two holes the settlement package was shipped with, and the rules that
## close them.
##
## **The LIVING family was empty and `sleeps` was a lie.** `Settlement.beds()`
## was written, documented and called by NOBODY, so a holding took in one
## resident per job it had and housed them in the open — while the build card on
## the slate printed "sleeps 2" under a hut. A number a player is shown and can
## act on has to decide something, so `beds()` is now the cap, and the piece
## whose whole job is beds has a row.
##
## **There was one generator.** The wind spinner was the only power in the game,
## which is why a bug in how the wind was read cost half of all power rather than
## a third — and `SettlementRules.source` had carried the solar array's day curve
## and its weather dimming the whole time, unreachable, because the kind had no
## row for anybody to build.

const Sx := preload("res://tests/save/save_fixture.gd")


static func _holdings(g: Game) -> Node:
	return Sx.system(g, "46_settlements")


# --- the living family ------------------------------------------------------

func test_every_family_has_something_a_player_can_build_in_it() -> void:
	var families: Array[int] = [StructureKind.Family.SHELTER, StructureKind.Family.POWER,
		StructureKind.Family.FOOD, StructureKind.Family.WORK,
		StructureKind.Family.DEFENCE, StructureKind.Family.LIVING]
	for f: int in families:
		var n := 0
		for k: int in StructureKind.BUILDABLE:
			if StructureKind.family(k) == f:
				n += 1
		gt(float(n), 0.0, "family %d has nothing in it, so the slate offers a heading with no rows" % f)


func test_a_piece_a_player_can_choose_always_has_a_row() -> void:
	for k: int in StructureKind.BUILDABLE:
		check(not StructureKind.row(k).is_empty(),
			"%s is offered on the slate and has no row" % StructureKind.display_name(k))


func test_a_bunk_is_what_raises_the_cap_past_the_players_own_roof() -> void:
	var s := Settlement.new()
	eq(s.beds(), 0, "nothing built, nowhere to sleep")
	@warning_ignore("return_value_discarded")
	s.add(StructureKind.LEAN_TO, Vector2.ZERO)
	eq(s.beds(), StructureKind.sleeps(StructureKind.LEAN_TO), "a lean-to is one bed")
	@warning_ignore("return_value_discarded")
	s.add(StructureKind.BUNK, Vector2(2, 0))
	eq(s.beds(), StructureKind.sleeps(StructureKind.LEAN_TO) + StructureKind.sleeps(StructureKind.BUNK),
		"and a bunk adds its own")
	gt(float(StructureKind.sleeps(StructureKind.BUNK)), float(StructureKind.sleeps(StructureKind.HUT)),
		"a bunk sleeps more than the household piece, or it is not worth building")


## The rule as a player meets it: a plot with nobody to work it, and a bed is the
## answer. Run in a real game, because `_recruit` is the system's and so is the
## refusal the player reads.
func test_nobody_moves_in_where_there_is_nowhere_to_sleep() -> void:
	Sx.use_root("living")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10"])
	await frames(3)
	var h := _holdings(g)
	var s := Settlement.new()
	s.realm = g.world.realm
	s.centre = g.player.pos
	var plot := s.add(StructureKind.PLOT, g.player.pos + Vector2(2, 0))
	(h.get(&"places") as Array).append(s)
	eq(s.beds(), 0, "a plot is not a bed")
	var who := int(h.call("_staff", s, plot))
	eq(who, -1, "so nobody moves in to work it")
	eq(s.people.size(), 0, "and the holding houses nobody")
	# Put a roof over it and the same call lands.
	@warning_ignore("return_value_discarded")
	s.add(StructureKind.BUNK, g.player.pos + Vector2(0, 2))
	gt(float(s.beds()), 0.0, "now there are beds")
	var again := int(h.call("_staff", s, plot))
	gt(float(again), -1.0, "and somebody comes to work the plot")
	eq(s.people.size(), 1, "and lives there")
	Sx.end(g)


## Staging is documented as "free and staffed", and a shot or a tour that asks
## for one plot must get a working plot rather than a lesson about roofs. Every
## existing `--holding=` in the tests and tours leans on this.
func test_a_staged_holding_is_staffed_whatever_it_has_for_a_roof() -> void:
	Sx.use_root("living")
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=8", "--holding=plot,catchment,store"])
	await frames(3)
	var s: Settlement = _holdings(g).call("here")
	check(s != null, "the staged holding is there")
	eq(s.beds(), 0, "staged with no bed in it")
	gt(float(s.people.size()), 0.0, "and still staffed, because staging is a cheat by design")
	Sx.end(g)


## The hole the LIVING family was supposed to close, and the one a bunk alone
## does NOT: a holding out on its own could never be staffed, whatever it built.
##
## `_recruit` asked 35_folk for a body, and 35_folk only builds villagers within
## 34 tiles of the PLAYER — so the recruit reach was the streaming radius under
## another name, and the answer everywhere else was no. Measured on seeds 1/4/7,
## that is about a fifth of the standable island (the furthest tile from any
## village is 64, 71 and 77). Word to the nearest village is what answers it.
func test_a_holding_out_on_its_own_can_still_be_staffed() -> void:
	Sx.use_root("living")
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=10"])
	await frames(3)
	var h := _holdings(g)
	# Stand it where no villager will ever be built: further from every village
	# than 35_folk's own NEAR. Found by asking the world, never by a coordinate.
	var far := Vector2.INF
	var best := 0.0
	for ty: int in range(0, 256, 3):
		for tx: int in range(0, 256, 3):
			if Ground.is_water(g.world.ground_at(tx, ty)) or not g.query.standable(tx, ty):
				continue
			var p := Vector2(tx + 0.5, ty + 0.5)
			var d := INF
			for v: Dictionary in g.world.villages:
				d = minf(d, p.distance_to(v.pos as Vector2))
			if d > best:
				best = d
				far = p
	gt(best, 34.0, "seed 1 has ground further from a village than 35_folk will build a body")
	var s := Settlement.new()
	s.realm = g.world.realm
	s.centre = far
	(h.get(&"places") as Array).append(s)
	# Nothing of 35_folk is out there to ask.
	eq(int(h.call("_villager_near", s).size()), 0, "no villager body anywhere near it")
	# Without a bed it is still refused, so the bed stays the rule.
	var plot := s.add(StructureKind.PLOT, far + Vector2(2, 0))
	eq(int(h.call("_staff", s, plot)), -1, "and with no bed, still nobody")
	# With one, word goes to the nearest village and somebody walks out.
	@warning_ignore("return_value_discarded")
	s.add(StructureKind.BUNK, far + Vector2(0, 2))
	gt(float(int(h.call("_staff", s, plot))), -1.0,
		"a holding %0.0f tiles from the nearest village is staffed once it has a bed" % best)
	eq(s.people.size(), 1, "and somebody lives there")
	print("  staffed a holding %.0f tiles from the nearest village" % best)
	Sx.end(g)


## The far path is a fallback, not a replacement: next to a village it is still
## the body already walking about that comes over, so the village is seen to lose
## somebody rather than quietly gaining a twin.
func test_next_to_a_village_it_is_still_the_body_already_there() -> void:
	Sx.use_root("living")
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--folk=6"])
	await frames(6)
	var h := _holdings(g)
	var s := Settlement.new()
	s.realm = g.world.realm
	s.centre = g.player.pos
	(h.get(&"places") as Array).append(s)
	@warning_ignore("return_value_discarded")
	s.add(StructureKind.BUNK, g.player.pos + Vector2(0, 2))
	var plot := s.add(StructureKind.PLOT, g.player.pos + Vector2(2, 0))
	var body: Dictionary = h.call("_villager_near", s)
	if body.is_empty():
		print("  no villager within reach on this seed; the near path is untested here")
		Sx.end(g)
		return
	gt(float(int(h.call("_staff", s, plot))), -1.0, "somebody takes it on")
	eq(int(body.get("village", 0)), -3, "and it is that body, moved onto the holding's books")
	Sx.end(g)


# --- the second generator ---------------------------------------------------

func test_the_array_makes_power_by_day_and_none_at_night() -> void:
	var clear := {"kind": Weather.CLEAR, "strength": 0.0, "wind": 0.35}
	var noon := SettlementRules.source(StructureKind.SOLAR_ARRAY, clear, 12.0)
	var midnight := SettlementRules.source(StructureKind.SOLAR_ARRAY, clear, 0.0)
	gt(noon, 0.8, "an array at noon is near enough its whole output")
	near(midnight, 0.0, 1e-6, "and nothing at all in the dark")
	gt(noon, SettlementRules.source(StructureKind.SOLAR_ARRAY, clear, 7.0), "morning is less than noon")


func test_weather_dims_the_array_and_stillness_stops_the_spinner() -> void:
	var clear := {"kind": Weather.CLEAR, "strength": 0.0, "wind": 0.35}
	var storm := {"kind": Weather.RAIN, "strength": 1.0, "wind": 0.35}
	lt(SettlementRules.source(StructureKind.SOLAR_ARRAY, storm, 12.0),
		SettlementRules.source(StructureKind.SOLAR_ARRAY, clear, 12.0),
		"weather dims an array")
	var still := {"kind": Weather.CLEAR, "strength": 0.0, "wind": 0.0}
	near(SettlementRules.source(StructureKind.WIND_SPINNER, still, 12.0), 0.0, 1e-6,
		"and a still day stops a spinner")
	# The two fail on different days, which is the whole reason for having both.
	gt(SettlementRules.source(StructureKind.SOLAR_ARRAY, still, 12.0), 0.8,
		"the array does not care that the air is still")


## Over a whole day the two are worth about the same, so choosing between them is
## about WHEN the power arrives and not how much of it there is.
func test_the_two_generators_are_worth_about_the_same_over_a_day() -> void:
	var clear := {"kind": Weather.CLEAR, "strength": 0.0, "wind": 0.35}
	var sun := 0.0
	var wind := 0.0
	for step in 48:
		var hour := float(step) * 0.5
		sun += SettlementRules.source(StructureKind.SOLAR_ARRAY, clear, hour) \
			* StructureKind.makes_power(StructureKind.SOLAR_ARRAY)
		wind += SettlementRules.source(StructureKind.WIND_SPINNER, clear, hour) \
			* StructureKind.makes_power(StructureKind.WIND_SPINNER)
	print("  a day's power: array %.2f, spinner %.2f" % [sun, wind])
	var ratio := sun / maxf(wind, 0.001)
	check(ratio > 0.7 and ratio < 1.45,
		"one generator is %.2fx the other over a day; they are meant to differ in WHEN, not in how much" % ratio)
