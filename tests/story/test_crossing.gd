extends TestCase
## THE CROSSING (ROADMAP slice 3, step 1): Vera has named the archive across the
## water. The goal is a raft, then the narrows the survey marks on the home body's
## shore (StoryCrossing: the line from the crew's camp to the archive, where it
## leaves the land), then, once he has stood on the far body, the archive.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_narrows_lie_between_the_camp_and_the_archive_and_a_raft_crosses_them() -> void:
	var w := WorldGen.generate(1, 1840)
	var cast := StoryPlan.cast(w)
	var camp: Vector2 = cast[&"the_camp"].pos
	var arc: Vector2 = cast[&"the_archive"].pos
	var c := StoryCrossing.find(w, camp, arc)
	check(not c.is_empty(), "seed 1 has a crossing from the camp toward the archive")
	if c.is_empty():
		return
	check(w.same_body(c.launch, camp), "it puts in from the home body")
	check(w.same_body(c.land, arc), "and lands on the archive's")
	lt(float(c.water), 200.0, "narrow water, as measured (130 tiles on seed 1): %.0f" % float(c.water))
	# The raft's hull is spent a share a tile (CraftKinds wear); it must outlast
	# the crossing with the worst water all the way.
	var worst: float = 0.0
	for g: int in CraftKinds.row(&"raft").get("wear", {}):
		worst = maxf(worst, float(CraftKinds.row(&"raft")["wear"][g]))
	lt(float(c.water) * worst, float(CraftKinds.row(&"raft").get("hull", 0.0)), "a raft outlasts the crossing in its worst water")


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
