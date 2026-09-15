extends RefCounted
## Small hand-made worlds and simulations for fight tests: flat ground, one
## country, no villages, so every rule is tested against exactly what it reads
## and nothing another package generates can move a number.


static func flat_world(size: int = 64, ground: int = Ground.GRASS, country: int = Country.COAST, level: int = 2) -> WorldData:
	var w := WorldData.new(7, size)
	for i in size * size:
		w.level[i] = level
		w.ground[i] = ground
		w.country[i] = country
	w.spawn = Vector2(size * 0.5, size * 0.5)
	return w


## A simulation with a hero at `at` facing east, bare-handed, full body.
static func make_sim(w: WorldData = null, at: Vector2 = Vector2(20.5, 20.5)) -> FightSim:
	if w == null:
		w = flat_world()
	var q := WorldQuery.new(w)
	var hero := Hero.new()
	hero.body = Body.new()
	hero.inventory = Inventory.new()
	hero.pos = at
	hero.facing = 0.0
	var m := Moment.new()
	m.seed_value = 7
	m.minutes = 12.0 * 60.0
	var sim := FightSim.new(w, q, hero, m)
	return sim


## A body placed and made to hold still and pay no attention unless struck.
static func still(sim: FightSim, kind: StringName, at: Vector2, facing: float) -> MobState:
	var m := sim.add_mob(kind, at)
	m.facing = facing
	m.aim = facing
	m.line_a = at
	m.line_b = at
	m.calm_until = INF
	return m


static func ms(sim: FightSim, milliseconds: float) -> void:
	sim.slices(maxi(1, roundi(milliseconds / FightRules.SLICE_MS)))


static func count(events: Array[Dictionary], type: StringName) -> int:
	var n := 0
	for e in events:
		if e.type == type:
			n += 1
	return n


static func first(events: Array[Dictionary], type: StringName) -> Dictionary:
	for e in events:
		if e.type == type:
			return e
	return {}
