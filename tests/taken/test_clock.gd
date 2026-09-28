extends TestCase
## THE 71 HOURS (docs/STORY.md; slice 1 step 6). The plan runs the minds of the
## people it holds, and running a mind replaces it: got out inside RUN_HOURS a
## person comes back whole, after it they come back empty, and past GONE_HOURS
## they do not come back at all. Pure, on the record, in world minutes.

const H := 60.0


func _held(t: Taken, region: int, taken_at: float) -> Taken.TakenPerson:
	return t.take(3, "", 1, "Oyster Row", region, taken_at)


func test_got_out_inside_the_hours_they_come_back_whole() -> void:
	var t := Taken.new()
	var p := _held(t, 7, 100.0)
	var out := t.free_region(7, 100.0 + (Taken.RUN_HOURS - 1.0) * H)
	eq(out.size(), 1, "freed")
	check(not p.empty, "an hour inside the run, whole")
	near(p.freed_at, 100.0 + (Taken.RUN_HOURS - 1.0) * H, 1e-3, "and when they walked out is kept")


func test_got_out_after_the_hours_they_come_back_empty() -> void:
	var t := Taken.new()
	var p := _held(t, 7, 100.0)
	var _f := t.free_region(7, 100.0 + (Taken.RUN_HOURS + 1.0) * H)
	check(p.freed and p.empty, "an hour past the run, out, and empty")


func test_left_past_the_last_of_it_they_do_not_come_back_at_all() -> void:
	var t := Taken.new()
	var early := _held(t, 7, 0.0)
	var late := _held(t, 7, 50.0 * H)
	var now := (Taken.GONE_HOURS + 1.0) * H
	var gone := t.run_out(now)
	eq(gone.size(), 1, "only the one held past the last of it")
	check(early.gone and not early.freed, "gone, and not out")
	check(early.lost and early.lost_to == &"" and not early.at.is_finite(), "lost as the road's lost are, to nobody, nowhere")
	check(not late.gone, "the one taken later is still there to be got out")
	eq(t.held_in(7).size(), 1, "the gone are no longer held there")
	check(t.holds_anyone(7), "the yard still holds the other")
	eq(t.run_out(now).size(), 0, "and nobody goes twice")
	var out := t.free_region(7, now)
	eq(out.size(), 1, "putting the yard dark then frees only who is still in it")
	check(out[0] == late and late.empty, "and they come back empty: they were past the run too")


func test_a_freed_person_is_never_run_out_after() -> void:
	var t := Taken.new()
	var p := _held(t, 7, 0.0)
	var _f := t.free_region(7, 10.0 * H)
	eq(t.run_out((Taken.GONE_HOURS + 10.0) * H).size(), 0, "out is out")
	check(not p.gone and not p.empty, "and whole")


func test_without_a_clock_a_freed_person_is_whole() -> void:
	var t := Taken.new()
	var p := _held(t, 7, 0.0)
	var _f := t.free_region(7)
	check(p.freed and not p.empty, "a caller with no clock frees them whole, as before the hours were kept")


func test_the_hours_survive_a_save() -> void:
	var t := Taken.new()
	var a := _held(t, 7, 0.0)
	var b := _held(t, 8, 0.0)
	var _g := t.run_out((Taken.GONE_HOURS + 1.0) * H)
	a.empty = true
	var back := Taken.new()
	back.load_from(JSON.parse_string(JSON.stringify(t.save())))
	check(back.people[0].gone and back.people[1].gone, "gone comes back gone")
	check(back.people[0].empty, "empty comes back empty")
	eq(b.freed_at, INF, "never freed is INF")
	eq(back.people[1].freed_at, INF, "and INF survives the round trip")
