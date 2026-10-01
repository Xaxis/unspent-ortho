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
## `use_spent`, `_cache_wins`). One press at seed 1's nearest cache opened it and
## read the terminal beside it; facing nothing with words, it opened it and, by a
## fire and peckish, ate the stew too. Facing the words, the press is theirs and
## the cache waits; facing nothing, the cache's, and nothing else answers it.
func test_the_press_that_opens_a_cache_answers_nothing_else() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var sys := g.get_node("22_landmarks")
	var story := g.get_node("49_story")
	Story.forget()
	var sites: Array[LandmarkSite] = []
	for s: LandmarkSite in sys.all():
		sites.append(s)
	sites.sort_custom(func(a: LandmarkSite, b: LandmarkSite) -> bool: return a.pos.distance_to(g.player.pos) < b.pos.distance_to(g.player.pos))
	check(sites.size() >= 2, "two caches to open")
	g.inventory.add(&"stew", 2)
	# The first cache has a terminal beside it: faced, then turned from. The
	# second is opened facing nothing.
	for i in 2:
		var site := sites[i]
		var at := Landmarks.cache_of(site)
		g.player.hero.pos = at
		g.player.pos = at
		check(Survival.add_prop(g, PropKind.FIRE, at + Vector2(-1.5, 0.0), 0.0, 0.3) != null, "a fire by %s" % site.id)
		await frames(30)
		g.body.fed_until = g.clock.minutes - 120.0
		var stew := g.inventory.count(&"stew")
		await frames(2)
		check(sys.get("reachable") != null and Survival.at_rest(g) and g.body.hunger_level(g.clock.minutes) == 1,
			"%s: in reach of the cache, by a fire, peckish" % site.id)
		if i == 0:
			check(_face(g, story, true), "%s: a way to face the words beside it" % site.id)
			await _press_use()
			check(story.view.showing(), "%s: facing the words, the press reads them" % site.id)
			check(not sys.state.is_opened(site.id), "%s: and the cache waits" % site.id)
			eq(g.inventory.count(&"stew"), stew, "%s: and nothing is eaten" % site.id)
			story.call("_close")
			await frames(2)
		check(_face(g, story, false), "%s: a way to face nothing with words" % site.id)
		await _press_use()
		check(sys.state.is_opened(site.id), "%s: facing nothing, the press opens the cache" % site.id)
		check(not story.view.showing(), "%s: and reads nothing" % site.id)
		eq(g.inventory.count(&"stew"), stew, "%s: and eats nothing" % site.id)
		if story.view.showing():
			story.call("_close")
		await frames(2)
	g.queue_free()
	await frames(1)


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
