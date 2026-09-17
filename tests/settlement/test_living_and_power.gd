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
