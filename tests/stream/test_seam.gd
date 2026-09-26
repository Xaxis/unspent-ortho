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


## The old `Chapter._standing_counts`: every prop, its region, that region's ore.
static func _ore_standing_whole(world: WorldData) -> Dictionary:
	var kinds_of := {}
	var out := {}
	for p: WorldProp in world.props:
		var r := world.region_at(floori(p.pos.x), floori(p.pos.y))
		if r < 0:
			continue
		if not kinds_of.has(r):
			kinds_of[r] = Chapter.ore_kinds(world, r)
		if (kinds_of[r] as Array).has(p.kind):
			out[r] = int(out.get(r, 0)) + 1
	return out


func test_generation_records_the_ore_every_region_stands() -> void:
	var w := _world()
	check(w.ore_counted, "generation counted the ore")
	var want := _ore_standing_whole(w)
	gt(float(want.size()), 3.0, "several regions stand ore (%d)" % want.size())
	eq(w.ore_standing, want, "the record is the sweep's count")
	for r: int in want:
		eq(Chapter.ore_standing(w, r), int(want[r]), "region %d reads it" % r)


## The old `StoryFragments.held_by` count: every prop of the world before it.
static func _held_by_whole(world: WorldData, prop: WorldProp) -> StringName:
	var kind := StoryProps.kind_of(prop.kind)
	if kind == &"":
		return &""
	var place := StoryWorld.place_of(world, prop.pos)
	if place != &"":
		var n := 0
		for q: WorldProp in world.props:
			if q.id < prop.id and StoryProps.kind_of(q.kind) == kind and StoryWorld.place_of(world, q.pos) == place:
				n += 1
		var own := StoryFragments.pick_at(place, n, kind)
		if own != &"":
			return own
	var d := BiomeRegistry.at(world, prop.pos)
	return StoryFragments.pick(kind, d.id if d != null else &"", world.seed_value, prop.id)


func test_the_words_a_thing_holds_are_counted_from_its_place() -> void:
	var w := _world()
	var site := StoryWorld.black_site(w)
	check(site != Vector2.INF, "the world has its black site")
	var in_place := 0
	var readable := 0
	for p in w.props:
		if StoryProps.kind_of(p.kind) == &"":
			continue
		readable += 1
		if StoryWorld.place_of(w, p.pos) != &"":
			in_place += 1
		eq(StoryFragments.held_by(w, _q, p), _held_by_whole(w, p), "prop %d holds the same words" % p.id)
	gt(float(in_place), 2.0, "things stand in the place (%d)" % in_place)
	gt(float(readable), 20.0, "and elsewhere (%d)" % readable)


func test_a_thing_at_the_far_edge_of_a_place_counts_what_stands_across_it() -> void:
	# The window has to span the whole place: a screen set down at its edge,
	# opposite the ones already there, counts them all.
	var w := _world()
	var site := StoryWorld.black_site(w)
	var first: WorldProp = null
	for p in _q.props_near(site, StoryWorld.PLACE_REACH):
		if p.kind == PropKind.CONSOLE and StoryWorld.place_of(w, p.pos) != &"" and (first == null or p.id < first.id):
			first = p
	check(first != null, "a screen stands in the place")
	if first == null:
		return
	var away := (site - first.pos).normalized() if first.pos.distance_to(site) > 0.01 else Vector2.RIGHT
	var edge := WorldProp.new(w.props.size(), PropKind.CONSOLE, site + away * StoryWorld.PLACE_REACH * 0.95, 0.0, 1.0)
	w.props.append(edge)
	_q.add_prop(edge)
	check(StoryWorld.place_of(w, edge.pos) != &"", "the new screen stands in the place")
	eq(StoryFragments.held_by(w, _q, edge), _held_by_whole(w, edge), "the edge screen holds what the sweep said")
	_q.remove_prop(edge)
	w.props.pop_back()


## What the view's `_bind` filed before it bound a section at a time: every
## prop, every line, every standing prop, walked once each.
static func _buckets_whole(w: WorldData) -> Array:
	var chunks := {}
	for p in w.props:
		var key := WorldView._key_of(p.pos)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(p)
	var cables := {}
	for line: Dictionary in w.lines:
		if not line.has("props"):
			continue
		var ids := PackedInt32Array(line["props"])
		for j in ids.size() - 1:
			if w.prop(ids[j]) == null or w.prop(ids[j + 1]) == null:
				continue
			var key := WorldView._key_of(w.prop(ids[j]).pos)
			if not cables.has(key):
				cables[key] = []
			cables[key].append(Vector2i(ids[j], ids[j + 1]))
	var far := {}
	for p in w.props:
		if w.depleted.has(p.id):
			continue
		var bk := Vector2i(floori(p.pos.x) / WorldView.Far.BLOCK, floori(p.pos.y) / WorldView.Far.BLOCK)
		if not far.has(bk):
			far[bk] = []
		far[bk].append(p)
	return [chunks, cables, far]


## The view keeps table rows; the reference kept props. Compared as props.
static func _as_props(w: WorldData, lists: Dictionary) -> Dictionary:
	var out := {}
	for key: Vector2i in lists:
		var props: Array = []
		for row: int in lists[key]:
			props.append(w.prop_at(row))
		out[key] = props
	return out


func test_the_view_bound_a_section_at_a_time_files_what_the_whole_bind_did() -> void:
	var w := _world()
	var view := WorldView.new()
	view.setup(w)
	var want := _buckets_whole(w)
	eq(_as_props(w, view._props_by_chunk), want[0], "every chunk holds the same props, in the same order")
	eq(view._cables_by_chunk, want[1], "every chunk draws the same spans")
	eq(_as_props(w, view._far_props), want[2], "every far block stands the same props")
	gt(float((want[1] as Dictionary).size()), 0.0, "the world strings a grid (%d chunks of spans)" % (want[1] as Dictionary).size())
	view.free()


func test_a_prop_set_down_later_is_found_in_its_section() -> void:
	# Its own small world: a prop set down stays set down.
	var w := WorldGen.generate(SEED, 192)
	var at := Vector2(150.5, 100.5)
	var before := WorldSections.props_in(w, WorldSections.of(at)).size()
	var p := WorldProp.new(w.next_id(), PropKind.FIRE, at, 0.0, 1.0)
	w.add_prop(p)
	var got := WorldSections.props_in(w, WorldSections.of(at))
	eq(got.size(), before + 1, "its section holds one more")
	check(got.any(func(q: WorldProp) -> bool: return WorldProp.same(q, p)), "and it is the one set down")
