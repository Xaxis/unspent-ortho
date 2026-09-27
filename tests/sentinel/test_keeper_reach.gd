extends TestCase
## A KEEPER REACHES YOU ON ITS OWN GROUND. Roused at its lair on a real world,
## with the player standing DIST off on ground its own move can walk to from
## there (its own field, FightSim.route_steps: a player on a cliff top or an
## island is not counted against it), it comes to striking range in
## REACH_SECONDS, finding a player who keeps still by its hunt (Brains._hunt).
## Every keeper charges, and a charge aimed straight at the player met a terrace
## wall, stood, re-aimed straight and met it again: on seeds 1 and 4 a keeper
## reached as few as 0 of 8 players 14 tiles off, on every GEN.
##
## A RATCHET, not a promise of every spot: over both seeds REACHED_LEAST of the
## spots are reached (86% measured, 2026-09-27), no keeper with REGION_TRIED
## spots or more reaches under REGION_LEAST of them, and every keeper's own move
## opens Sentinels.OPENS_LEAST tiles round its lair (Sentinels.lair holds a lair to
## it, and never puts one on the ground its FOUNDER way takes it on). What is left is a
## body stalled on a terrace edge where a corner of it hangs over a step its
## move will not take; raise the floor when that is fixed.

const F := preload("res://tests/fight/fixture.gd")
const SEEDS: Array[int] = [1, 4]
const DIST := 12.0
const REACH_SECONDS := 40.0
const REACHED_LEAST := 0.85
const REGION_LEAST := 0.25
const REGION_TRIED := 4


func _reaches(w: WorldData, lair: Vector2, kind: StringName, player: Vector2) -> Dictionary:
	var sim := F.make_sim(w, player)
	var m := sim.add_mob(kind, lair)
	if sim.route_steps(m, player, lair) >= NavField.FAR:
		return {"counted": false}
	m.facing = (player - lair).angle()
	m.aim = m.facing
	# Roused knowing where the player stood; then the player keeps still and
	# quiet, and it must find them by its own senses (Brains._hunt).
	m.disturbed = true
	m.last_seen = player
	m.set_mood(MobState.CHASING, sim.now)
	var t := 0.0
	while t < REACH_SECONDS * 1000.0:
		sim.hero.pos = player
		sim.slices(2)
		t += 16.0
		if m.pos.distance_to(sim.hero.pos) <= m.radius + sim.hero.radius + 2.0:
			return {"counted": true, "reached": true, "secs": t / 1000.0}
	return {"counted": true, "reached": false, "left": m.pos.distance_to(sim.hero.pos), "forgot": m.mood == MobState.IDLE or m.mood == MobState.FLEEING}


func test_every_keeper_reaches_a_player_the_ground_leads_to() -> void:
	var counted := 0
	var reached := 0
	var forgot := 0
	var stuck := 0
	for seed_value in SEEDS:
		var w := BootWorld.world(seed_value, Tuning.WORLD_SIZE)
		var q := WorldQuery.new(w)
		for s: SentinelState in Sentinels.states(w):
			var def := Sentinels.for_land(s.land)
			var lair: Vector2 = s.lair
			# Never stood on the ground its own FOUNDER way takes it on: roused
			# there, it foundered at home in the time it took to turn round.
			var sink := Sentinels.founders(def)
			var under := w.ground_at(floori(lair.x), floori(lair.y))
			check(not sink.has(under), "seed %d %s at %s: its lair is not on the ground it founders on (%s)" % [seed_value, s.land, lair, Ground.NAMES[under] if under < Ground.NAMES.size() else str(under)])
			var opens := Sentinels.opens(w, q, lair, def)
			print("  %s seed %d region %d opens %d tiles %d-%d out" % [s.land, seed_value, s.region, opens, Sentinels.OPEN_FROM, Sentinels.OPEN_TO])
			check(opens >= Sentinels.OPENS_LEAST, "seed %d %s at %s: its own move opens %d tiles %d-%d round its lair, not boxed in (%d)" % [seed_value, s.land, lair, Sentinels.OPENS_LEAST, Sentinels.OPEN_FROM, Sentinels.OPEN_TO, opens])
			var got := 0
			var tried := 0
			for k in 8:
				var p := lair + Vector2.from_angle(TAU * k / 8.0) * DIST
				if not q.standable(floori(p.x), floori(p.y)):
					continue
				var r := _reaches(w, lair, def.kind, p)
				if not r.counted:
					continue
				tried += 1
				counted += 1
				got += int(r.reached)
				if not r.reached:
					if bool(r.forgot):
						forgot += 1
					else:
						stuck += 1
			reached += got
			print("  %s seed %d region %d: %d of %d reached" % [s.land, seed_value, s.region, got, tried])
			if tried >= REGION_TRIED:
				check(float(got) / float(tried) >= REGION_LEAST, "seed %d %s at %s: reaches %d of %d players %.0f tiles off" % [seed_value, s.land, lair, got, tried, DIST])
	print("  missed: %d ended idle, %d still chasing and stuck" % [forgot, stuck])
	gt(float(counted), 150.0, "enough players its own move leads to were stood out (%d)" % counted)
	gt(float(reached) / float(maxi(counted, 1)), REACHED_LEAST - 0.0001, "keepers reach %d of %d players on their own ground" % [reached, counted])
