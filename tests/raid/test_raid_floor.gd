extends TestCase
## A WORKING DAY BEFORE MORE THAN A LOOK. However loud a new holding is, nothing
## past a survey is warned on it until it has stood 48_raids.FIRST_WARNING_AFTER:
## the time a player has to hear why from Rook and put the shutters up.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_new_holding_is_not_warned_of_a_raid_before_a_working_day() -> void:
	Sx.use_root("raid_floor")
	var g := Sx.game(tree, ["--seed=4", "--size=64", "--hour=10", "--held=axe_felling", "--holding=hut,plot,hearth"])
	await frames(3)
	var coast: Coast = Sx.system(g, "30_mobs").get("coast")
	coast.spawning = false
	coast.rounds = false
	g.player.sim.clear_mobs()
	var sys := Sx.system(g, "48_raids")
	var s: Settlement = Sx.system(g, "46_settlements").call("here")
	check(s != null and is_finite(s.founded_at), "it records when it went up")
	var past := []
	var on_warned := func(_id: int, stage: StringName) -> void:
		if stage != RaidStage.SURVEY:
			past.append(stage)
	Events.raid_warned.connect(on_warned)
	# Read, and at a probe's worth of attention from the first hour.
	s.attention = RaidStage.AT[1] + 0.02
	for hour in 11:
		(sys.call("book", s.id) as Dictionary)["last_read"] = g.clock.minutes
		sys.call("pass_now")
		g.clock.skip(60.0)
	eq(past.size(), 0, "nothing past a look in its first eleven hours")
	g.clock.skip(90.0)
	(sys.call("book", s.id) as Dictionary)["last_read"] = g.clock.minutes
	s.attention = maxf(s.attention, RaidStage.AT[1] + 0.02)
	sys.call("pass_now")
	check(not past.is_empty(), "and the probe is warned once it has stood a working day (%s)" % [past])
	Events.raid_warned.disconnect(on_warned)
	Sx.end(g)
	Sx.finish()


func test_a_holding_staged_as_already_read_has_stood_that_long() -> void:
	Sx.use_root("raid_floor")
	var g := Sx.game(tree, ["--seed=4", "--size=64", "--hour=10", "--held=axe_felling", "--holding=hut,plot,hearth", "--attention=0.5"])
	await frames(3)
	var s: Settlement = Sx.system(g, "46_settlements").call("here")
	lt(s.founded_at, g.clock.minutes - _floor_minutes(), "a tour's --attention stands it past the floor")
	Sx.end(g)
	Sx.finish()


func _floor_minutes() -> float:
	return float((load("res://src/systems/48_raids.gd") as GDScript).get_script_constant_map()["FIRST_WARNING_AFTER"]) - 1.0
