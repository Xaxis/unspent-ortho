extends TestCase
## One local per landscape (docs/STORY.md §8): colour, never load. Each stands at
## the village of their own land nearest to where he woke, whatever body that is
## on, and each carries a small story of their land that lands as a beat.


## The one landscape without a local of its own: the coast's person is Maren.
const COVERED := [&"coast"]


func _locals() -> Array[StorySlot]:
	var out: Array[StorySlot] = []
	for s: StorySlot in StoryPlan.slots():
		# The Before's places are unordered too, but they are 2029, not locals.
		if not s.ordered and s.mirror == &"":
			out.append(s)
	return out


func test_every_land_people_live_in_has_one_local() -> void:
	var by_land := {}
	for s: StorySlot in _locals():
		check(not s.require, "%s is colour, never load" % s.id)
		check(BiomeRegistry.get_def(s.land) != null, "%s names a landscape that exists: %s" % [s.id, s.land])
		check(not by_land.has(s.land), "%s has one local, not two" % s.land)
		by_land[s.land] = s.id
		var who := 0
		for c: StoryCharacter in StoryCast.all():
			if c.at == s.id:
				who += 1
		eq(who, 1, "%s has exactly one person" % s.id)
	for d: BiomeDef in BiomeRegistry.all():
		if d.villages <= 0 or COVERED.has(d.id):
			continue
		check(by_land.has(d.id), "%s has villages and somebody in them" % d.id)


func test_a_local_stands_in_their_own_land_and_moves_the_journey_nowhere() -> void:
	for seed_v: int in [1, 7]:
		var w := WorldGen.generate(seed_v, 1024)
		var done := StoryPlan.cast(w)
		var cast := 0
		for s: StorySlot in _locals():
			if s.realm != w.realm or not done.has(s.id):
				continue
			cast += 1
			var at: Vector2 = done[s.id].pos
			eq(BiomeRegistry.at(w, at).id, s.land, "seed %d: %s stands in %s" % [seed_v, s.id, s.land])
		gt(float(cast), 3.0, "seed %d: a big world holds most of its locals" % seed_v)
		# The spine is cast exactly as it was without them.
		var spine: Array[StorySlot] = []
		for s: StorySlot in StoryPlan.slots():
			if s.ordered:
				spine.append(s)
		var alone := StoryCasting.cast(w, spine)
		for id: StringName in alone:
			eq(done[id].pos as Vector2, alone[id].pos as Vector2, "seed %d: %s is where it would be without any local" % [seed_v, id])


## Each local's own story, told: the reply that asks, and the beat it lands.
const WALKS := {
	&"hollis": [["What do the refineries make?"], &"burning_feeds"],
	&"wren": [["Listen to what?"], &"plant_below"],
	&"ansel": [["Whose roof?"], &"dam_order"],
	&"corra": [["What are the square cuts?"], &"server_fields"],
	&"mica": [["The big one, out on the flat."], &"keeper_waits"],
	&"tamsin": [["What happened here?"], &"scrap_war"],
	&"pell": [["Out of the water."], &"others_before"],
	&"brannoc": [["What's on the wires?", "What numbers?"], &"the_count"],
}


func _walk(talk: StringName, picks: Array) -> void:
	var t := StoryTalk.start(talk)
	for want: Variant in picks:
		var i := -1
		var rs := t.replies()
		for k in rs.size():
			if str(rs[k].text) == str(want):
				i = k
		check(i >= 0, "%s offers \"%s\" at %s" % [talk, want, t.node])
		if i < 0:
			return
		@warning_ignore("return_value_discarded")
		t.pick(i)


func test_every_local_tells_what_their_land_has_noticed() -> void:
	for talk: StringName in WALKS:
		Story.forget()
		_walk(talk, WALKS[talk][0])
		check(Story.landed(WALKS[talk][1]), "%s tells it: %s" % [talk, WALKS[talk][1]])
	# Esk's is the player's to tell him, once he knows the machines count things.
	Story.forget()
	_walk(&"esk", ["Why set them up?"])
	check(not Story.landed(&"stones_counted"), "Esk believes his gran")
	Story.forget()
	Story.beat(&"counted", -INF)
	_walk(&"esk", ["Why set them up?", "They leave them because they've counted them."])
	check(Story.landed(&"stones_counted"), "and sets it up anyway")
	Story.forget()
