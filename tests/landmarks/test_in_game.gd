extends TestCase
## The places worth the walk in a REAL GAME (docs/VISION.md, §8): what a body
## meets when it walks into one, and the order the place is experienced in.
##
## Nothing in this package stopped a body until the masses were written. A player
## could stand in the middle of the lighthouse's stonework, occluded and
## invisible at screen centre, and every silhouette in the game was scenery you
## walked through.


func _game(args: PackedStringArray) -> Game:
	var o := BootOptions.parse(args)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func _nearest(g: Game, kind: StringName) -> LandmarkSite:
	var sys := g.get_node("22_landmarks")
	var best: LandmarkSite = null
	var best_d := INF
	for s: LandmarkSite in sys.all():
		var d := s.pos.distance_to(g.player.pos)
		if (kind == &"" or s.kind == kind) and d < best_d:
			best_d = d
			best = s
	return best


func test_a_body_cannot_walk_into_a_tower() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--place=lighthouse"]))
	await frames(4)
	var sys := g.get_node("22_landmarks")
	var site := _nearest(g, &"lighthouse")
	check(site != null, "seed 1 holds a lighthouse to walk into")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	# Come at it from every quarter and be stopped by the stonework every time.
	for i in 8:
		var a := TAU * i / 8.0
		var from := site.pos + Vector2.from_angle(a) * 4.0
		var to := g.query.move_body(from, (site.pos - from) * 1.2, 0.34)
		gt(to.distance_to(site.pos), 1.0, "a body walks into the tower from %.1f rad" % a)
	# AND THE GROUND BESIDE IT IS STILL GROUND — a claim about the LANDMARK'S OWN
	# MASS and about nothing else in the world, so it is asked as a CONTROL and an
	# EXPERIMENT that differ in exactly one thing: whether the mass is registered.
	# Walk two tiles in from six out on every bearing; take every landmark's walls
	# off the query and walk the same lines again. A bearing the tower walls is one
	# the body cannot make WITH the mass and can make WITHOUT it, and no reasoning
	# about what else might be standing there is needed or trusted.
	#
	# **It used to ask the world instead, and got a different question back.** It
	# set a bearing aside when the tile the body STARTS on is not standable and
	# when a solid prop lay across the line — the start, and the furniture, and
	# never the STEP. Measured on this seed: the lighthouse stands on a level-5
	# knoll, so the two-tile step east falls lv5 → lv3 and the one west climbs
	# lv1 → lv5. Both are cliffs a body may not take, neither is the tower's
	# doing, and both were reported as its stonework walling the neighbourhood.
	var stopped: Array[float] = []
	for i in 8:
		var a := TAU * i / 8.0
		var from := site.pos + Vector2.from_angle(a) * 6.0
		var step := (site.pos - from).normalized() * 2.0
		if g.query.move_body(from, step, 0.34).distance_to(from) <= 1.0:
			stopped.append(a)
	var none: Array[Vector3] = []
	g.query.set_blocks(&"landmarks", none)
	var walled: PackedStringArray = []
	for a: float in stopped:
		var from := site.pos + Vector2.from_angle(a) * 6.0
		var step := (site.pos - from).normalized() * 2.0
		if g.query.move_body(from, step, 0.34).distance_to(from) > 1.0:
			walled.append("%.2f rad" % a)
	sys._set_walls()
	check(walled.is_empty(), "a landmark's own mass walls the land round it at %s" % [walled])
	g.queue_free()
	await frames(1)


## THE ORDER A LANDMARK IS EXPERIENCED IN: a shape at `sees`, a name at
## `FOUND_AT`, hands on it at `OPEN_REACH`. Each one is inside the last.
func test_it_is_read_then_named_then_opened_and_never_the_other_way_round() -> void:
	# Started at the spawn, so nothing has been found yet: booting AT a landmark
	# names it on the first frame, which is exactly the order this is about.
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var sys := g.get_node("22_landmarks")
	var site := _nearest(g, &"")
	check(site != null, "there is a place to walk to")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var def := site.def()
	gt(def.sees, Landmarks.FOUND_AT, "%s is a shape before it is a name" % site.kind)
	gt(Landmarks.FOUND_AT, Landmarks.OPEN_REACH, "and a name before it is a cache")
	# Standing well outside FOUND_AT, it is not found; walked in, it is, and it
	# stays found for the rest of the game.
	var away := site.pos + Vector2.from_angle(site.facing) * (Landmarks.FOUND_AT + 6.0)
	g.player.hero.pos = away
	g.player.pos = away
	await frames(24)
	check(not sys.state.is_found(site.id), "%s is not named from outside its own distance" % site.id)
	var near_at := Landmarks.cache_of(site)
	g.player.hero.pos = near_at
	g.player.pos = near_at
	await frames(24)
	check(sys.state.is_found(site.id), "%s is named when it is reached" % site.id)
	g.player.hero.pos = away
	g.player.pos = away
	await frames(24)
	check(sys.state.is_found(site.id), "and it stays on the survey after the player leaves")
	g.queue_free()
	await frames(1)


## What every landmark in a world has: a mass in the query, put there by the
## system and not by the world's own props.
func test_the_island_carries_the_mass_of_every_landmark_it_holds() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var sys := g.get_node("22_landmarks")
	var sites: Array[LandmarkSite] = sys.all()
	gt(float(sites.size()), 3.0, "the island holds places worth the walk")
	var walled := 0
	for s in sites:
		if not g.query.blocks_at(s.pos).is_empty():
			walled += 1
	eq(walled, sites.size(), "every one of them stops a body")
	print("landmarks in play: %d places, all of them with mass" % sites.size())
	g.queue_free()
	await frames(1)


## A CACHE TAKES THE PRESS FROM THE GROUND, NEVER FROM WHAT HE FACES (22_landmarks
## `use_spent`, `_cache_wins`): one press, one answer. Staged by name, whatever
## the world laid there: the nearest unguarded cache moved to Maren's side
## (cast:maren, who stands apart), a fire laid, peckish, stew carried. Facing her,
## the press is hers and the cache waits; facing away, the cache's and nothing
## else's; and the press after, with the cache open, eats. That last went to the
## open cache instead, until its next look, and did nothing at all.
func test_the_press_that_opens_a_cache_answers_nothing_else() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var sys := g.get_node("22_landmarks")
	var story := g.get_node("49_story")
	var cast := g.get_node("49_cast")
	Story.forget()
	var beside: Vector2 = cast.call("tour_place", "cast:maren")
	var maren := Vector2.INF
	for row: Dictionary in cast.get("people"):
		if row.character == &"maren":
			maren = row.pos
	check(beside.is_finite() and maren.is_finite(), "Maren is cast, with somewhere to stand at her side")
	# Past CLOSE (49_story: nearer, she answers whichever way he faces) and in
	# REACH, so turning away from her is facing nothing.
	var spot := maren + (beside - maren).normalized() * (StoryProps.CLOSE + StoryProps.REACH) * 0.5
	check(g.query.standable(floori(spot.x), floori(spot.y)), "ground to stand on there")
	# Unguarded: a guarded one sends a machine out behind him, and nobody eats
	# with a hunter that close (Survival.eat).
	var site: LandmarkSite = null
	for s: LandmarkSite in sys.all():
		if s.def() != null and not s.def().guarded and (site == null or s.pos.distance_to(spot) < site.pos.distance_to(spot)):
			site = s
	check(site != null, "an unguarded cache to move")
	if site == null or not spot.is_finite():
		g.queue_free()
		await frames(1)
		return
	site.pos += spot - Landmarks.cache_of(site)
	g.player.hero.pos = spot
	g.player.pos = spot
	check(Survival.add_prop(g, PropKind.FIRE, spot + (spot - maren).normalized() * 1.5, 0.0, 0.3) != null, "a fire at his back")
	g.inventory.add(&"stew", 2)
	await frames(30)
	g.body.fed_until = g.clock.minutes - 120.0
	var stew := g.inventory.count(&"stew")
	await frames(2)
	check(sys.get("reachable") == site and Survival.at_rest(g) and g.body.hunger_level(g.clock.minutes) == 1,
		"in reach of the cache, by a fire, peckish")
	_turn(g, (maren - spot).angle())
	check(bool(story.call("faces_words")), "facing Maren")
	eq(UiLink.use_hint(g), "talk", "and the hint says the press is hers, not the cache's")
	await _free(g)
	await _press_use()
	check(story.get("talk") != null, "facing Maren, the press is hers")
	check(not sys.state.is_opened(site.id), "and the cache waits")
	eq(g.inventory.count(&"stew"), stew, "and nothing is eaten")
	story.call("_close")
	await frames(2)
	check(_face(g, story, false), "a way to face nothing with words")
	eq(UiLink.use_hint(g), "cache - open", "and the hint says the press is the cache's")
	await _free(g)
	await _press_use()
	check(sys.state.is_opened(site.id), "facing away, the press opens the cache")
	check(story.get("talk") == null and not story.view.showing(), "and says nothing")
	eq(g.inventory.count(&"stew"), stew, "and eats nothing")
	await _free(g)
	await _press_use()
	eq(g.inventory.count(&"stew"), stew - 1, "the cache open, the next press eats")
	g.queue_free()
	await frames(1)


## AN ASK'S SECOND PRESS IS THE ASK'S (Survival.ask_pending): "Again, and a fire
## is laid here" promises the next press, and a system that answers `use` before
## the survival one must not spend it. At seed 7's camp on the drowned city's
## world the first press asked before the cache in reach was looked at again
## (22_landmarks, LOOK_EVERY), and the second opened the cache. Staged by name:
## the nearest unguarded cache moved to his back, in reach, and a fire asked for
## as that first press did. The hint names whatever the press goes to.
func test_a_fire_asked_for_is_laid_by_the_next_press_whatever_is_in_reach() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var sys := g.get_node("22_landmarks")
	var spot := g.player.pos
	g.inventory.add(&"driftwood", 3)
	g.inventory.add(&"stone", 2)
	var faced := false
	for k in 16:
		_turn(g, TAU * k / 16.0)
		if Survival.describe_target(g) == "campfire - build?":
			faced = true
			break
	check(faced, "somewhere in front of him to lay a fire, and what it takes")
	var site: LandmarkSite = null
	for s: LandmarkSite in sys.all():
		if s.def() != null and not s.def().guarded and (site == null or s.pos.distance_to(spot) < site.pos.distance_to(spot)):
			site = s
	check(site != null, "an unguarded cache to move")
	if site == null or not faced:
		g.queue_free()
		await frames(1)
		return
	site.pos += spot - Vector2.from_angle(g.player.facing) * 1.5 - Landmarks.cache_of(site)
	await frames(30)
	check(sys.get("reachable") == site, "the cache at his back, in reach")
	eq(UiLink.use_hint(g), "cache - open", "and the hint names it, the press being its")
	check(Survival.use(g) and Survival.build_asked(g).is_finite(), "a fire asked for")
	eq(UiLink.use_hint(g), "campfire - build", "and the hint names the ask's answer")
	await _free(g)
	await _press_use()
	check(Survival.fire_near(g, 5.0) != null, "the next press lays the fire it promised")
	check(not sys.state.is_opened(site.id), "and the cache waits")
	await _free(g)
	await _press_use()
	check(sys.state.is_opened(site.id), "the press after opens it")
	g.queue_free()
	await frames(1)


func _turn(g: Game, facing: float) -> void:
	g.player.facing = facing
	g.player.hero.facing = facing


## Until the keys are his again (a staged view may hold them), or ten seconds.
func _free(g: Game) -> void:
	var end := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < end and g.input_blocked():
		await process_frames(1)
	check(not g.input_blocked(), "the keys are his")


## Turn him, round the compass, until the story would (or would not) answer what
## he faces with words.
func _face(g: Game, story: Node, words: bool) -> bool:
	for k in 16:
		g.player.facing = TAU * k / 16.0
		g.player.hero.facing = g.player.facing
		if bool(story.call("faces_words")) == words:
			return true
	return false


## The real key, as a player presses it.
func _press_use() -> void:
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	await process_frames(3)
