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
	f.decay(4.0, false, false, COAST, _at())
	far.decay(4.0, false, false, COAST, _at() + Vector2(Interference.COOL_DISTANCE * 1.2, 0))
	lt(f.value(COAST), start, "four hours takes some of it off")
	lt(far.value(COAST), f.value(COAST), "and being a long way off takes more")
	near(start - far.value(COAST), Interference.DECAY_PER_HOUR * 4.0, 1e-4, "at the full rate, far away")


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
	var text := JSON.stringify(f.save())
	var back := Interference.new()
	back.load(JSON.parse_string(text) as Dictionary)
	near(back.value(COAST), f.value(COAST), 1e-5, "the coast comes back")
	near(back.value(MOSS), f.value(MOSS), 1e-5, "and the moss")
	eq(back.scenes[COAST], Vector2(12.5, 34.5), "and where it happened")


func test_a_network_is_a_region_and_for_now_that_is_a_country() -> void:
	var w := WorldData.new(3, 32)
	for i in 32 * 32:
		w.country[i] = Country.COAST
	w.country[5 * 32 + 5] = Country.MOSS
	eq(Interference.network(w, Vector2(1.5, 1.5)), Country.COAST)
	eq(Interference.network(w, Vector2(5.5, 5.5)), Country.MOSS, "over the border is another network")
