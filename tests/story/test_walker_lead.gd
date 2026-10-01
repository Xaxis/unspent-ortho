extends TestCase
## THE ROAD UP (Guide.WAY `walker`, ROADMAP slice 3 step 7). Solis, asked about
## every road, names the one nobody has sold: up the lame walker (walker_told).
## Once his word on Teague has settled, the goal is the walker, pinned on its
## crater on the Covenant's body, until the enclave in its crown has been met, and
## the way home waits on it. A world whose craters both fall on another leg's body
## has no such goal: the line never sends him there, and goes home instead.
## Whole worlds, since a small one has no crater at all.

const Sx := preload("res://tests/save/save_fixture.gd")


func _lead(key: StringName) -> String:
	return String(StoryContent.LEAD.get(key, "<no %s line>" % key))


## Seed 1 has a crater on the Covenant's body, 163 tiles from it.
func test_the_goal_is_the_walkers_crater_until_the_enclave() -> void:
	var g := await _told(1)
	@warning_ignore("return_value_discarded")
	Guide.goal(g)
	check(Guide.last_goal_key != &"walker" and Guide.last_goal_key != &"camp_back", "his word still settling: neither the climb nor home yet (%s)" % Guide.last_goal_key)
	await _next_day(g)
	_hop(g, &"walker", "settled: the lame walker")
	var crater := _pinned_crater(g)
	check(crater.is_finite(), "the survey marks the crater (%s)" % [UiMapScreen.told(g)])
	check(_is_tread(g, crater), "on a crater the walker's foot comes back to")
	check(g.world.same_body(crater, _placed(g, &"the_covenant")), "on the Covenant's body")
	Story.beat(&"enclave_met")
	_hop(g, &"camp_back", "the enclave met: the far shore done, home")
	Sx.end(g)
	Story.forget()


## Seed 42 has two craters, on the shaft's body and the far works': neither is the
## Covenant's.
func test_no_crater_on_the_covenants_body_and_the_goal_goes_home() -> void:
	var g := await _told(42)
	var craters := 0
	for m: Dictionary in g.world.landmarks:
		if StringName(m.get("kind", &"")) == &"tread":
			craters += 1
			check(not g.world.same_body(m.pos, _placed(g, &"the_covenant")), "a crater at %s is on another body" % [m.pos])
	gt(float(craters), 0.0, "the walker does set feet down in this world")
	await _next_day(g)
	_hop(g, &"camp_back", "told and settled, with no crater on this shore: home, never another leg's body")
	check(not _pinned_crater(g).is_finite(), "and no crater is marked")
	Sx.end(g)
	Story.forget()


## Slice 2 done, the far shore's threads behind him long ago, and Solis has just
## said whose roads he is sold and the road up.
func _told(seed_value: int) -> Game:
	Story.forget()
	Sx.use_root("walker-lead-%d" % seed_value)
	var g := Sx.game(tree, ["--seed=%d" % seed_value, "--hour=10", "--weather=clear:0"])
	await frames(3)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	Story.choose(&"rook.iron", &"paid")
	if not g.inventory.has(&"kit_plate"):
		g.inventory.add(&"kit_plate", 1)
	g.inventory.add(&"plate_mended", 1)
	g.body.fed_until = g.clock.minutes + 100000.0
	for b: StringName in [&"reaper_down", &"built_halcyon", &"holdfast_hope", &"war_archive", &"war_relay", &"tradecraft",
			&"covenant_fed", &"covenant_speaker", &"june_named", &"june_knew", &"echo_kept"]:
		Story.beat(b, -INF)
	for who: StringName in [&"otto", &"june"]:
		@warning_ignore("return_value_discarded")
		Story.meet(who)
	Story.beat(&"teague_sold")
	Story.beat(&"walker_told")
	return g


## A day on, at the same hour: whatever landed has been felt, and it is light.
func _next_day(g: Game) -> void:
	g.clock.minutes += 24.0 * 60.0
	await process_frames(2)


func _hop(g: Game, key: StringName, what: String) -> void:
	eq(Guide.goal(g), _lead(key), what)
	eq(Guide.last_goal_key, key, "%s: keyed, so a tour can claim it" % key)


## Where the survey marks the crater's word while the goal is the walker's, or INF.
func _pinned_crater(g: Game) -> Vector2:
	var word := String(StoryContent.TOLD_WHILE.get(&"walker", {}).get("word", "<none>"))
	for m: Dictionary in UiMapScreen.told(g):
		if String(m.word) == word:
			return m.at
	return Vector2.INF


func _is_tread(g: Game, at: Vector2) -> bool:
	for m: Dictionary in g.world.landmarks:
		if StringName(m.get("kind", &"")) == &"tread" and (m.pos as Vector2).distance_to(at) < 0.5:
			return true
	return false


func _placed(g: Game, place: StringName) -> Vector2:
	var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
	return placed[place].pos if placed.has(place) else Vector2.INF
