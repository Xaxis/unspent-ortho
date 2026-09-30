extends TestCase
## THE COVENANT'S SEAT (slice 3 step 2). Its notice stands at its own place
## (StoryContent.STOOD, walked by test_lab_and_table), and the house nearest it
## is the Speaker's: her set, the card by it, the photograph turned to the wall
## (StoryRooms.SPEAKER, ROOMS home:speaker). Her voice reaches every landscape on
## a stray relay (`broadcast`); her own set pays covenant_speaker off whether or
## not that has already, and nothing is read twice.

const SEEDS: Array[int] = [1, 7]
const SIZE := 256


func test_the_house_nearest_the_covenant_is_the_speakers_and_holds_her_set() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var cast := StoryPlan.cast(w)
		check(cast.has(&"the_covenant"), "seed %d casts the Covenant" % s)
		if not cast.has(&"the_covenant"):
			continue
		var seat: Vector2 = cast[&"the_covenant"].pos
		var tenants := StoryRooms.tenants(w)
		var hers: Array[Threshold] = []
		var nearest: Threshold = null
		for t: Threshold in Interiors.thresholds(w):
			if tenants.get(t.key, &"") == StoryRooms.SPEAKER:
				hers.append(t)
			if StoryRooms.SPEAKER_KINDS.has(t.kind) and (nearest == null or t.host.distance_to(seat) < nearest.host.distance_to(seat)):
				nearest = t
		eq(hers.size(), 1, "seed %d: one house is the Speaker's" % s)
		if hers.size() != 1:
			continue
		var t := hers[0]
		check(t == nearest, "seed %d: the one nearest the Covenant (%.0f tiles from it)" % [s, t.host.distance_to(seat)])
		var room := InteriorGen.grow(s, t, StoryRooms.SPEAKER)
		check(room != null, "seed %d: her house opens" % s)
		if room == null:
			continue
		var l := room.layout
		var radio := false
		for th: Dictionary in l.things:
			radio = radio or th.kind == &"radio"
		check(radio, "seed %d: her set stands in it" % s)
		var row := StoryRooms.room_of(room.kind.words if room.kind.words != &"" else room.kind.id, StoryRooms.SPEAKER)
		var held: Array[StringName] = []
		for i in l.slots.size():
			held.append(StoryRooms.held(row, t.key, l, i, t.land))
		for id: StringName in [&"speaker_set", &"home_speaker_card", &"home_speaker_photo"]:
			check(held.has(id), "seed %d: %s is read there (%s)" % [s, id, held])


func test_her_set_pays_the_speaker_off_whether_or_not_a_relay_did() -> void:
	# A stray relay first: the beat lands there; her set still reads, once.
	Story.forget()
	check(Story.read(&"broadcast"), "a relay carries her voice")
	check(Story.landed(&"covenant_speaker"), "and the Speaker is heard of")
	check(Story.read(&"speaker_set"), "her own set is still read")
	check(Story.landed(&"covenant_speaker"), "the beat stands")
	check(not Story.read(&"speaker_set"), "and her set is not read twice")
	check(not Story.read(&"broadcast"), "nor the relay")
	# Her set first: it lands the beat itself.
	Story.forget()
	check(Story.read(&"speaker_set"), "her set, before any relay")
	check(Story.landed(&"covenant_speaker"), "pays the Speaker off itself")
	Story.forget()


func test_her_voice_still_reaches_every_landscape() -> void:
	check(not StoryFragments.placed(&"broadcast"), "the relay's broadcast stays in the deal")
	check(StoryFragments.placed(&"speaker_set"), "her own set is only in her house")
	check(StoryFragments.placed(&"covenant_notice"), "the notice is only at the Covenant")
