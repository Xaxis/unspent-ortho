extends TestCase
## THE COME-ROUND (shared keeper rule, 2026-09-27): a keeper whose target keeps
## to its flank or back inside its reach for a whole turn-pause comes round on it
## with a short-told sweep at that side (Sentinels.come_round_of), each keeper in
## its own flavour (SentinelDef.come_round). Circling a guarded keeper was a dead
## end: it could never face the player to run, so it never bit and never opened.
## Now circling is answered, and the sweep is a tell to dodge and an opening after.

const F := preload("res://tests/fight/fixture.gd")


func test_every_keeper_says_how_it_comes_round() -> void:
	for land: StringName in Sentinels.lands():
		var def := Sentinels.for_land(land)
		check(def.come_round.length() > 20, "%s says its come-round in its own words" % land)


## A body kept circling a guarded keeper's flank at 2.3 tiles, faster than it
## turns: before, nothing ever came; now the keeper comes round with the sweep,
## told short, and the sweep's box covers the side the body keeps to.
func test_a_circling_body_is_come_round_on() -> void:
	for land: StringName in Sentinels.lands():
		MobState._next_id = 1000
		var def := Sentinels.for_land(land)
		var sim := F.make_sim(F.flat_world(64), Vector2(32.5, 32.5))
		var at := sim.hero.pos + Vector2(3.0, 0.0)
		var m := sim.add_mob(def.kind, at)
		Sentinels.own_row(m)
		# Its guarded phase if it has one, else its first: circling is what the
		# guard invites.
		var guarded := 0
		for i in def.phases.size():
			if def.phase(i).guarded:
				guarded = i
				break
		Sentinels.wear_phase(m, def, guarded)
		m.facing = PI
		m.aim = PI
		m.disturbed = true
		m.set_mood(MobState.ATTACKING, sim.now)
		var angle := 0.0
		var r := m.radius + sim.hero.radius + 1.0
		var came := false
		var covered := false
		for k in 400:
			angle += 1.6 * 0.008
			sim.hero.pos = m.pos + Vector2.from_angle(m.facing + PI * 0.5 + angle) * r
			sim.slices(1)
			for e in sim.drain():
				if e.type == &"windup" and m.blow != null and m.blow == m.come_round:
					came = true
					covered = FightRules.box_hits(m.pos, m.facing, m.radius, m.blow, sim.hero.pos, sim.hero.radius)
			if came:
				break
		check(came, "%s comes round on a body circling its flank" % land)
		check(covered, "%s: and its sweep covers where that body is" % land)
		if came:
			lt(float(m.come_round.windup), float(m.bite.windup) + 1.0, "%s: told no longer than its bite" % land)
