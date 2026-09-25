extends TestCase
## The old THRESHOLD site, offshore (BlackSite, unspent-ortho-df): cast as the
## spine's first stop out of the surf, and holding its own words, which are never
## dealt to a sign anywhere else.

const SEEDS: Array[int] = [1, 7]
const SIZE := 256


func test_it_is_cast_where_the_world_put_it() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var at := BlackSite.site(w)
		check(at != Vector2.INF, "seed %d has sea off its spawn" % s)
		var done := StoryPlan.cast(w)
		check(done.has(&"the_black_site"), "seed %d casts the black site" % s)
		if done.has(&"the_black_site"):
			eq(done[&"the_black_site"].pos as Vector2, at, "seed %d: in the water df found" % s)
		# It is in the sea, not on the body he wakes on, and still leg 0.
		check(not w.same_body(at, w.spawn), "seed %d: nobody walks to it" % s)


func test_a_place_keeps_its_words_in_order_and_by_kind() -> void:
	eq(StoryFragments.pick_at(&"black_site", 0), &"growth_bay", "the tank he came out of first")
	eq(StoryFragments.pick_at(&"black_site", 0, &"notebook"), &"volunteers", "the one binder")
	eq(StoryFragments.pick_at(&"black_site", 1, &"terminal"), &"release_order", "the second screen")
	eq(StoryFragments.pick_at(&"black_site", 2, &"terminal"), &"", "and nothing past the end")
	eq(StoryFragments.pick_at(&"nowhere", 0), &"", "a place with no words has none")


func test_a_place_s_words_are_never_dealt() -> void:
	var placed := {}
	for place: StringName in StoryContent.PLACED:
		for id: StringName in StoryContent.PLACED[place]:
			check(StoryContent.FRAGMENTS.has(id), "%s at %s is written" % [id, place])
			check(not placed.has(id), "%s belongs to one place only" % id)
			placed[id] = true
	for kind: StringName in StoryFragments.KINDS:
		for d: BiomeDef in BiomeRegistry.all():
			for i in 200:
				var id := StoryFragments.pick(kind, d.id, 1, i)
				check(not placed.has(id), "%s is dealt to a %s in %s" % [id, kind, d.id])


func test_a_thing_standing_there_holds_the_place_s_words() -> void:
	var w := WorldGen.generate(1, SIZE)
	var at := BlackSite.site(w)
	# THE REAL THINGS, not stand-ins. This test invented three props at the site
	# because nothing stood there yet; world gen now lays the platform, the tank,
	# its two consoles and the binder (`GenScatter._black_site`), so the fixtures
	# would be a SECOND terminal and a second notebook and would be dealt the
	# words meant for something else. Reading what the world actually put there
	# is also the only version of this that can fail when the placement moves.
	var tank: WorldProp = null
	var door: WorldProp = null
	var binder: WorldProp = null
	for q: WorldProp in w.props:
		if q.pos.distance_to(at) > StoryWorld.PLACE_REACH:
			continue
		if q.kind == PropKind.CONSOLE:
			if tank == null:
				tank = q
			elif door == null:
				door = q
		elif q.kind == PropKind.ARCHIVE and binder == null:
			binder = q
	check(tank != null and door != null and binder != null,
		"the site stands two screens and a binder")
	if tank == null or door == null or binder == null:
		return
	var top := 0
	for q: WorldProp in w.props:
		top = maxi(top, q.id)
	var ashore := WorldProp.new(top + 1, PropKind.RELAY, w.spawn, 0.0, 1.0)
	w.props.append(ashore)
	var wq := WorldQuery.new(w)
	eq(StoryFragments.held_by(w, wq, tank), &"growth_bay", "the first screen is the tank's")
	eq(StoryFragments.held_by(w, wq, door), &"release_order", "the second is the sea door's")
	eq(StoryFragments.held_by(w, wq, binder), &"volunteers", "the binder holds the list")
	check(not StoryFragments.placed(StoryFragments.held_by(w, wq, ashore)), "a screen ashore holds dealt words")
	eq(StoryFragments.held_by(w, wq, tank), StoryFragments.held_by(w, wq, tank), "and it holds the same words when asked again")


func test_the_fire_keeper_points_at_it() -> void:
	Story.forget()
	var t := StoryTalk.start(&"maren")
	for want: String in ["Where am I?", "What's that, out in the water?"]:
		var i := -1
		var rs := t.replies()
		for k in rs.size():
			if str(rs[k].text) == want:
				i = k
		check(i >= 0, "Maren is asked \"%s\"" % want)
		if i < 0:
			return
		t.pick(i)
	check(Story.landed(&"the_platform"), "a lead, before anything is known about it")
	check(not StoryPacing.is_reveal(&"the_platform"), "and a lead is not a revelation")
	Story.forget()


func test_reading_the_list_is_knowing_both_things_on_it() -> void:
	Story.forget()
	check(Story.read(&"volunteers"), "read")
	check(Story.landed(&"threshold") and Story.landed(&"three_before"), "the table, and the three before him")
	Story.forget()
