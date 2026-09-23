extends TestCase
## Where a keeper stands in a world that was really generated, and what its fall
## changes. One instance per REGION (docs/VISION.md, CLAUDE.md's Regions row),
## so every run of a landscape has its own keeper and the second one is the same
## species and a different fight.

## THREE, because two stopped being enough evidence rather than because the bar
## was too high. `test_it_stands_at_its_regions_works_where_there_is_one` counts
## the keepers it really asked about, and once the regions whose only works lie
## inside `CLEAR_OF_HOME` were correctly exempted, two seeds offered three of
## them against a bar of more than three. The answer to a counter that has gone
## thin is a bigger sample, never a smaller bar.
const SEEDS: Array[int] = [1, 7, 3]
const SIZE := 256


func test_every_region_of_a_landscape_with_a_keeper_has_one_standing_in_it() -> void:
	Sentinels.declare_loot()
	# Which designs the three seeds placed at all. Every keeper land used to be
	# asked for on EVERY seed, which was true while the keeper lands were the
	# coast (guaranteed on every continent) and the flats, and became a claim
	# about the dealer the moment a landscape with a five-percent share got a
	# keeper. Measured, seed 1 at 256: the glass desert's biggest run is 445
	# tiles with its heart 29 tiles from the spawn, and `Sentinels.lair` refuses
	# it whole — nowhere in it is CLEAR_OF_HOME (48) from where the player
	# wakes, which is the safety rule winning, as it must. Seeds 7 and 3 both
	# place the anvil. So the claim is what the test's name says — every region
	# the siting rule can keep has its keeper — plus one that still fails for a
	# design no seed ever places.
	var placed := {}
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
			var biggest := 0
			var big: Dictionary = {}
			for r: Dictionary in w.regions:
				if StringName(str(r.get("type", &""))) == land and int(r.get("tiles", 0)) > biggest:
					biggest = int(r.get("tiles", 0))
					big = r
			var centre: Vector2 = big.get("centre", Vector2.ZERO)
			if biggest < Sentinels.MIN_TILES:
				print("sentinel seed %d: %s holds no region big enough to keep (biggest run %d tiles, floor %d)"
					% [s, land, biggest, Sentinels.MIN_TILES])
			elif not Sentinels.lair(w, big, Sentinels.for_land(land)).is_finite():
				# The siting rule refused the whole region: nowhere in it is far
				# enough from where the player wakes. Said with the numbers, so a
				# region refused for a new reason reads differently here.
				print("sentinel seed %d: %s's biggest run (%d tiles, heart %s, %.1f from the spawn %s) is all inside CLEAR_OF_HOME %.0f: no keeper, by the rule"
					% [s, land, biggest, centre, centre.distance_to(w.spawn), w.spawn, Sentinels.CLEAR_OF_HOME])
			else:
				check(lands.has(land), "seed %d: %s has its keeper out there (biggest run %d tiles at %s)" % [s, land, biggest, centre])
			if lands.has(land):
				placed[land] = true
	for land: StringName in Sentinels.lands():
		check(placed.has(land), "%s's keeper is placed on at least one of seeds %s at %d" % [land, SEEDS, SIZE])


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
			# **ONLY THE STATIONS THE SITING RULE COULD HAVE CHOSEN.** A keeper may
			# never stand within `CLEAR_OF_HOME` of where the player wakes — that
			# is a floor, not a preference, and `Sentinels.lair` drops a station
			# inside it whatever kind it is. This asked about every station in the
			# region, so a region whose only work is near the spawn demanded the
			# keeper stand somewhere it is forbidden to stand: measured on seed 7
			# at 256, region 0's one `turf_rows` is 24.4 tiles from the spawn
			# against a floor of 48, the rule rejected it, the keeper went to the
			# region's heart 51 tiles away, and this called that a placement bug.
			# Two rules that genuinely conflict, and the safety one wins.
			var station := Vector2.INF
			var kind := &""
			var best := INF
			var barred := 0
			for m: Dictionary in w.landmarks:
				var mk := StringName(str(m.get("kind", &"")))
				if not def.stations.has(mk):
					continue
				var p: Vector2 = m.pos
				if w.region_at(floori(p.x), floori(p.y)) != st.region:
					continue
				if Sentinels.stand_near(w, p).distance_to(w.spawn) < Sentinels.CLEAR_OF_HOME:
					barred += 1
					continue
				var d := p.distance_to(st.lair)
				if d < best:
					best = d
					station = p
					kind = mk
			if not station.is_finite():
				# A run of land with none of the plan's works its keeper may stand
				# at: it keeps the region's heart, which is all there is to keep.
				print("sentinel seed %d: %s keeps region %d from its heart (%d works in it, all inside CLEAR_OF_HOME)"
					% [s, st.design, st.region, barred])
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


## WHAT IT EATS HAS TO STAND IN ITS OWN LAND, IN A REAL WORLD.
##
## The test above builds the works itself "so the count is known by construction",
## which is why it could not see this: measured on three seeds, the coast's keeper
## fed on ONE prop. `tide_reaper.feeds` names INTAKE, PUMP_HOUSE, PIPE and RELAY,
## and `test_world_gen_works.HOME` gives pump houses to the moss and relays to the
## pinewood -- so three quarters of its diet stood where it could never reach, and
## the fourth was the single intake it dens on. `SentinelWay.STARVE` refuses to
## open when nothing feeds a keeper, and at one prop it opened and was won by
## robbing one thing: the design's own line, "The intake feeds it. Rob the
## intake", was a sentence about a world that did not exist.
##
## So the bar is not "more than none". It is "enough that robbing its larder is a
## task", and it is asked of the world world gen actually makes.
func test_a_keeper_has_enough_to_eat_where_it_actually_stands() -> void:
	for s: int in [1, 4, 42]:
		var w := WorldGen.generate(s, 512)
		for region: Dictionary in w.regions:
			var def := Sentinels.for_land(StringName(str(region.get("type", &""))))
			if def == null or def.feeds.is_empty():
				continue
			var has_starve := false
			for way: SentinelWay in def.ways:
				if way.kind == SentinelWay.STARVE:
					has_starve = true
			if not has_starve:
				continue
			var lair := Sentinels.lair(w, region, def)
			var fed := Sentinels.feeds(w, lair, def)
			# NONE IS ALLOWED AND ONE IS NOT. A region with nothing of the plan in
			# it closes the way itself (`SentinelWay.progress`: a way with no larder
			# "must never read as already won because there is nothing to break"),
			# and that keeper is taken by force or foundering instead. What must not
			# happen is the way standing OPEN on a larder so small that one press
			# wins it, which is what the coast had.
			if fed == 0:
				continue
			gt(fed, STARVE_LEAST - 1,
				"seed %d: the %s keeper's starve way is open on %d works, which is %s"
					% [s, def.land, fed, "one theft" if fed <= 1 else "too small a task"])


## The fewest works a keeper may feed on and still have starving mean something.
## Under this, robbing its larder is one or two presses and the way is won by
## accident rather than chosen.
const STARVE_LEAST := 4
