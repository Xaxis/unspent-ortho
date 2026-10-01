extends TestCase
## BACK AT THE CAMP (ROADMAP slice 3, step 8). Once what the archive showed him
## (tradecraft) has been felt, the goal line leads him back across to the old
## soldier; once what the warden said of Teague (teague_sold) has been felt, to
## Rook; both pinned where he landed, on the narrows. The goal is the person and
## never the line: any talk with them since ends it (Story.spoke_since), so the
## confession is never forced. Dace, as cast at the crew's camp, answers the one
## `use` key with the war (crew_war) and, told the order was Elias's, leaves
## (dace_left); Rook, told of Teague's roads, will see to it (rook_told).

const Sx := preload("res://tests/save/save_fixture.gd")
## The crew's camp is cast on seed 1 at this size; the narrows need the whole
## world, so the goal line's test is walked there.
const SIZE := 256


func _lead(key: StringName) -> String:
	return String(StoryContent.LEAD.get(key, "<no %s line>" % key))


## Dace through the key: the war, then, once the archive's order is felt, back to
## him, where a talk that says nothing is enough; told, he is gone from the camp
## and from the key.
func test_dace_hears_it_through_the_key_and_is_gone() -> void:
	Story.forget()
	Sx.use_root("camp-dace")
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=10", "--weather=clear:0"])
	await frames(3)
	var cast := Sx.system(g, "49_cast")
	var story := Sx.system(g, "49_story")
	_past_the_holdfast(g)
	g.body.fed_until = g.clock.minutes + 100000.0
	var dace := _stand_at_cast(g, cast, &"dace")
	check(not dace.is_empty(), "Dace is cast at the crew's camp")
	await _until(func() -> bool: return bool(cast.call("tour_seen", &"cast:dace")))
	check(bool(cast.call("tour_seen", &"cast:dace")), "and drawn there")
	await _press_use(g)
	var t: StoryTalk = story.get("talk")
	eq(t.id if t != null else &"", &"dace", "the key opens Dace's words")
	_say(t, ["What happened?"])
	check(Story.landed(&"crew_war"), "he turned a key on an order that checked out")
	check(not _offers(t, "The order was mine."), "and there is nothing to confess before the archive")
	story.call("_close")
	# Across and back: June's leg behind him, and the archive's order shown him.
	_across()
	Story.beat(&"tradecraft")
	await _next_day(g)
	eq(Guide.goal(g), _lead(&"camp_back"), "felt: the old soldier, with what the archive showed")
	eq(Guide.last_goal_key, &"camp_back", "keyed, so a tour can claim it")
	await _press_use(g)
	t = story.get("talk")
	eq(t.id if t != null else &"", &"dace", "the key opens him again")
	story.call("_close")
	@warning_ignore("return_value_discarded")
	Guide.goal(g)
	check(Guide.last_goal_key != &"camp_back", "spoken to since, saying nothing: that want is met")
	check(not Story.landed(&"dace_left"), "and nothing made him say it")
	await _press_use(g)
	t = story.get("talk")
	_say(t, ["What happened?", "The order was mine."])
	check(Story.landed(&"dace_left"), "told, he is done with the crew, and with him")
	story.call("_close")
	check(not StoryCast.get_def(&"dace").present(), "gone, by the story")
	await _until(func() -> bool: return not bool(cast.call("tour_seen", &"cast:dace")))
	check(not bool(cast.call("tour_seen", &"cast:dace")), "and no longer stands at the camp")
	var stood: Vector2 = dace.get("pos", g.player.pos)
	g.player.pos = stood + Vector2(1.0, 0.0)
	g.player.hero.pos = g.player.pos
	g.player.facing = PI
	g.player.hero.facing = PI
	await _press_use(g)
	t = story.get("talk")
	check(t == null or t.id != &"dace", "where he stood, the key answers nothing of his")
	if t != null:
		story.call("_close")
	Sx.end(g)
	Story.forget()


## Rook through the key: once the warden's word on Teague has landed, he is told,
## says he will see to it, and Teague is gone.
func test_rook_is_told_of_teagues_roads_through_the_key() -> void:
	Story.forget()
	Sx.use_root("camp-rook")
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=10", "--weather=clear:0"])
	await frames(3)
	var cast := Sx.system(g, "49_cast")
	var story := Sx.system(g, "49_story")
	_past_the_holdfast(g)
	check(not _stand_at_cast(g, cast, &"rook").is_empty(), "Rook is cast at the crew's camp")
	await _until(func() -> bool: return bool(cast.call("tour_seen", &"cast:rook")))
	await _press_use(g)
	var t: StoryTalk = story.get("talk")
	eq(t.id if t != null else &"", &"rook", "the key opens Rook's words")
	check(not _offers(t, "Teague sells our roads to the Covenant."), "nothing to tell him before the warden has said it")
	story.call("_close")
	Story.beat(&"teague_sold", -INF)
	await _press_use(g)
	t = story.get("talk")
	_say(t, ["Teague sells our roads to the Covenant."])
	check(Story.landed(&"rook_told"), "he will see to it; the north road")
	story.call("_close")
	check(not StoryCast.get_def(&"teague").present(), "and Teague is gone")
	Sx.end(g)
	Story.forget()


## The goal line from June's voice to the slice's end: back to the old soldier
## once the order is felt, then Rook once the warden's word is, each pinned on the
## narrows where he landed, each ended by a talk since and only since; then the
## mended plate, and the relay below.
func test_the_goal_line_leads_him_back_across_to_dace_then_rook() -> void:
	Story.forget()
	Sx.use_root("camp-way")
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	await frames(3)
	_past_the_holdfast(g)
	g.body.fed_until = g.clock.minutes + 100000.0
	_across()
	Story.beat(&"war_relay", -INF)
	# Spoken to before either was learned: those talks are not the ones.
	for who: StringName in [&"dace", &"rook"]:
		@warning_ignore("return_value_discarded")
		Story.meet(who)
	await _next_day(g)
	Story.beat(&"tradecraft")
	Story.beat(&"teague_sold")
	@warning_ignore("return_value_discarded")
	Guide.goal(g)
	check(Guide.last_goal_key != &"camp_back" and Guide.last_goal_key != &"rook_teague", "still being felt: nobody to go back to yet (%s)" % Guide.last_goal_key)
	await _next_day(g)
	_hop(g, &"camp_back", "both felt: the old soldier first")
	_stand(g, _placed(g, &"the_landing"))
	_pinned(g, &"camp_back", &"the_landing")
	# Home again, the way back is no way: the crew's own mark is.
	_stand(g, _placed(g, &"the_camp"))
	check(not _marked(g, &"camp_back", _placed(g, &"the_landing")), "back on the home shore, the narrows are not pinned (%s)" % [UiMapScreen.told(g)])
	check(_marked(g, Guide.LEAD_BEAT, _placed(g, &"the_camp")), "and the crew's camp is")
	@warning_ignore("return_value_discarded")
	Story.meet(&"dace")
	_hop(g, &"rook_teague", "spoken to since: then Rook")
	_stand(g, _placed(g, &"the_landing"))
	_pinned(g, &"rook_teague", &"the_landing")
	@warning_ignore("return_value_discarded")
	Story.meet(&"rook")
	check(Guide.goal(g) != _lead(&"rook_teague"), "spoken to since: that want is met")
	Story.beat(&"covenant_fed")
	_hop(g, &"mend", "fed at the Covenant: the mended plate")
	g.inventory.add(&"plate_mended", 1)
	_hop(g, &"relay", "and last, the relay below")
	Sx.end(g)
	Story.forget()


## What Story remembers of a talk: the minute of the last, saved and loaded, and
## a save from before it knows nobody was spoken to since anything.
func test_the_last_talk_is_remembered_and_saved() -> void:
	Story.forget()
	Story.now = 100.0
	check(not Story.spoke_since(&"dace", -INF), "never spoken to")
	check(Story.meet(&"dace"), "met, the first time")
	Story.now = 500.0
	check(not Story.meet(&"dace"), "met once only")
	check(Story.spoke_since(&"dace", 500.0), "but the last talk is now")
	check(not Story.spoke_since(&"dace", 501.0), "and not after")
	var saved := Story.save_state()
	Story.forget()
	Story.load_state(saved)
	check(Story.met(&"dace") and Story.spoke_since(&"dace", 500.0), "saved and loaded")
	saved.erase("spoke")
	Story.load_state(saved)
	check(Story.met(&"dace") and not Story.spoke_since(&"dace", -1.0e9), "an older save: met, and nothing since")
	Story.forget()


## A day on, at the same hour: whatever landed has been felt, and it is light.
func _next_day(g: Game) -> void:
	g.clock.minutes += 24.0 * 60.0
	await process_frames(2)


func _hop(g: Game, key: StringName, what: String) -> void:
	eq(Guide.goal(g), _lead(key), what)
	eq(Guide.last_goal_key, key, "%s: keyed, so a tour can claim it" % key)


## Marked while the goal is `key` (StoryContent.TOLD_WHILE), at the place cast.
func _pinned(g: Game, key: StringName, place: StringName) -> void:
	var pin: Dictionary = StoryContent.TOLD_WHILE.get(key, {})
	eq(pin.get("place", &""), place, "%s: the survey pins %s while it is the goal" % [key, place])
	check(_placed(g, place).is_finite(), "%s is cast on this world" % place)
	check(_marked(g, key, _placed(g, place)), "%s: and the survey marks it (%s)" % [key, UiMapScreen.told(g)])


## Whether the survey marks `at` with the word of `key`: a goal's (TOLD_WHILE) or,
## failing that, a beat's (TOLD).
func _marked(g: Game, key: StringName, at: Vector2) -> bool:
	var row: Dictionary = StoryContent.TOLD_WHILE.get(key, StoryContent.TOLD.get(key, {}))
	for m: Dictionary in UiMapScreen.told(g):
		if String(m.word) == String(row.get("word", "<none>")) and (m.at as Vector2).distance_to(at) < 0.5:
			return true
	return false


func _placed(g: Game, place: StringName) -> Vector2:
	var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
	return placed[place].pos if placed.has(place) else Vector2.INF


func _stand(g: Game, at: Vector2) -> void:
	g.player.pos = at
	g.player.hero.pos = at


## The crew paid and the armour made, the yard read, Rook and Vera: slice 2 done.
func _past_the_holdfast(g: Game) -> void:
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	Story.choose(&"rook.iron", &"paid")
	if not g.inventory.has(&"kit_plate"):
		g.inventory.add(&"kit_plate", 1)
	for b: StringName in [&"reaper_down", &"built_halcyon", &"holdfast_hope"]:
		Story.beat(b, -INF)


## Across the water as far as June's leg goes, long ago: the archive's man met,
## June met, and what the voice kept her from said.
func _across() -> void:
	for b: StringName in [&"war_archive", &"covenant_speaker", &"june_named", &"june_knew", &"echo_kept"]:
		Story.beat(b, -INF)
	for who: StringName in [&"otto", &"june"]:
		@warning_ignore("return_value_discarded")
		Story.meet(who)


func _stand_at_cast(g: Game, cast: Node, id: StringName) -> Dictionary:
	var spot: Vector2 = cast.call("tour_place", "cast:%s" % id)
	for row: Dictionary in cast.get("people"):
		if row.character == id:
			g.player.pos = spot
			g.player.hero.pos = spot
			g.player.facing = ((row.pos as Vector2) - spot).angle()
			g.player.hero.facing = g.player.facing
			return row
	return {}


## Until `ok` holds, or ten seconds: who is drawn is settled twice a second
## (49_cast RECHECK), on the game's own clock.
func _until(ok: Callable) -> void:
	var end := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < end and not bool(ok.call()):
		await process_frames(1)


## The real key, as a player presses it: once the keys are his again. At this
## size a keeper's yard is in sight of the camp, and its waking turns the view
## to it and holds the keys (42_stage).
func _press_use(g: Game) -> void:
	await _until(func() -> bool: return not g.input_blocked())
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	await process_frames(3)


func _offers(t: StoryTalk, text: String) -> bool:
	if t == null:
		return false
	for r: Dictionary in t.replies():
		if str(r.text) == text:
			return true
	return false


func _say(t: StoryTalk, picks: Array) -> void:
	if t == null:
		check(false, "a conversation is open")
		return
	for want: String in picks:
		var i := -1
		var rs := t.replies()
		for k in rs.size():
			if str(rs[k].text) == want:
				i = k
		check(i >= 0, "%s offers \"%s\" at %s" % [t.id, want, t.node])
		if i < 0:
			return
		@warning_ignore("return_value_discarded")
		t.pick(i)
