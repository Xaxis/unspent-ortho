extends TestCase
## A whole fight with a keeper, in the real simulation, headless: the openings it
## gives, the phases it goes through, and the two ways it can end that are not a
## fight at all. This is the evidence that a sentinel is beatable — and beatable by
## READING it rather than by standing in front of it — without a person at the keys.

const F := preload("res://tests/fight/fixture.gd")


## A keeper out on flat ground with the player beside it, as 44_sentinels puts one
## out: its own row, its first phase, roused and fighting.
func _fight(land: StringName, kit: Array[StringName] = []) -> Dictionary:
	var def := Sentinels.for_land(land)
	var sim := F.make_sim(F.flat_world(80), Vector2(40.5, 40.5))
	sim.hero.inventory.add(&"axe_felling")
	sim.hero.inventory.set_held(&"axe_felling")
	sim.hero.kit = FightKit.of(kit)
	var m := sim.add_mob(def.kind, Vector2(44.5, 40.5))
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 0)
	m.facing = PI
	m.aim = PI
	m.line_a = m.pos
	m.line_b = m.pos
	m.disturbed = true
	m.set_mood(MobState.ATTACKING, sim.now)
	return {"sim": sim, "mob": m, "def": def}


## Where the working part can be reached from: the side a player has to walk to,
## `gap` off the body's skin.
func _at_part(m: MobState, gap: float) -> Vector2:
	var side := {&"front": 0.0, &"right": PI * 0.5, &"back": PI, &"left": -PI * 0.5}
	var off: float = side.get(m.part, 0.0)
	return m.pos + Vector2.from_angle(m.facing + off) * (m.radius + gap)


## One pass of the fight a player learns: stand in front of it where it will bite,
## step round out of the box as the tell starts, and go into the working part while
## the drum is jammed. Nothing here is a special case for a sentinel — it is the
## plate rule and the opening every machine has had since M1.
func _play(sim: FightSim, m: MobState) -> void:
	var hero := sim.hero
	var bp := m.blow_phase(sim.now)
	if bp == &"windup" or bp == &"active":
		hero.pos = _at_part(m, hero.radius + m.bite.reach + 1.0)
		hero.facing = (m.pos - hero.pos).angle()
		return
	if m.spent(sim.now) or m.stunned(sim.now) or not m.roused() or sim.phase_ready(m):
		hero.pos = _at_part(m, hero.radius + 0.4)
		hero.facing = (m.pos - hero.pos).angle()
		if (sim.reaches_part(m, hero.pos) or sim.phase_ready(m)) and not hero.committed(sim.now):
			sim.press_swing()
		return
	# In front of it, inside its reach: what makes it throw a bite at all.
	hero.pos = m.pos + Vector2.from_angle(m.facing) * (m.radius + hero.radius + m.bite.reach * 0.5)
	hero.facing = (m.pos - hero.pos).angle()


## Fight it down, taking only the openings it gives.
func _beat(land: StringName, slices: int = 12000, kit: Array[StringName] = []) -> Dictionary:
	var f := _fight(land, kit)
	var sim: FightSim = f.sim
	var m: MobState = f.mob
	var def: SentinelDef = f.def
	var phase := 0
	var parts: Array[StringName] = [m.part]
	var swings := 0
	var rings := 0
	var openings := 0
	for i in slices:
		sim.slices(1)
		# What the system does every frame: the phase is the body.
		var want := def.phase_at(m.health_fraction())
		if want != phase and m.alive:
			phase = want
			Sentinels.wear_phase(m, def, want)
			parts.append(m.part)
		if not m.alive:
			break
		_play(sim, m)
		for e in sim.drain():
			if e.type == &"swing":
				swings += 1
			elif e.type == &"hit" and bool(e.get("plate", false)):
				rings += 1
			elif e.type == &"opened":
				# The machine says so itself: a bite went past and its part is open.
				openings += 1
		# The player is never hurt in this fight: it is about the machine.
		sim.hero.health = FightRules.HEALTH
		sim.hero.wind = FightRules.WIND
	return {"mob": m, "def": def, "phases": phase, "parts": parts, "swings": swings,
		"rings": rings, "openings": openings, "sim": sim}


func test_a_keeper_can_be_taken_apart_through_the_openings_it_gives() -> void:
	for land: StringName in [&"coast", &"salt_flats"]:
		var r := _beat(land)
		var m: MobState = r.mob
		var def: SentinelDef = r.def
		check(not m.alive, "%s: the keeper goes down (at %d of %d health, phase %d)"
			% [land, m.health, m.max_health, int(r.phases)])
		eq(r.phases, def.phases.size() - 1, "%s: through every phase on the way" % land)
		gt(float(r.openings), 2.0, "%s: it gave %d openings on the way down" % [land, int(r.openings)])
		lt(float(r.swings), 60.0, "%s: and took %d swings, not a hundred" % [land, int(r.swings)])
		print("sentinel %s: down in %d swings, %d openings, %d rings, %.1f s of fight"
			% [land, int(r.swings), int(r.openings), int(r.rings), float((r.sim as FightSim).now) / 1000.0])
		# The side that is open moved as it came apart: the lesson a boss teaches.
		var seen := {}
		for p: StringName in (r.parts as Array[StringName]):
			seen[p] = true
		gt(float(seen.size()), 2.0, "%s: the working side moved (%d sides)" % [land, seen.size()])


func test_standing_in_front_of_one_and_swinging_never_beats_it() -> void:
	# The other half of VISION §3: "none by trading hits". A player who walks in
	# swinging at a guarded keeper rings off it and is taken apart.
	var f := _fight(&"coast")
	var sim: FightSim = f.sim
	var m: MobState = f.mob
	var rings := 0
	var hurt := 0
	for i in 3000:
		sim.slices(1)
		if not m.alive:
			break
		# Dead in front of its working part, swinging on every cooldown.
		sim.hero.pos = m.pos + Vector2.from_angle(m.facing) * (m.radius + sim.hero.radius + 0.5)
		sim.hero.facing = (m.pos - sim.hero.pos).angle()
		sim.press_swing()
		for e in sim.drain():
			if e.type == &"hit" and bool(e.get("plate", false)):
				rings += 1
			elif e.type == &"hurt":
				hurt += 1
	check(m.alive, "the keeper is still standing (%d of %d)" % [m.health, m.max_health])
	gt(float(rings), 3.0, "and the blows rang off its drum (%d)" % rings)
	gt(float(hurt), 0.0, "while it took the player apart (%d blows landed on them)" % hurt)


func test_the_land_takes_it_where_it_will_not_carry_it() -> void:
	# The FOUNDER way, judged as 44_sentinels judges it: the look is filled in from
	# the body and the ground under it, and the pure rule says the rest.
	var def := Sentinels.for_land(&"salt_flats")
	var way := def.way_of(SentinelWay.FOUNDER)
	var look := SentinelLook.new()
	look.health = 0.8
	look.ground = Ground.SALT
	look.ground_ms = 20000.0
	check(not way.met(look), "the crust carries it all day")
	look.ground = way.grounds[0]
	look.ground_ms = way.hold_ms * 0.5
	check(not way.met(look), "crossing a pan is not foundering in one")
	look.ground_ms = way.hold_ms
	check(way.met(look), "standing in one is")
	check(way.kills(), "and it does not get up")


func test_a_keeper_that_stood_down_is_not_a_keeper_any_more() -> void:
	# The SPOOF way: beaten without a blow. What changes is the REGION, not the
	# machine — it is still standing there when it is over.
	var def := Sentinels.for_land(&"salt_flats")
	var way := def.way_of(SentinelWay.SPOOF)
	var s := SentinelState.new()
	s.region = 3
	s.design = def.id
	s.land = def.land
	s.lair = Vector2(20, 20)
	s.max_health = Roster.health_of(def.kind)
	s.health = s.max_health
	check(s.alive() and s.holds(s.lair + Vector2(4, 0), def.reach), "it holds its ground while it keeps")
	s.fallen = true
	s.how = way.id()
	check(not s.holds(s.lair, def.reach), "and holds nothing once it has stood down")
	check(not s.alive(), "the region is taken")
	eq(s.health, s.max_health, "though nothing was ever done to its body")


## The phase coil's opener against a keeper: a shorter fight, still through
## every phase, and not a win (mechanics pass 2a).
func test_a_phase_coil_opens_a_keeper_and_does_not_take_it() -> void:
	for land: StringName in [&"coast", &"salt_flats"]:
		var bare := _beat(land)
		var coil := _beat(land, 12000, [&"mod_phase"] as Array[StringName])
		var tb := float((bare.sim as FightSim).now) / 1000.0
		var tc := float((coil.sim as FightSim).now) / 1000.0
		print("sentinel %s: bare %.1f s, phase coil %.1f s (%.0f%% less)" % [land, tb, tc, (1.0 - tc / tb) * 100.0])
		check(not (coil.mob as MobState).alive, "%s: the coil's reader takes it" % land)
		eq(coil.phases, (coil.def as SentinelDef).phases.size() - 1, "%s: through every phase" % land)
		check(tc <= tb + 0.02, "%s: never slower with it" % land)
