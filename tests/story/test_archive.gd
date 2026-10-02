extends TestCase
## THE ARCHIVE (ROADMAP slice 3, step 4). Otto keeps the war's archive across the
## water. Through the one `use` key he says how the war started (forged_order),
## where every order went (war_relay: the relay below, a shaft down, pinned on the
## survey as a standing lead), and, shown one, an order in Elias's own rhythm
## (tradecraft). The goal line asks for that order once Otto is met, until it is
## shown; the relay below is the slice's last hop, said only while no keeper named
## to him still stands (Guide.WAY `last`, Guide.keeper_goal).

const Sx := preload("res://tests/save/save_fixture.gd")
## Every slot the way walks is cast on seed 1 at this size; the keepers are
## measured on the whole world (test_next_keeper), so the relay's test is too.
const SIZE := 256


func _lead(key: StringName) -> String:
	return String(StoryContent.LEAD.get(key, "<no %s line>" % key))


## Otto as cast in the world: the key opens his words, and each of the three
## answers lands its beat; the goal turns from the archive to the order, and on.
func test_otto_at_the_archive_answers_the_key_with_each_of_his_three() -> void:
	Story.forget()
	Sx.use_root("archive-otto")
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=10", "--weather=clear:0"])
	await frames(3)
	var cast := Sx.system(g, "49_cast")
	var story := Sx.system(g, "49_story")
	_past_the_holdfast(g)
	Story.beat(&"war_archive", -INF)
	@warning_ignore("return_value_discarded")
	Story.hear(StoryCrossing.CROSSED)
	eq(Guide.goal(g), _lead(&"archive"), "across, not yet met: the archive")
	var otto := _stand_at_cast(g, cast, &"otto")
	check(not otto.is_empty(), "Otto is cast at the archive")
	await frames(40)
	check(bool(cast.call("tour_seen", &"cast:otto")), "and drawn there")
	await _press_use()
	var t: StoryTalk = story.get("talk")
	eq(t.id if t != null else &"", &"otto", "the key opens Otto's words")
	check(Story.met(&"otto"), "and he has met him")
	_say(t, ["How the war started."])
	check(Story.landed(&"forged_order"), "every order that started it checked out")
	_say(t, ["Where is it?"])
	check(Story.landed(&"war_relay"), "and every one passed through one relay, below")
	check(not Story.landed(&"tradecraft"), "nothing shown him yet")
	story.call("_close")
	eq(Guide.goal(g), _lead(&"orders"), "met: one of the orders, for who sent them")
	eq(Guide.last_goal_key, &"orders", "keyed, so a tour can claim it")
	check(_placed(g, &"the_shaft").is_finite(), "the shaft is cast on this world")
	_told(g, &"war_relay", &"the_shaft")
	await _press_use()
	t = story.get("talk")
	eq(t.id if t != null else &"", &"otto", "the key opens him again")
	_say(t, ["How the war started.", "Show me one."])
	check(Story.landed(&"tradecraft"), "shown one, it reads like him")
	story.call("_close")
	@warning_ignore("return_value_discarded")
	Guide.goal(g)
	eq(Guide.last_goal_key, &"covenant", "shown: the way goes on to the Covenant's seat")
	Sx.end(g)
	Story.forget()


## THE PRESS GOES TO WHAT HE FACES. On the full-size island Otto stood within
## reach of the archive's landmark cache, and a cache in reach took the key though
## he faced Otto: the locker opened and the archive's man said nothing
## (tours/archive.tour line 24). A person in front is the press's first. The cache
## is staged at his side by name (the archive's own landmark, moved), since a
## change to worldgen may leave none in reach there.
func test_facing_otto_beside_a_cache_the_press_is_his() -> void:
	Story.forget()
	Sx.use_root("archive-cache")
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % Tuning.WORLD_SIZE, "--hour=10", "--weather=clear:0"])
	await frames(3)
	var cast := Sx.system(g, "49_cast")
	var story := Sx.system(g, "49_story")
	var marks := Sx.system(g, "22_landmarks")
	_past_the_holdfast(g)
	Story.beat(&"war_archive", -INF)
	@warning_ignore("return_value_discarded")
	Story.hear(StoryCrossing.CROSSED)
	var otto := _stand_at_cast(g, cast, &"otto")
	check(not otto.is_empty(), "Otto is cast at the archive")
	var site := _nearest_site(marks, _placed(g, &"the_archive"))
	check(site != null, "the archive has a landmark")
	if site != null:
		var beside := g.player.pos + Vector2.from_angle(g.player.facing + PI / 2.0) * 1.5
		site.pos = beside - (Landmarks.cache_of(site) - site.pos)
	await frames(40)
	var cache: LandmarkSite = marks.get("reachable")
	check(cache != null, "and a cache is in reach where he stands")
	await _press_use()
	var t: StoryTalk = story.get("talk")
	eq(t.id if t != null else &"", &"otto", "facing Otto, the key opens his words")
	if cache != null:
		check(not marks.state.is_opened(cache.id), "and the cache beside him waits")
	Sx.end(g)
	Story.forget()


## The whole way from Vera's lead to the slice's end, each hop in order, until
## what ends it, each keyed and pinned: the raft, the narrows, the archive, the
## order, the Covenant's seat, her name, June, the voice, the mended plate, and
## the relay below.
func test_the_goal_line_walks_from_the_archive_to_the_relay() -> void:
	Story.forget()
	Sx.use_root("archive-way")
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=10", "--weather=clear:0"])
	await frames(3)
	_past_the_holdfast(g)
	g.body.fed_until = g.clock.minutes + 100000.0
	Story.beat(&"war_archive")
	_hop(g, &"raft", "Vera's lead: a raft")
	@warning_ignore("return_value_discarded")
	Story.hear(StoryCrossing.PUT_IN)
	# (The narrows' own pin is test_crossing's, on the whole world: this size
	# joins no two bodies by a narrows.)
	_hop(g, &"crossing", "the raft in: the narrows")
	@warning_ignore("return_value_discarded")
	Story.hear(StoryCrossing.CROSSED)
	_hop(g, &"archive", "across: the archive")
	_told(g, &"war_archive", &"the_archive")
	@warning_ignore("return_value_discarded")
	Story.meet(&"otto")
	_hop(g, &"orders", "the archive's man met: one of the orders")
	_told(g, &"war_archive", &"the_archive")
	Story.beat(&"forged_order")
	Story.beat(&"war_relay")
	_hop(g, &"orders", "told how it started and where they went: the order still")
	_told(g, &"war_relay", &"the_shaft")
	Story.beat(&"tradecraft")
	_hop(g, &"covenant", "shown one: the Covenant's seat")
	_pinned(g, &"covenant", &"the_covenant")
	Story.beat(&"covenant_speaker")
	_hop(g, &"speaker", "the Speaker heard of: her name")
	await _next_day(g)
	Story.beat(&"june_named")
	await _next_day(g)
	_hop(g, &"june", "her name felt: June")
	@warning_ignore("return_value_discarded")
	Story.meet(&"june")
	Story.beat(&"june_met")
	Story.beat(&"june_knew")
	await _next_day(g)
	_hop(g, &"june_voice", "what she knew felt: back to her")
	Story.beat(&"echo_kept")
	# What the archive showed him felt, the old soldier (test_back_at_camp walks it).
	@warning_ignore("return_value_discarded")
	Story.meet(&"dace")
	Story.beat(&"covenant_fed")
	_hop(g, &"mend", "fed at the Covenant: the mended plate")
	g.inventory.add(&"plate_mended", 1)
	_hop(g, &"relay", "and last, the relay below, held into the next leg")
	_told(g, &"war_relay", &"the_shaft")
	Sx.end(g)
	Story.forget()


## THE RELAY IS A FALLBACK: the leg's last lead has nothing in this slice to end
## it, so a keeper named to him (the Candlestick, Teague's `anvil_named`) and still
## standing is said first, and the relay only once it has fallen.
func test_the_relay_waits_behind_a_named_keeper_still_standing() -> void:
	Story.forget()
	Sx.use_root("archive-relay-keeper")
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	await frames(3)
	_past_the_holdfast(g)
	for b: StringName in [&"war_archive", &"tradecraft", &"war_relay", &"covenant_speaker", &"june_named",
			&"june_knew", &"echo_kept", &"teague_sold"]:
		Story.beat(b, -INF)
	for who: StringName in [&"otto", &"june", &"dace", &"rook"]:
		@warning_ignore("return_value_discarded")
		Story.meet(who)
	_hop(g, &"relay", "nothing else open: the relay below")
	var states := Sentinels.live(g)
	var reaper := Sentinels.next_keeper(states, g.world.spawn, g.world, Guide.bodies_reached(g))
	eq(reaper.design if reaper != null else &"", &"tide_reaper", "the Reaper is the first keeper")
	if reaper == null:
		Sx.end(g)
		Story.forget()
		return
	reaper.fallen = true
	var anvil := Sentinels.next_keeper(states, g.world.spawn, g.world, Guide.bodies_reached(g))
	eq(anvil.design if anvil != null else &"", &"anvil", "the Candlestick the second")
	@warning_ignore("return_value_discarded")
	Story.beat(&"anvil_named")
	eq(Guide.goal(g), _lead(&"anvil"), "Teague has named it and it stands: his lead, not the relay")
	eq(Guide.last_goal_key, &"anvil", "keyed as the keeper's")
	if anvil != null:
		anvil.fallen = true
	_hop(g, &"relay", "the Candlestick down: the relay again")
	Sx.end(g)
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
	check(_marked(g, String(pin.get("word", "<none>")), _placed(g, place)), "%s: and marks it (%s)" % [key, UiMapScreen.told(g)])


## Marked since `beat` told him of it (StoryContent.TOLD), at the place cast.
func _told(g: Game, beat: StringName, place: StringName) -> void:
	var row: Dictionary = StoryContent.TOLD.get(beat, {})
	eq(row.get("place", &""), place, "%s tells him of %s" % [beat, place])
	check(_marked(g, String(row.get("word", "<none>")), _placed(g, place)), "%s: the survey marks %s (%s)" % [beat, place, UiMapScreen.told(g)])


## The landmark of `marks` (22_landmarks) nearest `at`, or null.
func _nearest_site(marks: Node, at: Vector2) -> LandmarkSite:
	var best: LandmarkSite = null
	for s: LandmarkSite in marks.get("sites"):
		if best == null or s.pos.distance_to(at) < best.pos.distance_to(at):
			best = s
	return best


func _placed(g: Game, place: StringName) -> Vector2:
	var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
	return placed[place].pos if placed.has(place) else Vector2.INF


func _marked(g: Game, word: String, at: Vector2) -> bool:
	for m: Dictionary in UiMapScreen.told(g):
		if String(m.word) == word and (m.at as Vector2).distance_to(at) < 0.5:
			return true
	return false


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


## The real key, as a player presses it.
func _press_use() -> void:
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	await process_frames(3)


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
