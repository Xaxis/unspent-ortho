extends TestCase
## THE MACHINES WILL NOT FOLLOW (docs/HUSH.md H1). A crags ring (HushSites) and
## HUSH_PAD round it is a place no machine steps into: one chasing the player
## who goes in stops at its edge, turns to face in, and holds there without a
## blow, for as long as the player stays in it, until dawn. Out of the ring,
## out of its sight and past its forget, it goes home. A feral is not afraid.

const F := preload("res://tests/fight/fixture.gd")

const CENTRE := Vector2(30.3, 30.7)
const RADIUS := 3.7


## A crags field with one ring of eight stones round CENTRE, each facing it.
func _sim(at: Vector2) -> FightSim:
	var w := F.flat_world(96, Ground.MOSS, BiomeRegistry.index_of(&"the_crags"), 2)
	for k in 8:
		var q := CENTRE + Vector2.from_angle(float(k) / 8.0 * TAU) * RADIUS
		w.add_prop(WorldProp.new(w.next_id(), PropKind.STANDING_STONE, q, (CENTRE - q).angle(), 0.6))
	return F.make_sim(w, at)


func _edge() -> float:
	return RADIUS + FightSim.HUSH_PAD


## Runs the sim `ms` with the hero standing still; returns the nearest any mob in
## `watch` came to the centre, and counts hurts into `hurts`.
func _run(sim: FightSim, ms: float, watch: MobState, hurts: Array) -> float:
	var nearest := INF
	var t := 0.0
	while t < ms:
		sim.slices(2)
		t += 2.0 * FightRules.SLICE_MS
		nearest = minf(nearest, watch.pos.distance_to(CENTRE))
		for e in sim.drain():
			if e.type == &"hurt":
				hurts.append(e)
	return nearest


func test_a_machine_holds_at_the_edge_and_never_comes_in() -> void:
	var sim := _sim(CENTRE)
	var m := sim.add_mob(&"runner", CENTRE + Vector2(12.0, 0.0))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	var hurts: Array = []
	# A holding's gates are set every step by 46_settlements, replacing the list
	# of them: the rings must stand whatever is written there.
	sim.mob_walls = [Vector3(80.0, 80.0, 1.0)] as Array[Vector3]
	var nearest := _run(sim, 8000.0, m, hurts)
	gt(nearest, _edge() + m.radius * 0.5, "it never crosses the ring's edge (came to %.2f of %.2f)" % [nearest, _edge()])
	eq(m.mood, MobState.HOLDING, "it holds")
	lt(m.pos.distance_to(CENTRE), _edge() + 2.5, "at the edge, not off somewhere")
	lt(absf(wrapf(m.facing - (CENTRE - m.pos).angle(), -PI, PI)), 0.35, "facing in")
	eq(hurts.size(), 0, "and it throws nothing into the ring")


func test_a_feral_is_not_afraid() -> void:
	var sim := _sim(CENTRE)
	var d := sim.add_mob(&"dog.feral", CENTRE + Vector2(12.0, 0.0))
	d.set_mood(MobState.CHASING, sim.now)
	var nearest := _run(sim, 8000.0, d, [])
	lt(nearest, RADIUS, "a feral comes in after you")


func test_the_standoff_ends_at_dawn_and_they_go_home() -> void:
	var sim := _sim(CENTRE)
	sim.moment.minutes = 23.0 * 60.0
	var m := sim.add_mob(&"runner", CENTRE + Vector2(12.0, 0.0))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	_run(sim, 6000.0, m, [])
	eq(m.mood, MobState.HOLDING, "it holds through the night")
	sim.moment.minutes = 24.0 * 60.0 + FightSim.HUSH_DAWN_HOUR * 60.0 + 1.0
	_run(sim, 1000.0, m, [])
	check(m.mood == MobState.FLEEING and m.flee_home, "at dawn it gives up and goes home")


## Out of the ring and out of its sight past its forget, it goes home; a
## machine at its work never reads the player inside a ring at all.
func test_senses_read_the_ring_as_nothing() -> void:
	var sim := _sim(CENTRE)
	var m := F.still(sim, &"runner", CENTRE + Vector2(7.0, 0.0), PI)
	m.calm_until = 0.0
	_run(sim, 4000.0, m, [])
	check(m.mood == MobState.IDLE or m.mood == MobState.WORKING, "a machine at its work never has the player inside a ring")
	eq(m.suspicion, 0.0, "not even a doubt")


## THE BOUT: hunted across the crags, a runner five tiles behind, the player
## runs for the ring and stands in it through the night. Held at the edge, it
## takes nothing off them; at dawn it goes home. The same run with the stones
## gone (no ring): the runner has them.
func _hunted(stones: bool) -> Dictionary:
	var start := CENTRE + Vector2(-12.0, 0.0)
	var sim := _sim(start) if stones else F.make_sim(F.flat_world(96, Ground.MOSS, BiomeRegistry.index_of(&"the_crags"), 2), start)
	sim.moment.minutes = 22.0 * 60.0
	var m := sim.add_mob(&"runner", start + Vector2(-5.0, 0.0))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	var lost := 0
	var t := 0.0
	while t < 40000.0:
		var to := CENTRE - sim.hero.pos
		sim.hero.move = to.normalized() if to.length() > 0.5 else Vector2.ZERO
		sim.hero.run = to.length() > 0.5
		sim.slices(2)
		t += 2.0 * FightRules.SLICE_MS
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
	sim.moment.minutes = 30.0 * 60.0 + 1.0
	F.ms(sim, 500.0)
	return {"lost": lost, "home": m.mood == MobState.FLEEING and m.flee_home}


func test_hunted_into_a_ring_the_night_is_survived() -> void:
	var ring := _hunted(true)
	var open := _hunted(false)
	print("  info hunted into a ring: lost %d health in 40 s; with no ring: lost %d" % [ring.lost, open.lost])
	eq(ring.lost, 0, "held at the edge, it takes nothing off the player")
	check(ring.home, "and at dawn it goes home")
	gt(float(open.lost), 0.0, "with no ring the runner has them")
