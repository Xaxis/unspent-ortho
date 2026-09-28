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


## A body striking: a charger's run from the moment it commits, or any biter's
## blow from its tell through its strike.
static func striking(m: MobState, now: float) -> bool:
	if not m.alive or m.removed:
		return false
	return m.charging or m.blow_phase(now) in [&"windup", &"active"]


## A charge is a bite (FightSim.bite_turn): in three harvesters and two cutters,
## no charge ever runs while another body strikes.
func test_a_charge_never_overlaps_another_strike() -> void:
	var kinds: Array[StringName] = [&"harvester", &"harvester", &"harvester", &"cutter", &"cutter"]
	var overlaps := 0
	for start in 8:
		MobState._next_id = 1000
		var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
		sim.hero.inventory.add(&"knife")
		sim.hero.inventory.set_held(&"knife")
		var a := float(start) / 8.0 * TAU
		var mid := sim.hero.pos + Vector2.from_angle(a) * 5.0
		var side := Vector2.from_angle(a).orthogonal()
		var crowd: Array[MobState] = []
		for k in kinds.size():
			var m := sim.add_mob(kinds[k], mid + side * (float(k) - 2.0) * 1.1)
			m.facing = (sim.hero.pos - m.pos).angle()
			m.aim = m.facing
			m.disturbed = true
			m.set_mood(MobState.CHASING, sim.now)
			crowd.append(m)
		var player := SR.new(sim)
		sim.hero.facing = (mid - sim.hero.pos).angle()
		var t := 0.0
		while t < 30000.0 and not sim.last_outcome in [&"downed", &"carried"]:
			player.act()
			sim.slices(2)
			t += 16.0
			for m in crowd:
				if not m.charging or not striking(m, sim.now):
					continue
				for o in crowd:
					if o != m and striking(o, sim.now):
						overlaps += 1
	print("  info three harvesters and two cutters, 8 starts of 30 s: %d slices a charge ran over another strike" % overlaps)
	eq(overlaps, 0, "no charge runs while another body strikes")


## A charge is read at least as long as the cutter's tell: every roster charger's
## bite winds up no quicker than the cutter's.
func test_a_charge_is_told_no_quicker_than_a_cutters_bite() -> void:
	var cutter := int((Roster.row(&"cutter").bite as Dictionary).swing[0])
	for k in Roster.kinds():
		var r := Roster.row(k)
		if r.get("approach", &"") != &"charge" or not r.has("bite"):
			continue
		var w := int((r.bite as Dictionary).swing[0])
		check(w >= cutter, "%s winds up %d ms, the cutter %d" % [k, w, cutter])



## UNSEEN BITES (FightSim.UNSEEN_ARC): three cutters, and three harvesters with
## two cutters, on a knife, 8 starts of 30 s each. Every tell begun in a crowd,
## where its body stood off the player's facing, whether it came with the cue,
## and how long it was told; and the most unseen strikes on at once.
func _unseen_run() -> Dictionary:
	var tells: Array[Dictionary] = []
	var most := 0
	for kinds: Array in [[&"cutter", &"cutter", &"cutter"], [&"harvester", &"harvester", &"harvester", &"cutter", &"cutter"]]:
		for start in 8:
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
			var cued := {}
			var t := 0.0
			while t < 30000.0 and not sim.last_outcome in [&"downed", &"carried"]:
				player.act()
				for s in 2:
					var facing := sim.hero.facing
					var pos := sim.hero.pos
					var crowded := 0
					for o in crowd:
						crowded += int(o.alive and (o.mood == MobState.CHASING or o.mood == MobState.ATTACKING))
					sim.slices(1)
					var events := sim.drain()
					var cues := {}
					for e in events:
						if e.type == &"unseen_tell":
							cues[(e.mob as MobState).id] = true
							cued[(e.mob as MobState).id] = true
					for e in events:
						if e.type != &"windup" or not (e.get("mob") is MobState):
							continue
						var m := e.mob as MobState
						if crowded < 2 or not FightSim.biter(m):
							continue
						tells.append({"off": absf(wrapf((m.pos - pos).angle() - facing, -PI, PI)), "cued": cues.has(m.id),
							"windup": m.blow.windup, "row": m.bite.windup})
					var on := 0
					for o in crowd:
						if cued.has(o.id) and o.alive and (o.charging or o.blow_phase(sim.now) in [&"windup", &"active"]):
							on += 1
						elif cued.has(o.id):
							cued.erase(o.id)
					most = maxi(most, on)
				t += 16.0
	return {"tells": tells, "most": most}


func test_in_a_crowd_never_two_unseen_bites_at_once() -> void:
	var r := _unseen_run()
	var unseen := 0
	for t: Dictionary in r.tells:
		unseen += int(bool(t.cued))
	print("  info crowds: %d tells, %d of them unseen and cued; at most %d unseen on at once" % [r.tells.size(), unseen, r.most])
	gt(float(unseen), 3.0, "blows from behind are still thrown (%d)" % unseen)
	lt(float(r.most), 1.5, "never two unseen at once (%d)" % r.most)


func test_every_unseen_tell_is_cued_and_told_longer() -> void:
	var r := _unseen_run()
	var uncued := 0
	var short := 0
	for t: Dictionary in r.tells:
		if float(t.off) > FightSim.UNSEEN_ARC + 0.05 and not bool(t.cued):
			uncued += 1
		if bool(t.cued) and int(t.windup) < roundi(int(t.row) * FightSim.UNSEEN_TELL):
			short += 1
	print("  info crowds: %d tells begun out of sight without the cue, %d cued ones told short" % [uncued, short])
	eq(uncued, 0, "every tell begun out of the player's sight is cued")
	eq(short, 0, "and told %.1f times as long" % FightSim.UNSEEN_TELL)



## A crowd keeps its own (FightSim._mates_see): three harvesters and two cutters,
## the knife, 8 starts of 60 s. No body goes back to its work while another of
## the crowd is after the player and sees them.
func test_a_crowd_does_not_wander_off_its_own_fight() -> void:
	var kinds: Array[StringName] = [&"harvester", &"harvester", &"harvester", &"cutter", &"cutter"]
	var wandered := 0
	for start in 8:
		MobState._next_id = 1000
		var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
		sim.hero.inventory.add(&"knife")
		sim.hero.inventory.set_held(&"knife")
		var a := float(start) / 8.0 * TAU
		var mid := sim.hero.pos + Vector2.from_angle(a) * 5.0
		var side := Vector2.from_angle(a).orthogonal()
		var crowd: Array[MobState] = []
		for k in kinds.size():
			var m := sim.add_mob(kinds[k], mid + side * (float(k) - 2.0) * 1.1)
			m.facing = (sim.hero.pos - m.pos).angle()
			m.aim = m.facing
			m.disturbed = true
			m.set_mood(MobState.CHASING, sim.now)
			crowd.append(m)
		var player := SR.new(sim)
		sim.hero.facing = (mid - sim.hero.pos).angle()
		var was := {}
		var t := 0.0
		while t < 60000.0 and not sim.last_outcome in [&"downed", &"carried"]:
			player.act()
			sim.slices(2)
			t += 16.0
			for m in crowd:
				var after := m.alive and (m.mood == MobState.CHASING or m.mood == MobState.ATTACKING)
				var went := bool(was.get(m.id, true)) and m.alive and (m.mood == MobState.IDLE or m.mood == MobState.WORKING)
				was[m.id] = after
				if not went:
					continue
				for o in crowd:
					if o != m and o.alive and (o.mood == MobState.CHASING or o.mood == MobState.ATTACKING) and o.lost_beats == 0:
						wandered += 1
						break
	print("  info three harvesters and two cutters, 8 starts of 60 s: %d times a body went back to its work while its crowd still saw the player" % wandered)
	eq(wandered, 0, "none")



## A CROWD BREAKS (FightSim._crowd_falls): half-broken machines lose the fight
## when only one of them is left standing, or when the one body bigger than all
## the rest is taken first, and the rest go back to their rounds.
func _crowd(sim: FightSim, kinds: Array[StringName]) -> Array[MobState]:
	var out: Array[MobState] = []
	for k in kinds.size():
		var m := sim.add_mob(kinds[k], sim.hero.pos + Vector2(4.0, 0.0) + Vector2(0.0, 1.2) * (float(k) - 0.5 * float(kinds.size() - 1)))
		m.facing = PI
		m.aim = PI
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		out.append(m)
	return out


static func after(m: MobState) -> bool:
	return m.alive and (m.mood == MobState.CHASING or m.mood == MobState.ATTACKING)


func test_a_crowd_breaks_when_most_of_it_falls() -> void:
	MobState._next_id = 1000
	var sim := F.make_sim(F.flat_world(64), Vector2(30.5, 30.5))
	var kinds: Array[StringName] = [&"harvester", &"harvester", &"harvester", &"cutter", &"cutter"]
	var crowd := _crowd(sim, kinds)
	F.ms(sim, 200)
	sim._kill(crowd[3])
	F.ms(sim, 200)
	var still := 0
	for m in crowd:
		still += int(after(m))
	eq(still, 4, "one fallen: the rest fight on")
	sim._kill(crowd[4])
	F.ms(sim, 200)
	still = 0
	for m in crowd:
		still += int(after(m))
	eq(still, 3, "two of five fallen: the rest still fight")
	sim._kill(crowd[2])
	F.ms(sim, 200)
	still = 0
	for m in crowd:
		still += int(after(m))
	eq(still, 2, "three of five fallen: the two left still fight")
	sim._kill(crowd[1])
	F.ms(sim, 200)
	still = 0
	for m in crowd:
		still += int(after(m))
	eq(still, 0, "one left standing: it loses the fight")
	for m in crowd:
		if m.alive:
			check(not m.disturbed, "and go back to their rounds")
	F.ms(sim, 3000)
	still = 0
	for m in crowd:
		still += int(after(m))
	eq(still, 0, "and do not turn straight back on the player")


func test_a_crowd_breaks_when_its_leader_falls_first() -> void:
	MobState._next_id = 1000
	var sim := F.make_sim(F.flat_world(64), Vector2(30.5, 30.5))
	var kinds: Array[StringName] = [&"harvester", &"cutter", &"cutter"]
	var crowd := _crowd(sim, kinds)
	F.ms(sim, 200)
	sim._kill(crowd[0])
	F.ms(sim, 200)
	var still := 0
	for m in crowd:
		still += int(after(m))
	eq(still, 0, "its biggest fallen, the two cutters lose the fight")


func test_a_pair_is_not_a_crowd_that_breaks() -> void:
	MobState._next_id = 1000
	var sim := F.make_sim(F.flat_world(64), Vector2(30.5, 30.5))
	var kinds: Array[StringName] = [&"harvester", &"harvester"]
	var crowd := _crowd(sim, kinds)
	F.ms(sim, 200)
	sim._kill(crowd[0])
	F.ms(sim, 200)
	check(after(crowd[1]), "one of a pair fallen, the other fights on")


func test_a_crowd_that_lost_others_first_does_not_break_on_its_biggest() -> void:
	MobState._next_id = 1000
	var sim := F.make_sim(F.flat_world(64), Vector2(30.5, 30.5))
	var kinds: Array[StringName] = [&"harvester", &"cutter", &"cutter", &"cutter"]
	var crowd := _crowd(sim, kinds)
	F.ms(sim, 200)
	sim._kill(crowd[1])
	F.ms(sim, 200)
	sim._kill(crowd[0])
	F.ms(sim, 200)
	var still := 0
	for m in crowd:
		still += int(after(m))
	eq(still, 2, "its biggest taken second: the two cutters left fight on")
