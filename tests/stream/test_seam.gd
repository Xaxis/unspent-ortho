extends TestCase
## The streaming seam (slice S1): readers that swept the whole world now read
## only what is near, or what generation recorded. Each keeps the ANSWER it
## gave: the old whole-world form is kept here as the reference and the two are
## compared on a real world, at many places.

const SIZE := 512
const SEED := 7

static var _w: WorldData
static var _q: WorldQuery


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(SEED, SIZE)
		_q = WorldQuery.new(_w)
	return _w


## Where a downed body is carried to, found by sweeping every prop: the form
## `Outcomes.working_near` had before it read the query.
static func _working_near_whole(world: WorldData, query: WorldQuery, from: Vector2, range_tiles: float) -> Dictionary:
	var r2 := range_tiles * range_tiles
	for kinds: Array in [Outcomes.ORE, Outcomes.ROCK]:
		var cands: Array[WorldProp] = []
		var dists: PackedFloat32Array = []
		for p in world.props:
			if kinds.has(p.kind) and not world.depleted.has(p.id):
				var d := p.pos.distance_squared_to(from)
				if d <= r2:
					cands.append(p)
					dists.append(d)
		for attempt in mini(cands.size(), Outcomes.BESIDE_TRIES):
			var best := 0
			for i in dists.size():
				if dists[i] < dists[best]:
					best = i
			var spot := Outcomes._beside(world, query, cands[best])
			if not spot.is_empty():
				return spot
			dists[best] = INF
	return {}


func test_working_near_answers_as_the_whole_sweep_did() -> void:
	var w := _world()
	# Asked from a real working's surroundings at every distance, so answers are
	# found in each shell and across its edges: a random spot mostly has ore
	# well inside the first one, and a search cut short would agree there.
	var workings: Array[WorldProp] = []
	for p in w.props:
		if Outcomes.ORE.has(p.kind) or Outcomes.ROCK.has(p.kind):
			workings.append(p)
	gt(float(workings.size()), 100.0, "the world has workings (%d)" % workings.size())
	var found := 0
	var n := 0
	for k in 600:
		var p := workings[floori(Rng.hash01(SEED, k, 0, 0x5EA) * workings.size())]
		var a := Rng.hash01(SEED, k, 1, 0x5EA) * TAU
		# Across every shell boundary the search widens through, and out to the
		# edge of the range.
		var r := 4.0 + Rng.hash01(SEED, k, 2, 0x5EA) * 200.0
		var at := p.pos + Vector2(cos(a), sin(a)) * r
		if w.level_at(floori(at.x), floori(at.y)) <= 0:
			continue
		n += 1
		var want := _working_near_whole(w, _q, at, FightRules.CARRIED_RANGE)
		var got := Outcomes.working_near(w, _q, at, FightRules.CARRIED_RANGE)
		eq(got, want, "carried from %s" % at)
		if not want.is_empty():
			found += 1
	gt(float(n), 150.0, "enough land sampled (%d)" % n)
	gt(float(found), 50.0, "and most of it finds a working (%d)" % found)


func test_working_near_reaches_past_the_near_shells() -> void:
	# A working far off: every one within 140 tiles taken first, so the answer
	# can only come from the widest shell.
	var w := _world()
	var asked := 0
	for k in 30:
		var at := Vector2(Rng.hash01(SEED, k, 3, 0x5EB) * SIZE, Rng.hash01(SEED, k, 4, 0x5EB) * SIZE)
		if w.level_at(floori(at.x), floori(at.y)) <= 0:
			continue
		var taken: Array[int] = []
		for p in w.props:
			if (Outcomes.ORE.has(p.kind) or Outcomes.ROCK.has(p.kind)) and p.pos.distance_to(at) < 140.0 and not w.depleted.has(p.id):
				w.depleted[p.id] = 0.0
				taken.append(p.id)
		var want := _working_near_whole(w, _q, at, FightRules.CARRIED_RANGE)
		var got := Outcomes.working_near(w, _q, at, FightRules.CARRIED_RANGE)
		for id in taken:
			w.depleted.erase(id)
		eq(got, want, "carried from %s with nothing near" % at)
		if not want.is_empty():
			asked += 1
	gt(float(asked), 2.0, "some found a working past 140 tiles (%d)" % asked)
