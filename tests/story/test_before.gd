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


func test_the_past_does_not_change_but_the_machine_made_of_it_does() -> void:
	Story.forget()
	var t := StoryTalk.start(&"hale")
	for r: Dictionary in t.replies():
		check(str(r.text) != "[walk out. It's nearly two.]", "nobody walks out on a promise he has not made")
	_walk(&"june_young", ["It's the best crown I've ever seen.", "I promise."])
	_walk(&"hale", ["[walk out. It's nearly two.]"])
	check(Story.landed(&"play_kept"), "he walks out for the play, in the Seeker's 2029")
	# In 2098, June hears it from the voice.
	Story.beat(&"june_named", -INF)
	Story.now += StoryPacing.SETTLE * 2.0
	_walk(&"june", ["Do you know who I am?", "Has the voice said anything new?"])
	eq(Story.chose(&"june.knows"), &"asked_new", "and June tells him what the voice said last night")
	Story.forget()


func test_what_became_of_hannah_is_june_s_to_say() -> void:
	Story.forget()
	Story.beat(&"june_named", -INF)
	Story.beat(&"hannah_play", -INF)
	Story.now = 9000.0
	_walk(&"june", ["Do you know who I am?"])
	Story.now += StoryPacing.SETTLE
	_walk(&"june", ["Do you know who I am?", "What happened to your mother?"])
	check(Story.landed(&"hannah_died"), "the winter of thirty-four, the north road")
	Story.forget()


## In 2029 the machines' works have not risen (unspent-ortho-df): a mirrored slot
## stands on its twin's tile whatever its own world holds, so the lab stands where
## the yard will, in a Before with no yard in it.
func test_a_mirrored_place_does_not_ask_its_own_world_for_its_ground() -> void:
	var now := WorldGen.generate(SEED, SIZE)
	var then := WorldGen.generate(SEED, SIZE, &"", Realm.ERA)
	var placed_now := StoryPlan.cast(now)
	# Strip the Before of every works site: the slot must not care.
	then.props = then.props.filter(func(p: WorldProp) -> bool: return not Takes.is_plan_work(p.kind))
	var placed_then := StoryPlan.cast(then)
	check(placed_then.has(&"then_lab"), "the lab is cast in a Before with no works in it")
	if placed_then.has(&"then_lab"):
		eq(placed_then[&"then_lab"].pos as Vector2, placed_now[&"the_yard"].pos as Vector2, "where the yard will rise")
