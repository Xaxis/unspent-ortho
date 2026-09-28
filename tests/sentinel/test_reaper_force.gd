extends TestCase
## THE REAPER BY FORCE IS A FIGHT (roadmap slice 1 step 4, cb's playtest bar):
## from full health, with the steel knife the kiln makes (knife_shear, the edge
## its plate asks for), the shoulder reader takes it down by blows in its open
## part: many of them, over a real stretch of time, and on its own shore as well
## as on open ground. The stooped phase grips; a grip pulled loose must leave a
## window a player can use, or the force way is nominal.

const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")


static func bout(w: WorldData, lair: Vector2, start: Vector2, ids: int, seconds: float = 150.0) -> Dictionary:
	MobState._next_id = ids
	var def := Sentinels.for_land(&"coast")
	var sim := F.make_sim(w, start)
	sim.hero.inventory.add(&"knife_shear")
	sim.hero.inventory.set_held(&"knife_shear")
	sim.hero.kit = FightKit.of([])
	var m := sim.add_mob(def.kind, lair)
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 0)
	m.facing = (sim.hero.pos - m.pos).angle()
	m.aim = m.facing
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	var reader: Variant = SR.new(sim)
	sim.hero.facing = (m.pos - sim.hero.pos).angle()
	var phase := 0
	var blows := [0, 0, 0]
	var grips := 0
	var loose := 0
	var t := 0.0
	var out := {"won": false, "t": 0.0, "blows": 0, "by_phase": blows, "grips": 0, "loose": 0, "end": &"time", "hurt": 0, "torn": 0}
	var over := false
	while t < seconds * 1000.0 and not over:
		var want := def.phase_at(m.health_fraction())
		if want != phase and m.alive:
			phase = want
			Sentinels.wear_phase(m, def, want)
		reader.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hit" and e.target == m and int(e.damage) > 0:
				blows[phase] += 1
			if e.type == &"grip":
				grips += 1
			if e.type == &"loose":
				loose += 1
			if e.type == &"torn":
				out.torn = int(out.torn) + 1
			if e.type == &"hurt":
				out.hurt = int(out.hurt) + int(e.damage)
			if e.type == &"outcome" and e.outcome in [&"downed", &"carried"]:
				out.end = e.outcome
				over = true
		if not m.alive:
			out.won = true
			out.end = &"won"
			break
	out.t = t / 1000.0
	out.blows = blows[0] + blows[1] + blows[2]
	out.grips = grips
	out.loose = loose
	return out


static func tally(rows: Array[Dictionary]) -> Dictionary:
	var won := 0
	var t := 0.0
	var blows := 0
	var grips := 0
	var loose := 0
	var ends := {}
	for r: Dictionary in rows:
		won += int(r.won)
		if r.won:
			t += float(r.t)
			blows += int(r.blows)
		grips += int(r.grips)
		loose += int(r.loose)
		ends[r.end] = int(ends.get(r.end, 0)) + 1
	return {"n": rows.size(), "won": won, "t": t / maxf(won, 1), "blows": float(blows) / maxf(won, 1), "grips": grips, "loose": loose, "ends": ends}


## Seed 7's shore (the playtest's): each start round its lair where a player
## can stand, the reader holding the steel knife, from full health.
const SHORE_SEED := 7
const WON_LEAST := 4
const BLOWS_LEAST := 20
const SECONDS_LEAST := 20.0


func test_by_force_it_is_many_blows_over_a_real_fight() -> void:
	var w := BootWorld.world(SHORE_SEED, Tuning.WORLD_SIZE)
	var lair := Vector2.INF
	for s: SentinelState in Sentinels.states(w):
		if s.land == &"coast":
			lair = s.lair
			break
	check(is_finite(lair.x), "seed %d has a reaper" % SHORE_SEED)
	if not is_finite(lair.x):
		return
	var q := WorldQuery.new(w)
	var rows: Array[Dictionary] = []
	for k in 8:
		var p := lair + Vector2.from_angle(TAU * k / 8.0) * 7.0
		if q.standable(floori(p.x), floori(p.y)):
			rows.append(bout(w, lair, p, 2000 + k))
	var r := tally(rows)
	print("  info seed %d shore: %s" % [SHORE_SEED, r])
	gt(float(r.won), float(WON_LEAST) - 0.5, "won from full health on its own shore (%d of %d)" % [r.won, r.n])
	for b: Dictionary in rows:
		if b.won:
			gt(float(b.blows), float(BLOWS_LEAST) - 0.5, "a fight of blows in its open part, not one (%d)" % b.blows)
			gt(float(b.t), SECONDS_LEAST, "over a real stretch of time (%.1f s)" % b.t)


## A player the stooped Reaper has gripped pulls loose with the steel knife (two
## pulls), then runs round the arch for the chute gear at its back and swings
## when behind it: a human's play, no reading of its timers. Once loose, the gear
## must be taken before it grips again, from any side it gripped from.
static func grip_then_back(from_side: float, ids: int) -> Dictionary:
	MobState._next_id = ids
	var def := Sentinels.for_land(&"coast")
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife_shear")
	sim.hero.inventory.set_held(&"knife_shear")
	sim.hero.kit = FightKit.of([])
	var m := sim.add_mob(def.kind, sim.hero.pos + Vector2.from_angle(from_side) * 2.6)
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 2)
	m.health = int(m.max_health * 0.25)
	m.facing = (sim.hero.pos - m.pos).angle()
	m.aim = m.facing
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	var hero := sim.hero
	var out := {"gripped": false, "loose": false, "took": false, "secs": -1.0, "regripped": false, "end": &"time", "sides": {}, "near": 99.0}
	var loose_at := -INF
	var t := 0.0
	while t < 20000.0 and m.alive:
		var to := m.pos - hero.pos
		hero.facing = to.angle()
		if hero.held():
			hero.move = Vector2.ZERO
			if int(t) % 160 < 16:
				sim.press_swing()
		elif out.loose:
			# Round the arch the short way to its back, running; swing when behind.
			var back := m.pos - Vector2.from_angle(m.facing) * (m.radius + 0.55)
			var side := FightRules.side_of(m.pos, m.facing, hero.pos)
			if side == &"back" and to.length() <= m.radius + 1.2:
				hero.move = Vector2.ZERO
				sim.press_swing()
			else:
				var way := back - hero.pos
				# Keep off the body: step out along the circle when the line crosses it.
				var r := hero.pos - m.pos
				if r.length() < m.radius + 0.9:
					way += r.normalized() * 1.5
				hero.move = way.normalized()
			hero.run = true
		else:
			hero.move = Vector2.ZERO
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"grip":
				if out.loose:
					out.regripped = true
				out.gripped = true
			if e.type == &"loose":
				out.loose = true
				loose_at = t
			if e.type == &"hit" and e.target == m and int(e.damage) > 0 and out.loose and not out.took:
				out.took = true
				out.secs = (t - loose_at) / 1000.0
			if e.type == &"outcome":
				out.end = e.outcome
				return out
		if out.loose and not out.took:
			out.sides[FightRules.side_of(m.pos, m.facing, hero.pos)] = int(out.sides.get(FightRules.side_of(m.pos, m.facing, hero.pos), 0)) + 1
			out.near = minf(float(out.near), (m.pos - hero.pos).length())
		if out.took or out.regripped:
			return out
	return out


func test_pulled_loose_the_chute_gear_is_there_to_take() -> void:
	var took := 0
	var tried := 0
	for k in 8:
		var r := grip_then_back(TAU * k / 8.0, 3000 + k)
		print("  info grip from %d: %s" % [k, r])
		if not r.gripped or not r.loose:
			continue
		tried += 1
		took += int(r.took)
	gt(float(tried), 5.5, "it grips a player standing in front of it, and the knife pulls loose (%d of 8)" % tried)
	eq(took, tried, "pulled loose, the chute gear at its back is taken before it grips again")
