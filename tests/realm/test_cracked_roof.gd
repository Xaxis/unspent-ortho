extends TestCase
## A CAVE'S ROOF HANGS CRACKED ROUND ITS TEARS (CrackedRoof): stones worked out
## at play time from the lid the world already has and the landscape's `collapse`
## pressure, so no seed moves. Each hangs from roofed ground a few tiles in from
## open ground, over ground a body stands on, with room for a person under it;
## the same world gives the same stones; ground with no lid has none.

const Sx := preload("res://tests/save/save_fixture.gd")
const SIZE := 256
const SEED := 7


func test_the_caves_hang_stones_round_their_tears_and_the_surface_none() -> void:
	var w := WorldGen.generate(SEED, SIZE, &"", Realm.UNDERGROUND)
	var q := WorldQuery.new(w)
	var all := CrackedRoof.stones_near(w, Vector2(SIZE * 0.5, SIZE * 0.5), SIZE)
	print("  %d stones hang cracked in a %d cave" % [all.size(), SIZE])
	gt(float(all.size()), 20.0, "the caves hang stones to bring down")
	lt(float(all.size()), 600.0, "and not a forest of them")
	for s: Dictionary in all:
		var k: Vector2i = s.key
		check(w.overhead_at(k.x, k.y).x >= 0, "%s hangs from a lid" % k)
		check(q.standable(k.x, k.y), "%s over ground a body stands on" % k)
		gt(float(s.y), float(w.level_at(k.x, k.y)) * WorldData.STEP + Tuning.PLAYER_HEIGHT, "%s hangs over a person's head" % k)
		var open := false
		for dy in range(-CrackedRoof.RIM_TO, CrackedRoof.RIM_TO + 1):
			for dx in range(-CrackedRoof.RIM_TO, CrackedRoof.RIM_TO + 1):
				if w.level_at(k.x + dx, k.y + dy) > 0 and w.overhead_at(k.x + dx, k.y + dy).x < 0:
					open = true
		check(open, "%s is on the rim of a tear" % k)
	var again := CrackedRoof.stones_near(w, Vector2(SIZE * 0.5, SIZE * 0.5), SIZE)
	eq(again.size(), all.size(), "the same world hangs the same stones")
	var surface := WorldGen.generate(SEED, SIZE)
	eq(CrackedRoof.stones_near(surface, Vector2(SIZE * 0.5, SIZE * 0.5), SIZE).size(), 0, "the surface hangs none")


## In play (43_cracked_roof): the stones near the player hang in the fight, one
## pulled down comes down and stays down, through a save.
func test_a_stone_brought_down_stays_down_through_a_save() -> void:
	Sx.use_root("cracked-roof")
	var g := Sx.game(tree, ["--seed=7", "--realm=underground", "--hour=12"])
	var sys := Sx.system(g, "43_cracked_roof")
	var sim: FightSim = g.player.sim
	var at := g.player.pos
	var near := CrackedRoof.stones_near(g.world, at, 60)
	check(not near.is_empty(), "stones hang near the start")
	if near.is_empty():
		Sx.end(g)
		return
	g.player.place(near[0].at + Vector2(3.0, 0.0))
	for i in 40:
		await tree.process_frame
	var hung := sim.hangings.size()
	gt(float(hung), 0.0, "the stones near the player hang in the fight (%d)" % hung)
	var id := int(sim.hangings[0].id)
	var where: Vector2 = sim.hangings[0].at
	check(sim.pull_down(id), "pulled")
	# Until it has landed, by the fight's own clock (a frame is not a sim step).
	var land := sim.now + FightSim.FALL_MS + 400.0
	var until := Time.get_ticks_msec() + int(20000.0 * machine_slack())
	while sim.now < land and Time.get_ticks_msec() < until:
		await tree.process_frame
	for i in 10:
		await tree.process_frame
	sys.call(&"_read")
	for h: Dictionary in sim.hangings:
		check((h.at as Vector2).distance_to(where) > 0.1, "it came down and is not hung again")
	var saved: Variant = sys.call(&"_save")
	sys.call(&"_load", saved)
	# The roof read again at once (its own beat is real time, longer than a few
	# headless frames), so what it hangs is what the load left down.
	sys.call(&"_read")
	gt(float(sim.hangings.size()), 0.0, "the roof is hung again after the load")
	for h: Dictionary in sim.hangings:
		check((h.at as Vector2).distance_to(where) > 0.1, "and stays down through a save")
	Sx.end(g)
