extends TestCase
## The judge on `--stats`, held to judging (docs/PERF.md, task #126).
##
## THIS EXISTS BECAUSE THE JUDGE WAS WRONG IN THE DIRECTION THAT HIDES WORK.
## `frame_line` took its percentiles over every frame of a run including the
## warm-up, so a run measuring p95 9.3 and p99 12.9 in steady play -- both well
## inside budget -- printed `PERF FAIL` on the strength of frame 0 being 150 ms.
## docs/PERF.md has always bounded warm-up separately, and the instrument did not
## make the split the document promised.
##
## An instrument that cannot report a pass is worse than one that prints nothing,
## because it teaches the reader to discount it, and after that it cannot report
## a real failure either.

const Landscape := preload("res://src/systems/12_landscape.gd")

## A steady run: 8 ms everywhere, which is inside every budget.
static func _steady(n: int, ms: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		out.append(ms)
	return out


func test_the_frames_a_world_lands_in_are_warm_up_and_not_the_run() -> void:
	var run := _steady(200, 8.0)
	run[0] = 150.0
	run[1] = 120.0
	check(Landscape.warm_frames(run) == 2,
		"two slow frames at the head are warm-up, got %d" % Landscape.warm_frames(run))
	var line := Landscape.frame_line(run)
	check(line.contains("PERF OK"), "a run that is 8 ms after it lands passes: %s" % line)
	check(line.contains("+2 warm-up"), "the warm-up is still reported, not hidden: %s" % line)


func test_a_spike_in_the_body_of_the_run_is_never_warm_up() -> void:
	# The same 150 ms frame, moved off the head. A player lives with this one.
	var run := _steady(200, 8.0)
	run[120] = 150.0
	check(Landscape.warm_frames(run) == 0, "nothing at the head is nothing to forgive")
	var line := Landscape.frame_line(run)
	check(not line.contains("PERF OK"), "a hitch in steady play must fail: %s" % line)
	check(line.contains("120:150"), "and it must say WHERE: %s" % line)


func test_a_run_cannot_call_itself_warm_up_all_the_way_through() -> void:
	# The escape hatch this rule needs, or a wholly broken run passes by being
	# classified as one long warm-up. A prefix past the allowance is a failure.
	var run := _steady(200, 40.0)
	check(Landscape.warm_frames(run) <= Landscape.WARM_MOST + 1,
		"the warm-up prefix is capped, got %d" % Landscape.warm_frames(run))
	var line := Landscape.frame_line(run)
	check(not line.contains("PERF OK"), "40 ms forever is not a warm-up: %s" % line)


func test_warm_up_is_bounded_rather_than_exempt() -> void:
	# docs/PERF.md: no more than WARM_MOST frames over, and none over the ceiling.
	# A loading screen that is not over is still a loading screen.
	var run := _steady(200, 8.0)
	run[0] = Landscape.WARM_CEILING_MS + 50.0
	var line := Landscape.frame_line(run)
	check(not line.contains("PERF OK"), "a warm-up frame past the ceiling fails: %s" % line)
	check(line.contains("warm-up ceiling"), "and is named as the warm-up's fault: %s" % line)


## THE BUDGETS ARE REFRESH INTERVALS, AND TWO OF THEM WERE WRITTEN JUST UNDER THE
## INTERVAL THEY NAME.
##
## 120 Hz is 1000/120 = 8.3333 ms, and `P50_MS` was 8.3 — so a run whose frame
## pacer delivers a PERFECT 120 fps failed its own 120 Hz budget by three
## hundredths of a millisecond, and printed "p50 8.3 ms ... PERF FAIL: p50",
## which reads as a broken printer rather than a bar set below its own target.
## `WORST_MS` 33.3 was the same against 30 Hz's 33.333.
##
## Measured 2026-09-20: the populated walk at `--quality=low` returns
## p50 = p95 = p99 = 8.3 — a locked 120 Hz, the best result this judge can ever
## be shown — and it was reported as a failure.
##
## p95 (13.9 against 72 Hz's 13.889) and p99 (16.7 against 60 Hz's 16.667) round
## the other way and were always reachable, which is why this went unseen: half
## the table worked.
##
## Note what a run pinned at 72 Hz SHOULD do: fail p50, because p50 names 120 Hz
## and 72 is slower. The first version of this test asserted every rate passes
## everything and was wrong about three of its four rows.
func test_every_budget_is_reachable_at_the_rate_it_names() -> void:
	# The invariant, stated against the constants rather than a run, so it holds
	# for a budget nobody has a frame for yet. A budget that names a refresh rate
	# has to be AT LEAST that rate's interval, or the rate it names cannot pass it.
	for row: Array in [[Landscape.P50_MS, 120.0, "p50"], [Landscape.P95_MS, 72.0, "p95"],
			[Landscape.P99_MS, 60.0, "p99"], [Landscape.WORST_MS, 30.0, "worst"]]:
		var budget: float = row[0]
		var rate: float = row[1]
		var interval := 1000.0 / rate
		check(budget >= interval,
			"%s names %.0f Hz, which is %.4f ms, but the budget is %.4f -- %.0f Hz can never pass it"
				% [String(row[2]), rate, interval, budget, rate])


func test_a_run_pinned_at_120_hz_passes_every_budget() -> void:
	# The best result this judge can ever be shown: a frame pacer delivering a
	# perfect 120 fps. Measured 2026-09-20, the populated walk at --quality=low
	# returns p50 = p95 = p99 = 8.3, and it was reported as PERF FAIL: p50.
	var line := Landscape.frame_line(_steady(200, 1000.0 / 120.0))
	check(line.contains("PERF OK"), "a locked 120 fps is not a failure: %s" % line)
