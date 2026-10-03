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
func test_the_raft_comes_ashore_at_the_landfall() -> void:
	for s: int in [7, 42]:
		var w := WorldGen.generate(s, 2048)
		StoryPlan.forget()
		var cast := StoryPlan.cast(w)
		check(cast.has(&"the_landfall"), "seed %d: the world has a landfall" % s)
		if not cast.has(&"the_landfall"):
			continue
		var landfall: Vector2 = cast[&"the_landfall"].pos
		var c := StoryCrossing.of(w, cast)
		var land: Vector2 = c.get("land", Vector2.INF)
		lt(land.distance_to(landfall), StoryCrossing.ASHORE + 1.0, "seed %d: the raft comes ashore at it (%.1f tiles off)" % [s, land.distance_to(landfall)])
		check(w.same_body(c.get("launch", Vector2.INF), cast[&"the_camp"].pos), "seed %d: from home" % s)
		var city := false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				city = city or BiomeRegistry.at(w, land + Vector2(dx, dy)).id == &"drowned_city"
		check(city, "seed %d: into the drowned city" % s)
	StoryPlan.forget()
