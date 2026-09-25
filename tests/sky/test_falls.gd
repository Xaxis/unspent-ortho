extends TestCase
## Debris falling through the sky (src/core/sky/fall_schedule.gd, 21_falls):
## when a piece comes down is a pure function of the seed and the clock, a skip
## fires nothing, falls crowd round the ring's passes, every one of them comes
## in from the same radiant, and each class keeps its own share and shape.
##
## What only a real frame can answer -- a streak on the glass, a breakup, a
## train twisting in the sunset -- is asked of the live frame by 21_falls
## (`tour_seen` &"fall", &"fall_breakup", &"fall_train", &"fall_flash") in
## tours/falls_sky.tour and tours/falls_top.tour.

const Sched := preload("res://src/core/sky/fall_schedule.gd")
const Def := preload("res://src/core/orbit/orbit_def.gd")
const Pass := preload("res://src/core/orbit/orbit_pass.gd")

const DAY := 1440.0


func _def() -> RefCounted:
	return Def.ring()


## Everything between m0 and m1, asked in frame-sized steps the way the system
## asks it.
func _walk(seed_value: int, m0: float, m1: float, step: float) -> Array:
	var out: Array = []
	var m := m0
	while m < m1:
		out.append_array(Sched.between(_def(), seed_value, m, minf(m + step, m1)))
		m += step
	return out


func test_the_same_minutes_are_the_same_falls() -> void:
	var a := _walk(7, 3000.0, 3000.0 + DAY * 2.0, 20.0)
	var b := _walk(7, 3000.0, 3000.0 + DAY * 2.0, 20.0)
	gt(a.size(), 8.0, "two days hold falls")
	eq(a.size(), b.size(), "one clock, one list")
	for i in mini(a.size(), b.size()):
		eq(a[i].id, b[i].id, "fall %d is the same fall" % i)
		eq(a[i].minute, b[i].minute, "at the same minute")
		eq(a[i].kind, b[i].kind, "of the same class")
	var other := _walk(8, 3000.0, 3000.0 + DAY * 2.0, 20.0)
	check(other.size() != a.size() or other[0].minute != a[0].minute, "another seed has other falls")


## However the frames cut the clock, the same falls land in it once each, in
## order: a frame never fires one twice or loses one on its edge.
func test_any_way_of_cutting_the_clock_finds_each_fall_once() -> void:
	var fine := _walk(3, 900.0, 900.0 + DAY * 3.0, 0.37)
	var coarse := _walk(3, 900.0, 900.0 + DAY * 3.0, 29.0)
	eq(fine.size(), coarse.size(), "frame size does not change what falls")
	var seen := {}
	for i in fine.size():
		check(not seen.has(fine[i].id), "fall %d fires once" % int(fine[i].id))
		seen[fine[i].id] = true
		eq(fine[i].id, coarse[i].id, "and in the same order")
		if i > 0:
			check(float(fine[i].minute) >= float(fine[i - 1].minute), "in the clock's order")


## A night slept, a load, a tour's `hour`: the player did not live through that
## sky, and a dozen streaks arriving at once would be the world lying.
func test_a_skip_fires_nothing() -> void:
	var m0 := 5000.0
	var lived := _walk(7, m0, m0 + 600.0, 10.0)
	gt(lived.size(), 0.0, "ten hours lived through hold falls")
	eq(Sched.between(_def(), 7, m0, m0 + 600.0).size(), 0, "ten hours skipped hold none")
	eq(Sched.between(_def(), 7, m0, m0 + Sched.SKIP + 0.5).size(), 0, "just past the skip holds none")
	eq(Sched.between(_def(), 7, m0, m0).size(), 0, "no time, no falls")
	eq(Sched.between(_def(), 7, m0 + 5.0, m0).size(), 0, "the clock put back fires nothing")


## Falls crowd round the ring's passes (the wake it sheds is densest along its
## own track): the rate inside a pass window is well over the rate half a day
## from one.
func test_falls_cluster_round_the_passes() -> void:
	var d := _def()
	var seed_value := 11
	var inside := 0
	var far := 0
	var in_min := 0.0
	var far_min := 0.0
	var m := 2000.0
	var until := m + DAY * 40.0
	var step := 10.0
	while m < until:
		var w := Sched.wake(d, seed_value, m + step * 0.5)
		var n := Sched.between(d, seed_value, m, m + step).size()
		if w >= 0.999:
			inside += n
			in_min += step
		elif w < 0.05:
			far += n
			far_min += step
		m += step
	gt(in_min, DAY * 5.0, "forty days hold many hours of passes")
	gt(far_min, DAY * 5.0, "and many hours far from one")
	var in_rate := inside / (in_min / 60.0)
	var far_rate := far / (far_min / 60.0)
	print("  falls: %.2f an hour under a pass, %.2f far from one" % [in_rate, far_rate])
	gt(in_rate, far_rate * 2.5, "a pass brings the falls")
	gt(far_rate, 0.05, "and a night without one still has a few")
	near(in_rate, Sched.RATE * (Sched.FLOOR + Sched.LIFT), Sched.RATE * 0.35, "at the stated rate under a pass")


## One radiant: every fall comes in along the orbit's own track, within its
## spread, and dips at the world's one angle -- so traced back, the streaks all
## meet at the same point of the sky.
func test_every_fall_comes_in_from_one_radiant() -> void:
	var d := _def()
	var falls := _walk(5, 0.0, DAY * 6.0, 20.0)
	gt(falls.size(), 20.0, "six days of falls")
	var rad := Sched.radiant(5)
	for f: Dictionary in falls:
		var v: Vector3 = f.dir
		near(v.length(), 1.0, 1e-4, "a unit heading")
		lt(rad_to_deg((-v).angle_to(rad)), Sched.SPREAD + 0.01, "fall %d within the spread of the radiant" % int(f.id))
	check(rad.y > 0.0, "the radiant stands over the horizon: they come DOWN out of it")
	var flat := Vector2(-rad.x, -rad.z).normalized()
	var head := Pass.heading(5)
	near(rad_to_deg(flat.angle_to(Vector2(cos(deg_to_rad(head)), sin(deg_to_rad(head))))), 0.0, 0.5, "along the orbit's own heading")
	check(d != null, "the orbit's own body")


## The classes keep their shares, and each its own shape: dust is a short
## streak high up, a fragment breaks up and leaves a train, a mass comes low,
## near and slow enough to be heard.
func test_each_class_has_its_share_and_its_shape() -> void:
	var falls := _walk(9, 0.0, DAY * 60.0, 25.0)
	var n := {&"dust": 0, &"fragment": 0, &"mass": 0}
	for f: Dictionary in falls:
		n[f.kind] = int(n[f.kind]) + 1
		var e: float = f.entry_km
		var end: float = f.end_km
		check(e > end, "fall %d burns downward" % int(f.id))
		match f.kind:
			&"dust":
				eq(int(f.pieces), 0, "dust does not break up")
				gt(end, 60.0, "dust burns out high")
				lt(float(f.secs), 2.0, "a short streak")
				eq(float(f.train_secs) < 3.0, true, "and its glow gone in a breath")
			&"fragment":
				check(int(f.pieces) >= 3 and int(f.pieces) <= 6, "a fragment breaks into three to six")
				check(float(f.break_km) < e and float(f.break_km) > end, "it breaks on the way down")
				gt(float(f.train_secs), 20.0, "and leaves a train")
			&"mass":
				lt(float(f.range_km), Sched.MASS_RANGE.y + 0.01, "a mass is near enough to be heard")
				var boom := Sched.boom_secs(f)
				check(boom >= 40.0 and boom <= 200.0, "its boom arrives %.0f s later" % boom)
		var span: Vector2 = Sched.MASS_RANGE if f.kind == &"mass" else Sched.RANGE
		check(float(f.range_km) >= span.x - 0.01 and float(f.range_km) <= span.y + 0.01, "within its class's range")
	var total := float(falls.size())
	gt(total, 150.0, "sixty days of falls")
	near(float(n[&"dust"]) / total, 0.70, 0.07, "seven in ten are dust")
	near(float(n[&"fragment"]) / total, 0.25, 0.07, "a quarter fragments")
	near(float(n[&"mass"]) / total, 0.05, 0.04, "a mass is rare")
	gt(float(n[&"mass"]), 0.0, "but it comes")


## A fall's path is a line through the air from its entry to where it goes out,
## at the range it was dealt; and the path at any share is on that line.
func test_a_path_is_a_straight_line_through_its_heights() -> void:
	var falls := _walk(4, 0.0, DAY * 3.0, 20.0)
	for f: Dictionary in falls:
		var a := Sched.point(f, 0.0)
		var b := Sched.point(f, 1.0)
		near(a.y, float(f.entry_km), 0.01, "fall %d starts at its entry height" % int(f.id))
		near(b.y, float(f.end_km), 0.01, "and ends where it goes out")
		var mid := Sched.point(f, Sched.anchor_s(f))
		near(Vector2(mid.x, mid.z).length(), float(f.range_km), 0.01, "its anchor at its range")
		near((b - a).normalized().dot(f.dir), 1.0, 1e-4, "along its heading")


## Over its life a fall lights up, breaks at its breakup height with a flash
## far brighter than it was, flings its pieces off diverging from the break
## point, and they burn out; the head's motion and its inverse agree.
func test_a_fragment_lights_breaks_and_scatters() -> void:
	var f := Sched.staged(_def(), 7, &"fragment", 100.0, 90.0)
	var tb := Sched.break_secs(f)
	check(tb > 0.5 and tb < float(f.secs), "it breaks during its flight (%.2f s of %.2f)" % [tb, float(f.secs)])
	near(Sched.point(f, Sched.head_s(tb / float(f.secs))).y, float(f.break_km), 0.05, "at its breakup height")
	for s: float in [0.0, 0.2, 0.55, 0.9, 1.0]:
		near(Sched.head_s(Sched.time_at(s)), s, 1e-4, "time_at inverts head_s at %.2f" % s)
	gt(Sched.head_level(f, tb * 0.9), Sched.head_level(f, tb * 0.3), "it brightens into the thicker air")
	eq(Sched.head_level(f, tb + 0.01), 0.0, "and the body is gone once it breaks")
	gt(Sched.flash_level(f, tb + 0.02), Sched.head_level(f, tb * 0.99) * 2.0, "the breakup flashes")
	lt(Sched.flash_level(f, tb + 3.0), 0.2, "and the flash is gone in a breath")
	var ps := Sched.pieces_of(f)
	eq(ps.size(), int(f.pieces), "one piece a piece")
	var dirs: Array[Vector3] = []
	for p: Dictionary in ps:
		gt(float(p.life), 0.0, "each burns a while")
		near(Sched.piece_tau_at(p, Sched.piece_x(p, float(p.life) * 0.6)), float(p.life) * 0.6, 1e-3, "piece motion inverts")
		gt(Sched.piece_level(f, p, tb + 0.05), 0.0, "each lit at the breakup")
		eq(Sched.piece_level(f, p, tb + float(p.life) + 0.1), 0.0, "and out when it has burned")
		dirs.append(p.dir)
	var widest := 0.0
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			widest = maxf(widest, rad_to_deg(dirs[i].angle_to(dirs[j])))
	check(widest > 1.0 and widest < 12.0, "the pieces diverge by a few degrees (%.1f)" % widest)
	var at := Sched.light_at(f, ps, tb + 1.0)
	gt(at.distance_to(Sched.point(f, Sched.break_s(f))), 1.0, "the light moves on with the pieces")
	eq(Sched.pieces_of(Sched.staged(_def(), 7, &"dust", 100.0, 90.0)).size(), 0, "dust has no pieces")
	eq(Sched.flash_level(Sched.staged(_def(), 7, &"dust", 100.0, 90.0), 0.5), 0.0, "and no breakup flash")


## Staged by name (`--fall=CLASS@MINUTE`): the class asked for, at the minute
## asked for, on the bearing asked for, and nothing about it left to chance.
func test_a_staged_fall_is_the_one_asked_for() -> void:
	for kind: StringName in [&"dust", &"fragment", &"mass"]:
		var f := Sched.staged(_def(), 7, kind, 1300.0, 200.0)
		eq(f.kind, kind, "a staged %s" % kind)
		eq(float(f.minute), 1300.0, "at the minute")
		var mid := Sched.point(f, Sched.anchor_s(f))
		near(fposmod(rad_to_deg(atan2(mid.z, mid.x)), 360.0), 200.0, 0.5, "on the bearing")
	var bad := Sched.parse_stage("fragment@21.5/140")
	eq(bad.kind, &"fragment", "the class read")
	near(float(bad.at), 21.5, 1e-4, "the hour read")
	near(float(bad.bearing), 140.0, 1e-4, "the bearing read")
	check(Sched.parse_stage("nothing@3").is_empty(), "an unknown class stages nothing")
