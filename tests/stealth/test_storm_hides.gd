extends TestCase
## STORMS THAT HIDE YOU (the lands builder's weather audit): rain, storm,
## blizzard and blown dust mask a body's noise, so a machine hears a player less
## far in them, by the weather's family and strength (Weather.HEARING_CUT), and
## an approach heard far off in the clear gets close in a storm. Fog,
## heat and a clear sky hide no sound.

const F := preload("res://tests/fight/fixture.gd")


func _moment(kind: StringName, strength: float) -> Moment:
	var m := Moment.new()
	m.minutes = 23.0 * 60.0
	m.weather = kind
	m.weather_strength = strength
	return m


func test_a_storm_cuts_how_far_a_machine_hears_you() -> void:
	var row := Roster.row(&"runner")
	var clear := StealthQuery.hearing_range(row, _moment(&"clear", 0.0))
	gt(clear, 0.0, "a runner hears a walking player in the clear")
	for kind: StringName in [&"rain", &"storm", &"blizzard", &"dust", &"whiteout", &"dry_storm"]:
		lt(StealthQuery.hearing_range(row, _moment(kind, 1.0)), clear, "%s masks the player's noise" % kind)
	near(StealthQuery.hearing_range(row, _moment(&"fog", 1.0)), clear, 1e-6, "fog hides no sound")
	lt(StealthQuery.hearing_range(row, _moment(&"storm", 1.0)), StealthQuery.hearing_range(row, _moment(&"storm", 0.3)),
		"a full storm hides more than a passing one")
	lt(StealthQuery.hearing_range(row, _moment(&"storm", 1.0)), StealthQuery.hearing_range(row, _moment(&"rain", 1.0)),
		"a storm more than rain")


## How far off a runner notices a player walking straight at it at night, when
## its ear is what finds them, in `kind` at full strength: the tiles between
## them when it first knows.
func _noticed_at(kind: StringName) -> float:
	var sim := F.make_sim(F.flat_world(96), Vector2(18.5, 48.5))
	sim.moment.minutes = 23.0 * 60.0
	sim.moment.weather = kind
	sim.moment.weather_strength = 1.0
	var m := F.still(sim, &"runner", Vector2(48.5, 48.5), PI)
	m.calm_until = 0.0
	sim.hero.move = Vector2(1, 0)
	var t := 0.0
	while t < 20000.0:
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type in [&"noticed", &"heard", &"alerted"] and e.get("mob") == m:
				return m.pos.distance_to(sim.hero.pos)
	return 0.0


func test_an_approach_gets_closer_in_a_storm() -> void:
	var clear := _noticed_at(&"clear")
	var storm := _noticed_at(&"storm")
	print("  info a walking player noticed by a runner at night: %.1f tiles off in the clear, %.1f in a storm" % [clear, storm])
	gt(clear, 0.0, "in the clear it notices the player")
	lt(storm, clear - 1.0, "in a storm the player gets more than a tile closer")
