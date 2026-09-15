extends TestCase
## The strand laid near the spawn: on the shore, the same for a seed, and only
## the shortfall of what the generator already placed.

const Fx := preload("res://tests/survival/fixture.gd")


## A 60x60 field with the sea along its west side and a beach of sand above it.
static func _coast() -> Game:
	var g := Fx.flat(60)
	var w := g.world
	for y in w.size:
		for x in 12:
			var i := y * w.size + x
			if x < 8:
				w.level[i] = 0
				w.ground[i] = Ground.WATER
			else:
				w.level[i] = 2
				w.ground[i] = Ground.SAND
	w.spawn = Vector2(16.5, 30.5)
	g.player.pos = w.spawn
	return g


func test_the_strand_lies_on_the_beach_by_the_water_and_the_tip_inland() -> void:
	var g := _coast()
	var laid := Strand.lay(g)
	var kinds := {}
	for p in laid:
		kinds[p.kind] = int(kinds.get(p.kind, 0)) + 1
		var tx := floori(p.pos.x)
		var ty := floori(p.pos.y)
		if p.kind == PropKind.TIP:
			check(g.world.ground_at(tx, ty) == Ground.GRASS, "a tip stands on dry ground, not the beach")
			gt(p.pos.distance_to(g.world.spawn), 7.0, "a walk inland")
		else:
			eq(g.world.ground_at(tx, ty), Ground.SAND, "%s on the sand" % PropKind.NAMES[p.kind])
			var wet := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					wet = wet or g.world.level_at(tx + dx, ty + dy) <= 0
			check(wet, "%s within two tiles of the water" % PropKind.NAMES[p.kind])
		lt(p.pos.distance_to(g.world.spawn), Strand.TIP_RADIUS + 0.1, "within a walk of the spawn")
		eq(g.query.nearest_prop(p.pos, 0.1), p, "in the query")
	for kind: int in Strand.WANT:
		eq(kinds.get(kind, 0), Strand.WANT[kind], "all the %s wanted" % PropKind.NAMES[kind])
	eq(kinds.get(PropKind.TIP, 0), Strand.TIP_HEAPS, "a tip of a few heaps")
	for i in laid.size():
		for j in range(i + 1, laid.size()):
			gt(laid[i].pos.distance_to(laid[j].pos), 1.0, "scattered, never stacked")
	eq(Strand.plan(g).size(), 0, "laid once, nothing more to lay")
	Fx.done(g)


func test_the_same_seed_lays_the_same_strand() -> void:
	var a := _coast()
	var b := _coast()
	var pa := Strand.plan(a)
	var pb := Strand.plan(b)
	eq(pa.size(), pb.size())
	for i in mini(pa.size(), pb.size()):
		eq(pa[i].kind, pb[i].kind)
		near((pa[i].pos as Vector2).distance_to(pb[i].pos), 0.0, 1e-6)
	Fx.done(a)
	Fx.done(b)


func test_it_steps_back_where_the_generator_already_placed_things() -> void:
	var g := _coast()
	for i in 5:
		Survival.add_prop(g, PropKind.DRIFTWOOD, Vector2(9.5, 20.5 + i * 3.0))
	Survival.add_prop(g, PropKind.TIP, Vector2(40.5, 30.5))
	var plan := Strand.plan(g)
	var drift := 0
	for p: Dictionary in plan:
		drift += int(int(p.kind) == PropKind.DRIFTWOOD)
		check(int(p.kind) != PropKind.TIP, "a tip in reach already: no second tip")
	eq(drift, Strand.WANT[PropKind.DRIFTWOOD] - 5, "only the driftwood short")
	Fx.done(g)


func test_found_leavings_are_drawn_by_the_ruler_and_made_ones_by_hand() -> void:
	for kind: int in [PropKind.WRECK, PropKind.POLE, PropKind.PYLON]:
		check(RemnantModels.is_found(RemnantModels.for_kind(kind)), "%s leaves plate" % PropKind.NAMES[kind])
	for kind: int in [PropKind.BOULDER, PropKind.IRON_ORE, PropKind.RUIN, PropKind.PINE, PropKind.REEDS]:
		check(not RemnantModels.is_found(RemnantModels.for_kind(kind)), "%s leaves something made" % PropKind.NAMES[kind])
	check(RemnantModels.is_found(RemnantModels.worked_for(PropKind.TIP, &"turn")), "a picked tip has plate turned out round it")
	eq(RemnantModels.worked_for(PropKind.PINE, &"tap"), &"tapped")
	eq(RemnantModels.worked_for(PropKind.PINE, &"gather"), &"picked", "dead wood gathered is not a tap")
