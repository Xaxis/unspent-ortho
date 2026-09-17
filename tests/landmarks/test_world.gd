extends TestCase
## The places worth the walk, in worlds that were really generated
## (docs/VISION.md §3, §8): enough of them, in the right landscapes, standing
## somewhere a player can walk to, and in the same place on every run of a seed.

const SEEDS: Array[int] = [1, 7]
const SIZE := 256


func test_every_landscape_declares_three_kinds_or_more_and_they_all_hold_up() -> void:
	var ids: Array = []
	for d: BiomeDef in BiomeRegistry.all():
		ids.append(d.id)
	var bad := Landmarks.problems(ids)
	check(bad.is_empty(), "\n  ".join(bad))


func test_a_world_holds_landmarks_and_each_stands_on_ground_a_player_can_reach() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var sites := Landmarks.sites(w)
		gt(float(sites.size()), 3.0, "seed %d holds places worth the walk" % s)
		var by_land := {}
		for site: LandmarkSite in sites:
			by_land[site.land] = int(by_land.get(site.land, 0)) + 1
			var def := site.def()
			check(def != null, "seed %d: %s names a kind that exists" % [s, site.kind])
			check(def.lands.has(site.land) or not BiomeRegistry.get_def(site.land).landmarks.is_empty(),
				"seed %d: %s stands in %s, which is not one of its landscapes" % [s, site.kind, site.land])
			var x := floori(site.pos.x)
			var y := floori(site.pos.y)
			check(w.in_bounds(x, y), "seed %d: %s is on the map" % [s, site.id])
			check(not Ground.is_water(w.ground_at(x, y)), "seed %d: %s is not in the water" % [s, site.id])
			gt(site.pos.distance_to(w.spawn), Landmarks.CLEAR_HOME - 0.01,
				"seed %d: %s is not at the player's feet on the first morning" % [s, site.id])
			# REACHABILITY: its cache is on ground a body can stand on, or the
			# place cannot be opened at all.
			var c := Landmarks.cache_of(site)
			var cx := floori(c.x)
			var cy := floori(c.y)
			check(not Ground.is_water(w.ground_at(cx, cy)), "seed %d: %s's cache is in the water" % [s, site.id])
			gt(float(w.level_at(cx, cy)), 0.0, "seed %d: %s's cache is above the tide" % [s, site.id])
		print("landmarks seed %d: %d in all, %s" % [s, sites.size(), by_land])
		# Every landscape a world really holds a run of carries at least two.
		for region: Dictionary in w.regions:
			if int(region.get("tiles", 0)) < 2000:
				continue
			var land := StringName(str(region.get("type", &"")))
			if BiomeRegistry.get_def(land) == null or BiomeRegistry.get_def(land).sea:
				continue
			gt(float(by_land.get(land, 0)), 1.0, "seed %d: %s is worth crossing" % [s, land])


func test_they_stand_in_the_same_places_on_every_run_of_a_seed() -> void:
	var a := Landmarks.sites(WorldGen.generate(3, SIZE))
	var b := Landmarks.sites(WorldGen.generate(3, SIZE))
	eq(b.size(), a.size(), "the same island holds the same number of them")
	for i in mini(a.size(), b.size()):
		eq(b[i].id, a[i].id, "landmark %d is the same one" % i)
		near(b[i].pos.distance_to(a[i].pos), 0.0, 1e-4, "and stands in the same place")
		near(b[i].facing, a[i].facing, 1e-4, "turned the same way")


func test_no_two_landmarks_are_on_top_of_each_other_or_on_a_village() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var sites := Landmarks.sites(w)
		for i in sites.size():
			for j in range(i + 1, sites.size()):
				gt(sites[i].pos.distance_to(sites[j].pos), 20.0,
					"seed %d: %s and %s are two silhouettes on one hill" % [s, sites[i].id, sites[j].id])
			for v: Dictionary in w.villages:
				gt(sites[i].pos.distance_to(v.get("pos", Vector2.ZERO)), Landmarks.CLEAR_VILLAGE - 0.01,
					"seed %d: %s is standing in a village" % [s, sites[i].id])


## A landmark is READ before it is reached: the distance a kind claims to be
## visible from is further than the distance at which the game says what it is.
func test_a_landmark_is_seen_before_it_is_named() -> void:
	for d: LandmarkDef in Landmarks.all():
		gt(d.sees, Landmarks.FOUND_AT, "%s is read off the horizon before it is named" % d.id)
		gt(d.sees, 18.0, "%s can be read from twenty tiles, which is what a landmark is" % d.id)


## The start budget is real (docs/ROADMAP.md): siting them is a search over a
## region's bounds and it must not be a stage a player waits through.
func test_siting_them_costs_nothing_a_player_would_notice() -> void:
	var w := WorldGen.generate(1, 512)
	var t := Time.get_ticks_usec()
	for i in 3:
		# The answer is remembered per island, so the measurement has to forget it
		# or it times a dictionary lookup and says the sweep is free.
		Landmarks.forget()
		var sites := Landmarks.sites(w)
		check(not sites.is_empty(), "there is something to find")
	var ms := (Time.get_ticks_usec() - t) / 3000.0
	print("landmarks: %.2f ms to site every landmark in a 512 world (cold)" % ms)
	lt(ms, 90.0 * machine_slack(), "siting them is not a stage a player waits through")
	# And a second ask costs nothing, which is what lets the system, the map and a
	# shot's --place all want the list without paying for it three times.
	var t2 := Time.get_ticks_usec()
	for i in 20:
		@warning_ignore("return_value_discarded")
		Landmarks.sites(w)
	lt((Time.get_ticks_usec() - t2) / 20000.0, 1.0, "asking again is free")
