extends TestCase
## THE REAPER BY FORCE IS A FIGHT (roadmap slice 1 step 4, cb's playtest bar):
## from full health, with the steel knife the kiln makes (knife_shear, the edge
## its plate asks for), the shoulder reader takes it down by blows in its open
## part: many of them, over a real stretch of time, and on its own shore as well
## as on open ground. The stooped phase grips; a grip pulled loose must leave a
## window a player can use, or the force way is nominal.

const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")
const PR := preload("res://tests/fight/plate_reader.gd")


static func bout(w: WorldData, lair: Vector2, start: Vector2, ids: int, seconds: float = 150.0, human: int = -1, at_plate: bool = false, health: int = -1, hero_health: int = -1) -> Dictionary:
	MobState._next_id = ids
	var def := Sentinels.for_land(&"coast")
	var sim := F.make_sim(w, start)
	sim.hero.inventory.add(&"knife_shear")
	sim.hero.inventory.set_held(&"knife_shear")
	sim.hero.kit = FightKit.of([])
	if hero_health > 0:
		# Come to after a down, as the last try left them (Outcomes.downed).
		sim.hero.health = hero_health
	var m := sim.add_mob(def.kind, lair)
	Sentinels.own_row(m)
	if health >= 0:
		# What an earlier try left it (SentinelState keeps a keeper's health).
		m.health = health
	var phase := def.phase_at(m.health_fraction())
	Sentinels.wear_phase(m, def, phase)
	# As 44_sentinels puts it out: at its lair, facing the way the player comes
	# from, standing its ground, at its work until the player is inside its guard.
	m.facing = (sim.hero.pos - m.pos).angle()
	m.aim = m.facing
	m.bearing = Vector2.from_angle(m.facing)
	m.line_a = lair
	m.line_b = lair
	m.home = lair
	var reader: Variant = PR.new(sim) if at_plate else SR.new(sim)
	reader.human = human
	sim.hero.facing = (m.pos - sim.hero.pos).angle()
	var blows := [0, 0, 0]
	var grips := 0
	var loose := 0
	var t := 0.0
	var out := {"won": false, "t": 0.0, "blows": 0, "by_phase": blows, "grips": 0, "loose": 0, "end": &"time", "hurt": 0, "torn": 0, "tells": 0, "gap": 0.0}
	# The longest the player stood beside it without a tell: the time beside it
	# between one windup and the next. Time carried out of its reach (knocked out
	# into the sea) is not time it owes a tell for, nor is time it stands spent,
	# stopped by the player's blows, or holding them: that is an opening, or a
	# bite that landed, not a wait.
	var stood := 0.0
	var over := false
	while t < seconds * 1000.0 and not over:
		var want := def.phase_at(m.health_fraction())
		if want != phase and m.alive:
			phase = want
			Sentinels.wear_phase(m, def, want)
		reader.act()
		sim.slices(2)
		t += 16.0
		var owed := not (m.spent(sim.now) or m.stunned(sim.now) or sim.hero.held())
		if owed and sim.hero.pos.distance_to(m.pos) <= m.radius + sim.hero.radius + 1.0:
			stood += 16.0
			out.gap = maxf(float(out.gap), stood / 1000.0)
		for e in sim.drain():
			if e.type == &"windup" and e.mob == m:
				out.tells = int(out.tells) + 1
				stood = 0.0
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
	out.health = m.health
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



## THE PLAYER AT ITS PLATE (the proof tour's, tours/reaper_force.tour, and
## cb's): walked round to the side of it opposite its working part and stood
## against it, a first-hour human's hands (Reader.human: a late eye, misreads,
## whiffs), moved only by the walk and hurt for real. It is told a bite within
## a few seconds wherever it stands, and a run of tries (the keeper keeps what
## each one cost it) takes it down. Seeds 1 (the owner's) and 7, from every side
## of the lair on the keeper's own level. The longest wait for a tell on main was
## 68 and 128 s: a keeper with the player pressed to it walked its field's way
## round to them (a prop by the line) instead of biting.
const PLATE_SEEDS: Array[int] = [1, 7]
## Seconds beside it without a tell, not counting its stands: its slowest
## honest wait is the turn round to a player who keeps to its back, and the
## seconds a person spends going round before letting it come.
const TELL_WAIT_MOST := 6.0
const TRIES_MOST := 4


## Tries, one after another from the same start, the keeper carrying its wounds
## and the player coming to at DOWNED_WAKE_HEALTH after a down, until it falls
## or TRIES_MOST are spent.
static func tries(w: WorldData, lair: Vector2, start: Vector2, ids: int, human: int) -> Dictionary:
	var health := -1
	var out := {"tries": 0, "won": false, "t": 0.0, "blows": 0, "gap": 0.0, "last_t": 0.0}
	for i in TRIES_MOST:
		var r := bout(w, lair, start, ids + i * 100, 90.0, human + i * 17, true, health, FightRules.DOWNED_WAKE_HEALTH if i > 0 else -1)
		out.tries = i + 1
		out.t = float(out.t) + float(r.t)
		out.last_t = float(r.t)
		out.blows = int(out.blows) + int(r.blows)
		out.gap = maxf(float(out.gap), float(r.gap))
		health = int(r.health)
		if r.won:
			out.won = true
			break
	return out


func test_at_its_plate_it_tells_and_a_few_tries_take_it() -> void:
	for sd: int in PLATE_SEEDS:
		var w := BootWorld.world(sd, Tuning.WORLD_SIZE)
		var lair := Vector2.INF
		for s: SentinelState in Sentinels.states(w):
			if s.land == &"coast":
				lair = s.lair
				break
		check(is_finite(lair.x), "seed %d has a reaper" % sd)
		if not is_finite(lair.x):
			continue
		var q := WorldQuery.new(w)
		var lair_level := w.level_at(floori(lair.x), floori(lair.y))
		var runs: Array[Dictionary] = []
		for k in 8:
			var p := lair + Vector2.from_angle(TAU * k / 8.0) * 7.0
			if not q.standable(floori(p.x), floori(p.y)) or not FightRules.levels_meet(w.level_at(floori(p.x), floori(p.y)), lair_level):
				continue
			var r := tries(w, lair, p, 4000 + k, k)
			print("  info seed %d from %d: %s" % [sd, k, r])
			runs.append(r)
		gt(float(runs.size()), 1.5, "seed %d: sides of its lair to come at it from (%d)" % [sd, runs.size()])
		var won := 0
		var tried := 0
		for r: Dictionary in runs:
			lt(float(r.gap), TELL_WAIT_MOST, "seed %d: beside it, a tell within %.0f s (longest wait %.1f s)" % [sd, TELL_WAIT_MOST, r.gap])
			if r.won:
				won += 1
				tried += int(r.tries)
		gt(float(won), runs.size() * 0.5, "seed %d: taken by force within %d tries from most sides (%d of %d)" % [sd, TRIES_MOST, won, runs.size()])
		lt(float(tried) / maxf(won, 1), 3.5, "seed %d: in about three tries (%.1f)" % [sd, float(tried) / maxf(won, 1)])

