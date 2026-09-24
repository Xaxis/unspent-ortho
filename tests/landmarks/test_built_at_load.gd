extends TestCase
## Every landmark and every depot is BUILT WHEN THE WORLD IS MADE and never again.
##
## They were built when they came within draw reach and freed when they left it.
## From above that reach is 62 tiles; the moment the camera sees the horizon
## (over the shoulder) it is `SkyLight.SEE`, the whole island, so the FIRST press
## of the shoulder key built all two hundred landmarks and seventeen depots in one
## frame: measured 569 ms and 97 ms on seed 7, 584 and 95 on seed 4, with the box
## at load 45 (perf/stutters). And walking out of reach and back rebuilt the same
## model again, so every walk past one paid it twice. A site never moves and its
## model is a function of the site, so the model has one answer for the life of
## a world: it is made at load and only SHOWN or HIDDEN by distance after that.


func _game() -> Game:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func test_every_site_is_built_at_load_and_kept() -> void:
	var g := _game()
	await frames(4)
	var lm := g.get_node("22_landmarks")
	var wk := g.get_node("34_works")
	var sites: Array = lm.all()
	gt(sites.size(), 3, "seed 1 at 256 has landmarks to hold to this")
	var nodes: Dictionary = lm.get(&"_nodes")
	eq(nodes.size(), sites.size(), "a model for every landmark on the island, before anything looks up")
	var yards: Dictionary = wk.get(&"_yards")
	var works_sites: Array = wk.get(&"sites")
	eq(yards.size(), works_sites.size(), "a yard for every depot on the island")
	# Walk to the far side of the island and back: the same models, not new ones.
	var before := {}
	for id: Variant in nodes:
		before[id] = (nodes[id] as Node3D).get_instance_id()
	# The simulation is made after 22_landmarks' setup and taken on its first
	# tick; hand it over rather than wait on a tick this runner may not give.
	lm.set(&"sim", g.player.sim)
	var hero: Variant = g.player.sim.hero
	var home: Vector2 = hero.pos
	for at: Vector2 in [Vector2(250, 250), Vector2(4, 4), home]:
		hero.pos = at
		lm.call(&"_draw")
		wk.call(&"_draw")
	var rebuilt := 0
	for id: Variant in before:
		if not nodes.has(id) or (nodes[id] as Node3D).get_instance_id() != int(before[id]):
			rebuilt += 1
	eq(rebuilt, 0, "walking away and back rebuilds no landmark")
	# And from above, only what is within reach is drawn.
	var shown := 0
	var near := 0
	var reach: float = (lm.get_script() as Script).get_script_constant_map()["DRAW"]
	for s: LandmarkSite in sites:
		if s.pos.distance_to(home) <= reach:
			near += 1
		if (nodes[s.id] as Node3D).visible:
			shown += 1
	eq(shown, near, "from above, exactly the landmarks in draw reach are shown")
	g.queue_free()
	await frames(1)
