extends TestCase
## Interference per plan network: what raises it, what lets it fall, and what
## its levels mean to the machines standing in that region (VISION §2).

const COAST := Country.COAST
const MOSS := Country.MOSS


func _at(net: int = COAST) -> Vector2:
	return Vector2(10.0 + net, 10.0)


func test_causes_raise_the_network_they_happened_in_and_no_other() -> void:
	var f := Interference.new()
	eq(f.value(COAST), 0.0, "nothing has happened")
	eq(f.level_name(COAST), &"calm")
	var rose := f.raise(COAST, &"theft", _at(), 100.0)
	near(rose, Interference.CAUSES[&"theft"], 1e-5, "a theft is worth its own")
	near(f.value(COAST), Interference.CAUSES[&"theft"], 1e-5)
	eq(f.value(MOSS), 0.0, "the moss has heard nothing")


func test_a_dead_worker_costs_more_than_a_theft_and_a_theft_more_than_being_in_the_way() -> void:
	gt(Interference.CAUSES[&"killed_worker"], Interference.CAUSES[&"theft"], "a dead worker")
	gt(Interference.CAUSES[&"theft"], Interference.CAUSES[&"blocked"], "a theft")
	gt(Interference.CAUSES[&"filed"], Interference.CAUSES[&"curfew"], "a filing")


func test_the_same_cause_counts_once_in_a_while_so_one_long_job_is_one_theft() -> void:
	var f := Interference.new()
	f.raise(COAST, &"theft", _at(), 100.0)
	var again := f.raise(COAST, &"theft", _at(), 100.0 + Interference.SAME_CAUSE_GAP * 0.5)
	eq(again, 0.0, "the same theft going on is not a second theft")
	var later := f.raise(COAST, &"theft", _at(), 100.0 + Interference.SAME_CAUSE_GAP + 1.0)
	gt(later, 0.0, "a new one, later, is")


func test_levels_are_read_off_the_thresholds_and_climb_with_what_is_done() -> void:
	var f := Interference.new()
	eq(f.level(COAST), 0)
	var minutes := 0.0
	var causes: Array[StringName] = [&"killed_worker", &"killed_worker", &"killed_worker", &"killed_worker", &"sabotage"]
	var seen: Array[int] = [0]
	for c: StringName in causes:
		minutes += Interference.SAME_CAUSE_GAP + 1.0
		f.raise(COAST, c, _at(), minutes)
		if f.level(COAST) != seen[seen.size() - 1]:
			seen.append(f.level(COAST))
	eq(seen, [0, 1, 2, 3], "calm, wary, hostile, hunted, in that order")
	eq(f.level_name(COAST), &"hunted")


func test_time_lets_it_fall_and_standing_at_the_scene_keeps_it_up() -> void:
	var f := Interference.new()
	f.raise(COAST, &"killed_worker", _at(), 0.0)
	var start := f.value(COAST)
	var far := Interference.new()
	far.raise(COAST, &"killed_worker", _at(), 0.0)
	f.decay(2.0, false, false, COAST, _at())
	far.decay(2.0, false, false, COAST, _at() + Vector2(Interference.COOL_DISTANCE * 1.2, 0))
	lt(f.value(COAST), start, "two hours takes some of it off")
	lt(far.value(COAST), f.value(COAST), "and being a long way off takes more")
	near(start - far.value(COAST), Interference.DECAY_PER_HOUR * 2.0, 1e-4, "at the full rate, far away")


func test_hiding_and_a_misread_signature_let_it_fall_faster() -> void:
	var plain := Interference.new()
	var hidden := Interference.new()
	var spoofed := Interference.new()
	for f: Interference in [plain, hidden, spoofed]:
		f.raise(COAST, &"killed_worker", _at(), 0.0)
	var away := _at() + Vector2(Interference.COOL_DISTANCE * 2.0, 0)
	plain.decay(1.0, false, false, COAST, away)
	hidden.decay(1.0, true, false, COAST, away)
	spoofed.decay(1.0, false, true, COAST, away)
	lt(hidden.value(COAST), plain.value(COAST), "hidden, the file goes cold sooner")
	lt(spoofed.value(COAST), hidden.value(COAST), "and a signature read as one of theirs sooner still")


## The numbers have to let a hunted player win their way out. One dispatch
## cycle (32_disposition.DISPATCH_EVERY, 90 world minutes) costs at most the one
## machine the player kills in it; breaking contact for that long has to take
## off more, or fighting back is a net rise for ever and the only move is to run.
func test_breaking_contact_takes_off_more_than_fighting_back_costs() -> void:
	var cycle := 90.0 / 60.0
	var fighting := Interference.CAUSES[&"killed_machine"]
	var f := Interference.new()
	f.levels[COAST] = 1.0
	f.decay(cycle, false, false, MOSS, _at(MOSS), true)
	lt(f.value(COAST), 1.0 - fighting, "nothing aware of them: the file falls faster than the hunt feeds it")
	var seen := Interference.new()
	seen.levels[COAST] = 1.0
	seen.decay(cycle, false, false, MOSS, _at(MOSS))
	gt(seen.value(COAST), f.value(COAST), "and being watched the whole time does not")


func test_it_never_goes_below_nothing_and_forgets_the_network_when_it_does() -> void:
	var f := Interference.new()
	f.raise(COAST, &"blocked", _at(), 0.0)
	f.decay(100.0, false, false, MOSS, _at(MOSS))
	eq(f.value(COAST), 0.0, "a long time later it is over")
	eq(f.levels.size(), 0, "and the network is off the books")


func test_the_worst_network_is_the_one_that_answers() -> void:
	var f := Interference.new()
	f.raise(COAST, &"theft", _at(), 0.0)
	f.raise(MOSS, &"killed_worker", _at(MOSS), 0.0)
	var w := f.worst()
	eq(int(w[0]), MOSS, "the moss is the hot one")
	near(float(w[1]), f.value(MOSS), 1e-5)


func test_it_survives_a_trip_through_json() -> void:
	var f := Interference.new()
	f.raise(COAST, &"killed_worker", Vector2(12.5, 34.5), 0.0)
	f.raise(MOSS, &"theft", Vector2(80.0, 3.0), 0.0)
	f.lose(MOSS)
	var text := JSON.stringify(f.save())
	var back := Interference.new()
	back.load(JSON.parse_string(text) as Dictionary)
	near(back.value(COAST), f.value(COAST), 1e-5, "the coast comes back")
	near(back.value(MOSS), f.value(MOSS), 1e-5, "and the moss")
	eq(back.scenes[COAST], Vector2(12.5, 34.5), "and where it happened")
	check(back.is_lost(MOSS) and not back.is_lost(COAST),
		"a region whose plant has gone is still gone after a load")


## WHAT BREAKING THE PLAN IS WORTH. `Events.works_broken` and `Events.sentinel_fell`
## were emitted for a whole wave with nothing listening: a player could put a
## depot out and the same region would go on working itself up to hunted and
## sending bodies out of a dark yard. A region with nothing running it is not
## safe — what stands in it still stands — but its file can never climb past
## hostile again, and `32_disposition._dispatch` will not pick a hunter below
## hunted, so nothing more is ever sent from there.
func test_a_region_whose_plant_has_gone_can_never_hunt_again() -> void:
	var f := Interference.new()
	var at := Vector2(40.0, 40.0)
	# Worked all the way up to hunted first, so this is a real climb being capped.
	# Every cause there is: one of each is what it takes (0.88 of the 0.84 a
	# network hunts at), which is itself the measure of how far a player has to go.
	for cause: StringName in Interference.CAUSES:
		f.raise(COAST, cause, at, 0.0)
	eq(f.level(COAST), 3, "a player who did all that is hunted: %.2f" % f.value(COAST))
	f.lose(COAST)
	lt(f.value(COAST), Interference.THRESHOLDS[3], "and the yard going dark takes that off them")
	lt(f.level(COAST), 3, "nothing is left to send")
	# And it cannot be climbed back into, however much is done in that region.
	for cause: StringName in [&"killed_worker", &"sabotage", &"filed", &"killed_machine"]:
		f.raise(COAST, cause, at, 1000.0 * float(cause.length()))
	lt(f.level(COAST), 3, "a dark yard cannot work itself back up to hunting: %.2f" % f.value(COAST))
	# It is not peace, though: a region that has been robbed still stiffens.
	gt(f.value(COAST), Interference.THRESHOLDS[1], "the machines standing in it still read the file")


func test_a_lost_region_cools_faster_than_one_with_a_yard_behind_it() -> void:
	var f := Interference.new()
	f.raise(COAST, &"sabotage", Vector2.ZERO, 0.0)
	f.raise(MOSS, &"sabotage", Vector2.ZERO, 0.0)
	f.lose(MOSS)
	var before := f.value(COAST)
	f.decay(1.0, false, false, -99, Vector2(500.0, 500.0))
	lt(f.value(MOSS), f.value(COAST), "the file with no plant behind it goes cold first")
	lt(f.value(COAST), before, "and the working one cools too, only slower")


## A network is a REGION: one connected run of one landscape type. Two
## snowfields on opposite coasts keep separate files on the player, so robbing
## one does not bring the other down on you. A world with no regions recorded
## (a test world, or a save made before regions existed) still gets one network
## per landscape type rather than none, on ids that cannot collide with a real
## region's.
func test_a_network_is_a_region() -> void:
	var w := WorldData.new(3, 32)
	for i in 32 * 32:
		w.country[i] = Country.COAST
	w.country[5 * 32 + 5] = Country.MOSS
	w.region.resize(32 * 32)
	w.region.fill(1)
	w.regions = [{"id": 0, "type": &"coast", "index": Country.COAST, "tiles": 1023,
		"centre": Vector2.ZERO, "bounds": Rect2()}]
	# Two runs of coast, one region each, are two networks.
	for y in range(20, 32):
		for x in range(20, 32):
			w.region[y * 32 + x] = 2
	w.regions.append({"id": 1, "type": &"coast", "index": Country.COAST, "tiles": 144,
		"centre": Vector2(26, 26), "bounds": Rect2()})
	eq(Interference.network(w, Vector2(1.5, 1.5)), 0)
	eq(Interference.network(w, Vector2(25.5, 25.5)), 1,
		"the far run of the same landscape is its own network")
	# A world with no regions falls back to one network per landscape type, on
	# negative ids, so an old save still reads one file per landscape.
	var bare := WorldData.new(3, 32)
	for i in 32 * 32:
		bare.country[i] = Country.COAST
	bare.country[5 * 32 + 5] = Country.MOSS
	var a := Interference.network(bare, Vector2(1.5, 1.5))
	var b := Interference.network(bare, Vector2(5.5, 5.5))
	lt(a, 0, "a world with no regions gets ids no region can take")
	check(a != b, "and still one network per landscape")
