extends TestCase
## A lid over a landscape, and the light that gets through where it is torn
## (`BiomeDef.sky_shut`, `Dome`, `SkyLight.LID_*`).
##
## Arithmetic, not frames: the frames are tours/slums-dome.tour's job. Everything
## here is a SILENT failure — a tear that moved between two runs of one seed, a
## lid that let the hour back into the street, a lid that snapped at a border —
## and every one of them looks like somebody's grading choice rather than a bug.

const NOON := 12.0
const MIDNIGHT := 0.0


# --- the tears are a property of the world ---------------------------------

func test_a_tear_is_in_the_same_place_on_every_run_of_a_seed() -> void:
	# Nothing about the dome is saved, so this is the only thing that keeps a
	# street lit the same way twice. A hash drawn from a sequence rather than a
	# position would pass every other test in this file and fail here.
	var a := Dome.tears(4242, Vector2(180.0, 96.0), 40.0)
	var b := Dome.tears(4242, Vector2(180.0, 96.0), 40.0)
	eq(a.size(), b.size(), "the same seed deals the same number of tears")
	check(not a.is_empty(), "a 40-tile sweep finds at least one tear")
	for i in a.size():
		check(a[i].is_equal_approx(b[i]), "tear %d is in the same place" % i)


func test_two_seeds_do_not_make_the_same_city() -> void:
	var a := Dome.tears(11, Vector2(200.0, 200.0), 60.0)
	var b := Dome.tears(12, Vector2(200.0, 200.0), 60.0)
	var same := 0
	for p: Vector2 in a:
		for q: Vector2 in b:
			if p.is_equal_approx(q):
				same += 1
	check(same < a.size(), "seed 12 is not seed 11's dome")


func test_a_sweep_finds_every_tear_inside_its_reach_and_none_outside() -> void:
	var at := Vector2(300.0, 140.0)
	var reach := 45.0
	for p: Vector2 in Dome.tears(7, at, reach):
		check(p.distance_to(at) <= reach + 0.001, "a tear it returned is inside the reach")
	# The jitter can carry a tear a long way out of its own cell, so the sweep has
	# to look wider than the radius. Under-sweeping is invisible: a shaft simply
	# pops into being when the player walks a little nearer.
	var wide := Dome.tears(7, at, reach * 2.0)
	var near := Dome.tears(7, at, reach)
	for p: Vector2 in wide:
		if p.distance_to(at) > reach:
			continue
		var found := false
		for q: Vector2 in near:
			if p.is_equal_approx(q):
				found = true
		check(found, "the narrow sweep did not miss a tear at %.1f tiles" % p.distance_to(at))


# --- and the light through them belongs to the hour ------------------------

func test_the_patch_moves_across_the_street_over_a_day() -> void:
	# This is the whole point of the feature and the one thing a tour cannot say
	# cheaply: a player who learns the city learns where the light falls and when.
	var tear := Vector2(120.0, 120.0)
	var seen: Array[Vector2] = []
	for h: float in [8.0, 10.0, 12.0, 14.0, 16.0]:
		var s := SkyLight.sun_at(h)
		seen.append(Dome.patch(tear, float(s.azimuth), float(s.elevation)))
	for i in seen.size() - 1:
		gt(seen[i].distance_to(seen[i + 1]), 0.2, "the pool moved between two hours")
	gt(seen[0].distance_to(seen[seen.size() - 1]), 3.0, "and it is somewhere else by teatime")


func test_the_patch_is_down_sun_of_its_tear_and_never_on_top_of_it() -> void:
	# A pool directly under the hole would mean the sun was overhead, which this
	# game's sun never is (`_elevation_for_shadow` picks an elevation for a SCREEN
	# shadow length). If this ever reads zero the shaft has stopped being lit from
	# a direction and has become a downlight.
	var tear := Vector2(64.0, 64.0)
	var s := SkyLight.sun_at(NOON)
	var p := Dome.patch(tear, float(s.azimuth), float(s.elevation))
	gt(p.distance_to(tear), 1.0, "the light lands away from the hole it came through")


# --- the lid itself ---------------------------------------------------------

func test_a_landscape_with_no_lid_pays_nothing_for_this_existing() -> void:
	# Every landscape but one has `sky_shut` 0, and the whole feature has to be
	# invisible to them or it is a global change wearing a local name.
	eq(SkyLight.sky_shut_at({&"coast": 1.0}), 0.0, "the coast is under the open sky")
	for d: BiomeDef in BiomeRegistry.land():
		check(d.sky_shut >= 0.0 and d.sky_shut <= 1.0,
			"%s asks for a lid of %.2f, which is not 0..1" % [d.id, d.sky_shut])


func test_a_lid_is_blended_across_a_border_and_never_snaps() -> void:
	# The same rule as the night, the grade, the air and the score: a lid that
	# snapped at a border would draw the ecotone as a line across the frame, and
	# this is the one of the five spent at EVERY hour, so it would show at noon.
	var shut: float = BiomeRegistry.get_def(&"slums").sky_shut
	var half := SkyLight.sky_shut_at({&"slums": 0.5, &"coast": 0.5})
	check(half > 0.0 and half < shut, "half a frame of slums is half a lid, not all or nothing")
	var mostly := SkyLight.sky_shut_at({&"slums": 0.9, &"coast": 0.1})
	gt(mostly, half, "and more of it is more lid")


func test_the_hour_barely_reaches_a_street_under_a_lid() -> void:
	# The claim tours/slums-dome.tour makes in pixels, made here in the numbers
	# the renderer is actually driven by. Relational on purpose: what matters is
	# not what the slums measures but that a day costs it far less than it costs
	# the landscape this game's night was calibrated on.
	var open_day := SkyLight.frame_level(NOON, Vector3.ONE, Vector3.ONE, 0.0)
	var open_night := SkyLight.frame_level(MIDNIGHT, Vector3.ONE, Vector3.ONE, 0.0)
	var shut: float = BiomeRegistry.get_def(&"slums").sky_shut
	var lid_day := SkyLight.frame_level(NOON, Vector3.ONE, Vector3.ONE, shut)
	var lid_night := SkyLight.frame_level(MIDNIGHT, Vector3.ONE, Vector3.ONE, shut)
	var open_swing := absf(open_day - open_night) / maxf(open_night, 0.0001)
	var lid_swing := absf(lid_day - lid_night) / maxf(lid_night, 0.0001)
	lt(lid_swing, open_swing * 0.5,
		"a day costs a shut street %.2f of its night and an open one %.2f" % [lid_swing, open_swing])
	lt(lid_day, open_day, "and noon under a lid is darker than noon without one")


func test_the_slums_keeps_its_own_colour_and_never_goes_to_the_night_key() -> void:
	# `SkyLight.closed` eases the TINT to the night key, which is blue, and that
	# is right for a cave. Doing it for a smog dome would take the sodium out of
	# the one landscape whose whole argument is that it is orange, so the lid is
	# deliberately absent from `last_tint`. If somebody ever adds it there, this
	# is the line that says why not.
	#
	# It is the one test here that catches a future GOOD IDEA rather than a bug:
	# the next person to read `sky_shut` will reasonably think "closed eases the
	# tint, so the lid should too", and it is a one-line change that would turn
	# the Slums blue without failing anything else.
	var d := BiomeRegistry.get_def(&"slums")
	gt(d.light_tint.r, d.light_tint.b, "the slums lights itself warm")
	var lit := SkyLight.type_light(d, NOON)
	gt(lit.x, lit.z, "and its composed light is warm at noon, not blue")
