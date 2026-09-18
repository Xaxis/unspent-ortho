extends TestCase
## 2029, the Before (docs/STORY.md §6). The era is this same coast tile for tile
## (Realm.ERA, unspent-ortho-df), so each place of his old life is cast exactly
## where its 2098 twin stands, and the people of 2029 stand only in the era.

const SEED := 1
const SIZE := 256


func _then() -> Array[StorySlot]:
	var out: Array[StorySlot] = []
	for s: StorySlot in StoryPlan.slots():
		if s.realm == Realm.ERA:
			out.append(s)
	return out


func test_every_place_of_his_old_life_has_a_twin_in_2098() -> void:
	var ids := {}
	for s: StorySlot in StoryPlan.slots():
		ids[s.id] = s
	var then := _then()
	gt(float(then.size()), 3.0, "the Before has his house, the lab, the meeting and the table")
	for s: StorySlot in then:
		check(not s.require, "%s is colour until a gate opens into the era" % s.id)
		check(ids.has(s.mirror), "%s is cast as %s, which is a place of the story" % [s.id, s.mirror])
		if ids.has(s.mirror):
			eq((ids[s.mirror] as StorySlot).realm, Realm.SURFACE, "%s's twin is on the surface" % s.id)


func test_the_ruin_he_wakes_beside_was_his_street() -> void:
	var now := WorldGen.generate(SEED, SIZE)
	var then := WorldGen.generate(SEED, SIZE, &"", Realm.ERA)
	var placed_now := StoryPlan.cast(now)
	var placed_then := StoryPlan.cast(then)
	for s: StorySlot in _then():
		check(placed_then.has(s.id), "%s is cast in the Before" % s.id)
		check(not placed_now.has(s.id), "and not in 2098")
		if placed_then.has(s.id) and placed_now.has(s.mirror):
			eq(placed_then[s.id].pos as Vector2, placed_now[s.mirror].pos as Vector2,
				"%s stands exactly where %s does" % [s.id, s.mirror])
	for s: StorySlot in StoryPlan.slots():
		if s.realm == Realm.SURFACE:
			check(not placed_then.has(s.id), "%s is 2098's, not the Before's" % s.id)


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


func test_what_he_says_in_2029_is_what_2029_remembers() -> void:
	Story.forget()
	_walk(&"hannah", ["[say nothing]"])
	check(Story.landed(&"hannah_phone"), "saying nothing is how she tells him she knows")
	Story.forget()
	_walk(&"hannah", ["Work ran late.", "I'll be there."])
	check(Story.landed(&"hannah_play"), "two o'clock, the school hall")
	eq(Story.chose(&"hannah.late"), &"promised", "and he promised")
	Story.forget()
	_walk(&"june_young", ["It's the best crown I've ever seen.", "I promise."])
	check(Story.landed(&"june_crown"), "a paper crown, and a promise")
	Story.forget()
	_walk(&"ruth", ["What happens now?"])
	check(Story.landed(&"ruth_signed"), "she offers it knowing about the three")
	Story.now += StoryPacing.SETTLE
	_walk(&"ruth", ["What happens now?", "I'll do it."])
	check(Story.landed(&"ruth_volunteered"), "and he says yes before she has finished")
	Story.forget()
	_walk(&"kerr", ["It's exactly what she says."])
	check(Story.landed(&"kerr_money"), "Virginia paid to keep it Cairn's")
	Story.forget()
	_walk(&"priya_then", ["It's a model, Priya.", "Home."])
	for b: StringName in [&"priya_warned", &"priya_suspected"]:
		check(Story.landed(b), "%s, from Priya herself" % b)
	Story.forget()
	_walk(&"hale", ["What happened to the others?"])
	check(Story.landed(&"three_before"), "Hale says what the binder says")
	Story.forget()
