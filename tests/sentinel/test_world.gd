extends TestCase
## Where a keeper stands in a world that was really generated, and what its fall
## changes. One instance per REGION (docs/VISION.md §3, CLAUDE.md's Regions row),
## so every run of a landscape has its own keeper and the second one is the same
## species and a different fight.

const SEEDS: Array[int] = [1, 7]
const SIZE := 256


func test_every_region_of_a_landscape_with_a_keeper_has_one_standing_in_it() -> void:
	Sentinels.declare_loot()
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var states := Sentinels.states(w)
		gt(float(states.size()), 1.0, "seed %d holds keepers" % s)
		var lands := {}
		for st: SentinelState in states:
			var def := Sentinels.by_id(st.design)
			check(def != null, "seed %d: region %d names a design" % [s, st.region])
			lands[st.land] = true
			var r := w.region_of(st.region)
			eq(StringName(str(r.type)), st.land, "seed %d: region %d is the land its keeper keeps" % [s, st.region])
			# It stands somewhere a body three tiles wide can stand.
			var x := floori(st.lair.x)
			var y := floori(st.lair.y)
			check(w.in_bounds(x, y), "seed %d: region %d's keeper is on the map" % [s, st.region])
			check(not Ground.is_water(w.ground_at(x, y)), "seed %d: region %d's keeper is not in the sea (%s)"
				% [s, st.region, Ground.NAMES[w.ground_at(x, y)]])
			gt(float(w.level_at(x, y)), 0.0, "seed %d: region %d's keeper stands on land" % [s, st.region])
			eq(st.health, st.max_health, "a keeper nobody has met is whole")
			check(not st.fallen, "and still keeps its region")
			print("sentinel seed %d: %s keeps region %d (%d tiles) at %s, ground %s, %d works feeding it"
				% [s, st.design, st.region, int(r.tiles), st.lair, Ground.NAMES[w.ground_at(x, y)],
					Sentinels.feeds(w, st.lair, Sentinels.by_id(st.design))])
		for land: StringName in Sentinels.lands():
			check(lands.has(land), "seed %d: %s has its keeper out there" % [s, land])


func test_where_it_stands_is_the_same_on_every_run_of_the_same_seed() -> void:
	var a := WorldGen.generate(1, SIZE)
	var b := WorldGen.generate(1, SIZE)
	var sa := Sentinels.states(a)
	var sb := Sentinels.states(b)
	eq(sa.size(), sb.size(), "the same world holds the same keepers")
	for i in sa.size():
		eq(sa[i].region, sb[i].region, "keeper %d keeps the same region" % i)
		eq(sa[i].lair, sb[i].lair, "and stands in the same place, so it can be walked to twice")


## A keeper keeps the plan's own work where its region holds one: that is what a
## player finds it at, and what a tour walks to by name.
func test_it_stands_at_its_regions_works_where_there_is_one() -> void:
	var at_works := 0
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		for st: SentinelState in Sentinels.states(w):
			var def := Sentinels.by_id(st.design)
			# Does this region hold one of the works its keeper keeps at all?
			var station := Vector2.INF
			var kind := &""
			var best := INF
			for m: Dictionary in w.landmarks:
				var mk := StringName(str(m.get("kind", &"")))
				if not def.stations.has(mk):
					continue
				var p: Vector2 = m.pos
				if w.region_at(floori(p.x), floori(p.y)) != st.region:
					continue
				var d := p.distance_to(st.lair)
				if d < best:
					best = d
					station = p
					kind = mk
			if not station.is_finite():
				# A run of land with none of the plan's works in it: its keeper
				# stands at the region's heart, which is all there is to keep.
				print("sentinel seed %d: %s keeps region %d from its heart, no works in it" % [s, st.design, st.region])
				continue
			at_works += 1
			lt(station.distance_to(st.lair), 13.0,
				"seed %d: %s stands at the %s it keeps (%s, works at %s)" % [s, st.design, kind, st.lair, station])
			print("sentinel seed %d: %s stands at a %s" % [s, st.design, kind])
	gt(float(at_works), 3.0, "keepers were found standing at real works on both seeds (%d)" % at_works)


func test_a_keeper_holds_the_ground_inside_its_reach_until_it_falls() -> void:
	var w := WorldGen.generate(1, SIZE)
	var states := Sentinels.states(w)
	var st: SentinelState = states[0]
	var def := Sentinels.by_id(st.design)
	check(st.holds(st.lair, def.reach), "it holds where it stands")
	check(st.holds(st.lair + Vector2(def.reach - 2.0, 0.0), def.reach), "and out to its reach")
	check(not st.holds(st.lair + Vector2(def.reach + 6.0, 0.0), def.reach), "and no further")
	st.fallen = true
	st.how = &"force"
	check(not st.holds(st.lair, def.reach), "once it has fallen it holds nothing, not even the ground it lies on")
	check(not st.alive(), "and it is no longer the region's keeper")


func test_a_fall_is_remembered_across_a_save_and_the_keeper_never_comes_back() -> void:
	var w := WorldGen.generate(1, SIZE)
	var st: SentinelState = Sentinels.states(w)[0]
	st.health = 4
	st.phase = 2
	st.woken = true
	st.fallen = true
	st.how = &"founder"
	st.hulk_laid = true
	var back := SentinelState.from_save(JSON.parse_string(JSON.stringify(st.save())))
	eq(back.region, st.region, "the region it kept")
	eq(back.design, st.design, "the design")
	eq(back.health, 4, "what it was down to")
	eq(back.phase, 2, "the phase it reached")
	eq(back.how, &"founder", "and which way took it")
	check(back.fallen and back.hulk_laid, "a fallen keeper comes back fallen, with its wreck already laid")
	eq(back.lair, st.lair, "and the wreck is where it fell")


func test_what_feeds_it_is_the_plans_works_near_it_and_robbing_them_counts() -> void:
	var w := WorldGen.generate(1, SIZE)
	var def := Sentinels.for_land(&"coast")
	# A keeper with its own works laid round it, so the count is known by construction.
	var at := Vector2(40.5, 40.5)
	var props: Array[WorldProp] = []
	for i in 3:
		props.append(WorldProp.new(i, def.feeds[0], at + Vector2(2.0 + i, 0.0), 0.0, 1.0))
	props.append(WorldProp.new(9, PropKind.BOULDER, at + Vector2(1.0, 1.0), 0.0, 1.0))
	eq(Sentinels.feeds_among(props, at, def, {}, 20.0), 3, "the three works feed it; the boulder does not")
	eq(Sentinels.feeds_among(props, at, def, {1: INF}, 20.0), 2, "one robbed and it is down to two")
	eq(Sentinels.feeds_among(props, at, def, {}, 2.5), 1, "and only what stands inside its reach counts")
	check(Sentinels.feeds(w, Vector2(1.5, 1.5), def) >= 0, "asking the world for it costs nothing")
