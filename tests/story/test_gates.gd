extends TestCase
## The gates into 2029 (StoryGates): each at a place of the 2098 story, on the
## same tile in the Before, and opening only once its revelation has been felt.

const SEED := 1
const SIZE := 256


func test_every_gate_is_a_place_of_the_story_and_opens_on_a_beat() -> void:
	var slots := {}
	for s: StorySlot in StoryPlan.slots():
		slots[s.id] = s
	for g: Dictionary in StoryGates.GATES:
		check(slots.has(g.at), "%s stands at %s, a place of the story" % [g.id, g.at])
		check(slots.has(g.then), "%s opens onto %s, a place of 2029" % [g.id, g.then])
		if slots.has(g.then):
			eq((slots[g.then] as StorySlot).mirror, g.at, "%s's two ends are twins" % g.id)
		check(StoryContent.BEATS.has(g.opens), "%s opens on %s, a beat" % [g.id, g.opens])


func test_a_gate_stands_on_the_same_tile_in_both_times() -> void:
	var now := WorldGen.generate(SEED, SIZE)
	var then := WorldGen.generate(SEED, SIZE, &"", Realm.ERA)
	var a := StoryGates.all(now)
	var b := StoryGates.all(then)
	eq(a.size(), StoryGates.GATES.size(), "every gate stands in 2098")
	eq(b.size(), a.size(), "and in the Before")
	for i in mini(a.size(), b.size()):
		eq(a[i].id, b[i].id)
		eq(a[i].pos as Vector2, b[i].pos as Vector2, "%s is one tile in two times" % a[i].id)


func test_a_gate_opens_only_once_its_news_has_been_felt() -> void:
	Story.forget()
	var w := WorldGen.generate(SEED, SIZE)
	eq(StoryGates.open(w).size(), 0, "nothing is open on the first morning")
	Story.now = 100.0
	Story.beat(&"body_new")
	eq(StoryGates.open(w).size(), 0, "not the minute he learns it")
	Story.now += StoryPacing.SETTLE
	var open := StoryGates.open(w)
	eq(open.size(), 1, "then the first")
	if open.size() == 1:
		eq(open[0].id, &"gate_home", "and it is his house")
	Story.forget()
