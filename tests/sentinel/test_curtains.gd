extends TestCase
## IT SEALS THE WAY BEHIND YOU (a row that `seals`, the Limestone Caves'
## drip-warden; FightSim.curtains). A gap the player passes while it hunts them
## is sprayed shut behind them after a tell it stands still for; the curtain
## stops the player and not the warden; two heavy blows break one; it keeps two
## standing and the oldest crumbles; and after its time a curtain falls.

const F := preload("res://tests/fight/fixture.gd")
const WARDEN := &"sentinel.limestone_caves"
## The gap between the stones, edge to edge.
const GAP := 1.5


## A world with pairs of standing boulders across the row y = 20.5, one pair at
## each x in `xs`, `GAP` apart edge to edge; the player at (26.5, 20.5).
static func _gaps(xs: Array) -> FightSim:
	var w := F.flat_world(64)
	var id := 9000
	for x: float in xs:
		for side: float in [-1.0, 1.0]:
			id += 1
			var p := WorldProp.new(id, PropKind.BOULDER, Vector2(x, 20.5), 0.0, 1.0)
			p.pos = Vector2(x, 20.5 + side * (p.solid + GAP * 0.5))
			w.add_prop(p)
	var sim := F.make_sim(w, Vector2(26.5, 20.5))
	sim.hero.wind = sim.hero.max_wind
	return sim


## A warden at `at`, roused and after the player.
static func _warden(sim: FightSim, at: Vector2) -> MobState:
	var m := sim.add_mob(WARDEN, at)
	m.disturbed = true
	m.calm_until = 0.0
	m.set_mood(MobState.CHASING, sim.now)
	return m


static func _walk(sim: FightSim, dir: Vector2, ms: float) -> void:
	sim.hero.move = dir
	F.ms(sim, ms)
	sim.hero.move = Vector2.ZERO


func test_a_gap_passed_while_it_hunts_is_shut_behind_you_after_its_tell() -> void:
	var sim := _gaps([30.5])
	var m := _warden(sim, Vector2(14.5, 20.5))
	sim.drain()
	_walk(sim, Vector2.RIGHT, 1600)
	var ev := sim.drain()
	eq(F.count(ev, &"curtain_tell"), 1, "passing the gap starts its tell")
	gt(sim.hero.pos.x, 31.5, "the player went through (%.2f)" % sim.hero.pos.x)
	# It stands for the tell: where it was when the tell began, it still is.
	var at := m.pos
	F.ms(sim, 700)
	lt(m.pos.distance_to(at), 0.05, "it stands still for its tell (moved %.2f)" % m.pos.distance_to(at))
	F.ms(sim, 900)
	ev = sim.drain()
	eq(F.count(ev, &"curtain_up"), 1, "and then the curtain stands")
	# Walked back into it, the player is held on the far side.
	_walk(sim, Vector2.LEFT, 1500)
	gt(sim.hero.pos.x, 30.5, "the curtain stops the player going back (%.2f)" % sim.hero.pos.x)


func test_the_warden_walks_through_its_own_curtain() -> void:
	var sim := _gaps([30.5])
	var m := _warden(sim, Vector2(20.5, 20.5))
	_walk(sim, Vector2.RIGHT, 1600)
	F.ms(sim, 1600)
	eq(sim.curtains.size(), 1, "a curtain stands")
	check(bool(sim.curtains[0].up), "and is up")
	# Stood at the gap's near side, with the player beyond it.
	sim.hero.pos = Vector2(36.5, 20.5)
	m.pos = Vector2(28.8, 20.5)
	m.set_mood(MobState.CHASING, sim.now)
	F.ms(sim, 2500)
	gt(m.pos.x, 31.5, "it comes on through the curtain (%.2f)" % m.pos.x)


func test_two_heavy_blows_break_a_curtain() -> void:
	var sim := _gaps([30.5])
	_warden(sim, Vector2(14.5, 20.5))
	_walk(sim, Vector2.RIGHT, 1600)
	F.ms(sim, 1600)
	sim.drain()
	eq(sim.curtains.size(), 1, "a curtain stands")
	var c: Dictionary = sim.curtains[0]
	sim.hero.pos = (c.at as Vector2) + Vector2(1.0, 0.0)
	sim.hero.facing = PI
	sim.hero.wind = sim.hero.max_wind
	sim.press_heavy(PI)
	F.ms(sim, 1400)
	var ev := sim.drain()
	eq(F.count(ev, &"curtain_cracked"), 1, "the first heavy blow cracks it")
	eq(sim.curtains.size(), 1, "and it still stands")
	sim.hero.wind = sim.hero.max_wind
	sim.press_heavy(PI)
	F.ms(sim, 1400)
	ev = sim.drain()
	var down := F.first(ev, &"curtain_down")
	check(bool(down.get("broken", false)), "the second breaks it")
	eq(sim.curtains.size(), 0, "and it is gone")
	# A light blow does nothing to one.
	var sim2 := _gaps([30.5])
	_warden(sim2, Vector2(14.5, 20.5))
	_walk(sim2, Vector2.RIGHT, 1600)
	F.ms(sim2, 1600)
	sim2.drain()
	var c2: Dictionary = sim2.curtains[0]
	sim2.hero.pos = (c2.at as Vector2) + Vector2(1.0, 0.0)
	sim2.hero.facing = PI
	for i in 3:
		sim2.press_swing(PI)
		F.ms(sim2, 900)
	eq(F.count(sim2.drain(), &"curtain_cracked"), 0, "light blows do not crack it")


func test_it_keeps_two_standing_and_the_oldest_crumbles() -> void:
	var sim := _gaps([30.5, 38.5, 46.5])
	# Close behind, and kept within its senses as they go (a walk outpaces it and
	# it would lose them): what this asks is how many it keeps, not its ears.
	var m := _warden(sim, Vector2(23.5, 20.5))
	sim.drain()
	var ev: Array[Dictionary] = []
	for x: float in [34.5, 42.5, 50.5]:
		while sim.hero.pos.x < x:
			_walk(sim, Vector2.RIGHT, 100)
			m.pos = Vector2(maxf(m.pos.x, sim.hero.pos.x - 6.0), m.pos.y)
			m.last_seen = sim.hero.pos
			if m.mood != MobState.CHASING and m.mood != MobState.ATTACKING:
				m.set_mood(MobState.CHASING, sim.now)
		ev.append_array(sim.drain())
	F.ms(sim, 1600)
	ev.append_array(sim.drain())
	eq(F.count(ev, &"curtain_up"), 3, "three gaps passed, three curtains raised")
	var up := 0
	for c: Dictionary in sim.curtains:
		up += int(bool(c.up))
	eq(up, 2, "two stand at once")
	var down := F.first(ev, &"curtain_down")
	check(not down.is_empty() and not bool(down.broken), "the oldest crumbled")
	lt((down.get("at", Vector2.ZERO) as Vector2).distance_to(Vector2(30.5, 20.5)), 0.5, "and it was the first")


func test_a_curtain_falls_after_its_time() -> void:
	var sim := _gaps([30.5])
	var m := _warden(sim, Vector2(14.5, 20.5))
	_walk(sim, Vector2.RIGHT, 1600)
	F.ms(sim, 1600)
	eq(sim.curtains.size(), 1, "a curtain stands")
	# It stands its time whether its warden is about or not: taken off here, so
	# the fight it would make does not end the test.
	sim.remove_mob(m)
	sim.drain()
	# It tells before it goes: the crumble, a moment before the way opens.
	F.ms(sim, 22800)
	var ev := sim.drain()
	eq(F.count(ev, &"curtain_crumbling"), 0, "no crumble while it has time")
	eq(F.count(ev, &"curtain_down"), 0, "and it stands")
	F.ms(sim, 1200)
	ev = sim.drain()
	eq(F.count(ev, &"curtain_crumbling"), 1, "it crumbles a moment before its time is up")
	eq(F.count(ev, &"curtain_down"), 0, "still standing as it crumbles")
	F.ms(sim, 1500)
	eq(F.count(sim.drain(), &"curtain_down"), 1, "and falls after its time")
	eq(sim.curtains.size(), 0, "and is gone")


func test_no_curtain_from_a_calm_warden_or_a_keeper_that_does_not_seal() -> void:
	var sim := _gaps([30.5])
	var st := F.still(sim, WARDEN, Vector2(14.5, 20.5), 0.0)
	sim.drain()
	_walk(sim, Vector2.RIGHT, 1600)
	check(not sim.hunting(st), "a keeper that never had the player is not hunting them")
	eq(F.count(sim.drain(), &"curtain_tell"), 0, "a warden at its work does not seal")
	var sim2 := _gaps([30.5])
	var other := sim2.add_mob(&"sentinel.salt", Vector2(14.5, 20.5))
	other.disturbed = true
	other.set_mood(MobState.CHASING, sim2.now)
	sim2.drain()
	_walk(sim2, Vector2.RIGHT, 1600)
	eq(F.count(sim2.drain(), &"curtain_tell"), 0, "a keeper whose row does not seal does not")
