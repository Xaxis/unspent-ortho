extends TestCase
## THE PLATE PLAYER'S WALK TO ITS LURE IS NOT UNDONE BY A RISE
## (tests/fight/plate_reader.gd). Drawing a keeper out, it walks to the lure; a
## step up a bank two levels above the keeper is ground no blow passes from, and
## a reader fighting there steps straight back down. Walked at the lure across a
## rise, the two undid each other every frame: it stood in the keeper's row on
## the rise's lip, never reaching the lure, and the anvil's bites caught it
## there (seed 1's den, test_anvil_ways). A player drawing it out keeps going.

const F := preload("res://tests/fight/fixture.gd")
const PR := preload("res://tests/fight/plate_reader.gd")


func test_the_walk_to_the_lure_crosses_a_rise_and_keeps_going() -> void:
	var w := F.flat_world(64, Ground.ROCK, Country.COAST, 7)
	for y in 64:
		for x in 64:
			var i := y * 64 + x
			if x >= 34:
				w.ground[i] = Ground.SAND
			# The keeper's ground, a level below the player's.
			if x >= 12 and x <= 22 and y >= 24 and y <= 36:
				w.level[i] = 6
			# A rise straight between the player and the lure, two above the keeper.
			if x >= 28 and x <= 29 and y >= 29 and y <= 31:
				w.level[i] = 8
	var sim := F.make_sim(w, Vector2(26.5, 30.5))
	var def := Sentinels.by_id(&"anvil")
	var m := sim.add_mob(def.kind, Vector2(17.5, 30.5))
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 0)
	m.facing = (sim.hero.pos - m.pos).angle()
	m.aim = m.facing
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	# Facing it, as a player who has stirred it stands.
	sim.hero.facing = (m.pos - sim.hero.pos).angle()
	var r: Variant = PR.new(sim)
	r.keep_on = [Ground.SAND]
	r.lure = Vector2(38.5, 30.5)
	r.home = sim.hero.pos
	var start := sim.hero.pos.distance_to(r.lure)
	# Undone on the very next step and done again: the flip, not a turn or a dodge.
	var flips := 0
	var moves: Array[Vector2] = []
	for i in 90:
		r.act()
		moves.append(sim.hero.move)
		var n := moves.size()
		if n >= 3 and _back(moves[n - 3], moves[n - 2]) and _back(moves[n - 2], moves[n - 1]):
			flips += 1
		sim.slices(2)
	var gained := start - sim.hero.pos.distance_to(r.lure)
	lt(float(flips), 2.0, "its walk is never undone and redone step on step (%d flips)" % flips)
	gt(gained, 3.0, "and it gets on toward the lure (%.1f tiles of %.1f)" % [gained, start])


func _back(a: Vector2, b: Vector2) -> bool:
	return a.length() > 0.5 and b.length() > 0.5 and a.normalized().dot(b.normalized()) < -0.5
