extends TestCase
## ATTACK SLOTS (FightSim.attack_slots): a crowd is a fight, not a wall. At most
## ATTACK_SLOTS biters commit to the player at once; the rest wait at the edge,
## circling and feinting where the player can see them, and swap in when a slot
## frees or the player turns their back on them.
##
## A body is COMMITTED while it is after the player (chasing or attacking) and
## attacking, running a charge, or in a blow.

const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")


static func committed(m: MobState, now: float) -> bool:
	if not m.alive or m.removed or not (m.mood == MobState.CHASING or m.mood == MobState.ATTACKING):
		return false
	return m.mood == MobState.ATTACKING or m.charging or (m.blow != null and m.blow_phase(now) != &"")


## A crowd of `kinds` five tiles off, roused, the shoulder reader with a knife.
## The most committed at once, how many beats a waiter stood off, and whether the
## bout was won.
func _bout(kinds: Array[StringName], start: int, seconds: float = 30.0) -> Dictionary:
	MobState._next_id = 1000
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	var a := float(start) / 8.0 * TAU
	var mid := sim.hero.pos + Vector2.from_angle(a) * 5.0
	var side := Vector2.from_angle(a).orthogonal()
	var crowd: Array[MobState] = []
	for k in kinds.size():
		var m := sim.add_mob(kinds[k], mid + side * (float(k) - 0.5 * float(kinds.size() - 1)) * 1.1)
		m.facing = (sim.hero.pos - m.pos).angle()
		m.aim = m.facing
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		crowd.append(m)
	var player := SR.new(sim)
	sim.hero.facing = (mid - sim.hero.pos).angle()
	var most := 0
	var t := 0.0
	var won := false
	while t < seconds * 1000.0:
		player.act()
		sim.slices(2)
		t += 16.0
		var n := 0
		for m in crowd:
			n += int(committed(m, sim.now))
		most = maxi(most, n)
		var left := 0
		for m in crowd:
			left += int(m.alive)
		if left == 0:
			won = true
			break
		if sim.last_outcome in [&"downed", &"carried"]:
			break
	return {"most": most, "won": won}


func test_three_cutters_never_commit_more_than_two() -> void:
	var cutters: Array[StringName] = [&"cutter", &"cutter", &"cutter"]
	var worst := 0
	for s in 8:
		var r := _bout(cutters, s)
		worst = maxi(worst, int(r.most))
	print("  info three cutters on a knife, 8 starts: at most %d committed at once" % worst)
	check(worst <= FightSim.ATTACK_SLOTS, "never more than %d committed (%d)" % [FightSim.ATTACK_SLOTS, worst])
	eq(FightSim.ATTACK_SLOTS, 2, "two slots")


func test_a_mixed_crowd_never_commits_more_than_two() -> void:
	var crowd: Array[StringName] = [&"harvester", &"harvester", &"harvester", &"cutter", &"cutter"]
	var worst := 0
	for s in 8:
		worst = maxi(worst, int(_bout(crowd, s).most))
	print("  info three harvesters and two cutters, 8 starts: at most %d committed at once" % worst)
	check(worst <= FightSim.ATTACK_SLOTS, "never more than two committed (%d)" % worst)


## A waiter stands off at the edge, facing the player, and does not bite.
func test_a_waiter_waits_at_the_edge_facing_you() -> void:
	MobState._next_id = 1000
	var sim := F.make_sim(F.flat_world(64), Vector2(30.5, 30.5))
	var crowd: Array[MobState] = []
	for k in 3:
		var m := sim.add_mob(&"cutter", sim.hero.pos + Vector2.from_angle(float(k) * TAU / 3.0) * 4.0)
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		crowd.append(m)
	var bites := {}
	for i in 180:
		F.ms(sim, 16)
		for e in sim.drain():
			if e.type == &"windup" and e.get("mob") != null:
				bites[(e.mob as MobState).id] = true
	var waiters := 0
	for m in crowd:
		if not sim.holds_slot(m):
			waiters += 1
			var d := m.pos.distance_to(sim.hero.pos)
			gt(d, Brains.strike_range(m, sim), "a waiter stands outside its strike (%.2f)" % d)
			lt(d, Brains.strike_range(m, sim) + FightSim.WAIT_GAP + 1.5, "and not far off (%.2f)" % d)
			lt(absf(wrapf((sim.hero.pos - m.pos).angle() - m.facing, -PI, PI)), 0.6, "facing the player")
	eq(waiters, 1, "one of three waits")
	lt(float(bites.size()), 2.5, "only the two in their slots told a bite")
