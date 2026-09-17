extends TestCase
## Where the plan's depots stand in a world that was really generated
## (docs/VISION.md §2). One per REGION the machines are working, found from what
## they already built there, and in the same place on every run of a seed.

const SEEDS: Array[int] = [1, 7]
const SIZE := 256


func test_a_region_the_plan_is_working_has_a_depot_standing_in_it() -> void:
	var any := 0
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var sites := Works.sites(w)
		gt(float(sites.size()), 0.0, "seed %d holds a depot somewhere" % s)
		any += sites.size()
		for site: WorksSite in sites:
			var r := w.region_of(site.region)
			eq(StringName(str(r.get("type", &""))), site.land, "seed %d: a depot is in the land it serves" % s)
			var x := floori(site.pos.x)
			var y := floori(site.pos.y)
			check(w.in_bounds(x, y), "seed %d: region %d's depot is on the map" % [s, site.region])
			check(not Ground.is_water(w.ground_at(x, y)), "seed %d: region %d's depot is not in the sea" % [s, site.region])
			gt(float(w.level_at(x, y)), 0.0, "seed %d: region %d's depot stands on land" % [s, site.region])
			gt(site.pos.distance_to(w.spawn), Works.CLEAR_HOME - 0.01, "a depot keeps clear of where the player wakes")
			for v: Dictionary in w.villages:
				gt(site.pos.distance_to(v.get("pos", Vector2.ZERO)), Works.CLEAR_VILLAGE - 0.01,
					"a depot keeps off a village green")
			# Its three working parts are three separate walks across open ground.
			for i in Works.PART_NAMES.size():
				for j in range(i + 1, Works.PART_NAMES.size()):
					gt(site.part(i).distance_to(site.part(j)), Works.PART_REACH * 2.0,
						"parts %d and %d cannot be reached from one spot" % [i, j])
			print("works seed %d: %s in region %d (%s), %d works in its yard, at %s"
				% [s, site.trade, site.region, site.land, site.yard, site.pos])
	gt(float(any), 1.0, "a world is not one depot")


func test_a_depot_is_in_the_same_place_on_every_run_of_a_seed() -> void:
	var a := Works.sites(WorldGen.generate(3, SIZE))
	var b := Works.sites(WorldGen.generate(3, SIZE))
	eq(b.size(), a.size(), "the same island holds the same number of depots")
	for i in mini(a.size(), b.size()):
		eq(b[i].region, a[i].region, "depot %d serves the same region" % i)
		near(b[i].pos.distance_to(a[i].pos), 0.0, 1e-4, "depot %d stands in the same place" % i)
		eq(b[i].trade, a[i].trade, "depot %d is in the same trade" % i)


func test_a_patrol_route_runs_along_the_survey_the_machines_laid_everything_else_on() -> void:
	var w := WorldGen.generate(1, SIZE)
	var sites := Works.sites(w)
	check(not sites.is_empty(), "there is a depot to walk a round from")
	if sites.is_empty():
		return
	var line := Works.route(sites[0])
	var along := ((line[1] as Vector2) - (line[0] as Vector2)).normalized()
	var survey := Vector2.from_angle(GenWorks.bearing(w.seed_value))
	gt(absf(along.dot(survey)), 0.999, "the round runs on the survey bearing, not across the tiles")
	near((line[0] as Vector2).distance_to(line[1] as Vector2), Works.ROUTE_LENGTH, 0.01, "and it is a round of its own length")


## The start budget is real (docs/ROADMAP.md): finding the depots is a search
## over what the world already recorded, and it must not be a stage a player
## waits through. Scaled by machine_slack, because several builders share this
## laptop and a wall-clock budget taken under load says nothing.
func test_finding_them_costs_nothing_a_player_would_notice() -> void:
	var w := WorldGen.generate(1, 512)
	var t := Time.get_ticks_usec()
	for i in 4:
		var sites := Works.sites(w)
		check(not sites.is_empty(), "there is something to find")
	var ms := (Time.get_ticks_usec() - t) / 4000.0
	print("works: %.2f ms to find every depot in a 512 world" % ms)
	lt(ms, 25.0 * machine_slack(), "finding the depots is not a stage a player waits through")
