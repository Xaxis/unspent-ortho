extends TestCase
## GLARE IS SOMETHING TO USE (the lands builder's weather audit). A hard white
## sky thrown back off the ground blinds a lens as it blinds an eye, so a
## crouched player crossing open ground at noon under glare gets a real stretch
## closer to a runner (whose eye finds a crouched body before its ear does)
## than on a clear noon. At
## Weather.SIGHT_CUT glare 0.10 the gain was under a tile, which is a number, not
## a play; the bout below is what 0.25 buys.

const F := preload("res://tests/fight/fixture.gd")


func _noticed_at(kind: StringName) -> float:
	var sim := F.make_sim(F.flat_world(96), Vector2(18.5, 48.5))
	sim.moment.minutes = 12.0 * 60.0
	sim.moment.weather = kind
	sim.moment.weather_strength = 1.0 if kind != &"clear" else 0.0
	sim.moment.crouched = true
	sim.moment.loudness = StealthNoise.CROUCH_BODY
	var m := F.still(sim, &"runner", Vector2(48.5, 48.5), PI)
	m.calm_until = 0.0
	sim.hero.move = Vector2(1, 0)
	var t := 0.0
	while t < 40000.0:
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type in [&"noticed", &"heard", &"alerted"] and e.get("mob") == m:
				return m.pos.distance_to(sim.hero.pos)
	return 0.0


func test_glare_lets_a_crouched_player_close_on_a_runner() -> void:
	var clear := _noticed_at(&"clear")
	var glare := _noticed_at(&"glare")
	print("  info a runner notices a crouched player at noon %.1f tiles off in the clear, %.1f under glare" % [clear, glare])
	gt(clear, 0.0, "in the clear it sees the player")
	lt(glare, clear - 1.2, "under glare the player closes more than a tile further")
