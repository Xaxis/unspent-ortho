extends TestCase
## THE HUSH (Hush, docs/HUSH.md H3): a ring answers only in the dark or the fog,
## and then about one visit in two, the same way for the same visit; the quiet
## comes after a moment, holds, and lifts; and when it is whole, every bed in
## the mix is silent while the player's own sounds are not the beds' to take.


func test_a_ring_answers_only_in_the_dark_or_the_fog() -> void:
	for v in 50:
		check(not Hush.answers(7, 1234, 1, v, 0.0, 0.0), "never on a clear day (visit %d)" % v)
	var night := 0
	var fog := 0
	for v in 200:
		if Hush.answers(7, 1234, 1, v, 1.0, 0.0):
			night += 1
		if Hush.answers(7, 1234, 1, v, 0.0, 0.8):
			fog += 1
	check(night > 60 and night < 140, "about one visit in two at night (%d of 200)" % night)
	eq(fog, night, "fog answers as the dark does")
	eq(Hush.answers(7, 1234, 3, 5, 1.0, 0.0), Hush.answers(7, 1234, 3, 5, 1.0, 0.0), "the same visit, the same answer")


func test_the_quiet_comes_holds_and_lifts() -> void:
	var sp := Hush.span(7, 1234, 1, 0)
	check(sp.x >= 0.5 and sp.x <= 2.0 and sp.y >= 4.0 and sp.y <= 9.0, "a short wait and a hold of seconds (%s)" % sp)
	eq(Hush.level(sp.x * 0.5, sp.x, sp.y), 0.0, "nothing while it waits")
	near(Hush.level(sp.x + Hush.FALL + sp.y * 0.5, sp.x, sp.y), 1.0, 1e-6, "silent through the hold")
	eq(Hush.level(Hush.ends(sp.x, sp.y) + 0.1, sp.x, sp.y), 0.0, "and back after")
	var last := 0.0
	for i in 20:
		var l := Hush.level(sp.x + Hush.FALL * float(i) / 19.0, sp.x, sp.y)
		check(l >= last - 1e-6, "falling silent never lurches back")
		last = l


func test_silence_takes_every_bed_and_leaves_the_mix_alone_without_it() -> void:
	var w := WorldData.new(3, 64)
	var weather := {"kind": &"rain", "strength": 0.8, "wind": 0.6}
	var loud := SoundMix.bed_levels(w, Vector2(32, 32), weather, {}, {}, 1.0, {"hour": 22.0})
	var plain := SoundMix.bed_levels(w, Vector2(32, 32), weather, {}, {}, 1.0, {"hour": 22.0, "hush": 0.0})
	var hushed := SoundMix.bed_levels(w, Vector2(32, 32), weather, {}, {}, 1.0, {"hour": 22.0, "hush": 1.0})
	var any := 0.0
	for bed: StringName in loud:
		any = maxf(any, float(loud[bed]))
		eq(float(plain[bed]), float(loud[bed]), "no hush changes nothing (%s)" % bed)
		eq(float(hushed[bed]), 0.0, "the hush silences %s" % bed)
	gt(any, 0.05, "there was something to silence")
