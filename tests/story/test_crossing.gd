extends TestCase
## THE CROSSING (ROADMAP slice 3, step 1): Vera has named the archive across the
## water. The goal is a raft, then the put-in the survey marks on the home body's
## shore, then, once he has stood on the far body, the archive. The raft comes
## ashore at the world's landfall, else across the narrows off the line from the
## crew's camp to the archive (StoryCrossing.of).

const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_narrows_lie_between_the_camp_and_the_archive_and_a_raft_crosses_them() -> void:
	for world_seed: int in [1, 7]:
		_narrows(world_seed)


func _narrows(world_seed: int) -> void:
	var w := WorldGen.generate(world_seed, 1840)
	var cast := StoryPlan.cast(w)
	var camp: Vector2 = cast[&"the_camp"].pos
	var arc: Vector2 = cast[&"the_archive"].pos
	var c := StoryCrossing.find(w, camp, arc)
	print("  seed %d: camp %s archive %s -> %s" % [world_seed, camp, arc, c])
	check(not c.is_empty(), "seed %d has a crossing from the camp toward the archive" % world_seed)
	if c.is_empty():
		return
	check(w.same_body(c.launch, camp), "it puts in from the home body")
	check(w.same_body(c.land, arc), "and lands on the archive's")
	if world_seed == 1:
		check(absf(float(c.water) - 130.0) < 6.0, "seed 1: the narrows, measured at 130 tiles: %.0f" % float(c.water))
	lt(Geometry2D.get_closest_point_to_segment(c.launch, camp, arc).distance_to(c.launch), StoryCrossing.REACH + 1.0, "a short walk off his road")
	# The raft's hull is spent a share a tile by the water under it (CraftKinds
	# wear), so the run is walked tile by tile: open water is kind to it, the
	# shallows are not. Half the hull is the most a crossing may take, so a
	# raft that drifts or turns back still makes the far shore.
	var row := CraftKinds.row(&"raft")
	var wear := 0.0
	var n := ceili(float(c.water))
	for i in n:
		var p: Vector2 = c.launch + (c.land - c.launch) * (float(i) / float(n))
		wear += float(row.get("wear", {}).get(w.ground_at(floori(p.x), floori(p.y)), 0.0))
	lt(wear, float(row.get("hull", 0.0)) * 0.5, "seed %d: a raft crosses on half its hull (%.0f water tiles)" % [world_seed, float(c.water)])


func _lead(key: StringName) -> String:
	return String(StoryContent.LEAD.get(key, "<no %s line>" % key))


func test_the_goal_walks_raft_narrows_archive() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	Story.choose(Guide.CAMP_PAID, StringName(StoryContent.PAID[Guide.CAMP_PAID].pick))
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"kit_plate", 1)
	for b: StringName in [&"reaper_down", &"built_halcyon", &"holdfast_hope", &"war_archive"]:
		Story.beat(b, -INF)
	eq(Guide.goal(g), _lead(&"raft"), "Vera has named the archive across the water: a raft")
	g.inventory.add(&"raft", 1)
	eq(Guide.goal(g), _lead(&"crossing"), "a raft in the creel: the narrows")
	var marked := false
	for t: Dictionary in UiMapScreen.told(g):
		marked = marked or String(t.word) == String(StoryContent.TOLD_WHILE.get(&"crossing", {}).get("word", "<none>"))
	check(marked, "and the survey marks where to put in")
	@warning_ignore("return_value_discarded")
	Story.hear(StoryCrossing.CROSSED)
	eq(Guide.goal(g), _lead(&"archive"), "stood on the far body: the archive")
	Sx.end(g)
	Story.forget()



## THE RAFT COMES ASHORE AT THE LANDFALL, where the shortest water from home does
## and the city dealt there stands its clock (StoryCrossing.of, the_landfall):
## seed 7's narrows put him ashore 126 tiles off it, out of sight of the city's
## port. In the drowned city, a step off the raft.
## THE RAFT LANDS ON THE PORT STAIR (StoryCrossing.of, rule 1): on a world whose
## landfall city laid its port (Landmarks.port_of), the raft comes in on that
## stair, under the clock, put in from a home shore with open water all the way.
## At the shipped size; each seed prints which rule it took and how far it lands
## from where the shortest water comes ashore.
func test_the_raft_lands_on_the_port_stair() -> void:
	var ported := 0
	for s: int in [1, 7, 42]:
		var w := WorldGen.generate(s, Tuning.WORLD_SIZE)
		StoryPlan.forget()
		var cast := StoryPlan.cast(w)
		var port := Landmarks.port_of(w)
		var c := StoryCrossing.of(w, cast)
		var land: Vector2 = c.get("land", Vector2.INF)
		var from := GenBodies.ashore(w)
		print("  seed %d at %d: %s, landing %.1f off the port and %.1f off where the water comes ashore, over %.0f tiles of water" % [
			s, Tuning.WORLD_SIZE, "the port" if port.is_finite() else "no port", land.distance_to(port), land.distance_to(from), float(c.get("water", NAN))])
		if not port.is_finite():
			continue
		ported += 1
		lt(land.distance_to(port), 0.01, "seed %d: the raft lands on the port's stair" % s)
		check(w.same_body(c.get("launch", Vector2.INF), cast[&"the_camp"].pos), "seed %d: put in from home" % s)
		check(StoryCrossing._open_water(w, c.get("launch", Vector2.INF), land), "seed %d: over open water all the way" % s)
		# And he steps off the raft onto the stair, not into the shallows beside it
		# (Crafts.step_off_spot): from the water nearest the landing the raft can
		# float on, the ground he is set down on is the port's own land.
		var berth := _berth(w, land)
		var off := Crafts.step_off_spot(w, WorldQuery.new(w), &"raft", berth)
		print("  seed %d: the raft berths at %s and sets him down at %s (%s)" % [s, berth, off, BiomeRegistry.at(w, off).id if off.is_finite() else &"nowhere"])
		check(off.is_finite() and not Ground.is_water(w.ground_at(floori(off.x), floori(off.y))), "seed %d: he steps off onto dry ground at the stair (%s)" % [s, off])
		check(off.is_finite() and BiomeRegistry.at(w, off).id == BiomeRegistry.at(w, port).id, "seed %d: the port's own land" % s)
	gt(float(ported), 0.0, "some seed's landfall laid a port, or nothing above was asked")
	StoryPlan.forget()


## The water tile nearest `land` a raft floats on: where it berths at a landing.
func _berth(w: WorldData, land: Vector2) -> Vector2:
	var best := Vector2.INF
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var p := Vector2(floori(land.x) + dx + 0.5, floori(land.y) + dy + 0.5)
			if Crafts.crossable(w, &"raft", p) and (not best.is_finite() or p.distance_to(land) < best.distance_to(land)):
				best = p
	return best


## THE PORT STANDS ITS SIGN (49_cast `the_port`, StoryContent.STOOD): on a world
## whose raft comes in on the port's stair, the story places `the_port` there, and
## once he is near, one sign is set down by it on dry ground, holding the stair's
## own words (`port_arrivals`), not any landscape's.
func test_the_port_stands_its_sign_at_the_stair() -> void:
	var signed := 0
	for s: int in [1, 7, 42]:
		Story.forget()
		var g := Sx.game(tree, ["--seed=%d" % s, "--hour=11", "--weather=clear:0"])
		await process_frames(2)
		var port := Landmarks.port_of(g.world)
		var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
		if not port.is_finite():
			check(not placed.has(StoryCrossing.PORT), "seed %d: no port, so no port slot" % s)
			Sx.end(g)
			continue
		check(placed.has(StoryCrossing.PORT) and (placed[StoryCrossing.PORT].pos as Vector2).distance_to(port) < 0.01, "seed %d: the port slot is the port's stair" % s)
		var p := g.player.place(port)
		g.view.ensure_near(p)
		var got: Array[WorldProp] = []
		for i in 120:
			await process_frames(1)
			got = _set_down_near(g, PropKind.SIGN, port, 10.0)
			if not got.is_empty():
				break
		eq(got.size(), 1, "seed %d: one sign is set down by the stair" % s)
		if got.size() == 1:
			signed += 1
			var t := Vector2i(got[0].pos.floor())
			check(g.query.standable(t.x, t.y) and not Ground.is_water(g.world.ground_at(t.x, t.y)), "seed %d: on dry ground you can stand at" % s)
			eq(StoryFragments.held_by(g.world, g.query, got[0]), &"port_arrivals", "seed %d: holding the stair's own words" % s)
		Sx.end(g)
		await process_frames(1)
	gt(float(signed), 0.0, "some seed's raft lands on a port, or nothing above was asked")
	Story.forget()


## The props set down in play (after the world's own) of `kind` within `r` of `at`.
func _set_down_near(g: Game, kind: int, at: Vector2, r: float) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	for i in range(g.world.generated(), g.world.prop_count()):
		var q := g.world.prop_at(i)
		if q.kind == kind and q.pos.distance_to(at) <= r:
			out.append(q)
	return out


func test_the_raft_comes_ashore_at_the_landfall() -> void:
	for s: int in [7, 42]:
		var w := WorldGen.generate(s, Tuning.WORLD_SIZE)
		StoryPlan.forget()
		var cast := StoryPlan.cast(w)
		check(cast.has(&"the_landfall"), "seed %d: the world has a landfall" % s)
		if not cast.has(&"the_landfall"):
			continue
		var landfall: Vector2 = cast[&"the_landfall"].pos
		var c := StoryCrossing.of(w, cast)
		var land: Vector2 = c.get("land", Vector2.INF)
		var narrows := StoryCrossing.find(w, cast[&"the_camp"].pos, cast[&"the_archive"].pos)
		print("  seed %d at %d: ashore %.1f tiles off the landfall over %.0f of water; the narrows land %.0f off it" % [
			s, Tuning.WORLD_SIZE, land.distance_to(landfall), float(c.get("water", NAN)),
			(narrows.get("land", Vector2.INF) as Vector2).distance_to(landfall)])
		lt(land.distance_to(landfall), StoryCrossing.ASHORE + 1.0, "seed %d: the raft comes ashore at it (%.1f tiles off)" % [s, land.distance_to(landfall)])
		check(w.same_body(c.get("launch", Vector2.INF), cast[&"the_camp"].pos), "seed %d: from home" % s)
		var city := false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				city = city or BiomeRegistry.at(w, land + Vector2(dx, dy)).id == &"drowned_city"
		check(city, "seed %d: into the drowned city" % s)
	StoryPlan.forget()
