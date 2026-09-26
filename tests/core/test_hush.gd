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


## THE STONES (Hush.turned, H2): in each epoch one stone of a ring stands turned,
## TURN_MIN to TURN_MAX degrees either way, the same stone and turn for the same epoch; over
## many epochs every stone of the ring takes its turn.
func test_one_stone_a_ring_stands_turned_an_epoch() -> void:
	var seen := {}
	for e in 200:
		var t := Hush.turned(7, 4242, 8, e)
		check(int(t.x) >= 0 and int(t.x) < 8, "a stone of the ring (%d)" % int(t.x))
		var deg := absf(rad_to_deg(t.y))
		check(deg >= Hush.TURN_MIN - 1e-4 and deg <= Hush.TURN_MAX + 1e-4, "turned %d to %d degrees (%.1f)" % [Hush.TURN_MIN, Hush.TURN_MAX, deg])
		seen[int(t.x)] = true
		eq(Hush.turned(7, 4242, 8, e), t, "the same epoch, the same stone")
	eq(seen.size(), 8, "every stone takes its turn")


## A stone turned where it stands (WorldData.turn_prop) keeps its footprint.
func test_a_stone_turns_where_it_stands() -> void:
	var w := WorldData.new(3, 32)
	var st := WorldProp.new(w.next_id(), PropKind.STANDING_STONE, Vector2(10.5, 10.5), 0.3, 0.6)
	w.add_prop(st)
	var before := w.prop(st.id).solid
	w.turn_prop(st.id, 0.5)
	var got := w.prop(st.id)
	near(got.rot, 0.5, 1e-6, "it is turned")
	eq(got.pos, Vector2(10.5, 10.5), "where it stood")
	near(got.solid, before, 1e-6, "its footprint the same")


## NOBODY'S LIGHTS (Hush.nobody, H4): one to three, each NEAR to FAR from the
## player wherever the player stands, the same for the same night and minute,
## never in a ring, and only in the dark in fog.
func test_nobodys_lights_keep_their_distance_and_keep_out_of_the_rings() -> void:
	check(not Hush.lit(1.0, 0.0), "not on a clear night")
	check(not Hush.lit(0.0, 1.0), "not by day in fog")
	check(Hush.lit(1.0, 0.6), "on a night in fog")
	for night in 30:
		var at := Vector2(100.0 + night * 3.0, 80.0)
		var pts := Hush.nobody(7, night, 600.0 + night * 11.0, at, PackedVector3Array())
		check(pts.size() >= 1 and pts.size() <= 3, "one to three (%d)" % pts.size())
		for p: Vector2 in pts:
			var d := p.distance_to(at)
			check(d >= Hush.NEAR - 1e-3 and d <= Hush.FAR + 1e-3, "always %d to %d tiles off (%.1f)" % [Hush.NEAR, Hush.FAR, d])
		eq(Hush.nobody(7, night, 600.0 + night * 11.0, at, PackedVector3Array()), pts, "the same night and minute, the same lights")
	# Walk toward one: it is as far as ever.
	var start := Hush.nobody(7, 3, 700.0, Vector2(50, 50), PackedVector3Array())[0]
	var walked := Vector2(50, 50) + (start - Vector2(50, 50)).normalized() * 10.0
	var after := Hush.nobody(7, 3, 701.0, walked, PackedVector3Array())[0]
	near(after.distance_to(walked), start.distance_to(Vector2(50, 50)), 1e-3, "walked toward, it keeps its distance")
	# A ring where one would stand: it does not stand there.
	var ring := PackedVector3Array([Vector3(start.x, start.y, 4.0)])
	for p: Vector2 in Hush.nobody(7, 3, 700.0, Vector2(50, 50), ring):
		check(p.distance_to(start) > 4.0 + Hush.RING_CLEAR, "never in a ring")
